module Xext.shape;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Copyright 1989, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

********************************************************/

import build.xlibre_server;
import Xext.panoramiXsrv;

import core.stdc.stdlib;
//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.shapeproto;
import region;

import dix.client_priv;
import dix.dix_priv;
import dix.gc_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.screenint_priv;
import dix.screen_hooks_priv;
import dix.window_priv;
import miext.extinit_priv;
import Xext.panoramiX;
import Xext.panoramiXsrv;
import dix.dispatch;

import common.misc;
import os.os;
import include.windowstr;
import include.scrnintstr;
import dix.pixmap;
import dix.dixstruct_priv;
import dix.window;
import include.regionstr;
import dix.gc;
import include.protocol_versions;
import externs.X11.extensions.shapeproto;
import dix.swapreq;
import dix.dixutils;
import dix.extension;
import dix.events;
import dix.screen_hooks;


Bool noShapeExtension = FALSE;

alias CreateDftPtr = RegionPtr function(WindowPtr);

private DevPrivateKeyRec ShapeWindowPrivateKeyRec;



/* SendShapeNotify, CreateBoundingShape and CreateClipShape are used
 * externally by the Xfixes extension and are now defined in window.h
 */

private int ShapeEventBase = 0;

/*
 * each window has a list of clients requesting
 * ShapeNotify events.  Each client has a resource
 * for each window it selects ShapeNotify input for,
 * this resource is used to delete the ShapeNotifyRec
 * entry from the per-window queue.
 */




struct _ShapeEvent {
    ShapeEventPtr next;
    ClientPtr client;
    WindowPtr window;
}
alias ShapeEventRec = _ShapeEvent;
alias ShapeEventPtr = _ShapeEvent*;

enum string  SHAPE_WINDOW_PRIVADDR(string pWin) = `(cast(ShapeEventPtr*) 
dixLookupPrivateAddr(&(` ~ pWin ~ `).devPrivates, &ShapeWindowPrivateKeyRec))`;

private int ShapeDelClientFromWin(WindowPtr pWin, void* value) {
    ClientPtr client = cast(ClientPtr)value;
    ShapeEventPtr* pHead = mixin(SHAPE_WINDOW_PRIVADDR!(`pWin`));
    ShapeEventPtr* prev = pHead;
    ShapeEventPtr curr = *pHead;

    while (curr) {
        if (curr.client == client) {
            *prev = curr.next;
            free(curr);
            break;
        }
        prev = &curr.next;
        curr = curr.next;
    }
    return WT_WALKCHILDREN;
}

/****************
 * ShapeExtensionInit
 *
 //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
 * Called from InitExtensions in main() or from QueryExtension() if the
 * extension is dynamically loaded.
 *
 ****************/

private int RegionOperate(ClientPtr client, WindowPtr pWin, int kind, RegionPtr* destRgnp, RegionPtr srcRgn, int op, int xoff, int yoff, CreateDftPtr create)
{
    if (srcRgn && (xoff || yoff))
        RegionTranslate(srcRgn, xoff, yoff);
    if (!pWin.parent) {
        if (srcRgn)
            RegionDestroy(srcRgn);
        return Success;
    }

    /* May/30/2001:
     * The shape.PS specs say if src is None, existing shape is to be
     * removed (and so the op-code has no meaning in such removal);
     * see shape.PS, page 3, ShapeMask.
     */
    if (srcRgn is null) {
        if (*destRgnp !is null) {
            RegionDestroy(*destRgnp);
            *destRgnp = null;
            /* go on to remove shape and generate ShapeNotify */
        }
        else {
            /* May/30/2001:
             * The target currently has no shape in effect, so nothing to
             * do here.  The specs say that ShapeNotify is generated whenever
             * the client region is "modified"; since no modification is done
             * here, we do not generate that event.  The specs does not say
             * "it is an error to request removal when there is no shape in
             * effect", so we return good status.
             */
            return Success;
        }
    }
    else
        switch (op) {
        case ShapeSet:
            if (*destRgnp)
                RegionDestroy(*destRgnp);
            *destRgnp = srcRgn;
            srcRgn = null;
            break;
        case ShapeUnion:
            if (*destRgnp)
                RegionUnion(*destRgnp, *destRgnp, srcRgn);
            break;
        case ShapeIntersect:
            if (*destRgnp)
                RegionIntersect(*destRgnp, *destRgnp, srcRgn);
            else {
                *destRgnp = srcRgn;
                srcRgn = null;
            }
            break;
        case ShapeSubtract:
            if (!*destRgnp)
                *destRgnp = (*create) (pWin);
            RegionSubtract(*destRgnp, *destRgnp, srcRgn);
            break;
        case ShapeInvert:
            if (!*destRgnp)
                *destRgnp = RegionCreate(cast(BoxPtr) 0, 0);
            else
                RegionSubtract(*destRgnp, srcRgn, *destRgnp);
            break;
        default:
            client.errorValue = cast(uint)op;
            return BadValue;
        }
    if (srcRgn)
        RegionDestroy(srcRgn);
    (*pWin.drawable.pScreen.SetShape) (pWin, kind);
    SendShapeNotify(pWin, kind);
    return Success;
}

