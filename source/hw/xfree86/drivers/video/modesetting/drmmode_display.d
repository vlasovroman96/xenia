module hw.xfree86.drivers.video.modesetting.drmmode_display;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2007 Red Hat, Inc.
 * Copyright © 2019 NVIDIA CORPORATION
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
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Authors:
 *    Dave Airlie <airlied@redhat.com>
 *    Aaron Plattner <aplattner@nvidia.com>
 *
 */

import build.dix_config;
import dix.pixmap;

import core.stdc.errno;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd;

import include.glamor;
import dix.dix_priv;
import os.fmt;
import present.present_priv;
import glamor.glamor;

import include.inputstr;
import include.xf86str;
//import externs.X11.Xatom;
import include.mi;
import mi.micmap;
import xf86cmap;
import xf86DDC_priv;
// import externs.libdrm;;
// import externs.libdrm;;
import externs.libdrm;;
import include.mipointer;
// import externs.drmMode;
import externs.libdrm;

import include.xf86Crtc;
import hw.xfree86.drivers.video.modesetting.drmmode_bo;

import include.cursor;
import hw.xfree86.drivers.video.modesetting.drmmode_display;
import include.randrstr; 
import include.xf86Crtc;
// //import externs.X11.extensions.dpmsconst;
import hw.xfree86.modes.xf86Crtc;
import os.string;
import hw.xfree86.common.xf86Helper;
import externs.X11.extensions.dpmsconst;
import os.log;
import hw.xfree86.drivers.video.modesetting.vblank;
import pageflip;
import include.xf86Cursor;
import dix.gc;
import xf86CursorRD;
import xf86Option;
import externs.X11.Xatom;
import randr.rrproperty;
import externs.gnu;
import xf86Rotate;
import interpret_edid;
import xf86Bus;
import externs.gnu;
import randr.rroutput;
import core.sys.posix.strings;
import hw.xfree86.drivers.video.modesetting.driver;
import include.xf86cmap;
import include.privates;
import randr.rrcrtc;
import randr.randr;
import randr.rrinfo;


enum string msGetPixmapPriv(string drmmode, string p) =`(cast(msPixmapPrivPtr)dixGetPrivateAddr(&(`~p~`).devPrivates, &(`~drmmode~`).pixmapPrivateKeyRec))`;
alias uint32_t = core.stdc.stdint.uint32_t;
alias uint64_t = core.stdc.stdint.uint64_t;
alias uint16_t = core.stdc.stdint.uint16_t;
alias UINT64_MAX = core.stdc.stdint.UINT64_MAX;


enum DRMMODE_FRONT_BO = 0;
enum DRMMODE_BACK_BO =  1;
enum DRMMODE_CURSOR_BO = 2;

struct _msPixmapPriv {
    uint32_t fb_id;
    gbm_bo *backing_bo; /* if this pixmap is backed by a gbm bo */

    DamagePtr secondary_damage;

    /** Sink fields for flipping shared pixmaps */
    int flip_seq; /* seq of current page flip event handler */
    Bool wait_for_damage; /* if we have requested damage notification from source */

    /** Source fields for flipping shared pixmaps */
    Bool defer_dirty_update; /* if we want to manually update */
    PixmapDirtyUpdatePtr dirty; /* cached dirty ent to avoid searching list */
    DrawablePtr secondary_src; /* if we exported shared pixmap, dirty tracking src */
    Bool notify_on_damage; /* if sink has requested damage notification */
} 
alias msPixmapPrivRec = _msPixmapPriv;
alias msPixmapPrivPtr = msPixmapPrivRec*;

alias drmmode_plane_property = int;

enum :drmmode_plane_property {
    DRMMODE_PLANE_TYPE = 0,
    DRMMODE_PLANE_FB_ID,
    DRMMODE_PLANE_IN_FORMATS,
    DRMMODE_PLANE_IN_FORMATS_ASYNC,
    DRMMODE_PLANE_CRTC_ID,
    DRMMODE_PLANE_SRC_X,
    DRMMODE_PLANE_SRC_Y,
    DRMMODE_PLANE_SRC_W,
    DRMMODE_PLANE_SRC_H,
    DRMMODE_PLANE_CRTC_X,
    DRMMODE_PLANE_CRTC_Y,
    DRMMODE_PLANE_CRTC_W,
    DRMMODE_PLANE_CRTC_H,
    DRMMODE_PLANE_SIZE_HINTS,
    DRMMODE_PLANE__COUNT
};

alias drmmode_plane_type = int;

enum :drmmode_plane_type {
    DRMMODE_PLANE_TYPE_PRIMARY = 0,
    DRMMODE_PLANE_TYPE_CURSOR,
    DRMMODE_PLANE_TYPE_OVERLAY,
    DRMMODE_PLANE_TYPE__COUNT
};

alias drmmode_connector_property = int;

enum :drmmode_connector_property {
    DRMMODE_CONNECTOR_CRTC_ID,
    DRMMODE_CONNECTOR__COUNT
};

alias drmmode_crtc_property = int;

enum :drmmode_crtc_property {
    DRMMODE_CRTC_ACTIVE,
    DRMMODE_CRTC_MODE_ID,
    DRMMODE_CRTC_GAMMA_LUT,
    DRMMODE_CRTC_GAMMA_LUT_SIZE,
    DRMMODE_CRTC_CTM,
    DRMMODE_CRTC__COUNT
};


enum string MIN(string a,string b) = `((` ~ a ~ `) < (` ~ b ~ `) ? (` ~ a ~ `) : (` ~ b ~ `))`;
enum string MAX(string a,string b) = `((` ~ a ~ `) > (` ~ b ~ `) ? (` ~ a ~ `) : (` ~ b ~ `))`;
enum string msGetSpritePriv(string dev, string ms, string screen) =`
    dixLookupScreenPrivate(&(`~dev~`).devPrivates, &(`~ms~`).drmmode.spritePrivateKeyRec, (`~screen~`))
 `;
// enum GBM_BO_USE_FRONT_RENDERING = 0;



struct drmmode_cursor_dim_rec {
    uint16_t width, height;
}
alias drmmode_cursor_dim_ptr = drmmode_cursor_dim_rec*;

struct drmmode_cursor_rec{
    uint16_t num_dimensions;

    /* Sorted from smallest to largest. */
    drmmode_cursor_dim_rec* dimensions;
    gbm_bo *bo;
} 
alias drmmode_cursor_ptr = drmmode_cursor_rec*;

struct drmmode_format_rec{
    uint32_t format;
    uint32_t num_modifiers;
    uint64_t *modifiers;
}

alias drmmode_format_ptr = drmmode_format_rec*;

struct drmmode_prop_info_rec{
    const char *name;
    uint32_t prop_id;
    uint64_t value;
    uint num_enum_values;
    drmmode_prop_enum_info_rec *enum_values;
} 

alias drmmode_prop_info_ptr = drmmode_prop_info_rec*;

struct drmmode_lease_private_rec{
    uint32_t    lessee_id;
}

alias drmmode_lease_private_ptr = drmmode_lease_private_rec*;

struct drmmode_prop_enum_info_rec{
    const char *name;
    Bool valid;
    uint64_t value;
} 
alias drmmode_prop_enum_info_ptr = drmmode_prop_enum_info_rec*;

struct drmmode_mode_rec{
    drmModeModeInfo mode_info;
    uint32_t blob_id;
    xorg_list entry;
} 
alias drmmode_mode_ptr = drmmode_mode_rec*;


struct drmmode_crtc_private_rec {
    drmmode_ptr drmmode;
    drmModeCrtcPtr mode_crtc;
    uint32_t vblank_pipe;
    int dpms_mode;
    drmmode_cursor_rec cursor;
    Bool cursor_up;

    uint16_t[256] lut_r, lut_g, lut_b;

    drmmode_prop_info_rec[DRMMODE_CRTC__COUNT] props;
    drmmode_prop_info_rec[DRMMODE_PLANE__COUNT] props_plane;
    uint32_t plane_id;
    drmmode_mode_ptr current_mode;
    uint32_t num_formats;
    drmmode_format_rec *formats;
    drmmode_format_rec *formats_async;

    gbm_bo *rotate_bo;
    uint rotate_fb_id;
    drmmode_tearfree_rec tearfree;

    PixmapPtr prime_pixmap;
    PixmapPtr prime_pixmap_back;
    uint prime_pixmap_x;

    int src_x, src_y;

    /**
     * @{ MSC (vblank count) handling for the PRESENT extension.
     *
     * The kernel's vblank counters are 32 bits and apparently full of
     * lies, and we need to give a reliable 64-bit msc for GL, so we
     * have to track and convert to a userland-tracked 64-bit msc.
     */
    uint32_t msc_prev;
    uint64_t msc_high;
    /** @} */

    uint64_t next_msc;

    int cursor_width;
    int cursor_height;

    Bool need_modeset;
    xorg_list mode_list;

    Bool enable_flipping;
    Bool flipping_active;

    Bool vrr_enabled;
    Bool use_gamma_lut;

    /* For damage-like tracking of the cursor buffer */
    uint32_t cursor_glyph_width;
    uint32_t cursor_glyph_height;
    int old_pitch;
    int cursor_rotation;
    int cursor_src_x;
    int cursor_src_y;

    Bool cursor_probed;
    Bool cursor_dim_fallback_warned;

    int* cursor_pitches;
}

alias drmmode_crtc_private_ptr = drmmode_crtc_private_rec*;

struct drmmode_shadow_fb_rec{
    gbm_bo *bo;
    uint32_t fb_id;
    PixmapPtr px;
    RegionRec dmg;
} 
alias drmmode_shadow_fb_ptr = drmmode_shadow_fb_rec*;

struct drmmode_tearfree_rec{
    drmmode_shadow_fb_rec[2] buf;
    xorg_list dri_flip_list;
    uint32_t back_idx;
    uint32_t flip_seq;
} 
alias drmmode_tearfree_ptr = drmmode_tearfree_rec*;

struct drmmode_rec {
    int fd;
    uint fb_id;
    drmModeFBPtr mode_fb;
    int cpp;
    int kbpp;
    ScrnInfoPtr scrn;

    gbm_device *gbm;

// #ifdef CONFIG_UDEV_KMS
//     udev_monitor *uevent_monitor;
//     InputHandlerProc uevent_handler;
// #endif
    drmEventContext event_context;
    gbm_bo *front_bo;
    Bool sw_cursor;
    Bool set_cursor_failed;

    /* Broken-out options. */
    OptionInfoPtr Options;

    Bool glamor;
    Bool glamor_gbm;
    Bool glamor_gbm_device;
    Bool shadow_enable;
    Bool shadow_enable2;
    /** Is Option "PageFlip" enabled? */
    Bool pageflip;
    Bool force_24_32;
    void *shadow_fb;
    void *shadow_fb2;

    DevPrivateKeyRec pixmapPrivateKeyRec;
    DevScreenPrivateKeyRec spritePrivateKeyRec;
    DevPrivateKeyRec vrrPrivateKeyRec;
    /* Number of SW cursors currently visible on this screen */
    int sprites_visible;

    Bool reverse_prime_offload_mode;

    Bool is_secondary;

    PixmapPtr fbcon_pixmap;

    Bool dri2_flipping;
    Bool present_flipping;
    Bool flip_bo_import_failed;

    Bool can_async_flip;
    Bool async_flip_secondaries;
    Bool dri2_enable;
    Bool present_enable;
    Bool tearfree_enable;

    uint32_t vrr_prop_id;
    Bool use_ctm;

    Bool pending_modeset;
} 
alias drmmode_ptr = drmmode_rec*;

struct drmmode_output_private_rec{
    drmmode_ptr drmmode;
    int output_id;
    drmModeConnectorPtr mode_output;
    drmModeEncoderPtr *mode_encoders;
    drmModePropertyBlobPtr edid_blob;
    drmModePropertyBlobPtr tile_blob;
    int dpms_enum_id;
    int dpms;
    int num_props;
    drmmode_prop_ptr props;
    drmmode_prop_info_rec[DRMMODE_CONNECTOR__COUNT] props_connector;
    int enc_mask;
    int enc_clone_mask;
    xf86CrtcPtr current_crtc;
    Atom ctm_atom;
    drm_color_ctm ctm;
} 
alias drmmode_output_private_ptr = drmmode_output_private_rec*;

struct drmmode_prop_rec{
    drmModePropertyPtr mode_prop;
    uint64_t value;
    int num_atoms;              /* if range prop, num_atoms == 1; if enum prop, num_atoms == num_enums + 1 */
    Atom *atoms;
} 
alias drmmode_prop_ptr = drmmode_prop_rec*;

struct _msSpritePriv {
    CursorPtr cursor;
    Bool sprite_visible;
} 
alias msSpritePrivRec = _msSpritePriv; 
alias msSpritePrivPtr = msSpritePrivRec*;

private const(drm_color_ctm) ctm_identity = {
    [1UL << 32, 0, 0,
    0, 1UL << 32, 0,
    0, 0, 1UL << 32]
 } ;

private Bool ctm_is_identity(const(drm_color_ctm)* ctm)
{
    const(size_t) matrix_len = cast(size_t)((ctm.matrix).sizeof / typeof(ctm.matrix[0]).sizeof);
    const(ulong) one = 1UL << 32;
    const(ulong) neg_zero = 1UL << 63;
    int i = void;

    for (i = 0; i < matrix_len; i++) {
        const(Bool) diagonal = i / 3 == i % 3;
        const(ulong) val = ctm.matrix[i];

        if ((diagonal && val != one) ||
            (!diagonal && val != 0 && val != neg_zero)) {
            return FALSE;
        }
    }

    return TRUE;
}

pragma(inline, true) private uint* formats_ptr(drm_format_modifier_blob* blob)
{
    return cast(uint*)((cast(char*)blob) + blob.formats_offset);
}

pragma(inline, true) private drm_format_modifier* modifiers_ptr(drm_format_modifier_blob* blob)
{
    return cast(drm_format_modifier*)((cast(char*)blob) + blob.modifiers_offset);
}

private uint get_opaque_format(uint format)
{
    switch (format) {
    case DRM_FORMAT_ARGB8888:
        return DRM_FORMAT_XRGB8888;
    case DRM_FORMAT_ARGB2101010:
        return DRM_FORMAT_XRGB2101010;
    default:
        return format;
    }
}

private drmmode_format_ptr drmmode_crtc_get_format(drmmode_crtc_private_ptr drmmode_crtc, Bool async_flip, int i)
{
    if (async_flip && drmmode_crtc.formats_async)
        return &drmmode_crtc.formats_async[i];
    else
        return &drmmode_crtc.formats[i];
}

Bool drmmode_is_format_supported(ScrnInfoPtr scrn, uint format, ulong modifier, Bool async_flip)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int c = void, i = void, j = void;

    /* BO are imported as opaque surface, so let's pretend there is no alpha */
    format = get_opaque_format(format);

    for (c = 0; c < xf86_config.num_crtc; c++) {
        xf86CrtcPtr crtc = xf86_config.crtc[c];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
        Bool found = FALSE;

        if (!crtc.enabled)
            continue;

        if (drmmode_crtc.num_formats == 0)
            continue;

        for (i = 0; i < drmmode_crtc.num_formats; i++) {
            drmmode_format_ptr iter = drmmode_crtc_get_format(drmmode_crtc, async_flip, i);

            if (iter.format != format)
                continue;

            if (modifier == DRM_FORMAT_MOD_INVALID ||
                iter.num_modifiers == 0) {
                found = TRUE;
                break;
            }

            for (j = 0; j < iter.num_modifiers; j++) {
                if (iter.modifiers[j] == modifier) {
                    found = TRUE;
                    break;
                }
            }

            break;
        }

        if (!found)
            return FALSE;
    }

    return TRUE;
}

static if (GBM_BO_WITH_MODIFIERS) {
uint get_modifiers_set(ScrnInfoPtr scrn, uint format, ulong** modifiers, Bool enabled_crtc_only, Bool exclude_multiplane, Bool async_flip)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    drmmode_ptr drmmode = &ms.drmmode;
    int c = void, i = void, j = void, k = void, count_modifiers = 0;
    ulong* tmp = void, ret = null;

    /* BOs are imported as opaque surfaces, so pretend the same thing here */
    format = get_opaque_format(format);

    *modifiers = null;
    for (c = 0; c < xf86_config.num_crtc; c++) {
        xf86CrtcPtr crtc = xf86_config.crtc[c];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

        if (enabled_crtc_only && !crtc.enabled)
            continue;

        for (i = 0; i < drmmode_crtc.num_formats; i++) {
            drmmode_format_ptr iter = drmmode_crtc_get_format(drmmode_crtc, async_flip, i);

            if (iter.format != format)
                continue;

            for (j = 0; j < iter.num_modifiers; j++) {
                Bool found = FALSE;

                /* Don't choose multi-plane formats for our screen pixmap.
                 * These will get used with frontbuffer rendering, which will
                 * lead to worse-than-tearing with multi-plane formats, as the
                 * primary and auxiliary planes go out of sync. */
                if (exclude_multiplane &&
                    gbm_device_get_format_modifier_plane_count(drmmode.gbm,
                                                               format,
                                                               iter.modifiers[j]) > 1) {
                    continue;
                }

                for (k = 0; k < count_modifiers; k++) {
                    if (iter.modifiers[j] == ret[k])
                        found = TRUE;
                }
                if (!found) {
                    count_modifiers++;
                    tmp = cast(ulong*) realloc(ret, count_modifiers * ulong.sizeof);
                    if (!tmp) {
                        free(ret);
                        return 0;
                    }
                    ret = tmp;
                    ret[count_modifiers - 1] = iter.modifiers[j];
                }
            }
        }
    }

    *modifiers = ret;
    return count_modifiers;
}

private Bool get_drawable_modifiers(DrawablePtr draw, uint format, uint* num_modifiers, ulong** modifiers)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(draw.pScreen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    Bool async_flip = void;

    if (!present_can_window_flip(cast(WindowPtr) draw) ||
        !ms.drmmode.pageflip || ms.drmmode.dri2_flipping || !scrn.vtSema) {
        *num_modifiers = 0;
        *modifiers = null;
        return TRUE;
    }

    async_flip = ms_window_has_async_flip(cast(WindowPtr)draw);
    ms_window_update_async_flip_modifiers(cast(WindowPtr)draw, async_flip);

    *num_modifiers = get_modifiers_set(scrn, format, modifiers,
                                       TRUE, FALSE, async_flip);
    return TRUE;
}
}

private Bool drmmode_zaphod_string_matches(ScrnInfoPtr scrn, const(char)* s, char* output_name)
{
    char** token = xstrtokenize(s, ", \t\n\r");
    Bool ret = FALSE;

    if (!token)
        return FALSE;

    for (int i = 0; token[i]; i++) {
        if (strcmp(token[i], output_name) == 0)
            ret = TRUE;

        free(token[i]);
    }

    free(token);

    return ret;
}

private ulong drmmode_prop_get_value(drmmode_prop_info_ptr info, drmModeObjectPropertiesPtr props, ulong def)
{
    uint i = void;

    if (info.prop_id == 0)
        return def;

    for (i = 0; i < props.count_props; i++) {
        uint j = void;

        if (props.props[i] != info.prop_id)
            continue;

        /* Simple (non-enum) types can return the value directly */
        if (info.num_enum_values == 0)
            return props.prop_values[i];

        /* Map from raw value to enum value */
        for (j = 0; j < info.num_enum_values; j++) {
            if (!info.enum_values[j].valid)
                continue;
            if (info.enum_values[j].value != props.prop_values[i])
                continue;

            return j;
        }
    }

    return def;
}

private uint drmmode_prop_info_update(drmmode_ptr drmmode, drmmode_prop_info_ptr info, uint num_infos, drmModeObjectProperties* props)
{
    drmModePropertyRes* prop = void;
    uint valid_mask = 0;
    uint i = void, j = void;

    assert(num_infos <= 32 && "update return type");

    for (i = 0; i < props.count_props; i++) {
        Bool props_incomplete = FALSE;
        uint k = void;

        for (j = 0; j < num_infos; j++) {
            if (info[j].prop_id == props.props[i])
                break;
            if (!info[j].prop_id)
                props_incomplete = TRUE;
        }

        /* We've already discovered this property. */
        if (j != num_infos)
            continue;

        /* We haven't found this property ID, but as we've already
         * found all known properties, we don't need to look any
         * further. */
        if (!props_incomplete)
            break;

        prop = drmModeGetProperty(drmmode.fd, props.props[i]);
        if (!prop)
            continue;

        for (j = 0; j < num_infos; j++) {
            if (!strcmp(prop.name.ptr, info[j].name))
                break;
        }

        /* We don't know/care about this property. */
        if (j == num_infos) {
            drmModeFreeProperty(prop);
            continue;
        }

        info[j].prop_id = props.props[i];
        info[j].value = props.prop_values[i];
        valid_mask |= 1U << j;

        if (info[j].num_enum_values == 0) {
            drmModeFreeProperty(prop);
            continue;
        }

        if (!(prop.flags & DRM_MODE_PROP_ENUM)) {
            xf86DrvMsg(drmmode.scrn.scrnIndex, X_WARNING,
                       "expected property %s to be an enum,"
                       ~ " but it is not; ignoring\n", prop.name.ptr);
            drmModeFreeProperty(prop);
            continue;
        }

        for (k = 0; k < info[j].num_enum_values; k++) {
            int l = void;

            if (info[j].enum_values[k].valid)
                continue;

            for (l = 0; l < prop.count_enums; l++) {
                if (!strcmp(prop.enums[l].name.ptr,
                            info[j].enum_values[k].name))
                    break;
            }

            if (l == prop.count_enums)
                continue;

            info[j].enum_values[k].valid = TRUE;
            info[j].enum_values[k].value = prop.enums[l].value;
        }

        drmModeFreeProperty(prop);
    }

    return valid_mask;
}

