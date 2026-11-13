module externs.X11.extensions.XI2proto;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
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

/* Conventions for this file:
 * Names:
 * structs: always typedef'd, prefixed with xXI, CamelCase
 * struct members: lower_case_with_underscores
 *        Exceptions: reqType, ReqType, repType, RepType, sequenceNumber are
 *        named as such for historical reasons.
 * request opcodes: X_XIRequestName as CamelCase
 * defines: defines used in client applications must go in XI2.h
 *          defines used only in protocol handling: XISOMENAME
 *
 * Data types: unless there is a historical name for a datatype (e.g.
 * Window), use stdint types specifying the size of the datatype.
 * historical data type names must be defined and undefined at the top and
 * end of the file.
 *
 * General:
 * spaces, not tabs.
 * structs specific to a request or reply added before the request
 *      definition. structs used in more than one request, reply or event
 *      appended to the common structs section before the definition of the
 *      first request.
 * members of structs vertically aligned on column 16 if datatypes permit.
 *      otherwise aligned on next available 8n column.
 */

/**
 * Protocol definitions for the XI2 protocol.
 * This file should not be included by clients that merely use XI2, but do not
 * need the wire protocol. Such clients should include XI2.h, or the matching
 * header from the library.
 *
 */
 
import x11.Xproto;
public import x11.X;
public import externs.X11.extensions.XI2;
public import core.stdc.stdint;
import x11.Xmd;

/* make sure types have right sizes for protocol structures. */
// alias Window =  uint;
// alias Time =    uint;
// alias Atom =    uint;
// alias Cursor =  uint;
alias Barrier = uint;

/**
 * XI2 Request opcodes
 */
enum X_XIQueryPointer =                40;
enum X_XIWarpPointer =                 41;
enum X_XIChangeCursor =                42;
enum X_XIChangeHierarchy =             43;
enum X_XISetClientPointer =            44;
enum X_XIGetClientPointer =            45;
enum X_XISelectEvents =                46;
enum X_XIQueryVersion =                47;
enum X_XIQueryDevice =                 48;
enum X_XISetFocus =                    49;
enum X_XIGetFocus =                    50;
enum X_XIGrabDevice =                  51;
enum X_XIUngrabDevice =                52;
enum X_XIAllowEvents =                 53;
enum X_XIPassiveGrabDevice =           54;
enum X_XIPassiveUngrabDevice =         55;
enum X_XIListProperties =              56;
enum X_XIChangeProperty =              57;
enum X_XIDeleteProperty =              58;
enum X_XIGetProperty =                 59;
enum X_XIGetSelectedEvents =           60;
enum X_XIBarrierReleasePointer =       61;

/** Number of XI requests */
enum XI2REQUESTS = (X_XIBarrierReleasePointer - X_XIQueryPointer + 1);
/** Number of XI2 events */
enum XI2EVENTS =   (XI_LASTEVENT + 1);

/*************************************************************************************
 *                                                                                   *
 *                               COMMON STRUCTS                                      *
 *                                                                                   *
 *************************************************************************************/
/** Fixed point 16.16 */
alias FP1616 = int;

/** Fixed point 32.32 */
struct FP3232 {
    int integral;
    uint frac;
}

/**
 * Struct to describe a device.
 *
 * For a MasterPointer or a MasterKeyboard, 'attachment' specifies the
 * paired master device.
 * For a SlaveKeyboard or SlavePointer, 'attachment' specifies the master
 * device this device is attached to.
 * For a FloatingSlave, 'attachment' is undefined.
 */
struct xXIDeviceInfo {
    ushort deviceid;
    ushort use;            /**< ::XIMasterPointer, ::XIMasterKeyboard,
                                     ::XISlavePointer, ::XISlaveKeyboard,
                                     ::XIFloatingSlave */
    ushort attachment;     /**< Current attachment or pairing.*/
    ushort num_classes;    /**< Number of classes following this struct. */
    ushort name_len;       /**< Length of name in bytes. */
    ubyte enabled;        /**< True if device is enabled. */
    ubyte pad;
}

