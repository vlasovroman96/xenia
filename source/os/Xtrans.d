module os.Xtrans;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*

Copyright 1993, 1994, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

 * Copyright 1993, 1994 NCR Corporation - Dayton, Ohio, USA
 *
 * All Rights Reserved
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name NCR not be used in advertising
 * or publicity pertaining to distribution of the software without specific,
 * written prior permission.  NCR makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 * NCR DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN
 * NO EVENT SHALL NCR BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
import build.xlibre_server;

import core.stdc.ctype;
import core.stdc.stdlib;
import core.stdc.string;
version (HAVE_SYSTEMD_DAEMON) {
import systemd.sd_daemon;
}

import os.ossock;
import os.xhostname;
import os.Xtranssock;
import core.sys.posix.fcntl;
import core.stdc.stdio;
import os.Xtranssock;

import externs.attrs;
/*
 * The transport table contains a definition for every transport (protocol)
 * family. All operations that can be made on the transport go through this
 * table.
 *
 * Each transport is assigned a unique transport id.
 *
 * New transports can be added by adding an entry in this table.
 * For compatibility, the transport ids should never be renumbered.
 * Always add to the end of the list.
 */

enum TRANS_RESET_NOOP =	1;
enum TRANS_RESET_NEW_FD =	2;
enum TRANS_RESET_FAILURE =	3;

enum TRANS_SOCKET_UNIX_INDEX =		4;
enum TRANS_SOCKET_LOCAL_INDEX =	5;
enum TRANS_SOCKET_INET_INDEX =		6;
enum TRANS_SOCKET_TCP_INDEX =		7;
enum TRANS_SOCKET_INET6_INDEX =	14;
import os.Xtransint;
import externs.gnu;
/*
 * Return values of Connect (0 is success)
 */

enum TRANS_CONNECT_FAILED = 	-1;
enum TRANS_TRY_CONNECT_AGAIN = -2;
enum TRANS_IN_PROGRESS =	-3;


/*
 * Return values of CreateListener (0 is success)
 */

enum TRANS_CREATE_LISTENER_FAILED = 	-1;
enum TRANS_ADDR_IN_USE =		-2;

static if (HasVersion!"IPv6" && !HasVersion!"AF_INET6") {
static assert(0, "Cannot build IPv6 support without AF_INET6");
}

import os.Xtranssock;
enum XTRANS_MAX_ADDR_LEN =	128;	/* large enough to hold sun_path */
struct Xtransaddr {
    ubyte[XTRANS_MAX_ADDR_LEN]	addr;
} 

__gshared Xtransport_table[] Xtransport_tabletab;
__gshared Xtransport_table[] Xtransports;

// static this() {
//     Xtransports = Xtransport_tabletab;
// }
import core.attribute : standalone;
extern(D)
@standalone
// // @trusted
// // shared static this()
@system
shared static this()
{
    import core.stdc.stdio : fprintf, stderr;
    //fprintf(stderr, "!!! XTRANS STATIC CTOR !!!\n");
    size_t maxElements = 2; // TCP + INET
    static if(IPv6) {
        maxElements += 1;   // INET6
    }
    static if(UNIXCONN){
        maxElements += 2;   // LOCAL + UNIX
    }

    auto ptr = cast(Xtransport_table*)calloc(
        maxElements,
        Xtransport_table.sizeof
    );

    Xtransport_table[] arr = ptr[0 .. maxElements];
    size_t count = 0;

    arr[count++] = Xtransport_table(
        &_XSERVTransSocketTCPFuncs,
        TRANS_SOCKET_TCP_INDEX
    );

    static if (IPv6)
    {
        arr[count++] = Xtransport_table(
            &_XSERVTransSocketINET6Funcs,
            TRANS_SOCKET_INET6_INDEX
        );
    }

    arr[count++] = Xtransport_table(
        &_XSERVTransSocketINETFuncs,
        TRANS_SOCKET_INET_INDEX
    );

    static if(UNIXCONN)
    {
        arr[count++] = Xtransport_table(
            &_XSERVTransSocketLocalFuncs,
            TRANS_SOCKET_LOCAL_INDEX
        );

        arr[count++] = Xtransport_table(
            &_XSERVTransSocketUNIXFuncs,
            TRANS_SOCKET_UNIX_INDEX
        );
    }

    Xtransport_tabletab = arr;
    Xtransports = Xtransport_tabletab;

    // foreach(tr; Xtransports) {
    //     cast(int)0;
    // }
    // fprintf(stderr, "%d, %d", Xtransport_tabletab.length, Xtransports.length);
}