private Bool drmmode_prop_info_copy(drmmode_prop_info_ptr dst, const(drmmode_prop_info_rec)* src, uint num_props, Bool copy_prop_id)
{
    uint i = void;

    memcpy(dst, src, num_props * typeof(*dst).sizeof);

    for (i = 0; i < num_props; i++) {
        uint j = void;

        if (copy_prop_id)
            dst[i].prop_id = src[i].prop_id;
        else
            dst[i].prop_id = 0;

        if (src[i].num_enum_values == 0)
            continue;

        dst[i].enum_values =
            cast(drmmode_prop_enum_info_rec*)calloc(src[i].num_enum_values,
                    typeof(*dst[i].enum_values).sizeof);
        if (!dst[i].enum_values)
            goto err;

        memcpy(dst[i].enum_values, src[i].enum_values,
                src[i].num_enum_values * typeof(*dst[i].enum_values).sizeof);

        for (j = 0; j < dst[i].num_enum_values; j++)
            dst[i].enum_values[j].valid = FALSE;
    }

    return TRUE;

err:
    while (i--)
        free(dst[i].enum_values);
    return FALSE;
}

private void drmmode_prop_info_free(drmmode_prop_info_ptr info, int num_props)
{
    int i = void;

    for (i = 0; i < num_props; i++)
        free(info[i].enum_values);
}




private int plane_add_prop(drmModeAtomicReq* req, drmmode_crtc_private_ptr drmmode_crtc, drmmode_plane_property prop, ulong val)
{
    drmmode_prop_info_ptr info = &drmmode_crtc.props_plane[prop];
    int ret = void;

    if (!info)
        return -1;

    ret = drmModeAtomicAddProperty(req, drmmode_crtc.plane_id,
                                   info.prop_id, val);
    return (ret <= 0) ? -1 : 0;
}

private int plane_add_props(drmModeAtomicReq* req, xf86CrtcPtr crtc, uint fb_id, int x, int y)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    int ret = 0;

    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_FB_ID,
                          fb_id);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_CRTC_ID,
                          fb_id ? drmmode_crtc.mode_crtc.crtc_id : 0);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_SRC_X, x << 16);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_SRC_Y, y << 16);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_SRC_W,
                          crtc.mode.HDisplay << 16);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_SRC_H,
                          crtc.mode.VDisplay << 16);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_CRTC_X, 0);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_CRTC_Y, 0);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_CRTC_W,
                          crtc.mode.HDisplay);
    ret |= plane_add_prop(req, drmmode_crtc, DRMMODE_PLANE_CRTC_H,
                          crtc.mode.VDisplay);

    return ret;
}

private int crtc_add_prop(drmModeAtomicReq* req, drmmode_crtc_private_ptr drmmode_crtc, drmmode_crtc_property prop, ulong val)
{
    drmmode_prop_info_ptr info = &drmmode_crtc.props[prop];
    int ret = void;

    if (!info)
        return -1;

    ret = drmModeAtomicAddProperty(req, drmmode_crtc.mode_crtc.crtc_id,
                                   info.prop_id, val);
    return (ret <= 0) ? -1 : 0;
}

private int connector_add_prop(drmModeAtomicReq* req, drmmode_output_private_ptr drmmode_output, drmmode_connector_property prop, ulong val)
{
    drmmode_prop_info_ptr info = &drmmode_output.props_connector[prop];
    int ret = void;

    if (!info)
        return -1;

    ret = drmModeAtomicAddProperty(req, drmmode_output.output_id,
                                   info.prop_id, val);
    return (ret <= 0) ? -1 : 0;
}

private int drmmode_CompareKModes(const(drmModeModeInfo)* kmode, const(drmModeModeInfo)* other)
{
    return memcmp(kmode, other, typeof(*kmode).sizeof);
}

private int drm_mode_ensure_blob(xf86CrtcPtr crtc, const(drmModeModeInfo)* mode_info)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_mode_ptr mode = void;
    int ret = void;

    if (drmmode_crtc.current_mode &&
        drmmode_CompareKModes(&drmmode_crtc.current_mode.mode_info, mode_info) == 0)
        return 0;

    mode = cast(drmmode_mode_rec*) calloc(1, drmmode_mode_rec.sizeof);
    if (!mode)
        return -1;

    mode.mode_info = *mode_info;
    ret = drmModeCreatePropertyBlob(ms.fd,
                                    &mode.mode_info,
                                    typeof(mode.mode_info).sizeof,
                                    &mode.blob_id);
    drmmode_crtc.current_mode = mode;
    xorg_list_add(&mode.entry, &drmmode_crtc.mode_list);

    return ret;
}

private int crtc_add_dpms_props(drmModeAtomicReq* req, xf86CrtcPtr crtc, int new_dpms, Bool* active)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_rec*)crtc.driver_private;
    Bool crtc_active = FALSE;
    int i = void;
    int ret = 0;

    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];
        drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;

        if (output.crtc != crtc) {
            if (drmmode_output.current_crtc == crtc) {
                ret |= connector_add_prop(req, drmmode_output,
                                          DRMMODE_CONNECTOR_CRTC_ID, 0);
            }
            continue;
        }

        if (drmmode_output.output_id == -1)
            continue;

        if (new_dpms == DPMSModeOn)
            crtc_active = TRUE;

        ret |= connector_add_prop(req, drmmode_output,
                                  DRMMODE_CONNECTOR_CRTC_ID,
                                  crtc_active ?
                                      drmmode_crtc.mode_crtc.crtc_id : 0);
    }

    if (crtc_active) {
        drmModeModeInfo kmode = void;

        drmmode_ConvertToKMode(crtc.scrn, &kmode, &crtc.mode);
        ret |= drm_mode_ensure_blob(crtc, &kmode);

        ret |= crtc_add_prop(req, drmmode_crtc,
                             DRMMODE_CRTC_ACTIVE, 1);
        ret |= crtc_add_prop(req, drmmode_crtc,
                             DRMMODE_CRTC_MODE_ID,
                             drmmode_crtc.current_mode.blob_id);
    } else {
        ret |= crtc_add_prop(req, drmmode_crtc,
                             DRMMODE_CRTC_ACTIVE, 0);
        ret |= crtc_add_prop(req, drmmode_crtc,
                             DRMMODE_CRTC_MODE_ID, 0);
    }

    if (active)
        *active = crtc_active;

    return ret;
}

private void drm_mode_destroy(xf86CrtcPtr crtc, drmmode_mode_ptr mode)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    if (mode.blob_id)
        drmModeDestroyPropertyBlob(ms.fd, mode.blob_id);
    xorg_list_del(&mode.entry);
    free(mode);
}

private int drmmode_crtc_can_test_mode(xf86CrtcPtr crtc)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));

    return ms.atomic_modeset;
}

Bool drmmode_crtc_get_fb_id(xf86CrtcPtr crtc, uint* fb_id, int* x, int* y)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmmode_tearfree_ptr trf = &drmmode_crtc.tearfree;
    int ret = void;

    *fb_id = 0;

    if (drmmode_crtc.prime_pixmap) {
        if (!drmmode.reverse_prime_offload_mode) {
            msPixmapPrivPtr ppriv = mixin(msGetPixmapPriv!("drmmode", "drmmode_crtc.prime_pixmap"));
            *fb_id = ppriv.fb_id;
            *x = 0;
        } else {
            *fb_id = drmmode.fb_id;
            *x = drmmode_crtc.prime_pixmap_x;
        }
        *y = 0;
    }
    else if (trf.buf[trf.back_idx ^ 1].px) {
        *fb_id = trf.buf[trf.back_idx ^ 1].fb_id;
        *x = *y = 0;
    }
    else if (drmmode_crtc.rotate_fb_id) {
        *fb_id = drmmode_crtc.rotate_fb_id;
        *x = *y = 0;
    }
    else {
        *fb_id = drmmode.fb_id;
        *x = crtc.x;
        *y = crtc.y;
    }

    if (*fb_id == 0) {
        ret = drmmode_bo_import(drmmode, drmmode.front_bo,
                                &drmmode.fb_id);
        if (ret < 0) {
            ErrorF("failed to add fb %d\n", ret);
            return FALSE;
        }
        *fb_id = drmmode.fb_id;
    }

    return TRUE;
}

void drmmode_set_dpms(ScrnInfoPtr scrn, int dpms, int flags)
{
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    drmModeAtomicReq* req = drmModeAtomicAlloc();
    uint mode_flags = DRM_MODE_ATOMIC_ALLOW_MODESET;
    int ret = 0;
    int i = void;

    assert(ms.atomic_modeset);

    if (!req)
        return;

    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];
        drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;

        if (output.crtc !is null)
            continue;

        ret = connector_add_prop(req, drmmode_output,
                                 DRMMODE_CONNECTOR_CRTC_ID, 0);
    }

    for (i = 0; i < xf86_config.num_crtc; i++) {
        xf86CrtcPtr crtc = xf86_config.crtc[i];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
        Bool active = FALSE;

        ret |= crtc_add_dpms_props(req, crtc, dpms, &active);

        if (dpms == DPMSModeOn && active && drmmode_crtc.need_modeset) {
            uint fb_id = void;
            int x = void, y = void;

            if (!drmmode_crtc_get_fb_id(crtc, &fb_id, &x, &y))
                continue;
            ret |= plane_add_props(req, crtc, fb_id, x, y);
            drmmode_crtc.need_modeset = FALSE;
        }
    }

    if (ret == 0)
        drmModeAtomicCommit(ms.fd, req, mode_flags, null);
    drmModeAtomicFree(req);

    ms.pending_modeset = TRUE;
    xf86DPMSSet(scrn, dpms, flags);
    ms.pending_modeset = FALSE;
}

private int drmmode_output_disable(xf86OutputPtr output)
{
    modesettingPtr ms = mixin(modesettingPTR!("output.scrn"));
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    xf86CrtcPtr crtc = drmmode_output.current_crtc;
    drmModeAtomicReq* req = drmModeAtomicAlloc();
    uint flags = DRM_MODE_ATOMIC_ALLOW_MODESET;
    int ret = 0;

    assert(ms.atomic_modeset);

    if (!req)
        return 1;

    ret |= connector_add_prop(req, drmmode_output,
                              DRMMODE_CONNECTOR_CRTC_ID, 0);
    if (crtc)
        ret |= crtc_add_dpms_props(req, crtc, DPMSModeOff, null);

    if (ret == 0)
        ret = drmModeAtomicCommit(ms.fd, req, flags, null);

    if (ret == 0)
        drmmode_output.current_crtc = null;

    drmModeAtomicFree(req);
    return ret;
}

private int drmmode_crtc_disable(xf86CrtcPtr crtc)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmModeAtomicReq* req = drmModeAtomicAlloc();
    uint flags = DRM_MODE_ATOMIC_ALLOW_MODESET;
    int ret = 0;

    assert(ms.atomic_modeset);

    if (!req)
        return 1;

    ret |= crtc_add_prop(req, drmmode_crtc,
                         DRMMODE_CRTC_ACTIVE, 0);
    ret |= crtc_add_prop(req, drmmode_crtc,
                         DRMMODE_CRTC_MODE_ID, 0);

    if (ret == 0)
        ret = drmModeAtomicCommit(ms.fd, req, flags, null);

    drmModeAtomicFree(req);
    return ret;
}

private void drmmode_set_ctm(xf86CrtcPtr crtc, const(drm_color_ctm)* ctm)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmmode_prop_info_ptr ctm_info = &drmmode_crtc.props[DRMMODE_CRTC_CTM];
    int ret = void;
    uint blob_id = 0;

    if (ctm_info.prop_id == 0)
        return;

    if (ctm && drmmode_crtc.use_gamma_lut && !ctm_is_identity(ctm)) {
        ret = drmModeCreatePropertyBlob(drmmode.fd, ctm, typeof(*ctm).sizeof, &blob_id);
        if (ret != 0) {
            xf86DrvMsg(crtc.scrn.scrnIndex, X_ERROR,
                       "Failed to create CTM property blob: %d\n", ret);
            blob_id = 0;
        }
    }

    ret = drmModeObjectSetProperty(drmmode.fd,
                                   drmmode_crtc.mode_crtc.crtc_id,
                                   DRM_MODE_OBJECT_CRTC, ctm_info.prop_id,
                                   blob_id);
    if (ret != 0)
        xf86DrvMsg(crtc.scrn.scrnIndex, X_ERROR,
                   "Failed to set CTM property: %d\n", ret);

    drmModeDestroyPropertyBlob(drmmode.fd, blob_id);
}

private int drmmode_crtc_set_mode(xf86CrtcPtr crtc, Bool test_only)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmModeModeInfo kmode = void;
    int output_count = 0;
    uint* output_ids = null;
    uint fb_id = void;
    int x = void, y = void;
    int i = void, ret = 0;
    const(drm_color_ctm)* ctm = null;

    if (!drmmode_crtc_get_fb_id(crtc, &fb_id, &x, &y))
        return 1;

static if (GLAMOR) {
    /* Make sure any pending drawing will be visible in a new scanout buffer */
    if (drmmode.glamor_gbm)
        glamor_finish(crtc.scrn.pScreen);
}

    if (ms.atomic_modeset) {
        drmModeAtomicReq* req = drmModeAtomicAlloc();
        Bool active = void;
        uint flags = DRM_MODE_ATOMIC_ALLOW_MODESET;

        if (!req)
            return 1;

        ret |= crtc_add_dpms_props(req, crtc, DPMSModeOn, &active);
        ret |= plane_add_props(req, crtc, active ? fb_id : 0, x, y);

        /* Orphaned CRTCs need to be disabled right now in atomic mode */
        for (i = 0; i < xf86_config.num_crtc; i++) {
            xf86CrtcPtr other_crtc = xf86_config.crtc[i];
            drmmode_crtc_private_ptr other_drmmode_crtc = cast(drmmode_crtc_private_ptr)other_crtc.driver_private;
            int lost_outputs = 0;
            int remaining_outputs = 0;
            int j = void;

            if (other_crtc == crtc)
                continue;

            for (j = 0; j < xf86_config.num_output; j++) {
                xf86OutputPtr output = xf86_config.output[j];
                drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;

                if (drmmode_output.current_crtc == other_crtc) {
                    if (output.crtc == crtc)
                        lost_outputs++;
                    else
                        remaining_outputs++;
                }
            }

            if (lost_outputs > 0 && remaining_outputs == 0) {
                ret |= crtc_add_prop(req, other_drmmode_crtc,
                                     DRMMODE_CRTC_ACTIVE, 0);
                ret |= crtc_add_prop(req, other_drmmode_crtc,
                                     DRMMODE_CRTC_MODE_ID, 0);
            }
        }

        if (test_only)
            flags |= DRM_MODE_ATOMIC_TEST_ONLY;

        if (ret == 0)
            ret = drmModeAtomicCommit(ms.fd, req, flags, null);

        if (ret == 0 && !test_only) {
            for (i = 0; i < xf86_config.num_output; i++) {
                xf86OutputPtr output = xf86_config.output[i];
                drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;

                if (output.crtc == crtc)
                    drmmode_output.current_crtc = crtc;
                else if (drmmode_output.current_crtc == crtc)
                    drmmode_output.current_crtc = null;
            }
        }

        drmModeAtomicFree(req);
        return ret;
    }

    output_ids = cast(uint*) calloc(xf86_config.num_output, uint.sizeof);
    if (!output_ids)
        return -1;

    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];
        drmmode_output_private_ptr drmmode_output = void;

        if (output.crtc != crtc)
            continue;

        drmmode_output = cast(drmmode_output_private_rec*)output.driver_private;
        if (drmmode_output.output_id == -1)
            continue;
        output_ids[output_count] = drmmode_output.output_id;
        output_count++;

        ctm = &drmmode_output.ctm;
    }

    drmmode_ConvertToKMode(crtc.scrn, &kmode, &crtc.mode);
    ret = drmModeSetCrtc(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                         fb_id, x, y, output_ids, output_count, &kmode);
    if (!ret && !ms.atomic_modeset) {
        drmmode_crtc.src_x = x;
        drmmode_crtc.src_y = y;
    }

    drmmode_set_ctm(crtc, ctm);

    free(output_ids);
    return ret;
}

int drmmode_crtc_flip(xf86CrtcPtr crtc, uint fb_id, int x, int y, uint flags, void* data)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    int ret = void;

    if (ms.atomic_modeset) {
        drmModeAtomicReq* req = drmModeAtomicAlloc();

        if (!req)
            return 1;

        ret = plane_add_props(req, crtc, fb_id, x, y);
        flags |= DRM_MODE_ATOMIC_NONBLOCK;
        if (ret == 0)
            ret = drmModeAtomicCommit(ms.fd, req, flags, data);
        drmModeAtomicFree(req);
        return ret;
    }

    /* The frame buffer source coordinates may change when switching between the
     * primary frame buffer and a per-CRTC frame buffer. Set the correct source
     * coordinates if they differ for this flip.
     */
    if (drmmode_crtc.src_x != x || drmmode_crtc.src_y != y) {
        ret = drmModeSetPlane(ms.fd, drmmode_crtc.plane_id,
                              drmmode_crtc.mode_crtc.crtc_id, fb_id, 0,
                              0, 0, crtc.mode.HDisplay, crtc.mode.VDisplay,
                              x << 16, y << 16, crtc.mode.HDisplay << 16,
                              crtc.mode.VDisplay << 16);
        if (ret) {
            xf86DrvMsg(crtc.scrn.scrnIndex, X_WARNING,
                       "error changing fb src coordinates for flip: %d\n", ret);
            return ret;
        }

        drmmode_crtc.src_x = x;
        drmmode_crtc.src_y = y;
    }

    return drmModePageFlip(ms.fd, drmmode_crtc.mode_crtc.crtc_id,
                           fb_id, flags, data);
}

Bool drmmode_SetSlaveBO(PixmapPtr ppix, drmmode_ptr drmmode, int fd_handle, int pitch, int size)
{
    msPixmapPrivPtr ppriv = mixin(msGetPixmapPriv!("drmmode", "ppix"));

    if (fd_handle == -1) {
        gbm_bo_destroy(ppriv.backing_bo);
        ppriv.backing_bo = null;
        return TRUE;
    }

    ppriv.backing_bo = gbm_back_bo_from_fd(drmmode, TRUE, fd_handle, pitch, size);
    if (!ppriv.backing_bo)
        return FALSE;

    close(fd_handle);
    return TRUE;
}

private Bool drmmode_SharedPixmapPresent(PixmapPtr ppix, xf86CrtcPtr crtc, drmmode_ptr drmmode)
{
    ScreenPtr primary = cast(ScreenPtr)crtc.randr_crtc.pScreen.current_primary;

    if (primary.PresentSharedPixmap(ppix)) {
        /* Success, queue flip to back target */
        if (drmmode_SharedPixmapFlip(ppix, crtc, drmmode))
            return TRUE;

        xf86DrvMsg(drmmode.scrn.scrnIndex, X_WARNING,
                   "drmmode_SharedPixmapFlip() failed, trying again next vblank\n");

        return drmmode_SharedPixmapPresentOnVBlank(ppix, crtc, drmmode);
    }

    /* Failed to present, try again on next vblank after damage */
    if (primary.RequestSharedPixmapNotifyDamage) {
        msPixmapPrivPtr ppriv = mixin(msGetPixmapPriv!("drmmode", "ppix"));

        /* Set flag first in case we are immediately notified */
        ppriv.wait_for_damage = TRUE;

        if (primary.RequestSharedPixmapNotifyDamage(ppix))
            return TRUE;
        else
            ppriv.wait_for_damage = FALSE;
    }

    /* Damage notification not available, just try again on vblank */
    return drmmode_SharedPixmapPresentOnVBlank(ppix, crtc, drmmode);
}

struct vblank_event_args {
    PixmapPtr frontTarget;
    PixmapPtr backTarget;
    xf86CrtcPtr crtc;
    drmmode_ptr drmmode;
    Bool flip;
}
private void drmmode_SharedPixmapVBlankEventHandler(ulong frame, ulong usec, void* data)
{
    vblank_event_args* args = cast(vblank_event_args*)data;

    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) args.crtc.driver_private;

    if (args.flip) {
        /* frontTarget is being displayed, update crtc to reflect */
        drmmode_crtc.prime_pixmap = args.frontTarget;
        drmmode_crtc.prime_pixmap_back = args.backTarget;

        /* Safe to present on backTarget, no longer displayed */
        drmmode_SharedPixmapPresent(args.backTarget, args.crtc, args.drmmode);
    } else {
        /* backTarget is still being displayed, present on frontTarget */
        drmmode_SharedPixmapPresent(args.frontTarget, args.crtc, args.drmmode);
    }

    free(args);
}

private void drmmode_SharedPixmapVBlankEventAbort(void* data)
{
    vblank_event_args* args = cast(vblank_event_args*)data;

    mixin(msGetPixmapPriv!("args.drmmode", "args.frontTarget")).flip_seq = 0;

    free(args);
}

Bool drmmode_SharedPixmapPresentOnVBlank(PixmapPtr ppix, xf86CrtcPtr crtc, drmmode_ptr drmmode)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    msPixmapPrivPtr ppriv = mixin(msGetPixmapPriv!("drmmode", "ppix"));
    vblank_event_args* event_args = void;

    if (ppix == drmmode_crtc.prime_pixmap)
        return FALSE; /* Already flipped to this pixmap */
    if (ppix != drmmode_crtc.prime_pixmap_back)
        return FALSE; /* Pixmap is not a scanout pixmap for CRTC */

    event_args = cast(vblank_event_args*) calloc(1, typeof(*event_args).sizeof);
    if (!event_args)
        return FALSE;

    event_args.frontTarget = ppix;
    event_args.backTarget = drmmode_crtc.prime_pixmap;
    event_args.crtc = crtc;
    event_args.drmmode = drmmode;
    event_args.flip = FALSE;

    ppriv.flip_seq =
        ms_drm_queue_alloc(crtc, event_args,
                           &drmmode_SharedPixmapVBlankEventHandler,
                           &drmmode_SharedPixmapVBlankEventAbort);

    return ms_queue_vblank(crtc, MS_QUEUE_RELATIVE, 1, null, ppriv.flip_seq);
}

