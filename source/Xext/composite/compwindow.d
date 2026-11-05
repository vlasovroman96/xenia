module composite.compwindow;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2006, Oracle and/or its affiliates.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Copyright © 2003 Keith Packard
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

import dix.dix_priv;
import dix.resource_priv;
import dix.screensaver_priv;
import dix.window_priv;
import os.osdep;
import Xext.panoramiXsrv;

import composite.compint;
import composite.compositeext_priv;
import composite.compwindow;
import externs.X11.extensions.composite_;
import externs.X11.extensions.render_;
import dix.resource;
import miext.damage.damage_;
import dix.gc;
import render.picture;
import dix.dixutils;
import dix.window;
import include.picture;

// version (COMPOSITE_DEBUG) {
// private int compCheckWindow(WindowPtr pWin, void* data)
// {
//     ScreenPtr pScreen = pWin.drawable.pScreen;
//     PixmapPtr pWinPixmap = (*pScreen.GetWindowPixmap) (pWin);
//     PixmapPtr pParentPixmap = pWin.parent ? (*pScreen.GetWindowPixmap) (pWin.parent) : null;
//     PixmapPtr pScreenPixmap = (*pScreen.GetScreenPixmap) (pScreen);

//     if (!pWin.parent) {
//         assert(pWin.redirectDraw == RedirectDrawNone);
//         assert(pWinPixmap == pScreenPixmap);
//     }
//     else if (pWin.redirectDraw != RedirectDrawNone) {
//         assert(pWinPixmap != pParentPixmap);
//         assert(pWinPixmap != pScreenPixmap);
//     }
//     else {
//         assert(pWinPixmap == pParentPixmap);
//     }

//     assert(0 < pWinPixmap.refcnt);
//     assert(pWinPixmap.refcnt < 3);

//     assert(0 < pScreenPixmap.refcnt);
//     assert(pScreenPixmap.refcnt < 3);

//     if (pParentPixmap) {
//         assert(0 <= pParentPixmap.refcnt);
//         assert(pParentPixmap.refcnt < 3);
//     }
//     return WT_WALKCHILDREN;
// }

// void compCheckTree(ScreenPtr pScreen)
// {
//     WalkTree(pScreen, &compCheckWindow, null);
// }
// }

struct _compPixmapVisit {
    WindowPtr pWindow;
    PixmapPtr pPixmap;
    int bw;
}alias CompPixmapVisitRec = _compPixmapVisit;
alias CompPixmapVisitPtr = _compPixmapVisit*;

private Bool compRepaintBorder(ClientPtr pClient, void* closure)
{
    WindowPtr pWindow = void;
    int rc = dixLookupWindow(&pWindow, cast(XID) cast(intptr_t) closure, pClient,
                        DixWriteAccess);

    if (rc == Success) {
        RegionRec exposed = void;

        RegionNull(&exposed);
        RegionSubtract(&exposed, &pWindow.borderClip, &pWindow.winSize);
        pWindow.drawable.pScreen.PaintWindow(pWindow, &exposed, PW_BORDER);
        RegionUninit(&exposed);
    }
    return TRUE;
}

private int compSetPixmapVisitWindow(WindowPtr pWindow, void* data)
{
    CompPixmapVisitPtr pVisit = cast(CompPixmapVisitPtr) data;
    ScreenPtr pScreen = pWindow.drawable.pScreen;

    if (pWindow != pVisit.pWindow && pWindow.redirectDraw != RedirectDrawNone)
        return WT_DONTWALKCHILDREN;
    (*pScreen.SetWindowPixmap) (pWindow, pVisit.pPixmap);
    /*
     * Recompute winSize and borderSize.  This is duplicate effort
     * when resizing pixmaps, but necessary when changing redirection.
     * Might be nice to fix this.
     */
    SetWinSize(pWindow);
    SetBorderSize(pWindow);
    if (pVisit.bw)
        QueueWorkProc(&compRepaintBorder, serverClient,
                      cast(void*) cast(intptr_t) pWindow.drawable.id);
    return WT_WALKCHILDREN;
}

void compSetPixmap(WindowPtr pWindow, PixmapPtr pPixmap, int bw)
{
    CompPixmapVisitRec visitRec = void;

    visitRec.pWindow = pWindow;
    visitRec.pPixmap = pPixmap;
    visitRec.bw = bw;
    TraverseTree(pWindow, &compSetPixmapVisitWindow, cast(void*) &visitRec);
    //compCheckTree(pWindow.drawable.pScreen);
}

