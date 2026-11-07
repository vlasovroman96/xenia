module randr.rrlease;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
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
 */
import build.dix_config;

import core.sys.posix.unistd;

import dix.dix_priv;
import dix.request_priv;
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import os.client_priv;
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

import dix.swaprep;

// RESTYPE RRLeaseType;

/*
 * Notify of some lease change
 */
void RRDeliverLeaseEvent(ClientPtr client, WindowPtr window)
{
    ScreenPtr screen = window.drawable.pScreen;
    rrScrPrivPtr scr_priv = mixin(rrGetScrPriv!("screen"));

    UpdateCurrentTimeIf();
    foreach(lease; scr_priv.leases.byEntries!RRLeasePtr) {
        if (lease.id != None && (lease.state == RRLeaseCreating ||
                                  lease.state == RRLeaseTerminating))
        {
            xRRLeaseNotifyEvent le = xRRLeaseNotifyEvent (
                type: cast(ubyte)(RRNotify + RREventBase),
                subCode: RRNotify_Lease,
                timestamp: currentTime.milliseconds,
                window: cast(uint)window.drawable.id,
                lease: cast(uint)lease.id,
                created: lease.state == RRLeaseCreating,
            );
            WriteEventsToClient(client, 1, cast(xEvent*) &le);
        }
    }
}

/*
 * Change the state of a lease and let anyone watching leases know
 */
private void RRLeaseChangeState(RRLeasePtr lease, RRLeaseState old, RRLeaseState new_)
{
    ScreenPtr screen = lease.screen;
    rrScrPrivPtr scr_priv = mixin(rrGetScrPriv!("screen"));

    lease.state = old;
    scr_priv.leasesChanged = TRUE;
    RRSetChanged(lease.screen);
    RRTellChanged(lease.screen);
    scr_priv.leasesChanged = FALSE;
    lease.state = new_;
}

/*
 * Allocate and initialize a lease
 */
private RRLeasePtr RRLeaseAlloc(ScreenPtr screen, RRLease lid, int numCrtcs, int numOutputs)
{
    RRLeasePtr lease = void;
    lease = cast(RRLeasePtr)calloc(1,
                   ((RRLeaseRec).sizeof +
                   numCrtcs * (RRCrtcPtr.sizeof +
                   numOutputs * RROutputPtr.sizeof)));
    if (!lease)
        return null;
    lease.screen = screen;
    lease.list.initList();
    lease.id = lid;
    lease.state = RRLeaseCreating;
    lease.numCrtcs = numCrtcs;
    lease.numOutputs = numOutputs;
    lease.crtcs = cast(RRCrtcPtr*) (lease + 1);
    lease.outputs = cast(RROutputPtr*) (lease.crtcs + numCrtcs);
    return lease;
}

/*
 * Check if a crtc is leased
 */
Bool RRCrtcIsLeased(RRCrtcPtr crtc)
{
    ScreenPtr screen = crtc.pScreen;
    rrScrPrivPtr scr_priv = mixin(rrGetScrPriv!("screen"));
    int c = void;

    foreach(lease; scr_priv.leases.byEntries!RRLeasePtr) {
        for (c = 0; c < lease.numCrtcs; c++)
            if (lease.crtcs[c] == crtc)
                return TRUE;
    }
    return FALSE;
}

/*
 * Check if an output is leased
 */
Bool RROutputIsLeased(RROutputPtr output)
{
    ScreenPtr screen = output.pScreen;
    rrScrPrivPtr scr_priv = mixin(rrGetScrPriv!("screen"));
    int o = void;

    foreach(lease; scr_priv.leases.byEntries!RRLeasePtr) {
        for (o = 0; o < lease.numOutputs; o++)
            if (lease.outputs[o] == output)
                return TRUE;
    }
    return FALSE;
}

/*
 * A lease has been terminated.
 * The driver is responsible for noticing and
 * calling this function when that happens
 */

void RRLeaseTerminated(RRLeasePtr lease)
{
    /* Notify clients with events, but only if this isn't during lease creation */
    if (lease.state == RRLeaseRunning)
        RRLeaseChangeState(lease, RRLeaseTerminating, RRLeaseTerminating);

    if (lease.id != None)
        FreeResource(cast(uint)lease.id, X11_RESTYPE_NONE);

    lease.list.removeFromList();
}

/*
 * A lease is completely shut down and is
 * ready to be deallocated
 */

void RRLeaseFree(RRLeasePtr lease)
{
    free(lease);
}

/*
 * Ask the driver to terminate a lease. The
 * driver will call RRLeaseTerminated when that has
 * finished, which may be some time after this function returns
 * if the driver operation is asynchronous
 */
void RRTerminateLease(RRLeasePtr lease)
{
    ScreenPtr screen = lease.screen;
    rrScrPrivPtr scr_priv = mixin(rrGetScrPriv!("screen"));

    scr_priv.rrTerminateLease(screen, lease);
}

/*
 * Destroy a lease resource ID. All this
 * does is note that the lease no longer has an ID, and
 * so doesn't appear over the protocol anymore.
 */
