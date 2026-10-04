module hw.xfree86.os_support.linux.systemd_logind;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Red Hat Inc.
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
 * Author: Hans de Goede <hdegoede@redhat.com>
 */
// import build.xorg_config;

import externs.libdbus;
// import core.stdc.string;
// import core.sys.posix.sys.types;
import core.sys.posix.unistd;

import config.dbus_core;
// import config.hotplug_priv;

// import include.os;
// import hw.xfree.os_support.linux.linux;
// import hw.xfree86.os_support.xf86_os_support;
// import xf86_priv;
// // import xf86platformBus_priv;
// import xf86Xinput_priv;
// import include.xf86Priv;
// import include.globals;
// import core.sys.posix.sys.ioctl;
// import core.sys.posix.sys.types;
// import core.sys.posix.sys.socket;
// import core.sys.posix.sys.un;
// import core.sys.posix.unistd;
// import core.sys.posix.fcntl;
// import core.stdc.errno;

// import os.log_priv;

// import include.os;
// import xf86_priv;
// import include.xf86Priv;
// import hw.xfree86.os_support.xf86_os_support;
// import include.xf86_OSproc;;
// import include.xf86Privstr;

// import os.log;
import xf86Events;
import xf86Globals;
// import externs.sys.sysmacros;;
// import os.utils;
import xf86Option;
// import config.libhal;
import include.misc;
import externs.libdbus;
import core.sys.posix.sys.select;
import include.xf86Xinput;
import config.hotplug_priv;


import os.log_priv;

import include.dix;
import include.os;

// import config.dbus_core;
import externs.attrs;
import os.log;
import config.libhal;
import os.connection;
import include.xf86;
import xf86Xinput;
import xf86Init;
import xf86platformBus_priv;
import lnx_init;


alias FALSE = include.misc.FALSE;
alias TRUE = include.misc.TRUE;

import externs.attrs;;
import xf86platformBus;


