module xf86VGAarbiter;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * This code was stolen from RAC and adapted to control the legacy vga
 * interface.
 *
 *
 * Copyright (c) 2007 Paulo R. Zanoni, Tiago Vignatti
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use,
 * copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following
 * conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES
 * OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT
 * HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 */

import build.xorg_config;

import dix.colormap_priv;

import xf86VGAarbiter_priv;
import xf86VGAarbiterPriv;
import xf86Bus;
import hw.xfree86.common.xf86Priv;
import externs.pciaccess;
import mi.mipointer;
import os.log;
import hw.xfree86.common.xf86Helper;
import render.picture;
import xf86VGAarbiterPriv;
import xf86Globals;
import os.inputthread;
import hw.xfree86.modes.displaymode;
import dix.picture;

private GCFuncs VGAarbiterGCFuncs = {
    &VGAarbiterValidateGC, &VGAarbiterChangeGC, &VGAarbiterCopyGC,
    &VGAarbiterDestroyGC, &VGAarbiterChangeClip, &VGAarbiterDestroyClip,
    &VGAarbiterCopyClip
};

private GCOps VGAarbiterGCOps = {
    &VGAarbiterFillSpans, &VGAarbiterSetSpans, &VGAarbiterPutImage,
    &VGAarbiterCopyArea, &VGAarbiterCopyPlane, &VGAarbiterPolyPoint,
    &VGAarbiterPolylines, &VGAarbiterPolySegment, &VGAarbiterPolyRectangle,
    &VGAarbiterPolyArc, &VGAarbiterFillPolygon, &VGAarbiterPolyFillRect,
    &VGAarbiterPolyFillArc, &VGAarbiterPolyText8, &VGAarbiterPolyText16,
    &VGAarbiterImageText8, &VGAarbiterImageText16, &VGAarbiterImageGlyphBlt,
    &VGAarbiterPolyGlyphBlt, &VGAarbiterPushPixels,
};

private miPointerSpriteFuncRec VGAarbiterSpriteFuncs = {
    &VGAarbiterSpriteRealizeCursor, &VGAarbiterSpriteUnrealizeCursor,
    &VGAarbiterSpriteSetCursor, &VGAarbiterSpriteMoveCursor,
    &VGAarbiterDeviceCursorInitialize, &VGAarbiterDeviceCursorCleanup
};

private DevPrivateKeyRec VGAarbiterScreenKeyRec;
private DevPrivateKeyRec VGAarbiterGCKeyRec;

