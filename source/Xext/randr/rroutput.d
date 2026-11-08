module randr.rroutput;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2006 Keith Packard
 * Copyright © 2008 Red Hat, Inc.
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
 */
import build.dix_config;

import externs.X11.Xatom;

import dix.dix_priv;
import dix.request_priv;
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import randr.rrcrtc;
import dix.resource;
import randr.rroutput;
import randr.rrmode;
import randr.rroutput;
import randr.rroutput;
import os.io;
import dix.events;
import dix.pixmap;
import randr.rrproperty;
import render.filter;
import dix.swapreq;
import randr.rrmode;
import randr.rrinfo;

RESTYPE RROutputType;

/*
 * Notify the output of some change
 */
void RROutputChanged(RROutputPtr output, Bool configChanged)
{
    /* set changed bits on the primary screen only */
    ScreenPtr pScreen = output.pScreen;
    rrScrPrivPtr primarysp = void;

    output.changed = TRUE;
    if (!pScreen)
        return;

    if (pScreen.isGPU) {
        ScreenPtr primary = pScreen.current_primary;
        if (!primary)
            return;
        primarysp = mixin(rrGetScrPriv!("primary"));
    }
    else {
        primarysp = mixin(rrGetScrPriv!("pScreen"));
    }

    RRSetChanged(pScreen);
    if (configChanged)
        primarysp.configChanged = TRUE;
}

/*
 * Create an output
 */

RROutputPtr RROutputCreate(ScreenPtr pScreen, const(char)* name, int nameLength, void* devPrivate)
{
    RROutputPtr output = void;
    RROutputPtr* outputs = void;
    rrScrPrivPtr pScrPriv = void;
    Atom DPIAtom = void;

    if (!RRInit())
        return null;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    outputs = cast(_rrOutput**)reallocarray(pScrPriv.outputs,
                           pScrPriv.numOutputs + 1, RROutputPtr.sizeof);
    if (!outputs)
        return null;

    pScrPriv.outputs = outputs;

    output = cast(_rrOutput*)calloc(1, ((RROutputRec).sizeof + nameLength + 1));
    if (!output)
        return null;
    output.id = dixAllocServerXID();
    output.pScreen = pScreen;
    output.name = cast(char*) (output + 1);
    output.nameLength = nameLength;
    memcpy(output.name, name, nameLength);
    output.name[nameLength] = '\0';
    output.connection = RR_UnknownConnection;
    output.subpixelOrder = SubPixelUnknown;
    output.devPrivate = devPrivate;

    if (!AddResource(cast(uint)output.id, RROutputType, cast(void*) output))
        return null;

    pScrPriv.outputs[pScrPriv.numOutputs++] = output;

    Atom nonDesktopAtom = dixAddAtom(RR_PROPERTY_NON_DESKTOP);
    if (nonDesktopAtom != BAD_RESOURCE) {
        static const(INT32)[2] values = [ 0, 1 ];
        cast(void) RRConfigureOutputProperty(output, nonDesktopAtom, FALSE, FALSE, FALSE,
                                            2, values.ptr);
    }
    RROutputSetNonDesktop(output, FALSE);

    /* Initialize DPI property for all outputs. */
    DPIAtom = dixAddAtom("DPI");
    if (DPIAtom != BAD_RESOURCE) {
        static const(INT32)[2] values = [ 0, 960 ]; // arbitrary range
        cast(void) RRConfigureOutputProperty(output, DPIAtom, FALSE, TRUE, FALSE,
                                         2, values.ptr);
        INT32 value = monitorResolution ? monitorResolution : 96;
        cast(void) RRChangeOutputProperty(output, DPIAtom, XA_INTEGER, 32,
                                      PropModeReplace, 1, &value, FALSE, FALSE);
    }

    RRResourcesChanged(pScreen);

    return output;
}

/*
 * Notify extension that output parameters have been changed
 */
Bool RROutputSetClones(RROutputPtr output, RROutputPtr* clones, int numClones)
{
    int i = void;

    if (numClones == output.numClones) {
        for (i = 0; i < numClones; i++)
            if (output.clones[i] != clones[i])
                break;
        if (i == numClones)
            return TRUE;
    }

    RROutputPtr* newClones = null;
    if (numClones) {
        newClones = cast(RROutputPtr*) calloc(numClones, RROutputPtr.sizeof);
        if (!newClones)
            return FALSE;
        memcpy(newClones, clones, numClones * RROutputPtr.sizeof);
    }

    free(output.clones);
    output.clones = newClones;
    output.numClones = numClones;
    RROutputChanged(output, TRUE);
    return TRUE;
}

