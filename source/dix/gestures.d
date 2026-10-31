module gestures;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2011 Collabra Ltd.
 * Copyright © 2011 Red Hat, Inc.
 * Copyright © 2020 Povilas Kanapickas  <povilas@radix.lt>
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
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

import build.dix_config;
import os.inputthread;

import dix.dix_priv;
import dix.dixgrabs_priv;
import dix.eventconvert;
import dix.input_priv;
import dix.inpututils_priv;
import dix.resource_priv;
import dix.screenint_priv;
import dix.window_priv;
import mi.mi_priv;
import os.bug_priv;

import include.inputstr;
import include.scrnintstr;
import dix.events;
import include.exevents;
import Xi.exglobals;
import include.windowstr;
import dix.events;
import os.utils;
import dix.devices;
import dix.inpututils;


enum GESTURE_HISTORY_SIZE = 100;

Bool GestureInitGestureInfo(GestureInfoPtr gi)
{
    memset(gi, 0, typeof(*gi).sizeof);

    gi.sprite.spriteTrace = cast(_Window**)calloc(32, typeof(*gi.sprite.spriteTrace).sizeof);
    if (!gi.sprite.spriteTrace) {
        return FALSE;
    }
    ScreenPtr masterScreen = dixGetMasterScreen();

    gi.sprite.spriteTraceSize = 32;
    gi.sprite.spriteTrace[0] = masterScreen.root;
    gi.sprite.hot.pScreen = masterScreen;
    gi.sprite.hotPhys.pScreen = masterScreen;

    return TRUE;
}

void GestureFreeGestureInfo(GestureInfoPtr gi)
{
    free(gi.sprite.spriteTrace);
}

/**
 * Given an event type returns the associated gesture event info.
 */
GestureInfoPtr GestureFindActiveByEventType(DeviceIntPtr dev, int type)
{
    GestureClassPtr g = dev.gesture;
    EventType type_to_expect = GestureTypeToBegin(cast(EventType)type);

    if (!g || type_to_expect == 0 || !g.gesture.active ||
        g.gesture.type != type_to_expect) {
        return null;
    }

    return &g.gesture;
}

/**
 * Sets up gesture info for a new gesture. Returns NULL on failure.
 */
GestureInfoPtr GestureBeginGesture(DeviceIntPtr dev, InternalEvent* ev)
{
    GestureClassPtr g = dev.gesture;
    EventType gesture_type = GestureTypeToBegin(ev.any.type);

    /* Note that we ignore begin events when an existing gesture is active */
    if (!g || gesture_type == 0 || g.gesture.active)
        return null;

    g.gesture.type = cast(ubyte)gesture_type;

    if (!GestureBuildSprite(dev, &g.gesture))
        return null;

    g.gesture.active = TRUE;
    g.gesture.num_touches = ev.gesture_event.num_touches;
    g.gesture.sourceid = ev.gesture_event.sourceid;
    g.gesture.has_listener = FALSE;
    return &g.gesture;
}

/**
 * Releases a gesture: this must only be called after all events
 * related to that gesture have been sent and finalised.
 */
void GestureEndGesture(GestureInfoPtr gi)
{
    if (gi.has_listener) {
        FreeGrab(gi.listener.grab);
        gi.listener.grab = null;
        gi.listener.listener = 0;
        gi.has_listener = FALSE;
    }

    gi.active = FALSE;
    gi.num_touches = 0;
    gi.sprite.spriteTraceGood = 0;
}

/**
 * Ensure a window trace is present in gi->sprite, constructing one for
 * Gesture{Pinch,Swipe}Begin events.
 */
Bool GestureBuildSprite(DeviceIntPtr sourcedev, GestureInfoPtr gi)
{
    SpritePtr sprite = &gi.sprite;

    if (!sourcedev.spriteInfo.sprite)
        return FALSE;

    if (!CopySprite(sourcedev.spriteInfo.sprite, sprite))
        return FALSE;

    if (sprite.spriteTraceGood <= 0)
        return FALSE;

    return TRUE;
}

/**
 * @returns TRUE if the specified grab or selection is the current owner of
 * the gesture sequence.
 */
Bool GestureResourceIsOwner(GestureInfoPtr gi, XID resource)
{
    return (gi.listener.listener == resource);
}

void GestureAddListener(GestureInfoPtr gi, XID resource, int resource_type, GestureListenerType type, WindowPtr window, const(GrabPtr) grab)
{
    GrabPtr g = null;

    mixin(BUG_RETURN!("gi.has_listener"));

    /* We need a copy of the grab, not the grab itself since that may be deleted by
     * a UngrabButton request and leaves us with a dangling pointer */
    if (grab)
        g = AllocGrab(grab);

    gi.listener.listener = resource;
    gi.listener.resource_type = resource_type;
    gi.listener.type = type;
    gi.listener.window = window;
    gi.listener.grab = g;
    gi.has_listener = TRUE;
}

private void GestureAddGrabListener(DeviceIntPtr dev, GestureInfoPtr gi, GrabPtr grab)
{
    GestureListenerType type = void;

    /* FIXME: owner_events */

    if (grab.grabtype == XI2) {
        if (xi2mask_isset(grab.xi2mask, dev, XI_GesturePinchBegin) ||
            xi2mask_isset(grab.xi2mask, dev, XI_GestureSwipeBegin)) {
            type = GESTURE_LISTENER_GRAB;
        } else
            type = GESTURE_LISTENER_NONGESTURE_GRAB;
    }
    else if (grab.grabtype == XI || grab.grabtype == CORE) {
        type = GESTURE_LISTENER_NONGESTURE_GRAB;
    }
    else {
        mixin(BUG_RETURN_MSG!("1", "Unsupported grab type\n"));
    }

    /* grab listeners are always X11_RESTYPE_NONE since we keep the grab pointer */
    GestureAddListener(gi, grab.resource, X11_RESTYPE_NONE, type, grab.window, grab);
}

