module Xi.getfctl;
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
 *  Get feedback control attributes for an extension device.
 *
 */

import build.dix_config;

//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import Xi.handlers;

import dix.inputstr;           /* DeviceIntPtr      */
import externs.X11.extensions.XIproto;
import externs.X11.extensions.XI;
import dix.devices;
import common.swap;




/***********************************************************************
 *
 * This procedure copies KbdFeedbackClass data, swapping if necessary.
 *
 */

private void CopySwapKbdFeedback(ClientPtr client, KbdFeedbackPtr k, char** buf)
{
    int i = void;
    xKbdFeedbackState* k2 = void;

    k2 = cast(xKbdFeedbackState*) * buf;
    k2.class_ = KbdFeedbackClass;
    k2.length = xKbdFeedbackState.sizeof;
    k2.id = k.ctrl.id;
    k2.click = cast(ubyte)k.ctrl.click;
    k2.percent = cast(ubyte)k.ctrl.bell;
    k2.pitch = cast(ushort)k.ctrl.bell_pitch;
    k2.duration = cast(ushort)k.ctrl.bell_duration;
    k2.led_mask = cast(uint)k.ctrl.leds;
    k2.led_values = cast(uint)k.ctrl.leds;
    k2.global_auto_repeat = cast(ubyte)k.ctrl.autoRepeat;
    for (i = 0; i < 32; i++)
        k2.auto_repeats[i] = k.ctrl.autoRepeats[i];
    if (client.swapped) {
        swaps(&k2.length);
        swaps(&k2.pitch);
        swaps(&k2.duration);
        swapl(&k2.led_mask);
        swapl(&k2.led_values);
    }
    *buf += xKbdFeedbackState.sizeof;
}

/***********************************************************************
 *
 * This procedure copies PtrFeedbackClass data, swapping if necessary.
 *
 */

private void CopySwapPtrFeedback(ClientPtr client, PtrFeedbackPtr p, char** buf)
{
    xPtrFeedbackState* p2 = void;

    p2 = cast(xPtrFeedbackState*) * buf;
    p2.class_ = PtrFeedbackClass;
    p2.length = xPtrFeedbackState.sizeof;
    p2.id = p.ctrl.id;
    p2.accelNum = cast(ushort)p.ctrl.num;
    p2.accelDenom = cast(ushort)p.ctrl.den;
    p2.threshold = cast(ushort)p.ctrl.threshold;
    if (client.swapped) {
        swaps(&p2.length);
        swaps(&p2.accelNum);
        swaps(&p2.accelDenom);
        swaps(&p2.threshold);
    }
    *buf += xPtrFeedbackState.sizeof;
}

/***********************************************************************
 *
 * This procedure copies IntegerFeedbackClass data, swapping if necessary.
 *
 */

private void CopySwapIntegerFeedback(ClientPtr client, IntegerFeedbackPtr i, char** buf)
{
    xIntegerFeedbackState* i2 = void;

    i2 = cast(xIntegerFeedbackState*) * buf;
    i2.class_ = IntegerFeedbackClass;
    i2.length = xIntegerFeedbackState.sizeof;
    i2.id = i.ctrl.id;
    i2.resolution = i.ctrl.resolution;
    i2.min_value = i.ctrl.min_value;
    i2.max_value = i.ctrl.max_value;
    if (client.swapped) {
        swaps(&i2.length);
        swapl(&i2.resolution);
        swapl(&i2.min_value);
        swapl(&i2.max_value);
    }
    *buf += xIntegerFeedbackState.sizeof;
}

/***********************************************************************
 *
 * This procedure copies StringFeedbackClass data, swapping if necessary.
 *
 */

private void CopySwapStringFeedback(ClientPtr client, StringFeedbackPtr s, char** buf)
{
    int i = void;
    xStringFeedbackState* s2 = void;
    KeySym* kptr = void;

    s2 = cast(xStringFeedbackState*) * buf;
    s2.class_ = StringFeedbackClass;
    s2.length = cast(ushort)(xStringFeedbackState.sizeof +
        s.ctrl.num_symbols_supported * KeySym.sizeof);
    s2.id = s.ctrl.id;
    s2.max_symbols = cast(ushort)s.ctrl.max_symbols;
    s2.num_syms_supported = cast(ushort)s.ctrl.num_symbols_supported;
    *buf += xStringFeedbackState.sizeof;
    kptr = cast(KeySym*) (*buf);
    for (i = 0; i < s.ctrl.num_symbols_supported; i++)
        *kptr++ = *(s.ctrl.symbols_supported + i);
    if (client.swapped) {
        swaps(&s2.length);
        swaps(&s2.max_symbols);
        swaps(&s2.num_syms_supported);
        kptr = cast(KeySym*) (*buf);
        for (i = 0; i < s.ctrl.num_symbols_supported; i++, kptr++) {
            swapl(kptr);
        }
    }
    *buf += (s.ctrl.num_symbols_supported * KeySym.sizeof);
}

