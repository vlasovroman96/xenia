module xkb.hw.xfree86.xkb.xkbKillSrv;
@nogc nothrow:
extern(C): __gshared:
/************************************************************
Copyright (c) 1993 by Silicon Graphics Computer Systems, Inc.

Permission to use, copy, modify, and distribute this
software and its documentation for any purpose and without
fee is hereby granted, provided that the above copyright
notice appear in all copies and that both that copyright
notice and this permission notice appear in supporting
documentation, and that the name of Silicon Graphics not be
used in advertising or publicity pertaining to distribution
of the software without specific prior written permission.
Silicon Graphics makes no representation about the suitability
of this software for any purpose. It is provided "as is"
without any express or implied warranty.

SILICON GRAPHICS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL SILICON
GRAPHICS BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION  WITH
THE USE OR PERFORMANCE OF THIS SOFTWARE.

********************************************************/

import build.dix_config;

import build.xorg_config;

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
//import x11.keysym;
////import externs.X11.extensions.XI;

import hw.xfree86.common.action_priv;
import xkb.xkbsrv_priv;

import dix.inputstr;import include.scrnintstr;
import include.windowstr;
import dix.events;
// import externs.X11.extensions.XKBstr;
import include.xkbstr;


import xf86_priv;

// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int XkbDDXTerminateServer(DeviceIntPtr dev, KeyCode key, XkbAction* act)
{
    if (dev != inputInfo.keyboard)
        xf86ProcessActionEvent(ACTION_TERMINATE, null);

    return 0;
}
