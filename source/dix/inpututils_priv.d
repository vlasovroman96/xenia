module dix.inpututils_priv;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2010 Red Hat, Inc.
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
 
public import include.input;
public import dix.events;
import dix.inpututils_priv;
import externs.X11.extensions.XI2proto;
// public // //import externs.X11.extensions.XI2proto;

// Mask[MAXEVENTS][MAXDEVICES] event_filters;

struct _ValuatorMask {
    byte last_bit;            /* highest bit set in mask */
    byte has_unaccelerated;
    ubyte[(MAX_VALUATORS + 7) / 8] mask;
    double[MAX_VALUATORS] valuators = 0;    /* valuator data */
    double[MAX_VALUATORS] unaccelerated = 0;    /* valuator data */
}

// void verify_internal_event(const(InternalEvent)* ev);
// void init_device_event(DeviceEvent* event, DeviceIntPtr dev, Time ms, DeviceEventSource event_source);
// void init_gesture_event(GestureEvent* event, DeviceIntPtr dev, Time ms);
// int event_get_corestate(DeviceIntPtr mouse, DeviceIntPtr kbd);
// void event_set_state(DeviceIntPtr mouse, DeviceIntPtr kbd, DeviceEvent* event);
// void event_set_state_gesture(DeviceIntPtr kbd, GestureEvent* event);
// Mask event_get_filter_from_type(DeviceIntPtr dev, int evtype);
// Mask event_get_filter_from_xi2type(int evtype);

// FP3232 double_to_fp3232(double in_);
// FP1616 double_to_fp1616(double in_);
double fp1616_to_double(FP1616 in_);
double fp3232_to_double(FP3232 in_);

// XI2Mask* xi2mask_new();
XI2Mask* xi2mask_new_with_size(size_t, size_t); /* don't use it */
// void xi2mask_free(XI2Mask** mask);
// Bool xi2mask_isset(XI2Mask* mask, const(DeviceIntPtr) dev, int event_type);
// Bool xi2mask_isset_for_device(XI2Mask* mask, const(DeviceIntPtr) dev, int event_type);
void xi2mask_set(XI2Mask* mask, int deviceid, int event_type);
// void xi2mask_zero(XI2Mask* mask, int deviceid);
// void xi2mask_merge(XI2Mask* dest, const(XI2Mask)* source);
// size_t xi2mask_num_masks(const(XI2Mask)* mask);
// size_t xi2mask_mask_size(const(XI2Mask)* mask);
// void xi2mask_set_one_mask(XI2Mask* xi2mask, int deviceid, const(ubyte)* mask, size_t mask_size);
// const(ubyte)* xi2mask_get_one_mask(const(XI2Mask)* xi2mask, int deviceid);

// Bool CopySprite(SpritePtr src, SpritePtr dst);

 /* _XSERVER_DIX_INPUTUTILS_PRIV_H */
