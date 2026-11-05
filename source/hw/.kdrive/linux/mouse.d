module mouse;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2001 Keith Packard
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
import core.sys.posix.termios;
import build.dix_config;
//import x11.X;
//import x11.Xproto;
import os.xserver_poll;
import dix.inputstr;
import dix.scrnintstr;
import hw.kdrive.src.kdrive;

enum KBUFIO_SIZE = 256;
enum MOUSE_TIMEOUT =	100;

struct Kbufio {
    int fd;
    ubyte[KBUFIO_SIZE] buf;
    int avail;
    int used;
}

private Bool MouseWaitForReadable(int fd, int timeout)
{
    pollfd poll_fd = void;
    int n = void;
    CARD32 done = void;

    done = GetTimeInMillis() + timeout;
    poll_fd.fd = fd;
    poll_fd.events = POLLIN;
    for (;;) {
        n = xserver_poll(&poll_fd, 1, timeout);
        if (n > 0)
            return TRUE;
        if (n < 0 && (errno == EAGAIN || errno == EINTR)) {
            timeout = cast(int) (done - GetTimeInMillis());
            if (timeout > 0)
                continue;
        }
        break;
    }
    return FALSE;
}

private int MouseReadByte(Kbufio* b, int timeout)
{
    int n = void;

    if (b.avail <= b.used) {
        if (timeout && !MouseWaitForReadable(b.fd, timeout)) {
version (DEBUG_BYTES) {
            ErrorF("\tTimeout %d\n", timeout);
}
            return -1;
        }
        n = read(b.fd, b.buf, KBUFIO_SIZE);
        if (n <= 0)
            return -1;
        b.avail = n;
        b.used = 0;
    }
version (DEBUG_BYTES) {
    ErrorF("\tget %02x\n", b.buf[b.used]);
}
    return b.buf[b.used++];
}

static if (NOTUSED) {
private int MouseFlush(Kbufio* b, char* buf, int size)
{
    CARD32 now = GetTimeInMillis();
    CARD32 done = now + 100;
    int c = void;
    int n = 0;

    while ((c = MouseReadByte(b, done - now)) != -1) {
        if (buf) {
            if (n == size) {
                memmove(buf.ptr, buf.ptr + 1, size - 1);
                n--;
            }
            buf[n++] = c;
        }
        now = GetTimeInMillis();
        if (cast(INT32) (now - done) >= 0)
            break;
    }
    return n;
}

private int MousePeekByte(Kbufio* b, int timeout)
{
    int c = void;

    c = MouseReadByte(b, timeout);
    if (c != -1)
        --b.used;
    return c;
}
}                          /* NOTUSED */

private Bool MouseWaitForWritable(int fd, int timeout)
{
    pollfd poll_fd = void;
    int n = void;

    poll_fd.fd = fd;
    poll_fd.events = POLLOUT;
    n = xserver_poll(&poll_fd, 1, timeout);
    if (n > 0)
        return TRUE;
    return FALSE;
}

private Bool MouseWriteByte(int fd, ubyte c, int timeout)
{
    int ret = void;

version (DEBUG_BYTES) {
    ErrorF("\tput %02x\n", c);
}
    for (;;) {
        ret = write(fd, &c, 1);
        if (ret == 1)
            return TRUE;
        if (ret == 0)
            return FALSE;
        if (errno != EWOULDBLOCK)
            return FALSE;
        if (!MouseWaitForWritable(fd, timeout))
            return FALSE;
    }
}

private Bool MouseWriteBytes(int fd, ubyte* c, int n, int timeout)
{
    while (n--)
        if (!MouseWriteByte(fd, *c++, timeout))
            return FALSE;
    return TRUE;
}

enum MAX_MOUSE =   10          /* maximum length of mouse protocol */;
enum MAX_SKIP =    16          /* number of error bytes before switching */;
enum MAX_VALID =   4           /* number of valid packets before accepting */;

