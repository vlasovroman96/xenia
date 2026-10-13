module os.Xtranssock;
@nogc nothrow:
extern(C): __gshared:

template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (c) 2002, 2025, Oracle and/or its affiliates.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */
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

Except as contained in this notice, the name of the copyright holders shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from the copyright holders.

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

// import core.stdc.ctype;
version (XTHREADS) {
// import externs.X11.Xthreads;
}
// import core.sys.posix.sys.stat;
import std.conv;
// import os.ossock;
import x11.Xos;
import build.xlibre_server;
import core.stdc.string;
import sock = core.sys.posix.sys.socket;
import os.Xtransint;
import core.sys.posix.unistd;
alias rindex = strrchr;
import core.sys.posix.netdb;
import os.ossock;
 import os.io_priv;
 import externs.attrs;
import os.Xtransutil;

alias listen = core.sys.posix.sys.socket.listen;
alias socket = core.sys.posix.sys.socket.socket;

alias sockaddr_in = core.sys.posix.netinet.in_.sockaddr_in;
alias _XGetservbyname = getservbyname;
alias iovec = core.sys.posix.sys.uio.iovec;
alias msghdr = core.sys.posix.sys.socket.msghdr;
alias htons = core.sys.posix.arpa.inet.htons;
alias htonl = core.sys.posix.arpa.inet.htonl;

alias INADDR_ANY = core.sys.posix.netinet.in_.INADDR_ANY;
alias accept = sock.accept;
alias CMSG_LEN = core.sys.posix.sys.socket.CMSG_LEN;
alias CMSG_DATA = core.sys.posix.sys.socket.CMSG_DATA;

alias CMSG_FIRSTHDR = core.sys.posix.sys.socket.CMSG_FIRSTHDR;
alias CMSG_NXTHDR = core.sys.posix.sys.socket.CMSG_NXTHDR;
alias SOL_SOCKET = core.sys.posix.sys.socket.SOL_SOCKET;
alias SCM_RIGHTS = core.sys.posix.sys.socket.SCM_RIGHTS;
    alias shutdown = core.sys.posix.sys.socket.shutdown;




alias cmsghdr = core.sys.posix.sys.socket.cmsghdr;
alias ssize_t = core.sys.posix.sys.types.ssize_t;
version (Windows) {} else {
    
static if(UNIXCONN){
import sock_ = core.sys.posix.sys.un;
import core.sys.posix.netinet.in_;
import core.sys.posix.arpa.inet;
}

static if(UNIXCONN){
version = X_INCLUDE_NETDB_H;
version = XOS_USE_NO_LOCKING;
}

version (NO_TCP_H) {} else {
static if (HasVersion!"linux" || HasVersion!"__GLIBC__") {
// import sys.param;
} /* osf */
static if (HasVersion!"__NetBSD__" || HasVersion!"__OpenBSD__" || HasVersion!"__FreeBSD__" || HasVersion!"__DragonFly__") {
// import sys.param;
// import machine.endian;
} /* __NetBSD__ || __OpenBSD__ || __FreeBSD__ || __DragonFly__ */
// import externs.netinet.tcp;
} /* !NO_TCP_H */

// import core.sys.posix.sys.ioctl;
static if (HasVersion!"SVR4" || HasVersion!"__SVR4") {
// import core.sys.posix.sys.filio;
}

// // import core.sys.posix.unistd;
// import core.sys.posix.sys.socket;

} version (Windows) { /* !WIN32 */

//import externs.X11.Xwinsock;
//import externs.X11.Xwindows;
//import externs.X11.Xw32defs;

// import afunix;

enum EADDRINUSE = WSAEADDRINUSE;
enum EWOULDBLOCK = WSAEWOULDBLOCK;
enum EINTR = WSAEINTR;
version = X_INCLUDE_NETDB_H;
version = XOS_USE_MTSAFE_NETDBAPI;
//import x11.Xos_r;
// import core.sys.posix.netinet.tcp;
} /* WIN32 */
import build.dix_config;

static if (HasVersion!"SO_DONTLINGER" && HasVersion!"SO_LINGER") {
}

/* others don't need this */
//#define SocketInitOnce() /**/

version (linux) {
enum HAVE_ABSTRACT_SOCKETS = 1;
}
else {
    enum HAVE_ABSTRACT_SOCKETS = 0;
}

enum MIN_BACKLOG = 128;
version (SOMAXCONN) {
static if (SOMAXCONN > MIN_BACKLOG) {
enum BACKLOG = SOMAXCONN;
}
}
enum BACKLOG = MIN_BACKLOG;


static if (HasVersion!"IPv6" && !HasVersion!"AF_INET6") {
static assert(0, "Cannot build IPv6 support without AF_INET6");
}

/* Temporary workaround for consumers whose configure scripts were
   generated with pre-1.6 versions of xtrans.m4 */
static if (HasVersion!"IPv6" && !HasVersion!"HAVE_GETADDRINFO") {
version = HAVE_GETADDRINFO;
}

/*
 * This is the Socket implementation of the X Transport service layer
 *
 * This file contains the implementation for both the UNIX and INET domains,
 * and can be built for either one, or both.
 *
 */

struct Sockettrans2dev {
    const(char)* transname;
    int family;
    int devcotsname;
    int devcltsname;
    int protocol;
}

/* As documented in the X(7) man page:
 *  tcp     TCP over IPv4 or IPv6
 *  inet    TCP over IPv4 only
 *  inet6   TCP over IPv6 only
 *  unix    UNIX Domain Sockets (same host only)
 *  local   Platform preferred local connection method
 */
immutable Sockettrans2dev[] Sockettrans2devtab = () {
    // Вычисляем точный размер внутри лямбды времени компиляции
    enum size_t maxElements = () {
        size_t count = 1; // inet
        static if(IPv6) {
            count += 3;
        } else {
            count += 1;
        }
        static if(UNIXCONN){
            count += 2;
        }
        return count;
    }();

    Sockettrans2dev[maxElements] arr;
    size_t count = 0;

    arr[count++] = Sockettrans2dev(
        "inet",
        AF_INET,
        sock.SOCK_STREAM,
        sock.SOCK_DGRAM,
        0
    );

    static if (IPv6)
    {
        arr[count++] = Sockettrans2dev(
            "tcp",
            AF_INET6,
            sock.SOCK_STREAM,
            sock.SOCK_DGRAM,
            0
        );

        // IPv4 fallback
        arr[count++] = Sockettrans2dev(
            "tcp",
            AF_INET,
            sock.SOCK_STREAM,
            sock.SOCK_DGRAM,
            0
        );

        arr[count++] = Sockettrans2dev(
            "inet6",
            AF_INET6,
            sock.SOCK_STREAM,
            sock.SOCK_DGRAM,
            0
        );
    }
    else
    {
        arr[count++] = Sockettrans2dev(
            "tcp",
            AF_INET,
            sock.SOCK_STREAM,
            sock.SOCK_DGRAM,
            0
        );
    }

    static if (UNIXCONN)
    {
        arr[count++] = Sockettrans2dev(
            "unix",
            AF_UNIX,
            sock.SOCK_STREAM,
            sock.SOCK_DGRAM,
            0
        );

        arr[count++] = Sockettrans2dev(
            "local",
            AF_UNIX,
            sock.SOCK_STREAM,
            sock.SOCK_DGRAM,
            0
        );
    }

    return arr.dup; 
}();


