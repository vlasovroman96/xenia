module externs.X11.fonts.fontstruct;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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

 
public import x11.Xproto;
public import externs.X11.fonts.font;
public import x11.Xdefs;

/*
 * This version of the server font data structure is only for describing
 * the in memory data structure. The file structure is not necessarily a
 * copy of this. That is up to the compiler and the OS layer font loading
 * machinery.
 */

enum GLYPHPADOPTIONS = 4	/* 1, 2, 4, or 8 */;

struct _FontProp {
    c_long name;
    c_long value;		/* assumes ATOM is not larger than INT32 */
}

alias FontPropRec = _FontProp;

struct _FontResolution {
    ushort x_resolution;
    ushort y_resolution;
    ushort point_size;
}

alias FontResolutionRec = _FontResolution;

struct _ExtentInfo {
    DrawDirection drawDirection;
    int fontAscent;
    int fontDescent;
    int overallAscent;
    int overallDescent;
    int overallWidth;
    int overallLeft;
    int overallRight;
}

alias ExtentInfoRec = _ExtentInfo;

struct _CharInfo {
    xCharInfo metrics;	/* info preformatted for Queries */
    char* bits;		/* pointer to glyph image */
}

alias CharInfoRec = _CharInfo;


/*
 * Font is created at font load time. It is specific to a single encoding.
 * e.g. not all of the glyphs in a font may be part of a single encoding.
 */

struct _FontInfo {
    ushort firstCol;
    ushort lastCol;
    ushort firstRow;
    ushort lastRow;
    ushort defaultCh;
    uint noOverlap:1;
    uint terminalFont:1;
    uint constantMetrics:1;
    uint constantWidth:1;
    uint inkInside:1;
    uint inkMetrics:1;
    uint allExist:1;
    uint drawDirection:2;
    uint cachable:1;
    uint anamorphic:1;
    short maxOverlap;
    short pad;
    xCharInfo maxbounds;
    xCharInfo minbounds;
    xCharInfo ink_maxbounds;
    xCharInfo ink_minbounds;
    short fontAscent;
    short fontDescent;
    int nprops;
    FontPropPtr props;
    char* isStringProp;
}
alias FontInfoRec = _FontInfo;

alias FontPtr = externs.X11.fonts.font.FontPtr;

struct _Font {
    int refcnt;
    FontInfoRec info;
    char bit = 0;
    char byte_ = 0;
    char glyph = 0;
    char scan = 0;
    fsBitmapFormat format;
    int function(FontPtr, c_ulong, ubyte*, FontEncoding, c_ulong*, CharInfoPtr*) get_glyphs;
    int function(FontPtr, c_ulong, ubyte*, FontEncoding, c_ulong*, xCharInfo**) get_metrics;
    void function(FontPtr) unload_font;
    void function(FontPtr) unload_glyphs;
    FontPathElementPtr fpe;
    void* svrPrivate;
    void* fontPrivate;
    void* fpePrivate;
    int maxPrivate;
    void** devPrivates;
}

alias FontRec = _Font;

enum string FontGetPrivate(string pFont,string n) = `((` ~ n ~ `) > (` ~ pFont ~ `).maxPrivate ? cast(void*) 0 : 
			     (` ~ pFont ~ `).devPrivates[` ~ n ~ `])`;

enum string FontSetPrivate(string pFont,string n,string ptr) = `((` ~ n ~ `) > (` ~ pFont ~ `).maxPrivate ? 
			_FontSetNewPrivate (` ~ pFont ~ `, ` ~ n ~ `, ` ~ ptr ~ `) : 
			((((` ~ pFont ~ `).devPrivates[` ~ n ~ `] = (` ~ ptr ~ `)) != 0) || True))`;

struct _FontNames {
    int nnames;
    int size;
    int* length;
    char** names;
}

alias FontNamesRec = _FontNames;

/* External view of font paths */
struct _FontPathElement {
    int name_length;
// static if (FONT_PATH_ELEMENT_NAME_CONST) {
//     const char* name;
// }
// else
    char* name;
    int type;
    int refcount;
    void* private_;
}

alias FontPathElementRec = _FontPathElement;


alias NameCheckFunc = Bool function(const(char)* name);
alias InitFpeFunc = int function(FontPathElementPtr fpe);
alias FreeFpeFunc = int function(FontPathElementPtr fpe);
alias ResetFpeFunc = int function(FontPathElementPtr fpe);
alias OpenFontFunc = int function(void* client, FontPathElementPtr fpe, Mask flags, const(char)* name, int namelen, fsBitmapFormat format, fsBitmapFormatMask fmask, XID id, FontPtr* pFont, char** aliasName, FontPtr non_cachable_font);
alias CloseFontFunc = void function(FontPathElementPtr fpe, FontPtr pFont);
alias ListFontsFunc = int function(void* client, FontPathElementPtr fpe, const(char)* pat, int len, int max, FontNamesPtr names);

alias StartLfwiFunc = int function(void* client, FontPathElementPtr fpe, const(char)* pat, int len, int max, void** privatep);

alias NextLfwiFunc = int function(void* client, FontPathElementPtr fpe, char** name, int* namelen, FontInfoPtr* info, int* numFonts, void* private_);

