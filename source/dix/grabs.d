module grabs;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts,

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
WHETHER IN AN action OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

*/

import build.dix_config;

//import x11.X;
//import x11.Xproto;
//import externs.X11.extensions.XI2;

import dix.cursor_priv;
import dix.devices_priv;
import dix.dix_priv;
import dix.dixgrabs_priv;
import dix.exevents_priv;
import dix.inpututils_priv;
import dix.resource_priv;
import dix.window_priv;
import os.auth;
import os.client_priv;

import include.misc;
import include.windowstr;
import include.inputstr;
import dix.cursor;
import Xi.exglobals;
import os.log;
import os.access;
import dix.events;
import os.auth;
import dix.dispatch;
import dix.inpututils;


enum MasksPerDetailMask = 8;    /* 256 keycodes and 256 possible;
                                   modifier combinations; modifier MASKWORD(buf, i); */
// enum string BITCLEAR(string buf, string i) = mixin(MASKWORD!(buf,i)) ~`&=` ~ mixin(BITMASK!(i));
// enum string GETBIT(string buf, string i) = `(MASKWORD(` ~ buf ~ `, ` ~ i ~ `) & BITMASK(` ~ i ~ `))`;

void PrintDeviceGrabInfo(DeviceIntPtr dev)
{
    LocalClientCredRec* lcc = void;
    GrabInfoPtr devGrab = &dev.deviceGrab;
    GrabPtr grab = devGrab.grab;
    Bool clientIdPrinted = FALSE;

    ErrorF("Active grab 0x%lx (%s) on device '%s' (%d):\n",
           cast(c_ulong) grab.resource,
           (grab.grabtype == XI2) ? "xi2".ptr :
           ((grab.grabtype == CORE) ? "core".ptr : "xi1".ptr), dev.name, dev.id);

    ClientPtr client = dixClientForXID(grab.resource);
    if (client) {
        pid_t clientpid = GetClientPid(client);
        const(char)* cmdname = GetClientCmdName(client);
        const(char)* cmdargs = GetClientCmdArgs(client);

        if ((clientpid > 0) && (cmdname !is null)) {
            ErrorF("      client pid %ld %s %s\n",
                   cast(c_long) clientpid, cmdname, cmdargs ? cmdargs : "");
            clientIdPrinted = TRUE;
        }
        else if (GetLocalClientCreds(client, &lcc) != -1) {
            ErrorF("      client pid %ld uid %ld gid %ld\n",
                   (lcc.fieldsSet & LCC_PID_SET) ? cast(c_long) lcc.pid : 0,
                   (lcc.fieldsSet & LCC_UID_SET) ? cast(c_long) lcc.euid : 0,
                   (lcc.fieldsSet & LCC_GID_SET) ? cast(c_long) lcc.egid : 0);
            FreeLocalClientCreds(lcc);
            clientIdPrinted = TRUE;
        }
    }
    if (!clientIdPrinted) {
        ErrorF("      (no client information available for client %d)\n",
               dixClientIdForXID(grab.resource));
    }

    /* XXX is this even correct? */
    if (devGrab.sync.other)
        ErrorF("      grab ID 0x%lx from paired device\n",
               cast(c_ulong) devGrab.sync.other.resource);

    ErrorF("      at %ld (from %s grab)%s (device %s, state %d)\n",
           cast(c_ulong) devGrab.grabTime.milliseconds,
           devGrab.fromPassiveGrab ? "passive".ptr : "active".ptr,
           devGrab.implicitGrab ? " (implicit)".ptr : "".ptr,
           devGrab.sync.frozen ? "frozen".ptr : "thawed".ptr, devGrab.sync.state);

    if (grab.grabtype == CORE) {
        ErrorF("        core event mask 0x%lx\n".ptr,
               cast(c_ulong) grab.eventMask);
    }
    else if (grab.grabtype == XI) {
        ErrorF("      xi1 event mask 0x%lx\n".ptr,
               devGrab.implicitGrab ? cast(c_ulong) grab.deviceMask :
               cast(c_ulong) grab.eventMask);
    }
    else if (grab.grabtype == XI2) {
        for (int i = 0; i < xi2mask_num_masks(grab.xi2mask); i++) {
            const(ubyte)* mask = void;
            int print = void;

            print = 0;
            for (int j = 0; j < XI2MASKSIZE; j++) {
                mask = xi2mask_get_one_mask(grab.xi2mask, i);
                if (mask[j]) {
                    print = 1;
                    break;
                }
            }
            if (!print)
                continue;
            ErrorF("      xi2 event mask for device %d: 0x".ptr, dev.id);
            for (int j = 0; j < xi2mask_mask_size(grab.xi2mask); j++)
                ErrorF("%x".ptr, mask[j]);
            ErrorF("\n".ptr);
        }
    }

    if (devGrab.fromPassiveGrab) {
        ErrorF("      passive grab type %d, detail 0x%x, ".ptr,
               "activating key %d\n".ptr, grab.type, grab.detail.exact,
               devGrab.activatingKey);
    }

    ErrorF("      owner-events %s, kb %d ptr %d, confine %lx, cursor 0x%lx\n".ptr,
           grab.ownerEvents ? "true".ptr : "false".ptr,
           grab.keyboardMode, grab.pointerMode,
           grab.confineTo ? cast(c_ulong) grab.confineTo.drawable.id : 0,
           grab.cursor ? cast(c_ulong) grab.cursor.id : 0);
}

