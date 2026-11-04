module os.io;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/***********************************************************

Copyright 1987, 1989, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987, 1989 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/
/*****************************************************************
 * i/o functions
 *
 *   WriteToClient, ReadRequestFromClient
 *   InsertFakeRequest, ResetCurrentRequest
 *
 *****************************************************************/

import build.xlibre_server;

import dix.dixstruct_priv;
import os.connection;


version (Windows) {
//import externs.X11.Xwinsock;
}
// //import stdbool;
import core.stdc.stdio;
import core.stdc.string;
import os.Xtrans;
//import x11.Xmd;
import core.stdc.errno;
static if (!HasVersion!"Windows") {
import core.sys.posix.sys.uio;
}
//import x11.X;
//import x11.Xproto;

import dix.dix_priv;
import os.bug_priv;
import os.client_priv;
import os.io_priv;
import os.osdep;
import os.ossock;
import dix.dispatch;

import include.os;
import include.misc;
import externs.X11.extensions.bigreqsproto;
import core.stdc.stdio;
import core.stdc.errno;
import core.stdc.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.pthread;
import os.Xtransint;

CallbackListPtr ReplyCallback = null;
CallbackListPtr FlushCallback;

struct _connectionInput {
    _connectionInput* next;
    char* buffer;               /* contains current client input */
    char* bufptr;               /* pointer to current start of data */
    int bufcnt;                 /* count of bytes in buffer */
    int lenLastReq;
    int size;
    uint ignoreBytes;   /* bytes to ignore before the next request */
}

alias ConnectionInput = _connectionInput;
alias ConnectionInputPtr = _connectionInput*;

struct _connectionOutput {
    _connectionOutput* next;
    ubyte* buf;
    int size;
    int count;
}

alias ConnectionOutput = _connectionOutput;
alias ConnectionOutputPtr = _connectionOutput*;


private Bool CriticalOutputPending;
private int timesThisConnection = 0;
private ConnectionInputPtr FreeInputs = cast(ConnectionInputPtr) null;
private ConnectionOutputPtr FreeOutputs = cast(ConnectionOutputPtr) null;
private OsCommPtr AvailableInput = cast(OsCommPtr) null;

enum string get_req_len(string req,string cli) = `((` ~ cli ~ `).swapped ? 
			      bswap_16((` ~ req ~ `).length) : (` ~ req ~ `).length)`;

//import externs.X11.extensions.bigreqsproto;

enum string get_big_req_len(string req,string cli) = `((` ~ cli ~ `).swapped ? 
				  bswap_32(cast(uint)(cast(xBigReq*)(` ~ req ~ `)).length) : 
				  (cast(xBigReq*)(` ~ req ~ `)).length)`;

enum BUFSIZE = 16384;
enum BUFWATERMARK = 32768;

/*
 *   A lot of the code in this file manipulates a ConnectionInputPtr:
 *
 *    -----------------------------------------------
 *   |------- bufcnt ------->|           |           |
 *   |           |- gotnow ->|           |           |
 *   |           |-------- needed ------>|           |
 *   |-----------+--------- size --------+---------->|
 *    -----------------------------------------------
 *   ^           ^
 *   |           |
 *   buffer   bufptr
 *
 *  buffer is a pointer to the start of the buffer.
 *  bufptr points to the start of the current request.
 *  bufcnt counts how many bytes are in the buffer.
 *  size is the size of the buffer in bytes.
 *
 *  In several of the functions, gotnow and needed are local variables
 *  that do the following:
 *
 *  gotnow is the number of bytes of the request that we're
 *  trying to read that are currently in the buffer.
 *  Typically, gotnow = (buffer + bufcnt) - bufptr
 *
 *  needed = the length of the request that we're trying to
 *  read.  Watch out: needed sometimes counts bytes and sometimes
 *  counts CARD32's.
 */

