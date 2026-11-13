module Xext.xvmain;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************
Copyright 1991 by Digital Equipment Corporation, Maynard, Massachusetts,
and the Massachusetts Institute of Technology, Cambridge, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the names of Digital or MIT not be
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

/*
** File:
**
**   xvmain.c --- Xv server extension main device independent module.
**
** Author:
**
**   David Carver (Digital Workstation Engineering/Project Athena)
**
** Revisions:
**
**   04.09.91 Carver
**     - change: stop video always generates an event even when video
**       wasn't active
**
**   29.08.91 Carver
**     - change: unrealizing windows no longer preempts video
**
**   11.06.91 Carver
**     - changed SetPortControl to SetPortAttribute
**     - changed GetPortControl to GetPortAttribute
**     - changed QueryBestSize
**
**   28.05.91 Carver
**     - fixed Put and Get requests to not preempt operations to same drawable
**
**   15.05.91 Carver
**     - version 2.0 upgrade
**
**   19.03.91 Carver
**     - fixed Put and Get requests to honor grabbed ports.
**     - fixed Video requests to update di structure with new drawable, and
**       client after calling ddx.
**
**   24.01.91 Carver
**     - version 1.4 upgrade
**
** Notes:
**
**   Port structures reference client structures in a two different
**   ways: when grabs, or video is active.  Each reference is encoded
**   as fake client resources and thus when the client is goes away so
**   does the reference (it is zeroed).  No other action is taken, so
**   video doesn't necessarily stop.  It probably will as a result of
**   other resources going away, but if a client starts video using
**   none of its own resources, then the video will continue to play
**   after the client disappears.
**
**
*/

import build.xlibre_server;
import Xext.panoramiXsrv;
import core.stdc.string;
import dix.dispatch;
//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.Xv;
// //import externs.X11.extensions.Xvproto;

import dix.timestamp;
import dix.dix_priv;
import dix.screen_hooks_priv;
import miext.extinit_priv;
import Xext.panoramiX;
import Xext.panoramiXsrv;
import Xext.xvdix_priv;

import os.os;
import dix.scrnintstr;
import dix.window;
import dix.pixmap;
import dix.dixstruct_priv;
import dix.resource;
import dix.input;
import Xext.xvdisp;
import externs.X11.extensions.Xvproto;
import os.log;
import dix.extension;
import externs.X11.extensions.Xv;
import dix.dixutils;
import dix.gc;
import dix.events;
import dix.screen_hooks;
import common.swap;


enum string SCREEN_PROLOGUE(string pScreen, string field) = `((` ~ pScreen ~ `).` ~ field ~ ` = (cast(XvScreenPtr) 
    dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, &XvScreenKeyRec)).` ~ field ~ `)`;

enum string SCREEN_EPILOGUE(string pScreen, string field, string wrapper) = `
    ((` ~ pScreen ~ `).` ~ field ~ ` = ` ~ wrapper ~ `)`;

struct _XvVideoNotifyRec {
    _XvVideoNotifyRec* next;
    ClientPtr client;
    c_ulong id;
    c_ulong mask;
}alias XvVideoNotifyRec = _XvVideoNotifyRec;
alias XvVideoNotifyPtr = _XvVideoNotifyRec*;

private DevPrivateKeyRec XvScreenKeyRec;

Bool noXvExtension = FALSE;

private x_server_generation_t XvExtensionGeneration = 0;
private x_server_generation_t XvScreenGeneration = 0;
private x_server_generation_t XvResourceGeneration = 0;

// int XvReqCode;
private int XvEventBase;
// int XvErrorBase;

int xvUseXinerama = 0;

RESTYPE XvRTPort;
private RESTYPE XvRTEncoding;
private RESTYPE XvRTGrab;
private RESTYPE XvRTVideoNotify;
private RESTYPE XvRTVideoNotifyList;
private RESTYPE XvRTPortNotify;

/* EXTERNAL */
















