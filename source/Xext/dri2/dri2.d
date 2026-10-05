module Xext.dri2.dri2;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2007, 2008 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Soft-
 * ware"), to deal in the Software without restriction, including without
 * limitation the rights to use, copy, modify, merge, publish, distribute,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, provided that the above copyright
 * notice(s) and this permission notice appear in all copies of the Soft-
 * ware and that both the above copyright notice(s) and this permission
 * notice appear in supporting documentation.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABIL-
 * ITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF THIRD PARTY
 * RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN
 * THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSE-
 * QUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFOR-
 * MANCE OF THIS SOFTWARE.
 *
 * Except as contained in this notice, the name of a copyright holder shall
 * not be used in advertising or otherwise to promote the sale, use or
 * other dealings in this Software without prior written authorization of
 * the copyright holder.
 *
 * Authors:
 *   Kristian Høgsberg (krh@redhat.com)
 */

import build.dix_config;

import core.stdc.errno;

import dix.dix_priv;
import os.client_priv;

static if (WITH_LIBDRM) {
import externs.libdrm;;
}
import include.list;
import include.scrnintstr;
import include.windowstr;
import include.dixstruct;
import Xext.dri2.dri2_priv;
import Xext.dri2.dri2int;
import include.damage;
import include.dri2;
import externs.X11.extensions.dri2tokens;
import include.list;
import dix.pixmap;
import os.log;
import std.string;
import os.io;

// CARD8 dri2_major;               /* version of DRI2 supported by DDX */
// CARD8 dri2_minor;

uint prime_id_allocate_bitmask;

private DevPrivateKeyRec dri2ScreenPrivateKeyRec;
private DevPrivateKeyRec dri2WindowPrivateKeyRec;
private DevPrivateKeyRec dri2PixmapPrivateKeyRec;
private DevPrivateKeyRec dri2ClientPrivateKeyRec;

struct _DRI2Client {
    int prime_id;
}alias DRI2ClientRec = _DRI2Client;
alias DRI2ClientPtr = _DRI2Client*;

pragma(inline, true) private DRI2ClientPtr dri2ClientPrivate(ClientPtr pClient) {
    return cast(DRI2ClientPtr) dixLookupPrivate(
        &pClient.devPrivates,
        &dri2ClientPrivateKeyRec);
}

private RESTYPE dri2DrawableRes;

alias DRI2ScreenPtr = _DRI2Screen*;
alias DRI2ScreenRec = _DRI2Screen;

struct _DRI2Drawable {
    DRI2ScreenPtr dri2_screen;
    DrawablePtr drawable;
    xorg_list reference_list;
    int width;
    int height;
    DRI2BufferPtr* buffers;
    int bufferCount;
    uint swapsPending;
    int swap_interval;
    CARD64 swap_count;
    long target_sbc;         /* -1 means no SBC wait outstanding */
    CARD64 last_swap_target;    /* most recently queued swap target */
    CARD64 last_swap_msc;       /* msc at completion of most recent swap */
    CARD64 last_swap_ust;       /* ust at completion of most recent swap */
    int swap_limit;             /* for N-buffering */
    uint[3] blocked;
    Bool needInvalidate;
    int prime_id;
    PixmapPtr prime_secondary_pixmap;
    PixmapPtr redirectpixmap;
}alias DRI2DrawableRec = _DRI2Drawable;
alias DRI2DrawablePtr = _DRI2Drawable*;

struct _DRI2Screen {
    ScreenPtr pScreen;
    int refcnt;
    uint numDrivers;
    const(char)** driverNames;
    const(char)* deviceName;
    int fd;
    uint lastSequence;
    int prime_id;

    DRI2CreateBufferProcPtr CreateBuffer;
    DRI2DestroyBufferProcPtr DestroyBuffer;
    DRI2CopyRegionProcPtr CopyRegion;
    DRI2ScheduleSwapProcPtr ScheduleSwap;
    DRI2GetMSCProcPtr GetMSC;
    DRI2ScheduleWaitMSCProcPtr ScheduleWaitMSC;
    DRI2AuthMagic2ProcPtr AuthMagic;
    DRI2AuthMagicProcPtr LegacyAuthMagic;
    DRI2ReuseBufferNotifyProcPtr ReuseBufferNotify;
    DRI2SwapLimitValidateProcPtr SwapLimitValidate;
    DRI2GetParamProcPtr GetParam;

    HandleExposuresProcPtr HandleExposures;

    ConfigNotifyProcPtr ConfigNotify;
    SetWindowPixmapProcPtr SetWindowPixmap;
    DRI2CreateBuffer2ProcPtr CreateBuffer2;
    DRI2DestroyBuffer2ProcPtr DestroyBuffer2;
    DRI2CopyRegion2ProcPtr CopyRegion2;
}



enum DRI2WakeType {
    WAKE_SBC,
    WAKE_MSC,
    WAKE_SWAP,
}
alias WAKE_SBC = DRI2WakeType.WAKE_SBC;
alias WAKE_MSC = DRI2WakeType.WAKE_MSC;
alias WAKE_SWAP = DRI2WakeType.WAKE_SWAP;


enum string Wake(string c, string t) = `cast(void*)(cast(uintptr_t)(` ~ c ~ `) | (` ~ t ~ `))`;

private Bool dri2WakeClient(ClientPtr client, void* closure)
{
    ClientWakeup(client);
    return TRUE;
}

private Bool dri2WakeAll(ClientPtr client, DRI2DrawablePtr pPriv, DRI2WakeType t)
{
    if (!pPriv.blocked[t])
        return FALSE;

    int count = ClientSignalAll(client, &dri2WakeClient, mixin(Wake!(`pPriv`, `t`)));
    pPriv.blocked[t] -= count;
    return count;
}

private Bool dri2Sleep(ClientPtr client, DRI2DrawablePtr pPriv, DRI2WakeType t)
{
    if (ClientSleep(client, &dri2WakeClient, mixin(Wake!(`pPriv`, `t`)))) {
        pPriv.blocked[t]++;
        return TRUE;
    }
    return FALSE;
}

private DRI2ScreenPtr DRI2GetScreen(ScreenPtr pScreen)
{
    return cast(DRI2ScreenPtr)dixLookupPrivate(&pScreen.devPrivates, &dri2ScreenPrivateKeyRec);
}

private ScreenPtr GetScreenPrime(ScreenPtr primary, int prime_id)
{
    if (prime_id == 0)
        return primary;

    ScreenPtr secondary = void;
    // pragma(msg, xorg_list_for_each_entry!(
    // "secondary",
    // "&primary.secondary_list",
    // "secondary_head"));
   mixin(xorg_list_for_each_entry!("secondary", "&primary.secondary_list", "secondary_head", q{
        if (!secondary.is_offload_secondary)
            continue;

        DRI2ScreenPtr ds = DRI2GetScreen(secondary);
        if (ds is null)
            continue;

        if (ds.prime_id == prime_id)
            return secondary;
    }));
    return primary;
}