Bool RROutputSetModes(RROutputPtr output, RRModePtr* modes, int numModes, int numPreferred)
{
    int i = void;

    if (numModes == output.numModes && numPreferred == output.numPreferred) {
        for (i = 0; i < numModes; i++)
            if (output.modes[i] != modes[i])
                break;
        if (i == numModes) {
            for (i = 0; i < numModes; i++)
                RRModeDestroy(modes[i]);
            return TRUE;
        }
    }

    RRModePtr* newModes = null;
    if (numModes) {
        newModes = cast(RRModePtr*) calloc(numModes, RRModePtr.sizeof);
        if (!newModes)
            return FALSE;
        memcpy(newModes, modes, numModes * RRModePtr.sizeof);
    }

    if (output.modes) {
        for (i = 0; i < output.numModes; i++)
            RRModeDestroy(output.modes[i]);
        free(output.modes);
    }
    output.modes = newModes;
    output.numModes = numModes;
    output.numPreferred = numPreferred;
    RROutputChanged(output, TRUE);
    return TRUE;
}

int RROutputAddUserMode(RROutputPtr output, RRModePtr mode)
{
    int m = void;
    ScreenPtr pScreen = output.pScreen;

    mixin(rrScrPriv!("pScreen"));
    RRModePtr* newModes = void;

    /* Check to see if this mode is already listed for this output */
    for (m = 0; m < output.numModes + output.numUserModes; m++) {
        RRModePtr e = (m < output.numModes ?
                       output.modes[m] :
                       output.userModes[m - output.numModes]);
        if (mode == e)
            return Success;
    }

    /* Check with the DDX to see if this mode is OK */
    if (pScrPriv.rrOutputValidateMode)
        if (!pScrPriv.rrOutputValidateMode(pScreen, output, mode))
            return BadMatch;

    if (output.userModes)
        newModes = cast(_rrMode**)reallocarray(output.userModes,
                                output.numUserModes + 1, RRModePtr.sizeof);
    else
        newModes = cast(RRModePtr*) cast(RRModePtr*) calloc(1, RRModePtr.sizeof);
    if (!newModes)
        return BadAlloc;

    output.userModes = newModes;
    output.userModes[output.numUserModes++] = mode;
    ++mode.refcnt;
    RROutputChanged(output, TRUE);
    RRTellChanged(pScreen);
    return Success;
}

int RROutputDeleteUserMode(RROutputPtr output, RRModePtr mode)
{
    int m = void;

    /* Find this mode in the user mode list */
    for (m = 0; m < output.numUserModes; m++) {
        RRModePtr e = output.userModes[m];

        if (mode == e)
            break;
    }
    /* Not there, access error */
    if (m == output.numUserModes)
        return BadAccess;

    /* make sure the mode isn't active for this output */
    if (output.crtc && output.crtc.mode == mode)
        return BadMatch;

    memmove(output.userModes + m, output.userModes + m + 1,
            (output.numUserModes - m - 1) * RRModePtr.sizeof);
    output.numUserModes--;
    RRModeDestroy(mode);
    return Success;
}

Bool RROutputSetCrtcs(RROutputPtr output, RRCrtcPtr* crtcs, int numCrtcs)
{
    int i = void;

    if (numCrtcs == output.numCrtcs) {
        for (i = 0; i < numCrtcs; i++)
            if (output.crtcs[i] != crtcs[i])
                break;
        if (i == numCrtcs)
            return TRUE;
    }

    RRCrtcPtr* newCrtcs = null;
    if (numCrtcs) {
        newCrtcs = cast(RRCrtcPtr*) calloc(numCrtcs, RRCrtcPtr.sizeof);
        if (!newCrtcs)
            return FALSE;
        memcpy(newCrtcs, crtcs, numCrtcs * RRCrtcPtr.sizeof);
    }

    free(output.crtcs);
    output.crtcs = newCrtcs;
    output.numCrtcs = numCrtcs;
    RROutputChanged(output, TRUE);
    return TRUE;
}

Bool RROutputSetConnection(RROutputPtr output, CARD8 connection)
{
    if (output.connection == connection)
        return TRUE;
    output.connection = connection;
    RROutputChanged(output, TRUE);
    return TRUE;
}

void RROutputSetSubpixelOrder(RROutputPtr output, int subpixelOrder)
{
    if (output.subpixelOrder == subpixelOrder)
        return;

    output.subpixelOrder = cast(ubyte)subpixelOrder;
    RROutputChanged(output, FALSE);
}

