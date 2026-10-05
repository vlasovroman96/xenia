module hw.xfree86.drivers.video.modesetting.drmmode_bo;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026 stefan11111 <stefan11111@shitposting.expert>
 */

import core.stdc.stddef;
import core.stdc.stdint;

import build.dix_config;

import include.dix; /* ARRAY_SIZE() */

import dix.dix_priv;

// import externs.libdrm;;
// import externs.libdrm; 
// import externs.libdrm;_mode;
import externs.libdrm;

import externs.libdrm;;
import include.xf86Crtc;

import hw.xfree86.drivers.video.modesetting.driver;
import hw.xfree86.drivers.video.modesetting.drmmode_bo;
import std.array;
import hw.xfree86.drivers.video.modesetting.drmmode_display;

enum {
    GBM_FORMAT_RGB565      = 0x36314752, // 'R' 'G' '1' '6' little-endian
    GBM_FORMAT_XRGB8888     = 0x34325258, // 'X' 'R' '2' '4'
    GBM_FORMAT_ARGB8888     = 0x34325241, // 'A' 'R' '2' '4'
    GBM_FORMAT_ARGB2101010  = 0x30335241, // 'A' 'R' '3' '0'
    GBM_FORMAT_ARGB1555     = 0x35315241, // 'A' 'R' '1' '5' (мы уже нашли)
}

// struct _drmmode_rec;
// alias drmmode_ptr = _drmmode_rec*;


struct bo_priv_t {
    void* map_data; /* Opaque ptr for the mapped region */
    void* map_addr; /* Address of the map, what we actually want to use */
    Bool used_modifiers;
}

static if (GBM_HAVE_BO_USE_LINEAR) {} else {
enum GBM_BO_USE_LINEAR = 0;
}

static if (GBM_HAVE_BO_USE_FRONT_RENDERING) {} else {
enum GBM_BO_USE_FRONT_RENDERING = 0;
}

enum GBM_MAX_PLANES = 4;


/**
 * Thin wrapper around gbm_bo_{create,map,unmap}
 * that creates and maps (if necessary) the "best"
 * buffer of a certain type that we can create.
 *
 * Any needed mapping is done when creating the buffer,
 * and unmapping is handeled automatically by the gbm
 * loader through the destroy_user_data callback.
 */
enum uint GBM_FORMAT_R8 = 0x20203852; 
uint
drmmode_gbm_format_for_depth(int depth)
{
    switch (depth) {
    case 8:
        return GBM_FORMAT_R8;
    case 15:
        return GBM_FORMAT_ARGB1555;
    case 16:
        return GBM_FORMAT_RGB565;
    case 24:
        return GBM_FORMAT_XRGB8888;
    case 30:
        /* XXX Is this format right? https://github.com/X11Libre/xserver/pull/1396/files#r2523698616 XXX */
        return GBM_FORMAT_ARGB2101010;
    case 32:
        return GBM_FORMAT_ARGB8888;
    default: break;
    }

    /* Unsupported depth */
    return GBM_FORMAT_ARGB8888;
}

enum string TRY_CREATE(string proc, string data, string do_map, string[] args) = ` {
    gbm_bo* ret = ` ~ proc ~ `(` ~ args.join(", ") ~ `);
    if (ret && (!(` ~ do_map ~ `) ||
                gbm_bo_map_or_free(ret, (` ~ data ~ `)))) {
        return ret;
    }}`;
pragma(inline, true) private uint get_opaque_format(uint format)
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

private void destroy_user_data(gbm_bo* bo, void* _data)
{
    bo_priv_t* data = cast(bo_priv_t*)_data;
    if (!data) {
        return;
    }

    if (data.map_data) {
        gbm_bo_unmap(bo, data.map_data);
    }
    free(data);
}

void* gbm_bo_get_map(gbm_bo* bo)
{
    bo_priv_t* data = cast(bo_priv_t*)gbm_bo_get_user_data(bo);
    return data ? data.map_addr : null;
}

Bool gbm_bo_get_used_modifiers(gbm_bo* bo)
{
    bo_priv_t* data = cast(bo_priv_t*)gbm_bo_get_user_data(bo);
    return data ? data.used_modifiers : FALSE;
}

pragma(inline, true) private Bool gbm_bo_map_all(gbm_bo* bo, bo_priv_t* data)
{
    uint stride = 0;

    if (!bo || !data) {
        return FALSE;
    }

    if (data.map_addr) {
        return TRUE;
    }

    uint width = gbm_bo_get_width(bo);
    uint height = gbm_bo_get_height(bo);

    /* must be NULL before the map call */
    data.map_data = null;

    /* While reading from gpu memory is often very slow, we do allow it */
    data.map_addr = gbm_bo_map(bo, 0, 0, width, height,
                                GBM_BO_TRANSFER_READ_WRITE,
                                &stride, &data.map_data);

    return !!data.map_addr;
}

