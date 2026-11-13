module composite.compext;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2006, Oracle and/or its affiliates.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
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

import build.dix_config;

import dix.dix_priv;
import dix.request_priv;
import dix.screenint_priv;
import miext.extinit_priv;
import Xext.panoramiXsrv;
import build.xlibre_server;

import composite.compint;
import Xext.xace;
import common.protocol_versions;
import externs.X11.extensions.compositeproto;
import xfixes.region;
import dix.extension;
import render.picture;
public import composite.compint;
import common.swap;



private CARD8 CompositeReqCode;
private DevPrivateKeyRec CompositeClientPrivateKeyRec;

static if(XINERAMA){
private int compositeUseXinerama = 0;
}

enum CompositeClientPrivateKey = (&CompositeClientPrivateKeyRec);
RESTYPE CompositeClientWindowType;
// RESTYPE CompositeClientSubwindowsType;
// RESTYPE CompositeClientOverlayType;

struct _CompositeClient {
    int major_version;
    int minor_version;
}alias CompositeClientRec = _CompositeClient;
alias CompositeClientPtr = _CompositeClient*;

enum string GetCompositeClient(string pClient) = `(cast(CompositeClientPtr) 
    dixLookupPrivate(&(` ~ pClient ~ `).devPrivates, CompositeClientPrivateKey))`;

private int FreeCompositeClientWindow(void* value, XID ccwid)
{
    WindowPtr pWin = cast(WindowPtr)value;

    compFreeClientWindow(pWin, ccwid);
    return Success;
}

private int FreeCompositeClientSubwindows(void* value, XID ccwid)
{
    WindowPtr pWin = cast(WindowPtr)value;

    compFreeClientSubwindows(pWin, ccwid);
    return Success;
}

private int FreeCompositeClientOverlay(void* value, XID ccwid)
{
    CompOverlayClientPtr pOc = cast(CompOverlayClientPtr) value;

    compFreeOverlayClient(pOc);
    return Success;
}

private int ProcCompositeQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeQueryVersionReq);
    mixin(X_REQUEST_FIELD_CARD32!"majorVersion");
    mixin(X_REQUEST_FIELD_CARD32!"minorVersion");

    CompositeClientPtr pCompositeClient = mixin(GetCompositeClient!(`client`));

    xCompositeQueryVersionReply reply = {
        majorVersion: SERVER_COMPOSITE_MAJOR_VERSION,
        minorVersion: SERVER_COMPOSITE_MINOR_VERSION
    };

    /* if client asking for a lower version, use this one */
    if (stuff.majorVersion < SERVER_COMPOSITE_MAJOR_VERSION) {
        reply.majorVersion = stuff.majorVersion;
        reply.minorVersion = stuff.minorVersion;
    }

    pCompositeClient.major_version = cast(int)reply.majorVersion;
    pCompositeClient.minor_version = cast(int)reply.minorVersion;

    mixin(X_REPLY_FIELD_CARD32!"majorVersion");
    mixin(X_REPLY_FIELD_CARD32!"minorVersion");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

enum string VERIFY_WINDOW(string pWindow, string wid, string client, string mode) = `
        int err = void;                                                        
        err = dixLookupResourceByType(cast(void**) &` ~ pWindow ~ `, ` ~ wid ~ `,          
                                      X11_RESTYPE_WINDOW, ` ~ client ~ `, ` ~ mode ~ `);
        if (err != Success) {                                           
            ` ~ client ~ `.errorValue = ` ~ wid ~ `;                                   
            return err;                                                 
        }`;                                                               

private int SingleCompositeRedirectWindow(ClientPtr client, xCompositeRedirectWindowReq* stuff)
{
    WindowPtr pWin = void;

    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`,
                  `DixSetAttrAccess | DixManageAccess | DixBlendAccess`));

    return compRedirectWindow(client, pWin, stuff.update);
}

private int SingleRedirectSubwindows(ClientPtr client, xCompositeRedirectSubwindowsReq* stuff)
{
    WindowPtr pWin = void;

    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`,
                  `DixSetAttrAccess | DixManageAccess | DixBlendAccess`));

    return compRedirectSubwindows(client, pWin, stuff.update);
}

private int SingleCompositeUnredirectWindow(ClientPtr client, xCompositeUnredirectWindowReq* stuff)
{
    WindowPtr pWin = void;

    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`,
                  `DixSetAttrAccess | DixManageAccess | DixBlendAccess`));

    return compUnredirectWindow(client, pWin, stuff.update);
}

private int SingleCompositeUnredirectSubwindows(ClientPtr client, xCompositeUnredirectSubwindowsReq* stuff)
{
    WindowPtr pWin = void;

    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`,
                  `DixSetAttrAccess | DixManageAccess | DixBlendAccess`));

    return compUnredirectSubwindows(client, pWin, stuff.update);
}