/**
 * Default template for a device class.
 * A device class is equivalent to a device's capabilities. Multiple classes
 * are supported per device.
 */
struct xXIAnyInfo {
    ushort type;           /**< One of *class */
    ushort length;         /**< Length in 4 byte units */
    ushort sourceid;       /**< source device for this class */
    ushort pad;
}

/**
 * Denotes button capability on a device.
 * Struct is followed by a button bit-mask (padded to four byte chunks) and
 * then num_buttons * Atom that names the buttons in the device-native setup
 * (i.e.  ignoring button mappings).
 */
struct xXIButtonInfo {
    ushort type;           /**< Always ButtonClass */
    ushort length;         /**< Length in 4 byte units */
    ushort sourceid;       /**< source device for this class */
    ushort num_buttons;    /**< Number of buttons provided */
}

/**
 * Denotes key capability on a device.
 * Struct is followed by num_keys * CARD32 that lists the keycodes available
 * on the device.
 */
struct xXIKeyInfo {
    ushort type;           /**< Always KeyClass */
    ushort length;         /**< Length in 4 byte units */
    ushort sourceid;       /**< source device for this class */
    ushort num_keycodes;   /**< Number of keys provided */
}

/**
 * Denotes an valuator capability on a device.
 * One XIValuatorInfo describes exactly one valuator (axis) on the device.
 */
struct xXIValuatorInfo {
    ushort type;           /**< Always ValuatorClass       */
    ushort length;         /**< Length in 4 byte units */
    ushort sourceid;       /**< source device for this class */
    ushort number;         /**< Valuator number            */
    Atom label;          /**< Axis label                 */
    FP3232 min;            /**< Min value                  */
    FP3232 max;            /**< Max value                  */
    FP3232 value;          /**< Last published value       */
    uint resolution;     /**< Resolutions in units/m     */
    ubyte mode;           /**< ModeRelative or ModeAbsolute */
    ubyte pad1;
    ushort pad2;
}

/***
 * Denotes a scroll valuator on a device.
 * One XIScrollInfo describes exactly one scroll valuator that must have a
 * XIValuatorInfo struct.
 */
struct xXIScrollInfo {
    ushort type;           /**< Always ValuatorClass         */
    ushort length;         /**< Length in 4 byte units       */
    ushort sourceid;       /**< source device for this class */
    ushort number;         /**< Valuator number              */
    ushort scroll_type;    /**< ::XIScrollTypeVertical, ::XIScrollTypeHorizontal */
    ushort pad0;
    uint flags;          /**< ::XIScrollFlagEmulate, ::XIScrollFlagPreferred   */
    FP3232 increment;      /**< Increment for one unit of scrolling              */
}

/**
 * Denotes multitouch capability on a device.
 */
struct xXITouchInfo {
    ushort type;           /**< Always TouchClass */
    ushort length;         /**< Length in 4 byte units */
    ushort sourceid;       /**< source device for this class */
    ubyte mode;           /**< DirectTouch or DependentTouch */
    ubyte num_touches;    /**< Maximum number of touches (0==unlimited) */
}

/**
 * Denotes touchpad gesture capability on a device.
 */
struct xXIGestureInfo {
    ushort type;           /**< Always GestureClass */
    ushort length;         /**< Length in 4 byte units */
    ushort sourceid;       /**< source device for this class */
    ubyte num_touches;    /**< Maximum number of touches gesture supports (0==unlimited) */
    ubyte pad0;
}

/**
 * Used to select for events on a given window.
 * Struct is followed by (mask_len * CARD8), with each bit set representing
 * the event mask for the given type. A mask bit represents an event type if
 * (mask == (1 << type)).
 */
struct xXIEventMask {
    ushort deviceid;       /**< Device id to select for        */
    ushort mask_len;       /**< Length of mask in 4 byte units */
}

