module hw.xfree86.drivers.video.modesetting.dri2;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Intel Corporation
 * Copyright © 2014 Broadcom
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
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 */

/**
 * @file dri2.c
 *
 * Implements generic support for DRI2 on KMS, using glamor pixmaps
 * for color buffer management (no support for other aux buffers), and
 * the DRM vblank ioctls.
 *
 * This doesn't implement pageflipping yet.
 */

import build.dix_config;

import core.stdc.errno;
import core.stdc.time;
import hw.xfree86.drivers.video.modesetting.present;
import pageflip;
import hw.xfree86.drivers.video.modesetting.drmmode_display;
import externs.libdrm;
import dix.dix_priv;
import externs.X11.extensions.dri2tokens;
import dix.gc;
import include.list;
import include.xf86;
// import driver;
import include.dri2;
import include.xf86Crtc;
import hw.xfree86.common.xf86Helper;
import Xext.dri2.dri2;
import hw.xfree86.drivers.video.modesetting.vblank;
import hw.xfree86.drivers.video.modesetting.drmmode_display;
import hw.xfree86.modes.xf86Crtc;

static if (GLAMOR) {
import hw.xfree86.drivers.video.modesetting.driver;

enum ms_dri2_frame_event_type {
    MS_DRI2_QUEUE_SWAP,
    MS_DRI2_QUEUE_FLIP,
    MS_DRI2_WAIT_MSC,
}
alias MS_DRI2_QUEUE_SWAP = ms_dri2_frame_event_type.MS_DRI2_QUEUE_SWAP;
alias MS_DRI2_QUEUE_FLIP = ms_dri2_frame_event_type.MS_DRI2_QUEUE_FLIP;
alias MS_DRI2_WAIT_MSC = ms_dri2_frame_event_type.MS_DRI2_WAIT_MSC;


struct ms_dri2_frame_event {
    ScreenPtr screen;

    DrawablePtr drawable;
    ClientPtr client;
    ms_dri2_frame_event_type type;
    int frame;
    xf86CrtcPtr crtc;

    xorg_list drawable_resource, client_resource;

    /* for swaps & flips only */
    DRI2SwapEventPtr event_complete;
    void* event_data;
    DRI2BufferPtr front;
    DRI2BufferPtr back;
}alias ms_dri2_frame_event_rec = ms_dri2_frame_event;
alias ms_dri2_frame_event_ptr = ms_dri2_frame_event*;

struct _Ms_dri2_buffer_private_rec {
    int refcnt;
    PixmapPtr pixmap;
}alias ms_dri2_buffer_private_rec = _Ms_dri2_buffer_private_rec;
alias ms_dri2_buffer_private_ptr = ms_dri2_buffer_private_rec*;

private DevPrivateKeyRec ms_dri2_client_key;
private RESTYPE frame_event_client_type, frame_event_drawable_type;
private x_server_generation_t ms_dri2_server_generation;

struct ms_dri2_resource {
    XID id;
    RESTYPE type;
    xorg_list list;
}

private ms_dri2_resource* ms_get_resource(XID id, RESTYPE type)
{
    void* ptr = void;

    ptr = null;
    dixLookupResourceByType(&ptr, id, type, null, DixWriteAccess);
    if (ptr)
        return cast(ms_dri2_resource*)ptr;

    ms_dri2_resource* resource = cast(ms_dri2_resource*) calloc(1, ms_dri2_resource.sizeof);
    if (resource is null)
        return null;

    if (!AddResource(cast(uint)id, type, resource))
        return null;

    resource.id = id;
    resource.type = type;
    xorg_list_init(&resource.list);
    return resource;
}

pragma(inline, true) private PixmapPtr get_drawable_pixmap(DrawablePtr drawable)
{
    ScreenPtr screen = drawable.pScreen;

    if (drawable.type == DRAWABLE_PIXMAP)
        return cast(PixmapPtr) drawable;
    else
        return screen.GetWindowPixmap(cast(WindowPtr) drawable);
}

private DRI2Buffer2Ptr ms_dri2_create_buffer2(ScreenPtr screen, DrawablePtr drawable, uint attachment, uint format)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    DRI2Buffer2Ptr buffer = void;
    PixmapPtr pixmap = void;
    CARD32 size = void;
    CARD16 pitch = void;
    ms_dri2_buffer_private_ptr private_ = void;

    buffer = cast(DRI2Buffer2Ptr)calloc(1, (_DRI2Buffer).sizeof);
    if (buffer is null)
        return null;

    private_ = cast(ms_dri2_buffer_private_ptr)calloc(1, (ms_dri2_buffer_private_rec).sizeof);
    if (private_ is null) {
        free(buffer);
        return null;
    }

    pixmap = null;
    if (attachment == DRI2BufferFrontLeft) {
        pixmap = get_drawable_pixmap(drawable);
        if (pixmap && pixmap.drawable.pScreen != screen)
            pixmap = null;
        if (pixmap)
            pixmap.refcnt++;
    }

    if (pixmap is null) {
        int pixmap_width = drawable.width;
        int pixmap_height = drawable.height;
        int pixmap_cpp = (format != 0) ? format : drawable.depth;

        /* Assume that non-color-buffers require special
         * device-specific handling.  Mesa currently makes no requests
         * for non-color aux buffers.
         */
        switch (attachment) {
        case DRI2BufferAccum:
        case DRI2BufferBackLeft:
        case DRI2BufferBackRight:
        case DRI2BufferFakeFrontLeft:
        case DRI2BufferFakeFrontRight:
        case DRI2BufferFrontLeft:
        case DRI2BufferFrontRight:
            break;

        case DRI2BufferStencil:
        case DRI2BufferDepth:
        case DRI2BufferDepthStencil:
        case DRI2BufferHiz:
        default:
            xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                       "Request for DRI2 buffer attachment %d unsupported\n",
                       attachment);
            free(private_);
            free(buffer);
            return null;
        }

        pixmap = screen.CreatePixmap(screen,
                                      pixmap_width,
                                      pixmap_height,
                                      pixmap_cpp,
                                      0);
        if (pixmap is null) {
            free(private_);
            free(buffer);
            return null;
        }
    }

    buffer.attachment = attachment;
    buffer.cpp = pixmap.drawable.bitsPerPixel / 8;
    buffer.format = format;
    /* The buffer's flags field is unused by the client drivers in
     * Mesa currently.
     */
    buffer.flags = 0;

    buffer.name = ms.glamor.name_from_pixmap(pixmap, &pitch, &size);
    buffer.pitch = pitch;
    if (buffer.name == -1) {
        xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                   "Failed to get DRI2 name for pixmap\n");
        dixDestroyPixmap(pixmap, 0);
        free(private_);
        free(buffer);
        return null;
    }

    buffer.driverPrivate = private_;
    private_.refcnt = 1;
    private_.pixmap = pixmap;

    return buffer;
}

