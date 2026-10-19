module Xext.sync;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1991, 1993, 1998  The Open Group

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

Copyright 1991, 1993 by Digital Equipment Corporation, Maynard, Massachusetts,
and Olivetti Research Limited, Cambridge, England.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the names of Digital or Olivetti
not be used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.  Digital and Olivetti
make no representations about the suitability of this software
for any purpose.  It is provided "as is" without express or implied warranty.

DIGITAL AND OLIVETTI DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS, IN NO EVENT SHALL THEY BE LIABLE FOR ANY SPECIAL, INDIRECT OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.

*/

import build.dix_config;

import core.stdc.string;
import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
//import x11.Xmd;
// //import externs.X11.extensions.syncproto;
import miext.sync.misyncfd;

import dix.dix_priv;
import dix.request_priv;
import dix.screenint_priv;
import include.syncsdk;
import miext.extinit_priv;
import os.bug_priv;
import os.osdep;

import include.scrnintstr;
import include.os;
import include.extnsionst;
import include.dixstruct;
import include.pixmapstr;
import include.resource;
import Xext.syncsrv;
import include.protocol_versions;
import include.inputstr;
import externs.X11.extensions.syncconst;
import externs.X11.extensions.syncproto;
import os.log;
import dix.dixutils;
import dix.extension;
import os.utils;
import os.WaitFor;
import dix.events;
import miext.sync.misync;
// import include.misync_priv;

/*
 * Local Global Variables
 */
private int SyncEventBase;
private int SyncErrorBase;
private RESTYPE RTCounter = 0;
private RESTYPE RTAwait;
private RESTYPE RTAlarm;
private RESTYPE RTAlarmClient;
private RESTYPE RTFence;
private xorg_list SysCounterList;
private int SyncNumInvalidCounterWarnings = 0;

enum MAX_INVALID_COUNTER_WARNINGS =	   5;

private const(char)* WARN_INVALID_COUNTER_COMPARE = "Warning: Non-counter XSync object using Counter-only\n"
    ~ "         comparison.  Result will never be true.\n";

private const(char)* WARN_INVALID_COUNTER_ALARM = "Warning: Non-counter XSync object used in alarm.  This is\n"
    ~ "         the result of a programming error in the X server.\n";

enum string IsSystemCounter(string pCounter) = `
    (` ~ pCounter ~ ` && (` ~ pCounter ~ `.sync.client is null))`;

/* these are all the alarm attributes that pertain to the alarm's trigger */
enum XSyncCAAllTrigger = 
    (XSyncCACounter | XSyncCAValueType | XSyncCAValue | XSyncCATestType);

// static void SyncComputeBracketValues(SyncCounter *);

// static void SyncInitServerTime();

// static void SyncInitIdleTime();

pragma(inline, true) private void* SysCounterGetPrivate(SyncCounter* counter)
{
    mixin(BUG_WARN!("!mixin(IsSystemCounter!(`counter`))"));

    return counter.pSysCounterInfo ? counter.pSysCounterInfo.private_ : null;
}

private Bool SyncCheckWarnIsCounter(const(SyncObject)* pSync, const(char)* warning)
{
    if (pSync && (SYNC_COUNTER != pSync.type)) {
        if (SyncNumInvalidCounterWarnings++ < MAX_INVALID_COUNTER_WARNINGS) {
            ErrorF("%s", warning);
            ErrorF("         Counter type: %d\n", pSync.type);
        }

        return FALSE;
    }

    return TRUE;
}

/*  Each counter maintains a simple linked list of triggers that are
 *  interested in the counter.  The two functions below are used to
 *  delete and add triggers on this list.
 */
void SyncDeleteTriggerFromSyncObject(SyncTrigger* pTrigger)
{
    SyncTriggerList* pCur = void;
    SyncTriggerList* pPrev = void;
    SyncCounter* pCounter = void;

    /* pSync needs to be stored in pTrigger before calling here. */

    if (!pTrigger.pSync)
        return;

    pPrev = null;
    pCur = pTrigger.pSync.pTriglist;

    while (pCur) {
        if (pCur.pTrigger == pTrigger) {
            if (pPrev)
                pPrev.next = pCur.next;
            else
                pTrigger.pSync.pTriglist = pCur.next;

            free(pCur);
            break;
        }

        pPrev = pCur;
        pCur = pCur.next;
    }

    if (SYNC_COUNTER == pTrigger.pSync.type) {
        pCounter = cast(SyncCounter*) pTrigger.pSync;

        if (mixin(IsSystemCounter!(`pCounter`)))
            SyncComputeBracketValues(pCounter);
    }
    else if (SYNC_FENCE == pTrigger.pSync.type) {
        SyncFence* pFence = cast(SyncFence*) pTrigger.pSync;

        pFence.funcs.DeleteTrigger(pTrigger);
    }
}

int SyncAddTriggerToSyncObject(SyncTrigger* pTrigger)
{
    SyncTriggerList* pCur = void;
    SyncCounter* pCounter = void;

    if (!pTrigger.pSync)
        return Success;

    /* don't do anything if it's already there */
    for (pCur = pTrigger.pSync.pTriglist; pCur; pCur = pCur.next) {
        if (pCur.pTrigger == pTrigger)
            return Success;
    }

    /* Failure is not an option, it's succeed or burst! */
    pCur = cast(SyncTriggerList*)XNFalloc(SyncTriggerList.sizeof);

    pCur.pTrigger = pTrigger;
    pCur.next = pTrigger.pSync.pTriglist;
    pTrigger.pSync.pTriglist = pCur;

    if (SYNC_COUNTER == pTrigger.pSync.type) {
        pCounter = cast(SyncCounter*) pTrigger.pSync;

        if (mixin(IsSystemCounter!(`pCounter`)))
            SyncComputeBracketValues(pCounter);
    }
    else if (SYNC_FENCE == pTrigger.pSync.type) {
        SyncFence* pFence = cast(SyncFence*) pTrigger.pSync;

        pFence.funcs.AddTrigger(pTrigger);
    }

    return Success;
}

/*  Below are five possible functions that can be plugged into
 *  pTrigger->CheckTrigger for counter sync objects, corresponding to
 *  the four possible test-types, and the one possible function that
 *  can be plugged into pTrigger->CheckTrigger for fence sync objects.
 *  These functions are called after the sync object's state changes
 *  but are also passed the old state so they can inspect both the old
 *  and new values.  (PositiveTransition and NegativeTransition need to
 *  see both pieces of information.)  These functions return the truth
 *  value of the trigger.
 *
 *  All of them include the condition pTrigger->pSync == NULL.
 *  This is because the spec says that a trigger with a sync value
 *  of None is always TRUE.
 */

private Bool SyncCheckTriggerPositiveComparison(SyncTrigger* pTrigger, long oldval)
{
    SyncCounter* pCounter = void;

    /* Non-counter sync objects should never get here because they
     * never trigger this comparison. */
    if (!SyncCheckWarnIsCounter(pTrigger.pSync, WARN_INVALID_COUNTER_COMPARE))
        return FALSE;

    pCounter = cast(SyncCounter*) pTrigger.pSync;

    return pCounter is null || pCounter.value >= pTrigger.test_value;
}

private Bool SyncCheckTriggerNegativeComparison(SyncTrigger* pTrigger, long oldval)
{
    SyncCounter* pCounter = void;

    /* Non-counter sync objects should never get here because they
     * never trigger this comparison. */
    if (!SyncCheckWarnIsCounter(pTrigger.pSync, WARN_INVALID_COUNTER_COMPARE))
        return FALSE;

    pCounter = cast(SyncCounter*) pTrigger.pSync;

    return pCounter is null || pCounter.value <= pTrigger.test_value;
}

private Bool SyncCheckTriggerPositiveTransition(SyncTrigger* pTrigger, long oldval)
{
    SyncCounter* pCounter = void;

    /* Non-counter sync objects should never get here because they
     * never trigger this comparison. */
    if (!SyncCheckWarnIsCounter(pTrigger.pSync, WARN_INVALID_COUNTER_COMPARE))
        return FALSE;

    pCounter = cast(SyncCounter*) pTrigger.pSync;

    return (pCounter is null ||
            (oldval < pTrigger.test_value &&
             pCounter.value >= pTrigger.test_value));
}

private Bool SyncCheckTriggerNegativeTransition(SyncTrigger* pTrigger, long oldval)
{
    SyncCounter* pCounter = void;

    /* Non-counter sync objects should never get here because they
     * never trigger this comparison. */
    if (!SyncCheckWarnIsCounter(pTrigger.pSync, WARN_INVALID_COUNTER_COMPARE))
        return FALSE;

    pCounter = cast(SyncCounter*) pTrigger.pSync;

    return (pCounter is null ||
            (oldval > pTrigger.test_value &&
             pCounter.value <= pTrigger.test_value));
}

private Bool SyncCheckTriggerFence(SyncTrigger* pTrigger, long unused)
{
    SyncFence* pFence = cast(SyncFence*) pTrigger.pSync;

    cast(void) unused;

    return (pFence is null || pFence.funcs.CheckTriggered(pFence));
}

pragma(inline, true) private Bool checked_int64_add(long* out_, long a, long b)
{
    /* Do the potentially overflowing math as uint64_t, as signed
     * integers in C are undefined on overflow (and the compiler may
     * optimize out our overflow check below, otherwise)
     */
    long result = cast(ulong)a + cast(ulong)b;
    /* signed addition overflows if operands have the same sign, and
     * the sign of the result doesn't match the sign of the inputs.
     */
    Bool overflow = (a < 0) == (b < 0) && (a < 0) != (result < 0);

    *out_ = result;

    return overflow;
}

pragma(inline, true) private Bool checked_int64_subtract(long* out_, long a, long b)
{
    long result = cast(ulong)a - cast(ulong)b;
    Bool overflow = (a < 0) != (b < 0) && (a < 0) != (result < 0);

    *out_ = result;

    return overflow;
}

