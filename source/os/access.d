module os.access;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/***********************************************************

Copyright 1987, 1998  The Open Group

All rights reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, and/or sell copies of the Software, and to permit persons
to whom the Software is furnished to do so, provided that the above
copyright notice(s) and this permission notice appear in all copies of
the Software and that both the above copyright notice(s) and this
permission notice appear in supporting documentation.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT
OF THIRD PARTY RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
HOLDERS INCLUDED IN THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL
INDIRECT OR CONSEQUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING
FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION
WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

Except as contained in this notice, the name of a copyright holder
shall not be used in advertising or otherwise to promote the sale, use
or other dealings in this Software without prior written authorization
of the copyright holder.

X Window System is a trademark of The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

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

/*
 * Copyright (c) 2004, Oracle and/or its affiliates.
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

import build.xlibre_server;

version (Windows) {
//import externs.X11.Xwinsock;
}
import core.sys.posix.pwd ;
import core.sys.posix.unistd;
import core.stdc.stdio;
import core.stdc.stdlib;
import os.Xtrans;
// import externs.X11.Xauth;
//import x11.X;
//import x11.Xproto;
import common.misc;
import core.stdc.errno;
import core.sys.posix.sys.types;
import x11.Xosdefs;

import dix.server_priv;
import os.io_priv;
import os.xhostname;
import externs.gnu;
import os.log;
import trutils = os.Xtransutil;
import os.Xtranssock;
import os.Xtransint;
alias sockaddr_in = core.sys.posix.netinet.in_.sockaddr_in;
version (Windows) {} else {
import core.sys.posix.sys.socket;
import core.sys.posix.sys.ioctl;
import core.stdc.ctype;

version (NO_LOCAL_CLIENT_CRED) {} else {
import core.sys.posix.pwd;
}

import core.sys.posix.netinet.in_;

version (HAVE_GETPEERUCRED) {
import ucred;
version (__sun) {
import zone;
}
}

version (HAVE_SYS_UCRED_H) {
import sys.ucred;
}

version (HAVE_SYS_UN_H) {
import core.sys.posix.sys.un;
}

static if (HasVersion!"SVR4" || HasVersion!"__GNU__") {
import core.sys.posix.sys.utsname;
}
version (__GNU__) {
import core.sys.posix.netdb;
} else {                           /*!__GNU__ */
import externs.net.if_;
} /*__GNU__ */

version (SVR4) {
import sys.sockio;
import sys.stropts;
}

import core.sys.posix.netdb;

static if(CSRG_BASED) {
import sys.param;
static if ((BSD >= 199103)) {
version = VARIABLE_IFREQ;
}
}

version (BSD44SOCKETS) {
 

}

version (HAVE_GETIFADDRS) {
import ifaddrs;
} else {

/* Solaris provides an extended interface SIOCGLIFCONF. */
version (SIOCGLIFCONF) {
version = USE_SIOCGLIFCONF;
}
} /* HAVE_GETIFADDRS */

import core.sys.posix.arpa.inet;

}                          /* WIN32 */

static if (!HasVersion!"Windows" || HasVersion!"Cygwin") {
import core.sys.posix.libgen;
}

version = X_INCLUDE_NETDB_H;
// import x11.Xos_r;

import os.auth;
import os.client_priv;
import os.osdep;

import dix.dixstruct_priv;

import Xext.xace;

static if(build.xlibre_server.XDMCP){
import os.xdmcp;
}

import os.Xtransutil;

alias sockaddr = core.sys.posix.sys.socket.sockaddr;

Bool defeatAccessControl = FALSE;

enum string addrEqual(string fam, string address, string length, string host) = `
			 ((` ~ fam ~ `) == (` ~ host ~ `).family &&
			  (` ~ length ~ `) == (` ~ host ~ `).len &&
			  !memcmp (cast(void*)` ~ address ~ `, (` ~ host ~ `).addr, ` ~ length ~ `))`;







/* XFree86 bug #156: To keep track of which hosts were explicitly requested in
   /etc/X<display>.hosts, we've added a requested field to the HOST struct,
   and a LocalHostRequested variable.  These default to FALSE, but are set
   to TRUE in ResetHosts when reading in /etc/X<display>.hosts.  They are
   checked in DisableLocalHost(), which is called to disable the default
   local host entries when stronger authentication is turned on. */

struct _host {
    short family;
    short len;
    ubyte* addr;
    _host* next;
    int requested;
}

alias HOST = _host;

enum string MakeHost(string h,string l) = `(` ~ h ~ `)=cast(typeof(`~h~`))calloc(1, ((*` ~ h ~ `).sizeof+(` ~ l ~ `)));
			if (` ~ h ~ `) { 
			   (` ~ h ~ `).addr=cast(ubyte*) ((` ~ h ~ `) + 1);
			   (` ~ h ~ `).requested = FALSE; 
			}`;
enum string FreeHost(string h) = `free(` ~ h ~ `);`;
private HOST* selfhosts = null;
private HOST* validhosts = null;
private int AccessEnabled = TRUE;
private int LocalHostEnabled = FALSE;
private int LocalHostRequested = FALSE;
private int UsingXdmcp = FALSE;

alias in_addr = core.sys.posix.arpa.inet.in_addr;

enum _LocalAccessScope {
    LOCAL_ACCESS_SCOPE_HOST = 0,
// #ifndef NO_LOCAL_CLIENT_CRED
    LOCAL_ACCESS_SCOPE_USER,
}


private _LocalAccessScope LocalAccessScope;

/* FamilyServerInterpreted implementation */







version (NO_LOCAL_CLIENT_CRED) {} else {


}

/*
 * called when authorization is not enabled to add the
 * local host to the access list
 */

void EnableLocalAccess()
{
    switch (LocalAccessScope) {
        case _LocalAccessScope.LOCAL_ACCESS_SCOPE_HOST:
            EnableLocalHost();
            break;
version (NO_LOCAL_CLIENT_CRED) {} else {
        case _LocalAccessScope.LOCAL_ACCESS_SCOPE_USER:
            EnableLocalUser();
            break;
}
    default: break;}
}

private void EnableLocalHost()
{
    if (!UsingXdmcp) {
        LocalHostEnabled = TRUE;
        AddLocalHosts();
    }
}

/*
 * called when authorization is enabled to keep us secure
 */
void DisableLocalAccess()
{
    switch (LocalAccessScope) {
        case _LocalAccessScope.LOCAL_ACCESS_SCOPE_HOST:
            DisableLocalHost();
            break;
version (NO_LOCAL_CLIENT_CRED) {} else {
        case _LocalAccessScope.LOCAL_ACCESS_SCOPE_USER:
            DisableLocalUser();
            break;
}
    default: break;}
}

private void DisableLocalHost()
{
    HOST* self = void;

    if (!LocalHostRequested)    /* Fix for XFree86 bug #156 */
        LocalHostEnabled = FALSE;
    for (self = selfhosts; self; self = self.next) {
        if (!self.requested)   /* Fix for XFree86 bug #156 */
            cast(void) RemoveHost(cast(ClientPtr) null, self.family, self.len,
                              cast(void*) self.addr);
    }
}

version (NO_LOCAL_CLIENT_CRED) {} else {
private int GetLocalUserAddr(char** addr)
{
    static const(char)* type = "localuser";
    static const(char) delimiter = '\0';
    static const(char)* value;
    passwd* pw = void;
    int length = -1;

    pw = getpwuid(getuid());

    if (pw is null || pw.pw_name is null)
        goto out_;

    value = pw.pw_name;

    length = asprintf(addr, "%s%c%s", type, delimiter, value);

    if (length == -1) {
        goto out_;
    }

    /* Trailing NUL */
    length++;

out_:
    return length;
}

private void EnableLocalUser()
{
    char* addr = null;
    int length = -1;

    length = GetLocalUserAddr(&addr);

    if (length == -1)
        return;

    NewHost(FamilyServerInterpreted, addr, length, TRUE);

    free(addr);
}

private void DisableLocalUser()
{
    char* addr = null;
    int length = -1;

    length = GetLocalUserAddr(&addr);

    if (length == -1)
        return;

    RemoveHost(null, FamilyServerInterpreted, length, addr);

    free(addr);
}

void LocalAccessScopeUser()
{
    LocalAccessScope =  _LocalAccessScope.LOCAL_ACCESS_SCOPE_USER;
}
}

