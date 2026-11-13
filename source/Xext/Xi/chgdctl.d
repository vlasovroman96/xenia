module Xi.chgdctl;
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

/********************************************************************
 *
 *  Change Device control attributes for an extension device.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI;
// // //import externs.X11.extensions.XIproto;     /* control constants */

import dix.dix_priv;
import dix.exevents_priv;
import dix.input_priv;
import dix.request_priv;
import dix.resource_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import Xi.XIstubs;
import Xi.exglobals;
import externs.X11.extensions.XI;
import dix.devices;
import common.bytes;



/***********************************************************************
 *
 * Change the control attributes.
 *
 */

int ProcXChangeDeviceControl(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xChangeDeviceControlReq);
    mixin(REQUEST_AT_LEAST_EXTRA_SIZE!("xChangeDeviceControlReq", "xDeviceCtl.sizeof"));
    mixin(X_REQUEST_FIELD_CARD16!"control");

    if (client.swapped) {
        xDeviceCtl* ctl = cast(xDeviceCtl*) &stuff[1];
        swaps(&ctl.control);
        swaps(&ctl.length);
    }

    uint len = cast(uint)(client.req_len - int32ForBytes(xChangeDeviceControlReq.sizeof));

    xChangeDeviceControlReply reply = {
        RepType: X_ChangeDeviceControl,
        status: Success,
    };
    DeviceIntPtr dev = void;
    int ret = dixLookupDevice(&dev, stuff.deviceid, client, DixManageAccess);
    if (ret != Success)
        goto out_;

    /* XTest devices are special, none of the below apply to them anyway */
    if (IsXTestDevice(dev, null)) {
        ret = BadMatch;
        goto out_;
    }


    switch (stuff.control) {
    case DEVICE_RESOLUTION:
    {
        xDeviceResolutionCtl* r = cast(xDeviceResolutionCtl*) &stuff[1];
        if ((len < int32ForBytes(xDeviceResolutionCtl.sizeof)) ||
            (len !=
             int32ForBytes(xDeviceResolutionCtl.sizeof) + r.num_valuators)) {
            ret = BadLength;
            goto out_;
        }
        if (!dev.valuator) {
            ret = BadMatch;
            goto out_;
        }
        if ((dev.deviceGrab.grab) && !mixin(SameClient!("dev.deviceGrab.grab", "client"))) {
            reply.status = AlreadyGrabbed;
            ret = Success;
            goto out_;
        }
        CARD32* resolution = cast(CARD32*) (r + 1);
        if (r.first_valuator + r.num_valuators > dev.valuator.numAxes) {
            ret = BadValue;
            goto out_;
        }
        if (client.swapped) {
            SwapLongs(cast(CARD32*) (r + 1), r.num_valuators);
        }
        //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
        int status = ChangeDeviceControl(client, dev, cast(xDeviceCtl*) r);
        if (status == Success) {
            AxisInfoPtr a = &dev.valuator.axes[r.first_valuator];
            for (int i = 0; i < r.num_valuators; i++)
                if (*(resolution + i) < (a + i).min_resolution ||
                    *(resolution + i) > (a + i).max_resolution)
                    return BadValue;
            for (int i = 0; i < r.num_valuators; i++)
                (a++).resolution = cast(int)*resolution++;

            ret = Success;
        }
        else if (status == cast(ubyte)DeviceBusy) {
            reply.status = cast(ubyte)DeviceBusy;
            ret = Success;
        }
        else {
            ret = BadMatch;
        }
        break;
    }
    case DEVICE_ABS_CALIB:
    case DEVICE_ABS_AREA:
        /* Calibration is now done through properties, and never had any effect
         * on anything (in the open-source world). Thus, be honest. */
        ret = BadMatch;
        break;
    case DEVICE_CORE:
        /* Sorry, no device core switching no more. If you want a device to
         * send core events, attach it to a master device */
        ret = BadMatch;
        break;
    case DEVICE_ENABLE:
    {
        xDeviceEnableCtl* e = cast(xDeviceEnableCtl*) &stuff[1];
        if ((len != int32ForBytes(xDeviceEnableCtl.sizeof))) {
            ret = BadLength;
            goto out_;
        }

        int status = (IsXTestDevice(dev, null) ?
                      (!Success) : ChangeDeviceControl(client, dev, cast(xDeviceCtl*) e));

        if (status == Success) {
            if (e.enable)
                EnableDevice(dev, TRUE);
            else
                DisableDevice(dev, TRUE);
            ret = Success;
        }
        else if (status == DeviceBusy) {
            reply.status = cast(ubyte)DeviceBusy;
            ret = Success;
        }
        else {
            ret = BadMatch;
        }

        break;
    }
    default:
        ret = BadValue;
    }

 out_:
    if (ret == Success) {
        devicePresenceNotify dpn = {
            type: cast(ubyte)DevicePresenceNotify,
            time: currentTime.milliseconds,
            devchange: DeviceControlChanged,
            deviceid: cast(ubyte)dev.id,
            control: stuff.control
        };
        SendEventToAllWindows(dev, DevicePresenceNotifyMask,
                              cast(xEvent*) &dpn, 1);

        ret = mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
    }

    return ret;
}
