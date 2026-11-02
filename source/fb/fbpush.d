module fb.fbpush;
@nogc nothrow:
extern(C): __gshared:
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

import fb.fb_priv;
import fb.fbfill;
import fb.fb;

private void fbPushPattern(DrawablePtr pDrawable, GCPtr pGC, FbStip* src, FbStride srcStride, int srcX, int x, int y, int width, int height)
{
    FbStip* s = void; FbStip bitsMask = void, bitsMask0 = void, bits = void;
    int xspan = void;
    int w = void;
    int lenspan = void;

    src += srcX >> FB_STIP_SHIFT;
    srcX &= FB_STIP_MASK;

    bitsMask0 = mixin(FbStipMask!("srcX", "1"));

    while (height--) {
        bitsMask = bitsMask0;
        w = width;
        s = src;
        src += srcStride;
        bits = mixin(READ!("s++"));
        xspan = x;
        while (w) {
            if (bits & bitsMask) {
                lenspan = 0;
                do {
                    lenspan++;
                    if (lenspan == w)
                        break;
                    bitsMask = mixin(FbStipRight!("bitsMask", "1"));
                    if (!bitsMask) {
                        bits = mixin(READ!("s++"));
                        bitsMask = mixin(FbBitsMask!("0", "1"));
                    }
                } while (bits & bitsMask);
                fbFill(pDrawable, pGC, xspan, y, lenspan, 1);
                xspan += lenspan;
                w -= lenspan;
            }
            else {
                do {
                    w--;
                    xspan++;
                    if (!w)
                        break;
                    bitsMask = mixin(FbStipRight!("bitsMask", "1"));
                    if (!bitsMask) {
                        bits = mixin(READ!("s++"));
                        bitsMask = mixin(FbBitsMask!("0", "1"));
                    }
                } while (!(bits & bitsMask));
            }
        }
        y++;
    }
}

private void fbPushFill(DrawablePtr pDrawable, GCPtr pGC, FbStip* src, FbStride srcStride, int srcX, int x, int y, int width, int height)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));

    if (pGC.fillStyle == FillSolid) {
        FbBits* dst = void;
        FbStride dstStride = void;
        int dstBpp = void;
        int dstXoff = void, dstYoff = void;
        int dstX = void;
        int dstWidth = void;

        mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
        dst = dst + (y + dstYoff) * dstStride;
        dstX = (x + dstXoff) * dstBpp;
        dstWidth = width * dstBpp;
        if (dstBpp == 1) {
            fbBltStip(src,
                      srcStride,
                      srcX,
                      cast(FbStip*) dst,
                      mixin(FbBitsStrideToStipStride!("dstStride")),
                      dstX,
                      dstWidth,
                      height,
                      mixin(FbStipple1Rop!("pGC.alu", "pGC.fgPixel")), pPriv.pm, dstBpp);
        }
        else {
            fbBltOne(src,
                     srcStride,
                     srcX,
                     dst,
                     dstStride,
                     dstX,
                     dstBpp,
                     dstWidth,
                     height,
                     pPriv.and, pPriv.xor,
                     mixin(fbAnd!("GXnoop", "cast(FbBits) 0", "FB_ALLONES")),
                     mixin(fbXor!("GXnoop", "cast(FbBits) 0", "FB_ALLONES")));
        }
        mixin(fbFinishAccess!("pDrawable"));
    }
    else {
        fbPushPattern(pDrawable, pGC, src, srcStride, srcX,
                      x, y, width, height);
    }
}

void fbPushImage(DrawablePtr pDrawable, GCPtr pGC, FbStip* src, FbStride srcStride, int srcX, int x, int y, int width, int height)
{
    RegionPtr pClip = mixin(fbGetCompositeClip!("pGC"));
    int nbox = void;
    BoxPtr pbox = void;
    int x1 = void, y1 = void, x2 = void, y2 = void;

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
        fbPushFill(pDrawable,
                   pGC,
                   src + (y1 - y) * srcStride,
                   srcStride, srcX + (x1 - x), x1, y1, x2 - x1, y2 - y1);
    }
}

void fbPushPixels(GCPtr pGC, PixmapPtr pBitmap, DrawablePtr pDrawable, int dx, int dy, int xOrg, int yOrg)
{
    FbStip* stip = void;
    FbStride stipStride = void;
    int stipBpp = void;
    int stipXoff = void, stipYoff = void;

    mixin(fbGetStipDrawable!("(&pBitmap.drawable)", "stip", "stipStride", "stipBpp", "stipXoff",
                      "stipYoff"));

    fbPushImage(pDrawable, pGC, stip, stipStride, 0, xOrg, yOrg, dx, dy);
}
