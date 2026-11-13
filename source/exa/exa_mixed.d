module exa_mixed;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2009 Maarten Maathuis
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

import build.dix_config;

import core.stdc.string;

import exa.exa_priv;
import exa.exa;
import exa.exa_migration_mixed;
import fb.fb;

/* This file holds the driver allocated pixmaps + better initial placement code.
 */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void* ExaGetPixmapAddress(PixmapPtr p)
{
    mixin(ExaPixmapPriv!("p"));

    return pExaPixmap.sys_ptr;
}

/**
 * exaCreatePixmap() creates a new pixmap.
 */
PixmapPtr exaCreatePixmap_mixed(ScreenPtr pScreen, int w, int h, int depth, uint usage_hint)
{
    PixmapPtr pPixmap = void;
    ExaPixmapPrivPtr pExaPixmap = void;
    int bpp = void;
    size_t paddedWidth = void;

    mixin(ExaScreenPriv!("pScreen"));

    if (w > 32767 || h > 32767)
        return NullPixmap;

    mixin(swap!("pExaScr", "pScreen", "CreatePixmap"));
    pPixmap = pScreen.CreatePixmap(pScreen, 0, 0, depth, usage_hint);
    mixin(swap!("pExaScr", "pScreen", "CreatePixmap"));

    if (!pPixmap)
        return null;

    pExaPixmap = mixin(ExaGetPixmapPriv!("pPixmap"));
    pExaPixmap.driverPriv = null;

    bpp = pPixmap.drawable.bitsPerPixel;

    paddedWidth = ((w * bpp + FB_MASK) >> FB_SHIFT) * FbBits.sizeof;
    if (paddedWidth / 4 > 32767)
        return NullPixmap;

    /* We will allocate the system pixmap later if needed. */
    pPixmap.devPrivate.ptr = null;
    pExaPixmap.sys_ptr = null;
    pExaPixmap.sys_pitch = cast(int)paddedWidth;

    pExaPixmap.area = null;
    pExaPixmap.fb_ptr = null;
    pExaPixmap.pDamage = null;

    exaSetFbPitch(pExaScr, pExaPixmap, w, h, bpp);
    exaSetAccelBlock(pExaScr, pExaPixmap, w, h, bpp);

    (*pScreen.ModifyPixmapHeader) (pPixmap, w, h, 0, 0, cast(int)paddedWidth, null);

    /* A scratch pixmap will become a driver pixmap right away. */
    if (!w || !h) {
        exaCreateDriverPixmap_mixed(pPixmap);
        pExaPixmap.use_gpu_copy = exaPixmapHasGpuCopy(pPixmap);
    }
    else {
        pExaPixmap.use_gpu_copy = False;

        if (w == 1 && h == 1) {
            pExaPixmap.sys_ptr = cast(ubyte*)calloc(1, paddedWidth);

            /* Set up damage tracking */
            pExaPixmap.pDamage = DamageCreate(&exaDamageReport_mixed, null,
                                               DamageReportNonEmpty, True,
                                               pPixmap.drawable.pScreen,
                                               pPixmap);

            if (pExaPixmap.pDamage) {
                DamageRegister(&pPixmap.drawable, pExaPixmap.pDamage);
                /* This ensures that pending damage reflects the current
                 * operation. This is used by exa to optimize migration.
                 */
                DamageSetReportAfterOp(pExaPixmap.pDamage, True);
            }
        }
    }

    /* During a fallback we must prepare access. */
    if (pExaScr.fallback_counter)
        exaPrepareAccess(&pPixmap.drawable, EXA_PREPARE_AUX_DEST);

    return pPixmap;
}

