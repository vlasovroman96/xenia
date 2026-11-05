module hw.xnest.Screen;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1993 by Davor Matic

Permission to use, copy, modify, distribute, and sell this software
and its documentation for any purpose is hereby granted without fee,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation.  Davor Matic makes no representations about
the suitability of this software for any purpose.  It is provided "as
is" without express or implied warranty.

*/
import build.xorg_config;

import externs.xcb.xcb;
import externs.xcb.xcb_aux;

//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import externs.xcb.xcb_icccm;

import mi.mi_priv;
import mi.mipointer_priv;

import include.scrnintstr;
import mi.micmap;
import dix.resource;

import xnest_xcb;


import Display;
import Screen;
import XNGC;
import hw.xnest.GCOps;
import Drawable;
import XNFont;
import Color;
import XNCursor;
import dix.events;
import Init;
import mi.mipointer;
import Args;

xcb_window_t[MAXSCREENS] xnestDefaultWindows;
xcb_window_t[MAXSCREENS] xnestScreenSaverWindows;
DevPrivateKeyRec xnestScreenCursorFuncKeyRec;
DevScreenPrivateKeyRec xnestScreenCursorPrivKeyRec;

ScreenPtr xnestScreen(xcb_window_t window)
{
    int i = void;

    for (i = 0; i < xnestNumScreens; i++)
        if (xnestDefaultWindows[i] == window)
            return screenInfo.screens[i];

    return null;
}

private int offset(c_ulong mask)
{
    int count = void;

    for (count = 0; !(mask & 1) && count < 32; count++)
        mask >>= 1;

    return count;
}

private Bool xnestSaveScreen(ScreenPtr pScreen, int what)
{
    if (xnestSoftwareScreenSaver)
        return FALSE;
    else {
        switch (what) {
        case SCREEN_SAVER_ON:
            xcb_map_window(xnestUpstreamInfo.conn, xnestScreenSaverWindows[pScreen.myNum]);
            uint value = XCB_STACK_MODE_ABOVE;
            xcb_configure_window(xnestUpstreamInfo.conn,
                                 xnestScreenSaverWindows[pScreen.myNum],
                                 XCB_CONFIG_WINDOW_STACK_MODE,
                                 &value);
            xnestSetScreenSaverColormapWindow(pScreen);
            break;

        case SCREEN_SAVER_OFF:
            xcb_unmap_window(xnestUpstreamInfo.conn, xnestScreenSaverWindows[pScreen.myNum]);
            xnestSetInstalledColormapWindows(pScreen);
            break;

        case SCREEN_SAVER_FORCER:
            lastEventTime = GetTimeInMillis();
            xcb_unmap_window(xnestUpstreamInfo.conn, xnestScreenSaverWindows[pScreen.myNum]);
            xnestSetInstalledColormapWindows(pScreen);
            break;

        case SCREEN_SAVER_CYCLE:
            xcb_unmap_window(xnestUpstreamInfo.conn, xnestScreenSaverWindows[pScreen.myNum]);
            xnestSetInstalledColormapWindows(pScreen);
            break;
        default: break;}
        return TRUE;
    }
}

private Bool xnestCursorOffScreen(ScreenPtr* ppScreen, int* x, int* y)
{
    return FALSE;
}

private void xnestCrossScreen(ScreenPtr pScreen, Bool entering)
{
}

miPointerScreenFuncRec xnestPointerScreenFuncs = {
    CursorOffScreen: &xnestCursorOffScreen,
    CrossScreen:     &xnestCrossScreen,
    // WarpCursor:      &xnestWarpCursor
};

private miPointerSpriteFuncRec xnestPointerSpriteFuncs = {
    &xnestRealizeCursor,
    &xnestUnrealizeCursor,
    &xnestSetCursor,
    &xnestMoveCursor,
    &xnestDeviceCursorInitialize,
    &xnestDeviceCursorCleanup
};

private DepthPtr add_depth(DepthPtr depths, int* numDepths, int nplanes)
{
    int num = *numDepths;

    for (int j = 0; j < num; j++)
        if (depths[j].depth == nplanes)
            return &depths[j];

    depths[num].depth = nplanes;
    if (((depths[num].vids = calloc(MAXVISUALSPERDEPTH, VisualID.sizeof)) == 0))
        FatalError("memory allocation failed");

    (*numDepths)++;
    return &depths[num];
}

