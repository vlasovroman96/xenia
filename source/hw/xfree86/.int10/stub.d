module stub;
@nogc nothrow:
extern(C): __gshared:
/*
 *                   XFree86 int10 module
 *   execute BIOS int 10h calls in x86 real mode environment
 *                 Copyright 1999 Egbert Eich
 */
import build.xorg_config;

import hw.xfree86.common.xf86Helper;
import include.xf86str;
import hw.xfree86.os_support.xf86_OSproc;;
version = _INT10_PRIVATE;
import xf86int10;


xf86Int10InfoPtr xf86InitInt10(int entityIndex)
{
    return xf86ExtendedInitInt10(entityIndex, 0);
}

xf86Int10InfoPtr xf86ExtendedInitInt10(int entityIndex, int Flags)
{
    return null;
}

Bool MapCurrentInt10(xf86Int10InfoPtr pInt)
{
    return FALSE;
}

void xf86FreeInt10(xf86Int10InfoPtr pInt)
{
    return;
}

void* xf86Int10AllocPages(xf86Int10InfoPtr pInt, int num, int* off)
{
    *off = 0;
    return null;
}

void xf86Int10FreePages(xf86Int10InfoPtr pInt, void* pbase, int num)
{
    return;
}

// Bool xf86Int10ExecSetup(xf86Int10InfoPtr pInt)
// {
//     return FALSE;
// }

void xf86ExecX86int10(xf86Int10InfoPtr pInt)
{
    return;
}

void* xf86int10Addr(xf86Int10InfoPtr pInt, uint addr)
{
    return 0;
}