pragma(inline, true) private DRI2ScreenPtr DRI2GetScreenPrime(ScreenPtr primary, int prime_id)
{
    return DRI2GetScreen(GetScreenPrime(primary, prime_id));
}

private DRI2DrawablePtr DRI2GetDrawable(DrawablePtr pDraw)
{
    switch (pDraw.type) {
    case DRAWABLE_WINDOW:
    {
        WindowPtr pWin = cast(WindowPtr) pDraw;
        return cast(DRI2DrawablePtr)dixLookupPrivate(&pWin.devPrivates, &dri2WindowPrivateKeyRec);
    }
    case DRAWABLE_PIXMAP:
    {
        PixmapPtr pPixmap = cast(PixmapPtr) pDraw;
        return cast(DRI2DrawablePtr)dixLookupPrivate(&pPixmap.devPrivates, &dri2PixmapPrivateKeyRec);
    }
    default:
        return null;
    }
}

private DRI2DrawablePtr DRI2AllocateDrawable(DrawablePtr pDraw)
{
    DRI2DrawablePtr pPriv;
    pPriv = cast(DRI2DrawablePtr)calloc(1, (*pPriv).sizeof);
    if (pPriv is null)
        return null;

    DRI2ScreenPtr ds = DRI2GetScreen(pDraw.pScreen);

    pPriv.dri2_screen = ds;
    pPriv.drawable = pDraw;
    pPriv.width = pDraw.width;
    pPriv.height = pDraw.height;
    pPriv.buffers = null;
    pPriv.bufferCount = 0;
    pPriv.swapsPending = 0;
    pPriv.swap_count = 0;
    pPriv.target_sbc = -1;
    pPriv.swap_interval = 1;

    /* Initialize last swap target from DDX if possible */
    CARD64 ust = void;
    if (!ds.GetMSC || !(*ds.GetMSC) (pDraw, &ust, &pPriv.last_swap_target))
        pPriv.last_swap_target = 0;

    memset(pPriv.blocked.ptr, 0, typeof(pPriv.blocked).sizeof);
    pPriv.swap_limit = 1;      /* default to double buffering */
    pPriv.last_swap_msc = 0;
    pPriv.last_swap_ust = 0;
    xorg_list_init(&pPriv.reference_list);
    pPriv.needInvalidate = FALSE;
    pPriv.redirectpixmap = null;
    pPriv.prime_secondary_pixmap = null;
    if (pDraw.type == DRAWABLE_WINDOW) {
        WindowPtr pWin = cast(WindowPtr) pDraw;
        dixSetPrivate(&pWin.devPrivates, &dri2WindowPrivateKeyRec, pPriv);
    }
    else {
        PixmapPtr pPixmap = cast(PixmapPtr) pDraw;
        dixSetPrivate(&pPixmap.devPrivates, &dri2PixmapPrivateKeyRec, pPriv);
    }

    return pPriv;
}

Bool DRI2SwapLimit(DrawablePtr pDraw, int swap_limit)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);

    if (!pPriv)
        return FALSE;

    DRI2ScreenPtr ds = pPriv.dri2_screen;

    if (!ds.SwapLimitValidate || !ds.SwapLimitValidate(pDraw, swap_limit))
        return FALSE;

    pPriv.swap_limit = swap_limit;

    /* Check throttling */
    if (pPriv.swapsPending >= pPriv.swap_limit)
        return TRUE;

    dri2WakeAll(cast(ClientPtr)CLIENT_SIGNAL_ANY, pPriv, WAKE_SWAP);
    return TRUE;
}

struct DRI2DrawableRefRec {
    XID id;
    XID dri2_id;
    DRI2InvalidateProcPtr invalidate;
    void* priv;
    xorg_list link;
}alias DRI2DrawableRefPtr = DRI2DrawableRefRec*;

private DRI2DrawableRefPtr DRI2LookupDrawableRef(DRI2DrawablePtr pPriv, XID id)
{
    DRI2DrawableRefPtr ref_ = void;

    mixin(xorg_list_for_each_entry!("ref_", "&pPriv.reference_list", "link", q{
        if (ref_.id == id)
            return ref_;
    }));

    return null;
}

private int DRI2AddDrawableRef(DRI2DrawablePtr pPriv, XID id, XID dri2_id, DRI2InvalidateProcPtr invalidate, void* priv)
{
    DRI2DrawableRefPtr ref_;
    ref_ = cast(DRI2DrawableRefPtr)calloc(1, (*ref_).sizeof);
    if (ref_ is null)
        return BadAlloc;

    if (!AddResource(cast(uint)dri2_id, dri2DrawableRes, pPriv)) {
        free(ref_);
        return BadAlloc;
    }
    if (!DRI2LookupDrawableRef(pPriv, id))
        if (!AddResource(cast(uint)id, dri2DrawableRes, pPriv)) {
            FreeResourceByType(dri2_id, dri2DrawableRes, TRUE);
            free(ref_);
            return BadAlloc;
        }

    ref_.id = id;
    ref_.dri2_id = dri2_id;
    ref_.invalidate = invalidate;
    ref_.priv = priv;
    xorg_list_add(&ref_.link, &pPriv.reference_list);

    return Success;
}

int DRI2CreateDrawable2(ClientPtr client, DrawablePtr pDraw, XID id, DRI2InvalidateProcPtr invalidate, void* priv, XID* dri2_id_out)
{
    if (!dixPrivateKeyRegistered(&dri2ScreenPrivateKeyRec))
        return BadValue;

    DRI2ClientPtr dri2_client = dri2ClientPrivate(client);

    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null)
        pPriv = DRI2AllocateDrawable(pDraw);
    if (pPriv is null)
        return BadAlloc;

    pPriv.prime_id = dri2_client.prime_id;

    XID dri2_id = FakeClientID(client.index);
    int rc = DRI2AddDrawableRef(pPriv, id, dri2_id, invalidate, priv);
    if (rc != Success)
        return rc;

    if (dri2_id_out)
        *dri2_id_out = dri2_id;

    return Success;
}

int DRI2CreateDrawable(ClientPtr client, DrawablePtr pDraw, XID id, DRI2InvalidateProcPtr invalidate, void* priv)
{
    return DRI2CreateDrawable2(client, pDraw, id, invalidate, priv, null);
}