Bool compCheckRedirect(WindowPtr pWin)
{
    CompWindowPtr cw = mixin(GetCompWindow!("pWin"));
    CompScreenPtr cs = mixin(GetCompScreen!("pWin.drawable.pScreen"));
    Bool should = void;

    should = pWin.realized && (pWin.drawable.class_ != InputOnly) &&
        (cw !is null) && (pWin.parent !is null);

    /* Never redirect the overlay window */
    if (cs.pOverlayWin !is null) {
        if (pWin == cs.pOverlayWin) {
            should = FALSE;
        }
    }

    if (should != (pWin.redirectDraw != RedirectDrawNone)) {
        if (should)
            return compAllocPixmap(pWin);
        else {
            ScreenPtr pScreen = pWin.drawable.pScreen;
            PixmapPtr pPixmap = (*pScreen.GetWindowPixmap) (pWin);

            compSetParentPixmap(pWin);
            compRestoreWindow(pWin, pPixmap);
            dixDestroyPixmap(pPixmap, 0);
        }
    }
    else if (should) {
        if (cw.update == CompositeRedirectAutomatic)
            pWin.redirectDraw = RedirectDrawAutomatic;
        else
            pWin.redirectDraw = RedirectDrawManual;
    }
    return TRUE;
}

private int updateOverlayWindow(ScreenPtr pScreen)
{
    CompScreenPtr cs = void;
    WindowPtr pWin = void;             /* overlay window */
    XID[2] vlist = void;
    int w = pScreen.width;
    int h = pScreen.height;

static if(XINERAMA){
    if (!noPanoramiXExtension) {
        w = PanoramiXPixWidth;
        h = PanoramiXPixHeight;
    }
} /* XINERAMA */

    cs = mixin(GetCompScreen!("pScreen"));
    if ((pWin = cs.pOverlayWin) !is null) {
        if ((pWin.drawable.width == w) && (pWin.drawable.height == h))
            return Success;

        /* Let's resize the overlay window. */
        vlist[0] = w;
        vlist[1] = h;
        return ConfigureWindow(pWin, CWWidth | CWHeight, vlist.ptr, dixClientForWindow(pWin));
    }

    /* Let's be on the safe side and not assume an overlay window is
       always allocated. */
    return Success;
}

void compWindowPosition(CallbackListPtr* pcbl, ScreenPtr pScreen, XorgScreenWindowPositionParamRec* param)
{
    WindowPtr pWin = param.window;
    /*
     * "Shouldn't need this as all possible places should be wrapped
     *
     compCheckRedirect (pWin);
     */
version (COMPOSITE_DEBUG) {
    if ((pWin.redirectDraw != RedirectDrawNone) !=
        (pWin.viewable && (mixin(GetCompWindow!("pWin") !is null))))
        OsAbort();
}
    if (pWin.redirectDraw != RedirectDrawNone) {
        PixmapPtr pPixmap = (*pScreen.GetWindowPixmap) (pWin);
        int bw = mixin(wBorderWidth!("pWin"));
        int nx = pWin.drawable.x - bw;
        int ny = pWin.drawable.y - bw;

        if (pPixmap.screen_x != nx || pPixmap.screen_y != ny) {
            pPixmap.screen_x = cast(short)nx;
            pPixmap.screen_y = cast(short)ny;
            pPixmap.drawable.serialNumber = NEXT_SERIAL_NUMBER;
        }
    }

    //compCheckTree(pWin.drawable.pScreen);
    updateOverlayWindow(pScreen);
}

Bool compRealizeWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    Bool ret = TRUE;

    pScreen.RealizeWindow = cs.RealizeWindow;
    compCheckRedirect(pWin);
    if (!(*pScreen.RealizeWindow) (pWin))
        ret = FALSE;
    cs.RealizeWindow = pScreen.RealizeWindow;
    pScreen.RealizeWindow = &compRealizeWindow;
    //compCheckTree(pWin.drawable.pScreen);
    return ret;
}

Bool compUnrealizeWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    Bool ret = TRUE;

    pScreen.UnrealizeWindow = cs.UnrealizeWindow;
    compCheckRedirect(pWin);
    if (!(*pScreen.UnrealizeWindow) (pWin))
        ret = FALSE;
    cs.UnrealizeWindow = pScreen.UnrealizeWindow;
    pScreen.UnrealizeWindow = &compUnrealizeWindow;
    //compCheckTree(pWin.drawable.pScreen);
    return ret;
}