private int vga_no_arb = 0;
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86VGAarbiterInit()
{
    if (pci_device_vgaarb_init() != 0) {
        vga_no_arb = 1;
        LogMessageVerb(X_WARNING, 1,
                      "VGA arbiter: cannot open kernel arbiter, no multi-card support\n");
    }
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86VGAarbiterFini()
{
    if (vga_no_arb)
        return;
    pci_device_vgaarb_fini();
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86VGAarbiterLock(ScrnInfoPtr pScrn)
{
    if (vga_no_arb)
        return;
    pci_device_vgaarb_set_target(pScrn.vgaDev);
    pci_device_vgaarb_lock();
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86VGAarbiterUnlock(ScrnInfoPtr pScrn)
{
    if (vga_no_arb)
        return;
    pci_device_vgaarb_unlock();
}

Bool xf86VGAarbiterAllowDRI(ScreenPtr pScreen)
{
    int vga_count = void;
    int rsrc_decodes = 0;
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);

    if (vga_no_arb)
        return True;

    pci_device_vgaarb_get_info(pScrn.vgaDev, &vga_count, &rsrc_decodes);
    if (vga_count > 1) {
        if (rsrc_decodes) {
            return False;
        }
    }
    return True;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86VGAarbiterScrnInit(ScrnInfoPtr pScrn)
{
    pci_device* dev = void;
    EntityPtr pEnt = void;

    if (vga_no_arb)
        return;

    pEnt = xf86Entities[pScrn.entityList[0]];
    if (pEnt.bus.type != BUS_PCI)
        return;

    dev = pEnt.bus.id.pci;
    pScrn.vgaDev = dev;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VGAarbiterWrapFunctions()
{
    ScrnInfoPtr pScrn = void;
    VGAarbiterScreenPtr pScreenPriv = void;
    miPointerScreenPtr PointPriv = void;
    PictureScreenPtr ps = void;
    ScreenPtr pScreen = void;
    int vga_count = void, i = void;

    if (vga_no_arb)
        return False;

    /*
     * we need to wrap the arbiter if we have more than
     * one VGA card - hotplug cries.
     */
    pci_device_vgaarb_get_info(null, &vga_count, null);
    if (vga_count < 2 || !xf86Screens)
        return False;

    LogMessageVerb(X_INFO, 1,
                   "Found %d VGA devices: arbiter wrapping enabled\n",
                   vga_count);

    for (i = 0; i < xf86NumScreens; i++) {
        pScreen = xf86Screens[i].pScreen;
        ps = mixin(GetPictureScreenIfSet!("pScreen"));
        pScrn = xf86ScreenToScrn(pScreen);
        PointPriv = cast(_MiPointerScreenRec*)dixLookupPrivate(&pScreen.devPrivates, miPointerScreenKey);

        if (!dixRegisterPrivateKey
            (&VGAarbiterGCKeyRec, PRIVATE_GC, VGAarbiterGCRec.sizeof))
            return False;

        if (!dixRegisterPrivateKey(&VGAarbiterScreenKeyRec, PRIVATE_SCREEN, 0))
            return False;

        if (((pScreenPriv = cast(VGAarbiterScreenRec*) calloc(1, VGAarbiterScreenRec.sizeof)) is null))
            return False;

        dixSetPrivate(&pScreen.devPrivates, &VGAarbiterScreenKeyRec, pScreenPriv);

        mixin(WRAP_SCREEN!("CloseScreen", "VGAarbiterCloseScreen"));
        mixin(WRAP_SCREEN!("SaveScreen", "VGAarbiterSaveScreen"));
        mixin(WRAP_SCREEN!("WakeupHandler", "VGAarbiterWakeupHandler"));
        mixin(WRAP_SCREEN!("BlockHandler", "VGAarbiterBlockHandler"));
        mixin(WRAP_SCREEN!("CreateGC", "VGAarbiterCreateGC"));
        mixin(WRAP_SCREEN!("GetImage", "VGAarbiterGetImage"));
        mixin(WRAP_SCREEN!("GetSpans", "VGAarbiterGetSpans"));
        mixin(WRAP_SCREEN!("SourceValidate", "VGAarbiterSourceValidate"));
        mixin(WRAP_SCREEN!("CopyWindow", "VGAarbiterCopyWindow"));
        mixin(WRAP_SCREEN!("ClearToBackground", "VGAarbiterClearToBackground"));
        mixin(WRAP_SCREEN!("CreatePixmap", "VGAarbiterCreatePixmap"));
        mixin(WRAP_SCREEN!("StoreColors", "VGAarbiterStoreColors"));
        mixin(WRAP_SCREEN!("DisplayCursor", "VGAarbiterDisplayCursor"));
        mixin(WRAP_SCREEN!("RealizeCursor", "VGAarbiterRealizeCursor"));
        mixin(WRAP_SCREEN!("UnrealizeCursor", "VGAarbiterUnrealizeCursor"));
        mixin(WRAP_SCREEN!("RecolorCursor", "VGAarbiterRecolorCursor"));
        mixin(WRAP_SCREEN!("SetCursorPosition", "VGAarbiterSetCursorPosition"));
        mixin(WRAP_PICT!("Composite", "VGAarbiterComposite"));
        mixin(WRAP_PICT!("Glyphs", "VGAarbiterGlyphs"));
        mixin(WRAP_PICT!("CompositeRects", "VGAarbiterCompositeRects"));
        mixin(WRAP_SCREEN_INFO!("AdjustFrame", "VGAarbiterAdjustFrame"));
        mixin(WRAP_SCREEN_INFO!("SwitchMode", "VGAarbiterSwitchMode"));
        mixin(WRAP_SCREEN_INFO!("EnterVT", "VGAarbiterEnterVT"));
        mixin(WRAP_SCREEN_INFO!("LeaveVT", "VGAarbiterLeaveVT"));
        mixin(WRAP_SCREEN_INFO!("FreeScreen", "VGAarbiterFreeScreen"));
        mixin(WRAP_SPRITE);
    }

    return True;
}

/* Screen funcs */
private Bool VGAarbiterCloseScreen(ScreenPtr pScreen)
{
    Bool val = void;
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    VGAarbiterScreenPtr pScreenPriv = cast(VGAarbiterScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &VGAarbiterScreenKeyRec);
    miPointerScreenPtr PointPriv = cast(miPointerScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                              miPointerScreenKey);
    PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("pScreen"));

    mixin(UNWRAP_SCREEN!("CreateGC"));
    mixin(UNWRAP_SCREEN!("CloseScreen"));
    mixin(UNWRAP_SCREEN!("GetImage"));
    mixin(UNWRAP_SCREEN!("GetSpans"));
    mixin(UNWRAP_SCREEN!("SourceValidate"));
    mixin(UNWRAP_SCREEN!("CopyWindow"));
    mixin(UNWRAP_SCREEN!("ClearToBackground"));
    mixin(UNWRAP_SCREEN!("SaveScreen"));
    mixin(UNWRAP_SCREEN!("StoreColors"));
    mixin(UNWRAP_SCREEN!("DisplayCursor"));
    mixin(UNWRAP_SCREEN!("RealizeCursor"));
    mixin(UNWRAP_SCREEN!("UnrealizeCursor"));
    mixin(UNWRAP_SCREEN!("RecolorCursor"));
    mixin(UNWRAP_SCREEN!("SetCursorPosition"));
    mixin(UNWRAP_PICT!("Composite"));
    mixin(UNWRAP_PICT!("Glyphs"));
    mixin(UNWRAP_PICT!("CompositeRects"));
    mixin(UNWRAP_SCREEN_INFO!("AdjustFrame"));
    mixin(UNWRAP_SCREEN_INFO!("SwitchMode"));
    mixin(UNWRAP_SCREEN_INFO!("EnterVT"));
    mixin(UNWRAP_SCREEN_INFO!("LeaveVT"));
    mixin(UNWRAP_SCREEN_INFO!("FreeScreen"));
    mixin(UNWRAP_SPRITE);

    free(cast(void*) pScreenPriv);
    xf86VGAarbiterLock(xf86ScreenToScrn(pScreen));
    val = (*pScreen.CloseScreen) (pScreen);
    xf86VGAarbiterUnlock(xf86ScreenToScrn(pScreen));
    return val;
}

private void VGAarbiterBlockHandler(ScreenPtr pScreen, void* pTimeout)
{
    mixin(SCREEN_PROLOG!("BlockHandler"));
    VGAGet(pScreen);
    pScreen.BlockHandler(pScreen, pTimeout);
    VGAPut();
    mixin(SCREEN_EPILOG!("BlockHandler", "VGAarbiterBlockHandler"));
}

private void VGAarbiterWakeupHandler(ScreenPtr pScreen, int result)
{
    mixin(SCREEN_PROLOG!("WakeupHandler"));
    VGAGet(pScreen);
    pScreen.WakeupHandler(pScreen, result);
    VGAPut();
    mixin(SCREEN_EPILOG!("WakeupHandler", "VGAarbiterWakeupHandler"));
}

private void VGAarbiterGetImage(DrawablePtr pDrawable, int sx, int sy, int w, int h, uint format, c_ulong planemask, char* pdstLine)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(SCREEN_PROLOG!("GetImage"));
    VGAGet(pScreen);
    (*pScreen.GetImage) (pDrawable, sx, sy, w, h, format, planemask, pdstLine);
    VGAPut();
    mixin(SCREEN_EPILOG!("GetImage", "VGAarbiterGetImage"));
}

private void VGAarbiterGetSpans(DrawablePtr pDrawable, int wMax, xPoint* ppt, int* pwidth, int nspans, char* pdstStart)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(SCREEN_PROLOG!("GetSpans"));
    VGAGet(pScreen);
    (*pScreen.GetSpans) (pDrawable, wMax, ppt, pwidth, nspans, pdstStart);
    VGAPut();
    mixin(SCREEN_EPILOG!("GetSpans", "VGAarbiterGetSpans"));
}

private void VGAarbiterSourceValidate(DrawablePtr pDrawable, int x, int y, int width, int height, uint subWindowMode)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(SCREEN_PROLOG!("SourceValidate"));
    VGAGet(pScreen);
    (*pScreen.SourceValidate) (pDrawable, x, y, width, height,
                                subWindowMode);
    VGAPut();
    mixin(SCREEN_EPILOG!("SourceValidate", "VGAarbiterSourceValidate"));
}

