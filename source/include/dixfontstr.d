module include.dixfontstr;
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

 
public import include.servermd;
public import dix.dixfonts;
import Xext.xf86bigfont;
import externs.X11.fonts.fontstruct;
//public import x11.Xproto;         /* for xQueryFontReply */
import fb.fbglyph;

// enum string FONTCHARSET(string font) = `(` ~ font ~ `)`;
// enum string FONTMAXBOUNDS(string font, string field) = `(` ~ font ~ `")).info.maxbounds.` ~ field ~ ``;
// enum string FONTMINBOUNDS(string font, string field) = `(` ~ font ~ `")).info.props`;
// enum string FONTGLYPHBITS(string base,string pci) = `(cast(ubyte*) (` ~ pci ~ `).bits)`;
// enum string FONTINFONPROPS(string font) = `(` ~ font ~ `).info.nprops`;

/* some things haven't changed names, but we'll be careful anyway */

enum string FONTREFCNT(string font) = `(` ~ font ~ `).refcnt`;

/*
 * for linear char sets
 */
enum string N1dChars(string pfont) = `(` ~ FONTLASTCOL!(pfont) ~ ` - ` ~ FONTFIRSTCOL!(pfont) ~ ` + 1)`;

/*
 * for 2D char sets
 */
enum string N2dChars(string pfont) = `(` ~ N1dChars!(pfont) ~ ` * 
			 (` ~ FONTLASTROW!(pfont) ~ ` - ` ~ FONTFIRSTROW!(pfont) ~ ` + 1))`;

// enum GLYPHPADBYTES = -1;


static if (GLYPHPADBYTES == 0 || GLYPHPADBYTES == 1) {
enum string	GLYPHWIDTHBYTESPADDED(string pci) = `(`~GLYPHWIDTHBYTES!(pci)~`)`;
}

static if (GLYPHPADBYTES == 2) {
enum string	GLYPHWIDTHBYTESPADDED(string pci) = `((`~GLYPHWIDTHBYTES!(pci)~`+1) & ~0x1)`;
}

static if (GLYPHPADBYTES == 4) {
enum string	GLYPHWIDTHBYTESPADDED(string pci) = `((`~GLYPHWIDTHBYTES!(pci)~`+3) & ~0x3)`;
}

static if (GLYPHPADBYTES == 8) {          /* for a cray? */
enum string	GLYPHWIDTHBYTESPADDED(string pci) = `((`~GLYPHWIDTHBYTES!(pci)~`+7) & ~0x7)`;
}

                          /* DIXFONTSTRUCT_H */
