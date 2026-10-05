module randr.rrcrtc;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2006 Keith Packard
 * Copyright 2010 Red Hat, Inc
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
import dix.rpcbuf_priv;
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import os.bug_priv;
import os.osdep;

import dix.swaprep;
import mi.mipointer;
import include.rrtransform;
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

import externs.attrs;
 

/* XFixed is just `int`, so better check whether it's really 32bit */
static assert(XFixed.sizeof, CARD32.sizeof);

RESTYPE RRCrtcType = 0;

/*
 * Notify the CRTC of some change
 */
private void RRCrtcChanged(RRCrtcPtr crtc, Bool layoutChanged)
{
    ScreenPtr pScreen = crtc.pScreen;

    crtc.changed = TRUE;
    if (pScreen) {
        mixin(rrScrPriv!("pScreen"));

        RRSetChanged(pScreen);
        /*
         * Send ConfigureNotify on any layout change
         */
        if (layoutChanged)
            pScrPriv.layoutChanged = TRUE;
    }
}

/*
 * Create a CRTC
 */
RRCrtcPtr RRCrtcCreate(ScreenPtr pScreen, void* devPrivate)
{
    RRCrtcPtr crtc = void;
    RRCrtcPtr* crtcs = void;
    rrScrPrivPtr pScrPriv = void;

    if (!RRInit())
        return null;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    /* make space for the crtc pointer */
    crtcs = cast(_rrCrtc**)cast(RRCrtcPtr*)reallocarray(pScrPriv.crtcs,
            pScrPriv.numCrtcs + 1, RRCrtcPtr.sizeof);
    if (!crtcs)
        return null;
    pScrPriv.crtcs = crtcs;

    crtc = cast(RRCrtcRec*) calloc(1, RRCrtcRec.sizeof);
    if (!crtc)
        return null;
    crtc.id = dixAllocServerXID();
    crtc.pScreen = pScreen;
    crtc.rotation = RR_Rotate_0;
    crtc.rotations = RR_Rotate_0;
    crtc.devPrivate = devPrivate;
    RRTransformInit(&crtc.client_pending_transform);
    RRTransformInit(&crtc.client_current_transform);
    assumeNoGC(&pixman_transform_init_identity)(&crtc.transform);
    assumeNoGC(&pixman_f_transform_init_identity)(&crtc.f_transform);
    assumeNoGC(&pixman_f_transform_init_identity)(&crtc.f_inverse);

    if (!AddResource(cast(uint)crtc.id, RRCrtcType, cast(void*) crtc))
        return null;

    /* attach the screen and crtc together */
    crtc.pScreen = pScreen;
    pScrPriv.crtcs[pScrPriv.numCrtcs++] = crtc;

    RRResourcesChanged(pScreen);

    return crtc;
}

/*
 * Set the allowed rotations on a CRTC
 */
void RRCrtcSetRotations(RRCrtcPtr crtc, Rotation rotations)
{
    crtc.rotations = rotations;
}

/*
 * Set whether transforms are allowed on a CRTC
 */
void RRCrtcSetTransformSupport(RRCrtcPtr crtc, Bool transforms)
{
    crtc.transforms = transforms;
}

/*
 * Notify the extension that the Crtc has been reconfigured,
 * the driver calls this whenever it has updated the mode
 */
Bool RRCrtcNotify(RRCrtcPtr crtc, RRModePtr mode, int x, int y, Rotation rotation, RRTransformPtr transform, int numOutputs, RROutputPtr* outputs)
{
    int i = void, j = void;

    /*
     * Check to see if any of the new outputs were
     * not in the old list and mark them as changed
     */
    for (i = 0; i < numOutputs; i++) {
        for (j = 0; j < crtc.numOutputs; j++)
            if (outputs[i] == crtc.outputs[j])
                break;
        if (j == crtc.numOutputs) {
            outputs[i].crtc = crtc;
            RROutputChanged(outputs[i], FALSE);
            RRCrtcChanged(crtc, FALSE);
        }
    }
    /*
     * Check to see if any of the old outputs are
     * not in the new list and mark them as changed
     */
    for (j = 0; j < crtc.numOutputs; j++) {
        for (i = 0; i < numOutputs; i++)
            if (outputs[i] == crtc.outputs[j])
                break;
        if (i == numOutputs) {
            if (crtc.outputs[j].crtc == crtc)
                crtc.outputs[j].crtc = null;
            RROutputChanged(crtc.outputs[j], FALSE);
            RRCrtcChanged(crtc, FALSE);
        }
    }
    /*
     * Reallocate the crtc output array if necessary
     */
    if (numOutputs != crtc.numOutputs) {
        RROutputPtr* newoutputs = void;

        if (numOutputs) {
            if (crtc.numOutputs)
                newoutputs = cast(RROutputPtr*)reallocarray(crtc.outputs,
                                          numOutputs, RROutputPtr.sizeof);
            else
                newoutputs = cast(RROutputPtr*) calloc(numOutputs, RROutputPtr.sizeof);
            if (!newoutputs)
                return FALSE;
        }
        else {
            free(crtc.outputs);
            newoutputs = null;
        }
        crtc.outputs = newoutputs;
        crtc.numOutputs = numOutputs;
    }

    /*
     * Copy the new list of outputs into the crtc
     */
    // mixin(BUG_RETURN_VAL!("numOutputs != 0 && outputs is null", "FALSE"));
    if (numOutputs > 0)
        memcpy(crtc.outputs, outputs, numOutputs * RROutputPtr.sizeof);

    /*
     * Update remaining crtc fields
     */
    if (mode != crtc.mode) {
        if (crtc.mode)
            RRModeDestroy(crtc.mode);
        crtc.mode = mode;
        if (mode !is null)
            mode.refcnt++;
        RRCrtcChanged(crtc, TRUE);
    }
    if (x != crtc.x) {
        crtc.x = x;
        RRCrtcChanged(crtc, TRUE);
    }
    if (y != crtc.y) {
        crtc.y = y;
        RRCrtcChanged(crtc, TRUE);
    }
    if (rotation != crtc.rotation) {
        crtc.rotation = rotation;
        RRCrtcChanged(crtc, TRUE);
    }
    if (!RRTransformEqual(transform, &crtc.client_current_transform)) {
        RRTransformCopy(&crtc.client_current_transform, transform);
        RRCrtcChanged(crtc, TRUE);
    }
    if (crtc.changed && mode) {
        RRTransformCompute(x, y,
                           mode.mode.width, mode.mode.height,
                           rotation,
                           &crtc.client_current_transform,
                           &crtc.transform, &crtc.f_transform,
                           &crtc.f_inverse);
    }
    return TRUE;
}

void RRDeliverCrtcEvent(ClientPtr client, WindowPtr pWin, RRCrtcPtr crtc)
{
    ScreenPtr pScreen = pWin.drawable.pScreen;

    mixin(rrScrPriv!("pScreen"));
    RRModePtr mode = crtc.mode;

    xRRCrtcChangeNotifyEvent ce = {
        type: cast(ubyte)(RRNotify + RREventBase),
        subCode: RRNotify_CrtcChange,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        window: cast(uint)pWin.drawable.id,
        crtc: cast(uint)crtc.id,
        mode: mode ? mode.mode.id : None,
        rotation: crtc.rotation,
        x: cast(short)(mode ? crtc.x : 0),
        y: cast(short)(mode ? crtc.y : 0),
        width: mode ? mode.mode.width : 0,
        height: mode ? mode.mode.height : 0
    };
    WriteEventsToClient(client, 1, cast(xEvent*) &ce);
}

