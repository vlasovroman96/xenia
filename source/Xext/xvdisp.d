module Xext.xvdisp;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************
Copyright 1991 by Digital Equipment Corporation, Maynard, Massachusetts,
and the Massachusetts Institute of Technology, Cambridge, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the names of Digital or MIT not be
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

import build.xlibre_server;

import core.stdc.string;

//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.Xv;
// //import externs.X11.extensions.Xvproto;
import externs.X11.extensions.shmproto;

import dix.dix_priv;
import dix.rpcbuf_priv;
import dix.request_priv;
import dix.screenint_priv;
import include.shmint;
import include.xvmcext;
import Xext.panoramiX;
import Xext.panoramiXsrv;
import Xext.shm_priv;
import Xext.xvdix_priv;
import common.misc;
import dix.scrnintstr;
import include.windowstr;
import dix.pixmap;
import dix.dixstruct_priv;
import dix.resource;

import Xext.xvdisp;
import externs.X11.extensions.Xvproto;
import externs.X11.extensions.Xv;
import dix.dixutils;
import dix.gc;
import os.log;
import Xext.xvmain;
import dix.screen_hooks;
import dix.atom;
import dix.dispatch;

static if(XINERAMA){
c_ulong XvXRTPort;
} /* XINERAMA */

private int ProcXvQueryExtension(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvQueryExtensionReq);

    xvQueryExtensionReply reply = {
        version_: XvVersion,
        revision: XvRevision
    };

    // reply.`version` = XvVersion;

    mixin(X_REPLY_FIELD_CARD16!"version_");
    mixin(X_REPLY_FIELD_CARD16!"revision");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXvQueryAdaptors(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvQueryAdaptorsReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    int na = void, nf = void, rc = void;
    XvAdaptorPtr pa = void;
    XvFormatPtr pf = void;
    WindowPtr pWin = void;
    ScreenPtr pScreen = void;
    XvScreenPtr pxvs = void;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    pScreen = pWin.drawable.pScreen;
    pxvs = cast(XvScreenPtr) dixLookupPrivate(&pScreen.devPrivates,
                                          XvGetScreenKey());

    size_t numAdaptors = 0;
    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (pxvs) {
        numAdaptors = pxvs.nAdaptors;
        na = pxvs.nAdaptors;
        pa = pxvs.pAdaptors;
        while (na--) {
            /* xvAdaptorInfo */
            x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)pa.base_id);
            x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)strlen(pa.name));
            x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)pa.nPorts);
            x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)pa.nFormats);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pa.type);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)0); /* padding */
            x_rpcbuf_write_string_pad(&rpcbuf, pa.name);

            nf = pa.nFormats;
            pf = pa.pFormats;
            while (nf--) {
                /* xvFormat */
                x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)pf.visual);
                x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pf.depth);
                x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)0); /* padding */
                x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)0); /* padding */
                pf++;
            }
            pa++;
        }
    }

    xvQueryAdaptorsReply reply = {
        num_adaptors: cast(ushort)numAdaptors,
    };

    mixin(X_REPLY_FIELD_CARD16!"num_adaptors");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvQueryEncodings(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvQueryEncodingsReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");

    XvPortPtr pPort = void;
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    size_t ne = pPort.pAdaptor.nEncodings;
    XvEncodingPtr pe = pPort.pAdaptor.pEncodings;
    while (ne--) {
        size_t nameSize = strlen(pe.name);

        x_rpcbuf_write_CARD32(&rpcbuf, pe.id);
        x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)nameSize);
        x_rpcbuf_write_CARD16(&rpcbuf, pe.width);
        x_rpcbuf_write_CARD16(&rpcbuf, pe.height);
        x_rpcbuf_write_CARD16(&rpcbuf, 0); /* padding */
        x_rpcbuf_write_CARD32(&rpcbuf, pe.rate.numerator);
        x_rpcbuf_write_CARD32(&rpcbuf, pe.rate.denominator);
        x_rpcbuf_write_string_pad(&rpcbuf, pe.name);

        pe++;
    }

    xvQueryEncodingsReply reply = {
        num_encodings: cast(ushort)pPort.pAdaptor.nEncodings,
    };

    mixin(X_REPLY_FIELD_CARD16!"num_encodings");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int SingleXvPutVideo(ClientPtr client)
{
    DrawablePtr pDraw = void;
    XvPortPtr pPort = void;
    GCPtr pGC = void;
    int status = void;

    mixin(REQUEST!xvPutVideoReq);

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    if (!(pPort.pAdaptor.type & XvInputMask) ||
        !(pPort.pAdaptor.type & XvVideoMask)) {
        client.errorValue = cast(uint)stuff.port;
        return BadMatch;
    }

    status = XvdiMatchPort(pPort, pDraw);
    if (status != Success) {
        return status;
    }

    return XvdiPutVideo(client, pDraw, pPort, pGC, stuff.vid_x, stuff.vid_y,
                        stuff.vid_w, stuff.vid_h, stuff.drw_x, stuff.drw_y,
                        stuff.drw_w, stuff.drw_h);
}

