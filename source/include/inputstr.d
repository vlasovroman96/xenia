module include.inputstr;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

********************************************************/

 
//public import x11.X;
//public import externs.X11.extensions.XI2proto;

import build.xlibre_server;
public import externs.X11.extensions.XI2;
// //public import externs.X11.extensions.XI2;

public import dsl.pixman;
public import include.input;
public import include.window;
public import include.dixstruct;
public import dix.cursor;
public import include.privates;
import include.xkbsrv;
import include.misyncstr;
import include.xkbstr;


alias CARD8 = x11.Xmd.CARD8;

enum string BitIsOn(string ptr, string bit) = `(!!((cast(const(BYTE)*) (` ~ ptr ~ `))[(` ~ bit ~ `)>>3] & (1 << ((` ~ bit ~ `) & 7))))`;
enum string SetBit(string ptr, string bit) = `((cast(BYTE*) (` ~ ptr ~ `))[(` ~ bit ~ `)>>3] |= (1 << ((` ~ bit ~ `) & 7)));`;
enum string ClearBit(string ptr, string bit) = `((cast(BYTE*)(` ~ ptr ~ `))[(` ~ bit ~ `)>>3] &= ~(1 << ((` ~ bit ~ `) & 7)));`;

enum EMASKSIZE =	(MAXDEVICES + 2);

/* This is the last XI2 event supported by the server. If you add
 * events to the protocol, the server will not support these events until
 * this number here is bumped.
 */
enum XI2LASTEVENT =    XI_GestureSwipeEnd;
enum XI2MASKSIZE =     ((XI2LASTEVENT >> 3) + 1)       /* no of bytes for masks */;

/**
 * Scroll types for ::SetScrollValuator and the scroll type in the
 * ::ScrollInfoPtr.
 */
enum ScrollType {
    SCROLL_TYPE_NONE = 0,           /**< Not a scrolling valuator */
    SCROLL_TYPE_VERTICAL = 8,
    SCROLL_TYPE_HORIZONTAL = 9,
}
alias SCROLL_TYPE_NONE = ScrollType.SCROLL_TYPE_NONE;
alias SCROLL_TYPE_VERTICAL = ScrollType.SCROLL_TYPE_VERTICAL;
alias SCROLL_TYPE_HORIZONTAL = ScrollType.SCROLL_TYPE_HORIZONTAL;


/**
 * This struct stores the core event mask for each client except the client
 * that created the window.
 *
 * Each window that has events selected from other clients has at least one of
 * these masks. If multiple clients selected for events on the same window,
 * these masks are in a linked list.
 *
 * The event mask for the client that created the window is stored in
 * win->eventMask instead.
 *
 * The resource id is simply a fake client ID to associate this mask with a
 * client.
 *
 * Kludge: OtherClients and InputClients must be compatible, see code.
 */
struct _OtherClients {
    OtherClientsPtr next;     /**< Pointer to the next mask */
    XID resource;                 /**< id for putting into resource manager */
    Mask mask;                /**< Core event mask */
}

alias OtherClients = _OtherClients;
/**
 * This struct stores the XI event mask for each client.
 *
 * Each window that has events selected has at least one of these masks. If
 * multiple client selected for events on the same window, these masks are in
 * a linked list.
 */
struct _InputClients {
    InputClientsPtr next;     /**< Pointer to the next mask */
    XID resource;                 /**< id for putting into resource manager */
    Mask[EMASKSIZE] mask;                /**< Actual XI event mask, deviceid is index */
    /** XI2 event masks. One per device, each bit is a mask of (1 << type) */
    _XI2Mask* xi2mask;
}

/**
 * Combined XI event masks from all devices.
 *
 * This is the XI equivalent of the deliverableEvents, eventMask and
 * dontPropagate mask of the WindowRec (or WindowOptRec).
 *
 * A window that has an XI client selecting for events has exactly one
 * OtherInputMasks struct and exactly one InputClients struct hanging off
 * inputClients. Each further client appends to the inputClients list.
 * Each Mask field is per-device, with the device id as the index.
 * Exception: for non-device events (Presence events), the MAXDEVICES
 * deviceid is used.
 */
