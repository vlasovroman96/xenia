module hw.xfree86.drivers.video.modesetting.present;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2014 Intel Corporation
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */

import build.dix_config;

import core.stdc.assert_;
import core.stdc.errno;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.stdc.stdio;
import core.stdc.stdint;
import core.stdc.string;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.time;
import core.sys.posix.sys.types;
import core.stdc.time;
import pageflip;
import externs.X11.extensions.dpmsconst;

import include.present;

import include.xf86;
import include.xf86Crtc;
import externs.libdrm;
import include.xf86str;

import hw.xfree86.drivers.video.modesetting.driver;
import hw.xfree86.drivers.video.modesetting.drmmode_display;
import hw.xfree86.drivers.video.modesetting.vblank;
import hw.xfree86.common.xf86Helper;
import xf86Globals;
import externs.X11.extensions.presenttokens;
import hw.xfree86.modes.xf86Crtc;
import present.present_screen;


version (none) {
enum string DebugPresent(string x) = `ErrorF x = void;`;
} else {
//#define DebugPresent(x)
}

struct ms_present_vblank_event {
    ulong event_id;
    Bool unflip;
}

private RRCrtcPtr ms_present_get_crtc(WindowPtr window)
{
    return ms_randr_crtc_covering_drawable(&window.drawable);
}

private int ms_present_get_ust_msc(RRCrtcPtr crtc, CARD64* ust, CARD64* msc)
{
    xf86CrtcPtr xf86_crtc = cast(xf86CrtcPtr)crtc.devPrivate;

    return ms_get_crtc_ust_msc(xf86_crtc, ust, msc);
}

/*
 * Changes the variable refresh state for every CRTC on the screen.
 */
void ms_present_set_screen_vrr(ScrnInfoPtr scrn, Bool vrr_enabled)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    xf86CrtcPtr crtc = void;
    int i = void;

    for (i = 0; i < config.num_crtc; i++) {
        crtc = config.crtc[i];
        drmmode_crtc_set_vrr(crtc, vrr_enabled);
    }
}

/*
 * Called when the queued vblank event has occurred
 */
private void ms_present_vblank_handler(ulong msc, ulong usec, void* data)
{
    ms_present_vblank_event* event = cast(ms_present_vblank_event*)data;

    // DebugPresent(("\t\tmh %lld msc %llu\n",
    //              cast(long) event.event_id, cast(long) msc));

    present_event_notify(event.event_id, usec, msc);
    free(event);
}

/*
 * Called when the queued vblank is aborted
 */
private void ms_present_vblank_abort(void* data)
{
    ms_present_vblank_event* event = cast(ms_present_vblank_event*)data;

    // DebugPresent(("\t\tma %lld\n", cast(long) event.event_id));

    free(event);
}

/*
 * Queue an event to report back to the Present extension when the specified
 * MSC has past
 */
private int ms_present_queue_vblank(RRCrtcPtr crtc, ulong event_id, ulong msc)
{
    xf86CrtcPtr xf86_crtc = cast(xf86CrtcPtr)crtc.devPrivate;
    ms_present_vblank_event* event = void;
    uint seq = void;

    event = cast(ms_present_vblank_event*) cast(ms_present_vblank_event*) calloc(1, ms_present_vblank_event.sizeof);
    if (!event)
        return BadAlloc;
    event.event_id = event_id;
    seq = ms_drm_queue_alloc(xf86_crtc, event,
                             &ms_present_vblank_handler,
                             &ms_present_vblank_abort);
    if (!seq) {
        free(event);
        return BadAlloc;
    }

    if (!ms_queue_vblank(xf86_crtc, MS_QUEUE_ABSOLUTE, msc, null, seq))
        return BadAlloc;

    // DebugPresent(("\t\tmq %lld seq %u msc %llu\n",
    //              cast(long) event_id, seq, cast(long) msc));
    return Success;
}

private Bool ms_present_event_match(void* data, void* match_data)
{
    ms_present_vblank_event* event = cast(ms_present_vblank_event*)data;
    ulong* match = cast(ulong*)match_data;

    return *match == event.event_id;
}

