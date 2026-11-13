module common.servermd;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2026, Roman Vlasov
 * Copyright 1987, 1998  The Open Group
 * Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.
 *
 * See COPYING for the full license texts.
 */

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
    int bytesPerPixel;          /* only set when notPower2 is True */
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
    