private Bool RRCrtcPendingProperties(RRCrtcPtr crtc)
{
    ScreenPtr pScreen = crtc.pScreen;

    mixin(rrScrPriv!("pScreen"));
    int o = void;

    for (o = 0; o < pScrPriv.numOutputs; o++) {
        RROutputPtr output = pScrPriv.outputs[o];

        if (output.crtc == crtc && output.pendingProperties)
            return TRUE;
    }
    return FALSE;
}

private Bool cursor_bounds(RRCrtcPtr crtc, int* left, int* right, int* top, int* bottom)
{
    mixin(rrScrPriv!("crtc.pScreen"));
    BoxRec bounds = void;

    if (crtc.mode is null)
	return FALSE;

    memset(&bounds, 0, bounds.sizeof);
    if (pScrPriv.rrGetPanning)
	pScrPriv.rrGetPanning(crtc.pScreen, crtc, null, &bounds, null);

    if (bounds.y2 <= bounds.y1 || bounds.x2 <= bounds.x1) {
	bounds.x1 = 0;
	bounds.y1 = 0;
	bounds.x2 = crtc.mode.mode.width;
	bounds.y2 = crtc.mode.mode.height;
    }

    assumeNoGC(&pixman_f_transform_bounds)(&crtc.f_transform, &bounds);

    *left = bounds.x1;
    *right = bounds.x2;
    *top = bounds.y1;
    *bottom = bounds.y2;

    return TRUE;
}

/* overlapping counts as adjacent */
private Bool crtcs_adjacent(RRCrtcPtr a, RRCrtcPtr b)
{
    /* left, right, top, bottom... */
    int al = void, ar = void, at = void, ab = void;
    int bl = void, br = void, bt = void, bb = void;
    int cl = void, cr = void, ct = void, cb = void;         /* the overlap, if any */

    if (!cursor_bounds(a, &al, &ar, &at, &ab))
	    return FALSE;
    if (!cursor_bounds(b, &bl, &br, &bt, &bb))
	    return FALSE;

    cl = max(al, bl);
    cr = min(ar, br);
    ct = max(at, bt);
    cb = min(ab, bb);

    return (cl <= cr) && (ct <= cb);
}

/* Depth-first search and mark all CRTCs reachable from cur */
private void mark_crtcs(rrScrPrivPtr pScrPriv, int* reachable, int cur)
{
    int i = void;

    reachable[cur] = TRUE;
    for (i = 0; i < pScrPriv.numCrtcs; ++i) {
        if (reachable[i])
            continue;
        if (crtcs_adjacent(pScrPriv.crtcs[cur], pScrPriv.crtcs[i]))
            mark_crtcs(pScrPriv, reachable, i);
    }
}

private void RRComputeContiguity(ScreenPtr pScreen)
{
    mixin(rrScrPriv!("pScreen"));
    Bool discontiguous = TRUE;
    int i = void, n = pScrPriv.numCrtcs;

    int* reachable = cast(int*) calloc(n, int.sizeof);

    if (!reachable)
        goto out_;

    /* Find first enabled CRTC and start search for reachable CRTCs from it */
    for (i = 0; i < n; ++i) {
        if (pScrPriv.crtcs[i].mode) {
            mark_crtcs(pScrPriv, reachable, i);
            break;
        }
    }

    /* Check that all enabled CRTCs were marked as reachable */
    for (i = 0; i < n; ++i)
        if (pScrPriv.crtcs[i].mode && !reachable[i])
            goto out_;

    discontiguous = FALSE;

 out_:
    free(reachable);
    pScrPriv.discontiguous = discontiguous;
}

private void rrDestroySharedPixmap(RRCrtcPtr crtc, PixmapPtr pPixmap) {
    ScreenPtr primary = crtc.pScreen.current_primary;

    if (primary && pPixmap.primary_pixmap) {
        /*
         * Unref the pixmap twice: once for the original reference, and once
         * for the reference implicitly added by PixmapShareToSecondary.
         */
        PixmapUnshareSecondaryPixmap(pPixmap);

        dixDestroyPixmap(pPixmap.primary_pixmap, 0);
        dixDestroyPixmap(pPixmap.primary_pixmap, 0);
    }

    dixDestroyPixmap(pPixmap, 0);
}

void RRCrtcDetachScanoutPixmap(RRCrtcPtr crtc)
{
    mixin(rrScrPriv!("crtc.pScreen"));

    if (crtc.scanout_pixmap) {
        ScreenPtr primary = crtc.pScreen.current_primary;
        DrawablePtr mrootdraw = &primary.root.drawable;

        if (crtc.scanout_pixmap_back) {
            pScrPriv.rrDisableSharedPixmapFlipping(crtc);

            if (mrootdraw) {
                primary.StopFlippingPixmapTracking(mrootdraw,
                                                   crtc.scanout_pixmap,
                                                   crtc.scanout_pixmap_back);
            }

            rrDestroySharedPixmap(crtc, crtc.scanout_pixmap_back);
            crtc.scanout_pixmap_back = null;
        }
        else {
            pScrPriv.rrCrtcSetScanoutPixmap(crtc, null);

            if (mrootdraw) {
                primary.StopPixmapTracking(mrootdraw,
                                           crtc.scanout_pixmap);
            }
        }

        rrDestroySharedPixmap(crtc, crtc.scanout_pixmap);
        crtc.scanout_pixmap = null;
    }

    RRCrtcChanged(crtc, TRUE);
}

private PixmapPtr rrCreateSharedPixmap(RRCrtcPtr crtc, ScreenPtr primary, int width, int height, int depth, int x, int y, Rotation rotation)
{
    PixmapPtr mpix = void, spix = void;

    mpix = primary.CreatePixmap(primary, width, height, depth,
                                CREATE_PIXMAP_USAGE_SHARED);
    if (!mpix)
        return null;

    spix = PixmapShareToSecondary(mpix, crtc.pScreen);
    if (spix is null) {
        dixDestroyPixmap(mpix, 0);
        return null;
    }

    return spix;
}

private Bool rrGetPixmapSharingSyncProp(int numOutputs, RROutputPtr* outputs)
{
    /* Determine if the user wants prime syncing */
    int o = void;
    const(char)* syncStr = PRIME_SYNC_PROP;
    Atom syncProp = dixGetAtomID(syncStr);
    if (syncProp == None)
        return TRUE;

    /* If one output doesn't want sync, no sync */
    for (o = 0; o < numOutputs; o++) {
        RRPropertyValuePtr val = void;

        if ((val = RRGetOutputProperty(outputs[o], syncProp, TRUE) )!is null &&
            val.data) {
            if (!(*cast(char*) val.data))
                return FALSE;
            continue;
        }
    }

    return TRUE;
}

private void rrSetPixmapSharingSyncProp(char val, int numOutputs, RROutputPtr* outputs)
{
    int o = void;
    const(char)* syncStr = PRIME_SYNC_PROP;
    Atom syncProp = dixGetAtomID(syncStr);
    if (syncProp == None)
        return;

    for (o = 0; o < numOutputs; o++) {
        RRPropertyPtr prop = RRQueryOutputProperty(outputs[o], syncProp);
        if (prop)
            RRChangeOutputProperty(outputs[o], syncProp, XA_INTEGER,
                                   8, PropModeReplace, 1, &val, FALSE, TRUE);
    }
}