private int SyncInitTrigger(ClientPtr client, SyncTrigger* pTrigger, XID syncObject, RESTYPE resType, Mask changes)
{
    SyncObject* pSync = pTrigger.pSync;
    SyncCounter* pCounter = null;
    Bool newSyncObject = FALSE;

    if (changes & XSyncCACounter) {
        if (syncObject == None) {
            pSync = null;
        } else {
            int rc = dixLookupResourceByType(cast(void**) &pSync, syncObject,
                                              resType, client, DixReadAccess);
            if (rc != Success) {
                client.errorValue = cast(uint)syncObject;
                return rc;
            }
        }
    }

    /* if system counter, ask it what the current value is */

    if (pSync && SYNC_COUNTER == pSync.type) {
        pCounter = cast(SyncCounter*) pSync;

        if (mixin(IsSystemCounter!(`pCounter`))) {
            (*pCounter.pSysCounterInfo.QueryValue) (cast(void*) pCounter,
                                                      &pCounter.value);
        }
    }

    if (changes & XSyncCAValueType) {
        if (pTrigger.value_type != XSyncRelative &&
            pTrigger.value_type != XSyncAbsolute) {
            client.errorValue = cast(uint)pTrigger.value_type;
            return BadValue;
        }
    }

    if (changes & (XSyncCAValueType | XSyncCAValue)) {
        if (pTrigger.value_type == XSyncAbsolute)
            pTrigger.test_value = pTrigger.wait_value;
        else {                  /* relative */
            Bool overflow = void;

            if (pCounter is null)
                return BadMatch;

            overflow = checked_int64_add(&pTrigger.test_value,
                                         pCounter.value, pTrigger.wait_value);
            if (overflow) {
                client.errorValue = cast(uint)(pTrigger.wait_value >> 32);
                return BadValue;
            }
        }
    }

    if (changes & XSyncCATestType) {

        if (pSync && SYNC_FENCE == pSync.type) {
            pTrigger.CheckTrigger = &SyncCheckTriggerFence;
        }
        else {
            /* select appropriate CheckTrigger function */

            switch (pTrigger.test_type) {
            case XSyncPositiveTransition:
                pTrigger.CheckTrigger = &SyncCheckTriggerPositiveTransition;
                break;
            case XSyncNegativeTransition:
                pTrigger.CheckTrigger = &SyncCheckTriggerNegativeTransition;
                break;
            case XSyncPositiveComparison:
                pTrigger.CheckTrigger = &SyncCheckTriggerPositiveComparison;
                break;
            case XSyncNegativeComparison:
                pTrigger.CheckTrigger = &SyncCheckTriggerNegativeComparison;
                break;
            default:
                client.errorValue = cast(uint)pTrigger.test_type;
                return BadValue;
            }
        }
    }

    if (changes & XSyncCACounter) {
        if (pSync != pTrigger.pSync) { /* new counter for trigger */
            SyncDeleteTriggerFromSyncObject(pTrigger);
            pTrigger.pSync = pSync;
            newSyncObject = TRUE;
        }
    }

    /*  we wait until we're sure there are no errors before registering
     *  a new counter on a trigger
     */
    if (newSyncObject) {
        SyncAddTriggerToSyncObject(pTrigger);
    }
    else if (mixin(IsSystemCounter!(`pCounter`))) {
        SyncComputeBracketValues(pCounter);
    }

    return Success;
}

/*  AlarmNotify events happen in response to actions taken on an Alarm or
 *  the counter used by the alarm.  AlarmNotify may be sent to multiple
 *  clients.  The alarm maintains a list of clients interested in events.
 */
private void SyncSendAlarmNotifyEvents(SyncAlarm* pAlarm)
{
    SyncAlarmClientList* pcl = void;
    // xSyncAlarmNotifyEvent ane = void;
    SyncTrigger* pTrigger = &pAlarm.trigger;
    SyncCounter* pCounter = void;

    if (!SyncCheckWarnIsCounter(pTrigger.pSync, WARN_INVALID_COUNTER_ALARM))
        return;

    pCounter = cast(SyncCounter*) pTrigger.pSync;

    UpdateCurrentTime();

    xSyncAlarmNotifyEvent ane = {
        type: cast(ubyte)(SyncEventBase + XSyncAlarmNotify),
        kind: cast(ubyte)XSyncAlarmNotify,
        alarm: cast(uint)pAlarm.alarm_id,
        alarm_value_hi: pTrigger.test_value >> 32,
        alarm_value_lo: cast(uint)pTrigger.test_value,
        time: currentTime.milliseconds,
        state: cast(ubyte)pAlarm.state
    };

    if (pTrigger.pSync && SYNC_COUNTER == pTrigger.pSync.type) {
        ane.counter_value_hi = pCounter.value >> 32;
        ane.counter_value_lo = cast(uint)pCounter.value;
    }
    else {
        /* XXX what else can we do if there's no counter? */
        ane.counter_value_hi = ane.counter_value_lo = 0;
    }

    /* send to owner */
    if (pAlarm.events)
        WriteEventsToClient(pAlarm.client, 1, cast(xEvent*) &ane);

    /* send to other interested clients */
    for (pcl = pAlarm.pEventClients; pcl; pcl = pcl.next)
        WriteEventsToClient(pcl.client, 1, cast(xEvent*) &ane);
}

/*  CounterNotify events only occur in response to an Await.  The events
 *  go only to the Awaiting client.
 */
private void SyncSendCounterNotifyEvents(ClientPtr client, SyncAwait** ppAwait, int num_events)
{
    xSyncCounterNotifyEvent* pEvents = void, pev = void;
    int i = void;

    if (client.clientGone)
        return;
    pev = pEvents = cast(xSyncCounterNotifyEvent*) calloc(num_events, xSyncCounterNotifyEvent.sizeof);
    if (!pEvents)
        return;
    UpdateCurrentTime();
    for (i = 0; i < num_events; i++, ppAwait++, pev++) {
        SyncTrigger* pTrigger = &(*ppAwait).trigger;

        pev.type = cast(ubyte)(SyncEventBase + XSyncCounterNotify);
        pev.kind = XSyncCounterNotify;
        pev.counter = cast(uint)pTrigger.pSync.id;
        pev.wait_value_lo = cast(uint)pTrigger.test_value;
        pev.wait_value_hi = pTrigger.test_value >> 32;
        if (SYNC_COUNTER == pTrigger.pSync.type) {
            SyncCounter* pCounter = cast(SyncCounter*) pTrigger.pSync;

            pev.counter_value_lo = cast(uint)pCounter.value;
            pev.counter_value_hi = pCounter.value >> 32;
        }
        else {
            pev.counter_value_lo = 0;
            pev.counter_value_hi = 0;
        }

        pev.time = currentTime.milliseconds;
        pev.count = cast(ushort)(num_events - i - 1);        /* events remaining */
        pev.destroyed = cast(ubyte)pTrigger.pSync.beingDestroyed;
    }
    /* swapping will be taken care of by this */
    WriteEventsToClient(client, num_events, cast(xEvent*) pEvents);
    free(pEvents);
}

/* This function is called when an alarm's counter is destroyed.
 * It is plugged into pTrigger->CounterDestroyed (for alarm triggers).
 */
private void SyncAlarmCounterDestroyed(SyncTrigger* pTrigger)
{
    SyncAlarm* pAlarm = cast(SyncAlarm*) pTrigger;

    pAlarm.state = XSyncAlarmInactive;
    SyncSendAlarmNotifyEvents(pAlarm);
    pTrigger.pSync = null;
}

/*  This function is called when an alarm "goes off."
 *  It is plugged into pTrigger->TriggerFired (for alarm triggers).
 */
private void SyncAlarmTriggerFired(SyncTrigger* pTrigger)
{
    SyncAlarm* pAlarm = cast(SyncAlarm*) pTrigger;
    SyncCounter* pCounter = void;
    long new_test_value = void;

    if (!SyncCheckWarnIsCounter(pTrigger.pSync, WARN_INVALID_COUNTER_ALARM))
        return;

    pCounter = cast(SyncCounter*) pTrigger.pSync;

    /* no need to check alarm unless it's active */
    if (pAlarm.state != XSyncAlarmActive)
        return;

    /*  " if the counter value is None, or if the delta is 0 and
     *    the test-type is PositiveComparison or NegativeComparison,
     *    no change is made to value (test-value) and the alarm
     *    state is changed to Inactive before the event is generated."
     */
    if (pCounter is null || (pAlarm.delta == 0
                             && (pAlarm.trigger.test_type ==
                                 XSyncPositiveComparison ||
                                 pAlarm.trigger.test_type ==
                                 XSyncNegativeComparison)))
        pAlarm.state = XSyncAlarmInactive;

    new_test_value = pAlarm.trigger.test_value;

    if (pAlarm.state == XSyncAlarmActive) {
        Bool overflow = void;
        long oldvalue = void;
        SyncTrigger* paTrigger = &pAlarm.trigger;
        SyncCounter* paCounter = void;

        if (!SyncCheckWarnIsCounter(paTrigger.pSync,
                                    WARN_INVALID_COUNTER_ALARM))
            return;

        paCounter = cast(SyncCounter*) pTrigger.pSync;

        /* "The alarm is updated by repeatedly adding delta to the
         *  value of the trigger and re-initializing it until it
         *  becomes FALSE."
         */
        oldvalue = paTrigger.test_value;

        /* XXX really should do something smarter here */

        do {
            overflow = checked_int64_add(&paTrigger.test_value,
                                         paTrigger.test_value, pAlarm.delta);
        } while (!overflow &&
                 (*paTrigger.CheckTrigger) (paTrigger, paCounter.value));

        new_test_value = paTrigger.test_value;
        paTrigger.test_value = oldvalue;

        /* "If this update would cause value to fall outside the range
         *  for an INT64...no change is made to value (test-value) and
         *  the alarm state is changed to Inactive before the event is
         *  generated."
         */
        if (overflow) {
            new_test_value = oldvalue;
            pAlarm.state = XSyncAlarmInactive;
        }
    }
    /*  The AlarmNotify event has to have the "new state of the alarm"
     *  which we can't be sure of until this point.  However, it has
     *  to have the "old" trigger test value.  That's the reason for
     *  all the newvalue/oldvalue shuffling above.  After we send the
     *  events, give the trigger its new test value.
     */
    SyncSendAlarmNotifyEvents(pAlarm);
    pTrigger.test_value = new_test_value;
}

