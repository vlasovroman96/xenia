module hw.xfree86.os_support.xf86_OSlib;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/*
 * Copyright 1990, 1991 by Thomas Roell, Dinkelscherben, Germany
 * Copyright 1992 by David Dawes <dawes@XFree86.org>
 * Copyright 1992 by Jim Tsillas <jtsilla@damon.ccs.northeastern.edu>
 * Copyright 1992 by Rich Murphey <Rich@Rice.edu>
 * Copyright 1992 by Robert Baron <Robert.Baron@ernst.mach.cs.cmu.edu>
 * Copyright 1992 by Orest Zborowski <obz@eskimo.com>
 * Copyright 1993 by Vrije Universiteit, The Netherlands
 * Copyright 1993 by David Wexelblat <dwex@XFree86.org>
 * Copyright 1994, 1996 by Holger Veit <Holger.Veit@gmd.de>
 * Copyright 1997 by Takis Psarogiannakopoulos <takis@dpmms.cam.ac.uk>
 * Copyright 1994-2003 by The XFree86 Project, Inc
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the names of the above listed copyright holders
 * not be used in advertising or publicity pertaining to distribution of
 * the software without specific, written prior permission.  The above listed
 * copyright holders make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *
 * THE ABOVE LISTED COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD
 * TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS, IN NO EVENT SHALL THE ABOVE LISTED COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY
 * DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER
 * IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */

/*
 * The ARM32 code here carries the following copyright:
 *
 * Copyright 1997
 * Digital Equipment Corporation. All rights reserved.
 * This software is furnished under license and may be used and copied only in
 * accordance with the following terms and conditions.  Subject to these
 * conditions, you may download, copy, install, use, modify and distribute
 * this software in source and/or binary form. No title or ownership is
 * transferred hereby.
 *
 * 1) Any source code used, modified or distributed must reproduce and retain
 *    this copyright notice and list of conditions as they appear in the
 *    source file.
 *
 * 2) No right is granted to use any trade name, trademark, or logo of Digital
 *    Equipment Corporation. Neither the "Digital Equipment Corporation"
 *    name nor any trademark or logo of Digital Equipment Corporation may be
 *    used to endorse or promote products derived from this software without
 *    the prior written permission of Digital Equipment Corporation.
 *
 * 3) This software is provided "AS-IS" and any express or implied warranties,
 *    including but not limited to, any implied warranties of merchantability,
 *    fitness for a particular purpose, or non-infringement are disclaimed.
 *    In no event shall DIGITAL be liable for any damages whatsoever, and in
 *    particular, DIGITAL shall not be liable for special, indirect,
 *    consequential, or incidental damages or damages for lost profits, loss
 *    of revenue or loss of use, whether such damages arise in contract,
 *    negligence, tort, under statute, in equity, at law or otherwise, even
 *    if advised of the possibility of such damage.
 *
 */

/*
 * This is private, and should not be included by any drivers.  Drivers
 * may include xf86_OSproc.h to get prototypes for public interfaces.
 */

 
// //public import x11.Xos;
// //public import x11.Xfuncproto;
import x11.Xosdefs;

public import core.stdc.stdio;
public import core.stdc.ctype;
public import core.stdc.stddef;

/**************************************************************************/
/* Solaris or illumos-based system                                        */
/**************************************************************************/
static if (HasVersion!"__SVR4" && HasVersion!"__sun") {
public import core.sys.posix.sys.ioctl;
public import core.stdc.signal;
public import termio;
public import core.sys.posix.sys.types;

public import core.stdc.errno;

// version (HAVE_SYS_VT_H) {
// version = HAS_USL_VTS;
// }
// version (HAS_USL_VTS) {
public import sys.kd;
public import sys.vt;
// }

version = CLEARDTR_SUPPORT;

}                          /* SVR4 && __sun */

/**************************************************************************/
/* Linux or Glibc-based system                                            */
/**************************************************************************/
static if (HasVersion!"linux" || HasVersion!"__GLIBC__" || HasVersion!"Cygwin") {
public import core.sys.posix.sys.ioctl;
public import core.stdc.signal;
public import core.stdc.stdlib;
public import core.sys.posix.sys.types;
public import core.stdc.assert_;

public import core.sys.posix.termios;
version (__sparc__) {
public import sys.param;
}

public import core.stdc.errno;

// version (linux) {
// version = HAS_USL_VTS;
public import externs.linux.kd;
public import externs.linux.vt;
enum LDGMAP = GIO_SCRNMAP;
enum LDSMAP = PIO_SCRNMAP;
enum LDNMAP = LDSMAP;
version = CLEARDTR_SUPPORT;
// }

}                          /* __linux__ || __GLIBC__ */

