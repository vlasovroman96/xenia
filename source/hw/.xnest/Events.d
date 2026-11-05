module Events;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1993 by Davor Matic

Permission to use, copy, modify, distribute, and sell this software
and its documentation for any purpose is hereby granted without fee,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.  Davor Matic makes no representations about
the suitability of this software for any purpose.  It is provided "as
is" without express or implied warranty.

*/
import build.xorg_config;

//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import dix.cursor_priv;
import dix.inpututils_priv;
import mi.mi_priv;

import include.scrintstr;
import dix.input;
import include.misc;
import include.scrnintstr;
import include.windowstr;
import include.servermd;
import dix.inputstr;
import xnest_xcb;


import Args;
import Color;
import Display;
import Screen;
import XNWindow;
import dix.events;
import Keyboard;
import Pointer;
import mi.mipointer;

CARD32 lastEventTime = 0;

void ProcessInputEvents()
{
    mieqProcessInputEvents();
}

int TimeSinceLastInputEvent()
{
    if (lastEventTime == 0)
        lastEventTime = GetTimeInMillis();
    return GetTimeInMillis() - lastEventTime;
}

void SetTimeSinceLastInputEvent()
{
    lastEventTime = GetTimeInMillis();
}

void xnestQueueKeyEvent(int type, uint keycode)
{
    lastEventTime = GetTimeInMillis();
    QueueKeyboardEvents(xnestKeyboardDevice, type, keycode);
}

enum string EVTYPE(string tname) = `tname* ev = cast(tname*)event;`;

