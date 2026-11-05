module config.hotplug_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
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
 
// //public import x11.Xfuncproto;

public import dix.settings_priv;

import common.list;

// import hw.xfree86.drivers.video.modesetting.driver;

/* Bump this each time you add something to the struct
 * so that drivers can easily tell what is available
 */
enum ODEV_ATTRIBUTES_VERSION =         1;

struct OdevAttributes {
    /* path to kernel device node - Linux e.g. /dev/dri/card0 */
    char* path;

    /* system device path - Linux e.g. /sys/devices/pci0000:00/0000:00:01.0/0000:01:00.0/drm/card1 */
    char* syspath;

    /* DRI-style bus id */
    char* busid;

    /* Server managed FD */
    int fd;

    /* Major number of the device node pointed to by ODEV_ATTRIB_PATH */
    uint major;

    /* Minor number of the device node pointed to by ODEV_ATTRIB_PATH */
    uint minor;

    /* kernel driver name */
    char* driver;
}

/* Note starting with xserver 1.16 this function never fails */
OdevAttributes* config_odev_allocate_attributes();

void config_odev_free_attributes(OdevAttributes* attribs);

alias config_odev_probe_proc_ptr = void function(OdevAttributes* attribs);
void config_odev_probe(config_odev_probe_proc_ptr probe_callback);

version (CONFIG_UDEV_KMS) {
void NewGPUDeviceRequest(OdevAttributes* attribs);
void DeleteGPUDeviceRequest(OdevAttributes* attribs);
}

enum string ServerIsNotSeat0() = `(dixSettingSeatId && strcmp(dixSettingSeatId, "seat0"))`;

// xf86_platform_device* xf86_find_platform_device_by_devnum(uint major, uint minor);

void config_pre_init();

void config_init();
void config_fini();

 /* _XSERVER_HOTPLUG_PRIV_H */
