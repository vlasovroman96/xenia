module externs.pixman.pixman;

extern(C):
@nogc: nothrow:
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

******************************************************************/
/*
 * Copyright © 1998, 2004 Keith Packard
 * Copyright   2007 Red Hat, Inc.
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


import externs.pixman.pixman_version;

/*
 * Standard integers
 */

// #if !defined (PIXMAN_DONT_DEFINE_STDINT)

// #if defined (_SVR4) || defined (SVR4) || defined (__OpenBSD__) || defined (_sgi) || defined (__sun) || defined (sun) || defined (__digital__) || defined (__HP_cc)
// #  include <inttypes.h>
// /* VS 2010 (_MSC_VER 1600) has stdint.h */
// #elif defined (_MSC_VER) && _MSC_VER < 1600
// typedef __int8 int8_t;
// typedef unsigned __int8 uint8_t;
// typedef __int16 int16_t;
// typedef unsigned __int16 uint16_t;
// typedef __int32 int32_t;
// typedef unsigned __int32 uint32_t;
// typedef __int64 int64_t;
// typedef unsigned __int64 uint64_t;
// #elif defined (_AIX)
// #  include <sys/inttypes.h>
// #else
// #  include <stdint.h>
// #endif

// #endif

import core.stdc.stdint;

/*
 * Boolean
 */
alias pixman_bool_t = int;

/*
 * Fixpoint numbers
 */
alias pixman_fixed_32_32_t = int64_t;
alias pixman_fixed_48_16_t = pixman_fixed_32_32_t;
alias pixman_fixed_1_31_t = uint32_t;
alias pixman_fixed_1_16_t = uint32_t;
alias pixman_fixed_16_16_t = int32_t;
alias pixman_fixed_t = pixman_fixed_16_16_t;

enum pixman_fixed_t pixman_fixed_e = 1;
enum pixman_fixed_1 = pixman_int_to_fixed(1);
enum pixman_fixed_1_minus_e =		pixman_fixed_1 - pixman_fixed_e;
enum pixman_fixed_minus_1 = pixman_int_to_fixed(-1);
enum pixman_min_fixed_48_16 =		-(cast(pixman_fixed_48_16_t) 1 << 31);
enum pixman_max_fixed_48_16 =		cast(pixman_fixed_48_16_t) 0x7fffffff;

auto pixman_fixed_to_int(F)(F f) =>		cast(int) (f >> 16);
auto pixman_int_to_fixed(I)(I i) =>	cast(pixman_fixed_t) (cast(uint32_t)i << 16);
auto pixman_fixed_to_double(F)(F f) =>	cast(double) (f / cast(double) pixman_fixed_1);
auto pixman_double_to_fixed(D)(D d) =>	cast(pixman_fixed_t) (d * 65536.0);
auto pixman_fixed_frac(F)(F f) =>		f & pixman_fixed_1_minus_e;
auto pixman_fixed_floor(F)(F f) =>		(f) & ~pixman_fixed_1_minus_e;
auto pixman_fixed_ceil(F)(F f) =>		pixman_fixed_floor (f + pixman_fixed_1_minus_e);
auto pixman_fixed_fraction(F)(F f) =>	f & pixman_fixed_1_minus_e;
auto pixman_fixed_mod_2(F)(F f) =>		f & (pixman_fixed1 | pixman_fixed_1_minus_e);

/*
 * Misc structs
 */
alias pixman_color_t = pixman_color;
alias pixman_point_fixed_t = pixman_point_fixed;
alias pixman_line_fixed_t = pixman_line_fixed;
alias pixman_vector_t = pixman_vector;
alias pixman_transform_t = pixman_transform;

struct pixman_color
{
    uint16_t	red;
    uint16_t    green;
    uint16_t    blue;
    uint16_t    alpha;
}

struct pixman_point_fixed
{
    pixman_fixed_t	x;
    pixman_fixed_t	y;
}

struct pixman_line_fixed
{
    pixman_point_fixed_t	p1, p2;
}

/*
 * Fixed point matrices
 */

struct pixman_vector
{
    pixman_fixed_t[3]	vector;
}

struct pixman_transform
{
    pixman_fixed_t[3][3]	matrix;
}

/* forward declaration (sorry) */
// struct pixman_box16;
union pixman_image; 
alias pixman_image_t = pixman_image;

void          pixman_transform_init_identity    (pixman_transform       *matrix);

pixman_bool_t pixman_transform_point_3d         (const pixman_transform *transform,
						 pixman_vector          *vector);

pixman_bool_t pixman_transform_point            (const pixman_transform *transform,
						 pixman_vector          *vector);

pixman_bool_t pixman_transform_multiply         (pixman_transform       *dst,
						 const pixman_transform *l,
						 const pixman_transform *r);

void          pixman_transform_init_scale       (pixman_transform       *t,
						 pixman_fixed_t                 sx,
						 pixman_fixed_t                 sy);

pixman_bool_t pixman_transform_scale            (pixman_transform       *forward,
						 pixman_transform       *reverse,
						 pixman_fixed_t                 sx,
						 pixman_fixed_t                 sy);

void          pixman_transform_init_rotate      (pixman_transform       *t,
						 pixman_fixed_t                 cos,
						 pixman_fixed_t                 sin);

pixman_bool_t pixman_transform_rotate           (pixman_transform       *forward,
						 pixman_transform       *reverse,
						 pixman_fixed_t                 c,
						 pixman_fixed_t                 s);

void          pixman_transform_init_translate   (pixman_transform       *t,
						 pixman_fixed_t                 tx,
						 pixman_fixed_t                 ty);

pixman_bool_t pixman_transform_translate        (pixman_transform       *forward,
						 pixman_transform       *reverse,
						 pixman_fixed_t                 tx,
						 pixman_fixed_t                 ty);

pixman_bool_t pixman_transform_bounds           (const pixman_transform *matrix,
						 pixman_box16           *b);

pixman_bool_t pixman_transform_invert           (pixman_transform       *dst,
						 const pixman_transform *src);

pixman_bool_t pixman_transform_is_identity      (const pixman_transform *t);

pixman_bool_t pixman_transform_is_scale         (const pixman_transform *t);

pixman_bool_t pixman_transform_is_int_translate (const pixman_transform *t);

pixman_bool_t pixman_transform_is_inverse       (const pixman_transform *a,
						 const pixman_transform *b);

/*
 * Floating point matrices
 */
alias pixman_f_transform_t = pixman_f_transform ;
alias pixman_f_vector_t = pixman_f_vector ;

struct pixman_f_vector
{
    double[3]  v;
}

struct pixman_f_transform
{
    double[3][3]  m;
}


pixman_bool_t pixman_transform_from_pixman_f_transform (pixman_transform         *t,
							const pixman_f_transform *ft);

void          pixman_f_transform_from_pixman_transform (pixman_f_transform       *ft,
							const pixman_transform   *t);

pixman_bool_t pixman_f_transform_invert                (pixman_f_transform       *dst,
							const pixman_f_transform *src);

pixman_bool_t pixman_f_transform_point                 (const pixman_f_transform *t,
							pixman_f_vector          *v);

void          pixman_f_transform_point_3d              (const pixman_f_transform *t,
							pixman_f_vector          *v);

void          pixman_f_transform_multiply              (pixman_f_transform       *dst,
							const pixman_f_transform *l,
							const pixman_f_transform *r);

void          pixman_f_transform_init_scale            (pixman_f_transform       *t,
							double                           sx,
							double                           sy);

pixman_bool_t pixman_f_transform_scale                 (pixman_f_transform       *forward,
							pixman_f_transform       *reverse,
							double                           sx,
							double                           sy);

void          pixman_f_transform_init_rotate           (pixman_f_transform       *t,
							double                           cos,
							double                           sin);

pixman_bool_t pixman_f_transform_rotate                (pixman_f_transform       *forward,
							pixman_f_transform       *reverse,
							double                           c,
							double                           s);

void          pixman_f_transform_init_translate        (pixman_f_transform       *t,
							double                           tx,
							double                           ty);

pixman_bool_t pixman_f_transform_translate             (pixman_f_transform       *forward,
							pixman_f_transform       *reverse,
							double                           tx,
							double                           ty);

pixman_bool_t pixman_f_transform_bounds                (const pixman_f_transform *t,
							pixman_box16             *b);

void          pixman_f_transform_init_identity         (pixman_f_transform       *t);

enum pixman_repeat_t
{
    PIXMAN_REPEAT_NONE,
    PIXMAN_REPEAT_NORMAL,
    PIXMAN_REPEAT_PAD,
    PIXMAN_REPEAT_REFLECT
}

