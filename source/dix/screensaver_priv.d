module dix.screensaver_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
// // public //import stdbool;
//public import x11.Xdefs;
//public import x11.Xmd;

public import dix.callback;
public import include.screenint;
public import include.scrnintstr;
public import dix.globals;

// CARD32 defaultScreenSaverTime;
// CARD32 defaultScreenSaverInterval;
// CARD32 ScreenSaverTime;
// CARD32 ScreenSaverInterval;
// Bool screenSaverSuspended;

CallbackListPtr ScreenSaverAccessCallback;

struct ScreenSaverAccessCallbackParam {
    ClientPtr client;
    ScreenPtr screen;
    Mask access_mode;
    int status;
}

pragma(inline, true) int dixCallScreensaverAccessCallback(ClientPtr client, ScreenPtr screen, Mask access_mode)
{
    ScreenSaverAccessCallbackParam rec = { client, screen, access_mode, Success };
    CallCallbacks(&ScreenSaverAccessCallback, &rec);
    return rec.status;
}

int screenIsSaved;

pragma(inline, true) bool HasSaverWindow(ScreenPtr pScreen) {
    return (pScreen.screensaver.pWindow != NullWindow);
}

 /* _XSERVER_DIX_SCREENSAVER_PRIV_H */
