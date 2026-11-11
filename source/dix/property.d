module dix.property;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

import build.xlibre_server;

import x11.X;
//import x11.Xproto;

import dix.dix_priv;
import dix.input_priv;
import dix.property_priv;
import dix.request_priv;
import dix.window_priv;
import Xext.panoramiX;
import Xext.panoramiXsrv;

import dix.property;
import dix.dixstruct_priv;
import dix.dispatch;
import dix.swaprep;
import Xext.xace;
import dix.swapreq;
import dix.events;
import dix.atom;
import dix.window;
 import common.math;

public import common.misc;
public import dix.privates;
/*
 *   PROPERTY -- property element
 */

struct _Property {
    _Property* next;
    Atom propertyName;
    Atom type;                  /* ignored by server */
    uint format;            /* format of data for swapping - 8,16,32 */
    uint size;              /* size of data in (format/8) bytes */
    void* data;                 /* private to client */
    PrivateRec* devPrivates;
}
alias PropertyRec = _Property;

/*****************************************************************
 * Property Stuff
 *
 *    dixLookupProperty, dixChangeProperty, DeleteProperty
 *
 *   Properties belong to windows.  The list of properties should not be
 *   traversed directly.  Instead, use the three functions listed above.
 *
 *****************************************************************/

version (notdef) {
private void PrintPropertys(WindowPtr pWin)
{
    PropertyPtr pProp = void;

    pProp = pWin.properties;
    while (pProp) {
        ErrorF("[dix] %x %x\n", pProp.propertyName, pProp.type);
        ErrorF("[dix] property format: %d\n", pProp.format);
        ErrorF("[dix] property data: \n");
        for (int j = 0; j < (pProp.format / 8) * pProp.size; j++)
            ErrorF("[dix] %c\n", pProp.data[j]);
        pProp = pProp.next;
    }
}
}

int dixLookupProperty(PropertyPtr* result, WindowPtr pWin, Atom propertyName, ClientPtr client, Mask access_mode)
{
    PropertyPtr pProp = void;
    int rc = BadMatch;

    client.errorValue = cast(uint)propertyName;

    for (pProp = pWin.properties; pProp; pProp = pProp.next)
        if (pProp.propertyName == propertyName)
            break;

    if (pProp)
        rc = XaceHookPropertyAccess(client, pWin, &pProp, access_mode);
    *result = pProp;
    return rc;
}

private void setVRRMode(WindowPtr pWin, WindowVRRMode mode)
{
    SetWindowVRRModeProcPtr proc = pWin.drawable.pScreen.SetWindowVRRMode;
    if (proc !is null)
        proc(pWin, mode);
}

private void notifyVRRMode(ClientPtr pClient, WindowPtr pWindow, int state, PropertyPtr pProp)
{
    const(char)* pName = NameForAtom(pProp.propertyName);
    if (pName is null || strcmp(pName, "_VARIABLE_REFRESH") || pProp.format != 32 || pProp.size != 1)
        return;

    WindowVRRMode mode = cast(WindowVRRMode)(state == PropertyNewValue ? (*(cast(uint*)pProp.data)) : 0);

static if(XINERAMA){
    if (!noPanoramiXExtension) {
        PanoramiXRes* win = void;
        int rc = void;

        rc = dixLookupResourceByType(cast(void**) &win, pWindow.drawable.id, XRT_WINDOW,
                                     pClient, DixWriteAccess);
        if (rc != Success)
            goto no_panoramix;

        mixin(XINERAMA_FOR_EACH_SCREEN_BACKWARD!(q{
            WindowPtr pWin = void;
            rc = dixLookupWindow(&pWin, win.info[walkScreenIdx].id, pClient, DixSetPropAccess);
            if (rc == Success)
                setVRRMode(pWin, mode);
        }));
    }
    return;
no_panoramix:
}
    setVRRMode(pWindow, mode);
}

// CallbackListPtr PropertyFilterCallback;