private Bool rrSetupPixmapSharing(RRCrtcPtr crtc, int width, int height, int x, int y, Rotation rotation, Bool sync, int numOutputs, RROutputPtr* outputs)
{
    ScreenPtr primary = crtc.pScreen.current_primary;
    rrScrPrivPtr pPrimaryScrPriv = mixin(rrGetScrPriv!("primary"));
    rrScrPrivPtr pSecondaryScrPriv = mixin(rrGetScrPriv!("crtc.pScreen"));
    DrawablePtr mrootdraw = &primary.root.drawable;
    int depth = mrootdraw.depth;
    PixmapPtr spix_front = void;

    /* Create a pixmap on the primary screen, then get a shared handle for it.
       Create a shared pixmap on the secondary screen using the handle.

       If sync == FALSE --
       Set secondary screen to scanout shared linear pixmap.
       Set the primary screen to do dirty updates to the shared pixmap
       from the screen pixmap on its own accord.

       If sync == TRUE --
       If any of the below steps fail, clean up and fall back to sync == FALSE.
       Create another shared pixmap on the secondary screen using the handle.
       Set secondary screen to prepare for scanout and flipping between shared
       linear pixmaps.
       Set the primary screen to do dirty updates to the shared pixmaps from the
       screen pixmap when prompted to by us or the secondary.
       Prompt the primary to do a dirty update on the first shared pixmap, then
       defer to the secondary.
    */

    if (crtc.scanout_pixmap)
        RRCrtcDetachScanoutPixmap(crtc);

    if (width == 0 && height == 0) {
        return TRUE;
    }

    spix_front = rrCreateSharedPixmap(crtc, primary,
                                      width, height, depth,
                                      x, y, rotation);
    if (spix_front is null) {
        ErrorF("randr: failed to create shared pixmap\n");
        return FALSE;
    }

    /* Both source and sink must support required ABI funcs for flipping */
    if (sync &&
        pSecondaryScrPriv.rrEnableSharedPixmapFlipping &&
        pSecondaryScrPriv.rrDisableSharedPixmapFlipping &&
        pPrimaryScrPriv.rrStartFlippingPixmapTracking &&
        primary.PresentSharedPixmap &&
        primary.StopFlippingPixmapTracking) {

        PixmapPtr spix_back = rrCreateSharedPixmap(crtc, primary,
                                                   width, height, depth,
                                                   x, y, rotation);
        if (spix_back is null)
            goto fail;

        if (!pSecondaryScrPriv.rrEnableSharedPixmapFlipping(crtc,
                                                         spix_front, spix_back))
            goto fail;

        crtc.scanout_pixmap = spix_front;
        crtc.scanout_pixmap_back = spix_back;

        if (!pPrimaryScrPriv.rrStartFlippingPixmapTracking(crtc,
                                                           mrootdraw,
                                                           spix_front,
                                                           spix_back,
                                                           x, y, 0, 0,
                                                           rotation)) {
            pSecondaryScrPriv.rrDisableSharedPixmapFlipping(crtc);
            goto fail;
        }

        primary.PresentSharedPixmap(spix_front);

        return TRUE;

fail: /* If flipping funcs fail, just fall back to unsynchronized */
        if (spix_back)
            rrDestroySharedPixmap(crtc, spix_back);

        crtc.scanout_pixmap = null;
        crtc.scanout_pixmap_back = null;
    }

    if (sync) { /* Wanted sync, didn't get it */
        ErrorF("randr: falling back to unsynchronized pixmap sharing\n");

        /* Set output property to 0 to indicate to user */
        rrSetPixmapSharingSyncProp(0, numOutputs, outputs);
    }

    if (!pSecondaryScrPriv.rrCrtcSetScanoutPixmap(crtc, spix_front)) {
        rrDestroySharedPixmap(crtc, spix_front);
        ErrorF("randr: failed to set shadow secondary pixmap\n");
        return FALSE;
    }
    crtc.scanout_pixmap = spix_front;

    primary.StartPixmapTracking(mrootdraw, spix_front, x, y, 0, 0, rotation);

    return TRUE;
}

private void crtc_to_box(BoxPtr box, RRCrtcPtr crtc)
{
    box.x1 = cast(short)(crtc.x);
    box.y1 = cast(short)(crtc.y);
    switch (crtc.rotation) {
    case RR_Rotate_0:
    case RR_Rotate_180:
    default:
        box.x2 = cast(short)(crtc.x + crtc.mode.mode.width);
        box.y2 = cast(short)(crtc.y + crtc.mode.mode.height);
        break;
    case RR_Rotate_90:
    case RR_Rotate_270:
        box.x2 = cast(short)(crtc.x + crtc.mode.mode.height);
        box.y2 = cast(short)(crtc.y + crtc.mode.mode.width);
        break;
    }
}

private Bool rrCheckPixmapBounding(ScreenPtr pScreen, RRCrtcPtr rr_crtc, Rotation rotation, int x, int y, int w, int h)
{
    RegionRec root_pixmap_region = void, total_region = void, new_crtc_region = void;
    int c = void;
    BoxRec newbox = void;
    BoxPtr newsize = void;
    ScreenPtr secondary = void;
    int new_width = void, new_height = void;
    PixmapPtr screen_pixmap = pScreen.GetScreenPixmap(pScreen);
    mixin(rrScrPriv!("pScreen"));

    PixmapRegionInit(&root_pixmap_region, screen_pixmap);
    RegionInit(&total_region, null, 0);

    /* have to iterate all the crtcs of the attached gpu primarys
       and all their output secondarys */
    for (c = 0; c < pScrPriv.numCrtcs; c++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[c];

        if (crtc == rr_crtc) {
            newbox.x1 = cast(short)(x);
            newbox.y1 = cast(short)(y);
            if (rotation == RR_Rotate_90 ||
                rotation == RR_Rotate_270) {
                newbox.x2 = cast(short)(x + h);
                newbox.y2 = cast(short)(y + w);
            } else {
                newbox.x2 = cast(short)(x + w);
                newbox.y2 = cast(short)(y + h);
            }
        } else {
            if (!crtc.mode)
                continue;
            crtc_to_box(&newbox, crtc);
        }
        RegionInit(&new_crtc_region, &newbox, 1);
        RegionUnion(&total_region, &total_region, &new_crtc_region);
    }

    mixin(xorg_list_for_each_entry!("secondary", "&pScreen.secondary_list", "secondary_head", q{
        rrScrPrivPtr secondary_priv = mixin(rrGetScrPriv!("secondary"));

        if (!secondary.is_output_secondary)
            continue;

        for (c = 0; c < secondary_priv.numCrtcs; c++) {
            RRCrtcPtr secondary_crtc = secondary_priv.crtcs[c];

            if (secondary_crtc == rr_crtc) {
                newbox.x1 = cast(short)(x);
                newbox.y1 = cast(short)(y);
                if (rotation == RR_Rotate_90 ||
                    rotation == RR_Rotate_270) {
                    newbox.x2 = cast(short)(x + h);
                    newbox.y2 = cast(short)(y + w);
                } else {
                    newbox.x2 = cast(short)(x + w);
                    newbox.y2 = cast(short)(y + h);
                }
            }
            else {
                if (!secondary_crtc.mode)
                    continue;
                crtc_to_box(&newbox, secondary_crtc);
            }
            RegionInit(&new_crtc_region, &newbox, 1);
            RegionUnion(&total_region, &total_region, &new_crtc_region);
        }
    }));

    newsize = RegionExtents(&total_region);
    new_width = newsize.x2;
    new_height = newsize.y2;

    if (new_width < screen_pixmap.drawable.width)
        new_width = screen_pixmap.drawable.width;

    if (new_height < screen_pixmap.drawable.height)
        new_height = screen_pixmap.drawable.height;

    if (new_width <= screen_pixmap.drawable.width &&
        new_height <= screen_pixmap.drawable.height) {
    } else {
        pScrPriv.rrScreenSetSize(pScreen, cast(ushort)new_width, cast(ushort)new_height, 0, 0);
    }

    /* set shatters TODO */
    return TRUE;
}

