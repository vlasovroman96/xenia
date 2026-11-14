module randr.rrscreen;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2006 Keith Packard
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

import dix.dix_priv;
import dix.request_priv;
import dix.server_priv;
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
import externs.attrs;
import os.log;
import randr.rrdispatch;
import dix.timestamp;
import common.bytes;
import common.swap;
import dix.dispatch;

/*
 * Edit connection information block so that new clients
 * see the current screen size on connect
 */
private void RREditConnectionInfo(ScreenPtr pScreen)
{
    xConnSetup* connSetup = void;
    char* vendor = void;
    xPixmapFormat* formats = void;
    xWindowRoot* root = void;
    xDepth* depth = void;
    xVisualType* visual = void;
    int screen = 0;
    int d = void;

    if (ConnectionInfo is null)
        return;

    connSetup = cast(xConnSetup*) ConnectionInfo;
    vendor = cast(char*) connSetup + xConnSetup.sizeof;
    formats = cast(xPixmapFormat*) (cast(char*) vendor +
                                 padForInt32(connSetup.nbytesVendor));
    root = cast(xWindowRoot*) (cast(char*) formats +
                            ((xPixmapFormat).sizeof *
                            screenInfo.numPixmapFormats));
    while (screen != pScreen.myNum) {
        depth = cast(xDepth*) (cast(char*) root + xWindowRoot.sizeof);
        for (d = 0; d < root.nDepths; d++) {
            visual = cast(xVisualType*) (cast(char*) depth + xDepth.sizeof);
            depth = cast(xDepth*) (cast(char*) visual +
                                depth.nVisuals * xVisualType.sizeof);
        }
        root = cast(xWindowRoot*) (cast(char*) depth);
        screen++;
    }
    root.pixWidth = pScreen.width;
    root.pixHeight = pScreen.height;
    root.mmWidth = pScreen.mmWidth;
    root.mmHeight = pScreen.mmHeight;
}

void RRSendConfigNotify(ScreenPtr pScreen)
{
    WindowPtr pWin = pScreen.root;
    // xEvent event = {
    //     u:configureNotify:window: cast(uint)pWin.drawable.id,
    //     u:configureNotify:aboveSibling: None,

    // /* XXX xinerama stuff ? */

    //     u:configureNotify:width: pWin.drawable.width,
    //     u:configureNotify:height: pWin.drawable.height,
    //     u:configureNotify:borderWidth: mixin(wBorderWidth!("pWin")),
    //     u:configureNotify:override: pWin.overrideRedirect
    // };
        xEvent event;
        event.u.configureNotify.window = cast(uint)pWin.drawable.id,
        event.u.configureNotify.aboveSibling = None,

    /* XXX xinerama stuff ? */

        event.u.configureNotify.width = pWin.drawable.width,
        event.u.configureNotify.height = pWin.drawable.height,
        event.u.configureNotify.borderWidth = mixin(wBorderWidth!("pWin")),
        event.u.configureNotify.override_ = cast(ubyte)pWin.overrideRedirect;
    // };

    event.u.u.type = ConfigureNotify;
    DeliverEvents(pWin, &event, 1, NullWindow);
}

void RRDeliverScreenEvent(ClientPtr client, WindowPtr pWin, ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    RRCrtcPtr crtc = pScrPriv.numCrtcs ? pScrPriv.crtcs[0] : null;
    WindowPtr pRoot = pScreen.root;

    xRRScreenChangeNotifyEvent se = {
        type: cast(ubyte)(RRScreenChangeNotify + RREventBase),
        rotation: cast(CARD8) (crtc ? crtc.rotation : RR_Rotate_0),
        timestamp: pScrPriv.lastSetTime.milliseconds,
        configTimestamp: pScrPriv.lastConfigTime.milliseconds,
        root: cast(uint)pRoot.drawable.id,
        window: cast(uint)pWin.drawable.id,
        subpixelOrder: cast(ushort)PictureGetSubpixelOrder(pScreen),

        sizeID: RR10CurrentSizeID(pScreen)
    };

    if (se.rotation & (RR_Rotate_90 | RR_Rotate_270)) {
        se.widthInPixels = pScreen.height;
        se.heightInPixels = pScreen.width;
        se.widthInMillimeters = pScreen.mmHeight;
        se.heightInMillimeters = pScreen.mmWidth;
    }
    else {
        se.widthInPixels = pScreen.width;
        se.heightInPixels = pScreen.height;
        se.widthInMillimeters = pScreen.mmWidth;
        se.heightInMillimeters = pScreen.mmHeight;
    }

    WriteEventsToClient(client, 1, cast(xEvent*) &se);
}