extern(C):

enum XTRANS_COUNT = 2 + ((IPv6 != 0) ? 1 : 0) + ((UNIXCONN != 0) ? 2 : 0);
enum string NUMTRANS = "XTRANS_COUNT";

/*
 * These are a few utility function used by the public interface functions.
 */
void _XSERVTransFreeConnInfo(XtransConnInfo ciptr)

{
    // pragma(msg, 3,"FreeConnInfo(%p)\n", cast(void*) ciptr);

    if (ciptr.addr)
	free (ciptr.addr);

    if (ciptr.peeraddr)
	free (ciptr.peeraddr);

    if (ciptr.port)
	free (ciptr.port);

    free (ciptr);
}


enum PROTOBUFSIZE =	20;

private Xtransport* _XSERVTransSelectTransport(const(char)* protocol)
{
    for (uint i = 0; i < Xtransports.length; i++)
    {
        if (Xtransports[i].transport is null)
            continue;

        fprintf(stderr,
            "SELECT: '%s' vs '%s'\n",
            protocol,
            Xtransports[i].transport.TransName);

        if (strcasecmp(
                protocol,
                Xtransports[i].transport.TransName) == 0)
        {
            fprintf(stderr, "SELECT: FOUND\n");
            return Xtransports[i].transport;
        }
    }

    fprintf(stderr, "SELECT: NOT FOUND '%s'\n", protocol);
    return null;
}

// private Xtransport* _XSERVTransSelectTransport(const(char)* protocol)

// {
// version (HAVE_STRCASECMP) {} else {
//     char[PROTOBUFSIZE] protobuf = void;
// }

//     // prmsg (3,"SelectTransport(%s)\n", protocol);

// version (HAVE_STRCASECMP) {} else {
//     /*
//      * Force Protocol to be lowercase as a way of doing
//      * a case insensitive match.
//      */

//     strncpy (protobuf.ptr, protocol, PROTOBUFSIZE - 1);
//     protobuf[PROTOBUFSIZE-1] = '\0';

//     for (uint i = 0; i < PROTOBUFSIZE && protobuf[i] != '\0'; i++)
// 	if (isupper (cast(ubyte)protobuf[i]))
// 	    protobuf[i] = cast(char)tolower (cast(ubyte)protobuf[i]);
// }

//     /* Look at all of the configured protocols */

//     for (uint i = 0; i < Xtransports.length; i++)
//     {
// version (HAVE_STRCASECMP) {
//     if (!strcmp (protobuf.ptr, Xtransports[i].transport.TransName)) {
//         return Xtransports[i].transport;
//     }
// } else {
// 	if (!strcasecmp (protocol, Xtransports[i].transport.TransName)) {
// 	    return Xtransports[i].transport;
//     }
// }
//     }
//     return null;
// }

int _XSERVTransParseAddress(const(char)* address, char** protocol, char** host, char** port)

