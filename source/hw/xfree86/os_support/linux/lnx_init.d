module lnx_init;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 1992 by Orest Zborowski <obz@Kodak.com>
 * Copyright 1993 by David Wexelblat <dwex@goblin.org>
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the names of Orest Zborowski and David Wexelblat
 * not be used in advertising or publicity pertaining to distribution of
 * the software without specific, written prior permission.  Orest Zborowski
 * and David Wexelblat make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *
 * OREST ZBOROWSKI AND DAVID WEXELBLAT DISCLAIMS ALL WARRANTIES WITH REGARD
 * TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS, IN NO EVENT SHALL OREST ZBOROWSKI OR DAVID WEXELBLAT BE LIABLE
 * FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
import build.xorg_config;

import core.stdc.errno;
import core.sys.posix.sys.stat;
//import x11.X;
////import x11.Xmd;

import os.cmdline;
import os.osdep;

import hw.xfree86.utils.compiler;
// import hw.kdrive.linux.linux;
import xf86_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;

import seatd_libseat;


import core.sys.posix.sys.stat;
version (HAVE_SYS_SYSMACROS_H) {
import sys.sysmacros;
}


import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.un;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import core.stdc.errno;

import os.log_priv;

import include.os;
import xf86_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSproc;;
import include.xf86Privstr;

import os.log;
import xf86Events;
import xf86Globals;
import externs.sys.sysmacros;;
import os.utils;



enum K_OFF = 0x4;

alias FALSE = include.misc.FALSE;
alias TRUE = include.misc.TRUE;


private Bool KeepTty = FALSE;
private int activeVT = -1;

private char[11] vtname = 0;
private termios tty_attr; /* tty state to restore */
private int tty_mode;            /* kbd mode to restore */

private void drain_console(int fd, void* closure)
{
    errno = 0;
    if (tcflush(fd, TCIOFLUSH) == -1 && errno == EIO) {
        xf86SetConsoleHandler(null, null);
    }
}

private int switch_to(int vt, const(char)* from)

{
    int ret = void;
    fprintf(stderr,
    "switch_to: vt=%d consoleFd=%d euid=%d\n",
    vt, xf86Info.consoleFd, geteuid());

    fprintf(stderr, "VT_ACTIVATE before\n");
    mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_ACTIVATE, vt)"));
    fprintf(stderr, "VT_ACTIVATE ret=%d errno=%d (%s)\n",
    ret, errno, strerror(errno));
    if (ret < 0) {
        LogMessageVerb(X_WARNING, 1, "%s: VT_ACTIVATE failed: %s\n", from, strerror(errno));
        return 0;
    }

    mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_WAITACTIVE, vt)"));
    if (ret < 0) {
        LogMessageVerb(X_WARNING, 1, "%s: VT_WAITACTIVE failed: %s\n", from, strerror(errno));
        return 0;
    }

    return 1;
}

// #pragma GCC diagnostic push
// #pragma GCC diagnostic ignored "-Wformat-nonliteral"