static if(SYSTEMD_LOGIND) {
    // / import systemd_logind;

struct systemd_logind_info {
    DBusConnection* conn;
    char* session;
    Bool active;
    Bool vt_active;
}

private systemd_logind_info logind_info;

private InputInfoPtr systemd_logind_find_info_ptr_by_devnum(InputInfoPtr start, int major, int minor)
{
    InputInfoPtr pInfo = void;

    for (pInfo = start; pInfo; pInfo = pInfo.next)
        if (pInfo.major == major && pInfo.minor == minor &&
                (pInfo.flags & XI86_SERVER_FD))
            return pInfo;

    return null;
}

private void systemd_logind_set_input_fd_for_all_devs(int major, int minor, int fd, Bool enable)
{
    InputInfoPtr pInfo = void;

    pInfo = systemd_logind_find_info_ptr_by_devnum(xf86InputDevs, major, minor);
    while (pInfo) {
        pInfo.fd = fd;
        pInfo.options = xf86ReplaceIntOption(pInfo.options, "fd", fd);
        if (enable)
            xf86EnableInputDeviceForVTSwitch(pInfo);

        pInfo = systemd_logind_find_info_ptr_by_devnum(pInfo.next, major, minor);
    }
}

int systemd_logind_take_fd(int _major, int _minor, const(char)* path, Bool* paused_ret)
{
    systemd_logind_info* info = &logind_info;
    InputInfoPtr pInfo = void;
    DBusError error = void;
    DBusMessage* msg = null;
    DBusMessage* reply = null;
    dbus_int32_t major = _major;
    dbus_int32_t minor = _minor;
    dbus_bool_t paused = void;
    int fd = -1;

    if (!info.session || major == 0)
        return -1;

    /* logind does not support mouse devs (with evdev we don't need them) */
    if (strstr(path, "mouse"))
        return -1;

    /* Check if we already have an InputInfo entry with this major, minor
     * (shared device-nodes happen ie with Wacom tablets). */
    pInfo = systemd_logind_find_info_ptr_by_devnum(xf86InputDevs, major, minor);
    if (pInfo) {
        LogMessage(X_INFO, "systemd-logind: returning pre-existing fd for %s %u:%u\n",
               path, major, minor);
        *paused_ret = FALSE;
        return pInfo.fd;
    }

    resolve!"dbus_error_init"()(&error);

    msg = assumeNoGC(&dbus_message_new_method_call)("org.freedesktop.login1", info.session,
            "org.freedesktop.login1.Session", "TakeDevice");
    if (!msg) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    if (!assumeNoGC(&dbus_message_append_args)(msg, DBUS_TYPE_UINT32, &major,
                                       DBUS_TYPE_UINT32, &minor,
                                       )) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    reply = assumeNoGC(&dbus_connection_send_with_reply_and_block)(info.conn, msg,
                                                      DBUS_TIMEOUT_USE_DEFAULT, &error);
    if (!reply) {
        LogMessage(X_ERROR, "systemd-logind: failed to take device %s: %s\n",
                   path, error.message);
        goto cleanup;
    }

    if (!dbus_message_get_args_d(reply, &error,
                               DBUS_TYPE_UNIX_FD, &fd,
                               DBUS_TYPE_BOOLEAN, &paused
                               )) {
        LogMessage(X_ERROR, "systemd-logind: TakeDevice %s: %s\n",
                   path, error.message);
        goto cleanup;
    }

    *paused_ret = paused;

    LogMessage(X_INFO, "systemd-logind: got fd for %s %u:%u fd %d paused %d\n",
               path, major, minor, fd, paused);

cleanup:
    if (msg)
        assumeNoGC(&dbus_message_unref)(msg);
    if (reply)
        assumeNoGC(&dbus_message_unref)(reply);
    resolve!"dbus_error_free"()(&error);

    return fd;
}

void systemd_logind_release_fd(int _major, int _minor, int fd)
{
    systemd_logind_info* info = &logind_info;
    InputInfoPtr pInfo = void;
    DBusError error = void;
    DBusMessage* msg = null;
    DBusMessage* reply = null;
    dbus_int32_t major = _major;
    dbus_int32_t minor = _minor;
    int matches = 0;

    if (!info.session || major == 0)
        goto close;

    /* Only release the fd if there is only 1 InputInfo left for this major
     * and minor, otherwise other InputInfo's are still referencing the fd. */
    pInfo = systemd_logind_find_info_ptr_by_devnum(xf86InputDevs, major, minor);
    while (pInfo) {
        matches++;
        pInfo = systemd_logind_find_info_ptr_by_devnum(pInfo.next, major, minor);
    }
    if (matches > 1) {
        LogMessage(X_INFO, "systemd-logind: not releasing fd for %u:%u, still in use\n", major, minor);
        return;
    }

    LogMessage(X_INFO, "systemd-logind: releasing fd for %u:%u\n", major, minor);

    resolve!"dbus_error_init"()(&error);

    msg = assumeNoGC(&dbus_message_new_method_call)("org.freedesktop.login1", info.session,
            "org.freedesktop.login1.Session", "ReleaseDevice");
    if (!msg) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    if (!assumeNoGC(&dbus_message_append_args)(msg, DBUS_TYPE_UINT32, &major,
                                       DBUS_TYPE_UINT32, &minor,
                                       )) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    reply = assumeNoGC(&dbus_connection_send_with_reply_and_block)(info.conn, msg,
                                                      DBUS_TIMEOUT_USE_DEFAULT, &error);
    if (!reply)
        LogMessage(X_ERROR, "systemd-logind: failed to release device: %s\n",
                   error.message);

cleanup:
    if (msg)
        assumeNoGC(&dbus_message_unref)(msg);
    if (reply)
        assumeNoGC(&dbus_message_unref)(reply);
    resolve!"dbus_error_free"()(&error);
close:
    if (fd != -1)
        close(fd);
}

int systemd_logind_controls_session()
{
    return logind_info.session ? 1 : 0;
}

void systemd_logind_vtenter()
{
    systemd_logind_info* info = &logind_info;
    InputInfoPtr pInfo = void;
    int i = void;

    if (!info.session)
        return; /* Not using systemd-logind */

    if (!info.active)
        return; /* Session not active */

    if (info.vt_active)
        return; /* Already did vtenter */

    for (i = 0; i < xf86_num_platform_devices; i++) {
        if (xf86_platform_devices[i].flags & XF86_PDEV_PAUSED)
            break;
    }
    if (i != xf86_num_platform_devices)
        return; /* Some drm nodes are still paused wait for resume */

    xf86VTEnter();
    info.vt_active = TRUE;

    /* Activate any input devices which were resumed before the drm nodes */
    for (pInfo = xf86InputDevs; pInfo; pInfo = pInfo.next)
        if ((pInfo.flags & XI86_SERVER_FD) && pInfo.fd != -1)
            xf86EnableInputDeviceForVTSwitch(pInfo);

    /* Do delayed input probing, this must be done after the above enabling */
    xf86InputEnableVTProbe();
}

private void systemd_logind_ack_pause(systemd_logind_info* info, dbus_int32_t minor, dbus_int32_t major)
{
    DBusError error = void;
    DBusMessage* msg = null;
    DBusMessage* reply = null;

    resolve!"dbus_error_init"()(&error);

    msg = assumeNoGC(&dbus_message_new_method_call)("org.freedesktop.login1", info.session,
            "org.freedesktop.login1.Session", "PauseDeviceComplete");
    if (!msg) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    if (!assumeNoGC(&dbus_message_append_args)(msg, DBUS_TYPE_UINT32, &major,
                                       DBUS_TYPE_UINT32, &minor,
                                       )) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    reply = assumeNoGC(&dbus_connection_send_with_reply_and_block)(info.conn, msg,
                                                      DBUS_TIMEOUT_USE_DEFAULT, &error);
    if (!reply)
        LogMessage(X_ERROR, "systemd-logind: failed to ack pause: %s\n",
                   error.message);

cleanup:
    if (msg)
        assumeNoGC(&dbus_message_unref)(msg);
    if (reply)
        assumeNoGC(&dbus_message_unref)(reply);
    resolve!"dbus_error_free"()(&error);
}

/*
 * Send a message to logind, to pause the drm device
 * and ensure the drm_drop_master is done before
 * VT_RELDISP when switching VT
 */
void systemd_logind_drop_master()
{
    systemd_logind_info* info = &logind_info;
    int i = void;
    /* Our VT_PROCESS usage guarantees we've already given up the vt */
    info.active = info.vt_active = FALSE;
    for (i = 0; i < xf86_num_platform_devices; i++) {
        if (xf86_platform_devices[i].flags & XF86_PDEV_SERVER_FD) {
            dbus_int32_t major = void, minor = void;

            xf86_platform_devices[i].flags |= XF86_PDEV_PAUSED;
            major = xf86_platform_odev_attributes(i).major;
            minor = xf86_platform_odev_attributes(i).minor;
            LogMessage(X_INFO, "systemd-logind: drop master for %u:%u\n",
               major, minor);
            systemd_logind_ack_pause(info, minor, major);
        }
    }
}

private Bool are_platform_devices_resumed() {
    int i = void;
    for (i = 0; i < xf86_num_platform_devices; i++) {
        if (xf86_platform_devices[i].flags & XF86_PDEV_PAUSED) {
            return FALSE;
        }
    }
    return TRUE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private DBusHandlerResult message_filter(DBusConnection* connection, DBusMessage* message, void* data)
{
    systemd_logind_info* info = cast(systemd_logind_info*)data;
    xf86_platform_device* pdev = null;
    InputInfoPtr pInfo = null;
    int ack = 0, pause = 0, fd = -1;
    DBusError error = void;
    dbus_int32_t major = void, minor = void;
    char* pause_str = void;

    if (strcmp(assumeNoGC(&dbus_message_get_path)(message), info.session) != 0)
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    resolve!"dbus_error_init"()(&error);

    if (assumeNoGC(&dbus_message_is_signal)(message, "org.freedesktop.login1.Session",
                               "PauseDevice")) {
        if (!dbus_message_get_args_d(message, &error,
                               DBUS_TYPE_UINT32, &major,
                               DBUS_TYPE_UINT32, &minor,
                               DBUS_TYPE_STRING, &pause_str,
                               )) {
            LogMessage(X_ERROR, "systemd-logind: PauseDevice: %s\n",
                       error.message);
            resolve!"dbus_error_free"()(&error);
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        }

        if (strcmp(pause_str, "pause") == 0) {
            pause = 1;
            ack = 1;
        }
        else if (strcmp(pause_str, "force") == 0) {
            pause = 1;
        }
        else if (strcmp(pause_str, "gone") == 0) {
            /* Device removal is handled through udev */
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        }
        else {
            LogMessage(X_WARNING, "systemd-logind: unknown pause type: %s\n",
                       pause_str);
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        }
    }
    else if (assumeNoGC(&dbus_message_is_signal)(message, "org.freedesktop.login1.Session",
                                    "ResumeDevice")) {
        if (!dbus_message_get_args_d(message, &error,
                                   DBUS_TYPE_UINT32, &major,
                                   DBUS_TYPE_UINT32, &minor,
                                   DBUS_TYPE_UNIX_FD, &fd,
                                   )) {
            LogMessage(X_ERROR, "systemd-logind: ResumeDevice: %s\n",
                       error.message);
            resolve!"dbus_error_free"()(&error);
            return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
        }

        /*
         * fd will be received via DBus if and only if pause == 0, so it
         * only needs to be closed in that code path
         */
    } else
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    LogMessage(X_INFO, "systemd-logind: got %s for %u:%u\n",
               pause ? "pause".ptr : "resume".ptr, major, minor);

    pdev = cast(include.xf86platformBus.xf86_platform_device*)xf86_find_platform_device_by_devnum(major, minor);
    if (!pdev)
        pInfo = systemd_logind_find_info_ptr_by_devnum(xf86InputDevs,
                                                       major, minor);
    if (!pdev && !pInfo) {
        LogMessage(X_WARNING, "systemd-logind: could not find dev %u:%u\n",
                   major, minor);
        return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
    }

    if (pause) {
        /* Our VT_PROCESS usage guarantees we've already given up the vt */
        info.active = info.vt_active = FALSE;
        /* Note the actual vtleave has already been handled by xf86Events.c */
        if (pdev)
            pdev.flags |= XF86_PDEV_PAUSED;
        else {
            close(pInfo.fd);
            systemd_logind_set_input_fd_for_all_devs(major, minor, -1, FALSE);
        }
        if (ack)
            systemd_logind_ack_pause(info, major, minor);
    }
    else {
        /* info->vt_active gets set by systemd_logind_vtenter() */
        info.active = TRUE;

        if (pdev) {
            close(fd);
            pdev.flags &= ~XF86_PDEV_PAUSED;
        } else
            systemd_logind_set_input_fd_for_all_devs(major, minor, fd,
                                                     info.vt_active);
        /* Call vtenter if all platform devices are resumed, or if there are no platform device */
        if (are_platform_devices_resumed())
            systemd_logind_vtenter();
    }
    return DBUS_HANDLER_RESULT_HANDLED;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void connect_hook(DBusConnection* connection, void* data)
{
    const(char)* session_type = "X11";
    systemd_logind_info* info = cast(systemd_logind_info*)data;
    DBusError error = void;
    DBusMessage* msg = null;
    DBusMessage* reply = null;
    dbus_int32_t arg = void;
    char* session = null;

    resolve!"dbus_error_init"()(&error);

    msg = assumeNoGC(&dbus_message_new_method_call)("org.freedesktop.login1",
            "/org/freedesktop/login1", "org.freedesktop.login1.Manager",
            "GetSessionByPID");
    if (!msg) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    arg = getpid();
    if (!assumeNoGC(&dbus_message_append_args)(msg, DBUS_TYPE_UINT32, &arg,
                                  )) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    reply = assumeNoGC(&dbus_connection_send_with_reply_and_block)(connection, msg,
                                                      DBUS_TIMEOUT_USE_DEFAULT, &error);
    if (!reply) {
        LogMessage(X_ERROR, "systemd-logind: failed to get session: %s\n",
                   error.message);
        goto cleanup;
    }
    assumeNoGC(&dbus_message_unref)(msg);

    if (!dbus_message_get_args_d(reply, &error, DBUS_TYPE_OBJECT_PATH, &session,
    )) {
        LogMessage(X_ERROR, "systemd-logind: GetSessionByPID: %s\n",
                   error.message);
        goto cleanup;
    }
    session = strdup(session);
    if (!session) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    assumeNoGC(&dbus_message_unref)(reply);
    reply = null;


    msg = assumeNoGC(&dbus_message_new_method_call)("org.freedesktop.login1",
            session, "org.freedesktop.login1.Session", "TakeControl");
    if (!msg) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    arg = FALSE; /* Don't forcibly take over over the session */
    if (!assumeNoGC(&dbus_message_append_args)(msg, DBUS_TYPE_BOOLEAN, &arg,
                                  )) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    reply = assumeNoGC(&dbus_connection_send_with_reply_and_block)(connection, msg,
                                                      DBUS_TIMEOUT_USE_DEFAULT, &error);
    if (!reply) {
        LogMessage(X_ERROR, "systemd-logind: TakeControl failed: %s\n",
                   error.message);
        goto cleanup;
    }
    assumeNoGC(&dbus_message_unref)(msg);
    assumeNoGC(&dbus_message_unref)(reply);
    reply = null;

    msg = assumeNoGC(&dbus_message_new_method_call)("org.freedesktop.login1",
            session, "org.freedesktop.login1.Session", "SetType");
    if (!msg) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    if (!assumeNoGC(&dbus_message_append_args)(msg, DBUS_TYPE_STRING, &session_type,
                                  )) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    reply = assumeNoGC(&dbus_connection_send_with_reply_and_block)(connection, msg,
                                                      DBUS_TIMEOUT_USE_DEFAULT, &error);
    /* Requires systemd >= 246, SetType() is not critical for xserver function */
    if (!reply) {
        /* unprevileged users get access denied rather than unknown method */
        if (!assumeNoGC(&dbus_error_has_name)(&error, DBUS_ERROR_ACCESS_DENIED) &&
            !assumeNoGC(&dbus_error_has_name)(&error, DBUS_ERROR_UNKNOWN_METHOD))
            LogMessage(X_WARNING, "systemd-logind: SetType failed: %s\n", error.message);
        resolve!"dbus_error_free"()(&error);
    }

    assumeNoGC(&dbus_bus_add_match)(connection,
        "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Session',member='PauseDevice'",
        &error);
    if (assumeNoGC(&dbus_error_is_set)(&error)) {
        LogMessage(X_ERROR, "systemd-logind: could not add match: %s\n",
                   error.message);
        goto cleanup;
    }

    assumeNoGC(&dbus_bus_add_match)(connection,
        "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.login1.Session',member='ResumeDevice'",
        &error);
    if (assumeNoGC(&dbus_error_is_set)(&error)) {
        LogMessage(X_ERROR, "systemd-logind: could not add match: %s\n",
                   error.message);
        goto cleanup;
    }

    /*
     * HdG: This is not useful with systemd <= 208 since the signal only
     * contains invalidated property names there, rather than property, val
     * pairs as it should.  Instead we just use the first resume / pause now.
     */
version (none) {
    snprintf(match, match.sizeof,
        "type='signal',sender='org.freedesktop.login1',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged',path='%s'",
        session);
    assumeNoGC(&dbus_bus_add_match)(connection, match, &error);
    if (assumeNoGC(&dbus_error_is_set)(&error)) {
        LogMessage(X_ERROR, "systemd-logind: could not add match: %s\n",
                   error.message);
        goto cleanup;
    }
}

    if (!assumeNoGC(&dbus_connection_add_filter)(connection, &message_filter, info, null)) {
        LogMessage(X_ERROR, "systemd-logind: could not add filter: %s\n",
                   error.message);
        goto cleanup;
    }

    LogMessage(X_INFO, "systemd-logind: took control of session %s\n",
               session);
    info.conn = connection;
    info.session = session;
    info.vt_active = info.active = TRUE; /* The server owns the vt during init */
    session = null;

cleanup:
    free(session);
    if (msg)
        assumeNoGC(&dbus_message_unref)(msg);
    if (reply)
        assumeNoGC(&dbus_message_unref)(reply);
    resolve!"dbus_error_free"()(&error);
}

private void systemd_logind_release_control(systemd_logind_info* info)
{
    DBusError error = void;
    DBusMessage* msg = null;
    DBusMessage* reply = null;

    resolve!"dbus_error_init"()(&error);

    msg = assumeNoGC(&dbus_message_new_method_call)("org.freedesktop.login1",
            info.session, "org.freedesktop.login1.Session", "ReleaseControl");
    if (!msg) {
        LogMessage(X_ERROR, "systemd-logind: out of memory\n");
        goto cleanup;
    }

    reply = assumeNoGC(&dbus_connection_send_with_reply_and_block)(info.conn, msg,
                                                      DBUS_TIMEOUT_USE_DEFAULT, &error);
    if (!reply) {
        LogMessage(X_ERROR, "systemd-logind: ReleaseControl failed: %s\n",
                   error.message);
        goto cleanup;
    }

cleanup:
    if (msg)
        assumeNoGC(&dbus_message_unref)(msg);
    if (reply)
        assumeNoGC(&dbus_message_unref)(reply);
    resolve!"dbus_error_free"()(&error);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void disconnect_hook(void* data)
{
    systemd_logind_info* info = cast(systemd_logind_info*)data;

    free(info.session);
    info.session = null;
    info.conn = null;
}

private dbus_core_hook core_hook = {
    connect: &connect_hook,
    disconnect: &disconnect_hook,
    data: &logind_info,
};

int systemd_logind_init()
{
    if (!mixin(ServerIsNotSeat0!()) && xf86HasTTYs() && linux_parse_vt_settings(TRUE) && !xf86VTKeepTtyIsSet()) {
        LogMessage(X_INFO,
            "systemd-logind: logind integration requires -keeptty and "
            ~ "-keeptty was not provided, disabling logind integration\n");
        return 1;
    }

    return dbus_core_add_hook(&core_hook);
}

void systemd_logind_fini()
{
    if (logind_info.session)
        systemd_logind_release_control(&logind_info);

    dbus_core_remove_hook(&core_hook);
}

}
else {
    void systemd_logind_init() {}
    void systemd_logind_fini() {}
    int systemd_logind_take_fd(int _major, int _minor, const(char)* path, Bool* paused_ret) => -1;
    void systemd_logind_release_fd(int _major, int _minor, int fd) { close(fd); }
    int systemd_logind_controls_session() => 0;

    void systemd_logind_vtenter() {}
    void systemd_logind_drop_master() {}
}