private DRI2Buffer2Ptr ms_dri2_create_buffer(DrawablePtr drawable, uint attachment, uint format)
{
    return ms_dri2_create_buffer2(drawable.pScreen, drawable, attachment,
                                  format);
}

private void ms_dri2_reference_buffer(DRI2Buffer2Ptr buffer)
{
    if (buffer) {
        ms_dri2_buffer_private_ptr private_ = cast(ms_dri2_buffer_private_ptr)buffer.driverPrivate;
        private_.refcnt++;
    }
}

private void ms_dri2_destroy_buffer2(ScreenPtr unused, DrawablePtr unused2, DRI2Buffer2Ptr buffer)
{
    if (!buffer)
        return;

    if (buffer.driverPrivate) {
        ms_dri2_buffer_private_ptr private_ = cast(ms_dri2_buffer_private_ptr)buffer.driverPrivate;
        if (--private_.refcnt == 0) {
            dixDestroyPixmap(private_.pixmap, 0);
            free(private_);
            free(buffer);
        }
    } else {
        free(buffer);
    }
}

private void ms_dri2_destroy_buffer(DrawablePtr drawable, DRI2Buffer2Ptr buffer)
{
    ms_dri2_destroy_buffer2(null, drawable, buffer);
}

private void ms_dri2_copy_region2(ScreenPtr screen, DrawablePtr drawable, RegionPtr pRegion, DRI2BufferPtr destBuffer, DRI2BufferPtr sourceBuffer)
{
    ms_dri2_buffer_private_ptr src_priv = cast(ms_dri2_buffer_private_ptr)sourceBuffer.driverPrivate;
    ms_dri2_buffer_private_ptr dst_priv = cast(ms_dri2_buffer_private_ptr)destBuffer.driverPrivate;
    PixmapPtr src_pixmap = src_priv.pixmap;
    PixmapPtr dst_pixmap = dst_priv.pixmap;
    DrawablePtr src = (sourceBuffer.attachment == DRI2BufferFrontLeft)
        ? drawable : &src_pixmap.drawable;
    DrawablePtr dst = (destBuffer.attachment == DRI2BufferFrontLeft)
        ? drawable : &dst_pixmap.drawable;
    int off_x = 0, off_y = 0;
    Bool translate = FALSE;
    RegionPtr pCopyClip = void;
    GCPtr gc = void;

    if (destBuffer.attachment == DRI2BufferFrontLeft &&
             drawable.pScreen != screen) {
        dst = DRI2UpdatePrime(drawable, destBuffer);
        if (!dst)
            return;
        if (dst != drawable)
            translate = TRUE;
    }

    if (translate && drawable.type == DRAWABLE_WINDOW) {
        PixmapPtr pixmap = get_drawable_pixmap(drawable);
        off_x = -pixmap.screen_x;
        off_y = -pixmap.screen_y;
        off_x += drawable.x;
        off_y += drawable.y;
    }

    gc = GetScratchGC(dst.depth, screen);
    if (!gc)
        return;

    pCopyClip = mixin(REGION_CREATE!("screen", "null", "0"));
    mixin(REGION_COPY!("screen", "pCopyClip", "pRegion") ~";");
    if (translate)
        mixin(REGION_TRANSLATE!("screen", "pCopyClip", "off_x", "off_y") ~";");
    (*gc.funcs.ChangeClip) (gc, CT_REGION, pCopyClip, 0);
    ValidateGC(dst, gc);

    /* It's important that this copy gets submitted before the direct
     * rendering client submits rendering for the next frame, but we
     * don't actually need to submit right now.  The client will wait
     * for the DRI2CopyRegion reply or the swap buffer event before
     * rendering, and we'll hit the flush callback chain before those
     * messages are sent.  We submit our batch buffers from the flush
     * callback chain so we know that will happen before the client
     * tries to render again.
     */
    cast(void) gc.ops.CopyArea(src, dst, gc,
                      0, 0,
                      drawable.width, drawable.height,
                      off_x, off_y);

    FreeScratchGC(gc);
}

