module hw.kdrive.src.kinput;
@nogc nothrow:
extern(C): __gshared:

template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 1999 Keith Packard
 * Copyright © 2006 Nokia Corporation
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of the authors not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  The authors make no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * THE AUTHORS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE AUTHORS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import config.kdrive_config;
import config.xkb_config;
import hw.kdrive.src.kdrive;
import dix.inputstr;

version = XK_PUBLISHING;
//import x11.keysym;
// static if (HAVE_X11_XF86KEYSYM_H) {
// //import externs.X11.XF86keysym;
// }
import core.stdc.stdio;
import core.stdc.signal;
import core.sys.posix.fcntl;           /* needed for FNONBLOCK & FASYNC */

////import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import config.hotplug_priv;
import dix.dix_priv;
import dix.input_priv;
import dix.inpututils_priv;
import dix.screenint_priv;
import dix.settings_priv;
import mi.mi_priv;
import mi.mipointer_priv;
import os.cmdline;

import xkb.xkbsrv_priv;
import Xi.XIstubs;            /* even though we don't use stubs.  cute, no? */
import Xi.exevents;
import Xi.exglobals;
import dix.events;
import common.xserver_properties;

static if (HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
import config.hotplug_priv;
}

version (KDRIVE_EVDEV) {
enum DEV_INPUT_EVENT_PREFIX = "/dev/input/event";
enum DEV_INPUT_EVENT_PREFIX_LEN = (sizeof(DEV_INPUT_EVENT_PREFIX) - 1);
}

enum string AtomFromName(string x) = `MakeAtom(` ~ x ~ `, strlen(` ~ x ~ `), 1)`;

enum KD_KEY_COUNT =    248;
enum KD_MIN_KEYCODE =  8;
enum KD_MAX_KEYCODE =  255;
enum KD_MAX_WIDTH =    4;
enum KD_MAX_LENGTH =   (KD_MAX_KEYCODE - KD_MIN_KEYCODE + 1);

struct KdConfigDevice {
    char* line;
    KdConfigDevice* next;
};

/* kdKeyboards and kdPointers hold all the real devices. */
KdKeyboardInfo* kdKeyboards = null;
KdPointerInfo* kdPointers = null;
KdConfigDevice* kdConfigKeyboards = null;
KdConfigDevice* kdConfigPointers = null;

KdKeyboardDriver* kdKeyboardDrivers = null;
KdPointerDriver* kdPointerDrivers = null;

Bool kdInputEnabled;
Bool kdOffScreen;
c_ulong kdOffScreenTime;

KdPointerMatrix kdPointerMatrix = {
    [[1, 0, 0],
    [0, 1, 0]]
};

enum KD_MAX_INPUT_FDS =    8;

struct KdInputFd {
    int fd;
    void function(int fd, void* closure) read;
    int function(int fd, void* closure) enable;
    void function(int fd, void* closure) disable;
    void* closure;
}

KdInputFd[KD_MAX_INPUT_FDS] kdInputFds;
int kdNumInputFds = 0;

Bool kdRawPointerCoordinates;

const(char)* kdGlobalXkbRules;
const(char)* kdGlobalXkbModel;
const(char)* kdGlobalXkbLayout;
const(char)* kdGlobalXkbVariant;
const(char)* kdGlobalXkbOptions;

version (FNONBLOCK) {
enum NOBLOCK = FNONBLOCK;
} else {
// enum NOBLOCK = FNDELAY;
}

void KdResetInputMachine()
{
    KdPointerInfo* pi = void;

    for (pi = kdPointers; pi; pi = pi.next) {
        pi.mouseState = start;
        pi.eventHeld = False;
    }
}

void KdEnableNonBlockFd(int fd)
{
version (Windows) {} else {
    int flags = fcntl(fd, F_GETFL);
    flags |= NOBLOCK;
    fcntl(fd, F_SETFL, flags);
}
}

void KdDisableNotBlockFd(int fd)
{
version (Windows) {} else {
    int flags = fcntl(fd, F_GETFL);
    flags &= ~NOBLOCK;
    fcntl(fd, F_SETFL, flags);
}
}

void KdNotifyFd(int fd, int ready, void* data)
{
    int i = cast(int) cast(intptr_t) data;
    (*kdInputFds[i].read)(fd, kdInputFds[i].closure);
}

void KdAddFd(int fd, int i)
{
    KdEnableNonBlockFd(fd);
    /* AddEnabledDevice(fd); No longer exists */
    InputThreadRegisterDev(fd, &KdNotifyFd, cast(void*) cast(intptr_t) i);
}

void KdRemoveFd(int fd)
{
    /* RemoveEnabledDevice(fd); No longer exists */
    InputThreadUnregisterDev(fd);
    KdDisableNotBlockFd(fd);
}

Bool KdRegisterFd(int fd, void function(int fd, void* closure) read, void* closure)
{
    if (kdNumInputFds == KD_MAX_INPUT_FDS)
        return False;
    kdInputFds[kdNumInputFds].fd = fd;
    kdInputFds[kdNumInputFds].read = read;
    kdInputFds[kdNumInputFds].enable = 0;
    kdInputFds[kdNumInputFds].disable = 0;
    kdInputFds[kdNumInputFds].closure = closure;
    if (kdInputEnabled)
        KdAddFd(fd, kdNumInputFds);
    kdNumInputFds++;
    return True;
}

void KdUnregisterFd(void* closure, int fd, Bool do_close)
{
    int i = void, j = void;

    for (i = 0; i < kdNumInputFds; i++) {
        if (kdInputFds[i].closure == closure &&
            (fd == -1 || kdInputFds[i].fd == fd)) {
            if (kdInputEnabled)
                KdRemoveFd(kdInputFds[i].fd);
            if (do_close)
                close(kdInputFds[i].fd);
            for (j = i; j < (kdNumInputFds - 1); j++)
                kdInputFds[j] = kdInputFds[j + 1];
            kdNumInputFds--;
            break;
        }
    }
}

void KdUnregisterFds(void* closure, Bool do_close)
{
    KdUnregisterFd(closure, -1, do_close);
}

void KdDisableInput()
{
    KdKeyboardInfo* ki = void;
    KdPointerInfo* pi = void;
    int found = 0, i = 0;

    input_lock();

    for (ki = kdKeyboards; ki; ki = ki.next) {
        if (ki.last_scan_code != -1) {
            /**
             * When we're doing something that causes a vt switch,
             * if that action is a key press, the X server doesn't see
             * the key release event.
             *
             * For example, if we start an X server from a terminal
             * running inside another X server, the "host" server
             * sees the "enter" key press, but not the key release.
             *
             * With this, we forge the key release event that the
             * X server doesn't see, so that it doesn't misinterpret
             * the missing key release as a long key press.
             *
             * Doesn't really matter what the value of the
             * third argument is, as long as it is non-zero.
             * This is what the linux keyboard driver sends.
             */
            KdEnqueueKeyboardEvent(ki, ki.last_scan_code, 0x80);
        }
        if (ki.driver && ki.driver.Disable)
            (*ki.driver.Disable) (ki);
    }

    for (pi = kdPointers; pi; pi = pi.next) {
        if (pi.driver && pi.driver.Disable)
            (*pi.driver.Disable) (pi);
    }

    if (kdNumInputFds) {
        ErrorF("[KdDisableInput] Buggy drivers: still %d input fds left!",
               kdNumInputFds);
        i = 0;
        while (i < kdNumInputFds) {
            found = 0;
            for (ki = kdKeyboards; ki; ki = ki.next) {
                if (ki == kdInputFds[i].closure) {
                    ErrorF("    fd %d belongs to keybd driver %s\n",
                           kdInputFds[i].fd,
                           ki.driver && ki.driver.name ?
                           ki.driver.name : "(unnamed!)");
                    found = 1;
                    break;
                }
            }

            if (found) {
                i++;
                continue;
            }

            for (pi = kdPointers; pi; pi = pi.next) {
                if (pi == kdInputFds[i].closure) {
                    ErrorF("    fd %d belongs to pointer driver %s\n",
                           kdInputFds[i].fd,
                           pi.driver && pi.driver.name ?
                           pi.driver.name : "(unnamed!)");
                    break;
                }
            }

            if (found) {
                i++;
                continue;
            }

            ErrorF("    fd %d not claimed by any active device!\n",
                   kdInputFds[i].fd);
            KdUnregisterFd(kdInputFds[i].closure, kdInputFds[i].fd, True);
        }
    }

    kdInputEnabled = False;
}

void KdEnableInput()
{
    InternalEvent ev = void;
    KdKeyboardInfo* ki = void;
    KdPointerInfo* pi = void;

    kdInputEnabled = True;

    ev.any.time = GetTimeInMillis();

    for (ki = kdKeyboards; ki; ki = ki.next) {
        if (ki.driver && ki.driver.Enable)
            (*ki.driver.Enable) (ki);
        /* reset screen saver */
        NoticeEventTime (&ev, ki.dixdev);
    }

    for (pi = kdPointers; pi; pi = pi.next) {
        if (pi.driver && pi.driver.Enable)
            (*pi.driver.Enable) (pi);
        /* reset screen saver */
        NoticeEventTime (&ev, pi.dixdev);
    }

    input_unlock();
}

KdKeyboardDriver* KdFindKeyboardDriver(const(char)* name)
{
    KdKeyboardDriver* ret = void;

    /* ask a stupid question ... */
    if (!name)
        return null;

    for (ret = kdKeyboardDrivers; ret; ret = ret.next) {
        if (strcmp(ret.name, name) == 0)
            return ret;
    }

    return null;
}

