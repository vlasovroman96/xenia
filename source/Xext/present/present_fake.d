module present.present_fake;
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
import build.dix_config;

import common.list;
import present.present_priv;
import os.utils;
import os.WaitFor;


private XList fake_vblank_queue;

struct present_fake_vblank {
    XList list;
    ulong event_id;
    OsTimerPtr timer;
    ScreenPtr screen;
}alias present_fake_vblank_rec = present_fake_vblank;
alias present_fake_vblank_ptr = present_fake_vblank*;

int present_fake_get_ust_msc(ScreenPtr screen, ulong* ust, ulong* msc)
{
    present_screen_priv_ptr screen_priv = present_screen_priv(screen);

    *ust = GetTimeInMicros();
    *msc = (*ust + screen_priv.fake_interval / 2) / screen_priv.fake_interval;
    return Success;
}

private void present_fake_notify(ScreenPtr screen, ulong event_id)
{
    ulong ust = void, msc = void;

    present_fake_get_ust_msc(screen, &ust, &msc);
    present_event_notify(event_id, ust, msc);
}

private CARD32 present_fake_do_timer(OsTimerPtr timer, CARD32 time, void* arg)
{
    present_fake_vblank_ptr fake_vblank = cast(present_fake_vblank_ptr)arg;

    present_fake_notify(fake_vblank.screen, fake_vblank.event_id);
    fake_vblank.list.removeFromList();
    TimerFree(fake_vblank.timer);
    free(fake_vblank);
    return 0;
}

void present_fake_abort_vblank(ScreenPtr screen, ulong event_id, ulong msc)
{
    foreach(fake_vblank; fake_vblank_queue.byEntriesSafe!present_fake_vblank_ptr) {
        if (fake_vblank.event_id == event_id) {
            TimerFree(fake_vblank.timer); /* TimerFree will call TimerCancel() */
            fake_vblank.list.removeFromList();
            free (fake_vblank);
            break;
        }
    }
}

int present_fake_queue_vblank(ScreenPtr screen, ulong event_id, ulong msc)
{
    present_screen_priv_ptr screen_priv = present_screen_priv(screen);
    ulong ust = msc * screen_priv.fake_interval;
    ulong now = GetTimeInMicros();
    INT32 delay = cast(int)((cast(long) (ust - now)) / 1000);
    present_fake_vblank_ptr fake_vblank = void;

    if (delay <= 0) {
        present_fake_notify(screen, event_id);
        return Success;
    }

    fake_vblank = cast(present_fake_vblank_ptr)calloc (1, present_fake_vblank_rec.sizeof);
    if (!fake_vblank)
        return BadAlloc;

    fake_vblank.screen = screen;
    fake_vblank.event_id = event_id;
    fake_vblank.timer = TimerSet(null, 0, delay, &present_fake_do_timer, fake_vblank);
    if (!fake_vblank.timer) {
        free(fake_vblank);
        return BadAlloc;
    }

    fake_vblank_queue.addListNext(&fake_vblank.list);

    return Success;
}

// uint FakeScreenFps = 0;

void present_fake_screen_init(ScreenPtr screen)
{
    uint fake_fps = void;
    present_screen_priv_ptr screen_priv = present_screen_priv(screen);

    if (FakeScreenFps)
        fake_fps = FakeScreenFps;
    else {
        /* For screens with hardware vblank support, the fake code
        * will be used for off-screen windows and while screens are blanked,
        * in which case we want a large interval here: 1Hz
        *
        * Otherwise, pretend that the screen runs at 60Hz
        */
        if (screen_priv.info && screen_priv.info.get_crtc)
            fake_fps = 1;
        else
            fake_fps = 60;
    }
    screen_priv.fake_interval = 1000000 / fake_fps;
}

void present_fake_queue_init()
{
    fake_vblank_queue.initList();
}
