module randr.randr;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2000 Compaq Computer Corporation
 * Copyright © 2002 Hewlett-Packard Company
 * Copyright © 2006 Intel Corporation
 * Copyright © 2017 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 *
 * Author:  Jim Gettys, Hewlett-Packard Company, Inc.
 *	    Keith Packard, Intel Corporation
 */

import build.xlibre_server;
import Xext.panoramiXsrv;

//import stdbool;

import dix.screen_hooks_priv;
import dix.screenint_priv;
import miext.extinit_priv;
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import dix.screen_hooks;
import dix.resource;
import dix.dixutils;
import dix.extension;
import os.io;
import dix.events;
import dix.timestamp;
import dix.window;

/* From render.h */
// enum SubPixelUnknown = 0;


Bool noRRExtension = FALSE;

version = RR_VALIDATE;
private int RRNScreens;

enum string wrap(string priv,string real_,string mem,string func) = `{
    ` ~ priv ~ `.` ~ mem ~ ` = ` ~ real_ ~ `.` ~ mem ~ `; 
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ func ~ `; 
}`;

enum string unwrap(string priv,string real_,string mem) = `{
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ priv ~ `.` ~ mem ~ `; 
}`;

int RREventBase;
int RRErrorBase;
RESTYPE RRClientType, RREventType;      /* resource types for event masks */
// DevPrivateKeyRec RRClientPrivateKeyRec;

// DevPrivateKeyRec rrPrivKeyRec;

private void RRClientCallback(CallbackListPtr* list, void* closure, void* data)
{
    NewClientInfoRec* clientinfo = cast(NewClientInfoRec*) data;
    ClientPtr pClient = clientinfo.client;

    mixin(rrClientPriv!("pClient"));
    RRTimesPtr pTimes = cast(RRTimesPtr) (pRRClient + 1);

    pRRClient.major_version = 0;
    pRRClient.minor_version = 0;

    mixin(DIX_FOR_EACH_SCREEN!q{
        mixin(rrScrPriv!("walkScreen"));
        if (pScrPriv) {
            pTimes[walkScreenIdx].setTime = pScrPriv.lastSetTime;
            pTimes[walkScreenIdx].configTime = pScrPriv.lastConfigTime;
        }
    });
}

private void RRCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    mixin(rrScrPriv!("pScreen"));
    int j = void;
    RRLeasePtr lease = void, next = void;

    dixScreenUnhookClose(pScreen, &RRCloseScreen);

    mixin(xorg_list_for_each_entry_safe!("lease", "next", "&pScrPriv.leases", "list", q{
        RRTerminateLease(lease);
    }));
    for (j = pScrPriv.numCrtcs - 1; j >= 0; j--)
        RRCrtcDestroy(pScrPriv.crtcs[j]);
    for (j = pScrPriv.numOutputs - 1; j >= 0; j--)
        RROutputDestroy(pScrPriv.outputs[j]);

    if (pScrPriv.provider)
        RRProviderDestroy(pScrPriv.provider);

    RRMonitorClose(pScreen);

    free(pScrPriv.crtcs);
    free(pScrPriv.outputs);
    free(pScrPriv);
    RRNScreens -= 1;            /* ok, one fewer screen with RandR running */
}

private void SRRScreenChangeNotifyEvent(xRRScreenChangeNotifyEvent* from, xRRScreenChangeNotifyEvent* to)
{
    to.type = from.type;
    to.rotation = from.rotation;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.configTimestamp, to.configTimestamp);
    cpswapl(from.root, to.root);
    cpswapl(from.window, to.window);
    cpswaps(from.sizeID, to.sizeID);
    cpswaps(from.subpixelOrder, to.subpixelOrder);
    cpswaps(from.widthInPixels, to.widthInPixels);
    cpswaps(from.heightInPixels, to.heightInPixels);
    cpswaps(from.widthInMillimeters, to.widthInMillimeters);
    cpswaps(from.heightInMillimeters, to.heightInMillimeters);
}

private void SRRCrtcChangeNotifyEvent(xRRCrtcChangeNotifyEvent* from, xRRCrtcChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.crtc, to.crtc);
    cpswapl(from.mode, to.mode);
    cpswaps(from.rotation, to.rotation);
    /* pad1 */
    cpswaps(from.x, to.x);
    cpswaps(from.y, to.y);
    cpswaps(from.width, to.width);
    cpswaps(from.height, to.height);
}

