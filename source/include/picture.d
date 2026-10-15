module include.picture;
@nogc nothrow:
extern(C): __gshared:
/*
 *
 * Copyright © 2000 SuSE, Inc.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of SuSE not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  SuSE makes no representations about the
 * suitability of this software for any purpose.  It is provided "as is"
 * without express or implied warranty.
 *
 * SuSE DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL
 * IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL SuSE
 * BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN ACTION
 * OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN
 * CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 * Author:  Keith Packard, SuSE, Inc.
 */

 
public import include.privates;
import include.picturestr;

public import dsl.pixman;
public import glamor.glamor_render;
import render.picture;


alias DirectFormatPtr = _DirectFormat*;
alias PictFormatPtr = _PictFormat*;
alias PictFormatRec = _PictFormat;
alias PicturePtr = _Picture*;
alias PictureRec = _Picture;


/*
 * While the protocol is generous in format support, the
 * sample implementation allows only packed RGB and GBR
 * representations for data to simplify software rendering,
 */
enum string PICT_FORMAT(string bpp,string type,string a,string r,string g,string b) = `PIXMAN_FORMAT(` ~ bpp ~ `, ` ~ type ~ `, ` ~ a ~ `, ` ~ r ~ `, ` ~ g ~ `, ` ~ b ~ `)`;
enum string PIXMAN_FORMAT_RGB(string f) =	`(((`~f~`)      ) & 0xfff)`;
/*
 * gray/color formats use a visual index instead of argb
 */
enum string PICT_VISFORMAT(string bpp,string type,string vi) = `(((` ~ bpp ~ `) << 24) |  
					 ((` ~ type ~ `) << 16) | 
					 ((` ~ vi ~ `)))`;

enum string PICT_FORMAT_BPP(string f) = `PIXMAN_FORMAT_BPP(` ~ f ~ `)`;
enum string PICT_FORMAT_TYPE(string f) = `PIXMAN_FORMAT_TYPE(` ~ f ~ `)`;
enum string PICT_FORMAT_A(string f) = `PIXMAN_FORMAT_A(` ~ f ~ `)`;
enum string PICT_FORMAT_R(string f) = `PIXMAN_FORMAT_R(` ~ f ~ `)`;
enum string PICT_FORMAT_G(string f) = `PIXMAN_FORMAT_G(` ~ f ~ `)`;
enum string PICT_FORMAT_B(string f) = `PIXMAN_FORMAT_B(` ~ f ~ `)`;
enum string PICT_FORMAT_RGB(string f) = `PIXMAN_FORMAT_RGB(` ~ f ~ `)`;
enum string PICT_FORMAT_VIS(string f) = `PIXMAN_FORMAT_VIS(` ~ f ~ `)`;

enum PICT_TYPE_OTHER =		PIXMAN_TYPE_OTHER;
enum PICT_TYPE_A =		PIXMAN_TYPE_A;
enum PICT_TYPE_ARGB =		PIXMAN_TYPE_ARGB;
enum PICT_TYPE_ABGR =		PIXMAN_TYPE_ABGR;
enum PICT_TYPE_COLOR =		PIXMAN_TYPE_COLOR;
enum PICT_TYPE_GRAY =		PIXMAN_TYPE_GRAY;
enum PICT_TYPE_BGRA =		PIXMAN_TYPE_BGRA;

enum string PICT_FORMAT_COLOR(string f) = `PIXMAN_FORMAT_COLOR(` ~ f ~ `)`;

alias PictFormatShort = pixman_format_code_t;

