module Xext.panoramiX;
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

import build.dix_config;

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
// //import x11.Xarch;
import externs.X11.extensions.panoramiXproto;

import dix.dix_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.rpcbuf_priv;
import dix.screen_hooks_priv;
import dix.screenint_priv;
import dix.server_priv;
import miext.extinit_priv;
import os.osdep;
import Xext.damage.damageext_priv;
import Xext.panoramiX;
import Xext.panoramiXsrv;

import include.misc;
import dix.cursor;
import dix.cursor;
import include.extnsionst;
import include.dixstruct;
import include.gc;
import include.gcstruct;
import include.scrnintstr;
import include.window;
import include.windowstr;
import include.pixmapstr;
import include.globals;
import include.servermd;
import include.resource;
import render.picturestr_priv;
import xfixes.xfixesint;
import composite.compint;
import include.protocol_versions;
import dix.extension;
import os.log;
import xfixes.xfixes;
import dix.dixutils;
import Xext.panoramiXprocs;
import dix.screen_hooks;
import render.render;
import tables;
import os.utils;


struct PanoramiXInfo {
    XID id;
}

struct PanoramiXRes {
    PanoramiXInfo[MAXSCREENS] info;
    RESTYPE type;
    union _U {
        struct _Win {
            char visibility = 0;
            char class_ = 0;
            char root = 0;
        }_Win win;
        struct _Pix {
            Bool shared_;
        }_Pix pix;
        struct _Pict {
            Bool root;
        }_Pict pict;
        char[4] raw_data;
    }_U u;
}

/*
 * macro for looping over all screens (up to `PanoramiXNumScreens`).
 * Makes a new scopes and declares `walkScreenIdx` as the current screen's
 * index number as well as `walkScreen` as poiner to current ScreenRec
 *
 * @param __LAMBDA__ the code to be executed in each iteration step.
 */
enum string XINERAMA_FOR_EACH_SCREEN_FORWARD(string __LAMBDA__) = `
    do { 
        for (uint walkScreenIdx = 0; walkScreenIdx < PanoramiXNumScreens; walkScreenIdx++) { 
            ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx]; 
            cast(void)walkScreen; 
            ` ~ __LAMBDA__ ~ `; 
        } 
    } while (0);`;

/*
 * just like XINERAMA_FOR_EACH_SCREEN_FORWARD(), but skipping the first
 * screen (which is the frontend to the client)
 *
 * @param __LAMBDA__ the code to be executed in each iteration step.
 */
enum string XINERAMA_FOR_EACH_SCREEN_FORWARD_SKIP0(string __LAMBDA__) = `
    do { 
        for (uint walkScreenIdx = 1; walkScreenIdx < PanoramiXNumScreens; walkScreenIdx++) { 
            ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx]; 
            cast(void)walkScreen; 
            ` ~ __LAMBDA__ ~ `; 
        } 
    } while (0);`;

/*
 * like XINERAMA_FOR_EACH_SCREEN_FORWARD(), but traveling backwards.
 *
 * @param __LAMBDA__ the code to be executed in each iteration step.
 */
enum string XINERAMA_FOR_EACH_SCREEN_BACKWARD(string __LAMBDA__) = `
    do { 
        for (uint __walkidx = PanoramiXNumScreens; __walkidx > 0; __walkidx--) { 
            uint walkScreenIdx = __walkidx - 1; 
            ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx]; 
            cast(void)walkScreen; 
            ` ~ __LAMBDA__ ~ `; 
        } 
    } while (0);`;

enum string FOR_NSCREENS_FORWARD(string j) = `for(` ~ j ~ ` = 0; ` ~ j ~ ` < PanoramiXNumScreens; ` ~ j ~ `++)`;
enum string FOR_NSCREENS_FORWARD_SKIP(string j) = `for(` ~ j ~ ` = 1; ` ~ j ~ ` < PanoramiXNumScreens; ` ~ j ~ `++)`;
enum string FOR_NSCREENS_BACKWARD(string j) = `for(` ~ j ~ ` = PanoramiXNumScreens - 1; ` ~ j ~ ` >= 0; ` ~ j ~ `--)`;

enum string IS_SHARED_PIXMAP(string r) = `(((` ~ r ~ `).type == XRT_PIXMAP) && (` ~ r ~ `).u.pix.shared_)`;

enum string IS_ROOT_DRAWABLE(string d) = `(((` ~ d ~ `).type == XRT_WINDOW) && (` ~ d ~ `).u.win.root)`;
                          /* _PANORAMIX_H_ */

/* Xinerama is disabled by default unless enabled via +xinerama */
Bool noPanoramiXExtension = TRUE;

/*
 *	PanoramiX data declarations
 */

int PanoramiXPixWidth = 0;
int PanoramiXPixHeight = 0;
int PanoramiXNumScreens = 0;

RegionRec PanoramiXScreenRegion = { {0, 0, 0, 0}, null };

private int PanoramiXNumDepths;
private DepthPtr PanoramiXDepths;
private int PanoramiXNumVisuals;
private VisualPtr PanoramiXVisuals;

RESTYPE XRC_DRAWABLE;
RESTYPE XRT_WINDOW;
RESTYPE XRT_PIXMAP;
RESTYPE XRT_GC;
RESTYPE XRT_COLORMAP;


private XineramaVisualsEqualProcPtr XineramaVisualsEqualPtr = &VisualsEqual;

/*
 *	Function prototypes
 */

static int ProcPanoramiXDispatch(ClientPtr client);

static void PanoramiXResetProc(_ExtensionEntry *);

/*
 *	External references for functions and data variables
 */

// import panoramiXh;

int function(ClientPtr client)[256] SavedProcVector = null;

private DevPrivateKeyRec PanoramiXGCKeyRec;
private DevPrivateKeyRec PanoramiXScreenKeyRec;

struct _PanoramiXGCRec {
    xPoint clipOrg;
    xPoint patOrg;
    const(GCFuncs)* wrapFuncs;
}alias PanoramiXGCRec = _PanoramiXGCRec;
alias PanoramiXGCPtr = _PanoramiXGCRec*;

