module exa.exa_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
 * Copyright (C) 2000 Keith Packard, member of The XFree86 Project, Inc.
 *               2005 Zack Rusin, Trolltech
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
 * SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS, IN NO EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN
 * AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING
 * OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
 * SOFTWARE.
 */

 
public import include.exa_i;

//public import x11.X;
public import externs.X11.extensions.renderproto;

public import include.shmint;

public import include.scrnintstr;
public import include.pixmapstr;
public import include.windowstr;
public import include.servermd;
public import include.gcstruct;
public import include.input;
public import mi.mipointer;
public import include.mi;
public import include.dix;
public import include.fb;
public import include.fboverlay;
public import include.fbpict;
public import include.glyphstr;
public import dix.damage;
public import exa_accel;

import include.exa_i;
import include.gc;
import include.privates;

enum DEBUG_TRACE_FALL =	0;
enum DEBUG_MIGRATE =		0;
enum DEBUG_PIXMAP =		0;
enum DEBUG_OFFSCREEN =		0;
enum DEBUG_GLYPH_CACHE =	0;

static if (DEBUG_TRACE_FALL) {
enum string EXA_FALLBACK(string x) = `{						
	ErrorF("EXA fallback at %s: ", __FUNCTION__.ptr);		
	// ErrorF x = void;						
}`;

char exaDrawableLocation(DrawablePtr pDrawable);
} else {
//#define EXA_FALLBACK(x)
}

static if (DEBUG_PIXMAP) {
// enum string DBG_PIXMAP(string a) ""= `ErrorF a = void;""`;
// enum string DBG_PIXMAP*string 
} else {
//#define DBG_PIXMAP(a)
}

enum EXA_MAX_FB =   FB_OVERLAY_MAX;


version (DEBUG) {
enum string EXA_FatalErrorDebug(string x) = `FatalError x = void;`;
enum string EXA_FatalErrorDebugWithRet(string x, string ret) = `FatalError x = void;`;
} else {
// enum string EXA_FatalErrorDebug(string x) = `ErrorF();`;
enum string EXA_FatalErrorDebugWithRet(string x, string ret) = `{ 
    // ErrorF x = void; 
    return `~ret~`; 
}`;
}

/**
 * This is the list of migration heuristics supported by EXA.  See
 * exaDoMigration() for what their implementations do.
 */
enum ExaMigrationHeuristic {
    ExaMigrationGreedy,
    ExaMigrationAlways,
    ExaMigrationSmart
}
alias ExaMigrationGreedy = ExaMigrationHeuristic.ExaMigrationGreedy;
alias ExaMigrationAlways = ExaMigrationHeuristic.ExaMigrationAlways;
alias ExaMigrationSmart = ExaMigrationHeuristic.ExaMigrationSmart;


struct _ExaCachedGlyphRec {
    ubyte[20] sha1;
}alias ExaCachedGlyphRec = _ExaCachedGlyphRec;
alias ExaCachedGlyphPtr = ExaCachedGlyphRec*;

struct _ExaGlyphCacheRec {
    /* The identity of the cache, statically configured at initialization */
    uint format;
    int glyphWidth;
    int glyphHeight;

    int size;                   /* Size of cache; eventually this should be dynamically determined */

    /* Hash table mapping from glyph sha1 to position in the glyph; we use
     * open addressing with a hash table size determined based on size and large
     * enough so that we always have a good amount of free space, so we can
     * use linear probing. (Linear probing is preferable to double hashing
     * here because it allows us to easily remove entries.)
     */
    int* hashEntries;
    int hashSize;

    ExaCachedGlyphPtr glyphs;
    int glyphCount;             /* Current number of glyphs */

    PicturePtr picture;         /* Where the glyphs of the cache are stored */
    int yOffset;                /* y location within the picture where the cache starts */
    int columns;                /* Number of columns the glyphs are laid out in */
    int evictionPosition;       /* Next random position to evict a glyph */
}alias ExaGlyphCacheRec = _ExaGlyphCacheRec;
alias ExaGlyphCachePtr = ExaGlyphCacheRec*;

