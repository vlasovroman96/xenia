module randr.rrtransform;
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
import build.dix_config;

import include.rrtransform;
import randr.randrstr_priv;
import externs.attrs;
import include.picture;


void RRTransformInit(RRTransformPtr transform)
{
    assumeNoGC(&pixman_transform_init_identity)(&transform.transform);
    assumeNoGC(&pixman_f_transform_init_identity)(&transform.f_transform);
    assumeNoGC(&pixman_f_transform_init_identity)(&transform.f_inverse);
    transform.filter = null;
    transform.params = null;
    transform.nparams = 0;
}

Bool RRTransformEqual(RRTransformPtr a, RRTransformPtr b)
{
    if (a && assumeNoGC(&pixman_transform_is_identity)(&a.transform))
        a = null;
    if (b && assumeNoGC(&pixman_transform_is_identity)(&b.transform))
        b = null;
    if (a is null && b is null)
        return TRUE;
    if (a is null || b is null)
        return FALSE;
    if (memcmp(&a.transform, &b.transform, typeof(a.transform).sizeof) != 0)
        return FALSE;
    if (a.filter != b.filter)
        return FALSE;
    if (a.nparams != b.nparams)
        return FALSE;
    if (memcmp(a.params, b.params, a.nparams * XFixed.sizeof) != 0)
        return FALSE;
    return TRUE;
}

Bool RRTransformSetFilter(RRTransformPtr dst, PictFilterPtr filter, XFixed* params, int nparams, int width, int height)
{
    XFixed* new_params = void;

    if (nparams) {
        new_params = cast(XFixed*) calloc(nparams, XFixed.sizeof);
        if (!new_params)
            return FALSE;
        memcpy(new_params, params, nparams * XFixed.sizeof);
    }
    else
        new_params = null;
    free(dst.params);
    dst.filter = filter;
    dst.params = new_params;
    dst.nparams = nparams;
    dst.width = width;
    dst.height = height;
    return TRUE;
}

Bool RRTransformCopy(RRTransformPtr dst, RRTransformPtr src)
{
    if (src && assumeNoGC(&pixman_transform_is_identity)(&src.transform))
        src = null;

    if (src) {
        if (!RRTransformSetFilter(dst, src.filter,
                                  src.params, src.nparams, src.width,
                                  src.height))
            return FALSE;
        dst.transform = src.transform;
        dst.f_transform = src.f_transform;
        dst.f_inverse = src.f_inverse;
    }
    else {
        if (!RRTransformSetFilter(dst, null, null, 0, 0, 0))
            return FALSE;
        assumeNoGC(&pixman_transform_init_identity)(&dst.transform);
        assumeNoGC(&pixman_f_transform_init_identity)(&dst.f_transform);
        assumeNoGC(&pixman_f_transform_init_identity)(&dst.f_inverse);
    }
    return TRUE;
}

enum string F(string x) = IntToxFixed!(x);

private void RRTransformRescale(pixman_f_transform* f_transform, double limit)
{
    double max = 0, v = void, scale = void;
    int i = void, j = void;

    for (j = 0; j < 3; j++)
        for (i = 0; i < 3; i++)
            if ((v = fabs(f_transform.m[j][i])) > max)
                max = v;
    scale = limit / max;
    for (j = 0; j < 3; j++)
        for (i = 0; i < 3; i++)
            f_transform.m[j][i] *= scale;
}

/*
 * Compute the complete transformation matrix including
 * client-specified transform, rotation/reflection values and the crtc
 * offset.
 *
 * Return TRUE if the resulting transform is not a simple translation.
 */