Bool RROutputSetPhysicalSize(RROutputPtr output, int mmWidth, int mmHeight)
{
    if (output.mmWidth == mmWidth && output.mmHeight == mmHeight)
        return TRUE;
    output.mmWidth = mmWidth;
    output.mmHeight = mmHeight;
    RROutputChanged(output, FALSE);
    return TRUE;
}

Bool RROutputSetNonDesktop(RROutputPtr output, Bool nonDesktop)
{
    const(char)* nonDesktopStr = RR_PROPERTY_NON_DESKTOP;
    Atom nonDesktopProp = dixAddAtom(nonDesktopStr);
    uint value = nonDesktop ? 1 : 0;

    if (nonDesktopProp == None || nonDesktopProp == BAD_RESOURCE)
        return FALSE;

    return RRChangeOutputProperty(output, nonDesktopProp, XA_INTEGER, 32,
                                  PropModeReplace, 1, &value, TRUE, FALSE) == Success;
}

void RRDeliverOutputEvent(ClientPtr client, WindowPtr pWin, RROutputPtr output)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;

    mixin(rrScrPriv!("pScreen"));
    RRCrtcPtr crtc = output.crtc;
    RRModePtr mode = crtc ? crtc.mode : null;

    xRROutputChangeNotifyEvent oe = {
        type: cast(ubyte)(RRNotify + RREventBase),
        subCode: RRNotify_OutputChange,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        configTimestamp: pScrPriv.lastConfigTime.milliseconds,
        window: cast(uint)pWin.drawable.id,
        output: cast(uint)output.id,
        crtc: cast(uint)(crtc ? crtc.id : None),
        mode: mode ? mode.mode.id : None,
        rotation: crtc ? crtc.rotation : RR_Rotate_0,
        connection: output.nonDesktop ? RR_Disconnected : output.connection,
        subpixelOrder: output.subpixelOrder
    };
    WriteEventsToClient(client, 1, cast(xEvent*) &oe);
}

/*
 * Destroy a Output at shutdown
 */
void RROutputDestroy(RROutputPtr output)
{
    FreeResource(cast(uint)output.id, 0);
}

private int RROutputDestroyResource(void* value, XID pid)
{
    RROutputPtr output = cast(RROutputPtr) value;
    ScreenPtr pScreen = output.pScreen;
    ScreenPtr primary = void;
    rrScrPrivPtr primarysp = void;
    int m = void;

    if (pScreen) {
        mixin(rrScrPriv!("pScreen"));
        int i = void;

        foreach(lease; pScrPriv.leases.byEntriesSafe!RRLeasePtr) {
            int o = void;
            for (o = 0; o < lease.numOutputs; o++) {
                if (lease.outputs[o] == output) {
                    RRTerminateLease(lease);
                    break;
                }
            }
        }

        if (pScrPriv.primaryOutput == output)
            pScrPriv.primaryOutput = null;

        if (pScreen.isGPU) {
            primary = pScreen.current_primary;
            if (primary) {
                primarysp = mixin(rrGetScrPriv!("primary"));
                if (primarysp.primaryOutput == output)
                    primarysp.primaryOutput = null;
            }
        }

        for (i = 0; i < pScrPriv.numOutputs; i++) {
            if (pScrPriv.outputs[i] == output) {
                memmove(pScrPriv.outputs + i, pScrPriv.outputs + i + 1,
                        (pScrPriv.numOutputs - (i + 1)) * RROutputPtr.sizeof);
                --pScrPriv.numOutputs;
                break;
            }
        }

        RRResourcesChanged(pScreen);
    }
    if (output.modes) {
        for (m = 0; m < output.numModes; m++)
            RRModeDestroy(output.modes[m]);
        free(output.modes);
    }

    for (m = 0; m < output.numUserModes; m++)
        RRModeDestroy(output.userModes[m]);
    free(output.userModes);

    free(output.crtcs);
    free(output.clones);
    RRDeleteAllOutputProperties(output);
    free(output);
    return 1;
}

/*
 * Initialize output type
 */
Bool RROutputInit()
{
    RROutputType = CreateNewResourceType(&RROutputDestroyResource, "OUTPUT");
    if (!RROutputType)
        return FALSE;

    return TRUE;
}

/*
 * Initialize output type error value
 */
void RROutputInitErrorValue()
{
    SetResourceTypeErrorValue(RROutputType, RRErrorBase + BadRROutput);
}

