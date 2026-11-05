module Xext.xvmc;
@nogc nothrow:
extern(C): __gshared:

import build.dix_config;

import core.stdc.string;
//import x11.X;
// //import x11.Xfuncproto;
//import x11.Xproto;
// //import externs.X11.extensions.XvMC;
// //import externs.X11.extensions.Xvproto;
// //import externs.X11.extensions.XvMCproto;

import dix.dix_priv;
import dix.request_priv;
import dix.screen_hooks_priv;
import include.xvmcext;
import miext.extinit_priv;
import Xext.xvdix_priv;

import common.misc;
import include.os;
import dix.dixstruct_priv;
import include.resource;
import include.scrnintstr;
import dix.extension;
import include.servermd;
import externs.X11.extensions.XvMCproto;
import dix.dixutils;
import externs.X11.extensions.XvMC;
import dix.extension;
import dix.screen_hooks;
import Xext.xvmain;


enum SERVER_XVMC_MAJOR_VERSION =               1;
enum SERVER_XVMC_MINOR_VERSION =               1;

enum DR_CLIENT_DRIVER_NAME_SIZE = 48;
enum DR_BUSID_SIZE = 48;

private DevPrivateKeyRec XvMCScreenKeyRec;
private Bool XvMCInUse;

int XvMCReqCode;
int XvMCEventBase;

private RESTYPE XvMCRTContext;
private RESTYPE XvMCRTSurface;
private RESTYPE XvMCRTSubpicture;

struct _XvMCScreenRec {
    int num_adaptors;
    XvMCAdaptorPtr adaptors;
    char[DR_CLIENT_DRIVER_NAME_SIZE] clientDriverName = 0;
    char[DR_BUSID_SIZE] busID = 0;
    int major;
    int minor;
    int patchLevel;
}alias XvMCScreenRec = _XvMCScreenRec;
alias XvMCScreenPtr = XvMCScreenRec*;

enum string XVMC_GET_PRIVATE(string pScreen) = `
    cast(XvMCScreenPtr)(dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, &XvMCScreenKeyRec))`;

private int XvMCDestroyContextRes(void* data, XID id)
{
    XvMCContextPtr pContext = cast(XvMCContextPtr) data;

    pContext.refcnt--;

    if (!pContext.refcnt) {
        XvMCScreenPtr pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pContext.pScreen`));

        (*pScreenPriv.adaptors[pContext.adapt_num].DestroyContext) (pContext);
        free(pContext);
    }

    return Success;
}

private int XvMCDestroySurfaceRes(void* data, XID id)
{
    XvMCSurfacePtr pSurface = cast(XvMCSurfacePtr) data;
    XvMCContextPtr pContext = pSurface.context;
    XvMCScreenPtr pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pContext.pScreen`));

    (*pScreenPriv.adaptors[pContext.adapt_num].DestroySurface) (pSurface);
    free(pSurface);

    XvMCDestroyContextRes(cast(void*) pContext, pContext.context_id);

    return Success;
}

