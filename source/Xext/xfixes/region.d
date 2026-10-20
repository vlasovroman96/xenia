module xfixes.region;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2003 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.xlibre_server;;

import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.window_priv;
import render.picturestr_priv;
import Xext.panoramiX;
import Xext.panoramiXsrv;

import xfixes.xfixesint;
import include.scrnintstr;

import include.regionstr;
import include.gcstruct;
import include.window;
import externs.X11.extensions.xfixesproto;
import externs.X11.extensions.render_;

import region;
import dix.swapreq;
import render.picture;
import dix.gc;
import Xext.shape;

RESTYPE RegionResType;

private int RegionResFree(void* data, XID id)
{
    RegionPtr pRegion = cast(RegionPtr) data;

    RegionDestroy(pRegion);
    return Success;
}

RegionPtr XFixesRegionCopy(RegionPtr pRegion)
{
    RegionPtr pNew = RegionCreate(RegionExtents(pRegion),
                                  RegionNumRects(pRegion));

    if (!pNew)
        return null;
    if (!RegionCopy(pNew, pRegion)) {
        RegionDestroy(pNew);
        return null;
    }
    return pNew;
}

Bool XFixesRegionInit()
{
    RegionResType = CreateNewResourceType(&RegionResFree, "XFixesRegion");

    return RegionResType != 0;
}

int ProcXFixesCreateRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXFixesCreateRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_REST_CARD16!());

    int things = void;
    RegionPtr pRegion = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.region", "client"));

    things = cast(int)((client.req_len << 2) - xXFixesCreateRegionReq.sizeof);
    if (things & 4)
        return BadLength;
    things >>= 3;

    pRegion = RegionFromRects(things, cast(xRectangle*) (stuff + 1), CT_UNSORTED);
    if (!pRegion)
        return BadAlloc;
    if (!AddResource(cast(uint)stuff.region, RegionResType, cast(void*) pRegion))
        return BadAlloc;

    return Success;
}

int ProcXFixesCreateRegionFromBitmap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesCreateRegionFromBitmapReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD32!"bitmap");

    RegionPtr pRegion = void;
    PixmapPtr pPixmap = void;
    int rc = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.region", "client"));

    rc = dixLookupResourceByType(cast(void**) &pPixmap, stuff.bitmap, X11_RESTYPE_PIXMAP,
                                 client, DixReadAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.bitmap;
        return rc;
    }
    if (pPixmap.drawable.depth != 1)
        return BadMatch;

    pRegion = BitmapToRegion(pPixmap.drawable.pScreen, pPixmap);

    if (!pRegion)
        return BadAlloc;

    if (!AddResource(cast(uint)stuff.region, RegionResType, cast(void*) pRegion))
        return BadAlloc;

    return Success;
}

int ProcXFixesCreateRegionFromWindow(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesCreateRegionFromWindowReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD32!"window");

    RegionPtr pRegion = void;
    Bool copy = TRUE;
    WindowPtr pWin = void;
    int rc = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.region", "client"));
    rc = dixLookupResourceByType(cast(void**) &pWin, stuff.window, X11_RESTYPE_WINDOW,
                                 client, DixGetAttrAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }
    switch (stuff.kind) {
    case WindowRegionBounding:
        pRegion = mixin(wBoundingShape!("pWin"));
        if (!pRegion) {
            pRegion = CreateBoundingShape(pWin);
            copy = FALSE;
        }
        break;
    case WindowRegionClip:
        pRegion = mixin(wClipShape!("pWin"));
        if (!pRegion) {
            pRegion = CreateClipShape(pWin);
            copy = FALSE;
        }
        break;
    default:
        client.errorValue = cast(uint)stuff.kind;
        return BadValue;
    }
    if (copy && pRegion)
        pRegion = XFixesRegionCopy(pRegion);
    if (!pRegion)
        return BadAlloc;
    if (!AddResource(cast(uint)stuff.region, RegionResType, cast(void*) pRegion))
        return BadAlloc;

    return Success;
}

