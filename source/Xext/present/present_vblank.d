module present.present_vblank;
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
import build.xlibre_server;

import core.sys.posix.unistd;

import present.present_priv;
import include.dri3;
import dix.screen_hooks;
import dix.extension;
import externs.X11.extensions.presenttokens;
import os.log;
import os.connection;
void present_vblank_notify(present_vblank_ptr vblank, CARD8 kind, CARD8 mode, ulong ust, ulong crtc_msc)
{
    int n = void;

    if (vblank.window)
        present_send_complete_notify(vblank.window, kind, mode, vblank.serial, ust, crtc_msc - vblank.msc_offset);
    for (n = 0; n < vblank.num_notifies; n++) {
        WindowPtr window = vblank.notifies[n].window;
        CARD32 serial = vblank.notifies[n].serial;

        if (window)
            present_send_complete_notify(window, kind, mode, serial, ust, crtc_msc - vblank.msc_offset);
    }
}

private Bool present_want_async_flip(uint options, uint capabilities)
{
	if (options & PresentOptionAsync &&
	    capabilities & PresentCapabilityAsync)
		return TRUE;

	if (options & PresentOptionAsyncMayTear &&
	    capabilities & PresentCapabilityAsyncMayTear)
		return TRUE;

	return FALSE;
}

/* The memory vblank points to must be 0-initialized before calling this function.
 *
 * If this function returns FALSE, present_vblank_destroy must be called to clean
 * up.
 */