private int XvMCDestroySubpictureRes(void* data, XID id)
{
    XvMCSubpicturePtr pSubpict = cast(XvMCSubpicturePtr) data;
    XvMCContextPtr pContext = pSubpict.context;
    XvMCScreenPtr pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pContext.pScreen`));

    (*pScreenPriv.adaptors[pContext.adapt_num].DestroySubpicture) (pSubpict);
    free(pSubpict);

    XvMCDestroyContextRes(cast(void*) pContext, pContext.context_id);

    return Success;
}

private int ProcXvMCQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcQueryVersionReq);

    xvmcQueryVersionReply reply = {
        major: SERVER_XVMC_MAJOR_VERSION,
        minor: SERVER_XVMC_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD32!"major");
    mixin(X_REPLY_FIELD_CARD32!"minor");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXvMCListSurfaceTypes(ClientPtr client)
{
    XvPortPtr pPort = void;
    XvMCScreenPtr pScreenPriv = void;
    XvMCAdaptorPtr adaptor = null;

    mixin(X_REQUEST_HEAD_STRUCT!xvmcListSurfaceTypesReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    if (XvMCInUse) {            /* any adaptors at all */
        ScreenPtr pScreen = pPort.pAdaptor.pScreen;

        if ((pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pScreen`))) !is null) {        /* any this screen */
            for (int i = 0; i < pScreenPriv.num_adaptors; i++) {
                if (pPort.pAdaptor == pScreenPriv.adaptors[i].xv_adaptor) {
                    adaptor = &(pScreenPriv.adaptors[i]);
                    break;
                }
            }
        }
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    int num_surfaces = (adaptor) ? adaptor.num_surfaces : 0;
    for (int i = 0; i < num_surfaces; i++) {
        XvMCSurfaceInfoPtr surface = adaptor.surfaces[i];

        /* write xvmcSurfaceInfo */
        x_rpcbuf_write_CARD32(&rpcbuf, surface.surface_type_id);
        x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)surface.chroma_format);
        x_rpcbuf_write_CARD16(&rpcbuf, 0);
        x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)surface.max_width);
        x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)surface.max_height);
        x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)surface.subpicture_max_width);
        x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)surface.subpicture_max_height);
        x_rpcbuf_write_CARD32(&rpcbuf, cast(ushort)surface.mc_type);
        x_rpcbuf_write_CARD32(&rpcbuf, cast(ushort)surface.flags);
    }

    xvmcListSurfaceTypesReply reply = {
        num: num_surfaces,
    };

    mixin(X_REPLY_FIELD_CARD32!"num");
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvMCCreateContext(ClientPtr client)
{
    XvPortPtr pPort = void;
    CARD32* data = null;
    int dwords = 0;
    int result = void, adapt_num = -1;
    ScreenPtr pScreen = void;
    XvMCContextPtr pContext = void;
    XvMCScreenPtr pScreenPriv = void;
    XvMCAdaptorPtr adaptor = null;
    XvMCSurfaceInfoPtr surface = null;

    mixin(X_REQUEST_HEAD_STRUCT!xvmcCreateContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"context_id");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");
    mixin(X_REQUEST_FIELD_CARD32!"flags");

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    pScreen = pPort.pAdaptor.pScreen;

    if (!XvMCInUse)             /* no XvMC adaptors */
        return BadMatch;

    if (((pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pScreen`))) !is null))     /* none this screen */
        return BadMatch;

    for (int i = 0; i < pScreenPriv.num_adaptors; i++) {
        if (pPort.pAdaptor == pScreenPriv.adaptors[i].xv_adaptor) {
            adaptor = &(pScreenPriv.adaptors[i]);
            adapt_num = i;
            break;
        }
    }

    if (adapt_num < 0)          /* none this port */
        return BadMatch;

    for (int i = 0; i < adaptor.num_surfaces; i++) {
        if (adaptor.surfaces[i].surface_type_id == stuff.surface_type_id) {
            surface = adaptor.surfaces[i];
            break;
        }
    }

    /* adaptor doesn't support this surface_type_id */
    if (!surface)
        return BadMatch;

    if ((stuff.width > surface.max_width) ||
        (stuff.height > surface.max_height))
        return BadValue;

    if (((pContext = cast(XvMCContextPtr)cast(XvMCContextRec*) calloc(1, XvMCContextRec.sizeof)) !is null)) {
        return BadAlloc;
    }

    pContext.pScreen = pScreen;
    pContext.adapt_num = adapt_num;
    pContext.context_id = stuff.context_id;
    pContext.surface_type_id = cast(int)stuff.surface_type_id;
    pContext.width = stuff.width;
    pContext.height = stuff.height;
    pContext.flags = stuff.flags;
    pContext.refcnt = 1;

    result = (*adaptor.CreateContext) (pPort, pContext, &dwords, &data);

    if (result != Success) {
        free(pContext);
        return result;
    }
    if (!AddResource(cast(uint)pContext.context_id, XvMCRTContext, pContext)) {
        free(data);
        return BadAlloc;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(&rpcbuf, data, dwords);
    free(data);

    xvmcCreateContextReply reply = {
        width_actual: pContext.width,
        height_actual: pContext.height,
        flags_return: pContext.flags
    };

    mixin(X_REPLY_FIELD_CARD16!"width_actual");
    mixin(X_REPLY_FIELD_CARD16!"height_actual");
    mixin(X_REPLY_FIELD_CARD32!"flags_return");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvMCDestroyContext(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcDestroyContextReq);
    mixin(X_REQUEST_FIELD_CARD32!"context_id");

    void* val = void;

    int rc = dixLookupResourceByType(&val, stuff.context_id, XvMCRTContext,
                                 client, DixDestroyAccess);
    if (rc != Success)
        return rc;

    FreeResource(cast(uint)stuff.context_id, X11_RESTYPE_NONE);

    return Success;
}

private int ProcXvMCCreateSurface(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcCreateSurfaceReq);
    mixin(X_REQUEST_FIELD_CARD32!"surface_id");
    mixin(X_REQUEST_FIELD_CARD32!"context_id");

    CARD32* data = null;
    int dwords = 0;
    int result = void;
    XvMCContextPtr pContext = void;
    XvMCSurfacePtr pSurface = void;
    XvMCScreenPtr pScreenPriv = void;

    result = dixLookupResourceByType(cast(void**) &pContext, stuff.context_id,
                                     XvMCRTContext, client, DixUseAccess);
    if (result != Success)
        return result;

    pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pContext.pScreen`));

    if (((pSurface = cast(XvMCSurfacePtr)cast(XvMCSurfaceRec*) calloc(1, XvMCSurfaceRec.sizeof)) !is null))
        return BadAlloc;

    pSurface.surface_id = stuff.surface_id;
    pSurface.surface_type_id = pContext.surface_type_id;
    pSurface.context = pContext;

    result =
        (*pScreenPriv.adaptors[pContext.adapt_num].CreateSurface) (pSurface,
                                                                     &dwords,
                                                                     &data);

    if (result != Success) {
        free(pSurface);
        return result;
    }
    if (!AddResource(cast(uint)pSurface.surface_id, XvMCRTSurface, pSurface)) {
        free(data);
        return BadAlloc;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(&rpcbuf, data, dwords);
    free(data);

    xvmcCreateSurfaceReply reply = { 0 };

    pContext.refcnt++;

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvMCDestroySurface(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcDestroySurfaceReq);
    mixin(X_REQUEST_FIELD_CARD32!"surface_id");

    void* val = void;

    int rc = dixLookupResourceByType(&val, stuff.surface_id, XvMCRTSurface,
                                 client, DixDestroyAccess);
    if (rc != Success)
        return rc;

    FreeResource(cast(uint)stuff.surface_id, X11_RESTYPE_NONE);

    return Success;
}

private int ProcXvMCCreateSubpicture(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcCreateSubpictureReq);
    mixin(X_REQUEST_FIELD_CARD32!"subpicture_id");
    mixin(X_REQUEST_FIELD_CARD32!"context_id");
    mixin(X_REQUEST_FIELD_CARD32!"xvimage_id");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");

    Bool image_supported = FALSE;
    CARD32* data = null;
    int result = void, dwords = 0;
    XvMCContextPtr pContext = void;
    XvMCSubpicturePtr pSubpicture = void;
    XvMCScreenPtr pScreenPriv = void;
    XvMCAdaptorPtr adaptor = void;
    XvMCSurfaceInfoPtr surface = null;

    result = dixLookupResourceByType(cast(void**) &pContext, stuff.context_id,
                                     XvMCRTContext, client, DixUseAccess);
    if (result != Success)
        return result;

    pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pContext.pScreen`));

    adaptor = &(pScreenPriv.adaptors[pContext.adapt_num]);

    /* find which surface this context supports */
    for (int i = 0; i < adaptor.num_surfaces; i++) {
        if (adaptor.surfaces[i].surface_type_id == pContext.surface_type_id) {
            surface = adaptor.surfaces[i];
            break;
        }
    }

    if (!surface)
        return BadMatch;

    /* make sure this surface supports that xvimage format */
    if (!surface.compatible_subpictures)
        return BadMatch;

    for (int i = 0; i < surface.compatible_subpictures.num_xvimages; i++) {
        if (surface.compatible_subpictures.xvimage_ids[i] ==
            stuff.xvimage_id) {
            image_supported = TRUE;
            break;
        }
    }

    if (!image_supported)
        return BadMatch;

    /* make sure the size is OK */
    if ((stuff.width > surface.subpicture_max_width) ||
        (stuff.height > surface.subpicture_max_height))
        return BadValue;

    if (((pSubpicture = cast(XvMCSubpicturePtr)cast(XvMCSubpictureRec*) calloc(1, XvMCSubpictureRec.sizeof)) !is null))
        return BadAlloc;

    pSubpicture.subpicture_id = stuff.subpicture_id;
    pSubpicture.xvimage_id = cast(int)stuff.xvimage_id;
    pSubpicture.width = stuff.width;
    pSubpicture.height = stuff.height;
    pSubpicture.num_palette_entries = 0;       /* overwritten by DDX */
    pSubpicture.entry_bytes = 0;       /* overwritten by DDX */
    pSubpicture.component_order[0] = 0;        /* overwritten by DDX */
    pSubpicture.component_order[1] = 0;
    pSubpicture.component_order[2] = 0;
    pSubpicture.component_order[3] = 0;
    pSubpicture.context = pContext;

    result =
        (*pScreenPriv.adaptors[pContext.adapt_num].
         CreateSubpicture) (pSubpicture, &dwords, &data);

    if (result != Success) {
        free(pSubpicture);
        return result;
    }
    if (!AddResource(cast(uint)pSubpicture.subpicture_id, XvMCRTSubpicture, pSubpicture)) {
        free(data);
        return BadAlloc;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(&rpcbuf, data, dwords);
    free(data);

    xvmcCreateSubpictureReply reply;
        reply.width_actual = pSubpicture.width;
        reply.height_actual = pSubpicture.height;
        reply.num_palette_entries = cast(ushort)pSubpicture.num_palette_entries;
        reply.entry_bytes = cast(ushort)pSubpicture.entry_bytes;
        reply.component_order[0] = pSubpicture.component_order[0];
        reply.component_order[1] = pSubpicture.component_order[1];
        reply.component_order[2] = pSubpicture.component_order[2];
        reply.component_order[3] = pSubpicture.component_order[3];

    mixin(X_REPLY_FIELD_CARD16!"width_actual");
    mixin(X_REPLY_FIELD_CARD16!"height_actual");
    mixin(X_REPLY_FIELD_CARD16!"num_palette_entries");
    mixin(X_REPLY_FIELD_CARD16!"entry_bytes");

    pContext.refcnt++;

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvMCDestroySubpicture(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcDestroySubpictureReq);
    mixin(X_REQUEST_FIELD_CARD32!"subpicture_id");

    void* val = void;

    int rc = dixLookupResourceByType(&val, stuff.subpicture_id, XvMCRTSubpicture,
                                 client, DixDestroyAccess);
    if (rc != Success)
        return rc;

    FreeResource(cast(uint)stuff.subpicture_id, X11_RESTYPE_NONE);

    return Success;
}

private int ProcXvMCListSubpictureTypes(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcListSubpictureTypesReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"surface_type_id");

    XvPortPtr pPort = void;
    XvMCScreenPtr pScreenPriv = void;
    ScreenPtr pScreen = void;
    XvMCAdaptorPtr adaptor = null;
    XvMCSurfaceInfoPtr surface = null;
    XvImagePtr pImage = void;

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    pScreen = pPort.pAdaptor.pScreen;

    if (!dixPrivateKeyRegistered(&XvMCScreenKeyRec))
        return BadMatch;        /* No XvMC adaptors */

    if (((pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pScreen`))) !is null))
        return BadMatch;        /* None this screen */

    for (int i = 0; i < pScreenPriv.num_adaptors; i++) {
        if (pPort.pAdaptor == pScreenPriv.adaptors[i].xv_adaptor) {
            adaptor = &(pScreenPriv.adaptors[i]);
            break;
        }
    }

    if (!adaptor)
        return BadMatch;

    for (int i = 0; i < adaptor.num_surfaces; i++) {
        if (adaptor.surfaces[i].surface_type_id == stuff.surface_type_id) {
            surface = adaptor.surfaces[i];
            break;
        }
    }

    if (!surface)
        return BadMatch;

    int num = (surface.compatible_subpictures ?
               surface.compatible_subpictures.num_xvimages : 0);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (num) {
        for (int i = 0; i < num; i++) {
            pImage = null;
            for (int j = 0; j < adaptor.num_subpictures; j++) {
                if (surface.compatible_subpictures.xvimage_ids[i] ==
                    adaptor.subpictures[j].id) {
                    pImage = adaptor.subpictures[j];
                    break;
                }
            }
            if (!pImage) {
                return BadImplementation;
            }

            /* xvImageFormatInfo */
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.id);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)pImage.type);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)pImage.byte_order);
            x_rpcbuf_write_CARD16(&rpcbuf, 0); /* pad1 */
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)pImage.guid, 16);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)pImage.bits_per_pixel);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)pImage.num_planes);
            x_rpcbuf_write_CARD16(&rpcbuf, 0); /* pad2 */
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)pImage.depth);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)0); /* pad3 */
            x_rpcbuf_write_CARD16(&rpcbuf, 0); /* pad4 */
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.red_mask);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.green_mask);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.blue_mask);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)pImage.format);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)0); /* pad5 */
            x_rpcbuf_write_CARD16(&rpcbuf, 0); /* pad6 */
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.y_sample_bits);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.u_sample_bits);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.v_sample_bits);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.horz_y_period);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.horz_u_period);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.horz_v_period);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.vert_y_period);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.vert_u_period);
            x_rpcbuf_write_CARD32(&rpcbuf, pImage.vert_v_period);
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)pImage.component_order, 32);
            x_rpcbuf_write_CARD8(&rpcbuf,  cast(ubyte)pImage.scanline_order);
            x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)0); /* pad7 */
            x_rpcbuf_write_CARD16(&rpcbuf, 0); /* pad8 */
            x_rpcbuf_write_CARD32(&rpcbuf, 0); /* pad9 */
            x_rpcbuf_write_CARD32(&rpcbuf, 0); /* pad10 */
        }
    }

    xvmcListSubpictureTypesReply reply = {
        num: num,
    };

    mixin(X_REPLY_FIELD_CARD32!"num");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvMCGetDRInfo(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xvmcGetDRInfoReq);
    mixin(X_REQUEST_FIELD_CARD32!"port");
    mixin(X_REQUEST_FIELD_CARD32!"shmKey");
    mixin(X_REQUEST_FIELD_CARD32!"magic");

    XvPortPtr pPort = void;
    ScreenPtr pScreen = void;
    XvMCScreenPtr pScreenPriv = void;

    mixin(VALIDATE_XV_PORT!("stuff.port", "pPort", "DixReadAccess"));

    pScreen = pPort.pAdaptor.pScreen;
    pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pScreen`));

    int nameLen = cast(int)strlen(pScreenPriv.clientDriverName.ptr) + 1;
    int busIDLen = cast(int)strlen(pScreenPriv.busID.ptr) + 1;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)pScreenPriv.clientDriverName, nameLen);
    x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)pScreenPriv.busID, busIDLen);

    xvmcGetDRInfoReply reply = {
        major: pScreenPriv.major,
        minor: pScreenPriv.minor,
        patchLevel: pScreenPriv.patchLevel,
        nameLen: nameLen,
        busIDLen: busIDLen,
        isLocal: 1
    };

    /*
     * Read back to the client what she has put in the shared memory
     * segment she prepared for us.
     */
    mixin(X_REPLY_FIELD_CARD32!"major");
    mixin(X_REPLY_FIELD_CARD32!"minor");
    mixin(X_REPLY_FIELD_CARD32!"patchLevel");
    mixin(X_REPLY_FIELD_CARD32!"nameLen");
    mixin(X_REPLY_FIELD_CARD32!"busIDLen");
    mixin(X_REPLY_FIELD_CARD32!"isLocal");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcXvMCDispatch(ClientPtr client)
{
    if (!(client.local))
        return BadImplementation;

    mixin(REQUEST!xReq);
    switch (stuff.data)
    {
        case xvmc_QueryVersion:
            return ProcXvMCQueryVersion(client);
        case xvmc_ListSurfaceTypes:
            return ProcXvMCListSurfaceTypes(client);
        case xvmc_CreateContext:
            return ProcXvMCCreateContext(client);
        case xvmc_DestroyContext:
            return ProcXvMCDestroyContext(client);
        case xvmc_CreateSurface:
            return ProcXvMCCreateSurface(client);
        case xvmc_DestroySurface:
            return ProcXvMCDestroySurface(client);
        case xvmc_CreateSubpicture:
            return ProcXvMCCreateSubpicture(client);
        case xvmc_DestroySubpicture:
            return ProcXvMCDestroySubpicture(client);
        case xvmc_ListSubpictureTypes:
            return ProcXvMCListSubpictureTypes(client);
        case xvmc_GetDRInfo:
            return ProcXvMCGetDRInfo(client);
        default:
            return BadRequest;
    }
}

void XvMCExtensionInit()
{
    ExtensionEntry* extEntry = void;

    if (!dixPrivateKeyRegistered(&XvMCScreenKeyRec))
        return;

    if (((XvMCRTContext = CreateNewResourceType(&XvMCDestroyContextRes,
                                                "XvMCRTContext")) == 0))
        return;

    if (((XvMCRTSurface = CreateNewResourceType(&XvMCDestroySurfaceRes,
                                                "XvMCRTSurface")) == 0))
        return;

    if (((XvMCRTSubpicture = CreateNewResourceType(&XvMCDestroySubpictureRes,
                                                   "XvMCRTSubpicture")) == 0))
        return;

    extEntry = AddExtension(XvMCName, XvMCNumEvents, XvMCNumErrors,
                            &ProcXvMCDispatch, &ProcXvMCDispatch,
                            null, &StandardMinorOpcode);

    if (!extEntry)
        return;

    XvMCReqCode = extEntry.base;
    XvMCEventBase = extEntry.eventBase;
    SetResourceTypeErrorValue(XvMCRTContext,
                              extEntry.errorBase + XvMCBadContext);
    SetResourceTypeErrorValue(XvMCRTSurface,
                              extEntry.errorBase + XvMCBadSurface);
    SetResourceTypeErrorValue(XvMCRTSubpicture,
                              extEntry.errorBase + XvMCBadSubpicture);
}

private void XvMCScreenClose(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    XvMCScreenPtr pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pScreen`));
    free(pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, &XvMCScreenKeyRec, null);
    dixScreenUnhookClose(pScreen, &XvMCScreenClose);
}