private void SRROutputChangeNotifyEvent(xRROutputChangeNotifyEvent* from, xRROutputChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.configTimestamp, to.configTimestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.output, to.output);
    cpswapl(from.crtc, to.crtc);
    cpswapl(from.mode, to.mode);
    cpswaps(from.rotation, to.rotation);
    to.connection = from.connection;
    to.subpixelOrder = from.subpixelOrder;
}

private void SRROutputPropertyNotifyEvent(xRROutputPropertyNotifyEvent* from, xRROutputPropertyNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.window, to.window);
    cpswapl(from.output, to.output);
    cpswapl(from.atom, to.atom);
    cpswapl(from.timestamp, to.timestamp);
    to.state = from.state;
    /* pad1 */
    /* pad2 */
    /* pad3 */
    /* pad4 */
}

private void SRRProviderChangeNotifyEvent(xRRProviderChangeNotifyEvent* from, xRRProviderChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.provider, to.provider);
}

private void SRRProviderPropertyNotifyEvent(xRRProviderPropertyNotifyEvent* from, xRRProviderPropertyNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.window, to.window);
    cpswapl(from.provider, to.provider);
    cpswapl(from.atom, to.atom);
    cpswapl(from.timestamp, to.timestamp);
    to.state = from.state;
    /* pad1 */
    /* pad2 */
    /* pad3 */
    /* pad4 */
}

private void SRRResourceChangeNotifyEvent(xRRResourceChangeNotifyEvent* from, xRRResourceChangeNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
}

private void SRRLeaseNotifyEvent(xRRLeaseNotifyEvent* from, xRRLeaseNotifyEvent* to)
{
    to.type = from.type;
    to.subCode = from.subCode;
    cpswaps(from.sequenceNumber, to.sequenceNumber);
    cpswapl(from.timestamp, to.timestamp);
    cpswapl(from.window, to.window);
    cpswapl(from.lease, to.lease);
    to.created = from.created;
}

private void SRRNotifyEvent(xEvent* from, xEvent* to)
{
    switch (from.u.u.detail) {
    case RRNotify_CrtcChange:
        SRRCrtcChangeNotifyEvent(cast(xRRCrtcChangeNotifyEvent*) from,
                                 cast(xRRCrtcChangeNotifyEvent*) to);
        break;
    case RRNotify_OutputChange:
        SRROutputChangeNotifyEvent(cast(xRROutputChangeNotifyEvent*) from,
                                   cast(xRROutputChangeNotifyEvent*) to);
        break;
    case RRNotify_OutputProperty:
        SRROutputPropertyNotifyEvent(cast(xRROutputPropertyNotifyEvent*) from,
                                     cast(xRROutputPropertyNotifyEvent*) to);
        break;
    case RRNotify_ProviderChange:
        SRRProviderChangeNotifyEvent(cast(xRRProviderChangeNotifyEvent*) from,
                                   cast(xRRProviderChangeNotifyEvent*) to);
        break;
    case RRNotify_ProviderProperty:
        SRRProviderPropertyNotifyEvent(cast(xRRProviderPropertyNotifyEvent*) from,
                                       cast(xRRProviderPropertyNotifyEvent*) to);
        break;
    case RRNotify_ResourceChange:
        SRRResourceChangeNotifyEvent(cast(xRRResourceChangeNotifyEvent*) from,
                                   cast(xRRResourceChangeNotifyEvent*) to);
        break;
    case RRNotify_Lease:
        SRRLeaseNotifyEvent(cast(xRRLeaseNotifyEvent*) from,
                            cast(xRRLeaseNotifyEvent*) to);
        break;
    default:
        break;
    }
}

private bool initialized = false;