struct _OtherInputMasks {
    /**
     * Bitwise OR of all masks by all clients and the window's parent's masks.
     */
    Mask[EMASKSIZE] deliverableEvents;
    /**
     * Bitwise OR of all masks by all clients on this window.
     */
    Mask[EMASKSIZE] inputEvents;
    /** The do-not-propagate masks for each device. */
    Mask[EMASKSIZE] dontPropagateMask;
    /** The clients that selected for events */
    InputClientsPtr inputClients;
    /* XI2 event masks. One per device, each bit is a mask of (1 << type) */
    _XI2Mask* xi2mask;
}

alias OtherInputMasks = _OtherInputMasks;
/*
 * The following structure gets used for both active and passive grabs. For
 * active grabs some of the fields (e.g. modifiers) are not used. However,
 * that is not much waste since there aren't many active grabs (one per
 * keyboard/pointer device) going at once in the server.
 */
alias GrabRec = _GrabRec;

struct _DetailRec {     /* Grab details may be bit masks */
    uint exact;
    Mask* pMask;
}

alias DetailRec = _DetailRec;

union _GrabMask {
    Mask core;
    Mask xi;
    _XI2Mask* xi2mask;
}

/**
 * Central struct for device grabs.
 * The same struct is used for both core grabs and device grabs, with
 * different fields being set.
 * If the grab is a core grab (GrabPointer/GrabKeyboard), then the eventMask
 * is a combination of standard event masks (i.e. PointerMotionMask |
 * ButtonPressMask).
 * If the grab is a device grab (GrabDevice), then the eventMask is a
 * combination of event masks for a given XI event type (see SetEventInfo).
 *
 * If the grab is a result of a ButtonPress, then eventMask is the core mask
 * and deviceMask is set to the XI event mask for the grab.
 */
struct _GrabRec {
    GrabPtr next;               /* for chain of passive grabs */
    XID resource;
    DeviceIntPtr device;
    WindowPtr window;
    uint ownerEvents : 1;
    uint keyboardMode : 1;
    uint pointerMode : 1;
    InputLevel grabtype;
    CARD8 type;                 /* event type for passive grabs, 0 for active grabs */
    DetailRec modifiersDetail;
    DeviceIntPtr modifierDevice;
    DetailRec detail;           /* key or button */
    WindowPtr confineTo;        /* always NULL for keyboards */
    CursorPtr cursor;           /* always NULL for keyboards */
    Mask eventMask;
    Mask deviceMask;
    /* XI2 event masks. One per device, each bit is a mask of (1 << type) */
    _XI2Mask* xi2mask;
}

/**
 * Sprite information for a device.
 */
struct _SpriteRec {
    CursorPtr current;
    BoxRec hotLimits;           /* logical constraints of hot spot */
    Bool confined;              /* confined to screen */
    RegionPtr hotShape;         /* additional logical shape constraint */
    BoxRec physLimits;          /* physical constraints of hot spot */
    WindowPtr win;              /* window of logical position */
    HotSpot hot;                /* logical pointer position */
    HotSpot hotPhys;            /* physical pointer position */
static if(XINERAMA){
    ScreenPtr screen;           /* all others are in Screen 0 coordinates */
    RegionRec Reg1;             /* Region 1 for confining motion */
    RegionRec Reg2;             /* Region 2 for confining virtual motion */
    WindowPtr[MAXSCREENS] windows;
    WindowPtr confineWin;       /* confine window */
} /* XINERAMA */
    /* The window trace information is used at dix/events.c to avoid having
     * to compute all the windows between the root and the current pointer
     * window each time a button or key goes down. The grabs on each of those
     * windows must be checked.
     * spriteTraces should only be used at dix/events.c! */
    WindowPtr* spriteTrace;
    int spriteTraceSize;
    int spriteTraceGood;

    /* Due to delays between event generation and event processing, it is
     * possible that the pointer has crossed screen boundaries between the
     * time in which it begins generating events and the time when
     * those events are processed.
     *
     * pEnqueueScreen: screen the pointer was on when the event was generated
     * pDequeueScreen: screen the pointer was on when the event is processed
     */
    ScreenPtr pEnqueueScreen;
    ScreenPtr pDequeueScreen;
}

alias SpriteRec = _SpriteRec;