/*
 * Called after the borderClip for the window has settled down
 * We use this to make sure our extra borderClip has the right origin
 */

void compClipNotify(WindowPtr pWin, int dx, int dy)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    CompWindowPtr cw = mixin(GetCompWindow!("pWin"));

    if (cw) {
        if (cw.borderClipX != pWin.drawable.x ||
            cw.borderClipY != pWin.drawable.y) {
            RegionTranslate(&cw.borderClip,
                            pWin.drawable.x - cw.borderClipX,
                            pWin.drawable.y - cw.borderClipY);
            cw.borderClipX = pWin.drawable.x;
            cw.borderClipY = pWin.drawable.y;
        }
    }
    if (cs.ClipNotify) {
        pScreen.ClipNotify = cs.ClipNotify;
        (*pScreen.ClipNotify) (pWin, dx, dy);
        cs.ClipNotify = pScreen.ClipNotify;
        pScreen.ClipNotify = &compClipNotify;
    }
}

Bool compIsAlternateVisual(ScreenPtr pScreen, XID visual)
{
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    for (int i = 0; cs && i < cs.numAlternateVisuals; i++)
        if (cs.alternateVisuals[i] == visual)
            return TRUE;
    return FALSE;
}

Bool CompositeIsImplicitRedirectException(ScreenPtr pScreen, XID parentVisual, XID winVisual)
{
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    for (int i = 0; i < cs.numImplicitRedirectExceptions; i++)
        if (cs.implicitRedirectExceptions[i].parentVisual == parentVisual &&
            cs.implicitRedirectExceptions[i].winVisual == winVisual)
            return TRUE;

    return FALSE;
}

private Bool compImplicitRedirect(WindowPtr pWin, WindowPtr pParent)
{
    if (pParent) {
        ScreenPtr pScreen = pWin.drawable.pScreen;
        XID winVisual = mixin(wVisual!("pWin"));
        XID parentVisual = mixin(wVisual!("pParent"));

        if (CompositeIsImplicitRedirectException(pScreen, parentVisual, winVisual))
            return FALSE;

        if (winVisual != parentVisual &&
            (compIsAlternateVisual(pScreen, winVisual) ||
             compIsAlternateVisual(pScreen, parentVisual)))
            return TRUE;
    }
    return FALSE;
}

private void compFreeOldPixmap(WindowPtr pWin)
{
    if (pWin.redirectDraw != RedirectDrawNone) {
        CompWindowPtr cw = mixin(GetCompWindow!("pWin"));

        if (cw.pOldPixmap) {
            dixDestroyPixmap(cw.pOldPixmap, 0);
            cw.pOldPixmap = NullPixmap;
        }
    }
}

void compMoveWindow(WindowPtr pWin, int x, int y, WindowPtr pSib, VTKind kind)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    pScreen.MoveWindow = cs.MoveWindow;
    (*pScreen.MoveWindow) (pWin, x, y, pSib, kind);
    cs.MoveWindow = pScreen.MoveWindow;
    pScreen.MoveWindow = &compMoveWindow;

    compFreeOldPixmap(pWin);
    //compCheckTree(pScreen);
}

void compResizeWindow(WindowPtr pWin, int x, int y, uint w, uint h, WindowPtr pSib)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    pScreen.ResizeWindow = cs.ResizeWindow;
    (*pScreen.ResizeWindow) (pWin, x, y, w, h, pSib);
    cs.ResizeWindow = pScreen.ResizeWindow;
    pScreen.ResizeWindow = &compResizeWindow;

    compFreeOldPixmap(pWin);
    //compCheckTree(pWin.drawable.pScreen);
}

void compChangeBorderWidth(WindowPtr pWin, uint bw)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    pScreen.ChangeBorderWidth = cs.ChangeBorderWidth;
    (*pScreen.ChangeBorderWidth) (pWin, bw);
    cs.ChangeBorderWidth = pScreen.ChangeBorderWidth;
    pScreen.ChangeBorderWidth = &compChangeBorderWidth;

    compFreeOldPixmap(pWin);
    //compCheckTree(pWin.drawable.pScreen);
}

