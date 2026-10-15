module include.misc;
@nogc nothrow:
extern(C): __gshared:

template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

Copyright 1992, 1993 Data General Corporation;
Copyright 1992, 1993 OMRON Corporation

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that the
above copyright notice appear in all copies and that both that copyright
notice and this permission notice appear in supporting documentation, and that
neither the name OMRON or DATA GENERAL be used in advertising or publicity
pertaining to distribution of the software without specific, written prior
permission of the party whose name is to be used.  Neither OMRON or
DATA GENERAL make any representation about the suitability of this software
for any purpose.  It is provided "as is" without express or implied warranty.

OMRON AND DATA GENERAL EACH DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS,
IN NO EVENT SHALL OMRON OR DATA GENERAL BE LIABLE FOR ANY SPECIAL, INDIRECT
OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
OF THIS SOFTWARE.

******************************************************************/
version (MISC_H) {} else {
enum MISC_H = 1;
/*
 *  X internal definitions
 *
 */

// public import x11.Xosdefs;
public import x11.Xmd;
public import x11.X;
// public import x11.Xdefs;
public import x11.Xprotostr;
import include.dixstruct;

public import core.stdc.stddef;
public import core.stdc.stdint;
public import core.sys.posix.pthread;
import dsl.pixman;
public import include.scrintstr;

enum MAXSCREENS =	16;

enum MAXGPUSCREENS =	16;

enum MAXFORMATS =	8;
enum MAXDEVICES =	256      /* input devices */;

enum GPU_SCREEN_OFFSET = 256;

/* 128 event opcodes for core + extension events, excluding GE */
enum MAXEVENTS =       128;
enum EXTENSION_EVENT_BASE = 64;
enum EXTENSION_BASE = 128;

alias ATOM = uint;

public import externs.libdbus;


/* @brief generic X return code
 *
 * this type is should be used instead of plain int for all functions
 * returning and X error code (that's possibly sent to the client),
 * in order to make return value semantics clear to the humen reader.
 *
 * part of public SDK / driver API.
 */
alias XRetCode = int;

version (TRUE) {} else {
// enum TRUE = 1;
// enum FALSE = 0;
}

public import include.os;                 /* for ALLOCATE_LOCAL and DEALLOCATE_LOCAL */
//public import x11.X;         /* for bcopy, bzero, and bcmp */

enum NullBox = cast(BoxPtr)0;

/* @deprecated */
auto min(T, S) (T a, S b) {
    return a < b ? a : b;
}

auto max(T, S) (T a, S b) {
    return a > b ? a : b;
}
// enum string min(string a, string b) = `(((` ~ a ~ `) < (` ~ b ~ `)) ? (` ~ a ~ `) : (` ~ b ~ `))`;
// enum string max(string a, string b) = `(((` ~ a ~ `) > (` ~ b ~ `)) ? (` ~ a ~ `) : (` ~ b ~ `))`;
/* abs() is a function, not a macro; include the file declaring
 * it in case we haven't done that yet.
 */
/* this assumes b > 0 */
enum string modulus(string a, string b, string d) = `if (((` ~ d ~ `) = (` ~ a ~ `) % (` ~ b ~ `)) < 0) (` ~ d ~ `) += (` ~ b ~ `);`;

/* XXX Not for modules */
public import core.stdc.limits;
static if (!HasVersion!"MAXSHORT" || !HasVersion!"MINSHORT" || 
    !HasVersion!"MAXINT" || !HasVersion!"MININT") {
/*
 * Some implementations #define these through <math.h>, so preclude
 * #include'ing it later.
 */

public import core.stdc.math;
enum MAXSHORT = SHRT_MAX;
enum MINSHORT = SHRT_MIN;
enum MAXINT = INT_MAX;
enum MININT = INT_MIN;

public import core.stdc.assert_;
public import core.stdc.ctype;
public import core.stdc.stdio;              /* for fopen, etc... */

}

/**
 * Calculate the number of bytes needed to hold bits.
 * @param bits The minimum number of bits needed.
 * @return The number of bytes needed to hold bits.
 */
pragma(inline, true) int bits_to_bytes(const(int) bits)
{
    return ((bits + 7) >> 3);
}

/**
 * Calculate the number of 4-byte units needed to hold the given number of
 * bytes.
 * @param bytes The minimum number of bytes needed.
 * @return The number of 4-byte units needed to hold bytes.
 */
pragma(inline, true) CARD32 bytes_to_int32(const(size_t) bytes)
{
    return cast(CARD32)(((bytes) + 3) >> 2);
}

/**
 * Calculate the number of bytes (in multiples of 4) needed to hold bytes.
 * @param bytes The minimum number of bytes needed.
 * @return The closest multiple of 4 that is equal or higher than bytes.
 */
pragma(inline, true) int pad_to_int32(const(int) bytes)
{
    return (((bytes) + 3) & ~3);
}

/**
 * Calculate padding needed to bring the number of bytes to an even
 * multiple of 4.
 * @param bytes The minimum number of bytes needed.
 * @return The bytes of padding needed to arrive at the closest multiple of 4
 * that is equal or higher than bytes.
 */
pragma(inline, true) int padding_for_int32(const(int) bytes)
{
    return ((-bytes) & 3);
}

/* some macros to help swap requests, replies, and events */

enum string LengthRestS(string stuff) = `
    (client.req_len << 1) - ((*` ~ stuff ~ `).sizeof >> 1)`;

enum string SwapRestS(string stuff) = `
    SwapShorts(cast(short*)(` ~ stuff ~ ` + 1), ` ~ LengthRestS!(stuff) ~ `);`;

static if (HasVersion!"__GNUC__" && ((__GNUC__ > 4) || (__GNUC__ == 4 && __GNUC_MINOR__ >= 3))) {

} else {
pragma(inline, true) void wrong_size()
{
}
}

static if (!(HasVersion!"__GNUC__")) {
pragma(inline, true) int __builtin_constant_p(int x)
{
    return 0;
}
}

pragma(inline, true) ulong bswap_64(ulong x)
{
    return (((x & 0xFF00000000000000uL) >> 56) |
            ((x & 0x00FF000000000000uL) >> 40) |
            ((x & 0x0000FF0000000000uL) >> 24) |
            ((x & 0x000000FF00000000uL) >>  8) |
            ((x & 0x00000000FF000000uL) <<  8) |
            ((x & 0x0000000000FF0000uL) << 24) |
            ((x & 0x000000000000FF00uL) << 40) |
            ((x & 0x00000000000000FFuL) << 56));
}

ref auto swapll(T)(T* t) {
		if (T.sizeof != 8) 
			wrong_size(); 
		*t = cast(ulong)bswap_64(*t);          
}

pragma(inline, true) uint bswap_32(uint x)
{
    return (((x & 0xFF000000) >> 24) |
            ((x & 0x00FF0000) >> 8) |
            ((x & 0x0000FF00) << 8) |
            ((x & 0x000000FF) << 24));
}

ref auto swapl(T)(T* t) {
		if (T.sizeof != 4) 
			wrong_size(); 
		*t = cast(ulong)bswap_32(cast(uint)*(t)); 
}

pragma(inline, true) ushort bswap_16(ushort x)
{
    return (((x & 0xFF00) >> 8) |
            ((x & 0x00FF) << 8));
}

// enum string swaps(string x) = `do { 
// 		if (typeof(*(` ~ x ~ `)).sizeof != 2) 
// 			wrong_size(); 
// 		*(` ~ x ~ `) = bswap_16(*(` ~ x ~ `)); 
// 	} while (0)`;

void swaps(T)(T* x) {
    if (typeof(*x).sizeof != 2) 
			wrong_size(); 
	*x = bswap_16(*x); 
}

/* copy 32-bit value from src to dst byteswapping on the way */
// enum string cpswapl(string src, string dst) = `do { 
// 		if (typeof((` ~ src ~ `)).sizeof != 4 || typeof((` ~ dst ~ `)).sizeof != 4) 
// 			wrong_size(); 
// 		(` ~ dst ~ `) = bswap_32((` ~ src ~ `)); 
// 	} while (0)`;\

void cpswapl(T, U)(ref T src, ref U dst) {
    if (typeof(src).sizeof != 4 || typeof(dst).sizeof != 4)
			wrong_size(); 
		dst = bswap_32(cast(uint)src); 
}

/* copy short from src to dst byteswapping on the way */
// enum string cpswaps(string src, string dst) = `do { 
// 		if (typeof((` ~ src ~ `)).sizeof != 2 || typeof((` ~ dst ~ `)).sizeof != 2) 
// 			wrong_size(); 
// 		(` ~ dst ~ `) = bswap_16((` ~ src ~ `)); 
// 	} while (0)`;

// enum string cpswap(string src, string dst) = `do { 
// 		if (typeof((` ~ src ~ `)).sizeof != 2 || typeof((` ~ dst ~ `)).sizeof != 2) 
// 			wrong_size(); 
// 		(` ~ dst ~ `) = bswap_16((` ~ src ~ `)); 
// 	} while (0)`;


void cpswaps(T, U)(ref T src, ref U dst) {
    if (typeof(src).sizeof != 2 || typeof(dst).sizeof != 2) 
			wrong_size(); 
		dst = bswap_16(src); 
}

// void SwapShorts(short* list, c_ulong count);

alias DDXPointPtr = xPoint*;
alias BoxPtr = pixman_box16*;
alias xEventPtr = _xEvent*;
alias xRectanglePtr = xRectangle*;
// struct _GrabRec;
alias GrabPtr = GrabRec*;

alias x_server_generation_t = c_ulong;

// static ulong globalSerialNumber = 0;
// x_server_generation_t serverGeneration;

}                          /* MISC_H */