/*
 * called at init time when XDMCP will be used; xdmcp always
 * adds local hosts manually when needed
 */

void AccessUsingXdmcp()
{
    UsingXdmcp = TRUE;
    LocalHostEnabled = FALSE;
}

/*
 * DefineSelf (fd):
 *
 * Define this host for access control.  Find all the hosts the OS knows about
 * for this fd and add them to the selfhosts list.
 */
alias caddr_t = char*;
static if(!HasVersion!"SIOCGIFCONF") {
    void DefineSelf(int fd)
    {
        int len = void;
        caddr_t addr = void;
        int family = void;
        HOST* host = void;
        hostent* hp = void;

        union _Saddr {
            sockaddr sa = void;
            sockaddr_in in_ = void;
            static if (IPv6){
                    core.sys.posix.netinet.in_.sockaddr_in6 in6 = void;
            }
        }
        _Saddr saddr = void;

        sockaddr_in* inetaddr = void;

        static if (IPv6){
            core.sys.posix.netinet.in_.sockaddr_in6* inet6addr = void;
        }
        
        sockaddr_in broad_addr = void;

        version (XTHREADS_NEEDS_BYNAMEPARAMS) {
            _Xgethostbynameparams hparams = void;
        }

        /* Why not use gethostname()?  Well, at least on my system, I've had to
        * make an ugly kernel patch to get a name longer than 8 characters, and
        * uname() lets me access to the whole string (it smashes release, you
        * see), whereas gethostname() kindly truncates it for me.
        */
        xhostname hn = void;
        f_xhostname(&hn);

        hp = _XGethostbyname(hn.name.ptr);
        if (hp !is null) {
            saddr.sa.sa_family = cast(ushort)hp.h_addrtype;
            switch (hp.h_addrtype) {
            case AF_INET:
                inetaddr = cast(sockaddr_in*) (&(saddr.sa));
                memcpy(&(inetaddr.sin_addr), hp.h_addr, hp.h_length);
                len = typeof(saddr.sa).sizeof;
                break;
            static if (IPv6){
            case AF_INET6:
                inet6addr = cast(core.sys.posix.netinet.in_.sockaddr_in6*) (&(saddr.sa));
                memcpy(&(inet6addr.sin6_addr), hp.h_addr, hp.h_length);
                len = typeof(saddr.in6).sizeof;
                break;
            }

            default:
                goto DefineLocalHost;
            }

            family = ConvertAddr(&(saddr.sa), &len, cast(void**) &addr);
            if (family != -1 && family != FamilyLocal) {
                for (host = selfhosts;
                    host && !mixin(addrEqual!(`family`, `addr`, `len`, `host`));
                    host = host.next){}
                if (!host) {
                    /* add this host to the host list.      */
                    mixin(MakeHost!(`host`, `len`));
                        if (host) {
                        host.family = cast(short)family;
                        host.len = cast(short)len;
                        memcpy(host.addr, addr, len);
                        host.next = selfhosts;
                        selfhosts = host;
                    }
                    static if(build.xlibre_server.XDMCP){
                    /*
                    *  If this is an Internet Address, but not the localhost
                    *  address (127.0.0.1), nor the bogus address (0.0.0.0),
                    *  register it.
                    */
                        if (family == FamilyInternet &&
                            !(len == 4 &&
                            ((addr[0] == 127) ||
                            (addr[0] == 0 && addr[1] == 0 &&
                                addr[2] == 0 && addr[3] == 0)))
                            ) {
                            XdmcpRegisterConnection(family, cast(char*) addr, len);
                            broad_addr = *inetaddr;
                            (cast(sockaddr_in*) &broad_addr).sin_addr.s_addr =
                                core.sys.posix.arpa.inet.htonl(core.sys.posix.netinet.in_.INADDR_BROADCAST);
                            XdmcpRegisterBroadcastAddress(cast(sockaddr_in*)
                                                        &broad_addr);
                        }
                        static if (IPv6){
                            if (family == FamilyInternet6 &&
                                    !(IN6_IS_ADDR_LOOPBACK!()(cast(core.sys.posix.netinet.in_.in6_addr*)addr))) {
                                XdmcpRegisterConnection(family, cast(char*) addr, len);
                            }
                        }
                    }                                     /* XDMCP */
                }
            }
        }
    /*
     * now add a host of family FamilyLocalHost...
     */
        DefineLocalHost:
        for (host = selfhosts;
            host && !mixin(addrEqual!(`FamilyLocalHost`, `"".ptr`, `0`, `host`)); host = host.next){}
        if (!host) {
            mixin(MakeHost!(`host`, `0`));
            if (host) {
                host.family = FamilyLocalHost;
                host.len = 0;
                /* Nothing to store in host->addr */
                host.next = selfhosts;
                selfhosts = host;
            }
        }
    }
}//!version
 else {
    static if(HasVersion!"USE_SIOCGLIFCONF") {
        alias ifr_type =    lifreq;
    } else {
        alias ifr_type = ifreq;
    }

    version (VARIABLE_IFREQ) {
        enum string ifr_size(string p) = `(sizeof cast(ifreq) + 
                    (` ~ p ~ `.ifr_addr.sa_len > typeof(` ~ p ~ `.ifr_addr).sizeof ? 
                    ` ~ p ~ `.ifr_addr.sa_len - typeof(` ~ p ~ `.ifr_addr).sizeof : 0))`;
        enum string ifraddr_size(string a) = `(` ~ a ~ `.sa_len)`;
    } else {
        enum string ifr_size(string p) = `(ifr_type.sizeof)`;
        enum string ifraddr_size(string a) = `(` ~ a ~ `.sizeof)`;
    }

    static if (IPv6){
        private void in6_fillscopeid(sockaddr_in6* sin6)
        {
            version (__KAME__) {
                if (IN6_IS_ADDR_LINKLOCAL(&sin6.sin6_addr) && sin6.sin6_scope_id == 0) {
                    sin6.sin6_scope_id =
                    ntohs(*cast(u_int16_t*) &sin6.sin6_addr.s6_addr[2]);
                sin6.sin6_addr.s6_addr[2] = sin6.sin6_addr.s6_addr[3] = 0;
                }       
            }
        }
    }

    void    
    DefineSelf(int fd)
    {
        version (HAVE_GETIFADDRS) {} 
        else {
            char* cp, cplim;

            version (USE_SIOCGLIFCONF) {
                sockaddr_storage[16] buf;
                lifconf ifc;
                lifreq* ifr;

                version (SIOCGLIFNUM) {
                    lifnum ifn;
                }
            } else {                           /* !USE_SIOCGLIFCONF */
                char[2048] buf = 0;
                ifconf ifc;
                ifreq* ifr;
            }

            void* bufptr = buf;
        } 
        version (HAVE_GETIFADDRS) {                           /* HAVE_GETIFADDRS */
            ifaddrs* ifap, ifr;
        }

        int len;
        ubyte* addr;
        int family;
        HOST* host;

        static if(!HasVersion("HAVE_GETIFADDRS")) {
            len = buf.sizeof;
        }


        version (USE_SIOCGLIFCONF) {

            version (SIOCGLIFNUM) {
                ifn.lifn_family = AF_UNSPEC;
                ifn.lifn_flags = 0;
                if (ioctl(fd, SIOCGLIFNUM, cast(char*) &ifn) < 0)
                    ErrorF("Getting interface count: %s\n", strerror(errno));
                if (len < (ifn.lifn_count * lifreq.sizeof)) {
                    len = ifn.lifn_count * lifreq.sizeof;
                    if (((bufptr = calloc(1, len)) == 0)) {
                        FatalError("DefineSelf: failed to allocate memory\n");
                    }
                }
            }

            ifc.lifc_family = AF_UNSPEC;
            ifc.lifc_flags = 0;
            ifc.lifc_len = len;
            ifc.lifc_buf = bufptr;

            enum IFC_IOCTL_REQ = SIOCGLIFCONF;
            enum IFC_IFC_REQ = ifc.lifc_req;
            enum IFC_IFC_LEN = ifc.lifc_len;
            enum IFR_IFR_ADDR = ifr.lifr_addr;
            enum IFR_IFR_NAME = ifr.lifr_name;

        } else {                           /* Use SIOCGIFCONF */
            ifc.ifc_len = len;
            ifc.ifc_buf = bufptr;

            enum IFC_IOCTL_REQ = SIOCGIFCONF;
            enum IFC_IFC_REQ = ifc.ifc_req;
            enum IFC_IFC_LEN = ifc.ifc_len;
            enum IFR_IFR_ADDR = ifr.ifr_addr;
            enum IFR_IFR_NAME = ifr.ifr_name;
        }

        if (ioctl(fd, IFC_IOCTL_REQ, cast(void*) &ifc) < 0)
            ErrorF("Getting interface configuration (4): %s\n", strerror(errno));

        cplim = cast(char*) IFC_IFC_REQ + IFC_IFC_LEN;

        for (cp = cast(char*) IFC_IFC_REQ; cp < cplim; cp += mixin(ifr_size!(`ifr`))) {
            ifr = cast(ifaddrs*) (cast(ifr_type*) cp);
            len = mixin(ifraddr_size!(`IFR_IFR_ADDR`));
            family = ConvertAddr(cast(sockaddr*) &IFR_IFR_ADDR,
                             &len, cast(void**) &addr);
        if (family == -1 || family == FamilyLocal)
            continue;

        static if (IPv6){
            if (family == FamilyInternet6)
                in6_fillscopeid(cast(sockaddr_in6*) &IFR_IFR_ADDR);          
        }
        for (host = selfhosts;
             host && !mixin(addrEqual!(`family`, `addr`, `len`, `host`)); host = host.next){}
        if (host)
            continue;
        mixin(MakeHost!(`host`, `len`));
            if (host) {
            host.family = family;
            host.len = len;
            memcpy(host.addr, addr, len);
            host.next = selfhosts;
            selfhosts = host;
        }

        static if(XDMCP){
            version (USE_SIOCGLIFCONF) {
                sockaddr_storage broad_addr;
            } else {
                sockaddr broad_addr;
            }
            /*
             * If this isn't an Internet Address, don't register it.
             */
            static if(IPv6) {
                if (family != FamilyInternet 
                && family != FamilyInternet6)
                    continue;
            }
            else {
                if (family != FamilyInternet)
                    continue;
            }
            /*
             * ignore 'localhost' entries as they're not useful
             * on the other end of the wire
             */
            static if(IPv6) {
                if (family == FamilyInternet &&
                    addr[0] == 127 && addr[1] == 0 && addr[2] == 0 && addr[3] == 1)
                    
                    continue;
                else if (family == FamilyInternet6 &&
                     IN6_IS_ADDR_LOOPBACK(cast(in6_addr *) addr))
                continue;
            }
            else {
                if (family == FamilyInternet &&
                    addr[0] == 127 && addr[1] == 0 && addr[2] == 0 && addr[3] == 1)
                    
                    continue;
            }

            /*
             * Ignore '0.0.0.0' entries as they are
             * returned by some OSes for unconfigured NICs but they are
             * not useful on the other end of the wire.
             */
            if (len == 4 &&
                addr[0] == 0 && addr[1] == 0 && addr[2] == 0 && addr[3] == 0)
                continue;

            XdmcpRegisterConnection(family, cast(char*) addr, len);

            static if (IPv6){
                /* IPv6 doesn't support broadcasting, so we drop out here */
                if (family == FamilyInternet6)
                    continue;
            }

            broad_addr = IFR_IFR_ADDR;

            (cast(sockaddr_in*) &broad_addr).sin_addr.s_addr =
                htonl(INADDR_BROADCAST);

            static if (HasVersion!"USE_SIOCGLIFCONF" && HasVersion!"SIOCGLIFBRDADDR") {
                lifreq broad_req;

                broad_req = *ifr;
                if (ioctl(fd, SIOCGLIFFLAGS, cast(char*) &broad_req) != -1 &&
                    (broad_req.lifr_flags & IFF_BROADCAST) &&
                    (broad_req.lifr_flags & IFF_UP)
                    ) {
                    broad_req = *ifr;
                    if (ioctl(fd, SIOCGLIFBRDADDR, &broad_req) != -1)
                        broad_addr = broad_req.lifr_broadaddr;
                    else
                        continue;
                }
                else
                    continue;
            }
            } else version (SIOCGIFBRDADDR) {
                ifreq broad_req;

                broad_req = *ifr;
                if (ioctl(fd, SIOCGIFFLAGS, cast(void*) &broad_req) != -1 &&
                    (broad_req.ifr_flags & IFF_BROADCAST) &&
                    (broad_req.ifr_flags & IFF_UP)
                    ) {
                    broad_req = *ifr;
                    if (ioctl(fd, SIOCGIFBRDADDR, cast(void*) &broad_req) != -1)
                        broad_addr = broad_req.ifr_addr;
                    else
                        continue;
                }
                else
                    continue;
            }  
                                    /* SIOCGIFBRDADDR */
            XdmcpRegisterBroadcastAddress(cast(sockaddr_in*) &broad_addr);
        }
                                  /* XDMCP */
    if (bufptr != buf.ptr)
        free(bufptr);
         else {                           /* HAVE_GETIFADDRS */
    if (getifaddrs(&ifap) < 0) {
        ErrorF("Warning: getifaddrs returns %s\n", strerror(errno));
        return;
    }
    for (ifr = ifap; ifr !is null; ifr = ifr.ifa_next) {
        if (!ifr.ifa_addr)
            continue;
        len = typeof(*(ifr.ifa_addr)).sizeof;
        family = ConvertAddr(cast(sockaddr*) ifr.ifa_addr, &len,
                             cast(void**) &addr);
        if (family == -1 || family == FamilyLocal)
            continue;
static if (IPv6){
        if (family == FamilyInternet6)
            in6_fillscopeid(cast(sockaddr_in6*) ifr.ifa_addr);
}

        for (host = selfhosts;
             host !is null && !mixin(addrEqual!(`family`, `addr`, `len`, `host`));
             host = host.next){}
        if (host !is null)
            continue;
        mixin(MakeHost!(`host`, `len`));
        if (host !is null) {
            host.family = family;
            host.len = len;
            memcpy(host.addr, addr, len);
            host.next = selfhosts;
            selfhosts = host;
        }
static if(XDMCP){
            /*
             * If this isn't an Internet Address, don't register it.
             */
             static if(IPv6) {
                if (family != FamilyInternet
                    && family != FamilyInternet6
                    )
                    continue;
             }
             else {
            if (family != FamilyInternet
                )
                continue;
             }

            /*
             * ignore 'localhost' entries as they're not useful
             * on the other end of the wire
             */
            if (ifr.ifa_flags & IFF_LOOPBACK)
                continue;

            if (family == FamilyInternet &&
                addr[0] == 127 && addr[1] == 0 && addr[2] == 0 && addr[3] == 1)
                continue;

            /*
             * Ignore '0.0.0.0' entries as they are
             * returned by some OSes for unconfigured NICs but they are
             * not useful on the other end of the wire.
             */
version(IPv6) {
            if (len == 4 &&
                addr[0] == 0 && addr[1] == 0 && addr[2] == 0 && addr[3] == 0)
                continue;
            else if(family == FamilyInternet6 && IN6_IS_ADDR_LOOPBACK( addr))
                continue;
}
else {
        if (len == 4 &&
            addr[0] == 0 && addr[1] == 0 && addr[2] == 0 && addr[3] == 0)
            continue;
}

            XdmcpRegisterConnection(family, cast(char*) addr, len);
static if (IPv6){
            if (family == FamilyInternet6)
                /* IPv6 doesn't support broadcasting, so we drop out here */
                continue;
}
            if ((ifr.ifa_flags & IFF_BROADCAST) &&
                (ifr.ifa_flags & IFF_UP) && ifr.ifa_broadaddr)
                XdmcpRegisterBroadcastAddress(cast(sockaddr_in*) ifr.
                                              ifa_broadaddr);
            else
                continue;
}                          /* XDMCP */

    }                           /* for */
    freeifaddrs(ifap);
}                          /* HAVE_GETIFADDRS */

    /*
     * add something of FamilyLocalHost
     */
    for (host = selfhosts;
         host && !mixin(addrEqual!(`FamilyLocalHost`, `""`, `0`, `host`)); host = host.next){}
    if (!host) {
        mixin(MakeHost!(`host`, `0`));
        if (host) {
            host.family = FamilyLocalHost;
            host.len = 0;
            /* Nothing to store in host->addr */
            host.next = selfhosts;
            selfhosts = host;
        }
    }
}
}                          /* hpux && !HAVE_IFREQ */

