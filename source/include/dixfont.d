module include.dixfont;
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

version (DIXFONT_H) {} else {
enum DIXFONT_H = 1;

public import include.xlibre_ptrtypes;

public import externs.X11.fonts.font;
// //public import externs.X11.fonts.fontstruct;

int SetDefaultFont(const(char)*);

// int OpenFont(ClientPtr, XID, Mask, uint, const(char)*);

// int CloseFont(void* pfont, XID fid);

// int ListFonts(ClientPtr, ubyte*, uint, uint);

// int PolyText(ClientPtr, DrawablePtr, GCPtr, ubyte*, ubyte*, int, int, int, XID);

// int ImageText(ClientPtr, DrawablePtr, GCPtr, int, ubyte*, int, int, int, XID);

// int SetFontPath(ClientPtr, int, ubyte*);

int SetDefaultFontPath(const(char)*);

// int DeleteClientFontStuff(ClientPtr);

/* Quartz support on Mac OS X pulls in the QuickDraw
   framework whose InitFonts function conflicts here. */
version (OSX) {
enum InitFonts = Darwin_X_InitFonts;
}
int InitFonts();

int FreeFonts();

int GetGlyphs(FontPtr, c_ulong, ubyte*, FontEncoding, c_ulong*, CharInfoPtr*);

}                          /* DIXFONT_H */