KdPointerDriver* KdFindPointerDriver(const(char)* name)
{
    KdPointerDriver* ret = void;

    /* ask a stupid question ... */
    if (!name)
        return null;

    for (ret = kdPointerDrivers; ret; ret = ret.next) {
        if (strcmp(ret.name, name) == 0)
            return ret;
    }

    return null;
}

int KdPointerProc(DeviceIntPtr pDevice, int onoff)
{
    DevicePtr pDev = cast(DevicePtr) pDevice;
    KdPointerInfo* pi = void;
    Atom xiclass = void;
    Atom* btn_labels = void;
    Atom* axes_labels = void;

    if (!pDev)
        return BadImplementation;

    for (pi = kdPointers; pi; pi = pi.next) {
        if (pi.dixdev && pi.dixdev.id == pDevice.id)
            break;
    }

    if (!pi || !pi.dixdev || pi.dixdev.id != pDevice.id) {
        ErrorF("[KdPointerProc] Failed to find pointer for device %d!\n",
               pDevice.id);
        return BadImplementation;
    }

    switch (onoff) {
    case DEVICE_INIT:
version (DEBUG) {
        ErrorF("initialising pointer %s ...\n", pi.name);
}
        if (!pi.driver) {
            if (!pi.driver) {
                ErrorF("no driver specified for pointer device \"%s\" (%s)\n",
                       pi.name ? pi.name : "(unnamed)", pi.path);
                return BadImplementation;
            }

            pi.driver = KdFindPointerDriver(pi.driver);
            if (!pi.driver) {
                ErrorF("Couldn't find pointer driver %s\n",
                       pi.driver? cast(char*) pi.driver:
                       "(unnamed)");
                return !Success;
            }
            free(pi.driver);
            pi.driver= null;
        }

        if (!pi.driver.Init) {
            ErrorF("no init function\n");
            return BadImplementation;
        }

        if ((*pi.driver.Init) (pi) != Success) {
            return !Success;
        }

        btn_labels = cast(Atom*) calloc(pi.nButtons, Atom.sizeof);
        if (!btn_labels)
            return BadAlloc;
        axes_labels = cast(Atom*) calloc(pi.nAxes, Atom.sizeof);
        if (!axes_labels) {
            free(btn_labels);
            return BadAlloc;
        }

        switch (pi.nAxes) {
        default:
        case 7:
            btn_labels[6] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_RIGHT);
        case 6:
            btn_labels[5] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_HWHEEL_LEFT);
        case 5:
            btn_labels[4] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_DOWN);
        case 4:
            btn_labels[3] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_WHEEL_UP);
        case 3:
            btn_labels[2] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_RIGHT);
        case 2:
            btn_labels[1] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_MIDDLE);
        case 1:
            btn_labels[0] = XIGetKnownProperty(BTN_LABEL_PROP_BTN_LEFT);
        case 0:
            break;
        }

        if (pi.nAxes >= 2) {
            axes_labels[0] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_X);
            axes_labels[1] = XIGetKnownProperty(AXIS_LABEL_PROP_REL_Y);
        }

        InitPointerDeviceStruct(pDev, pi.map, pi.nButtons, btn_labels,
                                cast(PtrCtrlProcPtr) NoopDDA,
                                GetMotionHistorySize(), pi.nAxes, axes_labels);

        free(btn_labels);
        free(axes_labels);

        if (pi.inputClass == KD_TOUCHSCREEN) {
            xiclass = mixin(AtomFromName!(`XI_TOUCHSCREEN`));
        }
        else {
            xiclass = mixin(AtomFromName!(`XI_MOUSE`));
        }

        AssignTypeAndName(pi.dixdev, xiclass,
                          pi.name ? pi.name : "Generic KDrive Pointer");

        return Success;

    case DEVICE_ON:
        if (pDev.on == True)
            return Success;

        if (!pi.driver.Enable) {
            ErrorF("no enable function\n");
            return BadImplementation;
        }

        if ((*pi.driver.Enable) (pi) == Success) {
            pDev.on = True;
            return Success;
        }
        else {
            return BadImplementation;
        }

        return Success;

    case DEVICE_OFF:
        if (pDev.on == False) {
            return Success;
        }

        if (!pi.driver.Disable) {
            return BadImplementation;
        }
        else {
            (*pi.driver.Disable) (pi);
            pDev.on = False;
            return Success;
        }

        return Success;

    case DEVICE_CLOSE:
        if (pDev.on) {
            if (!pi.driver.Disable) {
                return BadImplementation;
            }
            (*pi.driver.Disable) (pi);
            pDev.on = False;
        }

        if (!pi.driver.Fini)
            return BadImplementation;

        (*pi.driver.Fini) (pi);

        KdRemovePointer(pi);

        return Success;
    default: break;}

    /* NOTREACHED */
    return BadImplementation;
}

void KdRingBell(KdKeyboardInfo* ki, int volume, int pitch, int duration)
{
    if (!ki || !ki.driver || !ki.driver.Bell)
        return;

    if (kdInputEnabled)
        (*ki.driver.Bell) (ki, volume, pitch, duration);
}

void KdBell(int volume, DeviceIntPtr pDev, void* arg, int something)
{
    KeybdCtrl* ctrl = arg;
    KdKeyboardInfo* ki = null;

    for (ki = kdKeyboards; ki; ki = ki.next) {
        if (ki.dixdev && ki.dixdev.id == pDev.id)
            break;
    }

    if (!ki || !ki.dixdev || ki.dixdev.id != pDev.id || !ki.driver)
        return;

    KdRingBell(ki, volume, ctrl.bell_pitch, ctrl.bell_duration);
}

void DDXRingBell(int volume, int pitch, int duration)
{
    KdKeyboardInfo* ki = null;

    if (kdOsFuncs.Bell) {
        kdOsFuncs.Bell(volume, pitch, duration);
        return;
    }

    for (ki = kdKeyboards; ki; ki = ki.next) {
        if (ki.dixdev.coreEvents)
            KdRingBell(ki, volume, pitch, duration);
    }
}

void KdSetLeds(KdKeyboardInfo* ki, int leds)
{
    if (!ki || !ki.driver)
        return;

    if (kdInputEnabled) {
        if (ki.driver.Leds)
            (*ki.driver.Leds) (ki, leds);
    }
}

void KdSetLed(KdKeyboardInfo* ki, int led, Bool on)
{
    if (!ki || !ki.dixdev || !ki.dixdev.kbdfeed)
        return;

    NoteLedState(ki.dixdev, led, on);
    KdSetLeds(ki, ki.dixdev.kbdfeed.ctrl.leds);
}

void KdSetPointerMatrix(KdPointerMatrix* matrix)
{
    kdPointerMatrix = *matrix;
}

void KdComputePointerMatrix(KdPointerMatrix* m, Rotation randr, int width, int height)
{
    int x_dir = 1, y_dir = 1;
    int i = void, j = void;
    int[2] size = void;

    size[0] = width;
    size[1] = height;
    if (randr & RR_Reflect_X)
        x_dir = -1;
    if (randr & RR_Reflect_Y)
        y_dir = -1;
    switch (randr & (RR_Rotate_All)) {
    case RR_Rotate_0:
        m.matrix[0][0] = x_dir;
        m.matrix[0][1] = 0;
        m.matrix[1][0] = 0;
        m.matrix[1][1] = y_dir;
        break;
    case RR_Rotate_90:
        m.matrix[0][0] = 0;
        m.matrix[0][1] = -x_dir;
        m.matrix[1][0] = y_dir;
        m.matrix[1][1] = 0;
        break;
    case RR_Rotate_180:
        m.matrix[0][0] = -x_dir;
        m.matrix[0][1] = 0;
        m.matrix[1][0] = 0;
        m.matrix[1][1] = -y_dir;
        break;
    case RR_Rotate_270:
        m.matrix[0][0] = 0;
        m.matrix[0][1] = x_dir;
        m.matrix[1][0] = -y_dir;
        m.matrix[1][1] = 0;
        break;
    default: break;}
    for (i = 0; i < 2; i++) {
        m.matrix[i][2] = 0;
        for (j = 0; j < 2; j++)
            if (m.matrix[i][j] < 0)
                m.matrix[i][2] = size[j] - 1;
    }
}

void KdScreenToPointerCoords(int* x, int* y)
{
    int[3]* m = kdPointerMatrix.matrix;
    int div = m[0][1] * m[1][0] - m[1][1] * m[0][0];
    int sx = *x;
    int sy = *y;

    *x = (m[0][1] * sy - m[0][1] * m[1][2] + m[1][1] * m[0][2] -
          m[1][1] * sx) / div;
    *y = (m[1][0] * sx + m[0][0] * m[1][2] - m[1][0] * m[0][2] -
          m[0][0] * sy) / div;
}

void KdKbdCtrl(DeviceIntPtr pDevice, KeybdCtrl* ctrl)
{
    KdKeyboardInfo* ki = void;

    for (ki = kdKeyboards; ki; ki = ki.next) {
        if (ki.dixdev && ki.dixdev.id == pDevice.id)
            break;
    }

    if (!ki || !ki.dixdev || ki.dixdev.id != pDevice.id || !ki.driver)
        return;

    KdSetLeds(ki, ctrl.leds);
    ki.bellPitch = ctrl.bell_pitch;
    ki.bellDuration = ctrl.bell_duration;
}

