module mi.misyncstr;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2010 NVIDIA Corporation
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
 */
 
public import core.stdc.stdint;

public import include.xlibre_ptrtypes;
public import mi.misync;
public import dix.scrnintstr;
import Xext.syncsrv;

// //public import externs.X11.extensions.syncconst;

/* Sync object types */
enum SYNC_COUNTER =		0;
enum SYNC_FENCE =		1;

struct _SyncObject {
    ClientPtr client;           /* Owning client. 0 for system counters */
    _SyncTriggerList* pTriglist; /* list of triggers */
    XID id;                     /* resource ID */
    ubyte type;         /* SYNC_* */
    ubyte initialized;  /* FALSE if created but not initialized */
    Bool beingDestroyed;        /* in process of going away */
}

struct _SyncCounter {
    SyncObject sync;            /* Common sync object data */
    long value;              /* counter value */
    _SysCounterInfo* pSysCounterInfo; /* NULL if not a system counter */
}

alias SyncCounter = _SyncCounter;

struct _SyncFence {
    SyncObject sync;            /* Common sync object data */
    ScreenPtr pScreen;          /* Screen of this fence object */
    SyncFenceFuncsRec funcs;    /* Funcs for performing ops on fence */
    Bool triggered;             /* fence state */
    PrivateRec* devPrivates;    /* driver-specific per-fence data */
}

struct _SyncTrigger {
    SyncObject* pSync;
    long wait_value;         /* wait value */
    uint value_type;    /* Absolute or Relative */
    uint test_type;     /* transition or Comparison type */
    long test_value;         /* trigger event threshold value */
    Bool function(_SyncTrigger* pTrigger, long newval) @nogc nothrow CheckTrigger;
    void function(_SyncTrigger* pTrigger) @nogc nothrow TriggerFired;
    void function(_SyncTrigger* pTrigger) @nogc nothrow CounterDestroyed;
}

struct _SyncTriggerList {
    SyncTrigger* pTrigger;
    _SyncTriggerList* next;
}

alias SyncTriggerList = _SyncTriggerList;

                          /* _MISYNCSTR_H_ */