/**
 * XKB modifier information.
 * The effective modifier is a binary mask of base, latched, and locked
 * modifiers.
 */
struct xXIModifierInfo {
    uint base_mods;              /**< Logically pressed modifiers */
    uint latched_mods;           /**< Logically latched modifiers */
    uint locked_mods;            /**< Logically locked modifiers */
    uint effective_mods;         /**< Effective modifiers */
}

/**
 * XKB group information.
 * The effective group is the mathematical sum of base, latched, and locked
 * group after group wrapping is taken into account.
 */
struct xXIGroupInfo {
    ubyte base_group;             /**< Logically "pressed" group */
    ubyte latched_group;          /**< Logically latched group */
    ubyte locked_group;           /**< Logically locked group */
    ubyte effective_group;        /**< Effective group */
}


/*************************************************************************************
 *                                                                                   *
 *                                   REQUESTS                                        *
 *                                                                                   *
 *************************************************************************************/

/**
 * Query the server for the supported X Input extension version.
 */

struct xXIQueryVersionReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XIQueryVersion */
    ushort length;                 /**< Length in 4 byte units */
    ushort major_version;
    ushort minor_version;
}
enum sz_xXIQueryVersionReq =                     8;

struct xXIQueryVersionReply {
    ubyte repType;                /**< ::X_Reply */
    ubyte RepType;                /**< Always ::X_XIQueryVersion */
    ushort sequenceNumber;
    uint length;
    ushort major_version;
    ushort minor_version;
    uint pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
}
enum sz_xXIQueryVersionReply =             32;

/**
 * Query the server for information about a specific device or all input
 * devices.
 */
struct xXIQueryDeviceReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XIQueryDevice */
    ushort length;                 /**< Length in 4 byte units */
    ushort deviceid;
    ushort pad;
}
enum sz_xXIQueryDeviceReq =                    8;

struct xXIQueryDeviceReply {
    ubyte repType;                /**< ::X_Reply */
    ubyte RepType;                /**< Always ::X_XIQueryDevice */
    ushort sequenceNumber;
    uint length;
    ushort num_devices;
    ushort pad0;
    uint pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
}
enum sz_xXIQueryDeviceReply =                  32;

/**
 * Select for events on a given window.
 */
struct xXISelectEventsReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XISelectEvents */
    ushort length;                 /**< Length in 4 byte units */
    Window win;
    ushort num_masks;
    ushort pad;
}
enum sz_xXISelectEventsReq =                  12;

/**
 * Query for selected events on a given window.
 */
struct xXIGetSelectedEventsReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XIGetSelectedEvents */
    ushort length;                 /**< Length in 4 byte units */
    Window win;
}
enum sz_xXIGetSelectedEventsReq =              8;

struct xXIGetSelectedEventsReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always ::X_XIGetSelectedEvents */
    ushort sequenceNumber;
    uint length;
    ushort num_masks;              /**< Number of xXIEventMask structs
                                             trailing the reply */
    ushort pad0;
    uint pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
}
enum sz_xXIGetSelectedEventsReply =            32;

/**
 * Query the given device's screen/window coordinates.
 */

struct xXIQueryPointerReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XIQueryPointer */
    ushort length;                 /**< Length in 4 byte units */
    Window win;
    ushort deviceid;
    ushort pad1;
}
enum sz_xXIQueryPointerReq =                   12;


struct xXIQueryPointerReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always ::X_XIQueryPointer */
    ushort sequenceNumber;
    uint length;
    Window root;
    Window child;
    FP1616 root_x;
    FP1616 root_y;
    FP1616 win_x;
    FP1616 win_y;
    ubyte same_screen;
    ubyte pad0;
    ushort buttons_len;
    xXIModifierInfo mods;
    xXIGroupInfo group;
}
enum sz_xXIQueryPointerReply =                 56;