struct _PanoramiXScreenRec {
    CreateGCProcPtr CreateGC;
}alias PanoramiXScreenRec = _PanoramiXScreenRec;
alias PanoramiXScreenPtr = _PanoramiXScreenRec*;

static void XineramaValidateGC(GCPtr, ulong, DrawablePtr);
static void XineramaChangeGC(GCPtr, ulong);
static void XineramaCopyGC(GCPtr, ulong, GCPtr);
static void XineramaDestroyGC(GCPtr);
static void XineramaChangeClip(GCPtr, int, void *, int);
static void XineramaDestroyClip(GCPtr);
static void XineramaCopyClip(GCPtr, GCPtr);

private const(GCFuncs) XineramaGCFuncs = {
    &XineramaValidateGC, &XineramaChangeGC, &XineramaCopyGC, &XineramaDestroyGC,
    &XineramaChangeClip, &XineramaDestroyClip, &XineramaCopyClip
};

enum string Xinerama_GC_FUNC_PROLOGUE(string pGC) = `
    PanoramiXGCPtr pGCPriv = cast(PanoramiXGCPtr) 
	dixLookupPrivate(&(` ~ pGC ~ `).devPrivates, &PanoramiXGCKeyRec); 
    (` ~ pGC ~ `).funcs = pGCPriv.wrapFuncs;`;

enum string Xinerama_GC_FUNC_EPILOGUE(string pGC) = `
    pGCPriv.wrapFuncs = (` ~ pGC ~ `).funcs;
    (` ~ pGC ~ `).funcs = &XineramaGCFuncs;`;

private void XineramaCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unsused)
{
    dixScreenUnhookClose(pScreen, &XineramaCloseScreen);

    PanoramiXScreenPtr pScreenPriv = cast(PanoramiXScreenPtr)
        dixLookupPrivate(&pScreen.devPrivates, &PanoramiXScreenKeyRec);

    if (!pScreenPriv)
        return;

    pScreen.CreateGC = pScreenPriv.CreateGC;

    if (pScreen.myNum == 0)
        RegionUninit(&PanoramiXScreenRegion);

    free(pScreenPriv);
    dixSetPrivate(&pScreen.devPrivates, &PanoramiXScreenKeyRec, null);
}

private Bool XineramaCreateGC(GCPtr pGC)
{
    ScreenPtr pScreen = pGC.pScreen;
    PanoramiXScreenPtr pScreenPriv = cast(PanoramiXScreenPtr)
        dixLookupPrivate(&pScreen.devPrivates, &PanoramiXScreenKeyRec);
    Bool ret = void;

    pScreen.CreateGC = pScreenPriv.CreateGC;
    if ((ret = pScreen.CreateGC(pGC)) != false) {
        PanoramiXGCPtr pGCPriv = cast(PanoramiXGCPtr)
            dixLookupPrivate(&pGC.devPrivates, &PanoramiXGCKeyRec);

        pGCPriv.wrapFuncs = pGC.funcs;
        pGC.funcs = &XineramaGCFuncs;

        pGCPriv.clipOrg.x = pGC.clipOrg.x;
        pGCPriv.clipOrg.y = pGC.clipOrg.y;
        pGCPriv.patOrg.x = pGC.patOrg.x;
        pGCPriv.patOrg.y = pGC.patOrg.y;
    }
    pScreen.CreateGC = &XineramaCreateGC;

    return ret;
}

private void XineramaValidateGC(GCPtr pGC, c_ulong changes, DrawablePtr pDraw)
{
    mixin(Xinerama_GC_FUNC_PROLOGUE!(`pGC`));

    if ((pDraw.type == DRAWABLE_WINDOW) && !((cast(WindowPtr) pDraw).parent)) {
        /* the root window */
        int x_off = pGC.pScreen.x;
        int y_off = pGC.pScreen.y;
        int new_val = void;

        new_val = pGCPriv.clipOrg.x - x_off;
        if (pGC.clipOrg.x != new_val) {
            pGC.clipOrg.x = cast(ushort)new_val;
            changes |= GCClipXOrigin;
        }
        new_val = pGCPriv.clipOrg.y - y_off;
        if (pGC.clipOrg.y != new_val) {
            pGC.clipOrg.y = cast(ushort)new_val;
            changes |= GCClipYOrigin;
        }
        new_val = pGCPriv.patOrg.x - x_off;
        if (pGC.patOrg.x != new_val) {
            pGC.patOrg.x = cast(ushort)new_val;
            changes |= GCTileStipXOrigin;
        }
        new_val = pGCPriv.patOrg.y - y_off;
        if (pGC.patOrg.y != new_val) {
            pGC.patOrg.y = cast(ushort)new_val;
            changes |= GCTileStipYOrigin;
        }
    }
    else {
        if (pGC.clipOrg.x != pGCPriv.clipOrg.x) {
            pGC.clipOrg.x = pGCPriv.clipOrg.x;
            changes |= GCClipXOrigin;
        }
        if (pGC.clipOrg.y != pGCPriv.clipOrg.y) {
            pGC.clipOrg.y = pGCPriv.clipOrg.y;
            changes |= GCClipYOrigin;
        }
        if (pGC.patOrg.x != pGCPriv.patOrg.x) {
            pGC.patOrg.x = pGCPriv.patOrg.x;
            changes |= GCTileStipXOrigin;
        }
        if (pGC.patOrg.y != pGCPriv.patOrg.y) {
            pGC.patOrg.y = pGCPriv.patOrg.y;
            changes |= GCTileStipYOrigin;
        }
    }

    (*pGC.funcs.ValidateGC) (pGC, changes, pDraw);
    mixin(Xinerama_GC_FUNC_EPILOGUE!(`pGC`));
}

private void XineramaDestroyGC(GCPtr pGC)
{
    mixin(Xinerama_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.DestroyGC) (pGC);
    mixin(Xinerama_GC_FUNC_EPILOGUE!(`pGC`));
}

