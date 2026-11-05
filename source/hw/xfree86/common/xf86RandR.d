module xf86RandR;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2002 Keith Packard, member of The XFree86 Project, Inc.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */
import build.xlibre_server;
import Xext.panoramiXsrv;

//import x11.X;

import dix.input_priv;
import dix.screen_hooks_priv;
import include.xf86DDC;

import os.os;
import xf86_priv;
import include.xf86str;
import include.xf86Priv;
import mi.mipointer;
import dix.inputstr;
import hw.xfree86.common.xf86Helper;
import xf86Cursor;
import dix.events;
import randr.rrinfo;
import randr.randr;
import dix.screen_hooks;
import hw.xfree86.modes.displaymode;

struct _xf86RandRInfo {
    int virtualX;
    int virtualY;
    int mmWidth;
    int mmHeight;
    Rotation rotation;
}alias XF86RandRInfoRec = _xf86RandRInfo;
alias XF86RandRInfoPtr = _xf86RandRInfo*;

private DevPrivateKeyRec xf86RandRKeyRec;
private DevPrivateKey xf86RandRKey;

enum string XF86RANDRINFO(string p) = `(cast(XF86RandRInfoPtr)dixLookupPrivate(&(` ~ p ~ `).devPrivates, xf86RandRKey))`;

private int xf86RandRModeRefresh(DisplayModePtr mode)
{
    if (mode.VRefresh)
        return cast(int) (mode.VRefresh + 0.5);
    else if (mode.Clock == 0)
        return 0;
    else
        return cast(int) (mode.Clock * 1000.0 / mode.HTotal / mode.VTotal + 0.5);
}

private Bool xf86RandRGetInfo(ScreenPtr pScreen, Rotation* rotations)
{
    RRScreenSizePtr pSize = void;
    ScrnInfoPtr scrp = xf86ScreenToScrn(pScreen);
    XF86RandRInfoPtr randrp = mixin(XF86RANDRINFO!(`pScreen`));
    DisplayModePtr mode = void;
    int refresh0 = 60;
    xorgRRModeMM RRModeMM = void;

    *rotations = RR_Rotate_0;

    for (mode = scrp.modes; mode !is null; mode = mode.next) {
        int refresh = xf86RandRModeRefresh(mode);

        if (mode == scrp.modes)
            refresh0 = refresh;

        RRModeMM.mode = mode;
        RRModeMM.virtX = randrp.virtualX;
        RRModeMM.virtY = randrp.virtualY;
        RRModeMM.mmWidth = randrp.mmWidth;
        RRModeMM.mmHeight = randrp.mmHeight;

        if (scrp.DriverFunc) {
            (*scrp.DriverFunc) (scrp, RR_GET_MODE_MM, &RRModeMM);
        }

        pSize = RRRegisterSize(pScreen,
                               cast(short)mode.HDisplay, cast(short)mode.VDisplay,
                               cast(short)RRModeMM.mmWidth, cast(short)RRModeMM.mmHeight);
        if (!pSize)
            return FALSE;
        RRRegisterRate(pScreen, pSize, refresh);
        if (mode == scrp.currentMode &&
            mode.HDisplay == scrp.virtualX &&
            mode.VDisplay == scrp.virtualY)
            RRSetCurrentConfig(pScreen, randrp.rotation, refresh, pSize);
        if (mode.next == scrp.modes)
            break;
    }
    if (scrp.currentMode.HDisplay != randrp.virtualX ||
        scrp.currentMode.VDisplay != randrp.virtualY) {
        mode = scrp.modes;

        RRModeMM.mode = null;
        RRModeMM.virtX = randrp.virtualX;
        RRModeMM.virtY = randrp.virtualY;
        RRModeMM.mmWidth = randrp.mmWidth;
        RRModeMM.mmHeight = randrp.mmHeight;

        if (scrp.DriverFunc) {
            (*scrp.DriverFunc) (scrp, RR_GET_MODE_MM, &RRModeMM);
        }

        pSize = RRRegisterSize(pScreen,
                               cast(short)randrp.virtualX, cast(short)randrp.virtualY,
                               cast(short)RRModeMM.mmWidth, cast(short)RRModeMM.mmHeight);
        if (!pSize)
            return FALSE;
        RRRegisterRate(pScreen, pSize, refresh0);
        if (scrp.virtualX == randrp.virtualX &&
            scrp.virtualY == randrp.virtualY) {
            RRSetCurrentConfig(pScreen, randrp.rotation, refresh0, pSize);
        }
    }

    /* If there is driver support for randr, let it set our supported rotations */
    if (scrp.DriverFunc) {
        xorgRRRotation RRRotation = void;

        RRRotation.RRRotations = *rotations;
        if (!(*scrp.DriverFunc) (scrp, RR_GET_INFO, &RRRotation))
            return TRUE;
        *rotations = RRRotation.RRRotations;
    }

    return TRUE;
}

