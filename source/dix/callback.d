module dix.callback;
@nogc nothrow:
extern(C): __gshared:
/*
 *  Generic Callback Manager
 */

/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright (c) 2026, Roman Vlasov
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
import x11.Xdefs;
import dix.dixutils;
import core.stdc.stdlib;
import os.alloc;

private size_t numCallbackListsToCleanup = 0;
private CallbackListPtr** listsToCleanup = null;

alias ServerBlockHandlerProcPtr = void function(void* blockData, void* timeout);

alias ServerWakeupHandlerProcPtr = void function(void* blockData, int result);

struct CallbackRec {
    CallbackProcPtr proc;
    void* data;
    Bool deleted;
    CallbackRec* next;
}
alias CallbackPtr = CallbackRec*;

struct CallbackListRec {
    int inCallback;
    Bool deleted;
    int numDeleted;
    CallbackPtr list;
}
alias CallbackListPtr = CallbackListRec*;

private Bool _AddCallback(CallbackListPtr* pcbl, CallbackProcPtr callback, void* data)
{
    CallbackPtr cbr = cast(CallbackRec*) calloc(1, CallbackRec.sizeof);
    if (!cbr)
        return False;
    cbr.proc = callback;
    cbr.data = data;
    cbr.next = (*pcbl).list;
    cbr.deleted = False;
    (*pcbl).list = cbr;
    return True;
}

private Bool _DeleteCallback(CallbackListPtr* pcbl, CallbackProcPtr callback, void* data)
{
    CallbackListPtr cbl = *pcbl;
    CallbackPtr cbr = void, pcbr = void;

    for (pcbr = null, cbr = cbl.list; cbr !is null; pcbr = cbr, cbr = cbr.next) {
        if ((cbr.proc == callback) && (cbr.data == data))
            break;
    }
    if (cbr !is null) {
        if (cbl.inCallback) {
            ++(cbl.numDeleted);
            cbr.deleted = True;
        }
        else {
            if (pcbr is null)
                cbl.list = cbr.next;
            else
                pcbr.next = cbr.next;
            free(cbr);
        }
        return True;
    }
    return False;
}

void _CallCallbacks(CallbackListPtr* pcbl, void* call_data)
{
    CallbackListPtr cbl = *pcbl;
    CallbackPtr cbr = void, pcbr = void;

    ++(cbl.inCallback);
    for (cbr = cbl.list; cbr !is null; cbr = cbr.next) {
        (*(cbr.proc)) (pcbl, cbr.data, call_data);
    }
    --(cbl.inCallback);

    if (cbl.inCallback)
        return;

    /* Was the entire list marked for deletion? */

    if (cbl.deleted) {
        DeleteCallbackList(pcbl);
        return;
    }

    /* Were some individual callbacks on the list marked for deletion?
     * If so, do the deletions.
     */

    if (cbl.numDeleted) {
        for (pcbr = null, cbr = cbl.list; (cbr !is null) && cbl.numDeleted;) {
            if (cbr.deleted) {
                if (pcbr) {
                    cbr = cbr.next;
                    free(pcbr.next);
                    pcbr.next = cbr;
                }
                else {
                    cbr = cbr.next;
                    free(cbl.list);
                    cbl.list = cbr;
                }
                cbl.numDeleted--;
            }
            else {              /* this one wasn't deleted */

                pcbr = cbr;
                cbr = cbr.next;
            }
        }
    }
}

void DeleteCallbackList(CallbackListPtr* pcbl)
{
    if (!pcbl || !*pcbl)
        return;

    CallbackListPtr cbl = *pcbl;

    if (cbl.inCallback) {
        cbl.deleted = True;
        return;
    }

    for (size_t i = 0; i < numCallbackListsToCleanup; i++) {
        if (listsToCleanup[i] == pcbl) {
            listsToCleanup[i] = null;
            break;
        }
    }

    for (CallbackPtr cbr = cbl.list, nextcbr = void; cbr !is null; cbr = nextcbr) {
        nextcbr = cbr.next;
        free(cbr);
    }
    free(cbl);
    *pcbl = null;
}

private Bool CreateCallbackList(CallbackListPtr* pcbl)
{
    if (!pcbl)
        return False;

    CallbackListPtr cbl = cast(CallbackListRec*) calloc(1, CallbackListRec.sizeof);
    if (!cbl)
        return False;
    cbl.inCallback = 0;
    cbl.deleted = False;
    cbl.numDeleted = 0;
    cbl.list = null;
    *pcbl = cbl;

    for (size_t i = 0; i < numCallbackListsToCleanup; i++) {
        if (!listsToCleanup[i]) {
            listsToCleanup[i] = pcbl;
            return True;
        }
    }

    listsToCleanup = cast(CallbackListPtr**) XNFrealloc(listsToCleanup,
                                                     (CallbackListPtr*).sizeof *
                                                     (numCallbackListsToCleanup
                                                      + 1));
    listsToCleanup[numCallbackListsToCleanup] = pcbl;
    numCallbackListsToCleanup++;
    return True;
}

/* ===== Public Procedures ===== */

Bool AddCallback(CallbackListPtr* pcbl, CallbackProcPtr callback, void* data)
{
    if (!pcbl)
        return False;
    if (!*pcbl) {               /* list hasn't been created yet; go create it */
        if (!CreateCallbackList(pcbl))
            return False;
    }
    return _AddCallback(pcbl, callback, data);
}

Bool DeleteCallback(CallbackListPtr* pcbl, CallbackProcPtr callback, void* data)
{
    if (!pcbl || !*pcbl)
        return False;
    return _DeleteCallback(pcbl, callback, data);
}

void DeleteCallbackManager()
{
    for (size_t i = 0; i < numCallbackListsToCleanup; i++) {
        DeleteCallbackList(listsToCleanup[i]);
    }
    free(listsToCleanup);

    numCallbackListsToCleanup = 0;
    listsToCleanup = null;
}

void InitCallbackManager()
{
    DeleteCallbackManager();
}

alias CallbackProcPtr = void function(CallbackListPtr*, void*, void*) @nogc nothrow;

pragma(inline, true) void CallCallbacks(CallbackListPtr* pcbl, void* call_data)
{
    if (!pcbl || !*pcbl)
        return;
    _CallCallbacks(pcbl, call_data);
}