private void deliverPropertyNotifyEvent(WindowPtr pWin, int state, PropertyPtr pProp)
{
    xEvent event = void;
    UpdateCurrentTimeIf();
    // event = xEvent;
    //  (
        // u:property:window: cast(uint)pWin.drawable.id,
    //     u:property:state: state,
    //     u:property:atom: pProp.propertyName,
    //     u:property:time: currentTime.milliseconds,
    // );

        event.u.property.window = cast(uint)pWin.drawable.id;
        event.u.property.state = cast(ubyte)state;
        event.u.property.atom = pProp.propertyName;
        event.u.property.time = currentTime.milliseconds;
        event.u.u.type = PropertyNotify;

    DeliverEvents(pWin, &event, 1, cast(WindowPtr) null);
}

int ProcRotateProperties(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xRotatePropertiesReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD16!"nAtoms");
    mixin(X_REQUEST_FIELD_CARD16!"nPositions");
    mixin(X_REQUEST_REST_CARD32!());

    int delta = void, rc = void;
    PropertyPtr* props = void;         /* array of pointer */
    PropertyPtr pProp = void, saved = void;

    mixin(REQUEST_FIXED_SIZE!("xRotatePropertiesReq", "stuff.nAtoms << 2"));
    UpdateCurrentTime();

    PropertyFilterParam p = {
        client: client,
        window: stuff.window,
        access_mode: DixWriteAccess,
        atoms: cast(Atom*) &stuff[1],
        nAtoms: stuff.nAtoms,
        nPositions: stuff.nPositions,
    };

    CallCallbacks(&PropertyFilterCallback, &p);
    if (p.skip)
        return p.status;

    WindowPtr pWin = void;
    rc = dixLookupWindow(&pWin, p.window, p.client, DixSetPropAccess);
    if (rc != Success || stuff.nAtoms <= 0)
        return rc;

    props = cast(PropertyPtr*) calloc(p.nAtoms, PropertyPtr.sizeof);
    saved = cast(_Property*)calloc(p.nAtoms, PropertyRec.sizeof);
    if (!props || !saved) {
        rc = BadAlloc;
        goto out_;
    }

    for (int i = 0; i < p.nAtoms; i++) {
        if (!ValidAtom(p.atoms[i])) {
            rc = BadAtom;
            client.errorValue = cast(uint)p.atoms[i];
            goto out_;
        }
        for (int j = i + 1; j < p.nAtoms; j++)
            if (p.atoms[j] == p.atoms[i]) {
                rc = BadMatch;
                goto out_;
            }

        rc = dixLookupProperty(&pProp, pWin, p.atoms[i], p.client,
                               DixReadAccess | DixWriteAccess);

        if (rc != Success)
            goto out_;

        props[i] = pProp;
        saved[i] = *pProp;
    }
    delta = cast(int)p.nPositions;

    /* If the rotation is a complete 360 degrees, then moving the properties
       around and generating PropertyNotify events should be skipped. */

    if (abs(delta) % p.nAtoms) {
        while (delta < 0)       /* faster if abs value is small */
            delta += p.nAtoms;
        for (int i = 0; i < p.nAtoms; i++) {
            int j = cast(int)((i + delta) % p.nAtoms);
            deliverPropertyNotifyEvent(pWin, PropertyNewValue, props[i]);
            notifyVRRMode(client, pWin, PropertyNewValue, props[i]);

            /* Preserve name and devPrivates */
            props[j].type = saved[i].type;
            props[j].format = saved[i].format;
            props[j].size = saved[i].size;
            props[j].data = saved[i].data;
        }
    }
 out_:
    free(saved);
    free(props);
    return rc;
}

int ProcChangeProperty(ClientPtr client)
{
    mixin(REQUEST!xChangePropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xChangePropertyReq);

    if (client.swapped) {
        swapl(&stuff.window);
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

    char format = void, mode = void;
    c_ulong len = void;
    int sizeInBytes = void, err = void;
    ulong totalSize = void;

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
    if (len > bytes_to_int32(0xffffffff - xChangePropertyReq.sizeof))
        return BadLength;
    sizeInBytes = format >> 3;
    totalSize = len * sizeInBytes;
    mixin(REQUEST_FIXED_SIZE!("xChangePropertyReq", "totalSize"));

    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }
    if (!ValidAtom(stuff.type)) {
        client.errorValue = cast(uint)stuff.type;
        return BadAtom;
    }

    PropertyFilterParam p = {
        client: client,
        window: stuff.window,
        property: stuff.property,
        type: stuff.type,
        format: format,
        mode: mode,
        len: len,
        value: &stuff[1],
        sendevent: TRUE,
        access_mode: DixWriteAccess,
    };

    CallCallbacks(&PropertyFilterCallback, &p);
    if (p.skip)
        return p.status;

    WindowPtr pWin = void;
    err = dixLookupWindow(&pWin, p.window, p.client, DixSetPropAccess);
    if (err != Success)
        return err;

    return dixChangeWindowProperty(p.client, pWin, p.property, p.type, p.format,
                                   p.mode, p.len, p.value, p.sendevent);
}

