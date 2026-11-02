module fbseg;
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

import core.stdc.stdlib;

import fb.fb_priv;
import fb.fbbits;;

import include.miline;
import fb.fbbitsh;
import fb.fbfill;
import dix.gc;
import core.stdc.config;
import mi.mizerclip;
import fb.fb;
import fb.fbrop;

enum string fbBresShiftMask(string mask,string dir,string bpp) = `((` ~ bpp ~ ` == FB_STIP_UNIT) ? 0 : 
					((` ~ dir ~ ` < 0) ? `~FbStipLeft!(mask, bpp)~` : `~
					 FbStipRight!(mask, bpp)~`))`;

private void fbBresSolid(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x1, int y1, int e, int e1, int e3, int len)
{
    FbStip* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    FbStip and = cast(FbStip) pPriv.and;
    FbStip xor = cast(FbStip) pPriv.xor;
    FbStip mask = void, mask0 = void;
    FbStip bits = void;

    mixin(fbGetStipDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    dst += ((y1 + dstYoff) * dstStride);
    x1 = (x1 + dstXoff) * dstBpp;
    dst += x1 >> FB_STIP_SHIFT;
    x1 &= FB_STIP_MASK;
    mask0 = mixin(FbStipMask!("0", "dstBpp"));
    mask = mixin(FbStipRight!("mask0", "x1"));
    if (signdx < 0)
        mask0 = mixin(FbStipRight!("mask0", "FB_STIP_UNIT - dstBpp"));
    if (signdy < 0)
        dstStride = -dstStride;
    if (axis == X_AXIS) {
        bits = 0;
        while (len--) {
            bits |= mask;
            mask = mixin(fbBresShiftMask!(`mask`, `signdx`, `dstBpp`));
            if (!mask) {
                mixin(WRITE!("dst", FbDoMaskRRop!(READ!("dst"), "and", "xor", "bits"))~";");
                bits = 0;
                dst += signdx;
                mask = mask0;
            }
            e += e1;
            if (e >= 0) {
                if (bits) {
                    mixin(WRITE!("dst", FbDoMaskRRop!(READ!("dst"), "and", "xor", "bits"))~";");
                    bits = 0;
                }
                dst += dstStride;
                e += e3;
            }
        }
        if (bits)
            mixin(WRITE!("dst", FbDoMaskRRop!(READ!("dst"), "and", "xor", "bits"))~";");
    }
    else {
        while (len--) {
            mixin(WRITE!("dst", FbDoMaskRRop!(READ!("dst"), "and", "xor", "mask"))~";");
            dst += dstStride;
            e += e1;
            if (e >= 0) {
                e += e3;
                mask = mixin(fbBresShiftMask!(`mask`, `signdx`, `dstBpp`));
                if (!mask) {
                    dst += signdx;
                    mask = mask0;
                }
            }
        }
    }

    mixin(fbFinishAccess!("pDrawable"));
}

private void fbBresDash(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x1, int y1, int e, int e1, int e3, int len)
{
    FbStip* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    FbStip and = cast(FbStip) pPriv.and;
    FbStip xor = cast(FbStip) pPriv.xor;
    FbStip bgand = cast(FbStip) pPriv.bgand;
    FbStip bgxor = cast(FbStip) pPriv.bgxor;
    FbStip mask = void, mask0 = void;

    mixin(FbDashDeclare);
    int dashlen = void;
    Bool even = void;
    Bool doOdd = void;

    mixin(fbGetStipDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));
    doOdd = pGC.lineStyle == LineDoubleDash;

    mixin(FbDashInit!("pGC", "pPriv", "dashOffset", "dashlen", "even"));

    dst += ((y1 + dstYoff) * dstStride);
    x1 = (x1 + dstXoff) * dstBpp;
    dst += x1 >> FB_STIP_SHIFT;
    x1 &= FB_STIP_MASK;
    mask0 = mixin(FbStipMask!("0", "dstBpp"));
    mask = mixin(FbStipRight!("mask0", "x1"));
    if (signdx < 0)
        mask0 = mixin(FbStipRight!("mask0", "FB_STIP_UNIT - dstBpp"));
    if (signdy < 0)
        dstStride = -dstStride;
    while (len--) {
        if (even)
            mixin(WRITE!("dst", FbDoMaskRRop!(READ!("dst"), "and", "xor", "mask"))~";");
        else if (doOdd)
            mixin(WRITE!("dst", FbDoMaskRRop!(READ!("dst"), "bgand", "bgxor", "mask"))~";");
        if (axis == X_AXIS) {
            mask = mixin(fbBresShiftMask!(`mask`, `signdx`, `dstBpp`));
            if (!mask) {
                dst += signdx;
                mask = mask0;
            }
            e += e1;
            if (e >= 0) {
                dst += dstStride;
                e += e3;
            }
        }
        else {
            dst += dstStride;
            e += e1;
            if (e >= 0) {
                e += e3;
                mask = mixin(fbBresShiftMask!(`mask`, `signdx`, `dstBpp`));
                if (!mask) {
                    dst += signdx;
                    mask = mask0;
                }
            }
        }
        mixin(FbDashStep!("dashlen", "even"));
    }

    mixin(fbFinishAccess!("pDrawable"));
}

