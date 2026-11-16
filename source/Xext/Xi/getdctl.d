module Xi.getdctl;
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

import build.dix_config;

//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf;
import Xi.handlers;
import externs.X11.extensions.XI;
import externs.X11.extensions.XIproto;
import dix.dixutils;
import dix.devices;
import dix.events;
import common.swap;


import dix.inputstr;           /* DeviceIntPtr      */

private void _writeDeviceResolution(ClientPtr client, ValuatorClassPtr v, RPCBuffer* rpcbuf)
{
    AxisInfoPtr a = void;
    int i = void;

    /* write xDeviceResolutionState */
    rpcbuf.writeCard16(DEVICE_RESOLUTION);
    rpcbuf.writeCard16(
        cast(ushort)((xDeviceResolutionState).sizeof + (3*((CARD32).sizeof*v.numAxes))));
    rpcbuf.writeCard32(v.numAxes);

    for (i = 0, a = v.axes; i < v.numAxes; i++, a++)
        rpcbuf.writeCard32(a.resolution);
    for (i = 0, a = v.axes; i < v.numAxes; i++, a++)
        rpcbuf.writeCard32(a.min_resolution);
    for (i = 0, a = v.axes; i < v.numAxes; i++, a++)
        rpcbuf.writeCard32(a.max_resolution);
}

private void _writeDeviceCore(ClientPtr client, DeviceIntPtr dev, RPCBuffer* rpcbuf)
{
    /* write xDeviceCoreState */
    rpcbuf.writeCard16(DEVICE_CORE);
    rpcbuf.writeCard16(xDeviceCoreState.sizeof);
    rpcbuf.writeCard8(cast(ubyte)dev.coreEvents);
    rpcbuf.writeCard8(cast(ubyte)(dev == inputInfo.keyboard || dev == inputInfo.pointer));
    rpcbuf.writeCard16(0); /* pad1 */
}

private void _writeDeviceEnable(ClientPtr client, DeviceIntPtr dev, RPCBuffer* rpcbuf)
{
    /* write xDeviceEnableState */
    rpcbuf.writeCard16(DEVICE_ENABLE);
    rpcbuf.writeCard16(xDeviceEnableState.sizeof);
    rpcbuf.writeCard8(cast(ubyte)dev.enabled);
    rpcbuf.writeCard8(0); /* pad0 */
    rpcbuf.writeCard16(0); /* pad1 */
}

/***********************************************************************
 *
 * Get the state of the specified device control.
 *
 */

int ProcXGetDeviceControl(ClientPtr client)
{
    DeviceIntPtr dev = void;

    mixin(X_REQUEST_HEAD_STRUCT!xGetDeviceControlReq);
    mixin(X_REQUEST_FIELD_CARD16!"control");

    int rc = dixLookupDevice(&dev, stuff.deviceid, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    RPCBuffer rpcbuf = { swapped: cast(bool)client.swapped, err_clear: True };

    switch (stuff.control) {
    case DEVICE_RESOLUTION:
        if (!dev.valuator)
            return BadMatch;
        _writeDeviceResolution(client, dev.valuator, &rpcbuf);
        break;
    case DEVICE_CORE:
        _writeDeviceCore(client, dev, &rpcbuf);
        break;
    case DEVICE_ENABLE:
        _writeDeviceEnable(client, dev, &rpcbuf);
        break;
    case DEVICE_ABS_CALIB:
    case DEVICE_ABS_AREA:
        return BadMatch;
    default:
        return BadValue;
    }

    xGetDeviceControlReply reply = {
        RepType: X_GetDeviceControl,
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
