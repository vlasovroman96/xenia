module randr.rrproperty;
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

import externs.X11.Xatom;

import dix.dix_priv;
import dix.request_priv;
import randr.rrdispatch_priv;
import dix.atom;
import randr.randrstr_priv;
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
import dix.window;
import common.math;

private int DeliverPropertyEvent(WindowPtr pWin, void* value)
{
    xRROutputPropertyNotifyEvent* event = cast(xRROutputPropertyNotifyEvent*)value;
    RREventPtr* pHead = void; RREventPtr pRREvent = void;

    dixLookupResourceByType(cast(void**) &pHead, pWin.drawable.id,
                            RREventType, serverClient, DixReadAccess);
    if (!pHead)
        return WT_WALKCHILDREN;

    for (pRREvent = *pHead; pRREvent; pRREvent = pRREvent.next) {
        if (!(pRREvent.mask & RROutputPropertyNotifyMask))
            continue;

        event.window = cast(uint)pRREvent.window.drawable.id;
        WriteEventsToClient(pRREvent.client, 1, cast(xEvent*) event);
    }

    return WT_WALKCHILDREN;
}

private void RRDeliverPropertyEvent(ScreenPtr pScreen, xEvent* event)
{
    if (!(dispatchException & (DE_TERMINATE)))
        WalkTree(pScreen, &DeliverPropertyEvent, event);
}

