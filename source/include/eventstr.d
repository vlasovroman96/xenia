module include.eventstr;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2009 Red Hat, Inc.
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
 *
 */

 
public import include.inputstr;

import build.xlibre_server;/**
 * @file events.h
 * This file describes the event structures used internally by the X
 * server during event generation and event processing.
 *
 * When are internal events used?
 * Events from input devices are stored as internal events in the EQ and
 * processed as internal events until late in the processing cycle. Only then
 * do they switch to their respective wire events.
 */

/**
 * Event types. Used exclusively internal to the server, not visible on the
 * protocol.
 *
 * Note: Keep KeyPress to Motion aligned with the core events.
 *       Keep ET_Raw* in the same order as KeyPress - Motion
 */
enum EventType {
    ET_KeyPress = 2,
    ET_KeyRelease,
    ET_ButtonPress,
    ET_ButtonRelease,
    ET_Motion,
    ET_TouchBegin,
    ET_TouchUpdate,
    ET_TouchEnd,
    ET_TouchOwnership,
    ET_Enter,
    ET_Leave,
    ET_FocusIn,
    ET_FocusOut,
    ET_ProximityIn,
    ET_ProximityOut,
    ET_DeviceChanged,
    ET_Hierarchy,
    ET_DGAEvent,
    ET_RawKeyPress,
    ET_RawKeyRelease,
    ET_RawButtonPress,
    ET_RawButtonRelease,
    ET_RawMotion,
    ET_RawTouchBegin,
    ET_RawTouchUpdate,
    ET_RawTouchEnd,
    ET_XQuartz,
    ET_BarrierHit,
    ET_BarrierLeave,
    ET_GesturePinchBegin,
    ET_GesturePinchUpdate,
    ET_GesturePinchEnd,
    ET_GestureSwipeBegin,
    ET_GestureSwipeUpdate,
    ET_GestureSwipeEnd,
    ET_Internal = 0xFF          /* First byte */
}
alias ET_KeyPress = EventType.ET_KeyPress;
alias ET_KeyRelease = EventType.ET_KeyRelease;
alias ET_ButtonPress = EventType.ET_ButtonPress;
alias ET_ButtonRelease = EventType.ET_ButtonRelease;
alias ET_Motion = EventType.ET_Motion;
alias ET_TouchBegin = EventType.ET_TouchBegin;
alias ET_TouchUpdate = EventType.ET_TouchUpdate;
alias ET_TouchEnd = EventType.ET_TouchEnd;
alias ET_TouchOwnership = EventType.ET_TouchOwnership;
alias ET_Enter = EventType.ET_Enter;
alias ET_Leave = EventType.ET_Leave;
alias ET_FocusIn = EventType.ET_FocusIn;
alias ET_FocusOut = EventType.ET_FocusOut;
alias ET_ProximityIn = EventType.ET_ProximityIn;
alias ET_ProximityOut = EventType.ET_ProximityOut;
alias ET_DeviceChanged = EventType.ET_DeviceChanged;
alias ET_Hierarchy = EventType.ET_Hierarchy;
alias ET_DGAEvent = EventType.ET_DGAEvent;
alias ET_RawKeyPress = EventType.ET_RawKeyPress;
alias ET_RawKeyRelease = EventType.ET_RawKeyRelease;
alias ET_RawButtonPress = EventType.ET_RawButtonPress;
alias ET_RawButtonRelease = EventType.ET_RawButtonRelease;
alias ET_RawMotion = EventType.ET_RawMotion;
alias ET_RawTouchBegin = EventType.ET_RawTouchBegin;
alias ET_RawTouchUpdate = EventType.ET_RawTouchUpdate;
alias ET_RawTouchEnd = EventType.ET_RawTouchEnd;
alias ET_XQuartz = EventType.ET_XQuartz;
alias ET_BarrierHit = EventType.ET_BarrierHit;
alias ET_BarrierLeave = EventType.ET_BarrierLeave;
alias ET_GesturePinchBegin = EventType.ET_GesturePinchBegin;
alias ET_GesturePinchUpdate = EventType.ET_GesturePinchUpdate;
alias ET_GesturePinchEnd = EventType.ET_GesturePinchEnd;
alias ET_GestureSwipeBegin = EventType.ET_GestureSwipeBegin;
alias ET_GestureSwipeUpdate = EventType.ET_GestureSwipeUpdate;
alias ET_GestureSwipeEnd = EventType.ET_GestureSwipeEnd;
alias ET_Internal = EventType.ET_Internal;


/**
 * How a DeviceEvent was provoked
 */
enum DeviceEventSource {
  EVENT_SOURCE_NORMAL = 0, /**< Default: from a user action (e.g. key press) */
  EVENT_SOURCE_FOCUS, /**< Keys or buttons previously down on focus-in */
}
alias EVENT_SOURCE_NORMAL = DeviceEventSource.EVENT_SOURCE_NORMAL;
alias EVENT_SOURCE_FOCUS = DeviceEventSource.EVENT_SOURCE_FOCUS;


