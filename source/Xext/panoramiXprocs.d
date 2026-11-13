module Xext.panoramiXprocs;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*****************************************************************
Copyright (c) 1991, 1997 Digital Equipment Corporation, Maynard, Massachusetts.
Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
DIGITAL EQUIPMENT CORPORATION BE LIABLE FOR ANY CLAIM, DAMAGES, INCLUDING,
BUT NOT LIMITED TO CONSEQUENTIAL OR INCIDENTAL DAMAGES, OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of Digital Equipment Corporation
shall not be used in advertising or otherwise to promote the sale, use or other
dealings in this Software without prior written authorization from Digital
Equipment Corporation.
******************************************************************/

/* Massively rewritten by Mark Vojkovich <markv@valinux.com> */

import build.dix_config;

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;

import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.screenint_priv;
import dix.server_priv;
import dix.window_priv;
import os.osdep;
import Xext.panoramiX;
import Xext.panoramiXsrv;

import dix.dixfonts;
import dix.scrnintstr;
import dix.window;
import dix.inputstr;
import migc;
import common.bytes;
import dix.dixstruct_priv;
import dix.resource;
import panoramiXh;
import dix.dixutils;
import dix.gc;
import common.math;
import common.swap;

enum XINERAMA_IMAGE_BUFSIZE = (256*1024);
enum INPUTONLY_LEGAL_MASK = (CWWinGravity | CWEventMask |
                              CWDontPropagate | CWOverrideRedirect | CWCursor );

int PanoramiXCreateWindow(ClientPtr client)
{
    PanoramiXRes* parent = void, newWin = void;
    PanoramiXRes* backPix = null;
    PanoramiXRes* bordPix = null;
    PanoramiXRes* cmap = null;

    mixin(REQUEST!xCreateWindowReq);
    int pback_offset = 0, pbord_offset = 0, cmap_offset = 0;
    int result = void, len = void;
    int orig_x = void, orig_y = void;
    XID orig_visual = void, tmp = void;

    mixin(REQUEST_AT_LEAST_SIZE!xCreateWindowReq);

    len = cast(int)(client.req_len - int32ForBytes(xCreateWindowReq.sizeof));
    if (Ones(stuff.mask) != len)
        return BadLength;

    result = dixLookupResourceByType(cast(void**) &parent, stuff.parent,
                                     XRT_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    if (__traits(getMember, stuff, "class_") == CopyFromParent)
        __traits(getMember, stuff, "class_") = parent.u.win.class_;

    if ((__traits(getMember, stuff, "class_") == InputOnly) && (stuff.mask & (~INPUTONLY_LEGAL_MASK)))
        return BadMatch;

    if (cast(Mask) stuff.mask & CWBackPixmap) {
        pback_offset = Ones(cast(Mask) stuff.mask & (CWBackPixmap - 1));
        tmp = *(cast(CARD32*) &stuff[1] + pback_offset);
        if ((tmp != None) && (tmp != ParentRelative)) {
            result = dixLookupResourceByType(cast(void**) &backPix, tmp,
                                             XRT_PIXMAP, client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.mask & CWBorderPixmap) {
        pbord_offset = Ones(cast(Mask) stuff.mask & (CWBorderPixmap - 1));
        tmp = *(cast(CARD32*) &stuff[1] + pbord_offset);
        if (tmp != CopyFromParent) {
            result = dixLookupResourceByType(cast(void**) &bordPix, tmp,
                                             XRT_PIXMAP, client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.mask & CWColormap) {
        cmap_offset = Ones(cast(Mask) stuff.mask & (CWColormap - 1));
        tmp = *(cast(CARD32*) &stuff[1] + cmap_offset);
        if (tmp != CopyFromParent) {
            result = dixLookupResourceByType(cast(void**) &cmap, tmp,
                                             XRT_COLORMAP, client,
                                             DixReadAccess);
            if (result != Success)
                return result;
        }
    }

    if (((newWin = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof)) is null))
        return BadAlloc;

    newWin.type = XRT_WINDOW;
    newWin.u.win.visibility = VisibilityNotViewable;
    newWin.u.win.class_ = cast(char)__traits(getMember, stuff, "class_");
    newWin.u.win.root = FALSE;
    panoramix_setup_ids(newWin, client, stuff.wid);

    if (__traits(getMember, stuff, "class_") == InputOnly)
        stuff.visual = cast(uint)CopyFromParent;
    orig_visual = stuff.visual;
    orig_x = stuff.x;
    orig_y = stuff.y;

    ScreenPtr masterScreen = dixGetMasterScreen();

    Bool parentIsRoot = (stuff.parent == masterScreen.root.drawable.id)
                     || (stuff.parent == masterScreen.screensaver.wid);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.wid = cast(uint)newWin.info[walkScreenIdx].id;
        stuff.parent = cast(uint) cast(uint)parent.info[walkScreenIdx].id;
        if (parentIsRoot) {
            stuff.x = cast(short)(orig_x - walkScreen.x);
            stuff.y = cast(short)(orig_y - walkScreen.y);
        }
        if (backPix)
            *(cast(CARD32*) &stuff[1] + pback_offset) = cast(uint)backPix.info[walkScreenIdx].id;
        if (bordPix)
            *(cast(CARD32*) &stuff[1] + pbord_offset) = cast(uint)bordPix.info[walkScreenIdx].id;
        if (cmap)
            *(cast(CARD32*) &stuff[1] + cmap_offset) = cast(uint)cmap.info[walkScreenIdx].id;
        if (orig_visual != CopyFromParent)
            stuff.visual = cast(uint)PanoramiXTranslateVisualID(walkScreenIdx, orig_visual);
        result = DoCreateWindowReq(client, stuff, cast(XID*)&stuff[1]);
        if (result != Success)
            break;
    }));

    if (result == Success)
        AddResource(cast(uint)newWin.info[0].id, XRT_WINDOW, newWin);
    else
        free(newWin);

    return result;
}

int PanoramiXChangeWindowAttributes(ClientPtr client)
{
    PanoramiXRes* win = void;
    PanoramiXRes* backPix = null;
    PanoramiXRes* bordPix = null;
    PanoramiXRes* cmap = null;

    mixin(REQUEST!xChangeWindowAttributesReq);
    int pback_offset = 0, pbord_offset = 0, cmap_offset = 0;
    int result = void, len = void;
    XID tmp = void;

    mixin(REQUEST_AT_LEAST_SIZE!xChangeWindowAttributesReq);

    len = cast(int)(client.req_len - int32ForBytes(xChangeWindowAttributesReq.sizeof));
    if (Ones(stuff.valueMask) != len)
        return BadLength;

    result = dixLookupResourceByType(cast(void**) &win, stuff.window,
                                     XRT_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    if ((win.u.win.class_ == InputOnly) &&
        (stuff.valueMask & (~INPUTONLY_LEGAL_MASK)))
        return BadMatch;

    if (cast(Mask) stuff.valueMask & CWBackPixmap) {
        pback_offset = Ones(cast(Mask) stuff.valueMask & (CWBackPixmap - 1));
        tmp = *(cast(CARD32*) &stuff[1] + pback_offset);
        if ((tmp != None) && (tmp != ParentRelative)) {
            result = dixLookupResourceByType(cast(void**) &backPix, tmp,
                                             XRT_PIXMAP, client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.valueMask & CWBorderPixmap) {
        pbord_offset = Ones(cast(Mask) stuff.valueMask & (CWBorderPixmap - 1));
        tmp = *(cast(CARD32*) &stuff[1] + pbord_offset);
        if (tmp != CopyFromParent) {
            result = dixLookupResourceByType(cast(void**) &bordPix, tmp,
                                             XRT_PIXMAP, client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.valueMask & CWColormap) {
        cmap_offset = Ones(cast(Mask) stuff.valueMask & (CWColormap - 1));
        tmp = *(cast(CARD32*) &stuff[1] + cmap_offset);
        if (tmp != CopyFromParent) {
            result = dixLookupResourceByType(cast(void**) &cmap, tmp,
                                             XRT_COLORMAP, client,
                                             DixReadAccess);
            if (result != Success)
                return result;
        }
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.window = cast(uint)cast(uint)win.info[walkScreenIdx].id;
        if (backPix)
            *(cast(CARD32*) &stuff[1] + pback_offset) = cast(uint)backPix.info[walkScreenIdx].id;
        if (bordPix)
            *(cast(CARD32*) &stuff[1] + pbord_offset) = cast(uint)bordPix.info[walkScreenIdx].id;
        if (cmap)
            *(cast(CARD32*) &stuff[1] + cmap_offset) = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_ChangeWindowAttributes]) (client);
    }));

    return result;
}

int PanoramiXDestroyWindow(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.id, XRT_WINDOW,
                                     client, DixDestroyAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.id = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_DestroyWindow]) (client);
        if (result != Success)
            break;
    }));

    /* Since ProcDestroyWindow is using FreeResource, it will free
       our resource for us on the last pass through the loop above */

    return result;
}

