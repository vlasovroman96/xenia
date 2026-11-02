module fb.fbglyph;
@nogc nothrow:
extern(C): __gshared:
/*
 *
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

import externs.X11.fonts.fontstruct;

import fb.fb_priv;
import dix.dixfonts;
import fb.fbbits;
import fb.fbpush;
import Xext.xf86bigfont;
import fb.fb;
import fb.fbrop;


// enum string GLYPHWIDTHPIXELS(string pci) = 
//     "(" ~ pci ~ ".metrics.rightSideBearing - " ~
//     pci ~ ".metrics.leftSideBearing)";
    // enum string GLYPHHEIGHTPIXELS(string pci) =
    // `(` ~ pci ~ `.metrics.ascent + ` ~ pci ~ `.metrics.descent)`;
// enum string GLYPHWIDTHBYTES(string pci) = `(((`~GLYPHWIDTHPIXELS!(pci) ~`)+7) >> 3)`;

private Bool fbGlyphIn(RegionPtr pRegion, int x, int y, int width, int height)
{
    BoxRec box = void;
    BoxPtr pExtents = RegionExtents(pRegion);

    /*
     * Check extents by hand to avoid 16 bit overflows
     */
    if (x < cast(int) pExtents.x1)
        return FALSE;
    if (cast(int) pExtents.x2 < x + width)
        return FALSE;
    if (y < cast(int) pExtents.y1)
        return FALSE;
    if (cast(int) pExtents.y2 < y + height)
        return FALSE;
    box.x1 = cast(ushort)(x);
    box.x2 = cast(ushort)(x + width);
    box.y1 = cast(ushort)(y);
    box.y2 = cast(ushort)(y + height);
    return RegionContainsRect(pRegion, &box) == rgnIN;
}

void fbPolyGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    CharInfoPtr pci = void;
    ubyte* pglyph = void;      /* pointer bits in glyph */
    int gx = void, gy = void;
    int gWidth = void, gHeight = void;        /* width and height of glyph */
    FbStride gStride = void;           /* stride of glyph */
    extern(C) void function(FbBits*, FbStride, int, FbStip*, FbBits, int, int) @nogc nothrow glyph = void;
    FbBits* dst = null;
    FbStride dstStride = 0;
    int dstBpp = 0;
    int dstXoff = 0, dstYoff = 0;

    glyph = null;
    if (pGC.fillStyle == FillSolid && pPriv.and == 0) {
        dstBpp = pDrawable.bitsPerPixel;
        switch (dstBpp) {
        case 8:
            glyph = &fbGlyph8;
            break;
        case 16:
            glyph = &fbGlyph16;
            break;
        case 32:
            glyph = &fbGlyph32;
            break;
        default: break;}
    }
    x += pDrawable.x;
    y += pDrawable.y;

    while (nglyph--) {
        pci = *ppci++;
        pglyph = mixin(FONTGLYPHBITS!("pglyphBase", "pci"));
        gWidth = mixin(GLYPHWIDTHPIXELS!("pci"));
        gHeight = mixin(GLYPHHEIGHTPIXELS!("pci"));
        if (gWidth && gHeight) {
            gx = x + pci.metrics.leftSideBearing;
            gy = y - pci.metrics.ascent;
            if (glyph && gWidth <= ((FbStip).sizeof * 8) &&
                fbGlyphIn(mixin(fbGetCompositeClip!("pGC")), gx, gy, gWidth, gHeight)) {
                mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff",
                              "dstYoff"));
                (*glyph) (dst + (gy + dstYoff) * dstStride, dstStride, dstBpp,
                          cast(FbStip*) pglyph, pPriv.xor, gx + dstXoff, gHeight);
                mixin(fbFinishAccess!("pDrawable"));
            }
            else {
                gStride = cast(int)(mixin(GLYPHWIDTHBYTESPADDED!("pci")) / FbStip.sizeof);
                fbPushImage(pDrawable,
                            pGC,
                            cast(FbStip*) pglyph,
                            gStride, 0, gx, gy, gWidth, gHeight);
            }
        }
        x += pci.metrics.characterWidth;
    }
}

void fbImageGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppciInit, void* pglyphBase)
{
    FbGCPrivPtr pPriv = mixin(fbGetGCPrivate!("pGC"));
    CharInfoPtr* ppci = void;
    CharInfoPtr pci = void;
    ubyte* pglyph = void;      /* pointer bits in glyph */
    int gWidth = void, gHeight = void;        /* width and height of glyph */
    FbStride gStride = void;           /* stride of glyph */
    Bool opaque = void;
    int n = void;
    int gx = void, gy = void;
    extern(C) void function(FbBits*, FbStride, int, FbStip*, FbBits, int, int) @nogc nothrow glyph = void;
    FbBits* dst = null;
    FbStride dstStride = 0;
    int dstBpp = 0;
    int dstXoff = 0, dstYoff = 0;

    glyph = null;
    if (pPriv.and == 0) {
        dstBpp = pDrawable.bitsPerPixel;
        switch (dstBpp) {
        case 8:
            glyph = &fbGlyph8;
            break;
        case 16:
            glyph = &fbGlyph16;
            break;
        case 32:
            glyph = &fbGlyph32;
            break;
        default: break;}
    }

    x += pDrawable.x;
    y += pDrawable.y;

    if (mixin(TERMINALFONT!("pGC.font"))
        && !glyph) {
        opaque = TRUE;
    }
    else {
        int xBack = void, widthBack = void;
        int yBack = void, heightBack = void;

        ppci = ppciInit;
        n = nglyph;
        widthBack = 0;
        while (n--)
            widthBack += (*ppci++).metrics.characterWidth;

        xBack = x;
        if (widthBack < 0) {
            xBack += widthBack;
            widthBack = -widthBack;
        }
        yBack = y - mixin(FONTASCENT!("pGC.font"));
        heightBack = mixin(FONTASCENT!("pGC.font")) + mixin(FONTDESCENT!("pGC.font"));
        fbSolidBoxClipped(pDrawable,
                          mixin(fbGetCompositeClip!("pGC")),
                          xBack,
                          yBack,
                          xBack + widthBack,
                          yBack + heightBack,
                          mixin(fbAnd!("GXcopy", "pPriv.bg", "pPriv.pm")),
                          mixin(fbXor!("GXcopy", "pPriv.bg", "pPriv.pm")));
        opaque = FALSE;
    }

    ppci = ppciInit;
    while (nglyph--) {
        pci = *ppci++;
        pglyph = mixin(FONTGLYPHBITS!("pglyphBase", "pci"));
        gWidth = mixin(GLYPHWIDTHPIXELS!("pci"));
        gHeight = mixin(GLYPHHEIGHTPIXELS!("pci"));
        if (gWidth && gHeight) {
            gx = x + pci.metrics.leftSideBearing;
            gy = y - pci.metrics.ascent;
            if (glyph && gWidth <= ((FbStip).sizeof * 8) &&
                fbGlyphIn(mixin(fbGetCompositeClip!("pGC")), gx, gy, gWidth, gHeight)) {
                mixin(fbGetDrawable!("pDrawable", "dst", "dstStride", "dstBpp", "dstXoff",
                              "dstYoff"));
                (*glyph) (dst + (gy + dstYoff) * dstStride, dstStride, dstBpp,
                          cast(FbStip*) pglyph, pPriv.fg, gx + dstXoff, gHeight);
                mixin(fbFinishAccess!("pDrawable"));
            }
            else {
                gStride = cast(int)(mixin(GLYPHWIDTHBYTESPADDED!("pci")) / FbStip.sizeof);
                fbPutXYImage(pDrawable,
                             mixin(fbGetCompositeClip!("pGC")),
                             pPriv.fg,
                             pPriv.bg,
                             pPriv.pm,
                             GXcopy,
                             opaque,
                             gx,
                             gy,
                             gWidth, gHeight, cast(FbStip*) pglyph, gStride, 0);
            }
        }
        x += pci.metrics.characterWidth;
    }
}