/*  This function is called when an Await unblocks, either as a result
 *  of the trigger firing OR the counter being destroyed.
 *  It goes into pTrigger->TriggerFired AND pTrigger->CounterDestroyed
 *  (for Await triggers).
 */
private void SyncAwaitTriggerFired(SyncTrigger* pTrigger)
{
    SyncAwait* pAwait = cast(SyncAwait*) pTrigger;
    int numwaits = void;
    SyncAwaitUnion* pAwaitUnion = void;
    SyncAwait** ppAwait = void;
    int num_events = 0;

    pAwaitUnion = cast(SyncAwaitUnion*) pAwait.pHeader;
    numwaits = pAwaitUnion.header.num_waitconditions;
    ppAwait = cast(SyncAwait**) calloc(numwaits, (SyncAwait*).sizeof);
    if (!ppAwait)
        goto bail;

    pAwait = &(pAwaitUnion + 1).await;

    /* "When a client is unblocked, all the CounterNotify events for
     *  the Await request are generated contiguously. If count is 0
     *  there are no more events to follow for this request. If
     *  count is n, there are at least n more events to follow."
     *
     *  Thus, it is best to find all the counters for which events
     *  need to be sent first, so that an accurate count field can
     *  be stored in the events.
     */
    for (; numwaits; numwaits--, pAwait++) {
        long diff = void;
        Bool overflow = void, diffgreater = void, diffequal = void;

        /* "A CounterNotify event with the destroyed flag set to TRUE is
         *  always generated if the counter for one of the triggers is
         *  destroyed."
         */
        if (pAwait.trigger.pSync.beingDestroyed) {
            ppAwait[num_events++] = pAwait;
            continue;
        }

        if (SYNC_COUNTER == pAwait.trigger.pSync.type) {
            SyncCounter* pCounter = cast(SyncCounter*) pAwait.trigger.pSync;

            /* "The difference between the counter and the test value is
             *  calculated by subtracting the test value from the value of
             *  the counter."
             */
            overflow = checked_int64_subtract(&diff, pCounter.value,
                                              pAwait.trigger.test_value);

            /* "If the difference lies outside the range for an INT64, an
             *  event is not generated."
             */
            if (overflow)
                continue;
            diffgreater = diff > pAwait.event_threshold;
            diffequal = diff == pAwait.event_threshold;

            /* "If the test-type is PositiveTransition or
             *  PositiveComparison, a CounterNotify event is generated if
             *  the difference is at least event-threshold. If the test-type
             *  is NegativeTransition or NegativeComparison, a CounterNotify
             *  event is generated if the difference is at most
             *  event-threshold."
             */

            if (((pAwait.trigger.test_type == XSyncPositiveComparison ||
                  pAwait.trigger.test_type == XSyncPositiveTransition)
                 && (diffgreater || diffequal))
                ||
                ((pAwait.trigger.test_type == XSyncNegativeComparison ||
                  pAwait.trigger.test_type == XSyncNegativeTransition)
                 && (!diffgreater)      /* less or equal */
                )
                ) {
                ppAwait[num_events++] = pAwait;
            }
        }
    }
    if (num_events)
        SyncSendCounterNotifyEvents(pAwaitUnion.header.client, ppAwait,
                                    num_events);
    free(ppAwait);

 bail:
    /* unblock the client */
    AttendClient(pAwaitUnion.header.client);
    /* delete the await */
    FreeResource(cast(uint)pAwaitUnion.header.delete_id, X11_RESTYPE_NONE);
}

private long SyncUpdateCounter(SyncCounter* pCounter, long newval)
{
    long oldval = pCounter.value;
    pCounter.value = newval;
    return oldval;
}

/*  This function should always be used to change a counter's value so that
 *  any triggers depending on the counter will be checked.
 */
void SyncChangeCounter(SyncCounter* pCounter, long newval)
{
    SyncTriggerList* ptl = void, pnext = void;
    long oldval = void;

    oldval = SyncUpdateCounter(pCounter, newval);

    /* run through triggers to see if any become true */
    for (ptl = pCounter.sync.pTriglist; ptl; ptl = pnext) {
        pnext = ptl.next;
        if ((*ptl.pTrigger.CheckTrigger) (ptl.pTrigger, oldval))
            (*ptl.pTrigger.TriggerFired) (ptl.pTrigger);
    }

    if (mixin(IsSystemCounter!(`pCounter`))) {
        SyncComputeBracketValues(pCounter);
    }
}

/* loosely based on dix/events.c/EventSelectForWindow */
private Bool SyncEventSelectForAlarm(SyncAlarm* pAlarm, ClientPtr client, Bool wantevents)
{
    if (client == pAlarm.client) {     /* alarm owner */
        pAlarm.events = wantevents;
        return Success;
    }

    /* see if the client is already on the list (has events selected) */

    for (SyncAlarmClientList* pClients = pAlarm.pEventClients;
         pClients !is null; pClients = pClients.next) {
        if (pClients.client == client) {
            /* client's presence on the list indicates desire for
             * events.  If the client doesn't want events, remove it
             * from the list.  If the client does want events, do
             * nothing, since it's already got them.
             */
            if (!wantevents) {
                FreeResource(cast(uint)pClients.delete_id, X11_RESTYPE_NONE);
            }
            return Success;
        }
    }

    /*  if we get here, this client does not currently have
     *  events selected on the alarm
     */

    if (!wantevents)
        /* client doesn't want events, and we just discovered that it
         * doesn't have them, so there's nothing to do.
         */
        return Success;

    /* add new client to pAlarm->pEventClients */

    SyncAlarmClientList* pClients = cast(SyncAlarmClientList*) cast(SyncAlarmClientList*) calloc(1, SyncAlarmClientList.sizeof);
    if (!pClients)
        return BadAlloc;

    /*  register it as a resource so it will be cleaned up
     *  if the client dies
     */

    pClients.delete_id = FakeClientID(client.index);

    /* link it into list after we know all the allocations succeed */
    pClients.next = pAlarm.pEventClients;
    pAlarm.pEventClients = pClients;
    pClients.client = client;

    if (!AddResource(cast(uint)pClients.delete_id, RTAlarmClient, pAlarm))
        return BadAlloc;

    return Success;
}

/*
 * ** SyncChangeAlarmAttributes ** This is used by CreateAlarm and ChangeAlarm
 */
private int SyncChangeAlarmAttributes(ClientPtr client, SyncAlarm* pAlarm, Mask mask, CARD32* values)
{
    int status = void;
    XSyncCounter counter = void;
    Mask origmask = mask;
    SyncTrigger trigger = void;
    Bool select_events_changed = FALSE;
    Bool select_events_value = FALSE;
    long delta = void;

    trigger = pAlarm.trigger;
    delta = pAlarm.delta;
    counter = trigger.pSync ? trigger.pSync.id : None;

    while (mask) {
        int index2 = cast(int)mixin(lowbit!mask);

        mask &= ~index2;
        switch (cast(long)index2) {
        case XSyncCACounter:
            mask &= ~XSyncCACounter;
            /* sanity check in SyncInitTrigger */
            counter = *values++;
            break;

        case XSyncCAValueType:
            mask &= ~XSyncCAValueType;
            /* sanity check in SyncInitTrigger */
            trigger.value_type = cast(uint)*values++;
            break;

        case XSyncCAValue:
            mask &= ~XSyncCAValue;
            trigger.wait_value = (cast(long)values[0] << 32) | values[1];
            values += 2;
            break;

        case XSyncCATestType:
            mask &= ~XSyncCATestType;
            /* sanity check in SyncInitTrigger */
            trigger.test_type = cast(uint)*values++;
            break;

        case XSyncCADelta:
            mask &= ~XSyncCADelta;
            delta = (cast(long)values[0] << 32) | values[1];
            values += 2;
            break;

        case XSyncCAEvents:
            mask &= ~XSyncCAEvents;
            if ((*values != xTrue) && (*values != xFalse)) {
                client.errorValue = cast(uint)*values;
                return BadValue;
            }
            select_events_value = cast(Bool) (*values++);
            select_events_changed = TRUE;
            break;

        default:
            client.errorValue = cast(uint)mask;
            return BadValue;
        }
    }

    if (select_events_changed) {
        status = SyncEventSelectForAlarm(pAlarm, client, select_events_value);
        if (status != Success)
            return status;
    }

    /* "If the test-type is PositiveComparison or PositiveTransition
     *  and delta is less than zero, or if the test-type is
     *  NegativeComparison or NegativeTransition and delta is
     *  greater than zero, a Match error is generated."
     */
    if (origmask & (XSyncCADelta | XSyncCATestType)) {
        if ((((trigger.test_type == XSyncPositiveComparison) ||
              (trigger.test_type == XSyncPositiveTransition))
             && delta < 0)
            ||
            (((trigger.test_type == XSyncNegativeComparison) ||
              (trigger.test_type == XSyncNegativeTransition))
             && delta > 0)
            ) {
            return BadMatch;
        }
    }

    /* postpone this until now, when we're sure nothing else can go wrong */
    pAlarm.delta = delta;
    pAlarm.trigger = trigger;
    if ((status = SyncInitTrigger(client, &pAlarm.trigger, counter, RTCounter,
                                  origmask & XSyncCAAllTrigger)) != Success)
        return status;

    /* XXX spec does not really say to do this - needs clarification */
    pAlarm.state = XSyncAlarmActive;
    return Success;
}

SyncObject* SyncCreate(ClientPtr client, XID id, ubyte type)
{
    SyncObject* pSync = void;
    RESTYPE resType = void;

    switch (type) {
    case SYNC_COUNTER:
        pSync = cast(SyncObject*) cast(SyncCounter*) calloc(1, SyncCounter.sizeof);
        resType = RTCounter;
        break;
    case SYNC_FENCE:
        pSync = cast(SyncObject*) mixin(dixAllocateObjectWithPrivates!("SyncFence",
                                                             "PRIVATE_SYNC_FENCE"));
        resType = RTFence;
        break;
    default:
        return null;
    }

    if (!pSync)
        return null;

    pSync.initialized = FALSE;

    if (!AddResource(cast(uint)id, resType, cast(void*) pSync))
        return null;

    pSync.client = client;
    pSync.id = id;
    pSync.pTriglist = null;
    pSync.beingDestroyed = FALSE;
    pSync.type = type;

    return pSync;
}

