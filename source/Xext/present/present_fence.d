module present.present_fence;
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

import present.present_priv;

import dix.gc;
import mi.misync;
import mi.misyncstr;

/*
 * Wraps SyncFence objects so we can add a SyncTrigger to find out
 * when the SyncFence gets destroyed and clean up appropriately
 */

struct present_fence {
    SyncTrigger trigger;
    SyncFence* fence;
    void function(void* param) @nogc nothrow callback;
    void* param;
}

/*
 * SyncTrigger callbacks
 */
private Bool present_fence_sync_check_trigger(SyncTrigger* trigger, long oldval)
{
    present_fence* present_fence = trigger.containerOf!(present_fence, "trigger");

    return present_fence.callback !is null;
}

private void present_fence_sync_trigger_fired(SyncTrigger* trigger)
{
    present_fence* present_fence = trigger.containerOf!(present_fence, "trigger");

    if (present_fence.callback)
        (*present_fence.callback)(present_fence.param);
}

private void present_fence_sync_counter_destroyed(SyncTrigger* trigger)
{
    present_fence* present_fence = trigger.containerOf!(present_fence, "trigger");

    present_fence.fence = null;
}

present_fence* present_fence_create(SyncFence* fence)
{
    present_fence* present_fence_ = void;

    present_fence_ = cast(present_fence*) calloc (1, present_fence.sizeof);
    if (!present_fence_)
        return null;

    present_fence_.fence = fence;
    present_fence_.trigger.pSync = cast(SyncObject*) fence;
    present_fence_.trigger.CheckTrigger = &present_fence_sync_check_trigger;
    present_fence_.trigger.TriggerFired = &present_fence_sync_trigger_fired;
    present_fence_.trigger.CounterDestroyed = &present_fence_sync_counter_destroyed;

    if (SyncAddTriggerToSyncObject(&present_fence_.trigger) != Success) {
        free (present_fence_);
        return null;
    }
    return present_fence_;
}

void present_fence_destroy(present_fence* present_fence_)
{
    if (present_fence_) {
        if (present_fence_.fence)
            SyncDeleteTriggerFromSyncObject(&present_fence_.trigger);
        free(present_fence_);
    }
}

void present_fence_set_triggered(present_fence* present_fence)
{
    if (present_fence)
        if (present_fence.fence)
            (*present_fence.fence.funcs.SetTriggered) (present_fence.fence);
}

Bool present_fence_check_triggered(present_fence* present_fence)
{
    if (!present_fence)
        return True;
    if (!present_fence.fence)
        return True;
    return (*present_fence.fence.funcs.CheckTriggered)(present_fence.fence);
}

void present_fence_set_callback(present_fence* present_fence, void function(void* param) @nogc nothrow callback, void* param)
{
    present_fence.callback = callback;
    present_fence.param = param;
}

XID present_fence_id(present_fence* present_fence)
{
    if (!present_fence)
        return None;
    if (!present_fence.fence)
        return None;
    return present_fence.fence.sync.id;
}