private void XineramaChangeGC(GCPtr pGC, c_ulong mask)
{
    mixin(Xinerama_GC_FUNC_PROLOGUE!(`pGC`));

    if (mask & GCTileStipXOrigin)
        pGCPriv.patOrg.x = pGC.patOrg.x;
    if (mask & GCTileStipYOrigin)
        pGCPriv.patOrg.y = pGC.patOrg.y;
    if (mask & GCClipXOrigin)
        pGCPriv.clipOrg.x = pGC.clipOrg.x;
    if (mask & GCClipYOrigin)
        pGCPriv.clipOrg.y = pGC.clipOrg.y;

    (*pGC.funcs.ChangeGC) (pGC, mask);
    mixin(Xinerama_GC_FUNC_EPILOGUE!(`pGC`));
}

private void XineramaCopyGC(GCPtr pGCSrc, c_ulong mask, GCPtr pGCDst)
{
    PanoramiXGCPtr pSrcPriv = cast(PanoramiXGCPtr)
        dixLookupPrivate(&pGCSrc.devPrivates, &PanoramiXGCKeyRec);

    mixin(Xinerama_GC_FUNC_PROLOGUE!(`pGCDst`));

    if (mask & GCTileStipXOrigin)
        pGCPriv.patOrg.x = pSrcPriv.patOrg.x;
    if (mask & GCTileStipYOrigin)
        pGCPriv.patOrg.y = pSrcPriv.patOrg.y;
    if (mask & GCClipXOrigin)
        pGCPriv.clipOrg.x = pSrcPriv.clipOrg.x;
    if (mask & GCClipYOrigin)
        pGCPriv.clipOrg.y = pSrcPriv.clipOrg.y;

    (*pGCDst.funcs.CopyGC) (pGCSrc, mask, pGCDst);
    mixin(Xinerama_GC_FUNC_EPILOGUE!(`pGCDst`));
}

private void XineramaChangeClip(GCPtr pGC, int type, void* pvalue, int nrects)
{
    mixin(Xinerama_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.ChangeClip) (pGC, type, pvalue, nrects);
    mixin(Xinerama_GC_FUNC_EPILOGUE!(`pGC`));
}

private void XineramaCopyClip(GCPtr pgcDst, GCPtr pgcSrc)
{
    mixin(Xinerama_GC_FUNC_PROLOGUE!(`pgcDst`));
    (*pgcDst.funcs.CopyClip) (pgcDst, pgcSrc);
    mixin(Xinerama_GC_FUNC_EPILOGUE!(`pgcDst`));
}

private void XineramaDestroyClip(GCPtr pGC)
{
    mixin(Xinerama_GC_FUNC_PROLOGUE!(`pGC`));
    (*pGC.funcs.DestroyClip) (pGC);
    mixin(Xinerama_GC_FUNC_EPILOGUE!(`pGC`));
}

int XineramaDeleteResource(void* data, XID id)
{
    free(data);
    return 1;
}

struct PanoramiXSearchData {
    int screen;
    int id;
}

private Bool XineramaFindIDByScrnum(void* resource, XID id, void* privdata)
{
    PanoramiXRes* res = cast(PanoramiXRes*) resource;
    PanoramiXSearchData* data = cast(PanoramiXSearchData*) privdata;

    return res.info[data.screen].id == data.id;
}

PanoramiXRes* PanoramiXFindIDByScrnum(RESTYPE type, XID id, int screen)
{
    PanoramiXSearchData data = void;
    void* val = void;

    if (!screen) {
        dixLookupResourceByType(&val, id, type, serverClient, DixReadAccess);
        return cast(PanoramiXRes*)val;
    }

    data.screen = screen;
    data.id = cast(int)id;

    return cast(PanoramiXRes*)LookupClientResourceComplex(dixClientForXID(id), type,
                                       &XineramaFindIDByScrnum, &data);
}

struct _connect_callback_list {
    void function() @nogc nothrow func;
    _connect_callback_list* next;
}

alias XineramaConnectionCallbackList = _connect_callback_list;

private XineramaConnectionCallbackList* ConnectionCallbackList = null;

Bool XineramaRegisterConnectionBlockCallback(void function() @nogc nothrow func)
{
    XineramaConnectionCallbackList* newlist = void;

    if (((newlist = cast(XineramaConnectionCallbackList*) cast(XineramaConnectionCallbackList*) calloc(1, XineramaConnectionCallbackList.sizeof)) is null))
        return FALSE;

    newlist.next = ConnectionCallbackList;
    newlist.func = func;
    ConnectionCallbackList = newlist;

    return TRUE;
}

private void XineramaInitData()
{
    RegionNull(&PanoramiXScreenRegion);

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        BoxRec TheBox = void;
        RegionRec ScreenRegion = void;

        TheBox.x1 = walkScreen.x;
        TheBox.x2 = cast(short)(TheBox.x1 + walkScreen.width);
        TheBox.y1 = walkScreen.y;
        TheBox.y2 = cast(short)(TheBox.y1 + walkScreen.height);

        RegionInit(&ScreenRegion, &TheBox, 1);
        RegionUnion(&PanoramiXScreenRegion, &PanoramiXScreenRegion,
                    &ScreenRegion);
        RegionUninit(&ScreenRegion);
    }));

    ScreenPtr masterScreen = dixGetMasterScreen();

    PanoramiXPixWidth = masterScreen.x + masterScreen.width;
    PanoramiXPixHeight = masterScreen.y + masterScreen.height;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD_SKIP0!(q{
        int w = walkScreen.x + walkScreen.width;
        int h = walkScreen.y + walkScreen.height;

        if (PanoramiXPixWidth < w)
            PanoramiXPixWidth = w;
        if (PanoramiXPixHeight < h)
            PanoramiXPixHeight = h;
    }));
}