int PanoramiXDestroySubwindows(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.id, XRT_WINDOW,
                                     client, DixDestroyAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.id = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_DestroySubwindows]) (client);
        if (result != Success)
            break;
    }));

    /* DestroySubwindows is using FreeResource which will free
       our resources for us on the last pass through the loop above */

    return result;
}

int PanoramiXChangeSaveSet(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xChangeSaveSetReq);

    mixin(REQUEST_AT_LEAST_SIZE!xChangeSaveSetReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.window,
                                     XRT_WINDOW, client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.window = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_ChangeSaveSet]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXReparentWindow(ClientPtr client)
{
    PanoramiXRes* win = void, parent = void;
    int result = void;
    int x = void, y = void;

    mixin(REQUEST!xReparentWindowReq);

    mixin(REQUEST_AT_LEAST_SIZE!xReparentWindowReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.window,
                                     XRT_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &parent, stuff.parent,
                                     XRT_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    x = stuff.x;
    y = stuff.y;

    ScreenPtr masterScreen = dixGetMasterScreen();

    Bool parentIsRoot = (stuff.parent == masterScreen.root.drawable.id)
                     || (stuff.parent == masterScreen.screensaver.wid);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.window = cast(uint)win.info[walkScreenIdx].id;
        stuff.parent = cast(uint) parent.info[walkScreenIdx].id;
        if (parentIsRoot) {
            stuff.x = cast(short)(x - walkScreen.x);
            stuff.y = cast(short)(y - walkScreen.y);
        }
        result = (*SavedProcVector[X_ReparentWindow]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXMapWindow(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.id,
                                     XRT_WINDOW, client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.id = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_MapWindow]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXMapSubwindows(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.id,
                                     XRT_WINDOW, client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.id = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_MapSubwindows]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXUnmapWindow(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.id,
                                     XRT_WINDOW, client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.id = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_UnmapWindow]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXUnmapSubwindows(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.id,
                                     XRT_WINDOW, client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.id = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_UnmapSubwindows]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXConfigureWindow(ClientPtr client)
{
    PanoramiXRes* win = void;
    PanoramiXRes* sib = null;
    WindowPtr pWin = void;
    int result = void, len = void, sib_offset = 0, x = 0, y = 0;
    int x_offset = -1;
    int y_offset = -1;

    mixin(REQUEST!xConfigureWindowReq);

    mixin(REQUEST_AT_LEAST_SIZE!xConfigureWindowReq);

    len = cast(int)(client.req_len - int32ForBytes(xConfigureWindowReq.sizeof));
    if (Ones(stuff.mask) != len)
        return BadLength;

    /* because we need the parent */
    result = dixLookupResourceByType(cast(void**) &pWin, stuff.window,
                                     X11_RESTYPE_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &win, stuff.window,
                                     XRT_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    if (cast(Mask) stuff.mask & CWSibling) {
        XID tmp = void;

        sib_offset = Ones(cast(Mask) stuff.mask & (CWSibling - 1));
        if ((tmp = *(cast(CARD32*) &stuff[1] + sib_offset)) != 0) {
            result = dixLookupResourceByType(cast(void**) &sib, tmp, XRT_WINDOW,
                                             client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }

    ScreenPtr masterScreen = dixGetMasterScreen();

    if (pWin.parent && ((pWin.parent == masterScreen.root) ||
                         (pWin.parent.drawable.id == masterScreen.screensaver.wid))) {
        if (cast(Mask) stuff.mask & CWX) {
            x_offset = 0;
            x = cast(int)*(cast(CARD32*) &stuff[1]);
        }
        if (cast(Mask) stuff.mask & CWY) {
            y_offset = (x_offset == -1) ? 0 : 1;
            y = cast(int)*(cast(CARD32*) &stuff[1] + y_offset);
        }
    }

    /* have to go forward or you get expose events before
       ConfigureNotify events */
    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.window = cast(uint)win.info[walkScreenIdx].id;
        if (sib)
            *(cast(CARD32*) &stuff[1] + sib_offset) = cast(uint)sib.info[walkScreenIdx].id;
        if (x_offset >= 0)
            *(cast(CARD32*) &stuff[1] + x_offset) = x - walkScreen.x;
        if (y_offset >= 0)
            *(cast(CARD32*) &stuff[1] + y_offset) = y - walkScreen.y;
        result = (*SavedProcVector[X_ConfigureWindow]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXCirculateWindow(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void;

    mixin(REQUEST!xCirculateWindowReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCirculateWindowReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.window,
                                     XRT_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.window = cast(uint)win.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_CirculateWindow]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXGetGeometry(ClientPtr client)
{
    DrawablePtr pDraw = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    int rc = dixLookupDrawable(&pDraw, stuff.id, client, M_ANY, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    ScreenPtr masterScreen = dixGetMasterScreen();

    xGetGeometryReply reply = {
        root: cast(uint)masterScreen.root.drawable.id,
        depth: pDraw.depth,
        width: pDraw.width,
        height: pDraw.height,
        x: 0,
        y: 0,
        borderWidth: 0
    };

    if (stuff.id == reply.root) {
        xWindowRoot* root = cast(xWindowRoot*)
            (ConnectionInfo + connBlockScreenStart);

        reply.width = root.pixWidth;
        reply.height = root.pixHeight;
    }
    else if (mixin(WindowDrawable!("pDraw.type"))) {
        WindowPtr pWin = cast(WindowPtr) pDraw;

        reply.x = cast(short)(pWin.origin.x - mixin(wBorderWidth!("pWin")));
        reply.y = cast(short)(pWin.origin.y - mixin(wBorderWidth!("pWin")));
        if ((pWin.parent == masterScreen.root) ||
            (pWin.parent.drawable.id == masterScreen.screensaver.wid)) {
            reply.x += masterScreen.x;
            reply.y += masterScreen.y;
        }
        reply.borderWidth = pWin.borderWidth;
    }

    if (client.swapped) {
        swapl(&reply.root);
        swaps(&reply.x);
        swaps(&reply.y);
        swaps(&reply.width);
        swaps(&reply.height);
        swaps(&reply.borderWidth);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int PanoramiXTranslateCoords(ClientPtr client)
{
    INT16 x = void, y = void;

    mixin(REQUEST!xTranslateCoordsReq);
    WindowPtr pWin = void, pDst = void;

    mixin(REQUEST_AT_LEAST_SIZE!xTranslateCoordsReq);

    int rc = dixLookupWindow(&pWin, stuff.srcWid, client, DixReadAccess);
    if (rc != Success)
        return rc;
    rc = dixLookupWindow(&pDst, stuff.dstWid, client, DixReadAccess);
    if (rc != Success)
        return rc;

    ScreenPtr masterScreen = dixGetMasterScreen();

    if ((pWin == masterScreen.root) ||
        (pWin.drawable.id == masterScreen.screensaver.wid)) {
        x = cast(short)(stuff.srcX - masterScreen.x);
        y = cast(short)(stuff.srcY - masterScreen.y);
    }
    else {
        x = cast(short)(pWin.drawable.x + stuff.srcX);
        y = cast(short)(pWin.drawable.y + stuff.srcY);
    }
    pWin = pDst.firstChild;

    XID child = None;
    while (pWin) {
        BoxRec box = void;

        if ((pWin.mapped) &&
            (x >= pWin.drawable.x - mixin(wBorderWidth!("pWin"))) &&
            (x < pWin.drawable.x + cast(int) pWin.drawable.width +
             mixin(wBorderWidth!("pWin"))) &&
            (y >= pWin.drawable.y - mixin(wBorderWidth!("pWin"))) &&
            (y < pWin.drawable.y + cast(int) pWin.drawable.height +
             mixin(wBorderWidth!("pWin")))
            /* When a window is shaped, a further check
             * is made to see if the point is inside
             * borderSize
             */
            && (!mixin(wBoundingShape!("pWin")) ||
                RegionContainsPoint(mixin(wBoundingShape!("pWin")),
                                    x - pWin.drawable.x,
                                    y - pWin.drawable.y, &box))
            ) {
            child = pWin.drawable.id;
            pWin = cast(WindowPtr) null;
        }
        else
            pWin = pWin.nextSib;
    }

    INT16 dstX = cast(short)(x - pDst.drawable.x);
    INT16 dstY = cast(short)(y - pDst.drawable.y);
    if ((pDst == masterScreen.root) ||
        (pDst.drawable.id == masterScreen.screensaver.wid)) {
        dstX += masterScreen.x;
        dstY += masterScreen.y;
    }

    xTranslateCoordsReply reply = {
        sameScreen: xTrue,
        dstX: dstX,
        dstY: dstY,
        child: cast(uint)child
    };

    if (client.swapped) {
        swapl(&reply.child);
        swaps(&reply.dstX);
        swaps(&reply.dstY);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int PanoramiXCreatePixmap(ClientPtr client)
{
    PanoramiXRes* refDraw = void, newPix = void;
    int result = void;

    mixin(REQUEST!xCreatePixmapReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCreatePixmapReq);
    client.errorValue = cast(uint)stuff.pid;

    result = dixLookupResourceByClass(cast(void**) &refDraw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixReadAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (((newPix = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof)) is null))
        return BadAlloc;

    newPix.type = XRT_PIXMAP;
    newPix.u.pix.shared_ = FALSE;
    panoramix_setup_ids(newPix, client, stuff.pid);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.pid = cast(uint)newPix.info[walkScreenIdx].id;
        stuff.drawable = cast(uint)refDraw.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_CreatePixmap]) (client);
        if (result != Success)
            break;
    }));

    if (result == Success)
        AddResource(cast(uint)newPix.info[0].id, XRT_PIXMAP, newPix);
    else
        free(newPix);

    return result;
}

int PanoramiXFreePixmap(ClientPtr client)
{
    PanoramiXRes* pix = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    client.errorValue = cast(uint)stuff.id;

    result = dixLookupResourceByType(cast(void**) &pix, stuff.id, XRT_PIXMAP,
                                     client, DixDestroyAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.id = cast(uint)pix.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_FreePixmap]) (client);
        if (result != Success)
            break;
    }));

    /* Since ProcFreePixmap is using FreeResource, it will free
       our resource for us on the last pass through the loop above */

    return result;
}

int PanoramiXCreateGC(ClientPtr client)
{
    PanoramiXRes* refDraw = void;
    PanoramiXRes* newGC = void;
    PanoramiXRes* stip = null;
    PanoramiXRes* tile = null;
    PanoramiXRes* clip = null;

    mixin(REQUEST!xCreateGCReq);
    int tile_offset = 0, stip_offset = 0, clip_offset = 0;
    int result = void, len = void;
    XID tmp = void;

    mixin(REQUEST_AT_LEAST_SIZE!xCreateGCReq);

    client.errorValue = cast(uint)stuff.gc;
    len = cast(int)(client.req_len - int32ForBytes(xCreateGCReq.sizeof));
    if (Ones(stuff.mask) != len)
        return BadLength;

    result = dixLookupResourceByClass(cast(void**) &refDraw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixReadAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (cast(Mask) stuff.mask & GCTile) {
        tile_offset = Ones(cast(Mask) stuff.mask & (GCTile - 1));
        if ((tmp = *(cast(CARD32*) &stuff[1] + tile_offset)) != 0) {
            result = dixLookupResourceByType(cast(void**) &tile, tmp, XRT_PIXMAP,
                                             client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.mask & GCStipple) {
        stip_offset = Ones(cast(Mask) stuff.mask & (GCStipple - 1));
        if ((tmp = *(cast(CARD32*) &stuff[1] + stip_offset))!= 0) {
            result = dixLookupResourceByType(cast(void**) &stip, tmp, XRT_PIXMAP,
                                             client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.mask & GCClipMask) {
        clip_offset = Ones(cast(Mask) stuff.mask & (GCClipMask - 1));
        if ((tmp = *(cast(CARD32*) &stuff[1] + clip_offset)) != 0) {
            result = dixLookupResourceByType(cast(void**) &clip, tmp, XRT_PIXMAP,
                                             client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }

    if (((newGC = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof)) is null))
        return BadAlloc;

    newGC.type = XRT_GC;
    panoramix_setup_ids(newGC, client, stuff.gc);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.gc = cast(uint)newGC.info[walkScreenIdx].id;
        stuff.drawable = cast(uint)refDraw.info[walkScreenIdx].id;
        if (tile)
            *(cast(CARD32*) &stuff[1] + tile_offset) = cast(uint)tile.info[walkScreenIdx].id;
        if (stip)
            *(cast(CARD32*) &stuff[1] + stip_offset) = cast(uint)stip.info[walkScreenIdx].id;
        if (clip)
            *(cast(CARD32*) &stuff[1] + clip_offset) = cast(uint)clip.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_CreateGC]) (client);
        if (result != Success)
            break;
    }));

    if (result == Success)
        AddResource(cast(uint)newGC.info[0].id, XRT_GC, newGC);
    else
        free(newGC);

    return result;
}

int PanoramiXChangeGC(ClientPtr client)
{
    PanoramiXRes* gc = void;
    PanoramiXRes* stip = null;
    PanoramiXRes* tile = null;
    PanoramiXRes* clip = null;

    mixin(REQUEST!xChangeGCReq);
    int tile_offset = 0, stip_offset = 0, clip_offset = 0;
    int result = void, len = void;
    XID tmp = void;

    mixin(REQUEST_AT_LEAST_SIZE!xChangeGCReq);

    len = cast(int)(client.req_len - int32ForBytes(xChangeGCReq.sizeof));
    if (Ones(stuff.mask) != len)
        return BadLength;

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    if (cast(Mask) stuff.mask & GCTile) {
        tile_offset = Ones(cast(Mask) stuff.mask & (GCTile - 1));
        if ((tmp = *(cast(CARD32*) &stuff[1] + tile_offset)) != 0) {
            result = dixLookupResourceByType(cast(void**) &tile, tmp, XRT_PIXMAP,
                                             client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.mask & GCStipple) {
        stip_offset = Ones(cast(Mask) stuff.mask & (GCStipple - 1));
        if ((tmp = *(cast(CARD32*) &stuff[1] + stip_offset))!= 0) {
            result = dixLookupResourceByType(cast(void**) &stip, tmp, XRT_PIXMAP,
                                             client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }
    if (cast(Mask) stuff.mask & GCClipMask) {
        clip_offset = Ones(cast(Mask) stuff.mask & (GCClipMask - 1));
        if ((tmp = *(cast(CARD32*) &stuff[1] + clip_offset))!= 0) {
            result = dixLookupResourceByType(cast(void**) &clip, tmp, XRT_PIXMAP,
                                             client, DixReadAccess);
            if (result != Success)
                return result;
        }
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        if (tile)
            *(cast(CARD32*) &stuff[1] + tile_offset) = cast(uint)tile.info[walkScreenIdx].id;
        if (stip)
            *(cast(CARD32*) &stuff[1] + stip_offset) = cast(uint)stip.info[walkScreenIdx].id;
        if (clip)
            *(cast(CARD32*) &stuff[1] + clip_offset) = cast(uint)clip.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_ChangeGC]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXCopyGC(ClientPtr client)
{
    PanoramiXRes* srcGC = void, dstGC = void;
    int result = void;

    mixin(REQUEST!xCopyGCReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCopyGCReq);

    result = dixLookupResourceByType(cast(void**) &srcGC, stuff.srcGC, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    result = dixLookupResourceByType(cast(void**) &dstGC, stuff.dstGC, XRT_GC,
                                     client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.srcGC = cast(uint) srcGC.info[walkScreenIdx].id;
        stuff.dstGC = cast(uint)dstGC.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_CopyGC]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXSetDashes(ClientPtr client)
{
    PanoramiXRes* gc = void;
    int result = void;

    mixin(REQUEST!xSetDashesReq);

    mixin(REQUEST_FIXED_SIZE!("xSetDashesReq", "stuff.nDashes"));

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_SetDashes]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXSetClipRectangles(ClientPtr client)
{
    PanoramiXRes* gc = void;
    int result = void;

    mixin(REQUEST!xSetClipRectanglesReq);

    mixin(REQUEST_AT_LEAST_SIZE!xSetClipRectanglesReq);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_SetClipRectangles]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXFreeGC(ClientPtr client)
{
    PanoramiXRes* gc = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.id, XRT_GC,
                                     client, DixDestroyAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.id = cast(uint)gc.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_FreeGC]) (client);
        if (result != Success)
            break;
    }));

    /* Since ProcFreeGC is using FreeResource, it will free
       our resource for us on the last pass through the loop above */

    return result;
}

int PanoramiXClearToBackground(ClientPtr client)
{
    PanoramiXRes* win = void;
    int result = void, x = void, y = void;
    Bool isRoot = void;

    mixin(REQUEST!xClearAreaReq);

    mixin(REQUEST_AT_LEAST_SIZE!xClearAreaReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.window,
                                     XRT_WINDOW, client, DixWriteAccess);
    if (result != Success)
        return result;

    x = stuff.x;
    y = stuff.y;
    isRoot = win.u.win.root;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.window = cast(uint)win.info[walkScreenIdx].id;
        if (isRoot) {
            stuff.x = cast(short)(x - walkScreen.x);
            stuff.y = cast(short)(y - walkScreen.y);
        }
        result = (*SavedProcVector[X_ClearArea]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

/*
    For Window to Pixmap copies you're screwed since each screen's
    pixmap will look like what it sees on its screen.  Unless the
    screens overlap and the window lies on each, the two copies
    will be out of sync.  To remedy this we do a GetImage and PutImage
    in place of the copy.  Doing this as a single Image isn't quite
    correct since it will include the obscured areas but we will
    have to fix this later. (MArk).
*/

int PanoramiXCopyArea(ClientPtr client)
{
    int result = void, srcx = void, srcy = void, dstx = void, dsty = void, width = void, height = void;
    PanoramiXRes* gc = void, src = void, dst = void;
    Bool srcIsRoot = FALSE;
    Bool dstIsRoot = FALSE;
    Bool srcShared = void, dstShared = void;

    mixin(REQUEST!xCopyAreaReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCopyAreaReq);

    result = dixLookupResourceByClass(cast(void**) &src, stuff.srcDrawable,
                                      XRC_DRAWABLE, client, DixReadAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    srcShared = mixin(IS_SHARED_PIXMAP!("src"));

    result = dixLookupResourceByClass(cast(void**) &dst, stuff.dstDrawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    dstShared = mixin(IS_SHARED_PIXMAP!("dst"));

    if (dstShared && srcShared)
        return (*SavedProcVector[X_CopyArea]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    if ((dst.type == XRT_WINDOW) && dst.u.win.root)
        dstIsRoot = TRUE;
    if ((src.type == XRT_WINDOW) && src.u.win.root)
        srcIsRoot = TRUE;

    srcx = stuff.srcX;
    srcy = stuff.srcY;
    dstx = stuff.dstX;
    dsty = stuff.dstY;
    width = stuff.width;
    height = stuff.height;
    if ((dst.type == XRT_PIXMAP) && (src.type == XRT_WINDOW)) {
        DrawablePtr[MAXSCREENS] drawables = void;
        DrawablePtr pDst = void;
        GCPtr pGC = null;
        char* data = void;
        int pitch = void, rc = void;

        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            rc = dixLookupDrawable(drawables.ptr + walkScreenIdx, src.info[walkScreenIdx].id, client, 0,
                                   DixGetAttrAccess);
            if (rc != Success)
                return rc;
            drawables[walkScreenIdx].pScreen.SourceValidate(drawables[walkScreenIdx], 0, 0,
                                                  drawables[walkScreenIdx].width,
                                                  drawables[walkScreenIdx].height,
                                                  IncludeInferiors);
        }));

        pitch = PixmapBytePad(width, drawables[0].depth);
        if (((data = cast(char*) calloc(height, pitch)) is null))
            return BadAlloc;

        XineramaGetImageData(drawables.ptr, srcx, srcy, width, height, ZPixmap, ~0,
                             data, pitch, srcIsRoot);

        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            mixin(VALIDATE_DRAWABLE_AND_GC!("dst.info[walkScreenIdx].id", "pDst", "DixWriteAccess"));
            if (drawables[0].depth != pDst.depth) {
                client.errorValue = cast(uint)stuff.dstDrawable;
                free(data);
                return BadMatch;
            }

            (*pGC.ops.PutImage) (pDst, pGC, pDst.depth, dstx, dsty,
                                   width, height, 0, ZPixmap, data);
            if (dstShared)
                break;
        }));
        free(data);

        if (pGC && pGC.graphicsExposures) {
            RegionRec rgn = void;
            int dx = void, dy = void;
            BoxRec sourceBox = void;

            dx = drawables[0].x;
            dy = drawables[0].y;
            if (srcIsRoot) {
                ScreenPtr masterScreen = dixGetMasterScreen();
                dx += masterScreen.x;
                dy += masterScreen.y;
            }

            sourceBox.x1 = cast(short)min(srcx + dx, 0);
            sourceBox.y1 = cast(short)min(srcy + dy, 0);
            sourceBox.x2 = cast(short)max(sourceBox.x1 + width, 32767);
            sourceBox.y2 = cast(short)max(sourceBox.y1 + height, 32767);

            RegionInit(&rgn, &sourceBox, 1);

            /* subtract the (screen-space) clips of the source drawables */
            mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
                RegionPtr sd = void;

                if (pGC.subWindowMode == IncludeInferiors)
                    sd = NotClippedByChildren(cast(WindowPtr)drawables[walkScreenIdx]);
                else
                    sd = &(cast(WindowPtr)drawables[walkScreenIdx]).clipList;

                if (srcIsRoot)
                    RegionTranslate(&rgn, -walkScreen.x, -walkScreen.y);

                RegionSubtract(&rgn, &rgn, sd);

                if (srcIsRoot)
                    RegionTranslate(&rgn, walkScreen.x, walkScreen.y);

                if (pGC.subWindowMode == IncludeInferiors)
                    RegionDestroy(sd);
            }));

            /* -dx/-dy to get back to dest-relative, plus request offsets */
            RegionTranslate(&rgn, -dx + dstx, -dy + dsty);

            /* intersect with gc clip; just one screen is fine because pixmap */
            RegionIntersect(&rgn, &rgn, pGC.pCompositeClip);

            /* and expose */
            SendGraphicsExpose(client, &rgn, dst.info[0].id, X_CopyArea, 0);
            RegionUninit(&rgn);
        }
    }
    else {
        DrawablePtr pDst = null, pSrc = null;
        GCPtr pGC = null;
        RegionRec totalReg = void;

        RegionNull(&totalReg);

        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            RegionPtr pRgn = void;

            stuff.dstDrawable = cast(uint)dst.info[walkScreenIdx].id;
            stuff.srcDrawable = cast(uint)src.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            if (srcIsRoot) {
                stuff.srcX = cast(short)(srcx - walkScreen.x);
                stuff.srcY = cast(short)(srcy - walkScreen.y);
            }
            if (dstIsRoot) {
                stuff.dstX = cast(short)(dstx - walkScreen.x);
                stuff.dstY = cast(short)(dsty - walkScreen.y);
            }

            mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.dstDrawable", "pDst", "DixWriteAccess"));

            if (stuff.dstDrawable != stuff.srcDrawable) {
                int rc = dixLookupDrawable(&pSrc, stuff.srcDrawable, client, 0,
                                           DixReadAccess);
                if (rc != Success)
                    return rc;

                if ((pDst.pScreen != pSrc.pScreen) ||
                    (pDst.depth != pSrc.depth)) {
                    client.errorValue = cast(uint)stuff.dstDrawable;
                    return BadMatch;
                }
            }
            else
                pSrc = pDst;

            pRgn = (*pGC.ops.CopyArea) (pSrc, pDst, pGC,
                                          stuff.srcX, stuff.srcY,
                                          stuff.width, stuff.height,
                                          stuff.dstX, stuff.dstY);
            if (pGC.graphicsExposures && pRgn) {
                if (srcIsRoot) {
                    RegionTranslate(pRgn, walkScreen.x, walkScreen.y);
                }
                RegionAppend(&totalReg, pRgn);
                RegionDestroy(pRgn);
            }

            if (dstShared)
                break;
        }));

        if (pGC.graphicsExposures) {
            Bool overlap = void;

            RegionValidate(&totalReg, &overlap);
            SendGraphicsExpose(client, &totalReg, stuff.dstDrawable,
                               X_CopyArea, 0);
            RegionUninit(&totalReg);
        }
    }

    return Success;
}

int PanoramiXCopyPlane(ClientPtr client)
{
    int srcx = void, srcy = void, dstx = void, dsty = void;
    PanoramiXRes* gc = void, src = void, dst = void;
    Bool srcIsRoot = FALSE;
    Bool dstIsRoot = FALSE;
    Bool srcShared = void, dstShared = void;
    DrawablePtr psrcDraw = void, pdstDraw = null;
    GCPtr pGC = null;
    RegionRec totalReg = void;

    mixin(REQUEST!xCopyPlaneReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCopyPlaneReq);

    int rc = dixLookupResourceByClass(cast(void**) &src, stuff.srcDrawable,
                                      XRC_DRAWABLE, client, DixReadAccess);
    if (rc != Success)
        return (rc == BadValue) ? BadDrawable : rc;

    srcShared = mixin(IS_SHARED_PIXMAP!("src"));

    rc = dixLookupResourceByClass(cast(void**) &dst, stuff.dstDrawable,
                                  XRC_DRAWABLE, client, DixWriteAccess);
    if (rc != Success)
        return (rc == BadValue) ? BadDrawable : rc;

    dstShared = mixin(IS_SHARED_PIXMAP!("dst"));

    if (dstShared && srcShared)
        return (*SavedProcVector[X_CopyPlane]) (client);

    rc = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                 client, DixReadAccess);
    if (rc != Success)
        return rc;

    if ((dst.type == XRT_WINDOW) && dst.u.win.root)
        dstIsRoot = TRUE;
    if ((src.type == XRT_WINDOW) && src.u.win.root)
        srcIsRoot = TRUE;

    srcx = stuff.srcX;
    srcy = stuff.srcY;
    dstx = stuff.dstX;
    dsty = stuff.dstY;

    RegionNull(&totalReg);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        RegionPtr pRgn = void;

        stuff.dstDrawable = cast(uint)dst.info[walkScreenIdx].id;
        stuff.srcDrawable = cast(uint)src.info[walkScreenIdx].id;
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        if (srcIsRoot) {
            stuff.srcX = cast(short)(srcx - walkScreen.x);
            stuff.srcY = cast(short)(srcy - walkScreen.y);
        }
        if (dstIsRoot) {
            stuff.dstX = cast(short)(dstx - walkScreen.x);
            stuff.dstY = cast(short)(dsty - walkScreen.y);
        }

        mixin(VALIDATE_DRAWABLE_AND_GC!("stuff.dstDrawable", "pdstDraw", "DixWriteAccess"));
        if (stuff.dstDrawable != stuff.srcDrawable) {
            rc = dixLookupDrawable(&psrcDraw, stuff.srcDrawable, client, 0,
                                   DixReadAccess);
            if (rc != Success)
                return rc;

            if (pdstDraw.pScreen != psrcDraw.pScreen) {
                client.errorValue = cast(uint)stuff.dstDrawable;
                return BadMatch;
            }
        }
        else
            psrcDraw = pdstDraw;

        if (stuff.bitPlane == 0 || (stuff.bitPlane & (stuff.bitPlane - 1)) ||
            (stuff.bitPlane > (1L << (psrcDraw.depth - 1)))) {
            client.errorValue = cast(uint)stuff.bitPlane;
            return BadValue;
        }

        pRgn = (*pGC.ops.CopyPlane) (psrcDraw, pdstDraw, pGC,
                                       stuff.srcX, stuff.srcY,
                                       stuff.width, stuff.height,
                                       stuff.dstX, stuff.dstY,
                                       stuff.bitPlane);
        if (pGC.graphicsExposures && pRgn) {
            RegionAppend(&totalReg, pRgn);
            RegionDestroy(pRgn);
        }

        if (dstShared)
            break;
    }));

    if (pGC.graphicsExposures) {
        Bool overlap = void;

        RegionValidate(&totalReg, &overlap);
        SendGraphicsExpose(client, &totalReg, stuff.dstDrawable,
                           X_CopyPlane, 0);
        RegionUninit(&totalReg);
    }

    return Success;
}

