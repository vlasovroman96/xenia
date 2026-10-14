module cursor;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2006, Oracle and/or its affiliates.
 * Copyright 2010 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Copyright © 2002 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;

import dix.cursor_priv;
import dix.dix_priv;
import dix.input_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.screen_hooks_priv;
import dix.screenint_priv;

import xfixes.xfixesint;
import include.scrnintstr;
import dix.cursor;
import include.servermd;
import mi.mipointer;
import include.inputstr;
import include.windowstr;
import Xext.xace;
import include.list;
import Xi.xibarriers;
import externs.X11.extensions.xfixeswire;
import externs.X11.extensions.xfixesproto;
import dix.events;
import os.io;
import dix.screen_hooks;
import dix.swapreq;

private RESTYPE CursorClientType;
private RESTYPE CursorHideCountType;
private RESTYPE CursorWindowType;

private DevPrivateKeyRec CursorScreenPrivateKeyRec;

enum CursorScreenPrivateKey = (&CursorScreenPrivateKeyRec);



enum string VERIFY_CURSOR(string pCursor, string cursor, string client, string access) = `
    {								
	int err = void;							
	err = dixLookupResourceByType(cast(void**) &` ~ pCursor ~ `, ` ~ cursor ~ `,	
				      X11_RESTYPE_CURSOR, ` ~ client ~ `, ` ~ access ~ `);	
	if (err != Success) {						
	    ` ~ client ~ `.errorValue = ` ~ cursor ~ `;				
	    return err;							
	}								
    }`;

/*
 * There is a global list of windows selecting for cursor events
 */

alias CursorEventPtr = _CursorEvent*;

struct  _CursorEvent{
    CursorEventPtr next;
    CARD32 eventMask;
    ClientPtr pClient;
    WindowPtr pWindow;
    XID clientResource;
}

alias CursorEventRec = _CursorEvent;

private CursorEventPtr cursorEvents;

/*
 * Each screen has a list of clients which have requested
 * that the cursor be hid, and the number of times each
 * client has requested.
*/

alias CursorHideCountPtr = _CursorHideCountRec*;

struct _CursorHideCountRec {
    CursorHideCountPtr pNext;
    ClientPtr pClient;
    ScreenPtr pScreen;
    int hideCount;
    XID resource;
}

alias CursorHideCountRec = _CursorHideCountRec;

/*
 * Wrap DisplayCursor to catch cursor change events
 */

struct _CursorScreen {
    DisplayCursorProcPtr DisplayCursor;
    CursorHideCountPtr pCursorHideCounts;
}alias CursorScreenRec = _CursorScreen;
alias CursorScreenPtr = _CursorScreen*;

enum string GetCursorScreen(string s) = `(cast(CursorScreenPtr)dixLookupPrivate(&(` ~ s ~ `).devPrivates, CursorScreenPrivateKey))`;
enum string Wrap(string as,string s,string elt,string func) = `(((` ~ as ~ `).` ~ elt ~ ` = (` ~ s ~ `).` ~ elt ~ `), (` ~ s ~ `).` ~ elt ~ ` = ` ~ func ~ `);`;
enum string Unwrap(string as,string s,string elt,string backup) = `(((` ~ backup ~ `) = (` ~ s ~ `).` ~ elt ~ `), (` ~ s ~ `).` ~ elt ~ ` = (` ~ as ~ `).` ~ elt ~ `);`;

/* The cursor doesn't show up until the first XDefineCursor() */
Bool CursorVisible = FALSE;
Bool EnableCursor = TRUE;

private CursorPtr CursorForDevice(DeviceIntPtr pDev)
{
    if (pDev && pDev.spriteInfo && pDev.spriteInfo.sprite) {
        if (pDev.spriteInfo.anim.pCursor)
            return pDev.spriteInfo.anim.pCursor;
        return pDev.spriteInfo.sprite.current;
    }

    return null;
}

private CursorPtr CursorForClient(ClientPtr client)
{
    return CursorForDevice(PickPointer(client));
}

