module lnx_apm;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

//import x11.X;

import os.log_priv;

import include.os;
import xf86_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSproc;;

static if (HAVE_ACPI) {
PMClose lnxACPIOpen();
}

version (HAVE_APM) {

import linux.apm_bios;
import core.sys.posix.unistd;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;
import core.stdc.errno;

enum APM_PROC =   "/proc/apm";
enum APM_DEVICE = "/dev/apm_bios";

enum APM_STANDBY_FAILED = 0xf000;

enum APM_SUSPEND_FAILED = 0xf001;




private void* APMihPtr = null;

struct _LinuxToXF86 {
    apm_event_t apmLinux;
    pmEvent xf86;
}

private _LinuxToXF86[14] LinuxToXF86;
//  = [
//     {APM_SYS_STANDBY, XF86_APM_SYS_STANDBY},
//     {APM_SYS_SUSPEND, XF86_APM_SYS_SUSPEND},
//     {APM_NORMAL_RESUME, XF86_APM_NORMAL_RESUME},
//     {APM_CRITICAL_RESUME, XF86_APM_CRITICAL_RESUME},
//     {APM_LOW_BATTERY, XF86_APM_LOW_BATTERY},
//     {APM_POWER_STATUS_CHANGE, XF86_APM_POWER_STATUS_CHANGE},
//     {APM_UPDATE_TIME, XF86_APM_UPDATE_TIME},
//     {APM_CRITICAL_SUSPEND, XF86_APM_CRITICAL_SUSPEND},
//     {APM_USER_STANDBY, XF86_APM_USER_STANDBY},
//     {APM_USER_SUSPEND, XF86_APM_USER_SUSPEND},
//     {APM_STANDBY_RESUME, XF86_APM_STANDBY_RESUME},
// #if defined(APM_CAPABILITY_CHANGED)
//     {APM_CAPABILITY_CHANGED, XF86_CAPABILITY_CHANGED},
// #endif
// #if 0
//     {APM_STANDBY_FAILED, XF86_APM_STANDBY_FAILED},
//     {APM_SUSPEND_FAILED, XF86_APM_SUSPEND_FAILED}
// #endif
// ];

static this() {
    linuxToXF86 = [
        _LinuxToXF86(APM_SYS_STANDBY, XF86_APM_SYS_STANDBY),
        _LinuxToXF86(APM_SYS_SUSPEND, XF86_APM_SYS_SUSPEND),
        _LinuxToXF86(APM_NORMAL_RESUME, XF86_APM_NORMAL_RESUME),
        _LinuxToXF86(APM_CRITICAL_RESUME, XF86_APM_CRITICAL_RESUME),
        _LinuxToXF86(APM_LOW_BATTERY, XF86_APM_LOW_BATTERY),
        _LinuxToXF86(APM_POWER_STATUS_CHANGE, XF86_APM_POWER_STATUS_CHANGE),
        _LinuxToXF86(APM_UPDATE_TIME, XF86_APM_UPDATE_TIME),
        _LinuxToXF86(APM_CRITICAL_SUSPEND, XF86_APM_CRITICAL_SUSPEND),
        _LinuxToXF86(APM_USER_STANDBY, XF86_APM_USER_STANDBY),
        _LinuxToXF86(APM_USER_SUSPEND, XF86_APM_USER_SUSPEND),
        _LinuxToXF86(APM_STANDBY_RESUME, XF86_APM_STANDBY_RESUME)
// #if defined(APM_CAPABILITY_CHANGED)
//     {APM_CAPABILITY_CH  ANGED, XF86_CAPABILITY_CHANGED},
// #endif
// #if 0
//     {APM_STANDBY_FAILED, XF86_APM_STANDBY_FAILED},
//     {APM_SUSPEND_FAILED, XF86_APM_SUSPEND_FAILED}
// #endif
    ];
    static if(APM_CAPABILITY_CHANGED) 
    {
        LinuxToXF86[11] = _LinuxToXF86(ANGED, XF86_CAPABILITY_CHANGED);
    }
}

/*
 * APM is still under construction.
 * I'm not sure if the places where I initialize/deinitialize
 * apm is correct. Also I don't know what to do in SETUP state.
 * This depends if wakeup gets called in this situation, too.
 * Also we need to check if the action that is taken on an
 * event is reasonable.
 */
private int lnxPMGetEventFromOs(int fd, pmEvent* events, int num)
{
    int i = void, j = void, n = void;
    apm_event_t[8] linuxEvents = void;

    if ((n = read(fd, linuxEvents.ptr, num * apm_event_t.sizeof)) == -1)
        return 0;
    n /= apm_event_t.sizeof;
    if (n > num)
        n = num;
    for (i = 0; i < n; i++) {
        for (j = 0; j < LinuxToXF86.length; j++)
            if (LinuxToXF86[j].apmLinux == linuxEvents[i]) {
                events[i] = LinuxToXF86[j].xf86;
                break;
            }
        if (j == LinuxToXF86.length)
            events[i] = XF86_APM_UNKNOWN;
    }
    return n;
}

private pmWait lnxPMConfirmEventToOs(int fd, pmEvent event)
{
    switch (event) {
    case XF86_APM_SYS_STANDBY:
    case XF86_APM_USER_STANDBY:
        if (ioctl(fd, APM_IOC_STANDBY, null))
            return PM_FAILED;
        return PM_CONTINUE;
    case XF86_APM_SYS_SUSPEND:
    case XF86_APM_CRITICAL_SUSPEND:
    case XF86_APM_USER_SUSPEND:
        if (ioctl(fd, APM_IOC_SUSPEND, null)) {
            /* I believe this is wrong (EE)
               EBUSY is sent when a device refuses to be suspended.
               In this case we still need to undo everything we have
               done to suspend ourselves or we will stay in suspended
               state forever. */
            if (errno == EBUSY)
                return PM_CONTINUE;
            else
                return PM_FAILED;
        }
        return PM_CONTINUE;
    case XF86_APM_STANDBY_RESUME:
    case XF86_APM_NORMAL_RESUME:
    case XF86_APM_CRITICAL_RESUME:
    case XF86_APM_STANDBY_FAILED:
    case XF86_APM_SUSPEND_FAILED:
        return PM_CONTINUE;
    default:
        return PM_NONE;
    }
}

}                          // HAVE_APM

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
PMClose xf86OSPMOpen()
{
    PMClose ret = null;

static if (HAVE_ACPI) {
    /* Favour ACPI over APM, but only when enabled */

    if (!xf86acpiDisableFlag) {
        ret = lnxACPIOpen();
        if (ret)
            return ret;
    }
}
version (HAVE_APM) {
    ret = lnxAPMOpen();
}

    return ret;
}