RegionPtr CreateBoundingShape(WindowPtr pWin)
{
    BoxRec extents = void;

    extents.x1 = cast(short)-mixin(wBorderWidth!("pWin"));
    extents.y1 = cast(short)-mixin(wBorderWidth!("pWin"));
    extents.x2 = cast(short)(pWin.drawable.width + mixin(wBorderWidth!("pWin")));
    extents.y2 = cast(short)(pWin.drawable.height + mixin(wBorderWidth!("pWin")));
    return RegionCreate(&extents, 1);
}

RegionPtr CreateClipShape(WindowPtr pWin)
{
    BoxRec extents = void;

    extents.x1 = 0;
    extents.y1 = 0;
    extents.x2 = pWin.drawable.width;
    extents.y2 = pWin.drawable.height;
    return RegionCreate(&extents, 1);
}

private int ProcShapeQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xShapeQueryVersionReq);

    xShapeQueryVersionReply reply = {
        majorVersion: SERVER_SHAPE_MAJOR_VERSION,
        minorVersion: SERVER_SHAPE_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ShapeRectangles(ClientPtr client, xShapeRectanglesReq* stuff)
{
    WindowPtr pWin = void;
    xRectangle* prects = void;
    int nrects = void, ctype = void, rc = void;
    RegionPtr srcRgn = void;
    RegionPtr* destRgn = void;
    CreateDftPtr createDefault = void;

    UpdateCurrentTime();
    rc = dixLookupWindow(&pWin, stuff.dest, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;
    switch (stuff.destKind) {
    case ShapeBounding:
        createDefault = &CreateBoundingShape;
        break;
    case ShapeClip:
        createDefault = &CreateClipShape;
        break;
    case ShapeInput:
        createDefault = &CreateBoundingShape;
        break;
    default:
        client.errorValue = cast(uint)stuff.destKind;
        return BadValue;
    }
    if ((stuff.ordering != Unsorted) && (stuff.ordering != YSorted) &&
        (stuff.ordering != YXSorted) && (stuff.ordering != YXBanded)) {
        client.errorValue = cast(uint)stuff.ordering;
        return BadValue;
    }
    nrects = cast(int)((client.req_len << 2) - xShapeRectanglesReq.sizeof);
    if (nrects & 4)
        return BadLength;
    nrects >>= 3;
    prects = cast(xRectangle*) &stuff[1];
    ctype = VerifyRectOrder(nrects, prects, cast(int) stuff.ordering);
    if (ctype < 0)
        return BadMatch;
    srcRgn = RegionFromRects(nrects, prects, ctype);

    if (!MakeWindowOptional(pWin))
        return BadAlloc;

    switch (stuff.destKind) {
    case ShapeBounding:
        destRgn = &pWin.optional.boundingShape;
        break;
    case ShapeClip:
        destRgn = &pWin.optional.clipShape;
        break;
    case ShapeInput:
        destRgn = &pWin.optional.inputShape;
        break;
    default:
        return BadValue;
    }

    return RegionOperate(client, pWin, cast(int) stuff.destKind,
                         destRgn, srcRgn, cast(int) stuff.op,
                         stuff.xOff, stuff.yOff, createDefault);
}

private int ProcShapeRectangles(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xShapeRectanglesReq);
    mixin(X_REQUEST_FIELD_CARD32!"dest");
    mixin(X_REQUEST_FIELD_CARD16!"xOff");
    mixin(X_REQUEST_FIELD_CARD16!"yOff");
    mixin(X_REQUEST_REST_CARD16!());

static if(XINERAMA){
    if (noPanoramiXExtension)
        return ShapeRectangles(client, stuff);

    PanoramiXRes* win = void;
    int result = void;

    result = dixLookupResourceByType(cast(void**) &win, stuff.dest, XRT_WINDOW,
                                     client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.dest = win.info[walkScreenIdx].id;
        result = ShapeRectangles(client, stuff);
        if (result != Success)
            break;
    }));

    return result;
} else {
    return ShapeRectangles(client, stuff);
}
}

