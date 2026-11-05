module Args;
@nogc nothrow:
extern(C): __gshared:
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

//import x11.X;
//import x11.Xdefs;
//import x11.Xproto;

import miext.extinit_priv;
import os.ddx_priv;

import dix.scrintstr;
import dix.input;
import common.misc;
import dix.scrnintstr;
import include.servermd;
import include.extinit;
import build.xlibre_server;

import xnest_xcb;


import Display;
import Args;

char* xnestDisplayName = null;
int xnestDefaultClass;
Bool xnestUserDefaultClass = FALSE;
int xnestDefaultDepth;
Bool xnestUserDefaultDepth = FALSE;
Bool xnestSoftwareScreenSaver = FALSE;
xRectangle xnestGeometry = { 0 };
int xnestUserGeometry = 0;
int xnestBorderWidth;
Bool xnestUserBorderWidth = FALSE;
char* xnestWindowName = null;
int xnestNumScreens = 0;
Bool xnestDoDirectColormaps = FALSE;
xcb_window_t xnestParentWindow = 0;

int ddxProcessArgument(int argc, char** argv, int i)
{
    /* disable some extensions we currently don't support yet */
static if(CONFIG_MITSHM){
    noMITShmExtension = TRUE;
} /* CONFIG_MITSHM */

    noCompositeExtension = TRUE;

static if(DPMSExtension) {
    noDPMSExtension = TRUE;
}

    if (!strcmp(argv[i], "-display")) {
        if (++i < argc) {
            xnestDisplayName = argv[i];
            return 2;
        }
        return 0;
    }
    if (!strcmp(argv[i], "-class")) {
        if (++i < argc) {
            if (!strcmp(argv[i], "StaticGray")) {
                xnestDefaultClass = StaticGray;
                xnestUserDefaultClass = TRUE;
                return 2;
            }
            else if (!strcmp(argv[i], "GrayScale")) {
                xnestDefaultClass = GrayScale;
                xnestUserDefaultClass = TRUE;
                return 2;
            }
            else if (!strcmp(argv[i], "StaticColor")) {
                xnestDefaultClass = StaticColor;
                xnestUserDefaultClass = TRUE;
                return 2;
            }
            else if (!strcmp(argv[i], "PseudoColor")) {
                xnestDefaultClass = PseudoColor;
                xnestUserDefaultClass = TRUE;
                return 2;
            }
            else if (!strcmp(argv[i], "TrueColor")) {
                xnestDefaultClass = TrueColor;
                xnestUserDefaultClass = TRUE;
                return 2;
            }
            else if (!strcmp(argv[i], "DirectColor")) {
                xnestDefaultClass = DirectColor;
                xnestUserDefaultClass = TRUE;
                return 2;
            }
        }
        return 0;
    }
    if (!strcmp(argv[i], "-cc")) {
        if (++i < argc && sscanf(argv[i], "%i", &xnestDefaultClass) == 1) {
            if (xnestDefaultClass >= 0 && xnestDefaultClass <= 5) {
                xnestUserDefaultClass = TRUE;
                /* lex the OS layer process it as well, so return 0 */
            }
        }
        return 0;
    }
    if (!strcmp(argv[i], "-depth")) {
        if (++i < argc && sscanf(argv[i], "%i", &xnestDefaultDepth) == 1) {
            if (xnestDefaultDepth > 0) {
                xnestUserDefaultDepth = TRUE;
                return 2;
            }
        }
        return 0;
    }
    if (!strcmp(argv[i], "-sss")) {
        xnestSoftwareScreenSaver = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-geometry")) {
        if (++i < argc) {
            if (xnest_parse_geometry(argv[i], &xnestGeometry))
                return 2;
        }
        return 0;
    }
    if (!strcmp(argv[i], "-bw")) {
        if (++i < argc && sscanf(argv[i], "%i", &xnestBorderWidth) == 1) {
            if (xnestBorderWidth >= 0) {
                xnestUserBorderWidth = TRUE;
                return 2;
            }
        }
        return 0;
    }
    if (!strcmp(argv[i], "-name")) {
        if (++i < argc) {
            xnestWindowName = argv[i];
            return 2;
        }
        return 0;
    }
    if (!strcmp(argv[i], "-scrns")) {
        if (++i < argc && sscanf(argv[i], "%i", &xnestNumScreens) == 1) {
            if (xnestNumScreens > 0) {
                if (xnestNumScreens > MAXSCREENS) {
                    ErrorF("Maximum number of screens is %d.\n", MAXSCREENS);
                    xnestNumScreens = MAXSCREENS;
                }
                return 2;
            }
        }
        return 0;
    }
    if (!strcmp(argv[i], "-install")) {
        xnestDoDirectColormaps = TRUE;
        return 1;
    }
    if (!strcmp(argv[i], "-parent")) {
        if (++i < argc) {
            xnestParentWindow = cast(XID) strtol(argv[i], cast(char**) null, 0);
            return 2;
        }
    }
    return 0;
}

void ddxUseMsg()
{
    ErrorF("-display string        display name of the real server\n");
    ErrorF("-class string          default visual class\n");
    ErrorF("-depth int             default depth\n");
    ErrorF("-sss                   use software screen saver\n");
    ErrorF("-geometry WxH+X+Y      window size and position\n");
    ErrorF("-bw int                window border width\n");
    ErrorF("-name string           window name\n");
    ErrorF("-scrns int             number of screens to generate\n");
    ErrorF("-install               install colormaps directly\n");
}
