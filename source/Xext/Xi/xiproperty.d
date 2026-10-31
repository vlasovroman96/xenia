module Xi.xiproperty;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2006 Keith Packard
 * Copyright © 2008 Peter Hutterer
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
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WAXIANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WAXIANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 */

/* This code is a modified version of randr/rrproperty.c */

import build.dix_config;

import externs.X11.Xatom;
//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;
import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.extension_priv;
import dix.input_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import Xi.handlers;

import include.dix;
import include.inputstr;
import Xi.exglobals;
import dix.swaprep;
import Xi.xiproperty;
import include.xserver_properties;
// import externs.X11.Xatom;
import dix.devices;
import dix.events;
import os.inputthread;


/**
 * Properties used or alloced from inside the server.
 */
struct dev_properties_ {
    Atom type;
    const(char)* name;
}
private dev_properties_[128] dev_properties = [
    {0, XI_PROP_ENABLED},
    {0, XI_PROP_XTEST_DEVICE},
    {0, XATOM_FLOAT},
    {0, ACCEL_PROP_PROFILE_NUMBER},
    {0, ACCEL_PROP_CONSTANT_DECELERATION},
    {0, ACCEL_PROP_ADAPTIVE_DECELERATION},
    {0, ACCEL_PROP_VELOCITY_SCALING},
    {0, AXIS_LABEL_PROP},
    {0, AXIS_LABEL_PROP_REL_X},
    {0, AXIS_LABEL_PROP_REL_Y},
    {0, AXIS_LABEL_PROP_REL_Z},
    {0, AXIS_LABEL_PROP_REL_RX},
    {0, AXIS_LABEL_PROP_REL_RY},
    {0, AXIS_LABEL_PROP_REL_RZ},
    {0, AXIS_LABEL_PROP_REL_HWHEEL},
    {0, AXIS_LABEL_PROP_REL_DIAL},
    {0, AXIS_LABEL_PROP_REL_WHEEL},
    {0, AXIS_LABEL_PROP_REL_MISC},
    {0, AXIS_LABEL_PROP_REL_VSCROLL},
    {0, AXIS_LABEL_PROP_REL_HSCROLL},
    {0, AXIS_LABEL_PROP_ABS_X},
    {0, AXIS_LABEL_PROP_ABS_Y},
    {0, AXIS_LABEL_PROP_ABS_Z},
    {0, AXIS_LABEL_PROP_ABS_RX},
    {0, AXIS_LABEL_PROP_ABS_RY},
    {0, AXIS_LABEL_PROP_ABS_RZ},
    {0, AXIS_LABEL_PROP_ABS_THROTTLE},
    {0, AXIS_LABEL_PROP_ABS_RUDDER},
    {0, AXIS_LABEL_PROP_ABS_WHEEL},
    {0, AXIS_LABEL_PROP_ABS_GAS},
    {0, AXIS_LABEL_PROP_ABS_BRAKE},
    {0, AXIS_LABEL_PROP_ABS_HAT0X},
    {0, AXIS_LABEL_PROP_ABS_HAT0Y},
    {0, AXIS_LABEL_PROP_ABS_HAT1X},
    {0, AXIS_LABEL_PROP_ABS_HAT1Y},
    {0, AXIS_LABEL_PROP_ABS_HAT2X},
    {0, AXIS_LABEL_PROP_ABS_HAT2Y},
    {0, AXIS_LABEL_PROP_ABS_HAT3X},
    {0, AXIS_LABEL_PROP_ABS_HAT3Y},
    {0, AXIS_LABEL_PROP_ABS_PRESSURE},
    {0, AXIS_LABEL_PROP_ABS_DISTANCE},
    {0, AXIS_LABEL_PROP_ABS_TILT_X},
    {0, AXIS_LABEL_PROP_ABS_TILT_Y},
    {0, AXIS_LABEL_PROP_ABS_TOOL_WIDTH},
    {0, AXIS_LABEL_PROP_ABS_VOLUME},
    {0, AXIS_LABEL_PROP_ABS_MT_TOUCH_MAJOR},
    {0, AXIS_LABEL_PROP_ABS_MT_TOUCH_MINOR},
    {0, AXIS_LABEL_PROP_ABS_MT_WIDTH_MAJOR},
    {0, AXIS_LABEL_PROP_ABS_MT_WIDTH_MINOR},
    {0, AXIS_LABEL_PROP_ABS_MT_ORIENTATION},
    {0, AXIS_LABEL_PROP_ABS_MT_POSITION_X},
    {0, AXIS_LABEL_PROP_ABS_MT_POSITION_Y},
    {0, AXIS_LABEL_PROP_ABS_MT_TOOL_TYPE},
    {0, AXIS_LABEL_PROP_ABS_MT_BLOB_ID},
    {0, AXIS_LABEL_PROP_ABS_MT_TRACKING_ID},
    {0, AXIS_LABEL_PROP_ABS_MT_PRESSURE},
    {0, AXIS_LABEL_PROP_ABS_MT_DISTANCE},
    {0, AXIS_LABEL_PROP_ABS_MT_TOOL_X},
    {0, AXIS_LABEL_PROP_ABS_MT_TOOL_Y},
    {0, AXIS_LABEL_PROP_ABS_MISC},
    {0, BTN_LABEL_PROP},
    {0, BTN_LABEL_PROP_BTN_UNKNOWN},
    {0, BTN_LABEL_PROP_BTN_WHEEL_UP},
    {0, BTN_LABEL_PROP_BTN_WHEEL_DOWN},
    {0, BTN_LABEL_PROP_BTN_HWHEEL_LEFT},
    {0, BTN_LABEL_PROP_BTN_HWHEEL_RIGHT},
    {0, BTN_LABEL_PROP_BTN_0},
    {0, BTN_LABEL_PROP_BTN_1},
    {0, BTN_LABEL_PROP_BTN_2},
    {0, BTN_LABEL_PROP_BTN_3},
    {0, BTN_LABEL_PROP_BTN_4},
    {0, BTN_LABEL_PROP_BTN_5},
    {0, BTN_LABEL_PROP_BTN_6},
    {0, BTN_LABEL_PROP_BTN_7},
    {0, BTN_LABEL_PROP_BTN_8},
    {0, BTN_LABEL_PROP_BTN_9},
    {0, BTN_LABEL_PROP_BTN_LEFT},
    {0, BTN_LABEL_PROP_BTN_RIGHT},
    {0, BTN_LABEL_PROP_BTN_MIDDLE},
    {0, BTN_LABEL_PROP_BTN_SIDE},
    {0, BTN_LABEL_PROP_BTN_EXTRA},
    {0, BTN_LABEL_PROP_BTN_FORWARD},
    {0, BTN_LABEL_PROP_BTN_BACK},
    {0, BTN_LABEL_PROP_BTN_TASK},
    {0, BTN_LABEL_PROP_BTN_TRIGGER},
    {0, BTN_LABEL_PROP_BTN_THUMB},
    {0, BTN_LABEL_PROP_BTN_THUMB2},
    {0, BTN_LABEL_PROP_BTN_TOP},
    {0, BTN_LABEL_PROP_BTN_TOP2},
    {0, BTN_LABEL_PROP_BTN_PINKIE},
    {0, BTN_LABEL_PROP_BTN_BASE},
    {0, BTN_LABEL_PROP_BTN_BASE2},
    {0, BTN_LABEL_PROP_BTN_BASE3},
    {0, BTN_LABEL_PROP_BTN_BASE4},
    {0, BTN_LABEL_PROP_BTN_BASE5},
    {0, BTN_LABEL_PROP_BTN_BASE6},
    {0, BTN_LABEL_PROP_BTN_DEAD},
    {0, BTN_LABEL_PROP_BTN_A},
    {0, BTN_LABEL_PROP_BTN_B},
    {0, BTN_LABEL_PROP_BTN_C},
    {0, BTN_LABEL_PROP_BTN_X},
    {0, BTN_LABEL_PROP_BTN_Y},
    {0, BTN_LABEL_PROP_BTN_Z},
    {0, BTN_LABEL_PROP_BTN_TL},
    {0, BTN_LABEL_PROP_BTN_TR},
    {0, BTN_LABEL_PROP_BTN_TL2},
    {0, BTN_LABEL_PROP_BTN_TR2},
    {0, BTN_LABEL_PROP_BTN_SELECT},
    {0, BTN_LABEL_PROP_BTN_START},
    {0, BTN_LABEL_PROP_BTN_MODE},
    {0, BTN_LABEL_PROP_BTN_THUMBL},
    {0, BTN_LABEL_PROP_BTN_THUMBR},
    {0, BTN_LABEL_PROP_BTN_TOOL_PEN},
    {0, BTN_LABEL_PROP_BTN_TOOL_RUBBER},
    {0, BTN_LABEL_PROP_BTN_TOOL_BRUSH},
    {0, BTN_LABEL_PROP_BTN_TOOL_PENCIL},
    {0, BTN_LABEL_PROP_BTN_TOOL_AIRBRUSH},
    {0, BTN_LABEL_PROP_BTN_TOOL_FINGER},
    {0, BTN_LABEL_PROP_BTN_TOOL_MOUSE},
    {0, BTN_LABEL_PROP_BTN_TOOL_LENS},
    {0, BTN_LABEL_PROP_BTN_TOUCH},
    {0, BTN_LABEL_PROP_BTN_STYLUS},
    {0, BTN_LABEL_PROP_BTN_STYLUS2},
    {0, BTN_LABEL_PROP_BTN_TOOL_DOUBLETAP},
    {0, BTN_LABEL_PROP_BTN_TOOL_TRIPLETAP},
    {0, BTN_LABEL_PROP_BTN_GEAR_DOWN},
    {0, BTN_LABEL_PROP_BTN_GEAR_UP},
    {0, XI_PROP_TRANSFORM}
];

