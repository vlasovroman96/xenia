module dri3_request;
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

import core.sys.posix.unistd;

import dix.dix_priv;
import dix.request_priv;
import dix.screenint_priv;
import os.client_priv;

import dri3.dri3_priv;
import Xext.syncsrv;
import Xext.xace;
import common.protocol_versions;
// import externs.libdrm;;
import randr.randrstr_priv;
import dix.dixstruct_priv;
import externs.X11.extensions.dri3proto;
import os.io;
import externs.libdrm;;
import Xext.sync;
import common.swap;

private Bool dri3_screen_can_one_point_one(ScreenPtr screen)
{
    dri3_screen_priv_ptr dri3 = dri3_screen_priv(screen);

    if (dri3 && dri3.info && dri3.info.version_ >= 1 &&
        dri3.info.fd_from_pixmap)
        return TRUE;

    return FALSE;
}

private Bool dri3_screen_can_one_point_two(ScreenPtr screen)
{
    dri3_screen_priv_ptr dri3 = dri3_screen_priv(screen);

    if (dri3 && dri3.info && dri3.info.version_ >= 2 &&
        dri3.info.pixmap_from_fds && dri3.info.fds_from_pixmap &&
        dri3.info.get_formats && dri3.info.get_modifiers &&
        dri3.info.get_drawable_modifiers)
        return TRUE;

    return FALSE;
}

private Bool dri3_screen_can_one_point_four(ScreenPtr screen)
{
    dri3_screen_priv_ptr dri3 = dri3_screen_priv(screen);

    return dri3 &&
        dri3.info &&
        dri3.info.version_ >= 4 &&
        dri3.info.import_syncobj;
}

private int proc_dri3_query_version(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3QueryVersionReq);
    mixin(X_REQUEST_FIELD_CARD32!"majorVersion");
    mixin(X_REQUEST_FIELD_CARD32!"minorVersion");

    xDRI3QueryVersionReply reply = {
        majorVersion: SERVER_DRI3_MAJOR_VERSION,
        minorVersion: SERVER_DRI3_MINOR_VERSION
    };

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (!dri3_screen_can_one_point_one(walkScreen)) {
            reply.minorVersion = 0;
            break;
        }
        if (!dri3_screen_can_one_point_two(walkScreen)) {
            reply.minorVersion = 1;
            break;
        }
        if (!dri3_screen_can_one_point_four(walkScreen)) {
            reply.minorVersion = 2;
            break;
        } else {
            reply.minorVersion = 4;
            break;
        }
    });

    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        if (!dri3_screen_can_one_point_one(walkScreen)) {
            reply.minorVersion = 0;
            break;
        }
        if (!dri3_screen_can_one_point_two(walkScreen)) {
            reply.minorVersion = 1;
            break;
        }
        if (!dri3_screen_can_one_point_four(walkScreen)) {
            reply.minorVersion = 2;
            break;
        } else {
            reply.minorVersion = 4;
            break;
        }
    }"));

    /* From DRI3 proto:
     *
     * The client sends the highest supported version to the server
     * and the server sends the highest version it supports, but no
     * higher than the requested version.
     */

    if (reply.majorVersion > stuff.majorVersion ||
        (reply.majorVersion == stuff.majorVersion &&
         reply.minorVersion > stuff.minorVersion)) {
        reply.majorVersion = stuff.majorVersion;
        reply.minorVersion = stuff.minorVersion;
    }

    mixin(X_REPLY_FIELD_CARD32!"majorVersion");
    mixin(X_REPLY_FIELD_CARD32!"minorVersion");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int dri3_send_open_reply(ClientPtr client, int fd)
{
    xDRI3OpenReply reply = {
        nfd: 1,
    };

    if (WriteFdToClient(client, fd, TRUE) < 0) {
        close(fd);
        return BadAlloc;
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int proc_dri3_open(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3OpenReq);
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"provider");

    RRProviderPtr provider = void;
    DrawablePtr drawable = void;
    ScreenPtr screen = void;
    int fd = void;
    int status = void;

    status = dixLookupDrawable(&drawable, stuff.drawable, client, 0, DixGetAttrAccess);
    if (status != Success)
        return status;

    if (stuff.provider == None)
        provider = null;
    else if (!RRProviderType) {
        return BadMatch;
    } else {
        mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));
        if (drawable.pScreen != provider.pScreen)
            return BadMatch;
    }
    screen = drawable.pScreen;

    status = dri3_open(client, screen, provider, &fd);
    if (status != Success)
        return status;

    if (client.ignoreCount == 0)
        return dri3_send_open_reply(client, fd);

    return Success;
}