private void VGAarbiterCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;

    mixin(SCREEN_PROLOG!("CopyWindow"));
    VGAGet(pScreen);
    (*pScreen.CopyWindow) (pWin, ptOldOrg, prgnSrc);
    VGAPut();
    mixin(SCREEN_EPILOG!("CopyWindow", "VGAarbiterCopyWindow"));
}

private void VGAarbiterClearToBackground(WindowPtr pWin, int x, int y, int w, int h, Bool generateExposures)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;

    mixin(SCREEN_PROLOG!("ClearToBackground"));
    VGAGet(pScreen);
    (*pScreen.ClearToBackground) (pWin, x, y, w, h, generateExposures);
    VGAPut();
    mixin(SCREEN_EPILOG!("ClearToBackground", "VGAarbiterClearToBackground"));
}

private PixmapPtr VGAarbiterCreatePixmap(ScreenPtr pScreen, int w, int h, int depth, uint usage_hint)
{
    PixmapPtr pPix = void;

    mixin(SCREEN_PROLOG!("CreatePixmap"));
    VGAGet(pScreen);
    pPix = (*pScreen.CreatePixmap) (pScreen, w, h, depth, usage_hint);
    VGAPut();
    mixin(SCREEN_EPILOG!("CreatePixmap", "VGAarbiterCreatePixmap"));

    return pPix;
}