static if(XINERAMA){

}

private int ProcXvPutVideo(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvPutVideoReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"gc");
    mixin(X_REQUEST_FIELD_CARD16!"vid_x");
    mixin(X_REQUEST_FIELD_CARD16!"vid_y");
    mixin(X_REQUEST_FIELD_CARD16!"vid_w");
    mixin(X_REQUEST_FIELD_CARD16!"vid_h");
    mixin(X_REQUEST_FIELD_CARD16!"drw_x");
    mixin(X_REQUEST_FIELD_CARD16!"drw_y");
    mixin(X_REQUEST_FIELD_CARD16!"drw_w");
    mixin(X_REQUEST_FIELD_CARD16!"drw_h");

static if(XINERAMA){
    if (xvUseXinerama)
        return XineramaXvPutVideo(client);
}
    return SingleXvPutVideo(client);
}

private int SingleXvPutStill(ClientPtr client)
{
    DrawablePtr pDraw = void;
    XvPortPtr pPort = void;
    GCPtr pGC = void;
    int status = void;

    mixin(REQUEST!xvPutStillReq);

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    if (!(pPort.pAdaptor.type & XvInputMask) ||
        !(pPort.pAdaptor.type & XvStillMask)) {
        client.errorValue = cast(uint)stuff.port;
        return BadMatch;
    }

    status = XvdiMatchPort(pPort, pDraw);
    if (status != Success) {
        return status;
    }

    return XvdiPutStill(client, pDraw, pPort, pGC, stuff.vid_x, stuff.vid_y,
                        stuff.vid_w, stuff.vid_h, stuff.drw_x, stuff.drw_y,
                        stuff.drw_w, stuff.drw_h);
}

static if(XINERAMA){

}

private int ProcXvPutStill(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvPutStillReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"gc");
    mixin(X_REQUEST_FIELD_CARD16!"vid_x");
    mixin(X_REQUEST_FIELD_CARD16!"vid_y");
    mixin(X_REQUEST_FIELD_CARD16!"vid_w");
    mixin(X_REQUEST_FIELD_CARD16!"vid_h");
    mixin(X_REQUEST_FIELD_CARD16!"drw_x");
    mixin(X_REQUEST_FIELD_CARD16!"drw_y");
    mixin(X_REQUEST_FIELD_CARD16!"drw_w");
    mixin(X_REQUEST_FIELD_CARD16!"drw_h");

static if(XINERAMA){
    if (xvUseXinerama)
        return XineramaXvPutStill(client);
}
    return SingleXvPutStill(client);
}

private int ProcXvGetVideo(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvGetVideoReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"gc");
    mixin(X_REQUEST_FIELD_CARD16!"vid_x");
    mixin(X_REQUEST_FIELD_CARD16!"vid_y");
    mixin(X_REQUEST_FIELD_CARD16!"vid_w");
    mixin(X_REQUEST_FIELD_CARD16!"vid_h");
    mixin(X_REQUEST_FIELD_CARD16!"drw_x");
    mixin(X_REQUEST_FIELD_CARD16!"drw_y");
    mixin(X_REQUEST_FIELD_CARD16!"drw_w");
    mixin(X_REQUEST_FIELD_CARD16!"drw_h");

    DrawablePtr pDraw = void;
    XvPortPtr pPort = void;
    GCPtr pGC = void;
    int status = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixReadAccess"));
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    if (!(pPort.pAdaptor.type & XvOutputMask) ||
        !(pPort.pAdaptor.type & XvVideoMask)) {
        client.errorValue = cast(uint)stuff.port;
        return BadMatch;
    }

    status = XvdiMatchPort(pPort, pDraw);
    if (status != Success) {
        return status;
    }

    return XvdiGetVideo(client, pDraw, pPort, pGC, stuff.vid_x, stuff.vid_y,
                        stuff.vid_w, stuff.vid_h, stuff.drw_x, stuff.drw_y,
                        stuff.drw_w, stuff.drw_h);
}