private int ProcCompositeCreateRegionFromBorderClip(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeCreateRegionFromBorderClipReq);
    mixin(X_REQUEST_FIELD_CARD32!"region");
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`, `DixGetAttrAccess`));
    mixin(LEGAL_NEW_RESOURCE!("stuff.region", "client"));

    CompWindowPtr cw = mixin(GetCompWindow!("pWin"));

    RegionPtr pBorderClip = (cw ? &cw.borderClip : &pWin.borderClip);

    RegionPtr pRegion = XFixesRegionCopy(pBorderClip);
    if (!pRegion)
        return BadAlloc;

    RegionTranslate(pRegion, -pWin.drawable.x, -pWin.drawable.y);

    if (!AddResource(cast(uint)stuff.region, RegionResType, cast(void*) pRegion))
        return BadAlloc;

    return Success;
}

private int SingleCompositeNameWindowPixmap(ClientPtr client, xCompositeNameWindowPixmapReq* stuff)
{
    WindowPtr pWin = void;

    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`, `DixGetAttrAccess`));

    ScreenPtr pScreen = pWin.drawable.pScreen;

    if (!pWin.viewable)
        return BadMatch;

    mixin(LEGAL_NEW_RESOURCE!("stuff.pixmap", "client"));

    CompWindowPtr cw = mixin(GetCompWindow!("pWin"));
    if (!cw)
        return BadMatch;

    PixmapPtr pPixmap = pScreen.GetWindowPixmap(pWin);
    if (!pPixmap)
        return BadMatch;

    /* security creation/labeling check */
    int rc = XaceHookResourceAccess(client,
                                    stuff.pixmap,
                                    X11_RESTYPE_PIXMAP,
                                    pPixmap,
                                    X11_RESTYPE_WINDOW,
                                    pWin,
                                    DixCreateAccess);
    if (rc != Success)
        return rc;

    ++pPixmap.refcnt;

    if (!AddResource(cast(uint)stuff.pixmap, X11_RESTYPE_PIXMAP, cast(void*) pPixmap))
        return BadAlloc;

    if (pScreen.NameWindowPixmap) {
        rc = pScreen.NameWindowPixmap(pWin, pPixmap, stuff.pixmap);
        if (rc != Success) {
            FreeResource(cast(uint)stuff.pixmap, X11_RESTYPE_NONE);
            return rc;
        }
    }

    return Success;
}

