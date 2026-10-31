module externs.X11.fonts.font;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************
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

 

version (BitmapFormatByteOrderMask) {} else {
public import	externs.X11.fonts.fsmasks;
}

import externs.X11.fonts.fontstruct;
import dix.dixstruct_priv;

/* data structures */
version (_XTYPEDEF_FONTPTR) {} else {
alias FontPtr = externs.X11.fonts.fontstruct._Font*;
// version = _XTYPEDEF_FONTPTR;
}

alias FontInfoPtr = _FontInfo*;
alias FontPropPtr = _FontProp*;
alias ExtentInfoPtr = _ExtentInfo*;
alias FontPathElementPtr = _FontPathElement*;

version (_XTYPEDEF_CHARINFOPTR) {} else {
alias CharInfoPtr = _CharInfo*;
// version = _XTYPEDEF_CHARINFOPTR;
}

alias FontNamesPtr = _FontNames*;
alias FontResolutionPtr = _FontResolution*;

enum NullCharInfo =	(cast(CharInfoPtr) 0);
enum NullFont =	(cast(FontPtr) 0);
enum NullFontInfo =	(cast(FontInfoPtr) 0);

 /* draw direction */
enum LeftToRight = 0;
enum RightToLeft = 1;
enum BottomToTop = 2;
enum TopToBottom = 3;
alias DrawDirection = int;

enum NO_SUCH_CHAR =	-1;


enum	FontAliasType =	0x1000;

enum	AllocError =	80;
enum	StillWorking =	81;
enum	FontNameAlias =	82;
enum	BadFontName =	83;
enum	Suspended =	84;
enum	Successful =	85;
enum	BadFontPath =	86;
enum	BadCharRange =	87;
enum	BadFontFormat =	88;
enum	FPEResetFailed =	89	/* for when an FPE reset won't work */;

/* OpenFont flags */
enum FontLoadInfo =	0x0001;
enum FontLoadProps =	0x0002;
enum FontLoadMetrics =	0x0004;
enum FontLoadBitmaps =	0x0008;
enum FontLoadAll =	0x000f;
enum	FontOpenSync =	0x0010;
enum FontReopen =	0x0020;

/* Query flags */
enum	LoadAll =		0x1;
enum	FinishRamge =	0x2;
enum       EightBitFont =    0x4;
enum       SixteenBitFont =  0x8;

/* Glyph Caching Modes */
enum CACHING_OFF = 0;
enum CACHE_16_BIT_GLYPHS = 1;
enum CACHE_ALL_GLYPHS = 2;
enum DEFAULT_GLYPH_CACHING_MODE = CACHE_16_BIT_GLYPHS;
extern int glyphCachingMode;
// 
// extern struct _Client;

extern int StartListFontsWithInfo(_Client*, int, ubyte*, int);

extern FontNamesPtr MakeFontNamesRecord(uint);

extern void FreeFontNames(FontNamesPtr);

extern int AddFontNamesName(FontNamesPtr, char*, int);

version (none) { /* unused */
extern int FontToFSError();
extern FontResolutionPtr GetClientResolution();
}

alias FontPatternCachePtr = _FontPatternCache*;

extern FontPatternCachePtr MakeFontPatternCache();

extern void FreeFontPatternCache(FontPatternCachePtr);

extern void EmptyFontPatternCache(FontPatternCachePtr);

extern void CacheFontPattern(FontPatternCachePtr, const(char)*, int, FontPtr);

extern struct _FontPatternCache;

extern FontResolutionPtr GetClientResolutions(
    int * /* num */
);

extern FontPtr FindCachedFontPattern(FontPatternCachePtr, const(char)*, int);

extern void RemoveCachedFontPattern(FontPatternCachePtr, FontPtr);

enum FontEncoding {
    Linear8Bit, TwoD8Bit, Linear16Bit, TwoD16Bit
}
alias Linear8Bit = FontEncoding.Linear8Bit;
alias TwoD8Bit = FontEncoding.TwoD8Bit;
alias Linear16Bit = FontEncoding.Linear16Bit;
alias TwoD16Bit = FontEncoding.TwoD16Bit;


				/* FONT_H */
