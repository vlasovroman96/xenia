module linux;
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
import hw.kdrive.src.kdrive;
import core.stdc.errno;
import externs.linux.vt;
import externs.linux.kd;
// import core.sys.linux;
import core.sys.linux.fcntl;
import core.sys.posix.sys.stat;
import core.sys.posix.sys.ioctl;
//import x11.keysym;
import externs.linux.apm_bios;
import core.sys.posix.unistd;

import os.osdep;
import os.ddx_priv;
import os.log_priv;
import os.log;


version (KDRIVE_MOUSE) {
KdPointerDriver LinuxMouseDriver;
KdPointerDriver Ps2MouseDriver;
KdPointerDriver MsMouseDriver;
}
version (KDRIVE_TSLIB) {
KdPointerDriver TsDriver;
}
version (KDRIVE_EVDEV) {
KdPointerDriver LinuxEvdevMouseDriver;
KdKeyboardDriver LinuxEvdevKeyboardDriver;
}
version (KDRIVE_KBD) {
KdKeyboardDriver LinuxKeyboardDriver;
}

private int vtno;
static int LinuxConsoleFd = 0;
static int LinuxApmFd = -1;
private int activeVT;
private Bool enabled;

static this()
{
    LinuxConsoleFd = -1;
}

private void LinuxVTRequest(int sig)
{
    kdSwitchPending = True;
}

/* Check before chowning -- this avoids touching the file system */
private void LinuxCheckChown(const(char)* file)
{
    stat st = void;
    int r = void;

    if (stat(file, &st) < 0)
        return;
    uid_t u = getuid();
    gid_t g = getgid();
    if (st.st_uid != u || st.st_gid != g) {
        r = chown(file, u, g);
        cast(void) r;
    }
}

private int LinuxInit()
{
    int fd = -1;
    char[11] vtname = void;
    vt_stat vts = void;

    // LinuxConsoleFd = -1;
    /* check if we're run with euid==0 */
    if (geteuid() != 0) {
        FatalError("LinuxInit: Server must be suid root\n");
    }

    if (kdVirtualTerminal >= 0)
        vtno = kdVirtualTerminal;
    else {
        if ((fd = open("/dev/tty0", O_WRONLY, 0)) < 0) {
            FatalError("LinuxInit: Cannot open /dev/tty0 (%s)\n",
                       strerror(errno));
        }
        if ((ioctl(fd, VT_OPENQRY, &vtno) < 0) || (vtno == -1)) {
            FatalError("xf86OpenConsole: Cannot find a free VT\n");
        }
        close(fd);
    }

    snprintf(vtname.ptr, vtname.sizeof, "/dev/tty%d", vtno);       /* /dev/tty1-64 */

    if ((LinuxConsoleFd = open(vtname.ptr, O_RDWR | O_NDELAY, 0)) < 0) {
        FatalError("LinuxInit: Cannot open %s (%s)\n", vtname.ptr, strerror(errno));
    }

    /* change ownership of the vt */
    LinuxCheckChown(vtname.ptr);

    /*
     * the current VT device we're running on is not "console", we want
     * to grab all consoles too
     *
     * Why is this needed?
     */
    LinuxCheckChown("/dev/tty0");
    /*
     * Linux doesn't switch to an active vt after the last close of a vt,
     * so we do this ourselves by remembering which is active now.
     */
    memset(&vts, '\0', vts.sizeof);    /* valgrind */
    if (ioctl(LinuxConsoleFd, VT_GETSTATE, &vts) == 0) {
        activeVT = vts.v_active;
    }

    return 1;
}

