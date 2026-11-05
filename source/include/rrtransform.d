module include.rrtransform;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2007 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */

 
//public import externs.X11.extensions._randr;
public import include.picturestr;
import include.picture;

alias RRTransformRec = _rrTransform;
alias RRTransformPtr = _rrTransform*;

struct _rrTransform {
    PictTransform transform;
    pixman_f_transform f_transform;
    pixman_f_transform f_inverse;
    PictFilterPtr filter;
    XFixed* params;
    int nparams;
    int width;
    int height;
}

/*
 * Compute the complete transformation matrix including
 * client-specified transform, rotation/reflection values and the crtc
 * offset.
 *
 * Return TRUE if the resulting transform is not a simple translation.
 */
// void  RRTransformCompute(int x, int y, int width, int height, Rotation rotation, RRTransformPtr rr_transform, PictTransformPtr transform, pixman_f_transform* f_transform, pixman_f_transform* f_inverse);

                          /* _RRTRANSFORM_H_ */