int KdKeyboardProc(DeviceIntPtr pDevice, int onoff)
{
    Bool ret = void;
    DevicePtr pDev = cast(DevicePtr) pDevice;
    KdKeyboardInfo* ki = void;
    Atom xiclass = void;
    XkbRMLVOSet rmlvo = void;

    if (!pDev)
        return BadImplementation;

    for (ki = kdKeyboards; ki; ki = ki.next) {
        if (ki.dixdev && ki.dixdev.id == pDevice.id)
            break;
    }

    if (!ki || !ki.dixdev || ki.dixdev.id != pDevice.id) {
        return BadImplementation;
    }

    switch (onoff) {
    case DEVICE_INIT:
version (DEBUG) {
        ErrorF("initialising keyboard %s\n", ki.name);
}
        if (!ki.driver) {
            if (!ki.driver) {
                ErrorF("no driver specified for keyboard device \"%s\" (%s)\n",
                       ki.name ? ki.name : "(unnamed)", ki.path);
                return BadImplementation;
            }

            ki.driver = KdFindKeyboardDriver(ki.driver);
            if (!ki.driver) {
                ErrorF("Couldn't find keyboard driver %s\n",
                       ki.driver? cast(char*) ki.driver:
                       "(unnamed)");
                return !Success;
            }
            free(ki.driver);
            ki.driver= null;
        }

        if (!ki.driver.Init) {
            ErrorF("Keyboard %s: no init function\n", ki.name);
            return BadImplementation;
        }

        if (ki.driver.PreInit) {
            (*ki.driver.PreInit)(ki);
        }

        memset(&rmlvo, 0, rmlvo.sizeof);
        rmlvo.rules = ki.xkbRules;
        rmlvo.model = ki.xkbModel;
        rmlvo.layout = ki.xkbLayout;
        rmlvo.variant = ki.xkbVariant;
        rmlvo.options = ki.xkbOptions;
        ret = InitKeyboardDeviceStruct(pDevice, &rmlvo, &KdBell, &KdKbdCtrl);
        if (!ret) {
            ErrorF("Couldn't initialise keyboard %s\n", ki.name);
            return BadImplementation;
        }

        if ((*ki.driver.Init) (ki) != Success) {
            return !Success;
        }

        xiclass = mixin(AtomFromName!(`XI_KEYBOARD`));
        AssignTypeAndName(pDevice, xiclass,
                          ki.name ? ki.name : "Generic KDrive Keyboard");

        KdResetInputMachine();

        return Success;

    case DEVICE_ON:
        if (pDev.on == True)
            return Success;

        if (!ki.driver.Enable)
            return BadImplementation;

        if ((*ki.driver.Enable) (ki) != Success) {
            return BadMatch;
        }

        pDev.on = True;
        return Success;

    case DEVICE_OFF:
        if (pDev.on == False)
            return Success;

        if (!ki.driver.Disable)
            return BadImplementation;

        (*ki.driver.Disable) (ki);
        pDev.on = False;

        return Success;

        break;

    case DEVICE_CLOSE:
        if (pDev.on) {
            if (!ki.driver.Disable)
                return BadImplementation;

            (*ki.driver.Disable) (ki);
            pDev.on = False;
        }

        if (!ki.driver.Fini)
            return BadImplementation;

        (*ki.driver.Fini) (ki);

        KdRemoveKeyboard(ki);

        return Success;
    default: break;}

    /* NOTREACHED */
    return BadImplementation;
}

void KdAddPointerDriver(KdPointerDriver* driver)
{
    KdPointerDriver** prev = void;

    if (!driver)
        return;

    for (prev = &kdPointerDrivers; *prev; prev = &(*prev).next) {
        if (*prev == driver)
            return;
    }
    *prev = driver;
}

void KdRemovePointerDriver(KdPointerDriver* driver)
{
    KdPointerDriver* tmp = void;

    if (!driver)
        return;

    /* FIXME remove all pointers using this driver */
    for (tmp = kdPointerDrivers; tmp; tmp = tmp.next) {
        if (tmp.next == driver)
            tmp.next = driver.next;
    }
    if (tmp == driver)
        tmp = null;
}

void KdAddKeyboardDriver(KdKeyboardDriver* driver)
{
    KdKeyboardDriver** prev = void;

    if (!driver)
        return;

    for (prev = &kdKeyboardDrivers; *prev; prev = &(*prev).next) {
        if (*prev == driver)
            return;
    }
    *prev = driver;
}

void KdRemoveKeyboardDriver(KdKeyboardDriver* driver)
{
    KdKeyboardDriver* tmp = void;

    if (!driver)
        return;

    /* FIXME remove all keyboards using this driver */
    for (tmp = kdKeyboardDrivers; tmp; tmp = tmp.next) {
        if (tmp.next == driver)
            tmp.next = driver.next;
    }
    if (tmp == driver)
        tmp = null;
}

KdKeyboardInfo* KdNewKeyboard()
{
    KdKeyboardInfo* ki = cast(KdKeyboardInfo*) cast(KdKeyboardInfo*) calloc(1, KdKeyboardInfo.sizeof);

    if (!ki)
        return null;

    ki.minScanCode = 0;
    ki.maxScanCode = 0;
    ki.leds = 0;
    ki.bellPitch = 1000;
    ki.bellDuration = 200;
    ki.next = null;
    ki.options = null;
    ki.name = strdup("Generic Keyboard");
    ki.path = null;
    ki.xkbRules = strdup(kdGlobalXkbRules ? kdGlobalXkbRules : XKB_DFLT_RULES);
    ki.xkbModel = strdup(kdGlobalXkbModel ? kdGlobalXkbModel : XKB_DFLT_MODEL);
    ki.xkbLayout = strdup(kdGlobalXkbLayout ? kdGlobalXkbLayout : XKB_DFLT_LAYOUT);
    ki.xkbVariant = strdup(kdGlobalXkbVariant ? kdGlobalXkbVariant :XKB_DFLT_VARIANT);
    ki.xkbOptions = strdup(kdGlobalXkbOptions ? kdGlobalXkbOptions : XKB_DFLT_OPTIONS);

    return ki;
}

int KdAddConfigKeyboard(const(char)* keyboard)
{
    KdConfigDevice** prev = void; KdConfigDevice* new_ = void;

    if (!keyboard)
        return Success;

    new_ = cast(KdConfigDevice*) cast(KdConfigDevice*) calloc(1, KdConfigDevice.sizeof);
    if (!new_)
        return BadAlloc;

    new_.line = strdup(keyboard);
    new_.next = null;

    for (prev = &kdConfigKeyboards; *prev; prev = &(*prev).next){}
    *prev = new_;

    return Success;
}

int KdAddKeyboard(KdKeyboardInfo* ki)
{
    KdKeyboardInfo** prev = void;

    if (!ki)
        return !Success;

    ki.dixdev = AddInputDevice(serverClient, &KdKeyboardProc, True);
    if (!ki.dixdev) {
        ErrorF("Couldn't register keyboard device %s\n",
               ki.name ? ki.name : "(unnamed)");
        return !Success;
    }

version (DEBUG) {
    ErrorF("added keyboard %s with dix id %d\n", ki.name, ki.dixdev.id);
}

    for (prev = &kdKeyboards; *prev; prev = &(*prev).next){}
    *prev = ki;

    return Success;
}

void KdRemoveKeyboard(KdKeyboardInfo* ki)
{
    KdKeyboardInfo** prev = void;

    if (!ki)
        return;

    for (prev = &kdKeyboards; *prev; prev = &(*prev).next) {
        if (*prev == ki) {
            *prev = ki.next;
            break;
        }
    }

    KdFreeKeyboard(ki);
}

int KdAddConfigPointer(const(char)* pointer)
{
    KdConfigDevice** prev = void; KdConfigDevice* new_ = void;

    if (!pointer)
        return Success;

    new_ = cast(KdConfigDevice*) cast(KdConfigDevice*) calloc(1, KdConfigDevice.sizeof);
    if (!new_)
        return BadAlloc;

    new_.line = strdup(pointer);
    new_.next = null;

    for (prev = &kdConfigPointers; *prev; prev = &(*prev).next){}
    *prev = new_;

    return Success;
}

int KdAddPointer(KdPointerInfo* pi)
{
    KdPointerInfo** prev = void;

    if (!pi)
        return Success;

    pi.mouseState = start;
    pi.eventHeld = False;

    pi.dixdev = AddInputDevice(serverClient, &KdPointerProc, True);
    if (!pi.dixdev) {
        ErrorF("Couldn't add pointer device %s\n",
               pi.name ? pi.name : "(unnamed)");
        return BadDevice;
    }

    for (prev = &kdPointers; *prev; prev = &(*prev).next){}
    *prev = pi;

    return Success;
}

void KdRemovePointer(KdPointerInfo* pi)
{
    KdPointerInfo** prev = void;

    if (!pi)
        return;

    for (prev = &kdPointers; *prev; prev = &(*prev).next) {
        if (*prev == pi) {
            *prev = pi.next;
            break;
        }
    }

    KdFreePointer(pi);
}

/*
 * You can call your kdriver server with something like:
 * $ ./hw/kdrive/yourserver/X :1 -mouse evdev,,device=/dev/input/event4 -keybd
 * evdev,,device=/dev/input/event1,xkbmodel=abnt2,xkblayout=br
 */
Bool KdGetOptions(InputOption** options, char* string)
{
    InputOption* newopt = null;
    char* key = null, value = null;
    int tam_key = 0;

    if (strchr(string, '=')) {
        tam_key = (strchr(string, '=') - string);
        key = strndup(string, tam_key);
        if (!key)
            goto out_;

        value = strdup(strchr(string, '=') + 1);
        if (!value)
            goto out_;
    }
    else {
        key = strdup(string);
        value = null;
    }

    newopt = input_option_new(*options, key, value);
    if (newopt)
        *options = newopt;

 out_:
    free(key);
    free(value);

    return (newopt !is null);
}