void UngrabAllDevices(Bool kill_client)
{
    ErrorF("Ungrabbing all devices%s; grabs listed below:\n".ptr,
           kill_client ? " and killing their owners".ptr : "".ptr);

    for (DeviceIntPtr dev = inputInfo.devices; dev; dev = dev.next) {
        if (!dev.deviceGrab.grab)
            continue;
        PrintDeviceGrabInfo(dev);
        ClientPtr client = dixClientForXID(dev.deviceGrab.grab.resource);
        if (!kill_client || !client || client.clientGone)
            dev.deviceGrab.DeactivateGrab(dev);
        if (kill_client)
            CloseDownClient(client);
    }

    ErrorF("End list of ungrabbed devices\n");
}



GrabPtr AllocGrab(GrabPtr src)
{
    GrabPtr grab = cast(GrabRec*) calloc(1, GrabRec.sizeof);

    if (grab) {
        grab.xi2mask = xi2mask_new();
        if (!grab.xi2mask) {
            free(grab);
            grab = null;
        }
        else if (src && !CopyGrab(grab, src)) {
            free(grab.xi2mask);
            free(grab);
            grab = null;
        }
    }

    return grab;
}

GrabPtr CreateGrab(ClientPtr client, DeviceIntPtr device, DeviceIntPtr modDevice, WindowPtr window, InputLevel grabtype, GrabMask* mask, GrabParameters* param, int eventType, KeyCode keybut, WindowPtr confineTo, CursorPtr cursor)
{
    GrabPtr grab = void;

    grab = AllocGrab(null);
    if (!grab)
        return cast(GrabPtr) null;
    grab.resource = FakeClientID(client.index);
    grab.device = device;
    grab.window = window;
    if (grabtype == CORE || grabtype == XI)
        grab.eventMask = mask.core;       /* same for XI */
    else
        grab.eventMask = 0;
    grab.deviceMask = 0;
    grab.ownerEvents = param.ownerEvents;
    grab.keyboardMode = param.this_device_mode;
    grab.pointerMode = param.other_devices_mode;
    grab.modifiersDetail.exact = param.modifiers;
    grab.modifiersDetail.pMask = null;
    grab.modifierDevice = modDevice;
    grab.type = cast(ubyte)eventType;
    grab.grabtype = grabtype;
    grab.detail.exact = keybut;
    grab.detail.pMask = null;
    grab.confineTo = confineTo;
    grab.cursor = RefCursor(cursor);
    grab.next = null;

    if (grabtype == XI2)
        xi2mask_merge(grab.xi2mask, mask.xi2mask);
    return grab;
}