/**
 * Warp the given device's pointer to the specified position.
 */

struct xXIWarpPointerReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XIWarpPointer   */
    ushort length;                 /**< Length in 4 byte units */
    Window src_win;
    Window dst_win;
    FP1616 src_x;
    FP1616 src_y;
    ushort src_width;
    ushort src_height;
    FP1616 dst_x;
    FP1616 dst_y;
    ushort deviceid;
    ushort pad1;
}
enum sz_xXIWarpPointerReq =                    36;

/**
 * Change the given device's sprite to the given cursor.
 */

struct xXIChangeCursorReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XIChangeCursor  */
    ushort length;                 /**< Length in 4 byte units */
    Window win;
    Cursor cursor;
    ushort deviceid;
    ushort pad1;
}
enum sz_xXIChangeCursorReq =                           16;

/**
 * Modify the device hierarchy.
 */

struct xXIChangeHierarchyReq {
    ubyte reqType;                /**< Input extension major code */
    ubyte ReqType;                /**< Always ::X_XIChangeHierarchy */
    ushort length;                 /**< Length in 4 byte units */
    ubyte num_changes;
    ubyte pad0;
    ushort pad1;
}
enum sz_xXIChangeHierarchyReq =                        8;

/**
 * Generic header for any hierarchy change.
 */
struct xXIAnyHierarchyChangeInfo {
    ushort type;
    ushort length;                 /**< Length in 4 byte units */
}

/**
 * Create a new master device.
 * Name of new master follows struct (4-byte padded)
 */
struct xXIAddMasterInfo {
    ushort type;                   /**< Always ::XIAddMaster */
    ushort length;                 /**< 2 + (namelen + padding)/4 */
    ushort name_len;
    ubyte send_core;
    ubyte enable;
}

/**
 * Delete a master device. Will automatically delete the master device paired
 * with the given master device.
 */
struct xXIRemoveMasterInfo {
    ushort type;            /**< Always ::XIRemoveMaster */
    ushort length;          /**< 3 */
    ushort deviceid;
    ubyte return_mode;     /**< ::XIAttachToMaster, ::XIFloating */
    ubyte pad;
    ushort return_pointer;  /**< Pointer to attach slave ptr devices to */
    ushort return_keyboard; /**< keyboard to attach slave keybd devices to*/
}

/**
 * Attach an SD to a new device.
 * NewMaster has to be of same type (pointer->pointer, keyboard->keyboard);
 */
struct xXIAttachSlaveInfo {
    ushort type;           /**< Always ::XIAttachSlave */
    ushort length;         /**< 2 */
    ushort deviceid;
    ushort new_master;     /**< id of new master device */
}

/**
 * Detach an SD from its current master device.
 */
struct xXIDetachSlaveInfo {
    ushort type;           /**< Always ::XIDetachSlave */
    ushort length;         /**< 2 */
    ushort deviceid;
    ushort pad;
}


/**
 * Set the window/client's ClientPointer.
 */
struct xXISetClientPointerReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XISetClientPointer */
    ushort length;                 /**< Length in 4 byte units */
    Window win;
    ushort deviceid;
    ushort pad1;
}
enum sz_xXISetClientPointerReq =                 12;

/**
 * Query the given window/client's ClientPointer setting.
 */
struct xXIGetClientPointerReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_GetClientPointer */
    ushort length;                 /**< Length in 4 byte units */
    Window win;
}
enum sz_xXIGetClientPointerReq =                 8;

struct xXIGetClientPointerReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always ::X_GetClientPointer */
    ushort sequenceNumber;
    uint length;
    BOOL set;                    /**< client pointer is set? */
    ubyte pad0;
    ushort deviceid;
    uint pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
}
enum sz_xXIGetClientPointerReply =               32;

/**
 * Set the input focus to the specified window.
 */