{
    /*
     * For the font library, the address is a string formatted
     * as "protocol/host:port[/catalogue]".  Note that the catologue
     * is optional.  At this time, the catologue info is ignored, but
     * we have to parse it anyways.
     *
     * Other than fontlib, the address is a string formatted
     * as "protocol/host:port".
     *
     * If the protocol part is missing, then assume TCP.
     * If the protocol part and host part are missing, then assume local.
     * If a "::" is found then assume DNET.
     */

    char* mybuf = void, tmpptr = null;
    const(char)* _protocol = null;
    const(char)* _host = void, _port = void;
    char* _host_buf = void;
    int _host_len = void;
    xhostname hn;

    // prmsg (3,"ParseAddress(%s)\n", address);

    enum string HAVE_LAUNCHD_STR = `    if(!strncmp(address,"local//",7)) {
        _protocol="local";
        _host="";
        _port=address+6;
    } else`;
    /* First, check for AF_UNIX socket paths */
    if (address[0] == '/') {
        _protocol = "local";
        _host = "";
        _port = address;
    } else
version (HAVE_LAUNCHD) {
    /* launchd sockets will look like 'local//tmp/launch-XgkNns/:0' */
    mixin(HAVE_LAUNCHD_STR);
}
    if (!strncmp(address, "unix:", 5)) {
        _protocol = "local";
        _host = "";
        _port = address + 5;
    }
    if (_protocol)
        goto done_parsing;

    /* Copy the string so it can be changed */

    tmpptr = mybuf = strdup (address);

    /* Parse the string to get each component */

    /* Get the protocol part */

    _protocol = cast(const(char)*) mybuf;


    if ((mybuf is null) ||
        ( ((mybuf = strchr (mybuf, '/')) is null) &&
          ((mybuf = strrchr (tmpptr, ':')) is null) ) )
    {
	/* address is in a bad format */
	*protocol = null;
	*host = null;
	*port = null;
	free (tmpptr);
	return 0;
    }

    if (*mybuf == ':')
    {
	/*
	 * If there is a hostname, then assume tcp, otherwise
	 * it must be local.
	 */
	if (mybuf == tmpptr)
	{
	    /* There is neither a protocol or host specified */
	    _protocol = "local";
	}
	else
	{
	    /* There is a hostname specified */
	    _protocol = "tcp";
	    mybuf = tmpptr;	/* reset to the beginning of the host ptr */
	}
    }
    else
    {
	/* *mybuf == '/' */

	*mybuf ++= '\0'; /* put a null at the end of the protocol */

	if (strlen(_protocol) == 0)
	{
	    /*
	     * If there is a hostname, then assume tcp, otherwise
	     * it must be local.
	     */
	    if (*mybuf != ':')
		_protocol = "tcp";
	    else
		_protocol = "local";
	}
    }

    /* Get the host part */

    _host = _host_buf = mybuf;

    if ((mybuf = strrchr (mybuf,':')) is null)
    {
	*protocol = null;
	*host = null;
	*port = null;
	free (tmpptr);
	return 0;
    }

    *mybuf ++= '\0';

    _host_len = cast(int)strlen(_host);

    // hn = void;
    // if (_host_len == 0)
    // {
    //     f_xhostname(&hn);
    //     _host = hn.name.ptr;
    // }
static if (IPv6){
enum IPv6_STR = `    if (_host_len == 0)
    {
        f_xhostname(&hn);
        _host = hn.name.ptr;
    }else if ( (_host_len > 3) &&
      ((strcmp(_protocol, "tcp") == 0) || (strcmp(_protocol, "inet6") == 0))
      && (_host_buf[0] == '[') && (_host_buf[_host_len - 1] == ']') ) {
	sockaddr_in6 sin6 = void;

	_host_buf[_host_len - 1] = '\0';

	/* Verify address is valid IPv6 numeric form */
	if (assumeNoGC(&inet_pton)(AF_INET6, _host + 1, &sin6) == 1) {
	    /* It is. Use it as such. */
	    _host++;
	    _protocol = "inet6";
	} else {
	    /* It's not, restore it just in case some other code can use it. */
	    _host_buf[_host_len - 1] = ']';
	}
    }`;
}
else {
    enum IPv6_STR =`    if (_host_len == 0)
    {
        f_xhostname(&hn);
        _host = hn.name.ptr;
    }`;
}

    mixin(IPv6_STR);

    /* Get the port */

    _port = cast(const(char)*) mybuf;

done_parsing:
    /*
     * Now that we have all of the components, allocate new
     * string space for them.
     */

    if ((*protocol = strdup (_protocol)) is null)
    {
    	/* Malloc failed */
        *port = null;
        *host = null;
        *protocol = null;
        free (tmpptr);
        return 0;
    }

    if ((*host = strdup (_host)) is null)
    {
	    /* Malloc failed */ 
        *port = null;
        *host = null;
        free (*protocol);
        *protocol = null;
        free (tmpptr);
        return 0;
    }

    if ((*port = strdup (_port)) is null)
    {
        /* Malloc failed */
        *port = null;
        free (*host);
        *host = null;
        free (*protocol);
        *protocol = null;
        free (tmpptr);
        return 0;
    }

    free (tmpptr);

    return 1;

    // assert(0);
}