private int ShapeMask(ClientPtr client, xShapeMaskReq* stuff)
{
    WindowPtr pWin = void;
    ScreenPtr pScreen = void;
    RegionPtr srcRgn = void;
    RegionPtr* destRgn = void;
    PixmapPtr pPixmap = void;
    CreateDftPtr createDefault = void;

    UpdateCurrentTime();
    int rc = dixLookupWindow(&pWin, stuff.dest, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;
    switch (stuff.destKind) {
    case ShapeBounding:
        createDefault = &CreateBoundingShape;
        break;
    case ShapeClip:
        createDefault = &CreateClipShape;
        break;
    case ShapeInput:
        createDefault = &CreateBoundingShape;
        break;
    default:
        client.errorValue = cast(uint)stuff.destKind;
        return BadValue;
    }
    pScreen = pWin.drawable.pScreen;
    if (stuff.src == None)
        srcRgn = null;
    else {
        rc = dixLookupResourceByType(cast(void**) &pPixmap, stuff.src,
                                     X11_RESTYPE_PIXMAP, client, DixReadAccess);
        if (rc != Success)
            return rc;
        if (pPixmap.drawable.pScreen != pScreen ||
            pPixmap.drawable.depth != 1)
            return BadMatch;
        srcRgn = BitmapToRegion(pScreen, pPixmap);
        if (!srcRgn)
            return BadAlloc;
    }

    if (!MakeWindowOptional(pWin))
        return BadAlloc;

    switch (stuff.destKind) {
    case ShapeBounding:
        destRgn = &pWin.optional.boundingShape;
        break;
    case ShapeClip:
        destRgn = &pWin.optional.clipShape;
        break;
    case ShapeInput:
        destRgn = &pWin.optional.inputShape;
        break;
    default:
        return BadValue;
    }

    return RegionOperate(client, pWin, cast(int) stuff.destKind,
                         destRgn, srcRgn, cast(int) stuff.op,
                         stuff.xOff, stuff.yOff, createDefault);
}

private int ProcShapeMask(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xShapeMaskReq);
    mixin(X_REQUEST_FIELD_CARD32!"dest");
    mixin(X_REQUEST_FIELD_CARD16!"xOff");
    mixin(X_REQUEST_FIELD_CARD16!"yOff");
    mixin(X_REQUEST_FIELD_CARD32!"src");

static if(XINERAMA){
    if (noPanoramiXExtension)
        return ShapeMask(client, stuff);

    PanoramiXRes* win = void, pmap = void;
    int result = void;

    result = dixLookupResourceByType(cast(void**) &win, stuff.dest, XRT_WINDOW,
                                     client, DixWriteAccess);
    if (result != Success)
        return result;

    if (stuff.src != None) {
        result = dixLookupResourceByType(cast(void**) &pmap, stuff.src,
                                         XRT_PIXMAP, client, DixReadAccess);
        if (result != Success)
            return result;
    }
    else
        pmap = null;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.dest = win.info[walkScreenIdx].id;
        if (pmap)
            stuff.src = pmap.info[walkScreenIdx].id;
        result = ShapeMask(client, stuff);
        if (result != Success)
            break;
    }));

    return result;
} else {
    return ShapeMask(client, stuff);
}
}

