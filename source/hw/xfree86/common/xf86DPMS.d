module xf86DPMS;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 1997-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */
/*
 * This file contains the DPMS functions required by the extension.
 */
import build.xorg_config;

//import x11.X;
import os.os;
import dix.window;
import hw.xfree86.common.xf86Priv;
import xf86Opt_priv;
import hw.xfree86.common.xf86Helper;
import build.xlibre_server;
import externs.X11.extensions.dpmsconst;
import Xext.dpms;
import xf86VGAarbiter;

static if(DPMSExtension) {
//import externs.X11.extensions.dpmsconst;
import Xext.dpmsproc;
}
// import xf86VGAarbiter_priv;

static if(DPMSExtension) {
private void xf86DPMS(ScreenPtr pScreen, int level)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    if (pScrn.DPMSSet && pScrn.vtSema) {
        xf86VGAarbiterLock(pScrn);
        pScrn.DPMSSet(pScrn, level, 0);
        xf86VGAarbiterUnlock(pScrn);
    }
}
}

Bool xf86DPMSInit(ScreenPtr pScreen, DPMSSetProcPtr set, int flags)
{
static if(DPMSExtension) {
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    void* DPMSOpt = void;
    MessageType enabled_from = X_DEFAULT;
    Bool enabled = TRUE;

    DPMSOpt = xf86FindOption(cast(_InputOption*)pScrn.options, "dpms");
    if (DPMSDisabledSwitch) {
        enabled_from = X_CMDLINE;
        enabled = FALSE;
    }
    else if (DPMSOpt !is null) {
        enabled_from = X_CONFIG;
        enabled = xf86CheckBoolOption(cast(_InputOption*)pScrn.options, "dpms", FALSE);
        xf86MarkOptionUsed(cast(_InputOption*)DPMSOpt);
    }
    if (enabled) {
        xf86DrvMsg(pScreen.myNum, enabled_from, "DPMS enabled\n");
        pScrn.DPMSSet = set;
        pScreen.DPMS = &xf86DPMS;
    }
    return TRUE;
} else {
    return FALSE;
}
}
