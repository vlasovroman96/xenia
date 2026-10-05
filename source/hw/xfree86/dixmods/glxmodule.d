module glxmodule;
@nogc nothrow:
extern(C): __gshared:
/**************************************************************************

Copyright 1998-1999 Precision Insight, Inc., Cedar Park, Texas.
All Rights Reserved.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sub license, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice (including the
next paragraph) shall be included in all copies or substantial portions
of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-INFRINGEMENT.
IN NO EVENT SHALL PRECISION INSIGHT AND/OR ITS SUPPLIERS BE LIABLE FOR
ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

**************************************************************************/
/*
 * Authors:
 *   Kevin E. Martin <kevin@precisioninsight.com>
 *
 */
import build.xorg_config;

import include.xf86Module;
import include.xf86Priv;
import include.xf86;
import include.colormap;
import mi.micmap;
import include.globals;
import glx.glxserver;
import include.glx_extinit;
import build.xlibre_server;
import glx.glxext;

// private MODULESETUPPROTO glxSetup;

private XF86ModuleVersionInfo VersRecGLX = {
    modname: "glx",
    vendor: MODULEVENDORSTRING,
    _modinfo1_: MODINFOSTRING1,
    _modinfo2_: MODINFOSTRING2,
    xf86version: XORG_VERSION_CURRENT,
    majorversion: 1,
    minorversion: 0,
    patchlevel: 0,
    abiclass: ABI_CLASS_EXTENSION,
    abiversion: ABI_EXTENSION_VERSION,
};

XF86ModuleData glxModuleData = {
    vers: &VersRecGLX,
    setup: &glxSetup
};

private void* glxSetup(void* module_, void* opts, int* errmaj, int* errmin)
{
    static Bool setupDone = FALSE;
    __GLXprovider* provider = void;

    if (setupDone) {
        if (errmaj)
            *errmaj = LDR_ONCEONLY;
        return null;
    }

    setupDone = TRUE;

    provider = cast(__GLXprovider*)LoaderSymbol("__glXDRI2Provider");
    if (provider)
        GlxPushProvider(provider);
    xorgGlxCreateVendor();

    return module_;
}