pragma(inline, true) private Bool gbm_bo_map_or_free(gbm_bo* bo, bo_priv_t* data)
{
    if (gbm_bo_map_all(bo, data)) {
        return TRUE;
    }

    if (bo) {
        gbm_bo_destroy(bo);
    }
    return FALSE;
}

pragma(inline, true) private gbm_bo* gbm_bo_create_and_map(gbm_device* gbm, bo_priv_t* data, Bool do_map, uint width, uint height, uint format, const(ulong)* modifiers, const(uint) count, uint flags)
{
    if (!data) {
        return null;
    }

static if (GBM_BO_WITH_MODIFIERS) {
    if (count && modifiers) {
        data.used_modifiers = TRUE;
static if (GBM_BO_WITH_MODIFIERS2) {
        mixin(TRY_CREATE!(`gbm_bo_create_with_modifiers2`, `data`, `do_map`,
                   [`gbm`, `width`, `height`, `format`, `modifiers`, `count`, `flags`]));
}
        mixin(TRY_CREATE!(`gbm_bo_create_with_modifiers`, `data`, `do_map`,
                   [`gbm`, `width`, `height`, `format`, `modifiers`, `count`]));
    }
}

    data.used_modifiers = FALSE;
    mixin(TRY_CREATE!(`gbm_bo_create`, `data`, `do_map`,
    [`gbm`, `width`, `height`, `format`, `flags`]));
    return null;
}

pragma(inline, true) private gbm_bo* gbm_bo_create_and_map_with_flag_list(gbm_device* gbm, bo_priv_t* data, Bool do_map, uint width, uint height, uint format, const(ulong)* modifiers, const(uint) count, const(uint)* flag_list, uint flag_count)
{
    gbm_bo* ret = null;
    for (uint i = 0; i < flag_count && !ret; i++) {
        ret = gbm_bo_create_and_map(gbm, data, do_map,
                                    width, height, format,
                                    modifiers, count,
                                    flag_list[i]);
    }

    return ret;
}

pragma(inline, true) private gbm_bo* gbm_create_front_bo(drmmode_ptr drmmode, Bool do_map, bo_priv_t* data, uint width, uint height)
{
    gbm_bo* ret = null;
    uint format = drmmode_gbm_format_for_depth(drmmode.scrn.depth);

    uint num_modifiers = 0;
    ulong* modifiers = null;

    static const(uint)[5] front_flag_list = [ /* best flags */
                                                GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT |
                                                GBM_BO_USE_FRONT_RENDERING,

                                                /* if front_rendering is unsupported */
                                                GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT,

                                                /* linear buffers */
                                                GBM_BO_USE_LINEAR | GBM_BO_USE_SCANOUT |
                                                GBM_BO_USE_FRONT_RENDERING,

                                                GBM_BO_USE_WRITE | GBM_BO_USE_SCANOUT,
                                              ];

static if (GBM_BO_WITH_MODIFIERS) {
    num_modifiers = get_modifiers_set(drmmode.scrn, format, &modifiers,
                                      FALSE, TRUE, TRUE);
}

    ret = gbm_bo_create_and_map_with_flag_list(drmmode.gbm,
                                               data,
                                               do_map,
                                               width, height,
                                               format,
                                               modifiers, num_modifiers,
                                               front_flag_list.ptr,
                                               mixin(ARRAY_SIZE!("front_flag_list")));

static if (GBM_BO_WITH_MODIFIERS) {
    free(modifiers);
}

    return ret;
}
pragma(inline, true) private gbm_bo* gbm_create_cursor_bo(drmmode_ptr drmmode, Bool do_map, bo_priv_t* data, uint width, uint height)
{
    static const(uint)[5] cursor_flag_list = [ /* best flags */
// #if 0 /* Seems to have issues for now */
//                                                  GBM_BO_USE_CURSOR,
// #endif

// #if 0 /* Use these ones too if we ever need to */
//                                                  GBM_BO_USE_CURSOR | GBM_BO_USE_LINEAR,
//                                                  GBM_BO_USE_LINEAR,
// #endif

                                                /* For older mesa */
                                                 GBM_BO_USE_CURSOR | GBM_BO_USE_WRITE,
                                               ];

    /* Assume whatever bpp we have for the primary plane, we also have for the cursor plane */
    int bpp = drmmode.kbpp;

    /**
     * Assume the depth for the cursor is the same as the bpp,
     * even if this is not true for the primary plane (e.g., even if bpp is 32, but drmmode->scrn->depth is 24).
     */
    uint format = drmmode_gbm_format_for_depth(bpp);

    return gbm_bo_create_and_map_with_flag_list(drmmode.gbm,
                                                data,
                                                do_map,
                                                width, height,
                                                format,
                                                null, 0,
                                                cursor_flag_list.ptr,
                                                mixin(ARRAY_SIZE!("cursor_flag_list")));
}

