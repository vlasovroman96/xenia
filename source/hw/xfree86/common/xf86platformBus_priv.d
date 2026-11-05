module xf86platformBus_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import xf86platformBus;
import include.xf86str;
public import config.hotplug_priv;
import build.xlibre_server;

static if(XSERVER_PLATFORM_BUS){

// int xf86_num_platform_devices;
// xf86_platform_device* xf86_platform_devices;

pragma(inline, true) OdevAttributes* xf86_platform_odev_attributes(int index)
{
    xf86_platform_device* device = &xf86_platform_devices[index];
    return device.attribs;
}

pragma(inline, true) OdevAttributes* xf86_platform_device_odev_attributes(xf86_platform_device* device)
{
    return device.attribs;
}

// int xf86platformProbe();
// int xf86platformProbeDev(DriverPtr drvp);


// void xf86PlatformScanPciDev();
// const(char)* xf86PlatformFindHotplugDriver(int dev_index);

// int xf86_add_platform_device(OdevAttributes* attribs, Bool unowned);
// int xf86_remove_platform_device(int dev_index);
// Bool xf86_get_platform_device_unowned(int index);

// int xf86platformAddDevice(const(char)* driver_name, int index);
// void xf86platformRemoveDevice(int index);

// void xf86platformVTProbe();
// void xf86platformPrimary();

// } else { /* XSERVER_PLATFORM_BUS */

// pragma(inline, true) int xf86platformAddGPUDevices(DriverPtr drvp) { return FALSE; }
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// pragma(inline, true) void xf86MergeOutputClassOptions(int index, void** options) {}

} /* XSERVER_PLATFORM_BUS */

 /* _XSERVER_XF86_PLATFORM_BUS_PRIV_H */
