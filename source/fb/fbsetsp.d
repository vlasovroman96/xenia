module fbsetsp;
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

import fb.fb_priv;
import fb.fb;

void fbSetSpans(DrawablePtr pDrawable, GCPtr pGC, char* src, xPoint* ppt, int* pwidth, int nspans, int fSorted)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    RegionPtr pClip = mixin(fbGetCompositeClip!("pGC"));
    FbBits* dst = void, d = void, s = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    BoxPtr pbox = void;
    int n = void;
    int xoff = void;
    int x1 = void, x2 = void;

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    while (nspans--) {
        d = dst + (ppt.y + dstYoff) * dstStride;
        xoff = cast(int) ((cast(c_long) src) & (FB_MASK >> 3));
        s = cast(FbBits*) (src - xoff);
        xoff <<= 3;
        n = RegionNumRects(pClip);
        pbox = RegionRects(pClip);
        while (n--) {
            if (pbox.y1 > ppt.y)
                break;
            if (pbox.y2 > ppt.y) {
                x1 = ppt.x;
                x2 = x1 + *pwidth;
                if (pbox.x1 > x1)
                    x1 = pbox.x1;
                if (pbox.x2 < x2)
                    x2 = pbox.x2;
                if (x1 < x2)
                    fbBlt(cast(FbBits*) s,
                          0,
                          (x1 - ppt.x) * dstBpp + xoff,
                          d,
                          dstStride,
                          (x1 + dstXoff) * dstBpp,
                          (x2 - x1) * dstBpp,
                          1, pGC.alu, pPriv.pm, dstBpp, False, False);
            }
        }
        src += PixmapBytePad(*pwidth, pDrawable.depth);
        ppt++;
        pwidth++;
    }
    fbValidateDrawable(pDrawable);
    mixin(fbFinishAccess!("pDrawable"));
}
