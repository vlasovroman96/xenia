module xf86_input_inputtest;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013-2017 Red Hat, Inc.
 * Copyright © 2020 Povilas Kanapickas <povilas@radix.lt>
 *
 * Permission to use, copy, modify, distribute, and sell this software
 * and its documentation for any purpose is hereby granted without
 * fee, provided that the above copyright notice appear in all copies
 * and that both that copyright notice and this permission notice
 * appear in supporting documentation, and that the name of Red Hat
 * not be used in advertising or publicity pertaining to distribution
 * of the software without specific, written prior permission.  Red
 * Hat makes no representations about the suitability of this software
 * for any purpose.  It is provided "as is" without express or implied
 * warranty.
 *
 * THE AUTHORS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN
 * NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
 * OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT,
 * NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */
import build.xorg_config;
import build.xlibre_server;

import core.stdc.errno;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.stat;
import core.sys.posix.sys.un;
// //import stdbool;
import os.inputthread;

//import externs.X11.Xatom;

import include.xorgVersion;

import Xi.exevents;
import dix.input;
import include.xkbsrv;
import include.xserver_properties;
import os.os;
import os.log;
import hw.xfree86.common.xf86Helper;
import dix.dixutils;
import os.connection;
import Xi.xiproperty;
import hw.xfree86.common.xf86Option;
import hw.xfree86.parser.Flags;
import dix.devices;
import dix.inpututils;
import hw.xfree86.common.xf86Xinput;
import std.conv;
import xkb.xkbInit;
import hw.xfree86.drivers.input.inputtest.xf86_input_inputtest_protocol;
import xf86Events;


enum MAX_POINTER_NUM_AXES = 5 /* x, y, hscroll, vscroll, [pressure] */;
enum MAX_TOUCH_NUM_AXES = 5 /* x, y, hscroll, vscroll, pressure */;
enum TOUCH_MAX_SLOTS = 15;

enum TOUCH_AXIS_MAX = 0xffff;
enum TABLET_PRESSURE_AXIS_MAX = 2047;

enum EVENT_BUFFER_SIZE = 4096;

enum xf86ITDeviceType {
    DEVICE_KEYBOARD = 1,
    DEVICE_POINTER,
    DEVICE_POINTER_GESTURE,
    DEVICE_POINTER_ABS,
    DEVICE_POINTER_ABS_PROXIMITY,
    DEVICE_TOUCH,
}
alias DEVICE_KEYBOARD = xf86ITDeviceType.DEVICE_KEYBOARD;
alias DEVICE_POINTER = xf86ITDeviceType.DEVICE_POINTER;
alias DEVICE_POINTER_GESTURE = xf86ITDeviceType.DEVICE_POINTER_GESTURE;
alias DEVICE_POINTER_ABS = xf86ITDeviceType.DEVICE_POINTER_ABS;
alias DEVICE_POINTER_ABS_PROXIMITY = xf86ITDeviceType.DEVICE_POINTER_ABS_PROXIMITY;
alias DEVICE_TOUCH = xf86ITDeviceType.DEVICE_TOUCH;


enum xf86ITClientState {
    CLIENT_STATE_NOT_CONNECTED = 0,

    /* connection_fd is valid */
    CLIENT_STATE_NEW,

    /* connection_fd is valid and client_protocol.{major,minor} are set */
    CLIENT_STATE_READY,
}
alias CLIENT_STATE_NOT_CONNECTED = xf86ITClientState.CLIENT_STATE_NOT_CONNECTED;
alias CLIENT_STATE_NEW = xf86ITClientState.CLIENT_STATE_NEW;
alias CLIENT_STATE_READY = xf86ITClientState.CLIENT_STATE_READY;


struct _Xf86ITDevice {
    InputInfoPtr pInfo;

    int socket_fd;  /* for accepting new clients */
    int connection_fd; /* current client connection */

    char* socket_path;

    xf86ITClientState client_state;
    struct _Client_protocol {
        int major, minor;
    }_Client_protocol client_protocol;

    struct _Buffer {
        char[EVENT_BUFFER_SIZE] data = 0;
        int valid_length;
    }_Buffer buffer;

    uint device_type;

    /*  last_processed_event_num == last_event_num and waiting_for_drain != 0 must never be true
        both at the same time. This would mean that we are waiting for the input queue to be
        processed, yet all events have already been processed, i.e. a deadlock.

        waiting_for_drain_mutex protects concurrent access to waiting_for_drain variable which
        may be modified from multiple threads.
    */
    pthread_mutex_t waiting_for_drain_mutex;
    bool waiting_for_drain;
    int last_processed_event_num;
    int last_event_num;

    ValuatorMask* valuators;
    ValuatorMask* valuators_unaccelerated;
}alias xf86ITDevice = _Xf86ITDevice;
alias xf86ITDevicePtr = xf86ITDevice*;