/*****************************************************************
 * ReadRequestFromClient
 *    Returns one request in client->requestBuffer.  The request
 *    length will be in client->req_len.  Return status is:
 *
 *    > 0  if  successful, specifies length in bytes of the request
 *    = 0  if  entire request is not yet available
 *    < 0  if  client should be terminated
 *
 *    The request returned must be contiguous so that it can be
 *    cast in the dispatcher to the correct request type.  Because requests
 *    are variable length, ReadRequestFromClient() must look at the first 4
 *    or 8 bytes of a request to determine the length (the request length is
 *    in the 3rd and 4th bytes of the request unless it is a Big Request
 *    (see the Big Request Extension), in which case the 3rd and 4th bytes
 *    are zero and the following 4 bytes are the request length.
 *
 *    Note: in order to make the server scheduler (WaitForSomething())
 *    "fair", the ClientsWithInput mask is used.  This mask tells which
 *    clients have FULL requests left in their buffers.  Clients with
 *    partial requests require a read.  Basically, client buffers
 *    are drained before select() is called again.  But, we can't keep
 *    reading from a client that is sending buckets of data (or has
 *    a partial request) because others clients need to be scheduled.
 *****************************************************************/

private void YieldControl()
{
    isItTimeToYield = TRUE;
    timesThisConnection = 0;
}

private void YieldControlNoInput(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr)client.osPrivate;
    YieldControl();
    if (oc.trans_conn)
        ospoll_reset_events(server_poll, oc.fd);
}

private void YieldControlDeath()
{
    timesThisConnection = 0;
}

/* If an input buffer was empty, either free it if it is too big or link it
 * into our list of free input buffers.  This means that different clients can
 * share the same input buffer (at different times).  This was done to save
 * memory.
 */
private void NextAvailableInput(OsCommPtr oc)
{
    if (AvailableInput) {
        if (AvailableInput != oc) {
            ConnectionInputPtr aci = AvailableInput.input;

            if (aci.size > BUFWATERMARK) {
                free(aci.buffer);
                free(aci);
            }
            else {
                aci.next = FreeInputs;
                FreeInputs = aci;
            }
            AvailableInput.input = null;
        }
        AvailableInput = null;
    }
}

