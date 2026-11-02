module fbimage;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 1998 Keith Packard
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

import core.stdc.string;

import fb.fb_priv;
import fb.fbutil;
import fb.fb;
import fb.fbrop;

void fbPutImage(DrawablePtr pDrawable, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* pImage)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    c_ulong i = void;
    FbStride srcStride = void;
    FbStip* src = cast(FbStip*) pImage;

    x += pDrawable.x;
    y += pDrawable.y;

    switch (format) {
    case XYBitmap:
        srcStride = cast(int)(mixin(BitmapBytePad!("w + leftPad")) / FbStip.sizeof);
        fbPutXYImage(pDrawable,
                     mixin(fbGetCompositeClip!("pGC")),
                     pPriv.fg,
                     pPriv.bg,
                     pPriv.pm,
                     pGC.alu, TRUE, x, y, w, h, src, srcStride, leftPad);
        break;
    case XYPixmap:
        srcStride = cast(int)(mixin(BitmapBytePad!("w + leftPad")) / FbStip.sizeof);
        for (i = cast(c_ulong) 1 << (pDrawable.depth - 1); i; i >>= 1) {
            if (i & pGC.planemask) {
                fbPutXYImage(pDrawable,
                             mixin(fbGetCompositeClip!("pGC")),
                             FB_ALLONES,
                             0,
                             fbReplicatePixel(cast(uint)i, pDrawable.bitsPerPixel),
                             pGC.alu,
                             TRUE, x, y, w, h, src, srcStride, leftPad);
            }
            src += srcStride * h;
        }
        break;
    case ZPixmap:
        srcStride = cast(int)(PixmapBytePad(w, pDrawable.depth) / FbStip.sizeof);
        fbPutZImage(pDrawable, mixin(fbGetCompositeClip!("pGC")),
                    pGC.alu, pPriv.pm, x, y, w, h, src, srcStride);
                    goto default;
    default: break;}
}

void fbPutZImage(DrawablePtr pDrawable, RegionPtr pClip, int alu, FbBits pm, int x, int y, int width, int height, FbStip* src, FbStride srcStride)
{
    FbStip* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    int nbox = void;
    BoxPtr pbox = void;
    int x1 = void, y1 = void, x2 = void, y2 = void;

    mixin(fbGetStipDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));

    for (nbox = RegionNumRects(pClip),
         pbox = RegionRects(pClip); nbox--; pbox++) {
        x1 = x;
        y1 = y;
        x2 = x + width;
        y2 = y + height;
        if (x1 < pbox.x1)
            x1 = pbox.x1;
        if (y1 < pbox.y1)
            y1 = pbox.y1;
        if (x2 > pbox.x2)
            x2 = pbox.x2;
        if (y2 > pbox.y2)
            y2 = pbox.y2;
        if (x1 >= x2 || y1 >= y2)
            continue;
        fbBltStip(src + (y1 - y) * srcStride,
                  srcStride,
                  (x1 - x) * dstBpp,
                  dst + (y1 + dstYoff) * dstStride,
                  dstStride,
                  (x1 + dstXoff) * dstBpp,
                  (x2 - x1) * dstBpp, (y2 - y1), alu, pm, dstBpp);
    }

    mixin(fbFinishAccess!("pDrawable"));
}