private Bool notify_sync_finished(ClientPtr ptr, void* closure)
{
    int fd = cast(int)cast(intptr_t) closure;
    xf86ITResponseSyncFinished response = void;
    response.header.length = response.sizeof;
    response.header.type = XF86IT_RESPONSE_SYNC_FINISHED;

    input_lock();
    /*  we don't really care whether the write succeeds. It may fail if the device is
        already shut down and the descriptor is closed.
    */
    if (write(fd, &response, response.header.length) != response.header.length) {
        LogMessageVerb(X_ERROR, 0,
                       "inputtest: Failed to write sync response: %s\n",
                       strerror(errno));
    }
    input_unlock();
    return TRUE;
}

private void input_drain_callback(CallbackListPtr* callback, void* data, void* call_data)
{
    void* drain_write_closure = void;
    InputInfoPtr pInfo = cast(_InputInfoRec*)data;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    bool notify_synchronization = false;

    pthread_mutex_lock(&driver_data.waiting_for_drain_mutex);
    driver_data.last_processed_event_num = driver_data.last_event_num;
    if (driver_data.waiting_for_drain) {
        driver_data.waiting_for_drain = false;
        notify_synchronization = true;
    }
    pthread_mutex_unlock(&driver_data.waiting_for_drain_mutex);

    if (notify_synchronization) {
        drain_write_closure = cast(void*)cast(intptr_t) driver_data.connection_fd;
        /* One input event may result in additional sets of events being submitted to the
           input queue from the input processing code itself. This results in
           input_drain_callback being called multiple times.

           We therefore schedule a WorkProc (to be run when the server is no longer busy)
           to notify the client when all current events have been processed.
         */
        xf86IDrvMsg(pInfo, X_DEBUG, "Synchronization finished\n");
        QueueWorkProc(&notify_sync_finished, null, drain_write_closure);
    }
}

private void read_events(int fd, int ready, void* data)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) data;
    InputInfoPtr pInfo = cast(_InputInfoRec*)dev.public_.devicePrivate;
    read_input_from_connection(pInfo);
}

private void try_accept_connection(int fd, int ready, void* data)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) data;
    InputInfoPtr pInfo = cast(_InputInfoRec*)dev.public_.devicePrivate;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    int connection_fd = void;
    int flags = void;

    if (driver_data.connection_fd >= 0)
        return;

    connection_fd = accept(driver_data.socket_fd, null, null);
    if (connection_fd < 0) {
        if (errno == EAGAIN || errno == EWOULDBLOCK)
            return;
        xf86IDrvMsg(pInfo, X_ERROR, "Failed to accept a connection\n");
        return;
    }

    xf86IDrvMsg(pInfo, X_DEBUG, "Accepted input control connection\n");

    flags = fcntl(connection_fd, F_GETFL, 0);
    fcntl(connection_fd, F_SETFL, flags | O_NONBLOCK);

    driver_data.connection_fd = connection_fd;
    xf86AddInputEventDrainCallback(&input_drain_callback, pInfo);
    SetNotifyFd(driver_data.connection_fd, &read_events, X_NOTIFY_READ, dev);

    driver_data.client_state = CLIENT_STATE_NEW;
}

private int device_on(DeviceIntPtr dev)
{
    InputInfoPtr pInfo = cast(_InputInfoRec*)dev.public_.devicePrivate;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;

    xf86IDrvMsg(pInfo, X_DEBUG, "Device turned on\n");

    xf86AddEnabledDevice(pInfo);
    dev.public_.on = TRUE;
    driver_data.buffer.valid_length = 0;

    try_accept_connection(-1, 0, dev);
    if (driver_data.connection_fd < 0)
        SetNotifyFd(driver_data.socket_fd, &try_accept_connection, X_NOTIFY_READ, dev);

    return Success;
}

private void teardown_client_connection(InputInfoPtr pInfo)
{
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    if (driver_data.client_state != CLIENT_STATE_NOT_CONNECTED) {
        RemoveNotifyFd(driver_data.connection_fd);
        xf86RemoveInputEventDrainCallback(&input_drain_callback, pInfo);

        close(driver_data.connection_fd);
        driver_data.connection_fd = -1;
    }
    RemoveNotifyFd(driver_data.socket_fd);
    driver_data.client_state = CLIENT_STATE_NOT_CONNECTED;
}

private int device_off(DeviceIntPtr dev)
{
    InputInfoPtr pInfo = cast(_InputInfoRec*)dev.public_.devicePrivate;

    xf86IDrvMsg(pInfo, X_DEBUG, "Device turned off\n");

    if (dev.public_.on) {
        teardown_client_connection(pInfo);
        xf86RemoveEnabledDevice(pInfo);
    }
    dev.public_.on = FALSE;
    return Success;
}

private void ptr_ctl(DeviceIntPtr dev, PtrCtrl* ctl)
{
}

private void init_button_map(ubyte* btnmap, size_t size)
{
    int i = void;

    memset(btnmap, 0, size);
    for (i = 0; i < size; i++)
        btnmap[i] = cast(ubyte)i;
}

private void init_button_labels(Atom* labels, size_t size)
{
    assert(size > 10);

    memset(labels, 0, size * Atom.sizeof);
    labels[0] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_LEFT);
    labels[1] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_MIDDLE);
    labels[2] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_RIGHT);
    labels[3] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_UP);
    labels[4] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_DOWN);
    labels[5] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_LEFT);
    labels[6] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_RIGHT);
    labels[7] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_SIDE);
    labels[8] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_EXTRA);
    labels[9] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_FORWARD);
    labels[10] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_BACK);
}

