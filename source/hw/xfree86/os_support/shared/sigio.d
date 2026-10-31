module sigio;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/* sigio.c -- Support for SIGIO handler installation and removal
 * Created: Thu Jun  3 15:39:18 1999 by faith@precisioninsight.com
 *
 * Copyright 1999 Precision Insight, Inc., Cedar Park, Texas.
 * All Rights Reserved.
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
 * PRECISION INSIGHT AND/OR ITS SUPPLIERS BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Authors: Rickard E. (Rik) Faith <faith@valinux.com>
 */
/*
 * Copyright (c) 2002 by The XFree86 Project, Inc.
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
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */
import build.xorg_config;

import core.stdc.errno;
import core.sys.posix.sys.stat;
import core.sys.posix.poll;
//import x11.X;

import os.osdep;
import os.xserver_poll;

import include.xf86;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;
import include.inputstr;
import os.ospoll;
import core.sys.posix.unistd;
// import core.sys.posix.
import include.xf86;
import xf86Opt_priv;
import include.xf86Priv;
import include.xf86_OSlib;
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

import include.servermd;
import include.windowstr;
import include.scrnintstr;
// import hw.xfree86.os_support.linux.systemd_logind;
// import seatd_libseat;

// import xf86VGAarbiter_priv;
import hw.xfree86.loader.loaderProcs;

import xf86Module_priv;
import xf86_priv;
import include.xf86Priv;
// import xf86Config;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;
// import xf86cmap;
import mi.mipointer;
// import xf86Extensions;
import include.xf86;

// import xf86InPriv;
// import include.xf86Crtc;
import include.picturestr;
// import xf86Bus;
import include.xserver_properties;
import os.log;
import externs.attrs;
import xf86Globals;
import dix.property;
// import xf86AutoConfig_;
import externs.X11.Xatom;
// import xf86VGAarbiter;
import core.sys.posix.unistd;
// import xf86Events;
import core.stdc.stdlib;
import core.stdc.errno;
import core.sys.posix.sys.stat;
import core.sys.linux.fcntl;
import os.xserver_poll;
import core.sys.posix.poll;
import os.connection;
import core.sys.posix.signal;
enum SIGIO = 29;

version (HAVE_STROPTS_H) {
import stropts;
}

version (MAXDEVICES) {
/* MAXDEVICES represents the maximum number of input devices usable
 * at the same time plus one entry for DRM support.
 */
enum MAX_FUNCS =   (MAXDEVICES + 1);
} else {
enum MAX_FUNCS = 16;
}

struct Xf86SigIOFunc {
    void function(int, void*) @nogc nothrow f;
    int fd;
    void* closure;
}

private Xf86SigIOFunc[MAX_FUNCS] xf86SigIOFuncs;
private int xf86SigIOMax;
private pollfd* xf86SigIOFds;
private int xf86SigIONum;

private Bool xf86SigIOAdd(int fd)
{
    pollfd* n = void;

    n = cast(pollfd*) realloc(xf86SigIOFds, (xf86SigIONum + 1) * pollfd.sizeof);
    if (!n)
        return FALSE;

    n[xf86SigIONum].fd = fd;
    n[xf86SigIONum].events = POLLIN;
    xf86SigIONum++;
    xf86SigIOFds = n;
    return TRUE;
}

private void xf86SigIORemove(int fd)
{
    int i = void;
    for (i = 0; i < xf86SigIONum; i++)
        if (xf86SigIOFds[i].fd == fd) {
            memmove(&xf86SigIOFds[i], &xf86SigIOFds[i+1], (xf86SigIONum - i - 1) * pollfd.sizeof);
            xf86SigIONum--;
            break;
        }
}

/*
 * SIGIO gives no way of discovering which fd signalled, select
 * to discover
 */
private void xf86SIGIO(int sig)
{
    int i = void, f = void;
    int save_errno = errno;     /* do not clobber the global errno */
    int r = void;

    inSignalContext = TRUE;

    mixin(SYSCALL!("r = xserver_poll(xf86SigIOFds, xf86SigIONum, 0)"));
    for (f = 0; r > 0 && f < xf86SigIONum; f++) {
        if (xf86SigIOFds[f].revents & POLLIN) {
            for (i = 0; i < xf86SigIOMax; i++)
                if (xf86SigIOFuncs[i].f && xf86SigIOFuncs[i].fd == xf86SigIOFds[f].fd)
                    (*xf86SigIOFuncs[i].f) (xf86SigIOFuncs[i].fd,
                                            xf86SigIOFuncs[i].closure);
            r--;
        }
    }
    if (r > 0) {
        LogMessageVerb(X_ERROR, 1, "SIGIO %d descriptors not handled\n", r);
    }
    /* restore global errno */
    errno = save_errno;

    inSignalContext = FALSE;
}

