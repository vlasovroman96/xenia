module pseudoramiX;
@nogc nothrow:
extern(C): __gshared:
/*
 * Minimal implementation of PanoramiX/Xinerama
 *
 * This is used in rootless mode where the underlying window server
 * already provides an abstracted view of multiple screens as one
 * large screen area.
 *
 * This code is largely based on panoramiX.c, which contains the
 * following copyright notice:
 */
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

import build.dix_config;

// //import x11.Xfuncproto;

import dix.dix_priv;
import dix.request_priv;
import miext.extinit_priv;

import pseudoramiX;
import dix.dixstruct_priv;
import include.window;
import externs.X11.extensions.panoramiXproto;
import os.log;
import dix.extension;

// enum TRACE = LogMessageVerb(X_NONE, 10, "TRACE " ~ __FILE__ ~":%s", __FUNCTION__.ptr);
// enum string DEBUG_LOG(__VA_ARGS__) = `LogMessageVerb(X_NONE, 3, `~__VA_ARGS__~`);`;

Bool noPseudoramiXExtension = FALSE;
Bool noRRXineramaExtension;

int ProcPanoramiXQueryVersion(ClientPtr client);










struct PseudoramiXScreenRec {
    int x;
    int y;
    int w;
    int h;
}

private PseudoramiXScreenRec* pseudoramiXScreens = null;
private int pseudoramiXScreensAllocated = 0;
private int pseudoramiXNumScreens = 0;

// Add a PseudoramiX screen.
// The rest of the X server will know nothing about this screen.
// Can be called before or after extension init.
// Screens must be re-added once per generation.
void PseudoramiXAddScreen(int x, int y, int w, int h)
{
    PseudoramiXScreenRec* s = void;

    if (noPseudoramiXExtension) return;

    if (pseudoramiXNumScreens == pseudoramiXScreensAllocated) {
        pseudoramiXScreensAllocated += pseudoramiXScreensAllocated + 1;
        pseudoramiXScreens = cast(PseudoramiXScreenRec*)reallocarray(pseudoramiXScreens,
                                          pseudoramiXScreensAllocated,
                                          PseudoramiXScreenRec.sizeof);
    }

    // mixin(DEBUG_LOG!(`"x: %d, y: %d, w: %d, h: %d\n"`, `x`, `y`, `w`, `h`));

    s = &pseudoramiXScreens[pseudoramiXNumScreens++];
    s.x = x;
    s.y = y;
    s.w = w;
    s.h = h;
}

// Initialize PseudoramiX.
// Copied from PanoramiXExtensionInit
void PseudoramiXExtensionInit()
{
    Bool success = FALSE;
    ExtensionEntry* extEntry = void;

    if (noPseudoramiXExtension) return;

    // TRACE;

    /* Even with only one screen we need to enable PseudoramiX to allow
       dynamic screen configuration changes. */
version (none) {
    if (pseudoramiXNumScreens == 1) {
        // Only one screen - disable Xinerama extension.
        noPseudoramiXExtension = TRUE;
        return;
    }
}

    extEntry = AddExtension(PANORAMIX_PROTOCOL_NAME, 0, 0,
                            &ProcPseudoramiXDispatch,
                            &ProcPseudoramiXDispatch,
                            &PseudoramiXResetProc,
                            &StandardMinorOpcode);
    if (!extEntry) {
        ErrorF("PseudoramiXExtensionInit(): AddExtension failed\n");
    }
    else {
        success = TRUE;
    }

    /* Do not allow RRXinerama to initialize if we did */
    noRRXineramaExtension = success;

    if (!success) {
        ErrorF("%s Extension (PseudoramiX) failed to initialize\n",
               PANORAMIX_PROTOCOL_NAME.ptr);
        return;
    }
}

void PseudoramiXResetScreens()
{
    // TRACE;

    pseudoramiXNumScreens = 0;
}

private void PseudoramiXResetProc(ExtensionEntry* extEntry)
{
    // TRACE;

    PseudoramiXResetScreens();
}

