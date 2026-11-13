module dix.dixutils;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************

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

******************************************************************/

/*

(c)Copyright 1988,1991 Adobe Systems Incorporated. All rights reserved.

Permission to use, copy, modify, distribute, and sublicense this software and its
documentation for any purpose and without fee is hereby granted, provided that
the above copyright notices appear in all copies and that both those copyright
notices and this permission notice appear in supporting documentation and that
the name of Adobe Systems Incorporated not be used in advertising or publicity
pertaining to distribution of the software without specific, written prior
permission.  No trademark license to use the Adobe trademarks is hereby
granted.  If the Adobe trademark "Display PostScript"(tm) is used to describe
this software, its functionality or for any other purpose, such use shall be
limited to a statement that this software works in conjunction with the Display
PostScript system.  Proper trademark attribution to reflect Adobe's ownership
of the trademark shall be given whenever any such reference to the Display
PostScript system is made.

ADOBE MAKES NO REPRESENTATIONS ABOUT THE SUITABILITY OF THE SOFTWARE FOR ANY
PURPOSE.  IT IS PROVIDED "AS IS" WITHOUT EXPRESS OR IMPLIED WARRANTY.  ADOBE
DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING ALL IMPLIED
WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NON-
INFRINGEMENT OF THIRD PARTY RIGHTS.  IN NO EVENT SHALL ADOBE BE LIABLE TO YOU
OR ANY OTHER PARTY FOR ANY SPECIAL, INDIRECT, OR CONSEQUENTIAL DAMAGES OR ANY
DAMAGES WHATSOEVER WHETHER IN AN ACTION OF CONTRACT,NEGLIGENCE, STRICT
LIABILITY OR ANY OTHER ACTION ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.  ADOBE WILL NOT PROVIDE ANY TRAINING OR OTHER
SUPPORT FOR THE SOFTWARE.

Adobe, PostScript, and Display PostScript are trademarks of Adobe Systems
Incorporated which may be registered in certain jurisdictions.

Author:  Adobe Systems Incorporated

*/

import build.dix_config;

//import x11.X;
//import x11.Xmd;

import dix.callback;
import dix.client_priv;
import dix.dix_priv;
import dix.resource_priv;
import dix.screenint_priv;

import dix.window;
import dix.dixstruct_priv;
import dix.pixmap;
import dix.gc;
import dix.scrnintstr;
import Xext.xace;
import externs.attrs;
import dix.timestamp;

/*
 * CompareTimeStamps returns -1, 0, or +1 depending on if the first
 * argument is less than, equal to or greater than the second argument.
 */

int CompareTimeStamps(TimeStamp a, TimeStamp b)
{
    if (a.months < b.months)
        return EARLIER;
    if (a.months > b.months)
        return LATER;
    if (a.milliseconds < b.milliseconds)
        return EARLIER;
    if (a.milliseconds > b.milliseconds)
        return LATER;
    return SAMETIME;
}

/*
 * convert client times to server TimeStamps
 */

enum ulong HALFMONTH = 1<<31;
TimeStamp ClientTimeToServerTime(CARD32 c)
{
    TimeStamp ts = void;

    if (c == CurrentTime)
        return currentTime;
    ts.months = currentTime.months;
    ts.milliseconds = c;
    if (c > currentTime.milliseconds) {
        if ((cast(c_ulong) c - currentTime.milliseconds) > HALFMONTH)
            ts.months -= 1;
    }
    else if (c < currentTime.milliseconds) {
        if ((cast(c_ulong) currentTime.milliseconds - c) > HALFMONTH)
            ts.months += 1;
    }
    return ts;
}

/*
 * dixLookupWindow and dixLookupDrawable:
 * Look up the window/drawable taking into account the client doing the
 * lookup, the type of drawable desired, and the type of access desired.
 * Return Success with *pDraw set if the window/drawable exists and the client
 * is allowed access, else return an error code with *pDraw set to NULL.  The
 * access mask values are defined in resource.h.  The type mask values are
 * defined in pixmap.h, with zero equivalent to M_DRAWABLE.
 */
int dixLookupDrawable(DrawablePtr* pDraw, XID id, ClientPtr client, Mask type, Mask access)
{
    DrawablePtr pTmp = void;
    int rc = void;

    *pDraw = null;

    rc = dixLookupResourceByClass(cast(void**) &pTmp, id, RC_DRAWABLE, client,
                                  access);

    if (rc != Success)
        client.errorValue = cast(uint)id;

    if (rc == BadValue)
        return BadDrawable;
    if (rc != Success)
        return rc;
    if (!((1 << pTmp.type) & (type ? type : M_DRAWABLE)))
        return BadMatch;

    *pDraw = pTmp;
    return Success;
}