alias PIXMAN_REPEAT_NONE = pixman_repeat_t.PIXMAN_REPEAT_NONE;
alias PIXMAN_REPEAT_NORMAL = pixman_repeat_t.PIXMAN_REPEAT_NORMAL;
alias PIXMAN_REPEAT_PAD = pixman_repeat_t.PIXMAN_REPEAT_PAD;
alias PIXMAN_REPEAT_REFLECT = pixman_repeat_t.PIXMAN_REPEAT_REFLECT;

enum pixman_dither_t
{
    PIXMAN_DITHER_NONE,
    PIXMAN_DITHER_FAST,
    PIXMAN_DITHER_GOOD,
    PIXMAN_DITHER_BEST,
    PIXMAN_DITHER_ORDERED_BAYER_8,
    PIXMAN_DITHER_ORDERED_BLUE_NOISE_64,
} ;

enum pixman_filter_t
{
    PIXMAN_FILTER_FAST,
    PIXMAN_FILTER_GOOD,
    PIXMAN_FILTER_BEST,
    PIXMAN_FILTER_NEAREST,
    PIXMAN_FILTER_BILINEAR,
    PIXMAN_FILTER_CONVOLUTION,

    /* The SEPARABLE_CONVOLUTION filter takes the following parameters:
     *
     *         width:           integer given as 16.16 fixpoint number
     *         height:          integer given as 16.16 fixpoint number
     *         x_phase_bits:	integer given as 16.16 fixpoint
     *         y_phase_bits:	integer given as 16.16 fixpoint
     *         xtables:         (1 << x_phase_bits) tables of size width
     *         ytables:         (1 << y_phase_bits) tables of size height
     *
     * When sampling at (x, y), the location is first rounded to one of
     * n_x_phases * n_y_phases subpixel positions. These subpixel positions
     * determine an xtable and a ytable to use.
     *
     * Conceptually a width x height matrix is then formed in which each entry
     * is the product of the corresponding entries in the x and y tables.
     * This matrix is then aligned with the image pixels such that its center
     * is as close as possible to the subpixel location chosen earlier. Then
     * the image is convolved with the matrix and the resulting pixel returned.
     */
    PIXMAN_FILTER_SEPARABLE_CONVOLUTION
}

alias     PIXMAN_FILTER_FAST = pixman_filter_t.PIXMAN_FILTER_FAST;
alias     PIXMAN_FILTER_GOOD = pixman_filter_t.PIXMAN_FILTER_GOOD;
alias     PIXMAN_FILTER_BEST = pixman_filter_t.PIXMAN_FILTER_BEST;
alias     PIXMAN_FILTER_NEAREST = pixman_filter_t.PIXMAN_FILTER_NEAREST;
alias     PIXMAN_FILTER_BILINEAR = pixman_filter_t.PIXMAN_FILTER_BILINEAR;
alias     PIXMAN_FILTER_CONVOLUTION = pixman_filter_t.PIXMAN_FILTER_CONVOLUTION;
alias     PIXMAN_FILTER_SEPARABLE_CONVOLUTION = pixman_filter_t.PIXMAN_FILTER_SEPARABLE_CONVOLUTION;

enum pixman_op_t
{
    PIXMAN_OP_CLEAR			= 0x00,
    PIXMAN_OP_SRC			= 0x01,
    PIXMAN_OP_DST			= 0x02,
    PIXMAN_OP_OVER			= 0x03,
    PIXMAN_OP_OVER_REVERSE		= 0x04,
    PIXMAN_OP_IN			= 0x05,
    PIXMAN_OP_IN_REVERSE		= 0x06,
    PIXMAN_OP_OUT			= 0x07,
    PIXMAN_OP_OUT_REVERSE		= 0x08,
    PIXMAN_OP_ATOP			= 0x09,
    PIXMAN_OP_ATOP_REVERSE		= 0x0a,
    PIXMAN_OP_XOR			= 0x0b,
    PIXMAN_OP_ADD			= 0x0c,
    PIXMAN_OP_SATURATE			= 0x0d,

    PIXMAN_OP_DISJOINT_CLEAR		= 0x10,
    PIXMAN_OP_DISJOINT_SRC		= 0x11,
    PIXMAN_OP_DISJOINT_DST		= 0x12,
    PIXMAN_OP_DISJOINT_OVER		= 0x13,
    PIXMAN_OP_DISJOINT_OVER_REVERSE	= 0x14,
    PIXMAN_OP_DISJOINT_IN		= 0x15,
    PIXMAN_OP_DISJOINT_IN_REVERSE	= 0x16,
    PIXMAN_OP_DISJOINT_OUT		= 0x17,
    PIXMAN_OP_DISJOINT_OUT_REVERSE	= 0x18,
    PIXMAN_OP_DISJOINT_ATOP		= 0x19,
    PIXMAN_OP_DISJOINT_ATOP_REVERSE	= 0x1a,
    PIXMAN_OP_DISJOINT_XOR		= 0x1b,

    PIXMAN_OP_CONJOINT_CLEAR		= 0x20,
    PIXMAN_OP_CONJOINT_SRC		= 0x21,
    PIXMAN_OP_CONJOINT_DST		= 0x22,
    PIXMAN_OP_CONJOINT_OVER		= 0x23,
    PIXMAN_OP_CONJOINT_OVER_REVERSE	= 0x24,
    PIXMAN_OP_CONJOINT_IN		= 0x25,
    PIXMAN_OP_CONJOINT_IN_REVERSE	= 0x26,
    PIXMAN_OP_CONJOINT_OUT		= 0x27,
    PIXMAN_OP_CONJOINT_OUT_REVERSE	= 0x28,
    PIXMAN_OP_CONJOINT_ATOP		= 0x29,
    PIXMAN_OP_CONJOINT_ATOP_REVERSE	= 0x2a,
    PIXMAN_OP_CONJOINT_XOR		= 0x2b,

    PIXMAN_OP_MULTIPLY                  = 0x30,
    PIXMAN_OP_SCREEN                    = 0x31,
    PIXMAN_OP_OVERLAY                   = 0x32,
    PIXMAN_OP_DARKEN                    = 0x33,
    PIXMAN_OP_LIGHTEN                   = 0x34,
    PIXMAN_OP_COLOR_DODGE               = 0x35,
    PIXMAN_OP_COLOR_BURN                = 0x36,
    PIXMAN_OP_HARD_LIGHT                = 0x37,
    PIXMAN_OP_SOFT_LIGHT                = 0x38,
    PIXMAN_OP_DIFFERENCE                = 0x39,
    PIXMAN_OP_EXCLUSION                 = 0x3a,
    PIXMAN_OP_HSL_HUE			= 0x3b,
    PIXMAN_OP_HSL_SATURATION		= 0x3c,
    PIXMAN_OP_HSL_COLOR			= 0x3d,
    PIXMAN_OP_HSL_LUMINOSITY		= 0x3e

// #ifdef PIXMAN_USE_INTERNAL_API
//     ,
//     PIXMAN_N_OPERATORS,
//     PIXMAN_OP_NONE = PIXMAN_N_OPERATORS
// #endif
}

alias PIXMAN_OP_CLEAR = pixman_op_t.PIXMAN_OP_CLEAR ; 
alias PIXMAN_OP_SRC = pixman_op_t.PIXMAN_OP_SRC ; 
alias PIXMAN_OP_DST = pixman_op_t.PIXMAN_OP_DST ; 
alias PIXMAN_OP_OVER = pixman_op_t.PIXMAN_OP_OVER ; 
alias PIXMAN_OP_OVER_REVERSE = pixman_op_t.PIXMAN_OP_OVER_REVERSE ; 
alias PIXMAN_OP_IN = pixman_op_t.PIXMAN_OP_IN ; 
alias PIXMAN_OP_IN_REVERSE = pixman_op_t.PIXMAN_OP_IN_REVERSE ; 
alias PIXMAN_OP_OUT = pixman_op_t.PIXMAN_OP_OUT ; 
alias PIXMAN_OP_OUT_REVERSE = pixman_op_t.PIXMAN_OP_OUT_REVERSE ; 
alias PIXMAN_OP_ATOP = pixman_op_t.PIXMAN_OP_ATOP ; 
alias PIXMAN_OP_ATOP_REVERSE = pixman_op_t.PIXMAN_OP_ATOP_REVERSE ; 
alias PIXMAN_OP_XOR = pixman_op_t.PIXMAN_OP_XOR ; 
alias PIXMAN_OP_ADD = pixman_op_t.PIXMAN_OP_ADD ; 
alias PIXMAN_OP_SATURATE = pixman_op_t.PIXMAN_OP_SATURATE ; 

