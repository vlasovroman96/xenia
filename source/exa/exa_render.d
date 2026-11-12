module exa.exa_render;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2001 Keith Packard
 *
 * Partly based on code that is Copyright © The XFree86 Project Inc.
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

import core.stdc.stdlib;

import mi.mipict;

import exa.exa_priv;
import os.log;
import exa.exa;
import render.picture;
import render.mipict;
import dix.gc;
import mirect;
import mitrap;
import mitri;
import exa_unaccel;
import fb.fb;
import dix.picture;

static if (DEBUG_TRACE_FALL) {
private void exaCompositeFallbackPictDesc(PicturePtr pict, char* string, int n)
{
    char[20] format = void;
    char[20] size = void;
    char loc = void;
    int temp = void;

    if (!pict) {
        snprintf(string, n, "None");
        return;
    }

    switch (pict.format) {
    case PIXMAN_a8r8g8b8:
        snprintf(format.ptr, 20, "ARGB8888");
        break;
    case PIXMAN_x8r8g8b8:
        snprintf(format.ptr, 20, "XRGB8888");
        break;
    case PIXMAN_b8g8r8a8:
        snprintf(format.ptr, 20, "BGRA8888");
        break;
    case PIXMAN_b8g8r8x8:
        snprintf(format.ptr, 20, "BGRX8888");
        break;
    case PIXMAN_r5g6b5:
        snprintf(format.ptr, 20, "RGB565  ");
        break;
    case PIXMAN_x1r5g5b5:
        snprintf(format.ptr, 20, "RGB555  ");
        break;
    case PIXMAN_a8:
        snprintf(format.ptr, 20, "A8      ");
        break;
    case PIXMAN_a1:
        snprintf(format.ptr, 20, "A1      ");
        break;
    default:
        snprintf(format.ptr, 20, "0x%x", cast(int) pict.format);
        break;
    }

    if (pict.pDrawable) {
        loc = exaGetOffscreenPixmap(pict.pDrawable, &temp, &temp) ? 's' : 'm';

        snprintf(size.ptr, 20, "%dx%d%s", pict.pDrawable.width,
                 pict.pDrawable.height, pict.repeat ? " R" : "");
    }
    else {
        loc = '-';

        snprintf(size.ptr, 20, "%s", pict.repeat ? " R" : "");
    }

    snprintf(string, n, "%p:%c fmt %s (%s)", pict.pDrawable, loc, format.ptr,
             size.ptr);
}

private void exaPrintCompositeFallback(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst)
{
    char[20] sop = void;
    char[40] srcdesc = void, maskdesc = void, dstdesc = void;

    switch (op) {
    case PictOpSrc:
        snprintf(sop.ptr, sop.sizeof, "Src");
        break;
    case PictOpOver:
        snprintf(sop.ptr, sop.sizeof, "Over");
        break;
    default:
        snprintf(sop.ptr, sop.sizeof, "0x%x", cast(int) op);
        break;
    }

    exaCompositeFallbackPictDesc(pSrc, srcdesc.ptr, 40);
    exaCompositeFallbackPictDesc(pMask, maskdesc.ptr, 40);
    exaCompositeFallbackPictDesc(pDst, dstdesc.ptr, 40);

    ErrorF("Composite fallback: op %s, \n"
           ~ "                    src  %s, \n"
           ~ "                    mask %s, \n"
           ~ "                    dst  %s, \n", sop.ptr, srcdesc.ptr, maskdesc.ptr, dstdesc.ptr);
}
}                          /* DEBUG_TRACE_FALL */

Bool exaOpReadsDestination(CARD8 op)
{
    /* FALSE (does not read destination) is the list of ops in the protocol
     * document with "0" in the "Fb" column and no "Ab" in the "Fa" column.
     * That's just Clear and Src.  ReduceCompositeOp() will already have
     * converted con/disjoint clear/src to Clear or Src.
     */
    switch(op)
    {
        case PictOpClear:
        case PictOpSrc:
            return FALSE;
        default:
            return TRUE;
    }
}

private Bool exaGetPixelFromRGBA(CARD32* pixel, CARD16 red, CARD16 green, CARD16 blue, CARD16 alpha, PictFormatPtr pFormat)
{
    int rshift = void, bshift = void, gshift = void, ashift = void;

    *pixel = 0;

    if (!PIXMAN_FORMAT_COLOR(pFormat.format) &&
        PIXMAN_FORMAT_TYPE(pFormat.format) != PIXMAN_TYPE_A)
        return FALSE;

    int rbits = cast(int)PIXMAN_FORMAT_R(pFormat.format);
    int gbits = cast(int)PIXMAN_FORMAT_G(pFormat.format);
    int bbits = cast(int)PIXMAN_FORMAT_B(pFormat.format);
    int abits = cast(int)PIXMAN_FORMAT_A(pFormat.format);

    rshift = pFormat.direct.red;
    gshift = pFormat.direct.green;
    bshift = pFormat.direct.blue;
    ashift = pFormat.direct.alpha;

    *pixel |= (blue >> (16 - bbits)) << bshift;
    *pixel |= (red >> (16 - rbits)) << rshift;
    *pixel |= (green >> (16 - gbits)) << gshift;
    *pixel |= (alpha >> (16 - abits)) << ashift;

    return TRUE;
}