static if(DRI3) {
Bool present_vblank_init(present_vblank_ptr vblank, WindowPtr window, 
PixmapPtr pixmap, CARD32 serial, 
RegionPtr valid, RegionPtr update, 
short x_off, short y_off, RRCrtcPtr target_crtc, SyncFence* wait_fence, 
SyncFence* idle_fence, 
dri3_syncobj* acquire_syncobj, dri3_syncobj* release_syncobj, 
ulong acquire_point, ulong release_point, 
uint options, const(uint) capabilities, present_notify_ptr notifies, 
int num_notifies, ulong target_msc, ulong crtc_msc)
{
    ScreenPtr screen = window.drawable.pScreen;
    present_window_priv_ptr window_priv = present_get_window_priv(window, TRUE);
    present_screen_priv_ptr screen_priv = present_screen_priv(screen);
    PresentFlipReason reason = PRESENT_FLIP_REASON_UNKNOWN;

    if (target_crtc) {
        screen_priv = present_screen_priv(target_crtc.pScreen);
    }

    xorg_list_append(&vblank.window_list, &window_priv.vblank);
    xorg_list_init(&vblank.event_queue);

    vblank.screen = screen;
    vblank.window = window;
    vblank.pixmap = pixmap;

    if (pixmap) {
        vblank.kind = PresentCompleteKindPixmap;
        pixmap.refcnt++;
    } else
        vblank.kind = PresentCompleteKindNotifyMSC;

    vblank.serial = cast(uint)serial;

    if (valid) {
        vblank.valid = RegionDuplicate(valid);
        if (!vblank.valid)
            goto no_mem;
    }
    if (update) {
        vblank.update = RegionDuplicate(update);
        if (!vblank.update)
            goto no_mem;
    }

    vblank.x_off = x_off;
    vblank.y_off = y_off;
    vblank.target_msc = target_msc;
    vblank.exec_msc = target_msc;
    vblank.crtc = target_crtc;
    vblank.msc_offset = window_priv.msc_offset;
    vblank.notifies = notifies;
    vblank.num_notifies = num_notifies;
    vblank.has_suboptimal = (options & PresentOptionSuboptimal);

    if (pixmap !is null &&
        !(options & PresentOptionCopy) &&
        screen_priv.check_flip) {

        Bool sync_flip = !present_want_async_flip(options, capabilities);

        if (screen_priv.check_flip (target_crtc, window, pixmap,
                                     sync_flip, valid, x_off, y_off, &reason))
        {
            vblank.flip = TRUE;
            vblank.sync_flip = sync_flip;
        }
    }
    vblank.reason = reason;

    if (wait_fence) {
        vblank.wait_fence = present_fence_create(wait_fence);
        if (!vblank.wait_fence)
            goto no_mem;
    }

    if (idle_fence) {
        vblank.idle_fence = present_fence_create(idle_fence);
        if (!vblank.idle_fence)
            goto no_mem;
    }

static if(DRI3){
    vblank.efd = -1;

    if (acquire_syncobj) {
        vblank.acquire_syncobj = acquire_syncobj;
        ++acquire_syncobj.refcount;
        vblank.acquire_point = acquire_point;
    }

    if (release_syncobj) {
        vblank.release_syncobj = release_syncobj;
        ++release_syncobj.refcount;
        vblank.release_point = release_point;
    }
} /* DRI3 */

    if (pixmap) {}
        // DebugPresent(("q %" ~PRIu64 ~ " %p %"~ PRIu64 ~ ": %08" ~PRIx32 ~ " -> %08" ~PRIx32 ~ " (crtc %p) flip %d vsync %d serial %d\n",
        //               vblank.event_id, vblank, target_msc,
        //               vblank.pixmap.drawable.id, vblank.window.drawable.id,
        //               target_crtc, vblank.flip, vblank.sync_flip, vblank.serial));
    return TRUE;

no_mem:
    vblank.notifies = null;
    return FALSE;
}
}
else {
Bool present_vblank_init(present_vblank_ptr vblank, 
WindowPtr window, PixmapPtr pixmap, 
CARD32 serial, RegionPtr valid, RegionPtr update, 
short x_off, short y_off, 
RRCrtcPtr target_crtc, SyncFence* wait_fence, 
SyncFence* idle_fence, uint options, const(uint) capabilities, 
present_notify_ptr notifies, int num_notifies, ulong target_msc, ulong crtc_msc)
{
    ScreenPtr screen = window.drawable.pScreen;
    present_window_priv_ptr window_priv = present_get_window_priv(window, TRUE);
    present_screen_priv_ptr screen_priv = present_screen_priv(screen);
    PresentFlipReason reason = PRESENT_FLIP_REASON_UNKNOWN;

    if (target_crtc) {
        screen_priv = present_screen_priv(target_crtc.pScreen);
    }

    xorg_list_append(&vblank.window_list, &window_priv.vblank);
    xorg_list_init(&vblank.event_queue);

    vblank.screen = screen;
    vblank.window = window;
    vblank.pixmap = pixmap;

    if (pixmap) {
        vblank.kind = PresentCompleteKindPixmap;
        pixmap.refcnt++;
    } else
        vblank.kind = PresentCompleteKindNotifyMSC;

    vblank.serial = cast(uint)serial;

    if (valid) {
        vblank.valid = RegionDuplicate(valid);
        if (!vblank.valid)
            goto no_mem;
    }
    if (update) {
        vblank.update = RegionDuplicate(update);
        if (!vblank.update)
            goto no_mem;
    }

    vblank.x_off = x_off;
    vblank.y_off = y_off;
    vblank.target_msc = target_msc;
    vblank.exec_msc = target_msc;
    vblank.crtc = target_crtc;
    vblank.msc_offset = window_priv.msc_offset;
    vblank.notifies = notifies;
    vblank.num_notifies = num_notifies;
    vblank.has_suboptimal = (options & PresentOptionSuboptimal);

    if (pixmap !is null &&
        !(options & PresentOptionCopy) &&
        screen_priv.check_flip) {

        Bool sync_flip = !present_want_async_flip(options, capabilities);

        if (screen_priv.check_flip (target_crtc, window, pixmap,
                                     sync_flip, valid, x_off, y_off, &reason))
        {
            vblank.flip = TRUE;
            vblank.sync_flip = sync_flip;
        }
    }
    vblank.reason = reason;

    if (wait_fence) {
        vblank.wait_fence = present_fence_create(wait_fence);
        if (!vblank.wait_fence)
            goto no_mem;
    }

    if (idle_fence) {
        vblank.idle_fence = present_fence_create(idle_fence);
        if (!vblank.idle_fence)
            goto no_mem;
    }

    if (pixmap) {}
        // DebugPresent(("q %" ~PRIu64 ~ " %p %"~ PRIu64 ~ ": %08" ~PRIx32 ~ " -> %08" ~PRIx32 ~ " (crtc %p) flip %d vsync %d serial %d\n",
        //               vblank.event_id, vblank, target_msc,
        //               vblank.pixmap.drawable.id, vblank.window.drawable.id,
        //               target_crtc, vblank.flip, vblank.sync_flip, vblank.serial));
    return TRUE;

no_mem:
    vblank.notifies = null;
    return FALSE;
}
}

static if(DRI3) {
present_vblank_ptr present_vblank_create(WindowPtr window, PixmapPtr pixmap, 
CARD32 serial, RegionPtr valid, RegionPtr update, 
short x_off, short y_off, 
RRCrtcPtr target_crtc, SyncFence* wait_fence, SyncFence* idle_fence, 
dri3_syncobj* acquire_syncobj, dri3_syncobj* release_syncobj, ulong acquire_point, 
ulong release_point, uint options, const(uint) capabilities, 
present_notify_ptr notifies, int num_notifies, ulong target_msc, ulong crtc_msc)
{
    present_vblank_ptr vblank = cast(present_vblank_rec*) calloc(1, present_vblank_rec.sizeof);

    if (!vblank)
        return null;

    bool init;
    init = cast(bool)present_vblank_init(vblank, window, pixmap, serial, valid, update,
                            x_off, y_off, target_crtc, wait_fence, idle_fence,
                            acquire_syncobj, release_syncobj,
                            acquire_point, release_point,
                            options, capabilities, notifies, num_notifies,
                            target_msc, crtc_msc);

    if (init)
        return vblank;

    present_vblank_destroy(vblank);
    return null;
}

}