private void xnest_handle_event(xcb_generic_event_t* event)
{
    if (!event)
        return;

    switch (event.response_type & ~0x80) {
        case KeyPress:
        {
            mixin(EVTYPE!(`xcb_key_press_event_t`));
            xnestUpdateModifierState(ev.state);
            xnestQueueKeyEvent(KeyPress, ev.detail);
            break;
        }

        case KeyRelease:
        {
            mixin(EVTYPE!(`xcb_key_release_event_t`));
            xnestUpdateModifierState(ev.state);
            xnestQueueKeyEvent(KeyRelease, ev.detail);
            break;
        }

        case ButtonPress:
        {
            ValuatorMask mask = void;
            mixin(EVTYPE!(`xcb_button_press_event_t`));
            valuator_mask_set_range(&mask, 0, 0, null);
            xnestUpdateModifierState(ev.state);
            lastEventTime = GetTimeInMillis();
            QueuePointerEvents(xnestPointerDevice, ButtonPress,
                               ev.detail, POINTER_RELATIVE, &mask);
            break;
        }

        case ButtonRelease:
        {
            ValuatorMask mask = void;
            mixin(EVTYPE!(`xcb_button_release_event_t`));
            valuator_mask_set_range(&mask, 0, 0, null);
            xnestUpdateModifierState(ev.state);
            lastEventTime = GetTimeInMillis();
            QueuePointerEvents(xnestPointerDevice, ButtonRelease,
                               ev.detail, POINTER_RELATIVE, &mask);
            break;
        }

        case MotionNotify:
        {
            mixin(EVTYPE!(`xcb_motion_notify_event_t`));
            ValuatorMask mask = void;
            int[2] valuators = void;
            valuators[0] = ev.event_x;
            valuators[1] = ev.event_y;
            valuator_mask_set_range(&mask, 0, 2, valuators.ptr);
            lastEventTime = GetTimeInMillis();
            QueuePointerEvents(xnestPointerDevice, MotionNotify,
                               0, POINTER_ABSOLUTE, &mask);
            break;
        }

        case FocusIn:
        {
            mixin(EVTYPE!(`xcb_focus_in_event_t`));
            if (ev.detail != NotifyInferior) {
                ScreenPtr pScreen = xnestScreen(ev.event);
                if (pScreen)
                    xnestDirectInstallColormaps(pScreen);
            }
            break;
        }

        case FocusOut:
        {
            mixin(EVTYPE!(`xcb_focus_out_event_t`));
            if (ev.detail != NotifyInferior) {
                ScreenPtr pScreen = xnestScreen(ev.event);
                if (pScreen)
                    xnestDirectUninstallColormaps(pScreen);
            }
            break;
        }

        case KeymapNotify:
            break;

        case EnterNotify:
        {
            mixin(EVTYPE!(`xcb_enter_notify_event_t`));
            if (ev.detail != NotifyInferior) {
                ScreenPtr pScreen = xnestScreen(ev.event);
                if (pScreen) {
                    ValuatorMask mask = void;
                    int[2] valuators = void;
                    NewCurrentScreen(inputInfo.pointer, pScreen,
                                     ev.event_x, ev.event_y);
                    valuators[0] = ev.event_x;
                    valuators[1] = ev.event_y;
                    valuator_mask_set_range(&mask, 0, 2, valuators.ptr);
                    lastEventTime = GetTimeInMillis();
                    QueuePointerEvents(xnestPointerDevice, MotionNotify,
                                       0, POINTER_ABSOLUTE, &mask);
                    xnestDirectInstallColormaps(pScreen);
                }
            }
            break;
        }

        case LeaveNotify:
        {
            mixin(EVTYPE!(`xcb_leave_notify_event_t`));
            if (ev.detail != NotifyInferior) {
                ScreenPtr pScreen = xnestScreen(ev.event);
                if (pScreen) {
                    xnestDirectUninstallColormaps(pScreen);
                }
            }
            break;
        }

        case DestroyNotify:
        {
            xcb_destroy_notify_event_t* ev = cast(xcb_destroy_notify_event_t*)event;
            if (xnestParentWindow &&
                ev.window == xnestParentWindow)
                exit(0);
            break;
        }

        case CirculateNotify:
        case ConfigureNotify:
        case GravityNotify:
        case MapNotify:
        case ReparentNotify:
        case UnmapNotify:
            break;

        case Expose:
        {
            mixin(EVTYPE!(`xcb_expose_event_t`));
            WindowPtr pWin = xnestWindowPtr(ev.window);
            if (pWin && ev.width && ev.height) {
                RegionRec Rgn = void;
                BoxRec Box = void;
                Box.x1 = pWin.drawable.x + mixin(wBorderWidth!"pWin")+ ev.x;
                Box.y1 = pWin.drawable.y + mixin(wBorderWidth!"pWin")+ ev.y;
                Box.x2 = Box.x1 + ev.width;
                Box.y2 = Box.y1 + ev.height;
                RegionInit(&Rgn, &Box, 1);
                miSendExposures(pWin, &Rgn, Box.x1, Box.y1);
            }
        }
        break;

        case NoExpose:
            ErrorF("xnest: received stray NoExpose\n");
        break;
        case GraphicsExpose:
            ErrorF("xnest: received stray GraphicsExpose\n");
        break;

        default:
            ErrorF("xnest warning: unhandled event: %d\n", event.response_type);
            break;
    }
}

void xnestCollectEvents()
{
    /* process queued events */
    xnest_event_queue* tmp = null, walk = null;
    mixin(xorg_list_for_each_entry_safe!("walk", "tmp", "xnestUpstreamInfo.eventQueue.entry", "entry", q{
        xnest_handle_event(walk.event);
        xorg_list_del(&walk.entry);
        free(walk.event);
        free(walk);
    }));

    xcb_flush(xnestUpstreamInfo.conn);

    int err = xcb_connection_has_error(xnestUpstreamInfo.conn);
    if (err) {
        ErrorF("Xnest: upstream connection error: %d\n", err);
        exit(0);
    }

    /* fetch new events from xcb */
    xcb_generic_event_t* event = null;
    while ((event = xcb_poll_for_event(xnestUpstreamInfo.conn))) {
        xnest_handle_event(event);
        free(event);
    }

    xcb_flush(xnestUpstreamInfo.conn);
}