/*
 * _XSERVTransOpen does all of the real work opening a connection. The only
 * funny part about this is the type parameter which is used to decide which
 * type of open to perform.
 */

private XtransConnInfo _XSERVTransOpen(int type, const(char)* address)

{
    char* protocol = null, host = null, port = null;
    XtransConnInfo ciptr = null;
    Xtransport* thistrans = void;

    prmsg (2,"Open(%d,%s)\n", type, address);

    ossock_init();

    /* Parse the Address */

    if (_XSERVTransParseAddress (address, &protocol, &host, &port) == 0)
    {
	prmsg (1,"Open: Unable to Parse address %s\n", address);
	return null;
    }

    /* Determine the transport type */

    if ((thistrans = _XSERVTransSelectTransport (protocol)) is null)
    {
	prmsg (1,"Open: Unable to find transport for %s\n",
	       protocol);

	free (protocol);
	free (host);
	free (port);
	return null;
    }

    /* Open the transport */

    switch (type)
    {
    case XTRANS_OPEN_COTS_CLIENT:
	break;
    case XTRANS_OPEN_COTS_SERVER:
	ciptr = thistrans.OpenCOTSServer(thistrans, protocol, host, port);
	break;
    default: break;
	prmsg (1,"Open: Unknown Open type %d\n", type);
    }

    if (ciptr is null)
    {
	if (!(thistrans.flags & TRANS_DISABLED))
	{
	    prmsg (1,"Open: transport open failed for %s/%s:%s\n",
	           protocol, host, port);
        prmsg(1, "flags=%d", thistrans.flags);
	}
	free (protocol);
	free (host);
	free (port);
	return null;
    }

    ciptr.transptr = thistrans;
    ciptr.port = port;			/* We need this for _XSERVTransReopen */

    free (protocol);
    free (host);

    return ciptr;
}

/*
 * We might want to create an XtransConnInfo object based on a previously
 * opened connection.  For example, the font server may clone itself and
 * pass file descriptors to the parent.
 */

private XtransConnInfo _XSERVTransReopen(int type, int trans_id, int fd, const(char)* port)

{
    XtransConnInfo ciptr = null;
    Xtransport* thistrans = null;
    char* save_port = void;

    // prmsg (2,"Reopen(%d,%d,%s)\n", trans_id, fd, port);

    /* Determine the transport type */

    for (uint i = 0; i < mixin(NUMTRANS); i++)
    {
	if (Xtransports[i].transport_id == trans_id)
	{
	    thistrans = Xtransports[i].transport;
	    break;
	}
    }

    if (thistrans is null)
    {
	// prmsg (1,"Reopen: Unable to find transport id %d\n",
	//        trans_id);

	return null;
    }

    if ((save_port = strdup (port)) is null)
    {
	// prmsg (1,"Reopen: Unable to malloc port string\n");

	return null;
    }

    /* Get a new XtransConnInfo object */

    switch (type)
    {
    case XTRANS_OPEN_COTS_SERVER:
	ciptr = thistrans.ReopenCOTSServer(thistrans, fd, port);
	break;
    default: break;
	// prmsg (1,"Reopen: Bad Open type %d\n", type);
    }

    if (ciptr is null)
    {
	// prmsg (1,"Reopen: transport open failed\n");
	free (save_port);
	return null;
    }

    ciptr.transptr = thistrans;
    ciptr.port = save_port;

    return ciptr;
}