private int ShapeCombine(ClientPtr client, xShapeCombineReq* stuff)
{
    WindowPtr pSrcWin = void, pDestWin = void;
    RegionPtr srcRgn = void;
    RegionPtr* destRgn = void;
    CreateDftPtr createDefault = void;
    CreateDftPtr createSrc = void;
    RegionPtr tmp = void;

    UpdateCurrentTime();
    int rc = dixLookupWindow(&pDestWin, stuff.dest, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;
    if (!MakeWindowOptional(pDestWin))
        return BadAlloc;

    switch (stuff.destKind) {
    case ShapeBounding:
        createDefault = &CreateBoundingShape;
        break;
    case ShapeClip:
        createDefault = &CreateClipShape;
        break;
    case ShapeInput:
        createDefault = &CreateBoundingShape;
        break;
    default:
        client.errorValue = cast(uint)stuff.destKind;
        return BadValue;
    }

    rc = dixLookupWindow(&pSrcWin, stuff.src, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;
    switch (stuff.srcKind) {
    case ShapeBounding:
        srcRgn = mixin(wBoundingShape!("pSrcWin"));
        createSrc = &CreateBoundingShape;
        break;
    case ShapeClip:
        srcRgn = mixin(wClipShape!("pSrcWin"));
        createSrc = &CreateClipShape;
        break;
    case ShapeInput:
        srcRgn = mixin(wInputShape!("pSrcWin"));
        createSrc = &CreateBoundingShape;
        break;
    default:
        client.errorValue = cast(uint)stuff.srcKind;
        return BadValue;
    }
    if (pSrcWin.drawable.pScreen != pDestWin.drawable.pScreen) {
        return BadMatch;
    }

    if (srcRgn) {
        tmp = RegionCreate(cast(BoxPtr) 0, 0);
        RegionCopy(tmp, srcRgn);
        srcRgn = tmp;
    }
    else
        srcRgn = (*createSrc) (pSrcWin);

    if (!MakeWindowOptional(pDestWin))
        return BadAlloc;

    switch (stuff.destKind) {
    case ShapeBounding:
        destRgn = &pDestWin.optional.boundingShape;
        break;
    case ShapeClip:
        destRgn = &pDestWin.optional.clipShape;
        break;
    case ShapeInput:
        destRgn = &pDestWin.optional.inputShape;
        break;
    default:
        return BadValue;
    }

    return RegionOperate(client, pDestWin, cast(int) stuff.destKind,
                         destRgn, srcRgn, cast(int) stuff.op,
                         stuff.xOff, stuff.yOff, createDefault);
}

private int ProcShapeCombine(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xShapeCombineReq);
    mixin(X_REQUEST_FIELD_CARD32!"dest");
    mixin(X_REQUEST_FIELD_CARD16!"xOff");
    mixin(X_REQUEST_FIELD_CARD16!"yOff");
    mixin(X_REQUEST_FIELD_CARD32!"src");

static if(XINERAMA){
    if (noPanoramiXExtension)
        return ShapeCombine(client, stuff);

    PanoramiXRes* win = void, win2 = void;
    int result = void;

    result = dixLookupResourceByType(cast(void**) &win, stuff.dest, XRT_WINDOW,
                                     client, DixWriteAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &win2, stuff.src, XRT_WINDOW,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.dest = win.info[walkScreenIdx].id;
        stuff.src = win2.info[walkScreenIdx].id;
        result = ShapeCombine(client, stuff);
        if (result != Success)
            break;
    }));

    return result;
} else {
    return ShapeCombine(client, stuff);
}
}

private int ShapeOffset(ClientPtr client, xShapeOffsetReq* stuff)
{
    WindowPtr pWin = void;
    RegionPtr srcRgn = void;

    UpdateCurrentTime();
    int rc = dixLookupWindow(&pWin, stuff.dest, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;
    switch (stuff.destKind) {
    case ShapeBounding:
        srcRgn = mixin(wBoundingShape!("pWin"));
        break;
    case ShapeClip:
        srcRgn = mixin(wClipShape!("pWin"));
        break;
    case ShapeInput:
        srcRgn = mixin(wInputShape!("pWin"));
        break;
    default:
        client.errorValue = cast(uint)stuff.destKind;
        return BadValue;
    }
    if (srcRgn) {
        RegionTranslate(srcRgn, stuff.xOff, stuff.yOff);
        (*pWin.drawable.pScreen.SetShape) (pWin, stuff.destKind);
    }
    SendShapeNotify(pWin, cast(int) stuff.destKind);
    return Success;
}

private int ProcShapeOffset(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xShapeOffsetReq);
    mixin(X_REQUEST_FIELD_CARD32!"dest");
    mixin(X_REQUEST_FIELD_CARD16!"yOff");
    mixin(X_REQUEST_FIELD_CARD16!"yOff");

static if(XINERAMA){
    PanoramiXRes* win = void;
    int result = void;

    if (noPanoramiXExtension)
        return ShapeOffset(client, stuff);

    result = dixLookupResourceByType(cast(void**) &win, stuff.dest, XRT_WINDOW,
                                     client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.dest = win.info[walkScreenIdx].id;
        result = ShapeOffset(client, stuff);
        if (result != Success)
            break;
    }));

    return result;
} else {
    return ShapeOffset(client, stuff);
}
}