private void RRDestroyOutputProperty(RRPropertyPtr prop)
{
    free(prop.valid_values);
    free(prop.current.data);
    free(prop.pending.data);
    free(prop);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void RRDeleteProperty(RROutputRec* output, RRPropertyRec* prop)
{
    xRROutputPropertyNotifyEvent event = {
        type: cast(ubyte)(RREventBase + RRNotify),
        subCode: RRNotify_OutputProperty,
        output: cast(ubyte)output.id,
        state: PropertyDelete,
        atom: prop.propertyName,
        timestamp: currentTime.milliseconds
    };

    RRDeliverPropertyEvent(output.pScreen, cast(xEvent*) &event);

    RRDestroyOutputProperty(prop);
}

void RRDeleteAllOutputProperties(RROutputPtr output)
{
    RRPropertyPtr prop = void, next = void;

    for (prop = output.properties; prop; prop = next) {
        next = prop.next;
        RRDeleteProperty(output, prop);
    }
}

private void RRInitOutputPropertyValue(RRPropertyValuePtr property_value)
{
    property_value.type = None;
    property_value.format = 0;
    property_value.size = 0;
    property_value.data = null;
}

private RRPropertyPtr RRCreateOutputProperty(Atom property)
{
    RRPropertyPtr prop = cast(RRPropertyRec*) calloc(1, RRPropertyRec.sizeof);
    if (!prop)
        return null;
    prop.next = null;
    prop.propertyName = cast(uint)property;
    prop.is_pending = FALSE;
    prop.range = FALSE;
    prop.immutable_ = FALSE;
    prop.num_valid = 0;
    prop.valid_values = null;
    RRInitOutputPropertyValue(&prop.current);
    RRInitOutputPropertyValue(&prop.pending);
    return prop;
}

void RRDeleteOutputProperty(RROutputPtr output, Atom property)
{
    RRPropertyRec* prop = void; RRPropertyRec** prev = void;

    for (prev = &output.properties; ((prop = *prev) !is null); prev = &(prop.next))
        if (prop.propertyName == property) {
            *prev = prop.next;
            RRDeleteProperty(output, prop);
            return;
        }
}

private void RRNoticePropertyChange(RROutputPtr output, Atom property, RRPropertyValuePtr value)
{
    const(char)* non_desktop_str = RR_PROPERTY_NON_DESKTOP;
    Atom non_desktop_prop = dixGetAtomID(non_desktop_str);

    if (property == non_desktop_prop) {
        if (value.type == XA_INTEGER && value.format == 32 && value.size >= 1) {
            uint nonDesktopData = void;
            Bool nonDesktop = void;

            memcpy(&nonDesktopData, value.data, nonDesktopData.sizeof);
            nonDesktop = nonDesktopData != 0;

            if (nonDesktop != output.nonDesktop) {
                output.nonDesktop = nonDesktop;
                RROutputChanged(output, 0);
                RRTellChanged(output.pScreen);
            }
        }
    }
}

int RRChangeOutputProperty(RROutputPtr output, Atom property, Atom type, int format, int mode, c_ulong len, const(void)* value, Bool sendevent, Bool pending)
{
    RRPropertyPtr prop = void;
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("output.pScreen"));
    int size_in_bytes = void;
    c_ulong total_len = void;
    RRPropertyValuePtr prop_value = void;
    RRPropertyValueRec new_value = void;
    Bool add = FALSE;

    size_in_bytes = format >> 3;

    /* first see if property already exists */
    prop = RRQueryOutputProperty(output, property);
    if (!prop) {                /* just add to list */
        prop = RRCreateOutputProperty(property);
        if (!prop)
            return BadAlloc;
        add = TRUE;
        mode = PropModeReplace;
    }
    if (pending && prop.is_pending)
        prop_value = &prop.pending;
    else
        prop_value = &prop.current;

    /* To append or prepend to a property the request format and type
       must match those of the already defined property.  The
       existing format and type are irrelevant when using the mode
       "PropModeReplace" since they will be written over. */

    if ((format != prop_value.format) && (mode != PropModeReplace))
        return BadMatch;
    if ((prop_value.type != type) && (mode != PropModeReplace))
        return BadMatch;
    new_value = *prop_value;
    if (mode == PropModeReplace)
        total_len = len;
    else
        total_len = prop_value.size + len;

    if (mode == PropModeReplace || len > 0) {
        void* new_data = null, old_data = null;

        new_value.data = calloc(total_len, size_in_bytes);
        if (!new_value.data && total_len && size_in_bytes) {
            if (add)
                RRDestroyOutputProperty(prop);
            return BadAlloc;
        }
        new_value.size = total_len;
        new_value.type = type;
        new_value.format = cast(short)format;

        switch (mode) {
        case PropModeReplace:
            new_data = new_value.data;
            old_data = null;
            break;
        case PropModeAppend:
            new_data = cast(void*) ((cast(char*) new_value.data) +
                                  (prop_value.size * size_in_bytes));
            old_data = new_value.data;
            break;
        case PropModePrepend:
            new_data = new_value.data;
            old_data = cast(void*) ((cast(char*) new_value.data) +
                                  (len * size_in_bytes));
            break;
        default: break;}
        if (new_data)
            memcpy(cast(char*) new_data, cast(char*) value, len * size_in_bytes);
        if (old_data)
            memcpy(cast(char*) old_data, cast(char*) prop_value.data,
                   prop_value.size * size_in_bytes);

        if (pending && pScrPriv.rrOutputSetProperty &&
            !pScrPriv.rrOutputSetProperty(output.pScreen, output,
                                           prop.propertyName, &new_value)) {
            free(new_value.data);
            if (add)
                RRDestroyOutputProperty(prop);
            return BadValue;
        }
        free(prop_value.data);
        *prop_value = new_value;
    }

    else if (len == 0) {
        /* do nothing */
    }

    if (add) {
        prop.next = output.properties;
        output.properties = prop;
    }

    if (pending && prop.is_pending)
        output.pendingProperties = TRUE;

    if (!(pending && prop.is_pending))
        RRNoticePropertyChange(output, prop.propertyName, prop_value);

    if (sendevent) {
        xRROutputPropertyNotifyEvent event = {
            type: cast(ubyte)(RREventBase + RRNotify),
            subCode: RRNotify_OutputProperty,
            output: cast(uint)output.id,
            state: PropertyNewValue,
            atom: prop.propertyName,
            timestamp: currentTime.milliseconds
        };
        RRDeliverPropertyEvent(output.pScreen, cast(xEvent*) &event);
    }
    return Success;
}

