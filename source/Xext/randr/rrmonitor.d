module randr.rrmonitor;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2014 Keith Packard
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
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import randr.rrcrtc;
import dix.resource;
import randr.rroutput;
import randr.rrmode;
import randr.randr;
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
import dix.atom;
import dix.swaprep;

private Atom RRMonitorCrtcName(RRCrtcPtr crtc)
{
    char[20] name = void;

    if (crtc.numOutputs) {
        RROutputPtr output = crtc.outputs[0];
        return MakeAtom(output.name, cast(uint)output.nameLength, TRUE);
    }
    sprintf(name.ptr, "Monitor-%08lx", cast(c_ulong)crtc.id);
    return dixAddAtom(name.ptr);
}

private Bool RRMonitorCrtcPrimary(RRCrtcPtr crtc)
{
    ScreenPtr screen = crtc.pScreen;
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    int o = void;

    for (o = 0; o < crtc.numOutputs; o++)
        if (crtc.outputs[o] == pScrPriv.primaryOutput)
            return TRUE;
    return FALSE;
}

enum DEFAULT_PIXELS_PER_MM =   (96.0 / 25.4);

private void RRMonitorGetCrtcGeometry(RRCrtcPtr crtc, RRMonitorGeometryPtr geometry)
{
    ScreenPtr screen = crtc.pScreen;
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    BoxRec panned_area = void;

    /* Check to see if crtc is panned and return the full area when applicable. */
    if (pScrPriv && pScrPriv.rrGetPanning &&
        pScrPriv.rrGetPanning(screen, crtc, &panned_area, null, null) &&
        (panned_area.x2 > panned_area.x1) &&
        (panned_area.y2 > panned_area.y1)) {
        geometry.box = panned_area;
    }
    else {
        int width = void, height = void;

        RRCrtcGetScanoutSize(crtc, &width, &height);
        geometry.box.x1 = cast(short)crtc.x;
        geometry.box.y1 = cast(short)crtc.y;
        geometry.box.x2 = cast(short)(geometry.box.x1 + width);
        geometry.box.y2 = cast(short)(geometry.box.y1 + height);
    }
    if (crtc.numOutputs && crtc.outputs[0].mmWidth && crtc.outputs[0].mmHeight) {
        RROutputPtr output = crtc.outputs[0];
        geometry.mmWidth = output.mmWidth;
        geometry.mmHeight = output.mmHeight;
    } else {
        geometry.mmWidth = cast(uint)(floor ((geometry.box.x2 - geometry.box.x1) / DEFAULT_PIXELS_PER_MM + 0.5));
        geometry.mmHeight = cast(uint)(floor ((geometry.box.y2 - geometry.box.y1) / DEFAULT_PIXELS_PER_MM + 0.5));
    }
}

private Bool RRMonitorSetFromServer(RRCrtcPtr crtc, RRMonitorPtr monitor)
{
    int o = void;

    monitor.name = RRMonitorCrtcName(crtc);
    monitor.pScreen = crtc.pScreen;
    monitor.numOutputs = crtc.numOutputs;
    monitor.outputs = cast(uint*)calloc(crtc.numOutputs, RROutput.sizeof);
    if (!monitor.outputs)
        return FALSE;
    for (o = 0; o < crtc.numOutputs; o++)
        monitor.outputs[o] = crtc.outputs[o].id;
    monitor.primary = RRMonitorCrtcPrimary(crtc);
    monitor.automatic = TRUE;
    RRMonitorGetCrtcGeometry(crtc, &monitor.geometry);
    return TRUE;
}

private Bool RRMonitorAutomaticGeometry(RRMonitorPtr monitor)
{
    return (monitor.geometry.box.x1 == 0 &&
            monitor.geometry.box.y1 == 0 &&
            monitor.geometry.box.x2 == 0 &&
            monitor.geometry.box.y2 == 0);
}