struct KmouseProt {
    const(char)* name;
    Bool function(KdPointerInfo* pi, ubyte* ev, int ne) Complete;
    int function(KdPointerInfo* pi, ubyte* ev, int ne) Valid;
    Bool function(KdPointerInfo* pi, ubyte* ev, int ne) Parse;
    Bool function(KdPointerInfo* pi) Init;
    ubyte headerMask, headerValid;
    ubyte dataMask, dataValid;
    Bool tty;
    uint c_iflag;
    uint c_oflag;
    uint c_lflag;
    uint c_cflag;
    uint speed;
    ubyte* init;
    c_ulong state;
}

enum KmouseStage {
    MouseBroken, MouseTesting, MouseWorking
}
alias MouseBroken = KmouseStage.MouseBroken;
alias MouseTesting = KmouseStage.MouseTesting;
alias MouseWorking = KmouseStage.MouseWorking;


struct Kmouse {
    Kbufio iob;
    const(KmouseProt)* prot;
    int i_prot;
    KmouseStage stage;          /* protocol verification stage */
    Bool tty;                   /* mouse device is a tty */
    int valid;                  /* sequential valid events */
    int tested;                 /* bytes scanned during Testing phase */
    int invalid;                /* total invalid bytes for this protocol */
    c_ulong state;        /* private per protocol, init to prot->state */
}

private int mouseValid(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;
    const(KmouseProt)* prot = km.prot;
    int i = void;

    for (i = 0; i < ne; i++)
        if ((ev[i] & prot.headerMask) == prot.headerValid)
            break;
    if (i != 0)
        return i;
    for (i = 1; i < ne; i++)
        if ((ev[i] & prot.dataMask) != prot.dataValid)
            return -1;
    return 0;
}

private Bool threeComplete(KdPointerInfo* pi, ubyte* ev, int ne)
{
    return ne == 3;
}

private Bool fourComplete(KdPointerInfo* pi, ubyte* ev, int ne)
{
    return ne == 4;
}

private Bool fiveComplete(KdPointerInfo* pi, ubyte* ev, int ne)
{
    return ne == 5;
}

private Bool MouseReasonable(KdPointerInfo* pi, c_ulong flags, int dx, int dy)
{
    Kmouse* km = pi.driverPrivate;

    if (km.stage == MouseWorking)
        return TRUE;
    if (dx < -50 || dx > 50) {
version (DEBUG) {
        ErrorF("Large X %d\n", dx);
}
        return FALSE;
    }
    if (dy < -50 || dy > 50) {
version (DEBUG) {
        ErrorF("Large Y %d\n", dy);
}
        return FALSE;
    }
    return TRUE;
}

/*
 * Standard PS/2 mouse protocol
 */
private Bool ps2Parse(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;
    int dx = void, dy = void, dz = void;
    c_ulong flags = void;
    c_ulong flagsrelease = 0;

    flags = KD_MOUSE_DELTA;
    if (ev[0] & 4)
        flags |= KD_BUTTON_2;
    if (ev[0] & 2)
        flags |= KD_BUTTON_3;
    if (ev[0] & 1)
        flags |= KD_BUTTON_1;

    if (ne > 3) {
        dz = cast(int) cast(char) ev[3];
        if (dz < 0) {
            flags |= KD_BUTTON_4;
            flagsrelease = KD_BUTTON_4;
        }
        else if (dz > 0) {
            flags |= KD_BUTTON_5;
            flagsrelease = KD_BUTTON_5;
        }
    }

    dx = ev[1];
    if (ev[0] & 0x10)
        dx -= 256;
    dy = ev[2];
    if (ev[0] & 0x20)
        dy -= 256;
    dy = -dy;
    if (!MouseReasonable(pi, flags, dx, dy))
        return FALSE;
    if (km.stage == MouseWorking) {
        KdEnqueuePointerEvent(pi, flags, dx, dy, 0);
        if (flagsrelease) {
            flags &= ~flagsrelease;
            KdEnqueuePointerEvent(pi, flags, dx, dy, 0);
        }
    }
    return TRUE;
}



