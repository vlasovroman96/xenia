module os.io_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import x11.Xdefs;
// public import x11.Xdefs;
import x11.Xmd;
import dix.dixstruct_priv;
import dix.input;

import os.io;
import os.Xtransint;

// struct _XtransConnInfo;

// alias XtransConnInfo = _XtransConnInfo*;

alias ConnectionInputPtr = _connectionInput*;
alias ConnectionOutputPtr = _connectionOutput*;

struct _OsCommRec {
    int fd;
    ConnectionInputPtr input;
    ConnectionOutputPtr output;
    XID auth_id;
    CARD32 conn_time;
    _XtransConnInfo* trans_conn;
    int flags;
}alias OsCommRec = _OsCommRec;
alias OsCommPtr = OsCommRec*;

// int FlushClient(ClientPtr who, OsCommPtr oc);
// void FreeOsBuffers(OsCommPtr oc);
// void CloseDownFileDescriptor(OsCommPtr oc);

 /* __XORG_OS_IO_H */