int dixLookupWindow(WindowPtr* pWin, XID id, ClientPtr client, Mask access)
{
    int rc = void;

    rc = dixLookupDrawable(cast(DrawablePtr*) pWin, id, client, M_WINDOW, access);
    /* dixLookupDrawable returns BadMatch iff id is a valid Drawable
       but is not a Window. Users of dixLookupWindow expect a BadWindow
       error in this case; they don't care that it's a valid non-Window XID */
    if (rc == BadMatch)
        rc = BadWindow;
    /* Similarly, users of dixLookupWindow don't want BadDrawable. */
    if (rc == BadDrawable)
        rc = BadWindow;
    return rc;
}

int dixLookupGC(GCPtr* pGC, XID id, ClientPtr client, Mask access)
{
    return dixLookupResourceByType(cast(void**) pGC, id, X11_RESTYPE_GC, client, access);
}

int dixLookupFontable(FontPtr* pFont, XID id, ClientPtr client, Mask access)
{
    int rc = void;
    GCPtr pGC = void;

    client.errorValue = cast(uint)id;    /* EITHER font or gc */
    rc = dixLookupResourceByType(cast(void**) pFont, id, X11_RESTYPE_FONT, client,
                                 access);
    if (rc != BadFont)
        return rc;
    rc = dixLookupResourceByType(cast(void**) &pGC, id, X11_RESTYPE_GC, client, access);
    if (rc == BadGC)
        return BadFont;
    if (rc == Success)
        *pFont = pGC.font;
    return rc;
}

int dixLookupResourceOwner(ClientPtr* result, XID id, ClientPtr client, Mask access_mode)
{
    void* pRes = void;
    int rc = BadValue, clientIndex = dixClientIdForXID(id);

    if (!clientIndex || !clients[clientIndex] || (id & SERVER_BIT))
        goto bad;

    rc = dixLookupResourceByClass(&pRes, id, RC_ANY, client, DixGetAttrAccess);
    if (rc != Success)
        goto bad;

    rc = dixCallClientAccessCallback(client, clients[clientIndex], access_mode);
    if (rc != Success)
        goto bad;

    *result = clients[clientIndex];
    return Success;
 bad:
    if (client)
        client.errorValue = cast(uint)id;
    *result = null;
    return rc;
}

int AlterSaveSetForClient(ClientPtr client, WindowPtr pWin, uint mode, Bool toRoot, Bool map)
{
    uint numnow = void;
    SaveSetElt* pTmp = null;
    int j = void;

    numnow = client.numSaved;
    j = 0;
    if (numnow) {
        pTmp = client.saveSet;
        while ((j < numnow) && (mixin(SaveSetWindow!("pTmp[j]")) != cast(void*) pWin))
            j++;
    }
    if (mode == SetModeInsert) {
        if (j < numnow)         /* duplicate */
            return Success;
        numnow++;
        pTmp = cast(SaveSetElt*) realloc(client.saveSet, ((*pTmp).sizeof * numnow));
        if (!pTmp)
            return BadAlloc;
        client.saveSet = pTmp;
        client.numSaved = numnow;
        mixin(SaveSetAssignWindow!("client.saveSet[numnow - 1]", "pWin"));
        mixin(SaveSetAssignToRoot!("client.saveSet[numnow - 1]", "toRoot"));
        mixin(SaveSetAssignMap!("client.saveSet[numnow - 1]", "map"));
        return Success;
    }
    else if ((mode == SetModeDelete) && (j < numnow)) {
        while (j < numnow - 1) {
            pTmp[j] = pTmp[j + 1];
            j++;
        }
        numnow--;
        if (numnow) {
            pTmp =
                cast(SaveSetElt*) realloc(client.saveSet, ((*pTmp).sizeof * numnow));
            if (pTmp)
                client.saveSet = pTmp;
        }
        else {
            free(client.saveSet);
            client.saveSet = cast(SaveSetElt*) null;
        }
        client.numSaved = numnow;
        return Success;
    }
    return Success;
}

void DeleteWindowFromAnySaveSet(WindowPtr pWin)
{
    ClientPtr client = void;

    for (int i = 0; i < currentMaxClients; i++) {
        client = clients[i];
        if (client && client.numSaved)
            cast(void) AlterSaveSetForClient(client, pWin, SetModeDelete, False,
                                         True);
    }
}

/* No-op Don't Do Anything : sometimes we need to be able to call a procedure
 * that doesn't do anything.  For example, on screen with only static
 * colormaps, if someone calls install colormap, it's easier to have a dummy
 * procedure to call than to check if there's a procedure
 */
extern(C) void NoopDDA() @nogc nothrow
{
}

struct _BlockHandler {
    ServerBlockHandlerProcPtr BlockHandler;
    ServerWakeupHandlerProcPtr WakeupHandler;
    void* blockData;
    Bool deleted;
}alias BlockHandlerRec = _BlockHandler;
alias BlockHandlerPtr = _BlockHandler*;

