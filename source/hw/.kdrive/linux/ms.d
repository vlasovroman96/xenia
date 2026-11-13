module ms;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
Copyright (c) 2001 by Juliusz Chroboczek
Copyright (c) 1999 by Keith Packard

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
*/

import config.kdrive_config;
import core.stdc.errno;
import core.sys.posix.termios;
import os.xserver_poll;
//import x11.X;
//import x11.Xproto;
import dix.inputstr;
import dix.scrnintstr;
import hw.kdrive.src.kdrive;

private int MsReadBytes(int fd, char* buf, int len, int min)
{
    int n = void, tot = void;
    pollfd poll_fd = void;

    poll_fd.fd = fd;
    poll_fd.events = POLLIN;
    tot = 0;
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

private void MsRead(int port, void* closure)
{
    ubyte[3 * 200] buf = void;
    ubyte* b = void;
    int n = void;
    int dx = void, dy = void;
    c_ulong flags = void;

    while ((n = MsReadBytes(port, cast(char*) buf, buf.sizeof, 3)) > 0) {
        b = buf;
        while (n >= 3) {
            flags = KD_MOUSE_DELTA;

            if (b[0] & 0x20)
                flags |= KD_BUTTON_1;
            if (b[0] & 0x10)
                flags |= KD_BUTTON_3;

            dx = cast(char) (((b[0] & 0x03) << 6) | (b[1] & 0x3F));
            dy = cast(char) (((b[0] & 0x0C) << 4) | (b[2] & 0x3F));
            n -= 3;
            b += 3;
            KdEnqueuePointerEvent(closure, flags, dx, dy, 0);
        }
    }
}

private Status MsInit(KdPointerInfo* pi)
{
    if (!pi)
        return BadImplementation;

    if (!pi.path || strcmp(pi.path, "auto"))
        pi.path = strdup("/dev/mouse");
    if (!pi.name)
        pi.name = strdup("Microsoft protocol mouse");

    return Success;
}

private Status MsEnable(KdPointerInfo* pi)
{
    int port = void;
    termios t = void;
    int ret = void;

    port = open(pi.path, O_RDWR | O_NONBLOCK);
    if (port < 0) {
        ErrorF("Couldn't open %s (%d)\n", pi.path, cast(int) errno);
        return 0;
    }
    else if (port == 0) {
        ErrorF("Opening %s returned 0!  Please complain to Keith.\n", pi.path);
        goto bail;
    }

    if (!isatty(port)) {
        ErrorF("%s is not a tty\n", pi.path);
        goto bail;
    }

    ret = tcgetattr(port, &t);
    if (ret < 0) {
        ErrorF("Couldn't tcgetattr(%s): %d\n", pi.path, errno);
        goto bail;
    }
    t.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR |
                   IGNCR | ICRNL | IXON | IXOFF);
    t.c_oflag &= ~OPOST;
    t.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    t.c_cflag &= ~(CSIZE | PARENB);
    t.c_cflag |= CS8 | CLOCAL | CSTOPB;

    cfsetispeed(&t, B1200);
    cfsetospeed(&t, B1200);
    t.c_cc[VMIN] = 1;
    t.c_cc[VTIME] = 0;
    ret = tcsetattr(port, TCSANOW, &t);
    if (ret < 0) {
        ErrorF("Couldn't tcsetattr(%s): %d\n", pi.path, errno);
        goto bail;
    }
    if (KdRegisterFd(port, &MsRead, pi))
        return True;
    pi.driverPrivate = cast(void*) cast(intptr_t) port;

    return Success;

 bail:
    close(port);
    return BadMatch;
}

private void MsDisable(KdPointerInfo* pi)
{
    KdUnregisterFd(pi, cast(int) cast(intptr_t) pi.driverPrivate, True);
}

private void MsFini(KdPointerInfo* pi)
{
}

KdPointerDriver MsMouseDriver = {
    name: "ms",
    Init: &MsInit,
    Enable: &MsEnable,
    Disable: &MsDisable,
    Fini: &MsFini,
};
