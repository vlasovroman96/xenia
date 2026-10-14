module xf86CursorRD;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import dix.colormap_priv;
import dix.cursor_priv;
import dix.screen_hooks_priv;
import mi.mipointer_priv;

import include.xf86;
import hw.xfree86.ramdac.xf86CursorPriv;
import dix.cursor;
import hw.xfree86.common.xf86Helper;
import dix.screen_hooks;
import dix.events;
import include.privates;
import dix.devices;

/* FIXME: This was added with the ABI change of the miPointerSpriteFuncs for
 * MPX.
 * inputInfo is needed to pass the core pointer as the default argument into
 * the cursor functions.
 *
 * Externing inputInfo is not the nice way to do it but it works.
 */
import include.inputstr;

DevPrivateKeyRec xf86CursorScreenKeyRec;
DevScreenPrivateKeyRec xf86ScreenCursorBitsKeyRec;

/* sprite functions */








private miPointerSpriteFuncRec xf86CursorSpriteFuncs = {
    &xf86CursorRealizeCursor,
    &xf86CursorUnrealizeCursor,
    &xf86CursorSetCursor,
    &xf86CursorMoveCursor,
    &xf86DeviceCursorInitialize,
    &xf86DeviceCursorCleanup
};

/* Screen functions */






/* ScrnInfoRec functions */




Bool xf86InitCursor(ScreenPtr pScreen, xf86CursorInfoPtr infoPtr)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    xf86CursorScreenPtr ScreenPriv = void;
    miPointerScreenPtr PointPriv = void;

    if (!xf86InitHardwareCursor(pScreen, infoPtr))
        return FALSE;

    if (!dixRegisterPrivateKey(&xf86CursorScreenKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    ScreenPriv = cast(xf86CursorScreenRec*) calloc(1, xf86CursorScreenRec.sizeof);
    if (!ScreenPriv)
        return FALSE;

    if (!dixRegisterScreenPrivateKey(&xf86ScreenCursorBitsKeyRec, pScreen,
                                     PRIVATE_CURSOR, 0))
        return FALSE;

    dixSetPrivate(&pScreen.devPrivates, &xf86CursorScreenKeyRec, ScreenPriv);

    ScreenPriv.SWCursor = TRUE;
    ScreenPriv.isUp = FALSE;
    ScreenPriv.CurrentCursor = null;
    ScreenPriv.CursorInfoPtr = infoPtr;
    ScreenPriv.PalettedCursor = FALSE;
    ScreenPriv.pInstalledMap = null;

    dixScreenHookClose(pScreen, &xf86CursorCloseScreen);
    ScreenPriv.QueryBestSize = pScreen.QueryBestSize;
    pScreen.QueryBestSize = &xf86CursorQueryBestSize;
    ScreenPriv.RecolorCursor = pScreen.RecolorCursor;
    pScreen.RecolorCursor = &xf86CursorRecolorCursor;

    if ((infoPtr.pScrn.bitsPerPixel == 8) &&
        !(infoPtr.Flags & HARDWARE_CURSOR_TRUECOLOR_AT_8BPP)) {
        ScreenPriv.InstallColormap = pScreen.InstallColormap;
        pScreen.InstallColormap = &xf86CursorInstallColormap;
        ScreenPriv.PalettedCursor = TRUE;
    }

    PointPriv = cast(_MiPointerScreenRec*)dixLookupPrivate(&pScreen.devPrivates, miPointerScreenKey);

    ScreenPriv.showTransparent = PointPriv.showTransparent;
    if (infoPtr.Flags & HARDWARE_CURSOR_SHOW_TRANSPARENT)
        PointPriv.showTransparent = TRUE;
    else
        PointPriv.showTransparent = FALSE;
    ScreenPriv.spriteFuncs = PointPriv.spriteFuncs;
    PointPriv.spriteFuncs = &xf86CursorSpriteFuncs;

    ScreenPriv.EnableDisableFBAccess = pScrn.EnableDisableFBAccess;
    ScreenPriv.SwitchMode = pScrn.SwitchMode;

    ScreenPriv.ForceHWCursorCount = 0;
    ScreenPriv.HWCursorForced = FALSE;

    pScrn.EnableDisableFBAccess = &xf86CursorEnableDisableFBAccess;
    if (pScrn.SwitchMode)
        pScrn.SwitchMode = &xf86CursorSwitchMode;

    return TRUE;
}

/***** Screen functions *****/

private void xf86CursorCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    if (!pScrn)
        return;

    dixScreenUnhookClose(pScreen, &xf86CursorCloseScreen);

    miPointerScreenPtr PointPriv = cast(miPointerScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                              miPointerScreenKey);
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (ScreenPriv.isUp && pScrn.vtSema)
        xf86SetCursor(pScreen, NullCursor, ScreenPriv.x, ScreenPriv.y);

    FreeCursor(ScreenPriv.CurrentCursor, None);

    pScreen.QueryBestSize = ScreenPriv.QueryBestSize;
    pScreen.RecolorCursor = ScreenPriv.RecolorCursor;
    if (ScreenPriv.InstallColormap)
        pScreen.InstallColormap = ScreenPriv.InstallColormap;

    PointPriv.spriteFuncs = ScreenPriv.spriteFuncs;
    PointPriv.showTransparent = ScreenPriv.showTransparent;

    pScrn.EnableDisableFBAccess = ScreenPriv.EnableDisableFBAccess;
    pScrn.SwitchMode = ScreenPriv.SwitchMode;

    free(ScreenPriv.transparentData);
    free(ScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, &xf86CursorScreenKeyRec, null);
}

