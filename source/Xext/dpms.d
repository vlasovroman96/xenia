module Xext.dpms;
@nogc nothrow:
extern(C): __gshared:
/*****************************************************************

Copyright (c) 1996 Digital Equipment Corporation, Maynard, Massachusetts.

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
DIGITAL EQUIPMENT CORPORATION BE LIABLE FOR ANY CLAIM, DAMAGES, INCLUDING,
BUT NOT LIMITED TO CONSEQUENTIAL OR INCIDENTAL DAMAGES, OR OTHER LIABILITY,
WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR
IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of Digital Equipment Corporation
shall not be used in advertising or otherwise to promote the sale, use or other
dealings in this Software without prior written authorization from Digital
Equipment Corporation.

******************************************************************/

import build.dix_config;

//import x11.X;
//import x11.Xproto;
//import x11.X;

import dix.dix_priv;
import dix.request_priv;
import dix.screenint_priv;
import dix.screensaver_priv;
import miext.extinit_priv;
import os.screensaver;
import os.osdep;
import Xext.geext_priv;

import include.misc;
import include.os;
import dix.dixstruct_priv;
import include.extnsionst;
import include.opaque;
import Xext.dpmsproc;
import include.scrnintstr;
import include.windowstr;
import include.protocol_versions;
import externs.X11.extensions.dpmsconst;
import externs.X11.extensions.dpmsproto;
import dix.extension;

import os.WaitFor;
import dix.events;

Bool noDPMSExtension = FALSE;

CARD16 DPMSPowerLevel = 0;
Bool DPMSDisabledSwitch = FALSE;
CARD32 DPMSStandbyTime = -1;
CARD32 DPMSSuspendTime = -1;
CARD32 DPMSOffTime = -1;
Bool DPMSEnabled;

private int DPMSReqCode = 0;
private RESTYPE ClientType, DPMSEventType;  /* resource types for event masks */
private XID eventResource;

struct _DPMSEvent {
    DPMSEventPtr next;
    ClientPtr client;
    XID clientResource;
    uint mask;
}
alias DPMSEventPtr = _DPMSEvent*;
alias DPMSEventRec = _DPMSEvent;

 /*ARGSUSED*/ private int DPMSFreeClient(void* data, XID id)
{
    DPMSEventPtr pEvent = void;
    DPMSEventPtr* pHead = void; DPMSEventPtr pCur = void, pPrev = void;

    pEvent = cast(DPMSEventPtr) data;
    dixLookupResourceByType(cast(void**) &pHead, eventResource, DPMSEventType,
                            null, DixUnknownAccess);
    if (pHead) {
        pPrev = null;
        for (pCur = *pHead; pCur && pCur != pEvent; pCur = pCur.next) {
            pPrev = pCur;
        }
        if (pCur) {
            if (pPrev) {
                pPrev.next = pEvent.next;
            } else {
                *pHead = pEvent.next;
            }
        }
    }
    free(cast(void*) pEvent);
    return 1;
}

 /*ARGSUSED*/ private int DPMSFreeEvents(void* data, XID id)
{
    DPMSEventPtr* pHead = void; DPMSEventPtr pCur = void, pNext = void;

    pHead = cast(DPMSEventPtr*) data;
    for (pCur = *pHead; pCur; pCur = pNext) {
        pNext = pCur.next;
        FreeResource(cast(uint)pCur.clientResource, ClientType);
        free(cast(void*) pCur);
    }
    free(cast(void*) pHead);
    return 1;
}

private void SDPMSInfoNotifyEvent(xGenericEvent* from, xGenericEvent* to)
{
    *to = *from;
    swaps(&to.sequenceNumber);
    swapl(&to.length);
    swaps(&to.evtype);
    if (from.evtype == DPMSInfoNotify) {
        xDPMSInfoNotifyEvent* c = cast(xDPMSInfoNotifyEvent*) to;
        swapl(&c.timestamp);
        swaps(&c.power_level);
    }
}

