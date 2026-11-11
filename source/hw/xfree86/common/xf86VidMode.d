module xf86VidMode;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 1999-2003 by The XFree86 Project, Inc.
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
 * This file contains the VidMode functions required by the extension.
 * These have been added to avoid the need for the higher level extension
 * code to access the private XFree86 data structures directly. Wherever
 * possible this code uses the functions in xf86Mode.c to do the work,
 * so that two version of code that do similar things don't have to be
 * maintained.
 */
import build.xorg_config;
import build.xlibre_server;

//import x11.X;

import dix.screenint_priv;
import os.log_priv;

import os.os;
import xf86_priv;
import hw.xfree86.common.xf86Priv;
import xf86Globals;
import xf86Mode;
import common.math;

static if(XF86VIDMODE){
import hw.xfree86.xext.vidmode;
// import vidmodestr;
import xf86Extensions;
import xf86cmap;
import hw.xfree86.common.xf86Helper;
import xf86Cursor;


private vidMonitorValue xf86VidModeGetMonitorValue(ScreenPtr pScreen, int valtyp, int indx)
{
    vidMonitorValue ret = { null, };
    MonPtr monitor = void;
    ScrnInfoPtr pScrn = void;

    pScrn = xf86ScreenToScrn(pScreen);
    monitor = pScrn.monitor;

    switch (valtyp) {
    case VIDMODE_MON_VENDOR:
        ret.ptr = monitor.vendor;
        break;
    case VIDMODE_MON_MODEL:
        ret.ptr = monitor.model;
        break;
    case VIDMODE_MON_NHSYNC:
        ret.i = monitor.nHsync;
        break;
    case VIDMODE_MON_NVREFRESH:
        ret.i = monitor.nVrefresh;
        break;
    case VIDMODE_MON_HSYNC_LO:
        ret.f = (100.0 * monitor.hsync[indx].lo);
        break;
    case VIDMODE_MON_HSYNC_HI:
        ret.f = (100.0 * monitor.hsync[indx].hi);
        break;
    case VIDMODE_MON_VREFRESH_LO:
        ret.f = (100.0 * monitor.vrefresh[indx].lo);
        break;
    case VIDMODE_MON_VREFRESH_HI:
        ret.f = (100.0 * monitor.vrefresh[indx].hi);
        break;
    default: break;}
    return ret;
}

private Bool xf86VidModeGetCurrentModeline(ScreenPtr pScreen, DisplayModePtr* mode, int* dotClock)
{
    ScrnInfoPtr pScrn = void;

    pScrn = xf86ScreenToScrn(pScreen);

    if (pScrn.currentMode) {
        *mode = pScrn.currentMode;
        *dotClock = pScrn.currentMode.Clock;

        return TRUE;
    }
    return FALSE;
}

private int xf86VidModeGetDotClock(ScreenPtr pScreen, int Clock)
{
    ScrnInfoPtr pScrn = void;

    pScrn = xf86ScreenToScrn(pScreen);
    if ((pScrn.progClock) || (Clock >= MAXCLOCKS))
        return Clock;
    else
        return pScrn.clock[Clock];
}

private int xf86VidModeGetNumOfClocks(ScreenPtr pScreen, Bool* progClock)
{
    ScrnInfoPtr pScrn = void;

    pScrn = xf86ScreenToScrn(pScreen);
    if (pScrn.progClock) {
        *progClock = TRUE;
        return 0;
    }
    else {
        *progClock = FALSE;
        return pScrn.numClocks;
    }
}

private Bool xf86VidModeGetClocks(ScreenPtr pScreen, int* Clocks)
{
    ScrnInfoPtr pScrn = void;
    int i = void;

    pScrn = xf86ScreenToScrn(pScreen);

    if (pScrn.progClock)
        return FALSE;

    for (i = 0; i < pScrn.numClocks; i++)
        *Clocks++ = pScrn.clock[i];

    return TRUE;
}

private Bool xf86VidModeGetNextModeline(ScreenPtr pScreen, DisplayModePtr* mode, int* dotClock)
{
    VidModePtr pVidMode = void;
    DisplayModePtr p = void;

    pVidMode = VidModeGetPtr(pScreen);

    for (p = pVidMode.Next; p !is null && p != pVidMode.First; p = p.next) {
        if (p.status == MODE_OK) {
            pVidMode.Next = p.next;
            *mode = p;
            *dotClock = xf86VidModeGetDotClock(pScreen, p.Clock);
            return TRUE;
        }
    }

    return FALSE;
}

private Bool xf86VidModeGetFirstModeline(ScreenPtr pScreen, DisplayModePtr* mode, int* dotClock)
{
    ScrnInfoPtr pScrn = void;
    VidModePtr pVidMode = void;

    pScrn = xf86ScreenToScrn(pScreen);
    if (pScrn.modes is null)
        return FALSE;

    pVidMode = VidModeGetPtr(pScreen);
    pVidMode.First = pScrn.modes;
    pVidMode.Next = pVidMode.First.next;

    if (pVidMode.First.status == MODE_OK) {
        *mode = pVidMode.First;
        *dotClock = xf86VidModeGetDotClock(pScreen, pVidMode.First.Clock);
        return TRUE;
    }

    return xf86VidModeGetNextModeline(pScreen, mode, dotClock);
}

private Bool xf86VidModeDeleteModeline(ScreenPtr pScreen, DisplayModePtr mode)
{
    ScrnInfoPtr pScrn = void;

    if (mode is null)
        return FALSE;

    pScrn = xf86ScreenToScrn(pScreen);
    xf86DeleteMode(&(pScrn.modes), mode);
    return TRUE;
}

private Bool xf86VidModeZoomViewport(ScreenPtr pScreen, int zoom)
{
    xf86ZoomViewport(pScreen, zoom);
    return TRUE;
}

private Bool xf86VidModeSetViewPort(ScreenPtr pScreen, int x, int y)
{
    ScrnInfoPtr pScrn = void;

    pScrn = xf86ScreenToScrn(pScreen);
    pScrn.frameX0 = min(max(x, 0),
                         pScrn.virtualX - pScrn.currentMode.HDisplay);
    pScrn.frameX1 = pScrn.frameX0 + pScrn.currentMode.HDisplay - 1;
    pScrn.frameY0 = min(max(y, 0),
                         pScrn.virtualY - pScrn.currentMode.VDisplay);
    pScrn.frameY1 = pScrn.frameY0 + pScrn.currentMode.VDisplay - 1;
    if (pScrn.AdjustFrame !is null)
        (pScrn.AdjustFrame) (pScrn, pScrn.frameX0, pScrn.frameY0);

    return TRUE;
}

private Bool xf86VidModeGetViewPort(ScreenPtr pScreen, int* x, int* y)
{
    ScrnInfoPtr pScrn = void;

    pScrn = xf86ScreenToScrn(pScreen);
    *x = pScrn.frameX0;
    *y = pScrn.frameY0;
    return TRUE;
}

private Bool xf86VidModeSwitchMode(ScreenPtr pScreen, DisplayModePtr mode)
{
    ScrnInfoPtr pScrn = void;
    DisplayModePtr pTmpMode = void;
    Bool retval = void;

    pScrn = xf86ScreenToScrn(pScreen);
    /* save in case we fail */
    pTmpMode = pScrn.currentMode;
    /* Force a mode switch */
    pScrn.currentMode = null;
    retval = xf86SwitchMode(pScrn.pScreen, mode);
    /* we failed: restore it */
    if (retval == FALSE)
        pScrn.currentMode = pTmpMode;
    return retval;
}

private Bool xf86VidModeLockZoom(ScreenPtr pScreen, Bool lock)
{
    if (xf86Info.dontZoom)
        return FALSE;

    xf86LockZoom(pScreen, lock);
    return TRUE;
}

private ModeStatus xf86VidModeCheckModeForMonitor(ScreenPtr pScreen, DisplayModePtr mode)
{
    ScrnInfoPtr pScrn = void;

    if (mode is null)
        return MODE_ERROR;

    pScrn = xf86ScreenToScrn(pScreen);

    return xf86CheckModeForMonitor(mode, pScrn.monitor);
}

private ModeStatus xf86VidModeCheckModeForDriver(ScreenPtr pScreen, DisplayModePtr mode)
{
    ScrnInfoPtr pScrn = void;

    if (mode is null)
        return MODE_ERROR;

    pScrn = xf86ScreenToScrn(pScreen);

    return xf86CheckModeForDriver(pScrn, mode, 0);
}

private void xf86VidModeSetCrtcForMode(ScreenPtr pScreen, DisplayModePtr mode)
{
    ScrnInfoPtr pScrn = void;
    DisplayModePtr ScreenModes = void;

    if (mode is null)
        return;

    /* Ugly hack so that the xf86Mode.c function can be used without change */
    pScrn = xf86ScreenToScrn(pScreen);
    ScreenModes = pScrn.modes;
    pScrn.modes = mode;

    xf86SetCrtcForModes(pScrn, pScrn.adjustFlags);
    pScrn.modes = ScreenModes;
    return;
}

private Bool xf86VidModeAddModeline(ScreenPtr pScreen, DisplayModePtr mode)
{
    ScrnInfoPtr pScrn = void;

    if (mode is null)
        return FALSE;

    pScrn = xf86ScreenToScrn(pScreen);

    mode.name = strdup(""); /* freed by deletemode */
    mode.status = MODE_OK;
    mode.next = pScrn.modes.next;
    mode.prev = pScrn.modes;
    pScrn.modes.next = mode;
    if (mode.next !is null)
        mode.next.prev = mode;

    return TRUE;
}

private int xf86VidModeGetNumOfModes(ScreenPtr pScreen)
{
    DisplayModePtr mode = null;
    int dotClock = 0, nummodes = 0;

    if (!xf86VidModeGetFirstModeline(pScreen, &mode, &dotClock))
        return nummodes;

    do {
        nummodes++;
        if (!xf86VidModeGetNextModeline(pScreen, &mode, &dotClock))
            return nummodes;
    } while (TRUE);
}

private Bool xf86VidModeSetGamma(ScreenPtr pScreen, float red, float green, float blue)
{
    Gamma gamma = void;

    gamma.red = red;
    gamma.green = green;
    gamma.blue = blue;
    if (xf86ChangeGamma(pScreen, gamma) != Success)
        return FALSE;
    else
        return TRUE;
}

private Bool xf86VidModeGetGamma(ScreenPtr pScreen, float* red, float* green, float* blue)
{
    ScrnInfoPtr pScrn = void;

    pScrn = xf86ScreenToScrn(pScreen);
    *red = pScrn.gamma.red;
    *green = pScrn.gamma.green;
    *blue = pScrn.gamma.blue;
    return TRUE;
}

private Bool xf86VidModeSetGammaRamp(ScreenPtr pScreen, int size, CARD16* r, CARD16* g, CARD16* b)
{
    xf86ChangeGammaRamp(pScreen, size, r, g, b);
    return TRUE;
}

private Bool xf86VidModeGetGammaRamp(ScreenPtr pScreen, int size, CARD16* r, CARD16* g, CARD16* b)
{
    xf86GetGammaRamp(pScreen, size, r, g, b);
    return TRUE;
}

private Bool xf86VidModeInit(ScreenPtr pScreen)
{
    VidModePtr pVidMode = void;

    if (!xf86Info.vidModeEnabled) {
        DebugF("!xf86GetVidModeEnabled()\n");
        return FALSE;
    }

    pVidMode = VidModeInit(pScreen);
    if (!pVidMode)
        return FALSE;

    pVidMode.Flags = 0;
    pVidMode.Next = null;

    pVidMode.GetMonitorValue = &xf86VidModeGetMonitorValue;
    pVidMode.GetCurrentModeline = &xf86VidModeGetCurrentModeline;
    pVidMode.GetFirstModeline = &xf86VidModeGetFirstModeline;
    pVidMode.GetNextModeline = &xf86VidModeGetNextModeline;
    pVidMode.DeleteModeline = &xf86VidModeDeleteModeline;
    pVidMode.ZoomViewport = &xf86VidModeZoomViewport;
    pVidMode.GetViewPort = &xf86VidModeGetViewPort;
    pVidMode.SetViewPort = &xf86VidModeSetViewPort;
    pVidMode.SwitchMode = &xf86VidModeSwitchMode;
    pVidMode.LockZoom = &xf86VidModeLockZoom;
    pVidMode.GetNumOfClocks = &xf86VidModeGetNumOfClocks;
    pVidMode.GetClocks = &xf86VidModeGetClocks;
    pVidMode.CheckModeForMonitor = &xf86VidModeCheckModeForMonitor;
    pVidMode.CheckModeForDriver = &xf86VidModeCheckModeForDriver;
    pVidMode.SetCrtcForMode = &xf86VidModeSetCrtcForMode;
    pVidMode.AddModeline = &xf86VidModeAddModeline;
    pVidMode.GetDotClock = &xf86VidModeGetDotClock;
    pVidMode.GetNumOfModes = &xf86VidModeGetNumOfModes;
    pVidMode.SetGamma = &xf86VidModeSetGamma;
    pVidMode.GetGamma = &xf86VidModeGetGamma;
    pVidMode.SetGammaRamp = &xf86VidModeSetGammaRamp;
    pVidMode.GetGammaRamp = &xf86VidModeGetGammaRamp;
    pVidMode.GetGammaRampSize = &xf86GetGammaRampSize; /* use xf86cmap API directly */

    return TRUE;
}

void XFree86VidModeExtensionInit()
{
    Bool enabled = FALSE;

    DebugF("XFree86VidModeExtensionInit");

    /* This means that the DDX doesn't want the vidmode extension enabled */
    if (!xf86Info.vidModeEnabled)
        return;

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (xf86VidModeInit(walkScreen))
            enabled = TRUE;
    });

    /* This means that the DDX doesn't want the vidmode extension enabled */
    if (!enabled)
        return;

   VidModeAddExtension(xf86Info.vidModeAllowNonLocal);
}

}                          /* XF86VIDMODE */
