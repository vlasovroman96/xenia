module seatd_libseat;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2022-2024 Mark Hindley, Ralph Ronnquist.
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
 * Authors: Mark Hindley <mark@hindley.org.uk>
 *          Ralph Ronnquist <ralph.ronnquist@gmail.com>
 */

 
public import x11.Xdefs;
import x11.Xmd;
import common.misc;

version = SEATD_LIBSEAT;
version (SEATD_LIBSEAT) {
public import hw.xfree86.common.xf86Xinput;
public import hw.xfree.os_support.shrd.seatd_libseat;
// public import 


// /**
//  * @brief seatd_libseat_open_graphics returns opened fd via rpc call through seatd
//  * @param path node path
//  * @warning this function returns <0 in case of error (for example -2)
//  * @return file descriptior or <0
//  *
//  * @warning void  is only for internal consuption (currently for modesetting only, because its `open_hw` function calls open directly)
//  *
//  * @note XXX: maybe in future Xlibre public api could gain function for opening device nodes by path?
//  **/





} else {

pragma(inline, true) int seatd_libseat_init(bool KeepTty_state) {cast(void)KeepTty_state; return -1; }
pragma(inline, true) void seatd_libseat_fini() {}
pragma(inline, true) int seatd_libseat_open_graphics(const(char)* path) {cast(void)path; return -1; }
pragma(inline, true) void seatd_libseat_open_device(void* p, int* fd, Bool* paus) { cast(void)p;cast(void)fd;cast(void)paus; }
pragma(inline, true) void seatd_libseat_close_device(void* p) { cast(void)p;}
pragma(inline, true) int seatd_libseat_switch_session(int session) { return -1; }
pragma(inline, true) Bool seatd_libseat_controls_session() { return FALSE; }

}