private void LinuxSetSwitchMode(int mode)
{
    vt_mode VT = void;

    if (ioctl(LinuxConsoleFd, VT_GETMODE, &VT) < 0) {
        FatalError("LinuxInit: VT_GETMODE failed\n");
    }

    if (mode == VT_PROCESS) {
        OsSignal(SIGUSR1, &LinuxVTRequest);

        VT.mode = mode;
        VT.relsig = SIGUSR1;
        VT.acqsig = SIGUSR1;
    }
    else {
        OsSignal(SIGUSR1, SIG_IGN);

        VT.mode = mode;
        VT.relsig = 0;
        VT.acqsig = 0;
    }
    if (ioctl(LinuxConsoleFd, VT_SETMODE, &VT) < 0) {
        FatalError("LinuxInit: VT_SETMODE failed\n");
    }
}

private Bool LinuxApmRunning;

private void LinuxApmNotify(int fd, int mask, void* blockData)
{
    apm_event_t event = void;
    Bool running = LinuxApmRunning;
    int cmd = APM_IOC_SUSPEND;

    while (read(fd, &event, event.sizeof) == event.sizeof) {
        switch (event) {
        case APM_SYS_STANDBY:
        case APM_USER_STANDBY:
            running = False;
            cmd = APM_IOC_STANDBY;
            break;
        case APM_SYS_SUSPEND:
        case APM_USER_SUSPEND:
        case APM_CRITICAL_SUSPEND:
            running = False;
            cmd = APM_IOC_SUSPEND;
            break;
        case APM_NORMAL_RESUME:
        case APM_CRITICAL_RESUME:
        case APM_STANDBY_RESUME:
            running = True;
            break;
        default: break;}
    }
    if (running && !LinuxApmRunning) {
        KdResume();
        LinuxApmRunning = True;
    }
    else if (!running && LinuxApmRunning) {
        KdSuspend(FALSE);
        LinuxApmRunning = False;
        ioctl(fd, cmd, 0);
    }
}

version (FNONBLOCK) {
enum NOBLOCK = FNONBLOCK;
} else {
// enum NOBLOCK = FNDELAY;
enum NOBLOCK = O_NDELAY;
}

private void LinuxEnable()
{
    if (enabled)
        return;
    if (kdSwitchPending) {
        kdSwitchPending = False;
        ioctl(LinuxConsoleFd, VT_RELDISP, VT_ACKACQ);
    }
    /*
     * Open the APM driver
     */
    LinuxApmFd = open("/dev/apm_bios", 2);
    if (LinuxApmFd < 0 && errno == ENOENT)
        LinuxApmFd = open("/dev/misc/apm_bios", 2);
    if (LinuxApmFd >= 0) {
        LinuxApmRunning = True;
        fcntl(LinuxApmFd, F_SETFL, fcntl(LinuxApmFd, F_GETFL) | NOBLOCK);
        SetNotifyFd(LinuxApmFd, &LinuxApmNotify, X_NOTIFY_READ, null);
    }

    /*
     * now get the VT
     */
    LinuxSetSwitchMode(VT_AUTO);
    if (ioctl(LinuxConsoleFd, VT_ACTIVATE, vtno) != 0) {
        FatalError("LinuxInit: VT_ACTIVATE failed\n");
    }
    if (ioctl(LinuxConsoleFd, VT_WAITACTIVE, vtno) != 0) {
        FatalError("LinuxInit: VT_WAITACTIVE failed\n");
    }
    LinuxSetSwitchMode(VT_PROCESS);
    if (ioctl(LinuxConsoleFd, KDSETMODE, KD_GRAPHICS) < 0) {
        FatalError("LinuxInit: KDSETMODE KD_GRAPHICS failed\n");
    }
    enabled = True;
}

private Bool LinuxSpecialKey(KeySym sym)
{
    vt_stat vts = void;
    int con = void;

    if (XK_F1 <= sym && sym <= XK_F12) {
        con = sym - XK_F1 + 1;
        memset(&vts, '\0', vts.sizeof);    /* valgrind */
        ioctl(LinuxConsoleFd, VT_GETSTATE, &vts);
        if (con != vts.v_active && (vts.v_state & (1 << con))) {
            ioctl(LinuxConsoleFd, VT_ACTIVATE, con);
            return True;
        }
    }
    return False;
}