private int SingleCompositeGetOverlayWindow(ClientPtr client, xCompositeGetOverlayWindowReq* stuff)
{
    WindowPtr pWin = void;

    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`, `DixGetAttrAccess`));
    ScreenPtr pScreen = pWin.drawable.pScreen;

    /*
     * Create an OverlayClient structure to mark this client's
     * interest in the overlay window
     */
    CompOverlayClientPtr pOc = compCreateOverlayClient(pScreen, client);
    if (pOc is null)
        return BadAlloc;

    /*
     * Make sure the overlay window exists
     */
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    if (cs.pOverlayWin is null)
        if (!compCreateOverlayWindow(pScreen)) {
            FreeResource(cast(uint)pOc.resource, X11_RESTYPE_NONE);
            return BadAlloc;
        }

    int rc = XaceHookResourceAccess(client,
                                    cs.pOverlayWin.drawable.id,
                                    X11_RESTYPE_WINDOW,
                                    cs.pOverlayWin, X11_RESTYPE_NONE,
                                    null,
                                    DixGetAttrAccess);
    if (rc != Success) {
        FreeResource(cast(uint)pOc.resource, X11_RESTYPE_NONE);
        return rc;
    }

    xCompositeGetOverlayWindowReply reply = {
        overlayWin: cast(uint)cs.pOverlayWin.drawable.id
    };

    mixin(X_REPLY_FIELD_CARD32!"overlayWin");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int SingleCompositeReleaseOverlayWindow(ClientPtr client, xCompositeReleaseOverlayWindowReq* stuff)
{
    WindowPtr pWin = void;

    mixin(VERIFY_WINDOW!(`pWin`, `stuff.window`, `client`, `DixGetAttrAccess`));

    /*
     * Has client queried a reference to the overlay window
     * on this screen? If not, generate an error.
     */
    CompOverlayClientPtr pOc = compFindOverlayClient(pWin.drawable.pScreen, client);
    if (pOc is null)
        return BadMatch;

    /* The delete function will free the client structure */
    FreeResource(cast(uint)pOc.resource, X11_RESTYPE_NONE);

    return Success;
}









private int ProcCompositeDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
        case X_CompositeQueryVersion:
            return ProcCompositeQueryVersion(client);
        case X_CompositeRedirectWindow:
            return ProcCompositeRedirectWindow(client);
        case X_CompositeRedirectSubwindows:
            return ProcCompositeRedirectSubwindows(client);
        case X_CompositeUnredirectWindow:
            return ProcCompositeUnredirectWindow(client);
        case X_CompositeUnredirectSubwindows:
            return ProcCompositeUnredirectSubwindows(client);
        case X_CompositeCreateRegionFromBorderClip:
            return ProcCompositeCreateRegionFromBorderClip(client);
        case X_CompositeNameWindowPixmap:
            return ProcCompositeNameWindowPixmap(client);
        case X_CompositeGetOverlayWindow:
            return ProcCompositeGetOverlayWindow(client);
        case X_CompositeReleaseOverlayWindow:
            return ProcCompositeReleaseOverlayWindow(client);
        default:
            return BadRequest;
    }
}

/** @see GetDefaultBytes */
private SizeType coreGetWindowBytes;

private void GetCompositeWindowBytes(void* value, XID id, ResourceSizePtr size)
{
    WindowPtr window = cast(WindowPtr)value;

    /* call down */
    coreGetWindowBytes(value, id, size);

    /* account for redirection */
    if (window.redirectDraw != RedirectDrawNone)
    {
        SizeType pixmapSizeFunc = GetResourceTypeSizeFunc(X11_RESTYPE_PIXMAP);
        ResourceSizeRec pixmapSize = { 0, 0 };
        ScreenPtr pScreen = window.drawable.pScreen;
        PixmapPtr pixmap = pScreen.GetWindowPixmap(window);
        pixmapSizeFunc(pixmap, pixmap.drawable.id, &pixmapSize);
        size.pixmapRefSize += pixmapSize.pixmapRefSize;
    }
}

void CompositeExtensionInit()
{
    /* Assume initialization is going to fail */
    noCompositeExtension = TRUE;

    mixin(DIX_FOR_EACH_SCREEN!q{

        /* Composite on 8bpp pseudocolor root windows appears to fail, so
         * just disable it on anything pseudocolor for safety.
         */
        VisualPtr vis = void;
        for (vis = walkScreen.visuals; vis.vid != walkScreen.rootVisual; vis++){}
        if ((vis.class_ | DynamicClass) == PseudoColor)
            return;

        /* Ensure that Render is initialized, which is required for automatic
         * compositing.
         */
        if (mixin(GetPictureScreenIfSet!("walkScreen")) is null)
            return;
    });

    CompositeClientWindowType = CreateNewResourceType
        (&FreeCompositeClientWindow, "CompositeClientWindow");
    if (!CompositeClientWindowType)
        return;

    coreGetWindowBytes = GetResourceTypeSizeFunc(X11_RESTYPE_WINDOW);
    SetResourceTypeSizeFunc(X11_RESTYPE_WINDOW, &GetCompositeWindowBytes);

    CompositeClientSubwindowsType = CreateNewResourceType
        (&FreeCompositeClientSubwindows, "CompositeClientSubwindows");
    if (!CompositeClientSubwindowsType)
        return;

    CompositeClientOverlayType = CreateNewResourceType
        (&FreeCompositeClientOverlay, "CompositeClientOverlay");
    if (!CompositeClientOverlayType)
        return;

    if (!dixRegisterPrivateKey(&CompositeClientPrivateKeyRec, PRIVATE_CLIENT,
                               CompositeClientRec.sizeof))
        return;

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (!compScreenInit(walkScreen))
            return;
    });

    ExtensionEntry* extEntry = AddExtension(COMPOSITE_NAME, 0, 0,
                            &ProcCompositeDispatch,
                            &ProcCompositeDispatch,
                            null, &StandardMinorOpcode);
    if (!extEntry)
        return;
    CompositeReqCode = cast(CARD8) extEntry.base;

    /* Initialization succeeded */
    noCompositeExtension = FALSE;
}

private int ProcCompositeRedirectWindow(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeRedirectWindowReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

static if(XINERAMA){
    if (!compositeUseXinerama)
        return SingleCompositeRedirectWindow(client, stuff);

    PanoramiXRes* win = void;
    int rc = 0;

    if ((rc = dixLookupResourceByType(cast(void**) &win, stuff.window, XRT_WINDOW,
                                      client, DixUnknownAccess)) != 0) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.window = win.info[walkScreenIdx].id;
        rc = SingleCompositeRedirectWindow(client, stuff);
        if (rc != Success)
            break;
    }));

    return rc;
} else {
    return SingleCompositeRedirectWindow(client, stuff);
} /* XINERAMA */
}

private int ProcCompositeRedirectSubwindows(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeRedirectSubwindowsReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

static if(XINERAMA){
    if (!compositeUseXinerama)
        return SingleRedirectSubwindows(client, stuff);

    PanoramiXRes* win = void;
    int rc = 0;

    if ((rc = dixLookupResourceByType(cast(void**) &win, stuff.window, XRT_WINDOW,
                                      client, DixUnknownAccess))!= 0) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.window = win.info[walkScreenIdx].id;
        rc = SingleRedirectSubwindows(client, stuff);
        if (rc != Success)
            break;
    }));

    return rc;
} else {
    return SingleRedirectSubwindows(client, stuff);
} /* XINERAMA */
}

private int ProcCompositeUnredirectWindow(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeUnredirectWindowReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

static if(XINERAMA){
    if (!compositeUseXinerama)
        return SingleCompositeUnredirectWindow(client, stuff);

    PanoramiXRes* win = void;
    int rc = 0;

    if ((rc = dixLookupResourceByType(cast(void**) &win, stuff.window, XRT_WINDOW,
                                      client, DixUnknownAccess))!= 0) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.window = win.info[walkScreenIdx].id;
        rc = SingleCompositeUnredirectWindow(client, stuff);
        if (rc != Success)
            break;
    }));

    return rc;
} else {
    return SingleCompositeUnredirectWindow(client, stuff);
} /* XINERAMA */
}

private int ProcCompositeUnredirectSubwindows(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeUnredirectSubwindowsReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

static if(XINERAMA){
    if (!compositeUseXinerama)
        return SingleCompositeUnredirectSubwindows(client, stuff);

    PanoramiXRes* win = void;
    int rc = 0;

    if ((rc = dixLookupResourceByType(cast(void**) &win, stuff.window, XRT_WINDOW,
                                      client, DixUnknownAccess))!= 0) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD!(q{
        stuff.window = win.info[walkScreenIdx].id;
        rc = SingleCompositeUnredirectSubwindows(client, stuff);
        if (rc != Success)
            break;
    }));

    return rc;
} else {
    return SingleCompositeUnredirectSubwindows(client, stuff);
} /* XINERAMA */
}

private int ProcCompositeNameWindowPixmap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeNameWindowPixmapReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"pixmap");

static if(XINERAMA){
    if (!compositeUseXinerama)
        return SingleCompositeNameWindowPixmap(client, stuff);

    WindowPtr pWin = void;
    CompWindowPtr cw = void;
    PixmapPtr pPixmap = void;
    int rc = void;
    PanoramiXRes* win = void, newPix = void;

    if ((rc = dixLookupResourceByType(cast(void**) &win, stuff.window, XRT_WINDOW,
                                      client, DixUnknownAccess))!= 0) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    mixin(LEGAL_NEW_RESOURCE!("stuff.pixmap", "client"));

    if (((newPix = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof))) is null)
        return BadAlloc;

    newPix.type = XRT_PIXMAP;
    newPix.u.pix.shared_ = FALSE;
    panoramix_setup_ids(newPix, client, stuff.pixmap);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        rc = dixLookupResourceByType(cast(void**) &pWin, win.info[walkScreenIdx].id,
                                     X11_RESTYPE_WINDOW, client,
                                     DixGetAttrAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)stuff.window;
            free(newPix);
            return rc;
        }

        if (!pWin.viewable) {
            free(newPix);
            return BadMatch;
        }

        cw = mixin(GetCompWindow!("pWin"));
        if (!cw) {
            free(newPix);
            return BadMatch;
        }

        pPixmap = (*pWin.drawable.pScreen.GetWindowPixmap) (pWin);
        if (!pPixmap) {
            free(newPix);
            return BadMatch;
        }

        if (!AddResource(cast(uint)newPix.info[walkScreenIdx].id, X11_RESTYPE_PIXMAP, cast(void*) pPixmap)) {
            free(newPix);
            return BadAlloc;
        }

        ++pPixmap.refcnt;
    }));

    if (!AddResource(cast(uint)stuff.pixmap, XRT_PIXMAP, cast(void*) newPix))
        return BadAlloc;

    return Success;
} else {
    return SingleCompositeNameWindowPixmap(client, stuff);
} /* XINERAMA */
}

private int ProcCompositeGetOverlayWindow(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeGetOverlayWindowReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

static if(XINERAMA){
    if (!compositeUseXinerama)
        return SingleCompositeGetOverlayWindow(client, stuff);

    WindowPtr pWin = void;
    ScreenPtr pScreen = void;
    CompOverlayClientPtr pOc = void;
    int rc = void;
    PanoramiXRes* win = void, overlayWin = null;

    if ((rc = dixLookupResourceByType(cast(void**) &win, stuff.window, XRT_WINDOW,
                                      client, DixUnknownAccess))!= 0) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    CompScreenPtr cs = mixin(GetCompScreen!("dixGetMasterScreen"));
    if (!cs.pOverlayWin) {
        if (((overlayWin = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof)) is null))
            return BadAlloc;

        overlayWin.type = XRT_WINDOW;
        overlayWin.u.win.root = FALSE;
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        rc = dixLookupResourceByType(cast(void**) &pWin, win.info[walkScreenIdx].id,
                                     X11_RESTYPE_WINDOW, client,
                                     DixGetAttrAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)stuff.window;
            free(overlayWin);
            return rc;
        }
        pScreen = pWin.drawable.pScreen;

        pOc = compCreateOverlayClient(pScreen, client);
        if (pOc is null) {
            free(overlayWin);
            return BadAlloc;
        }

        /*
         * Make sure the overlay window exists
         */
        cs = mixin(GetCompScreen!("pScreen"));
        if (cs.pOverlayWin is null)
            if (!compCreateOverlayWindow(pScreen)) {
                FreeResource(cast(uint)pOc.resource, X11_RESTYPE_NONE);
                free(overlayWin);
                return BadAlloc;
            }

        rc = XaceHookResourceAccess(client,
                      cs.pOverlayWin.drawable.id,
                      X11_RESTYPE_WINDOW, cs.pOverlayWin, X11_RESTYPE_NONE, null,
                      DixGetAttrAccess);
        if (rc != Success) {
            FreeResource(cast(uint)pOc.resource, X11_RESTYPE_NONE);
            free(overlayWin);
            return rc;
        }
    }));

    if (overlayWin) {
        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            cs = mixin(GetCompScreen!("walkScreen"));
            overlayWin.info[walkScreenIdx].id = cs.pOverlayWin.drawable.id;
        }));

        AddResource(cast(uint)overlayWin.info[0].id, XRT_WINDOW, overlayWin);
    }

    cs = mixin(GetCompScreen!("dixGetMasterScreen()"));

    xCompositeGetOverlayWindowReply reply = {
        overlayWin: cs.pOverlayWin.drawable.id
    };

    mixin(X_REPLY_FIELD_CARD32!"overlayWin");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
} else {
    return SingleCompositeGetOverlayWindow(client, stuff);
} /* XINERAMA */
}

private int ProcCompositeReleaseOverlayWindow(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xCompositeReleaseOverlayWindowReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

static if(XINERAMA){
    if (!compositeUseXinerama)
        return SingleCompositeReleaseOverlayWindow(client, stuff);

    WindowPtr pWin = void;
    CompOverlayClientPtr pOc = void;
    PanoramiXRes* win = void;
    int rc = void;

    if ((rc = dixLookupResourceByType(cast(void**) &win, stuff.window, XRT_WINDOW,
                                      client, DixUnknownAccess)) != 0) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if ((rc = dixLookupResourceByType(cast(void**) &pWin, win.info[walkScreenIdx].id,
                                          XRT_WINDOW, client,
                                          DixUnknownAccess))!= 0) {
            client.errorValue = cast(uint)stuff.window;
            return rc;
        }
        pOc = compFindOverlayClient(pWin.drawable.pScreen, client);
        if (pOc is null)
            return BadMatch;

        /* The delete function will free the client structure */
        FreeResource(cast(uint)pOc.resource, X11_RESTYPE_NONE);
    }));

    return Success;
} else {
    return SingleCompositeReleaseOverlayWindow(client, stuff);
} /* XINERAMA */
}

static if(XINERAMA){
void PanoramiXCompositeInit()
{
    compositeUseXinerama = 1;
}

void PanoramiXCompositeReset()
{
    compositeUseXinerama = 0;
}
} /* XINERAMA */