private int DRI2DrawableGone(void* p, XID id)
{
    DRI2DrawablePtr pPriv = cast(DRI2DrawablePtr)p;

    DRI2DrawableRefPtr ref_ = void, next = void;
    mixin(xorg_list_for_each_entry_safe!("ref_", "next", "&(pPriv.reference_list)", "link", q{
        if (ref_.dri2_id == id) {
            xorg_list_del(&ref_.link);
            /* If this was the last ref under this X drawable XID,
             * unregister the X drawable resource. */
            if (!DRI2LookupDrawableRef(pPriv, ref_.id))
                FreeResourceByType(ref_.id, dri2DrawableRes, TRUE);
            free(ref_);
            break;
        }

        if (ref_.id == id) {
            xorg_list_del(&ref_.link);
            FreeResourceByType(ref_.dri2_id, dri2DrawableRes, TRUE);
            free(ref_);
        }
    }));

    if (!xorg_list_is_empty(&pPriv.reference_list))
        return Success;

    DrawablePtr pDraw = pPriv.drawable;
    if (pDraw.type == DRAWABLE_WINDOW) {
        WindowPtr pWin = cast(WindowPtr) pDraw;
        dixSetPrivate(&pWin.devPrivates, &dri2WindowPrivateKeyRec, null);
    }
    else {
        PixmapPtr pPixmap = cast(PixmapPtr) pDraw;
        dixSetPrivate(&pPixmap.devPrivates, &dri2PixmapPrivateKeyRec, null);
    }

    if (pPriv.prime_secondary_pixmap) {
        dixDestroyPixmap(pPriv.prime_secondary_pixmap.primary_pixmap, 0);
        dixDestroyPixmap(pPriv.prime_secondary_pixmap, 0);
    }

    if (pPriv.buffers !is null) {
        for (int i = 0; i < pPriv.bufferCount; i++)
            destroy_buffer(pDraw, pPriv.buffers[i], pPriv.prime_id);
        free(pPriv.buffers);
    }

    if (pPriv.redirectpixmap) {
        (*pDraw.pScreen.ReplaceScanoutPixmap)(pDraw, pPriv.redirectpixmap, FALSE);
        dixDestroyPixmap(pPriv.redirectpixmap, 0);
    }

    dri2WakeAll(cast(ClientPtr)CLIENT_SIGNAL_ANY, pPriv, WAKE_SWAP);
    dri2WakeAll(cast(ClientPtr)CLIENT_SIGNAL_ANY, pPriv, WAKE_MSC);
    dri2WakeAll(cast(ClientPtr)CLIENT_SIGNAL_ANY, pPriv, WAKE_SBC);

    free(pPriv);

    return Success;
}

private DRI2BufferPtr create_buffer(DRI2ScreenPtr ds, DrawablePtr pDraw, uint attachment, uint format)
{
    if (ds.CreateBuffer2)
        return ds.CreateBuffer2(GetScreenPrime(pDraw.pScreen,
                                                 DRI2GetDrawable(pDraw).prime_id),
                                 pDraw, attachment, format);
    else
        return ds.CreateBuffer(pDraw, attachment, format);
}

private void destroy_buffer(DrawablePtr pDraw, DRI2BufferPtr buffer, int prime_id)
{
    ScreenPtr primeScreen = GetScreenPrime(pDraw.pScreen, prime_id);
    DRI2ScreenPtr ds = DRI2GetScreen(primeScreen);
    if (ds.DestroyBuffer2)
        (*ds.DestroyBuffer2)(primeScreen, pDraw, buffer);
    else
        (*ds.DestroyBuffer)(pDraw, buffer);
}

private int find_attachment(DRI2DrawablePtr pPriv, uint attachment)
{
    if (pPriv.buffers is null) {
        return -1;
    }

    for (int i = 0; i < pPriv.bufferCount; i++) {
        if ((pPriv.buffers[i] !is null)
            && (pPriv.buffers[i].attachment == attachment)) {
            return i;
        }
    }

    return -1;
}

private Bool allocate_or_reuse_buffer(DrawablePtr pDraw, DRI2ScreenPtr ds, DRI2DrawablePtr pPriv, uint attachment, uint format, int dimensions_match, DRI2BufferPtr* buffer)
{
    int old_buf = find_attachment(pPriv, attachment);

    if ((old_buf < 0)
        || attachment == DRI2BufferFrontLeft
        || !dimensions_match || (pPriv.buffers[old_buf].format != format)) {
        *buffer = create_buffer(ds, pDraw, attachment, format);
        return TRUE;

    }
    else {
        *buffer = pPriv.buffers[old_buf];

        if (ds.ReuseBufferNotify)
            (*ds.ReuseBufferNotify) (pDraw, *buffer);

        pPriv.buffers[old_buf] = null;
        return FALSE;
    }
}

private void update_dri2_drawable_buffers(DRI2DrawablePtr pPriv, DrawablePtr pDraw, DRI2BufferPtr* buffers, int out_count, int* width, int* height)
{
    if (pPriv.buffers !is null) {
        for (int i = 0; i < pPriv.bufferCount; i++) {
            if (pPriv.buffers[i] !is null) {
                destroy_buffer(pDraw, pPriv.buffers[i], pPriv.prime_id);
            }
        }
        free(pPriv.buffers);
    }

    pPriv.buffers = buffers;
    pPriv.bufferCount = out_count;
    pPriv.width = pDraw.width;
    pPriv.height = pDraw.height;
    *width = pPriv.width;
    *height = pPriv.height;
}