private int ProcXvGetStill(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvGetStillReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"gc");
    mixin(X_REQUEST_FIELD_CARD16!"vid_x");
    mixin(X_REQUEST_FIELD_CARD16!"vid_y");
    mixin(X_REQUEST_FIELD_CARD16!"vid_w");
    mixin(X_REQUEST_FIELD_CARD16!"vid_h");
    mixin(X_REQUEST_FIELD_CARD16!"drw_x");
    mixin(X_REQUEST_FIELD_CARD16!"drw_y");
    mixin(X_REQUEST_FIELD_CARD16!"drw_w");
    mixin(X_REQUEST_FIELD_CARD16!"drw_h");

    DrawablePtr pDraw = void;
    XvPortPtr pPort = void;
    GCPtr pGC = void;
    int status = void;

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixReadAccess"));
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    if (!(pPort.pAdaptor.type & XvOutputMask) ||
        !(pPort.pAdaptor.type & XvStillMask)) {
        client.errorValue = cast(uint)stuff.port;
        return BadMatch;
    }

    status = XvdiMatchPort(pPort, pDraw);
    if (status != Success) {
        return status;
    }

    return XvdiGetStill(client, pDraw, pPort, pGC, stuff.vid_x, stuff.vid_y,
                        stuff.vid_w, stuff.vid_h, stuff.drw_x, stuff.drw_y,
                        stuff.drw_w, stuff.drw_h);
}

private int ProcXvSelectVideoNotify(ClientPtr client)
{
    DrawablePtr pDraw = void;
    int rc = void;

    mixin(X_REQUEST_HEAD_STRUCT!xvSelectVideoNotifyReq);
    mixin(X_REQUEST_FIELD_CARD32!"drawable");

    rc = dixLookupDrawable(&pDraw, stuff.drawable, client, 0,
                           DixReceiveAccess);
    if (rc != Success)
        return rc;

    return XvdiSelectVideoNotify(client, pDraw, stuff.onoff);
}

private int ProcXvSelectPortNotify(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvSelectPortNotifyReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");

    XvPortPtr pPort = void;
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    return XvdiSelectPortNotify(client, pPort, stuff.onoff);
}

private int ProcXvGrabPort(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvGrabPortReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"time");

    int result = void, status = void;
    XvPortPtr pPort = void;

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    status = XvdiGrabPort(client, pPort, stuff.time, &result);

    if (status != Success) {
        return status;
    }
    xvGrabPortReply reply = {
        result: cast(ubyte)result
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXvUngrabPort(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvUngrabPortReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"time");

    XvPortPtr pPort = void;
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    return XvdiUngrabPort(client, pPort, stuff.time);
}

private int SingleXvStopVideo(ClientPtr client)
{
    int ret = void;
    DrawablePtr pDraw = void;
    XvPortPtr pPort = void;

    mixin(REQUEST!xvStopVideoReq);

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    ret = dixLookupDrawable(&pDraw, stuff.drawable, client, 0, DixWriteAccess);
    if (ret != Success)
        return ret;

    return XvdiStopVideo(client, pPort, pDraw);
}

static if(XINERAMA){

}

private int ProcXvStopVideo(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvStopVideoReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");

static if(XINERAMA){
    if (xvUseXinerama)
        return XineramaXvStopVideo(client);
}
    return SingleXvStopVideo(client);
}

private int SingleXvSetPortAttribute(ClientPtr client)
{
    int status = void;
    XvPortPtr pPort = void;

    mixin(REQUEST!xvSetPortAttributeReq);

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixSetAttrAccess"));

    if (!ValidAtom(stuff.attribute)) {
        client.errorValue = cast(uint)stuff.attribute;
        return BadAtom;
    }

    status =
        XvdiSetPortAttribute(client, pPort, stuff.attribute, stuff.value);

    if (status == BadMatch)
        client.errorValue = cast(uint)stuff.attribute;
    else
        client.errorValue = cast(uint)stuff.value;

    return status;
}

static if(XINERAMA){

}

private int ProcXvSetPortAttribute(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvSetPortAttributeReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"attribute");
    mixin(X_REQUEST_FIELD_CARD32!"value");

static if(XINERAMA){
    if (xvUseXinerama)
        return XineramaXvSetPortAttribute(client);
}
    return SingleXvSetPortAttribute(client);
}