static if(build.xlibre_server.XDMCP){
void AugmentSelf(void* from, int len)
{
    int family = void;
    void* addr = void;
    HOST* host = void;

    family = ConvertAddr(cast(sockaddr*)from, &len, cast(void**) &addr);
    if (family == -1 || family == FamilyLocal)
        return;
    for (host = selfhosts; host; host = host.next) {
        if (mixin(addrEqual!(`family`, `addr`, `len`, `host`)))
            return;
    }
    mixin(MakeHost!(`host`, `len`));
        if (!host)
        return;
    host.family = cast(short)family;
    host.len = cast(short)len;
    memcpy(host.addr, addr, len);
    host.next = selfhosts;
    selfhosts = host;
}
}

void AddLocalHosts()
{
    HOST* self = void;

    for (self = selfhosts; self; self = self.next)
        /* Fix for XFree86 bug #156: pass addingLocal = TRUE to
         * NewHost to tell that we are adding the default local
         * host entries and not to flag the entries as being
         * explicitly requested */
        cast(void) NewHost(self.family, self.addr, self.len, TRUE);
}

/* Reset access control list to initial hosts */
void ResetHosts(const(char)* display)
{
    HOST* host = void;
    char[120] lhostname = void, ohostname = void;
    char* hostname = ohostname.ptr;
    char[PATH_MAX + 1] fname = void;
    int fnamelen = void;
    FILE* fd = void;
    char* ptr = void;
    int i = void, hostlen = void;
    int family = 0;
    void* addr = null;
    int len = void;

    siTypesInitialize();
    AccessEnabled = !defeatAccessControl;
    LocalHostEnabled = FALSE;
    while ((host = validhosts) !is null) {
        validhosts = host.next;
        mixin(FreeHost!(`host`));
    }

static if (HasVersion!"Windows" && HasVersion!"Windows") {
    enum ETC_HOST_PREFIX = "X";
} else {
    enum ETC_HOST_PREFIX = "/etc/X";
}
    enum ETC_HOST_SUFFIX = ".hosts";
    fnamelen = cast(int)(strlen(ETC_HOST_PREFIX) + strlen(ETC_HOST_SUFFIX) +
        strlen(display) + 1);
    if (fnamelen > fname.sizeof)
        FatalError("Display name `%s' is too long\n", display);
    snprintf(fname.ptr, fname.sizeof, ETC_HOST_PREFIX ~ "%s"~ ETC_HOST_SUFFIX,
             display);

    if ((fd = fopen(fname.ptr, "r")) !is null) {
        while (fgets(ohostname.ptr, ohostname.sizeof, fd)) {
            family = FamilyWild;
            if (*ohostname.ptr == '#')
                continue;
            if ((ptr = strchr(ohostname.ptr, '\n')) !is null)
                *ptr = 0;
            hostlen = cast(int)(strlen(ohostname.ptr) + 1);
            for (i = 0; i < hostlen; i++)
                lhostname[i] = cast(char)tolower(cast(ubyte)ohostname[i]);
            hostname = ohostname.ptr;
            if (!strncmp("local:", lhostname.ptr, 6)) {
                family = FamilyLocalHost;
                NewHost(family, "".ptr, 0, FALSE);
                LocalHostRequested = TRUE;      /* Fix for XFree86 bug #156 */
            }
            else if (!strncmp("inet:", lhostname.ptr, 5)) {
                family = FamilyInternet;
                hostname = ohostname.ptr + 5;
            }
static if (IPv6){
            if (!strncmp("inet6:".ptr, lhostname.ptr, 6)) {
                family = FamilyInternet6;
                hostname = ohostname.ptr + 6;
            }
}
            else if (!strncmp("si:".ptr, lhostname.ptr, 3)) {
                family = FamilyServerInterpreted;
                hostname = ohostname.ptr + 3;
                hostlen -= 3;
            }

            if (family == FamilyServerInterpreted) {
                len = siCheckAddr(hostname, hostlen);
                if (len >= 0) {
                    NewHost(family, hostname, len, FALSE);
                }
            }
            else
            {
static if (HAVE_GETADDRINFO) {
    bool ipv6;
    static if(IPv6) {
        ipv6 = true;
    }
                if ((family == FamilyInternet) ||
                    (ipv6 && family == FamilyInternet6) ||
                    (family == FamilyWild)) {
                    addrinfo* addresses = void;
                    addrinfo* a = void;
                    int f = void;

                    if (getaddrinfo(hostname, null, null, &addresses) == 0) {
                        for (a = addresses; a !is null; a = a.ai_next) {
                            len = a.ai_addrlen;
                            f = ConvertAddr(a.ai_addr, &len,
                                            cast(void**) &addr);
                            if (addr && ((family == f) ||
                                         ((family == FamilyWild) && (f != -1)))) {
                                NewHost(f, addr, len, FALSE);
                            }
                        }
                        freeaddrinfo(addresses);
                    }
                }
} else {                           /* HAVE_GETADDRINFO */
                hostent* hp = void;

                /* host name */
                if ((family == FamilyInternet &&
                     ((hp = _XGethostbyname(hostname)) !is null)) ||
                    ((hp = _XGethostbyname(hostname)) !is null)) {
                    sockaddr sa = {
                        sa_family: cast(ushort)hp.h_addrtype
                    };
                    len = sa.sizeof;
                    if ((family =
                         ConvertAddr(&sa, &len, cast(void**) &addr)) != -1) {
version (h_addr) {                   /* new 4.3bsd version of gethostent */
                        char** list = void;

                        /* iterate over the addresses */
                        for (list = hp.h_addr_list; *list; list++)
                            cast(void) NewHost(family, cast(void*) *list, len, FALSE);
} else {
                        cast(void) NewHost(family, cast(void*) hp.h_addr, len,
                                       FALSE);
}
                    }
                }
}                          /* HAVE_GETADDRINFO */
            }
            family = FamilyWild;
        }
        fclose(fd);
    }
}


