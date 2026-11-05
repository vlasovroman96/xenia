module dix.pixmap;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1993, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

*/

import build.dix_config;

//import x11.X;
//import externs.X11.extensions._render;

import mi.mi_priv;

import dix.scrnintstr;
import common.misc;
import os.os;
import dix.window;
import dix.resource;
import dix.dixstruct_priv;
import common.servermd;
import dix.picturestr;
import randr.randr;
import miext.damage.damage_;
import dix.gc;
import render.picture;
import externs.attrs;
import dix.picture;

public import common.misc;
public import dix.scrintstr;
public import region;
// //public import externs.X11.extensions._randr;
import dix.pixmap;

public import dix.scrintstr;
public import dix.privates;
public import dix.damage;
// //public import externs.X11.extensions._randr;
public import dix.picturestr;
import xf86Bus;

struct _Drawable {
    ubyte type;         /* DRAWABLE_<type> */
    ubyte class_;        /* specific to type */
    ubyte depth;
    ubyte bitsPerPixel;
    XID id;                     /* resource id */
    short x;                    /* window: screen absolute, pixmap: 0 */
    short y;                    /* window: screen absolute, pixmap: 0 */
    ushort width;
    ushort height;
    ScreenPtr pScreen;
    c_ulong serialNumber;
}

alias DrawableRec = _Drawable;
alias DrawablePtr = DrawableRec*;

/*
 * PIXMAP -- device dependent
 */

struct _Pixmap {
    DrawableRec drawable;
    PrivateRec* devPrivates;
    int refcnt;
    int devKind;                /* This is the pitch of the pixmap, typically width*bpp/8. */
    DevUnion devPrivate;        /* When !NULL, devPrivate.ptr points to the raw pixel data. */
    short screen_x;
    short screen_y;
    uint usage_hint;        /* see CREATE_PIXMAP_USAGE_* */

    PixmapPtr primary_pixmap;    /* pointer to primary copy of pixmap for pixmap sharing */
}

alias PixmapRec = _Pixmap;


struct _PixmapDirtyUpdate {
    DrawablePtr src;            /* Root window / shared pixmap */
    PixmapPtr secondary_dst;    /* Shared / scanout pixmap */
    int x, y;
    DamagePtr damage;
    xorg_list ent;
    int dst_x, dst_y;
    Rotation rotation;
    PictTransform transform;
    pixman_f_transform f_transform, f_inverse;
}

alias PixmapDirtyUpdateRec = _PixmapDirtyUpdate;
alias PixmapDirtyUpdatePtr = PixmapDirtyUpdateRec*;

pragma(inline, true) void PixmapRegionInit(RegionPtr region, PixmapPtr pixmap)
{
    BoxRec box = {
        x2: cast(short)pixmap.drawable.width,
        y2: cast(short)pixmap.drawable.height,
    };
    RegionInit(region, &box, 1);
}

/* types for Drawable */
enum DRAWABLE_WINDOW = 0;
enum DRAWABLE_PIXMAP = 1;
enum UNDRAWABLE_WINDOW = 2;

/* corresponding type masks for dixLookupDrawable() */
enum M_DRAWABLE_WINDOW =	(1<<0);
enum M_DRAWABLE_PIXMAP =	(1<<1);
enum M_UNDRAWABLE_WINDOW =	(1<<2);
enum M_ANY =			(-1);
enum M_WINDOW =	(M_DRAWABLE_WINDOW|M_UNDRAWABLE_WINDOW);
enum M_DRAWABLE =	(M_DRAWABLE_WINDOW|M_DRAWABLE_PIXMAP);
enum M_UNDRAWABLE =	(M_UNDRAWABLE_WINDOW);

/* flags to PaintWindow() */
enum PW_BACKGROUND = 0;
enum PW_BORDER = 1;

enum NullPixmap = cast(PixmapPtr)0;

// alias DrawablePtr = _Drawable*;
alias PixmapPtr = _Pixmap*;

union PixUnion {
    PixmapPtr pixmap;
    c_ulong pixel;
}

enum string SamePixUnion(string a,string b,string isPixel) = `
    ((` ~ isPixel ~ `) ? (` ~ a ~ `).pixel == (` ~ b ~ `).pixel : (` ~ a ~ `).pixmap == (` ~ b ~ `).pixmap)`;

enum string EqualPixUnion(string as, string a, string bs, string b) = `
    ((` ~ as ~ `) == (` ~ bs ~ `) && (` ~ SamePixUnion! (a, b, as) ~ `))`;

enum string OnScreenDrawable(string type) = `
	(` ~ type ~ ` == DRAWABLE_WINDOW)`;

