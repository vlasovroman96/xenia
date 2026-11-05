module include.mipict;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2000 SuSE, Inc.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of SuSE not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  SuSE makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 * SuSE DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL SuSE
 * BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
 * OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * Author:  Keith Packard, SuSE, Inc.
 */

 
public import include.picturestr;
import externs.X11.extensions.renderproto;
import include.picture;

enum MI_MAX_INDEXED =	256     /* XXX depth must be <= 8 */;

static if (MI_MAX_INDEXED <= 256) {
alias miIndexType = CARD8;
}

struct _miIndexed {
    Bool color;
    CARD32[MI_MAX_INDEXED] rgba;
    miIndexType[32768] ent;
}alias miIndexedRec = _miIndexed;
alias miIndexedPtr = _miIndexed*;

enum string miCvtR8G8B8to15(string s) = `((((` ~ s ~ `) >> 3) & 0x001f) | 
			     (((` ~ s ~ `) >> 6) & 0x03e0) | 
			     (((` ~ s ~ `) >> 9) & 0x7c00))`;
enum string miIndexToEnt15(string mif,string rgb15) = `((` ~ mif ~ `).ent[` ~ rgb15 ~ `])`;
enum string miIndexToEnt24(string mif,string rgb24) = `` ~ miIndexToEnt15!(mif,miCvtR8G8B8to15!(rgb24)) ~ ``;

enum string miIndexToEntY24(string mif,string rgb24) = `((` ~ mif ~ `).ent[`~CvtR8G8B8toY15!(rgb24)~`])`;

void  miCreatePicture(PicturePtr pPicture);

void  miDestroyPicture(PicturePtr pPicture);

// void  miCompositeSourceValidate(PicturePtr pPicture);

// void  miComputeCompositeRegion(RegionPtr pRegion, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height);

// void  miPictureInit(ScreenPtr pScreen, PictFormatPtr formats, int nformats);

void  miRealizeGlyph(ScreenPtr pScreen, GlyphPtr glyph);

// void  miUnrealizeGlyph(ScreenPtr pScreen, GlyphPtr glyph);

// void  miGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs);

// void  miRenderColorToPixel(PictFormatPtr pPict, xRenderColor* color, CARD32* pixel);

// void  miRenderPixelToColor(PictFormatPtr pPict, CARD32 pixel, xRenderColor* color);

// void  miIsSolidAlpha(PicturePtr pSrc);

// void  miCompositeRects(CARD8 op, PicturePtr pDst, xRenderColor* color, int nRect, xRectangle* rects);

// void  miTrapezoidBounds(int ntrap, xTrapezoid* traps, BoxPtr box);

// void  miPointFixedBounds(int npoint, xPointFixed* points, BoxPtr bounds);

// void  miTriangleBounds(int ntri, xTriangle* tris, BoxPtr bounds);

// void  miInitIndexed(ScreenPtr pScreen, PictFormatPtr pFormat);

// void  miCloseIndexed(ScreenPtr pScreen, PictFormatPtr pFormat);

// void  miUpdateIndexed(ScreenPtr pScreen, PictFormatPtr pFormat, int ndef, xColorItem* pdef);

                          /* _MIPICT_H_ */