private void xf86CursorQueryBestSize(int class_, ushort* width, ushort* height, ScreenPtr pScreen)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (class_ == CursorShape) {
        if (*width > ScreenPriv.CursorInfoPtr.MaxWidth)
            *width = cast(ushort)ScreenPriv.CursorInfoPtr.MaxWidth;
        if (*height > ScreenPriv.CursorInfoPtr.MaxHeight)
            *height = cast(ushort)ScreenPriv.CursorInfoPtr.MaxHeight;
    }
    else
        (*ScreenPriv.QueryBestSize) (class_, width, height, pScreen);
}

private void xf86CursorInstallColormap(ColormapPtr pMap)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pMap.pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    ScreenPriv.pInstalledMap = pMap;

    (*ScreenPriv.InstallColormap) (pMap);
}

private void xf86CursorRecolorCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCurs, Bool displayed)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (!displayed)
        return;

    if (ScreenPriv.SWCursor)
        (*ScreenPriv.RecolorCursor) (pDev, pScreen, pCurs, displayed);
    else
        xf86RecolorCursor(pScreen, pCurs, displayed);
}

/***** ScrnInfoRec functions *********/

private void xf86CursorEnableDisableFBAccess(ScrnInfoPtr pScrn, Bool enable)
{
    DeviceIntPtr pDev = inputInfo.pointer;

    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (!enable && ScreenPriv.CurrentCursor != NullCursor) {
        CursorPtr currentCursor = RefCursor(ScreenPriv.CurrentCursor);

        xf86CursorSetCursor(pDev, pScreen, NullCursor, ScreenPriv.x,
                            ScreenPriv.y);
        ScreenPriv.isUp = FALSE;
        ScreenPriv.SWCursor = TRUE;
        ScreenPriv.SavedCursor = currentCursor;
    }

    if (ScreenPriv.EnableDisableFBAccess)
        (*ScreenPriv.EnableDisableFBAccess) (pScrn, enable);

    if (enable && ScreenPriv.SavedCursor) {
        /*
         * Re-set current cursor so drivers can react to FB access having been
         * temporarily disabled.
         */
        xf86CursorSetCursor(pDev, pScreen, ScreenPriv.SavedCursor,
                            ScreenPriv.x, ScreenPriv.y);
        UnrefCursor(ScreenPriv.SavedCursor);
        ScreenPriv.SavedCursor = null;
    }
}

private Bool xf86CursorSwitchMode(ScrnInfoPtr pScrn, DisplayModePtr mode)
{
    Bool ret = void;
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (ScreenPriv.isUp) {
        xf86SetCursor(pScreen, NullCursor, ScreenPriv.x, ScreenPriv.y);
        ScreenPriv.isUp = FALSE;
    }

    ret = (*ScreenPriv.SwitchMode) (pScrn, mode);

    /*
     * Cannot restore cursor here because the new frame[XY][01] haven't been
     * calculated yet.  However, because the hardware cursor was removed above,
     * ensure the cursor is repainted by miPointerWarpCursor().
     */
    ScreenPriv.CursorToRestore = ScreenPriv.CurrentCursor;
    miPointerSetWaitForUpdate(pScreen, FALSE);  /* Force cursor repaint */

    return ret;
}

