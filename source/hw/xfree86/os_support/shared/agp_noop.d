module agp_noop;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (c) 2000-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */

/*
 * Abstraction of the AGP GART interface.  Stubs for platforms without
 * AGP GART support.
 */
import build.xorg_config;

//import x11.X;

import hw.xfree86.common.xf86Helper;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import hw.xfree86.os_support.xf86_OSlib;
import hw.xfree86.os_support.xf86_os_support;

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86GARTCloseScreen(int screenNum)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86AgpGARTSupported()
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
AgpInfoPtr xf86GetAGPInfo(int screenNum)
{
    return null;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86AcquireGART(int screenNum)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86ReleaseGART(int screenNum)
{
    return FALSE;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86AllocateGARTMemory(int screenNum, c_ulong size, int type, c_ulong* physical)
{
    return -1;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86DeallocateGARTMemory(int screenNum, int key)
{
    return FALSE;
}

Bool xf86BindGARTMemory(int screenNum, int key, c_ulong offset)
{
    return FALSE;
}

Bool xf86UnbindGARTMemory(int screenNum, int key)
{
    return FALSE;
}