/*
 * Remove a pending vblank event from the DRM queue so that it is not reported
 * to the extension
 */
private void ms_present_abort_vblank(RRCrtcPtr crtc, ulong event_id, ulong msc)
{
    ScreenPtr screen = crtc.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
static if (GLAMOR) {
    xf86CrtcPtr xf86_crtc = cast(xf86CrtcPtr)crtc.devPrivate;

    /* Check if this is a fake flip routed through TearFree and abort it */
    if (ms_tearfree_dri_abort(xf86_crtc, &ms_present_event_match, &event_id))
        return;
}

    ms_drm_abort(scrn, &ms_present_event_match, &event_id);
}

/*
 * Flush our batch buffer when requested by the Present extension.
 */
private void ms_present_flush(WindowPtr window)
{
static if (GLAMOR) {
    ScreenPtr screen = window.drawable.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    if (ms.drmmode.glamor)
        ms.glamor.block_handler(screen);
}
}

static if (GLAMOR) {

/**
 * Callback for the DRM event queue when a flip has completed on all pipes
 *
 * Notify the extension code
 */
private void ms_present_flip_handler(modesettingPtr ms, ulong msc, ulong ust, void* data)
{
    ms_present_vblank_event* event = cast(ms_present_vblank_event*)data;
// 
    // DebugPresent(("\t\tms:fc %lld msc %llu ust %llu\n",
                //   cast(long) event.event_id,
                //   cast(long) msc, cast(long) ust));

    if (event.unflip)
        ms.drmmode.present_flipping = FALSE;

    ms_present_vblank_handler(msc, ust, event);
}

/*
 * Callback for the DRM queue abort code.  A flip has been aborted.
 */
private void ms_present_flip_abort(modesettingPtr ms, void* data)
{
    ms_present_vblank_event* event = cast(ms_present_vblank_event*)data;

    // DebugPresent(("\t\tms:fa %lld\n", cast(long) event.event_id));

    free(event);
}

/*
 * Test to see if page flipping is possible on the target crtc
 *
 * We ignore sw-cursors when *disabling* flipping, we may very well be
 * returning to scanning out the normal framebuffer *because* we just
 * switched to sw-cursor mode and check_flip just failed because of that.
 */
private Bool ms_present_check_unflip(RRCrtcPtr crtc, WindowPtr window, PixmapPtr pixmap, Bool sync_flip, PresentFlipReason* reason)
{
    ScreenPtr screen = window.drawable.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int num_crtcs_on = 0;
    int i = void;
    gbm_bo* gbm = void;

    if (!ms.drmmode.pageflip)
        return FALSE;

    if (ms.drmmode.dri2_flipping)
        return FALSE;

    if (!scrn.vtSema)
        return FALSE;

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

    /*
     * Check stride, can't change that reliably on flip on some drivers, unless
     * the kms driver is atomic_modeset_capable.
     */
    if (!ms.atomic_modeset_capable &&
        pixmap.devKind != gbm_bo_get_stride(ms.drmmode.front_bo))
        return FALSE;

    if (!ms.drmmode.glamor)
        return FALSE;

static if (GBM_BO_WITH_MODIFIERS) {
    /* Check if buffer format/modifier is supported by all active CRTCs */
    gbm = ms.glamor.gbm_bo_from_pixmap(screen, pixmap);
    if (gbm) {
        uint format = void;
        ulong modifier = void;

        format = gbm_bo_get_format(gbm);
        modifier = gbm_bo_get_modifier(gbm);
        gbm_bo_destroy(gbm);

        if (!drmmode_is_format_supported(scrn, format, modifier, !sync_flip)) {
            if (reason)
                *reason = PRESENT_FLIP_REASON_BUFFER_FORMAT;
            return FALSE;
        }
    }
}

    /* Make sure there's a bo we can get to */
    /* XXX: actually do this.  also...is it sufficient?
     * if (!glamor_get_pixmap_private(pixmap))
     *     return FALSE;
     */

    return TRUE;
}

private Bool ms_present_check_flip(RRCrtcPtr crtc, WindowPtr window, PixmapPtr pixmap, Bool sync_flip, PresentFlipReason* reason)
{
    ScreenPtr screen = window.drawable.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    Bool async_flip = !sync_flip;

    if (reason)
        *reason = PRESENT_FLIP_REASON_UNKNOWN;

    if (ms.drmmode.sprites_visible > 0)
        goto no_flip;

    if (ms.drmmode.pending_modeset)
        goto no_flip;

    /**
     * Does the window match the pixmap exactly?
     *
     * We need to check here too, despite also
     * checking in the generic present check_flip,
     * because we need to be able to give info
     * about tearfree, even if we can't flip.
     *
     * See: https://github.com/X11Libre/xserver/issues/1812
     * See: https://github.com/X11Libre/xserver/issues/1754
     */
    if (window.drawable.x != 0 || window.drawable.y != 0 ||
        window.drawable.x != pixmap.screen_x || window.drawable.y != pixmap.screen_y ||
        window.drawable.width != pixmap.drawable.width ||
        window.drawable.height != pixmap.drawable.height) {
        goto no_flip;
    }

    if (!ms_present_check_unflip(crtc, window, pixmap, sync_flip, reason)) {
        if (reason && *reason == PRESENT_FLIP_REASON_BUFFER_FORMAT)
            ms_window_update_async_flip(window, async_flip);
        goto no_flip;
    }

    ms_window_update_async_flip(window, async_flip);

    /*
     * Force a format renegotiation when switching between sync and async,
     * otherwise we may end up with a working but suboptimal modifier.
     */
    if (reason && async_flip != ms_window_has_async_flip_modifiers(window)) {
        *reason = PRESENT_FLIP_REASON_BUFFER_FORMAT;
        goto no_flip;
    }

    ms.flip_window = window;

    return TRUE;

no_flip:
    /* Export some info about TearFree if Present can't flip anyway */
    if (reason && *reason == PRESENT_FLIP_REASON_UNKNOWN) {
        xf86CrtcPtr xf86_crtc = cast(xf86CrtcPtr)crtc.devPrivate;
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) xf86_crtc.driver_private;
        drmmode_tearfree_ptr trf = &drmmode_crtc.tearfree;

        if (ms_tearfree_is_active_on_crtc(xf86_crtc)) {
            if (trf.flip_seq)
                /* The driver has a TearFree flip pending */
                *reason = PRESENT_FLIP_REASON_DRIVER_TEARFREE_FLIPPING;
            else
                /* The driver uses TearFree flips and there's no flip pending */
                *reason = PRESENT_FLIP_REASON_DRIVER_TEARFREE;
        }
    }
    return FALSE;
}