struct _KeyClassRec {
    int sourceid;
    CARD8[DOWN_LENGTH] down;
    CARD8[DOWN_LENGTH] postdown;
    int[8] modifierKeyCount;
    _XkbSrvInfo* xkbInfo;
}alias KeyClassRec = _KeyClassRec;
alias KeyClassPtr = _KeyClassRec*;

struct _ScrollInfo {
    ScrollType type;
    double increment = 0;
    int flags;
}alias ScrollInfo = _ScrollInfo;
alias ScrollInfoPtr = _ScrollInfo*;

struct _AxisInfo {
    int resolution;
    int min_resolution;
    int max_resolution;
    int min_value;
    int max_value;
    Atom label;
    CARD8 mode;
    ScrollInfo scroll;
}alias AxisInfo = _AxisInfo;
alias AxisInfoPtr = _AxisInfo*;

struct _ValuatorAccelerationRec {
    int number;
    PointerAccelSchemeProc AccelSchemeProc;
    void* accelData;            /* at disposal of AccelScheme */
    PointerAccelSchemeInitProc AccelInitProc;
    DeviceCallbackProc AccelCleanupProc;
}alias ValuatorAccelerationRec = _ValuatorAccelerationRec;
alias ValuatorAccelerationPtr = _ValuatorAccelerationRec*;

struct _ValuatorClass {
    int sourceid;
    int numMotionEvents;
    int first_motion;
    int last_motion;
    void* motion;               /* motion history buffer. Different layout
                                   for MDs and SDs! */
    WindowPtr motionHintWindow;

    AxisInfoPtr axes;
    ushort numAxes;
    double* axisVal;            /* always absolute, but device-coord system */
    ValuatorAccelerationRec accelScheme;
    int h_scroll_axis;          /* horiz smooth-scrolling axis */
    int v_scroll_axis;          /* vert smooth-scrolling axis */
}

alias _ValuatorClassRec = _ValuatorClass;

struct TouchListener {
    XID listener;           /* grabs/event selection IDs receiving
                             * events for this touch */
    int resource_type;      /* listener's resource type */
    TouchListenerType type;
    TouchListenerState state;
    InputLevel level;  /* matters only for emulating touches */
    WindowPtr window;
    GrabPtr grab;
}

struct _TouchPointInfo {
    uint client_id;         /* touch ID as seen in client events */
    int sourceid;               /* Source device's ID for this touchpoint */
    Bool active;                /* whether or not the touch is active */
    Bool pending_finish;        /* true if the touch is physically inactive
                                 * but still owned by a grab */
    SpriteRec sprite;           /* window trace for delivery */
    ValuatorMask* valuators;    /* last recorded axis values */
    TouchListener* listeners;   /* set of listeners */
    int num_listeners;
    int num_grabs;              /* number of open grabs on this touch
                                 * which have not accepted or rejected */
    Bool emulate_pointer;
    DeviceEvent* history;       /* History of events on this touchpoint */
    size_t history_elements;    /* Number of current elements in history */
    size_t history_size;        /* Size of history in elements */
}
alias TouchPointInfoRec = _TouchPointInfo;

struct _TouchClassRec {
    int sourceid;
    TouchPointInfoPtr touches;
    ushort num_touches; /* number of allocated touches */
    ushort max_touches; /* maximum number of touches, may be 0 */
    CARD8 mode;                 /* ::XIDirectTouch, XIDependentTouch */
    /* for pointer-emulation */
    CARD8 buttonsDown;          /* number of buttons down */
    ushort state;       /* logical button state */
    Mask motionMask;
}

alias TouchClassRec = _TouchClassRec;

struct GestureListener {
    XID listener;           /* grabs/event selection IDs receiving
                             * events for this gesture */
    int resource_type;      /* listener's resource type */
    GestureListenerType type;
    WindowPtr window;
    GrabPtr grab;
}

struct _GestureInfo {
    int sourceid;               /* Source device's ID for this gesture */
    Bool active;                /* whether or not the gesture is active */
    ubyte type;               /* Gesture type: either ET_GesturePinchBegin or
                                   ET_GestureSwipeBegin. Valid if active == TRUE */
    int num_touches;            /* The number of touches in the gesture */
    SpriteRec sprite;           /* window trace for delivery */
    GestureListener listener;   /* the listener that will receive events */
    Bool has_listener;          /* true if listener has been setup already */
}

alias GestureInfoRec = _GestureInfo;

