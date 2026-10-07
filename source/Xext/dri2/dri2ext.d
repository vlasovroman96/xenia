module Xext.dri2.dri2ext;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2008 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Soft-
 * ware"), to deal in the Software without restriction, including without
 * limitation the rights to use, copy, modify, merge, publish, distribute,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, provided that the above copyright
 * notice(s) and this permission notice appear in all copies of the Soft-
 * ware and that both the above copyright notice(s) and this permission
 * notice appear in supporting documentation.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABIL-
 * ITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT OF THIRD PARTY
 * RIGHTS. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR HOLDERS INCLUDED IN
 * THIS NOTICE BE LIABLE FOR ANY CLAIM, OR ANY SPECIAL INDIRECT OR CONSE-
 * QUENTIAL DAMAGES, OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFOR-
 * MANCE OF THIS SOFTWARE.
 *
 * Except as contained in this notice, the name of a copyright holder shall
 * not be used in advertising or otherwise to promote the sale, use or
 * other dealings in this Software without prior written authorization of
 * the copyright holder.
 *
 * Authors:
 *   Kristian Høgsberg (krh@redhat.com)
 */

import build.dix_config;

//import x11.X;
//import x11.Xproto;
import externs.X11.extensions.dri2proto;
// //import externs.X11.extensions.xfixeswire;
import build.xlibre_server;

import dix.dix_priv;
import dix.request_priv;
import include.extinit;

import include.dixstruct;
import include.scrnintstr;
import include.pixmapstr;
import include.extnsionst;
import xfixes.xfixes;
import Xext.dri2.dri2_priv;
import Xext.dri2.dri2int;
import include.protocol_versions;
import include.dri2;
import externs.X11.extensions.dri2tokens;
import include.dix;
import xfixes.region;
import dix.extension;
import dix.dixutils;
import dix.events;
import Xext.panoramiXsrv;

/* For the static extension loader */
Bool noDRI2Extension = FALSE;


private int DRI2EventBase;

private Bool validDrawable(ClientPtr client, XID drawable, Mask access_mode, DrawablePtr* pDrawable, int* status)
{
    *status = dixLookupDrawable(pDrawable, drawable, client,
                                M_DRAWABLE_WINDOW | M_DRAWABLE_PIXMAP,
                                access_mode);
    if (*status != Success) {
        client.errorValue = cast(uint)drawable;
        return FALSE;
    }

    return TRUE;
}

private int ProcDRI2QueryVersion(ClientPtr client)
{
    xDRI2QueryVersionReply reply = {
        majorVersion: dri2_major,
        minorVersion: dri2_minor
    };

    mixin(REQUEST_SIZE_MATCH!"xDRI2QueryVersionReq");

    if (client.swapped) {
        swapl(&reply.majorVersion);
        swapl(&reply.minorVersion);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDRI2Connect(ClientPtr client)
{
    mixin(REQUEST!xDRI2ConnectReq);
    DrawablePtr pDraw = void;
    int fd = void, status = void;
    const(char)* driverName = void;
    const(char)* deviceName = void;

    mixin(REQUEST_SIZE_MATCH!"xDRI2ConnectReq");
    if (!validDrawable(client, stuff.window, DixGetAttrAccess,
                       &pDraw, &status))
        return status;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    xDRI2ConnectReply reply = { 0 };

    if (DRI2Connect(client, pDraw.pScreen,
                    cast(uint)stuff.driverType, &fd, &driverName, &deviceName)) {
        reply.driverNameLength = cast(uint)strlen(driverName);
        reply.deviceNameLength = cast(uint)strlen(deviceName);

        x_rpcbuf_write_string_pad(&rpcbuf, driverName);
        x_rpcbuf_write_string_pad(&rpcbuf, deviceName);
    }

    auto res = mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));

    return res;
}