private BlockHandlerPtr handlers;
private size_t numHandlers;
private size_t sizeHandlers;
private Bool inHandler;
private Bool handlerDeleted;

/**
 *
 *  \param pTimeout   DIX doesn't want to know how OS represents time
 */
void BlockHandler(void* pTimeout)
{
    ++inHandler;
    for (size_t i = 0; i < numHandlers; i++)
        if (!handlers[i].deleted)
            (*handlers[i].BlockHandler) (handlers[i].blockData, pTimeout);

    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        if (walkScreen.BlockHandler)
            walkScreen.BlockHandler(walkScreen, pTimeout);
    }"));

    mixin(DIX_FOR_EACH_SCREEN!("{
        if (walkScreen.BlockHandler)
            walkScreen.BlockHandler(walkScreen, pTimeout);
    }"));

    if (handlerDeleted) {
        for (size_t i = 0; i < numHandlers;)
            if (handlers[i].deleted) {
                for (size_t j = i; j < numHandlers - 1; j++)
                    handlers[j] = handlers[j + 1];
                numHandlers--;
            }
            else
                i++;
        handlerDeleted = False;
    }
    --inHandler;
}

/**
 *
 *  \param result    32 bits of undefined result from the wait
 *  \param pReadmask the resulting descriptor mask
 */
void WakeupHandler(int result)
{
    ++inHandler;

    mixin(DIX_FOR_EACH_SCREEN!("{
        if (walkScreen.WakeupHandler)
            walkScreen.WakeupHandler(walkScreen, result);
    }"));

    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        if (walkScreen.WakeupHandler)
            walkScreen.WakeupHandler(walkScreen, result);
    }"));

    for (size_t i = numHandlers; i > 0; i--)
        if (!handlers[i-1].deleted)
            handlers[i-1].WakeupHandler(handlers[i-1].blockData, result);
    if (handlerDeleted) {
        for (size_t i = 0; i < numHandlers;)
            if (handlers[i].deleted) {
                for (size_t j = i; j < numHandlers - 1; j++)
                    handlers[j] = handlers[j + 1];
                numHandlers--;
            }
            else
                i++;
        handlerDeleted = False;
    }
    --inHandler;
}

/**
 * Reentrant with BlockHandler and WakeupHandler, except wakeup won't
 * get called until next time
 */
Bool RegisterBlockAndWakeupHandlers(ServerBlockHandlerProcPtr blockHandler, ServerWakeupHandlerProcPtr wakeupHandler, void* blockData)
{
    BlockHandlerPtr new_ = void;

    if (numHandlers >= sizeHandlers) {
        new_ = cast(BlockHandlerPtr) realloc(handlers, (numHandlers + 1) *
                                        BlockHandlerRec.sizeof);
        if (!new_)
            return False;
        handlers = new_;
        sizeHandlers = numHandlers + 1;
    }
    handlers[numHandlers].BlockHandler = blockHandler;
    handlers[numHandlers].WakeupHandler = wakeupHandler;
    handlers[numHandlers].blockData = blockData;
    handlers[numHandlers].deleted = False;
    numHandlers = numHandlers + 1;
    return True;
}

void RemoveBlockAndWakeupHandlers(ServerBlockHandlerProcPtr blockHandler, ServerWakeupHandlerProcPtr wakeupHandler, void* blockData)
{
    for (size_t i = 0; i < numHandlers; i++)
        if (handlers[i].BlockHandler == blockHandler &&
            handlers[i].WakeupHandler == wakeupHandler &&
            handlers[i].blockData == blockData) {
            if (inHandler) {
                handlerDeleted = True;
                handlers[i].deleted = True;
            }
            else {
                for (; i < numHandlers - 1; i++)
                    handlers[i] = handlers[i + 1];
                numHandlers--;
            }
            break;
        }
}

void InitBlockAndWakeupHandlers()
{
    free(handlers);
    handlers = cast(BlockHandlerPtr) 0;
    numHandlers = 0;
    sizeHandlers = 0;
}

/*
 * A general work queue.  Perform some task before the server
 * sleeps for input.
 */

struct _WorkQueue {
    _WorkQueue* next;
    Bool function(ClientPtr pClient, void* closure) function_;
    ClientPtr client;
    void* closure;
}alias WorkQueuePtr = _WorkQueue*;

WorkQueuePtr workQueue;
private WorkQueuePtr* workQueueLast = &workQueue;

void ClearWorkQueue()
{
    WorkQueuePtr q = void; WorkQueuePtr* p = void;

    p = &workQueue;
    while ((q = *p) !is null) {
        *p = q.next;
        free(q);
    }
    workQueueLast = p;
}