private void RRMonitorGetGeometry(RRMonitorPtr monitor, RRMonitorGeometryPtr geometry)
{
    if (RRMonitorAutomaticGeometry(monitor) && monitor.numOutputs > 0) {
        ScreenPtr screen = monitor.pScreen;
        rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
        RRMonitorGeometryRec first = { box: { 0, 0, 0, 0 }, mmWidth: 0, mmHeight: 0 };
        RRMonitorGeometryRec this_ = void;
        int c = void, o = void, co = void;
        int active_crtcs = 0;

        *geometry = first;
        for (o = 0; o < monitor.numOutputs; o++) {
            RRCrtcPtr crtc = null;
            Bool in_use = FALSE;

            for (c = 0; !in_use && c < pScrPriv.numCrtcs; c++) {
                crtc = pScrPriv.crtcs[c];
                if (!crtc.mode)
                    continue;
                for (co = 0; !in_use && co < crtc.numOutputs; co++)
                    if (monitor.outputs[o] == crtc.outputs[co].id)
                        in_use = TRUE;
            }

            if (!in_use)
                continue;

            RRMonitorGetCrtcGeometry(crtc, &this_);

            if (active_crtcs == 0) {
                first = this_;
                *geometry = this_;
            } else {
                geometry.box.x1 = min(this_.box.x1, geometry.box.x1);
                geometry.box.x2 = max(this_.box.x2, geometry.box.x2);
                geometry.box.y1 = min(this_.box.y1, geometry.box.y1);
                geometry.box.y2 = max(this_.box.y2, geometry.box.y2);
            }
            active_crtcs++;
        }

        /* Adjust physical sizes to account for total area */
        if (active_crtcs > 1 && first.box.x2 != first.box.x1 && first.box.y2 != first.box.y1) {
            geometry.mmWidth = cast(uint)((cast(double)(geometry.box.x2 - geometry.box.x1) / (first.box.x2 - first.box.x1)) * first.mmWidth);
            geometry.mmHeight = cast(uint)((cast(double)(geometry.box.y2 - geometry.box.y1) / (first.box.y2 - first.box.y1)) * first.mmHeight);
        }
    } else {
        *geometry = monitor.geometry;
    }
}

private Bool RRMonitorSetFromClient(RRMonitorPtr client_monitor, RRMonitorPtr monitor)
{
    monitor.name = client_monitor.name;
    monitor.pScreen = client_monitor.pScreen;
    monitor.numOutputs = client_monitor.numOutputs;
    monitor.outputs = cast(uint*)calloc(client_monitor.numOutputs, RROutput.sizeof);
    if (!monitor.outputs && client_monitor.numOutputs)
        return FALSE;
    memcpy(monitor.outputs, client_monitor.outputs, client_monitor.numOutputs * RROutput.sizeof);
    monitor.primary = client_monitor.primary;
    monitor.automatic = client_monitor.automatic;
    RRMonitorGetGeometry(client_monitor, &monitor.geometry);
    return TRUE;
}

struct _rrMonitorList {
    int num_client;
    int num_server;
    RRCrtcPtr* server_crtc;
    int num_crtcs;
    int client_primary;
    int server_primary;
}alias RRMonitorListRec = _rrMonitorList;
alias RRMonitorListPtr = _rrMonitorList*;