Bool drmmode_SharedPixmapFlip(PixmapPtr frontTarget, xf86CrtcPtr crtc, drmmode_ptr drmmode)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    msPixmapPrivPtr ppriv_front = mixin(msGetPixmapPriv!("drmmode", "frontTarget"));

    vblank_event_args* event_args = void;

    event_args = cast(vblank_event_args*) calloc(1, typeof(*event_args).sizeof);
    if (!event_args)
        return FALSE;

    event_args.frontTarget = frontTarget;
    event_args.backTarget = drmmode_crtc.prime_pixmap;
    event_args.crtc = crtc;
    event_args.drmmode = drmmode;
    event_args.flip = TRUE;

    ppriv_front.flip_seq =
        ms_drm_queue_alloc(crtc, event_args,
                           &drmmode_SharedPixmapVBlankEventHandler,
                           &drmmode_SharedPixmapVBlankEventAbort);

    if (drmModePageFlip(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                        ppriv_front.fb_id, DRM_MODE_PAGE_FLIP_EVENT,
                        cast(void*)cast(intptr_t) ppriv_front.flip_seq) < 0) {
        ms_drm_abort_seq(crtc.scrn, ppriv_front.flip_seq);
        return FALSE;
    }

    return TRUE;
}

private Bool drmmode_InitSharedPixmapFlipping(xf86CrtcPtr crtc, drmmode_ptr drmmode)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    if (!drmmode_crtc.enable_flipping)
        return FALSE;

    if (drmmode_crtc.flipping_active)
        return TRUE;

    drmmode_crtc.flipping_active =
        drmmode_SharedPixmapPresent(drmmode_crtc.prime_pixmap_back,
                                    crtc, drmmode);

    return drmmode_crtc.flipping_active;
}

private void drmmode_FiniSharedPixmapFlipping(xf86CrtcPtr crtc, drmmode_ptr drmmode)
{
    uint seq = void;
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    if (!drmmode_crtc.flipping_active)
        return;

    drmmode_crtc.flipping_active = FALSE;

    /* Abort page flip event handler on prime_pixmap */
    seq = mixin(msGetPixmapPriv!("drmmode", "drmmode_crtc.prime_pixmap")).flip_seq;
    if (seq)
        ms_drm_abort_seq(crtc.scrn, seq);

    /* Abort page flip event handler on prime_pixmap_back */
    seq = mixin(msGetPixmapPriv!("drmmode",
                          "drmmode_crtc.prime_pixmap_back")).flip_seq;
    if (seq)
        ms_drm_abort_seq(crtc.scrn, seq);
}



Bool drmmode_EnableSharedPixmapFlipping(xf86CrtcPtr crtc, drmmode_ptr drmmode, PixmapPtr front, PixmapPtr back)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    drmmode_crtc.enable_flipping = TRUE;

    /* Set front scanout pixmap */
    drmmode_crtc.enable_flipping &=
        drmmode_set_target_scanout_pixmap(crtc, front,
                                          &drmmode_crtc.prime_pixmap);
    if (!drmmode_crtc.enable_flipping)
        return FALSE;

    /* Set back scanout pixmap */
    drmmode_crtc.enable_flipping &=
        drmmode_set_target_scanout_pixmap(crtc, back,
                                          &drmmode_crtc.prime_pixmap_back);
    if (!drmmode_crtc.enable_flipping) {
        drmmode_set_target_scanout_pixmap(crtc, null,
                                          &drmmode_crtc.prime_pixmap);
        return FALSE;
    }

    return TRUE;
}

void drmmode_DisableSharedPixmapFlipping(xf86CrtcPtr crtc, drmmode_ptr drmmode)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    drmmode_crtc.enable_flipping = FALSE;

    drmmode_FiniSharedPixmapFlipping(crtc, drmmode);

    drmmode_set_target_scanout_pixmap(crtc, null, &drmmode_crtc.prime_pixmap);

    drmmode_set_target_scanout_pixmap(crtc, null,
                                      &drmmode_crtc.prime_pixmap_back);
}

private void drmmode_ConvertFromKMode(ScrnInfoPtr scrn, drmModeModeInfo* kmode, DisplayModePtr mode)
{
    memset(mode, 0, DisplayModeRec.sizeof);
    mode.status = MODE_OK;

    mode.Clock = kmode.clock;

    mode.HDisplay = kmode.hdisplay;
    mode.HSyncStart = kmode.hsync_start;
    mode.HSyncEnd = kmode.hsync_end;
    mode.HTotal = kmode.htotal;
    mode.HSkew = kmode.hskew;

    mode.VDisplay = kmode.vdisplay;
    mode.VSyncStart = kmode.vsync_start;
    mode.VSyncEnd = kmode.vsync_end;
    mode.VTotal = kmode.vtotal;
    mode.VScan = kmode.vscan;

    mode.Flags = kmode.flags; //& FLAG_BITS;
    mode.name = strdup(kmode.name.ptr);

    if (kmode.type & DRM_MODE_TYPE_DRIVER)
        mode.type = M_T_DRIVER;
    if (kmode.type & DRM_MODE_TYPE_PREFERRED)
        mode.type |= M_T_PREFERRED;
    xf86SetModeCrtc(mode, scrn.adjustFlags);
}

private void drmmode_ConvertToKMode(ScrnInfoPtr scrn, drmModeModeInfo* kmode, DisplayModePtr mode)
{
    memset(kmode, 0, typeof(*kmode).sizeof);

    kmode.clock = mode.Clock;
    kmode.hdisplay = cast(ushort)mode.HDisplay;
    kmode.hsync_start = cast(ushort)mode.HSyncStart;
    kmode.hsync_end = cast(ushort)mode.HSyncEnd;
    kmode.htotal = cast(ushort)mode.HTotal;
    kmode.hskew = cast(ushort)mode.HSkew;

    kmode.vdisplay = cast(ushort)mode.VDisplay;
    kmode.vsync_start = cast(ushort)mode.VSyncStart;
    kmode.vsync_end = cast(ushort)mode.VSyncEnd;
    kmode.vtotal = cast(ushort)mode.VTotal;
    kmode.vscan = cast(ushort)mode.VScan;

    kmode.flags = mode.Flags; //& FLAG_BITS;
    if (mode.name)
        strncpy(kmode.name.ptr, mode.name, DRM_DISPLAY_MODE_LEN);
    kmode.name[DRM_DISPLAY_MODE_LEN - 1] = 0;

}

private void drmmode_crtc_dpms(xf86CrtcPtr crtc, int mode)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    /* XXX Check if DPMS mode is already the right one */

    drmmode_crtc.dpms_mode = mode;

    if (ms.atomic_modeset) {
        if (mode != DPMSModeOn && !ms.pending_modeset)
            drmmode_crtc_disable(crtc);
    } else if (crtc.enabled == FALSE) {
        drmModeSetCrtc(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                       0, 0, 0, null, 0, null);
    }
}

static if (GLAMOR) {
private PixmapPtr create_pixmap_for_fbcon(drmmode_ptr drmmode, ScrnInfoPtr pScrn, int fbcon_id)
{
    PixmapPtr pixmap = drmmode.fbcon_pixmap;
    drmModeFBPtr fbcon = void;
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    modesettingPtr ms = mixin(modesettingPTR!("pScrn"));
    Bool ret = void;

    if (pixmap)
        return pixmap;

    fbcon = drmModeGetFB(drmmode.fd, fbcon_id);
    if (fbcon is null)
        return null;

    if (fbcon.depth != pScrn.depth ||
        fbcon.width != pScrn.virtualX ||
        fbcon.height != pScrn.virtualY)
        goto out_free_fb;

    pixmap = drmmode_create_pixmap_header(pScreen, fbcon.width,
                                          fbcon.height, fbcon.depth,
                                          fbcon.bpp, fbcon.pitch, null);
    if (!pixmap)
        goto out_free_fb;

    ret = ms.glamor.egl_create_textured_pixmap(pixmap, fbcon.handle,
                                                fbcon.pitch);
    if (!ret) {
      FreePixmap(pixmap);
      pixmap = null;
    }

    drmmode.fbcon_pixmap = pixmap;
out_free_fb:
    drmModeFreeFB(fbcon);
    return pixmap;
}
}

void drmmode_copy_fb(ScrnInfoPtr pScrn, drmmode_ptr drmmode)
{
static if (GLAMOR) {
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    PixmapPtr src = void, dst = void;
    int fbcon_id = 0;
    GCPtr gc = void;
    int i = void;

    for (i = 0; i < xf86_config.num_crtc; i++) {
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) xf86_config.crtc[i].driver_private;
        if (drmmode_crtc.mode_crtc.buffer_id)
            fbcon_id = drmmode_crtc.mode_crtc.buffer_id;
    }

    if (!fbcon_id)
        return;

    if (fbcon_id == drmmode.fb_id) {
        /* in some rare case there might be no fbcon and we might already
         * be the one with the current fb to avoid a false deadlck in
         * kernel ttm code just do nothing as anyway there is nothing
         * to do
         */
        return;
    }

    src = create_pixmap_for_fbcon(drmmode, pScrn, fbcon_id);
    if (!src)
        return;

    dst = pScreen.GetScreenPixmap(pScreen);

    gc = GetScratchGC(pScrn.depth, pScreen);
    ValidateGC(&dst.drawable, gc);

    cast(void) (*gc.ops.CopyArea)(&src.drawable, &dst.drawable, gc, 0, 0,
                         pScrn.virtualX, pScrn.virtualY, 0, 0);

    FreeScratchGC(gc);

    pScreen.canDoBGNoneRoot = TRUE;

    dixDestroyPixmap(drmmode.fbcon_pixmap, 0);
    drmmode.fbcon_pixmap = null;
}
}

void drmmode_copy_damage(xf86CrtcPtr crtc, PixmapPtr dst, RegionPtr dmg, Bool empty)
{
    ScreenPtr pScreen = xf86ScrnToScreen(crtc.scrn);
    DrawableRec* src = void;

    /* Copy the screen's pixmap into the destination pixmap */
    if (crtc.rotatedPixmap) {
        src = &crtc.rotatedPixmap.drawable;
        xf86RotateCrtcRedisplay(crtc, dst, src, dmg, FALSE);
    } else {
        src = &pScreen.GetScreenPixmap(pScreen).drawable;
        PixmapDirtyCopyArea(dst, src, 0, 0, -crtc.x, -crtc.y, dmg);
    }

    /* Reset the damages if requested */
    if (empty)
        RegionEmpty(dmg);

static if (GLAMOR) {
    /* Wait until the GC operations finish */
    mixin(modesettingPTR!("crtc.scrn")).glamor.finish(pScreen);
}
}


private void drmmode_destroy_tearfree_shadow(xf86CrtcPtr crtc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_tearfree_ptr trf = &drmmode_crtc.tearfree;
    int i = void;

    if (trf.flip_seq)
        ms_drm_abort_seq(crtc.scrn, trf.flip_seq);

    for (i = 0; i < mixin(ARRAY_SIZE!("trf.buf")); i++) {
        if (trf.buf[i].px) {
            drmmode_shadow_fb_destroy(crtc, trf.buf[i].px, cast(void*)cast(c_long)1,
                                      trf.buf[i].bo, &trf.buf[i].fb_id);
            trf.buf[i].bo = null;
            trf.buf[i].px = null;
            RegionUninit(&trf.buf[i].dmg);
        }
    }
}


private Bool drmmode_create_tearfree_shadow(xf86CrtcPtr crtc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmmode_tearfree_ptr trf = &drmmode_crtc.tearfree;
    uint w = crtc.mode.HDisplay, h = crtc.mode.VDisplay;
    int i = void;

    if (!drmmode.tearfree_enable)
        return TRUE;

    /* Destroy the old mode's buffers and make new ones */
    drmmode_destroy_tearfree_shadow(crtc);
    for (i = 0; i < mixin(ARRAY_SIZE!("trf.buf")); i++) {
        trf.buf[i].px = drmmode_shadow_fb_create(crtc, null, w, h,
                                                  &trf.buf[i].bo,
                                                  &trf.buf[i].fb_id);
        if (!trf.buf[i].px) {
            drmmode_destroy_tearfree_shadow(crtc);
            xf86DrvMsg(crtc.scrn.scrnIndex, X_ERROR,
                       "shadow creation failed for TearFree buf%d\n", i);
            return FALSE;
        }
        RegionInit(&trf.buf[i].dmg, &crtc.bounds, 0);
    }

    /* Initialize the front buffer with the current scanout */
    drmmode_copy_damage(crtc, trf.buf[trf.back_idx ^ 1].px,
                        &trf.buf[trf.back_idx ^ 1].dmg, TRUE);
    return TRUE;
}

private void drmmmode_prepare_modeset(ScrnInfoPtr scrn)
{
    ScreenPtr pScreen = scrn.pScreen;
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    if (!ms.drmmode.present_flipping || ms.drmmode.pending_modeset)
        return;

    /*
     * Force present to unflip everything before we might
     * try lighting up new displays. This makes sure fancy
     * modifiers can't cause the modeset to fail.
     */
    ms.drmmode.pending_modeset = TRUE;
    present_check_flips(pScreen.root);
    ms.drmmode.pending_modeset = FALSE;

    ms_drain_drm_events(pScreen);
}

private Bool drmmode_set_mode_major(xf86CrtcPtr crtc, DisplayModePtr mode, Rotation rotation, int x, int y)
{
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    int saved_x = void, saved_y = void;
    Rotation saved_rotation = void;
    DisplayModeRec saved_mode = void;
    Bool ret = TRUE;
    Bool can_test = void;
    int i = void;

    if (mode)
        drmmmode_prepare_modeset(crtc.scrn);

    saved_mode = crtc.mode;
    saved_x = crtc.x;
    saved_y = crtc.y;
    saved_rotation = crtc.rotation;

    if (mode) {
        crtc.mode = *mode;
        crtc.x = x;
        crtc.y = y;
        crtc.rotation = rotation;

        if (!xf86CrtcRotate(crtc)) {
            goto done;
        }

        crtc.funcs.gamma_set(crtc, crtc.gamma_red, crtc.gamma_green,
                               crtc.gamma_blue, crtc.gamma_size);

        ret = drmmode_create_tearfree_shadow(crtc);
        if (!ret)
            goto done;

        can_test = drmmode_crtc_can_test_mode(crtc);
        if (drmmode_crtc_set_mode(crtc, can_test)) {
            xf86DrvMsg(crtc.scrn.scrnIndex, X_ERROR,
                       "failed to set mode: %s\n", strerror(errno));
            ret = FALSE;
            goto done;
        } else
            ret = TRUE;

        if (crtc.scrn.pScreen)
            xf86CrtcSetScreenSubpixelOrder(crtc.scrn.pScreen);

        ms.pending_modeset = TRUE;
        drmmode_crtc.need_modeset = FALSE;
        crtc.funcs.dpms(crtc, DPMSModeOn);

        if (drmmode_crtc.prime_pixmap_back)
            drmmode_InitSharedPixmapFlipping(crtc, drmmode);

        /* go through all the outputs and force DPMS them back on? */
        for (i = 0; i < xf86_config.num_output; i++) {
            xf86OutputPtr output = xf86_config.output[i];
            drmmode_output_private_ptr drmmode_output = void;

            if (output.crtc != crtc)
                continue;

            drmmode_output = cast(drmmode_output_private_rec*)output.driver_private;
            if (drmmode_output.output_id == -1)
                continue;
            output.funcs.dpms(output, DPMSModeOn);
        }

        /* if we only tested the mode previously, really set it now */
        if (can_test)
            drmmode_crtc_set_mode(crtc, FALSE);
        ms.pending_modeset = FALSE;
    }

 done:
    if (!ret) {
        crtc.x = saved_x;
        crtc.y = saved_y;
        crtc.rotation = saved_rotation;
        crtc.mode = saved_mode;
        drmmode_create_tearfree_shadow(crtc);
    } else
        crtc.active = TRUE;

    return ret;
}

private void drmmode_set_cursor_colors(xf86CrtcPtr crtc, int bg, int fg)
{

}

private void drmmode_set_cursor_position(xf86CrtcPtr crtc, int x, int y)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    /* Core handles rotation; we only compensate when the glyph box is offset from its click hotspot. */
    x += drmmode_crtc.cursor_src_x;
    y += drmmode_crtc.cursor_src_y;

    drmModeMoveCursor(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id, x, y);
}

private Bool drmmode_set_cursor(xf86CrtcPtr crtc, int width, int height)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    uint handle = gbm_bo_get_handle(drmmode_crtc.cursor.bo).u32;
    CursorPtr cursor = xf86CurrentCursor(crtc.scrn.pScreen);
    int ret = -EINVAL;

    if (cursor == NullCursor)
        return TRUE;

    ret = drmModeSetCursor2(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                            handle, width, height,
                            cursor.bits.xhot, cursor.bits.yhot);

    /* -EINVAL can mean that an old kernel supports drmModeSetCursor but
     * not drmModeSetCursor2, though it can mean other things too. */
    if (ret == -EINVAL)
        ret = drmModeSetCursor(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                               handle, width, height);

    /* -ENXIO normally means that the current drm driver supports neither
     * cursor_set nor cursor_set2.  Disable hardware cursor support for
     * the rest of the session in that case. */
    if (ret == -ENXIO) {
        xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("crtc.scrn"));
        xf86CursorInfoPtr cursor_info = xf86_config.cursor_info;

        cursor_info.MaxWidth = cursor_info.MaxHeight = 0;
        drmmode_crtc.drmmode.sw_cursor = TRUE;
        drmmode_crtc.drmmode.set_cursor_failed = TRUE;
    }

    if (ret) {
        /* fallback to swcursor */
        return FALSE;
    }

    return TRUE;
}

pragma(inline, true) private Bool drmmode_cursor_get_pitch_slow(drmmode_crtc_private_ptr drmmode_crtc, int idx, int* pitch)
{
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmmode_cursor_ptr drmmode_cursor = &drmmode_crtc.cursor;

    int width = drmmode_cursor.dimensions[idx].width;
    int height = drmmode_cursor.dimensions[idx].height;

    gbm_bo* bo = gbm_create_best_bo(drmmode, FALSE, width, height, DRMMODE_CURSOR_BO);
    if (!bo) {
        /* We couldn't allocate a bo, so we try to guess the pitch */
        *pitch = mixin(MAX!(`width`, `64`));
        return FALSE;
    }

    *pitch = gbm_bo_get_stride(bo) / drmmode.cpp;

    gbm_bo_destroy(bo);
    return TRUE;
}

private int drmmode_cursor_get_pitch(drmmode_crtc_private_ptr drmmode_crtc, int idx)
{
    int ret = 0;

    if (!drmmode_crtc.cursor_pitches) {
        int num_pitches = drmmode_crtc.cursor.num_dimensions;
        drmmode_crtc.cursor_pitches = cast(int*)calloc(num_pitches, int.sizeof);
        if (!drmmode_crtc.cursor_pitches) {
            /* we couldn't allocate memory for the cache, so we don't cache the result */
            drmmode_cursor_get_pitch_slow(drmmode_crtc, idx, &ret);
            return ret;
        }
    }

    if (drmmode_crtc.cursor_pitches[idx]) {
        /* return the cached pitch */
        return drmmode_crtc.cursor_pitches[idx];
    }

    if (drmmode_cursor_get_pitch_slow(drmmode_crtc, idx, &ret)) {
        drmmode_crtc.cursor_pitches[idx] = ret;
    }

    return ret;
}

/*
 * The core stores a single rotated/reflected cursor glyph inside a fixed-size
 * cursor image buffer. The glyph is written into one corner depending on the
 * screen rotation and reflections. We compute the bounding box of that placed
 * glyph to crop just the relevant region.
 *
 * This is the placement of the cursor glyph for each screen rotation:
 *
 *   +-----------+-----------+
 *   | Rotate 0  | Rotate 270|
 *   |(top-left) |(top-right)|
 *   +-----------+-----------+
 *   | Rotate 90 | Rotate 180|
 *   |(bot-left) |(bot-right)|
 *   +-----------+-----------+
 *
 * Reflections flip the corresponding coordinate before rotation:
 * RR_Reflect_X mirrors across the Y axis (flips X), RR_Reflect_Y mirrors across
 * the X axis (flips Y). This changes which corner the glyph occupies.
 */
private void drmmode_transform_box_back(Rotation rotation, int image_width, int image_height, int box_width, int box_height, int* x_dst, int* y_dst, int* dst_width, int* dst_height)
{
    int dst_min_x = void, dst_min_y = void, dst_max_x = void, dst_max_y = void;
    /* We want to get the (0,0) coordinates of the cursor glyph box. */
    int src_min_x = 0;
    int src_max_x = box_width - 1;
    int src_min_y = 0;
    int src_max_y = box_height - 1;

    /* Reflect first, then rotate to match the logic in xf86_crtc_rotate_coord_back(). */
    if (rotation & RR_Reflect_X) {
        /* (x, y) -> (W - 1 - x, y) */
        int rx_min = image_width - 1 - src_max_x;
        int rx_max = image_width - 1 - src_min_x;
        src_min_x = rx_min;
        src_max_x = rx_max;
    }
    if (rotation & RR_Reflect_Y) {
        /* (x, y) -> (x, H - 1 - y) */
        int ry_min = image_height - 1 - src_max_y;
        int ry_max = image_height - 1 - src_min_y;
        src_min_y = ry_min;
        src_max_y = ry_max;
    }

    switch (rotation & 0xf) {
    case RR_Rotate_90:
        /* (x, y) -> (y, W - 1 - x) */
        dst_min_x = src_min_y;
        dst_max_x = src_max_y;
        dst_min_y = image_width - 1 - src_max_x;
        dst_max_y = image_width - 1 - src_min_x;
        break;
    case RR_Rotate_180:
        /* (x, y) -> (W - 1 - x, H - 1 - y) */
        dst_min_x = image_width - 1 - src_max_x;
        dst_max_x = image_width - 1 - src_min_x;
        dst_min_y = image_height - 1 - src_max_y;
        dst_max_y = image_height - 1 - src_min_y;
        break;
    case RR_Rotate_270:
        /* (x, y) -> (H - 1 - y, x) */
        dst_min_x = image_height - 1 - src_max_y;
        dst_max_x = image_height - 1 - src_min_y;
        dst_min_y = src_min_x;
        dst_max_y = src_max_x;
        break;
    default:
        /* RR_Rotate_0 or unknown rotation: identity */
        /* (x, y) -> (x, y) */
        dst_min_x = src_min_x;
        dst_max_x = src_max_x;
        dst_min_y = src_min_y;
        dst_max_y = src_max_y;
        break;
    }

    /* Clamp to the source image bounds. */
    dst_min_x = mixin(MAX!(`dst_min_x`, `0`));
    dst_min_y = mixin(MAX!(`dst_min_y`, `0`));
    dst_max_x = mixin(MIN!(`dst_max_x`, `image_width - 1`));
    dst_max_y = mixin(MIN!(`dst_max_y`, `image_height - 1`));

    *x_dst = dst_min_x;
    *y_dst = dst_min_y;
    *dst_width = dst_max_x - dst_min_x + 1;
    *dst_height = dst_max_y - dst_min_y + 1;
}