private Bool xtransLocalClient(ClientPtr client)
{
    int alen = void, family = void, notused = void;
    Xtransaddr* from = null;
    void* addr = void;
    HOST* host = void;
    OsCommPtr oc = cast(OsCommPtr) client.osPrivate;

    if (!oc.trans_conn)
        return FALSE;

    if (!_XSERVTransGetPeerAddr(oc.trans_conn, &notused, &alen, &from)) {
        family = ConvertAddr(cast(sockaddr*) from,
                             &alen, cast(void**) &addr);
        if (family == -1) {
            free(from);
            return FALSE;
        }
        if (family == FamilyLocal) {
            free(from);
            return TRUE;
        }
        for (host = selfhosts; host; host = host.next) {
            if (mixin(addrEqual!(`family`, `addr`, `alen`, `host`))) {
                free(from);
                return TRUE;
            }
        }
        free(from);
    }
    return FALSE;
}

/* Is client on the local host */
Bool ComputeLocalClient(ClientPtr client)
{
    const(char)* cmdname = GetClientCmdName(client);

    if (!xtransLocalClient(client))
        return FALSE;

    /* If the executable name is "ssh", assume that this client connection
     * is forwarded from another host via SSH
     */
    if (cmdname) {
        char* cmd = strdup(cmdname);
        if (!cmd)
            return FALSE;

        Bool ret = void;

        /* Cut off any colon and whatever comes after it, see
         * https://lists.freedesktop.org/archives/xorg-devel/2015-December/048164.html
         */
        char* tok = strtok(cmd, ":");

static if (!HasVersion!"Windows" || HasVersion!"Cygwin") {
        ret = strcmp(basename(tok), "ssh") != 0;
} else {
        ret = strcmp(tok, "ssh") != 0;
}

        free(cmd);

        return ret;
    }

    return TRUE;
}