int PanoramiXPolyPoint(ClientPtr client)
{
    PanoramiXRes* gc = void, draw = void;
    int result = void, npoint = void;
    Bool isRoot = void;

    mixin(REQUEST!xPolyPointReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyPointReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyPoint]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = (draw.type == XRT_WINDOW) && draw.u.win.root;
    npoint = cast(int)int32ForBytes((client.req_len << 2) - xPolyPointReq.sizeof);
    if (npoint > 0) {
        xPoint* origPts = cast(xPoint*) calloc(npoint, xPoint.sizeof);
        if (!origPts)
            return BadAlloc;

        memcpy(cast(char*) origPts, cast(char*) &stuff[1], npoint * xPoint.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx)
                memcpy(&stuff[1], origPts, npoint * xPoint.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xPoint* pnts = cast(xPoint*) &stuff[1];
                    int i = (stuff.coordMode == CoordModePrevious) ? 1 : npoint;

                    while (i--) {
                        pnts.x -= x_off;
                        pnts.y -= y_off;
                        pnts++;
                    }
                }
            }

            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_PolyPoint]) (client);
            if (result != Success)
                break;
        }));

        free(origPts);
        return result;
    }
    else
        return Success;
}

int PanoramiXPolyLine(ClientPtr client)
{
    PanoramiXRes* gc = void, draw = void;
    int result = void, npoint = void;
    Bool isRoot = void;

    mixin(REQUEST!xPolyLineReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyLineReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyLine]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");
    npoint = cast(int)int32ForBytes((client.req_len << 2) - xPolyLineReq.sizeof);
    if (npoint > 0) {
        xPoint* origPts = cast(xPoint*) calloc(npoint, xPoint.sizeof);
        if (!origPts)
            return BadAlloc;
        memcpy(cast(char*) origPts, cast(char*) &stuff[1], npoint * xPoint.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx)
                memcpy(&stuff[1], origPts, npoint * xPoint.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xPoint* pnts = cast(xPoint*) &stuff[1];
                    int i = (stuff.coordMode == CoordModePrevious) ? 1 : npoint;

                    while (i--) {
                        pnts.x -= x_off;
                        pnts.y -= y_off;
                        pnts++;
                    }
                }
            }

            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_PolyLine]) (client);
            if (result != Success)
                break;
        }));

        free(origPts);
        return result;
    }
    else
        return Success;
}