private void init_pointer(InputInfoPtr pInfo)
{
    DeviceIntPtr dev = pInfo.dev;
    int min = void, max = void, res = void;
    int nbuttons = 7;
    bool has_pressure = false;
    int num_axes = 0;

    ubyte[MAX_BUTTONS + 1] btnmap = void;
    Atom[MAX_BUTTONS] btnlabels = void;
    Atom[MAX_POINTER_NUM_AXES] axislabels = void;

    nbuttons = xf86SetIntOption(cast(_InputOption*)pInfo.options, "PointerButtonCount", 7);
    has_pressure = cast(bool)xf86SetBoolOption(pInfo.options, "PointerHasPressure",
                                     false);

    init_button_map(btnmap.ptr, btnmap.length);
    init_button_labels(btnlabels.ptr, btnlabels.length);

    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_X);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_Y);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_HSCROLL);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_VSCROLL);
    if (has_pressure)
        axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_ABS_PRESSURE);

    InitPointerDeviceStruct(cast(DevicePtr)dev,
                            btnmap.ptr,
                            nbuttons,
                            btnlabels.ptr,
                            &ptr_ctl,
                            GetMotionHistorySize(),
                            num_axes,
                            axislabels.ptr);
    min = -1;
    max = -1;
    res = 0;

    xf86InitValuatorAxisStruct(dev, 0, XIGetKnownProperty(AXIS_LABEL_PROP_REL_X),
                               min, max, res * 1000, 0, res * 1000, Relative);
    xf86InitValuatorAxisStruct(dev, 1, XIGetKnownProperty(AXIS_LABEL_PROP_REL_Y),
                               min, max, res * 1000, 0, res * 1000, Relative);

    SetScrollValuator(dev, 2, SCROLL_TYPE_HORIZONTAL, 120, 0);
    SetScrollValuator(dev, 3, SCROLL_TYPE_VERTICAL, 120, 0);

    if (has_pressure) {
        xf86InitValuatorAxisStruct(dev, 4,
            XIGetKnownProperty(AXIS_LABEL_PROP_ABS_PRESSURE),
            0, 1000, 1, 1, 1, Absolute);
    }
}

private void init_pointer_absolute(InputInfoPtr pInfo)
{
    DeviceIntPtr dev = pInfo.dev;
    int min = void, max = void, res = void;
    int nbuttons = 7;
    bool has_pressure = false;
    int num_axes = 0;

    ubyte[MAX_BUTTONS + 1] btnmap = void;
    Atom[MAX_BUTTONS] btnlabels = void;
    Atom[MAX_POINTER_NUM_AXES] axislabels = void;

    nbuttons = xf86SetIntOption(cast(_InputOption*)pInfo.options, "PointerButtonCount", 7);
    has_pressure = cast(bool)xf86SetBoolOption(pInfo.options, "PointerHasPressure",
                                     false);

    init_button_map(btnmap.ptr, btnmap.length);
    init_button_labels(btnlabels.ptr, btnlabels.length);

    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_ABS_X);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_ABS_Y);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_HSCROLL);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_VSCROLL);
    if (has_pressure)
        axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_ABS_PRESSURE);

    InitPointerDeviceStruct(cast(DevicePtr)dev,
                            btnmap.ptr,
                            nbuttons,
                            btnlabels.ptr,
                            &ptr_ctl,
                            GetMotionHistorySize(),
                            num_axes ,
                            axislabels.ptr);
    min = 0;
    max = TOUCH_AXIS_MAX;
    res = 0;

    xf86InitValuatorAxisStruct(dev, 0, XIGetKnownProperty(AXIS_LABEL_PROP_ABS_X),
                               min, max, res * 1000, 0, res * 1000, Absolute);
    xf86InitValuatorAxisStruct(dev, 1, XIGetKnownProperty(AXIS_LABEL_PROP_ABS_Y),
                               min, max, res * 1000, 0, res * 1000, Absolute);

    SetScrollValuator(dev, 2, SCROLL_TYPE_HORIZONTAL, 120, 0);
    SetScrollValuator(dev, 3, SCROLL_TYPE_VERTICAL, 120, 0);

    if (has_pressure) {
        xf86InitValuatorAxisStruct(dev, 4,
            XIGetKnownProperty(AXIS_LABEL_PROP_ABS_PRESSURE),
            0, 1000, 1, 1, 1, Absolute);
    }
}

private void init_proximity(InputInfoPtr pInfo)
{
    DeviceIntPtr dev = pInfo.dev;
    InitProximityClassDeviceStruct(dev);
}