int dixChangeWindowProperty(ClientPtr pClient, WindowPtr pWin, Atom property, Atom type, int format, int mode, c_ulong len, const(void)* value, Bool sendevent)
{
    PropertyPtr pProp = void;
    PropertyRec savedProp = void;
    int sizeInBytes = void, totalSize = void, rc = void;
    Mask access_mode = void;

    sizeInBytes = format >> 3;
    totalSize = cast(int)(len * sizeInBytes);
    access_mode = (mode == PropModeReplace) ? DixWriteAccess : DixBlendAccess;

    /* first see if property already exists */
    rc = dixLookupProperty(&pProp, pWin, property, pClient, access_mode);

    if (rc == BadMatch) {       /* just add to list */
        if (!MakeWindowOptional(pWin))
            return BadAlloc;
        pProp = mixin(dixAllocateObjectWithPrivates!("PropertyRec", "PRIVATE_PROPERTY"));
        if (!pProp)
            return BadAlloc;
        ubyte* data = cast(ubyte*) calloc(1, totalSize);
        if (totalSize) {
            if (!data) {
                mixin(dixFreeObjectWithPrivatesM!("pProp", "PRIVATE_PROPERTY"));
                return BadAlloc;
            }
            memcpy(data, value, totalSize);
        }
        pProp.propertyName = cast(uint)property;
        pProp.type = cast(uint)type;
        pProp.format = format;
        pProp.data = data;
        pProp.size = cast(uint)len;
        rc = XaceHookPropertyAccess(pClient, pWin, &pProp,
                                    DixCreateAccess | DixWriteAccess);
        if (rc != Success) {
            free(data);
            mixin(dixFreeObjectWithPrivatesM!("pProp", "PRIVATE_PROPERTY"));
            pClient.errorValue = property;
            return rc;
        }
        pProp.next = pWin.properties;
        pWin.properties = pProp;
    }
    else if (rc == Success) {
        /* To append or prepend to a property the request format and type
           must match those of the already defined property.  The
           existing format and type are irrelevant when using the mode
           "PropModeReplace" since they will be written over. */

        if ((format != pProp.format) && (mode != PropModeReplace))
            return BadMatch;
        if ((pProp.type != type) && (mode != PropModeReplace))
            return BadMatch;

        /* save the old values for later */
        savedProp = *pProp;

        if (mode == PropModeReplace) {
            ubyte* data = cast(ubyte*) calloc(1, totalSize);
            if (totalSize) {
                if (!data)
                    return BadAlloc;
                memcpy(data, value, totalSize);
            }
            pProp.data = data;
            pProp.size = cast(uint)len;
            pProp.type = cast(uint)type;
            pProp.format = format;
        }
        else if (len == 0) {
            /* do nothing */
        }
        else if (mode == PropModeAppend) {
            ubyte* data = cast(ubyte*) calloc(pProp.size + len, sizeInBytes);
            if (!data)
                return BadAlloc;
            memcpy(data, pProp.data, pProp.size * sizeInBytes);
            memcpy(data + pProp.size * sizeInBytes, value, totalSize);
            pProp.data = data;
            pProp.size += len;
        }
        else if (mode == PropModePrepend) {
            ubyte* data = cast(ubyte*) calloc(len + pProp.size, sizeInBytes);
            if (!data)
                return BadAlloc;
            memcpy(data + totalSize, pProp.data, pProp.size * sizeInBytes);
            memcpy(data, value, totalSize);
            pProp.data = data;
            pProp.size += len;
        }

        /* Allow security modules to check the new content */
        access_mode |= DixPostAccess;
        rc = XaceHookPropertyAccess(pClient, pWin, &pProp, access_mode);
        if (rc == Success) {
            if (savedProp.data != pProp.data)
                free(savedProp.data);
        }
        else {
            if (savedProp.data != pProp.data)
                free(pProp.data);
            *pProp = savedProp;
            return rc;
        }
    }
    else
        return rc;

    if (sendevent) {
        deliverPropertyNotifyEvent(pWin, PropertyNewValue, pProp);
        notifyVRRMode(pClient, pWin, PropertyNewValue, pProp);
    }

    return Success;
}