private int proc_dri3_pixmap_from_buffer(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3PixmapFromBufferReq);
    mixin(X_REQUEST_FIELD_CARD32!"pixmap");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"size");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");
    mixin(X_REQUEST_FIELD_CARD16!"stride");

    int fd = void;
    DrawablePtr drawable = void;
    PixmapPtr pixmap = void;
    CARD32 stride = void, offset = void;
    int rc = void;

    SetReqFds(client, 1);
    mixin(LEGAL_NEW_RESOURCE!("stuff.pixmap", "client"));
    rc = dixLookupDrawable(&drawable, stuff.drawable, client, M_ANY, DixGetAttrAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.drawable;
        return rc;
    }

    if (!stuff.width || !stuff.height) {
        client.errorValue = cast(uint)0;
        return BadValue;
    }

    if (stuff.width > 32767 || stuff.height > 32767)
        return BadAlloc;

    if (stuff.depth != 1) {
        DepthPtr depth = drawable.pScreen.allowedDepths;
        int i = void;
        for (i = 0; i < drawable.pScreen.numDepths; i++, depth++)
            if (depth.depth == stuff.depth)
                break;
        if (i == drawable.pScreen.numDepths) {
            client.errorValue = cast(uint)stuff.depth;
            return BadValue;
        }
    }

    fd = ReadFdFromClient(client);
    if (fd < 0)
        return BadValue;

    offset = 0;
    stride = stuff.stride;
    rc = dri3_pixmap_from_fds(&pixmap,
                              drawable.pScreen, 1, &fd,
                              stuff.width, stuff.height,
                              &stride, &offset,
                              stuff.depth, stuff.bpp,
                              DRM_FORMAT_MOD_INVALID);
    close (fd);
    if (rc != Success)
        return rc;

    pixmap.drawable.id = stuff.pixmap;

    /* security creation/labeling check */
    rc = XaceHookResourceAccess(client, stuff.pixmap, X11_RESTYPE_PIXMAP,
                  pixmap, X11_RESTYPE_NONE, null, DixCreateAccess);

    if (rc != Success) {
        dixDestroyPixmap(pixmap, 0);
        return rc;
    }
    if (!AddResource(cast(uint)stuff.pixmap, X11_RESTYPE_PIXMAP, cast(void*) pixmap))
        return BadAlloc;

    return Success;
}

