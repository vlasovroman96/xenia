module xorgHelper;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

//import x11.X;

import include.xorgVersion;
import build.xlibre_server;

import os.os;
import common.servermd;
import dix.pixmap;
import dix.window;
import dix.property;
import dix.gc;
import hw.xfree86.loader.loaderProcs;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.common.xf86Priv;

CARD32 xorgGetVersion()
{
    return XORG_VERSION_CURRENT;
}