int ProcXFixesCreateRegionFromGC(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesCreateRegionFromGCReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD32!"gc");

    RegionPtr pRegion = void, pClip = void;
    GCPtr pGC = void;
    int rc = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.region", "client"));

    rc = dixLookupGC(&pGC, stuff.gc, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    if (pGC.clientClip) {
        pClip = cast(RegionPtr) pGC.clientClip;
        pRegion = XFixesRegionCopy(pClip);
        if (!pRegion)
            return BadAlloc;
    } else {
        return BadMatch;
    }

    if (!AddResource(cast(uint)stuff.region, RegionResType, cast(void*) pRegion))
        return BadAlloc;

    return Success;
}

int ProcXFixesCreateRegionFromPicture(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesCreateRegionFromPictureReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD32!"picture");

    RegionPtr pRegion = void;
    PicturePtr pPicture = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.region", "client"));

    mixin(VERIFY_PICTURE!("pPicture", "stuff.picture", "client", "DixGetAttrAccess"));

    if (!pPicture.pDrawable)
        return RenderErrBase + BadPicture;

    if (pPicture.clientClip) {
        pRegion = XFixesRegionCopy(cast(RegionPtr) pPicture.clientClip);
        if (!pRegion)
            return BadAlloc;
    } else {
        return BadMatch;
    }

    if (!AddResource(cast(uint)stuff.region, RegionResType, cast(void*) pRegion))
        return BadAlloc;

    return Success;
}

int ProcXFixesDestroyRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesDestroyRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");

    RegionPtr pRegion = void;

    mixin(VERIFY_REGION!("pRegion", "stuff.region", "client", "DixWriteAccess"));
    FreeResource(cast(uint)stuff.region, X11_RESTYPE_NONE);
    return Success;
}

int ProcXFixesSetRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXFixesSetRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_REST_CARD16!());

    int things = void;
    RegionPtr pRegion = void, pNew = void;

    mixin(VERIFY_REGION!("pRegion", "stuff.region", "client", "DixWriteAccess"));

    things = cast(int)((client.req_len << 2) - xXFixesCreateRegionReq.sizeof);
    if (things & 4)
        return BadLength;
    things >>= 3;

    pNew = RegionFromRects(things, cast(xRectangle*) (stuff + 1), CT_UNSORTED);
    if (!pNew)
        return BadAlloc;
    if (!RegionCopy(pRegion, pNew)) {
        RegionDestroy(pNew);
        return BadAlloc;
    }
    RegionDestroy(pNew);
    return Success;
}

int ProcXFixesCopyRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesCopyRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"source");
    mixin(X_REQUEST_FIELD_CARD32!"destination");

    RegionPtr pSource = void, pDestination = void;

    mixin(VERIFY_REGION!("pSource", "stuff.source", "client", "DixReadAccess"));
    mixin(VERIFY_REGION!("pDestination", "stuff.destination", "client", "DixWriteAccess"));

    if (!RegionCopy(pDestination, pSource))
        return BadAlloc;

    return Success;
}

int ProcXFixesCombineRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesCombineRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"source1");
    mixin(X_REQUEST_FIELD_CARD32!"source2");
    mixin(X_REQUEST_FIELD_CARD32!"destination");

    RegionPtr pSource1 = void, pSource2 = void, pDestination = void;

    mixin(VERIFY_REGION!("pSource1", "stuff.source1", "client", "DixReadAccess"));
    mixin(VERIFY_REGION!("pSource2", "stuff.source2", "client", "DixReadAccess"));
    mixin(VERIFY_REGION!("pDestination", "stuff.destination", "client", "DixWriteAccess"));

    switch (stuff.xfixesReqType) {
    case X_XFixesUnionRegion:
        if (!RegionUnion(pDestination, pSource1, pSource2))
            return BadAlloc;
        break;
    case X_XFixesIntersectRegion:
        if (!RegionIntersect(pDestination, pSource1, pSource2))
            return BadAlloc;
        break;
    case X_XFixesSubtractRegion:
        if (!RegionSubtract(pDestination, pSource1, pSource2))
            return BadAlloc;
        break;
    default: break;}

    return Success;
}

int ProcXFixesInvertRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesInvertRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"source");
    mixin(X_REQUEST_FIELD_CARD16!"x");
    mixin(X_REQUEST_FIELD_CARD16!"y");
    mixin(X_REQUEST_FIELD_CARD16!"width");
    mixin(X_REQUEST_FIELD_CARD16!"height");
    mixin(X_REQUEST_FIELD_CARD32!"destination");

    RegionPtr pSource = void, pDestination = void;
    BoxRec bounds = void;

    mixin(VERIFY_REGION!("pSource", "stuff.source", "client", "DixReadAccess"));
    mixin(VERIFY_REGION!("pDestination", "stuff.destination", "client", "DixWriteAccess"));

    /* Compute bounds, limit to 16 bits */
    bounds.x1 = stuff.x;
    bounds.y1 = stuff.y;
    if (cast(int) stuff.x + cast(int) stuff.width > MAXSHORT)
        bounds.x2 = cast(short)(MAXSHORT);
    else
        bounds.x2 = cast(short)(stuff.x + stuff.width);

    if (cast(int) stuff.y + cast(int) stuff.height > MAXSHORT)
        bounds.y2 = cast(short)(MAXSHORT);
    else
        bounds.y2 = cast(short)(stuff.y + stuff.height);

    if (!RegionInverse(pDestination, pSource, &bounds))
        return BadAlloc;

    return Success;
}

int ProcXFixesTranslateRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesTranslateRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD16!"dx");
    mixin(X_REQUEST_FIELD_CARD16!"dy");

    RegionPtr pRegion = void;

    mixin(VERIFY_REGION!("pRegion", "stuff.region", "client", "DixWriteAccess"));

    RegionTranslate(pRegion, stuff.dx, stuff.dy);
    return Success;
}

int ProcXFixesRegionExtents(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesRegionExtentsReq);
    mixin(X_REQUEST_FIELD_CARD32!"source");
    mixin(X_REQUEST_FIELD_CARD32!"destination");

    RegionPtr pSource = void, pDestination = void;

    mixin(VERIFY_REGION!("pSource", "stuff.source", "client", "DixReadAccess"));
    mixin(VERIFY_REGION!("pDestination", "stuff.destination", "client", "DixWriteAccess"));

    RegionReset(pDestination, RegionExtents(pSource));

    return Success;
}

int ProcXFixesFetchRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesFetchRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");

    RegionPtr pRegion = void;
    mixin(VERIFY_REGION!("pRegion", "stuff.region", "client", "DixReadAccess"));

    BoxPtr pExtent = RegionExtents(pRegion);
    BoxPtr pBox = RegionRects(pRegion);
    int nBox = RegionNumRects(pRegion);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    for (int i = 0; i < nBox; i++) {
        x_rpcbuf_write_rect(&rpcbuf,
                            pBox[i].x1,
                            pBox[i].y1,
                            cast(ushort)(pBox[i].x2 - pBox[i].x1),
                            cast(ushort)(pBox[i].y2 - pBox[i].y1));
    }

    xXFixesFetchRegionReply reply = {
        x: pExtent.x1,
        y: pExtent.y1,
        width: cast(ushort)(pExtent.x2 - pExtent.x1),
        height: cast(ushort)(pExtent.y2 - pExtent.y1),
    };

    mixin(X_REPLY_FIELD_CARD16!"x");
    mixin(X_REPLY_FIELD_CARD16!"y");
    mixin(X_REPLY_FIELD_CARD16!"width");
    mixin(X_REPLY_FIELD_CARD16!"height");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

static if(XINERAMA){

}



int ProcXFixesSetGCClipRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesSetGCClipRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"gc");
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD16!"xOrigin");
    mixin(X_REQUEST_FIELD_CARD16!"yOrigin");

static if(XINERAMA){
    if (XFixesUseXinerama)
        return PanoramiXFixesSetGCClipRegion(client, stuff);
}
    return SingleXFixesSetGCClipRegion(client, stuff);
}