Bool RRPostPendingProperties(RROutputPtr output)
{
    RRPropertyValuePtr pending_value = void;
    RRPropertyValuePtr current_value = void;
    RRPropertyPtr property = void;
    Bool ret = TRUE;

    if (!output.pendingProperties)
        return TRUE;

    output.pendingProperties = FALSE;
    for (property = output.properties; property; property = property.next) {
        /* Skip non-pending properties */
        if (!property.is_pending)
            continue;

        pending_value = &property.pending;
        current_value = &property.current;

        /*
         * If the pending and current values are equal, don't mark it
         * as changed (which would deliver an event)
         */
        if (pending_value.type == current_value.type &&
            pending_value.format == current_value.format &&
            pending_value.size == current_value.size &&
            !memcmp(pending_value.data, current_value.data,
                    pending_value.size * (pending_value.format / 8)))
            continue;

        if (RRChangeOutputProperty(output, property.propertyName,
                                   pending_value.type, pending_value.format,
                                   PropModeReplace, pending_value.size,
                                   pending_value.data, TRUE, FALSE) != Success)
            ret = FALSE;
    }
    return ret;
}

RRPropertyPtr RRQueryOutputProperty(RROutputPtr output, Atom property)
{
    RRPropertyPtr prop = void;

    for (prop = output.properties; prop; prop = prop.next)
        if (prop.propertyName == property)
            return prop;
    return null;
}

RRPropertyValuePtr RRGetOutputProperty(RROutputPtr output, Atom property, Bool pending)
{
    RRPropertyPtr prop = RRQueryOutputProperty(output, property);
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("output.pScreen"));

    if (!prop)
        return null;
    if (pending && prop.is_pending)
        return &prop.pending;
    else {
static if (RANDR_13_INTERFACE) {
        /* If we can, try to update the property value first */
        if (pScrPriv.rrOutputGetProperty)
            pScrPriv.rrOutputGetProperty(output.pScreen, output,
                                          prop.propertyName);
}
        return &prop.current;
    }
}

int RRConfigureOutputProperty(RROutputPtr output, Atom property, Bool pending, Bool range, Bool immutable_, int num_values, const(INT32)* values)
{
    RRPropertyPtr prop = RRQueryOutputProperty(output, property);
    Bool add = FALSE;

    if (!prop) {
        prop = RRCreateOutputProperty(property);
        if (!prop)
            return BadAlloc;
        add = TRUE;
    }
    else if (prop.immutable_ && !immutable_)
        return BadAccess;

    /*
     * ranges must have even number of values
     */
    if (range && (num_values & 1)) {
        if (add)
            RRDestroyOutputProperty(prop);
        return BadMatch;
    }

    INT32* new_values = null;

    if (num_values) {
        new_values = cast(INT32*) calloc(num_values, INT32.sizeof);
        if (!new_values) {
            if (add)
                RRDestroyOutputProperty(prop);
            return BadAlloc;
        }
        memcpy(new_values, values, num_values * INT32.sizeof);
    }

    /*
     * Property moving from pending to non-pending
     * loses any pending values
     */
    if (prop.is_pending && !pending) {
        free(prop.pending.data);
        RRInitOutputPropertyValue(&prop.pending);
    }

    prop.is_pending = pending;
    prop.range = range;
    prop.immutable_ = immutable_;
    prop.num_valid = num_values;
    free(prop.valid_values);
    prop.valid_values = new_values;

    if (add) {
        prop.next = output.properties;
        output.properties = prop;
    }

    return Success;
}

int ProcRRListOutputProperties(ClientPtr client)
{
    mixin(REQUEST!xRRListOutputPropertiesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRListOutputPropertiesReq);

    if (client.swapped)
        swapl(&stuff.output);

    RROutputPtr output = void;
    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));