private int ProcShapeQueryExtents(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xShapeQueryExtentsReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    RegionPtr boundRegion = void;
    BoxRec boundBox = void;
    if ((boundRegion = mixin(wBoundingShape!("pWin"))) !is null) {
        /* this is done in two steps because of a compiler bug on SunOS 4.1.3 */
        BoxRec* pExtents = RegionExtents(boundRegion);
        boundBox = *pExtents;
    }
    else {
        boundBox.x1 = cast(ushort)-mixin(wBorderWidth!("pWin"));
        boundBox.y1 = cast(ushort)-mixin(wBorderWidth!("pWin"));
        boundBox.x2 = cast(ushort)(pWin.drawable.width + mixin(wBorderWidth!("pWin")));
        boundBox.y2 = cast(ushort)(pWin.drawable.height + mixin(wBorderWidth!("pWin")));
    }

    RegionPtr shapeRegion = void;
    BoxRec shapeBox = void;
    if ((shapeRegion = mixin(wClipShape!("pWin"))) !is null) {
        /* this is done in two steps because of a compiler bug on SunOS 4.1.3 */
        BoxRec* pExtents = RegionExtents(shapeRegion);
        shapeBox = *pExtents;
    }
    else {
        shapeBox.x1 = 0;
        shapeBox.y1 = 0;
        shapeBox.x2 = pWin.drawable.width;
        shapeBox.y2 = pWin.drawable.height;
    }

    xShapeQueryExtentsReply reply = {
        boundingShaped: (mixin(wBoundingShape!("pWin")) !is null),
        clipShaped: (mixin(wClipShape!("pWin")) !is null),
        xBoundingShape: boundBox.x1,
        yBoundingShape: boundBox.y1,
        widthBoundingShape: cast(ushort)(boundBox.x2 - boundBox.x1),
        heightBoundingShape: cast(ushort)(boundBox.y2 - boundBox.y1),
        xClipShape: shapeBox.x1,
        yClipShape: shapeBox.y1,
        widthClipShape: cast(ushort)(shapeBox.x2 - shapeBox.x1),
        heightClipShape: cast(ushort)(shapeBox.y2 - shapeBox.y1),
    };

    mixin(X_REPLY_FIELD_CARD16!"xBoundingShape");
    mixin(X_REPLY_FIELD_CARD16!"yBoundingShape");
    mixin(X_REPLY_FIELD_CARD16!"widthBoundingShape");
    mixin(X_REPLY_FIELD_CARD16!"heightBoundingShape");
    mixin(X_REPLY_FIELD_CARD16!"xClipShape");
    mixin(X_REPLY_FIELD_CARD16!"yClipShape");
    mixin(X_REPLY_FIELD_CARD16!"widthClipShape");
    mixin(X_REPLY_FIELD_CARD16!"heightClipShape");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcShapeSelectInput(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xShapeSelectInputReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    ShapeEventPtr pNewShapeEvent = void;

    mixin(REQUEST_AT_LEAST_SIZE!xShapeSelectInputReq);

    if (client.swapped)
        swapl(&stuff.window);
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixReceiveAccess);
    if (rc != Success)
        return rc;
    ShapeEventPtr pShapeEvent = void; ShapeEventPtr* pHead = mixin(SHAPE_WINDOW_PRIVADDR!(`pWin`));
    switch (stuff.enable) {
    case xTrue:

        /* check for existing entry. */
        for (pShapeEvent = *pHead;
             pShapeEvent; pShapeEvent = pShapeEvent.next) {
            if (pShapeEvent.client == client) {
                return Success;
            }
        }

        /* Form the event */
        pNewShapeEvent = cast(ShapeEventPtr)cast(ShapeEventRec*) calloc(1, ShapeEventRec.sizeof);
        if (!pNewShapeEvent)
            return BadAlloc;
        pNewShapeEvent.next = *pHead;
        pNewShapeEvent.client = client;
        pNewShapeEvent.window = pWin;
        dixSetPrivate(&pWin.devPrivates, &ShapeWindowPrivateKeyRec, pNewShapeEvent);
        break;
    case xFalse:
        /* remove the events with (client) */
        ShapeDelClientFromWin(pWin,client);
        break;
    default:
        client.errorValue = cast(uint)stuff.enable;
        return BadValue;
    }
    return Success;
}