/**************************************************************************/
/* System is BSD-like                                                     */
/**************************************************************************/

static if (CSRG_BASED) {
public import core.sys.posix.sys.ioctl;
public import core.stdc.signal;

public import core.sys.posix.termios;
enum termio = termios;

public import core.stdc.errno;

public import core.sys.posix.sys.types;

}                          /* CSRG_BASED */

/**************************************************************************/
/* Kernel of *BSD                                                         */
/**************************************************************************/
static if (HasVersion!"__FreeBSD__" || HasVersion!"__FreeBSD_kernel__" || 
 HasVersion!"__NetBSD__" || HasVersion!"__OpenBSD__" || HasVersion!"__DragonFly__") {

public import sys.param;
static if (HasVersion!"__FreeBSD_version" && !HasVersion!"__FreeBSD_kernel_version") {
enum __FreeBSD_kernel_version = __FreeBSD_version;
}

version (SYSCONS_SUPPORT) {
version = COMPAT_SYSCONS;
static if (HasVersion!"__FreeBSD__" || HasVersion!"__FreeBSD_kernel__" || HasVersion!"__DragonFly__") {
static if (HasVersion!"__DragonFly__"  || (__FreeBSD_kernel_version >= 410000)) {
public import sys.consio;
public import sys.kbio;
} else {
public import machine.console;
}                          /* FreeBSD 4.1 RELEASE or lator */
} else {
public import sys.console;
}
}                          /* SYSCONS_SUPPORT */
static if (HasVersion!"PCVT_SUPPORT" && !HasVersion!"__NetBSD__" && !HasVersion!"__OpenBSD__") {
static if (!HasVersion!"SYSCONS_SUPPORT") {
      /* no syscons, so include pcvt specific header file */
static if (HasVersion!"__FreeBSD__" || HasVersion!"__FreeBSD_kernel__") {
public import machine.pcvt_ioctl;
} else {
public import sys.pcvt_ioctl;
}                          /* __FreeBSD_kernel__ */
} else {                           /* pcvt and syscons: hard-code the ID magic */
enum VGAPCVTID = _IOWR('V',113, pcvtid);
struct pcvtid {
    char[16] name = 0;
    int rmajor, rminor;
};
}                          /* PCVT_SUPPORT && SYSCONS_SUPPORT */
}                          /* PCVT_SUPPORT */
version (WSCONS_SUPPORT) {
public import dev.wscons.wsconsio;
public import dev.wscons.wsdisplay_usl_io;
}                          /* WSCONS_SUPPORT */
static if (HasVersion!"__FreeBSD__" || HasVersion!"__FreeBSD_kernel__" || HasVersion!"__DragonFly__") {
public import sys.mouse;
}
    /* Include these definitions in case ioctl_pc.h didn't get included */
enum CONSOLE_X_BELL = "";
// _IOW('t',123,int[2]);


version = CLEARDTR_SUPPORT;

}                          /* __FreeBSD__ || __NetBSD__ || __OpenBSD__ || __DragonFly__ */

/**************************************************************************/
/* IRIX                                                                   */
/**************************************************************************/

/**************************************************************************/
/* Generic                                                                */
/**************************************************************************/

/* For PATH_MAX */
public import common.misc;

/*
 * Hack originally for ISC 2.2 POSIX headers, but may apply elsewhere,
 * and it's safe, so just do it.
 */
static if (!HasVersion!"O_NDELAY" && HasVersion!"O_NONBLOCK") {
enum O_NDELAY = O_NONBLOCK;
}                          /* !O_NDELAY && O_NONBLOCK */

static if (!HasVersion!"MAXHOSTNAMELEN") {
enum MAXHOSTNAMELEN = 32;
}                          /* !MAXHOSTNAMELEN */

public import core.stdc.limits;

enum MAP_FAILED = cast(void *)-1;


enum string SYSCALL(string call) = `
    while ((` ~ call ~ `) == -1 && errno == EINTR) {}
`;
public import hw.xfree86.os_support.xf86_OSproc;;

                          /* _XF86_OSLIB_H */