private DRI2BufferPtr* do_get_buffers(DrawablePtr pDraw, int* width, int* height, uint* attachments, int count, int* out_count, int has_format)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);

    if (!pPriv) {
        *width = pDraw.width;
        *height = pDraw.height;
        *out_count = 0;
        return null;
    }

    DRI2ScreenPtr ds = DRI2GetScreenPrime(pDraw.pScreen, pPriv.prime_id);

    int dimensions_match = (pDraw.width == pPriv.width)
        && (pDraw.height == pPriv.height);

    DRI2BufferPtr* buffers;
    buffers = cast(DRI2BufferPtr*) calloc((count + 1), typeof(buffers[0]).sizeof);
    int i = void;
    int buffers_changed = 0;
    int need_real_front = 0;
    int need_fake_front = 0;
    int have_fake_front = 0;
    int front_format = 0;
    if (!buffers)
        goto err_out;

    for (i = 0; i < count; i++) {
        const(uint) attachment = *(attachments++);
        const(uint) format = (has_format) ? *(attachments++) : 0;

        if (allocate_or_reuse_buffer(pDraw, ds, pPriv, attachment,
                                     format, dimensions_match, &buffers[i]))
            buffers_changed = 1;

        if (buffers[i] is null)
            goto err_out;

        /* If the drawable is a window and the front-buffer is requested,
         * silently add the fake front-buffer to the list of requested
         * attachments.  The counting logic in the loop accounts for the case
         * where the client requests both the fake and real front-buffer.
         */
        if (attachment == DRI2BufferBackLeft) {
            need_real_front++;
            front_format = format;
        }

        if (attachment == DRI2BufferFrontLeft) {
            need_real_front--;
            front_format = format;

            if (pDraw.type == DRAWABLE_WINDOW) {
                need_fake_front++;
            }
        }

        if (pDraw.type == DRAWABLE_WINDOW) {
            if (attachment == DRI2BufferFakeFrontLeft) {
                need_fake_front--;
                have_fake_front = 1;
            }
        }
    }

    if (need_real_front > 0) {
        if (allocate_or_reuse_buffer(pDraw, ds, pPriv, DRI2BufferFrontLeft,
                                     front_format, dimensions_match,
                                     &buffers[i]))
            buffers_changed = 1;

        if (buffers[i] is null)
            goto err_out;
        i++;
    }

    if (need_fake_front > 0) {
        if (allocate_or_reuse_buffer(pDraw, ds, pPriv, DRI2BufferFakeFrontLeft,
                                     front_format, dimensions_match,
                                     &buffers[i]))
            buffers_changed = 1;

        if (buffers[i] is null)
            goto err_out;

        i++;
        have_fake_front = 1;
    }

    *out_count = i;

    update_dri2_drawable_buffers(pPriv, pDraw, buffers, *out_count, width,
                                 height);

    /* If the client is getting a fake front-buffer, pre-fill it with the
     * contents of the real front-buffer.  This ensures correct operation of
     * applications that call glXWaitX before calling glDrawBuffer.
     */
    if (have_fake_front && buffers_changed) {
        BoxRec box = void;
        RegionRec region = void;

        box.x1 = 0;
        box.y1 = 0;
        box.x2 = cast(short)pPriv.width;
        box.y2 = cast(short)pPriv.height;
        RegionInit(&region, &box, 0);

        DRI2CopyRegion(pDraw, &region, DRI2BufferFakeFrontLeft,
                       DRI2BufferFrontLeft);
    }

    pPriv.needInvalidate = TRUE;

    return pPriv.buffers;

 err_out:

    *out_count = 0;

    if (buffers) {
        for (i = 0; i < count; i++) {
            if (buffers[i] !is null)
                destroy_buffer(pDraw, buffers[i], 0);
        }

        free(buffers);
        buffers = null;
    }

    update_dri2_drawable_buffers(pPriv, pDraw, buffers, *out_count, width,
                                 height);

    return buffers;
}

DRI2BufferPtr* DRI2GetBuffers(DrawablePtr pDraw, int* width, int* height, uint* attachments, int count, int* out_count)
{
    return do_get_buffers(pDraw, width, height, attachments, count,
                          out_count, FALSE);
}

DRI2BufferPtr* DRI2GetBuffersWithFormat(DrawablePtr pDraw, int* width, int* height, uint* attachments, int count, int* out_count)
{
    return do_get_buffers(pDraw, width, height, attachments, count,
                          out_count, TRUE);
}

private void DRI2InvalidateDrawable(DrawablePtr pDraw)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);

    if (!pPriv || !pPriv.needInvalidate)
        return;

    pPriv.needInvalidate = FALSE;

    DRI2DrawableRefPtr ref_ = void;
    mixin(xorg_list_for_each_entry!("ref_", "&pPriv.reference_list", "link", q{
        ref_.invalidate(pDraw, ref_.priv, ref_.id);
    }));
}

/*
 * In the direct rendered case, we throttle the clients that have more
 * than their share of outstanding swaps (and thus busy buffers) when a
 * new GetBuffers request is received.  In the AIGLX case, we allow the
 * client to get the new buffers, but throttle when the next GLX request
 * comes in (see __glXDRIcontextWait()).
 */
Bool DRI2ThrottleClient(ClientPtr client, DrawablePtr pDraw)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null)
        return FALSE;

    /* Throttle to swap limit */
    if (pPriv.swapsPending >= pPriv.swap_limit) {
        if (dri2Sleep(client, pPriv, WAKE_SWAP)) {
            ResetCurrentRequest(client);
            client.sequence--;
            return TRUE;
        }
    }

    return FALSE;
}

void DRI2BlockClient(ClientPtr client, DrawablePtr pDraw)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null)
        return;

    dri2Sleep(client, pPriv, WAKE_MSC);
}

pragma(inline, true) private PixmapPtr GetDrawablePixmap(DrawablePtr drawable)
{
    if (drawable.type == DRAWABLE_PIXMAP)
        return cast(PixmapPtr)drawable;
    else {
        _Window* pWin = cast(_Window*)drawable;
        return drawable.pScreen.GetWindowPixmap(pWin);
    }
}

/*
 * A TraverseTree callback to invalidate all windows using the same
 * pixmap
 */
private int DRI2InvalidateWalk(WindowPtr pWin, void* data)
{
    if (pWin.drawable.pScreen.GetWindowPixmap(pWin) != data)
        return WT_DONTWALKCHILDREN;
    DRI2InvalidateDrawable(&pWin.drawable);
    return WT_WALKCHILDREN;
}

private void DRI2InvalidateDrawableAll(DrawablePtr pDraw)
{
    if (pDraw.type == DRAWABLE_WINDOW) {
        WindowPtr pWin = cast(WindowPtr) pDraw;
        PixmapPtr pPixmap = pDraw.pScreen.GetWindowPixmap(pWin);

        /*
         * Find the top-most window using this pixmap
         */
        while (pWin.parent &&
               pDraw.pScreen.GetWindowPixmap(pWin.parent) == pPixmap)
            pWin = pWin.parent;

        /*
         * Walk the sub-tree to invalidate all of the
         * windows using the same pixmap
         */
        TraverseTree(pWin, &DRI2InvalidateWalk, pPixmap);
        DRI2InvalidateDrawable(&pPixmap.drawable);
    }
    else
        DRI2InvalidateDrawable(pDraw);
}

