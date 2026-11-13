module Xi.selectev;
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
 * Request to select input from an extension device.
 *
 */

import build.dix_config;

import externs.X11.extensions.XI;
//import externs.X11.extensions.XI2;
// //import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.request_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import dix.window;          /* window structure  */
import Xi.exglobals;
import Xi.grabdev;
import dix.dixutils;
import std.conv;
import common.swap;

private int HandleDevicePresenceMask(ClientPtr client, WindowPtr win, XEventClass* cls, CARD16* count)
{
    int i = void, j = void;
    Mask mask = void;

    /* We use the device ID 256 to select events that aren't bound to
     * any device.  For now we only handle the device presence event,
     * but this could be extended to other events that aren't bound to
     * a device.
     *
     * In order not to break in CreateMaskFromList() we remove the
     * entries with device ID 256 from the XEventClass array.
     */

    mask = 0;
    for (i = 0, j = 0; i < *count; i++) {
        if (cls[i] >> 8 != 256) {
            cls[j] = cls[i];
            j++;
            continue;
        }

        switch (cls[i] & 0xff) {
        case _devicePresence:
            mask |= DevicePresenceNotifyMask;
            break;
        default: break;}
    }

    *count = cast(ushort)j;

    if (mask == 0)
        return Success;

    /* We always only use mksidx = AllDevices for events not bound to
     * devices */
    if (AddExtensionClient(win, client, mask, XIAllDevices) != Success)
        return BadAlloc;

    RecalculateDeviceDeliverableEvents(win);

    return Success;
}

/***********************************************************************
 *
 * This procedure selects input from an extension device.
 *
 */

int ProcXSelectExtensionEvent(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xSelectExtensionEventReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD16!"count");
    mixin(X_REQUEST_REST_COUNT_CARD32!("stuff.count"));

    int ret = void;
    int i = void;
    WindowPtr pWin = void;
    tmask[EMASKSIZE] tmp = void;

    ret = dixLookupWindow(&pWin, stuff.window, client, DixReceiveAccess);
    if (ret != Success)
        return ret;

    if (HandleDevicePresenceMask(client, pWin, cast(XEventClass*) &stuff[1],
                                 &stuff.count) != Success)
        return BadAlloc;

    if ((ret = CreateMaskFromList(client, cast(XEventClass*) &stuff[1],
                                  stuff.count, tmp.ptr, null,
                                  X_SelectExtensionEvent)) != Success)
        return ret;

    for (i = 0; i < EMASKSIZE; i++)
        if (tmp[i].dev !is null) {
            if (tmp[i].mask & ~XIAllMasks) {
                client.errorValue = cast(uint)tmp[i].mask;
                return BadValue;
            }
            if ((ret =
                 SelectForWindow(cast(DeviceIntPtr) tmp[i].dev, pWin, client,
                                 tmp[i].mask, DeviceButtonGrabMask)) != Success)
                return ret;
        }

    return Success;
}
