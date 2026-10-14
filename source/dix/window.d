module dix.window;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright (c) 2006, Red Hat, Inc.

Permission is hereby granted, free of charge, to any person obtaining a
copy of this software and associated documentation files (the "Software"),
to deal in the Software without restriction, including without limitation
the rights to use, copy, modify, merge, publish, distribute, sublicense,
and/or sell copies of the Software, and to permit persons to whom the
Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice (including the next
paragraph) shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
DEALINGS IN THE SOFTWARE.

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts,

			All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

*/

/* The panoramix components contained the following notice */
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

import build.xlibre_server;
import region;

import dix.colormap_priv;
import dix.cursor_priv;
import dix.dispatch;
import dix.dix_priv;
import dix.exevents_priv;
import dix.input_priv;
import dix.inpututils_priv;
import dix.property_priv;
import dix.request_priv;
import dix.resource_priv;
import dix.screenint_priv;
import dix.screensaver_priv;
import dix.selection_priv;
import dix.screenint_priv;
import dix.window_priv;
import include.extinit;
import mi.mi_priv;         /* miPaintWindow */
import os.auth;
import os.client_priv;
import os.osdep;
import os.screensaver;
import Xext.panoramiX;
import Xext.panoramiXsrv;

import include.misc;
import include.scrnintstr;
import include.os;
import include.regionstr;
import include.validate;
import include.windowstr;
import include.propertyst;
import include.inputstr;
import include.resource;
import dix.cursor;
import include.dixstruct;
import include.gcstruct;
import include.servermd;
import include.globals;
import composite.compint;
import include.privates;
import Xext.xace;
import os.WaitFor;

import externs.X11.Xatom;          /* must come after server includes */
import os.log;
import os.access;
import dix.gc;
import externs.xorg.xace;
import dix.events;
import externs.attrs;
import dix.screen_hooks;
import os.io;
import x11.X;
import dix.inpututils;

/******
 * Window stuff for server
 *
 *    CreateRootWindow, dixCreateWindow, ChangeWindowAttributes,
 *    GetWindowAttributes, DeleteWindow, DestroySubWindows,
 *    HandleSaveSet, ReparentWindow, MapWindow, MapSubWindows,
 *    UnmapWindow, UnmapSubWindows, ConfigureWindow, CirculateWindow,
 *    ChangeWindowDeviceCursor
 ******/

Bool bgNoneRoot = FALSE;

private const(ubyte)[4] _back_lsb = [ 0x88, 0x22, 0x44, 0X11 ];
private const(ubyte)[4] _back_msb = [ 0X11, 0x44, 0x22, 0x88 ];




// int screenIsSaved = SCREEN_SAVER_OFF;



enum INPUTONLY_LEGAL_MASK = (CWWinGravity | CWEventMask | 
			      CWDontPropagate | CWOverrideRedirect | CWCursor );

enum string BOXES_OVERLAP(string b1, string b2) = `
      (!( ((` ~ b1 ~ `).x2 <= (` ~ b2 ~ `).x1)  || 
	( ((` ~ b1 ~ `).x1 >= (` ~ b2 ~ `).x2)) || 
	( ((` ~ b1 ~ `).y2 <= (` ~ b2 ~ `).y1)) || 
	( ((` ~ b1 ~ `).y1 >= (` ~ b2 ~ `).y2)) ) )`;

enum string RedirectSend(string pWin) = `
    ((` ~ pWin ~ `.eventMask| `~wOtherEventMasks!(pWin)~`) & SubstructureRedirectMask)`;

// enum string SubSend(string pWin) = `
//     ((` ~ pWin ~ `.eventMask|`~wOtherEventMasks!(pWin)~` & SubstructureNotifyMask))`;

import x11.X;
    enum string SubSend(string pWin) = `
    ((`~pWin~`.eventMask| `~wOtherEventMasks!(pWin)~`) & SubstructureNotifyMask)`;
pragma(msg, typeof(SubstructureRedirectMask).stringof);
pragma(msg, __traits(identifier, SubstructureRedirectMask));

pragma(msg, __traits(compiles, cast(Mask)SubstructureNotifyMask));
pragma(msg, __traits(compiles, cast(Mask)StructureNotifyMask));
pragma(msg, __traits(compiles, cast(Mask)SubstructureRedirectMask));


enum string StrSend(string pWin) = `
    ((` ~ pWin ~ `.eventMask|`~wOtherEventMasks!(pWin)~`) & StructureNotifyMask)`;

enum string SubStrSend(string pWin,string pParent) = `(` ~ StrSend!(pWin) ~ ` || ` ~ SubSend!(pParent) ~ `)`;

private const(char)* overlay_win_name = "<composite overlay>";

private const(char)* get_window_name(WindowPtr pWin)
{
enum WINDOW_NAME_BUF_LEN = 512;
    static char[WINDOW_NAME_BUF_LEN] buf = 0;
    int len = void;

    CompScreenPtr comp_screen = mixin(GetCompScreen!("pWin.drawable.pScreen"));

    if (comp_screen && pWin == comp_screen.pOverlayWin)
        return overlay_win_name;

    for (PropertyPtr prop = pWin.properties; prop; prop = prop.next) {
        if (prop.propertyName == XA_WM_NAME && prop.type == XA_STRING &&
            prop.data) {
            len = min(prop.size, WINDOW_NAME_BUF_LEN - 1);
            memcpy(buf.ptr, prop.data, len);
            buf[len] = '\0';
            return buf.ptr;
        }
    }

    return null;
}

private void log_window_info(WindowPtr pWin, int depth)
{
    const(char)* win_name = void, visibility = void;
    BoxPtr rects = void;

    for (int i = 0; i < (depth << 2); i++)
        ErrorF(" ");

    win_name = get_window_name(pWin);
    ErrorF("win 0x%.8x (%s), [%d, %d] to [%d, %d]",
           cast(uint) pWin.drawable.id,
           win_name ? win_name : "no name",
           pWin.drawable.x, pWin.drawable.y,
           pWin.drawable.x + pWin.drawable.width,
           pWin.drawable.y + pWin.drawable.height);

    if (pWin.overrideRedirect)
        ErrorF(" (override redirect)");
    if (pWin.redirectDraw)
        ErrorF(" (%s compositing: pixmap %x)",
               (pWin.redirectDraw == RedirectDrawAutomatic) ?
               "automatic".ptr : "manual".ptr,
               cast(uint) pWin.drawable.pScreen.GetWindowPixmap(pWin).drawable.id);

    switch (pWin.visibility) {
    case VisibilityUnobscured:
        visibility = "unobscured";
        break;
    case VisibilityPartiallyObscured:
        visibility = "partially obscured";
        break;
    case VisibilityFullyObscured:
        visibility = "fully obscured";
        break;
    case VisibilityNotViewable:
        visibility = "unviewable";
        break;
    default: break;}
    ErrorF(", %s", visibility);

    if (RegionNotEmpty(&pWin.clipList)) {
        ErrorF(", clip list:");
        rects = RegionRects(&pWin.clipList);
        for (int i = 0; i < RegionNumRects(&pWin.clipList); i++)
            ErrorF(" [(%d, %d) to (%d, %d)]",
                   rects[i].x1, rects[i].y1, rects[i].x2, rects[i].y2);
        ErrorF("; extents [(%d, %d) to (%d, %d)]",
               pWin.clipList.extents.x1, pWin.clipList.extents.y1,
               pWin.clipList.extents.x2, pWin.clipList.extents.y2);
    }

    ErrorF("\n");
}

private const(char)* grab_grabtype_to_text(GrabPtr pGrab)
{
    switch (pGrab.grabtype) {
        case XI2:
            return "xi2";
        case CORE:
            return "core";
        default:
            return "xi1";
    }
}

private const(char)* grab_type_to_text(GrabPtr pGrab)
{
    switch (pGrab.type) {
        case ButtonPress:
            return "ButtonPress";
        case KeyPress:
            return "KeyPress";
        case XI_Enter:
            return "XI_Enter";
        case XI_FocusIn:
            return "XI_FocusIn";
        default:
            return "unknown?!";
    }
}

private void log_grab_info(void* value, XID id, void* cdata)
{
    GrabPtr pGrab = cast(GrabPtr)value;

    ErrorF("  grab 0x%lx (%s), type '%s' on window 0x%lx\n",
           cast(c_ulong) pGrab.resource,
           grab_grabtype_to_text(pGrab),
           grab_type_to_text(pGrab),
           cast(c_ulong) pGrab.window.drawable.id);
    ErrorF("    detail %d (mask %lu), modifiersDetail %d (mask %lu)\n",
           pGrab.detail.exact,
           pGrab.detail.pMask ? cast(c_ulong) *(pGrab.detail.pMask) : 0,
           pGrab.modifiersDetail.exact,
           pGrab.modifiersDetail.pMask ?
           cast(c_ulong) *(pGrab.modifiersDetail.pMask) :
           cast(c_ulong) 0);
    ErrorF("    device '%s' (%d), modifierDevice '%s' (%d)\n",
           pGrab.device.name, pGrab.device.id,
           pGrab.modifierDevice.name, pGrab.modifierDevice.id);
    if (pGrab.grabtype == CORE) {
        ErrorF("    core event mask 0x%lx\n",
               cast(c_ulong) pGrab.eventMask);
    }
    else if (pGrab.grabtype == XI) {
        ErrorF("    xi1 event mask 0x%lx\n",
               cast(c_ulong) pGrab.eventMask);
    }
    else if (pGrab.grabtype == XI2) {
        for (int i = 0; i < xi2mask_num_masks(pGrab.xi2mask); i++) {
            const(ubyte)* mask = void;
            int print = void;

            print = 0;
            for (int j = 0; j < XI2MASKSIZE; j++) {
                mask = xi2mask_get_one_mask(pGrab.xi2mask, i);
                if (mask[j]) {
                    print = 1;
                    break;
                }
            }
            if (!print)
                continue;
            ErrorF("      xi2 event mask 0x");
            for (int j = 0; j < xi2mask_mask_size(pGrab.xi2mask); j++)
                ErrorF("%x ", mask[j]);
            ErrorF("\n");
        }
    }
    ErrorF("    owner-events %s, kb %d ptr %d, confine 0x%lx, cursor 0x%lx\n",
           pGrab.ownerEvents ? "true".ptr : "false".ptr,
           pGrab.keyboardMode, pGrab.pointerMode,
           pGrab.confineTo ? cast(c_ulong) pGrab.confineTo.drawable.id : 0,
           pGrab.cursor ? cast(c_ulong) pGrab.cursor.id : 0);
}

void PrintPassiveGrabs()
{
    LocalClientCredRec* lcc = void;
    pid_t clientpid = void;
    const(char)* cmdname = void;
    const(char)* cmdargs = void;

    ErrorF("Printing all currently registered grabs\n");

    for (int i = 1; i < currentMaxClients; i++) {
        if (!clients[i] || clients[i].clientState != ClientStateRunning)
            continue;

        clientpid = GetClientPid(clients[i]);
        cmdname = GetClientCmdName(clients[i]);
        cmdargs = GetClientCmdArgs(clients[i]);
        if ((clientpid > 0) && (cmdname !is null)) {
            ErrorF("  Printing all registered grabs of client pid %ld %s %s\n",
                   cast(c_long) clientpid, cmdname, cmdargs ? cmdargs : "");
        } else {
            if (GetLocalClientCreds(clients[i], &lcc) == -1) {
                ErrorF("  GetLocalClientCreds() failed\n");
                continue;
            }
            ErrorF("  Printing all registered grabs of client pid %ld uid %ld gid %ld\n",
                   (lcc.fieldsSet & LCC_PID_SET) ? cast(c_long) lcc.pid : 0,
                   (lcc.fieldsSet & LCC_UID_SET) ? cast(c_long) lcc.euid : 0,
                   (lcc.fieldsSet & LCC_GID_SET) ? cast(c_long) lcc.egid : 0);
            FreeLocalClientCreds(lcc);
        }

        FindClientResourcesByType(clients[i], X11_RESTYPE_PASSIVEGRAB, &log_grab_info, null);
    }
    ErrorF("End list of registered passive grabs\n");
}

void PrintWindowTree()
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        ErrorF("[dix] Dumping windows for screen %d (pixmap %x):\n", walkScreenIdx,
               cast(uint) walkScreen.GetScreenPixmap(walkScreen).drawable.id);
        WindowPtr pWin = walkScreen.root;
        int depth = 1;
        while (pWin) {
            log_window_info(pWin, depth);
            if (pWin.firstChild) {
                pWin = pWin.firstChild;
                depth++;
                continue;
            }
            while (pWin && !pWin.nextSib) {
                pWin = pWin.parent;
                depth--;
            }
            if (!pWin)
                break;
            pWin = pWin.nextSib;
        }
    });
}

int TraverseTree(WindowPtr pWin, VisitWindowProcPtr func, void* data)
{
    int result = void;
    WindowPtr pChild = void;

    if (((pChild = pWin) is null))
        return WT_NOMATCH;
    while (1) {
        result = (*func) (pChild, data);
        if (result == WT_STOPWALKING)
            return WT_STOPWALKING;
        if ((result == WT_WALKCHILDREN) && pChild.firstChild) {
            pChild = pChild.firstChild;
            continue;
        }
        while (!pChild.nextSib && (pChild != pWin))
            pChild = pChild.parent;
        if (pChild == pWin)
            break;
        pChild = pChild.nextSib;
    }
    return WT_NOMATCH;
}

/*****
 * WalkTree
 *   Walk the window tree, for SCREEN, performing FUNC(pWin, data) on
 *   each window.  If FUNC returns WT_WALKCHILDREN, traverse the children,
 *   if it returns WT_DONTWALKCHILDREN, don't.  If it returns WT_STOPWALKING,
 *   exit WalkTree.  Does depth-first traverse.
 *****/

int WalkTree(ScreenPtr pScreen, VisitWindowProcPtr func, void* data)
{
    return (TraverseTree(pScreen.root, func, data));
}

/* hack to force no backing store */
// Bool disableBackingStore = FALSE;
// Bool enableBackingStore = FALSE;

void SetWindowToDefaults(WindowPtr pWin)
{
    pWin.prevSib = NullWindow;
    pWin.firstChild = NullWindow;
    pWin.lastChild = NullWindow;

    pWin.valdata = null;
    pWin.optional = null;
    pWin.cursorIsNone = TRUE;

    pWin.backingStore = NotUseful;

    pWin.mapped = FALSE;       /* off */
    pWin.realized = FALSE;     /* off */
    pWin.viewable = FALSE;
    pWin.visibility = VisibilityNotViewable;
    pWin.overrideRedirect = FALSE;
    pWin.saveUnder = FALSE;

    pWin.bitGravity = ForgetGravity;
    pWin.winGravity = NorthWestGravity;

    pWin.eventMask = 0;
    pWin.deliverableEvents = 0;
    pWin.dontPropagate = 0;
    pWin.redirectDraw = RedirectDrawNone;
    pWin.forcedBG = FALSE;
    pWin.unhittable = FALSE;

    pWin.damagedDescendants = FALSE;
}

