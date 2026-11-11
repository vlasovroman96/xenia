module randr.rrproviderproperty;
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
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import dix.atom;
import dix.swaprep;
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
    xRRProviderPropertyNotifyEvent* event = cast(xRRProviderPropertyNotifyEvent*)value;
    RREventPtr* pHead = void; RREventPtr pRREvent = void;

    dixLookupResourceByType(cast(void**) &pHead, pWin.drawable.id,
                            RREventType, serverClient, DixReadAccess);
    if (!pHead)
        return WT_WALKCHILDREN;

    for (pRREvent = *pHead; pRREvent; pRREvent = pRREvent.next) {
        if (!(pRREvent.mask & RRProviderPropertyNotifyMask))
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

private void RRDestroyProviderProperty(RRPropertyPtr prop)
{
    free(prop.valid_values);
    free(prop.current.data);
    free(prop.pending.data);
    free(prop);
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void RRDeleteProperty(RRProviderRec* provider, RRPropertyRec* prop)
{
    xRRProviderPropertyNotifyEvent event = {
        type: cast(ubyte)(RREventBase + RRNotify),
        subCode: RRNotify_ProviderProperty,
        provider: cast(uint)provider.id,
        state: PropertyDelete,
        atom: prop.propertyName,
        timestamp: currentTime.milliseconds
    };

    RRDeliverPropertyEvent(provider.pScreen, cast(xEvent*) &event);

    RRDestroyProviderProperty(prop);
}

private void RRInitProviderPropertyValue(RRPropertyValuePtr property_value)
{
    property_value.type = None;
    property_value.format = 0;
    property_value.size = 0;
    property_value.data = null;
}

private RRPropertyPtr RRCreateProviderProperty(Atom property)
{
    RRPropertyPtr prop = void;

    prop = cast(RRPropertyPtr) cast(RRPropertyRec*) calloc(1, RRPropertyRec.sizeof);
    if (!prop)
        return null;
    prop.propertyName = cast(uint)property;
    RRInitProviderPropertyValue(&prop.current);
    RRInitProviderPropertyValue(&prop.pending);
    return prop;
}

void RRDeleteProviderProperty(RRProviderPtr provider, Atom property)
{
    RRPropertyRec* prop = void; RRPropertyRec** prev = void;

    for (prev = &provider.properties; ((prop = *prev) !is null); prev = &(prop.next))
        if (prop.propertyName == property) {
            *prev = prop.next;
            RRDeleteProperty(provider, prop);
            return;
        }
}

/* shortcut for cleaning up property when failed to add */
pragma(inline, true) private void cleanupProperty(RRPropertyPtr prop, Bool added) {
    if ((prop !is null) && added)
        RRDestroyProviderProperty(prop);
}

int RRChangeProviderProperty(RRProviderPtr provider, Atom property, Atom type, int format, int mode, c_ulong len, void* value, Bool sendevent, Bool pending)
{
    RRPropertyPtr prop = void;
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("provider.pScreen"));
    int size_in_bytes = void;
    int total_size = void;
    c_ulong total_len = void;
    RRPropertyValuePtr prop_value = void;
    RRPropertyValueRec new_value = void;
    Bool add = FALSE;

    size_in_bytes = format >> 3;

    /* first see if property already exists */
    prop = RRQueryProviderProperty(provider, property);
    if (!prop) {                /* just add to list */
        prop = RRCreateProviderProperty(property);
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
        if (total_len > MAXINT / size_in_bytes) {
            cleanupProperty(prop, add);
            return BadValue;
        }
        total_size = cast(int)(total_len * size_in_bytes);
        new_value.data = calloc(1, total_size);
        if (!new_value.data && total_size) {
            cleanupProperty(prop, add);
            return BadAlloc;
        }
        new_value.size = len;
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
                                  (prop_value.size * size_in_bytes));
            break;
        default: break;}
        if (new_data)
            memcpy(cast(char*) new_data, cast(char*) value, len * size_in_bytes);
        if (old_data)
            memcpy(cast(char*) old_data, cast(char*) prop_value.data,
                   prop_value.size * size_in_bytes);

        if (pending && pScrPriv.rrProviderSetProperty &&
            !pScrPriv.rrProviderSetProperty(provider.pScreen, provider,
                                           prop.propertyName, &new_value)) {
            cleanupProperty(prop, add);
            free(new_value.data);
            return BadValue;
        }
        free(prop_value.data);
        *prop_value = new_value;
    }

    else if (len == 0) {
        /* do nothing */
    }

    if (add) {
        prop.next = provider.properties;
        provider.properties = prop;
    }

    if (pending && prop.is_pending)
        provider.pendingProperties = TRUE;

    if (sendevent) {
        xRRProviderPropertyNotifyEvent event = {
            type: cast(ubyte)(RREventBase + RRNotify),
            subCode: RRNotify_ProviderProperty,
            provider: cast(uint)provider.id,
            state: PropertyNewValue,
            atom: prop.propertyName,
            timestamp: currentTime.milliseconds
        };
        RRDeliverPropertyEvent(provider.pScreen, cast(xEvent*) &event);
    }
    return Success;
}

