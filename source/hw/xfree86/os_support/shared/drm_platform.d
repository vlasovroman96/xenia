module drm_platform;
@nogc nothrow:
extern(C): __gshared:
import build.xlibre_server;

static if(XSERVER_PLATFORM_BUS){

import externs.libdrm;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.stdc.errno;
import core.stdc.string;

import config.hotplug_priv;

/* Linux platform device support */
import include.xf86_OSproc;;

import xf86_priv;
import hw.xfree86.os_support.xf86_os_support;
import xf86platformBus_priv;
import xf86Bus;

import hw.xfree86.os_support.linux.systemd_logind;
import seatd_libseat;
import os.osdep;

import include.xf86;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;

import seatd_libseat;

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
import os.utils;
import externs.pciaccess;
import xf86pciBus;
import externs.gnu;

alias FALSE = include.misc.FALSE;

alias TRUE = include.misc.TRUE;
private Bool get_drm_info(OdevAttributes* attribs, char* path, int delayed_index)
{
    drmVersionPtr v = void;
    int fd = -1;
    int err = 0;
    Bool paused = FALSE, server_fd = FALSE;

    LogMessage(X_INFO, "Platform probe for %s\n", attribs.syspath);

    fd = seatd_libseat_open_graphics(path);
    if (fd >= 0) {
        attribs.fd = fd;
        server_fd = TRUE;
    } else {
       fd = systemd_logind_take_fd(attribs.major, attribs.minor, path, &paused);
       if (fd != -1) {
            if (paused) {
                LogMessage(X_ERROR,
                        "Error systemd-logind returned paused fd for drm node\n");
                systemd_logind_release_fd(attribs.major, attribs.minor, -1);
                return FALSE;
            }
            attribs.fd = fd;
            server_fd = TRUE;
        }
    }

    if (fd == -1) {
        /* Try opening the path directly */
        fd = open(path, O_RDWR | O_CLOEXEC, 0);
        if (fd == -1) {
            // xf86Msg(X_ERROR, "cannot open %s\n", path);
            return FALSE;
        }
    }

    /* for a delayed probe we've already added the device */
    if (delayed_index == -1) {
            xf86_add_platform_device(attribs, FALSE);
            delayed_index = xf86_num_platform_devices - 1;
    }

    if (server_fd)
        xf86_platform_devices[delayed_index].flags |= XF86_PDEV_SERVER_FD;

    v = drmGetVersion(fd);
    if (!v) {
        LogMessageVerb(X_ERROR, 1, "%s: failed to query DRM version\n", path);
        goto out_;
    }

    xf86_platform_odev_attributes(delayed_index).driver = cast(char*)XNFstrdup(v.name);
    drmFreeVersion(v);

out_:
    if (!server_fd)
        close(fd);
    return (err == 0);
}

Bool xf86PlatformDeviceCheckBusID(xf86_platform_device* device, const(char)* busid)
{
    const(char)* syspath = device.attribs.syspath;
    BusType bustype = void;
    const(char)* id = void;

    if (!syspath)
        return FALSE;

    bustype = StringToBusType(busid, &id);
    if (bustype == BUS_PCI) {
        pci_device* pPci = device.pdev;
        if (!pPci)
            return FALSE;

        if (xf86ComparePciBusString(busid,
                                    ((pPci.domain << 8)
                                     | pPci.bus),
                                    pPci.dev, pPci.func)) {
            return TRUE;
        }
    }
    else if (bustype == BUS_PLATFORM) {
        /* match on the minimum string */
        int len = cast(int)strlen(id);

        if (strlen(syspath) < strlen(id))
            len = cast(int)strlen(syspath);

        if (strncmp(id, syspath, len))
            return FALSE;
        return TRUE;
    }
    else if (bustype == BUS_USB) {
        if (strcasecmp(busid, device.attribs.busid))
            return FALSE;
        return TRUE;
    }
    return FALSE;
}

void xf86PlatformReprobeDevice(int index, OdevAttributes* attribs)
{
    Bool ret = void;
    char* dpath = attribs.path;

    ret = get_drm_info(attribs, dpath, index);
    if (ret == FALSE) {
        xf86_remove_platform_device(index);
        return;
    }
    ret = xf86platformAddDevice(xf86PlatformFindHotplugDriver(index), index);
    if (ret == -1)
        xf86_remove_platform_device(index);
}

void xf86PlatformDeviceProbe(OdevAttributes* attribs)
{
    int i = void;
    char* path = attribs.path;
    Bool ret = void;

    if (!path)
        goto out_free;

    for (i = 0; i < xf86_num_platform_devices; i++) {
        char* dpath = xf86_platform_odev_attributes(i).path;

        if (dpath && !strcmp(path, dpath))
            break;
    }

    if (i != xf86_num_platform_devices)
        goto out_free;

    LogMessage(X_INFO, "xfree86: Adding drm device (%s)\n", path);

    if (!xf86VTOwner()) {
            /* if we don't currently own the VT then don't probe the device,
               just mark it as unowned for later use */
            xf86_add_platform_device(attribs, TRUE);
            return;
    }

    ret = get_drm_info(attribs, path, -1);
    if (ret == FALSE)
        goto out_free;

    return;

out_free:
    config_odev_free_attributes(attribs);
}

void NewGPUDeviceRequest(OdevAttributes* attribs)
{
    int old_num = xf86_num_platform_devices;
    int ret = void;
    const(char)* driver_name = void;

    xf86PlatformDeviceProbe(attribs);

    if (old_num == xf86_num_platform_devices)
        return;

    if (xf86_get_platform_device_unowned(xf86_num_platform_devices - 1) == TRUE)
        return;

    /* Scan and update PCI devices before adding new platform device */
    xf86PlatformScanPciDev();
    driver_name = xf86PlatformFindHotplugDriver(xf86_num_platform_devices - 1);

    ret = xf86platformAddDevice(driver_name, xf86_num_platform_devices-1);
    if (ret == -1)
        xf86_remove_platform_device(xf86_num_platform_devices-1);

    ErrorF("xf86: found device %d\n", xf86_num_platform_devices);
    return;
}

void DeleteGPUDeviceRequest(OdevAttributes* attribs)
{
    int index = void;
    char* syspath = attribs.syspath;

    if (!syspath)
        goto out_;

    for (index = 0; index < xf86_num_platform_devices; index++) {
        char* dspath = xf86_platform_odev_attributes(index).syspath;
        if (dspath && !strcmp(syspath, dspath))
            break;
    }

    if (index == xf86_num_platform_devices)
        goto out_;

    ErrorF("xf86: remove device %d %s\n", index, syspath);

    if (xf86_get_platform_device_unowned(index) == TRUE)
            xf86_remove_platform_device(index);
    else
            xf86platformRemoveDevice(index);
out_:
    config_odev_free_attributes(attribs);
}

}