/*
 * Return the uid and all gids of a connected local client
 * Allocates a LocalClientCredRec - caller must call FreeLocalClientCreds
 *
 * Used by localuser & localgroup ServerInterpreted access control forms below
 * Used by AuthAudit to log who local connections came from
 */
int GetLocalClientCreds(ClientPtr client, LocalClientCredRec** lccp)
{
static if (HasVersion!"HAVE_GETPEEREID" 
        || HasVersion!"HAVE_GETPEERUCRED" 
        || HasVersion!"SO_PEERCRED" 
        || HasVersion!"LOCAL_PEERCRED") {
    int fd = void;
    XtransConnInfo ci = void;
    LocalClientCredRec* lcc = void;

    version (HAVE_GETPEERUCRED) {
        ucred_t* peercred = null;
        const(gid_t)* gids = void;
    } else version (SO_PEERCRED) {
        version (__OpenBSD__) {
            sockpeercred peercred = void;
        } else {
            ucred peercred = void;
        }

        socklen_t so_len = peercred.sizeof;
    } else static if (HasVersion!"LOCAL_PEERCRED" && HasVersion!"HAVE_XUCRED_CR_PID") {
        xucred peercred = void;
        socklen_t so_len = peercred.sizeof;
    } else version (HAVE_GETPEEREID) {
        uid_t uid = void;
        gid_t gid = void;
        version (LOCAL_PEERPID) {
            pid_t pid = void;
            socklen_t so_len = pid.sizeof;
        }
    }

    if (client is null)
        return -1;
    ci = (cast(OsCommPtr) client.osPrivate).trans_conn;
static if (!(HasVersion!"__sun" && HasVersion!"HAVE_GETPEERUCRED")) {
    /* Most implementations can only determine peer credentials for Unix
     * domain sockets - Solaris getpeerucred can work with a bit more, so
     * we just let it tell us if the connection type is supported or not
     */
    if (!_XSERVTransIsLocal(ci)) {
        return -1;
    }
}

    *lccp = cast(LocalClientCredRec*) calloc(1, LocalClientCredRec.sizeof);
    if (*lccp is null)
        return -1;
    lcc = *lccp;

    fd = _XSERVTransGetConnectionNumber(ci);
version (HAVE_GETPEERUCRED) {
    if (getpeerucred(fd, &peercred) < 0) {
        FreeLocalClientCreds(lcc);
        return -1;
    }
    lcc.euid = ucred_geteuid(peercred);
    if (lcc.euid != -1)
        lcc.fieldsSet |= LCC_UID_SET;
    lcc.egid = ucred_getegid(peercred);
    if (lcc.egid != -1)
        lcc.fieldsSet |= LCC_GID_SET;
    lcc.pid = ucred_getpid(peercred);
    if (lcc.pid != -1)
        lcc.fieldsSet |= LCC_PID_SET;
    version (HAVE_GETZONEID) {
        lcc.zoneid = ucred_getzoneid(peercred);
        if (lcc.zoneid != -1)
            lcc.fieldsSet |= LCC_ZID_SET;
    }
    lcc.nSuppGids = ucred_getgroups(peercred, &gids);
    if (lcc.nSuppGids > 0) {
        lcc.pSuppGids = calloc(lcc.nSuppGids, int.sizeof);
        if (lcc.pSuppGids is null) {
            lcc.nSuppGids = 0;
        }
        else {
            int i = void;

            for (i = 0; i < lcc.nSuppGids; i++) {
                (lcc.pSuppGids)[i] = cast(int) gids[i];
            }
        }
    }
    else {
        lcc.nSuppGids = 0;
    }
    ucred_free(peercred);
    return 0;
} else version (SO_PEERCRED) {
    if (getsockopt(fd, SOL_SOCKET, SO_PEERCRED, &peercred, &so_len) == -1) {
        FreeLocalClientCreds(lcc);
        return -1;
    }
    lcc.euid = peercred.uid;
    lcc.egid = peercred.gid;
    lcc.pid = peercred.pid;
    lcc.fieldsSet = LCC_UID_SET | LCC_GID_SET | LCC_PID_SET;
    return 0;
} else static if (HasVersion!"LOCAL_PEERCRED" && HasVersion!"HAVE_XUCRED_CR_PID") {
    if (getsockopt(fd, SOL_LOCAL, LOCAL_PEERCRED, &peercred, &so_len) != 0 ||
        peercred.cr_version != XUCRED_VERSION) {
        FreeLocalClientCreds(lcc);
        return -1;
    }
    lcc.euid = peercred.cr_uid;
    lcc.egid = peercred.cr_gid;
    lcc.pid = peercred.cr_pid;
    lcc.fieldsSet = LCC_UID_SET | LCC_GID_SET | LCC_PID_SET;
    return 0;
} else version (HAVE_GETPEEREID) {
    if (getpeereid(fd, &uid, &gid) == -1) {
        FreeLocalClientCreds(lcc);
        return -1;
    }
    lcc.euid = uid;
    lcc.egid = gid;
    lcc.fieldsSet = LCC_UID_SET | LCC_GID_SET;

    version (LOCAL_PEERPID) {
        if (getsockopt(fd, SOL_LOCAL, LOCAL_PEERPID, &pid, &so_len) != 0) {
            ErrorF("getsockopt failed to determine pid of socket %d: %s\n", fd, strerror(errno));
        } else {
            lcc.pid = pid;
            lcc.fieldsSet |= LCC_PID_SET;
        }
    }

    return 0;
}
} else { //else (HasVersion!"HAVE_GETPEEREID" || HasVersion!"HAVE_GETPEERUCRED" || HasVersion!"SO_PEERCRED" || HasVersion!"LOCAL_PEERCRED") {
    /* No system call available to get the credentials of the peer */
    return -1;
}
}

void FreeLocalClientCreds(LocalClientCredRec* lcc)
{
    if (lcc !is null) {
        if (lcc.nSuppGids > 0) {
            free(lcc.pSuppGids);
        }
        free(lcc);
    }
}

private int AuthorizedClient(ClientPtr client)
{
    int rc = void;

    if (!client || defeatAccessControl)
        return Success;

    /* untrusted clients can't change host access */
    rc = dixCallServerAccessCallback(client, DixManageAccess);
    if (rc != Success)
        return rc;

    return client.local ? Success : BadAccess;
}

/* Add a host to the access control list.  This is the external interface
 * called from the dispatcher */

int AddHost(ClientPtr client, int family, uint length, const(void)* pAddr)
{
    int rc = void, len = void;

    rc = AuthorizedClient(client);
    if (rc != Success)
        return rc;
    switch (family) {
    case FamilyLocalHost:
        len = length;
        LocalHostEnabled = TRUE;
        break;
    case FamilyInternet:
static if (IPv6){
    case FamilyInternet6:
}
    case FamilyDECnet:
    case FamilyChaos:
    case FamilyServerInterpreted:
        if ((len = CheckAddr(family, pAddr, length)) < 0) {
            client.errorValue = cast(uint)length;
            return BadValue;
        }
        break;
    case FamilyLocal:
    default:
        client.errorValue = cast(uint)family;
        return BadValue;
    }
    if (NewHost(family, pAddr, len, FALSE))
        return Success;
    return BadAlloc;
}

