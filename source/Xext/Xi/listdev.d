module Xi.listdev;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Copyright 1989, 1998  The Open Group

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

Copyright 1989 by Hewlett-Packard Company, Palo Alto, California.

			All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Hewlett-Packard not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

HEWLETT-PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
HEWLETT-PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

********************************************************/

/***********************************************************************
 *
 * Extension function to list the available input devices.
 *
 */

import build.dix_config;

//import x11.X;              /* for inputstr.h    */
//import x11.Xproto;         /* Request macro     */
//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.devices_priv;
import dix.dix_priv;
import dix.input_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import Xi.handlers;

import include.inputstr;           /* DeviceIntPtr      */
import Xi.XIstubs;
import include.extnsionst;
import include.exevents;
import include.xkbsrv;
import externs.X11.extensions.XI;
import include.xkbsrv;
import dix.devices;
import dix.events;

enum VPC =        20              /* Max # valuators per chunk */;

/***********************************************************************
 *
 * This procedure calculates the size of the information to be returned
 * for an input device.
 *
 */

pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void SizeDeviceInfo(DeviceIntPtr d, int* namesize, int* size)
{
    int chunks = void;

    *namesize += 1;
    if (d.name)
        *namesize += strlen(d.name);
    if (d.key !is null)
        *size += xKeyInfo.sizeof;
    if (d.button !is null)
        *size += xButtonInfo.sizeof;
    if (d.valuator !is null) {
        chunks = (cast(int) d.valuator.numAxes + 19) / VPC;
        *size += (chunks * (xValuatorInfo).sizeof +
                  d.valuator.numAxes * xAxisInfo.sizeof);
    }
}

/***********************************************************************
 *
 * This procedure copies data to the DeviceInfo struct, swapping if necessary.
 *
 * We need the extra byte in the allocated buffer, because the trailing null
 * hammers one extra byte, which is overwritten by the next name except for
 * the last name copied.
 *
 */

private void CopyDeviceName(char** namebuf, const(char)* name)
{
    char* nameptr = *namebuf;

    if (name) {
        *(nameptr++) = cast(char)strlen(name);
        strcpy(nameptr, name);
        *namebuf += (strlen(name) + 1);
    }
    else {
        *nameptr++ = 0;
        *namebuf += 1;
    }
}

/***********************************************************************
 *
 * This procedure copies ButtonClass information, swapping if necessary.
 *
 */

private void CopySwapButtonClass(ClientPtr client, ButtonClassPtr b, char** buf)
{
    xButtonInfoPtr b2 = void;

    b2 = cast(xButtonInfoPtr) * buf;
    b2.class_ = ButtonClass;
    b2.length = xButtonInfo.sizeof;
    b2.num_buttons = b.numButtons;
    if (client && client.swapped) {
        swaps(&b2.num_buttons);
    }
    *buf += xButtonInfo.sizeof;
}

/***********************************************************************
 *
 * This procedure copies data to the DeviceInfo struct, swapping if necessary.
 *
 */

private void CopySwapDevice(ClientPtr client, DeviceIntPtr d, int num_classes, char** buf)
{
    xDeviceInfoPtr dev = void;

    dev = cast(xDeviceInfoPtr) * buf;

    dev.id = cast(ubyte)d.id;
    dev.type = cast(uint)d.xinput_type;
    dev.num_classes = cast(ubyte)num_classes;
    if (InputDevIsMaster(d) && IsKeyboardDevice(d))
        dev.use = IsXKeyboard;
    else if (InputDevIsMaster(d) && IsPointerDevice(d))
        dev.use = IsXPointer;
    else if (d.valuator && d.button)
        dev.use = IsXExtensionPointer;
    else if (d.key && d.kbdfeed)
        dev.use = IsXExtensionKeyboard;
    else
        dev.use = IsXExtensionDevice;

    if (client.swapped) {
        swapl(&dev.type);
    }
    *buf += xDeviceInfo.sizeof;
}

/***********************************************************************
 *
 * This procedure copies KeyClass information, swapping if necessary.
 *
 */

private void CopySwapKeyClass(ClientPtr client, KeyClassPtr k, char** buf)
{
    xKeyInfoPtr k2 = void;

    k2 = cast(xKeyInfoPtr) * buf;
    k2.class_ = KeyClass;
    k2.length = xKeyInfo.sizeof;
    k2.min_keycode = k.xkbInfo.desc.min_key_code;
    k2.max_keycode = k.xkbInfo.desc.max_key_code;
    k2.num_keys = cast(ushort)(k2.max_keycode - k2.min_keycode + 1);
    if (client && client.swapped) {
        swaps(&k2.num_keys);
    }
    *buf += xKeyInfo.sizeof;
}

/***********************************************************************
 *
 * This procedure copies ValuatorClass information, swapping if necessary.
 *
 * Devices may have up to 255 valuators.  The length of a ValuatorClass is
 * defined to be sizeof(ValuatorClassInfo) + num_axes * sizeof (xAxisInfo).
 * The maximum length is therefore (8 + 255 * 12) = 3068.  However, the
 * length field is one byte.  If a device has more than 20 valuators, we
 * must therefore return multiple valuator classes to the client.
 *
 */

