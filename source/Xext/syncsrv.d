module Xext.syncsrv;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1991, 1993, 1994, 1998  The Open Group

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

*/

/***********************************************************
Copyright 1991,1993 by Digital Equipment Corporation, Maynard, Massachusetts,
and Olivetti Research Limited, Cambridge, England.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the names of Digital or Olivetti
not be used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL AND OLIVETTI DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS, IN NO EVENT SHALL THEY BE LIABLE FOR ANY SPECIAL, INDIRECT OR
CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF
USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR
OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
PERFORMANCE OF THIS SOFTWARE.

******************************************************************/

 
public import mi.misync;
public import mi.misyncstr;
import externs.X11.extensions.syncconst;

/*
 * The System Counter interface
 */

enum SyncCounterType {
    XSyncCounterNeverChanges,
    XSyncCounterNeverIncreases,
    XSyncCounterNeverDecreases,
    XSyncCounterUnrestricted
}
alias XSyncCounterNeverChanges = SyncCounterType.XSyncCounterNeverChanges;
alias XSyncCounterNeverIncreases = SyncCounterType.XSyncCounterNeverIncreases;
alias XSyncCounterNeverDecreases = SyncCounterType.XSyncCounterNeverDecreases;
alias XSyncCounterUnrestricted = SyncCounterType.XSyncCounterUnrestricted;


alias SyncSystemCounterQueryValue = void function(void* counter, long* value_return);
alias SyncSystemCounterBracketValues = void function(void* counter, long* pbracket_less, long* pbracket_greater);

struct _SysCounterInfo {
    _SyncCounter* pCounter;
    char* name;
    long resolution;
    long bracket_greater;
    long bracket_less;
    SyncCounterType counterType;        /* how can this counter change */
    SyncSystemCounterQueryValue QueryValue;
    SyncSystemCounterBracketValues BracketValues;
    void* private_;
    xorg_list entry;
}
alias SysCounterInfo = _SysCounterInfo;

struct _SyncAlarmClientList {
    ClientPtr client;
    XID delete_id;
    _SyncAlarmClientList* next;
}

alias SyncAlarmClientList = _SyncAlarmClientList;

struct _SyncAlarm {
    SyncTrigger trigger;
    ClientPtr client;
    XSyncAlarm alarm_id;
    long delta;
    int events;
    int state;
    _SyncAlarmClientList* pEventClients;
}

alias SyncAlarm = _SyncAlarm;

struct _SyncAwaitHeader {
    ClientPtr client;
    CARD32 delete_id;
    int num_waitconditions;
}

struct _SyncAwait {
    SyncTrigger trigger;
    long event_threshold;
    _SyncAwaitHeader* pHeader;
}

alias SyncAwait = _SyncAwait;

union SyncAwaitUnion {
    _SyncAwaitHeader header;
    _SyncAwait await;
}

SyncCounter* SyncCreateSystemCounter(const(char)* name, long initial_value, long resolution, SyncCounterType counterType, SyncSystemCounterQueryValue QueryValue, SyncSystemCounterBracketValues BracketValues);

void SyncChangeCounter(SyncCounter* pCounter, long new_value);

void SyncDestroySystemCounter(void* pCounter);

SyncCounter* SyncInitDeviceIdleTime(DeviceIntPtr dev);
void SyncRemoveDeviceIdleTime(SyncCounter* counter);

// int SyncCreateFenceFromFD(ClientPtr client, DrawablePtr pDraw, XID id, int fd, BOOL initially_triggered);

// int SyncFDFromFence(ClientPtr client, DrawablePtr pDraw, SyncFence* fence);

void SyncDeleteTriggerFromSyncObject(SyncTrigger* pTrigger);

int SyncAddTriggerToSyncObject(SyncTrigger* pTrigger);

                          /* _SYNCSRV_H_ */