private void MakeRootTile(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    GCPtr pGC = void;
    ubyte[128] back = void;
    int len = mixin(BitmapBytePad!("c_long.sizeof"));
    ubyte* to = void;

    pWin.background.pixmap = (*pScreen.CreatePixmap) (pScreen, 4, 4,
                                                        pScreen.rootDepth, 0);

    pWin.backgroundState = BackgroundPixmap;
    pGC = GetScratchGC(pScreen.rootDepth, pScreen);
    if (!pWin.background.pixmap || !pGC)
        FatalError("could not create root tile");

    {
        ChangeGCVal[2] attributes = void;

        attributes[0].val = cast(uint)pScreen.whitePixel;
        attributes[1].val = cast(uint)pScreen.blackPixel;

        cast(void) ChangeGC(null, pGC, cast(uint)(GCForeground | GCBackground),
                        attributes.ptr);
    }

    ValidateGC(cast(DrawablePtr) pWin.background.pixmap, pGC);

    const(ubyte)* from = (screenInfo.bitmapBitOrder == LSBFirst) ? _back_lsb.ptr : _back_msb.ptr;
    to = back.ptr;

    for (int i = 4; i > 0; i--, from++)
        for (int j = len; j > 0; j--)
            *to++ = *from;

    (*pGC.ops.PutImage) (cast(DrawablePtr) pWin.background.pixmap, pGC, 1,
                           0, 0, len, 4, 0, XYBitmap, cast(char*) back);

    FreeScratchGC(pGC);

}

/*****
 * CreateRootWindow
 *    Makes a window at initialization time for specified screen
 *****/

Bool CreateRootWindow(ScreenPtr pScreen)
{
    WindowPtr pWin = void;
    BoxRec box = void;
    PixmapFormatRec* format = void;

    pWin = cast(_Window*)mixin(dixAllocateScreenObjectWithPrivates!("pScreen", "WindowRec", "PRIVATE_WINDOW"));
    if (!pWin)
        return FALSE;

    pScreen.screensaver.pWindow = null;
    pScreen.screensaver.wid = dixAllocServerXID();
    pScreen.screensaver.ExternalScreenSaver = null;
    screenIsSaved = SCREEN_SAVER_OFF;

    pScreen.root = pWin;

    pWin.drawable.pScreen = pScreen;
    pWin.drawable.type = DRAWABLE_WINDOW;

    pWin.drawable.depth = pScreen.rootDepth;
    for (format = cast(PixmapFormatRec*)screenInfo.formats.ptr;
         format.depth != pScreen.rootDepth; format++){}
    pWin.drawable.bitsPerPixel = format.bitsPerPixel;

    pWin.drawable.serialNumber = NEXT_SERIAL_NUMBER;

    pWin.parent = NullWindow;
    SetWindowToDefaults(pWin);

    pWin.optional = cast(WindowOptRec*) calloc(1, WindowOptRec.sizeof);
    if (!pWin.optional)
        return FALSE;

    pWin.optional.dontPropagateMask = 0;
    pWin.optional.otherEventMasks = 0;
    pWin.optional.otherClients = null;
    pWin.optional.passiveGrabs = null;
    pWin.optional.backingBitPlanes = cast(uint)~0L;
    pWin.optional.backingPixel = 0;
    pWin.optional.boundingShape = null;
    pWin.optional.clipShape = null;
    pWin.optional.inputShape = null;
    pWin.optional.inputMasks = null;
    pWin.optional.deviceCursors = null;
    pWin.optional.colormap = cast(uint)pScreen.defColormap;
    pWin.optional.visual = cast(uint)cast(uint)pScreen.rootVisual;

    pWin.nextSib = NullWindow;

    pWin.drawable.id = dixAllocServerXID();

    pWin.origin.x = pWin.origin.y = 0;
    pWin.drawable.height = pScreen.height;
    pWin.drawable.width = pScreen.width;
    pWin.drawable.x = pWin.drawable.y = 0;

    box.x1 = 0;
    box.y1 = 0;
    box.x2 = pScreen.width;
    box.y2 = pScreen.height;
    RegionInit(&pWin.clipList, &box, 1);
    RegionInit(&pWin.winSize, &box, 1);
    RegionInit(&pWin.borderSize, &box, 1);
    RegionInit(&pWin.borderClip, &box, 1);

    pWin.drawable.class_ = InputOutput;
    pWin.optional.visual = cast(uint)pScreen.rootVisual;

    pWin.backgroundState = BackgroundPixel;
    pWin.background.pixel = pScreen.whitePixel;

    pWin.borderIsPixel = TRUE;
    pWin.border.pixel = pScreen.blackPixel;
    pWin.borderWidth = 0;

    /*  security creation/labeling check
     */
    if (XaceHookResourceAccess(serverClient, pWin.drawable.id,
                 X11_RESTYPE_WINDOW, pWin, X11_RESTYPE_NONE, null, DixCreateAccess))
        return FALSE;

    if (!AddResource(cast(uint)pWin.drawable.id, X11_RESTYPE_WINDOW, cast(void*) pWin))
        return FALSE;

    if (disableBackingStore)
        pScreen.backingStoreSupport = NotUseful;
    if (enableBackingStore)
        pScreen.backingStoreSupport = WhenMapped;
    if (noCompositeExtension)
        pScreen.backingStoreSupport = NotUseful;

    pScreen.saveUnderSupport = NotUseful;

    return TRUE;
}

void InitRootWindow(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    int backFlag = cast(int)(CWBorderPixel | CWCursor | CWBackingStore);

    if (!(*pScreen.CreateWindow) (pWin))
        return;                 /* XXX */

    dixScreenRaiseWindowPosition(pWin, 0, 0);

    pWin.cursorIsNone = FALSE;
    pWin.optional.cursor = RefCursor(rootCursor);

    if (party_like_its_1989) {
        MakeRootTile(pWin);
        backFlag |= CWBackPixmap;
    }
    else if (pScreen.canDoBGNoneRoot && bgNoneRoot) {
        pWin.backgroundState = XaceBackgroundNoneState(pWin);
        pWin.background.pixel = pScreen.whitePixel;
        backFlag |= CWBackPixmap;
    }
    else {
        pWin.backgroundState = BackgroundPixel;
        if (whiteRoot)
            pWin.background.pixel = pScreen.whitePixel;
        else
            pWin.background.pixel = pScreen.blackPixel;
        backFlag |= CWBackPixel;
    }

    pWin.backingStore = NotUseful;
    /* We SHOULD check for an error value here XXX */
    (*pScreen.ChangeWindowAttributes) (pWin, backFlag);

    MapWindow(pWin, serverClient);
}

/* Set the region to the intersection of the rectangle and the
 * window's winSize.  The window is typically the parent of the
 * window from which the region came.
 */

private void ClippedRegionFromBox(WindowPtr pWin, RegionPtr Rgn, int x, int y, int w, int h)
{
    BoxRec box = *RegionExtents(&pWin.winSize);

    /* we do these calculations to avoid overflows */
    if (x > box.x1)
        box.x1 = cast(short)x;
    if (y > box.y1)
        box.y1 = cast(short)y;
    x += w;
    if (x < box.x2)
        box.x2 = cast(short)x;
    y += h;
    if (y < box.y2)
        box.y2 = cast(short)y;
    if (box.x1 > box.x2)
        box.x2 = cast(short)box.x1;
    if (box.y1 > box.y2)
        box.y2 = cast(short)box.y1;
    RegionReset(Rgn, &box);
    RegionIntersect(Rgn, Rgn, &pWin.winSize);
}

private RealChildHeadProc realChildHeadProc = null;

void RegisterRealChildHeadProc(RealChildHeadProc proc)
{
    realChildHeadProc = proc;
}

WindowPtr RealChildHead(WindowPtr pWin)
{
    if (realChildHeadProc) {
        return realChildHeadProc(pWin);
    }

    if (!pWin.parent &&
        (screenIsSaved == SCREEN_SAVER_ON) &&
        (HasSaverWindow(pWin.drawable.pScreen)))
        return pWin.firstChild;
    else
        return NullWindow;
}

@nogc nothrow
WindowPtr dixCreateWindow(Window wid, WindowPtr pParent, int x, int y, uint w, uint h, uint bw, uint class_, Mask vmask, XID* vlist, int depth, ClientPtr client, VisualID visual, int* error)
{
    WindowPtr pWin = void;
    WindowPtr pHead = void;
    ScreenPtr pScreen = void;
    Bool fOK = void;
    DepthPtr pDepth = void;
    PixmapFormatRec* format = void;
    WindowOptPtr ancwopt = void;

    if (class_ == CopyFromParent)
        class_ = pParent.drawable.class_;

    if ((class_ != InputOutput) && (class_ != InputOnly)) {
        *error = BadValue;
        client.errorValue = cast(uint)class_;
        return NullWindow;
    }

    if ((class_ != InputOnly) && (pParent.drawable.class_ == InputOnly)) {
        *error = BadMatch;
        return NullWindow;
    }

    if ((class_ == InputOnly) && ((bw != 0) || (depth != 0))) {
        *error = BadMatch;
        return NullWindow;
    }

    pScreen = pParent.drawable.pScreen;
    if ((class_ == InputOutput) && (depth == 0))
        depth = pParent.drawable.depth;
    ancwopt = pParent.optional;
    if (!ancwopt)
        ancwopt = FindWindowWithOptional(pParent).optional;
    if (visual == CopyFromParent) {
        visual = ancwopt.visual;
    }

    // /* Find out if the depth and visual are acceptable for this Screen */
    if ((visual != ancwopt.visual) || (depth != pParent.drawable.depth)) {
        fOK = FALSE;
        for (int idepth = 0; idepth < pScreen.numDepths; idepth++) {
            pDepth = cast(DepthPtr) &pScreen.allowedDepths[idepth];
            if ((depth == pDepth.depth) || (depth == 0)) {
                for (int ivisual = 0; ivisual < pDepth.numVids; ivisual++) {
                    if (visual == pDepth.vids[ivisual]) {
                        fOK = TRUE;
                        break;
                    }
                }
            }
        }
        if (fOK == FALSE) {
            *error = BadMatch;
            return NullWindow;
        }
    }

    if (((vmask & CWColormap) == 0) &&
        (class_ != InputOnly) &&
        ((visual != ancwopt.visual) || (ancwopt.colormap == None))) {
        *error = BadMatch;
        return NullWindow;
    }

    pWin = cast(_Window*)mixin(dixAllocateScreenObjectWithPrivates!("pScreen", "WindowRec", "PRIVATE_WINDOW"));
    if (!pWin) {
        *error = BadAlloc;
        return NullWindow;
    }
    pWin.drawable = pParent.drawable;
    pWin.drawable.depth = cast(ubyte)depth;
    if (depth == pParent.drawable.depth)
        pWin.drawable.bitsPerPixel = pParent.drawable.bitsPerPixel;
    else {
        for (format = cast(PixmapFormatRec*)screenInfo.formats.ptr; format.depth != depth; format++){}
        pWin.drawable.bitsPerPixel = format.bitsPerPixel;
    }
    if (class_ == InputOnly)
        pWin.drawable.type = cast(short) UNDRAWABLE_WINDOW;
    pWin.drawable.serialNumber = NEXT_SERIAL_NUMBER;

    pWin.drawable.id = wid;
    pWin.drawable.class_ = cast(ubyte)class_;

    pWin.parent = pParent;
    SetWindowToDefaults(pWin);

    if (visual != ancwopt.visual) {
        if (!MakeWindowOptional(pWin)) {
            mixin(dixFreeObjectWithPrivatesM!("pWin", "PRIVATE_WINDOW"));
            *error = BadAlloc;
            return NullWindow;
        }
        pWin.optional.visual = cast(uint)visual;
        pWin.optional.colormap = None;
    }

    pWin.borderWidth = cast(ushort)bw;

    /*  security creation/labeling check
     */
    *error = assumeNoGC(&XaceHookResourceAccess)(client, wid, X11_RESTYPE_WINDOW, pWin,
                      X11_RESTYPE_WINDOW, pWin.parent,
                      DixCreateAccess | DixSetAttrAccess);
    if (*error != Success) {
        mixin(dixFreeObjectWithPrivatesM!("pWin", "PRIVATE_WINDOW"));
        return NullWindow;
    }

    pWin.backgroundState = XaceBackgroundNoneState!()("pWin");
    pWin.background.pixel = pScreen.whitePixel;

    pWin.borderIsPixel = pParent.borderIsPixel;
    pWin.border = pParent.border;
    if (pWin.borderIsPixel == FALSE)
        pWin.border.pixmap.refcnt++;

    pWin.origin.x = cast(short)(x + cast(int) bw);
    pWin.origin.y = cast(short)(y + cast(int) bw);
    pWin.drawable.width = cast(ushort)w;
    pWin.drawable.height = cast(ushort)h;
    pWin.drawable.x = cast(short)(pParent.drawable.x + x + cast(int) bw);
    pWin.drawable.y = cast(short)(pParent.drawable.y + y + cast(int) bw);

    // /* set up clip list correctly for unobscured WindowPtr */
    RegionNull(&pWin.clipList);
    RegionNull(&pWin.borderClip);
    RegionNull(&pWin.winSize);
    RegionNull(&pWin.borderSize);

    pHead = RealChildHead(pParent);
    if (pHead) {
        pWin.nextSib = pHead.nextSib;
        if (pHead.nextSib)
            pHead.nextSib.prevSib = pWin;
        else
            pParent.lastChild = pWin;
        pHead.nextSib = pWin;
        pWin.prevSib = pHead;
    }
    else {
        pWin.nextSib = pParent.firstChild;
        if (pParent.firstChild)
            pParent.firstChild.prevSib = pWin;
        else
            pParent.lastChild = pWin;
        pParent.firstChild = pWin;
    }

    SetWinSize(pWin);
    SetBorderSize(pWin);

    /* We SHOULD check for an error value here XXX */
    if (!(*pScreen.CreateWindow) (pWin)) {
        *error = BadAlloc;
        DeleteWindow(pWin, None);
        return NullWindow;
    }
    /* We SHOULD check for an error value here XXX */
    dixScreenRaiseWindowPosition(pWin, pWin.drawable.x, pWin.drawable.y);

    if (!(vmask & CWEventMask))
        RecalculateDeliverableEvents(pWin);

    if (vmask)
        *error = ChangeWindowAttributes(pWin, vmask, vlist, dixClientForWindow(pWin));
    else
        *error = Success;

    if (*error != Success) {
        DeleteWindow(pWin, None);
        return NullWindow;
    }

    bool m = cast(bool)mixin(SubSend!(`pParent`)); 
    // pragma(msg, SubSend!("pParent"));
    // bool m;

    if (m) {
        xEvent event;
            event.u.createNotify.window= cast(uint)wid,
            event.u.createNotify.parent= cast(uint)pParent.drawable.id,
            event.u.createNotify.x= cast(short)x,
            event.u.createNotify.y= cast(short)y,
            event.u.createNotify.width= cast(ushort)w,
            event.u.createNotify.height= cast(ushort)h,
            event.u.createNotify.borderWidth= cast(ushort)bw,
            event.u.createNotify.override_ = cast(ubyte)pWin.overrideRedirect;

        event.u.u.type = CreateNotify;
        DeliverEvents(pParent, &event, 1, NullWindow);
    }
    return pWin;
}

private void DisposeWindowOptional(WindowPtr pWin)
{
    if (!pWin.optional)
        return;
    /*
     * everything is peachy.  Delete the optional record
     * and clean up
     */
    if (pWin.optional.cursor) {
        FreeCursor(pWin.optional.cursor, cast(Cursor) 0);
        pWin.cursorIsNone = FALSE;
    }
    else
        pWin.cursorIsNone = TRUE;

    if (pWin.optional.deviceCursors) {
        DevCursorList pList = void;
        DevCursorList pPrev = void;

        pList = pWin.optional.deviceCursors;
        while (pList) {
            FreeCursor(pList.cursor, cast(XID) 0);
            pPrev = pList;
            pList = pList.next;
            free(pPrev);
        }
        pWin.optional.deviceCursors = null;
    }

    free(pWin.optional);
    pWin.optional = null;
}

