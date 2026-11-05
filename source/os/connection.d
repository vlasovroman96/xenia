module os.connection;
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
 *  Stuff to create connections --- OS dependent
 *
 *      EstablishNewConnections, CreateWellKnownSockets
 *      CloseDownConnection,
 *	OnlyListToOneClient,
 *      ListenToAllClients,
 *
 *      (WaitForSomething is in its own file)
 *
 *      In this implementation, a client socket table is not kept.
 *      Instead, what would be the index into the table is just the
 *      file descriptor of the socket.  This won't work for if the
 *      socket ids aren't small nums (0 - 2^8)
 *
 *****************************************************************/

import build.xlibre_server;

version (Windows) {
//import externs.X11.Xwinsock;
}
//import x11.X;
//import x11.Xproto;
import os.Xtrans;
import os.Xtransint;
import core.stdc.errno;
import core.stdc.signal;
import core.stdc.stdio;
import core.stdc.stdlib;
// import os.utils;
import os.log;
import core.sys.posix.unistd;
import core.sys.posix.unistd;
import core.sys.posix.sys.stat;
import core.sys.posix.arpa.inet;
import os.access;
import externs.attrs;
import os.io;
import x11.Xosdefs;
import dix.dispatch;

alias sockaddr_in = os.access.sockaddr_in;

version (Windows) {} else {
import core.sys.posix.sys.socket;

import core.sys.posix.netinet.in_;
import core.sys.posix.arpa.inet;
static if (CSRG_BASED) {
import sys.param;
}
import core.sys.posix.arpa.inet;
}
version (Windows) {} else {
import core.sys.posix.sys.uio;
}

import dix.dix_priv;
import dix.dixgrabs_priv;
import dix.server_priv;
import os.audit_priv;
import os.auth;
import os.client_priv;
import os.io_priv;
import os.log_priv;
import os.osdep;
import os.probes_priv;

import common.misc;               /* for typedef of pointer */
import dix.dixstruct_priv;
import Xext.xace;

alias sockaddr = core.sys.posix.sys.socket.sockaddr;
alias in_addr = core.sys.posix.arpa.inet.in_addr;
// module ;
alias inet_ntoa = core.sys.posix.arpa.inet.inet_ntoa;

version (HAVE_GETPEERUCRED) {
import ucred;
import zone;
} else {
alias zoneid_t = int;
}

version (HAVE_SYSTEMD_DAEMON) {
import systemd.sd_daemon;
}

static if(build.xlibre_server.XDMCP){
import os.xdmcp;
}

enum MAX_CONNECTIONS = (1<<16);

enum OS_COMM_GRAB_IMPERVIOUS = 1;
enum OS_COMM_IGNORED =         2;

// ospoll* server_poll;

alias pid_t = core.sys.posix.sys.types.pid_t;

// Bool NewOutputPending;          /* not yet attempted to write some new output */
Bool NoListenAll;               /* Don't establish any listening sockets */

private char[7] dynamic_display = 0; /* display name */
Bool PartialNetwork;            /* continue even if unable to bind all addrs */
static if (!HasVersion!"Windows") {
private pid_t ParentProcess;
private Bool RunFromSmartParent; /* send SIGUSR1 to parent process */
}

int GrabInProgress = 0;







private XtransConnInfo* ListenTransConns = null;
private int* ListenTransFds = null;
private uint ListenTransCount = 0;



private XtransConnInfo lookup_trans_conn(int fd)
{
    if (ListenTransFds) {
        int i = void;

        for (i = 0; i < ListenTransCount; i++)
            if (ListenTransFds[i] == fd)
                return ListenTransConns[i];
    }

    return null;
}

/*
 * If SIGUSR1 was set to SIG_IGN when the server started, assume that either
 *
 *  a- The parent process is ignoring SIGUSR1
 *
 * or
 *
 *  b- The parent process is expecting a SIGUSR1
 *     when the server is ready to accept connections
 *
 * In the first case, the signal will be harmless, in the second case,
 * the signal will be quite useful.
 */