private Bool exaGetRGBAFromPixel(CARD32 pixel, CARD16* red, CARD16* green, CARD16* blue, CARD16* alpha, PictFormatPtr pFormat, pixman_format_code_t format)
{
    int rshift = void, bshift = void, gshift = void, ashift = void;

    if (!PIXMAN_FORMAT_COLOR(format) && PIXMAN_FORMAT_TYPE(format) != PIXMAN_TYPE_A)
        return FALSE;

    int rbits = PIXMAN_FORMAT_R(format);
    int gbits = PIXMAN_FORMAT_G(format);
    int bbits = PIXMAN_FORMAT_B(format);
    int abits = PIXMAN_FORMAT_A(format);

    if (pFormat) {
        rshift = pFormat.direct.red;
        gshift = pFormat.direct.green;
        bshift = pFormat.direct.blue;
        ashift = pFormat.direct.alpha;
    }
    else if (format == PIXMAN_a8r8g8b8) {
        rshift = 16;
        gshift = 8;
        bshift = 0;
        ashift = 24;
    }
    else
        FatalError("EXA bug: exaGetRGBAFromPixel() doesn't match "
                   ~ "createSourcePicture()\n");

    if (rbits) {
        *red = cast(ushort)(((pixel >> rshift) & ((1 << rbits) - 1)) << (16 - rbits));
        while (rbits < 16) {
            *red |= *red >> rbits;
            rbits <<= 1;
        }

        *green = cast(ushort)(((pixel >> gshift) & ((1 << gbits) - 1)) << (16 - gbits));
        while (gbits < 16) {
            *green |= *green >> gbits;
            gbits <<= 1;
        }

        *blue = cast(ushort)(((pixel >> bshift) & ((1 << bbits) - 1)) << (16 - bbits));
        while (bbits < 16) {
            *blue |= *blue >> bbits;
            bbits <<= 1;
        }
    }
    else {
        *red = 0x0000;
        *green = 0x0000;
        *blue = 0x0000;
    }

    if (abits) {
        *alpha = cast(ushort)(((pixel >> ashift) & ((1 << abits) - 1)) << (16 - abits));
        while (abits < 16) {
            *alpha |= *alpha >> abits;
            abits <<= 1;
        }
    }
    else
        *alpha = 0xffff;

    return TRUE;
}

private int exaTryDriverSolidFill(PicturePtr pSrc, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    mixin(ExaScreenPriv!("pDst.pDrawable.pScreen"));
    RegionRec region = void;
    BoxPtr pbox = void;
    int nbox = void;
    int dst_off_x = void, dst_off_y = void;
    PixmapPtr pSrcPix = void, pDstPix = void;
    ExaPixmapPrivPtr pDstExaPix = void;
    CARD32 pixel = void;
    CARD16 red = void, green = void, blue = void, alpha = void;

    pDstPix = exaGetDrawablePixmap(pDst.pDrawable);
    pDstExaPix = mixin(ExaGetPixmapPriv!("pDstPix"));

    /* Check whether the accelerator can use the destination pixmap.
     */
    if (pDstExaPix.accel_blocked) {
        return -1;
    }

    xDst += pDst.pDrawable.x;
    yDst += pDst.pDrawable.y;
    if (pSrc.pDrawable) {
        xSrc += pSrc.pDrawable.x;
        ySrc += pSrc.pDrawable.y;
    }

    if (!miComputeCompositeRegion(&region, pSrc, null, pDst,
                                  xSrc, ySrc, 0, 0, xDst, yDst, width, height))
        return 1;

    exaGetDrawableDeltas(pDst.pDrawable, pDstPix, &dst_off_x, &dst_off_y);

    RegionTranslate(&region, dst_off_x, dst_off_y);

    if (pSrc.pDrawable) {
        pSrcPix = exaGetDrawablePixmap(pSrc.pDrawable);
        pixel = exaGetPixmapFirstPixel(pSrcPix);
    }
    else
        miRenderColorToPixel(PictureMatchFormat(pDst.pDrawable.pScreen, 32,
                                                pSrc.format),
                             &pSrc.pSourcePict.solidFill.fullcolor,
                             &pixel);

    if (!exaGetRGBAFromPixel(pixel, &red, &green, &blue, &alpha,
                             pSrc.pFormat, pSrc.format) ||
        !exaGetPixelFromRGBA(&pixel, red, green, blue, alpha, pDst.pFormat)) {
        RegionUninit(&region);
        return -1;
    }

    if (pExaScr.do_migration) {
        ExaMigrationRec[1] pixmaps = void;

        pixmaps[0].as_dst = TRUE;
        pixmaps[0].as_src = FALSE;
        pixmaps[0].pPix = pDstPix;
        pixmaps[0].pReg = &region;
        exaDoMigration(pixmaps.ptr, 1, TRUE);
    }

    if (!exaPixmapHasGpuCopy(pDstPix)) {
        RegionUninit(&region);
        return 0;
    }

    if (!(*pExaScr.info.PrepareSolid) (pDstPix, GXcopy, 0xffffffff, pixel)) {
        RegionUninit(&region);
        return -1;
    }

    nbox = RegionNumRects(&region);
    pbox = RegionRects(&region);

    while (nbox--) {
        (*pExaScr.info.Solid) (pDstPix, pbox.x1, pbox.y1, pbox.x2,
                                 pbox.y2);
        pbox++;
    }

    (*pExaScr.info.DoneSolid) (pDstPix);
    exaMarkSync(pDst.pDrawable.pScreen);

    RegionUninit(&region);
    return 1;
}