/*
 * Queue a flip on 'crtc' to 'pixmap' at 'target_msc'. If 'sync_flip' is true,
 * then wait for vblank. Otherwise, flip immediately
 */
private Bool ms_present_flip(RRCrtcPtr crtc, ulong event_id, ulong target_msc, PixmapPtr pixmap, Bool sync_flip)
{
    ScreenPtr screen = crtc.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    xf86CrtcPtr xf86_crtc = cast(xf86CrtcPtr)crtc.devPrivate;
    Bool ret = void;
    ms_present_vblank_event* event = void;

    /* A NULL pixmap means this is a fake flip to be routed through TearFree */
    if (pixmap &&
        !ms_present_check_flip(crtc, ms.flip_window, pixmap, sync_flip, null))
        return FALSE;

    event = cast(ms_present_vblank_event*) cast(ms_present_vblank_event*) calloc(1, ms_present_vblank_event.sizeof);
    if (!event)
        return FALSE;

    // DebugPresent(("\t\tms:pf %lld msc %llu\n",
                //   cast(long) event_id, cast(long) target_msc));

    event.event_id = event_id;
    event.unflip = FALSE;

    /* Register the fake flip (indicated by a NULL pixmap) with TearFree */
    if (!pixmap)
        return ms_do_pageflip(screen, null, event, xf86_crtc, FALSE,
                              &ms_present_flip_handler, &ms_present_flip_abort,
                              "Present-TearFree-flip");

    /* A window can only flip if it covers the entire X screen.
     * Only one window can flip at a time.
     *
     * If the window also has the variable refresh property then
     * variable refresh supported can be enabled on every CRTC.
     */
    if (ms.vrr_support && ms.is_connector_vrr_capable &&
          ms_window_has_variable_refresh(ms, ms.flip_window)) {
        ms_present_set_screen_vrr(scrn, TRUE);
    }

    ret = ms_do_pageflip(screen, pixmap, event, xf86_crtc, !sync_flip,
                         &ms_present_flip_handler, &ms_present_flip_abort,
                         "Present-flip");
    if (ret)
        ms.drmmode.present_flipping = TRUE;

    return ret;
}