struct _GestureClassRec {
    int sourceid;
    GestureInfoRec gesture;
    ushort max_touches; /* maximum number of touches, may be 0 */
}

struct _ButtonClassRec {
    int sourceid;
    CARD8 numButtons;
    CARD8 buttonsDown;          /* number of buttons currently down
                                   This counts logical buttons, not
                                   physical ones, i.e if some buttons
                                   are mapped to 0, they're not counted
                                   here */
    ushort state;
    Mask motionMask;
    CARD8[DOWN_LENGTH] down;
    CARD8[DOWN_LENGTH] postdown;
    CARD8[MAP_LENGTH] map;
    _XkbAction* xkb_acts;
    Atom[MAX_BUTTONS] labels;
}alias ButtonClassRec = _ButtonClassRec;
alias ButtonClassPtr = _ButtonClassRec*;

struct _FocusClassRec {
    int sourceid;
    WindowPtr win;              /* May be set to a int constant (e.g. PointerRootWin)! */
    int revert;
    TimeStamp time;
    WindowPtr* trace;
    int traceSize;
    int traceGood;
}alias FocusClassRec = _FocusClassRec;
alias FocusClassPtr = _FocusClassRec*;

struct _ProximityClassRec {
    int sourceid;
    char in_proximity = 0;
}alias ProximityClassRec = _ProximityClassRec;
alias ProximityClassPtr = _ProximityClassRec*;

alias KbdFeedbackPtr = _KbdFeedbackClassRec*;
alias PtrFeedbackPtr = _PtrFeedbackClassRec*;
alias IntegerFeedbackPtr = _IntegerFeedbackClassRec*;
alias StringFeedbackPtr = _StringFeedbackClassRec*;
alias BellFeedbackPtr = _BellFeedbackClassRec*;
alias LedFeedbackPtr = _LedFeedbackClassRec*;

struct _KbdFeedbackClassRec {
    BellProcPtr BellProc;
    KbdCtrlProcPtr CtrlProc;
    KeybdCtrl ctrl;
    KbdFeedbackPtr next;
    _XkbSrvLedInfo* xkb_sli;
}

alias KbdFeedbackClassRec = _KbdFeedbackClassRec;

struct _PtrFeedbackClassRec {
    PtrCtrlProcPtr CtrlProc;
    PtrCtrl ctrl;
    PtrFeedbackPtr next;
}

alias PtrFeedbackClassRec = _PtrFeedbackClassRec;

struct _IntegerFeedbackClassRec {
    IntegerCtrlProcPtr CtrlProc;
    IntegerCtrl ctrl;
    IntegerFeedbackPtr next;
}
alias IntegerFeedbackClassRec = _IntegerFeedbackClassRec;

struct _StringFeedbackClassRec {
    StringCtrlProcPtr CtrlProc;
    StringCtrl ctrl;
    StringFeedbackPtr next;
}

alias StringFeedbackClassRec = _StringFeedbackClassRec;


struct _BellFeedbackClassRec {
    BellProcPtr BellProc;
    BellCtrlProcPtr CtrlProc;
    BellCtrl ctrl;
    BellFeedbackPtr next;
}

alias BellFeedbackClassRec = _BellFeedbackClassRec;

struct _LedFeedbackClassRec {
    LedCtrlProcPtr CtrlProc;
    LedCtrl ctrl;
    LedFeedbackPtr next;
    _XkbSrvLedInfo* xkb_sli;
}

alias LedFeedbackClassRec = _LedFeedbackClassRec;

struct _ClassesRec {
    KeyClassPtr key;
    ValuatorClassPtr valuator;
    TouchClassPtr touch;
    GestureClassPtr gesture;
    ButtonClassPtr button;
    FocusClassPtr focus;
    ProximityClassPtr proximity;
    KbdFeedbackPtr kbdfeed;
    PtrFeedbackPtr ptrfeed;
    IntegerFeedbackPtr intfeed;
    StringFeedbackPtr stringfeed;
    BellFeedbackPtr bell;
    LedFeedbackPtr leds;
}

/* Device properties */
struct XIPropertyValueRec {
    Atom type;                  /* ignored by server */
    short format;               /* format of data for swapping - 8,16,32 */
    c_long size;                  /* size of data in (format/8) bytes */
    void* data;                 /* private to client */
}