private void InitParentProcess()
{
static if (!HasVersion!"Windows") {
    OsSigHandlerPtr handler = void;

    handler = OsSignal(SIGUSR1, SIG_IGN);
    if (handler == SIG_IGN)
        RunFromSmartParent = TRUE;
    OsSignal(SIGUSR1, handler);
    ParentProcess = getppid();
}
}

void NotifyParentProcess()
{
static if (!HasVersion!"Windows") {
    if (displayfd >= 0) {
        if (write(displayfd, display, strlen(display)) != strlen(display))
            FatalError("Cannot write display number to fd %d\n", displayfd);
        if (write(displayfd, "\n".ptr, 1) != 1)
            FatalError("Cannot write display number to fd %d\n", displayfd);
        close(displayfd);
        displayfd = -1;
    }
    if (RunFromSmartParent) {
        if (ParentProcess > 1) {
            kill(ParentProcess, SIGUSR1);
        }
    }
version (HAVE_SYSTEMD_DAEMON) {
    /* If we have been started as a systemd service, tell systemd that
       we are ready. Otherwise sd_notify() won't do anything. */
    sd_notify(0, "READY=1");
}
}
}

private Bool TryCreateSocket(int num, int* partial)
{
    char[20] port = void;

    snprintf(port.ptr, port.length, "%d", num);

    return (_XSERVTransMakeAllCOTSServerListeners(port.ptr, partial,
                                                  &ListenTransCount,
                                                  &ListenTransConns) >= 0);
}

/*****************
 * CreateWellKnownSockets
 *    At initialization, create the sockets to listen on for new clients.
 *****************/

void CreateWellKnownSockets()
{
    // fprintf(stderr, "%d", NUMTRANS);
    // fflush();
    int i = void;
    int partial = 0;

    /* display is initialized to "0" by main(). It is then set to the display
     * number if specified on the command line. */

    if (NoListenAll) {
        ListenTransCount = 0;
    }
    else if ((displayfd < 0) || explicit_display) {
        if (TryCreateSocket(atoi(display), &partial) &&
            ListenTransCount >= 1)
            if (!PartialNetwork && partial)
                FatalError ("Failed to establish all listening sockets");
    }
    else { /* -displayfd and no explicit display number */
        Bool found = 0;
        import os.utils;
        for (i = 0; defaultNoListenList[i] !is null; i++)
    fprintf(stderr, "DEFAULT NOLISTEN: %s\n",
            defaultNoListenList[i]);
        for (i = 0; i < 65536 - X_TCP_PORT; i++) {
            if (TryCreateSocket(i, &partial) && !partial) {
                found = 1;
                break;
            }
            else
                CloseWellKnownConnections();
        }
        if (!found)
            FatalError("Failed to find a socket to listen on");
        snprintf(dynamic_display.ptr, dynamic_display.length, "%d", i);
        fprintf(stderr, "%s", dynamic_display.ptr);
        display = dynamic_display.ptr;
        LogSetDisplay();
    }

    fprintf(stderr, "%d, %d", ListenTransCount, MAX_CONNECTIONS);
    if (ListenTransCount >= MAX_CONNECTIONS) {
        FatalError ("Tried to clear too many listening sockets - OOM");
        return; // mostly to keep GCC from complaining about too large alloc
    }

    ListenTransFds = cast(int*) calloc(ListenTransCount, int.sizeof);
    if (ListenTransFds is null)
        FatalError ("Failed to create listening socket array");

    for (i = 0; i < ListenTransCount; i++) {
        int fd = _XSERVTransGetConnectionNumber(ListenTransConns[i]);

        ListenTransFds[i] = fd;
        SetNotifyFd(fd, &EstablishNewConnections, X_NOTIFY_READ, null);

        if (!_XSERVTransIsLocal(ListenTransConns[i]))
            DefineSelf (fd);
    }

    if (ListenTransCount == 0 && !NoListenAll)
        FatalError
            ("Cannot establish any listening sockets - Make sure an X server isn't already running");

static if (!HasVersion!"Windows") {
    OsSignal(SIGPIPE, SIG_IGN);
}
    OsSignal(SIGINT, &GiveUp);
    OsSignal(SIGTERM, &GiveUp);
    ResetHosts(display);

    InitParentProcess();

static if(build.dix_config.XDMCP){
    XdmcpInit();
}
}

