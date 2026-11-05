module exa_unaccel;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright © 1999 Keith Packard
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
import build.dix_config;

import mi.mipict;

import exa.exa_priv;
import exa.exa;
import render.mipict;
import os.log;
import render.picture;
import dix.picture;
import render.glyph;

/*
 * These functions wrap the low-level fb rendering functions and
 * synchronize framebuffer/accelerated drawing by stalling until
 * the accelerator is idle
 */

/**
 * Calls exaPrepareAccess with EXA_PREPARE_SRC for the tile, if that is the
 * current fill style.
 *
 * Solid doesn't use an extra pixmap source, and Stippled/OpaqueStippled are
 * 1bpp and never in fb, so we don't worry about them.
 * We should worry about them for completeness sake and going forward.
 */
void exaPrepareAccessGC(GCPtr pGC)
{
    if (pGC.stipple)
        exaPrepareAccess(&pGC.stipple.drawable, EXA_PREPARE_MASK);
    if (pGC.fillStyle == FillTiled)
        exaPrepareAccess(&pGC.tile.pixmap.drawable, EXA_PREPARE_SRC);
}

/**
 * Finishes access to the tile in the GC, if used.
 */
void exaFinishAccessGC(GCPtr pGC)
{
    if (pGC.fillStyle == FillTiled)
        exaFinishAccess(&pGC.tile.pixmap.drawable, EXA_PREPARE_SRC);
    if (pGC.stipple)
        exaFinishAccess(&pGC.stipple.drawable, EXA_PREPARE_MASK);
}

static if (DEBUG_TRACE_FALL) {
char exaDrawableLocation(DrawablePtr pDrawable)
{
    return exaDrawableIsOffscreen(pDrawable) ? 's' : 'm';
}
}                          /* DEBUG_TRACE_FALL */