private Bool RRMonitorInitList(ScreenPtr screen, RRMonitorListPtr mon_list, Bool get_active)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    int m = void, o = void, c = void, sc = void;
    int numCrtcs = void;
    ScreenPtr secondary = void;

    if (!RRGetInfo(screen, FALSE))
        return FALSE;

    /* Count the number of crtcs in this and any secondary screens */
    numCrtcs = pScrPriv.numCrtcs;
    mixin(xorg_list_for_each_entry!("secondary", "&screen.secondary_list", "secondary_head", q{
        rrScrPrivPtr pSecondaryPriv = void;

        if (!secondary.is_output_secondary)
            continue;

        pSecondaryPriv = mixin(rrGetScrPriv!("secondary"));
        numCrtcs += pSecondaryPriv.numCrtcs;
    }));
    mon_list.num_crtcs = numCrtcs;

    mon_list.server_crtc = cast(_rrCrtc**)calloc(numCrtcs * 2, RRCrtcPtr.sizeof);
    if (!mon_list.server_crtc)
        return FALSE;

    /* Collect pointers to all of the active crtcs */
    c = 0;
    for (sc = 0; sc < pScrPriv.numCrtcs; sc++, c++) {
        if (pScrPriv.crtcs[sc].mode !is null)
            mon_list.server_crtc[c] = pScrPriv.crtcs[sc];
    }

    mixin(xorg_list_for_each_entry!("secondary", "&screen.secondary_list", "secondary_head", q{
        rrScrPrivPtr pSecondaryPriv = void;

        if (!secondary.is_output_secondary)
            continue;

        pSecondaryPriv = mixin(rrGetScrPriv!("secondary"));
        for (sc = 0; sc < pSecondaryPriv.numCrtcs; sc++, c++) {
            if (pSecondaryPriv.crtcs[sc].mode !is null)
                mon_list.server_crtc[c] = pSecondaryPriv.crtcs[sc];
        }
    }));

    /* Walk the list of client-defined monitors, clearing the covered
     * CRTCs from the full list and finding whether one of the
     * monitors is primary
     */
    mon_list.num_client = pScrPriv.numMonitors;
    mon_list.client_primary = -1;

    for (m = 0; m < pScrPriv.numMonitors; m++) {
        RRMonitorPtr monitor = pScrPriv.monitors[m];
        if (get_active) {
            RRMonitorGeometryRec geom = void;

            RRMonitorGetGeometry(monitor, &geom);
            if (geom.box.x2 - geom.box.x1 == 0 ||
                geom.box.y2 - geom.box.y1 == 0) {
                mon_list.num_client--;
                continue;
            }
        }
        if (monitor.primary && mon_list.client_primary == -1)
            mon_list.client_primary = m;
        for (o = 0; o < monitor.numOutputs; o++) {
            for (c = 0; c < numCrtcs; c++) {
                RRCrtcPtr crtc = mon_list.server_crtc[c];
                if (crtc) {
                    int co = void;
                    for (co = 0; co < crtc.numOutputs; co++)
                        if (crtc.outputs[co].id == monitor.outputs[o]) {
                            mon_list.server_crtc[c] = null;
                            break;
                        }
                }
            }
        }
    }

    /* Now look at the active CRTCs, and count
     * those not covered by a client monitor, as well
     * as finding whether one of them is marked primary
     */
    mon_list.num_server = 0;
    mon_list.server_primary = -1;

    for (c = 0; c < mon_list.num_crtcs; c++) {
        RRCrtcPtr crtc = mon_list.server_crtc[c];

        if (!crtc)
            continue;

        mon_list.num_server++;

        if (RRMonitorCrtcPrimary(crtc) && mon_list.server_primary == -1)
            mon_list.server_primary = c;
    }
    return TRUE;
}

private void RRMonitorFiniList(RRMonitorListPtr list)
{
    free(list.server_crtc);
}

/* Construct a complete list of protocol-visible monitors, including
 * the manually generated ones as well as those generated
 * automatically from the remaining CRCTs
 */