private c_long XIPropHandlerID = 1;

private void send_property_event(DeviceIntPtr dev, Atom property, int what)
{
    int state = (what == XIPropertyDeleted) ? PropertyDelete : PropertyNewValue;
    devicePropertyNotify event = {
        type: cast(ubyte)DevicePropertyNotify,
        deviceid: cast(ubyte)dev.id,
        state:cast(ubyte) state,
        atom: cast(uint)property,
        time: currentTime.milliseconds
    };
    xXIPropertyEvent xi2 = {
        type: GenericEvent,
        extension: EXTENSION_MAJOR_XINPUT,
        length: 0,
        evtype: XI_PropertyEvent,
        deviceid: cast(ushort)dev.id,
        time: currentTime.milliseconds,
        property: cast(uint)property,
        what: cast(ubyte)what
    };

    SendEventToAllWindows(dev, DevicePropertyNotifyMask, cast(xEvent*) &event, 1);

    SendEventToAllWindows(dev, GetEventFilter(dev, cast(xEvent*) &xi2),
                          cast(xEvent*) &xi2, 1);
}

private int get_property(ClientPtr client, DeviceIntPtr dev, Atom property, Atom type, Bool delete_, int offset, int length, int* bytes_after, Atom* type_return, int* format, int* nitems, int* length_return, char** data)
{
    c_ulong n = void, len = void, ind = void;
    int rc = void;
    XIPropertyPtr prop = void;
    XIPropertyValuePtr prop_value = void;

    if (!ValidAtom(property)) {
        client.errorValue = cast(uint)property;
        return BadAtom;
    }
    if ((delete_ != xTrue) && (delete_ != xFalse)) {
        client.errorValue = cast(uint)delete_;
        return BadValue;
    }

    if ((type != AnyPropertyType) && !ValidAtom(type)) {
        client.errorValue = cast(uint)type;
        return BadAtom;
    }

    for (prop = dev.properties.properties; prop; prop = prop.next)
        if (prop.propertyName == property)
            break;

    if (!prop) {
        *bytes_after = 0;
        *type_return = None;
        *format = 0;
        *nitems = 0;
        *length_return = 0;
        return Success;
    }

    rc = XIGetDeviceProperty(dev, property, &prop_value);
    if (rc != Success) {
        client.errorValue = cast(uint)property;
        return rc;
    }

    /* If the request type and actual type don't match. Return the
       property information, but not the data. */

    if (((type != prop_value.type) && (type != AnyPropertyType))) {
        *bytes_after = cast(int)prop_value.size;
        *format = prop_value.format;
        *length_return = 0;
        *nitems = 0;
        *type_return = prop_value.type;
        return Success;
    }

    /* Return type, format, value to client */
    n = (prop_value.format / 8) * prop_value.size;    /* size (bytes) of prop */
    ind = offset << 2;

    /* If offset is invalid such that it causes "len" to
       be negative, it's a value error. */

    if (n < ind) {
        client.errorValue = cast(uint)offset;
        return BadValue;
    }

    len = min(n - ind, 4 * length);

    *bytes_after = cast(int)(n - (ind + len));
    *format = prop_value.format;
    *length_return = cast(int)len;
    if (prop_value.format)
        *nitems = cast(int)(len / (prop_value.format / 8));
    else
        *nitems = 0;
    *type_return = prop_value.type;

    *data = cast(char*) prop_value.data + ind;

    return Success;
}