;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    size_t numProps = 0;
    for (RRPropertyPtr prop = output.properties; prop; prop = prop.next) {
        numProps++;
        x_rpcbuf_write_CARD32(&rpcbuf, prop.propertyName);
    }

    xRRListOutputPropertiesReply reply = {
        nAtoms: cast(ushort)numProps
    };

    if (client.swapped) {
        swaps(&reply.nAtoms);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRQueryOutputProperty(ClientPtr client)
{
    mixin(REQUEST!xRRQueryOutputPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRQueryOutputPropertyReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.property);
    }

    RROutputPtr output = void;
    RRPropertyPtr prop = void;

    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));
;

    prop = RRQueryOutputProperty(output, stuff.property);
    if (!prop)
        return BadName;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)prop.valid_values, prop.num_valid);

    xRRQueryOutputPropertyReply reply = {
        pending: cast(ubyte)prop.is_pending,
        range: cast(ubyte)prop.range,
        immutable_: cast(ubyte)prop.immutable_
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRConfigureOutputProperty(ClientPtr client)
{
    mixin(REQUEST!xRRConfigureOutputPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRConfigureOutputPropertyReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.property);
        mixin(SwapRestL!("stuff"));
    }

    RROutputPtr output = void;
    int num_valid = void;

    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));
;

    if (RROutputIsLeased(output))
        return BadAccess;

    num_valid =
        cast(int)(client.req_len - bytes_to_int32(xRRConfigureOutputPropertyReq.sizeof));
    return RRConfigureOutputProperty(output, stuff.property, stuff.pending,
                                     stuff.range, FALSE, num_valid,
                                     cast(INT32*) (stuff + 1));
}

int ProcRRChangeOutputProperty(ClientPtr client)
{
    mixin(REQUEST!xRRChangeOutputPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRChangeOutputPropertyReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.property);
        swapl(&stuff.type);
        swapl(&stuff.nUnits);
        switch (stuff.format) {
            case 8:
                break;
            case 16:
                mixin(SwapRestS!("stuff"));
                break;
            case 32:
                mixin(SwapRestL!("stuff"));
                break;
            default:
                client.errorValue = cast(uint)stuff.format;
                return BadValue;
        }
    }

    RROutputPtr output = void;
    char format = void, mode = void;
    c_ulong len = void;
    int sizeInBytes = void;
    ulong totalSize = void;
    int err = void;

    UpdateCurrentTime();
    format = stuff.format;
    mode = stuff.mode;
    if ((mode != PropModeReplace) && (mode != PropModeAppend) &&
        (mode != PropModePrepend)) {
        client.errorValue = cast(uint)mode;
        return BadValue;
    }
    if ((format != 8) && (format != 16) && (format != 32)) {
        client.errorValue = cast(uint)format;
        return BadValue;
    }
    len = stuff.nUnits;
    if (len > bytes_to_int32((0xffffffff - xChangePropertyReq.sizeof)))
        return BadLength;
    sizeInBytes = format >> 3;
    totalSize = len * sizeInBytes;
    mixin(REQUEST_FIXED_SIZE!("xRRChangeOutputPropertyReq", "totalSize"));

    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));
;

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }
    if (!ValidAtom(stuff.type)) {
        client.errorValue = cast(uint)stuff.type;
        return BadAtom;
    }

    err = RRChangeOutputProperty(output, stuff.property,
                                 stuff.type, cast(int) format,
                                 cast(int) mode, len, cast(void*) &stuff[1], TRUE,
                                 TRUE);
    if (err != Success)
        return err;
    else
        return Success;
}

int ProcRRDeleteOutputProperty(ClientPtr client)
{
    mixin(REQUEST!xRRDeleteOutputPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRDeleteOutputPropertyReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.property);
    }

    RROutputPtr output = void;
    RRPropertyPtr prop = void;

    UpdateCurrentTime();
    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));
;

    if (RROutputIsLeased(output))
        return BadAccess;

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }

    prop = RRQueryOutputProperty(output, stuff.property);
    if (!prop) {
        client.errorValue = cast(uint)stuff.property;
        return BadName;
    }

    if (prop.immutable_) {
        client.errorValue = cast(uint)stuff.property;
        return BadAccess;
    }

    RRDeleteOutputProperty(output, stuff.property);
    return Success;
}