Bool RRTransformCompute(int x, int y, int width, int height, Rotation rotation, RRTransformPtr rr_transform, PictTransformPtr transform, pixman_f_transform* f_transform, pixman_f_transform* f_inverse)
{
    PictTransform t_transform = void, inverse = void;
    pixman_f_transform tf_transform = void, tf_inverse = void;
    Bool overflow = FALSE;

    if (!transform)
        transform = &t_transform;
    if (!f_transform)
        f_transform = &tf_transform;
    if (!f_inverse)
        f_inverse = &tf_inverse;

    assumeNoGC(&pixman_transform_init_identity)(transform);
    assumeNoGC(&pixman_transform_init_identity)(&inverse);
    assumeNoGC(&pixman_f_transform_init_identity)(f_transform);
    assumeNoGC(&pixman_f_transform_init_identity)(f_inverse);
    if (rotation != RR_Rotate_0) {
        double f_rot_cos = void, f_rot_sin = void, f_rot_dx = void, f_rot_dy = void;
        double f_scale_x = void, f_scale_y = void, f_scale_dx = void, f_scale_dy = void;
        XFixed rot_cos = void, rot_sin = void, rot_dx = void, rot_dy = void;
        XFixed scale_x = void, scale_y = void, scale_dx = void, scale_dy = void;

        /* rotation */
        switch (rotation & 0xf) {
        default:
        case RR_Rotate_0:
            f_rot_cos = 1;
            f_rot_sin = 0;
            f_rot_dx = 0;
            f_rot_dy = 0;
            rot_cos = mixin(F!(`1`));
            rot_sin = mixin(F!(`0`));
            rot_dx = mixin(F!(`0`));
            rot_dy = mixin(F!(`0`));
            break;
        case RR_Rotate_90:
            f_rot_cos = 0;
            f_rot_sin = 1;
            f_rot_dx = height;
            f_rot_dy = 0;
            rot_cos = mixin(F!(`0`));
            rot_sin = mixin(F!(`1`));
            rot_dx = mixin(F!(`height`));
            rot_dy = mixin(F!(`0`));
            break;
        case RR_Rotate_180:
            f_rot_cos = -1;
            f_rot_sin = 0;
            f_rot_dx = width;
            f_rot_dy = height;
            rot_cos = mixin(F!(`~0u`));
            rot_sin = mixin(F!(`0`));
            rot_dx = mixin(F!(`width`));
            rot_dy = mixin(F!(`height`));
            break;
        case RR_Rotate_270:
            f_rot_cos = 0;
            f_rot_sin = -1;
            f_rot_dx = 0;
            f_rot_dy = width;
            rot_cos = mixin(F!(`0`));
            rot_sin = mixin(F!(`~0u`));
            rot_dx = mixin(F!(`0`));
            rot_dy = mixin(F!(`width`));
            break;
        }

        assumeNoGC(&pixman_transform_rotate)(transform, &inverse, rot_cos, rot_sin);
        assumeNoGC(&pixman_transform_translate)(transform, &inverse, rot_dx, rot_dy);
        assumeNoGC(&pixman_f_transform_rotate)(f_transform, f_inverse, f_rot_cos, f_rot_sin);
        assumeNoGC(&pixman_f_transform_translate)(f_transform, f_inverse, f_rot_dx,
                                     f_rot_dy);

        /* reflection */
        f_scale_x = 1;
        f_scale_dx = 0;
        f_scale_y = 1;
        f_scale_dy = 0;
        scale_x = mixin(F!(`1`));
        scale_dx = 0;
        scale_y = mixin(F!(`1`));
        scale_dy = 0;
        if (rotation & RR_Reflect_X) {
            f_scale_x = -1;
            scale_x = mixin(F!(`~0u`));
            if (rotation & (RR_Rotate_0 | RR_Rotate_180)) {
                f_scale_dx = width;
                scale_dx = mixin(F!(`width`));
            }
            else {
                f_scale_dx = height;
                scale_dx = mixin(F!(`height`));
            }
        }
        if (rotation & RR_Reflect_Y) {
            f_scale_y = -1;
            scale_y = mixin(F!(`~0u`));
            if (rotation & (RR_Rotate_0 | RR_Rotate_180)) {
                f_scale_dy = height;
                scale_dy = mixin(F!(`height`));
            }
            else {
                f_scale_dy = width;
                scale_dy = mixin(F!(`width`));
            }
        }

        assumeNoGC(&pixman_transform_scale)(transform, &inverse, scale_x, scale_y);
        assumeNoGC(&pixman_f_transform_scale)(f_transform, f_inverse, f_scale_x, f_scale_y);
        assumeNoGC(&pixman_transform_translate)(transform, &inverse, scale_dx, scale_dy);
        assumeNoGC(&pixman_f_transform_translate)(f_transform, f_inverse, f_scale_dx,
                                     f_scale_dy);
    }

static if (RANDR_12_INTERFACE) {
    if (rr_transform) {
        if (!pixman_transform_multiply
            (transform, &rr_transform.transform, transform))
            overflow = TRUE;
        assumeNoGC(&pixman_f_transform_multiply)(f_transform, &rr_transform.f_transform,
                                    f_transform);
        assumeNoGC(&pixman_f_transform_multiply)(f_inverse, f_inverse,
                                    &rr_transform.f_inverse);
    }
}
    /*
     * Compute the class of the resulting transform
     */
    if (!overflow && assumeNoGC(&pixman_transform_is_identity)(transform)) {
        assumeNoGC(&pixman_transform_init_translate)(transform, mixin(F!(`x`)), mixin(F!(`y`)));

        assumeNoGC(&pixman_f_transform_init_translate)(f_transform, x, y);
        assumeNoGC(&pixman_f_transform_init_translate)(f_inverse, -x, -y);
        return FALSE;
    }
    else {
        assumeNoGC(&pixman_f_transform_translate)(f_transform, f_inverse, x, y);
        if (!assumeNoGC(&pixman_transform_translate)(transform, &inverse, mixin(F!(`x`)), mixin(F!(`y`))))
            overflow = TRUE;
        if (overflow) {
            pixman_f_transform f_scaled = void;

            f_scaled = *f_transform;
            RRTransformRescale(&f_scaled, 16384.0);
            assumeNoGC(&pixman_transform_from_pixman_f_transform)(transform, &f_scaled);
        }
        return TRUE;
    }
}