void compReparentWindow(WindowPtr pWin, WindowPtr pPriorParent)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    CompWindowPtr cw = void;

    pScreen.ReparentWindow = cs.ReparentWindow;
    /*
     * Remove any implicit redirect due to synthesized visual
     */
    if (compImplicitRedirect(pWin, pPriorParent))
        compUnredirectWindow(serverClient, pWin, CompositeRedirectAutomatic);
    /*
     * Handle subwindows redirection
     */
    compUnredirectOneSubwindow(pPriorParent, pWin);
    compRedirectOneSubwindow(pWin.parent, pWin);
    /*
     * Add any implicit redirect due to synthesized visual
     */
    if (compImplicitRedirect(pWin, pWin.parent))
        compRedirectWindow(serverClient, pWin, CompositeRedirectAutomatic);

    /*
     * Allocate any necessary redirect pixmap
     * (this actually should never be true; pWin is always unmapped)
     */
    compCheckRedirect(pWin);

    /*
     * Reset pixmap pointers as appropriate
     */
    if (pWin.parent && pWin.redirectDraw == RedirectDrawNone)
        compSetPixmap(pWin, (*pScreen.GetWindowPixmap) (pWin.parent),
                      pWin.borderWidth);
    /*
     * Call down to next function
     */
    if (pScreen.ReparentWindow)
        (*pScreen.ReparentWindow) (pWin, pPriorParent);
    cs.ReparentWindow = pScreen.ReparentWindow;
    pScreen.ReparentWindow = &compReparentWindow;

    cw = mixin(GetCompWindow!("pWin"));
    if (pWin.damagedDescendants || (cw && cw.damaged))
        compMarkAncestors(pWin);

    //compCheckTree(pWin.drawable.pScreen);
}

void compCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    int dx = 0, dy = 0;

    if (pWin.redirectDraw != RedirectDrawNone) {
        PixmapPtr pPixmap = (*pScreen.GetWindowPixmap) (pWin);
        CompWindowPtr cw = mixin(GetCompWindow!("pWin"));

        assert(cw.oldx != COMP_ORIGIN_INVALID);
        assert(cw.oldy != COMP_ORIGIN_INVALID);
        if (cw.pOldPixmap) {
            /*
             * Ok, the old bits are available in pOldPixmap and
             * need to be copied to pNewPixmap.
             */
            RegionRec rgnDst = void;
            GCPtr pGC = void;

            dx = ptOldOrg.x - pWin.drawable.x;
            dy = ptOldOrg.y - pWin.drawable.y;
            RegionTranslate(prgnSrc, -dx, -dy);

            RegionNull(&rgnDst);

            RegionIntersect(&rgnDst, &pWin.borderClip, prgnSrc);

            RegionTranslate(&rgnDst, -pPixmap.screen_x, -pPixmap.screen_y);

            dx = dx + pPixmap.screen_x - cw.oldx;
            dy = dy + pPixmap.screen_y - cw.oldy;
            pGC = GetScratchGC(pPixmap.drawable.depth, pScreen);
            if (pGC) {
                BoxPtr pBox = RegionRects(&rgnDst);
                int nBox = RegionNumRects(&rgnDst);

                ValidateGC(&pPixmap.drawable, pGC);
                while (nBox--) {
                    cast(void) (*pGC.ops.CopyArea) (&cw.pOldPixmap.drawable,
                                                  &pPixmap.drawable,
                                                  pGC,
                                                  pBox.x1 + dx, pBox.y1 + dy,
                                                  pBox.x2 - pBox.x1,
                                                  pBox.y2 - pBox.y1,
                                                  pBox.x1, pBox.y1);
                    pBox++;
                }
                FreeScratchGC(pGC);
            }
            RegionUninit(&rgnDst);
            return;
        }
        dx = pPixmap.screen_x - cw.oldx;
        dy = pPixmap.screen_y - cw.oldy;
        ptOldOrg.x += dx;
        ptOldOrg.y += dy;
    }

    pScreen.CopyWindow = cs.CopyWindow;
    if (ptOldOrg.x != pWin.drawable.x || ptOldOrg.y != pWin.drawable.y) {
        if (dx || dy)
            RegionTranslate(prgnSrc, dx, dy);
        (*pScreen.CopyWindow) (pWin, ptOldOrg, prgnSrc);
        if (dx || dy)
            RegionTranslate(prgnSrc, -dx, -dy);
    }
    else {
        ptOldOrg.x -= dx;
        ptOldOrg.y -= dy;
        RegionTranslate(prgnSrc,
                        pWin.drawable.x - ptOldOrg.x,
                        pWin.drawable.y - ptOldOrg.y);
        DamageDamageRegion(&pWin.drawable, prgnSrc);
    }
    cs.CopyWindow = pScreen.CopyWindow;
    pScreen.CopyWindow = &compCopyWindow;
    //compCheckTree(pWin.drawable.pScreen);
}