private int ProcDPMSSelectInput(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSSelectInputReq);
    mixin(X_REQUEST_FIELD_CARD32!("eventMask"));

    DPMSEventPtr pEvent = void, pNewEvent = void; DPMSEventPtr* pHead = void;
    XID clientResource = void;
    int i = void;

    i = dixLookupResourceByType(cast(void**)&pHead, eventResource, DPMSEventType,
                                client,
                                DixWriteAccess);
    if (stuff.eventMask == DPMSInfoNotifyMask) {
        if (i == Success && pHead) {
            /* check for existing entry. */
            for (pEvent = *pHead; pEvent; pEvent = pEvent.next) {
                if (pEvent.client == client) {
                    pEvent.mask = cast(uint)stuff.eventMask;
                    return Success;
                }
            }
        }

        /* build the entry */
        pNewEvent = cast(DPMSEventPtr)cast(DPMSEventRec*) calloc(1, DPMSEventRec.sizeof);
        if (!pNewEvent)
            return BadAlloc;
        pNewEvent.client = client;
        pNewEvent.mask = cast(uint)stuff.eventMask;
        /*
         * add a resource that will be deleted when
         * the client goes away
         */
        clientResource = FakeClientID(client.index);
        pNewEvent.clientResource = clientResource;
        if (!AddResource(cast(uint)clientResource, ClientType, cast(void*)pNewEvent))
            return BadAlloc;
        /*
         * create a resource to contain a pointer to the list
         * of clients selecting input
         */
        if (i != Success || !pHead) {
            pHead = cast(DPMSEventPtr*) cast(DPMSEventPtr*) calloc(1, DPMSEventPtr.sizeof);
            if (!pHead ||
                    !AddResource(cast(uint)eventResource, DPMSEventType, cast(void*)pHead)) {
                FreeResource(cast(uint)clientResource, X11_RESTYPE_NONE);
                return BadAlloc;
            }
            *pHead = null;
        }
        pNewEvent.next = *pHead;
        *pHead = pNewEvent;
    }
    else if (stuff.eventMask == 0) {
        /* delete the interest */
        if (i == Success && pHead) {
            pNewEvent = null;
            for (pEvent = *pHead; pEvent; pEvent = pEvent.next) {
                if (pEvent.client == client) {
                    break;
                }
                pNewEvent = pEvent;
            }
            if (pEvent) {
                FreeResource(cast(uint)pEvent.clientResource, ClientType);
                if (pNewEvent) {
                    pNewEvent.next = pEvent.next;
                } else {
                    *pHead = pEvent.next;
                }
                free(pEvent);
            }
        }
    }
    else {
        client.errorValue = cast(uint)stuff.eventMask;
        return BadValue;
    }
    return Success;
}

private void SendDPMSInfoNotify()
{
    DPMSEventPtr* pHead = void; DPMSEventPtr pEvent = void;
    xDPMSInfoNotifyEvent se = void;
    int i = void;

    i = dixLookupResourceByType(cast(void**)&pHead, eventResource, DPMSEventType,
                                serverClient,
                                DixReadAccess);
    if (i != Success || !pHead) {
        return;
    }

    for (pEvent = *pHead; pEvent; pEvent = pEvent.next) {
        if ((pEvent.mask & DPMSInfoNotifyMask) == 0) {
            continue;
        }
        se.type = GenericEvent;
        se.extension = cast(ubyte)DPMSReqCode;
        se.length = (xDPMSInfoNotifyEvent.sizeof - 32) >> 2;
        se.evtype = DPMSInfoNotify;
        se.timestamp = currentTime.milliseconds;
        se.power_level = DPMSPowerLevel;
        se.state = cast(ubyte)DPMSEnabled;
        WriteEventsToClient(pEvent.client, 1, cast(xEvent*)&se);
    }
}

Bool DPMSSupported()
{
    /* For each screen, check if DPMS is supported */
    mixin(DIX_FOR_EACH_SCREEN!("{
        if (walkScreen.DPMS !is null) {
            return TRUE;
        }
    }"));

    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        if (walkScreen.DPMS !is null) {
            return TRUE;
        }
    }"));

    return FALSE;
}

private Bool isUnblank(int mode)
{
    switch (mode) {
    case SCREEN_SAVER_OFF:
    case SCREEN_SAVER_FORCER:
        return TRUE;
    case SCREEN_SAVER_ON:
    case SCREEN_SAVER_CYCLE:
        return FALSE;
    default:
        return TRUE;
    }
}

int DPMSSet(ClientPtr client, int level)
{
    int old_level = DPMSPowerLevel;

    DPMSPowerLevel = cast(ushort)level;

    if (level != DPMSModeOn) {
        if (isUnblank(screenIsSaved)) {
            int rc = dixSaveScreens(client, SCREEN_SAVER_FORCER, ScreenSaverActive);
            if (rc != Success) {
                return rc;
            }
        }
    } else if (!isUnblank(screenIsSaved)) {
        int rc = dixSaveScreens(client, SCREEN_SAVER_OFF, ScreenSaverReset);
        if (rc != Success) {
            return rc;
        }
    }

    mixin(DIX_FOR_EACH_SCREEN!("{
        if (walkScreen.DPMS !is null) {
            walkScreen.DPMS(walkScreen, level);
        }
    }"));

    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        if (walkScreen.DPMS !is null) {
            walkScreen.DPMS(walkScreen, level);
        }
    }"));

    if (DPMSPowerLevel != old_level) {
        SendDPMSInfoNotify();
    }

    return Success;
}

