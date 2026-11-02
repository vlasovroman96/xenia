module fb.fbfill;
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
import externs.attrs;
import fb.fb;

private void fbStipple(FbBits* dst, FbStride dstStride, int dstX, int dstBpp, int width, int height, FbStip* stip, FbStride stipStride, int stipWidth, int stipHeight, FbBits fgand, FbBits fgxor, FbBits bgand, FbBits bgxor, int xRot, int yRot)
{
    int stipX = void, stipY = void, sx = void;
    int widthTmp = void;
    int h = void, w = void;
    int x = void, y = void;

    mixin(modulus!("-yRot", "stipHeight", "stipY"));
    mixin(modulus!("dstX / dstBpp - xRot", "stipWidth", "stipX"));
    y = 0;
    while (height) {
        h = stipHeight - stipY;
        if (h > height)
            h = height;
        height -= h;
        widthTmp = width;
        x = dstX;
        sx = stipX;
        while (widthTmp) {
            w = (stipWidth - sx) * dstBpp;
            if (w > widthTmp)
                w = widthTmp;
            widthTmp -= w;
            fbBltOne(stip + stipY * stipStride,
                     stipStride,
                     sx,
                     dst + y * dstStride,
                     dstStride, x, dstBpp, w, h, fgand, fgxor, bgand, bgxor);
            x += w;
            sx = 0;
        }
        y += h;
        stipY = 0;
    }
}

void fbFill(DrawablePtr pDrawable, GCPtr pGC, int x, int y, int width, int height)
{
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));

    switch (pGC.fillStyle) {
    case FillSolid:
static if (FB_ACCESS_WRAPPER) {
                fbSolid(dst + (y + dstYoff) * dstStride,
                    dstStride,
                    (x + dstXoff) * dstBpp,
                    dstBpp, width * dstBpp, height, pPriv.and, pPriv.xor);
} else {
        if (pPriv.and || !assumeNoGC(&pixman_fill)(cast(uint*) dst, dstStride, dstBpp,
                                       x + dstXoff, y + dstYoff,
                                       width, height, cast(uint)pPriv.xor))
            fbSolid(dst + (y + dstYoff) * dstStride,
                    dstStride,
                    (x + dstXoff) * dstBpp,
                    dstBpp, width * dstBpp, height, pPriv.and, pPriv.xor);
}
        break;
    case FillStippled:
    case FillOpaqueStippled:{
        PixmapPtr pStip = pGC.stipple;
        int stipWidth = pStip.drawable.width;
        int stipHeight = pStip.drawable.height;

        if (dstBpp == 1) {
            int alu = void;
            FbBits* stip = void;
            FbStride stipStride = void;
            int stipBpp = void;
            int stipXoff = void, stipYoff = void;

            if (pGC.fillStyle == FillStippled)
                alu = mixin(FbStipple1Rop!("pGC.alu", "pGC.fgPixel"));
            else
                alu = mixin(FbOpaqueStipple1Rop!("pGC.alu", "pGC.fgPixel", "pGC.bgPixel"));
            mixin(fbGetDrawable!("(&pStip.drawable)", "stip", "stipStride", "stipBpp", "stipXoff",
                          "stipYoff"));
            fbTile(dst + (y + dstYoff) * dstStride, dstStride, x + dstXoff,
                   width, height, stip, stipStride, stipWidth, stipHeight, alu,
                   pPriv.pm, dstBpp, (pGC.patOrg.x + pDrawable.x + dstXoff),
                   pGC.patOrg.y + pDrawable.y - y);
            mixin(fbFinishAccess!("&pStip.drawable"));
        }
        else {
            FbStip* stip = void;
            FbStride stipStride = void;
            int stipBpp = void;
            int stipXoff = void, stipYoff = void;
            FbBits fgand = void, fgxor = void, bgand = void, bgxor = void;

            fgand = pPriv.and;
            fgxor = pPriv.xor;
            if (pGC.fillStyle == FillStippled) {
                bgand = mixin(fbAnd!("GXnoop", "cast(FbBits) 0", "FB_ALLONES"));
                bgxor = mixin(fbXor!("GXnoop", "cast(FbBits) 0", "FB_ALLONES"));
            }
            else {
                bgand = pPriv.bgand;
                bgxor = pPriv.bgxor;
            }

            mixin(fbGetStipDrawable!("(&pStip.drawable)", "stip", "stipStride", "stipBpp",
                              "stipXoff", "stipYoff"));
            fbStipple(dst + (y + dstYoff) * dstStride, dstStride,
                      (x + dstXoff) * dstBpp, dstBpp, width * dstBpp, height,
                      stip, stipStride, stipWidth, stipHeight,
                      fgand, fgxor, bgand, bgxor,
                      pGC.patOrg.x + pDrawable.x + dstXoff,
                      pGC.patOrg.y + pDrawable.y - y);
            mixin(fbFinishAccess!("&pStip.drawable"));
        }
        break;
    }
    case FillTiled:{
        PixmapPtr pTile = pGC.tile.pixmap;
        FbBits* tile = void;
        FbStride tileStride = void;
        int tileBpp = void;
        int tileWidth = void;
        int tileHeight = void;
        int tileXoff = void, tileYoff = void;

        mixin(fbGetDrawable!("(&pTile.drawable)", "tile", "tileStride", "tileBpp", "tileXoff",
                      "tileYoff"));
        tileWidth = pTile.drawable.width;
        tileHeight = pTile.drawable.height;
        fbTile(dst + (y + dstYoff) * dstStride,
               dstStride,
               (x + dstXoff) * dstBpp,
               width * dstBpp, height,
               tile,
               tileStride,
               tileWidth * tileBpp,
               tileHeight,
               pGC.alu,
               pPriv.pm,
               dstBpp,
               (pGC.patOrg.x + pDrawable.x + dstXoff) * dstBpp,
               pGC.patOrg.y + pDrawable.y - y);
        mixin(fbFinishAccess!("&pTile.drawable"));
        break;
    }
    default: break;
    }
    fbValidateDrawable(pDrawable);
    mixin(fbFinishAccess!("pDrawable"));
}

