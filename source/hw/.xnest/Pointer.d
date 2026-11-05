module hw.xnest.Pointer;
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
//import x11.Xproto;
import dix.scrintstr;
import dix.inputstr;import dix.input;
import common.misc;
import dix.scrnintstr;
import include.servermd;
import mi.mipointer;

import xnest_xcb;


import Display;
import Screen;
import Pointer;
import Args;

import include.xserver_properties;
import Xi.exevents;           /* For XIGetKnownProperty */

DeviceIntPtr xnestPointerDevice = null;

void xnestChangePointerControl(DeviceIntPtr pDev, PtrCtrl* ctrl)
{
    xcb_change_pointer_control(xnestUpstreamInfo.conn,
                               ctrl.num,
                               ctrl.den,
                               ctrl.threshold,
                               TRUE,
                               TRUE);
}

int xnestPointerProc(DeviceIntPtr pDev, int onoff)
{
    Atom[MAXBUTTONS] btn_labels = 0;
    Atom[2] axes_labels = 0;
    int i = void;

    switch (onoff) {
    case DEVICE_INIT:
    {
        btn_labels[0] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_LEFT);
        btn_labels[1] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_MIDDLE);
        btn_labels[2] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_RIGHT);
        btn_labels[3] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_UP);
        btn_labels[4] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_DOWN);
        btn_labels[5] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_LEFT);
        btn_labels[6] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_RIGHT);

        axes_labels[0] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_X);
        axes_labels[1] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_Y);

        xnest_get_pointer_control(xnestUpstreamInfo.conn,
                                  &defaultPointerControl.num,
                                  &defaultPointerControl.den,
                                  &defaultPointerControl.threshold);

        xcb_generic_error_t* pm_err = null;
        xcb_get_pointer_mapping_reply_t* pm_reply = xcb_get_pointer_mapping_reply(
                xnestUpstreamInfo.conn,
                xcb_get_pointer_mapping(xnestUpstreamInfo.conn),
                &pm_err);
        if (pm_err) {
            ErrorF("failed getting pointer mapping %d\n", pm_err.error_code);
            free(pm_err);
            break;
        }

        if (!pm_reply) {
            ErrorF("failed getting pointer mapping: no reply\n");
            break;
        }

        const(int) nmap = xcb_get_pointer_mapping_map_length(pm_reply);
        ubyte* map = xcb_get_pointer_mapping_map(pm_reply);
        for (i=0; i<nmap; i++)
            map[i] = i;         /* buttons are already mapped */

        InitPointerDeviceStruct(&pDev.public_,
                                map,
                                nmap,
                                btn_labels.ptr,
                                &xnestChangePointerControl,
                                GetMotionHistorySize(), 2, axes_labels.ptr);
        free(pm_reply);
        break;
    }
    case DEVICE_ON:
        xnestEventMask |= XNEST_POINTER_EVENT_MASK;
        for (i = 0; i < xnestNumScreens; i++)
            xcb_change_window_attributes(xnestUpstreamInfo.conn,
                                         xnestDefaultWindows[i],
                                         XCB_CW_EVENT_MASK,
                                         &xnestEventMask);
        break;
    case DEVICE_OFF:
        xnestEventMask &= ~XNEST_POINTER_EVENT_MASK;
        for (i = 0; i < xnestNumScreens; i++)
            xcb_change_window_attributes(xnestUpstreamInfo.conn,
                                         xnestDefaultWindows[i],
                                         XCB_CW_EVENT_MASK,
                                         &xnestEventMask);
        break;
    case DEVICE_CLOSE:
        break;
    default: break;}
    return Success;
}
