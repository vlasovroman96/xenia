module Xi.xichangecursor;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2007-2008 Peter Hutterer
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
 * Author: Peter Hutterer, University of South Australia, NICTA
 */

/***********************************************************************
 *
 * Request to change a given device pointer's cursor.
 *
 */

import build.dix_config;

//import x11.X;              /* for inputstr.h    */
//import x11.Xproto;         /* Request macro     */
//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XI2proto;

import dix.cursor_priv;
import dix.dix_priv;
import dix.request_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import include.windowstr;          /* window structure  */
import dix.scrnintstr;         /* screen structure  */
import dix.extension;
import Xi.exevents;
import Xi.exglobals;
import dix.input;
import externs.X11.extensions.XI2proto;
import dix.devices;
import dix.dixutils;
import dix.events;
import dix.window;

/***********************************************************************
 *
 * This procedure allows a client to set one pointer's cursor.
 *
 */

int ProcXIChangeCursor(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXIChangeCursorReq);
    mixin(X_REQUEST_FIELD_CARD32!"win");
    mixin(X_REQUEST_FIELD_CARD32!"cursor");
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");

    int rc = void;
    WindowPtr pWin = null;
    DeviceIntPtr pDev = null;
    CursorPtr pCursor = null;

    rc = dixLookupDevice(&pDev, stuff.deviceid, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;

    if (!InputDevIsMaster(pDev) || !IsPointerDevice(pDev))
        return BadDevice;

    if (stuff.win != None) {
        rc = dixLookupWindow(&pWin, stuff.win, client, DixSetAttrAccess);
        if (rc != Success)
            return rc;
    }

    if (stuff.cursor == None) {
        if (pWin == pWin.drawable.pScreen.root)
            pCursor = rootCursor;
        else
            pCursor = cast(CursorPtr) None;
    }
    else {
        rc = dixLookupResourceByType(cast(void**) &pCursor, stuff.cursor,
                                     X11_RESTYPE_CURSOR, client, DixUseAccess);
        if (rc != Success)
            return rc;
    }

    ChangeWindowDeviceCursor(pWin, pDev, pCursor);

    return Success;
}