int SyncCreateFenceFromFD(ClientPtr client, DrawablePtr pDraw, XID id, int fd, BOOL initially_triggered)
{
static if (HAVE_XSHMFENCE) {
    SyncFence* pFence = void;
    int status = void;

    pFence = cast(SyncFence*) SyncCreate(client, id, SYNC_FENCE);
    if (!pFence)
        return BadAlloc;

    status = miSyncInitFenceFromFD(pDraw, pFence, fd, initially_triggered);
    if (status != Success) {
        FreeResource(cast(uint)pFence.sync.id, X11_RESTYPE_NONE);
        return status;
    }

    return Success;
} else {
    return BadImplementation;
}
}

int SyncFDFromFence(ClientPtr client, DrawablePtr pDraw, SyncFence* pFence)
{
static if (HAVE_XSHMFENCE) {
    return miSyncFDFromFence(pDraw, pFence);
} else {
    return BadImplementation;
}
}

private SyncCounter* SyncCreateCounter(ClientPtr client, XSyncCounter id, long initialvalue)
{
    SyncCounter* pCounter = void;

    if (((pCounter = cast(SyncCounter*) SyncCreate(client, id, SYNC_COUNTER)) is null))
        return null;

    pCounter.value = initialvalue;
    pCounter.pSysCounterInfo = null;

    pCounter.sync.initialized = TRUE;

    return pCounter;
}



/*
 * ***** System Counter utilities
 */

SyncCounter* SyncCreateSystemCounter(const(char)* name, long initial, long resolution, SyncCounterType counterType, SyncSystemCounterQueryValue QueryValue, SyncSystemCounterBracketValues BracketValues)
{
    SyncCounter* pCounter = SyncCreateCounter(null, dixAllocServerXID(), initial);

    if (pCounter) {
        SysCounterInfo* psci = cast(_SysCounterInfo*) cast(SysCounterInfo*) calloc(1, SysCounterInfo.sizeof);
        if (!psci) {
            FreeResource(cast(uint)pCounter.sync.id, X11_RESTYPE_NONE);
            return null;
        }
        pCounter.pSysCounterInfo = psci;
        psci.pCounter = pCounter;
        if (((psci.name = strdup(name)) is null)) {
            free(psci);
            pCounter.pSysCounterInfo = null;
            FreeResource(cast(uint)pCounter.sync.id, X11_RESTYPE_NONE);
            return null;
        }
        psci.resolution = resolution;
        psci.counterType = counterType;
        psci.QueryValue = QueryValue;
        psci.BracketValues = BracketValues;
        psci.private_ = null;
        psci.bracket_greater = LLONG_MAX;
        psci.bracket_less = LLONG_MIN;
        xorg_list_add(&psci.entry, &SysCounterList);
    }
    return pCounter;
}

void SyncDestroySystemCounter(void* pSysCounter)
{
    SyncCounter* pCounter = cast(SyncCounter*) pSysCounter;

    FreeResource(cast(uint)pCounter.sync.id, X11_RESTYPE_NONE);
}

private void SyncComputeBracketValues(SyncCounter* pCounter)
{
    SyncTriggerList* pCur = void;
    SyncTrigger* pTrigger = void;
    SysCounterInfo* psci = void;
    long* pnewgtval = null;
    long* pnewltval = null;
    SyncCounterType ct = void;

    if (!pCounter)
        return;

    psci = pCounter.pSysCounterInfo;
    ct = pCounter.pSysCounterInfo.counterType;
    if (ct == XSyncCounterNeverChanges)
        return;

    psci.bracket_greater = LLONG_MAX;
    psci.bracket_less = LLONG_MIN;

    for (pCur = pCounter.sync.pTriglist; pCur; pCur = pCur.next) {
        pTrigger = pCur.pTrigger;

        if (pTrigger.test_type == XSyncPositiveComparison &&
            ct != XSyncCounterNeverIncreases) {
            if (pCounter.value < pTrigger.test_value &&
                pTrigger.test_value < psci.bracket_greater) {
                psci.bracket_greater = pTrigger.test_value;
                pnewgtval = &psci.bracket_greater;
            }
            else if (pCounter.value > pTrigger.test_value &&
                     pTrigger.test_value > psci.bracket_less) {
                    psci.bracket_less = pTrigger.test_value;
                    pnewltval = &psci.bracket_less;
            }
        }
        else if (pTrigger.test_type == XSyncNegativeComparison &&
                 ct != XSyncCounterNeverDecreases) {
            if (pCounter.value > pTrigger.test_value &&
                pTrigger.test_value > psci.bracket_less) {
                psci.bracket_less = pTrigger.test_value;
                pnewltval = &psci.bracket_less;
            }
            else if (pCounter.value < pTrigger.test_value &&
                     pTrigger.test_value < psci.bracket_greater) {
                    psci.bracket_greater = pTrigger.test_value;
                    pnewgtval = &psci.bracket_greater;
            }
        }
        else if (pTrigger.test_type == XSyncNegativeTransition &&
                 ct != XSyncCounterNeverIncreases) {
            if (pCounter.value >= pTrigger.test_value &&
                pTrigger.test_value > psci.bracket_less) {
                    /*
                     * If the value is exactly equal to our threshold, we want one
                     * more event in the negative direction to ensure we pick up
                     * when the value is less than this threshold.
                     */
                    psci.bracket_less = pTrigger.test_value;
                    pnewltval = &psci.bracket_less;
            }
            else if (pCounter.value < pTrigger.test_value &&
                     pTrigger.test_value < psci.bracket_greater) {
                    psci.bracket_greater = pTrigger.test_value;
                    pnewgtval = &psci.bracket_greater;
            }
        }
        else if (pTrigger.test_type == XSyncPositiveTransition &&
                 ct != XSyncCounterNeverDecreases) {
            if (pCounter.value <= pTrigger.test_value &&
                pTrigger.test_value < psci.bracket_greater) {
                    /*
                     * If the value is exactly equal to our threshold, we
                     * want one more event in the positive direction to
                     * ensure we pick up when the value *exceeds* this
                     * threshold.
                     */
                    psci.bracket_greater = pTrigger.test_value;
                    pnewgtval = &psci.bracket_greater;
            }
            else if (pCounter.value > pTrigger.test_value &&
                     pTrigger.test_value > psci.bracket_less) {
                    psci.bracket_less = pTrigger.test_value;
                    pnewltval = &psci.bracket_less;
            }
        }
    }                           /* end for each trigger */

    (*psci.BracketValues) (cast(void*) pCounter, pnewltval, pnewgtval);

}

/*
 * *****  Resource delete functions
 */

/* ARGSUSED */
private int FreeAlarm(void* addr, XID id)
{
    SyncAlarm* pAlarm = cast(SyncAlarm*) addr;

    pAlarm.state = XSyncAlarmDestroyed;

    SyncSendAlarmNotifyEvents(pAlarm);

    /* delete event selections */

    while (pAlarm.pEventClients)
        FreeResource(cast(uint)pAlarm.pEventClients.delete_id, X11_RESTYPE_NONE);

    SyncDeleteTriggerFromSyncObject(&pAlarm.trigger);

    free(pAlarm);
    return Success;
}

/*
 * ** Cleanup after the destruction of a Counter
 */
/* ARGSUSED */
private int FreeCounter(void* env, XID id)
{
    SyncCounter* pCounter = cast(SyncCounter*) env;

    pCounter.sync.beingDestroyed = TRUE;

    if (pCounter.sync.initialized) {
        SyncTriggerList* ptl = void, pnext = void;

        /* tell all the counter's triggers that counter has been destroyed */
        for (ptl = pCounter.sync.pTriglist; ptl; ptl = pnext) {
            (*ptl.pTrigger.CounterDestroyed) (ptl.pTrigger);
            pnext = ptl.next;
            free(ptl); /* destroy the trigger list as we go */
        }
        if (mixin(IsSystemCounter!(`pCounter`)) && pCounter.pSysCounterInfo) {
            xorg_list_del(&pCounter.pSysCounterInfo.entry);
            free(pCounter.pSysCounterInfo.name);
            free(pCounter.pSysCounterInfo.private_);
            free(pCounter.pSysCounterInfo);
        }
    }

    free(pCounter);
    return Success;
}

/*
 * ** Cleanup after Await
 */
/* ARGSUSED */
private int FreeAwait(void* addr, XID id)
{
    SyncAwaitUnion* pAwaitUnion = cast(SyncAwaitUnion*) addr;
    SyncAwait* pAwait = void;
    int numwaits = void;

    pAwait = &(pAwaitUnion + 1).await; /* first await on list */

    /* remove triggers from counters */

    for (numwaits = pAwaitUnion.header.num_waitconditions; numwaits;
         numwaits--, pAwait++) {
        /* If the counter is being destroyed, FreeCounter will delete
         * the trigger list itself, so don't do it here.
         */
        SyncObject* pSync = pAwait.trigger.pSync;

        if (pSync && !pSync.beingDestroyed)
            SyncDeleteTriggerFromSyncObject(&pAwait.trigger);
    }
    free(pAwaitUnion);
    return Success;
}

/* loosely based on dix/events.c/OtherClientGone */
private int FreeAlarmClient(void* value, XID id)
{
    SyncAlarm* pAlarm = cast(SyncAlarm*) value;
    SyncAlarmClientList* pCur = void, pPrev = void;

    for (pPrev = null, pCur = pAlarm.pEventClients;
         pCur; pPrev = pCur, pCur = pCur.next) {
        if (pCur.delete_id == id) {
            if (pPrev)
                pPrev.next = pCur.next;
            else
                pAlarm.pEventClients = pCur.next;
            free(pCur);
            return Success;
        }
    }
    FatalError("alarm client not on event list");
    assert(0);
 /*NOTREACHED*/
 }