int ReadRequestFromClient(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;
    ConnectionInputPtr oci = oc.input;
    uint gotnow = void, needed = void;
    int result = void;
    xReq* request = void;
    Bool need_header = void;
    Bool move_header = void;

    NextAvailableInput(oc);

    /* make sure we have an input buffer */

    if (!oci) {
        if ((oci = FreeInputs) !is null) {
            FreeInputs = oci.next;
        }
        else if (((oci = AllocateInputBuffer()) is null)) {
            YieldControlDeath();
            return -1;
        }
        oc.input = oci;
    }

static if (XTRANS_SEND_FDS) {
    /* Discard any unused file descriptors */
    while (client.req_fds > 0) {
        int req_fd = ReadFdFromClient(client);
        if (req_fd >= 0)
            close(req_fd);
    }
}
    /* advance to start of next request */

    oci.bufptr += oci.lenLastReq;

    need_header = FALSE;
    move_header = FALSE;
    gotnow = cast(uint)(oci.bufcnt + oci.buffer - oci.bufptr);

    if (oci.ignoreBytes > 0) {
        if (oci.ignoreBytes > oci.size)
            needed = oci.size;
        else
            needed = oci.ignoreBytes;
    }
    else if (gotnow < xReq.sizeof) {
        /* We don't have an entire xReq yet.  Can't tell how big
         * the request will be until we get the whole xReq.
         */
        needed = xReq.sizeof;
        need_header = TRUE;
    }
    else {
        /* We have a whole xReq.  We can tell how big the whole
         * request will be unless it is a Big Request.
         */
        request = cast(xReq*) oci.bufptr;
        needed = mixin(get_req_len!(`request`, `client`));
        if (!needed && client.big_requests) {
            /* It's a Big Request. */
            move_header = TRUE;
            if (gotnow < xBigReq.sizeof) {
                /* Still need more data to tell just how big. */
                needed = cast(uint)bytes_to_int32(xBigReq.sizeof);       /* needed is in CARD32s now */
                need_header = TRUE;
            }
            else
                needed = cast(uint)mixin(get_big_req_len!(`request`, `client`));
        }
        client.req_len = needed;
        if (needed > MAXINT >> 2) {
            /* Check for potential integer overflow */
            return -(BadLength);
        }
        needed <<= 2;           /* needed is in bytes now */
    }
    if (gotnow < needed) {
        /* Need to read more data, either so that we can get a
         * complete xReq (if need_header is TRUE), a complete
         * xBigReq (if move_header is TRUE), or the rest of the
         * request (if need_header and move_header are both FALSE).
         */

        oci.lenLastReq = 0;
        if (needed > maxBigRequestSize << 2) {
            /* request is too big for us to handle */
            /*
             * Mark the rest of it as needing to be ignored, and then return
             * the full size.  Dispatch() will turn it into a BadLength error.
             */
            oci.ignoreBytes = needed - gotnow;
            oci.lenLastReq = gotnow;
            return needed;
        }
        if ((gotnow == 0) || ((oci.bufptr - oci.buffer + needed) > oci.size)) {
            /* no data, or the request is too big to fit in the buffer */

            if ((gotnow > 0) && (oci.bufptr != oci.buffer))
                /* save the data we've already read */
                memmove(oci.buffer, oci.bufptr, gotnow);
            if (needed > oci.size) {
                /* make buffer bigger to accommodate request */
                char* ibuf = void;

                ibuf = cast(char*) realloc(oci.buffer, needed);
                if (!ibuf) {
                    YieldControlDeath();
                    return -1;
                }
                oci.size = needed;
                oci.buffer = ibuf;
            }
            oci.bufptr = oci.buffer;
            oci.bufcnt = gotnow;
        }
        /*  XXX this is a workaround.  This function is sometimes called
         *  after the trans_conn has been freed.  In this case trans_conn
         *  will be null.  Really ought to restructure things so that we
         *  never get here in those circumstances.
         */
        if (!oc.trans_conn) {
            /*  treat as if an error occurred on the read, which is what
             *  used to happen
             */
            YieldControlDeath();
            return -1;
        }
        result = _XSERVTransRead(oc.trans_conn, oci.buffer + oci.bufcnt,
                                 oci.size - oci.bufcnt);
        if (result <= 0) {
            if ((result < 0) && ossock_wouldblock(errno)) {
                mark_client_not_ready(client);
                YieldControlNoInput(client);
                return 0;
            }
            YieldControlDeath();
            return -1;
        }
        oci.bufcnt += result;
        gotnow += result;
        /* free up some space after huge requests */
        if ((oci.size > BUFWATERMARK) &&
            (oci.bufcnt < BUFSIZE) && (needed < BUFSIZE)) {
            char* ibuf = void;

            ibuf = cast(char*) realloc(oci.buffer, BUFSIZE);
            if (ibuf) {
                oci.size = BUFSIZE;
                oci.buffer = ibuf;
                oci.bufptr = ibuf + oci.bufcnt - gotnow;
            }
        }
        if (need_header && gotnow >= needed) {
            /* We wanted an xReq, now we've gotten it. */
            request = cast(xReq*) oci.bufptr;
            needed = mixin(get_req_len!(`request`, `client`));
            if (!needed && client.big_requests) {
                move_header = TRUE;
                if (gotnow < xBigReq.sizeof)
                    needed = cast(uint)bytes_to_int32(xBigReq.sizeof);
                else
                    needed = cast(int)mixin(get_big_req_len!(`request`, `client`));
            }
            client.req_len = needed;
            if (needed > MAXINT >> 2)
                return -(BadLength);
            needed <<= 2;
        }
        if (gotnow < needed) {
            /* Still don't have enough; punt. */
            YieldControlNoInput(client);
            return 0;
        }
    }
    if (needed == 0) {
        if (client.big_requests)
            needed = xBigReq.sizeof;
        else
            needed = xReq.sizeof;
    }

    /* If there are bytes to ignore, ignore them now. */

    if (oci.ignoreBytes > 0) {
        assert(needed == oci.ignoreBytes || needed == oci.size);
        /*
         * The _XSERVTransRead call above may return more or fewer bytes than we
         * want to ignore.  Ignore the smaller of the two sizes.
         */
        if (gotnow < needed) {
            oci.ignoreBytes -= gotnow;
            oci.bufptr += gotnow;
            gotnow = 0;
        }
        else {
            oci.ignoreBytes -= needed;
            oci.bufptr += needed;
            gotnow -= needed;
        }
        needed = 0;
    }

    oci.lenLastReq = needed;

    /*
     *  Check to see if client has at least one whole request in the
     *  buffer beyond the request we're returning to the caller.
     *  If there is only a partial request, treat like buffer
     *  is empty so that select() will be called again and other clients
     *  can get into the queue.
     */

    gotnow -= needed;
    if (!gotnow && !oci.ignoreBytes)
        AvailableInput = oc;
    if (move_header) {
        if (client.req_len < bytes_to_int32(((xBigReq).sizeof - xReq.sizeof))) {
            YieldControlDeath();
            return -1;
        }

        request = cast(xReq*) oci.bufptr;
        oci.bufptr += (((xBigReq).sizeof - xReq.sizeof));
        *cast(xReq*) oci.bufptr = *request;
        oci.lenLastReq -= (((xBigReq).sizeof - xReq.sizeof));
        client.req_len -= bytes_to_int32(((xBigReq).sizeof - xReq.sizeof));
    }
    client.requestBuffer = cast(void*) oci.bufptr;
version (DEBUG_COMMUNICATION) {
    {
        xReq* req = client.requestBuffer;

        ErrorF("REQUEST: ClientIDX: %i, type: 0x%x data: 0x%x len: %i\n",
               client.index, req.reqType, req.data, req.length);
    }
}
    return needed;
}