private Bool CursorDisplayCursor(DeviceIntPtr pDev, ScreenPtr pScreen, CursorPtr pCursor)
{
    CursorScreenPtr cs = mixin(GetCursorScreen!(`pScreen`));
    CursorPtr pOldCursor = CursorForDevice(pDev);
    Bool ret = void;
    DisplayCursorProcPtr backupProc = void;

    mixin(Unwrap!(`cs`, `pScreen`, `DisplayCursor`, `backupProc`));

    CursorVisible = CursorVisible && EnableCursor;

    if (cs.pCursorHideCounts !is null || !CursorVisible) {
        ret = (*pScreen.DisplayCursor) (pDev, pScreen, NullCursor);
    }
    else {
        ret = (*pScreen.DisplayCursor) (pDev, pScreen, pCursor);
    }

    if (pCursor != pOldCursor) {
        CursorEventPtr e = void;

        UpdateCurrentTimeIf();
        for (e = cursorEvents; e; e = e.next) {
            if ((e.eventMask & XFixesDisplayCursorNotifyMask)) {
                xXFixesCursorNotifyEvent ev = {
                    type: cast(ubyte)(XFixesEventBase + XFixesCursorNotify),
                    subtype: XFixesDisplayCursorNotify,
                    window: cast(uint)e.pWindow.drawable.id,
                    cursorSerial: pCursor ? pCursor.serialNumber : 0,
                    timestamp: currentTime.milliseconds,
                    name: cast(uint)(pCursor ? pCursor.name : None)
                };
                WriteEventsToClient(e.pClient, 1, cast(xEvent*) &ev);
            }
        }
    }
    mixin(Wrap!(`cs`, `pScreen`, `DisplayCursor`, `backupProc`));

    return ret;
}

private void CursorScreenClose(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    CursorScreenPtr cs = mixin(GetCursorScreen!(`pScreen`));

     DisplayCursorProcPtr display_proc;

    dixScreenUnhookClose(pScreen, &CursorScreenClose);
    mixin(Unwrap!(`cs`, `pScreen`, `DisplayCursor`, `display_proc`));
    deleteCursorHideCountsForScreen(pScreen);
}

enum CursorAllEvents = (XFixesDisplayCursorNotifyMask);

private int XFixesSelectCursorInput(ClientPtr pClient, WindowPtr pWindow, CARD32 eventMask)
{
    CursorEventPtr* prev = void; CursorEventPtr e = void;
    void* val = void;
    int rc = void;

    for (prev = &cursorEvents; ((e = *prev) !is null); prev = &e.next) {
        if (e.pClient == pClient && e.pWindow == pWindow) {
            break;
        }
    }
    if (!eventMask) {
        if (e) {
            FreeResource(cast(uint)e.clientResource, 0);
        }
        return Success;
    }
    if (!e) {
        e = cast(CursorEventRec*) calloc(1, CursorEventRec.sizeof);
        if (!e)
            return BadAlloc;

        e.pClient = pClient;
        e.pWindow = pWindow;
        e.clientResource = FakeClientID(pClient.index);

        /*
         * Add a resource hanging from the window to
         * catch window destroy
         */
        rc = dixLookupResourceByType(&val, pWindow.drawable.id,
                                     CursorWindowType, serverClient,
                                     DixGetAttrAccess);
        if (rc != Success)
            if (!AddResource(cast(uint)pWindow.drawable.id, CursorWindowType,
                             cast(void*) pWindow)) {
                free(e);
                return BadAlloc;
            }

        if (!AddResource(cast(uint)e.clientResource, CursorClientType, cast(void*) e))
            return BadAlloc;

        *prev = e;
    }
    e.eventMask = eventMask;
    return Success;
}

int ProcXFixesSelectCursorInput(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesSelectCursorInputReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"eventMask");

    WindowPtr pWin = void;
    int rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    if (stuff.eventMask & ~CursorAllEvents) {
        client.errorValue = cast(uint)stuff.eventMask;
        return BadValue;
    }
    return XFixesSelectCursorInput(client, pWin, stuff.eventMask);
}

private int GetBit(ubyte* line, int x)
{
    ubyte mask = void;

    if (screenInfo.bitmapBitOrder == LSBFirst)
        mask = (1 << (x & 7));
    else
        mask = (0x80 >> (x & 7));
    /* XXX assumes byte order is host byte order */
    line += (x >> 3);
    if (*line & mask)
        return 1;
    return 0;
}