/*
** XvExtensionInit
**
**
*/

void XvExtensionInit()
{
    ExtensionEntry* extEntry = void;

    if (!dixRegisterPrivateKey(&XvScreenKeyRec, PRIVATE_SCREEN, XvScreenRec.sizeof))
        return;

    /* Look to see if any screens were initialized; if not then
       init global variables so the extension can function */
    if (XvScreenGeneration != serverGeneration) {
        if (!CreateResourceTypes()) {
            ErrorF("XvExtensionInit: Unable to allocate resource types\n");
            return;
        }
static if(XINERAMA){
        XineramaRegisterConnectionBlockCallback(&XineramifyXv);
} /* XINERAMA */
        XvScreenGeneration = serverGeneration;
    }

    if (XvExtensionGeneration != serverGeneration) {
        XvExtensionGeneration = serverGeneration;

        extEntry = AddExtension(XvName, XvNumEvents, XvNumErrors,
                                &ProcXvDispatch, &ProcXvDispatch,
                                &XvResetProc, &StandardMinorOpcode);
        if (!extEntry) {
            FatalError("XvExtensionInit: AddExtensions failed\n");
        }

        XvReqCode = extEntry.base;
        XvEventBase = extEntry.eventBase;
        XvErrorBase = extEntry.errorBase;

        EventSwapVector[XvEventBase + XvVideoNotify] =
            cast(EventSwapPtr) &WriteSwappedVideoNotifyEvent;
        EventSwapVector[XvEventBase + XvPortNotify] =
            cast(EventSwapPtr) &WriteSwappedPortNotifyEvent;

        SetResourceTypeErrorValue(XvRTPort, _XvBadPort);
        cast(void) dixAddAtom(XvName);
    }
}

private Bool CreateResourceTypes()
{

    if (XvResourceGeneration == serverGeneration)
        return TRUE;

    XvResourceGeneration = serverGeneration;

    if (((XvRTPort = CreateNewResourceType(&XvdiDestroyPort, "XvRTPort")) == 0)) {
        ErrorF("CreateResourceTypes: failed to allocate port resource.\n");
        return FALSE;
    }

    if (((XvRTGrab = CreateNewResourceType(&XvdiDestroyGrab, "XvRTGrab")) == 0)) {
        ErrorF("CreateResourceTypes: failed to allocate grab resource.\n");
        return FALSE;
    }

    if (((XvRTEncoding = CreateNewResourceType(&XvdiDestroyEncoding,
                                               "XvRTEncoding")) == 0)) {
        ErrorF("CreateResourceTypes: failed to allocate encoding resource.\n");
        return FALSE;
    }

    if (((XvRTVideoNotify = CreateNewResourceType(&XvdiDestroyVideoNotify,
                                                  "XvRTVideoNotify")) == 0)) {
        ErrorF
            ("CreateResourceTypes: failed to allocate video notify resource.\n");
        return FALSE;
    }

    if (
        ((XvRTVideoNotifyList =
         CreateNewResourceType(&XvdiDestroyVideoNotifyList,
                               "XvRTVideoNotifyList")) == 0)) {
        ErrorF
            ("CreateResourceTypes: failed to allocate video notify list resource.\n");
        return FALSE;
    }

    if (((XvRTPortNotify = CreateNewResourceType(&XvdiDestroyPortNotify,
                                                 "XvRTPortNotify")) == 0)) {
        ErrorF
            ("CreateResourceTypes: failed to allocate port notify resource.\n");
        return FALSE;
    }

    return TRUE;

}

private void XvWindowDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, WindowPtr pWin)
{
    XvStopAdaptors(&pWin.drawable);
}

private void XvPixmapDestroy(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pPixmap)
{
    XvStopAdaptors(&pPixmap.drawable);
}

