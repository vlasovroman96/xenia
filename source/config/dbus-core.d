module config.dbus_core;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2006-2007 Daniel Stone
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
 * Author: Daniel Stone <daniel@fooishbar.org>
 */

import build.dix_config;

import externs.libdbus;
import core.sys.posix.sys.select;

import os.log_priv;

import include.dix;
import include.os;

// import config.dbus_core;
import externs.attrs;
import os.log;
import config.libhal;
import os.connection;
import include.misc;
import externs.libdbus;
import core.sys.posix.sys.select;

import os.log_priv;

import include.dix;
import include.os;

// import config.dbus_core;
import externs.attrs;
import os.log;
import config.libhal;
import os.connection;

import os.WaitFor;
DBusErrorFn dbusErrorFunc = cast(DBusErrorFn)&__traits(getOverloads, mixin(__MODULE__), "dbus_error_init")[0];
DBusErrorFn dbusFreeFunc = cast(DBusErrorFn)&__traits(getOverloads, mixin(__MODULE__), "dbus_error_free")[0];


/* How often to attempt reconnecting when we get booted off the bus. */
enum RECONNECT_DELAY = (10 * 1000)     /* in ms */;

extern(C) nothrow @nogc
dbus_bool_t dbus_connection_unregister_object_path_d(
    DBusConnection* connection,
    const(char)* path)
{
    alias Fn = extern(C) dbus_bool_t function(
        DBusConnection*,
        const(char)*);

    return assumeNoGC(
        cast(Fn)&dbus_connection_unregister_object_path
    )(connection, path);
}

extern(C) nothrow @nogc
void dbus_bus_add_match_d(
    DBusConnection* connection,
    const(char)* rule,
    DBusError* error)
{
    assumeNoGC(&dbus_bus_add_match)(
        connection,
        rule,
        error
    );
}

extern(C) nothrow @nogc
dbus_bool_t dbus_connection_register_object_path_d(
    DBusConnection* connection,
    const(char)* path,
    DBusObjectPathVTable* vtable,
    void* data)
{
    alias Fn = extern(C) dbus_bool_t function(
        DBusConnection*,
        const(char)*,
        DBusObjectPathVTable*,
        void*
    );

    return assumeNoGC(cast(Fn)&dbus_connection_register_object_path)(
        connection,
        path,
        vtable,
        data
    );
}

dbus_bool_t dbus_error_is_set_d(DBusError* error) {
    return (cast(dbus_bool_t function(DBusError*)@nogc nothrow )&dbus_error_is_set)(error);
}

    dbus_bool_t dbus_message_is_signal_d(
        DBusMessage* msg,
        const(char)* iface,
        const(char)* name
    ) {
        return dbus_message_is_signal_d(msg, iface, name);
    }

int dbus_message_get_args_d(Args...)(DBusMessage* message, DBusError* error, Args args)
{
    return assumeNoGC(&dbus_message_get_args)(
        message,
        error,
        args,
        DBUS_TYPE_INVALID
    );
}

alias dbus_core_connect_hook = void function(DBusConnection * connection,
                                               void *data);
alias dbus_core_disconnect_hook = void function(void *data);

struct dbus_core_hook {
    dbus_core_connect_hook connect;
    dbus_core_disconnect_hook disconnect;
    void *data;

    dbus_core_hook *next;
};

struct dbus_core_info {
    int fd;
    DBusConnection* connection;
    OsTimerPtr timer;
    dbus_core_hook* hooks;
}
private dbus_core_info bus_info = { fd: -1 };



//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void dbus_socket_handler(int fd, int ready, void* data)
{
    dbus_core_info* info = cast(dbus_core_info*)data;

    if (info.connection) {
        do {
            assumeNoGC(&dbus_connection_read_write_dispatch)(info.connection, 0);
        } while (info.connection &&
                 assumeNoGC(&dbus_connection_get_is_connected)(info.connection) &&
                 assumeNoGC(&dbus_connection_get_dispatch_status)(info.connection) ==
                 DBUS_DISPATCH_DATA_REMAINS);
    }
}

/**
 * Disconnect (if we haven't already been forcefully disconnected), clean up
 * after ourselves, and call all registered disconnect hooks.
 */
nothrow @nogc private void teardown()
{
    dbus_core_hook* hook = void;

    if (bus_info.timer) {
        TimerFree(bus_info.timer);
        bus_info.timer = null;
    }

    /* We should really have pre-disconnect hooks and run them here, for
     * completeness.  But then it gets awkward, given that you can't
     * guarantee that they'll be called ... */
    if (bus_info.connection)
        assumeNoGC(&dbus_connection_unref)(bus_info.connection);

    if (bus_info.fd != -1)
        RemoveNotifyFd(bus_info.fd);
    bus_info.fd = -1;
    bus_info.connection = null;

    for (hook = bus_info.hooks; hook; hook = hook.next) {
        if (hook.disconnect)
            hook.disconnect(hook.data);
    }
}

