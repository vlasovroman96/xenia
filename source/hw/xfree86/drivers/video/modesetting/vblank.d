module hw.xfree86.drivers.video.modesetting.vblank;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Keith Packard
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

/** @file vblank.c
 *
 * Support for tracking the DRM's vblank events.
 */

import build.dix_config;

import core.stdc.errno;
import core.sys.posix.unistd;

import hw.xfree86.common.xf86Crtc;
import hw.xfree86.drivers.video.modesetting.driver;
import hw.xfree86.drivers.video.modesetting.drmmode_display;
import externs.X11.extensions.dpmsconst;
import hw.xfree86.common.xf86Helper;
import externs.libdrm;;
import randr.randr;
import pageflip;
import os.connection;
/**
 * Tracking for outstanding events queued to the kernel.
 *
 * Each list entry is a struct ms_drm_queue, which has a uint32_t
 * value generated from drm_seq that identifies the event and a
 * reference back to the crtc/screen associated with the event.  It's
 * done this way rather than in the screen because we want to be able
 * to drain the list of event handlers that should be called at server
 * regen time, even though we don't close the drm fd and have no way
 * to actually drain the kernel events.
 */
//  alias ms_drm_queue = hw.xfree86.drivers.video.modesetting.driver.ms_drm_queue;
XList ms_drm_queue_;
uint ms_drm_seq;
alias UINT64_MAX = core.stdc.stdint.UINT64_MAX;
void box_intersect(BoxPtr dest, BoxPtr a, BoxPtr b)
{
    dest.x1 = a.x1 > b.x1 ? a.x1 : b.x1;
    dest.x2 = a.x2 < b.x2 ? a.x2 : b.x2;
    if (dest.x1 >= dest.x2) {
        dest.x1 = dest.x2 = dest.y1 = dest.y2 = 0;
        return;
    }

    dest.y1 = a.y1 > b.y1 ? a.y1 : b.y1;
    dest.y2 = a.y2 < b.y2 ? a.y2 : b.y2;
    if (dest.y1 >= dest.y2)
        dest.x1 = dest.x2 = dest.y1 = dest.y2 = 0;
}

void rr_crtc_box(RRCrtcPtr crtc, BoxPtr crtc_box)
{
    if (crtc.mode) {
        crtc_box.x1 = cast(short)(crtc.x);
        crtc_box.y1 = cast(short)(crtc.y);
        switch (crtc.rotation) {
            case RR_Rotate_0:
            case RR_Rotate_180:
            default:
                crtc_box.x2 = cast(short)(crtc.x + crtc.mode.mode.width);
                crtc_box.y2 = cast(short)(crtc.y + crtc.mode.mode.height);
                break;
            case RR_Rotate_90:
            case RR_Rotate_270:
                crtc_box.x2 = cast(short)(crtc.x + crtc.mode.mode.height);
                crtc_box.y2 = cast(short)(crtc.y + crtc.mode.mode.width);
                break;
        }
    } else
        crtc_box.x1 = crtc_box.x2 = crtc_box.y1 = crtc_box.y2 = 0;
}

int box_area(BoxPtr box)
{
    return cast(int)(box.x2 - box.x1) * cast(int)(box.y2 - box.y1);
}

Bool rr_crtc_on(RRCrtcPtr crtc, Bool crtc_is_xf86_hint)
{
    if (!crtc) {
        return FALSE;
    }
    if (crtc_is_xf86_hint && crtc.devPrivate) {
         return xf86_crtc_on(cast(_xf86Crtc*)crtc.devPrivate);
    } else {
        return !!crtc.mode;
    }
}

Bool xf86_crtc_on(xf86CrtcPtr crtc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) crtc.driver_private;

    return crtc.enabled && drmmode_crtc.dpms_mode == DPMSModeOn;
}


/*
 * Return the crtc covering 'box'. If two crtcs cover a portion of
 * 'box', then prefer the crtc with greater coverage.
 */