version (HAVE_APM) {

private PMClose lnxAPMOpen()
{
    int fd = void, pfd = void;

    DebugF("APM: OSPMOpen called\n");
    if (APMihPtr || !xf86Info.pmFlag)
        return null;

    DebugF("APM: Opening device\n");
    if ((fd = open(APM_DEVICE, O_RDWR)) > -1) {
        if (access(APM_PROC, R_OK) || ((pfd = open(APM_PROC, O_RDONLY)) == -1)) {
            LogMessageVerb(X_WARNING, 3, "Cannot open APM (%s) (%s)\n",
                        APM_PROC, strerror(errno));
            close(fd);
            return null;
        }
        else
            close(pfd);
        xf86PMGetEventFromOs = lnxPMGetEventFromOs;
        xf86PMConfirmEventToOs = lnxPMConfirmEventToOs;
        APMihPtr = xf86AddGeneralHandler(fd, xf86HandlePMEvents, null);
        LogMessageVerb(X_INFO, 3, "Open APM successful\n");
        return lnxCloseAPM;
    }
    return null;
}

private void lnxCloseAPM()
{
    int fd = void;

    DebugF("APM: Closing device\n");
    if (APMihPtr) {
        fd = xf86RemoveGeneralHandler(APMihPtr);
        close(fd);
        APMihPtr = null;
    }
}

}                          // HAVE_APM