Bool RRInit()
{
    /* prevent double init attempts */
    if (initialized)
        return TRUE;

    if (!RRModeInit())
        return FALSE;
    if (!RRCrtcInit())
        return FALSE;
    if (!RROutputInit())
        return FALSE;
    if (!RRProviderInit())
        return FALSE;
    if (!RRLeaseInit())
        return FALSE;

    if (!dixRegisterPrivateKey(&rrPrivKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    initialized = true;
    return TRUE;
}

Bool RRScreenInit(ScreenPtr pScreen)
{
    rrScrPrivPtr pScrPriv = void;

    if (!RRInit())
        return FALSE;

    pScrPriv = cast(rrScrPrivPtr) cast(rrScrPrivRec*) calloc(1, rrScrPrivRec.sizeof);
    if (!pScrPriv)
        return FALSE;

    mixin(SetRRScreen!("pScreen", "pScrPriv"));

    /*
     * Calling function best set these function vectors
     */
    pScrPriv.maxWidth = pScrPriv.minWidth = pScreen.width;
    pScrPriv.maxHeight = pScrPriv.minHeight = pScreen.height;

    pScrPriv.width = pScreen.width;
    pScrPriv.height = pScreen.height;
    pScrPriv.mmWidth = pScreen.mmWidth;
    pScrPriv.mmHeight = pScreen.mmHeight;
    pScrPriv.rotations = RR_Rotate_0;
    pScrPriv.reqWidth = pScreen.width;
    pScrPriv.reqHeight = pScreen.height;
    pScrPriv.rotation = RR_Rotate_0;

    /*
     * This value doesn't really matter -- any client must call
     * GetScreenInfo before reading it which will automatically update
     * the time
     */
    pScrPriv.lastSetTime = currentTime;
    pScrPriv.lastConfigTime = currentTime;

    dixScreenHookClose(pScreen, &RRCloseScreen);

    pScreen.ConstrainCursorHarder = &RRConstrainCursorHarder;
    pScreen.ReplaceScanoutPixmap = &RRReplaceScanoutPixmap;

    xorg_list_init(&pScrPriv.leases);

    RRMonitorInit(pScreen);

    RRNScreens += 1;            /* keep count of screens that implement randr */
    return TRUE;
}

 /*ARGSUSED*/ private int RRFreeClient(void* data, XID id)
{
    RREventPtr pRREvent = void;
    WindowPtr pWin = void;
    RREventPtr* pHead = void; RREventPtr pCur = void, pPrev = void;

    pRREvent = cast(RREventPtr) data;
    pWin = pRREvent.window;
    dixLookupResourceByType(cast(void**) &pHead, pWin.drawable.id,
                            RREventType, serverClient, DixDestroyAccess);
    if (pHead) {
        pPrev = null;
        for (pCur = *pHead; pCur && pCur != pRREvent; pCur = pCur.next)
            pPrev = pCur;
        if (pCur) {
            if (pPrev)
                pPrev.next = pRREvent.next;
            else
                *pHead = pRREvent.next;
        }
    }
    free(cast(void*) pRREvent);
    return 1;
}

 /*ARGSUSED*/ private int RRFreeEvents(void* data, XID id)
{
    RREventPtr* pHead = void; RREventPtr pCur = void, pNext = void;

    pHead = cast(RREventPtr*) data;
    for (pCur = *pHead; pCur; pCur = pNext) {
        pNext = pCur.next;
        FreeResource(cast(uint)pCur.clientResource, RRClientType);
        free(cast(void*) pCur);
    }
    free(cast(void*) pHead);
    return 1;
}

void RRExtensionInit()
{
    ExtensionEntry* extEntry = void;

    if (RRNScreens == 0)
        return;

    if (!dixRegisterPrivateKey(&RRClientPrivateKeyRec, PRIVATE_CLIENT,
                               cast(uint)((RRClientRec).sizeof +
                               screenInfo.numScreens * RRTimesRec.sizeof)))
        return;
    if (!AddCallback(&ClientStateCallback, &RRClientCallback, null))
        return;

    RRClientType = CreateNewResourceType(&RRFreeClient, "RandRClient");
    if (!RRClientType)
        return;
    RREventType = CreateNewResourceType(&RRFreeEvents, "RandREvent");
    if (!RREventType)
        return;
    extEntry = AddExtension(RANDR_NAME, RRNumberEvents, RRNumberErrors,
                            &ProcRRDispatch, &ProcRRDispatch,
                            null, &StandardMinorOpcode);
    if (!extEntry)
        return;
    RRErrorBase = extEntry.errorBase;
    RREventBase = extEntry.eventBase;
    EventSwapVector[RREventBase + RRScreenChangeNotify] = cast(EventSwapPtr)
        &SRRScreenChangeNotifyEvent;
    EventSwapVector[RREventBase + RRNotify] = cast(EventSwapPtr)
        &SRRNotifyEvent;

    RRModeInitErrorValue();
    RRCrtcInitErrorValue();
    RROutputInitErrorValue();
    RRProviderInitErrorValue();
static if(XINERAMA){
    RRXineramaExtensionInit();
} /* XINERAMA */
}

void RRResourcesChanged(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    pScrPriv.resourcesChanged = TRUE;

    RRSetChanged(pScreen);
}

private void RRDeliverResourceEvent(ClientPtr client, WindowPtr pWin)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;

    mixin(rrScrPriv!("pScreen"));

    xRRResourceChangeNotifyEvent re = {
        type: cast(ubyte)(RRNotify + RREventBase),
        subCode: RRNotify_ResourceChange,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        window: cast(uint)pWin.drawable.id
    };

    WriteEventsToClient(client, 1, cast(xEvent*) &re);
}

private int TellChanged(WindowPtr pWin, void* value)
{
    RREventPtr* pHead = void; RREventPtr pRREvent = void;
    ClientPtr client = void;
    ScreenPtr pScreen = pWin.drawable.pScreen;
    ScreenPtr iter = void;
    rrScrPrivPtr pSecondaryScrPriv = void;

    mixin(rrScrPriv!("pScreen"));
    int i = void;

    dixLookupResourceByType(cast(void**) &pHead, pWin.drawable.id,
                            RREventType, serverClient, DixReadAccess);
    if (!pHead)
        return WT_WALKCHILDREN;

    for (pRREvent = *pHead; pRREvent; pRREvent = pRREvent.next) {
        client = pRREvent.client;
        if (client == serverClient || client.clientGone)
            continue;

        if (pRREvent.mask & RRScreenChangeNotifyMask)
            RRDeliverScreenEvent(client, pWin, pScreen);

        if (pRREvent.mask & RRCrtcChangeNotifyMask) {
            for (i = 0; i < pScrPriv.numCrtcs; i++) {
                RRCrtcPtr crtc = pScrPriv.crtcs[i];

                if (crtc.changed)
                    RRDeliverCrtcEvent(client, pWin, crtc);
            }

            mixin(xorg_list_for_each_entry!("iter", "&pScreen.secondary_list", "secondary_head", q{
                if (!iter.is_output_secondary)
                    continue;

                pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
                for (i = 0; i < pSecondaryScrPriv.numCrtcs; i++) {
                    RRCrtcPtr crtc = pSecondaryScrPriv.crtcs[i];

                    if (crtc.changed)
                        RRDeliverCrtcEvent(client, pWin, crtc);
                }
            }));
        }

        if (pRREvent.mask & RROutputChangeNotifyMask) {
            for (i = 0; i < pScrPriv.numOutputs; i++) {
                RROutputPtr output = pScrPriv.outputs[i];

                if (output.changed)
                    RRDeliverOutputEvent(client, pWin, output);
            }

            mixin(xorg_list_for_each_entry!("iter", "&pScreen.secondary_list", "secondary_head", q{
                if (!iter.is_output_secondary)
                    continue;

                pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
                for (i = 0; i < pSecondaryScrPriv.numOutputs; i++) {
                    RROutputPtr output = pSecondaryScrPriv.outputs[i];

                    if (output.changed)
                        RRDeliverOutputEvent(client, pWin, output);
                }
            }));
        }

        if (pRREvent.mask & RRProviderChangeNotifyMask) {
            mixin(xorg_list_for_each_entry!("iter", "&pScreen.secondary_list", "secondary_head", q{
                pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
                if (pSecondaryScrPriv.provider.changed)
                    RRDeliverProviderEvent(client, pWin, pSecondaryScrPriv.provider);
            }));
        }

        if (pRREvent.mask & RRResourceChangeNotifyMask) {
            if (pScrPriv.resourcesChanged) {
                RRDeliverResourceEvent(client, pWin);
            }
        }

        if (pRREvent.mask & RRLeaseNotifyMask) {
            if (pScrPriv.leasesChanged) {
                RRDeliverLeaseEvent(client, pWin);
            }
        }
    }
    return WT_WALKCHILDREN;
}

void RRSetChanged(ScreenPtr pScreen)
{
    /* set changed bits on the primary screen only */
    ScreenPtr primary = void;
    mixin(rrScrPriv!("pScreen"));
    rrScrPrivPtr primarysp = void;

    if (pScreen.isGPU) {
        primary = pScreen.current_primary;
        if (!primary)
            return;
        primarysp = mixin(rrGetScrPriv!("primary"));
    }
    else {
        primary = pScreen;
        primarysp = pScrPriv;
    }

    primarysp.changed = TRUE;
}

/*
 * Something changed; send events and adjust pointer position
 */
void RRTellChanged(ScreenPtr pScreen)
{
    ScreenPtr primary = void;
    mixin(rrScrPriv!("pScreen"));
    rrScrPrivPtr primarysp = void;
    int i = void;
    ScreenPtr iter = void;
    rrScrPrivPtr pSecondaryScrPriv = void;

    if (pScreen.isGPU) {
        primary = pScreen.current_primary;
        if (!primary)
            return;
        primarysp = mixin(rrGetScrPriv!("primary"));
    }
    else {
        primary = pScreen;
        primarysp = pScrPriv;
    }

    /* If there's no root window yet, can't send events */
    if (!primary.root)
        return;

    mixin(xorg_list_for_each_entry!("iter", "&primary.secondary_list", "secondary_head", q{
        pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));

        if (!iter.is_output_secondary)
            continue;

        if (CompareTimeStamps(primarysp.lastSetTime,
                              pSecondaryScrPriv.lastSetTime) == EARLIER) {
            primarysp.lastSetTime = pSecondaryScrPriv.lastSetTime;
        }
    }));

    if (primarysp.changed) {
        UpdateCurrentTimeIf();
        if (primarysp.configChanged) {
            primarysp.lastConfigTime = currentTime;
            primarysp.configChanged = FALSE;
        }
        pScrPriv.changed = FALSE;
        primarysp.changed = FALSE;

        WalkTree(primary, &TellChanged, cast(void*) primary);

        primarysp.resourcesChanged = FALSE;

        for (i = 0; i < pScrPriv.numOutputs; i++)
            pScrPriv.outputs[i].changed = FALSE;
        for (i = 0; i < pScrPriv.numCrtcs; i++)
            pScrPriv.crtcs[i].changed = FALSE;

        mixin(xorg_list_for_each_entry!("iter", "&primary.secondary_list", "secondary_head", q{
            pSecondaryScrPriv = mixin(rrGetScrPriv!("iter"));
            pSecondaryScrPriv.provider.changed = FALSE;
            if (iter.is_output_secondary) {
                for (i = 0; i < pSecondaryScrPriv.numOutputs; i++)
                    pSecondaryScrPriv.outputs[i].changed = FALSE;
                for (i = 0; i < pSecondaryScrPriv.numCrtcs; i++)
                    pSecondaryScrPriv.crtcs[i].changed = FALSE;
            }
        }));

        if (primarysp.layoutChanged) {
            pScrPriv.layoutChanged = FALSE;
            RRPointerScreenConfigured(primary);
            RRSendConfigNotify(primary);
        }
    }
}