int DeleteProperty(ClientPtr client, WindowPtr pWin, Atom propName)
{
    PropertyPtr pProp = void, prevProp = void;
    int rc = void;

    rc = dixLookupProperty(&pProp, pWin, propName, client, DixDestroyAccess);
    if (rc == BadMatch)
        return Success;         /* Succeed if property does not exist */

    if (rc == Success) {
        if (pWin.properties == pProp) {
            /* Takes care of head */
            if (((pWin.properties = pProp.next) is null))
                CheckWindowOptionalNeed(pWin);
        }
        else {
            /* Need to traverse to find the previous element */
            prevProp = pWin.properties;
            while (prevProp.next != pProp)
                prevProp = prevProp.next;
            prevProp.next = pProp.next;
        }

        deliverPropertyNotifyEvent(pWin, PropertyDelete, pProp);
        notifyVRRMode(client, pWin, PropertyDelete, pProp);
        free(pProp.data);
        mixin(dixFreeObjectWithPrivatesM!("pProp", "PRIVATE_PROPERTY"));
    }
    return rc;
}

void DeleteAllWindowProperties(WindowPtr pWin)
{
    PropertyPtr pProp = pWin.properties;

    while (pProp) {
        deliverPropertyNotifyEvent(pWin, PropertyDelete, pProp);
        PropertyPtr pNextProp = pProp.next;
        free(pProp.data);
        mixin(dixFreeObjectWithPrivatesM!("pProp", "PRIVATE_PROPERTY"));
        pProp = pNextProp;
    }

    pWin.properties = null;
}

/*****************
 * GetProperty
 *    If type Any is specified, returns the property from the specified
 *    window regardless of its type.  If a type is specified, returns the
 *    property only if its type equals the specified type.
 *    If delete is True and a property is returned, the property is also
 *    deleted from the window and a PropertyNotify event is generated on the
 *    window.
 *****************/