/*
 * Notify the extension that the screen size has been changed.
 * The driver is responsible for calling this whenever it has changed
 * the size of the screen
 */
void RRScreenSizeNotify(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    /*
     * Deliver ConfigureNotify events when root changes
     * pixel size
     */
    if (pScrPriv.width == pScreen.width &&
        pScrPriv.height == pScreen.height &&
        pScrPriv.mmWidth == pScreen.mmWidth &&
        pScrPriv.mmHeight == pScreen.mmHeight)
        return;

    pScrPriv.width = pScreen.width;
    pScrPriv.height = pScreen.height;
    pScrPriv.mmWidth = pScreen.mmWidth;
    pScrPriv.mmHeight = pScreen.mmHeight;
    RRSetChanged(pScreen);
/*    pScrPriv->sizeChanged = True; */

    RRTellChanged(pScreen);
    RRSendConfigNotify(pScreen);
    RREditConnectionInfo(pScreen);

    RRPointerScreenConfigured(pScreen);
    /*
     * Fix pointer bounds and location
     */
    ScreenRestructured(pScreen);
}

/*
 * Request that the screen be resized
 */
Bool RRScreenSizeSet(ScreenPtr pScreen, CARD16 width, CARD16 height, CARD32 mmWidth, CARD32 mmHeight)
{
    mixin(rrScrPriv!("pScreen"));

static if (RANDR_12_INTERFACE) {
    if (pScrPriv.rrScreenSetSize) {
        return (*pScrPriv.rrScreenSetSize) (pScreen,
                                             width, height, mmWidth, mmHeight);
    }
}
    if (pScrPriv.rrSetConfig) {
        return True;            /* can't set size separately */
    }
    return False;
}

/*
 * Retrieve valid screen size range
 */
int ProcRRGetScreenSizeRange(ClientPtr client)
{
    mixin(REQUEST!xRRGetScreenSizeRangeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetScreenSizeRangeReq);
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

    xRRGetScreenSizeRangeReply reply = { 0 };

    if (pScrPriv) {
        if (!RRGetInfo(pScreen, False))
            return BadAlloc;
        reply.minWidth = pScrPriv.minWidth;
        reply.minHeight = pScrPriv.minHeight;
        reply.maxWidth = pScrPriv.maxWidth;
        reply.maxHeight = pScrPriv.maxHeight;
    }
    else {
        reply.maxWidth = reply.minWidth = pScreen.width;
        reply.maxHeight = reply.minHeight = pScreen.height;
    }
    if (client.swapped) {
        swaps(&reply.minWidth);
        swaps(&reply.minHeight);
        swaps(&reply.maxWidth);
        swaps(&reply.maxHeight);
    }
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcRRSetScreenSize(ClientPtr client)
{
    mixin(REQUEST!xRRSetScreenSizeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetScreenSizeReq);
    if (client.swapped) {
        swapl(&stuff.window);
        swaps(&stuff.width);
        swaps(&stuff.height);
        swapl(&stuff.widthInMillimeters);
        swapl(&stuff.heightInMillimeters);
    }

    WindowPtr pWin = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    int i = void, rc = void;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    pScreen = pWin.drawable.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    if (!pScrPriv)
        return BadMatch;

    if (stuff.width < pScrPriv.minWidth || pScrPriv.maxWidth < stuff.width) {
        client.errorValue = cast(uint)stuff.width;
        return BadValue;
    }
    if (stuff.height < pScrPriv.minHeight ||
        pScrPriv.maxHeight < stuff.height) {
        client.errorValue = cast(uint)stuff.height;
        return BadValue;
    }
    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];
        RRModePtr mode = crtc.mode;

        if (!RRCrtcIsLeased(crtc) && mode) {
            pixman_box16 display_box = {
                0, 0,
                mode.mode.width,
                mode.mode.height
            };
            assumeNoGC(&pixman_f_transform_bounds)(&crtc.f_transform, &display_box);

            if (display_box.x2 > stuff.width || display_box.y2 > stuff.height)
                return BadMatch;
        }
    }
    if (stuff.widthInMillimeters == 0 || stuff.heightInMillimeters == 0) {
        client.errorValue = cast(uint)0;
        return BadValue;
    }
    if (!RRScreenSizeSet(pScreen,
                         stuff.width, stuff.height,
                         stuff.widthInMillimeters,
                         stuff.heightInMillimeters)) {
        return BadMatch;
    }
    return Success;
}


