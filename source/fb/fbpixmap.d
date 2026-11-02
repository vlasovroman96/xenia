module fb.fbpixmap;
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
import dix.pixmap;
import region;
import fb.fb;

version (FB_DEBUG) {

}

PixmapPtr fbCreatePixmap(ScreenPtr pScreen, int width, int height, int depth, uint usage_hint)
{
    PixmapPtr pPixmap = void;
    size_t datasize = void;
    size_t paddedWidth = void;
    int adjust = void;
    int base = void;
    int bpp = mixin(BitsPerPixel!("depth"));

    paddedWidth = ((width * bpp + FB_MASK) >> FB_SHIFT) * FbBits.sizeof;
    if (paddedWidth / 4 > 32767 || height > 32767)
        return NullPixmap;
    datasize = height * paddedWidth;
    base = pScreen.totalPixmapSize;
    adjust = 0;
    if (base & 7)
        adjust = 8 - (base & 7);
    datasize += adjust;
// version (FB_DEBUG) {
//     datasize += 2 * paddedWidth;
// }
    pPixmap = AllocatePixmap(pScreen, cast(int)datasize);
    if (!pPixmap)
        return NullPixmap;
    pPixmap.drawable.type = DRAWABLE_PIXMAP;
    pPixmap.drawable.pScreen = pScreen;
    pPixmap.drawable.depth = cast(ubyte)depth;
    pPixmap.drawable.bitsPerPixel = cast(ubyte)bpp;
    pPixmap.drawable.serialNumber = NEXT_SERIAL_NUMBER;
    pPixmap.drawable.width = cast(ushort)width;
    pPixmap.drawable.height = cast(ushort)height;
    pPixmap.devKind = cast(int)paddedWidth;
    pPixmap.refcnt = 1;
    pPixmap.devPrivate.ptr = cast(void*) (cast(char*) pPixmap + base + adjust);
    pPixmap.primary_pixmap = null;

version (FB_DEBUG) {
    pPixmap.devPrivate.ptr =
        cast(void*) (cast(char*) pPixmap.devPrivate.ptr + paddedWidth);
    fbInitializeDrawable(&pPixmap.drawable);
}

    pPixmap.usage_hint = usage_hint;

    return pPixmap;
}

Bool fbDestroyPixmap(PixmapPtr pPixmap)
{
    if (--pPixmap.refcnt)
        return TRUE;
    FreePixmap(pPixmap);
    return TRUE;
}

enum string ADDRECT(string reg,string r,string fr,string rx1,string ry1,string rx2,string ry2) = `
if (((` ~ rx1 ~ `) < (` ~ rx2 ~ `)) && ((` ~ ry1 ~ `) < (` ~ ry2 ~ `)) &&			
    (!((` ~ reg ~ `).data.numRects &&					
       ((` ~ r ~ `-1).y1 == (` ~ ry1 ~ `)) &&					
       ((` ~ r ~ `-1).y2 == (` ~ ry2 ~ `)) &&					
       ((` ~ r ~ `-1).x1 <= (` ~ rx1 ~ `)) &&					
       ((` ~ r ~ `-1).x2 >= (` ~ rx2 ~ `)))))					
{								
    if ((` ~ reg ~ `).data.numRects == (` ~ reg ~ `).data.size)		
    {								
	RegionRectAlloc(` ~ reg ~ `, 1);					
	` ~ fr ~ ` = RegionBoxptr(` ~ reg ~ `);				
	` ~ r ~ ` = ` ~ fr ~ ` + (` ~ reg ~ `).data.numRects;				
    }								
    ` ~ r ~ `.x1 = cast(short)(` ~ rx1 ~ `);						
    ` ~ r ~ `.y1 = cast(short)(` ~ ry1 ~ `);						
    ` ~ r ~ `.x2 = cast(short)(` ~ rx2 ~ `);						
    ` ~ r ~ `.y2 = cast(short)(` ~ ry2 ~ `);						
    (` ~ reg ~ `).data.numRects++;					
    if(` ~ r ~ `.x1 < (` ~ reg ~ `).extents.x1)				
	(` ~ reg ~ `).extents.x1 = ` ~ r ~ `.x1;				
    if(` ~ r ~ `.x2 > (` ~ reg ~ `).extents.x2)				
	(` ~ reg ~ `).extents.x2 = ` ~ r ~ `.x2;				
    ` ~ r ~ `++;							
}`;

