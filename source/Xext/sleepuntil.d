module Xext.sleepuntil;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 *
Copyright 1992, 1998  The Open Group

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
 *
 * Author:  Keith Packard, MIT X Consortium
 */

/* dixsleep.c - implement millisecond timeouts for X clients */

import build.dix_config;

import Xext.sleepuntil;
//import x11.X;
//import x11.Xmd;
import common.misc;
import dix.window;
import dix.dixstruct_priv;
import dix.pixmap;
import dix.scrnintstr;
import dix.resource;
import os.WaitFor;
import os.utils;
import dix.dixutils;
import dix.timestamp;

struct _Sertafied {
    _Sertafied* next;
    TimeStamp revive;
    ClientPtr pClient;
    XID id;
    void function(ClientPtr, void*) @nogc nothrow notifyFunc;

    void* closure;
}alias SertafiedRec = _Sertafied;
alias SertafiedPtr = _Sertafied*;

private SertafiedPtr pending;
private RESTYPE SertafiedResType;
private Bool BlockHandlerRegistered;







int ClientSleepUntil(ClientPtr client, TimeStamp* revive, void function(ClientPtr, void*) @nogc nothrow notifyFunc, void* closure)
{
    SertafiedResType = CreateNewResourceType(&SertafiedDelete,
                                             "ClientSleep");
    if (!SertafiedResType)
        return FALSE;
    BlockHandlerRegistered = FALSE;

    SertafiedPtr pRequest = cast(SertafiedPtr)cast(SertafiedRec*) calloc(1, SertafiedRec.sizeof);
    if (!pRequest)
        return FALSE;
    pRequest.pClient = client;
    pRequest.revive = *revive;
    pRequest.id = FakeClientID(client.index);
    pRequest.closure = closure;
    if (!BlockHandlerRegistered) {
        if (!RegisterBlockAndWakeupHandlers(&SertafiedBlockHandler,
                                            &SertafiedWakeupHandler,
                                            cast(void*) 0)) {
            free(pRequest);
            return FALSE;
        }
        BlockHandlerRegistered = TRUE;
    }
    pRequest.notifyFunc = null;
    if (!AddResource(cast(uint)pRequest.id, SertafiedResType, cast(void*) pRequest))
        return FALSE;
    if (!notifyFunc)
        notifyFunc = &ClientAwaken;
    pRequest.notifyFunc = notifyFunc;
    /* Insert into time-ordered queue, with earliest activation time coming first. */

    SertafiedPtr walk = void, pPrev = null;
    for (walk = pending; walk; walk = walk.next) {
        if (CompareTimeStamps(walk.revive, *revive) == LATER)
            break;
        pPrev = walk;
    }
    if (pPrev)
        pPrev.next = pRequest;
    else
        pending = pRequest;
    pRequest.next = walk;
    IgnoreClient(client);
    return TRUE;
}

private void ClientAwaken(ClientPtr client, void* closure)
{
    AttendClient(client);
}

private int SertafiedDelete(void* value, XID id)
{
    SertafiedPtr pRequest = cast(SertafiedPtr) value;

    SertafiedPtr walk = void, pPrev = null;
    for (walk = pending; walk; pPrev = walk, walk = walk.next)
        if (walk == pRequest) {
            if (pPrev)
                pPrev.next = walk.next;
            else
                pending = walk.next;
            break;
        }
    if (pRequest.notifyFunc)
        (*pRequest.notifyFunc) (pRequest.pClient, pRequest.closure);
    free(pRequest);
    return TRUE;
}

private void SertafiedBlockHandler(void* data, void* wt)
{
    c_ulong delay = void;
    TimeStamp now = void;

    if (!pending)
        return;
    now.milliseconds = GetTimeInMillis();
    now.months = currentTime.months;
    if (cast(int) (now.milliseconds - currentTime.milliseconds) < 0)
        now.months++;

    SertafiedPtr walk = void, pNext = void;
    for (walk = pending; walk; walk = pNext) {
        pNext = walk.next;
        if (CompareTimeStamps(walk.revive, now) == LATER)
            break;
        FreeResource(cast(uint)walk.id, X11_RESTYPE_NONE);

        /* AttendClient() may have been called via the resource delete
         * function so a client may have input to be processed and so
         *  set delay to 0 to prevent blocking in WaitForSomething().
         */
        AdjustWaitForDelay(wt, 0);
    }

    if (pending) {
        delay = pending.revive.milliseconds - now.milliseconds;
        AdjustWaitForDelay(wt, cast(int)delay);
    }
}

private void SertafiedWakeupHandler(void* data, int i)
{
    TimeStamp now = void;

    now.milliseconds = GetTimeInMillis();
    now.months = currentTime.months;
    if (cast(int) (now.milliseconds - currentTime.milliseconds) < 0)
        now.months++;

    SertafiedPtr walk = void, pNext = void;
    for (walk = pending; walk; walk = pNext) {
        pNext = walk.next;
        if (CompareTimeStamps(walk.revive, now) == LATER)
            break;
        FreeResource(cast(uint)walk.id, X11_RESTYPE_NONE);
    }
    if (!pending) {
        RemoveBlockAndWakeupHandlers(&SertafiedBlockHandler,
                                     &SertafiedWakeupHandler, cast(void*) 0);
        BlockHandlerRegistered = FALSE;
    }
}