private int exaTryDriverCompositeRects(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, int nrect, ExaCompositeRectPtr rects)
{
    mixin(ExaScreenPriv!("pDst.pDrawable.pScreen"));
    int src_off_x = 0, src_off_y = 0, mask_off_x = 0, mask_off_y = 0;
    int dst_off_x = void, dst_off_y = void;
    PixmapPtr pSrcPix = null, pMaskPix = null, pDstPix = void;
    ExaPixmapPrivPtr pSrcExaPix = null, pMaskExaPix = null, pDstExaPix = void;

    if (!pExaScr.info.PrepareComposite)
        return -1;

    if (pSrc.pDrawable) {
        pSrcPix = exaGetDrawablePixmap(pSrc.pDrawable);
        pSrcExaPix = mixin(ExaGetPixmapPriv!("pSrcPix"));
    }

    if (pMask && pMask.pDrawable) {
        pMaskPix = exaGetDrawablePixmap(pMask.pDrawable);
        pMaskExaPix = mixin(ExaGetPixmapPriv!("pMaskPix"));
    }

    pDstPix = exaGetDrawablePixmap(pDst.pDrawable);
    pDstExaPix = mixin(ExaGetPixmapPriv!("pDstPix"));

    /* Check whether the accelerator can use these pixmaps.
     * FIXME: If it cannot, use temporary pixmaps so that the drawing
     * happens within limits.
     */
    if (pDstExaPix.accel_blocked ||
        (pSrcExaPix && pSrcExaPix.accel_blocked) ||
        (pMaskExaPix && pMaskExaPix.accel_blocked)) {
        return -1;
    }

    if (pExaScr.info.CheckComposite &&
        !(*pExaScr.info.CheckComposite) (op, pSrc, pMask, pDst)) {
        return -1;
    }

    if (pExaScr.do_migration) {
        ExaMigrationRec[3] pixmaps = void;
        int i = 0;

        pixmaps[i].as_dst = TRUE;
        pixmaps[i].as_src = exaOpReadsDestination(op);
        pixmaps[i].pPix = pDstPix;
        pixmaps[i].pReg = null;
        i++;

        if (pSrcPix) {
            pixmaps[i].as_dst = FALSE;
            pixmaps[i].as_src = TRUE;
            pixmaps[i].pPix = pSrcPix;
            pixmaps[i].pReg = null;
            i++;
        }

        if (pMaskPix) {
            pixmaps[i].as_dst = FALSE;
            pixmaps[i].as_src = TRUE;
            pixmaps[i].pPix = pMaskPix;
            pixmaps[i].pReg = null;
            i++;
        }

        exaDoMigration(pixmaps.ptr, i, TRUE);
    }

    pDstPix = exaGetOffscreenPixmap(pDst.pDrawable, &dst_off_x, &dst_off_y);
    if (!pDstPix)
        return 0;

    if (pSrcPix) {
        pSrcPix =
            exaGetOffscreenPixmap(pSrc.pDrawable, &src_off_x, &src_off_y);
        if (!pSrcPix)
            return 0;
    }

    if (pMaskPix) {
        pMaskPix =
            exaGetOffscreenPixmap(pMask.pDrawable, &mask_off_x, &mask_off_y);
        if (!pMaskPix)
            return 0;
    }

    if (!(*pExaScr.info.PrepareComposite) (op, pSrc, pMask, pDst, pSrcPix,
                                             pMaskPix, pDstPix))
        return -1;

    while (nrect--) {
        INT16 xDst = cast(short)(rects.xDst + pDst.pDrawable.x);
        INT16 yDst = cast(short)(rects.yDst + pDst.pDrawable.y);
        INT16 xMask = rects.xMask;
        INT16 yMask = rects.yMask;
        INT16 xSrc = rects.xSrc;
        INT16 ySrc = rects.ySrc;
        RegionRec region = void;
        BoxPtr pbox = void;
        int nbox = void;

        if (pMaskPix) {
            xMask += pMask.pDrawable.x;
            yMask += pMask.pDrawable.y;
        }

        if (pSrcPix) {
            xSrc += pSrc.pDrawable.x;
            ySrc += pSrc.pDrawable.y;
        }

        if (!miComputeCompositeRegion(&region, pSrc, pMask, pDst,
                                      xSrc, ySrc, xMask, yMask, xDst, yDst,
                                      rects.width, rects.height))
            goto next_rect;

        RegionTranslate(&region, dst_off_x, dst_off_y);

        nbox = RegionNumRects(&region);
        pbox = RegionRects(&region);

        xMask = cast(short)(xMask + mask_off_x - xDst - dst_off_x);
        yMask = cast(short)(yMask + mask_off_y - yDst - dst_off_y);
        xSrc = cast(short)(xSrc + src_off_x - xDst - dst_off_x);
        ySrc = cast(short)(ySrc + src_off_y - yDst - dst_off_y);

        while (nbox--) {
            (*pExaScr.info.Composite) (pDstPix,
                                         pbox.x1 + xSrc,
                                         pbox.y1 + ySrc,
                                         pbox.x1 + xMask,
                                         pbox.y1 + yMask,
                                         pbox.x1,
                                         pbox.y1,
                                         pbox.x2 - pbox.x1,
                                         pbox.y2 - pbox.y1);
            pbox++;
        }

 next_rect:
        RegionUninit(&region);

        rects++;
    }

    (*pExaScr.info.DoneComposite) (pDstPix);
    exaMarkSync(pDst.pDrawable.pScreen);

    return 1;
}