private Bool VGAarbiterSaveScreen(ScreenPtr pScreen, Bool unblank)
{
    Bool val = void;

    mixin(SCREEN_PROLOG!("SaveScreen"));
    VGAGet(pScreen);
    val = (*pScreen.SaveScreen) (pScreen, unblank);
    VGAPut();
    mixin(SCREEN_EPILOG!("SaveScreen", "VGAarbiterSaveScreen"));

    return val;
}

private void VGAarbiterStoreColors(ColormapPtr pmap, int ndef, xColorItem* pdefs)
{
    ScreenPtr pScreen = pmap.pScreen;

    mixin(SCREEN_PROLOG!("StoreColors"));
    VGAGet(pScreen);
    (*pScreen.StoreColors) (pmap, ndef, pdefs);
    VGAPut();
    mixin(SCREEN_EPILOG!("StoreColors", "VGAarbiterStoreColors"));
}

private void VGAarbiterRecolorCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCurs, Bool displayed)
{
    mixin(SCREEN_PROLOG!("RecolorCursor"));
    VGAGet(pScreen);
    (*pScreen.RecolorCursor) (pDev, pScreen, pCurs, displayed);
    VGAPut();
    mixin(SCREEN_EPILOG!("RecolorCursor", "VGAarbiterRecolorCursor"));
}

private Bool VGAarbiterRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    Bool val = void;

    mixin(SCREEN_PROLOG!("RealizeCursor"));
    VGAGet(pScreen);
    val = (*pScreen.RealizeCursor) (pDev, pScreen, pCursor);
    VGAPut();
    mixin(SCREEN_EPILOG!("RealizeCursor", "VGAarbiterRealizeCursor"));
    return val;
}

private Bool VGAarbiterUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    Bool val = void;

    mixin(SCREEN_PROLOG!("UnrealizeCursor"));
    VGAGet(pScreen);
    val = (*pScreen.UnrealizeCursor) (pDev, pScreen, pCursor);
    VGAPut();
    mixin(SCREEN_EPILOG!("UnrealizeCursor", "VGAarbiterUnrealizeCursor"));
    return val;
}

private Bool VGAarbiterDisplayCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    Bool val = void;

    mixin(SCREEN_PROLOG!("DisplayCursor"));
    VGAGet(pScreen);
    val = (*pScreen.DisplayCursor) (pDev, pScreen, pCursor);
    VGAPut();
    mixin(SCREEN_EPILOG!("DisplayCursor", "VGAarbiterDisplayCursor"));
    return val;
}