gbm_bo* gbm_create_best_bo(drmmode_ptr drmmode, Bool do_map, uint width, uint height, int type)
{
    gbm_bo* ret = null;
    bo_priv_t* data = cast(bo_priv_t*) calloc(1, bo_priv_t.sizeof);
    if (!data) {
        return null;
    }

    switch (type) {
    case DRMMODE_FRONT_BO:
        ret = gbm_create_front_bo(drmmode, do_map, data, width, height);
        break;
    case DRMMODE_CURSOR_BO:
        ret = gbm_create_cursor_bo(drmmode, do_map, data, width, height);
        break;
    default: break;}

    if (!ret) {
        free(data);
        return null;
    }

    gbm_bo_set_user_data(ret, data, &destroy_user_data);
    return ret;
}

/* dmabuf import */
gbm_bo* gbm_back_bo_from_fd(drmmode_ptr drmmode, Bool do_map, int fd_handle, uint pitch, uint size)
{
    /* pitch == width * cpp */
    int width = pitch / drmmode.cpp;
    /* size == pitch * height */
    int height = size / pitch;

    int depth = drmmode.scrn.depth > 0 ?
                drmmode.scrn.depth : drmmode.kbpp;

    uint format = drmmode_gbm_format_for_depth(depth);

    gbm_import_fd_data import_data = {fd: fd_handle,
                                             width: width,
                                             height: height,
                                             stride: pitch,
                                             format: format,
                                            };

    bo_priv_t* data = cast(bo_priv_t*) calloc(1, bo_priv_t.sizeof);
    if (!data) {
        return null;
    }

    data.used_modifiers = FALSE;

    mixin(TRY_CREATE!(`gbm_bo_import`, `data`, `do_map`,
               [`drmmode.gbm`, `GBM_BO_IMPORT_FD`, `&import_data`,
               `GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT`]));

    mixin(TRY_CREATE!(`gbm_bo_import`, `data`, `do_map`,
               [`drmmode.gbm`, `GBM_BO_IMPORT_FD`, `&import_data`,
               `GBM_BO_USE_RENDERING | GBM_BO_USE_SCANOUT | GBM_BO_USE_WRITE`]));

    return null;
}

/* A bit of a misnomer, this is a dmabuf export */
int drmmode_bo_import(drmmode_ptr drmmode, gbm_bo* bo, uint* fb_id)
{
    uint width = gbm_bo_get_width(bo);
    uint height = gbm_bo_get_height(bo);

static if (GBM_BO_WITH_MODIFIERS) {
    modesettingPtr ms = mixin(modesettingPTR!("drmmode.scrn"));
    if (bo && ms.kms_has_modifiers &&
        gbm_bo_get_modifier(bo) != DRM_FORMAT_MOD_INVALID) {
        int num_fds = void;

        num_fds = gbm_bo_get_plane_count(bo);
        if (num_fds > 0) {
            int i = void;
            uint format = void;
            uint[GBM_MAX_PLANES] handles = 0;
            uint[GBM_MAX_PLANES] strides = 0;
            uint[GBM_MAX_PLANES] offsets = 0;
            ulong[GBM_MAX_PLANES] modifiers = 0;

            format = gbm_bo_get_format(bo);
            format = get_opaque_format(format);
            for (i = 0; i < num_fds; i++) {
                handles[i] = gbm_bo_get_handle_for_plane(bo, i).u32;
                strides[i] = gbm_bo_get_stride_for_plane(bo, i);
                offsets[i] = gbm_bo_get_offset(bo, i);
                modifiers[i] = gbm_bo_get_modifier(bo);
            }

            return drmModeAddFB2WithModifiers(drmmode.fd, width, height,
                                              format, handles.ptr, strides.ptr,
                                              offsets.ptr, modifiers.ptr, fb_id,
                                              DRM_MODE_FB_MODIFIERS);
        }
    }
}
    return drmModeAddFB(drmmode.fd, width, height,
                        cast(ubyte)drmmode.scrn.depth, cast(ubyte)drmmode.kbpp,
                        gbm_bo_get_stride(bo),
                        gbm_bo_get_handle(bo).u32, fb_id);
}