private void ms_dri2_copy_region(DrawablePtr drawable, RegionPtr pRegion, DRI2BufferPtr destBuffer, DRI2BufferPtr sourceBuffer)
{
    ms_dri2_copy_region2(drawable.pScreen, drawable, pRegion, destBuffer,
                         sourceBuffer);
}

private ulong gettime_us()
{
    timespec tv = void;

    if (clock_gettime(CLOCK_MONOTONIC, &tv))
        return 0;

    return cast(ulong)tv.tv_sec * 1000000 + tv.tv_nsec / 1000;
}

/**
 * Get current frame count and frame count timestamp, based on drawable's
 * crtc.
 */
private int ms_dri2_get_msc(DrawablePtr draw, CARD64* ust, CARD64* msc)
{
    int ret = void;
    xf86CrtcPtr crtc = ms_dri2_crtc_covering_drawable(draw);

    /* Drawable not displayed, make up a *monotonic* value */
    if (crtc is null) {
        *ust = gettime_us();
        *msc = 0;
        return TRUE;
    }

    ret = ms_get_crtc_ust_msc(crtc, ust, msc);

    if (ret)
        return FALSE;

    return TRUE;
}

private XID get_client_id(ClientPtr client)
{
    XID* ptr = cast(XID*)dixGetPrivateAddr(&client.devPrivates, &ms_dri2_client_key);
    if (*ptr == 0)
        *ptr = FakeClientID(client.index);
    return *ptr;
}

/*
 * Hook this frame event into the server resource
 * database so we can clean it up if the drawable or
 * client exits while the swap is pending
 */
private Bool ms_dri2_add_frame_event(ms_dri2_frame_event_ptr info)
{
    ms_dri2_resource* resource = void;

    resource = ms_get_resource(get_client_id(info.client),
                               frame_event_client_type);
    if (resource is null)
        return FALSE;

    xorg_list_add(&info.client_resource, &resource.list);

    resource = ms_get_resource(info.drawable.id, frame_event_drawable_type);
    if (resource is null) {
        xorg_list_del(&info.client_resource);
        return FALSE;
    }

    xorg_list_add(&info.drawable_resource, &resource.list);

    return TRUE;
}

private void ms_dri2_del_frame_event(ms_dri2_frame_event_rec* info)
{
    xorg_list_del(&info.client_resource);
    xorg_list_del(&info.drawable_resource);

    if (info.front)
        ms_dri2_destroy_buffer(null, info.front);
    if (info.back)
        ms_dri2_destroy_buffer(null, info.back);

    free(info);
}

private void ms_dri2_blit_swap(DrawablePtr drawable, DRI2BufferPtr dst, DRI2BufferPtr src)
{
    BoxRec box = void;
    RegionRec region = void;

    box.x1 = 0;
    box.y1 = 0;
    box.x2 = drawable.width;
    box.y2 = drawable.height;
    mixin(REGION_INIT!("pScreen", "&region", "&box", "0") ~";");

    ms_dri2_copy_region(drawable, &region, dst, src);
}

