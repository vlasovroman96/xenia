module dix.swaprep;
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
// //import externs.X11.fonts.fontstruct;

import dix.dix_priv;

import include.misc;
import include.dixstruct;
import include.scrnintstr;
import dix.swaprep;
import os.io;
import os.log;
import std.conv;




private void SwapCharInfo(xCharInfo* pInfo)
{
    swaps(&pInfo.leftSideBearing);
    swaps(&pInfo.rightSideBearing);
    swaps(&pInfo.characterWidth);
    swaps(&pInfo.ascent);
    swaps(&pInfo.descent);
    swaps(&pInfo.attributes);
}

void SwapFontInfo(xQueryFontReply* pr)
{
    swaps(&pr.minCharOrByte2);
    swaps(&pr.maxCharOrByte2);
    swaps(&pr.defaultChar);
    swaps(&pr.nFontProps);
    swaps(&pr.fontAscent);
    swaps(&pr.fontDescent);
    SwapCharInfo(&pr.minBounds);
    SwapCharInfo(&pr.maxBounds);
    swapl(&pr.nCharInfos);
}

void SwapFont(xQueryFontReply* pr, Bool hasGlyphs)
{
    xCharInfo* pxci = void;
    uint nchars = void, nprops = void;
    char* pby = void;

    swaps(&pr.sequenceNumber);
    swapl(&pr.length);
    nchars = cast(uint)pr.nCharInfos;
    nprops = pr.nFontProps;
    SwapFontInfo(pr);
    pby = cast(char*) &pr[1];
    /* Font properties are an atom and either an int32 or a CARD32, so
     * they are always 2 4 byte values */
    for (uint i = 0; i < nprops; i++) {
        swapl(cast(int*) pby);
        pby += 4;
        swapl(cast(int*) pby);
        pby += 4;
    }
    if (hasGlyphs) {
        pxci = cast(xCharInfo*) pby;
        for (uint i = 0; i < nchars; i++, pxci++)
            SwapCharInfo(pxci);
    }
}

void SErrorEvent(xError* from, xError* to)
{
    to.type = X_Error;
    to.errorCode = from.errorCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.resourceID, to.resourceID);
    cpswaps(from.minorCode, to.minorCode);
    to.majorCode = from.majorCode;
}

void SKeyButtonPtrEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.keyButtonPointer.time, to.u.keyButtonPointer.time);
    cpswapl(from.u.keyButtonPointer.root, to.u.keyButtonPointer.root);
    cpswapl(from.u.keyButtonPointer.event, to.u.keyButtonPointer.event);
    cpswapl(from.u.keyButtonPointer.child, to.u.keyButtonPointer.child);
    cpswaps(from.u.keyButtonPointer.rootX, to.u.keyButtonPointer.rootX);
    cpswaps(from.u.keyButtonPointer.rootY, to.u.keyButtonPointer.rootY);
    cpswaps(from.u.keyButtonPointer.eventX, to.u.keyButtonPointer.eventX);
    cpswaps(from.u.keyButtonPointer.eventY, to.u.keyButtonPointer.eventY);
    cpswaps(from.u.keyButtonPointer.state, to.u.keyButtonPointer.state);
    to.u.keyButtonPointer.sameScreen = from.u.keyButtonPointer.sameScreen;
}

void SEnterLeaveEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.enterLeave.time, to.u.enterLeave.time);
    cpswapl(from.u.enterLeave.root, to.u.enterLeave.root);
    cpswapl(from.u.enterLeave.event, to.u.enterLeave.event);
    cpswapl(from.u.enterLeave.child, to.u.enterLeave.child);
    cpswaps(from.u.enterLeave.rootX, to.u.enterLeave.rootX);
    cpswaps(from.u.enterLeave.rootY, to.u.enterLeave.rootY);
    cpswaps(from.u.enterLeave.eventX, to.u.enterLeave.eventX);
    cpswaps(from.u.enterLeave.eventY, to.u.enterLeave.eventY);
    cpswaps(from.u.enterLeave.state, to.u.enterLeave.state);
    to.u.enterLeave.mode = from.u.enterLeave.mode;
    to.u.enterLeave.flags = from.u.enterLeave.flags;
}

void SFocusEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.focus.window, to.u.focus.window);
    to.u.focus.mode = from.u.focus.mode;
}

void SExposeEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.expose.window, to.u.expose.window);
    cpswaps(from.u.expose.x, to.u.expose.x);
    cpswaps(from.u.expose.y, to.u.expose.y);
    cpswaps(from.u.expose.width, to.u.expose.width);
    cpswaps(from.u.expose.height, to.u.expose.height);
    cpswaps(from.u.expose.count, to.u.expose.count);
}

void SGraphicsExposureEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.graphicsExposure.drawable, to.u.graphicsExposure.drawable);
    cpswaps(from.u.graphicsExposure.x, to.u.graphicsExposure.x);
    cpswaps(from.u.graphicsExposure.y, to.u.graphicsExposure.y);
    cpswaps(from.u.graphicsExposure.width, to.u.graphicsExposure.width);
    cpswaps(from.u.graphicsExposure.height, to.u.graphicsExposure.height);
    cpswaps(from.u.graphicsExposure.minorEvent,
            to.u.graphicsExposure.minorEvent);
    cpswaps(from.u.graphicsExposure.count, to.u.graphicsExposure.count);
    to.u.graphicsExposure.majorEvent = from.u.graphicsExposure.majorEvent;
}

void SNoExposureEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.noExposure.drawable, to.u.noExposure.drawable);
    cpswaps(from.u.noExposure.minorEvent, to.u.noExposure.minorEvent);
    to.u.noExposure.majorEvent = from.u.noExposure.majorEvent;
}

void SVisibilityEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.visibility.window, to.u.visibility.window);
    to.u.visibility.state = from.u.visibility.state;
}

void SCreateNotifyEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.createNotify.window, to.u.createNotify.window);
    cpswapl(from.u.createNotify.parent, to.u.createNotify.parent);
    cpswaps(from.u.createNotify.x, to.u.createNotify.x);
    cpswaps(from.u.createNotify.y, to.u.createNotify.y);
    cpswaps(from.u.createNotify.width, to.u.createNotify.width);
    cpswaps(from.u.createNotify.height, to.u.createNotify.height);
    cpswaps(from.u.createNotify.borderWidth, to.u.createNotify.borderWidth);
    to.u.createNotify.override_ = from.u.createNotify.override_;
}

void SDestroyNotifyEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.destroyNotify.event, to.u.destroyNotify.event);
    cpswapl(from.u.destroyNotify.window, to.u.destroyNotify.window);
}

void SUnmapNotifyEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.unmapNotify.event, to.u.unmapNotify.event);
    cpswapl(from.u.unmapNotify.window, to.u.unmapNotify.window);
    to.u.unmapNotify.fromConfigure = from.u.unmapNotify.fromConfigure;
}

void SMapNotifyEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.mapNotify.event, to.u.mapNotify.event);
    cpswapl(from.u.mapNotify.window, to.u.mapNotify.window);
    to.u.mapNotify.override_ = from.u.mapNotify.override_;
}

void SMapRequestEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.mapRequest.parent, to.u.mapRequest.parent);
    cpswapl(from.u.mapRequest.window, to.u.mapRequest.window);
}

void SReparentEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.reparent.event, to.u.reparent.event);
    cpswapl(from.u.reparent.window, to.u.reparent.window);
    cpswapl(from.u.reparent.parent, to.u.reparent.parent);
    cpswaps(from.u.reparent.x, to.u.reparent.x);
    cpswaps(from.u.reparent.y, to.u.reparent.y);
    to.u.reparent.override_ = from.u.reparent.override_;
}

void SConfigureNotifyEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.configureNotify.event, to.u.configureNotify.event);
    cpswapl(from.u.configureNotify.window, to.u.configureNotify.window);
    cpswapl(from.u.configureNotify.aboveSibling,
            to.u.configureNotify.aboveSibling);
    cpswaps(from.u.configureNotify.x, to.u.configureNotify.x);
    cpswaps(from.u.configureNotify.y, to.u.configureNotify.y);
    cpswaps(from.u.configureNotify.width, to.u.configureNotify.width);
    cpswaps(from.u.configureNotify.height, to.u.configureNotify.height);
    cpswaps(from.u.configureNotify.borderWidth,
            to.u.configureNotify.borderWidth);
    to.u.configureNotify.override_ = from.u.configureNotify.override_;
}

void SConfigureRequestEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;  /* actually stack-mode */
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.configureRequest.parent, to.u.configureRequest.parent);
    cpswapl(from.u.configureRequest.window, to.u.configureRequest.window);
    cpswapl(from.u.configureRequest.sibling, to.u.configureRequest.sibling);
    cpswaps(from.u.configureRequest.x, to.u.configureRequest.x);
    cpswaps(from.u.configureRequest.y, to.u.configureRequest.y);
    cpswaps(from.u.configureRequest.width, to.u.configureRequest.width);
    cpswaps(from.u.configureRequest.height, to.u.configureRequest.height);
    cpswaps(from.u.configureRequest.borderWidth,
            to.u.configureRequest.borderWidth);
    cpswaps(from.u.configureRequest.valueMask,
            to.u.configureRequest.valueMask);
}

void SGravityEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.gravity.event, to.u.gravity.event);
    cpswapl(from.u.gravity.window, to.u.gravity.window);
    cpswaps(from.u.gravity.x, to.u.gravity.x);
    cpswaps(from.u.gravity.y, to.u.gravity.y);
}

void SResizeRequestEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.resizeRequest.window, to.u.resizeRequest.window);
    cpswaps(from.u.resizeRequest.width, to.u.resizeRequest.width);
    cpswaps(from.u.resizeRequest.height, to.u.resizeRequest.height);
}

void SCirculateEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.circulate.event, to.u.circulate.event);
    cpswapl(from.u.circulate.window, to.u.circulate.window);
    cpswapl(from.u.circulate.parent, to.u.circulate.parent);
    to.u.circulate.place = from.u.circulate.place;
}

void SPropertyEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.property.window, to.u.property.window);
    cpswapl(from.u.property.atom, to.u.property.atom);
    cpswapl(from.u.property.time, to.u.property.time);
    to.u.property.state = from.u.property.state;
}

void SSelectionClearEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.selectionClear.time, to.u.selectionClear.time);
    cpswapl(from.u.selectionClear.window, to.u.selectionClear.window);
    cpswapl(from.u.selectionClear.atom, to.u.selectionClear.atom);
}

void SSelectionRequestEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.selectionRequest.time, to.u.selectionRequest.time);
    cpswapl(from.u.selectionRequest.owner, to.u.selectionRequest.owner);
    cpswapl(from.u.selectionRequest.requestor,
            to.u.selectionRequest.requestor);
    cpswapl(from.u.selectionRequest.selection,
            to.u.selectionRequest.selection);
    cpswapl(from.u.selectionRequest.target, to.u.selectionRequest.target);
    cpswapl(from.u.selectionRequest.property, to.u.selectionRequest.property);
}

void SSelectionNotifyEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.selectionNotify.time, to.u.selectionNotify.time);
    cpswapl(from.u.selectionNotify.requestor, to.u.selectionNotify.requestor);
    cpswapl(from.u.selectionNotify.selection, to.u.selectionNotify.selection);
    cpswapl(from.u.selectionNotify.target, to.u.selectionNotify.target);
    cpswapl(from.u.selectionNotify.property, to.u.selectionNotify.property);
}

void SColormapEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.colormap.window, to.u.colormap.window);
    cpswapl(from.u.colormap.colormap, to.u.colormap.colormap);
    to.u.colormap.new_ = from.u.colormap.new_;
    to.u.colormap.state = from.u.colormap.state;
}

void SMappingEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    to.u.mappingNotify.request = from.u.mappingNotify.request;
    to.u.mappingNotify.firstKeyCode = from.u.mappingNotify.firstKeyCode;
    to.u.mappingNotify.count = from.u.mappingNotify.count;
}