int PanoramiXPolySegment(ClientPtr client)
{
    int result = void, nsegs = void, i = void;
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;

    mixin(REQUEST!xPolySegmentReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolySegmentReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolySegment]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    nsegs = cast(uint)((client.req_len << 2) - xPolySegmentReq.sizeof);
    if (nsegs & 4)
        return BadLength;
    nsegs >>= 3;
    if (nsegs > 0) {
        xSegment* origSegs = cast(xSegment*) calloc(nsegs, xSegment.sizeof);
        if (!origSegs)
            return BadAlloc;
        memcpy(cast(char*) origSegs, cast(char*) &stuff[1], nsegs * xSegment.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx) /* skip on screen #0 */
                memcpy(&stuff[1], origSegs, nsegs * xSegment.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xSegment* segs = cast(xSegment*) &stuff[1];

                    for (i = nsegs; i--; segs++) {
                        segs.x1 -= x_off;
                        segs.x2 -= x_off;
                        segs.y1 -= y_off;
                        segs.y2 -= y_off;
                    }
                }
            }

            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_PolySegment]) (client);
            if (result != Success)
                break;
        }));

        free(origSegs);
        return result;
    }
    else
        return Success;
}

int PanoramiXPolyRectangle(ClientPtr client)
{
    int result = void, nrects = void, i = void;
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;

    mixin(REQUEST!xPolyRectangleReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyRectangleReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyRectangle]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    nrects = cast(uint)((client.req_len << 2) - xPolyRectangleReq.sizeof);
    if (nrects & 4)
        return BadLength;
    nrects >>= 3;
    if (nrects > 0) {
        xRectangle* origRecs = cast(xRectangle*) calloc(nrects, xRectangle.sizeof);
        if (!origRecs)
            return BadAlloc;
        memcpy(cast(char*) origRecs, cast(char*) &stuff[1],
               nrects * xRectangle.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx) /* skip on screen #0 */
                memcpy(&stuff[1], origRecs, nrects * xRectangle.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xRectangle* rects = cast(xRectangle*) &stuff[1];

                    for (i = nrects; i--; rects++) {
                        rects.x -= x_off;
                        rects.y -= y_off;
                    }
                }
            }

            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_PolyRectangle]) (client);
            if (result != Success)
                break;
        }));

        free(origRecs);
        return result;
    }
    else
        return Success;
}