/*
 *	PanoramiXExtensionInit():
 //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
 *		Called from InitExtensions in main().
 *		Register PanoramiXeen Extension
 *		Initialize global variables.
 */

void PanoramiXExtensionInit()
{
    int i = void;
    Bool success = FALSE;
    ScreenPtr masterScreen = dixGetMasterScreen();

    if (noPanoramiXExtension)
        return;

    if (!dixRegisterPrivateKey(&PanoramiXScreenKeyRec, PRIVATE_SCREEN, 0)) {
        noPanoramiXExtension = TRUE;
        return;
    }

    if (!dixRegisterPrivateKey
        (&PanoramiXGCKeyRec, PRIVATE_GC, PanoramiXGCRec.sizeof)) {
        noPanoramiXExtension = TRUE;
        return;
    }

    PanoramiXNumScreens = screenInfo.numScreens;
    if (PanoramiXNumScreens == 1) {     /* Only 1 screen        */
        noPanoramiXExtension = TRUE;
        return;
    }

    ExtensionEntry* extEntry = AddExtension(
        PANORAMIX_PROTOCOL_NAME, 0, 0,
        &ProcPanoramiXDispatch,
        &ProcPanoramiXDispatch,
        &PanoramiXResetProc,
        &StandardMinorOpcode);

    if (!extEntry)
        return;

    /*
     *      First make sure all the basic allocations succeed.  If not,
     *      run in non-PanoramiXeen mode.
     */
    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        PanoramiXScreenPtr pScreenPriv = cast(PanoramiXScreenPtr)cast(PanoramiXScreenRec*) calloc(1, PanoramiXScreenRec.sizeof);
        dixSetPrivate(&walkScreen.devPrivates, &PanoramiXScreenKeyRec,
                      pScreenPriv);
        if (!pScreenPriv) {
            noPanoramiXExtension = TRUE;
            return;
        }

        dixScreenHookClose(walkScreen, &XineramaCloseScreen);
        pScreenPriv.CreateGC = masterScreen.CreateGC;
        walkScreen.CreateGC = &XineramaCreateGC;
    }));

    XRC_DRAWABLE = CreateNewResourceClass();
    XRT_WINDOW = CreateNewResourceType(&XineramaDeleteResource,
                                           "XineramaWindow");
    if (XRT_WINDOW)
        XRT_WINDOW |= XRC_DRAWABLE;

    XRT_PIXMAP = CreateNewResourceType(&XineramaDeleteResource,
                                           "XineramaPixmap");
    if (XRT_PIXMAP)
        XRT_PIXMAP |= XRC_DRAWABLE;

    XRT_GC = CreateNewResourceType(&XineramaDeleteResource, "XineramaGC");
    XRT_COLORMAP = CreateNewResourceType(&XineramaDeleteResource,
                                             "XineramaColormap");

    if (XRT_WINDOW && XRT_PIXMAP && XRT_GC && XRT_COLORMAP)
        success = TRUE;

    SetResourceTypeErrorValue(XRT_WINDOW, BadWindow);
    SetResourceTypeErrorValue(XRT_PIXMAP, BadPixmap);
    SetResourceTypeErrorValue(XRT_GC, BadGC);
    SetResourceTypeErrorValue(XRT_COLORMAP, BadColor);

    if (!success) {
        noPanoramiXExtension = TRUE;
        ErrorF(PANORAMIX_PROTOCOL_NAME ~ " extension failed to initialize\n");
        return;
    }

    XineramaInitData();

    /*
     *  Put our processes into the ProcVector
     */

    for (i = 256; i--;)
        SavedProcVector[i] = ProcVector[i];

    ProcVector[X_CreateWindow] = &PanoramiXCreateWindow;
    ProcVector[X_ChangeWindowAttributes] = &PanoramiXChangeWindowAttributes;
    ProcVector[X_DestroyWindow] = &PanoramiXDestroyWindow;
    ProcVector[X_DestroySubwindows] = &PanoramiXDestroySubwindows;
    ProcVector[X_ChangeSaveSet] = &PanoramiXChangeSaveSet;
    ProcVector[X_ReparentWindow] = &PanoramiXReparentWindow;
    ProcVector[X_MapWindow] = &PanoramiXMapWindow;
    ProcVector[X_MapSubwindows] = &PanoramiXMapSubwindows;
    ProcVector[X_UnmapWindow] = &PanoramiXUnmapWindow;
    ProcVector[X_UnmapSubwindows] = &PanoramiXUnmapSubwindows;
    ProcVector[X_ConfigureWindow] = &PanoramiXConfigureWindow;
    ProcVector[X_CirculateWindow] = &PanoramiXCirculateWindow;
    ProcVector[X_GetGeometry] = &PanoramiXGetGeometry;
    ProcVector[X_TranslateCoords] = &PanoramiXTranslateCoords;
    ProcVector[X_CreatePixmap] = &PanoramiXCreatePixmap;
    ProcVector[X_FreePixmap] = &PanoramiXFreePixmap;
    ProcVector[X_CreateGC] = &PanoramiXCreateGC;
    ProcVector[X_ChangeGC] = &PanoramiXChangeGC;
    ProcVector[X_CopyGC] = &PanoramiXCopyGC;
    ProcVector[X_SetDashes] = &PanoramiXSetDashes;
    ProcVector[X_SetClipRectangles] = &PanoramiXSetClipRectangles;
    ProcVector[X_FreeGC] = &PanoramiXFreeGC;
    ProcVector[X_ClearArea] = &PanoramiXClearToBackground;
    ProcVector[X_CopyArea] = &PanoramiXCopyArea;
    ProcVector[X_CopyPlane] = &PanoramiXCopyPlane;
    ProcVector[X_PolyPoint] = &PanoramiXPolyPoint;
    ProcVector[X_PolyLine] = &PanoramiXPolyLine;
    ProcVector[X_PolySegment] = &PanoramiXPolySegment;
    ProcVector[X_PolyRectangle] = &PanoramiXPolyRectangle;
    ProcVector[X_PolyArc] = &PanoramiXPolyArc;
    ProcVector[X_FillPoly] = &PanoramiXFillPoly;
    ProcVector[X_PolyFillRectangle] = &PanoramiXPolyFillRectangle;
    ProcVector[X_PolyFillArc] = &PanoramiXPolyFillArc;
    ProcVector[X_PutImage] = &PanoramiXPutImage;
    ProcVector[X_GetImage] = &PanoramiXGetImage;
    ProcVector[X_PolyText8] = &PanoramiXPolyText8;
    ProcVector[X_PolyText16] = &PanoramiXPolyText16;
    ProcVector[X_ImageText8] = &PanoramiXImageText8;
    ProcVector[X_ImageText16] = &PanoramiXImageText16;
    ProcVector[X_CreateColormap] = &PanoramiXCreateColormap;
    ProcVector[X_FreeColormap] = &PanoramiXFreeColormap;
    ProcVector[X_CopyColormapAndFree] = &PanoramiXCopyColormapAndFree;
    ProcVector[X_InstallColormap] = &PanoramiXInstallColormap;
    ProcVector[X_UninstallColormap] = &PanoramiXUninstallColormap;
    ProcVector[X_AllocColor] = &PanoramiXAllocColor;
    ProcVector[X_AllocNamedColor] = &PanoramiXAllocNamedColor;
    ProcVector[X_AllocColorCells] = &PanoramiXAllocColorCells;
    ProcVector[X_AllocColorPlanes] = &PanoramiXAllocColorPlanes;
    ProcVector[X_FreeColors] = &PanoramiXFreeColors;
    ProcVector[X_StoreColors] = &PanoramiXStoreColors;
    ProcVector[X_StoreNamedColor] = &PanoramiXStoreNamedColor;

    PanoramiXRenderInit();
    PanoramiXFixesInit();
    PanoramiXDamageInit();
    PanoramiXCompositeInit();
}