private void fbBresFill(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x1, int y1, int e, int e1, int e3, int len)
{
    while (len--) {
        fbFill(pDrawable, pGC, x1, y1, 1, 1);
        if (axis == X_AXIS) {
            x1 += signdx;
            e += e1;
            if (e >= 0) {
                e += e3;
                y1 += signdy;
            }
        }
        else {
            y1 += signdy;
            e += e1;
            if (e >= 0) {
                e += e3;
                x1 += signdx;
            }
        }
    }
}

private void fbSetFg(DrawablePtr pDrawable, GCPtr pGC, Pixel fg)
{
    if (fg != pGC.fgPixel) {
        ChangeGCVal val = void;

        val.val = fg;
        ChangeGC(null, pGC, cast(uint)GCForeground, &val);
        ValidateGC(pDrawable, pGC);
    }
}

private void fbBresFillDash(DrawablePtr pDrawable, GCPtr pGC, int dashOffset, int signdx, int signdy, int axis, int x1, int y1, int e, int e1, int e3, int len)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));

    mixin(FbDashDeclare);
    int dashlen = void;
    Bool even = void;
    Bool doOdd = void;
    Bool doBg = void;
    Pixel fg = void, bg = void;

    fg = pGC.fgPixel;
    bg = pGC.bgPixel;

    /* whether to fill the odd dashes */
    doOdd = pGC.lineStyle == LineDoubleDash;
    /* whether to switch fg to bg when filling odd dashes */
    doBg = doOdd && (pGC.fillStyle == FillSolid ||
                     pGC.fillStyle == FillStippled);

    /* compute current dash position */
    mixin(FbDashInit!("pGC", "pPriv", "dashOffset", "dashlen", "even"));

    while (len--) {
        if (even || doOdd) {
            if (doBg) {
                if (even)
                    fbSetFg(pDrawable, pGC, fg);
                else
                    fbSetFg(pDrawable, pGC, bg);
            }
            fbFill(pDrawable, pGC, x1, y1, 1, 1);
        }
        if (axis == X_AXIS) {
            x1 += signdx;
            e += e1;
            if (e >= 0) {
                e += e3;
                y1 += signdy;
            }
        }
        else {
            y1 += signdy;
            e += e1;
            if (e >= 0) {
                e += e3;
                x1 += signdx;
            }
        }
        mixin(FbDashStep!("dashlen", "even"));
    }
    if (doBg)
        fbSetFg(pDrawable, pGC, fg);
}

/*
 * For drivers that want to bail drawing some lines, this
 * function takes care of selecting the appropriate rasterizer
 * based on the contents of the specified GC.
 */

private FbBres* fbSelectBres(DrawablePtr pDrawable, GCPtr pGC)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    int dstBpp = pDrawable.bitsPerPixel;
    FbBres* bres = void;

    if (pGC.lineStyle == LineSolid) {
        bres = &fbBresFill;
        if (pGC.fillStyle == FillSolid) {
            bres = &fbBresSolid;
            if (pPriv.and == 0) {
                switch (dstBpp) {
                case 8:
                    bres = &fbBresSolid8;
                    break;
                case 16:
                    bres = &fbBresSolid16;
                    break;
                case 32:
                    bres = &fbBresSolid32;
                    break;
                default: break;}
            }
        }
    }
    else {
        bres = &fbBresFillDash;
        if (pGC.fillStyle == FillSolid) {
            bres = &fbBresDash;
            if (pPriv.and == 0 &&
                (pGC.lineStyle == LineOnOffDash || pPriv.bgand == 0)) {
                switch (dstBpp) {
                case 8:
                    bres = &fbBresDash8;
                    break;
                case 16:
                    bres = &fbBresDash16;
                    break;
                case 32:
                    bres = &fbBresDash32;
                    break;

                default: break;}
            }
        }
    }
    return bres;
}

