module render.glyphstr_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 2000 SuSE, Inc.
 */
 
public import externs.X11.extensions.renderproto;
public import include.glyphstr;
public import render.picture;
public import include.scrintstr;
public import include.regionstr;
public import include.miscstruct;
public import include.privates;

enum string GlyphPicture(string glyph) = `(cast(PicturePtr*) ((` ~ glyph ~ `) + 1))`;

struct _GlyphRefRec {
    CARD32 signature;
    GlyphPtr glyph;
}alias GlyphRefRec = _GlyphRefRec;
alias GlyphRefPtr = GlyphRefRec*;

enum DeletedGlyph =	cast(GlyphPtr) 1;

struct _GlyphHashSetRec {
    CARD32 entries;
    CARD32 size;
    CARD32 rehash;
}alias GlyphHashSetRec = _GlyphHashSetRec;
alias GlyphHashSetPtr = GlyphHashSetRec*;

struct _GlyphHashRec {
    GlyphRefPtr table;
    GlyphHashSetPtr hashSet;
    CARD32 tableEntries;
}alias GlyphHashRec = _GlyphHashRec;
alias GlyphHashPtr = GlyphHashRec*;

struct _GlyphSetRec {
    CARD32 refcnt;
    int fdepth;
    PictFormatPtr format;
    GlyphHashRec hash;
    PrivateRec* devPrivates;
}alias GlyphSetRec = _GlyphSetRec;
alias GlyphSetPtr = GlyphSetRec*;

enum string GlyphSetGetPrivate(string pGlyphSet,string k) = `
    dixLookupPrivate(&(` ~ pGlyphSet ~ `).devPrivates, ` ~ k ~ `)`;

enum string GlyphSetSetPrivate(string pGlyphSet,string k,string ptr) = `
    dixSetPrivate(&(` ~ pGlyphSet ~ `).devPrivates, ` ~ k ~ `, ` ~ ptr ~ `)`;

// void GlyphUninit(ScreenPtr pScreen);
// GlyphPtr FindGlyphByHash(ubyte* sha1, int format);
// int HashGlyph(xGlyphInfo* gi, CARD8* bits, c_ulong size, ubyte* sha1);
// void AddGlyph(GlyphSetPtr glyphSet, GlyphPtr glyph, Glyph id);
// Bool DeleteGlyph(GlyphSetPtr glyphSet, Glyph id);
// GlyphPtr FindGlyph(GlyphSetPtr glyphSet, Glyph id);
// GlyphPtr AllocateGlyph(xGlyphInfo* gi, int format);
// void FreeGlyph(GlyphPtr glyph, int format);
// Bool ResizeGlyphSet(GlyphSetPtr glyphSet, CARD32 change);
// GlyphSetPtr AllocateGlyphSet(int fdepth, PictFormatPtr format);
// int FreeGlyphSet(void* value, XID gid);

 /* _XSERVER_GLYPHSTR_PRIV_H_ */