Bool ForEachHostInFamily(int family, Bool function(ubyte* addr, short len, void* closure) @nogc nothrow func, void* closure)
{
    HOST* host = void;

    for (host = validhosts; host; host = host.next)
        if (family == host.family && func(host.addr, host.len, closure))
            return TRUE;
    return FALSE;
}

/* Add a host to the access control list. This is the internal interface
 * called when starting or resetting the server */
private Bool NewHost(int family, const(void)* addr, int len, int addingLocalHosts)
{
    HOST* host = void;

    for (host = validhosts; host; host = host.next) {
        if (mixin(addrEqual!(`family`, `addr`, `len`, `host`)))
            return TRUE;
    }
    if (!addingLocalHosts) {    /* Fix for XFree86 bug #156 */
        for (host = selfhosts; host; host = host.next) {
            if (mixin(addrEqual!(`family`, `addr`, `len`, `host`))) {
                host.requested = TRUE;
                break;
            }
        }
    }
    mixin(MakeHost!(`host`, `len`));
        if (!host)
        return FALSE;
    host.family = cast(short)family;
    host.len = cast(short)len;
    memcpy(host.addr, addr, len);
    host.next = validhosts;
    validhosts = host;
    return TRUE;
}

/* Remove a host from the access control list */

int RemoveHost(ClientPtr client, int family, uint length, void* pAddr)
{
    int rc = void, len = void;
    HOST* host = void; HOST** prev = void;

    rc = AuthorizedClient(client);
    if (rc != Success)
        return rc;
    switch (family) {
    case FamilyLocalHost:
        len = length;
        LocalHostEnabled = FALSE;
        break;
    case FamilyInternet:
static if (IPv6){
    case FamilyInternet6:
}
    case FamilyDECnet:
    case FamilyChaos:
    case FamilyServerInterpreted:
        if ((len = CheckAddr(family, pAddr, length)) < 0) {
            if (client)
                client.errorValue = cast(uint)length;
            return BadValue;
        }
        break;
    case FamilyLocal:
    default:
        if (client)
            client.errorValue = cast(uint)family;
        return BadValue;
    }
    for (prev = &validhosts;
         (host = *prev) !is null && (!mixin(addrEqual!(`family`, `pAddr`, `len`, `host`)));
         prev = &host.next){}
    if (host) {
        *prev = host.next;
        mixin(FreeHost!(`host`));
    }
    return Success;
}

/* Get all hosts in the access control list */
int GetHosts(void** data, int* pnHosts, int* pLen, BOOL* pEnabled)
{
    int len = void;
    int n = 0;
    ubyte* ptr = void;
    HOST* host = void;
    int nHosts = 0;

    *pEnabled = AccessEnabled ? EnableAccess : DisableAccess;
    for (host = validhosts; host; host = host.next) {
        nHosts++;
        n += pad_to_int32(host.len) + xHostEntry.sizeof;
        /* Could check for INT_MAX, but in reality having more than 1mb of
           hostnames in the access list is ridiculous */
        if (n >= 1048576)
            break;
    }
    if (n) {
        *data = ptr = cast(ubyte*) calloc(1, n);
        if (!ptr) {
            return BadAlloc;
        }
        for (host = validhosts; host; host = host.next) {
            len = host.len;
            if ((ptr + ((xHostEntry).sizeof + len)) > (cast(ubyte*) *data + n))
                break;
            (cast(xHostEntry*) ptr).family = cast(ubyte)host.family;
            (cast(xHostEntry*) ptr).length = cast(ushort)len;
            ptr += xHostEntry.sizeof;
            memcpy(ptr, host.addr, len);
            ptr += pad_to_int32(len);
        }
    }
    else {
        *data = null;
    }
    *pnHosts = nHosts;
    *pLen = n;
    return Success;
}

/* Check for valid address family and length, and return address length. */

 /*ARGSUSED*/ private int CheckAddr(int family, const(void)* pAddr, uint length)
{
    int len = void;

    switch (family) {
    case FamilyInternet:
        if (length == in_addr.sizeof)
            len = length;
        else
            len = -1;
        break;
static if (IPv6){
    case FamilyInternet6:
        if (length == core.sys.posix.netinet.in_.sockaddr_in6.sizeof)
            len = length;
        else
            len = -1;
        break;
}
    case FamilyServerInterpreted:
        len = siCheckAddr(cast(char*)pAddr, length);
        break;
    default:
        len = -1;
    }
    return len;
}

/* Check if a host is not in the access control list.
 * Returns 1 if host is invalid, 0 if we've found it. */

int InvalidHost(sockaddr* saddr, int len, ClientPtr client)
{
    int family = void;
    void* addr = null;
    HOST* selfhost = void, host = void;

    if (!AccessEnabled)         /* just let them in */
        return 0;
    family = ConvertAddr(saddr, &len, cast(void**) &addr);
    if (family == -1)
        return 1;
    if (family == FamilyLocal) {
        if (!LocalHostEnabled) {
            /*
             * check to see if any local address is enabled.  This
             * implicitly enables local connections.
             */
            for (selfhost = selfhosts; selfhost; selfhost = selfhost.next) {
                for (host = validhosts; host; host = host.next) {
                    if (mixin(addrEqual!(`selfhost.family`, `selfhost.addr`,
                                  `selfhost.len`, `host`)))
                        return 0;
                }
            }
        }
        else
            return 0;
    }
    for (host = validhosts; host; host = host.next) {
        if (host.family == FamilyServerInterpreted) {
            if (siAddrMatch(family, addr, len, host, client)) {
                return 0;
            }
        }
        else {
            if (addr && mixin(addrEqual!(`family`, `addr`, `len`, `host`)))
                return 0;
        }

    }
    return 1;
}

private int ConvertAddr(sockaddr* saddr, int* len, void** addr)
{
    if (*len == 0)
        return FamilyLocal;
    switch (saddr.sa_family) {
    case AF_UNSPEC:
static if(UNIXCONN){
    case AF_UNIX:
}
        return FamilyLocal;
    case AF_INET:
version (Windows) {
        if (16777343 == *cast(c_long*) &(cast(sockaddr_in*) saddr).sin_addr)
            return FamilyLocal;
}
        *len = in_addr.sizeof;
        *addr = cast(void*) &((cast(sockaddr_in*) saddr).sin_addr);
        return FamilyInternet;
static if (IPv6){
    case AF_INET6:
    {
        core.sys.posix.netinet.in_.sockaddr_in6* saddr6 = cast(core.sys.posix.netinet.in_.sockaddr_in6*) saddr;

        if (IN6_IS_ADDR_V4MAPPED!()(&saddr6.sin6_addr)) {
            *len = in_addr.sizeof;
            *addr = cast(void*) &(saddr6.sin6_addr.s6_addr[12]);
            return FamilyInternet;
        }
        else {
            *len = core.sys.posix.netinet.in_.in6_addr.sizeof;
            *addr = cast(void*) &(saddr6.sin6_addr);
            return FamilyInternet6;
        }
    }
}
    default:
        return -1;
    }
}

int ChangeAccessControl(ClientPtr client, int fEnabled)
{
    int rc = AuthorizedClient(client);

    if (rc != Success)
        return rc;
    AccessEnabled = fEnabled;
    return Success;
}

int GetClientFd(ClientPtr client)
{
    return (cast(OsCommPtr) client.osPrivate).fd;
}

Bool ClientIsLocal(ClientPtr client)
{
    XtransConnInfo ci = (cast(OsCommPtr) client.osPrivate).trans_conn;

    return _XSERVTransIsLocal(ci);
}

/*****************************************************************************
 * FamilyServerInterpreted host entry implementation
 *
 * Supports an extensible system of host types which the server can interpret
 * See the IPv6 extensions to the X11 protocol spec for the definition.
 *
 * Currently supported schemes:
 *
 * hostname	- hostname as defined in IETF RFC 2396
 * ipv6		- IPv6 literal address as defined in IETF RFC's 3513 and <TBD>
 *
 * See xc/doc/specs/SIAddresses for formal definitions of each type.
 */

