module geext;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2007-2008 Peter Hutterer
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
 *
 * Author: Peter Hutterer, University of South Australia, NICTA
 */

import build.dix_config;

import externs.X11.extensions.geproto;
// // //import externs.X11.extensions.geproto;
//import x11.X;

import dix.dix_priv;
import dix.request_priv;
import miext.extinit_priv;
import Xext.geext_priv;

import include.windowstr;
import include.protocol_versions;
import os.log;
import dix.extension;
import dix.events;

enum MAXEXTENSIONS =   128;

DevPrivateKeyRec GEClientPrivateKeyRec;

/** Struct to keep information about registered extensions */
struct _GEExtension {
    /** Event swapping routine */
    nothrow @nogc void function(xGenericEvent* from, xGenericEvent* to) evswap;
}alias GEExtension = _GEExtension;
alias GEExtensionPtr = _GEExtension*;

private GEExtension[MAXEXTENSIONS] GEExtensions;

struct _GEClientInfo {
    CARD32 major_version;
    CARD32 minor_version;
}alias GEClientInfoRec = _GEClientInfo;
alias GEClientInfoPtr = _GEClientInfo*;

enum string GEGetClient(string pClient) = `(cast(GEClientInfoPtr)(dixLookupPrivate(&((` ~ pClient ~ `).devPrivates), &GEClientPrivateKeyRec)))`;

/* Forward declarations */


enum string EXT_MASK(string ext) = `((` ~ ext ~ `) & 0x7F)`;

/************************************************************/
/*                request handlers                          */
/************************************************************/

private int ProcGEQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xGEQueryVersionReq);
    mixin(X_REQUEST_FIELD_CARD16!("majorVersion"));
    mixin(X_REQUEST_FIELD_CARD16!("minorVersion"));

    GEClientInfoPtr pGEClient = mixin(GEGetClient!(`client`));

    xGEQueryVersionReply reply = {
        RepType: X_GEQueryVersion,
        /* return the supported version by the server */
        majorVersion: SERVER_GE_MAJOR_VERSION,
        minorVersion: SERVER_GE_MINOR_VERSION
    };

    /* Remember version the client requested */
    pGEClient.major_version = stuff.majorVersion;
    pGEClient.minor_version = stuff.minorVersion;

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/************************************************************/
/*                callbacks                                 */
/************************************************************/

/* dispatch requests */
private int ProcGEDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
    case X_GEQueryVersion:
        return ProcGEQueryVersion(client);
    default:
        return BadRequest;
    }
}

/* Reset extension. Called on server shutdown. */
private void GEResetProc(_ExtensionEntry* extEntry)
{
    EventSwapVector[GenericEvent] = &NotImplemented;
}

/*  Calls the registered event swap function for the extension.
 *
 *  Each extension can register a swap function to handle GenericEvents being
 *  swapped properly. The server calls SGEGenericEvent() before the event is
 *  written on the wire, this one calls the registered swap function to do the
 *  work.
 */
private void SGEGenericEvent(xEvent* from, xEvent* to)
{
    xGenericEvent* gefrom = cast(xGenericEvent*) from;
    xGenericEvent* geto = cast(xGenericEvent*) to;

    if ((gefrom.extension & 0x7f) > MAXEXTENSIONS) {
        // ErrorF("GE: Invalid extension offset for event.\n");
        return;
    }

    if (GEExtensions[mixin(EXT_MASK!(`gefrom.extension`))].evswap)
        GEExtensions[mixin(EXT_MASK!(`gefrom.extension`))].evswap(gefrom, geto);
}

/* Init extension, register at server.
 * Since other extensions may rely on XGE (XInput does already), it is a good
 * idea to init XGE first, before any other extension.
 */
void GEExtensionInit()
{
    if (!dixRegisterPrivateKey
        (&GEClientPrivateKeyRec, PRIVATE_CLIENT, GEClientInfoRec.sizeof))
        FatalError("GEExtensionInit: GE private request failed.\n");

    if (!AddExtension(GE_NAME, 0, GENumberErrors, &ProcGEDispatch, &ProcGEDispatch,
                      &GEResetProc, &StandardMinorOpcode))
        FatalError("GEInit: AddExtensions failed.\n");

    memset(GEExtensions.ptr, 0, GEExtensions.sizeof);
    EventSwapVector[GenericEvent] = cast(EventSwapPtr) &SGEGenericEvent;
}

/************************************************************/
/*                interface for extensions                  */
/************************************************************/

/* Register an extension with GE. The given swap function will be called each
 * time an event is sent to a client with different byte order.
 * @param extension The extensions major opcode
 * @param ev_swap The event swap function.
 * @param ev_fill Called for an event before delivery. The extension now has
 * the chance to fill in necessary fields for the event.
 */
void GERegisterExtension(int extension, void function(xGenericEvent* from, xGenericEvent* to) nothrow @nogc   ev_swap)
{
    if (mixin(EXT_MASK!(`extension`)) >= MAXEXTENSIONS)
        FatalError("GE: extension > MAXEXTENSIONS. This should not happen.\n");

    /* extension opcodes are > 128, might as well save some space here */
    GEExtensions[mixin(EXT_MASK!(`extension`))].evswap = ev_swap;
}