private const(KmouseProt) ps2Prot = {
    "ps/2",
    &threeComplete, &mouseValid, &ps2Parse, &ps2Init,
    0x08, 0x08, 0x00, 0x00,
    FALSE
};

private const(KmouseProt) imps2Prot = {
    "imps/2",
    &fourComplete, &mouseValid, &ps2Parse, &ps2Init,
    0x08, 0x08, 0x00, 0x00,
    FALSE
};

private const(KmouseProt) exps2Prot = {
    "exps/2",
    &fourComplete, &mouseValid, &ps2Parse, &ps2Init,
    0x08, 0x08, 0x00, 0x00,
    FALSE
};

/*
 * Once the mouse is known to speak ps/2 protocol, go and find out
 * what advanced capabilities it has and turn them on
 */

/* these extracted from FreeBSD 4.3 sys/dev/kbd/atkbdcreg.h */

/* aux device commands (sent to KBD_DATA_PORT) */
enum PSMC_SET_SCALING11 =      0x00e6;
enum PSMC_SET_SCALING21 =      0x00e7;
enum PSMC_SET_RESOLUTION =     0x00e8;
enum PSMC_SEND_DEV_STATUS =    0x00e9;
enum PSMC_SET_STREAM_MODE =    0x00ea;
enum PSMC_SEND_DEV_DATA =      0x00eb;
enum PSMC_SET_REMOTE_MODE =    0x00f0;
enum PSMC_SEND_DEV_ID =        0x00f2;
enum PSMC_SET_SAMPLING_RATE =  0x00f3;
enum PSMC_ENABLE_DEV =         0x00f4;
enum PSMC_DISABLE_DEV =        0x00f5;
enum PSMC_SET_DEFAULTS =       0x00f6;
enum PSMC_RESET_DEV =          0x00ff;

/* PSMC_SET_RESOLUTION argument */
enum PSMD_RES_LOW =            0       /* typically 25ppi */;
enum PSMD_RES_MEDIUM_LOW =     1       /* typically 50ppi */;
enum PSMD_RES_MEDIUM_HIGH =    2       /* typically 100ppi (default) */;
enum PSMD_RES_HIGH =           3       /* typically 200ppi */;
enum PSMD_MAX_RESOLUTION =     PSMD_RES_HIGH;

/* PSMC_SET_SAMPLING_RATE */
enum PSMD_MAX_RATE =           255     /* FIXME: not sure if it's possible */;

/* aux device ID */
enum PSM_MOUSE_ID =            0;
enum PSM_BALLPOINT_ID =        2;
enum PSM_INTELLI_ID =          3;
enum PSM_EXPLORER_ID =         4;
enum PSM_4DMOUSE_ID =          6;
enum PSM_4DPLUS_ID =           8;

private ubyte[1] ps2_init = [
    PSMC_ENABLE_DEV
];

enum NINIT_PS2 =   1;

private ubyte[8] wheel_3button_init = [
    PSMC_SET_SAMPLING_RATE, 200,
    PSMC_SET_SAMPLING_RATE, 100,
    PSMC_SET_SAMPLING_RATE, 80,
    PSMC_SEND_DEV_ID,
];

enum NINIT_IMPS2 = 4;

private ubyte[14] wheel_5button_init = [
    PSMC_SET_SAMPLING_RATE, 200,
    PSMC_SET_SAMPLING_RATE, 100,
    PSMC_SET_SAMPLING_RATE, 80,
    PSMC_SET_SAMPLING_RATE, 200,
    PSMC_SET_SAMPLING_RATE, 200,
    PSMC_SET_SAMPLING_RATE, 80,
    PSMC_SEND_DEV_ID,
];

enum NINIT_EXPS2 = 7;

private ubyte[7] intelli_init = [
    PSMC_SET_SAMPLING_RATE, 200,
    PSMC_SET_SAMPLING_RATE, 100,
    PSMC_SET_SAMPLING_RATE, 80,
];

enum NINIT_INTELLI =	3;

