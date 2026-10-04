module hw.xfree.os_support.shrd.seatd_libseat;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2022-2024 Mark Hindley, Ralph Ronnquist.
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
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Authors: Mark Hindley <mark@hindley.org.uk>
 *          Ralph Ronnquist <ralph.ronnquist@gmail.com>
 */
import build.xorg_config;

import core.stdc.stdio;
import core.stdc.string;
import core.sys.posix.sys.types;
import core.sys.posix.unistd;
import core.stdc.errno;
import externs.libseat;

import include.os;
import include.xf86;
import xf86_priv;
static if(XSERVER_PLATFORM_BUS){
import xf86platformBus_priv;
import xf86platformBus;
}
import xf86Xinput;
import xf86Xinput_priv;
import include.xf86Priv;
import include.globals;

import config.hotplug_priv;

import seatd_libseat;

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
import hw.xfree86.os_support.linux.systemd_logind;
import seatd_libseat;

// import xf86VGAarbiter_priv;
import hw.xfree86.loader.loaderProcs;

import xf86Module_priv;
import xf86_priv;
import include.xf86Priv;
import xf86Config;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;
import xf86cmap;
import mi.mipointer;
import xf86Extensions;
import xf86Xinput;
// import xf86InPriv;
import include.xf86Crtc;
import include.picturestr;
import xf86Bus;
import include.globals;
import include.xserver_properties;
import os.log;
import externs.attrs;
import xf86Globals;
import dix.property;
import xf86AutoConfig_;
import externs.X11.Xatom;
import xf86VGAarbiter;
import xf86Option;
import core.sys.posix.unistd;
import xf86Events;
import core.stdc.stdlib;
import core.stdc.errno;
import core.sys.posix.sys.stat;
import core.sys.linux.fcntl;
import include.optionstr;
import os.xserver_poll;
import core.sys.posix.poll;
import os.connection;

/* ============ libseat client adapter ====================== */

struct libseat_info {
    char* session;
    Bool active;
    Bool vt_active;
    /*
     * This pointer gets initialised to the actual libseat client instance
     * provided by assumeNoGC(&libseat_open_seat).
     */
    libseat* client;
    int graphics_id;
}
private libseat_info seat_info;

/*
 * The seat has been enabled, and is now valid for use. Re-open all
 * seat devices to ensure that they are operational, as existing fds
 * may have had their functionality blocked or revoked.
 */
private void enable_seat(libseat* seat, void* userdata)
{
    InputInfoPtr pInfo = void;
    cast(void) userdata;
    LogMessage(X_INFO, "seatd_libseat enable\n");
    seat_info.active = TRUE;
    seat_info.vt_active = TRUE;

    xf86VTEnter();
    /* Reactivate all input devices */
    for (pInfo = xf86InputDevs; pInfo; pInfo = pInfo.next)
        if (pInfo.flags & XI86_SERVER_FD){
            if (xf86CheckIntOption(pInfo.options, "libseat_id", -1) >= 0){
                int fd = -1, paused = FALSE;
                seatd_libseat_open_device(pInfo, &fd, &paused);
                xf86EnableInputDeviceForVTSwitch(pInfo);
            }
        }
    xf86InputEnableVTProbe(); /* Add any paused input devices */
    static if(XSERVER_PLATFORM_BUS){
    xf86platformVTProbe(); /* Probe for outputs */
    }
}

/*
 * The seat has been disabled. This event signals that the application
 * is going to lose its seat access. The event *must* be acknowledged
 * with libseat_disable_seat shortly after receiving this event.
 *
 * If the recepient fails to acknowledge the event in time, seat
 * devices may be forcibly revoked by the seat provider.
 */
private void disable_seat(libseat* seat, void* userdata)
{
    cast(void) userdata;
    LogMessage(X_INFO, "seatd_libseat disable\n");
    xf86VTLeave();
    seat_info.vt_active = FALSE;
    if (assumeNoGC(&libseat_disable_seat)(seat)) {
        LogMessage(X_ERROR, "seatd_libseat disable failed: %d\n", errno);
    }
}

/*
 * Callbacks for handling the libseat events.
 */
private libseat_seat_listener client_callbacks = {
    enable_seat: &enable_seat,
    disable_seat: &disable_seat,
};

/*
 * Check libseat is initialised and active.
 */
