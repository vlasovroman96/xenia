module Xi.exglobals;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Copyright 1996 by Thomas E. Dickey <dickey@clark.net>

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of the above listed
copyright holder(s) not be used in advertising or publicity pertaining
to distribution of the software without specific, written prior
permission.

THE ABOVE LISTED COPYRIGHT HOLDER(S) DISCLAIM ALL WARRANTIES WITH REGARD
TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS, IN NO EVENT SHALL THE ABOVE LISTED COPYRIGHT HOLDER(S) BE
LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.

********************************************************/

/*****************************************************************
 *
 * Globals referenced elsewhere in the server.
 *
 */

version (EXGLOBALS_H) {} else {
enum EXGLOBALS_H = 1;

public import dix.exevents_priv;
public import dix.privates;
public import Xi.extinit;

// int IEventBase;
// int BadDevice;
// int BadMode;
// int DeviceBusy;
// int BadClass;

/* Note: only the ones needed in files other than extinit.c are declared */
// const(Mask) DevicePointerMotionHintMask;
// const(Mask) DeviceFocusChangeMask;
// const(Mask) DeviceStateNotifyMask;
// const(Mask) DeviceMappingNotifyMask;
// const(Mask) DeviceOwnerGrabButtonMask;
// const(Mask) DeviceButtonGrabMask;
// const(Mask) DeviceButtonMotionMask;
// const(Mask) DevicePresenceNotifyMask;
// const(Mask) DevicePropertyNotifyMask;
// const(Mask) XIAllMasks;

// int DeviceValuator;
// int DeviceKeyPress;
// int DeviceKeyRelease;
// int DeviceButtonPress;
// int DeviceButtonRelease;
// int DeviceMotionNotify;
// int DeviceFocusIn;
// int DeviceFocusOut;
// int ProximityIn;
// int ProximityOut;
// int DeviceStateNotify;
// int DeviceKeyStateNotify;
// int DeviceButtonStateNotify;
// int DeviceMappingNotify;
// int ChangeDeviceNotify;
// int DevicePresenceNotify;
// int DevicePropertyNotify;

// RESTYPE RT_INPUTCLIENT;

// DevPrivateKeyRec XIClientPrivateKeyRec;

pragma(inline, true) XIClientPtr XIClientPriv(ClientPtr client) {
    return cast(XIClientPtr)dixLookupPrivate(&client.devPrivates, &XIClientPrivateKeyRec);
}

}                          /* EXGLOBALS_H */