void FreeGrab(GrabPtr pGrab)
{
    if (!pGrab)
        return;

    free(pGrab.modifiersDetail.pMask);
    free(pGrab.detail.pMask);
    FreeCursor(pGrab.cursor, cast(Cursor) 0);

    xi2mask_free(&pGrab.xi2mask);
    free(pGrab);
}

private Bool CopyGrab(GrabPtr dst, GrabPtr src)
{
    Mask* mdetails_mask = null;
    Mask* details_mask = null;
    XI2Mask* xi2mask = void;

    if (src.modifiersDetail.pMask) {
        int len = MasksPerDetailMask * Mask.sizeof;

        mdetails_mask = cast(Mask*) calloc(1, len);
        if (!mdetails_mask)
            return FALSE;
        memcpy(mdetails_mask, src.modifiersDetail.pMask, len);
    }

    if (src.detail.pMask) {
        int len = MasksPerDetailMask * Mask.sizeof;

        details_mask = cast(Mask*) calloc(1, len);
        if (!details_mask) {
            free(mdetails_mask);
            return FALSE;
        }
        memcpy(details_mask, src.detail.pMask, len);
    }

    if (!dst.xi2mask) {
        xi2mask = xi2mask_new();
        if (!xi2mask) {
            free(mdetails_mask);
            free(details_mask);
            return FALSE;
        }
    }
    else {
        xi2mask = dst.xi2mask;
        xi2mask_zero(xi2mask, -1);
    }

    *dst = *src;
    dst.modifiersDetail.pMask = mdetails_mask;
    dst.detail.pMask = details_mask;
    dst.xi2mask = xi2mask;
    dst.cursor = RefCursor(src.cursor);

    xi2mask_merge(dst.xi2mask, src.xi2mask);

    return TRUE;
}

int DeletePassiveGrab(void* value, XID id)
{
    GrabPtr pGrab = cast(GrabPtr) value;

    /* it is OK if the grab isn't found */
    for (GrabPtr g = (mixin(wPassiveGrabs!("pGrab.window"))), prev = null; g; g = g.next) {
        if (pGrab == g) {
            if (prev)
                prev.next = g.next;
            else if (((pGrab.window.optional.passiveGrabs = g.next) is null))
                CheckWindowOptionalNeed(pGrab.window);
            break;
        }
        prev = g;
    }
    FreeGrab(pGrab);
    return Success;
}

private Mask* DeleteDetailFromMask(Mask* pDetailMask, uint detail)
{
    Mask* mask = cast(Mask*) calloc(MasksPerDetailMask, Mask.sizeof);
    if (mask) {
        if (pDetailMask)
            for (int i = 0; i < MasksPerDetailMask; i++)
                mask[i] = pDetailMask[i];
        else
            for (int i = 0; i < MasksPerDetailMask; i++)
                mask[i] = cast(uint)~0L;
        mixin(BITCLEAR!(`mask`, `detail`));
    }
    return mask;
}

private Bool IsInGrabMask(DetailRec firstDetail, DetailRec secondDetail, uint exception)
{
    if (firstDetail.exact == exception) {
        if (firstDetail.pMask is null)
            return TRUE;

        /* (at present) never called with two non-null pMasks */
        if (secondDetail.exact == exception)
            return FALSE;

        if (mixin(GETBIT!(`firstDetail.pMask`, `secondDetail.exact`)))
            return TRUE;
    }

    return FALSE;
}

private Bool IdenticalExactDetails(uint firstExact, uint secondExact, uint exception)
{
    if ((firstExact == exception) || (secondExact == exception))
        return FALSE;

    if (firstExact == secondExact)
        return TRUE;

    return FALSE;
}

private Bool DetailSupersedesSecond(DetailRec firstDetail, DetailRec secondDetail, uint exception)
{
    if (IsInGrabMask(firstDetail, secondDetail, exception))
        return TRUE;

    if (IdenticalExactDetails(firstDetail.exact, secondDetail.exact, exception))
        return TRUE;

    return FALSE;
}