struct xXISetFocusReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XISetFocus */
    ushort length;                 /**< Length in 4 byte units */
    Window focus;
    Time time;
    ushort deviceid;
    ushort pad0;
}
enum sz_xXISetFocusReq =                       16;

/**
 * Query the current input focus.
 */
struct xXIGetFocusReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIGetDeviceFocus */
    ushort length;                 /**< Length in 4 byte units */
    ushort deviceid;
    ushort pad0;
}
enum sz_xXIGetFocusReq =                       8;

struct xXIGetFocusReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always ::X_XIGetFocus */
    ushort sequenceNumber;
    uint length;
    Window focus;
    uint pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
}
enum sz_xXIGetFocusReply =                     32;


/**
 * Grab the given device.
 */
struct xXIGrabDeviceReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIGrabDevice */
    ushort length;                 /**< Length in 4 byte units */
    Window grab_window;
    Time time;
    Cursor cursor;
    ushort deviceid;
    ubyte grab_mode;
    ubyte paired_device_mode;
    ubyte owner_events;
    ubyte pad;
    ushort mask_len;
}
enum sz_xXIGrabDeviceReq =                     24;

/**
 * Return codes from a XIPassiveGrabDevice request.
 */
struct xXIGrabModifierInfo {
    uint modifiers;              /**< Modifier state */
    ubyte status;                 /**< Grab status code */
    ubyte pad0;
    ushort pad1;
}

struct xXIGrabDeviceReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always ::X_XIGrabDevice */
    ushort sequenceNumber;
    uint length;
    ubyte status;
    ubyte pad0;
    ushort pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
    uint pad6;
}
enum sz_xXIGrabDeviceReply =                  32;

/**
 * Ungrab the specified device.
 *
 */
struct xXIUngrabDeviceReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIUngrabDevice */
    ushort length;                 /**< Length in 4 byte units */
    Time time;
    ushort deviceid;
    ushort pad;
}
enum sz_xXIUngrabDeviceReq =                   12;


/**
 * Allow or replay events on the specified grabbed device.
 */
struct xXIAllowEventsReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIAllowEvents */
    ushort length;                 /**< Length in 4 byte units */
    Time time;
    ushort deviceid;
    ubyte mode;
    ubyte pad;
}
enum sz_xXIAllowEventsReq =                   12;

/**
 * Allow or replay events on the specified grabbed device.
 * Since XI 2.2
 */
struct xXI2_2AllowEventsReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIAllowEvents */
    ushort length;                 /**< Length in 4 byte units */
    Time time;
    ushort deviceid;
    ubyte mode;
    ubyte pad;
    uint touchid;                /**< Since XI 2.2 */
    Window grab_window;            /**< Since XI 2.2 */
}
enum sz_xXI2_2AllowEventsReq =                20;


/**
 * Passively grab the device.
 */
struct xXIPassiveGrabDeviceReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIPassiveGrabDevice */
    ushort length;                 /**< Length in 4 byte units */
    Time time;
    Window grab_window;
    Cursor cursor;
    uint detail;
    ushort deviceid;
    ushort num_modifiers;
    ushort mask_len;
    ubyte grab_type;
    ubyte grab_mode;
    ubyte paired_device_mode;
    ubyte owner_events;
    ushort pad1;
}
enum sz_xXIPassiveGrabDeviceReq =              32;

struct xXIPassiveGrabDeviceReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always ::X_XIPassiveGrabDevice */
    ushort sequenceNumber;
    uint length;
    ushort num_modifiers;
    ushort pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
    uint pad6;
}
enum sz_xXIPassiveGrabDeviceReply =            32;

/**
 * Delete a passive grab for the given device.
 */
struct xXIPassiveUngrabDeviceReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIPassiveUngrabDevice */
    ushort length;                 /**< Length in 4 byte units */
    Window grab_window;
    uint detail;
    ushort deviceid;
    ushort num_modifiers;
    ubyte grab_type;
    ubyte pad0;
    ushort pad1;
}
enum sz_xXIPassiveUngrabDeviceReq =            20;