private Bool VGAarbiterSetCursorPosition(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y, Bool generateEvent)
{
    Bool val = void;

    mixin(SCREEN_PROLOG!("SetCursorPosition"));
    VGAGet(pScreen);
    val = (*pScreen.SetCursorPosition) (pDev, pScreen, x, y, generateEvent);
    VGAPut();
    mixin(SCREEN_EPILOG!("SetCursorPosition", "VGAarbiterSetCursorPosition"));
    return val;
}

private void VGAarbiterAdjustFrame(ScrnInfoPtr pScrn, int x, int y)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    VGAarbiterScreenPtr pScreenPriv = cast(VGAarbiterScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &VGAarbiterScreenKeyRec);

    VGAGet(pScreen);
    (*pScreenPriv.AdjustFrame) (pScrn, x, y);
    VGAPut();
}

private Bool VGAarbiterSwitchMode(ScrnInfoPtr pScrn, DisplayModePtr mode)
{
    Bool val = void;
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    VGAarbiterScreenPtr pScreenPriv = cast(VGAarbiterScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &VGAarbiterScreenKeyRec);

    VGAGet(pScreen);
    val = (*pScreenPriv.SwitchMode) (pScrn, mode);
    VGAPut();
    return val;
}

private Bool VGAarbiterEnterVT(ScrnInfoPtr pScrn)
{
    Bool val = void;
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    VGAarbiterScreenPtr pScreenPriv = cast(VGAarbiterScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &VGAarbiterScreenKeyRec);

    VGAGet(pScreen);
    pScrn.EnterVT = pScreenPriv.EnterVT;
    val = (*pScrn.EnterVT) (pScrn);
    pScreenPriv.EnterVT = pScrn.EnterVT;
    pScrn.EnterVT = &VGAarbiterEnterVT;
    VGAPut();
    return val;
}

private void VGAarbiterLeaveVT(ScrnInfoPtr pScrn)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    VGAarbiterScreenPtr pScreenPriv = cast(VGAarbiterScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &VGAarbiterScreenKeyRec);

    VGAGet(pScreen);
    pScrn.LeaveVT = pScreenPriv.LeaveVT;
    (*pScreenPriv.LeaveVT) (pScrn);
    pScreenPriv.LeaveVT = pScrn.LeaveVT;
    pScrn.LeaveVT = &VGAarbiterLeaveVT;
    VGAPut();
}

private void VGAarbiterFreeScreen(ScrnInfoPtr pScrn)
{
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    VGAarbiterScreenPtr pScreenPriv = cast(VGAarbiterScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                               &VGAarbiterScreenKeyRec);

    VGAGet(pScreen);
    (*pScreenPriv.FreeScreen) (pScrn);
    VGAPut();
}

private Bool VGAarbiterCreateGC(GCPtr pGC)
{
    ScreenPtr pScreen = pGC.pScreen;
    VGAarbiterGCPtr pGCPriv = cast(VGAarbiterGCPtr) dixLookupPrivate(&pGC.devPrivates, &VGAarbiterGCKeyRec);
    Bool ret = void;

    mixin(SCREEN_PROLOG!("CreateGC"));
    ret = (*pScreen.CreateGC) (pGC);
    mixin(GC_WRAP!("pGC"));
    mixin(SCREEN_EPILOG!("CreateGC", "VGAarbiterCreateGC"));

    return ret;
}