int PanoramiXPolyArc(ClientPtr client)
{
    int result = void, narcs = void, i = void;
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;

    mixin(REQUEST!xPolyArcReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyArcReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyArc]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    narcs = cast(int)cast(uint)((client.req_len << 2) - xPolyArcReq.sizeof);
    if (narcs % xArc.sizeof)
        return BadLength;
    narcs /= xArc.sizeof;
    if (narcs > 0) {
        xArc* origArcs = cast(xArc*) calloc(narcs, xArc.sizeof);
        if (!origArcs)
            return BadAlloc;
        memcpy(cast(char*) origArcs, cast(char*) &stuff[1], narcs * xArc.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx) /* skip screen #0 */
                memcpy(&stuff[1], origArcs, narcs * xArc.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xArc* arcs = cast(xArc*) &stuff[1];

                    for (i = narcs; i--; arcs++) {
                        arcs.x -= x_off;
                        arcs.y -= y_off;
                    }
                }
            }
            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_PolyArc]) (client);
            if (result != Success)
                break;
        }));

        free(origArcs);
        return result;
    }
    else
        return Success;
}

int PanoramiXFillPoly(ClientPtr client)
{
    int result = void, count = void;
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;

    mixin(REQUEST!xFillPolyReq);

    mixin(REQUEST_AT_LEAST_SIZE!xFillPolyReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_FillPoly]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    count = cast(int)int32ForBytes((client.req_len << 2) - xFillPolyReq.sizeof);
    if (count > 0) {
        xPoint* locPts = cast(xPoint*)calloc(count, xPoint.sizeof);
        if (!locPts)
            return BadAlloc;
        memcpy(cast(char*) locPts, cast(char*) &stuff[1],
               count * xPoint.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx) /* skip screen #0 */
                memcpy(&stuff[1], locPts, count * xPoint.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xPoint* pnts = cast(xPoint*) &stuff[1];
                    int i = (stuff.coordMode == CoordModePrevious) ? 1 : count;

                    while (i--) {
                        pnts.x -= x_off;
                        pnts.y -= y_off;
                        pnts++;
                    }
                }
            }

            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_FillPoly]) (client);
            if (result != Success)
                break;
        }));

        free(locPts);
        return result;
    }
    else
        return Success;
}

