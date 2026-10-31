module dix.swapreq;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

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

********************************************************/

import build.dix_config;

//import x11.X;
//import x11.Xproto;
//import x11.Xprotostr;

import dix.dix_priv;
import dix.reqhandlers_priv;

import include.misc;
import dix.dixstruct_priv;
import include.extnsionst;         /* for SendEvent */
import std.conv;
import dix.events;
import tables;
import dix.request_priv;
// import swapreq;

/* Thanks to Jack Palevich for testing and subsequently rewriting all this */

/* Byte swap a list of shorts */
void SwapShorts(short* list, c_ulong count)
{
    while (count >= 16) {
        swaps(list + 0);
        swaps(list + 1);
        swaps(list + 2);
        swaps(list + 3);
        swaps(list + 4);
        swaps(list + 5);
        swaps(list + 6);
        swaps(list + 7);
        swaps(list + 8);
        swaps(list + 9);
        swaps(list + 10);
        swaps(list + 11);
        swaps(list + 12);
        swaps(list + 13);
        swaps(list + 14);
        swaps(list + 15);
        list += 16;
        count -= 16;
    }
    if (count != 0) {
        do {
            swaps(list);
            list++;
        } while (--count != 0);
    }
}

int SProcCreateWindow(ClientPtr client)
{
    mixin(REQUEST!xCreateWindowReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCreateWindowReq);
    swapl(&stuff.wid);
    swapl(&stuff.parent);
    swaps(&stuff.x);
    swaps(&stuff.y);
    swaps(&stuff.width);
    swaps(&stuff.height);
    swaps(&stuff.borderWidth);
    swaps(&stuff.class_);
    swapl(&stuff.visual);
    swapl(&stuff.mask);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_CreateWindow]) (client));
}

int SProcChangeWindowAttributes(ClientPtr client)
{
    mixin(REQUEST!xChangeWindowAttributesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeWindowAttributesReq);
    swapl(&stuff.window);
    swapl(&stuff.valueMask);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_ChangeWindowAttributes]) (client));
}

int SProcReparentWindow(ClientPtr client)
{
    mixin(REQUEST!xReparentWindowReq);
    mixin(REQUEST_AT_LEAST_SIZE!xReparentWindowReq);
    swapl(&stuff.window);
    swapl(&stuff.parent);
    swaps(&stuff.x);
    swaps(&stuff.y);
    return ((*ProcVector[X_ReparentWindow]) (client));
}

int SProcConfigureWindow(ClientPtr client)
{
    mixin(REQUEST!xConfigureWindowReq);
    mixin(REQUEST_AT_LEAST_SIZE!xConfigureWindowReq);
    swapl(&stuff.window);
    swaps(&stuff.mask);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_ConfigureWindow]) (client));

}

int SProcConvertSelection(ClientPtr client)
{
    mixin(REQUEST!xConvertSelectionReq);
    mixin(REQUEST_AT_LEAST_SIZE!xConvertSelectionReq);
    swapl(&stuff.requestor);
    swapl(&stuff.selection);
    swapl(&stuff.target);
    swapl(&stuff.property);
    swapl(&stuff.time);
    return ((*ProcVector[X_ConvertSelection]) (client));
}

int SProcSendEvent(ClientPtr client)
{
    xEvent eventT;
    eventT.u.u.type = 0;
    EventSwapPtr proc = void;

    mixin(REQUEST!xSendEventReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSendEventReq);
    swapl(&stuff.destination);
    swapl(&stuff.eventMask);

    /* Generic events can have variable size, but SendEvent request holds
       exactly 32B of event data. */
    if (stuff.event.u.u.type == GenericEvent) {
        client.errorValue = cast(uint)stuff.event.u.u.type;
        return BadValue;
    }

    /* Swap event */
    proc = EventSwapVector[stuff.event.u.u.type & octal!"0177"];
    if (!proc || proc is &NotImplemented)        /* no swapping proc; invalid event type? */
        return BadValue;
    (*proc) (&stuff.event, &eventT);
    stuff.event = eventT;

    return ((*ProcVector[X_SendEvent]) (client));
}