Bool PanoramiXCreateConnectionBlock()
{
    int i = void, j = void, length = void;
    Bool disable_backing_store = FALSE;
    int old_width = void, old_height = void;
    float width_mult = void, height_mult = void;
    xWindowRoot* root = void;
    xVisualType* visual = void;
    xDepth* depth = void;
    VisualPtr pVisual = void;

    /*
     *  Do normal CreateConnectionBlock but faking it for only one screen
     */

    if (!PanoramiXNumDepths) {
        ErrorF("Xinerama error: No common visuals\n");
        return FALSE;
    }

    ScreenPtr masterScreen = dixGetMasterScreen();
    mixin(DIX_FOR_EACH_SCREEN!q{
        if (!walkScreenIdx)
            continue;  /* skip the first one */

        if (walkScreen.rootDepth != masterScreen.rootDepth) {
            ErrorF("Xinerama error: Root window depths differ\n");
            return FALSE;
        }
        if (walkScreen.backingStoreSupport !=
            masterScreen.backingStoreSupport)
            disable_backing_store = TRUE;
    });

    if (disable_backing_store) {
        mixin(DIX_FOR_EACH_SCREEN!q{
            walkScreen.backingStoreSupport = NotUseful;
        });
    }

    i = screenInfo.numScreens;
    screenInfo.numScreens = 1;
    if (!CreateConnectionBlock()) {
        screenInfo.numScreens = i;
        return FALSE;
    }

    screenInfo.numScreens = i;

    root = cast(xWindowRoot*) (ConnectionInfo + connBlockScreenStart);
    length = cast(int)(connBlockScreenStart + xWindowRoot.sizeof);

    /* overwrite the connection block */
    root.nDepths = cast(ubyte)PanoramiXNumDepths;

    for (uint walkScreenIdx = 0; walkScreenIdx < PanoramiXNumDepths; walkScreenIdx++) {
        depth = cast(xDepth*) (ConnectionInfo + length);
        depth.depth = PanoramiXDepths[walkScreenIdx].depth;
        depth.nVisuals = PanoramiXDepths[walkScreenIdx].numVids;
        length += xDepth.sizeof;
        visual = cast(xVisualType*) (ConnectionInfo + length);

        for (j = 0; j < depth.nVisuals; j++, visual++) {
            visual.visualID = cast(uint)PanoramiXDepths[walkScreenIdx].vids[j];

            for (pVisual = PanoramiXVisuals;
                 pVisual.vid != visual.visualID; pVisual++){}

            __traits(getMember, *visual, "class_")  = cast(ubyte)pVisual.class_;
            visual.bitsPerRGB = cast(ubyte)pVisual.bitsPerRGBValue;
            visual.colormapEntries = pVisual.ColormapEntries;
            visual.redMask = cast(uint)pVisual.redMask;
            visual.greenMask = cast(uint)pVisual.greenMask;
            visual.blueMask = cast(uint)pVisual.blueMask;
        }

        length += (depth.nVisuals * xVisualType.sizeof);
    }

    connSetupPrefix.length = cast(ushort)bytes_to_int32(length);

    for (uint walkScreenIdx = 0; walkScreenIdx < PanoramiXNumDepths; walkScreenIdx++)
        free(PanoramiXDepths[walkScreenIdx].vids);
    free(PanoramiXDepths);
    PanoramiXDepths = null;

    /*
     *  OK, change some dimensions so it looks as if it were one big screen
     */

    old_width = root.pixWidth;
    old_height = root.pixHeight;

    root.pixWidth = cast(ushort)PanoramiXPixWidth;
    root.pixHeight = cast(ushort)PanoramiXPixHeight;
    width_mult = (1.0 * root.pixWidth) / old_width;
    height_mult = (1.0 * root.pixHeight) / old_height;
    root.mmWidth *= width_mult;
    root.mmHeight *= height_mult;

    while (ConnectionCallbackList) {
        void* tmp = void;

        tmp = cast(void*) ConnectionCallbackList;
        (*ConnectionCallbackList.func) ();
        ConnectionCallbackList = ConnectionCallbackList.next;
        free(tmp);
    }

    return TRUE;
}

