module common.servermd;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

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

******************************************************************/

version (SERVERMD_H) {} else {
enum SERVERMD_H = 1;

import build.dix_config;

public import x11.X;		/* for X_LITTLE_ENDIAN/X_BIG_ENDIAN */
public import dix.dispatch;

// static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
enum IMAGE_BYTE_ORDER =        LSBFirst;
enum BITMAP_BIT_ORDER =        LSBFirst;
// } else static if (X_BYTE_ORDER == X_BIG_ENDIAN) {
// enum IMAGE_BYTE_ORDER =        MSBFirst;
// enum BITMAP_BIT_ORDER =        MSBFirst;
// } else {
// static assert(0, "Too weird to live.");
// }

enum GLYPHPADBYTES =           4;


enum BITMAP_SCANLINE_PAD =  32;
enum LOG2_BITMAP_PAD =		5;
enum LOG2_BYTES_PER_SCANLINE_PAD =	2;

// //public import x11.Xfuncproto;
/*
 *   This returns the number of padding units, for depth d and width w.
 * For bitmaps this can be calculated with the macros above.
 * Other depths require either grovelling over the formats field of the
 * screenInfo or hardwired constants.
 */

struct PaddingInfo {
    int padRoundUp;             /* pixels per pad unit - 1 */
    int padPixelsLog2;          /* log 2 (pixels per pad unit) */
    int padBytesLog2;           /* log 2 (bytes per pad unit) */
    int notPower2;              /* bitsPerPixel not a power of 2 */
    int bytesPerPixel;          /* only set when notPower2 is TRUE */
    int bitsPerPixel;           /* bits per pixel */
}
// PaddingInfo [1] PixmapWidthPaddingInfo;

/* The only portable way to get the bpp from the depth is to look it up */
enum string BitsPerPixel(string d) = `(PixmapWidthPaddingInfo[` ~ d ~ `].bitsPerPixel)`;

enum string PixmapWidthInPadUnits(string w, string d) = `
    (PixmapWidthPaddingInfo[` ~ d ~ `].notPower2 ? 
    ((cast(int)(` ~ w ~ `) * PixmapWidthPaddingInfo[` ~ d ~ `].bytesPerPixel +  
	         PixmapWidthPaddingInfo[` ~ d ~ `].bytesPerPixel) >> 
	PixmapWidthPaddingInfo[` ~ d ~ `].padBytesLog2) : 
    (cast(int)((` ~ w ~ `) + PixmapWidthPaddingInfo[` ~ d ~ `].padRoundUp) >> 
	PixmapWidthPaddingInfo[` ~ d ~ `].padPixelsLog2))`;

/*
 *	Return the number of bytes to which a scanline of the given
 * depth and width will be padded.
 */
// enum string PixmapBytePad(string w, string d) = `
//     (` ~ PixmapWidthInPadUnits!(w, d) ~ ` << PixmapWidthPaddingInfo[` ~ d ~ `].padBytesLog2)`;

auto PixmapBytePad(T, S) (T w, S d) {
    return mixin(PixmapWidthInPadUnits!("w", "d")) << PixmapWidthPaddingInfo[d].padBytesLog2;
}

enum string BitmapBytePad(string w) = `
    ((cast(int)((` ~ w ~ `) + BITMAP_SCANLINE_PAD - 1) >> LOG2_BITMAP_PAD) << LOG2_BYTES_PER_SCANLINE_PAD)`;

}                          /* SERVERMD_H */