static void
KdParseKbdOptions(KdKeyboardInfo* ki)
{
    InputOption* option = null;

    mixin(nt_list_for_each_entry!("option", "ki.options", "list.next")); {
        const(char)* key = input_option_get_key(option);
        const(char)* value = input_option_get_value(option);

        bool xkbRulesCond = strcasecmp(key, "XkbRules") == 0 ;
        bool xkbModelCond = strcasecmp(key, "XkbModel") == 0 ;
        bool xkbLayoutCond = strcasecmp(key, "XkbLayout") == 0 ;
        bool xkbVariantCond = strcasecmp(key, "XkbVariant") == 0 ;
        bool xkbOptionsCond = strcasecmp(key, "XkbOptions") == 0 ;

static if(HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
    xkbRulesCond = xkbRulesCond || strcasecmp(key, "xkb_rules") == 0;
    xkbModelCond = xkbModelCond || strcasecmp(key, "xkb_model") == 0;
    xkbLayoutCond = xkbLayoutCond || strcasecmp(key, "xkb_layot") == 0;
    xkbVariantCond = xkbVariantCond || strcasecmp(key, "xkb_variant") == 0;
    xkbOptionsCond = xkbOptionsCond || strcasecmp(key, "xkb_options") == 0;

}





        if (xkbRulesCond)
            ki.xkbRules = strdup(value);
        else if (xkbModelCond)
            ki.xkbModel = strdup(value);
        else if (xkbLayoutCond)
            ki.xkbLayout = strdup(value);
        else if (xkbVariantCond)
            ki.xkbVariant = strdup(value);
        else if (xkbOptionsCond)
            ki.xkbOptions = strdup(value);
        else if(strcasecmp) {
            if (ki.path !is null)
                free(ki.path);
            ki.path = strdup(value);
        }
static if (HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
        if(strcasecmp) {
            if (ki.path !is null)
                free(ki.path);
            ki.path = strdup(value);
        }
        else if(strcasecmp) {
            free(ki.name);
            ki.name = strdup(value);
        }
}
        if (!strcasecmp(key, "driver"))
            ki.driver = KdFindKeyboardDriver(value);
        else
            ErrorF("Kbd option key (%s) of value (%s) not assigned!\n",
                   key, value);
    }

version (KDRIVE_EVDEV) {
    if (!ki.driver && ki.path !is null &&
        strncasecmp(ki.path,
                    DEV_INPUT_EVENT_PREFIX,
                    DEV_INPUT_EVENT_PREFIX_LEN) == 0) {
            ki.driver = KdFindKeyboardDriver("evdev");
            ki.options = input_option_new(ki.options, "driver", "evdev");
    }
}
}

KdKeyboardInfo* KdParseKeyboard(const(char)* arg)
{
    char[1024] save = void;
    char delim = void;
    InputOption* options = null;
    KdKeyboardInfo* ki = null;

    ki = KdNewKeyboard();
    if (!ki)
        return null;

    if (ki.name)
        free(ki.name);
    ki.name = strdup("Unknown KDrive Keyboard");
    ki.path = null;
    ki.driver = null;
    ki.driver= null;
    ki.next = null;

    if (!arg) {
        ErrorF("keybd: no arg\n");
        KdFreeKeyboard(ki);
        return null;
    }

    if (strlen(arg) >= save.sizeof) {
        ErrorF("keybd: arg too long\n");
        KdFreeKeyboard(ki);
        return null;
    }

    arg = KdParseFindNext(arg, ",", save.ptr, &delim);
    if (!save[0]) {
        ErrorF("keybd: failed on save[0]\n");
        KdFreeKeyboard(ki);
        return null;
    }

    if (strcmp(save.ptr, "auto") == 0)
        ki.driver= null;
    else
        ki.driver= strdup(save.ptr);

    if (delim != ',') {
        return ki;
    }

    arg = KdParseFindNext(arg, ",", save.ptr, &delim);

    while (delim == ',') {
        arg = KdParseFindNext(arg, ",", save.ptr, &delim);

        if (!KdGetOptions(&options, save.ptr)) {
            KdFreeKeyboard(ki);
            return null;
        }
    }

    if (options) {
        ki.options = options;
        KdParseKbdOptions(ki);
    }

    return ki;
}

void KdParsePointerOptions(KdPointerInfo* pi)
{
    InputOption* option = null;

    mixin(nt_list_for_each_entry!("option", "pi.options", "list.next")); {
        const(char)* key = input_option_get_key(option);
        const(char)* value = input_option_get_value(option);

        if (!strcasecmp(key, "emulatemiddle"))
            pi.emulateMiddleButton = True;
        else if (!strcasecmp(key, "noemulatemiddle"))
            pi.emulateMiddleButton = False;
        else if (!strcasecmp(key, "transformcoord"))
            pi.transformCoordinates = True;
        else if (!strcasecmp(key, "rawcoord"))
            pi.transformCoordinates = False;
        else if (!strcasecmp(key, "device")) {
            if (pi.path !is null)
                free(pi.path);
            pi.path = strdup(value);
        }
static if (HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
        if(!strcasecmp(key, "path")) {
            if (pi.path !is null)
                free(pi.path);
            pi.path = strdup(value);
        }
        else if(!strcasecmp(key, "name")) {
            free(pi.name);
            pi.name = strdup(value);
        }
}else{}
        if (!strcasecmp(key, "protocol"))
            pi.protocol = strdup(value);
        else if (!strcasecmp(key, "driver"))
            pi.driver = KdFindPointerDriver(value);
        else
            ErrorF("Pointer option key (%s) of value (%s) not assigned!\n",
                   key, value);

version (KDRIVE_EVDEV) {
    if (!pi.driver && pi.path !is null &&
        strncasecmp(pi.path,
                    DEV_INPUT_EVENT_PREFIX,
                    DEV_INPUT_EVENT_PREFIX_LEN) == 0) {
            pi.driver = KdFindPointerDriver("evdev");
            pi.options = input_option_new(pi.options, "driver", "evdev");
    }
}
}
}

/*
 * Mouse argument syntax:
 *
 *  device,protocol,options...
 *
 *  Options are any of:
 *      1-5         n button mouse
 *      2button     emulate middle button
 *      {NMO}       Reorder buttons
 */
KdPointerInfo* KdParsePointer(const(char)* arg)
{
    char[1024] save = void;
    char delim = void;
    KdPointerInfo* pi = null;
    InputOption* options = null;
    int i = 0;

    pi = KdNewPointer();
    if (!pi)
        return null;
    pi.emulateMiddleButton = kdEmulateMiddleButton;
    pi.transformCoordinates = !kdRawPointerCoordinates;
    pi.protocol = null;
    pi.nButtons = 5;           /* XXX should not be hardcoded */
    pi.inputClass = KD_MOUSE;

    if (!arg) {
        ErrorF("mouse: no arg\n");
        KdFreePointer(pi);
        return null;
    }

    if (strlen(arg) >= save.sizeof) {
        ErrorF("mouse: arg too long\n");
        KdFreePointer(pi);
        return null;
    }
    arg = KdParseFindNext(arg, ",", save.ptr, &delim);
    if (!save[0]) {
        ErrorF("failed on save[0]\n");
        KdFreePointer(pi);
        return null;
    }

    if (strcmp(save.ptr, "auto") == 0)
        pi.driver= null;
    else
        pi.driver= strdup(save.ptr);

    if (delim != ',') {
        return pi;
    }

    arg = KdParseFindNext(arg, ",", save.ptr, &delim);

    while (delim == ',') {
        arg = KdParseFindNext(arg, ",", save.ptr, &delim);
        if (save[0] == '{') {
            char* s = save.ptr + 1;

            i = 0;
            while (*s && *s != '}') {
                if ('1' <= *s && *s <= '0' + pi.nButtons)
                    pi.map[i] = *s - '0';
                else
                    UseMsg();
                s++;
            }
        }
        else {
            if (!KdGetOptions(&options, save.ptr)) {
                KdFreePointer(pi);
                return null;
            }
        }
    }

    if (options) {
        pi.options = options;
        KdParsePointerOptions(pi);
    }

    return pi;
}

version (KDRIVE_KBD) {
enum DEFAULT_KEYBOARD = "keyboard";
} else {
version (KDRIVE_EVDEV) {
enum DEFAULT_KEYBOARD = "evdev";
}
}

version (KDRIVE_MOUSE) {
enum DEFAULT_MOUSE = "mouse";
} else {
version (KDRIVE_EVDEV) {
enum DEFAULT_MOUSE = "evdev";
}
}

void KdAddConfigInputDrivers()
{
    version (DEFAULT_KEYBOARD) {
    if (!kdConfigKeyboards) {
        KdAddConfigKeyboard(DEFAULT_KEYBOARD);
    }
    }

    version (DEFAULT_MOUSE) {
    if (!kdConfigPointers) {
        KdAddConfigPointer(DEFAULT_MOUSE);
    }
    }
}

void KdInitInput()
{
    KdPointerInfo* pi = void;
    KdKeyboardInfo* ki = void;
    KdConfigDevice* dev = void;

    if (kdConfigPointers || kdConfigKeyboards)
        InputThreadPreInit();

    kdInputEnabled = True;

    for (dev = kdConfigPointers; dev; dev = dev.next) {
        pi = KdParsePointer(dev.line);
        if (!pi)
            ErrorF("Failed to parse pointer\n");
        if (KdAddPointer(pi) != Success)
            ErrorF("Failed to add pointer!\n");
    }
    for (dev = kdConfigKeyboards; dev; dev = dev.next) {
        ki = KdParseKeyboard(dev.line);
        if (!ki)
            ErrorF("Failed to parse keyboard\n");
        if (KdAddKeyboard(ki) != Success)
            ErrorF("Failed to add keyboard!\n");
    }

    mieqInit();

static if (HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
    if (dixSettingSeatId) /* Enable input hot-plugging */
        config_init();
}
}

