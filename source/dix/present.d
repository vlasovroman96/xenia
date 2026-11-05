module include.present;
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

 
// //public import x11.Xfuncproto;
//public import x11.Xmd;
// //public import externs.X11.extensions.presentproto;

public import include.randrstr;
import present.present_priv;

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

// void  present_screen_init(ScreenPtr screen, present_screen_info_ptr info);

 /* _PRESENT_H_ */