private void LinuxDisable()
{
    ioctl(LinuxConsoleFd, KDSETMODE, KD_TEXT);  /* Back to text mode ... */
    if (kdSwitchPending) {
        kdSwitchPending = False;
        ioctl(LinuxConsoleFd, VT_RELDISP, 1);
    }
    enabled = False;
    if (LinuxApmFd >= 0) {
        RemoveNotifyFd(LinuxApmFd);
        close(LinuxApmFd);
        LinuxApmFd = -1;
    }
}

private void LinuxFini()
{
    vt_mode VT = void;
    vt_stat vts = void;
    int fd = void;

    if (LinuxConsoleFd < 0)
        return;

    if (ioctl(LinuxConsoleFd, VT_GETMODE, &VT) != -1) {
        VT.mode = VT_AUTO;
        ioctl(LinuxConsoleFd, VT_SETMODE, &VT); /* set dflt vt handling */
    }
    memset(&vts, '\0', vts.sizeof);    /* valgrind */
    ioctl(LinuxConsoleFd, VT_GETSTATE, &vts);
    if (vtno == vts.v_active) {
        /*
         * Find a legal VT to switch to, either the one we started from
         * or the lowest active one that isn't ours
         */
        if (activeVT < 0 ||
            activeVT == vts.v_active || !(vts.v_state & (1 << activeVT))) {
            for (activeVT = 1; activeVT < 16; activeVT++)
                if (activeVT != vtno && (vts.v_state & (1 << activeVT)))
                    break;
            if (activeVT == 16)
                activeVT = -1;
        }
        /*
         * Perform a switch back to the active VT when we were started
         */
        if (activeVT >= -1) {
            ioctl(LinuxConsoleFd, VT_ACTIVATE, activeVT);
            ioctl(LinuxConsoleFd, VT_WAITACTIVE, activeVT);
            activeVT = -1;
        }
    }
    close(LinuxConsoleFd);      /* make the vt-manager happy */
    LinuxConsoleFd = -1;
    fd = open("/dev/tty0", O_RDWR | O_NDELAY, 0);
    if (fd >= 0) {
        memset(&vts, '\0', vts.sizeof);        /* valgrind */
        ioctl(fd, VT_GETSTATE, &vts);
        if (ioctl(fd, VT_DISALLOCATE, vtno) < 0)
            fprintf(stderr, "Can't deallocate console %d %s\n", vtno,
                    strerror(errno));
        close(fd);
    }
    return;
}

void KdOsAddInputDrivers()
{
version (KDRIVE_MOUSE) {
    KdAddPointerDriver(&LinuxMouseDriver);
    KdAddPointerDriver(&MsMouseDriver);
    KdAddPointerDriver(&Ps2MouseDriver);
}
version (KDRIVE_TSLIB) {
    KdAddPointerDriver(&TsDriver);
}
version (KDRIVE_EVDEV) {
    KdAddPointerDriver(&LinuxEvdevMouseDriver);
    KdAddKeyboardDriver(&LinuxEvdevKeyboardDriver);
}
version (KDRIVE_KBD) {
    KdAddKeyboardDriver(&LinuxKeyboardDriver);
}
}

private void LinuxBell(int volume, int pitch, int duration)
{
    if (volume && pitch)
        ioctl(LinuxConsoleFd, KDMKTONE, ((1193190 / pitch) & 0xffff) |
              ((cast(c_ulong) duration * volume / 50) << 16));
}

KdOsFuncs LinuxFuncs = {
    Init: &LinuxInit,
    Enable: &LinuxEnable,
    SpecialKey: &LinuxSpecialKey,
    Disable: &LinuxDisable,
    Fini: &LinuxFini,
    Bell: &LinuxBell,
};

void OsVendorInit()
{
    LogInit(DEFAULT_LOGDIR~ "/Xkdrive.log", ".old");
    KdOsInit(&LinuxFuncs);
}