/*
 * These are the public interfaces to this Transport interface.
 * These are the only functions that should have knowledge of the transport
 * table.
 */

XtransConnInfo _XSERVTransOpenCOTSServer(const(char)* address)

{
    prmsg (2,"OpenCOTSServer(%s)\n", address);
    return _XSERVTransOpen (XTRANS_OPEN_COTS_SERVER, address);
}

XtransConnInfo _XSERVTransReopenCOTSServer(int trans_id, int fd, const(char)* port)

{
    // prmsg (2,"ReopenCOTSServer(%d, %d, %s)\n", trans_id, fd, port);
    return _XSERVTransReopen (XTRANS_OPEN_COTS_SERVER, trans_id, fd, port);
}

int _XSERVTransNonBlock(XtransConnInfo ciptr)
{
    int fd = ciptr.fd;
    int ret = 0;

version (O_NONBLOCK) {
	    ret = fcntl (fd, F_GETFL, 0);
	    if (ret != -1)
		ret = fcntl (fd, F_SETFL, ret | O_NONBLOCK);
} else {
version (FIOSNBIO) {
	{
	    int arg = void;
	    arg = 1;
	    ret = ossock_ioctl (fd, FIOSNBIO, &arg);
	}
} else {
version (Windows) {
	{
	    u_long arg_ret = 1;
/* IBM TCP/IP understands this option too well: it causes _XSERVTransRead to fail
 * eventually with EWOULDBLOCK */
	    ret = ossock_ioctl (fd, FIONBIO, &arg_ret);
	}
} else {
	    ret = fcntl (fd, F_GETFL, 0);
	    ret = fcntl (fd, F_SETFL, ret | O_NDELAY);
} /* WIN32 */
} /* FIOSNBIO */
} /* O_NONBLOCK */

    return ret;
}

int _XSERVTransCreateListener(XtransConnInfo ciptr, const(char)* port, uint flags)
{
//     fprintf(stderr, "ciptr=%p\n", cast(void*)ciptr);
// fprintf(stderr, "transptr=%p\n", cast(void*)ciptr.transptr);
// fprintf(stderr, "CreateListener=%p\n",
        // cast(void*)ciptr.transptr.CreateListener);
    return ciptr.transptr.CreateListener (ciptr, port, flags);
}

int _XSERVTransReceived(const(char)* protocol)
{
   Xtransport* trans = void;
   int i = 0, ret = 0;

//    prmsg (5, "Received(%s)\n", protocol);

   if ((trans = _XSERVTransSelectTransport(protocol)) is null)
   {
	// prmsg (1,"Received: unable to find transport: %s\n",
	//        protocol);

	return -1;
   }
   if (trans.flags & TRANS_ALIAS) {
       if (trans.nolisten)
	   while (trans.nolisten[i]) {
	       ret |= _XSERVTransReceived(trans.nolisten[i]);
	       i++;
       }
   }

   trans.flags |= TRANS_RECEIVED;
   return ret;
}

int _XSERVTransNoListen(const(char)* protocol)
{
   Xtransport* trans = void;
   int i = 0, ret = 0;

   if ((trans = _XSERVTransSelectTransport(protocol)) is null)
   {
	// prmsg (1,"TransNoListen: unable to find transport: %s\n",
	//        protocol);

	return -1;
   }
   if (trans.flags & TRANS_ALIAS) {
       if (trans.nolisten)
	   while (trans.nolisten[i]) {
	       ret |= _XSERVTransNoListen(trans.nolisten[i]);
	       i++;
       }
   }

   trans.flags |= TRANS_NOLISTEN;
   return ret;
}