enum string NUMSOCKETFAMILIES = "Sockettrans2devtab.sizeof / Sockettrans2dev.sizeof";



int is_numeric(const(char)* str)
{
    for (uint i = 0; i < cast(int) strlen (str); i++)
	if (!isdigit (cast(ubyte)(str[i])))
	    return (0);

    return (1);
}

static if(UNIXCONN){


enum UNIX_PATH = "/tmp/.X11-unix/X";
enum UNIX_DIR = "/tmp/.X11-unix";

} /* UNIXCONN */

enum PORTBUFSIZE =	32;

enum MAXHOSTNAMELEN = 255;


static if (HasVersion!"HAVE_SOCKLEN_T" || HasVersion!"IPv6") {
enum SOCKLEN_T = socklen_t;
} else static if (HasVersion!"SVR4" || HasVersion!"__SVR4") {
enum SOCKLEN_T = size_t;
} else {
alias SOCKLEN_T = int;
}

/*
 * These are some utility function used by the real interface function below.
 */

int _XSERVTransSocketSelectFamily(int first, const(char)* family)
{
    int i = 0;

    prmsg (3,"SocketSelectFamily(%s)\n", family);

    for (i = first + 1; i < cast(int)Sockettrans2devtab.length; i++)
    {
        prmsg(1, "TEST FAMILY %s", Sockettrans2devtab[i].transname);
        if (!strcmp (family, Sockettrans2devtab[i].transname))
	    return i;
    }

    return (first == -1 ? -2 : -1);
}


/*
 * This function gets the local address of the socket and stores it in the
 * XtransConnInfo structure for the connection.
 */


int _XSERVTransSocketINETGetAddr(XtransConnInfo ciptr)
{
version (HAVE_STRUCT_SOCKADDR_STORAGE) {
    sockaddr_storage sockname = void;
} else {
    core.sys.posix.netinet.in_.sockaddr_in sockname = void;
}
    void* socknamePtr = &sockname;
    SOCKLEN_T namelen = sockname.sizeof;

    prmsg (3,"SocketINETGetAddr(%p)\n", cast(void*) ciptr);

    memset(socknamePtr, 0, namelen);

    if (sock.getsockname (ciptr.fd,cast(sock.sockaddr*) socknamePtr,
		     cast(uint*)&namelen) < 0)
    {
version (Windows) {
	errno = WSAGetLastError();
}
	prmsg (1,"SocketINETGetAddr: getsockname() failed: %d\n",
	    mixin(EGET!()));
	return -1;
    }

    /*
     * Everything looks good: fill in the XtransConnInfo structure.
     */

    if ((ciptr.addr = cast(char*)malloc (namelen)) is null)
    {
        prmsg (1,
	    "SocketINETGetAddr: Can't allocate space for the addr\n");
        return -1;
    }

    ciptr.family = (cast(sock.sockaddr*)socknamePtr).sa_family;
    ciptr.addrlen = namelen;
    memcpy (ciptr.addr, socknamePtr, ciptr.addrlen);

    return 0;
}


/*
 * This function gets the remote address of the socket and stores it in the
 * XtransConnInfo structure for the connection.
 */

int _XSERVTransSocketINETGetPeerAddr(XtransConnInfo ciptr)
{
version (HAVE_STRUCT_SOCKADDR_STORAGE) {
    sockaddr_storage sockname = void;
} else {
    core.sys.posix.netinet.in_.sockaddr_in sockname = void;
}
    void* socknamePtr = &sockname;
    SOCKLEN_T namelen = sockname.sizeof;

    memset(socknamePtr, 0, namelen);

    prmsg (3,"SocketINETGetPeerAddr(%p)\n", cast(void*) ciptr);

    if (sock.getpeername (ciptr.fd, cast(sock.sockaddr*) socknamePtr,
		     cast(uint*)&namelen) < 0)
    {
version (Windows) {
	errno = WSAGetLastError();
}
	prmsg (1,"SocketINETGetPeerAddr: getpeername() failed: %d\n",
	    mixin(EGET!()));
	return -1;
    }

    /*
     * Everything looks good: fill in the XtransConnInfo structure.
     */

    if ((ciptr.peeraddr = cast(char*)malloc (namelen)) is null)
    {
        prmsg (1,
	   "SocketINETGetPeerAddr: Can't allocate space for the addr\n");
        return -1;
    }

    ciptr.peeraddrlen = namelen;
    memcpy (ciptr.peeraddr, socknamePtr, ciptr.peeraddrlen);

    return 0;
}


XtransConnInfo _XSERVTransSocketOpen(int i, int type)
{
    XtransConnInfo ciptr = void;

    prmsg (3,"SocketOpen(%d,%d)\n", i, type);

    if ((ciptr = cast(_XtransConnInfo*)calloc (1, _XtransConnInfo.sizeof)) is null)
    {
	prmsg (1, "SocketOpen: malloc failed\n");
	return null;
    }

    ciptr.fd = sock.socket(Sockettrans2devtab[i].family, type,
                       Sockettrans2devtab[i].protocol);

    if (ciptr.fd < 0) {
version (Windows) {
	errno = WSAGetLastError();
}
	prmsg (2, "SocketOpen: socket() failed for %s\n",
	    Sockettrans2devtab[i].transname);

	free (ciptr);
	return null;
    }

version(TCP_NODELAY) {
    static if (IPv6){
    if (Sockettrans2devtab[i].family == AF_INET
      || Sockettrans2devtab[i].family == AF_INET6)
    {
	/*
	 * turn off TCP coalescence for INET sockets
	 */

	int tmp = 1;
	setsockopt (ciptr.fd, IPPROTO_TCP, TCP_NODELAY,
	    cast(char*) &tmp, int.sizeof);
    }
    }
    else {
    if (Sockettrans2devtab[i].family == AF_INET)
    {
	/*
	 * turn off TCP coalescence for INET sockets
	 */

	int tmp = 1;
	setsockopt (ciptr.fd, IPPROTO_TCP, TCP_NODELAY,
	    cast(char*) &tmp, int.sizeof);
    }
    }
}


    /*
     * Some systems provide a really small default buffer size for
     * UNIX sockets.  Bump it up a bit such that large transfers don't
     * proceed at glacial speed.
     */
version (SO_SNDBUF) {
    if (Sockettrans2devtab[i].family == AF_UNIX)
    {
	SOCKLEN_T len = int.sizeof;
	int val = void;

	if (getsockopt (ciptr.fd, SOL_SOCKET, SO_SNDBUF,
	    cast(char*) &val, &len) == 0 && val < 64 * 1024)
	{
	    val = 64 * 1024;
	    setsockopt (ciptr.fd, SOL_SOCKET, SO_SNDBUF,
	        cast(char*) &val, int.sizeof);
	}
    }
}

    return ciptr;
}