/**
 * Copy a number of rectangles from source to destination in a single
 * operation. This is specialized for glyph rendering: we don't have the
 * special-case fallbacks found in exaComposite() - if the driver can support
 * it, we use the driver functionality, otherwise we fall back straight to
 * software.
 */
void exaCompositeRects(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, int nrect, ExaCompositeRectPtr rects)
{
    mixin(ExaScreenPriv!("pDst.pDrawable.pScreen"));
    int n = void;
    ExaCompositeRectPtr r = void;
    int ret = void;

    /* If we get a mask, that means we're rendering to the exaGlyphs
     * destination directly, so the damage layer takes care of this.
     */
    if (!pMask) {
        RegionRec region = void;
        int x1 = SHRT_MAX;
        int y1 = SHRT_MAX;
        int x2 = SHRT_MIN;
        int y2 = SHRT_MIN;
        BoxRec box = void;

        /* We have to manage the damage ourselves, since CompositeRects isn't
         * something in the screen that can be managed by the damage extension,
         * and EXA depends on damage to track what needs to be migrated between
         * the gpu and the cpu.
         */

        /* Compute the overall extents of the composited region - we're making
         * the assumption here that we are compositing a bunch of glyphs that
         * cluster closely together and damaging each glyph individually would
         * be a loss compared to damaging the bounding box.
         */
        n = nrect;
        r = rects;
        while (n--) {
            int rect_x2 = r.xDst + r.width;
            int rect_y2 = r.yDst + r.height;

            if (r.xDst < x1)
                x1 = r.xDst;
            if (r.yDst < y1)
                y1 = r.yDst;
            if (rect_x2 > x2)
                x2 = rect_x2;
            if (rect_y2 > y2)
                y2 = rect_y2;

            r++;
        }

        if (x2 <= x1 || y2 <= y1)
            return;

        box.x1 = cast(short)(x1);
        box.x2 = cast(short)(x2 < SHRT_MAX ? x2 : SHRT_MAX);
        box.y1 = cast(short)(y1);
        box.y2 = cast(short)(y2 < SHRT_MAX ? y2 : SHRT_MAX);

        /* The pixmap migration code relies on pendingDamage indicating
         * the bounds of the current rendering, so we need to force
         * the actual damage into that region before we do anything, and
         * (see use of DamagePendingRegion in exaCopyDirty)
         */

        RegionInit(&region, &box, 1);

        DamageRegionAppend(pDst.pDrawable, &region);

        RegionUninit(&region);
    }

    /************************************************************/

    ValidatePicture(pSrc);
    if (pMask)
        ValidatePicture(pMask);
    ValidatePicture(pDst);

    ret = exaTryDriverCompositeRects(op, pSrc, pMask, pDst, nrect, rects);

    if (ret != 1) {
        if (ret == -1 && op == PictOpOver && pMask && pMask.componentAlpha &&
            (!pExaScr.info.CheckComposite ||
             ((*pExaScr.info.CheckComposite) (PictOpOutReverse, pSrc, pMask,
                                                pDst) &&
              (*pExaScr.info.CheckComposite) (PictOpAdd, pSrc, pMask,
                                                pDst)))) {
            ret =
                exaTryDriverCompositeRects(PictOpOutReverse, pSrc, pMask, pDst,
                                           nrect, rects);
            if (ret == 1) {
                op = PictOpAdd;
                ret = exaTryDriverCompositeRects(op, pSrc, pMask, pDst, nrect,
                                                 rects);
            }
        }

        if (ret != 1) {
            n = nrect;
            r = rects;
            while (n--) {
                ExaCheckComposite(op, pSrc, pMask, pDst,
                                  r.xSrc, r.ySrc,
                                  r.xMask, r.yMask,
                                  r.xDst, r.yDst, r.width, r.height);
                r++;
            }
        }
    }

    /************************************************************/

    if (!pMask) {
        /* Now we have to flush the damage out from pendingDamage => damage
         * Calling DamageRegionProcessPending has that effect.
         */

        DamageRegionProcessPending(pDst.pDrawable);
    }
}