private int proc_dri3_buffer_from_pixmap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3BufferFromPixmapReq);
    mixin(X_REQUEST_FIELD_CARD32!"pixmap");

    int rc = void;
    int fd = void;
    PixmapPtr pixmap = void;

    rc = dixLookupResourceByType(cast(void**) &pixmap, stuff.pixmap, X11_RESTYPE_PIXMAP,
                                 client, DixWriteAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.pixmap;
        return rc;
    }

    xDRI3BufferFromPixmapReply reply = {
        nfd: 1,
        width: pixmap.drawable.width,
        height: pixmap.drawable.height,
        depth: pixmap.drawable.depth,
        bpp: pixmap.drawable.bitsPerPixel,
    };

    fd = dri3_fd_from_pixmap(pixmap, &reply.stride, &reply.size);
    if (fd < 0)
        return BadPixmap;

    if (WriteFdToClient(client, fd, TRUE) < 0) {
        close(fd);
        return BadAlloc;
    }

    mixin(X_REPLY_FIELD_CARD32!"size");
    mixin(X_REPLY_FIELD_CARD16!"width");
    mixin(X_REPLY_FIELD_CARD16!"height");
    mixin(X_REPLY_FIELD_CARD16!"stride");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int proc_dri3_fence_from_fd(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3FenceFromFDReq);
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"fence");

    DrawablePtr drawable = void;
    int fd = void;
    int status = void;

    SetReqFds(client, 1);
    mixin(LEGAL_NEW_RESOURCE!("stuff.fence", "client"));

    status = dixLookupDrawable(&drawable, stuff.drawable, client, M_ANY, DixGetAttrAccess);
    if (status != Success)
        return status;

    fd = ReadFdFromClient(client);
    if (fd < 0)
        return BadValue;

    status = SyncCreateFenceFromFD(client, drawable, stuff.fence,
                                   fd, stuff.initially_triggered);

    return status;
}