private int SingleXFixesSetGCClipRegion(ClientPtr client, xXFixesSetGCClipRegionReq* stuff)
{
    GCPtr pGC = void;
    int rc = dixLookupGC(&pGC, stuff.gc, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;

    RegionPtr pRegion = void;
    mixin(VERIFY_REGION_OR_NONE!("pRegion", "stuff.region", "client", "DixReadAccess"));

    if (pRegion) {
        pRegion = XFixesRegionCopy(pRegion);
        if (!pRegion)
            return BadAlloc;
    }

    ChangeGCVal[2] vals = void;
    vals[0].val = stuff.xOrigin;
    vals[1].val = stuff.yOrigin;
    ChangeGC(null, pGC, cast(uint)(GCClipXOrigin | GCClipYOrigin), vals.ptr);
    (*pGC.funcs.ChangeClip) (pGC, pRegion ? CT_REGION : CT_NONE,
                               cast(void*) pRegion, 0);

    return Success;
}

alias CreateDftPtr = RegionPtr function(WindowPtr pWin);

private int SingleXFixesSetWindowShapeRegion(ClientPtr client, xXFixesSetWindowShapeRegionReq* stuff)
{

    WindowPtr pWin = void;
    int rc = dixLookupResourceByType(cast(void**) &pWin, stuff.dest, X11_RESTYPE_WINDOW,
                                 client, DixSetAttrAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.dest;
        return rc;
    }

    RegionPtr pRegion = void;
    mixin(VERIFY_REGION_OR_NONE!("pRegion", "stuff.region", "client", "DixWriteAccess"));
    switch (stuff.destKind) {
    case ShapeBounding:
    case ShapeClip:
    case ShapeInput:
        break;
    default:
        client.errorValue = cast(uint)stuff.destKind;
        return BadValue;
    }

    RegionPtr* pDestRegion = null;

    if (pRegion) {
        pRegion = XFixesRegionCopy(pRegion);
        if (!pRegion)
            return BadAlloc;
        if (!MakeWindowOptional(pWin))
            return BadAlloc;
        switch (stuff.destKind) {
        default:
        case ShapeBounding:
            pDestRegion = &pWin.optional.boundingShape;
            break;
        case ShapeClip:
            pDestRegion = &pWin.optional.clipShape;
            break;
        case ShapeInput:
            pDestRegion = &pWin.optional.inputShape;
            break;
        }
        if (stuff.xOff || stuff.yOff)
            RegionTranslate(pRegion, stuff.xOff, stuff.yOff);
    }
    else {
        if (pWin.optional) {
            switch (stuff.destKind) {
            default:
            case ShapeBounding:
                pDestRegion = &pWin.optional.boundingShape;
                break;
            case ShapeClip:
                pDestRegion = &pWin.optional.clipShape;
                break;
            case ShapeInput:
                pDestRegion = &pWin.optional.inputShape;
                break;
            }
        }
        else
            pDestRegion = &pRegion;     /* a NULL region pointer */
    }
    if (*pDestRegion)
        RegionDestroy(*pDestRegion);
    *pDestRegion = pRegion;
    (*pWin.drawable.pScreen.SetShape) (pWin, stuff.destKind);
    SendShapeNotify(pWin, stuff.destKind);
    return Success;
}

static if(XINERAMA){

}

int ProcXFixesSetWindowShapeRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesSetWindowShapeRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"dest");
    mixin(X_REQUEST_FIELD_CARD16!"xOff");
    mixin(X_REQUEST_FIELD_CARD16!"yOff");
    mixin(X_REQUEST_FIELD_CARD32!"region");

static if(XINERAMA){
    if (XFixesUseXinerama)
        return PanoramiXFixesSetWindowShapeRegion(client, stuff);
}
    return SingleXFixesSetWindowShapeRegion(client, stuff);
}



static if(XINERAMA){

}

int ProcXFixesSetPictureClipRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesSetPictureClipRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"picture");
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD16!"xOrigin");
    mixin(X_REQUEST_FIELD_CARD16!"yOrigin");

static if(XINERAMA){
    if (XFixesUseXinerama)
        return PanoramiXFixesSetPictureClipRegion(client, stuff);
}
    return SingleXFixesSetPictureClipRegion(client, stuff);
}

private int SingleXFixesSetPictureClipRegion(ClientPtr client, xXFixesSetPictureClipRegionReq* stuff)
{
    PicturePtr pPicture = void;
    RegionPtr pRegion = void;

    mixin(VERIFY_PICTURE!("pPicture", "stuff.picture", "client", "DixSetAttrAccess"));
    mixin(VERIFY_REGION_OR_NONE!("pRegion", "stuff.region", "client", "DixReadAccess"));

    if (!pPicture.pDrawable)
        return RenderErrBase + BadPicture;

    return SetPictureClipRegion(pPicture, stuff.xOrigin, stuff.yOrigin,
                                pRegion);
}