void fbSegment(DrawablePtr pDrawable, GCPtr pGC, int x1, int y1, int x2, int y2, Bool drawLast, int* dashOffset)
{
    FbBres* bres = void;
    RegionPtr pClip = mixin(fbGetCompositeClip!("pGC"));
    BoxPtr pBox = void;
    int nBox = void;
    int adx = void;                    /* abs values of dx and dy */
    int ady = void;
    int signdx = void;                 /* sign of dx and dy */
    int signdy = void;
    int e = void, e1 = void, e2 = void, e3 = void;          /* bresenham error and increments */
    int len = void;                    /* length of segment */
    int axis = void;                   /* major axis */
    int octant = void;
    int dashoff = void;
    int doff = void;
    uint bias = cast(uint)mixin(miGetZeroLineBias!("pDrawable.pScreen"));
    uint oc1 = void;           /* outcode of point 1 */
    uint oc2 = void;           /* outcode of point 2 */

    nBox = RegionNumRects(pClip);
    pBox = RegionRects(pClip);

    bres = fbSelectBres(pDrawable, pGC);

    mixin(CalcLineDeltas!("x1", "y1", "x2", "y2", "adx", "ady", "signdx", "signdy", "1", "1", "octant"));

    if (adx > ady) {
        axis = X_AXIS;
        e1 = ady << 1;
        e2 = e1 - (adx << 1);
        e = e1 - adx;
        len = adx;
    }
    else {
        axis = Y_AXIS;
        e1 = adx << 1;
        e2 = e1 - (ady << 1);
        e = e1 - ady;
        mixin(SetYMajorOctant!("octant"));
        len = ady;
    }

    mixin(FIXUP_ERROR!("e", "octant", "bias"));

    /*
     * Adjust error terms to compare against zero
     */
    e3 = e2 - e1;
    e = e - e1;

    /* we have bresenham parameters and two points.
       all we have to do now is clip and draw.
     */

    if (drawLast)
        len++;
    dashoff = *dashOffset;
    *dashOffset = dashoff + len;
    while (nBox--) {
        oc1 = 0;
        oc2 = 0;
        mixin(OUTCODES!("oc1", "x1", "y1", "pBox"));
        mixin(OUTCODES!("oc2", "x2", "y2", "pBox"));
        if ((oc1 | oc2) == 0) {
            (*bres) (pDrawable, pGC, dashoff,
                     signdx, signdy, axis, x1, y1, e, e1, e3, len);
            break;
        }
        else if (oc1 & oc2) {
            pBox++;
        }
        else {
            int new_x1 = x1, new_y1 = y1, new_x2 = x2, new_y2 = y2;
            int clip1 = 0, clip2 = 0;
            int clipdx = void, clipdy = void;
            int err = void;

            if (miZeroClipLine(pBox.x1, pBox.y1, pBox.x2 - 1,
                               pBox.y2 - 1,
                               &new_x1, &new_y1, &new_x2, &new_y2,
                               adx, ady, &clip1, &clip2,
                               octant, bias, oc1, oc2) == -1) {
                pBox++;
                continue;
            }

            if (axis == X_AXIS)
                len = abs(new_x2 - new_x1);
            else
                len = abs(new_y2 - new_y1);
            if (clip2 != 0 || drawLast)
                len++;
            if (len) {
                /* unwind bresenham error term to first point */
                doff = dashoff;
                err = e;
                if (clip1) {
                    clipdx = abs(new_x1 - x1);
                    clipdy = abs(new_y1 - y1);
                    if (axis == X_AXIS) {
                        doff += clipdx;
                        err += e3 * clipdy + e1 * clipdx;
                    }
                    else {
                        doff += clipdy;
                        err += e3 * clipdx + e1 * clipdy;
                    }
                }
                (*bres) (pDrawable, pGC, doff,
                         signdx, signdy, axis, new_x1, new_y1,
                         err, e1, e3, len);
            }
            pBox++;
        }
    }                           /* while (nBox--) */
}