Bool RRMonitorMakeList(ScreenPtr screen, Bool get_active, RRMonitorPtr* monitors_ret, int* nmon_ret)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    RRMonitorListRec list = void;
    int m = void, c = void;
    RRMonitorPtr mon = void, monitors = void;
    Bool has_primary = FALSE;

    if (!pScrPriv)
        return FALSE;

    if (!RRMonitorInitList(screen, &list, get_active))
        return FALSE;

    monitors = cast(_rrMonitor*)calloc(list.num_client + list.num_server, RRMonitorRec.sizeof);
    if (!monitors) {
        RRMonitorFiniList(&list);
        return FALSE;
    }

    mon = monitors;

    /* Fill in the primary monitor data first
     */
    if (list.client_primary >= 0) {
        RRMonitorSetFromClient(pScrPriv.monitors[list.client_primary], mon);
        mon++;
    } else if (list.server_primary >= 0) {
        RRMonitorSetFromServer(list.server_crtc[list.server_primary], mon);
        mon++;
    }

    /* Fill in the client-defined monitors next
     */
    for (m = 0; m < pScrPriv.numMonitors; m++) {
        if (m == list.client_primary)
            continue;
        if (get_active) {
            RRMonitorGeometryRec geom = void;

            RRMonitorGetGeometry(pScrPriv.monitors[m], &geom);
            if (geom.box.x2 - geom.box.x1 == 0 ||
                geom.box.y2 - geom.box.y1 == 0) {
                continue;
            }
        }
        RRMonitorSetFromClient(pScrPriv.monitors[m], mon);
        if (has_primary)
            mon.primary = FALSE;
        else if (mon.primary)
            has_primary = TRUE;
        mon++;
    }

    /* And finish with the list of crtc-inspired monitors
     */
    for (c = 0; c < list.num_crtcs; c++) {
        RRCrtcPtr crtc = list.server_crtc[c];
        if (c == list.server_primary && list.client_primary < 0)
            continue;

        if (!list.server_crtc[c])
            continue;

        RRMonitorSetFromServer(crtc, mon);
        if (has_primary)
            mon.primary = FALSE;
        else if (mon.primary)
            has_primary = TRUE;
        mon++;
    }

    RRMonitorFiniList(&list);
    *nmon_ret = list.num_client + list.num_server;
    *monitors_ret = monitors;
    return TRUE;
}

int RRMonitorCountList(ScreenPtr screen)
{
    RRMonitorListRec list = void;
    int nmon = void;

    if (!RRMonitorInitList(screen, &list, FALSE))
        return -1;
    nmon = list.num_client + list.num_server;
    RRMonitorFiniList(&list);
    return nmon;
}

void RRMonitorFree(RRMonitorPtr monitor)
{
    free(monitor);
}

RRMonitorPtr RRMonitorAlloc(int noutput)
{
    RRMonitorPtr monitor = void;

    monitor = cast(_rrMonitor*)calloc(1, (RRMonitorRec).sizeof + noutput * RROutput.sizeof);
    if (!monitor)
        return null;
    monitor.numOutputs = noutput;
    monitor.outputs = cast(RROutput*) (monitor + 1);
    return monitor;
}

private int RRMonitorDelete(ClientPtr client, ScreenPtr screen, Atom name)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    int m = void;

    if (!pScrPriv) {
        client.errorValue = cast(uint)name;
        return BadAtom;
    }

    for (m = 0; m < pScrPriv.numMonitors; m++) {
        RRMonitorPtr monitor = pScrPriv.monitors[m];
        if (monitor.name == name) {
            memmove(pScrPriv.monitors + m, pScrPriv.monitors + m + 1,
                    (pScrPriv.numMonitors - (m + 1)) * RRMonitorPtr.sizeof);
            --pScrPriv.numMonitors;
            RRMonitorFree(monitor);
            return Success;
        }
    }

    client.errorValue = cast(uint)name;
    return BadValue;
}

private Bool RRMonitorMatchesOutputName(ScreenPtr screen, Atom name)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    int o = void;
    const(char)* str = NameForAtom(name);
    int len = cast(int)strlen(str);

    for (o = 0; o < pScrPriv.numOutputs; o++) {
        RROutputPtr output = pScrPriv.outputs[o];

        if (output.nameLength == len && !memcmp(output.name, str, len))
            return TRUE;
    }
    return FALSE;
}

