module dix.screenint_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 1987, 1998 The Open Group
 */
 
// // public //import stdbool;
//public import x11.Xdefs;
import build.xlibre_server;

public import dix.callback;
public import dix.scrintstr;
public import dix.scrnintstr; /* for screenInfo */
// import dix.scre

alias ScreenInitProcPtr = Bool function(ScreenPtr pScreen, int argc, char** argv);

// int AddScreen(ScreenInitProcPtr pfnInit, int argc, char** argv);
// int AddGPUScreen(ScreenInitProcPtr pfnInit, int argc, char** argv);

// void RemoveGPUScreen(ScreenPtr pScreen);

// void AttachUnboundGPU(ScreenPtr pScreen, ScreenPtr newScreen);
// void DetachUnboundGPU(ScreenPtr unbound);

// void AttachOffloadGPU(ScreenPtr pScreen, ScreenPtr newScreen);
// void DetachOffloadGPU(ScreenPtr slave);

void InitOutput(int argc, char** argv);

pragma(inline, true) ScreenPtr dixGetMasterScreen() {
    return screenInfo.screens[0];
}

/*
 * retrieve pointer to screen by it's index. If index is above the total
 * number of screens, returns NULL
 *
 * @param idx screen index
 * @return pointer to idx'th screen or NULL
 */
pragma(inline, true) ScreenPtr dixGetScreenPtr(uint idx) {
    if (idx < screenInfo.numScreens)
        return screenInfo.screens[idx];
    return null;
}

/*
 * check whether screen with given index exists
 *
 * @param idx screen index
 * @return TRUE if the screen at this index exists
 */
pragma(inline, true) bool dixScreenExists(uint idx) {
    return ((idx < screenInfo.numScreens) &&
            (screenInfo.screens[idx] !is null));
}

/*
 * macro for looping over all screens (up to `screenInfo.numScreens`).
 * Makes a new scopes and declares `walkScreenIdx` as the current screen's
 * index number as well as `walkScreen` as poiner to current ScreenRec
 *
 * @param __LAMBDA__ the code to be executed in each iteration step.
 */
enum string DIX_FOR_EACH_SCREEN(string __LAMBDA__) = `
        for (uint walkScreenIdx = 0; walkScreenIdx < screenInfo.numScreens; walkScreenIdx++) { 
            ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx]; 
            cast(void)walkScreen; 
            ` ~ __LAMBDA__ ~ `; 
        } `;

/*
 * macro for looping over all screens (up to `screenInfo.numScreens`),
 * but if XINERAMA enabled only hit the first screen.
 *
 * @param __LAMBDA__ the code to be executed in each iteration step.
 */
static if(XINERAMA){
enum string DIX_FOR_EACH_SCREEN_XINERAMA(string __LAMBDA__) = `
        uint __num_screens = screenInfo.numScreens; 
        if (!noPanoramiXExtension) 
            __num_screens = 1; 
        for (uint walkScreenIdx = 0; walkScreenIdx < __num_screens; walkScreenIdx++) { 
            ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx]; 
            cast(void)walkScreen; 
            ` ~ __LAMBDA__ ~ `; 
        } `;
} else {
alias DIX_FOR_EACH_SCREEN_XINERAMA = DIX_FOR_EACH_SCREEN;
}

/*
 * macro for looping over all GPU screens (up to `screenInfo.numScreens`).
 * Makes a new scopes and declares `walkScreenIdx` as the current screen's
 * index number as well as `walkScreen` as poiner to current ScreenRec
 *
 * @param __LAMBDA__ the code to be executed in each iteration step.
 */
enum string DIX_FOR_EACH_GPU_SCREEN(string __LAMBDA__) = `
    do { 
        for (uint walkScreenIdx = 0; walkScreenIdx < screenInfo.numGPUScreens; walkScreenIdx++) { 
            ScreenPtr walkScreen = screenInfo.gpuscreens[walkScreenIdx]; 
            cast(void)walkScreen; 
            ` ~ __LAMBDA__ ~ `; 
        } 
    } while (0);`;

CallbackListPtr ScreenAccessCallback;

struct ScreenAccessCallbackParam {
    ClientPtr client;
    ScreenPtr screen;
    Mask access_mode;
    int status;
}

pragma(inline, true) int dixCallScreenAccessCallback(ClientPtr client, ScreenPtr screen, Mask access_mode)
{
    ScreenAccessCallbackParam rec = { client, screen, access_mode, Success };
    CallCallbacks(&ScreenAccessCallback, &rec);
    return rec.status;
}

 /* _XSERVER_DIX_SCREENINT_PRIV_H */
