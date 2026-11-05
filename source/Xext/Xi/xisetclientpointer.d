module Xi.xisetclientpointer;
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
 * Request to set the client pointer for the owner of the given window.
 * All subsequent calls that are ambiguous will choose the client pointer as
 * default value.
 */

import build.dix_config;

//import x11.X;              /* for inputstr.h    */
//import x11.Xproto;         /* Request macro     */
import externs.X11.extensions.XI;
import externs.X11.extensions.XI2proto;

import dix.dix_priv;
import dix.request_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structure  */
import dix.scrnintstr;         /* screen structure  */
import dix.extension;
import Xi.exevents;
import Xi.exglobals;
import dix.devices;
import dix.dixutils;
import dix.events;

int ProcXISetClientPointer(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXISetClientPointerReq);
    mixin(X_REQUEST_FIELD_CARD32!"win");
    mixin(X_REQUEST_FIELD_CARD16!"deviceid");

    DeviceIntPtr pDev = void;
    ClientPtr targetClient = void;
    int rc = void;

    rc = dixLookupDevice(&pDev, stuff.deviceid, client, DixManageAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.deviceid;
        return rc;
    }

    if (!InputDevIsMaster(pDev)) {
        client.errorValue = cast(uint)stuff.deviceid;
        return BadDevice;
    }

    pDev = GetMaster(pDev, MASTER_POINTER);

    if (stuff.win != None) {
        rc = dixLookupResourceOwner(&targetClient, stuff.win, client,
                             DixManageAccess);

        if (rc != Success)
            return BadWindow;

    }
    else
        targetClient = client;

    rc = SetClientPointer(targetClient, pDev);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.deviceid;
        return rc;
    }

    return Success;
}