RRCrtcPtr rr_crtc_covering_box(ScreenPtr pScreen, BoxPtr box, Bool screen_is_xf86_hint)
{
    rrScrPrivPtr pScrPriv = void;
    RROutputPtr primary_output = void;
    RRCrtcPtr crtc = void, best_crtc = void, primary_crtc = void;
    int coverage = void, best_coverage = void;
    int c = void;
    BoxRec crtc_box = void, cover_box = void;

    best_crtc = null;
    best_coverage = 0;

    if (!dixPrivateKeyRegistered(rrPrivKey))
        return null;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (!pScrPriv)
        return null;

    primary_crtc = null;
    primary_output = RRFirstOutput(pScreen);
    if (primary_output)
        primary_crtc = primary_output.crtc;

    for (c = 0; c < pScrPriv.numCrtcs; c++) {
        crtc = pScrPriv.crtcs[c];

        /* If the CRTC is off, treat it as not covering */
        if (!rr_crtc_on(crtc, screen_is_xf86_hint))
            continue;

        rr_crtc_box(crtc, &crtc_box);
        box_intersect(&cover_box, &crtc_box, box);
        coverage = box_area(&cover_box);
        if ((coverage > best_coverage) ||
            (coverage == best_coverage && crtc == primary_crtc)) {
            best_crtc = crtc;
            best_coverage = coverage;
        }
    }

    return best_crtc;
}

private RRCrtcPtr rr_crtc_covering_box_on_secondary(ScreenPtr pScreen, BoxPtr box)
{
    if (!pScreen.isGPU) {
        RRCrtcPtr crtc = null;

        foreach(secondary; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")){
            if (!secondary.is_output_secondary)
                continue;

            crtc = rr_crtc_covering_box(secondary, box, FALSE);
            if (crtc)
                return crtc;
        }
    }

    return null;
}

xf86CrtcPtr ms_dri2_crtc_covering_drawable(DrawablePtr pDraw)
{
    ScreenPtr pScreen = pDraw.pScreen;
    RRCrtcPtr crtc = null;
    BoxRec box = void;

    box.x1 = cast(short)(pDraw.x);
    box.y1 = cast(short)(pDraw.y);
    box.x2 = cast(short)(box.x1 + pDraw.width);
    box.y2 = cast(short)(box.y1 + pDraw.height);

    crtc = rr_crtc_covering_box(pScreen, &box, TRUE);
    if (crtc) {
        return cast(xf86CrtcPtr)crtc.devPrivate;
    }
    return null;
}

RRCrtcPtr ms_randr_crtc_covering_drawable(DrawablePtr pDraw)
{
    ScreenPtr pScreen = pDraw.pScreen;
    RRCrtcPtr crtc = null;
    BoxRec box = void;

    box.x1 = cast(short)(pDraw.x);
    box.y1 = cast(short)(pDraw.y);
    box.x2 = cast(short)(box.x1 + pDraw.width);
    box.y2 = cast(short)(box.y1 + pDraw.height);

    crtc = rr_crtc_covering_box(pScreen, &box, TRUE);
    if (!crtc) {
        crtc = rr_crtc_covering_box_on_secondary(pScreen, &box);
    }
    return crtc;
}

Bool ms_get_kernel_ust_msc(xf86CrtcPtr crtc, ulong* msc, ulong* ust)
{
    ScreenPtr screen = crtc.randr_crtc.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) crtc.driver_private;
    drmVBlank vbl = void;
    int ret = void;

    if (ms.has_queue_sequence || !ms.tried_queue_sequence) {
        ulong ns = void;
        ms.tried_queue_sequence = TRUE;

        ret = drmCrtcGetSequence(ms.fd, drmmode_crtc.mode_crtc.crtc_id,
                                 msc, &ns);
        if (ret != -1 || (errno != ENOTTY && errno != EINVAL)) {
            ms.has_queue_sequence = TRUE;
            if (ret == 0)
                *ust = ns / 1000;
            return ret == 0;
        }
    }
    /* Get current count */
    vbl.request.type = cast(drmVBlankSeqType)(DRM_VBLANK_RELATIVE | drmmode_crtc.vblank_pipe);
    vbl.request.sequence = 0;
    vbl.request.signal = 0;
    ret = drmWaitVBlank(ms.fd, &vbl);
    if (ret) {
        *msc = 0;
        *ust = 0;
        return FALSE;
    } else {
        *msc = vbl.reply.sequence;
        *ust = cast(CARD64) vbl.reply.tval_sec * 1000000 + vbl.reply.tval_usec;
        return TRUE;
    }
}

private void ms_drm_set_seq_msc(uint seq, ulong msc)
{
    foreach(q; ms_drm_queue_.byEntries!ms_drm_queue) {
        if (q.seq == seq) {
            q.msc = msc;
            break;
        }
    }
}

