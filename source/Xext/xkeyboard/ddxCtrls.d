module xkb.ddxCtrls;
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

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
//import x11.keysym;
import externs.X11.extensions.XKB;

import xkb.xkbsrv_priv;

import dix.inputstr;import include.scrnintstr;
import include.windowstr;
import include.xkbstr;


void XkbDDXKeybdCtrlProc(DeviceIntPtr dev, KeybdCtrl* ctrl)
{
    int realRepeat = void;

    realRepeat = ctrl.autoRepeat;
    if ((dev.kbdfeed) && (XkbDDXUsesSoftRepeat(dev)))
        ctrl.autoRepeat = 0;
    if (dev.key && dev.key.xkbInfo && dev.key.xkbInfo.kbdProc)
        (*dev.key.xkbInfo.kbdProc) (dev, ctrl);
    ctrl.autoRepeat = realRepeat;
    return;
}

int XkbDDXUsesSoftRepeat(DeviceIntPtr pXDev)
{
    return 1;
}

void XkbDDXChangeControls(DeviceIntPtr dev, XkbControlsPtr old, XkbControlsPtr new_)
{
    uint changed = void, i = void;
    ubyte* rep_old = void, rep_new = void, rep_fb = void;

    changed = new_.enabled_ctrls ^ old.enabled_ctrls;
    for (rep_old = old.per_key_repeat.ptr,
         rep_new = new_.per_key_repeat.ptr,
         rep_fb = dev.kbdfeed.ctrl.autoRepeats.ptr,
         i = 0; i < XkbPerKeyBitArraySize; i++) {
        if (rep_old[i] != rep_new[i]) {
            rep_fb[i] = rep_new[i];
            changed &= XkbPerKeyRepeatMask;
        }
    }

    if (changed & XkbPerKeyRepeatMask) {
        if (dev.kbdfeed.CtrlProc)
            (*dev.kbdfeed.CtrlProc) (dev, &dev.kbdfeed.ctrl);
    }
    return;
}