XtransConnInfo _XSERVTransSocketReopen(int _X_UNUSED, int type, int fd, const(char)* port)
{
    XtransConnInfo ciptr = void;
    sock.sockaddr* addr = void;
    size_t addrlen = void;

    prmsg (3,"SocketReopen(%d,%d,%s)\n", type, fd, port);

    if (port is null) {
      prmsg (1, "SocketReopen: port was null!\n");
      return null;
    }

    size_t portnamelen = strlen(port) + 1;
    size_t portlen = portnamelen;
version (SOCK_MAXADDRLEN) {
    if (portlen > (SOCK_MAXADDRLEN + 2)) {
      prmsg (1, "SocketReopen: invalid portlen %llu\n", cast(ulong)portlen);
      return null;
    }
    if (portlen < 14) portlen = 14;
} else {
    if (portlen > 14) {
      prmsg (1, "SocketReopen: invalid portlen %llu\n", cast(ulong)portlen);
      return null;
    }
} /*SOCK_MAXADDRLEN*/

    if ((ciptr = cast(_XtransConnInfo*)calloc (1, _XtransConnInfo.sizeof)) is null)
    {
	prmsg (1, "SocketReopen: malloc(ciptr) failed\n");
	return null;
    }

    ciptr.fd = fd;

    addrlen = portlen + offsetof!(sock.sockaddr, "sa_data");
    if ((addr = cast(sock.sockaddr*) calloc (1, addrlen)) is null) {
	prmsg (1, "SocketReopen: malloc(addr) failed\n");
	free (ciptr);
	return null;
    }
    ciptr.addr = cast(char*) addr;
    ciptr.addrlen = cast(int)addrlen;

    if ((ciptr.peeraddr = cast(char*)calloc (1, addrlen)) is null) {
	prmsg (1, "SocketReopen: malloc(portaddr) failed\n");
	free (addr);
	free (ciptr);
	return null;
    }
    ciptr.peeraddrlen = cast(int)addrlen;

    /* Initialize ciptr structure as if it were a normally-opened unix socket */
    ciptr.flags = TRANS_LOCAL | TRANS_NOUNLINK;
version (BSD44SOCKETS) {
    addr.sa_len = addrlen;
}
    addr.sa_family = AF_UNIX;

    memcpy(addr.sa_data.ptr, port, portnamelen);

    ciptr.family = AF_UNIX;
    memcpy(ciptr.peeraddr, ciptr.addr, addrlen);
    ciptr.port = rindex(cast(char*)addr.sa_data.ptr, ':');
    if (ciptr.port is null) {
	if (is_numeric(cast(char*)addr.sa_data.ptr)) {
	    ciptr.port = cast(char*)addr.sa_data.ptr;
	}
    } else if (ciptr.port[0] == ':') {
	ciptr.port++;
    }
    /* port should now point to portnum or NULL */
    return ciptr;
}

/*
 * These functions are the interface supplied in the Xtransport structure
 */

XtransConnInfo _XSERVTransSocketOpenCOTSServer(Xtransport* thistrans, const(char)* protocol, const(char)* host, const(char)* port)
{
    XtransConnInfo ciptr = null;
    int i = -1;

    prmsg (2,"SocketOpenCOTSServer(%s,%s,%s)\n", protocol, host, port);

    // SocketInitOnce();

    while ((i = _XSERVTransSocketSelectFamily (i, thistrans.TransName)) >= 0) {
	if ((ciptr = _XSERVTransSocketOpen (
		 i, Sockettrans2devtab[i].devcotsname)) !is null)
	    break;
    }
    if (i < 0) {
	if (i == -1) {
		if (errno == EAFNOSUPPORT) {
			thistrans.flags |= TRANS_NOLISTEN;
			prmsg (1,"SocketOpenCOTSServer: Socket for %s unsupported on this system.\n",
			       thistrans.TransName);
		} else {
			prmsg (1,"SocketOpenCOTSServer: Unable to open socket for %s\n",
			       thistrans.TransName);
		}
	} else {
	    prmsg (1,"SocketOpenCOTSServer: Unable to determine socket type for %s\n",
		   thistrans.TransName);
	}
	return null;
    }

    /*
     * Using this prevents the bind() check for an existing server listening
     * on the same port, but it is required for other reasons.
     */



version(SO_REUSEADDR) {
    static if (IPv6){
    if (Sockettrans2devtab[i].family == AF_INET
      || Sockettrans2devtab[i].family == AF_INET6)
    {
	/*
	 * turn off TCP coalescence for INET sockets
	 */

	int one = 1;
	setsockopt (ciptr.fd, SOL_SOCKET, SO_REUSEADDR,
		    cast(char*) &one, int.sizeof);
    }
    }
    else {
    if (Sockettrans2devtab[i].family == AF_INET)
    {
	/*
	 * turn off TCP coalescence for INET sockets
	 */

	int one = 1;
	setsockopt (ciptr.fd, SOL_SOCKET, SO_REUSEADDR,
		    cast(char*) &one, int.sizeof);
    }
    }
}
version (IPV6_V6ONLY) {
    if (Sockettrans2devtab[i].family == AF_INET6)
    {
	int one = 1;
	setsockopt(ciptr.fd, IPPROTO_IPV6, IPV6_V6ONLY, &one, int.sizeof);
    }
}
    /* Save the index for later use */

    ciptr.index = i;

    return ciptr;
}