private int check_change_property(ClientPtr client, Atom property, Atom type, int format, int mode, int nitems)
{
    if ((mode != PropModeReplace) && (mode != PropModeAppend) &&
        (mode != PropModePrepend)) {
        client.errorValue = cast(uint)mode;
        return BadValue;
    }
    if ((format != 8) && (format != 16) && (format != 32)) {
        client.errorValue = cast(uint)format;
        return BadValue;
    }

    if (!ValidAtom(property)) {
        client.errorValue = cast(uint)property;
        return BadAtom;
    }
    if (!ValidAtom(type)) {
        client.errorValue = cast(uint)type;
        return BadAtom;
    }

    return Success;
}

private int change_property(ClientPtr client, DeviceIntPtr dev, Atom property, Atom type, int format, int mode, int len, void* data)
{
    int rc = Success;

    rc = XIChangeDeviceProperty(dev, property, type, format, mode, len, data,
                                TRUE);
    if (rc != Success)
        client.errorValue = cast(uint)property;

    return rc;
}

/**
 * Return the atom assigned to the specified string or 0 if the atom isn't known
 * to the DIX.
 *
 * If name is NULL, None is returned.
 */
Atom XIGetKnownProperty(const(char)* name)
{
    int i = void;

    if (!name)
        return None;

    for (i = 0; i < dev_properties.length; i++) {
        if (strcmp(name, dev_properties[i].name) == 0) {
            if (dev_properties[i].type == None)
                dev_properties[i].type = dixAddAtom(dev_properties[i].name);
            return dev_properties[i].type;
        }
    }

    return 0;
}