private Bool xf86RandRSetMode(ScreenPtr pScreen, DisplayModePtr mode, Bool useVirtual, int mmWidth, int mmHeight)
{
    ScrnInfoPtr scrp = xf86ScreenToScrn(pScreen);
    XF86RandRInfoPtr randrp = mixin(XF86RANDRINFO!(`pScreen`));
    int oldWidth = pScreen.width;
    int oldHeight = pScreen.height;
    int oldmmWidth = pScreen.mmWidth;
    int oldmmHeight = pScreen.mmHeight;
    int oldVirtualX = scrp.virtualX;
    int oldVirtualY = scrp.virtualY;
    WindowPtr pRoot = pScreen.root;
    Bool ret = TRUE;

    if (pRoot && scrp.vtSema)
        (*scrp.EnableDisableFBAccess) (scrp, FALSE);
    if (useVirtual) {
        scrp.virtualX = randrp.virtualX;
        scrp.virtualY = randrp.virtualY;
    }
    else {
        scrp.virtualX = mode.HDisplay;
        scrp.virtualY = mode.VDisplay;
    }

    /*
     * The DIX forgets the physical dimensions we passed into RRRegisterSize, so
     * reconstruct them if possible.
     */
    if (scrp.DriverFunc) {
        xorgRRModeMM RRModeMM = void;

        RRModeMM.mode = mode;
        RRModeMM.virtX = scrp.virtualX;
        RRModeMM.virtY = scrp.virtualY;
        RRModeMM.mmWidth = mmWidth;
        RRModeMM.mmHeight = mmHeight;

        (*scrp.DriverFunc) (scrp, RR_GET_MODE_MM, &RRModeMM);

        mmWidth = RRModeMM.mmWidth;
        mmHeight = RRModeMM.mmHeight;
    }
    if (randrp.rotation & (RR_Rotate_90 | RR_Rotate_270)) {
        /* If the screen is rotated 90 or 270 degrees, swap the sizes. */
        pScreen.width = cast(short)scrp.virtualY;
        pScreen.height = cast(short)scrp.virtualX;
        pScreen.mmWidth = cast(short)mmHeight;
        pScreen.mmHeight = cast(short)mmWidth;
    }
    else {
        pScreen.width = cast(short)scrp.virtualX;
        pScreen.height = cast(short)scrp.virtualY;
        pScreen.mmWidth = cast(short)mmWidth;
        pScreen.mmHeight = cast(short)mmHeight;
    }
    if (!xf86SwitchMode(pScreen, mode)) {
        pScreen.width = cast(short)oldWidth;
        pScreen.height = cast(short)oldHeight;
        pScreen.mmWidth = cast(short)oldmmWidth;
        pScreen.mmHeight = cast(short)oldmmHeight;
        scrp.virtualX = cast(short)oldVirtualX;
        scrp.virtualY = cast(short)oldVirtualY;
        ret = FALSE;
    }
    /*
     * Make sure the layout is correct
     */
    xf86ReconfigureLayout();

    if (scrp.vtSema) {
        /*
         * Make sure the whole screen is visible
         */
        xf86SetViewport (pScreen, pScreen.width, pScreen.height);
        xf86SetViewport (pScreen, 0, 0);
        if (pRoot)
            (*scrp.EnableDisableFBAccess) (scrp, TRUE);
    }
    return ret;
}