int SProcUngrabButton(ClientPtr client)
{
    mixin(REQUEST!xUngrabButtonReq);
    mixin(REQUEST_AT_LEAST_SIZE!xUngrabButtonReq);
    swapl(&stuff.grabWindow);
    swaps(&stuff.modifiers);
    return ((*ProcVector[X_UngrabButton]) (client));
}

int SProcChangeActivePointerGrab(ClientPtr client)
{
    mixin(REQUEST!xChangeActivePointerGrabReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeActivePointerGrabReq);
    swapl(&stuff.cursor);
    swapl(&stuff.time);
    swaps(&stuff.eventMask);
    return ((*ProcVector[X_ChangeActivePointerGrab]) (client));
}

int SProcGrabKeyboard(ClientPtr client)
{
    mixin(REQUEST!xGrabKeyboardReq);
    mixin(REQUEST_AT_LEAST_SIZE!xGrabKeyboardReq);
    swapl(&stuff.grabWindow);
    swapl(&stuff.time);
    return ((*ProcVector[X_GrabKeyboard]) (client));
}

int SProcGrabKey(ClientPtr client)
{
    mixin(REQUEST!xGrabKeyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xGrabKeyReq);
    swapl(&stuff.grabWindow);
    swaps(&stuff.modifiers);
    return ((*ProcVector[X_GrabKey]) (client));
}

int SProcUngrabKey(ClientPtr client)
{
    mixin(REQUEST!xUngrabKeyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xUngrabKeyReq);
    swapl(&stuff.grabWindow);
    swaps(&stuff.modifiers);
    return ((*ProcVector[X_UngrabKey]) (client));
}

int SProcGetMotionEvents(ClientPtr client)
{
    mixin(REQUEST!xGetMotionEventsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xGetMotionEventsReq);
    swapl(&stuff.window);
    swapl(&stuff.start);
    swapl(&stuff.stop);
    return ((*ProcVector[X_GetMotionEvents]) (client));
}

int SProcTranslateCoords(ClientPtr client)
{
    mixin(REQUEST!xTranslateCoordsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xTranslateCoordsReq);
    swapl(&stuff.srcWid);
    swapl(&stuff.dstWid);
    swaps(&stuff.srcX);
    swaps(&stuff.srcY);
    return ((*ProcVector[X_TranslateCoords]) (client));
}

int SProcWarpPointer(ClientPtr client)
{
    mixin(REQUEST!xWarpPointerReq);
    mixin(REQUEST_AT_LEAST_SIZE!xWarpPointerReq);
    swapl(&stuff.srcWid);
    swapl(&stuff.dstWid);
    swaps(&stuff.srcX);
    swaps(&stuff.srcY);
    swaps(&stuff.srcWidth);
    swaps(&stuff.srcHeight);
    swaps(&stuff.dstX);
    swaps(&stuff.dstY);
    return ((*ProcVector[X_WarpPointer]) (client));
}

int SProcSetInputFocus(ClientPtr client)
{
    mixin(REQUEST!xSetInputFocusReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetInputFocusReq);
    swapl(&stuff.focus);
    swapl(&stuff.time);
    return ((*ProcVector[X_SetInputFocus]) (client));
}

int SProcOpenFont(ClientPtr client)
{
    mixin(REQUEST!xOpenFontReq);
    mixin(REQUEST_AT_LEAST_SIZE!xOpenFontReq);
    swapl(&stuff.fid);
    swaps(&stuff.nbytes);
    return ((*ProcVector[X_OpenFont]) (client));
}

int SProcListFonts(ClientPtr client)
{
    mixin(REQUEST!xListFontsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xListFontsReq);
    swaps(&stuff.maxNames);
    swaps(&stuff.nbytes);
    return ((*ProcVector[X_ListFonts]) (client));
}