struct _XIProperty {
    _XIProperty* next;
    Atom propertyName;
    BOOL deletable;             /* clients can delete this prop? */
    XIPropertyValueRec value;
}

alias XIPropertyRec = _XIProperty;
alias XIPropertyPtr = XIPropertyRec*;
alias XIPropertyValuePtr = XIPropertyValueRec*;

struct _XIPropertyHandler {
    _XIPropertyHandler* next;
    c_long id;
    @nogc nothrow int function(DeviceIntPtr dev, Atom property, XIPropertyValuePtr prop, BOOL checkonly) SetProperty;
    @nogc nothrow int function(DeviceIntPtr dev, Atom property) GetProperty;
    @nogc nothrow int function(DeviceIntPtr dev, Atom property) DeleteProperty;
}alias XIPropertyHandler = _XIPropertyHandler;
alias XIPropertyHandlerPtr = _XIPropertyHandler*;

struct _GrabInfoRec {
    TimeStamp grabTime;
    Bool fromPassiveGrab;       /* true if from passive grab */
    Bool implicitGrab;          /* implicit from ButtonPress */
    GrabPtr unused;             /* Kept for ABI stability, remove soon */
    GrabPtr grab;
    CARD8 activatingKey;
    @nogc nothrow void function(DeviceIntPtr, GrabPtr, TimeStamp, Bool) ActivateGrab;
    @nogc nothrow void function(DeviceIntPtr) DeactivateGrab;
    struct _Sync {
        Bool frozen;
        int state;
        GrabPtr other;          /* if other grab has this frozen */
        InternalEvent* event;   /* saved to be replayed */
    }_Sync sync;
}alias GrabInfoRec = _GrabInfoRec;
alias GrabInfoPtr = _GrabInfoRec*;

struct _SpriteInfoRec {
    /* sprite must always point to a valid sprite. For devices sharing the
     * sprite, let sprite point to a paired spriteOwner's sprite. */
    SpritePtr sprite;           /* sprite information */
    Bool spriteOwner;           /* True if device owns the sprite */
    DeviceIntPtr paired;        /* The paired device. Keyboard if
                                   spriteOwner is TRUE, otherwise the
                                   pointer that owns the sprite. */

    /* keep states for animated cursor */
    struct _Anim {
        CursorPtr pCursor;
        ScreenPtr pScreen;
        int elt;
    }_Anim anim;
}alias SpriteInfoRec = _SpriteInfoRec;
alias SpriteInfoPtr = _SpriteInfoRec*;

/* device types */
enum MASTER_POINTER =          1;
enum MASTER_KEYBOARD =         2;
enum SLAVE =                   3;
/* special types for GetMaster */
enum MASTER_ATTACHED =         4       /* Master for this device */;
enum KEYBOARD_OR_FLOAT =       5       /* Keyboard master for this device or this device if floating */;
enum POINTER_OR_FLOAT =        6       /* Pointer master for this device or this device if floating */;

struct DeviceIntRec {
    DeviceRec public_;
    DeviceIntPtr next;
    Bool startup;               /* true if needs to be turned on at
                                   server initialization time */
    DeviceProc deviceProc;      /* proc(DevicePtr, DEVICE_xx). It is
                                   used to initialize, turn on, or
                                   turn off the device */
    Bool inited;                /* TRUE if INIT returns Success */
    Bool enabled;               /* TRUE if ON returns Success */
    Bool coreEvents;            /* TRUE if device also sends core */
    GrabInfoRec deviceGrab;     /* grab on the device */
    int type;                   /* MASTER_POINTER, MASTER_KEYBOARD, SLAVE */
    Atom xinput_type;
    char* name;
    int id;
    KeyClassPtr key;
    ValuatorClassPtr valuator;
    TouchClassPtr touch;
    GestureClassPtr gesture;
    ButtonClassPtr button;
    FocusClassPtr focus;
    ProximityClassPtr proximity;
    KbdFeedbackPtr kbdfeed;
    PtrFeedbackPtr ptrfeed;
    IntegerFeedbackPtr intfeed;
    StringFeedbackPtr stringfeed;
    BellFeedbackPtr bell;
    LedFeedbackPtr leds;
    _XkbInterest* xkb_interest;
    char* config_info;          /* used by the hotplug layer */
    ClassesPtr unused_classes;  /* for master devices */
    int saved_master_id;        /* for slaves while grabbed */
    PrivateRec* devPrivates;
    DeviceUnwrapProc unwrapProc;
    SpriteInfoPtr spriteInfo;
    DeviceIntPtr master;        /* master device */
    DeviceIntPtr lastSlave;     /* last slave device used */