void SClientMessageEvent(xEvent* from, xEvent* to)
{
    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;  /* actually format */
    cpswaps(from.u.u.sequenceNumber, to.u.u.sequenceNumber);
    cpswapl(from.u.clientMessage.window, to.u.clientMessage.window);
    cpswapl(from.u.clientMessage.u.l.type, to.u.clientMessage.u.l.type);
    switch (from.u.u.detail) {
    case 8:
        memmove(to.u.clientMessage.u.b.bytes.ptr,
                from.u.clientMessage.u.b.bytes.ptr, 20);
        break;
    case 16:
        cpswaps(from.u.clientMessage.u.s.shorts0,
                to.u.clientMessage.u.s.shorts0);
        cpswaps(from.u.clientMessage.u.s.shorts1,
                to.u.clientMessage.u.s.shorts1);
        cpswaps(from.u.clientMessage.u.s.shorts2,
                to.u.clientMessage.u.s.shorts2);
        cpswaps(from.u.clientMessage.u.s.shorts3,
                to.u.clientMessage.u.s.shorts3);
        cpswaps(from.u.clientMessage.u.s.shorts4,
                to.u.clientMessage.u.s.shorts4);
        cpswaps(from.u.clientMessage.u.s.shorts5,
                to.u.clientMessage.u.s.shorts5);
        cpswaps(from.u.clientMessage.u.s.shorts6,
                to.u.clientMessage.u.s.shorts6);
        cpswaps(from.u.clientMessage.u.s.shorts7,
                to.u.clientMessage.u.s.shorts7);
        cpswaps(from.u.clientMessage.u.s.shorts8,
                to.u.clientMessage.u.s.shorts8);
        cpswaps(from.u.clientMessage.u.s.shorts9,
                to.u.clientMessage.u.s.shorts9);
        break;
    case 32:
        cpswapl(from.u.clientMessage.u.l.longs0,
                to.u.clientMessage.u.l.longs0);
        cpswapl(from.u.clientMessage.u.l.longs1,
                to.u.clientMessage.u.l.longs1);
        cpswapl(from.u.clientMessage.u.l.longs2,
                to.u.clientMessage.u.l.longs2);
        cpswapl(from.u.clientMessage.u.l.longs3,
                to.u.clientMessage.u.l.longs3);
        cpswapl(from.u.clientMessage.u.l.longs4,
                to.u.clientMessage.u.l.longs4);
        break;
    default: break;}
}

void SKeymapNotifyEvent(xEvent* from, xEvent* to)
{
    /* Keymap notify events are special; they have no
       sequence number field, and contain entirely 8-bit data */
    *to = *from;
}

private void SwapConnSetup(xConnSetup* pConnSetup, xConnSetup* pConnSetupT)
{
    cpswapl(pConnSetup.release, pConnSetupT.release);
    cpswapl(pConnSetup.ridBase, pConnSetupT.ridBase);
    cpswapl(pConnSetup.ridMask, pConnSetupT.ridMask);
    cpswapl(pConnSetup.motionBufferSize, pConnSetupT.motionBufferSize);
    cpswaps(pConnSetup.nbytesVendor, pConnSetupT.nbytesVendor);
    cpswaps(pConnSetup.maxRequestSize, pConnSetupT.maxRequestSize);
    pConnSetupT.minKeyCode = pConnSetup.minKeyCode;
    pConnSetupT.maxKeyCode = pConnSetup.maxKeyCode;
    pConnSetupT.numRoots = pConnSetup.numRoots;
    pConnSetupT.numFormats = pConnSetup.numFormats;
    pConnSetupT.imageByteOrder = pConnSetup.imageByteOrder;
    pConnSetupT.bitmapBitOrder = pConnSetup.bitmapBitOrder;
    pConnSetupT.bitmapScanlineUnit = pConnSetup.bitmapScanlineUnit;
    pConnSetupT.bitmapScanlinePad = pConnSetup.bitmapScanlinePad;
}

private void SwapWinRoot(xWindowRoot* pRoot, xWindowRoot* pRootT)
{
    cpswapl(pRoot.windowId, pRootT.windowId);
    cpswapl(pRoot.defaultColormap, pRootT.defaultColormap);
    cpswapl(pRoot.whitePixel, pRootT.whitePixel);
    cpswapl(pRoot.blackPixel, pRootT.blackPixel);
    cpswapl(pRoot.currentInputMask, pRootT.currentInputMask);
    cpswaps(pRoot.pixWidth, pRootT.pixWidth);
    cpswaps(pRoot.pixHeight, pRootT.pixHeight);
    cpswaps(pRoot.mmWidth, pRootT.mmWidth);
    cpswaps(pRoot.mmHeight, pRootT.mmHeight);
    cpswaps(pRoot.minInstalledMaps, pRootT.minInstalledMaps);
    cpswaps(pRoot.maxInstalledMaps, pRootT.maxInstalledMaps);
    cpswapl(pRoot.rootVisualID, pRootT.rootVisualID);
    pRootT.backingStore = pRoot.backingStore;
    pRootT.saveUnders = pRoot.saveUnders;
    pRootT.rootDepth = pRoot.rootDepth;
    pRootT.nDepths = pRoot.nDepths;
}