/*
 * Queue a flip back to the normal frame buffer
 */
private void ms_present_unflip(ScreenPtr screen, ulong event_id)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    PixmapPtr pixmap = screen.GetScreenPixmap(screen);
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int i = void;

    ms_present_set_screen_vrr(scrn, FALSE);

    if (ms_present_check_unflip(null, screen.root, pixmap, TRUE, null)) {
        ms_present_vblank_event* event = void;

        event = cast(ms_present_vblank_event*) cast(ms_present_vblank_event*) calloc(1, ms_present_vblank_event.sizeof);
        if (!event)
            return;

        event.event_id = event_id;
        event.unflip = TRUE;

        if (ms_do_pageflip(screen, pixmap, event, null, FALSE,
                           &ms_present_flip_handler, &ms_present_flip_abort,
                           "Present-unflip")) {
            return;
        }
    }

    ms.drmmode.present_flipping = FALSE;

    for (i = 0; i < config.num_crtc; i++) {
        xf86CrtcPtr crtc = config.crtc[i];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) crtc.driver_private;

        if (!crtc.enabled)
            continue;

        /* info->drmmode.fb_id still points to the FB for the last flipped BO.
         * Clear it, drmmode_set_mode_major will re-create it
         */
        if (drmmode_crtc.drmmode.fb_id) {
            drmModeRmFB(drmmode_crtc.drmmode.fd, drmmode_crtc.drmmode.fb_id);
            drmmode_crtc.drmmode.fb_id = 0;
        }

        if (drmmode_crtc.dpms_mode == DPMSModeOn)
            crtc.funcs.set_mode_major(crtc, &crtc.mode, crtc.rotation,
                                        crtc.x, crtc.y);
        else
            drmmode_crtc.need_modeset = TRUE;
    }

    present_event_notify(event_id, 0, 0);
}
}

private present_screen_info_rec ms_present_screen_info;

import core.attribute : standalone;
@standalone
@trusted
shared static this()
{
    ms_present_screen_info = present_screen_info_rec(
        version_: PRESENT_SCREEN_INFO_VERSION,

        get_crtc: &ms_present_get_crtc,
        get_ust_msc: &ms_present_get_ust_msc,
        queue_vblank: &ms_present_queue_vblank,
        abort_vblank: &ms_present_abort_vblank,
        flush: &ms_present_flush,

        capabilities: PresentCapabilityNone
    );

    static if (GLAMOR)
    {
        ms_present_screen_info.check_flip = null;
        ms_present_screen_info.check_flip2 = &ms_present_check_flip;
        ms_present_screen_info.flip = &ms_present_flip;
        ms_present_screen_info.unflip = &ms_present_unflip;
    }
}

Bool ms_present_screen_init(ScreenPtr screen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    ulong value = void;
    int ret = void;

enum DRM_CAP_ATOMIC_ASYNC_PAGE_FLIP = 0x15;


    ret = drmGetCap(ms.fd, ms.atomic_modeset ?
                            DRM_CAP_ATOMIC_ASYNC_PAGE_FLIP :
                            DRM_CAP_ASYNC_PAGE_FLIP, &value);
    if (ret == 0 && value == 1) {
        ms_present_screen_info.capabilities |= PresentCapabilityAsync;
        ms.drmmode.can_async_flip = TRUE;
        xf86DrvMsg(screen.myNum, X_INFO, "Async flip capable\n");
    }

    return present_screen_init(screen, &ms_present_screen_info);
}