XtransConnInfo _XSERVTransSocketReopenCOTSServer(Xtransport* thistrans, int fd, const(char)* port)
{
    XtransConnInfo ciptr = void;
    int i = -1;

    prmsg (2,
	"SocketReopenCOTSServer(%d, %s)\n", fd, port);

    // SocketInitOnce();

    while ((i = _XSERVTransSocketSelectFamily (i, thistrans.TransName)) >= 0) {
	if ((ciptr = _XSERVTransSocketReopen (
		 i, Sockettrans2devtab[i].devcotsname, fd, port)) !is null)
	    break;
    }
    if (i < 0) {
	if (i == -1)
	    prmsg (1,"SocketReopenCOTSServer: Unable to open socket for %s\n",
		   thistrans.TransName);
	else
	    prmsg (1,"SocketReopenCOTSServer: Unable to determine socket type for %s\n",
		   thistrans.TransName);
	return null;
    }

    /* Save the index for later use */

    ciptr.index = i;

    return ciptr;
}

int _XSERVTransSocketSetOption(XtransConnInfo ciptr, int option, int arg)
{
    prmsg (2,"SocketSetOption(%d,%d,%d)\n", ciptr.fd, option, arg);
    return -1;
}

static if(UNIXCONN){
int set_sun_path(const(char)* port, const(char)* upath, char* path, int abstract_)
{
    sock_.sockaddr_un s = void;
    ssize_t maxlen = ((s.sun_path).sizeof - 1);
    const(char)* at = "";

    if (!port || !*port || !path)
	return -1;

static if (HAVE_ABSTRACT_SOCKETS) {
    if (port[0] == '@')
	upath = "";
    else if (abstract_)
	at = "@";
}

    if (*port == '/') /* a full pathname */
	upath = "";

    if (cast(ssize_t)(strlen(at) + strlen(upath) + strlen(port)) > maxlen)
	return -1;
    snprintf(path, typeof(s.sun_path).sizeof, "%s%s%s", at, upath, port);
    return 0;
}
}

int _XSERVTransSocketCreateListener(
    XtransConnInfo ciptr,
    sock.sockaddr* sockname,
    int socknamelen,
    uint flags
)
{
    SOCKLEN_T namelen = socknamelen;
    int fd = ciptr.fd;

    bool inetFamily =
        Sockettrans2devtab[ciptr.index].family == AF_INET;

    version (IPv6)
    {
        inetFamily |=
            Sockettrans2devtab[ciptr.index].family == AF_INET6;
    }

    int retry = inetFamily ? 20 : 0;

    prmsg(3, "SocketCreateListener(%p,%d)\n",
        cast(void*) ciptr,
        fd);

    while (bind(fd, sockname, namelen) < 0)
    {
        if (errno == EADDRINUSE)
        {
            if (flags & ADDR_IN_USE_ALLOWED)
                break;

            return TRANS_ADDR_IN_USE;
        }

        if (retry-- == 0)
        {
            prmsg(1,
                "SocketCreateListener: failed to bind listener\n");

            ossock_close(fd);

            return TRANS_CREATE_LISTENER_FAILED;
        }

        version (SO_REUSEADDR)
        {
            sleep(1);
        }
        else
        {
            sleep(10);
        }
    }

    if (inetFamily)
    {
        version (SO_DONTLINGER)
        {
            setsockopt(
                fd,
                SOL_SOCKET,
                SO_DONTLINGER,
                cast(char*) null,
                0
            );
        }
        else version (SO_LINGER)
        {
            static int[2] linger = [0, 0];

            setsockopt(
                fd,
                SOL_SOCKET,
                SO_LINGER,
                cast(char*) linger.ptr,
                linger.sizeof
            );
        }
    }

    if (sock.listen(fd, BACKLOG) < 0)
    {
        prmsg(1,
            "SocketCreateListener: listen() failed\n");

        ossock_close(fd);

        return TRANS_CREATE_LISTENER_FAILED;
    }

    // Mark as listener
    ciptr.flags = 1 | (ciptr.flags & TRANS_KEEPFLAGS);

    return 0;
}

int _XSERVTransSocketINETCreateListener(XtransConnInfo ciptr, const(char)* port, uint flags)
{
version (HAVE_STRUCT_SOCKADDR_STORAGE) {
    sock.sockaddr_storage sockname = void;
} else {
    core.sys.posix.netinet.in_.sockaddr_in sockname = void;
}
    ushort sport = void;
    SOCKLEN_T namelen = sockname.sizeof;
    int status = void;
    c_long tmpport = void;
version (XTHREADS_NEEDS_BYNAMEPARAMS) {
    _Xgetservbynameparams sparams = void;
}
    servent* servp = void;

    char[PORTBUFSIZE] portbuf = void;

    prmsg (2, "SocketINETCreateListener(%s)\n", port);

    /*
     * X has a well known port, that is transport dependent. It is easier
     * to handle it here, than try and come up with a transport independent
     * representation that can be passed in and resolved the usual way.
     *
     * The port that is passed here is really a string containing the idisplay
     * from ConnectDisplay().
     */

    if (is_numeric (port))
    {
	/* fixup the server port address */
	tmpport = X_TCP_PORT + strtol (port, cast(char**)null, 10);
	snprintf (portbuf.ptr, portbuf.sizeof, "%lu", tmpport);
	port = portbuf.ptr;
    }

    if (port && *port)
    {
	/* Check to see if the port string is just a number (handles X11) */

	if (!is_numeric (port))
	{
	    if ((servp = _XGetservbyname (port,"tcp".ptr)) is null)
	    {
		prmsg (1,
	     "SocketINETCreateListener: Unable to get service for %s\n",
		      port);
		return TRANS_CREATE_LISTENER_FAILED;
	    }
	    /* we trust getservbyname to return a valid number */
	    sport = cast(ushort)servp.s_port;
	}
	else
	{
	    tmpport = strtol (port, cast(char**)null, 10);
	    /*
	     * check that somehow the port address isn't negative or in
	     * the range of reserved port addresses. This can happen and
	     * be very bad if the server is suid-root and the user does
	     * something (dumb) like `X :60049`.
	     */
	    if (tmpport < 1024 || tmpport > USHRT_MAX)
		return TRANS_CREATE_LISTENER_FAILED;

	    sport = cast(ushort) tmpport;
	}
    }
    else
	sport = 0;

    memset(&sockname, 0, sockname.sizeof);
    if (Sockettrans2devtab[ciptr.index].family == AF_INET) {
	namelen = sockaddr_in.sizeof;
version (BSD44SOCKETS) {
	(cast(sockaddr_in*)&sockname).sin_len = namelen;
}
	(cast(sockaddr_in*)&sockname).sin_family = AF_INET;
	(cast(sockaddr_in*)&sockname).sin_port = htons(sport);
	(cast(sockaddr_in*)&sockname).sin_addr.s_addr = htonl(INADDR_ANY);
    } else {
static if (IPv6){
	namelen = core.sys.posix.netinet.in_.sockaddr_in6.sizeof;
version (SIN6_LEN) {
	(cast(sockaddr_in6*)&sockname).sin6_len = sockname.sizeof;
}
	(cast(core.sys.posix.netinet.in_.sockaddr_in6*)&sockname).sin6_family = AF_INET6;
	(cast(core.sys.posix.netinet.in_.sockaddr_in6*)&sockname).sin6_port = htons(sport);
	(cast(core.sys.posix.netinet.in_.sockaddr_in6*)&sockname).sin6_addr = core.sys.posix.netinet.in_.in6addr_any;
} else {
        prmsg (1,
               "SocketINETCreateListener: unsupported address family %d\n",
               Sockettrans2devtab[ciptr.index].family);
        return TRANS_CREATE_LISTENER_FAILED;
}
    }

    if ((status = _XSERVTransSocketCreateListener (ciptr,
	cast(sock.sockaddr*) &sockname, namelen, flags)) < 0)
    {
	prmsg (1,
    "SocketINETCreateListener: ...SocketCreateListener() failed\n");
	return status;
    }

    if (_XSERVTransSocketINETGetAddr (ciptr) < 0)
    {
	prmsg (1,
       "SocketINETCreateListener: ...SocketINETGetAddr() failed\n");
	return TRANS_CREATE_LISTENER_FAILED;
    }

    return 0;
}