/*
 * This isn't just memcmp(), bitsPerRGBValue is skipped.  markv made that
 * change way back before xf86 4.0, but the comment for _why_ is a bit
 * opaque, so I'm not going to question it for now.
 *
 * This is probably better done as a screen hook so DBE/EVI/GLX can add
 * their own tests, and adding privates to VisualRec so they don't have to
 * do their own back-mapping.
 */
private Bool VisualsEqual(VisualPtr a, ScreenPtr pScreenB, VisualPtr b)
{
    return ((a.class_ == b.class_) &&
            (a.ColormapEntries == b.ColormapEntries) &&
            (a.nplanes == b.nplanes) &&
            (a.redMask == b.redMask) &&
            (a.greenMask == b.greenMask) &&
            (a.blueMask == b.blueMask) &&
            (a.offsetRed == b.offsetRed) &&
            (a.offsetGreen == b.offsetGreen) &&
            (a.offsetBlue == b.offsetBlue));
}

private void PanoramiXMaybeAddDepth(DepthPtr pDepth)
{
    int k = void;
    Bool found = FALSE;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD_SKIP0!(q{
        for (k = 0; k < walkScreen.numDepths; k++) {
            if (walkScreen.allowedDepths[k].depth == pDepth.depth) {
                found = TRUE;
                break;
            }
        }
    }));

    if (!found)
        return;

    int j = PanoramiXNumDepths;
    PanoramiXNumDepths++;
    PanoramiXDepths = cast(_Depth*)XNFreallocarray(PanoramiXDepths,
                                      PanoramiXNumDepths, DepthRec.sizeof);
    PanoramiXDepths[j].depth = pDepth.depth;
    PanoramiXDepths[j].numVids = 0;
    PanoramiXDepths[j].vids = null;
}

private void PanoramiXMaybeAddVisual(VisualPtr pVisual)
{
    int k = void;
    Bool found = FALSE;

    mixin(XINERAMA_FOR_EACH_SCREEN_FORWARD_SKIP0!(q{
        found = FALSE;

        for (k = 0; k < walkScreen.numVisuals; k++) {
            VisualPtr candidate = &walkScreen.visuals[k];

            if ((*XineramaVisualsEqualPtr) (pVisual, walkScreen, candidate)) {
                found = TRUE;
                break;
            }
        }

        if (!found)
            return;
    }));

    /* found a matching visual on all screens, add it to the subset list */
    int j = PanoramiXNumVisuals;
    PanoramiXNumVisuals++;
    PanoramiXVisuals = cast(_Visual*)XNFreallocarray(PanoramiXVisuals,
                                       PanoramiXNumVisuals, VisualRec.sizeof);

    memcpy(&PanoramiXVisuals[j], pVisual, VisualRec.sizeof);

    for (k = 0; k < PanoramiXNumDepths; k++) {
        if (PanoramiXDepths[k].depth == pVisual.nplanes) {
            PanoramiXDepths[k].vids = cast(uint*)XNFreallocarray(PanoramiXDepths[k].vids,
                                                      PanoramiXDepths[k].numVids + 1,
                                                      VisualID.sizeof);
            PanoramiXDepths[k].vids[PanoramiXDepths[k].numVids] = pVisual.vid;
            PanoramiXDepths[k].numVids++;
            break;
        }
    }
}

void PanoramiXConsolidate()
{
    ScreenPtr masterScreen = dixGetMasterScreen();
    DepthPtr pDepth = masterScreen.allowedDepths;
    VisualPtr pVisual = masterScreen.visuals;

    PanoramiXNumDepths = 0;
    PanoramiXNumVisuals = 0;

    for (int i = 0; i < masterScreen.numDepths; i++)
        PanoramiXMaybeAddDepth(pDepth++);

    for (int i = 0; i < masterScreen.numVisuals; i++)
        PanoramiXMaybeAddVisual(pVisual++);

    PanoramiXRes* root = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof);
    if (!root)
        return;

    root.type = XRT_WINDOW;
    PanoramiXRes* defmap = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof);
    if (!defmap) {
        free(root);
        return;
    }
    defmap.type = XRT_COLORMAP;
    PanoramiXRes* saver = cast(PanoramiXRes*) cast(PanoramiXRes*) calloc(1, PanoramiXRes.sizeof);
    if (!saver) {
        free(root);
        free(defmap);
        return;
    }
    saver.type = XRT_WINDOW;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        root.info[walkScreenIdx].id = cast(uint)walkScreen.root.drawable.id;
        root.u.win.class_ = InputOutput;
        root.u.win.root = TRUE;
        saver.info[walkScreenIdx].id = walkScreen.screensaver.wid;
        saver.u.win.class_ = InputOutput;
        saver.u.win.root = TRUE;
        defmap.info[walkScreenIdx].id = cast(uint)walkScreen.defColormap;
    }));

    AddResource(cast(uint)root.info[0].id, XRT_WINDOW, root);
    AddResource(cast(uint)saver.info[0].id, XRT_WINDOW, saver);
    AddResource(cast(uint)defmap.info[0].id, XRT_COLORMAP, defmap);
}

VisualID PanoramiXTranslateVisualID(int screen, VisualID orig)
{
    ScreenPtr pOtherScreen = dixGetScreenPtr(cast(uint)screen);
    VisualPtr pVisual = null;
    int i = void;

    for (i = 0; i < PanoramiXNumVisuals; i++) {
        if (orig == PanoramiXVisuals[i].vid) {
            pVisual = &PanoramiXVisuals[i];
            break;
        }
    }

    if (!pVisual)
        return 0;

    /* if screen is 0, orig is already the correct visual ID */
    if (screen == 0)
        return orig;

    /* found the original, now translate it relative to the backend screen */
    for (i = 0; i < pOtherScreen.numVisuals; i++) {
        VisualPtr pOtherVisual = &pOtherScreen.visuals[i];

        if ((*XineramaVisualsEqualPtr) (pVisual, pOtherScreen, pOtherVisual))
            return pOtherVisual.vid;
    }

    return 0;
}