enum EXA_NUM_GLYPH_CACHES = 4;

enum EXA_FALLBACK_COPYWINDOW = (1 << 0);
enum EXA_ACCEL_COPYWINDOW = (1 << 1);

struct _ExaMigrationRec {
    Bool as_dst;
    Bool as_src;
    PixmapPtr pPix;
    RegionPtr pReg;
}alias ExaMigrationRec = _ExaMigrationRec;
alias ExaMigrationPtr = _ExaMigrationRec*;

alias EnableDisableFBAccessProcPtr = void function(ScreenPtr, Bool);
struct _ExaScreenPrivRec {
    ExaDriverPtr info;
    ScreenBlockHandlerProcPtr SavedBlockHandler;
    ScreenWakeupHandlerProcPtr SavedWakeupHandler;
    CreateGCProcPtr SavedCreateGC;
    GetImageProcPtr SavedGetImage;
    GetSpansProcPtr SavedGetSpans;
    CreatePixmapProcPtr SavedCreatePixmap;
    CopyWindowProcPtr SavedCopyWindow;
    ChangeWindowAttributesProcPtr SavedChangeWindowAttributes;
    BitmapToRegionProcPtr SavedBitmapToRegion;
    ModifyPixmapHeaderProcPtr SavedModifyPixmapHeader;
    SharePixmapBackingProcPtr SavedSharePixmapBacking;
    SetSharedPixmapBackingProcPtr SavedSetSharedPixmapBacking;
    SourceValidateProcPtr SavedSourceValidate;
    CompositeProcPtr SavedComposite;
    TrianglesProcPtr SavedTriangles;
    GlyphsProcPtr SavedGlyphs;
    TrapezoidsProcPtr SavedTrapezoids;
    AddTrapsProcPtr SavedAddTraps;
    void function(ExaMigrationPtr pixmaps, int npixmaps, Bool can_accel) @nogc nothrow do_migration;
    Bool function(PixmapPtr pPixmap) @nogc nothrow pixmap_has_gpu_copy;
    void function(PixmapPtr pPixmap) @nogc nothrow do_move_in_pixmap;
    void function(PixmapPtr pPixmap) @nogc nothrow do_move_out_pixmap;
    void function(PixmapPtr pPixmap, int index, RegionPtr pReg) @nogc nothrow prepare_access_reg;

    Bool swappedOut;
    ExaMigrationHeuristic migration;
    Bool checkDirtyCorrectness;
    uint disableFbCount;
    Bool optimize_migration;
    uint offScreenCounter;
    uint numOffscreenAvailable;
    CARD32 lastDefragment;
    CARD32 nextDefragment;
    PixmapPtr deferred_mixed_pixmap;

    import include.exa_i;
    /* Reference counting for accessed pixmaps */
    struct _Access {
        PixmapPtr pixmap;
        int count;
        Bool retval;
    }_Access[EXA_NUM_PREPARE_INDICES] access;

    /* Holds information on fallbacks that cannot be relayed otherwise. */
    uint fallback_flags;
    uint fallback_counter;

    ExaGlyphCacheRec[EXA_NUM_GLYPH_CACHES] glyphCaches;

    /**
     * Regions affected by fallback composite source / mask operations.
     */

    RegionRec srcReg;
    RegionRec maskReg;
    PixmapPtr srcPix;
    PixmapPtr maskPix;

    DevPrivateKeyRec pixmapPrivateKeyRec;
    DevPrivateKeyRec gcPrivateKeyRec;
}alias ExaScreenPrivRec = _ExaScreenPrivRec;
alias ExaScreenPrivPtr = ExaScreenPrivRec*;

DevPrivateKeyRec exaScreenPrivateKeyRec;

enum exaScreenPrivateKey = (&exaScreenPrivateKeyRec);