private void FreeWindowResources(WindowPtr pWin)
{
    DeleteWindowFromAnySaveSet(pWin);
    DeleteWindowFromAnySelections(pWin);
    DeleteWindowFromAnyEvents(pWin, TRUE);
    RegionUninit(&pWin.clipList);
    RegionUninit(&pWin.winSize);
    RegionUninit(&pWin.borderClip);
    RegionUninit(&pWin.borderSize);
    if (mixin(wBoundingShape!("pWin")))
        RegionDestroy(mixin(wBoundingShape!("pWin")));
    if (mixin(wClipShape!("pWin")))
        RegionDestroy(mixin(wClipShape!("pWin")));
    if (mixin(wInputShape!("pWin")))
        RegionDestroy(mixin(wInputShape!("pWin")));
    if (pWin.borderIsPixel == FALSE)
        dixDestroyPixmap(pWin.border.pixmap, 0);
    if (pWin.backgroundState == BackgroundPixmap)
        dixDestroyPixmap(pWin.background.pixmap, 0);

    DeleteAllWindowProperties(pWin);

    /* We SHOULD check for an error value here XXX */
    dixScreenRaiseWindowDestroy(pWin);
    DisposeWindowOptional(pWin);
}

private void CrushTree(WindowPtr pWin)
{
    WindowPtr pChild = void, pSib = void;

    if (((pChild = pWin.firstChild) is null))
        return;
    while (1) {

        /* go to a leaf node in the window tree */
        while (pChild.firstChild)
            pChild = pChild.firstChild;

        while (1) {
            WindowPtr pParent = pChild.parent;
            if (mixin(SubStrSend!(`pChild`, `pParent`))) {
                xEvent event;
                event.u.u.type = DestroyNotify ;
                event.u.destroyNotify.window = cast(uint)pChild.drawable.id;
                DeliverEvents(pChild, &event, 1, NullWindow);
            }
            FreeResource(cast(uint)pChild.drawable.id, X11_RESTYPE_WINDOW);
            pSib = pChild.nextSib;
            pChild.viewable = FALSE;
            if (pChild.realized) {
                dixScreenRaiseUnrealizeWindow(pChild);
            }
            FreeWindowResources(pChild);
            mixin(dixFreeObjectWithPrivatesM!("pChild", "PRIVATE_WINDOW"));
            if ((pChild = pSib) !is null)
                break;
            pChild = pParent;
            pChild.firstChild = NullWindow;
            pChild.lastChild = NullWindow;
            if (pChild == pWin)
                return;
        }
    }
}

/*****
 *  DeleteWindow
 *	 Deletes child of window then window itself
 *	 If wid is None, don't send any events
 *****/

int DeleteWindow(void* value, XID wid)
{
    WindowPtr pParent = void;
    WindowPtr pWin = cast(WindowPtr) value;

    UnmapWindow(pWin, FALSE);

    CrushTree(pWin);

    pParent = pWin.parent;
    if (wid && pParent && mixin(SubStrSend!(`pWin`, `pParent`))) {
        xEvent event;
        event.u.u.type = DestroyNotify ;
        event.u.destroyNotify.window = cast(uint)pWin.drawable.id;
        DeliverEvents(pWin, &event, 1, NullWindow);
    }

    FreeWindowResources(pWin);
    if (pParent) {
        if (pParent.firstChild == pWin)
            pParent.firstChild = pWin.nextSib;
        if (pParent.lastChild == pWin)
            pParent.lastChild = pWin.prevSib;
        if (pWin.nextSib)
            pWin.nextSib.prevSib = pWin.prevSib;
        if (pWin.prevSib)
            pWin.prevSib.nextSib = pWin.nextSib;
    }
    else
        pWin.drawable.pScreen.root = null;
    mixin(dixFreeObjectWithPrivatesM!("pWin", "PRIVATE_WINDOW"));
    return Success;
}

int DestroySubwindows(WindowPtr pWin, ClientPtr client)
{
    /* XXX
     * The protocol is quite clear that each window should be
     * destroyed in turn, however, unmapping all of the first
     * eliminates most of the calls to ValidateTree.  So,
     * this implementation is incorrect in that all of the
     * UnmapNotifies occur before all of the DestroyNotifies.
     * If you care, simply delete the call to UnmapSubwindows.
     */
    UnmapSubwindows(pWin);
    while (pWin.lastChild) {
        int rc = XaceHookResourceAccess(client,
                          pWin.lastChild.drawable.id, X11_RESTYPE_WINDOW,
                          pWin.lastChild, X11_RESTYPE_NONE, null, DixDestroyAccess);

        if (rc != Success)
            return rc;
        FreeResource(cast(uint)pWin.lastChild.drawable.id, X11_RESTYPE_NONE);
    }
    return Success;
}

private void SetRootWindowBackground(WindowPtr pWin, ScreenPtr pScreen, Mask* index2)
{
    /* following the protocol: "Changing the background of a root window to
     * None or ParentRelative restores the default background pixmap" */
    if (bgNoneRoot) {
        pWin.backgroundState = XaceBackgroundNoneState(pWin);
        pWin.background.pixel = pScreen.whitePixel;
    }
    else if (party_like_its_1989)
        MakeRootTile(pWin);
    else {
        pWin.backgroundState = BackgroundPixel;
        if (whiteRoot)
            pWin.background.pixel = pScreen.whitePixel;
        else
            pWin.background.pixel = pScreen.blackPixel;
        *index2 = CWBackPixel;
    }
}

/*****
 *  ChangeWindowAttributes
 *
 *  The value-mask specifies which attributes are to be changed; the
 *  value-list contains one value for each one bit in the mask, from least
 *  to most significant bit in the mask.
 *****/

int ChangeWindowAttributes(WindowPtr pWin, Mask vmask, XID* vlist, ClientPtr client)
{
    XID* pVlist = void;
    PixmapPtr pPixmap = void;
    Pixmap pixID = void;
    CursorPtr pCursor = void, pOldCursor = void;
    Cursor cursorID = void;
    Colormap cmap = void;
    ColormapPtr pCmap = void;
    xEvent xE = void;
    int error = void, rc = void;
    ScreenPtr pScreen = void;
    Mask index2 = void, tmask = void, vmaskCopy = 0;
    uint val = void;
    Bool checkOptional = FALSE, borderRelative = FALSE;

    if ((pWin.drawable.class_ == InputOnly) &&
        (vmask & (~INPUTONLY_LEGAL_MASK)))
        return BadMatch;

    error = Success;
    pScreen = pWin.drawable.pScreen;
    pVlist = vlist;
    tmask = vmask;
    while (tmask) {
        index2 = cast(Mask) mixin(lowbit!tmask);
        tmask &= ~index2;
        switch (index2) {
        case CWBackPixmap:
            pixID = cast(Pixmap) * pVlist;
            pVlist++;
            if (pWin.backgroundState == ParentRelative)
                borderRelative = TRUE;
            if (pixID == None) {
                if (pWin.backgroundState == BackgroundPixmap)
                    dixDestroyPixmap(pWin.background.pixmap, 0);
                if (!pWin.parent)
                    SetRootWindowBackground(pWin, pScreen, &index2);
                else {
                    pWin.backgroundState = XaceBackgroundNoneState(pWin);
                    pWin.background.pixel = pScreen.whitePixel;
                }
            }
            else if (pixID == ParentRelative) {
                if (pWin.parent &&
                    pWin.drawable.depth != pWin.parent.drawable.depth) {
                    error = BadMatch;
                    goto PatchUp;
                }
                if (pWin.backgroundState == BackgroundPixmap)
                    dixDestroyPixmap(pWin.background.pixmap, 0);
                if (!pWin.parent)
                    SetRootWindowBackground(pWin, pScreen, &index2);
                else
                    pWin.backgroundState = ParentRelative;
                borderRelative = TRUE;
                /* Note that the parent's backgroundTile's refcnt is NOT
                 * incremented. */
            }
            else {
                rc = dixLookupResourceByType(cast(void**) &pPixmap, pixID,
                                             X11_RESTYPE_PIXMAP, client, DixReadAccess);
                if (rc == Success) {
                    if ((pPixmap.drawable.depth != pWin.drawable.depth) ||
                        (pPixmap.drawable.pScreen != pScreen)) {
                        error = BadMatch;
                        goto PatchUp;
                    }
                    if (pWin.backgroundState == BackgroundPixmap)
                        dixDestroyPixmap(pWin.background.pixmap, 0);
                    pWin.backgroundState = BackgroundPixmap;
                    pWin.background.pixmap = pPixmap;
                    pPixmap.refcnt++;
                }
                else {
                    error = rc;
                    client.errorValue = cast(uint)pixID;
                    goto PatchUp;
                }
            }
            break;
        case CWBackPixel:
            if (pWin.backgroundState == ParentRelative)
                borderRelative = TRUE;
            if (pWin.backgroundState == BackgroundPixmap)
                dixDestroyPixmap(pWin.background.pixmap, 0);
            pWin.backgroundState = BackgroundPixel;
            pWin.background.pixel = cast(CARD32) *pVlist;
            /* background pixel overrides background pixmap,
               so don't let the ddx layer see both bits */
            vmaskCopy &= ~CWBackPixmap;
            pVlist++;
            break;
        case CWBorderPixmap:
            pixID = cast(Pixmap) * pVlist;
            pVlist++;
            if (pixID == CopyFromParent) {
                if (!pWin.parent ||
                    (pWin.drawable.depth != pWin.parent.drawable.depth)) {
                    error = BadMatch;
                    goto PatchUp;
                }
                if (pWin.parent.borderIsPixel == TRUE) {
                    if (pWin.borderIsPixel == FALSE)
                        dixDestroyPixmap(pWin.border.pixmap, 0);
                    pWin.border = pWin.parent.border;
                    pWin.borderIsPixel = TRUE;
                    index2 = CWBorderPixel;
                    break;
                }
                else {
                    pixID = pWin.parent.border.pixmap.drawable.id;
                }
            }
            rc = dixLookupResourceByType(cast(void**) &pPixmap, pixID, X11_RESTYPE_PIXMAP,
                                         client, DixReadAccess);
            if (rc == Success) {
                if ((pPixmap.drawable.depth != pWin.drawable.depth) ||
                    (pPixmap.drawable.pScreen != pScreen)) {
                    error = BadMatch;
                    goto PatchUp;
                }
                if (pWin.borderIsPixel == FALSE)
                    dixDestroyPixmap(pWin.border.pixmap, 0);
                pWin.borderIsPixel = FALSE;
                pWin.border.pixmap = pPixmap;
                pPixmap.refcnt++;
            }
            else {
                error = rc;
                client.errorValue = cast(uint)pixID;
                goto PatchUp;
            }
            break;
        case CWBorderPixel:
            if (pWin.borderIsPixel == FALSE)
                dixDestroyPixmap(pWin.border.pixmap, 0);
            pWin.borderIsPixel = TRUE;
            pWin.border.pixel = cast(CARD32) *pVlist;
            /* border pixel overrides border pixmap,
               so don't let the ddx layer see both bits */
            vmaskCopy &= ~CWBorderPixmap;
            pVlist++;
            break;
        case CWBitGravity:
            val = cast(CARD8) *pVlist;
            pVlist++;
            if (val > StaticGravity) {
                error = BadValue;
                client.errorValue = cast(uint)val;
                goto PatchUp;
            }
            pWin.bitGravity = val;
            break;
        case CWWinGravity:
            val = cast(CARD8) *pVlist;
            pVlist++;
            if (val > StaticGravity) {
                error = BadValue;
                client.errorValue = cast(uint)val;
                goto PatchUp;
            }
            pWin.winGravity = val;
            break;
        case CWBackingStore:
            val = cast(CARD8) *pVlist;
            pVlist++;
            if ((val != NotUseful) && (val != WhenMapped) && (val != Always)) {
                error = BadValue;
                client.errorValue = cast(uint)val;
                goto PatchUp;
            }
            /* if we're not actually changing the window's state, hide
             * CWBackingStore from vmaskCopy so it doesn't get passed to
             * ->ChangeWindowAttributes below
             */
            if (pWin.backingStore == val)
                continue;
            pWin.backingStore = val;
            break;
        case CWBackingPlanes:
            if (pWin.optional || (cast(CARD32) *pVlist != cast(CARD32) ~0L)) {
                if (!MakeWindowOptional(pWin)) {
                    error = BadAlloc;
                    goto PatchUp;
                }
                pWin.optional.backingBitPlanes = cast(CARD32) *pVlist;
                if (cast(CARD32) *pVlist == cast(CARD32) ~0L)
                    checkOptional = TRUE;
            }
            pVlist++;
            break;
        case CWBackingPixel:
            if (pWin.optional || cast(CARD32) *pVlist) {
                if (!MakeWindowOptional(pWin)) {
                    error = BadAlloc;
                    goto PatchUp;
                }
                pWin.optional.backingPixel = cast(CARD32) *pVlist;
                if (!*pVlist)
                    checkOptional = TRUE;
            }
            pVlist++;
            break;
        case CWSaveUnder:
            val = cast(BOOL) *pVlist;
            pVlist++;
            if ((val != xTrue) && (val != xFalse)) {
                error = BadValue;
                client.errorValue = cast(uint)val;
                goto PatchUp;
            }
            pWin.saveUnder = val;
            break;
        case CWEventMask:
            rc = EventSelectForWindow(pWin, client, cast(Mask) *pVlist);
            if (rc) {
                error = rc;
                goto PatchUp;
            }
            pVlist++;
            break;
        case CWDontPropagate:
            rc = EventSuppressForWindow(pWin, client, cast(Mask) *pVlist,
                                        &checkOptional);
            if (rc) {
                error = rc;
                goto PatchUp;
            }
            pVlist++;
            break;
        case CWOverrideRedirect:
            val = cast(BOOL) *pVlist;
            pVlist++;
            if ((val != xTrue) && (val != xFalse)) {
                error = BadValue;
                client.errorValue = cast(uint)val;
                goto PatchUp;
            }
            if (val == xTrue) {
                rc = XaceHookResourceAccess(client, pWin.drawable.id,
                              X11_RESTYPE_WINDOW, pWin, X11_RESTYPE_NONE, null, DixGrabAccess);
                if (rc != Success) {
                    error = rc;
                    client.errorValue = cast(uint)pWin.drawable.id;
                    goto PatchUp;
                }
            }
            pWin.overrideRedirect = val;
            break;
        case CWColormap:
            cmap = cast(Colormap) * pVlist;
            pVlist++;
            if (cmap == CopyFromParent) {
                if (pWin.parent &&
                    (!pWin.optional ||
                     pWin.optional.visual == mixin(wVisual!("pWin.parent")))) {
                    cmap = mixin(wColormap!("pWin.parent"));
                }
                else
                    cmap = None;
            }
            if (cmap == None) {
                error = BadMatch;
                goto PatchUp;
            }
            rc = dixLookupResourceByType(cast(void**) &pCmap, cmap, X11_RESTYPE_COLORMAP,
                                         client, DixUseAccess);
            if (rc != Success) {
                error = rc;
                client.errorValue = cast(uint)cmap;
                goto PatchUp;
            }
            if (pCmap.pVisual.vid != mixin(wVisual!("pWin")) ||
                pCmap.pScreen != pScreen) {
                error = BadMatch;
                goto PatchUp;
            }
            if (cmap != mixin(wColormap!("pWin"))) {
                if (!pWin.optional) {
                    if (!MakeWindowOptional(pWin)) {
                        error = BadAlloc;
                        goto PatchUp;
                    }
                }
                else if (pWin.parent && cmap == mixin(wColormap!("pWin.parent")))
                    checkOptional = TRUE;

                /*
                 * propagate the original colormap to any children
                 * inheriting it
                 */

                for (WindowPtr pChild = pWin.firstChild; pChild;
                     pChild = pChild.nextSib) {
                    if (!MakeWindowOptional(pChild)) {
                        error = BadAlloc;
                        goto PatchUp;
                    }
                }

                pWin.optional.colormap = cmap;

                /*
                 * check on any children now matching the new colormap
                 */

                for (WindowPtr pChild = pWin.firstChild; pChild;
                     pChild = pChild.nextSib) {
                    if (pChild.optional.colormap == cmap)
                        CheckWindowOptionalNeed(pChild);
                }

                // xE;
                    xE.u.colormap.window = cast(uint)pWin.drawable.id,
                    xE.u.colormap.colormap = cast(uint)cmap,
                    xE.u.colormap.new_ = xTrue,
                    xE.u.colormap.state = cast(ubyte)IsMapInstalled(cmap, pWin);
                // );
                xE.u.u.type = ColormapNotify;
                DeliverEvents(pWin, &xE, 1, NullWindow);
            }
            break;
        case CWCursor:
            cursorID = cast(Cursor) * pVlist;
            pVlist++;
            /*
             * install the new
             */
            if (cursorID == None) {
                if (pWin == pWin.drawable.pScreen.root)
                    pCursor = rootCursor;
                else
                    pCursor = cast(CursorPtr) None;
            }
            else {
                rc = dixLookupResourceByType(cast(void**) &pCursor, cursorID,
                                             X11_RESTYPE_CURSOR, client, DixUseAccess);
                if (rc != Success) {
                    error = rc;
                    client.errorValue = cast(uint)cursorID;
                    goto PatchUp;
                }
            }

            if (pCursor != mixin(wCursor!"pWin")) {
                /*
                 * patch up child windows so they don't lose cursors.
                 */

                for (WindowPtr pChild = pWin.firstChild; pChild;
                     pChild = pChild.nextSib) {
                    if (!pChild.optional && !pChild.cursorIsNone &&
                        !MakeWindowOptional(pChild)) {
                        error = BadAlloc;
                        goto PatchUp;
                    }
                }

                pOldCursor = null;
                if (pCursor == cast(CursorPtr) None) {
                    pWin.cursorIsNone = TRUE;
                    if (pWin.optional) {
                        pOldCursor = pWin.optional.cursor;
                        pWin.optional.cursor = cast(CursorPtr) None;
                        checkOptional = TRUE;
                    }
                }
                else {
                    if (!pWin.optional) {
                        if (!MakeWindowOptional(pWin)) {
                            error = BadAlloc;
                            goto PatchUp;
                        }
                    }
                    else if (pWin.parent && pCursor == mixin(wCursor!("pWin.parent")))
                        checkOptional = TRUE;
                    pOldCursor = pWin.optional.cursor;
                    pWin.optional.cursor = RefCursor(pCursor);
                    pWin.cursorIsNone = FALSE;
                    /*
                     * check on any children now matching the new cursor
                     */

                    for (WindowPtr pChild = pWin.firstChild; pChild;
                         pChild = pChild.nextSib) {
                        if (pChild.optional &&
                            (pChild.optional.cursor == pCursor))
                            CheckWindowOptionalNeed(pChild);
                    }
                }

                CursorVisible = TRUE;

                if (pWin.realized)
                    WindowHasNewCursor(pWin);

                /* Can't free cursor until here - old cursor
                 * is needed in WindowHasNewCursor
                 */
                FreeCursor(pOldCursor, cast(Cursor) 0);
            }
            break;
        default:
            error = BadValue;
            client.errorValue = cast(uint)vmask;
            goto PatchUp;
        }
        vmaskCopy |= index2;
    }
 PatchUp:
    if (checkOptional)
        CheckWindowOptionalNeed(pWin);

    /* We SHOULD check for an error value here XXX */
    (*pScreen.ChangeWindowAttributes) (pWin, vmaskCopy);

    /*
       If the border contents have changed, redraw the border.
       Note that this has to be done AFTER pScreen->ChangeWindowAttributes
       for the tile to be rotated, and the correct function selected.
     */
    if (((vmaskCopy & (CWBorderPixel | CWBorderPixmap)) || borderRelative)
        && pWin.viewable && mixin(HasBorder!("pWin"))) {
        RegionRec exposed = void;

        RegionNull(&exposed);
        RegionSubtract(&exposed, &pWin.borderClip, &pWin.winSize);
        pWin.drawable.pScreen.PaintWindow(pWin, &exposed, PW_BORDER);
        RegionUninit(&exposed);
    }
    return error;
}