private void init_keyboard(InputInfoPtr pInfo)
{
    DeviceIntPtr dev = pInfo.dev;
    XkbRMLVOSet rmlvo = void;
    XkbRMLVOSet defaults = void;

    XkbGetRulesDflts(&defaults);

    rmlvo.rules = xf86SetStrOption(pInfo.options, "xkb_rules", defaults.rules);
    rmlvo.model = xf86SetStrOption(pInfo.options, "xkb_model", defaults.model);
    rmlvo.layout = xf86SetStrOption(pInfo.options, "xkb_layout", defaults.layout);
    rmlvo.variant = xf86SetStrOption(pInfo.options, "xkb_variant", defaults.variant);
    rmlvo.options = xf86SetStrOption(pInfo.options, "xkb_options", defaults.options);

    InitKeyboardDeviceStruct(dev, &rmlvo, null, null);
    XkbFreeRMLVOSet(&rmlvo, FALSE);
    XkbFreeRMLVOSet(&defaults, FALSE);
}

private void init_touch(InputInfoPtr pInfo)
{
    DeviceIntPtr dev = pInfo.dev;
    int min = void, max = void, res = void;
    ubyte[MAX_BUTTONS + 1] btnmap = void;
    Atom[MAX_BUTTONS] btnlabels = void;
    Atom[MAX_TOUCH_NUM_AXES] axislabels = void;
    int num_axes = 0;
    int nbuttons = 7;
    int ntouches = TOUCH_MAX_SLOTS;

    init_button_map(btnmap.ptr, btnmap.length);
    init_button_labels(btnlabels.ptr, btnlabels.length);

    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_ABS_MT_POSITION_X);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_ABS_MT_POSITION_Y);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_HSCROLL);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_VSCROLL);
    axislabels[num_axes++] = XIGetKnownProperty(AXIS_LABEL_PROP_ABS_MT_PRESSURE);

    InitPointerDeviceStruct(cast(DevicePtr)dev,
                            btnmap.ptr,
                            nbuttons,
                            btnlabels.ptr,
                            &ptr_ctl,
                            GetMotionHistorySize(),
                            num_axes,
                            axislabels.ptr);
    min = 0;
    max = TOUCH_AXIS_MAX;
    res = 0;

    xf86InitValuatorAxisStruct(dev, 0,
                               XIGetKnownProperty(AXIS_LABEL_PROP_ABS_MT_POSITION_X),
                               min, max, res * 1000, 0, res * 1000, Absolute);
    xf86InitValuatorAxisStruct(dev, 1,
                               XIGetKnownProperty(AXIS_LABEL_PROP_ABS_MT_POSITION_Y),
                               min, max, res * 1000, 0, res * 1000, Absolute);

    SetScrollValuator(dev, 2, SCROLL_TYPE_HORIZONTAL, 120, 0);
    SetScrollValuator(dev, 3, SCROLL_TYPE_VERTICAL, 120, 0);

    xf86InitValuatorAxisStruct(dev, 4,
                               XIGetKnownProperty(AXIS_LABEL_PROP_ABS_MT_PRESSURE),
                               min, TABLET_PRESSURE_AXIS_MAX, res * 1000, 0, res * 1000, Absolute);

    ntouches = xf86SetIntOption(cast(_InputOption*)pInfo.options, "TouchCount", TOUCH_MAX_SLOTS);
    if (ntouches == 0) /* unknown */
        ntouches = TOUCH_MAX_SLOTS;
    InitTouchClassDeviceStruct(dev, ntouches, XIDirectTouch, 2);
}

private void init_gesture(InputInfoPtr pInfo)
{
    DeviceIntPtr dev = pInfo.dev;
    int ntouches = TOUCH_MAX_SLOTS;
    InitGestureClassDeviceStruct(dev, ntouches);
}

private void device_init(DeviceIntPtr dev)
{
    InputInfoPtr pInfo = cast(InputInfoPtr)dev.public_.devicePrivate;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;

    dev.public_.on = FALSE;

    switch (driver_data.device_type) {
        case DEVICE_KEYBOARD:
            init_keyboard(pInfo);
            break;
        case DEVICE_POINTER:
            init_pointer(pInfo);
            break;
        case DEVICE_POINTER_GESTURE:
            init_pointer(pInfo);
            init_gesture(pInfo);
            break;
        case DEVICE_POINTER_ABS:
            init_pointer_absolute(pInfo);
            break;
        case DEVICE_POINTER_ABS_PROXIMITY:
            init_pointer_absolute(pInfo);
            init_proximity(pInfo);
            break;
        case DEVICE_TOUCH:
            init_touch(pInfo);
            break;
    default: break;}
}

private void device_destroy(DeviceIntPtr dev)
{
    InputInfoPtr pInfo = cast(_InputInfoRec*)dev.public_.devicePrivate;
    xf86IDrvMsg(pInfo, X_INFO, "Close\n");
}

private int device_control(DeviceIntPtr dev, int mode)
{
    switch (mode) {
        case DEVICE_INIT:
            device_init(dev);
            break;
        case DEVICE_ON:
            device_on(dev);
            break;
        case DEVICE_OFF:
            device_off(dev);
            break;
        case DEVICE_CLOSE:
            device_destroy(dev);
            break;
    default: break;}

    return Success;
}