int ReadFdFromClient(ClientPtr client)
{
    int fd = -1;

static if (XTRANS_SEND_FDS) {
    if (client.req_fds > 0) {
        OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

        --client.req_fds;
        fd = _XSERVTransRecvFd(oc.trans_conn);
    } else
        LogMessage(X_ERROR, "Request asks for FD without setting req_fds\n");
}

    return fd;
}

int WriteFdToClient(ClientPtr client, int fd, Bool do_close)
{
static if (XTRANS_SEND_FDS) {
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    return _XSERVTransSendFd(oc.trans_conn, fd, do_close);
} else {
    return -1;
}
}

/*****************************************************************
 * InsertFakeRequest
 *    Splice a consed up (possibly partial) request in as the next request.
 *
 **********************/

Bool InsertFakeRequest(ClientPtr client, char* data, int count)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;
    ConnectionInputPtr oci = oc.input;
    int gotnow = void, moveup = void;

    NextAvailableInput(oc);

    if (!oci) {
        if ((oci = FreeInputs) !is null)
            FreeInputs = oci.next;
        else if (((oci = AllocateInputBuffer()) is null))
            return FALSE;
        oc.input = oci;
    }
    oci.bufptr += oci.lenLastReq;
    oci.lenLastReq = 0;
    gotnow = cast(uint)(oci.bufcnt + oci.buffer - oci.bufptr);
    if ((gotnow + count) > oci.size) {
        char* ibuf = void;

        ibuf = cast(char*) realloc(oci.buffer, gotnow + count);
        if (!ibuf)
            return FALSE;
        oci.size = gotnow + count;
        oci.buffer = ibuf;
        oci.bufptr = ibuf + oci.bufcnt - gotnow;
    }
    moveup = cast(int)(count - (oci.bufptr - oci.buffer));
    if (moveup > 0) {
        if (gotnow > 0)
            memmove(oci.bufptr + moveup, oci.bufptr, gotnow);
        oci.bufptr += moveup;
        oci.bufcnt += moveup;
    }
    memmove(oci.bufptr - count, data, count);
    oci.bufptr -= count;
    gotnow += count;
    if ((gotnow >= xReq.sizeof) &&
        (gotnow >= cast(int) (mixin(get_req_len!(`cast(xReq*) oci.bufptr`, `client`)) << 2)))
        mark_client_ready(client);
    else
        YieldControlNoInput(client);
    return TRUE;
}

