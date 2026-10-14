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

public import include.dix;
public import include.resource;
public import dix.cursor;
public import include.gc;
public import include.pixmap;
public import include.privates;
public import include.dixstruct;
import os.log;
public import tables;

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

// xorg_list output_pending_clients;

pragma(inline, true) void output_pending_mark(ClientPtr client)
{
    if (!client.clientGone && xorg_list_is_empty(&client.output_pending))
        xorg_list_append(&client.output_pending, &output_pending_clients);
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