static if(UNIXCONN){

int _XSERVTransSocketUNIXCreateListener(XtransConnInfo ciptr, const(char)* port, uint flags)
{
    sock_.sockaddr_un sockname = void;
    int namelen = void;
    int oldUmask = void;
    int status = void;
    uint mode = void;
    char[108] tmpport = void;

    int abstract_ = 0;
static if (HAVE_ABSTRACT_SOCKETS) {
    abstract_ = ciptr.transptr.flags & TRANS_ABSTRACT;
}

    prmsg (2, "SocketUNIXCreateListener(%s)\n",
	port ? port : "NULL");

    /* Make sure the directory is created */

    oldUmask = umask (0);

static if (UNIXCONN) {
version (HAS_STICKY_DIR_BIT) {
    mode = octal!"01777";
} else {
    mode = octal!"0777";
}
    if (!abstract_ && trans_mkdir(UNIX_DIR.ptr, mode) == -1) {
	prmsg (1, "SocketUNIXCreateListener: mkdir(%s) failed, errno = %d\n",
	       UNIX_DIR.ptr, errno);
	cast(void) umask (oldUmask);
	return TRANS_CREATE_LISTENER_FAILED;
    }
}

    memset(&sockname, 0, sockname.sizeof);
    sockname.sun_family = AF_UNIX;

    if (!(port && *port)) {
	snprintf (tmpport.ptr, tmpport.sizeof, "%s%ld", UNIX_PATH.ptr, cast(c_long)getpid());
	port = tmpport.ptr;
    }
    if (set_sun_path(port, UNIX_PATH, cast(char*)sockname.sun_path.ptr, abstract_) != 0) {
	prmsg (1, "SocketUNIXCreateListener: path too long\n");
	return TRANS_CREATE_LISTENER_FAILED;
    }

version (BSD44SOCKETS) {
    sockname.sun_len = strlen(sockname.sun_path);
}

static if (HasVersion!"BSD44SOCKETS" || HasVersion!"SUN_LEN") {
    namelen = SUN_LEN(&sockname);
} else {
    namelen = cast(int)(strlen(cast(char*)sockname.sun_path.ptr) + offsetof!(sock_.sockaddr_un, "sun_path"));
}

    if (abstract_) {
	sockname.sun_path[0] = '\0';
	namelen = cast(int)(offsetof!(sock_.sockaddr_un, "sun_path") + 1 + strlen(cast(char*)sockname.sun_path.ptr + 1));
    }
    else
	unlink (cast(char*)sockname.sun_path.ptr);

    if ((status = _XSERVTransSocketCreateListener (ciptr,
	cast(sock.sockaddr*) &sockname, namelen, flags)) < 0)
    {
	prmsg (1,
    "SocketUNIXCreateListener: ...SocketCreateListener() failed\n");
	cast(void) umask (oldUmask);
	return status;
    }

    /*
     * Now that the listener is esablished, create the addr info for
     * this connection. getpeername() doesn't work for UNIX Domain Sockets
     * on some systems (hpux at least), so we will just do it manually, instead
     * of calling something like _XSERVTransSocketUNIXGetAddr.
     */

    namelen = sockname.sizeof; /* this will always make it the same size */

    if ((ciptr.addr = cast(char*)malloc (namelen)) is null)
    {
        prmsg (1,
        "SocketUNIXCreateListener: Can't allocate space for the addr\n");
	cast(void) umask (oldUmask);
        return TRANS_CREATE_LISTENER_FAILED;
    }

    if (abstract_)
	sockname.sun_path[0] = '@';

    ciptr.family = sockname.sun_family;
    ciptr.addrlen = namelen;
    memcpy (ciptr.addr, &sockname, ciptr.addrlen);

    cast(void) umask (oldUmask);

    return 0;
}


int _XSERVTransSocketUNIXResetListener(XtransConnInfo ciptr)
{
    /*
     * See if the unix domain socket has disappeared.  If it has, recreate it.
     */

    sock_.sockaddr_un* unsock = cast(sock_.sockaddr_un*) ciptr.addr;
    stat_t statb = void;
    int status = TRANS_RESET_NOOP;
    uint mode = void;
    int abstract_ = 0;
static if (HAVE_ABSTRACT_SOCKETS) {
    abstract_ = ciptr.transptr.flags & TRANS_ABSTRACT;
}

    prmsg (3, "SocketUNIXResetListener(%p,%d)\n", cast(void*) ciptr, ciptr.fd);

    if (!abstract_ && (
	stat (cast(char*)unsock.sun_path.ptr, &statb) == -1 ||
        ((statb.st_mode & S_IFMT) !=
// #if !defined(S_IFSOCK)
// 	  		S_IFIFO
// } else {
			S_IFSOCK
// }
				)))
    {
	int oldUmask = umask (0);

static if  (UNIXCONN) {
version (HAS_STICKY_DIR_BIT) {
	mode = octal!"01777";
} else {
	mode = octal!"0777";
}
        if (trans_mkdir(UNIX_DIR, mode) == -1) {
            prmsg (1, "SocketUNIXResetListener: mkdir(%s) failed, errno = %d\n",
	    UNIX_DIR.ptr, errno);
	    cast(void) umask (oldUmask);
	    return TRANS_RESET_FAILURE;
        }
}

	ossock_close(ciptr.fd);
	unlink (cast(char*)unsock.sun_path.ptr);

	if ((ciptr.fd = assumeNoGC(&socket) (AF_UNIX, sock.SOCK_STREAM, 0)) < 0)
	{
	    _XSERVTransFreeConnInfo (ciptr);
	    cast(void) umask (oldUmask);
	    return TRANS_RESET_FAILURE;
	}

	if (bind (ciptr.fd, cast(sock.sockaddr*) unsock, ciptr.addrlen) < 0)
	{
	    ossock_close(ciptr.fd);
	    _XSERVTransFreeConnInfo (ciptr);
	    return TRANS_RESET_FAILURE;
	}

	if (assumeNoGC(&listen) (ciptr.fd, BACKLOG) < 0)
	{
	    ossock_close(ciptr.fd);
	    _XSERVTransFreeConnInfo (ciptr);
	    cast(void) umask (oldUmask);
	    return TRANS_RESET_FAILURE;
	}

	umask (oldUmask);

	status = TRANS_RESET_NEW_FD;
    }

    return status;
}
}