int PanoramiXPolyFillRectangle(ClientPtr client)
{
    int result = void, things = void, i = void;
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;
    mixin(REQUEST!xPolyFillRectangleReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyFillRectangleReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyFillRectangle]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    things = cast(int)((client.req_len << 2) - xPolyFillRectangleReq.sizeof);
    if (things & 4)
        return BadLength;
    things >>= 3;
    if (things > 0) {
        xRectangle* origRects = cast(xRectangle*) calloc(things, xRectangle.sizeof);
        if (!origRects)
            return BadAlloc;
        memcpy(cast(char*) origRects, cast(char*) &stuff[1],
               things * xRectangle.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx) /* skip screen #0 */
                memcpy(&stuff[1], origRects, things * xRectangle.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xRectangle* rects = cast(xRectangle*) &stuff[1];

                    for (i = things; i--; rects++) {
                        rects.x -= x_off;
                        rects.y -= y_off;
                    }
                }
            }

            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_PolyFillRectangle]) (client);
            if (result != Success)
                break;
        }));

        free(origRects);
        return result;
    }
    else
        return Success;
}

int PanoramiXPolyFillArc(ClientPtr client)
{
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;
    int result = void, narcs = void, i = void;

    mixin(REQUEST!xPolyFillArcReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyFillArcReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyFillArc]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    narcs = cast(int)((client.req_len << 2) - xPolyFillArcReq.sizeof);
    if (narcs % xArc.sizeof)
        return BadLength;
    narcs /= xArc.sizeof;
    if (narcs > 0) {
        xArc* origArcs = cast(xArc*) calloc(narcs, xArc.sizeof);
        if (!origArcs)
            return BadAlloc;
        memcpy(cast(char*) origArcs, cast(char*) &stuff[1], narcs * xArc.sizeof);

        mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
            if (walkScreenIdx) /* skip screen #0 */
                memcpy(&stuff[1], origArcs, narcs * xArc.sizeof);

            if (isRoot) {
                int x_off = walkScreen.x;
                int y_off = walkScreen.y;

                if (x_off || y_off) {
                    xArc* arcs = cast(xArc*) &stuff[1];

                    for (i = narcs; i--; arcs++) {
                        arcs.x -= x_off;
                        arcs.y -= y_off;
                    }
                }
            }

            stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
            stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
            result = (*SavedProcVector[X_PolyFillArc]) (client);
            if (result != Success)
                break;
        }));

        free(origArcs);
        return result;
    }
    else
        return Success;
}