int RRMonitorAdd(ClientPtr client, ScreenPtr screen, RRMonitorPtr monitor)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    int m = void;
    ScreenPtr secondary = void;
    RRMonitorPtr* monitors = void;

    if (!pScrPriv)
        return BadAlloc;

    /* 	'name' must not match the name of any Output on the screen, or
     *	a Value error results.
     */

    if (RRMonitorMatchesOutputName(screen, monitor.name)) {
        client.errorValue = cast(uint)monitor.name;
        return BadValue;
    }

    mixin(xorg_list_for_each_entry!("secondary", "&screen.secondary_list", "secondary_head", q{
        if (!secondary.is_output_secondary)
            continue;

        if (RRMonitorMatchesOutputName(secondary, monitor.name)) {
            client.errorValue = cast(uint)monitor.name;
            return BadValue;
        }
    }));

    /* Allocate space for the new pointer. This is done before
     * removing matching monitors as it may fail, and the request
     * needs to not have any side-effects on failure
     */
    if (pScrPriv.numMonitors)
        monitors = cast(_rrMonitor**)reallocarray(pScrPriv.monitors,
                                pScrPriv.numMonitors + 1,
                                RRMonitorPtr.sizeof);
    else
        monitors = cast(RRMonitorPtr*) cast(RRMonitorPtr*) calloc(1, RRMonitorPtr.sizeof);

    if (!monitors)
        return BadAlloc;

    pScrPriv.monitors = monitors;

    for (m = 0; m < pScrPriv.numMonitors; m++) {
        RRMonitorPtr existing = pScrPriv.monitors[m];

	/* If 'name' matches an existing Monitor on the screen, the
         * existing one will be deleted as if RRDeleteMonitor were called.
         */
        if (existing.name == monitor.name) {
            cast(void) RRMonitorDelete(client, screen, existing.name);
            continue;
        }

        if (monitor.primary)
            existing.primary = FALSE;
    }

    /* Add the new one to the list
     */
    pScrPriv.monitors[pScrPriv.numMonitors++] = monitor;

    return Success;
}

void RRMonitorFreeList(RRMonitorPtr monitors, int nmon)
{
    int m = void;

    for (m = 0; m < nmon; m++)
        free(monitors[m].outputs);
    free(monitors);
}

void RRMonitorInit(ScreenPtr screen)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));

    if (!pScrPriv)
        return;

    pScrPriv.numMonitors = 0;
    pScrPriv.monitors = null;
}

void RRMonitorClose(ScreenPtr screen)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));
    int m = void;

    if (!pScrPriv)
        return;

    for (m = 0; m < pScrPriv.numMonitors; m++)
        RRMonitorFree(pScrPriv.monitors[m]);
    free(pScrPriv.monitors);
    pScrPriv.monitors = null;
    pScrPriv.numMonitors = 0;
}

private CARD32 RRMonitorTimestamp(ScreenPtr screen)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("screen"));

    /* XXX should take client monitor changes into account */
    return pScrPriv.lastConfigTime.milliseconds;
}