private int exaTryDriverComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    mixin(ExaScreenPriv!("pDst.pDrawable.pScreen"));
    RegionRec region = void;
    BoxPtr pbox = void;
    int nbox = void;
    int src_off_x = void, src_off_y = void, mask_off_x = 0, mask_off_y = 0, dst_off_x = void, dst_off_y = void;
    PixmapPtr pSrcPix = null, pMaskPix = null, pDstPix = void;
    ExaPixmapPrivPtr pSrcExaPix = null, pMaskExaPix = null, pDstExaPix = void;

    if (pSrc.pDrawable) {
        pSrcPix = exaGetDrawablePixmap(pSrc.pDrawable);
        pSrcExaPix = mixin(ExaGetPixmapPriv!("pSrcPix"));
    }

    pDstPix = exaGetDrawablePixmap(pDst.pDrawable);
    pDstExaPix = mixin(ExaGetPixmapPriv!("pDstPix"));

    if (pMask && pMask.pDrawable) {
        pMaskPix = exaGetDrawablePixmap(pMask.pDrawable);
        pMaskExaPix = mixin(ExaGetPixmapPriv!("pMaskPix"));
    }

    /* Check whether the accelerator can use these pixmaps.
     * FIXME: If it cannot, use temporary pixmaps so that the drawing
     * happens within limits.
     */
    if (pDstExaPix.accel_blocked ||
        (pSrcExaPix && pSrcExaPix.accel_blocked) ||
        (pMaskExaPix && (pMaskExaPix.accel_blocked))) {
        return -1;
    }

    xDst += pDst.pDrawable.x;
    yDst += pDst.pDrawable.y;

    if (pMaskPix) {
        xMask += pMask.pDrawable.x;
        yMask += pMask.pDrawable.y;
    }

    if (pSrcPix) {
        xSrc += pSrc.pDrawable.x;
        ySrc += pSrc.pDrawable.y;
    }

    if (pExaScr.info.CheckComposite &&
        !(*pExaScr.info.CheckComposite) (op, pSrc, pMask, pDst)) {
        return -1;
    }

    if (!miComputeCompositeRegion(&region, pSrc, pMask, pDst,
                                  xSrc, ySrc, xMask, yMask, xDst, yDst,
                                  width, height))
        return 1;

    exaGetDrawableDeltas(pDst.pDrawable, pDstPix, &dst_off_x, &dst_off_y);

    RegionTranslate(&region, dst_off_x, dst_off_y);

    if (pExaScr.do_migration) {
        ExaMigrationRec[3] pixmaps = void;
        int i = 0;

        pixmaps[i].as_dst = TRUE;
        pixmaps[i].as_src = exaOpReadsDestination(op);
        pixmaps[i].pPix = pDstPix;
        pixmaps[i].pReg = pixmaps[0].as_src ? null : &region;
        i++;

        if (pSrcPix) {
            pixmaps[i].as_dst = FALSE;
            pixmaps[i].as_src = TRUE;
            pixmaps[i].pPix = pSrcPix;
            pixmaps[i].pReg = null;
            i++;
        }

        if (pMaskPix) {
            pixmaps[i].as_dst = FALSE;
            pixmaps[i].as_src = TRUE;
            pixmaps[i].pPix = pMaskPix;
            pixmaps[i].pReg = null;
            i++;
        }

        exaDoMigration(pixmaps.ptr, i, TRUE);
    }

    if (pSrcPix) {
        pSrcPix =
            exaGetOffscreenPixmap(pSrc.pDrawable, &src_off_x, &src_off_y);
        if (!pSrcPix) {
            RegionUninit(&region);
            return 0;
        }
    }

    if (pMaskPix) {
        pMaskPix = exaGetOffscreenPixmap(pMask.pDrawable, &mask_off_x,
                                         &mask_off_y);
        if (!pMaskPix) {
            RegionUninit(&region);
            return 0;
        }
    }

    if (!exaPixmapHasGpuCopy(pDstPix)) {
        RegionUninit(&region);
        return 0;
    }

    if (!(*pExaScr.info.PrepareComposite) (op, pSrc, pMask, pDst, pSrcPix,
                                             pMaskPix, pDstPix)) {
        RegionUninit(&region);
        return -1;
    }

    nbox = RegionNumRects(&region);
    pbox = RegionRects(&region);

    xMask = cast(short)(xMask + mask_off_x - xDst - dst_off_x);
    yMask = cast(short)(yMask + mask_off_y - yDst - dst_off_y);

    xSrc = cast(short)(xSrc + src_off_x - xDst - dst_off_x);
    ySrc = cast(short)(ySrc + src_off_y - yDst - dst_off_y);

    while (nbox--) {
        (*pExaScr.info.Composite) (pDstPix,
                                     pbox.x1 + xSrc,
                                     pbox.y1 + ySrc,
                                     pbox.x1 + xMask,
                                     pbox.y1 + yMask,
                                     pbox.x1,
                                     pbox.y1,
                                     pbox.x2 - pbox.x1, pbox.y2 - pbox.y1);
        pbox++;
    }
    (*pExaScr.info.DoneComposite) (pDstPix);
    exaMarkSync(pDst.pDrawable.pScreen);

    RegionUninit(&region);
    return 1;
}

/**
 * exaTryMagicTwoPassCompositeHelper implements PictOpOver using two passes of
 * simpler operations PictOpOutReverse and PictOpAdd. Mainly used for component
 * alpha and limited 1-tmu cards.
 *
 * From http://anholt.livejournal.com/32058.html:
 *
 * The trouble is that component-alpha rendering requires two different sources
 * for blending: one for the source value to the blender, which is the
 * per-channel multiplication of source and mask, and one for the source alpha
 * for multiplying with the destination channels, which is the multiplication
 * of the source channels by the mask alpha. So the equation for Over is:
 *
 * dst.A = src.A * mask.A + (1 - (src.A * mask.A)) * dst.A
 * dst.R = src.R * mask.R + (1 - (src.A * mask.R)) * dst.R
 * dst.G = src.G * mask.G + (1 - (src.A * mask.G)) * dst.G
 * dst.B = src.B * mask.B + (1 - (src.A * mask.B)) * dst.B
 *
 * But we can do some simpler operations, right? How about PictOpOutReverse,
 * which has a source factor of 0 and dest factor of (1 - source alpha). We
 * can get the source alpha value (srca.X = src.A * mask.X) out of the texture
 * blenders pretty easily. So we can do a component-alpha OutReverse, which
 * gets us:
 *
 * dst.A = 0 + (1 - (src.A * mask.A)) * dst.A
 * dst.R = 0 + (1 - (src.A * mask.R)) * dst.R
 * dst.G = 0 + (1 - (src.A * mask.G)) * dst.G
 * dst.B = 0 + (1 - (src.A * mask.B)) * dst.B
 *
 * OK. And if an op doesn't use the source alpha value for the destination
 * factor, then we can do the channel multiplication in the texture blenders
 * to get the source value, and ignore the source alpha that we wouldn't use.
 * We've supported this in the Radeon driver for a long time. An example would
 * be PictOpAdd, which does:
 *
 * dst.A = src.A * mask.A + dst.A
 * dst.R = src.R * mask.R + dst.R
 * dst.G = src.G * mask.G + dst.G
 * dst.B = src.B * mask.B + dst.B
 *
 * Hey, this looks good! If we do a PictOpOutReverse and then a PictOpAdd right
 * after it, we get:
 *
 * dst.A = src.A * mask.A + ((1 - (src.A * mask.A)) * dst.A)
 * dst.R = src.R * mask.R + ((1 - (src.A * mask.R)) * dst.R)
 * dst.G = src.G * mask.G + ((1 - (src.A * mask.G)) * dst.G)
 * dst.B = src.B * mask.B + ((1 - (src.A * mask.B)) * dst.B)
 */