struct ms_dri2_vblank_event {
    XID drawable_id;
    ClientPtr client;
    DRI2SwapEventPtr event_complete;
    void* event_data;
}

private void ms_dri2_flip_abort(modesettingPtr ms, void* data)
{
    ms_present_vblank_event* event = cast(ms_present_vblank_event*)data;

    ms.drmmode.dri2_flipping = FALSE;
    free(event);
}

private void ms_dri2_flip_handler(modesettingPtr ms, ulong msc, ulong ust, void* data)
{
    ms_dri2_vblank_event* event = cast(ms_dri2_vblank_event*)data;
    uint frame = cast(uint)msc;
    uint tv_sec = cast(uint)(ust / 1000000);
    uint tv_usec = cast(uint)(ust % 1000000);
    DrawablePtr drawable = void;
    int status = void;

    status = dixLookupDrawable(&drawable, event.drawable_id, serverClient,
                               M_ANY, DixWriteAccess);
    if (status == Success)
        DRI2SwapComplete(event.client, drawable, frame, tv_sec, tv_usec,
                         DRI2_FLIP_COMPLETE, event.event_complete,
                         event.event_data);

    ms.drmmode.dri2_flipping = FALSE;
    free(event);
}

private Bool ms_dri2_schedule_flip(ms_dri2_frame_event_ptr info)
{
    DrawablePtr draw = info.drawable;
    ScreenPtr screen = draw.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    ms_dri2_buffer_private_ptr back_priv = cast(ms_dri2_buffer_private_ptr)info.back.driverPrivate;
    ms_dri2_vblank_event* event = void;

    event = cast(ms_dri2_vblank_event*) cast(ms_dri2_vblank_event*) calloc(1, ms_dri2_vblank_event.sizeof);
    if (!event)
        return FALSE;

    event.drawable_id = draw.id;
    event.client = info.client;
    event.event_complete = info.event_complete;
    event.event_data = info.event_data;

    if (ms_do_pageflip(screen, back_priv.pixmap, event,
                       info.crtc, FALSE,
                       &ms_dri2_flip_handler,
                       &ms_dri2_flip_abort,
                       "DRI2-flip")) {
        ms.drmmode.dri2_flipping = TRUE;
        return TRUE;
    }
    return FALSE;
}

private Bool update_front(DrawablePtr draw, DRI2BufferPtr front)
{
    ScreenPtr screen = draw.pScreen;
    PixmapPtr pixmap = get_drawable_pixmap(draw);
    ms_dri2_buffer_private_ptr priv = cast(ms_dri2_buffer_private_ptr)front.driverPrivate;
    modesettingPtr ms = mixin(modesettingPTR!("xf86ScreenToScrn(screen)"));
    CARD32 size = void;
    CARD16 pitch = void;
    int name = void;

    name = ms.glamor.name_from_pixmap(pixmap, &pitch, &size);
    if (name < 0)
        return FALSE;

    front.name = name;

    dixDestroyPixmap(priv.pixmap, 0);
    front.pitch = pixmap.devKind;
    front.cpp = pixmap.drawable.bitsPerPixel / 8;
    priv.pixmap = pixmap;
    pixmap.refcnt++;

    return TRUE;
}

private Bool can_exchange(ScrnInfoPtr scrn, DrawablePtr draw, DRI2BufferPtr front, DRI2BufferPtr back)
{
    ms_dri2_buffer_private_ptr front_priv = cast(ms_dri2_buffer_private_ptr)front.driverPrivate;
    ms_dri2_buffer_private_ptr back_priv = cast(ms_dri2_buffer_private_ptr)back.driverPrivate;
    PixmapPtr front_pixmap = void;
    PixmapPtr back_pixmap = back_priv.pixmap;
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int num_crtcs_on = 0;
    int i = void;

    for (i = 0; i < config.num_crtc; i++) {
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) config.crtc[i].driver_private;

        /* Don't do pageflipping if CRTCs are rotated. */
        if (drmmode_crtc.rotate_bo)
            return FALSE;

        if (xf86_crtc_on(config.crtc[i]))
            num_crtcs_on++;
    }

    /* We can't do pageflipping if all the CRTCs are off. */
    if (num_crtcs_on == 0)
        return FALSE;

    if (!update_front(draw, front))
        return FALSE;

    front_pixmap = front_priv.pixmap;

    if (front_pixmap.drawable.width != back_pixmap.drawable.width)
        return FALSE;

    if (front_pixmap.drawable.height != back_pixmap.drawable.height)
        return FALSE;

    if (front_pixmap.drawable.bitsPerPixel !=
        back_pixmap.drawable.bitsPerPixel)
        return FALSE;

    if (front_pixmap.devKind != back_pixmap.devKind)
        return FALSE;

    return TRUE;
}

