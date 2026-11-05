module Xi.xichangehierarchy;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright 2007-2008 Peter Hutterer
 * Copyright 2009 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Author: Peter Hutterer, University of South Australia, NICTA
 */

/***********************************************************************
 *
 * Request change in the device hierarchy.
 *
 */

import build.dix_config;

//import x11.X;              /* for inputstr.h    */
//import x11.Xproto;         /* Request macro     */
import externs.X11.extensions.XI;
import externs.X11.extensions.XI2proto;
// //import externs.X11.extensions.geproto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.extension_priv;
import dix.input_priv;
import dix.request_priv;
import os.bug_priv;
import Xi.handlers;
import dix.events;
import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structure  */
import dix.scrnintstr;         /* screen structure  */
import dix.extension;
import Xi.exglobals;
import common.misc;
import Xext.xace;
import Xi.xiquerydevice;      /* for GetDeviceUse */
import xkb.xkbsrv_priv;
import Xi.xichangehierarchy;
import Xi.xibarriers;
import os.utils;
import dix.devices;
import dix.events;

/**
 * Send the current state of the device hierarchy to all clients.
 */
void XISendDeviceHierarchyEvent(int* flags)
{
    xXIHierarchyEvent* ev = void;
    xXIHierarchyInfo* info = void;
    DeviceIntRec dummyDev = void;
    DeviceIntPtr dev = void;
    int i = void;

    if (!flags)
        return;

    ev = cast(xXIHierarchyEvent*) calloc(1, ((xXIHierarchyEvent).sizeof +
                MAXDEVICES * xXIHierarchyInfo.sizeof));
    if (!ev)
        return;
    ev.type = GenericEvent;
    ev.extension = EXTENSION_MAJOR_XINPUT;
    ev.evtype = XI_HierarchyChanged;
    ev.time = GetTimeInMillis();
    ev.flags = 0;
    ev.num_info = cast(ushort)inputInfo.numDevices;

    info = cast(xXIHierarchyInfo*) &ev[1];
    for (dev = inputInfo.devices; dev; dev = dev.next) {
        info.deviceid = cast(ushort)dev.id;
        info.enabled = cast(ubyte)dev.enabled;
        info.use = cast(ubyte)GetDeviceUse(dev, &info.attachment);
        info.flags = flags[dev.id];
        ev.flags |= info.flags;
        info++;
    }
    for (dev = inputInfo.off_devices; dev; dev = dev.next) {
        info.deviceid = cast(ushort)dev.id;
        info.enabled = cast(ubyte)dev.enabled;
        info.use = cast(ubyte)GetDeviceUse(dev, &info.attachment);
        info.flags = flags[dev.id];
        ev.flags |= info.flags;
        info++;
    }

    for (i = 0; i < MAXDEVICES; i++) {
        if (flags[i] & (XIMasterRemoved | XISlaveRemoved)) {
            info.deviceid = cast(ushort)i;
            info.enabled = FALSE;
            info.flags = flags[i];
            info.use = 0;
            ev.flags |= info.flags;
            ev.num_info++;
            info++;
        }
    }

    ev.length = cast(uint)bytes_to_int32(ev.num_info * xXIHierarchyInfo.sizeof);

    memset(&dummyDev, 0, dummyDev.sizeof);
    dummyDev.id = XIAllDevices;
    dummyDev.type = SLAVE;
    SendEventToAllWindows(&dummyDev, (XI_HierarchyChangedMask >> 8),
                          cast(xEvent*) ev, 1);
    free(ev);
}

/***********************************************************************
 *
 * This procedure allows a client to change the device hierarchy through
 * adding new master devices, removing them, etc.
 *
 */