private int exaTryMagicTwoPassCompositeHelper(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    mixin(ExaScreenPriv!("pDst.pDrawable.pScreen"));

    assert(op == PictOpOver);

    if (pExaScr.info.CheckComposite &&
        (!(*pExaScr.info.CheckComposite) (PictOpOutReverse, pSrc, pMask,
                                            pDst) ||
         !(*pExaScr.info.CheckComposite) (PictOpAdd, pSrc, pMask, pDst))) {
        return -1;
    }

    /* Now, we think we should be able to accelerate this operation. First,
     * composite the destination to be the destination times the source alpha
     * factors.
     */
    exaComposite(PictOpOutReverse, pSrc, pMask, pDst, xSrc, ySrc, xMask, yMask,
                 xDst, yDst, width, height);

    /* Then, add in the source value times the destination alpha factors (1.0).
     */
    exaComposite(PictOpAdd, pSrc, pMask, pDst, xSrc, ySrc, xMask, yMask,
                 xDst, yDst, width, height);

    return 1;
}

void exaComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height)
{
    mixin(ExaScreenPriv!("pDst.pDrawable.pScreen"));
    int ret = -1;
    Bool saveSrcRepeat = pSrc.repeat;
    Bool saveMaskRepeat = pMask ? pMask.repeat : 0;
    RegionRec region = void;

    if (pExaScr.swappedOut)
        goto fallback;

    /* Remove repeat in source if useless */
    if (pSrc.pDrawable && pSrc.repeat && !pSrc.transform && xSrc >= 0 &&
        (xSrc + width) <= pSrc.pDrawable.width && ySrc >= 0 &&
        (ySrc + height) <= pSrc.pDrawable.height)
        pSrc.repeat = 0;

    if (!pMask && !pSrc.alphaMap && !pDst.alphaMap &&
        (op == PictOpSrc || (op == PictOpOver && !PIXMAN_FORMAT_A(pSrc.format))))
    {
        if (pSrc.pDrawable ?
            (pSrc.pDrawable.width == 1 && pSrc.pDrawable.height == 1 &&
             pSrc.repeat) :
            (pSrc.pSourcePict.type == SourcePictTypeSolidFill)) {
            ret = exaTryDriverSolidFill(pSrc, pDst, xSrc, ySrc, xDst, yDst,
                                        width, height);
            if (ret == 1)
                goto done;
        }
        else if (pSrc.pDrawable && !pSrc.transform &&
                 ((op == PictOpSrc &&
                   (pSrc.format == pDst.format ||
                    (PIXMAN_FORMAT_COLOR(pDst.format) &&
                     PIXMAN_FORMAT_COLOR(pSrc.format) &&
                     pDst.format == PIXMAN_FORMAT(PIXMAN_FORMAT_BPP(pSrc.format),
                                                 PIXMAN_FORMAT_TYPE(pSrc.format),
                                                 0,
                                                 PIXMAN_FORMAT_R(pSrc.format),
                                                 PIXMAN_FORMAT_G(pSrc.format),
                                                 PIXMAN_FORMAT_B(pSrc.format)))))
                  || (op == PictOpOver && pSrc.format == pDst.format &&
                      !PIXMAN_FORMAT_A(pSrc.format)))) {
            if (!pSrc.repeat && xSrc >= 0 && ySrc >= 0 &&
                (xSrc + width <= pSrc.pDrawable.width) &&
                (ySrc + height <= pSrc.pDrawable.height)) {
                Bool suc = void;

                xDst += pDst.pDrawable.x;
                yDst += pDst.pDrawable.y;
                xSrc += pSrc.pDrawable.x;
                ySrc += pSrc.pDrawable.y;

                if (!miComputeCompositeRegion(&region, pSrc, pMask, pDst,
                                              xSrc, ySrc, xMask, yMask, xDst,
                                              yDst, width, height))
                    goto done;

                suc = exaHWCopyNtoN(pSrc.pDrawable, pDst.pDrawable, null,
                                    RegionRects(&region),
                                    RegionNumRects(&region), xSrc - xDst,
                                    ySrc - yDst, FALSE, FALSE);
                RegionUninit(&region);

                /* Reset values to their original values. */
                xDst -= pDst.pDrawable.x;
                yDst -= pDst.pDrawable.y;
                xSrc -= pSrc.pDrawable.x;
                ySrc -= pSrc.pDrawable.y;

                if (!suc)
                    goto fallback;

                goto done;
            }

            if (pSrc.repeat && pSrc.repeatType == RepeatNormal &&
                pSrc.pDrawable.type == DRAWABLE_PIXMAP) {
                xPoint patOrg = void;

                /* Let's see if the driver can do the repeat in one go */
                if (pExaScr.info.PrepareComposite && !pSrc.alphaMap &&
                    !pDst.alphaMap) {
                    ret = exaTryDriverComposite(op, pSrc, pMask, pDst, xSrc,
                                                ySrc, xMask, yMask, xDst, yDst,
                                                width, height);
                    if (ret == 1)
                        goto done;
                }

                /* Now see if we can use exaFillRegionTiled() */
                xDst += pDst.pDrawable.x;
                yDst += pDst.pDrawable.y;
                xSrc += pSrc.pDrawable.x;
                ySrc += pSrc.pDrawable.y;

                if (!miComputeCompositeRegion(&region, pSrc, pMask, pDst, xSrc,
                                              ySrc, xMask, yMask, xDst, yDst,
                                              width, height))
                    goto done;

                /* pattern origin is the point in the destination drawable
                 * corresponding to (0,0) in the source */
                patOrg.x = cast(short)(xDst - xSrc);
                patOrg.y = cast(short)(yDst - ySrc);

                ret = exaFillRegionTiled(pDst.pDrawable, &region,
                                         cast(PixmapPtr) pSrc.pDrawable,
                                         &patOrg, FB_ALLONES, GXcopy, CT_NONE);

                RegionUninit(&region);

                if (ret)
                    goto done;

                /* Let's be correct and restore the variables to their original state. */
                xDst -= pDst.pDrawable.x;
                yDst -= pDst.pDrawable.y;
                xSrc -= pSrc.pDrawable.x;
                ySrc -= pSrc.pDrawable.y;
            }
        }
    }

    /* Remove repeat in mask if useless */
    if (pMask && pMask.pDrawable && pMask.repeat && !pMask.transform &&
        xMask >= 0 && (xMask + width) <= pMask.pDrawable.width &&
        yMask >= 0 && (yMask + height) <= pMask.pDrawable.height)
        pMask.repeat = 0;

    if (pExaScr.info.PrepareComposite &&
        !pSrc.alphaMap && (!pMask || !pMask.alphaMap) && !pDst.alphaMap) {
        Bool isSrcSolid = void;

        ret = exaTryDriverComposite(op, pSrc, pMask, pDst, xSrc, ySrc, xMask,
                                    yMask, xDst, yDst, width, height);
        if (ret == 1)
            goto done;

        /* For generic masks and solid src pictures, mach64 can do Over in two
         * passes, similar to the component-alpha case.
         */
        isSrcSolid = pSrc.pDrawable ?
            (pSrc.pDrawable.width == 1 && pSrc.pDrawable.height == 1 &&
             pSrc.repeat) :
            (pSrc.pSourcePict.type == SourcePictTypeSolidFill);

        /* If we couldn't do the Composite in a single pass, and it was a
         * component-alpha Over, see if we can do it in two passes with
         * an OutReverse and then an Add.
         */
        if (ret == -1 && op == PictOpOver && pMask &&
            (pMask.componentAlpha || isSrcSolid)) {
            ret = exaTryMagicTwoPassCompositeHelper(op, pSrc, pMask, pDst,
                                                    xSrc, ySrc,
                                                    xMask, yMask, xDst, yDst,
                                                    width, height);
            if (ret == 1)
                goto done;
        }
    }

 fallback:
static if (DEBUG_TRACE_FALL) {
    exaPrintCompositeFallback(op, pSrc, pMask, pDst);
}

    ExaCheckComposite(op, pSrc, pMask, pDst, xSrc, ySrc,
                      xMask, yMask, xDst, yDst, width, height);

 done:
    pSrc.repeat = saveSrcRepeat;
    if (pMask)
        pMask.repeat = saveMaskRepeat;
}