private int ps2SkipInit(KdPointerInfo* pi, int ninit, Bool ret_next)
{
    Kmouse* km = pi.driverPrivate;
    int c = -1;
    Bool waiting = void;

    waiting = FALSE;
    while (ninit || ret_next) {
        c = MouseReadByte(&km.iob, 1); /* Minimum timeout like in xf86-input-mouse and tinyx */
        if (c == -1)
            break;
        /* look for ACK */
        if (c == 0xfa) {
            ninit--;
            if (ret_next)
                waiting = TRUE;
        }
        /* look for packet start -- not the response */
        else if ((c & 0x08) == 0x08)
            waiting = FALSE;
        else if (waiting)
            break;
    }
    return c;
}

private Bool ps2Init(KdPointerInfo* pi)
{
    Kmouse* km = pi.driverPrivate;
    int id = void;
    ubyte* init = void;
    int ninit = void;
    int len = void;

    /* Send Intellimouse initialization sequence */
    MouseWriteBytes(km.iob.fd, intelli_init.ptr, intelli_init.sizeof,
                    100);
    /*
     * Send ID command
     */
    if (!MouseWriteByte(km.iob.fd, PSMC_SEND_DEV_ID, 100))
        return FALSE;
    id = ps2SkipInit(pi, 0, TRUE);
    switch (id) {
    case 3:
        init = wheel_3button_init;
        ninit = NINIT_IMPS2;
        km.prot = &imps2Prot;
        len = wheel_3button_init.sizeof;
        break;
    case 4:
        init = wheel_5button_init;
        ninit = NINIT_EXPS2;
        km.prot = &exps2Prot;
        len = wheel_5button_init.sizeof;
        break;
    default:
        init = ps2_init;
        ninit = NINIT_PS2;
        km.prot = &ps2Prot;
        len = ps2_init.sizeof;
        break;
    }
    if (init)
        MouseWriteBytes(km.iob.fd, init, len, 100);
    /*
     * Flush out the available data to eliminate responses to the
     * initialization string.  Make sure any partial event is
     * skipped
     */
    cast(void) ps2SkipInit(pi, ninit, FALSE);
    return TRUE;
}

private Bool busParse(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;
    int dx = void, dy = void;
    c_ulong flags = void;

    flags = KD_MOUSE_DELTA;
    dx = cast(char) ev[1];
    dy = -cast(char) ev[2];
    if ((ev[0] & 4) == 0)
        flags |= KD_BUTTON_1;
    if ((ev[0] & 2) == 0)
        flags |= KD_BUTTON_2;
    if ((ev[0] & 1) == 0)
        flags |= KD_BUTTON_3;
    if (!MouseReasonable(pi, flags, dx, dy))
        return FALSE;
    if (km.stage == MouseWorking)
        KdEnqueuePointerEvent(pi, flags, dx, dy, 0);
    return TRUE;
}

private const(KmouseProt) busProt = {
    "bus",
    &threeComplete, &mouseValid, &busParse, null,
    0xf8, 0x00, 0x00, 0x00,
    FALSE
};

/*
 * Standard MS serial protocol, three bytes
 */

private Bool msParse(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;
    int dx = void, dy = void;
    c_ulong flags = void;

    flags = KD_MOUSE_DELTA;

    if (ev[0] & 0x20)
        flags |= KD_BUTTON_1;
    if (ev[0] & 0x10)
        flags |= KD_BUTTON_3;

    dx = cast(char) (((ev[0] & 0x03) << 6) | (ev[1] & 0x3F));
    dy = cast(char) (((ev[0] & 0x0C) << 4) | (ev[2] & 0x3F));
    if (!MouseReasonable(pi, flags, dx, dy))
        return FALSE;
    if (km.stage == MouseWorking)
        KdEnqueuePointerEvent(pi, flags, dx, dy, 0);
    return TRUE;
}

private const(KmouseProt) msProt = {
    "ms",
    &threeComplete, &mouseValid, &msParse, null,
    0xc0, 0x40, 0xc0, 0x00,
    TRUE,
    IGNPAR,
    0,
    0,
    CS7 | CSTOPB | CREAD | CLOCAL,
    B1200,
};