    /* last valuator values recorded, not posted to client;
     * for slave devices, valuators is in device coordinates, mapped to the
     * desktop
     * for master devices, valuators is in desktop coordinates.
     * see dix/getevents.c
     * remainder supports acceleration
     */
    struct _Last {
        double[MAX_VALUATORS] valuators = 0;
        int numValuators;
        DeviceIntPtr slave;
        ValuatorMask* scroll;
        int num_touches;        /* size of the touches array */
        DDXTouchPointInfoPtr touches;
    }
    _Last last;

    /* Input device property handling. */
    struct _Properties {
        XIPropertyPtr properties;
        XIPropertyHandlerPtr handlers;  /* NULL-terminated */
    }_Properties properties;

    /* coordinate transformation matrix for relative movement. Matrix with
     * the translation component dropped */
    pixman_f_transform relative_transform;
    /* scale matrix for absolute devices, this is the combined matrix of
       [1/scale] . [transform] . [scale]. See DeviceSetTransform */
    pixman_f_transform scale_and_transform;

    /* XTest related master device id */
    int xtest_master_id;
    DeviceSendEventsProc sendEventsProc;

    _SyncCounter* idle_counter;

    Bool ignoreXkbActionsBehaviors; /* TRUE if keys don't trigger behaviors and actions */
}

struct InputInfo {
    int numDevices;             /* total number of devices */
    DeviceIntPtr devices;       /* all devices turned on */
    DeviceIntPtr off_devices;   /* all devices turned off */
    DeviceIntPtr keyboard;      /* the main one for the server */
    DeviceIntPtr pointer;
    DeviceIntPtr all_devices;
    DeviceIntPtr all_master_devices;
}

// InputInfo inputInfo;

/* for keeping the events for devices grabbed synchronously */
struct _QdEvent {
    xorg_list next;
    DeviceIntPtr device;
    ScreenPtr pScreen;          /* what screen the pointer was on */
    c_ulong months;       /* milliseconds is in the event */
    InternalEvent* event;
}

alias QdEventPtr = _QdEvent*;
alias QdEventRec = _QdEvent;

/**
 * syncEvents is the global structure for queued events.
 *
 * Devices can be frozen through GrabModeSync pointer grabs. If this is the
 * case, events from these devices are added to "pending" instead of being
 * processed normally. When the device is unfrozen, events in "pending" are
 * replayed and processed as if they would come from the device directly.
 */
struct _EventSyncInfo {
    xorg_list pending;

    /** The device to replay events for. Only set in AllowEvents(), in which
     * case it is set to the device specified in the request. */
    DeviceIntPtr replayDev;     /* kludgy rock to put flag for */

    /**
     * The window the events are supposed to be replayed on.
     * This window may be set to the grab's window (but only when
     * Replay{Pointer|Keyboard} is given in the XAllowEvents()
     * request. */
    WindowPtr replayWin;        /*   ComputeFreezes            */
    /**
     * Flag to indicate whether we're in the process of
     * replaying events. Only set in ComputeFreezes(). */
    Bool playingEvents;
    TimeStamp time;
}alias EventSyncInfoRec = _EventSyncInfo;
alias EventSyncInfoPtr = _EventSyncInfo*;

// EventSyncInfoRec syncEvents;

/**
 * Given a sprite, returns the window at the bottom of the trace (i.e. the
 * furthest window from the root).
 */
pragma(inline, true) WindowPtr DeepestSpriteWin(SpritePtr sprite)
{
    assert(sprite.spriteTraceGood > 0);
    return sprite.spriteTrace[sprite.spriteTraceGood - 1];
}

struct _XI2Mask {
    ubyte** masks;      /* event mask in masks[deviceid][event type byte] */
    size_t nmasks;              /* number of masks */
    size_t mask_size;           /* size of each mask in bytes */
}

                          /* INPUTSTRUCT_H */
