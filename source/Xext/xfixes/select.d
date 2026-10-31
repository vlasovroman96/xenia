module select;
@nogc nothrow:
extern(C): __gshared:
/*
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

import dix.dix_priv;
import dix.request_priv;
import dix.selection_priv;
import dix.dispatch;

import xfixes.xfixesint;
import Xext.xace;
import externs.X11.extensions.xfixesproto;
import externs.X11.extensions.xfixeswire;
import dix.events;

private RESTYPE SelectionClientType, SelectionWindowType;
private Bool SelectionCallbackRegistered = FALSE;

/*
 * There is a global list of windows selecting for selection events
 * on every selection.  This should be plenty efficient for the
 * expected usage, if it does become a problem, it should be easily
 * replaced with a hash table of some kind keyed off the selection atom
 */

alias SelectionEventPtr = _SelectionEvent*;

struct _SelectionEvent {
    SelectionEventPtr next;
    Selection* selection;
    CARD32 eventMask;
    ClientPtr pClient;
    WindowPtr pWindow;
    XID clientResource;
}

alias SelectionEventRec = _SelectionEvent;

private SelectionEventPtr selectionEvents;

private void XFixesSelectionCallback(CallbackListPtr* callbacks, void* data, void* args)
{
    SelectionEventPtr e = void;
    SelectionInfoRec* info = cast(SelectionInfoRec*) args;
    Selection* selection = info.selection;
    int subtype = void;
    CARD32 eventMask = void;

    switch (info.kind) {
    case SelectionSetOwner:
        subtype = cast(uint)XFixesSetSelectionOwnerNotify;
        eventMask = cast(uint)XFixesSetSelectionOwnerNotifyMask;
        break;
    case SelectionWindowDestroy:
        subtype = cast(uint)XFixesSelectionWindowDestroyNotify;
        eventMask = cast(uint)XFixesSelectionWindowDestroyNotifyMask;
        break;
    case SelectionClientClose:
        subtype = cast(uint)XFixesSelectionClientCloseNotify;
        eventMask = cast(uint)XFixesSelectionClientCloseNotifyMask;
        break;
    default:
        return;
    }
    UpdateCurrentTimeIf();
    for (e = selectionEvents; e; e = e.next) {
        if (e.selection == selection && (e.eventMask & eventMask)) {

            /* allow extensions to intercept */
            SelectionFilterParamRec param = {
                client: e.pClient,
                selection: selection.selection,
                owner: (subtype == XFixesSetSelectionOwnerNotify) ?
                            selection.window : 0,
                op: SELECTION_FILTER_NOTIFY,
            };
            CallCallbacks(&SelectionFilterCallback, &param);
            if (param.skip)
                continue;

            xXFixesSelectionNotifyEvent ev = {
                type: cast(ubyte)XFixesEventBase + XFixesSelectionNotify,
                subtype: cast(ubyte)subtype,
                window: cast(uint)e.pWindow.drawable.id,
                owner: cast(uint)param.owner,
                selection: cast(uint)param.selection,
                timestamp: currentTime.milliseconds,
                selectionTimestamp: selection.lastTimeChanged.milliseconds
            };
            WriteEventsToClient(e.pClient, 1, cast(xEvent*) &ev);
        }
    }
}

private Bool CheckSelectionCallback()
{
    if (selectionEvents) {
        if (!SelectionCallbackRegistered) {
            if (!AddCallback(&SelectionCallback, &XFixesSelectionCallback, null))
                return FALSE;
            SelectionCallbackRegistered = TRUE;
        }
    }
    else {
        if (SelectionCallbackRegistered) {
            DeleteCallback(&SelectionCallback, &XFixesSelectionCallback, null);
            SelectionCallbackRegistered = FALSE;
        }
    }
    return TRUE;
}

enum SelectionAllEvents = (XFixesSetSelectionOwnerNotifyMask |
			    XFixesSelectionWindowDestroyNotifyMask |
			    XFixesSelectionClientCloseNotifyMask);