/**
 * List all device properties on the specified device.
 */
struct xXIListPropertiesReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIListProperties */
    ushort length;                 /**< Length in 4 byte units */
    ushort deviceid;
    ushort pad;
}
enum sz_xXIListPropertiesReq =                 8;

struct xXIListPropertiesReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always ::X_XIListProperties */
    ushort sequenceNumber;
    uint length;
    ushort num_properties;
    ushort pad0;
    uint pad1;
    uint pad2;
    uint pad3;
    uint pad4;
    uint pad5;
}
enum sz_xXIListPropertiesReply =               32;

/**
 * Change a property on the specified device.
 */
struct xXIChangePropertyReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always ::X_XIChangeProperty */
    ushort length;                 /**< Length in 4 byte units */
    ushort deviceid;
    ubyte mode;
    ubyte format;
    Atom property;
    Atom type;
    uint num_items;
}
enum sz_xXIChangePropertyReq =                 20;

/**
 * Delete the specified property.
 */
struct xXIDeletePropertyReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always X_XIDeleteProperty */
    ushort length;                 /**< Length in 4 byte units */
    ushort deviceid;
    ushort pad0;
    Atom property;
}
enum sz_xXIDeletePropertyReq =                 12;

/**
 * Query the specified property's values.
 */
struct xXIGetPropertyReq {
    ubyte reqType;
    ubyte ReqType;                /**< Always X_XIGetProperty */
    ushort length;                 /**< Length in 4 byte units */
    ushort deviceid;
static if (HasVersion!"none" || HasVersion!"c_plusplus") {
    ubyte c_delete;
} else {
    ubyte delete_;
}
    ubyte pad0;
    Atom property;
    Atom type;
    uint offset;
    uint len;
}
enum sz_xXIGetPropertyReq =                    24;

struct xXIGetPropertyReply {
    ubyte repType;                /**< Input extension major opcode */
    ubyte RepType;                /**< Always X_XIGetProperty */
    ushort sequenceNumber;
    uint length;
    Atom type;
    uint bytes_after;
    uint num_items;
    ubyte format;
    ubyte pad0;
    ushort pad1;
    uint pad2;
    uint pad3;
}
enum sz_xXIGetPropertyReply =               32;

struct xXIBarrierReleasePointerInfo {
    ushort deviceid;
    ushort pad;
    Barrier barrier;
    uint eventid;
}

struct xXIBarrierReleasePointerReq {
    ubyte reqType;                /**< Input extension major opcode */
    ubyte ReqType;                /**< Always X_XIBarrierReleasePointer */
    ushort length;
    uint num_barriers;
    /* array of xXIBarrierReleasePointerInfo */
}
enum sz_xXIBarrierReleasePointerReq =       8;

/*************************************************************************************
 *                                                                                   *
 *                                      EVENTS                                       *
 *                                                                                   *
 *************************************************************************************/

/**
 * Generic XI2 event header. All XI2 events use the same header.
 */
struct xXIGenericDeviceEvent {
    ubyte type;
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;
    ushort evtype;
    ushort deviceid;
    Time time;
}

/**
 * Device hierarchy information.
 */
struct xXIHierarchyInfo {
    ushort deviceid;
    ushort attachment;             /**< ID of master or paired device */
    ubyte use;                    /**< ::XIMasterKeyboard,
                                             ::XIMasterPointer,
                                             ::XISlaveKeyboard,
                                             ::XISlavePointer,
                                             ::XIFloatingSlave */
    BOOL enabled;                /**< True if the device is enabled */
    ushort pad;
    uint flags;                  /**< ::XIMasterAdded, ::XIMasterRemoved,
                                             ::XISlaveAttached, ::XISlaveDetached,
                                             ::XISlaveAdded, ::XISlaveRemoved,
                                             ::XIDeviceEnabled, ::XIDeviceDisabled */
}