/* GC funcs */
private void VGAarbiterValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDraw)
{
    mixin(GC_UNWRAP!("pGC"));
    (*pGC.funcs.ValidateGC) (pGC, changes, pDraw);
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterDestroyGC(GCPtr pGC)
{
    mixin(GC_UNWRAP!("pGC"));
    (*pGC.funcs.DestroyGC) (pGC);
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterChangeGC(GCPtr pGC, c_ulong mask)
{
    mixin(GC_UNWRAP!("pGC"));
    (*pGC.funcs.ChangeGC) (pGC, mask);
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterCopyGC(GCPtr pGCSrc, c_ulong mask, GCPtr pGCDst)
{
    mixin(GC_UNWRAP!("pGCDst"));
    (*pGCDst.funcs.CopyGC) (pGCSrc, mask, pGCDst);
    mixin(GC_WRAP!("pGCDst"));
}

private void VGAarbiterChangeClip(GCPtr pGC, int type, void* pvalue, int nrects)
{
    mixin(GC_UNWRAP!("pGC"));
    (*pGC.funcs.ChangeClip) (pGC, type, pvalue, nrects);
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterCopyClip(GCPtr pgcDst, GCPtr pgcSrc)
{
    mixin(GC_UNWRAP!("pgcDst"));
    (*pgcDst.funcs.CopyClip) (pgcDst, pgcSrc);
    mixin(GC_WRAP!("pgcDst"));
}

private void VGAarbiterDestroyClip(GCPtr pGC)
{
    mixin(GC_UNWRAP!("pGC"));
    (*pGC.funcs.DestroyClip) (pGC);
    mixin(GC_WRAP!("pGC"));
}

/* GC Ops */
private void VGAarbiterFillSpans(DrawablePtr pDraw, GCPtr pGC, int nInit, xPoint* pptInit, int* pwidthInit, int fSorted)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.FillSpans) (pDraw, pGC, nInit, pptInit, pwidthInit, fSorted);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterSetSpans(DrawablePtr pDraw, GCPtr pGC, char* pcharsrc, xPoint* ppt, int* pwidth, int nspans, int fSorted)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.SetSpans) (pDraw, pGC, pcharsrc, ppt, pwidth, nspans, fSorted);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPutImage(DrawablePtr pDraw, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* pImage)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PutImage) (pDraw, pGC, depth, x, y, w, h,
                           leftPad, format, pImage);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private RegionPtr VGAarbiterCopyArea(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty)
{
    RegionPtr ret = void;
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    ret = (*pGC.ops.CopyArea) (pSrc, pDst,
                                 pGC, srcx, srcy, width, height, dstx, dsty);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
    return ret;
}

private RegionPtr VGAarbiterCopyPlane(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty, c_ulong bitPlane)
{
    RegionPtr ret = void;
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    ret = (*pGC.ops.CopyPlane) (pSrc, pDst, pGC, srcx, srcy,
                                  width, height, dstx, dsty, bitPlane);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
    return ret;
}

private void VGAarbiterPolyPoint(DrawablePtr pDraw, GCPtr pGC, int mode, int npt, xPoint* pptInit)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PolyPoint) (pDraw, pGC, mode, npt, pptInit);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPolylines(DrawablePtr pDraw, GCPtr pGC, int mode, int npt, xPoint* pptInit)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.Polylines) (pDraw, pGC, mode, npt, pptInit);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPolySegment(DrawablePtr pDraw, GCPtr pGC, int nseg, xSegment* pSeg)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PolySegment) (pDraw, pGC, nseg, pSeg);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPolyRectangle(DrawablePtr pDraw, GCPtr pGC, int nRectsInit, xRectangle* pRectsInit)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PolyRectangle) (pDraw, pGC, nRectsInit, pRectsInit);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPolyArc(DrawablePtr pDraw, GCPtr pGC, int narcs, xArc* parcs)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PolyArc) (pDraw, pGC, narcs, parcs);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterFillPolygon(DrawablePtr pDraw, GCPtr pGC, int shape, int mode, int count, xPoint* ptsIn)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.FillPolygon) (pDraw, pGC, shape, mode, count, ptsIn);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPolyFillRect(DrawablePtr pDraw, GCPtr pGC, int nrectFill, xRectangle* prectInit)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PolyFillRect) (pDraw, pGC, nrectFill, prectInit);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPolyFillArc(DrawablePtr pDraw, GCPtr pGC, int narcs, xArc* parcs)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PolyFillArc) (pDraw, pGC, narcs, parcs);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private int VGAarbiterPolyText8(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, char* chars)
{
    int ret = void;
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    ret = (*pGC.ops.PolyText8) (pDraw, pGC, x, y, count, chars);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
    return ret;
}

private int VGAarbiterPolyText16(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    int ret = void;
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    ret = (*pGC.ops.PolyText16) (pDraw, pGC, x, y, count, chars);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
    return ret;
}