/*****************************************************************
 * ResetRequestFromClient
 *    Reset to reexecute the current request, and yield.
 *
 **********************/

void ResetCurrentRequest(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    /* ignore dying clients */
    if (!oc)
        return;

    ConnectionInputPtr oci = oc.input;
    xReq* request = void;
    int gotnow = void, needed = void;

    if (AvailableInput == oc)
        AvailableInput = cast(OsCommPtr) null;
    oci.lenLastReq = 0;
    gotnow = cast(int)(oci.bufcnt + oci.buffer - oci.bufptr);
    if (gotnow < xReq.sizeof) {
        YieldControlNoInput(client);
    }
    else {
        request = cast(xReq*) oci.bufptr;
        needed = mixin(get_req_len!(`request`, `client`));
        if (!needed && client.big_requests) {
            oci.bufptr -= ((xBigReq).sizeof - xReq.sizeof);
            *cast(xReq*) oci.bufptr = *request;
            (cast(xBigReq*) oci.bufptr).length = client.req_len;
            if (client.swapped) {
                swapl(&(cast(xBigReq*) oci.bufptr).length);
            }
        }
        if (gotnow >= (needed << 2)) {
            if (listen_to_client(client))
                mark_client_ready(client);
            YieldControl();
        }
        else
            YieldControlNoInput(client);
    }
}

 /********************
 * FlushAllOutput()
 *    Flush all clients with output.  However, if some client still
 *    has input in the queue (more requests), then don't flush.  This
 *    will prevent the output queue from being flushed every time around
 *    the round robin queue.  Now, some say that it SHOULD be flushed
 *    every time around, but...
 *
 **********************/

void FlushAllOutput()
{
    OsCommPtr oc = void;
    ClientPtr client = void, tmp = void;
    Bool newoutput = !!NewOutputPending;

    if (!newoutput)
        return;

    /*
     * It may be that some client still has critical output pending,
     * but he is not yet ready to receive it anyway, so we will
     * simply wait for the select to tell us when he's ready to receive.
     */
    CriticalOutputPending = FALSE;
    NewOutputPending = FALSE;

    mixin(xorg_list_for_each_entry_safe!("client", "tmp", "&output_pending_clients", "output_pending", q{
        if (client.clientGone)
            continue;
        if (!client_is_ready(client)) {
            oc = cast(OsCommPtr) client.osPrivate;
            FlushClient(client, oc);
        } else
            NewOutputPending = TRUE;
    }));
}

void FlushIfCriticalOutputPending()
{
    if (CriticalOutputPending)
        FlushAllOutput();
}

void SetCriticalOutputPending()
{
    CriticalOutputPending = TRUE;
}

/*****************
 * AbortClient:
 *    When a write error occurs to a client, close
 *    the connection and clean things up. Mark
 *    the client as 'ready' so that the server will
 *    try to read from it again, notice that the fd is
 *    closed and clean up from there.
 *****************/

private void AbortClient(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr)client.osPrivate;

    if (oc.trans_conn) {
        CloseDownFileDescriptor(oc);
        mark_client_ready(client);
    }
}

/*
 * make sure we have an output buffer in the OsComm
 */
private bool OutputEnsureBuffer(ClientPtr who, OsCommPtr oc)
{
    if (oc.output)
        return true;

    if ((oc.output = FreeOutputs) !is null) {
        FreeOutputs = oc.output.next;
        return true;
    }

    if ((oc.output = AllocateOutputBuffer())!is null)
        return true;

    AbortClient(who);
    dixMarkClientException(who);
    return false;
}