private int RRLeaseDestroyResource(void* value, XID pid)
{
    RRLeasePtr lease = cast(RRLeasePtr)value;

    lease.id = None;
    return 1;
}

/*
 * Create the lease resource type during server initialization
 */
Bool RRLeaseInit()
{
    RRLeaseType = CreateNewResourceType(&RRLeaseDestroyResource, "LEASE");
    if (!RRLeaseType)
        return FALSE;
    return TRUE;
}

int ProcRRCreateLease(ClientPtr client)
{
    mixin(REQUEST!xRRCreateLeaseReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRCreateLeaseReq);

    if (client.swapped) {
        swapl(&stuff.window);
        swaps(&stuff.nCrtcs);
        swaps(&stuff.nOutputs);
        swapl(&stuff.lid);
        mixin(SwapRestL!("stuff"));
    }

    WindowPtr window = void;
    ScreenPtr screen = void;
    rrScrPrivPtr scr_priv = void;
    RRLeasePtr lease = void;
    RRCrtc* crtcIds = void;
    RROutput* outputIds = void;
    int fd = void;
    int rc = void;
    c_ulong len = void;
    int c = void, o = void;

    mixin(LEGAL_NEW_RESOURCE!("stuff.lid", "client"));

    rc = dixLookupWindow(&window, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    len = cast(int)(client.req_len - bytes_to_int32(xRRCreateLeaseReq.sizeof));

    if (len != stuff.nCrtcs + stuff.nOutputs)
        return BadLength;

    screen = window.drawable.pScreen;
    scr_priv = mixin(rrGetScrPriv!("screen"));

    xRRCreateLeaseReply reply = {
        nfd: 1,
    };

    if (!scr_priv)
        return BadMatch;

    if (!scr_priv.rrCreateLease && !scr_priv.rrRequestLease)
        return BadMatch;

    if (scr_priv.rrGetLease) {
        scr_priv.rrGetLease(client, screen, &lease, &fd);
        if (lease) {
            if (fd >= 0)
                goto leaseReturned;
            else
                goto bail_lease;
        }
    }

    /* Allocate a structure to hold all of the lease information */

    lease = RRLeaseAlloc(screen, stuff.lid, stuff.nCrtcs, stuff.nOutputs);
    if (!lease)
        return BadAlloc;

    /* Look up all of the crtcs */
    crtcIds = cast(RRCrtc*) (stuff + 1);
    for (c = 0; c < stuff.nCrtcs; c++) {
        RRCrtcPtr crtc = void;

	rc = dixLookupResourceByType(cast(void**)&crtc, crtcIds[c],
                                     RRCrtcType, client, DixSetAttrAccess);

        if (rc != Success) {
            client.errorValue = cast(uint)crtcIds[c];
            goto bail_lease;
        }

        if (RRCrtcIsLeased(crtc)) {
            client.errorValue = cast(uint)crtcIds[c];
            rc = BadAccess;
            goto bail_lease;
        }

        lease.crtcs[c] = crtc;
    }

    /* Look up all of the outputs */
    outputIds = cast(RROutput*) (crtcIds + stuff.nCrtcs);
    for (o = 0; o < stuff.nOutputs; o++) {
        RROutputPtr output = void;

	rc = dixLookupResourceByType(cast(void**)&output, outputIds[o],
                                     RROutputType, client, DixSetAttrAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)outputIds[o];
            goto bail_lease;
        }

        if (RROutputIsLeased(output)) {
            client.errorValue = cast(uint)outputIds[o];
            rc = BadAccess;
            goto bail_lease;
        }

        lease.outputs[o] = output;
    }

    if (scr_priv.rrRequestLease) {
        rc = scr_priv.rrRequestLease(client, screen, lease);
        if (rc == Success)
            return Success;
        else
            goto bail_lease;
    } else {
        rc = scr_priv.rrCreateLease(screen, lease, &fd);
        if (rc != Success)
            goto bail_lease;
    }

leaseReturned:
    scr_priv.leases.addListNext(&lease.list);

    if (!AddResource(cast(uint)stuff.lid, RRLeaseType, lease)) {
        close(fd);
        return BadAlloc;
    }

    if (WriteFdToClient(client, fd, TRUE) < 0) {
        RRTerminateLease(lease);
        close(fd);
        return BadAlloc;
    }

    RRLeaseChangeState(lease, RRLeaseCreating, RRLeaseRunning);

    

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));

bail_lease:
    free(lease);
    return rc;
}

int ProcRRFreeLease(ClientPtr client)
{
    mixin(REQUEST!xRRFreeLeaseReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRFreeLeaseReq);

    if (client.swapped)
        swapl(&stuff.lid);

    RRLeasePtr lease = void;
    mixin(VERIFY_RR_LEASE!("stuff.lid", "lease", "DixDestroyAccess"));

    if (stuff.terminate)
        RRTerminateLease(lease);
    else
        /* Get rid of the resource database entry */
        FreeResource(cast(uint)stuff.lid, X11_RESTYPE_NONE);

    return Success;
}
