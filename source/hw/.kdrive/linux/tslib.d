module hw.kdrive.linux.tslib_;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * TSLIB based touchscreen driver for KDrive
 * Porting to new input API and event queueing by Daniel Stone.
 * Derived from ts.c by Keith Packard
 * Derived from ps2.c by Jim Gettys
 *
 * Copyright © 1999 Keith Packard
 * Copyright © 2000 Compaq Computer Corporation
 * Copyright © 2002 MontaVista Software Inc.
 * Copyright © 2005 OpenedHand Ltd.
 * Copyright © 2006 Nokia Corporation
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of the authors and/or copyright holders
 * not be used in advertising or publicity pertaining to distribution of the
 * software without specific, written prior permission.  The authors and/or
 * copyright holders make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *
 * THE AUTHORS AND/OR COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD
 * TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
 * AND FITNESS, IN NO EVENT SHALL THE AUTHORS AND/OR COPYRIGHT HOLDERS BE
 * LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 */

import config.kdrive_config;

//import x11.X;
//import x11.Xproto;
import dix.inputstr;
import dix.scrnintstr;
import hw.kdrive.src.kdrive;
import core.sys.posix.sys.ioctl;
import externs.tslib;
import core.sys.posix.dirent;
import externs.linux.input;

struct TslibPrivate {
    int fd;
    int lastx, lasty;
    tsdev* tsDev;
    void function(int x, int y, int pressure, void* closure) raw_event_hook;
    void* raw_event_closure;
    int phys_screen;
}

private void TsRead(int fd, void* closure)
{
    KdPointerInfo* pi = closure;
    TslibPrivate* private_ = pi.driverPrivate;
    ts_sample event = void;
    c_long x = 0, y = 0;
    c_ulong flags = void;

    if (private_.raw_event_hook) {
        while (ts_read_raw(private_.tsDev, &event, 1) == 1)
            private_.raw_event_hook(event.x, event.y, event.pressure,
                                    private_.raw_event_closure);
        return;
    }

    while (ts_read(private_.tsDev, &event, 1) == 1) {
        if (event.pressure) {
            flags = KD_BUTTON_1;

            /*
             * Here we test for the touch screen driver actually being on the
             * touch screen, if it is we send absolute coordinates. If not,
             * then we send delta's so that we can track the entire vga screen.
             */
            if (KdCurScreen == private_.phys_screen) {
                x = event.x;
                y = event.y;
            }
            else {
                flags |= KD_MOUSE_DELTA;
                if ((private_.lastx == 0) || (private_.lasty == 0)) {
                    x = event.x;
                    y = event.y;
                }
                else {
                    x = event.x - private_.lastx;
                    y = event.y - private_.lasty;
                }
            }
            private_.lastx = event.x;
            private_.lasty = event.y;
        }
        else {
            flags = 0;
            x = private_.lastx;
            y = private_.lasty;
        }

        KdEnqueuePointerEvent(pi, flags, x, y, event.pressure);
    }
}

private Status TslibEnable(KdPointerInfo* pi)
{
    TslibPrivate* private_ = pi.driverPrivate;

    private_.raw_event_hook = null;
    private_.raw_event_closure = null;
    if (!pi.path) {
        pi.path = strdup("/dev/input/touchscreen0");
        ErrorF("[tslib/TslibEnable] no device path given, trying %s\n",
               pi.path);
    }

    private_.tsDev = ts_open(pi.path, 0);
    if (!private_.tsDev) {
        ErrorF("[tslib/TslibEnable] failed to open %s\n", pi.path);
        return BadAlloc;
    }

    if (ts_config(private_.tsDev)) {
        ErrorF("[tslib/TslibEnable] failed to load configuration\n");
        ts_close(private_.tsDev);
        private_.tsDev = null;
        return BadValue;
    }

    private_.fd = ts_fd(private_.tsDev);

    KdRegisterFd(private_.fd, &TsRead, pi);

    return Success;
}

private void TslibDisable(KdPointerInfo* pi)
{
    TslibPrivate* private_ = pi.driverPrivate;

    if (private_.fd)
        KdUnregisterFd(pi, private_.fd, True);

    if (private_.tsDev)
        ts_close(private_.tsDev);

    private_.fd = 0;
    private_.tsDev = null;
}

private Status TslibInit(KdPointerInfo* pi)
{
    TslibPrivate* private_ = null;

    if (!pi || !pi.dixdev)
        return !Success;

    pi.driverPrivate = cast(TslibPrivate*)
        calloc(TslibPrivate.sizeof, 1);
    if (!pi.driverPrivate)
        return !Success;

    private_ = pi.driverPrivate;
    /* hacktastic */
    private_.phys_screen = 0;
    pi.nAxes = 3;
    pi.name = strdup("Touchscreen");
    pi.inputClass = KD_TOUCHSCREEN;

    return Success;
}

private void TslibFini(KdPointerInfo* pi)
{
    free(pi.driverPrivate);
    pi.driverPrivate = null;
}

KdPointerDriver TsDriver = {
    name: "tslib",
    Init: &TslibInit,
    Enable: &TslibEnable,
    Disable: &TslibDisable,
    Fini: &TslibFini,
};
