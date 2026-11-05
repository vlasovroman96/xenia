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
public import render.glyphstr_priv;
public import render.picture;
public import include.scrintstr;
public import include.regionstr;
public import include.miscstruct;
public import include.privates;
import include.picture;

public import x11.X;
// alias xGlyphInfo = XGlyphInfo;

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
// void SetGlyphPicture(GlyphPtr glyph, ScreenPtr pScreen, PicturePtr picture);


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