/**
 * This is a filter, which only handles the disconnected signal, which
 * doesn't go to the normal message handling function.  This takes
 * precedence over the message handling function, so have have to be
 * careful to ignore anything we don't want to deal with here.
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private DBusHandlerResult message_filter(DBusConnection* connection, DBusMessage* message, void* data)
{
    /* If we get disconnected, then take everything down, and attempt to
     * reconnect immediately (assuming it's just a restart).  The
     * connection isn't valid at this point, so throw it out immediately. */
    if (assumeNoGC(&dbus_message_is_signal)(message, DBUS_INTERFACE_LOCAL, "Disconnected")) {
        DebugF("[dbus-core] disconnected from bus\n");
        bus_info.connection = null;
        teardown();

        if (bus_info.timer)
            TimerFree(bus_info.timer);
        bus_info.timer = TimerSet(null, 0, 1, &reconnect_timer, null);

        return DBUS_HANDLER_RESULT_HANDLED;
    }

    return DBUS_HANDLER_RESULT_NOT_YET_HANDLED;
}

/**
 * Attempt to connect to the system bus, and set a filter to deal with
 * disconnection (see message_filter above).
 *
 * @return 1 on success, 0 on failure.
 */
private int connect_to_bus()
{
    DBusError error = void;
    dbus_core_hook* hook = void;

    resolve!"dbus_error_init"()(&error);
    bus_info.connection = assumeNoGC(&dbus_bus_get)(DBUS_BUS_SYSTEM, &error);
    if (!bus_info.connection || assumeNoGC(&dbus_error_is_set)(&error)) {
        LogMessage(X_ERROR, "dbus-core: error connecting to system bus: %s (%s)\n",
               error.name, error.message);
        goto err_begin;
    }

    /* Thankyou.  Really, thankyou. */
    assumeNoGC(&dbus_connection_set_exit_on_disconnect)(bus_info.connection, 0);

    if (!assumeNoGC(&dbus_connection_get_unix_fd)(bus_info.connection, &bus_info.fd)) {
        ErrorF("[dbus-core] couldn't get fd for system bus\n");
        goto err_unref;
    }

    if (!assumeNoGC(&dbus_connection_add_filter)(bus_info.connection, &message_filter,
                                    &bus_info, null)) {
        ErrorF("[dbus-core] couldn't add filter: %s (%s)\n", error.name,
               error.message);
        goto err_fd;
    }

    resolve!"dbus_error_free"()(&error);
    SetNotifyFd(bus_info.fd, &dbus_socket_handler, X_NOTIFY_READ, &bus_info);

    for (hook = bus_info.hooks; hook; hook = hook.next) {
        if (hook.connect)
            hook.connect(bus_info.connection, hook.data);
    }

    return 1;

 err_fd:
    bus_info.fd = -1;
 err_unref:
    assumeNoGC(&dbus_connection_unref)(bus_info.connection);
    bus_info.connection = null;
 err_begin:
    resolve!"dbus_error_free"()(&error);

    return 0;
}

private CARD32 reconnect_timer(OsTimerPtr timer, CARD32 time, void* arg)
{
    if (connect_to_bus()) {
        TimerFree(bus_info.timer);
        bus_info.timer = null;
        return 0;
    }
    else {
        return RECONNECT_DELAY;
    }
}

int dbus_core_add_hook(dbus_core_hook* hook)
{
    dbus_core_hook** prev = void;

    for (prev = &bus_info.hooks; *prev; prev = &(*prev).next){}

    hook.next = null;
    *prev = hook;

    /* If we're already connected, call the connect hook. */
    if (bus_info.connection)
        hook.connect(bus_info.connection, hook.data);

    return 1;
}

void dbus_core_remove_hook(dbus_core_hook* hook)
{
    dbus_core_hook** prev = void;

    for (prev = &bus_info.hooks; *prev; prev = &(*prev).next) {
        if (*prev == hook) {
            *prev = hook.next;
            break;
        }
    }
}

int dbus_core_init()
{
    memset(&bus_info, 0, bus_info.sizeof);
    bus_info.fd = -1;
    bus_info.hooks = null;
    if (!connect_to_bus())
        bus_info.timer = TimerSet(null, 0, 1, &reconnect_timer, null);

    return 1;
}

void dbus_core_fini()
{
    teardown();
}