/*
 * Return the first output which is connected to an active CRTC
 * Used in emulating 1.0 behaviour
 */
RROutputPtr RRFirstOutput(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    RROutputPtr output = void;
    int i = void, j = void;

    if (!pScrPriv)
        return null;

    if (pScrPriv.primaryOutput && pScrPriv.primaryOutput.crtc)
        return pScrPriv.primaryOutput;

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];

        for (j = 0; j < pScrPriv.numOutputs; j++) {
            output = pScrPriv.outputs[j];
            if (output.crtc == crtc)
                return output;
        }
    }
    return null;
}

RRCrtcPtr RRFirstEnabledCrtc(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    RROutputPtr output = void;
    int i = void, j = void;

    if (!pScrPriv)
        return null;

    if (pScrPriv.primaryOutput && pScrPriv.primaryOutput.crtc &&
        pScrPriv.primaryOutput.pScreen == pScreen)
        return pScrPriv.primaryOutput.crtc;

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];

        for (j = 0; j < pScrPriv.numOutputs; j++) {
            output = pScrPriv.outputs[j];
            if (output.crtc == crtc && crtc.mode)
                return crtc;
        }
    }
    return null;
}


CARD16 RRVerticalRefresh(xRRModeInfo* mode)
{
    CARD32 refresh = void;
    CARD32 dots = mode.hTotal * mode.vTotal;

    if (!dots)
        return 0;
    refresh = (mode.dotClock + dots / 2) / dots;
    if (refresh > 0xffff)
        refresh = 0xffff;
    return cast(CARD16) refresh;
}