private int CopySwapValuatorClass(ClientPtr client, DeviceIntPtr dev, char** buf)
{
    int i = void, j = void, axes = void, t_axes = void;
    ValuatorClassPtr v = dev.valuator;
    xValuatorInfoPtr v2 = void;
    AxisInfo* a = void;
    xAxisInfoPtr a2 = void;

    for (i = 0, axes = v.numAxes; i < ((v.numAxes + 19) / VPC);
         i++, axes -= VPC) {
        t_axes = axes < VPC ? axes : VPC;
        if (t_axes < 0)
            t_axes = v.numAxes % VPC;
        v2 = cast(xValuatorInfoPtr) * buf;
        v2.class_ = ValuatorClass;
        v2.length = cast(ubyte)((xValuatorInfo).sizeof + t_axes * xAxisInfo.sizeof);
        v2.num_axes = cast(ubyte)t_axes;
        v2.mode = cast(ubyte)valuator_get_mode(dev, 0);
        v2.motion_buffer_size = v.numMotionEvents;
        if (client && client.swapped) {
            swapl(&v2.motion_buffer_size);
        }
        *buf += xValuatorInfo.sizeof;
        a = v.axes + (VPC * i);
        a2 = cast(xAxisInfoPtr) * buf;
        for (j = 0; j < t_axes; j++) {
            a2.min_value = a.min_value;
            a2.max_value = a.max_value;
            a2.resolution = a.resolution;
            if (client && client.swapped) {
                swapl(&a2.min_value);
                swapl(&a2.max_value);
                swapl(&a2.resolution);
            }
            a2++;
            a++;
            *buf += xAxisInfo.sizeof;
        }
    }
    return i;
}

private void CopySwapClasses(ClientPtr client, DeviceIntPtr dev, CARD8* num_classes, char** classbuf)
{
    if (dev.key !is null) {
        CopySwapKeyClass(client, dev.key, classbuf);
        (*num_classes)++;
    }
    if (dev.button !is null) {
        CopySwapButtonClass(client, dev.button, classbuf);
        (*num_classes)++;
    }
    if (dev.valuator !is null) {
        (*num_classes) += CopySwapValuatorClass(client, dev, classbuf);
    }
}

/***********************************************************************
 *
 * This procedure lists information to be returned for an input device.
 *
 */

pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private void ListDeviceInfo(ClientPtr client, DeviceIntPtr d, xDeviceInfoPtr dev, char** devbuf, char** classbuf, char** namebuf)
{
    CopyDeviceName(namebuf, d.name);
    CopySwapDevice(client, d, 0, devbuf);
    CopySwapClasses(client, d, &dev.num_classes, classbuf);
}

/***********************************************************************
 *
 * This procedure checks if a device should be left off the list.
 *
 */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
private Bool ShouldSkipDevice(ClientPtr client, DeviceIntPtr d)
{
    /* don't send master devices other than VCP/VCK */
    if (!InputDevIsMaster(d) || d == inputInfo.pointer ||d == inputInfo.keyboard) {
        int rc = dixCallDeviceAccessCallback(client, d, DixGetAttrAccess);

        if (rc == Success)
            return FALSE;
    }
    return TRUE;
}

/***********************************************************************
 *
 * This procedure lists the input devices available to the server.
 *
 * If this request is called by a client that has not issued a
 * GetExtensionVersion request with major/minor version set, we don't send the
 * complete device list. Instead, we only send the VCP, the VCK and floating
 * SDs. This resembles the setup found on XI 1.x machines.
 */

int ProcXListInputDevices(ClientPtr client)
{
    int numdevs = 0;
    int namesize = 1;           /* need 1 extra byte for strcpy */
    int i = 0, size = 0;
    int total_length = void;
    char* classbuf = void, namebuf = void;
    Bool* skip = void;
    xDeviceInfo* dev = void;
    DeviceIntPtr d = void;

    mixin(X_REQUEST_HEAD_STRUCT!xListInputDevicesReq);

    /* allocate space for saving skip value */
    skip = cast(Bool*) calloc(inputInfo.numDevices, Bool.sizeof);
    if (!skip)
        return BadAlloc;

    /* figure out which devices to skip */
    numdevs = 0;
    for (d = inputInfo.devices; d; d = d.next, i++) {
        skip[i] = ShouldSkipDevice(client, d);
        if (skip[i])
            continue;

        SizeDeviceInfo(d, &namesize, &size);
        numdevs++;
    }

    for (d = inputInfo.off_devices; d; d = d.next, i++) {
        skip[i] = ShouldSkipDevice(client, d);
        if (skip[i])
            continue;

        SizeDeviceInfo(d, &namesize, &size);
        numdevs++;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    /* allocate space for reply */
    total_length = cast(int)(numdevs * (xDeviceInfo).sizeof + size + namesize);
    char* devbuf = cast(char*)x_rpcbuf_reserve(&rpcbuf, total_length);
    if (!devbuf) {
        free(skip);
        return BadAlloc;
    }

    classbuf = devbuf + (numdevs * xDeviceInfo.sizeof);
    namebuf = classbuf + size;

    /* fill in and send reply */
    i = 0;
    dev = cast(xDeviceInfoPtr) devbuf;
    for (d = inputInfo.devices; d; d = d.next, i++) {
        if (skip[i])
            continue;

        ListDeviceInfo(client, d, dev++, &devbuf, &classbuf, &namebuf);
    }

    for (d = inputInfo.off_devices; d; d = d.next, i++) {
        if (skip[i])
            continue;

        ListDeviceInfo(client, d, dev++, &devbuf, &classbuf, &namebuf);
    }

    free(skip);

    xListInputDevicesReply reply = {
        RepType: X_ListInputDevices,
        ndevices: cast(ubyte)numdevs,
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
