module dri3_screen;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Keith Packard
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

import core.stdc.assert_;
// import externs.libdrm;;
import core.sys.posix.unistd;

import Xext.sync;

import dri3.dri3_priv;
import mi.misync;
import randr.randr;
import externs.libdrm;;
import dix.resource;

int dri3_open(ClientPtr client, ScreenPtr screen, RRProviderPtr provider, int* fd)
{
    dri3_screen_priv_ptr ds = dri3_screen_priv(screen);
    const(dri3_screen_info_rec)* info = ds.info;

    if (info is null)
        return BadMatch;

    if (info.version_ >= 1 && info.open_client !is null)
        return (*info.open_client) (client, screen, provider, fd);
    if (info.open !is null)
        return (*info.open) (screen, provider, fd);

    return BadMatch;
}

int dri3_pixmap_from_fds(PixmapPtr* ppixmap, ScreenPtr screen, CARD8 num_fds, const(int)* fds, CARD16 width, CARD16 height, const(CARD32)* strides, const(CARD32)* offsets, CARD8 depth, CARD8 bpp, CARD64 modifier)
{
    dri3_screen_priv_ptr ds = dri3_screen_priv(screen);
    const(dri3_screen_info_rec)* info = ds.info;
    PixmapPtr pixmap = void;

    if (!info)
        return BadImplementation;

    if (info.version_ >= 2 && info.pixmap_from_fds !is null) {
        pixmap = (*info.pixmap_from_fds) (screen, num_fds, fds, width, height,
                                           strides, offsets, depth, bpp, modifier);
    } else if (info.pixmap_from_fd !is null && num_fds == 1) {
        pixmap = (*info.pixmap_from_fd) (screen, fds[0], width, height,
                                          cast(ushort)strides[0], depth, bpp);
    } else {
        return BadImplementation;
    }

    if (!pixmap)
        return BadAlloc;

    *ppixmap = pixmap;
    return Success;
}

int dri3_fds_from_pixmap(PixmapPtr pixmap, int* fds, uint* strides, uint* offsets, ulong* modifier)
{
    ScreenPtr screen = pixmap.drawable.pScreen;
    dri3_screen_priv_ptr ds = dri3_screen_priv(screen);
    const(dri3_screen_info_rec)* info = ds.info;

    if (!info)
        return 0;

    if (info.version_ >= 2 && info.fds_from_pixmap !is null) {
        return (*info.fds_from_pixmap)(screen, pixmap, fds, strides, offsets,
                                        modifier);
    } else if (info.fd_from_pixmap !is null) {
        CARD16 stride = void;
        CARD32 size = void;

        fds[0] = (*info.fd_from_pixmap)(screen, pixmap, &stride, &size);
        if (fds[0] < 0)
            return 0;

        strides[0] = stride;
        offsets[0] = 0;
        *modifier = DRM_FORMAT_MOD_INVALID;
        return 1;
    } else {
        return 0;
    }
}

int dri3_fd_from_pixmap(PixmapPtr pixmap, CARD16* stride, CARD32* size)
{
    ScreenPtr screen = pixmap.drawable.pScreen;
    dri3_screen_priv_ptr ds = dri3_screen_priv(screen);
    const(dri3_screen_info_rec)* info = ds.info;
    uint[4] strides = void;
    uint[4] offsets = void;
    ulong modifier = void;
    int[4] fds = void;
    int num_fds = void;

    if (!info)
        return -1;

    /* Preferentially use the old interface, allowing the implementation to
     * ensure the buffer is in a single-plane format which doesn't need
     * modifiers. */
    if (info.fd_from_pixmap !is null)
        return (*info.fd_from_pixmap)(screen, pixmap, stride, size);

    if (info.version_ < 2 || info.fds_from_pixmap is null)
        return -1;

    /* If using the new interface, make sure that it's a single plane starting
     * at 0 within the BO. We don't check the modifier, as the client may
     * have an auxiliary mechanism for determining the modifier itself. */
    num_fds = info.fds_from_pixmap(screen, pixmap, fds.ptr, strides.ptr, offsets.ptr,
                                    &modifier);
    if (num_fds != 1 || offsets[0] != 0) {
        assert(num_fds <= 4);
        for (int i = 0; i < num_fds; i++)
            close(fds[i]);
        return -1;
    }

    *stride = cast(ushort)strides[0];
    *size = size[0];
    return fds[0];
}

