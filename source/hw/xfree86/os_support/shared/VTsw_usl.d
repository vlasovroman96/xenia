module VTsw_usl;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 1993 by David Wexelblat <dwex@XFree86.org>
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of David Wexelblat not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  David Wexelblat makes no representations
 * about the suitability of this software for any purpose.  It is provided
 * "as is" without express or implied warranty.
 *
 * DAVID WEXELBLAT DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL DAVID WEXELBLAT BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *
 */
import build.xorg_config;
import build.dix_config;

//import x11.X;

import os.osdep;

import include.xf86;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;

import seatd_libseat;

import xf86Events;
import xf86Globals;
// import externs.sys.sysmacros;;
// import os.utils;
import xf86Option;
// import config.libhal;
import include.misc;
import externs.libdbus;
import core.sys.posix.sys.select;
import include.xf86Xinput;
import config.hotplug_priv;


import os.log_priv;

import include.dix;
import include.os;

// import config.dbus_core;
import externs.attrs;
import os.log;
import config.libhal;
import os.connection;
import include.xf86;
import xf86Xinput;
import xf86Init;
import xf86platformBus_priv;
import lnx_init;
import os.utils;
alias FALSE = include.misc.FALSE;

alias TRUE = include.misc.TRUE;
import lnx_init;
// import 
/*
 * Handle the VT-switching interface for OSs that use USL-style ioctl()s
 * (this used to include the sysv, sco, and linux subdirs, but only linux
 *  remains now).
 */

/*
 * This function is the signal handler for the VT-switching signal.  It
 * is only referenced inside the OS-support layer.
 */
void xf86VTRequest(int sig)
{
    OsSignal(sig, cast(void function(int)) &xf86VTRequest);
    xf86Info.vtRequestsPending = TRUE;
    return;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTSwitchPending()
{
    return xf86Info.vtRequestsPending ? TRUE : FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTSwitchAway()
{
    xf86Info.vtRequestsPending = FALSE;
    if (seatd_libseat_controls_session())
        return TRUE;
    if (ioctl(xf86Info.consoleFd, VT_RELDISP, 1) < 0)
        return FALSE;
    else
        return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTSwitchTo()
{
    xf86Info.vtRequestsPending = FALSE;
    if (seatd_libseat_controls_session())
        return TRUE;
    if (ioctl(xf86Info.consoleFd, VT_RELDISP, VT_ACKACQ) < 0)
        return FALSE;
    else
        return TRUE;
}

Bool xf86VTActivate(int vtno)
{
static if (VT_ACTIVATE) {
    if (ioctl(xf86Info.consoleFd, VT_ACTIVATE, vtno) < 0) {
        return FALSE;
    }
}
    return TRUE;
}