private void convert_to_valuator_mask(xf86ITValuatorData* event, ValuatorMask* mask)
{
    valuator_mask_zero(mask);
    for (int i = 0; i < min(XF86IT_MAX_VALUATORS, MAX_VALUATORS); ++i) {
        if (mixin(BitIsOn!("event.mask", "i"))) {
            if (event.has_unaccelerated) {
                valuator_mask_set_unaccelerated(mask, i, event.valuators[i],
                                                event.unaccelerated[i]);
            } else {
                valuator_mask_set_double(mask, i, event.valuators[i]);
            }
        }
    }
}

private void handle_client_version(InputInfoPtr pInfo, xf86ITEventClientVersion* event)
{
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    xf86ITResponseServerVersion response = void;

    response.header.length = response.sizeof;
    response.header.type = XF86IT_RESPONSE_SERVER_VERSION;
    response.major = XF86IT_PROTOCOL_VERSION_MAJOR;
    response.minor = XF86IT_PROTOCOL_VERSION_MINOR;

    if (write(driver_data.connection_fd, &response, response.header.length) != response.header.length) {
        xf86IDrvMsg(pInfo, X_ERROR, "Error writing driver version: %s\n", strerror(errno));
        teardown_client_connection(pInfo);
        return;
    }

    if (event.major != XF86IT_PROTOCOL_VERSION_MAJOR ||
        event.minor > XF86IT_PROTOCOL_VERSION_MINOR)
    {
        xf86IDrvMsg(pInfo, X_ERROR, "Unsupported protocol version: %d.%d (current %d.%d)\n",
                    event.major, event.minor,
                    XF86IT_PROTOCOL_VERSION_MAJOR,
                    XF86IT_PROTOCOL_VERSION_MINOR);
        teardown_client_connection(pInfo);
        return;
    }

    driver_data.client_protocol.major = event.major;
    driver_data.client_protocol.minor = event.minor;

    driver_data.client_state = CLIENT_STATE_READY;
}

private void handle_wait_for_sync(InputInfoPtr pInfo)
{
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    bool notify_synchronization = false;
    void* drain_write_closure = void;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling sync event\n");

    pthread_mutex_lock(&driver_data.waiting_for_drain_mutex);
    if (driver_data.last_processed_event_num == driver_data.last_event_num) {
        notify_synchronization = true;
    } else {
        driver_data.waiting_for_drain = true;
    }
    pthread_mutex_unlock(&driver_data.waiting_for_drain_mutex);

    if (notify_synchronization) {
        drain_write_closure = cast(void*)cast(intptr_t) driver_data.connection_fd;
        xf86IDrvMsg(pInfo, X_DEBUG, "Synchronization finished\n");
        notify_sync_finished(null, drain_write_closure);
    }
}

private void handle_motion(InputInfoPtr pInfo, xf86ITEventMotion* event)
{
    DeviceIntPtr dev = pInfo.dev;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    ValuatorMask* mask = driver_data.valuators;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling motion event\n");

    driver_data.last_event_num++;

    convert_to_valuator_mask(&event.valuators, mask);
    xf86PostMotionEventM(dev, event.is_absolute ? Absolute : Relative, mask);
}

private void handle_proximity(InputInfoPtr pInfo, xf86ITEventProximity* event)
{
    DeviceIntPtr dev = pInfo.dev;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    ValuatorMask* mask = driver_data.valuators;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling proximity event\n");

    driver_data.last_event_num++;

    convert_to_valuator_mask(&event.valuators, mask);
    xf86PostProximityEventM(dev, event.is_prox_in, mask);
}

private void handle_button(InputInfoPtr pInfo, xf86ITEventButton* event)
{
    DeviceIntPtr dev = pInfo.dev;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    ValuatorMask* mask = driver_data.valuators;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling button event\n");

    driver_data.last_event_num++;

    convert_to_valuator_mask(&event.valuators, mask);
    xf86PostButtonEventM(dev, event.is_absolute ? Absolute : Relative, event.button,
                         event.is_press, mask);
}

private void handle_key(InputInfoPtr pInfo, xf86ITEventKey* event)
{
    DeviceIntPtr dev = pInfo.dev;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling key event\n");

    driver_data.last_event_num++;

    xf86PostKeyboardEvent(dev, event.key_code, event.is_press);
}

private void handle_touch(InputInfoPtr pInfo, xf86ITEventTouch* event)
{
    DeviceIntPtr dev = pInfo.dev;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    ValuatorMask* mask = driver_data.valuators;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling touch event\n");

    driver_data.last_event_num++;

    convert_to_valuator_mask(&event.valuators, mask);
    xf86PostTouchEvent(dev, event.touchid, cast(ushort)event.touch_type, 0, mask);
}

private void handle_gesture_swipe(InputInfoPtr pInfo, xf86ITEventGestureSwipe* event)
{
    DeviceIntPtr dev = pInfo.dev;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling gesture swipe event\n");

    driver_data.last_event_num++;

    xf86PostGestureSwipeEvent(dev, event.gesture_type, event.num_touches, event.flags,
                              event.delta_x, event.delta_y,
                              event.delta_unaccel_x, event.delta_unaccel_y);
}

