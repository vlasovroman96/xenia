module externs.pixman.pixman_version;

/*
 * Copyright © 2008 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person
 * obtaining a copy of this software and associated documentation
 * files (the "Software"), to deal in the Software without
 * restriction, including without limitation the rights to use, copy,
 * modify, merge, publish, distribute, sublicense, and/or sell copies
 * of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be
 * included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND
 * NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS
 * BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN
 * ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Author: Carl D. Worth <cworth@cworth.org>
 */

enum PIXMAN_VERSION_MAJOR = 0;
enum PIXMAN_VERSION_MINOR = 46;
enum PIXMAN_VERSION_MICRO = 4;

enum PIXMAN_VERSION_STRING = "0.46.4";

auto PIXMAN_VERSION_ENCODE(Mj, Mn, Mc) (Mj major, Mn minor, Mc micro) => (	
	  ((major) * 10000)				
	+ ((minor) *   100)				
	+ ((micro) *     1));

auto PIXMAN_VERSION() => PIXMAN_VERSION_ENCODE(	
	PIXMAN_VERSION_MAJOR,			
	PIXMAN_VERSION_MINOR,			
	PIXMAN_VERSION_MICRO);
