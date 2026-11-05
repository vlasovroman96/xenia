module xf86int10module;
@nogc nothrow:
extern(C): __gshared:
/*
 *                   XFree86 int10 module
 *   execute BIOS int 10h calls in x86 real mode environment
 *                 Copyright 1999 Egbert Eich
 */
import build.xorg_config;

import xf86Module_priv;

private XF86ModuleVersionInfo VersRecInt10 = {
    modname: "int10",
    vendor: MODULEVENDORSTRING,
    _modinfo1_: MODINFOSTRING1,
    _modinfo2_: MODINFOSTRING2,
    xf86version: XORG_VERSION_CURRENT,
    majorversion: 1,
    minorversion: 0,
    patchlevel: 0,
    abiclass: ABI_CLASS_VIDEODRV,
    abiversion: ABI_VIDEODRV_VERSION,
};

export XF86ModuleData int10ModuleData = {
    vers: &VersRecInt10
};