enum string WindowDrawable(string type) = `
	((` ~ type ~ ` == DRAWABLE_WINDOW) || (` ~ type ~ ` == UNDRAWABLE_WINDOW))`;

// int GetScratchPixmapHeader(ScreenPtr pScreen, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData);

// int FreeScratchPixmapHeader(PixmapPtr);

int PixmapScreenInit(ScreenPtr);

// int AllocatePixmap(ScreenPtr, int);

// int FreePixmap(PixmapPtr);

// int PixmapShareToSecondary(PixmapPtr pixmap, ScreenPtr secondary);

// int PixmapUnshareSecondaryPixmap(PixmapPtr secondary_pixmap);

enum HAS_DIRTYTRACKING_ROTATION = 1;
enum HAS_DIRTYTRACKING_DRAWABLE_SRC = 1;
// int PixmapStartDirtyTracking(DrawablePtr src, PixmapPtr slave_dst, int x, int y, int dst_x, int dst_y, Rotation rotation);

// int PixmapStopDirtyTracking(DrawablePtr src, PixmapPtr slave_dst);

/* helper function, drivers can do this themselves if they can do it more
   efficiently */
// int PixmapSyncDirtyHelper(PixmapDirtyUpdatePtr dirty);

// int PixmapDirtyCopyArea(PixmapPtr dst, DrawablePtr src, int x, int y, int dst_x, int dst_y, RegionPtr dirty_region);
/*
 * Scratch pixmap APIs are provided for source and binary compatibility.  In
 * older versions, DIX would store a freed scratch pixmap for future use.  This
 * optimization is not really that impactful on modern systems with decent
 * system heap management and modern CPUs, and it interferes with memory
 * analysis tools such as ASan, malloc history, etc.
 *
 * Now, these entry points just allocte/free pixmaps.
 */

/* callable by ddx */
PixmapPtr GetScratchPixmapHeader(ScreenPtr pScreen, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData)
{
    PixmapPtr pPixmap = (*pScreen.CreatePixmap) (pScreen, 0, 0, depth, 0);
    if (pPixmap) {
        if ((*pScreen.ModifyPixmapHeader) (pPixmap, width, height, depth,
                                            bitsPerPixel, devKind, pPixData))
            return pPixmap;
        dixDestroyPixmap(pPixmap, 0);
    }
    return NullPixmap;
}

/* callable by ddx */
void FreeScratchPixmapHeader(PixmapPtr pPixmap)
{
    if (pPixmap) {
        pPixmap.devPrivate.ptr = null; /* help catch/avoid heap-use-after-free */
        dixDestroyPixmap(pPixmap, 0);
    }
}

Bool PixmapScreenInit(ScreenPtr pScreen)
{
    uint pixmap_size = void;

    pixmap_size = cast(uint)((PixmapRec).sizeof + dixScreenSpecificPrivatesSize(pScreen, PRIVATE_PIXMAP));
    pScreen.totalPixmapSize =
        mixin(BitmapBytePad!("pixmap_size * 8"));

// version (CONFIG_LEGACY_NVIDIA_PADDING) {
    /* This field is used by the 470 and 390 proprietary nvidia DDX driver, and should always be NULL */
    pScreen.reserved_for_nvidia_470_and_390 = null;
// }
    return TRUE;
}

/* callable by ddx */
PixmapPtr AllocatePixmap(ScreenPtr pScreen, int pixDataSize)
{
    PixmapPtr pPixmap = void;

    assert(pScreen.totalPixmapSize > 0);

    if (pScreen.totalPixmapSize > (cast(size_t) - 1) - pixDataSize)
        return NullPixmap;

    pPixmap = cast(PixmapPtr)calloc(1, pScreen.totalPixmapSize + pixDataSize);
    if (!pPixmap)
        return NullPixmap;

    mixin(dixInitScreenPrivates!("pScreen", "pPixmap", "pPixmap + 1", "PRIVATE_PIXMAP"));
    return pPixmap;
}

/* callable by ddx */
void FreePixmap(PixmapPtr pPixmap)
{
    mixin(dixFiniPrivates!("pPixmap", "PRIVATE_PIXMAP"));
    free(pPixmap);
}

void PixmapUnshareSecondaryPixmap(PixmapPtr secondary_pixmap)
{
     int ihandle = -1;
     ScreenPtr pScreen = secondary_pixmap.drawable.pScreen;
     pScreen.SetSharedPixmapBacking(secondary_pixmap, (cast(void*)cast(c_long)ihandle));
}