int XvScreenInit(ScreenPtr pScreen)
{
    if (XvScreenGeneration != serverGeneration) {
        if (!CreateResourceTypes()) {
            ErrorF("XvScreenInit: Unable to allocate resource types\n");
            return BadAlloc;
        }
static if(XINERAMA){
        XineramaRegisterConnectionBlockCallback(&XineramifyXv);
} /* XINERAMA */
        XvScreenGeneration = serverGeneration;
    }

    if (!dixRegisterPrivateKey(&XvScreenKeyRec, PRIVATE_SCREEN, XvScreenRec.sizeof))
        return BadAlloc;

    dixScreenHookWindowDestroy(pScreen, &XvWindowDestroy);
    dixScreenHookClose(pScreen, &XvScreenClose);
    dixScreenHookPixmapDestroy(pScreen, &XvPixmapDestroy);

    return Success;
}

private void XvScreenClose(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookWindowDestroy(pScreen, &XvWindowDestroy);
    dixScreenUnhookClose(pScreen, &XvScreenClose);
    dixScreenUnhookPixmapDestroy(pScreen, &XvPixmapDestroy);
}

private void XvResetProc(ExtensionEntry* extEntry)
{
    xvUseXinerama = 0;
}

DevPrivateKey XvGetScreenKey()
{
    return &XvScreenKeyRec;
}

c_ulong XvGetRTPort()
{
    return XvRTPort;
}

private void XvStopAdaptors(DrawablePtr pDrawable)
{
    ScreenPtr pScreen = pDrawable.pScreen;
    XvScreenPtr pxvs = cast(XvScreenPtr)dixLookupPrivate(&pScreen.devPrivates, &XvScreenKeyRec);
    XvAdaptorPtr pa = pxvs.pAdaptors;
    int na = pxvs.nAdaptors;

    /* CHECK TO SEE IF THIS PORT IS IN USE */
    while (na--) {
        XvPortPtr pp = pa.pPorts;
        int np = pa.nPorts;

        while ((np--) && (pp)) {
            if (pp.pDraw == pDrawable) {
                XvdiSendVideoNotify(pp, pDrawable, XvPreempted);

                cast(void) (*pp.pAdaptor.ddStopVideo) (pp, pDrawable);

                pp.pDraw = null;
                pp.client = null;
                pp.time = currentTime;
            }
            pp++;
        }
        pa++;
    }
}

private int XvdiDestroyPort(void* pPort, XID id)
{
    return Success;
}

private int XvdiDestroyGrab(void* pGrab, XID id)
{
    (cast(XvGrabPtr) pGrab).client = null;
    return Success;
}

private int XvdiDestroyVideoNotify(void* pn, XID id)
{
    /* JUST CLEAR OUT THE client POINTER FIELD */

    (cast(XvVideoNotifyPtr) pn).client = null;
    return Success;
}

private int XvdiDestroyPortNotify(void* pn, XID id)
{
    /* JUST CLEAR OUT THE client POINTER FIELD */

    (cast(XvPortNotifyPtr) pn).client = null;
    return Success;
}

private int XvdiDestroyVideoNotifyList(void* pn, XID id)
{
    XvVideoNotifyPtr npn = void, cpn = void;

    /* ACTUALLY DESTROY THE NOTIFY LIST */

    cpn = cast(XvVideoNotifyPtr) pn;

    while (cpn) {
        npn = cpn.next;
        if (cpn.client)
            FreeResource(cast(uint)cpn.id, XvRTVideoNotify);
        free(cpn);
        cpn = npn;
    }
    return Success;
}

private int XvdiDestroyEncoding(void* value, XID id)
{
    return Success;
}

private int XvdiSendVideoNotify(XvPortPtr pPort, DrawablePtr pDraw, int reason)
{
    XvVideoNotifyPtr pn = void;

    dixLookupResourceByType(cast(void**) &pn, pDraw.id, XvRTVideoNotifyList,
                            serverClient, DixReadAccess);

    while (pn) {
        xvEvent event;
            event.u.videoNotify.reason = cast(ubyte)reason;
            event.u.videoNotify.time = currentTime.milliseconds;
            event.u.videoNotify.drawable = cast(uint)pDraw.id;
            event.u.videoNotify.port = cast(uint)pPort.id;

        event.u.u.type = cast(ubyte)(XvEventBase + XvVideoNotify);
        WriteEventsToClient(pn.client, 1, cast(_xEvent*) &event);
        pn = pn.next;
    }

    return Success;

}