private void SwapVisual(xVisualType* pVis, xVisualType* pVisT)
{
    cpswapl(pVis.visualID, pVisT.visualID);
    pVisT.class_ = pVis.class_;
    pVisT.bitsPerRGB = pVis.bitsPerRGB;
    cpswaps(pVis.colormapEntries, pVisT.colormapEntries);
    cpswapl(pVis.redMask, pVisT.redMask);
    cpswapl(pVis.greenMask, pVisT.greenMask);
    cpswapl(pVis.blueMask, pVisT.blueMask);
}

void SwapConnSetupInfo(char* pInfo, char* pInfoT)
{
    int nbytesVendor = void;
    xConnSetup* pConnSetup = cast(xConnSetup*) pInfo;
    xDepth* depth = void;
    xWindowRoot* root = void;

    SwapConnSetup(pConnSetup, cast(xConnSetup*) pInfoT);
    pInfo += xConnSetup.sizeof;
    pInfoT += xConnSetup.sizeof;

    /* Copy the vendor string */
    nbytesVendor = pad_to_int32(pConnSetup.nbytesVendor);
    memcpy(pInfoT, pInfo, nbytesVendor);
    pInfo += nbytesVendor;
    pInfoT += nbytesVendor;

    /* The Pixmap formats don't need to be swapped, just copied. */
    nbytesVendor = ((xPixmapFormat).sizeof * pConnSetup.numFormats);
    memcpy(pInfoT, pInfo, nbytesVendor);
    pInfo += nbytesVendor;
    pInfoT += nbytesVendor;

    for (int i = 0; i < pConnSetup.numRoots; i++) {
        root = cast(xWindowRoot*) pInfo;
        SwapWinRoot(root, cast(xWindowRoot*) pInfoT);
        pInfo += xWindowRoot.sizeof;
        pInfoT += xWindowRoot.sizeof;

        for (int j = 0; j < root.nDepths; j++) {
            depth = cast(xDepth*) pInfo;
            (cast(xDepth*) pInfoT).depth = depth.depth;
            cpswaps(depth.nVisuals, (cast(xDepth*) pInfoT).nVisuals);
            pInfo += xDepth.sizeof;
            pInfoT += xDepth.sizeof;
            for (int k = 0; k < depth.nVisuals; k++) {
                SwapVisual(cast(xVisualType*) pInfo, cast(xVisualType*) pInfoT);
                pInfo += xVisualType.sizeof;
                pInfoT += xVisualType.sizeof;
            }
        }
    }
}

void WriteSConnectionInfo(ClientPtr pClient, c_ulong size, char* pInfo)
{
    char* pInfoTBase = cast(char*) calloc(1, size);
    if (!pInfoTBase) {
        pClient.noClientException = -1;
        return;
    }
    SwapConnSetupInfo(pInfo, pInfoTBase);
    WriteToClient(pClient, cast(int) size, pInfoTBase);
    free(pInfoTBase);
}

void SwapConnSetupPrefix(xConnSetupPrefix* pcspFrom, xConnSetupPrefix* pcspTo)
{
    pcspTo.success = pcspFrom.success;
    pcspTo.lengthReason = pcspFrom.lengthReason;
    cpswaps(pcspFrom.majorVersion, pcspTo.majorVersion);
    cpswaps(pcspFrom.minorVersion, pcspTo.minorVersion);
    cpswaps(pcspFrom.length, pcspTo.length);
}

void WriteSConnSetupPrefix(ClientPtr pClient, xConnSetupPrefix* pcsp)
{
    xConnSetupPrefix cspT = void;

    SwapConnSetupPrefix(pcsp, &cspT);
    WriteToClient(pClient, cspT.sizeof, &cspT);
}

/*
 * Dummy entry for ReplySwapVector[]
 */

void ReplyNotSwappd(ClientPtr pClient, int size, void* pbuf)
{
    FatalError("Not implemented");
}