private void handle_gesture_pinch(InputInfoPtr pInfo, xf86ITEventGesturePinch* event)
{
    DeviceIntPtr dev = pInfo.dev;
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;

    xf86IDrvMsg(pInfo, X_DEBUG, "Handling gesture pinch event\n");

    driver_data.last_event_num++;

    xf86PostGesturePinchEvent(dev, event.gesture_type, event.num_touches, event.flags,
                              event.delta_x, event.delta_y,
                              event.delta_unaccel_x, event.delta_unaccel_y,
                              event.scale, event.delta_angle);
}

private void client_new_handle_event(InputInfoPtr pInfo, xf86ITEventAny* event)
{
    switch (event.header.type) {
        case XF86IT_EVENT_CLIENT_VERSION:
            handle_client_version(pInfo, &event.version_);
            break;
        default:
            xf86IDrvMsg(pInfo, X_ERROR, "Event before client is ready: event type %d\n",
                        event.header.type);
            teardown_client_connection(pInfo);
            break;
    }
}

private void client_ready_handle_event(InputInfoPtr pInfo, xf86ITEventAny* event)
{
    switch (event.header.type) {
        case XF86IT_EVENT_WAIT_FOR_SYNC:
            handle_wait_for_sync(pInfo);
            break;
        case XF86IT_EVENT_MOTION:
            handle_motion(pInfo, &event.motion);
            break;
        case XF86IT_EVENT_PROXIMITY:
            handle_proximity(pInfo, &event.proximity);
            break;
        case XF86IT_EVENT_BUTTON:
            handle_button(pInfo, &event.button);
            break;
        case XF86IT_EVENT_KEY:
            handle_key(pInfo, &event.key);
            break;
        case XF86IT_EVENT_TOUCH:
            handle_touch(pInfo, &event.touch);
            break;
        case XF86IT_EVENT_GESTURE_PINCH:
            handle_gesture_pinch(pInfo, &(event.pinch));
            break;
        case XF86IT_EVENT_GESTURE_SWIPE:
            handle_gesture_swipe(pInfo, &(event.swipe));
            break;
        case XF86IT_EVENT_CLIENT_VERSION:
            xf86IDrvMsg(pInfo, X_ERROR, "Only single ClientVersion event is allowed\n");
            teardown_client_connection(pInfo);
            break;
        default:
            xf86IDrvMsg(pInfo, X_ERROR, "Invalid event when client is ready %d\n",
                        event.header.type);
            teardown_client_connection(pInfo);
            break;
    }
}

private void handle_event(InputInfoPtr pInfo, xf86ITEventAny* event)
{
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;

    if (!pInfo.dev.public_.on)
        return;

    switch (driver_data.client_state) {
        case CLIENT_STATE_NOT_CONNECTED:
            xf86IDrvMsg(pInfo, X_ERROR, "Got event when client is not connected\n");
            break;
        case CLIENT_STATE_NEW:
            client_new_handle_event(pInfo, event);
            break;
        case CLIENT_STATE_READY:
            client_ready_handle_event(pInfo, event);
            break;
    default: break;}
}

private bool is_supported_event(xf86ITEventType type)
{
    switch (type) {
        case XF86IT_EVENT_CLIENT_VERSION:
        case XF86IT_EVENT_WAIT_FOR_SYNC:
        case XF86IT_EVENT_MOTION:
        case XF86IT_EVENT_PROXIMITY:
        case XF86IT_EVENT_BUTTON:
        case XF86IT_EVENT_KEY:
        case XF86IT_EVENT_TOUCH:
        case XF86IT_EVENT_GESTURE_PINCH:
        case XF86IT_EVENT_GESTURE_SWIPE:
            return true;
    default: break;}
    return false;
}

private int get_event_size(xf86ITEventType type)
{
    switch (type) {
        case XF86IT_EVENT_CLIENT_VERSION: return xf86ITEventClientVersion.sizeof;
        case XF86IT_EVENT_WAIT_FOR_SYNC: return xf86ITEventWaitForSync.sizeof;
        case XF86IT_EVENT_MOTION: return xf86ITEventMotion.sizeof;
        case XF86IT_EVENT_PROXIMITY: return xf86ITEventProximity.sizeof;
        case XF86IT_EVENT_BUTTON: return xf86ITEventButton.sizeof;
        case XF86IT_EVENT_KEY: return xf86ITEventKey.sizeof;
        case XF86IT_EVENT_TOUCH: return xf86ITEventTouch.sizeof;
        case XF86IT_EVENT_GESTURE_PINCH: return xf86ITEventGesturePinch.sizeof;
        case XF86IT_EVENT_GESTURE_SWIPE: return xf86ITEventGestureSwipe.sizeof;
    default: break;}
    FatalError("xf86-input-inputtest: get_event_size() got undefined event type %d\n", cast(int)type);
    assert(0);
}