void SXFixesCursorNotifyEvent(xXFixesCursorNotifyEvent* from, xXFixesCursorNotifyEvent* to)
{
    to.type = from.type;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.window, to.window);
    cpswapl(from.cursorSerial, to.cursorSerial);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.name, to.name);
}

private void CopyCursorToImage(CursorPtr pCursor, CARD32* image)
{
    int width = pCursor.bits.width;
    int height = pCursor.bits.height;
    int npixels = width * height;

    if (pCursor.bits.argb)
        memcpy(image, pCursor.bits.argb, npixels * CARD32.sizeof);
    else
    {
        ubyte* srcLine = pCursor.bits.source;
        ubyte* mskLine = pCursor.bits.mask;
        int stride = mixin(BitmapBytePad!("width"));
        int x = void, y = void;
        CARD32 fg = void, bg = void;

        fg = (0xff000000 |
              ((pCursor.foreRed & 0xff00) << 8) |
              (pCursor.foreGreen & 0xff00) | (pCursor.foreBlue >> 8));
        bg = (0xff000000 |
              ((pCursor.backRed & 0xff00) << 8) |
              (pCursor.backGreen & 0xff00) | (pCursor.backBlue >> 8));
        for (y = 0; y < height; y++) {
            for (x = 0; x < width; x++) {
                if (GetBit(mskLine, x)) {
                    if (GetBit(srcLine, x))
                        *image++ = fg;
                    else
                        *image++ = bg;
                }
                else
                    *image++ = 0;
            }
            srcLine += stride;
            mskLine += stride;
        }
    }
}

int ProcXFixesGetCursorImage(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesGetCursorImageReq);

    CursorPtr pCursor = CursorForClient(client);
    if (!pCursor)
        return BadCursor;
    int rc = XaceHookResourceAccess(client, pCursor.id, X11_RESTYPE_CURSOR,
                  pCursor, X11_RESTYPE_NONE, null, DixReadAccess);
    if (rc != Success)
        return rc;

    int x = void, y = void;
    GetSpritePosition(PickPointer(client), &x, &y);

    int width = pCursor.bits.width;
    int height = pCursor.bits.height;
    int npixels = width * height;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    CARD32* image = cast(CARD32*)x_rpcbuf_reserve(&rpcbuf, npixels * CARD32.sizeof);
    if (!image)
        return BadAlloc;

    CopyCursorToImage(pCursor, image);
    if (client.swapped)
        SwapLongs(image, npixels);

    xXFixesGetCursorImageReply reply = {
        width: cast(ushort)width,
        height: cast(ushort)height,
        x: cast(short)x,
        y: cast(short)y,
        xhot: pCursor.bits.xhot,
        yhot: pCursor.bits.yhot,
        cursorSerial: pCursor.serialNumber,
    };

    mixin(X_REPLY_FIELD_CARD16!"x");
    mixin(X_REPLY_FIELD_CARD16!"y");
    mixin(X_REPLY_FIELD_CARD16!"width");
    mixin(X_REPLY_FIELD_CARD16!"height");
    mixin(X_REPLY_FIELD_CARD16!"xhot");
    mixin(X_REPLY_FIELD_CARD16!"yhot");
    mixin(X_REPLY_FIELD_CARD32!"cursorSerial");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcXFixesSetCursorName(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXFixesSetCursorNameReq);
    mixin(X_REQUEST_FIELD_CARD32!"cursor");
    mixin(X_REQUEST_FIELD_CARD16!"nbytes");
    mixin(REQUEST_FIXED_SIZE!("xXFixesSetCursorNameReq", "stuff.nbytes"));

    CursorPtr pCursor = void;
    mixin(VERIFY_CURSOR!(`pCursor`, `stuff.cursor`, `client`, `DixSetAttrAccess`));
    char* tchar = cast(char*) &stuff[1];
    Atom atom = MakeAtom(tchar, stuff.nbytes, TRUE);
    if (atom == BAD_RESOURCE)
        return BadAlloc;

    pCursor.name = atom;
    return Success;
}