private Bool GrabSupersedesSecond(GrabPtr pFirstGrab, GrabPtr pSecondGrab)
{
    uint any_modifier = (pFirstGrab.grabtype == XI2) ?
        cast(uint) XIAnyModifier : cast(uint) AnyModifier;
    if (!DetailSupersedesSecond(pFirstGrab.modifiersDetail,
                                pSecondGrab.modifiersDetail, any_modifier))
        return FALSE;

    if (DetailSupersedesSecond(pFirstGrab.detail,
                               pSecondGrab.detail, cast(uint) AnyKey))
        return TRUE;

    return FALSE;
}

/**
 * Compares two grabs and returns TRUE if the first grab matches the second
 * grab.
 *
 * A match is when
 *  - the devices set for the grab are equal (this is optional).
 *  - the event types for both grabs are equal.
 *  - XXX
 *
 * @param ignoreDevice TRUE if the device settings on the grabs are to be
 * ignored.
 * @return TRUE if the grabs match or FALSE otherwise.
 */
Bool GrabMatchesSecond(GrabPtr pFirstGrab, GrabPtr pSecondGrab, Bool ignoreDevice)
{
    uint any_modifier = (pFirstGrab.grabtype == XI2) ?
        cast(uint) XIAnyModifier : cast(uint) AnyModifier;

    if (pFirstGrab.grabtype != pSecondGrab.grabtype)
        return FALSE;

    if (pFirstGrab.grabtype == XI2) {
        if (pFirstGrab.device == inputInfo.all_devices ||
            pSecondGrab.device == inputInfo.all_devices) {
            /* do nothing */
        }
        else if (pFirstGrab.device == inputInfo.all_master_devices) {
            if (pSecondGrab.device != inputInfo.all_master_devices &&
                !InputDevIsMaster(pSecondGrab.device))
                return FALSE;
        }
        else if (pSecondGrab.device == inputInfo.all_master_devices) {
            if (pFirstGrab.device != inputInfo.all_master_devices &&
                !InputDevIsMaster(pFirstGrab.device))
                return FALSE;
        }
        else if (pSecondGrab.device != pFirstGrab.device)
            return FALSE;
    }
    else if (!ignoreDevice &&
             ((pFirstGrab.device != pSecondGrab.device) ||
              (pFirstGrab.modifierDevice != pSecondGrab.modifierDevice)))
        return FALSE;

    if (pFirstGrab.type != pSecondGrab.type)
        return FALSE;

    if (GrabSupersedesSecond(pFirstGrab, pSecondGrab) ||
        GrabSupersedesSecond(pSecondGrab, pFirstGrab))
        return TRUE;

    if (DetailSupersedesSecond(pSecondGrab.detail, pFirstGrab.detail,
                               cast(uint) AnyKey)
        &&
        DetailSupersedesSecond(pFirstGrab.modifiersDetail,
                               pSecondGrab.modifiersDetail, any_modifier))
        return TRUE;

    if (DetailSupersedesSecond(pFirstGrab.detail, pSecondGrab.detail,
                               cast(uint) AnyKey)
        &&
        DetailSupersedesSecond(pSecondGrab.modifiersDetail,
                               pFirstGrab.modifiersDetail, any_modifier))
        return TRUE;

    return FALSE;
}

private Bool GrabsAreIdentical(GrabPtr pFirstGrab, GrabPtr pSecondGrab)
{
    uint any_modifier = (pFirstGrab.grabtype == XI2) ?
        cast(uint) XIAnyModifier : cast(uint) AnyModifier;

    if (pFirstGrab.grabtype != pSecondGrab.grabtype)
        return FALSE;

    if (pFirstGrab.device != pSecondGrab.device ||
        (pFirstGrab.modifierDevice != pSecondGrab.modifierDevice) ||
        (pFirstGrab.type != pSecondGrab.type))
        return FALSE;

    if (!(DetailSupersedesSecond(pFirstGrab.detail,
                                 pSecondGrab.detail,
                                 cast(uint) AnyKey) &&
          DetailSupersedesSecond(pSecondGrab.detail,
                                 pFirstGrab.detail, cast(uint) AnyKey)))
        return FALSE;

    if (!(DetailSupersedesSecond(pFirstGrab.modifiersDetail,
                                 pSecondGrab.modifiersDetail,
                                 any_modifier) &&
          DetailSupersedesSecond(pSecondGrab.modifiersDetail,
                                 pFirstGrab.modifiersDetail, any_modifier)))
        return FALSE;

    return TRUE;
}