private void drmmode_paint_cursor(gbm_bo* cursor_bo, int cursor_pitch, int cursor_width, int cursor_height, const(CARD32)* image, int image_width, int image_height, /*restrict*/ drmmode_crtc_private_ptr drmmode_crtc, int glyph_width, int glyph_height, int rotation, int src_x, int src_y)
{
    int width_todo = void;
    int height_todo = void;

    CARD32* cursor = cast(uint*)gbm_bo_get_map(cursor_bo);

    /* Clamp to the source image bounds to avoid pointer UB and OOB reads. */
    src_x = mixin(MAX!(MIN!(`src_x`, `(image_width - 1)`), `0`));
    src_y = mixin(MAX!(MIN!(`src_y`, `(image_height - 1)`), `0`));

    /*
     * The image buffer can be smaller than the cursor buffer.
     * This means that we can't clear the cursor by copying '\0' bytes
     * from the image buffer, because we might read out of bounds.
     */
    if (
        /* If the buffer is uninitialized, assume it is dirty */
        (drmmode_crtc.cursor_glyph_width == 0 &&
         drmmode_crtc.cursor_glyph_height == 0) ||

        /* If cached glyph dimensions exceed the current crop window, force a full clear */
        (drmmode_crtc.cursor_glyph_width > image_width - src_x ||
         drmmode_crtc.cursor_glyph_height > image_height - src_y) ||

        /* If the pitch changed, the memory layout of the cursor data changed, so the buffer is dirty */
        /* See: https://github.com/X11Libre/xserver/pull/1234 */
        (drmmode_crtc.old_pitch != cursor_pitch) ||

        /* If rotation changed, the glyph moves to a different region */
        (drmmode_crtc.cursor_rotation != rotation)
       ) {
        int pitch = gbm_bo_get_stride(cursor_bo);
        int height = gbm_bo_get_height(cursor_bo);
        memset(cursor, 0, pitch * height);

        /* Since we already cleared the buffer, no need to clear it again below */
        drmmode_crtc.cursor_glyph_width = 0;
        drmmode_crtc.cursor_glyph_height = 0;
    }

    drmmode_crtc.old_pitch = cursor_pitch;
    drmmode_crtc.cursor_rotation = rotation;

    /* Paint only what we need to */
    width_todo = mixin(MAX!(`drmmode_crtc.cursor_glyph_width`, `glyph_width`));
    height_todo = mixin(MAX!(`drmmode_crtc.cursor_glyph_height`, `glyph_height`));

    /* Basic buffer bounds checking */
    width_todo = mixin(MAX!(MIN!(`width_todo`, `(image_width - src_x)`), `0`));
    height_todo = mixin(MAX!(MIN!(`height_todo`, `(image_height - src_y)`), `0`));

    /* remember the size of the current cursor glyph */
    drmmode_crtc.cursor_glyph_width = glyph_width;
    drmmode_crtc.cursor_glyph_height = glyph_height;

    const(CARD32)* src = image + src_y * image_width + src_x;
    for (int i = 0; i < height_todo; i++) {
        memcpy(cursor + i * cursor_pitch, src + i * image_width, width_todo * typeof(*cursor).sizeof);    /* cpu_to_le32(image[i]); */
    }
}




/*
 * The load_cursor_argb_check driver hook.
 *
 * Sets the hardware cursor by calling the drmModeSetCursor2 ioctl.
 * On failure, returns FALSE indicating that the X server should fall
 * back to software cursors.
 */
private Bool drmmode_load_cursor_argb_check(xf86CrtcPtr crtc, CARD32* image)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));
    CursorPtr cursor = xf86CurrentCursor(crtc.scrn.pScreen);
    const(Rotation) rotation = crtc.rotation;
    int glyph_width = cursor.bits.width;
    int glyph_height = cursor.bits.height;
    int crop_width = glyph_width;
    int crop_height = glyph_height;

    if (drmmode_crtc.cursor_up) {
        /* we probe the cursor so late, because we want to make sure that
           the screen is fully initialized and something is already drawn on it.
           Otherwise, we can't get reliable results with the probe. */
        drmmode_probe_cursor_size(crtc);
    }

    drmmode_cursor_rec drmmode_cursor = drmmode_crtc.cursor;

    /* Find the most compatiable size. */
    int idx = void;
    for (idx = 0; idx < drmmode_cursor.num_dimensions; idx++)
    {
        drmmode_cursor_dim_rec dimensions = drmmode_cursor.dimensions[idx];

        if (dimensions.width >= glyph_width &&
            dimensions.height >= glyph_height) {
                break;
        }
    }

    if (idx >= drmmode_cursor.num_dimensions) {
        /* No compatible hardware cursor size; fall back to software cursor. */
        if (!drmmode_crtc.cursor_dim_fallback_warned) {
            xf86DrvMsg(crtc.scrn.scrnIndex, X_WARNING,
                       "No compatible hardware cursor size for %dx%d; "
                       ~ "falling back to software cursor\n",
                       glyph_width, glyph_height);
            drmmode_crtc.cursor_dim_fallback_warned = TRUE;
        }
        return FALSE;
    }

    const(int) cursor_pitch = drmmode_cursor_get_pitch(drmmode_crtc, idx);

    /* Get the resolution of the cursor. */
    int cursor_width = drmmode_cursor.dimensions[idx].width;
    int cursor_height = drmmode_cursor.dimensions[idx].height;

    /* Get the size of the cursor image buffer */
    int image_width = ms.cursor_image_width;
    int image_height = ms.cursor_image_height;
    int src_x = 0;
    int src_y = 0;

    /* Map the source glyph box (0,0) into the displayed cursor image; src_x/src_y become BO (0,0). */
    drmmode_transform_box_back(rotation, image_width, image_height,
                               glyph_width, glyph_height,
                               &src_x, &src_y, &crop_width, &crop_height);

    drmmode_crtc.cursor_src_x = src_x;
    drmmode_crtc.cursor_src_y = src_y;

    /* cursor should be mapped already */
    drmmode_paint_cursor(drmmode_cursor.bo, cursor_pitch, cursor_width, cursor_height,
                         image, image_width, image_height,
                         drmmode_crtc, crop_width, crop_height,
                         rotation, src_x, src_y);

    /* set cursor width and height here for drmmode_show_cursor */
    drmmode_crtc.cursor_width  = cursor_width;
    drmmode_crtc.cursor_height = cursor_height;

    return drmmode_crtc.cursor_up ? drmmode_set_cursor(crtc, cursor_width, cursor_height) : TRUE;
}

private void drmmode_hide_cursor(xf86CrtcPtr crtc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    drmmode_crtc.cursor_up = FALSE;
    drmModeSetCursor(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id, 0,
                     drmmode_crtc.cursor_width, drmmode_crtc.cursor_height);
}

private Bool drmmode_show_cursor(xf86CrtcPtr crtc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_crtc.cursor_up = TRUE;
    return drmmode_set_cursor(crtc, drmmode_crtc.cursor_width, drmmode_crtc.cursor_height);
}

private void drmmode_set_gamma_lut(drmmode_crtc_private_ptr drmmode_crtc, ushort* red, ushort* green, ushort* blue, int size)
{
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmmode_prop_info_ptr gamma_lut_info = &drmmode_crtc.props[DRMMODE_CRTC_GAMMA_LUT];
    const(uint) crtc_id = drmmode_crtc.mode_crtc.crtc_id;
    drm_color_lut* lut = cast(drm_color_lut*) calloc(size, drm_color_lut.sizeof);
    if (!lut)
        return;

    assert(gamma_lut_info.prop_id != 0);

    for (int i = 0; i < size; i++) {
        lut[i].red = red[i];
        lut[i].green = green[i];
        lut[i].blue = blue[i];
        lut[i].reserved = 0;
    }

    uint blob_id = void;
    if (drmModeCreatePropertyBlob(drmmode.fd, lut, size * drm_color_lut.sizeof, &blob_id)) {
        free(lut);
        return;
    }

    drmModeObjectSetProperty(drmmode.fd, crtc_id, DRM_MODE_OBJECT_CRTC,
                             gamma_lut_info.prop_id, blob_id);

    drmModeDestroyPropertyBlob(drmmode.fd, blob_id);
    free(lut);
}

private void drmmode_crtc_gamma_set(xf86CrtcPtr crtc, ushort* red, ushort* green, ushort* blue, int size)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    if (drmmode_crtc.use_gamma_lut) {
        drmmode_set_gamma_lut(drmmode_crtc, red, green, blue, size);
    } else {
        drmModeCrtcSetGamma(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                            size, red, green, blue);
    }
}

private Bool drmmode_set_target_scanout_pixmap_gpu(xf86CrtcPtr crtc, PixmapPtr ppix, PixmapPtr* target)
{
    ScreenPtr screen = xf86ScrnToScreen(crtc.scrn);
    PixmapPtr screenpix = screen.GetScreenPixmap(screen);
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("crtc.scrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    int c = void, total_width = 0, max_height = 0, this_x = 0;

    if (*target) {
        PixmapStopDirtyTracking(&(*target).drawable, screenpix);
        if (drmmode.fb_id) {
            drmModeRmFB(drmmode.fd, drmmode.fb_id);
            drmmode.fb_id = 0;
        }
        drmmode_crtc.prime_pixmap_x = 0;
        *target = null;
    }

    if (!ppix)
        return TRUE;

    /* iterate over all the attached crtcs to work out the bounding box */
    for (c = 0; c < xf86_config.num_crtc; c++) {
        xf86CrtcPtr iter = xf86_config.crtc[c];
        if (!iter.enabled && iter != crtc)
            continue;
        if (iter == crtc) {
            this_x = total_width;
            total_width += ppix.drawable.width;
            if (max_height < ppix.drawable.height)
                max_height = ppix.drawable.height;
        } else {
            total_width += iter.mode.HDisplay;
            if (max_height < iter.mode.VDisplay)
                max_height = iter.mode.VDisplay;
        }
    }

    if (total_width != screenpix.drawable.width ||
        max_height != screenpix.drawable.height) {

        if (!drmmode_xf86crtc_resize(crtc.scrn, total_width, max_height))
            return FALSE;

        screenpix = screen.GetScreenPixmap(screen);
        screen.width = screenpix.drawable.width = cast(ushort)total_width;
        screen.height = screenpix.drawable.height = cast(ushort)max_height;
    }
    drmmode_crtc.prime_pixmap_x = this_x;
    PixmapStartDirtyTracking(&ppix.drawable, screenpix, 0, 0, this_x, 0,
                             RR_Rotate_0);
    *target = ppix;
    return TRUE;
}

private Bool drmmode_set_target_scanout_pixmap_cpu(xf86CrtcPtr crtc, PixmapPtr ppix, PixmapPtr* target)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    msPixmapPrivPtr ppriv = void;

    if (*target) {
        ppriv = mixin(msGetPixmapPriv!("drmmode", "*target"));
        drmModeRmFB(drmmode.fd, ppriv.fb_id);
        ppriv.fb_id = 0;
        if (ppriv.secondary_damage) {
            DamageUnregister(ppriv.secondary_damage);
            ppriv.secondary_damage = null;
        }
        *target = null;
    }

    if (!ppix)
        return TRUE;

    ppriv = mixin(msGetPixmapPriv!("drmmode", "ppix"));
    if (!ppriv.secondary_damage) {
        ppriv.secondary_damage = DamageCreate(null, null,
                                           DamageReportNone,
                                           TRUE,
                                           crtc.randr_crtc.pScreen,
                                           null);
    }
    ppix.devPrivate.ptr = gbm_bo_get_map(ppriv.backing_bo);
    DamageRegister(&ppix.drawable, ppriv.secondary_damage);

    if (ppriv.fb_id == 0) {
        drmModeAddFB(drmmode.fd, ppix.drawable.width,
                     ppix.drawable.height,
                     ppix.drawable.depth,
                     ppix.drawable.bitsPerPixel,
                     ppix.devKind, gbm_bo_get_handle(ppriv.backing_bo).s32, &ppriv.fb_id);
    }
    *target = ppix;
    return TRUE;
}

private Bool drmmode_set_target_scanout_pixmap(xf86CrtcPtr crtc, PixmapPtr ppix, PixmapPtr* target)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    if (drmmode.reverse_prime_offload_mode)
        return drmmode_set_target_scanout_pixmap_gpu(crtc, ppix, target);
    else
        return drmmode_set_target_scanout_pixmap_cpu(crtc, ppix, target);
}

private Bool drmmode_set_scanout_pixmap(xf86CrtcPtr crtc, PixmapPtr ppix)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    /* Use DisableSharedPixmapFlipping before switching to single buf */
    if (drmmode_crtc.enable_flipping)
        return FALSE;

    return drmmode_set_target_scanout_pixmap(crtc, ppix,
                                             &drmmode_crtc.prime_pixmap);
}

private void drmmode_clear_pixmap(PixmapPtr pixmap)
{
    ScreenPtr screen = pixmap.drawable.pScreen;
    GCPtr gc = void;
static if (GLAMOR) {
    modesettingPtr ms = mixin(modesettingPTR!("xf86ScreenToScrn(screen)"));

    if (ms.drmmode.glamor_gbm) {
        ms.glamor.clear_pixmap(pixmap);
        return;
    }
}

    gc = GetScratchGC(pixmap.drawable.depth, screen);
    if (gc) {
        miClearDrawable(&pixmap.drawable, gc);
        FreeScratchGC(gc);
    }
}

private gbm_bo* drmmode_shadow_fb_allocate(xf86CrtcPtr crtc, int width, int height, uint* fb_id)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    gbm_bo* ret = gbm_create_best_bo(drmmode, !drmmode.glamor_gbm, width, height, DRMMODE_FRONT_BO);
    if (ret is null) {
        xf86DrvMsg(crtc.scrn.scrnIndex, X_ERROR,
               "Couldn't allocate shadow memory for rotated CRTC\n");
        return null;
    }

    if (drmmode_bo_import(drmmode, ret, fb_id)) {
        ErrorF("failed to add rotate fb\n");
        gbm_bo_destroy(ret);
        return null;
    }

    return ret;
}

private void* drmmode_shadow_allocate(xf86CrtcPtr crtc, int width, int height)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    drmmode_crtc.rotate_bo = drmmode_shadow_fb_allocate(crtc, width, height,
                                                         &drmmode_crtc.rotate_fb_id);

    return drmmode_crtc.rotate_bo;
}

private PixmapPtr drmmode_create_pixmap_header(ScreenPtr pScreen, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData)
{
    PixmapPtr pixmap = void;

    /* width and height of 0 means don't allocate any pixmap data */
    pixmap = (*pScreen.CreatePixmap)(pScreen, 0, 0, depth, 0);

    if (pixmap) {
        if ((*pScreen.ModifyPixmapHeader)(pixmap, width, height, depth,
                                           bitsPerPixel, devKind, pPixData))
            return pixmap;
        dixDestroyPixmap(pixmap, 0);
    }
    return NullPixmap;
}



private PixmapPtr drmmode_shadow_fb_create(xf86CrtcPtr crtc, void* data, int width, int height, gbm_bo** bo, uint* fb_id)
{
    ScrnInfoPtr scrn = crtc.scrn;
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    uint pitch = void;
    PixmapPtr pixmap = void;
    void* pPixData = null;

    if (!data) {
        *bo = drmmode_shadow_fb_allocate(crtc, width, height, fb_id);
        data = *bo;
        if (!data) {
            xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                       "Couldn't allocate shadow pixmap for CRTC\n");
            return null;
        }
    }

    if (*bo is null) {
        xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                   "Couldn't allocate shadow pixmap for CRTC\n");
        return null;
    }

    pPixData = gbm_bo_get_map(*bo);
    pitch = gbm_bo_get_stride(*bo);

    pixmap = drmmode_create_pixmap_header(scrn.pScreen,
                                          width, height,
                                          scrn.depth,
                                          drmmode.kbpp,
                                          pitch,
                                          pPixData);

    if (pixmap is null) {
        xf86DrvMsg(scrn.scrnIndex, X_ERROR,
                   "Couldn't allocate shadow pixmap for CRTC\n");
        return null;
    }

    drmmode_set_pixmap_bo(drmmode, pixmap, *bo);

    return pixmap;
}

private PixmapPtr drmmode_shadow_create(xf86CrtcPtr crtc, void* data, int width, int height)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    return drmmode_shadow_fb_create(crtc, data, width, height,
                                    &drmmode_crtc.rotate_bo,
                                    &drmmode_crtc.rotate_fb_id);
}

private void drmmode_shadow_fb_destroy(xf86CrtcPtr crtc, PixmapPtr pixmap, void* data, gbm_bo* bo, uint* fb_id)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    dixDestroyPixmap(pixmap, 0);

    if (data) {
        drmModeRmFB(drmmode.fd, *fb_id);
        *fb_id = 0;

        gbm_bo_destroy(bo);
    }
}

private void drmmode_shadow_destroy(xf86CrtcPtr crtc, PixmapPtr pixmap, void* data)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

    drmmode_shadow_fb_destroy(crtc, pixmap, data, drmmode_crtc.rotate_bo,
                              &drmmode_crtc.rotate_fb_id);
    drmmode_crtc.rotate_bo = null;
}

private void drmmode_crtc_destroy(xf86CrtcPtr crtc)
{
    drmmode_mode_ptr iterator = void, next = void;
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    modesettingPtr ms = mixin(modesettingPTR!("crtc.scrn"));

    /* Used even without atomic modesetting */
    free(drmmode_crtc.cursor.dimensions);
    free(drmmode_crtc.cursor_pitches);

    if (!ms.atomic_modeset)
        return;

    drmmode_prop_info_free(drmmode_crtc.props_plane.ptr, DRMMODE_PLANE__COUNT);
    mixin(xorg_list_for_each_entry_safe!("iterator", "next", "&drmmode_crtc.mode_list", "entry", q{
        drm_mode_destroy(crtc, iterator);
    }));
}

private const(xf86CrtcFuncsRec) drmmode_crtc_funcs = {
    dpms: &drmmode_crtc_dpms,
    set_mode_major: &drmmode_set_mode_major,
    set_cursor_colors: &drmmode_set_cursor_colors,
    set_cursor_position: &drmmode_set_cursor_position,
    show_cursor_check: &drmmode_show_cursor,
    hide_cursor: &drmmode_hide_cursor,
    load_cursor_argb_check: &drmmode_load_cursor_argb_check,

    gamma_set: &drmmode_crtc_gamma_set,
    destroy: &drmmode_crtc_destroy,
    set_scanout_pixmap: &drmmode_set_scanout_pixmap,
    shadow_allocate: &drmmode_shadow_allocate,
    shadow_create: &drmmode_shadow_create,
    shadow_destroy: &drmmode_shadow_destroy,
};

private uint drmmode_crtc_vblank_pipe(int crtc_id)
{
    if (crtc_id > 1)
        return crtc_id << DRM_VBLANK_HIGH_CRTC_SHIFT;
    else if (crtc_id > 0)
        return DRM_VBLANK_SECONDARY;
    else
        return 0;
}

private Bool is_plane_assigned(ScrnInfoPtr scrn, int plane_id)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int c = void;

    for (c = 0; c < xf86_config.num_crtc; c++) {
        xf86CrtcPtr iter = xf86_config.crtc[c];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) iter.driver_private;
        if (drmmode_crtc.plane_id == plane_id)
            return TRUE;
    }

    return FALSE;
}

/**
 * Populates the formats array, and the modifiers of each format for a drm_plane.
 */
private Bool populate_format_modifiers(xf86CrtcPtr crtc, const(drmModePlane)* kplane, drmmode_format_rec* formats, uint blob_id)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    uint i = void, j = void;
    drmModePropertyBlobRes* blob = void;
    drm_format_modifier_blob* fmt_mod_blob = void;
    uint* blob_formats = void;
    drm_format_modifier* blob_modifiers = void;

    if (!blob_id)
        return FALSE;

    blob = drmModeGetPropertyBlob(drmmode.fd, blob_id);
    if (!blob)
        return FALSE;

    fmt_mod_blob = cast(drm_format_modifier_blob*)blob.data;
    blob_formats = formats_ptr(fmt_mod_blob);
    blob_modifiers = modifiers_ptr(fmt_mod_blob);

    assert(drmmode_crtc.num_formats == fmt_mod_blob.count_formats);

    for (i = 0; i < fmt_mod_blob.count_formats; i++) {
        uint num_modifiers = 0;
        ulong* modifiers = null;
        ulong* tmp = void;
        for (j = 0; j < fmt_mod_blob.count_modifiers; j++) {
            drm_format_modifier* mod = &blob_modifiers[j];

            if ((i < mod.offset) || (i > mod.offset + 63))
                continue;

            if (!(mod.formats & (1 << (i - mod.offset))))
                continue;

            if (mod.modifier == DRM_FORMAT_MOD_INVALID)
                continue;

            num_modifiers++;
            tmp = cast(ulong*) realloc(modifiers, num_modifiers * typeof(modifiers[0]).sizeof);
            if (!tmp) {
                free(modifiers);
                drmModeFreePropertyBlob(blob);
                return FALSE;
            }
            modifiers = tmp;
            modifiers[num_modifiers - 1] = mod.modifier;
        }

        formats[i].format = blob_formats[i];
        formats[i].modifiers = modifiers;
        formats[i].num_modifiers = num_modifiers;
    }

    drmModeFreePropertyBlob(blob);

    return TRUE;
}