private int ProcXvGetPortAttribute(ClientPtr client)
{
    INT32 value = void;
    int status = void;
    XvPortPtr pPort = void;

    mixin(X_REQUEST_HEAD_STRUCT!xvGetPortAttributeReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"attribute");

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixGetAttrAccess"));

    if (!ValidAtom(stuff.attribute)) {
        client.errorValue = cast(uint)stuff.attribute;
        return BadAtom;
    }

    status = XvdiGetPortAttribute(client, pPort, stuff.attribute, &value);
    if (status != Success) {
        client.errorValue = cast(uint)stuff.attribute;
        return status;
    }

    xvGetPortAttributeReply reply = {
        value: value
    };

    mixin(X_REPLY_FIELD_CARD32!"value");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXvQueryBestSize(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvQueryBestSizeReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD16!"vid_w");
    mixin(X_REQUEST_FIELD_CARD16!"vid_h");
    mixin(X_REQUEST_FIELD_CARD16!"drw_w");
    mixin(X_REQUEST_FIELD_CARD16!"drw_h");

    uint actual_width = void, actual_height = void;
    XvPortPtr pPort = void;

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    (*pPort.pAdaptor.ddQueryBestSize) (pPort, stuff.motion,
                                         stuff.vid_w, stuff.vid_h,
                                         stuff.drw_w, stuff.drw_h,
                                         &actual_width, &actual_height);

    xvQueryBestSizeReply reply = {
        actual_width: cast(ushort)actual_width,
        actual_height: cast(ushort)actual_height
    };

    mixin(X_REPLY_FIELD_CARD16!"actual_width");
    mixin(X_REPLY_FIELD_CARD16!"actual_height");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXvQueryPortAttributes(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvQueryPortAttributesReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");

    int i = void;
    XvPortPtr pPort = void;
    XvAttributePtr pAtt = void;

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixGetAttrAccess"));

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    size_t textSize = 0;
    for (i = 0, pAtt = pPort.pAdaptor.pAttributes;
         i < pPort.pAdaptor.nAttributes; i++, pAtt++) {
        textSize += pad_to_int32(cast(int)strlen(pAtt.name) + 1);
        x_rpcbuf_write_CARD32(&rpcbuf, pAtt.flags);
        x_rpcbuf_write_CARD32(&rpcbuf, pAtt.min_value);
        x_rpcbuf_write_CARD32(&rpcbuf, pAtt.max_value);
        x_rpcbuf_write_CARD32(&rpcbuf, pad_to_int32(cast(uint)strlen(pAtt.name)+1)); /* pass the NULL */
        x_rpcbuf_write_string_0t_pad(&rpcbuf, pAtt.name);
    }

    xvQueryPortAttributesReply reply = {
        num_attributes: pPort.pAdaptor.nAttributes,
        text_size: cast(uint)textSize,
    };

    mixin(X_REPLY_FIELD_CARD32!"num_attributes");
    mixin(X_REPLY_FIELD_CARD32!"text_size");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int SingleXvPutImage(ClientPtr client)
{
    DrawablePtr pDraw = void;
    XvPortPtr pPort = void;
    XvImagePtr pImage = null;
    GCPtr pGC = void;
    int status = void, i = void, size = void;
    CARD16 width = void, height = void;

    mixin(REQUEST!xvPutImageReq);

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    if (!(pPort.pAdaptor.type & XvImageMask) ||
        !(pPort.pAdaptor.type & XvInputMask)) {
        client.errorValue = cast(uint)stuff.port;
        return BadMatch;
    }

    status = XvdiMatchPort(pPort, pDraw);
    if (status != Success) {
        return status;
    }

    for (i = 0; i < pPort.pAdaptor.nImages; i++) {
        if (pPort.pAdaptor.pImages[i].id == stuff.id) {
            pImage = &(pPort.pAdaptor.pImages[i]);
            break;
        }
    }

    if (!pImage)
        return BadMatch;

    width = stuff.width;
    height = stuff.height;
    size = (*pPort.pAdaptor.ddQueryImageAttributes) (pPort, pImage, &width,
                                                       &height, null, null);
    size += xvPutImageReq.sizeof;
    size = cast(int)bytes_to_int32(size);

    if ((width < stuff.width) || (height < stuff.height))
        return BadValue;

    if (client.req_len < size)
        return BadLength;

    return XvdiPutImage(client, pDraw, pPort, pGC, stuff.src_x, stuff.src_y,
                        stuff.src_w, stuff.src_h, stuff.drw_x, stuff.drw_y,
                        stuff.drw_w, stuff.drw_h, pImage,
                        cast(ubyte*) (&stuff[1]), FALSE,
                        stuff.width, stuff.height);
}

static if(XINERAMA){

}

private int ProcXvPutImage(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xvPutImageReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"gc");
    mixin(X_REQUEST_FIELD_CARD32!"id");
    mixin(X_REQUEST_FIELD_CARD16!"src_x");
    mixin(X_REQUEST_FIELD_CARD16!"src_y");
    mixin(X_REQUEST_FIELD_CARD16!"src_w");
    mixin(X_REQUEST_FIELD_CARD16!"src_h");
    mixin(X_REQUEST_FIELD_CARD16!"drw_x");
    mixin(X_REQUEST_FIELD_CARD16!"drw_y");
    mixin(X_REQUEST_FIELD_CARD16!"drw_w");
    mixin(X_REQUEST_FIELD_CARD16!"drw_h");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");

static if(XINERAMA){
    if (xvUseXinerama)
        return XineramaXvPutImage(client);
}
    return SingleXvPutImage(client);
}

static if(CONFIG_MITSHM){

private int SingleXvShmPutImage(ClientPtr client)
{
    ShmDescPtr shmdesc = void;
    DrawablePtr pDraw = void;
    XvPortPtr pPort = void;
    XvImagePtr pImage = null;
    GCPtr pGC = void;
    int status = void, size_needed = void, i = void;
    CARD16 width = void, height = void;

    mixin(REQUEST!xvShmPutImageReq);

    mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.drawable", "pDraw", "DixWriteAccess"));
    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    if (!(pPort.pAdaptor.type & XvImageMask) ||
        !(pPort.pAdaptor.type & XvInputMask)) {
        client.errorValue = cast(uint)stuff.port;
        return BadMatch;
    }

    status = XvdiMatchPort(pPort, pDraw);
    if (status != Success) {
        return status;
    }

    for (i = 0; i < pPort.pAdaptor.nImages; i++) {
        if (pPort.pAdaptor.pImages[i].id == stuff.id) {
            pImage = &(pPort.pAdaptor.pImages[i]);
            break;
        }
    }

    if (!pImage)
        return BadMatch;

    status = dixLookupResourceByType(cast(void**) &shmdesc, stuff.shmseg,
                                     ShmSegType, serverClient, DixReadAccess);
    if (status != Success)
        return status;

    width = stuff.width;
    height = stuff.height;
    size_needed = (*pPort.pAdaptor.ddQueryImageAttributes) (pPort, pImage,
                                                              &width, &height,
                                                              null, null);
    if ((size_needed + stuff.offset) > shmdesc.size)
        return BadAccess;

    if ((width < stuff.width) || (height < stuff.height))
        return BadValue;

    status = XvdiPutImage(client, pDraw, pPort, pGC, stuff.src_x, stuff.src_y,
                          stuff.src_w, stuff.src_h, stuff.drw_x,
                          stuff.drw_y, stuff.drw_w, stuff.drw_h, pImage,
                          cast(ubyte*) shmdesc.addr + stuff.offset,
                          stuff.send_event, stuff.width, stuff.height);

    if ((status == Success) && stuff.send_event) {
        xShmCompletionEvent ev = {
            type: cast(ubyte)ShmCompletionCode,
            drawable: stuff.drawable,
            minorEvent: xv_ShmPutImage,
            majorEvent: cast(ubyte)XvReqCode,
            shmseg: stuff.shmseg,
            offset: stuff.offset
        };
        WriteEventsToClient(client, 1, cast(xEvent*) &ev);
    }

    return status;
}

static if(XINERAMA){

}

} /* CONFIG_MITSHM */

private int ProcXvShmPutImage(ClientPtr client)
{
static if(CONFIG_MITSHM){
    mixin(X_REQUEST_HEAD_STRUCT!xvShmPutImageReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"drawable");
    mixin(X_REQUEST_FIELD_CARD32!"gc");
    mixin(X_REQUEST_FIELD_CARD32!"shmseg");
    mixin(X_REQUEST_FIELD_CARD32!"id");
    mixin(X_REQUEST_FIELD_CARD32!"offset");
    mixin(X_REQUEST_FIELD_CARD16!"src_x");
    mixin(X_REQUEST_FIELD_CARD16!"src_y");
    mixin(X_REQUEST_FIELD_CARD16!"src_w");
    mixin(X_REQUEST_FIELD_CARD16!"src_h");
    mixin(X_REQUEST_FIELD_CARD16!"drw_x");
    mixin(X_REQUEST_FIELD_CARD16!"drw_y");
    mixin(X_REQUEST_FIELD_CARD16!"drw_w");
    mixin(X_REQUEST_FIELD_CARD16!"drw_h");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");

static if(XINERAMA){
    if (xvUseXinerama)
        return XineramaXvShmPutImage(client);
}
    return SingleXvShmPutImage(client);
} else {
    return BadImplementation;
} /* CONFIG_MITSHM */
}

mixin __size_assert!(int, INT32.sizeof);

private int ProcXvQueryImageAttributes(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvQueryImageAttributesReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"id");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");

    int size = void, num_planes = void, i = void;
    CARD16 width = void, height = void;
    XvImagePtr pImage = null;
    XvPortPtr pPort = void;

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    for (i = 0; i < pPort.pAdaptor.nImages; i++) {
        if (pPort.pAdaptor.pImages[i].id == stuff.id) {
            pImage = &(pPort.pAdaptor.pImages[i]);
            break;
        }
    }

static if(XvMCExtension) {
    if (!pImage)
        pImage = XvMCFindXvImage(pPort, stuff.id);
}

    if (!pImage)
        return BadMatch;

    num_planes = pImage.num_planes;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    /* allocating for `offsets` as well as `pitches` in one block */
    /* both having CARD32 * num_planes (actually int32_t put into CARD32) */
    int* offsets = cast(int*)x_rpcbuf_reserve(&rpcbuf, 2 * num_planes * int.sizeof);
    if (!offsets)
        return BadAlloc;
    int* pitches = offsets + num_planes;

    width = stuff.width;
    height = stuff.height;

    size = (*pPort.pAdaptor.ddQueryImageAttributes) (pPort, pImage,
                                                       &width, &height, offsets,
                                                       pitches);

    xvQueryImageAttributesReply reply = {
        num_planes: num_planes,
        width: width,
        height: height,
        data_size: size
    };

    if (client.swapped) {
        /* needed here, because ddQueryImageAttributes() directly wrote into
           our rpcbuf area */
        SwapLongs(cast(CARD32*) offsets, x_rpcbuf_wsize_units(&rpcbuf));
    }

    mixin(X_REPLY_FIELD_CARD32!"num_planes");
    mixin(X_REPLY_FIELD_CARD32!"data_size");
    mixin(X_REPLY_FIELD_CARD16!"width");
    mixin(X_REPLY_FIELD_CARD16!"height");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvListImageFormats(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvListImageFormatsReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");

    XvPortPtr pPort = void;
    XvImagePtr pImage = void;
    int i = void;

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    pImage = pPort.pAdaptor.pImages;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    for (i = 0; i < pPort.pAdaptor.nImages; i++, pImage++) {
        /* xvImageFormatInfo */
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.id);
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pImage.type);
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pImage.byte_order);
        x_rpcbuf_reserve(&rpcbuf, CARD16.sizeof); /* pad1; */
        x_rpcbuf_write_binary_pad(&rpcbuf, pImage.guid.ptr, 16);
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pImage.bits_per_pixel);
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pImage.num_planes);
        x_rpcbuf_reserve(&rpcbuf, CARD16.sizeof); /* pad2; */
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pImage.depth);
        x_rpcbuf_reserve(&rpcbuf, ((CARD8).sizeof+CARD16.sizeof)); /* pad3, pad4 */
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.red_mask);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.green_mask);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.blue_mask);
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pImage.format);
        x_rpcbuf_reserve(&rpcbuf, ((CARD8).sizeof+CARD16.sizeof)); /* pad5, pad6 */
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.y_sample_bits);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.u_sample_bits);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.v_sample_bits);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.horz_y_period);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.horz_u_period);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.horz_v_period);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.vert_y_period);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.vert_u_period);
        x_rpcbuf_write_CARD32(&rpcbuf, pImage.vert_v_period);
        x_rpcbuf_write_binary_pad(&rpcbuf, pImage.component_order.ptr, 32);
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)cast(ubyte)pImage.scanline_order);
        x_rpcbuf_reserve(&rpcbuf, CARD8.sizeof+CARD16.sizeof+CARD32.sizeof*32); /* pad7, pad8, pad9, pad10 */
    }

    /* use rpc.wpos here, in order to get how much we've really written */
    if (rpcbuf.wpos != (pPort.pAdaptor.nImages*sz_xvImageFormatInfo))
        LogMessage(X_WARNING, "ProcXvListImageFormats() payload_len mismatch: %llu but shoud be %d\n",
                   cast(ulong)rpcbuf.wpos, (pPort.pAdaptor.nImages*sz_xvImageFormatInfo));

    xvListImageFormatsReply reply = {
        num_formats: pPort.pAdaptor.nImages,
    };

    mixin(X_REPLY_FIELD_CARD32!"num_formats");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcXvDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    UpdateCurrentTime();

    switch (stuff.data) {
        case xv_QueryExtension:
            return ProcXvQueryExtension(client);
        case xv_QueryAdaptors:
            return ProcXvQueryAdaptors(client);
        case xv_QueryEncodings:
            return ProcXvQueryEncodings(client);
        case xv_GrabPort:
            return ProcXvGrabPort(client);
        case xv_UngrabPort:
            return ProcXvUngrabPort(client);
        case xv_PutVideo:
            return ProcXvPutVideo(client);
        case xv_PutStill:
            return ProcXvPutStill(client);
        case xv_GetVideo:
            return ProcXvGetVideo(client);
        case xv_GetStill:
            return ProcXvGetStill(client);
        case xv_StopVideo:
            return ProcXvStopVideo(client);
        case xv_SelectVideoNotify:
            return ProcXvSelectVideoNotify(client);
        case xv_SelectPortNotify:
            return ProcXvSelectPortNotify(client);
        case xv_QueryBestSize:
            return ProcXvQueryBestSize(client);
        case xv_SetPortAttribute:
            return ProcXvSetPortAttribute(client);
        case xv_GetPortAttribute:
            return ProcXvGetPortAttribute(client);
        case xv_QueryPortAttributes:
            return ProcXvQueryPortAttributes(client);
        case xv_ListImageFormats:
            return ProcXvListImageFormats(client);
        case xv_QueryImageAttributes:
            return ProcXvQueryImageAttributes(client);
        case xv_PutImage:
            return ProcXvPutImage(client);
        case xv_ShmPutImage:
            return ProcXvShmPutImage(client);
        default:
            return BadRequest;
    }
}