void CloseWellKnownConnections()
{
    int i = void;

    for (i = 0; i < ListenTransCount; i++) {
        if (ListenTransConns[i] !is null) {
            _XSERVTransClose(ListenTransConns[i]);
            ListenTransConns[i] = null;
            if (ListenTransFds !is null)
                RemoveNotifyFd(ListenTransFds[i]);
        }
    }
    ListenTransCount = 0;
}

private void AuthAudit(ClientPtr client, Bool letin, sockaddr* saddr, int len, uint proto_n, char* auth_proto, int auth_id)
{
    char[128] addr = void;
    char[64] client_uid_string = void;
    LocalClientCredRec* lcc = void;

version (XSERVER_DTRACE) {
    pid_t client_pid = -1;
    zoneid_t client_zid = -1;
}

    if (!len)
        strlcpy(addr.ptr, "local host", addr.sizeof);
    else
        switch (saddr.sa_family) {
        case AF_UNSPEC:
static if(UNIXCONN){
        case AF_UNIX:
}
            strlcpy(addr.ptr, "local host", addr.sizeof);
            break;
        case AF_INET:{
version (HAVE_INET_NTOP) {
            char[INET_ADDRSTRLEN] ipaddr = void;

            inet_ntop(AF_INET, &(cast(sockaddr_in*) saddr).sin_addr,
                      ipaddr.ptr, ipaddr.sizeof);
} else {
            const(char)* ipaddr = inet_ntoa((cast(sockaddr_in*)addr).sin_addr);
}
            snprintf(addr.ptr, addr.sizeof, "IP %s", ipaddr);
        }
            break;
static if (IPv6){
        case AF_INET6:{
            char[core.sys.posix.arpa.inet.INET6_ADDRSTRLEN] ipaddr = void;

            core.sys.posix.arpa.inet.inet_ntop(AF_INET6, &(cast(sockaddr_in6*) saddr).sin6_addr,
                      ipaddr.ptr, ipaddr.sizeof);
            snprintf(addr.ptr, addr.sizeof, "IP %s", ipaddr.ptr);
        }
            break;
}
        default:
            strlcpy(addr.ptr, "unknown address", addr.sizeof);
        }

    if (GetLocalClientCreds(client, &lcc) != -1) {
        int slen = void;               /* length written to client_uid_string */

        strcpy(client_uid_string.ptr, " ( ");
        slen = 3;

        if (lcc.fieldsSet & LCC_UID_SET) {
            snprintf(client_uid_string.ptr + slen,
                     ((client_uid_string).ptr - slen).sizeof,
                     "uid=%ld ", cast(c_long) lcc.euid);
            slen = cast(int)strlen(client_uid_string.ptr);
        }

        if (lcc.fieldsSet & LCC_GID_SET) {
            snprintf(client_uid_string.ptr + slen,
                     ((client_uid_string).ptr - slen).sizeof,
                     "gid=%ld ", cast(c_long) lcc.egid);
            slen = cast(int)strlen(client_uid_string.ptr);
        }

        if (lcc.fieldsSet & LCC_PID_SET) {
version (XSERVER_DTRACE) {
            client_pid = lcc.pid;
}
            snprintf(client_uid_string.ptr + slen,
                     ((client_uid_string).ptr - slen).sizeof,
                     "pid=%ld ", cast(c_long) lcc.pid);
            slen = cast(int)strlen(client_uid_string.ptr);
        }

        if (lcc.fieldsSet & LCC_ZID_SET) {
version (XSERVER_DTRACE) {
            client_zid = lcc.zoneid;
}
            snprintf(client_uid_string.ptr + slen,
                     ((client_uid_string).ptr - slen).sizeof,
                     "zoneid=%ld ", cast(c_long) lcc.zoneid);
            slen = cast(int)strlen(client_uid_string.ptr);
        }

        snprintf(client_uid_string.ptr + slen, ((client_uid_string).ptr - slen).sizeof,
                 ")");
        FreeLocalClientCreds(lcc);
    }
    else {
        client_uid_string[0] = '\0';
    }

version (XSERVER_DTRACE) {
    XSERVER_CLIENT_AUTH(client.index, addr.ptr, client_pid, client_zid);
}
    if (auditTrailLevel > 1) {
        if (proto_n)
            AuditF("client %d %s from %s%s\n  Auth name: %.*s ID: %d\n",
                   client.index, letin ? "connected".ptr : "rejected.ptr", addr.ptr,
                   client_uid_string.ptr, cast(int) proto_n, auth_proto, auth_id);
        else
            AuditF("client %d %s from %s%s\n",
                   client.index, letin ? "connected".ptr : "rejected".ptr, addr.ptr,
                   client_uid_string.ptr);

    }
}