void KdCloseInput()
{
static if (HasVersion!"CONFIG_UDEV" || HasVersion!"CONFIG_HAL") {
    if (dixSettingSeatId) /* Input hot-plugging is enabled */
        config_fini();
}

    mieqFini();
}

/*
 * Middle button emulation state machine
 *
 *  Possible transitions:
 *	Button 1 press	    v1
 *	Button 1 release    ^1
 *	Button 2 press	    v2
 *	Button 2 release    ^2
 *	Button 3 press	    v3
 *	Button 3 release    ^3
 *	Button other press  vo
 *	Button other release ^o
 *	Mouse motion	    <>
 *	Keyboard event	    k
 *	timeout		    ...
 *	outside box	    <->
 *
 *  States:
 *	start
 *	button_1_pend
 *	button_1_down
 *	button_2_down
 *	button_3_pend
 *	button_3_down
 *	synthetic_2_down_13
 *	synthetic_2_down_3
 *	synthetic_2_down_1
 *
 *  Transition diagram
 *
 *  start
 *	v1  -> (hold) (settimeout) button_1_pend
 *	^1  -> (deliver) start
 *	v2  -> (deliver) button_2_down
 *	^2  -> (deliver) start
 *	v3  -> (hold) (settimeout) button_3_pend
 *	^3  -> (deliver) start
 *	vo  -> (deliver) start
 *	^o  -> (deliver) start
 *	<>  -> (deliver) start
 *	k   -> (deliver) start
 *
 *  button_1_pend	(button 1 is down, timeout pending)
 *	^1  -> (release) (deliver) start
 *	v2  -> (release) (deliver) button_1_down
 *	^2  -> (release) (deliver) button_1_down
 *	v3  -> (cleartimeout) (generate v2) synthetic_2_down_13
 *	^3  -> (release) (deliver) button_1_down
 *	vo  -> (release) (deliver) button_1_down
 *	^o  -> (release) (deliver) button_1_down
 *	<-> -> (release) (deliver) button_1_down
 *	<>  -> (deliver) button_1_pend
 *	k   -> (release) (deliver) button_1_down
 *	... -> (release) button_1_down
 *
 *  button_1_down	(button 1 is down)
 *	^1  -> (deliver) start
 *	v2  -> (deliver) button_1_down
 *	^2  -> (deliver) button_1_down
 *	v3  -> (deliver) button_1_down
 *	^3  -> (deliver) button_1_down
 *	vo  -> (deliver) button_1_down
 *	^o  -> (deliver) button_1_down
 *	<>  -> (deliver) button_1_down
 *	k   -> (deliver) button_1_down
 *
 *  button_2_down	(button 2 is down)
 *	v1  -> (deliver) button_2_down
 *	^1  -> (deliver) button_2_down
 *	^2  -> (deliver) start
 *	v3  -> (deliver) button_2_down
 *	^3  -> (deliver) button_2_down
 *	vo  -> (deliver) button_2_down
 *	^o  -> (deliver) button_2_down
 *	<>  -> (deliver) button_2_down
 *	k   -> (deliver) button_2_down
 *
 *  button_3_pend	(button 3 is down, timeout pending)
 *	v1  -> (generate v2) synthetic_2_down
 *	^1  -> (release) (deliver) button_3_down
 *	v2  -> (release) (deliver) button_3_down
 *	^2  -> (release) (deliver) button_3_down
 *	^3  -> (release) (deliver) start
 *	vo  -> (release) (deliver) button_3_down
 *	^o  -> (release) (deliver) button_3_down
 *	<-> -> (release) (deliver) button_3_down
 *	<>  -> (deliver) button_3_pend
 *	k   -> (release) (deliver) button_3_down
 *	... -> (release) button_3_down
 *
 *  button_3_down	(button 3 is down)
 *	v1  -> (deliver) button_3_down
 *	^1  -> (deliver) button_3_down
 *	v2  -> (deliver) button_3_down
 *	^2  -> (deliver) button_3_down
 *	^3  -> (deliver) start
 *	vo  -> (deliver) button_3_down
 *	^o  -> (deliver) button_3_down
 *	<>  -> (deliver) button_3_down
 *	k   -> (deliver) button_3_down
 *
 *  synthetic_2_down_13	(button 1 and 3 are down)
 *	^1  -> (generate ^2) synthetic_2_down_3
 *	v2  -> synthetic_2_down_13
 *	^2  -> synthetic_2_down_13
 *	^3  -> (generate ^2) synthetic_2_down_1
 *	vo  -> (deliver) synthetic_2_down_13
 *	^o  -> (deliver) synthetic_2_down_13
 *	<>  -> (deliver) synthetic_2_down_13
 *	k   -> (deliver) synthetic_2_down_13
 *
 *  synthetic_2_down_3 (button 3 is down)
 *	v1  -> (deliver) synthetic_2_down_3
 *	^1  -> (deliver) synthetic_2_down_3
 *	v2  -> synthetic_2_down_3
 *	^2  -> synthetic_2_down_3
 *	^3  -> start
 *	vo  -> (deliver) synthetic_2_down_3
 *	^o  -> (deliver) synthetic_2_down_3
 *	<>  -> (deliver) synthetic_2_down_3
 *	k   -> (deliver) synthetic_2_down_3
 *
 *  synthetic_2_down_1 (button 1 is down)
 *	^1  -> start
 *	v2  -> synthetic_2_down_1
 *	^2  -> synthetic_2_down_1
 *	v3  -> (deliver) synthetic_2_down_1
 *	^3  -> (deliver) synthetic_2_down_1
 *	vo  -> (deliver) synthetic_2_down_1
 *	^o  -> (deliver) synthetic_2_down_1
 *	<>  -> (deliver) synthetic_2_down_1
 *	k   -> (deliver) synthetic_2_down_1
 */

enum KdInputClass {
    down_1, up_1,
    down_2, up_2,
    down_3, up_3,
    down_o, up_o,
    motion, outside_box,
    keyboard, timeout,
    num_input_class
}
alias down_1 = KdInputClass.down_1;
alias up_1 = KdInputClass.up_1;
alias down_2 = KdInputClass.down_2;
alias up_2 = KdInputClass.up_2;
alias down_3 = KdInputClass.down_3;
alias up_3 = KdInputClass.up_3;
alias down_o = KdInputClass.down_o;
alias up_o = KdInputClass.up_o;
alias motion = KdInputClass.motion;
alias outside_box = KdInputClass.outside_box;
alias keyboard = KdInputClass.keyboard;
alias timeout = KdInputClass.timeout;
alias num_input_class = KdInputClass.num_input_class;


enum KdInputAction {
    noop,
    hold,
    setto,
    deliver,
    release,
    clearto,
    gen_down_2,
    gen_up_2
}
alias noop = KdInputAction.noop;
alias hold = KdInputAction.hold;
alias setto = KdInputAction.setto;
alias deliver = KdInputAction.deliver;
alias release = KdInputAction.release;
alias clearto = KdInputAction.clearto;
alias gen_down_2 = KdInputAction.gen_down_2;
alias gen_up_2 = KdInputAction.gen_up_2;


enum MAX_ACTIONS = 2;

struct KdInputTransition {
    KdInputAction[MAX_ACTIONS] actions;
    KdPointerState nextState;
}