/****** miPointerSpriteFunctions *******/

private Bool xf86CursorRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCurs)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (CursorRefCount(pCurs) <= 1)
        dixSetScreenPrivate(&pCurs.devPrivates, &xf86ScreenCursorBitsKeyRec,
                            pScreen, null);

    return (*ScreenPriv.spriteFuncs.RealizeCursor) (pDev, pScreen, pCurs);
}

private Bool xf86CursorUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCurs)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (CursorRefCount(pCurs) <= 1) {
        free(dixLookupScreenPrivate
             (&pCurs.devPrivates, &xf86ScreenCursorBitsKeyRec, pScreen));
        dixSetScreenPrivate(&pCurs.devPrivates, &xf86ScreenCursorBitsKeyRec,
                            pScreen, null);
    }

    return (*ScreenPriv.spriteFuncs.UnrealizeCursor) (pDev, pScreen, pCurs);
}

private void xf86CursorSetCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCurs, int x, int y)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);
    xf86CursorInfoPtr infoPtr = ScreenPriv.CursorInfoPtr;

    if (pCurs == NullCursor) {  /* means we're supposed to remove the cursor */
        if (ScreenPriv.SWCursor ||
            !(GetMaster(pDev, MASTER_POINTER) == inputInfo.pointer))
            (*ScreenPriv.spriteFuncs.SetCursor) (pDev, pScreen, NullCursor, x,
                                                   y);
        else if (ScreenPriv.isUp) {
            xf86SetCursor(pScreen, NullCursor, x, y);
            ScreenPriv.isUp = FALSE;
        }
        FreeCursor(ScreenPriv.CurrentCursor, None);
        ScreenPriv.CurrentCursor = NullCursor;
        return;
    }

    /* only update for VCP, otherwise we get cursor jumps when removing a
       sprite. The second cursor is never HW rendered anyway. */
    if (GetMaster(pDev, MASTER_POINTER) == inputInfo.pointer) {
        CursorPtr cursor = RefCursor(pCurs);
        FreeCursor(ScreenPriv.CurrentCursor, None);
        ScreenPriv.CurrentCursor = cursor;
        ScreenPriv.x = cast(short)x;
        ScreenPriv.y = cast(short)y;
        ScreenPriv.CursorToRestore = null;
        ScreenPriv.HotX = cursor.bits.xhot;
        ScreenPriv.HotY = cursor.bits.yhot;

        if (!infoPtr.pScrn.vtSema) {
            cursor = RefCursor(cursor);
            FreeCursor(ScreenPriv.SavedCursor, None);
            ScreenPriv.SavedCursor = cursor;
            return;
        }

        if (infoPtr.pScrn.vtSema &&
            (ScreenPriv.ForceHWCursorCount ||
             xf86CheckHWCursor(pScreen, cursor, infoPtr))) {

            if (ScreenPriv.SWCursor)   /* remove the SW cursor */
                (*ScreenPriv.spriteFuncs.SetCursor) (pDev, pScreen,
                                                       NullCursor, x, y);

            if (xf86SetCursor(pScreen, cursor, x, y)) {
                ScreenPriv.SWCursor = FALSE;
                ScreenPriv.isUp = TRUE;

                miPointerSetWaitForUpdate(pScreen, !infoPtr.pScrn.silkenMouse);
                return;
            }
        }

        miPointerSetWaitForUpdate(pScreen, TRUE);

        if (ScreenPriv.isUp) {
            /* Remove the HW cursor, or make it transparent */
            if (infoPtr.Flags & HARDWARE_CURSOR_SHOW_TRANSPARENT) {
                xf86SetTransparentCursor(pScreen);
            }
            else {
                xf86SetCursor(pScreen, NullCursor, x, y);
                ScreenPriv.isUp = FALSE;
            }
        }

        if (!ScreenPriv.SWCursor)
            ScreenPriv.SWCursor = TRUE;

    }

    if (pCurs.bits.emptyMask && !ScreenPriv.showTransparent)
        pCurs = NullCursor;

    (*ScreenPriv.spriteFuncs.SetCursor) (pDev, pScreen, pCurs, x, y);
}