int ProcXFixesSelectSelectionInput(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesSelectSelectionInputReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD32!"selection");
    mixin(X_REQUEST_FIELD_CARD32!"eventMask");

    /* allow extensions to intercept */
    SelectionFilterParamRec param = {
        client: client,
        selection: stuff.selection,
        owner: stuff.window,
        op: SELECTION_FILTER_LISTEN,
    };
    CallCallbacks(&SelectionFilterCallback, &param);
    if (param.skip) {
        if (param.status != Success)
            client.errorValue = cast(uint)param.selection;
        return param.status;
    }

    WindowPtr pWindow = void;
    int rc = dixLookupWindow(&pWindow, param.owner, param.client, DixGetAttrAccess);
    if (rc != Success)
        return rc;
    if (stuff.eventMask & ~SelectionAllEvents) {
        client.errorValue = cast(uint)stuff.eventMask;
        return BadValue;
    }

    void* val = void;
    SelectionEventPtr* prev = void; SelectionEventPtr e = void;
    Selection* selection = void;

    rc = dixLookupSelection(&selection, param.selection, param.client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    for (prev = &selectionEvents; ((e = *prev) !is null); prev = &e.next) {
        if (e.selection == selection &&
            e.pClient == param.client && e.pWindow == pWindow) {
            break;
        }
    }
    if (!stuff.eventMask) {
        if (e) {
            FreeResource(cast(uint)e.clientResource, 0);
        }
        return Success;
    }
    if (!e) {
        e = cast(SelectionEventRec*) calloc(1, SelectionEventRec.sizeof);
        if (!e)
            return BadAlloc;

        e.next = null;
        e.selection = selection;
        e.pClient = param.client;
        e.pWindow = pWindow;
        e.clientResource = FakeClientID(param.client.index);

        /*
         * Add a resource hanging from the window to
         * catch window destroy
         */
        rc = dixLookupResourceByType(&val, pWindow.drawable.id,
                                     SelectionWindowType, serverClient,
                                     DixGetAttrAccess);
        if (rc != Success)
            if (!AddResource(cast(uint)pWindow.drawable.id, SelectionWindowType,
                             cast(void*) pWindow)) {
                free(e);
                return BadAlloc;
            }

        if (!AddResource(cast(uint)e.clientResource, SelectionClientType, cast(void*) e))
            return BadAlloc;

        *prev = e;
        if (!CheckSelectionCallback()) {
            FreeResource(cast(uint)e.clientResource, 0);
            return BadAlloc;
        }
    }
    e.eventMask = stuff.eventMask;
    return Success;
}

void SXFixesSelectionNotifyEvent(xXFixesSelectionNotifyEvent* from, xXFixesSelectionNotifyEvent* to)
{
    to.type = from.type;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.window, to.window);
    cpswapl(from.owner, to.owner);
    cpswapl(from.selection, to.selection);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.selectionTimestamp, to.selectionTimestamp);
}

private int SelectionFreeClient(void* data, XID id)
{
    SelectionEventPtr old = cast(SelectionEventPtr) data;
    SelectionEventPtr* prev = void; SelectionEventPtr e = void;

    for (prev = &selectionEvents; ((e = *prev) !is null); prev = &e.next) {
        if (e == old) {
            *prev = e.next;
            free(e);
            CheckSelectionCallback();
            break;
        }
    }
    return 1;
}

private int SelectionFreeWindow(void* data, XID id)
{
    WindowPtr pWindow = cast(WindowPtr) data;
    SelectionEventPtr e = void, next = void;

    for (e = selectionEvents; e; e = next) {
        next = e.next;
        if (e.pWindow == pWindow) {
            FreeResource(cast(uint)e.clientResource, 0);
        }
    }
    return 1;
}

Bool XFixesSelectionInit()
{
    SelectionClientType = CreateNewResourceType(&SelectionFreeClient,
                                                "XFixesSelectionClient");
    SelectionWindowType = CreateNewResourceType(&SelectionFreeWindow,
                                                "XFixesSelectionWindow");
    return SelectionClientType && SelectionWindowType;
}