/*
 * Logitech mice send 3 or 4 bytes, the only way to tell is to look at the
 * first byte of a synchronized protocol stream and see if it's got
 * any bits turned on that can't occur in that fourth byte
 */
private Bool logiComplete(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;

    if ((ev[0] & 0x40) == 0x40)
        return ne == 3;
    if (km.stage != MouseBroken && (ev[0] & ~0x23) == 0)
        return ne == 1;
    return FALSE;
}

private int logiValid(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;
    const(KmouseProt)* prot = km.prot;
    int i = void;

    for (i = 0; i < ne; i++) {
        if ((ev[i] & 0x40) == 0x40)
            break;
        if (km.stage != MouseBroken && (ev[i] & ~0x23) == 0)
            break;
    }
    if (i != 0)
        return i;
    for (i = 1; i < ne; i++)
        if ((ev[i] & prot.dataMask) != prot.dataValid)
            return -1;
    return 0;
}

private Bool logiParse(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;
    int dx = void, dy = void;
    c_ulong flags = void;

    flags = KD_MOUSE_DELTA;

    if (ne == 3) {
        if (ev[0] & 0x20)
            flags |= KD_BUTTON_1;
        if (ev[0] & 0x10)
            flags |= KD_BUTTON_3;

        dx = cast(char) (((ev[0] & 0x03) << 6) | (ev[1] & 0x3F));
        dy = cast(char) (((ev[0] & 0x0C) << 4) | (ev[2] & 0x3F));
        flags |= km.state & KD_BUTTON_2;
    }
    else {
        if (ev[0] & 0x20)
            flags |= KD_BUTTON_2;
        dx = 0;
        dy = 0;
        flags |= km.state & (KD_BUTTON_1 | KD_BUTTON_3);
    }

    if (!MouseReasonable(pi, flags, dx, dy))
        return FALSE;
    if (km.stage == MouseWorking)
        KdEnqueuePointerEvent(pi, flags, dx, dy, 0);
    return TRUE;
}

private const(KmouseProt) logiProt = {
    "logitech",
    &logiComplete, &logiValid, &logiParse, null,
    0xc0, 0x40, 0xc0, 0x00,
    TRUE,
    IGNPAR,
    0,
    0,
    CS7 | CSTOPB | CREAD | CLOCAL,
    B1200,
};

/*
 * Mouse systems protocol, 5 bytes
 */
private Bool mscParse(KdPointerInfo* pi, ubyte* ev, int ne)
{
    Kmouse* km = pi.driverPrivate;
    int dx = void, dy = void;
    c_ulong flags = void;

    flags = KD_MOUSE_DELTA;

    if (!(ev[0] & 0x4))
        flags |= KD_BUTTON_1;
    if (!(ev[0] & 0x2))
        flags |= KD_BUTTON_2;
    if (!(ev[0] & 0x1))
        flags |= KD_BUTTON_3;
    dx = cast(char) (ev[1]) + cast(char) (ev[3]);
    dy = -(cast(char) (ev[2]) + cast(char) (ev[4]));

    if (!MouseReasonable(pi, flags, dx, dy))
        return FALSE;
    if (km.stage == MouseWorking)
        KdEnqueuePointerEvent(pi, flags, dx, dy, 0);
    return TRUE;
}

private const(KmouseProt) mscProt = {
    "msc",
    &fiveComplete, &mouseValid, &mscParse, null,
    0xf8, 0x80, 0x00, 0x00,
    TRUE,
    IGNPAR,
    0,
    0,
    CS8 | CSTOPB | CREAD | CLOCAL,
    B1200,
};

/*
 * Use logitech before ms -- they're the same except that
 * logitech sometimes has a fourth byte
 */
private const(KmouseProt)*[8] kmouseProts = [
    &ps2Prot, &imps2Prot, &exps2Prot, &busProt, &logiProt, &msProt, &mscProt,
];

enum NUM_PROT =    kmouseProts.sizeof / kmouseProts[0].sizeof;