/**
 * Add one listener if there is a grab on the given window.
 */
private void GestureAddPassiveGrabListener(DeviceIntPtr dev, GestureInfoPtr gi, WindowPtr win, InternalEvent* ev)
{
    Bool activate = FALSE;
    Bool check_core = FALSE;

    GrabPtr grab = CheckPassiveGrabsOnWindow(win, dev, ev, cast(ubyte)check_core,
                                             cast(ubyte)activate);
    if (!grab)
        return;

    /* We'll deliver later in gesture-specific code */
    ActivateGrabNoDelivery(dev, grab, ev, ev);
    GestureAddGrabListener(dev, gi, grab);
}

private void GestureAddRegularListener(DeviceIntPtr dev, GestureInfoPtr gi, WindowPtr win, InternalEvent* ev)
{
    InputClients* iclients = null;
    OtherInputMasks* inputMasks = null;
    ushort evtype = cast(ushort)GetXI2Type(ev.any.type);
    int mask = void;

    mask = EventIsDeliverable(dev, ev.any.type, win);
    if (!mask)
        return;

    inputMasks = mixin(wOtherInputMasks!("win"));

    if ((mask & EVENT_XI2_MASK) && (inputMasks !is null)) {
        mixin(nt_list_for_each_entry!("iclients", "inputMasks.inputClients", "next", q{
            if (!xi2mask_isset(iclients.xi2mask, dev, evtype))
                continue;

            GestureAddListener(gi, iclients.resource, RT_INPUTCLIENT,
                               GESTURE_LISTENER_REGULAR, win, null);
            return;
        }));
    }
}

void GestureSetupListener(DeviceIntPtr dev, GestureInfoPtr gi, InternalEvent* ev)
{
    int i = void;
    SpritePtr sprite = &gi.sprite;
    WindowPtr win = void;

    /* Any current grab will consume all gesture events */
    if (dev.deviceGrab.grab) {
        GestureAddGrabListener(dev, gi, dev.deviceGrab.grab);
        return;
    }

    /* Find passive grab that would be activated by this event, if any. If we're handling
     * ReplayDevice then the search starts from the descendant of the grab window, otherwise
     * the search starts at the root window. The search ends at deepest child window. */
    i = 0;
    if (syncEvents.playingEvents) {
        while (i < dev.spriteInfo.sprite.spriteTraceGood) {
            if (dev.spriteInfo.sprite.spriteTrace[i++] == syncEvents.replayWin)
                break;
        }
    }

    for (; i < sprite.spriteTraceGood; i++) {
        win = sprite.spriteTrace[i];
        GestureAddPassiveGrabListener(dev, gi, win, ev);
        if (gi.has_listener)
            return;
    }

    /* Find the first client with an applicable event selection,
     * going from deepest child window back up to the root window. */
    for (int j = sprite.spriteTraceGood - 1; j >= 0; j--) {
        win = sprite.spriteTrace[j];
        GestureAddRegularListener(dev, gi, win, ev);
        if (gi.has_listener)
            return;
    }
}

/* As gesture grabs don't turn into active grabs with their own resources, we
 * need to walk all the gestures and remove this grab from listener */
void GestureListenerGone(XID resource)
{
    GestureInfoPtr gi = void;
    InternalEvent* events = InitEventList(GetMaximumEventsNum());

    if (!events)
        FatalError("GestureListenerGone: couldn't allocate events\n");

    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next) {
        if (!dev.gesture)
            continue;

        gi = &dev.gesture.gesture;
        if (!gi.active)
            continue;

        if (CLIENT_BITS(gi.listener.listener) == resource)
            GestureEndGesture(gi);
    }

    FreeEventList(events, GetMaximumEventsNum());
}

/**
 * End physically active gestures for a device.
 */
void GestureEndActiveGestures(DeviceIntPtr dev)
{
    GestureClassPtr g = dev.gesture;
    InternalEvent* eventlist = void;

    if (!g)
        return;

    eventlist = InitEventList(GetMaximumEventsNum());

    input_lock();
    mieqProcessInputEvents();
    if (g.gesture.active) {
        int type = GetXI2Type(GestureTypeToEnd(cast(EventType)g.gesture.type));
        int nevents = GetGestureEvents(eventlist, dev, cast(ushort)type, cast(ushort)g.gesture.num_touches,
                                       0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);

        for (int j = 0; j < nevents; j++)
            mieqProcessDeviceEvent(dev, eventlist + j, null);
    }
    input_unlock();

    FreeEventList(eventlist, GetMaximumEventsNum());
}

/**
 * Generate and deliver a Gesture{Pinch,Swipe}End event to the owner.
 *
 * @param dev The device to deliver the event for.
 * @param gi The gesture record to deliver the event for.
 */
void GestureEmitGestureEndToOwner(DeviceIntPtr dev, GestureInfoPtr gi)
{
    InternalEvent event = void;
    /* We're not processing a gesture end for a frozen device */
    if (dev.deviceGrab.sync.frozen)
        return;

    DeliverDeviceClassesChangedEvent(gi.sourceid, GetTimeInMillis());
    InitGestureEvent(&event, dev, GetTimeInMillis(), GestureTypeToEnd(cast(EventType)gi.type),
                     0, 0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0);
    DeliverGestureEventToOwner(dev, gi, &event);
}