static if(XINERAMA){
private int XineramaXvStopVideo(ClientPtr client)
{
    int result = void;
    PanoramiXRes* draw = void, port = void;

    mixin(REQUEST!xvStopVideoReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    result = dixLookupResourceByType(cast(void**) &port, stuff.port,
                                     cast(uint)XvXRTPort, client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (port.info[walkScreenIdx].id) {
            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.port = port.info[walkScreenIdx].id;
            result = SingleXvStopVideo(client);
        }
    }));

    return result;
}

private int XineramaXvSetPortAttribute(ClientPtr client)
{
    mixin(REQUEST!xvSetPortAttributeReq);
    PanoramiXRes* port = void;
    int result = void;

    result = dixLookupResourceByType(cast(void**) &port, stuff.port,
                                     cast(uint)XvXRTPort, client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (port.info[walkScreenIdx].id) {
            stuff.port = port.info[walkScreenIdx].id;
            result = SingleXvSetPortAttribute(client);
        }
    }));

    return result;
}

static if(CONFIG_MITSHM){
private int XineramaXvShmPutImage(ClientPtr client)
{
    mixin(REQUEST!xvShmPutImageReq);
    PanoramiXRes* draw = void, gc = void, port = void;
    Bool send_event = void;
    Bool isRoot = void;
    int result = void, x = void, y = void;

    send_event = stuff.send_event;

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc,
                                     XRT_GC, client, DixReadAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &port, stuff.port,
                                     cast(uint)XvXRTPort, client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = (draw.type == XRT_WINDOW) && draw.u.win.root;

    x = stuff.drw_x;
    y = stuff.drw_y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (port.info[walkScreenIdx].id) {
            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.port = port.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            stuff.drw_x = cast(short)x;
            stuff.drw_y = cast(short)y;
            if (isRoot) {
                stuff.drw_x -= walkScreen.x;
                stuff.drw_y -= walkScreen.y;
            }
            stuff.send_event = (send_event && !walkScreenIdx) ? 1 : 0;

            result = SingleXvShmPutImage(client);
        }
    }));

    return result;
}
} else { /* CONFIG_MITSHM */
enum XineramaXvShmPutImage = ProcXvShmPutImage;
} /* CONFIG_MITSHM */

