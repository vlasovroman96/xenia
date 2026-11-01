module InitInput;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1993, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

*/

import build.dix_config;

//import x11.X;
//import x11.Xproto;
// //import x11.Xos;
//import x11.keysym;

import dix.dix_priv;
import dix.input_priv;
import mi.mi_priv;

import include.scrnintstr;
import include.inputstr;
import mi.mipointer;
import include.xkbsrv;
import include.xserver_properties;
import Xi.exevents;

void ProcessInputEvents()
{
    mieqProcessInputEvents();
}

void DDXRingBell(int volume, int pitch, int duration)
{
}

enum VFB_MIN_KEY = 8;
enum VFB_MAX_KEY = 255;

private int vfbKeybdProc(DeviceIntPtr pDevice, int onoff)
{
    DevicePtr pDev = cast(DevicePtr) pDevice;

    switch (onoff) {
    case DEVICE_INIT:
        InitKeyboardDeviceStruct(pDevice, null, null, null);
        break;
    case DEVICE_ON:
        pDev.on = TRUE;
        break;
    case DEVICE_OFF:
        pDev.on = FALSE;
        break;
    case DEVICE_CLOSE:
        break;
    default: break;}
    return Success;
}

private int vfbMouseProc(DeviceIntPtr pDevice, int onoff)
{
enum NBUTTONS = 13;
enum NAXES = 2;

    BYTE[NBUTTONS + 1] map = void;
    DevicePtr pDev = cast(DevicePtr) pDevice;
    Atom[NBUTTONS] btn_labels = 0;
    Atom[NAXES] axes_labels = 0;

    switch (onoff) {
    case DEVICE_INIT:
        for (int i = 1; i <= NBUTTONS; ++i) {
            map[i] = i;
        }

        btn_labels[0] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_LEFT);
        btn_labels[1] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_MIDDLE);
        btn_labels[2] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_RIGHT);
        btn_labels[3] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_UP);
        btn_labels[4] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_DOWN);
        btn_labels[5] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_LEFT);
        btn_labels[6] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_RIGHT);
        btn_labels[7] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_UNKNOWN);
        btn_labels[8] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_UNKNOWN);
        btn_labels[9] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_UNKNOWN);
        btn_labels[10] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_UNKNOWN);
        btn_labels[11] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_UNKNOWN);
        btn_labels[12] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_UNKNOWN);

        axes_labels[0] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_X);
        axes_labels[1] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_Y);

        InitPointerDeviceStruct(pDev, map.ptr, NBUTTONS, btn_labels.ptr,
                                cast(PtrCtrlProcPtr) NoopDDA,
                                GetMotionHistorySize(), NAXES, axes_labels.ptr);
        break;

    case DEVICE_ON:
        pDev.on = TRUE;
        break;

    case DEVICE_OFF:
        pDev.on = FALSE;
        break;

    case DEVICE_CLOSE:
        break;
    default: break;}
    return Success;

}

void InitInput(int argc, char** argv)
{
    DeviceIntPtr p = void, k = void;
    Atom xiclass = void;

    p = AddInputDevice(serverClient, &vfbMouseProc, TRUE);
    k = AddInputDevice(serverClient, &vfbKeybdProc, TRUE);
    xiclass = dixAddAtom(XI_MOUSE);
    AssignTypeAndName(p, xiclass, "Xvfb mouse");
    xiclass = dixAddAtom(XI_KEYBOARD);
    AssignTypeAndName(k, xiclass, "Xvfb keyboard");
    cast(void) mieqInit();
}

void CloseInput()
{
    mieqFini();
}