const(KdInputTransition)[num_input_class][num_input_states] kdInputMachine = [
    /* start */
    [
     {[hold, setto], button_1_pend},    /* v1 */
     {[deliver, noop], start},  /* ^1 */
     {[deliver, noop], button_2_down},  /* v2 */
     {[deliver, noop], start},  /* ^2 */
     {[hold, setto], button_3_pend},    /* v3 */
     {[deliver, noop], start},  /* ^3 */
     {[deliver, noop], start},  /* vo */
     {[deliver, noop], start},  /* ^o */
     {[deliver, noop], start},  /* <> */
     {[deliver, noop], start},  /* <-> */
     {[noop, noop], start},     /* k */
     {[noop, noop], start},     /* ... */
     ],
    /* button_1_pend */
    [
     {[noop, noop], button_1_pend},     /* v1 */
     {[release, deliver], start},       /* ^1 */
     {[release, deliver], button_1_down},       /* v2 */
     {[release, deliver], button_1_down},       /* ^2 */
     {[clearto, gen_down_2], synth_2_down_13},  /* v3 */
     {[release, deliver], button_1_down},       /* ^3 */
     {[release, deliver], button_1_down},       /* vo */
     {[release, deliver], button_1_down},       /* ^o */
     {[deliver, noop], button_1_pend},  /* <> */
     {[release, deliver], button_1_down},       /* <-> */
     {[noop, noop], button_1_down},     /* k */
     {[release, noop], button_1_down},  /* ... */
     ],
    /* button_1_down */
    [
     {[noop, noop], button_1_down},     /* v1 */
     {[deliver, noop], start},  /* ^1 */
     {[deliver, noop], button_1_down},  /* v2 */
     {[deliver, noop], button_1_down},  /* ^2 */
     {[deliver, noop], button_1_down},  /* v3 */
     {[deliver, noop], button_1_down},  /* ^3 */
     {[deliver, noop], button_1_down},  /* vo */
     {[deliver, noop], button_1_down},  /* ^o */
     {[deliver, noop], button_1_down},  /* <> */
     {[deliver, noop], button_1_down},  /* <-> */
     {[noop, noop], button_1_down},     /* k */
     {[noop, noop], button_1_down},     /* ... */
     ],
    /* button_2_down */
    [
     {[deliver, noop], button_2_down},  /* v1 */
     {[deliver, noop], button_2_down},  /* ^1 */
     {[noop, noop], button_2_down},     /* v2 */
     {[deliver, noop], start},  /* ^2 */
     {[deliver, noop], button_2_down},  /* v3 */
     {[deliver, noop], button_2_down},  /* ^3 */
     {[deliver, noop], button_2_down},  /* vo */
     {[deliver, noop], button_2_down},  /* ^o */
     {[deliver, noop], button_2_down},  /* <> */
     {[deliver, noop], button_2_down},  /* <-> */
     {[noop, noop], button_2_down},     /* k */
     {[noop, noop], button_2_down},     /* ... */
     ],
    /* button_3_pend */
    [
     {[clearto, gen_down_2], synth_2_down_13},  /* v1 */
     {[release, deliver], button_3_down},       /* ^1 */
     {[release, deliver], button_3_down},       /* v2 */
     {[release, deliver], button_3_down},       /* ^2 */
     {[release, deliver], button_3_down},       /* v3 */
     {[release, deliver], start},       /* ^3 */
     {[release, deliver], button_3_down},       /* vo */
     {[release, deliver], button_3_down},       /* ^o */
     {[deliver, noop], button_3_pend},  /* <> */
     {[release, deliver], button_3_down},       /* <-> */
     {[release, noop], button_3_down},  /* k */
     {[release, noop], button_3_down},  /* ... */
     ],
    /* button_3_down */
    [
     {[deliver, noop], button_3_down},  /* v1 */
     {[deliver, noop], button_3_down},  /* ^1 */
     {[deliver, noop], button_3_down},  /* v2 */
     {[deliver, noop], button_3_down},  /* ^2 */
     {[noop, noop], button_3_down},     /* v3 */
     {[deliver, noop], start},  /* ^3 */
     {[deliver, noop], button_3_down},  /* vo */
     {[deliver, noop], button_3_down},  /* ^o */
     {[deliver, noop], button_3_down},  /* <> */
     {[deliver, noop], button_3_down},  /* <-> */
     {[noop, noop], button_3_down},     /* k */
     {[noop, noop], button_3_down},     /* ... */
     ],
    /* synthetic_2_down_13 */
    [
     {[noop, noop], synth_2_down_13},   /* v1 */
     {[gen_up_2, noop], synth_2_down_3},        /* ^1 */
     {[noop, noop], synth_2_down_13},   /* v2 */
     {[noop, noop], synth_2_down_13},   /* ^2 */
     {[noop, noop], synth_2_down_13},   /* v3 */
     {[gen_up_2, noop], synth_2_down_1},        /* ^3 */
     {[deliver, noop], synth_2_down_13},        /* vo */
     {[deliver, noop], synth_2_down_13},        /* ^o */
     {[deliver, noop], synth_2_down_13},        /* <> */
     {[deliver, noop], synth_2_down_13},        /* <-> */
     {[noop, noop], synth_2_down_13},   /* k */
     {[noop, noop], synth_2_down_13},   /* ... */
     ],
    /* synthetic_2_down_3 */
    [
     {[deliver, noop], synth_2_down_3}, /* v1 */
     {[deliver, noop], synth_2_down_3}, /* ^1 */
     {[deliver, noop], synth_2_down_3}, /* v2 */
     {[deliver, noop], synth_2_down_3}, /* ^2 */
     {[noop, noop], synth_2_down_3},    /* v3 */
     {[noop, noop], start},     /* ^3 */
     {[deliver, noop], synth_2_down_3}, /* vo */
     {[deliver, noop], synth_2_down_3}, /* ^o */
     {[deliver, noop], synth_2_down_3}, /* <> */
     {[deliver, noop], synth_2_down_3}, /* <-> */
     {[noop, noop], synth_2_down_3},    /* k */
     {[noop, noop], synth_2_down_3},    /* ... */
     ],
    /* synthetic_2_down_1 */
    [
     {[noop, noop], synth_2_down_1},    /* v1 */
     {[noop, noop], start},     /* ^1 */
     {[deliver, noop], synth_2_down_1}, /* v2 */
     {[deliver, noop], synth_2_down_1}, /* ^2 */
     {[deliver, noop], synth_2_down_1}, /* v3 */
     {[deliver, noop], synth_2_down_1}, /* ^3 */
     {[deliver, noop], synth_2_down_1}, /* vo */
     {[deliver, noop], synth_2_down_1}, /* ^o */
     {[deliver, noop], synth_2_down_1}, /* <> */
     {[deliver, noop], synth_2_down_1}, /* <-> */
     {[noop, noop], synth_2_down_1},    /* k */
     {[noop, noop], synth_2_down_1},    /* ... */
     ],
];

enum EMULATION_WINDOW =    10;
enum EMULATION_TIMEOUT =   100;

int KdInsideEmulationWindow(KdPointerInfo* pi, int x, int y, int z)
{
    pi.emulationDx = pi.heldEvent.x - x;
    pi.emulationDy = pi.heldEvent.y - y;

    return (abs(pi.emulationDx) < EMULATION_WINDOW &&
            abs(pi.emulationDy) < EMULATION_WINDOW);
}

KdInputClass KdClassifyInput(KdPointerInfo* pi, int type, int x, int y, int z, int b)
{
    switch (type) {
    case ButtonPress:
        switch (b) {
        case 1:
            return down_1;
        case 2:
            return down_2;
        case 3:
            return down_3;
        default:
            return down_o;
        }
        break;
    case ButtonRelease:
        switch (b) {
        case 1:
            return up_1;
        case 2:
            return up_2;
        case 3:
            return up_3;
        default:
            return up_o;
        }
        break;
    case MotionNotify:
        if (pi.eventHeld && !KdInsideEmulationWindow(pi, x, y, z))
            return outside_box;
        else
            return motion;
    default:
        return keyboard;
    }
    return keyboard;
}

/* We return true if we're stealing the event. */
Bool KdRunMouseMachine(KdPointerInfo* pi, KdInputClass c, int type, int x, int y, int z, int b, int absrel)
{
    const(KdInputTransition)* t = void;
    int a = void;

    c = KdClassifyInput(pi, type, x, y, z, b);
    t = &kdInputMachine[pi.mouseState][c];
    for (a = 0; a < MAX_ACTIONS; a++) {
        switch (t.actions[a]) {
        case noop:
            break;
        case hold:
            pi.eventHeld = True;
            pi.emulationDx = 0;
            pi.emulationDy = 0;
            pi.heldEvent.type = type;
            pi.heldEvent.x = x;
            pi.heldEvent.y = y;
            pi.heldEvent.z = z;
            pi.heldEvent.flags = b;
            pi.heldEvent.absrel = absrel;
            return True;
            break;
        case setto:
            pi.emulationTimeout = GetTimeInMillis() + EMULATION_TIMEOUT;
            pi.timeoutPending = True;
            break;
        case deliver:
            _KdEnqueuePointerEvent(pi, pi.heldEvent.type, pi.heldEvent.x,
                                   pi.heldEvent.y, pi.heldEvent.z,
                                   pi.heldEvent.flags, pi.heldEvent.absrel,
                                   True);
            break;
        case release:
            pi.eventHeld = False;
            pi.timeoutPending = False;
            _KdEnqueuePointerEvent(pi, pi.heldEvent.type, pi.heldEvent.x,
                                   pi.heldEvent.y, pi.heldEvent.z,
                                   pi.heldEvent.flags, pi.heldEvent.absrel,
                                   True);
            return True;
            break;
        case clearto:
            pi.timeoutPending = False;
            break;
        case gen_down_2:
            _KdEnqueuePointerEvent(pi, ButtonPress, x, y, z, 2, absrel, True);
            pi.eventHeld = False;
            return True;
            break;
        case gen_up_2:
            _KdEnqueuePointerEvent(pi, ButtonRelease, x, y, z, 2, absrel, True);
            return True;
            break;
        default: break;}
    }
    pi.mouseState = t.nextState;
    return False;
}

int KdHandlePointerEvent(KdPointerInfo* pi, int type, int x, int y, int z, int b, int absrel)
{
    if (pi.emulateMiddleButton)
        return KdRunMouseMachine(pi, KdClassifyInput(pi, type, x, y, z, b),
                                 type, x, y, z, b, absrel);
    return False;
}

void _KdEnqueuePointerEvent(KdPointerInfo* pi, int type, int x, int y, int z, int b, int absrel, Bool force)
{
    int[3] valuators = [ x, y, z ];
    ValuatorMask mask = void;

    /* True from KdHandlePointerEvent, means 'we swallowed the event'. */
    if (!force && KdHandlePointerEvent(pi, type, x, y, z, b, absrel))
        return;

    valuator_mask_set_range(&mask, 0, 3, valuators.ptr);

    QueuePointerEvents(pi.dixdev, type, b, absrel, &mask);
}

void KdReceiveTimeout(KdPointerInfo* pi)
{
    KdRunMouseMachine(pi, timeout, 0, 0, 0, 0, 0, 0);
}

void KdReleaseAllKeys()
{
version (none) {
    int key = void;
    KdKeyboardInfo* ki = void;

    input_lock();

    for (ki = kdKeyboards; ki; ki = ki.next) {
        for (key = ki.keySyms.minKeyCode; key < ki.keySyms.maxKeyCode; key++) {
            if (key_is_down(ki.dixdev, key, KEY_POSTED | KEY_PROCESSED)) {
                KdHandleKeyboardEvent(ki, KeyRelease, key);
                QueueGetKeyboardEvents(ki.dixdev, KeyRelease, key, null);
            }
        }
    }

    input_unlock();
}
}

