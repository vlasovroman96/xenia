module randr.rrprovider;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2012 Red Hat Inc.
 * Copyright 2019 DisplayLink (UK) Ltd.
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
 * Authors: Dave Airlie
 */
import build.dix_config;

import externs.X11.Xatom;

import dix.dix_priv;
import dix.request_priv;
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import dix.property;
import dix.swaprep;
import randr.rrcrtc;
import dix.resource;
import randr.rroutput;
import randr.rrmode;
import randr.randr;
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

import dix.swaprep;
import common.bytes;

// RESTYPE RRProviderType = 0;

/*
 * Initialize provider type error value
 */
void RRProviderInitErrorValue()
{
    SetResourceTypeErrorValue(RRProviderType, RRErrorBase + BadRRProvider);
}

enum string ADD_PROVIDER(string _pScreen) = `{                                 
    pScrPriv = mixin(rrGetScrPriv!("` ~ _pScreen ~ `"));                            
    if (pScrPriv.provider) {                                   
        x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)pScrPriv.provider.id); 
        count_providers++;                                      
    }                                                           
    }`;

int ProcRRGetProviders(ClientPtr client)
{
    mixin(REQUEST!xRRGetProvidersReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetProvidersReq);

    if (client.swapped)
        swapl(&stuff.window);

    WindowPtr pWin = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    int rc = void;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    pScreen = pWin.drawable.pScreen;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    if (!pScrPriv)
    {
        xRRGetProvidersReply reply = {
            timestamp: currentTime.milliseconds,
        };
        if (client.swapped)
            swapl(&reply.timestamp);
        return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    CARD16 count_providers = 0;
    mixin(ADD_PROVIDER!(`pScreen`));
    foreach(iter; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
        mixin(ADD_PROVIDER!(`iter`));
    }

    xRRGetProvidersReply reply = {
        timestamp: pScrPriv.lastSetTime.milliseconds,
        nProviders: count_providers,
    };

    if (client.swapped) {
        swapl(&reply.timestamp);
        swaps(&reply.nProviders);
    }
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRGetProviderInfo(ClientPtr client)
{
    mixin(REQUEST!xRRGetProviderInfoReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetProviderInfoReq);

    if (client.swapped) {
        swapl(&stuff.provider);
        swapl(&stuff.configTimestamp);
    }

    rrScrPrivPtr pScrPriv = void, pScrProvPriv = void;
    RRProviderPtr provider = void;
    ScreenPtr pScreen = void;
    CARD8* extra = void;
    uint extraLen = 0;
    RRCrtc* crtcs = void;
    RROutput* outputs = void;
    int i = void;
    char* name = void;
    RRProvider* providers = void;
    uint* prov_cap = void;

    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));

    pScreen = provider.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    xRRGetProviderInfoReply reply = {
        status: RRSetConfigSuccess,
        capabilities: provider.capabilities,
        nameLength: cast(ushort)provider.nameLength,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        nCrtcs: cast(ushort)pScrPriv.numCrtcs,
        nOutputs: cast(ushort)pScrPriv.numOutputs,
    };

    /* count associated providers */
    if (provider.offload_sink)
        reply.nAssociatedProviders++;
    if (provider.output_source &&
            provider.output_source != provider.offload_sink)
        reply.nAssociatedProviders++;
    foreach(provscreen; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
        if (provscreen.is_output_secondary || provscreen.is_offload_secondary)
            reply.nAssociatedProviders++;
    }

    reply.length = (pScrPriv.numCrtcs + pScrPriv.numOutputs +
                   (reply.nAssociatedProviders * 2) + int32ForBytes(reply.nameLength));

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    extraLen = cast(uint)(reply.length << 2);
    if (extraLen) {
        extra = cast(ubyte*)x_rpcbuf_reserve(&rpcbuf, extraLen);
        if (!extra)
            return BadAlloc;
    }
    else
        extra = null;

    crtcs = cast(RRCrtc*)extra;
    outputs = cast(RROutput*)(crtcs + reply.nCrtcs);
    providers = cast(RRProvider*)(outputs + reply.nOutputs);
    prov_cap = cast(uint*)(providers + reply.nAssociatedProviders);
    name = cast(char*)(prov_cap + reply.nAssociatedProviders);

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        crtcs[i] = pScrPriv.crtcs[i].id;
        if (client.swapped)
            swapl(&crtcs[i]);
    }

    for (i = 0; i < pScrPriv.numOutputs; i++) {
        outputs[i] = pScrPriv.outputs[i].id;
        if (client.swapped)
            swapl(&outputs[i]);
    }

    i = 0;
    if (provider.offload_sink) {
        providers[i] = provider.offload_sink.id;
        if (client.swapped)
            swapl(&providers[i]);
        prov_cap[i] = RR_Capability_SinkOffload;
        if (client.swapped)
            swapl(&prov_cap[i]);
        i++;
    }
    if (provider.output_source) {
        providers[i] = provider.output_source.id;
        prov_cap[i] = RR_Capability_SourceOutput;
        if (client.swapped) {
            swapl(&providers[i]);
            swapl(&prov_cap[i]);
        }
        i++;
    }
    foreach(provscreen; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
        if (!provscreen.is_output_secondary && !provscreen.is_offload_secondary)
            continue;
        pScrProvPriv = mixin(rrGetScrPriv!("provscreen"));
        providers[i] = pScrProvPriv.provider.id;
        if (client.swapped)
            swapl(&providers[i]);
        prov_cap[i] = 0;
        if (provscreen.is_output_secondary)
            prov_cap[i] |= RR_Capability_SinkOutput;
        if (provscreen.is_offload_secondary)
            prov_cap[i] |= RR_Capability_SourceOffload;
        if (client.swapped)
            swapl(&prov_cap[i]);
        i++;
    }

    memcpy(name, provider.name, reply.nameLength);
    if (client.swapped) {
        swapl(&reply.capabilities);
        swaps(&reply.nCrtcs);
        swaps(&reply.nOutputs);
        swaps(&reply.nameLength);
        swapl(&reply.timestamp);
        swaps(&reply.nAssociatedProviders);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private void RRInitPrimeSyncProps(ScreenPtr pScreen)
{
    /*
     * TODO: When adding support for different sources for different outputs,
     * make sure this sets up the output properties only on outputs associated
     * with the correct source provider.
     */

    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    const(char)* syncStr = PRIME_SYNC_PROP;
    Atom syncProp = dixAddAtom(syncStr);

    int defaultVal = TRUE;
    INT32[2] validVals = [FALSE, TRUE];

    int i = void;
    for (i = 0; i < pScrPriv.numOutputs; i++) {
        if (!RRQueryOutputProperty(pScrPriv.outputs[i], syncProp)) {
            RRConfigureOutputProperty(pScrPriv.outputs[i], syncProp,
                                      TRUE, FALSE, FALSE,
                                      2, &validVals[0]);
            RRChangeOutputProperty(pScrPriv.outputs[i], syncProp, XA_INTEGER,
                                   8, PropModeReplace, 1, &defaultVal,
                                   FALSE, FALSE);
        }
    }
}

private void RRFiniPrimeSyncProps(ScreenPtr pScreen)
{
    /*
     * TODO: When adding support for different sources for different outputs,
     * make sure this tears down the output properties only on outputs
     * associated with the correct source provider.
     */

    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    int i = void;

    const(char)* syncStr = PRIME_SYNC_PROP;
    Atom syncProp = dixGetAtomID(syncStr);
    if (syncProp == None)
        return;

    for (i = 0; i < pScrPriv.numOutputs; i++) {
        RRDeleteOutputProperty(pScrPriv.outputs[i], syncProp);
    }
}

int ProcRRSetProviderOutputSource(ClientPtr client)
{
    mixin(REQUEST!xRRSetProviderOutputSourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetProviderOutputSourceReq);

    if (client.swapped) {
        swapl(&stuff.provider);
        swapl(&stuff.source_provider);
        swapl(&stuff.configTimestamp);
    }

    rrScrPrivPtr pScrPriv = void;
    RRProviderPtr provider = void, source_provider = null;
    ScreenPtr pScreen = void;

    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));

    if (!(provider.capabilities & RR_Capability_SinkOutput))
        return BadValue;

    if (stuff.source_provider) {
        mixin(VERIFY_RR_PROVIDER!("stuff.source_provider", "source_provider", "DixReadAccess"));

        if (!(source_provider.capabilities & RR_Capability_SourceOutput))
            return BadValue;
    }

    pScreen = provider.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (!pScreen.isGPU)
        return BadValue;

    pScrPriv.rrProviderSetOutputSource(pScreen, provider, source_provider);

    RRInitPrimeSyncProps(pScreen);

    provider.changed = TRUE;
    RRSetChanged(pScreen);

    RRTellChanged (pScreen);

    return Success;
}