private int XvdiSendPortNotify(XvPortPtr pPort, Atom attribute, INT32 value)
{
    XvPortNotifyPtr pn = void;

    pn = pPort.pNotify;

    while (pn) {
        xvEvent event;
            event.u.portNotify.time = currentTime.milliseconds;
            event.u.portNotify.port = cast(uint)pPort.id;
            event.u.portNotify.attribute = cast(uint)attribute;
            event.u.portNotify.value = value;

        event.u.u.type = cast(ubyte)(XvEventBase + XvPortNotify);
        WriteEventsToClient(pn.client, 1, cast(_xEvent*) &event);
        pn = pn.next;
    }

    return Success;

}

enum string CHECK_SIZE(string dw, string dh, string sw, string sh) = `{                                  
  if(!` ~ dw ~ ` || !` ~ dh ~ ` || !` ~ sw ~ ` || !` ~ sh ~ `)  return Success;                       
  /* The region code will break these if they are too large */        
  if((` ~ dw ~ ` > 32767) || (` ~ dh ~ ` > 32767) || (` ~ sw ~ ` > 32767) || (` ~ sh ~ ` > 32767))    
        return BadValue;                                              
}`;

int XvdiPutVideo(ClientPtr client, DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    DrawablePtr pOldDraw = void;

    mixin(CHECK_SIZE!(`drw_w`, `drw_h`, `vid_w`, `vid_h`));

    /* UPDATE TIME VARIABLES FOR USE IN EVENTS */

    UpdateCurrentTime();

    /* CHECK FOR GRAB; IF THIS CLIENT DOESN'T HAVE THE PORT GRABBED THEN
       INFORM CLIENT OF ITS FAILURE */

    if (pPort.grab.client && (pPort.grab.client != client)) {
        XvdiSendVideoNotify(pPort, pDraw, XvBusy);
        return Success;
    }

    /* CHECK TO SEE IF PORT IS IN USE; IF SO THEN WE MUST DELIVER INTERRUPTED
       EVENTS TO ANY CLIENTS WHO WANT THEM */

    pOldDraw = pPort.pDraw;
    if ((pOldDraw) && (pOldDraw != pDraw)) {
        XvdiSendVideoNotify(pPort, pPort.pDraw, XvPreempted);
    }

    cast(void) (*pPort.pAdaptor.ddPutVideo) (pDraw, pPort, pGC,
                                           vid_x, vid_y, vid_w, vid_h,
                                           drw_x, drw_y, drw_w, drw_h);

    if ((pPort.pDraw) && (pOldDraw != pDraw)) {
        pPort.client = client;
        XvdiSendVideoNotify(pPort, pPort.pDraw, XvStarted);
    }

    pPort.time = currentTime;

    return Success;

}

int XvdiPutStill(ClientPtr client, DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    int status = void;

    mixin(CHECK_SIZE!(`drw_w`, `drw_h`, `vid_w`, `vid_h`));

    /* UPDATE TIME VARIABLES FOR USE IN EVENTS */

    UpdateCurrentTime();

    /* CHECK FOR GRAB; IF THIS CLIENT DOESN'T HAVE THE PORT GRABBED THEN
       INFORM CLIENT OF ITS FAILURE */

    if (pPort.grab.client && (pPort.grab.client != client)) {
        XvdiSendVideoNotify(pPort, pDraw, XvBusy);
        return Success;
    }

    pPort.time = currentTime;

    status = (*pPort.pAdaptor.ddPutStill) (pDraw, pPort, pGC,
                                             vid_x, vid_y, vid_w, vid_h,
                                             drw_x, drw_y, drw_w, drw_h);

    return status;

}