void ExaCheckFillSpans(DrawablePtr pDrawable, GCPtr pGC, int nspans, DDXPointPtr ppt, int* pwidth, int fSorted)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));
    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    exaPrepareAccessGC(pGC);
    pGC.ops.FillSpans(pDrawable, pGC, nspans, ppt, pwidth, fSorted);
    exaFinishAccessGC(pGC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckSetSpans(DrawablePtr pDrawable, GCPtr pGC, char* psrc, DDXPointPtr ppt, int* pwidth, int nspans, int fSorted)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));
    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    pGC.ops.SetSpans(pDrawable, pGC, psrc, ppt, pwidth, nspans, fSorted);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckPutImage(DrawablePtr pDrawable, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* bits)
{
    PixmapPtr pPixmap = exaGetDrawablePixmap(pDrawable);

    mixin(ExaPixmapPriv!("pPixmap"));

    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));
    if (!pExaScr.prepare_access_reg || !pExaPixmap.pDamage ||
        exaGCReadsDestination(pDrawable, pGC.planemask, pGC.fillStyle,
                              pGC.alu, pGC.clientClip !is null))
        exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    else
        pExaScr.prepare_access_reg(pPixmap, EXA_PREPARE_DEST,
                                    DamagePendingRegion(pExaPixmap.pDamage));
    pGC.ops.PutImage(pDrawable, pGC, depth, x, y, w, h, leftPad, format,
                       bits);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckCopyNtoN(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure)
{
    RegionRec reg = void;
    int xoff = void, yoff = void;

    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("from %p to %p (%c,%c)\n", pSr), pDst,
                //   exaDrawableLocation(pSrc), exaDrawableLocation(pDst)));

    if (pExaScr.prepare_access_reg && RegionInitBoxes(&reg, pbox, nbox)) {
        PixmapPtr pPixmap = exaGetDrawablePixmap(pSrc);

        exaGetDrawableDeltas(pSrc, pPixmap, &xoff, &yoff);
        RegionTranslate(&reg, xoff + dx, yoff + dy);
        pExaScr.prepare_access_reg(pPixmap, EXA_PREPARE_SRC, &reg);
        RegionUninit(&reg);
    }
    else
        exaPrepareAccess(pSrc, EXA_PREPARE_SRC);

    if (pExaScr.prepare_access_reg &&
        !exaGCReadsDestination(pDst, pGC.planemask, pGC.fillStyle,
                               pGC.alu, pGC.clientClip !is null) &&
        RegionInitBoxes(&reg, pbox, nbox)) {
        PixmapPtr pPixmap = exaGetDrawablePixmap(pDst);

        exaGetDrawableDeltas(pDst, pPixmap, &xoff, &yoff);
        RegionTranslate(&reg, xoff, yoff);
        pExaScr.prepare_access_reg(pPixmap, EXA_PREPARE_DEST, &reg);
        RegionUninit(&reg);
    }
    else
        exaPrepareAccess(pDst, EXA_PREPARE_DEST);

    /* This will eventually call fbCopyNtoN, with some calculation overhead. */
    while (nbox--) {
        pGC.ops.CopyArea(pSrc, pDst, pGC, pbox.x1 - pSrc.x + dx,
                           pbox.y1 - pSrc.y + dy, pbox.x2 - pbox.x1,
                           pbox.y2 - pbox.y1, pbox.x1 - pDst.x,
                           pbox.y1 - pDst.y);
        pbox++;
    }
    exaFinishAccess(pSrc, EXA_PREPARE_SRC);
    exaFinishAccess(pDst, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

private void ExaFallbackPrepareReg(DrawablePtr pDrawable, GCPtr pGC, int x, int y, int width, int height, int index, Bool checkReads)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(ExaScreenPriv!("pScreen"));

    if (pExaScr.prepare_access_reg &&
        !(checkReads && exaGCReadsDestination(pDrawable, pGC.planemask,
                                              pGC.fillStyle, pGC.alu,
                                              pGC.clientClip !is null))) {
        BoxRec box = void;
        RegionRec reg = void;
        int xoff = void, yoff = void;
        PixmapPtr pPixmap = exaGetDrawablePixmap(pDrawable);

        exaGetDrawableDeltas(pDrawable, pPixmap, &xoff, &yoff);
        box.x1 = cast(short)(pDrawable.x + x + xoff);
        box.y1 = cast(short)(pDrawable.y + y + yoff);
        box.x2 = cast(short)(box.x1 + width);
        box.y2 = cast(short)(box.y1 + height);

        RegionInit(&reg, &box, 1);
        pExaScr.prepare_access_reg(pPixmap, index, &reg);
        RegionUninit(&reg);
    }
    else
        exaPrepareAccess(pDrawable, index);
}

RegionPtr ExaCheckCopyArea(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int w, int h, int dstx, int dsty)
{
    RegionPtr ret = void;

    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("from %p to %p (%c,%c)\n", pSrc, pDst,
                //   exaDrawableLocation(pSrc), exaDrawableLocation(pDst))));
    ExaFallbackPrepareReg(pSrc, pGC, srcx, srcy, w, h, EXA_PREPARE_SRC, FALSE);
    ExaFallbackPrepareReg(pDst, pGC, dstx, dsty, w, h, EXA_PREPARE_DEST, TRUE);
    ret = pGC.ops.CopyArea(pSrc, pDst, pGC, srcx, srcy, w, h, dstx, dsty);
    exaFinishAccess(pSrc, EXA_PREPARE_SRC);
    exaFinishAccess(pDst, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));

    return ret;
}

RegionPtr ExaCheckCopyPlane(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int w, int h, int dstx, int dsty, c_ulong bitPlane)
{
    RegionPtr ret = void;

    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("from %p to %p (%c,%c)\n", pSrc, pDst,
                //   exaDrawableLocation(pSrc), exaDrawableLocation(pDst))));
    ExaFallbackPrepareReg(pSrc, pGC, srcx, srcy, w, h, EXA_PREPARE_SRC, FALSE);
    ExaFallbackPrepareReg(pDst, pGC, dstx, dsty, w, h, EXA_PREPARE_DEST, TRUE);
    ret = pGC.ops.CopyPlane(pSrc, pDst, pGC, srcx, srcy, w, h, dstx, dsty,
                              bitPlane);
    exaFinishAccess(pSrc, EXA_PREPARE_SRC);
    exaFinishAccess(pDst, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));

    return ret;
}

void ExaCheckPolyPoint(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr pptInit)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));
    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    pGC.ops.PolyPoint(pDrawable, pGC, mode, npt, pptInit);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckPolylines(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr ppt)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c), width %d, mode %d, coun)t %d\n",
                //   pDrawable, exaDrawableLocation(pDrawable),
                //   pGC.lineWidth, mode, npt)));

    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    exaPrepareAccessGC(pGC);
    pGC.ops.Polylines(pDrawable, pGC, mode, npt, ppt);
    exaFinishAccessGC(pGC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckPolySegment(DrawablePtr pDrawable, GCPtr pGC, int nsegInit, xSegment* pSegInit)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c) width %d, count %d\n"), pDrawable,
                //   exaDrawableLocation(pDrawable), pGC.lineWidth, nsegInit));

    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    exaPrepareAccessGC(pGC);
    pGC.ops.PolySegment(pDrawable, pGC, nsegInit, pSegInit);
    exaFinishAccessGC(pGC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckPolyArc(DrawablePtr pDrawable, GCPtr pGC, int narcs, xArc* pArcs)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));

    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    exaPrepareAccessGC(pGC);
    pGC.ops.PolyArc(pDrawable, pGC, narcs, pArcs);
    exaFinishAccessGC(pGC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckPolyFillRect(DrawablePtr pDrawable, GCPtr pGC, int nrect, xRectangle* prect)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));

    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    exaPrepareAccessGC(pGC);
    pGC.ops.PolyFillRect(pDrawable, pGC, nrect, prect);
    exaFinishAccessGC(pGC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckImageGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));
    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    exaPrepareAccessGC(pGC);
    pGC.ops.ImageGlyphBlt(pDrawable, pGC, x, y, nglyph, ppci, pglyphBase);
    exaFinishAccessGC(pGC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckPolyGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("to %p (%c), style %d alu %d\n", pDrawable,
                //   exaDrawableLocation(pDrawable), pGC.fillStyle, pGC.alu)));
    exaPrepareAccess(pDrawable, EXA_PREPARE_DEST);
    exaPrepareAccessGC(pGC);
    pGC.ops.PolyGlyphBlt(pDrawable, pGC, x, y, nglyph, ppci, pglyphBase);
    exaFinishAccessGC(pGC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckPushPixels(GCPtr pGC, PixmapPtr pBitmap, DrawablePtr pDrawable, int w, int h, int x, int y)
{
    mixin(EXA_PRE_FALLBACK_GC!("pGC"));
    // mixin(EXA_FALLBACK!(("from %p to %p (%c,%c)\n", pBitma)p, pDrawable,
                //   exaDrawableLocation(&pBitmap.drawable),
                //   exaDrawableLocation(pDrawable)));
    ExaFallbackPrepareReg(pDrawable, pGC, x, y, w, h, EXA_PREPARE_DEST, TRUE);
    ExaFallbackPrepareReg(&pBitmap.drawable, pGC, 0, 0, w, h,
                          EXA_PREPARE_SRC, FALSE);
    exaPrepareAccessGC(pGC);
    pGC.ops.PushPixels(pGC, pBitmap, pDrawable, w, h, x, y);
    exaFinishAccessGC(pGC);
    exaFinishAccess(&pBitmap.drawable, EXA_PREPARE_SRC);
    exaFinishAccess(pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK_GC!("pGC"));
}

void ExaCheckCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc)
{
    DrawablePtr pDrawable = &pWin.drawable;
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(EXA_PRE_FALLBACK!("pScreen"));
    // mixin(EXA_FALLBACK!(("from %p\n", pWin));

    /* Only need the sourc)e bits, the destination region will be overwritten */
    if (pExaScr.prepare_access_reg) {
        PixmapPtr pPixmap = pScreen.GetWindowPixmap(pWin);
        int xoff = void, yoff = void;

        exaGetDrawableDeltas(&pWin.drawable, pPixmap, &xoff, &yoff);
        RegionTranslate(prgnSrc, xoff, yoff);
        pExaScr.prepare_access_reg(pPixmap, EXA_PREPARE_SRC, prgnSrc);
        RegionTranslate(prgnSrc, -xoff, -yoff);
    }
    else
        exaPrepareAccess(pDrawable, EXA_PREPARE_SRC);

    mixin(swap!("pExaScr", "pScreen", "CopyWindow"));
    pScreen.CopyWindow(pWin, ptOldOrg, prgnSrc);
    mixin(swap!("pExaScr", "pScreen", "CopyWindow"));
    exaFinishAccess(pDrawable, EXA_PREPARE_SRC);
    mixin(EXA_POST_FALLBACK!("pScreen"));
}

void ExaCheckGetImage(DrawablePtr pDrawable, int x, int y, int w, int h, uint format, c_ulong planeMask, char* d)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(EXA_PRE_FALLBACK!("pScreen"));
    // mixin(EXA_FALLBACK!(("from %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));

    ExaFallbackPrepareReg(pDrawable, null, x, y, w, h, EXA_PREPARE_SRC, FALSE);
    mixin(swap!("pExaScr", "pScreen", "GetImage"));
    pScreen.GetImage(pDrawable, x, y, w, h, format, planeMask, d);
    mixin(swap!("pExaScr", "pScreen", "GetImage"));
    exaFinishAccess(pDrawable, EXA_PREPARE_SRC);
    mixin(EXA_POST_FALLBACK!("pScreen"));
}

void ExaCheckGetSpans(DrawablePtr pDrawable, int wMax, DDXPointPtr ppt, int* pwidth, int nspans, char* pdstStart)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(EXA_PRE_FALLBACK!("pScreen"));
    // mixin(EXA_FALLBACK!(("from %p (%c)\n", pDrawable, exaDrawableLocation(pDrawable))));
    exaPrepareAccess(pDrawable, EXA_PREPARE_SRC);
    mixin(swap!("pExaScr", "pScreen", "GetSpans"));
    pScreen.GetSpans(pDrawable, wMax, ppt, pwidth, nspans, pdstStart);
    mixin(swap!("pExaScr", "pScreen", "GetSpans"));
    exaFinishAccess(pDrawable, EXA_PREPARE_SRC);
    mixin(EXA_POST_FALLBACK!("pScreen"));
}