private Bool can_flip(ScrnInfoPtr scrn, DrawablePtr draw, DRI2BufferPtr front, DRI2BufferPtr back)
{
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    return draw.type == DRAWABLE_WINDOW &&
        ms.drmmode.pageflip &&
        !ms.drmmode.sprites_visible &&
        !ms.drmmode.present_flipping &&
        scrn.vtSema &&
        DRI2CanFlip(draw) && can_exchange(scrn, draw, front, back);
}

private void ms_dri2_exchange_buffers(DrawablePtr draw, DRI2BufferPtr front, DRI2BufferPtr back)
{
    ms_dri2_buffer_private_ptr front_priv = cast(ms_dri2_buffer_private_ptr)front.driverPrivate;
    ms_dri2_buffer_private_ptr back_priv = cast(ms_dri2_buffer_private_ptr)back.driverPrivate;
    ScreenPtr screen = draw.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    msPixmapPrivPtr front_pix = mixin(msGetPixmapPriv!("&ms.drmmode", "front_priv.pixmap"));
    msPixmapPrivPtr back_pix = mixin(msGetPixmapPriv!("&ms.drmmode", "back_priv.pixmap"));
    msPixmapPrivRec tmp_pix = void;
    RegionRec region = void;
    int tmp = void;

    /* Swap BO names so DRI works */
    tmp = front.name;
    front.name = back.name;
    back.name = tmp;

    /* Swap pixmap privates */
    tmp_pix = *front_pix;
    *front_pix = *back_pix;
    *back_pix = tmp_pix;

    ms.glamor.egl_exchange_buffers(front_priv.pixmap, back_priv.pixmap);

    /* Post damage on the front buffer so that listeners, such
     * as DisplayLink know take a copy and shove it over the USB.
     */
    region.extents.x1 = region.extents.y1 = 0;
    region.extents.x2 = front_priv.pixmap.drawable.width;
    region.extents.y2 = front_priv.pixmap.drawable.height;
    region.data = null;
    DamageRegionAppend(&front_priv.pixmap.drawable, &region);
    DamageRegionProcessPending(&front_priv.pixmap.drawable);
}

private void ms_dri2_frame_event_handler(ulong msc, ulong usec, void* data)
{
    ms_dri2_frame_event_ptr frame_info = cast(ms_dri2_frame_event_ptr)data;
    DrawablePtr drawable = frame_info.drawable;
    ScreenPtr screen = frame_info.screen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    uint tv_sec = cast(uint)(usec / 1000000);
    uint tv_usec = cast(uint)(usec % 1000000);

    if (!drawable) {
        ms_dri2_del_frame_event(frame_info);
        return;
    }

    switch (frame_info.type) {
    case MS_DRI2_QUEUE_FLIP:
        if (can_flip(scrn, drawable, frame_info.front, frame_info.back) &&
            ms_dri2_schedule_flip(frame_info)) {
            ms_dri2_exchange_buffers(drawable, frame_info.front, frame_info.back);
            break;
        }
        goto case;
        /* else fall through to blit */
    case MS_DRI2_QUEUE_SWAP:
        ms_dri2_blit_swap(drawable, frame_info.front, frame_info.back);
        DRI2SwapComplete(frame_info.client, drawable, cast(int)msc, tv_sec, tv_usec,
                         DRI2_BLIT_COMPLETE,
                         frame_info.client ? frame_info.event_complete : null,
                         frame_info.event_data);
        break;

    case MS_DRI2_WAIT_MSC:
        if (frame_info.client)
            DRI2WaitMSCComplete(frame_info.client, drawable,
                                cast(int)msc, tv_sec, tv_usec);
        break;

    default:
        xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                   "%s: unknown vblank event (type %d) received\n", __FUNCTION__.ptr,
                   frame_info.type);
        break;
    }

    ms_dri2_del_frame_event(frame_info);
}

private void ms_dri2_frame_event_abort(void* data)
{
    ms_dri2_frame_event_ptr frame_info = cast(ms_dri2_frame_event_ptr)data;

    ms_dri2_del_frame_event(frame_info);
}

/**
 * Request a DRM event when the requested conditions will be satisfied.
 *
 * We need to handle the event and ask the server to wake up the client when
 * we receive it.
 */