alias WakeupFpeFunc = int function(FontPathElementPtr fpe, c_ulong* LastSelectMask);

alias ClientDiedFunc = void function(void* client, FontPathElementPtr fpe);

alias LoadGlyphsFunc = int function(void* client, FontPtr pfont, Bool range_flag, uint nchars, int item_size, ubyte* data);

alias StartLaFunc = int function(void* client, FontPathElementPtr fpe, const(char)* pat, int len, int max, void** privatep);

alias NextLaFunc = int function(void* client, FontPathElementPtr fpe, char** namep, int* namelenp, char** resolvedp, int* resolvedlenp, void* private_);

alias SetPathFunc = void function();

struct _FPEFunctions {
    NameCheckFunc name_check;
    InitFpeFunc init_fpe;
    ResetFpeFunc reset_fpe;
    FreeFpeFunc free_fpe;
    OpenFontFunc open_font;
    CloseFontFunc close_font;
    ListFontsFunc list_fonts;
    StartLaFunc start_list_fonts_and_aliases;
    NextLaFunc list_next_font_or_alias;
    StartLfwiFunc start_list_fonts_with_info;
    NextLfwiFunc list_next_font_with_info;
    WakeupFpeFunc wakeup_fpe;
    ClientDiedFunc client_died;
		/* for load_glyphs, range_flag = 0 ->
			nchars = # of characters in data
			item_size = bytes/char
			data = list of characters
		   range_flag = 1 ->
			nchars = # of fsChar2b's in data
			item_size is ignored
			data = list of fsChar2b's */
    LoadGlyphsFunc load_glyphs;
    SetPathFunc set_path_hook;
}alias FPEFunctionsRec = _FPEFunctions;
alias FPEFunctions = _FPEFunctions;

/*
 * Various macros for computing values based on contents of
 * the above structures
 */

enum string	GLYPHWIDTHPIXELS(string pci) = `
	((` ~ pci ~ `).metrics.rightSideBearing - (` ~ pci ~ `).metrics.leftSideBearing)`;

enum string	GLYPHHEIGHTPIXELS(string pci) = `
 	((` ~ pci ~ `).metrics.ascent + (` ~ pci ~ `).metrics.descent)`;

enum string	GLYPHWIDTHBYTES(string pci) = `(((` ~ GLYPHWIDTHPIXELS!(pci) ~ `)+7) >> 3)`;

enum string GLYPHWIDTHPADDED(string bc) = `(((` ~ bc ~ `)+7) & ~0x7)`;

enum string BYTES_PER_ROW(string bits, string nbytes) = `
	((` ~ nbytes ~ `) == 1 ? (((` ~ bits ~ `)+7)>>3)	/* pad to 1 byte */ 
	:(` ~ nbytes ~ `) == 2 ? ((((` ~ bits ~ `)+15)>>3)&~1)	/* pad to 2 bytes */ 
	:(` ~ nbytes ~ `) == 4 ? ((((` ~ bits ~ `)+31)>>3)&~3)	/* pad to 4 bytes */ 
	:(` ~ nbytes ~ `) == 8 ? ((((` ~ bits ~ `)+63)>>3)&~7)	/* pad to 8 bytes */ 
	: 0)`;

enum string BYTES_FOR_GLYPH(string ci,string pad) = `(` ~ GLYPHHEIGHTPIXELS!(ci) ~ ` * 
				 ` ~ BYTES_PER_ROW!(GLYPHWIDTHPIXELS!(ci),pad) ~ `)`;
/*
 * Macros for computing different bounding boxes for fonts; from
 * the font protocol
 */

enum string FONT_MAX_ASCENT(string pi) = `((` ~ pi ~ `).fontAscent > (` ~ pi ~ `).ink_maxbounds.ascent ? 
			    (` ~ pi ~ `).fontAscent : (` ~ pi ~ `).ink_maxbounds.ascent)`;
enum string FONT_MAX_DESCENT(string pi) = `((` ~ pi ~ `).fontDescent > (` ~ pi ~ `).ink_maxbounds.descent ? 
			    (` ~ pi ~ `).fontDescent : (` ~ pi ~ `).ink_maxbounds.descent)`;
enum string FONT_MAX_HEIGHT(string pi) = `(` ~ FONT_MAX_ASCENT!(pi) ~ ` + ` ~ FONT_MAX_DESCENT!(pi) ~ `)`;
enum string FONT_MIN_LEFT(string pi) = `((` ~ pi ~ `).ink_minbounds.leftSideBearing < 0 ? 
			    (` ~ pi ~ `).ink_minbounds.leftSideBearing : 0)`;
enum string FONT_MAX_RIGHT(string pi) = `((` ~ pi ~ `).ink_maxbounds.rightSideBearing > 
				(` ~ pi ~ `).ink_maxbounds.characterWidth ? 
			    (` ~ pi ~ `).ink_maxbounds.rightSideBearing : 
				(` ~ pi ~ `).ink_maxbounds.characterWidth)`;
enum string FONT_MAX_WIDTH(string pi) = `(` ~ FONT_MAX_RIGHT!(pi) ~ ` - ` ~ FONT_MIN_LEFT!(pi) ~ `)`;

public import externs.X11.fonts.fontproto;

				/* FONTSTR_H */