/*
 * *****  Proc functions
 */

/*
 * ** Initialize the extension
 */
private int ProcSyncInitialize(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncInitializeReq);

    xSyncInitializeReply reply = {
        majorVersion: SERVER_SYNC_MAJOR_VERSION,
        minorVersion: SERVER_SYNC_MINOR_VERSION,
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/*
 * ** Get list of system counters available through the extension
 */
private int ProcSyncListSystemCounters(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncListSystemCountersReq);

    SysCounterInfo* psci = void;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    CARD32 nCounters = 0;
    mixin(xorg_list_for_each_entry!("psci", "&SysCounterList", "entry", q{
        CARD16 namelen = cast(ushort)strlen(psci.name);

        /* write xSyncSystemCounter:
           the name chars (`namelen` amount of bytes) are directly written
           after the header fields, then the whole thing is padded to
           full protocol units.
        */
        x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)psci.pCounter.sync.id);
        x_rpcbuf_write_INT32(&rpcbuf, cast(int)(psci.resolution >> 32));
        x_rpcbuf_write_INT32(&rpcbuf, cast(int)psci.resolution);
        x_rpcbuf_write_CARD16(&rpcbuf, cast(ushort)namelen);
        x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)psci.name, namelen);
        x_rpcbuf_pad(&rpcbuf);

        nCounters++;
    }));

    if (rpcbuf.error)
        return BadAlloc;

    xSyncListSystemCountersReply reply = {
        nCounters: nCounters
    };

    mixin(X_REPLY_FIELD_CARD32!"nCounters");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/*
 * Set the priority of the client owning given resource.
 * If the resource ID is None then set the priority of calling client.
 */
private int ProcSyncSetPriority(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncSetPriorityReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");
    mixin(X_REQUEST_FIELD_CARD32!"priority");

    ClientPtr priorityclient = void;

    if (stuff.id == None)
        priorityclient = client;
    else {
        int rc = dixLookupResourceOwner(&priorityclient, stuff.id, client,
                             DixSetAttrAccess);
        if (rc != Success)
            return rc;
    }

    if (priorityclient.priority != stuff.priority) {
        priorityclient.priority = cast(int)stuff.priority;

        /*  The following will force the server back into WaitForSomething
         *  so that the change in this client's priority is immediately
         *  reflected.
         */
        isItTimeToYield = TRUE;
        dispatchException |= DE_PRIORITYCHANGE;
    }
    return Success;
}

/*
 * Retrieve the priority of the client owning given resource.
 * If the resource ID is None then retrieve the priority of calling client.
 */
private int ProcSyncGetPriority(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncGetPriorityReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    ClientPtr priorityclient = void;

    if (stuff.id == None)
        priorityclient = client;
    else {
        int rc = dixLookupResourceOwner(&priorityclient, stuff.id, client,
                             DixGetAttrAccess);
        if (rc != Success)
            return rc;
    }

    xSyncGetPriorityReply reply = {
        priority: priorityclient.priority
    };

    mixin(X_REPLY_FIELD_CARD32!"priority");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/*
 * ** Create a new counter
 */
private int ProcSyncCreateCounter(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncCreateCounterReq);
    mixin(X_REQUEST_FIELD_CARD32!"cid");
    mixin(X_REQUEST_FIELD_CARD32!"initial_value_lo");
    mixin(X_REQUEST_FIELD_CARD32!"initial_value_hi");

    long initial = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.cid", "client"));

    initial = (cast(long)stuff.initial_value_hi << 32) | stuff.initial_value_lo;

    if (!SyncCreateCounter(client, stuff.cid, initial))
        return BadAlloc;

    return Success;
}

/*
 * ** Set Counter value
 */
private int ProcSyncSetCounter(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncSetCounterReq);
    mixin(X_REQUEST_FIELD_CARD32!"cid");
    mixin(X_REQUEST_FIELD_CARD32!"value_lo");
    mixin(X_REQUEST_FIELD_CARD32!"value_hi");

    SyncCounter* pCounter = void;
    long newvalue = void;

    int rc = dixLookupResourceByType(cast(void**) &pCounter, stuff.cid, RTCounter,
                                 client, DixWriteAccess);
    if (rc != Success)
        return rc;

    if (mixin(IsSystemCounter!(`pCounter`))) {
        client.errorValue = cast(uint)stuff.cid;
        return BadAccess;
    }

    newvalue = (cast(long)stuff.value_hi << 32) | stuff.value_lo;
    SyncChangeCounter(pCounter, newvalue);
    return Success;
}

/*
 * ** Change Counter value
 */
private int ProcSyncChangeCounter(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncChangeCounterReq);
    mixin(X_REQUEST_FIELD_CARD32!"cid");
    mixin(X_REQUEST_FIELD_CARD32!"value_lo");
    mixin(X_REQUEST_FIELD_CARD32!"value_hi");

    SyncCounter* pCounter = void;
    long newvalue = void;
    Bool overflow = void;

    int rc = dixLookupResourceByType(cast(void**) &pCounter, stuff.cid, RTCounter,
                                 client, DixWriteAccess);
    if (rc != Success)
        return rc;

    if (mixin(IsSystemCounter!(`pCounter`))) {
        client.errorValue = cast(uint)stuff.cid;
        return BadAccess;
    }

    newvalue = cast(long)stuff.value_hi << 32 | stuff.value_lo;
    overflow = checked_int64_add(&newvalue, newvalue, pCounter.value);
    if (overflow) {
        /* XXX 64 bit value can't fit in 32 bits; do the best we can */
        client.errorValue = cast(uint)stuff.value_hi;
        return BadValue;
    }
    SyncChangeCounter(pCounter, newvalue);
    return Success;
}

/*
 * ** Destroy a counter
 */
private int ProcSyncDestroyCounter(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncDestroyCounterReq);
    mixin(X_REQUEST_FIELD_CARD32!"counter");

    SyncCounter* pCounter = void;

    int rc = dixLookupResourceByType(cast(void**) &pCounter, stuff.counter,
                                 RTCounter, client, DixDestroyAccess);
    if (rc != Success)
        return rc;

    if (mixin(IsSystemCounter!(`pCounter`))) {
        client.errorValue = cast(uint)stuff.counter;
        return BadAccess;
    }
    FreeResource(cast(uint)pCounter.sync.id, X11_RESTYPE_NONE);
    return Success;
}

private SyncAwaitUnion* SyncAwaitPrologue(ClientPtr client, int items)
{
    SyncAwaitUnion* pAwaitUnion = void;

    /*  all the memory for the entire await list is allocated
     *  here in one chunk
     */
    pAwaitUnion = cast(SyncAwaitUnion*) calloc(items + 1, SyncAwaitUnion.sizeof);
    if (!pAwaitUnion)
        return null;

    /* first item is the header, remainder are real wait conditions */

    pAwaitUnion.header.delete_id = cast(uint)FakeClientID(client.index);
    pAwaitUnion.header.client = client;
    pAwaitUnion.header.num_waitconditions = 0;

    if (!AddResource(cast(uint)pAwaitUnion.header.delete_id, RTAwait, pAwaitUnion))
        return null;

    return pAwaitUnion;
}

private void SyncAwaitEpilogue(ClientPtr client, int items, SyncAwaitUnion* pAwaitUnion)
{
    SyncAwait* pAwait = void;
    int i = void;

    IgnoreClient(client);

    /* see if any of the triggers are already true */

    pAwait = &(pAwaitUnion + 1).await; /* skip over header */
    for (i = 0; i < items; i++, pAwait++) {
        long value = void;

        /*  don't have to worry about NULL counters because the request
         *  errors before we get here out if they occur
         */
        switch (pAwait.trigger.pSync.type) {
        case SYNC_COUNTER:
            value = (cast(SyncCounter*) pAwait.trigger.pSync).value;
            break;
        default:
            value = 0;
        }

        if ((*pAwait.trigger.CheckTrigger) (&pAwait.trigger, value)) {
            (*pAwait.trigger.TriggerFired) (&pAwait.trigger);
            break;              /* once is enough */
        }
    }
}

/*
 * ** Await
 */
private int ProcSyncAwait(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xSyncAwaitReq);
    mixin(X_REQUEST_REST_CARD32!());

    int len = void, items = void;
    int i = void;
    xSyncWaitCondition* pProtocolWaitConds = void;
    SyncAwaitUnion* pAwaitUnion = void;
    SyncAwait* pAwait = void;
    int status = void;

    len = cast(int)client.req_len << 2;
    len -= sz_xSyncAwaitReq;
    items = len / sz_xSyncWaitCondition;

    if (items * sz_xSyncWaitCondition != len) {
        return BadLength;
    }
    if (items == 0) {
        client.errorValue = cast(uint)items;     /* XXX protocol change */
        return BadValue;
    }

    if (((pAwaitUnion = SyncAwaitPrologue(client, items)) is null))
        return BadAlloc;

    /* don't need to do any more memory allocation for this request! */

    pProtocolWaitConds = cast(xSyncWaitCondition*) &stuff[1];

    pAwait = &(pAwaitUnion + 1).await; /* skip over header */
    for (i = 0; i < items; i++, pProtocolWaitConds++, pAwait++) {
        if (pProtocolWaitConds.counter == None) {      /* XXX protocol change */
            /*  this should take care of removing any triggers created by
             *  this request that have already been registered on sync objects
             */
            FreeResource(cast(uint)pAwaitUnion.header.delete_id, X11_RESTYPE_NONE);
            client.errorValue = cast(uint)pProtocolWaitConds.counter;
            return SyncErrorBase + XSyncBadCounter;
        }

        /* sanity checks are in SyncInitTrigger */
        pAwait.trigger.pSync = null;
        pAwait.trigger.value_type = cast(uint)pProtocolWaitConds.value_type;
        pAwait.trigger.wait_value =
            (cast(long)pProtocolWaitConds.wait_value_hi << 32) |
            pProtocolWaitConds.wait_value_lo;
        pAwait.trigger.test_type = cast(uint)pProtocolWaitConds.test_type;

        status = SyncInitTrigger(client, &pAwait.trigger,
                                 pProtocolWaitConds.counter, RTCounter,
                                 XSyncCAAllTrigger);
        if (status != Success) {
            /*  this should take care of removing any triggers created by
             *  this request that have already been registered on sync objects
             */
            FreeResource(cast(uint)pAwaitUnion.header.delete_id, X11_RESTYPE_NONE);
            return status;
        }
        /* this is not a mistake -- same function works for both cases */
        pAwait.trigger.TriggerFired = &SyncAwaitTriggerFired;
        pAwait.trigger.CounterDestroyed = &SyncAwaitTriggerFired;
        pAwait.event_threshold =
            (cast(long) pProtocolWaitConds.event_threshold_hi << 32) |
            pProtocolWaitConds.event_threshold_lo;

        pAwait.pHeader = &pAwaitUnion.header;
        pAwaitUnion.header.num_waitconditions++;
    }

    SyncAwaitEpilogue(client, items, pAwaitUnion);

    return Success;
}