private int XineramaXvPutImage(ClientPtr client)
{
    mixin(REQUEST!xvPutImageReq);
    PanoramiXRes* draw = void, gc = void, port = void;
    Bool isRoot = void;
    int result = void, x = void, y = void;

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc,
                                     XRT_GC, client, DixReadAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &port, stuff.port,
                                     cast(uint)XvXRTPort, client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = (draw.type == XRT_WINDOW) && draw.u.win.root;

    x = stuff.drw_x;
    y = stuff.drw_y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (port.info[walkScreenIdx].id) {
            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.port = port.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            stuff.drw_x = cast(short)x;
            stuff.drw_y = cast(short)y;
            if (isRoot) {
                stuff.drw_x -= walkScreen.x;
                stuff.drw_y -= walkScreen.y;
            }

            result = SingleXvPutImage(client);
        }
    }));

    return result;
}

private int XineramaXvPutVideo(ClientPtr client)
{
    mixin(REQUEST!xvPutImageReq);
    PanoramiXRes* draw = void, gc = void, port = void;
    Bool isRoot = void;
    int result = void, x = void, y = void;

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc,
                                     XRT_GC, client, DixReadAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &port, stuff.port,
                                     cast(uint)XvXRTPort, client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = (draw.type == XRT_WINDOW) && draw.u.win.root;

    x = stuff.drw_x;
    y = stuff.drw_y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (port.info[walkScreenIdx].id) {
            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.port = port.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            stuff.drw_x = cast(short)x;
            stuff.drw_y = cast(short)y;
            if (isRoot) {
                stuff.drw_x -= walkScreen.x;
                stuff.drw_y -= walkScreen.y;
            }

            result = SingleXvPutVideo(client);
        }
    }));

    return result;
}

