module posix_tty;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 1993-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE XFREE86 PROJECT BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the XFree86 Project shall
 * not be used in advertising or otherwise to promote the sale, use or other
 * dealings in this Software without prior written authorization from the
 * XFree86 Project.
 */
/*
 *
 * Copyright (c) 1997  Metro Link Incorporated
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Metro Link shall not be
 * used in advertising or otherwise to promote the sale, use or other dealings
 * in this Software without prior written authorization from Metro Link.
 *
 */
import build.xorg_config;

import core.stdc.errno;
//import x11.X;

import os.log_priv;
import os.xserver_poll;

import core.sys.posix.unistd;
// import core.sys.posix.
import hw.xfree86.common.xf86Helper;
import xf86Opt_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_OSlib;
// import xf86Options;
import config.dbus_core;
import config.hotplug_priv;
import dix.input_priv;
import dix.screenint_priv;
import include.xf86DDC;
import include.xorgVersion;
import mi.mi_priv;
import os.cmdline;
import os.ddx_priv;
import os.log_priv;
import os.osdep;
import randr.randrstr_priv;

import common.servermd;
import dix.window;
import dix.scrnintstr;
import hw.xfree86.os_support.linux.systemd_logind;
import seatd_libseat;

// import xf86VGAarbiter_priv;
import hw.xfree86.loader.loaderProcs;

import xf86Module_priv;
import xf86_priv;
import include.xf86Priv;
import xf86Config;
import hw.xfree86.os_support.xf86_os_support;
import xf86cmap;
import mi.mipointer;
import xf86Extensions;
import hw.xfree86.common.xf86Xinput;
// import xf86InPriv;
import hw.xfree86.common.xf86Crtc;
import dix.picturestr;
import xf86Bus;
import include.xserver_properties;
import os.log;
import externs.attrs;
import xf86Globals;
import dix.property;
import xf86AutoConfig_;
import externs.X11.Xatom;
import xf86VGAarbiter;
import hw.xfree86.common.xf86Option;
import core.sys.posix.unistd;
import xf86Events;
import core.stdc.stdlib;
import core.stdc.errno;
import core.sys.posix.sys.stat;
import core.sys.linux.fcntl;
import hw.xfree86.parser.Flags;
import os.xserver_poll;
import core.sys.posix.poll;

private int GetBaud(int baudrate)
{
version (B300) {
    if (baudrate == 300)
        return B300;
}
version (B1200) {
    if (baudrate == 1200)
        return B1200;
}
version (B2400) {
    if (baudrate == 2400)
        return B2400;
}
version (B4800) {
    if (baudrate == 4800)
        return B4800;
}
version (B9600) {
    if (baudrate == 9600)
        return B9600;
}
version (B19200) {
    if (baudrate == 19200)
        return B19200;
}
version (B38400) {
    if (baudrate == 38400)
        return B38400;
}
version (B57600) {
    if (baudrate == 57600)
        return B57600;
}
version (B115200) {
    if (baudrate == 115200)
        return B115200;
}
version (B230400) {
    if (baudrate == 230400)
        return B230400;
}
version (B460800) {
    if (baudrate == 460800)
        return B460800;
}
    return 0;
}

int xf86OpenSerial(XF86OptionPtr options)
{
    termios t = void;
    int fd = void, i = void;
    char* dev = void;

    dev = xf86SetStrOption(options, "Device", null);
    if (!dev) {
        LogMessageVerb(X_ERROR, 1, "xf86OpenSerial: No Device specified.\n");
        return -1;
    }

    fd = xf86CheckIntOption(options, "fd", -1);

    if (fd == -1)
        mixin(SYSCALL!("fd = open(dev, O_RDWR | O_NONBLOCK)"));

    if (fd == -1) {
        LogMessageVerb(X_ERROR, 1,
                       "xf86OpenSerial: Cannot open device %s\n\t%s.\n",
                       dev, strerror(errno));
        free(dev);
        return -1;
    }

    if (!isatty(fd)) {
        /* Allow non-tty devices to be opened. */
        free(dev);
        return fd;
    }

    /* set up default port parameters */
    mixin(SYSCALL!("tcgetattr(fd, &t)"));
    t.c_iflag &= ~(IGNBRK | BRKINT | PARMRK | ISTRIP | INLCR
                   | IGNCR | ICRNL | IXON);
    t.c_oflag &= ~OPOST;
    t.c_lflag &= ~(ECHO | ECHONL | ICANON | ISIG | IEXTEN);
    t.c_cflag &= ~(CSIZE | PARENB);
    t.c_cflag |= CS8 | CLOCAL;

    cfsetispeed(&t, B9600);
    cfsetospeed(&t, B9600);
    t.c_cc[VMIN] = 1;
    t.c_cc[VTIME] = 0;

    mixin(SYSCALL!("tcsetattr(fd, TCSANOW, &t)"));

    if (xf86SetSerial(fd, options) == -1) {
        mixin(SYSCALL!("close(fd)"));
        free(dev);
        return -1;
    }

    mixin(SYSCALL!("i = fcntl(fd, F_GETFL, 0)"));
    if (i == -1) {
        mixin(SYSCALL!("close(fd)"));
        free(dev);
        return -1;
    }
    i &= ~O_NONBLOCK;
    mixin(SYSCALL!("i = fcntl(fd, F_SETFL, i)"));
    if (i == -1) {
        mixin(SYSCALL!("close(fd)"));
        free(dev);
        return -1;
    }
    free(dev);
    return fd;
}