/*
 * ** Query a counter
 */
private int ProcSyncQueryCounter(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncQueryCounterReq);
    mixin(X_REQUEST_FIELD_CARD32!"counter");

    SyncCounter* pCounter = void;

    int rc = dixLookupResourceByType(cast(void**) &pCounter, stuff.counter,
                                 RTCounter, client, DixReadAccess);
    if (rc != Success)
        return rc;

    /* if system counter, ask it what the current value is */
    if (mixin(IsSystemCounter!(`pCounter`))) {
        (*pCounter.pSysCounterInfo.QueryValue) (cast(void*) pCounter,
                                                  &pCounter.value);
    }

    xSyncQueryCounterReply reply = {
        value_hi: pCounter.value >> 32,
        value_lo: cast(uint)pCounter.value
    };

    mixin(X_REPLY_FIELD_CARD32!"value_hi");
    mixin(X_REPLY_FIELD_CARD32!"value_lo");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/*
 * ** Create Alarm
 */
private int ProcSyncCreateAlarm(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xSyncCreateAlarmReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");
    mixin(X_REQUEST_FIELD_CARD32!"valueMask");
    mixin(X_REQUEST_REST_CARD32!());

    SyncAlarm* pAlarm = void;
    int status = void;
    c_ulong len = void, vmask = void;
    SyncTrigger* pTrigger = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.id", "client"));

    vmask = stuff.valueMask;
    len = cast(int)(client.req_len - bytes_to_int32(xSyncCreateAlarmReq.sizeof));
    /* the "extra" call to Ones accounts for the presence of 64 bit values */
    if (len != (Ones(vmask) + Ones(vmask & (XSyncCAValue | XSyncCADelta))))
        return BadLength;

    if (((pAlarm = cast(SyncAlarm*) cast(SyncAlarm*) calloc(1, SyncAlarm.sizeof)) is null)) {
        return BadAlloc;
    }

    /* set up defaults */

    pTrigger = &pAlarm.trigger;
    pTrigger.pSync = null;
    pTrigger.value_type = XSyncAbsolute;
    pTrigger.wait_value = 0;
    pTrigger.test_type = XSyncPositiveComparison;
    pTrigger.TriggerFired = &SyncAlarmTriggerFired;
    pTrigger.CounterDestroyed = &SyncAlarmCounterDestroyed;
    status = SyncInitTrigger(client, pTrigger, None, RTCounter,
                             XSyncCAAllTrigger);
    if (status != Success) {
        free(pAlarm);
        return status;
    }

    pAlarm.client = client;
    pAlarm.alarm_id = stuff.id;
    pAlarm.delta = 1;
    pAlarm.events = TRUE;
    pAlarm.state = XSyncAlarmInactive;
    pAlarm.pEventClients = null;
    status = SyncChangeAlarmAttributes(client, pAlarm, cast(uint)vmask,
                                       cast(CARD32*) &stuff[1]);
    if (status != Success) {
        free(pAlarm);
        return status;
    }

    if (!AddResource(cast(uint)stuff.id, RTAlarm, pAlarm))
        return BadAlloc;

    /*  see if alarm already triggered.  NULL counter will not trigger
     *  in CreateAlarm and sets alarm state to Inactive.
     */

    if (!pTrigger.pSync) {
        pAlarm.state = XSyncAlarmInactive;     /* XXX protocol change */
    }
    else {
        SyncCounter* pCounter = void;

        if (!SyncCheckWarnIsCounter(pTrigger.pSync,
                                    WARN_INVALID_COUNTER_ALARM)) {
            FreeResource(cast(uint)stuff.id, X11_RESTYPE_NONE);
            return BadAlloc;
        }

        pCounter = cast(SyncCounter*) pTrigger.pSync;

        if ((*pTrigger.CheckTrigger) (pTrigger, pCounter.value))
            (*pTrigger.TriggerFired) (pTrigger);
    }

    return Success;
}

/*
 * ** Change Alarm
 */
private int ProcSyncChangeAlarm(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xSyncChangeAlarmReq);
    mixin(X_REQUEST_FIELD_CARD32!"alarm");
    mixin(X_REQUEST_FIELD_CARD32!"valueMask");
    mixin(X_REQUEST_REST_CARD32!());

    SyncAlarm* pAlarm = void;
    SyncCounter* pCounter = null;
    c_long vmask = void;
    int len = void, status = void;

    status = dixLookupResourceByType(cast(void**) &pAlarm, stuff.alarm, RTAlarm,
                                     client, DixWriteAccess);
    if (status != Success)
        return status;

    vmask = stuff.valueMask;
    len = cast(int)(client.req_len - bytes_to_int32(xSyncChangeAlarmReq.sizeof));
    /* the "extra" call to Ones accounts for the presence of 64 bit values */
    if (len != (Ones(vmask) + Ones(vmask & (XSyncCAValue | XSyncCADelta))))
        return BadLength;

    if ((status = SyncChangeAlarmAttributes(client, pAlarm, cast(uint)vmask,
                                            cast(CARD32*) &stuff[1])) != Success)
        return status;

    if (SyncCheckWarnIsCounter(pAlarm.trigger.pSync,
                               WARN_INVALID_COUNTER_ALARM))
        pCounter = cast(SyncCounter*) pAlarm.trigger.pSync;

    /*  see if alarm already triggered.  NULL counter WILL trigger
     *  in ChangeAlarm.
     */

    if (!pCounter ||
        (*pAlarm.trigger.CheckTrigger) (&pAlarm.trigger, pCounter.value)) {
        (*pAlarm.trigger.TriggerFired) (&pAlarm.trigger);
    }
    return Success;
}

private int ProcSyncQueryAlarm(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncQueryAlarmReq);
    mixin(X_REQUEST_FIELD_CARD32!"alarm");

    SyncAlarm* pAlarm = void;
    SyncTrigger* pTrigger = void;

    int rc = dixLookupResourceByType(cast(void**) &pAlarm, stuff.alarm, RTAlarm,
                                 client, DixReadAccess);
    if (rc != Success)
        return rc;

    pTrigger = &pAlarm.trigger;

    xSyncQueryAlarmReply reply = {
        counter: cast(uint)((pTrigger.pSync) ? pTrigger.pSync.id : None),

// #if 0  /* XXX unclear what to do, depends on whether relative value-types
//         * are "consumed" immediately and are considered absolute from then
//         * on.
//         */
//         .value_type = pTrigger.value_type,
//         wait_value_hi: pTrigger.wait_value >> 32,
//         wait_value_lo: pTrigger.wait_value,
// #else
        value_type: XSyncAbsolute,
        wait_value_hi: pTrigger.test_value >> 32,
        wait_value_lo: cast(uint)pTrigger.test_value,
// #endif

        test_type: pTrigger.test_type,
        delta_hi: pAlarm.delta >> 32,
        delta_lo: cast(uint)pAlarm.delta,
        events: cast(ubyte)pAlarm.events,
        state: cast(ubyte)pAlarm.state
    };

    mixin(X_REPLY_FIELD_CARD32!"counter");
    mixin(X_REPLY_FIELD_CARD32!"value_type");
    mixin(X_REPLY_FIELD_CARD32!"wait_value_hi");
    mixin(X_REPLY_FIELD_CARD32!"wait_value_lo");
    mixin(X_REPLY_FIELD_CARD32!"test_type");
    mixin(X_REPLY_FIELD_CARD32!"delta_hi");
    mixin(X_REPLY_FIELD_CARD32!"delta_lo");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcSyncDestroyAlarm(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncDestroyAlarmReq);
    mixin(X_REQUEST_FIELD_CARD32!"alarm");

    SyncAlarm* pAlarm = void;

    int rc = dixLookupResourceByType(cast(void**) &pAlarm, stuff.alarm, RTAlarm,
                                 client, DixDestroyAccess);
    if (rc != Success)
        return rc;

    FreeResource(cast(uint)stuff.alarm, X11_RESTYPE_NONE);
    return Success;
}

private int ProcSyncCreateFence(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncCreateFenceReq);
    mixin(X_REQUEST_FIELD_CARD32!"d");
    mixin(X_REQUEST_FIELD_CARD32!"fid");

    DrawablePtr pDraw = void;
    SyncFence* pFence = void;

    int rc = dixLookupDrawable(&pDraw, stuff.d, client, M_ANY, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    mixin(LEGAL_NEW_RESOURCE!("stuff.fid", "client"));

    if (((pFence = cast(SyncFence*) SyncCreate(client, stuff.fid, SYNC_FENCE)) is null))
        return BadAlloc;

    miSyncInitFence(pDraw.pScreen, pFence, stuff.initially_triggered);

    return Success;
}

private int FreeFence(void* obj, XID id)
{
    SyncFence* pFence = cast(SyncFence*) obj;

    miSyncDestroyFence(pFence);

    return Success;
}

int SyncVerifyFence(SyncFence** ppSyncFence, XID fid, ClientPtr client, Mask mode)
{
    int rc = dixLookupResourceByType(cast(void**) ppSyncFence, fid, RTFence,
                                     client, mode);

    if (rc != Success)
        client.errorValue = cast(uint)fid;

    return rc;
}