private int proc_dri3_fd_from_fence(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3FDFromFenceReq);
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"fence");

    xDRI3FDFromFenceReply reply = {
        nfd: 1,
    };
    DrawablePtr drawable = void;
    int fd = void;
    int status = void;
    SyncFence* fence = void;

    status = dixLookupDrawable(&drawable, stuff.drawable, client, M_ANY, DixGetAttrAccess);
    if (status != Success)
        return status;
    status = SyncVerifyFence(&fence, stuff.fence, client, DixWriteAccess);
    if (status != Success)
        return status;

    fd = SyncFDFromFence(client, drawable, fence);
    if (fd < 0)
        return BadMatch;

    if (WriteFdToClient(client, fd, FALSE) < 0)
        return BadAlloc;

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int proc_dri3_get_supported_modifiers(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3GetSupportedModifiersReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr window = void;
    ScreenPtr pScreen = void;
    CARD64* window_modifiers = null;
    CARD64* screen_modifiers = null;
    CARD32 nwindowmodifiers = 0;
    CARD32 nscreenmodifiers = 0;
    int status = void;

    status = dixLookupWindow(&window, stuff.window, client, DixGetAttrAccess);
    if (status != Success)
        return status;
    pScreen = window.drawable.pScreen;

    dri3_get_supported_modifiers(pScreen, &window.drawable,
                                 stuff.depth, stuff.bpp,
                                 &nwindowmodifiers, &window_modifiers,
                                 &nscreenmodifiers, &screen_modifiers);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD64s(&rpcbuf, window_modifiers, nwindowmodifiers);
    x_rpcbuf_write_CARD64s(&rpcbuf, screen_modifiers, nscreenmodifiers);

    free(window_modifiers);
    free(screen_modifiers);

    xDRI3GetSupportedModifiersReply reply = {
        numWindowModifiers: nwindowmodifiers,
        numScreenModifiers: nscreenmodifiers,
    };

    mixin(X_REPLY_FIELD_CARD32!"numWindowModifiers");
    mixin(X_REPLY_FIELD_CARD32!"numScreenModifiers");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int proc_dri3_pixmap_from_buffers(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3PixmapFromBuffersReq);
    mixin(X_REQUEST_FIELD_CARD32!"pixmap");
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");
    mixin(X_REQUEST_FIELD_CARD32!"stride0");
    mixin(X_REQUEST_FIELD_CARD32!"offset0");
    mixin(X_REQUEST_FIELD_CARD32!"stride1");
    mixin(X_REQUEST_FIELD_CARD32!"offset1");
    mixin(X_REQUEST_FIELD_CARD32!"stride2");
    mixin(X_REQUEST_FIELD_CARD32!"offset2");
    mixin(X_REQUEST_FIELD_CARD32!"stride3");
    mixin(X_REQUEST_FIELD_CARD32!"offset3");
    mixin(X_REQUEST_FIELD_CARD64!("modifier"));

    int[4] fds = void;
    CARD32[4] strides = void, offsets = void;
    ScreenPtr screen = void;
    WindowPtr window = void;
    PixmapPtr pixmap = void;
    int rc = void;
    int i = void;

    SetReqFds(client, stuff.num_buffers);
    mixin(LEGAL_NEW_RESOURCE!("stuff.pixmap", "client"));
    rc = dixLookupWindow(&window, stuff.window, client, DixGetAttrAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }
    screen = window.drawable.pScreen;

    if (!stuff.width || !stuff.height || !stuff.bpp || !stuff.depth) {
        client.errorValue = cast(uint)0;
        return BadValue;
    }

    if (stuff.width > 32767 || stuff.height > 32767)
        return BadAlloc;

    if (stuff.depth != 1) {
        DepthPtr depth = screen.allowedDepths;
        int j = void;
        for (j = 0; j < screen.numDepths; j++, depth++)
            if (depth.depth == stuff.depth)
                break;
        if (j == screen.numDepths) {
            client.errorValue = cast(uint)stuff.depth;
            return BadValue;
        }
    }

    if (!stuff.num_buffers || stuff.num_buffers > 4) {
        client.errorValue = cast(uint)stuff.num_buffers;
        return BadValue;
    }

    for (i = 0; i < stuff.num_buffers; i++) {
        fds[i] = ReadFdFromClient(client);
        if (fds[i] < 0) {
            while (--i >= 0)
                close(fds[i]);
            return BadValue;
        }
    }

    strides[0] = stuff.stride0;
    strides[1] = stuff.stride1;
    strides[2] = stuff.stride2;
    strides[3] = stuff.stride3;
    offsets[0] = stuff.offset0;
    offsets[1] = stuff.offset1;
    offsets[2] = stuff.offset2;
    offsets[3] = stuff.offset3;

    rc = dri3_pixmap_from_fds(&pixmap, screen,
                              stuff.num_buffers, fds.ptr,
                              stuff.width, stuff.height,
                              strides.ptr, offsets.ptr,
                              stuff.depth, stuff.bpp,
                              stuff.modifier);

    for (i = 0; i < stuff.num_buffers; i++)
        close (fds[i]);

    if (rc != Success)
        return rc;

    pixmap.drawable.id = stuff.pixmap;

    /* security creation/labeling check */
    rc = XaceHookResourceAccess(client, stuff.pixmap, X11_RESTYPE_PIXMAP,
                  pixmap, X11_RESTYPE_NONE, null, DixCreateAccess);

    if (rc != Success) {
        dixDestroyPixmap(pixmap, 0);
        return rc;
    }
    if (!AddResource(cast(uint)stuff.pixmap, X11_RESTYPE_PIXMAP, cast(void*) pixmap))
        return BadAlloc;

    return Success;
}