private Bool libseat_active()
{
    if (!seat_info.client) {
        LogMessageVerb(X_DEBUG, 5, "seatd_libseat not initialised!\n");
        return FALSE;
    }
    if (!seat_info.active) {
        LogMessage(X_DEBUG, "seatd_libseat not active\n");
        return FALSE;
    }
    return TRUE;
}

/*
 * Handle libseat events
 */
private int libseat_handle_events(int timeout)
{
    int ret = void;

    while ((ret = assumeNoGC(&libseat_dispatch)(seat_info.client, timeout)) > 0)
        LogMessage(X_INFO, "seatd_libseat handled %i events\n", ret);
    if (ret == -1) {
        LogMessage(X_ERROR, "assumeNoGC(&libseat_dispatch)() failed: %s\n", strerror(errno));
        return -1;
    }
    return ret;
}

private void event_handler(int fd, int ready, void* data)
{
    LogMessage(X_INFO, "seatd_libseat event handler\n");
    libseat_handle_events(0);
}

/*
 * Handle libseat logging.
 */
static void
log_libseat(libseat_log_level level, const char *fmt, va_list args)
{
    MessageType xmt;
    size_t xfmt_size = strlen(fmt) + 2;
    char* xfmt;

    xfmt = cast(char*) malloc(xfmt_size);
    if (xfmt is null)
        return;
    snprintf(xfmt, xfmt_size, "%s\n", fmt);

    switch (level) {
    case LIBSEAT_LOG_LEVEL_INFO:
        xmt = X_INFO;
        break;
    case LIBSEAT_LOG_LEVEL_ERROR:
        xmt = X_ERROR;
        break;
    default:
        xmt = X_DEBUG;
    }
    LogVMessageVerb(xmt, 0, xfmt, args);

    free(xfmt);
}

/* ============== seatd-libseat.h API functions ============= */

/*
 * Initialise the libseat client.
 *
 * @param KeepTty_state - the KeepTty parameter value
 *
 * Returns:
 *   0 if all ok
 *   1 if not possible
 *   -EPERM (-1) if it was already initialised
 *   -EPIPE (-32) if the seat opening failed.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int seatd_libseat_init(Bool KeepTty_state)
{
    if (!mixin(ServerIsNotSeat0!()) && xf86HasTTYs() && !KeepTty_state) {
        LogMessage(X_WARNING,
            "seat-libseat: libseat integration requires -keeptty which "
            ~ "was not provided, disabling\n");
        return 1;
    }

    assumeNoGC(&libseat_set_log_level)(LIBSEAT_LOG_LEVEL_DEBUG);
    assumeNoGC(&libseat_set_log_handler)(cast(libseat_log_func)&log_libseat);
    LogMessage(X_INFO, "seatd_libseat init\n");
    if (assumeNoGC(&libseat_active)()) {
        LogMessage(X_ERROR, "seatd_libseat already initialised\n");
        return -EPERM;
    }
    seat_info.graphics_id = -1;
    seat_info.client = assumeNoGC(&libseat_open_seat)(&client_callbacks, null);
    if (!seat_info.client) {
        LogMessage(X_ERROR, "Cannot set up seatd_libseat client\n");
        return -EPIPE;
    }
    SetNotifyFd(assumeNoGC(&libseat_get_fd)(seat_info.client), &event_handler, X_NOTIFY_READ, null);

    if (assumeNoGC(&libseat_handle_events)(100) < 0) {
        assumeNoGC(&libseat_close_seat)(seat_info.client);
        return -EPIPE;
    }
    LogMessage(X_INFO, "seatd_libseat client activated\n");
    return 0;
}

/*
 * Shutdown the libseat client.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void seatd_libseat_fini()
{
    if (seat_info.client) {
        LogMessage(X_INFO, "seatd_libseat finish\n");
        assumeNoGC(&libseat_close_seat)(seat_info.client);
    }
    seat_info.graphics_id = -1;
    seat_info.active = FALSE;
    seat_info.client = null;
}

/*
 * Open the graphics device
 *
 * Return
 *   file descriptor (>=0) if all is ok.
 *   -EPERM (-1) if the libseat client is not activated
 *   -EAGAIN (-11) if the VT is not active
 *   -errno from libseat_open_device if device access failed
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int seatd_libseat_open_graphics(const(char)* path)
{
    int fd = void, id = void;

    if (!assumeNoGC(&libseat_active)()) {
        return -EPERM;
    }
    LogMessage(X_INFO, "seatd_libseat try open graphics %s\n", path);
    if ((id = assumeNoGC(&libseat_open_device)(seat_info.client, path, &fd)) == -1) {
        fd = -errno;
        LogMessage(X_ERROR, "seatd_libseat open graphics %s (%d) failed: %d\n",
                   path, id, fd);
    }
    else {
        LogMessage(X_INFO, "seatd_libseat opened graphics: %s (%d:%d)\n", path,
                   id, fd);
    }
    seat_info.graphics_id = id;
    return fd;
}

/*
 * Find duplicate devices with same major:minor number and assigned
 * "libseat_id" and, if any, return its file descriptor.
 */