/* Re-set the current cursor. This will switch between hardware and software
 * cursor depending on whether hardware cursor is currently supported
 * according to the driver.
 */
void xf86CursorResetCursor(ScreenPtr pScreen)
{
    xf86CursorScreenPtr ScreenPriv = void;

    if (!inputInfo.pointer)
        return;

    if (!dixPrivateKeyRegistered(&xf86CursorScreenKeyRec))
        return;

    ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                                        &xf86CursorScreenKeyRec);
    if (!ScreenPriv)
        return;

    xf86CursorSetCursor(inputInfo.pointer, pScreen, ScreenPriv.CurrentCursor,
                        ScreenPriv.x, ScreenPriv.y);
}

private void xf86CursorMoveCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    /* only update coordinate state for first sprite, otherwise we get jumps
       when removing a sprite. The second sprite is never HW rendered anyway */
    if (GetMaster(pDev, MASTER_POINTER) == inputInfo.pointer) {
        ScreenPriv.x = cast(short)x;
        ScreenPriv.y = cast(short)y;

        if (ScreenPriv.CursorToRestore)
            xf86CursorSetCursor(pDev, pScreen, ScreenPriv.CursorToRestore, x,
                                y);
        else if (ScreenPriv.SWCursor)
            (*ScreenPriv.spriteFuncs.MoveCursor) (pDev, pScreen, x, y);
        else if (ScreenPriv.isUp)
            xf86MoveCursor(pScreen, x, y);
    }
    else
        (*ScreenPriv.spriteFuncs.MoveCursor) (pDev, pScreen, x, y);
}

void xf86ForceHWCursor(ScreenPtr pScreen, Bool on)
{
    DeviceIntPtr pDev = inputInfo.pointer;
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    if (on) {
        if (ScreenPriv.ForceHWCursorCount++ == 0) {
            if (ScreenPriv.SWCursor && ScreenPriv.CurrentCursor) {
                ScreenPriv.HWCursorForced = TRUE;
                xf86CursorSetCursor(pDev, pScreen, ScreenPriv.CurrentCursor,
                                    ScreenPriv.x, ScreenPriv.y);
            }
            else
                ScreenPriv.HWCursorForced = FALSE;
        }
    }
    else {
        if (--ScreenPriv.ForceHWCursorCount == 0) {
            if (ScreenPriv.HWCursorForced && ScreenPriv.CurrentCursor)
                xf86CursorSetCursor(pDev, pScreen, ScreenPriv.CurrentCursor,
                                    ScreenPriv.x, ScreenPriv.y);
        }
    }
}

CursorPtr xf86CurrentCursor(ScreenPtr pScreen)
{
    xf86CursorScreenPtr ScreenPriv = void;

    if (pScreen.is_output_secondary)
        pScreen = pScreen.current_primary;

    ScreenPriv = cast(_Xf86CursorScreenRec*)dixLookupPrivate(&pScreen.devPrivates, &xf86CursorScreenKeyRec);
    return ScreenPriv.CurrentCursor;
}

xf86CursorInfoPtr xf86CreateCursorInfoRec()
{
    return cast(xf86CursorInfoRec*) calloc(1, xf86CursorInfoRec.sizeof);
}

void xf86DestroyCursorInfoRec(xf86CursorInfoPtr infoPtr)
{
    free(infoPtr);
}

/**
 * New cursor has been created. Do your initializations here.
 */
private Bool xf86DeviceCursorInitialize(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    int ret = void;
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    /* Init SW cursor */
    ret = (*ScreenPriv.spriteFuncs.DeviceCursorInitialize) (pDev, pScreen);

    return ret;
}

/**
 * Cursor has been removed. Clean up after yourself.
 */
private void xf86DeviceCursorCleanup(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    xf86CursorScreenPtr ScreenPriv = cast(xf86CursorScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &xf86CursorScreenKeyRec);

    /* Clean up SW cursor */
    (*ScreenPriv.spriteFuncs.DeviceCursorCleanup) (pDev, pScreen);
}