RRPropertyPtr RRQueryProviderProperty(RRProviderPtr provider, Atom property)
{
    RRPropertyPtr prop = void;

    for (prop = provider.properties; prop; prop = prop.next)
        if (prop.propertyName == property)
            return prop;
    return null;
}

RRPropertyValuePtr RRGetProviderProperty(RRProviderPtr provider, Atom property, Bool pending)
{
    RRPropertyPtr prop = RRQueryProviderProperty(provider, property);
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("provider.pScreen"));

    if (!prop)
        return null;
    if (pending && prop.is_pending)
        return &prop.pending;
    else {
static if (RANDR_13_INTERFACE) {
        /* If we can, try to update the property value first */
        if (pScrPriv.rrProviderGetProperty)
            pScrPriv.rrProviderGetProperty(provider.pScreen, provider,
                                          prop.propertyName);
}
        return &prop.current;
    }
}

int RRConfigureProviderProperty(RRProviderPtr provider, Atom property, Bool pending, Bool range, Bool immutable_, int num_values, INT32* values)
{
    RRPropertyPtr prop = RRQueryProviderProperty(provider, property);
    Bool add = FALSE;

    if (!prop) {
        prop = RRCreateProviderProperty(property);
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
        cleanupProperty(prop, add);
        return BadMatch;
    }

    INT32* new_values = null;
    if (num_values) {
        new_values = cast(INT32*) calloc(num_values, INT32.sizeof);
        if (!new_values) {
            cleanupProperty(prop, add);
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
        RRInitProviderPropertyValue(&prop.pending);
    }

    prop.is_pending = pending;
    prop.range = range;
    prop.immutable_ = immutable_;
    prop.num_valid = num_values;
    free(prop.valid_values);
    prop.valid_values = new_values;

    if (add) {
        prop.next = provider.properties;
        provider.properties = prop;
    }

    return Success;
}

int ProcRRListProviderProperties(ClientPtr client)
{
    mixin(REQUEST!xRRListProviderPropertiesReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRListProviderPropertiesReq);

    if (client.swapped)
        swapl(&stuff.provider);

    int numProps = 0;
    RRProviderPtr provider = void;
    RRPropertyPtr prop = void;

    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    for (prop = provider.properties; prop; prop = prop.next) {
        x_rpcbuf_write_CARD32(&rpcbuf, prop.propertyName);
        numProps++;
    }

    xRRListProviderPropertiesReply reply = {
        nAtoms: cast(ushort)numProps
    };

    if (client.swapped)
        swaps(&reply.nAtoms);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRQueryProviderProperty(ClientPtr client)
{
    mixin(REQUEST!xRRQueryProviderPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRQueryProviderPropertyReq);

    if (client.swapped) {
        swapl(&stuff.provider);
        swapl(&stuff.property);
    }

    RRProviderPtr provider = void;
    RRPropertyPtr prop = void;

    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));

    prop = RRQueryProviderProperty(provider, stuff.property);
    if (!prop)
        return BadName;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_INT32s(&rpcbuf, prop.valid_values, prop.num_valid);

    xRRQueryProviderPropertyReply reply = {
        pending: cast(ubyte)prop.is_pending,
        range: cast(ubyte)prop.range,
        immutable_: cast(ubyte)prop.immutable_
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcRRConfigureProviderProperty(ClientPtr client)
{
    mixin(REQUEST!xRRConfigureProviderPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRConfigureProviderPropertyReq);

    if (client.swapped) {
        swapl(&stuff.provider);
        swapl(&stuff.property);
        /* TODO: no way to specify format? */
        mixin(SwapRestL!("stuff"));
    }

    RRProviderPtr provider = void;
    int num_valid = void;

    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));

    num_valid =
        cast(int)(client.req_len - bytes_to_int32(xRRConfigureProviderPropertyReq.sizeof));
    return RRConfigureProviderProperty(provider, stuff.property, stuff.pending,
                                     stuff.range, FALSE, num_valid,
                                     cast(INT32*) (stuff + 1));
}

