module Xi.closedev;
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
 * Extension function to close an extension input device.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.request_priv;
import dix.resource_priv;
import dix.screenint_priv;
import dix.window_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import include.windowstr;          /* window structure  */
import include.scrnintstr;         /* screen structure  */
import Xi.XIstubs;
import dix.resource;
import dix.devices;

/***********************************************************************
 *
 * Clear out event selections and passive grabs from a window for the
 * specified device.
 *
 */

private void DeleteDeviceEvents(DeviceIntPtr dev, WindowPtr pWin, ClientPtr client)
{
    InputClientsPtr others = void;
    OtherInputMasks* pOthers = void;
    GrabPtr grab = void, next = void;

    if ((pOthers = mixin(wOtherInputMasks!("pWin")) )!is null)
        for (others = pOthers.inputClients; others; others = others.next)
            if (mixin(SameClient!("others", "client")))
                others.mask[dev.id] = NoEventMask;

    for (grab = mixin(wPassiveGrabs!("pWin")); grab; grab = next) {
        next = grab.next;
        if ((grab.device == dev) &&
            (client.clientAsMask == CLIENT_BITS(grab.resource)))
            FreeResource(cast(uint)grab.resource, X11_RESTYPE_NONE);
    }
}

/***********************************************************************
 *
 * Walk through the window tree, deleting event selections for this client
 * from this device from all windows.
 *
 */

private void DeleteEventsFromChildren(DeviceIntPtr dev, WindowPtr p1, ClientPtr client)
{
    WindowPtr p2 = void;

    while (p1) {
        p2 = p1.firstChild;
        DeleteDeviceEvents(dev, p1, client);
        DeleteEventsFromChildren(dev, p2, client);
        p1 = p1.nextSib;
    }
}

/***********************************************************************
 *
 * This procedure closes an input device.
 *
 */

int ProcXCloseDevice(ClientPtr client)
{
    int rc = void;
    DeviceIntPtr d = void;

    mixin(X_REQUEST_HEAD_STRUCT!xCloseDeviceReq);

    rc = dixLookupDevice(&d, stuff.deviceid, client, DixUseAccess);
    if (rc != Success)
        return rc;

    if (d.deviceGrab.grab && mixin(SameClient!("d.deviceGrab.grab", "client")))
        (*d.deviceGrab.DeactivateGrab) (d);    /* release active grab */

    /* Remove event selections from all windows for events from this device
     * and selected by this client.
     * Delete passive grabs from all windows for this device.      */

    mixin(DIX_FOR_EACH_SCREEN!q{
        DeleteDeviceEvents(d, walkScreen.root, client);
        DeleteEventsFromChildren(d, walkScreen.root.firstChild, client);
    });

    return Success;
}