/**
 * Same as miCreateAlphaPicture, except it uses ExaCheckPolyFillRect instead
 * of PolyFillRect to initialize the pixmap after creating it, to prevent
 * the pixmap from being migrated.
 *
 * See the comments about exaTrapezoids and exaTriangles.
 */
private PicturePtr exaCreateAlphaPicture(ScreenPtr pScreen, PicturePtr pDst, PictFormatPtr pPictFormat, CARD16 width, CARD16 height)
{
    PixmapPtr pPixmap = void;
    PicturePtr pPicture = void;
    GCPtr pGC = void;
    int error = void;
    xRectangle rect = void;

    if (width > 32767 || height > 32767)
        return null;

    if (!pPictFormat) {
        if (pDst.polyEdge == PolyEdgeSharp)
            pPictFormat = PictureMatchFormat(pScreen, 1, PIXMAN_a1);
        else
            pPictFormat = PictureMatchFormat(pScreen, 8, PIXMAN_a8);
        if (!pPictFormat)
            return null;
    }

    pPixmap = (*pScreen.CreatePixmap) (pScreen, width, height,
                                        pPictFormat.depth, 0);
    if (!pPixmap)
        return null;
    pGC = GetScratchGC(pPixmap.drawable.depth, pScreen);
    if (!pGC) {
        dixDestroyPixmap(pPixmap, 0);
        return null;
    }
    ValidateGC(&pPixmap.drawable, pGC);
    rect.x = 0;
    rect.y = 0;
    rect.width = width;
    rect.height = height;
    ExaCheckPolyFillRect(&pPixmap.drawable, pGC, 1, &rect);
    exaPixmapDirty(pPixmap, 0, 0, width, height);
    FreeScratchGC(pGC);
    pPicture = CreatePicture(0, &pPixmap.drawable, pPictFormat,
                             0, null, serverClient, &error);
    dixDestroyPixmap(pPixmap, 0);
    return pPicture;
}

