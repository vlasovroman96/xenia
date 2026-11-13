module mi.miexpose;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/
/*****************************************************************

Copyright (c) 1991, 1997 Digital Equipment Corporation, Maynard, Massachusetts.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
DIGITAL EQUIPMENT CORPORATION BE LIABLE FOR ANY CLAIM, DAMAGES, INCLUDING,
BUT NOT LIMITED TO CONSEQUENTIAL OR INCIDENTAL DAMAGES, OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of Digital Equipment Corporation
shall not be used in advertising or otherwise to promote the sale, use or other
dealings in this Software without prior written authorization from Digital
Equipment Corporation.

******************************************************************/

import build.xlibre_server;
import Xext.panoramiXsrv;

//import x11.X;
//import x11.Xmd;
//import x11.Xproto;
//import x11.Xprotostr;
import region;

import dix.dix_priv;
import dix.screenint_priv;
import dix.window_priv;
import mi.mi_priv;
import Xext.panoramiX;
import Xext.panoramiXsrv;

import dix.scrnintstr;
import dix.pixmap;
import dix.input;
import dix.dixstruct_priv;
import dix.events;
import dix.gc;
import dix.window;

/*
    machine-independent graphics exposure code.  any device that uses
the region package can call this.
*/

enum RECTLIMIT = 25            /* pick a number, any number > 8 */;


/* miHandleExposures
    generate a region for exposures for areas that were copied from obscured or
non-existent areas to non-obscured areas of the destination.  Paint the
background for the region, if the destination is a window.

*/