/**
 * Prepend the new grab to the list of passive grabs on the window.
 * Any previously existing grab that matches the new grab will be removed.
 * Adding a new grab that would override another client's grab will result in
 * a BadAccess.
 *
 * @return Success or X error code on failure.
 */
int AddPassiveGrabToList(ClientPtr client, GrabPtr pGrab)
{
    Mask access_mode = DixGrabAccess;
    int rc = void;

    for (GrabPtr grab = mixin(wPassiveGrabs!("pGrab.window")); grab; grab = grab.next) {
        if (GrabMatchesSecond(pGrab, grab, (pGrab.grabtype == CORE))) {
            if (dixClientIdForXID(pGrab.resource) != dixClientIdForXID(grab.resource)) {
                FreeGrab(pGrab);
                return BadAccess;
            }
        }
    }

    if (pGrab.keyboardMode == GrabModeSync ||
        pGrab.pointerMode == GrabModeSync)
        access_mode |= DixFreezeAccess;
    rc = dixCallDeviceAccessCallback(client, pGrab.device, access_mode);
    if (rc != Success)
        return rc;

    /* Remove all grabs that match the new one exactly */
    for (GrabPtr grab = mixin(wPassiveGrabs!("pGrab.window")); grab; grab = grab.next) {
        if (GrabsAreIdentical(pGrab, grab)) {
            DeletePassiveGrabFromList(grab);
            break;
        }
    }

    if (!MakeWindowOptional(pGrab.window)) {
        FreeGrab(pGrab);
        return BadAlloc;
    }

    pGrab.next = pGrab.window.optional.passiveGrabs;
    pGrab.window.optional.passiveGrabs = pGrab;
    if (AddResource(cast(uint)pGrab.resource, X11_RESTYPE_PASSIVEGRAB, cast(void*) pGrab))
        return Success;
    return BadAlloc;
}

/* the following is kinda complicated, because we need to be able to back out
 * if any allocation fails
 */