enum string update_totals(string gpuscreen, string pScrPriv) = `{       
    total_crtcs += ` ~ pScrPriv ~ `.numCrtcs;                
    total_outputs += ` ~ pScrPriv ~ `.numOutputs;            
    modes = RRModesForScreen(` ~ gpuscreen ~ `, &num_modes);  
    if (!modes)                                       
        return BadAlloc;                              
    for (j = 0; j < num_modes; j++)                   
        total_name_len += modes[j].mode.nameLength;  
    total_modes += num_modes;                         
    free(modes);                                      
}`;

pragma(inline, true) private void swap_modeinfos(xRRModeInfo* modeinfos, int i)
{
    swapl(&modeinfos[i].id);
    swaps(&modeinfos[i].width);
    swaps(&modeinfos[i].height);
    swapl(&modeinfos[i].dotClock);
    swaps(&modeinfos[i].hSyncStart);
    swaps(&modeinfos[i].hSyncEnd);
    swaps(&modeinfos[i].hTotal);
    swaps(&modeinfos[i].hSkew);
    swaps(&modeinfos[i].vSyncStart);
    swaps(&modeinfos[i].vSyncEnd);
    swaps(&modeinfos[i].vTotal);
    swaps(&modeinfos[i].nameLength);
    swapl(&modeinfos[i].modeFlags);
}

enum string update_arrays(string gpuscreen, string pScrPriv, string primary_crtc, string has_primary) = `{            
    for (j = 0; j < ` ~ pScrPriv ~ `.numCrtcs; j++) {             
        if (` ~ has_primary ~ ` && 
            ` ~ primary_crtc ~ ` == ` ~ pScrPriv ~ `.crtcs[j]) { 
            ` ~ has_primary ~ ` = 0;   
            continue; 
        }
        crtcs[crtc_count] = ` ~ pScrPriv ~ `.crtcs[j].id;        
        if (client.swapped)                               
            swapl(&crtcs[crtc_count]);                     
        crtc_count++;                                      
    }                                                      
    for (j = 0; j < ` ~ pScrPriv ~ `.numOutputs; j++) {           
        outputs[output_count] = ` ~ pScrPriv ~ `.outputs[j].id;  
        if (client.swapped)                               
            swapl(&outputs[output_count]);                 
        output_count++;                                    
    }                                                      
    {                                                      
        RRModePtr mode = void;                                    
        modes = RRModesForScreen(` ~ gpuscreen ~ `, &num_modes);   
        for (j = 0; j < num_modes; j++) {                  
            mode = modes[j];                               
            modeinfos[mode_count] = mode.mode;            
            if (client.swapped) {                         
                swap_modeinfos(modeinfos, mode_count);     
            }                                              
            memcpy(names, mode.name, mode.mode.nameLength); 
            names += mode.mode.nameLength;                
            mode_count++;                                  
        }                                                  
        free(modes);                                       
    }                                                      
    }`;