int XvdiPutImage(ClientPtr client, DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 src_x, INT16 src_y, CARD16 src_w, CARD16 src_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h, XvImagePtr image, ubyte* data, Bool sync, CARD16 width, CARD16 height)
{
    mixin(CHECK_SIZE!(`drw_w`, `drw_h`, `src_w`, `src_h`));

    /* UPDATE TIME VARIABLES FOR USE IN EVENTS */

    UpdateCurrentTime();

    /* CHECK FOR GRAB; IF THIS CLIENT DOESN'T HAVE THE PORT GRABBED THEN
       INFORM CLIENT OF ITS FAILURE */

    if (pPort.grab.client && (pPort.grab.client != client)) {
        XvdiSendVideoNotify(pPort, pDraw, XvBusy);
        return Success;
    }

    pPort.time = currentTime;

    return (*pPort.pAdaptor.ddPutImage) (pDraw, pPort, pGC,
                                           src_x, src_y, src_w, src_h,
                                           drw_x, drw_y, drw_w, drw_h,
                                           image, data, sync, width, height);
}

int XvdiGetVideo(ClientPtr client, DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    DrawablePtr pOldDraw = void;

    mixin(CHECK_SIZE!(`drw_w`, `drw_h`, `vid_w`, `vid_h`));

    /* UPDATE TIME VARIABLES FOR USE IN EVENTS */

    UpdateCurrentTime();

    /* CHECK FOR GRAB; IF THIS CLIENT DOESN'T HAVE THE PORT GRABBED THEN
       INFORM CLIENT OF ITS FAILURE */

    if (pPort.grab.client && (pPort.grab.client != client)) {
        XvdiSendVideoNotify(pPort, pDraw, XvBusy);
        return Success;
    }

    /* CHECK TO SEE IF PORT IS IN USE; IF SO THEN WE MUST DELIVER INTERRUPTED
       EVENTS TO ANY CLIENTS WHO WANT THEM */

    pOldDraw = pPort.pDraw;
    if ((pOldDraw) && (pOldDraw != pDraw)) {
        XvdiSendVideoNotify(pPort, pPort.pDraw, XvPreempted);
    }

    cast(void) (*pPort.pAdaptor.ddGetVideo) (pDraw, pPort, pGC,
                                           vid_x, vid_y, vid_w, vid_h,
                                           drw_x, drw_y, drw_w, drw_h);

    if ((pPort.pDraw) && (pOldDraw != pDraw)) {
        pPort.client = client;
        XvdiSendVideoNotify(pPort, pPort.pDraw, XvStarted);
    }

    pPort.time = currentTime;

    return Success;

}

int XvdiGetStill(ClientPtr client, DrawablePtr pDraw, XvPortPtr pPort, GCPtr pGC, INT16 vid_x, INT16 vid_y, CARD16 vid_w, CARD16 vid_h, INT16 drw_x, INT16 drw_y, CARD16 drw_w, CARD16 drw_h)
{
    int status = void;

    mixin(CHECK_SIZE!(`drw_w`, `drw_h`, `vid_w`, `vid_h`));

    /* UPDATE TIME VARIABLES FOR USE IN EVENTS */

    UpdateCurrentTime();

    /* CHECK FOR GRAB; IF THIS CLIENT DOESN'T HAVE THE PORT GRABBED THEN
       INFORM CLIENT OF ITS FAILURE */

    if (pPort.grab.client && (pPort.grab.client != client)) {
        XvdiSendVideoNotify(pPort, pDraw, XvBusy);
        return Success;
    }

    status = (*pPort.pAdaptor.ddGetStill) (pDraw, pPort, pGC,
                                             vid_x, vid_y, vid_w, vid_h,
                                             drw_x, drw_y, drw_w, drw_h);

    pPort.time = currentTime;

    return status;

}