alias PIXMAN_OP_DISJOINT_CLEAR = pixman_op_t.PIXMAN_OP_DISJOINT_CLEAR ; 
alias PIXMAN_OP_DISJOINT_SRC = pixman_op_t.PIXMAN_OP_DISJOINT_SRC ; 
alias PIXMAN_OP_DISJOINT_DST = pixman_op_t.PIXMAN_OP_DISJOINT_DST ; 
alias PIXMAN_OP_DISJOINT_OVER = pixman_op_t.PIXMAN_OP_DISJOINT_OVER ; 
alias PIXMAN_OP_DISJOINT_OVER_REVERSE = pixman_op_t.PIXMAN_OP_DISJOINT_OVER_REVERSE ; 
alias PIXMAN_OP_DISJOINT_IN = pixman_op_t.PIXMAN_OP_DISJOINT_IN ; 
alias PIXMAN_OP_DISJOINT_IN_REVERSE = pixman_op_t.PIXMAN_OP_DISJOINT_IN_REVERSE ; 
alias PIXMAN_OP_DISJOINT_OUT = pixman_op_t.PIXMAN_OP_DISJOINT_OUT ; 
alias PIXMAN_OP_DISJOINT_OUT_REVERSE = pixman_op_t.PIXMAN_OP_DISJOINT_OUT_REVERSE ; 
alias PIXMAN_OP_DISJOINT_ATOP = pixman_op_t.PIXMAN_OP_DISJOINT_ATOP ; 
alias PIXMAN_OP_DISJOINT_ATOP_REVERSE = pixman_op_t.PIXMAN_OP_DISJOINT_ATOP_REVERSE ; 
alias PIXMAN_OP_DISJOINT_XOR = pixman_op_t.PIXMAN_OP_DISJOINT_XOR ; 

alias PIXMAN_OP_CONJOINT_CLEAR = pixman_op_t.PIXMAN_OP_CONJOINT_CLEAR ; 
alias PIXMAN_OP_CONJOINT_SRC = pixman_op_t.PIXMAN_OP_CONJOINT_SRC ; 
alias PIXMAN_OP_CONJOINT_DST = pixman_op_t.PIXMAN_OP_CONJOINT_DST ; 
alias PIXMAN_OP_CONJOINT_OVER = pixman_op_t.PIXMAN_OP_CONJOINT_OVER ; 
alias PIXMAN_OP_CONJOINT_OVER_REVERSE = pixman_op_t.PIXMAN_OP_CONJOINT_OVER_REVERSE ; 
alias PIXMAN_OP_CONJOINT_IN = pixman_op_t.PIXMAN_OP_CONJOINT_IN ; 
alias PIXMAN_OP_CONJOINT_IN_REVERSE = pixman_op_t.PIXMAN_OP_CONJOINT_IN_REVERSE ; 
alias PIXMAN_OP_CONJOINT_OUT = pixman_op_t.PIXMAN_OP_CONJOINT_OUT ; 
alias PIXMAN_OP_CONJOINT_OUT_REVERSE = pixman_op_t.PIXMAN_OP_CONJOINT_OUT_REVERSE ; 
alias PIXMAN_OP_CONJOINT_ATOP = pixman_op_t.PIXMAN_OP_CONJOINT_ATOP ; 
alias PIXMAN_OP_CONJOINT_ATOP_REVERSE = pixman_op_t.PIXMAN_OP_CONJOINT_ATOP_REVERSE ; 
alias PIXMAN_OP_CONJOINT_XOR = pixman_op_t.PIXMAN_OP_CONJOINT_XOR ; 

alias PIXMAN_OP_MULTIPLY = pixman_op_t.PIXMAN_OP_MULTIPLY ; 
alias PIXMAN_OP_SCREEN = pixman_op_t.PIXMAN_OP_SCREEN ; 
alias PIXMAN_OP_OVERLAY = pixman_op_t.PIXMAN_OP_OVERLAY ; 
alias PIXMAN_OP_DARKEN = pixman_op_t.PIXMAN_OP_DARKEN ; 
alias PIXMAN_OP_LIGHTEN = pixman_op_t.PIXMAN_OP_LIGHTEN ; 
alias PIXMAN_OP_COLOR_DODGE = pixman_op_t.PIXMAN_OP_COLOR_DODGE ; 
alias PIXMAN_OP_COLOR_BURN = pixman_op_t.PIXMAN_OP_COLOR_BURN ; 
alias PIXMAN_OP_HARD_LIGHT = pixman_op_t.PIXMAN_OP_HARD_LIGHT ; 
alias PIXMAN_OP_SOFT_LIGHT = pixman_op_t.PIXMAN_OP_SOFT_LIGHT ; 
alias PIXMAN_OP_DIFFERENCE = pixman_op_t.PIXMAN_OP_DIFFERENCE ; 
alias PIXMAN_OP_EXCLUSION = pixman_op_t.PIXMAN_OP_EXCLUSION ; 
alias PIXMAN_OP_HSL_HUE = pixman_op_t.PIXMAN_OP_HSL_HUE ; 
alias PIXMAN_OP_HSL_SATURATION = pixman_op_t.PIXMAN_OP_HSL_SATURATION ; 
alias PIXMAN_OP_HSL_COLOR = pixman_op_t.PIXMAN_OP_HSL_COLOR ; 
alias PIXMAN_OP_HSL_LUMINOSITY = pixman_op_t.PIXMAN_OP_HSL_LUMINOSITY ; 

/*
 * Regions
 */
alias pixman_region16_data_t = pixman_region16_data;
alias pixman_box16_t = pixman_box16;
alias pixman_rectangle16_t = pixman_rectangle16;
alias pixman_region16_t = pixman_region16;

struct pixman_region16_data {
    long		size;
    long		numRects;
/*  pixman_box16_t	rects[size];   in memory but not explicitly declared */
}

struct pixman_rectangle16
{
    int16_t	x, y;
    uint16_t	width, height;
}

struct pixman_box16
{
    int16_t x1, y1, x2, y2;
}

struct pixman_region16
{
    pixman_box16_t          extents;
    pixman_region16_data_t *data;
}

enum pixman_region_overlap_t
{
    PIXMAN_REGION_OUT,
    PIXMAN_REGION_IN,
    PIXMAN_REGION_PART
} ;

/* This function exists only to make it possible to preserve
 * the X ABI - it should go away at first opportunity.
 */
void pixman_region_set_static_pointers (pixman_box16_t         *empty_box,
					pixman_region16_data_t *empty_data,
					pixman_region16_data_t *broken_data);

/* creation/destruction */
void                    pixman_region_init               (pixman_region16_t *region);

void                    pixman_region_init_rect          (pixman_region16_t *region,
							  int                x,
							  int                y,
							  uint       width,
							  uint       height);

pixman_bool_t           pixman_region_init_rects         (pixman_region16_t *region,
							  const pixman_box16_t *boxes,
							  int                count);

void                    pixman_region_init_with_extents  (pixman_region16_t    *region,
							  const pixman_box16_t *extents);

void                    pixman_region_init_from_image    (pixman_region16_t *region,
							  pixman_image_t    *image);

void                    pixman_region_fini               (pixman_region16_t *region);


/* manipulation */
void                    pixman_region_translate          (pixman_region16_t *region,
							  int                x,
							  int                y);

pixman_bool_t           pixman_region_copy               (pixman_region16_t       *dest,
							  const pixman_region16_t *source);

pixman_bool_t           pixman_region_intersect          (pixman_region16_t       *new_reg,
							  const pixman_region16_t *reg1,
							  const pixman_region16_t *reg2);

pixman_bool_t           pixman_region_union              (pixman_region16_t       *new_reg,
							  const pixman_region16_t *reg1,
							  const pixman_region16_t *reg2);

pixman_bool_t           pixman_region_union_rect         (pixman_region16_t       *dest,
							  const pixman_region16_t *source,
							  int                     x,
							  int                     y,
							  uint            width,
							  uint            height);

pixman_bool_t		pixman_region_intersect_rect     (pixman_region16_t       *dest,
							  const pixman_region16_t *source,
							  int                      x,
							  int                      y,
							  uint             width,
							  uint             height);

pixman_bool_t           pixman_region_subtract           (pixman_region16_t       *reg_d,
							  const pixman_region16_t *reg_m,
							  const pixman_region16_t *reg_s);