int ProcXFixesExpandRegion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesExpandRegionReq);
    mixin(X_REQUEST_FIELD_CARD32!"source");
    mixin(X_REQUEST_FIELD_CARD32!"destination");
    mixin(X_REQUEST_FIELD_CARD16!"left");
    mixin(X_REQUEST_FIELD_CARD16!"right");
    mixin(X_REQUEST_FIELD_CARD16!"top");
    mixin(X_REQUEST_FIELD_CARD16!"bottom");

    RegionPtr pSource = void, pDestination = void;
    mixin(VERIFY_REGION!("pSource", "stuff.source", "client", "DixReadAccess"));
    mixin(VERIFY_REGION!("pDestination", "stuff.destination", "client", "DixWriteAccess"));

    int nBoxes = RegionNumRects(pSource);
    BoxPtr pSrc = RegionRects(pSource);
    if (nBoxes) {
        BoxPtr pTmp = cast(BoxPtr) calloc(nBoxes, BoxRec.sizeof);
        if (!pTmp)
            return BadAlloc;
        for (int i = 0; i < nBoxes; i++) {
            pTmp[i].x1 = cast(short)(pSrc[i].x1 - stuff.left);
            pTmp[i].x2 = cast(short)(pSrc[i].x2 + stuff.right);
            pTmp[i].y1 = cast(short)(pSrc[i].y1 - stuff.top);
            pTmp[i].y2 = cast(short)(pSrc[i].y2 + stuff.bottom);
        }
        RegionEmpty(pDestination);
        for (int i = 0; i < nBoxes; i++) {
            RegionRec r = void;
            RegionInit(&r, &pTmp[i], 0);
            RegionUnion(pDestination, pDestination, &r);
        }
        free(pTmp);
    }
    return Success;
}

static if(XINERAMA){

private int PanoramiXFixesSetGCClipRegion(ClientPtr client, xXFixesSetGCClipRegionReq* stuff)
{
    int result = Success;
    PanoramiXRes* gc = void;

    if ((result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                          client, DixWriteAccess)) != 0) {
        client.errorValue = cast(uint)stuff.gc;
        return result;
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        result = SingleXFixesSetGCClipRegion(client, stuff);
        if (result != Success)
            break;
    }));

    return result;
}

private int PanoramiXFixesSetWindowShapeRegion(ClientPtr client, xXFixesSetWindowShapeRegionReq* stuff)
{
    int result = Success;
    PanoramiXRes* win = void;
    RegionPtr reg = null;

    if ((result = dixLookupResourceByType(cast(void**) &win, stuff.dest,
                                          XRT_WINDOW, client,
                                          DixWriteAccess)) != 0) {
        client.errorValue = cast(uint)stuff.dest;
        return result;
    }

    if (win.u.win.root)
        mixin(VERIFY_REGION_OR_NONE!("reg", "stuff.region", "client", "DixReadAccess"));

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.dest = win.info[walkScreenIdx].id;

        if (reg)
            RegionTranslate(reg, -walkScreen.x, -walkScreen.y);

        result = SingleXFixesSetWindowShapeRegion(client, stuff);

        if (reg)
            RegionTranslate(reg, walkScreen.x, walkScreen.y);

        if (result != Success)
            break;
    }));

    return result;
}

private int PanoramiXFixesSetPictureClipRegion(ClientPtr client, xXFixesSetPictureClipRegionReq* stuff)
{
    int result = Success;
    PanoramiXRes* pict = void;
    RegionPtr reg = null;

    if ((result = dixLookupResourceByType(cast(void**) &pict, stuff.picture,
                                          XRT_PICTURE, client,
                                          DixWriteAccess)) != 0) {
        client.errorValue = cast(uint)stuff.picture;
        return result;
    }

    if (pict.u.pict.root)
        mixin(VERIFY_REGION_OR_NONE!("reg", "stuff.region", "client", "DixReadAccess"));

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.picture = pict.info[walkScreenIdx].id;

        if (reg)
            RegionTranslate(reg, -walkScreen.x, -walkScreen.y);

        result = SingleXFixesSetPictureClipRegion(client, stuff);

        if (reg)
            RegionTranslate(reg, walkScreen.x, walkScreen.y);

        if (result != Success)
            break;
    }));

    return result;
}

} /* XINERAMA */
