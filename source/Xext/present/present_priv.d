module present.present_priv;
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

 
//public import x11.X;
//public import x11.Xmd;

import build.xlibre_server;
public import Xext.sync;

public import dix.scrnintstr;
public import dix.window;
public import dix.dixstruct_priv;
public import Xext.syncsrv;
public import xfixes.xfixes;
public import randr.randr;
public import core.stdc.inttypes;
public import dri3.dri3;
import present.present_fence;
import externs.X11.extensions.presentproto;
public import present.present_vblank; 
import common.swap;

enum PresentFlipReason {
    PRESENT_FLIP_REASON_UNKNOWN,
    PRESENT_FLIP_REASON_BUFFER_FORMAT,

    /* Don't add new flip reasons after the TearFree ones, since it's expected
     * that the TearFree reasons are the highest ones in order to allow doing
     * `reason >= PRESENT_FLIP_REASON_DRIVER_TEARFREE` to check if a reason is
     * PRESENT_FLIP_REASON_DRIVER_TEARFREE{_FLIPPING}.
     */
    PRESENT_FLIP_REASON_DRIVER_TEARFREE,
    PRESENT_FLIP_REASON_DRIVER_TEARFREE_FLIPPING
}
alias PRESENT_FLIP_REASON_UNKNOWN = PresentFlipReason.PRESENT_FLIP_REASON_UNKNOWN;
alias PRESENT_FLIP_REASON_BUFFER_FORMAT = PresentFlipReason.PRESENT_FLIP_REASON_BUFFER_FORMAT;
alias PRESENT_FLIP_REASON_DRIVER_TEARFREE = PresentFlipReason.PRESENT_FLIP_REASON_DRIVER_TEARFREE;
alias PRESENT_FLIP_REASON_DRIVER_TEARFREE_FLIPPING = PresentFlipReason.PRESENT_FLIP_REASON_DRIVER_TEARFREE_FLIPPING;


alias present_vblank_rec = present_vblank;
alias present_vblank_ptr = present_vblank*;

/* Return the current CRTC for 'window'.
 */
alias present_get_crtc_ptr = RRCrtcPtr function(WindowPtr window);

/* Return the current ust/msc for 'crtc'
 */
alias present_get_ust_msc_ptr = int function(RRCrtcPtr crtc, ulong* ust, ulong* msc);
alias present_wnmd_get_ust_msc_ptr = int function(WindowPtr window, ulong* ust, ulong* msc);

/* Queue callback on 'crtc' for time 'msc'. Call present_event_notify with 'event_id'
 * at or after 'msc'. Return false if it didn't happen (which might occur if 'crtc'
 * is not currently generating vblanks).
 */
alias present_queue_vblank_ptr = Bool function(RRCrtcPtr crtc, ulong event_id, ulong msc);
alias present_wnmd_queue_vblank_ptr = Bool function(WindowPtr window, RRCrtcPtr crtc, ulong event_id, ulong msc);

/* Abort pending vblank. The extension is no longer interested in
 * 'event_id' which was to be notified at 'msc'. If possible, the
 * driver is free to de-queue the notification.
 */
alias present_abort_vblank_ptr = void function(RRCrtcPtr crtc, ulong event_id, ulong msc);
alias present_wnmd_abort_vblank_ptr = void function(WindowPtr window, RRCrtcPtr crtc, ulong event_id, ulong msc);

/* Flush pending drawing on 'window' to the hardware.
 */
alias present_flush_ptr = void function(WindowPtr window);

/* Check if 'pixmap' is suitable for flipping to 'window'.
 */
alias present_check_flip_ptr = Bool function(RRCrtcPtr crtc, WindowPtr window, PixmapPtr pixmap, Bool sync_flip);

/* Same as 'check_flip' but it can return a 'reason' why the flip would fail.
 */
alias present_check_flip2_ptr = Bool function(RRCrtcPtr crtc, WindowPtr window, PixmapPtr pixmap, Bool sync_flip, PresentFlipReason* reason);