pixman_bool_t           pixman_region_inverse            (pixman_region16_t       *new_reg,
							  const pixman_region16_t *reg1,
							  const pixman_box16_t    *inv_rect);

pixman_bool_t           pixman_region_contains_point     (const pixman_region16_t *region,
							  int                      x,
							  int                      y,
							  pixman_box16_t          *box);

pixman_region_overlap_t pixman_region_contains_rectangle (const pixman_region16_t *region,
							  const pixman_box16_t    *prect);

pixman_bool_t           pixman_region_empty              (const pixman_region16_t *region);

pixman_bool_t           pixman_region_not_empty          (const pixman_region16_t *region);

pixman_box16_t *        pixman_region_extents            (const pixman_region16_t *region);

int                     pixman_region_n_rects            (const pixman_region16_t *region);

pixman_box16_t *        pixman_region_rectangles         (const pixman_region16_t *region,
							  int                     *n_rects);

pixman_bool_t           pixman_region_equal              (const pixman_region16_t *region1,
							  const pixman_region16_t *region2);

pixman_bool_t           pixman_region_selfcheck          (pixman_region16_t *region);

void                    pixman_region_reset              (pixman_region16_t       *region,
							  const pixman_box16_t    *box);

void			pixman_region_clear		 (pixman_region16_t *region);
/*
 * 32 bit regions
 */
alias pixman_region32_data_t = pixman_region32_data;
alias pixman_box32_t = pixman_box32;
alias pixman_rectangle32_t = pixman_rectangle32;
alias pixman_region32_t = pixman_region32;

struct pixman_region32_data {
    long		size;
    long		numRects;
/*  pixman_box32_t	rects[size];   in memory but not explicitly declared */
}

struct pixman_rectangle32
{
    int32_t x, y;
    uint32_t width, height;
}

struct pixman_box32
{
    int32_t x1, y1, x2, y2;
}

struct pixman_region32
{
    pixman_box32_t          extents;
    pixman_region32_data_t  *data;
}

/* creation/destruction */
void                    pixman_region32_init               (pixman_region32_t *region);

void                    pixman_region32_init_rect          (pixman_region32_t *region,
							    int                x,
							    int                y,
							    uint       width,
							    uint       height);

pixman_bool_t           pixman_region32_init_rects         (pixman_region32_t *region,
							    const pixman_box32_t *boxes,
							    int                count);

void                    pixman_region32_init_with_extents  (pixman_region32_t    *region,
							    const pixman_box32_t *extents);

void                    pixman_region32_init_from_image    (pixman_region32_t *region,
							    pixman_image_t    *image);

void                    pixman_region32_fini               (pixman_region32_t *region);


/* manipulation */
void                    pixman_region32_translate          (pixman_region32_t *region,
							    int                x,
							    int                y);

pixman_bool_t           pixman_region32_copy               (pixman_region32_t       *dest,
							    const pixman_region32_t *source);

pixman_bool_t           pixman_region32_intersect          (pixman_region32_t       *new_reg,
							    const pixman_region32_t *reg1,
							    const pixman_region32_t *reg2);

pixman_bool_t           pixman_region32_union              (pixman_region32_t       *new_reg,
							    const pixman_region32_t *reg1,
							    const pixman_region32_t *reg2);

pixman_bool_t		pixman_region32_intersect_rect     (pixman_region32_t       *dest,
							    const pixman_region32_t *source,
							    int                      x,
							    int                      y,
							    uint             width,
							    uint             height);

pixman_bool_t           pixman_region32_union_rect         (pixman_region32_t       *dest,
							    const pixman_region32_t *source,
							    int                      x,
							    int                      y,
							    uint             width,
							    uint             height);

pixman_bool_t           pixman_region32_subtract           (pixman_region32_t       *reg_d,
							    const pixman_region32_t *reg_m,
							    const pixman_region32_t *reg_s);

pixman_bool_t           pixman_region32_inverse            (pixman_region32_t       *new_reg,
							    const pixman_region32_t *reg1,
							    const pixman_box32_t    *inv_rect);

pixman_bool_t           pixman_region32_contains_point     (const pixman_region32_t *region,
							    int                      x,
							    int                      y,
							    pixman_box32_t          *box);

pixman_region_overlap_t pixman_region32_contains_rectangle (const pixman_region32_t *region,
							    const pixman_box32_t    *prect);

pixman_bool_t           pixman_region32_empty              (const pixman_region32_t *region);

pixman_bool_t           pixman_region32_not_empty          (const pixman_region32_t *region);

pixman_box32_t *        pixman_region32_extents            (const pixman_region32_t *region);

int                     pixman_region32_n_rects            (const pixman_region32_t *region);

pixman_box32_t *        pixman_region32_rectangles         (const pixman_region32_t *region,
							    int                     *n_rects);

pixman_bool_t           pixman_region32_equal              (const pixman_region32_t *region1,
							    const pixman_region32_t *region2);

pixman_bool_t           pixman_region32_selfcheck          (pixman_region32_t *region);

void                    pixman_region32_reset              (pixman_region32_t    *region,
							    const pixman_box32_t *box);

void			pixman_region32_clear		   (pixman_region32_t *region);
/*
 * 64 bit fractional regions
 */
alias pixman_region64f_data_t = pixman_region64f_data;
alias pixman_box64f_t = pixman_box64f;
alias pixman_rectangle64f_t = pixman_rectangle64f;
alias pixman_region64f_t = pixman_region64f;

struct pixman_region64f_data {
    long		size;
    long		numRects;
/*  pixman_box64f_t	rects[size];   in memory but not explicitly declared */
}

struct pixman_rectangle64f
{
    double x, y;
    double width, height;
}

struct pixman_box64f
{
    double x1, y1, x2, y2;
}

struct pixman_region64f
{
    pixman_box64f_t          extents;
    pixman_region64f_data_t  *data;
}

/* creation/destruction */
void                    pixman_region64f_init              (pixman_region64f_t *region);

void                    pixman_region64f_init_rect         (pixman_region64f_t *region,
							    int                 x,
							    int                 y,
							    uint        width,
							    uint        height);

void                    pixman_region64f_init_rectf        (pixman_region64f_t *region,
							    double              x,
							    double              y,
							    double              width,
							    double              height);

pixman_bool_t           pixman_region64f_init_rects        (pixman_region64f_t *region,
							    const pixman_box64f_t *boxes,
							    int                 count);

void                    pixman_region64f_init_with_extents (pixman_region64f_t    *region,
							    const pixman_box64f_t *extents);

void                    pixman_region64f_init_from_image   (pixman_region64f_t *region,
							    pixman_image_t     *image);

void                    pixman_region64f_fini              (pixman_region64f_t *region);


/* manipulation */
void                    pixman_region64f_translate         (pixman_region64f_t *region,
							    int                 x,
							    int                 y);

void                    pixman_region64f_translatef        (pixman_region64f_t *region,
							    double              x,
							    double              y);

pixman_bool_t           pixman_region64f_copy              (pixman_region64f_t       *dest,
							    const pixman_region64f_t *source);

pixman_bool_t           pixman_region64f_intersect         (pixman_region64f_t       *new_reg,
							    const pixman_region64f_t *reg1,
							    const pixman_region64f_t *reg2);

pixman_bool_t           pixman_region64f_union             (pixman_region64f_t       *new_reg,
							    const pixman_region64f_t *reg1,
							    const pixman_region64f_t *reg2);

pixman_bool_t		pixman_region64f_intersect_rect    (pixman_region64f_t       *dest,
							    const pixman_region64f_t *source,
							    int                       x,
							    int                       y,
							    uint              width,
							    uint              height);

pixman_bool_t		pixman_region64f_intersect_rectf   (pixman_region64f_t       *dest,
							    const pixman_region64f_t *source,
							    double                    x,
							    double                    y,
							    double                    width,
							    double                    height);

pixman_bool_t           pixman_region64f_union_rect        (pixman_region64f_t       *dest,
							    const pixman_region64f_t *source,
							    int                       x,
							    int                       y,
							    uint              width,
							    uint              height);

pixman_bool_t           pixman_region64f_union_rectf       (pixman_region64f_t       *dest,
							    const pixman_region64f_t *source,
							    double                    x,
							    double                    y,
							    double                    width,
							    double                    height);

pixman_bool_t           pixman_region64f_subtract          (pixman_region64f_t       *reg_d,
							    const pixman_region64f_t *reg_m,
							    const pixman_region64f_t *reg_s);

pixman_bool_t           pixman_region64f_inverse           (pixman_region64f_t       *new_reg,
							    const pixman_region64f_t *reg1,
							    const pixman_box64f_t    *inv_rect);