void fbSolidBoxClipped(DrawablePtr pDrawable, RegionPtr pClip, int x1, int y1, int x2, int y2, FbBits and, FbBits xor)
{
    FbBits* dst = void;
    FbStride dstStride = void;
    int dstBpp = void;
    int dstXoff = void, dstYoff = void;
    BoxPtr pbox = void;
    int nbox = void;
    int partX1 = void, partX2 = void, partY1 = void, partY2 = void;

    mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff", "dstYoff"));

    for (nbox = RegionNumRects(pClip), pbox = RegionRects(pClip);
         nbox--; pbox++) {
        partX1 = pbox.x1;
        if (partX1 < x1)
            partX1 = x1;

        partX2 = pbox.x2;
        if (partX2 > x2)
            partX2 = x2;

        if (partX2 <= partX1)
            continue;

        partY1 = pbox.y1;
        if (partY1 < y1)
            partY1 = y1;

        partY2 = pbox.y2;
        if (partY2 > y2)
            partY2 = y2;

        if (partY2 <= partY1)
            continue;

static if (FB_ACCESS_WRAPPER) {
                fbSolid(dst + (partY1 + dstYoff) * dstStride,
                    dstStride,
                    (partX1 + dstXoff) * dstBpp,
                    dstBpp,
                    (partX2 - partX1) * dstBpp, (partY2 - partY1), and, xor);
} else {
        if (and || !assumeNoGC(&pixman_fill)(cast(uint*) dst, dstStride, dstBpp,
                                partX1 + dstXoff, partY1 + dstYoff,
                                (partX2 - partX1), (partY2 - partY1), cast(uint)xor))
            fbSolid(dst + (partY1 + dstYoff) * dstStride,
                    dstStride,
                    (partX1 + dstXoff) * dstBpp,
                    dstBpp,
                    (partX2 - partX1) * dstBpp, (partY2 - partY1), and, cast(uint)xor);
    }
    mixin(fbFinishAccess!("pDrawable"));
}
}