pragma(inline, true) private int memcpy_and_flush(ClientPtr who, OsCommPtr oc, const(void)* extra_buf, size_t extra_size, size_t padsize)
{
    ConnectionOutputPtr oco = oc.output;

    memcpy(oco.buf + oco.count, extra_buf, extra_size);
    oco.count += extra_size;
    memset(oco.buf + oco.count, 0, padsize);
    oco.count += padsize;
    return (FlushClient(who, oc) == -1) ? -1 : cast(int)extra_size; /* return the requested size, or fail */
}

/*
 * try to make room in the output buffer:
 * if not enough room, try to flush first.
 * if that's not giving enough room, increase the buffer size.
 */
private int OutputBufferMakeRoomAndFlush(ClientPtr who, OsCommPtr oc, const(void)* extra_buf, size_t extra_size)
{
    const(size_t) padsize = padding_for_int32(cast(int)extra_size);
    const(size_t) needed = extra_size + padsize;

    if (oc.output) {
        /* check whether it already fits into buffer */
        if (oc.output.count + needed <= oc.output.size) {
            return memcpy_and_flush(who, oc, extra_buf, extra_size, padsize);
        }

        /* try flushing the buffer */
        if (FlushClient(who, oc) == -1) {
            /* client was aborted */
            return -1;
        }
    }

    if (!OutputEnsureBuffer(who, oc)) {
        return -1;
    }

    ConnectionOutputPtr oco = oc.output;

    /* does it fit this time ? */
    if (oco.count + needed <= oco.size) {
        return memcpy_and_flush(who, oc, extra_buf, extra_size, padsize);
    }

    /* still not enough */
    /* try to resize the buffer */
    int newsize = cast(int)(oco.count + (((needed / BUFSIZE)+1)*BUFSIZE));

    void* newbuf = realloc(oco.buf, newsize);
    if (!newbuf) {
        AbortClient(who);
        dixMarkClientException(who);
        oco.count = 0;
        return -1;
    }

    oco.buf = cast(ubyte*)newbuf;
    oco.size = newsize;

    return memcpy_and_flush(who, oc, extra_buf, extra_size, padsize);
}

/*****************
 * WriteToClient
 *    Copies buf into ClientPtr.buf if it fits (with padding), else
 *    flushes ClientPtr.buf and buf to client.  As of this writing,
 *    every use of WriteToClient is cast to void, and the result
 *    is ignored.  Potentially, this could be used by requests
 *    that are sending several chunks of data and want to break
 *    out of a loop on error.  Thus, we will leave the type of
 *    this routine as int.
 *****************/