int ProcGetWindowAttributes(ClientPtr client)
{
    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.id, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xGetWindowAttributesReply reply; 
        reply.bitGravity = cast(ubyte)pWin.bitGravity,
        reply.winGravity = cast(ubyte)pWin.winGravity,
        reply.backingStore = cast(ubyte)pWin.backingStore,
        reply.backingBitPlanes = cast(uint)mixin(wBackingBitPlanes!("pWin")),
        reply.backingPixel = mixin(wBackingPixel!("pWin")),
        reply.saveUnder = cast(BOOL) pWin.saveUnder,
        reply.override_ = cast(ubyte)pWin.overrideRedirect,
        reply.mapState = (!pWin.mapped ? IsUnmapped :
                     (pWin.realized ? IsViewable : IsUnviewable)),
        reply.colormap = cast(uint)mixin(wColormap!("pWin")),
        reply.mapInstalled = (mixin(wColormap!("pWin")) == None) ? cast(ubyte)xFalse
             : cast(ubyte)IsMapInstalled(mixin(wColormap!("pWin")), pWin),
        reply.yourEventMask = cast(uint)EventMaskForClient(pWin, client),
        reply.allEventMasks = cast(uint)(pWin.eventMask | mixin(wOtherEventMasks!("pWin"))),
        reply.doNotPropagateMask = cast(ushort)mixin(wDontPropagateMask!("pWin")),
        reply.class_ = pWin.drawable.class_,
        reply.visualID = cast(uint)mixin(wVisual!("pWin"));
    // };

    if (client.swapped) {
        swapl(&reply.visualID);
        swaps(&reply.class_);
        swapl(&reply.backingBitPlanes);
        swapl(&reply.backingPixel);
        swapl(&reply.colormap);
        swapl(&reply.allEventMasks);
        swapl(&reply.yourEventMask);
        swaps(&reply.doNotPropagateMask);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

WindowPtr MoveWindowInStack(WindowPtr pWin, WindowPtr pNextSib)
{
    WindowPtr pParent = pWin.parent;
    WindowPtr pFirstChange = pWin;      /* highest window where list changes */

    if (pWin.nextSib != pNextSib) {
        WindowPtr pOldNextSib = pWin.nextSib;

        if (!pNextSib) {        /* move to bottom */
            if (pParent.firstChild == pWin)
                pParent.firstChild = pWin.nextSib;
            /* if (pWin->nextSib) *//* is always True: pNextSib == NULL
             * and pWin->nextSib != pNextSib
             * therefore pWin->nextSib != NULL */
            pFirstChange = pWin.nextSib;
            pWin.nextSib.prevSib = pWin.prevSib;
            if (pWin.prevSib)
                pWin.prevSib.nextSib = pWin.nextSib;
            pParent.lastChild.nextSib = pWin;
            pWin.prevSib = pParent.lastChild;
            pWin.nextSib = NullWindow;
            pParent.lastChild = pWin;
        }
        else if (pParent.firstChild == pNextSib) {     /* move to top */
            pFirstChange = pWin;
            if (pParent.lastChild == pWin)
                pParent.lastChild = pWin.prevSib;
            if (pWin.nextSib)
                pWin.nextSib.prevSib = pWin.prevSib;
            if (pWin.prevSib)
                pWin.prevSib.nextSib = pWin.nextSib;
            pWin.nextSib = pParent.firstChild;
            pWin.prevSib = null;
            pNextSib.prevSib = pWin;
            pParent.firstChild = pWin;
        }
        else {                  /* move in middle of list */

            WindowPtr pOldNext = pWin.nextSib;

            pFirstChange = NullWindow;
            if (pParent.firstChild == pWin)
                pFirstChange = pParent.firstChild = pWin.nextSib;
            if (pParent.lastChild == pWin) {
                pFirstChange = pWin;
                pParent.lastChild = pWin.prevSib;
            }
            if (pWin.nextSib)
                pWin.nextSib.prevSib = pWin.prevSib;
            if (pWin.prevSib)
                pWin.prevSib.nextSib = pWin.nextSib;
            pWin.nextSib = pNextSib;
            pWin.prevSib = pNextSib.prevSib;
            if (pNextSib.prevSib)
                pNextSib.prevSib.nextSib = pWin;
            pNextSib.prevSib = pWin;
            if (!pFirstChange) {        /* do we know it yet? */
                pFirstChange = pParent.firstChild;     /* no, search from top */
                while ((pFirstChange != pWin) && (pFirstChange != pOldNext))
                    pFirstChange = pFirstChange.nextSib;
            }
        }
        if (pWin.drawable.pScreen.RestackWindow)
            (*pWin.drawable.pScreen.RestackWindow) (pWin, pOldNextSib);
    }

version (ROOTLESS) {
    /*
     * In rootless mode we can't optimize away window restacks.
     * There may be non-X windows around, so even if the window
     * is in the correct position from X's point of view,
     * the underlying window system may want to reorder it.
     */
         if (pWin.drawable.pScreen.RestackWindow)
            (*pWin.drawable.pScreen.RestackWindow) (pWin, pWin.nextSib);
}

    return pFirstChange;
}

void SetWinSize(WindowPtr pWin)
{
    if (pWin.redirectDraw != RedirectDrawNone) {
        BoxRec box = void;

        /*
         * Redirected clients get clip list equal to their
         * own geometry, not clipped to their parent
         */
        box.x1 = pWin.drawable.x;
        box.y1 = pWin.drawable.y;
        box.x2 = cast(short)(pWin.drawable.x + pWin.drawable.width);
        box.y2 = cast(short)(pWin.drawable.y + pWin.drawable.height);
        RegionReset(&pWin.winSize, &box);
    }
    else
        ClippedRegionFromBox(pWin.parent, &pWin.winSize,
                             pWin.drawable.x, pWin.drawable.y,
                             cast(int) pWin.drawable.width,
                             cast(int) pWin.drawable.height);
    if (mixin(wBoundingShape!("pWin")) || mixin(wClipShape!("pWin"))) {
        RegionTranslate(&pWin.winSize, -pWin.drawable.x, -pWin.drawable.y);
        if (mixin(wBoundingShape!("pWin")))
            RegionIntersect(&pWin.winSize, &pWin.winSize,
                            mixin(wBoundingShape!("pWin")));
        if (mixin(wClipShape!("pWin")))
            RegionIntersect(&pWin.winSize, &pWin.winSize, mixin(wClipShape!("pWin")));
        RegionTranslate(&pWin.winSize, pWin.drawable.x, pWin.drawable.y);
    }
}

void SetBorderSize(WindowPtr pWin)
{
    int bw = void;

    if (mixin(HasBorder!("pWin"))) {
        bw = mixin(wBorderWidth!("pWin"));
        if (pWin.redirectDraw != RedirectDrawNone) {
            BoxRec box = void;

            /*
             * Redirected clients get clip list equal to their
             * own geometry, not clipped to their parent
             */
            box.x1 = cast(short)(pWin.drawable.x - bw);
            box.y1 = cast(short)(pWin.drawable.y - bw);
            box.x2 = cast(short)(pWin.drawable.x + pWin.drawable.width + bw);
            box.y2 = cast(short)(pWin.drawable.y + pWin.drawable.height + bw);
            RegionReset(&pWin.borderSize, &box);
        }
        else
            ClippedRegionFromBox(pWin.parent, &pWin.borderSize,
                                 pWin.drawable.x - bw, pWin.drawable.y - bw,
                                 cast(int) (pWin.drawable.width + (bw << 1)),
                                 cast(int) (pWin.drawable.height + (bw << 1)));
        if (mixin(wBoundingShape!("pWin"))) {
            RegionTranslate(&pWin.borderSize, -pWin.drawable.x,
                            -pWin.drawable.y);
            RegionIntersect(&pWin.borderSize, &pWin.borderSize,
                            mixin(wBoundingShape!("pWin")));
            RegionTranslate(&pWin.borderSize, pWin.drawable.x,
                            pWin.drawable.y);
            RegionUnion(&pWin.borderSize, &pWin.borderSize, &pWin.winSize);
        }
    }
    else {
        RegionCopy(&pWin.borderSize, &pWin.winSize);
    }
}

/**
 *
 *  \param x,y          new window position
 *  \param oldx,oldy    old window position
 *  \param destx,desty  position relative to gravity
 */

void GravityTranslate(int x, int y, int oldx, int oldy, int dw, int dh, uint gravity, int* destx, int* desty)
{
    switch (gravity) {
    case NorthGravity:
        *destx = x + dw / 2;
        *desty = y;
        break;
    case NorthEastGravity:
        *destx = x + dw;
        *desty = y;
        break;
    case WestGravity:
        *destx = x;
        *desty = y + dh / 2;
        break;
    case CenterGravity:
        *destx = x + dw / 2;
        *desty = y + dh / 2;
        break;
    case EastGravity:
        *destx = x + dw;
        *desty = y + dh / 2;
        break;
    case SouthWestGravity:
        *destx = x;
        *desty = y + dh;
        break;
    case SouthGravity:
        *destx = x + dw / 2;
        *desty = y + dh;
        break;
    case SouthEastGravity:
        *destx = x + dw;
        *desty = y + dh;
        break;
    case StaticGravity:
        *destx = oldx;
        *desty = oldy;
        break;
    default:
        *destx = x;
        *desty = y;
        break;
    }
}

/* XXX need to retile border on each window with ParentRelative origin */
void ResizeChildrenWinSize(WindowPtr pWin, int dx, int dy, int dw, int dh)
{
    WindowPtr pChild = void;
    Bool resized = (dw || dh);

    for (WindowPtr pSib = pWin.firstChild; pSib; pSib = pSib.nextSib) {
        if (resized && (pSib.winGravity > NorthWestGravity)) {
            int cwsx = void, cwsy = void;

            cwsx = pSib.origin.x;
            cwsy = pSib.origin.y;
            GravityTranslate(cwsx, cwsy, cwsx - dx, cwsy - dy, dw, dh,
                             pSib.winGravity, &cwsx, &cwsy);
            if (cwsx != pSib.origin.x || cwsy != pSib.origin.y) {
                xEvent event;
                
                    event.u.gravity.window = cast(uint)pSib.drawable.id,
                    event.u.gravity.x = cast(short)(cwsx - mixin(wBorderWidth!("pSib"))),
                    event.u.gravity.y = cast(short)(cwsy - mixin(wBorderWidth!("pSib"))),

                event.u.u.type = GravityNotify;
                DeliverEvents(pSib, &event, 1, NullWindow);
                pSib.origin.x = cast(short)cwsx;
                pSib.origin.y = cast(short)cwsy;
            }
        }
        pSib.drawable.x = cast(short)(pWin.drawable.x + pSib.origin.x);
        pSib.drawable.y = cast(short)(pWin.drawable.y + pSib.origin.y);
        SetWinSize(pSib);
        SetBorderSize(pSib);

        dixScreenRaiseWindowPosition(pSib, pSib.drawable.x, pSib.drawable.y);

        if ((pChild = pSib.firstChild) !is null) {
            while (1) {
                pChild.drawable.x = cast(short)(pChild.parent.drawable.x +
                    pChild.origin.x);
                pChild.drawable.y = cast(short)(pChild.parent.drawable.y +
                    pChild.origin.y);
                SetWinSize(pChild);
                SetBorderSize(pChild);
                dixScreenRaiseWindowPosition(pChild,
                                             pChild.drawable.x,
                                             pChild.drawable.y);
                if (pChild.firstChild) {
                    pChild = pChild.firstChild;
                    continue;
                }
                while (!pChild.nextSib && (pChild != pSib))
                    pChild = pChild.parent;
                if (pChild == pSib)
                    break;
                pChild = pChild.nextSib;
            }
        }
    }
}

enum string GET_INT16(string m, string f) = `
	if (` ~ m ~ ` & mask) 
	  { 
	     ` ~ f ~ ` = cast(INT16) *pVlist;
	    pVlist++; 
	 }`;
enum string GET_CARD16(string m, string f) = `
	if (` ~ m ~ ` & mask) 
	 { 
	    ` ~ f ~ ` = cast(CARD16) *pVlist;
	    pVlist++;
	 }`;

enum string GET_CARD8(string m, string f) = `
	if (` ~ m ~ ` & mask) 
	 { 
	    ` ~ f ~ ` = cast(CARD8) *pVlist;
	    pVlist++;
	 }`;

enum ChangeMask = ((Mask)(CWX | CWY | CWWidth | CWHeight));

/*
 * IsSiblingAboveMe
 *     returns Above if pSib above pMe in stack or Below otherwise
 */

private int IsSiblingAboveMe(WindowPtr pMe, WindowPtr pSib)
{
    WindowPtr pWin = void;

    pWin = pMe.parent.firstChild;
    while (pWin) {
        if (pWin == pSib)
            return Above;
        else if (pWin == pMe)
            return Below;
        pWin = pWin.nextSib;
    }
    return Below;
}

private BoxPtr WindowExtents(WindowPtr pWin, BoxPtr pBox)
{
    pBox.x1 = cast(short)(pWin.drawable.x - mixin(wBorderWidth!("pWin")));
    pBox.y1 = cast(short)(pWin.drawable.y - mixin(wBorderWidth!("pWin")));
    pBox.x2 = cast(short)(pWin.drawable.x + cast(int) pWin.drawable.width
        + mixin(wBorderWidth!("pWin")));
    pBox.y2 = cast(short)(pWin.drawable.y + cast(int) pWin.drawable.height
        + mixin(wBorderWidth!("pWin")));
    return pBox;
}

enum string IS_SHAPED(string pWin) = `(`~wBoundingShape!(pWin) ~ `!is null)`;

private RegionPtr MakeBoundingRegion(WindowPtr pWin, BoxPtr pBox)
{
    RegionPtr pRgn = RegionCreate(pBox, 1);

    if (mixin(wBoundingShape!("pWin"))) {
        RegionTranslate(pRgn, -pWin.origin.x, -pWin.origin.y);
        RegionIntersect(pRgn, pRgn, mixin(wBoundingShape!("pWin")));
        RegionTranslate(pRgn, pWin.origin.x, pWin.origin.y);
    }
    return pRgn;
}

private Bool ShapeOverlap(WindowPtr pWin, BoxPtr pWinBox, WindowPtr pSib, BoxPtr pSibBox)
{
    RegionPtr pWinRgn = void, pSibRgn = void;
    Bool ret = void;

    if (!mixin(IS_SHAPED!(`pWin`)) && !mixin(IS_SHAPED!(`pSib`)))
        return TRUE;
    pWinRgn = MakeBoundingRegion(pWin, pWinBox);
    pSibRgn = MakeBoundingRegion(pSib, pSibBox);
    RegionIntersect(pWinRgn, pWinRgn, pSibRgn);
    ret = RegionNotEmpty(pWinRgn);
    RegionDestroy(pWinRgn);
    RegionDestroy(pSibRgn);
    return ret;
}

private Bool AnyWindowOverlapsMe(WindowPtr pWin, WindowPtr pHead, BoxPtr box)
{
    BoxRec sboxrec = void;
    BoxPtr sbox = void;

    for (WindowPtr pSib = pWin.prevSib; pSib != pHead; pSib = pSib.prevSib) {
        if (pSib.mapped) {
            sbox = WindowExtents(pSib, &sboxrec);
            if (mixin(BOXES_OVERLAP!(`sbox`, `box`))
                && ShapeOverlap(pWin, box, pSib, sbox))
                return TRUE;
        }
    }
    return FALSE;
}

private Bool IOverlapAnyWindow(WindowPtr pWin, BoxPtr box)
{
    BoxRec sboxrec = void;
    BoxPtr sbox = void;

    for (WindowPtr pSib = pWin.nextSib; pSib; pSib = pSib.nextSib) {
        if (pSib.mapped) {
            sbox = WindowExtents(pSib, &sboxrec);
            if (mixin(BOXES_OVERLAP!(`sbox`, `box`))
                && ShapeOverlap(pWin, box, pSib, sbox))
                return TRUE;
        }
    }
    return FALSE;
}

/*
 *   WhereDoIGoInTheStack()
 *	  Given pWin and pSib and the relationshipe smode, return
 *	  the window that pWin should go ABOVE.
 *	  If a pSib is specified:
 *	      Above:  pWin is placed just above pSib
 *	      Below:  pWin is placed just below pSib
 *	      TopIf:  if pSib occludes pWin, then pWin is placed
 *		      at the top of the stack
 *	      BottomIf:	 if pWin occludes pSib, then pWin is
 *			 placed at the bottom of the stack
 *	      Opposite: if pSib occludes pWin, then pWin is placed at the
 *			top of the stack, else if pWin occludes pSib, then
 *			pWin is placed at the bottom of the stack
 *
 *	  If pSib is NULL:
 *	      Above:  pWin is placed at the top of the stack
 *	      Below:  pWin is placed at the bottom of the stack
 *	      TopIf:  if any sibling occludes pWin, then pWin is placed at
 *		      the top of the stack
 *	      BottomIf: if pWin occludes any sibline, then pWin is placed at
 *			the bottom of the stack
 *	      Opposite: if any sibling occludes pWin, then pWin is placed at
 *			the top of the stack, else if pWin occludes any
 *			sibling, then pWin is placed at the bottom of the stack
 *
 */

private WindowPtr WhereDoIGoInTheStack(WindowPtr pWin, WindowPtr pSib, short x, short y, ushort w, ushort h, int smode)
{
    BoxRec box = void;
    WindowPtr pHead = void, pFirst = void;

    if ((pWin == pWin.parent.firstChild) && (pWin == pWin.parent.lastChild))
        return null;
    pHead = RealChildHead(pWin.parent);
    pFirst = pHead ? pHead.nextSib : pWin.parent.firstChild;
    box.x1 = x;
    box.y1 = y;
    box.x2 = cast(short)(x + cast(int) w);
    box.y2 = cast(short)(y + cast(int) h);
    switch (smode) {
    case Above:
        if (pSib)
            return pSib;
        else if (pWin == pFirst)
            return pWin.nextSib;
        else
            return pFirst;
    case Below:
        if (pSib)
            if (pSib.nextSib != pWin)
                return pSib.nextSib;
            else
                return pWin.nextSib;
        else
            return NullWindow;
    case TopIf:
        if ((!pWin.mapped || (pSib && !pSib.mapped)))
            return pWin.nextSib;
        else if (pSib) {
            if ((IsSiblingAboveMe(pWin, pSib) == Above) &&
                (RegionContainsRect(&pSib.borderSize, &box) != rgnOUT))
                return pFirst;
            else
                return pWin.nextSib;
        }
        else if (AnyWindowOverlapsMe(pWin, pHead, &box))
            return pFirst;
        else
            return pWin.nextSib;
    case BottomIf:
        if ((!pWin.mapped || (pSib && !pSib.mapped)))
            return pWin.nextSib;
        else if (pSib) {
            if ((IsSiblingAboveMe(pWin, pSib) == Below) &&
                (RegionContainsRect(&pSib.borderSize, &box) != rgnOUT))
                return NullWindow;
            else
                return pWin.nextSib;
        }
        else if (IOverlapAnyWindow(pWin, &box))
            return NullWindow;
        else
            return pWin.nextSib;
    case Opposite:
        if ((!pWin.mapped || (pSib && !pSib.mapped)))
            return pWin.nextSib;
        else if (pSib) {
            if (RegionContainsRect(&pSib.borderSize, &box) != rgnOUT) {
                if (IsSiblingAboveMe(pWin, pSib) == Above)
                    return pFirst;
                else
                    return NullWindow;
            }
            else
                return pWin.nextSib;
        }
        else if (AnyWindowOverlapsMe(pWin, pHead, &box)) {
            /* If I'm occluded, I can't possibly be the first child
             * if (pWin == pWin->parent->firstChild)
             *    return pWin->nextSib;
             */
            return pFirst;
        }
        else if (IOverlapAnyWindow(pWin, &box))
            return NullWindow;
        else
            return pWin.nextSib;
    default:
    {
        /* should never happen; make something up. */
        return pWin.nextSib;
    }
    }
}

private void ReflectStackChange(WindowPtr pWin, WindowPtr pSib, VTKind kind)
{
/* Note that pSib might be NULL */

    Bool WasViewable = cast(Bool) pWin.viewable;
    Bool anyMarked = void;
    WindowPtr pFirstChange = void;
    WindowPtr pLayerWin = void;
    ScreenPtr pScreen = pWin.drawable.pScreen;

    /* if this is a root window, can't be restacked */
    if (!pWin.parent)
        return;

    pFirstChange = MoveWindowInStack(pWin, pSib);

    if (WasViewable) {
        anyMarked = (*pScreen.MarkOverlappedWindows) (pWin, pFirstChange,
                                                       &pLayerWin);
        if (pLayerWin != pWin)
            pFirstChange = pLayerWin;
        if (anyMarked) {
            (*pScreen.ValidateTree) (pLayerWin.parent, pFirstChange, kind);
            (*pScreen.HandleExposures) (pLayerWin.parent);
            if (pWin.drawable.pScreen.PostValidateTree)
                (*pScreen.PostValidateTree) (pLayerWin.parent, pFirstChange,
                                              kind);
        }
    }
    if (pWin.realized)
        WindowsRestructured();
}

/*****
 * ConfigureWindow
 *****/

int ConfigureWindow(WindowPtr pWin, Mask mask, XID* vlist, ClientPtr client)
{
enum RESTACK_WIN =    0;
enum MOVE_WIN =       1;
enum RESIZE_WIN =     2;
enum REBORDER_WIN =   3;
    WindowPtr pSib = NullWindow;
    WindowPtr pParent = pWin.parent;
    Window sibwid = 0;
    Mask index2 = void, tmask = void;
    XID* pVlist = void;
    short x = void, y = void, beforeX = void, beforeY = void;
    ushort w = pWin.drawable.width, h = pWin.drawable.height, bw = pWin.borderWidth;
    int rc = void, action = void, smode = Above;

    if ((pWin.drawable.class_ == InputOnly) && (mask & CWBorderWidth))
        return BadMatch;

    if ((mask & CWSibling) && !(mask & CWStackMode))
        return BadMatch;

    pVlist = vlist;

    if (pParent) {
        x = cast(short)(pWin.drawable.x - pParent.drawable.x - cast(int) bw);
        y = cast(short)(pWin.drawable.y - pParent.drawable.y - cast(int) bw);
    }
    else {
        x = pWin.drawable.x;
        y = pWin.drawable.y;
    }
    beforeX = x;
    beforeY = y;
    action = RESTACK_WIN;
    if ((mask & (CWX | CWY)) && (!(mask & (CWHeight | CWWidth)))) {
        mixin(GET_INT16!(`CWX`, `x`));
        mixin(GET_INT16!(`CWY`, `y`));
        action = MOVE_WIN;
    }
    /* or should be resized */
    else if (mask & (CWX | CWY | CWWidth | CWHeight)) {
        mixin(GET_INT16!(`CWX`, `x`));
        mixin(GET_INT16!(`CWY`, `y`));
        mixin(GET_CARD16!(`CWWidth`, `w`));
        mixin(GET_CARD16!(`CWHeight`, `h`));
        if (!w || !h) {
            client.errorValue = cast(uint)0;
            return BadValue;
        }
        action = RESIZE_WIN;
    }
    tmask = mask & ~ChangeMask;
    while (tmask) {
        index2 = cast(Mask) mixin(lowbit!tmask);
        tmask &= ~index2;
        switch (index2) {
        case CWBorderWidth:
            mixin(GET_CARD16!(`CWBorderWidth`, `bw`));
            break;
        case CWSibling:
            sibwid = cast(Window) *pVlist;
            pVlist++;
            rc = dixLookupWindow(&pSib, sibwid, client, DixGetAttrAccess);
            if (rc != Success) {
                client.errorValue = cast(uint)sibwid;
                return rc;
            }
            if (pSib.parent != pParent)
                return BadMatch;
            if (pSib == pWin)
                return BadMatch;
            break;
        case CWStackMode:
            mixin(GET_CARD8!(`CWStackMode`, `smode`));
            if ((smode != TopIf) && (smode != BottomIf) &&
                (smode != Opposite) && (smode != Above) && (smode != Below)) {
                client.errorValue = cast(uint)smode;
                return BadValue;
            }
            break;
        default:
            client.errorValue = cast(uint)mask;
            return BadValue;
        }
    }
    /* root really can't be reconfigured, so just return */
    if (!pParent)
        return Success;

//     /* Figure out if the window should be moved.  Doesn't
//        make the changes to the window if event sent. */

    if (mask & CWStackMode)
        pSib = WhereDoIGoInTheStack(pWin, pSib, cast(short)(pParent.drawable.x + x),
                                    cast(short)(pParent.drawable.y + y),
                                    cast(short)(w + (bw << 1)), cast(short)(h + (bw << 1)), smode);
    else
        pSib = pWin.nextSib;

    // if(true) {
    if ((!pWin.overrideRedirect) && (mixin(RedirectSend!(`pParent`)))) {
        xEvent event;
            event.u.configureRequest.window = cast(uint)pWin.drawable.id,
            event.u.configureRequest.sibling = (mask & CWSibling) ? cast(uint)sibwid : cast(uint)None,
            event.u.configureRequest.x = x,
            event.u.configureRequest.y = y,
            event.u.configureRequest.width = w,
            event.u.configureRequest.height = h,
            event.u.configureRequest.borderWidth = bw,
            event.u.configureRequest.valueMask = cast(ushort)mask,
            event.u.configureRequest.parent = cast(uint)pParent.drawable.id;
        // };
        event.u.u.type = ConfigureRequest;
        event.u.u.detail = (mask & CWStackMode) ? cast(ubyte)smode : cast(ubyte)Above;
static if(XINERAMA){
        if (!noPanoramiXExtension && (!pParent || !pParent.parent)) {
            ScreenPtr masterScreen = dixGetMasterScreen();
            event.u.configureRequest.x += masterScreen.x;
            event.u.configureRequest.y += masterScreen.y;
        }
} /* XINERAMA */
        if (MaybeDeliverEventToClient(pParent, &event,
                                      SubstructureRedirectMask, client))
            return Success;
    }
    if (action == RESIZE_WIN) {
        Bool size_change = (w != pWin.drawable.width)
            || (h != pWin.drawable.height);

        if (size_change &&
            ((pWin.eventMask | mixin(wOtherEventMasks!("pWin"))) & (1 << 18))) { //ResizeRedirectMask
            xEvent eventT; 

                eventT.u.resizeRequest.window = cast(uint)pWin.drawable.id,
                eventT.u.resizeRequest.width = w,
                eventT.u.resizeRequest.height = h,
            // };
            eventT.u.u.type = ResizeRequest;
            if (MaybeDeliverEventToClient(pWin, &eventT,
                                          (1 << 18), client)) {//ResizeRedirectMask
                /* if event is delivered, leave the actual size alone. */
                w = pWin.drawable.width;
                h = pWin.drawable.height;
                size_change = FALSE;
            }
        }
        if (!size_change) {
            if (mask & (CWX | CWY))
                action = MOVE_WIN;
            else if (mask & (CWStackMode | CWBorderWidth))
                action = RESTACK_WIN;
            else                /* really nothing to do */
                return (Success);
        }
    }

    if (action == RESIZE_WIN)
        /* we've already checked whether there's really a size change */
        goto ActuallyDoSomething;
    if ((mask & CWX) && (x != beforeX))
        goto ActuallyDoSomething;
    if ((mask & CWY) && (y != beforeY))
        goto ActuallyDoSomething;
    if ((mask & CWBorderWidth) && (bw != mixin(wBorderWidth!("pWin"))))
        goto ActuallyDoSomething;
    if (mask & CWStackMode) {
version (ROOTLESS) {
        goto ActuallyDoSomething;
} else {
        /* See above for why we always reorder in rootless mode. */
        if (pWin.nextSib != pSib)
            goto ActuallyDoSomething;
}

    }
    return Success;

 ActuallyDoSomething:
    if (pWin.drawable.pScreen.ConfigNotify) {
        int ret = void;

        ret =
            (*pWin.drawable.pScreen.ConfigNotify) (pWin, x, y, w, h, bw,
                                                     pSib);
        if (ret) {
            client.errorValue = cast(uint)0;
            return ret;
        }
    }

    if (mixin(SubStrSend!(`pWin`, `pParent`))) {
        // xEvent event = {
            // u:configureNotify:window: cast(uint)pWin.drawable.id,
        //     u:configureNotify:aboveSibling: pSib ? pSib.drawable.id : None,
        //     u:configureNotify:x: x,
        //     u:configureNotify:y: y,
        //     u:configureNotify:width: w,
        //     u:configureNotify:height: h,
        //     u:configureNotify:borderWidth: bw,
        //     u:configureNotify:override: pWin.overrideRedirect
        // };

        xEvent event;
            event.u.configureNotify.window = cast(uint)pWin.drawable.id,
            event.u.configureNotify.aboveSibling = pSib ? cast(uint)pSib.drawable.id : cast(uint)None,
            event.u.configureNotify.x = x,
            event.u.configureNotify.y = y,
            event.u.configureNotify.width = w,
            event.u.configureNotify.height = h,
            event.u.configureNotify.borderWidth = bw,
            event.u.configureNotify.override_ = cast(ubyte)pWin.overrideRedirect;

        event.u.u.type = ConfigureNotify;
static if(XINERAMA){
        if (!noPanoramiXExtension && (!pParent || !pParent.parent)) {
            ScreenPtr masterScreen = dixGetMasterScreen();
            event.u.configureNotify.x += masterScreen.x;
            event.u.configureNotify.y += masterScreen.y;
        }
} /* XINERAMA */
        DeliverEvents(pWin, &event, 1, NullWindow);
    }
    if (mask & CWBorderWidth) {
        if (action == RESTACK_WIN) {
            action = MOVE_WIN;
            pWin.borderWidth = bw;
        }
        else if ((action == MOVE_WIN) &&
                 (beforeX + mixin(wBorderWidth!"pWin")== x + cast(int) bw) &&
                 (beforeY + mixin(wBorderWidth!"pWin")== y + cast(int) bw)) {
            action = REBORDER_WIN;
            (*pWin.drawable.pScreen.ChangeBorderWidth) (pWin, bw);
        }
        else
            pWin.borderWidth = bw;
    }
    if (action == MOVE_WIN)
        (*pWin.drawable.pScreen.MoveWindow) (pWin, x, y, pSib,
                                               (mask & CWBorderWidth) ? VTOther
                                               : VTMove);
    else if (action == RESIZE_WIN)
        (*pWin.drawable.pScreen.ResizeWindow) (pWin, x, y, w, h, pSib);
    else if (mask & CWStackMode)
        ReflectStackChange(pWin, pSib, VTOther);

    if (action != RESTACK_WIN)
        CheckCursorConfinement(pWin);
    return Success;
}

/******
 *
 * CirculateWindow
 *    For RaiseLowest, raises the lowest mapped child (if any) that is
 *    obscured by another child to the top of the stack.  For LowerHighest,
 *    lowers the highest mapped child (if any) that is obscuring another
 *    child to the bottom of the stack.	 Exposure processing is performed
 *
 ******/

int CirculateWindow(WindowPtr pParent, int direction, ClientPtr client)
{
    WindowPtr pWin = void, pHead = void, pFirst = void;
    xEvent event = void;
    BoxRec box = void;

    pHead = RealChildHead(pParent);
    pFirst = pHead ? pHead.nextSib : pParent.firstChild;
    if (direction == RaiseLowest) {
        for (pWin = pParent.lastChild;
             (pWin != pHead) &&
             !(pWin.mapped &&
               AnyWindowOverlapsMe(pWin, pHead, WindowExtents(pWin, &box)));
             pWin = pWin.prevSib){}
        if (pWin == pHead)
            return Success;
    }
    else {
        for (pWin = pFirst;
             pWin &&
             !(pWin.mapped &&
               IOverlapAnyWindow(pWin, WindowExtents(pWin, &box)));
             pWin = pWin.nextSib){}
        if (!pWin)
            return Success;
    }

    // event = xEvent (
    //     u:circulate:window: cast(uint)pWin.drawable.id,
    //     u:circulate:parent: pParent.drawable.id,
    //     u:circulate:event: pParent.drawable.id,
    //     u:circulate:place: (direction == RaiseLowest) ?
    //                           PlaceOnTop : PlaceOnBottom,
    // );

    // xEvent event;
        event.u.circulate.window = cast(uint)pWin.drawable.id,
        event.u.circulate.parent = cast(uint)pParent.drawable.id,
        event.u.circulate.event = cast(uint)pParent.drawable.id,
        event.u.circulate.place = (direction == RaiseLowest) ?
                              PlaceOnTop : PlaceOnBottom;
    // );

    if (mixin(RedirectSend!(`pParent`))) {
        event.u.u.type = CirculateRequest;
        if (MaybeDeliverEventToClient(pParent, &event,
                                      SubstructureRedirectMask, client))
            return Success;
    }

    event.u.u.type = CirculateNotify;
    DeliverEvents(pWin, &event, 1, NullWindow);
    ReflectStackChange(pWin,
                       (direction == RaiseLowest) ? pFirst : NullWindow,
                       VTStack);

    return Success;
}

private int CompareWIDs(WindowPtr pWin, void* value)
{                               /* must conform to VisitWindowProcPtr */
    Window* wid = cast(Window*) value;

    if (pWin.drawable.id == *wid)
        return WT_STOPWALKING;
    else
        return WT_WALKCHILDREN;
}

/*****
 *  ReparentWindow
 *****/

int ReparentWindow(WindowPtr pWin, WindowPtr pParent, int x, int y, ClientPtr client)
{
    WindowPtr pPrev = void, pPriorParent = void;
    Bool WasMapped = cast(Bool) (pWin.mapped);
    xEvent event = void;
    int bw = mixin(wBorderWidth!("pWin"));
    ScreenPtr pScreen = void;

    pScreen = pWin.drawable.pScreen;
    if (TraverseTree(pWin, &CompareWIDs, cast(void*) &pParent.drawable.id) ==
        WT_STOPWALKING)
        return BadMatch;
    if (!MakeWindowOptional(pWin))
        return BadAlloc;

    if (WasMapped)
        UnmapWindow(pWin, FALSE);

        event.u.reparent.window = cast(uint)pWin.drawable.id,
        event.u.reparent.parent = cast(uint)pParent.drawable.id,
        event.u.reparent.x = cast(short)x,
        event.u.reparent.y = cast(short)y,
        event.u.reparent.override_ = cast(ubyte)pWin.overrideRedirect;
    // );
    event.u.u.type = ReparentNotify;
static if(XINERAMA){
    if (!noPanoramiXExtension && !pParent.parent) {
        ScreenPtr masterScreen = dixGetMasterScreen();
        event.u.reparent.x += masterScreen.x;
        event.u.reparent.y += masterScreen.y;
    }
} /* XINERAMA */
    DeliverEvents(pWin, &event, 1, pParent);

    /* take out of sibling chain */

    pPriorParent = pPrev = pWin.parent;
    if (pPrev.firstChild == pWin)
        pPrev.firstChild = pWin.nextSib;
    if (pPrev.lastChild == pWin)
        pPrev.lastChild = pWin.prevSib;

    if (pWin.nextSib)
        pWin.nextSib.prevSib = pWin.prevSib;
    if (pWin.prevSib)
        pWin.prevSib.nextSib = pWin.nextSib;

    /* insert at beginning of pParent */
    pWin.parent = pParent;
    pPrev = RealChildHead(pParent);
    if (pPrev) {
        pWin.nextSib = pPrev.nextSib;
        if (pPrev.nextSib)
            pPrev.nextSib.prevSib = pWin;
        else
            pParent.lastChild = pWin;
        pPrev.nextSib = pWin;
        pWin.prevSib = pPrev;
    }
    else {
        pWin.nextSib = pParent.firstChild;
        pWin.prevSib = NullWindow;
        if (pParent.firstChild)
            pParent.firstChild.prevSib = pWin;
        else
            pParent.lastChild = pWin;
        pParent.firstChild = pWin;
    }

    pWin.origin.x = cast(short)(x + bw);
    pWin.origin.y = cast(short)(y + bw);
    pWin.drawable.x = cast(short)(x + bw + pParent.drawable.x);
    pWin.drawable.y = cast(short)(y + bw + pParent.drawable.y);

    /* clip to parent */
    SetWinSize(pWin);
    SetBorderSize(pWin);

    if (pScreen.ReparentWindow)
        (*pScreen.ReparentWindow) (pWin, pPriorParent);

    dixScreenRaiseWindowPosition(pWin, pWin.drawable.x, pWin.drawable.y);
    ResizeChildrenWinSize(pWin, 0, 0, 0, 0);

    CheckWindowOptionalNeed(pWin);

    if (WasMapped)
        MapWindow(pWin, client);
    RecalculateDeliverableEvents(pWin);
    return Success;
}

private void RealizeTree(WindowPtr pWin)
{
    WindowPtr pChild = void;
    RealizeWindowProcPtr Realize = void;

    Realize = pWin.drawable.pScreen.RealizeWindow;
    pChild = pWin;
    while (1) {
        if (pChild.mapped) {
            pChild.realized = TRUE;
            pChild.viewable = (pChild.drawable.class_ == InputOutput);
            (*Realize) (pChild);
            if (pChild.firstChild) {
                pChild = pChild.firstChild;
                continue;
            }
        }
        while (!pChild.nextSib && (pChild != pWin))
            pChild = pChild.parent;
        if (pChild == pWin)
            return;
        pChild = pChild.nextSib;
    }
}

private Bool MaybeDeliverMapRequest(WindowPtr pWin, WindowPtr pParent, ClientPtr client)
{
    xEvent event;
        event.u.mapRequest.window = cast(uint)pWin.drawable.id,
        event.u.mapRequest.parent = cast(uint)pParent.drawable.id;
    // };
    event.u.u.type = MapRequest;

    return MaybeDeliverEventToClient(pParent, &event,
                                     SubstructureRedirectMask,
                                     client);
}

private void DeliverMapNotify(WindowPtr pWin)
{
    xEvent event;
        event.u.mapNotify.window = cast(uint)pWin.drawable.id,
        event.u.mapNotify.override_ = cast(ubyte)pWin.overrideRedirect;
    // };
    event.u.u.type = MapNotify;
    DeliverEvents(pWin, &event, 1, NullWindow);
}

/*****
 * MapWindow
 *    If some other client has selected SubStructureReDirect on the parent
 *    and override-redirect is xFalse, then a MapRequest event is generated,
 *    but the window remains unmapped.	Otherwise, the window is mapped and a
 *    MapNotify event is generated.
 *****/

int MapWindow(WindowPtr pWin, ClientPtr client)
{
    ScreenPtr pScreen = void;

    WindowPtr pParent = void;
    WindowPtr pLayerWin = void;

    if (pWin.mapped)
        return Success;

    /* general check for permission to map window */
    if (XaceHookResourceAccess(client, pWin.drawable.id, X11_RESTYPE_WINDOW,
                 pWin, X11_RESTYPE_NONE, null, DixShowAccess) != Success)
        return Success;

    pScreen = pWin.drawable.pScreen;
    if ((pParent = pWin.parent) !is null) {
        Bool anyMarked = void;

        if ((!pWin.overrideRedirect) && (mixin(RedirectSend!(`pParent`))))
            if (MaybeDeliverMapRequest(pWin, pParent, client))
                return Success;

        pWin.mapped = TRUE;
        if (mixin(SubStrSend!(`pWin`, `pParent`)))
            DeliverMapNotify(pWin);

        if (!pParent.realized)
            return Success;
        RealizeTree(pWin);
        if (pWin.viewable) {
            anyMarked = (*pScreen.MarkOverlappedWindows) (pWin, pWin,
                                                           &pLayerWin);
            if (anyMarked) {
                (*pScreen.ValidateTree) (pLayerWin.parent, pLayerWin, VTMap);
                (*pScreen.HandleExposures) (pLayerWin.parent);
                if (pScreen.PostValidateTree)
                    (*pScreen.PostValidateTree) (pLayerWin.parent, pLayerWin,
                                                  VTMap);
            }
        }
        WindowsRestructured();
    }
    else {
        RegionRec temp = void;

        pWin.mapped = TRUE;
        pWin.realized = TRUE;  /* for roots */
        pWin.viewable = pWin.drawable.class_ == InputOutput;
        /* We SHOULD check for an error value here XXX */
        (*pScreen.RealizeWindow) (pWin);
        if (pScreen.ClipNotify)
            (*pScreen.ClipNotify) (pWin, 0, 0);
        if (pScreen.PostValidateTree)
            (*pScreen.PostValidateTree) (NullWindow, pWin, VTMap);
        RegionNull(&temp);
        RegionCopy(&temp, &pWin.clipList);
        (*pScreen.WindowExposures) (pWin, &temp);
        RegionUninit(&temp);
    }

    return Success;
}

/*****
 * MapSubwindows
 *    Performs a MapWindow all unmapped children of the window, in top
 *    to bottom stacking order.
 *****/

void MapSubwindows(WindowPtr pParent, ClientPtr client)
{
    WindowPtr pFirstMapped = NullWindow;
    ScreenPtr pScreen = void;
    Mask parentRedirect = void;
    Mask parentNotify = void;
    Bool anyMarked = void;
    WindowPtr pLayerWin = void;

    pScreen = pParent.drawable.pScreen;
    parentRedirect = mixin(RedirectSend!(`pParent`));
    parentNotify = mixin(SubSend!(`pParent`));
    anyMarked = FALSE;
    for (WindowPtr pWin = pParent.firstChild; pWin; pWin = pWin.nextSib) {
        if (!pWin.mapped) {
            if (parentRedirect && !pWin.overrideRedirect)
                if (MaybeDeliverMapRequest(pWin, pParent, client))
                    continue;

            pWin.mapped = TRUE;
            if (parentNotify || mixin(StrSend!(`pWin`)))
                DeliverMapNotify(pWin);

            if (!pFirstMapped)
                pFirstMapped = pWin;
            if (pParent.realized) {
                RealizeTree(pWin);
                if (pWin.viewable) {
                    anyMarked |= (*pScreen.MarkOverlappedWindows) (pWin, pWin,
                                                                    null);
                }
            }
        }
    }

    if (pFirstMapped) {
        pLayerWin = (*pScreen.GetLayerWindow) (pParent);
        if (pLayerWin.parent != pParent) {
            anyMarked |= (*pScreen.MarkOverlappedWindows) (pLayerWin,
                                                            pLayerWin, null);
            pFirstMapped = pLayerWin;
        }
        if (anyMarked) {
            (*pScreen.ValidateTree) (pLayerWin.parent, pFirstMapped, VTMap);
            (*pScreen.HandleExposures) (pLayerWin.parent);
            if (pScreen.PostValidateTree)
                (*pScreen.PostValidateTree) (pLayerWin.parent, pFirstMapped,
                                              VTMap);
        }
        WindowsRestructured();
    }
}

private void UnrealizeTree(WindowPtr pWin, Bool fromConfigure)
{
    WindowPtr pChild = void;
    MarkUnrealizedWindowProcPtr MarkUnrealizedWindow = void;

    MarkUnrealizedWindow = pWin.drawable.pScreen.MarkUnrealizedWindow;
    pChild = pWin;
    while (1) {
        if (pChild.realized) {
            pChild.visibility = VisibilityNotViewable;
static if(XINERAMA){
            if (!noPanoramiXExtension && !pChild.drawable.pScreen.myNum) {
                PanoramiXRes* win = void;
                int rc = dixLookupResourceByType(cast(void**) &win,
                                                 pChild.drawable.id,
                                                 XRT_WINDOW,
                                                 serverClient, DixWriteAccess);

                if (rc == Success)
                    win.u.win.visibility = VisibilityNotViewable;
            }
} /* XINERAMA */
            dixScreenRaiseUnrealizeWindow(pChild);
            DeleteWindowFromAnyEvents(pChild, FALSE);
            if (pChild.viewable) {
                pChild.viewable = FALSE;
                (*MarkUnrealizedWindow) (pChild, pWin, fromConfigure);
                pChild.drawable.serialNumber = NEXT_SERIAL_NUMBER;
            }
            if (pChild.firstChild) {
                pChild = pChild.firstChild;
                continue;
            }
        }
        while (!pChild.nextSib && (pChild != pWin))
            pChild = pChild.parent;
        if (pChild == pWin)
            return;
        pChild = pChild.nextSib;
    }
}

private void DeliverUnmapNotify(WindowPtr pWin, Bool fromConfigure)
{
    xEvent event;
        event.u.unmapNotify.window = cast(uint)pWin.drawable.id,
        event.u.unmapNotify.fromConfigure = cast(ubyte)fromConfigure;
    // };
    event.u.u.type = UnmapNotify;
    DeliverEvents(pWin, &event, 1, NullWindow);
}

/*****
 * UnmapWindow
 *    If the window is already unmapped, this request has no effect.
 *    Otherwise, the window is unmapped and an UnMapNotify event is
 *    generated.  Cannot unmap a root window.
 *****/

int UnmapWindow(WindowPtr pWin, Bool fromConfigure)
{
    WindowPtr pParent = void;
    Bool wasRealized = cast(Bool) pWin.realized;
    Bool wasViewable = cast(Bool) pWin.viewable;
    ScreenPtr pScreen = pWin.drawable.pScreen;
    WindowPtr pLayerWin = pWin;

    if ((!pWin.mapped) || (((pParent = pWin.parent) is null)))
        return Success;
    if (mixin(SubStrSend!(`pWin`, `pParent`)))
        DeliverUnmapNotify(pWin, fromConfigure);
    if (wasViewable && !fromConfigure) {
        pWin.valdata = UnmapValData;
        (*pScreen.MarkOverlappedWindows) (pWin, pWin.nextSib, &pLayerWin);
        (*pScreen.MarkWindow) (pLayerWin.parent);
    }
    pWin.mapped = FALSE;
    if (wasRealized)
        UnrealizeTree(pWin, fromConfigure);
    if (wasViewable && !fromConfigure) {
        (*pScreen.ValidateTree) (pLayerWin.parent, pWin, VTUnmap);
        (*pScreen.HandleExposures) (pLayerWin.parent);
        if (pScreen.PostValidateTree)
            (*pScreen.PostValidateTree) (pLayerWin.parent, pWin, VTUnmap);
    }
    if (wasRealized && !fromConfigure) {
        WindowsRestructured();
        WindowGone(pWin);
    }
    return Success;
}

/*****
 * UnmapSubwindows
 *    Performs an UnmapWindow request with the specified mode on all mapped
 *    children of the window, in bottom to top stacking order.
 *****/

void UnmapSubwindows(WindowPtr pWin)
{
    WindowPtr pHead = void;
    Bool wasRealized = cast(Bool) pWin.realized;
    Bool wasViewable = cast(Bool) pWin.viewable;
    Bool anyMarked = FALSE;
    Mask parentNotify = void;
    WindowPtr pLayerWin = null;
    ScreenPtr pScreen = pWin.drawable.pScreen;

    if (!pWin.firstChild)
        return;
    parentNotify = mixin(SubSend!(`pWin`));
    pHead = RealChildHead(pWin);

    if (wasViewable)
        pLayerWin = (*pScreen.GetLayerWindow) (pWin);

    for (WindowPtr pChild = pWin.lastChild; pChild != pHead; pChild = pChild.prevSib) {
        if (pChild.mapped) {
            if (parentNotify || mixin(StrSend!(`pChild`)))
                DeliverUnmapNotify(pChild, xFalse);
            if (pChild.viewable) {
                pChild.valdata = UnmapValData;
                anyMarked = TRUE;
            }
            pChild.mapped = FALSE;
            if (pChild.realized)
                UnrealizeTree(pChild, FALSE);
        }
    }
    if (wasViewable && anyMarked && pLayerWin) {
        if (pLayerWin.parent == pWin)
            (*pScreen.MarkWindow) (pWin);
        else {
            WindowPtr ptmp = void;

            (*pScreen.MarkOverlappedWindows) (pWin, pLayerWin, null);
            (*pScreen.MarkWindow) (pLayerWin.parent);

            /* Windows between pWin and pLayerWin may not have been marked */
            ptmp = pWin;

            while (ptmp != pLayerWin.parent) {
                (*pScreen.MarkWindow) (ptmp);
                ptmp = ptmp.parent;
            }
            pHead = pWin.firstChild;
        }
        (*pScreen.ValidateTree) (pLayerWin.parent, pHead, VTUnmap);
        (*pScreen.HandleExposures) (pLayerWin.parent);
        if (pScreen.PostValidateTree)
            (*pScreen.PostValidateTree) (pLayerWin.parent, pHead, VTUnmap);
    }
    if (wasRealized) {
        WindowsRestructured();
        WindowGone(pWin);
    }
}

void HandleSaveSet(ClientPtr client)
{
    WindowPtr pParent = void, pWin = void;

    for (uint j = 0; j < client.numSaved; j++) {
        pWin = mixin(SaveSetWindow!("client.saveSet[j]"));
        if (mixin(SaveSetToRoot!("client.saveSet[j]")))
            pParent = pWin.drawable.pScreen.root;
        else
        {
            pParent = pWin.parent;
            while (pParent && (dixClientForWindow(pParent) == client))
                pParent = pParent.parent;
        }
        if (pParent) {
            if (pParent != pWin.parent) {
                /* unmap first so that ReparentWindow doesn't remap */
                if (!mixin(SaveSetShouldMap!("client.saveSet[j]")))
                    UnmapWindow(pWin, FALSE);
                ReparentWindow(pWin, pParent,
                               pWin.drawable.x - mixin(wBorderWidth!"pWin")-
                               pParent.drawable.x,
                               pWin.drawable.y - mixin(wBorderWidth!"pWin")-
                               pParent.drawable.y, client);
                if (!pWin.realized && pWin.mapped)
                    pWin.mapped = FALSE;
            }
            if (mixin(SaveSetShouldMap!("client.saveSet[j]")))
                MapWindow(pWin, client);
        }
    }
    free(client.saveSet);
    client.numSaved = 0;
    client.saveSet = null;
}

/**
 *
 * \param x,y  in root
 */
Bool PointInWindowIsVisible(WindowPtr pWin, int x, int y)
{
    BoxRec box = void;

    if (!pWin.realized)
        return FALSE;
    if (RegionContainsPoint(&pWin.borderClip, x, y, &box)
        && (!mixin(wInputShape!("pWin")) ||
            RegionContainsPoint(mixin(wInputShape!("pWin")),
                                x - pWin.drawable.x,
                                y - pWin.drawable.y, &box)))
        return TRUE;
    return FALSE;
}

RegionPtr NotClippedByChildren(WindowPtr pWin)
{
    RegionPtr pReg = RegionCreate(NullBox, 1);

    if (pWin.parent ||
        screenIsSaved != SCREEN_SAVER_ON ||
        !HasSaverWindow(pWin.drawable.pScreen)) {
        RegionIntersect(pReg, &pWin.borderClip, &pWin.winSize);
    }
    return pReg;
}

void SendVisibilityNotify(WindowPtr pWin)
{
    xEvent event = void;
    uint visibility = pWin.visibility;

static if(XINERAMA){
    /* This is not quite correct yet, but it's close */
    if (!noPanoramiXExtension) {
        PanoramiXRes* win = void;
        WindowPtr pWin2 = void;
        int rc = void, Scrnum = void;

        Scrnum = pWin.drawable.pScreen.myNum;

        win = PanoramiXFindIDByScrnum(XRT_WINDOW, pWin.drawable.id, Scrnum);

        if (!win || (win.u.win.visibility == visibility))
            return;

        switch (visibility) {
        case VisibilityUnobscured: {
        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            if (walkScreenIdx == Scrnum)
                continue;

            rc = dixLookupWindow(&pWin2, win.info[walkScreenIdx].id, serverClient,
                                 DixWriteAccess);

            if (rc == Success) {
                if (pWin2.visibility == VisibilityPartiallyObscured)
                    return;

                if (!walkScreenIdx)
                    pWin = pWin2;
            }
        }));
        }
            break;
        case VisibilityPartiallyObscured:
            if (Scrnum) {
                rc = dixLookupWindow(&pWin2, win.info[0].id, serverClient,
                                     DixWriteAccess);
                if (rc == Success)
                    pWin = pWin2;
            }
            break;
        case VisibilityFullyObscured: {
        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            if (walkScreenIdx == Scrnum)
                continue;

            rc = dixLookupWindow(&pWin2, win.info[walkScreenIdx].id, serverClient,
                                 DixWriteAccess);

            if (rc == Success) {
                if (pWin2.visibility != VisibilityFullyObscured)
                    return;

                if (!walkScreenIdx)
                    pWin = pWin2;
            }
        }));
            break;
        }
        default: break;}

        win.u.win.visibility = cast(char)visibility;
    }
} /* XINERAMA */

    // event = xEvent; 
        event.u.visibility.window = cast(uint)pWin.drawable.id,
        event.u.visibility.state = cast(ubyte)visibility;
    // );
    event.u.u.type = VisibilityNotify;
    DeliverEvents(pWin, &event, 1, NullWindow);
}