/**
 * Used for ALL input device events internal in the server until
 * copied into the matching protocol event.
 *
 * Note: We only use the device id because the DeviceIntPtr may become invalid while
 * the event is in the EQ.
 */
struct _DeviceEvent {
    ubyte header; /**< Always ET_Internal */
    EventType type;  /**< One of EventType */
    int length;           /**< Length in bytes */
    Time time;            /**< Time in ms */
    int deviceid;         /**< Device to post this event for */
    int sourceid;         /**< The physical source device */
    union _Detail {
        uint button;  /**< Button number (also used in pointer emulating
                               touch events) */
        uint key;     /**< Key code */
    }_Detail detail;
    uint touchid;     /**< Touch ID (client_id) */
    short root_x;       /**< Pos relative to root window in integral data */
    float root_x_frac = 0;    /**< Pos relative to root window in frac part */
    short root_y;       /**< Pos relative to root window in integral part */
    float root_y_frac = 0;    /**< Pos relative to root window in frac part */
    ubyte[(MAX_BUTTONS + 7) / 8] buttons;  /**< Button mask */
    struct _Valuators {
        ubyte[(MAX_VALUATORS + 7) / 8] mask;/**< Valuator mask */
        ubyte[(MAX_VALUATORS + 7) / 8] mode;/**< Valuator mode (Abs or Rel)*/
        double[MAX_VALUATORS] data = 0;           /**< Valuator data */
    }_Valuators valuators;
    struct _Mods {
        uint base;    /**< XKB base modifiers */
        uint latched; /**< XKB latched modifiers */
        uint locked;  /**< XKB locked modifiers */
        uint effective;/**< XKB effective modifiers */
    }_Mods mods;
    struct _Group {
        ubyte base;    /**< XKB base group */
        ubyte latched; /**< XKB latched group */
        ubyte locked;  /**< XKB locked group */
        ubyte effective;/**< XKB effective group */
    }_Group group;
    Window root;      /**< Root window of the event */
    int corestate;    /**< Core key/button state BEFORE the event */
    int key_repeat;   /**< Internally-generated key repeat event */
    uint flags;   /**< Flags to be copied into the generated event */
    uint resource; /**< Touch event resource, only for TOUCH_REPLAYING */
    DeviceEventSource source_type; /**< How this event was provoked */
}
alias DeviceEvent = _DeviceEvent;

/**
 * Generated internally whenever a touch ownership chain changes - an owner
 * has accepted or rejected a touch, or a grab/event selection in the delivery
 * chain has been removed.
 */
struct _TouchOwnershipEvent {
    ubyte header; /**< Always ET_Internal */
    EventType type;  /**< ET_TouchOwnership */
    int length;           /**< Length in bytes */
    Time time;            /**< Time in ms */
    int deviceid;         /**< Device to post this event for */
    int sourceid;         /**< The physical source device */
    uint touchid;     /**< Touch ID (client_id) */
    ubyte reason;       /**< ::XIAcceptTouch, ::XIRejectTouch */
    uint resource;    /**< Provoking grab or event selection */
    uint flags;       /**< Flags to be copied into the generated event */
}
alias TouchOwnershipEvent = _TouchOwnershipEvent;

/* Flags used in DeviceChangedEvent to signal if the slave has changed */
enum DEVCHANGE_SLAVE_SWITCH = 0x2;
/* Flags used in DeviceChangedEvent to signal whether the event was a
 * pointer event or a keyboard event */
enum DEVCHANGE_POINTER_EVENT = 0x4;
enum DEVCHANGE_KEYBOARD_EVENT = 0x8;
/* device capabilities changed */
enum DEVCHANGE_DEVICE_CHANGE = 0x10;

/**
 * Sent whenever a device's capabilities have changed.
 */
struct _DeviceChangedEvent {
    ubyte header; /**< Always ET_Internal */
    EventType type;  /**< ET_DeviceChanged */
    int length;           /**< Length in bytes */
    Time time;            /**< Time in ms */
    int deviceid;         /**< Device whose capabilities have changed */
    int flags;            /**< Mask of ::HAS_NEW_SLAVE,
                               ::POINTER_EVENT, ::KEYBOARD_EVENT */
    int masterid;         /**< MD when event was generated */
    int sourceid;         /**< The device that caused the change */

    struct _Buttons {
        int num_buttons;        /**< Number of buttons */
        Atom[MAX_BUTTONS] names;/**< Button names */
    }_Buttons buttons;

    int num_valuators;          /**< Number of axes */
    struct _Valuators {
        uint min;           /**< Minimum value */
        uint max;           /**< Maximum value */
        double value = 0;           /**< Current value */
        /* FIXME: frac parts of min/max */
        uint resolution;    /**< Resolution counts/m */
        ubyte mode;           /**< Relative or Absolute */
        Atom name;              /**< Axis name */
        ScrollInfo scroll;      /**< Smooth scrolling info */
    }_Valuators[MAX_VALUATORS] valuators;

    struct _Keys {
        int min_keycode;
        int max_keycode;
    }_Keys keys;
}
alias DeviceChangedEvent = _DeviceChangedEvent;

// static if(build.xlibre_server.XFreeXDGA){
/**
 * DGAEvent, used by DGA to intercept and emulate input events.
 */