enum PICT_a2r10g10b10 =    PIXMAN_a2r10g10b10;
enum PICT_x2r10g10b10 =    PIXMAN_x2r10g10b10;
enum PICT_a2b10g10r10 =    PIXMAN_a2b10g10r10;
enum PICT_x2b10g10r10 =    PIXMAN_x2b10g10r10;
enum PICT_a8r8g8b8 =       PIXMAN_a8r8g8b8;
enum PICT_x8r8g8b8 =       PIXMAN_x8r8g8b8;
enum PICT_a8b8g8r8 =       PIXMAN_a8b8g8r8;
enum PICT_x8b8g8r8 =       PIXMAN_x8b8g8r8;
enum PICT_b8g8r8a8 =       PIXMAN_b8g8r8a8;
enum PICT_b8g8r8x8 =       PIXMAN_b8g8r8x8;
enum PICT_r8g8b8 =         PIXMAN_r8g8b8;
enum PICT_b8g8r8 =         PIXMAN_b8g8r8;
enum PICT_r5g6b5 =         PIXMAN_r5g6b5;
enum PICT_b5g6r5 =         PIXMAN_b5g6r5;
enum PICT_a1r5g5b5 =       PIXMAN_a1r5g5b5;
enum PICT_x1r5g5b5 =       PIXMAN_x1r5g5b5;
enum PICT_a1b5g5r5 =       PIXMAN_a1b5g5r5;
enum PICT_x1b5g5r5 =       PIXMAN_x1b5g5r5;
enum PICT_a4r4g4b4 =       PIXMAN_a4r4g4b4;
enum PICT_x4r4g4b4 =       PIXMAN_x4r4g4b4;
enum PICT_a4b4g4r4 =       PIXMAN_a4b4g4r4;
enum PICT_x4b4g4r4 =       PIXMAN_x4b4g4r4;
enum PICT_a8 =             PIXMAN_a8;
enum PICT_r3g3b2 =         PIXMAN_r3g3b2;
enum PICT_b2g3r3 =         PIXMAN_b2g3r3;
enum PICT_a2r2g2b2 =       PIXMAN_a2r2g2b2;
enum PICT_a2b2g2r2 =       PIXMAN_a2b2g2r2;
enum PICT_c8 =             PIXMAN_c8;
enum PICT_g8 =             PIXMAN_g8;
enum PICT_x4a4 =           PIXMAN_x4a4;
enum PICT_x4c4 =           PIXMAN_x4c4;
enum PICT_x4g4 =           PIXMAN_x4g4;
enum PICT_a4 =             PIXMAN_a4;
enum PICT_r1g2b1 =         PIXMAN_r1g2b1;
enum PICT_b1g2r1 =         PIXMAN_b1g2r1;
enum PICT_a1r1g1b1 =       PIXMAN_a1r1g1b1;
enum PICT_a1b1g1r1 =       PIXMAN_a1b1g1r1;
enum PICT_c4 =             PIXMAN_c4;
enum PICT_g4 =             PIXMAN_g4;
enum PICT_a1 =             PIXMAN_a1;
enum PICT_g1 =             PIXMAN_g1;
enum PICT_yuv2 =           PIXMAN_yuy2;

/*
 * For dynamic indexed visuals (GrayScale and PseudoColor), these control the
 * selection of colors allocated for drawing to Pictures.  The default
 * policy depends on the size of the colormap:
 *
 * Size		Default Policy
 * ----------------------------
 *  < 64	PolicyMono
 *  < 256	PolicyGray
 *  256		PolicyColor (only on PseudoColor)
 *
 * The actual allocation code lives in miindex.c, and so is
 * ostensibly server dependent, but that code does:
 *
 * PolicyMono	    Allocate no additional colors, use black and white
 * PolicyGray	    Allocate 13 gray levels (11 cells used)
 * PolicyColor	    Allocate a 4x4x4 cube and 13 gray levels (71 cells used)
 * PolicyAll	    Allocate as big a cube as possible, fill with gray (all)
 *
 * Here's a picture to help understand how many colors are
 * actually allocated (this is just the gray ramp):
 *
 *                 gray level
 * all   0000 1555 2aaa 4000 5555 6aaa 8000 9555 aaaa bfff d555 eaaa ffff
 * b/w   0000                                                        ffff
 * 4x4x4                     5555                aaaa
 * extra      1555 2aaa 4000      6aaa 8000 9555      bfff d555 eaaa
 *
 * The default colormap supplies two gray levels (black/white), the
 * 4x4x4 cube allocates another two and nine more are allocated to fill
 * in the 13 levels.  When the 4x4x4 cube is not allocated, a total of
 * 11 cells are allocated.
 */