int _XSERVTransListen(const(char)* protocol)
{
   Xtransport* trans = void;
   int i = 0, ret = 0;

   if ((trans = _XSERVTransSelectTransport(protocol)) is null)
   {
	// prmsg (1,"TransListen: unable to find transport: %s\n",
	//        protocol);

	return -1;
   }
   if (trans.flags & TRANS_ALIAS) {
       if (trans.nolisten)
	   while (trans.nolisten[i]) {
	       ret |= _XSERVTransListen(trans.nolisten[i]);
	       i++;
       }
   }

   trans.flags &= ~TRANS_NOLISTEN;
   return ret;
}

int _XSERVTransIsListening(const(char)* protocol)
{
   Xtransport* trans = void;

   if ((trans = _XSERVTransSelectTransport(protocol)) is null)
   {
	// prmsg (1,"TransIsListening: unable to find transport: %s\n",
	//        protocol);

	return 0;
   }

   return !(trans.flags & TRANS_NOLISTEN);
}

int _XSERVTransResetListener(XtransConnInfo ciptr)
{
    if (ciptr.transptr.ResetListener)
	return ciptr.transptr.ResetListener (ciptr);
    else
	return TRANS_RESET_NOOP;
}

XtransConnInfo _XSERVTransAccept(XtransConnInfo ciptr)
{
    XtransConnInfo newciptr = void;

    // prmsg (2,"Accept(%d)\n", ciptr.fd);

    newciptr = ciptr.transptr.Accept(ciptr);

    if (newciptr)
	newciptr.transptr = ciptr.transptr;

    return newciptr;
}

int _XSERVTransRead(XtransConnInfo ciptr, char* buf, int size)
{
    return ciptr.transptr.Read (ciptr, buf, size);
}

ssize_t _XSERVTransWrite(XtransConnInfo ciptr, const(char)* buf, size_t size)
{
    return ciptr.transptr.Write (ciptr, buf, size);
}

static if (build.xlibre_server.XTRANS_SEND_FDS) {
int _XSERVTransSendFd(XtransConnInfo ciptr, int fd, int do_close)
{
    return ciptr.transptr.SendFd(ciptr, fd, do_close);
}

int _XSERVTransRecvFd(XtransConnInfo ciptr)
{
    return ciptr.transptr.RecvFd(ciptr);
}
}

int _XSERVTransDisconnect(XtransConnInfo ciptr)
{
    return ciptr.transptr.Disconnect (ciptr);
}

int _XSERVTransClose(XtransConnInfo ciptr)
{
    int ret = void;

    // prmsg (2,"Close(%d)\n", ciptr.fd);

    ret = ciptr.transptr.Close (ciptr);

    _XSERVTransFreeConnInfo (ciptr);

    return ret;
}

int _XSERVTransCloseForCloning(XtransConnInfo ciptr)
{
    int ret = void;

    // prmsg (2,"CloseForCloning(%d)\n", ciptr.fd);

    ret = ciptr.transptr.CloseForCloning (ciptr);

    _XSERVTransFreeConnInfo (ciptr);

    return ret;
}

int _XSERVTransIsLocal(XtransConnInfo ciptr)
{
    return (ciptr.family == AF_UNIX);
}

int _XSERVTransGetPeerAddr(XtransConnInfo ciptr, int* familyp, int* addrlenp, Xtransaddr** addrp)
{
    // prmsg (2,"GetPeerAddr(%d)\n", ciptr.fd);

    *familyp = ciptr.family;
    *addrlenp = ciptr.peeraddrlen;

    if ((*addrp = cast(Xtransaddr*)malloc (ciptr.peeraddrlen)) is null)
    {
	// prmsg (1,"GetPeerAddr: malloc failed\n");
	return -1;
    }
    memcpy(*addrp, ciptr.peeraddr, ciptr.peeraddrlen);

    return 0;
}

int _XSERVTransGetConnectionNumber(XtransConnInfo ciptr)
{
    return ciptr.fd;
}

/*
 * These functions are really utility functions, but they require knowledge
 * of the internal data structures, so they have to be part of the Transport
 * Independent API.
 */
