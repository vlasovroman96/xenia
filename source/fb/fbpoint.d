module fbpoint;
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
import fb.fbbits;;
import fb.fb;

alias FbDots = extern(C) void function(FbBits* dst, FbStride dstStride, int dstBpp, BoxPtr pBox, xPoint* pts, int npt, int xorg, int yorg, int xoff, int yoff, FbBits and, FbBits xor) @nogc nothrow;

private void fbDots(FbBits* dstOrig, FbStride dstStride, int dstBpp, BoxPtr pBox, xPoint* pts, int npt, int xorg, int yorg, int xoff, int yoff, FbBits andOrig, FbBits xorOrig)
{
    FbStip* dst = cast(FbStip*) dstOrig;
    int x1 = void, y1 = void, x2 = void, y2 = void;
    int x = void, y = void;
    FbStip* d = void;
    FbStip and = andOrig;
    FbStip xor = xorOrig;

    dstStride = mixin(FbBitsStrideToStipStride!("dstStride"));
    x1 = pBox.x1;
    y1 = pBox.y1;
    x2 = pBox.x2;
    y2 = pBox.y2;
    while (npt--) {
        x = pts.x + xorg;
        y = pts.y + yorg;
        pts++;
        if (x1 <= x && x < x2 && y1 <= y && y < y2) {
            FbStip mask = void;
            x = (x + xoff) * dstBpp;
            d = dst + ((y + yoff) * dstStride) + (x >> FB_STIP_SHIFT);
            x &= FB_STIP_MASK;

            mask = mixin(FbStipMask!("x", "dstBpp"));
            mixin(WRITE!("d", FbDoMaskRRop!(READ!("d"), "and", "xor", "mask"))~`;`);
        }
    }
}

void fbPolyPoint(DrawablePtr pDrawable, GCPtr pGC, int mode, int nptInit, xPoint* pptInit)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    RegionPtr pClip = mixin(fbGetCompositeClip!("pGC"));
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    FbDots dots = void;
    FbBits and = void, xor = void;
    xPoint* ppt = void;
    int npt = void;
    BoxPtr pBox = void;
    int nBox = void;

    /* make pointlist origin relative */
    ppt = pptInit;
    npt = nptInit;
    if (mode == CoordModePrevious) {
        npt--;
        while (npt--) {
            ppt++;
            ppt.x += (ppt - 1).x;
            ppt.y += (ppt - 1).y;
        }
    }
    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    and = pPriv.and;
    xor = pPriv.xor;
    dots = &fbDots;
    switch (dstBpp) {
    case 8:
        dots = &fbDots8;
        break;
    case 16:
        dots = &fbDots16;
        break;
    case 32:
        dots = &fbDots32;
        break;
    default: break;}
    for (nBox = RegionNumRects(pClip), pBox = RegionRects(pClip);
         nBox--; pBox++)
        (*dots) (dst, dstStride, dstBpp, pBox, pptInit, nptInit,
                 pDrawable.x, pDrawable.y, dstXoff, dstYoff, and, xor);
    mixin(fbFinishAccess!("pDrawable"));
}
