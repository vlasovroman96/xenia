module render.glyph;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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

import build.dix_config;

import dix.screenint_priv;
import include.mipict;
import os.bug_priv;
import os.xsha1;

import include.misc;
import include.scrnintstr;
import include.os;
import include.regionstr;
import include.validate;
import include.windowstr;
import include.input;
import include.resource;
import dix.cursor;
import include.dixstruct;
import include.gcstruct;
import include.servermd;
import include.picturestr;
import render.glyphstr_priv;
import dix.gc;

/*
 * From Knuth -- a good choice for hash/rehash values is p, p-2 where
 * p and p-2 are both prime.  These tables are sized to have an extra 10%
 * free to avoid exponential performance degradation as the hash table fills
 */
private GlyphHashSetRec[25] glyphHashSets = [
    {32, 43, 41},
    {64, 73, 71},
    {128, 151, 149},
    {256, 283, 281},
    {512, 571, 569},
    {1024, 1153, 1151},
    {2048, 2269, 2267},
    {4096, 4519, 4517},
    {8192, 9013, 9011},
    {16384, 18043, 18041},
    {32768, 36109, 36107},
    {65536, 72091, 72089},
    {131072, 144409, 144407},
    {262144, 288361, 288359},
    {524288, 576883, 576881},
    {1048576, 1153459, 1153457},
    {2097152, 2307163, 2307161},
    {4194304, 4613893, 4613891},
    {8388608, 9227641, 9227639},
    {16777216, 18455029, 18455027},
    {33554432, 36911011, 36911009},
    {67108864, 73819861, 73819859},
    {134217728, 147639589, 147639587},
    {268435456, 295279081, 295279079},
    {536870912, 590559793, 590559791}
];

enum NGLYPHHASHSETS =	mixin(ARRAY_SIZE!("glyphHashSets"));

private GlyphHashRec[GlyphFormatNum] globalGlyphs;

void GlyphUninit(ScreenPtr pScreen)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pScreen"));
    GlyphPtr glyph = void;
    int fdepth = void, i = void;

    for (fdepth = 0; fdepth < GlyphFormatNum; fdepth++) {
        if (!globalGlyphs[fdepth].hashSet)
            continue;

        for (i = 0; i < globalGlyphs[fdepth].hashSet.size; i++) {
            glyph = globalGlyphs[fdepth].table[i].glyph;
            if (glyph && glyph != DeletedGlyph) {
                if (GetGlyphPicture(glyph, pScreen)) {
                    FreePicture(cast(void*) GetGlyphPicture(glyph, pScreen), 0);
                    SetGlyphPicture(glyph, pScreen, null);
                }
                (*ps.UnrealizeGlyph) (pScreen, glyph);
            }
        }
    }
}

private GlyphHashSetPtr FindGlyphHashSet(CARD32 filled)
{
    int i = void;

    for (i = 0; i < NGLYPHHASHSETS; i++)
        if (glyphHashSets[i].entries >= filled)
            return &glyphHashSets[i];
    return null;
}

private GlyphRefPtr FindGlyphRef(GlyphHashPtr hash, CARD32 signature, Bool match, ubyte* sha1)
{
    CARD32 elt = void, step = void, s = void;
    GlyphPtr glyph = void;
    GlyphRefPtr table = void, gr = void, del = void;

    if ((hash is null) || (hash.hashSet is null))
        return null;

    CARD32 tableSize = hash.hashSet.size;

    table = hash.table;
    elt = signature % tableSize;
    step = 0;
    del = null;
    for (;;) {
        gr = &table[elt];
        s = gr.signature;
        glyph = gr.glyph;
        if (!glyph) {
            if (del)
                gr = del;
            break;
        }
        if (glyph == DeletedGlyph) {
            if (!del)
                del = gr;
            else if (gr == del)
                break;
        }
        else if (s == signature &&
                 (!match || memcmp(glyph.sha1.ptr, sha1, 20) == 0)) {
            break;
        }
        if (!step) {
            step = signature % hash.hashSet.rehash;
            if (!step)
                step = 1;
        }
        elt += step;
        if (elt >= tableSize)
            elt -= tableSize;
    }
    return gr;
}

