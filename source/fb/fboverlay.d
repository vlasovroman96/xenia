module fboverlay;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright © 2000 SuSE, Inc.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of SuSE not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  SuSE makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 * SuSE DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL SuSE
 * BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
 * OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * Author:  Keith Packard, SuSE, Inc.
 */

import build.xlibre_server;


import core.stdc.assert_;
import core.stdc.stdlib;

import include.shmint;
import mi.mi_priv;

import fb.fb;
import fboverlay;
import fb.fballpriv;
import fb.fbutil;
import mi.miscrinit;
import mi.micopy;

private DevPrivateKeyRec fbOverlayScreenPrivateKeyRec;

enum fbOverlayScreenPrivateKey = (&fbOverlayScreenPrivateKeyRec);

enum FB_OVERLAY_MAX =	2;


alias fbOverlayPaintKeyProc = void function(DrawablePtr, RegionPtr, CARD32, int);

struct FbOverlayLayer {
    union _U {
        struct _Init {
            void* pbits;
            int width;
            int depth;
        }_Init init;
        struct _Run {
            PixmapPtr pixmap;
            RegionRec region;
        }_Run run;
    }_U u;
    CARD32 key;                 /* special pixel value */
}

struct _fbOverlayScrPriv {
    int nlayers;
    fbOverlayPaintKeyProc PaintKey;
    miCopyProc CopyWindow;
    FbOverlayLayer[FB_OVERLAY_MAX] layer;
}alias FbOverlayScrPrivRec = _fbOverlayScrPriv;
alias FbOverlayScrPrivPtr = _fbOverlayScrPriv*;

enum string fbOverlayGetScrPriv(string s) = `
    cast(_fbOverlayScrPriv*)dixLookupPrivate((&` ~ s ~ `.devPrivates), fbOverlayGetScreenPrivateKey())`;

int fbOverlayFinishScreenInit(ScreenPtr pScreen, void* pbits1, void* pbits2, int xsize, int ysize, int dpix, int dpiy, int width1, int width2, int bpp1, int bpp2, int depth1, int depth2);


DevPrivateKey fbOverlayGetScreenPrivateKey()
{
    return fbOverlayScreenPrivateKey;
}

/*
 * Replace this if you want something supporting
 * multiple overlays with the same depth
 */
private Bool fbOverlayCreateWindow(WindowPtr pWin)
{
    FbOverlayScrPrivPtr pScrPriv = mixin(fbOverlayGetScrPriv!("pWin.drawable.pScreen"));
    int i = void;
    PixmapPtr pPixmap = void;

    if (pWin.drawable.class_ != InputOutput)
        return TRUE;

    for (i = 0; i < pScrPriv.nlayers; i++) {
        pPixmap = pScrPriv.layer[i].u.run.pixmap;
        if (pWin.drawable.depth == pPixmap.drawable.depth) {
            dixSetPrivate(&pWin.devPrivates, mixin(fbGetWinPrivateKey!("pWin")), pPixmap);
            /*
             * Make sure layer keys are written correctly by
             * having non-root layers set to full while the
             * root layer is set to empty.  This will cause
             * all of the layers to get painted when the root
             * is mapped
             */
            if (!pWin.parent) {
                RegionEmpty(&pScrPriv.layer[i].u.run.region);
            }
            return TRUE;
        }
    }
    return FALSE;
}

private Bool fbOverlayCloseScreen(ScreenPtr pScreen)
{
    FbOverlayScrPrivPtr pScrPriv = mixin(fbOverlayGetScrPriv!("pScreen"));
    int i = void;

    for (i = 0; i < pScrPriv.nlayers; i++) {
        dixDestroyPixmap(pScrPriv.layer[i].u.run.pixmap, 0);
        RegionUninit(&pScrPriv.layer[i].u.run.region);
    }
    return TRUE;
}

/*
 * Return layer containing this window
 */
private int fbOverlayWindowLayer(WindowPtr pWin)
{
    FbOverlayScrPrivPtr pScrPriv = mixin(fbOverlayGetScrPriv!("pWin.drawable.pScreen"));
    int i = void;

    for (i = 0; i < pScrPriv.nlayers; i++)
        if (dixLookupPrivate(&pWin.devPrivates, mixin(fbGetWinPrivateKey!("pWin"))) ==
            cast(void*) pScrPriv.layer[i].u.run.pixmap)
            return i;
    return 0;
}