int ProcXFixesGetCursorName(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesGetCursorNameReq);
    mixin(X_REQUEST_FIELD_CARD32!"cursor");

    CursorPtr pCursor = void;
    mixin(VERIFY_CURSOR!(`pCursor`, `stuff.cursor`, `client`, `DixGetAttrAccess`));

    const(char)* str = ((pCursor.name) ? NameForAtom(pCursor.name) : "");

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_string_pad(&rpcbuf, str);

    xXFixesGetCursorNameReply reply = {
        atom: cast(int)pCursor.name,
        nbytes: cast(ushort)strlen(str)
    };

    mixin(X_REPLY_FIELD_CARD32!"atom");
    mixin(X_REPLY_FIELD_CARD16!"nbytes");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcXFixesGetCursorImageAndName(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesGetCursorImageAndNameReq);

    CursorPtr pCursor = CursorForClient(client);
    if (!pCursor)
        return BadCursor;
    int rc = XaceHookResourceAccess(client, pCursor.id, X11_RESTYPE_CURSOR,
                  pCursor, X11_RESTYPE_NONE, null, DixReadAccess | DixGetAttrAccess);
    if (rc != Success)
        return rc;

    int x = void, y = void;
    GetSpritePosition(PickPointer(client), &x, &y);
    int width = pCursor.bits.width;
    int height = pCursor.bits.height;
    int npixels = width * height;

    const(char)* name = pCursor.name ? NameForAtom(pCursor.name) : "";

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    CARD32* image = cast(uint*)x_rpcbuf_reserve(&rpcbuf, npixels * CARD32.sizeof);
    if (!image)
        return BadAlloc;

    CopyCursorToImage(pCursor, image);
    if (client.swapped)
        SwapLongs(image, npixels);

    x_rpcbuf_write_string_pad(&rpcbuf, name);

    if (rpcbuf.error)
        return BadAlloc;

    xXFixesGetCursorImageAndNameReply reply = {
        width: cast(ushort)width,
        height: cast(ushort)height,
        x: cast(short)x,
        y: cast(short)y,
        xhot: pCursor.bits.xhot,
        yhot: pCursor.bits.yhot,
        cursorSerial: pCursor.serialNumber,
        cursorName: cast(uint)pCursor.name,
        nbytes: cast(ushort)strlen(name),
    };

    mixin(X_REPLY_FIELD_CARD16!"x");
    mixin(X_REPLY_FIELD_CARD16!"y");
    mixin(X_REPLY_FIELD_CARD16!"width");
    mixin(X_REPLY_FIELD_CARD16!"height");
    mixin(X_REPLY_FIELD_CARD16!"xhot");
    mixin(X_REPLY_FIELD_CARD16!"yhot");
    mixin(X_REPLY_FIELD_CARD32!"cursorSerial");
    mixin(X_REPLY_FIELD_CARD32!"cursorName");
    mixin(X_REPLY_FIELD_CARD16!"nbytes");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/*
 * Find every cursor reference in the system, ask testCursor
 * whether it should be replaced with a reference to pCursor.
 */

alias TestCursorFunc = Bool function(CursorPtr pOld, void* closure);

struct _ReplaceCursorLookupRec {
    RESTYPE type;
    TestCursorFunc testCursor;
    CursorPtr pNew;
    void* closure;
}alias ReplaceCursorLookupRec = _ReplaceCursorLookupRec;
alias ReplaceCursorLookupPtr = ReplaceCursorLookupRec*;

private const(RESTYPE)[3] CursorRestypes = [
    X11_RESTYPE_WINDOW,
    X11_RESTYPE_PASSIVEGRAB,
    X11_RESTYPE_CURSOR
];