enum RANDOM_WIDTH = 32;
int dixSaveScreens(ClientPtr client, int on, int mode)
{
    int what = void, type = void;
    XID[2] vlist = void;

    if (on == SCREEN_SAVER_FORCER) {
        if (mode == ScreenSaverReset)
            what = SCREEN_SAVER_OFF;
        else
            what = SCREEN_SAVER_ON;
        type = what;
    }
    else {
        what = on;
        type = what;
        if (what == screenIsSaved)
            type = SCREEN_SAVER_CYCLE;
    }

    mixin(DIX_FOR_EACH_SCREEN!q{
        int rc = dixCallScreensaverAccessCallback(client, walkScreen,
                      DixShowAccess | DixHideAccess);
        if (rc != Success)
            return rc;
    });

    mixin(DIX_FOR_EACH_SCREEN!q{
        if (on == SCREEN_SAVER_FORCER)
            walkScreen.SaveScreen(walkScreen, on);
        if (walkScreen.screensaver.ExternalScreenSaver) {
            if (walkScreen.screensaver.ExternalScreenSaver
                (walkScreen, type, on == SCREEN_SAVER_FORCER))
                continue;
        }
        if (type == screenIsSaved)
            continue;
        switch (type) {
        case SCREEN_SAVER_OFF:
            if (walkScreen.screensaver.blanked == SCREEN_IS_BLANKED) {
                walkScreen.SaveScreen(walkScreen, what);
            }
            else if (HasSaverWindow(walkScreen)) {
                walkScreen.screensaver.pWindow = NullWindow;
                FreeResource(cast(uint)walkScreen.screensaver.wid, X11_RESTYPE_NONE);
            }
            break;
        case SCREEN_SAVER_CYCLE:
            if (walkScreen.screensaver.blanked == SCREEN_IS_TILED) {
                WindowPtr pWin = walkScreen.screensaver.pWindow;

                /* make it look like screen saver is off, so that
                 * NotClippedByChildren will compute a clip list
                 * for the root window, so PaintWindow works
                 */
                screenIsSaved = SCREEN_SAVER_OFF;

                vlist[0] = -(rand() % RANDOM_WIDTH);
                vlist[1] = -(rand() % RANDOM_WIDTH);
                ConfigureWindow(pWin, CWX | CWY, vlist.ptr, client);

                screenIsSaved = SCREEN_SAVER_ON;
            }
            /*
             * Call the DDX saver in case it wants to do something
             * at cycle time
             */
            else if (walkScreen.screensaver.blanked == SCREEN_IS_BLANKED) {
                walkScreen.SaveScreen(walkScreen, type);
            }
            break;
        case SCREEN_SAVER_ON:
            if (ScreenSaverBlanking != DontPreferBlanking) {
                if (walkScreen.SaveScreen(walkScreen, what)) {
                    walkScreen.screensaver.blanked = SCREEN_IS_BLANKED;
                    continue;
                }
                if ((ScreenSaverAllowExposures != DontAllowExposures) &&
                    TileScreenSaver(walkScreen, SCREEN_IS_BLACK)) {
                    walkScreen.screensaver.blanked = SCREEN_IS_BLACK;
                    continue;
                }
            }
            if ((ScreenSaverAllowExposures != DontAllowExposures) &&
                TileScreenSaver(walkScreen, SCREEN_IS_TILED)) {
                walkScreen.screensaver.blanked = SCREEN_IS_TILED;
            }
            else
                walkScreen.screensaver.blanked = SCREEN_ISNT_SAVED;
            break;
        default: break;}
    });

    screenIsSaved = what;
    if (mode == ScreenSaverReset) {
        if (on == SCREEN_SAVER_FORCER) {
            DeviceIntPtr dev = void;
            UpdateCurrentTimeIf();
            mixin(nt_list_for_each_entry!("dev", "inputInfo.devices", "next", q{
                NoticeTime(dev, currentTime);
            }));;
        }
        SetScreenSaverTimer();
    }
    return Success;
}

