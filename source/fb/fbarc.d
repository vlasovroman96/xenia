module fbarc;
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
import build.xorg_config;

import fb.fb_priv;

import include.mizerarc;
import core.stdc.limits;
import mizerarc;
import fb.fbbits;;
import mi.miarc;
import fb.fb;


alias FbArc = void function(FbBits* dst, FbStride dstStride, int dstBpp, xArc* arc, int dx, int dy, FbBits and, FbBits xor);

void fbPolyArc(DrawablePtr pDrawable, GCPtr pGC, int narcs, xArc* parcs)
{
    FbArc arc = void;

    if (pGC.lineWidth == 0) {
        arc = null;
        if (pGC.lineStyle == LineSolid && pGC.fillStyle == FillSolid) {
            switch (pDrawable.bitsPerPixel) {
            case 8:
                arc = &fbArc8;
                break;
            case 16:
                arc = &fbArc16;
                break;
            case 32:
                arc = &fbArc32;
                break;
            default: break;}
        }
        if (arc) {
            FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
            FbBits* dst = void;
            FbStride dstStride = void;
            int dstBpp = void;
            int dstXoff = void, dstYoff = void;
            BoxRec box = void;
            int x2 = void, y2 = void;
            RegionPtr cclip = void;

static if (FB_ACCESS_WRAPPER) {
            int wrapped = 1;
}

            cclip = mixin(fbGetCompositeClip!("pGC"));
            mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
            while (narcs--) {
                if (mixin(miCanZeroArc!("parcs"))) {
                    box.x1 = cast(short)(parcs.x + pDrawable.x);
                    box.y1 = cast(short)(parcs.y + pDrawable.y);
                    /*
                     * Because box.x2 and box.y2 get truncated to 16 bits, and the
                     * RECT_IN_REGION test treats the resulting number as a signed
                     * integer, the RECT_IN_REGION test alone can go the wrong way.
                     * This can result in a server crash because the rendering
                     * routines in this file deal directly with cpu addresses
                     * of pixels to be stored, and do not clip or otherwise check
                     * that all such addresses are within their respective pixmaps.
                     * So we only allow the RECT_IN_REGION test to be used for
                     * values that can be expressed correctly in a signed short.
                     */
                    x2 = cast(short)(box.x1 + cast(int) parcs.width + 1);
                    box.x2 = cast(short)(x2);
                    y2 = cast(short)(box.y1 + cast(int) parcs.height + 1);
                    box.y2 = cast(short)(y2);
                    if ((x2 <= SHRT_MAX) && (y2 <= SHRT_MAX) &&
                        (RegionContainsRect(cclip, &box) == rgnIN)) {
static if (FB_ACCESS_WRAPPER) {
                        if (!wrapped) {
                            fbPrepareAccess(pDrawable);
                            wrapped = 1;
                        }
}
                        (*arc) (dst, dstStride, dstBpp,
                                parcs, pDrawable.x + dstXoff,
                                pDrawable.y + dstYoff, pPriv.and, pPriv.xor);
                    }
                    else {
static if (FB_ACCESS_WRAPPER) {
                        if (wrapped) {
                            mixin(fbFinishAccess!("pDrawable"));
                            wrapped = 0;
                        }
}
                        miZeroPolyArc(pDrawable, pGC, 1, parcs);
                    }
                }
                else {
static if (FB_ACCESS_WRAPPER) {
                    if (wrapped) {
                        mixin(fbFinishAccess!("pDrawable"));
                        wrapped = 0;
                    }
}
                    miPolyArc(pDrawable, pGC, 1, parcs);
                }
                parcs++;
            }
static if (FB_ACCESS_WRAPPER) {
            if (wrapped) {
                mixin(fbFinishAccess!("pDrawable"));
                wrapped = 0;
            }
}
        }
        else
            miZeroPolyArc(pDrawable, pGC, narcs, parcs);
    }
    else
        miPolyArc(pDrawable, pGC, narcs, parcs);
}