void XIResetProperties()
{
    int i = void;

    for (i = 0; i < dev_properties.length; i++)
        dev_properties[i].type = None;
}

/**
 * Convert the given property's value(s) into @nelem_return integer values and
 * store them in @buf_return. If @nelem_return is larger than the number of
 * values in the property, @nelem_return is set to the number of values in the
 * property.
 *
 * If *@buf_return is NULL and @nelem_return is 0, memory is allocated
 * automatically and must be freed by the caller.
 *
 * Possible return codes.
 * Success ... No error.
 * BadMatch ... Wrong atom type, atom is not XA_INTEGER
 * BadAlloc ... NULL passed as buffer and allocation failed.
 * BadLength ... @buff is NULL but @nelem_return is non-zero.
 *
 * @param val The property value
 * @param nelem_return The maximum number of elements to return.
 * @param buf_return Pointer to an array of at least @nelem_return values.
 * @return Success or the error code if an error occurred.
 */
int XIPropToInt(XIPropertyValuePtr val, int* nelem_return, int** buf_return)
{
    int i = void;
    int* buf = void;

    if (val.type != XA_INTEGER)
        return BadMatch;
    if (!*buf_return && *nelem_return)
        return BadLength;

    switch (val.format) {
    case 8:
    case 16:
    case 32:
        break;
    default:
        return BadValue;
    }

    buf = *buf_return;

    if (!buf && !(*nelem_return)) {
        buf = cast(int*) calloc(val.size, int.sizeof);
        if (!buf)
            return BadAlloc;
        *buf_return = buf;
        *nelem_return = cast(int)val.size;
    }
    else if (cast(int)val.size < *nelem_return)
        *nelem_return = cast(int)val.size;

    for (i = 0; i < val.size && i < *nelem_return; i++) {
        switch (val.format) {
        case 8:
            buf[i] = (cast(CARD8*) val.data)[i];
            break;
        case 16:
            buf[i] = (cast(CARD16*) val.data)[i];
            break;
        case 32:
            buf[i] = cast(int)(cast(CARD32*) val.data)[i];
            break;
        default: break;}
    }

    return Success;
}

/**
 * Convert the given property's value(s) into @nelem_return float values and
 * store them in @buf_return. If @nelem_return is larger than the number of
 * values in the property, @nelem_return is set to the number of values in the
 * property.
 *
 * If *@buf_return is NULL and @nelem_return is 0, memory is allocated
 * automatically and must be freed by the caller.
 *
 * Possible errors returned:
 * Success
 * BadMatch ... Wrong atom type, atom is not XA_FLOAT
 * BadValue ... Wrong format, format is not 32
 * BadAlloc ... NULL passed as buffer and allocation failed.
 * BadLength ... @buff is NULL but @nelem_return is non-zero.
 *
 * @param val The property value
 * @param nelem_return The maximum number of elements to return.
 * @param buf_return Pointer to an array of at least @nelem_return values.
 * @return Success or the error code if an error occurred.
 */
int XIPropToFloat(XIPropertyValuePtr val, int* nelem_return, float** buf_return)
{
    int i = void;
    float* buf = void;

    if (!val.type || val.type != XIGetKnownProperty(XATOM_FLOAT))
        return BadMatch;

    if (val.format != 32)
        return BadValue;
    if (!*buf_return && *nelem_return)
        return BadLength;

    buf = *buf_return;

    if (!buf && !(*nelem_return)) {
        buf = cast(float*) calloc(val.size, float.sizeof);
        if (!buf)
            return BadAlloc;
        *buf_return = buf;
        *nelem_return = cast(int)val.size;
    }
    else if (val.size < *nelem_return)
        *nelem_return = cast(int) val.size;

    for (i = 0; i < val.size && i < *nelem_return; i++)
        buf[i] = (cast(float*) val.data)[i];

    return Success;
}