private void ms_drm_set_seq_queued(uint seq, ulong msc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)null;

    foreach(q; ms_drm_queue_.byEntries!ms_drm_queue) {
        if (q.seq == seq) {
            drmmode_crtc = cast(drmmode_crtc_private_rec*)q.crtc.driver_private;
            if (msc < drmmode_crtc.next_msc)
                drmmode_crtc.next_msc = msc;
            q.msc = msc;
            q.kernel_queued = TRUE;
            break;
        }
    }
}

private Bool ms_queue_coalesce(xf86CrtcPtr crtc, uint seq, ulong msc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) crtc.driver_private;

    /* If the next MSC is too late, then this event can't be coalesced */
    if (msc < drmmode_crtc.next_msc)
        return FALSE;

    /* Set the target MSC on this sequence number */
    ms_drm_set_seq_msc(seq, msc);
    return TRUE;
}

Bool ms_queue_vblank(xf86CrtcPtr crtc, ms_queue_flag flags, ulong msc, ulong* msc_queued, uint seq)
{
    ScreenPtr screen = crtc.randr_crtc.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) crtc.driver_private;
    drmVBlank vbl = void;
    int ret = void;

    /* Try coalescing this event into another to avoid event queue exhaustion */
    if (flags == MS_QUEUE_ABSOLUTE && ms_queue_coalesce(crtc, seq, msc))
        return TRUE;

    for (;;) {
        /* Queue an event at the specified sequence */
        if (ms.has_queue_sequence || !ms.tried_queue_sequence) {
            uint drm_flags = 0;
            ulong kernel_queued = void;

            ms.tried_queue_sequence = TRUE;

            if (flags & MS_QUEUE_RELATIVE)
                drm_flags |= DRM_CRTC_SEQUENCE_RELATIVE;
            if (flags & MS_QUEUE_NEXT_ON_MISS)
                drm_flags |= DRM_CRTC_SEQUENCE_NEXT_ON_MISS;

            ret = drmCrtcQueueSequence(ms.fd, drmmode_crtc.mode_crtc.crtc_id,
                                       drm_flags, msc, &kernel_queued, seq);
            if (ret == 0) {
                msc = ms_kernel_msc_to_crtc_msc(crtc, kernel_queued, TRUE);
                ms_drm_set_seq_queued(seq, msc);
                if (msc_queued)
                    *msc_queued = msc;
                ms.has_queue_sequence = TRUE;
                return TRUE;
            }

            if (ret != -1 || (errno != ENOTTY && errno != EINVAL)) {
                ms.has_queue_sequence = TRUE;
                goto check;
            }
        }
        vbl.request.type = cast(drmVBlankSeqType)(DRM_VBLANK_EVENT | drmmode_crtc.vblank_pipe);
        if (flags & MS_QUEUE_RELATIVE)
            vbl.request.type |= DRM_VBLANK_RELATIVE;
        else
            vbl.request.type |= DRM_VBLANK_ABSOLUTE;
        if (flags & MS_QUEUE_NEXT_ON_MISS)
            vbl.request.type |= DRM_VBLANK_NEXTONMISS;

        vbl.request.sequence = cast(uint)msc;
        vbl.request.signal = seq;
        ret = drmWaitVBlank(ms.fd, &vbl);
        if (ret == 0) {
            msc = ms_kernel_msc_to_crtc_msc(crtc, vbl.reply.sequence, FALSE);
            ms_drm_set_seq_queued(seq, msc);
            if (msc_queued)
                *msc_queued = msc;
            return TRUE;
        }
    check:
        if (errno != EBUSY) {
            ms_drm_abort_seq(scrn, seq);
            return FALSE;
        }
        ms_flush_drm_events(screen);
    }
    assert(0);
}

/**
 * Convert a 32-bit or 64-bit kernel MSC sequence number to a 64-bit local
 * sequence number, adding in the high 32 bits, and dealing with 32-bit
 * wrapping if needed.
 */