PixmapPtr PixmapShareToSecondary(PixmapPtr pixmap, ScreenPtr secondary)
{
    PixmapPtr spix = void;
    int ret = void;
    void* handle = void;
    ScreenPtr primary = pixmap.drawable.pScreen;
    int depth = pixmap.drawable.depth;

    ret = primary.SharePixmapBacking(pixmap, secondary, &handle);
    if (ret == FALSE)
        return null;

    spix = secondary.CreatePixmap(secondary, 0, 0, depth,
                               CREATE_PIXMAP_USAGE_SHARED);
    secondary.ModifyPixmapHeader(spix, pixmap.drawable.width,
                                  pixmap.drawable.height, depth, 0,
                                  pixmap.devKind, null);

    /* have the secondary pixmap take a reference on the primary pixmap
       later we destroy them both at the same time */
    pixmap.refcnt++;

    spix.primary_pixmap = pixmap;

    ret = secondary.SetSharedPixmapBacking(spix, handle);
    if (ret == FALSE) {
        dixDestroyPixmap(spix, 0);
        return null;
    }

    return spix;
}

private void PixmapDirtyDamageDestroy(DamagePtr damage, void* closure)
{
    PixmapDirtyUpdatePtr dirty = cast(PixmapDirtyUpdatePtr )closure;

    dirty.damage = null;
}

Bool PixmapStartDirtyTracking(DrawablePtr src, PixmapPtr secondary_dst, int x, int y, int dst_x, int dst_y, Rotation rotation)
{
    ScreenPtr screen = src.pScreen;
    PixmapDirtyUpdatePtr dirty_update = void;
    RegionPtr damageregion = void;
    RegionRec dstregion = void;
    BoxRec box = void;

    dirty_update = cast(PixmapDirtyUpdateRec*) calloc(1, PixmapDirtyUpdateRec.sizeof);
    if (!dirty_update)
        return FALSE;

    dirty_update.src = src;
    dirty_update.secondary_dst = secondary_dst;
    dirty_update.x = x;
    dirty_update.y = y;
    dirty_update.dst_x = dst_x;
    dirty_update.dst_y = dst_y;
    dirty_update.rotation = rotation;
    dirty_update.damage = DamageCreate(null, &PixmapDirtyDamageDestroy,
                                        DamageReportNone, TRUE, screen,
                                        dirty_update);

    if (rotation != RR_Rotate_0) {
        RRTransformCompute(x, y,
                           secondary_dst.drawable.width,
                           secondary_dst.drawable.height,
                           rotation,
                           null,
                           &dirty_update.transform,
                           &dirty_update.f_transform,
                           &dirty_update.f_inverse);
    }
    if (!dirty_update.damage) {
        free(dirty_update);
        return FALSE;
    }

    /* Damage destination rectangle so that the destination pixmap contents
     * will get fully initialized
     */
    box.x1 = cast(short)dirty_update.x;
    box.y1 = cast(short)dirty_update.y;
    if (dirty_update.rotation == RR_Rotate_90 ||
        dirty_update.rotation == RR_Rotate_270) {
        box.x2 = cast(short)(dirty_update.x + secondary_dst.drawable.height);
        box.y2 = cast(short)(dirty_update.y + secondary_dst.drawable.width);
    } else {
        box.x2 = cast(short)(dirty_update.x + secondary_dst.drawable.width);
        box.y2 = cast(short)(dirty_update.y + secondary_dst.drawable.height);
    }
    RegionInit(&dstregion, &box, 1);
    damageregion = DamageRegion(dirty_update.damage);
    RegionUnion(damageregion, damageregion, &dstregion);
    RegionUninit(&dstregion);

    DamageRegister(src, dirty_update.damage);
    xorg_list_add(&dirty_update.ent, &screen.pixmap_dirty_list);
    return TRUE;
}

Bool PixmapStopDirtyTracking(DrawablePtr src, PixmapPtr secondary_dst)
{
    ScreenPtr screen = src.pScreen;
    PixmapDirtyUpdatePtr ent = void, safe = void;

    mixin(xorg_list_for_each_entry_safe!("ent", "safe", "&screen.pixmap_dirty_list", "ent", q{
        if (ent.src == src && ent.secondary_dst == secondary_dst) {
            if (ent.damage)
                DamageDestroy(ent.damage);
            xorg_list_del(&ent.ent);
            free(ent);
        }
    }));
    return TRUE;
}