/* Registers a new property handler on the given device and returns a unique
 * identifier for this handler. This identifier is required to unregister the
 * property handler again.
 * @return The handler's identifier or 0 if an error occurred.
 */
c_long XIRegisterPropertyHandler(DeviceIntPtr dev, int function(DeviceIntPtr dev, Atom property, XIPropertyValuePtr prop, BOOL checkonly) SetProperty, int function(DeviceIntPtr dev, Atom property) GetProperty, int function(DeviceIntPtr dev, Atom property) DeleteProperty)
{
    XIPropertyHandlerPtr new_handler = void;

    new_handler = cast(XIPropertyHandler*) calloc(1, XIPropertyHandler.sizeof);
    if (!new_handler)
        return 0;

    new_handler.id = XIPropHandlerID++;
    new_handler.SetProperty = cast(typeof(new_handler.SetProperty))SetProperty;
    new_handler.GetProperty = cast(typeof(new_handler.GetProperty))GetProperty;
    new_handler.DeleteProperty = cast(typeof(new_handler.DeleteProperty))DeleteProperty;
    new_handler.next = dev.properties.handlers;
    dev.properties.handlers = new_handler;

    return new_handler.id;
}

void XIUnregisterPropertyHandler(DeviceIntPtr dev, c_long id)
{
    XIPropertyHandlerPtr curr = void, prev = null;

    curr = dev.properties.handlers;
    while (curr && curr.id != id) {
        prev = curr;
        curr = curr.next;
    }

    if (!curr)
        return;

    if (!prev)                  /* first one */
        dev.properties.handlers = curr.next;
    else
        prev.next = curr.next;

    free(curr);
}

private XIPropertyPtr XICreateDeviceProperty(Atom property)
{
    XIPropertyPtr prop = cast(XIPropertyRec*) calloc(1, XIPropertyRec.sizeof);
    if (!prop)
        return null;

    prop.next = null;
    prop.propertyName = cast(uint)property;
    prop.value.type = None;
    prop.value.format = 0;
    prop.value.size = 0;
    prop.value.data = null;
    prop.deletable = TRUE;

    return prop;
}

private XIPropertyPtr XIFetchDeviceProperty(DeviceIntPtr dev, Atom property)
{
    XIPropertyPtr prop = void;

    for (prop = dev.properties.properties; prop; prop = prop.next)
        if (prop.propertyName == property)
            return prop;
    return null;
}

private void XIDestroyDeviceProperty(XIPropertyPtr prop)
{
    free(prop.value.data);
    free(prop);
}

/* This function destroys all of the device's property-related stuff,
 * including removing all device handlers.
 * DO NOT CALL FROM THE DRIVER.
 */
void XIDeleteAllDeviceProperties(DeviceIntPtr device)
{
    XIPropertyPtr prop = void, next = void;
    XIPropertyHandlerPtr curr_handler = void, next_handler = void;

    UpdateCurrentTimeIf();
    for (prop = device.properties.properties; prop; prop = next) {
        next = prop.next;
        send_property_event(device, prop.propertyName, XIPropertyDeleted);
        XIDestroyDeviceProperty(prop);
    }

    device.properties.properties = null;

    /* Now free all handlers */
    curr_handler = device.properties.handlers;
    while (curr_handler) {
        next_handler = curr_handler.next;
        free(curr_handler);
        curr_handler = next_handler;
    }

    device.properties.handlers = null;
}

int XIDeleteDeviceProperty(DeviceIntPtr device, Atom property, Bool fromClient)
{
    XIPropertyPtr prop = void; XIPropertyPtr* prev = void;
    int rc = Success;

    for (prev = &device.properties.properties; ((prop = *prev) !is null);
         prev = &(prop.next))
        if (prop.propertyName == property)
            break;

    if (!prop)
        return Success;

    if (fromClient && !prop.deletable)
        return BadAccess;

    /* Ask handlers if we may delete the property */
    if (device.properties.handlers) {
        XIPropertyHandlerPtr handler = device.properties.handlers;

        while (handler) {
            if (handler.DeleteProperty)
                rc = handler.DeleteProperty(device, prop.propertyName);
            if (rc != Success)
                return rc;
            handler = handler.next;
        }
    }

    if (prop) {
        UpdateCurrentTimeIf();
        *prev = prop.next;
        send_property_event(device, prop.propertyName, XIPropertyDeleted);
        XIDestroyDeviceProperty(prop);
    }

    return Success;
}