/* Flip pixmap, return false if it didn't happen.
 *
 * 'crtc' is to be used for any necessary synchronization.
 *
 * 'sync_flip' requests that the flip be performed at the next
 * vertical blank interval to avoid tearing artifacts. If false, the
 * flip should be performed as soon as possible.
 *
 * present_event_notify should be called with 'event_id' when the flip
 * occurs
 */
alias present_flip_ptr = Bool function(RRCrtcPtr crtc, ulong event_id, ulong target_msc, PixmapPtr pixmap, Bool sync_flip);
/* Flip pixmap for window, return false if it didn't happen.
 *
 * Like present_flip_ptr, additionally with:
 *
 * 'window' used for synchronization.
 *
 */
alias present_wnmd_flip_ptr = Bool function(WindowPtr window, RRCrtcPtr crtc, ulong event_id, ulong target_msc, PixmapPtr pixmap, Bool sync_flip, RegionPtr damage);

/* "unflip" back to the regular screen scanout buffer
 *
 * present_event_notify should be called with 'event_id' when the unflip occurs.
 */
alias present_unflip_ptr = void function(ScreenPtr screen, ulong event_id);

/* Doing flips has been discontinued.
 *
 * Inform driver for potential cleanup on its side.
 */
alias present_wnmd_flips_stop_ptr = void function(WindowPtr window);

enum PRESENT_SCREEN_INFO_VERSION =        1;

struct present_screen_info {
    uint version_;

    present_get_crtc_ptr get_crtc;
    present_get_ust_msc_ptr get_ust_msc;
    present_queue_vblank_ptr queue_vblank;
    present_abort_vblank_ptr abort_vblank;
    present_flush_ptr flush;
    uint capabilities;
    present_check_flip_ptr check_flip;
    present_flip_ptr flip;
    present_unflip_ptr unflip;
    present_check_flip2_ptr check_flip2;

}alias present_screen_info_rec = present_screen_info;
alias present_screen_info_ptr = present_screen_info*;

/*
 * Called when 'event_id' occurs. 'ust' and 'msc' indicate when the
 * event actually happened
 */
void  present_event_notify(ulong event_id, ulong ust, ulong msc);

version (none) {
enum string DebugPresent(string x) = `ErrorF x = void;`;
} else {
//#define DebugPresent(x)
}

/* XXX this belongs in presentproto */
enum PresentWindowDestroyed = (1 << 0);


int present_request;

DevPrivateKeyRec present_screen_private_key;

alias present_fence_ptr = present_fence*;

alias present_notify_rec = present_notify;
alias present_notify_ptr = present_notify*;

struct present_notify {
    XList window_list;
    WindowPtr window;
    CARD32 serial;
}

struct present_vblank {
    XList window_list;
    XList event_queue;
    ScreenPtr screen;
    WindowPtr window;
    PixmapPtr pixmap;
    RegionPtr valid;
    RegionPtr update;
    RRCrtcPtr crtc;
    uint serial;
    short x_off;
    short y_off;
    CARD16 kind;
    ulong event_id;
    ulong target_msc;     /* target MSC when present should complete */
    ulong exec_msc;       /* MSC at which present can be executed */
    ulong msc_offset;
    present_fence_ptr idle_fence;
    present_fence_ptr wait_fence;
    present_notify_ptr notifies;
    int num_notifies;
    Bool queued;         /* on present_exec_queue */
    Bool flip;           /* planning on using flip */
    Bool flip_ready;     /* wants to flip, but waiting for previous flip or unflip */
    Bool sync_flip;      /* do flip synchronous to vblank */
    Bool abort_flip;     /* aborting this flip */
    PresentFlipReason reason;         /* reason for which flip is not possible */
    Bool has_suboptimal; /* whether client can support SuboptimalCopy mode */
static if(DRI3){
    dri3_syncobj* acquire_syncobj;
    dri3_syncobj* release_syncobj;
    ulong acquire_point;
    ulong release_point;
    int efd;
} /* DRI3 */
}

alias present_screen_priv_rec = present_screen_priv_t;
alias present_screen_priv_ptr = present_screen_priv_t*;
alias present_window_priv_rec = present_window_priv_t;
alias present_window_priv_ptr = present_window_priv_t*;

/*
 * Mode hooks
 */