int ProcRRGetMonitors(ClientPtr client)
{
    mixin(REQUEST!xRRGetMonitorsReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetMonitorsReq);

    if (client.swapped)
        swapl(&stuff.window);

    WindowPtr window = void;
    ScreenPtr screen = void;
    int r = void;
    RRMonitorPtr monitors = void;
    int nmonitors = void;
    Bool get_active = void;

    r = dixLookupWindow(&window, stuff.window, client, DixGetAttrAccess);
    if (r != Success)
        return r;
    screen = window.drawable.pScreen;

    get_active = stuff.get_active;
    if (!RRMonitorMakeList(screen, get_active, &monitors, &nmonitors))
        return BadAlloc;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    size_t noutputs = 0;

    for (size_t m = 0; m < nmonitors; m++) {
        RRMonitorPtr monitor = &monitors[m];
        xRRMonitorInfo* info = cast(xRRMonitorInfo*)x_rpcbuf_reserve(&rpcbuf, xRRMonitorInfo.sizeof);

        noutputs += monitors[m].numOutputs;

        *info = xRRMonitorInfo (
            name: cast(uint)monitor.name,
            primary: cast(ubyte)monitor.primary,
            automatic: cast(ubyte)monitor.automatic,
            noutput: cast(ushort)monitor.numOutputs,
            x: monitor.geometry.box.x1,
            y: monitor.geometry.box.y1,
            width: cast(ushort)(monitor.geometry.box.x2 - monitor.geometry.box.x1),
            height: cast(ushort)(monitor.geometry.box.y2 - monitor.geometry.box.y1),
            widthInMillimeters: monitor.geometry.mmWidth,
            heightInMillimeters: monitor.geometry.mmHeight,
        );

        if (client.swapped) {
            swapl(&info.name);
            swaps(&info.noutput);
            swaps(&info.x);
            swaps(&info.y);
            swaps(&info.width);
            swaps(&info.height);
            swapl(&info.widthInMillimeters);
            swapl(&info.heightInMillimeters);
        }

        x_rpcbuf_write_CARD32s(&rpcbuf, monitor.outputs, monitor.numOutputs);
    }
    RRMonitorFreeList(monitors, nmonitors);

    xRRGetMonitorsReply reply = {
        timestamp: RRMonitorTimestamp(screen),
        nmonitors: nmonitors,
        noutputs: cast(uint)noutputs,
    };

    if (client.swapped) {
        swapl(&reply.timestamp);
        swapl(&reply.nmonitors);
        swapl(&reply.noutputs);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRSetMonitor(ClientPtr client)
{
    mixin(REQUEST!xRRSetMonitorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetMonitorReq);

    if (client.swapped) {
        swapl(&stuff.window);
        swapl(&stuff.monitor.name);
        swaps(&stuff.monitor.noutput);
        swaps(&stuff.monitor.x);
        swaps(&stuff.monitor.y);
        swaps(&stuff.monitor.width);
        swaps(&stuff.monitor.height);
        swapl(&stuff.monitor.widthInMillimeters);
        swapl(&stuff.monitor.heightInMillimeters);
        mixin(SwapRestL!("stuff"));
    }

    WindowPtr window = void;
    ScreenPtr screen = void;
    RRMonitorPtr monitor = void;
    int r = void;

    if (stuff.monitor.noutput != client.req_len - (xRRSetMonitorReq.sizeof >> 2))
        return BadLength;

    r = dixLookupWindow(&window, stuff.window, client, DixGetAttrAccess);
    if (r != Success)
        return r;
    screen = window.drawable.pScreen;

    if (!ValidAtom(stuff.monitor.name))
        return BadAtom;

    /* Allocate the new monitor */
    monitor = RRMonitorAlloc(stuff.monitor.noutput);
    if (!monitor)
        return BadAlloc;

    /* Fill in the bits from the request */
    monitor.pScreen = screen;
    monitor.name = stuff.monitor.name;
    monitor.primary = stuff.monitor.primary;
    monitor.automatic = FALSE;
    memcpy(monitor.outputs, stuff + 1, stuff.monitor.noutput * RROutput.sizeof);
    monitor.geometry.box.x1 = cast(short)(stuff.monitor.x);
    monitor.geometry.box.y1 = cast(short)(stuff.monitor.y);
    monitor.geometry.box.x2 = cast(short)(stuff.monitor.x + stuff.monitor.width);
    monitor.geometry.box.y2 = cast(short)(stuff.monitor.y + stuff.monitor.height);
    monitor.geometry.mmWidth = stuff.monitor.widthInMillimeters;
    monitor.geometry.mmHeight = stuff.monitor.heightInMillimeters;

    r = RRMonitorAdd(client, screen, monitor);
    if (r == Success)
        RRSendConfigNotify(screen);
    else
        RRMonitorFree(monitor);
    return r;
}

int ProcRRDeleteMonitor(ClientPtr client)
{
    mixin(REQUEST!xRRDeleteMonitorReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRDeleteMonitorReq);

    if (client.swapped) {
        swapl(&stuff.window);
        swapl(&stuff.name);
    }

    WindowPtr window = void;
    ScreenPtr screen = void;
    int r = void;

    r = dixLookupWindow(&window, stuff.window, client, DixGetAttrAccess);
    if (r != Success)
        return r;
    screen = window.drawable.pScreen;

    if (!ValidAtom(stuff.name)) {
        client.errorValue = cast(uint)stuff.name;
        return BadAtom;
    }

    r = RRMonitorDelete(client, screen, stuff.name);
    if (r == Success)
        RRSendConfigNotify(screen);
    return r;
}
