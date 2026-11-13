module evdev;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2004 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import config.kdrive_config;
import core.stdc.errno;
import externs.linux.input;
//import x11.X;
//import x11.Xproto;
import dix.inputstr;
import dix.scrnintstr;
import hw.kdrive.src.kdrive;
import evdev;

enum NUM_EVENTS =  128;
enum ABS_UNSET =   -65535;

enum BITS_PER_LONG = long.sizeof * 8;
enum string NBITS(string x) = `((((` ~ x ~ `)-1)/BITS_PER_LONG)+1)`;
enum string ISBITSET(string x,string y) = `((` ~ x ~ `)[LONG(` ~ y ~ `)] & BIT(` ~ y ~ `))`;
enum string OFF(string x) = `((` ~ x ~ `)%BITS_PER_LONG)`;
enum string LONG(string x) = `((` ~ x ~ `)/BITS_PER_LONG)`;
enum string BIT(string x) = `(1 << ` ~ OFF!(x) ~ `)`;

struct Kevdev {
    /* current device state */
    int[REL_MAX + 1] rel;
    int[ABS_MAX + 1] abs;
    int[ABS_MAX + 1] prevabs;
    c_long[mixin(NBITS!(`KEY_MAX + 1`))] key;

    /* supported device info */
    c_long[mixin(NBITS!(`REL_MAX + 1`))] relbits;
    c_long[mixin(NBITS!(`ABS_MAX + 1`))] absbits;
    c_long[mixin(NBITS!(`KEY_MAX + 1`))] keybits;
    input_absinfo[ABS_MAX + 1] absinfo;
    int max_rel;
    int max_abs;

    int fd;
}

private void EvdevPtrBtn(KdPointerInfo* pi, input_event* ev)
{
    int flags = KD_MOUSE_DELTA | pi.buttonState;

    if (ev.code >= BTN_MOUSE && ev.code < BTN_JOYSTICK) {
        switch (ev.code) {
        case BTN_LEFT:
            if (ev.value == 1)
                flags |= KD_BUTTON_1;
            else
                flags &= ~KD_BUTTON_1;
            break;
        case BTN_MIDDLE:
            if (ev.value == 1)
                flags |= KD_BUTTON_2;
            else
                flags &= ~KD_BUTTON_2;
            break;
        case BTN_RIGHT:
            if (ev.value == 1)
                flags |= KD_BUTTON_3;
            else
                flags &= ~KD_BUTTON_3;
            break;
        default:
            /* Unknow button */
            break;
        }

        KdEnqueuePointerEvent(pi, flags, 0, 0, 0);
    }
}

private void EvdevPtrMotion(KdPointerInfo* pi, input_event* ev)
{
    Kevdev* ke = pi.driverPrivate;
    int i = void;
    int flags = KD_MOUSE_DELTA | pi.buttonState;

    for (i = 0; i <= ke.max_rel; i++)
        if (ke.rel[i]) {
            int a = void;

            for (a = 0; a <= ke.max_rel; a++) {
                if (mixin(ISBITSET!(`ke.relbits`, `a`))) {
                    if (a == 0)
                        KdEnqueuePointerEvent(pi, flags, ke.rel[a], 0, 0);
                    else if (a == 1)
                        KdEnqueuePointerEvent(pi, flags, 0, ke.rel[a], 0);
                }
                ke.rel[a] = 0;
            }
            break;
        }
    for (i = 0; i < ke.max_abs; i++)
        if (ke.abs[i] != ke.prevabs[i]) {
            int a = void;

            ErrorF("abs");
            for (a = 0; a <= ke.max_abs; a++) {
                if (mixin(ISBITSET!(`ke.absbits`, `a`)))
                    ErrorF(" %d=%d", a, ke.abs[a]);
                ke.prevabs[a] = ke.abs[a];
            }
            ErrorF("\n");
            break;
        }

    if (ev.code == REL_WHEEL) {
        for (i = 0; i < abs(ev.value); i++) {
            if (ev.value > 0)
                flags |= KD_BUTTON_4;
            else
                flags |= KD_BUTTON_5;

            KdEnqueuePointerEvent(pi, flags, 0, 0, 0);

            if (ev.value > 0)
                flags &= ~KD_BUTTON_4;
            else
                flags &= ~KD_BUTTON_5;

            KdEnqueuePointerEvent(pi, flags, 0, 0, 0);
        }
    }

}