/*
 *	PanoramiXResetProc()
 *		Exit, deallocating as needed.
 */

private void PanoramiXResetProc(_ExtensionEntry* extEntry)
{
    int i = void;

    PanoramiXRenderReset();
    PanoramiXFixesReset();
    PanoramiXDamageReset();
    PanoramiXCompositeReset ();
    screenInfo.numScreens = PanoramiXNumScreens;
    for (i = 256; i--;)
        ProcVector[i] = SavedProcVector[i];
}

int ProcPanoramiXQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xPanoramiXQueryVersionReq);

    xPanoramiXQueryVersionReply reply = {
        majorVersion: SERVER_PANORAMIX_MAJOR_VERSION,
        minorVersion: SERVER_PANORAMIX_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcPanoramiXGetState(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xPanoramiXGetStateReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xPanoramiXGetStateReply reply = {
        state: !noPanoramiXExtension,
        window: stuff.window
    };

    mixin(X_REPLY_FIELD_CARD32!"window");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcPanoramiXGetScreenCount(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xPanoramiXGetScreenCountReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xPanoramiXGetScreenCountReply reply = {
        ScreenCount: cast(ubyte)PanoramiXNumScreens,
        window: stuff.window
    };

    mixin(X_REPLY_FIELD_CARD32!"window");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcPanoramiXGetScreenSize(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xPanoramiXGetScreenSizeReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"screen");

    if (stuff.screen >= PanoramiXNumScreens)
        return BadMatch;

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);

    xPanoramiXGetScreenSizeReply reply = {
        /* screen dimensions */
        width: pScreen.width,
        height: pScreen.height,
        window: stuff.window,
        screen: stuff.screen
    };

    mixin(X_REPLY_FIELD_CARD32!"width");
    mixin(X_REPLY_FIELD_CARD32!"height");
    mixin(X_REPLY_FIELD_CARD32!"window");
    mixin(X_REPLY_FIELD_CARD32!"screen");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcXineramaIsActive(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXineramaIsActiveReq);

    xXineramaIsActiveReply reply = {
// #if 1
        /* The following hack fools clients into thinking that Xinerama
         * is disabled even though it is not. */
        state: !noPanoramiXExtension && !PanoramiXExtensionDisabledHack
//! #else
        // .state = !noPanoramiXExtension;
//! #endif
    };

    mixin(X_REPLY_FIELD_CARD32!"state");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcXineramaQueryScreens(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXineramaQueryScreensReq);

    CARD32 number = (noPanoramiXExtension) ? 0 : PanoramiXNumScreens;
    xXineramaQueryScreensReply reply = {
        number: number
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (!noPanoramiXExtension) {
        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            /* xXineramaScreenInfo is the same as xRectangle */
            x_rpcbuf_write_rect(&rpcbuf,
                                walkScreen.x,
                                walkScreen.y,
                                walkScreen.width,
                                walkScreen.height);
        }));
    }

    mixin(X_REPLY_FIELD_CARD32!"number");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcPanoramiXDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_PanoramiXQueryVersion:
        return ProcPanoramiXQueryVersion(client);
    case X_PanoramiXGetState:
        return ProcPanoramiXGetState(client);
    case X_PanoramiXGetScreenCount:
        return ProcPanoramiXGetScreenCount(client);
    case X_PanoramiXGetScreenSize:
        return ProcPanoramiXGetScreenSize(client);
    case X_XineramaIsActive:
        return ProcXineramaIsActive(client);
    case X_XineramaQueryScreens:
        return ProcXineramaQueryScreens(client);
    default: break;}
    return BadRequest;
}

static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
enum string SHIFT_L(string v,string s) = `(` ~ v ~ `) << (` ~ s ~ `)`;
enum string SHIFT_R(string v,string s) = `(` ~ v ~ `) >> (` ~ s ~ `)`;
} else {
enum string SHIFT_L(string v,string s) = `(` ~ v ~ `) >> (` ~ s ~ `)`;
enum string SHIFT_R(string v,string s) = `(` ~ v ~ `) << (` ~ s ~ `)`;
}

private void CopyBits(char* dst, int shiftL, char* src, int bytes)
{
    /* Just get it to work.  Worry about speed later */
    int shiftR = 8 - shiftL;

    while (bytes--) {
        *dst |= mixin(SHIFT_L!(`*src`, `shiftL`));
        *(dst + 1) |= mixin(SHIFT_R!(`*src`, `shiftR`));
        dst++;
        src++;
    }
}

/* Caution.  This doesn't support 2 and 4 bpp formats.  We expect
   1 bpp and planar data to be already cleared when presented
   to this function */