/*
 * deliver the event
 */

void SendShapeNotify(WindowPtr pWin, int which)
{
    BoxRec extents = void;
    RegionPtr region = void;
    BYTE shaped = void;

    ShapeEventPtr pShapeEvent = void; ShapeEventPtr* pHead = mixin(SHAPE_WINDOW_PRIVADDR!(`pWin`));

    switch (which) {
    case ShapeBounding:
        region = mixin(wBoundingShape!("pWin"));
        if (region) {
            extents = *RegionExtents(region);
            shaped = xTrue;
        }
        else {
            extents.x1 = cast(short)-mixin(wBorderWidth!("pWin"));
            extents.y1 = cast(short)-mixin(wBorderWidth!("pWin"));
            extents.x2 = cast(short)(pWin.drawable.width + mixin(wBorderWidth!("pWin")));
            extents.y2 = cast(short)(pWin.drawable.height + mixin(wBorderWidth!("pWin")));
            shaped = xFalse;
        }
        break;
    case ShapeClip:
        region = mixin(wClipShape!("pWin"));
        if (region) {
            extents = *RegionExtents(region);
            shaped = xTrue;
        }
        else {
            extents.x1 = 0;
            extents.y1 = 0;
            extents.x2 = pWin.drawable.width;
            extents.y2 = pWin.drawable.height;
            shaped = xFalse;
        }
        break;
    case ShapeInput:
        region = mixin(wInputShape!("pWin"));
        if (region) {
            extents = *RegionExtents(region);
            shaped = xTrue;
        }
        else {
            extents.x1 = cast(short)-mixin(wBorderWidth!("pWin"));
            extents.y1 = cast(short)-mixin(wBorderWidth!("pWin"));
            extents.x2 = cast(short)(pWin.drawable.width + mixin(wBorderWidth!("pWin")));
            extents.y2 = cast(short)(pWin.drawable.height + mixin(wBorderWidth!("pWin")));
            shaped = xFalse;
        }
        break;
    default:
        return;
    }
    UpdateCurrentTimeIf();
    for (pShapeEvent = *pHead; pShapeEvent; pShapeEvent = pShapeEvent.next) {
        xShapeNotifyEvent se = {
            type: cast(ubyte)(ShapeNotify + ShapeEventBase),
            kind: cast(ubyte)which,
            window: cast(uint)pWin.drawable.id,
            x: extents.x1,
            y: extents.y1,
            width: cast(ushort)(extents.x2 - extents.x1),
            height: cast(ushort)(extents.y2 - extents.y1),
            time: currentTime.milliseconds,
            shaped: shaped
        };
        WriteEventsToClient(pShapeEvent.client, 1, cast(xEvent*) &se);
    }
}