/* Convert bitmap clip mask into clipping region.
 * First, goes through each line and makes boxes by noting the transitions
 * from 0 to 1 and 1 to 0.
 * Then it coalesces the current line with the previous if they have boxes
 * at the same X coordinates.
 */
RegionPtr fbPixmapToRegion(PixmapPtr pPix)
{
    RegionPtr pReg = void;
    FbBits* pw = void; FbBits w = void;
    int ib = void;
    int width = void, h = void, base = void, rx1 = 0, crects = void;
    FbBits* pwLineEnd = void;
    int irectPrevStart = void, irectLineStart = void;
    BoxPtr prectO = void, prectN = void;
    BoxPtr FirstRect = void, rects = void, prectLineStart = void;
    Bool fInBox = void, fSame = void;
    FbBits mask0 = FB_ALLONES & ~mixin(FbScrRight!("FB_ALLONES", "1"));
    FbBits* pwLine = void;
    int nWidth = void;

    pReg = RegionCreate(null, 1);
    if (!pReg)
        return NullRegion;
    FirstRect = RegionBoxptr(pReg);
    rects = FirstRect;

    // mixin(fbPrepareAccess!("(&pPix.drawable)")~";");

    pwLine = cast(FbBits*) pPix.devPrivate.ptr;
    nWidth = pPix.devKind >> (FB_SHIFT - 3);

    width = pPix.drawable.width;
    pReg.extents.x1 = cast(short)(width - 1);
    pReg.extents.x2 = cast(short)(0);
    irectPrevStart = -1;
    for (h = 0; h < pPix.drawable.height; h++) {
        pw = pwLine;
        pwLine += nWidth;
        irectLineStart = cast(int)(rects - FirstRect);
        /* If the Screen left most bit of the word is set, we're starting in
         * a box */
        if (mixin(READ!("pw")) & mask0) {
            fInBox = TRUE;
            rx1 = 0;
        }
        else
            fInBox = FALSE;
        /* Process all words which are fully in the pixmap */
        pwLineEnd = pw + (width >> FB_SHIFT);
        for (base = 0; pw < pwLineEnd; base += FB_UNIT) {
            w = mixin(READ!("pw++"));
            if (fInBox) {
                if (!~w)
                    continue;
            }
            else {
                if (!w)
                    continue;
            }
            for (ib = 0; ib < FB_UNIT; ib++) {
                /* If the Screen left most bit of the word is set, we're
                 * starting a box */
                if (w & mask0) {
                    if (!fInBox) {
                        rx1 = base + ib;
                        /* start new box */
                        fInBox = TRUE;
                    }
                }
                else {
                    if (fInBox) {
                        /* end box */
                        mixin(ADDRECT!(`pReg`, `rects`, `FirstRect`,
                                `rx1`, `h`, `base + ib`, `h + 1`));
                        fInBox = FALSE;
                    }
                }
                /* Shift the word VISUALLY left one. */
                w = mixin(FbScrLeft!("w", "1"));
            }
        }
        if (width & FB_MASK) {
            /* Process final partial word on line */
            w = mixin(READ!("pw++"));
            for (ib = 0; ib < (width & FB_MASK); ib++) {
                /* If the Screen left most bit of the word is set, we're
                 * starting a box */
                if (w & mask0) {
                    if (!fInBox) {
                        rx1 = base + ib;
                        /* start new box */
                        fInBox = TRUE;
                    }
                }
                else {
                    if (fInBox) {
                        /* end box */
                        mixin(ADDRECT!(`pReg`, `rects`, `FirstRect`,
                                `rx1`, `h`, `base + ib`, `h + 1`));
                        fInBox = FALSE;
                    }
                }
                /* Shift the word VISUALLY left one. */
                w = mixin(FbScrLeft!("w", "1"));
            }
        }
        /* If scanline ended with last bit set, end the box */
        if (fInBox) {
            mixin(ADDRECT!(`pReg`, `rects`, `FirstRect`,
                    `rx1`, `h`, `base + (width & FB_MASK)`, `h + 1`));
        }
        /* if all rectangles on this line have the same x-coords as
         * those on the previous line, then add 1 to all the previous  y2s and
         * throw away all the rectangles from this line
         */
        fSame = FALSE;
        if (irectPrevStart != -1) {
            crects = irectLineStart - irectPrevStart;
            if (crects == ((rects - FirstRect) - irectLineStart)) {
                prectO = FirstRect + irectPrevStart;
                prectN = prectLineStart = FirstRect + irectLineStart;
                fSame = TRUE;
                while (prectO < prectLineStart) {
                    if ((prectO.x1 != prectN.x1) ||
                        (prectO.x2 != prectN.x2)) {
                        fSame = FALSE;
                        break;
                    }
                    prectO++;
                    prectN++;
                }
                if (fSame) {
                    prectO = FirstRect + irectPrevStart;
                    while (prectO < prectLineStart) {
                        prectO.y2 += 1;
                        prectO++;
                    }
                    rects -= crects;
                    pReg.data.numRects -= crects;
                }
            }
        }
        if (!fSame)
            irectPrevStart = irectLineStart;
    }
    if (!pReg.data.numRects)
        pReg.extents.x1 = pReg.extents.x2 = 0;
    else {
        pReg.extents.y1 = RegionBoxptr(pReg).y1;
        pReg.extents.y2 = RegionEnd(pReg).y2;
        if (pReg.data.numRects == 1) {
            free(pReg.data);
            pReg.data = cast(RegDataPtr) null;
        }
    }

    mixin(fbFinishAccess!("&pPix.drawable"));
version (DEBUG) {
    if (!RegionIsValid(pReg))
        FatalError("Assertion failed file %s, line %d: expr\n", __FILE__,
                   __LINE__);
}
    return pReg;
}