int XvdiGrabPort(ClientPtr client, XvPortPtr pPort, Time ctime, int* p_result)
{
    c_ulong id = void;
    TimeStamp time = void;

    UpdateCurrentTime();
    time = ClientTimeToServerTime(cast(uint)ctime);

    if (pPort.grab.client && (client != pPort.grab.client)) {
        *p_result = XvAlreadyGrabbed;
        return Success;
    }

    if ((CompareTimeStamps(time, currentTime) == LATER) ||
        (CompareTimeStamps(time, pPort.time) == EARLIER)) {
        *p_result = XvInvalidTime;
        return Success;
    }

    if (client == pPort.grab.client) {
        *p_result = Success;
        return Success;
    }

    id = FakeClientID(client.index);

    if (!AddResource(cast(uint)id, XvRTGrab, &pPort.grab)) {
        return BadAlloc;
    }

    /* IF THERE IS ACTIVE VIDEO THEN STOP IT */

    if ((pPort.pDraw) && (client != pPort.client)) {
        XvdiStopVideo(null, pPort, pPort.pDraw);
    }

    pPort.grab.client = client;
    pPort.grab.id = id;

    pPort.time = currentTime;

    *p_result = Success;

    return Success;

}

int XvdiUngrabPort(ClientPtr client, XvPortPtr pPort, Time ctime)
{
    TimeStamp time = void;

    UpdateCurrentTime();
    time = ClientTimeToServerTime(cast(uint)ctime);

    if ((!pPort.grab.client) || (client != pPort.grab.client)) {
        return Success;
    }

    if ((CompareTimeStamps(time, currentTime) == LATER) ||
        (CompareTimeStamps(time, pPort.time) == EARLIER)) {
        return Success;
    }

    /* FREE THE GRAB RESOURCE; AND SET THE GRAB CLIENT TO NULL */

    FreeResource(cast(uint)pPort.grab.id, XvRTGrab);
    pPort.grab.client = null;

    pPort.time = currentTime;

    return Success;

}

int XvdiSelectVideoNotify(ClientPtr client, DrawablePtr pDraw, BOOL onoff)
{
    XvVideoNotifyPtr pn = void, tpn = void, fpn = void;

    /* FIND VideoNotify LIST */

    int rc = dixLookupResourceByType(cast(void**) &pn, pDraw.id,
                                 XvRTVideoNotifyList, client, DixWriteAccess);
    if (rc != Success && rc != BadValue)
        return rc;

    /* IF ONE DONES'T EXIST AND NO MASK, THEN JUST RETURN */

    if (!onoff && !pn)
        return Success;

    /* IF ONE DOESN'T EXIST CREATE IT AND ADD A RESOURCE SO THAT THE LIST
       WILL BE DELETED WHEN THE DRAWABLE IS DESTROYED */

    if (!pn) {
        if (((tpn = cast(XvVideoNotifyPtr)cast(XvVideoNotifyRec*) calloc(1, XvVideoNotifyRec.sizeof)) is null))
            return BadAlloc;
        tpn.next = null;
        tpn.client = null;
        if (!AddResource(cast(uint)pDraw.id, XvRTVideoNotifyList, tpn))
            return BadAlloc;
    }
    else {
        /* LOOK TO SEE IF ENTRY ALREADY EXISTS */

        fpn = null;
        tpn = pn;
        while (tpn) {
            if (tpn.client == client) {
                if (!onoff) {
                    tpn.client = null;
                    FreeResource(cast(uint)tpn.id, XvRTVideoNotify);
                }
                return Success;
            }
            if (!tpn.client)
                fpn = tpn;      /* TAKE NOTE OF FREE ENTRY */
            tpn = tpn.next;
        }

        /* IF TURNING OFF, THEN JUST RETURN */

        if (!onoff)
            return Success;

        /* IF ONE ISN'T FOUND THEN ALLOCATE ONE AND LINK IT INTO THE LIST */

        if (fpn) {
            tpn = fpn;
        }
        else {
            if (((tpn = cast(XvVideoNotifyPtr)cast(XvVideoNotifyRec*) calloc(1, XvVideoNotifyRec.sizeof)) is null))
                return BadAlloc;
            tpn.next = pn.next;
            pn.next = tpn;
        }
    }

    /* INIT CLIENT PTR IN CASE WE CAN'T ADD RESOURCE */
    /* ADD RESOURCE SO THAT IF CLIENT EXITS THE CLIENT PTR WILL BE CLEARED */

    tpn.client = null;
    tpn.id = FakeClientID(client.index);
    if (!AddResource(cast(uint)tpn.id, XvRTVideoNotify, tpn))
        return BadAlloc;

    tpn.client = client;
    return Success;

}