private int complete_network_count()
{
    int count = 0;
    int found_local = 0;

    /*
     * For a complete network, we only need one LOCALCONN transport to work
     */

    for (uint i = 0; i < mixin(NUMTRANS); i++)
    {
	if (Xtransports[i].transport.flags & TRANS_ALIAS
   	 || Xtransports[i].transport.flags & TRANS_NOLISTEN)
	    continue;

	if (Xtransports[i].transport.flags & TRANS_LOCAL)
	    found_local = 1;
	else
	    count++;
    }

    return (count + found_local);
}


private int receive_listening_fds(const(char)* port, XtransConnInfo* temp_ciptrs, uint* count_ret)

{
// version (HAVE_SYSTEMD_DAEMON) {
//     XtransConnInfo ciptr = void;
//     int i = void, systemd_listen_fds = void;

//     systemd_listen_fds = sd_listen_fds(1);
//     if (systemd_listen_fds < 0)
//     {
//         // prmsg (1, "receive_listening_fds: sd_listen_fds error: %s\n",
//         //        strerror(-systemd_listen_fds));
//         return -1;
//     }

//     for (i = 0; i < systemd_listen_fds && *count_ret < cast(int)NUMTRANS; i++)
//     {
//         sockaddr_storage a = void;
//         int ti = void;
//         const(char)* tn = void;
//         socklen_t al = void;

//         al = a.sizeof;
//         if (getsockname(i + SD_LISTEN_FDS_START, cast(sockaddr*)&a, &al) < 0) {
//             // prmsg (1, "receive_listening_fds: getsockname error: %s\n",
//             //        strerror(errno));
//             return -1;
//         }

//         switch (a.ss_family)
//         {
//         case AF_UNIX:
//             ti = TRANS_SOCKET_UNIX_INDEX;
//             if (*(cast(sockaddr_un*)&a).sun_path == '\0' &&
//                 al > sa_family_t.sizeof)
//                 tn = "local";
//             else
//                 tn = "unix";
//             break;
//         case AF_INET:
//             ti = TRANS_SOCKET_INET_INDEX;
//             tn = "inet";
//             break;
// static if (IPv6){
//         case AF_INET6:
//             ti = TRANS_SOCKET_INET6_INDEX;
//             tn = "inet6";
//             break;
// } /* IPv6 */
//         default:
//             // prmsg (1, "receive_listening_fds:"
//             //        ~ "Got unknown socket address family\n");
//             return -1;
//         }

//         ciptr = _XSERVTransReopenCOTSServer(ti, i + SD_LISTEN_FDS_START, port);
//         if (!ciptr)
//         {
//             // prmsg (1, "receive_listening_fds:"
//             //        ~ "Got NULL while trying to reopen socket received from systemd.\n");
//             return -1;
//         }

//         // prmsg (5, "receive_listening_fds: received listener for %s, %d\n",
//         //        tn, ciptr.fd);
//         temp_ciptrs[(*count_ret)++] = ciptr;
//         _XSERVTransReceived(tn);
//     }
// } /* HAVE_SYSTEMD_DAEMON */
    return 0;
}

version (XQUARTZ_EXPORTS_LAUNCHD_FD) {
int xquartz_launchd_fd;
}