private Bool ReplaceCursorLookup(void* value, XID id, void* closure)
{
    ReplaceCursorLookupPtr rcl = cast(ReplaceCursorLookupPtr) closure;
    CursorPtr pCursor = null; CursorPtr* pCursorRef = null;
    XID cursor = 0;

    switch (rcl.type) {
    case X11_RESTYPE_WINDOW:
    {
        WindowPtr pWin = cast(WindowPtr) value;
        if (pWin.optional) {
            pCursorRef = &pWin.optional.cursor;
            pCursor = *pCursorRef;
        }
        break;
    }
    case X11_RESTYPE_PASSIVEGRAB:
    {
        GrabPtr pGrab = cast(GrabPtr) value;
        pCursorRef = &pGrab.cursor;
        pCursor = *pCursorRef;
        break;
    }
    case X11_RESTYPE_CURSOR:
        pCursorRef = null;
        pCursor = cast(CursorPtr) value;
        cursor = id;
        break;
    default: break;}
    if (pCursor && pCursor != rcl.pNew) {
        if ((*rcl.testCursor) (pCursor, rcl.closure)) {
            CursorPtr curs = RefCursor(rcl.pNew);
            /* either redirect reference or update resource database */
            if (pCursorRef)
                *pCursorRef = curs;
            else
                ChangeResourceValue(id, X11_RESTYPE_CURSOR, curs);
            FreeCursor(pCursor, cursor);
        }
    }
    return FALSE;               /* keep walking */
}

private void ReplaceCursor(CursorPtr pCursor, TestCursorFunc testCursor, void* closure)
{
    int clientIndex = void;
    int resIndex = void;
    ReplaceCursorLookupRec rcl = void;

    /*
     * Cursors exist only in the resource database, windows and grabs.
     * All of these are always pointed at by the resource database.  Walk
     * the whole thing looking for cursors
     */
    rcl.testCursor = testCursor;
    rcl.pNew = pCursor;
    rcl.closure = closure;

    /* for each client */
    for (clientIndex = 0; clientIndex < currentMaxClients; clientIndex++) {
        if (!clients[clientIndex])
            continue;
        for (resIndex = 0; resIndex < mixin(ARRAY_SIZE!("CursorRestypes")); resIndex++) {
            rcl.type = CursorRestypes[resIndex];
            /*
             * This function walks the entire client resource database
             */
            LookupClientResourceComplex(clients[clientIndex],
                                        rcl.type,
                                        &ReplaceCursorLookup, cast(void*) &rcl);
        }
    }
    /* this "knows" that WindowHasNewCursor doesn't depend on its argument */
    WindowHasNewCursor(dixGetMasterScreen().root);
}

private Bool TestForCursor(CursorPtr pCursor, void* closure)
{
    return (pCursor == cast(CursorPtr) closure);
}

int ProcXFixesChangeCursor(ClientPtr client)
{
    CursorPtr pSource = void, pDestination = void;

    mixin(X_REQUEST_HEAD_STRUCT!xXFixesChangeCursorReq);
    mixin(X_REQUEST_FIELD_CARD32!"source");
    mixin(X_REQUEST_FIELD_CARD32!"destination");

    mixin(VERIFY_CURSOR!(`pSource`, `stuff.source`, `client`,
                  `DixReadAccess | DixGetAttrAccess`));
    mixin(VERIFY_CURSOR!(`pDestination`, `stuff.destination`, `client`,
                  `DixWriteAccess | DixSetAttrAccess`));

    ReplaceCursor(pSource, &TestForCursor, cast(void*) pDestination);
    return Success;
}

private Bool TestForCursorName(CursorPtr pCursor, void* closure)
{
    Atom* pName = cast(Atom*) closure;

    return pCursor.name == *pName;
}

int ProcXFixesChangeCursorByName(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXFixesChangeCursorByNameReq);
    mixin(X_REQUEST_FIELD_CARD32!"source");
    mixin(X_REQUEST_FIELD_CARD16!"nbytes");
    mixin(REQUEST_FIXED_SIZE!("xXFixesChangeCursorByNameReq", "stuff.nbytes"));

    CursorPtr pSource = void;
    Atom name = void;
    char* tchar = void;

    mixin(VERIFY_CURSOR!(`pSource`, `stuff.source`, `client`,
                  `DixReadAccess | DixGetAttrAccess`));
    tchar = cast(char*) &stuff[1];
    name = MakeAtom(tchar, stuff.nbytes, FALSE);
    if (name)
        ReplaceCursor(pSource, &TestForCursorName, &name);
    return Success;
}

/*
 * Routines for manipulating the per-screen hide counts list.
 * This list indicates which clients have requested cursor hiding
 * for that screen.
 */