private int proc_dri3_buffers_from_pixmap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3BuffersFromPixmapReq);
    mixin(X_REQUEST_FIELD_CARD32!"pixmap");

    int rc = void;
    int[4] fds = void;
    int num_fds = void;
    uint[4] strides = void, offsets = void;
    ulong modifier = void;
    int i = void;
    PixmapPtr pixmap = void;

    rc = dixLookupResourceByType(cast(void**) &pixmap, stuff.pixmap, X11_RESTYPE_PIXMAP,
                                 client, DixWriteAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.pixmap;
        return rc;
    }

    num_fds = dri3_fds_from_pixmap(pixmap, fds.ptr, strides.ptr, offsets.ptr, &modifier);
    if (num_fds == 0)
        return BadPixmap;

    for (i = 0; i < num_fds; i++) {
        if (WriteFdToClient(client, fds[i], TRUE) < 0) {
            while (i--)
                close(fds[i]);
            return BadAlloc;
        }
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)strides, num_fds);
    x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)offsets, num_fds);

    xDRI3BuffersFromPixmapReply reply = {
        nfd: cast(ubyte)num_fds,
        width: pixmap.drawable.width,
        height: pixmap.drawable.height,
        depth: pixmap.drawable.depth,
        bpp: pixmap.drawable.bitsPerPixel,
        modifier: modifier,
    };

    mixin(X_REPLY_FIELD_CARD16!"width");
    mixin(X_REPLY_FIELD_CARD16!"height");
    mixin(X_REPLY_FIELD_CARD64!("modifier"));

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int proc_dri3_set_drm_device_in_use(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3SetDRMDeviceInUseReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"drmMajor");
    mixin(X_REQUEST_FIELD_CARD32!"drmMinor");

    WindowPtr window = void;
    int status = void;

    status = dixLookupWindow(&window, stuff.window, client,
                             DixGetAttrAccess);
    if (status != Success)
        return status;

    /* TODO Eventually we should use this information to have
     * DRI3GetSupportedModifiers return device-specific modifiers, but for now
     * we will ignore it until multi-device support is more complete.
     * Otherwise we can't advertise support for DRI3 1.4.
     */
    return Success;
}

private int proc_dri3_import_syncobj(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3ImportSyncobjReq);
    mixin(X_REQUEST_FIELD_CARD32!"syncobj");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");

    DrawablePtr drawable = void;
    ScreenPtr screen = void;
    int fd = void;
    int status = void;

    SetReqFds(client, 1);
    mixin(LEGAL_NEW_RESOURCE!("stuff.syncobj", "client"));

    status = dixLookupDrawable(&drawable, stuff.drawable, client,
                               M_ANY, DixGetAttrAccess);
    if (status != Success)
        return status;

    screen = drawable.pScreen;

    fd = ReadFdFromClient(client);
    if (fd < 0)
        return BadValue;

    return dri3_import_syncobj(client, screen, stuff.syncobj, fd);
}

private int proc_dri3_free_syncobj(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDRI3FreeSyncobjReq);
    mixin(X_REQUEST_FIELD_CARD32!"syncobj");

    dri3_syncobj* syncobj = void;
    int status = void;

    status = dixLookupResourceByType(cast(void**) &syncobj, stuff.syncobj,
                                     dri3_syncobj_type, client, DixWriteAccess);
    if (status != Success)
        return status;

    FreeResource(cast(uint)stuff.syncobj, RT_NONE);
    return Success;
}

int proc_dri3_dispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    if (!client.local)
        return BadMatch;

    switch (stuff.data) {
        case X_DRI3QueryVersion:
            return proc_dri3_query_version(client);
        case X_DRI3Open:
            return proc_dri3_open(client);
        case X_DRI3PixmapFromBuffer:
            return proc_dri3_pixmap_from_buffer(client);
        case X_DRI3BufferFromPixmap:
            return proc_dri3_buffer_from_pixmap(client);
        case X_DRI3FenceFromFD:
            return proc_dri3_fence_from_fd(client);
        case X_DRI3FDFromFence:
            return proc_dri3_fd_from_fence(client);

        /* v1.2 */
        case xDRI3GetSupportedModifiers:
            return proc_dri3_get_supported_modifiers(client);
        case xDRI3PixmapFromBuffers:
            return proc_dri3_pixmap_from_buffers(client);
        case xDRI3BuffersFromPixmap:
            return proc_dri3_buffers_from_pixmap(client);

        /* v1.3 */
        case xDRI3SetDRMDeviceInUse:
            return proc_dri3_set_drm_device_in_use(client);

        /* v1.4 */
        case xDRI3ImportSyncobj:
            return proc_dri3_import_syncobj(client);
        case xDRI3FreeSyncobj:
            return proc_dri3_free_syncobj(client);
        default:
            return BadRequest;
    }
}