/* These definitions and the siTypeAdd function could be exported in the
 * future to enable loading additional host types, but that was not done for
 * the initial implementation.
 */
alias siAddrMatchFunc = Bool function(int family, void* addr, int len, const(char)* siAddr, int siAddrlen, ClientPtr client, void* siTypePriv);
alias siCheckAddrFunc = int function(const(char)* addrString, int length, void* siTypePriv);

struct siType {
    siType* next;
    const(char)* typeName;
    siAddrMatchFunc addrMatch;
    siCheckAddrFunc checkAddr;
    void* typePriv;             /* Private data for type routines */
};

private siType* siTypeList;

private int siTypeAdd(const(char)* typeName, siAddrMatchFunc addrMatch, siCheckAddrFunc checkAddr, void* typePriv)
{
    siType* s = void, p = void;

    if ((typeName is null) || (addrMatch is null) || (checkAddr is null))
        return BadValue;

    for (s = siTypeList, p = null; s !is null; p = s, s = s.next) {
        if (strcmp(typeName, s.typeName) == 0) {
            s.addrMatch = addrMatch;
            s.checkAddr = checkAddr;
            s.typePriv = typePriv;
            return Success;
        }
    }

    s = cast(siType*) cast(siType*) calloc(1, siType.sizeof);
    if (s is null)
        return BadAlloc;

    if (p is null)
        siTypeList = s;
    else
        p.next = s;

    s.next = null;
    s.typeName = typeName;
    s.addrMatch = addrMatch;
    s.checkAddr = checkAddr;
    s.typePriv = typePriv;
    return Success;
}

/* Checks to see if a host matches a server-interpreted host entry */
private Bool siAddrMatch(int family, void* addr, int len, HOST* host, ClientPtr client)
{
    Bool matches = FALSE;
    siType* s = void;
    const(char)* valueString = void;
    int addrlen = void;

    valueString = cast(const(char)*) memchr(host.addr, '\0', host.len);
    if (valueString !is null) {
        for (s = siTypeList; s !is null; s = s.next) {
            if (strcmp(cast(char*) host.addr, s.typeName) == 0) {
                addrlen = cast(int)(host.len - (strlen(cast(char*) host.addr) + 1));
                matches = s.addrMatch(family, addr, len,
                                       valueString + 1, addrlen, client,
                                       s.typePriv);
                break;
            }
        }
version (FAMILY_SI_DEBUG) {
        ErrorF("Xserver: siAddrMatch(): type = %s, value = %*.*s -- %s\n",
               host.addr, addrlen, addrlen, valueString + 1,
               (matches) ? "accepted" : "rejected");
}
    }
    return matches;
}

private int siCheckAddr(const(char)* addrString, int length)
{
    const(char)* valueString = void;
    int addrlen = void, typelen = void;
    int len = -1;
    siType* s = void;

    /* Make sure there is a \0 byte inside the specified length
       to separate the address type from the address value. */
    valueString = cast(const(char)*) memchr(addrString, '\0', length);
    if (valueString !is null) {
        /* Make sure the first string is a recognized address type,
         * and the second string is a valid address of that type.
         */
        typelen = cast(int)(strlen(addrString) + 1);
        addrlen = length - typelen;

        for (s = siTypeList; s !is null; s = s.next) {
            if (strcmp(addrString, s.typeName) == 0) {
                len = s.checkAddr(valueString + 1, addrlen, s.typePriv);
                if (len >= 0) {
                    len += typelen;
                }
                break;
            }
        }
version (FAMILY_SI_DEBUG) {
        {
            const(char)* resultMsg = void;

            if (s is null) {
                resultMsg = "type not registered";
            }
            else {
                if (len == -1)
                    resultMsg = "rejected";
                else
                    resultMsg = "accepted";
            }

            ErrorF
                ("Xserver: siCheckAddr(): type = %s, value = %*.*s, len = %d -- %s\n",
                 addrString, addrlen, addrlen, valueString + 1, len, resultMsg);
        }
}
    }
    return len;
}

/***
 * Hostname server-interpreted host type
 *
 * Stored as hostname string, explicitly defined to be resolved ONLY
 * at access check time, to allow for hosts with dynamic addresses
 * but static hostnames, such as found in some DHCP & mobile setups.
 *
 * Hostname must conform to IETF RFC 2396 sec. 3.2.2, which defines it as:
 * 	hostname     = *( domainlabel "." ) toplabel [ "." ]
 *	domainlabel  = alphanum | alphanum *( alphanum | "-" ) alphanum
 *	toplabel     = alpha | alpha *( alphanum | "-" ) alphanum
 */

version (NI_MAXHOST) {
    enum SI_HOSTNAME_MAXLEN = NI_MAXHOST;
} else {
    version (MAXHOSTNAMELEN) {
        enum SI_HOSTNAME_MAXLEN = MAXHOSTNAMELEN;
    } else {
        enum SI_HOSTNAME_MAXLEN = 256;
    }
}

private Bool siHostnameAddrMatch(int family, void* addr, int len, const(char)* siAddr, int siAddrLen, ClientPtr client, void* typePriv)
{
    Bool res = FALSE;

/* Currently only supports checking against IPv4 & IPv6 connections, but
 * support for other address families, such as DECnet, could be added if
 * desired.
 */
version (HAVE_GETADDRINFO) {
    bool ipv6   = false;
static if (HasVersion!"IPv6") {
    ipv6 = true;
}
    if ((family == FamilyInternet)
        || (ipv6 && family == FamilyInternet6)) 
         {
        char[SI_HOSTNAME_MAXLEN] hostname = void;
        addrinfo* addresses = void;
        addrinfo* a = void;
        int f = void, hostaddrlen = void;
        void* hostaddr = null;

        if (siAddrLen >= hostname.sizeof)
            return FALSE;

        strlcpy(hostname.ptr, siAddr, siAddrLen + 1);

        if (getaddrinfo(hostname.ptr, null, null, &addresses) == 0) {
            for (a = addresses; a !is null; a = a.ai_next) {
                hostaddrlen = a.ai_addrlen;
                f = ConvertAddr(a.ai_addr, &hostaddrlen, &hostaddr);
                if ((f == family) && (len == hostaddrlen) && hostaddr &&
                    (memcmp(addr, hostaddr, len) == 0)) {
                    res = TRUE;
                    break;
                }
            }
            freeaddrinfo(addresses);
        }
    }
} else { /* getaddrinfo not supported, use gethostbyname instead for IPv4 */
    if (family == FamilyInternet) {
        hostent* hp = void;

        char[SI_HOSTNAME_MAXLEN] hostname = void;
        int f = void, hostaddrlen = void;
        void* hostaddr = void;
        char** addrlist = void;

        if (siAddrLen >= hostname.sizeof)
            return FALSE;

        strlcpy(hostname.ptr, siAddr, siAddrLen + 1);

        if ((hp = _XGethostbyname(hostname.ptr)) !is null) {
// version (h_addr) {                   /* new 4.3bsd version of gethostent */
            /* iterate over the addresses */
            for (addrlist = hp.h_addr_list; *addrlist; addrlist++)
// }// #else h_addr
//             addrlist = &hp.h_addr;
// // }
            {
                sockaddr_in sin = void;

                sin.sin_family = cast(ushort)hp.h_addrtype;
                memcpy(&(sin.sin_addr), *addrlist, hp.h_length);
                hostaddrlen = sin.sizeof;
                f = ConvertAddr(cast(sockaddr*) &sin,
                                &hostaddrlen, &hostaddr);
                if ((f == family) && (len == hostaddrlen) &&
                    (memcmp(addr, hostaddr, len) == 0)) {
                    res = TRUE;
version (h_addr) {
                    break;
}
                }
            }
        }
    }
}//endif HAVE_GETADDRINFO
    return res;
}