int SProcListFontsWithInfo(ClientPtr client)
{
    mixin(REQUEST!xListFontsWithInfoReq);
    mixin(REQUEST_AT_LEAST_SIZE!xListFontsWithInfoReq);
    swaps(&stuff.maxNames);
    swaps(&stuff.nbytes);
    return ((*ProcVector[X_ListFontsWithInfo]) (client));
}

int SProcSetFontPath(ClientPtr client)
{
    mixin(REQUEST!xSetFontPathReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetFontPathReq);
    swaps(&stuff.nFonts);
    return ((*ProcVector[X_SetFontPath]) (client));
}

int SProcCreatePixmap(ClientPtr client)
{
    mixin(REQUEST!xCreatePixmapReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCreatePixmapReq);
    swapl(&stuff.pid);
    swapl(&stuff.drawable);
    swaps(&stuff.width);
    swaps(&stuff.height);
    return ((*ProcVector[X_CreatePixmap]) (client));
}

int SProcCreateGC(ClientPtr client)
{
    mixin(REQUEST!xCreateGCReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCreateGCReq);
    swapl(&stuff.gc);
    swapl(&stuff.drawable);
    swapl(&stuff.mask);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_CreateGC]) (client));
}

int SProcChangeGC(ClientPtr client)
{
    mixin(REQUEST!xChangeGCReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeGCReq);
    swapl(&stuff.gc);
    swapl(&stuff.mask);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_ChangeGC]) (client));
}

int SProcCopyGC(ClientPtr client)
{
    mixin(REQUEST!xCopyGCReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCopyGCReq);
    swapl(&stuff.srcGC);
    swapl(&stuff.dstGC);
    swapl(&stuff.mask);
    return ((*ProcVector[X_CopyGC]) (client));
}

int SProcSetDashes(ClientPtr client)
{
    mixin(REQUEST!xSetDashesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetDashesReq);
    swapl(&stuff.gc);
    swaps(&stuff.dashOffset);
    swaps(&stuff.nDashes);
    return ((*ProcVector[X_SetDashes]) (client));
}

int SProcSetClipRectangles(ClientPtr client)
{
    mixin(REQUEST!xSetClipRectanglesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xSetClipRectanglesReq);
    swapl(&stuff.gc);
    swaps(&stuff.xOrigin);
    swaps(&stuff.yOrigin);
    mixin(SwapRestS!("stuff"));
    return ((*ProcVector[X_SetClipRectangles]) (client));
}

int SProcClearToBackground(ClientPtr client)
{
    mixin(REQUEST!xClearAreaReq);
    mixin(REQUEST_AT_LEAST_SIZE!xClearAreaReq);
    swapl(&stuff.window);
    swaps(&stuff.x);
    swaps(&stuff.y);
    swaps(&stuff.width);
    swaps(&stuff.height);
    return ((*ProcVector[X_ClearArea]) (client));
}

int SProcCopyArea(ClientPtr client)
{
    mixin(REQUEST!xCopyAreaReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCopyAreaReq);
    swapl(&stuff.srcDrawable);
    swapl(&stuff.dstDrawable);
    swapl(&stuff.gc);
    swaps(&stuff.srcX);
    swaps(&stuff.srcY);
    swaps(&stuff.dstX);
    swaps(&stuff.dstY);
    swaps(&stuff.width);
    swaps(&stuff.height);
    return ((*ProcVector[X_CopyArea]) (client));
}

int SProcCopyPlane(ClientPtr client)
{
    mixin(REQUEST!xCopyPlaneReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCopyPlaneReq);
    swapl(&stuff.srcDrawable);
    swapl(&stuff.dstDrawable);
    swapl(&stuff.gc);
    swaps(&stuff.srcX);
    swaps(&stuff.srcY);
    swaps(&stuff.dstX);
    swaps(&stuff.dstY);
    swaps(&stuff.width);
    swaps(&stuff.height);
    swapl(&stuff.bitPlane);
    return ((*ProcVector[X_CopyPlane]) (client));
}