int SaveScreens(int on, int mode)
{
    return dixSaveScreens(serverClient, on, mode);
}

private Bool TileScreenSaver(ScreenPtr pScreen, int kind)
{
    int result = void;
    XID[3] attributes = void;
    Mask mask = void;
    WindowPtr pWin = void;
    CursorMetricRec cm = void;
    CursorPtr cursor = void;
    XID cursorID = 0;
    int attri = void;

    mask = 0;
    attri = 0;
    switch (kind) {
    case SCREEN_IS_TILED:
        switch (pScreen.root.backgroundState) {
        case BackgroundPixel:
            attributes[attri++] = cast(uint)pScreen.root.background.pixel;
            mask |= CWBackPixel;
            break;
        case BackgroundPixmap:
            attributes[attri++] = cast(uint)None;
            mask |= CWBackPixmap;
            break;
        default:
            break;
        }
        break;
    case SCREEN_IS_BLACK:
        attributes[attri++] = cast(uint)pScreen.root.drawable.pScreen.blackPixel;
        mask |= CWBackPixel;
        break;
    default: break;}
    mask |= CWOverrideRedirect;
    attributes[attri++] = xTrue;

    /*
     * create a blank cursor
     */

    cm.width = 16;
    cm.height = 16;
    cm.xhot = 8;
    cm.yhot = 8;
    ubyte* srcbits = cast(ubyte*) calloc(16, mixin(BitmapBytePad!("32")));
    ubyte* mskbits = cast(ubyte*) calloc(16, mixin(BitmapBytePad!("32")));
    if (!srcbits || !mskbits) {
        free(srcbits);
        free(mskbits);
        cursor = null;
    }
    else {
        for (int j = 0; j < mixin(BitmapBytePad!("32")) * 16; j++)
            srcbits[j] = mskbits[j] = 0x0;
        result = AllocARGBCursor(srcbits, mskbits, null, &cm, 0, 0, 0, 0, 0, 0,
                                 &cursor, serverClient, cast(XID) 0);
        if (cursor) {
            cursorID = dixAllocServerXID();
            if (AddResource(cast(uint)cursorID, X11_RESTYPE_CURSOR, cast(void*) cursor)) {
                attributes[attri] = cursorID;
                mask |= CWCursor;
            }
            else
                cursor = null;
        }
        else {
            free(srcbits);
            free(mskbits);
        }
    }

    pWin = pScreen.screensaver.pWindow =
        dixCreateWindow(pScreen.screensaver.wid,
                     pScreen.root,
                     -RANDOM_WIDTH, -RANDOM_WIDTH,
                     cast(ushort) pScreen.width + RANDOM_WIDTH,
                     cast(ushort) pScreen.height + RANDOM_WIDTH,
                     0, InputOutput, mask, attributes.ptr, 0, serverClient,
                     mixin(wVisual!("pScreen.root")), &result);

    if (cursor)
        FreeResource(cast(uint)cursorID, X11_RESTYPE_NONE);

    if (!pWin)
        return FALSE;

    if (!AddResource(cast(uint)pWin.drawable.id, X11_RESTYPE_WINDOW,
                     cast(void*) pScreen.screensaver.pWindow))
        return FALSE;

    if (mask & CWBackPixmap) {
        MakeRootTile(pWin);
        (*pWin.drawable.pScreen.ChangeWindowAttributes) (pWin, CWBackPixmap);
    }
    MapWindow(pWin, serverClient);
    return TRUE;
}

