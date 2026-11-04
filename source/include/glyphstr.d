module include.glyphstr;
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

 
public import x11.X;
import externs.X11.extensions.renderproto;


// alias xGlyphInfo = XGlyphInfo;
public import include.picture;
public import include.scrintstr;
public import render.glyph;

enum GlyphFormat1 =	0;
enum GlyphFormat4 =	1;
enum GlyphFormat8 =	2;
enum GlyphFormat16 =	3;
enum GlyphFormat32 =	4;
enum GlyphFormatNum =	5;

struct _Glyph {
    CARD32 refcnt;
    PrivateRec* devPrivates;
    ubyte[20] sha1;
    CARD32 size;                /* info + bitmap */
    xGlyphInfo info;
    /* per-screen pixmaps follow */
}alias GlyphRec = _Glyph;
alias GlyphPtr = _Glyph*;

struct _GlyphList {
    INT16 xOff;
    INT16 yOff;
    CARD8 len;
    PictFormatPtr format;
}alias GlyphListRec = _GlyphList;
alias GlyphListPtr = _GlyphList*;

enum GLYPH_HAS_GLYPH_PICTURE_ACCESSOR = 1 /* used for api compat */;
// void GetGlyphPicture(GlyphPtr glyph, ScreenPtr pScreen);
void SetGlyphPicture(GlyphPtr glyph, ScreenPtr pScreen, PicturePtr picture);

                          /* _GLYPHSTR_H_ */