int ProcGetProperty(ClientPtr client)
{
    mixin(REQUEST!xGetPropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xGetPropertyReq);

    if (client.swapped) {
        swapl(&stuff.window);
        swapl(&stuff.property);
        swapl(&stuff.type);
        swapl(&stuff.longOffset);
        swapl(&stuff.longLength);
    }

    PropertyPtr pProp = void, prevProp = void;
    c_ulong n = void, len = void, ind = void;
    int rc = void;
    Mask win_mode = DixGetPropAccess, prop_mode = DixReadAccess;

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

    PropertyFilterParam p = {
        client: client,
        window: stuff.window,
        property: stuff.property,
        type: stuff.type,
        delete_: stuff.delete_,
        access_mode: prop_mode,
        longOffset: stuff.longOffset,
        longLength: stuff.longLength,
    };

    CallCallbacks(&PropertyFilterCallback, &p);
    if (p.skip)
        return p.status;

    if (p.delete_) {
        UpdateCurrentTime();
        win_mode |= DixSetPropAccess;
        prop_mode |= DixDestroyAccess;
    }

    WindowPtr pWin = void;
    rc = dixLookupWindow(&pWin, p.window, p.client, win_mode);
    if (rc != Success)
        return rc;

    rc = dixLookupProperty(&pProp, pWin, p.property, p.client, prop_mode);
    if (rc == BadMatch) {
        xGetPropertyReply reply = { 0 };
        return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
    }
    else if (rc != Success)
        return rc;

    /* If the request type and actual type don't match. Return the
       property information, but not the data. */

    if (((p.type != pProp.type) && (p.type != AnyPropertyType))) {
        xGetPropertyReply reply = {
            bytesAfter: pProp.size,
            format: cast(ubyte)pProp.format,
            propertyType: pProp.type
        };
        if (client.swapped) {
            swapl(&reply.propertyType);
            swapl(&reply.bytesAfter);
        }
        return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
    }

/*
 *  Return type, format, value to client
 */
    n = (pProp.format / 8) * pProp.size;      /* size (bytes) of prop */
    ind = p.longOffset << 2;

    /* If longOffset is invalid such that it causes "len" to
       be negative, it's a value error. */

    if (n < ind) {
        client.errorValue = cast(uint)p.longOffset;
        return BadValue;
    }

    len = min(n - ind, 4 * p.longLength);

    xGetPropertyReply reply = {
        bytesAfter: cast(uint)(n - (ind + len)),
        format: cast(ubyte)pProp.format,
        nItems: cast(uint)(len / (pProp.format / 8)),
        propertyType: pProp.type
    };

    if (p.delete_ && (reply.bytesAfter == 0)) {
        deliverPropertyNotifyEvent(pWin, PropertyDelete, pProp);
        notifyVRRMode(client, pWin, PropertyDelete, pProp);
    }

    const(char)* dataptr = (cast(char*)pProp.data) + ind;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    switch (pProp.format) {
        case 32:
            x_rpcbuf_write_CARD32s(&rpcbuf, cast(CARD32*)dataptr, len / 4);
        break;
        case 16:
            x_rpcbuf_write_CARD16s(&rpcbuf, cast(CARD16*)dataptr, len / 2);
        break;
        default:
            x_rpcbuf_write_CARD8s(&rpcbuf, cast(CARD8*)dataptr, len);
        break;
    }

    /* don't delete if there's an error */
    if (rpcbuf.error)
        return BadAlloc;

    if (p.delete_ && (reply.bytesAfter == 0)) {
        /* Delete the Property */
        if (pWin.properties == pProp) {
            /* Takes care of head */
            if (((pWin.properties = pProp.next) is null))
                CheckWindowOptionalNeed(pWin);
        }
        else {
            /* Need to traverse to find the previous element */
            prevProp = pWin.properties;
            while (prevProp.next != pProp)
                prevProp = prevProp.next;
            prevProp.next = pProp.next;
        }

        free(pProp.data);
        mixin(dixFreeObjectWithPrivatesM!("pProp", "PRIVATE_PROPERTY"));
    }

    if (client.swapped) {
        swapl(&reply.propertyType);
        swapl(&reply.bytesAfter);
        swapl(&reply.nItems);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcListProperties(ClientPtr client)
{
    WindowPtr pWin = void;

    mixin(REQUEST!xResourceReq);
    mixin(REQUEST_AT_LEAST_SIZE!xResourceReq);

    if (client.swapped)
        swapl(&stuff.id);

    int rc = dixLookupWindow(&pWin, stuff.id, client, DixListPropAccess);
    if (rc != Success)
        return rc;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    size_t numProps = 0;
    for (PropertyPtr realProp = void, pProp = pWin.properties; pProp; pProp = pProp.next) {
        realProp = pProp;
        rc = XaceHookPropertyAccess(client, pWin, &realProp, DixGetAttrAccess);
        if (rc == Success && realProp == pProp) {
            x_rpcbuf_write_CARD32(&rpcbuf, pProp.propertyName);
            numProps++;
        }
    }

    xListPropertiesReply reply = {
        nProperties: cast(ushort)numProps
    };

    if (client.swapped) {
        swaps(&reply.nProperties);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int ProcDeleteProperty(ClientPtr client)
{
    mixin(REQUEST!xDeletePropertyReq);
    mixin(REQUEST_AT_LEAST_SIZE!xDeletePropertyReq);

    if (client.swapped) {
        swapl(&stuff.window);
        swapl(&stuff.property);
    }

    UpdateCurrentTime();
    if (!ValidAtom(stuff.property)) {
        client.errorValue = cast(uint)stuff.property;
        return BadAtom;
    }

    PropertyFilterParam p = {
        client: client,
        window: stuff.window,
        property: stuff.property,
        access_mode: DixRemoveAccess,
    };

    CallCallbacks(&PropertyFilterCallback, &p);
    if (p.skip)
        return p.status;

    WindowPtr pWin = void;
    int result = dixLookupWindow(&pWin, p.window, p.client, DixSetPropAccess);
    if (result != Success)
        return result;

    return DeleteProperty(p.client, pWin, p.property);
}