void PixmapDirtyCopyArea(PixmapPtr dst, DrawablePtr src, int x, int y, int dst_x, int dst_y, RegionPtr dirty_region)
{
    ScreenPtr pScreen = src.pScreen;
    int n = void;
    BoxPtr b = void;
    GCPtr pGC = void;

    n = RegionNumRects(dirty_region);
    b = RegionRects(dirty_region);

    pGC = GetScratchGC(src.depth, pScreen);
    if (pScreen.root) {
        ChangeGCVal subWindowMode = void;

        subWindowMode.val = IncludeInferiors;
        ChangeGC(null, pGC, cast(uint)GCSubwindowMode, &subWindowMode);
    }
    ValidateGC(&dst.drawable, pGC);

    while (n--) {
        BoxRec dst_box = void;
        int w = void, h = void;

        dst_box = *b;
        w = dst_box.x2 - dst_box.x1;
        h = dst_box.y2 - dst_box.y1;

        cast(void) pGC.ops.CopyArea(src,
                                  &dst.drawable,
                                  pGC,
                                  x + dst_box.x1,
                                  y + dst_box.y1,
                                  w,
                                  h,
                                  dst_x + dst_box.x1,
                                  dst_y + dst_box.y1);
        b++;
    }
    FreeScratchGC(pGC);
}

private void PixmapDirtyCompositeRotate(PixmapPtr dst_pixmap, PixmapDirtyUpdatePtr dirty, RegionPtr dirty_region)
{
    ScreenPtr pScreen = dirty.src.pScreen;
    PictFormatPtr format = PictureWindowFormat(pScreen.root);
    PicturePtr src = void, dst = void;
    XID include_inferiors = IncludeInferiors;
    int n = RegionNumRects(dirty_region);
    BoxPtr b = RegionRects(dirty_region);
    int error = void;

    src = CreatePicture(None,
                        dirty.src,
                        format,
                        CPSubwindowMode,
                        &include_inferiors, serverClient, &error);
    if (!src)
        return;

    dst = CreatePicture(None,
                        &dst_pixmap.drawable,
                        format, 0L, null, serverClient, &error);
    if (!dst)
        return;

    error = SetPictureTransform(src, &dirty.transform);
    if (error)
        return;
    while (n--) {
        BoxRec dst_box = void;

        dst_box = *b;
        dst_box.x1 += dirty.x;
        dst_box.x2 += dirty.x;
        dst_box.y1 += dirty.y;
        dst_box.y2 += dirty.y;
        assumeNoGC(&pixman_f_transform_bounds)(&dirty.f_inverse, &dst_box);

        CompositePicture(PictOpSrc,
                         src, null, dst,
                         dst_box.x1,
                         dst_box.y1,
                         0, 0,
                         dst_box.x1,
                         dst_box.y1,
                         cast(short)(dst_box.x2 - dst_box.x1),
                         cast(short)(dst_box.y2 - dst_box.y1));
        b++;
    }

    FreePicture(src, None);
    FreePicture(dst, None);
}

/*
 * this function can possibly be improved and optimised, by clipping
 * instead of iterating
 * Drivers are free to implement their own version of this.
 */
Bool PixmapSyncDirtyHelper(PixmapDirtyUpdatePtr dirty)
{
    ScreenPtr pScreen = dirty.src.pScreen;
    RegionPtr region = DamageRegion(dirty.damage);
    PixmapPtr dst = void;
    SourceValidateProcPtr SourceValidate = void;
    RegionRec pixregion = void;
    BoxRec box = void;

    dst = dirty.secondary_dst.primary_pixmap;
    if (!dst)
        dst = dirty.secondary_dst;

    box.x1 = 0;
    box.y1 = 0;
    if (dirty.rotation == RR_Rotate_90 ||
        dirty.rotation == RR_Rotate_270) {
        box.x2 = dst.drawable.height;
        box.y2 = dst.drawable.width;
    } else {
        box.x2 = dst.drawable.width;
        box.y2 = dst.drawable.height;
    }
    RegionInit(&pixregion, &box, 1);

    /*
     * SourceValidate is used by the software cursor code
     * to pull the cursor off of the screen when reading
     * bits from the frame buffer. Bypassing this function
     * leaves the software cursor in place
     */
    SourceValidate = pScreen.SourceValidate;
    pScreen.SourceValidate = &miSourceValidate;

    RegionTranslate(&pixregion, dirty.x, dirty.y);
    RegionIntersect(&pixregion, &pixregion, region);

    if (RegionNil(&pixregion)) {
        RegionUninit(&pixregion);
        return FALSE;
    }

    RegionTranslate(&pixregion, -dirty.x, -dirty.y);

    if (!pScreen.root || dirty.rotation == RR_Rotate_0)
        PixmapDirtyCopyArea(dst, dirty.src, dirty.x, dirty.y,
                            dirty.dst_x, dirty.dst_y, &pixregion);
    else
        PixmapDirtyCompositeRotate(dst, dirty, &pixregion);
    pScreen.SourceValidate = SourceValidate;
    return TRUE;
}