private int cache_formats_and_modifiers(ScreenPtr screen)
{
    dri3_screen_priv_ptr ds = dri3_screen_priv(screen);
    const(dri3_screen_info_rec)* info = ds.info;
    CARD32 num_formats = void;
    CARD32* formats = void;
    uint num_modifiers = void;
    ulong* modifiers = void;
    int i = void;

    if (ds.formats_cached)
        return Success;

    if (!info)
        return BadImplementation;

    if (info.version_ < 2 || !info.get_formats || !info.get_modifiers) {
        ds.formats = null;
        ds.num_formats = 0;
        ds.formats_cached = True;
        return Success;
    }

    if (!info.get_formats(screen, &num_formats, &formats))
        return BadAlloc;

    if (!num_formats) {
        ds.num_formats = 0;
        ds.formats_cached = True;
        return Success;
    }

    ds.formats = cast(dri3_dmabuf_format*)calloc(num_formats, dri3_dmabuf_format_rec.sizeof);
    if (!ds.formats) {
        free(formats);
        return BadAlloc;
    }

    for (i = 0; i < num_formats; i++) {
        dri3_dmabuf_format_ptr iter = &ds.formats[i];

        if (!info.get_modifiers(screen, cast(uint)formats[i],
                                 &num_modifiers,
                                 &modifiers))
            continue;

        if (!num_modifiers)
            continue;

        iter.format = cast(uint)formats[i];
        iter.num_modifiers = num_modifiers;
        iter.modifiers = modifiers;
    }

    ds.num_formats = i;
    ds.formats_cached = True;

    free(formats);
    return Success;
}

int dri3_get_supported_modifiers(ScreenPtr screen, DrawablePtr drawable, CARD8 depth, CARD8 bpp, CARD32* num_drawable_modifiers, CARD64** drawable_modifiers, CARD32* num_screen_modifiers, CARD64** screen_modifiers)
{
    dri3_screen_priv_ptr ds = dri3_screen_priv(screen);
    const(dri3_screen_info_rec)* info = ds.info;
    int i = void;
    int ret = void;
    uint num_drawable_mods = void;
    ulong* drawable_mods = void;
    CARD64* screen_mods = null;
    CARD32 format = void;
    dri3_dmabuf_format_ptr screen_format = null;

    ret = cache_formats_and_modifiers(screen);
    if (ret != Success)
        return ret;

    format = drm_format_for_depth(depth, bpp);
    if (format == 0)
        return BadValue;

    /* Find screen-global modifiers from cache
     */
    for (i = 0; i < ds.num_formats; i++) {
        if (ds.formats[i].format == format) {
            screen_format = &ds.formats[i];
            break;
        }
    }
    if (screen_format is null)
        return BadMatch;

    if (screen_format.num_modifiers == 0) {
        *num_screen_modifiers = 0;
        *num_drawable_modifiers = 0;
        return Success;
    }

    /* copy the screen mods so we can return an owned allocation */
    screen_mods = cast(ulong*)XNFalloc(screen_format.num_modifiers * CARD64.sizeof);
    memcpy(screen_mods, screen_format.modifiers,
           screen_format.num_modifiers * CARD64.sizeof);

    if (!info.get_drawable_modifiers ||
        !info.get_drawable_modifiers(drawable, cast(uint)format,
                                      &num_drawable_mods,
                                      &drawable_mods)) {
        num_drawable_mods = 0;
        drawable_mods = null;
    }

    *num_drawable_modifiers = num_drawable_mods;
    *drawable_modifiers = drawable_mods;

    *num_screen_modifiers = screen_format.num_modifiers;
    *screen_modifiers = screen_mods;

    return Success;
}

int dri3_import_syncobj(ClientPtr client, ScreenPtr screen, XID id, int fd)
{
    const(dri3_screen_info_rec)* info = dri3_screen_priv(screen).info;
    dri3_syncobj* syncobj = null;

    if (info.version_ < 4 || !info.import_syncobj)
        return BadImplementation;

    syncobj = info.import_syncobj(client, screen, id, fd);
    close(fd);

    if (!syncobj)
        return BadAlloc;

    if (!AddResource(cast(uint)id, dri3_syncobj_type, syncobj))
        return BadAlloc;

    return Success;
}
