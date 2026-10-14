module include.dixstruct;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************
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

 
public import x11.Xmd;

public import include.xlibre_ptrtypes;

public import dix.callback;
public import include.dix;
public import include.resource;
public import dix.cursor;
public import include.gc;
public import include.pixmap;
public import include.privates;
public import dix.globals;
import os.client_priv;
/*
 * 	direct-mapped hash table, used by resource manager to store
 *      translation from client ids to server addresses.
 */

// CallbackListPtr ClientStateCallback;

struct NewClientInfoRec {
    ClientPtr client;
    xConnSetupPrefix* prefix;
    xConnSetup* setup;
}

alias ReplySwapPtr = void function(ClientPtr, int, void*);

enum ClientState { ClientStateInitial,
    ClientStateRunning,
    ClientStateRetained,
    ClientStateGone
}
alias ClientStateInitial = ClientState.ClientStateInitial;
alias ClientStateRunning = ClientState.ClientStateRunning;
alias ClientStateRetained = ClientState.ClientStateRetained;
alias ClientStateGone = ClientState.ClientStateGone;


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
    xorg_list ready;      /* List of clients ready to run */
    xorg_list output_pending; /* List of clients with output queued */
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

public import externs.X11.fonts.fontproto;
// alias ClientPtr = ._Client*;

// TimeStamp currentTime;

// int CompareTimeStamps(TimeStamp, TimeStamp);

// TimeStamp ClientTimeToServerTime(CARD32);

/* proc vectors */

//  int function(ClientPtr)[256] ProcVector;

//  int function(ClientPtr)[256] SwappedProcVector;

/* fixme: still needed by (public) dix.h */
// ReplySwapPtr[256] ReplySwapVector;

                          /* DIXSTRUCT_H */