private int ProcDRI2Authenticate(ClientPtr client)
{
    mixin(REQUEST!xDRI2AuthenticateReq);
    DrawablePtr pDraw = void;
    int status = void;


    mixin(REQUEST_SIZE_MATCH!"xDRI2AuthenticateReq");
    if (!validDrawable(client, stuff.window, DixGetAttrAccess,
                       &pDraw, &status))
        return status;

    xDRI2AuthenticateReply reply = {
        authenticated: DRI2Authenticate(client, pDraw.pScreen, cast(uint)stuff.magic)
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private void DRI2InvalidateBuffersEvent(DrawablePtr pDraw, void* priv, XID id)
{
    ClientPtr client = cast(ClientPtr)priv;
    xDRI2InvalidateBuffers event = {
        type: cast(ubyte)(DRI2EventBase + DRI2_InvalidateBuffers),
        drawable: cast(uint)id
    };

    WriteEventsToClient(client, 1, cast(xEvent*) &event);
}

private int ProcDRI2CreateDrawable(ClientPtr client)
{
    mixin(REQUEST!xDRI2CreateDrawableReq);
    DrawablePtr pDrawable = void;
    int status = void;

    mixin(REQUEST_SIZE_MATCH!"xDRI2CreateDrawableReq");

    if (!validDrawable(client, stuff.drawable, DixAddAccess,
                       &pDrawable, &status))
        return status;

    status = DRI2CreateDrawable(client, pDrawable, stuff.drawable,
                                &DRI2InvalidateBuffersEvent, client);
    if (status != Success)
        return status;

    return Success;
}

private int ProcDRI2DestroyDrawable(ClientPtr client)
{
    mixin(REQUEST!xDRI2DestroyDrawableReq);
    DrawablePtr pDrawable = void;
    int status = void;

    mixin(REQUEST_SIZE_MATCH!"xDRI2DestroyDrawableReq");
    if (!validDrawable(client, stuff.drawable, DixRemoveAccess,
                       &pDrawable, &status))
        return status;

    return Success;
}

private int send_buffers_reply(ClientPtr client, DrawablePtr pDrawable, DRI2BufferPtr* buffers, int count, int width, int height)
{
    int skip = 0;
    int i = void;

    if (buffers is null)
        return BadAlloc;

    if (pDrawable.type == DRAWABLE_WINDOW) {
        for (i = 0; i < count; i++) {
            /* Do not send the real front buffer of a window to the client.
             */
            if (buffers[i].attachment == DRI2BufferFrontLeft) {
                skip++;
                continue;
            }
        }
    }

    xDRI2GetBuffersReply reply = {
        width: width,
        height: height,
        count: count - skip
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    for (i = 0; i < count; i++) {
        xDRI2Buffer buffer = void;

        /* Do not send the real front buffer of a window to the client.
         */
        if ((pDrawable.type == DRAWABLE_WINDOW)
            && (buffers[i].attachment == DRI2BufferFrontLeft)) {
            continue;
        }

        buffer.attachment = buffers[i].attachment;
        buffer.name = buffers[i].name;
        buffer.pitch = buffers[i].pitch;
        buffer.cpp = buffers[i].cpp;
        buffer.flags = buffers[i].flags;

        x_rpcbuf_write_binary_pad(&rpcbuf, &buffer, xDRI2Buffer.sizeof);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcDRI2GetBuffers(ClientPtr client)
{
    mixin(REQUEST!xDRI2GetBuffersReq);
    DrawablePtr pDrawable = void;
    DRI2BufferPtr* buffers = void;
    int status = void, width = void, height = void, count = void;
    uint* attachments = void;

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2GetBuffersReq);
    /* stuff->count is a count of CARD32 attachments that follows */
    if (stuff.count > (INT_MAX / CARD32.sizeof))
        return BadLength;
    mixin(REQUEST_FIXED_SIZE!("xDRI2GetBuffersReq", "stuff.count * CARD32.sizeof"));

    if (!validDrawable(client, stuff.drawable, DixReadAccess | DixWriteAccess,
                       &pDrawable, &status))
        return status;

    if (DRI2ThrottleClient(client, pDrawable))
        return Success;

    attachments = cast(uint*) &stuff[1];
    buffers = DRI2GetBuffers(pDrawable, &width, &height,
                             attachments, cast(int)stuff.count, &count);

    return send_buffers_reply(client, pDrawable, buffers, count, width, height);

}

private int ProcDRI2GetBuffersWithFormat(ClientPtr client)
{
    mixin(REQUEST!xDRI2GetBuffersReq);
    DrawablePtr pDrawable = void;
    DRI2BufferPtr* buffers = void;
    int status = void, width = void, height = void, count = void;
    uint* attachments = void;

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2GetBuffersReq);
    /* stuff->count is a count of pairs of CARD32s (attachments & formats)
       that follows */
    if (stuff.count > (INT_MAX / (2 * CARD32.sizeof)))
        return BadLength;
    mixin(REQUEST_FIXED_SIZE!("xDRI2GetBuffersReq",
                       "stuff.count * (2 * CARD32.sizeof)"));
    if (!validDrawable(client, stuff.drawable, DixReadAccess | DixWriteAccess,
                       &pDrawable, &status))
        return status;

    if (DRI2ThrottleClient(client, pDrawable))
        return Success;

    attachments = cast(uint*) &stuff[1];
    buffers = DRI2GetBuffersWithFormat(pDrawable, &width, &height,
                                       attachments, cast(int)stuff.count, &count);

    return send_buffers_reply(client, pDrawable, buffers, count, width, height);
}

private int ProcDRI2CopyRegion(ClientPtr client)
{
    mixin(REQUEST!xDRI2CopyRegionReq);
    DrawablePtr pDrawable = void;
    int status = void;
    RegionPtr pRegion = void;

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2CopyRegionReq);

    if (!validDrawable(client, stuff.drawable, DixWriteAccess,
                       &pDrawable, &status))
        return status;

    mixin(VERIFY_REGION!("pRegion", "stuff.region", "client", "DixReadAccess"));

    status = DRI2CopyRegion(pDrawable, pRegion, cast(uint)stuff.dest, cast(uint)stuff.src);
    if (status != Success)
        return status;

    /* CopyRegion needs to be a round trip to make sure the X server
     * queues the swap buffer rendering commands before the DRI client
     * continues rendering.  The reply has a bitmask to signal the
     * presence of optional return values as well, but we're not using
     * that yet.
     */

    xDRI2CopyRegionReply reply = { 0 };
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private CARD64 vals_to_card64(CARD32 lo, CARD32 hi)
{
    return cast(CARD64) hi << 32 | lo;
}

private void DRI2SwapEvent(ClientPtr client, void* data, int type, CARD64 ust, CARD64 msc, CARD32 sbc)
{
    DrawablePtr pDrawable = cast(DrawablePtr)data;
    xDRI2BufferSwapComplete2 event = {
        type: cast(ubyte)(DRI2EventBase + DRI2_BufferSwapComplete),
        event_type: cast(ushort)type,
        drawable: cast(uint)pDrawable.id,
        ust_hi: cast(CARD64) ust >> 32,
        ust_lo: ust & 0xffffffff,
        msc_hi: cast(CARD64) msc >> 32,
        msc_lo: msc & 0xffffffff,
        sbc: sbc
    };

    WriteEventsToClient(client, 1, cast(xEvent*) &event);
}

private int ProcDRI2SwapBuffers(ClientPtr client)
{
    mixin(REQUEST!xDRI2SwapBuffersReq);
    DrawablePtr pDrawable = void;
    CARD64 target_msc = void, divisor = void, remainder = void, swap_target = void;
    int status = void;

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2SwapBuffersReq);

    if (!validDrawable(client, stuff.drawable,
                       DixReadAccess | DixWriteAccess, &pDrawable, &status))
        return status;

    /*
     * Ensures an out of control client can't exhaust our swap queue, and
     * also orders swaps.
     */
    if (DRI2ThrottleClient(client, pDrawable))
        return Success;

    target_msc = vals_to_card64(stuff.target_msc_lo, stuff.target_msc_hi);
    divisor = vals_to_card64(stuff.divisor_lo, stuff.divisor_hi);
    remainder = vals_to_card64(stuff.remainder_lo, stuff.remainder_hi);

    status = DRI2SwapBuffers(client, pDrawable, target_msc, divisor, remainder,
                             &swap_target, &DRI2SwapEvent, pDrawable);
    if (status != Success)
        return BadDrawable;

    xDRI2SwapBuffersReply reply = { 0 };

    reply.swap_hi = swap_target >> 32;
    reply.swap_lo = swap_target & 0xffffffff;

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private void load_msc_reply(xDRI2MSCReply* rep, CARD64 ust, CARD64 msc, CARD64 sbc)
{
    rep.ust_hi = ust >> 32;
    rep.ust_lo = ust & 0xffffffff;
    rep.msc_hi = msc >> 32;
    rep.msc_lo = msc & 0xffffffff;
    rep.sbc_hi = sbc >> 32;
    rep.sbc_lo = sbc & 0xffffffff;
}

private int ProcDRI2GetMSC(ClientPtr client)
{
    mixin(REQUEST!xDRI2GetMSCReq);
    DrawablePtr pDrawable = void;
    CARD64 ust = void, msc = void, sbc = void;
    int status = void;

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2GetMSCReq);

    if (!validDrawable(client, stuff.drawable, DixReadAccess, &pDrawable,
                       &status))
        return status;

    status = DRI2GetMSC(pDrawable, &ust, &msc, &sbc);
    if (status != Success)
        return status;

    xDRI2MSCReply reply = { 0 };

    load_msc_reply(&reply, ust, msc, sbc);

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDRI2WaitMSC(ClientPtr client)
{
    mixin(REQUEST!xDRI2WaitMSCReq);
    DrawablePtr pDrawable = void;
    CARD64 target = void, divisor = void, remainder = void;
    int status = void;

    /* FIXME: in restart case, client may be gone at this point */

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2WaitMSCReq);

    if (!validDrawable(client, stuff.drawable, DixReadAccess, &pDrawable,
                       &status))
        return status;

    target = vals_to_card64(stuff.target_msc_lo, stuff.target_msc_hi);
    divisor = vals_to_card64(stuff.divisor_lo, stuff.divisor_hi);
    remainder = vals_to_card64(stuff.remainder_lo, stuff.remainder_hi);

    status = DRI2WaitMSC(client, pDrawable, target, divisor, remainder);
    if (status != Success)
        return status;

    return Success;
}

int ProcDRI2WaitMSCReply(ClientPtr client, CARD64 ust, CARD64 msc, CARD64 sbc)
{
    xDRI2MSCReply reply = { 0 };

    load_msc_reply(&reply, ust, msc, sbc);

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDRI2SwapInterval(ClientPtr client)
{
    mixin(REQUEST!xDRI2SwapIntervalReq);
    DrawablePtr pDrawable = void;
    int status = void;

    /* FIXME: in restart case, client may be gone at this point */

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2SwapIntervalReq);

    if (!validDrawable(client, stuff.drawable, DixReadAccess | DixWriteAccess,
                       &pDrawable, &status))
        return status;

    DRI2SwapInterval(pDrawable, cast(int)stuff.interval);

    return Success;
}

private int ProcDRI2WaitSBC(ClientPtr client)
{
    mixin(REQUEST!xDRI2WaitSBCReq);
    DrawablePtr pDrawable = void;
    CARD64 target = void;
    int status = void;

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2WaitSBCReq);

    if (!validDrawable(client, stuff.drawable, DixReadAccess, &pDrawable,
                       &status))
        return status;

    target = vals_to_card64(stuff.target_sbc_lo, stuff.target_sbc_hi);
    status = DRI2WaitSBC(client, pDrawable, target);

    return status;
}

private int ProcDRI2GetParam(ClientPtr client)
{
    mixin(REQUEST!xDRI2GetParamReq);
    DrawablePtr pDrawable = void;
    CARD64 value = void;
    int status = void;

    mixin(REQUEST_AT_LEAST_SIZE!xDRI2GetParamReq);

    if (!validDrawable(client, stuff.drawable, DixReadAccess,
                       &pDrawable, &status))
        return status;

    xDRI2GetParamReply reply = { 0 };

    status = DRI2GetParam(client, pDrawable, stuff.param,
                          &reply.is_param_recognized, &value);
    reply.value_hi = value >> 32;
    reply.value_lo = value & 0xffffffff;

    if (status != Success)
        return status;

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDRI2Dispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
    case X_DRI2QueryVersion:
        return ProcDRI2QueryVersion(client);
    default: break;}

    if (!client.local)
        return BadRequest;

    switch (stuff.data) {
    case X_DRI2Connect:
        return ProcDRI2Connect(client);
    case X_DRI2Authenticate:
        return ProcDRI2Authenticate(client);
    case X_DRI2CreateDrawable:
        return ProcDRI2CreateDrawable(client);
    case X_DRI2DestroyDrawable:
        return ProcDRI2DestroyDrawable(client);
    case X_DRI2GetBuffers:
        return ProcDRI2GetBuffers(client);
    case X_DRI2CopyRegion:
        return ProcDRI2CopyRegion(client);
    case X_DRI2GetBuffersWithFormat:
        return ProcDRI2GetBuffersWithFormat(client);
    case X_DRI2SwapBuffers:
        return ProcDRI2SwapBuffers(client);
    case X_DRI2GetMSC:
        return ProcDRI2GetMSC(client);
    case X_DRI2WaitMSC:
        return ProcDRI2WaitMSC(client);
    case X_DRI2WaitSBC:
        return ProcDRI2WaitSBC(client);
    case X_DRI2SwapInterval:
        return ProcDRI2SwapInterval(client);
    case X_DRI2GetParam:
        return ProcDRI2GetParam(client);
    default:
        return BadRequest;
    }
}

void DRI2ExtensionInit()
{
    ExtensionEntry* dri2Extension = void;

static if(XINERAMA){
    if (!noPanoramiXExtension)
        return;
} /* XINERAMA */

    /**
     * Advertise the DRI2 extension,
     * even if no screens support it.
     *
     * This is needed for steam's proton to work.
     */
    dri2Extension = AddExtension(DRI2_NAME,
                                 DRI2NumberEvents,
                                 DRI2NumberErrors,
                                 &ProcDRI2Dispatch,
                                 &ProcDRI2Dispatch,
                                 null,
                                 &StandardMinorOpcode);

    DRI2EventBase = dri2Extension.eventBase;

    DRI2ModuleSetup();
}