/**
 * exaTrapezoids is essentially a copy of miTrapezoids that uses
 * exaCreateAlphaPicture instead of miCreateAlphaPicture.
 *
 * The problem with miCreateAlphaPicture is that it calls PolyFillRect
 * to initialize the contents after creating the pixmap, which
 * causes the pixmap to be moved in for acceleration. The subsequent
 * call to RasterizeTrapezoid won't be accelerated however, which
 * forces the pixmap to be moved out again.
 *
 * exaCreateAlphaPicture avoids this roundtrip by using ExaCheckPolyFillRect
 * to initialize the contents.
 */
void exaTrapezoids(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntrap, xTrapezoid* traps)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    BoxRec bounds = void;

    if (maskFormat) {
        PicturePtr pPicture = void;
        INT16 xDst = void, yDst = void;
        INT16 xRel = void, yRel = void;

        miTrapezoidBounds(ntrap, traps, &bounds);

        if (bounds.y1 >= bounds.y2 || bounds.x1 >= bounds.x2)
            return;

        xDst = cast(short)traps[0].left.p1.x >> 16;
        yDst = cast(short)traps[0].left.p1.y >> 16;

        pPicture = exaCreateAlphaPicture(pScreen, pDst, maskFormat,
                                         cast(short)(bounds.x2 - bounds.x1),
                                         cast(short)(bounds.y2 - bounds.y1));
        if (!pPicture)
            return;

        exaPrepareAccess(pPicture.pDrawable, EXA_PREPARE_DEST);
        for (; ntrap; ntrap--, traps++)
            if (mixin(xTrapezoidValid!("traps")))
                (*ps.RasterizeTrapezoid) (pPicture, traps, -bounds.x1, -bounds.y1);
        exaFinishAccess(pPicture.pDrawable, EXA_PREPARE_DEST);

        xRel = cast(short)(bounds.x1 + xSrc - xDst);
        yRel = cast(short)(bounds.y1 + ySrc - yDst);
        CompositePicture(op, pSrc, pPicture, pDst,
                         xRel, yRel, 0, 0, bounds.x1, bounds.y1,
                         cast(short)(bounds.x2 - bounds.x1), cast(short)(bounds.y2 - bounds.y1));
        FreePicture(pPicture, 0);
    }
    else {
        if (pDst.polyEdge == PolyEdgeSharp)
            maskFormat = PictureMatchFormat(pScreen, 1, PIXMAN_a1);
        else
            maskFormat = PictureMatchFormat(pScreen, 8, PIXMAN_a8);
        for (; ntrap; ntrap--, traps++)
            exaTrapezoids(op, pSrc, pDst, maskFormat, xSrc, ySrc, 1, traps);
    }
}

/**
 * exaTriangles is essentially a copy of miTriangles that uses
 * exaCreateAlphaPicture instead of miCreateAlphaPicture.
 *
 * The problem with miCreateAlphaPicture is that it calls PolyFillRect
 * to initialize the contents after creating the pixmap, which
 * causes the pixmap to be moved in for acceleration. The subsequent
 * call to AddTriangles won't be accelerated however, which forces the pixmap
 * to be moved out again.
 *
 * exaCreateAlphaPicture avoids this roundtrip by using ExaCheckPolyFillRect
 * to initialize the contents.
 */
void exaTriangles(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntri, xTriangle* tris)
{
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    BoxRec bounds = void;

    if (maskFormat) {
        PicturePtr pPicture = void;
        INT16 xDst = void, yDst = void;
        INT16 xRel = void, yRel = void;

        miTriangleBounds(ntri, tris, &bounds);

        if (bounds.y1 >= bounds.y2 || bounds.x1 >= bounds.x2)
            return;

        xDst = cast(short)tris[0].p1.x >> 16;
        yDst = cast(short)tris[0].p1.y >> 16;

        pPicture = exaCreateAlphaPicture(pScreen, pDst, maskFormat,
                                         cast(short)(bounds.x2 - bounds.x1),
                                         cast(short)(bounds.y2 - bounds.y1));
        if (!pPicture)
            return;

        exaPrepareAccess(pPicture.pDrawable, EXA_PREPARE_DEST);
        (*ps.AddTriangles) (pPicture, cast(short)-bounds.x1, cast(short)-bounds.y1, ntri, tris);
        exaFinishAccess(pPicture.pDrawable, EXA_PREPARE_DEST);

        xRel = cast(short)(bounds.x1 + xSrc - xDst);
        yRel = cast(short)(bounds.y1 + ySrc - yDst);
        CompositePicture(op, pSrc, pPicture, pDst,
                         xRel, yRel, 0, 0, bounds.x1, bounds.y1,
                         cast(short)(bounds.x2 - bounds.x1), cast(short)(bounds.y2 - bounds.y1));
        FreePicture(pPicture, 0);
    }
    else {
        if (pDst.polyEdge == PolyEdgeSharp)
            maskFormat = PictureMatchFormat(pScreen, 1, PIXMAN_a1);
        else
            maskFormat = PictureMatchFormat(pScreen, 8, PIXMAN_a8);

        for (; ntri; ntri--, tris++)
            exaTriangles(op, pSrc, pDst, maskFormat, xSrc, ySrc, 1, tris);
    }
}
