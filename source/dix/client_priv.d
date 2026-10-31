module dix.client_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import dix.callback;
import dix.dixstruct_priv;
import dix.dispatch;

/*
 * called right before ClientRec is about to be destroyed,
 * after resources have been freed. argument is ClientPtr
 */
CallbackListPtr ClientDestroyCallback;

struct ClientAccessCallbackParam {
    ClientPtr client;
    ClientPtr target;
    Mask access_mode;
    int status;
}

/*
 * called when a client tries to access another client
 */
// CallbackListPtr ClientAccessCallback;

pragma(inline, true) int dixCallClientAccessCallback(ClientPtr client, ClientPtr target, Mask access_mode)
{
    ClientAccessCallbackParam rec = { client, target, access_mode, Success };
    CallCallbacks(&ClientAccessCallback, &rec);
    return rec.status;
}

 /* _XSERVER_DIX_CLIENT_PRIV_H */