version (FB_DEBUG) {

version (Windows) {} else {
import core.stdc.stdio;
} version (Windows) {
import dbg;
}

private Bool fbValidateBits(FbStip* bits, int stride, FbStip data)
{
    while (stride--) {
        if (*bits != data) {
version (Windows) {
            NCD_DEBUG((DEBUG_FAILURE,
                       "fdValidateBits failed at 0x%x (is 0x%x want 0x%x)",
                       bits, *bits, data));
} else {
            fprintf(stderr, "fbValidateBits failed\n");
}
            return FALSE;
        }
        bits++;
    }
}

void fbValidateDrawable(DrawablePtr pDrawable)
{
    FbStip* bits = void, first = void, last = void;
    int stride = void, bpp = void;
    int xoff = void, yoff = void;
    int height = void;
    Bool failed = void;

    if (pDrawable.type != DRAWABLE_PIXMAP)
        pDrawable = cast(DrawablePtr) fbGetWindowPixmap(pDrawable);
    fbGetStipDrawable(pDrawable, bits, stride, bpp, xoff, yoff);
    first = bits - stride;
    last = bits + stride * pDrawable.height;
    if (!fbValidateBits(first, stride, FB_HEAD_BITS) ||
        !fbValidateBits(last, stride, FB_TAIL_BITS))
        fbInitializeDrawable(pDrawable);
    mixin(fbFinishAccess!("pDrawable"));
}

void fbSetBits(FbStip* bits, int stride, FbStip data)
{
    while (stride--)
        *bits++ = data;
}

void fbInitializeDrawable(DrawablePtr pDrawable)
{
    FbStip* bits = void, first = void, last = void;
    int stride = void, bpp = void;
    int xoff = void, yoff = void;

    fbGetStipDrawable(pDrawable, bits, stride, bpp, xoff, yoff);
    first = bits - stride;
    last = bits + stride * pDrawable.height;
    fbSetBits(first, stride, FB_HEAD_BITS);
    fbSetBits(last, stride, FB_TAIL_BITS);
    mixin(fbFinishAccess!("pDrawable"));
}
}                          /* FB_DEBUG */