alias present_priv_query_capabilities_ptr = uint function(present_screen_priv_ptr screen_priv);
alias present_priv_get_crtc_ptr = RRCrtcPtr function(present_screen_priv_ptr screen_priv, WindowPtr window);

alias present_priv_check_flip_ptr = Bool function(RRCrtcPtr crtc, WindowPtr window, PixmapPtr pixmap, Bool sync_flip, RegionPtr valid, short x_off, short y_off, PresentFlipReason* reason);
alias present_priv_check_flip_window_ptr = void function(WindowPtr window);
alias present_priv_can_window_flip_ptr = Bool function(WindowPtr window);
alias present_priv_clear_window_flip_ptr = void function(WindowPtr window);

static if(DRI3) {
alias present_priv_pixmap_ptr = int function(WindowPtr window, 
    PixmapPtr pixmap, 
    CARD32 serial, 
    RegionPtr valid, 
    RegionPtr update, 
    short x_off, 
    short y_off, 
    RRCrtcPtr target_crtc, 
    SyncFence* wait_fence, 
    SyncFence* idle_fence, 
    dri3_syncobj* acquire_syncobj, 
    dri3_syncobj* release_syncobj, 
    ulong acquire_point, 
    ulong release_point, 
    uint options, 
    ulong window_msc, 
    ulong divisor, 
    ulong remainder, 
    present_notify_ptr notifies, int 
    num_notifies);
}
else {
    alias present_priv_pixmap_ptr = int function(WindowPtr window, 
    PixmapPtr pixmap, 
    CARD32 serial, 
    RegionPtr valid, 
    RegionPtr update, 
    short x_off, 
    short y_off, 
    RRCrtcPtr target_crtc, 
    SyncFence* wait_fence, 
    SyncFence* idle_fence, 
    uint options, 
    ulong window_msc, 
    ulong divisor, 
    ulong remainder, 
    present_notify_ptr notifies, int 
    num_notifies);
}


alias present_priv_queue_vblank_ptr = int function(ScreenPtr screen, WindowPtr window, RRCrtcPtr crtc, ulong event_id, ulong msc);
alias present_priv_flush_ptr = void function(WindowPtr window);
alias present_priv_flush_fenced_ptr = int function(WindowPtr window);
alias present_priv_re_execute_ptr = void function(present_vblank_ptr vblank);

alias present_priv_abort_vblank_ptr = void function(ScreenPtr screen, WindowPtr window, RRCrtcPtr crtc, ulong event_id, ulong msc);
alias present_priv_flip_destroy_ptr = void function(ScreenPtr screen);

struct present_screen_priv_t {
    ScreenPtr pScreen;
    ConfigNotifyProcPtr ConfigNotify;
    ClipNotifyProcPtr ClipNotify;

    present_vblank_ptr flip_pending;
    ulong unflip_event_id;

    uint fake_interval;

    /* Currently active flipped pixmap and fence */
    RRCrtcPtr flip_crtc;
    WindowPtr flip_window;
    uint flip_serial;
    PixmapPtr flip_pixmap;
    present_fence_ptr flip_idle_fence;
    Bool flip_sync;

    present_screen_info_ptr info;

    /* Mode hooks */
    present_priv_query_capabilities_ptr query_capabilities;
    present_priv_get_crtc_ptr get_crtc;

    present_priv_check_flip_ptr check_flip;
    present_priv_check_flip_window_ptr check_flip_window;
    present_priv_can_window_flip_ptr can_window_flip;
    present_priv_clear_window_flip_ptr clear_window_flip;

    present_priv_pixmap_ptr present_pixmap;

    present_priv_queue_vblank_ptr queue_vblank;
    present_priv_flush_ptr flush;
    present_priv_flush_fenced_ptr flush_fenced;
    present_priv_re_execute_ptr re_execute;

    present_priv_abort_vblank_ptr abort_vblank;
    present_priv_flip_destroy_ptr flip_destroy;
}