private int rrGetMultiScreenResources(ClientPtr client, Bool query, ScreenPtr pScreen)
{
    int j = void;
    int total_crtcs = void, total_outputs = void, total_modes = void, total_name_len = void;
    int crtc_count = void, output_count = void, mode_count = void;
    rrScrPrivPtr pScrPriv = void;
    int num_modes = void;
    RRModePtr* modes = void;
    c_ulong extraLen = void;
    CARD8* extra = void;
    RRCrtc* crtcs = void;
    RRCrtcPtr primary_crtc = null;
    RROutput* outputs = void;
    xRRModeInfo* modeinfos = void;
    CARD8* names = void;
    int has_primary = 0;

    /* we need to iterate all the GPU primarys and all their output secondarys */
    total_crtcs = 0;
    total_outputs = 0;
    total_modes = 0;
    total_name_len = 0;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (query && pScrPriv)
        if (!RRGetInfo(pScreen, query))
            return BadAlloc;

    mixin(update_totals!(`pScreen`, `pScrPriv`));

    foreach(iter; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
        if (!iter.is_output_secondary)
            continue;

        pScrPriv = mixin(rrGetScrPriv!("iter"));

        if (query)
          if (!RRGetInfo(iter, query))
            return BadAlloc;
        mixin(update_totals!(`iter`, `pScrPriv`));
    }

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    xRRGetScreenResourcesReply reply = {
        timestamp: pScrPriv.lastSetTime.milliseconds,
        configTimestamp: pScrPriv.lastConfigTime.milliseconds,
        nCrtcs: cast(ushort)total_crtcs,
        nOutputs: cast(ushort)total_outputs,
        nModes: cast(ushort)total_modes,
        nbytesNames: cast(ushort)total_name_len
    };

    reply.length = (total_crtcs + total_outputs +
                  total_modes * int32ForBytes((xRRModeInfo).sizeof) +
                  int32ForBytes(total_name_len));

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: True };

    extraLen = reply.length << 2;
    if (extraLen) {
        extra = cast(ubyte*)x_rpcbuf_reserve(&rpcbuf, extraLen);
        if (!extra) {
            return BadAlloc;
        }
    }
    else
        extra = null;

    crtcs = cast(RRCrtc*)extra;
    outputs = cast(RROutput*)(crtcs + total_crtcs);
    modeinfos = cast(xRRModeInfo*)(outputs + total_outputs);
    names = cast(CARD8*)(modeinfos + total_modes);

    crtc_count = 0;
    output_count = 0;
    mode_count = 0;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    if (pScrPriv.primaryOutput && pScrPriv.primaryOutput.crtc) {
        has_primary = 1;
        primary_crtc = pScrPriv.primaryOutput.crtc;
        crtcs[0] = pScrPriv.primaryOutput.crtc.id;
        if (client.swapped)
            swapl(&crtcs[0]);
        crtc_count = 1;
    }
    mixin(update_arrays!(`pScreen`, `pScrPriv`, `primary_crtc`, `has_primary`));

    foreach(iter; pScreen.secondary_list.byEntries!(ScreenPtr, "secondary_head")) {
        if (!iter.is_output_secondary)
            continue;

        pScrPriv = mixin(rrGetScrPriv!("iter"));

        mixin(update_arrays!(`iter`, `pScrPriv`, `primary_crtc`, `has_primary`));
    }

    assert(int32ForBytes(cast(char*) names - cast(char*) extra) == reply.length);

    if (client.swapped) {
        swapl(&reply.timestamp);
        swapl(&reply.configTimestamp);
        swaps(&reply.nCrtcs);
        swaps(&reply.nOutputs);
        swaps(&reply.nModes);
        swaps(&reply.nbytesNames);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int rrGetScreenResources(ClientPtr client, Bool query)
{
    mixin(REQUEST!xRRGetScreenResourcesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetScreenResourcesReq);

    if (client.swapped)
        swapl(&stuff.window);

    xRRGetScreenResourcesReply reply = void;
    WindowPtr pWin = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    CARD8* extra = null;
    c_ulong extraLen = 0;
    int i = void, rc = void, has_primary = 0;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    pScreen = pWin.drawable.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (query && pScrPriv)
        if (!RRGetInfo(pScreen, query))
            return BadAlloc;

    if (pScreen.output_secondarys)
        return rrGetMultiScreenResources(client, query, pScreen);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: True };

    if (!pScrPriv) {
        reply = xRRGetScreenResourcesReply (
            timestamp: currentTime.milliseconds,
            configTimestamp: currentTime.milliseconds,
        );
    }
    else {
        RRModePtr* modes = void;
        int num_modes = void;

        modes = RRModesForScreen(pScreen, &num_modes);
        if (!modes)
            return BadAlloc;

        reply = xRRGetScreenResourcesReply (
            timestamp: pScrPriv.lastSetTime.milliseconds,
            configTimestamp: pScrPriv.lastConfigTime.milliseconds,
            nCrtcs: cast(ushort)pScrPriv.numCrtcs,
            nOutputs: cast(ushort)pScrPriv.numOutputs,
            nModes: cast(ushort)num_modes,
        );

        for (i = 0; i < num_modes; i++)
            reply.nbytesNames += modes[i].mode.nameLength;

        reply.length = pScrPriv.numCrtcs +
                      pScrPriv.numOutputs +
                      num_modes * int32ForBytes((xRRModeInfo).sizeof) +
                      int32ForBytes(reply.nbytesNames);

        RRCrtc* crtcs;
        RROutput* outputs;
        xRRModeInfo* modeinfos;
        CARD8* names;


        extraLen = reply.length << 2;
        if (!extraLen)
            goto finish;

        extra = cast(ubyte*)x_rpcbuf_reserve(&rpcbuf, extraLen);
        if (!extra) {
            free(modes);
            return BadAlloc;
        }

        crtcs = cast(RRCrtc*) extra;
        outputs = cast(RROutput*) (crtcs + pScrPriv.numCrtcs);
        modeinfos = cast(xRRModeInfo*) (outputs + pScrPriv.numOutputs);
        names = cast(CARD8*) (modeinfos + num_modes);

        if (pScrPriv.primaryOutput && pScrPriv.primaryOutput.crtc) {
            has_primary = 1;
            crtcs[0] = pScrPriv.primaryOutput.crtc.id;
            if (client.swapped)
                swapl(&crtcs[0]);
        }

        for (i = 0; i < pScrPriv.numCrtcs; i++) {
            if (has_primary &&
                pScrPriv.primaryOutput.crtc == pScrPriv.crtcs[i]) {
                has_primary = 0;
                continue;
            }
            crtcs[i + has_primary] = pScrPriv.crtcs[i].id;
            if (client.swapped)
                swapl(&crtcs[i + has_primary]);
        }

        for (i = 0; i < pScrPriv.numOutputs; i++) {
            outputs[i] = pScrPriv.outputs[i].id;
            if (client.swapped)
                swapl(&outputs[i]);
        }

        for (i = 0; i < num_modes; i++) {
            RRModePtr mode = modes[i];

            modeinfos[i] = mode.mode;
            if (client.swapped) {
                swapl(&modeinfos[i].id);
                swaps(&modeinfos[i].width);
                swaps(&modeinfos[i].height);
                swapl(&modeinfos[i].dotClock);
                swaps(&modeinfos[i].hSyncStart);
                swaps(&modeinfos[i].hSyncEnd);
                swaps(&modeinfos[i].hTotal);
                swaps(&modeinfos[i].hSkew);
                swaps(&modeinfos[i].vSyncStart);
                swaps(&modeinfos[i].vSyncEnd);
                swaps(&modeinfos[i].vTotal);
                swaps(&modeinfos[i].nameLength);
                swapl(&modeinfos[i].modeFlags);
            }
            memcpy(names, mode.name, mode.mode.nameLength);
            names += mode.mode.nameLength;
        }
        assert(int32ForBytes(cast(char*) names - cast(char*) extra) == reply.length);
finish:
        free(modes);
    }

    if (client.swapped) {
        swapl(&reply.timestamp);
        swapl(&reply.configTimestamp);
        swaps(&reply.nCrtcs);
        swaps(&reply.nOutputs);
        swaps(&reply.nModes);
        swaps(&reply.nbytesNames);
    }
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRGetScreenResources(ClientPtr client)
{
    return rrGetScreenResources(client, True);
}

int ProcRRGetScreenResourcesCurrent(ClientPtr client)
{
    return rrGetScreenResources(client, False);
}

struct _RR10Data {
    RRScreenSizePtr sizes;
    int nsize;
    int nrefresh;
    int size;
    CARD16 refresh;
}alias RR10DataRec = _RR10Data;
alias RR10DataPtr = _RR10Data*;

/*
 * Convert 1.2 monitor data into 1.0 screen data
 */
private RR10DataPtr RR10GetData(ScreenPtr pScreen, RROutputPtr output)
{
    RRScreenSizePtr size = void;
    int nmode = output.numModes + output.numUserModes;
    int o = void, os = void, l = void, r = void;
    RRScreenRatePtr refresh = void;
    CARD16 vRefresh = void;
    RRModePtr mode = void;
    Bool* used = void;

    /* Make sure there is plenty of space for any combination */
    RR10DataPtr data = cast(RR10DataPtr) calloc(1, ((RR10DataRec).sizeof +
                  ((RRScreenSize).sizeof * nmode +
                  ((RRScreenRate).sizeof * nmode + ((Bool).sizeof * nmode)))));
    if (!data)
        return null;
    size = cast(RRScreenSizePtr) (data + 1);
    refresh = cast(RRScreenRatePtr) (size + nmode);
    used = cast(Bool*) (refresh + nmode);
    memset(used, '\0', ((Bool).sizeof * nmode));
    data.sizes = size;
    data.nsize = 0;
    data.nrefresh = 0;
    data.size = 0;
    data.refresh = 0;

    /*
     * find modes not yet listed
     */
    for (o = 0; o < output.numModes + output.numUserModes; o++) {
        if (used[o])
            continue;

        if (o < output.numModes)
            mode = output.modes[o];
        else
            mode = output.userModes[o - output.numModes];

        l = data.nsize;
        size[l].id = data.nsize;
        size[l].width = cast(short)mode.mode.width;
        size[l].height = cast(short)mode.mode.height;
        if (output.mmWidth && output.mmHeight) {
            size[l].mmWidth = cast(short)output.mmWidth;
            size[l].mmHeight = cast(short)output.mmHeight;
        }
        else {
            size[l].mmWidth = pScreen.mmWidth;
            size[l].mmHeight = pScreen.mmHeight;
        }
        size[l].nRates = 0;
        size[l].pRates = &refresh[data.nrefresh];
        data.nsize++;

        /*
         * Find all modes with matching size
         */
        for (os = o; os < output.numModes + output.numUserModes; os++) {
            if (os < output.numModes)
                mode = output.modes[os];
            else
                mode = output.userModes[os - output.numModes];
            if (mode.mode.width == size[l].width &&
                mode.mode.height == size[l].height) {
                vRefresh = RRVerticalRefresh(&mode.mode);
                used[os] = True;

                for (r = 0; r < size[l].nRates; r++)
                    if (vRefresh == size[l].pRates[r].rate)
                        break;
                if (r == size[l].nRates) {
                    size[l].pRates[r].rate = vRefresh;
                    size[l].pRates[r].mode = mode;
                    size[l].nRates++;
                    data.nrefresh++;
                }
                if (mode == output.crtc.mode) {
                    data.size = l;
                    data.refresh = vRefresh;
                }
            }
        }
    }
    return data;
}

int ProcRRGetScreenInfo(ClientPtr client)
{
    mixin(REQUEST!xRRGetScreenInfoReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetScreenInfoReq);
    if (client.swapped)
        swapl(&stuff.window);

    xRRGetScreenInfoReply reply = void;
    WindowPtr pWin = void;
    int rc = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    CARD8* extra = null;
    c_ulong extraLen = 0;
    RROutputPtr output = void;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    pScreen = pWin.drawable.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (pScrPriv)
        if (!RRGetInfo(pScreen, True))
            return BadAlloc;

    output = RRFirstOutput(pScreen);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: True };

    if (!pScrPriv || !output) {
        reply = xRRGetScreenInfoReply (
            setOfRotations: RR_Rotate_0,
            root: cast(uint)pWin.drawable.pScreen.root.drawable.id,
            timestamp: currentTime.milliseconds,
            configTimestamp: currentTime.milliseconds,
            rotation: RR_Rotate_0,
        );
    }
    else {
        int i = void, j = void;
        CARD8* data8 = void;
        Bool has_rate = RRClientKnowsRates(client);
        RR10DataPtr pData = void;
        RRScreenSizePtr pSize = void;

        pData = RR10GetData(pScreen, output);
        if (!pData)
            return BadAlloc;

        reply = xRRGetScreenInfoReply (
            setOfRotations: cast(ubyte)output.crtc.rotations,
            root: cast(uint)pWin.drawable.pScreen.root.drawable.id,
            timestamp: pScrPriv.lastSetTime.milliseconds,
            configTimestamp: pScrPriv.lastConfigTime.milliseconds,
            rotation: output.crtc.rotation,
            nSizes: cast(ushort)pData.nsize,
            nrateEnts: cast(ushort)(pData.nrefresh + pData.nsize),
            sizeID: cast(ushort)pData.size,
            rate: pData.refresh
        );

        CARD16* rates;
        xScreenSizes* size;

        extraLen = reply.nSizes * xScreenSizes.sizeof;
        if (has_rate)
            extraLen += reply.nrateEnts * CARD16.sizeof;

        if (!extraLen)
            goto finish; // no extra payload

        extra = cast(ubyte*)x_rpcbuf_reserve(&rpcbuf, extraLen);
        if (!extra) {
            free(pData);
            return BadAlloc;
        }

        /*
         * First comes the size information
         */
        size = cast(xScreenSizes*) extra;
        rates = cast(CARD16*) (size + reply.nSizes);
        for (i = 0; i < pData.nsize; i++) {
            pSize = &pData.sizes[i];
            size.widthInPixels = pSize.width;
            size.heightInPixels = pSize.height;
            size.widthInMillimeters = pSize.mmWidth;
            size.heightInMillimeters = pSize.mmHeight;
            if (client.swapped) {
                swaps(&size.widthInPixels);
                swaps(&size.heightInPixels);
                swaps(&size.widthInMillimeters);
                swaps(&size.heightInMillimeters);
            }
            size++;
            if (has_rate) {
                *rates = cast(ushort)pSize.nRates;
                if (client.swapped) {
                    swaps(rates);
                }
                rates++;
                for (j = 0; j < pSize.nRates; j++) {
                    *rates = pSize.pRates[j].rate;
                    if (client.swapped) {
                        swaps(rates);
                    }
                    rates++;
                }
            }
        }

        data8 = cast(CARD8*) rates;

        if (data8 - cast(CARD8*) extra != extraLen)
            FatalError("RRGetScreenInfo bad extra len %ld != %ld\n",
                       cast(c_ulong) (data8 - cast(CARD8*) extra), extraLen);

finish:
        free(pData);
    }
    if (client.swapped) {
        swapl(&reply.timestamp);
        swapl(&reply.configTimestamp);
        swaps(&reply.rotation);
        swaps(&reply.nSizes);
        swaps(&reply.sizeID);
        swaps(&reply.rate);
        swaps(&reply.nrateEnts);
    }
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRSetScreenConfig(ClientPtr client)
{
    mixin(REQUEST!xRRSetScreenConfigReq);

    int rate = 0;
    if (RRClientKnowsRates(client)) {
        mixin(REQUEST_AT_LEAST_SIZE!xRRSetScreenConfigReq);
        if (client.swapped) swaps(&stuff.rate);
        rate = stuff.rate;
    }
    else {
        mixin(REQUEST_AT_LEAST_SIZE!xRR1_0SetScreenConfigReq);
    }

    if (client.swapped) {
        swapl(&stuff.drawable);
        swapl(&stuff.timestamp);
        swaps(&stuff.sizeID);
        swaps(&stuff.rotation);
        swapl(&stuff.configTimestamp);
    }

    DrawablePtr pDraw = void;
    int rc = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    TimeStamp time = void;
    int i = void;
    Rotation rotation = void;
    CARD8 status = void;
    RROutputPtr output = void;
    RRCrtcPtr crtc = void;
    RRModePtr mode = void;
    RR10DataPtr pData = null;
    RRScreenSizePtr pSize = void;
    int width = void, height = void;

    UpdateCurrentTime();

    rc = dixLookupDrawable(&pDraw, stuff.drawable, client, 0, DixWriteAccess);
    if (rc != Success)
        return rc;

    pScreen = pDraw.pScreen;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    time = ClientTimeToServerTime(stuff.timestamp);

    if (!pScrPriv) {
        time = currentTime;
        status = RRSetConfigFailed;
        goto sendReply;
    }
    if (!RRGetInfo(pScreen, False))
        return BadAlloc;

    output = RRFirstOutput(pScreen);
    if (!output) {
        time = currentTime;
        status = RRSetConfigFailed;
        goto sendReply;
    }

    crtc = output.crtc;

    /*
     * If the client's config timestamp is not the same as the last config
     * timestamp, then the config information isn't up-to-date and
     * can't even be validated.
     *
     * Note that the client only knows about the milliseconds part of the
     * timestamp, so using CompareTimeStamps here would cause randr to suddenly
     * stop working after several hours have passed (freedesktop bug #6502).
     */
    if (stuff.configTimestamp != pScrPriv.lastConfigTime.milliseconds) {
        status = RRSetConfigInvalidConfigTime;
        goto sendReply;
    }

    pData = RR10GetData(pScreen, output);
    if (!pData)
        return BadAlloc;

    if (stuff.sizeID >= pData.nsize) {
        /*
         * Invalid size ID
         */
        client.errorValue = cast(uint)stuff.sizeID;
        free(pData);
        return BadValue;
    }
    pSize = &pData.sizes[stuff.sizeID];

    /*
     * Validate requested rotation
     */
    rotation = cast(Rotation) stuff.rotation;

    /* test the rotation bits only! */
    switch (rotation & 0xf) {
    case RR_Rotate_0:
    case RR_Rotate_90:
    case RR_Rotate_180:
    case RR_Rotate_270:
        break;
    default:
        /*
         * Invalid rotation
         */
        client.errorValue = cast(uint)stuff.rotation;
        free(pData);
        return BadValue;
    }

    if ((~crtc.rotations) & rotation) {
        /*
         * requested rotation or reflection not supported by screen
         */
        client.errorValue = cast(uint)stuff.rotation;
        free(pData);
        return BadMatch;
    }

    if (rate) {
        for (i = 0; i < pSize.nRates; i++) {
            if (pSize.pRates[i].rate == rate)
                break;
        }
        if (i == pSize.nRates) {
            /*
             * Invalid rate
             */
            client.errorValue = cast(uint)rate;
            free(pData);
            return BadValue;
        }
        mode = pSize.pRates[i].mode;
    }
    else
        mode = pSize.pRates[0].mode;

    /*
     * Make sure the requested set-time is not older than
     * the last set-time
     */
    if (CompareTimeStamps(time, pScrPriv.lastSetTime) < 0) {
        status = RRSetConfigInvalidTime;
        goto sendReply;
    }

    /*
     * If the screen size is changing, adjust all of the other outputs
     * to fit the new size, mirroring as much as possible
     */
    width = mode.mode.width;
    height = mode.mode.height;
    if (width < pScrPriv.minWidth || pScrPriv.maxWidth < width) {
        client.errorValue = cast(uint)width;
        free(pData);
        return BadValue;
    }
    if (height < pScrPriv.minHeight || pScrPriv.maxHeight < height) {
        client.errorValue = cast(uint)height;
        free(pData);
        return BadValue;
    }

    if (rotation & (RR_Rotate_90 | RR_Rotate_270)) {
        width = mode.mode.height;
        height = mode.mode.width;
    }

    if (width != pScreen.width || height != pScreen.height) {
        int c = void;

        for (c = 0; c < pScrPriv.numCrtcs; c++) {
            if (!RRCrtcSet(pScrPriv.crtcs[c], null, 0, 0, RR_Rotate_0,
                           0, null)) {
                status = RRSetConfigFailed;
                /* XXX recover from failure */
                goto sendReply;
            }
        }
        if (!RRScreenSizeSet(pScreen, cast(ushort)width, cast(ushort)height,
                             cast(ushort)pScreen.mmWidth, cast(ushort)pScreen.mmHeight)) {
            status = RRSetConfigFailed;
            /* XXX recover from failure */
            goto sendReply;
        }
    }

    if (!RRCrtcSet(crtc, mode, 0, 0, stuff.rotation, 1, &output))
        status = RRSetConfigFailed;
    else {
        pScrPriv.lastSetTime = time;
        status = RRSetConfigSuccess;
    }

    /*
     * XXX Configure other crtcs to mirror as much as possible
     */

 sendReply:

    free(pData);

    xRRSetScreenConfigReply reply = {
        status: status,
        newTimestamp: pScrPriv.lastSetTime.milliseconds,
        newConfigTimestamp: pScrPriv.lastConfigTime.milliseconds,
        root: cast(uint)pDraw.pScreen.root.drawable.id,
        /* .subpixelOrder = ?? */
    };

    if (client.swapped) {
        swapl(&reply.newTimestamp);
        swapl(&reply.newConfigTimestamp);
        swapl(&reply.root);
    }
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private CARD16 RR10CurrentSizeID(ScreenPtr pScreen)
{
    CARD16 sizeID = 0xffff;
    RROutputPtr output = RRFirstOutput(pScreen);

    if (output) {
        RR10DataPtr data = RR10GetData(pScreen, output);

        if (data) {
            int i = void;

            for (i = 0; i < data.nsize; i++)
                if (data.sizes[i].width == pScreen.width &&
                    data.sizes[i].height == pScreen.height) {
                    sizeID = cast(CARD16) i;
                    break;
                }
            free(data);
        }
    }
    return sizeID;
}
