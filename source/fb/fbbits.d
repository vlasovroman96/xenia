module fb.fbbits;;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 1998 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;
import fb.wfbrename;
public import mi.miline;
import dix.timestamp;


mixin template Iteration8() {
	import fb.fbbits_h;
    alias fbBresSolid8 = BRESSOLID!(UNIT, BITS);
    alias fbBresDash8 = BRESDASH!(UNIT, BITS);
    alias fbDots8 = DOTS!(UNIT, BITS);
    alias fbArc8 = ARC!(UNIT, BITS);
    alias fbGlyph8 = GLYPH!(UNIT, BITS);
    alias fbPolyline8 = POLYLINE!(UNIT, BITS);
    alias fbPolySegment8 = POLYSEGMENT!(UNIT, BITS);
    alias BITS = BYTE;
    alias UNIT = BITS;

    alias BITS2 = CARD16;
    alias BITS4 = CARD32;
}

mixin template Iteration16() {
	import fb.fbbits_h;
    alias fbBresSolid16 = BRESSOLID!(UNIT, BITS);
    alias fbBresDash16 = BRESDASH!(UNIT, BITS);
    alias fbDots16 = DOTS!(UNIT, BITS);
    alias fbArc16 = ARC!(UNIT, BITS);
    alias fbGlyph16 = GLYPH!(UNIT, BITS);
    alias fbPolyline16 = POLYLINE!(UNIT, BITS);
    alias fbPolySegment16 = POLYSEGMENT!(UNIT, BITS);
    alias BITS = CARD16;
    alias BITS2 = CARD32;
alias UNIT = BITS;

}

mixin template Iteration32() {
    alias fbBresSolid32 = BRESSOLID!(UNIT, BITS);
    alias fbBresDash32 = BRESDASH!(UNIT, BITS);
    alias fbDots32 = DOTS!(UNIT, BITS);
    alias fbArc32 = ARC!(UNIT, BITS);
    alias fbGlyph32 = GLYPH!(UNIT, BITS);
    alias fbPolyline32 = POLYLINE!(UNIT, BITS);
    alias fbPolySegment32 = POLYSEGMENT!(UNIT, BITS);
    alias BITS = CARD32 ;
alias UNIT = BITS;


	import fb.fbbits_h;
}


mixin Iteration8 i8;
mixin Iteration16 i16;
mixin Iteration32 i32;