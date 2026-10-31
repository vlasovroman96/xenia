module dix.selection;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Copyright 1987, 1989, 1998  The Open Group

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

Copyright 1987, 1989 by Digital Equipment Corporation, Maynard, Massachusetts.

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

import dix.dix_priv;
import dix.request_priv;
import dix.selection_priv;

import include.windowstr;
import dix.dixstruct_priv;
import dix.dispatch;
import Xext.xace;
import dix.selection_priv;;
import os.io;
import dix.events;
import dix.timestamp;
import dix.atom;
/*****************************************************************
 * Selection Stuff
 *
 *    dixLookupSelection
 *
 *   Selections are global to the server.  The list of selections should
 *   not be traversed directly.  Instead, use the functions listed above.
 *
 *****************************************************************/

// Selection* CurrentSelections;
// CallbackListPtr SelectionCallback;
// CallbackListPtr SelectionFilterCallback = null;

int dixLookupSelection(Selection** result, Atom selectionName, ClientPtr client, Mask access_mode)
{
    Selection* pSel = void;
    int rc = BadMatch;

    client.errorValue = cast(uint)selectionName;

    for (pSel = CurrentSelections; pSel; pSel = pSel.next)
        if (pSel.selection == selectionName)
            break;

    if (!pSel) {
        pSel = mixin(dixAllocateObjectWithPrivates!("Selection", "PRIVATE_SELECTION"));
        if (!pSel)
            return BadAlloc;
        pSel.selection = selectionName;
        pSel.next = CurrentSelections;
        CurrentSelections = pSel;
    }

    /* security creation/labeling check */
    rc = XaceHookSelectionAccess(client, &pSel, access_mode | DixCreateAccess);
    if (rc != Success) {
        return rc;
    }

    *result = pSel;
    return rc;
}

void InitSelections()
{
    Selection* pSel = void, pNextSel = void;

    pSel = CurrentSelections;
    while (pSel) {
        pNextSel = pSel.next;
        mixin(dixFreeObjectWithPrivatesM!("pSel", "PRIVATE_SELECTION"));
        pSel = pNextSel;
    }

    CurrentSelections = null;
}

pragma(inline, true) private void CallSelectionCallback(Selection* pSel, ClientPtr client, SelectionCallbackKind kind)
{
    SelectionInfoRec info = { pSel, client, kind };
    CallCallbacks(&SelectionCallback, &info);
}

void DeleteWindowFromAnySelections(WindowPtr pWin)
{
    for (Selection* pSel = CurrentSelections; pSel; pSel = pSel.next)
        if (pSel.pWin == pWin) {
            CallSelectionCallback(pSel, null, SelectionWindowDestroy);

            pSel.pWin = cast(WindowPtr) null;
            pSel.window = None;
            pSel.client = null;
        }
}

void DeleteClientFromAnySelections(ClientPtr client)
{
    for (Selection* pSel = CurrentSelections; pSel; pSel = pSel.next)
        if (pSel.client == client) {
            CallSelectionCallback(pSel, null, SelectionClientClose);

            pSel.pWin = cast(WindowPtr) null;
            pSel.window = None;
            pSel.client = null;
        }
}

int ProcSetSelectionOwner(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSetSelectionOwnerReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"selection");
    mixin(X_REQUEST_FIELD_CARD32!"time");

    WindowPtr pWin = null;
    TimeStamp time = void;
    Selection* pSel = void;
    int rc = void;

    UpdateCurrentTime();
    time = ClientTimeToServerTime(stuff.time);

    /* If the client's time stamp is in the future relative to the server's
       time stamp, do not set the selection, just return success. */
    if (CompareTimeStamps(time, currentTime) == LATER)
        return Success;

    /* allow extensions to intercept */
    SelectionFilterParamRec param = {
        client: client,
        selection: stuff.selection,
        owner: stuff.window,
        op: SELECTION_FILTER_SETOWNER,
    };
    CallCallbacks(&SelectionFilterCallback, &param);
    if (param.skip) {
        if (param.status != Success)
            client.errorValue = cast(uint)stuff.selection;
        return param.status;
    }

    if (param.owner != None) {
        rc = dixLookupWindow(&pWin, param.owner, client, DixSetAttrAccess);
        if (rc != Success)
            return rc;
    }

    if (!ValidAtom(param.selection)) {
        client.errorValue = cast(uint)stuff.selection;
        return BadAtom;
    }

    /*
     * First, see if the selection is already set...
     */
    rc = dixLookupSelection(&pSel, param.selection, client, DixSetAttrAccess);
    if (rc != Success) {
        client.errorValue = cast(uint)stuff.selection;
        return rc;
    }

    /* If the timestamp in client's request is in the past relative
       to the time stamp indicating the last time the owner of the
       selection was set, do not set the selection, just return
       success. */
    if (CompareTimeStamps(time, pSel.lastTimeChanged) == EARLIER)
        return Success;
    if (pSel.client && (!pWin || (pSel.client != client))) {
        SelectionFilterParamRec eventParam = {
            client: client,
            recvClient: pSel.client,
            owner: pSel.window,
            selection: stuff.selection,
            op: SELECTION_FILTER_EV_CLEAR,
        };
        CallCallbacks(&SelectionFilterCallback, &eventParam);
        if (!param.skip) {
            xEvent event;
                event.u.selectionClear.time = time.milliseconds;
                event.u.selectionClear.window = cast(uint)eventParam.owner;
                event.u.selectionClear.atom = cast(uint)eventParam.selection;

            event.u.u.type = SelectionClear;
            WriteEventsToClient(eventParam.recvClient, 1, &event);
        }
    }

    pSel.lastTimeChanged = time;
    pSel.window = param.owner;
    pSel.pWin = pWin;
    pSel.client = (pWin ? client : null);

    CallSelectionCallback(pSel, client, SelectionSetOwner);
    return Success;
}