pixman_bool_t           pixman_region64f_contains_point    (const pixman_region64f_t *region,
							    int                       x,
							    int                       y,
							    pixman_box64f_t          *box);

pixman_bool_t           pixman_region64f_contains_pointf   (const pixman_region64f_t *region,
							    double                    x,
							    double                    y,
							    pixman_box64f_t          *box);

pixman_region_overlap_t pixman_region64f_contains_rectangle(const pixman_region64f_t *region,
							    const pixman_box64f_t    *prect);

pixman_bool_t           pixman_region64f_empty             (const pixman_region64f_t *region);

pixman_bool_t           pixman_region64f_not_empty         (const pixman_region64f_t *region);

pixman_box64f_t *       pixman_region64f_extents           (const pixman_region64f_t *region);

int                     pixman_region64f_n_rects           (const pixman_region64f_t *region);

pixman_box64f_t *       pixman_region64f_rectangles        (const pixman_region64f_t *region,
							    int                      *n_rects);

pixman_bool_t           pixman_region64f_equal             (const pixman_region64f_t *region1,
							    const pixman_region64f_t *region2);

pixman_bool_t           pixman_region64f_selfcheck         (pixman_region64f_t *region);

void                    pixman_region64f_reset             (pixman_region64f_t    *region,
							    const pixman_box64f_t *box);

void			pixman_region64f_clear		   (pixman_region64f_t *region);


/* Copy / Fill / Misc */
pixman_bool_t pixman_blt                (uint32_t           *src_bits,
					 uint32_t           *dst_bits,
					 int                 src_stride,
					 int                 dst_stride,
					 int                 src_bpp,
					 int                 dst_bpp,
					 int                 src_x,
					 int                 src_y,
					 int                 dest_x,
					 int                 dest_y,
					 int                 width,
					 int                 height);

pixman_bool_t pixman_fill               (uint32_t           *bits,
					 int                 stride,
					 int                 bpp,
					 int                 x,
					 int                 y,
					 int                 width,
					 int                 height,
					 uint32_t            _xor);


int           pixman_version            ();

const(char*)   pixman_version_string     ();

/*
 * Images
 */
alias pixman_indexed_t = pixman_indexed;
alias pixman_gradient_stop_t = pixman_gradient_stop;

alias pixman_read_memory_func_t = uint32_t function(const(void*)src, int size);
alias pixman_write_memory_func_t = void function(void *dst, uint32_t value, int size);

alias pixman_image_destroy_func_t = void function(pixman_image_t *image, void *data);

struct pixman_gradient_stop {
    pixman_fixed_t x;
    pixman_color_t color;
}

enum PIXMAN_MAX_INDEXED =  256; /* XXX depth must be <= 8 */

// #if PIXMAN_MAX_INDEXED <= 256
alias pixman_index_type = uint8_t;
// #endif

struct pixman_indexed
{
    pixman_bool_t       color;
    uint32_t[PIXMAN_MAX_INDEXED]		rgba;
    pixman_index_type[32768]	ent;
}

/*
 * While the protocol is generous in format support, the
 * sample implementation allows only packed RGB and GBR
 * representations for data to simplify software rendering,
 */
auto PIXMAN_FORMAT(BPP, TYPE, A, R, G, B)(BPP bpp, TYPE type, A a, R r, G g, B b) =>	(((bpp) << 24) | 
					 ((type) << 16) |
					 ((a) << 12) |	 
					 ((r) << 8) |	 
					 ((g) << 4) |	 
					 ((b)));

auto PIXMAN_FORMAT_BYTE(BPP, TYPE, A, R, G, B)(BPP bpp, TYPE type, A a, R r, G g, B b) =>
	(((bpp >> 3) << 24) | 
	(3 << 22) | ((type) << 16) | 
	((a >> 3) << 12) | 
	((r >> 3) << 8) | 
	((g >> 3) << 4) | 
	((b >> 3)));

auto PIXMAN_FORMAT_RESHIFT(Val, Ofs, Num)(Val val, Ofs ofs, Num num) =>
	(((val >> (ofs)) & ((1 << (num)) - 1)) << ((val >> 22) & 3));

auto PIXMAN_FORMAT_BPP(F)(F f) =>	PIXMAN_FORMAT_RESHIFT(f, 24, 8);
auto PIXMAN_FORMAT_SHIFT(F)(F f)	=> 	cast(uint32_t)((f >> 22) & 3);
auto PIXMAN_FORMAT_TYPE(F)(F f) =>	(f >> 16) & 0x3f;
auto PIXMAN_FORMAT_A(F)(F f) =>	PIXMAN_FORMAT_RESHIFT(f, 12, 4);
auto PIXMAN_FORMAT_R(F)(F f)	=> PIXMAN_FORMAT_RESHIFT(f, 8, 4);
auto PIXMAN_FORMAT_G(F)(F f)	=> PIXMAN_FORMAT_RESHIFT(f, 4, 4);
auto PIXMAN_FORMAT_B(F)(F f)	=> PIXMAN_FORMAT_RESHIFT(f, 0, 4);
auto PIXMAN_FORMAT_RGB(F)(F f)	=> f & 0xfff;
auto PIXMAN_FORMAT_VIS(F)(F f)	=> f & 0xffff;
auto PIXMAN_FORMAT_DEPTH(F)(F f)	=> PIXMAN_FORMAT_A(f) +	
				 PIXMAN_FORMAT_R(f) +	
				 PIXMAN_FORMAT_G(f) +	
				 PIXMAN_FORMAT_B(f);

enum PIXMAN_TYPE_OTHER =	0;
enum PIXMAN_TYPE_A =		1;
enum PIXMAN_TYPE_ARGB =	2;
enum PIXMAN_TYPE_ABGR =	3;
enum PIXMAN_TYPE_COLOR =	4;
enum PIXMAN_TYPE_GRAY =	5;
enum PIXMAN_TYPE_YUY2 =	6;
enum PIXMAN_TYPE_YV12 =	7;
enum PIXMAN_TYPE_BGRA =	8;
enum PIXMAN_TYPE_RGBA =	9;
enum PIXMAN_TYPE_ARGB_SRGB =	10;
enum PIXMAN_TYPE_RGBA_FLOAT =	11;

auto PIXMAN_FORMAT_COLOR(F) (F f) =>
	(PIXMAN_FORMAT_TYPE(f) == PIXMAN_TYPE_ARGB ||	
	 PIXMAN_FORMAT_TYPE(f) == PIXMAN_TYPE_ABGR ||	
	 PIXMAN_FORMAT_TYPE(f) == PIXMAN_TYPE_BGRA ||	
	 PIXMAN_FORMAT_TYPE(f) == PIXMAN_TYPE_RGBA ||	
	 PIXMAN_FORMAT_TYPE(f) == PIXMAN_TYPE_RGBA_FLOAT);

public enum pixman_format_code_t : int {
/* 128bpp formats */
    PIXMAN_rgba_float =	PIXMAN_FORMAT_BYTE(128,PIXMAN_TYPE_RGBA_FLOAT,32,32,32,32),
/* 96bpp formats */
    PIXMAN_rgb_float =	PIXMAN_FORMAT_BYTE(96,PIXMAN_TYPE_RGBA_FLOAT,0,32,32,32),

/* 64bpp formats */
    /* [63:0] A:B:G:R 16:16:16:16 native endian */
    PIXMAN_a16b16g16r16 = PIXMAN_FORMAT_BYTE(64,PIXMAN_TYPE_ABGR,16,16,16,16),

/* 32bpp formats */
    PIXMAN_a8r8g8b8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_ARGB,8,8,8,8),
    PIXMAN_x8r8g8b8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_ARGB,0,8,8,8),
    PIXMAN_a8b8g8r8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_ABGR,8,8,8,8),
    PIXMAN_x8b8g8r8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_ABGR,0,8,8,8),
    PIXMAN_b8g8r8a8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_BGRA,8,8,8,8),
    PIXMAN_b8g8r8x8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_BGRA,0,8,8,8),
    PIXMAN_r8g8b8a8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_RGBA,8,8,8,8),
    PIXMAN_r8g8b8x8 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_RGBA,0,8,8,8),
    PIXMAN_x14r6g6b6 =	 PIXMAN_FORMAT(32,PIXMAN_TYPE_ARGB,0,6,6,6),
    PIXMAN_x2r10g10b10 = PIXMAN_FORMAT(32,PIXMAN_TYPE_ARGB,0,10,10,10),
    PIXMAN_a2r10g10b10 = PIXMAN_FORMAT(32,PIXMAN_TYPE_ARGB,2,10,10,10),
    PIXMAN_x2b10g10r10 = PIXMAN_FORMAT(32,PIXMAN_TYPE_ABGR,0,10,10,10),
    PIXMAN_a2b10g10r10 = PIXMAN_FORMAT(32,PIXMAN_TYPE_ABGR,2,10,10,10),