int ProcRRSetProviderOffloadSink(ClientPtr client)
{
    mixin(REQUEST!xRRSetProviderOffloadSinkReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetProviderOffloadSinkReq);

    if (client.swapped) {
        swapl(&stuff.provider);
        swapl(&stuff.sink_provider);
        swapl(&stuff.configTimestamp);
    }

    rrScrPrivPtr pScrPriv = void;
    RRProviderPtr provider = void, sink_provider = null;
    ScreenPtr pScreen = void;

    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));
    if (!(provider.capabilities & RR_Capability_SourceOffload))
        return BadValue;
    if (!provider.pScreen.isGPU)
        return BadValue;

    if (stuff.sink_provider) {
        mixin(VERIFY_RR_PROVIDER!("stuff.sink_provider", "sink_provider", "DixReadAccess"));
        if (!(sink_provider.capabilities & RR_Capability_SinkOffload))
            return BadValue;
    }
    pScreen = provider.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    pScrPriv.rrProviderSetOffloadSink(pScreen, provider, sink_provider);

    provider.changed = TRUE;
    RRSetChanged(pScreen);

    RRTellChanged (pScreen);

    return Success;
}

RRProviderPtr RRProviderCreate(ScreenPtr pScreen, const(char)* name, int nameLength)
{
    RRProviderPtr provider = void;
    rrScrPrivPtr pScrPriv = void;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    provider = cast(RRProviderPtr)calloc(1, ((RRProviderRec).sizeof + nameLength + 1));
    if (!provider)
        return null;

    provider.id = dixAllocServerXID();
    provider.pScreen = pScreen;
    provider.name = cast(char*) (provider + 1);
    provider.nameLength = nameLength;
    memcpy(provider.name, name, nameLength);
    provider.name[nameLength] = '\0';
    provider.changed = FALSE;

    if (!AddResource (provider.id, RRProviderType, cast(void*) provider))
        return null;
    pScrPriv.provider = provider;
    return provider;
}