int HashGlyph(xGlyphInfo* gi, CARD8* bits, c_ulong size, ubyte* sha1)
{
    void* ctx = x_sha1_init();
    int success = void;

    if (!ctx)
        return BadAlloc;

    success = x_sha1_update(ctx, gi, xGlyphInfo.sizeof);
    if (!success)
        return BadAlloc;
    success = x_sha1_update(ctx, bits, cast(int)size);
    if (!success)
        return BadAlloc;
    success = x_sha1_final(ctx, sha1);
    if (!success)
        return BadAlloc;
    return Success;
}

GlyphPtr FindGlyphByHash(ubyte* sha1, int format)
{
    GlyphRefPtr gr = void;
    CARD32 signature = *cast(CARD32*) sha1;

    if (!globalGlyphs[format].hashSet)
        return null;

    gr = FindGlyphRef(&globalGlyphs[format], signature, TRUE, sha1);

    if (gr.glyph && gr.glyph != DeletedGlyph)
        return gr.glyph;
    else
        return null;
}

// version (CHECK_DUPLICATES) {
void DuplicateRef(GlyphPtr glyph, char* where)
{
    ErrorF("Duplicate Glyph 0x%x from %s\n", glyph, where);
}

void CheckDuplicates(GlyphHashPtr hash, char* where)
{
    GlyphPtr g = void;
    int i = void, j = void;

    for (i = 0; i < hash.hashSet.size; i++) {
        g = hash.table[i].glyph;
        if (!g || g == DeletedGlyph)
            continue;
        for (j = i + 1; j < hash.hashSet.size; j++)
            if (hash.table[j].glyph == g)
                DuplicateRef(g, where);
    }
}
// } else {
// //#define CheckDuplicatescast(char*)(a,.ptrb)
// //#define DuplicateRef(a,b)
// }

private void FreeGlyphPicture(GlyphPtr glyph)
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        if (GetGlyphPicture(glyph, walkScreen))
            FreePicture(cast(void*) GetGlyphPicture(glyph, walkScreen), 0);

        PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("walkScreen"));
        if (ps)
            (*ps.UnrealizeGlyph) (walkScreen, glyph);
    });
}

void FreeGlyph(GlyphPtr glyph, int format)
{
    CheckDuplicates(&globalGlyphs[format], cast(char*)"FreeGlyph".ptr);
    mixin(BUG_RETURN!("glyph.refcnt == 0"));
    if (--glyph.refcnt == 0) {
        GlyphRefPtr gr = void;
        int i = void;
        int first = void;
        CARD32 signature = void;

        first = -1;
        for (i = 0; i < globalGlyphs[format].hashSet.size; i++)
            if (globalGlyphs[format].table[i].glyph == glyph) {
                if (first != -1)
                    DuplicateRef(glyph, cast(char*)"FreeGlyph check".ptr);
                first = i;
            }

        signature = *cast(CARD32*) glyph.sha1;
        gr = FindGlyphRef(&globalGlyphs[format], signature, TRUE, glyph.sha1.ptr);
        if (gr - globalGlyphs[format].table != first)
            DuplicateRef(glyph, cast(char*)"Found wrong one".ptr);
        if (gr && gr.glyph && gr.glyph != DeletedGlyph) {
            gr.glyph = DeletedGlyph;
            gr.signature = 0;
            globalGlyphs[format].tableEntries--;
        }

        FreeGlyphPicture(glyph);
        mixin(dixFreeObjectWithPrivatesM!("glyph", "PRIVATE_GLYPH"));
    }
}

void AddGlyph(GlyphSetPtr glyphSet, GlyphPtr glyph, Glyph id)
{
    GlyphRefPtr gr = void;
    CARD32 signature = void;

    CheckDuplicates(&globalGlyphs[glyphSet.fdepth], cast(char*)"AddGlyph topcast(char*) global".ptr);
    /* Locate existing matching glyph */
    signature = *cast(CARD32*) glyph.sha1;
    gr = FindGlyphRef(&globalGlyphs[glyphSet.fdepth], signature,
                      TRUE, glyph.sha1.ptr);
    if (gr.glyph && gr.glyph != DeletedGlyph && gr.glyph != glyph) {
        glyph = gr.glyph;
    }
    else if (gr.glyph != glyph) {
        gr.glyph = glyph;
        gr.signature = signature;
        globalGlyphs[glyphSet.fdepth].tableEntries++;
    }

    /* Insert/replace glyphset value */
    gr = FindGlyphRef(&glyphSet.hash, cast(uint)id, FALSE, null);
    ++glyph.refcnt;
    if (gr.glyph && gr.glyph != DeletedGlyph)
        FreeGlyph(gr.glyph, glyphSet.fdepth);
    else
        glyphSet.hash.tableEntries++;
    gr.glyph = glyph;
    gr.signature = cast(uint)id;
    CheckDuplicates(&globalGlyphs[glyphSet.fdepth], cast(char*)"AddGlyphcast(char*) bottom".ptr);
}