void ProcessWorkQueue()
{
    WorkQueuePtr q = void; WorkQueuePtr* p = void;

    // don't have a work queue yet
    if (!workQueue)
        return;

    p = &workQueue;
    /*
     * Scan the work queue once, calling each function.  Those
     * which return True are removed from the queue, otherwise
     * they will be called again.  This must be reentrant with
     * QueueWorkProc.
     */
    while ((q = *p) !is null) {
        if (assumeNoGC(q.function_) (q.client, q.closure)) {
            /* remove q from the list */
            *p = q.next;       /* don't fetch until after func called */
            free(q);
        }
        else {
            p = &q.next;       /* don't fetch until after func called */
        }
    }
    workQueueLast = p;
}

void ProcessWorkQueueZombies()
{
    WorkQueuePtr q = void; WorkQueuePtr* p = void;

    p = &workQueue;
    while ((q = *p) !is null) {
        if (q.client && q.client.clientGone) {
            assumeNoGC(q.function_) (q.client, q.closure);
            /* remove q from the list */
            *p = q.next;       /* don't fetch until after func called */
            free(q);
        }
        else {
            p = &q.next;       /* don't fetch until after func called */
        }
    }
    workQueueLast = p;
}

Bool QueueWorkProc(Bool function(ClientPtr pClient, void* closure) function_, ClientPtr client, void* closure)
{
    WorkQueuePtr q = cast(WorkQueuePtr) calloc(1, _WorkQueue.sizeof);
    if (!q)
        return False;
    q.function_ = function_;
    q.client = client;
    q.closure = closure;
    q.next = null;
    *workQueueLast = q;
    workQueueLast = &q.next;
    return True;
}

/*
 * Manage a queue of sleeping clients, awakening them
 * when requested, by using the OS functions IgnoreClient
 * and AttendClient.  Note that this *ignores* the troubles
 * with request data interleaving itself with events, but
 * we'll leave that until a later time.
 */

struct _SleepQueue {
    _SleepQueue* next;
    ClientPtr client;
    ClientSleepProcPtr function_;
    void* closure;
}alias SleepQueueRec = _SleepQueue;
alias SleepQueuePtr = _SleepQueue*;

private SleepQueuePtr sleepQueue = null;

Bool ClientSleep(ClientPtr client, ClientSleepProcPtr function_, void* closure)
{
    SleepQueuePtr q = cast(SleepQueuePtr) calloc(1, _SleepQueue.sizeof);
    if (!q)
        return False;

    IgnoreClient(client);
    q.next = sleepQueue;
    q.client = client;
    q.function_ = function_;
    q.closure = closure;
    sleepQueue = q;
    return True;
}

Bool dixClientSignal(ClientPtr client)
{
    for (SleepQueuePtr q = sleepQueue; q; q = q.next)
        if (q.client == client) {
            return QueueWorkProc(q.function_, q.client, q.closure);
        }
    return False;
}

int ClientSignalAll(ClientPtr client, ClientSleepProcPtr function_, void* closure)
{
    int count = 0;

    for (SleepQueuePtr q = sleepQueue; q; q = q.next) {
        if (!(client == CLIENT_SIGNAL_ANY || q.client == client))
            continue;

        if (!(function_ == CLIENT_SIGNAL_ANY || q.function_ == function_))
            continue;

        if (!(closure == CLIENT_SIGNAL_ANY || q.closure == closure))
            continue;

        count += QueueWorkProc(q.function_, q.client, q.closure);
    }

    return count;
}

void ClientWakeup(ClientPtr client)
{
    SleepQueuePtr q = void; SleepQueuePtr* prev = void;

    prev = &sleepQueue;
    while ((q = *prev) !is null) {
        if (q.client == client) {
            *prev = q.next;
            free(q);
            AttendClient(client);
            break;
        }
        prev = &q.next;
    }
}

Bool ClientIsAsleep(ClientPtr client)
{
    for (SleepQueuePtr q = sleepQueue; q; q = q.next)
        if (q.client == client)
            return True;
    return False;
}


/**
 * Coordinates the global GL context used by modules in the X Server
 * doing rendering with OpenGL.
 *
 * When setting a GL context (glXMakeCurrent() or eglMakeCurrent()),
 * there is an expensive implied glFlush() required by the GLX and EGL
 * APIs, so modules don't want to have to do it on every request.  But
 * the individual modules using GL also don't know about each other,
 * so they have to coordinate who owns the current context.
 *
 * When you're about to do a MakeCurrent, you should set this variable
 * to your context's address, and you can skip MakeCurrent if it's
 * already set to yours.
 *
 * When you're about to do a DestroyContext, you should set this to
 * NULL if it's set to your context.
 *
 * When you're about to do an unbindContext on a DRI driver, you
 * should set this to NULL.  Despite the unbindContext interface
 * sounding like it only unbinds the passed in context, it actually
 * unconditionally clears the dispatch table even if the given
 * context wasn't current.
 */
void* lastGLContext = null;