Bool compCreateWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    Bool ret = void;

    pScreen.CreateWindow = cs.CreateWindow;
    ret = (*pScreen.CreateWindow) (pWin);
    if (pWin.parent && ret) {
        CompSubwindowsPtr csw = mixin(GetCompSubwindows!("pWin.parent"));
        PixmapPtr parent_pixmap = (*pScreen.GetWindowPixmap)(pWin.parent);
        PixmapPtr window_pixmap = (*pScreen.GetWindowPixmap)(pWin);

        if (window_pixmap != parent_pixmap)
            (*pScreen.SetWindowPixmap) (pWin, parent_pixmap);
        if (csw)
            for (CompClientWindowPtr ccw = csw.clients; ccw; ccw = ccw.next)
                compRedirectWindow(dixClientForXID(ccw.id),
                                   pWin, ccw.update);
        if (compImplicitRedirect(pWin, pWin.parent))
            compRedirectWindow(serverClient, pWin, CompositeRedirectAutomatic);
    }
    cs.CreateWindow = pScreen.CreateWindow;
    pScreen.CreateWindow = &compCreateWindow;
    //compCheckTree(pWin.drawable.pScreen);
    return ret;
}

void compWindowDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, WindowPtr pWin)
{
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    CompWindowPtr cw = void;
    CompSubwindowsPtr csw = void;

    while ((cw = mixin(GetCompWindow!("pWin"))) !is null)
        FreeResource(cast(uint)cw.clients.id, X11_RESTYPE_NONE);
    while ((csw = mixin(GetCompSubwindows!("pWin")))!is null)
        FreeResource(cast(uint)csw.clients.id, X11_RESTYPE_NONE);

    if (pWin.redirectDraw != RedirectDrawNone) {
        PixmapPtr pPixmap = (*pScreen.GetWindowPixmap) (pWin);

        compSetParentPixmap(pWin);
        dixDestroyPixmap(pPixmap, 0);
    }

    /* Did we just destroy the overlay window? */
    if (pWin == cs.pOverlayWin)
        cs.pOverlayWin = null;

/*    compCheckTree (pWin->drawable.pScreen); can't check -- tree isn't good*/
}

void compSetRedirectBorderClip(WindowPtr pWin, RegionPtr pRegion)
{
    CompWindowPtr cw = mixin(GetCompWindow!("pWin"));
    RegionRec damage = void;

    RegionNull(&damage);
    /*
     * Align old border clip with new border clip
     */
    RegionTranslate(&cw.borderClip,
                    pWin.drawable.x - cw.borderClipX,
                    pWin.drawable.y - cw.borderClipY);
    /*
     * Compute newly visible portion of window for repaint
     */
    RegionSubtract(&damage, pRegion, &cw.borderClip);
    /*
     * Report that as damaged so it will be redrawn
     */
    DamageDamageRegion(&pWin.drawable, &damage);
    RegionUninit(&damage);
    /*
     * Save the new border clip region
     */
    RegionCopy(&cw.borderClip, pRegion);
    cw.borderClipX = pWin.drawable.x;
    cw.borderClipY = pWin.drawable.y;
}

RegionPtr compGetRedirectBorderClip(WindowPtr pWin)
{
    CompWindowPtr cw = mixin(GetCompWindow!("pWin"));

    return &cw.borderClip;
}

