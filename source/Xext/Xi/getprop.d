module Xi.getprop;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Copyright 1989, 1998  The Open Group

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

Copyright 1989 by Hewlett-Packard Company, Palo Alto, California.

			All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Hewlett-Packard not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

HEWLETT-PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
HEWLETT-PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

********************************************************/

/***********************************************************************
 *
 * Function to return the dont-propagate-list for an extension device.
 *
 */

import build.dix_config;

import externs.X11.extensions.XI;
import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.window_priv;
import Xi.handlers;
public import Xi.extinit;

import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structs    */
import dix.swaprep;
import Xi.getprop;
import externs.X11.extensions.XIproto;
import dix.devices;
import dix.dixutils;
import common.swap;

// XExtEventInfo[1] EventInfo;
// int ExtEventIndex;

/***********************************************************************
 *
 * This procedure lists the input devices available to the server.
 *
 */

int ProcXGetDeviceDontPropagateList(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xGetDeviceDontPropagateListReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    CARD16 count = 0;
    int i = void, rc = void;
    XEventClass* buf = null, tbuf = void;
    WindowPtr pWin = void;
    OtherInputMasks* others = void;

    xGetDeviceDontPropagateListReply reply = {
        RepType: X_GetDeviceDontPropagateList,
    };

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if ((others = mixin(wOtherInputMasks!("pWin"))) !is null) {
        for (i = 0; i < EMASKSIZE; i++)
            ClassFromMask(null, others.dontPropagateMask[i], i, &count, COUNT);
        if (count) {
            reply.count = count;
            buf = cast(XEventClass*) calloc(count, XEventClass.sizeof);
            if (!buf)
                return BadAlloc;

            tbuf = buf;
            for (i = 0; i < EMASKSIZE; i++)
                tbuf = ClassFromMask(tbuf, others.dontPropagateMask[i], i,
                                     null, CREATE);

            x_rpcbuf_write_CARD32s(&rpcbuf, buf, count);
            free(buf);
        }
    }

    mixin(X_REPLY_FIELD_CARD16!"count");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/***********************************************************************
 *
 * This procedure gets a list of event classes from a mask word.
 * A single mask may translate to more than one event class.
 *
 */

XEventClass* ClassFromMask(XEventClass* buf, Mask mask, int maskndx, CARD16* count, int mode)
{
    int i = void, j = void;
    int id = maskndx;
    Mask tmask = 0x80000000;

    for (i = 0; i < 32; i++, tmask >>= 1)
        if (tmask & mask) {
            for (j = 0; j < ExtEventIndex; j++)
                if (EventInfo[j].mask == tmask) {
                    if (mode == COUNT)
                        (*count)++;
                    else
                        *buf++ = (id << 8) | EventInfo[j].type;
                }
        }
    return buf;
}