private int XineramaXvPutStill(ClientPtr client)
{
    mixin(REQUEST!xvPutImageReq);
    PanoramiXRes* draw = void, gc = void, port = void;
    Bool isRoot = void;
    int result = void, x = void, y = void;

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc,
                                     XRT_GC, client, DixReadAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &port, stuff.port,
                                     cast(uint)XvXRTPort, client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = (draw.type == XRT_WINDOW) && draw.u.win.root;

    x = stuff.drw_x;
    y = stuff.drw_y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (port.info[walkScreenIdx].id) {
            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.port = port.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            stuff.drw_x = cast(short)x;
            stuff.drw_y = cast(short)y;
            if (isRoot) {
                stuff.drw_x -= walkScreen.x;
                stuff.drw_y -= walkScreen.y;
            }
            result = cast(short)SingleXvPutStill(client);
        }
    }));

    return result;
}

private Bool isImageAdaptor(XvAdaptorPtr pAdapt)
{
    return (pAdapt.type & XvImageMask) && (pAdapt.nImages > 0);
}

private Bool hasOverlay(XvAdaptorPtr pAdapt)
{
    int i = void;

    for (i = 0; i < pAdapt.nAttributes; i++)
        if (!strcmp(pAdapt.pAttributes[i].name, "XV_COLORKEY"))
            return TRUE;
    return FALSE;
}