int PanoramiXPutImage(ClientPtr client)
{
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;
    int result = void, orig_x = void, orig_y = void;

    mixin(REQUEST!xPutImageReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPutImageReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PutImage]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    orig_x = stuff.dstX;
    orig_y = stuff.dstY;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (isRoot) {
            stuff.dstX = cast(short)(orig_x - walkScreen.x);
            stuff.dstY = cast(short)(orig_y - walkScreen.y);
        }
        stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_PutImage]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXGetImage(ClientPtr client)
{
    DrawablePtr[MAXSCREENS] drawables = void;
    DrawablePtr pDraw = void;
    PanoramiXRes* draw = void;
    Bool isRoot = void;
    int x = void, y = void, w = void, h = void, format = void;
    Mask plane = 0, planemask = void;
    int linesDone = void, nlines = void, linesPerBuf = void;
    c_long widthBytesLine = void;

    mixin(REQUEST!xGetImageReq);

    mixin(REQUEST_AT_LEAST_SIZE!xGetImageReq);

    if ((stuff.format != XYPixmap) && (stuff.format != ZPixmap)) {
        client.errorValue = cast(uint)stuff.format;
        return BadValue;
    }

    int rc = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixReadAccess);
    if (rc != Success)
        return (rc == BadValue) ? BadDrawable : rc;

    if (draw.type == XRT_PIXMAP)
        return (*SavedProcVector[X_GetImage]) (client);

    rc = dixLookupDrawable(&pDraw, stuff.drawable, client, 0, DixReadAccess);
    if (rc != Success)
        return rc;

    if (!(cast(WindowPtr) pDraw).realized)
        return BadMatch;

    x = stuff.x;
    y = stuff.y;
    w = stuff.width;
    h = stuff.height;
    format = stuff.format;
    planemask = stuff.planeMask;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    if (isRoot) {
        /* check for being onscreen */
        if (x < 0 || x + w > PanoramiXPixWidth ||
            y < 0 || y + h > PanoramiXPixHeight)
            return BadMatch;
    }
    else {
        ScreenPtr masterScreen = dixGetMasterScreen();
        /* check for being onscreen and inside of border */
        if (masterScreen.x + pDraw.x + x < 0 ||
            masterScreen.x + pDraw.x + x + w > PanoramiXPixWidth ||
            masterScreen.y + pDraw.y + y < 0 ||
            masterScreen.y + pDraw.y + y + h > PanoramiXPixHeight ||
            x < -mixin(wBorderWidth!("cast(WindowPtr) pDraw")) ||
            x + w > mixin(wBorderWidth!("cast(WindowPtr) pDraw")) + cast(int) pDraw.width ||
            y < -mixin(wBorderWidth!("cast(WindowPtr) pDraw")) ||
            y + h > mixin(wBorderWidth!("cast(WindowPtr) pDraw")) + cast(int) pDraw.height)
            return BadMatch;
    }

    drawables[0] = pDraw;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD_SKIP0!(q{
        rc = dixLookupDrawable(drawables.ptr + walkScreenIdx,
                               draw.info[walkScreenIdx].id,
                               client, 0,
                               DixGetAttrAccess);
        if (rc != Success)
            return rc;
    }));

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        DrawablePtr d = drawables[walkScreenIdx];
        d.pScreen.SourceValidate(d, 0, 0, d.width, d.height, IncludeInferiors);
    }));

    size_t length = void;
    if (format == ZPixmap) {
        widthBytesLine = PixmapBytePad(w, pDraw.depth);
        length = widthBytesLine * h;
    }
    else {
        widthBytesLine = mixin(BitmapBytePad!"w");
        plane = (cast(Mask) 1) << (pDraw.depth - 1);
        /* only planes asked for */
        length = widthBytesLine * h * Ones(planemask & (plane | (plane - 1)));
    }

    if (widthBytesLine == 0 || h == 0)
        linesPerBuf = 0;
    else if (widthBytesLine >= XINERAMA_IMAGE_BUFSIZE)
        linesPerBuf = 1;
    else {
        linesPerBuf = XINERAMA_IMAGE_BUFSIZE / widthBytesLine;
        if (linesPerBuf > h)
            linesPerBuf = h;
    }


    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    /* can become quite big, so make enough room so we don't need to relloc */
    if (!x_rpcbuf_makeroom(&rpcbuf, length))
        return BadAlloc;

    if (linesPerBuf == 0) {
        /* nothing to do */
    }
    else if (format == ZPixmap) {
        linesDone = 0;
        while (h - linesDone > 0) {
            nlines = min(linesPerBuf, h - linesDone);

            char* pBuf = cast(char*)x_rpcbuf_reserve(&rpcbuf, nlines * widthBytesLine);
            if (!pBuf)
                return BadAlloc;
            XineramaGetImageData(drawables.ptr, x, y + linesDone, w, nlines,
                                 format, planemask, pBuf, cast(int)widthBytesLine,
                                 isRoot);

            linesDone += nlines;
        }
    }
    else {                      /* XYPixmap */
        for (; plane; plane >>= 1) {
            if (planemask & plane) {
                linesDone = 0;
                while (h - linesDone > 0) {
                    nlines = min(linesPerBuf, h - linesDone);

                    char* pBuf = cast(char*)x_rpcbuf_reserve(&rpcbuf, nlines * widthBytesLine);
                    if (!pBuf)
                        return BadAlloc;
                    XineramaGetImageData(drawables.ptr, x, y + linesDone, w,
                                         nlines, format, plane, pBuf,
                                         cast(int)widthBytesLine, isRoot);

                    linesDone += nlines;
                }
            }
        }
    }

    xGetImageReply reply = {
        visual: cast(uint)mixin(wVisual!("cast(WindowPtr) pDraw")),
        depth: pDraw.depth,
    };

    if (client.swapped) {
        swaps(&reply.sequenceNumber);
        swapl(&reply.visual);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/* The text stuff should be rewritten so that duplication happens
   at the GlyphBlt level.  That is, loading the font and getting
   the glyphs should only happen once */

int PanoramiXPolyText8(ClientPtr client)
{
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;
    int result = void;
    int orig_x = void, orig_y = void;

    mixin(REQUEST!xPolyTextReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyTextReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyText8]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    orig_x = stuff.x;
    orig_y = stuff.y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        if (isRoot) {
            stuff.x = cast(short)(orig_x - walkScreen.x);
            stuff.y = cast(short)(orig_y - walkScreen.y);
        }
        result = (*SavedProcVector[X_PolyText8]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXPolyText16(ClientPtr client)
{
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;
    int result = void;
    int orig_x = void, orig_y = void;

    mixin(REQUEST!xPolyTextReq);

    mixin(REQUEST_AT_LEAST_SIZE!xPolyTextReq);

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_PolyText16]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    orig_x = stuff.x;
    orig_y = stuff.y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        if (isRoot) {
            stuff.x = cast(short)(orig_x - walkScreen.x);
            stuff.y = cast(short)(orig_y - walkScreen.y);
        }
        result = (*SavedProcVector[X_PolyText16]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXImageText8(ClientPtr client)
{
    int result = void;
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;
    int orig_x = void, orig_y = void;

    mixin(REQUEST!xImageTextReq);

    mixin(REQUEST_FIXED_SIZE!("xImageTextReq", "stuff.nChars"));

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_ImageText8]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    orig_x = stuff.x;
    orig_y = stuff.y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        if (isRoot) {
            stuff.x = cast(short)(orig_x - walkScreen.x);
            stuff.y = cast(short)(orig_y - walkScreen.y);
        }
        result = (*SavedProcVector[X_ImageText8]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXImageText16(ClientPtr client)
{
    int result = void;
    PanoramiXRes* gc = void, draw = void;
    Bool isRoot = void;
    int orig_x = void, orig_y = void;

    mixin(REQUEST!xImageTextReq);

   mixin(REQUEST_FIXED_SIZE!("xImageTextReq", "stuff.nChars << 1"));

    result = dixLookupResourceByClass(cast(void**) &draw, stuff.drawable,
                                      XRC_DRAWABLE, client, DixWriteAccess);
    if (result != Success)
        return (result == BadValue) ? BadDrawable : result;

    if (mixin(IS_SHARED_PIXMAP!"draw"))
        return (*SavedProcVector[X_ImageText16]) (client);

    result = dixLookupResourceByType(cast(void**) &gc, stuff.gc, XRT_GC,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    isRoot = mixin(IS_ROOT_DRAWABLE!"draw");

    orig_x = stuff.x;
    orig_y = stuff.y;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.drawable = cast(uint)draw.info[walkScreenIdx].id;
        stuff.gc = cast(uint)gc.info[walkScreenIdx].id;
        if (isRoot) {
            stuff.x = cast(short)(orig_x - walkScreen.x);
            stuff.y = cast(short)(orig_y - walkScreen.y);
        }
        result = (*SavedProcVector[X_ImageText16]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXCreateColormap(ClientPtr client)
{
    PanoramiXRes* win = void, newCmap = void;
    int result = void, orig_visual = void;

    mixin(REQUEST!xCreateColormapReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCreateColormapReq);

    result = dixLookupResourceByType(cast(void**) &win, stuff.window,
                                     XRT_WINDOW, client, DixReadAccess);
    if (result != Success)
        return result;

    if (((newCmap = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof)) is null))
        return BadAlloc;

    newCmap.type = XRT_COLORMAP;
    panoramix_setup_ids(newCmap, client, stuff.mid);

    orig_visual = cast(int)stuff.visual;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.mid = cast(uint)newCmap.info[walkScreenIdx].id;
        stuff.window = cast(uint)win.info[walkScreenIdx].id;
        stuff.visual = cast(uint)PanoramiXTranslateVisualID(walkScreenIdx, orig_visual);
        result = (*SavedProcVector[X_CreateColormap]) (client);
        if (result != Success)
            break;
    }));

    if (result == Success)
        AddResource(cast(uint)newCmap.info[0].id, XRT_COLORMAP, newCmap);
    else
        free(newCmap);

    return result;
}

int PanoramiXFreeColormap(ClientPtr client)
{
    PanoramiXRes* cmap = void;
    int result = void;

    mixin(REQUEST!xResourceReq);

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    client.errorValue = cast(uint)stuff.id;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.id, XRT_COLORMAP,
                                     client, DixDestroyAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.id = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_FreeColormap]) (client);
        if (result != Success)
            break;
    }));

    /* Since ProcFreeColormap is using FreeResource, it will free
       our resource for us on the last pass through the loop above */

    return result;
}