int ProcGetSelectionOwner(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xResourceReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    Selection* pSel = void;

    /* allow extensions to intercept */
    SelectionFilterParamRec param = {
        client: client,
        selection: stuff.id,
        op: SELECTION_FILTER_GETOWNER,
    };
    CallCallbacks(&SelectionFilterCallback, &param);
    xGetSelectionOwnerReply reply = { 0 };
    if (param.skip) {
        goto out_;
    }

    if (!ValidAtom(param.selection)) {
        param.status = BadAtom;
        goto out_;
    }


    param.status = dixLookupSelection(&pSel, param.selection, param.client, DixGetAttrAccess);
    if (param.status == Success)
        reply.owner = cast(uint)pSel.window;
    else if (param.status == BadMatch)
        reply.owner = None;
    else
        goto out_;

    if (client.swapped) {
        swapl(&reply.owner);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));

out_:
    if (param.status != Success)
        client.errorValue = cast(uint)stuff.id;
    return param.status;
}

int ProcConvertSelection(ClientPtr client)
{
    Bool paramsOkay = void;
    xEvent event = void;
    WindowPtr pWin = void;
    Selection* pSel = void;
    int rc = void;

    mixin(REQUEST!xConvertSelectionReq);
    mixin(REQUEST_AT_LEAST_SIZE!xConvertSelectionReq);

    /* allow extensions to intercept */
    SelectionFilterParamRec param = {
        client: client,
        selection: stuff.selection,
        op: SELECTION_FILTER_CONVERT,
        requestor: stuff.requestor,
        property: stuff.property,
        target: stuff.target,
        time: stuff.time,
    };
    CallCallbacks(&SelectionFilterCallback, &param);
    if (param.skip) {
        if (param.status != Success)
            client.errorValue = cast(uint)stuff.selection;
        return param.status;
    }

    rc = dixLookupWindow(&pWin, param.requestor, client, DixSetAttrAccess);
    if (rc != Success)
        return rc;

    paramsOkay = ValidAtom(param.selection) && ValidAtom(param.target);
    paramsOkay &= (param.property == None) || ValidAtom(param.property);
    if (!paramsOkay) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }

    if (stuff.time == CurrentTime)
        UpdateCurrentTime();

    rc = dixLookupSelection(&pSel, param.selection, client, DixReadAccess);

    memset(&event, 0, xEvent.sizeof);
    if (rc != Success && rc != BadMatch)
        return rc;

    /* If the specified selection has an owner, the X server sends
       SelectionRequest event to that owner */
    if (rc == Success && pSel.window != None && pSel.client &&
        pSel.client != serverClient && !pSel.client.clientGone)
    {
        SelectionFilterParamRec evParam = {
            client: client,
            selection: stuff.selection,
            op: SELECTION_FILTER_EV_REQUEST,
            owner: pSel.window,
            requestor: stuff.requestor,
            property: stuff.property,
            target: stuff.target,
            time: stuff.time,
            recvClient: pSel.client,
        };

        CallCallbacks(&SelectionFilterCallback, &evParam);
        if (evParam.skip) {
            if (evParam.status != Success)
                client.errorValue = cast(uint)stuff.selection;
            return evParam.status;
        }

        event.u.u.type = SelectionRequest;
        event.u.selectionRequest.owner = cast(uint)evParam.owner;
        event.u.selectionRequest.time = cast(uint)evParam.time;
        event.u.selectionRequest.requestor = cast(uint)evParam.requestor;
        event.u.selectionRequest.selection = cast(uint)evParam.selection;
        event.u.selectionRequest.target = cast(uint)evParam.target;
        event.u.selectionRequest.property = cast(uint)evParam.property;
        WriteEventsToClient(evParam.recvClient, 1, &event);
        return Success;
    }

    /* If no owner for the specified selection exists, the X server generates
       a SelectionNotify event to the requestor with property None. */
    param.property = None;
    CallCallbacks(&SelectionFilterCallback, &param);
    if (param.skip) {
        if (param.status != Success)
            client.errorValue = cast(uint)stuff.selection;
        return param.status;
    }

    event.u.u.type = SelectionNotify;
    event.u.selectionNotify.time = cast(uint)param.time;
    event.u.selectionNotify.requestor = cast(uint)param.requestor;
    event.u.selectionNotify.selection = cast(uint)param.selection;
    event.u.selectionNotify.target = cast(uint)param.target;
    event.u.selectionNotify.property = cast(uint)param.property;
    WriteEventsToClient(client, 1, &event);
    return Success;
}