DrawablePtr DRI2UpdatePrime(DrawablePtr pDraw, DRI2BufferPtr pDest)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    PixmapPtr mpix = GetDrawablePixmap(pDraw);
    ScreenPtr primary = mpix.drawable.pScreen;

    if (pDraw.type == DRAWABLE_WINDOW) {
        WindowPtr pWin = cast(WindowPtr)pDraw;
        PixmapPtr pPixmap = pDraw.pScreen.GetWindowPixmap(pWin);

        if (pDraw.pScreen.GetScreenPixmap(pDraw.pScreen) == pPixmap) {
            if (pPriv.redirectpixmap &&
                pPriv.redirectpixmap.drawable.width == pDraw.width &&
                pPriv.redirectpixmap.drawable.height == pDraw.height &&
                pPriv.redirectpixmap.drawable.depth == pDraw.depth) {
                mpix = pPriv.redirectpixmap;
            } else {
                if (primary.ReplaceScanoutPixmap) {
                    mpix = (*primary.CreatePixmap)(primary, pDraw.width, pDraw.height,
                                                   pDraw.depth, CREATE_PIXMAP_USAGE_SHARED);
                    if (!mpix)
                        return null;

                    if (!(primary.ReplaceScanoutPixmap(pDraw, mpix, TRUE))) {
                        dixDestroyPixmap(mpix, 0);
                        return null;
                    }
                    pPriv.redirectpixmap = mpix;
                } else
                    return null;
            }
        } else if (pPriv.redirectpixmap) {
            (*primary.ReplaceScanoutPixmap)(pDraw, pPriv.redirectpixmap, FALSE);
            dixDestroyPixmap(pPriv.redirectpixmap, 0);
            pPriv.redirectpixmap = null;
        }
    }

    ScreenPtr secondary = GetScreenPrime(pDraw.pScreen, pPriv.prime_id);

    /* check if the pixmap is still fine */
    if (pPriv.prime_secondary_pixmap) {
        if (pPriv.prime_secondary_pixmap.primary_pixmap == mpix)
            return &pPriv.prime_secondary_pixmap.drawable;
        else {
            PixmapUnshareSecondaryPixmap(pPriv.prime_secondary_pixmap);
            dixDestroyPixmap(pPriv.prime_secondary_pixmap.primary_pixmap, 0);
            dixDestroyPixmap(pPriv.prime_secondary_pixmap, 0);
            pPriv.prime_secondary_pixmap = null;
        }
    }

    PixmapPtr spix = PixmapShareToSecondary(mpix, secondary);
    if (!spix)
        return null;

    pPriv.prime_secondary_pixmap = spix;
    spix.screen_x = mpix.screen_x;
    spix.screen_y = mpix.screen_y;

    DRI2InvalidateDrawableAll(pDraw);
    return &spix.drawable;
}

private void dri2_copy_region(DrawablePtr pDraw, RegionPtr pRegion, DRI2BufferPtr pDest, DRI2BufferPtr pSrc)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    ScreenPtr primeScreen = GetScreenPrime(pDraw.pScreen, pPriv.prime_id);
    DRI2ScreenPtr ds = DRI2GetScreen(primeScreen);

    if (ds.CopyRegion2)
        (*ds.CopyRegion2)(primeScreen, pDraw, pRegion, pDest, pSrc);
    else
        (*ds.CopyRegion) (pDraw, pRegion, pDest, pSrc);

    /* cause damage to the box */
    if (pPriv.prime_id) {
        BoxRec box = {
            x2: pDraw.width,
            y2: pDraw.height,
        };
        RegionRec region = void;
        RegionInit(&region, &box, 1);
        RegionTranslate(&region, pDraw.x, pDraw.y);
        DamageRegionAppend(pDraw, &region);
        DamageRegionProcessPending(pDraw);
        RegionUninit(&region);
    }
}

int DRI2CopyRegion(DrawablePtr pDraw, RegionPtr pRegion, uint dest, uint src)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null)
        return BadDrawable;

    DRI2BufferPtr pDestBuffer = null;
    DRI2BufferPtr pSrcBuffer = null;
    for (int i = 0; i < pPriv.bufferCount; i++) {
        if (pPriv.buffers[i].attachment == dest)
            pDestBuffer = cast(DRI2BufferPtr) pPriv.buffers[i];
        if (pPriv.buffers[i].attachment == src)
            pSrcBuffer = cast(DRI2BufferPtr) pPriv.buffers[i];
    }
    if (pSrcBuffer is null || pDestBuffer is null)
        return BadValue;

    dri2_copy_region(pDraw, pRegion, pDestBuffer, pSrcBuffer);

    return Success;
}

/* Can this drawable be page flipped? */
Bool DRI2CanFlip(DrawablePtr pDraw)
{
    ScreenPtr pScreen = pDraw.pScreen;

    if (pDraw.type == DRAWABLE_PIXMAP)
        return TRUE;

    WindowPtr pRoot = pScreen.root;
    PixmapPtr pRootPixmap = pScreen.GetWindowPixmap(pRoot);

    WindowPtr pWin = cast(WindowPtr) pDraw;
    PixmapPtr pWinPixmap = pScreen.GetWindowPixmap(pWin);
    if (pRootPixmap != pWinPixmap)
        return FALSE;
    if (!RegionEqual(&pWin.clipList, &pRoot.winSize))
        return FALSE;

    /* Does the window match the pixmap exactly? */
    if (pDraw.x != 0 || pDraw.y != 0 ||
        pDraw.x != pWinPixmap.screen_x || pDraw.y != pWinPixmap.screen_y ||
        pDraw.width != pWinPixmap.drawable.width ||
        pDraw.height != pWinPixmap.drawable.height)
        return FALSE;

    return TRUE;
}

/* Can we do a pixmap exchange instead of a blit? */
Bool DRI2CanExchange(DrawablePtr pDraw)
{
    return FALSE;
}

void DRI2WaitMSCComplete(ClientPtr client, DrawablePtr pDraw, int frame, uint tv_sec, uint tv_usec)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null)
        return;

    ProcDRI2WaitMSCReply(client, (cast(CARD64) tv_sec * 1000000) + tv_usec,
                         frame, pPriv.swap_count);

    dri2WakeAll(client, pPriv, WAKE_MSC);
}

private void DRI2WakeClient(ClientPtr client, DrawablePtr pDraw, int frame, uint tv_sec, uint tv_usec)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null) {
        LogMessage(X_ERROR, "[DRI2] %s: bad drawable\n");
        return;
    }

    /*
     * Swap completed.
     * Wake the client iff:
     *   - it was waiting on SBC
     *   - was blocked due to GLX make current
     *   - was blocked due to swap throttling
     *   - is not blocked due to an MSC wait
     */
    if (pPriv.target_sbc != -1 && pPriv.target_sbc <= pPriv.swap_count) {
        if (dri2WakeAll(client, pPriv, WAKE_SBC)) {
            ProcDRI2WaitMSCReply(client, (cast(CARD64) tv_sec * 1000000) + tv_usec,
                                 frame, pPriv.swap_count);
            pPriv.target_sbc = -1;
        }
    }

    dri2WakeAll(cast(ClientPtr)CLIENT_SIGNAL_ANY, pPriv, WAKE_SWAP);
}

void DRI2SwapComplete(ClientPtr client, DrawablePtr pDraw, int frame, uint tv_sec, uint tv_usec, int type, DRI2SwapEventPtr swap_complete, void* swap_data)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null) {
        LogMessage(X_ERROR, "[DRI2] %s: bad drawable\n");
        return;
    }

    pPriv.swapsPending--;
    pPriv.swap_count++;

    BoxRec box = {
        x2: pDraw.width,
        y2: pDraw.height,
    };

    RegionRec region = void;
    RegionInit(&region, &box, 0);

    DRI2CopyRegion(pDraw, &region, DRI2BufferFakeFrontLeft,
                   DRI2BufferFrontLeft);

    CARD64 ust = (cast(CARD64) tv_sec * 1000000) + tv_usec;
    if (swap_complete)
        swap_complete(client, swap_data, type, ust, frame,cast(uint) pPriv.swap_count);

    pPriv.last_swap_msc = frame;
    pPriv.last_swap_ust = ust;

    DRI2WakeClient(client, pDraw, frame, tv_sec, tv_usec);
}