private void EvdevPtrRead(int evdevPort, void* closure)
{
    KdPointerInfo* pi = closure;
    Kevdev* ke = pi.driverPrivate;
    int i = void;
    input_event[NUM_EVENTS] events = void;
    int n = void;

    n = read(evdevPort, &events, NUM_EVENTS * input_event.sizeof);
    if (n <= 0) {
        if (errno == ENODEV)
            DeleteInputDeviceRequest(pi.dixdev);
        return;
    }

    n /= input_event.sizeof;
    for (i = 0; i < n; i++) {
        switch (events[i].type) {
        case EV_SYN:
            break;
        case EV_KEY:
            EvdevPtrBtn(pi, &events[i]);
            break;
        case EV_REL:
            ke.rel[events[i].code] += events[i].value;
            EvdevPtrMotion(pi, &events[i]);
            break;
        case EV_ABS:
            ke.abs[events[i].code] = events[i].value;
            EvdevPtrMotion(pi, &events[i]);
            break;
        default: break;}
    }
}

private Status EvdevPtrInit(KdPointerInfo* pi)
{
    if (!pi.path) {
        pi.path = EvdevDefaultPtr(&pi.name);
    }
    else {
        int fd = open(pi.path, O_RDWR);
        if (fd < 0) {
            ErrorF("Failed to open evdev device %s\n", pi.path);
            return BadMatch;
        }
        close(fd);
    }

    if (!pi.name)
        pi.name = strdup("Evdev mouse");

    return Success;
}

private Status EvdevPtrEnable(KdPointerInfo* pi)
{
    int fd = void;
    c_ulong[mixin(NBITS!(`EV_MAX`))] ev = void;
    Kevdev* ke = void;

    if (!pi || !pi.path)
        return BadImplementation;

    fd = open(pi.path, 2);
    if (fd < 0)
        return BadMatch;

    if (ioctl(fd, EVIOCGRAB, 1) < 0)
        perror("Grabbing evdev mouse device failed");

    if (ioctl(fd, EVIOCGBIT(0 /*EV*/, ev.sizeof), ev.ptr) < 0) {
        perror("EVIOCGBIT 0");
        close(fd);
        return BadMatch;
    }
    ke = cast(Kevdev*) cast(Kevdev*) calloc(1, Kevdev.sizeof);
    if (!ke) {
        close(fd);
        return BadAlloc;
    }
    if (mixin(ISBITSET!(`ev`, `EV_KEY`))) {
        if (ioctl(fd, EVIOCGBIT(EV_KEY, typeof(ke.keybits).sizeof), ke.keybits) < 0) {
            perror("EVIOCGBIT EV_KEY");
            free(ke);
            close(fd);
            return BadMatch;
        }
    }
    if (mixin(ISBITSET!(`ev`, `EV_REL`))) {
        if (ioctl(fd, EVIOCGBIT(EV_REL, typeof(ke.relbits).sizeof), ke.relbits) < 0) {
            perror("EVIOCGBIT EV_REL");
            free(ke);
            close(fd);
            return BadMatch;
        }
        for (ke.max_rel = REL_MAX; ke.max_rel >= 0; ke.max_rel--)
            if (mixin(ISBITSET!(`ke.relbits`, `ke.max_rel`)))
                break;
    }
    if (mixin(ISBITSET!(`ev`, `EV_ABS`))) {
        int i = void;

        if (ioctl(fd, EVIOCGBIT(EV_ABS, typeof(ke.absbits).sizeof), ke.absbits) < 0) {
            perror("EVIOCGBIT EV_ABS");
            free(ke);
            close(fd);
            return BadMatch;
        }
        for (ke.max_abs = ABS_MAX; ke.max_abs >= 0; ke.max_abs--)
            if (mixin(ISBITSET!(`ke.absbits`, `ke.max_abs`)))
                break;
        for (i = 0; i <= ke.max_abs; i++) {
            if (mixin(ISBITSET!(`ke.absbits`, `i`)))
                if (ioctl(fd, EVIOCGABS(i), &ke.absinfo[i]) < 0) {
                    perror("EVIOCGABS");
                    break;
                }
            ke.prevabs[i] = ABS_UNSET;
        }
        if (i <= ke.max_abs) {
            free(ke);
            close(fd);
            return BadValue;
        }
    }
    if (!KdRegisterFd(fd, &EvdevPtrRead, pi)) {
        free(ke);
        close(fd);
        return BadAlloc;
    }
    pi.driverPrivate = ke;
    ke.fd = fd;

    return Success;
}

private void EvdevPtrDisable(KdPointerInfo* pi)
{
    Kevdev* ke = void;

    ke = pi.driverPrivate;

    if (!pi || !pi.driverPrivate)
        return;

    KdUnregisterFd(pi, ke.fd, True);

    if (ioctl(ke.fd, EVIOCGRAB, 0) < 0)
        perror("Ungrabbing evdev mouse device failed");

    free(ke);
    pi.driverPrivate = 0;
}

private void EvdevPtrFini(KdPointerInfo* pi)
{
}

/*
 * Evdev keyboard functions
 */

private void readMapping(KdKeyboardInfo* ki)
{
    if (!ki)
        return;

    ki.minScanCode = 0;
    ki.maxScanCode = 247;
}