int xf86SetSerial(int fd, XF86OptionPtr options)
{
    termios t = void;
    int val = void;
    char* s = void;
    int baud = void, r = void;

    if (fd < 0)
        return -1;

    /* Don't try to set parameters for non-tty devices. */
    if (!isatty(fd))
        return 0;

    mixin(SYSCALL!("tcgetattr(fd, &t)"));

    if ((val = xf86SetIntOption(cast(_InputOption*)options, "BaudRate", 0)) != 0) {
        if ((baud = GetBaud(val)) != 0) {
            cfsetispeed(&t, baud);
            cfsetospeed(&t, baud);
        }
        else {
            LogMessageVerb(X_ERROR, 1, "Invalid Option BaudRate value: %d\n", val);
            return -1;
        }
    }

    if ((val = xf86SetIntOption(cast(_InputOption*)options, "StopBits", 0)) != 0) {
        switch (val) {
        case 1:
            t.c_cflag &= ~(CSTOPB);
            break;
        case 2:
            t.c_cflag |= CSTOPB;
            break;
        default:
            LogMessageVerb(X_ERROR, 1, "Invalid Option StopBits value: %d\n", val);
            return -1;
            break;
        }
    }

    if ((val = xf86SetIntOption(cast(_InputOption*)options, "DataBits", 0)) != 0) {
        switch (val) {
        case 5:
            t.c_cflag &= ~(CSIZE);
            t.c_cflag |= CS5;
            break;
        case 6:
            t.c_cflag &= ~(CSIZE);
            t.c_cflag |= CS6;
            break;
        case 7:
            t.c_cflag &= ~(CSIZE);
            t.c_cflag |= CS7;
            break;
        case 8:
            t.c_cflag &= ~(CSIZE);
            t.c_cflag |= CS8;
            break;
        default:
            LogMessageVerb(X_ERROR, 1, "Invalid Option DataBits value: %d\n", val);
            return -1;
            break;
        }
    }

    if ((s = xf86SetStrOption(options, "Parity", null)) !is null) {
        if (xf86NameCmp(s, "Odd") == 0) {
            t.c_cflag |= PARENB | PARODD;
        }
        else if (xf86NameCmp(s, "Even") == 0) {
            t.c_cflag |= PARENB;
            t.c_cflag &= ~(PARODD);
        }
        else if (xf86NameCmp(s, "None") == 0) {
            t.c_cflag &= ~(PARENB);
        }
        else {
            LogMessageVerb(X_ERROR, 1, "Invalid Option Parity value: %s\n", s);
            free(s);
            return -1;
        }
        free(s);
    }

    if ((val = xf86SetIntOption(cast(_InputOption*)options, "Vmin", -1)) != -1) {
        t.c_cc[VMIN] = cast(ubyte)val;
    }
    if ((val = xf86SetIntOption(cast(_InputOption*)options, "Vtime", -1)) != -1) {
        t.c_cc[VTIME] = cast(ubyte)val;
    }

    if ((s = xf86SetStrOption(options, "FlowControl", null))!is null) {
        xf86MarkOptionUsedByName(options, "FlowControl");
        if (xf86NameCmp(s, "Xoff") == 0) {
            t.c_iflag |= IXOFF;
        }
        else if (xf86NameCmp(s, "Xon") == 0) {
            t.c_iflag |= IXON;
        }
        else if (xf86NameCmp(s, "XonXoff") == 0) {
            t.c_iflag |= IXON | IXOFF;
        }
        else if (xf86NameCmp(s, "None") == 0) {
            t.c_iflag &= ~(IXON | IXOFF);
        }
        else {
            LogMessageVerb(X_ERROR, 1, "Invalid Option FlowControl value: %s\n", s);
            free(s);
            return -1;
        }
        free(s);
    }

    if ((xf86SetBoolOption(options, "ClearDTR", FALSE)) != 0) {
version (CLEARDTR_SUPPORT) {
version (TIOCMBIC) {
        val = TIOCM_DTR;
        mixin(SYSCALL!("ioctl(fd, TIOCMBIC, &val)"));
} else {
        mixin(SYSCALL!("ioctl(fd, TIOCCDTR, null)"));
}
} else {
        LogMessageVerb(X_WARNING, 1, "Option ClearDTR not supported on this OS\n");
        return -1;
}
        xf86MarkOptionUsedByName(options, "ClearDTR");
    }

    if ((xf86SetBoolOption(options, "ClearRTS", FALSE)) != 0) {
        LogMessageVerb(X_WARNING, 1, "Option ClearRTS not supported on this OS\n");
        return -1;
        xf86MarkOptionUsedByName(options, "ClearRTS");
    }

    mixin(SYSCALL!("r = tcsetattr(fd, TCSANOW, &t)"));
    return r;
}