Bool DRI2WaitSwap(ClientPtr client, DrawablePtr pDrawable)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDrawable);

    /* If we're currently waiting for a swap on this drawable, reset
     * the request and suspend the client. */
    if (pPriv && pPriv.swapsPending) {
        if (dri2Sleep(client, pPriv, WAKE_SWAP)) {
            ResetCurrentRequest(client);
            client.sequence--;
            return TRUE;
        }
    }

    return FALSE;
}

int DRI2SwapBuffers(ClientPtr client, DrawablePtr pDraw, CARD64 target_msc, CARD64 divisor, CARD64 remainder, CARD64* swap_target, DRI2SwapEventPtr func, void* data)
{
    DRI2ScreenPtr ds = DRI2GetScreen(pDraw.pScreen);

    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null) {
        LogMessage(X_ERROR, "[DRI2] %s: bad drawable\n");
        return BadDrawable;
    }

    /* According to spec, return expected swapbuffers count SBC after this swap
     * will complete. This is ignored unless we return Success, but it must be
     * initialized on every path where we return Success or the caller will send
     * an uninitialized value off the stack to the client. So let's initialize
     * it as early as possible, just to be sure.
     */
    *swap_target = pPriv.swap_count + pPriv.swapsPending + 1;

    DRI2BufferPtr pDestBuffer = null, pSrcBuffer = null;
    for (int i = 0; i < pPriv.bufferCount; i++) {
        if (pPriv.buffers[i].attachment == DRI2BufferFrontLeft)
            pDestBuffer = cast(DRI2BufferPtr) pPriv.buffers[i];
        if (pPriv.buffers[i].attachment == DRI2BufferBackLeft)
            pSrcBuffer = cast(DRI2BufferPtr) pPriv.buffers[i];
    }
    if (pSrcBuffer is null || pDestBuffer is null) {
        LogMessage(X_ERROR, "[DRI2] %s: drawable has no back or front?\n");
        return BadDrawable;
    }

    /* Old DDX or no swap interval, just blit */
    if (!ds.ScheduleSwap || !pPriv.swap_interval || pPriv.prime_id) {
        BoxRec box = void;
        RegionRec region = void;

        box.x1 = 0;
        box.y1 = 0;
        box.x2 = pDraw.width;
        box.y2 = pDraw.height;
        RegionInit(&region, &box, 0);

        pPriv.swapsPending++;

        dri2_copy_region(pDraw, &region, pDestBuffer, pSrcBuffer);
        DRI2SwapComplete(client, pDraw, cast(int)target_msc, 0, 0, DRI2_BLIT_COMPLETE,
                         func, data);
        return Success;
    }

    /*
     * In the simple glXSwapBuffers case, all params will be 0, and we just
     * need to schedule a swap for the last swap target + the swap interval.
     */
    if (target_msc == 0 && divisor == 0 && remainder == 0) {
        /* If the current vblank count of the drawable's crtc is lower
         * than the count stored in last_swap_target from a previous swap
         * then reinitialize last_swap_target to the current crtc's msc,
         * otherwise the swap will hang. This will happen if the drawable
         * is moved to a crtc with a lower refresh rate, or a crtc that just
         * got enabled.
         */
        if (ds.GetMSC) {
            CARD64 current_msc = void, ust = void;
            if (!(*ds.GetMSC) (pDraw, &ust, &current_msc))
                pPriv.last_swap_target = 0;

            if (current_msc < pPriv.last_swap_target)
                pPriv.last_swap_target = current_msc;
        }

        /*
         * Swap target for this swap is last swap target + swap interval since
         * we have to account for the current swap count, interval, and the
         * number of pending swaps.
         */
        target_msc = pPriv.last_swap_target + pPriv.swap_interval;

    }

    pPriv.swapsPending++;
    int ret = (*ds.ScheduleSwap) (client, pDraw, pDestBuffer, pSrcBuffer,
                                   &target_msc, divisor, remainder, func, data);
    if (!ret) {
        pPriv.swapsPending--;  /* didn't schedule */
        LogMessage(X_ERROR, "[DRI2] %s: driver failed to schedule swap\n");
        return BadDrawable;
    }

    pPriv.last_swap_target = target_msc;

    DRI2InvalidateDrawableAll(pDraw);

    return Success;
}

void DRI2SwapInterval(DrawablePtr pDrawable, int interval)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDrawable);

    if (pPriv is null) {
        LogMessage(X_ERROR, "[DRI2] %s: bad drawable\n");
        return;
    }

    /* fixme: check against arbitrary max? */
    pPriv.swap_interval = interval;
}

int DRI2GetMSC(DrawablePtr pDraw, CARD64* ust, CARD64* msc, CARD64* sbc)
{
    DRI2ScreenPtr ds = DRI2GetScreen(pDraw.pScreen);

    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null) {
        LogMessage(X_ERROR, "[DRI2] %s: bad drawable\n");
        return BadDrawable;
    }

    if (!ds.GetMSC) {
        *ust = 0;
        *msc = 0;
        *sbc = pPriv.swap_count;
        return Success;
    }

    /*
     * Spec needs to be updated to include unmapped or redirected
     * drawables
     */

    if (!(ds.GetMSC(pDraw, ust, msc)))
        return BadDrawable;

    *sbc = pPriv.swap_count;

    return Success;
}

int DRI2WaitMSC(ClientPtr client, DrawablePtr pDraw, CARD64 target_msc, CARD64 divisor, CARD64 remainder)
{
    DRI2ScreenPtr ds = DRI2GetScreen(pDraw.pScreen);
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null)
        return BadDrawable;

    /* Old DDX just completes immediately */
    if (!ds.ScheduleWaitMSC) {
        DRI2WaitMSCComplete(client, pDraw, cast(int)target_msc, 0, 0);
        return Success;
    }

    if (!(ds.ScheduleWaitMSC(client, pDraw, target_msc, divisor, remainder)))
        return BadDrawable;

    return Success;
}

int DRI2WaitSBC(ClientPtr client, DrawablePtr pDraw, CARD64 target_sbc)
{
    DRI2DrawablePtr pPriv = DRI2GetDrawable(pDraw);
    if (pPriv is null)
        return BadDrawable;

    if (pPriv.target_sbc != -1) /* already in use */
        return BadDrawable;

    /* target_sbc == 0 means to block until all pending swaps are
     * finished. Recalculate target_sbc to get that behaviour.
     */
    if (target_sbc == 0)
        target_sbc = pPriv.swap_count + pPriv.swapsPending;

    /* If current swap count already >= target_sbc, reply and
     * return immediately with (ust, msc, sbc) triplet of
     * most recent completed swap.
     */
    if (pPriv.swap_count >= target_sbc) {
        ProcDRI2WaitMSCReply(client, pPriv.last_swap_ust,
                             pPriv.last_swap_msc, pPriv.swap_count);
        return Success;
    }

    if (!dri2Sleep(client, pPriv, WAKE_SBC))
        return BadAlloc;

    pPriv.target_sbc = target_sbc;
    return Success;
}

