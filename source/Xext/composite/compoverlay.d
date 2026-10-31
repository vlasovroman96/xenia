module composite.compoverlay;
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
//import x11.Xmd;

import dix.window_priv;
import Xext.panoramiXsrv;

import composite.compint;
import Xext.xace;
import composite.compwindow;
import externs.X11.extensions.composite_;
import externs.X11.extensions.render_;
import dix.resource;
import miext.damage.damage_;
import dix.gc;
import render.picture;
import build.xlibre_server;

/*
 * Delete the given overlay client list element from its screen list.
 */
void compFreeOverlayClient(CompOverlayClientPtr pOcToDel)
{
    ScreenPtr pScreen = pOcToDel.pScreen;
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    for ({CompOverlayClientPtr* pPrev = &cs.pOverlayClients; CompOverlayClientPtr pOc = void;}
                        ((pOc = *pPrev) !is null); pPrev = &pOc.pNext) {
        if (pOc == pOcToDel) {
            *pPrev = pOc.pNext;
            free(pOc);
            break;
        }
    }

    /* Destroy overlay window when there are no more clients using it */
    if (cs.pOverlayClients is null)
        compDestroyOverlayWindow(pScreen);
}

/*
 * Return the client's first overlay client rec from the given screen
 */
CompOverlayClientPtr compFindOverlayClient(ScreenPtr pScreen, ClientPtr pClient)
{
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    for (CompOverlayClientPtr pOc = cs.pOverlayClients;
                          pOc !is null; pOc = pOc.pNext)
        if (pOc.pClient == pClient)
            return pOc;

    return null;
}

/*
 * Create an overlay client object for the given client
 */
CompOverlayClientPtr compCreateOverlayClient(ScreenPtr pScreen, ClientPtr pClient)
{
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    CompOverlayClientPtr pOc = cast(CompOverlayClientRec*) calloc(1, CompOverlayClientRec.sizeof);
    if (pOc is null)
        return null;

    pOc.pClient = pClient;
    pOc.pScreen = pScreen;
    pOc.resource = FakeClientID(pClient.index);
    pOc.pNext = cs.pOverlayClients;
    cs.pOverlayClients = pOc;

    /*
     * Create a resource for this element so it can be deleted
     * when the client goes away.
     */
    if (!AddResource(cast(uint)pOc.resource, CompositeClientOverlayType, cast(void*) pOc))
        return null;

    return pOc;
}

/*
 * Create the overlay window and map it
 */
Bool compCreateOverlayWindow(ScreenPtr pScreen)
{
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));
    WindowPtr pRoot = pScreen.root;
    WindowPtr pWin = void;
    XID[2] attrs = [ None, TRUE ];       /* backPixmap, overrideRedirect */
    int result = void;
    int w = pScreen.width;
    int h = pScreen.height;
    int x = 0, y = 0;

static if(XINERAMA){
    if (!noPanoramiXExtension) {
        x = -pScreen.x;
        y = -pScreen.y;
        w = PanoramiXPixWidth;
        h = PanoramiXPixHeight;
    }
} /* XINERAMA */

    pWin = cs.pOverlayWin =
        dixCreateWindow(cs.overlayWid, pRoot, x, y, w, h, 0,
                     InputOutput, CWBackPixmap | CWOverrideRedirect, &attrs[0],
                     pRoot.drawable.depth,
                     serverClient, cast(uint)pScreen.rootVisual, &result);
    if (pWin is null)
        return FALSE;

    if (!AddResource(cast(uint)pWin.drawable.id, X11_RESTYPE_WINDOW, cast(void*) pWin))
        return FALSE;

    MapWindow(pWin, serverClient);

    return TRUE;
}

/*
 * Destroy the overlay window
 */
void compDestroyOverlayWindow(ScreenPtr pScreen)
{
    CompScreenPtr cs = mixin(GetCompScreen!("pScreen"));

    cs.pOverlayWin = NullWindow;
    FreeResource(cast(uint)cs.overlayWid, X11_RESTYPE_NONE);
}