enum XRANDR_EMULATION_PROP = "RANDR Emulation";
private Bool rrCheckEmulated(RROutputPtr output)
{
    const(char)* emulStr = XRANDR_EMULATION_PROP;
    RRPropertyValuePtr val = void;

    Atom emulProp = dixGetAtomID(emulStr);
    if (emulProp == None)
        return FALSE;

    val = RRGetOutputProperty(output, emulProp, TRUE);
    if (val && val.data)
        return !!val.data;

    return FALSE;
}


/*
 * Check whether the pending and current transforms are the same
 */
pragma(inline, true) private Bool RRCrtcPendingTransform(RRCrtcPtr crtc)
{
    return !RRTransformEqual(&crtc.client_current_transform,
                             &crtc.client_pending_transform);
}

/*
 * Request that the Crtc be reconfigured
 */
Bool RRCrtcSet(RRCrtcPtr crtc, RRModePtr mode, int x, int y, Rotation rotation, int numOutputs, RROutputPtr* outputs)
{
    ScreenPtr pScreen = crtc.pScreen;
    Bool ret = FALSE;
    Bool recompute = TRUE;
    Bool crtcChanged = void;
    int o = void;

    mixin(BUG_RETURN_VAL!("numOutputs != 0 && outputs is null", "FALSE"));

    mixin(rrScrPriv!("pScreen"));

    crtcChanged = FALSE;
    for (o = 0; o < numOutputs; o++) {
        if (outputs[o]) {
            if (rrCheckEmulated(outputs[o]) || (outputs[o].crtc != crtc)) {
                crtcChanged = TRUE;
                break;
            }
        }
    }

    /* See if nothing changed */
    if (crtc.mode == mode &&
        crtc.x == x &&
        crtc.y == y &&
        crtc.rotation == rotation &&
        crtc.numOutputs == numOutputs &&
        !memcmp(crtc.outputs, outputs, numOutputs * RROutputPtr.sizeof) &&
        !RRCrtcPendingProperties(crtc) && !RRCrtcPendingTransform(crtc) &&
        !crtcChanged) {
        recompute = FALSE;
        ret = TRUE;
    }
    else {
        if (pScreen.isGPU) {
            ScreenPtr primary = pScreen.current_primary;
            int width = 0, height = 0;

            if (mode) {
                width = mode.mode.width;
                height = mode.mode.height;
            }
            ret = rrCheckPixmapBounding(primary, crtc,
                                        rotation, x, y, width, height);
            if (!ret)
                return FALSE;

            if (pScreen.current_primary) {
                Bool sync = rrGetPixmapSharingSyncProp(numOutputs, outputs);
                ret = rrSetupPixmapSharing(crtc, width, height,
                                           x, y, rotation, sync,
                                           numOutputs, outputs);
            }
        }
static if (RANDR_12_INTERFACE) {
        if (pScrPriv.rrCrtcSet) {
            ret = (*pScrPriv.rrCrtcSet) (pScreen, crtc, mode, x, y,
                                          rotation, numOutputs, outputs);
        }
        else{
            if (pScrPriv.rrSetConfig) {
                RRScreenSize size = void;
                RRScreenRate rate = void;

                if (!mode) {
                    RRCrtcNotify(crtc, null, x, y, rotation, null, 0, null);
                    ret = TRUE;
                }
                else {
                    size.width = mode.mode.width;
                    size.height = mode.mode.height;
                    if (outputs[0].mmWidth && outputs[0].mmHeight) {
                        size.mmWidth = cast(short)outputs[0].mmWidth;
                        size.mmHeight = cast(short)outputs[0].mmHeight;
                    }
                    else {
                        size.mmWidth = cast(short)pScreen.mmWidth;
                        size.mmHeight = cast(short)pScreen.mmHeight;
                    }
                    size.nRates = 1;
                    rate.rate = RRVerticalRefresh(&mode.mode);
                    size.pRates = &rate;
                    ret =
                        (*pScrPriv.rrSetConfig) (pScreen, rotation, rate.rate,
                                                  &size);
                    /*
                     * Old 1.0 interface tied screen size to mode size
                     */
                    if (ret) {
                        RRCrtcNotify(crtc, mode, x, y, rotation, null, 1,
                                     outputs);
                        RRScreenSizeNotify(pScreen);
                    }
                }
            }
        }
}
else
        {
            if (pScrPriv.rrSetConfig) {
                RRScreenSize size = void;
                RRScreenRate rate = void;

                if (!mode) {
                    RRCrtcNotify(crtc, null, x, y, rotation, null, 0, null);
                    ret = TRUE;
                }
                else {
                    size.width = mode.mode.width;
                    size.height = mode.mode.height;
                    if (outputs[0].mmWidth && outputs[0].mmHeight) {
                        size.mmWidth = outputs[0].mmWidth;
                        size.mmHeight = outputs[0].mmHeight;
                    }
                    else {
                        size.mmWidth = pScreen.mmWidth;
                        size.mmHeight = pScreen.mmHeight;
                    }
                    size.nRates = 1;
                    rate.rate = RRVerticalRefresh(&mode.mode);
                    size.pRates = &rate;
                    ret =
                        (*pScrPriv.rrSetConfig) (pScreen, rotation, rate.rate,
                                                  &size);
                    /*
                     * Old 1.0 interface tied screen size to mode size
                     */
                    if (ret) {
                        RRCrtcNotify(crtc, mode, x, y, rotation, null, 1,
                                     outputs);
                        RRScreenSizeNotify(pScreen);
                    }
                }
            }
        }
        if (ret) {

            RRTellChanged(pScreen);

            for (o = 0; o < numOutputs; o++)
                RRPostPendingProperties(outputs[o]);
        }
    }

    if (recompute)
        RRComputeContiguity(pScreen);

    return ret;
}

/*
 * Return crtc transform
 */
RRTransformPtr RRCrtcGetTransform(RRCrtcPtr crtc)
{
    RRTransformPtr transform = &crtc.client_pending_transform;

    if (assumeNoGC(&pixman_transform_is_identity)(&transform.transform))
        return null;
    return transform;
}

/*
 * Destroy a Crtc at shutdown
 */
void RRCrtcDestroy(RRCrtcPtr crtc)
{
    FreeResource(cast(uint)crtc.id, 0);
}

private int RRCrtcDestroyResource(void* value, XID pid)
{
    RRCrtcPtr crtc = cast(RRCrtcPtr) value;
    ScreenPtr pScreen = crtc.pScreen;

    if (pScreen) {
        mixin(rrScrPriv!("pScreen"));
        int i = void;
        RRLeasePtr lease = void, next = void;

        mixin(xorg_list_for_each_entry_safe!("lease", "next", "&pScrPriv.leases", "list", q{
            int c = void;
            for (c = 0; c < lease.numCrtcs; c++) {
                if (lease.crtcs[c] == crtc) {
                    RRTerminateLease(lease);
                    break;
                }
            }
        }));

        for (i = 0; i < pScrPriv.numCrtcs; i++) {
            if (pScrPriv.crtcs[i] == crtc) {
                memmove(pScrPriv.crtcs + i, pScrPriv.crtcs + i + 1,
                        (pScrPriv.numCrtcs - (i + 1)) * RRCrtcPtr.sizeof);
                --pScrPriv.numCrtcs;
                break;
            }
        }

        RRResourcesChanged(pScreen);
    }

    if (crtc.scanout_pixmap)
        RRCrtcDetachScanoutPixmap(crtc);
    free(crtc.gammaRed);
    if (crtc.mode)
        RRModeDestroy(crtc.mode);
    free(crtc.outputs);
    free(crtc);
    return 1;
}

/*
 * Request that the Crtc gamma be changed
 */