/* sRGB formats */
    PIXMAN_a8r8g8b8_sRGB = PIXMAN_FORMAT(32,PIXMAN_TYPE_ARGB_SRGB,8,8,8,8),
    PIXMAN_r8g8b8_sRGB = PIXMAN_FORMAT(24,PIXMAN_TYPE_ARGB_SRGB,0,8,8,8),

/* 24bpp formats */
    PIXMAN_r8g8b8 =	 PIXMAN_FORMAT(24,PIXMAN_TYPE_ARGB,0,8,8,8),
    PIXMAN_b8g8r8 =	 PIXMAN_FORMAT(24,PIXMAN_TYPE_ABGR,0,8,8,8),

/* 16bpp formats */
    PIXMAN_r5g6b5 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ARGB,0,5,6,5),
    PIXMAN_b5g6r5 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ABGR,0,5,6,5),

    PIXMAN_a1r5g5b5 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ARGB,1,5,5,5),
    PIXMAN_x1r5g5b5 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ARGB,0,5,5,5),
    PIXMAN_a1b5g5r5 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ABGR,1,5,5,5),
    PIXMAN_x1b5g5r5 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ABGR,0,5,5,5),
    PIXMAN_a4r4g4b4 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ARGB,4,4,4,4),
    PIXMAN_x4r4g4b4 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ARGB,0,4,4,4),
    PIXMAN_a4b4g4r4 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ABGR,4,4,4,4),
    PIXMAN_x4b4g4r4 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_ABGR,0,4,4,4),

/* 8bpp formats */
    PIXMAN_a8 =		 PIXMAN_FORMAT(8,PIXMAN_TYPE_A,8,0,0,0),
    PIXMAN_r3g3b2 =	 PIXMAN_FORMAT(8,PIXMAN_TYPE_ARGB,0,3,3,2),
    PIXMAN_b2g3r3 =	 PIXMAN_FORMAT(8,PIXMAN_TYPE_ABGR,0,3,3,2),
    PIXMAN_a2r2g2b2 =	 PIXMAN_FORMAT(8,PIXMAN_TYPE_ARGB,2,2,2,2),
    PIXMAN_a2b2g2r2 =	 PIXMAN_FORMAT(8,PIXMAN_TYPE_ABGR,2,2,2,2),

    PIXMAN_c8 =		 PIXMAN_FORMAT(8,PIXMAN_TYPE_COLOR,0,0,0,0),
    PIXMAN_g8 =		 PIXMAN_FORMAT(8,PIXMAN_TYPE_GRAY,0,0,0,0),

    PIXMAN_x4a4 =	 PIXMAN_FORMAT(8,PIXMAN_TYPE_A,4,0,0,0),

    PIXMAN_x4c4 =	 PIXMAN_FORMAT(8,PIXMAN_TYPE_COLOR,0,0,0,0),
    PIXMAN_x4g4 =	 PIXMAN_FORMAT(8,PIXMAN_TYPE_GRAY,0,0,0,0),

/* 4bpp formats */
    PIXMAN_a4 =		 PIXMAN_FORMAT(4,PIXMAN_TYPE_A,4,0,0,0),
    PIXMAN_r1g2b1 =	 PIXMAN_FORMAT(4,PIXMAN_TYPE_ARGB,0,1,2,1),
    PIXMAN_b1g2r1 =	 PIXMAN_FORMAT(4,PIXMAN_TYPE_ABGR,0,1,2,1),
    PIXMAN_a1r1g1b1 =	 PIXMAN_FORMAT(4,PIXMAN_TYPE_ARGB,1,1,1,1),
    PIXMAN_a1b1g1r1 =	 PIXMAN_FORMAT(4,PIXMAN_TYPE_ABGR,1,1,1,1),

    PIXMAN_c4 =		 PIXMAN_FORMAT(4,PIXMAN_TYPE_COLOR,0,0,0,0),
    PIXMAN_g4 =		 PIXMAN_FORMAT(4,PIXMAN_TYPE_GRAY,0,0,0,0),

/* 1bpp formats */
    PIXMAN_a1 =		 PIXMAN_FORMAT(1,PIXMAN_TYPE_A,1,0,0,0),

    PIXMAN_g1 =		 PIXMAN_FORMAT(1,PIXMAN_TYPE_GRAY,0,0,0,0),

/* YUV formats */
    PIXMAN_yuy2 =	 PIXMAN_FORMAT(16,PIXMAN_TYPE_YUY2,0,0,0,0),
    PIXMAN_yv12 =	 PIXMAN_FORMAT(12,PIXMAN_TYPE_YV12,0,0,0,0)
}

/* 128bpp formats */
alias    PIXMAN_rgba_float =	pixman_format_code_t.PIXMAN_rgba_float;
/* 96bpp formats */
alias    PIXMAN_rgb_float =	pixman_format_code_t.PIXMAN_rgb_float;

/* 64bpp formats */
    /* [63:0] A:B:G:R 16:16:16:16 native endian */
alias    PIXMAN_a16b16g16r16 = pixman_format_code_t.PIXMAN_a16b16g16r16;

/* 32bpp formats */
alias    PIXMAN_a8r8g8b8 = pixman_format_code_t.PIXMAN_a8r8g8b8;
alias    PIXMAN_x8r8g8b8 = pixman_format_code_t.PIXMAN_x8r8g8b8;
alias    PIXMAN_a8b8g8r8 = pixman_format_code_t.PIXMAN_a8b8g8r8;
alias    PIXMAN_x8b8g8r8 = pixman_format_code_t.PIXMAN_x8b8g8r8;
alias    PIXMAN_b8g8r8a8 = pixman_format_code_t.PIXMAN_b8g8r8a8;
alias    PIXMAN_b8g8r8x8 = pixman_format_code_t.PIXMAN_b8g8r8x8;
alias    PIXMAN_r8g8b8a8 = pixman_format_code_t.PIXMAN_r8g8b8a8;
alias    PIXMAN_r8g8b8x8 = pixman_format_code_t.PIXMAN_r8g8b8x8;
alias    PIXMAN_x14r6g6b6 = pixman_format_code_t.PIXMAN_x14r6g6b6;
alias    PIXMAN_x2r10g10b10 = pixman_format_code_t.PIXMAN_x2r10g10b10;
alias    PIXMAN_a2r10g10b10 = pixman_format_code_t.PIXMAN_a2r10g10b10;
alias    PIXMAN_x2b10g10r10 = pixman_format_code_t.PIXMAN_x2b10g10r10;
alias    PIXMAN_a2b10g10r10 = pixman_format_code_t.PIXMAN_a2b10g10r10;

/* sRGB formats */
alias    PIXMAN_a8r8g8b8_sRGB = pixman_format_code_t.PIXMAN_a8r8g8b8_sRGB;
alias    PIXMAN_r8g8b8_sRGB = pixman_format_code_t.PIXMAN_r8g8b8_sRGB;

/* 24bpp formats */
alias    PIXMAN_r8g8b8 = pixman_format_code_t.PIXMAN_r8g8b8;
alias    PIXMAN_b8g8r8 = pixman_format_code_t.PIXMAN_b8g8r8;

/* 16bpp formats */
alias    PIXMAN_r5g6b5 = pixman_format_code_t.PIXMAN_r5g6b5;
alias    PIXMAN_b5g6r5 = pixman_format_code_t.PIXMAN_b5g6r5;

alias    PIXMAN_a1r5g5b5 = pixman_format_code_t.PIXMAN_a1r5g5b5;
alias    PIXMAN_x1r5g5b5 = pixman_format_code_t.PIXMAN_x1r5g5b5;
alias    PIXMAN_a1b5g5r5 = pixman_format_code_t.PIXMAN_a1b5g5r5;
alias    PIXMAN_x1b5g5r5 = pixman_format_code_t.PIXMAN_x1b5g5r5;
alias    PIXMAN_a4r4g4b4 = pixman_format_code_t.PIXMAN_a4r4g4b4;
alias    PIXMAN_x4r4g4b4 = pixman_format_code_t.PIXMAN_x4r4g4b4;
alias    PIXMAN_a4b4g4r4 = pixman_format_code_t.PIXMAN_a4b4g4r4;
alias    PIXMAN_x4b4g4r4 = pixman_format_code_t.PIXMAN_x4b4g4r4;