version (LIBDRM_HAS_PLANE_SIZE_HINTS) {
private void drmmode_populate_cursor_size_hints(drmmode_ptr drmmode, drmmode_crtc_private_ptr drmmode_crtc, int size_hints_blob)
{
    drmModePropertyBlobRes* blob = void;

    if (!drmmode_crtc)
        return;

    if (drmmode_crtc.cursor_probed)
        return;

    if (!size_hints_blob)
        return;

    blob = drmModeGetPropertyBlob(drmmode.fd, size_hints_blob);

    if (!blob)
        return;

    if (!blob.length)
        goto fail;

    const(drm_plane_size_hint)* size_hints = blob.data;
    size_t size_hints_len = blob.length / typeof(size_hints[0]).sizeof;

    if (!size_hints_len)
        goto fail;

    void* tmp = realloc(drmmode_crtc.cursor.dimensions, size_hints_len * drmmode_cursor_dim_rec.sizeof);
    if (!tmp)
        goto fail;

    drmmode_crtc.cursor.dimensions = tmp;
    drmmode_crtc.cursor.num_dimensions = size_hints_len;

    for (int idx = 0; idx < size_hints_len; idx++)
    {
        drm_plane_size_hint size_hint = size_hints[idx];

        drmmode_crtc.cursor.dimensions[idx].width = size_hint.width;
        drmmode_crtc.cursor.dimensions[idx].height = size_hint.height;
    }

    drmmode_crtc.cursor_probed = TRUE;
fail:
    drmModeFreePropertyBlob(blob);
}
}

private void drmmode_crtc_create_planes(xf86CrtcPtr crtc, int num)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmModePlaneRes* kplane_res = void;
    drmModePlane* kplane = void, best_kplane = null;
    drmModeObjectProperties* props = void;
    uint blob_id = void, async_blob_id = void;
    int best_plane = 0;

    __gshared drmmode_prop_enum_info_rec[4] plane_type_enums = [
        DRMMODE_PLANE_TYPE_PRIMARY: {
            name: "Primary",
        },
        DRMMODE_PLANE_TYPE_OVERLAY: {
            name: "Overlay",
        },
        DRMMODE_PLANE_TYPE_CURSOR: {
            name: "Cursor",
        },
    ];
    __gshared drmmode_prop_info_rec[14] plane_props = [
        DRMMODE_PLANE_TYPE: {
            name: "type",
            enum_values: plane_type_enums.ptr,
            num_enum_values: DRMMODE_PLANE_TYPE__COUNT,
        },
        DRMMODE_PLANE_FB_ID: { name: "FB_ID", },
        DRMMODE_PLANE_CRTC_ID: { name: "CRTC_ID", },
        DRMMODE_PLANE_IN_FORMATS: { name: "IN_FORMATS", },
        DRMMODE_PLANE_IN_FORMATS_ASYNC: { name: "IN_FORMATS_ASYNC", },
        DRMMODE_PLANE_SRC_X: { name: "SRC_X", },
        DRMMODE_PLANE_SRC_Y: { name: "SRC_Y", },
        DRMMODE_PLANE_SRC_W: { name: "SRC_W", },
        DRMMODE_PLANE_SRC_H: { name: "SRC_H", },
        DRMMODE_PLANE_CRTC_X: { name: "CRTC_X", },
        DRMMODE_PLANE_CRTC_Y: { name: "CRTC_Y", },
        DRMMODE_PLANE_CRTC_W: { name: "CRTC_W", },
        DRMMODE_PLANE_CRTC_H: { name: "CRTC_H", },
        DRMMODE_PLANE_SIZE_HINTS: { name: "SIZE_HINTS" }
    ];
    drmmode_prop_info_rec[DRMMODE_PLANE__COUNT] tmp_props = void;

    if (!drmmode_prop_info_copy(tmp_props.ptr, plane_props.ptr, DRMMODE_PLANE__COUNT, 0)) {
        xf86DrvMsg(drmmode.scrn.scrnIndex, X_ERROR,
                   "failed to copy plane property info\n");
        drmmode_prop_info_free(tmp_props.ptr, DRMMODE_PLANE__COUNT);
        return;
    }

    drmSetClientCap(drmmode.fd, DRM_CLIENT_CAP_UNIVERSAL_PLANES, 1);
    kplane_res = drmModeGetPlaneResources(drmmode.fd);
    if (!kplane_res) {
        xf86DrvMsg(drmmode.scrn.scrnIndex, X_ERROR,
                   "failed to get plane resources: %s\n", strerror(errno));
        drmmode_prop_info_free(tmp_props.ptr, DRMMODE_PLANE__COUNT);
        return;
    }

    for (int i = 0; i < kplane_res.count_planes; i++) {
        int plane_id = void;

        kplane = drmModeGetPlane(drmmode.fd, kplane_res.planes[i]);
        if (!kplane)
            continue;

        /* If this plane cannot be used on the current crtc, skip it */
        if (!(kplane.possible_crtcs & (1 << num)) ||
            is_plane_assigned(drmmode.scrn, kplane.plane_id)) {
            drmModeFreePlane(kplane);
            continue;
        }

        plane_id = kplane.plane_id;

        props = drmModeObjectGetProperties(drmmode.fd, plane_id,
                                           DRM_MODE_OBJECT_PLANE);
        if (!props) {
            xf86DrvMsg(drmmode.scrn.scrnIndex, X_ERROR,
                    "couldn't get plane properties\n");
            drmModeFreePlane(kplane);
            continue;
        }

        drmmode_prop_info_update(drmmode, tmp_props.ptr, DRMMODE_PLANE__COUNT, props);

        int plane_crtc = cast(int)drmmode_prop_get_value(&tmp_props[DRMMODE_PLANE_CRTC_ID],
                                                props, 0);

        uint type = cast(uint)drmmode_prop_get_value(&tmp_props[DRMMODE_PLANE_TYPE],
                                               props, DRMMODE_PLANE_TYPE__COUNT);

        switch (type) {
        case DRMMODE_PLANE_TYPE_CURSOR:
        {
            /* For some reason, cursor planes may not have prop_crtc_id set, so we don't check it */
version (LIBDRM_HAS_PLANE_SIZE_HINTS) {
            /* Get the SIZE_HINT dimensions, if supported. */
            int size_hint = drmmode_prop_get_value(&tmp_props[DRMMODE_PLANE_SIZE_HINTS], props, 0);
            drmmode_populate_cursor_size_hints(drmmode, drmmode_crtc, size_hint);
}
            drmModeFreePlane(kplane);
            drmModeFreeObjectProperties(props);
            continue;
        }
        case DRMMODE_PLANE_TYPE_PRIMARY:
        {
            /* Prefer planes that are on this CRTC already */
            if (plane_crtc != drmmode_crtc.mode_crtc.crtc_id) {
                /* If this is the only plane we have, it's the best we have */
                if (!best_plane) {
                    best_plane = plane_id;
                    best_kplane = kplane;
                    blob_id = cast(uint)drmmode_prop_get_value(&tmp_props[DRMMODE_PLANE_IN_FORMATS],
                                                     props, 0);
                    async_blob_id = cast(uint)drmmode_prop_get_value(&(tmp_props[DRMMODE_PLANE_IN_FORMATS_ASYNC]),
                                                           props, 0);
                    drmmode_prop_info_copy(drmmode_crtc.props_plane.ptr, tmp_props.ptr,
                                           DRMMODE_PLANE__COUNT, 1);
                } else {
                    drmModeFreePlane(kplane);
                }
                drmModeFreeObjectProperties(props);
                continue;
            }

            /* Only primary planes are important for atomic page-flipping */
            if (best_plane) { /* Can we have more that one primary plane on a crtc? */
                drmModeFreePlane(best_kplane);
                drmmode_prop_info_free(drmmode_crtc.props_plane.ptr, DRMMODE_PLANE__COUNT);
            }
            best_plane = plane_id;
            best_kplane = kplane;
            blob_id = cast(uint)drmmode_prop_get_value(&tmp_props[DRMMODE_PLANE_IN_FORMATS], props, 0);
            async_blob_id = cast(uint)drmmode_prop_get_value(&tmp_props[DRMMODE_PLANE_IN_FORMATS_ASYNC], props, 0);
            drmmode_prop_info_copy(drmmode_crtc.props_plane.ptr, tmp_props.ptr,
                                   DRMMODE_PLANE__COUNT, 1);
            drmModeFreeObjectProperties(props);
            continue;
        }
        case DRMMODE_PLANE_TYPE_OVERLAY:
        {
            drmModeFreePlane(kplane);
            drmModeFreeObjectProperties(props);
            continue;
        }
        default:
        {
            xf86DrvMsg(drmmode.scrn.scrnIndex, X_WARNING, "Plane with id: %d has unknown plane type: %d\n", plane_id, type);
            drmModeFreePlane(kplane);
            drmModeFreeObjectProperties(props);
            continue;
        }
        }
    }

    drmmode_crtc.plane_id = best_plane;
    if (best_kplane) {
        drmmode_crtc.num_formats = best_kplane.count_formats;
        drmmode_crtc.formats = cast(drmmode_format_rec*)calloc(best_kplane.count_formats,
                                       drmmode_format_rec.sizeof);
        if (!populate_format_modifiers(crtc, best_kplane,
                                       drmmode_crtc.formats, blob_id)) {
            for (int i = 0; i < best_kplane.count_formats; i++)
                drmmode_crtc.formats[i].format = best_kplane.formats[i];
        } else {
            drmmode_crtc.formats_async = cast(drmmode_format_rec*)calloc(best_kplane.count_formats,
                                                 drmmode_format_rec.sizeof);
            if (!populate_format_modifiers(crtc, best_kplane,
                                           drmmode_crtc.formats_async, async_blob_id)) {
                free(drmmode_crtc.formats_async);
                drmmode_crtc.formats_async = null;
            }
        }
        drmModeFreePlane(best_kplane);
    }

    drmmode_prop_info_free(tmp_props.ptr, DRMMODE_PLANE__COUNT);
    drmModeFreePlaneResources(kplane_res);
}

private uint drmmode_crtc_get_prop_id(uint drm_fd, drmModeObjectPropertiesPtr props, const(char)* name)
{
    uint i = void, prop_id = 0;

    for (i = 0; !prop_id && i < props.count_props; ++i) {
        drmModePropertyPtr drm_prop = drmModeGetProperty(drm_fd, props.props[i]);

        if (!drm_prop)
            continue;

        if (strcmp(drm_prop.name.ptr, name) == 0)
            prop_id = drm_prop.prop_id;

        drmModeFreeProperty(drm_prop);
    }

    return prop_id;
}

private void drmmode_crtc_vrr_init(int drm_fd, xf86CrtcPtr crtc)
{
    drmModeObjectPropertiesPtr drm_props = void;
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    if (drmmode.vrr_prop_id)
        return;

    drm_props = drmModeObjectGetProperties(drm_fd,
                                           drmmode_crtc.mode_crtc.crtc_id,
                                           DRM_MODE_OBJECT_CRTC);

    if (!drm_props)
        return;

    drmmode.vrr_prop_id = drmmode_crtc_get_prop_id(drm_fd,
                                                    drm_props,
                                                    "VRR_ENABLED");

    drmModeFreeObjectProperties(drm_props);
}

pragma(inline, true) private drmmode_cursor_dim_rec drmmode_get_kms_default(drmmode_ptr drmmode)
{
    ulong value = 0;
    drmmode_cursor_dim_rec fallback = void;

    /* We begin by using the largest supported cursor, and change it later,
       when we can reliably probe for the smallest suppored cursor size */
    int ret1 = drmGetCap(drmmode.fd, DRM_CAP_CURSOR_WIDTH, &value);
    fallback.width = cast(ushort)value;

    int ret2 = drmGetCap(drmmode.fd, DRM_CAP_CURSOR_HEIGHT, &value);
    fallback.height = cast(ushort)value;

    /* 64x64 is the safest fallback value to use when we can't probe in any other way,
     * as it is the default value that KMS uses.  */
    if (ret1 || ret2) {
        fallback.width  = 64;
        fallback.height = 64;
    }

    return fallback;
}

private drmmode_cursor_dim_rec drmmode_cursor_get_fallback(drmmode_crtc_private_ptr drmmode_crtc)
{
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmmode_cursor_dim_rec fallback = void;

    const(char)* cursor_size_str = xf86GetOptValString(drmmode.Options,
                                                      OPTION_CURSOR_SIZE);

    char* height = void;

    if (!cursor_size_str) {
        return drmmode_get_kms_default(drmmode);
    }

    errno = 0;
    fallback.width = cast(ushort)strtol(cast(char*)cursor_size_str, &height, 10);
    if (errno || fallback.width == 0) {
        return drmmode_get_kms_default(drmmode);
    }

    if (*height == '\0') {
        /* we have a width, but don't have a height */
        fallback.height = fallback.width;
        drmmode_crtc.cursor_probed = TRUE;
        return fallback;
    }

    fallback.height = cast(ushort)strtol(height + 1, null, 10);
    if (errno || fallback.height == 0) {
        return drmmode_get_kms_default(drmmode);
    }

    drmmode_crtc.cursor_probed = TRUE;
    return fallback;
}

private uint drmmode_crtc_init(ScrnInfoPtr pScrn, drmmode_ptr drmmode, drmModeResPtr mode_res, int num)
{
    xf86CrtcPtr crtc = void;
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr) null;
    modesettingEntPtr ms_ent = ms_ent_priv(pScrn);
    drmModeObjectPropertiesPtr props = void;
    static const(drmmode_prop_info_rec)[6] crtc_props = [
        DRMMODE_CRTC_ACTIVE: { name: "ACTIVE" },
        DRMMODE_CRTC_MODE_ID: { name: "MODE_ID" },
        DRMMODE_CRTC_GAMMA_LUT: { name: "GAMMA_LUT" },
        DRMMODE_CRTC_GAMMA_LUT_SIZE: { name: "GAMMA_LUT_SIZE" },
        DRMMODE_CRTC_CTM: { name: "CTM" },
    ];

    crtc = xf86CrtcCreate(pScrn, &drmmode_crtc_funcs);
    if (crtc is null)
        return 0;
    drmmode_crtc = cast(drmmode_crtc_private_rec*)XNFcallocarray(1, drmmode_crtc_private_rec.sizeof);
    crtc.driver_private = drmmode_crtc;
    drmmode_crtc.mode_crtc =
        drmModeGetCrtc(drmmode.fd, mode_res.crtcs[num]);
    drmmode_crtc.drmmode = drmmode;
    drmmode_crtc.vblank_pipe = drmmode_crtc_vblank_pipe(num);
    xorg_list_init(&drmmode_crtc.mode_list);
    xorg_list_init(&drmmode_crtc.tearfree.dri_flip_list);
    drmmode_crtc.next_msc = UINT64_MAX;

    /* Setup the fallback cursor immediately. */
    drmmode_crtc.cursor.dimensions = cast(drmmode_cursor_dim_rec*)malloc(drmmode_cursor_dim_rec.sizeof);
    if (drmmode_crtc.cursor.dimensions is null)
        return 0;

    drmmode_crtc.cursor.num_dimensions = 1;

    drmmode_crtc.cursor.dimensions[0] = drmmode_cursor_get_fallback(drmmode_crtc);

    props = drmModeObjectGetProperties(drmmode.fd, mode_res.crtcs[num],
                                       DRM_MODE_OBJECT_CRTC);
    if (!props || !drmmode_prop_info_copy(drmmode_crtc.props.ptr, crtc_props.ptr,
                                          DRMMODE_CRTC__COUNT, 0)) {
        xf86CrtcDestroy(crtc);
        return 0;
    }

    drmmode_prop_info_update(drmmode, drmmode_crtc.props.ptr,
                             DRMMODE_CRTC__COUNT, props);
    drmModeFreeObjectProperties(props);
    drmmode_crtc_create_planes(crtc, num);

    /* Hide any cursors which may be active from previous users */
    drmModeSetCursor(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id, 0, 0, 0);

    drmmode_crtc_vrr_init(drmmode.fd, crtc);

    /* Mark num'th crtc as in use on this device. */
    ms_ent.assigned_crtcs |= (1 << num);
    xf86DrvMsgVerb(pScrn.scrnIndex, X_INFO, MS_LOGLEVEL_DEBUG,
                   "Allocated crtc nr. %d to this screen.\n", num);

    if (drmmode_crtc.props[DRMMODE_CRTC_GAMMA_LUT_SIZE].prop_id &&
        drmmode_crtc.props[DRMMODE_CRTC_GAMMA_LUT_SIZE].value) {
        /*
         * GAMMA_LUT property supported, and so far tested to be safe to use by
         * default for lut sizes up to 4096 slots. Intel Tigerlake+ has some
         * issues, and a large GAMMA_LUT with 262145 slots, so keep GAMMA_LUT
         * off for large lut sizes by default for now.
         */
        drmmode_crtc.use_gamma_lut = drmmode_crtc.props[DRMMODE_CRTC_GAMMA_LUT_SIZE].value <= 4096;

        /* Allow config override. */
        drmmode_crtc.use_gamma_lut = xf86ReturnOptValBool(drmmode.Options,
                                                           OPTION_USE_GAMMA_LUT,
                                                           drmmode_crtc.use_gamma_lut);
    } else {
        drmmode_crtc.use_gamma_lut = FALSE;
    }

    if (drmmode_crtc.use_gamma_lut &&
        drmmode_crtc.props[DRMMODE_CRTC_CTM].prop_id) {
        drmmode.use_ctm = TRUE;
    }

    return 1;
}

/*
 * Update all of the property values for an output
 */
private void drmmode_output_update_properties(xf86OutputPtr output)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    int i = void, j = void, k = void;
    int err = void;
    drmModeConnectorPtr koutput = void;

    /* Use the most recently fetched values from the kernel */
    koutput = drmmode_output.mode_output;

    if (!koutput)
        return;

    for (i = 0; i < drmmode_output.num_props; i++) {
        drmmode_prop_ptr p = &drmmode_output.props[i];

        for (j = 0; koutput && j < koutput.count_props; j++) {
            if (koutput.props[j] == p.mode_prop.prop_id) {

                /* Check to see if the property value has changed */
                if (koutput.prop_values[j] != p.value) {

                    p.value = koutput.prop_values[j];

                    if (p.mode_prop.flags & DRM_MODE_PROP_RANGE) {
                        INT32 value = cast(uint)p.value;

                        err = RRChangeOutputProperty(cast(_rrOutput*)output.randr_output, p.atoms[0],
                                                     XA_INTEGER, 32, PropModeReplace, 1,
                                                     &value, FALSE, TRUE);

                        if (err != 0) {
                            xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                                       "RRChangeOutputProperty error, %d\n", err);
                        }
                    }
                    else if (p.mode_prop.flags & DRM_MODE_PROP_ENUM) {
                        for (k = 0; k < p.mode_prop.count_enums; k++)
                            if (p.mode_prop.enums[k].value == p.value)
                                break;
                        if (k < p.mode_prop.count_enums) {
                            err = RRChangeOutputProperty(cast(_rrOutput*)output.randr_output, p.atoms[0],
                                                         XA_ATOM, 32, PropModeReplace, 1,
                                                         &p.atoms[k + 1], FALSE, TRUE);
                            if (err != 0) {
                                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                                           "RRChangeOutputProperty error, %d\n", err);
                            }
                        }
                    }
                }
                break;
            }
        }
    }

    /* Update the CTM property */
    if (drmmode_output.ctm_atom) {
        err = RRChangeOutputProperty(cast(_rrOutput*)output.randr_output,
                                     drmmode_output.ctm_atom,
                                     XA_INTEGER, 32, PropModeReplace, 18,
                                     &drmmode_output.ctm,
                                     FALSE, TRUE);
        if (err != 0) {
            xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                       "RRChangeOutputProperty error, %d\n", err);
        }
    }

}

private xf86OutputStatus drmmode_output_detect(xf86OutputPtr output)
{
    /* go to the hw and retrieve a new output struct */
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    drmmode_ptr drmmode = drmmode_output.drmmode;
    xf86OutputStatus status = void;

    if (drmmode_output.output_id == -1)
        return XF86OutputStatusDisconnected;

    drmModeFreeConnector(drmmode_output.mode_output);

    drmmode_output.mode_output =
        drmModeGetConnector(drmmode.fd, drmmode_output.output_id);

    if (!drmmode_output.mode_output) {
        drmmode_output.output_id = -1;
        return XF86OutputStatusDisconnected;
    }

    drmmode_output_update_properties(output);

    switch (drmmode_output.mode_output.connection) {
    case DRM_MODE_CONNECTED:
        status = XF86OutputStatusConnected;
        break;
    case DRM_MODE_DISCONNECTED:
        status = XF86OutputStatusDisconnected;
        break;
    default:
    case DRM_MODE_UNKNOWNCONNECTION:
        status = XF86OutputStatusUnknown;
        break;
    }
    return status;
}

private Bool drmmode_output_mode_valid(xf86OutputPtr output, DisplayModePtr pModes)
{
    return MODE_OK;
}

private int koutput_get_prop_idx(int fd, drmModeConnectorPtr koutput, int type, const(char)* name)
{
    int idx = -1;

    for (int i = 0; i < koutput.count_props; i++) {
        drmModePropertyPtr prop = drmModeGetProperty(fd, koutput.props[i]);

        if (!prop)
            continue;

        if (drm_property_type_is(prop, type) && !strcmp(prop.name.ptr, name))
            idx = i;

        drmModeFreeProperty(prop);

        if (idx > -1)
            break;
    }

    return idx;
}

private int koutput_get_prop_id(int fd, drmModeConnectorPtr koutput, int type, const(char)* name)
{
    int idx = koutput_get_prop_idx(fd, koutput, type, name);

    return (idx > -1) ? koutput.props[idx] : -1;
}

private drmModePropertyBlobPtr koutput_get_prop_blob(int fd, drmModeConnectorPtr koutput, const(char)* name)
{
    drmModePropertyBlobPtr blob = null;
    int idx = koutput_get_prop_idx(fd, koutput, DRM_MODE_PROP_BLOB, name);

    if (idx > -1)
        blob = drmModeGetPropertyBlob(fd, cast(uint)koutput.prop_values[idx]);

    return blob;
}

private void drmmode_output_attach_tile(xf86OutputPtr output)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    drmModeConnectorPtr koutput = drmmode_output.mode_output;
    drmmode_ptr drmmode = drmmode_output.drmmode;
    xf86CrtcTileInfo tile_info = void; xf86CrtcTileInfo* set = null;

    if (!koutput) {
        xf86OutputSetTile(output, null);
        return;
    }

    drmModeFreePropertyBlob(drmmode_output.tile_blob);

    /* look for a TILE property */
    drmmode_output.tile_blob =
        koutput_get_prop_blob(drmmode.fd, koutput, "TILE");

    if (drmmode_output.tile_blob) {
        if (xf86OutputParseKMSTile(cast(char*)drmmode_output.tile_blob.data, drmmode_output.tile_blob.length, &tile_info) == TRUE)
            set = &tile_info;
    }
    xf86OutputSetTile(output, set);
}