Bool DeletePassiveGrabFromList(GrabPtr pMinuendGrab)
{
    GrabPtr* deletes = void, adds = void;
    Mask*** updates = void; Mask** details = void;
    int i = void, ndels = void, nadds = void, nups = void;
    Bool ok = void;
    uint any_modifier = void;
    uint any_key = void;

enum string UPDATE(string mask,string exact) = `
	if (((details[nups] = DeleteDetailFromMask(` ~ mask ~ `, ` ~ exact ~ `)) is null)) 
	  ok = FALSE; 
	else 
	  updates[nups++] = &(` ~ mask ~ `);`;

    i = 0;
    for (GrabPtr grab = mixin(wPassiveGrabs!("pMinuendGrab.window")); grab; grab = grab.next)
        i++;
    if (!i)
        return TRUE;
    deletes = cast(_GrabRec**)calloc(i, GrabPtr.sizeof);
    adds = cast(_GrabRec**)calloc(i, GrabPtr.sizeof);
    updates = cast(uint***)calloc(i, (Mask**).sizeof);
    details = cast(uint**)calloc(i, (Mask*).sizeof);
    if (!deletes || !adds || !updates || !details) {
        free(details);
        free(updates);
        free(adds);
        free(deletes);
        return FALSE;
    }

    any_modifier = (pMinuendGrab.grabtype == XI2) ?
        cast(uint) XIAnyModifier : cast(uint) AnyModifier;
    any_key = (pMinuendGrab.grabtype == XI2) ?
        cast(uint) XIAnyKeycode : cast(uint) AnyKey;
    ndels = nadds = nups = 0;
    ok = TRUE;
    for (GrabPtr grab = mixin(wPassiveGrabs!("pMinuendGrab.window"));
         grab && ok; grab = grab.next) {
        if ((dixClientIdForXID(grab.resource) != dixClientIdForXID(pMinuendGrab.resource))
            || !GrabMatchesSecond(grab, pMinuendGrab, (grab.grabtype == CORE)))
            continue;
        if (GrabSupersedesSecond(pMinuendGrab, grab)) {
            deletes[ndels++] = grab;
        }
        else if ((grab.detail.exact == any_key)
                 && (grab.modifiersDetail.exact != any_modifier)) {
            mixin(UPDATE!(`grab.detail.pMask`, `pMinuendGrab.detail.exact`));
        }
        else if ((grab.modifiersDetail.exact == any_modifier)
                 && (grab.detail.exact != any_key)) {
            mixin(UPDATE!(`grab.modifiersDetail.pMask`,
                   `pMinuendGrab.modifiersDetail.exact`));
        }
        else if ((pMinuendGrab.detail.exact != any_key)
                 && (pMinuendGrab.modifiersDetail.exact != any_modifier)) {
            GrabPtr pNewGrab;
            GrabParameters param;

            mixin(UPDATE!(`grab.detail.pMask`, `pMinuendGrab.detail.exact`));

            memset(&param, 0, param.sizeof);
            param.ownerEvents = grab.ownerEvents;
            param.this_device_mode = grab.keyboardMode;
            param.other_devices_mode = grab.pointerMode;
            param.modifiers = any_modifier;

            pNewGrab = CreateGrab(dixClientForXID(grab.resource), grab.device,
                                  grab.modifierDevice, grab.window,
                                  grab.grabtype,
                                  cast(GrabMask*) &grab.eventMask,
                                  &param, cast(int) grab.type,
                                  cast(ubyte)pMinuendGrab.detail.exact,
                                  grab.confineTo, grab.cursor);
            if (!pNewGrab)
                ok = FALSE;
            else if (((pNewGrab.modifiersDetail.pMask =
                       DeleteDetailFromMask(grab.modifiersDetail.pMask,
                                            pMinuendGrab.modifiersDetail.
                                            exact)) is null)
                     || (!MakeWindowOptional(pNewGrab.window))) {
                FreeGrab(pNewGrab);
                ok = FALSE;
            }
            else if (!AddResource(cast(uint)pNewGrab.resource, X11_RESTYPE_PASSIVEGRAB,
                                  cast(void*) pNewGrab))
                ok = FALSE;
            else
                adds[nadds++] = pNewGrab;
        }
        else if (pMinuendGrab.detail.exact == any_key) {
            mixin(UPDATE!(`grab.modifiersDetail.pMask`,
                   `pMinuendGrab.modifiersDetail.exact`));
        }
        else {
            mixin(UPDATE!(`grab.detail.pMask`, `pMinuendGrab.detail.exact`));
        }
    }

    if (!ok) {
        for (int j = 0; j < nadds; j++)
            FreeResource(cast(uint)adds[j].resource, X11_RESTYPE_NONE);
        for (int j = 0; j < nups; j++)
            free(details[j]);
    }
    else {
        for (int j = 0; j < ndels; j++)
            FreeResource(cast(uint)deletes[j].resource, X11_RESTYPE_NONE);
        for (int j = 0; j < nadds; j++) {
            GrabPtr grab = adds[j];
            grab.next = grab.window.optional.passiveGrabs;
            grab.window.optional.passiveGrabs = grab;
        }
        for (int j = 0; j < nups; j++) {
            free(*updates[j]);
            *updates[j] = details[j];
        }
    }
    free(details);
    free(updates);
    free(adds);
    free(deletes);
    return ok;

}

Bool GrabIsPointerGrab(GrabPtr grab)
{
    return (grab.type == ButtonPress ||
            grab.type == DeviceButtonPress || grab.type == XI_ButtonPress);
}

Bool GrabIsKeyboardGrab(GrabPtr grab)
{
    return (grab.type == KeyPress ||
            grab.type == DeviceKeyPress || grab.type == XI_KeyPress);
}

Bool GrabIsGestureGrab(GrabPtr grab)
{
    return (grab.type == XI_GesturePinchBegin ||
            grab.type == XI_GestureSwipeBegin);
}