private void ExaSrcValidate(DrawablePtr pDrawable, int x, int y, int width, int height, uint subWindowMode)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(ExaScreenPriv!("pScreen"));
    PixmapPtr pPix = exaGetDrawablePixmap(pDrawable);
    BoxRec box = void;
    RegionRec reg = void;
    RegionPtr dst = void;
    int xoff = void, yoff = void;

    if (pExaScr.srcPix == pPix)
        dst = &pExaScr.srcReg;
    else if (pExaScr.maskPix == pPix)
        dst = &pExaScr.maskReg;
    else
        return;

    exaGetDrawableDeltas(pDrawable, pPix, &xoff, &yoff);

    box.x1 = cast(short)(x + xoff);
    box.y1 = cast(short)(y + yoff);
    box.x2 = cast(short)(box.x1 + width);
    box.y2 = cast(short)(box.y1 + height);

    RegionInit(&reg, &box, 1);
    RegionUnion(dst, dst, &reg);
    RegionUninit(&reg);

    mixin(swap!("pExaScr", "pScreen", "SourceValidate"));
    pScreen.SourceValidate(pDrawable, x, y, width, height, subWindowMode);
    mixin(swap!("pExaScr", "pScreen", "SourceValidate"));
}

private Bool ExaPrepareCompositeReg(ScreenPtr pScreen, CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    RegionRec region = void;
    RegionPtr dstReg = null;
    RegionPtr srcReg = null;
    RegionPtr maskReg = null;
    PixmapPtr pSrcPix = null;
    PixmapPtr pMaskPix = null;
    PixmapPtr pDstPix = void;

    mixin(ExaScreenPriv!("pScreen"));
    Bool ret = void;

    RegionNull(&region);

    if (pSrc.pDrawable) {
        pSrcPix = exaGetDrawablePixmap(pSrc.pDrawable);
        RegionNull(&pExaScr.srcReg);
        srcReg = &pExaScr.srcReg;
        pExaScr.srcPix = pSrcPix;
        if (pSrc != pDst)
            RegionTranslate(pSrc.pCompositeClip,
                            -pSrc.pDrawable.x, -pSrc.pDrawable.y);
    } else
        pExaScr.srcPix = null;

    if (pMask && pMask.pDrawable) {
        pMaskPix = exaGetDrawablePixmap(pMask.pDrawable);
        RegionNull(&pExaScr.maskReg);
        maskReg = &pExaScr.maskReg;
        pExaScr.maskPix = pMaskPix;
        if (pMask != pDst && pMask != pSrc)
            RegionTranslate(pMask.pCompositeClip,
                            -pMask.pDrawable.x, -pMask.pDrawable.y);
    } else
        pExaScr.maskPix = null;

    RegionTranslate(pDst.pCompositeClip,
                    -pDst.pDrawable.x, -pDst.pDrawable.y);

    pExaScr.SavedSourceValidate = &ExaSrcValidate;
    mixin(swap!("pExaScr", "pScreen", "SourceValidate"));
    ret = miComputeCompositeRegion(&region, pSrc, pMask, pDst,
                                   xSrc, ySrc, xMask, yMask,
                                   xDst, yDst, width, height);
    mixin(swap!("pExaScr", "pScreen", "SourceValidate"));

    RegionTranslate(pDst.pCompositeClip,
                    pDst.pDrawable.x, pDst.pDrawable.y);
    if (pSrc.pDrawable && pSrc != pDst)
        RegionTranslate(pSrc.pCompositeClip,
                        pSrc.pDrawable.x, pSrc.pDrawable.y);
    if (pMask && pMask.pDrawable && pMask != pDst && pMask != pSrc)
        RegionTranslate(pMask.pCompositeClip,
                        pMask.pDrawable.x, pMask.pDrawable.y);

    if (!ret) {
        if (srcReg)
            RegionUninit(srcReg);
        if (maskReg)
            RegionUninit(maskReg);

        return FALSE;
    }

    /**
     * Don't limit alphamaps readbacks for now until we've figured out how that
     * should be done.
     */

    if (pSrc.alphaMap && pSrc.alphaMap.pDrawable)
        pExaScr.
            prepare_access_reg(exaGetDrawablePixmap(pSrc.alphaMap.pDrawable),
                               EXA_PREPARE_AUX_SRC, null);
    if (pMask && pMask.alphaMap && pMask.alphaMap.pDrawable)
        pExaScr.
            prepare_access_reg(exaGetDrawablePixmap(pMask.alphaMap.pDrawable),
                               EXA_PREPARE_AUX_MASK, null);

    if (pSrcPix)
        pExaScr.prepare_access_reg(pSrcPix, EXA_PREPARE_SRC, srcReg);

    if (pMaskPix)
        pExaScr.prepare_access_reg(pMaskPix, EXA_PREPARE_MASK, maskReg);

    if (srcReg)
        RegionUninit(srcReg);
    if (maskReg)
        RegionUninit(maskReg);

    pDstPix = exaGetDrawablePixmap(pDst.pDrawable);
    if (!exaOpReadsDestination(op)) {
        int xoff = void;
        int yoff = void;

        exaGetDrawableDeltas(pDst.pDrawable, pDstPix, &xoff, &yoff);
        RegionTranslate(&region, pDst.pDrawable.x + xoff,
                        pDst.pDrawable.y + yoff);
        dstReg = &region;
    }

    if (pDst.alphaMap && pDst.alphaMap.pDrawable)
        pExaScr.
            prepare_access_reg(exaGetDrawablePixmap(pDst.alphaMap.pDrawable),
                               EXA_PREPARE_AUX_DEST, dstReg);
    pExaScr.prepare_access_reg(pDstPix, EXA_PREPARE_DEST, dstReg);

    RegionUninit(&region);
    return TRUE;
}

void ExaCheckComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(EXA_PRE_FALLBACK!("pScreen"));

    if (pExaScr.prepare_access_reg) {
        if (!ExaPrepareCompositeReg(pScreen, op, pSrc, pMask, pDst, xSrc,
                                    ySrc, xMask, yMask, xDst, yDst, width,
                                    height))
            goto out_no_clip;
    }
    else {

        /* We need to prepare access to any separate alpha maps first,
         * in case the driver doesn't support EXA_PREPARE_AUX*,
         * in which case EXA_PREPARE_SRC may be used for moving them out.
         */

        if (pSrc.alphaMap && pSrc.alphaMap.pDrawable)
            exaPrepareAccess(pSrc.alphaMap.pDrawable, EXA_PREPARE_AUX_SRC);
        if (pMask && pMask.alphaMap && pMask.alphaMap.pDrawable)
            exaPrepareAccess(pMask.alphaMap.pDrawable, EXA_PREPARE_AUX_MASK);
        if (pDst.alphaMap && pDst.alphaMap.pDrawable)
            exaPrepareAccess(pDst.alphaMap.pDrawable, EXA_PREPARE_AUX_DEST);

        exaPrepareAccess(pDst.pDrawable, EXA_PREPARE_DEST);

        // mixin(EXA_FALLBACK!(("from picts %p/%p to pict %p\n", pSrc), pMask, pDst));

        if (pSrc.pDrawable !is null)
            exaPrepareAccess(pSrc.pDrawable, EXA_PREPARE_SRC);
        if (pMask && pMask.pDrawable !is null)
            exaPrepareAccess(pMask.pDrawable, EXA_PREPARE_MASK);
    }

    mixin(swap!("pExaScr", "ps", "Composite"));
    ps.Composite(op,
                  pSrc,
                  pMask,
                  pDst, xSrc, ySrc, xMask, yMask, xDst, yDst, width, height);
    mixin(swap!("pExaScr", "ps", "Composite"));
    if (pMask && pMask.pDrawable !is null)
        exaFinishAccess(pMask.pDrawable, EXA_PREPARE_MASK);
    if (pSrc.pDrawable !is null)
        exaFinishAccess(pSrc.pDrawable, EXA_PREPARE_SRC);
    exaFinishAccess(pDst.pDrawable, EXA_PREPARE_DEST);
    if (pDst.alphaMap && pDst.alphaMap.pDrawable)
        exaFinishAccess(pDst.alphaMap.pDrawable, EXA_PREPARE_AUX_DEST);
    if (pSrc.alphaMap && pSrc.alphaMap.pDrawable)
        exaFinishAccess(pSrc.alphaMap.pDrawable, EXA_PREPARE_AUX_SRC);
    if (pMask && pMask.alphaMap && pMask.alphaMap.pDrawable)
        exaFinishAccess(pMask.alphaMap.pDrawable, EXA_PREPARE_AUX_MASK);

 out_no_clip:
    mixin(EXA_POST_FALLBACK!("pScreen"));
}