XID AuthorizationIDOfClient(ClientPtr client)
{
    if (client.osPrivate)
        return (cast(OsCommPtr) client.osPrivate).auth_id;
    else
        return None;
}

/*****************************************************************
 * ClientAuthorized
 *
 *    Sent by the client at connection setup:
 *                typedef struct _xConnClientPrefix {
 *                   CARD8	byteOrder;
 *                   BYTE	pad;
 *                   CARD16	majorVersion, minorVersion;
 *                   CARD16	nbytesAuthProto;
 *                   CARD16	nbytesAuthString;
 *                 } xConnClientPrefix;
 *
 *     	It is hoped that eventually one protocol will be agreed upon.  In the
 *        mean time, a server that implements a different protocol than the
 *        client expects, or a server that only implements the host-based
 *        mechanism, will simply ignore this information.
 *
 *****************************************************************/

const(char)* ClientAuthorized(ClientPtr client, uint proto_n, char* auth_proto, uint string_n, char* auth_string)
{
    OsCommPtr priv = void;
    Xtransaddr* from = null;
    int family = void;
    int fromlen = void;
    XID auth_id = void;
    const(char)* reason = null;
    XtransConnInfo trans_conn = void;

    priv = cast(OsCommPtr) client.osPrivate;
    trans_conn = priv.trans_conn;

    /* Allow any client to connect without authorization on a launchd socket,
       because it is securely created -- this prevents a race condition on launch */
    if (trans_conn.flags & TRANS_NOXAUTH) {
        auth_id = cast(XID) 0L;
    }
    else {
        auth_id =
            CheckAuthorization(proto_n, auth_proto, string_n, auth_string,
                               client, &reason);
    }
    bool dtrace2;
    static if(HasVersion!"XSERVER_DTRACE") {
        dtrace2 = (auditTrailLevel > 1) || XSERVER_CLIENT_AUTH_ENABLED();
    }
    else {
        dtrace2 = cast(bool)auditTrailLevel;
    }
    if (auth_id == cast(XID) ~0L) {
        if (_XSERVTransGetPeerAddr(trans_conn, &family, &fromlen, &from) != -1) {
            if (InvalidHost(cast(sockaddr*) from, fromlen, client))
                AuthAudit(client, FALSE, cast(sockaddr*) from,
                          fromlen, proto_n, auth_proto, cast(int)auth_id);
            else {
                auth_id = cast(XID) 0;
                bool dtrace;
version (XSERVER_DTRACE) {
                dtrace = (auditTrailLevel > 1) || XSERVER_CLIENT_AUTH_ENABLED();
}else{
                dtrace = (auditTrailLevel > 1);
}
                if(dtrace) 
                    AuthAudit(client, TRUE,
                              cast(sockaddr*) from, fromlen,
                              proto_n, auth_proto, cast(int)auth_id);
            }

            free(from);
        }

        if (auth_id == cast(XID) ~0L) {
            if (reason)
                return reason;
            else
                return "Client is not authorized to connect to Server";
        }
    }
    else if (dtrace2)
    {
        if (_XSERVTransGetPeerAddr(trans_conn, &family, &fromlen, &from) != -1) {
            AuthAudit(client, TRUE, cast(sockaddr*) from, fromlen,
                      proto_n, auth_proto, cast(int)auth_id);

            free(from);
        }
    }
    priv.auth_id = auth_id;
    priv.conn_time = 0;

static if(build.dix_config.XDMCP){
    /* indicate to Xdmcp protocol that we've opened new client */
    XdmcpOpenDisplay(priv.fd);
}                          /* XDMCP */

    /* At this point, if the client is authorized to change the access control
     * list, we should getpeername() information, and add the client to
     * the selfhosts list.  It's not really the host machine, but the
     * true purpose of the selfhosts list is to see who may change the
     * access control list.
     */
    return (cast(char*) null);
}