/*
 * FindWindowWithOptional
 *
 * search ancestors of the given window for an entry containing
 * a WindowOpt structure.  Assumptions:	 some parent will
 * contain the structure.
 */

WindowPtr FindWindowWithOptional(WindowPtr w)
{
    do
        w = w.parent;
    while (!w.optional);
    return w;
}

/*
 * CheckWindowOptionalNeed
 *
 * check each optional entry in the given window to see if
 * the value is satisfied by the default rules.	 If so,
 * release the optional record
 */

void CheckWindowOptionalNeed(WindowPtr w)
{
    WindowOptPtr optional = void;
    WindowOptPtr parentOptional = void;

    if (!w.parent || !w.optional)
        return;
    optional = w.optional;
    if (optional.dontPropagateMask != DontPropagateMasks[w.dontPropagate])
        return;
    if (optional.otherEventMasks != 0)
        return;
    if (optional.otherClients !is null)
        return;
    if (optional.passiveGrabs !is null)
        return;
    if (optional.backingBitPlanes != cast(CARD32)~0L)
        return;
    if (optional.backingPixel != 0)
        return;
    if (optional.boundingShape !is null)
        return;
    if (optional.clipShape !is null)
        return;
    if (optional.inputShape !is null)
        return;
    if (optional.inputMasks !is null)
        return;
    if (optional.deviceCursors !is null) {
        DevCursNodePtr pNode = optional.deviceCursors;

        while (pNode) {
            if (pNode.cursor !is null)
                return;
            pNode = pNode.next;
        }
    }

    parentOptional = FindWindowWithOptional(w).optional;
    if (optional.visual != parentOptional.visual)
        return;
    if (optional.cursor !is null &&
        (optional.cursor != parentOptional.cursor || w.parent.cursorIsNone))
        return;
    if (optional.colormap != parentOptional.colormap)
        return;
    DisposeWindowOptional(w);
}