private int add_master(ClientPtr client, xXIAddMasterInfo* c, int* flags)
{
    DeviceIntPtr ptr = void, keybd = void, XTestptr = void, XTestkeybd = void;
    char* name = void;
    int rc = void;

    name = cast(char*) calloc(c.name_len + 1, char.sizeof);
    if (name is null) {
        rc = BadAlloc;
        goto unwind;
    }
    strncpy(name, cast(char*) &c[1], c.name_len);

    rc = AllocDevicePair(client, name, &ptr, &keybd,
                         &CorePointerProc, &CoreKeyboardProc, TRUE);
    if (rc != Success)
        goto unwind;

    if (!c.send_core)
        ptr.coreEvents = keybd.coreEvents = FALSE;

    /* Allocate virtual slave devices for xtest events */
    rc = AllocXTestDevice(client, name, &XTestptr, &XTestkeybd, ptr, keybd);
    if (rc != Success) {
        DeleteInputDeviceRequest(ptr);
        DeleteInputDeviceRequest(keybd);
        goto unwind;
    }

    ActivateDevice(ptr, FALSE);
    ActivateDevice(keybd, FALSE);
    flags[ptr.id] |= XIMasterAdded;
    flags[keybd.id] |= XIMasterAdded;

    ActivateDevice(XTestptr, FALSE);
    ActivateDevice(XTestkeybd, FALSE);
    flags[XTestptr.id] |= XISlaveAdded;
    flags[XTestkeybd.id] |= XISlaveAdded;

    if (c.enable) {
        EnableDevice(ptr, FALSE);
        EnableDevice(keybd, FALSE);
        flags[ptr.id] |= XIDeviceEnabled;
        flags[keybd.id] |= XIDeviceEnabled;

        EnableDevice(XTestptr, FALSE);
        EnableDevice(XTestkeybd, FALSE);
        flags[XTestptr.id] |= XIDeviceEnabled;
        flags[XTestkeybd.id] |= XIDeviceEnabled;
    }

    /* Attach the XTest virtual devices to the newly
       created master device */
    AttachDevice(null, XTestptr, ptr);
    AttachDevice(null, XTestkeybd, keybd);
    flags[XTestptr.id] |= XISlaveAttached;
    flags[XTestkeybd.id] |= XISlaveAttached;

    for (int i = 0; i < currentMaxClients; i++)
        XIBarrierNewMasterDevice(clients[i], ptr.id);

 unwind:
    free(name);
    return rc;
}

private void disable_clientpointer(DeviceIntPtr dev)
{
    int i = void;

    for (i = 0; i < currentMaxClients; i++) {
        ClientPtr client = clients[i];

        if (client && client.clientPtr == dev)
            client.clientPtr = null;
    }
}

private DeviceIntPtr find_disabled_master(int type)
{
    DeviceIntPtr dev = void;

    /* Once a master device is disabled it loses the pairing, so returning the first
     * match is good enough */
    for (dev = inputInfo.off_devices; dev; dev = dev.next) {
        if (dev.type == type)
            return dev;
    }

    return null;
}