void KdCheckLock()
{
    KeyClassPtr keyc = null;
    Bool isSet = False, shouldBeSet = False;
    KdKeyboardInfo* tmp = null;

    for (tmp = kdKeyboards; tmp; tmp = tmp.next) {
        if (tmp.LockLed && tmp.dixdev && tmp.dixdev.key) {
            keyc = tmp.dixdev.key;
            isSet = (tmp.leds & (1 << (tmp.LockLed - 1))) != 0;
            /* FIXME: Just use XKB indicators! */
            shouldBeSet =
                ! !(XkbStateFieldFromRec(&keyc.xkbInfo.state) & LockMask);
            if (isSet != shouldBeSet)
                KdSetLed(tmp, tmp.LockLed, shouldBeSet);
        }
    }
}

KeySym KdKeyCodeToKeySym(KdKeyboardInfo* ki, int type, ubyte key_code)
{
    ubyte scan_code = key_code - KD_MIN_KEYCODE + ki.minScanCode;
    cast(void)type;

    /**
     * XXX This looks really sketchy XXX
     * Surely there is a way to query this from xkb?
     * This doesn't work:
     * return kbd->key->xkbInfo->desc->map->modmap[key_code];
     *
     * Scancodes are taken from https://aeb.win.tue.nl/linux/kbd/scancodes-1.html
     *
     * Only a few keys we are interested in are listed here.
     * If we ever need more keys, we can add them later.
     */

enum KEY_BACKSPACE = 0x0E;
enum KEY_F1 = 0x3B;
enum KEY_F2 = 0x3C;
enum KEY_F3 = 0x3D;
enum KEY_F4 = 0x3E;
enum KEY_F5 = 0x3F;
enum KEY_F6 = 0x40;
enum KEY_F7 = 0x41;
enum KEY_F8 = 0x42;
enum KEY_F9 = 0x43;
enum KEY_F10 = 0x44;

/**
 * The driver doesn't differentiate between E0 53 and 53,
 * so both are treated as the delete key being pressed
 */
enum KEY_DEL = 0x53;

    switch(scan_code) {
        case KEY_BACKSPACE:
            return XK_BackSpace;
        case KEY_F1:
            return XK_F1;
        case KEY_F2:
            return XK_F2;
        case KEY_F3:
            return XK_F3;
        case KEY_F4:
            return XK_F4;
        case KEY_F5:
            return XK_F5;
        case KEY_F6:
            return XK_F6;
        case KEY_F7:
            return XK_F7;
        case KEY_F8:
            return XK_F8;
        case KEY_F9:
            return XK_F9;
        case KEY_F10:
            return XK_F10;
version (none) { /* Doesn't work from my testing */
        case KEY_DEL:
            return XK_Delete;
}
    default: break;}

    return XK_VoidSymbol;
}

/**
 * Returns False if we should treat this like a regular keyboard event
 * Returns True if we should fixup the event
 */
Bool KdCheckSpecialKeys(KdKeyboardInfo* ki, int type, ubyte key_code)
{
    KeySym sym = void;

    /*
     * Ignore key releases
     */

    if (type == KeyRelease) {
        return False;
    }

    /*
     * Check for control/alt pressed
     */
    if ((XkbStateFieldFromRec(&ki.dixdev.key.xkbInfo.state) & (ControlMask | Mod1Mask)) !=
        (ControlMask | Mod1Mask)) {
        return False;
    }

    sym = KdKeyCodeToKeySym(ki, type, key_code);
    if (sym == XK_VoidSymbol) {
        return False;
    }

    /*
     * Let OS function see keysym first
     */

    if (kdOsFuncs.SpecialKey)
        if ((*kdOsFuncs.SpecialKey) (sym))
            return True;

    /*
     * Now check for backspace or delete; these signal the
     * X server to terminate
     */
    switch (sym) {
    case XK_BackSpace:
    case XK_Delete:
    case XK_KP_Delete:
        /*
         * Set the dispatch exception flag so the server will terminate the
         * next time through the dispatch loop.
         */
        if (kdAllowZap)
            dispatchException |= DE_TERMINATE;
        break;
    default: break;}

    return False;
}

void KdEnqueueKeyboardEvent(KdKeyboardInfo* ki, ubyte scan_code, ubyte is_up)
{
    ubyte key_code = void;
    int type = void;

    if (!ki || !ki.dixdev || !ki.dixdev.kbdfeed || !ki.dixdev.key)
        return;

    if (scan_code >= ki.minScanCode && scan_code <= ki.maxScanCode) {
        key_code = scan_code + KD_MIN_KEYCODE - ki.minScanCode;

        /*
         * Set up this event -- the type may be modified below
         */
        if (is_up) {
            type = KeyRelease;
            ki.last_scan_code = -1;
        } else {
            type = KeyPress;
            ki.last_scan_code = scan_code;
        }

        /**
         * Right now, the only special keys we have
         * either terminate the server or switch vt.
         *
         * We don't really cares what happens if we terminate,
         * but we do care if we switch vt.
         *
         * If we switch vt, the input driver sees the key press
         * event, but it does't see the key release event.
         * As such, when we switch back to the original vt,
         * the server thinks we are still pressing the F* key.
         *
         * To mitigate this, we can do one of two things:
         *
         * Forge the key release event that the server
         * doesn't see, and 2 key release events for
         * the crtl key and the alt key and enqueue them.
         *
         * Not enqueue the key press event at all,
         * and only forge 2 key release events,
         * one for the crtl key, another for the alt key.
         *
         * Below, the latter option is implemented.
         */

        /* Scancodes are taken from https://aeb.win.tue.nl/linux/kbd/scancodes-1.html */

        enum KEY_CTRL = 0x1D;
        enum KEY_ALT = 0x38;

version (none) { /* First option */
        Bool ret = KdCheckSpecialKeys(ki, type, key_code);
        QueueKeyboardEvents(ki.dixdev, type, key_code);
        if (ret) {
            ubyte ctrl_key_code = KEY_CTRL + KD_MIN_KEYCODE - ki.minScanCode;
            ubyte alt_key_code = KEY_ALT + KD_MIN_KEYCODE - ki.minScanCode;
            QueueKeyboardEvents(ki.dixdev, KeyRelease, key_code);
            QueueKeyboardEvents(ki.dixdev, KeyRelease, ctrl_key_code);
            QueueKeyboardEvents(ki.dixdev, KeyRelease, alt_key_code);
            ki.last_scan_code = -1; /* No need to fix this scancode up again */
        }
} else { /* Second option */
        if (!KdCheckSpecialKeys(ki, type, key_code)) {
            QueueKeyboardEvents(ki.dixdev, type, key_code);
        } else {
            ubyte ctrl_key_code = KEY_CTRL + KD_MIN_KEYCODE - ki.minScanCode;
            ubyte alt_key_code = KEY_ALT + KD_MIN_KEYCODE - ki.minScanCode;
            QueueKeyboardEvents(ki.dixdev, KeyRelease, ctrl_key_code);
            QueueKeyboardEvents(ki.dixdev, KeyRelease, alt_key_code);
            ki.last_scan_code = -1; /* No need to fix this scancode up again */
        }
}
    }
    else {
        ErrorF("driver %s wanted to post scancode %d outside of [%d, %d]!\n",
               ki.name, scan_code, ki.minScanCode, ki.maxScanCode);
    }
}

/*
 * kdEnqueuePointerEvent
 *
 * This function converts hardware mouse event information into X event
 * information.  A mouse movement event is passed off to MI to generate
 * a MotionNotify event, if appropriate.  Button events are created and
 * passed off to MI for enqueueing.
 */

/* FIXME do something a little more clever to deal with multiple axes here */
void KdEnqueuePointerEvent(KdPointerInfo* pi, c_ulong flags, int rx, int ry, int rz)
{
    ubyte buttons = void;
    int x = void, y = void, z = void;
    int[3]* matrix = kdPointerMatrix.matrix;
    c_ulong button = void;
    int n = void;
    int dixflags = 0;

    if (!pi)
        return;

    /* we don't need to transform z, so we don't. */
    if (flags & KD_MOUSE_DELTA) {
        if (pi.transformCoordinates) {
            x = matrix[0][0] * rx + matrix[0][1] * ry;
            y = matrix[1][0] * rx + matrix[1][1] * ry;
        }
        else {
            x = rx;
            y = ry;
        }
    }
    else {
        if (pi.transformCoordinates) {
            x = matrix[0][0] * rx + matrix[0][1] * ry + matrix[0][2];
            y = matrix[1][0] * rx + matrix[1][1] * ry + matrix[1][2];
        }
        else {
            x = rx;
            y = ry;
        }
    }
    z = rz;

    if (flags & KD_MOUSE_DELTA) {
        if (x || y || z) {
            dixflags = POINTER_RELATIVE | POINTER_ACCELERATE;
            _KdEnqueuePointerEvent(pi, MotionNotify, x, y, z, 0, dixflags,
                                   False);
        }
    }
    else {
        dixflags = POINTER_ABSOLUTE;
        if (flags & KD_POINTER_DESKTOP)
            dixflags |= POINTER_DESKTOP;
        if (x != pi.dixdev.last.valuators[0] ||
            y != pi.dixdev.last.valuators[1])
            _KdEnqueuePointerEvent(pi, MotionNotify, x, y, z, 0, dixflags,
                                   False);
    }

    buttons = flags;

    for (button = KD_BUTTON_1, n = 1; n <= pi.nButtons; button <<= 1, n++) {
        if (((pi.buttonState & button) ^ (buttons & button)) &&
            !(buttons & button)) {
            _KdEnqueuePointerEvent(pi, ButtonRelease, x, y, z, n,
                                   dixflags, False);
        }
    }
    for (button = KD_BUTTON_1, n = 1; n <= pi.nButtons; button <<= 1, n++) {
        if (((pi.buttonState & button) ^ (buttons & button)) &&
            (buttons & button)) {
            _KdEnqueuePointerEvent(pi, ButtonPress, x, y, z, n,
                                   dixflags, False);
        }
    }

    pi.buttonState = buttons;
}