int XvdiSelectPortNotify(ClientPtr client, XvPortPtr pPort, BOOL onoff)
{
    XvPortNotifyPtr pn = void, tpn = void;

    /* SEE IF CLIENT IS ALREADY IN LIST */

    tpn = null;
    pn = pPort.pNotify;
    while (pn) {
        if (!pn.client)
            tpn = pn;           /* TAKE NOTE OF FREE ENTRY */
        if (pn.client == client)
            break;
        pn = pn.next;
    }

    /* IS THE CLIENT ALREADY ON THE LIST? */

    if (pn) {
        /* REMOVE IT? */

        if (!onoff) {
            pn.client = null;
            FreeResource(cast(uint)pn.id, XvRTPortNotify);
        }

        return Success;
    }

    /* DIDN'T FIND IT; SO REUSE LIST ELEMENT IF ONE IS FREE OTHERWISE
       CREATE A NEW ONE AND ADD IT TO THE BEGINNING OF THE LIST */

    if (!tpn) {
        if (((tpn = cast(XvPortNotifyPtr)cast(XvPortNotifyRec*) calloc(1, XvPortNotifyRec.sizeof)) is null))
            return BadAlloc;
        tpn.next = pPort.pNotify;
        pPort.pNotify = tpn;
    }

    tpn.client = client;
    tpn.id = FakeClientID(client.index);
    if (!AddResource(cast(uint)tpn.id, XvRTPortNotify, tpn))
        return BadAlloc;

    return Success;

}

int XvdiStopVideo(ClientPtr client, XvPortPtr pPort, DrawablePtr pDraw)
{
    int status = void;

    /* IF PORT ISN'T ACTIVE THEN WE'RE DONE */

    if (!pPort.pDraw || (pPort.pDraw != pDraw)) {
        XvdiSendVideoNotify(pPort, pDraw, XvStopped);
        return Success;
    }

    /* CHECK FOR GRAB; IF THIS CLIENT DOESN'T HAVE THE PORT GRABBED THEN
       INFORM CLIENT OF ITS FAILURE */

    if ((client) && (pPort.grab.client) && (pPort.grab.client != client)) {
        XvdiSendVideoNotify(pPort, pDraw, XvBusy);
        return Success;
    }

    XvdiSendVideoNotify(pPort, pDraw, XvStopped);

    status = (*pPort.pAdaptor.ddStopVideo) (pPort, pDraw);

    pPort.pDraw = null;
    pPort.client = cast(ClientPtr) client;
    pPort.time = currentTime;

    return status;

}

int XvdiMatchPort(XvPortPtr pPort, DrawablePtr pDraw)
{

    XvAdaptorPtr pa = void;
    XvFormatPtr pf = void;
    int nf = void;

    pa = pPort.pAdaptor;

    if (pa.pScreen != pDraw.pScreen)
        return BadMatch;

    nf = pa.nFormats;
    pf = pa.pFormats;

    while (nf--) {
        if (pf.depth == pDraw.depth)
            return Success;
        pf++;
    }

    return BadMatch;

}

int XvdiSetPortAttribute(ClientPtr client, XvPortPtr pPort, Atom attribute, INT32 value)
{
    int status = void;

    status =
        (*pPort.pAdaptor.ddSetPortAttribute) (pPort, attribute,
                                                value);
    if (status == Success)
        XvdiSendPortNotify(pPort, attribute, value);

    return status;
}

