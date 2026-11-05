module dri3.dri3;
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
import build.xlibre_server;
import Xext.panoramiXsrv;
import dix.screen_hooks_priv;
import dix.screenint_priv;
import miext.extinit_priv;

import dri3.dri3_priv;
// import externs.libdrm;;
import dix.extension;
import dix.resource;
import os.log;
import externs.X11.extensions.dri3proto;
// import externs.drm_fourcc;
import externs.libdrm;;
import dix.screen_hooks;



private int dri3_request;
// DevPrivateKeyRec dri3_screen_private_key;

public import randr.randr;

enum DRI3_SCREEN_INFO_VERSION =        4;

struct dri3_syncobj
{
    XID id;
    ScreenPtr screen;
    uint refcount;

    void function(dri3_syncobj* syncobj) @nogc nothrow free;
    Bool function(dri3_syncobj* syncobj, ulong point) @nogc nothrow has_fence;
    Bool function(dri3_syncobj* syncobj, ulong point) @nogc nothrow is_signaled;
    int function(dri3_syncobj* syncobj, ulong point) @nogc nothrow export_fence;
    void function(dri3_syncobj* syncobj, ulong point, int fd) @nogc nothrow import_fence;
    void function(dri3_syncobj* syncobj, ulong point) @nogc nothrow signal;
    void function(dri3_syncobj* syncobj, ulong point, int efd) @nogc nothrow submitted_eventfd;
    void function(dri3_syncobj* syncobj, ulong point, int efd) @nogc nothrow signaled_eventfd;
}

alias dri3_open_proc = int function(ScreenPtr screen, RRProviderPtr provider, int* fd);

alias dri3_open_client_proc = int function(ClientPtr client, ScreenPtr screen, RRProviderPtr provider, int* fd);

alias dri3_pixmap_from_fd_proc = PixmapPtr function(ScreenPtr screen, int fd, CARD16 width, CARD16 height, CARD16 stride, CARD8 depth, CARD8 bpp);

alias dri3_pixmap_from_fds_proc = PixmapPtr function(ScreenPtr screen, CARD8 num_fds, const(int)* fds, CARD16 width, CARD16 height, const(CARD32)* strides, const(CARD32)* offsets, CARD8 depth, CARD8 bpp, CARD64 modifier);

alias dri3_fd_from_pixmap_proc = int function(ScreenPtr screen, PixmapPtr pixmap, CARD16* stride, CARD32* size);

alias dri3_fds_from_pixmap_proc = int function(ScreenPtr screen, PixmapPtr pixmap, int* fds, uint* strides, uint* offsets, ulong* modifier);

alias dri3_get_formats_proc = int function(ScreenPtr screen, CARD32* num_formats, CARD32** formats);

alias dri3_get_modifiers_proc = int function(ScreenPtr screen, uint format, uint* num_modifiers, ulong** modifiers);

alias dri3_get_drawable_modifiers_proc = int function(DrawablePtr draw, uint format, uint* num_modifiers, ulong** modifiers);

alias dri3_import_syncobj_proc = dri3_syncobj* function(ClientPtr client, ScreenPtr screen, XID id, int fd);

struct dri3_screen_info {
    uint version_;

    dri3_open_proc open;
    dri3_pixmap_from_fd_proc pixmap_from_fd;
    dri3_fd_from_pixmap_proc fd_from_pixmap;

    /* Version 1 */
    dri3_open_client_proc open_client;

    /* Version 2 */
    dri3_pixmap_from_fds_proc pixmap_from_fds;
    dri3_fds_from_pixmap_proc fds_from_pixmap;
    dri3_get_formats_proc get_formats;
    dri3_get_modifiers_proc get_modifiers;
    dri3_get_drawable_modifiers_proc get_drawable_modifiers;

    /* Version 4 */
    dri3_import_syncobj_proc import_syncobj;

}alias dri3_screen_info_rec = dri3_screen_info;
alias dri3_screen_info_ptr = dri3_screen_info*;

private x_server_generation_t dri3_screen_generation;

private void dri3_screen_close(CallbackListPtr* pcbl, ScreenPtr screen, void* unused)
{
    dri3_screen_priv_ptr screen_priv = dri3_screen_priv(screen);

    if (screen_priv && screen_priv.formats && screen_priv.formats_cached) {
        for (int i = 0; i < screen_priv.num_formats; i++) {
            free(screen_priv.formats[i].modifiers);
        }
        free(screen_priv.formats);
    }
    free(screen_priv);

    dixScreenUnhookClose(screen, &dri3_screen_close);
}

Bool dri3_screen_init(ScreenPtr screen, const(dri3_screen_info_rec)* info)
{
    dri3_screen_generation = serverGeneration;

    if (!dixRegisterPrivateKey(&dri3_screen_private_key, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!dri3_screen_priv(screen)) {
        dri3_screen_priv_ptr screen_priv = cast(dri3_screen_priv_rec*) calloc(1, dri3_screen_priv_rec.sizeof);
        if (!screen_priv)
            return FALSE;

        dixScreenHookClose(screen, &dri3_screen_close);

        dixSetPrivate(&screen.devPrivates, &dri3_screen_private_key, screen_priv);
    }

    if (info)
        dri3_screen_priv(screen).info = info;

    return TRUE;
}

// RESTYPE dri3_syncobj_type;

private int dri3_syncobj_free(void* data, XID id)
{
    dri3_syncobj* syncobj = cast(dri3_syncobj* )data;
    if (--syncobj.refcount == 0)
        syncobj.free(syncobj);
    return 0;
}

void dri3_extension_init()
{
    ExtensionEntry* extension = void;

    /* If no screens support DRI3, there's no point offering the
     * extension at all
     */
    if (dri3_screen_generation != serverGeneration)
        return;

static if(XINERAMA){
    if (!noPanoramiXExtension)
        return;
} /* XINERAMA */

    extension = AddExtension(DRI3_NAME, DRI3NumberEvents, DRI3NumberErrors,
                             &proc_dri3_dispatch, &proc_dri3_dispatch,
                             null, &StandardMinorOpcode);
    if (!extension)
        goto bail;

    dri3_request = extension.base;

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (!dri3_screen_init(walkScreen, null))
            goto bail;
    });

    dri3_syncobj_type = CreateNewResourceType(&dri3_syncobj_free, "DRI3Syncobj");
    if (!dri3_syncobj_type)
        goto bail;

    return;

bail:
    FatalError("Cannot initialize DRI3 extension");
}

uint drm_format_for_depth(uint depth, uint bpp)
{
    switch (bpp) {
        case 16:
            return DRM_FORMAT_RGB565;
        case 24:
            return DRM_FORMAT_XRGB8888;
        case 30:
            return DRM_FORMAT_XRGB2101010;
        case 32:
            return DRM_FORMAT_ARGB8888;
        default:
            return 0;
    }
}