private int siHostnameCheckAddr(const(char)* valueString, int length, void* typePriv)
{
    /* Check conformance of hostname to RFC 2396 sec. 3.2.2 definition.
     * We do not use ctype functions here to avoid locale-specific
     * character sets.  Hostnames must be pure ASCII.
     */
    int len = length;
    int i = void;
    Bool dotAllowed = FALSE;
    Bool dashAllowed = FALSE;

    if ((length <= 0) || (length >= SI_HOSTNAME_MAXLEN)) {
        len = -1;
    }
    else {
        for (i = 0; i < length; i++) {
            char c = valueString[i];

            if (c == 0x2E) {    /* '.' */
                if (dotAllowed == FALSE) {
                    len = -1;
                    break;
                }
                else {
                    dotAllowed = FALSE;
                    dashAllowed = FALSE;
                }
            }
            else if (c == 0x2D) {       /* '-' */
                if (dashAllowed == FALSE) {
                    len = -1;
                    break;
                }
                else {
                    dotAllowed = FALSE;
                }
            }
            else if (((c >= 0x30) && (c <= 0x3A)) /* 0-9 */ ||
                     ((c >= 0x61) && (c <= 0x7A)) /* a-z */ ||
                     ((c >= 0x41) && (c <= 0x5A)) /* A-Z */ ) {
                dotAllowed = TRUE;
                dashAllowed = TRUE;
            }
            else {              /* Invalid character */
                len = -1;
                break;
            }
        }
    }
    return len;
}

static if (IPv6){
/***
 * "ipv6" server interpreted type
 *
 * Currently supports only IPv6 literal address as specified in IETF RFC 3513
 *
 * Once draft-ietf-ipv6-scoping-arch-00.txt becomes an RFC, support will be
 * added for the scoped address format it specifies.
 */

/* Maximum length of an IPv6 address string - increase when adding support
 * for scoped address qualifiers.  Includes room for trailing NUL byte.
 */
enum SI_IPv6_MAXLEN = core.sys.posix.arpa.inet.INET6_ADDRSTRLEN;

private Bool siIPv6AddrMatch(int family, void* addr, int len, const(char)* siAddr, int siAddrlen, ClientPtr client, void* typePriv)
{
    core.sys.posix.netinet.in_.in6_addr addr6 = void;
    char[SI_IPv6_MAXLEN] addrbuf = void;

    if ((family != FamilyInternet6) || (len != addr6.sizeof))
        return FALSE;

    memcpy(addrbuf.ptr, siAddr, siAddrlen);
    addrbuf[siAddrlen] = '\0';

    if (core.sys.posix.arpa.inet.inet_pton(AF_INET6, addrbuf.ptr, &addr6) != 1) {
        perror("inet_pton");
        return FALSE;
    }

    if (memcmp(addr, &addr6, len) == 0) {
        return TRUE;
    }
    else {
        return FALSE;
    }
}

private int siIPv6CheckAddr(const(char)* addrString, int length, void* typePriv)
{
    int len = void;

    /* Minimum length is 3 (smallest legal address is "::1") */
    if (length < 3) {
        /* Address is too short! */
        len = -1;
    }
    else if (length >= SI_IPv6_MAXLEN) {
        /* Address is too long! */
        len = -1;
    }
    else {
        /* Assume inet_pton is sufficient validation */
        core.sys.posix.netinet.in_.in6_addr addr6 = void;
        char[SI_IPv6_MAXLEN] addrbuf = void;

        memcpy(addrbuf.ptr, addrString, length);
        addrbuf[length] = '\0';

        if (core.sys.posix.arpa.inet.inet_pton(AF_INET6, addrbuf.ptr, &addr6) != 1) {
            perror("inet_pton");
            len = -1;
        }
        else {
            len = length;
        }
    }
    return len;
}
}                          /* IPv6 */

static if (!HasVersion!"NO_LOCAL_CLIENT_CRED") {
/***
 * "localuser" & "localgroup" server interpreted types
 *
 * Allows local connections from a given local user or group
 */

import core.sys.posix.pwd;
import core.sys.posix.grp;

enum LOCAL_USER = 1;
enum LOCAL_GROUP = 2;

struct _SiLocalCredPrivRec {
    int credType;
}alias siLocalCredPrivRec = _SiLocalCredPrivRec;
alias siLocalCredPrivPtr = siLocalCredPrivRec*;

private siLocalCredPrivRec siLocalUserPriv = { LOCAL_USER };
private siLocalCredPrivRec siLocalGroupPriv = { LOCAL_GROUP };

private Bool siLocalCredGetId(const(char)* addr, int len, siLocalCredPrivPtr lcPriv, int* id)
{
    Bool parsedOK = FALSE;
    char* addrbuf = cast(char*) calloc(1, len + 1);

    if (addrbuf is null) {
        return FALSE;
    }

    memcpy(addrbuf, addr, len);
    addrbuf[len] = '\0';

    if (addr[0] == '#') {       /* numeric id */
        char* cp = void;

        errno = 0;
        *id = cast(int)strtol(addrbuf + 1, &cp, 0);
        if ((errno == 0) && (cp != (addrbuf + 1))) {
            parsedOK = TRUE;
        }
    }
    else {                      /* non-numeric name */
        if (lcPriv.credType == LOCAL_USER) {
            passwd* pw = getpwnam(addrbuf);

            if (pw !is null) {
                *id = cast(int) pw.pw_uid;
                parsedOK = TRUE;
            }
        }
        else {                  /* group */
            group* gr = getgrnam(addrbuf);

            if (gr !is null) {
                *id = cast(int) gr.gr_gid;
                parsedOK = TRUE;
            }
        }
    }

    free(addrbuf);
    return parsedOK;
}

private Bool siLocalCredAddrMatch(int family, void* addr, int len, const(char)* siAddr, int siAddrlen, ClientPtr client, void* typePriv)
{
    int siAddrId = void;
    LocalClientCredRec* lcc = void;
    siLocalCredPrivPtr lcPriv = cast(siLocalCredPrivPtr) typePriv;

    if (GetLocalClientCreds(client, &lcc) == -1) {
        return FALSE;
    }

version (HAVE_GETZONEID) {           /* Ensure process is in the same zone */
    if ((lcc.fieldsSet & LCC_ZID_SET) && (lcc.zoneid != getzoneid())) {
        FreeLocalClientCreds(lcc);
        return FALSE;
    }
}

    if (siLocalCredGetId(siAddr, siAddrlen, lcPriv, &siAddrId) == FALSE) {
        FreeLocalClientCreds(lcc);
        return FALSE;
    }

    if (lcPriv.credType == LOCAL_USER) {
        if ((lcc.fieldsSet & LCC_UID_SET) && (lcc.euid == siAddrId)) {
            FreeLocalClientCreds(lcc);
            return TRUE;
        }
    }
    else {
        if ((lcc.fieldsSet & LCC_GID_SET) && (lcc.egid == siAddrId)) {
            FreeLocalClientCreds(lcc);
            return TRUE;
        }
        if (lcc.pSuppGids !is null) {
            int i = void;

            for (i = 0; i < lcc.nSuppGids; i++) {
                if (lcc.pSuppGids[i] == siAddrId) {
                    FreeLocalClientCreds(lcc);
                    return TRUE;
                }
            }
        }
    }
    FreeLocalClientCreds(lcc);
    return FALSE;
}

private int siLocalCredCheckAddr(const(char)* addrString, int length, void* typePriv)
{
    int len = length;
    int id = void;

    if (siLocalCredGetId(addrString, length,
                         cast(siLocalCredPrivPtr) typePriv, &id) == FALSE) {
        len = -1;
    }
    return len;
}
}

void siTypesInitialize()
{
    siTypeAdd("hostname", &siHostnameAddrMatch, &siHostnameCheckAddr, null);
static if (IPv6){
    siTypeAdd("ipv6", &siIPv6AddrMatch, &siIPv6CheckAddr, null);
}
static if (!HasVersion!"NO_LOCAL_CLIENT_CRED") {
    siTypeAdd("localuser", &siLocalCredAddrMatch, &siLocalCredCheckAddr,
              &siLocalUserPriv);
    siTypeAdd("localgroup", &siLocalCredAddrMatch, &siLocalCredCheckAddr,
              &siLocalGroupPriv);
}
}