module config.udev;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2009 Julien Cristau
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
 * Author: Julien Cristau <jcristau@debian.org>
 */

import build.dix_config;

import externs.libudev;
import core.stdc.ctype;
import core.sys.posix.unistd;

import dix.settings_priv;
import config.hotplug_priv;
import os.fmt;

import include.input;
import include.inputstr;
import config.config_backends;
import include.os;
import include.globals;
import externs.attrs;
import os.log;
import dix.inpututils;
import externs.gnu;
import os.string;
import os.connection;
import xf86Xinput;
import os.inputthread;
import xf86platformBus;

import drm_platform;


import hw.xfree86.os_support.linux.systemd_logind;

version (HAVE_SYS_SYSMACROS_H) {
import sys.sysmacros;
}

// struct udev_enumerate;
udev_enumerate* udev_enumerate_unref(udev_enumerate *p);

auto cstr(T)(T value)
{
    static if (is(T : const(char)*))
        return value;
    else
        return value.ptr;
}

template udev_list_entry_foreach(string entry, string set, string bodyCode)
{
    enum udev_list_entry_foreach = 
        "for (" ~ entry ~ " = " ~ set ~ "; "
        ~ entry ~ " !is null; "
        ~ entry ~ " = assumeNoGC(&udev_list_entry_get_next)(" ~ entry ~ ")) {"
        ~ bodyCode
        ~ "}";
}

enum UDEV_XKB_PROP_KEY = "xkb";

    enum string LOG_PROPERTY(string path, string attr, string val) = `
    LogMessageVerb(
        X_INFO,
        10,
        cstr("config/udev: getting attribute %s on %s returned \"%s\"\n"),
        cstr(` ~ attr ~ `),
        cstr(` ~ path ~ `),
        cstr(` ~ val ~ ` ? ` ~ val ~ ` : "(null)")
    );`;
enum string LOG_SYSATTR(string path, string attr, string val) = `
    LogMessageVerb(
        X_INFO,
        10,
        cstr("config/udev: getting attribute %s on %s returned \"%s\"\n"),
        cstr(` ~ attr ~ `),
        cstr(` ~ path ~ `),
        cstr(` ~ val ~ ` ? ` ~ val ~ ` : "(null)")
    );`;



private udev_monitor* udev_monitor_;

static if (CONFIG_UDEV_KMS) {

}

private Bool check_seat(udev_device* udev_device)
{
    const(char)* dev_seat = void;

    dev_seat = assumeNoGC(&udev_device_get_property_value)(udev_device, "ID_SEAT");
    if (!dev_seat)
        dev_seat = "seat0";

    if (dixSettingSeatId && strcmp(dev_seat, dixSettingSeatId))
        return FALSE;

    if (!dixSettingSeatId && strcmp(dev_seat, "seat0"))
        return FALSE;

    return TRUE;
}