enum string wrap(string priv,string real_,string mem,string func) = `{
    ` ~ priv ~ `.` ~ mem ~ ` = ` ~ real_ ~ `.` ~ mem ~ `; 
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ func ~ `; 
}`;

enum string unwrap(string priv,string real_,string mem) = `{
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ priv ~ `.` ~ mem ~ `; 
}`;

pragma(inline, true)present_screen_priv_ptr present_screen_priv(ScreenPtr screen)
{
    return cast(present_screen_priv_ptr)dixLookupPrivate(&(screen).devPrivates, &present_screen_private_key);
}

/*
 * Each window has a list of clients and event masks
 */

struct present_event{
    present_event_ptr next;
    ClientPtr client;
    WindowPtr window;
    XID id;
    int mask;
}
alias present_event_rec = present_event;
alias present_event_ptr = present_event*;

struct present_window_priv_t {
    WindowPtr window;
    present_event_ptr events;
    RRCrtcPtr crtc;        /* Last reported CRTC from get_ust_msc */
    ulong msc_offset;
    ulong msc;         /* Last reported MSC from the current crtc */
    XList vblank;
    XList notifies;
}

enum PresentCrtcNeverSet =     cast(RRCrtcPtr) 1;

DevPrivateKeyRec present_window_private_key;

pragma(inline, true)present_window_priv_ptr present_window_priv(WindowPtr window)
{
    return cast(present_window_priv_ptr)dixGetPrivate(&(window).devPrivates, &present_window_private_key);
}

present_window_priv_ptr present_get_window_priv(WindowPtr window, Bool create);

/*
 * Returns:
 * TRUE if the first MSC value is after the second one
 * FALSE if the first MSC value is equal to or before the second one
 */
pragma(inline, true)Bool msc_is_after(ulong test, ulong reference)
{
    return cast(long)(test - reference) > 0;
}

/*
 * present.c
 */
uint present_query_capabilities(RRCrtcPtr crtc);

RRCrtcPtr present_get_crtc(WindowPtr window);

void present_copy_region(DrawablePtr drawable, PixmapPtr pixmap, RegionPtr update, short x_off, short y_off);

void present_pixmap_idle(PixmapPtr pixmap, WindowPtr window, CARD32 serial, present_fence* present_fence);

void present_set_tree_pixmap(WindowPtr window, PixmapPtr expected, PixmapPtr pixmap);

ulong present_get_target_msc(ulong target_msc_arg, ulong crtc_msc, ulong divisor, ulong remainder, uint options);

static if(DRI3) {
int present_pixmap(WindowPtr window, 
    PixmapPtr pixmap, 
    CARD32 serial, 
    RegionPtr valid, 
    RegionPtr update, 
    short x_off, 
    short y_off, 
    RRCrtcPtr target_crtc, 
    SyncFence* wait_fence, 
    SyncFence* idle_fence, 
        dri3_syncobj* acquire_syncobj, 
        dri3_syncobj* release_syncobj, 
        ulong acquire_point, 
        ulong release_point, 
    uint options, ulong target_msc, ulong divisor, ulong remainder, present_notify_ptr notifies, int num_notifies);

}
else {
int present_pixmap(WindowPtr window, 
    PixmapPtr pixmap, 
    CARD32 serial, 
    RegionPtr valid, 
    RegionPtr update, 
    short x_off, 
    short y_off, 
    RRCrtcPtr target_crtc, 
    SyncFence* wait_fence, 
    SyncFence* idle_fence, 
    uint options, 
    ulong target_msc, 
    ulong divisor, 
    ulong remainder, present_notify_ptr notifies, int num_notifies);
}


int present_notify_msc(WindowPtr window, CARD32 serial, ulong target_msc, ulong divisor, ulong remainder);

/*
 * present_event.c
 */

void present_free_events(WindowPtr window);

void present_send_config_notify(WindowPtr window, int x, int y, int w, int h, int bw, WindowPtr sibling, CARD32 flags);

void present_send_complete_notify(WindowPtr window, CARD8 kind, CARD8 mode, CARD32 serial, ulong ust, ulong msc);

void present_send_idle_notify(WindowPtr window, CARD32 serial, PixmapPtr pixmap, present_fence_ptr idle_fence);

int present_select_input(ClientPtr client, XID eid, WindowPtr window, CARD32 event_mask);

Bool present_event_init();

/*
 * present_execute.c
 */
Bool present_execute_wait(present_vblank_ptr vblank, ulong crtc_msc);

void present_execute_copy(present_vblank_ptr vblank, ulong crtc_msc);

void present_execute_post(present_vblank_ptr vblank, ulong ust, ulong crtc_msc);

/*
 * present_fake.c
 */
int present_fake_get_ust_msc(ScreenPtr screen, ulong* ust, ulong* msc);

int present_fake_queue_vblank(ScreenPtr screen, ulong event_id, ulong msc);

void present_fake_abort_vblank(ScreenPtr screen, ulong event_id, ulong msc);

void present_fake_screen_init(ScreenPtr screen);

void present_fake_queue_init();

/*
 * present_fence.c
 */
present_fence* present_fence_create(SyncFence* sync_fence);

void present_fence_destroy(present_fence* present_fence);

// void present_fence_set_triggered(present_fence* present_fence);

Bool present_fence_check_triggered(present_fence* present_fence);

void present_fence_set_callback(present_fence* present_fence, void function(void* param) callback, void* param);

// XID present_fence_id(present_fence* present_fence);

/*
 * present_notify.c
 */
void present_clear_window_notifies(WindowPtr window);

void present_free_window_notify(present_notify_ptr notify);

int present_add_window_notify(present_notify_ptr notify);

int present_create_notifies(ClientPtr client, int num_notifies, xPresentNotify* x_notifies, present_notify_ptr* p_notifies);

void present_destroy_notifies(present_notify_ptr notifies, int num_notifies);

/*
 * present_redirect.c
 */

WindowPtr present_redirect(ClientPtr client, WindowPtr target);

/*
 * present_request.c
 */
int proc_present_dispatch(ClientPtr client);

int sproc_present_dispatch(ClientPtr client);

/*
 * present_scmd.c
 */
void present_abort_vblank(ScreenPtr screen, RRCrtcPtr crtc, ulong event_id, ulong msc);

void present_flip_destroy(ScreenPtr screen);

void present_restore_screen_pixmap(ScreenPtr screen);

void present_set_abort_flip(ScreenPtr screen);

Bool present_init();

void present_scmd_init_mode_hooks(present_screen_priv_ptr screen_priv);

/*
 * present_screen.c
 */
Bool present_screen_register_priv_keys();

present_screen_priv_ptr present_screen_priv_init(ScreenPtr screen);

/*
 * present_vblank.c
 */
// void present_vblank_notify(present_vblank_ptr vblank, CARD8 kind, CARD8 mode, ulong ust, ulong crtc_msc);

// Bool present_vblank_init(present_vblank_ptr vblank, WindowPtr window, PixmapPtr pixmap, CARD32 serial, RegionPtr valid, RegionPtr update, short x_off, short y_off, RRCrtcPtr target_crtc, SyncFence* wait_fence, SyncFence* idle_fence, dri3_syncobj* acquire_syncobj, dri3_syncobj* release_syncobj, ulong acquire_point, ulong release_point, uint options, const(uint) capabilities, present_notify_ptr notifies, int num_notifies, ulong target_msc, ulong crtc_msc);

// present_vblank_ptr present_vblank_create(WindowPtr window, PixmapPtr pixmap, CARD32 serial, RegionPtr valid, RegionPtr update, short x_off, short y_off, RRCrtcPtr target_crtc, SyncFence* wait_fence, SyncFence* idle_fence, dri3_syncobj* acquire_syncobj, dri3_syncobj* release_syncobj, ulong acquire_point, ulong release_point, uint options, const(uint) capabilities, present_notify_ptr notifies, int num_notifies, ulong target_msc, ulong crtc_msc);

// void present_vblank_scrap(present_vblank_ptr vblank);

// void present_vblank_destroy(present_vblank_ptr vblank);

/* only for in-tree modesetting */ void present_check_flips(WindowPtr window);

alias present_complete_notify_proc = void function(WindowPtr window, CARD8 kind, CARD8 mode, CARD32 serial, ulong ust, ulong msc);

/* only for in-tree GLX module present.*/ void present_register_complete_notify(present_complete_notify_proc proc);

/* only for in-tree modesetting */ Bool present_can_window_flip(WindowPtr window);

uint FakeScreenFps;

 /*  _PRESENT_PRIV_H_ */
