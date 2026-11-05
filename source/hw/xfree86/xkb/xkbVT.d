module xkb.xkbVT;
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
import build.xorg_config;

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
//import x11.keysym;
////import externs.X11.extensions.XI;

import hw.xfree86.common.action_priv;
import xkb.xkbsrv_priv;

import dix.inputstr;
import dix.scrnintstr;
import dix.window;

import xf86_priv;
import externs.X11.extensions.XKB;
import include.xkbstr;


// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int XkbDDXSwitchScreen(DeviceIntPtr dev, KeyCode key, XkbAction* act)
{
    int scrnnum = mixin(XkbSAScreen!("&act.screen"));

    if (act.screen.flags & XkbSA_SwitchApplication) {
        if (act.screen.flags & XkbSA_SwitchAbsolute)
            xf86ProcessActionEvent(ACTION_SWITCHSCREEN, cast(void*) &scrnnum);
        else {
            if (scrnnum < 0)
                xf86ProcessActionEvent(ACTION_SWITCHSCREEN_PREV, null);
            else
                xf86ProcessActionEvent(ACTION_SWITCHSCREEN_NEXT, null);
        }
    }

    return 1;
}