private int remove_master(ClientPtr client, xXIRemoveMasterInfo* r, int* flags)
{
    DeviceIntPtr dev = void, ptr = void, keybd = void, XTestptr = void, XTestkeybd = void;
    int rc = Success;

    if (r.return_mode != XIAttachToMaster && r.return_mode != XIFloating)
        return BadValue;

    rc = dixLookupDevice(&dev, r.deviceid, client, DixDestroyAccess);
    if (rc != Success)
        goto unwind;

    if (!InputDevIsMaster(dev)) {
        client.errorValue = cast(uint)r.deviceid;
        rc = BadDevice;
        goto unwind;
    }

    /* XXX: For now, don't allow removal of VCP, VCK */
    if (dev == inputInfo.pointer || dev == inputInfo.keyboard) {
        rc = BadDevice;
        goto unwind;
    }

    if ((ptr = GetMaster(dev, MASTER_POINTER)) is null)
        ptr = find_disabled_master(MASTER_POINTER);
    mixin(BUG_RETURN_VAL!("ptr is null", "BadDevice"));
    rc = dixLookupDevice(&ptr, ptr.id, client, DixDestroyAccess);
    if (rc != Success)
        goto unwind;

    if ((keybd = GetMaster(dev, MASTER_KEYBOARD)) is null)
        keybd = find_disabled_master(MASTER_KEYBOARD);
    mixin(BUG_RETURN_VAL!("keybd is null", "BadDevice"));
    rc = dixLookupDevice(&keybd, keybd.id, client, DixDestroyAccess);
    if (rc != Success)
        goto unwind;

    XTestptr = GetXTestDevice(ptr);
    mixin(BUG_RETURN_VAL!("XTestptr is null", "BadDevice"));
    rc = dixLookupDevice(&XTestptr, XTestptr.id, client, DixDestroyAccess);
    if (rc != Success)
        goto unwind;

    XTestkeybd = GetXTestDevice(keybd);
    mixin(BUG_RETURN_VAL!("XTestkeybd is null", "BadDevice"));
    rc = dixLookupDevice(&XTestkeybd, XTestkeybd.id, client, DixDestroyAccess);
    if (rc != Success)
        goto unwind;

    disable_clientpointer(ptr);

    /* Disabling sends the devices floating, reattach them if
     * desired. */
    if (r.return_mode == XIAttachToMaster) {
        DeviceIntPtr attached = void, newptr = void, newkeybd = void;

        rc = dixLookupDevice(&newptr, r.return_pointer, client, DixAddAccess);
        if (rc != Success)
            goto unwind;

        if (!InputDevIsMaster(newptr) || !IsPointerDevice(newptr)) {
            client.errorValue = cast(uint)r.return_pointer;
            rc = BadDevice;
            goto unwind;
        }

        rc = dixLookupDevice(&newkeybd, r.return_keyboard,
                             client, DixAddAccess);
        if (rc != Success)
            goto unwind;

        if (!InputDevIsMaster(newkeybd) || !IsKeyboardDevice(newkeybd)) {
            client.errorValue = cast(uint)r.return_keyboard;
            rc = BadDevice;
            goto unwind;
        }

        for (attached = inputInfo.devices; attached; attached = attached.next) {
            if (!InputDevIsMaster(attached)) {
                if (GetMaster(attached, MASTER_ATTACHED) == ptr) {
                    AttachDevice(client, attached, newptr);
                    flags[attached.id] |= XISlaveAttached;
                }
                if (GetMaster(attached, MASTER_ATTACHED) == keybd) {
                    AttachDevice(client, attached, newkeybd);
                    flags[attached.id] |= XISlaveAttached;
                }
            }
        }
    }

    for (int i = 0; i < currentMaxClients; i++)
        XIBarrierRemoveMasterDevice(clients[i], ptr.id);

    /* disable the remove the devices, XTest devices must be done first
       else the sprites they rely on will be destroyed  */
    DisableDevice(XTestptr, FALSE);
    DisableDevice(XTestkeybd, FALSE);
    DisableDevice(keybd, FALSE);
    DisableDevice(ptr, FALSE);
    flags[XTestptr.id] |= XIDeviceDisabled | XISlaveDetached;
    flags[XTestkeybd.id] |= XIDeviceDisabled | XISlaveDetached;
    flags[keybd.id] |= XIDeviceDisabled;
    flags[ptr.id] |= XIDeviceDisabled;

    flags[XTestptr.id] |= XISlaveRemoved;
    flags[XTestkeybd.id] |= XISlaveRemoved;
    flags[keybd.id] |= XIMasterRemoved;
    flags[ptr.id] |= XIMasterRemoved;

    RemoveDevice(XTestptr, FALSE);
    RemoveDevice(XTestkeybd, FALSE);
    RemoveDevice(keybd, FALSE);
    RemoveDevice(ptr, FALSE);

 unwind:
    return rc;
}

private int detach_slave(ClientPtr client, xXIDetachSlaveInfo* c, int* flags)
{
    DeviceIntPtr dev = void;
    int rc = void;

    rc = dixLookupDevice(&dev, c.deviceid, client, DixManageAccess);
    if (rc != Success)
        goto unwind;

    if (InputDevIsMaster(dev)) {
        client.errorValue = cast(uint)c.deviceid;
        rc = BadDevice;
        goto unwind;
    }

    /* Don't allow changes to XTest Devices, these are fixed */
    if (IsXTestDevice(dev, null)) {
        client.errorValue = cast(uint)c.deviceid;
        rc = BadDevice;
        goto unwind;
    }

    ReleaseButtonsAndKeys(dev);
    AttachDevice(client, dev, null);
    flags[dev.id] |= XISlaveDetached;

 unwind:
    return rc;
}

private int attach_slave(ClientPtr client, xXIAttachSlaveInfo* c, int* flags)
{
    DeviceIntPtr dev = void;
    DeviceIntPtr newmaster = void;
    int rc = void;

    rc = dixLookupDevice(&dev, c.deviceid, client, DixManageAccess);
    if (rc != Success)
        goto unwind;

    if (InputDevIsMaster(dev)) {
        client.errorValue = cast(uint)c.deviceid;
        rc = BadDevice;
        goto unwind;
    }

    /* Don't allow changes to XTest Devices, these are fixed */
    if (IsXTestDevice(dev, null)) {
        client.errorValue = cast(uint)c.deviceid;
        rc = BadDevice;
        goto unwind;
    }

    rc = dixLookupDevice(&newmaster, c.new_master, client, DixAddAccess);
    if (rc != Success)
        goto unwind;
    if (!InputDevIsMaster(newmaster)) {
        client.errorValue = cast(uint)c.new_master;
        rc = BadDevice;
        goto unwind;
    }

    if (!((IsPointerDevice(newmaster) && IsPointerDevice(dev)) ||
          (IsKeyboardDevice(newmaster) && IsKeyboardDevice(dev)))) {
        rc = BadDevice;
        goto unwind;
    }

    ReleaseButtonsAndKeys(dev);
    AttachDevice(client, dev, newmaster);
    flags[dev.id] |= XISlaveAttached;

 unwind:
    return rc;
}