int _XSERVTransMakeAllCOTSServerListeners(const(char)* port, int* partial, uint* count_ret, XtransConnInfo** ciptrs_ret)
{
    char[256] buffer = void; /* ??? What size ?? */
    XtransConnInfo ciptr = void; 
    XtransConnInfo[mixin(NUMTRANS)] temp_ciptrs = null;
    int status = void, j = void;

static if (IPv6){
    int ipv6_succ = 0;
}
    prmsg (2,"MakeAllCOTSServerListeners(%s,%p)\n",
	   port ? port : "NULL", cast(void*) ciptrs_ret);

    *count_ret = 0;

// version (XQUARTZ_EXPORTS_LAUNCHD_FD) {
//     fprintf(stderr, "Launchd socket fd: %d\n", xquartz_launchd_fd);
//     if(xquartz_launchd_fd != -1) {
//         auto ciptr = _XSERVTransReopenCOTSServer(TRANS_SOCKET_LOCAL_INDEX,
//                                            xquartz_launchd_fd, getenv("DISPLAY"));
//         if(ciptr is null)
//             fprintf(stderr,"Got NULL while trying to Reopen launchd port\n");
//         else
//             temp_ciptrs[(*count_ret)++] = ciptr;
//     }
// }

    if (receive_listening_fds(port, temp_ciptrs.ptr, count_ret) < 0)
	return -1;

    for (uint i = 0; i < Xtransports.length; i++)
    {
        auto tr = Xtransports[i];
        // cast(void*)tr;
	Xtransport* trans = Xtransports[i].transport;
	uint flags = 0;

        fprintf(stderr,
        "\nALIAS=%u NOLISTEN=%u RECEIVED=%u DISABLED=%u\n",
        (trans.flags & TRANS_ALIAS) != 0,
        (trans.flags & TRANS_NOLISTEN) != 0,
        (trans.flags & TRANS_RECEIVED) != 0,
        (trans.flags & TRANS_DISABLED) != 0
    );
	if (trans.flags&TRANS_ALIAS || trans.flags&TRANS_NOLISTEN ||
	    trans.flags&TRANS_RECEIVED)
	    continue;

	snprintf(buffer.ptr, buffer.sizeof, "%s/:%s",
		 trans.TransName, port ? port : "");

	prmsg (5,"MakeAllCOTSServerListeners: opening %s\n",
	       buffer.ptr);

	if ((ciptr = _XSERVTransOpenCOTSServer(buffer.ptr)) is null)
	{
	    if (trans.flags & TRANS_DISABLED)
		continue;

	    prmsg (1,
	  "MakeAllCOTSServerListeners: failed to open listener for %s\n",
		  trans.TransName);
	    continue;
	}
static if (IPv6){
		if ((Xtransports[i].transport_id == TRANS_SOCKET_INET_INDEX
		     && ipv6_succ))
		    flags |= ADDR_IN_USE_ALLOWED;
}

	if ((status = _XSERVTransCreateListener (ciptr, port, flags)) < 0)
	{
            if (*partial != 0)
		continue;

	    if (status == TRANS_ADDR_IN_USE)
	    {
		/*
		 * We failed to bind to the specified address because the
		 * address is in use.  It must be that a server is already
		 * running at this address, and this function should fail.
		 */

		prmsg (1,
		"MakeAllCOTSServerListeners: server already running\n");

		for (j = 0; j < *count_ret; j++)
		    if (temp_ciptrs[j] !is null)
			_XSERVTransClose (temp_ciptrs[j]);

		*count_ret = 0;
		*ciptrs_ret = null;
		*partial = 0;
		return -1;
	    }
	    else
	    {
		prmsg (1,
	"MakeAllCOTSServerListeners: failed to create listener for %s\n",
		  trans.TransName);

		continue;
	    }
	}

static if (IPv6){
	if (Xtransports[i].transport_id == TRANS_SOCKET_INET6_INDEX)
	    ipv6_succ = 1;
}

	prmsg (5,
	      "MakeAllCOTSServerListeners: opened listener for %s, %d\n",
	      trans.TransName, ciptr.fd);

	temp_ciptrs[*count_ret] = ciptr;
	(*count_ret)++;
    }

    *partial = (*count_ret < complete_network_count());

    prmsg (5,
     "MakeAllCOTSServerListeners: partial=%d, actual=%d, complete=%d \n",
	*partial, *count_ret, complete_network_count());

    if (*count_ret > 0)
    {
	if ((*ciptrs_ret = cast(_XtransConnInfo**)malloc (
	    *count_ret * XtransConnInfo.sizeof)) is null)
	{
	    return -1;
	}

	for (int i = 0; i < *count_ret; i++)
	{
	    (*ciptrs_ret)[i] = temp_ciptrs[i];
	}
    }
    else
	*ciptrs_ret = null;

    return 0;
}
