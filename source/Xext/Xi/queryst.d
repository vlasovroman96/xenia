module Xi.queryst;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1998, 1998  The Open Group

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

*/

/***********************************************************************
 *
 * Request to query the state of an extension input device.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.input_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structure  */
import include.xkbsrv;
import include.xkbsrv;
import dix.devices;
import externs.X11.extensions.XI;


/***********************************************************************
 *
 * This procedure allows frozen events to be routed.
 *
 */

int ProcXQueryDeviceState(ClientPtr client)
{
    int rc = void, i = void;
    int num_classes = 0;
    int total_length = 0;
    KeyClassPtr k = void;
    xKeyState* tk = void;
    ButtonClassPtr b = void;
    xButtonState* tb = void;
    ValuatorClassPtr v = void;
    xValuatorState* tv = void;
    DeviceIntPtr dev = void;
    double* values = void;

    mixin(X_REQUEST_HEAD_STRUCT!xQueryDeviceStateReq);

    rc = dixLookupDevice(&dev, stuff.deviceid, client, DixReadAccess);
    if (rc != Success && rc != BadAccess)
        return rc;

    v = dev.valuator;
    if (v !is null && v.motionHintWindow !is null)
        MaybeStopDeviceHint(dev, client);

    k = dev.key;
    if (k !is null) {
        total_length += xKeyState.sizeof;
        num_classes++;
    }

    b = dev.button;
    if (b !is null) {
        total_length += xButtonState.sizeof;
        num_classes++;
    }

    if (v !is null) {
        total_length += cast(int)(((xValuatorState).sizeof + (v.numAxes * int.sizeof)));
        num_classes++;
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    char* buf = cast(char*)x_rpcbuf_reserve(&rpcbuf, total_length);
    if (!buf)
        return BadAlloc;

    if (k !is null) {
        tk = cast(xKeyState*) buf;
        tk.class_ = KeyClass;
        tk.length = xKeyState.sizeof;
        tk.num_keys = cast(ubyte)(k.xkbInfo.desc.max_key_code -
            k.xkbInfo.desc.min_key_code + 1);
        if (rc != BadAccess)
            for (i = 0; i < 32; i++)
                tk.keys[i] = k.down[i];
        buf += xKeyState.sizeof;
    }

    if (b !is null) {
        tb = cast(xButtonState*) buf;
        tb.class_ = ButtonClass;
        tb.length = cast(uint)xButtonState.sizeof;
        tb.num_buttons = b.numButtons;
        if (rc != BadAccess)
            memcpy(tb.buttons.ptr, b.down.ptr, typeof(b.down).sizeof);
        buf += xButtonState.sizeof;
    }

    if (v !is null) {
        tv = cast(xValuatorState*) buf;
        tv.class_ = ValuatorClass;
        tv.length = cast(ubyte)((xValuatorState).sizeof + cast(ubyte)v.numAxes * 4);
        tv.num_valuators = cast(ubyte)v.numAxes;
        tv.mode = cast(ubyte)valuator_get_mode(dev, 0);
        tv.mode |= (dev.proximity &&
                     !dev.proximity.in_proximity) ? OutOfProximity : 0;
        buf += xValuatorState.sizeof;
        for (i = 0, values = v.axisVal; i < v.numAxes; i++) {
            if (rc != BadAccess)
                *(cast(int*) buf) = cast(int)*values;
            values++;
            if (client.swapped) {
                swapl(cast(int*) buf);
            }
            buf += int.sizeof;
        }
    }

    xQueryDeviceStateReply reply = {
        RepType: X_QueryDeviceState,
        num_classes: cast(ubyte)num_classes
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