private void MouseInitProtocol(Kmouse* km)
{
    int ret = void;
    termios t = void;

    if (km.prot.tty) {
        ret = tcgetattr(km.iob.fd, &t);

        if (ret >= 0) {
            t.c_iflag = km.prot.c_iflag;
            t.c_oflag = km.prot.c_oflag;
            t.c_lflag = km.prot.c_lflag;
            t.c_cflag = km.prot.c_cflag;
            cfsetispeed(&t, km.prot.speed);
            cfsetospeed(&t, km.prot.speed);
            ret = tcsetattr(km.iob.fd, TCSANOW, &t);
        }
    }
    km.stage = MouseBroken;
    km.valid = 0;
    km.tested = 0;
    km.invalid = 0;
    km.state = km.prot.state;
}

private void MouseFirstProtocol(Kmouse* km, const(char)* prot)
{
    if (prot) {
        for (km.i_prot = 0; km.i_prot < NUM_PROT; km.i_prot++)
            if (!strcmp(prot, kmouseProts[km.i_prot].name))
                break;
        if (km.i_prot == NUM_PROT) {
            int i = void;

            ErrorF("Unknown mouse protocol \"%s\". Pick one of:", prot);
            for (i = 0; i < NUM_PROT; i++)
                ErrorF(" %s", kmouseProts[i].name);
            ErrorF("\n");
            km.i_prot = 0;
            km.prot = kmouseProts[km.i_prot];
            ErrorF("Falling back to %s\n", km.prot.name);
        }
        else {
            km.prot = kmouseProts[km.i_prot];
            if (km.tty && !km.prot.tty)
                ErrorF
                    ("Mouse device is serial port, protocol %s is not serial protocol\n",
                     prot);
            else if (!km.tty && km.prot.tty)
                ErrorF
                    ("Mouse device is not serial port, protocol %s is serial protocol\n",
                     prot);
        }
    }
    if (!km.prot) {
        for (km.i_prot = 0; kmouseProts[km.i_prot].tty != km.tty;
             km.i_prot++){}
        km.prot = kmouseProts[km.i_prot];
    }
    MouseInitProtocol(km);
}

private void MouseNextProtocol(Kmouse* km)
{
    do {
        if (!km.prot)
            km.i_prot = 0;
        else if (++km.i_prot >= NUM_PROT)
            km.i_prot = 0;
        km.prot = kmouseProts[km.i_prot];
    } while (km.prot.tty != km.tty);
    MouseInitProtocol(km);
    ErrorF("Switching to mouse protocol \"%s\"\n", km.prot.name);
}

private void MouseRead(int mousePort, void* closure)
{
    KdPointerInfo* pi = closure;
    Kmouse* km = pi.driverPrivate;
    ubyte[MAX_MOUSE] event = void;
    int ne = void;
    int c = void;
    int i = void;
    int timeout = void;

    timeout = 0;
    ne = 0;
    for (;;) {
        c = MouseReadByte(&km.iob, timeout);
        if (c == -1) {
            if (ne) {
                km.invalid += ne + km.tested;
                km.valid = 0;
                km.tested = 0;
                km.stage = MouseBroken;
            }
            break;
        }
        event[ne++] = c;
        i = (*km.prot.Valid) (pi, event.ptr, ne);
        if (i != 0) {
version (DEBUG) {
            ErrorF("Mouse protocol %s broken %d of %d bytes bad\n",
                   km.prot.name, i > 0 ? i : ne, ne);
}
            if (i > 0 && i < ne) {
                ne -= i;
                memmove(event.ptr, event.ptr + i, ne);
            }
            else {
                i = ne;
                ne = 0;
            }
            km.invalid += i + km.tested;
            km.valid = 0;
            km.tested = 0;
            if (km.stage == MouseWorking)
                km.i_prot--;
            km.stage = MouseBroken;
            if (km.invalid > MAX_SKIP) {
                MouseNextProtocol(km);
                ne = 0;
            }
            timeout = 0;
        }
        else {
            if ((*km.prot.Complete) (pi, event.ptr, ne)) {
                if ((*km.prot.Parse) (pi, event.ptr, ne)) {
                    switch (km.stage) {
                    case MouseBroken:
version (DEBUG) {
                        ErrorF("Mouse protocol %s seems OK\n", km.prot.name);
}
                        /* do not zero invalid to accumulate invalid bytes */
                        km.valid = 0;
                        km.tested = 0;
                        km.stage = MouseTesting;
                        /* fall through ... */
                    case MouseTesting:
                        km.valid++;
                        km.tested += ne;
                        if (km.valid > MAX_VALID) {
version (DEBUG) {
                            ErrorF("Mouse protocol %s working\n",
                                   km.prot.name);
}
                            km.stage = MouseWorking;
                            km.invalid = 0;
                            km.tested = 0;
                            km.valid = 0;
                            if (km.prot.Init && !(*km.prot.Init) (pi))
                                km.stage = MouseBroken;
                        }
                        break;
                    case MouseWorking:
                        break;
                    default: break;}
                }
                else {
                    km.invalid += ne + km.tested;
                    km.valid = 0;
                    km.tested = 0;
                    km.stage = MouseBroken;
                }
                ne = 0;
                timeout = 0;
            }
            else
                timeout = MOUSE_TIMEOUT;
        }
    }
}