private int ProcShapeInputSelected(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xShapeInputSelectedReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    int enabled = void;

    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    ShapeEventPtr pShapeEvent = void; ShapeEventPtr* pHead = mixin(SHAPE_WINDOW_PRIVADDR!(`pWin`));
    enabled = xFalse;
    if (pHead) {
        for (pShapeEvent = *pHead; pShapeEvent; pShapeEvent = pShapeEvent.next) {
            if (pShapeEvent.client == client) {
                enabled = xTrue;
                break;
            }
        }
    }

    xShapeInputSelectedReply reply = {
        enabled: cast(ubyte)enabled,
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcShapeGetRectangles(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xShapeGetRectanglesReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    int nrects = void;
    RegionPtr region = void;

    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;
    switch (stuff.kind) {
    case ShapeBounding:
        region = mixin(wBoundingShape!("pWin"));
        break;
    case ShapeClip:
        region = mixin(wClipShape!("pWin"));
        break;
    case ShapeInput:
        region = mixin(wInputShape!("pWin"));
        break;
    default:
        client.errorValue = cast(uint)stuff.kind;
        return BadValue;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (!region) {
        xRectangle rect = void;
        switch (stuff.kind) {
        case ShapeBounding:
            rect.x = cast(short)-mixin(wBorderWidth!("pWin"));
            rect.y = cast(short)-mixin(wBorderWidth!("pWin"));
            rect.width = cast(ushort)(pWin.drawable.width + mixin(wBorderWidth!("pWin")));
            rect.height = cast(ushort)(pWin.drawable.height + mixin(wBorderWidth!("pWin")));
            break;
        case ShapeClip:
            rect.x = 0;
            rect.y = 0;
            rect.width = pWin.drawable.width;
            rect.height = pWin.drawable.height;
            break;
        case ShapeInput:
            rect.x = cast(short)-mixin(wBorderWidth!("pWin"));
            rect.y = cast(short)-mixin(wBorderWidth!("pWin"));
            rect.width = cast(ushort)(pWin.drawable.width + mixin(wBorderWidth!("pWin")));
            rect.height = cast(ushort)(pWin.drawable.height + mixin(wBorderWidth!("pWin")));
            break;
        default: break;}
        nrects = 1;
        x_rpcbuf_write_CARD16s(&rpcbuf, cast(CARD16*)&rect, 4);
    }
    else {
        nrects = RegionNumRects(region);
        BoxPtr boxes = RegionRects(region);
        for (int i = 0; i < nrects; i++) {
            xRectangle rect = {
                x: boxes[i].x1,
                y: boxes[i].y1,
                width: cast(ushort)(boxes[i].x2 - boxes[i].x1),
                height: cast(ushort)(boxes[i].y2 - boxes[i].y1),
            };
            x_rpcbuf_write_CARD16s(&rpcbuf, cast(CARD16*)&rect, 4);
        }{}
    }

    xShapeGetRectanglesReply reply = {
        ordering: YXBanded,
        nrects: nrects
    };

    mixin(X_REPLY_FIELD_CARD32!"nrects");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcShapeDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_ShapeQueryVersion:
        return ProcShapeQueryVersion(client);
    case X_ShapeRectangles:
        return ProcShapeRectangles(client);
    case X_ShapeMask:
        return ProcShapeMask(client);
    case X_ShapeCombine:
        return ProcShapeCombine(client);
    case X_ShapeOffset:
        return ProcShapeOffset(client);
    case X_ShapeQueryExtents:
        return ProcShapeQueryExtents(client);
    case X_ShapeSelectInput:
        return ProcShapeSelectInput(client);
    case X_ShapeInputSelected:
        return ProcShapeInputSelected(client);
    case X_ShapeGetRectangles:
        return ProcShapeGetRectangles(client);
    default:
        return BadRequest;
    }
}

private void SShapeNotifyEvent(xShapeNotifyEvent* from, xShapeNotifyEvent* to)
{
    to.type = from.type;
    to.kind = from.kind;
    cpswapl(from.window, to.window);
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswaps(from.x, to.x);
    cpswaps(from.y, to.y);
    cpswaps(from.width, to.width);
    cpswaps(from.height, to.height);
    cpswapl(from.time, to.time);
    to.shaped = from.shaped;
}

private void ShapeWindowDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, WindowPtr pWin)
{
    /* free the events before the window's devPrivates are free'd by destruction */
    ShapeEventPtr pShapeEvent = void, next = void;
    ShapeEventPtr* pHead = mixin(SHAPE_WINDOW_PRIVADDR!(`pWin`));

    pShapeEvent = *pHead;
    while (pShapeEvent) {
        next = pShapeEvent.next;
        free(pShapeEvent);
        pShapeEvent = next;
    }
    dixSetPrivate(&pWin.devPrivates, &ShapeWindowPrivateKeyRec, null);
}

private void ShapeClientDestroyCallback(CallbackListPtr* pcbl, void* unused, void* calldata)
{
    ClientPtr client = cast(ClientPtr)calldata;
    mixin(DIX_FOR_EACH_SCREEN!q{
        WalkTree(walkScreen, &ShapeDelClientFromWin, client);
    });
}

void ShapeExtensionInit()
{
    ExtensionEntry* extEntry = void;

    if (!dixRegisterPrivateKey(&ShapeWindowPrivateKeyRec, PRIVATE_WINDOW, 0))
        return;

    mixin(DIX_FOR_EACH_SCREEN!q{
        dixScreenHookWindowDestroy(walkScreen,&ShapeWindowDestroy);
    });

    AddCallback(&ClientDestroyCallback, &ShapeClientDestroyCallback, null);

    if ((extEntry = AddExtension(SHAPENAME, ShapeNumberEvents, 0,
                                 &ProcShapeDispatch, &ProcShapeDispatch,
                                 null, &StandardMinorOpcode)) !is null) {
        ShapeEventBase = extEntry.eventBase;
        EventSwapVector[ShapeEventBase] = cast(EventSwapPtr) &SShapeNotifyEvent;
    }
}