/***********************************************************************
 *
 * This procedure copies LedFeedbackClass data, swapping if necessary.
 *
 */

private void CopySwapLedFeedback(ClientPtr client, LedFeedbackPtr l, char** buf)
{
    xLedFeedbackState* l2 = void;

    l2 = cast(xLedFeedbackState*) * buf;
    l2.class_ = LedFeedbackClass;
    l2.length = xLedFeedbackState.sizeof;
    l2.id = l.ctrl.id;
    l2.led_values = cast(uint)l.ctrl.led_values;
    l2.led_mask = cast(uint)l.ctrl.led_mask;
    if (client.swapped) {
        swaps(&l2.length);
        swapl(&l2.led_values);
        swapl(&l2.led_mask);
    }
    *buf += xLedFeedbackState.sizeof;
}

/***********************************************************************
 *
 * This procedure copies BellFeedbackClass data, swapping if necessary.
 *
 */

private void CopySwapBellFeedback(ClientPtr client, BellFeedbackPtr b, char** buf)
{
    xBellFeedbackState* b2 = void;

    b2 = cast(xBellFeedbackState*) * buf;
    b2.class_ = BellFeedbackClass;
    b2.length = xBellFeedbackState.sizeof;
    b2.id = b.ctrl.id;
    b2.percent = cast(ubyte)b.ctrl.percent;
    b2.pitch = cast(ushort)b.ctrl.pitch;
    b2.duration = cast(ushort)b.ctrl.duration;
    if (client.swapped) {
        swaps(&b2.length);
        swaps(&b2.pitch);
        swaps(&b2.duration);
    }
    *buf += xBellFeedbackState.sizeof;
}

/***********************************************************************
 *
 * Get the feedback control state.
 *
 */

int ProcXGetFeedbackControl(ClientPtr client)
{
    int rc = void, total_length = 0;
    DeviceIntPtr dev = void;
    KbdFeedbackPtr k = void;
    PtrFeedbackPtr p = void;
    IntegerFeedbackPtr i = void;
    StringFeedbackPtr s = void;
    BellFeedbackPtr b = void;
    LedFeedbackPtr l = void;

    mixin(X_REQUEST_HEAD_STRUCT!xGetFeedbackControlReq);

    rc = dixLookupDevice(&dev, stuff.deviceid, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    xGetFeedbackControlReply reply = {
        RepType: X_GetFeedbackControl,
    };

    for (k = dev.kbdfeed; k; k = k.next) {
        reply.num_feedbacks++;
        total_length += xKbdFeedbackState.sizeof;
    }
    for (p = dev.ptrfeed; p; p = p.next) {
        reply.num_feedbacks++;
        total_length += xPtrFeedbackState.sizeof;
    }
    for (s = dev.stringfeed; s; s = s.next) {
        reply.num_feedbacks++;
        total_length += ((xStringFeedbackState).sizeof +
            (s.ctrl.num_symbols_supported * KeySym.sizeof));
    }
    for (i = dev.intfeed; i; i = i.next) {
        reply.num_feedbacks++;
        total_length += xIntegerFeedbackState.sizeof;
    }
    for (l = dev.leds; l; l = l.next) {
        reply.num_feedbacks++;
        total_length += xLedFeedbackState.sizeof;
    }
    for (b = dev.bell; b; b = b.next) {
        reply.num_feedbacks++;
        total_length += xBellFeedbackState.sizeof;
    }

    if (total_length == 0)
        return BadMatch;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: True };
    char* buf = cast(char*)x_rpcbuf_reserve(&rpcbuf, total_length);

    for (k = dev.kbdfeed; k; k = k.next)
        CopySwapKbdFeedback(client, k, &buf);
    for (p = dev.ptrfeed; p; p = p.next)
        CopySwapPtrFeedback(client, p, &buf);
    for (s = dev.stringfeed; s; s = s.next)
        CopySwapStringFeedback(client, s, &buf);
    for (i = dev.intfeed; i; i = i.next)
        CopySwapIntegerFeedback(client, i, &buf);
    for (l = dev.leds; l; l = l.next)
        CopySwapLedFeedback(client, l, &buf);
    for (b = dev.bell; b; b = b.next)
        CopySwapBellFeedback(client, b, &buf);

    mixin(X_REPLY_FIELD_CARD16!"num_feedbacks");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}