Bool DeleteGlyph(GlyphSetPtr glyphSet, Glyph id)
{
    GlyphRefPtr gr = void;
    GlyphPtr glyph = void;

    gr = FindGlyphRef(&glyphSet.hash, cast(uint)id, FALSE, null);
    glyph = gr.glyph;
    if (glyph && glyph != DeletedGlyph) {
        gr.glyph = DeletedGlyph;
        glyphSet.hash.tableEntries--;
        FreeGlyph(glyph, glyphSet.fdepth);
        return TRUE;
    }
    return FALSE;
}

GlyphPtr FindGlyph(GlyphSetPtr glyphSet, Glyph id)
{
    GlyphPtr glyph = void;

    glyph = FindGlyphRef(&glyphSet.hash, cast(uint)id, FALSE, null).glyph;
    if (glyph == DeletedGlyph)
        glyph = null;
    return glyph;
}

GlyphPtr AllocateGlyph(xGlyphInfo* gi, int fdepth)
{
    int size = void;
    int head_size = void;

    head_size = cast(int)((GlyphRec).sizeof + screenInfo.numScreens * PicturePtr.sizeof);
    size = (head_size + dixPrivatesSize(PRIVATE_GLYPH));
    GlyphPtr glyph = cast(GlyphPtr) calloc(1, size);
    if (!glyph)
        return null;
    glyph.refcnt = 1;
    glyph.size = cast(uint)(size + xGlyphInfo.sizeof);
    glyph.info = *gi;
    mixin(dixInitPrivates!("glyph", "cast(char*) glyph + head_size", "PRIVATE_GLYPH"));

    uint i = 0;
    mixin(DIX_FOR_EACH_SCREEN!q{
        SetGlyphPicture(glyph, walkScreen, null);
        PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("walkScreen"));
        if (ps) {
            if (!(ps.RealizeGlyph(walkScreen, glyph))) {
                i = walkScreenIdx;
                goto bail;
            }
        }
    });

    return glyph;

 bail:
    while (i--) {
        ScreenPtr walkScreen = dixGetScreenPtr(cast(uint)i);
        PictureScreenPtr ps = mixin(GetPictureScreenIfSet!("walkScreen"));
        if (ps)
            ps.UnrealizeGlyph(walkScreen, glyph);
    }

    mixin(dixFreeObjectWithPrivatesM!("glyph", "PRIVATE_GLYPH"));
    return null;
}

private Bool AllocateGlyphHash(GlyphHashPtr hash, GlyphHashSetPtr hashSet)
{
    if (hashSet is null)
        return FALSE;
    hash.table = cast(_GlyphRefRec*)calloc(hashSet.size, GlyphRefRec.sizeof);
    if (!hash.table)
        return FALSE;
    hash.hashSet = hashSet;
    hash.tableEntries = 0;
    return TRUE;
}

private Bool ResizeGlyphHash(GlyphHashPtr hash, CARD32 change, Bool global)
{
    CARD32 tableEntries = void;
    GlyphHashSetPtr hashSet = void;
    GlyphHashRec newHash = void;
    GlyphRefPtr gr = void;
    GlyphPtr glyph = void;
    int i = void;
    int oldSize = void;
    CARD32 s = void;

    tableEntries = hash.tableEntries + change;
    hashSet = FindGlyphHashSet(tableEntries);
    if (hashSet == hash.hashSet)
        return TRUE;
    if (global)
        CheckDuplicates(hash, cast(char*)"ResizeGlyphHashcast top".ptr);
    if (!AllocateGlyphHash(&newHash, hashSet))
        return FALSE;
    if (hash.table) {
        oldSize = cast(int)hash.hashSet.size;
        for (i = 0; i < oldSize; i++) {
            glyph = hash.table[i].glyph;
            if (glyph && glyph != DeletedGlyph) {
                s = hash.table[i].signature;
                if ((gr = FindGlyphRef(&newHash, s, global, glyph.sha1.ptr)) !is null) {
                    gr.signature = s;
                    gr.glyph = glyph;
                }
                ++newHash.tableEntries;
            }
        }
        free(hash.table);
    }
    *hash = newHash;
    if (global)
        CheckDuplicates(hash, cast(char*)"ResizeGlyphHashcast(char*) bottom".ptr);
    return TRUE;
}