RegionPtr miHandleExposures(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty)
{
    RegionPtr prgnSrcClip = void;      /* drawable-relative source clip */
    RegionRec rgnSrcRec = void;
    RegionPtr prgnDstClip = void;      /* drawable-relative dest clip */
    RegionRec rgnDstRec = void;
    BoxRec srcBox = void;              /* unclipped source */
    RegionRec rgnExposed = void;       /* exposed region, calculated source-
                                   relative, made dst relative to
                                   intersect with visible parts of
                                   dest and send events to client,
                                   and then screen relative to paint
                                   the window background
                                 */
    WindowPtr pSrcWin = void;
    BoxRec expBox = { 0, };
    Bool extents = void;

    /* avoid work if we can */
    if (!pGC.graphicsExposures && pDstDrawable.type == DRAWABLE_PIXMAP)
        return null;

    srcBox.x1 = cast(short)(srcx);
    srcBox.y1 = cast(short)(srcy);
    srcBox.x2 = cast(short)(srcx + width);
    srcBox.y2 = cast(short)(srcy + height);

    if (pSrcDrawable.type != DRAWABLE_PIXMAP) {
        BoxRec TsrcBox = void;

        TsrcBox.x1 = cast(short)(srcx + pSrcDrawable.x);
        TsrcBox.y1 = cast(short)(srcy + pSrcDrawable.y);
        TsrcBox.x2 = cast(short)(TsrcBox.x1 + width);
        TsrcBox.y2 = cast(short)(TsrcBox.y1 + height);
        pSrcWin = cast(WindowPtr) pSrcDrawable;
        if (pGC.subWindowMode == IncludeInferiors) {
            prgnSrcClip = NotClippedByChildren(pSrcWin);
            if ((RegionContainsRect(prgnSrcClip, &TsrcBox)) == rgnIN) {
                RegionDestroy(prgnSrcClip);
                return null;
            }
        }
        else {
            if ((RegionContainsRect(&pSrcWin.clipList, &TsrcBox)) == rgnIN)
                return null;
            prgnSrcClip = &rgnSrcRec;
            RegionNull(prgnSrcClip);
            RegionCopy(prgnSrcClip, &pSrcWin.clipList);
        }
        RegionTranslate(prgnSrcClip, -pSrcDrawable.x, -pSrcDrawable.y);
    }
    else {
        BoxRec box = void;

        if ((srcBox.x1 >= 0) && (srcBox.y1 >= 0) &&
            (srcBox.x2 <= pSrcDrawable.width) &&
            (srcBox.y2 <= pSrcDrawable.height))
            return null;

        box.x1 = 0;
        box.y1 = 0;
        box.x2 = pSrcDrawable.width;
        box.y2 = pSrcDrawable.height;
        prgnSrcClip = &rgnSrcRec;
        RegionInit(prgnSrcClip, &box, 1);
        pSrcWin = null;
    }

    if (pDstDrawable == pSrcDrawable) {
        prgnDstClip = prgnSrcClip;
    }
    else if (pDstDrawable.type != DRAWABLE_PIXMAP) {
        if (pGC.subWindowMode == IncludeInferiors) {
            prgnDstClip = NotClippedByChildren(cast(WindowPtr) pDstDrawable);
        }
        else {
            prgnDstClip = &rgnDstRec;
            RegionNull(prgnDstClip);
            RegionCopy(prgnDstClip, &(cast(WindowPtr) pDstDrawable).clipList);
        }
        RegionTranslate(prgnDstClip, -pDstDrawable.x, -pDstDrawable.y);
    }
    else {
        BoxRec box = void;

        box.x1 = 0;
        box.y1 = 0;
        box.x2 = pDstDrawable.width;
        box.y2 = pDstDrawable.height;
        prgnDstClip = &rgnDstRec;
        RegionInit(prgnDstClip, &box, 1);
    }

    /* drawable-relative source region */
    RegionInit(&rgnExposed, &srcBox, 1);

    /* now get the hidden parts of the source box */
    RegionSubtract(&rgnExposed, &rgnExposed, prgnSrcClip);

    /* move them over the destination */
    RegionTranslate(&rgnExposed, dstx - srcx, dsty - srcy);

    /* intersect with visible areas of dest */
    RegionIntersect(&rgnExposed, &rgnExposed, prgnDstClip);

    /* intersect with client clip region. */
    if (pGC.clientClip)
        RegionIntersect(&rgnExposed, &rgnExposed, pGC.clientClip);

    /*
     * If we have LOTS of rectangles, we decide to take the extents
     * and force an exposure on that.  This should require much less
     * work overall, on both client and server.  This is cheating, but
     * isn't prohibited by the protocol ("spontaneous combustion" :-)
     * for windows.
     */
    extents = pGC.graphicsExposures &&
        (RegionNumRects(&rgnExposed) > RECTLIMIT) &&
        (pDstDrawable.type != DRAWABLE_PIXMAP);
    if (pSrcWin) {
        RegionPtr region = void;

        if (((region = mixin(wClipShape!("pSrcWin"))) is null))
            region = mixin(wBoundingShape!("pSrcWin"));
        /*
         * If you try to CopyArea the extents of a shaped window, compacting the
         * exposed region will undo all our work!
         */
        if (extents && pSrcWin && region &&
            (RegionContainsRect(region, &srcBox) != rgnIN))
            extents = FALSE;
    }
    if (extents) {
        expBox = *RegionExtents(&rgnExposed);
        RegionReset(&rgnExposed, &expBox);
    }
    if ((pDstDrawable.type != DRAWABLE_PIXMAP) &&
        ((cast(WindowPtr) pDstDrawable).backgroundState != None)) {
        WindowPtr pWin = cast(WindowPtr) pDstDrawable;

        /* make the exposed area screen-relative */
        RegionTranslate(&rgnExposed, pDstDrawable.x, pDstDrawable.y);

        if (extents) {
            /* PaintWindow doesn't clip, so we have to */
            RegionIntersect(&rgnExposed, &rgnExposed, &pWin.clipList);
        }
        pDstDrawable.pScreen.PaintWindow(cast(WindowPtr) pDstDrawable,
                                           &rgnExposed, PW_BACKGROUND);

        if (extents) {
            RegionReset(&rgnExposed, &expBox);
        }
        else
            RegionTranslate(&rgnExposed, -pDstDrawable.x, -pDstDrawable.y);
    }
    if (prgnDstClip == &rgnDstRec) {
        RegionUninit(prgnDstClip);
    }
    else if (prgnDstClip != prgnSrcClip) {
        RegionDestroy(prgnDstClip);
    }

    if (prgnSrcClip == &rgnSrcRec) {
        RegionUninit(prgnSrcClip);
    }
    else {
        RegionDestroy(prgnSrcClip);
    }

    if (pGC.graphicsExposures) {
        /* don't look */
        RegionPtr exposed = RegionCreate(NullBox, 0);

        *exposed = rgnExposed;
        return exposed;
    }
    else {
        RegionUninit(&rgnExposed);
        return null;
    }
}