Bool RRCrtcGammaSet(RRCrtcPtr crtc, CARD16* red, CARD16* green, CARD16* blue)
{
    Bool ret = TRUE;

static if (RANDR_12_INTERFACE) {
    ScreenPtr pScreen = crtc.pScreen;
}

    memcpy(crtc.gammaRed, red, crtc.gammaSize * CARD16.sizeof);
    memcpy(crtc.gammaGreen, green, crtc.gammaSize * CARD16.sizeof);
    memcpy(crtc.gammaBlue, blue, crtc.gammaSize * CARD16.sizeof);
static if (RANDR_12_INTERFACE) {
    if (pScreen) {
        mixin(rrScrPriv!("pScreen"));
        if (pScrPriv.rrCrtcSetGamma)
            ret = (*pScrPriv.rrCrtcSetGamma) (pScreen, crtc);
    }
}
    return ret;
}

/*
 * Request current gamma back from the DDX (if possible).
 * This includes gamma size.
 */
private Bool RRCrtcGammaGet(RRCrtcPtr crtc)
{
    Bool ret = TRUE;

static if (RANDR_12_INTERFACE) {
    ScreenPtr pScreen = crtc.pScreen;
}

static if (RANDR_12_INTERFACE) {
    if (pScreen) {
        mixin(rrScrPriv!("pScreen"));
        if (pScrPriv.rrCrtcGetGamma)
            ret = (*pScrPriv.rrCrtcGetGamma) (pScreen, crtc);
    }
}
    return ret;
}

private Bool RRCrtcInScreen(ScreenPtr pScreen, RRCrtcPtr findCrtc)
{
    rrScrPrivPtr pScrPriv = void;
    int c = void;

    if (pScreen is null)
        return FALSE;

    if (findCrtc is null)
        return FALSE;

    if (!dixPrivateKeyRegistered(rrPrivKey))
        return FALSE;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    for (c = 0; c < pScrPriv.numCrtcs; c++) {
        if (pScrPriv.crtcs[c] == findCrtc)
            return TRUE;
    }

    return FALSE;
}

Bool RRCrtcExists(ScreenPtr pScreen, RRCrtcPtr findCrtc)
{
    ScreenPtr secondary = null;

    if (RRCrtcInScreen(pScreen, findCrtc))
        return TRUE;

    mixin(xorg_list_for_each_entry!("secondary", "&pScreen.secondary_list", "secondary_head", q{
        if (!secondary.is_output_secondary)
            continue;
        if (RRCrtcInScreen(secondary, findCrtc))
            return TRUE;
    }));

    return FALSE;
}

void RRModeGetScanoutSize(RRModePtr mode, PictTransformPtr transform, int* width, int* height)
{
    if (mode is null) {
        *width = 0;
        *height = 0;
        return;
    }

    BoxRec box = {
        x2: mode.mode.width,
        y2: mode.mode.height,
    };

    assumeNoGC(&pixman_transform_bounds)(transform, &box);
    *width = box.x2 - box.x1;
    *height = box.y2 - box.y1;
}

/**
 * Returns the width/height that the crtc scans out from the framebuffer
 */
void RRCrtcGetScanoutSize(RRCrtcPtr crtc, int* width, int* height)
{
    RRModeGetScanoutSize(crtc.mode, &crtc.transform, width, height);
}

/*
 * Set the size of the gamma table at server startup time
 */

Bool RRCrtcGammaSetSize(RRCrtcPtr crtc, int size)
{
    CARD16* gamma = void;

    if (size == crtc.gammaSize)
        return TRUE;
    if (size) {
        gamma = cast(CARD16*) calloc(size, 3 * CARD16.sizeof);
        if (!gamma)
            return FALSE;
    }
    else
        gamma = null;
    free(crtc.gammaRed);
    crtc.gammaRed = gamma;
    crtc.gammaGreen = gamma + size;
    crtc.gammaBlue = gamma + size * 2;
    crtc.gammaSize = size;
    return TRUE;
}

/*
 * Set the pending CRTC transformation
 */

private int RRCrtcTransformSet(RRCrtcPtr crtc, PictTransformPtr transform, pixman_f_transform* f_transform, pixman_f_transform* f_inverse, char* filter_name, int filter_len, XFixed* params, int nparams)
{
    PictFilterPtr filter = null;
    int width = 0, height = 0;

    if (!crtc.transforms)
        return BadValue;

    if (filter_len) {
        filter = PictureFindFilter(crtc.pScreen, filter_name, filter_len);
        if (!filter)
            return BadName;
        if (filter.ValidateParams) {
            if (!filter.ValidateParams(crtc.pScreen, filter.id,
                                        params, nparams, &width, &height))
                return BadMatch;
        }
        else {
            width = filter.width;
            height = filter.height;
        }
    }
    else {
        if (nparams)
            return BadMatch;
    }
    if (!RRTransformSetFilter(&crtc.client_pending_transform,
                              filter, params, nparams, width, height))
        return BadAlloc;

    crtc.client_pending_transform.transform = *transform;
    crtc.client_pending_transform.f_transform = *f_transform;
    crtc.client_pending_transform.f_inverse = *f_inverse;
    return Success;
}

/*
 * Initialize crtc type
 */
Bool RRCrtcInit()
{
    RRCrtcType = CreateNewResourceType(&RRCrtcDestroyResource, "CRTC");
    if (!RRCrtcType)
        return FALSE;

    return TRUE;
}

/*
 * Initialize crtc type error value
 */
void RRCrtcInitErrorValue()
{
    SetResourceTypeErrorValue(RRCrtcType, RRErrorBase + BadRRCrtc);
}

