module fbtile;
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

import fb.fb;
import fb.fbrop;
import common.math;

/*
 * Accelerated tile fill -- tile width is a power of two not greater
 * than FB_UNIT
 */

void fbEvenTile(FbBits* dst, FbStride dstStride, int dstX, int width, int height, FbBits* tile, FbStride tileStride, int tileHeight, int alu, FbBits pm, int xRot, int yRot)
{
    FbBits* t = void, tileEnd = void; FbBits bits = void;
    FbBits startmask = void, endmask = void;
    FbBits and = void, xor = void;
    int n = void, nmiddle = void;
    int tileX = void, tileY = void;
    int rot = void;
    int startbyte = void, endbyte = void;

    dst += dstX >> FB_SHIFT;
    dstX &= FB_MASK;
    mixin(FbMaskBitsBytes!("dstX", "width", FbDestInvarientRop!("alu", "pm"),
                    "startmask", "startbyte", "nmiddle", "endmask", "endbyte"));
    if (startmask)
        dstStride--;
    dstStride -= nmiddle;

    /*
     * Compute tile start scanline and rotation parameters
     */
    tileEnd = tile + tileHeight * tileStride;
    mixin(modulus!("-yRot", "tileHeight", "tileY"));
    t = tile + tileY * tileStride;
    mixin(modulus!("-xRot", "FB_UNIT", "tileX"));
    rot = tileX;

    while (height--) {

        /*
         * Pick up bits for this scanline
         */
        bits = mixin(READ!("t"));
        t += tileStride;
        if (t >= tileEnd)
            t = tile;
        bits = mixin(FbRotLeft!("bits", "rot"));
        and = mixin(fbAnd!("alu", "bits", "pm"));
        xor = mixin(fbXor!("alu", "bits", "pm"));

        if (startmask) {
            mixin(FbDoLeftMaskByteRRop!("dst", "startbyte", "startmask", "and", "xor"));
            dst++;
        }
        n = nmiddle;
        if (!and)
            while (n--)
                mixin(WRITE!("dst++", "xor")~";");
        else
            while (n--) {
                mixin(WRITE!("dst", FbDoRRop!(READ!("dst"), "and", "xor"))~";");
                dst++;
            }
        if (endmask)
            mixin(FbDoRightMaskByteRRop!("dst", "endbyte", "endmask", "and", "xor"));
        dst += dstStride;
    }
}

void fbOddTile(FbBits* dst, FbStride dstStride, int dstX, int width, int height, FbBits* tile, FbStride tileStride, int tileWidth, int tileHeight, int alu, FbBits pm, int bpp, int xRot, int yRot)
{
    int tileX = void, tileY = void;
    int widthTmp = void;
    int h = void, w = void;
    int x = void, y = void;

    mixin(modulus!("-yRot", "tileHeight", "tileY"));
    y = 0;
    while (height) {
        h = tileHeight - tileY;
        if (h > height)
            h = height;
        height -= h;
        widthTmp = width;
        x = dstX;
        mixin(modulus!("dstX - xRot", "tileWidth", "tileX"));
        while (widthTmp) {
            w = tileWidth - tileX;
            if (w > widthTmp)
                w = widthTmp;
            widthTmp -= w;
            fbBlt(tile + tileY * tileStride,
                  tileStride,
                  tileX,
                  dst + y * dstStride,
                  dstStride, x, w, h, alu, pm, bpp, FALSE, FALSE);
            x += w;
            tileX = 0;
        }
        y += h;
        tileY = 0;
    }
}

void fbTile(FbBits* dst, FbStride dstStride, int dstX, int width, int height, FbBits* tile, FbStride tileStride, int tileWidth, int tileHeight, int alu, FbBits pm, int bpp, int xRot, int yRot)
{
    if (mixin(FbEvenTile!("tileWidth")))
        fbEvenTile(dst, dstStride, dstX, width, height,
                   tile, tileStride, tileHeight, alu, pm, xRot, yRot);
    else
        fbOddTile(dst, dstStride, dstX, width, height,
                  tile, tileStride, tileWidth, tileHeight,
                  alu, pm, bpp, xRot, yRot);
}