Bool ResizeGlyphSet(GlyphSetPtr glyphSet, CARD32 change)
{
    return (ResizeGlyphHash(&glyphSet.hash, change, FALSE) &&
            ResizeGlyphHash(&globalGlyphs[glyphSet.fdepth], change, TRUE));
}

GlyphSetPtr AllocateGlyphSet(int fdepth, PictFormatPtr format)
{
    GlyphSetPtr glyphSet = void;

    if (!globalGlyphs[fdepth].hashSet) {
        if (!AllocateGlyphHash(&globalGlyphs[fdepth], &glyphHashSets[0]))
            return null;
    }

    glyphSet = mixin(dixAllocateObjectWithPrivates!("GlyphSetRec", "PRIVATE_GLYPHSET"));
    if (!glyphSet)
        return null;

    if (!AllocateGlyphHash(&glyphSet.hash, &glyphHashSets[0])) {
        free(glyphSet);
        return null;
    }
    glyphSet.refcnt = 1;
    glyphSet.fdepth = fdepth;
    glyphSet.format = format;
    return glyphSet;
}

int FreeGlyphSet(void* value, XID gid)
{
    GlyphSetPtr glyphSet = cast(GlyphSetPtr) value;

    if (--glyphSet.refcnt == 0) {
        CARD32 i = void, tableSize = glyphSet.hash.hashSet.size;
        GlyphRefPtr table = glyphSet.hash.table;
        GlyphPtr glyph = void;

        for (i = 0; i < tableSize; i++) {
            glyph = table[i].glyph;
            if (glyph && glyph != DeletedGlyph)
                FreeGlyph(glyph, glyphSet.fdepth);
        }
        if (!globalGlyphs[glyphSet.fdepth].tableEntries) {
            free(globalGlyphs[glyphSet.fdepth].table);
            globalGlyphs[glyphSet.fdepth].table = null;
            globalGlyphs[glyphSet.fdepth].hashSet = null;
        }
        else
            ResizeGlyphHash(&globalGlyphs[glyphSet.fdepth], 0, TRUE);
        free(table);
        mixin(dixFreeObjectWithPrivatesM!("glyphSet", "PRIVATE_GLYPHSET"));
    }
    return Success;
}

private void GlyphExtents(int nlist, GlyphListPtr list, GlyphPtr* glyphs, BoxPtr extents)
{
    int x1 = void, x2 = void, y1 = void, y2 = void;
    int n = void;
    GlyphPtr glyph = void;
    int x = void, y = void;

    x = 0;
    y = 0;
    extents.x1 = MAXSHORT;
    extents.x2 = MINSHORT;
    extents.y1 = MAXSHORT;
    extents.y2 = MINSHORT;
    while (nlist--) {
        x += list.xOff;
        y += list.yOff;
        n = list.len;
        list++;
        while (n--) {
            glyph = *glyphs++;
            x1 = x - glyph.info.x;
            if (x1 < MINSHORT)
                x1 = MINSHORT;
            y1 = y - glyph.info.y;
            if (y1 < MINSHORT)
                y1 = MINSHORT;
            x2 = x1 + glyph.info.width;
            if (x2 > MAXSHORT)
                x2 = MAXSHORT;
            y2 = y1 + glyph.info.height;
            if (y2 > MAXSHORT)
                y2 = MAXSHORT;
            if (x1 < extents.x1)
                extents.x1 = cast(short)x1;
            if (x2 > extents.x2)
                extents.x2 = cast(short)x2;
            if (y1 < extents.y1)
                extents.y1 = cast(short)y1;
            if (y2 > extents.y2)
                extents.y2 = cast(short)y2;
            x += glyph.info.xOff;
            y += glyph.info.yOff;
        }
    }
}

enum string NeedsComponent(string f) = `(PIXMAN_FORMAT_A(` ~ f ~ `) != 0 && PIXMAN_FORMAT_RGB(` ~ f ~ `) != 0)`;

void CompositeGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr lists, GlyphPtr* glyphs)
{
    PictureScreenPtr ps = mixin(GetPictureScreen!("pDst.pDrawable.pScreen"));

    ValidatePicture(pSrc);
    ValidatePicture(pDst);
    (*ps.Glyphs) (op, pSrc, pDst, maskFormat, xSrc, ySrc, nlist, lists,
                   glyphs);
}