/*
 * Destroy a provider at shutdown
 */
void RRProviderDestroy(RRProviderPtr provider)
{
    RRFiniPrimeSyncProps(provider.pScreen);
    FreeResource (provider.id, 0);
}

void RRProviderSetCapabilities(RRProviderPtr provider, uint capabilities)
{
    provider.capabilities = capabilities;
}

private int RRProviderDestroyResource(void* value, XID pid)
{
    RRProviderPtr provider = cast(RRProviderPtr)value;
    ScreenPtr pScreen = provider.pScreen;

    if (pScreen)
    {
        mixin(rrScrPriv!("pScreen"));

        if (pScrPriv.rrProviderDestroy)
            (*pScrPriv.rrProviderDestroy)(pScreen, provider);
        pScrPriv.provider = null;
    }
    free(provider);
    return 1;
}

Bool RRProviderInit()
{
    RRProviderType = CreateNewResourceType(&RRProviderDestroyResource, "Provider");
    if (!RRProviderType)
        return FALSE;

    return TRUE;
}

void RRDeliverProviderEvent(ClientPtr client, WindowPtr pWin, RRProviderPtr provider)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;

    mixin(rrScrPriv!("pScreen"));

    xRRProviderChangeNotifyEvent pe = {
        type: cast(ubyte)(RRNotify + RREventBase),
        subCode: RRNotify_ProviderChange,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        window: cast(uint)pWin.drawable.id,
        provider: cast(uint)provider.id
    };

    WriteEventsToClient(client, 1, cast(xEvent*) &pe);
}

void RRProviderAutoConfigGpuScreen(ScreenPtr pScreen, ScreenPtr primaryScreen)
{
    rrScrPrivPtr pScrPriv = void;
    rrScrPrivPtr primaryPriv = void;
    RRProviderPtr provider = void;
    RRProviderPtr primary_provider = void;

    /* Bail out if RandR wasn't initialized. */
    if (!dixPrivateKeyRegistered(rrPrivKey))
        return;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    primaryPriv = mixin(rrGetScrPriv!("primaryScreen"));

    provider = pScrPriv.provider;
    primary_provider = primaryPriv.provider;

    if (!provider || !primary_provider)
        return;

    if ((provider.capabilities & RR_Capability_SinkOutput) &&
        (primary_provider.capabilities & RR_Capability_SourceOutput)) {
        pScrPriv.rrProviderSetOutputSource(pScreen, provider, primary_provider);
        RRInitPrimeSyncProps(pScreen);

        primaryPriv.configChanged = TRUE;
        RRSetChanged(primaryScreen);
    }

    if ((provider.capabilities & RR_Capability_SourceOffload) &&
        (primary_provider.capabilities & RR_Capability_SinkOffload))
        pScrPriv.rrProviderSetOffloadSink(pScreen, provider, primary_provider);
}