private void add_depth_visual(DepthPtr depths, int* numDepths, int nplanes, VisualID vid)
{
    DepthPtr walk = add_depth(depths, numDepths, nplanes);
    walk.vids[walk.numVids] = vid;
    walk.numVids++;
}

Bool xnestOpenScreen(ScreenPtr pScreen, int argc, char** argv)
{
    c_ulong valuemask = void;
    VisualID defaultVisual = 0;
    int rootDepth = 0;
    miPointerScreenPtr PointPriv = void;

    if (!dixRegisterPrivateKey
        (&xnestWindowPrivateKeyRec, PRIVATE_WINDOW, xnestPrivWin.sizeof))
        return FALSE;
    if (!dixRegisterPrivateKey
        (&xnestGCPrivateKeyRec, PRIVATE_GC, xnestPrivGC.sizeof))
        return FALSE;
    if (!dixRegisterPrivateKey
        (&xnestPixmapPrivateKeyRec, PRIVATE_PIXMAP, xnestPrivPixmap.sizeof))
        return FALSE;
    if (!dixRegisterPrivateKey
        (&xnestColormapPrivateKeyRec, PRIVATE_COLORMAP,
         xnestPrivColormap.sizeof))
        return FALSE;
    if (!dixRegisterPrivateKey(&xnestScreenCursorFuncKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!dixRegisterScreenPrivateKey(&xnestScreenCursorPrivKeyRec, pScreen,
                                     PRIVATE_CURSOR, 0))
        return FALSE;

    int numVisuals = 0;
    VisualPtr visuals = cast(VisualRec*) calloc(1, VisualRec.sizeof);
    int numDepths = 0;
    DepthPtr depths = cast(DepthPtr) calloc(MAXDEPTH, DepthRec.sizeof);

    if (!visuals || !depths) {
        free(visuals);
        free(depths);
        return FALSE;
    }

    if (!xnestVisualMap)
        xnestVisualMap = cast(xnest_visual_t*) calloc(1, xnest_visual_t.sizeof);
    else
        xnestVisualMap = cast(xnest_visual_t*) reallocarray(xnestVisualMap, xnestNumVisualMap+1, xnest_visual_t.sizeof);

    add_depth(depths, &numDepths, 1);

    for (int i = 0; i<screenInfo.numPixmapFormats; i++)
        add_depth(depths, &numDepths, screenInfo.formats[i].depth);

    int found_default_visual = 0;
    xcb_depth_iterator_t depth_iter = void;
    for (depth_iter = xcb_screen_allowed_depths_iterator(xnestUpstreamInfo.screenInfo);
         depth_iter.rem;
         xcb_depth_next(&depth_iter))
    {
        int vlen = xcb_depth_visuals_length (depth_iter.data);
        xcb_visualtype_t* vts = xcb_depth_visuals (depth_iter.data);
        for (int x = 0; x<vlen; x++) {
            for (int j = 0; j < numVisuals; j++) {
                if (vts[x]._class == visuals[j].class_ &&
                    vts[x].bits_per_rgb_value == visuals[j].bitsPerRGBValue &&
                    vts[x].colormap_entries == visuals[j].ColormapEntries &&
                    depth_iter.data.depth == visuals[j].nplanes &&
                    vts[x].red_mask == visuals[j].redMask &&
                    vts[x].green_mask == visuals[j].greenMask &&
                    vts[x].blue_mask == visuals[j].blueMask &&
                    offset(vts[x].red_mask) == visuals[j].offsetRed &&
                    offset(vts[x].green_mask) == visuals[j].offsetGreen &&
                    offset(vts[x].blue_mask) == visuals[j].offsetBlue)
                        goto breakout;
            }

            visuals[numVisuals] = VisualRec (
                c_class = vts[x]._class,
                bitsPerRGBValue = vts[x].bits_per_rgb_value,
                ColormapEntries = vts[x].colormap_entries,
                nplanes = depth_iter.data.depth,
                redMask = vts[x].red_mask,
                greenMask = vts[x].green_mask,
                blueMask = vts[x].blue_mask,
                offsetRed = offset(vts[x].red_mask),
                offsetGreen = offset(vts[x].green_mask),
                offsetBlue = offset(vts[x].blue_mask),
                vid = dixAllocServerXID(),
            );

            xnestVisualMap[xnestNumVisualMap] = xnest_visual_t (
                ourXID = visuals[numVisuals].vid,
                ourVisual = &visuals[numVisuals],
                upstreamDepth = depth_iter.data,
                upstreamVisual = &vts[x],
                upstreamCMap = xcb_generate_id(xnestUpstreamInfo.conn),
            );

            xcb_create_colormap(xnestUpstreamInfo.conn,
                                XCB_COLORMAP_ALLOC_NONE,
                                xnestVisualMap[xnestNumVisualMap].upstreamCMap,
                                xnestUpstreamInfo.screenInfo.root,
                                xnestVisualMap[xnestNumVisualMap].upstreamVisual.visual_id);

            add_depth_visual(depths, &numDepths, visuals[numVisuals].nplanes, visuals[numVisuals].vid);

            if (xnestUserDefaultClass || xnestUserDefaultDepth) {
                if ((!xnestDefaultClass || visuals[numVisuals].class_ == xnestDefaultClass) &&
                    (!xnestDefaultDepth || visuals[numVisuals].nplanes == xnestDefaultDepth))
                {
                    defaultVisual = visuals[numVisuals].vid;
                    rootDepth = visuals[numVisuals].nplanes;
                    found_default_visual = 1;
                }
            }
            else
            {
                VisualID visual_id = xnestUpstreamInfo.screenInfo.root_visual;
                if (visual_id == vts[x].visual_id) {
                    defaultVisual = visuals[numVisuals].vid;
                    rootDepth = visuals[numVisuals].nplanes;
                    found_default_visual = 1;
                }
            }

            numVisuals++;
            xnestNumVisualMap++;
            visuals = cast(VisualRec*) reallocarray(visuals, numVisuals+1, VisualRec.sizeof);
            xnestVisualMap = cast(xnest_visual_t*) reallocarray(xnestVisualMap, xnestNumVisualMap+1, xnest_visual_t.sizeof);
        }
    }
breakout:
    visuals = cast(VisualRec*) reallocarray(visuals, numVisuals, VisualRec.sizeof);
    xnestVisualMap = cast(xnest_visual_t*) reallocarray(xnestVisualMap, xnestNumVisualMap, xnest_visual_t.sizeof);

    if (!found_default_visual) {
        ErrorF("Xnest: can't find matching visual for user specified depth %d\n", xnestDefaultDepth);
        defaultVisual = visuals[0].vid;
        rootDepth = visuals[0].nplanes;
    }

    if (xnestParentWindow != 0) {
        xRectangle r = xnest_get_geometry(xnestUpstreamInfo.conn, xnestParentWindow);
        xnestGeometry.width = r.width;
        xnestGeometry.height = r.height;
    }

    /* myNum */
    /* id */
    if (!miScreenInit(pScreen, null, xnestGeometry.width, xnestGeometry.height,
                      1, 1, xnestGeometry.width, rootDepth, numDepths, depths, defaultVisual, /* root visual */
                      numVisuals, visuals))
        return FALSE;

    pScreen.defColormap = cast(Colormap) dixAllocServerXID();
    pScreen.minInstalledCmaps = MINCMAPS;
    pScreen.maxInstalledCmaps = MAXCMAPS;
    pScreen.backingStoreSupport = XCB_BACKING_STORE_NOT_USEFUL;
    pScreen.saveUnderSupport = XCB_BACKING_STORE_NOT_USEFUL;
    pScreen.whitePixel = xnestUpstreamInfo.screenInfo.white_pixel;
    pScreen.blackPixel = xnestUpstreamInfo.screenInfo.black_pixel;
    /* GCperDepth */
    /* defaultStipple */
    /* WindowPrivateLen */
    /* WindowPrivateSizes */
    /* totalWindowSize */
    /* GCPrivateLen */
    /* GCPrivateSizes */
    /* totalGCSize */

    /* Random screen procedures */

    pScreen.QueryBestSize = xnestQueryBestSize;
    pScreen.SaveScreen = xnestSaveScreen;
    pScreen.GetImage = xnestGetImage;
    pScreen.GetSpans = xnestGetSpans;

    /* Window Procedures */

    pScreen.CreateWindow = xnestCreateWindow;
    pScreen.DestroyWindow = xnestDestroyWindow;
    pScreen.PositionWindow = xnestPositionWindow;
    pScreen.ChangeWindowAttributes = xnestChangeWindowAttributes;
    pScreen.RealizeWindow = xnestRealizeWindow;
    pScreen.UnrealizeWindow = xnestUnrealizeWindow;
    pScreen.PostValidateTree = null;
    pScreen.WindowExposures = miWindowExposures;
    pScreen.CopyWindow = xnestCopyWindow;
    pScreen.ClipNotify = xnestClipNotify;
    pScreen.ClearToBackground = xnest_screen_ClearToBackground;

    /* Pixmap procedures */

    pScreen.CreatePixmap = xnestCreatePixmap;
    pScreen.DestroyPixmap = xnestDestroyPixmap;
    pScreen.ModifyPixmapHeader = xnestModifyPixmapHeader;

    /* Font procedures */

    pScreen.RealizeFont = xnestRealizeFont;
    pScreen.UnrealizeFont = xnestUnrealizeFont;

    /* GC procedures */

    pScreen.CreateGC = xnestCreateGC;

    /* Colormap procedures */

    pScreen.CreateColormap = xnestCreateColormap;
    pScreen.DestroyColormap = xnestDestroyColormap;
    pScreen.InstallColormap = xnestInstallColormap;
    pScreen.UninstallColormap = xnestUninstallColormap;
    pScreen.ListInstalledColormaps = xnestListInstalledColormaps;
    pScreen.StoreColors = xnestStoreColors;
    pScreen.ResolveColor = xnestResolveColor;

    pScreen.BitmapToRegion = xnestPixmapToRegion;

    /* OS layer procedures */

    pScreen.BlockHandler = cast(ScreenBlockHandlerProcPtr) NoopDDA;
    pScreen.WakeupHandler = cast(ScreenWakeupHandlerProcPtr) NoopDDA;

    miDCInitialize(pScreen, &xnestPointerCursorFuncs);  /* init SW rendering */
    PointPriv = cast(_MiPointerScreenRec*)dixLookupPrivate(&pScreen.devPrivates, miPointerScreenKey);
    xnestCursorFuncs.spriteFuncs = PointPriv.spriteFuncs;
    dixSetPrivate(&pScreen.devPrivates, &xnestScreenCursorFuncKeyRec,
                  &xnestCursorFuncs);
    PointPriv.spriteFuncs = &xnestPointerSpriteFuncs;

    pScreen.mmWidth =
        xnestGeometry.width * xnestUpstreamInfo.screenInfo.width_in_millimeters /
        xnestUpstreamInfo.screenInfo.width_in_pixels;
    pScreen.mmHeight =
        xnestGeometry.height * xnestUpstreamInfo.screenInfo.height_in_millimeters /
        xnestUpstreamInfo.screenInfo.height_in_pixels;

    /* overwrite miCloseScreen with our own */
    pScreen.CloseScreen = xnestCloseScreen;

    /* overwrite miSetShape with our own */
    pScreen.SetShape = xnestSetShape;

    /* devPrivates */

enum POSITION_OFFSET = `(pScreen->myNum * (xnestGeometry.width + xnestGeometry.height) / 32);`;

    if (xnestDoFullGeneration) {

        xcb_params_cw_t attributes = {
            back_pixel: xnestUpstreamInfo.screenInfo.white_pixel,
            event_mask: xnestEventMask,
            colormap: xnest_visual_to_upstream_cmap(pScreen.rootVisual),
        };

        valuemask = XCB_CW_BACK_PIXEL | XCB_CW_EVENT_MASK | XCB_CW_COLORMAP;

        if (xnestParentWindow != 0) {
            xnestDefaultWindows[pScreen.myNum] = xnestParentWindow;
            xcb_change_window_attributes(xnestUpstreamInfo.conn,
                                         xnestDefaultWindows[pScreen.myNum],
                                         XCB_CW_EVENT_MASK,
                                         &xnestEventMask);
        }
        else {
            xnestDefaultWindows[pScreen.myNum] = xcb_generate_id(xnestUpstreamInfo.conn);
            xcb_aux_create_window(xnestUpstreamInfo.conn,
                                  pScreen.rootDepth,
                                  xnestDefaultWindows[pScreen.myNum],
                                  xnestUpstreamInfo.screenInfo.root,
                                  xnestGeometry.x + POSITION_OFFSET,
                                  xnestGeometry.y + POSITION_OFFSET,
                                  xnestGeometry.width,
                                  xnestGeometry.height,
                                  xnestBorderWidth,
                                  XCB_WINDOW_CLASS_INPUT_OUTPUT,
                                  xnest_visual_map_to_upstream(pScreen.rootVisual),
                                  valuemask,
                                  &attributes);
        }

        if (!xnestWindowName)
            xnestWindowName = argv[0];

        xcb_size_hints_t sizeHints = {
            flags: XCB_ICCCM_SIZE_HINT_P_POSITION | XCB_ICCCM_SIZE_HINT_P_SIZE | XCB_ICCCM_SIZE_HINT_P_MAX_SIZE,
            x: xnestGeometry.x + POSITION_OFFSET,
            y: xnestGeometry.y + POSITION_OFFSET,
            width: xnestGeometry.width,
            height: xnestGeometry.height,
            max_width: xnestGeometry.width,
            max_height: xnestGeometry.height,
        };

        if (xnestUserGeometry & XCB_CONFIG_WINDOW_X ||
            xnestUserGeometry & XCB_CONFIG_WINDOW_Y)
            sizeHints.flags |= XCB_ICCCM_SIZE_HINT_US_POSITION;
        if (xnestUserGeometry & XCB_CONFIG_WINDOW_WIDTH ||
            xnestUserGeometry & XCB_CONFIG_WINDOW_HEIGHT)
            sizeHints.flags |= XCB_ICCCM_SIZE_HINT_US_SIZE;

        const(size_t) windowNameLen = strlen(xnestWindowName);

        xcb_icccm_set_wm_name_checked(xnestUpstreamInfo.conn,
                                      xnestDefaultWindows[pScreen.myNum],
                                      XCB_ATOM_STRING,
                                      8,
                                      windowNameLen,
                                      xnestWindowName);

        xcb_icccm_set_wm_icon_name_checked(xnestUpstreamInfo.conn,
                                           xnestDefaultWindows[pScreen.myNum],
                                           XCB_ATOM_STRING,
                                           8,
                                           windowNameLen,
                                           xnestWindowName);

        xnest_set_command(xnestUpstreamInfo.conn,
                          xnestDefaultWindows[pScreen.myNum],
                          argv, argc);

        xcb_icccm_wm_hints_t wmhints = {
            icon_pixmap: xnestIconBitmap,
            flags: XCB_ICCCM_WM_HINT_ICON_PIXMAP,
        };

        xcb_icccm_set_wm_hints_checked(xnestUpstreamInfo.conn,
                                       xnestDefaultWindows[pScreen.myNum],
                                       &wmhints);

        xcb_map_window(xnestUpstreamInfo.conn, xnestDefaultWindows[pScreen.myNum]);

        valuemask = XCB_CW_BACK_PIXMAP | XCB_CW_COLORMAP;
        attributes.back_pixmap = xnestScreenSaverPixmap;
        attributes.colormap = xnestUpstreamInfo.screenInfo.default_colormap;

        xnestScreenSaverWindows[pScreen.myNum] = xcb_generate_id(xnestUpstreamInfo.conn);
        xcb_aux_create_window(xnestUpstreamInfo.conn,
                              xnestUpstreamInfo.screenInfo.root_depth,
                              xnestScreenSaverWindows[pScreen.myNum],
                              xnestDefaultWindows[pScreen.myNum],
                              0,
                              0,
                              xnestGeometry.width,
                              xnestGeometry.height,
                              0,
                              XCB_WINDOW_CLASS_INPUT_OUTPUT,
                              xnestUpstreamInfo.screenInfo.root_visual,
                              valuemask,
                              &attributes);
    }

    if (!xnestCreateDefaultColormap(pScreen))
        return FALSE;

    return TRUE;
}

Bool xnestCloseScreen(ScreenPtr pScreen)
{
    int i = void;

    for (i = 0; i < pScreen.numDepths; i++)
        free(pScreen.allowedDepths[i].vids);
    free(pScreen.allowedDepths);
    free(pScreen.visuals);
    miScreenClose(pScreen);

    /*
       If xnestDoFullGeneration all x resources will be destroyed upon closing
       the display connection.  There is no need to generate extra protocol.
     */

    return TRUE;
}