/* Return the screen's hide-counts list element for the given client */
private CursorHideCountPtr findCursorHideCount(ClientPtr pClient, ScreenPtr pScreen)
{
    CursorScreenPtr cs = mixin(GetCursorScreen!(`pScreen`));
    CursorHideCountPtr pChc = void;

    for (pChc = cs.pCursorHideCounts; pChc !is null; pChc = pChc.pNext) {
        if (pChc.pClient == pClient) {
            return pChc;
        }
    }

    return null;
}

private int createCursorHideCount(ClientPtr pClient, ScreenPtr pScreen)
{
    CursorScreenPtr cs = mixin(GetCursorScreen!(`pScreen`));
    CursorHideCountPtr pChc = cast(CursorHideCountRec*) calloc(1, CursorHideCountRec.sizeof);
    if (pChc is null) {
        return BadAlloc;
    }
    pChc.pClient = pClient;
    pChc.pScreen = pScreen;
    pChc.hideCount = 1;
    pChc.resource = FakeClientID(pClient.index);
    pChc.pNext = cs.pCursorHideCounts;
    cs.pCursorHideCounts = pChc;

    /*
     * Create a resource for this element so it can be deleted
     * when the client goes away.
     */
    if (!AddResource(cast(uint)pChc.resource, CursorHideCountType, cast(void*) pChc))
        return BadAlloc;

    return Success;
}

/*
 * Delete the given hide-counts list element from its screen list.
 */
private void deleteCursorHideCount(CursorHideCountPtr pChcToDel, ScreenPtr pScreen)
{
    CursorScreenPtr cs = mixin(GetCursorScreen!(`pScreen`));
    CursorHideCountPtr pChc = void, pNext = void;
    CursorHideCountPtr pChcLast = null;

    pChc = cs.pCursorHideCounts;
    while (pChc !is null) {
        pNext = pChc.pNext;
        if (pChc == pChcToDel) {
            free(pChc);
            if (pChcLast is null) {
                cs.pCursorHideCounts = pNext;
            }
            else {
                pChcLast.pNext = pNext;
            }
            return;
        }
        pChcLast = pChc;
        pChc = pNext;
    }
}

/*
 * Delete all the hide-counts list elements for this screen.
 */
private void deleteCursorHideCountsForScreen(ScreenPtr pScreen)
{
    CursorScreenPtr cs = mixin(GetCursorScreen!(`pScreen`));
    CursorHideCountPtr pChc = void, pTmp = void;

    pChc = cs.pCursorHideCounts;
    while (pChc !is null) {
        pTmp = pChc.pNext;
        FreeResource(cast(uint)pChc.resource, 0);
        pChc = pTmp;
    }
    cs.pCursorHideCounts = null;
}

int ProcXFixesHideCursor(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesHideCursorReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    CursorHideCountPtr pChc = void;
    int ret = void;

    ret = dixLookupResourceByType(cast(void**) &pWin, stuff.window, X11_RESTYPE_WINDOW,
                                  client, DixGetAttrAccess);
    if (ret != Success) {
        client.errorValue = cast(uint)stuff.window;
        return ret;
    }

    /*
     * Has client hidden the cursor before on this screen?
     * If so, just increment the count.
     */

    pChc = findCursorHideCount(client, pWin.drawable.pScreen);
    if (pChc !is null) {
        pChc.hideCount++;
        return Success;
    }

    /*
     * This is the first time this client has hid the cursor
     * for this screen.
     */
    ret = dixCallScreenAccessCallback(client, pWin.drawable.pScreen, DixHideAccess);
    if (ret != Success)
        return ret;

    ret = createCursorHideCount(client, pWin.drawable.pScreen);

    if (ret == Success) {
        DeviceIntPtr dev = void;

        for (dev = inputInfo.devices; dev; dev = dev.next) {
            if (InputDevIsMaster(dev) && IsPointerDevice(dev))
                CursorDisplayCursor(dev, pWin.drawable.pScreen,
                                    CursorForDevice(dev));
        }
    }

    return ret;
}

