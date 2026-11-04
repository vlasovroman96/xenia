module include.misync;
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
 
public import include.scrintstr;

import include.misyncstr;

alias SyncObject = _SyncObject;
alias SyncFence = _SyncFence;
alias SyncTrigger = _SyncTrigger;

alias SyncScreenCreateFenceFunc = void function(ScreenPtr pScreen, SyncFence* pFence, Bool initially_triggered);
alias SyncScreenDestroyFenceFunc = void function(ScreenPtr pScreen, SyncFence* pFence);

struct _syncScreenFuncs {
    SyncScreenCreateFenceFunc CreateFence;
    SyncScreenDestroyFenceFunc DestroyFence;
}alias SyncScreenFuncsRec = _syncScreenFuncs;
alias SyncScreenFuncsPtr = _syncScreenFuncs*;

// void miSyncScreenCreateFence(ScreenPtr pScreen, SyncFence* pFence, Bool initially_triggered);
// void miSyncScreenDestroyFence(ScreenPtr pScreen, SyncFence* pFence);

alias SyncFenceSetTriggeredFunc = void function(SyncFence* pFence);
alias SyncFenceResetFunc = void function(SyncFence* pFence);
alias SyncFenceCheckTriggeredFunc = Bool function(SyncFence* pFence);
alias SyncFenceAddTriggerFunc = void function(SyncTrigger* pTrigger);
alias SyncFenceDeleteTriggerFunc = void function(SyncTrigger* pTrigger);

struct _syncFenceFuncs {
    SyncFenceSetTriggeredFunc SetTriggered;
    SyncFenceResetFunc Reset;
    SyncFenceCheckTriggeredFunc CheckTriggered;
    SyncFenceAddTriggerFunc AddTrigger;
    SyncFenceDeleteTriggerFunc DeleteTrigger;
}alias SyncFenceFuncsRec = _syncFenceFuncs;
alias SyncFenceFuncsPtr = _syncFenceFuncs*;

// void miSyncInitFence(ScreenPtr pScreen, SyncFence* pFence, Bool initially_triggered);

// void miSyncDestroyFence(SyncFence* pFence);

// void miSyncTriggerFence(SyncFence* pFence);

// void miSyncGetScreenFuncs(ScreenPtr pScreen);
// void miSyncSetup(ScreenPtr pScreen);

                          /* _MISYNC_H_ */