private int ms_dri2_schedule_wait_msc(ClientPtr client, DrawablePtr draw, CARD64 target_msc, CARD64 divisor, CARD64 remainder)
{
    ScreenPtr screen = draw.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    ms_dri2_frame_event_ptr wait_info = void;
    int ret = void;
    xf86CrtcPtr crtc = ms_dri2_crtc_covering_drawable(draw);
    CARD64 current_msc = void, current_ust = void, request_msc = void;
    uint seq = void;
    ulong queued_msc = void;

    /* Drawable not visible, return immediately */
    if (!crtc)
        goto out_complete;

    wait_info = cast(ms_dri2_frame_event_ptr)calloc(1, ms_dri2_frame_event.sizeof);
    if (!wait_info)
        goto out_complete;

    wait_info.screen = screen;
    wait_info.drawable = draw;
    wait_info.client = client;
    wait_info.type = MS_DRI2_WAIT_MSC;

    if (!ms_dri2_add_frame_event(wait_info)) {
        free(wait_info);
        wait_info = null;
        goto out_complete;
    }

    /* Get current count */
    ret = ms_get_crtc_ust_msc(crtc, &current_ust, &current_msc);

    /*
     * If divisor is zero, or current_msc is smaller than target_msc,
     * we just need to make sure target_msc passes  before waking up the
     * client.
     */
    if (divisor == 0 || current_msc < target_msc) {
        /* If target_msc already reached or passed, set it to
         * current_msc to ensure we return a reasonable value back
         * to the caller. This keeps the client from continually
         * sending us MSC targets from the past by forcibly updating
         * their count on this call.
         */
        seq = ms_drm_queue_alloc(crtc, wait_info,
                                 &ms_dri2_frame_event_handler,
                                 &ms_dri2_frame_event_abort);
        if (!seq)
            goto out_free;

        if (current_msc >= target_msc)
            target_msc = current_msc;

        ret = ms_queue_vblank(crtc, MS_QUEUE_ABSOLUTE, target_msc, &queued_msc, seq);
        if (!ret) {
            static int limit = 5;
            if (limit) {
                xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                           "%s:%d get vblank counter failed: %s\n",
                           __FUNCTION__.ptr, __LINE__,
                           strerror(errno));
                limit--;
            }
            goto out_free;
        }

        wait_info.frame = cast(int)queued_msc;
        DRI2BlockClient(client, draw);
        return TRUE;
    }

    /*
     * If we get here, target_msc has already passed or we don't have one,
     * so we queue an event that will satisfy the divisor/remainder equation.
     */
    request_msc = current_msc - (current_msc % divisor) +
        remainder;
    /*
     * If calculated remainder is larger than requested remainder,
     * it means we've passed the last point where
     * seq % divisor == remainder, so we need to wait for the next time
     * that will happen.
     */
    if ((current_msc % divisor) >= remainder)
        request_msc += divisor;

    seq = ms_drm_queue_alloc(crtc, wait_info,
                             &ms_dri2_frame_event_handler,
                             &ms_dri2_frame_event_abort);
    if (!seq)
        goto out_free;

    if (!ms_queue_vblank(crtc, MS_QUEUE_ABSOLUTE, request_msc, &queued_msc, seq)) {
        static int limit = 5;
        if (limit) {
            xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                       "%s:%d get vblank counter failed: %s\n",
                       __FUNCTION__.ptr, __LINE__,
                       strerror(errno));
            limit--;
        }
        goto out_free;
    }

    wait_info.frame = cast(int)queued_msc;

    DRI2BlockClient(client, draw);

    return TRUE;

 out_free:
    ms_dri2_del_frame_event(wait_info);
 out_complete:
    DRI2WaitMSCComplete(client, draw, cast(int)target_msc, 0, 0);
    return TRUE;
}

/**
 * ScheduleSwap is responsible for requesting a DRM vblank event for
 * the appropriate frame, or executing the swap immediately if it
 * doesn't need to wait.
 *
 * When the swap is complete, the driver should call into the server so it
 * can send any swap complete events that have been requested.
 */
