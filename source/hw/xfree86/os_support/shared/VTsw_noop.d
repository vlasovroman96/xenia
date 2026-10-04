module VTsw_noop;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 1993 by David Wexelblat <dwex@XFree86.org>
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of David Wexelblat not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  David Wexelblat makes no representations
 * about the suitability of this software for any purpose.  It is provided
 * "as is" without express or implied warranty.
 *
 * DAVID WEXELBLAT DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL DAVID WEXELBLAT BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *
 */
import build.xorg_config;

//import x11.X;

import include.xf86;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSlib;

// /*
//  * No-op functions for OSs without VTs
//  */

// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// Bool xf86VTSwitchPending()
// {
//     return FALSE;
// }

// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// Bool xf86VTSwitchAway()
// {
//     return FALSE;
// }

// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// Bool xf86VTSwitchTo()
// {
//     return TRUE;
// }

// Bool xf86VTActivate(int vtno)
// {
//     return TRUE;
// }