/* 8bpp formats */
alias    PIXMAN_a8 = pixman_format_code_t.PIXMAN_a8;
alias    PIXMAN_r3g3b2 = pixman_format_code_t.PIXMAN_r3g3b2;
alias    PIXMAN_b2g3r3 = pixman_format_code_t.PIXMAN_b2g3r3;
alias    PIXMAN_a2r2g2b2 = pixman_format_code_t.PIXMAN_a2r2g2b2;
alias    PIXMAN_a2b2g2r2 = pixman_format_code_t.PIXMAN_a2b2g2r2;

alias    PIXMAN_c8 = pixman_format_code_t.PIXMAN_c8;
alias    PIXMAN_g8 = pixman_format_code_t.PIXMAN_g8;

alias    PIXMAN_x4a4 = pixman_format_code_t.PIXMAN_x4a4;

alias    PIXMAN_x4c4 = pixman_format_code_t.PIXMAN_x4c4;
alias    PIXMAN_x4g4 = pixman_format_code_t.PIXMAN_x4g4;

/* 4bpp formats */
alias    PIXMAN_a4 = pixman_format_code_t.PIXMAN_a4;
alias    PIXMAN_r1g2b1 = pixman_format_code_t.PIXMAN_r1g2b1;
alias    PIXMAN_b1g2r1 = pixman_format_code_t.PIXMAN_b1g2r1;
alias    PIXMAN_a1r1g1b1 = pixman_format_code_t.PIXMAN_a1r1g1b1;
alias    PIXMAN_a1b1g1r1 = pixman_format_code_t.PIXMAN_a1b1g1r1;

alias    PIXMAN_c4 = pixman_format_code_t.PIXMAN_c4;
alias    PIXMAN_g4 = pixman_format_code_t.PIXMAN_g4;

/* 1bpp formats */
alias    PIXMAN_a1 = pixman_format_code_t.PIXMAN_a1;

alias    PIXMAN_g1 = pixman_format_code_t.PIXMAN_g1;

/* YUV formats */
alias    PIXMAN_yuy2 = pixman_format_code_t.PIXMAN_yuy2;
alias    PIXMAN_yv12 = pixman_format_code_t.PIXMAN_yv12;

/* Querying supported format values. */
pixman_bool_t pixman_format_supported_destination (pixman_format_code_t format);

pixman_bool_t pixman_format_supported_source      (pixman_format_code_t format);

/* Constructors */
pixman_image_t *pixman_image_create_solid_fill       (const pixman_color_t         *color);

pixman_image_t *pixman_image_create_linear_gradient  (const pixman_point_fixed_t   *p1,
						      const pixman_point_fixed_t   *p2,
						      const pixman_gradient_stop_t *stops,
						      int                           n_stops);

pixman_image_t *pixman_image_create_radial_gradient  (const pixman_point_fixed_t   *inner,
						      const pixman_point_fixed_t   *outer,
						      pixman_fixed_t                inner_radius,
						      pixman_fixed_t                outer_radius,
						      const pixman_gradient_stop_t *stops,
						      int                           n_stops);

pixman_image_t *pixman_image_create_conical_gradient (const pixman_point_fixed_t   *center,
						      pixman_fixed_t                angle,
						      const pixman_gradient_stop_t *stops,
						      int                           n_stops);

pixman_image_t *pixman_image_create_bits             (pixman_format_code_t          format,
						      int                           width,
						      int                           height,
						      uint32_t                     *bits,
						      int                           rowstride_bytes);

pixman_image_t *pixman_image_create_bits_no_clear    (pixman_format_code_t format,
						      int                  width,
						      int                  height,
						      uint32_t *           bits,
						      int                  rowstride_bytes);

/* Destructor */
pixman_image_t *pixman_image_ref                     (pixman_image_t               *image);

pixman_bool_t   pixman_image_unref                   (pixman_image_t               *image);


void		pixman_image_set_destroy_function    (pixman_image_t		   *image,
						      pixman_image_destroy_func_t   function_,
						      void			   *data);

void *		pixman_image_get_destroy_data        (pixman_image_t		   *image);

/* Set properties */
pixman_bool_t   pixman_image_set_clip_region         (pixman_image_t               *image,
						      const pixman_region16_t            *region);

pixman_bool_t   pixman_image_set_clip_region32       (pixman_image_t               *image,
						      const pixman_region32_t            *region);

pixman_bool_t   pixman_image_set_clip_region64f      (pixman_image_t               *image,
						      const pixman_region64f_t           *region);

void		pixman_image_set_has_client_clip     (pixman_image_t               *image,
						      pixman_bool_t		    clien_clip);

pixman_bool_t   pixman_image_set_transform           (pixman_image_t               *image,
						      const pixman_transform_t     *transform);

void            pixman_image_set_repeat              (pixman_image_t               *image,
						      pixman_repeat_t               repeat);

void            pixman_image_set_dither              (pixman_image_t               *image,
						      pixman_dither_t               dither);

void            pixman_image_set_dither_offset       (pixman_image_t               *image,
						      int                           offset_x,
						      int                           offset_y);

pixman_bool_t   pixman_image_set_filter              (pixman_image_t               *image,
						      pixman_filter_t               filter,
						      const pixman_fixed_t         *filter_params,
						      int                           n_filter_params);

void		pixman_image_set_source_clipping     (pixman_image_t		   *image,
						      pixman_bool_t                 source_clipping);

void            pixman_image_set_alpha_map           (pixman_image_t               *image,
						      pixman_image_t               *alpha_map,
						      int16_t                       x,
						      int16_t                       y);

void            pixman_image_set_component_alpha     (pixman_image_t               *image,
						      pixman_bool_t                 component_alpha);

pixman_bool_t   pixman_image_get_component_alpha     (pixman_image_t               *image);

void		pixman_image_set_accessors	     (pixman_image_t		   *image,
						      pixman_read_memory_func_t	    read_func,
						      pixman_write_memory_func_t    write_func);

void		pixman_image_set_indexed	     (pixman_image_t		   *image,
						      const pixman_indexed_t	   *indexed);

uint32_t       *pixman_image_get_data                (pixman_image_t               *image);

int		pixman_image_get_width               (pixman_image_t               *image);

int             pixman_image_get_height              (pixman_image_t               *image);

int		pixman_image_get_stride              (pixman_image_t               *image); /* in bytes */

int		pixman_image_get_depth               (pixman_image_t		   *image);

pixman_format_code_t pixman_image_get_format	     (pixman_image_t		   *image);

enum pixman_kernel_t
{
    PIXMAN_KERNEL_IMPULSE,
    PIXMAN_KERNEL_BOX,
    PIXMAN_KERNEL_LINEAR,
    PIXMAN_KERNEL_CUBIC,
    PIXMAN_KERNEL_GAUSSIAN,
    PIXMAN_KERNEL_LANCZOS2,
    PIXMAN_KERNEL_LANCZOS3,
    PIXMAN_KERNEL_LANCZOS3_STRETCHED       /* Jim Blinn's 'nice' filter */
} ;

/* Create the parameter list for a SEPARABLE_CONVOLUTION filter
 * with the given kernels and scale parameters.
 */
pixman_fixed_t *
pixman_filter_create_separable_convolution (int             *n_values,
					    pixman_fixed_t   scale_x,
					    pixman_fixed_t   scale_y,
					    pixman_kernel_t  reconstruct_x,
					    pixman_kernel_t  reconstruct_y,
					    pixman_kernel_t  sample_x,
					    pixman_kernel_t  sample_y,
					    int              subsample_bits_x,
					    int              subsample_bits_y);


pixman_bool_t	pixman_image_fill_rectangles	     (pixman_op_t		    op,
						      pixman_image_t		   *image,
						      const pixman_color_t	   *color,
						      int			    n_rects,
						      const pixman_rectangle16_t   *rects);

pixman_bool_t   pixman_image_fill_boxes              (pixman_op_t                   op,
                                                      pixman_image_t               *dest,
                                                      const pixman_color_t         *color,
                                                      int                           n_boxes,
                                                      const pixman_box32_t         *boxes);

/* Composite */
pixman_bool_t pixman_compute_composite_region (pixman_region16_t *region,
					       pixman_image_t    *src_image,
					       pixman_image_t    *mask_image,
					       pixman_image_t    *dest_image,
					       int16_t            src_x,
					       int16_t            src_y,
					       int16_t            mask_x,
					       int16_t            mask_y,
					       int16_t            dest_x,
					       int16_t            dest_y,
					       uint16_t           width,
					       uint16_t           height);