int ProcRRGetOutputProperty(ClientPtr client)
{
    mixin(REQUEST!xRRGetOutputPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetOutputPropertyReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.property);
        swapl(&stuff.type);
        swapl(&stuff.longOffset);
        swapl(&stuff.longLength);
    }

    RRPropertyPtr prop = void; RRPropertyPtr* prev = void;
    RRPropertyValuePtr prop_value = void;
    c_ulong n = void, ind = void;
    RROutputPtr output = void;

    if (stuff.delete_)
        UpdateCurrentTime();
    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output",
                     "stuff.delete_ ? DixWriteAccess : DixReadAccess"));

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }
    if ((stuff.delete_ != xTrue) && (stuff.delete_ != xFalse)) {
        client.errorValue = cast(uint)stuff.delete_;
        return BadValue;
    }
    if ((stuff.type != AnyPropertyType) && !ValidAtom(stuff.type)) {
        client.errorValue = cast(uint)stuff.type;
        return BadAtom;
    }

    for (prev = &output.properties; ((prop = *prev) !is null); prev = &prop.next)
        if (prop.propertyName == stuff.property)
            break;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    xRRGetOutputPropertyReply reply = { 0 };

    size_t len; 
    if (!prop)
        goto sendout;

    if (prop.immutable_ && stuff.delete_)
        return BadAccess;

    prop_value = RRGetOutputProperty(output, stuff.property, stuff.pending);
    if (!prop_value)
        return BadAtom;

    /* If the request type and actual type don't match. Return the
       property information, but not the data. */

    if (((stuff.type != prop_value.type) && (stuff.type != AnyPropertyType))
        ) {
        reply.bytesAfter = cast(uint)prop_value.size;
        reply.format = cast(ubyte)prop_value.format;
        reply.propertyType = cast(uint)prop_value.type;
        goto sendout;
    }

/*
 *  Return type, format, value to client
 */
    n = (prop_value.format / 8) * prop_value.size;    /* size (bytes) of prop */
    ind = stuff.longOffset << 2;

    /* If longOffset is invalid such that it causes "len" to
       be negative, it's a value error. */

    if (n < ind) {
        client.errorValue = cast(uint)stuff.longOffset;
        return BadValue;
    }
    
    len = min(n - ind, 4 * stuff.longLength);

    reply.bytesAfter = cast(uint)(n - (ind + len));
    reply.format = cast(ubyte)prop_value.format;
    if (prop_value.format)
        reply.nItems = cast(uint)(len / (prop_value.format / 8));
    reply.propertyType = cast(uint)prop_value.type;

    if (stuff.delete_ && (reply.bytesAfter == 0)) {
        xRROutputPropertyNotifyEvent event = {
            type: cast(ubyte)(RREventBase + RRNotify),
            subCode: RRNotify_OutputProperty,
            output: cast(uint)output.id,
            state: PropertyDelete,
            atom: prop.propertyName,
            timestamp: currentTime.milliseconds
        };
        RRDeliverPropertyEvent(output.pScreen, cast(xEvent*) &event);
    }

    if (len) {
        const(char)* src = cast(char*) prop_value.data + ind;
        switch (reply.format) {
        case 32:
            x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)src, len / CARD32.sizeof);
            break;
        case 16:
            x_rpcbuf_write_CARD16s(&rpcbuf, cast(CARD16*)src, len / CARD16.sizeof);
            break;
        default:
            x_rpcbuf_write_binary_pad(&rpcbuf, src, len);
            break;
        }
    }

sendout:
    if (rpcbuf.error)
        return BadAlloc;

    if (client.swapped) {
        swapl(&reply.propertyType);
        swapl(&reply.bytesAfter);
        swapl(&reply.nItems);
    }

    if (prop && stuff.delete_ && (reply.bytesAfter == 0)) {     /* delete the Property */
        *prev = prop.next;
        RRDestroyOutputProperty(prop);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