private void read_input_from_connection(InputInfoPtr pInfo)
{
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;

    while (1) {
        int processed_size = 0;
        int read_size = cast(int)read(driver_data.connection_fd,
                             driver_data.buffer.data.ptr + driver_data.buffer.valid_length,
                             EVENT_BUFFER_SIZE - driver_data.buffer.valid_length);

        if (read_size < 0) {
            if (errno == EAGAIN || errno == EWOULDBLOCK)
                return;

            xf86IDrvMsg(pInfo, X_ERROR, "Error reading events: %s\n", strerror(errno));
            teardown_client_connection(pInfo);
            return;
        }

        driver_data.buffer.valid_length += read_size;

        while (1) {
            xf86ITEventHeader event_header = void;
            char* event_begin = driver_data.buffer.data.ptr + processed_size;

            if (driver_data.buffer.valid_length - processed_size < xf86ITEventHeader.sizeof)
                break;

            /* Note that event_begin pointer is not aligned, accessing it directly is
               undefined behavior. We must use memcpy to copy the data to aligned data
               area. Most compilers will optimize out this call out and use whatever
               is most efficient to access unaligned data on a particular platform */
            memcpy(&event_header, event_begin, xf86ITEventHeader.sizeof);

            if (event_header.length >= EVENT_BUFFER_SIZE) {
                xf86IDrvMsg(pInfo, X_ERROR, "Received event with too long length: %d\n",
                            event_header.length);
                teardown_client_connection(pInfo);
                return;
            }

            if (driver_data.buffer.valid_length - processed_size < event_header.length)
                break;

            if (is_supported_event(event_header.type)) {
                int expected_event_size = get_event_size(event_header.type);

                if (event_header.length != expected_event_size) {
                    xf86IDrvMsg(pInfo, X_ERROR, "Unexpected event length: was %d bytes, "
                                ~ "expected %d (event type: %d)\n",
                                event_header.length, expected_event_size,
                                cast(int) event_header.type);
                    teardown_client_connection(pInfo);
                    return;
                }

                /* We could use event_begin pointer directly, but we want to ensure correct
                   data alignment (if only so that address sanitizer does not complain) */
                xf86ITEventAny event_data = void;
                memset(&event_data, 0, event_data.sizeof);
                memcpy(&event_data, event_begin, event_header.length);
                handle_event(pInfo, &event_data);
            }
            processed_size += event_header.length;
        }

        if (processed_size > 0) {
            memmove(driver_data.buffer.data.ptr,
                    driver_data.buffer.data.ptr + processed_size,
                    driver_data.buffer.valid_length - processed_size);
            driver_data.buffer.valid_length -= processed_size;
        }

        if (read_size == 0)
            break;
    }
}

private void read_input(InputInfoPtr pInfo)
{
    /* The test input driver does not set up the pInfo->fd and use the regular
       read_input callback because we want to only accept the connection to
       the controlling socket after the device is turned on.
    */
}

private const(char)* get_type_name(InputInfoPtr pInfo, xf86ITDevicePtr driver_data)
{
    switch (driver_data.device_type) {
        case DEVICE_TOUCH: return XI_TOUCHSCREEN;
        case DEVICE_POINTER: return XI_MOUSE;
        case DEVICE_POINTER_GESTURE: return XI_TOUCHPAD;
        case DEVICE_POINTER_ABS: return XI_MOUSE;
        case DEVICE_POINTER_ABS_PROXIMITY: return XI_TABLET;
        case DEVICE_KEYBOARD: return XI_KEYBOARD;
    default: break;}
    xf86IDrvMsg(pInfo, X_ERROR, "Unexpected device type %d\n",
                driver_data.device_type);
    return XI_KEYBOARD;
}

private xf86ITDevicePtr device_alloc()
{
    xf86ITDevicePtr driver_data = cast(xf86ITDevice*) calloc(1, xf86ITDevice.sizeof);

    if (!driver_data)
        return null;

    driver_data.socket_fd = -1;
    driver_data.connection_fd = -1;

    return driver_data;
}

private void free_driver_data(xf86ITDevicePtr driver_data)
{
    if (driver_data) {
        close(driver_data.connection_fd);
        close(driver_data.socket_fd);
        if (driver_data.socket_path)
            unlink(driver_data.socket_path);
        free(driver_data.socket_path);
        pthread_mutex_destroy(&driver_data.waiting_for_drain_mutex);

        if (driver_data.valuators)
            valuator_mask_free(&driver_data.valuators);
        if (driver_data.valuators_unaccelerated)
            valuator_mask_free(&driver_data.valuators_unaccelerated);
    }
    free(driver_data);
}