int ProcRRGetCrtcInfo(ClientPtr client)
{
    mixin(REQUEST!xRRGetCrtcInfoReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetCrtcInfoReq);

    if (client.swapped) {
        swapl(&stuff.crtc);
        swapl(&stuff.configTimestamp);
    }

    RRCrtcPtr crtc = void;
    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    Bool leased = RRCrtcIsLeased(crtc);

    /* All crtcs must be associated with screens before client
     * requests are processed
     */
    ScreenPtr pScreen = crtc.pScreen;
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    RRModePtr mode = crtc.mode;

    xRRGetCrtcInfoReply reply = {
        status: RRSetConfigSuccess,
        timestamp: pScrPriv.lastSetTime.milliseconds,
        rotation: crtc.rotation,
        rotations: crtc.rotations,
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (leased) {
        reply.rotation = RR_Rotate_0;
        reply.rotations = RR_Rotate_0;
    } else {
        BoxRec panned_area = void;
        if (pScrPriv.rrGetPanning &&
            pScrPriv.rrGetPanning(pScreen, crtc, &panned_area, null, null) &&
            (panned_area.x2 > panned_area.x1) && (panned_area.y2 > panned_area.y1))
        {
            reply.x = panned_area.x1;
            reply.y = panned_area.y1;
            reply.width = cast(ushort)(panned_area.x2 - panned_area.x1);
            reply.height = cast(ushort)(panned_area.y2 - panned_area.y1);
        }
        else {
            int width = void, height = void;
            RRCrtcGetScanoutSize(crtc, &width, &height);
            reply.x = cast(short)crtc.x;
            reply.y = cast(short)crtc.y;
            reply.width = cast(ushort)width;
            reply.height = cast(ushort)height;
        }
        reply.mode = mode ? mode.mode.id : 0;
        reply.nOutput = cast(ushort)crtc.numOutputs;
        for (int i = 0; i < pScrPriv.numOutputs; i++) {
            if (!RROutputIsLeased(pScrPriv.outputs[i])) {
                for (int j = 0; j < pScrPriv.outputs[i].numCrtcs; j++)
                    if (pScrPriv.outputs[i].crtcs[j] == crtc)
                        reply.nPossibleOutput++;
            }
        }

        for (int i = 0; i < crtc.numOutputs; i++) {
            x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)crtc.outputs[i].id);
        }

        for (int i = 0; i < pScrPriv.numOutputs; i++) {
            if (!RROutputIsLeased(pScrPriv.outputs[i])) {
                for (int j = 0; j < pScrPriv.outputs[i].numCrtcs; j++)
                    if (pScrPriv.outputs[i].crtcs[j] == crtc) {
                        x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)pScrPriv.outputs[i].id);
                    }
            }
        }
    }

    if (pScrPriv.rrCrtcGet)
        pScrPriv.rrCrtcGet(pScreen, crtc, &reply);

    if (client.swapped) {
        swapl(&reply.timestamp);
        swaps(&reply.x);
        swaps(&reply.y);
        swaps(&reply.width);
        swaps(&reply.height);
        swapl(&reply.mode);
        swaps(&reply.rotation);
        swaps(&reply.rotations);
        swaps(&reply.nOutput);
        swaps(&reply.nPossibleOutput);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRSetCrtcConfig(ClientPtr client)
{
    mixin(REQUEST!xRRSetCrtcConfigReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetCrtcConfigReq);

    if (client.swapped) {
        swapl(&stuff.crtc);
        swapl(&stuff.timestamp);
        swapl(&stuff.configTimestamp);
        swaps(&stuff.x);
        swaps(&stuff.y);
        swapl(&stuff.mode);
        swaps(&stuff.rotation);
        mixin(SwapRestL!("stuff"));
    }

    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    RRCrtcPtr crtc = void;
    RRModePtr mode = void;
    uint numOutputs = void;
    RROutputPtr* outputs = null;
    RROutput* outputIds = void;
    TimeStamp time = void;
    Rotation rotation = void;
    int ret = void, i = void, j = void;
    CARD8 status = void;

    numOutputs = cast(uint)(client.req_len - bytes_to_int32(xRRSetCrtcConfigReq.sizeof));

    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixSetAttrAccess"));

    if (RRCrtcIsLeased(crtc))
        return BadAccess;

    if (stuff.mode == None) {
        mode = null;
        if (numOutputs > 0)
            return BadMatch;
    }
    else {
        mixin(VERIFY_RR_MODE!("stuff.mode", "mode", "DixSetAttrAccess"));
        if (numOutputs == 0)
            return BadMatch;
    }
    if (numOutputs) {
        outputs = cast(RROutputPtr*) calloc(numOutputs, RROutputPtr.sizeof);
        if (!outputs)
            return BadAlloc;
    }
    else
        outputs = null;

    outputIds = cast(RROutput*) (stuff + 1);
    for (i = 0; i < numOutputs; i++) {
        ret = dixLookupResourceByType(cast(void**) (outputs + i), outputIds[i],
                                     RROutputType, client, DixSetAttrAccess);
        if (ret != Success) {
            free(outputs);
            return ret;
        }

        if (RROutputIsLeased(outputs[i])) {
            free(outputs);
            return BadAccess;
        }

        /* validate crtc for this output */
        for (j = 0; j < outputs[i].numCrtcs; j++)
            if (outputs[i].crtcs[j] == crtc)
                break;
        if (j == outputs[i].numCrtcs) {
            free(outputs);
            return BadMatch;
        }
        /* validate mode for this output */
        for (j = 0; j < outputs[i].numModes + outputs[i].numUserModes; j++) {
            RRModePtr m = (j < outputs[i].numModes ?
                           outputs[i].modes[j] :
                           outputs[i].userModes[j - outputs[i].numModes]);
            if (m == mode)
                break;
        }
        if (j == outputs[i].numModes + outputs[i].numUserModes) {
            free(outputs);
            return BadMatch;
        }
    }
    /* validate clones */
    for (i = 0; i < numOutputs; i++) {
        for (j = 0; j < numOutputs; j++) {
            int k = void;

            if (i == j)
                continue;
            for (k = 0; k < outputs[i].numClones; k++) {
                if (outputs[i].clones[k] == outputs[j])
                    break;
            }
            if (k == outputs[i].numClones) {
                free(outputs);
                return BadMatch;
            }
        }
    }

    pScreen = crtc.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    time = ClientTimeToServerTime(stuff.timestamp);

    if (!pScrPriv) {
        time = currentTime;
        status = RRSetConfigFailed;
        goto sendReply;
    }

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
        free(outputs);
        return BadValue;
    }

    if (mode) {
        if ((~crtc.rotations) & rotation) {
            /*
             * requested rotation or reflection not supported by screen
             */
            client.errorValue = cast(uint)stuff.rotation;
            free(outputs);
            return BadMatch;
        }

static if (RANDR_12_INTERFACE) {
        /*
         * Check screen size bounds if the DDX provides a 1.2 interface
         * for setting screen size. Else, assume the CrtcSet sets
         * the size along with the mode. If the driver supports transforms,
         * then it must allow crtcs to display a subset of the screen, so
         * only do this check for drivers without transform support.
         */
        if (pScrPriv.rrScreenSetSize && !crtc.transforms) {
            int source_width = void;
            int source_height = void;
            PictTransform transform = void;
            pixman_f_transform f_transform = void, f_inverse = void;
            int width = void, height = void;

            if (pScreen.isGPU) {
                width = pScreen.current_primary.width;
                height = pScreen.current_primary.height;
            }
            else {
                width = pScreen.width;
                height = pScreen.height;
            }

            RRTransformCompute(stuff.x, stuff.y,
                               mode.mode.width, mode.mode.height,
                               rotation,
                               &crtc.client_pending_transform,
                               &transform, &f_transform, &f_inverse);

            RRModeGetScanoutSize(mode, &transform, &source_width,
                                 &source_height);
            if (stuff.x + source_width > width) {
                client.errorValue = cast(uint)stuff.x;
                free(outputs);
                return BadValue;
            }

            if (stuff.y + source_height > height) {
                client.errorValue = cast(uint)stuff.y;
                free(outputs);
                return BadValue;
            }
        }
}
    }

    if (!RRCrtcSet(crtc, mode, stuff.x, stuff.y,
                   rotation, numOutputs, outputs)) {
        status = RRSetConfigFailed;
        goto sendReply;
    }
    status = RRSetConfigSuccess;
    pScrPriv.lastSetTime = time;

 sendReply:
    free(outputs);

    xRRSetCrtcConfigReply reply = {
        status: status,
        newTimestamp: pScrPriv.lastSetTime.milliseconds
    };

    if (client.swapped) {
        swapl(&reply.newTimestamp);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcRRGetPanning(ClientPtr client)
{
    mixin(REQUEST!xRRGetPanningReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetPanningReq);

    if (client.swapped)
        swapl(&stuff.crtc);

    RRCrtcPtr crtc = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    BoxRec total = void;
    BoxRec tracking = void;
    INT16[4] border = void;

    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    /* All crtcs must be associated with screens before client
     * requests are processed
     */
    pScreen = crtc.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (!pScrPriv)
        return RRErrorBase + BadRRCrtc;

    xRRGetPanningReply reply = {
        status: RRSetConfigSuccess,
        timestamp: pScrPriv.lastSetTime.milliseconds
    };

    if (pScrPriv.rrGetPanning &&
        pScrPriv.rrGetPanning(pScreen, crtc, &total, &tracking, border.ptr)) {
        reply.left = total.x1;
        reply.top = total.y1;
        reply.width = cast(ushort)(total.x2 - total.x1);
        reply.height = cast(ushort)(total.y2 - total.y1);
        reply.track_left = tracking.x1;
        reply.track_top = tracking.y1;
        reply.track_width = cast(ushort)(tracking.x2 - tracking.x1);
        reply.track_height = cast(ushort)(tracking.y2 - tracking.y1);
        reply.border_left = border[0];
        reply.border_top = border[1];
        reply.border_right = border[2];
        reply.border_bottom = border[3];
    }

    if (client.swapped) {
        swapl(&reply.timestamp);
        swaps(&reply.left);
        swaps(&reply.top);
        swaps(&reply.width);
        swaps(&reply.height);
        swaps(&reply.track_left);
        swaps(&reply.track_top);
        swaps(&reply.track_width);
        swaps(&reply.track_height);
        swaps(&reply.border_left);
        swaps(&reply.border_top);
        swaps(&reply.border_right);
        swaps(&reply.border_bottom);
    }
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcRRSetPanning(ClientPtr client)
{
    mixin(REQUEST!xRRSetPanningReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetPanningReq);

    if (client.swapped) {
        swapl(&stuff.crtc);
        swapl(&stuff.timestamp);
        swaps(&stuff.left);
        swaps(&stuff.top);
        swaps(&stuff.width);
        swaps(&stuff.height);
        swaps(&stuff.track_left);
        swaps(&stuff.track_top);
        swaps(&stuff.track_width);
        swaps(&stuff.track_height);
        swaps(&stuff.border_left);
        swaps(&stuff.border_top);
        swaps(&stuff.border_right);
        swaps(&stuff.border_bottom);
    }

    RRCrtcPtr crtc = void;
    ScreenPtr pScreen = void;
    rrScrPrivPtr pScrPriv = void;
    TimeStamp time = void;
    BoxRec total = void;
    BoxRec tracking = void;
    INT16[4] border = void;
    CARD8 status = void;

    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    if (RRCrtcIsLeased(crtc))
        return BadAccess;

    /* All crtcs must be associated with screens before client
     * requests are processed
     */
    pScreen = crtc.pScreen;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (!pScrPriv) {
        time = currentTime;
        status = RRSetConfigFailed;
        goto sendReply;
    }

    time = ClientTimeToServerTime(stuff.timestamp);

    if (!pScrPriv.rrGetPanning)
        return RRErrorBase + BadRRCrtc;

    total.x1 = cast(short)(stuff.left);
    total.y1 = cast(short)(stuff.top);
    total.x2 = cast(short)(total.x1 + stuff.width);
    total.y2 = cast(short)(total.y1 + stuff.height);
    tracking.x1 = cast(short)(stuff.track_left);
    tracking.y1 = cast(short)(stuff.track_top);
    tracking.x2 = cast(short)(tracking.x1 + stuff.track_width);
    tracking.y2 = cast(short)(tracking.y1 + stuff.track_height);
    border[0] = stuff.border_left;
    border[1] = stuff.border_top;
    border[2] = stuff.border_right;
    border[3] = stuff.border_bottom;

    if (!pScrPriv.rrSetPanning(pScreen, crtc, &total, &tracking, border.ptr))
        return BadMatch;

    pScrPriv.lastSetTime = time;

    status = RRSetConfigSuccess;

sendReply: {}
    xRRSetPanningReply reply = {
        status: status,
        newTimestamp: pScrPriv.lastSetTime.milliseconds
    };

    if (client.swapped) {
        swapl(&reply.newTimestamp);
    }
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcRRGetCrtcGammaSize(ClientPtr client)
{
    mixin(REQUEST!xRRGetCrtcGammaSizeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetCrtcGammaSizeReq);

    if (client.swapped)
        swapl(&stuff.crtc);

    RRCrtcPtr crtc = void;

    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    /* Gamma retrieval failed, any better error? */
    if (!RRCrtcGammaGet(crtc))
        return RRErrorBase + BadRRCrtc;

    xRRGetCrtcGammaSizeReply reply = {
        size: cast(ushort)crtc.gammaSize
    };
    if (client.swapped) {
        swaps(&reply.size);
    }
    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcRRGetCrtcGamma(ClientPtr client)
{
    mixin(REQUEST!xRRGetCrtcGammaReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetCrtcGammaReq);

    if (client.swapped)
        swapl(&stuff.crtc);

    RRCrtcPtr crtc = void;
    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    /* Gamma retrieval failed, any better error? */
    if (!RRCrtcGammaGet(crtc))
        return RRErrorBase + BadRRCrtc;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    x_rpcbuf_write_CARD16s(&rpcbuf, crtc.gammaRed, crtc.gammaSize);
    x_rpcbuf_write_CARD16s(&rpcbuf, crtc.gammaGreen, crtc.gammaSize);
    x_rpcbuf_write_CARD16s(&rpcbuf, crtc.gammaBlue, crtc.gammaSize);

    xRRGetCrtcGammaReply reply = {
        size: cast(ushort)crtc.gammaSize
    };

    if (client.swapped) {
        swaps(&reply.size);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRSetCrtcGamma(ClientPtr client)
{
    mixin(REQUEST!xRRSetCrtcGammaReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetCrtcGammaReq);

    if (client.swapped) {
        swapl(&stuff.crtc);
        swaps(&stuff.size);
        mixin(SwapRestS!("stuff"));
    }

    RRCrtcPtr crtc = void;
    c_ulong len = void;
    CARD16* red = void, green = void, blue = void;

    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    if (RRCrtcIsLeased(crtc))
        return BadAccess;

    len = cast(int)(client.req_len - bytes_to_int32(xRRSetCrtcGammaReq.sizeof));
    if (len < (stuff.size * 3 + 1) >> 1)
        return BadLength;

    if (stuff.size != crtc.gammaSize)
        return BadMatch;

    red = cast(CARD16*) (stuff + 1);
    green = red + crtc.gammaSize;
    blue = green + crtc.gammaSize;

    RRCrtcGammaSet(crtc, red, green, blue);

    return Success;
}

/* Version 1.3 additions */

int ProcRRSetCrtcTransform(ClientPtr client)
{
    mixin(REQUEST!xRRSetCrtcTransformReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRSetCrtcTransformReq);

    if (client.swapped) {
        swapl(&stuff.crtc);
        SwapLongs(cast(CARD32*) &stuff.transform,
                  bytes_to_int32(xRenderTransform.sizeof));
        swaps(&stuff.nbytesFilter);
        char* filter = cast(char*) (stuff + 1);
        CARD32* params = cast(CARD32*) (filter + pad_to_int32(stuff.nbytesFilter));
        int nparams = cast(int)((cast(CARD32*)stuff + client.req_len) - params);
        if (nparams < 0)
            return BadLength;

        SwapLongs(params, nparams);
    }

    RRCrtcPtr crtc = void;
    PictTransform transform = void;
    pixman_f_transform f_transform = void, f_inverse = void;
    char* filter = void;
    int nbytes = void;
    XFixed* params = void;
    int nparams = void;

    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    if (RRCrtcIsLeased(crtc))
        return BadAccess;

    PictTransform_from_xRenderTransform(&transform, &stuff.transform);
    assumeNoGC(&pixman_f_transform_from_pixman_transform)(&f_transform, &transform);
    if (!assumeNoGC(&pixman_f_transform_invert)(&f_inverse, &f_transform))
        return BadMatch;

    filter = cast(char*) (stuff + 1);
    nbytes = stuff.nbytesFilter;
    params = cast(XFixed*) (filter + pad_to_int32(nbytes));
    nparams =  cast(int)((cast(XFixed*)stuff + client.req_len) - params);
    if (nparams < 0)
        return BadLength;

    return RRCrtcTransformSet(crtc, &transform, &f_transform, &f_inverse,
                              filter, nbytes, params, nparams);
}

int ProcRRGetCrtcTransform(ClientPtr client)
{
    mixin(REQUEST!xRRGetCrtcTransformReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetCrtcTransformReq);

    if (client.swapped)
        swapl(&stuff.crtc);

    RRCrtcPtr crtc = void;
    RRTransformPtr current = void, pending = void;

    mixin(VERIFY_RR_CRTC!("stuff.crtc", "crtc", "DixReadAccess"));

    pending = &crtc.client_pending_transform;
    current = &crtc.client_current_transform;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    xRRGetCrtcTransformReply reply = {
        hasTransforms: cast(ubyte)crtc.transforms,
    };

    xRenderTransform_from_PictTransform(&reply.pendingTransform, &pending.transform);
    xRenderTransform_from_PictTransform(&reply.currentTransform, &current.transform);

    if (pending.filter) {
        reply.pendingNbytesFilter = cast(ushort)strlen(pending.filter.name);
        reply.pendingNparamsFilter = cast(ushort)pending.nparams;
        x_rpcbuf_write_string_pad(&rpcbuf, pending.filter.name);
        x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)pending.params, pending.nparams);
    }

    if (current.filter) {
        reply.currentNbytesFilter = cast(ushort)strlen(current.filter.name);
        reply.currentNparamsFilter = cast(ushort)current.nparams;
        x_rpcbuf_write_string_pad(&rpcbuf, current.filter.name);
        x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)current.params, current.nparams);
    }

    if (client.swapped) {
        SwapLongs(cast(CARD32*) &reply.pendingTransform, bytes_to_int32(xRenderTransform.sizeof));
        SwapLongs(cast(CARD32*) &reply.currentTransform, bytes_to_int32(xRenderTransform.sizeof));
        swaps(&reply.pendingNbytesFilter);
        swaps(&reply.currentNbytesFilter);
        swaps(&reply.pendingNparamsFilter);
        swaps(&reply.currentNparamsFilter);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private Bool check_all_screen_crtcs(ScreenPtr pScreen, int* x, int* y)
{
    mixin(rrScrPriv!("pScreen"));
    int i = void;
    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];

        int left = void, right = void, top = void, bottom = void;

        if (!cursor_bounds(crtc, &left, &right, &top, &bottom))
	    continue;

        if ((*x >= left) && (*x < right) && (*y >= top) && (*y < bottom))
            return TRUE;
    }
    return FALSE;
}

private Bool constrain_all_screen_crtcs(DeviceIntPtr pDev, ScreenPtr pScreen, int* x, int* y)
{
    mixin(rrScrPriv!("pScreen"));
    int i = void;

    /* if we're trying to escape, clamp to the CRTC we're coming from */
    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];
        int nx = void, ny = void;
        int left = void, right = void, top = void, bottom = void;

        if (!cursor_bounds(crtc, &left, &right, &top, &bottom))
	    continue;

        miPointerGetPosition(pDev, &nx, &ny);

        if ((nx >= left) && (nx < right) && (ny >= top) && (ny < bottom)) {
            if (*x < left)
                *x = left;
            if (*x >= right)
                *x = right - 1;
            if (*y < top)
                *y = top;
            if (*y >= bottom)
                *y = bottom - 1;

            return TRUE;
        }
    }
    return FALSE;
}

void RRConstrainCursorHarder(DeviceIntPtr pDev, ScreenPtr pScreen, int mode, int* x, int* y)
{
    mixin(rrScrPriv!("pScreen"));
    Bool ret = void;
    ScreenPtr secondary = void;

    /* intentional dead space -> let it float */
    if (pScrPriv.discontiguous)
        return;

    /* if we're moving inside a crtc, we're fine */
    ret = check_all_screen_crtcs(pScreen, x, y);
    if (ret == TRUE)
        return;

    mixin(xorg_list_for_each_entry!("secondary", "&pScreen.secondary_list", "secondary_head", q{
        if (!secondary.is_output_secondary)
            continue;

        ret = check_all_screen_crtcs(secondary, x, y);
        if (ret == TRUE)
            return;
    }));

    /* if we're trying to escape, clamp to the CRTC we're coming from */
    ret = constrain_all_screen_crtcs(pDev, pScreen, x, y);
    if (ret == TRUE)
        return;

    mixin(xorg_list_for_each_entry!("secondary", "&pScreen.secondary_list", "secondary_head", q{
        if (!secondary.is_output_secondary)
            continue;

        ret = constrain_all_screen_crtcs(pDev, secondary, x, y);
        if (ret == TRUE)
            return;
    }));
}

Bool RRReplaceScanoutPixmap(DrawablePtr pDrawable, PixmapPtr pPixmap, Bool enable)
{
    mixin(rrScrPriv!("pDrawable.pScreen"));
    Bool ret = TRUE;
    PixmapPtr* saved_scanout_pixmap = void;
    int i = void;

    saved_scanout_pixmap = cast(PixmapPtr*) calloc(pScrPriv.numCrtcs, PixmapPtr.sizeof);
    if (saved_scanout_pixmap is null)
        return FALSE;

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];
        Bool size_fits = void;

        saved_scanout_pixmap[i] = crtc.scanout_pixmap;

        if (!crtc.mode && enable)
            continue;
        if (!crtc.scanout_pixmap && !enable)
            continue;

        /* not supported with double buffering, needs ABI change for 2 ppix */
        if (crtc.scanout_pixmap_back) {
            ret = FALSE;
            continue;
        }

        size_fits = (crtc.mode &&
                     crtc.x == pDrawable.x &&
                     crtc.y == pDrawable.y &&
                     crtc.mode.mode.width == pDrawable.width &&
                     crtc.mode.mode.height == pDrawable.height);

        /* is the pixmap already set? */
        if (crtc.scanout_pixmap == pPixmap) {
            /* if its a disable then don't care about size */
            if (enable == FALSE) {
                /* set scanout to NULL */
                crtc.scanout_pixmap = null;
            }
            else if (!size_fits) {
                /* if the size no longer fits then drop off */
                crtc.scanout_pixmap = null;
                pScrPriv.rrCrtcSetScanoutPixmap(crtc, crtc.scanout_pixmap);

                (*pScrPriv.rrCrtcSet) (pDrawable.pScreen, crtc, crtc.mode, crtc.x, crtc.y,
                                        crtc.rotation, crtc.numOutputs, crtc.outputs);
                saved_scanout_pixmap[i] = crtc.scanout_pixmap;
                ret = FALSE;
            }
            else {
                /* if the size fits then we are already setup */
            }
        }
        else {
            if (!size_fits)
                ret = FALSE;
            else if (enable)
                crtc.scanout_pixmap = pPixmap;
            else
                /* reject an attempt to disable someone else's scanout_pixmap */
                ret = FALSE;
        }
    }

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];

        if (crtc.scanout_pixmap == saved_scanout_pixmap[i])
            continue;

        if (ret) {
            pScrPriv.rrCrtcSetScanoutPixmap(crtc, crtc.scanout_pixmap);

            (*pScrPriv.rrCrtcSet) (pDrawable.pScreen, crtc, crtc.mode, crtc.x, crtc.y,
                                    crtc.rotation, crtc.numOutputs, crtc.outputs);
        }
        else
            crtc.scanout_pixmap = saved_scanout_pixmap[i];
    }
    free(saved_scanout_pixmap);

    return ret;
}

Bool RRHasScanoutPixmap(ScreenPtr pScreen)
{
    rrScrPrivPtr pScrPriv = void;
    int i = void;

    /* Bail out if RandR wasn't initialized. */
    if (!dixPrivateKeyRegistered(rrPrivKey))
        return FALSE;

    pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    if (!pScreen.is_output_secondary)
        return FALSE;

    for (i = 0; i < pScrPriv.numCrtcs; i++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[i];

        if (crtc.scanout_pixmap)
            return TRUE;
    }
    
    return FALSE;
}