private void VGAarbiterImageText8(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, char* chars)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.ImageText8) (pDraw, pGC, x, y, count, chars);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterImageText16(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.ImageText16) (pDraw, pGC, x, y, count, chars);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterImageGlyphBlt(DrawablePtr pDraw, GCPtr pGC, int xInit, int yInit, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.ImageGlyphBlt) (pDraw, pGC, xInit, yInit,
                                nglyph, ppci, pglyphBase);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPolyGlyphBlt(DrawablePtr pDraw, GCPtr pGC, int xInit, int yInit, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PolyGlyphBlt) (pDraw, pGC, xInit, yInit,
                               nglyph, ppci, pglyphBase);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

private void VGAarbiterPushPixels(GCPtr pGC, PixmapPtr pBitMap, DrawablePtr pDraw, int dx, int dy, int xOrg, int yOrg)
{
    ScreenPtr pScreen = pGC.pScreen;

    mixin(GC_UNWRAP!("pGC"));
    VGAGet(pScreen);
    (*pGC.ops.PushPixels) (pGC, pBitMap, pDraw, dx, dy, xOrg, yOrg);
    VGAPut();
    mixin(GC_WRAP!("pGC"));
}

/* miSpriteFuncs */
private Bool VGAarbiterSpriteRealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCur)
{
    Bool val = void;

    mixin(SPRITE_PROLOG);
    VGAGet(pScreen);
    val = PointPriv.spriteFuncs.RealizeCursor(pDev, pScreen, pCur);
    VGAPut();
    mixin(SPRITE_EPILOG);
    return val;
}

private Bool VGAarbiterSpriteUnrealizeCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCur)
{
    Bool val = void;

    mixin(SPRITE_PROLOG);
    VGAGet(pScreen);
    val = PointPriv.spriteFuncs.UnrealizeCursor(pDev, pScreen, pCur);
    VGAPut();
    mixin(SPRITE_EPILOG);
    return val;
}

private void VGAarbiterSpriteSetCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCur, int x, int y)
{
    mixin(SPRITE_PROLOG);
    VGAGet(pScreen);
    PointPriv.spriteFuncs.SetCursor(pDev, pScreen, pCur, x, y);
    VGAPut();
    mixin(SPRITE_EPILOG);
}

private void VGAarbiterSpriteMoveCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    mixin(SPRITE_PROLOG);
    VGAGet(pScreen);
    PointPriv.spriteFuncs.MoveCursor(pDev, pScreen, x, y);
    VGAPut();
    mixin(SPRITE_EPILOG);
}

private Bool VGAarbiterDeviceCursorInitialize(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    Bool val = void;

    mixin(SPRITE_PROLOG);
    VGAGet(pScreen);
    val = PointPriv.spriteFuncs.DeviceCursorInitialize(pDev, pScreen);
    VGAPut();
    mixin(SPRITE_EPILOG);
    return val;
}

private void VGAarbiterDeviceCursorCleanup(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    mixin(SPRITE_PROLOG);
    VGAGet(pScreen);
    PointPriv.spriteFuncs.DeviceCursorCleanup(pDev, pScreen);
    VGAPut();
    mixin(SPRITE_EPILOG);
}

private void VGAarbiterComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(PICTURE_PROLOGUE!("Composite"));

    VGAGet(pScreen);
    (*ps.Composite) (op, pSrc, pMask, pDst, xSrc, ySrc, xMask, yMask, xDst,
                      yDst, width, height);
    VGAPut();
    mixin(PICTURE_EPILOGUE!("Composite", "VGAarbiterComposite"));
}

private void VGAarbiterGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(PICTURE_PROLOGUE!("Glyphs"));

    VGAGet(pScreen);
    (*ps.Glyphs) (op, pSrc, pDst, maskFormat, xSrc, ySrc, nlist, list, glyphs);
    VGAPut();
    mixin(PICTURE_EPILOGUE!("Glyphs", "VGAarbiterGlyphs"));
}

private void VGAarbiterCompositeRects(CARD8 op, PicturePtr pDst, xRenderColor* color, int nRect, xRectangle* rects)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(PICTURE_PROLOGUE!("CompositeRects"));

    VGAGet(pScreen);
    (*ps.CompositeRects) (op, pDst, color, nRect, rects);
    VGAPut();
    mixin(PICTURE_EPILOGUE!("CompositeRects", "VGAarbiterCompositeRects"));
}
