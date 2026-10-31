module dix.server_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import dix.callback;
import include.dixstruct;
import dix.dispatch;

struct ServerAccessCallbackParam {
    ClientPtr client;
    Mask access_mode;
    int status;
}

// CallbackListPtr ServerAccessCallback;

pragma(inline, true) int dixCallServerAccessCallback(ClientPtr client, Mask access_mode)
{
    ServerAccessCallbackParam rec = { client, access_mode, Success };
    CallCallbacks(&ServerAccessCallback, &rec);
    return rec.status;
}

/* NVidia v.390 proprietary driver needs this */
// void * ConnectionInfo;

 /* _XSERVER_DIX_SERVER_PRIV_H */