/**
 * The device hierarchy has been modified. This event includes the device
 * hierarchy after the modification has been applied.
 */
struct xXIHierarchyEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte units */
    ushort evtype;                 /**< ::XI_Hierarchy */
    ushort deviceid;
    Time time;
    uint flags;                  /**< ::XIMasterAdded, ::XIMasterDeleted,
                                             ::XISlaveAttached, ::XISlaveDetached,
                                             ::XISlaveAdded, ::XISlaveRemoved,
                                             ::XIDeviceEnabled, ::XIDeviceDisabled */
    ushort num_info;
    ushort pad0;
    uint pad1;
    uint pad2;
}

/**
 * A device has changed capabilities.
 */
struct xXIDeviceChangedEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte units */
    ushort evtype;                 /**< XI_DeviceChanged */
    ushort deviceid;               /**< Device that has changed */
    Time time;
    ushort num_classes;            /**< Number of classes that have changed */
    ushort sourceid;               /**< Source of the new classes */
    ubyte reason;                 /**< ::XISlaveSwitch, ::XIDeviceChange */
    ubyte pad0;
    ushort pad1;
    uint pad2;
    uint pad3;
}

/**
 * The owner of a touch stream has passed on ownership to another client.
 */
struct xXITouchOwnershipEvent {
    ubyte type;               /**< Always GenericEvent */
    ubyte extension;          /**< XI extension offset */
    ushort sequenceNumber;
    uint length;             /**< Length in 4 byte units */
    ushort evtype;             /**< XI_TouchOwnership */
    ushort deviceid;           /**< Device that has changed */
    Time time;
    uint touchid;
    Window root;
    Window event;
    Window child;
/* └──────── 32 byte boundary ────────┘ */
    ushort sourceid;
    ushort pad0;
    uint flags;
    uint pad1;
    uint pad2;
}

/**
 * Default input event for pointer, keyboard or touch input.
 */
struct xXIDeviceEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte uints */
    ushort evtype;
    ushort deviceid;
    Time time;
    uint detail;                 /**< Keycode or button */
    Window root;
    Window event;
    Window child;
/* └──────── 32 byte boundary ────────┘ */
    FP1616 root_x;                 /**< Always screen coords, 16.16 fixed point */
    FP1616 root_y;
    FP1616 event_x;                /**< Always screen coords, 16.16 fixed point */
    FP1616 event_y;
    ushort buttons_len;            /**< Len of button flags in 4 b units */
    ushort valuators_len;          /**< Len of val. flags in 4 b units */
    ushort sourceid;               /**< The source device */
    ushort pad0;
    uint flags;                  /**< ::XIKeyRepeat */
    xXIModifierInfo mods;
    xXIGroupInfo group;
}


/**
 * Sent when an input event is generated. RawEvents include valuator
 * information in both device-specific data (i.e. unaccelerated) and
 * processed data (i.e. accelerated, if applicable).
 */
struct xXIRawEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte uints */
    ushort evtype;                 /**< ::XI_RawEvent */
    ushort deviceid;
    Time time;
    uint detail;
    ushort sourceid;               /**< The source device (XI 2.1) */
    ushort valuators_len;          /**< Length of trailing valuator
                                             mask in 4 byte units */
    uint flags;                  /**< ::XIKeyRepeat */
    uint pad2;
}

/**
 * Note that the layout of root, event, child, root_x, root_y, event_x,
 * event_y must be identical to the xXIDeviceEvent.
 */
struct xXIEnterEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte uints */
    ushort evtype;                 /**< ::XI_Enter */
    ushort deviceid;
    Time time;
    ushort sourceid;
    ubyte mode;
    ubyte detail;
    Window root;
    Window event;
    Window child;