int xf86SetSerialSpeed(int fd, int speed)
{
    termios t = void;
    int baud = void, r = void;

    if (fd < 0)
        return -1;

    /* Don't try to set parameters for non-tty devices. */
    if (!isatty(fd))
        return 0;

    mixin(SYSCALL!("tcgetattr(fd, &t)"));

    if ((baud = GetBaud(speed))!= 0) {
        cfsetispeed(&t, baud);
        cfsetospeed(&t, baud);
    }
    else {
        LogMessageVerb(X_ERROR, 1, "Invalid Option BaudRate value: %d\n", speed);
        return -1;
    }

    mixin(SYSCALL!("r = tcsetattr(fd, TCSANOW, &t)"));
    return r;
}

int xf86ReadSerial(int fd, void* buf, int count)
{
    int r = void;
    int i = void;

    mixin(SYSCALL!("r = cast(int)read(fd, buf, count)"));
    DebugF("ReadingSerial: 0x%x", cast(ubyte) *((cast(ubyte*) buf)));
    for (i = 1; i < r; i++)
        DebugF(", 0x%x", cast(ubyte) *((cast(ubyte*) buf) + i));
    DebugF("\n");
    return r;
}

int xf86WriteSerial(int fd, const(void)* buf, int count)
{
    int r = void;
    int i = void;

    DebugF("WritingSerial: 0x%x", cast(ubyte) *((cast(ubyte*) buf)));
    for (i = 1; i < count; i++)
        DebugF(", 0x%x", cast(ubyte) *((cast(ubyte*) buf) + i));
    DebugF("\n");
    mixin(SYSCALL!("r = cast(int)write(fd, buf, count)"));
    return r;
}

int xf86CloseSerial(int fd)
{
    int r = void;

    mixin(SYSCALL!("r = close(fd)"));
    return r;
}

int xf86WaitForInput(int fd, int timeout)
{
    int r = void;
    pollfd poll_fd = void;

    poll_fd.fd = fd;
    poll_fd.events = POLLIN;

    /* convert microseconds to milliseconds */
    timeout = (timeout + 999) / 1000;

    if (fd >= 0) {
        mixin(SYSCALL!("r = xserver_poll(&poll_fd, 1, timeout)"));
    }
    else {
        mixin(SYSCALL!("r = xserver_poll(&poll_fd, 0, timeout)"));
    }
    // xf86ErrorFVerb(9, "poll returned %d\n", r);
    return r;
}

int xf86FlushInput(int fd)
{
    pollfd poll_fd = void;
    /* this needs to be big enough to flush an evdev event. */
    char[256] c = void;

    DebugF("FlushingSerial\n");
    if (tcflush(fd, TCIFLUSH) == 0)
        return 0;

    poll_fd.fd = fd;
    poll_fd.events = POLLIN;
    while (xserver_poll(&poll_fd, 1, 0) > 0) {
        if (read(fd, &c, c.sizeof) < 1)
            return 0;
    }
    return 0;
}

struct State {
    int xf;
    int os;
}