Bool miRealizeGlyph(ScreenPtr pScreen, GlyphPtr glyph)
{
    return TRUE;
}

void miUnrealizeGlyph(ScreenPtr pScreen, GlyphPtr glyph)
{
}

void miGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs)
{
    PicturePtr pPicture = void;
    PixmapPtr pMaskPixmap = null;
    PicturePtr pMask = void;
    ScreenPtr pScreen = pDst.pDrawable.pScreen;
    int width = 0, height = 0;
    int x = void, y = void;
    int xDst = list.xOff, yDst = list.yOff;
    int n = void;
    GlyphPtr glyph = void;
    int error = void;
    BoxRec extents = { 0, 0, 0, 0 };
    CARD32 component_alpha = void;

    if (maskFormat) {
        GCPtr pGC = void;
        xRectangle rect = void;

        GlyphExtents(nlist, list, glyphs, &extents);

        if (extents.x2 <= extents.x1 || extents.y2 <= extents.y1)
            return;
        width = extents.x2 - extents.x1;
        height = extents.y2 - extents.y1;
        pMaskPixmap = (*pScreen.CreatePixmap) (pScreen, width, height,
                                                maskFormat.depth,
                                                CREATE_PIXMAP_USAGE_SCRATCH);
        if (!pMaskPixmap)
            return;
        component_alpha = mixin(NeedsComponent!(`maskFormat.format`));
        pMask = CreatePicture(0, &pMaskPixmap.drawable,
                              maskFormat, CPComponentAlpha, cast(uint*)&component_alpha,
                              serverClient, &error);
        if (!pMask) {
            dixDestroyPixmap(pMaskPixmap, 0);
            return;
        }
        pGC = GetScratchGC(pMaskPixmap.drawable.depth, pScreen);
        ValidateGC(&pMaskPixmap.drawable, pGC);
        rect.x = 0;
        rect.y = 0;
        rect.width = cast(ushort)width;
        rect.height = cast(ushort)height;
        (*pGC.ops.PolyFillRect) (&pMaskPixmap.drawable, pGC, 1, &rect);
        FreeScratchGC(pGC);
        x = -extents.x1;
        y = -extents.y1;
    }
    else {
        pMask = pDst;
        x = 0;
        y = 0;
    }
    while (nlist--) {
        x += list.xOff;
        y += list.yOff;
        n = list.len;
        while (n--) {
            glyph = *glyphs++;
            pPicture = GetGlyphPicture(glyph, pScreen);

            if (pPicture) {
                if (maskFormat) {
                    CompositePicture(PictOpAdd,
                                     pPicture,
                                     null,
                                     pMask,
                                     0, 0,
                                     0, 0,
                                     cast(short)(x - glyph.info.x),
                                     cast(short)(y - glyph.info.y),
                                     glyph.info.width, glyph.info.height);
                }
                else {
                    CompositePicture(op,
                                     pSrc,
                                     pPicture,
                                     pDst,
                                     cast(short)(xSrc + (x - glyph.info.x) - xDst),
                                     cast(short)(ySrc + (y - glyph.info.y) - yDst),
                                     0, 0,
                                     cast(short)(x - glyph.info.x),
                                     cast(short)(y - glyph.info.y),
                                     glyph.info.width, glyph.info.height);
                }
            }

            x += glyph.info.xOff;
            y += glyph.info.yOff;
        }
        list++;
    }
    if (maskFormat) {
        x = extents.x1;
        y = extents.y1;
        CompositePicture(op,
                         pSrc,
                         pMask,
                         pDst,
                         cast(short)(xSrc + x - xDst),
                         cast(short)(ySrc + y - yDst), 0, 0, cast(short)x, cast(short)y, cast(ushort)width, cast(ushort)height);
        FreePicture(cast(void*) pMask, cast(XID) 0);
        dixDestroyPixmap(pMaskPixmap, 0);
    }
}

PicturePtr GetGlyphPicture(GlyphPtr glyph, ScreenPtr pScreen)
{
    if (pScreen.isGPU)
        return null;
    return mixin(GlyphPicture!("glyph"))[pScreen.myNum];
}

void SetGlyphPicture(GlyphPtr glyph, ScreenPtr pScreen, PicturePtr picture)
{
    mixin(GlyphPicture!("glyph"))[pScreen.myNum] = picture;
}