void          pixman_image_composite          (pixman_op_t        op,
					       pixman_image_t    *src,
					       pixman_image_t    *mask,
					       pixman_image_t    *dest,
					       int16_t            src_x,
					       int16_t            src_y,
					       int16_t            mask_x,
					       int16_t            mask_y,
					       int16_t            dest_x,
					       int16_t            dest_y,
					       uint16_t           width,
					       uint16_t           height);

void          pixman_image_composite32        (pixman_op_t        op,
					       pixman_image_t    *src,
					       pixman_image_t    *mask,
					       pixman_image_t    *dest,
					       int32_t            src_x,
					       int32_t            src_y,
					       int32_t            mask_x,
					       int32_t            mask_y,
					       int32_t            dest_x,
					       int32_t            dest_y,
					       int32_t            width,
					       int32_t            height);

void          pixman_image_composite64f       (pixman_op_t        op,
					       pixman_image_t    *src,
					       pixman_image_t    *mask,
					       pixman_image_t    *dest,
					       double             src_x,
					       double             src_y,
					       double             mask_x,
					       double             mask_y,
					       double             dest_x,
					       double             dest_y,
					       double             width,
					       double             height);

/* Executive Summary: This function is a no-op that only exists
 * for historical reasons.
 *
 * There used to be a bug in the X server where it would rely on
 * out-of-bounds accesses when it was asked to composite with a
 * window as the source. It would create a pixman image pointing
 * to some bogus position in memory, but then set a clip region
 * to the position where the actual bits were.
 *
 * Due to a bug in old versions of pixman, where it would not clip
 * against the image bounds when a clip region was set, this would
 * actually work. So when the pixman bug was fixed, a workaround was
 * added to allow certain out-of-bound accesses. This function disabled
 * those workarounds.
 *
 * Since 0.21.2, pixman doesn't do these workarounds anymore, so now this
 * function is a no-op.
 */
void pixman_disable_out_of_bounds_workaround ();

/*
 * Glyphs
 */
 struct pixman_glyph_cache_t;
// alias pixman_glyph_cache_t = pixman_glyph_cache_t;
struct pixman_glyph_t
{
    int		x, y;
    const(void)* 	glyph;
}

pixman_glyph_cache_t *pixman_glyph_cache_create       ();

void                  pixman_glyph_cache_destroy      (pixman_glyph_cache_t *cache);

void                  pixman_glyph_cache_freeze       (pixman_glyph_cache_t *cache);

void                  pixman_glyph_cache_thaw         (pixman_glyph_cache_t *cache);

const(void*)          pixman_glyph_cache_lookup       (pixman_glyph_cache_t *cache,
						       void                 *font_key,
						       void                 *glyph_key);

const(void*)          pixman_glyph_cache_insert       (pixman_glyph_cache_t *cache,
						       void                 *font_key,
						       void                 *glyph_key,
						       int		     origin_x,
						       int                   origin_y,
						       pixman_image_t       *glyph_image);

void                  pixman_glyph_cache_remove       (pixman_glyph_cache_t *cache,
						       void                 *font_key,
						       void                 *glyph_key);

void                  pixman_glyph_get_extents        (pixman_glyph_cache_t *cache,
						       int                   n_glyphs,
						       pixman_glyph_t       *glyphs,
						       pixman_box32_t       *extents);

pixman_format_code_t  pixman_glyph_get_mask_format    (pixman_glyph_cache_t *cache,
						       int		     n_glyphs,
						       const pixman_glyph_t *glyphs);

void                  pixman_composite_glyphs         (pixman_op_t           op,
						       pixman_image_t       *src,
						       pixman_image_t       *dest,
						       pixman_format_code_t  mask_format,
						       int32_t               src_x,
						       int32_t               src_y,
						       int32_t		     mask_x,
						       int32_t		     mask_y,
						       int32_t               dest_x,
						       int32_t               dest_y,
						       int32_t		     width,
						       int32_t		     height,
						       pixman_glyph_cache_t *cache,
						       int		     n_glyphs,
						       const pixman_glyph_t *glyphs);

void                  pixman_composite_glyphs_no_mask (pixman_op_t           op,
						       pixman_image_t       *src,
						       pixman_image_t       *dest,
						       int32_t               src_x,
						       int32_t               src_y,
						       int32_t               dest_x,
						       int32_t               dest_y,
						       pixman_glyph_cache_t *cache,
						       int		     n_glyphs,
						       const pixman_glyph_t *glyphs);

/*
 * Trapezoids
 */
alias pixman_edge_t = pixman_edge;
alias pixman_trapezoid_t = pixman_trapezoid;
alias pixman_trap_t = pixman_trap;
alias pixman_span_fix_t = pixman_span_fix;
alias pixman_triangle_t = pixman_triangle;

/*
 * An edge structure.  This represents a single polygon edge
 * and can be quickly stepped across small or large gaps in the
 * sample grid
 */
struct pixman_edge
{
    pixman_fixed_t	x;
    pixman_fixed_t	e;
    pixman_fixed_t	stepx;
    pixman_fixed_t	signdx;
    pixman_fixed_t	dy;
    pixman_fixed_t	dx;

    pixman_fixed_t	stepx_small;
    pixman_fixed_t	stepx_big;
    pixman_fixed_t	dx_small;
    pixman_fixed_t	dx_big;
}

struct pixman_trapezoid
{
    pixman_fixed_t	top, bottom;
    pixman_line_fixed_t	left, right;
}

struct pixman_triangle
{
    pixman_point_fixed_t p1, p2, p3;
}

/* whether 't' is a well defined not obviously empty trapezoid */
auto pixman_trapezoid_valid(T)(T t) =>				   
    (t.left.p1.y != t.left.p2.y &&			   
     t.right.p1.y != t.right.p2.y &&			   
     (t.bottom > t.top));

struct pixman_span_fix
{
    pixman_fixed_t	l, r, y;
}

struct pixman_trap
{
    pixman_span_fix_t	top, bot;
}

pixman_fixed_t pixman_sample_ceil_y        (pixman_fixed_t             y,
					    int                        bpp);

pixman_fixed_t pixman_sample_floor_y       (pixman_fixed_t             y,
					    int                        bpp);

void           pixman_edge_step            (pixman_edge_t             *e,
					    int                        n);

void           pixman_edge_init            (pixman_edge_t             *e,
					    int                        bpp,
					    pixman_fixed_t             y_start,
					    pixman_fixed_t             x_top,
					    pixman_fixed_t             y_top,
					    pixman_fixed_t             x_bot,
					    pixman_fixed_t             y_bot);

void           pixman_line_fixed_edge_init (pixman_edge_t             *e,
					    int                        bpp,
					    pixman_fixed_t             y,
					    const pixman_line_fixed_t *line,
					    int                        x_off,
					    int                        y_off);

void           pixman_rasterize_edges      (pixman_image_t            *image,
					    pixman_edge_t             *l,
					    pixman_edge_t             *r,
					    pixman_fixed_t             t,
					    pixman_fixed_t             b);

void           pixman_add_traps            (pixman_image_t            *image,
					    int16_t                    x_off,
					    int16_t                    y_off,
					    int                        ntrap,
					    const pixman_trap_t       *traps);

void           pixman_add_trapezoids       (pixman_image_t            *image,
					    int16_t                    x_off,
					    int                        y_off,
					    int                        ntraps,
					    const pixman_trapezoid_t  *traps);

void           pixman_rasterize_trapezoid  (pixman_image_t            *image,
					    const pixman_trapezoid_t  *trap,
					    int                        x_off,
					    int                        y_off);

void          pixman_composite_trapezoids (pixman_op_t		       op,
					   pixman_image_t *	       src,
					   pixman_image_t *	       dst,
					   pixman_format_code_t	       mask_format,
					   int			       x_src,
					   int			       y_src,
					   int			       x_dst,
					   int			       y_dst,
					   int			       n_traps,
					   const pixman_trapezoid_t *  traps);

void          pixman_composite_triangles (pixman_op_t		       op,
					  pixman_image_t *	       src,
					  pixman_image_t *	       dst,
					  pixman_format_code_t	       mask_format,
					  int			       x_src,
					  int			       y_src,
					  int			       x_dst,
					  int			       y_dst,
					  int			       n_tris,
					  const pixman_triangle_t *    tris);

void	      pixman_add_triangles       (pixman_image_t              *image,
					  int32_t	               x_off,
					  int32_t	               y_off,
					  int	                       n_tris,
					  const pixman_triangle_t     *tris);