int PanoramiXCopyColormapAndFree(ClientPtr client)
{
    PanoramiXRes* cmap = void, newCmap = void;
    int result = void;

    mixin(REQUEST!xCopyColormapAndFreeReq);

    mixin(REQUEST_AT_LEAST_SIZE!xCopyColormapAndFreeReq);

    client.errorValue = cast(uint)stuff.srcCmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.srcCmap,
                                     XRT_COLORMAP, client,
                                     DixReadAccess | DixWriteAccess);
    if (result != Success)
        return result;

    if (((newCmap = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof)) is null))
        return BadAlloc;

    newCmap.type = XRT_COLORMAP;
    panoramix_setup_ids(newCmap, client, stuff.mid);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.srcCmap = cast(uint)cmap.info[walkScreenIdx].id;
        stuff.mid = cast(uint)newCmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_CopyColormapAndFree]) (client);
        if (result != Success)
            break;
    }));

    if (result == Success)
        AddResource(cast(uint)newCmap.info[0].id, XRT_COLORMAP, newCmap);
    else
        free(newCmap);

    return result;
}

int PanoramiXInstallColormap(ClientPtr client)
{
    mixin(REQUEST!xResourceReq);
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    client.errorValue = cast(uint)stuff.id;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.id, XRT_COLORMAP,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.id = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_InstallColormap]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXUninstallColormap(ClientPtr client)
{
    mixin(REQUEST!xResourceReq);
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    client.errorValue = cast(uint)stuff.id;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.id, XRT_COLORMAP,
                                     client, DixReadAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.id = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_UninstallColormap]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXAllocColor(ClientPtr client)
{
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST!xAllocColorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorReq);

    if (client.swapped) {
        swapl(&stuff.cmap);
        swaps(&stuff.red);
        swaps(&stuff.green);
        swaps(&stuff.blue);
    }

    client.errorValue = cast(uint)stuff.cmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap,
                                     XRT_COLORMAP, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        Colormap childCmap = cmap.info[walkScreenIdx].id;

        CARD16 red = stuff.red;
        CARD16 green = stuff.green;
        CARD16 blue = stuff.blue;
        CARD32 pixel = 0;

        result = dixAllocColor(client, childCmap, &red, &green, &blue, &pixel);
        if (result != Success)
            return result;

        /* only send out reply for on first screen */
        if (!walkScreenIdx) {
            xAllocColorReply reply = void; /* static init would confuse preprocessor */
            reply.red = red;
            reply.green = green;
            reply.blue = blue;
            reply.pixel = pixel;

            if (client.swapped) {
                swaps(&reply.red);
                swaps(&reply.green);
                swaps(&reply.blue);
                swapl(&reply.pixel);
            }

            /* iterating backwards, first screen comes last, so we can return here */
            return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
        }
    }));

    /* shouldn't ever reach here, because we already returned from within the loop
       if this ever happens, PanoramiXNumScreens must be 0 */
    return BadImplementation;
}

int PanoramiXAllocNamedColor(ClientPtr client)
{
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST!xAllocNamedColorReq);

    mixin(REQUEST_FIXED_SIZE!("xAllocNamedColorReq", "stuff.nbytes"));

    client.errorValue = cast(uint)stuff.cmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap,
                                     XRT_COLORMAP, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.cmap = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_AllocNamedColor]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXAllocColorCells(ClientPtr client)
{
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST!xAllocColorCellsReq);

    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorCellsReq);

    client.errorValue = cast(uint)stuff.cmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap,
                                     XRT_COLORMAP, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.cmap = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_AllocColorCells]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXAllocColorPlanes(ClientPtr client)
{
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST!xAllocColorPlanesReq);

    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorPlanesReq);

    client.errorValue = cast(uint)stuff.cmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap,
                                     XRT_COLORMAP, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.cmap = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_AllocColorPlanes]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXFreeColors(ClientPtr client)
{
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST!xFreeColorsReq);

    mixin(REQUEST_AT_LEAST_SIZE!xFreeColorsReq);

    client.errorValue = cast(uint)stuff.cmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap,
                                     XRT_COLORMAP, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.cmap = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_FreeColors]) (client);
    }));

    return result;
}

int PanoramiXStoreColors(ClientPtr client)
{
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST!xStoreColorsReq);

    mixin(REQUEST_AT_LEAST_SIZE!xStoreColorsReq);

    client.errorValue = cast(uint)stuff.cmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap,
                                     XRT_COLORMAP, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.cmap = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_StoreColors]) (client);
        if (result != Success)
            break;
    }));

    return result;
}

int PanoramiXStoreNamedColor(ClientPtr client)
{
    int result = void;
    PanoramiXRes* cmap = void;

    mixin(REQUEST!xStoreNamedColorReq);

    mixin(REQUEST_FIXED_SIZE!("xStoreNamedColorReq", "stuff.nbytes"));

    client.errorValue = cast(uint)stuff.cmap;

    result = dixLookupResourceByType(cast(void**) &cmap, stuff.cmap,
                                     XRT_COLORMAP, client, DixWriteAccess);
    if (result != Success)
        return result;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        stuff.cmap = cast(uint)cmap.info[walkScreenIdx].id;
        result = (*SavedProcVector[X_StoreNamedColor]) (client);
        if (result != Success)
            break;
    }));

    return result;
}