int XIChangeDeviceProperty(DeviceIntPtr dev, Atom property, Atom type, int format, int mode, c_ulong len, const(void)* value, Bool sendevent)
{
    XIPropertyPtr prop = void;
    int size_in_bytes = void;
    c_ulong total_len = void;
    XIPropertyValuePtr prop_value = void;
    XIPropertyValueRec new_value = void;
    Bool add = FALSE;
    int rc = void;

    size_in_bytes = format >> 3;

    /* first see if property already exists */
    prop = XIFetchDeviceProperty(dev, property);
    if (!prop) {                /* just add to list */
        prop = XICreateDeviceProperty(property);
        if (!prop)
            return BadAlloc;
        add = TRUE;
        mode = PropModeReplace;
    }
    prop_value = &prop.value;

    /* To append or prepend to a property the request format and type
       must match those of the already defined property.  The
       existing format and type are irrelevant when using the mode
       "PropModeReplace" since they will be written over. */

    if ((format != prop_value.format) && (mode != PropModeReplace))
        return BadMatch;
    if ((prop_value.type != type) && (mode != PropModeReplace))
        return BadMatch;
    new_value = *prop_value;
    if (mode == PropModeReplace)
        total_len = len;
    else
        total_len = prop_value.size + len;

    if (mode == PropModeReplace || len > 0) {
        void* new_data = null, old_data = null;

        new_value.data = calloc(total_len, size_in_bytes);
        if (!new_value.data && total_len && size_in_bytes) {
            if (add)
                XIDestroyDeviceProperty(prop);
            return BadAlloc;
        }
        new_value.size = total_len;
        new_value.type = type;
        new_value.format = cast(short)format;

        switch (mode) {
        case PropModeReplace:
            new_data = new_value.data;
            old_data = null;
            break;
        case PropModeAppend:
            new_data = cast(void*) ((cast(char*) new_value.data) +
                                  (prop_value.size * size_in_bytes));
            old_data = new_value.data;
            break;
        case PropModePrepend:
            new_data = new_value.data;
            old_data = cast(void*) ((cast(char*) new_value.data) +
                                  (len * size_in_bytes));
            break;
        default: break;}
        if (new_data)
            memcpy(cast(char*) new_data, value, len * size_in_bytes);
        if (old_data)
            memcpy(cast(char*) old_data, cast(char*) prop_value.data,
                   prop_value.size * size_in_bytes);

        if (dev.properties.handlers) {
            XIPropertyHandlerPtr handler = void;
            BOOL checkonly = TRUE;

            /* run through all handlers with checkonly TRUE, then again with
             * checkonly FALSE. Handlers MUST return error codes on the
             * checkonly run, errors on the second run are ignored */
            do {
                handler = dev.properties.handlers;
                while (handler) {
                    if (handler.SetProperty) {
                        input_lock();
                        rc = handler.SetProperty(dev, prop.propertyName,
                                                  &new_value, checkonly);
                        input_unlock();
                        if (checkonly && rc != Success) {
                            free(new_value.data);
                            if (add)
                                XIDestroyDeviceProperty(prop);
                            return rc;
                        }
                    }
                    handler = handler.next;
                }
                checkonly = !checkonly;
            } while (!checkonly);
        }
        free(prop_value.data);
        *prop_value = new_value;
    }
    else if (len == 0) {
        /* do nothing */
    }

    if (add) {
        prop.next = dev.properties.properties;
        dev.properties.properties = prop;
    }

    if (sendevent) {
        UpdateCurrentTimeIf();
        send_property_event(dev, prop.propertyName,
                            (add) ? XIPropertyCreated : XIPropertyModified);
    }

    return Success;
}

int XIGetDeviceProperty(DeviceIntPtr dev, Atom property, XIPropertyValuePtr* value)
{
    XIPropertyPtr prop = XIFetchDeviceProperty(dev, property);
    int rc = void;

    if (!prop) {
        *value = null;
        return BadAtom;
    }

    /* If we can, try to update the property value first */
    if (dev.properties.handlers) {
        XIPropertyHandlerPtr handler = dev.properties.handlers;

        while (handler) {
            if (handler.GetProperty) {
                rc = handler.GetProperty(dev, prop.propertyName);
                if (rc != Success) {
                    *value = null;
                    return rc;
                }
            }
            handler = handler.next;
        }
    }

    *value = &prop.value;
    return Success;
}

int XISetDevicePropertyDeletable(DeviceIntPtr dev, Atom property, Bool deletable)
{
    XIPropertyPtr prop = XIFetchDeviceProperty(dev, property);

    if (!prop)
        return BadAtom;

    prop.deletable = cast(ubyte)deletable;
    return Success;
}