/*
 * MakeWindowOptional
 *
 * create an optional record and initialize it with the default
 * values.
 */

Bool MakeWindowOptional(WindowPtr pWin)
{
    WindowOptPtr parentOptional = void;

    if (pWin.optional)
        return TRUE;

    WindowOptPtr optional = cast(WindowOptRec*) calloc(1, WindowOptRec.sizeof);
    if (!optional)
        return FALSE;
    optional.dontPropagateMask = DontPropagateMasks[pWin.dontPropagate];
    optional.otherEventMasks = 0;
    optional.otherClients = null;
    optional.passiveGrabs = null;
    optional.backingBitPlanes = cast(uint)~0L;
    optional.backingPixel = 0;
    optional.boundingShape = null;
    optional.clipShape = null;
    optional.inputShape = null;
    optional.inputMasks = null;
    optional.deviceCursors = null;

    parentOptional = FindWindowWithOptional(pWin).optional;
    optional.visual = parentOptional.visual;
    if (!pWin.cursorIsNone) {
        optional.cursor = RefCursor(parentOptional.cursor);
    }
    else {
        optional.cursor = null;
    }
    optional.colormap = parentOptional.colormap;
    pWin.optional = optional;
    return TRUE;
}

/*
 * Changes the cursor struct for the given device and the given window.
 * A cursor that does not have a device cursor set will use whatever the
 * standard cursor is for the window. If all devices have a cursor set,
 * changing the window cursor (e.g. using XDefineCursor()) will not have any
 * visible effect. Only when one of the device cursors is set to None again,
 * this device's cursor will display the changed standard cursor.
 *
 * CursorIsNone of the window struct is NOT modified if you set a device
 * cursor.
 *
 * Assumption: If there is a node for a device in the list, the device has a
 * cursor. If the cursor is set to None, it is inherited by the parent.
 */
int ChangeWindowDeviceCursor(WindowPtr pWin, DeviceIntPtr pDev, CursorPtr pCursor)
{
    DevCursNodePtr pNode = void, pPrev = void;
    CursorPtr pOldCursor = null;
    ScreenPtr pScreen = void;

    if (!MakeWindowOptional(pWin))
        return BadAlloc;

    /* 1) Check if window has device cursor set
     *  Yes: 1.1) swap cursor with given cursor if parent does not have same
     *            cursor, free old cursor
     *       1.2) free old cursor, use parent cursor
     *  No: 1.1) add node to beginning of list.
     *      1.2) add cursor to node if parent does not have same cursor
     *      1.3) use parent cursor if parent does not have same cursor
     *  2) Patch up children if child has a devcursor
     *  2.1) if child has cursor None, it inherited from parent, set to old
     *  cursor
     *  2.2) if child has same cursor as new cursor, remove and set to None
     */

    pScreen = pWin.drawable.pScreen;

    if (WindowSeekDeviceCursor(pWin, pDev, &pNode, &pPrev)) {
        /* has device cursor */

        if (pNode.cursor == pCursor)
            return Success;

        pOldCursor = pNode.cursor;

        if (!pCursor) {         /* remove from list */
            if (pPrev)
                pPrev.next = pNode.next;
            else
                /* first item in list */
                pWin.optional.deviceCursors = pNode.next;

            free(pNode);
            goto out_;
        }

    }
    else {
        /* no device cursor yet */
        if (!pCursor)
            return Success;

        DevCursNodePtr pNewNode = cast(DevCursNodeRec*) calloc(1, DevCursNodeRec.sizeof);
        if (!pNewNode)
            return BadAlloc;

        pNewNode.dev = pDev;
        pNewNode.next = pWin.optional.deviceCursors;
        pWin.optional.deviceCursors = pNewNode;
        pNode = pNewNode;
    }

    if (pCursor && WindowParentHasDeviceCursor(pWin, pDev, pCursor))
        pNode.cursor = null;
    else {
        pNode.cursor = RefCursor(pCursor);
    }

    pNode = pPrev = null;
    /* fix up children */
    for (WindowPtr pChild = pWin.firstChild; pChild; pChild = pChild.nextSib) {
        if (WindowSeekDeviceCursor(pChild, pDev, &pNode, &pPrev)) {
            if (pNode.cursor is null) {        /* inherited from parent */
                pNode.cursor = RefCursor(pOldCursor);
            }
            else if (pNode.cursor == pCursor) {
                pNode.cursor = null;
                FreeCursor(pCursor, cast(Cursor) 0);        /* fix up refcnt */
            }
        }
    }

 out_:
    CursorVisible = TRUE;

    if (pWin.realized)
        WindowHasNewCursor(pWin);

    FreeCursor(pOldCursor, cast(Cursor) 0);

    /* FIXME: We SHOULD check for an error value here XXX
       (comment taken from ChangeWindowAttributes) */
    (*pScreen.ChangeWindowAttributes) (pWin, CWCursor);

    return Success;
}

/* Get device cursor for given device or None if none is set */
CursorPtr WindowGetDeviceCursor(WindowPtr pWin, DeviceIntPtr pDev)
{
    DevCursorList pList = void;

    if (!pWin.optional || !pWin.optional.deviceCursors)
        return null;

    pList = pWin.optional.deviceCursors;

    while (pList) {
        if (pList.dev == pDev) {
            if (pList.cursor is null)  /* inherited from parent */
                return WindowGetDeviceCursor(pWin.parent, pDev);
            else
                return pList.cursor;
        }
        pList = pList.next;
    }
    return null;
}

/* Searches for a DevCursorNode for the given window and device. If one is
 * found, return True and set pNode and pPrev to the node and to the node
 * before the node respectively. Otherwise return False.
 * If the device is the first in list, pPrev is set to NULL.
 */
private Bool WindowSeekDeviceCursor(WindowPtr pWin, DeviceIntPtr pDev, DevCursNodePtr* pNode, DevCursNodePtr* pPrev)
{
    DevCursorList pList = void;

    if (!pWin.optional)
        return FALSE;

    pList = pWin.optional.deviceCursors;

    if (pList && pList.dev == pDev) {
        *pNode = pList;
        *pPrev = null;
        return TRUE;
    }

    while (pList) {
        if (pList.next) {
            if (pList.next.dev == pDev) {
                *pNode = pList.next;
                *pPrev = pList;
                return TRUE;
            }
        }
        pList = pList.next;
    }
    return FALSE;
}

/* Return True if a parent has the same device cursor set or False if
 * otherwise
 */
private Bool WindowParentHasDeviceCursor(WindowPtr pWin, DeviceIntPtr pDev, CursorPtr pCursor)
{
    WindowPtr pParent = void;
    DevCursNodePtr pParentNode = void, pParentPrev = void;

    pParent = pWin.parent;
    while (pParent) {
        if (WindowSeekDeviceCursor(pParent, pDev, &pParentNode, &pParentPrev)) {
            /* if there is a node in the list, the win has a dev cursor */
            if (!pParentNode.cursor)   /* inherited. */
                pParent = pParent.parent;
            else if (pParentNode.cursor == pCursor)    /* inherit */
                return TRUE;
            else                /* different cursor */
                return FALSE;
        }
        else
            /* parent does not have a device cursor for our device */
            return FALSE;
    }
    return FALSE;
}

/*
 * SetRootClip --
 *	Enable or disable rendering to the screen by
 *	setting the root clip list and revalidating
 *	all of the windows
 */
void SetRootClip(ScreenPtr pScreen, int enable)
{
    WindowPtr pWin = pScreen.root;
    Bool WasViewable = void;
    Bool anyMarked = FALSE;
    WindowPtr pLayerWin = void;
    BoxRec box = void;
    RootClipMode mode = cast(RootClipMode)enable;

    if (!pWin)
        return;
    WasViewable = cast(Bool) (pWin.viewable);
    if (WasViewable && mode != ROOT_CLIP_INPUT_ONLY) {
        for (WindowPtr pChild = pWin.firstChild; pChild; pChild = pChild.nextSib) {
            cast(void) (*pScreen.MarkOverlappedWindows) (pChild,
                                                      pChild, &pLayerWin);
        }
        (*pScreen.MarkWindow) (pWin);
        anyMarked = TRUE;
        if (pWin.valdata) {
            if (mixin(HasBorder!("pWin"))) {
                RegionPtr borderVisible = void;

                borderVisible = RegionCreate(NullBox, 1);
                RegionSubtract(borderVisible,
                               &pWin.borderClip, &pWin.winSize);
                pWin.valdata.before.borderVisible = borderVisible;
            }
            pWin.valdata.before.resized = TRUE;
        }
    }

    if (mode != ROOT_CLIP_NONE) {
        pWin.drawable.width = pScreen.width;
        pWin.drawable.height = pScreen.height;

        box.x1 = 0;
        box.y1 = 0;
        box.x2 = pScreen.width;
        box.y2 = pScreen.height;

        RegionInit(&pWin.winSize, &box, 1);
        RegionInit(&pWin.borderSize, &box, 1);

        /*
         * Use REGION_BREAK to avoid optimizations in ValidateTree
         * that assume the root borderClip can't change well, normally
         * it doesn't...)
         */
        RegionBreak(&pWin.clipList);

	/* For INPUT_ONLY, empty the borderClip so no rendering will ever
	 * be attempted to the screen pixmap (only redirected windows),
	 * but we keep borderSize as full regardless. */
        if (WasViewable && mode == ROOT_CLIP_FULL)
            RegionReset(&pWin.borderClip, &box);
        else
            RegionEmpty(&pWin.borderClip);
    }
    else {
        RegionEmpty(&pWin.borderClip);
        RegionBreak(&pWin.clipList);
    }

    ResizeChildrenWinSize(pWin, 0, 0, 0, 0);

    if (WasViewable && mode != ROOT_CLIP_INPUT_ONLY) {
        if (pWin.firstChild) {
            anyMarked |= (*pScreen.MarkOverlappedWindows) (pWin.firstChild,
                                                            pWin.firstChild,
                                                            null);
        }
        else {
            (*pScreen.MarkWindow) (pWin);
            anyMarked = TRUE;
        }

        if (anyMarked) {
            (*pScreen.ValidateTree) (pWin, NullWindow, VTOther);
            (*pScreen.HandleExposures) (pWin);
            if (pScreen.PostValidateTree)
                (*pScreen.PostValidateTree) (pWin, NullWindow, VTOther);
        }
    }
    if (pWin.realized)
        WindowsRestructured();
    FlushAllOutput();
}

VisualPtr WindowGetVisual(WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;
    VisualID vid = mixin(wVisual!("pWin"));

    for (int i = 0; i < pScreen.numVisuals; i++)
        if (pScreen.visuals[i].vid == vid)
            return &pScreen.visuals[i];
    return null;
}

/*
 * @brief check whether a window (ID) is a screen root window
 *
 * The underlying resource query is explicitly done on behalf of serverClient,
 * so XACE resource hooks don't recognize this as a client action.
 * It's explicitly designed for use in hooks that don't wanna cause unncessary
 * traffic in other XACE resource hooks: things done by the serverClient usually
 * considered safe enough for not needing any additional security checks.
 * (we don't have any way for completely skipping the XACE hook yet)
 */
Bool dixWindowIsRoot(Window window)
{
    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, window, serverClient, DixGetAttrAccess);
    if (rc != Success)
        return FALSE;
    return (pWin == pWin.drawable.pScreen.root);
}