private int ms_dri2_schedule_swap(ClientPtr client, DrawablePtr draw, DRI2BufferPtr front, DRI2BufferPtr back, CARD64* target_msc, CARD64 divisor, CARD64 remainder, DRI2SwapEventPtr func, void* data)
{
    ScreenPtr screen = draw.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    int ret = void, flip = 0;
    xf86CrtcPtr crtc = ms_dri2_crtc_covering_drawable(draw);
    ms_dri2_frame_event_ptr frame_info = null;
    ulong current_msc = void, current_ust = void;
    ulong request_msc = void;
    uint seq = void;
    ms_queue_flag ms_flag = MS_QUEUE_ABSOLUTE;
    ulong queued_msc = void;

    /* Drawable not displayed... just complete the swap */
    if (!crtc)
        goto blit_fallback;

    frame_info = cast(ms_dri2_frame_event_ptr)calloc(1, ms_dri2_frame_event.sizeof);
    if (!frame_info)
        goto blit_fallback;

    frame_info.screen = screen;
    frame_info.drawable = draw;
    frame_info.client = client;
    frame_info.event_complete = func;
    frame_info.event_data = data;
    frame_info.front = front;
    frame_info.back = back;
    frame_info.crtc = crtc;
    frame_info.type = MS_DRI2_QUEUE_SWAP;

    if (!ms_dri2_add_frame_event(frame_info)) {
        free(frame_info);
        frame_info = null;
        goto blit_fallback;
    }

    ms_dri2_reference_buffer(front);
    ms_dri2_reference_buffer(back);

    ret = ms_get_crtc_ust_msc(crtc, &current_ust, &current_msc);
    if (ret != Success)
        goto blit_fallback;

    /* Flips need to be submitted one frame before */
    if (can_flip(scrn, draw, front, back)) {
        frame_info.type = MS_DRI2_QUEUE_FLIP;
        flip = 1;
    }

    /* Correct target_msc by 'flip' if frame_info->type == MS_DRI2_QUEUE_FLIP.
     * Do it early, so handling of different timing constraints
     * for divisor, remainder and msc vs. target_msc works.
     */
    if (*target_msc > 0)
        *target_msc -= flip;

    /* If non-pageflipping, but blitting/exchanging, we need to use
     * DRM_VBLANK_NEXTONMISS to avoid unreliable timestamping later
     * on.
     */
    if (flip == 0)
        ms_flag |= MS_QUEUE_NEXT_ON_MISS;

    /*
     * If divisor is zero, or current_msc is smaller than target_msc
     * we just need to make sure target_msc passes before initiating
     * the swap.
     */
    if (divisor == 0 || current_msc < *target_msc) {

        /* If target_msc already reached or passed, set it to
         * current_msc to ensure we return a reasonable value back
         * to the caller. This makes swap_interval logic more robust.
         */
        if (current_msc >= *target_msc)
            *target_msc = current_msc;

        seq = ms_drm_queue_alloc(crtc, frame_info,
                                 &ms_dri2_frame_event_handler,
                                 &ms_dri2_frame_event_abort);
        if (!seq)
            goto blit_fallback;

        if (!ms_queue_vblank(crtc, ms_flag, *target_msc, &queued_msc, seq)) {
            xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                       "divisor 0 get vblank counter failed: %s\n",
                       strerror(errno));
            goto blit_fallback;
        }

        *target_msc = cast(int)(queued_msc + flip);
        frame_info.frame = cast(int)*target_msc;

        return TRUE;
    }

    /*
     * If we get here, target_msc has already passed or we don't have one,
     * and we need to queue an event that will satisfy the divisor/remainder
     * equation.
     */

    request_msc = current_msc - (current_msc % divisor) +
        remainder;

    /*
     * If the calculated deadline vbl.request.sequence is smaller than
     * or equal to current_msc, it means we've passed the last point
     * when effective onset frame seq could satisfy
     * seq % divisor == remainder, so we need to wait for the next time
     * this will happen.

     * This comparison takes the DRM_VBLANK_NEXTONMISS delay into account.
     */
    if (request_msc <= current_msc)
        request_msc += divisor;

    seq = ms_drm_queue_alloc(crtc, frame_info,
                             &ms_dri2_frame_event_handler,
                             &ms_dri2_frame_event_abort);
    if (!seq)
        goto blit_fallback;

    /* Account for 1 frame extra pageflip delay if flip > 0 */
    if (!ms_queue_vblank(crtc, ms_flag, request_msc - flip, &queued_msc, seq)) {
        xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                   "final get vblank counter failed: %s\n",
                   strerror(errno));
        goto blit_fallback;
    }

    /* Adjust returned value for 1 fame pageflip offset of flip > 0 */
    *target_msc = queued_msc + flip;
    frame_info.frame = cast(int)(*target_msc);

    return TRUE;

 blit_fallback:
    ms_dri2_blit_swap(draw, front, back);
    DRI2SwapComplete(client, draw, 0, 0, 0, DRI2_BLIT_COMPLETE, func, data);
    if (frame_info)
        ms_dri2_del_frame_event(frame_info);
    *target_msc = 0; /* offscreen, so zero out target vblank count */
    return TRUE;
}