private Bool fbOverlayCreateScreenResources(ScreenPtr pScreen)
{
    int i = void;
    FbOverlayScrPrivPtr pScrPriv = mixin(fbOverlayGetScrPriv!("pScreen"));
    PixmapPtr pPixmap = void;
    void* pbits = void;
    int width = void;
    int depth = void;
    BoxRec box = void;

    if (!miCreateScreenResources(pScreen))
        return FALSE;

    box.x1 = 0;
    box.y1 = 0;
    box.x2 = pScreen.width;
    box.y2 = pScreen.height;
    for (i = 0; i < pScrPriv.nlayers; i++) {
        pbits = pScrPriv.layer[i].u.init.pbits;
        width = pScrPriv.layer[i].u.init.width;
        depth = pScrPriv.layer[i].u.init.depth;
        pPixmap = (*pScreen.CreatePixmap) (pScreen, 0, 0, depth, 0);
        if (!pPixmap)
            return FALSE;
        if (!(*pScreen.ModifyPixmapHeader) (pPixmap, pScreen.width,
                                             pScreen.height, depth,
                                             mixin(BitsPerPixel!("depth")),
                                             PixmapBytePad(width, depth),
                                             pbits))
            return FALSE;
        pScrPriv.layer[i].u.run.pixmap = pPixmap;
        RegionInit(&pScrPriv.layer[i].u.run.region, &box, 0);
    }
    pScreen.devPrivate = pScrPriv.layer[0].u.run.pixmap;
    return TRUE;
}

private void fbOverlayPaintKey(DrawablePtr pDrawable, RegionPtr pRegion, CARD32 pixel, int layer)
{
    fbFillRegionSolid(pDrawable, pRegion, 0,
                      fbReplicatePixel(pixel, pDrawable.bitsPerPixel));
}

/*
 * Track visible region for each layer
 */
private void fbOverlayUpdateLayerRegion(ScreenPtr pScreen, int layer, RegionPtr prgn)
{
    FbOverlayScrPrivPtr pScrPriv = mixin(fbOverlayGetScrPriv!("pScreen"));
    int i = void;
    RegionRec rgnNew = void;

    if (!prgn || !RegionNotEmpty(prgn))
        return;
    for (i = 0; i < pScrPriv.nlayers; i++) {
        if (i == layer) {
            /* add new piece to this fb */
            RegionUnion(&pScrPriv.layer[i].u.run.region,
                        &pScrPriv.layer[i].u.run.region, prgn);
        }
        else if (RegionNotEmpty(&pScrPriv.layer[i].u.run.region)) {
            /* paint new piece with chroma key */
            RegionNull(&rgnNew);
            RegionIntersect(&rgnNew, prgn, &pScrPriv.layer[i].u.run.region);
            (*pScrPriv.PaintKey) (&pScrPriv.layer[i].u.run.pixmap.drawable,
                                   &rgnNew, pScrPriv.layer[i].key, i);
            RegionUninit(&rgnNew);
            /* remove piece from other fbs */
            RegionSubtract(&pScrPriv.layer[i].u.run.region,
                           &pScrPriv.layer[i].u.run.region, prgn);
        }
    }
}

/*
 * Copy only areas in each layer containing real bits
 */