int XvMCScreenInit(ScreenPtr pScreen, int num, XvMCAdaptorPtr pAdapt)
{
    XvMCScreenPtr pScreenPriv = void;

    if (!dixRegisterPrivateKey(&XvMCScreenKeyRec, PRIVATE_SCREEN, 0))
        return BadAlloc;

    if (((pScreenPriv = cast(XvMCScreenPtr)cast(XvMCScreenRec*) calloc(1, XvMCScreenRec.sizeof)) !is null))
        return BadAlloc;

    dixSetPrivate(&pScreen.devPrivates, &XvMCScreenKeyRec, pScreenPriv);

    dixScreenHookClose(pScreen, &XvMCScreenClose);

    pScreenPriv.num_adaptors = num;
    pScreenPriv.adaptors = pAdapt;
    pScreenPriv.clientDriverName[0] = 0;
    pScreenPriv.busID[0] = 0;
    pScreenPriv.major = 0;
    pScreenPriv.minor = 0;
    pScreenPriv.patchLevel = 0;

    XvMCInUse = TRUE;

    return Success;
}

XvImagePtr XvMCFindXvImage(XvPortPtr pPort, CARD32 id)
{
    XvImagePtr pImage = null;
    ScreenPtr pScreen = pPort.pAdaptor.pScreen;
    XvMCScreenPtr pScreenPriv = void;
    XvMCAdaptorPtr adaptor = null;

    if (!dixPrivateKeyRegistered(&XvMCScreenKeyRec))
        return null;

    if (((pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pScreen`))) !is null))
        return null;

    for (int i = 0; i < pScreenPriv.num_adaptors; i++) {
        if (pPort.pAdaptor == pScreenPriv.adaptors[i].xv_adaptor) {
            adaptor = &(pScreenPriv.adaptors[i]);
            break;
        }
    }

    if (!adaptor)
        return null;

    for (int i = 0; i < adaptor.num_subpictures; i++) {
        if (adaptor.subpictures[i].id == id) {
            pImage = adaptor.subpictures[i];
            break;
        }
    }

    return pImage;
}

int xf86XvMCRegisterDRInfo(ScreenPtr pScreen, const(char)* name, const(char)* busID, int major, int minor, int patchLevel)
{
    XvMCScreenPtr pScreenPriv = mixin(XVMC_GET_PRIVATE!(`pScreen`));

    strlcpy(pScreenPriv.clientDriverName.ptr, name, DR_CLIENT_DRIVER_NAME_SIZE);
    strlcpy(pScreenPriv.busID.ptr, busID, DR_BUSID_SIZE);
    pScreenPriv.major = major;
    pScreenPriv.minor = minor;
    pScreenPriv.patchLevel = patchLevel;
    return Success;
}