private int ProcSyncTriggerFence(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncTriggerFenceReq);
    mixin(X_REQUEST_FIELD_CARD32!"fid");

    SyncFence* pFence = void;

    int rc = dixLookupResourceByType(cast(void**) &pFence, stuff.fid, RTFence,
                                 client, DixWriteAccess);
    if (rc != Success)
        return rc;

    miSyncTriggerFence(pFence);

    return Success;
}

private int ProcSyncResetFence(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncResetFenceReq);
    mixin(X_REQUEST_FIELD_CARD32!"fid");

    SyncFence* pFence = void;

    int rc = dixLookupResourceByType(cast(void**) &pFence, stuff.fid, RTFence,
                                 client, DixWriteAccess);
    if (rc != Success)
        return rc;

    if (pFence.funcs.CheckTriggered(pFence) != TRUE)
        return BadMatch;

    pFence.funcs.Reset(pFence);

    return Success;
}

private int ProcSyncDestroyFence(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncDestroyFenceReq);
    mixin(X_REQUEST_FIELD_CARD32!"fid");

    SyncFence* pFence = void;

    int rc = dixLookupResourceByType(cast(void**) &pFence, stuff.fid, RTFence,
                                 client, DixDestroyAccess);
    if (rc != Success)
        return rc;

    FreeResource(cast(uint)stuff.fid, X11_RESTYPE_NONE);
    return Success;
}

private int ProcSyncQueryFence(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xSyncQueryFenceReq);
    mixin(X_REQUEST_FIELD_CARD32!"fid");

    SyncFence* pFence = void;

    int rc = dixLookupResourceByType(cast(void**) &pFence, stuff.fid,
                                 RTFence, client, DixReadAccess);
    if (rc != Success)
        return rc;

    xSyncQueryFenceReply reply = {
        triggered: cast(ubyte)pFence.funcs.CheckTriggered(pFence)
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcSyncAwaitFence(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xSyncAwaitFenceReq);
    mixin(X_REQUEST_REST_CARD32!());

    SyncAwaitUnion* pAwaitUnion = void;
    SyncAwait* pAwait = void;

    /* Use CARD32 rather than XSyncFence because XIDs are hard-coded to
     * CARD32 in protocol definitions */
    CARD32* pProtocolFences = void;
    int status = void;
    int len = void;
    int items = void;
    int i = void;

    len = cast(int)client.req_len << 2;
    len -= sz_xSyncAwaitFenceReq;
    items = cast(uint)(len / CARD32.sizeof);

    if (items * CARD32.sizeof != len) {
        return BadLength;
    }
    if (items == 0) {
        client.errorValue = cast(uint)items;
        return BadValue;
    }

    if (((pAwaitUnion = SyncAwaitPrologue(client, items)) is null))
        return BadAlloc;

    /* don't need to do any more memory allocation for this request! */

    pProtocolFences = cast(CARD32*) &stuff[1];

    pAwait = &(pAwaitUnion + 1).await; /* skip over header */
    for (i = 0; i < items; i++, pProtocolFences++, pAwait++) {
        if (*pProtocolFences == None) {
            /*  this should take care of removing any triggers created by
             *  this request that have already been registered on sync objects
             */
            FreeResource(cast(uint)pAwaitUnion.header.delete_id, X11_RESTYPE_NONE);
            client.errorValue = cast(uint)*pProtocolFences;
            return cast(uint)(SyncErrorBase + XSyncBadFence);
        }

        pAwait.trigger.pSync = null;
        /* Provide acceptable values for these unused fields to
         * satisfy SyncInitTrigger's validation logic
         */
        pAwait.trigger.value_type = XSyncAbsolute;
        pAwait.trigger.wait_value = 0;
        pAwait.trigger.test_type = 0;

        status = SyncInitTrigger(client, &pAwait.trigger,
                                 *pProtocolFences, RTFence, XSyncCAAllTrigger);
        if (status != Success) {
            /*  this should take care of removing any triggers created by
             *  this request that have already been registered on sync objects
             */
            FreeResource(cast(uint)pAwaitUnion.header.delete_id, X11_RESTYPE_NONE);
            return status;
        }
        /* this is not a mistake -- same function works for both cases */
        pAwait.trigger.TriggerFired = &SyncAwaitTriggerFired;
        pAwait.trigger.CounterDestroyed = &SyncAwaitTriggerFired;
        /* event_threshold is unused for fence syncs */
        pAwait.event_threshold = 0;
        pAwait.pHeader = &pAwaitUnion.header;
        pAwaitUnion.header.num_waitconditions++;
    }

    SyncAwaitEpilogue(client, items, pAwaitUnion);

    return Success;
}

/*
 * ** Given an extension request, call the appropriate request procedure
 */
private int ProcSyncDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
    case X_SyncInitialize:
        return ProcSyncInitialize(client);
    case X_SyncListSystemCounters:
        return ProcSyncListSystemCounters(client);
    case X_SyncCreateCounter:
        return ProcSyncCreateCounter(client);
    case X_SyncSetCounter:
        return ProcSyncSetCounter(client);
    case X_SyncChangeCounter:
        return ProcSyncChangeCounter(client);
    case X_SyncQueryCounter:
        return ProcSyncQueryCounter(client);
    case X_SyncDestroyCounter:
        return ProcSyncDestroyCounter(client);
    case X_SyncAwait:
        return ProcSyncAwait(client);
    case X_SyncCreateAlarm:
        return ProcSyncCreateAlarm(client);
    case X_SyncChangeAlarm:
        return ProcSyncChangeAlarm(client);
    case X_SyncQueryAlarm:
        return ProcSyncQueryAlarm(client);
    case X_SyncDestroyAlarm:
        return ProcSyncDestroyAlarm(client);
    case X_SyncSetPriority:
        return ProcSyncSetPriority(client);
    case X_SyncGetPriority:
        return ProcSyncGetPriority(client);
    case X_SyncCreateFence:
        return ProcSyncCreateFence(client);
    case X_SyncTriggerFence:
        return ProcSyncTriggerFence(client);
    case X_SyncResetFence:
        return ProcSyncResetFence(client);
    case X_SyncDestroyFence:
        return ProcSyncDestroyFence(client);
    case X_SyncQueryFence:
        return ProcSyncQueryFence(client);
    case X_SyncAwaitFence:
        return ProcSyncAwaitFence(client);
    default:
        return BadRequest;
    }
}

/*
 * Event Swapping
 */

private void SCounterNotifyEvent(xSyncCounterNotifyEvent* from, xSyncCounterNotifyEvent* to)
{
    to.type = from.type;
    to.kind = from.kind;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.counter, to.counter);
    cpswapl(from.wait_value_lo, to.wait_value_lo);
    cpswapl(from.wait_value_hi, to.wait_value_hi);
    cpswapl(from.counter_value_lo, to.counter_value_lo);
    cpswapl(from.counter_value_hi, to.counter_value_hi);
    cpswapl(from.time, to.time);
    cpswaps(from.count, to.count);
    to.destroyed = from.destroyed;
}

private void SAlarmNotifyEvent(xSyncAlarmNotifyEvent* from, xSyncAlarmNotifyEvent* to)
{
    to.type = from.type;
    to.kind = from.kind;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.alarm, to.alarm);
    cpswapl(from.counter_value_lo, to.counter_value_lo);
    cpswapl(from.counter_value_hi, to.counter_value_hi);
    cpswapl(from.alarm_value_lo, to.alarm_value_lo);
    cpswapl(from.alarm_value_hi, to.alarm_value_hi);
    cpswapl(from.time, to.time);
    to.state = from.state;
}

/*
 * ** Close everything down. ** This is fairly simple for now.
 */
/* ARGSUSED */
private void SyncResetProc(ExtensionEntry* extEntry)
{
    RTCounter = 0;
}

/*
 * ** Initialise the extension.
 */
void SyncExtensionInit()
{
    ExtensionEntry* extEntry = void;

    mixin(DIX_FOR_EACH_SCREEN!q{
        miSyncSetup(walkScreen);
    });

    RTCounter = CreateNewResourceType(&FreeCounter, "SyncCounter");
    xorg_list_init(&SysCounterList);
    RTAlarm = CreateNewResourceType(&FreeAlarm, "SyncAlarm");
    RTAwait = CreateNewResourceType(&FreeAwait, "SyncAwait");
    RTFence = CreateNewResourceType(&FreeFence, "SyncFence");
    if (RTAwait)
        RTAwait |= RC_NEVERRETAIN;
    RTAlarmClient = CreateNewResourceType(&FreeAlarmClient, "SyncAlarmClient");
    if (RTAlarmClient)
        RTAlarmClient |= RC_NEVERRETAIN;

    if (RTCounter == 0 || RTAwait == 0 || RTAlarm == 0 ||
        RTAlarmClient == 0 ||
        (extEntry = AddExtension(SYNC_NAME,
                                 cast(int)XSyncNumberEvents, cast(int)XSyncNumberErrors,
                                 &ProcSyncDispatch, &ProcSyncDispatch,
                                 &SyncResetProc, &StandardMinorOpcode)) is null) {
        ErrorF("Sync Extension %d.%d failed to Initialise\n",
               SYNC_MAJOR_VERSION, SYNC_MINOR_VERSION);
        return;
    }

    SyncEventBase = extEntry.eventBase;
    SyncErrorBase = extEntry.errorBase;
    EventSwapVector[SyncEventBase + XSyncCounterNotify] =
        cast(EventSwapPtr) &SCounterNotifyEvent;
    EventSwapVector[SyncEventBase + XSyncAlarmNotify] =
        cast(EventSwapPtr) &SAlarmNotifyEvent;

    SetResourceTypeErrorValue(RTCounter, cast(int)(SyncErrorBase + XSyncBadCounter));
    SetResourceTypeErrorValue(RTAlarm, cast(int)(SyncErrorBase + XSyncBadAlarm));
    SetResourceTypeErrorValue(RTFence, cast(int)(SyncErrorBase + XSyncBadFence));

    /*
     * Although SERVERTIME is implemented by the OS layer, we initialise it
     * here because doing it in OsInit() is too early. The resource database
     * is not initialised when OsInit() is called. This is just about OK
     * because there is always a servertime counter.
     */
    SyncInitServerTime();
    SyncInitIdleTime();

version (DEBUG) {
    fprintf(stderr, "Sync Extension %d.%d\n",
            SYNC_MAJOR_VERSION, SYNC_MINOR_VERSION);
}
}