void KdBlockHandler(ScreenPtr pScreen, void* timeo)
{
    KdPointerInfo* pi = void;
    int myTimeout = 0;

    for (pi = kdPointers; pi; pi = pi.next) {
        if (pi.timeoutPending) {
            int ms = void;

            ms = pi.emulationTimeout - GetTimeInMillis();
            if (ms < 1)
                ms = 1;
            if (ms < myTimeout || myTimeout == 0)
                myTimeout = ms;
        }
    }
    /* if we need to poll for events, do that */
    if (kdOsFuncs.pollEvents) {
        kdOsFuncs.pollEvents();
        myTimeout = 20;
    }
    if (myTimeout > 0)
        AdjustWaitForDelay(timeo, myTimeout);
}

void KdWakeupHandler(ScreenPtr pScreen, int result)
{
    KdPointerInfo* pi = void;

    for (pi = kdPointers; pi; pi = pi.next) {
        if (pi.timeoutPending) {
            if (cast(c_long) (GetTimeInMillis() - pi.emulationTimeout) >= 0) {
                pi.timeoutPending = False;
                input_lock();
                KdReceiveTimeout(pi);
                input_unlock();
            }
        }
    }
    if (kdSwitchPending)
        KdProcessSwitch();
}

enum string KdScreenOrigin(string pScreen) = `(&(KdGetScreenPriv(` ~ pScreen ~ `).screen.origin))`;

Bool KdCursorOffScreen(ScreenPtr* ppScreen, int* x, int* y)
{
    ScreenPtr pScreen = *ppScreen;
    int best_x = void, best_y = void;
    int n_best_x = void, n_best_y = void;
    CARD32 ms = void;

    if (kdDisableZaphod || (!dixScreenExists(1)))
        return False;

    if (0 <= *x && *x < pScreen.width && 0 <= *y && *y < pScreen.height)
        return False;

    ms = GetTimeInMillis();
    if (kdOffScreen && cast(int) (ms - kdOffScreenTime) < 1000)
        return False;
    kdOffScreen = True;
    kdOffScreenTime = ms;
    n_best_x = -1;
    best_x = 32767;
    n_best_y = -1;
    best_y = 32767;

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (walkScreen == pScreen)
            continue;
        int dx = mixin(KdScreenOrigin!(`walkScreen`)).x - mixin(KdScreenOrigin!(`pScreen`)).x;
        int dy = mixin(KdScreenOrigin!(`walkScreen`)).y - mixin(KdScreenOrigin!(`pScreen`)).y;
        if (*x < 0) {
            if (dx < 0 && -dx < best_x) {
                best_x = -dx;
                n_best_x = walkScreenIdx;
            }
        }
        else if (*x >= pScreen.width) {
            if (dx > 0 && dx < best_x) {
                best_x = dx;
                n_best_x = walkScreenIdx;
            }
        }
        if (*y < 0) {
            if (dy < 0 && -dy < best_y) {
                best_y = -dy;
                n_best_y = walkScreenIdx;
            }
        }
        else if (*y >= pScreen.height) {
            if (dy > 0 && dy < best_y) {
                best_y = dy;
                n_best_y = walkScreenIdx;
            }
        }
    });

    if (best_y < best_x)
        n_best_x = n_best_y;
    if (n_best_x == -1)
        return False;

    ScreenPtr pNewScreen = dixGetScreenPtr(cast(uint)n_best_x);

    if (*x < 0)
        *x += pNewScreen.width;
    if (*y < 0)
        *y += pNewScreen.height;

    if (*x >= pScreen.width)
        *x -= pScreen.width;
    if (*y >= pScreen.height)
        *y -= pScreen.height;

    *ppScreen = pNewScreen;
    return True;
}

void KdCrossScreen(ScreenPtr pScreen, Bool entering)
{
}

int KdCurScreen;                /* current event screen */

void KdWarpCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    input_lock();
    miPointerWarpCursor(pDev, pScreen, x, y);
    input_unlock();
}

miPointerScreenFuncRec kdPointerScreenFuncs = {
    &KdCursorOffScreen,
    &KdCrossScreen,
    &KdWarpCursor
};

void ProcessInputEvents()
{
    mieqProcessInputEvents();
    if (kdSwitchPending)
        KdProcessSwitch();
    KdCheckLock();
}

/* At the moment, absolute/relative is up to the client. */
// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int SetDeviceMode(ClientPtr client, DeviceIntPtr pDev, int mode)
{
    return BadMatch;
}

// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int SetDeviceValuators(ClientPtr client, DeviceIntPtr pDev, int* valuators, int first_valuator, int num_valuators)
{
    return BadMatch;
}

// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int ChangeDeviceControl(ClientPtr client, DeviceIntPtr pDev, xDeviceCtl* control)
{
    switch (control.control) {
    case DEVICE_RESOLUTION:
        /* FIXME do something more intelligent here */
        return BadMatch;

    case DEVICE_ABS_CALIB:
    case DEVICE_ABS_AREA:
    case DEVICE_CORE:
        return BadMatch;
    case DEVICE_ENABLE:
        return Success;

    default:
        return BadMatch;
    }

    /* NOTREACHED */
    return BadImplementation;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int NewInputDeviceRequest(InputOption* options, InputAttributes* attrs, DeviceIntPtr* pdev)
{
    InputOption* option = null, optionsdup = null;
    KdPointerInfo* pi = null;
    KdKeyboardInfo* ki = null;

    mixin(nt_list_for_each_entry!("option", "options", "list.next")); {
        const(char)* key = input_option_get_key(option);
        const(char)* value = input_option_get_value(option);
        optionsdup = input_option_new(optionsdup, key, value);

        if (strcmp(key, "type") == 0) {
            if (strcmp(value, "pointer") == 0) {
                pi = KdNewPointer();
                if (!pi) {
                    input_option_free_list(&optionsdup);
                    return BadAlloc;
                }
            }
            else if (strcmp(value, "keyboard") == 0) {
                ki = KdNewKeyboard();
                if (!ki) {
                    input_option_free_list(&optionsdup);
                    return BadAlloc;
                }
            }
            else {
                ErrorF("unrecognised device type!\n");
                return BadValue;
            }
        }
version (CONFIG_HAL) {
        if (strcmp(key, "_source") == 0 &&
                 strcmp(value, "server/hal") == 0) {
            if (dixSettingSeatId) {
                /* Input hot-plugging is enabled */
                if (attrs.flags & ATTR_POINTER) {
                    pi = KdNewPointer();
                    if (!pi) {
                        input_option_free_list(&optionsdup);
                        return BadAlloc;
                    }
                }
                else if (attrs.flags & ATTR_KEYBOARD) {
                    ki = KdNewKeyboard();
                    if (!ki) {
                        input_option_free_list(&optionsdup);
                        return BadAlloc;
                    }
                }
            }
            else {
                ErrorF("Ignoring device from HAL.n");
                input_option_free_list(&optionsdup);
                return BadValue;
            }
        }
}
version(CONFIG_UDEV) {
        if (strcmp(key, "_source") == 0 &&
                 strcmp(value, "server/udev") == 0) {
            if (dixSettingSeatId) {
                /* Input hot-plugging is enabled */
                if (attrs.flags & ATTR_POINTER) {
                    pi = KdNewPointer();
                    if (!pi) {
                        input_option_free_list(&optionsdup);
                        return BadAlloc;
                    }
                }
                else if (attrs.flags & ATTR_KEYBOARD) {
                    ki = KdNewKeyboard();
                    if (!ki) {
                        input_option_free_list(&optionsdup);
                        return BadAlloc;
                    }
                }
            }
            else {
                ErrorF("Ignoring device from udev.n");
                input_option_free_list(&optionsdup);
                return BadValue;
            }
        }
}
    }

    if (pi) {
        pi.options = optionsdup;
        KdParsePointerOptions(pi);

        if (!pi . driver) {
            ErrorF("couldn't find driver for pointer device \"%s\" (%s)\n",
                   pi.name ? pi.name : "(unnamed)", pi.path);
            KdFreePointer(pi);
            return BadValue;
        }

        if (KdAddPointer(pi) != Success ||
            ActivateDevice(pi.dixdev, True) != Success ||
            EnableDevice(pi.dixdev, True) != True) {
            ErrorF("couldn't add or enable pointer \"%s\" (%s)\n",
                   pi.name ? pi.name : "(unnamed)", pi.path);
            KdFreePointer(pi);
            return BadImplementation;
        }

        *pdev = pi.dixdev;
    }
    else if(ki) {
        ki.options = optionsdup;
        KdParseKbdOptions(ki);

        if (!ki.driver) {
            ErrorF("couldn't find driver for keyboard device \"%s\" (%s)\n",
                   ki.name ? ki.name : "(unnamed)", ki.path);
            KdFreeKeyboard(ki);
            return BadValue;
        }

        if (KdAddKeyboard(ki) != Success ||
            ActivateDevice(ki.dixdev, True) != Success ||
            EnableDevice(ki.dixdev, True) != True) {
            ErrorF("couldn't add or enable keyboard \"%s\" (%s)\n",
                   ki.name ? ki.name : "(unnamed)", ki.path);
            KdFreeKeyboard(ki);
            return BadImplementation;
        }

        *pdev = ki.dixdev;
    }
    else {
        ErrorF("unrecognised device identifier: %s\n",
               input_option_get_value(input_option_find(optionsdup,
                                                        "device")));
        input_option_free_list(&optionsdup);
        return BadValue;
    }

    return Success;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void DeleteInputDeviceRequest(DeviceIntPtr pDev)
{
    RemoveDevice(pDev, True);
}

// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void RemoveInputDeviceTraces(const(char)* config_info_){
}