int ProcRRGetOutputInfo(ClientPtr client)
{
    mixin(REQUEST!xRRGetOutputInfoReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetOutputInfoReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.configTimestamp);
    }

    RROutputPtr output = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    int i = void;
    Bool leased = void;

    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));

    leased = RROutputIsLeased(output);

    pScreen = output.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    xRRGetOutputInfoReply reply = {
        status: RRSetConfigSuccess,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        nameLength: cast(ushort)output.nameLength,
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (leased) {
        reply.connection = RR_Disconnected;
        reply.subpixelOrder = SubPixelUnknown;
    } else {
        reply.crtc = cast(uint)(output.crtc ? output.crtc.id : None);
        reply.mmWidth = output.mmWidth;
        reply.mmHeight = output.mmHeight;
        reply.connection = output.nonDesktop ? RR_Disconnected : output.connection;
        reply.subpixelOrder = output.subpixelOrder;
        reply.nCrtcs = cast(ushort)output.numCrtcs;
        reply.nModes = cast(ushort)(output.numModes + output.numUserModes);
        reply.nPreferred = cast(ushort)(output.numPreferred);
        reply.nClones = cast(ushort)output.numClones;

        for (i = 0; i < output.numCrtcs; i++)
            x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)output.crtcs[i].id);

        for (i = 0; i < output.numModes + output.numUserModes; i++) {
            if (i < output.numModes)
                x_rpcbuf_write_CARD32(&rpcbuf, output.modes[i].mode.id);
            else
                x_rpcbuf_write_CARD32(&rpcbuf, output.userModes[i - output.numModes].mode.id);
        }

        for (i = 0; i < output.numClones; i++)
            x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)output.clones[i].id);
    }

    x_rpcbuf_write_string_pad(&rpcbuf, output.name); /* indeed 0-terminated */

    if (client.swapped) {
        swapl(&reply.timestamp);
        swapl(&reply.crtc);
        swapl(&reply.mmWidth);
        swapl(&reply.mmHeight);
        swaps(&reply.nCrtcs);
        swaps(&reply.nModes);
        swaps(&reply.nPreferred);
        swaps(&reply.nClones);
        swaps(&reply.nameLength);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private void RRSetPrimaryOutput(ScreenPtr pScreen, rrScrPrivPtr pScrPriv, RROutputPtr output)
{
    if (pScrPriv.primaryOutput == output)
        return;

    /* clear the old primary */
    if (pScrPriv.primaryOutput) {
        RROutputChanged(pScrPriv.primaryOutput, 0);
        pScrPriv.primaryOutput = null;
    }

    /* set the new primary */
    if (output) {
        pScrPriv.primaryOutput = output;
        RROutputChanged(output, 0);
    }

    pScrPriv.layoutChanged = TRUE;

    RRTellChanged(pScreen);
}

int ProcRRSetOutputPrimary(ClientPtr client)
{
    mixin(REQUEST!xRRSetOutputPrimaryReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetOutputPrimaryReq);

    if (client.swapped) {
        swapl(&stuff.window);
        swapl(&stuff.output);
    }

    RROutputPtr output = null;
    WindowPtr pWin = void;
    rrScrPrivPtr pScrPriv = void;
    int ret = void;

    ret = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (ret != Success)
        return ret;

    if (stuff.output) {
        mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));
;

        if (RROutputIsLeased(output))
            return BadAccess;

        if (!output.pScreen.isGPU && output.pScreen != pWin.drawable.pScreen) {
            client.errorValue = cast(uint)stuff.window;
            return BadMatch;
        }
        if (output.pScreen.isGPU && output.pScreen.current_primary != pWin.drawable.pScreen) {
            client.errorValue = cast(uint)stuff.window;
            return BadMatch;
        }
    }

    pScrPriv = mixin(rrGetScrPriv!("pWin.drawable.pScreen"));
    if (pScrPriv)
    {
        RRSetPrimaryOutput(pWin.drawable.pScreen, pScrPriv, output);

        foreach(secondary; pWin.drawable.pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {                      
            if (secondary.is_output_secondary)
                RRSetPrimaryOutput(secondary, mixin(rrGetScrPriv!("secondary")), output);
        }
    }

    return Success;
}

int ProcRRGetOutputPrimary(ClientPtr client)
{
    mixin(REQUEST!xRRGetOutputPrimaryReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetOutputPrimaryReq);

    if (client.swapped)
        swapl(&stuff.window);

    WindowPtr pWin = void;
    rrScrPrivPtr pScrPriv = void;
    RROutputPtr primary = null;
    int rc = void;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    pScrPriv = mixin(rrGetScrPriv!("pWin.drawable.pScreen"));
    if (pScrPriv)
        primary = pScrPriv.primaryOutput;

    xRRGetOutputPrimaryReply reply = {
        output: cast(uint)(primary ? primary.id : None)
    };

    if (client.swapped) {
        swapl(&reply.output);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}