int linux_parse_vt_settings(int may_fail)
{
    int i = void, fd = -1, ret = void, current_vt = -1;
    vt_stat vts = void;
    stat_t st = void;
    MessageType from = X_PROBED;

    /* Only do this once */
    static int vt_settings_parsed = 0;

    if (vt_settings_parsed)
        return 1;

    /*
     * setup the virtual terminal manager
     */
    if (xf86Info.vtno != -1) {
        from = X_CMDLINE;
    }
    else {
        for (int i_ = 0; i_ <= 2; i_++)
    {
        stat_t st_ = void;
        auto r = fstat(i_, &st);
        // fprintf(stderr,
        //     "fd=%d mode=%#x rdev=%#llx\n",
        //     i,
        //     cast(uint) st.st_mode,
        //     cast(ulong) st.st_rdev);
    }
        fd = open("/dev/tty0", O_WRONLY, 0);
        if (fd < 0) {
            if (may_fail)
                return 0;
            FatalError("parse_vt_settings: Cannot open /dev/tty0 (%s), maybe missing for ex. '-seat seat0 -keeptty' parameters? (in case trying to run uid !=0 mode)\n",
                       strerror(errno));
        }

        if (xf86Info.ShareVTs) {
            mixin(SYSCALL!("ret = ioctl(fd, VT_GETSTATE, &vts)"));
            if (ret < 0) {
                if (may_fail)
                    return 0;
                FatalError("parse_vt_settings: Cannot find the current"
                           ~ " VT (%s)\n", strerror(errno));
            }
            xf86Info.vtno = vts.v_active;
        }
        else {
            mixin(SYSCALL!("ret = ioctl(fd, VT_OPENQRY, &xf86Info.vtno)"));
            if (ret < 0) {
                if (may_fail)
                    return 0;
                FatalError("parse_vt_settings: Cannot find a free VT: "
                           ~ "%s\n", strerror(errno));
            }
            if (xf86Info.vtno == -1) {
                if (may_fail)
                    return 0;
                FatalError("parse_vt_settings: Cannot find a free VT\n");
            }
        }
        close(fd);
    }

    LogMessageVerb(from, 1, "using VT number %d\n\n", xf86Info.vtno);

    /* Some of stdin / stdout / stderr maybe redirected to a file */
    for (i = STDIN_FILENO; i <= STDERR_FILENO; i++) {
        ret = fstat(i, &st);
        if (ret == 0 && S_ISCHR(st.st_mode) && major(st.st_rdev) == 4) {
            current_vt = minor(st.st_rdev);
            break;
        }
        fprintf(stderr,
        "fd=%d r=%d mode=%#x rdev=%#llx major=%u minor=%u\n",
        i, ret,
        st.st_mode,
        cast(ulong)st.st_rdev,
        major(st.st_rdev),
        minor(st.st_rdev));
    }

    if (!KeepTty && current_vt == xf86Info.vtno) {
        LogMessageVerb(X_PROBED, 1,
                       "controlling tty is VT number %d, auto-enabling KeepTty\n",
                       current_vt);
        KeepTty = TRUE;
    }

    vt_settings_parsed = 1;
    return 1;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTKeepTtyIsSet()
{
    return KeepTty;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86OpenConsole()
{
        fprintf(stderr,
    "console: vtno=%d consoleFd=%d seatd=%d KeepTty=%d\n",
    xf86Info.vtno,
    xf86Info.consoleFd,
    seatd_libseat_controls_session(),
    KeepTty);
    int i = void, ret = void;
    vt_stat vts = void;
    vt_mode VT = void;
    const(char)*[3] vcs = cast(const(char)*[])[ "/dev/vc/%d", "/dev/tty%d", null ];

    if (serverGeneration == 1) {
        linux_parse_vt_settings(FALSE);

        if (!KeepTty) {
            pid_t ppid = getppid();
            pid_t ppgid = void;

            ppgid = getpgid(ppid);

            /*
             * change to parent process group that pgid != pid so
             * that setsid() doesn't fail and we become process
             * group leader
             */
            if (setpgid(0, ppgid) < 0)
                LogMessageVerb(X_WARNING, 1, "xf86OpenConsole: setpgid failed: %s\n",
                               strerror(errno));

            /* become process group leader */
            if ((setsid() < 0))
                LogMessageVerb(X_WARNING, 1, "xf86OpenConsole: setsid failed: %s\n",
                               strerror(errno));
        }

        i = 0;
        while (vcs[i] !is null) {
            snprintf(vtname.ptr, vtname.sizeof, vcs[i], xf86Info.vtno);    /* /dev/tty1-64 */
            if ((xf86Info.consoleFd = open(vtname.ptr, O_RDWR | O_NDELAY, 0)) >= 0)
                break;
            i++;
        }


        /* If libseat is in control, it handles VT switching. */
        if (seatd_libseat_controls_session())
            return;

        if (xf86Info.consoleFd < 0)
            FatalError("xf86OpenConsole: Cannot open virtual console"
                       ~ " %d (%s)\n", xf86Info.vtno, strerror(errno));

        /*
         * Linux doesn't switch to an active vt after the last close of a vt,
         * so we do this ourselves by remembering which is active now.
         */
        mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_GETSTATE, &vts)"));
        if (ret < 0)
            LogMessageVerb(X_WARNING, 1, "xf86OpenConsole: VT_GETSTATE failed: %s\n",
                           strerror(errno));
        else
            activeVT = vts.v_active;

        if (!xf86Info.ShareVTs) {
            termios nTty = void;

            /*
             * now get the VT.  This _must_ succeed, or else fail completely.
             */
            if (!switch_to(xf86Info.vtno, "xf86OpenConsole"))
                FatalError("xf86OpenConsole: Switching VT failed\n");

            mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_GETMODE, &VT)"));
            if (ret < 0)
                FatalError("xf86OpenConsole: VT_GETMODE failed %s\n",
                           strerror(errno));

            OsSignal(SIGUSR1, &xf86VTRequest);

            VT.mode = VT_PROCESS;
            VT.relsig = SIGUSR1;
            VT.acqsig = SIGUSR1;

            mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_SETMODE, &VT)"));
            if (ret < 0)
                FatalError
                    ("xf86OpenConsole: VT_SETMODE VT_PROCESS failed: %s\n",
                     strerror(errno));

            mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, KDSETMODE, KD_GRAPHICS)"));
            if (ret < 0)
                FatalError("xf86OpenConsole: KDSETMODE KD_GRAPHICS failed %s\n",
                           strerror(errno));

            tcgetattr(xf86Info.consoleFd, &tty_attr);
            mixin(SYSCALL!("ioctl(xf86Info.consoleFd, KDGKBMODE, &tty_mode)"));

            /* disable kernel special keys and buffering */
            mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, KDSKBMODE, K_OFF)"));
            if (ret < 0)
            {
                /* fine, just disable special keys */
                mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, KDSKBMODE, K_RAW)"));
                if (ret < 0)
                    FatalError("xf86OpenConsole: KDSKBMODE K_RAW failed %s\n",
                               strerror(errno));

                /* ... and drain events, else the kernel gets angry */
                xf86SetConsoleHandler(&drain_console, null);
            }

            nTty = tty_attr;
            nTty.c_iflag = (IGNPAR | IGNBRK) & (~PARMRK) & (~ISTRIP);
            nTty.c_oflag = 0;
            nTty.c_cflag = CREAD | CS8;
            nTty.c_lflag = 0;
            nTty.c_cc[VTIME] = 0;
            nTty.c_cc[VMIN] = 1;
            cfsetispeed(&nTty, 9600);
            cfsetospeed(&nTty, 9600);
            tcsetattr(xf86Info.consoleFd, TCSANOW, &nTty);
        }
    }
    else {                      /* serverGeneration != 1 */
        if (!xf86Info.ShareVTs && xf86Info.autoVTSwitch) {
            /* now get the VT */
            if (!switch_to(xf86Info.vtno, "xf86OpenConsole"))
                FatalError("xf86OpenConsole: Switching VT failed\n");
        }
    }
}