/* rpcbuf->err_clear needs to be TRUE */
private int _writeDevProps(x_rpcbuf_t* rpcbuf, XID devId, ClientPtr pClient, size_t* natoms) {
    DeviceIntPtr dev = void;
    int rc = dixLookupDevice(&dev, cast(int)devId, pClient, DixListPropAccess);
    if (rc != Success)
        return rc;

    size_t n = 0;
    for (XIPropertyPtr p = dev.properties.properties; p; p = p.next) {
        n++;
        if (!x_rpcbuf_write_CARD32(rpcbuf, cast(uint)p.propertyName))
            return BadAlloc;
    }
    *natoms = n;
    return Success;
}

int ProcXListDeviceProperties(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xListDevicePropertiesReq);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    size_t natoms = 0;
    int rc = _writeDevProps(&rpcbuf, stuff.deviceid, client, &natoms);
    if (rc != Success)
        return rc;

    xListDevicePropertiesReply reply = {
        RepType: X_ListDeviceProperties,
        nAtoms: cast(ushort)natoms
    };

    mixin(X_REPLY_FIELD_CARD16!"nAtoms");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcXChangeDeviceProperty(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xChangeDevicePropertyReq);
    mixin(X_REQUEST_FIELD_CARD32!"property");
    mixin(X_REQUEST_FIELD_CARD32!"type");
    mixin(X_REQUEST_FIELD_CARD32!"nUnits");

    DeviceIntPtr dev = void;
    c_ulong len = void;
    ulong totalSize = void;
    int rc = void;

    UpdateCurrentTime();

    rc = dixLookupDevice(&dev, stuff.deviceid, client, DixSetPropAccess);
    if (rc != Success)
        return rc;

    rc = check_change_property(client, stuff.property, stuff.type,
                               stuff.format, stuff.mode, cast(int)stuff.nUnits);
    if (rc != Success)
        return rc;

    len = stuff.nUnits;
    if (len > (bytes_to_int32(0xffffffff - xChangeDevicePropertyReq.sizeof)))
        return BadLength;

    totalSize = len * (stuff.format / 8);
    mixin(REQUEST_FIXED_SIZE!("xChangeDevicePropertyReq", "totalSize"));

    rc = change_property(client, dev, stuff.property, stuff.type,
                         stuff.format, stuff.mode, cast(int)len, cast(void*) &stuff[1]);
    return rc;
}

int ProcXDeleteDeviceProperty(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDeleteDevicePropertyReq);
    mixin(X_REQUEST_FIELD_CARD32!"property");

    DeviceIntPtr dev = void;
    int rc = void;

    UpdateCurrentTime();
    rc = dixLookupDevice(&dev, stuff.deviceid, client, DixSetPropAccess);
    if (rc != Success)
        return rc;

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }

    rc = XIDeleteDeviceProperty(dev, stuff.property, TRUE);
    return rc;
}

int ProcXGetDeviceProperty(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xGetDevicePropertyReq);
    mixin(X_REQUEST_FIELD_CARD32!"property");
    mixin(X_REQUEST_FIELD_CARD32!"type");
    mixin(X_REQUEST_FIELD_CARD32!"longOffset");
    mixin(X_REQUEST_FIELD_CARD32!"longLength");

    DeviceIntPtr dev = void;
    int length = void;
    int rc = void, format = void, nitems = void, bytes_after = void;
    char* data = void;
    Atom type = void;

    if (stuff.delete_)
        UpdateCurrentTime();
    rc = dixLookupDevice(&dev, stuff.deviceid, client,
                         stuff.delete_ ? DixSetPropAccess : DixGetPropAccess);
    if (rc != Success)
        return rc;

    rc = get_property(client, dev, stuff.property, stuff.type,
                      stuff.delete_, cast(int)stuff.longOffset, cast(int)stuff.longLength,
                      &bytes_after, &type, &format, &nitems, &length, &data);

    if (rc != Success)
        return rc;

    xGetDevicePropertyReply reply = {
        RepType: X_GetDeviceProperty,
        propertyType: cast(uint)type,
        bytesAfter: bytes_after,
        nItems: nitems,
        format: cast(ubyte)format,
        deviceid: cast(ubyte)dev.id
    };

    if (stuff.delete_ && (reply.bytesAfter == 0))
        send_property_event(dev, stuff.property, XIPropertyDeleted);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (length) {
        switch (format) {
        case 32:
            x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)data, length / 4);
            break;
        case 16:
            x_rpcbuf_write_CARD16s(&rpcbuf, cast(CARD16*)data, length / 2);
            break;
        default:
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)data, length);
            break;
        }
    }

    /* delete the Property */
    if (stuff.delete_ && (reply.bytesAfter == 0)) {
        XIPropertyPtr prop = void; XIPropertyPtr* prev = void;

        for (prev = &dev.properties.properties; ((prop = *prev) !is null);
             prev = &prop.next) {
            if (prop.propertyName == stuff.property) {
                *prev = prop.next;
                XIDestroyDeviceProperty(prop);
                break;
            }
        }
    }

    mixin(X_REPLY_FIELD_CARD32!"propertyType");
    mixin(X_REPLY_FIELD_CARD32!"bytesAfter");
    mixin(X_REPLY_FIELD_CARD32!"nItems");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/* XI2 Request/reply handling */