private Bool has_panel_fitter(xf86OutputPtr output)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    drmModeConnectorPtr koutput = drmmode_output.mode_output;
    drmmode_ptr drmmode = drmmode_output.drmmode;
    int idx = void;

    /* Presume that if the output supports scaling, then we have a
     * panel fitter capable of adjust any mode to suit.
     */
    idx = koutput_get_prop_idx(drmmode.fd, koutput,
            DRM_MODE_PROP_ENUM, "scaling mode");

    return (idx > -1);
}

private DisplayModePtr drmmode_output_add_gtf_modes(xf86OutputPtr output, DisplayModePtr Modes)
{
    xf86MonPtr mon = output.MonInfo;
    DisplayModePtr i = void, j = void, m = void, preferred = null;
    int max_x = 0, max_y = 0;
    float max_vrefresh = 0.0;

    if (mon && gtf_supported(mon))
        return Modes;

    if (!has_panel_fitter(output))
        return Modes;

    for (m = Modes; m; m = m.next) {
        if (m.type & M_T_PREFERRED)
            preferred = m;
        max_x = max(max_x, m.HDisplay);
        max_y = max(max_y, m.VDisplay);
        max_vrefresh = max(max_vrefresh, xf86ModeVRefresh(m));
    }

    max_vrefresh = max(max_vrefresh, 60.0);
    max_vrefresh *= (1 + SYNC_TOLERANCE);

    m = xf86GetDefaultModes();
    xf86ValidateModesSize(output.scrn, m, max_x, max_y, 0);

    for (i = m; i; i = i.next) {
        if (xf86ModeVRefresh(i) > max_vrefresh)
            i.status = MODE_VSYNC;
        if (preferred &&
            i.HDisplay >= preferred.HDisplay &&
            i.VDisplay >= preferred.VDisplay &&
            xf86ModeVRefresh(i) >= xf86ModeVRefresh(preferred))
            i.status = MODE_VSYNC;
        if (preferred && xf86ModeVRefresh(i) > 0.0) {
            i.Clock = cast(int)(i.Clock * xf86ModeVRefresh(preferred) / xf86ModeVRefresh(i));
            i.VRefresh = xf86ModeVRefresh(preferred);
        }
        for (j = m; j != i; j = j.next) {
            if (!strcmp(i.name, j.name) &&
                xf86ModeVRefresh(i) * (1 + SYNC_TOLERANCE) >= xf86ModeVRefresh(j) &&
                xf86ModeVRefresh(i) * (1 - SYNC_TOLERANCE) <= xf86ModeVRefresh(j)) {
                i.status = MODE_DUPLICATE;
            }
        }
    }

    xf86PruneInvalidModes(output.scrn, &m, FALSE);

    return xf86ModesAdd(Modes, m);
}

private DisplayModePtr drmmode_output_get_modes(xf86OutputPtr output)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    drmModeConnectorPtr koutput = drmmode_output.mode_output;
    drmmode_ptr drmmode = drmmode_output.drmmode;
    int i = void;
    DisplayModePtr Modes = null, Mode = void;
    xf86MonPtr mon = null;

    if (!koutput)
        return null;

    drmModeFreePropertyBlob(drmmode_output.edid_blob);

    /* look for an EDID property */
    drmmode_output.edid_blob =
        koutput_get_prop_blob(drmmode.fd, koutput, "EDID");

    if (drmmode_output.edid_blob) {
        mon = xf86InterpretEDID(output.scrn.scrnIndex,
                                cast(ubyte*)drmmode_output.edid_blob.data);
        if (mon && drmmode_output.edid_blob.length > 128)
            mon.flags |= MONITOR_EDID_COMPLETE_RAWDATA;
    }
    xf86OutputSetEDID(output, mon);

    drmmode_output_attach_tile(output);

    /* modes should already be available */
    for (i = 0; i < koutput.count_modes; i++) {
        Mode = cast(DisplayModeRec*)XNFalloc(DisplayModeRec.sizeof);

        drmmode_ConvertFromKMode(output.scrn, &koutput.modes[i], Mode);
        Modes = xf86ModesAdd(Modes, Mode);

    }

    return drmmode_output_add_gtf_modes(output, Modes);
}

private void drmmode_output_destroy(xf86OutputPtr output)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    int i = void;

    drmModeFreePropertyBlob(drmmode_output.edid_blob);
    drmModeFreePropertyBlob(drmmode_output.tile_blob);

    for (i = 0; i < drmmode_output.num_props; i++) {
        drmModeFreeProperty(drmmode_output.props[i].mode_prop);
        free(drmmode_output.props[i].atoms);
    }
    free(drmmode_output.props);
    if (drmmode_output.mode_output) {
        for (i = 0; i < drmmode_output.mode_output.count_encoders; i++) {
            drmModeFreeEncoder(drmmode_output.mode_encoders[i]);
        }
        drmModeFreeConnector(drmmode_output.mode_output);
    }
    free(drmmode_output.mode_encoders);
    free(drmmode_output);
    output.driver_private = null;
}

private void drmmode_output_dpms(xf86OutputPtr output, int mode)
{
    modesettingPtr ms = mixin(modesettingPTR!("output.scrn"));
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    drmmode_ptr drmmode = drmmode_output.drmmode;
    xf86CrtcPtr crtc = output.crtc;
    drmModeConnectorPtr koutput = drmmode_output.mode_output;

    if (!koutput)
        return;

    /* XXX Check if DPMS mode is already the right one */

    drmmode_output.dpms = mode;

    if (ms.atomic_modeset) {
        if (mode != DPMSModeOn && !ms.pending_modeset)
            drmmode_output_disable(output);
    } else {
        drmModeConnectorSetProperty(drmmode.fd, koutput.connector_id,
                                    drmmode_output.dpms_enum_id, mode);
    }

    if (crtc) {
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

        if (mode == DPMSModeOn) {
            if (drmmode_crtc.need_modeset)
                drmmode_set_mode_major(crtc, &crtc.mode, crtc.rotation,
                                       crtc.x, crtc.y);

            if (drmmode_crtc.enable_flipping)
                drmmode_InitSharedPixmapFlipping(crtc, drmmode_crtc.drmmode);
        } else {
            if (drmmode_crtc.enable_flipping)
                drmmode_FiniSharedPixmapFlipping(crtc, drmmode_crtc.drmmode);
        }
    }

    return;
}

private Bool drmmode_property_ignore(drmModePropertyPtr prop)
{
    if (!prop)
        return TRUE;
    /* ignore blob prop */
    if (prop.flags & DRM_MODE_PROP_BLOB)
        return TRUE;
    /* ignore standard property */
    if (!strcmp(prop.name.ptr, "EDID") || !strcmp(prop.name.ptr, "DPMS") ||
        !strcmp(prop.name.ptr, "CRTC_ID"))
        return TRUE;

    return FALSE;
}

private void drmmode_output_create_resources(xf86OutputPtr output)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    drmModeConnectorPtr mode_output = drmmode_output.mode_output;
    drmmode_ptr drmmode = drmmode_output.drmmode;
    drmModePropertyPtr drmmode_prop = void;
    int i = void, j = void, err = void;

    drmmode_output.props =
        cast(drmmode_prop_rec*)calloc(mode_output.count_props, drmmode_prop_rec.sizeof);
    if (!drmmode_output.props)
        return;

    drmmode_output.num_props = 0;
    for (i = 0, j = 0; i < mode_output.count_props; i++) {
        drmmode_prop = drmModeGetProperty(drmmode.fd, mode_output.props[i]);
        if (drmmode_property_ignore(drmmode_prop)) {
            drmModeFreeProperty(drmmode_prop);
            continue;
        }
        drmmode_output.props[j].mode_prop = drmmode_prop;
        drmmode_output.props[j].value = mode_output.prop_values[i];
        drmmode_output.num_props++;
        j++;
    }

    /* Create CONNECTOR_ID property */
    {
        Atom name = dixAddAtom("CONNECTOR_ID");
        INT32 value = mode_output.connector_id;

        if (name != BAD_RESOURCE) {
            err = RRConfigureOutputProperty(cast(_rrOutput*)output.randr_output, name,
                                            FALSE, FALSE, TRUE,
                                            1, &value);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRConfigureOutputProperty error, %d\n", err);
            }
            err = RRChangeOutputProperty(cast(_rrOutput*)output.randr_output, name,
                                         XA_INTEGER, 32, PropModeReplace, 1,
                                         &value, FALSE, FALSE);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRChangeOutputProperty error, %d\n", err);
            }
        }
    }

    if (drmmode.use_ctm) {
        Atom name = dixAddAtom("CTM");

        if (name != BAD_RESOURCE) {
            drmmode_output.ctm_atom = name;

            err = RRConfigureOutputProperty(cast(_rrOutput*)output.randr_output, name,
                                            FALSE, FALSE, TRUE, 0, null);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRConfigureOutputProperty error, %d\n", err);
            }

            err = RRChangeOutputProperty(cast(_rrOutput*)output.randr_output, name,
                                         XA_INTEGER, 32, PropModeReplace, 18,
                                         &ctm_identity, FALSE, FALSE);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRChangeOutputProperty error, %d\n", err);
            }

            drmmode_output.ctm = ctm_identity;
        }
    }

    for (i = 0; i < drmmode_output.num_props; i++) {
        drmmode_prop_ptr p = &drmmode_output.props[i];

        drmmode_prop = p.mode_prop;

        if (drmmode_prop.flags & DRM_MODE_PROP_RANGE) {
            INT32[2] prop_range = void;
            INT32 value = cast(int)p.value;

            p.num_atoms = 1;
            p.atoms = cast(uint*)calloc(p.num_atoms, Atom.sizeof);
            if (!p.atoms)
                continue;
            p.atoms[0] = dixAddAtom(drmmode_prop.name.ptr);
            prop_range[0] = cast(int)drmmode_prop.values[0];
            prop_range[1] = cast(int)drmmode_prop.values[1];
            err = RRConfigureOutputProperty(cast(_rrOutput*)output.randr_output, p.atoms[0],
                                            FALSE, TRUE,
                                            drmmode_prop.
                                            flags & DRM_MODE_PROP_IMMUTABLE ?
                                            TRUE : FALSE, 2, prop_range.ptr);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRConfigureOutputProperty error, %d\n", err);
            }
            err = RRChangeOutputProperty(cast(_rrOutput*)output.randr_output, p.atoms[0],
                                         XA_INTEGER, 32, PropModeReplace, 1,
                                         &value, FALSE, TRUE);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRChangeOutputProperty error, %d\n", err);
            }
        }
        else if (drmmode_prop.flags & DRM_MODE_PROP_ENUM) {
            p.num_atoms = drmmode_prop.count_enums + 1;
            p.atoms = cast(uint*)calloc(p.num_atoms, Atom.sizeof);
            if (!p.atoms)
                continue;
            p.atoms[0] = dixAddAtom(drmmode_prop.name.ptr);
            for (j = 1; j <= drmmode_prop.count_enums; j++) {
                drm_mode_property_enum* e = &drmmode_prop.enums[j - 1];
                p.atoms[j] = dixAddAtom(e.name.ptr);
            }
            err = RRConfigureOutputProperty(cast(_rrOutput*)output.randr_output, p.atoms[0],
                                            FALSE, FALSE,
                                            drmmode_prop.
                                            flags & DRM_MODE_PROP_IMMUTABLE ?
                                            TRUE : FALSE, p.num_atoms - 1,
                                            cast(INT32*) &p.atoms[1]);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRConfigureOutputProperty error, %d\n", err);
            }
            for (j = 0; j < drmmode_prop.count_enums; j++)
                if (drmmode_prop.enums[j].value == p.value)
                    break;
            /* there's always a matching value */
            err = RRChangeOutputProperty(cast(_rrOutput*)output.randr_output, p.atoms[0],
                                         XA_ATOM, 32, PropModeReplace, 1,
                                         &p.atoms[j + 1], FALSE, TRUE);
            if (err != 0) {
                xf86DrvMsg(output.scrn.scrnIndex, X_ERROR,
                           "RRChangeOutputProperty error, %d\n", err);
            }
        }
    }
}

private Bool drmmode_output_set_property(xf86OutputPtr output, Atom property, RRPropertyValuePtr value)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;
    drmmode_ptr drmmode = drmmode_output.drmmode;
    int i = void;

    for (i = 0; i < drmmode_output.num_props; i++) {
        drmmode_prop_ptr p = &drmmode_output.props[i];

        if ((!p.atoms) || (p.atoms[0] != property))
            continue;

        if (p.mode_prop.flags & DRM_MODE_PROP_RANGE) {
            uint val = void;

            if (value.type != XA_INTEGER || value.format != 32 ||
                value.size != 1)
                return FALSE;
            val = *cast(uint*) value.data;

            drmModeConnectorSetProperty(drmmode.fd, drmmode_output.output_id,
                                        p.mode_prop.prop_id, cast(ulong) val);
            return TRUE;
        }
        else if (p.mode_prop.flags & DRM_MODE_PROP_ENUM) {
            Atom atom = void;
            const(char)* name = void;
            int j = void;

            if (value.type != XA_ATOM || value.format != 32 ||
                value.size != 1)
                return FALSE;
            memcpy(&atom, value.data, 4);
            if (((name = NameForAtom(atom)) is null))
                return FALSE;

            /* search for matching name string, then set its value down */
            for (j = 0; j < p.mode_prop.count_enums; j++) {
                if (!strcmp(p.mode_prop.enums[j].name.ptr, name)) {
                    drmModeConnectorSetProperty(drmmode.fd,
                                                drmmode_output.output_id,
                                                p.mode_prop.prop_id,
                                                p.mode_prop.enums[j].value);
                    return TRUE;
                }
            }
        }
    }

    if (property == drmmode_output.ctm_atom) {
        const(size_t) matrix_size = typeof(drmmode_output.ctm).sizeof;

        if (value.type != XA_INTEGER || value.format != 32 ||
            value.size * 4 != matrix_size)
            return FALSE;

        memcpy(&drmmode_output.ctm, value.data, matrix_size);

        // Update the CRTC if there is one bound to this output.
        if (output.crtc) {
            drmmode_set_ctm(output.crtc, &drmmode_output.ctm);
        }
    }

    return TRUE;
}

private Bool drmmode_output_get_property(xf86OutputPtr output, Atom property)
{
    return TRUE;
}

private const(xf86OutputFuncsRec) drmmode_output_funcs = {
    dpms: &drmmode_output_dpms,
    create_resources: &drmmode_output_create_resources,
    set_property: &drmmode_output_set_property,
    get_property: &drmmode_output_get_property,
    detect: &drmmode_output_detect,
    mode_valid: &drmmode_output_mode_valid,

    get_modes: &drmmode_output_get_modes,
    destroy: &drmmode_output_destroy
};

private int[7] subpixel_conv_table = [
    0,
    SubPixelUnknown,
    SubPixelHorizontalRGB,
    SubPixelHorizontalBGR,
    SubPixelVerticalRGB,
    SubPixelVerticalBGR,
    SubPixelNone
];

private const(char*)[19] output_names = [
    "None",
    "VGA",
    "DVI-I",
    "DVI-D",
    "DVI-A",
    "Composite",
    "SVIDEO",
    "LVDS",
    "Component",
    "DIN",
    "DP",
    "HDMI",
    "HDMI-B",
    "TV",
    "eDP",
    "Virtual",
    "DSI",
    "DPI",
];

private xf86OutputPtr find_output(ScrnInfoPtr pScrn, int id)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    int i = void;
    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];
        drmmode_output_private_ptr drmmode_output = void;

        drmmode_output = cast(drmmode_output_private_rec*)output.driver_private;
        if (drmmode_output.output_id == id)
            return output;
    }
    return null;
}

private int parse_path_blob(drmModePropertyBlobPtr path_blob, int* conn_base_id, char** path)
{
    char* conn = void;
    char[5] conn_id = void;
    int id = void, len = void;
    char* blob_data = void;

    if (!path_blob)
        return -1;

    blob_data = cast(char*)path_blob.data;
    /* we only handle MST paths for now */
    if (strncmp(blob_data, "mst:", 4))
        return -1;

    conn = strchr(blob_data + 4, '-');
    if (!conn)
        return -1;
    len = cast(int)(conn - (blob_data + 4));
    if (len + 1> 5)
        return -1;
    memcpy(conn_id.ptr, blob_data + 4, len);
    conn_id[len] = '\0';
    id = cast(int)strtoul(conn_id.ptr, null, 10);

    *conn_base_id = id;

    *path = conn + 1;
    return 0;
}

private void drmmode_create_name(ScrnInfoPtr pScrn, drmModeConnectorPtr koutput, char* name, drmModePropertyBlobPtr path_blob)
{
    int ret = void;
    char* extra_path = void;
    int conn_id = void;
    xf86OutputPtr output = void;

    ret = parse_path_blob(path_blob, &conn_id, &extra_path);
    if (ret == -1)
        goto fallback;

    output = find_output(pScrn, conn_id);
    if (!output)
        goto fallback;

    snprintf(name, 32, "%s-%s", output.name, extra_path);
    return;

 fallback:
    if (koutput.connector_type >= mixin(ARRAY_SIZE!("output_names")))
        snprintf(name, 32, "Unknown%d-%d", koutput.connector_type, koutput.connector_type_id);
    else if (pScrn.is_gpu)
        snprintf(name, 32, "%s-%d-%d", output_names[koutput.connector_type], pScrn.scrnIndex - GPU_SCREEN_OFFSET + 1, koutput.connector_type_id);
    else
        snprintf(name, 32, "%s-%d", output_names[koutput.connector_type], koutput.connector_type_id);
}

private Bool drmmode_connector_check_vrr_capable(uint drm_fd, int connector_id)
{
    uint i = void;
    Bool found = FALSE;
    ulong prop_value = 0;
    drmModeObjectPropertiesPtr props = void;
    const(char)* prop_name = "VRR_CAPABLE";

    props = drmModeObjectGetProperties(drm_fd, connector_id,
                                    DRM_MODE_OBJECT_CONNECTOR);
    if (!props)
        return FALSE;

    for (i = 0; !found && i < props.count_props; ++i) {
        drmModePropertyPtr drm_prop = drmModeGetProperty(drm_fd, props.props[i]);

        if (!drm_prop)
            continue;

        if (externs.gnu.strcasecmp(drm_prop.name.ptr, prop_name) == 0) {
            prop_value = props.prop_values[i];
            found = TRUE;
        }

        drmModeFreeProperty(drm_prop);
    }

    drmModeFreeObjectProperties(props);

    if(found)
        return prop_value ? TRUE : FALSE;

    return FALSE;
}

private uint drmmode_output_init(ScrnInfoPtr pScrn, drmmode_ptr drmmode, drmModeResPtr mode_res, int num, Bool dynamic, int crtcshift)
{
    xf86OutputPtr output = void;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    modesettingPtr ms = mixin(modesettingPTR!("pScrn"));
    drmModeConnectorPtr koutput = void;
    drmModeEncoderPtr* kencoders = null;
    drmmode_output_private_ptr drmmode_output = void;
    char[32] name = void;
    int i = void;
    Bool nonDesktop = FALSE;
    drmModePropertyBlobPtr path_blob = null;
    const(char)* s = void;
    drmModeObjectPropertiesPtr props = void;
    static const(drmmode_prop_info_rec)[2] connector_props = [
        DRMMODE_CONNECTOR_CRTC_ID: { name: "CRTC_ID", },
    ];

    koutput =
        drmModeGetConnector(drmmode.fd, mode_res.connectors[num]);
    if (!koutput)
        return 0;

    path_blob = koutput_get_prop_blob(drmmode.fd, koutput, "PATH");
    i = koutput_get_prop_idx(drmmode.fd, koutput, DRM_MODE_PROP_RANGE, RR_PROPERTY_NON_DESKTOP);
    if (i >= 0)
        nonDesktop = koutput.prop_values[i] != 0;

    drmmode_create_name(pScrn, koutput, name.ptr, path_blob);

    if (path_blob)
        drmModeFreePropertyBlob(path_blob);

    if (path_blob && dynamic) {
        /* see if we have an output with this name already
           and hook stuff up */
        for (i = 0; i < xf86_config.num_output; i++) {
            output = xf86_config.output[i];

            if (strncmp(output.name, name.ptr, 32))
                continue;

            drmmode_output = cast(drmmode_output_private_rec*)output.driver_private;
            drmmode_output.output_id = mode_res.connectors[num];
            drmmode_output.mode_output = koutput;
            output.non_desktop = nonDesktop;
            return 1;
        }
    }

    kencoders = cast(drmModeEncoderPtr*) calloc(koutput.count_encoders, drmModeEncoderPtr.sizeof);
    if (!kencoders) {
        goto out_free_encoders;
    }

    for (i = 0; i < koutput.count_encoders; i++) {
        kencoders[i] = drmModeGetEncoder(drmmode.fd, koutput.encoders[i]);
        if (!kencoders[i]) {
            goto out_free_encoders;
        }
    }

    if (xf86IsEntityShared(pScrn.entityList[0])) {
        if ((s = xf86GetOptValString(drmmode.Options, OPTION_ZAPHOD_HEADS)) !is null) {
            if (!drmmode_zaphod_string_matches(pScrn, s, name.ptr))
                goto out_free_encoders;
        } else {
            if (!drmmode.is_secondary && (num != 0))
                goto out_free_encoders;
            else if (drmmode.is_secondary && (num != 1))
                goto out_free_encoders;
        }
    }

    output = xf86OutputCreate(pScrn, &drmmode_output_funcs, name.ptr);
    if (!output) {
        goto out_free_encoders;
    }

    drmmode_output = cast(drmmode_output_private_rec*) calloc(1, drmmode_output_private_rec.sizeof);
    if (!drmmode_output) {
        xf86OutputDestroy(output);
        goto out_free_encoders;
    }

    drmmode_output.output_id = mode_res.connectors[num];
    drmmode_output.mode_output = koutput;
    drmmode_output.mode_encoders = kencoders;
    drmmode_output.drmmode = drmmode;
    output.mm_width = koutput.mmWidth;
    output.mm_height = koutput.mmHeight;

    output.subpixel_order = subpixel_conv_table[koutput.subpixel];
    output.interlaceAllowed = TRUE;
    output.doubleScanAllowed = TRUE;
    output.driver_private = drmmode_output;
    output.non_desktop = nonDesktop;

    output.possible_crtcs = 0;
    for (i = 0; i < koutput.count_encoders; i++) {
        output.possible_crtcs |= (kencoders[i].possible_crtcs >> crtcshift) & 0x7f;
    }
    /* work out the possible clones later */
    output.possible_clones = 0;

    if (ms.atomic_modeset) {
        if (!drmmode_prop_info_copy(drmmode_output.props_connector.ptr,
                                    connector_props.ptr, DRMMODE_CONNECTOR__COUNT,
                                    0)) {
            goto out_free_encoders;
        }
        props = drmModeObjectGetProperties(drmmode.fd,
                                           drmmode_output.output_id,
                                           DRM_MODE_OBJECT_CONNECTOR);
        drmmode_prop_info_update(drmmode, drmmode_output.props_connector.ptr,
                                 DRMMODE_CONNECTOR__COUNT, props);
    } else {
        drmmode_output.dpms_enum_id =
            koutput_get_prop_id(drmmode.fd, koutput, DRM_MODE_PROP_ENUM,
                                "DPMS");
    }

    if (dynamic) {
        output.randr_output = RROutputCreate(xf86ScrnToScreen(pScrn), output.name, cast(int)strlen(output.name), output);
        if (output.randr_output) {
            drmmode_output_create_resources(output);
            RRPostPendingProperties(cast(_rrOutput*)output.randr_output);
        }
    }

    ms.is_connector_vrr_capable |=
              drmmode_connector_check_vrr_capable(drmmode.fd,
                                                  drmmode_output.output_id);
    return 1;

 out_free_encoders:
    if (kencoders) {
        for (i = 0; i < koutput.count_encoders; i++)
            drmModeFreeEncoder(kencoders[i]);
        free(kencoders);
    }
    drmModeFreeConnector(koutput);

    return 0;
}