Bool DRI2HasSwapControl(ScreenPtr pScreen)
{
    DRI2ScreenPtr ds = DRI2GetScreen(pScreen);

    return ds.ScheduleSwap && ds.GetMSC;
}

Bool DRI2Connect(ClientPtr client, ScreenPtr pScreen, uint driverType, int* fd, const(char)** driverName, const(char)** deviceName)
{
    uint prime_id = mixin(DRI2DriverPrimeId!("driverType"));
    uint driver_id = driverType & 0xffff;

    if (!dixPrivateKeyRegistered(&dri2ScreenPrivateKeyRec))
        return FALSE;

    DRI2ScreenPtr ds = DRI2GetScreenPrime(pScreen, prime_id);
    if (ds is null)
        return FALSE;

    if (driver_id >= ds.numDrivers ||
        !ds.driverNames[driver_id])
        return FALSE;

    *driverName = ds.driverNames[driver_id];
    *deviceName = ds.deviceName;
    *fd = ds.fd;

    if (client) {
        DRI2ClientPtr dri2_client = void;
        dri2_client = dri2ClientPrivate(client);
        dri2_client.prime_id = prime_id;
    }

    return TRUE;
}

private int DRI2AuthMagic(ScreenPtr pScreen, uint magic)
{
    DRI2ScreenPtr ds = DRI2GetScreen(pScreen);
    if (ds is null)
        return -EINVAL;

    return (*ds.LegacyAuthMagic) (ds.fd, magic);
}

Bool DRI2Authenticate(ClientPtr client, ScreenPtr pScreen, uint magic)
{
    if (!dixPrivateKeyRegistered(&dri2ScreenPrivateKeyRec))
        return FALSE;

    DRI2ClientPtr dri2_client = dri2ClientPrivate(client);

    DRI2ScreenPtr ds = DRI2GetScreenPrime(pScreen, dri2_client.prime_id);
    if (ds is null)
        return FALSE;

    ScreenPtr primescreen = GetScreenPrime(pScreen, dri2_client.prime_id);
    if ((*ds.AuthMagic)(primescreen, magic))
        return FALSE;
    return TRUE;
}

private int DRI2ConfigNotify(WindowPtr pWin, int x, int y, int w, int h, int bw, WindowPtr pSib)
{
    DrawablePtr pDraw = cast(DrawablePtr) pWin;
    ScreenPtr pScreen = pDraw.pScreen;
    DRI2ScreenPtr ds = DRI2GetScreen(pScreen);
    DRI2DrawablePtr dd = DRI2GetDrawable(pDraw);

    if (ds.ConfigNotify) {
        pScreen.ConfigNotify = ds.ConfigNotify;

        int ret = pScreen.ConfigNotify(pWin, x, y, w, h, bw, pSib);

        ds.ConfigNotify = pScreen.ConfigNotify;
        pScreen.ConfigNotify = &DRI2ConfigNotify;
        if (ret)
            return ret;
    }

    if (!dd || (dd.width == w && dd.height == h))
        return Success;

    DRI2InvalidateDrawable(pDraw);
    return Success;
}

private void DRI2SetWindowPixmap(WindowPtr pWin, PixmapPtr pPix)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    DRI2ScreenPtr ds = DRI2GetScreen(pScreen);

    pScreen.SetWindowPixmap = ds.SetWindowPixmap;
    (*pScreen.SetWindowPixmap) (pWin, pPix);
    ds.SetWindowPixmap = pScreen.SetWindowPixmap;
    pScreen.SetWindowPixmap = &DRI2SetWindowPixmap;

    DRI2InvalidateDrawable(&pWin.drawable);
}

enum MAX_PRIME = DRI2DriverPrimeMask;
private int get_prime_id()
{
    int i = void;
    /* start at 1, prime id 0 is just normal driver */
    for (i = 1; i < MAX_PRIME; i++) {
         if (prime_id_allocate_bitmask & (1 << i))
             continue;

         prime_id_allocate_bitmask |= (1 << i);
         return i;
    }
    return -1;
}

import Xext.dri2.pci_ids.pci_id_driver_map;

private char* dri2_probe_driver_name(ScreenPtr pScreen, DRI2InfoPtr info)
{
static if (WITH_LIBDRM) {
    int i = void, j = void;
    char* driver = null;
    drmDevicePtr dev = void;

    /* For non-PCI devices and drmGetDevice fail, just assume that
     * the 3D driver is named the same as the kernel driver. This is
     * currently true for vc4 and msm (freedreno).
     */
    if (drmGetDevice(info.fd, &dev) || dev.bustype != DRM_BUS_PCI) {
        drmVersionPtr version_ = drmGetVersion(info.fd);

        if (!version_) {
            LogMessage(X_ERROR, "[DRI2] Couldn't drmGetVersion() on non-PCI device, "
                       ~ "no driver name found.\n");
            return null;
        }

        driver = strndup(version_.name, version_.name_len);
        drmFreeVersion(version_);
        return driver;
    }

    for (i = 0; driver_map[i].driver; i++) {
        if (dev.deviceinfo.pci.vendor_id != driver_map[i].vendor_id)
            continue;

        if (driver_map[i].num_chips_ids == -1) {
             driver = strdup(driver_map[i].driver);
             goto out_;
        }

        for (j = 0; j < driver_map[i].num_chips_ids; j++) {
            if (driver_map[i].chip_ids[j] == dev.deviceinfo.pci.device_id) {
                driver = strdup(driver_map[i].driver);
                goto out_;
            }
        }
    }

    LogMessage(X_ERROR,
               "[DRI2] No driver mapping found for PCI device "
               ~ "0x%04x / 0x%04x\n",
               dev.deviceinfo.pci.vendor_id, dev.deviceinfo.pci.device_id);
out_:
    drmFreeDevice(&dev);
    return driver;
} else {
    return null;
}
}

