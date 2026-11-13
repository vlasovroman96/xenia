module mipolytext;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*******************************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

************************************************************************/
/*
 * mipolytext.c - text routines
 *
 * Author:	haynes
 * 		Digital Equipment Corporation
 * 		Western Software Laboratory
 * Date:	Thu Feb  5 1987
 */

import build.dix_config;

//import   x11.X;
//import   x11.Xmd;
//import   x11.Xproto;
// //import   externs.X11.fonts.fontstruct;
import dix.pixmap;
import	dix.gc;
import	dix.dixfonts;
import Xext.xf86bigfont;

int miPolyText8(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, char* chars)
{
    c_ulong n = void, i = void;
    int w = void;
    CharInfoPtr[255] charinfo = void;  /* encoding only has 1 byte for count */

    GetGlyphs(pGC.font, cast(c_ulong) count, cast(ubyte*) chars,
              Linear8Bit, &n, charinfo.ptr);
    w = 0;
    for (i = 0; i < n; i++)
        w += charinfo[i].metrics.characterWidth;
    if (n != 0)
        (*pGC.ops.PolyGlyphBlt) (pDraw, pGC, x, y, cast(uint)n, charinfo.ptr,
                                   mixin(FONTGLYPHS!("pGC.font")));
    return x + w;
}

int miPolyText16(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    c_ulong n = void, i = void;
    int w = void;
    CharInfoPtr[255] charinfo = void;  /* encoding only has 1 byte for count */

    GetGlyphs(pGC.font, cast(c_ulong) count, cast(ubyte*) chars,
              (mixin(FONTLASTROW!("pGC.font")) == 0) ? Linear16Bit : TwoD16Bit,
              &n, charinfo.ptr);
    w = 0;
    for (i = 0; i < n; i++)
        w += charinfo[i].metrics.characterWidth;
    if (n != 0)
        (*pGC.ops.PolyGlyphBlt) (pDraw, pGC, x, y, cast(uint)n, charinfo.ptr,
                                   mixin(FONTGLYPHS!("pGC.font")));
    return x + w;
}

void miImageText8(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, char* chars)
{
    c_ulong n = void;
    FontPtr font = pGC.font;
    CharInfoPtr[255] charinfo = void;  /* encoding only has 1 byte for count */

    GetGlyphs(font, cast(c_ulong) count, cast(ubyte*) chars,
              Linear8Bit, &n, charinfo.ptr);
    if (n != 0)
        (*pGC.ops.ImageGlyphBlt) (pDraw, pGC, x, y, cast(uint)n, charinfo.ptr,
                                    mixin(FONTGLYPHS!("font")));
}

void miImageText16(DrawablePtr pDraw, GCPtr pGC, int x, int y, int count, ushort* chars)
{
    c_ulong n = void;
    FontPtr font = pGC.font;
    CharInfoPtr[255] charinfo = void;  /* encoding only has 1 byte for count */

    GetGlyphs(font, cast(c_ulong) count, cast(ubyte*) chars,
              (mixin(FONTLASTROW!("pGC.font")) == 0) ? Linear16Bit : TwoD16Bit,
              &n, charinfo.ptr);
    if (n != 0)
        (*pGC.ops.ImageGlyphBlt) (pDraw, pGC, x, y, cast(uint)n, charinfo.ptr,
                                    mixin(FONTGLYPHS!("font")));
}