alias dev_t = core.sys.posix.sys.types.dev_t;

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void device_added_udev(udev_device* udev_device_)
{
    const(char)* path = void, name = null;
    char* config_info = null;
    const(char)* syspath = void;
    const(char)* tags_prop = void;
    const(char)* key = void, value = void, tmp = void;
static if (CONFIG_UDEV_KMS) {
    const(char)* subsys = null;
}
    InputOption* input_options = void;
    InputAttributes attrs;
    DeviceIntPtr dev = null;
    udev_list_entry* set = void, entry = void;
    udev_device* parent = void;
    int rc = void;
    dev_t devnum = void;

    path = assumeNoGC(&udev_device_get_devnode)(udev_device_);

    syspath = assumeNoGC(&udev_device_get_syspath)(udev_device_);

    if (!path || !syspath)
        return;

    if (!check_seat(udev_device_))
        return;

    devnum = assumeNoGC(&udev_device_get_devnum)(udev_device_);

static if (CONFIG_UDEV_KMS) {
    subsys = assumeNoGC(&udev_device_get_subsystem)(udev_device_);

    if (subsys && !strcmp(subsys, "drm")) {
        const(char)* sysname = assumeNoGC(&udev_device_get_sysname)(udev_device_);

        if (strncmp(sysname, "card", 4) != 0)
            return;

        /* Check for devices already added through xf86platformProbe() */
        if (xf86_find_platform_device_by_devnum(major(devnum), minor(devnum)))
            return;

        LogMessage(X_INFO, "config/udev: Adding drm device (%s)\n", path);

        config_udev_odev_setup_attribs(udev_device_, path, syspath, major(devnum),
                                       minor(devnum), &NewGPUDeviceRequest);
        return;
    }
}

    value = assumeNoGC(&udev_device_get_property_value)(udev_device_, "ID_INPUT");
    if (!value || !strcmp(value, "0")) {
        LogMessageVerb(X_INFO, 10,
                       "config/udev: ignoring device %s without "
                       ~ "property ID_INPUT set\n", path);
        return;
    }

    input_options = input_option_new(null, "_source", "server/udev");
    if (!input_options)
        return;

    parent = assumeNoGC(&udev_device_get_parent)(udev_device_);
    if (parent) {
        const(char)* ppath = assumeNoGC(&udev_device_get_devnode)(parent);
        const(char)* product = assumeNoGC(&udev_device_get_property_value)(parent, "PRODUCT");
        const(char)* pnp_id = assumeNoGC(&udev_device_get_sysattr_value)(parent, "id");
        uint usb_vendor = void, usb_model = void;

        name = assumeNoGC(&udev_device_get_sysattr_value)(parent, "name");
        mixin(LOG_SYSATTR!(`ppath`, `"name"`, `name`));
        if (!name) {
            name = assumeNoGC(&udev_device_get_property_value)(parent, "NAME");
            mixin(LOG_PROPERTY!(`ppath`, `"NAME"`, `name`));
        }

        /* construct USB ID in lowercase hex - "0000:ffff" */
        if (product &&
            sscanf(product, "%*x/%4x/%4x/%*x", &usb_vendor, &usb_model) == 2) {
            char* usb_id = void;
            if (asprintf(&usb_id, "%04x:%04x", usb_vendor, usb_model)
                == -1)
                usb_id = null;
            else
                mixin(LOG_PROPERTY!(`ppath`, `"PRODUCT"`, `product`));
            attrs.usb_id = usb_id;
        }

        while (!pnp_id && (parent = assumeNoGC(&udev_device_get_parent)(parent)) !is null) {
            pnp_id = assumeNoGC(&udev_device_get_sysattr_value)(parent, "id");
            if (!pnp_id)
                continue;

            attrs.pnp_id = strdup(pnp_id);
            ppath = assumeNoGC(&udev_device_get_devnode)(parent);
            mixin(LOG_SYSATTR!(`ppath`, `"id"`, `pnp_id`));
        }

    }
    if (!name)
        name = "(unnamed)";
    else
        attrs.product = strdup(name);

    char[128] buf = void;
    input_options = input_option_new(input_options, "name", name);
    input_options = input_option_new(input_options, "path", path);
    input_options = input_option_new(input_options, "device", path);
    sprintf(buf.ptr, "%u", majorDev(devnum));
    input_options = input_option_new(input_options, "major", buf.ptr);
    sprintf(buf.ptr, "%u", minorDev(devnum));
    input_options = input_option_new(input_options, "minor", buf.ptr);
    if (path)
        attrs.device = strdup(path);

    tags_prop = assumeNoGC(&udev_device_get_property_value)(udev_device_, "ID_INPUT.tags");
    mixin(LOG_PROPERTY!(`path`, `"ID_INPUT.tags"`, `tags_prop`));
    attrs.tags = xstrtokenize(tags_prop, ",");

    if (asprintf(&config_info, "udev:%s", syspath) == -1) {
        config_info = null;
        goto unwind;
    }

    if (device_is_duplicate(config_info)) {
        LogMessage(X_WARNING, "config/udev: device %s already added. "
                   ~ "Ignoring.\n", name);
        goto unwind;
    }

    set = assumeNoGC(&udev_device_get_properties_list_entry)(udev_device_);
    mixin(udev_list_entry_foreach!("entry", "set", q{
        key = assumeNoGC(&udev_list_entry_get_name)(entry);
        if (!key)
            continue;
        value = assumeNoGC(&udev_list_entry_get_value)(entry);
        if (!strncasecmp(key, UDEV_XKB_PROP_KEY, ((UDEV_XKB_PROP_KEY).sizeof - 1))) {
            mixin(LOG_PROPERTY!(`path`, `key`, `value`));
            tmp = key + ((UDEV_XKB_PROP_KEY).sizeof - 1);
            if (!strcasecmp(tmp, "rules"))
                input_options =
                    input_option_new(input_options, "xkb_rules", value);
            else if (!strcasecmp(tmp, "layout"))
                input_options =
                    input_option_new(input_options, "xkb_layout", value);
            else if (!strcasecmp(tmp, "variant"))
                input_options =
                    input_option_new(input_options, "xkb_variant", value);
            else if (!strcasecmp(tmp, "model"))
                input_options =
                    input_option_new(input_options, "xkb_model", value);
            else if (!strcasecmp(tmp, "options"))
                input_options =
                    input_option_new(input_options, "xkb_options", value);
        }
        else if (!strcmp(key, "ID_VENDOR")) {
            mixin(LOG_PROPERTY!(`path`, `key`, `value`));
            attrs.vendor = strdup(value);
        } else if (!strncmp(key, "ID_INPUT_", 9)) {
            struct pfmap {
                const(char)* property = void;
                uint flag = void;
            }const(pfmap)[10] map = [
                { "ID_INPUT_KEY", ATTR_KEY },
                { "ID_INPUT_KEYBOARD", ATTR_KEYBOARD },
                { "ID_INPUT_MOUSE", ATTR_POINTER },
                { "ID_INPUT_JOYSTICK", ATTR_JOYSTICK },
                { "ID_INPUT_TABLET", ATTR_TABLET },
                { "ID_INPUT_TABLET_PAD", ATTR_TABLET_PAD },
                { "ID_INPUT_TOUCHPAD", ATTR_TOUCHPAD },
                { "ID_INPUT_TOUCHSCREEN", ATTR_TOUCHSCREEN },
                { null, 0 },
            ];

            if (value && strcmp(value, "0")) {
                const(pfmap)* m = map.ptr;

                while (m.property !is null) {
                    if (!strcmp(m.property, key)) {
                        mixin(LOG_PROPERTY!(`path`, `key`, `value`));
                        attrs.flags |= m.flag;
                    }
                    m++;
                }
            }
        }
    }));

    input_options = input_option_new(input_options, "config_info", config_info);

    /* Default setting needed for non-seat0 seats */
    if (mixin(ServerIsNotSeat0!()))
        input_options = input_option_new(input_options, "GrabDevice", "on");

    LogMessage(X_INFO, "config/udev: Adding input device %s (%s)\n",
               name, path);
    rc = NewInputDeviceRequest(input_options, &attrs, &dev);
    if (rc != Success)
        goto unwind;

 unwind:
    free(config_info);
    input_option_free_list(&input_options);

    free(attrs.usb_id);
    free(attrs.pnp_id);
    free(attrs.product);
    free(attrs.device);
    free(attrs.vendor);
    if (attrs.tags) {
        char** tag = attrs.tags;

        while (*tag) {
            free(*tag);
            tag++;
        }
        free(attrs.tags);
    }

    return;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void device_removed(udev_device* device)
{
    char* value = void;
    const(char)* syspath = assumeNoGC(&udev_device_get_syspath)(device);

static if (CONFIG_UDEV_KMS) {
    const(char)* subsys = assumeNoGC(&udev_device_get_subsystem)(device);

    if (subsys && !strcmp(subsys, "drm")) {
        const(char)* sysname = assumeNoGC(&udev_device_get_sysname)(device);
        const(char)* path = assumeNoGC(&udev_device_get_devnode)(device);
        dev_t devnum = assumeNoGC(&udev_device_get_devnum)(device);

        if ((strncmp(sysname,"card", 4) != 0) || (path is null))
            return;

        LogMessage(X_INFO, "config/udev: removing GPU device %s %s\n",
                   syspath, path);
        config_udev_odev_setup_attribs(device, path, syspath, major(devnum),
                                       minor(devnum), &DeleteGPUDeviceRequest);
        /* Retry vtenter after a drm node removal */
        systemd_logind_vtenter();
        return;
    }
}

    if (asprintf(&value, "udev:%s", syspath) == -1)
        return;

    remove_devices("udev", value);

    free(value);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void udev_socket_handler(int fd, int ready, void* data)
{
    cast(void) fd;
    cast(void) ready;
    cast(void) data;
    udev_device* udev_device = void;
    const(char)* action = void;

    input_lock();
    udev_device = assumeNoGC(&udev_monitor_receive_device)(udev_monitor_);
    if (!udev_device) {
        input_unlock();
        return;
    }
    action = assumeNoGC(&udev_device_get_action)(udev_device);
    if (action) {
        if (!strcmp(action, "add")) {
            device_removed(udev_device);
            device_added_udev(udev_device);
        } else if (!strcmp(action, "change")) {
            /* ignore change for the drm devices */
            const(char)* subsys = assumeNoGC(&udev_device_get_subsystem)(udev_device);

            if (subsys && strcmp(subsys, "drm")) {
                device_removed(udev_device);
                device_added_udev(udev_device);
            }
        }
        else if (!strcmp(action, "remove"))
            device_removed(udev_device);
    }
    assumeNoGC(&udev_device_unref)(udev_device);
    input_unlock();
}

int config_udev_pre_init()
{
    udev* udev = void;

    udev = assumeNoGC(&udev_new)();
    if (!udev)
        return 0;

    udev_monitor_ = assumeNoGC(&udev_monitor_new_from_netlink)(udev, "udev");
    if (!udev_monitor_)
        return 0;

    assumeNoGC(&udev_monitor_filter_add_match_subsystem_devtype)(udev_monitor_, "input",
                                                    null);
    /* For Wacom serial devices */
    assumeNoGC(&udev_monitor_filter_add_match_subsystem_devtype)(udev_monitor_, "tty", null);
static if (CONFIG_UDEV_KMS) {
    /* For output GPU devices */
    assumeNoGC(&udev_monitor_filter_add_match_subsystem_devtype)(udev_monitor_, "drm", null);
}

version (HAVE_UDEV_MONITOR_FILTER_ADD_MATCH_TAG) {
    if (mixin(ServerIsNotSeat0!()))
        udev_monitor_filter_add_match_tag(udev_monitor_, dixSettingSeatId);
}
    if (assumeNoGC(&udev_monitor_enable_receiving)(udev_monitor_)) {
        ErrorF("config/udev: failed to bind the udev monitor\n");
        return 0;
    }
    return 1;
}

int config_udev_init()
{
    udev* udev = void;
    udev_enumerate* enumerate = void;
    udev_list_entry* devices = void, device = void;

    udev = assumeNoGC(&udev_monitor_get_udev)(udev_monitor_);
    enumerate = assumeNoGC(&udev_enumerate_new)(udev);
    if (!enumerate)
        return 0;

    assumeNoGC(&udev_enumerate_add_match_subsystem)(enumerate, "input");
    assumeNoGC(&udev_enumerate_add_match_subsystem)(enumerate, "tty");
static if (CONFIG_UDEV_KMS) {
    assumeNoGC(&udev_enumerate_add_match_subsystem)(enumerate, "drm");
}

version (HAVE_UDEV_ENUMERATE_ADD_MATCH_TAG) {
    if (mixin(ServerIsNotSeat0!()))
        udev_enumerate_add_match_tag(enumerate, dixSettingSeatId);
}

    assumeNoGC(&udev_enumerate_scan_devices)(enumerate);
    devices = assumeNoGC(&udev_enumerate_get_list_entry)(enumerate);
    mixin(udev_list_entry_foreach!("device", "devices", q{
        const(char)* syspath = assumeNoGC(&udev_list_entry_get_name)(device);
        udev_device* udev_device = assumeNoGC(&udev_device_new_from_syspath)(udev, syspath);

        /* Device might be gone by the time we try to open it */
        if (!udev_device)
            continue;

        device_added_udev(udev_device);
        assumeNoGC(&udev_device_unref)(udev_device);
    }));

    udev_enumerate_unref(enumerate);

    SetNotifyFd(assumeNoGC(&udev_monitor_get_fd)(udev_monitor_), &udev_socket_handler, X_NOTIFY_READ, null);

    return 1;
}

void config_udev_fini()
{
    udev* udev = void;

    if (!udev_monitor_)
        return;

    udev = assumeNoGC(&udev_monitor_get_udev)(udev_monitor_);

    RemoveNotifyFd(assumeNoGC(&udev_monitor_get_fd)(udev_monitor_));
    assumeNoGC(&udev_monitor_unref)(udev_monitor_);
    udev_monitor_ = null;
    assumeNoGC(&udev_unref)(udev);
}

static if (CONFIG_UDEV_KMS) {

/* Find the last occurrence of the needle in haystack */
private char* strrstr(const(char)* haystack, const(char)* needle)
{
    char* prev = void, last = void, tmp = void;

    prev = cast(char*) strstr(haystack, needle);
    if (!prev)
        return null;

    last = prev;
    tmp = prev + 1;

    while (tmp) {
        last = strstr(tmp, needle);
        if (!last)
            return prev;
        else {
            prev = last;
            tmp = prev + 1;
        }
    }

    return last;
}

/* For certain devices udev does not create ID_PATH entry (which is presumably a bug
 * in udev). We work around that by implementing a minimal ID_PATH calculator
 * ourselves along the same logic that udev uses. This works only for the case of
 * a PCI device being directly connected to a PCI bus, but it will cover most end
 * users with e.g. a new laptop which only has beta hardware driver support.
 * See https://gitlab.freedesktop.org/xorg/xserver/-/issues/993 */
private char* config_udev_get_fallback_bus_id(udev_device* udev_device)
{
    const(char)* sysname = void;
    char* busid = void;

    udev_device = assumeNoGC(&udev_device_get_parent)(udev_device);
    if (udev_device is null)
        return null;

    if (strcmp(assumeNoGC(&udev_device_get_subsystem)(udev_device), "pci") != 0)
        return null;

    sysname = assumeNoGC(&udev_device_get_sysname)(udev_device);
    busid = cast(char*)XNFalloc(strlen(sysname) + 5);
    busid[0] = '\0';
    strcat(busid, "pci:");
    strcat(busid, sysname);

    return busid;
}

private void config_udev_odev_setup_attribs(udev_device* udev_device, const(char)* path, const(char)* syspath, uint major, uint minor, config_odev_probe_proc_ptr probe_callback)
{
    OdevAttributes* attribs = config_odev_allocate_attributes();
    const(char)* value = void, str = void;

    attribs.path = XNFstrdup(path);
    attribs.syspath = XNFstrdup(syspath);
    attribs.major = major;
    attribs.minor = minor;

    value = assumeNoGC(&udev_device_get_property_value)(udev_device, "ID_PATH");
    if (value && (str = strrstr(value, "pci-")) !is null) {
        value = str;

        if ((str = strstr(value, "usb-")) !is null)
            value = str;

        attribs.busid = XNFstrdup(value);
        attribs.busid[3] = ':';
    } else if (value && (str = strrstr(value, "platform-")) !is null) {
        value = str + 9;
        attribs.busid = XNFstrdup(value);
    }

    if (!value)
        attribs.busid = config_udev_get_fallback_bus_id(udev_device);

    /* ownership of attribs is passed to probe layer */
    probe_callback(attribs);
}

void config_udev_odev_probe(config_odev_probe_proc_ptr probe_callback)
{
    udev* udev = void;
    udev_enumerate* enumerate = void;
    udev_list_entry* devices = void, device = void;

    udev = assumeNoGC(&udev_monitor_get_udev)(udev_monitor_);
    enumerate = assumeNoGC(&udev_enumerate_new)(udev);
    if (!enumerate)
        return;

    assumeNoGC(&udev_enumerate_add_match_subsystem)(enumerate, "drm");
    udev_enumerate_add_match_sysname(enumerate, "card[0-9]*");
version (HAVE_UDEV_ENUMERATE_ADD_MATCH_TAG) {
    if (mixin(ServerIsNotSeat0!()))
        udev_enumerate_add_match_tag(enumerate, dixSettingSeatId);
}
    assumeNoGC(&udev_enumerate_scan_devices)(enumerate);
    devices = assumeNoGC(&udev_enumerate_get_list_entry)(enumerate);
    mixin(udev_list_entry_foreach!("device", "devices", q{
        const(char)* syspath = assumeNoGC(&udev_list_entry_get_name)(device);
        udev_device* udev_device = assumeNoGC(&udev_device_new_from_syspath)(udev, syspath);
        const(char)* path = assumeNoGC(&udev_device_get_devnode)(udev_device);
        const(char)* sysname = assumeNoGC(&udev_device_get_sysname)(udev_device);
        dev_t devnum = assumeNoGC(&udev_device_get_devnum)(udev_device);
        const(char)* subsys = assumeNoGC(&udev_device_get_subsystem)(udev_device);

        if (!path || !syspath || !subsys)
            goto no_probe;
        else if (strcmp(subsys, "drm") != 0)
            goto no_probe;
        else if (strncmp(sysname, "card", 4) != 0)
            goto no_probe;
        else if (!check_seat(udev_device))
            goto no_probe;

        config_udev_odev_setup_attribs(udev_device, path, syspath, major(devnum),
                                       minor(devnum), probe_callback);
    no_probe:
        assumeNoGC(&udev_device_unref)(udev_device);
    }));
    udev_enumerate_unref(enumerate);
    return;
}
}

