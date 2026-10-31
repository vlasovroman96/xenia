module dix.selection_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */

 
//public import x11.Xdefs;
//public import x11.Xproto;

public import include.dixstruct;
public import include.privates;
import dix.timestamp;

struct _Selection {
    Atom selection;
    TimeStamp lastTimeChanged;
    Window window;
    WindowPtr pWin;
    ClientPtr client;
    _Selection* next;
    PrivateRec* devPrivates;
}

alias Selection = _Selection;

enum SelectionCallbackKind {
    SelectionSetOwner,
    SelectionWindowDestroy,
    SelectionClientClose
}
alias SelectionSetOwner = SelectionCallbackKind.SelectionSetOwner;
alias SelectionWindowDestroy = SelectionCallbackKind.SelectionWindowDestroy;
alias SelectionClientClose = SelectionCallbackKind.SelectionClientClose;


struct SelectionInfoRec {
    _Selection* selection;
    ClientPtr client;
    SelectionCallbackKind kind;
}

enum SELECTION_FILTER_GETOWNER =       1;
enum SELECTION_FILTER_SETOWNER =       2;
enum SELECTION_FILTER_CONVERT =        3;
enum SELECTION_FILTER_LISTEN =         4;
enum SELECTION_FILTER_EV_REQUEST =     5;
enum SELECTION_FILTER_EV_CLEAR =       6;
enum SELECTION_FILTER_NOTIFY =         7;

struct _SelectionFilterParamRec {
    int op;
    Bool skip;
    int status;
    Atom selection;
    ClientPtr client;       // initiating client
    ClientPtr recvClient;   // client receiving event
    Time time;              // request time stamp
    Window requestor;
    Window owner;
    Atom property;
    Atom target;
}alias SelectionFilterParamRec = _SelectionFilterParamRec;
alias SelectionFilterParamPtr = SelectionFilterParamRec*;

_Selection* CurrentSelections;

CallbackListPtr SelectionCallback;
CallbackListPtr SelectionFilterCallback;

int dixLookupSelection(_Selection** result, Atom name, ClientPtr client, Mask access_mode);

void InitSelections();
void DeleteWindowFromAnySelections(WindowPtr pWin);
void DeleteClientFromAnySelections(ClientPtr client);

 /* _XSERVER_DIX_SELECTION_PRIV_H */
