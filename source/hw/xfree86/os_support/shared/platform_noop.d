module platform_noop;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import config.hotplug_priv;
import build.xlibre_server;
static if(XSERVER_PLATFORM_BUS){
/* noop platform device support */
import include.xf86_OSproc;;

import include.xf86;
import hw.xfree86.os_support.xf86_os_support;
import xf86platformBus_priv;

// Bool xf86PlatformDeviceCheckBusID(xf86_platform_device* device, const(char)* busid)
// {
//     return FALSE;
// }

// void xf86PlatformDeviceProbe(OdevAttributes* attribs)
// {
// }

// void xf86PlatformReprobeDevice(int index, OdevAttributes* attribs)
// {
// }

// void DeleteGPUDeviceRequest(OdevAttributes* attribs)
// {
// }

// void NewGPUDeviceRequest(OdevAttributes* attribs)
// {
// }

}