void fbPutXYImage(DrawablePtr pDrawable, RegionPtr pClip, FbBits fg, FbBits bg, FbBits pm, int alu, Bool opaque, int x, int y, int width, int height, FbStip* src, FbStride srcStride, int srcX)
{
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    int nbox = void;
    BoxPtr pbox = void;
    int x1 = void, y1 = void, x2 = void, y2 = void;
    FbBits fgand = 0, fgxor = 0, bgand = 0, bgxor = 0;

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));

    if (dstBpp == 1) {
        if (opaque)
            alu = mixin(FbOpaqueStipple1Rop!("alu", "fg", "bg"));
        else
            alu = mixin(FbStipple1Rop!("alu", "fg"));
    }
    else {
        fgand = mixin(fbAnd!("alu", "fg", "pm"));
        fgxor = mixin(fbXor!("alu", "fg", "pm"));
        if (opaque) {
            bgand = mixin(fbAnd!("alu", "bg", "pm"));
            bgxor = mixin(fbXor!("alu", "bg", "pm"));
        }
        else {
            bgand = mixin(fbAnd!("GXnoop", "cast(FbBits) 0", "FB_ALLONES"));
            bgxor = mixin(fbXor!("GXnoop", "cast(FbBits) 0", "FB_ALLONES"));
        }
    }

    for (nbox = RegionNumRects(pClip),
         pbox = RegionRects(pClip); nbox--; pbox++) {
        x1 = x;
        y1 = y;
        x2 = x + width;
        y2 = y + height;
        if (x1 < pbox.x1)
            x1 = pbox.x1;
        if (y1 < pbox.y1)
            y1 = pbox.y1;
        if (x2 > pbox.x2)
            x2 = pbox.x2;
        if (y2 > pbox.y2)
            y2 = pbox.y2;
        if (x1 >= x2 || y1 >= y2)
            continue;
        if (dstBpp == 1) {
            fbBltStip(src + (y1 - y) * srcStride,
                      srcStride,
                      (x1 - x) + srcX,
                      cast(FbStip*) (dst + (y1 + dstYoff) * dstStride),
                      mixin(FbBitsStrideToStipStride!("dstStride")),
                      (x1 + dstXoff) * dstBpp,
                      (x2 - x1) * dstBpp, (y2 - y1), alu, pm, dstBpp);
        }
        else {
            fbBltOne(src + (y1 - y) * srcStride,
                     srcStride,
                     (x1 - x) + srcX,
                     dst + (y1 + dstYoff) * dstStride,
                     dstStride,
                     (x1 + dstXoff) * dstBpp,
                     dstBpp,
                     (x2 - x1) * dstBpp, (y2 - y1), fgand, fgxor, bgand, bgxor);
        }
    }

    mixin(fbFinishAccess!("pDrawable"));
}

void fbGetImage(DrawablePtr pDrawable, int x, int y, int w, int h, uint format, c_ulong planeMask, char* d)
{
    FbBits* src = void;
    FbStride srcStride = void;
    int srcBpp = void;
    int srcXoff = void, srcYoff = void;
    FbStip* dst = void;
    FbStride dstStride = void;

    /*
     * XFree86 DDX empties the root borderClip when the VT is
     * switched away; this checks for that case
     */
    if (!mixin(fbDrawableEnabled!("pDrawable")))
        return;

    mixin(fbGetDrawable!("pDrawable", "src", "srcStride", "srcBpp", "srcXoff", "srcYoff"));

    x += pDrawable.x;
    y += pDrawable.y;

    dst = cast(FbStip*) d;
    if (format == ZPixmap || srcBpp == 1) {
        FbBits pm = void;

        pm = fbReplicatePixel(cast(uint)planeMask, srcBpp);
        dstStride = PixmapBytePad(w, pDrawable.depth);
        dstStride /= FbStip.sizeof;
        fbBltStip(cast(FbStip*) (src + (y + srcYoff) * srcStride),
                  mixin(FbBitsStrideToStipStride!("srcStride")),
                  (x + srcXoff) * srcBpp,
                  dst, dstStride, 0, w * srcBpp, h, GXcopy, FB_ALLONES, srcBpp);

        if (pm != FB_ALLONES) {
            for (int i = 0; i < dstStride * h; i++)
                dst[i] &= pm;
        }
    }
    else {
        dstStride = cast(int)(mixin(BitmapBytePad!"w") / FbStip.sizeof);
        fbBltPlane(src + (y + srcYoff) * srcStride,
                   srcStride,
                   (x + srcXoff) * srcBpp,
                   srcBpp,
                   dst,
                   dstStride,
                   0,
                   w * srcBpp, h,
                   mixin(fbAndStip!("GXcopy", "FB_STIP_ALLONES", "FB_STIP_ALLONES")),
                   mixin(fbXorStip!("GXcopy", "FB_STIP_ALLONES", "FB_STIP_ALLONES")),
                   mixin(fbAndStip!("GXcopy", "0", "FB_STIP_ALLONES")),
                   mixin(fbXorStip!("GXcopy", "0", "FB_STIP_ALLONES")), cast(uint)planeMask);
    }

    mixin(fbFinishAccess!("pDrawable"));
}