int WriteToClient(ClientPtr who, int count, const(void)* __buf)
{
    OsCommPtr oc = void;
    int padBytes = void;
    const(char)* buf = cast(char*)__buf;

    // BUG_RETURN_VAL_MSG(in_input_thread(), 0,
    //                    "******** %s called from input thread *********\n", __FUNCTION__.ptr);
    // return 0;

version (DEBUG_COMMUNICATION) {
    Bool multicount = FALSE;
}
    if (!count || !who || who == serverClient || who.clientGone)
        return 0;
    oc = cast(OsCommPtr)who.osPrivate;
version (DEBUG_COMMUNICATION) {
    {
        char[128] info = void;
        xError* err = void;
        xGenericReply* rep = void;
        xEvent* ev = void;

        if (!who.replyBytesRemaining) {
            switch (buf[0]) {
            case X_Reply:
                rep = cast(xGenericReply*) buf;
                if (rep.sequenceNumber == who.sequence) {
                    snprintf(info.ptr, 127, "Xreply: type: 0x%x data: 0x%x "
                             ~ "len: %i seq#: 0x%x", rep.type, rep.data1,
                             rep.length, rep.sequenceNumber);
                    multicount = TRUE;
                }
                break;
            case X_Error:
                err = cast(xError*) buf;
                snprintf(info.ptr, 127, "Xerror: Code: 0x%x resID: 0x%x maj: 0x%x "
                         ~ "min: %x", err.errorCode, err.resourceID,
                         err.minorCode, err.majorCode);
                break;
            default:
                if ((buf[0] & 0x7f) == KeymapNotify)
                    snprintf(info.ptr, 127, "KeymapNotifyEvent: %i", buf[0]);
                else {
                    ev = cast(xEvent*) buf;
                    snprintf(info.ptr, 127, "XEvent: type: 0x%x detail: 0x%x "
                             ~ "seq#: 0x%x", ev.u.u.type, ev.u.u.detail,
                             ev.u.u.sequenceNumber);
                }
            }
            ErrorF("REPLY: ClientIDX: %i %s\n", who.index, info.ptr);
        }
        else
            multicount = TRUE;
    }
}

    padBytes = padding_for_int32(count);

    if (ReplyCallback) {
        ReplyInfoRec replyinfo = void;

        replyinfo.client = who;
        replyinfo.replyData = buf;
        replyinfo.dataLenBytes = count + padBytes;
        replyinfo.padBytes = padBytes;
        if (who.replyBytesRemaining) { /* still sending data of an earlier reply */
            who.replyBytesRemaining -= count + padBytes;
            replyinfo.startOfReply = FALSE;
            replyinfo.bytesRemaining = who.replyBytesRemaining;
            CallCallbacks((&ReplyCallback), cast(void*) &replyinfo);
        }
        else if (who.clientState == ClientStateRunning && buf[0] == X_Reply) { /* start of new reply */
            CARD32 replylen = void;
            c_ulong bytesleft = void;

            replylen = (cast(const(xGenericReply)*) buf).length;
            if (who.swapped)
                swapl(&replylen);
            bytesleft = (replylen * 4) + xReply.sizeof - count - padBytes;
            replyinfo.startOfReply = TRUE;
            replyinfo.bytesRemaining = who.replyBytesRemaining = cast(int)bytesleft;
            CallCallbacks((&ReplyCallback), cast(void*) &replyinfo);
        }
    }
version (DEBUG_COMMUNICATION) {
    if(multicount) {
        if (who.replyBytesRemaining) {
            who.replyBytesRemaining -= (count + padBytes);
        }
        else {
            CARD32 replylen = void;

            replylen = (cast(xGenericReply*) buf).length;
            who.replyBytesRemaining =
                (replylen * 4) + xReply.sizeof - count - padBytes;
        }
    }
}

    if (!OutputEnsureBuffer(who, oc))
        return -1;

    ConnectionOutputPtr oco = oc.output;

    if ((oco.count == 0 && who.local) || oco.count + count + padBytes > oco.size) {
        output_pending_clear(who);
        if (!any_output_pending()) {
            CriticalOutputPending = FALSE;
            NewOutputPending = FALSE;
        }
        return OutputBufferMakeRoomAndFlush(who, oc, buf, count);
    }

    NewOutputPending = TRUE;
    output_pending_mark(who);
    memmove(cast(char*) oco.buf + oco.count, buf, count);
    oco.count += count;
    if (padBytes) {
        memset(oco.buf + oco.count, '\0', padBytes);
        oco.count += padBytes;
    }
    return count;
}

 /********************
 * FlushClient()
 *    If the client isn't keeping up with us, then we try to continue
 *    buffering the data and set the appropriate bit in ClientsWritable
 *    (which is used by WaitFor in the select).  If the connection yields
 *    a permanent error, or we can't allocate any more space, we then
 *    close the connection.
 *
 **********************/