int ProcXIListProperties(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIListPropertiesReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    size_t natoms = 0;
    int rc = _writeDevProps(&rpcbuf, stuff.deviceid, client, &natoms);
    if (rc != Success)
        return rc;

    xXIListPropertiesReply reply = {
        RepType: X_XIListProperties,
        num_properties: cast(ushort)natoms
    };

    mixin(X_REPLY_FIELD_CARD16!"num_properties");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcXIChangeProperty(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXIChangePropertyReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"property");
    mixin(X_REQUEST_FIELD_CARD32!"type");
    mixin(X_REQUEST_FIELD_CARD32!"num_items");

    int rc = void;
    DeviceIntPtr dev = void;
    ulong totalSize = void;
    c_ulong len = void;

    UpdateCurrentTime();

    rc = dixLookupDevice(&dev, stuff.deviceid, client, DixSetPropAccess);
    if (rc != Success)
        return rc;

    rc = check_change_property(client, stuff.property, stuff.type,
                               stuff.format, stuff.mode, stuff.num_items);
    if (rc != Success)
        return rc;

    len = stuff.num_items;
    if (len > bytes_to_int32(0xffffffff - xXIChangePropertyReq.sizeof))
        return BadLength;

    totalSize = len * (stuff.format / 8);
    mixin(REQUEST_FIXED_SIZE!("xXIChangePropertyReq", "totalSize"));

    rc = change_property(client, dev, stuff.property, stuff.type,
                         stuff.format, stuff.mode, cast(int)len, cast(void*) &stuff[1]);
    return rc;
}

int ProcXIDeleteProperty(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIDeletePropertyReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"property");

    DeviceIntPtr dev = void;
    int rc = void;

    UpdateCurrentTime();
    rc = dixLookupDevice(&dev, stuff.deviceid, client, DixSetPropAccess);
    if (rc != Success)
        return rc;

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }

    rc = XIDeleteDeviceProperty(dev, stuff.property, TRUE);
    return rc;
}

int ProcXIGetProperty(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIGetPropertyReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");
    mixin(X_REQUEST_FIELD_CARD32!"property");
    mixin(X_REQUEST_FIELD_CARD32!"type");
    mixin(X_REQUEST_FIELD_CARD32!"offset");
    mixin(X_REQUEST_FIELD_CARD32!"len");

    DeviceIntPtr dev = void;
    int length = void;
    int rc = void, format = void, nitems = void, bytes_after = void;
    char* data = void;
    Atom type = void;

    if (stuff.delete_)
        UpdateCurrentTime();
    rc = dixLookupDevice(&dev, stuff.deviceid, client,
                         stuff.delete_ ? DixSetPropAccess : DixGetPropAccess);
    if (rc != Success)
        return rc;

    rc = get_property(client, dev, stuff.property, stuff.type,
                      stuff.delete_, stuff.offset, stuff.len,
                      &bytes_after, &type, &format, &nitems, &length, &data);

    if (rc != Success)
        return rc;

    xXIGetPropertyReply reply = {
        RepType: X_XIGetProperty,
        type: cast(uint)type,
        bytes_after: bytes_after,
        num_items: nitems,
        format: cast(ubyte)format
    };

    if (length && stuff.delete_ && (reply.bytes_after == 0))
        send_property_event(dev, stuff.property, XIPropertyDeleted);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (length) {
        switch (format) {
        case 32:
            x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)data, length / 4);
            break;
        case 16:
            x_rpcbuf_write_CARD16s(&rpcbuf, cast(CARD16*)data, length / 2);
            break;
        default:
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)data, length);
            break;
        }
    }

    mixin(X_REPLY_FIELD_CARD32!"type");
    mixin(X_REPLY_FIELD_CARD32!"bytes_after");
    mixin(X_REPLY_FIELD_CARD32!"num_items");

    rc = mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
    if (rc != Success)
        return rc;

    /* delete the Property */
    if (stuff.delete_ && (reply.bytes_after == 0)) {
        XIPropertyPtr prop = void; XIPropertyPtr* prev = void;

        for (prev = &dev.properties.properties; ((prop = *prev) !is null);
             prev = &prop.next) {
            if (prop.propertyName == stuff.property) {
                *prev = prop.next;
                XIDestroyDeviceProperty(prop);
                break;
            }
        }
    }

    return rc;
}