struct _DGAEvent {
    ubyte header; /**<  Always ET_Internal */
    EventType type;  /**<  ET_DGAEvent */
    int length;           /**<  Length in bytes */
    Time time;            /**<  Time in ms */
    int subtype;          /**<  KeyPress, KeyRelease, ButtonPress,
                                ButtonRelease, MotionNotify */
    int detail;           /**<  Button number or key code */
    int dx;               /**<  Relative x coordinate */
    int dy;               /**<  Relative y coordinate */
    int screen;           /**<  Screen number this event applies to */
    ushort state;       /**<  Core modifier/button state */
}
alias DGAEvent = _DGAEvent;
// }

/**
 * Raw event, contains the data as posted by the device.
 */
struct _RawDeviceEvent {
    ubyte header; /**<  Always ET_Internal */
    EventType type;  /**<  ET_Raw */
    int length;           /**<  Length in bytes */
    Time time;            /**<  Time in ms */
    int deviceid;         /**< Device to post this event for */
    int sourceid;         /**< The physical source device */
    union _Detail {
        uint button;  /**< Button number */
        uint key;     /**< Key code */
    }_Detail detail;
    struct _Valuators {
        ubyte[(MAX_VALUATORS + 7) / 8] mask;/**< Valuator mask */
        double[MAX_VALUATORS] data = 0;           /**< Valuator data */
        double[MAX_VALUATORS] data_raw = 0;       /**< Valuator data as posted */
    }_Valuators valuators;
    uint flags;       /**< Flags to be copied into the generated event */
}
alias RawDeviceEvent = _RawDeviceEvent;

struct _BarrierEvent {
    ubyte header; /**<  Always ET_Internal */
    EventType type;  /**<  ET_BarrierHit, ET_BarrierLeave */
    int length;           /**<  Length in bytes */
    Time time;            /**<  Time in ms */
    int deviceid;         /**< Device to post this event for */
    int sourceid;         /**< The physical source device */
    int barrierid;
    Window window;
    Window root;
    double dx = 0;
    double dy = 0;
    double root_x = 0;
    double root_y = 0;
    short dt;
    int event_id;
    uint flags;
}
alias BarrierEvent = _BarrierEvent;

struct _GestureEvent {
    ubyte header; /**< Always ET_Internal */
    EventType type;  /**< One of ET_Gesture{Pinch,Swipe}{Begin,Update,End} */
    int length;           /**< Length in bytes */
    Time time;            /**< Time in ms */
    int deviceid;         /**< Device to post this event for */
    int sourceid;         /**< The physical source device */
    uint num_touches; /**< The number of touches in this gesture */
    double root_x = 0;        /**< Pos relative to root window */
    double root_y = 0;        /**< Pos relative to root window */
    double delta_x = 0;
    double delta_y = 0;
    double delta_unaccel_x = 0;
    double delta_unaccel_y = 0;
    double scale = 0;         /**< Only on ET_GesturePinch{Begin,Update} */
    double delta_angle = 0;   /**< Only on ET_GesturePinch{Begin,Update} */
    struct _Mods {
        uint base;    /**< XKB base modifiers */
        uint latched; /**< XKB latched modifiers */
        uint locked;  /**< XKB locked modifiers */
        uint effective;/**< XKB effective modifiers */
    }_Mods mods;
    struct _Group {
        ubyte base;    /**< XKB base group */
        ubyte latched; /**< XKB latched group */
        ubyte locked;  /**< XKB locked group */
        ubyte effective;/**< XKB effective group */
    }_Group group;
    Window root;      /**< Root window of the event */
    uint flags;   /**< Flags to be copied into the generated event */
}
alias GestureEvent = _GestureEvent;

version (XQUARTZ) {
enum XQUARTZ_EVENT_MAXARGS = 5;
struct _XQuartzEvent {
    ubyte header; /**< Always ET_Internal */
    EventType type;  /**< Always ET_XQuartz */
    int length;           /**< Length in bytes */
    Time time;            /**< Time in ms. */
    int subtype;          /**< Subtype defined by XQuartz DDX */
    uint[XQUARTZ_EVENT_MAXARGS] data; /**< Up to 5 32bit values passed to handler */
}
alias XQuartzEvent = _XQuartzEvent;

}

/**
 * Event type used inside the X server for input event
 * processing.
 */
union _InternalEvent {
    struct _Any {
        ubyte header;     /**< Always ET_Internal */
        EventType type;      /**< One of ET_* */
        int length;               /**< Length in bytes */
        Time time;                /**< Time in ms. */
    }_Any any;
    DeviceEvent device_event;
    DeviceChangedEvent changed_event;
    TouchOwnershipEvent touch_ownership_event;
    BarrierEvent barrier_event;
static if(build.xlibre_server.XFreeXDGA){
    _DGAEvent dga_event;
}
    RawDeviceEvent raw_event;
version (XQUARTZ) {
    XQuartzEvent xquartz_event;
}
    GestureEvent gesture_event;
}
alias InternalEvent = _InternalEvent;


// void LeaveWindow(DeviceIntPtr dev);