// #pragma GCC diagnostic pop

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86CloseConsole()
{

    vt_mode VT = void;
    vt_stat vts = void;
    int ret = void;

    if (xf86Info.ShareVTs || seatd_libseat_controls_session()) {
        close(xf86Info.consoleFd);
        return;
    }

    /*
     * unregister the drain_console handler
     * - what to do if someone else changed it in the meantime?
     */
    xf86SetConsoleHandler(null, null);

    /* Back to text mode ... */
    mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, KDSETMODE, KD_TEXT)"));
    if (ret < 0)
        LogMessageVerb(X_WARNING, 1, "xf86CloseConsole: KDSETMODE failed: %s\n",
                       strerror(errno));

    mixin(SYSCALL!("ioctl(xf86Info.consoleFd, KDSKBMODE, tty_mode)"));
    tcsetattr(xf86Info.consoleFd, TCSANOW, &tty_attr);

    mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_GETMODE, &VT)"));
    if (ret < 0)
        LogMessageVerb(X_WARNING, 1, "xf86CloseConsole: VT_GETMODE failed: %s\n",
                       strerror(errno));
    else {
        /* set dflt vt handling */
        VT.mode = VT_AUTO;
        mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_SETMODE, &VT)"));
        if (ret < 0)
            LogMessageVerb(X_WARNING, 1, "xf86CloseConsole: VT_SETMODE failed: %s\n",
                           strerror(errno));
    }

    if (xf86Info.autoVTSwitch) {
        /*
        * Perform a switch back to the active VT when we were started if our
        * vt is active now.
        */
        if (activeVT >= 0) {
            mixin(SYSCALL!("ret = ioctl(xf86Info.consoleFd, VT_GETSTATE, &vts)"));
            if (ret < 0) {
                LogMessageVerb(X_WARNING, 1, "xf86OpenConsole: VT_GETSTATE failed: %s\n",
                               strerror(errno));
            } else {
                if (vts.v_active == xf86Info.vtno) {
                    switch_to(activeVT, "xf86CloseConsole");
                }
            }
            activeVT = -1;
        }
    }
    close(xf86Info.consoleFd);  /* make the vt-manager happy */
}

enum string CHECK_FOR_REQUIRED_ARGUMENT() = `
    if (((i + 1) >= argc) || (!argv[i + 1])) { 				
      ErrorF("Required argument to %s not specified\n", argv[i]); 	
      UseMsg(); 							
      FatalError("Required argument to %s not specified\n", argv[i]);	
    }`;

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86ProcessArgument(int argc, char** argv, int i)
{
    /*
     * Keep server from detaching from controlling tty.  This is useful
     * when debugging (so the server can receive keyboard signals.
     */
    if (!strcmp(argv[i], "-keeptty")) {
        KeepTty = TRUE;
        return 1;
    }

    if ((argv[i][0] == 'v') && (argv[i][1] == 't')) {
        if (sscanf(argv[i], "vt%2d", &xf86Info.vtno) == 0) {
            UseMsg();
            xf86Info.vtno = -1;
            return 0;
        }
        return 1;
    }

    if (!strcmp(argv[i], "-masterfd")) {
        mixin(CHECK_FOR_REQUIRED_ARGUMENT!());
        if (PrivsElevated())
            FatalError("\nCannot specify -masterfd when server is setuid/setgid\n");
        if (sscanf(argv[++i], "%d", &xf86DRMMasterFd) != 1) {
            UseMsg();
            xf86DRMMasterFd = -1;
            return 0;
        }
        return 2;
    }

    return 0;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86UseMsg()
{
    ErrorF("vtXX                   use the specified VT number\n");
    ErrorF("-keeptty               ");
    ErrorF("don't detach controlling tty (for debugging only)\n");
    ErrorF("-masterfd <fd>         use the specified fd as the DRM master fd (not if setuid/gid)\n");
}

void xf86OSInputThreadInit()
{
    return;
}
