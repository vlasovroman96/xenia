module ps2;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 1999 Keith Packard
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
//import x11.X;
//import x11.Xproto;
import os.xserver_poll;
import dix.inputstr;import dix.scrnintstr;
import hw.kdrive.src.kdrive;

private int Ps2ReadBytes(int fd, char* buf, int len, int min)
{
    int n = void, tot = void;
    pollfd poll_fd = void;

    tot = 0;
    poll_fd.fd = fd;
    poll_fd.events = POLLIN;
    while (len) {
        n = read(fd, buf, len);
        if (n > 0) {
            tot += n;
            buf += n;
            len -= n;
        }
        if (tot % min == 0)
            break;
        n = xserver_poll(&poll_fd, 1, 100);
        if (n <= 0)
            break;
    }
    return tot;
}

const(char)*[3] Ps2Names = [
    "/dev/psaux",
/*    "/dev/mouse", */
    "/dev/input/mice",
];

enum NUM_PS2_NAMES =	Ps2Names.sizeof / Ps2Names[0].sizeof;

private void Ps2Read(int ps2Port, void* closure)
{
    ubyte[3 * 200] buf = void;
    ubyte* b = void;
    int n = void;
    int dx = void, dy = void;
    c_ulong flags = void;
    c_ulong left_button = KD_BUTTON_1;
    c_ulong right_button = KD_BUTTON_3;

version (SWAP_USB) {
    if (id == 2) {
        left_button = KD_BUTTON_3;
        right_button = KD_BUTTON_1;
    }
}
    while ((n = Ps2ReadBytes(ps2Port, cast(char*) buf, buf.sizeof, 3)) > 0) {
        b = buf;
        while (n >= 3) {
            flags = KD_MOUSE_DELTA;
            if (b[0] & 4)
                flags |= KD_BUTTON_2;
            if (b[0] & 2)
                flags |= right_button;
            if (b[0] & 1)
                flags |= left_button;

            dx = b[1];
            if (b[0] & 0x10)
                dx -= 256;
            dy = b[2];
            if (b[0] & 0x20)
                dy -= 256;
            dy = -dy;
            n -= 3;
            b += 3;
            KdEnqueuePointerEvent(closure, flags, dx, dy, 0);
        }
    }
}

private Status Ps2Init(KdPointerInfo* pi)
{
    int ps2Port = void, i = void;

    if (!pi.path) {
        for (i = 0; i < NUM_PS2_NAMES; i++) {
            ps2Port = open(Ps2Names[i], 0);
            if (ps2Port >= 0) {
                pi.path = strdup(Ps2Names[i]);
                break;
            }
        }
    }
    else {
        ps2Port = open(pi.path, 0);
    }

    if (ps2Port < 0)
        return BadMatch;

    close(ps2Port);
    if (!pi.name)
        pi.name = strdup("PS/2 Mouse");

    return Success;
}

private Status Ps2Enable(KdPointerInfo* pi)
{
    int fd = void;

    if (!pi)
        return BadImplementation;

    fd = open(pi.path, 0);
    if (fd < 0)
        return BadMatch;

    if (!KdRegisterFd(fd, &Ps2Read, pi)) {
        close(fd);
        return BadAlloc;
    }

    pi.driverPrivate = cast(void*) cast(intptr_t) fd;

    return Success;
}

private void Ps2Disable(KdPointerInfo* pi)
{
    KdUnregisterFd(pi, cast(int) cast(intptr_t) pi.driverPrivate, TRUE);
}

private void Ps2Fini(KdPointerInfo* pi)
{
}

KdPointerDriver Ps2MouseDriver = {
    name: "ps2",
    Init: &Ps2Init,
    Enable: &Ps2Enable,
    Disable: &Ps2Disable,
    Fini: &Ps2Fini,
};