/* UNIXCONN */


XtransConnInfo _XSERVTransSocketINETAccept(XtransConnInfo ciptr)
{
    XtransConnInfo newciptr = void;
    sockaddr_in sockname = void;
    SOCKLEN_T namelen = sockname.sizeof;

    prmsg (2, "SocketINETAccept(%p,%d)\n", cast(void*) ciptr, ciptr.fd);

    if ((newciptr = cast(_XtransConnInfo*)calloc (1, _XtransConnInfo.sizeof)) is null)
    {
	prmsg (1, "SocketINETAccept: malloc failed\n");
	return null;
    }

    if ((newciptr.fd = accept (ciptr.fd,
	cast(sock.sockaddr*) &sockname, cast(uint*)&(namelen))) < 0)
    {
version (Windows) {
	errno = WSAGetLastError();
}
	prmsg (1, "SocketINETAccept: accept() failed\n");
	free (newciptr);
	return null;
    }

version (TCP_NODELAY) {
    {
	/*
	 * turn off TCP coalescence for INET sockets
	 */

	int tmp = 1;
	setsockopt (newciptr.fd, IPPROTO_TCP, TCP_NODELAY,
	    cast(char*) &tmp, int.sizeof);
    }
}

    /*
     * Get this address again because the transport may give a more
     * specific address now that a connection is established.
     */

    if (_XSERVTransSocketINETGetAddr (newciptr) < 0)
    {
	prmsg (1,
	    "SocketINETAccept: ...SocketINETGetAddr() failed:\n");
	ossock_close(newciptr.fd);
	free (newciptr);
        return null;
    }

    if (_XSERVTransSocketINETGetPeerAddr (newciptr) < 0)
    {
	prmsg (1,
	  "SocketINETAccept: ...SocketINETGetPeerAddr() failed:\n");
	ossock_close(newciptr.fd);
	if (newciptr.addr) free (newciptr.addr);
	free (newciptr);
        return null;
    }

    return newciptr;
}

static if(UNIXCONN){
XtransConnInfo _XSERVTransSocketUNIXAccept(XtransConnInfo ciptr)
{
    XtransConnInfo newciptr = void;
    sock_.sockaddr_un sockname = void;
    SOCKLEN_T namelen = sockname.sizeof;

    prmsg (2, "SocketUNIXAccept(%p,%d)\n", cast(void*) ciptr, ciptr.fd);

    if ((newciptr = cast(_XtransConnInfo*)calloc (1, _XtransConnInfo.sizeof)) is null)
    {
	prmsg (1, "SocketUNIXAccept: malloc() failed\n");
	return null;
    }

    if ((newciptr.fd = accept (ciptr.fd,
	cast(sock.sockaddr*) &sockname, cast(uint*)&namelen)) < 0)
    {
	prmsg (1, "SocketUNIXAccept: accept() failed\n");
	free (newciptr);
	return null;
    }

	ciptr.addrlen = namelen;
    /*
     * Get the socket name and the peer name from the listener socket,
     * since this is unix domain.
     */

    if ((newciptr.addr = cast(char*)malloc (ciptr.addrlen)) is null)
    {
        prmsg (1,
        "SocketUNIXAccept: Can't allocate space for the addr\n");
	ossock_close(newciptr.fd);
	free (newciptr);
        return null;
    }

    /*
     * if the socket is abstract, we already modified the address to have a
     * @ instead of the initial NUL, so no need to do that again here.
     */

    newciptr.addrlen = ciptr.addrlen;
    memcpy (newciptr.addr, ciptr.addr, newciptr.addrlen);

    if ((newciptr.peeraddr = cast(char*)malloc (ciptr.addrlen)) is null)
    {
        prmsg (1,
	      "SocketUNIXAccept: Can't allocate space for the addr\n");
	ossock_close(newciptr.fd);
	if (newciptr.addr) free (newciptr.addr);
	free (newciptr);
        return null;
    }

    newciptr.peeraddrlen = ciptr.addrlen;
    memcpy (newciptr.peeraddr, ciptr.addr, newciptr.addrlen);

    newciptr.family = AF_UNIX;

    return newciptr;
}

} /* UNIXCONN */

