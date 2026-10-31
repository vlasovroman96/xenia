module dix.devices_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import dix.callback;
import include.xlibre_ptrtypes;

/*
 * called when a client tries to access devices
 */
CallbackListPtr DeviceAccessCallback;

struct DeviceAccessCallbackParam {
    ClientPtr client;
    DeviceIntPtr dev;
    Mask access_mode;
    int status;
}

pragma(inline, true) int dixCallDeviceAccessCallback(ClientPtr client, DeviceIntPtr dev, Mask access_mode)
{
    DeviceAccessCallbackParam rec = { client, dev, access_mode, Success };
    CallCallbacks(&DeviceAccessCallback, &rec);
    return rec.status;
}

 /* _XSERVER_DIX_DEVICES_PRIV_H */