int ProcRRChangeProviderProperty(ClientPtr client)
{
    mixin(REQUEST!xRRChangeProviderPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRChangeProviderPropertyReq);

    if (client.swapped) {
        swapl(&stuff.provider);
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
        default: break;}
    }

    RRProviderPtr provider = void;
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
    mixin(REQUEST_FIXED_SIZE!("xRRChangeProviderPropertyReq", "totalSize"));

    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }
    if (!ValidAtom(stuff.type)) {
        client.errorValue = cast(uint)stuff.type;
        return BadAtom;
    }

    err = RRChangeProviderProperty(provider, stuff.property,
                                 stuff.type, cast(int) format,
                                 cast(int) mode, len, cast(void*) &stuff[1], TRUE,
                                 TRUE);
    if (err != Success)
        return err;
    else
        return Success;
}

int ProcRRDeleteProviderProperty(ClientPtr client)
{
    mixin(REQUEST!xRRDeleteProviderPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRDeleteProviderPropertyReq);

    if (client.swapped) {
        swapl(&stuff.provider);
        swapl(&stuff.property);
    }

    RRProviderPtr provider = void;
    RRPropertyPtr prop = void;

    UpdateCurrentTime();
    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider", "DixReadAccess"));

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }

    prop = RRQueryProviderProperty(provider, stuff.property);
    if (!prop) {
        client.errorValue = cast(uint)stuff.property;
        return BadName;
    }

    if (prop.immutable_) {
        client.errorValue = cast(uint)stuff.property;
        return BadAccess;
    }

    RRDeleteProviderProperty(provider, stuff.property);
    return Success;
}

int ProcRRGetProviderProperty(ClientPtr client)
{
    mixin(REQUEST!xRRGetProviderPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRGetProviderPropertyReq);

    if (client.swapped) {
        swapl(&stuff.provider);
        swapl(&stuff.property);
        swapl(&stuff.type);
        swapl(&stuff.longOffset);
        swapl(&stuff.longLength);
    }

    RRPropertyPtr prop = void; RRPropertyPtr* prev = void;
    RRPropertyValuePtr prop_value = void;
    c_ulong n = void, len = void, ind = void;
    RRProviderPtr provider = void;

    if (stuff.delete_)
        UpdateCurrentTime();
    mixin(VERIFY_RR_PROVIDER!("stuff.provider", "provider",
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

    for (prev = &provider.properties; ((prop = *prev) !is null); prev = &prop.next)
        if (prop.propertyName == stuff.property)
            break;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    xRRGetProviderPropertyReply reply = { 0 };

    if (!prop)
        goto sendout;

    if (prop.immutable_ && stuff.delete_)
        return BadAccess;

    prop_value = RRGetProviderProperty(provider, stuff.property, stuff.pending);
    if (!prop_value)
        return BadAtom;

    /* If the request type and actual type don't match. Return the
       property information, but not the data. */

    if (((stuff.type != prop_value.type) && (stuff.type != AnyPropertyType))
        ) {
        reply.bytesAfter = cast(uint)prop_value.size;
        reply.format = cast(ubyte)prop_value.format;
        reply.propertyType = cast(uint)prop_value.type;
        if (client.swapped) {
            swapl(&reply.propertyType);
            swapl(&reply.bytesAfter);
        }

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
        xRRProviderPropertyNotifyEvent event = {
            type: cast(ubyte)(RREventBase + RRNotify),
            subCode: RRNotify_ProviderProperty,
            provider: cast(uint)provider.id,
            state: PropertyDelete,
            atom: prop.propertyName,
            timestamp: currentTime.milliseconds
        };
        RRDeliverPropertyEvent(provider.pScreen, cast(xEvent*) &event);
    }

    if (client.swapped) {
        swapl(&reply.propertyType);
        swapl(&reply.bytesAfter);
        swapl(&reply.nItems);
    }

    if (len) {
        const(char)* dataptr = (cast(char*)prop_value.data) + ind;
        switch (prop_value.format) {
        case 32:
            x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)dataptr, len/CARD32.sizeof);
            break;
        case 16:
            x_rpcbuf_write_CARD16s(&rpcbuf, cast(CARD16*)dataptr, len/CARD16.sizeof);
            break;
        default:
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)dataptr, len);
            break;
        }
    }

    if (stuff.delete_ && (reply.bytesAfter == 0)) {     /* delete the Property */
        *prev = prop.next;
        RRDestroyProviderProperty(prop);
    }

sendout:
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