private XvAdaptorPtr matchAdaptor(ScreenPtr pScreen, XvAdaptorPtr refAdapt, Bool isOverlay)
{
    int i = void;
    XvScreenPtr xvsp = cast(_XvScreenRec*)dixLookupPrivate(&pScreen.devPrivates, XvGetScreenKey());
    /* Do not try to go on if xv is not supported on this screen */
    if (xvsp is null)
        return null;

    /* if the adaptor has the same name it's a perfect match */
    for (i = 0; i < xvsp.nAdaptors; i++) {
        XvAdaptorPtr pAdapt = xvsp.pAdaptors + i;

        if (!strcmp(refAdapt.name, pAdapt.name))
            return pAdapt;
    }

    /* otherwise we only look for XvImage adaptors */
    if (!isImageAdaptor(refAdapt))
        return null;

    /* prefer overlay/overlay non-overlay/non-overlay pairing */
    for (i = 0; i < xvsp.nAdaptors; i++) {
        XvAdaptorPtr pAdapt = xvsp.pAdaptors + i;

        if (isImageAdaptor(pAdapt) && isOverlay == hasOverlay(pAdapt))
            return pAdapt;
    }

    /* but we'll take any XvImage pairing if we can get it */
    for (i = 0; i < xvsp.nAdaptors; i++) {
        XvAdaptorPtr pAdapt = xvsp.pAdaptors + i;

        if (isImageAdaptor(pAdapt))
            return pAdapt;
    }
    return null;
}

void XineramifyXv()
{
    XvScreenPtr xvsp0 = cast(_XvScreenRec*)dixLookupPrivate(&(dixGetMasterScreen().devPrivates), XvGetScreenKey());
    XvAdaptorPtr[MAXSCREENS] MatchingAdaptors = void;
    int i = void;

    XvXRTPort = CreateNewResourceType(&XineramaDeleteResource, "XvXRTPort");

    if (!xvsp0 || !XvXRTPort)
        return;
    SetResourceTypeErrorValue(cast(uint)XvXRTPort, _XvBadPort);

    for (i = 0; i < xvsp0.nAdaptors; i++) {
        Bool isOverlay = void;
        XvAdaptorPtr refAdapt = xvsp0.pAdaptors + i;

        if (!(refAdapt.type & XvInputMask))
            continue;

        MatchingAdaptors[0] = refAdapt;
        isOverlay = hasOverlay(refAdapt);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD_SKIP0!(q{
            MatchingAdaptors[walkScreenIdx] = matchAdaptor(walkScreen, refAdapt, isOverlay);
        }));

        /* now create a resource for each port */
        for (int j = 0; j < refAdapt.nPorts; j++) {
            PanoramiXRes* port = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof);

            if (!port)
                break;

            mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
                if (MatchingAdaptors[walkScreenIdx] && (MatchingAdaptors[walkScreenIdx].nPorts > j))
                    port.info[walkScreenIdx].id = cast(int)(MatchingAdaptors[walkScreenIdx].base_id + j);
                else
                    port.info[walkScreenIdx].id = 0;
            }));

            AddResource(cast(uint)port.info[0].id, cast(uint)XvXRTPort, port);
        }
    }

    xvUseXinerama = 1;
}
} /* XINERAMA */
