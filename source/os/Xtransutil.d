module os.Xtransutil;
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
 * NCRS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN
 * NO EVENT SHALL NCR BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

/*
 * These are some utility functions created for convenience or to provide
 * an interface that is similar to an existing interface. These are built
 * only using the Transport Independent API, and have no knowledge of
 * the internal implementation.
 */

version (XTHREADS) {
//import externs.X11.Xthreads;
}
version (Windows) {
//import externs.X11.Xlibint;
//import externs.X11.Xwinsock;
}
import std.conv;
import build.xlibre_server;
import os.Xtrans;

import os.xhostname;

static if (HasVersion!"IPv6" && !HasVersion!"AF_INET6") {
static assert(0, "Cannot build IPv6 support without AF_INET6");
}
import os.Xtransint;
import sock = core.sys.posix.sys.socket;
import os.Xtransint;
import core.sys.posix.unistd;
import core.stdc.stdlib;
import core.stdc.stdio;
import core.stdc.string;

// import core.sys.posix.sys.
// alias rindex = strrchr;
import core.sys.posix.netdb;
import os.ossock;

// alias sock = 
alias sockaddr_in = core.sys.posix.netinet.in_.sockaddr_in;
alias _XGetservbyname = getservbyname;
alias _XGethostbyaddr =	gethostbyaddr;
alias _XGethostbyname = gethostbyname;
// alias _XGetservbyname = getservbyname;
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

/* Temporary workaround for consumers whose configure scripts were
   generated with pre-1.6 versions of xtrans.m4 */
static if (HasVersion!"IPv6" && !HasVersion!"HAVE_INET_NTOP") {
version = HAVE_INET_NTOP;
}
public import x11.X;
/*
 * These values come from X.h and Xauth.h, and MUST match them. Some
 * of these values are also defined by the ChangeHost protocol message.
 */

// enum FamilyInternet =		0	/* IPv4 */;
// enum FamilyDECnet =		1;
// enum FamilyChaos =		2;
// enum FamilyInternet6 =		6;
// enum FamilyAmoeba =		33;
enum FamilyLocalHost =		252;
// enum FamilyKrb5Principal =	253;
// enum FamilyNetname =		254;
enum FamilyLocal =		256;
enum FamilyWild =		65535;

/*
 * _XSERVTransConvertAddress converts a sockaddr based address to an
 * X authorization based address. Some of this is defined as part of
 * the ChangeHost protocol. The rest is just done in a consistent manner.
 */

int _XSERVTransConvertAddress(int* familyp, int* addrlenp, Xtransaddr** addrp)
{
    prmsg(2,"ConvertAddress(%d,%d,%p)\n",*familyp,*addrlenp,cast(void*)*addrp);

    switch( *familyp )
    {
    case AF_INET:
    {
	/*
	 * Check for the BSD hack localhost address 127.0.0.1.
	 * In this case, we are really FamilyLocal.
	 */

	sockaddr_in saddr = void;
	int len = typeof(saddr.sin_addr.s_addr).sizeof;
	char* cp = cast(char*) &saddr.sin_addr.s_addr;

	memcpy (&saddr, *addrp, sockaddr_in.sizeof);

	if ((len == 4) && (cp[0] == 127) && (cp[1] == 0) &&
	    (cp[2] == 0) && (cp[3] == 1))
	{
	    *familyp=FamilyLocal;
	}
	else
	{
	    *familyp=FamilyInternet;
	    *addrlenp=len;
	    memcpy(*addrp,&saddr.sin_addr,len);
	}
	break;
    }

static if (IPv6){
    case AF_INET6:
    {
	core.sys.posix.netinet.in_.sockaddr_in6 saddr6 = void;

	memcpy (&saddr6, *addrp, core.sys.posix.netinet.in_.sockaddr_in6.sizeof);

	if (IN6_IS_ADDR_LOOPBACK!()(&saddr6.sin6_addr))
	{
	    *familyp=FamilyLocal;
	}
	else if (IN6_IS_ADDR_V4MAPPED!()(&saddr6.sin6_addr)) {
	    char* cp = cast(char*) &saddr6.sin6_addr.s6_addr[12];

	    if ((cp[0] == 127) && (cp[1] == 0) &&
	      (cp[2] == 0) && (cp[3] == 1))
	    {
		*familyp=FamilyLocal;
	    }
	    else
	    {
		*familyp=FamilyInternet;
		*addrlenp = core.sys.posix.arpa.inet.in_addr.sizeof;
		memcpy(*addrp,cp,*addrlenp);
	    }
	}
	else
	{
	    *familyp=FamilyInternet6;
	    *addrlenp=typeof(saddr6.sin6_addr).sizeof;
	    memcpy(*addrp,&saddr6.sin6_addr,typeof(saddr6.sin6_addr).sizeof);
	}
	break;
    }
} /* IPv6 */


static if(UNIXCONN){
    case AF_UNIX:
    {
	*familyp=FamilyLocal;
	break;
    }
} /* defined(UNIXCONN) */


    default:
	prmsg(1,"ConvertAddress: Unknown family type %d\n",
	      *familyp);
	return -1;
    }


    if (*familyp == FamilyLocal)
    {
	/*
	 * In the case of a local connection, we need to get the
	 * host name for authentication.
	 */

        xhostname hn = void;
        f_xhostname(&hn);
        int len = cast(int)strlen(hn.name.ptr);

	if (len > 0) {
	    if (*addrp && *addrlenp < (len + 1))
	    {
		free (*addrp);
		*addrp = null;
	    }
	    if (!*addrp)
		*addrp = cast(Xtransaddr*)malloc (len + 1);
	    if (*addrp) {
		strcpy (cast(char*) *addrp, hn.name.ptr);
		*addrlenp = len;
	    } else {
		*addrlenp = 0;
	    }
	}
	else
	{
	    if (*addrp)
		free (*addrp);
	    *addrp = null;
	    *addrlenp = 0;
	}
    }

    return 0;
}