const(char)*[7] kdefaultMouse = [
    "/dev/input/mice",
    "/dev/mouse",
    "/dev/psaux",
    "/dev/adbmouse",
    "/dev/ttyS0",
    "/dev/ttyS1",
];

enum NUM_DEFAULT_MOUSE =    kdefaultMouse.sizeof /  kdefaultMouse[0].sizeof;

private Status MouseInit(KdPointerInfo* pi)
{
    int i = void;
    int fd = void;
    Kmouse* km = void;

    if (!pi)
        return BadImplementation;

    if (!pi.path || strcmp(pi.path, "auto") == 0) {
        for (i = 0; i < NUM_DEFAULT_MOUSE; i++) {
            fd = open(kdefaultMouse[i], 2);
            if (fd >= 0) {
                pi.path = strdup(kdefaultMouse[i]);
                break;
            }
        }
    }
    else {
        fd = open(pi.path, 2);
    }

    if (fd < 0)
        return BadMatch;

    km = cast(Kmouse*) malloc(Kmouse.sizeof);
    if (km) {
        km.iob.avail = km.iob.used = 0;
        MouseFirstProtocol(km, pi.protocol ? pi.protocol : "ps/2");
        /* MouseFirstProtocol sets state to MouseBroken for later protocol
         * checks. Skip these checks if a protocol was supplied */
        if (pi.protocol)
            km.state = MouseWorking;
        km.i_prot = 0;
        km.tty = isatty(fd);
        km.iob.fd = fd;
        pi.driverPrivate = km;
    }
    else {
        close(fd);
        return BadAlloc;
    }

    return Success;
}

private Status MouseEnable(KdPointerInfo* pi)
{
    Kmouse* km = void;

    if (!pi || !pi.driverPrivate || !pi.path)
        return BadImplementation;

    km = pi.driverPrivate;

    km.iob.fd = open(pi.path, 2);
    if (km.iob.fd < 0)
        return BadMatch;

    if (!KdRegisterFd(km.iob.fd, &MouseRead, pi)) {
        close(km.iob.fd);
        return BadAlloc;
    }

    return Success;
}

private void MouseDisable(KdPointerInfo* pi)
{
    Kmouse* km = void;

    if (!pi || !pi.driverPrivate)
        return;

    km = pi.driverPrivate;
    KdUnregisterFd(pi, km.iob.fd, TRUE);
}

private void MouseFini(KdPointerInfo* pi)
{
    free(pi.driverPrivate);
    pi.driverPrivate = null;
}

KdPointerDriver LinuxMouseDriver = {
    name: "mouse",
    Init: &MouseInit,
    Enable: &MouseEnable,
    Disable: &MouseDisable,
    Fini: &MouseFini,
};