else  {
present_vblank_ptr present_vblank_create(WindowPtr window, PixmapPtr pixmap, 
    CARD32 serial, RegionPtr valid, 
    RegionPtr update, 
    short x_off, short y_off, 
    RRCrtcPtr target_crtc, SyncFence* wait_fence, SyncFence* idle_fence, uint options, 
    const(uint) capabilities, present_notify_ptr notifies, 
    int num_notifies, ulong target_msc, ulong crtc_msc)
{
    present_vblank_ptr vblank = cast(present_vblank_rec*) calloc(1, present_vblank_rec.sizeof);

    if (!vblank)
        return null;

    bool init;
        init = cast(bool)present_vblank_init(vblank, window, pixmap, serial, valid, update,
                            x_off, y_off, target_crtc, wait_fence, idle_fence,
                            options, capabilities, notifies, num_notifies,
                            target_msc, crtc_msc);

    if (init)
        return vblank;

    present_vblank_destroy(vblank);
    return null;
}
}

void present_vblank_scrap(present_vblank_ptr vblank)
{
    // DebugPresent(("\tx %"~ PRIu64 ~ " %p %"~ PRIu64 ~ " %" ~PRIu64 ~ ": %08" ~PRIx32 ~ " -> %08"~ PRIx32 ~ " (crtc %p)\n",
    //               vblank.event_id, vblank, vblank.exec_msc, vblank.target_msc,
    //               vblank.pixmap.drawable.id, vblank.window.drawable.id,
    //               vblank.crtc));

static if(DRI3){
    if (vblank.release_syncobj)
        vblank.release_syncobj.signal(vblank.release_syncobj,
                                        vblank.release_point);
    else
        present_pixmap_idle(vblank.pixmap, vblank.window, vblank.serial, vblank.idle_fence);
} /* DRI3 */
else
        present_pixmap_idle(vblank.pixmap, vblank.window, vblank.serial, vblank.idle_fence);

    present_fence_destroy(vblank.idle_fence);
    dixDestroyPixmap(vblank.pixmap, vblank.pixmap.drawable.id);

    vblank.pixmap = null;
    vblank.idle_fence = null;
    vblank.flip = FALSE;
}

void present_vblank_destroy(present_vblank_ptr vblank)
{
    /* Remove vblank from window and screen lists */
    xorg_list_del(&vblank.window_list);
    /* Also make sure vblank is removed from event queue (wnmd) */
    xorg_list_del(&vblank.event_queue);

    // // DebugPresent(("\td %" ~PRIu64 ~ " %p %" ~PRIu64 ~ " %" ~PRIu64 ~ ": %08"~ PRIx32 ~ " -> %08"~PRIx32 ~ "\n",
    //               vblank.event_id, vblank, vblank.exec_msc, vblank.target_msc,
    //               vblank.pixmap ? vblank.pixmap.drawable.id : 0,
    //               vblank.window ? vblank.window.drawable.id : 0));

    /* Drop pixmap reference */
    if (vblank.pixmap)
        dixDestroyPixmap(vblank.pixmap, vblank.pixmap.drawable.id);

    /* Free regions */
    if (vblank.valid)
        RegionDestroy(vblank.valid);
    if (vblank.update)
        RegionDestroy(vblank.update);

    if (vblank.wait_fence)
        present_fence_destroy(vblank.wait_fence);

    if (vblank.idle_fence)
        present_fence_destroy(vblank.idle_fence);

    if (vblank.notifies)
        present_destroy_notifies(vblank.notifies, vblank.num_notifies);

static if(DRI3){
    if (vblank.efd >= 0) {
        SetNotifyFd(vblank.efd, null, 0, null);
        close(vblank.efd);
    }

    if (vblank.acquire_syncobj &&
        --vblank.acquire_syncobj.refcount == 0)
        vblank.acquire_syncobj.free(vblank.acquire_syncobj);

    if (vblank.release_syncobj &&
        --vblank.release_syncobj.refcount == 0)
        vblank.release_syncobj.free(vblank.release_syncobj);
} /* DRI3 */

    free(vblank);
}
