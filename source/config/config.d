module config.config;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
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

import core.sys.posix.unistd;

import config.hotplug_priv;

import include.os;
import include.inputstr;
import config.config_backends;
import config.udev;
import hw.xfree86.os_support.linux.systemd_logind;
import os.log;
import dix.events;
import os.inputthread;
import xf86Events;


void config_pre_init()
{
    if (!config_udev_pre_init())
        ErrorF("[config] failed to pre-init udev\n");
}

void config_init()
{
version (CONFIG_UDEV) {
    if (!config_udev_init())
        ErrorF("[config] failed to initialise udev\n");
}
// } else version (CONFIG_HAL) {
//     if (!config_hal_init())
//         ErrorF("[config] failed to initialise HAL\n");
// } else version (CONFIG_WSCONS) {
//     if (!config_wscons_init())
//         ErrorF("[config] failed to initialise wscons\n");
// }
}

void config_fini()
{
version (CONFIG_UDEV) {
    config_udev_fini();
} else version (CONFIG_HAL) {
    config_hal_fini();
} else version (CONFIG_WSCONS) {
    config_wscons_fini();
}
}

void config_odev_probe(config_odev_probe_proc_ptr probe_callback)
{
static if (HasVersion!"CONFIG_UDEV" && HasVersion!"CONFIG_UDEV_KMS") {
    config_udev_odev_probe(probe_callback);
}
}

private void remove_device(const(char)* backend, DeviceIntPtr dev)
{
    /* this only gets called for devices that have already been added */
    LogMessage(X_INFO, "config/%s: removing device %s\n", backend, dev.name);

    /* Call PIE here so we don't try to dereference a device that's
     * already been removed. */
    input_lock();
    ProcessInputEvents();
    DeleteInputDeviceRequest(dev);
    input_unlock();
}

void remove_devices(const(char)* backend, const(char)* config_info)
{
    DeviceIntPtr dev = void, next = void;

    for (dev = inputInfo.devices; dev; dev = next) {
        next = dev.next;
        if (dev.config_info && strcmp(dev.config_info, config_info) == 0)
            remove_device(backend, dev);
    }
    for (dev = inputInfo.off_devices; dev; dev = next) {
        next = dev.next;
        if (dev.config_info && strcmp(dev.config_info, config_info) == 0)
            remove_device(backend, dev);
    }

    RemoveInputDeviceTraces(config_info);
}

BOOL device_is_duplicate(const(char)* config_info)
{
    DeviceIntPtr dev = void;

    for (dev = inputInfo.devices; dev; dev = dev.next) {
        if (dev.config_info && (strcmp(dev.config_info, config_info) == 0))
            return TRUE;
    }

    for (dev = inputInfo.off_devices; dev; dev = dev.next) {
        if (dev.config_info && (strcmp(dev.config_info, config_info) == 0))
            return TRUE;
    }

    return FALSE;
}

OdevAttributes* config_odev_allocate_attributes()
{
    OdevAttributes* attribs = cast(OdevAttributes*)XNFcallocarray(1, OdevAttributes.sizeof);
    attribs.fd = -1;
    return attribs;
}

void config_odev_free_attributes(OdevAttributes* attribs)
{
    if (attribs.fd != -1)
        systemd_logind_release_fd(attribs.major, attribs.minor, attribs.fd);
    free(attribs.path);
    free(attribs.syspath);
    free(attribs.busid);
    free(attribs.driver);
    free(attribs);
}