Bool exaModifyPixmapHeader_mixed(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData)
{
    ScreenPtr pScreen = void;
    ExaScreenPrivPtr pExaScr = void;
    ExaPixmapPrivPtr pExaPixmap = void;
    Bool ret = void, has_gpu_copy = void;

    if (!pPixmap)
        return False;

    pScreen = pPixmap.drawable.pScreen;
    pExaScr = mixin(ExaGetScreenPriv!("pScreen"));
    pExaPixmap = mixin(ExaGetPixmapPriv!("pPixmap"));

    if (pPixData) {
        if (pExaPixmap.driverPriv) {
            if (pExaPixmap.pDamage) {
                DamageDestroy(pExaPixmap.pDamage);
                pExaPixmap.pDamage = null;
            }

            pExaScr.info.DestroyPixmap(pScreen, pExaPixmap.driverPriv);
            pExaPixmap.driverPriv = null;
        }

        pExaPixmap.use_gpu_copy = False;
        pExaPixmap.score = EXA_PIXMAP_SCORE_PINNED;
    }

    has_gpu_copy = exaPixmapHasGpuCopy(pPixmap);

    if (width <= 0)
        width = pPixmap.drawable.width;

    if (height <= 0)
        height = pPixmap.drawable.height;

    if (bitsPerPixel <= 0) {
        if (depth <= 0)
            bitsPerPixel = pPixmap.drawable.bitsPerPixel;
        else
            bitsPerPixel = mixin(BitsPerPixel!("depth"));
    }

    if (depth <= 0)
        depth = pPixmap.drawable.depth;

    if (width != pPixmap.drawable.width ||
        height != pPixmap.drawable.height ||
        depth != pPixmap.drawable.depth ||
        bitsPerPixel != pPixmap.drawable.bitsPerPixel) {
        if (pExaPixmap.driverPriv) {
            if (devKind > 0)
                pExaPixmap.fb_pitch = devKind;
            else
                exaSetFbPitch(pExaScr, pExaPixmap, width, height, bitsPerPixel);

            exaSetAccelBlock(pExaScr, pExaPixmap, width, height, bitsPerPixel);
            RegionEmpty(&pExaPixmap.validFB);
        }

        /* Need to re-create system copy if there's also a GPU copy */
        if (has_gpu_copy) {
            if (pExaPixmap.sys_ptr) {
                free(pExaPixmap.sys_ptr);
                pExaPixmap.sys_ptr = null;
                DamageDestroy(pExaPixmap.pDamage);
                pExaPixmap.pDamage = null;
                RegionEmpty(&pExaPixmap.validSys);

                if (pExaScr.deferred_mixed_pixmap == pPixmap)
                    pExaScr.deferred_mixed_pixmap = null;
            }

            pExaPixmap.sys_pitch = PixmapBytePad(width, depth);
        }
    }

    if (has_gpu_copy) {
        pPixmap.devPrivate.ptr = pExaPixmap.fb_ptr;
        pPixmap.devKind = pExaPixmap.fb_pitch;
    }
    else {
        pPixmap.devPrivate.ptr = pExaPixmap.sys_ptr;
        pPixmap.devKind = pExaPixmap.sys_pitch;
    }

    /* Only pass driver pixmaps to the driver. */
    if (pExaScr.info.ModifyPixmapHeader && pExaPixmap.driverPriv) {
        ret = pExaScr.info.ModifyPixmapHeader(pPixmap, width, height, depth,
                                                bitsPerPixel, devKind,
                                                pPixData);
        if (ret == True)
            goto out_;
    }

    mixin(swap!("pExaScr", "pScreen", "ModifyPixmapHeader"));
    ret = pScreen.ModifyPixmapHeader(pPixmap, width, height, depth,
                                      bitsPerPixel, devKind, pPixData);
    mixin(swap!("pExaScr", "pScreen", "ModifyPixmapHeader"));

 out_:
    if (has_gpu_copy) {
        pExaPixmap.fb_ptr = cast(ubyte*) pPixmap.devPrivate.ptr;
        pExaPixmap.fb_pitch = pPixmap.devKind;
    }
    else {
        pExaPixmap.sys_ptr = cast(ubyte*)pPixmap.devPrivate.ptr;
        pExaPixmap.sys_pitch = pPixmap.devKind;
    }
    /* Always NULL this, we don't want lingering pointers. */
    pPixmap.devPrivate.ptr = null;

    return ret;
}

void exaPixmapDestroy_mixed(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pPixmap)
{
    mixin(ExaScreenPriv!("pScreen"));

    mixin(ExaPixmapPriv!("pPixmap"));
    if (!pExaPixmap) // we're called on an error path
        return;

    exaDestroyPixmap(pPixmap);

    if (pExaScr.deferred_mixed_pixmap == pPixmap)
        pExaScr.deferred_mixed_pixmap = null;

    if (pExaPixmap.driverPriv)
        pExaScr.info.DestroyPixmap(pScreen, pExaPixmap.driverPriv);
    pExaPixmap.driverPriv = null;

    if (pExaPixmap.pDamage) {
        free(pExaPixmap.sys_ptr);
        pExaPixmap.sys_ptr = null;
        pExaPixmap.pDamage = null;
    }
}

Bool exaPixmapHasGpuCopy_mixed(PixmapPtr pPixmap)
{
    ScreenPtr pScreen = pPixmap.drawable.pScreen;

    mixin(ExaScreenPriv!("pScreen"));
    mixin(ExaPixmapPriv!("pPixmap"));
    void* saved_ptr = void;
    Bool ret = void;

    if (!pExaPixmap.driverPriv)
        return False;

    saved_ptr = pPixmap.devPrivate.ptr;
    pPixmap.devPrivate.ptr = ExaGetPixmapAddress(pPixmap);
    ret = pExaScr.info.PixmapIsOffscreen(pPixmap);
    pPixmap.devPrivate.ptr = saved_ptr;

    return ret;
}

Bool exaSharePixmapBacking_mixed(PixmapPtr pPixmap, ScreenPtr secondary, void** handle_p)
{
    ScreenPtr pScreen = pPixmap.drawable.pScreen;
    mixin(ExaScreenPriv!("pScreen"));
    Bool ret = False;

    exaMoveInPixmap(pPixmap);
    /* get the driver to give us a handle */
    if (pExaScr.info.SharePixmapBacking)
        ret = pExaScr.info.SharePixmapBacking(pPixmap, secondary, handle_p);

    return ret;
}

Bool exaSetSharedPixmapBacking_mixed(PixmapPtr pPixmap, void* handle)
{
    ScreenPtr pScreen = pPixmap.drawable.pScreen;
    mixin(ExaScreenPriv!("pScreen"));
    Bool ret = False;

    if (pExaScr.info.SetSharedPixmapBacking)
        ret = pExaScr.info.SetSharedPixmapBacking(pPixmap, handle);

    if (ret == True)
        exaMoveInPixmap(pPixmap);

    return ret;
}