ulong ms_kernel_msc_to_crtc_msc(xf86CrtcPtr crtc, ulong sequence, Bool is64bit)
{
    drmmode_crtc_private_rec* drmmode_crtc = cast(drmmode_crtc_private_rec*)crtc.driver_private;

    if (!is64bit) {
        /* sequence is provided as a 32 bit value from one of the 32 bit apis,
         * e.g., drmWaitVBlank(), classic vblank events, or pageflip events.
         *
         * Track and handle 32-Bit wrapping, somewhat robust against occasional
         * out-of-order not always monotonically increasing sequence values.
         */
        if (cast(long) sequence < (cast(long) drmmode_crtc.msc_prev - 0x40000000))
            drmmode_crtc.msc_high += 0x100000000L;

        if (cast(long) sequence > (cast(long) drmmode_crtc.msc_prev + 0x40000000))
            drmmode_crtc.msc_high -= 0x100000000L;

        drmmode_crtc.msc_prev = cast(uint)sequence;

        return drmmode_crtc.msc_high + sequence;
    }

    /* True 64-Bit sequence from Linux 4.15+ 64-Bit drmCrtcGetSequence /
     * drmCrtcQueueSequence apis and events. Pass through sequence unmodified,
     * but update the 32-bit tracking variables with reliable ground truth.
     *
     * With 64-Bit api in use, the only !is64bit input is from pageflip events,
     * and any pageflip event is usually preceded by some is64bit input from
     * swap scheduling, so this should provide reliable mapping for pageflip
     * events based on true 64-bit input as baseline as well.
     */
    drmmode_crtc.msc_prev = cast(uint)sequence;
    drmmode_crtc.msc_high = sequence & 0xffffffff00000000;

    return sequence;
}

int ms_get_crtc_ust_msc(xf86CrtcPtr crtc, CARD64* ust, CARD64* msc)
{
    ScreenPtr screen = crtc.randr_crtc.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    ulong kernel_msc = void;

    if (!ms_get_kernel_ust_msc(crtc, &kernel_msc, ust))
        return BadMatch;
    *msc = ms_kernel_msc_to_crtc_msc(crtc, kernel_msc, ms.has_queue_sequence);

    return Success;
}

/**
 * Check for pending DRM events and process them.
 */
private void ms_drm_socket_handler(int fd, int ready, void* data)
{
    if (data is null)
        return;

    ScreenPtr screen = cast(ScreenPtr)data;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    drmHandleEvent(fd, &ms.event_context);
}

/*
 * Enqueue a potential drm response; when the associated response
 * appears, we've got data to pass to the handler from here
 */
uint ms_drm_queue_alloc(xf86CrtcPtr crtc, void* data, ms_drm_handler_proc handler, ms_drm_abort_proc abort)
{
    ScreenPtr screen = crtc.randr_crtc.pScreen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    ms_drm_queue* q = void;

    q = cast(ms_drm_queue*) cast(ms_drm_queue*) calloc(1, ms_drm_queue.sizeof);

    if (!q)
        return 0;
    if (!ms_drm_seq)
        ++ms_drm_seq;
    q.seq = ms_drm_seq++;
    q.msc = UINT64_MAX;
    q.scrn = scrn;
    q.crtc = crtc;
    q.data = data;
    q.handler = handler;
    q.abort = abort;

    /* Keep the list formatted in ascending order of sequence number */
    ms_drm_queue_.appendList(&q.list);

    return q.seq;
}

/**
 * Abort one queued DRM entry, removing it
 * from the list, calling the abort function and
 * freeing the memory
 */
void ms_drm_abort_one(ms_drm_queue* q)
{
    if (q.aborted)
        return;

    /* Don't remove vblank events if they were queued in the kernel */
    if (q.kernel_queued) {
        q.abort(q.data);
        q.aborted = TRUE;
    } else {
        q.list.removeFromList();
        q.abort(q.data);
        free(q);
    }
}

/**
 * Abort all queued entries on a specific scrn, used
 * when resetting the X server
 */
private void ms_drm_abort_scrn(ScrnInfoPtr scrn)
{
    foreach(q; ms_drm_queue_.byEntriesSafe!ms_drm_queue){
        if (q.scrn == scrn)
            ms_drm_abort_one(q);
    }
}

/**
 * Abort by drm queue sequence number.
 */
void ms_drm_abort_seq(ScrnInfoPtr scrn, uint seq)
{
    foreach(q; ms_drm_queue_.byEntriesSafe!ms_drm_queue){
        if (q.seq == seq) {
            ms_drm_abort_one(q);
            break;
        }
    }
}

import externs.attrs;

/*
 * Externally usable abort function that uses a callback to match a single
 * queued entry to abort
 */
void ms_drm_abort(ScrnInfoPtr scrn, Bool function(void* data, void* match_data) match, void* match_data)
{
    foreach(q; ms_drm_queue_.byEntries!ms_drm_queue) {
        if (assumeNoGC(match)(q.data, match_data)) {
            ms_drm_abort_one(q);
            break;
        }
    }
}