enum string ExaGetScreenPriv(string s) = `(cast(ExaScreenPrivPtr)dixGetPrivate(&(` ~ s ~ `).devPrivates, exaScreenPrivateKey))`;
enum string ExaScreenPriv(string s) = `ExaScreenPrivPtr pExaScr = ` ~ ExaGetScreenPriv!(s) ~ `;`;

enum string ExaGetGCPriv(string gc) = `(cast(ExaGCPrivPtr)dixGetPrivateAddr(&(` ~ gc ~ `).devPrivates, &` ~ ExaGetScreenPriv!(`` ~ gc ~ `.pScreen`) ~ `.gcPrivateKeyRec))`;
enum string ExaGCPriv(string gc) = `ExaGCPrivPtr pExaGC = ` ~ ExaGetGCPriv!(gc) ~ `;`;

/*
 * Some macros to deal with function wrapping.
 */
enum string wrap(string priv, string real_, string mem, string func) = `{
    ` ~ priv ~ `.Saved`~mem~` = ` ~ real_ ~ `.` ~ mem ~ `; 
    ` ~ real_ ~ `.` ~ mem ~ ` = &` ~ func ~ `; 
}`;

enum string unwrap(string priv, string real_, string mem) = `{
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ priv ~ `.Saved`~mem~`; 
}`;

enum string swap(string priv, string real_, string mem) = `{
    typeof(`~real_~`.`~mem~`) tmp = `~priv~`.Saved`~mem~`;
    `~priv~`.Saved`~mem~` = `~real_~`.`~mem~`;
    `~real_~`.`~mem~` = tmp;
}`;

enum string EXA_PRE_FALLBACK(string _screen_) = `
    ` ~ ExaScreenPriv!(_screen_) ~ ` 
    pExaScr.fallback_counter++;`;

enum string EXA_POST_FALLBACK(string _screen_) = `
    pExaScr.fallback_counter--;`;

enum string EXA_PRE_FALLBACK_GC(string _gc_) = `
    ` ~ ExaScreenPriv!(`` ~ _gc_ ~ `.pScreen`) ~ ` 
    ` ~ ExaGCPriv!(_gc_) ~ ` 
    pExaScr.fallback_counter++; 
    ` ~ swap!(`pExaGC`, _gc_, `ops`) ~ ``;

enum string EXA_POST_FALLBACK_GC(string _gc_) = `{
    pExaScr.fallback_counter--; 
    ` ~ swap!(`pExaGC`, _gc_, `ops`) ~ `;}`;

/** Align an offset to an arbitrary alignment */
enum string EXA_ALIGN(string offset, string align_) = `(((` ~ offset ~ `) + (` ~ align_ ~ `) - 1) - 
	(((` ~ offset ~ `) + (` ~ align_ ~ `) - 1) % (` ~ align_ ~ `)))`;
/** Align an offset to a power-of-two alignment */
enum string EXA_ALIGN2(string offset, string align_) = `(((` ~ offset ~ `) + (` ~ align_ ~ `) - 1) & ~((` ~ align_ ~ `) - 1))`;

enum EXA_PIXMAP_SCORE_MOVE_IN =    10;
enum EXA_PIXMAP_SCORE_MAX =	    20;
enum EXA_PIXMAP_SCORE_MOVE_OUT =   -10;
enum EXA_PIXMAP_SCORE_MIN =	    -20;
enum EXA_PIXMAP_SCORE_PINNED =	    1000;
enum EXA_PIXMAP_SCORE_INIT =	    1001;

enum string ExaGetPixmapPriv(string p) = `(cast(ExaPixmapPrivPtr)dixGetPrivateAddr(&(` ~ p ~ `).devPrivates, &` ~ ExaGetScreenPriv!(`(` ~ p ~ `).drawable.pScreen`) ~ `.pixmapPrivateKeyRec))`;
enum string ExaPixmapPriv(string p) = `ExaPixmapPrivPtr pExaPixmap = ` ~ ExaGetPixmapPriv!(p) ~ `;`;

enum EXA_RANGE_PITCH = (1 << 0);
enum EXA_RANGE_WIDTH = (1 << 1);
enum EXA_RANGE_HEIGHT = (1 << 2);

struct _ExaPixmapPrivRec {
    ExaOffscreenArea* area;
    int score;                  /**< score for the move-in vs move-out heuristic */
    Bool use_gpu_copy;

    CARD8* sys_ptr;             /**< pointer to pixmap data in system memory */
    int sys_pitch;              /**< pitch of pixmap in system memory */

    CARD8* fb_ptr;              /**< pointer to pixmap data in framebuffer memory */
    int fb_pitch;               /**< pitch of pixmap in framebuffer memory */
    uint fb_size;       /**< size of pixmap in framebuffer memory */

    /**
     * Holds information about whether this pixmap can be used for
     * acceleration (== 0) or not (> 0).
     *
     * Contains a OR'ed combination of the following values:
     * EXA_RANGE_PITCH - set if the pixmap's pitch is out of range
     * EXA_RANGE_WIDTH - set if the pixmap's width is out of range
     * EXA_RANGE_HEIGHT - set if the pixmap's height is out of range
     */
    uint accel_blocked;

    /**
     * The damage record contains the areas of the pixmap's current location
     * (framebuffer or system) that have been damaged compared to the other
     * location.
     */
    DamagePtr pDamage;
    /**
     * The valid regions mark the valid bits (at least, as they're derived from
     * damage, which may be overreported) of a pixmap's system and FB copies.
     */
    RegionRec validSys, validFB;
    /**
     * Driver private storage per EXA pixmap
     */
    void* driverPriv;
}alias ExaPixmapPrivRec = _ExaPixmapPrivRec;
alias ExaPixmapPrivPtr = ExaPixmapPrivRec*;

struct _ExaGCPrivRec {
    /* GC values from the layer below. */
    const(GCOps)* Savedops;
    const(GCFuncs)* Savedfuncs;
}alias ExaGCPrivRec = _ExaGCPrivRec;
alias ExaGCPrivPtr = ExaGCPrivRec*;

struct _ExaCompositeRectRec {
    PicturePtr pDst;
    INT16 xSrc;
    INT16 ySrc;
    INT16 xMask;
    INT16 yMask;
    INT16 xDst;
    INT16 yDst;
    INT16 width;
    INT16 height;
}alias ExaCompositeRectRec = _ExaCompositeRectRec;
alias ExaCompositeRectPtr = ExaCompositeRectRec*;

/**
 * exaDDXDriverInit must be implemented by the DDX using EXA, and is the place
 * to set EXA options or hook in screen functions to handle using EXA as the AA.
  */
void exaDDXDriverInit(ScreenPtr pScreen);

/* exa_unaccel.c */
void exaPrepareAccessGC(GCPtr pGC);

void exaFinishAccessGC(GCPtr pGC);

void ExaCheckFillSpans(DrawablePtr pDrawable, GCPtr pGC, int nspans, DDXPointPtr ppt, int* pwidth, int fSorted);

void ExaCheckSetSpans(DrawablePtr pDrawable, GCPtr pGC, char* psrc, DDXPointPtr ppt, int* pwidth, int nspans, int fSorted);

void ExaCheckPutImage(DrawablePtr pDrawable, GCPtr pGC, int depth, int x, int y, int w, int h, int leftPad, int format, char* bits);

void ExaCheckCopyNtoN(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure);

RegionPtr ExaCheckCopyArea(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int w, int h, int dstx, int dsty);

RegionPtr ExaCheckCopyPlane(DrawablePtr pSrc, DrawablePtr pDst, GCPtr pGC, int srcx, int srcy, int w, int h, int dstx, int dsty, c_ulong bitPlane);

void ExaCheckPolyPoint(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr pptInit);

void ExaCheckPolylines(DrawablePtr pDrawable, GCPtr pGC, int mode, int npt, DDXPointPtr ppt);

void ExaCheckPolySegment(DrawablePtr pDrawable, GCPtr pGC, int nsegInit, xSegment* pSegInit);

void ExaCheckPolyArc(DrawablePtr pDrawable, GCPtr pGC, int narcs, xArc* pArcs);

void ExaCheckPolyFillRect(DrawablePtr pDrawable, GCPtr pGC, int nrect, xRectangle* prect);

void ExaCheckImageGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);

void ExaCheckPolyGlyphBlt(DrawablePtr pDrawable, GCPtr pGC, int x, int y, uint nglyph, CharInfoPtr* ppci, void* pglyphBase);

void ExaCheckPushPixels(GCPtr pGC, PixmapPtr pBitmap, DrawablePtr pDrawable, int w, int h, int x, int y);

void ExaCheckCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc);

void ExaCheckGetImage(DrawablePtr pDrawable, int x, int y, int w, int h, uint format, c_ulong planeMask, char* d);

void ExaCheckGetSpans(DrawablePtr pDrawable, int wMax, DDXPointPtr ppt, int* pwidth, int nspans, char* pdstStart);

void ExaCheckAddTraps(PicturePtr pPicture, INT16 x_off, INT16 y_off, int ntrap, xTrap* traps);

/* exa_accel.c */

pragma(inline, true) Bool exaGCReadsDestination(DrawablePtr pDrawable, c_ulong planemask, uint fillStyle, ubyte alu, Bool clientClip)
{
    return ((alu != GXcopy && alu != GXclear && alu != GXset &&
             alu != GXcopyInverted) || fillStyle == FillStippled ||
            clientClip != FALSE || !mixin(EXA_PM_IS_SOLID!("pDrawable", "planemask")));
}

void exaCopyWindow(WindowPtr pWin, xPoint ptOldOrg, RegionPtr prgnSrc);

Bool exaFillRegionTiled(DrawablePtr pDrawable, RegionPtr pRegion, PixmapPtr pTile, DDXPointPtr pPatOrg, CARD32 planemask, CARD32 alu, Bool clientClip);

void exaGetImage(DrawablePtr pDrawable, int x, int y, int w, int h, uint format, c_ulong planeMask, char* d);

RegionPtr exaCopyArea(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, int srcx, int srcy, int width, int height, int dstx, int dsty);

Bool exaHWCopyNtoN(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown);

void exaCopyNtoN(DrawablePtr pSrcDrawable, DrawablePtr pDstDrawable, GCPtr pGC, BoxPtr pbox, int nbox, int dx, int dy, Bool reverse, Bool upsidedown, Pixel bitplane, void* closure);

// const(GCOps) exaOps;

void ExaCheckComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height);

void ExaCheckGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs);

/* exa_offscreen.c */
void ExaOffscreenSwapOut(ScreenPtr pScreen);

void ExaOffscreenSwapIn(ScreenPtr pScreen);

ExaOffscreenArea* ExaOffscreenDefragment(ScreenPtr pScreen);

Bool exaOffscreenInit(ScreenPtr pScreen);

void ExaOffscreenFini(ScreenPtr pScreen);

/* exa.c */
// Bool ExaDoPrepareAccess(PixmapPtr pPixmap, int index);

// void exaPrepareAccess(DrawablePtr pDrawable, int index);

// void exaFinishAccess(DrawablePtr pDrawable, int index);

// void exaDestroyPixmap(PixmapPtr pPixmap);

// void exaPixmapDirty(PixmapPtr pPix, int x1, int y1, int x2, int y2);

// void exaGetDrawableDeltas(DrawablePtr pDrawable, PixmapPtr pPixmap, int* xp, int* yp);

// Bool exaPixmapHasGpuCopy(PixmapPtr p);

// PixmapPtr exaGetOffscreenPixmap(DrawablePtr pDrawable, int* xp, int* yp);

// PixmapPtr exaGetDrawablePixmap(DrawablePtr pDrawable);

// void exaSetFbPitch(ExaScreenPrivPtr pExaScr, ExaPixmapPrivPtr pExaPixmap, int w, int h, int bpp);

// void exaSetAccelBlock(ExaScreenPrivPtr pExaScr, ExaPixmapPrivPtr pExaPixmap, int w, int h, int bpp);

// void exaDoMigration(ExaMigrationPtr pixmaps, int npixmaps, Bool can_accel);

// Bool exaPixmapIsPinned(PixmapPtr pPix);

// const(GCFuncs) exaGCFuncs;

/* exa_classic.c */
PixmapPtr exaCreatePixmap_classic(ScreenPtr pScreen, int w, int h, int depth, uint usage_hint);

Bool exaModifyPixmapHeader_classic(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData);

void exaPixmapDestroy_classic(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pPixmap);

Bool exaPixmapHasGpuCopy_classic(PixmapPtr pPixmap);

/* exa_driver.c */
PixmapPtr exaCreatePixmap_driver(ScreenPtr pScreen, int w, int h, int depth, uint usage_hint);

Bool exaModifyPixmapHeader_driver(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData);

void exaPixmapDestroy_driver(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pPixmap);

Bool exaPixmapHasGpuCopy_driver(PixmapPtr pPixmap);

/* exa_mixed.c */
PixmapPtr exaCreatePixmap_mixed(ScreenPtr pScreen, int w, int h, int depth, uint usage_hint);

Bool exaModifyPixmapHeader_mixed(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData);

void exaPixmapDestroy_mixed(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pPixmap);

Bool exaPixmapHasGpuCopy_mixed(PixmapPtr pPixmap);

/* exa_migration_mixed.c */
// void exaCreateDriverPixmap_mixed(PixmapPtr pPixmap);

void exaDoMigration_mixed(ExaMigrationPtr pixmaps, int npixmaps, Bool can_accel);

void exaMoveInPixmap_mixed(PixmapPtr pPixmap);

// void exaDamageReport_mixed(DamagePtr pDamage, RegionPtr pRegion, void* closure);

void exaPrepareAccessReg_mixed(PixmapPtr pPixmap, int index, RegionPtr pReg);

Bool exaSetSharedPixmapBacking_mixed(PixmapPtr pPixmap, void* handle);
Bool exaSharePixmapBacking_mixed(PixmapPtr pPixmap, ScreenPtr secondary, void** handle_p);

/* exa_render.c */
Bool exaOpReadsDestination(CARD8 op);

void exaComposite(CARD8 op, PicturePtr pSrc, PicturePtr pMask, PicturePtr pDst, INT16 xSrc, INT16 ySrc, INT16 xMask, INT16 yMask, INT16 xDst, INT16 yDst, CARD16 width, CARD16 height);

void exaCompositeRects(CARD8 op, PicturePtr Src, PicturePtr pMask, PicturePtr pDst, int nrect, ExaCompositeRectPtr rects);

void exaTrapezoids(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntrap, xTrapezoid* traps);

void exaTriangles(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntri, xTriangle* tris);

/* exa_glyph.c */
void exaGlyphsInit(ScreenPtr pScreen);

void exaGlyphsFini(ScreenPtr pScreen);

void exaGlyphs(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int nlist, GlyphListPtr list, GlyphPtr* glyphs);

/* exa_migration_classic.c */
void exaCopyDirtyToSys(ExaMigrationPtr migrate);

void exaCopyDirtyToFb(ExaMigrationPtr migrate);

void exaDoMigration_classic(ExaMigrationPtr pixmaps, int npixmaps, Bool can_accel);

void exaPixmapSave(ScreenPtr pScreen, ExaOffscreenArea* area);

void exaMoveOutPixmap_classic(PixmapPtr pPixmap);

void exaMoveInPixmap_classic(PixmapPtr pPixmap);

void exaPrepareAccessReg_classic(PixmapPtr pPixmap, int index, RegionPtr pReg);

// void exaMoveOutPixmap(PixmapPtr pPixmap);

// void ExaOffscreenMarkUsed(PixmapPtr pPixmap);

                          /* EXAPRIV_H */