void miSendExposures(WindowPtr pWin, RegionPtr pRgn, int dx, int dy)
{
    BoxPtr pBox = void;
    int numRects = void;
    xEvent* pEvent = void, pe = void;
    int i = void;

    pBox = RegionRects(pRgn);
    numRects = RegionNumRects(pRgn);
    if (((pEvent = cast(xEvent*) calloc(1, numRects * xEvent.sizeof)) is null))
        return;

    for (i = numRects, pe = pEvent; --i >= 0; pe++, pBox++) {
        pe.u.u.type = Expose;
        pe.u.expose.window = cast(uint)pWin.drawable.id;
        pe.u.expose.x = cast(ushort)(pBox.x1 - dx);
        pe.u.expose.y = cast(ushort)(pBox.y1 - dy);
        pe.u.expose.width = cast(ushort)(pBox.x2 - pBox.x1);
        pe.u.expose.height = cast(ushort)(pBox.y2 - pBox.y1);
        pe.u.expose.count = cast(ushort)i;
    }

static if(XINERAMA){
    if (!noPanoramiXExtension) {
        int scrnum = pWin.drawable.pScreen.myNum;
        int x = 0, y = 0;
        XID realWin = 0;

        if (!pWin.parent) {
            x = screenInfo.screens[scrnum].x;
            y = screenInfo.screens[scrnum].y;
            pWin = dixGetMasterScreen().root;
            realWin = pWin.drawable.id;
        }
        else if (scrnum) {
            PanoramiXRes* win = void;

            win = PanoramiXFindIDByScrnum(XRT_WINDOW,
                                          pWin.drawable.id, scrnum);
            if (!win) {
                free(pEvent);
                return;
            }
            realWin = win.info[0].id;
            dixLookupWindow(&pWin, realWin, serverClient, DixSendAccess);
        }
        if (x || y || scrnum)
            for (i = 0; i < numRects; i++) {
                pEvent[i].u.expose.window = realWin;
                pEvent[i].u.expose.x += x;
                pEvent[i].u.expose.y += y;
            }
    }
} /* XINERAMA */

    DeliverEvents(pWin, pEvent, numRects, NullWindow);

    free(pEvent);
}

void miWindowExposures(WindowPtr pWin, RegionPtr prgn)
{
    RegionPtr exposures = prgn;

    if (prgn && !RegionNil(prgn)) {
        RegionRec expRec = void;
        int clientInterested = cast(int)((pWin.eventMask | mixin(wOtherEventMasks!("pWin"))) & ExposureMask);
        if (clientInterested && (RegionNumRects(prgn) > RECTLIMIT)) {
            /*
             * If we have LOTS of rectangles, we decide to take the extents
             * and force an exposure on that.  This should require much less
             * work overall, on both client and server.  This is cheating, but
             * isn't prohibited by the protocol ("spontaneous combustion" :-).
             */
            BoxRec box = *RegionExtents(prgn);
            exposures = &expRec;
            RegionInit(exposures, &box, 1);
            RegionReset(prgn, &box);
            /* miPaintWindow doesn't clip, so we have to */
            RegionIntersect(prgn, prgn, &pWin.clipList);
        }
        pWin.drawable.pScreen.PaintWindow(pWin, prgn, PW_BACKGROUND);
        if (clientInterested)
            miSendExposures(pWin, exposures,
                            pWin.drawable.x, pWin.drawable.y);
        if (exposures == &expRec)
            RegionUninit(exposures);
        RegionEmpty(prgn);
    }
}

void miPaintWindow(WindowPtr pWin, RegionPtr prgn, int what)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    ChangeGCVal[6] gcval = void;
    BITS32 gcmask = void;
    GCPtr pGC = void;
    int i = void;
    BoxPtr pbox = void;
    xRectangle* prect = void;
    int numRects = void, regionnumrects = void;

    /*
     * Distance from screen to destination drawable, use this
     * to adjust rendering coordinates which come in in screen space
     */
    int draw_x_off = void, draw_y_off = void;

    /*
     * Tile offset for drawing; these need to align the tile
     * to the appropriate window origin
     */
    int tile_x_off = void, tile_y_off = void;
    PixUnion fill = void;
    Bool solid = TRUE;
    DrawablePtr drawable = &pWin.drawable;

    if (what == PW_BACKGROUND) {
        while (pWin.backgroundState == ParentRelative)
            pWin = pWin.parent;

        draw_x_off = drawable.x;
        draw_y_off = drawable.y;

        tile_x_off = pWin.drawable.x - draw_x_off;
        tile_y_off = pWin.drawable.y - draw_y_off;
        fill = pWin.background;
        if (pWin.inhibitBGPaint)
            return;
        switch (pWin.backgroundState) {
        case None:
            return;
        case BackgroundPixmap:
            solid = FALSE;
            break;
        default: break;}
    }
    else {
        PixmapPtr pixmap = void;

        fill = pWin.border;
        solid = pWin.borderIsPixel;

        /* servers without pixmaps draw their own borders */
        if (!pScreen.GetWindowPixmap)
            return;
        pixmap = (*pScreen.GetWindowPixmap) (cast(WindowPtr) drawable);
        drawable = &pixmap.drawable;

        while (pWin.backgroundState == ParentRelative)
            pWin = pWin.parent;

        tile_x_off = pWin.drawable.x;
        tile_y_off = pWin.drawable.y;

        draw_x_off = pixmap.screen_x;
        draw_y_off = pixmap.screen_y;
        tile_x_off -= draw_x_off;
        tile_y_off -= draw_y_off;
    }

    gcval[0].val = GXcopy;
    gcmask = cast(uint)GCFunction;