private void ClientReady(int fd, int xevents, void* data)
{
    ClientPtr client = cast(ClientPtr)data;

    if (xevents & X_NOTIFY_ERROR) {
        CloseDownClient(client);
        return;
    }
    if (xevents & X_NOTIFY_READ)
        mark_client_ready(client);
    if (xevents & X_NOTIFY_WRITE) {
        ospoll_mute(server_poll, fd, X_NOTIFY_WRITE);
        NewOutputPending = TRUE;
    }
}

private ClientPtr AllocNewConnection(XtransConnInfo trans_conn, int fd, CARD32 conn_time)
{
    ClientPtr client = void;

    OsCommPtr oc = cast(OsCommRec*) calloc(1, OsCommRec.sizeof);
    if (!oc)
        return null;
    oc.trans_conn = trans_conn;
    oc.fd = fd;
    oc.conn_time = conn_time;
    if (((client = NextAvailableClient(cast(void*) oc)) is null)) {
        free(oc);
        return null;
    }
    client.local = ComputeLocalClient(client);
    ospoll_add(server_poll, fd,
               _ospoll_trigger.ospoll_trigger_edge,
               &ClientReady,
               client);
    set_poll_client(client);

version (DEBUG) {
    ErrorF("AllocNewConnection: client index = %d, socket fd = %d, local = %d\n",
           client.index, fd, client.local);
}
version (XSERVER_DTRACE) {
    XSERVER_CLIENT_CONNECT(client.index, fd);
}

    return client;
}

/*****************
 * EstablishNewConnections
 *    If anyone is waiting on listened sockets, accept them. Drop pending
 *    connections if they've stuck around for more than one minute.
 *****************/
enum TimeOutValue = 60 * MILLI_PER_SECOND;
private void EstablishNewConnections(int curconn, int ready, void* data)
{
    int newconn = void;       /* fd of new client */
    CARD32 connect_time = void;
    int i = void;
    ClientPtr client = void;
    OsCommPtr oc = void;
    XtransConnInfo trans_conn = void, new_trans_conn = void;

    connect_time = GetTimeInMillis();
    /* kill off stragglers */
    for (i = 1; i < currentMaxClients; i++) {
        if ((client = clients[i]) !is null) {
            oc = cast(OsCommPtr) (client.osPrivate);
            if ((oc && (oc.conn_time != 0) &&
                 (connect_time - oc.conn_time) >= TimeOutValue) ||
                (client.noClientException != Success && !client.clientGone))
                CloseDownClient(client);
        }
    }

    if ((trans_conn = lookup_trans_conn(curconn)) is null)
        return;

    if ((new_trans_conn = _XSERVTransAccept(trans_conn)) is null)
        return;

    newconn = _XSERVTransGetConnectionNumber(new_trans_conn);

    _XSERVTransNonBlock(new_trans_conn);

    if (trans_conn.flags & TRANS_NOXAUTH)
        new_trans_conn.flags = new_trans_conn.flags | TRANS_NOXAUTH;

    if (!AllocNewConnection(new_trans_conn, newconn, connect_time)) {
        ErrorConnMax(new_trans_conn);
    }
    return;
}