private void EvdevKbdRead(int evdevPort, void* closure)
{
    KdKeyboardInfo* ki = closure;
    input_event[NUM_EVENTS] events = void;
    int i = void, n = void;

    n = read(evdevPort, &events, NUM_EVENTS * input_event.sizeof);
    if (n <= 0) {
        if (errno == ENODEV)
            DeleteInputDeviceRequest(ki.dixdev);
        return;
    }

    n /= input_event.sizeof;
    for (i = 0; i < n; i++) {
        if (events[i].type == EV_KEY)
            KdEnqueueKeyboardEvent(ki, events[i].code, !events[i].value);
/* FIXME: must implement other types of events
        else
            ErrorF("Event type (%d) not delivered\n", events[i].type);
*/
    }
}

private Status EvdevKbdInit(KdKeyboardInfo* ki)
{
    if (!ki.path) {
        ki.path = EvdevDefaultKbd(&ki.name);
    }
    else {
        int fd = open(ki.path, O_RDWR);
        if (fd < 0) {
            ErrorF("Failed to open evdev device %s\n", ki.path);
            return BadMatch;
        }
        close(fd);
    }

    if (!ki.name)
        ki.name = strdup("Evdev keyboard");

    readMapping(ki);

    return Success;
}

private Status EvdevKbdEnable(KdKeyboardInfo* ki)
{
    c_ulong[mixin(NBITS!(`EV_MAX`))] ev = void;
    Kevdev* ke = void;
    int fd = void;

    if (!ki || !ki.path)
        return BadImplementation;

    fd = open(ki.path, O_RDWR);
    if (fd < 0)
        return BadMatch;

    if (ioctl(fd, EVIOCGRAB, 1) < 0)
        perror("Grabbing evdev keyboard device failed");

    if (ioctl(fd, EVIOCGBIT(0 /*EV*/, ev.sizeof), ev.ptr) < 0) {
        perror("EVIOCGBIT 0");
        close(fd);
        return BadMatch;
    }

    ke = cast(Kevdev*) cast(Kevdev*) calloc(1, Kevdev.sizeof);
    if (!ke) {
        close(fd);
        return BadAlloc;
    }

    if (!KdRegisterFd(fd, &EvdevKbdRead, ki)) {
        free(ke);
        close(fd);
        return BadAlloc;
    }
    ki.driverPrivate = ke;
    ke.fd = fd;

    return Success;
}

private void EvdevKbdLeds(KdKeyboardInfo* ki, int leds)
{
    input_event event = void;
    Kevdev* ke = void;
    int i = void;

    if (!ki)
        return;

    ke = ki.driverPrivate;

    if (!ke)
        return;

    memset(&event, 0, event.sizeof);

    event.type = EV_LED;
    event.code = LED_CAPSL;
    event.value = leds & (1 << 0) ? 1 : 0;
    i = write(ke.fd, cast(char*) &event, event.sizeof);
    cast(void) i;

    event.type = EV_LED;
    event.code = LED_NUML;
    event.value = leds & (1 << 1) ? 1 : 0;
    i = write(ke.fd, cast(char*) &event, event.sizeof);
    cast(void) i;

    event.type = EV_LED;
    event.code = LED_SCROLLL;
    event.value = leds & (1 << 2) ? 1 : 0;
    i = write(ke.fd, cast(char*) &event, event.sizeof);
    cast(void) i;

    event.type = EV_LED;
    event.code = LED_COMPOSE;
    event.value = leds & (1 << 3) ? 1 : 0;
    i = write(ke.fd, cast(char*) &event, event.sizeof);
    cast(void) i;
}

private void EvdevKbdBell(KdKeyboardInfo* ki, int volume, int frequency, int duration)
{
}

private void EvdevKbdDisable(KdKeyboardInfo* ki)
{
    Kevdev* ke = void;

    ke = ki.driverPrivate;

    if (!ki || !ki.driverPrivate)
        return;

    KdUnregisterFd(ki, ke.fd, True);

    if (ioctl(ke.fd, EVIOCGRAB, 0) < 0)
        perror("Ungrabbing evdev keyboard device failed");

    free(ke);
    ki.driverPrivate = 0;
}

private void EvdevKbdFini(KdKeyboardInfo* ki)
{
}

KdPointerDriver LinuxEvdevMouseDriver = {
    name: "evdev",
    Init: &EvdevPtrInit,
    Enable: &EvdevPtrEnable,
    Disable: &EvdevPtrDisable,
    Fini: &EvdevPtrFini,
};

KdKeyboardDriver LinuxEvdevKeyboardDriver = {
    name: "evdev",
    Init: &EvdevKbdInit,
    Enable: &EvdevKbdEnable,
    Leds: &EvdevKbdLeds,
    Bell: &EvdevKbdBell,
    Disable: &EvdevKbdDisable,
    Fini: &EvdevKbdFini,
};