import core.sys.posix.sys.types;
import core.sys.posix.sys.stat;
import core.stdc.errno;

static if (!HasVersion!"S_IFLNK" && !HasVersion!"S_ISLNK") {
enum string lstat(string a,string b) = `stat(` ~ a ~ `,` ~ b ~ `)`;
}

enum FAIL_IF_NOMODE =  1;
enum FAIL_IF_NOT_ROOT = 2;
enum WARN_NO_ACCESS = 4;

/*
 * We make the assumption that when the 'sticky' (t) bit is requested
 * it's not save if the directory has non-root ownership or the sticky
 * bit cannot be set and fail.
 */
static if (!HasVersion!"S_IFLNK" && !HasVersion!"S_ISLNK") {
    alias lstat_ = stat;
} else {
    alias lstat_ = core.sys.posix.sys.stat.lstat;
}

int trans_mkdir(const(char)* path, int mode)
{
    stat_t buf = void;

    if (lstat_(path, &buf) != 0)
    {
        if (errno != ENOENT)
        {
            prmsg(1,
                "mkdir: ERROR: (l)stat failed for %s (%d)\n",
                path, errno);
            return -1;
        }

        /* Dir doesn't exist. Try to create it */

        static if (!HasVersion!"Windows" &&
                   !HasVersion!"Cygwin")
        {
            /*
             * 'sticky' bit requested: assume application makes
             * certain security implications. If effective user ID
             * is != 0: fail.
             */
            if (geteuid() != 0)
            {
                if (mode & octal!"01000")
                {
                    prmsg(1,
                        "mkdir: ERROR: euid != 0,"
                        ~ "directory %s will not be created.\n",
                        path);
                }
                else
                {
                    prmsg(1,
                        "mkdir: Cannot create %s with root ownership\n",
                        path);
                }
            }
        }

        version (Windows)
        {
            if (mkdir(path) != 0)
            {
                prmsg(1,
                    "mkdir: ERROR: Cannot create %s\n",
                    path);
                return -1;
            }
        }
        else
        {
            if (mkdir(path, mode) != 0)
            {
                prmsg(1,
                    "mkdir: ERROR: Cannot create %s\n",
                    path);
                return -1;
            }

            if (chmod(path, mode) != 0)
            {
                prmsg(1,
                    "mkdir: ERROR: Mode of %s should be set to %04o\n",
                    path, mode);
            }
        }

        return 0;
    }

    if (!S_ISDIR(buf.st_mode))
        return -1;

    int updateOwner = 0;
    int updateMode = 0;
    int updatedOwner = 0;
    int updatedMode = 0;
    int status = 0;

    /* Check if the directory's ownership is OK. */
    if (buf.st_uid != 0)
        updateOwner = 1;

    /*
     * Check if the directory's mode is OK. An exact match isn't
     * required, just a mode that isn't more permissive than the
     * one requested.
     */
    if ((~mode) & octal!"0077" & buf.st_mode)
        updateMode = 1;

    /*
     * If the directory is not writable not everybody may
     * be able to create sockets. Therefore warn if mode
     * cannot be fixed.
     */
    if ((~buf.st_mode) & octal!"0022" & mode)
    {
        updateMode = 1;
        status |= WARN_NO_ACCESS;
    }

    /*
     * If 'sticky' bit is requested fail if owner isn't root
     * as we assume the caller makes certain security implications.
     */
    if (mode & octal!"01000")
    {
        status |= FAIL_IF_NOT_ROOT;

        if (!(buf.st_mode & octal!"01000"))
        {
            status |= FAIL_IF_NOMODE;
            updateMode = 1;
        }
    }

    static if (HasVersion!"HAS_FCHOWN")
    {
        if (updateMode || updateOwner)
        {
            int fd = -1;
            stat_t fbuf = void;

            if ((fd = open(path, O_RDONLY)) != -1)
            {
                if (fstat(fd, &fbuf) == -1)
                {
                    prmsg(1,
                        "mkdir: ERROR: fstat failed for %s (%d)\n",
                        path, errno);
                    close(fd);
                    return -1;
                }

                /*
                 * Verify that we've opened the same directory as
                 * was checked above.
                 */
                if (!S_ISDIR(fbuf.st_mode) ||
                    buf.st_dev != fbuf.st_dev ||
                    buf.st_ino != fbuf.st_ino)
                {
                    prmsg(1,
                        "mkdir: ERROR: inode for %s changed\n",
                        path);
                    close(fd);
                    return -1;
                }

                if (updateOwner && fchown(fd, 0, 0) == 0)
                    updatedOwner = 1;

                if (updateMode && fchmod(fd, mode) == 0)
                    updatedMode = 1;

                close(fd);
            }
        }
    }

    if (updateOwner && !updatedOwner)
    {
        static if (!HasVersion!"__APPLE_CC__" &&
                   !HasVersion!"Cygwin")
        {
            prmsg(1,
                "mkdir: Owner of %s should be set to root\n",
                path);
        }
    }

    if (updateMode && !updatedMode)
    {
        prmsg(1,
            "mkdir: Mode of %s should be set to %04o\n",
            path, mode);

        if (status & WARN_NO_ACCESS)
            prmsg(1,
                "mkdir: this may cause subsequent errors\n");
    }

    return 0;
}