/************
 *   ErrorConnMax
 *     Fail a connection due to lack of client or file descriptor space
 ************/

private void ConnMaxNotify(int fd, int events, void* data)
{
    XtransConnInfo trans_conn = cast(XtransConnInfo)data;
    char order = 0;

    /* try to read the byte-order of the connection */
    cast(void) _XSERVTransRead(trans_conn, &order, 1);
    if (order == 'l' || order == 'B' || order == 'r' || order == 'R') {
        int whichbyte = 1;

/* 36 bytes (with zero) -- needs to be padded to 4*n */
enum ERR_TEXT = "Maximum number of clients reached\0\0";

        xConnSetupPrefix csp = {
            success: xFalse,
            lengthReason: ERR_TEXT.sizeof,
            length: ERR_TEXT.sizeof >> 2,
            majorVersion: X_PROTOCOL,
            minorVersion: X_PROTOCOL_REVISION,
        };

        if (((*cast(char*) &whichbyte) && (order == 'B' || order == 'R')) ||
            (!(*cast(char*) &whichbyte) && (order == 'l' || order == 'r'))) {
            swaps(&csp.majorVersion);
            swaps(&csp.minorVersion);
            swaps(&csp.length);
        }

        _XSERVTransWrite(trans_conn, cast(const(char)*)&csp, csp.sizeof);
        _XSERVTransWrite(trans_conn, ERR_TEXT, ERR_TEXT.sizeof);
    }
    RemoveNotifyFd(trans_conn.fd);
    _XSERVTransClose(trans_conn);
}

private void ErrorConnMax(XtransConnInfo trans_conn)
{
    if (!SetNotifyFd(trans_conn.fd, &ConnMaxNotify, X_NOTIFY_READ, trans_conn))
        _XSERVTransClose(trans_conn);
}

/************
 *   CloseDownFileDescriptor:
 *     Remove this file descriptor
 ************/

void CloseDownFileDescriptor(OsCommPtr oc)
{
    if (oc.trans_conn) {
        int connection = oc.fd;
static if(build.dix_config.XDMCP){
        XdmcpCloseDisplay(connection);
}
        ospoll_remove(server_poll, connection);
        _XSERVTransDisconnect(oc.trans_conn);
        _XSERVTransClose(oc.trans_conn);
        oc.trans_conn = null;
        oc.fd = -1;
    }
}

/*****************
 * CloseDownConnection
 *    Delete client from AllClients and free resources
 *****************/

void CloseDownConnection(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    if (FlushCallback)
        CallCallbacks(&FlushCallback, client);

    if (oc.output)
	FlushClient(client, oc);
    CloseDownFileDescriptor(oc);
    FreeOsBuffers(oc);
    free(client.osPrivate);
    client.osPrivate = cast(void*) null;
    if (auditTrailLevel > 1)
        AuditF("client %d disconnected\n", client.index);
}

struct notify_fd {
    int mask;
    NotifyFdProcPtr notify;
    void* data;
}

/*****************
 * HandleNotifyFd
 *    A poll callback to be called when the registered
 *    file descriptor is ready.
 *****************/

private void HandleNotifyFd(int fd, int xevents, void* data)
{
    notify_fd* n = cast(notify_fd*) data;
    n.notify(fd, xevents, n.data);
}

/*****************
 * SetNotifyFd
 *    Registers a callback to be invoked when the specified
 *    file descriptor becomes readable.
 *****************/

