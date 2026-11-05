module dix.dixstruct_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xmd;

public import dix.resource;
public import dix.cursor;
public import dix.gc;
public import dix.pixmap;
public import dix.privates;
import os.log;
public import tables;
import dix.dispatch;
public import dix.globals;
import os.client_priv;

struct NewClientInfoRec {
    ClientPtr client;
    xConnSetupPrefix* prefix;
    xConnSetup* setup;
}

enum ClientState { ClientStateInitial,
    ClientStateRunning,
    ClientStateRetained,
    ClientStateGone
}
alias ClientStateInitial = ClientState.ClientStateInitial;
alias ClientStateRunning = ClientState.ClientStateRunning;
alias ClientStateRetained = ClientState.ClientStateRetained;
alias ClientStateGone = ClientState.ClientStateGone;

alias ReplySwapPtr = void function(ClientPtr, int, void*);


struct SaveSetElt {
    _Window* windowPtr;
    Bool toRoot;
    Bool map;
}
enum string SaveSetWindow(string ss) = `((` ~ ss ~ `).windowPtr)`;
enum string SaveSetToRoot(string ss) = `((` ~ ss ~ `).toRoot)`;
enum string SaveSetShouldMap(string ss) = `((` ~ ss ~ `).map)`;
enum string SaveSetAssignWindow(string ss,string w) = `((` ~ ss ~ `).windowPtr = (` ~ w ~ `));`;
enum string SaveSetAssignToRoot(string ss,string tr) = `((` ~ ss ~ `).toRoot = (` ~ tr ~ `));`;
enum string SaveSetAssignMap(string ss,string m) = `((` ~ ss ~ `).map = (` ~ m ~ `));`;

struct _Client {
    void* requestBuffer;
    void* osPrivate;             /* for OS layer, including scheduler */
    XList ready;      /* List of clients ready to run */
    XList output_pending; /* List of clients with output queued */
    Mask clientAsMask;
    ushort index;
    ubyte majorOp, minorOp;
    uint swapped: 1;
    uint local: 1;
    uint big_requests: 1; /* supports large requests */
    uint clientGone: 1;
    uint closeDownMode : 2;
    uint clientState : 2;
    char smart_priority = 0;
    short noClientException;      /* this client died or needs to be killed */
    int priority;
    ReplySwapPtr pSwapReplyFunc;
    XID errorValue;
    int sequence;
    int ignoreCount;            /* count for Attend/IgnoreClient */
    uint numSaved;          /* amount of windows in saveSet */
    SaveSetElt* saveSet;
    @nogc nothrow int function(ClientPtr)* requestVector;
    CARD32 req_len;             /* length of current request */
    uint replyBytesRemaining;
    PrivateRec* devPrivates;
    ushort mapNotifyMask;
    ushort newKeyboardNotifyMask;
    ubyte xkbClientFlags;
    KeyCode minKC, maxKC;

    int smart_start_tick;
    int smart_stop_tick;

    DeviceIntPtr clientPtr;
    _ClientId* clientIds;
    int req_fds;
}

alias ClientPtr = _Client*;

public import externs.X11.fonts.fontproto;

pragma(inline, true) void SetReqFds(ClientPtr client, int req_fds) {
    if (client.req_fds != 0 && req_fds != client.req_fds)
        LogMessage(X_ERROR, "Mismatching number of request fds %d != %d\n", req_fds, client.req_fds);
    client.req_fds = req_fds;
}

/*
 * Scheduling interface
 */
c_long SmartScheduleTime;
// c_long SmartScheduleInterval;
// c_long SmartScheduleSlice;
// c_long SmartScheduleMaxSlice;
static if (HAVE_SETITIMER) {
// Bool SmartScheduleSignalEnable;
} else {
enum SmartScheduleSignalEnable = FALSE;
}
// void SmartScheduleStartTimer();
// void SmartScheduleStopTimer();

/* Client has requests queued or data on the network */
// void mark_client_ready(ClientPtr client);

/*
 * Client has requests queued or data on the network, but awaits a
 * server grab release
 */
// void mark_client_saved_ready(ClientPtr client);

/* Client has no requests queued and no data on network */
// void mark_client_not_ready(ClientPtr client);

pragma(inline, true) Bool client_is_ready(ClientPtr client)
{
    return !xorg_list_is_empty(&client.ready);
}

// Bool clients_are_ready();

// XList output_pending_clients;

pragma(inline, true) void output_pending_mark(ClientPtr client)
{
    if (!client.clientGone && xorg_list_is_empty(&client.output_pending))
        output_pending_clients.appendList(&client.output_pending);
}

pragma(inline, true) void output_pending_clear(ClientPtr client)
{
    xorg_list_del(&client.output_pending);
}

pragma(inline, true) Bool any_output_pending() {
    return !xorg_list_is_empty(&output_pending_clients);
}

enum SMART_MAX_PRIORITY =  (20);
enum SMART_MIN_PRIORITY =  (-20);

// void SmartScheduleInit();

/* This prototype is used pervasively in Xext, dix */
enum string DISPATCH_PROC(string func) = `int func(ClientPtr);`;

/* proc vectors */

// int function(ClientPtr)[3] InitialVector;

 /* _XSERVER_DIXSTRUCT_PRIV_H */
