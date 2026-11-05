module lnx_acpi;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
import build.xorg_config;

import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.un;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import core.stdc.errno;

import os.log_priv;

import os.os;
import xf86_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import hw.xfree86.os_support.xf86_OSproc;;
import include.xf86Privstr;

import os.log;
import xf86Events;
import xf86Globals;
import os.WaitFor;
public import xf86PM;

enum ACPI_SOCKET =  "/var/run/acpid.socket";

enum ACPI_VIDEO_NOTIFY_SWITCH =	0x80;
enum ACPI_VIDEO_NOTIFY_PROBE =		0x81;
enum ACPI_VIDEO_NOTIFY_CYCLE =		0x82;
enum ACPI_VIDEO_NOTIFY_NEXT_OUTPUT =	0x83;
enum ACPI_VIDEO_NOTIFY_PREV_OUTPUT =	0x84;

enum ACPI_VIDEO_NOTIFY_CYCLE_BRIGHTNESS =	0x85;
enum	ACPI_VIDEO_NOTIFY_INC_BRIGHTNESS =	0x86;
enum ACPI_VIDEO_NOTIFY_DEC_BRIGHTNESS =	0x87;
enum ACPI_VIDEO_NOTIFY_ZERO_BRIGHTNESS =	0x88;
enum ACPI_VIDEO_NOTIFY_DISPLAY_OFF =		0x89;

enum ACPI_VIDEO_HEAD_INVALID =		(~0u - 1);
enum ACPI_VIDEO_HEAD_END =		(~0u);


private void* ACPIihPtr = null;


/* in milliseconds */
enum ACPI_REOPEN_DELAY = 1000;

private CARD32 lnxACPIReopen(OsTimerPtr timer, CARD32 time, void* arg)
{
    if (lnxACPIOpen()) {
        TimerFree(timer);
        return 0;
    }

    return ACPI_REOPEN_DELAY;
}

enum LINE_LENGTH = 80;

private int lnxACPIGetEventFromOs(int fd, pmEvent* events, int num)
{
    char[LINE_LENGTH] ev = void;
    int n = void;

    memset(ev.ptr, 0, LINE_LENGTH);

    do {
        n = cast(int)read(fd, ev.ptr, LINE_LENGTH);
    } while ((n == -1) && (errno == EAGAIN || errno == EINTR));

    if (n <= 0) {
        lnxCloseACPI();
        TimerSet(null, 0, ACPI_REOPEN_DELAY, &lnxACPIReopen, null);
        return 0;
    }
    /* FIXME: this only processes the first read ACPI event & might break
     * with interrupted reads. */

    /* Check that we have a video event */
    if (!strncmp(ev.ptr, "video", 5)) {
        char* GFX = null;
        char* notify = null;
        char* data = null;      /* doesn't appear to be used in the kernel */
        c_ulong notify_l = void;

        strtok(ev.ptr, " ");

        if (((GFX = strtok(null, " ")) is null))
            return 0;
version (none) {
        ErrorF("GFX: %s\n", GFX);
}

        if (((notify = strtok(null, " ")) is null))
            return 0;
        notify_l = strtoul(notify, null, 16);
version (none) {
        ErrorF("notify: 0x%lx\n", notify_l);
}

        if (((data = strtok(null, " ")) is null))
            return 0;
version (none) {
        data_l = strtoul(data, null, 16);
        ErrorF("data: 0x%lx\n", data_l);
}

        /* Differentiate between events */
        switch (notify_l) {
        case ACPI_VIDEO_NOTIFY_SWITCH:
        case ACPI_VIDEO_NOTIFY_CYCLE:
        case ACPI_VIDEO_NOTIFY_NEXT_OUTPUT:
        case ACPI_VIDEO_NOTIFY_PREV_OUTPUT:
            events[0] = XF86_APM_CAPABILITY_CHANGED;
            return 1;
        case ACPI_VIDEO_NOTIFY_PROBE:
            return 0;
        default:
            return 0;
        }
    }

    return 0;
}

private pmWait lnxACPIConfirmEventToOs(int fd, pmEvent event)
{
    /* No ability to send back to the kernel in ACPI */
    switch (event) {
    default:
        return PM_NONE;
    }
}

PMClose lnxACPIOpen()
{
    int fd = void;
    sockaddr_un addr = void;
    int r = -1;
    static int warned = 0;

    DebugF("ACPI: OSPMOpen called\n");
    if (ACPIihPtr || !xf86Info.pmFlag)
        return null;

    DebugF("ACPI: Opening device\n");
    if ((fd = socket(AF_UNIX, SOCK_STREAM, 0)) > -1) {
        memset(&addr, 0, addr.sizeof);
        addr.sun_family = AF_UNIX;
        strcpy(cast(char*)addr.sun_path.ptr, ACPI_SOCKET.ptr);
        if ((r = connect(fd, cast(sockaddr*) &addr, addr.sizeof)) == -1) {
            if (!warned)
                LogMessageVerb(X_WARNING, 3, "Open ACPI failed (%s) (%s)\n",
                            ACPI_SOCKET.ptr, strerror(errno));
            warned = 1;
            shutdown(fd, 2);
            close(fd);
            return null;
        }
    }

    xf86PMGetEventFromOs = &lnxACPIGetEventFromOs;
    xf86PMConfirmEventToOs = &lnxACPIConfirmEventToOs;
    ACPIihPtr = xf86AddGeneralHandler(fd, &xf86HandlePMEvents, null);
    LogMessageVerb(X_INFO, 3, "Open ACPI successful (%s)\n", ACPI_SOCKET.ptr);
    warned = 0;

    return &lnxCloseACPI;
}

void lnxCloseACPI()
{
    int fd = void;

    DebugF("ACPI: Closing device\n");
    if (ACPIihPtr) {
        fd = xf86RemoveGeneralHandler(ACPIihPtr);
        shutdown(fd, 2);
        close(fd);
        ACPIihPtr = null;
    }
}