/*
 * General DRM kernel handler. Looks for the matching sequence number in the
 * drm event queue and calls the handler for it.
 */
private void ms_drm_sequence_handler(int fd, ulong frame, ulong ns, Bool is64bit, ulong user_data)
{
    uint seq = cast(uint) user_data;
    xf86CrtcPtr crtc = null;
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) null;
    ulong msc = void, next_msc = UINT64_MAX;

    /* Handle the seq for this event first in order to get the CRTC */
    foreach(q; ms_drm_queue_.byEntries!ms_drm_queue) {
        if (q.seq == seq) {
            crtc = q.crtc;
            msc = ms_kernel_msc_to_crtc_msc(crtc, frame, is64bit);
            q.msc = msc;
            break;
        }
    }

    if (!crtc)
        return;

    /* Now run all of the vblank events for this CRTC with an expired MSC */
    foreach(q_; ms_drm_queue_.byEntries!ms_drm_queue) {
        if (q_.crtc == crtc && q_.msc <= msc) {
            q_.list.removeFromList();
            if (!q_.aborted)
                q_.handler(msc, ns / 1000, q_.data);
            free(q_);
        }
    }

    /* Find this CRTC's next queued MSC and next non-queued MSC to be handled */
    msc = UINT64_MAX;
    foreach(q; ms_drm_queue_.byEntries!ms_drm_queue) {
        if (q.crtc == crtc) {
            if (q.kernel_queued) {
                if (q.msc < next_msc)
                    next_msc = q.msc;
            } else if (q.msc < msc) {
                msc = q.msc;
                seq = q.seq;
            }
        }
    }

    /* Queue an event if the next queued MSC isn't soon enough */
    drmmode_crtc = cast(drmmode_crtc_private_rec*)crtc.driver_private;
    drmmode_crtc.next_msc = next_msc;
    if (msc < next_msc && !ms_queue_vblank(crtc, MS_QUEUE_ABSOLUTE, msc, null, seq)) {
        xf86DrvMsg(crtc.scrn.scrnIndex, X_WARNING,
                   "failed to queue next vblank event, aborting lost events\n");
        foreach(q_; ms_drm_queue_.byEntriesSafe!ms_drm_queue){
            if (q_.crtc == crtc && q_.msc < next_msc)
                ms_drm_abort_one(q_);
        }
    }
}

private void ms_drm_sequence_handler_64bit(int fd, ulong frame, ulong ns, ulong user_data)
{
    /* frame is true 64 bit wrapped into 64 bit */
    ms_drm_sequence_handler(fd, frame, ns, TRUE, user_data);
}

private void ms_drm_handler(int fd, uint frame, uint sec, uint usec, void* user_ptr)
{
    /* frame is 32 bit wrapped into 64 bit */
    ms_drm_sequence_handler(fd, frame, (cast(ulong) sec * 1000000 + usec) * 1000,
                            FALSE, cast(uint) cast(uintptr_t) user_ptr);
}

Bool ms_drm_queue_is_empty()
{
    return ms_drm_queue_.isEmpty();
}

Bool ms_vblank_screen_init(ScreenPtr screen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    modesettingEntPtr ms_ent = ms_ent_priv(scrn);
    ms_drm_queue_.initList();

    __traits(getMember, ms.event_context, "version") = 4;
    ms.event_context.vblank_handler = &ms_drm_handler;
    ms.event_context.page_flip_handler = &ms_drm_handler;
    ms.event_context.sequence_handler = &ms_drm_sequence_handler_64bit;

    /* We need to re-register the DRM fd for the synchronisation
     * feedback on every server generation, so perform the
     * registration within ScreenInit and not PreInit.
     */
    if (ms_ent.fd_wakeup_registered != serverGeneration) {
        SetNotifyFd(ms.fd, &ms_drm_socket_handler, X_NOTIFY_READ, screen);
        ms_ent.fd_wakeup_registered = serverGeneration;
        ms_ent.fd_wakeup_ref = 1;
    } else
        ms_ent.fd_wakeup_ref++;

    return TRUE;
}

void ms_vblank_close_screen(ScreenPtr screen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    modesettingEntPtr ms_ent = ms_ent_priv(scrn);

    ms_drm_abort_scrn(scrn);

    if (ms_ent.fd_wakeup_registered == serverGeneration &&
        !--ms_ent.fd_wakeup_ref) {
        RemoveNotifyFd(ms.fd);
    }
}
