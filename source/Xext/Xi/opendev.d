module Xi.opendev;
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
 * Request to open an extension input device.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.input_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import Xi.XIstubs;
import dix.window;          /* window structure  */
import Xi.exglobals;
import Xi.exevents;
import dix.devices;
import externs.X11.extensions.XI;
import Xi.extinit;
import dix.events;


// CARD8[1] event_base;

/***********************************************************************
 *
 * This procedure causes the server to open an input device.
 *
 */

enum string WRITE_ICI(string cls) = `{ 
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)` ~ cls ~ `); 
        x_rpcbuf_write_CARD8(&rpcbuf, cast(ubyte)event_base[` ~ cls ~ `]); 
        num_classes++; 
    } `;

int ProcXOpenDevice(ClientPtr client)
{
    int num_classes = 0;
    int status = Success;
    DeviceIntPtr dev = void;

    mixin(X_REQUEST_HEAD_STRUCT!xOpenDeviceReq);

    status = dixLookupDevice(&dev, stuff.deviceid, client, DixUseAccess);

    if (status == BadDevice) {  /* not open */
        for (dev = inputInfo.off_devices; dev; dev = dev.next)
            if (dev.id == stuff.deviceid)
                break;
        if (dev is null)
            return BadDevice;
    }
    else if (status != Success)
        return status;

    if (InputDevIsMaster(dev))
        return BadDevice;

    if (status != Success)
        return status;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (dev.key !is null) {
        mixin(WRITE_ICI!(`KeyClass`));
    }
    if (dev.button !is null) {
        mixin(WRITE_ICI!(`ButtonClass`));
    }
    if (dev.valuator !is null) {
        mixin(WRITE_ICI!(`ValuatorClass`));
    }
    if (dev.kbdfeed !is null || dev.ptrfeed !is null || dev.leds !is null ||
        dev.intfeed !is null || dev.bell !is null || dev.stringfeed !is null) {
        mixin(WRITE_ICI!(`FeedbackClass`));
    }
    if (dev.focus !is null) {
        mixin(WRITE_ICI!(`FocusClass`));
    }
    if (dev.proximity !is null) {
        mixin(WRITE_ICI!(`ProximityClass`));
    }
    mixin(WRITE_ICI!(`OtherClass`));

    xOpenDeviceReply reply = {
        RepType: X_OpenDevice,
        num_classes: cast(ubyte)num_classes
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
