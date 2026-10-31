module shadowfb;
@nogc nothrow:
extern(C): __gshared:
/*
   Copyright (C) 1999.  The XFree86 Project Inc.
   Copyright 2014 Red Hat, Inc.

   Written by Mark Vojkovich (mvojkovi@ucsd.edu)
   Pre-fb-write callbacks and RENDER support - Nolan Leake (nolan@vmware.com)
*/
import build.xorg_config;

//import x11.X;
//import x11.Xproto;
// //import externs.X11.fonts.font;
// //import externs.X11.fonts.fontstruct;

import dix.screen_hooks_priv;

import include.misc;
import include.pixmapstr;
import include.input;
import include.mi;
import include.scrnintstr;
import include.windowstr;
import include.gcstruct;
import dix.dixfonts;
import include.xf86;
import include.xf86str;
import shadowfb;

import include.picturestr;
import include.shadowfb;
import hw.xfree86.common.xf86Helper;
import dix.screen_hooks;
import os.log;


struct _ShadowScreenRec {
    ScrnInfoPtr pScrn;
    RefreshAreaFuncPtr preRefresh;
    RefreshAreaFuncPtr postRefresh;
    CreateWindowProcPtr CreateWindow;
}alias ShadowScreenRec = _ShadowScreenRec;
alias ShadowScreenPtr = ShadowScreenRec*;

private DevPrivateKeyRec ShadowScreenKeyRec;

private ShadowScreenPtr shadowfbGetScreenPrivate(ScreenPtr pScreen)
{
    return cast(_ShadowScreenRec*)dixLookupPrivate(&(pScreen).devPrivates, &ShadowScreenKeyRec);
}

Bool ShadowFBInit2(ScreenPtr pScreen, RefreshAreaFuncPtr preRefreshArea, RefreshAreaFuncPtr postRefreshArea)
{
    ScrnInfoPtr pScrn = xf86ScreenToScrn(pScreen);
    ShadowScreenPtr pPriv = void;

    if (!preRefreshArea && !postRefreshArea)
        return FALSE;

    if (!dixRegisterPrivateKey(&ShadowScreenKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (((pPriv = cast(ShadowScreenPtr) cast(ShadowScreenRec*) calloc(1, ShadowScreenRec.sizeof)) is null))
        return FALSE;

    dixSetPrivate(&pScreen.devPrivates, &ShadowScreenKeyRec, pPriv);

    pPriv.pScrn = pScrn;
    pPriv.preRefresh = preRefreshArea;
    pPriv.postRefresh = postRefreshArea;

    dixScreenHookClose(pScreen, &ShadowCloseScreen);

    pPriv.CreateWindow = pScreen.CreateWindow;
    pScreen.CreateWindow = &ShadowCreateRootWindow;

    return TRUE;
}

Bool ShadowFBInit(ScreenPtr pScreen, RefreshAreaFuncPtr refreshArea)
{
    return ShadowFBInit2(pScreen, null, refreshArea);
}

/*
 * Note that we don't do DamageEmpty, or indeed look at the region inside the
 * DamagePtr at all.  This is an optimization, believe it or not.  The
 * incoming RegionPtr is the new damage, and if we were to empty the region
 * miext/damage would just have to waste time reallocating and re-unioning
 * it every time, whereas if we leave it around the union gets fast-pathed
 * away.
 */

private void shadowfbReportPre(DamagePtr damage, RegionPtr reg, void* closure)
{
    ShadowScreenPtr pPriv = cast(ShadowScreenPtr)closure;

    if (!pPriv.pScrn.vtSema)
        return;

    pPriv.preRefresh(pPriv.pScrn, RegionNumRects(reg), RegionRects(reg));
}

private void shadowfbReportPost(DamagePtr damage, RegionPtr reg, void* closure)
{
    ShadowScreenPtr pPriv = cast(ShadowScreenPtr)closure;

    if (!pPriv.pScrn.vtSema)
        return;

    pPriv.postRefresh(pPriv.pScrn, RegionNumRects(reg), RegionRects(reg));
}

private Bool ShadowCreateRootWindow(WindowPtr pWin)
{
    Bool ret = void;
    ScreenPtr pScreen = pWin.drawable.pScreen;
    ShadowScreenPtr pPriv = shadowfbGetScreenPrivate(pScreen);

    /* paranoia */
    if (pWin != pScreen.root)
        ErrorF("ShadowCreateRootWindow called unexpectedly\n");

    /* call down, but don't hook ourselves back in; we know the first time
     * we're called it's for the root window.
     */
    pScreen.CreateWindow = pPriv.CreateWindow;
    ret = pScreen.CreateWindow(pWin);

    /* this might look like it leaks, but the damage code reaps listeners
     * when their drawable disappears.
     */
    if (ret) {
        DamagePtr damage = void;

        if (pPriv.preRefresh) {
            damage = DamageCreate(&shadowfbReportPre, null,
                                  DamageReportRawRegion,
                                  TRUE, pScreen, pPriv);
            DamageRegister(&pWin.drawable, damage);
        }

        if (pPriv.postRefresh) {
            damage = DamageCreate(&shadowfbReportPost, null,
                                  DamageReportRawRegion,
                                  TRUE, pScreen, pPriv);
            DamageSetReportAfterOp(damage, TRUE);
            DamageRegister(&pWin.drawable, damage);
        }
    }

    return ret;
}

private void ShadowCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookClose(pScreen, &ShadowCloseScreen);

    ShadowScreenPtr pPriv = shadowfbGetScreenPrivate(pScreen);
    if (!pPriv)
        return;

    free(pPriv);
    dixSetPrivate(&pScreen.devPrivates, &ShadowScreenKeyRec, null);
}