/* cannot use SProcPoly for this one, because xFillPolyReq
   is longer than xPolyPointReq, and we don't want to swap
   the difference as shorts! */
int SProcFillPoly(ClientPtr client)
{
    mixin(REQUEST!xFillPolyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xFillPolyReq);
    swapl(&stuff.drawable);
    swapl(&stuff.gc);
    mixin(SwapRestS!("stuff"));
    return ((*ProcVector[X_FillPoly]) (client));
}

int SProcPutImage(ClientPtr client)
{
    mixin(REQUEST!xPutImageReq);
    mixin(REQUEST_AT_LEAST_SIZE!xPutImageReq);
    swapl(&stuff.drawable);
    swapl(&stuff.gc);
    swaps(&stuff.width);
    swaps(&stuff.height);
    swaps(&stuff.dstX);
    swaps(&stuff.dstY);
    /* Image should already be swapped */
    return ((*ProcVector[X_PutImage]) (client));
}

int SProcGetImage(ClientPtr client)
{
    mixin(REQUEST!xGetImageReq);
    mixin(REQUEST_AT_LEAST_SIZE!xGetImageReq);
    swapl(&stuff.drawable);
    swaps(&stuff.x);
    swaps(&stuff.y);
    swaps(&stuff.width);
    swaps(&stuff.height);
    swapl(&stuff.planeMask);
    return ((*ProcVector[X_GetImage]) (client));
}

/* ProcImageText used for both ImageText8 and ImageText16 */

int SProcImageText(ClientPtr client)
{
    mixin(REQUEST!xImageTextReq);
    mixin(REQUEST_AT_LEAST_SIZE!xImageTextReq);
    swapl(&stuff.drawable);
    swapl(&stuff.gc);
    swaps(&stuff.x);
    swaps(&stuff.y);
    return ((*ProcVector[stuff.reqType]) (client));
}

int SProcCreateColormap(ClientPtr client)
{
    mixin(REQUEST!xCreateColormapReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCreateColormapReq);
    swapl(&stuff.mid);
    swapl(&stuff.window);
    swapl(&stuff.visual);
    return ((*ProcVector[X_CreateColormap]) (client));
}

int SProcCopyColormapAndFree(ClientPtr client)
{
    mixin(REQUEST!xCopyColormapAndFreeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCopyColormapAndFreeReq);
    swapl(&stuff.mid);
    swapl(&stuff.srcCmap);
    return ((*ProcVector[X_CopyColormapAndFree]) (client));
}

int SProcAllocNamedColor(ClientPtr client)
{
    mixin(REQUEST!xAllocNamedColorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xAllocNamedColorReq);
    swapl(&stuff.cmap);
    swaps(&stuff.nbytes);
    return ((*ProcVector[X_AllocNamedColor]) (client));
}

int SProcAllocColorCells(ClientPtr client)
{
    mixin(REQUEST!xAllocColorCellsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorCellsReq);
    swapl(&stuff.cmap);
    swaps(&stuff.colors);
    swaps(&stuff.planes);
    return ((*ProcVector[X_AllocColorCells]) (client));
}

int SProcAllocColorPlanes(ClientPtr client)
{
    mixin(REQUEST!xAllocColorPlanesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xAllocColorPlanesReq);
    swapl(&stuff.cmap);
    swaps(&stuff.colors);
    swaps(&stuff.red);
    swaps(&stuff.green);
    swaps(&stuff.blue);
    return ((*ProcVector[X_AllocColorPlanes]) (client));
}

int SProcFreeColors(ClientPtr client)
{
    mixin(REQUEST!xFreeColorsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xFreeColorsReq);
    swapl(&stuff.cmap);
    swapl(&stuff.planeMask);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_FreeColors]) (client));
}