/**
 * Avoid migration ping-pong when using a mask.
 */
void ExaCheckGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;

    mixin(EXA_PRE_FALLBACK!("pScreen"));

    miGlyphs(op, pSrc, pDst, maskFormat, xSrc, ySrc, nlist, list, glyphs);

    mixin(EXA_POST_FALLBACK!("pScreen"));
}

void ExaCheckAddTraps(PicturePtr pPicture, INT16 x_off, INT16 y_off, int ntrap, xTrap* traps)
{
    ScreenPtr pScreen = pPicture.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));

    mixin(EXA_PRE_FALLBACK!("pScreen"));

    // mixin(EXA_FALLBACK!(("to pict %p (%c)\n", pPicture,
                //   exaDrawableLocation(pPictur)e.pDrawable)));
    exaPrepareAccess(pPicture.pDrawable, EXA_PREPARE_DEST);
    mixin(swap!("pExaScr", "ps", "AddTraps"));
    ps.AddTraps(pPicture, x_off, y_off, ntrap, traps);
    mixin(swap!("pExaScr", "ps", "AddTraps"));
    exaFinishAccess(pPicture.pDrawable, EXA_PREPARE_DEST);
    mixin(EXA_POST_FALLBACK!("pScreen"));
}

/**
 * Gets the 0,0 pixel of a pixmap.  Used for doing solid fills of tiled pixmaps
 * that happen to be 1x1.  Pixmap must be at least 8bpp.
 */
CARD32 exaGetPixmapFirstPixel(PixmapPtr pPixmap)
{
    switch (pPixmap.drawable.bitsPerPixel) {
    case 32:
    {
        CARD32 pixel = void;

        pPixmap.drawable.pScreen.GetImage(&pPixmap.drawable, 0, 0, 1, 1,
                                            ZPixmap, ~0, cast(char*) &pixel);
        return pixel;
    }
    case 16:
    {
        CARD16 pixel = void;

        pPixmap.drawable.pScreen.GetImage(&pPixmap.drawable, 0, 0, 1, 1,
                                            ZPixmap, ~0, cast(char*) &pixel);
        return pixel;
    }
    case 8:
    case 4:
    case 1:
    {
        CARD8 pixel = void;

        pPixmap.drawable.pScreen.GetImage(&pPixmap.drawable, 0, 0, 1, 1,
                                            ZPixmap, ~0, cast(char*) &pixel);
        return pixel;
    }
    default:
        FatalError("%s called for invalid bpp %d\n", __FUNCTION__.ptr,
                   pPixmap.drawable.bitsPerPixel);
    }
    assert(0);
}
