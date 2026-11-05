module config.libhal;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2007 Daniel Stone
 * Copyright © 2007 Red Hat, Inc.
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

import core.stdc.string;
import core.sys.posix.sys.select;
import externs.libdbus;
import externs.libhal;

import config.hotplug_priv;
import config.dbus_core;
import os.fmt;

import dix.input;
import include.inputstr;
import config.config_backends;
import include.os;
import externs.gnu;
import os.log;
import externs.libhal;
import externs.attrs;
import os.string;
import build.dix_config;

// import externs.libdbus;
import core.sys.posix.sys.select;

import os.log_priv;

import include.os;

import config.dbus_core;
import externs.attrs;
import os.log;
import dix.inpututils;
import hw.xfree86.common.xf86Xinput;


enum LIBHAL_PROP_KEY = "input.X11_options.";
enum LIBHAL_XKB_PROP_KEY = "input.xkb.";

alias DBusErrorFn = @nogc nothrow void function(DBusError*);
alias DBusErrorBoolFn = @nogc nothrow bool function(DBusError*);
alias HalConfigFn = @nogc nothrow bool function(DBusConnection*);

struct config_hal_info {
    DBusConnection* system_bus;
    LibHalContext* hal_ctx;
}

/* Used for special handling of xkb options. */
struct xkb_options {
    char* layout;
    char* model;
    char* rules;
    char* variant;
    char* options;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void device_removed(LibHalContext* ctx, const(char)* udi)
{
    char* value = void;

    if (asprintf(&value, "hal:%s", udi) == -1)
        return;

    remove_devices("hal", value);

    free(value);
}

private char* get_prop_string(LibHalContext* hal_ctx, const(char)* udi, const(char)* name)
{
    char* prop = void, ret = void;

    prop = assumeNoGC(&libhal_device_get_property_string)(hal_ctx, udi, name, null);
    LogMessageVerb(X_INFO, 10, "config/hal: getting %s on %s returned %s\n",
                   name, udi, prop ? prop : "(null)");
    if (prop) {
        ret = strdup(prop);
        assumeNoGC(&libhal_free_string)(prop);
    }
    else {
        return null;
    }

    return ret;
}

private char* get_prop_string_array(LibHalContext* hal_ctx, const(char)* udi, const(char)* prop)
{
    char** props = void; char* ret = void, str = void;
    int i = void, len = 0;

    props = assumeNoGC(&libhal_device_get_property_strlist)(hal_ctx, udi, prop, null);
    if (props) {
        for (i = 0; props[i]; i++)
            len += strlen(props[i]);

        ret = cast(char*) calloc(len + i, char.sizeof);    /* i - 1 commas, 1 NULL */
        if (!ret) {
            assumeNoGC(&libhal_free_string_array)(props);
            return null;
        }

        str = ret;
        for (i = 0; props[i]; i++) {
            strcpy(str, props[i]);
            str += strlen(props[i]);
            *str++ = ',';
        }
        *(str - 1) = '\0';

        assumeNoGC(&libhal_free_string_array)(props);
    }
    else {
        return null;
    }

    return ret;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void device_added_hal(LibHalContext* hal_ctx, const(char)* udi)
{
    char* path = null, driver = null, name = null, config_info = null;
    char* hal_tags = void, parent = void;
    InputOption* input_options = null;
    InputAttributes attrs;
    DeviceIntPtr dev = null;
    DBusError error = void;
    xkb_options xkb_opts;
    int rc = void;

    LibHalPropertySet* set = null;
    LibHalPropertySetIterator set_iter = void;
    char* psi_key = null, tmp_val = void;

    // alias dbuserrorFn = @nogc nothrow extern(C) void function(DBusError*);
    assumeNoGC(dbusErrorFunc)(&error);

    driver = get_prop_string(hal_ctx, udi, "input.X11_driver");
    if (!driver) {
        /* verbose, don't tell the user unless they _want_ to see it */
        LogMessageVerb(X_INFO, 7,
                       "config/hal: no driver specified for device %s\n", udi);
        goto unwind;
    }

    path = get_prop_string(hal_ctx, udi, "input.device");
    if (!path) {
        LogMessage(X_WARNING,
                   "config/hal: no driver or path specified for %s\n", udi);
        goto unwind;
    }
    attrs.device = strdup(path);

    name = get_prop_string(hal_ctx, udi, "info.product");
    if (!name)
        name = strdup("(unnamed)");
    else
        attrs.product = strdup(name);

    attrs.vendor = get_prop_string(hal_ctx, udi, "info.vendor");
    hal_tags = get_prop_string(hal_ctx, udi, "input.tags");
    attrs.tags = xstrtokenize(hal_tags, ",");
    free(hal_tags);

    if (assumeNoGC(&libhal_device_query_capability)(hal_ctx, udi, "input.keys", null))
        attrs.flags |= ATTR_KEY | ATTR_KEYBOARD;
    if (assumeNoGC(&libhal_device_query_capability)(hal_ctx, udi, "input.mouse", null))
        attrs.flags |= ATTR_POINTER;
    if (assumeNoGC(&libhal_device_query_capability)(hal_ctx, udi, "input.joystick", null))
        attrs.flags |= ATTR_JOYSTICK;
    if (assumeNoGC(&libhal_device_query_capability)(hal_ctx, udi, "input.tablet", null))
        attrs.flags |= ATTR_TABLET;
    if (assumeNoGC(&libhal_device_query_capability)(hal_ctx, udi, "input.tablet_pad", null))
        attrs.flags |= ATTR_TABLET_PAD;
    if (assumeNoGC(&libhal_device_query_capability)(hal_ctx, udi, "input.touchpad", null))
        attrs.flags |= ATTR_TOUCHPAD;
    if (assumeNoGC(&libhal_device_query_capability)(hal_ctx, udi, "input.touchscreen", null))
        attrs.flags |= ATTR_TOUCHSCREEN;

    parent = get_prop_string(hal_ctx, udi, "info.parent");
    if (parent) {
        int usb_vendor = void, usb_product = void;
        char* old_parent = void;

        /* construct USB ID in lowercase - "0000:ffff" */
        usb_vendor = assumeNoGC(&libhal_device_get_property_int)(hal_ctx, parent,
                                                    "usb.vendor_id", null);
        LogMessageVerb(X_INFO, 10,
                       "config/hal: getting usb.vendor_id on %s "
                       ~ "returned %04x\n", parent, usb_vendor);
        usb_product = assumeNoGC(&libhal_device_get_property_int)(hal_ctx, parent,
                                                     "usb.product_id", null);
        LogMessageVerb(X_INFO, 10,
                       "config/hal: getting usb.product_id on %s "
                       ~ "returned %04x\n", parent, usb_product);
        if (usb_vendor && usb_product)
            if (asprintf(&attrs.usb_id, "%04x:%04x", usb_vendor, usb_product)
                == -1)
                attrs.usb_id = null;

        attrs.pnp_id = get_prop_string(hal_ctx, parent, "pnp.id");
        old_parent = parent;

        while (!attrs.pnp_id &&
               (parent = get_prop_string(hal_ctx, parent, "info.parent")) !is null) {
            attrs.pnp_id = get_prop_string(hal_ctx, parent, "pnp.id");

            free(old_parent);
            old_parent = parent;
        }

        free(old_parent);
    }

    input_options = input_option_new(null, "_source", "server/hal");
    if (!input_options) {
        LogMessage(X_ERROR,
                   "config/hal: couldn't allocate first key/value pair\n");
        goto unwind;
    }

    /* most drivers use device.. not path. evdev uses both however, but the
     * path version isn't documented apparently. support both for now. */
    input_options = input_option_new(input_options, "path", path);
    input_options = input_option_new(input_options, "device", path);

    input_options = input_option_new(input_options, "driver", driver);
    input_options = input_option_new(input_options, "name", name);

    if (asprintf(&config_info, "hal:%s", udi) == -1) {
        config_info = null;
        LogMessage(X_ERROR, "config/hal: couldn't allocate name\n");
        goto unwind;
    }

    /* Check for duplicate devices */
    if (device_is_duplicate(config_info)) {
        LogMessage(X_WARNING,
                   "config/hal: device %s already added. Ignoring.\n", name);
        goto unwind;
    }

    /* ok, grab options from hal.. iterate through all properties
     * and lets see if any of them are options that we can add */
    set = assumeNoGC(&libhal_device_get_all_properties)(hal_ctx, udi, &error);

    if (!set) {
        LogMessage(X_ERROR,
                   "config/hal: couldn't get property list for %s: %s (%s)\n",
                   udi, error.name, error.message);
        goto unwind;
    }

    assumeNoGC(&libhal_psi_init)(&set_iter, set);
    while (assumeNoGC(&libhal_psi_has_more)(&set_iter)) {
        /* we are looking for supported keys.. extract and add to options */
        psi_key = assumeNoGC(&libhal_psi_get_key)(&set_iter);

        if (psi_key) {

            /* normal options first (input.X11_options.<propname>) */
            if (!strncasecmp
                (psi_key, LIBHAL_PROP_KEY, ((LIBHAL_PROP_KEY).sizeof - 1))) {
                char* tmp = void;

                /* only support strings for all values */
                tmp_val = get_prop_string(hal_ctx, udi, psi_key);

                if (tmp_val) {

                    /* xkb needs special handling. HAL specs include
                     * input.xkb.xyz options, but the X11-input.fdi specifies
                     * input.X11_options.Xkbxyz options. By default, we use
                     * the former, unless the specific X11 ones are specified.
                     * Since we can't predict the order in which the keys
                     * arrive, we need to store them.
                     */
                    if ((tmp = strcasestr(psi_key, "xkb")) !is null && strlen(tmp) >= 4) {
                        if (!strcasecmp(&tmp[3], "layout")) {
                            free(xkb_opts.layout);
                            xkb_opts.layout = strdup(tmp_val);
                        }
                        else if (!strcasecmp(&tmp[3], "model")) {
                            free(xkb_opts.model);
                            xkb_opts.model = strdup(tmp_val);
                        }
                        else if (!strcasecmp(&tmp[3], "rules")) {
                            free(xkb_opts.rules);
                            xkb_opts.rules = strdup(tmp_val);
                        }
                        else if (!strcasecmp(&tmp[3], "variant")) {
                            free(xkb_opts.variant);
                            xkb_opts.variant = strdup(tmp_val);
                        }
                        else if (!strcasecmp(&tmp[3], "options")) {
                            free(xkb_opts.options);
                            xkb_opts.options = strdup(tmp_val);
                        }
                    }
                    else {
                        /* all others */
                        input_options =
                            input_option_new(input_options,
                                             psi_key + ((LIBHAL_PROP_KEY).sizeof -
                                             1), tmp_val);
                        free(tmp_val);
                    }
                }
                else {
                    /* server 1.4 had xkb_options as strlist. */
                    if ((tmp = strcasestr(psi_key, "xkb")) !is null &&
                        (strlen(tmp) >= 4) &&
                        (!strcasecmp(&tmp[3], "options")) &&
                        (tmp_val =
                         get_prop_string_array(hal_ctx, udi, psi_key)) !is null) {
                        free(xkb_opts.options);
                        xkb_opts.options = strdup(tmp_val);
                    }
                }
            }
            else if (!strncasecmp
                     (psi_key, LIBHAL_XKB_PROP_KEY,
                      ((LIBHAL_XKB_PROP_KEY).sizeof - 1))) {
                char* tmp = void;

                /* only support strings for all values */
                tmp_val = get_prop_string(hal_ctx, udi, psi_key);

                if (tmp_val && strlen(psi_key) >= LIBHAL_XKB_PROP_KEY.sizeof) {

                    tmp = &psi_key[((LIBHAL_XKB_PROP_KEY).sizeof - 1)];

                    if (!strcasecmp(tmp, "layout")) {
                        if (!xkb_opts.layout)
                            xkb_opts.layout = strdup(tmp_val);
                    }
                    else if (!strcasecmp(tmp, "rules")) {
                        if (!xkb_opts.rules)
                            xkb_opts.rules = strdup(tmp_val);
                    }
                    else if (!strcasecmp(tmp, "variant")) {
                        if (!xkb_opts.variant)
                            xkb_opts.variant = strdup(tmp_val);
                    }
                    else if (!strcasecmp(tmp, "model")) {
                        if (!xkb_opts.model)
                            xkb_opts.model = strdup(tmp_val);
                    }
                    else if (!strcasecmp(tmp, "options")) {
                        if (!xkb_opts.options)
                            xkb_opts.options = strdup(tmp_val);
                    }
                    free(tmp_val);
                }
                else {
                    /* server 1.4 had xkb options as strlist */
                    tmp_val = get_prop_string_array(hal_ctx, udi, psi_key);
                    if (tmp_val &&
                        strlen(psi_key) >= LIBHAL_XKB_PROP_KEY.sizeof) {
                        tmp = &psi_key[((LIBHAL_XKB_PROP_KEY).sizeof - 1)];
                        if (!strcasecmp(tmp, ".options") && (!xkb_opts.options))
                            xkb_opts.options = strdup(tmp_val);
                    }
                    free(tmp_val);
                }
            }
        }

        /* psi_key doesn't need to be freed */
        assumeNoGC(&libhal_psi_next)(&set_iter);
    }

    /* Now add xkb options */
    if (xkb_opts.layout)
        input_options =
            input_option_new(input_options, "xkb_layout", xkb_opts.layout);
    if (xkb_opts.rules)
        input_options =
            input_option_new(input_options, "xkb_rules", xkb_opts.rules);
    if (xkb_opts.variant)
        input_options =
            input_option_new(input_options, "xkb_variant", xkb_opts.variant);
    if (xkb_opts.model)
        input_options =
            input_option_new(input_options, "xkb_model", xkb_opts.model);
    if (xkb_opts.options)
        input_options =
            input_option_new(input_options, "xkb_options", xkb_opts.options);
    input_options = input_option_new(input_options, "config_info", config_info);

    /* this isn't an error, but how else do you output something that the user can see? */
    LogMessage(X_INFO, "config/hal: Adding input device %s\n", name);
    if ((rc = NewInputDeviceRequest(input_options, &attrs, &dev)) != Success) {
        LogMessage(X_ERROR, "config/hal: NewInputDeviceRequest failed (%d)\n",
                   rc);
        dev = null;
        goto unwind;
    }

 unwind:
    if (set)
        assumeNoGC(&libhal_free_property_set)(set);
    free(path);
    free(driver);
    free(name);
    free(config_info);
    input_option_free_list(&input_options);

    free(attrs.product);
    free(attrs.vendor);
    free(attrs.device);
    free(attrs.pnp_id);
    free(attrs.usb_id);
    if (attrs.tags) {
        char** tag = attrs.tags;

        while (*tag) {
            free(*tag);
            tag++;
        }
        free(attrs.tags);
    }

    free(xkb_opts.layout);
    free(xkb_opts.rules);
    free(xkb_opts.model);
    free(xkb_opts.variant);
    free(xkb_opts.options);

    assumeNoGC(dbusFreeFunc)(&error);

    return;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void disconnect_hook(void* data)
{
    DBusError error = void;
    config_hal_info* info = cast(config_hal_info*)data;

    if (info.hal_ctx) {
        if (resolve!"dbus_connection_get_is_connected"()(info.system_bus)) {
            resolve!"dbus_error_init"()(&error);
            if (!assumeNoGC(&libhal_ctx_shutdown)(info.hal_ctx, &error))
                LogMessage(X_WARNING,
                           "config/hal: disconnect_hook couldn't shut down context: %s (%s)\n",
                           error.name, error.message);
            resolve!"dbus_error_free"()(&error);
        }
        assumeNoGC(&libhal_ctx_free)(info.hal_ctx);
    }

    info.hal_ctx = null;
    info.system_bus = null;
}

private BOOL connect_and_register(DBusConnection* connection, config_hal_info* info)
{
    DBusError error = void;
    char** devices = void;
    int num_devices = void, i = void;

    if (info.hal_ctx)
        return 1;            /* already registered, pretend we did something */

    info.system_bus = connection;

    resolve!"dbus_error_init"()(&error);

    info.hal_ctx = assumeNoGC(&libhal_ctx_new)();
    if (!info.hal_ctx) {
        LogMessage(X_ERROR, "config/hal: couldn't create HAL context\n");
        goto out_err;
    }

    if (!assumeNoGC(&libhal_ctx_set_dbus_connection)(info.hal_ctx, info.system_bus)) {
        LogMessage(X_ERROR,
                   "config/hal: couldn't associate HAL context with bus\n");
        goto out_err;
    }
    if (!assumeNoGC(&libhal_ctx_init)(info.hal_ctx, &error)) {
        LogMessage(X_ERROR,
                   "config/hal: couldn't initialise context: %s (%s)\n",
                   error.name ? error.name : "unknown error",
                   error.message ? error.message : "null");
        goto out_err;
    }
    if (!assumeNoGC(&libhal_device_property_watch_all)(info.hal_ctx, &error)) {
        LogMessage(X_ERROR,
                   "config/hal: couldn't watch all properties: %s (%s)\n",
                   error.name ? error.name : "unknown error",
                   error.message ? error.message : "null");
        goto out_ctx;
    }
    assumeNoGC(&libhal_ctx_set_device_added)(info.hal_ctx, &device_added_hal);
    assumeNoGC(&libhal_ctx_set_device_removed)(info.hal_ctx, &device_removed);

    devices = assumeNoGC(&libhal_find_device_by_capability)(info.hal_ctx, "input",
                                               &num_devices, &error);
    /* FIXME: Get default devices if error is set. */
    if (resolve!"dbus_error_is_set"()(&error)) {
        LogMessage(X_ERROR, "config/hal: couldn't find input device: %s (%s)\n",
                   error.name ? error.name : "unknown error",
                   error.message ? error.message : "null");
        goto out_ctx;
    }
    for (i = 0; i < num_devices; i++)
        device_added_hal(info.hal_ctx, devices[i]);
    assumeNoGC(&libhal_free_string_array)(devices);

    resolve!"dbus_error_free"()(&error);

    return 1;

 out_ctx:
    resolve!"dbus_error_free"()(&error);

    if (!assumeNoGC(&libhal_ctx_shutdown)(info.hal_ctx, &error)) {
        LogMessage(X_WARNING,
                   "config/hal: couldn't shut down context: %s (%s)\n",
                   error.name ? error.name : "unknown error",
                   error.message ? error.message : "null");
        resolve!"dbus_error_free"()(&error);
    }

 out_err:
    resolve!"dbus_error_free"()(&error);

    if (info.hal_ctx) {
        assumeNoGC(&libhal_ctx_free)(info.hal_ctx);
    }

    info.hal_ctx = null;
    info.system_bus = null;

    return 0;
}

/**
 * Handle NewOwnerChanged signals to deal with HAL startup at X server runtime.
 *
 * NewOwnerChanged is send once when HAL shuts down, and once again when it
 * comes back up. Message has three arguments, first is the name
 * (org.freedesktop.Hal), the second one is the old owner, third one is new
 * owner.
 */
private DBusHandlerResult ownerchanged_handler(DBusConnection* connection, DBusMessage* message, void* data)
{
    int ret = DBUS_HANDLER_RESULT_NOT_YET_HANDLED;

    if (dbus_message_is_signal_d(message,
                               "org.freedesktop.DBus", "NameOwnerChanged")) {
        DBusError error = void;
        char* name = void, old_owner = void, new_owner = void;

        resolve!"dbus_error_init"()(&error);
        dbus_message_get_args_d(message, &error,
                              DBUS_TYPE_STRING, &name,
                              DBUS_TYPE_STRING, &old_owner,
                              DBUS_TYPE_STRING, &new_owner);

        if (config.libhal.dbus_error_is_set_d(&error)) {
            ErrorF
                ("[config/hal] failed to get NameOwnerChanged args: %s (%s)\n",
                 error.name, error.message);
        }
        else if (name && strcmp(name, "org.freedesktop.Hal") == 0) {

            if (!old_owner || !strlen(old_owner)) {
                DebugF("[config/hal] HAL startup detected.\n");
                if (connect_and_register
                    (connection, cast(config_hal_info*) data)) {
                        dbus_connection_unregister_object_path_d(connection,
                                                           "/org/freedesktop/DBus");
                    }
                else
                    ErrorF("[config/hal] Failed to connect to HAL bus.\n");
            }

            ret = DBUS_HANDLER_RESULT_HANDLED;
        }
        resolve!"dbus_error_free"()(&error);
    }

    return cast(DBusHandlerResult)ret;
}

/**
 * Register a handler for the NameOwnerChanged signal.
 */
private BOOL listen_for_startup(DBusConnection* connection, void* data)
{
    DBusObjectPathVTable vtable = {message_function: &ownerchanged_handler, };
    DBusError error = void;
    const(char)[132] MATCH_RULE = "sender='org.freedesktop.DBus',"
        ~ "interface='org.freedesktop.DBus',"
        ~ "type='signal',"
        ~ "path='/org/freedesktop/DBus'," ~ "member='NameOwnerChanged'";
    int rc = 0;

    resolve!"dbus_error_init"()(&error);
    dbus_bus_add_match_d(connection, MATCH_RULE.ptr, &error);
    if (!dbus_error_is_set_d(&error)) {
        if (dbus_connection_register_object_path_d(connection,
                                                 "/org/freedesktop/DBus",
                                                 &vtable, data))
            rc = 1;
        else
            ErrorF("[config/hal] cannot register object path.\n");
    }
    else {
        ErrorF("[config/hal] couldn't add match rule: %s (%s)\n", error.name,
               error.message);
        ErrorF("[config/hal] cannot detect a HAL startup.\n");
    }

    resolve!"dbus_error_free"()(&error);

    return cast(BOOL)rc;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void connect_hook(DBusConnection* connection, void* data)
{
    config_hal_info* info = cast(config_hal_info*)data;

    if (listen_for_startup(connection, data) &&
        connect_and_register(connection, info))
        dbus_connection_unregister_object_path_d(connection,
                                               "/org/freedesktop/DBus");

    return;
}

private config_hal_info hal_info;

private dbus_core_hook hook = {
    connect: &connect_hook,
    disconnect: &disconnect_hook,
    data: &hal_info,
};

int config_hal_init()
{
    memset(&hal_info, 0, hal_info.sizeof);
    hal_info.system_bus = null;
    hal_info.hal_ctx = null;

    if (!dbus_core_add_hook(&hook)) {
        LogMessage(X_ERROR, "config/hal: failed to add D-Bus hook\n");
        return 0;
    }

    /* verbose message */
    LogMessageVerb(X_INFO, 7, "config/hal: initialized\n");

    return 1;
}

void config_hal_fini()
{
    dbus_core_remove_hook(&hook);
}