void SwapColorItem(xColorItem* pItem)
{
    swapl(&pItem.pixel);
    swaps(&pItem.red);
    swaps(&pItem.green);
    swaps(&pItem.blue);
}

int SProcStoreColors(ClientPtr client)
{
    xColorItem* pItem = void;

    mixin(REQUEST!xStoreColorsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xStoreColorsReq);
    swapl(&stuff.cmap);
    pItem = cast(xColorItem*) &stuff[1];
    for (c_long count = ((client.req_len << 2) - xStoreColorsReq.sizeof) / xColorItem.sizeof; --count >= 0;)
        SwapColorItem(pItem++);
    return ((*ProcVector[X_StoreColors]) (client));
}

int SProcStoreNamedColor(ClientPtr client)
{
    mixin(REQUEST!xStoreNamedColorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xStoreNamedColorReq);
    swapl(&stuff.cmap);
    swapl(&stuff.pixel);
    swaps(&stuff.nbytes);
    return ((*ProcVector[X_StoreNamedColor]) (client));
}

int SProcCreateCursor(ClientPtr client)
{
    mixin(REQUEST!xCreateCursorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xCreateCursorReq);
    swapl(&stuff.cid);
    swapl(&stuff.source);
    swapl(&stuff.mask);
    swaps(&stuff.foreRed);
    swaps(&stuff.foreGreen);
    swaps(&stuff.foreBlue);
    swaps(&stuff.backRed);
    swaps(&stuff.backGreen);
    swaps(&stuff.backBlue);
    swaps(&stuff.x);
    swaps(&stuff.y);
    return ((*ProcVector[X_CreateCursor]) (client));
}

int SProcRecolorCursor(ClientPtr client)
{
    mixin(REQUEST!xRecolorCursorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRecolorCursorReq);
    swapl(&stuff.cursor);
    swaps(&stuff.foreRed);
    swaps(&stuff.foreGreen);
    swaps(&stuff.foreBlue);
    swaps(&stuff.backRed);
    swaps(&stuff.backGreen);
    swaps(&stuff.backBlue);
    return ((*ProcVector[X_RecolorCursor]) (client));
}

int SProcQueryBestSize(ClientPtr client)
{
    mixin(REQUEST!xQueryBestSizeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xQueryBestSizeReq);
    swapl(&stuff.drawable);
    swaps(&stuff.width);
    swaps(&stuff.height);
    return ((*ProcVector[X_QueryBestSize]) (client));
}

int SProcChangeKeyboardMapping(ClientPtr client)
{
    mixin(REQUEST!xChangeKeyboardMappingReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeKeyboardMappingReq);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_ChangeKeyboardMapping]) (client));
}

int SProcChangeKeyboardControl(ClientPtr client)
{
    mixin(REQUEST!xChangeKeyboardControlReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeKeyboardControlReq);
    swapl(&stuff.mask);
    mixin(SwapRestL!("stuff"));
    return ((*ProcVector[X_ChangeKeyboardControl]) (client));
}

int SProcChangePointerControl(ClientPtr client)
{
    mixin(REQUEST!xChangePointerControlReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangePointerControlReq);
    swaps(&stuff.accelNum);
    swaps(&stuff.accelDenum);
    swaps(&stuff.threshold);
    return ((*ProcVector[X_ChangePointerControl]) (client));
}

int SProcChangeHosts(ClientPtr client)
{
    mixin(REQUEST!xChangeHostsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangeHostsReq);
    swaps(&stuff.hostLength);
    return ((*ProcVector[X_ChangeHosts]) (client));
}

void SwapConnClientPrefix(xConnClientPrefix* pCCP)
{
    swaps(&pCCP.majorVersion);
    swaps(&pCCP.minorVersion);
    swaps(&pCCP.nbytesAuthProto);
    swaps(&pCCP.nbytesAuthString);
}