/* └──────── 32 byte boundary ────────┘ */
    FP1616 root_x;
    FP1616 root_y;
    FP1616 event_x;
    FP1616 event_y;
    BOOL same_screen;
    BOOL focus;
    ushort buttons_len;            /**< Length of trailing button mask
                                             in 4 byte units */
    xXIModifierInfo mods;
    xXIGroupInfo group;
}

alias xXILeaveEvent = xXIEnterEvent;
alias xXIFocusInEvent = xXIEnterEvent;
alias xXIFocusOutEvent = xXIEnterEvent;

/**
 * Sent when a device property is created, modified or deleted. Does not
 * include property data, the client is required to query the data.
 */
struct xXIPropertyEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte units */
    ushort evtype;                 /**< ::XI_PropertyEvent */
    ushort deviceid;
    Time time;
    Atom property;
    ubyte what;                   /**< ::XIPropertyDeleted,
                                             ::XIPropertyCreated,
                                             ::XIPropertyMotified */
    ubyte pad0;
    ushort pad1;
    uint pad2;
    uint pad3;
}

struct xXIBarrierEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte units */
    ushort evtype;                 /**< ::XI_BarrierHit or ::XI_BarrierLeave */
    ushort deviceid;
    Time time;
    uint eventid;
    Window root;
    Window event;
    Barrier barrier;
/* └──────── 32 byte boundary ────────┘ */
    uint dtime;
    uint flags;                  /**< ::XIBarrierPointerReleased
                                             ::XIBarrierDeviceIsGrabbed */
    ushort sourceid;
    short pad;
    FP1616 root_x;
    FP1616 root_y;
    FP3232 dx;
    FP3232 dy;
}

alias xXIBarrierHitEvent = xXIBarrierEvent;
alias xXIBarrierPointerReleasedEvent = xXIBarrierEvent;
alias xXIBarrierLeaveEvent = xXIBarrierEvent;

/**
 * Event for touchpad gesture pinch input events
 */
struct xXIGesturePinchEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte uints */
    ushort evtype;
    ushort deviceid;
    Time time;
    uint detail;                 /**< The number of touches in the gesture */
    Window root;
    Window event;
    Window child;
/* └──────── 32 byte boundary ────────┘ */
    FP1616 root_x;                 /**< Always screen coords, 16.16 fixed point */
    FP1616 root_y;
    FP1616 event_x;                /**< Always screen coords, 16.16 fixed point */
    FP1616 event_y;
    FP1616 delta_x;
    FP1616 delta_y;
    FP1616 delta_unaccel_x;
    FP1616 delta_unaccel_y;
    FP1616 scale;
    FP1616 delta_angle;
    ushort sourceid;               /**< The source device */
    ushort pad0;
    xXIModifierInfo mods;
    xXIGroupInfo group;
    uint flags;                  /**< ::XIGesturePinchEventCancelled */
}

/**
 * Event for touchpad gesture swipe input events
 */
struct xXIGestureSwipeEvent {
    ubyte type;                   /**< Always GenericEvent */
    ubyte extension;              /**< XI extension offset */
    ushort sequenceNumber;
    uint length;                 /**< Length in 4 byte uints */
    ushort evtype;
    ushort deviceid;
    Time time;
    uint detail;                 /**< The number of touches in the gesture */
    Window root;
    Window event;
    Window child;
/* └──────── 32 byte boundary ────────┘ */
    FP1616 root_x;                 /**< Always screen coords, 16.16 fixed point */
    FP1616 root_y;
    FP1616 event_x;                /**< Always screen coords, 16.16 fixed point */
    FP1616 event_y;
    FP1616 delta_x;
    FP1616 delta_y;
    FP1616 delta_unaccel_x;
    FP1616 delta_unaccel_y;
    ushort sourceid;               /**< The source device */
    ushort pad0;
    xXIModifierInfo mods;
    xXIGroupInfo group;
    uint flags;                  /**< ::XIGestureSwipeEventCancelled */
}

 /* _XI2PROTO_H_ */