/*
 * ***** SERVERTIME implementation - should go in its own file in OS directory?
 */

private void* ServertimeCounter;
private long Now;
private long* pnext_time;

private void GetTime()
{
    c_ulong millis = GetTimeInMillis();
    c_ulong maxis = Now >> 32;

    if (millis < (Now & 0xffffffff))
        maxis++;

    Now = (cast(long)maxis << 32) | millis;
}

/*
*** Server Block Handler
*** code inspired by multibuffer extension (now deprecated)
 */
/*ARGSUSED*/ private void ServertimeBlockHandler(void* env, void* wt)
{
    c_ulong timeout = void;

    if (pnext_time) {
        GetTime();

        if (Now >= *pnext_time) {
            timeout = 0;
        }
        else {
            timeout = *pnext_time - Now;
        }
        AdjustWaitForDelay(wt, cast(int)timeout);        /* os/utils.c */
    }
}

/*
*** Wakeup Handler
 */
/*ARGSUSED*/ private void ServertimeWakeupHandler(void* env, int rc)
{
    if (pnext_time) {
        GetTime();

        if (Now >= *pnext_time) {
            SyncChangeCounter(cast(SyncCounter*)ServertimeCounter, cast(long)Now);
        }
    }
}

private void ServertimeQueryValue(void* pCounter, long* pValue_return)
{
    GetTime();
    *pValue_return = Now;
}

private void ServertimeBracketValues(void* pCounter, long* pbracket_less, long* pbracket_greater)
{
    if (!pnext_time && pbracket_greater) {
        RegisterBlockAndWakeupHandlers(&ServertimeBlockHandler,
                                       &ServertimeWakeupHandler, null);
    }
    else if (pnext_time && !pbracket_greater) {
        RemoveBlockAndWakeupHandlers(&ServertimeBlockHandler,
                                     &ServertimeWakeupHandler, null);
    }
    pnext_time = pbracket_greater;
}

private void SyncInitServerTime()
{
    long resolution = 4;

    Now = GetTimeInMillis();
    ServertimeCounter = SyncCreateSystemCounter("SERVERTIME", Now, resolution,
                                                XSyncCounterNeverDecreases,
                                                &ServertimeQueryValue,
                                                &ServertimeBracketValues);
    pnext_time = null;
}

/*
 * IDLETIME implementation
 */

struct IdleCounterPriv {
    long* value_less;
    long* value_greater;
    int deviceid;
}

private void IdleTimeQueryValue(void* pCounter, long* pValue_return)
{
    int deviceid = XIAllDevices;
    CARD32 idle = void;

    if (pCounter) {
        SyncCounter* counter = cast(SyncCounter*)pCounter;
        IdleCounterPriv* priv = cast(IdleCounterPriv*)SysCounterGetPrivate(counter);
        if (priv)
            deviceid = priv.deviceid;
    }
    idle = GetTimeInMillis() - LastEventTime(deviceid).milliseconds;
    *pValue_return = idle;
}

private void IdleTimeBlockHandler(void* pCounter, void* wt)
{
    SyncCounter* counter = cast(SyncCounter*)pCounter;
    IdleCounterPriv* priv = cast(IdleCounterPriv*)SysCounterGetPrivate(counter);
    assert(priv !is null);
    long* less = priv.value_less;
    long* greater = priv.value_greater;
    long idle = void, old_idle = void;
    SyncTriggerList* list = counter.sync.pTriglist;
    SyncTrigger* trig = void;

    if (!less && !greater)
        return;

    old_idle = counter.value;
    IdleTimeQueryValue(counter, &idle);
    counter.value = idle;      /* push, so CheckTrigger works */

    /**
     * There's an indefinite amount of time between ProcessInputEvents()
     * where the idle time is reset and the time we actually get here. idle
     * may be past the lower bracket if we dawdled with the events, so
     * check for whether we did reset and bomb out of select immediately.
     */
    if (less && idle > *less &&
        LastEventTimeWasReset(priv.deviceid)) {
        AdjustWaitForDelay(wt, 0);
    } else if (less && idle <= *less) {
        /*
         * We've been idle for less than the threshold value, and someone
         * wants to know about that, but now we need to know whether they
         * want level or edge trigger.  Check the trigger list against the
         * current idle time, and if any succeed, bomb out of select()
         * immediately so we can reschedule.
         */

        for (list = counter.sync.pTriglist; list; list = list.next) {
            trig = list.pTrigger;
            if (trig.CheckTrigger(trig, old_idle)) {
                AdjustWaitForDelay(wt, 0);
                break;
            }
        }
        /*
         * We've been called exactly on the idle time, but we have a
         * NegativeTransition trigger which requires a transition from an
         * idle time greater than this.  Schedule a wakeup for the next
         * millisecond so we won't miss a transition.
         */
        if (idle == *less)
            AdjustWaitForDelay(wt, 1);
    }
    else if (greater) {
        /*
         * There's a threshold in the positive direction.  If we've been
         * idle less than it, schedule a wakeup for sometime in the future.
         * If we've been idle more than it, and someone wants to know about
         * that level-triggered, schedule an immediate wakeup.
         */

        if (idle < *greater) {
            AdjustWaitForDelay(wt, cast(int)(*greater - idle));
        }
        else {
            for (list = counter.sync.pTriglist; list;
                 list = list.next) {
                trig = list.pTrigger;
                if (trig.CheckTrigger(trig, old_idle)) {
                    AdjustWaitForDelay(wt, 0);
                    break;
                }
            }
        }
    }

    counter.value = old_idle;  /* pop */
}

private void IdleTimeCheckBrackets(SyncCounter* counter, long idle, long* less, long* greater)
{
    if ((greater && idle >= *greater) ||
        (less && idle <= *less)) {
        SyncChangeCounter(counter, idle);
    }
    else
        SyncUpdateCounter(counter, idle);
}

private void IdleTimeWakeupHandler(void* pCounter, int rc)
{
    SyncCounter* counter = cast(SyncCounter*)pCounter;
    IdleCounterPriv* priv = cast(IdleCounterPriv*)SysCounterGetPrivate(counter);
    assert(priv !is null);
    long* less = priv.value_less;
    long* greater = priv.value_greater;
    long idle = void;

    if (!less && !greater)
        return;

    IdleTimeQueryValue(pCounter, &idle);

    /*
      There is no guarantee for the WakeupHandler to be called within a specific
      timeframe. Idletime may go to 0, but by the time we get here, it may be
      non-zero and alarms for a pos. transition on 0 won't get triggered.
      https://bugs.freedesktop.org/show_bug.cgi?id=70476
      */
    if (LastEventTimeWasReset(priv.deviceid)) {
        LastEventTimeToggleResetFlag(priv.deviceid, FALSE);
        if (idle != 0) {
            IdleTimeCheckBrackets(counter, 0, less, greater);
            less = priv.value_less;
            greater = priv.value_greater;
        }
    }

    IdleTimeCheckBrackets(counter, idle, less, greater);
}

private void IdleTimeBracketValues(void* pCounter, long* pbracket_less, long* pbracket_greater)
{
    SyncCounter* counter = cast(SyncCounter*)pCounter;
    IdleCounterPriv* priv = cast(IdleCounterPriv*)SysCounterGetPrivate(counter);
    assert(priv !is null);
    long* less = priv.value_less;
    long* greater = priv.value_greater;
    Bool registered = (less || greater);

    if (registered && !pbracket_less && !pbracket_greater) {
        RemoveBlockAndWakeupHandlers(&IdleTimeBlockHandler,
                                     &IdleTimeWakeupHandler, pCounter);
    }
    else if (!registered && (pbracket_less || pbracket_greater)) {
        /* Reset flag must be zero so we don't force a idle timer reset on
           the first wakeup */
        LastEventTimeToggleResetAll(FALSE);
        RegisterBlockAndWakeupHandlers(&IdleTimeBlockHandler,
                                       &IdleTimeWakeupHandler, pCounter);
    }

    priv.value_greater = pbracket_greater;
    priv.value_less = pbracket_less;
}

private SyncCounter* init_system_idle_counter(const(char)* name, int deviceid)
{
    long resolution = 4;
    long idle = void;
    SyncCounter* idle_time_counter = void;

    IdleTimeQueryValue(null, &idle);

    IdleCounterPriv* priv = cast(IdleCounterPriv*) cast(IdleCounterPriv*) calloc(1, IdleCounterPriv.sizeof);
    if (!priv)
        return null;

    idle_time_counter = SyncCreateSystemCounter(name, idle, resolution,
                                                XSyncCounterUnrestricted,
                                                &IdleTimeQueryValue,
                                                &IdleTimeBracketValues);

    if (!idle_time_counter) {
        free(priv);
        return null;
    }

    priv.value_less = priv.value_greater = null;
    priv.deviceid = deviceid;

    idle_time_counter.pSysCounterInfo.private_ = priv;
    return idle_time_counter;
}

private void SyncInitIdleTime()
{
    init_system_idle_counter("IDLETIME", XIAllDevices);
}

SyncCounter* SyncInitDeviceIdleTime(DeviceIntPtr dev)
{
    char[64] timer_name = void;
    sprintf(timer_name.ptr, "DEVICEIDLETIME %d", dev.id);

    return init_system_idle_counter(timer_name.ptr, dev.id);
}

void SyncRemoveDeviceIdleTime(SyncCounter* counter)
{
    /* FreeAllResources() frees all system counters before the devices are
       shut down, check if there are any left before freeing the device's
       counter */
    if (counter && !xorg_list_is_empty(&SysCounterList))
        xorg_list_del(&counter.pSysCounterInfo.entry);
}