private void fbOverlayCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    FbOverlayScrPrivPtr pScrPriv = mixin(fbOverlayGetScrPriv!("pScreen"));
    RegionRec rgnDst = void;
    int dx = void, dy = void;
    int i = void;
    RegionRec[FB_OVERLAY_MAX] layerRgn = void;
    PixmapPtr pPixmap = void;

    dx = ptOldOrg.x - pWin.drawable.x;
    dy = ptOldOrg.y - pWin.drawable.y;

    /*
     * Clip to existing bits
     */
    RegionTranslate(prgnSrc, -dx, -dy);
    RegionNull(&rgnDst);
    RegionIntersect(&rgnDst, &pWin.borderClip, prgnSrc);
    RegionTranslate(&rgnDst, dx, dy);
    /*
     * Compute the portion of each fb affected by this copy
     */
    assert(pScrPriv.nlayers <= FB_OVERLAY_MAX);
    for (i = 0; i < pScrPriv.nlayers; i++) {
        RegionNull(&layerRgn[i]);
        RegionIntersect(&layerRgn[i], &rgnDst,
                        &pScrPriv.layer[i].u.run.region);
        if (RegionNotEmpty(&layerRgn[i])) {
            RegionTranslate(&layerRgn[i], -dx, -dy);
            pPixmap = pScrPriv.layer[i].u.run.pixmap;
            miCopyRegion(&pPixmap.drawable, &pPixmap.drawable,
                         null,
                         &layerRgn[i], dx, dy, pScrPriv.CopyWindow, 0,
                         cast(void*) cast(c_long) i);
        }
    }
    /*
     * Update regions
     */
    for (i = 0; i < pScrPriv.nlayers; i++) {
        if (RegionNotEmpty(&layerRgn[i]))
            fbOverlayUpdateLayerRegion(pScreen, i, &layerRgn[i]);

        RegionUninit(&layerRgn[i]);
    }
    RegionUninit(&rgnDst);
}

private void fbOverlayWindowExposures(WindowPtr pWin, RegionPtr prgn)
{
    fbOverlayUpdateLayerRegion(pWin.drawable.pScreen,
                               fbOverlayWindowLayer(pWin), prgn);
    miWindowExposures(pWin, prgn);
}

Bool fbOverlayFinishScreenInit(ScreenPtr pScreen, void* pbits1, void* pbits2, int xsize, int ysize, int dpix, int dpiy, int width1, int width2, int bpp1, int bpp2, int depth1, int depth2)
{
    VisualPtr visuals = void;
    DepthPtr depths = void;
    int nvisuals = void;
    int ndepths = void;
    VisualID defaultVisual = void;

    if (!dixRegisterPrivateKey
        (&fbOverlayScreenPrivateKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (bpp1 == 24 || bpp2 == 24)
        return FALSE;

    FbOverlayScrPrivPtr pScrPriv = cast(FbOverlayScrPrivRec*) calloc(1, FbOverlayScrPrivRec.sizeof);
    if (!pScrPriv)
        return FALSE;

    if (!fbInitVisuals(&visuals, &depths, &nvisuals, &ndepths, &depth1,
                       &defaultVisual, (cast(c_ulong) 1 << (bpp1 - 1)) |
                       (cast(c_ulong) 1 << (bpp2 - 1)), 8)) {
        free(pScrPriv);
        return FALSE;
    }
    if (!miScreenInit(pScreen, null, xsize, ysize, dpix, dpiy, 0,
                      depth1, ndepths, depths,
                      defaultVisual, nvisuals, visuals)) {
        free(pScrPriv);
        return FALSE;
    }
    /* MI thinks there's no frame buffer */
static if(CONFIG_MITSHM){
    ShmRegisterFbFuncs(pScreen);
} /* CONFIG_MITSHM */
    pScreen.minInstalledCmaps = 1;
    pScreen.maxInstalledCmaps = 2;

    pScrPriv.nlayers = 2;
    pScrPriv.PaintKey = &fbOverlayPaintKey;
    pScrPriv.CopyWindow = &fbCopyWindowProc;
    pScrPriv.layer[0].u.init.pbits = pbits1;
    pScrPriv.layer[0].u.init.width = width1;
    pScrPriv.layer[0].u.init.depth = depth1;

    pScrPriv.layer[1].u.init.pbits = pbits2;
    pScrPriv.layer[1].u.init.width = width2;
    pScrPriv.layer[1].u.init.depth = depth2;
    dixSetPrivate(&pScreen.devPrivates, fbOverlayScreenPrivateKey, pScrPriv);

    /* overwrite miCloseScreen with our own */
    pScreen.CloseScreen = &fbOverlayCloseScreen;
    pScreen.CreateScreenResources = &fbOverlayCreateScreenResources;
    pScreen.CreateWindow = &fbOverlayCreateWindow;
    pScreen.WindowExposures = &fbOverlayWindowExposures;
    pScreen.CopyWindow = &fbOverlayCopyWindow;

    return TRUE;
}