private int check_duplicate_device(int maj, int min) {

    InputInfoPtr pInfo = void;

    for (pInfo = xf86InputDevs; pInfo; pInfo = pInfo.next) {
        if (pInfo.major == maj && pInfo.minor == min &&
            xf86CheckIntOption(pInfo.options, "libseat_id", -1) >= 0) {
            return pInfo.fd;
        }
    }
    return -1;
}

/*
 * Open an input device.
 *
 * The function sets the p->options "libseat_id" for the device when
 * successful.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void seatd_libseat_open_device(InputInfoPtr p, int* pfd, Bool* paused)
{
    int id = -1, fd = -1;
    char* path = xf86CheckStrOption(p.options, "Device", null);

    if (!assumeNoGC(&libseat_active)()) {
        return;
    }
    if (!seat_info.vt_active) {
        *pfd = -2; /* Invalid, but not -1. See xf86NewInputDevice() */
        *paused = TRUE;
        LogMessage(X_INFO, "seatd_libseat paused %s\n", path);
        return;
    }
    fd = check_duplicate_device(p.major,p.minor);
    if (fd < 0) {
        LogMessage(X_INFO, "seatd_libseat try open %s\n", path);
        if ((id = assumeNoGC(&libseat_open_device)(seat_info.client, path, &fd)) == -1) {
            fd = -errno;
            LogMessage(X_ERROR, "seatd_libseat open %s (%d) failed: %d\n",
                       path, id, fd);
            return;
        }
    }
    else {
        LogMessage(X_INFO, "seatd_libseat reuse %d for %s\n", fd, path);
    }
    p.flags |= XI86_SERVER_FD;
    p.fd = fd;
    p.options = xf86ReplaceIntOption(p.options, "fd", fd);
    p.options = xf86ReplaceIntOption(p.options, "libseat_id", id);
    LogMessage(X_INFO, "seatd_libseat opened %s (%d:%d)\n", path, id, fd);
}

/*
 * Release an input device.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void seatd_libseat_close_device(InputInfoPtr p)
{
    char* path = xf86CheckStrOption(p.options, "Device", null);
    int fd = xf86CheckIntOption(p.options, "fd", -1);
    int id = xf86CheckIntOption(p.options, "libseat_id", -1);

    if (!assumeNoGC(&libseat_active)())
        return;
    LogMessage(X_INFO, "seatd_libseat try close %s (%d:%d)\n", path, id, fd);
    if (fd < 0) {
        LogMessage(X_ERROR, "seatd_libseat device not open (%s)\n", path);
        return;
    }
    if (id < 0) {
        LogMessage(X_ERROR, "seatd_libseat no libseat ID\n");
        return;
    }
    if (assumeNoGC(&libseat_close_device)(seat_info.client, id)) {
        LogMessage(X_ERROR, "seatd_libseat close failed %d\n", -errno);
    }
    else {
        close(fd);
        p.fd = -1;
        p.options = xf86ReplaceIntOption(p.options, "fd", -1);
    }
}

/*
 * Libseat controls session
 */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool seatd_libseat_controls_session(){
    return assumeNoGC(&libseat_active)();
}

/*
 * Switch VT
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int seatd_libseat_switch_session(int session)
{
    int ret = 0;

    LogMessage(X_INFO, "seatd_libseat switch VT %d\n", session);
    if ((ret = assumeNoGC(&libseat_switch_session)(seat_info.client, session)) < 0) {
        LogMessage(X_ERROR, "seatd_libseat switch VT failed with %d\n", -errno);
        goto ret;
    }
 ret:
    return ret;
}