Bool DRI2ScreenInit(ScreenPtr pScreen, DRI2InfoPtr info)
{
    const(char)*[3] driverTypeNames = [
        "DRI"c.ptr,                  /* DRI2DriverDRI */
        "VDPAU"c.ptr,                /* DRI2DriverVDPAU */
        null
    ];

    if (info.version_ < 3)
        return FALSE;

    if (!dixRegisterPrivateKey(&dri2ScreenPrivateKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!dixRegisterPrivateKey(&dri2WindowPrivateKeyRec, PRIVATE_WINDOW, 0))
        return FALSE;

    if (!dixRegisterPrivateKey(&dri2PixmapPrivateKeyRec, PRIVATE_PIXMAP, 0))
        return FALSE;

    if (!dixRegisterPrivateKey(&dri2ClientPrivateKeyRec, PRIVATE_CLIENT, DRI2ClientRec.sizeof))
        return FALSE;

    DRI2ScreenPtr ds;
    ds = cast(DRI2ScreenPtr)calloc(1, (*ds).sizeof);
    if (!ds)
        return FALSE;

    ds.pScreen = pScreen;
    ds.fd = info.fd;
    ds.deviceName = info.deviceName;
    dri2_major = 1;

    ds.CreateBuffer = info.CreateBuffer;
    ds.DestroyBuffer = info.DestroyBuffer;
    ds.CopyRegion = info.CopyRegion;
    CARD8 cur_minor = 1;

    if (info.version_ >= 4) {
        ds.ScheduleSwap = info.ScheduleSwap;
        ds.ScheduleWaitMSC = info.ScheduleWaitMSC;
        ds.GetMSC = info.GetMSC;
        cur_minor = 3;
    }

    if (info.version_ >= 5) {
        ds.LegacyAuthMagic = info.AuthMagic;
    }

    if (info.version_ >= 6) {
        ds.ReuseBufferNotify = info.ReuseBufferNotify;
        ds.SwapLimitValidate = info.SwapLimitValidate;
    }

    if (info.version_ >= 7) {
        ds.GetParam = info.GetParam;
        cur_minor = 4;
    }

    if (info.version_ >= 8) {
        ds.AuthMagic = info.AuthMagic2;
    }

    if (info.version_ >= 9) {
        ds.CreateBuffer2 = info.CreateBuffer2;
        if (info.CreateBuffer2 && pScreen.isGPU) {
            ds.prime_id = get_prime_id();
            if (ds.prime_id == -1) {
                free(ds);
                return FALSE;
            }
        }
        ds.DestroyBuffer2 = info.DestroyBuffer2;
        ds.CopyRegion2 = info.CopyRegion2;
    }

    /*
     * if the driver doesn't provide an AuthMagic function or the info struct
     * version is too low, call through LegacyAuthMagic
     */
    if (!ds.AuthMagic) {
        ds.AuthMagic = &DRI2AuthMagic;
        /*
         * If the driver doesn't provide an AuthMagic function
         * it relies on the old method (using libdrm) or fails
         */
        if (!ds.LegacyAuthMagic) {
static if (WITH_LIBDRM) {
            ds.LegacyAuthMagic = &drmAuthMagic;
} else {
            goto err_out;
}
}
}

    /* Initialize minor if needed and set to minimum provided by DDX */
    if (!dri2_minor || dri2_minor > cur_minor)
        dri2_minor = cur_minor;

    if (info.version_ == 3 || info.numDrivers == 0) {
        /* Driver too old: use the old-style driverName field */
        ds.numDrivers = info.driverName ? 1 : 2;
        // ds.driverNames;
        ds.driverNames = cast(const(char)**)calloc(ds.numDrivers, typeof(*ds.driverNames).sizeof);
        if (!ds.driverNames)
            goto err_out;

        if (info.driverName) {
            ds.driverNames[0] = info.driverName;
        } else {
            /* FIXME dri2_probe_driver_name() returns a strdup-ed string,
             * currently this gets leaked */
            ds.driverNames[0] = ds.driverNames[1] = dri2_probe_driver_name(pScreen, info);
            if (!ds.driverNames[0])
                return FALSE;

            /* There is no VDPAU driver for i965, fallback to the generic
             * OpenGL/VAAPI va_gl backend to emulate VDPAU on i965. */
            if (strcmp(ds.driverNames[0], "i965") == 0)
                ds.driverNames[1] = "va_gl";
        }
    }
    else {
        ds.numDrivers = info.numDrivers;
        ds.driverNames = cast(const(char)**)calloc(info.numDrivers, typeof(*ds.driverNames).sizeof);
        if (!ds.driverNames)
            goto err_out;
        memcpy(ds.driverNames, info.driverNames,
               info.numDrivers * typeof(*ds.driverNames).sizeof);
    }

    dixSetPrivate(&pScreen.devPrivates, &dri2ScreenPrivateKeyRec, ds);

    ds.ConfigNotify = pScreen.ConfigNotify;
    pScreen.ConfigNotify = &DRI2ConfigNotify;

    ds.SetWindowPixmap = pScreen.SetWindowPixmap;
    pScreen.SetWindowPixmap = &DRI2SetWindowPixmap;

    LogMessage(X_INFO, "[DRI2] Setup complete\n");
    for (int i = 0; i < mixin(ARRAY_SIZE!("driverTypeNames")); i++) {
        if (i < ds.numDrivers && ds.driverNames[i]) {
            LogMessage(X_INFO, "[DRI2]   %s driver: %s\n",
                       driverTypeNames[i], ds.driverNames[i]);
        }
    }

    return TRUE;

 err_out:
    LogMessage(X_WARNING,
               "[DRI2] Initialization failed for info version %d.\n",
               info.version_);
    free(ds);
    return FALSE;
}

void DRI2CloseScreen(ScreenPtr pScreen)
{
    DRI2ScreenPtr ds = DRI2GetScreen(pScreen);

    pScreen.ConfigNotify = ds.ConfigNotify;
    pScreen.SetWindowPixmap = ds.SetWindowPixmap;

    if (ds.prime_id)
        prime_id_allocate_bitmask &= ~(1 << ds.prime_id);
    free(ds.driverNames);
    free(ds);
    dixSetPrivate(&pScreen.devPrivates, &dri2ScreenPrivateKeyRec, null);
}

/* Called by InitExtensions() */
Bool DRI2ModuleSetup()
{
    dri2DrawableRes = CreateNewResourceType(&DRI2DrawableGone, "DRI2Drawable");
    if (!dri2DrawableRes)
        return FALSE;

    return TRUE;
}

void DRI2Version(int* major, int* minor)
{
    if (major !is null)
        *major = 1;

    if (minor !is null)
        *minor = 2;
}

int DRI2GetParam(ClientPtr client, DrawablePtr drawable, CARD64 param, BOOL* is_param_recognized, CARD64* value)
{
    DRI2ScreenPtr ds = DRI2GetScreen(drawable.pScreen);
    char high_byte = cast(char)(param >> 24);

    switch (high_byte) {
    case 0:
        /* Parameter names whose high_byte is 0 are reserved for the X
         * server. The server currently recognizes no parameters.
         */
        goto not_recognized;
    case 1:
        /* Parameter names whose high byte is 1 are reserved for the DDX. */
        if (ds.GetParam)
            return ds.GetParam(client, drawable, param,
                                is_param_recognized, value);
        else
            goto not_recognized;
    default:
        /* Other parameter names are reserved for future use. They are never
         * recognized.
         */
        goto not_recognized;
    }

not_recognized:
    *is_param_recognized = FALSE;
    return Success;
}