private uint find_clones(ScrnInfoPtr scrn, xf86OutputPtr output)
{
    drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private, clone_drmout = void;
    int i = void;
    xf86OutputPtr clone_output = void;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int index_mask = 0;

    if (drmmode_output.enc_clone_mask == 0)
        return index_mask;

    for (i = 0; i < xf86_config.num_output; i++) {
        clone_output = xf86_config.output[i];
        clone_drmout = cast(drmmode_output_private_ptr)clone_output.driver_private;
        if (output == clone_output)
            continue;

        if (clone_drmout.enc_mask == 0)
            continue;
        if (drmmode_output.enc_clone_mask == clone_drmout.enc_mask)
            index_mask |= (1 << i);
    }
    return index_mask;
}

private void drmmode_clones_init(ScrnInfoPtr scrn, drmmode_ptr drmmode, drmModeResPtr mode_res)
{
    int i = void, j = void;
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));

    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];
        drmmode_output_private_ptr drmmode_output = void;

        drmmode_output = cast(drmmode_output_private_rec*)output.driver_private;
        drmmode_output.enc_clone_mask = 0xff;
        /* and all the possible encoder clones for this output together */
        for (j = 0; j < drmmode_output.mode_output.count_encoders; j++) {
            int k = void;

            for (k = 0; k < mode_res.count_encoders; k++) {
                if (mode_res.encoders[k] ==
                    drmmode_output.mode_encoders[j].encoder_id)
                    drmmode_output.enc_mask |= (1 << k);
            }

            drmmode_output.enc_clone_mask &=
                drmmode_output.mode_encoders[j].possible_clones;
        }
    }

    for (i = 0; i < xf86_config.num_output; i++) {
        xf86OutputPtr output = xf86_config.output[i];

        output.possible_clones = find_clones(scrn, output);
    }
}

private Bool drmmode_set_pixmap_bo(drmmode_ptr drmmode, PixmapPtr pixmap, gbm_bo* bo)
{
static if (GLAMOR) {
    ScrnInfoPtr scrn = drmmode.scrn;
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    if (!drmmode.glamor_gbm)
        return TRUE;

    if (!ms.glamor.egl_create_textured_pixmap_from_gbm_bo(pixmap, bo,
                                                           gbm_bo_get_used_modifiers(bo))) {
        xf86DrvMsg(scrn.scrnIndex, X_ERROR, "Failed to create pixmap\n");
        return FALSE;
    }
}

    return TRUE;
}

Bool drmmode_glamor_handle_new_screen_pixmap(drmmode_ptr drmmode)
{
    ScreenPtr screen = xf86ScrnToScreen(drmmode.scrn);
    PixmapPtr screen_pixmap = screen.GetScreenPixmap(screen);

    if (!drmmode_set_pixmap_bo(drmmode, screen_pixmap, drmmode.front_bo))
        return FALSE;

    return TRUE;
}

private Bool drmmode_xf86crtc_resize(ScrnInfoPtr scrn, int width, int height)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    drmmode_ptr drmmode = &ms.drmmode;
    gbm_bo* old_front = void;
    ScreenPtr screen = xf86ScrnToScreen(scrn);
    uint old_fb_id = void;
    int i = void, pitch = void, old_width = void, old_height = void, old_pitch = void;
    int cpp = (scrn.bitsPerPixel + 7) / 8;
    int kcpp = (drmmode.kbpp + 7) / 8;
    PixmapPtr ppix = screen.GetScreenPixmap(screen);
    void* new_pixels = null;

    if (scrn.virtualX == width && scrn.virtualY == height)
        return TRUE;

    xf86DrvMsg(scrn.scrnIndex, X_INFO,
               "Allocate new frame buffer %dx%d stride\n", width, height);

    old_width = scrn.virtualX;
    old_height = scrn.virtualY;
    old_pitch = gbm_bo_get_stride(drmmode.front_bo);
    old_front = drmmode.front_bo;
    old_fb_id = drmmode.fb_id;
    drmmode.fb_id = 0;

    drmmode.front_bo = gbm_create_best_bo(drmmode, !drmmode.glamor_gbm, width, height, DRMMODE_FRONT_BO);
    if (!drmmode.front_bo)
        goto fail;

    pitch = gbm_bo_get_stride(drmmode.front_bo);

    scrn.virtualX = width;
    scrn.virtualY = height;
    scrn.displayWidth = pitch / kcpp;

    if (!drmmode.glamor_gbm) {
        new_pixels = gbm_bo_get_map(drmmode.front_bo);
    }

    if (drmmode.shadow_enable) {
        uint size = scrn.displayWidth * scrn.virtualY * cpp;
        new_pixels = calloc(1, size);
        if (new_pixels is null)
            goto fail;
        free(drmmode.shadow_fb);
        drmmode.shadow_fb = new_pixels;
    }

    if (drmmode.shadow_enable2) {
        uint size = scrn.displayWidth * scrn.virtualY * cpp;
        void* fb2 = calloc(1, size);
        free(drmmode.shadow_fb2);
        drmmode.shadow_fb2 = fb2;
    }

    screen.ModifyPixmapHeader(ppix, width, height, -1, -1,
                               scrn.displayWidth * cpp, new_pixels);

    if (!drmmode_glamor_handle_new_screen_pixmap(drmmode))
        goto fail;

    drmmode_clear_pixmap(ppix);

    for (i = 0; i < xf86_config.num_crtc; i++) {
        xf86CrtcPtr crtc = xf86_config.crtc[i];

        if (!crtc.enabled)
            continue;

        drmmode_set_mode_major(crtc, &crtc.mode,
                               crtc.rotation, crtc.x, crtc.y);
    }

    if (old_fb_id)
        drmModeRmFB(drmmode.fd, old_fb_id);

    gbm_bo_destroy(old_front);

    return TRUE;

 fail:
    gbm_bo_destroy(drmmode.front_bo);
    drmmode.front_bo = old_front;
    scrn.virtualX = old_width;
    scrn.virtualY = old_height;
    scrn.displayWidth = old_pitch / kcpp;
    drmmode.fb_id = old_fb_id;

    return FALSE;
}

private void drmmode_validate_leases(ScrnInfoPtr scrn)
{
    ScreenPtr screen = scrn.pScreen;
    rrScrPrivPtr scr_priv = void;
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    drmmode_ptr drmmode = &ms.drmmode;
    drmModeLesseeListPtr lessees = void;
    RRLeasePtr lease = void, next = void;
    int l = void;

    /* Bail out if RandR wasn't initialized. */
    if (!dixPrivateKeyRegistered(rrPrivKey))
        return;

    scr_priv = mixin(rrGetScrPriv!("screen"));

    /* We can't talk to the kernel about leases when VT switched */
    if (!scrn.vtSema)
        return;

    lessees = drmModeListLessees(drmmode.fd);
    if (!lessees)
        return;

    mixin(xorg_list_for_each_entry_safe!("lease", "next", "&scr_priv.leases", "list", q{
        drmmode_lease_private_ptr lease_private = cast(drmmode_lease_private_ptr)lease.devPrivate;

        for (l = 0; l < lessees.count; l++) {
            if (lessees.lessees[l] == lease_private.lessee_id)
                break;
        }

        /* check to see if the lease has gone away */
        if (l == lessees.count) {
            free(lease_private);
            lease.devPrivate = null;
            xf86CrtcLeaseTerminated(lease);
        }
    }));

    free(lessees);
}

private int drmmode_create_lease(RRLeasePtr lease, int* fd)
{
    ScreenPtr screen = lease.screen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    drmmode_ptr drmmode = &ms.drmmode;
    int ncrtc = lease.numCrtcs;
    int noutput = lease.numOutputs;
    int nobjects = void;
    int c = void, o = void;
    int i = void;
    int lease_fd = void;
    uint* objects = void;
    drmmode_lease_private_ptr lease_private = void;

    nobjects = ncrtc + noutput;

    if (ms.atomic_modeset)
        nobjects += ncrtc; /* account for planes as well */

    if (nobjects == 0)
        return BadValue;

    lease_private = cast(drmmode_lease_private_rec*) calloc(1, drmmode_lease_private_rec.sizeof);
    if (!lease_private)
        return BadAlloc;

    objects = cast(uint*) calloc(nobjects, uint.sizeof);

    if (!objects) {
        free(lease_private);
        return BadAlloc;
    }

    i = 0;

    /* Add CRTC and plane ids */
    for (c = 0; c < ncrtc; c++) {
        xf86CrtcPtr crtc = cast(_xf86Crtc*)lease.crtcs[c].devPrivate;
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

        objects[i++] = drmmode_crtc.mode_crtc.crtc_id;
        if (ms.atomic_modeset)
            objects[i++] = drmmode_crtc.plane_id;
    }

    /* Add connector ids */

    for (o = 0; o < noutput; o++) {
        xf86OutputPtr output = cast(xf86OutputPtr)lease.outputs[o].devPrivate;
        drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;

        objects[i++] = drmmode_output.mode_output.connector_id;
    }

    /* call kernel to create lease */
    assert (i == nobjects);

    lease_fd = drmModeCreateLease(drmmode.fd, objects, nobjects, 0, &lease_private.lessee_id);

    free(objects);

    if (lease_fd < 0) {
        free(lease_private);
        return BadMatch;
    }

    lease.devPrivate = lease_private;

    xf86CrtcLeaseStarted(lease);

    *fd = lease_fd;
    return Success;
}

private void drmmode_terminate_lease(RRLeasePtr lease)
{
    ScreenPtr screen = lease.screen;
    ScrnInfoPtr scrn = xf86ScreenToScrn(screen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    drmmode_ptr drmmode = &ms.drmmode;
    drmmode_lease_private_ptr lease_private = cast(drmmode_lease_private_ptr)lease.devPrivate;

    if (drmModeRevokeLease(drmmode.fd, lease_private.lessee_id) == 0) {
        free(lease_private);
        lease.devPrivate = null;
        xf86CrtcLeaseTerminated(lease);
    }
}

private const(xf86CrtcConfigFuncsRec) drmmode_xf86crtc_config_funcs = {
    resize: &drmmode_xf86crtc_resize,
    create_lease: &drmmode_create_lease,
    terminate_lease: &drmmode_terminate_lease
};

Bool drmmode_pre_init(ScrnInfoPtr pScrn, drmmode_ptr drmmode, int cpp)
{
    modesettingEntPtr ms_ent = ms_ent_priv(pScrn);
    int i = void;
    int ret = void;
    ulong value = 0;
    uint crtcs_needed = 0;
    drmModeResPtr mode_res = void;
    int crtcshift = void;

    /* check for dumb capability */
    ret = drmGetCap(drmmode.fd, DRM_CAP_DUMB_BUFFER, &value);
    if (ret > 0 || value != 1) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                   "KMS doesn't support dumb interface\n");
        return FALSE;
    }

    xf86CrtcConfigInit(pScrn, &drmmode_xf86crtc_config_funcs);

    drmmode.scrn = pScrn;
    drmmode.cpp = cpp;
    mode_res = drmModeGetResources(drmmode.fd);
    if (!mode_res)
        return FALSE;

    crtcshift = ffs(ms_ent.assigned_crtcs ^ 0xffffffff) - 1;
    for (i = 0; i < mode_res.count_connectors; i++)
        crtcs_needed += drmmode_output_init(pScrn, drmmode, mode_res, i, FALSE,
                                            crtcshift);

    xf86DrvMsgVerb(pScrn.scrnIndex, X_INFO, MS_LOGLEVEL_DEBUG,
                   "Up to %d crtcs needed for screen.\n", crtcs_needed);

    xf86CrtcSetSizeRange(pScrn, 320, 200, mode_res.max_width,
                         mode_res.max_height);
    for (i = 0; i < mode_res.count_crtcs; i++)
        if (!xf86IsEntityShared(pScrn.entityList[0]) ||
            (crtcs_needed && !(ms_ent.assigned_crtcs & (1 << i))))
            crtcs_needed -= drmmode_crtc_init(pScrn, drmmode, mode_res, i);

    /* All ZaphodHeads outputs provided with matching crtcs? */
    if (xf86IsEntityShared(pScrn.entityList[0]) && (crtcs_needed > 0))
        xf86DrvMsg(pScrn.scrnIndex, X_WARNING,
                   "%d ZaphodHeads crtcs unavailable. Some outputs will stay off.\n",
                   crtcs_needed);

    /* workout clones */
    drmmode_clones_init(pScrn, drmmode, mode_res);

    drmModeFreeResources(mode_res);
    xf86ProviderSetup(pScrn, null, "modesetting");

    xf86InitialConfiguration(pScrn, TRUE);

    return TRUE;
}

Bool drmmode_init(ScrnInfoPtr pScrn, drmmode_ptr drmmode)
{
static if (GLAMOR) {
    ScreenPtr pScreen = xf86ScrnToScreen(pScrn);
    modesettingPtr ms = mixin(modesettingPTR!("pScrn"));

    if (drmmode.glamor) {
        if (!ms.glamor.init(pScreen, GLAMOR_USE_EGL_SCREEN)) {
            return FALSE;
        }
static if (GBM_BO_WITH_MODIFIERS) {
        ms.glamor.set_drawable_modifiers_func(pScreen, &get_drawable_modifiers);
}
    }
}

    return TRUE;
}

void drmmode_adjust_frame(ScrnInfoPtr pScrn, drmmode_ptr drmmode, int x, int y)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    xf86OutputPtr output = config.output[config.compat_output];
    xf86CrtcPtr crtc = output.crtc;

    if (crtc && crtc.enabled) {
        drmmode_set_mode_major(crtc, &crtc.mode, crtc.rotation, x, y);
    }
}

Bool drmmode_set_desired_modes(ScrnInfoPtr pScrn, drmmode_ptr drmmode, Bool set_hw, Bool ign_err)
{
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    Bool success = TRUE;
    int c = void;

    drmmmode_prepare_modeset(pScrn);

    for (c = 0; c < config.num_crtc; c++) {
        xf86CrtcPtr crtc = config.crtc[c];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
        xf86OutputPtr output = null;
        int o = void;

        /* Skip disabled CRTCs */
        if (!crtc.enabled) {
            if (set_hw) {
                drmModeSetCrtc(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                               0, 0, 0, null, 0, null);
            }
            continue;
        }

        if (config.output[config.compat_output].crtc == crtc)
            output = config.output[config.compat_output];
        else {
            for (o = 0; o < config.num_output; o++)
                if (config.output[o].crtc == crtc) {
                    output = config.output[o];
                    break;
                }
        }
        /* paranoia */
        if (!output)
            continue;

        /* Mark that we'll need to re-set the mode for sure */
        memset(&crtc.mode, 0, typeof(crtc.mode).sizeof);
        if (!crtc.desiredMode.CrtcHDisplay) {
            DisplayModePtr mode = xf86OutputFindClosestMode(output, pScrn.currentMode);

            if (!mode)
                return FALSE;
            crtc.desiredMode = *mode;
            crtc.desiredRotation = RR_Rotate_0;
            crtc.desiredX = 0;
            crtc.desiredY = 0;
        }

        if (set_hw) {
            if (!crtc.funcs.
                set_mode_major(crtc, &crtc.desiredMode, crtc.desiredRotation,
                               crtc.desiredX, crtc.desiredY)) {
                if (!ign_err)
                    return FALSE;
                else {
                    success = FALSE;
                    crtc.enabled = FALSE;
                    xf86DrvMsg(pScrn.scrnIndex, X_WARNING,
                               "Failed to set the desired mode on connector %s\n",
                               output.name);
                }
            }
        } else {
            crtc.mode = crtc.desiredMode;
            crtc.rotation = crtc.desiredRotation;
            crtc.x = crtc.desiredX;
            crtc.y = crtc.desiredY;
            if (!xf86CrtcRotate(crtc))
                return FALSE;
        }
    }

    /* Validate leases on VT re-entry */
    drmmode_validate_leases(pScrn);

    return success;
}

private void drmmode_load_palette(ScrnInfoPtr pScrn, int numColors, int* indices, LOCO* colors, VisualPtr pVisual)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    ushort[256] lut_r = void, lut_g = void, lut_b = void;
    int index = void, j = void, i = void;
    int c = void;

    for (c = 0; c < xf86_config.num_crtc; c++) {
        xf86CrtcPtr crtc = xf86_config.crtc[c];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

        for (i = 0; i < 256; i++) {
            lut_r[i] = cast(ushort)(drmmode_crtc.lut_r[i] << 6);
            lut_g[i] = cast(ushort)(drmmode_crtc.lut_g[i] << 6);
            lut_b[i] = cast(ushort)(drmmode_crtc.lut_b[i] << 6);
        }

        switch (pScrn.depth) {
        case 15:
            for (i = 0; i < numColors; i++) {
                index = indices[i];
                for (j = 0; j < 8; j++) {
                    lut_r[index * 8 + j] = cast(ushort)(colors[index].red << 6);
                    lut_g[index * 8 + j] = cast(ushort)(colors[index].green << 6);
                    lut_b[index * 8 + j] = cast(ushort)(colors[index].blue << 6);
                }
            }
            break;
        case 16:
            for (i = 0; i < numColors; i++) {
                index = indices[i];

                if (i <= 31) {
                    for (j = 0; j < 8; j++) {
                        lut_r[index * 8 + j] = cast(ushort)(colors[index].red << 6);
                        lut_b[index * 8 + j] = cast(ushort)(colors[index].blue << 6);
                    }
                }

                for (j = 0; j < 4; j++) {
                    lut_g[index * 4 + j] = cast(ushort)(colors[index].green << 6);
                }
            }
            break;
        default:
            for (i = 0; i < numColors; i++) {
                index = indices[i];
                lut_r[index] = cast(ushort)(colors[index].red << 6);
                lut_g[index] = cast(ushort)(colors[index].green << 6);
                lut_b[index] = cast(ushort)(colors[index].blue << 6);
            }
            break;
        }

        /* Make the change through RandR */
        if (crtc.randr_crtc)
            RRCrtcGammaSet(crtc.randr_crtc, lut_r.ptr, lut_g.ptr, lut_b.ptr);
        else
            crtc.funcs.gamma_set(crtc, lut_r.ptr, lut_g.ptr, lut_b.ptr, 256);
    }
}

private Bool drmmode_crtc_upgrade_lut(xf86CrtcPtr crtc, int num)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    ulong size = void;

    if (!drmmode_crtc.use_gamma_lut)
        return TRUE;

    assert(drmmode_crtc.props[DRMMODE_CRTC_GAMMA_LUT_SIZE].prop_id);

    size = drmmode_crtc.props[DRMMODE_CRTC_GAMMA_LUT_SIZE].value;

    if (size != crtc.gamma_size) {
        ScrnInfoPtr pScrn = crtc.scrn;
        ushort* gamma = cast(ushort*) calloc(3 * size, ushort.sizeof);

        if (gamma) {
            free(crtc.gamma_red);

            crtc.gamma_size = cast(int)size;
            crtc.gamma_red = gamma;
            crtc.gamma_green = gamma + size;
            crtc.gamma_blue = gamma + size * 2;

            xf86DrvMsgVerb(pScrn.scrnIndex, X_INFO, MS_LOGLEVEL_DEBUG,
                           "Gamma ramp set to %lld entries on CRTC %d\n",
                           cast(long)size, num);
        } else {
            xf86DrvMsg(pScrn.scrnIndex, X_ERROR,
                       "Failed to allocate memory for %lld gamma ramp entries "
                       ~ "on CRTC %d.\n",
                       cast(long)size, num);
            return FALSE;
        }
    }

    return TRUE;
}

Bool drmmode_setup_colormap(ScreenPtr pScreen, ScrnInfoPtr pScrn)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    int i = void;

    xf86DrvMsg(pScrn.scrnIndex, X_INFO,
              "Initializing kms color map for depth %d, %d bpc.\n",
              pScrn.depth, pScrn.rgbBits);
    if (!miCreateDefColormap(pScreen))
        return FALSE;

    /* If the GAMMA_LUT property is available, replace the server's default
     * gamma ramps with ones of the appropriate size. */
    for (i = 0; i < xf86_config.num_crtc; i++)
        if (!drmmode_crtc_upgrade_lut(xf86_config.crtc[i], i))
            return FALSE;

    /* Adapt color map size and depth to color depth of screen. */
    if (!xf86HandleColormaps(pScreen, 1 << pScrn.rgbBits, 10,
                             &drmmode_load_palette, null,
                             CMAP_PALETTED_TRUECOLOR |
                             CMAP_RELOAD_ON_MODE_SWITCH))
        return FALSE;
    return TRUE;
}