static if (build.xlibre_server.XTRANS_SEND_FDS) {

void appendFd(_XtransConnFd** prev, int fd, int do_close)
{
    _XtransConnFd* cf = void, new_ = void;

    new_ = cast(_XtransConnFd*)malloc (_XtransConnFd.sizeof);
    if (!new_) {
        /* XXX mark connection as broken */
        ossock_close(fd);
        return;
    }
    new_.next = null;
    new_.fd = fd;
    new_.do_close = do_close;
    /* search to end of list */
    for (; ((cf = *prev) !is null); prev = &(cf.next)){}
    *prev = new_;
}

int removeFd(_XtransConnFd** prev)
{
    _XtransConnFd* cf = void;
    int fd = void;

    if ((cf = *prev) !is null) {
        *prev = cf.next;
        fd = cf.fd;
        free(cf);
    } else
        fd = -1;
    return fd;
}

void discardFd(_XtransConnFd** prev, _XtransConnFd* upto, int do_close)
{
    _XtransConnFd* cf = void, next = void;

    for (cf = *prev; cf != upto; cf = next) {
        next = cf.next;
        if (do_close || cf.do_close)
            ossock_close(cf.fd);
        free(cf);
    }
    *prev = upto;
}

void cleanupFds(XtransConnInfo ciptr)
{
    /* Clean up the send list but don't close the fds */
    discardFd(&ciptr.send_fds, null, 0);
    /* Clean up the recv list and *do* close the fds */
    discardFd(&ciptr.recv_fds, null, 1);
}

int nFd(_XtransConnFd** prev)
{
    _XtransConnFd* cf = void;
    int n = 0;

    for (cf = *prev; cf; cf = cf.next)
        n++;
    return n;
}

int _XSERVTransSocketRecvFd(XtransConnInfo ciptr)
{
    prmsg (2, "SocketRecvFd(%d)\n", ciptr.fd);
    return removeFd(&ciptr.recv_fds);
}

int _XSERVTransSocketSendFd(XtransConnInfo ciptr, int fd, int do_close)
{
    appendFd(&ciptr.send_fds, fd, do_close);
    return 0;
}

int _XSERVTransSocketRecvFdInvalid(XtransConnInfo ciptr)
{
    errno = EINVAL;
    return -1;
}

int _XSERVTransSocketSendFdInvalid(XtransConnInfo ciptr, int fd, int do_close)
{
    errno = EINVAL;
    return -1;
}

enum MAX_FDS =		128;

union fd_pass {
	sock.cmsghdr cmsghdr_;
	char[sock.CMSG_SPACE(MAX_FDS * int.sizeof)] buf;
};

} /* XTRANS_SEND_FDS */

int _XSERVTransSocketRead(XtransConnInfo ciptr, char* buf, int size)
{
    // prmsg (2,"SocketRead(%d,%p,%d)\n", ciptr.fd, cast(void*) buf, size);

version (Windows) {
    {
	int ret = recv (cast(SOCKET)ciptr.fd, buf.ptr, size, 0);
version (Windows) {
	if (ret == SOCKET_ERROR) errno = WSAGetLastError();
}
	return ret;
    }
} else {
static if (build.xlibre_server.XTRANS_SEND_FDS) {
    {
        iovec iov = {
            iov_base: buf,
            iov_len: size
        };
        fd_pass cmsgbuf = void;
        msghdr msg = {
            msg_name: null,
            msg_namelen: 0,
            msg_iov: &iov,
            msg_iovlen: 1,
            msg_control: cast(void*)cmsgbuf.buf.ptr,
            msg_controllen: cast(int)CMSG_LEN(MAX_FDS * int.sizeof)
        };

        size = cast(int)recvmsg(ciptr.fd, &msg, 0);
        if (size >= 0) {
            cmsghdr* hdr = void;

            for (hdr = CMSG_FIRSTHDR(&msg); hdr; hdr = CMSG_NXTHDR(&msg, hdr)) {
                if (hdr.cmsg_level == SOL_SOCKET && hdr.cmsg_type == SCM_RIGHTS) {
                    int nfd = cast(int)((hdr.cmsg_len - CMSG_LEN(0)) / int.sizeof);
                    int i = void;
                    int* fd = cast(int*) CMSG_DATA(hdr);

                    for (i = 0; i < nfd; i++)
                        appendFd(&ciptr.recv_fds, fd[i], 0);
                }
            }
        }
        return size;
    }
} else {
    return cast(int)read(ciptr.fd, buf, size);
} /* XTRANS_SEND_FDS */
} /* WIN32 */
}

ssize_t _XSERVTransSocketWrite(XtransConnInfo ciptr, const(char)* buf, size_t size)
{
    // prmsg (2,"SocketWrite(%d,%p,%lu)\n", ciptr.fd, cast(void*) buf, cast(c_ulong)size);

static if (build.xlibre_server.XTRANS_SEND_FDS) {
    if (ciptr.send_fds)
    {
        fd_pass cmsgbuf = void;
        int nfd = nFd(&ciptr.send_fds);
        _XtransConnFd* cf = ciptr.send_fds;
        iovec iov = {
            iov_len: size,
            iov_base: cast(char*)buf,
        };
        msghdr msg = {
            msg_name: null,
            msg_namelen: 0,
            msg_iov: &iov,
            msg_iovlen: 1,
            msg_control: cmsgbuf.buf.ptr,
            msg_controllen: CMSG_LEN(nfd * int.sizeof)
        };
        cmsghdr* hdr = CMSG_FIRSTHDR(&msg);
        ssize_t i = void;
        int* fds = void;

        hdr.cmsg_len = msg.msg_controllen;
        hdr.cmsg_level = SOL_SOCKET;
        hdr.cmsg_type = SCM_RIGHTS;

        fds = cast(int*) CMSG_DATA(hdr);
        /* Set up fds */
        for (i = 0; i < nfd; i++) {
            fds[i] = cf.fd;
            cf = cf.next;
        }

        i = sendmsg(ciptr.fd, &msg, 0);
        if (i > 0)
            discardFd(&ciptr.send_fds, cf, 0);
        return i;
    }
}

version (Windows) {
    int ret = send (cast(SOCKET)ciptr.fd, buf.ptr, size, 0);
    if (ret == SOCKET_ERROR) errno = WSAGetLastError();
    return ret;
} else {
    return write (ciptr.fd, buf, size);
}
}

int _XSERVTransSocketDisconnect(XtransConnInfo ciptr)
{
    prmsg (2,"SocketDisconnect(%p,%d)\n", cast(void*) ciptr, ciptr.fd);

version (Windows) {
    {
	int ret = shutdown (ciptr.fd, 2);
	if (ret == SOCKET_ERROR) errno = WSAGetLastError();
	return ret;
    }
} else {
    return shutdown (ciptr.fd, 2); /* disallow further sends and receives */
}
}

static if(UNIXCONN){
int _XSERVTransSocketUNIXClose(XtransConnInfo ciptr)
{
    /*
     * If this is the server side, then once the socket is closed,
     * it must be unlinked to completely close it
     */

    sock_.sockaddr_un* sockname = cast(sock_.sockaddr_un*) ciptr.addr;
    int ret = void;

    prmsg (2,"SocketUNIXClose(%p,%d)\n", cast(void*) ciptr, ciptr.fd);

static if (build.xlibre_server.XTRANS_SEND_FDS) {
    cleanupFds(ciptr);
}
    ret = ossock_close(ciptr.fd);

    if (ciptr.flags
       && sockname
       && sockname.sun_family == AF_UNIX
       && sockname.sun_path[0])
    {
	if (!(ciptr.flags & TRANS_NOUNLINK
	    || ciptr.transptr.flags & TRANS_ABSTRACT))
		unlink (cast(char*)sockname.sun_path.ptr);
    }

    return ret;
}

int _XSERVTransSocketUNIXCloseForCloning(XtransConnInfo ciptr)
{
    /*
     * Don't unlink path.
     */
    prmsg (2,"SocketUNIXCloseForCloning(%p,%d)\n",
	cast(void*) ciptr, ciptr.fd);

static if (build.xlibre_server.XTRANS_SEND_FDS) {
    cleanupFds(ciptr);
}
    return ossock_close(ciptr.fd);
}

} /* UNIXCONN */