private void compWindowUpdateAutomatic(WindowPtr pWin)
{
    CompWindowPtr cw = mixin(GetCompWindow!("pWin"));
    ScreenPtr pScreen = pWin.drawable.pScreen;
    WindowPtr pParent = pWin.parent;
    PixmapPtr pSrcPixmap = (*pScreen.GetWindowPixmap) (pWin);
    PictFormatPtr pSrcFormat = PictureWindowFormat(pWin);
    PictFormatPtr pDstFormat = PictureWindowFormat(pWin.parent);
    int error = void;
    RegionPtr pRegion = DamageRegion(cw.damage);
    PicturePtr pSrcPicture = CreatePicture(0, &pSrcPixmap.drawable,
                                           pSrcFormat,
                                           0, null,
                                           serverClient,
                                           &error);
    XID subwindowMode = IncludeInferiors;
    PicturePtr pDstPicture = CreatePicture(0, &pParent.drawable,
                                           pDstFormat,
                                           CPSubwindowMode,
                                           &subwindowMode,
                                           serverClient,
                                           &error);

    /*
     * First move the region from window to screen coordinates
     */
    RegionTranslate(pRegion, pWin.drawable.x, pWin.drawable.y);

    /*
     * Clip against the "real" border clip
     */
    RegionIntersect(pRegion, pRegion, &cw.borderClip);

    /*
     * Now translate from screen to dest coordinates
     */
    RegionTranslate(pRegion, -pParent.drawable.x, -pParent.drawable.y);

    /*
     * Clip the picture
     */
    SetPictureClipRegion(pDstPicture, 0, 0, pRegion);

    /*
     * And paint
     */
    CompositePicture(PictOpSrc, pSrcPicture, null, pDstPicture,
                     0, 0,      /* src_x, src_y */
                     0, 0,      /* msk_x, msk_y */
                     cast(short)(pSrcPixmap.screen_x - pParent.drawable.x),
                     cast(short)(pSrcPixmap.screen_y - pParent.drawable.y),
                     cast(ushort)pSrcPixmap.drawable.width, cast(ushort)pSrcPixmap.drawable.height);
    FreePicture(pSrcPicture, 0);
    FreePicture(pDstPicture, 0);
    /*
     * Empty the damage region.  This has the nice effect of
     * rendering the translations above harmless
     */
    DamageEmpty(cw.damage);
}

private void compPaintWindowToParent(WindowPtr pWin)
{
    compPaintChildrenToWindow(pWin);

    if (pWin.redirectDraw != RedirectDrawNone) {
        CompWindowPtr cw = mixin(GetCompWindow!("pWin"));

        if (cw.damaged) {
            compWindowUpdateAutomatic(pWin);
            cw.damaged = FALSE;
        }
    }
}

void compPaintChildrenToWindow(WindowPtr pWin)
{
    if (!pWin.damagedDescendants)
        return;

    for (WindowPtr pChild = pWin.lastChild; pChild; pChild = pChild.prevSib)
        compPaintWindowToParent(pChild);

    pWin.damagedDescendants = FALSE;
}

WindowPtr CompositeRealChildHead(WindowPtr pWin)
{
    WindowPtr pChild = void, pChildBefore = void;
    CompScreenPtr cs = void;

    if (!pWin.parent &&
        (screenIsSaved == SCREEN_SAVER_ON) &&
        (HasSaverWindow(pWin.drawable.pScreen))) {

        /* First child is the screen saver; see if next child is the overlay */
        pChildBefore = pWin.firstChild;
        pChild = pChildBefore.nextSib;

    }
    else {
        pChildBefore = NullWindow;
        pChild = pWin.firstChild;
    }

    if (!pChild) {
        return NullWindow;
    }

    cs = mixin(GetCompScreen!("pWin.drawable.pScreen"));
    if (pChild == cs.pOverlayWin) {
        return pChild;
    }
    else {
        return pChildBefore;
    }
}

int compConfigNotify(WindowPtr pWin, int x, int y, int w, int h, int bw, WindowPtr pSib)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    Bool ret = 0;
    WindowPtr pParent = pWin.parent;
    int draw_x = void, draw_y = void;
    Bool alloc_ret = void;

    if (cs.ConfigNotify) {
        pScreen.ConfigNotify = cs.ConfigNotify;
        ret = (*pScreen.ConfigNotify) (pWin, x, y, w, h, bw, pSib);
        cs.ConfigNotify = pScreen.ConfigNotify;
        pScreen.ConfigNotify = &compConfigNotify;

        if (ret)
            return ret;
    }

    if (pWin.redirectDraw == RedirectDrawNone)
        return Success;

    //compCheckTree(pScreen);

    draw_x = pParent.drawable.x + x + bw;
    draw_y = pParent.drawable.y + y + bw;
    alloc_ret = compReallocPixmap(pWin, draw_x, draw_y, w, h, bw);

    if (alloc_ret == FALSE)
        return BadAlloc;
    return Success;
}