private Bool XineramaGetImageDataScr(BoxRec SrcBox, RegionPtr GrabRegion, RegionPtr SrcRegion, const(int) width, const(int) height, const(uint) format, const(c_ulong) planemask, char* data, const(int) depth, const(int) pitch, ScreenPtr walkScreen, DrawablePtr pWalkDraw)
{
        BoxRec TheBox = void;

        ScreenPtr pScreen = pWalkDraw.pScreen;

        TheBox.x1 = pScreen.x;
        TheBox.x2 = cast(ushort)(TheBox.x1 + pScreen.width);
        TheBox.y1 = pScreen.y;
        TheBox.y2 = cast(ushort)(TheBox.y1 + pScreen.height);

        RegionRec ScreenRegion = void;
        RegionInit(&ScreenRegion, &TheBox, 1);
        int inOut = RegionContainsRect(&ScreenRegion, &SrcBox);
        if (inOut == rgnPART)
            RegionIntersect(GrabRegion, SrcRegion, &ScreenRegion);
        RegionUninit(&ScreenRegion);

        if (inOut == rgnIN) {
            pScreen.GetImage(pWalkDraw,
                                  SrcBox.x1 - pWalkDraw.x -
                                  walkScreen.x,
                                  SrcBox.y1 - pWalkDraw.y -
                                  walkScreen.y, width, height,
                                  format, planemask, data);
            return FALSE;
        }
        else if (inOut == rgnOUT)
            return TRUE;

        int nbox = RegionNumRects(GrabRegion);
        if (!nbox)
            return TRUE;

        BoxRec* pbox = RegionRects(GrabRegion);

        int size = 0;
        char* ScratchMem = null;

        while (nbox--) {
            int w = pbox.x2 - pbox.x1;
            int h = pbox.y2 - pbox.y1;
            int ScratchPitch = PixmapBytePad(w, depth);
            int sizeNeeded = ScratchPitch * h;

            if (sizeNeeded > size) {
                char* tmpdata = ScratchMem;

                ScratchMem = cast(char*) realloc(ScratchMem, sizeNeeded);
                if (ScratchMem)
                    size = sizeNeeded;
                else {
                    ScratchMem = tmpdata;
                    break;
                }
            }

            int x = pbox.x1 - pWalkDraw.x - walkScreen.x;
            int y = pbox.y1 - pWalkDraw.y - walkScreen.y;

            (*pScreen.GetImage) (pWalkDraw, x, y, w, h,
                                  format, planemask, ScratchMem);

            /* copy the memory over */

            if (depth == 1) {
                int shift = void, leftover = void;

                x = pbox.x1 - SrcBox.x1;
                y = pbox.y1 - SrcBox.y1;
                shift = x & 7;
                x >>= 3;
                leftover = w & 7;
                w >>= 3;

                /* clean up the edge */
                if (leftover) {
                    int mask = (1 << leftover) - 1;

                    for (int j = h, k = w; j--; k += ScratchPitch)
                        ScratchMem[k] &= mask;
                }

                for (int j = 0, index = (pitch * y) + x, index2 = 0; j < h;
                         j++, index += pitch, index2 += ScratchPitch) {
                    if (w) {
                        if (!shift) {
                            assert(ScratchMem);
                            memcpy(data + index, ScratchMem + index2, w);
                        }
                        else {
                            assert(ScratchMem);
                            CopyBits(data + index, shift,
                                     ScratchMem + index2, w);
                        }
                    }

                    if (leftover) {
                        data[index + w] |=
                            mixin(SHIFT_L!(`ScratchMem[index2 + w]`, `shift`));
                        if ((shift + leftover) > 8)
                            data[index + w + 1] |=
                                mixin(SHIFT_R!(`ScratchMem[index2 + w]`,
                                        `(8 - shift)`));
                    }
                }
            }
            else {
                int bpp = mixin(BitsPerPixel!("depth")) >> 3;
                x = (pbox.x1 - SrcBox.x1) * bpp;
                y = pbox.y1 - SrcBox.y1;
                w *= bpp;

                for (int j = 0; j < h; j++) {
                    assert(ScratchMem);
                    memcpy(data + (pitch * (y + j)) + x,
                           ScratchMem + (ScratchPitch * j), w);
                }
            }
            pbox++;
        }

        free(ScratchMem);
        RegionSubtract(SrcRegion, SrcRegion, GrabRegion);
        if (!RegionNotEmpty(SrcRegion))
            return FALSE;

    return TRUE;
}

void XineramaGetImageData(DrawablePtr* pDrawables, int left, int top, int width, int height, uint format, c_ulong planemask, char* data, int pitch, Bool isRoot)
{
    RegionRec SrcRegion = void, GrabRegion = void;
    BoxRec SrcBox = void;
    DrawablePtr pDraw = pDrawables[0];

    /* find box in logical screen space */
    SrcBox.x1 = cast(short)left;
    SrcBox.y1 = cast(short)top;
    if (!isRoot) {
        ScreenPtr masterScreen = dixGetMasterScreen();
        SrcBox.x1 += pDraw.x + masterScreen.x;
        SrcBox.y1 += pDraw.y + masterScreen.y;
    }
    SrcBox.x2 = cast(short)(SrcBox.x1 + width);
    SrcBox.y2 = cast(short)(SrcBox.y1 + height);

    RegionInit(&SrcRegion, &SrcBox, 1);
    RegionNull(&GrabRegion);

    int depth = (format == XYPixmap) ? 1 : pDraw.depth;

    mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
        if (!XineramaGetImageDataScr(
                SrcBox,
                &GrabRegion,
                &SrcRegion,
                width,
                height,
                format,
                planemask,
                data,
                depth,
                pitch,
                walkScreen,
                pDrawables[walkScreenIdx]))
            break;
    }));

    RegionUninit(&SrcRegion);
    RegionUninit(&GrabRegion);
}

// work around broken X11 proto headers
enum sz_xXineramaQueryScreensReply = sz_XineramaQueryScreensReply;
enum sz_xXineramaIsActiveReply = sz_XineramaIsActiveReply;
enum sz_xPanoramiXGetScreenSizeReply = sz_panoramiXGetScreenSizeReply;
enum sz_xPanoramiXGetScreenCountReply = sz_panoramiXGetScreenCountReply;
enum sz_xPanoramiXGetStateReply = sz_panoramiXGetStateReply;

mixin XTYPE_SIZE_ASSERT!(xPanoramiXQueryVersionReply);
mixin XTYPE_SIZE_ASSERT!(xPanoramiXGetStateReply);
mixin XTYPE_SIZE_ASSERT!(xPanoramiXGetScreenCountReply);
mixin XTYPE_SIZE_ASSERT!(xPanoramiXGetScreenSizeReply);
mixin XTYPE_SIZE_ASSERT!(xXineramaIsActiveReply);
mixin XTYPE_SIZE_ASSERT!(xTranslateCoordsReply);
mixin XTYPE_SIZE_ASSERT!(xXineramaQueryScreensReply);
mixin XTYPE_SIZE_ASSERT!(xGetGeometryReply);
mixin XTYPE_SIZE_ASSERT!(xGetImageReply);