int _XSERVTransSocketINETClose(XtransConnInfo ciptr)
{
    prmsg (2,"SocketINETClose(%p,%d)\n", cast(void*) ciptr, ciptr.fd);
    return ossock_close(ciptr.fd);
}

enum const(char)*[3] tcp_nolisten = [
	"inet",
	"inet6", //!! We dont need inet6 if IPv6 version is disabled
	null
];

static if(build.xlibre_server.XTRANS_SEND_FDS) {
    Xtransport _XSERVTransSocketTCPFuncs = {
	/* Socket Interface */
	"tcp",
        TRANS_ALIAS,
	tcp_nolisten.ptr,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketINETCreateListener,
	null,		       			/* ResetListener */
	&_XSERVTransSocketINETAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
    &_XSERVTransSocketSendFdInvalid,
    &_XSERVTransSocketRecvFdInvalid,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketINETClose,
	&_XSERVTransSocketINETClose,
};
}
else {
    Xtransport _XSERVTransSocketTCPFuncs = {
	/* Socket Interface */
	"tcp",
        TRANS_ALIAS,
	tcp_nolisten.ptr,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketINETCreateListener,
	null,		       			/* ResetListener */
	&_XSERVTransSocketINETAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketINETClose,
	&_XSERVTransSocketINETClose,
};
}

static if(XTRANS_SEND_FDS) {
Xtransport _XSERVTransSocketINETFuncs = {
	/* Socket Interface */
	"inet",
	0,
	null,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketINETCreateListener,
	null,		       			/* ResetListener */
	&_XSERVTransSocketINETAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
	&_XSERVTransSocketSendFdInvalid,
	&_XSERVTransSocketRecvFdInvalid,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketINETClose,
	&_XSERVTransSocketINETClose,
};
}
else {
    Xtransport _XSERVTransSocketINETFuncs = {
	/* Socket Interface */
	"inet",
	0,
	null,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketINETCreateListener,
	null,		       			/* ResetListener */
	&_XSERVTransSocketINETAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketINETClose,
	&_XSERVTransSocketINETClose,
};
}

static if (IPv6){
    static if(XTRANS_SEND_FDS) {
Xtransport _XSERVTransSocketINET6Funcs = {
	/* Socket Interface */
	"inet6",
	0,
	null,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketINETCreateListener,
	null,					/* ResetListener */
	&_XSERVTransSocketINETAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
	&_XSERVTransSocketSendFdInvalid,
	&_XSERVTransSocketRecvFdInvalid,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketINETClose,
	&_XSERVTransSocketINETClose,
};
    }
    else {
Xtransport _XSERVTransSocketINET6Funcs = {
	/* Socket Interface */
	"inet6",
	0,
	null,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketINETCreateListener,
	null,					/* ResetListener */
	&_XSERVTransSocketINETAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketINETClose,
	&_XSERVTransSocketINETClose,
};
    }

} /* IPv6 */



static if(UNIXCONN){

    static if(HAVE_ABSTRACT_SOCKETS) {
// #ifdef HAVE_ABSTRACT_SOCKETS
	enum TRANS_LOCAL_FLAG = TRANS_ABSTRACT;
}
else {
    enum TRANS_LOCAL_FLAG  = 0;
}

static if(!HAVE_ABSTRACT_SOCKETS) {
// #ifdef HAVE_ABSTRACT_SOCKETS
	enum TRANS_UNIX_FLAG = TRANS_ALIAS;
}
else {
    enum TRANS_UNIX_FLAG  = 0;
}


static if(XTRANS_SEND_FDS) {
Xtransport _XSERVTransSocketLocalFuncs = {
	"local",
    TRANS_LOCAL_FLAG ,
	null,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketUNIXCreateListener,
	&_XSERVTransSocketUNIXResetListener,
	&_XSERVTransSocketUNIXAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
	&_XSERVTransSocketSendFd,
	&_XSERVTransSocketRecvFd,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketUNIXClose,
	&_XSERVTransSocketUNIXCloseForCloning,
};

enum const(char)*[2] unix_nolisten = [ "local" , null ];

Xtransport _XSERVTransSocketUNIXFuncs = {
	/* Socket Interface */
	"unix",
    TRANS_UNIX_FLAG,
	unix_nolisten.ptr,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketUNIXCreateListener,
	&_XSERVTransSocketUNIXResetListener,
	&_XSERVTransSocketUNIXAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
    &_XSERVTransSocketSendFd,
	&_XSERVTransSocketRecvFd,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketUNIXClose,
	&_XSERVTransSocketUNIXCloseForCloning,
};

}

else {
Xtransport _XSERVTransSocketLocalFuncs = {
	/* Socket Interface */
	"local",
    TRANS_LOCAL_FLAG ,
	null,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketUNIXCreateListener,
	&_XSERVTransSocketUNIXResetListener,
	&_XSERVTransSocketUNIXAccept,
	&_XSERVTransSocketRead,
	&_XSERVTransSocketWrite,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketUNIXClose,
	&_XSERVTransSocketUNIXCloseForCloning,
};

enum const(char)*[2] unix_nolisten = [ "local" , null ];

Xtransport _XSERVTransSocketUNIXFuncs = {
	/* Socket Interface */
	"unix",
    TRANS_UNIX_FLAG,
	unix_nolisten.ptr,
	&_XSERVTransSocketOpenCOTSServer,
	&_XSERVTransSocketReopenCOTSServer,
	&_XSERVTransSocketSetOption,
	&_XSERVTransSocketUNIXCreateListener,
	&_XSERVTransSocketUNIXResetListener,
	&_XSERVTransSocketUNIXAccept,
	&_XSERVTransSocketRead,
    &_XSERVTransSocketWrite,
	&_XSERVTransSocketDisconnect,
	&_XSERVTransSocketUNIXClose,
	&_XSERVTransSocketUNIXCloseForCloning,
};
}
} /* UNIXCONN */