private immutable State[] modemStates = () {
    State[] states;
    
    static if (is(typeof(TIOCM_LE)))   states ~= State(XF86_M_LE, TIOCM_LE);
    static if (is(typeof(TIOCM_DTR)))  states ~= State(XF86_M_DTR, TIOCM_DTR);
    static if (is(typeof(TIOCM_RTS)))  states ~= State(XF86_M_RTS, TIOCM_RTS);
    static if (is(typeof(TIOCM_ST)))   states ~= State(XF86_M_ST, TIOCM_ST);
    static if (is(typeof(TIOCM_SR)))   states ~= State(XF86_M_SR, TIOCM_SR);
    static if (is(typeof(TIOCM_CTS)))  states ~= State(XF86_M_CTS, TIOCM_CTS);
    
    static if (is(typeof(TIOCM_CAR))) {
        states ~= State(XF86_M_CAR, TIOCM_CAR);
    } else static if (is(typeof(TIOCM_CD))) {
        states ~= State(XF86_M_CAR, TIOCM_CD);
    }
    
    static if (is(typeof(TIOCM_RNG))) {
        states ~= State(XF86_M_RNG, TIOCM_RNG);
    } else static if (is(typeof(TIOCM_RI))) {
        states ~= State(XF86_M_CAR, TIOCM_RI); // Сохранена ваша логика XF86_M_CAR
    }
    
    static if (is(typeof(TIOCM_DSR)))  states ~= State(XF86_M_DSR, TIOCM_DSR);
    
    return states;
}();

static this() {
    
}

private int numStates = modemStates.length;

private int xf2osState(int state)
{
    int i = void;
    int ret = 0;

    for (i = 0; i < numStates; i++)
        if (state & modemStates[i].xf)
            ret |= modemStates[i].os;
    return ret;
}

private int os2xfState(int state)
{
    int i = void;
    int ret = 0;

    for (i = 0; i < numStates; i++)
        if (state & modemStates[i].os)
            ret |= modemStates[i].xf;
    return ret;
}

private int getOsStateMask()
{
    int i = void;
    int ret = 0;

    for (i = 0; i < numStates; i++)
        ret |= modemStates[i].os;
    return ret;
}

private int osStateMask = 0;

int xf86SetSerialModemState(int fd, int state)
{
    int ret = void;
    int s = void;

    if (fd < 0)
        return -1;

    /* Don't try to set parameters for non-tty devices. */
    if (!isatty(fd))
        return 0;

version (TIOCMGET) {} else {
    return -1;
} version (TIOCMGET) {
    if (!osStateMask)
        osStateMask = getOsStateMask();

    state = xf2osState(state);
    mixin(SYSCALL!("(ret = ioctl(fd, TIOCMGET, &s))"));
    if (ret < 0)
        return -1;
    s &= ~osStateMask;
    s |= state;
    mixin(SYSCALL!("(ret = ioctl(fd, TIOCMSET, &s))"));
    if (ret < 0)
        return -1;
    else
        return 0;
}
}

int xf86GetSerialModemState(int fd)
{
    int ret = void;
    int s = void;

    if (fd < 0)
        return -1;

    /* Don't try to set parameters for non-tty devices. */
    if (!isatty(fd))
        return 0;

version (TIOCMGET) {} else {
    return -1;
} version (TIOCMGET) {
    mixin(SYSCALL!("(ret = ioctl(fd, TIOCMGET, &s))"));
    if (ret < 0)
        return -1;
    return os2xfState(s);
}
}

int xf86SerialModemSetBits(int fd, int bits)
{
    int ret = void;
    int s = void;

    if (fd < 0)
        return -1;

    /* Don't try to set parameters for non-tty devices. */
    if (!isatty(fd))
        return 0;

version (TIOCMGET) {} else {
    return -1;
} version (TIOCMGET) {
    s = xf2osState(bits);
    mixin(SYSCALL!("(ret = ioctl(fd, TIOCMBIS, &s))"));
    return ret;
}
}

int xf86SerialModemClearBits(int fd, int bits)
{
    int ret = void;
    int s = void;

    if (fd < 0)
        return -1;

    /* Don't try to set parameters for non-tty devices. */
    if (!isatty(fd))
        return 0;

version (TIOCMGET) {} else {
    return -1;
} version (TIOCMGET) {
    s = xf2osState(bits);
    mixin(SYSCALL!("(ret = ioctl(fd, TIOCMBIC, &s))"));
    return ret;
}
}