private int ProcDPMSGetVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSGetVersionReq);
    mixin(X_REQUEST_FIELD_CARD16!"majorVersion");
    mixin(X_REQUEST_FIELD_CARD16!"minorVersion");

    xDPMSGetVersionReply reply = {
        majorVersion: SERVER_DPMS_MAJOR_VERSION,
        minorVersion: SERVER_DPMS_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDPMSCapable(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSCapableReq);

    xDPMSCapableReply reply = {
        xGenericEventcapable: TRUE
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDPMSGetTimeouts(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSGetTimeoutsReq);

    xDPMSGetTimeoutsReply reply = {
        standby: cast(ushort)(DPMSStandbyTime / MILLI_PER_SECOND),
        suspend: cast(ushort)(DPMSSuspendTime / MILLI_PER_SECOND),
        off: cast(ushort)(DPMSOffTime / MILLI_PER_SECOND)
    };

    mixin(X_REPLY_FIELD_CARD16!("standby"));
    mixin(X_REPLY_FIELD_CARD16!("suspend"));
    mixin(X_REPLY_FIELD_CARD16!("off"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDPMSSetTimeouts(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSSetTimeoutsReq);
    mixin(X_REQUEST_FIELD_CARD16!("standby"));
    mixin(X_REQUEST_FIELD_CARD16!("suspend"));
    mixin(X_REQUEST_FIELD_CARD16!("off"));

    if ((stuff.off != 0) && (stuff.off < stuff.suspend)) {
        client.errorValue = cast(uint)stuff.off;
        return BadValue;
    }
    if ((stuff.suspend != 0) && (stuff.suspend < stuff.standby)) {
        client.errorValue = cast(uint)stuff.suspend;
        return BadValue;
    }

    DPMSStandbyTime = stuff.standby * MILLI_PER_SECOND;
    DPMSSuspendTime = stuff.suspend * MILLI_PER_SECOND;
    DPMSOffTime = stuff.off * MILLI_PER_SECOND;
    SetScreenSaverTimer();

    return Success;
}

private int ProcDPMSEnable(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSEnableReq);

    Bool was_enabled = DPMSEnabled;

    DPMSEnabled = TRUE;
    if (!was_enabled) {
        SetScreenSaverTimer();
        SendDPMSInfoNotify();
    }

    return Success;
}

private int ProcDPMSDisable(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSDisableReq);

    Bool was_enabled = DPMSEnabled;

    DPMSSet(client, DPMSModeOn);

    DPMSEnabled = FALSE;
    if (was_enabled) {
        SendDPMSInfoNotify();
    }

    return Success;
}

private int ProcDPMSForceLevel(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSForceLevelReq);
    mixin(X_REQUEST_FIELD_CARD16!("level"));

    if (!DPMSEnabled) {
        return BadMatch;
    }

    if (stuff.level != DPMSModeOn &&
        stuff.level != DPMSModeStandby &&
        stuff.level != DPMSModeSuspend && stuff.level != DPMSModeOff) {
        client.errorValue = cast(uint)stuff.level;
        return BadValue;
    }

    DPMSSet(client, stuff.level);

    return Success;
}

private int ProcDPMSInfo(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xDPMSInfoReq);

    xDPMSInfoReply reply = {
        power_level: DPMSPowerLevel,
        state: cast(ubyte)DPMSEnabled
    };

    mixin(X_REPLY_FIELD_CARD16!("power_level"));
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcDPMSDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
    case X_DPMSGetVersion:
        return ProcDPMSGetVersion(client);
    case X_DPMSCapable:
        return ProcDPMSCapable(client);
    case X_DPMSGetTimeouts:
        return ProcDPMSGetTimeouts(client);
    case X_DPMSSetTimeouts:
        return ProcDPMSSetTimeouts(client);
    case X_DPMSEnable:
        return ProcDPMSEnable(client);
    case X_DPMSDisable:
        return ProcDPMSDisable(client);
    case X_DPMSForceLevel:
        return ProcDPMSForceLevel(client);
    case X_DPMSInfo:
        return ProcDPMSInfo(client);
    case X_DPMSSelectInput:
        return ProcDPMSSelectInput(client);
    default:
        return BadRequest;
    }
}

private void DPMSCloseDownExtension(_ExtensionEntry* e)
{
    DPMSSet(serverClient, DPMSModeOn);
}

void DPMSExtensionInit()
{
    _ExtensionEntry* extEntry = void;

enum string CONDITIONALLY_SET_DPMS_TIMEOUT(string _timeout_value_) = `
    if (` ~ _timeout_value_ ~ ` == -1) { /* not yet set from config */  
        ` ~ _timeout_value_ ~ ` = ScreenSaverTime;                      
    }`;

     mixin(CONDITIONALLY_SET_DPMS_TIMEOUT!("DPMSSuspendTime"));
     DPMSPowerLevel = DPMSModeOn;
    DPMSEnabled = DPMSSupported();

    ClientType = CreateNewResourceType(&DPMSFreeClient, "DPMSClient");
    DPMSEventType = CreateNewResourceType(&DPMSFreeEvents, "DPMSEvent");
    eventResource = dixAllocServerXID();

    extEntry = AddExtension(DPMSExtensionName, 0, 0,
                                 &ProcDPMSDispatch, &ProcDPMSDispatch,
                                 &DPMSCloseDownExtension, &StandardMinorOpcode);

    if (DPMSEnabled && ClientType && DPMSEventType &&
        extEntry !is null) {
        DPMSReqCode = extEntry.base;
        GERegisterExtension(DPMSReqCode, &SDPMSInfoNotifyEvent);
    }
}
