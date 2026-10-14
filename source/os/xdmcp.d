module os.xdmcp;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright 1989 Network Computing Devices, Inc., Mountain View, California.
 *
 * Permission to use, copy, modify, and distribute this software and its
 * documentation for any purpose and without fee is hereby granted, provided
 * that the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of N.C.D. not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  N.C.D. makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 */

import build.xlibre_server;

version (Windows) {
//import externs.X11.Xwinsock;
import os.Xtrans;
}
import os.log;
import os.access;
import os.connection;
import os.WaitFor;
import os.Xtransutil;


// //import x11.Xos;

static if (!HasVersion!"Windows") {
// import externs.sys.param;
import core.sys.posix.sys.socket;
import core.sys.linux.netinet.in_;
import core.sys.posix.netdb;
}

import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdlib;
//import x11.X;
//import x11.Xmd;

import dix.dix_priv;
import os.auth;
import os.ossock;

import include.misc;
import os.osdep;
import os.xdmcp;
import os.xdmauth;
import include.input;
import include.dixstruct;

import externs.xdmcp;
import os.Xtrans;

static if(build.xlibre_server.XDMCP){
version (XDMCP_NO_IPV6) {
}


version = X_INCLUDE_NETDB_H;
//import x11.Xos_r;

private const(char)* defaultDisplayClass = "MIT-unspecified";

private int xdmcpSocket, sessionSocket;
private xdmcp_states state;

static if (IPv6){
private int xdmcpSocket6;
private core.sys.posix.netinet.in_.sockaddr_in req_sockaddr;
} else {
private sockaddr_in req_sockaddr;
}
private int req_socklen;
private CARD32 SessionID;
private int timeOutRtx;
private CARD16 DisplayNumber;
private xdmcp_states XDM_INIT_STATE = XDM_OFF;
private OsTimerPtr xdmcp_timer;

version (HASXDMAUTH) {
private char* xdmAuthCookie;
}

private XdmcpBuffer buffer;

version (HAVE_GETADDRINFO) {
private addrinfo* mgrAddr;
private addrinfo* mgrAddrFirst;
}

static if (IPv6){

alias SOCKADDR_TYPE = core.sys.posix.netinet.in_.sockaddr_in;
enum string SOCKADDR_FAMILY(string s) = `(cast(os.access.sockaddr*)&(` ~ s ~ `)).sa_family`;

version (BSD44SOCKETS) {
enum string SOCKLEN_FIELD(string s) = `(cast(os.access.sockaddr*)&(` ~ s ~ `)).sa_len`;
alias SOCKLEN_TYPE = 		ubyte;
} else {
alias SOCKLEN_TYPE = 		uint;
}

} else {

alias SOCKADDR_TYPE = sockaddr_in;
enum string SOCKADDR_FAMILY(string s) = `(` ~ s ~ `).sin_family`;

version (BSD44SOCKETS) {
enum string SOCKLEN_FIELD(string s) = `(` ~ s ~ `).sin_len`;
alias SOCKLEN_TYPE =		ubyte;
} else {
alias SOCKLEN_TYPE =		size_t;
}

}

private SOCKADDR_TYPE ManagerAddress;
private SOCKADDR_TYPE FromAddress;

version (SOCKLEN_FIELD) {
enum ManagerAddressLen =	SOCKLEN_FIELD(ManagerAddress);
enum FromAddressLen =		SOCKLEN_FIELD(FromAddress);
} else {
private SOCKLEN_TYPE ManagerAddressLen, FromAddressLen;
}

static if (IPv6){
struct multicastinfo {
    multicastinfo* next;
    addrinfo* ai;
    int hops;
}private multicastinfo* mcastlist;
}



alias ValidatorFunc =  Bool function(ARRAY8Ptr Auth, ARRAY8Ptr Data, int packet_type);
alias GeneratorFunc =  Bool function(ARRAY8Ptr Auth, ARRAY8Ptr Data, int packet_type);
alias AddAuthorFunc =  Bool function(uint name_length, const char *name,
                               uint data_length, char *data);































static if (IPv6){

}











/*
 * Register the Manufacturer display ID
 */

private ARRAY8 ManufacturerDisplayID;

private void XdmcpRegisterManufacturerDisplayID(const(char)* name, int length)
{
    int i = void;

    XdmcpDisposeARRAY8(&ManufacturerDisplayID);
    if (!XdmcpAllocARRAY8(&ManufacturerDisplayID, length))
        return;
    for (i = 0; i < length; i++)
        ManufacturerDisplayID.data[i] = cast(CARD8) name[i];
}

private ushort xdm_udp_port = XDM_UDP_PORT;
private const(char)* xdm_from = null;

void XdmcpUseMsg()
{
    ErrorF("-query host-name       contact named host for XDMCP\n");
    ErrorF("-broadcast             broadcast for XDMCP\n");
static if (IPv6){
    ErrorF("-multicast [addr [hops]] IPv6 multicast for XDMCP\n");
}
    ErrorF("-indirect host-name    contact named host for indirect XDMCP\n");
    ErrorF("-port port-num         UDP port number to send messages to\n");
    ErrorF
        ("-from local-address    specify the local address to connect from\n");
    ErrorF("-class display-class   specify display class to send in manage\n");
version (HASXDMAUTH) {
    ErrorF("-cookie xdm-auth-bits  specify the magic cookie for XDMCP\n");
}
    ErrorF("-displayID display-id  manufacturer display ID for request\n");
}

private void XdmcpDefaultListen()
{
    /* Even when configured --disable-listen-tcp, we should listen on tcp in
       XDMCP modes */
    _XSERVTransListen("tcp");
}

int XdmcpOptions(int argc, char** argv, int i)
{
    if (strcmp(argv[i], "-query") == 0) {
        get_manager_by_name(argc, argv, i++);
        XDM_INIT_STATE = XDM_QUERY;
        AccessUsingXdmcp();
        XdmcpDefaultListen();
        return i + 1;
    }
    if (strcmp(argv[i], "-broadcast") == 0) {
        XDM_INIT_STATE = XDM_BROADCAST;
        AccessUsingXdmcp();
        XdmcpDefaultListen();
        return i + 1;
    }
static if (IPv6){
    if (strcmp(argv[i], "-multicast") == 0) {
        i = get_mcast_options(argc, argv, ++i);
        XDM_INIT_STATE = XDM_MULTICAST;
        AccessUsingXdmcp();
        XdmcpDefaultListen();
        return i + 1;
    }
}
    if (strcmp(argv[i], "-indirect") == 0) {
        get_manager_by_name(argc, argv, i++);
        XDM_INIT_STATE = XDM_INDIRECT;
        AccessUsingXdmcp();
        XdmcpDefaultListen();
        return i + 1;
    }
    if (strcmp(argv[i], "-port") == 0) {
        if (++i == argc) {
            FatalError("Xserver: missing port number in command line\n");
        }
        xdm_udp_port = cast(ushort) atoi(argv[i]);
        return i + 1;
    }
    if (strcmp(argv[i], "-from") == 0) {
        get_fromaddr_by_name(argc, argv, ++i);
        return i + 1;
    }
    if (strcmp(argv[i], "-class") == 0) {
        if (++i == argc) {
            FatalError("Xserver: missing class name in command line\n");
        }
        defaultDisplayClass = argv[i];
        return i + 1;
    }
version (HASXDMAUTH) {
    if (strcmp(argv[i], "-cookie") == 0) {
        if (++i == argc) {
            FatalError("Xserver: missing cookie data in command line\n");
        }
        xdmAuthCookie = argv[i];
        return i + 1;
    }
}
    if (strcmp(argv[i], "-displayID") == 0) {
        if (++i == argc) {
            FatalError("Xserver: missing displayID in command line\n");
        }
        XdmcpRegisterManufacturerDisplayID(argv[i], cast(int)strlen(argv[i]));
        return i + 1;
    }
    return i;
}

/*
 * This section is a collection of routines for
 * registering server-specific data with the XDMCP
 * state machine.
 */

/*
 * Save all broadcast addresses away so BroadcastQuery
 * packets get sent everywhere
 */

enum MAX_BROADCAST =	10;

/* This stays sockaddr_in since IPv6 doesn't support broadcast */
private core.sys.posix.netinet.in_.sockaddr_in[MAX_BROADCAST] BroadcastAddresses;
private int NumBroadcastAddresses;

void XdmcpRegisterBroadcastAddress(const(core.sys.posix.netinet.in_.sockaddr_in)* addr)
{
    os.access.sockaddr_in* bcast = void;

    if (NumBroadcastAddresses >= MAX_BROADCAST)
        return;
    bcast = &BroadcastAddresses[NumBroadcastAddresses++];
    memset(bcast, 0, os.access.sockaddr_in.sizeof);
version (BSD44SOCKETS) {
    bcast.sin_len = addr.sin_len;
}
    bcast.sin_family = addr.sin_family;
    bcast.sin_port = core.sys.posix.arpa.inet.htons(xdm_udp_port);
    bcast.sin_addr = addr.sin_addr;
}

/*
 * Each authentication type is registered here; Validator
 * will be called to check all access attempts using
 * the specified authentication type
 */

private ARRAYofARRAY8 AuthenticationNames, AuthenticationDatas;
struct _AuthenticationFuncs {
    ValidatorFunc Validator;
    GeneratorFunc Generator;
    AddAuthorFunc AddAuth;
}alias AuthenticationFuncsRec = _AuthenticationFuncs;
alias AuthenticationFuncsPtr = _AuthenticationFuncs*;

private AuthenticationFuncsPtr AuthenticationFuncsList;

void XdmcpRegisterAuthentication(const(char)* name, int namelen, const(char)* data, int datalen, ValidatorFunc Validator, GeneratorFunc Generator, AddAuthorFunc AddAuth)
{
    int i = void;
    ARRAY8 AuthenticationName = void, AuthenticationData = void;
    static AuthenticationFuncsPtr newFuncs;

    if (!XdmcpAllocARRAY8(&AuthenticationName, namelen))
        return;
    if (!XdmcpAllocARRAY8(&AuthenticationData, datalen)) {
        XdmcpDisposeARRAY8(&AuthenticationName);
        return;
    }
    for (i = 0; i < namelen; i++)
        AuthenticationName.data[i] = name[i];
    for (i = 0; i < datalen; i++)
        AuthenticationData.data[i] = data[i];
    if (!(XdmcpReallocARRAYofARRAY8(&AuthenticationNames,
                                    AuthenticationNames.length + 1) &&
          XdmcpReallocARRAYofARRAY8(&AuthenticationDatas,
                                    AuthenticationDatas.length + 1) &&
          (newFuncs =
           cast(_AuthenticationFuncs*)calloc(1, (AuthenticationNames.length +
                   1) * AuthenticationFuncsRec.sizeof)) !is null)) {
        XdmcpDisposeARRAY8(&AuthenticationName);
        XdmcpDisposeARRAY8(&AuthenticationData);
        return;
    }
    for (i = 0; i < AuthenticationNames.length - 1; i++)
        newFuncs[i] = AuthenticationFuncsList[i];
    newFuncs[AuthenticationNames.length - 1].Validator = Validator;
    newFuncs[AuthenticationNames.length - 1].Generator = Generator;
    newFuncs[AuthenticationNames.length - 1].AddAuth = AddAuth;
    free(AuthenticationFuncsList);
    AuthenticationFuncsList = newFuncs;
    AuthenticationNames.data[AuthenticationNames.length - 1] =
        AuthenticationName;
    AuthenticationDatas.data[AuthenticationDatas.length - 1] =
        AuthenticationData;
}

/*
 * Select the authentication type to be used; this is
 * set by the manager of the host to be connected to.
 */

private ARRAY8 noAuthenticationName = { cast(CARD16) 0, cast(CARD8Ptr) 0 };
private ARRAY8 noAuthenticationData = { cast(CARD16) 0, cast(CARD8Ptr) 0 };

private ARRAY8Ptr AuthenticationName = &noAuthenticationName;
private ARRAY8Ptr AuthenticationData = &noAuthenticationData;
private AuthenticationFuncsPtr AuthenticationFuncs;

private void XdmcpSetAuthentication(const(ARRAY8Ptr) name)
{
    int i = void;

    for (i = 0; i < AuthenticationNames.length; i++)
        if (XdmcpARRAY8Equal(&AuthenticationNames.data[i], name)) {
            AuthenticationName = &AuthenticationNames.data[i];
            AuthenticationData = &AuthenticationDatas.data[i];
            AuthenticationFuncs = &AuthenticationFuncsList[i];
            break;
        }
}

/*
 * Register the host address for the display
 */

private ARRAY16 ConnectionTypes;
private ARRAYofARRAY8 ConnectionAddresses;

void XdmcpRegisterConnection(int type, const(char)* address, int addrlen)
{
    int i = void;
    CARD8* newAddress = void;

    XdmcpDisposeARRAY16(&ConnectionTypes);
    XdmcpDisposeARRAYofARRAY8(&ConnectionAddresses);

    if (xdm_from !is null) {     /* Only register the requested address */
        const(void)* regAddr = address;
        const(void)* fromAddr = null;
        int regAddrlen = addrlen;

        if (addrlen == os.access.in_addr.sizeof) {
            if (mixin(SOCKADDR_FAMILY!(`FromAddress`)) == AF_INET) {
                fromAddr = &(cast(os.access.sockaddr_in*) &FromAddress).sin_addr;
            }
static if (HasVersion!"IPv6") {
            if ((SOCKADDR_FAMILY(FromAddress) == AF_INET6) &&
                     IN6_IS_ADDR_V4MAPPED(&
                                (cast(core.sys.posix.netinet.in_.sockaddr_in6 *)&FromAddress).sin6_addr)) {
                fromAddr =
                    &(cast(core.sys.posix.netinet.in_.sockaddr_in6*) &FromAddress).sin6_addr.
                    s6_addr[12];
            }
}
        }
static if (IPv6){
        if(addrlen == core.sys.posix.netinet.in_.in6_addr.sizeof) {
            if (mixin(SOCKADDR_FAMILY!(`FromAddress`)) == AF_INET6) {
                fromAddr = &(cast(core.sys.posix.netinet.in_.sockaddr_in6*) &FromAddress).sin6_addr;
            }
            else if ((mixin(SOCKADDR_FAMILY!(`FromAddress`)) == AF_INET) &&
                     IN6_IS_ADDR_V4MAPPED(cast(const(core.sys.posix.netinet.in_.in6_addr)*) address)) {
                fromAddr = &(cast(core.sys.posix.netinet.in_.sockaddr_in*) &FromAddress).sin_addr;
                regAddr =
                    &(cast(core.sys.posix.netinet.in_.sockaddr_in6*) address).sin6_addr.s6_addr[12];
                regAddrlen = core.sys.posix.netinet.in_.in_addr.sizeof;
            }
        }
}
        if (!fromAddr || memcmp(regAddr, fromAddr, regAddrlen) != 0) {
            return;
        }
    }
    if (ConnectionAddresses.length + 1 == 256)
        return;
    newAddress = cast(ubyte*)calloc(addrlen, CARD8.sizeof);
    if (!newAddress)
        return;
    if (!XdmcpReallocARRAY16(&ConnectionTypes, ConnectionTypes.length + 1)) {
        free(newAddress);
        return;
    }
    if (!XdmcpReallocARRAYofARRAY8(&ConnectionAddresses,
                                   ConnectionAddresses.length + 1)) {
        free(newAddress);
        return;
    }
    ConnectionTypes.data[ConnectionTypes.length - 1] = cast(CARD16) type;
    for (i = 0; i < addrlen; i++)
        newAddress[i] = address[i];
    ConnectionAddresses.data[ConnectionAddresses.length - 1].data = newAddress;
    ConnectionAddresses.data[ConnectionAddresses.length - 1].length = cast(ushort)addrlen;
}

/*
 * Register an Authorization Name.  XDMCP advertises this list
 * to the manager.
 */

private ARRAYofARRAY8 AuthorizationNames;

void XdmcpRegisterAuthorizations()
{
    XdmcpDisposeARRAYofARRAY8(&AuthorizationNames);
    RegisterAuthorizations();
}

void XdmcpRegisterAuthorization(const(char)* name)
{
    ARRAY8 authName = void;
    int i = void;

    size_t namelen = strlen(name);
    authName.data = cast(ubyte*)calloc(namelen, CARD8.sizeof);
    if (!authName.data)
        return;
    if (!XdmcpReallocARRAYofARRAY8
        (&AuthorizationNames, AuthorizationNames.length + 1)) {
        free(authName.data);
        return;
    }
    for (i = 0; i < namelen; i++)
        authName.data[i] = cast(CARD8) name[i];
    authName.length = cast(ushort)namelen;
    AuthorizationNames.data[AuthorizationNames.length - 1] = authName;
}

/*
 * Register the DisplayClass string
 */

private ARRAY8 DisplayClass;

private void XdmcpRegisterDisplayClass(const(char)* name, int length)
{
    int i = void;

    XdmcpDisposeARRAY8(&DisplayClass);
    if (!XdmcpAllocARRAY8(&DisplayClass, length))
        return;
    for (i = 0; i < length; i++)
        DisplayClass.data[i] = cast(CARD8) name[i];
}

private void xdmcp_reset()
{
    timeOutRtx = 0;
    if (xdmcpSocket >= 0)
        SetNotifyFd(xdmcpSocket, &XdmcpSocketNotify, X_NOTIFY_READ, null);
static if (IPv6){
    if (xdmcpSocket6 >= 0)
        SetNotifyFd(xdmcpSocket6, &XdmcpSocketNotify, X_NOTIFY_READ, null);
}
    xdmcp_timer = TimerSet(null, 0, 0, &XdmcpTimerNotify, null);
    send_packet();
}

private void xdmcp_start()
{
    get_xdmcp_sock();
    xdmcp_reset();
}

/*
 * initialize XDMCP; create the socket, compute the display
 * number, set up the state machine
 */

void XdmcpInit()
{
    state = XDM_INIT_STATE;
version (HASXDMAUTH) {
    if (xdmAuthCookie)
        XdmAuthenticationInit(xdmAuthCookie, strlen(xdmAuthCookie));
}
    if (state != XDM_OFF) {
        XdmcpRegisterAuthorizations();
        XdmcpRegisterDisplayClass(defaultDisplayClass,
                                  cast(int)strlen(defaultDisplayClass));
        AccessUsingXdmcp();
        DisplayNumber = cast(CARD16) atoi(display);
        xdmcp_start();
    }
}

/*
 * Called whenever a new connection is created; notices the
 * first connection and saves it to terminate the session
 * when it is closed
 */

void XdmcpOpenDisplay(int sock)
{
    if (state != XDM_AWAIT_MANAGE_RESPONSE)
        return;
    state = XDM_RUN_SESSION;
    TimerSet(xdmcp_timer, 0, XDM_DEF_DORMANCY * 1000, &XdmcpTimerNotify, null);
    sessionSocket = sock;
}

void XdmcpCloseDisplay(int sock)
{
    if ((state != XDM_RUN_SESSION && state != XDM_AWAIT_ALIVE_RESPONSE)
        || sessionSocket != sock)
        return;
    state = XDM_INIT_STATE;
    dispatchException |= DE_TERMINATE;
    isItTimeToYield = True;
}

private void XdmcpSocketNotify(int fd, int ready, void* data)
{
    if (state == XDM_OFF)
        return;
    receive_packet(fd);
}

private CARD32 XdmcpTimerNotify(OsTimerPtr timer, CARD32 time, void* arg)
{
    if (state == XDM_RUN_SESSION) {
        state = XDM_KEEPALIVE;
        send_packet();
    }
    else
        timeout();
    return 0;
}

/*
 * This routine should be called from the routine that drives the
 * user's host menu when the user selects a host
 */

private void XdmcpSelectHost(const(core.sys.posix.sys.socket.sockaddr)* host_sockaddr, int host_len, ARRAY8Ptr auth_name)
{
    state = XDM_START_CONNECTION;
    memmove(&req_sockaddr, host_sockaddr, host_len);
    req_socklen = host_len;
    XdmcpSetAuthentication(auth_name);
    send_packet();
}

/*
 * !!! this routine should be replaced by a routine that adds
 * the host to the user's host menu. the current version just
 * selects the first host to respond with willing message.
 */

 /*ARGSUSED*/ private void XdmcpAddHost(const(core.sys.posix.sys.socket.sockaddr)* from, int fromlen, ARRAY8Ptr auth_name, ARRAY8Ptr hostname, ARRAY8Ptr status)
{
    XdmcpSelectHost(from, fromlen, auth_name);
}

/*
 * A message is queued on the socket; read it and
 * do the appropriate thing
 */

private ARRAY8 UnwillingMessage = { cast(CARD8) 14, cast(CARD8*) "Host unwilling" };

private void receive_packet(int socketfd)
{
static if (IPv6){
    core.sys.posix.sys.socket.sockaddr_storage from = void;
} else {
    sockaddr_in from = void;
}
    int fromlen = from.sizeof;
    XdmcpHeader header = void;

    /* read message off socket */
    if (!XdmcpFill(socketfd, &buffer, cast(XdmcpNetaddr) &from, &fromlen))
        return;

    /* reset retransmission backoff */
    timeOutRtx = 0;

    if (!XdmcpReadHeader(&buffer, &header))
        return;

    if (header.version_ != XDM_PROTOCOL_VERSION)
        return;

    switch (header.opcode) {
    case WILLING:
        recv_willing_msg(cast(os.access.sockaddr*) &from, fromlen, header.length);
        break;
    case UNWILLING:
        XdmcpFatal("Manager unwilling", &UnwillingMessage);
        break;
    case ACCEPT:
        recv_accept_msg(header.length);
        break;
    case DECLINE:
        recv_decline_msg(header.length);
        break;
    case REFUSE:
        recv_refuse_msg(header.length);
        break;
    case FAILED:
        recv_failed_msg(header.length);
        break;
    case ALIVE:
        recv_alive_msg(header.length);
        break;
    default: break;}
}

/*
 * send the appropriate message given the current state
 */

private void send_packet()
{
    int rtx = void;

    switch (state) {
    case XDM_QUERY:
    case XDM_BROADCAST:
    case XDM_INDIRECT:
static if (IPv6){
    case XDM_MULTICAST:
}
        send_query_msg();
        break;
    case XDM_START_CONNECTION:
        send_request_msg();
        break;
    case XDM_MANAGE:
        send_manage_msg();
        break;
    case XDM_KEEPALIVE:
        send_keepalive_msg();
        break;
    default:
        break;
    }
    rtx = (XDM_MIN_RTX << timeOutRtx);
    if (rtx > XDM_MAX_RTX)
        rtx = XDM_MAX_RTX;
    TimerSet(xdmcp_timer, 0, rtx * 1000, &XdmcpTimerNotify, null);
}

/*
 * The session is declared dead for some reason; too many
 * timeouts, or Keepalive failure.
 */

private void XdmcpDeadSession(const(char)* reason)
{
    ErrorF("XDM: %s, declaring session dead\n", reason);
    state = XDM_INIT_STATE;
    isItTimeToYield = True;
    dispatchException |= DE_TERMINATE;
    TimerCancel(xdmcp_timer);
    timeOutRtx = 0;
    send_packet();
}

/*
 * Timeout waiting for an XDMCP response.
 */

private void timeout()
{
    timeOutRtx++;
    if (state == XDM_AWAIT_ALIVE_RESPONSE && timeOutRtx >= XDM_KA_RTX_LIMIT) {
        XdmcpDeadSession("too many keepalive retransmissions");
        return;
    }
    else if (timeOutRtx >= XDM_RTX_LIMIT) {
        dispatchException |= DE_TERMINATE;
        ErrorF("XDM: too many retransmissions\n");
        return;
    }

version (HAVE_GETADDRINFO) {
    if (state == XDM_COLLECT_QUERY || state == XDM_COLLECT_INDIRECT_QUERY) {
        /* Try next address */
        for (mgrAddr = mgrAddr.ai_next;; mgrAddr = mgrAddr.ai_next) {
            if (mgrAddr is null) {
                mgrAddr = mgrAddrFirst;
            }
            if (mgrAddr.ai_family == AF_INET)
                break;
static if (IPv6){
            if (mgrAddr.ai_family == AF_INET6)
                break;
}
        }
version (SIN6_LEN) {} else {
        ManagerAddressLen = mgrAddr.ai_addrlen;
}
        memcpy(&ManagerAddress, mgrAddr.ai_addr, mgrAddr.ai_addrlen);
    }
}

    switch (state) {
    case XDM_COLLECT_QUERY:
        state = XDM_QUERY;
        break;
    case XDM_COLLECT_BROADCAST_QUERY:
        state = XDM_BROADCAST;
        break;
static if (IPv6){
    case XDM_COLLECT_MULTICAST_QUERY:
        state = XDM_MULTICAST;
        break;
}
    case XDM_COLLECT_INDIRECT_QUERY:
        state = XDM_INDIRECT;
        break;
    case XDM_AWAIT_REQUEST_RESPONSE:
        state = XDM_START_CONNECTION;
        break;
    case XDM_AWAIT_MANAGE_RESPONSE:
        state = XDM_MANAGE;
        break;
    case XDM_AWAIT_ALIVE_RESPONSE:
        state = XDM_KEEPALIVE;
        break;
    default:
        break;
    }
    send_packet();
}

private int XdmcpCheckAuthentication(ARRAY8Ptr Name, ARRAY8Ptr Data, int packet_type)
{
    return (XdmcpARRAY8Equal(Name, AuthenticationName) &&
            (AuthenticationName.length == 0 ||
             (*AuthenticationFuncs.Validator) (AuthenticationData, Data,
                                                packet_type)));
}

private int XdmcpAddAuthorization(ARRAY8Ptr name, ARRAY8Ptr data)
{
    if (AuthenticationFuncs && AuthenticationFuncs.AddAuth)
        return AuthenticationFuncs.AddAuth(
                       cast(ushort) name.length,
                       cast(char*) name.data,
                       cast(ushort) data.length, cast(char*) data.data);
    else
        return AddAuthorization(
                       cast(ushort) name.length,
                       cast(char*) name.data,
                       cast(ushort) data.length, cast(char*) data.data);
}

/*
 * from here to the end of this file are routines private
 * to the state machine.
 */

private void get_xdmcp_sock()
{
    int soopts = 1;
    int socketfd = -1;

static if (IPv6){
    if ((xdmcpSocket6 = core.sys.posix.sys.socket.socket(AF_INET6, core.sys.posix.sys.socket.SOCK_DGRAM, 0)) < 0)
        XdmcpWarning("INET6 UDP socket creation failed");
}
    if ((xdmcpSocket = core.sys.posix.sys.socket.socket(AF_INET, core.sys.posix.sys.socket.SOCK_DGRAM, 0)) < 0)
        XdmcpWarning("UDP socket creation failed");
version (SO_BROADCAST) {
    if (setsockopt(xdmcpSocket, SOL_SOCKET, SO_BROADCAST, &soopts,
                        sizeof) < 0)
        XdmcpWarning("UDP set broadcast socket-option failed");
}                          /* SO_BROADCAST */

    if (xdm_from is null)
        return;

    if (mixin(SOCKADDR_FAMILY!(`FromAddress`)) == AF_INET)
        socketfd = xdmcpSocket;
static if (IPv6){
    if(mixin(SOCKADDR_FAMILY!("FromAddress")) == AF_INET6)
        socketfd = xdmcpSocket6;
}
    if (socketfd >= 0) {
        if (bind(socketfd, cast(os.access.sockaddr*) &FromAddress,
                 FromAddressLen) < 0) {
            FatalError("Xserver: failed to bind to -from address: %s\n",
                       xdm_from);
        }
    }
}

private void send_query_msg()
{
    XdmcpHeader header = void;
    Bool broadcast = False;

static if (IPv6){
    Bool multicast = False;
}
    int i = void;
    int socketfd = xdmcpSocket;

    header.version_ = XDM_PROTOCOL_VERSION;
    switch (state) {
    case XDM_QUERY:
        header.opcode = cast(CARD16) QUERY;
        state = XDM_COLLECT_QUERY;
        break;
    case XDM_BROADCAST:
        header.opcode = cast(CARD16) BROADCAST_QUERY;
        state = XDM_COLLECT_BROADCAST_QUERY;
        broadcast = False;
        break;
static if (IPv6){
    case XDM_MULTICAST:
        header.opcode = cast(CARD16) BROADCAST_QUERY;
        state = XDM_COLLECT_MULTICAST_QUERY;
        multicast = False;
        break;
}
    case XDM_INDIRECT:
        header.opcode = cast(CARD16) INDIRECT_QUERY;
        state = XDM_COLLECT_INDIRECT_QUERY;
        break;
    default:
        break;
    }
    header.length = 1;
    for (i = 0; i < AuthenticationNames.length; i++)
        header.length += 2 + AuthenticationNames.data[i].length;

    XdmcpWriteHeader(&buffer, &header);
    XdmcpWriteARRAYofARRAY8(&buffer, &AuthenticationNames);
    if (broadcast) {
        for (i = 0; i < NumBroadcastAddresses; i++)
            XdmcpFlush(xdmcpSocket, &buffer,
                       cast(XdmcpNetaddr) &BroadcastAddresses[i],
                       os.access.sockaddr_in.sizeof);
    }
static if (IPv6){
    if(multicast) {
        multicastinfo* mcl = void;
        addrinfo* ai = void;

        for (mcl = mcastlist; mcl !is null; mcl = mcl.next) {
            for (ai = mcl.ai; ai !is null; ai = ai.ai_next) {
                if (ai.ai_family == AF_INET) {
                    ubyte hopflag = cast(ubyte) mcl.hops;

                    socketfd = xdmcpSocket;
                    core.sys.posix.sys.socket.setsockopt(socketfd, core.sys.linux.netinet.in_.IPPROTO_IP, core.sys.linux.netinet.in_.IP_MULTICAST_TTL,
                               &hopflag, hopflag.sizeof);
                }
                else if (ai.ai_family == AF_INET6) {
                    int hopflag6 = mcl.hops;

                    socketfd = xdmcpSocket6;
                    core.sys.posix.sys.socket.setsockopt(socketfd, core.sys.linux.netinet.in_.IPPROTO_IPV6, core.sys.linux.netinet.in_.IPV6_MULTICAST_HOPS,
                               &hopflag6, hopflag6.sizeof);
                }
                else {
                    continue;
                }
                XdmcpFlush(socketfd, &buffer,
                           cast(XdmcpNetaddr) ai.ai_addr, ai.ai_addrlen);
                break;
            }
        }
    }
}
    else {
static if (IPv6){
        if (mixin(SOCKADDR_FAMILY!(`ManagerAddress`)) == AF_INET6)
            socketfd = xdmcpSocket6;
}
        XdmcpFlush(socketfd, &buffer, (XdmcpNetaddr) &ManagerAddress,
                   ManagerAddressLen);
    }
}

private void recv_willing_msg(core.sys.posix.sys.socket.sockaddr* from, int fromlen, uint length)
{
    ARRAY8 authenticationName = void;
    ARRAY8 hostname = void;
    ARRAY8 status = void;

    authenticationName.data = null;
    hostname.data = null;
    status.data = null;
    if (XdmcpReadARRAY8(&buffer, &authenticationName) &&
        XdmcpReadARRAY8(&buffer, &hostname) &&
        XdmcpReadARRAY8(&buffer, &status)) {
        if (length == 6 + authenticationName.length +
            hostname.length + status.length) {
            switch (state) {
            case XDM_COLLECT_QUERY:
                XdmcpSelectHost(from, fromlen, &authenticationName);
                break;
            case XDM_COLLECT_BROADCAST_QUERY:
static if (IPv6){
            case XDM_COLLECT_MULTICAST_QUERY:
}
            case XDM_COLLECT_INDIRECT_QUERY:
                XdmcpAddHost(from, fromlen, &authenticationName, &hostname,
                             &status);
                break;
            default:
                break;
            }
        }
    }
    XdmcpDisposeARRAY8(&authenticationName);
    XdmcpDisposeARRAY8(&hostname);
    XdmcpDisposeARRAY8(&status);
}

private void send_request_msg()
{
    XdmcpHeader header = void;
    int length = void;
    int i = void;
    CARD16 XdmcpConnectionType = void;
    ARRAY8 authenticationData = void;
    int socketfd = xdmcpSocket;

    switch (mixin(SOCKADDR_FAMILY!(`ManagerAddress`))) {
    case AF_INET:
        XdmcpConnectionType = FamilyInternet;
        break;
static if (IPv6){
    case AF_INET6:
        XdmcpConnectionType = FamilyInternet6;
        break;
}
    default:
        XdmcpConnectionType = 0xffff;
        break;
    }

    header.version_ = XDM_PROTOCOL_VERSION;
    header.opcode = cast(CARD16) xdmOpCode.REQUEST;

    length = 2;                 /* display number */
    length += 1 + 2 * ConnectionTypes.length;   /* connection types */
    length += 1;                /* connection addresses */
    for (i = 0; i < ConnectionAddresses.length; i++)
        length += 2 + ConnectionAddresses.data[i].length;
    authenticationData.length = 0;
    authenticationData.data = null;
    if (AuthenticationFuncs) {
        (*AuthenticationFuncs.Generator) (AuthenticationData,
                                           &authenticationData, xdmOpCode.REQUEST);
    }
    length += 2 + AuthenticationName.length;   /* authentication name */
    length += 2 + authenticationData.length;    /* authentication data */
    length += 1;                /* authorization names */
    for (i = 0; i < AuthorizationNames.length; i++)
        length += 2 + AuthorizationNames.data[i].length;
    length += 2 + ManufacturerDisplayID.length; /* display ID */
    header.length = cast(ushort)length;

    if (!XdmcpWriteHeader(&buffer, &header)) {
        XdmcpDisposeARRAY8(&authenticationData);
        return;
    }
    XdmcpWriteCARD16(&buffer, DisplayNumber);
    XdmcpWriteCARD8(&buffer, ConnectionTypes.length);

    /* The connection array is send reordered, so that connections of   */
    /* the same address type as the XDMCP manager connection are send   */
    /* first. This works around a bug in xdm. mario@klebsch.de          */
    for (i = 0; i < cast(int) ConnectionTypes.length; i++)
        if (ConnectionTypes.data[i] == XdmcpConnectionType)
            XdmcpWriteCARD16(&buffer, ConnectionTypes.data[i]);
    for (i = 0; i < cast(int) ConnectionTypes.length; i++)
        if (ConnectionTypes.data[i] != XdmcpConnectionType)
            XdmcpWriteCARD16(&buffer, ConnectionTypes.data[i]);

    XdmcpWriteCARD8(&buffer, ConnectionAddresses.length);
    for (i = 0; i < cast(int) ConnectionAddresses.length; i++)
        if ((i < ConnectionTypes.length) &&
            (ConnectionTypes.data[i] == XdmcpConnectionType))
            XdmcpWriteARRAY8(&buffer, &ConnectionAddresses.data[i]);
    for (i = 0; i < cast(int) ConnectionAddresses.length; i++)
        if ((i >= ConnectionTypes.length) ||
            (ConnectionTypes.data[i] != XdmcpConnectionType))
            XdmcpWriteARRAY8(&buffer, &ConnectionAddresses.data[i]);

    XdmcpWriteARRAY8(&buffer, AuthenticationName);
    XdmcpWriteARRAY8(&buffer, &authenticationData);
    XdmcpDisposeARRAY8(&authenticationData);
    XdmcpWriteARRAYofARRAY8(&buffer, &AuthorizationNames);
    XdmcpWriteARRAY8(&buffer, &ManufacturerDisplayID);
static if (IPv6){
    if (mixin(SOCKADDR_FAMILY!(`req_sockaddr`)) == AF_INET6)
        socketfd = xdmcpSocket6;
}
    if (XdmcpFlush(socketfd, &buffer,
                   cast(XdmcpNetaddr) &req_sockaddr, req_socklen))
        state = XDM_AWAIT_REQUEST_RESPONSE;
}

private void recv_accept_msg(uint length)
{
    CARD32 AcceptSessionID = void;
    ARRAY8 AcceptAuthenticationName = void, AcceptAuthenticationData = void;
    ARRAY8 AcceptAuthorizationName = void, AcceptAuthorizationData = void;

    if (state != XDM_AWAIT_REQUEST_RESPONSE)
        return;
    AcceptAuthenticationName.data = null;
    AcceptAuthenticationData.data = null;
    AcceptAuthorizationName.data = null;
    AcceptAuthorizationData.data = null;
    if (XdmcpReadCARD32(&buffer, &AcceptSessionID) &&
        XdmcpReadARRAY8(&buffer, &AcceptAuthenticationName) &&
        XdmcpReadARRAY8(&buffer, &AcceptAuthenticationData) &&
        XdmcpReadARRAY8(&buffer, &AcceptAuthorizationName) &&
        XdmcpReadARRAY8(&buffer, &AcceptAuthorizationData)) {
        if (length == 12 + AcceptAuthenticationName.length +
            AcceptAuthenticationData.length +
            AcceptAuthorizationName.length + AcceptAuthorizationData.length) {
            if (!XdmcpCheckAuthentication(&AcceptAuthenticationName,
                                          &AcceptAuthenticationData, ACCEPT)) {
                XdmcpFatal("Authentication Failure", &AcceptAuthenticationName);
            }
            /* permit access control manipulations from this host */
            AugmentSelf(&req_sockaddr, req_socklen);
            /* if the authorization specified in the packet fails
             * to be acceptable, enable the local addresses
             */
            if (!XdmcpAddAuthorization(&AcceptAuthorizationName,
                                       &AcceptAuthorizationData)) {
                AddLocalHosts();
            }
            SessionID = AcceptSessionID;
            state = XDM_MANAGE;
            send_packet();
        }
    }
    XdmcpDisposeARRAY8(&AcceptAuthenticationName);
    XdmcpDisposeARRAY8(&AcceptAuthenticationData);
    XdmcpDisposeARRAY8(&AcceptAuthorizationName);
    XdmcpDisposeARRAY8(&AcceptAuthorizationData);
}

private void recv_decline_msg(uint length)
{
    ARRAY8 status = void, DeclineAuthenticationName = void, DeclineAuthenticationData = void;

    status.data = null;
    DeclineAuthenticationName.data = null;
    DeclineAuthenticationData.data = null;
    if (XdmcpReadARRAY8(&buffer, &status) &&
        XdmcpReadARRAY8(&buffer, &DeclineAuthenticationName) &&
        XdmcpReadARRAY8(&buffer, &DeclineAuthenticationData)) {
        if (length == 6 + status.length +
            DeclineAuthenticationName.length +
            DeclineAuthenticationData.length &&
            XdmcpCheckAuthentication(&DeclineAuthenticationName,
                                     &DeclineAuthenticationData, DECLINE)) {
            XdmcpFatal("Session declined", &status);
        }
    }
    XdmcpDisposeARRAY8(&status);
    XdmcpDisposeARRAY8(&DeclineAuthenticationName);
    XdmcpDisposeARRAY8(&DeclineAuthenticationData);
}

private void send_manage_msg()
{
    XdmcpHeader header = void;
    int socketfd = xdmcpSocket;

    header.version_ = XDM_PROTOCOL_VERSION;
    header.opcode = cast(CARD16) MANAGE;
    header.length = cast(ushort)(8 + DisplayClass.length);

    if (!XdmcpWriteHeader(&buffer, &header))
        return;
    XdmcpWriteCARD32(&buffer, cast(uint)SessionID);
    XdmcpWriteCARD16(&buffer, DisplayNumber);
    XdmcpWriteARRAY8(&buffer, &DisplayClass);
    state = XDM_AWAIT_MANAGE_RESPONSE;
static if (IPv6){
    if (mixin(SOCKADDR_FAMILY!(`req_sockaddr`)) == AF_INET6)
        socketfd = xdmcpSocket6;
}
    XdmcpFlush(socketfd, &buffer, cast(XdmcpNetaddr) &req_sockaddr, req_socklen);
}

private void recv_refuse_msg(uint length)
{
    CARD32 RefusedSessionID = void;

    if (state != XDM_AWAIT_MANAGE_RESPONSE)
        return;
    if (length != 4)
        return;
    if (XdmcpReadCARD32(&buffer, &RefusedSessionID)) {
        if (RefusedSessionID == SessionID) {
            state = XDM_START_CONNECTION;
            send_packet();
        }
    }
}

private void recv_failed_msg(uint length)
{
    CARD32 FailedSessionID = void;
    ARRAY8 status = void;

    if (state != XDM_AWAIT_MANAGE_RESPONSE)
        return;
    status.data = null;
    if (XdmcpReadCARD32(&buffer, &FailedSessionID) &&
        XdmcpReadARRAY8(&buffer, &status)) {
        if (length == 6 + status.length && SessionID == FailedSessionID) {
            XdmcpFatal("Session failed", &status);
        }
    }
    XdmcpDisposeARRAY8(&status);
}

private void send_keepalive_msg()
{
    XdmcpHeader header = void;
    int socketfd = xdmcpSocket;

    header.version_ = XDM_PROTOCOL_VERSION;
    header.opcode = cast(CARD16) KEEPALIVE;
    header.length = 6;

    XdmcpWriteHeader(&buffer, &header);
    XdmcpWriteCARD16(&buffer, DisplayNumber);
    XdmcpWriteCARD32(&buffer, cast(uint)SessionID);

    state = XDM_AWAIT_ALIVE_RESPONSE;
static if (IPv6){
    if (mixin(SOCKADDR_FAMILY!(`req_sockaddr`)) == AF_INET6)
        socketfd = xdmcpSocket6;
}
    XdmcpFlush(socketfd, &buffer, cast(XdmcpNetaddr) &req_sockaddr, req_socklen);
}

private void recv_alive_msg(uint length)
{
    CARD8 SessionRunning = void;
    CARD32 AliveSessionID = void;

    if (state != XDM_AWAIT_ALIVE_RESPONSE)
        return;
    if (length != 5)
        return;
    if (XdmcpReadCARD8(&buffer, &SessionRunning) &&
        XdmcpReadCARD32(&buffer, &AliveSessionID)) {
        if (SessionRunning && AliveSessionID == SessionID) {
            state = XDM_RUN_SESSION;
            TimerSet(xdmcp_timer, 0, XDM_DEF_DORMANCY * 1000, &XdmcpTimerNotify, null);
        }
        else {
            XdmcpDeadSession("Alive response indicates session dead");
        }
    }
}

private noreturn XdmcpFatal(const(char)* type, ARRAY8Ptr status)
{
    FatalError("XDMCP fatal error: %s %*.*s\n", type,
               status.length, status.length, status.data);
    assert(0);
}

private void XdmcpWarning(const(char)* str)
{
    ErrorF("XDMCP warning: %s\n", str);
}

private void get_addr_by_name(const(char)* argtype, 
        const(char)* namestr, 
        int port, 
        int socktype, 
        SOCKADDR_TYPE* addr, 
        SOCKLEN_TYPE* addrlen, 
        addrinfo** aip,
        addrinfo **aifirstp)
{
version (HAVE_GETADDRINFO) {
    addrinfo* ai;
    addrinfo hints;
    char[6] portstr = 0;
    char* pport = portstr;
    int gaierr;

    memset(&hints, 0, hints.sizeof);
    hints.ai_socktype = socktype;

    if (port == 0) {
        pport = null;
    }
    else if (port > 0 && port < 65535) {
        snprintf(portstr.ptr, portstr.sizeof, "%d", port);
    }
    else {
        FatalError("Xserver: port out of range: %d\n", port);
    }

    if (*aifirstp !is null) {
        freeaddrinfo(*aifirstp);
        *aifirstp = null;
    }

    if ((gaierr = getaddrinfo(namestr, pport, &hints, aifirstp)) == 0) {
        for (ai = *aifirstp; ai !is null; ai = ai.ai_next) {
            if (ai.ai_family == AF_INET)
                break;
static if (IPv6){
            if (ai.ai_family == AF_INET6)
                break;
}
        }
        if ((ai is null) || (ai.ai_addrlen > SOCKADDR_TYPE.sizeof)) {
            FatalError("Xserver: %s host %s not on supported network type\n",
                       argtype, namestr);
        }
        else {
            *aip = ai;
            *addrlen = ai.ai_addrlen;
            memcpy(addr, ai.ai_addr, ai.ai_addrlen);
        }
    }
    else {
        FatalError("Xserver: %s: %s %s\n", gai_strerror(gaierr), argtype,
                   namestr);
    }
} else { /* HAVE_GETADDRINFO */
    hostent* hep;

// version (XTHREADS_NEEDS_BYNAMEPARAMS) {
    // _Xgethostbynameparams hparams;
// }
    ossock_init();
    // if (((hep = _XGethostbyname(namestr, hparams)) == 0)) {
    if (((hep = _XGethostbyname(namestr)) is null)) {

        FatalError("Xserver: %s unknown host: %s\n", argtype, namestr);
    }
    if (hep.h_length == os.access.in_addr.sizeof) {
        memcpy(&addr.sin_addr, hep.h_addr, hep.h_length);
        *addrlen = os.access.sockaddr_in.sizeof;
        addr.sin_family = AF_INET;
        addr.sin_port = core.sys.posix.arpa.inet.htons(cast(ushort)port);
    }
    else {
        FatalError("Xserver: %s host on strange network %s\n", argtype,
                   namestr);
    }
} /* HAVE_GETADDRINFO */
}

private void get_manager_by_name(int argc, char** argv, int i)
{

    if ((i + 1) == argc) {
        FatalError("Xserver: missing %s host name in command line\n", argv[i]);
    }

static if(HAVE_GETADDRINFO) {
    get_addr_by_name(argv[i], argv[i + 1], 
    xdm_udp_port, core.sys.posix.sys.socket.SOCK_DGRAM,
                     &ManagerAddress, &ManagerAddressLen, null, null);

}
else {
    get_addr_by_name(argv[i], argv[i + 1], xdm_udp_port, core.sys.posix.sys.socket.SOCK_DGRAM,
                     &ManagerAddress, &ManagerAddressLen
                     , &mgrAddr, &mgrAddrFirst
        );
}
}


private void get_fromaddr_by_name(int argc, char** argv, int i)
{
static if(HAVE_GETADDRINFO) {
    addrinfo* ai = null;
    addrinfo* aifirst = null;
}
    if (i == argc) {
        FatalError("Xserver: missing -from host name in command line\n");
    }
    get_addr_by_name("-from", argv[i], 0, 0, &FromAddress, &FromAddressLen
                     ,&ai, &aifirst
        );
static if(HAVE_GETADDRINFO) {
    if (aifirst !is null)
        freeaddrinfo(aifirst);
}
    xdm_from = argv[i];
}

static if (IPv6){
private int get_mcast_options(int argc, char** argv, int i)
{
    const(char)* address = XDM_DEFAULT_MCAST_ADDR6;
    int hopcount = 1;
    addrinfo hints = void;
    char[6] portstr = void;
    int gaierr = void;
    addrinfo* ai = void, firstai = void;

    if ((i < argc) && (argv[i][0] != '-') && (argv[i][0] != '+')) {
        address = argv[i++];
        if ((i < argc) && (argv[i][0] != '-') && (argv[i][0] != '+')) {
            hopcount = cast(int)strtol(argv[i++], null, 10);
            if ((hopcount < 1) || (hopcount > 255)) {
                FatalError("Xserver: multicast hop count out of range: %d\n",
                           hopcount);
            }
        }
    }

    if (xdm_udp_port > 0 && xdm_udp_port < 65535) {
        snprintf(portstr.ptr, portstr.sizeof, "%d", xdm_udp_port);
    }
    else {
        FatalError("Xserver: port out of range: %d\n", xdm_udp_port);
    }
    memset(&hints, 0, hints.sizeof);
    hints.ai_socktype = core.sys.posix.sys.socket.SOCK_DGRAM;

    if ((gaierr = getaddrinfo(address, portstr.ptr, &hints, &firstai)) == 0) {
        for (ai = firstai; ai !is null; ai = ai.ai_next) {
            if (((ai.ai_family == AF_INET) &&
                 IN_MULTICAST((cast(os.access.sockaddr_in*) ai.ai_addr)
                              .sin_addr.s_addr))
                || ((ai.ai_family == AF_INET6) &&
                    core.sys.posix.netinet.in_.IN6_IS_ADDR_MULTICAST!()(&(cast(core.sys.posix.netinet.in_.sockaddr_in6*) ai.ai_addr)
                                          .sin6_addr)))
                break;
        }
        if (ai is null) {
            FatalError("Xserver: address not supported multicast type %s\n",
                       address);
        }
        else {
            multicastinfo* mcastinfo = void, mcl = void;

            mcastinfo = cast(multicastinfo*) cast(multicastinfo*) calloc(1, multicastinfo.sizeof);
            if (!mcastinfo)
                FatalError("Xserver: failed to allocate mcastinfo\n");

            mcastinfo.ai = firstai;
            mcastinfo.hops = hopcount;

            if (mcastlist is null) {
                mcastlist = mcastinfo;
            }
            else {
                for (mcl = mcastlist; mcl.next !is null; mcl = mcl.next) {
                    /* Do nothing  - just find end of list */
                }
                mcl.next = mcastinfo;
            }
        }
    }
    else {
        FatalError("Xserver: %s: %s\n", gai_strerror(gaierr), address);
    }
    return i;
}
}

} else {
private int xdmcp_non_empty;     /* avoid complaint by ranlib */
}                          /* XDMCP */