private int ms_dri2_frame_event_client_gone(void* data, XID id)
{
    ms_dri2_resource* resource = cast(ms_dri2_resource*)data;

    while (!xorg_list_is_empty(&resource.list)) {
        ms_dri2_frame_event_ptr info = mixin(xorg_list_first_entry!("&resource.list",
                                  "ms_dri2_frame_event_rec",
                                  "client_resource"));

        xorg_list_del(&info.client_resource);
        info.client = null;
    }
    free(resource);

    return Success;
}

private int ms_dri2_frame_event_drawable_gone(void* data, XID id)
{
    ms_dri2_resource* resource = cast(ms_dri2_resource*)data;

    while (!xorg_list_is_empty(&resource.list)) {
        ms_dri2_frame_event_ptr info = mixin(xorg_list_first_entry!("&resource.list",
                                  "ms_dri2_frame_event_rec",
                                  "drawable_resource"));

        xorg_list_del(&info.drawable_resource);
        info.drawable = null;
    }
    free(resource);

    return Success;
}

private Bool ms_dri2_register_frame_event_resource_types()
{
    frame_event_client_type =
        CreateNewResourceType(&ms_dri2_frame_event_client_gone,
                              "Frame Event Client");
    if (!frame_event_client_type)
        return FALSE;

    frame_event_drawable_type =
        CreateNewResourceType(&ms_dri2_frame_event_drawable_gone,
                              "Frame Event Drawable");
    if (!frame_event_drawable_type)
        return FALSE;

    return TRUE;
}

Bool ms_dri2_screen_init(ScreenPtr screen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    DRI2InfoRec info = void;
    const(char)*[2] driver_names = [ null, null ];

    if (!ms.glamor.supports_pixmap_import_export(screen)) {
        xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                   "DRI2: glamor lacks support for pixmap import/export\n");
    }

    if (!xf86LoaderCheckSymbol("DRI2Version"))
        return FALSE;

    if (!dixRegisterPrivateKey(&ms_dri2_client_key,
                               PRIVATE_CLIENT, XID.sizeof))
        return FALSE;

    if (serverGeneration != ms_dri2_server_generation) {
        ms_dri2_server_generation = serverGeneration;
        if (!ms_dri2_register_frame_event_resource_types()) {
            xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                       "Cannot register DRI2 frame event resources\n");
            return FALSE;
        }
    }

    memset(&info, '\0', info.sizeof);
    info.fd = ms.fd;
    info.driverName = null; /* Compat field, unused. */
    info.deviceName = drmGetDeviceNameFromFd(ms.fd);

    info.version_ = 9;
    info.CreateBuffer = &ms_dri2_create_buffer;
    info.DestroyBuffer = &ms_dri2_destroy_buffer;
    info.CopyRegion = &ms_dri2_copy_region;
    info.ScheduleSwap = &ms_dri2_schedule_swap;
    info.GetMSC = &ms_dri2_get_msc;
    info.ScheduleWaitMSC = &ms_dri2_schedule_wait_msc;
    info.CreateBuffer2 = &ms_dri2_create_buffer2;
    info.DestroyBuffer2 = &ms_dri2_destroy_buffer2;
    info.CopyRegion2 = &ms_dri2_copy_region2;

    /* Ask Glamor to obtain the DRI driver name via EGL_MESA_query_driver, */
    if (ms.glamor.egl_get_driver_name)
        driver_names[0] = ms.glamor.egl_get_driver_name(screen);

    if (driver_names[0]) {
        /* There is no VDPAU driver for Intel, fallback to the generic
         * OpenGL/VAAPI va_gl backend to emulate VDPAU.  Otherwise,
         * guess that the DRI and VDPAU drivers have the same name.
         */
        if (strcmp(driver_names[0], "i965") == 0 ||
            strcmp(driver_names[0], "iris") == 0 ||
            strcmp(driver_names[0], "crocus") == 0) {
            driver_names[1] = "va_gl";
        } else {
            driver_names[1] = driver_names[0];
        }

        info.numDrivers = 2;
        info.driverNames = driver_names.ptr;
    } else {
        /* EGL_MESA_query_driver was unavailable; let dri2.c select the
         * driver and fill in these fields for us.
         */
        info.numDrivers = 0;
        info.driverNames = null;
    }

    return DRI2ScreenInit(screen, &info);
}

void ms_dri2_close_screen(ScreenPtr screen)
{
    DRI2CloseScreen(screen);
}

} /* GLAMOR */