Bool SetNotifyFd(int fd, NotifyFdProcPtr notify, int mask, void* data)
{
    notify_fd* n = void;

    n = cast(notify_fd*)ospoll_data(server_poll, fd);
    if (!n) {
        if (mask == 0)
            return TRUE;

        n = cast(notify_fd*) cast(notify_fd*) calloc(1, notify_fd.sizeof);
        if (!n)
            return FALSE;
        ospoll_add(server_poll, fd,
                   _ospoll_trigger.ospoll_trigger_level,
                   &HandleNotifyFd,
                   n);
    }

    if (mask == 0) {
        ospoll_remove(server_poll, fd);
        free(n);
    } else {
        int listen = mask & ~n.mask;
        int mute = n.mask & ~mask;

        if (listen)
            ospoll_listen(server_poll, fd, listen);
        if (mute)
            ospoll_mute(server_poll, fd, mute);
        n.mask = mask;
        n.data = data;
        n.notify = notify;
    }

    return TRUE;
}

/*****************
 * OnlyListenToOneClient:
 *    Only accept requests from  one client.  Continue to handle new
 *    connections, but don't take any protocol requests from the new
 *    ones.  Note that if GrabInProgress is set, EstablishNewConnections
 *    needs to put new clients into SavedAllSockets and SavedAllClients.
 *    Note also that there is no timeout for this in the protocol.
 *    This routine is "undone" by ListenToAllClients()
 *****************/

int OnlyListenToOneClient(ClientPtr client)
{
    int rc = void;

    rc = dixCallServerAccessCallback(client, DixGrabAccess);
    if (rc != Success)
        return rc;

    if (!GrabInProgress) {
        GrabInProgress = client.index;
        set_poll_clients();
    }

    return rc;
}

/****************
 * ListenToAllClients:
 *    Undoes OnlyListenToOneClient()
 ****************/

void ListenToAllClients()
{
    if (GrabInProgress) {
        GrabInProgress = 0;
        set_poll_clients();
    }
}

/****************
 * IgnoreClient
 *    Removes one client from input masks.
 *    Must have corresponding call to AttendClient.
 ****************/

void IgnoreClient(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    client.ignoreCount++;
    if (client.ignoreCount > 1)
        return;

    isItTimeToYield = TRUE;
    mark_client_not_ready(client);

    oc.flags |= OS_COMM_IGNORED;
    set_poll_client(client);
}

/****************
 * AttendClient
 *    Adds one client back into the input masks.
 ****************/

void AttendClient(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    if (client.clientGone) {
        /*
         * client is gone, so any pending requests will be dropped and its
         * ignore count doesn't matter.
         */
        return;
    }

    client.ignoreCount--;
    if (client.ignoreCount)
        return;

    oc.flags &= ~OS_COMM_IGNORED;
    set_poll_client(client);
    if (listen_to_client(client))
        mark_client_ready(client);
    else {
        /* grab active, mark ready when grab goes away */
        mark_client_saved_ready(client);
    }
}

/* make client impervious to grabs; assume only executing client calls this */

void MakeClientGrabImpervious(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    oc.flags |= OS_COMM_GRAB_IMPERVIOUS;
    set_poll_client(client);

    if (ServerGrabCallback) {
        ServerGrabInfoRec grabinfo = void;

        grabinfo.client = client;
        grabinfo.grabstate = CLIENT_IMPERVIOUS;
        CallCallbacks(&ServerGrabCallback, &grabinfo);
    }
}

/* make client pervious to grabs; assume only executing client calls this */

void MakeClientGrabPervious(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    oc.flags &= ~OS_COMM_GRAB_IMPERVIOUS;
    set_poll_client(client);
    isItTimeToYield = TRUE;

    if (ServerGrabCallback) {
        ServerGrabInfoRec grabinfo = void;

        grabinfo.client = client;
        grabinfo.grabstate = CLIENT_PERVIOUS;
        CallCallbacks(&ServerGrabCallback, &grabinfo);
    }
}