private int pre_init(InputDriverPtr drv, InputInfoPtr pInfo, int flags)
{
    xf86ITDevicePtr driver_data = null;
    char* device_type_option = void;
    sockaddr_un addr = void;

    pInfo.type_name = null;
    pInfo.device_control = &device_control;
    pInfo.read_input = &read_input;
    pInfo.control_proc = null;
    pInfo.switch_mode = null;
    int fd;
    driver_data = device_alloc();
    if (!driver_data)
        goto fail;

    driver_data.client_state = CLIENT_STATE_NOT_CONNECTED;
    driver_data.last_event_num = 1;
    driver_data.last_processed_event_num = 0;
    driver_data.waiting_for_drain = false;
    pthread_mutex_init(&driver_data.waiting_for_drain_mutex, null);

    driver_data.valuators = valuator_mask_new(6);
    if (!driver_data.valuators)
        goto fail;

    driver_data.valuators_unaccelerated = valuator_mask_new(2);
    if (!driver_data.valuators_unaccelerated)
        goto fail;

    driver_data.socket_path = xf86SetStrOption(pInfo.options, "SocketPath", null);
    if (!driver_data.socket_path){
        xf86IDrvMsg(pInfo, X_ERROR, "SocketPath must be specified\n");
        goto fail;
    }

    if (strlen(driver_data.socket_path) >= typeof(addr.sun_path).sizeof) {
        xf86IDrvMsg(pInfo, X_ERROR, "SocketPath is too long\n");
        goto fail;
    }

    unlink(driver_data.socket_path);

version (SOCK_NONBLOCK) {
    driver_data.socket_fd = socket(AF_UNIX, SOCK_STREAM | SOCK_NONBLOCK, 0);
} else {
    fd = socket(AF_UNIX, SOCK_STREAM, 0);
    if (fd >= 0) {
        flags = fcntl(fd, F_GETFL, 0);
        if (fcntl(fd, F_SETFL, flags | O_NONBLOCK) < 0) {
            fd = -1;
        }
    }
    driver_data.socket_fd = fd;
}

    if (driver_data.socket_fd < 0) {
        xf86IDrvMsg(pInfo, X_ERROR, "Failed to create a socket for communication: %s\n",
                    strerror(errno));
        goto fail;
    }

    memset(&addr, 0, addr.sizeof);
    addr.sun_family = AF_UNIX;
    strncpy(cast(char*)addr.sun_path.ptr, driver_data.socket_path, ((addr.sun_path).sizeof - 1));

    if (bind(driver_data.socket_fd, cast(sockaddr*) &addr, addr.sizeof) < 0) {
        xf86IDrvMsg(pInfo, X_ERROR, "Failed to assign address to the socket\n");
        goto fail;
    }

    if (chmod(driver_data.socket_path, octal!"0777") != 0) {
        xf86IDrvMsg(pInfo, X_ERROR, "Failed to chmod the socket path\n");
        goto fail;
    }

    if (listen(driver_data.socket_fd, 1) != 0) {
        xf86IDrvMsg(pInfo, X_ERROR, "Failed to listen on the socket\n");
        goto fail;
    }

    device_type_option = xf86SetStrOption(pInfo.options, "DeviceType", null);
    if (device_type_option is null) {
        xf86IDrvMsg(pInfo, X_ERROR, "DeviceType option must be specified\n");
        goto fail;
    }

    if (strcmp(device_type_option, "Keyboard") == 0) {
        driver_data.device_type = DEVICE_KEYBOARD;
    } else if (strcmp(device_type_option, "Pointer") == 0) {
        driver_data.device_type = DEVICE_POINTER;
    } else if (strcmp(device_type_option, "PointerGesture") == 0) {
        driver_data.device_type = DEVICE_POINTER_GESTURE;
    } else if (strcmp(device_type_option, "PointerAbsolute") == 0) {
        driver_data.device_type = DEVICE_POINTER_ABS;
    } else if (strcmp(device_type_option, "PointerAbsoluteProximity") == 0) {
        driver_data.device_type = DEVICE_POINTER_ABS_PROXIMITY;
    } else if (strcmp(device_type_option, "Touch") == 0) {
        driver_data.device_type = DEVICE_TOUCH;
    } else {
        xf86IDrvMsg(pInfo, X_ERROR, "Unsupported DeviceType option.\n");
        goto fail;
    }
    free(device_type_option);

    pInfo.private_ = driver_data;
    driver_data.pInfo = pInfo;

    pInfo.type_name = get_type_name(pInfo, driver_data);

    return Success;
fail:
    free_driver_data(driver_data);
    return BadValue;
}

private void uninit(InputDriverPtr drv, InputInfoPtr pInfo, int flags)
{
    xf86ITDevicePtr driver_data = cast(_Xf86ITDevice*)pInfo.private_;
    free_driver_data(driver_data);
    pInfo.private_ = null;
    xf86DeleteInput(pInfo, flags);
}

InputDriverRec driver = {
    driverVersion: 1,
    driverName: "inputtest",
    PreInit: &pre_init,
    UnInit: &uninit,
    module_: null,
    default_options: null,
    capabilities: 0
};

private XF86ModuleVersionInfo version_info = {
    modname: "inputtest",
    vendor: MODULEVENDORSTRING,
    _modinfo1_: MODINFOSTRING1,
    _modinfo2_: MODINFOSTRING2,
    xf86version: mixin(XORG_VERSION_CURRENT),
    majorversion: mixin(XORG_VERSION_MAJOR),
    minorversion: mixin(XORG_VERSION_MINOR),
    patchlevel: mixin(XORG_VERSION_PATCH),
    abiclass: ABI_CLASS_XINPUT,
    abiversion: ABI_XINPUT_VERSION,
    moduleclass: MOD_CLASS_XINPUT,
};

private void* setup_proc(void* module_, void* options, int* errmaj, int* errmin)
{
    xf86AddInputDriver(&driver, module_, 0);
    return module_;
}

export XF86ModuleData inputtestModuleData = {
    vers: &version_info,
    setup: &setup_proc,
};