enum PictureCmapPolicyInvalid =    -1;
enum PictureCmapPolicyDefault =    0;
enum PictureCmapPolicyMono =	    1;
enum PictureCmapPolicyGray =	    2;
enum PictureCmapPolicyColor =	    3;
enum PictureCmapPolicyAll =	    4;

// int PictureCmapPolicy;

// int PictureParseCmapPolicy(const(char)* name);

// int RenderErrBase;

/* Fixed point updates from Carl Worth, USC, Information Sciences Institute */

alias XFixed_32_32 = pixman_fixed_32_32_t;

alias XFixed_48_16 = pixman_fixed_48_16_t;

enum MAX_FIXED_48_16 =		pixman_max_fixed_48_16;
enum MIN_FIXED_48_16 =		pixman_min_fixed_48_16;

alias XFixed_1_31 = pixman_fixed_1_31_t;
alias XFixed_1_16 = pixman_fixed_1_16_t;
alias XFixed_16_16 = pixman_fixed_16_16_t;

/*
 * An unadorned "XFixed" is the same as XFixed_16_16,
 * (since it's quite common in the code)
 */
alias XFixed = pixman_fixed_t;

alias uint32_t = core.stdc.stdint.uint32_t;

enum XFIXED_BITS =	16;

// enum pixman_fixed_e =			(cast(pixman_fixed_t) 1);
// enum pixman_fixed_1 =			(pixman_int_to_fixed!("1"));
// enum pixman_fixed_1_minus_e =		(mixin(pixman_fixed_1) - pixman_fixed_e);
// alias pixman_fixed_minus_1		(pixman_int_to_fixed(-1))
// enum string pixman_fixed_to_int(string f) = `(cast(int) ((`~f~`) >> 16))`;
// enum string pixman_int_to_fixed(string i) =		`(cast(pixman_fixed_t) (cast(uint32_t) (`~i~`) << 16))`;
// alias pixman_fixed_to_double(f)	(double) ((f) / (double) pixman_fixed_1)
// alias pixman_double_to_fixed(d)	((pixman_fixed_t) ((d) * 65536.0))
// enum string pixman_fixed_frac(string f) = 		`((`~f~`) & pixman_fixed_1_minus_e)`;

// import glamor.glamor_render;
enum string xFixedToInt(string f) = pixman_fixed_to_int!(f);
enum string IntToxFixed(string i) = `pixman_int_to_fixed(` ~ i ~ `)`;
enum xFixedE =		pixman_fixed_e;
enum xFixed1 =		pixman_fixed_1;
enum xFixed1MinusE =	pixman_fixed_1_minus_e;
enum string xFixedFrac(string f) = pixman_fixed_frac!(f);
enum string xFixedFloor(string f) = `assumeNoGC(&pixman_fixed_floor)(` ~ f ~ `)`;
enum string xFixedCeil(string f) = `pixman_fixed_ceil(` ~ f ~ `)`;

enum string xFixedFraction(string f) = `assumeNoGC(&pixman_fixed_fraction)(` ~ f ~ `)`;
enum string xFixedMod2(string f) = `assumeNoGC(&pixman_fixed_mod2)(` ~ f ~ `)`;

/* whether 't' is a well defined not obviously empty trapezoid */
enum string xTrapezoidValid(string t) = `((` ~ t ~ `).left.p1.y != (` ~ t ~ `).left.p2.y && 
			     (` ~ t ~ `).right.p1.y != (` ~ t ~ `).right.p2.y && 
			     ((` ~ t ~ `).bottom > (` ~ t ~ `).top))`;

/*
 * Standard NTSC luminance conversions:
 *
 *  y = r * 0.299 + g * 0.587 + b * 0.114
 *
 * Approximate this for a bit more speed:
 *
 *  y = (r * 153 + g * 301 + b * 58) / 512
 *
 * This gives 17 bits of luminance; to get 15 bits, lop the low two
 */

enum string CvtR8G8B8toY15(string s) = `(((((` ~ s ~ `) >> 16) & 0xff) * 153 + 
				  (((` ~ s ~ `) >>  8) & 0xff) * 301 + 
				  (((` ~ s ~ `)      ) & 0xff) * 58) >> 2)`;

                          /* _PICTURE_H_ */