version (ROOTLESS_SAFEALPHA) {
/* Bit mask for alpha channel with a particular number of bits per
 * pixel. Note that we only care for 32bpp data. Mac OS X uses planar
 * alpha for 16bpp.
 */
enum string RootlessAlphaMask(string bpp) = `((` ~ bpp ~ `) == 32 ? 0xFF000000 : 0)`;
}

    if (solid) {
version (ROOTLESS_SAFEALPHA) {
        gcval[1].val =
            fill.pixel | mixin(RootlessAlphaMask!(`pWin.drawable.bitsPerPixel`));
} else {
        /* Make sure alpha will sample as 1.0 for opaque windows */
        if (drawable.depth == 32) {
            WindowPtr orig_pWin = pWin;
            int effective_depth = orig_pWin.drawable.depth;

            if (effective_depth == 32) {
                orig_pWin = orig_pWin.parent;
                while (orig_pWin && orig_pWin.parent) {
                    if (orig_pWin.drawable.depth == 24) {
                        effective_depth = 24;
                        break;
                    }

                    orig_pWin = orig_pWin.parent;
                }
            }

            if (effective_depth == 24)
                fill.pixel |= 0xff000000;
        }
        gcval[1].val = cast(uint)fill.pixel;
}
        gcval[2].val = cast(uint)FillSolid;
        gcmask |= GCForeground | GCFillStyle;
    }
    else {
        int c = 1;

version (ROOTLESS_SAFEALPHA) {
        gcval[c++].val =
            ((CARD32) -1) & ~mixin(RootlessAlphaMask!(`pWin.drawable.bitsPerPixel`));
        gcmask |= GCPlaneMask;
}
        gcval[c++].val = FillTiled;
        gcval[c++].ptr = cast(void*) fill.pixmap;
        gcval[c++].val = tile_x_off;
        gcval[c++].val = tile_y_off;
        gcmask |= GCFillStyle | GCTile | GCTileStipXOrigin | GCTileStipYOrigin;
    }

    regionnumrects = RegionNumRects(prgn);
    if (regionnumrects == 0)
        return;
    prect = cast(xRectangle*)calloc(regionnumrects, xRectangle.sizeof);
    if (!prect)
        return;

    pGC = GetScratchGC(drawable.depth, drawable.pScreen);
    if (!pGC) {
        free(prect);
        return;
    }

    ChangeGC(null, pGC, gcmask, gcval.ptr);
    ValidateGC(drawable, pGC);

    numRects = RegionNumRects(prgn);
    pbox = RegionRects(prgn);
    for (i = numRects; --i >= 0; pbox++, prect++) {
        prect.x = cast(short)(pbox.x1 - draw_x_off);
        prect.y = cast(short)(pbox.y1 - draw_y_off);
        prect.width = cast(ushort)(pbox.x2 - pbox.x1);
        prect.height = cast(ushort)(pbox.y2 - pbox.y1);
    }
    prect -= numRects;
    (*pGC.ops.PolyFillRect) (drawable, pGC, numRects, prect);
    free(prect);

    FreeScratchGC(pGC);
}

/* MICLEARDRAWABLE -- sets the entire drawable to the background color of
 * the GC.  Useful when we have a scratch drawable and need to initialize
 * it. */
void miClearDrawable(DrawablePtr pDraw, GCPtr pGC)
{
    ChangeGCVal fg = void, bg = void;
    xRectangle rect = void;

    fg.val = pGC.fgPixel;
    bg.val = pGC.bgPixel;
    rect.x = 0;
    rect.y = 0;
    rect.width = pDraw.width;
    rect.height = pDraw.height;
    ChangeGC(null, pGC, cast(uint)GCForeground, &bg);
    ValidateGC(pDraw, pGC);
    (*pGC.ops.PolyFillRect) (pDraw, pGC, 1, &rect);
    ChangeGC(null, pGC,cast(uint) GCForeground, &fg);
    ValidateGC(pDraw, pGC);
}
