module px.h;
@nogc nothrow:
extern(C): __gshared:
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

/* THIS IS NOT AN X PROJECT TEAM SPECIFICATION */

 
public import build.dix_config;

public import x11.Xmd;
public import externs.X11.extensions.panoramiXproto;

public import dix.scrnintstr; /* for screenInfo */

public import dix.gc;
public import dix.dixstruct_priv;

/*
 *	PanoramiX definitions
 */

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