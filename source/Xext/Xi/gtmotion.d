module Xi.gtmotion;
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
 * Request to get the motion history from an extension device.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import Xi.handlers;

import include.inputstr;           /* DeviceIntPtr      */
import externs.X11.extensions.XIproto;
import externs.X11.extensions.XI;
import dix.dixutils;
import dix.devices;
import dix.timestamp;


/****************************************************************************
 *
 * Get the motion history for an extension pointer devices.
 *
 */

int ProcXGetDeviceMotionEvents(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xGetDeviceMotionEventsReq);
    mixin(X_REQUEST_FIELD_CARD32!"start");
    mixin(X_REQUEST_FIELD_CARD32!"stop");

    DeviceIntPtr dev = void;
    int rc = dixLookupDevice(&dev, stuff.deviceid, client, DixReadAccess);
    if (rc != Success)
        return rc;

    const(ValuatorClassPtr) v = dev.valuator;
    if (v is null || v.numAxes == 0)
        return BadMatch;

    if (dev.valuator.motionHintWindow)
        MaybeStopDeviceHint(dev, client);

    xGetDeviceMotionEventsReply reply = {
        RepType: X_GetDeviceMotionEvents,
        axes: cast(ubyte)v.numAxes,
        mode: Absolute        /* XXX we don't do relative at the moment */
    };

    TimeStamp start = ClientTimeToServerTime(stuff.start);
    TimeStamp stop = ClientTimeToServerTime(stuff.stop);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (CompareTimeStamps(start, stop) != LATER &&
        CompareTimeStamps(start, currentTime) != LATER) {
        if (CompareTimeStamps(stop, currentTime) == LATER)
            stop = currentTime;
        if (v.numMotionEvents) {
            const(int) size = ((Time).sizeof + (v.numAxes * INT32.sizeof));
            INT32* coords = null;
            reply.nEvents = GetMotionHistory(dev, cast(xTimecoord**) &coords,   /* XXX */
                                           start.milliseconds, stop.milliseconds,
                                           cast(ScreenPtr) null, FALSE);
            x_rpcbuf_write_INT32s(&rpcbuf, coords, bytes_to_int32(reply.nEvents * size));
            free(coords);
        }
    }

    mixin(X_REPLY_FIELD_CARD32!"nEvents");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