private Bool xf86RandRSetConfig(ScreenPtr pScreen, Rotation rotation, int rate, RRScreenSizePtr pSize)
{
    ScrnInfoPtr scrp = xf86ScreenToScrn(pScreen);
    XF86RandRInfoPtr randrp = mixin(XF86RANDRINFO!(`pScreen`));
    DisplayModePtr mode = void;
    int[2][MAXDEVICES] pos = void;
    Bool useVirtual = FALSE;
    Rotation oldRotation = randrp.rotation;
    DeviceIntPtr dev = void;
    Bool view_adjusted = FALSE;

    for (dev = inputInfo.devices; dev; dev = dev.next) {
        if (!InputDevIsMaster(dev) && !InputDevIsFloating(dev))
            continue;

        miPointerGetPosition(dev, &pos[dev.id][0], &pos[dev.id][1]);
    }

    for (mode = scrp.modes;; mode = mode.next) {
        if (mode.HDisplay == pSize.width &&
            mode.VDisplay == pSize.height &&
            (rate == 0 || xf86RandRModeRefresh(mode) == rate))
            break;
        if (mode.next == scrp.modes) {
            if (pSize.width == randrp.virtualX &&
                pSize.height == randrp.virtualY) {
                mode = scrp.modes;
                useVirtual = TRUE;
                break;
            }
            return FALSE;
        }
    }

    if (randrp.rotation != rotation) {

        /* Have the driver do its thing. */
        if (scrp.DriverFunc) {
            xorgRRRotation RRRotation = void;

            RRRotation.RRConfig.rotation = rotation;
            RRRotation.RRConfig.rate = rate;
            RRRotation.RRConfig.width = pSize.width;
            RRRotation.RRConfig.height = pSize.height;

            /*
             * Currently we need to rely on HW support for rotation.
             */
            if (!(*scrp.DriverFunc) (scrp, RR_SET_CONFIG, &RRRotation))
                return FALSE;
        }
        else
            return FALSE;

        randrp.rotation = rotation;
    }

    if (!xf86RandRSetMode
        (pScreen, mode, useVirtual, pSize.mmWidth, pSize.mmHeight)) {
        if (randrp.rotation != oldRotation) {
            /* Have the driver undo its thing. */
            if (scrp.DriverFunc) {
                xorgRRRotation RRRotation = void;

                RRRotation.RRConfig.rotation = oldRotation;
                RRRotation.RRConfig.rate =
                    xf86RandRModeRefresh(scrp.currentMode);
                RRRotation.RRConfig.width = scrp.virtualX;
                RRRotation.RRConfig.height = scrp.virtualY;
                (*scrp.DriverFunc) (scrp, RR_SET_CONFIG, &RRRotation);
            }

            randrp.rotation = oldRotation;
        }
        return FALSE;
    }

    update_desktop_dimensions();

    /*
     * Move the cursor back where it belongs; SwitchMode repositions it
     * FIXME: duplicated code, see modes/xf86RandR12.c
     */
    for (dev = inputInfo.devices; dev; dev = dev.next) {
        if (!InputDevIsMaster(dev) && !InputDevIsFloating(dev))
            continue;

        if (pScreen == miPointerGetScreen(dev)) {
            int px = pos[dev.id][0];
            int py = pos[dev.id][1];

            px = (px >= pScreen.width ? (pScreen.width - 1) : px);
            py = (py >= pScreen.height ? (pScreen.height - 1) : py);

            /* Setting the viewpoint makes only sense on one device */
            if (!view_adjusted && InputDevIsMaster(dev)) {
                xf86SetViewport(pScreen, px, py);
                view_adjusted = TRUE;
            }

            if (pScreen.SetCursorPosition)
                pScreen.SetCursorPosition(dev, pScreen, px, py, FALSE);
        }
    }

    return TRUE;
}

/*
 * Reset size back to original
 */
private void xf86RandRCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    ScrnInfoPtr scrp = xf86ScreenToScrn(pScreen);
    if (!scrp)
        return;

    XF86RandRInfoPtr randrp = mixin(XF86RANDRINFO!(`pScreen`));

    scrp.virtualX = pScreen.width = cast(short)randrp.virtualX;
    scrp.virtualY = pScreen.height = cast(short)randrp.virtualY;
    scrp.currentMode = scrp.modes;

    dixScreenUnhookClose(pScreen, &xf86RandRCloseScreen);
    free(randrp);
    dixSetPrivate(&pScreen.devPrivates, xf86RandRKey, null);
}

Bool xf86RandRInit(ScreenPtr pScreen)
{
    rrScrPrivPtr rp = void;
    ScrnInfoPtr scrp = xf86ScreenToScrn(pScreen);

static if(XINERAMA){
    /* XXX disable RandR when using Xinerama */
    if (!noPanoramiXExtension)
        return TRUE;
} /* XINERAMA */

    xf86RandRKey = &xf86RandRKeyRec;

    if (!dixRegisterPrivateKey(&xf86RandRKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    XF86RandRInfoPtr randrp = cast(XF86RandRInfoRec*) calloc(1, XF86RandRInfoRec.sizeof);
    if (!randrp)
        return FALSE;

    if (!RRScreenInit(pScreen)) {
        free(randrp);
        return FALSE;
    }
    rp = mixin(rrGetScrPriv!("pScreen"));
    rp.rrGetInfo = &xf86RandRGetInfo;
    rp.rrSetConfig = &xf86RandRSetConfig;

    randrp.virtualX = scrp.virtualX;
    randrp.virtualY = scrp.virtualY;
    randrp.mmWidth = pScreen.mmWidth;
    randrp.mmHeight = pScreen.mmHeight;

    dixScreenHookClose(pScreen, &xf86RandRCloseScreen);

    randrp.rotation = RR_Rotate_0;

    dixSetPrivate(&pScreen.devPrivates, xf86RandRKey, randrp);
    return TRUE;
}