private int xf86IsPipe(int fd)
{
    stat_t buf = void;

    if (fstat(fd, &buf) < 0)
        return 0;
    return S_ISFIFO(buf.st_mode);
}

private void block_sigio()
{
    sigset_t set = void;

    sigemptyset(&set);
    sigaddset(&set, SIGIO);
    xthread_sigmask(SIG_BLOCK, &set, null);
}

private void release_sigio()
{
    sigset_t set = void;

    sigemptyset(&set);
    sigaddset(&set, SIGIO);
    xthread_sigmask(SIG_UNBLOCK, &set, null);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86InstallSIGIOHandler(int fd, void function(int, void*) @nogc nothrow f, void* closure)
{
    sigaction_t sa = void;
    sigaction_t osa = void;
    int i = void;
    int installed = FALSE;

    for (i = 0; i < MAX_FUNCS; i++) {
        if (!xf86SigIOFuncs[i].f) {
            if (xf86IsPipe(fd))
                return 0;
            block_sigio();
version (O_ASYNC) {
            if (fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) | O_ASYNC) == -1) {
                LogMessageVerb(X_WARNING, 1, "fcntl(%d, O_ASYNC): %s\n",
                               fd, strerror(errno));
            }
            else {
                if (fcntl(fd, F_SETOWN, getpid()) == -1) {
                    LogMessageVerb(X_WARNING, 1, "fcntl(%d, F_SETOWN): %s\n",
                                   fd, strerror(errno));
                }
                else {
                    installed = TRUE;
                }
            }
}
static if (HasVersion!"I_SETSIG" && HasVersion!"HAVE_ISASTREAM") {
            /* System V Streams - used on Solaris for input devices */
            if (!installed && isastream(fd)) {
                if (ioctl(fd, I_SETSIG, S_INPUT | S_ERROR | S_HANGUP) == -1) {
                    LogMessageVerb(X_WARNING, 1, "fcntl(%d, I_SETSIG): %s\n",
                                   fd, strerror(errno));
                }
                else {
                    installed = TRUE;
                }
            }
}
            if (!installed) {
                release_sigio();
                return 0;
            }
            sigemptyset(&sa.sa_mask);
            sigaddset(&sa.sa_mask, SIGIO);
            sa.sa_flags = SA_RESTART;
            sa.sa_handler = &xf86SIGIO;
            sigaction(SIGIO, &sa, &osa);
            xf86SigIOFuncs[i].fd = fd;
            xf86SigIOFuncs[i].closure = closure;
            xf86SigIOFuncs[i].f = f;
            if (i >= xf86SigIOMax)
                xf86SigIOMax = i + 1;
            xf86SigIOAdd(fd);
            release_sigio();
            return 1;
        }
        /* Allow overwriting of the closure and callback */
        else if (xf86SigIOFuncs[i].fd == fd) {
            xf86SigIOFuncs[i].closure = closure;
            xf86SigIOFuncs[i].f = f;
            return 1;
        }
    }
    return 0;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86RemoveSIGIOHandler(int fd)
{
    sigaction_t sa = void;
    sigaction_t osa = void;
    int i = void;
    int max = void;
    int ret = void;

    max = 0;
    ret = 0;
    for (i = 0; i < MAX_FUNCS; i++) {
        if (xf86SigIOFuncs[i].f) {
            if (xf86SigIOFuncs[i].fd == fd) {
                xf86SigIOFuncs[i].f = null;
                xf86SigIOFuncs[i].fd = 0;
                xf86SigIOFuncs[i].closure = null;
                xf86SigIORemove(fd);
                ret = 1;
            }
            else {
                max = i + 1;
            }
        }
    }
    if (ret) {
version (O_ASYNC) {
        fcntl(fd, F_SETFL, fcntl(fd, F_GETFL) & ~O_ASYNC);
}
static if (HasVersion!"I_SETSIG" && HasVersion!"HAVE_ISASTREAM") {
        if (isastream(fd)) {
            if (ioctl(fd, I_SETSIG, 0) == -1) {
                LogMessageVerb(X_WARNING, 1, "fcntl(%d, I_SETSIG, 0): %s\n",
                               fd, strerror(errno));
            }
        }
}
        xf86SigIOMax = max;
        if (!max) {
            sigemptyset(&sa.sa_mask);
            sigaddset(&sa.sa_mask, SIGIO);
            sa.sa_flags = 0;
            sa.sa_handler = SIG_IGN;
            sigaction(SIGIO, &sa, &osa);
        }
    }
    return ret;
}