int XvdiGetPortAttribute(ClientPtr client, XvPortPtr pPort, Atom attribute, INT32* p_value)
{

    return
        (*pPort.pAdaptor.ddGetPortAttribute) (pPort, attribute,
                                                p_value);

}

private void WriteSwappedVideoNotifyEvent(xvEvent* from, xvEvent* to)
{

    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;
    cpswaps(from.u.videoNotify.sequenceNumber,
            to.u.videoNotify.sequenceNumber);
    cpswapl(from.u.videoNotify.time, to.u.videoNotify.time);
    cpswapl(from.u.videoNotify.drawable, to.u.videoNotify.drawable);
    cpswapl(from.u.videoNotify.port, to.u.videoNotify.port);

}

private void WriteSwappedPortNotifyEvent(xvEvent* from, xvEvent* to)
{

    to.u.u.type = from.u.u.type;
    to.u.u.detail = from.u.u.detail;
    cpswaps(from.u.portNotify.sequenceNumber, to.u.portNotify.sequenceNumber);
    cpswapl(from.u.portNotify.time, to.u.portNotify.time);
    cpswapl(from.u.portNotify.port, to.u.portNotify.port);
    cpswapl(from.u.portNotify.value, to.u.portNotify.value);

}

void XvFreeAdaptor(XvAdaptorPtr pAdaptor)
{
    int i = void;

    free(pAdaptor.name);
    pAdaptor.name = null;

    if (pAdaptor.pEncodings) {
        XvEncodingPtr pEncode = pAdaptor.pEncodings;

        for (i = 0; i < pAdaptor.nEncodings; i++, pEncode++)
            free(pEncode.name);
        free(pAdaptor.pEncodings);
        pAdaptor.pEncodings = null;
    }

    free(pAdaptor.pFormats);
    pAdaptor.pFormats = null;

    free(pAdaptor.pPorts);
    pAdaptor.pPorts = null;

    if (pAdaptor.pAttributes) {
        XvAttributePtr pAttribute = pAdaptor.pAttributes;

        for (i = 0; i < pAdaptor.nAttributes; i++, pAttribute++)
            free(pAttribute.name);
        free(pAdaptor.pAttributes);
        pAdaptor.pAttributes = null;
    }

    free(pAdaptor.pImages);
    pAdaptor.pImages = null;

    free(pAdaptor.devPriv.ptr);
    pAdaptor.devPriv.ptr = null;
}

void XvFillColorKey(DrawablePtr pDraw, CARD32 key, RegionPtr region)
{
    ScreenPtr pScreen = pDraw.pScreen;
    ChangeGCVal[2] pval = void;
    BoxPtr pbox = RegionRects(region);
    int i = void, nbox = RegionNumRects(region);
    xRectangle* rects = void;
    GCPtr gc = void;

    gc = GetScratchGC(pDraw.depth, pScreen);
    if (!gc)
        return;

    pval[0].val = key;
    pval[1].val = IncludeInferiors;
    cast(void) ChangeGC(null, gc, cast(uint)(GCForeground | GCSubwindowMode), pval.ptr);
    ValidateGC(pDraw, gc);

    rects = cast(xRectangle*) calloc(nbox, xRectangle.sizeof);
    if (rects) {
        for (i = 0; i < nbox; i++, pbox++) {
            rects[i].x = cast(ushort)(pbox.x1 - pDraw.x);
            rects[i].y = cast(ushort)(pbox.y1 - pDraw.y);
            rects[i].width = cast(ushort)(pbox.x2 - pbox.x1);
            rects[i].height = cast(ushort)(pbox.y2 - pbox.y1);
        }

        (*gc.ops.PolyFillRect) (pDraw, gc, nbox, rects);

        free(rects);
    }
    FreeScratchGC(gc);
}