int ProcXIChangeHierarchy(ClientPtr client)
{
    xXIAnyHierarchyChangeInfo* any = void;
    size_t len = void;			/* length of data remaining in request */
    int rc = Success;
    int[MAXDEVICES] flags = 0;
    enum _Changes {
        NO_CHANGE,
        FLUSH,
        CHANGED,
    }
    _Changes changes = _Changes.NO_CHANGE;

    mixin(X_REQUEST_HEAD_AT_LEAST!xXIChangeHierarchyReq);

    if (!stuff.num_changes)
        return rc;

    len = (cast(size_t)client.req_len << 2) - xXIChangeHierarchyReq.sizeof;

    any = cast(xXIAnyHierarchyChangeInfo*) &stuff[1];
    while (stuff.num_changes--) {
        if (len < xXIAnyHierarchyChangeInfo.sizeof) {
            rc = BadLength;
            goto unwind;
        }

        if (client.swapped) {
            swaps(&any.type);
            swaps(&any.length);
        }

        if (len < (cast(size_t)any.length << 2))
            return BadLength;

enum string CHANGE_SIZE_MATCH(string type) = `
        if ((len < ` ~ type ~ `.sizeof) || (any.length != (`~type~`.sizeof >> 2))) { 
            rc = BadLength; 
            goto unwind; 
        }`; 

        switch (any.type) {
        case XIAddMaster:
        {
            xXIAddMasterInfo* c = cast(xXIAddMasterInfo*) any;

            /* Variable length, due to appended name string */
            if (len < xXIAddMasterInfo.sizeof) {
                rc = BadLength;
                goto unwind;
            }

            if (client.swapped)
                swaps(&c.name_len);

            if (c.name_len > (len - xXIAddMasterInfo.sizeof)) {
                rc = BadLength;
                goto unwind;
            }

            rc = add_master(client, c, flags.ptr);
            if (rc != Success)
                goto unwind;
            changes = _Changes.FLUSH;
            break;
        }
        case XIRemoveMaster:
        {
            xXIRemoveMasterInfo* r = cast(xXIRemoveMasterInfo*) any;

            mixin(CHANGE_SIZE_MATCH!(`xXIRemoveMasterInfo`));
            rc = remove_master(client, r, flags.ptr);
            if (rc != Success)
                goto unwind;
            changes = _Changes.FLUSH;
            break;
        }
        case XIDetachSlave:
        {
            xXIDetachSlaveInfo* c = cast(xXIDetachSlaveInfo*) any;

            mixin(CHANGE_SIZE_MATCH!(`xXIDetachSlaveInfo`));
            rc = detach_slave(client, c, flags.ptr);
            if (rc != Success)
                goto unwind;
            changes = _Changes.CHANGED;
            break;
        }
        case XIAttachSlave:
        {
            xXIAttachSlaveInfo* c = cast(xXIAttachSlaveInfo*) any;

            mixin(CHANGE_SIZE_MATCH!(`xXIAttachSlaveInfo`));
            rc = attach_slave(client, c, flags.ptr);
            if (rc != Success)
                goto unwind;
            changes = _Changes.CHANGED;
            break;
        }
        default:
            break;
        }

        if (changes == _Changes.FLUSH) {
            XISendDeviceHierarchyEvent(flags.ptr);
            memset(flags.ptr, 0, flags.sizeof);
            changes = _Changes.NO_CHANGE;
        }

        len -= any.length * 4;
        any = cast(xXIAnyHierarchyChangeInfo*) (cast(char*) any + any.length * 4);
    }

 unwind:
    if (changes != _Changes.NO_CHANGE)
        XISendDeviceHierarchyEvent(flags.ptr);
    return rc;
}