int ProcXFixesShowCursor(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesShowCursorReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    WindowPtr pWin = void;
    CursorHideCountPtr pChc = void;
    int rc = void;

    rc = dixLookupResourceByType(cast(void**) &pWin, stuff.window, X11_RESTYPE_WINDOW,
                                 client, DixGetAttrAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.window;
        return rc;
    }

    /*
     * Has client hidden the cursor on this screen?
     * If not, generate an error.
     */
    pChc = findCursorHideCount(client, pWin.drawable.pScreen);
    if (pChc is null) {
        return BadMatch;
    }

    rc = dixCallScreenAccessCallback(client, pWin.drawable.pScreen, DixShowAccess);
    if (rc != Success)
        return rc;

    pChc.hideCount--;
    if (pChc.hideCount <= 0) {
        FreeResource(cast(uint)pChc.resource, 0);
    }

    return Success;
}

private int CursorFreeClient(void* data, XID id)
{
    CursorEventPtr old = cast(CursorEventPtr) data;
    CursorEventPtr* prev = void; CursorEventPtr e = void;

    for (prev = &cursorEvents; ((e = *prev) !is null); prev = &e.next) {
        if (e == old) {
            *prev = e.next;
            free(e);
            break;
        }
    }
    return 1;
}

private int CursorFreeHideCount(void* data, XID id)
{
    CursorHideCountPtr pChc = cast(CursorHideCountPtr) data;
    ScreenPtr pScreen = pChc.pScreen;
    DeviceIntPtr dev = void;

    deleteCursorHideCount(pChc, pChc.pScreen);
    for (dev = inputInfo.devices; dev; dev = dev.next) {
        if (InputDevIsMaster(dev) && IsPointerDevice(dev))
            CursorDisplayCursor(dev, pScreen, CursorForDevice(dev));
    }

    return 1;
}

private int CursorFreeWindow(void* data, XID id)
{
    WindowPtr pWindow = cast(WindowPtr) data;
    CursorEventPtr e = void, next = void;

    for (e = cursorEvents; e; e = next) {
        next = e.next;
        if (e.pWindow == pWindow) {
            FreeResource(cast(uint)e.clientResource, 0);
        }
    }
    return 1;
}

int ProcXFixesCreatePointerBarrier(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXFixesCreatePointerBarrierReq);

    mixin(X_REQUEST_FIELD_CARD16!"num_devices");
    mixin(X_REQUEST_FIELD_CARD32!"barrier");
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD16!"x1");
    mixin(X_REQUEST_FIELD_CARD16!"y1");
    mixin(X_REQUEST_FIELD_CARD16!"x2");
    mixin(X_REQUEST_FIELD_CARD16!"y2");
    mixin(X_REQUEST_FIELD_CARD32!"directions");
    mixin(X_REQUEST_REST_COUNT_CARD16!("stuff.num_devices"));

    mixin(LEGAL_NEW_RESOURCE!("stuff.barrier", "client"));

    return XICreatePointerBarrier(client, stuff);
}

int ProcXFixesDestroyPointerBarrier(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesDestroyPointerBarrierReq);
    mixin(X_REQUEST_FIELD_CARD32!"barrier");
    return XIDestroyPointerBarrier(client, stuff);
}

Bool XFixesCursorInit()
{
    if (party_like_its_1989)
        CursorVisible = EnableCursor;
    else
        CursorVisible = FALSE;

    if (!dixRegisterPrivateKey(&CursorScreenPrivateKeyRec, PRIVATE_SCREEN, CursorScreenRec.sizeof))
        return FALSE;

    mixin(DIX_FOR_EACH_SCREEN!q{
        CursorScreenPtr cs = mixin(GetCursorScreen!(`walkScreen`));
        dixScreenHookClose(walkScreen, &CursorScreenClose);
        mixin(Wrap!(`cs`, `walkScreen`, `DisplayCursor`, `&CursorDisplayCursor`));
        cs.pCursorHideCounts = null;
    });

    CursorClientType = CreateNewResourceType(&CursorFreeClient,
                                             "XFixesCursorClient");
    CursorHideCountType = CreateNewResourceType(&CursorFreeHideCount,
                                                "XFixesCursorHideCount");
    CursorWindowType = CreateNewResourceType(&CursorFreeWindow,
                                             "XFixesCursorWindow");

    return CursorClientType && CursorHideCountType && CursorWindowType;
}