enum DRM_MODE_LINK_STATUS_GOOD =       0;
enum DRM_MODE_LINK_STATUS_BAD =        1;

void drmmode_update_kms_state(drmmode_ptr drmmode)
{
    ScrnInfoPtr scrn = drmmode.scrn;
    drmModeResPtr mode_res = void;
    xf86CrtcConfigPtr config = mixin(XF86_CRTC_CONFIG_PTR!("scrn"));
    int i = void, j = void;
    Bool found = FALSE;
    Bool changed = FALSE;

    /* Try to re-set the mode on all the connectors with a BAD link-state:
     * This may happen if a link degrades and a new modeset is necessary, using
     * different link-training parameters. If the kernel found that the current
     * mode is not achievable anymore, it should have pruned the mode before
     * sending the hotplug event. Try to re-set the currently-set mode to keep
     * the display alive, this will fail if the mode has been pruned.
     * In any case, we will send randr events for the Desktop Environment to
     * deal with it, if it wants to.
     */
    for (i = 0; i < config.num_output; i++) {
        xf86OutputPtr output = config.output[i];
        drmmode_output_private_ptr drmmode_output = cast(drmmode_output_private_ptr)output.driver_private;

        drmmode_output_detect(output);

        /* Get an updated view of the properties for the current connector and
         * look for the link-status property
         */
        for (j = 0; j < drmmode_output.num_props; j++) {
            drmmode_prop_ptr p = &drmmode_output.props[j];

            if (!strcmp(p.mode_prop.name.ptr, "link-status")) {
                if (p.value == DRM_MODE_LINK_STATUS_BAD) {
                    xf86CrtcPtr crtc = output.crtc;
                    if (!crtc)
                        continue;

                    /* the connector got a link failure, re-set the current mode */
                    drmmode_set_mode_major(crtc, &crtc.mode, crtc.rotation,
                                           crtc.x, crtc.y);

                    drmModeConnectorPtr mode_output = drmmode_output.mode_output;
                    if (mode_output) {
                        xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                                   "hotplug event: connector %u's link-state is BAD, "
                                   ~ "tried resetting the current mode. You may be left "
                                   ~ "with a black screen if this fails...\n",
                                   mode_output.connector_id);
                    } else {
                        xf86DrvMsg(scrn.scrnIndex, X_WARNING,
                                   "hotplug event: NULL connector's link-state is BAD, "
                                   ~ "tried resetting the current mode. You may be left "
                                   ~ "with a black screen if this fails...\n");
                    }
                }
                break;
            }
        }
    }

    mode_res = drmModeGetResources(drmmode.fd);
    if (!mode_res)
        goto out_;

    if (mode_res.count_crtcs != config.num_crtc) {
        /* this triggers with Zaphod mode where we don't currently support connector hotplug or MST. */
        goto out_free_res;
    }

    /* figure out if we have gotten rid of any connectors
       traverse old output list looking for outputs */
    for (i = 0; i < config.num_output; i++) {
        xf86OutputPtr output = config.output[i];
        drmmode_output_private_ptr drmmode_output = void;

        drmmode_output = cast(drmmode_output_private_rec*)output.driver_private;
        found = FALSE;
        for (j = 0; j < mode_res.count_connectors; j++) {
            if (mode_res.connectors[j] == drmmode_output.output_id) {
                found = TRUE;
                break;
            }
        }
        if (found)
            continue;

        drmModeFreeConnector(drmmode_output.mode_output);
        drmmode_output.mode_output = null;
        drmmode_output.output_id = -1;

        changed = TRUE;
    }

    /* find new output ids we don't have outputs for */
    for (i = 0; i < mode_res.count_connectors; i++) {
        found = FALSE;

        for (j = 0; j < config.num_output; j++) {
            xf86OutputPtr output = config.output[j];
            drmmode_output_private_ptr drmmode_output = void;

            drmmode_output = cast(drmmode_output_private_rec*)output.driver_private;
            if (mode_res.connectors[i] == drmmode_output.output_id) {
                found = TRUE;
                break;
            }
        }
        if (found)
            continue;

        changed = TRUE;
        drmmode_output_init(scrn, drmmode, mode_res, i, TRUE, 0);
    }

    if (changed) {
        RRSetChanged(xf86ScrnToScreen(scrn));
        RRTellChanged(xf86ScrnToScreen(scrn));
    }

out_free_res:

    /* Check to see if a lessee has disappeared */
    drmmode_validate_leases(scrn);

    drmModeFreeResources(mode_res);
out_:
    RRGetInfo(xf86ScrnToScreen(scrn), TRUE);
}

version (CONFIG_UDEV_KMS) {

private void drmmode_handle_uevents(int fd, void* closure)
{
    drmmode_ptr drmmode = closure;
    udev_device* dev = void;
    Bool found = FALSE;

    while ((dev = udev_monitor_receive_device(drmmode.uevent_monitor))) {
        udev_device_unref(dev);
        found = TRUE;
    }
    if (!found)
        return;

    drmmode_update_kms_state(drmmode);
}

}

void drmmode_uevent_init(ScrnInfoPtr scrn, drmmode_ptr drmmode)
{
version (CONFIG_UDEV_KMS) {
    udev* u = void;
    udev_monitor* mon = void;

    u = udev_new();
    if (!u)
        return;
    mon = udev_monitor_new_from_netlink(u, "udev");
    if (!mon) {
        udev_unref(u);
        return;
    }

    if (assumeNoGC(&udev_monitor_filter_add_match_subsystem_devtype)(mon,
                                                        "drm",
                                                        "drm_minor") < 0 ||
        udev_monitor_enable_receiving(mon) < 0) {
        udev_monitor_unref(mon);
        udev_unref(u);
        return;
    }

    drmmode.uevent_handler =
        xf86AddGeneralHandler(udev_monitor_get_fd(mon),
                              &drmmode_handle_uevents, drmmode);

    drmmode.uevent_monitor = mon;
}
}

void drmmode_uevent_fini(ScrnInfoPtr scrn, drmmode_ptr drmmode)
{
version (CONFIG_UDEV_KMS) {
    if (drmmode.uevent_handler) {
        udev* u = udev_monitor_get_udev(drmmode.uevent_monitor);

        xf86RemoveGeneralHandler(drmmode.uevent_handler);

        udev_monitor_unref(drmmode.uevent_monitor);
        udev_unref(u);
    }
}
}

pragma(inline, true) private void drmmode_reset_cursor(drmmode_crtc_private_ptr drmmode_crtc)
{
    /* Mark the entire cursor buffer as dirty */
    drmmode_crtc.cursor_glyph_width = 0;
    drmmode_crtc.cursor_glyph_height = 0;
    drmmode_crtc.old_pitch = 0;

    /* If we had any cursor pitches for the old cursor, they are no longer valid now */
    free(drmmode_crtc.cursor_pitches);
    drmmode_crtc.cursor_pitches = null;
}

/**
 * Some setups have different requirements for the
 * cursor pitch compared to intel and nvidia.
 *
 * See: https://github.com/X11Libre/xserver/issues/1816
 *
 * This function detects whether we are running in a vm,
 * or on bare metal.
 *
 * Driver names are taken from https://drmdb.emersion.fr/drivers
 */
pragma(inline, true) private Bool drmmode_legacy_cursor_probe_allowed(drmmode_ptr drmmode)
{
    drmVersionPtr version_ = drmGetVersion(drmmode.fd);
    if (!version_) {
        return FALSE;
    }

    if (!version_.name ||
        strstr(version_.name, "bochs-drm") ||
        strstr(version_.name, "evdi") ||
        strstr(version_.name, "vboxvideo") ||
        strstr(version_.name, "virtio_gpu") ||
        strstr(version_.name, "vkms") ||
        strstr(version_.name, "vmwgfx")) {
        drmFreeVersion(version_);
        return FALSE;
    }

    drmFreeVersion(version_);
    return TRUE;
}

/*
 * This is the old probe method for the minimum cursor size.
 * This is only used if the SIZE_HINTS probe fails.
 */
private void drmmode_probe_cursor_size(xf86CrtcPtr crtc)
{
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    uint handle = gbm_bo_get_handle(drmmode_crtc.cursor.bo).u32;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;
    drmmode_cursor_ptr drmmode_cursor = &drmmode_crtc.cursor;
    int width = void, height = void, size = void;
    int max_width = void, max_height = void;
    int min_width = void, min_height = void;

    if (drmmode_crtc.cursor_probed) {
        return;
    }

    drmmode_crtc.cursor_probed = TRUE;

    if (!drmmode_legacy_cursor_probe_allowed(drmmode)) {
        return;
    }

    xf86DrvMsg(crtc.scrn.scrnIndex, X_WARNING,
               "Probing the cursor size using the old method\n");

    /* If we're here, we only have one size, the fallback size */
    max_width = drmmode_cursor.dimensions[0].width;
    max_height = drmmode_cursor.dimensions[0].height;

    min_width = max_width;
    min_height = max_height;

    /* probe square min first */
    for (size = 1; size <= max_width &&
             size <= max_height; size *= 2) {
        int ret = void;

        ret = drmModeSetCursor2(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                                handle, size, size, 0, 0);
        if (ret == 0) {
            min_width = size;
            min_height = size;
            break;
        }
    }

    /* check if smaller width works with non-square */
    for (width = 1; width <= size; width *= 2) {
        int ret = void;

        ret = drmModeSetCursor2(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                                handle, width, size, 0, 0);
        if (ret == 0) {
            min_width = width;
            break;
        }
    }

    /* check if smaller height works with non-square */
    for (height = 1; height <= size; height *= 2) {
        int ret = void;

        ret = drmModeSetCursor2(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id,
                                handle, size, height, 0, 0);
        if (ret == 0) {
            min_height = height;
            break;
        }
    }

    drmModeSetCursor2(drmmode.fd, drmmode_crtc.mode_crtc.crtc_id, 0, 0, 0, 0, 0);

    if (min_width == max_width && min_height == max_height) {
        xf86DrvMsgVerb(crtc.scrn.scrnIndex, X_INFO, MS_LOGLEVEL_DEBUG,
                       "Cursor size: %dx%d\n",
                       min_width, min_height);

        return;
    }

    drmmode_reset_cursor(drmmode_crtc);

    /*
     * We could add as many sizes as we want here.
     * We want the minimum size to be here, and we need the maximum size to be here,
     * because that's what we initialize the cursor image with, and we could theoretically
     * get cursor glyph sizes that big.
     *
     * There is no problem with multiple sizes being equal here.
     * We want dimensions[i] <= dimensions[i + 1] for all i, but even if
     * this doesn't happen, there shouldn't be any issues.
     */

    int num_dimensions = 0;
    for (int i = mixin(MIN!(`min_width`, `min_height`)), max = mixin(MAX!(`max_width`, `max_height`)); ; i *= 2) {
        i = mixin(MIN!(`i`, `max`)); /* handle not power of 2 */
        num_dimensions++;
        if (i >= max) {
            break;
        }
    }

    void* tmp = realloc(drmmode_cursor.dimensions, num_dimensions * drmmode_cursor_dim_rec.sizeof);
    if (!tmp) {
        xf86DrvMsgVerb(crtc.scrn.scrnIndex, X_INFO, MS_LOGLEVEL_DEBUG,
                       "Cursor size: %dx%d\n",
                       max_width, max_height);
        return;
    }

    drmmode_cursor.dimensions = cast(drmmode_cursor_dim_rec*)tmp;
    drmmode_cursor.num_dimensions = 0;

enum string CLAMP(string val,string a,string b) = MAX!(`(` ~ a ~ `)`, MIN!(`(` ~ b ~ `)`, `(` ~ val ~ `)`)) ~ ``;

    for (int i = cast(int)mixin(MIN!(`min_width`, `min_height`)), max = cast(int)mixin(MAX!(`max_width`, `max_height`)); ; i *= 2) {
        i = cast(int)mixin(MIN!(`i`, `max`)); /* handle not power of 2 */
        drmmode_cursor.dimensions[drmmode_cursor.num_dimensions].width  = cast(ushort)mixin(CLAMP!(`i`, `min_width`, `max_width`));
        drmmode_cursor.dimensions[drmmode_cursor.num_dimensions].height = cast(ushort)mixin(CLAMP!(`i`, `min_height`, `max_height`));
        drmmode_cursor.num_dimensions++;
        if (i >= max) {
            break;
        }
    }

    xf86DrvMsgVerb(crtc.scrn.scrnIndex, X_INFO, MS_LOGLEVEL_DEBUG,
                   "Minimum cursor size: %dx%d\n",
                   min_width, min_height);
}

/* create front and cursor BOs */
Bool drmmode_create_initial_bos(ScrnInfoPtr pScrn, drmmode_ptr drmmode)
{
    modesettingPtr ms = mixin(modesettingPTR!("pScrn"));
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    int bpp = ms.drmmode.kbpp;
    int cpp = (bpp + 7) / 8;

    int width = void, height = void;
    uint min_width = 1 << 30, min_height = 1 << 30;

    width = pScrn.virtualX;
    height = pScrn.virtualY;

    drmmode.front_bo = gbm_create_best_bo(drmmode, !drmmode.glamor_gbm, width, height, DRMMODE_FRONT_BO);
    if (!drmmode.front_bo) {
        return FALSE;
    }

    pScrn.displayWidth = gbm_bo_get_stride(drmmode.front_bo) / cpp;

    for (int i = 0; i < xf86_config.num_crtc; i++) {
        xf86CrtcPtr crtc = xf86_config.crtc[i];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
        drmmode_cursor_rec cursor = drmmode_crtc.cursor;

        /* If we don't have any dimensions then
         * something has gone terribly wrong. */
        assert(cursor.num_dimensions);

        /* Use the maximum available size. */
        width  = cursor.dimensions[cursor.num_dimensions - 1].width;
        height = cursor.dimensions[cursor.num_dimensions - 1].height;

        /* We take the minimum of the sizes here
         * so that we don't get a cursor glyph larger
         * that a crtc's cursor buffer */
        min_width  = mixin(MIN!(`width`, `min_width`));
        min_height = mixin(MIN!(`height`, `min_height`));

        drmmode_crtc.cursor.bo = gbm_create_best_bo(drmmode, TRUE, width, height, DRMMODE_CURSOR_BO);
        if (!drmmode_crtc.cursor.bo) {
            gbm_bo_destroy(drmmode.front_bo);
            for (int j = 0; j < i; j++) {
                xf86CrtcPtr free_crtc = xf86_config.crtc[j];
                drmmode_crtc_private_ptr free_drmmode_crtc = cast(drmmode_crtc_private_ptr)free_crtc.driver_private;
                gbm_bo_destroy(free_drmmode_crtc.cursor.bo);
                free_drmmode_crtc.cursor.bo = null;
            }
            return FALSE;
        }
    }

    ms.cursor_image_width  = min_width;
    ms.cursor_image_height = min_height;

    return TRUE;
}

void drmmode_free_bos(ScrnInfoPtr pScrn, drmmode_ptr drmmode)
{
    xf86CrtcConfigPtr xf86_config = mixin(XF86_CRTC_CONFIG_PTR!("pScrn"));
    int i = void;

    if (drmmode.fb_id) {
        drmModeRmFB(drmmode.fd, drmmode.fb_id);
        drmmode.fb_id = 0;
    }

    gbm_bo_destroy(drmmode.front_bo);

    for (i = 0; i < xf86_config.num_crtc; i++) {
        xf86CrtcPtr crtc = xf86_config.crtc[i];
        drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;

        gbm_bo_destroy(drmmode_crtc.cursor.bo);
        drmmode_destroy_tearfree_shadow(crtc);
    }
}

/* XXX Do we really need to do this? XXX */
private gbm_bo* drmmode_create_bpp_probe_bo(drmmode_ptr drmmode, uint width, uint height, uint depth, uint bpp, gbm_device** out_gbm_dev)
{
    uint format = drmmode_gbm_format_for_depth(depth);
    gbm_device* gbm_dev = drmmode.gbm;

    *out_gbm_dev = null;
    if (!gbm_dev) {
        gbm_dev = gbm_create_device(drmmode.fd);
        if (!gbm_dev) {
            return null;
        }

        *out_gbm_dev = gbm_dev;
    }

    return gbm_bo_create(gbm_dev, width, height,
                         format, GBM_BO_USE_SCANOUT | GBM_BO_USE_WRITE);
}

/* ugly workaround to see if we can create 32bpp */
void drmmode_get_default_bpp(ScrnInfoPtr pScrn, drmmode_ptr drmmode, int* depth, int* bpp)
{
    drmModeResPtr mode_res = void;
    ulong value = void;
    gbm_device* free_me = null;
    gbm_bo* bo = null;
    uint fb_id = void;
    int ret = void;

    /* 16 is fine */
    ret = drmGetCap(drmmode.fd, DRM_CAP_DUMB_PREFERRED_DEPTH, &value);
    if (!ret && (value == 16 || value == 8)) {
        *depth = cast(int)value;
        *bpp = cast(int)value;
        return;
    }

    *depth = 24;
    *bpp = 32;
    mode_res = drmModeGetResources(drmmode.fd);
    if (!mode_res)
        return;

    if (mode_res.min_width == 0)
        mode_res.min_width = 1;
    if (mode_res.min_height == 0)
        mode_res.min_height = 1;
    /*create a bo */
    bo = drmmode_create_bpp_probe_bo(drmmode, mode_res.min_width, mode_res.min_height,
                                     *depth, *bpp, &free_me);

    if (!bo) {
        *bpp = 24;
        goto out_;
    }

    ret = drmModeAddFB(drmmode.fd, mode_res.min_width, mode_res.min_height,
                       cast(ubyte)*depth, cast(ubyte)*bpp, gbm_bo_get_stride(bo), gbm_bo_get_handle(bo).s32, &fb_id);

    if (ret) {
        *bpp = 24;
        goto out_;
    }

    drmModeRmFB(drmmode.fd, fb_id);

out_:
    if (bo) {
        gbm_bo_destroy(bo);
    }

    if (free_me) {
        gbm_device_destroy(free_me);
    }
    drmModeFreeResources(mode_res);
    return;
}

void drmmode_crtc_set_vrr(xf86CrtcPtr crtc, Bool enabled)
{
    ScrnInfoPtr pScrn = crtc.scrn;
    modesettingPtr ms = mixin(modesettingPTR!("pScrn"));
    drmmode_crtc_private_ptr drmmode_crtc = cast(drmmode_crtc_private_ptr)crtc.driver_private;
    drmmode_ptr drmmode = drmmode_crtc.drmmode;

    if (drmmode.vrr_prop_id && drmmode_crtc.vrr_enabled != enabled &&
        drmModeObjectSetProperty(ms.fd,
                                 drmmode_crtc.mode_crtc.crtc_id,
                                 DRM_MODE_OBJECT_CRTC,
                                 drmmode.vrr_prop_id,
                                 enabled) == 0)
        drmmode_crtc.vrr_enabled = enabled;
}

/*
 * We hook the screen's cursor-sprite (swcursor) functions to see if a swcursor
 * is active. When a swcursor is active we disable page-flipping.
 */

private void drmmode_sprite_do_set_cursor(msSpritePrivPtr sprite_priv, ScrnInfoPtr scrn, int x, int y)
{
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    CursorPtr cursor = sprite_priv.cursor;
    Bool sprite_visible = sprite_priv.sprite_visible;

    if (cursor) {
        x -= cursor.bits.xhot;
        y -= cursor.bits.yhot;

        sprite_priv.sprite_visible =
            x < scrn.virtualX && y < scrn.virtualY &&
            (x + cursor.bits.width > 0) &&
            (y + cursor.bits.height > 0);
    } else {
        sprite_priv.sprite_visible = FALSE;
    }

    ms.drmmode.sprites_visible += sprite_priv.sprite_visible - sprite_visible;
}

private void drmmode_sprite_set_cursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor, int x, int y)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    msSpritePrivPtr sprite_priv = cast(msSpritePrivPtr)mixin(msGetSpritePriv!("pDev", "ms", "pScreen"));

    sprite_priv.cursor = pCursor;
    drmmode_sprite_do_set_cursor(sprite_priv, scrn, x, y);

    ms.SpriteFuncs.SetCursor(pDev, pScreen, pCursor, x, y);
}

private void drmmode_sprite_move_cursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));
    msSpritePrivPtr sprite_priv = cast(msSpritePrivPtr)mixin(msGetSpritePriv!("pDev", "ms", "pScreen"));

    drmmode_sprite_do_set_cursor(sprite_priv, scrn, x, y);

    ms.SpriteFuncs.MoveCursor(pDev, pScreen, x, y);
}

private Bool drmmode_sprite_realize_realize_cursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    return ms.SpriteFuncs.RealizeCursor(pDev, pScreen, pCursor);
}

private Bool drmmode_sprite_realize_unrealize_cursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    return ms.SpriteFuncs.UnrealizeCursor(pDev, pScreen, pCursor);
}

private Bool drmmode_sprite_device_cursor_initialize(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    return ms.SpriteFuncs.DeviceCursorInitialize(pDev, pScreen);
}

private void drmmode_sprite_device_cursor_cleanup(DeviceIntPtr pDev, ScreenPtr pScreen)
{
    ScrnInfoPtr scrn = xf86ScreenToScrn(pScreen);
    modesettingPtr ms = mixin(modesettingPTR!("scrn"));

    ms.SpriteFuncs.DeviceCursorCleanup(pDev, pScreen);
}

miPointerSpriteFuncRec drmmode_sprite_funcs = {
    RealizeCursor: &drmmode_sprite_realize_realize_cursor,
    UnrealizeCursor: &drmmode_sprite_realize_unrealize_cursor,
    SetCursor: &drmmode_sprite_set_cursor,
    MoveCursor: &drmmode_sprite_move_cursor,
    DeviceCursorInitialize: &drmmode_sprite_device_cursor_initialize,
    DeviceCursorCleanup: &drmmode_sprite_device_cursor_cleanup,
};
