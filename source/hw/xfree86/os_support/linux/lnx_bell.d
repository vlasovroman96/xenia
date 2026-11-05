module lnx_bell;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2006 Daniel Stone
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Author: Daniel Stone <daniel@fooishbar.org>
 */
import build.xorg_config;

import core.sys.posix.sys.ioctl;
import externs.linux.kd;

import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import os.log_priv;

import os.os;
import xf86_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import hw.xfree86.os_support.xf86_OSproc;;
import include.xf86Privstr;

import os.log;
import xf86Events;
import xf86Globals;
import externs.linux.agpgart;


//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86OSRingBell(int loudness, int pitch, int duration)
{
    if (xf86Info.consoleFd == -1 || !pitch || !loudness)
        return;

    ioctl(xf86Info.consoleFd, KDMKTONE,
          ((1193190 / pitch) & 0xffff) |
          ((cast(c_ulong) duration * loudness / 50) << 16));
}
