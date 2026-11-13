module stub_video;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import hw.xfree86.os_support.xf86_os_support;
import hw.xfree86.os_support.xf86_OSlib;

void xf86OSInitVidMem(VidMemInfoPtr pVidMem)
{
    pVidMem.initialised = True;
    return;
}