int FlushClient(ClientPtr who, OsCommPtr oc)
{
    ConnectionOutputPtr oco = oc.output;
    XtransConnInfo trans_conn = oc.trans_conn;

    /* if no output buffer, then nothing to do */
    if (!oco)
	return 0;

    size_t notWritten = oco.count;
    size_t written = 0;
    size_t todo = notWritten; /* trying to write that much this time */
    if (!trans_conn) {
        /* uh, transport not connected ? can only kill the client :( */
        goto abortClient;
    }


    /* do nothing if we haven't anything to write */
    if (!notWritten)
        return 0;

    if (FlushCallback)
        CallCallbacks(&FlushCallback, who);

    while (notWritten) {
        errno = 0;
        ssize_t len = _XSERVTransWrite(trans_conn, (cast(const(char)*)oco.buf) + written, todo);
        if (len >= 0) {
            written += len;
            notWritten -= len;
            todo = notWritten;
        }
        else if (ossock_wouldblock(errno)) {
            /* If we've arrived here, then the client is stuffed to the gills
               and not ready to accept more.  Make a note of it and buffer
               the rest. */
            output_pending_mark(who);

            if (written > 0) {
                oco.count -= written;
                memmove(cast(char*) oco.buf,
                        cast(char*) oco.buf + written, oco.count);
                written = 0;
            }

            oco.count = cast(int)notWritten;
            ospoll_listen(server_poll, oc.fd, X_NOTIFY_WRITE);

            /* return only the amount explicitly requested */
            return 0;
        }
// version (EMSGSIZE) {                 /* check for another brain-damaged OS bug */
//         if(errno == EMSGSIZE) {
//             /* making separate try with half of the size */
//             todo /= 2;
//         }
// }
        else {
            goto abortClient;
        }
    }

    /* everything was flushed out */
    oco.count = 0;
    output_pending_clear(who);

    if (oco.size > BUFWATERMARK) {
        free(oco.buf);
        free(oco);
    }
    else {
        oco.next = FreeOutputs;
        FreeOutputs = oco;
    }
    oc.output = cast(ConnectionOutputPtr) null;
    return 0;          /* return only the amount explicitly requested */

abortClient:
    AbortClient(who);
    dixMarkClientException(who);
    oco.count = 0;
    return -1;
}

private ConnectionInputPtr AllocateInputBuffer()
{
    ConnectionInputPtr oci = cast(ConnectionInput*) calloc(1, ConnectionInput.sizeof);
    if (!oci)
        return null;
    oci.buffer = cast(char*)calloc(1, BUFSIZE);
    if (!oci.buffer) {
        free(oci);
        return null;
    }
    oci.size = BUFSIZE;
    oci.bufptr = oci.buffer;
    oci.bufcnt = 0;
    oci.lenLastReq = 0;
    oci.ignoreBytes = 0;
    return oci;
}

private ConnectionOutputPtr AllocateOutputBuffer()
{
    ConnectionOutputPtr oco = cast(ConnectionOutput*) calloc(1, ConnectionOutput.sizeof);
    if (!oco)
        return null;
    oco.buf = cast(ubyte*)calloc(1, BUFSIZE);
    if (!oco.buf) {
        free(oco);
        return null;
    }
    oco.size = BUFSIZE;
    oco.count = 0;
    return oco;
}

void FreeOsBuffers(OsCommPtr oc)
{
    ConnectionInputPtr oci = void;
    ConnectionOutputPtr oco = void;

    if (AvailableInput == oc)
        AvailableInput = cast(OsCommPtr) null;
    if ((oci = oc.input) !is null) {
        if (FreeInputs) {
            free(oci.buffer);
            free(oci);
        }
        else {
            FreeInputs = oci;
            oci.next = cast(ConnectionInputPtr) null;
            oci.bufptr = oci.buffer;
            oci.bufcnt = 0;
            oci.lenLastReq = 0;
            oci.ignoreBytes = 0;
        }
    }
    if ((oco = oc.output)!is null) {
        if (FreeOutputs) {
            free(oco.buf);
            free(oco);
        }
        else {
            FreeOutputs = oco;
            oco.next = cast(ConnectionOutputPtr) null;
            oco.count = 0;
        }
    }
}

void ResetOsBuffers()
{
    ConnectionInputPtr oci = void;
    ConnectionOutputPtr oco = void;

    while ((oci = FreeInputs)!is null) {
        FreeInputs = oci.next;
        free(oci.buffer);
        free(oci);
    }
    while ((oco = FreeOutputs)!is null) {
        FreeOutputs = oco.next;
        free(oco.buf);
        free(oco);
    }
}