// was PanoramiX
private int ProcPseudoramiXGetState(ClientPtr client)
{
    mixin(REQUEST!xPanoramiXGetStateReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPanoramiXGetStateReq);

    if (client.swapped)
        swapl(&stuff.window);

    WindowPtr pWin = void;
    int rc = void;

    // TRACE;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xPanoramiXGetStateReply reply = {
        state: !noPseudoramiXExtension,
        window: stuff.window
    };

    if (client.swapped) {
        swapl(&reply.window);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

// was PanoramiX
private int ProcPseudoramiXGetScreenCount(ClientPtr client)
{
    mixin(REQUEST!xPanoramiXGetScreenCountReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPanoramiXGetScreenCountReq);

    if (client.swapped)
        swapl(&stuff.window);

    WindowPtr pWin = void;
    int rc = void;

    // TRACE;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xPanoramiXGetScreenCountReply reply = {
        ScreenCount: cast(ubyte)pseudoramiXNumScreens,
        window: stuff.window
    };

    if (client.swapped) {
        swapl(&reply.window);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

// was PanoramiX
private int ProcPseudoramiXGetScreenSize(ClientPtr client)
{
    mixin(REQUEST!xPanoramiXGetScreenSizeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPanoramiXGetScreenSizeReq);

    if (client.swapped) {
        swapl(&stuff.window);
        swapl(&stuff.screen);
    }

    WindowPtr pWin = void;
    int rc = void;

    // TRACE;

    if (stuff.screen >= pseudoramiXNumScreens)
      return BadMatch;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xPanoramiXGetScreenSizeReply reply = {
        width: pseudoramiXScreens[stuff.screen].w,
        height: pseudoramiXScreens[stuff.screen].h,
        window: stuff.window,
        screen: stuff.screen
    };

    if (client.swapped) {
        swapl(&reply.width);
        swapl(&reply.height);
        swapl(&reply.window);
        swapl(&reply.screen);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

// was Xinerama
private int ProcPseudoramiXIsActive(ClientPtr client)
{
    /* mixin(REQUEST!xXineramaIsActiveReq); */
    // TRACE;
    mixin(REQUEST_AT_LEAST_SIZE!xXineramaIsActiveReq);

    xXineramaIsActiveReply reply = {
        state: !noPseudoramiXExtension
    };

    if (client.swapped) {
        swapl(&reply.state);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

// was Xinerama
private int ProcPseudoramiXQueryScreens(ClientPtr client)
{
    /* mixin(REQUEST!xXineramaQueryScreensReq); */

    // mixin(DEBUG_LOG!(`"noPseudoramiXExtension=%d, pseudoramiXNumScreens=%d\n"`,
    //           `noPseudoramiXExtension`,
    //           `pseudoramiXNumScreens`));

    mixin(REQUEST_AT_LEAST_SIZE!xXineramaQueryScreensReq);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (!noPseudoramiXExtension) {
        for (int i = 0; i < pseudoramiXNumScreens; i++) {
            /* xXineramaScreenInfo is the same as xRectangle */
            x_rpcbuf_write_rect(&rpcbuf,
                                cast(short)pseudoramiXScreens[i].x,
                                cast(short)pseudoramiXScreens[i].y,
                                cast(short)pseudoramiXScreens[i].w,
                                cast(short)pseudoramiXScreens[i].h);
        }
    }

    xXineramaQueryScreensReply reply = {
        number: noPseudoramiXExtension ? 0 : pseudoramiXNumScreens
    };

    if (client.swapped)
        swapl(&reply.number);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

// was PanoramiX
private int ProcPseudoramiXDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    // TRACE;
    switch (stuff.data) {
    case X_PanoramiXQueryVersion:
        return ProcPanoramiXQueryVersion(client);

    case X_PanoramiXGetState:
        return ProcPseudoramiXGetState(client);

    case X_PanoramiXGetScreenCount:
        return ProcPseudoramiXGetScreenCount(client);

    case X_PanoramiXGetScreenSize:
        return ProcPseudoramiXGetScreenSize(client);

    case X_XineramaIsActive:
        return ProcPseudoramiXIsActive(client);

    case X_XineramaQueryScreens:
        return ProcPseudoramiXQueryScreens(client);
    default: break;}
    return BadRequest;
}