/* Add a fd (from launchd or similar) to our listeners */
void ListenOnOpenFD(int fd, int noxauth)
{
    char[PATH_MAX] port = void;
    XtransConnInfo ciptr = void;
    const(char)* display_env = getenv("DISPLAY");

    /* First check if display_env matches a <absolute path to unix socket>[.<screen number>] scheme (eg: launchd) */
    if (display_env && display_env[0] == '/') {
        stat_t sbuf = void;

        strlcpy(port.ptr, display_env, port.sizeof);

        /* If the path exists, we don't have do do anything else.
         * If it doesn't, we need to check for a .<screen number> to strip off and recheck.
         */
        if (0 != stat(port.ptr, &sbuf)) {
            char* dot = strrchr(port.ptr, '.');
            if (dot) {
                *dot = '\0';

                if (0 != stat(port.ptr, &sbuf)) {
                    display_env = null;
                }
            } else {
                display_env = null;
            }
        }
    }

    if (!display_env || display_env[0] != '/') {
        /* Just some default so things don't break and die. */
        snprintf(port.ptr, port.sizeof, ":%d", atoi(display));
    }

    /* Make our XtransConnInfo
     * TRANS_SOCKET_LOCAL_INDEX = 5 from Xtrans.c
     */
    ciptr = _XSERVTransReopenCOTSServer(5, fd, port.ptr);
    if (ciptr is null) {
        ErrorF("Got NULL while trying to Reopen listen port.\n");
        return;
    }

    if (noxauth)
        ciptr.flags = ciptr.flags | TRANS_NOXAUTH;

    /* Allocate space to store it */
    ListenTransFds =
        cast(int*)XNFreallocarray(ListenTransFds, (ListenTransCount + 1), int.sizeof);
    ListenTransConns =
        cast(_XtransConnInfo**)XNFreallocarray(ListenTransConns, ListenTransCount + 1,
                        XtransConnInfo.sizeof);

    /* Store it */
    ListenTransConns[ListenTransCount] = ciptr;
    ListenTransFds[ListenTransCount] = fd;

    SetNotifyFd(fd, &EstablishNewConnections, X_NOTIFY_READ, null);

    /* Increment the count */
    ListenTransCount++;
}

Bool AddClientOnOpenFD(int fd)
{
    XtransConnInfo ciptr = void;
    CARD32 connect_time = void;
    char[20] port = void;

    snprintf(port.ptr, port.sizeof, ":%d", atoi(display));
    ciptr = _XSERVTransReopenCOTSServer(5, fd, port.ptr);
    if (ciptr is null)
        return FALSE;

    _XSERVTransNonBlock(ciptr);
    ciptr.flags |= TRANS_NOXAUTH;

    connect_time = GetTimeInMillis();

    if (!AllocNewConnection(ciptr, fd, connect_time)) {
        ErrorConnMax(ciptr);
        return FALSE;
    }

    return TRUE;
}

Bool listen_to_client(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    if (oc.flags & OS_COMM_IGNORED)
        return FALSE;

    if (!GrabInProgress)
        return TRUE;

    if (client.index == GrabInProgress)
        return TRUE;

    if (oc.flags & OS_COMM_GRAB_IMPERVIOUS)
        return TRUE;

    return FALSE;
}

private void set_poll_client(ClientPtr client)
{
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    if (oc.trans_conn) {
        if (listen_to_client(client))
            ospoll_listen(server_poll, oc.trans_conn.fd, X_NOTIFY_READ);
        else
            ospoll_mute(server_poll, oc.trans_conn.fd, X_NOTIFY_READ);
    }
}

private void set_poll_clients()
{
    int i = void;

    for (i = 1; i < currentMaxClients; i++) {
        ClientPtr client = clients[i];
        if (client && !client.clientGone)
            set_poll_client(client);
    }
}
