module xkb.xkb.xkb;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/************************************************************
Copyright (c) 1993 by Silicon Graphics Computer Systems, Inc.

Permission to use, copy, modify, and distribute this
software and its documentation for any purpose and without
fee is hereby granted, provided that the above copyright
notice appear in all copies and that both that copyright
notice and this permission notice appear in supporting
documentation, and that the name of Silicon Graphics not be
used in advertising or publicity pertaining to distribution
of the software without specific prior written permission.
Silicon Graphics makes no representation about the suitability
of this software for any purpose. It is provided "as is"
without any express or implied warranty.

SILICON GRAPHICS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL SILICON
GRAPHICS BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION  WITH
THE USE OR PERFORMANCE OF THIS SOFTWARE.

********************************************************/

import build.dix_config;

import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
//import externs.X11.extensions.XI;
import externs.X11.extensions.XKB;
import externs.X11.extensions.XKM;

import xkb.XKBMAlloc;

import dix.devices_priv;
import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.server_priv;
import miext.extinit_priv;
import os.osdep;
import xkb.xkbfmisc_priv;
public import xkb.xkbsrv_priv;
import dix.atom;
import common.misc;
import dix.inputstr;
import xkb.xkb_procs;
import common.protocol_versions;
import include.xkbstr;
import os.log;
import dix.events;
import dix.devices;

import externs.X11.extensions.XKBproto;
import xkb.XKBGAlloc;
import dix.extension;

// import externs.X11.extensions.XKBgeom;

public enum XkbSA_DeviceValuator = 0x14;
public enum XkbSA_LastAction = 0x14;

enum XkbAllStateEventsMask =		XkbAllStateComponentsMask;
enum XkbAllMapEventsMask =		XkbAllMapComponentsMask;
enum XkbAllControlEventsMask =		XkbAllControlsMask;
enum XkbAllIndicatorEventsMask =	XkbAllIndicatorsMask;
enum XkbAllNameEventsMask =		XkbAllNamesMask;
enum XkbAllCompatMapEventsMask =	XkbAllCompatMask;
enum XkbAllBellEventsMask =		(1L << 0);
enum XkbAllActionMessagesMask =	(1L << 0);

// int XkbEventBase;
private int XkbErrorBase;
// int XkbReqCode;
// int XkbKeyboardErrorCode;
// CARD32 xkbDebugFlags = 0;
private CARD32 xkbDebugCtrls = 0;

// RESTYPE RT_XKBCLIENT = 0;

alias XkbNumRequiredTypes = xkb.XKBMAlloc.XkbNumRequiredTypes;
alias UINT32_MAX = core.stdc.stdint.UINT32_MAX;

enum string	CHK_DEVICE(string dev, string id, string client, string access_mode, string lf) = `{
    int why = void;
    int tmprc = ` ~ lf ~ `(&(` ~ dev ~ `), ` ~ id ~ `, ` ~ client ~ `, ` ~ access_mode ~ `, &why);
    if (tmprc != Success) {
	` ~ client ~ `.errorValue = mixin(_XkbErrCode2!("why", "` ~ id ~ `"));
	return tmprc;
    }
}`;

enum string	CHK_KBD_DEVICE(string dev, string id, string client, string mode) = `
    ` ~ CHK_DEVICE!(dev, id, client, mode, `_XkbLookupKeyboard`) ~ ``;
enum string	CHK_LED_DEVICE(string dev, string id, string client, string mode) = `
    ` ~ CHK_DEVICE!(dev, id, client, mode, `_XkbLookupLedDevice`) ~ ``;
enum string	CHK_BELL_DEVICE(string dev, string id, string client, string mode) = `
    ` ~ CHK_DEVICE!(dev, id, client, mode, `_XkbLookupBellDevice`) ~ ``;
enum string	CHK_ANY_DEVICE(string dev, string id, string client, string mode) = `
    ` ~ CHK_DEVICE!(dev, id, client, mode, `_XkbLookupAnyDevice`) ~ ``;

enum string	CHK_ATOM_ONLY2(string a,string ev,string er) = `{
	if (((` ~ a ~ `)==None)||(!ValidAtom((` ~ a ~ `)))) {
	    (` ~ ev ~ `)= cast(XID)(` ~ a ~ `);
	    return ` ~ er ~ `;
	}
}`;
enum string	CHK_ATOM_ONLY(string a) = `
	` ~ CHK_ATOM_ONLY2!(a,`client.errorValue`,`BadAtom`) ~ ``;

enum string	CHK_ATOM_OR_NONE3(string a,string ev,string er,string ret) = `{
	if (((` ~ a ~ `)!=None)&&(!ValidAtom((` ~ a ~ `)))) {
	    (` ~ ev ~ `)= cast(XID)(` ~ a ~ `);
	    (` ~ er ~ `)= BadAtom;
	    return ` ~ ret ~ `;
	}
}`;
enum string	CHK_ATOM_OR_NONE2(string a,string ev,string er) = `{
	if (((` ~ a ~ `)!=None)&&(!ValidAtom((` ~ a ~ `)))) {
	    (` ~ ev ~ `)= cast(XID)(` ~ a ~ `);
	    return ` ~ er ~ `;
	}
}`;
enum string	CHK_ATOM_OR_NONE(string a) = `
	` ~ CHK_ATOM_OR_NONE2!(a,`client.errorValue`,`BadAtom`) ~ ``;

enum string	CHK_MASK_LEGAL3(string err,string mask,string legal,string ev,string er,string ret) = `{
	if ((` ~ mask ~ `)&(~(` ~ legal ~ `))) { 
	    (` ~ ev ~ `)= `~_XkbErrCode2!(err,`((` ~ mask ~ `)&(~(` ~ legal ~ `)))`)~`;
	    (` ~ er ~ `)= BadValue;
	    return ` ~ ret ~ `;
	}
}`;
enum string	CHK_MASK_LEGAL2(string err,string mask,string legal,string ev,string er) = `{
	if ((` ~ mask ~ `)&(~(` ~ legal ~ `))) { 
	    (` ~ ev ~ `)= `~_XkbErrCode2!(err,`((`~mask~`)&(~(` ~ legal ~ `)))`)~`;
	    return (` ~ er ~ `);
	}
}`;
enum string	CHK_MASK_LEGAL(string err,string mask,string legal) = `
	` ~ CHK_MASK_LEGAL2!(err,mask,legal,`client.errorValue`,`BadValue`) ~ ``;

enum string	CHK_MASK_MATCH(string err,string affect,string value) = `{
	if ((` ~ value ~ `)&(~(` ~ affect ~ `))) { 
	    client.errorValue= `~_XkbErrCode2!(err,value ~`&(~(` ~ affect ~ `))`)~`;
	    return BadMatch;
	}
}`;
enum string	CHK_MASK_OVERLAP(string err,string m1,string m2) = `{
	if ((` ~ m1 ~ `)&(` ~ m2 ~ `)) { 
	    client.errorValue= `~_XkbErrCode2!((err),`((` ~ m1 ~ `)&(` ~ m2 ~ `))`)~`;
	    return BadMatch;
	}
}`;
enum string	CHK_KEY_RANGE2(string err,string first,string num,string x,string ev,string er) = `{
	if ((cast(uint)(` ~ first ~ `)+(` ~ num ~ `)-1)>(((` ~ x ~ `).max_key_code))) {
	    (` ~ ev ~ `)=`~_XkbErrCode4!(err,first,num,`(` ~ x ~ `).max_key_code`)~`;
	    return (` ~ er ~ `);
	}
	else if ( (` ~ first ~ `)<(((` ~ x ~ `).min_key_code)) ) {
	    (` ~ ev ~ `)=`~_XkbErrCode3!(`(` ~ err ~ `)+1`,first,`xkb.min_key_code`)~`;
	    return (` ~ er ~ `);
	}
}`;

enum string	CHK_KEY_RANGE(string err,string first,string num,string x) = `
	` ~ CHK_KEY_RANGE2!(err,first,num,x,`client.errorValue`,`BadValue`);

enum string	CHK_REQ_KEY_RANGE2(string err,string first,string num,string r,string ev,string er) = `{
	if ((cast(uint)(` ~ first ~ `)+(` ~ num ~ `)-1)>(((` ~ r ~ `).maxKeyCode))) {
	    (` ~ ev ~ `)=`~_XkbErrCode4!(err,first,num,`(` ~ r ~ `).maxKeyCode`)~`;
	    return (` ~ er ~ `);
	}
	else if ( (` ~ first ~ `)<(((` ~ r ~ `).minKeyCode)) ) {
	    (` ~ ev ~ `)=`~_XkbErrCode3!((err~`+1`),first,`(` ~ r ~ `).minKeyCode`)~`;
	    return (` ~ er ~ `);
	}
}`;
enum string	CHK_REQ_KEY_RANGE(string err,string first,string num,string r) = `
	` ~ CHK_REQ_KEY_RANGE2!(err,first,num,r,`client.errorValue`,`BadValue`) ~ ``;

private Bool _XkbCheckRequestBounds(ClientPtr client, void* stuff, void* from, void* to) {
    char* cstuff = cast(char*)stuff;
    char* cfrom = cast(char*)from;
    char* cto = cast(char*)to;

    return cfrom < cto &&
           cfrom >= cstuff &&
           cfrom < cstuff + (cast(size_t)client.req_len << 2) &&
           cto >= cstuff &&
           cto <= cstuff + (cast(size_t)client.req_len << 2);
}

int ProcXkbUseExtension(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbUseExtensionReq);
    mixin(X_REQUEST_FIELD_CARD16!"wantedMajor");
    mixin(X_REQUEST_FIELD_CARD16!"wantedMinor");

    int supported = void;

    if (stuff.wantedMajor != SERVER_XKB_MAJOR_VERSION) {
        /* pre-release version 0.65 is compatible with 1.00 */
        supported = ((SERVER_XKB_MAJOR_VERSION == 1) &&
                     (stuff.wantedMajor == 0) && (stuff.wantedMinor == 65));
    }
    else
        supported = 1;

    if ((supported) && (!(client.xkbClientFlags & _XkbClientInitialized))) {
        client.xkbClientFlags = _XkbClientInitialized;
        if (stuff.wantedMajor == 0)
            client.xkbClientFlags |= _XkbClientIsAncient;
    }
    else if (xkbDebugFlags & 0x1) {
        ErrorF
            ("[xkb] Rejecting client %d (0x%lx) (wants %d.%02d, have %d.%02d)\n",
             client.index, cast(c_long) client.clientAsMask, stuff.wantedMajor,
             stuff.wantedMinor, SERVER_XKB_MAJOR_VERSION,
             SERVER_XKB_MINOR_VERSION);
    }

    xkbUseExtensionReply reply = {
        supported: cast(ubyte)supported,
        serverMajor: SERVER_XKB_MAJOR_VERSION,
        serverMinor: SERVER_XKB_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!"serverMajor");
    mixin(X_REPLY_FIELD_CARD16!"serverMinor");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcXkbSelectEvents(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSelectEventsReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"affectWhich");
    mixin(X_REQUEST_FIELD_CARD16!"clear");
    mixin(X_REQUEST_FIELD_CARD16!"selectAll");
    mixin(X_REQUEST_FIELD_CARD16!"affectMap");
    mixin(X_REQUEST_FIELD_CARD16!"map");
    /* more swapping done down below */

    if (client.swapped) {
        if ((stuff.affectWhich & (~XkbMapNotifyMask)) != 0) {
            union _From {
                BOOL* b = void;
                CARD8* c8 = void;
                CARD16* c16 = void;
                CARD32* c32 = void;
            }_From from = void;
            uint bit = void, ndx = void, maskLeft = void, dataLeft = void;

            from.c8 = cast(CARD8*) &stuff[1];
            dataLeft = cast(uint)((client.req_len * 4) - xkbSelectEventsReq.sizeof);
            maskLeft = (stuff.affectWhich & (~XkbMapNotifyMask));
            for (ndx = 0, bit = 1; (maskLeft != 0); ndx++, bit <<= 1) {
                if (((bit & maskLeft) == 0) || (ndx == XkbMapNotify))
                    continue;
                maskLeft &= ~bit;
                if ((stuff.selectAll & bit) || (stuff.clear & bit))
                    continue;
                switch (ndx) {
                    // CARD16
                    case XkbNewKeyboardNotify:
                    case XkbStateNotify:
                    case XkbNamesNotify:
                    case XkbAccessXNotify:
                    case XkbExtensionDeviceNotify:
                        if (dataLeft < ((CARD16)*2).sizeof)
                            return BadLength;
                        swaps(&from.c16[0]);
                        swaps(&from.c16[1]);
                        from.c8 += ((CARD16)*2).sizeof;
                        dataLeft -= ((CARD16)*2).sizeof;
                    break;
                    // CARD32
                    case XkbControlsNotify:
                    case XkbIndicatorStateNotify:
                    case XkbIndicatorMapNotify:
                        if (dataLeft < ((CARD32).sizeof*2))
                            return BadLength;
                        swapl(&from.c32[0]);
                        swapl(&from.c32[1]);
                        from.c8 += ((CARD32).sizeof*2);
                        dataLeft -= ((CARD32).sizeof*2);
                    break;
                    // CARD8
                    case XkbBellNotify:
                    case XkbActionMessage:
                    case XkbCompatMapNotify:
                        if (dataLeft < 2)
                            return BadLength;
                        from.c8 += 4;
                        dataLeft -= 4;
                    break;
                    default:
                        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x1", "bit"));
                        return BadValue;
                }
            }
            if (dataLeft > 2) {
                ErrorF("[xkb] Extra data (%d bytes) after SelectEvents\n", dataLeft);
                return BadLength;
            }
        }
    }

    uint legal = void;
    DeviceIntPtr dev = void;
    XkbInterestPtr masks = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_ANY_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixUseAccess`));

    if (((stuff.affectWhich & XkbMapNotifyMask) != 0) && (stuff.affectMap)) {
        client.mapNotifyMask &= ~stuff.affectMap;
        client.mapNotifyMask |= (stuff.affectMap & stuff.map);
    }
    if ((stuff.affectWhich & (~XkbMapNotifyMask)) == 0)
        return Success;

    masks = XkbFindClientResource(cast(DevicePtr) dev, client);
    if (!masks) {
        XID id = FakeClientID(client.index);

        if (!AddResource(cast(uint)id, RT_XKBCLIENT, dev))
            return BadAlloc;
        masks = XkbAddClientResource(cast(DevicePtr) dev, client, id);
    }
    if (masks) {
        union _From {
            CARD8* c8 = void;
            CARD16* c16 = void;
            CARD32* c32 = void;
        }_From from = void,  to = void;
        uint bit = void, ndx = void, maskLeft = void, dataLeft = void, size = void;

        from.c8 = cast(CARD8*) &stuff[1];
        dataLeft = cast(uint)((client.req_len * 4) - xkbSelectEventsReq.sizeof);
        maskLeft = (stuff.affectWhich & (~XkbMapNotifyMask));
        for (ndx = 0, bit = 1; (maskLeft != 0); ndx++, bit <<= 1) {
            if ((bit & maskLeft) == 0)
                continue;
            maskLeft &= ~bit;
            switch (ndx) {
            case XkbNewKeyboardNotify:
                to.c16 = &client.newKeyboardNotifyMask;
                legal = XkbAllNewKeyboardEventsMask;
                size = 2;
                break;
            case XkbStateNotify:
                to.c16 = &masks.stateNotifyMask;
                legal = XkbAllStateEventsMask;
                size = 2;
                break;
            case XkbControlsNotify:
                to.c32 = &masks.ctrlsNotifyMask;
                legal = XkbAllControlEventsMask;
                size = 4;
                break;
            case XkbIndicatorStateNotify:
                to.c32 = &masks.iStateNotifyMask;
                legal = XkbAllIndicatorEventsMask;
                size = 4;
                break;
            case XkbIndicatorMapNotify:
                to.c32 = &masks.iMapNotifyMask;
                legal = XkbAllIndicatorEventsMask;
                size = 4;
                break;
            case XkbNamesNotify:
                to.c16 = &masks.namesNotifyMask;
                legal = XkbAllNameEventsMask;
                size = 2;
                break;
            case XkbCompatMapNotify:
                to.c8 = &masks.compatNotifyMask;
                legal = XkbAllCompatMapEventsMask;
                size = 1;
                break;
            case XkbBellNotify:
                to.c8 = &masks.bellNotifyMask;
                legal = cast(uint)XkbAllBellEventsMask;
                size = 1;
                break;
            case XkbActionMessage:
                to.c8 = &masks.actionMessageMask;
                legal = cast(uint)XkbAllActionMessagesMask;
                size = 1;
                break;
            case XkbAccessXNotify:
                to.c16 = &masks.accessXNotifyMask;
                legal = XkbAllAccessXEventsMask;
                size = 2;
                break;
            case XkbExtensionDeviceNotify:
                to.c16 = &masks.extDevNotifyMask;
                legal = XkbAllExtensionDeviceEventsMask;
                size = 2;
                break;
            default:
                client.errorValue = cast(uint)mixin(_XkbErrCode2!("33", "bit"));
                return BadValue;
            }

            if (stuff.clear & bit) {
                if (size == 2)
                    to.c16[0] = 0;
                else if (size == 4)
                    to.c32[0] = 0;
                else
                    to.c8[0] = 0;
            }
            else if (stuff.selectAll & bit) {
                if (size == 2)
                    to.c16[0] = cast(ushort)~0;
                else if (size == 4)
                    to.c32[0] = ~0;
                else
                    to.c8[0] = cast(ubyte)~0;
            }
            else {
                if (dataLeft < (size * 2))
                    return BadLength;
                if (size == 2) {
                    mixin(CHK_MASK_MATCH!(`ndx`, `from.c16[0]`, `from.c16[1]`));
                    mixin(CHK_MASK_LEGAL!(`ndx`, `from.c16[0]`, `legal`));
                    to.c16[0] &= ~from.c16[0];
                    to.c16[0] |= (from.c16[0] & from.c16[1]);
                }
                else if (size == 4) {
                    mixin(CHK_MASK_MATCH!(`ndx`, `from.c32[0]`, `from.c32[1]`));
                    mixin(CHK_MASK_LEGAL!(`ndx`, `from.c32[0]`, `legal`));
                    to.c32[0] &= ~from.c32[0];
                    to.c32[0] |= (from.c32[0] & from.c32[1]);
                }
                else {
                    mixin(CHK_MASK_MATCH!(`ndx`, `from.c8[0]`, `from.c8[1]`));
                    mixin(CHK_MASK_LEGAL!(`ndx`, `from.c8[0]`, `legal`));
                    to.c8[0] &= ~from.c8[0];
                    to.c8[0] |= (from.c8[0] & from.c8[1]);
                    size = 2;
                }
                from.c8 += (size * 2);
                dataLeft -= (size * 2);
            }
        }
        if (dataLeft > 2) {
            ErrorF("[xkb] Extra data (%d bytes) after SelectEvents\n",
                   dataLeft);
            return BadLength;
        }
        return Success;
    }
    return BadAlloc;
}

/**
 * Ring a bell on the given device for the given client.
 */
private int _XkbBell(ClientPtr client, DeviceIntPtr dev, WindowPtr pWin, int bellClass, int bellID, int pitch, int duration, int percent, int forceSound, int eventOnly, Atom name)
{
    int base = void;
    void* ctrl = void;
    int oldPitch = void, oldDuration = void;
    int newPercent = void;

    if (bellClass == KbdFeedbackClass) {
        KbdFeedbackPtr k = void;

        if (bellID == XkbDfltXIId)
            k = dev.kbdfeed;
        else {
            for (k = dev.kbdfeed; k; k = k.next) {
                if (k.ctrl.id == bellID)
                    break;
            }
        }
        if (!k) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x5", "bellID"));
            return BadValue;
        }
        base = k.ctrl.bell;
        ctrl = cast(void*) &(k.ctrl);
        oldPitch = k.ctrl.bell_pitch;
        oldDuration = k.ctrl.bell_duration;
        if (pitch != 0) {
            if (pitch == -1)
                k.ctrl.bell_pitch = defaultKeyboardControl.bell_pitch;
            else
                k.ctrl.bell_pitch = pitch;
        }
        if (duration != 0) {
            if (duration == -1)
                k.ctrl.bell_duration = defaultKeyboardControl.bell_duration;
            else
                k.ctrl.bell_duration = duration;
        }
    }
    else if (bellClass == BellFeedbackClass) {
        BellFeedbackPtr b = void;

        if (bellID == XkbDfltXIId)
            b = dev.bell;
        else {
            for (b = dev.bell; b; b = b.next) {
                if (b.ctrl.id == bellID)
                    break;
            }
        }
        if (!b) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x6", "bellID"));
            return BadValue;
        }
        base = b.ctrl.percent;
        ctrl = cast(void*) &(b.ctrl);
        oldPitch = b.ctrl.pitch;
        oldDuration = b.ctrl.duration;
        if (pitch != 0) {
            if (pitch == -1)
                b.ctrl.pitch = defaultKeyboardControl.bell_pitch;
            else
                b.ctrl.pitch = pitch;
        }
        if (duration != 0) {
            if (duration == -1)
                b.ctrl.duration = defaultKeyboardControl.bell_duration;
            else
                b.ctrl.duration = duration;
        }
    }
    else {
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x7", "bellClass"));
        return BadValue;
    }

    newPercent = (base * percent) / 100;
    if (percent < 0)
        newPercent = base + newPercent;
    else
        newPercent = base - newPercent + percent;

    XkbHandleBell(cast(ubyte)forceSound, cast(ubyte)eventOnly,
                  dev, cast(ubyte)newPercent, ctrl, cast(ubyte)bellClass, name, pWin, client);
    if ((pitch != 0) || (duration != 0)) {
        if (bellClass == KbdFeedbackClass) {
            KbdFeedbackPtr k = void;

            k = cast(KbdFeedbackPtr) ctrl;
            if (pitch != 0)
                k.ctrl.bell_pitch = oldPitch;
            if (duration != 0)
                k.ctrl.bell_duration = oldDuration;
        }
        else {
            BellFeedbackPtr b = void;

            b = cast(BellFeedbackPtr) ctrl;
            if (pitch != 0)
                b.ctrl.pitch = oldPitch;
            if (duration != 0)
                b.ctrl.duration = oldDuration;
        }
    }

    return Success;
}

int ProcXkbBell(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbBellReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"bellClass");
    mixin(X_REQUEST_FIELD_CARD16!"bellID");
    mixin(X_REQUEST_FIELD_CARD32!"name");
    mixin(X_REQUEST_FIELD_CARD32!"window");
    mixin(X_REQUEST_FIELD_CARD16!"pitch");
    mixin(X_REQUEST_FIELD_CARD16!"duration");

    DeviceIntPtr dev = void;
    WindowPtr pWin = void;
    int rc = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_BELL_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixBellAccess`));
    mixin(CHK_ATOM_OR_NONE!(`stuff.name`));

    /* device-independent checks request for sane values */
    if ((stuff.forceSound) && (stuff.eventOnly)) {
        client.errorValue =
            mixin(_XkbErrCode3!(`0x1`, `stuff.forceSound`, `stuff.eventOnly`));
        return BadMatch;
    }
    if (stuff.percent < -100 || stuff.percent > 100) {
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x2", "stuff.percent"));
        return BadValue;
    }
    if (stuff.duration < -1) {
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x3", "stuff.duration"));
        return BadValue;
    }
    if (stuff.pitch < -1) {
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x4", "stuff.pitch"));
        return BadValue;
    }

    if (stuff.bellClass == XkbDfltXIClass) {
        if (dev.kbdfeed !is null)
            stuff.bellClass = KbdFeedbackClass;
        else
            stuff.bellClass = BellFeedbackClass;
    }

    if (stuff.window != None) {
        rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
        if (rc != Success) {
            client.errorValue = cast(uint)stuff.window;
            return rc;
        }
    }
    else
        pWin = null;

    /* Client wants to ring a bell on the core keyboard?
       Ring the bell on the core keyboard (which does nothing, but if that
       fails the client is screwed anyway), and then on all extension devices.
       Fail if the core keyboard fails but not the extension devices.  this
       may cause some keyboards to ding and others to stay silent. Fix
       your client to use explicit keyboards to avoid this.

       dev is the device the client requested.
     */
    rc = _XkbBell(client, dev, pWin, stuff.bellClass, stuff.bellID,
                  stuff.pitch, stuff.duration, stuff.percent,
                  stuff.forceSound, stuff.eventOnly, stuff.name);

    if ((rc == Success) && ((stuff.deviceSpec == XkbUseCoreKbd) ||
                            (stuff.deviceSpec == XkbUseCorePtr))) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {
                rc = dixCallDeviceAccessCallback(client, other, DixBellAccess);
                if (rc == Success)
                    _XkbBell(client, other, pWin, stuff.bellClass,
                             stuff.bellID, stuff.pitch, stuff.duration,
                             stuff.percent, stuff.forceSound,
                             stuff.eventOnly, stuff.name);
            }
        }
        rc = Success;           /* reset to success, that's what we got for the VCK */
    }

    return rc;
}

int ProcXkbGetState(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetStateReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");

    DeviceIntPtr dev = void;
    XkbStateRec* xkb = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));

    xkb = &dev.key.xkbInfo.state;

    xkbGetStateReply reply = {
        deviceID: cast(ubyte)dev.id,
        mods: mixin(XkbStateFieldFromRec!("xkb")) & 0xff,
        baseMods: xkb.base_mods,
        latchedMods: xkb.latched_mods,
        lockedMods: xkb.locked_mods,
        group: xkb.group,
        lockedGroup: xkb.locked_group,
        baseGroup: xkb.base_group,
        latchedGroup: xkb.latched_group,
        compatState: xkb.compat_state,
        ptrBtnState: xkb.ptr_buttons
    };

    mixin(X_REPLY_FIELD_CARD16!"ptrBtnState");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcXkbLatchLockState(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbLatchLockStateReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"groupLatch");

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    DeviceIntPtr dev = void;
    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixSetAttrAccess`));
    mixin(CHK_MASK_MATCH!(`0x01`, `stuff.affectModLocks`, `stuff.modLocks`));
    mixin(CHK_MASK_MATCH!(`0x01`, `stuff.affectModLatches`, `stuff.modLatches`));

    int status = Success;

    for (DeviceIntPtr tmpd = inputInfo.devices; tmpd; tmpd = tmpd.next) {
        if ((tmpd == dev) ||
            (!InputDevIsMaster(tmpd) && GetMaster(tmpd, MASTER_KEYBOARD) == dev)) {
            if (!tmpd.key || !tmpd.key.xkbInfo)
                continue;

			XkbStateRec oldState = tmpd.key.xkbInfo.state;
			XkbStateRec* newState = &tmpd.key.xkbInfo.state;
            if (stuff.affectModLocks) {
                newState.locked_mods &= ~stuff.affectModLocks;
                newState.locked_mods |=
                    (stuff.affectModLocks & stuff.modLocks);
            }
            if (status == Success && stuff.lockGroup)
                newState.locked_group = stuff.groupLock;
            if (status == Success && stuff.affectModLatches)
                status = XkbLatchModifiers(tmpd, stuff.affectModLatches,
                                           stuff.modLatches);
            if (status == Success && stuff.latchGroup)
                status = XkbLatchGroup(tmpd, stuff.groupLatch);

            if (status != Success)
                return status;

            XkbComputeDerivedState(tmpd.key.xkbInfo);

            CARD16 changed = cast(ushort)XkbStateChangedFlags(&oldState, newState);
            if (changed) {
				xkbStateNotify sn = {
					keycode: 0,
					eventType: 0,
					requestMajor: cast(ubyte)XkbReqCode,
					requestMinor: X_kbLatchLockState,
					changed: changed
				};
                XkbSendStateNotify(tmpd, &sn);
                changed = cast(short)XkbIndicatorsToUpdate(tmpd, changed, FALSE);
                if (changed) {
                    XkbEventCauseRec cause = { 0 };
                    mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbLatchLockState`, `client`));
                    XkbUpdateIndicators(tmpd, cast(ubyte)changed, TRUE, null, &cause);
                }
            }
        }
    }

    return Success;
}

int ProcXkbGetControls(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetControlsReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");

    XkbControlsPtr xkb = void;
    DeviceIntPtr dev = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));

    xkb = dev.key.xkbInfo.desc.ctrls;

    xkbGetControlsReply reply = {
        deviceID: cast(ubyte)(cast(DeviceIntPtr) dev).id,
        mkDfltBtn: xkb.mk_dflt_btn,
        numGroups: xkb.num_groups,
        groupsWrap: xkb.groups_wrap,
        internalMods: xkb.internal.mask,
        ignoreLockMods: xkb.ignore_lock.mask,
        internalRealMods: xkb.internal.real_mods,
        ignoreLockRealMods: xkb.ignore_lock.real_mods,
        internalVMods: xkb.internal.vmods,
        ignoreLockVMods: xkb.ignore_lock.vmods,
        repeatDelay: xkb.repeat_delay,
        repeatInterval: xkb.repeat_interval,
        slowKeysDelay: xkb.slow_keys_delay,
        debounceDelay: xkb.debounce_delay,
        mkDelay: xkb.mk_delay,
        mkInterval: xkb.mk_interval,
        mkTimeToMax: xkb.mk_time_to_max,
        mkMaxSpeed: xkb.mk_max_speed,
        mkCurve: xkb.mk_curve,
        axOptions: xkb.ax_options,
        axTimeout: xkb.ax_timeout,
        axtOptsMask: xkb.axt_opts_mask,
        axtOptsValues: xkb.axt_opts_values,
        axtCtrlsMask: xkb.axt_ctrls_mask,
        axtCtrlsValues: xkb.axt_ctrls_values,
        enabledCtrls: xkb.enabled_ctrls,
    };
    memcpy(reply.perKeyRepeat.ptr, xkb.per_key_repeat.ptr, XkbPerKeyBitArraySize);

    mixin(X_REPLY_FIELD_CARD16!"internalVMods");
    mixin(X_REPLY_FIELD_CARD16!"ignoreLockVMods");
    mixin(X_REPLY_FIELD_CARD32!"enabledCtrls");
    mixin(X_REPLY_FIELD_CARD16!"repeatDelay");
    mixin(X_REPLY_FIELD_CARD16!"repeatInterval");
    mixin(X_REPLY_FIELD_CARD16!"slowKeysDelay");
    mixin(X_REPLY_FIELD_CARD16!"debounceDelay");
    mixin(X_REPLY_FIELD_CARD16!"mkDelay");
    mixin(X_REPLY_FIELD_CARD16!"mkInterval");
    mixin(X_REPLY_FIELD_CARD16!"mkTimeToMax");
    mixin(X_REPLY_FIELD_CARD16!"mkMaxSpeed");
    mixin(X_REPLY_FIELD_CARD16!"mkCurve");
    mixin(X_REPLY_FIELD_CARD16!"axTimeout");
    mixin(X_REPLY_FIELD_CARD32!"axtCtrlsMask");
    mixin(X_REPLY_FIELD_CARD32!"axtCtrlsValues");
    mixin(X_REPLY_FIELD_CARD16!"axtOptsMask");
    mixin(X_REPLY_FIELD_CARD16!"axtOptsValues");
    mixin(X_REPLY_FIELD_CARD16!"axOptions");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcXkbSetControls(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbSetControlsReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"affectInternalVMods");
    mixin(X_REQUEST_FIELD_CARD16!"internalVMods");
    mixin(X_REQUEST_FIELD_CARD16!"affectIgnoreLockVMods");
    mixin(X_REQUEST_FIELD_CARD16!"ignoreLockVMods");
    mixin(X_REQUEST_FIELD_CARD16!"axOptions");
    mixin(X_REQUEST_FIELD_CARD32!"affectEnabledCtrls");
    mixin(X_REQUEST_FIELD_CARD32!"enabledCtrls");
    mixin(X_REQUEST_FIELD_CARD32!"changeCtrls");
    mixin(X_REQUEST_FIELD_CARD16!"repeatDelay");
    mixin(X_REQUEST_FIELD_CARD16!"repeatInterval");
    mixin(X_REQUEST_FIELD_CARD16!"slowKeysDelay");
    mixin(X_REQUEST_FIELD_CARD16!"debounceDelay");
    mixin(X_REQUEST_FIELD_CARD16!"mkDelay");
    mixin(X_REQUEST_FIELD_CARD16!"mkInterval");
    mixin(X_REQUEST_FIELD_CARD16!"mkTimeToMax");
    mixin(X_REQUEST_FIELD_CARD16!"mkMaxSpeed");
    mixin(X_REQUEST_FIELD_CARD16!"mkCurve");
    mixin(X_REQUEST_FIELD_CARD16!"axTimeout");
    mixin(X_REQUEST_FIELD_CARD32!"axtCtrlsMask");
    mixin(X_REQUEST_FIELD_CARD32!"axtCtrlsValues");
    mixin(X_REQUEST_FIELD_CARD16!"axtOptsMask");
    mixin(X_REQUEST_FIELD_CARD16!"axtOptsValues");

    DeviceIntPtr dev = void, tmpd = void;
    XkbSrvInfoPtr xkbi = void;
    XkbControlsPtr ctrl = void;
    XkbControlsRec new_ = { 0 };
    XkbControlsRec old = { 0 };
    xkbControlsNotify cn = { 0 };
    XkbEventCauseRec cause = { 0 };
    XkbSrvLedInfoPtr sli = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixManageAccess`));
    mixin(CHK_MASK_LEGAL!(`0x01`, `stuff.changeCtrls`, `XkbAllControlsMask`));

    for (tmpd = inputInfo.devices; tmpd; tmpd = tmpd.next) {
        if (!tmpd.key || !tmpd.key.xkbInfo)
            continue;
        if ((tmpd == dev) ||
            (!InputDevIsMaster(tmpd) && GetMaster(tmpd, MASTER_KEYBOARD) == dev)) {
            xkbi = tmpd.key.xkbInfo;
            ctrl = xkbi.desc.ctrls;
            new_ = *ctrl;
            mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbSetControls`, `client`));

            if (stuff.changeCtrls & XkbInternalModsMask) {
                mixin(CHK_MASK_MATCH!(`0x02`, `stuff.affectInternalMods`,
                               `stuff.internalMods`));
                mixin(CHK_MASK_MATCH!(`0x03`, `stuff.affectInternalVMods`,
                               `stuff.internalVMods`));

                new_.internal.real_mods &= ~(stuff.affectInternalMods);
                new_.internal.real_mods |= (stuff.affectInternalMods &
                                           stuff.internalMods);
                new_.internal.vmods &= ~(stuff.affectInternalVMods);
                new_.internal.vmods |= (stuff.affectInternalVMods &
                                       stuff.internalVMods);
                new_.internal.mask = cast(ubyte)(new_.internal.real_mods |
                    XkbMaskForVMask(xkbi.desc, new_.internal.vmods));
            }

            if (stuff.changeCtrls & XkbIgnoreLockModsMask) {
                mixin(CHK_MASK_MATCH!(`0x4`, `stuff.affectIgnoreLockMods`,
                               `stuff.ignoreLockMods`));
                mixin(CHK_MASK_MATCH!(`0x5`, `stuff.affectIgnoreLockVMods`,
                               `stuff.ignoreLockVMods`));

                new_.ignore_lock.real_mods &= ~(stuff.affectIgnoreLockMods);
                new_.ignore_lock.real_mods |= (stuff.affectIgnoreLockMods &
                                              stuff.ignoreLockMods);
                new_.ignore_lock.vmods &= ~(stuff.affectIgnoreLockVMods);
                new_.ignore_lock.vmods |= (stuff.affectIgnoreLockVMods &
                                          stuff.ignoreLockVMods);
                new_.ignore_lock.mask = cast(ubyte)(new_.ignore_lock.real_mods |
                    XkbMaskForVMask(xkbi.desc, new_.ignore_lock.vmods));
            }

            mixin(CHK_MASK_MATCH!(`0x06`, `stuff.affectEnabledCtrls`,
                           `stuff.enabledCtrls`));
            if (stuff.affectEnabledCtrls) {
                mixin(CHK_MASK_LEGAL!(`0x07`, `stuff.affectEnabledCtrls`,
                               `XkbAllBooleanCtrlsMask`));

                new_.enabled_ctrls &= ~(stuff.affectEnabledCtrls);
                new_.enabled_ctrls |= (stuff.affectEnabledCtrls &
                                      stuff.enabledCtrls);
            }

            if (stuff.changeCtrls & XkbRepeatKeysMask) {
                if (stuff.repeatDelay < 1 || stuff.repeatInterval < 1) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x08", "stuff.repeatDelay",
                                                      "stuff.repeatInterval"));
                    return BadValue;
                }

                new_.repeat_delay = stuff.repeatDelay;
                new_.repeat_interval = stuff.repeatInterval;
            }

            if (stuff.changeCtrls & XkbSlowKeysMask) {
                if (stuff.slowKeysDelay < 1) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x09",
"                                                      stuff.slowKeysDelay"));
                    return BadValue;
                }

                new_.slow_keys_delay = stuff.slowKeysDelay;
            }

            if (stuff.changeCtrls & XkbBounceKeysMask) {
                if (stuff.debounceDelay < 1) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x0A",
"                                                      stuff.debounceDelay"));
                    return BadValue;
                }

                new_.debounce_delay = stuff.debounceDelay;
            }

            if (stuff.changeCtrls & XkbMouseKeysMask) {
                if (stuff.mkDfltBtn > XkbMaxMouseKeysBtn) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x0B", "stuff.mkDfltBtn"));
                    return BadValue;
                }

                new_.mk_dflt_btn = stuff.mkDfltBtn;
            }

            if (stuff.changeCtrls & XkbMouseKeysAccelMask) {
                if (stuff.mkDelay < 1 || stuff.mkInterval < 1 ||
                    stuff.mkTimeToMax < 1 || stuff.mkMaxSpeed < 1 ||
                    stuff.mkCurve < -1000) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x0C", "0"));
                    return BadValue;
                }

                new_.mk_delay = stuff.mkDelay;
                new_.mk_interval = stuff.mkInterval;
                new_.mk_time_to_max = stuff.mkTimeToMax;
                new_.mk_max_speed = stuff.mkMaxSpeed;
                new_.mk_curve = stuff.mkCurve;
                AccessXComputeCurveFactor(xkbi, &new_);
            }

            if (stuff.changeCtrls & XkbGroupsWrapMask) {
                uint act = void, num = void;

                act = mixin(XkbOutOfRangeGroupAction!("stuff.groupsWrap"));
                switch (act) {
                case XkbRedirectIntoRange:
                    num = mixin(XkbOutOfRangeGroupNumber!("stuff.groupsWrap"));
                    if (num >= new_.num_groups) {
                        client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x0D", "new_.num_groups",
                                                          "num"));
                        return BadValue;
                    }
                goto case;
                // goto
                case XkbWrapIntoRange:
                case XkbClampIntoRange:
                    break;
                default:
                    client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x0E", "act"));
                    return BadValue;
                }

                new_.groups_wrap = stuff.groupsWrap;
            }

            mixin(CHK_MASK_LEGAL!(`0x0F`, `stuff.axOptions`, `XkbAX_AllOptionsMask`));
            if (stuff.changeCtrls & XkbAccessXKeysMask) {
                new_.ax_options = stuff.axOptions & XkbAX_AllOptionsMask;
            }
            else {
                if (stuff.changeCtrls & XkbStickyKeysMask) {
                    new_.ax_options &= ~(XkbAX_SKOptionsMask);
                    new_.ax_options |= (stuff.axOptions & XkbAX_SKOptionsMask);
                }

                if (stuff.changeCtrls & XkbAccessXFeedbackMask) {
                    new_.ax_options &= ~(XkbAX_FBOptionsMask);
                    new_.ax_options |= (stuff.axOptions & XkbAX_FBOptionsMask);
                }
            }

            if (stuff.changeCtrls & XkbAccessXTimeoutMask) {
                if (stuff.axTimeout < 1) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x10", "stuff.axTimeout"));
                    return BadValue;
                }
                mixin(CHK_MASK_MATCH!(`0X11`, `stuff.axtCtrlsMask`,
                               `stuff.axtCtrlsValues`));
                mixin(CHK_MASK_LEGAL!(`0x12`, `stuff.axtCtrlsMask`,
                               `XkbAllBooleanCtrlsMask`));
                mixin(CHK_MASK_MATCH!(`0x13`, `stuff.axtOptsMask`, `stuff.axtOptsValues`));
                mixin(CHK_MASK_LEGAL!(`0x14`, `stuff.axtOptsMask`, `XkbAX_AllOptionsMask`));
                new_.ax_timeout = stuff.axTimeout;
                new_.axt_ctrls_mask = cast(uint)stuff.axtCtrlsMask;
                new_.axt_ctrls_values = cast(uint)(stuff.axtCtrlsValues &
                                        stuff.axtCtrlsMask);
                new_.axt_opts_mask = stuff.axtOptsMask;
                new_.axt_opts_values = (stuff.axtOptsValues &
                                       stuff.axtOptsMask);
            }

            if (stuff.changeCtrls & XkbPerKeyRepeatMask) {
                memcpy(new_.per_key_repeat.ptr, stuff.perKeyRepeat.ptr,
                       XkbPerKeyBitArraySize);
                if (xkbi.repeatKey &&
                    !mixin(BitIsOn!("new_.per_key_repeat", "xkbi.repeatKey"))) {
                    AccessXCancelRepeatKey(xkbi, xkbi.repeatKey);
                }
            }

            old = *ctrl;
            *ctrl = new_;
            XkbDDXChangeControls(tmpd, &old, ctrl);

            if (XkbComputeControlsNotify(tmpd, &old, ctrl, &cn, FALSE)) {
                cn.keycode = 0;
                cn.eventType = 0;
                cn.requestMajor = cast(ubyte)XkbReqCode;
                cn.requestMinor = X_kbSetControls;
                XkbSendControlsNotify(tmpd, &cn);
            }

            sli = XkbFindSrvLedInfo(tmpd, XkbDfltXIClass, XkbDfltXIId, 0);
            if (sli)
                XkbUpdateIndicators(tmpd, sli.usesControls, TRUE, null,
                                    &cause);

            /* If sticky keys were disabled, clear all locks and latches */
            if ((old.enabled_ctrls & XkbStickyKeysMask) &&
                !(ctrl.enabled_ctrls & XkbStickyKeysMask))
                XkbClearAllLatchesAndLocks(tmpd, xkbi, TRUE, &cause);
        }
    }

    return Success;
}

private int XkbSizeKeyTypes(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    XkbKeyTypeRec* type = void;
    uint i = void, len = void;

    len = 0;
    if (((rep.present & XkbKeyTypesMask) == 0) || (rep.nTypes < 1) ||
        (!xkb) || (!xkb.map) || (!xkb.map.types)) {
        rep.present &= ~XkbKeyTypesMask;
        rep.firstType = rep.nTypes = 0;
        return 0;
    }
    type = &xkb.map.types[rep.firstType];
    for (i = 0; i < rep.nTypes; i++, type++) {
        len += xkbKeyTypeWireDesc.sizeof;
        if (type.map_count > 0) {
            len += (type.map_count * (xkbKTMapEntryWireDesc).sizeof);
            if (type.preserve)
                len += (type.map_count * (xkbModsWireDesc).sizeof);
        }
    }
    return len;
}

private void XkbWriteKeyTypes(XkbDescPtr xkb, CARD8 firstType, CARD8 nTypes, x_rpcbuf_t* rpcbuf, ClientPtr client)
{
    XkbKeyTypePtr type = &xkb.map.types[firstType];
    for (int i = 0; i < nTypes; i++, type++) {
        xkbKeyTypeWireDesc* wire = cast(xkbKeyTypeWireDesc*)x_rpcbuf_reserve(rpcbuf, xkbKeyTypeWireDesc.sizeof);
        wire.mask = type.mods.mask;
        wire.realMods = type.mods.real_mods;
        wire.virtualMods = type.mods.vmods;
        wire.numLevels = type.num_levels;
        wire.nMapEntries = type.map_count;
        wire.preserve = (type.preserve !is null);
        if (client.swapped) {
            swaps(&wire.virtualMods);
        }

        if (type.map_count > 0) {
            void* space = x_rpcbuf_reserve(
                rpcbuf, ((xkbKTMapEntryWireDesc).sizeof * type.map_count));
            xkbKTMapEntryWireDesc* ewire = cast(xkbKTMapEntryWireDesc*) space;
            XkbKTMapEntryPtr entry = type.map;

            size_t n = void;

            for (n = 0; n < type.map_count; n++, ewire++, entry++) {
                ewire.active = cast(ubyte)entry.active;
                ewire.mask = entry.mods.mask;
                ewire.level = entry.level;
                ewire.realMods = entry.mods.real_mods;
                ewire.virtualMods = entry.mods.vmods;
                if (client.swapped) {
                    swaps(&ewire.virtualMods);
                }
            }

            if (type.preserve !is null) {
                xkbModsWireDesc* pwire = cast(xkbModsWireDesc*)x_rpcbuf_reserve(
                    rpcbuf, ((xkbModsWireDesc).sizeof * type.map_count));
                XkbModsPtr preserve = type.preserve;

                for (n = 0; n < type.map_count; n++, pwire++, preserve++) {
                    pwire.mask = preserve.mask;
                    pwire.realMods = preserve.real_mods;
                    pwire.virtualMods = preserve.vmods;
                    if (client.swapped) {
                        swaps(&pwire.virtualMods);
                    }
                }
            }
        }
    }
}

private int XkbSizeKeySyms(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    XkbSymMapPtr symMap = void;
    uint i = void, len = void;
    uint nSyms = void, nSymsThisKey = void;

    if (((rep.present & XkbKeySymsMask) == 0) || (rep.nKeySyms < 1) ||
        (!xkb) || (!xkb.map) || (!xkb.map.key_sym_map)) {
        rep.present &= ~XkbKeySymsMask;
        rep.firstKeySym = rep.nKeySyms = 0;
        rep.totalSyms = 0;
        return 0;
    }
    len = rep.nKeySyms * (xkbSymMapWireDesc).sizeof;
    symMap = &xkb.map.key_sym_map[rep.firstKeySym];
    for (i = nSyms = 0; i < rep.nKeySyms; i++, symMap++) {
        nSymsThisKey = mixin(XkbNumGroups!("symMap.group_info")) * symMap.width;
        if (nSymsThisKey == 0)
            continue;
        nSyms += nSymsThisKey;
    }
    len += nSyms * 4;
    rep.totalSyms = cast(ushort)nSyms;
    return len;
}

private int XkbSizeVirtualMods(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    uint i = void, nMods = void, bit = void;

    if (((rep.present & XkbVirtualModsMask) == 0) || (rep.virtualMods == 0) ||
        (!xkb) || (!xkb.server)) {
        rep.present &= ~XkbVirtualModsMask;
        rep.virtualMods = 0;
        return 0;
    }
    for (i = nMods = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
        if (rep.virtualMods & bit)
            nMods++;
    }
    return mixin(XkbPaddedSize!("nMods"));
}

private void XkbWriteKeySyms(XkbDescPtr xkb, KeyCode firstKeySym, CARD8 nKeySyms, x_rpcbuf_t* rpcbuf, ClientPtr client)
{
    XkbSymMapPtr symMap = &xkb.map.key_sym_map[firstKeySym];
    for (int i = 0; i < nKeySyms; i++, symMap++) {
        size_t nSyms = symMap.width * mixin(XkbNumGroups!("symMap.group_info"));
        xkbSymMapWireDesc* outMap = cast(xkbSymMapWireDesc*)x_rpcbuf_reserve(rpcbuf, xkbSymMapWireDesc.sizeof);
        outMap.ktIndex[0] = symMap.kt_index[0];
        outMap.ktIndex[1] = symMap.kt_index[1];
        outMap.ktIndex[2] = symMap.kt_index[2];
        outMap.ktIndex[3] = symMap.kt_index[3];
        outMap.groupInfo = symMap.group_info;
        outMap.width = symMap.width;
        outMap.nSyms = cast(ushort)nSyms;

        if (client.swapped)
            swaps(&outMap.nSyms);

        if (outMap.nSyms) {
            KeySym* pSym = &xkb.map.syms[symMap.offset];
            x_rpcbuf_write_CARD32s(rpcbuf, pSym, cast(uint*)nSyms);
        }
    }
}

private int XkbSizeKeyActions(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    uint i = void, len = void, nActs = void;
    KeyCode firstKey = void;

    if (((rep.present & XkbKeyActionsMask) == 0) || (rep.nKeyActs < 1) ||
        (!xkb) || (!xkb.server) || (!xkb.server.key_acts)) {
        rep.present &= ~XkbKeyActionsMask;
        rep.firstKeyAct = rep.nKeyActs = 0;
        rep.totalActs = 0;
        return 0;
    }
    firstKey = rep.firstKeyAct;
    for (nActs = i = 0; i < rep.nKeyActs; i++) {
        if (xkb.server.key_acts[i + firstKey] != 0)
            nActs += mixin(XkbKeyNumActions!("xkb"," i + firstKey"));
    }
    len = cast(uint)(mixin(XkbPaddedSize!("rep.nKeyActs")) + (nActs * (xkbActionWireDesc).sizeof));
    rep.totalActs = cast(ushort)nActs;
    return len;
}

private void XkbWriteKeyActions(XkbDescPtr xkb, KeyCode firstKeyAct, CARD8 nKeyActs, x_rpcbuf_t* rpcbuf)
{
    CARD8* numDesc = cast(ubyte*)x_rpcbuf_reserve(rpcbuf, mixin(XkbPaddedSize!("nKeyActs")));

    for (int i = 0; i < nKeyActs; i++) {
        if (xkb.server.key_acts[i + firstKeyAct] == 0)
            numDesc[i] = 0;
        else
            numDesc[i] =cast(ubyte) mixin(XkbKeyNumActions!("xkb"," (i + firstKeyAct)"));
    }

    for (int i = 0; i < nKeyActs; i++) {
        if (xkb.server.key_acts[i + firstKeyAct] != 0) {
            size_t num = mixin(XkbKeyNumActions!("xkb"," (i + firstKeyAct)"));
            x_rpcbuf_write_CARD8s(rpcbuf,
                                  cast(CARD8*)mixin(XkbKeyActionsPtr!("xkb", "(i + firstKeyAct)")),
                                  cast(ubyte)(num * (xkbActionWireDesc).sizeof));
        }
    }
}

private int XkbSizeKeyBehaviors(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    uint i = void, len = void, nBhvr = void;
    XkbBehavior* bhv = void;

    if (((rep.present & XkbKeyBehaviorsMask) == 0) || (rep.nKeyBehaviors < 1)
        || (!xkb) || (!xkb.server) || (!xkb.server.behaviors)) {
        rep.present &= ~XkbKeyBehaviorsMask;
        rep.firstKeyBehavior = rep.nKeyBehaviors = 0;
        rep.totalKeyBehaviors = cast(ubyte)0;
        return 0;
    }
    bhv = &xkb.server.behaviors[rep.firstKeyBehavior];
    for (nBhvr = i = 0; i < rep.nKeyBehaviors; i++, bhv++) {
        if (bhv.type != XkbKB_Default)
            nBhvr++;
    }
    len = cast(uint)(nBhvr * (xkbBehaviorWireDesc).sizeof);
    rep.totalKeyBehaviors = cast(ubyte)nBhvr;
    return len;
}

private void XkbWriteKeyBehaviors(XkbDescPtr xkb, KeyCode firstKeyBehavior, CARD8 nKeyBehaviors, x_rpcbuf_t* rpcbuf)
{
    XkbBehavior* pBhvr = &xkb.server.behaviors[firstKeyBehavior];
    for (int i = 0; i < nKeyBehaviors; i++, pBhvr++) {
        if (pBhvr.type != XkbKB_Default) {
            xkbBehaviorWireDesc* wire = cast(xkbBehaviorWireDesc*)x_rpcbuf_reserve(rpcbuf, xkbBehaviorWireDesc.sizeof);
            wire.key = cast(ubyte)(i + firstKeyBehavior);
            wire.type = pBhvr.type;
            wire.data = pBhvr.data;
        }
    }
}

private int XkbSizeExplicit(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    uint i = void, len = void, nRtrn = void;

    if (((rep.present & XkbExplicitComponentsMask) == 0) ||
        (rep.nKeyExplicit < 1) || (!xkb) || (!xkb.server) ||
        (!xkb.server.explicit)) {
        rep.present &= ~XkbExplicitComponentsMask;
        rep.firstKeyExplicit = rep.nKeyExplicit = 0;
        rep.totalKeyExplicit = 0;
        return 0;
    }
    for (nRtrn = i = 0; i < rep.nKeyExplicit; i++) {
        if (xkb.server.explicit[i + rep.firstKeyExplicit] != 0)
            nRtrn++;
    }
    rep.totalKeyExplicit = cast(ubyte)nRtrn;
    len = mixin(XkbPaddedSize!("nRtrn * 2"));     /* two bytes per non-zero explicit component */
    return len;
}

private void XkbWriteExplicit(XkbDescPtr xkb, KeyCode firstKeyExplicit, CARD8 nKeyExplicit, x_rpcbuf_t* rpcbuf)
{
    ubyte* pExp = &xkb.server.explicit[firstKeyExplicit];

    /* count how many active entries there will be */
    size_t count = 0;
    for (int i = 0; i < nKeyExplicit; i++) {
        if (pExp[i] != 0)
            count++;
    }

    /* reserve buffer space (with padding) */
    char* buf = cast(char*)x_rpcbuf_reserve(rpcbuf, mixin(XkbPaddedSize!("count * 2")));

    /* copy over the active entries */
    for (int i = 0; i < nKeyExplicit; i++) {
        if (pExp[i] != 0) {
            *buf++ = cast(char)(i + firstKeyExplicit);
            *buf++ = pExp[i];
        }
    }
}

private int XkbSizeModifierMap(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    uint i = void, len = void, nRtrn = void;

    if (((rep.present & XkbModifierMapMask) == 0) || (rep.nModMapKeys < 1) ||
        (!xkb) || (!xkb.map) || (!xkb.map.modmap)) {
        rep.present &= ~XkbModifierMapMask;
        rep.firstModMapKey = rep.nModMapKeys = 0;
        rep.totalModMapKeys = cast(uint)0;
        return 0;
    }
    for (nRtrn = i = 0; i < rep.nModMapKeys; i++) {
        if (xkb.map.modmap[i + rep.firstModMapKey] != 0)
            nRtrn++;
    }
    rep.totalModMapKeys = cast(ubyte)nRtrn;
    len = mixin(XkbPaddedSize!("nRtrn * 2"));     /* two bytes per non-zero modmap component */
    return len;
}

private void XkbWriteModifierMap(XkbDescPtr xkb, KeyCode firstModMapKey, CARD8 nModMapKeys, x_rpcbuf_t* rpcbuf)
{
    ubyte* pMap = &xkb.map.modmap[firstModMapKey];

    for (int i = 0; i < nModMapKeys; i++) {
        if (pMap[i] != 0) {
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)(i + firstModMapKey));
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)pMap[i]);
        }
    }

    /* make sure the just written data is properly padded */
    x_rpcbuf_pad(rpcbuf);
}

private int XkbSizeVirtualModMap(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    uint i = void, len = void, nRtrn = void;

    if (((rep.present & XkbVirtualModMapMask) == 0) || (rep.nVModMapKeys < 1)
        || (!xkb) || (!xkb.server) || (!xkb.server.vmodmap)) {
        rep.present &= ~XkbVirtualModMapMask;
        rep.firstVModMapKey = rep.nVModMapKeys = 0;
        rep.totalVModMapKeys = cast(ubyte)0;
        return 0;
    }
    for (nRtrn = i = 0; i < rep.nVModMapKeys; i++) {
        if (xkb.server.vmodmap[i + rep.firstVModMapKey] != 0)
            nRtrn++;
    }
    rep.totalVModMapKeys = cast(ubyte)nRtrn;
    len = cast(uint)(nRtrn * (xkbVModMapWireDesc).sizeof);
    return len;
}

private void XkbWriteVirtualModMap(XkbDescPtr xkb, KeyCode firstVModMapKey, CARD8 nVModMapKeys, x_rpcbuf_t* rpcbuf)
{
    ushort* pMap = &xkb.server.vmodmap[firstVModMapKey];
    for (int i = 0; i < nVModMapKeys; i++, pMap++) {
        if (*pMap != 0) {
            xkbVModMapWireDesc* wire = cast(xkbVModMapWireDesc*)x_rpcbuf_reserve(rpcbuf, xkbVModMapWireDesc.sizeof);
            wire.key = cast(ubyte)(i + firstVModMapKey);
            wire.vmods = *pMap;
        }
    }
}

private Status XkbComputeGetMapReplySize(XkbDescPtr xkb, xkbGetMapReply* rep)
{
    int len = void;

    rep.minKeyCode = xkb.min_key_code;
    rep.maxKeyCode = xkb.max_key_code;
    len = XkbSizeKeyTypes(xkb, rep);
    len += XkbSizeKeySyms(xkb, rep);
    len += XkbSizeKeyActions(xkb, rep);
    len += XkbSizeKeyBehaviors(xkb, rep);
    len += XkbSizeVirtualMods(xkb, rep);
    len += XkbSizeExplicit(xkb, rep);
    len += XkbSizeModifierMap(xkb, rep);
    len += XkbSizeVirtualModMap(xkb, rep);
    rep.length += (len / 4);
    return Success;
}

private void XkbAssembleMap(ClientPtr client, XkbDescPtr xkb, xkbGetMapReply rep, x_rpcbuf_t* rpcbuf)
{
    XkbWriteKeyTypes(xkb, rep.firstType, rep.nTypes, rpcbuf, client);
    XkbWriteKeySyms(xkb, rep.firstKeySym, rep.nKeySyms, rpcbuf, client);
    XkbWriteKeyActions(xkb, rep.firstKeyAct, rep.nKeyActs, rpcbuf);
    if (rep.totalKeyBehaviors > 0)
        XkbWriteKeyBehaviors(xkb, rep.firstKeyBehavior, rep.nKeyBehaviors, rpcbuf);

    if (rep.virtualMods) {
        CARD8[mixin(XkbPaddedSize!("XkbNumVirtualMods"))] vmods = 0;
        size_t sz = 0;
        for (size_t i = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
            if (rep.virtualMods & bit) {
                vmods[sz++] = xkb.server.vmods[i];
            }
        }
        x_rpcbuf_write_CARD8s(rpcbuf, vmods.ptr, mixin(XkbPaddedSize!("sz")));
    }

    if (rep.totalKeyExplicit > 0)
        XkbWriteExplicit(xkb, rep.firstKeyExplicit, rep.nKeyExplicit, rpcbuf);
    if (rep.totalModMapKeys > 0)
        XkbWriteModifierMap(xkb, rep.firstModMapKey, rep.nModMapKeys, rpcbuf);
    if (rep.totalVModMapKeys > 0)
        XkbWriteVirtualModMap(xkb, rep.firstVModMapKey, rep.nVModMapKeys, rpcbuf);
}

int ProcXkbGetMap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetMapReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"full");
    mixin(X_REQUEST_FIELD_CARD16!"partial");
    mixin(X_REQUEST_FIELD_CARD16!"virtualMods");

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    DeviceIntPtr dev = void;
    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));
    mixin(CHK_MASK_OVERLAP!(`0x01`, `stuff.full`, `stuff.partial`));
    mixin(CHK_MASK_LEGAL!(`0x02`, `stuff.full`, `XkbAllMapComponentsMask`));
    mixin(CHK_MASK_LEGAL!(`0x03`, `stuff.partial`, `XkbAllMapComponentsMask`));

    XkbDescRec* xkb = dev.key.xkbInfo.desc;

    xkbGetMapReply reply = {
        deviceID: cast(ubyte)dev.id,
        present: stuff.partial | stuff.full,
        minKeyCode: xkb.min_key_code,
        maxKeyCode: xkb.max_key_code,
        totalTypes: xkb.map.num_types,
    };

    if (stuff.full & XkbKeyTypesMask) {
        reply.nTypes = xkb.map.num_types;
    }
    else if (stuff.partial & XkbKeyTypesMask) {
        if ((cast(uint) stuff.firstType + stuff.nTypes) > xkb.map.num_types) {
            client.errorValue = cast(uint)mixin(_XkbErrCode4!("0x04", "xkb.map.num_types",
                                              "stuff.firstType", "stuff.nTypes"));
            return BadValue;
        }
        reply.firstType = stuff.firstType;
        reply.nTypes = stuff.nTypes;
    }

    int numKeys = mixin(XkbNumKeys!("xkb"));
    if (stuff.full & XkbKeySymsMask) {
        reply.firstKeySym = xkb.min_key_code;
        reply.nKeySyms = cast(ubyte)numKeys;
    }
    else if (stuff.partial & XkbKeySymsMask) {
        mixin(CHK_KEY_RANGE!(`0x05`, `stuff.firstKeySym`, `stuff.nKeySyms`, `xkb`));
        reply.firstKeySym = stuff.firstKeySym;
        reply.nKeySyms = cast(ubyte)stuff.nKeySyms;
    }

    if (stuff.full & XkbKeyActionsMask) {
        reply.firstKeyAct = xkb.min_key_code;
        reply.nKeyActs = cast(ubyte)numKeys;
    }
    else if (stuff.partial & XkbKeyActionsMask) {
        mixin(CHK_KEY_RANGE!(`0x07`, `stuff.firstKeyAct`, `stuff.nKeyActs`, `xkb`));
        reply.firstKeyAct = stuff.firstKeyAct;
        reply.nKeyActs = cast(ubyte)stuff.nKeyActs;
    }

    if (stuff.full & XkbKeyBehaviorsMask) {
        reply.firstKeyBehavior = xkb.min_key_code;
        reply.nKeyBehaviors = cast(ubyte)numKeys;
    }
    else if (stuff.partial & XkbKeyBehaviorsMask) {
        mixin(CHK_KEY_RANGE!(`0x09`, `stuff.firstKeyBehavior`, `stuff.nKeyBehaviors`, `xkb`));
        reply.firstKeyBehavior = stuff.firstKeyBehavior;
        reply.nKeyBehaviors = cast(ubyte)stuff.nKeyBehaviors;
    }

    if (stuff.full & XkbVirtualModsMask)
        reply.virtualMods = cast(ushort)~0;
    else if (stuff.partial & XkbVirtualModsMask)
        reply.virtualMods = cast(ushort)stuff.virtualMods;

    if (stuff.full & XkbExplicitComponentsMask) {
        reply.firstKeyExplicit = xkb.min_key_code;
        reply.nKeyExplicit = cast(ubyte)numKeys;
    }
    else if (stuff.partial & XkbExplicitComponentsMask) {
        mixin(CHK_KEY_RANGE!(`0x0B`, `stuff.firstKeyExplicit`, `stuff.nKeyExplicit`, `xkb`));
        reply.firstKeyExplicit = stuff.firstKeyExplicit;
        reply.nKeyExplicit = cast(ubyte)stuff.nKeyExplicit;
    }

    if (stuff.full & XkbModifierMapMask) {
        reply.firstModMapKey = xkb.min_key_code;
        reply.nModMapKeys = cast(ubyte)numKeys;
    }
    else if (stuff.partial & XkbModifierMapMask) {
        mixin(CHK_KEY_RANGE!(`0x0D`, `stuff.firstModMapKey`, `stuff.nModMapKeys`, `xkb`));
        reply.firstModMapKey = stuff.firstModMapKey;
        reply.nModMapKeys = cast(ubyte)stuff.nModMapKeys;
    }

    if (stuff.full & XkbVirtualModMapMask) {
        reply.firstVModMapKey = xkb.min_key_code;
        reply.nVModMapKeys = cast(ubyte)numKeys;
    }
    else if (stuff.partial & XkbVirtualModMapMask) {
        mixin(CHK_KEY_RANGE!(`0x0F`, `stuff.firstVModMapKey`, `stuff.nVModMapKeys`, `xkb`));
        reply.firstVModMapKey = stuff.firstVModMapKey;
        reply.nVModMapKeys = cast(ubyte)stuff.nVModMapKeys;
    }

    int rc = XkbComputeGetMapReplySize(xkb, &reply);
    if (rc != Success)
        return rc;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    XkbAssembleMap(client, xkb, reply, &rpcbuf);

    if (rpcbuf.error)
        return BadAlloc;

    mixin(X_REPLY_FIELD_CARD16!"present");
    mixin(X_REPLY_FIELD_CARD16!"totalSyms");
    mixin(X_REPLY_FIELD_CARD16!"totalActs");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int CheckKeyTypes(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, xkbKeyTypeWireDesc** wireRtrn, int* nMapsRtrn, CARD8* mapWidthRtrn, Bool doswap)
{
    uint nMaps = void;
    uint i = void, n = void;
    CARD8* map = void;
    xkbKeyTypeWireDesc* wire = *wireRtrn;

    if (req.firstType > (cast(uint) xkb.map.num_types)) {
        *nMapsRtrn = mixin(_XkbErrCode3!("0x01", "req.firstType", "xkb.map.num_types"));
        return 0;
    }
    if (req.flags & XkbSetMapResizeTypes) {
        nMaps = req.firstType + req.nTypes;
        if (nMaps < XkbNumRequiredTypes) {      /* canonical types must be there */
            *nMapsRtrn = mixin(_XkbErrCode4!("0x02", "req.firstType", "req.nTypes", "4"));
            return 0;
        }
    }
    else if (req.present & XkbKeyTypesMask) {
        nMaps = xkb.map.num_types;
        if ((req.firstType + req.nTypes) > nMaps) {
            *nMapsRtrn = req.firstType + req.nTypes;
            return 0;
        }
    }
    else {
        *nMapsRtrn = xkb.map.num_types;
        for (i = 0; i < xkb.map.num_types; i++) {
            mapWidthRtrn[i] = xkb.map.types[i].num_levels;
        }
        return 1;
    }

    for (i = 0; i < req.firstType; i++) {
        mapWidthRtrn[i] = xkb.map.types[i].num_levels;
    }
    for (i = 0; i < req.nTypes; i++) {
        uint width = void;

        if (!_XkbCheckRequestBounds(client, req, wire, wire + 1)) {
            *nMapsRtrn = mixin(_XkbErrCode3!("0x0b", "req.nTypes", "i"));
            return 0;
        }
        if (client.swapped && doswap) {
            swaps(&wire.virtualMods);
        }
        n = i + req.firstType;
        width = wire.numLevels;
        if (width < 1) {
            *nMapsRtrn = mixin(_XkbErrCode3!("0x04", "n", "width"));
            return 0;
        }
        else if ((n == XkbOneLevelIndex) && (width != 1)) {     /* must be width 1 */
            *nMapsRtrn = mixin(_XkbErrCode3!("0x05", "n", "width"));
            return 0;
        }
        else if ((width != 2) &&
                 ((n == XkbTwoLevelIndex) || (n == XkbKeypadIndex) ||
                  (n == XkbAlphabeticIndex))) {
            /* TWO_LEVEL, ALPHABETIC and KEYPAD must be width 2 */
            *nMapsRtrn = mixin(_XkbErrCode3!("0x05", "n", "width"));
            return 0;
        }
        if (wire.nMapEntries > 0) {
            xkbKTSetMapEntryWireDesc* mapWire = void;
            xkbModsWireDesc* preWire = void;

            mapWire = cast(xkbKTSetMapEntryWireDesc*) &wire[1];
            if (!_XkbCheckRequestBounds(client, req, mapWire,
                                        &mapWire[wire.nMapEntries])) {
                *nMapsRtrn = mixin(_XkbErrCode3!("0x0c", "i", "wire.nMapEntries"));
                return 0;
            }
            preWire = cast(xkbModsWireDesc*) &mapWire[wire.nMapEntries];
            if (wire.preserve &&
                !_XkbCheckRequestBounds(client, req, preWire,
                                        &preWire[wire.nMapEntries])) {
                *nMapsRtrn = mixin(_XkbErrCode3!("0x0d", "i", "wire.nMapEntries"));
                return 0;
            }
            for (n = 0; n < wire.nMapEntries; n++) {
                if (client.swapped && doswap) {
                    swaps(&mapWire[n].virtualMods);
                }
                if (mapWire[n].realMods & (~wire.realMods)) {
                    *nMapsRtrn = mixin(_XkbErrCode4!("0x06", "n", "mapWire[n].realMods", "wire.realMods"));
                    return 0;
                }
                if (mapWire[n].virtualMods & (~wire.virtualMods)) {
                    *nMapsRtrn = mixin(_XkbErrCode3!("0x07", "n", "mapWire[n].virtualMods"));
                    return 0;
                }
                if (mapWire[n].level >= wire.numLevels) {
                    *nMapsRtrn = mixin(_XkbErrCode4!("0x08", "n", "wire.numLevels", "mapWire[n].level"));
                    return 0;
                }
                if (wire.preserve) {
                    if (client.swapped && doswap) {
                        swaps(&preWire[n].virtualMods);
                    }
                    if (preWire[n].realMods & (~mapWire[n].realMods)) {
                        *nMapsRtrn = mixin(_XkbErrCode4!("0x09", "n", "preWire[n].realMods", "mapWire[n].realMods"));
                        return 0;
                    }
                    if (preWire[n].virtualMods & (~mapWire[n].virtualMods)) {
                        *nMapsRtrn =
                            mixin(_XkbErrCode3!(`0x0a`, `n`, `preWire[n].virtualMods`));
                        return 0;
                    }
                }
            }
            if (wire.preserve)
                map = cast(CARD8*) &preWire[wire.nMapEntries];
            else
                map = cast(CARD8*) &mapWire[wire.nMapEntries];
        }
        else
            map = cast(CARD8*) &wire[1];
        mapWidthRtrn[i + req.firstType] = wire.numLevels;
        wire = cast(xkbKeyTypeWireDesc*) map;
    }
    for (i = req.firstType + req.nTypes; i < nMaps; i++) {
        mapWidthRtrn[i] = xkb.map.types[i].num_levels;
    }
    *nMapsRtrn = nMaps;
    *wireRtrn = wire;
    return 1;
}

private int CheckKeySyms(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, int nTypes, CARD8* mapWidths, CARD16* symsPerKey, xkbSymMapWireDesc** wireRtrn, int* errorRtrn, Bool doswap)
{
    uint i = void;
    XkbSymMapPtr map = void;
    xkbSymMapWireDesc* wire = *wireRtrn;

    if (!(XkbKeySymsMask & req.present))
        return 1;
    mixin(CHK_REQ_KEY_RANGE2!(`0X11`, `req.firstKeySym`, `req.nKeySyms`, `req`, `(*errorRtrn)`,
                       `0`));
    for (i = 0; i < req.nKeySyms; i++) {
        KeySym* pSyms = void;
        uint nG = void;

        /* Check we received enough data to read the next xkbSymMapWireDesc */
        if (!_XkbCheckRequestBounds(client, req, wire, wire + 1)) {
            *errorRtrn = mixin(_XkbErrCode3!("0x18", "i + req.firstKeySym", "i"));
            return 0;
        }
        if (client.swapped && doswap) {
            swaps(&wire.nSyms);
        }
        nG = mixin(XkbNumGroups!("wire.groupInfo"));
        if (nG > XkbNumKbdGroups) {
            *errorRtrn = mixin(_XkbErrCode3!("0x14", "i + req.firstKeySym", "nG"));
            return 0;
        }
        if (nG > 0) {
            int g = void, w = void;

            for (g = w = 0; g < nG; g++) {
                if (wire.ktIndex[g] >= cast(uint) nTypes) {
                    *errorRtrn = mixin(_XkbErrCode4!("0x15", "i + req.firstKeySym", "g", "wire.ktIndex[g]"));
                    return 0;
                }
                if (mapWidths[wire.ktIndex[g]] > w)
                    w = mapWidths[wire.ktIndex[g]];
            }
            if (wire.width != w) {
                *errorRtrn =
                    mixin(_XkbErrCode3!(`0x16`, `i + req.firstKeySym`, `wire.width`));
                return 0;
            }
            w *= nG;
            symsPerKey[i + req.firstKeySym] = cast(ushort)w;
            if (w != wire.nSyms) {
                *errorRtrn =
                    mixin(_XkbErrCode4!("0x16", "i + req.firstKeySym", "wire.nSyms", "w"));
                return 0;
            }
        }
        else if (wire.nSyms != 0) {
            *errorRtrn = mixin(_XkbErrCode3!("0x17", "i + req.firstKeySym", "wire.nSyms"));
            return 0;
        }
        pSyms = cast(KeySym*) &wire[1];
        if (wire.nSyms != 0) {
            if (!_XkbCheckRequestBounds(client, req, pSyms, &pSyms[wire.nSyms])) {
                *errorRtrn = mixin(_XkbErrCode3!("0x19", "i + req.firstKeySym", "wire.nSyms"));
                return 0;
            }
        }
        wire = cast(xkbSymMapWireDesc*) &pSyms[wire.nSyms];
    }

    map = &xkb.map.key_sym_map[i];
    for (; i <= cast(uint) xkb.max_key_code; i++, map++) {
        int g = void, nG = void, w = void;

        nG = mixin(XkbKeyNumGroups!("xkb", "i"));
        for (w = g = 0; g < nG; g++) {
            if (map.kt_index[g] >= cast(uint) nTypes) {
                *errorRtrn = mixin(_XkbErrCode4!("0x18", "i", "g", "map.kt_index[g]"));
                return 0;
            }
            if (mapWidths[map.kt_index[g]] > w)
                w = mapWidths[map.kt_index[g]];
        }
        symsPerKey[i] = cast(ushort)(w * nG);
    }
    *wireRtrn = wire;
    return 1;
}

private int CheckKeyActions(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, int nTypes, CARD8* mapWidths, CARD16* symsPerKey, CARD8** wireRtrn, int* nActsRtrn)
{
    int nActs = void;
    CARD8* wire = *wireRtrn;
    uint i = void;

    if (!(XkbKeyActionsMask & req.present))
        return 1;
    mixin(CHK_REQ_KEY_RANGE2!(`0x21`, `req.firstKeyAct`, `req.nKeyActs`, `req`, `(*nActsRtrn)`,
                       `0`));
    for (nActs = i = 0; i < req.nKeyActs; i++) {
        /* Check we received enough data to read the next byte on the wire */
        if (!_XkbCheckRequestBounds(client, req, wire, wire + 1)) {
            *nActsRtrn = mixin(_XkbErrCode3!("0x24", "i + req.firstKeyAct", "i"));
            return 0;
        }
        if (wire[0] != 0) {
            if (wire[0] == symsPerKey[i + req.firstKeyAct])
                nActs += wire[0];
            else {
                *nActsRtrn = mixin(_XkbErrCode3!("0x23", "i + req.firstKeyAct", "wire[0]"));
                return 0;
            }
        }
        wire++;
    }
    if (req.nKeyActs % 4)
        wire += 4 - (req.nKeyActs % 4);
    *wireRtrn = cast(CARD8*) ((cast(XkbAnyAction*) wire) + nActs);
    *nActsRtrn = nActs;
    return 1;
}

private int CheckKeyBehaviors(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, xkbBehaviorWireDesc** wireRtrn, int* errorRtrn)
{
    xkbBehaviorWireDesc* wire = *wireRtrn;
    XkbServerMapPtr server = xkb.server;
    uint i = void;
    uint first = void, last = void;

    if (((req.present & XkbKeyBehaviorsMask) == 0) || (req.nKeyBehaviors < 1)) {
        req.present &= ~XkbKeyBehaviorsMask;
        req.nKeyBehaviors = 0;
        return 1;
    }
    first = req.firstKeyBehavior;
    last = req.firstKeyBehavior + req.nKeyBehaviors - 1;
    if (first < req.minKeyCode) {
        *errorRtrn = mixin(_XkbErrCode3!("0x31", "first", "req.minKeyCode"));
        return 0;
    }
    if (last > req.maxKeyCode) {
        *errorRtrn = mixin(_XkbErrCode3!("0x32", "last", "req.maxKeyCode"));
        return 0;
    }

    for (i = 0; i < req.totalKeyBehaviors; i++, wire++) {
        /* Check we received enough data to read the next behavior */
        if (!_XkbCheckRequestBounds(client, req, wire, wire + 1)) {
            *errorRtrn = mixin(_XkbErrCode3!("0x36", "first", "i"));
            return 0;
        }
        if ((wire.key < first) || (wire.key > last)) {
            *errorRtrn = mixin(_XkbErrCode4!("0x33", "first", "last", "wire.key"));
            return 0;
        }
        if ((wire.type & XkbKB_Permanent) &&
            ((server.behaviors[wire.key].type != wire.type) ||
             (server.behaviors[wire.key].data != wire.data))) {
            *errorRtrn = mixin(_XkbErrCode3!("0x33", "wire.key", "wire.type"));
            return 0;
        }
        if ((wire.type == XkbKB_RadioGroup) &&
            ((wire.data & (~XkbKB_RGAllowNone)) > XkbMaxRadioGroups)) {
            *errorRtrn = mixin(_XkbErrCode4!("0x34", "wire.key", "wire.data", "XkbMaxRadioGroups"));
            return 0;
        }
        if ((wire.type == XkbKB_Overlay1) || (wire.type == XkbKB_Overlay2)) {
            mixin(CHK_KEY_RANGE2!(`0x35`, `wire.key`, `1`, `xkb`, `*errorRtrn`, `0`));
        }
    }
    *wireRtrn = wire;
    return 1;
}

private int CheckVirtualMods(ClientPtr client, XkbDescRec* xkb, xkbSetMapReq* req, CARD8** wireRtrn, int* errorRtrn)
{
    CARD8* wire = *wireRtrn;
    uint i = void, nMods = void, bit = void;

    if (((req.present & XkbVirtualModsMask) == 0) || (req.virtualMods == 0))
        return 1;
    for (i = nMods = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
        if (req.virtualMods & bit)
            nMods++;
    }
    /* Check we received enough data for the number of virtual mods expected */
    if (!_XkbCheckRequestBounds(client, req, wire, wire + mixin(XkbPaddedSize!("nMods")))) {
        *errorRtrn = mixin(_XkbErrCode3!("0x37", "nMods", "i"));
        return 0;
    }
    *wireRtrn = (wire + mixin(XkbPaddedSize!("nMods")));
    return 1;
}

private int CheckKeyExplicit(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, CARD8** wireRtrn, int* errorRtrn)
{
    CARD8* wire = *wireRtrn;
    CARD8* start = void;
    uint i = void;
    int first = void, last = void;

    if (((req.present & XkbExplicitComponentsMask) == 0) ||
        (req.nKeyExplicit < 1)) {
        req.present &= ~XkbExplicitComponentsMask;
        req.nKeyExplicit = 0;
        return 1;
    }
    first = req.firstKeyExplicit;
    last = first + req.nKeyExplicit - 1;
    if (first < req.minKeyCode) {
        *errorRtrn = mixin(_XkbErrCode3!("0x51", "first", "req.minKeyCode"));
        return 0;
    }
    if (last > req.maxKeyCode) {
        *errorRtrn = mixin(_XkbErrCode3!("0x52", "last", "req.maxKeyCode"));
        return 0;
    }
    start = wire;
    for (i = 0; i < req.totalKeyExplicit; i++, wire += 2) {
        /* Check we received enough data to read the next two bytes */
        if (!_XkbCheckRequestBounds(client, req, wire, wire + 2)) {
            *errorRtrn = mixin(_XkbErrCode4!("0x54", "first", "last", "i"));
            return 0;
        }
        if ((wire[0] < first) || (wire[0] > last)) {
            *errorRtrn = mixin(_XkbErrCode4!("0x53", "first", "last", "wire[0]"));
            return 0;
        }
        if (wire[1] & (~XkbAllExplicitMask)) {
            *errorRtrn = mixin(_XkbErrCode3!("0x52", "~XkbAllExplicitMask", "wire[1]"));
            return 0;
        }
    }
    wire += mixin(XkbPaddedSize!("wire - start")) - (wire - start);
    *wireRtrn = wire;
    return 1;
}

private int CheckModifierMap(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, CARD8** wireRtrn, int* errRtrn)
{
    CARD8* wire = *wireRtrn;
    CARD8* start = void;
    uint i = void;
    int first = void, last = void;

    if (((req.present & XkbModifierMapMask) == 0) || (req.nModMapKeys < 1)) {
        req.present &= ~XkbModifierMapMask;
        req.nModMapKeys = 0;
        return 1;
    }
    first = req.firstModMapKey;
    last = first + req.nModMapKeys - 1;
    if (first < req.minKeyCode) {
        *errRtrn = mixin(_XkbErrCode3!("0x61", "first", "req.minKeyCode"));
        return 0;
    }
    if (last > req.maxKeyCode) {
        *errRtrn = mixin(_XkbErrCode3!("0x62", "last", "req.maxKeyCode"));
        return 0;
    }
    start = wire;
    for (i = 0; i < req.totalModMapKeys; i++, wire += 2) {
        if (!_XkbCheckRequestBounds(client, req, wire, wire + 2)) {
            *errRtrn = mixin(_XkbErrCode3!("0x64", "req.totalModMapKeys", "i"));
            return 0;
        }
        if ((wire[0] < first) || (wire[0] > last)) {
            *errRtrn = mixin(_XkbErrCode4!("0x63", "first", "last", "wire[0]"));
            return 0;
        }
    }
    wire += mixin(XkbPaddedSize!("wire - start")) - (wire - start);
    *wireRtrn = wire;
    return 1;
}

private int CheckVirtualModMap(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, xkbVModMapWireDesc** wireRtrn, int* errRtrn)
{
    xkbVModMapWireDesc* wire = *wireRtrn;
    uint i = void;
    int first = void, last = void;

    if (((req.present & XkbVirtualModMapMask) == 0) || (req.nVModMapKeys < 1)) {
        req.present &= ~XkbVirtualModMapMask;
        req.nVModMapKeys = 0;
        return 1;
    }
    first = req.firstVModMapKey;
    last = first + req.nVModMapKeys - 1;
    if (first < req.minKeyCode) {
        *errRtrn = mixin(_XkbErrCode3!("0x71", "first", "req.minKeyCode"));
        return 0;
    }
    if (last > req.maxKeyCode) {
        *errRtrn = mixin(_XkbErrCode3!("0x72", "last", "req.maxKeyCode"));
        return 0;
    }
    for (i = 0; i < req.totalVModMapKeys; i++, wire++) {
        /* Check we received enough data to read the next virtual mod map key */
        if (!_XkbCheckRequestBounds(client, req, wire, wire + 1)) {
            *errRtrn = mixin(_XkbErrCode3!("0x74", "first", "i"));
            return 0;
        }
        if ((wire.key < first) || (wire.key > last)) {
            *errRtrn = mixin(_XkbErrCode4!("0x73", "first", "last", "wire.key"));
            return 0;
        }
    }
    *wireRtrn = wire;
    return 1;
}

private char* SetKeyTypes(XkbDescPtr xkb, xkbSetMapReq* req, xkbKeyTypeWireDesc* wire, XkbChangesPtr changes)
{
    uint i = void;
    uint first = void, last = void;
    CARD8* map = void;

    if (cast(uint) (req.firstType + req.nTypes) > xkb.map.size_types) {
        i = req.firstType + req.nTypes;
        if (XkbAllocClientMap(xkb, XkbKeyTypesMask, i) != Success) {
            return null;
        }
    }
    if (cast(uint) (req.firstType + req.nTypes) > xkb.map.num_types)
        xkb.map.num_types = cast(ubyte)(req.firstType + req.nTypes);

    for (i = 0; i < req.nTypes; i++) {
        XkbKeyTypePtr pOld = void;
        uint n = void;

        if (XkbResizeKeyType(xkb, i + req.firstType, wire.nMapEntries,
                             wire.preserve, wire.numLevels) != Success) {
            return null;
        }
        pOld = &xkb.map.types[i + req.firstType];
        map = cast(CARD8*) &wire[1];

        pOld.mods.real_mods = wire.realMods;
        pOld.mods.vmods = wire.virtualMods;
        pOld.num_levels = wire.numLevels;
        pOld.map_count = wire.nMapEntries;

        pOld.mods.mask = cast(ubyte)(pOld.mods.real_mods |
            XkbMaskForVMask(xkb, pOld.mods.vmods));

        if (wire.nMapEntries) {
            xkbKTSetMapEntryWireDesc* mapWire = void;
            xkbModsWireDesc* preWire = void;
            uint tmp = void;

            mapWire = cast(xkbKTSetMapEntryWireDesc*) map;
            preWire = cast(xkbModsWireDesc*) &mapWire[wire.nMapEntries];
            for (n = 0; n < wire.nMapEntries; n++) {
                pOld.map[n].active = 1;
                pOld.map[n].mods.mask = mapWire[n].realMods;
                pOld.map[n].mods.real_mods = mapWire[n].realMods;
                pOld.map[n].mods.vmods = mapWire[n].virtualMods;
                pOld.map[n].level = mapWire[n].level;
                if (mapWire[n].virtualMods != 0) {
                    tmp = XkbMaskForVMask(xkb, mapWire[n].virtualMods);
                    pOld.map[n].active = (tmp != 0);
                    pOld.map[n].mods.mask |= tmp;
                }
                if (wire.preserve) {
                    pOld.preserve[n].real_mods = preWire[n].realMods;
                    pOld.preserve[n].vmods = preWire[n].virtualMods;
                    tmp = XkbMaskForVMask(xkb, preWire[n].virtualMods);
                    pOld.preserve[n].mask = cast(ubyte)(preWire[n].realMods | tmp);
                }
            }
            if (wire.preserve)
                map = cast(CARD8*) &preWire[wire.nMapEntries];
            else
                map = cast(CARD8*) &mapWire[wire.nMapEntries];
        }
        else
            map = cast(CARD8*) &wire[1];
        wire = cast(xkbKeyTypeWireDesc*) map;
    }
    first = req.firstType;
    last = first + req.nTypes - 1;     /* last changed type */
    if (changes.map.changed & XkbKeyTypesMask) {
        int oldLast = void;

        oldLast = changes.map.first_type + changes.map.num_types - 1;
        if (changes.map.first_type < first)
            first = changes.map.first_type;
        if (oldLast > last)
            last = oldLast;
    }
    changes.map.changed |= XkbKeyTypesMask;
    changes.map.first_type = cast(ubyte)(first);
    changes.map.num_types = cast(ubyte)((last - first) + 1);
    return cast(char*) wire;
}

private char* SetKeySyms(ClientPtr client, XkbDescPtr xkb, xkbSetMapReq* req, xkbSymMapWireDesc* wire, XkbChangesPtr changes, DeviceIntPtr dev)
{
    uint i = void, s = void;
    XkbSymMapPtr oldMap = void;
    KeySym* newSyms = void;
    KeySym* pSyms = void;
    uint first = void, last = void;

    oldMap = &xkb.map.key_sym_map[req.firstKeySym];
    for (i = 0; i < req.nKeySyms; i++, oldMap++) {
        pSyms = cast(KeySym*) &wire[1];
        if (wire.nSyms > 0) {
            newSyms = XkbResizeKeySyms(xkb, i + req.firstKeySym, wire.nSyms);
            for (s = 0; s < wire.nSyms; s++) {
                newSyms[s] = pSyms[s];
            }
            if (client.swapped) {
                for (s = 0; s < wire.nSyms; s++) {
                    swapl(&newSyms[s]);
                }
            }
        }
        if (mixin(XkbKeyHasActions!("xkb", "i + req.firstKeySym")))
            XkbResizeKeyActions(xkb, i + req.firstKeySym,
                                mixin(XkbNumGroups!("wire.groupInfo")) * wire.width);
        oldMap.kt_index[0] = wire.ktIndex[0];
        oldMap.kt_index[1] = wire.ktIndex[1];
        oldMap.kt_index[2] = wire.ktIndex[2];
        oldMap.kt_index[3] = wire.ktIndex[3];
        oldMap.group_info = wire.groupInfo;
        oldMap.width = wire.width;
        wire = cast(xkbSymMapWireDesc*) &pSyms[wire.nSyms];
    }
    first = req.firstKeySym;
    last = first + req.nKeySyms - 1;
    if (changes.map.changed & XkbKeySymsMask) {
        int oldLast = (changes.map.first_key_sym + changes.map.num_key_syms - 1);
        if (changes.map.first_key_sym < first)
            first = changes.map.first_key_sym;
        if (oldLast > last)
            last = oldLast;
    }
    changes.map.changed |= XkbKeySymsMask;
    changes.map.first_key_sym = cast(ubyte)(first);
    changes.map.num_key_syms = cast(ubyte)((last - first + 1));

    s = 0;
    for (i = xkb.min_key_code; i <= xkb.max_key_code; i++) {
        if (mixin(XkbKeyNumGroups!("xkb", "i")) > s)
            s = mixin(XkbKeyNumGroups!("xkb", "i"));
    }
    if (s != xkb.ctrls.num_groups) {
        xkbControlsNotify cn = {
            requestMajor: cast(ubyte)XkbReqCode,
            requestMinor: X_kbSetMap,
        };
        XkbControlsRec old = *xkb.ctrls;
        xkb.ctrls.num_groups = cast(ubyte)(s);
        if (XkbComputeControlsNotify(dev, &old, xkb.ctrls, &cn, FALSE))
            XkbSendControlsNotify(dev, &cn);
    }
    return cast(char*) wire;
}

private char* SetKeyActions(XkbDescPtr xkb, xkbSetMapReq* req, CARD8* wire, XkbChangesPtr changes)
{
    uint i = void, first = void, last = void;
    CARD8* nActs = wire;
    XkbAction* newActs = void;

    wire += mixin(XkbPaddedSize!("req.nKeyActs"));
    for (i = 0; i < req.nKeyActs; i++) {
        if (nActs[i] == 0)
            xkb.server.key_acts[i + req.firstKeyAct] = 0;
        else {
            newActs = XkbResizeKeyActions(xkb, i + req.firstKeyAct, nActs[i]);
            memcpy(cast(char*) newActs, cast(char*) wire,
                   nActs[i] * xkbActionWireDesc.sizeof);
            wire += nActs[i] * xkbActionWireDesc.sizeof;
        }
    }
    first = req.firstKeyAct;
    last = (first + req.nKeyActs - 1);
    if (changes.map.changed & XkbKeyActionsMask) {
        int oldLast = void;

        oldLast = changes.map.first_key_act + changes.map.num_key_acts - 1;
        if (changes.map.first_key_act < first)
            first = changes.map.first_key_act;
        if (oldLast > last)
            last = oldLast;
    }
    changes.map.changed |= XkbKeyActionsMask;
    changes.map.first_key_act = cast(ubyte)(first);
    changes.map.num_key_acts = cast(ubyte)((last - first + 1));
    return cast(char*) wire;
}

private char* SetKeyBehaviors(XkbSrvInfoPtr xkbi, xkbSetMapReq* req, xkbBehaviorWireDesc* wire, XkbChangesPtr changes)
{
    uint i = void;
    int maxRG = -1;
    XkbDescPtr xkb = xkbi.desc;
    XkbServerMapPtr server = xkb.server;
    uint first = void, last = void;

    first = req.firstKeyBehavior;
    last = req.firstKeyBehavior + req.nKeyBehaviors - 1;
    memset(&server.behaviors[first], 0,
           req.nKeyBehaviors * XkbBehavior.sizeof);
    for (i = 0; i < req.totalKeyBehaviors; i++) {
        if ((server.behaviors[wire.key].type & XkbKB_Permanent) == 0) {
            server.behaviors[wire.key].type = wire.type;
            server.behaviors[wire.key].data = wire.data;
            if ((wire.type == XkbKB_RadioGroup) &&
                ((cast(int) wire.data) > maxRG))
                maxRG = wire.data + 1;
        }
        wire++;
    }

    if (maxRG > cast(int) xkbi.nRadioGroups) {
        if (xkbi.radioGroups)
            xkbi.radioGroups = cast(_XkbRadioGroup*)reallocarray(xkbi.radioGroups, maxRG,
                                             XkbRadioGroupRec.sizeof);
        else
            xkbi.radioGroups = cast(_XkbRadioGroup*)calloc(maxRG, XkbRadioGroupRec.sizeof);
        if (xkbi.radioGroups) {
            if (xkbi.nRadioGroups)
                memset(&xkbi.radioGroups[xkbi.nRadioGroups], 0,
                       (maxRG - xkbi.nRadioGroups) * XkbRadioGroupRec.sizeof);
            xkbi.nRadioGroups = cast(ubyte)maxRG;
        }
        else
            xkbi.nRadioGroups = 0;
        /* should compute members here */
    }
    if (changes.map.changed & XkbKeyBehaviorsMask) {
        uint oldLast = void;

        oldLast = changes.map.first_key_behavior +
            changes.map.num_key_behaviors - 1;
        if (changes.map.first_key_behavior < req.firstKeyBehavior)
            first = changes.map.first_key_behavior;
        if (oldLast > last)
            last = oldLast;
    }
    changes.map.changed |= XkbKeyBehaviorsMask;
    changes.map.first_key_behavior = cast(ubyte)(first);
    changes.map.num_key_behaviors = cast(ubyte)((last - first + 1));
    return cast(char*) wire;
}

private char* SetVirtualMods(XkbSrvInfoPtr xkbi, xkbSetMapReq* req, CARD8* wire, XkbChangesPtr changes)
{
    int i = void, bit = void, nMods = void;
    XkbServerMapPtr srv = xkbi.desc.server;

    if (((req.present & XkbVirtualModsMask) == 0) || (req.virtualMods == 0))
        return cast(char*) wire;
    for (i = nMods = 0, bit = 1; i < XkbNumVirtualMods; i++, bit <<= 1) {
        if (req.virtualMods & bit) {
            if (srv.vmods[i] != wire[nMods]) {
                changes.map.changed |= XkbVirtualModsMask;
                changes.map.vmods |= bit;
                srv.vmods[i] = wire[nMods];
            }
            nMods++;
        }
    }
    return cast(char*) (wire + mixin(XkbPaddedSize!("nMods")));
}

private char* SetKeyExplicit(XkbSrvInfoPtr xkbi, xkbSetMapReq* req, CARD8* wire, XkbChangesPtr changes)
{
    uint i = void, first = void, last = void;
    XkbServerMapPtr xkb = xkbi.desc.server;
    CARD8* start = void;

    start = wire;
    first = req.firstKeyExplicit;
    last = req.firstKeyExplicit + req.nKeyExplicit - 1;
    memset(&xkb.explicit[first], 0, req.nKeyExplicit);
    for (i = 0; i < req.totalKeyExplicit; i++, wire += 2) {
        xkb.explicit[wire[0]] = wire[1];
    }
    if (first > 0) {
        if (changes.map.changed & XkbExplicitComponentsMask) {
            int oldLast = void;

            oldLast = changes.map.first_key_explicit +
                changes.map.num_key_explicit - 1;
            if (changes.map.first_key_explicit < first)
                first = changes.map.first_key_explicit;
            if (oldLast > last)
                last = oldLast;
        }
        changes.map.first_key_explicit = cast(ubyte)(first);
        changes.map.num_key_explicit = cast(ubyte)((last - first) + 1);
    }
    wire += mixin(XkbPaddedSize!("wire - start")) - (wire - start);
    return cast(char*) wire;
}

private char* SetModifierMap(XkbSrvInfoPtr xkbi, xkbSetMapReq* req, CARD8* wire, XkbChangesPtr changes)
{
    uint i = void, first = void, last = void;
    XkbClientMapPtr xkb = xkbi.desc.map;
    CARD8* start = void;

    start = wire;
    first = req.firstModMapKey;
    last = req.firstModMapKey + req.nModMapKeys - 1;
    memset(&xkb.modmap[first], 0, req.nModMapKeys);
    for (i = 0; i < req.totalModMapKeys; i++, wire += 2) {
        xkb.modmap[wire[0]] = wire[1];
    }
    if (first > 0) {
        if (changes.map.changed & XkbModifierMapMask) {
            int oldLast = void;

            oldLast = changes.map.first_modmap_key +
                changes.map.num_modmap_keys - 1;
            if (changes.map.first_modmap_key < first)
                first = changes.map.first_modmap_key;
            if (oldLast > last)
                last = oldLast;
        }
        changes.map.first_modmap_key = cast(ubyte)(first);
        changes.map.num_modmap_keys = cast(ubyte)((last - first) + 1);
    }
    wire += mixin(XkbPaddedSize!("wire - start")) - (wire - start);
    return cast(char*) wire;
}

private char* SetVirtualModMap(XkbSrvInfoPtr xkbi, xkbSetMapReq* req, xkbVModMapWireDesc* wire, XkbChangesPtr changes)
{
    uint i = void, first = void, last = void;
    XkbServerMapPtr srv = xkbi.desc.server;

    first = req.firstVModMapKey;
    last = req.firstVModMapKey + req.nVModMapKeys - 1;
    memset(&srv.vmodmap[first], 0, req.nVModMapKeys * ushort.sizeof);
    for (i = 0; i < req.totalVModMapKeys; i++, wire++) {
        srv.vmodmap[wire.key] = wire.vmods;
    }
    if (first > 0) {
        if (changes.map.changed & XkbVirtualModMapMask) {
            int oldLast = void;

            oldLast = changes.map.first_vmodmap_key +
                changes.map.num_vmodmap_keys - 1;
            if (changes.map.first_vmodmap_key < first)
                first = changes.map.first_vmodmap_key;
            if (oldLast > last)
                last = oldLast;
        }
        changes.map.first_vmodmap_key = cast(ubyte)(first);
        changes.map.num_vmodmap_keys = cast(ubyte)((last - first) + 1);
    }
    return cast(char*) wire;
}

enum string _add_check_len(string new_) = `
    if (len > UINT32_MAX - (` ~ new_ ~ `) || len > req_len - (` ~ new_ ~ `)) goto bad; 
    else len += ` ~ new_ ~ `;`;

/**
 * Check the length of the SetMap request
 */
private int _XkbSetMapCheckLength(xkbSetMapReq* req)
{
    size_t len = sz_xkbSetMapReq, req_len = req.length << 2;
    xkbKeyTypeWireDesc* keytype = void;
    xkbSymMapWireDesc* symmap = void;
    BOOL preserve = void;
    int i = void, map_count = void, nSyms = void;

    if (req_len < len)
        goto bad;
    /* types */
    if (req.present & XkbKeyTypesMask) {
        keytype = cast(xkbKeyTypeWireDesc*)(req + 1);
        for (i = 0; i < req.nTypes; i++) {
            mixin(_add_check_len!(XkbPaddedSize!("sz_xkbKeyTypeWireDesc")));
            mixin(_add_check_len!(`keytype.nMapEntries
                           * sz_xkbKTSetMapEntryWireDesc`));
            preserve = keytype.preserve;
            map_count = keytype.nMapEntries;
            if (preserve) {
                mixin(_add_check_len!(`map_count * sz_xkbModsWireDesc`));
            }
            keytype += 1;
            keytype = cast(xkbKeyTypeWireDesc*)
                      (cast(xkbKTSetMapEntryWireDesc*)keytype + map_count);
            if (preserve)
                keytype = cast(xkbKeyTypeWireDesc*)
                          (cast(xkbModsWireDesc*)keytype + map_count);
        }
    }
    /* syms */
    if (req.present & XkbKeySymsMask) {
        symmap = cast(xkbSymMapWireDesc*)(cast(char*)req + len);
        for (i = 0; i < req.nKeySyms; i++) {
            mixin(_add_check_len!(`sz_xkbSymMapWireDesc`));
            nSyms = symmap.nSyms;
            mixin(_add_check_len!(`nSyms*CARD32.sizeof`));
            symmap += 1;
            symmap = cast(xkbSymMapWireDesc*)(cast(CARD32*)symmap + nSyms);
        }
    }
    /* actions */
    if (req.present & XkbKeyActionsMask) {
        mixin(_add_check_len!(`req.totalActs * sz_xkbActionWireDesc
                       + mixin(XkbPaddedSize!("req.nKeyActs"))`));
    }
    /* behaviours */
    if (req.present & XkbKeyBehaviorsMask) {
        mixin(_add_check_len!(`req.totalKeyBehaviors * sz_xkbBehaviorWireDesc`));
    }
    /* vmods */
    if (req.present & XkbVirtualModsMask) {
        mixin(_add_check_len!(XkbPaddedSize!(`Ones(req.virtualMods)`)));
    }
    /* explicit */
    if (req.present & XkbExplicitComponentsMask) {
        /* two bytes per non-zero explicit componen */
        mixin(_add_check_len!(XkbPaddedSize!(`req.totalKeyExplicit * CARD16.sizeof`)));
    }
    /* modmap */
    if (req.present & XkbModifierMapMask) {
         /* two bytes per non-zero modmap component */
        mixin(_add_check_len!(XkbPaddedSize!(`req.totalModMapKeys * CARD16.sizeof`)));
    }
    /* vmodmap */
    if (req.present & XkbVirtualModMapMask) {
        mixin(_add_check_len!(`req.totalVModMapKeys * sz_xkbVModMapWireDesc`));
    }
    if (len == req_len)
        return Success;
bad:
    ErrorF("[xkb] BOGUS LENGTH in SetMap: expected %lu got %lu\n",
        cast(c_ulong)len, cast(c_ulong)req_len);
    return BadLength;
}


/**
 * Check if the given request can be applied to the given device but don't
 * actually do anything, except swap values when client->swapped and doswap are both true.
 */
private int _XkbSetMapChecks(ClientPtr client, DeviceIntPtr dev, xkbSetMapReq* req, char* values, Bool doswap)
{
    XkbSrvInfoPtr xkbi = void;
    XkbDescPtr xkb = void;
    int error = void;
    int nTypes = 0, nActions = void;
    CARD8[XkbMaxLegalKeyCode + 1] mapWidths = 0;
    CARD16[XkbMaxLegalKeyCode + 1] symsPerKey = 0;
    XkbSymMapPtr map = void;
    int i = void;

    if (!dev.key)
        return 0;

    xkbi = dev.key.xkbInfo;
    xkb = xkbi.desc;

    if ((xkb.min_key_code != req.minKeyCode) ||
        (xkb.max_key_code != req.maxKeyCode)) {
        if (client.xkbClientFlags & _XkbClientIsAncient) {
            /* pre 1.0 versions of Xlib have a bug */
            req.minKeyCode = xkb.min_key_code;
            req.maxKeyCode = xkb.max_key_code;
        }
        else {
            if (!mixin(XkbIsLegalKeycode!("req.minKeyCode"))) {
                client.errorValue =
                    mixin(_XkbErrCode3!(`2`, `req.minKeyCode`, `req.maxKeyCode`));
                return BadValue;
            }
            if (req.minKeyCode > req.maxKeyCode) {
                client.errorValue =
                    mixin(_XkbErrCode3!(`3`, `req.minKeyCode`, `req.maxKeyCode`));
                return BadMatch;
            }
        }
    }

    /* nTypes/mapWidths/symsPerKey must be filled for further tests below,
     * regardless of client-side flags */

    if (!CheckKeyTypes(client, xkb, req, cast(xkbKeyTypeWireDesc**) &values,
		       &nTypes, mapWidths.ptr, doswap)) {
	    client.errorValue = cast(uint)nTypes;
	    return BadValue;
    }

    map = &xkb.map.key_sym_map[xkb.min_key_code];
    for (i = xkb.min_key_code; i < xkb.max_key_code; i++, map++) {
        int g = void, ng = void, w = void;

        ng = mixin(XkbNumGroups!("map.group_info"));
        for (w = g = 0; g < ng; g++) {
            if (map.kt_index[g] >= cast(uint) nTypes) {
                client.errorValue = cast(uint)mixin(_XkbErrCode4!("0x13", "i", "g", "map.kt_index[g]"));
                return BadValue;
            }
            if (mapWidths[map.kt_index[g]] > w)
                w = mapWidths[map.kt_index[g]];
        }
        symsPerKey[i] = cast(ushort)(w * ng);
    }

    if ((req.present & XkbKeySymsMask) &&
        (!CheckKeySyms(client, xkb, req, nTypes, mapWidths.ptr, symsPerKey.ptr,
                       cast(xkbSymMapWireDesc**) &values, &error, doswap))) {
        client.errorValue = cast(uint)error;
        return BadValue;
    }

    if ((req.present & XkbKeyActionsMask) &&
        (!CheckKeyActions(client, xkb, req, nTypes, mapWidths.ptr, symsPerKey.ptr,
                          cast(CARD8**) &values, &nActions))) {
        client.errorValue = cast(uint)nActions;
        return BadValue;
    }

    if ((req.present & XkbKeyBehaviorsMask) &&
        (!CheckKeyBehaviors
         (client, xkb, req, cast(xkbBehaviorWireDesc**) &values, &error))) {
        client.errorValue = cast(uint)error;
        return BadValue;
    }

    if ((req.present & XkbVirtualModsMask) &&
        (!CheckVirtualMods(client, xkb, req, cast(CARD8**) &values, &error))) {
        client.errorValue = cast(uint)error;
        return BadValue;
    }
    if ((req.present & XkbExplicitComponentsMask) &&
        (!CheckKeyExplicit(client, xkb, req, cast(CARD8**) &values, &error))) {
        client.errorValue = cast(uint)error;
        return BadValue;
    }
    if ((req.present & XkbModifierMapMask) &&
        (!CheckModifierMap(client, xkb, req, cast(CARD8**) &values, &error))) {
        client.errorValue = cast(uint)error;
        return BadValue;
    }
    if ((req.present & XkbVirtualModMapMask) &&
        (!CheckVirtualModMap
         (client, xkb, req, cast(xkbVModMapWireDesc**) &values, &error))) {
        client.errorValue = cast(uint)error;
        return BadValue;
    }

    if (((values - (cast(char*) req)) / 4) != req.length) {
        ErrorF("[xkb] Internal error! Bad length in XkbSetMap (after check)\n");
        client.errorValue = cast(uint)(values - (cast(char*) &req[1]));
        return BadLength;
    }

    return Success;
}

/**
 * Apply the given request on the given device.
 */
private int _XkbSetMap(ClientPtr client, DeviceIntPtr dev, xkbSetMapReq* req, char* values)
{
    XkbEventCauseRec cause = { 0 };
    XkbChangesRec change = { 0 };
    Bool sentNKN = void;
    XkbSrvInfoPtr xkbi = void;
    XkbDescPtr xkb = void;

    if (!dev.key)
        return Success;

    xkbi = dev.key.xkbInfo;
    xkb = xkbi.desc;

    mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbSetMap`, `client`));
    memset(&change, 0, change.sizeof);
    sentNKN = FALSE;
    if ((xkb.min_key_code != req.minKeyCode) ||
        (xkb.max_key_code != req.maxKeyCode)) {
        Status status = void;
        xkbNewKeyboardNotify nkn = { 0 };

        nkn.deviceID = nkn.oldDeviceID = cast(ubyte)dev.id;
        nkn.oldMinKeyCode = xkb.min_key_code;
        nkn.oldMaxKeyCode = xkb.max_key_code;
        status = XkbChangeKeycodeRange(xkb, req.minKeyCode,
                                       req.maxKeyCode, &change);
        if (status != Success)
            return status;      /* oh-oh. what about the other keyboards? */
        nkn.minKeyCode = xkb.min_key_code;
        nkn.maxKeyCode = xkb.max_key_code;
        nkn.requestMajor = cast(ubyte)(XkbReqCode);
        nkn.requestMinor = X_kbSetMap;
        nkn.changed = cast(ushort)XkbNKN_KeycodesMask;
        XkbSendNewKeyboardNotify(dev, &nkn);
        sentNKN = TRUE;
    }

    if (req.present & XkbKeyTypesMask) {
        values = SetKeyTypes(xkb, req, cast(xkbKeyTypeWireDesc*) values, &change);
        if (!values)
            goto allocFailure;
    }
    if (req.present & XkbKeySymsMask) {
        values =
            SetKeySyms(client, xkb, req, cast(xkbSymMapWireDesc*) values, &change,
                       dev);
        if (!values)
            goto allocFailure;
    }
    if (req.present & XkbKeyActionsMask) {
        values = SetKeyActions(xkb, req, cast(CARD8*) values, &change);
        if (!values)
            goto allocFailure;
    }
    if (req.present & XkbKeyBehaviorsMask) {
        values =
            SetKeyBehaviors(xkbi, req, cast(xkbBehaviorWireDesc*) values, &change);
        if (!values)
            goto allocFailure;
    }
    if (req.present & XkbVirtualModsMask)
        values = SetVirtualMods(xkbi, req, cast(CARD8*) values, &change);
    if (req.present & XkbExplicitComponentsMask)
        values = SetKeyExplicit(xkbi, req, cast(CARD8*) values, &change);
    if (req.present & XkbModifierMapMask)
        values = SetModifierMap(xkbi, req, cast(CARD8*) values, &change);
    if (req.present & XkbVirtualModMapMask)
        values =
            SetVirtualModMap(xkbi, req, cast(xkbVModMapWireDesc*) values, &change);
    if (((values - (cast(char*) req)) / 4) != req.length) {
        ErrorF("[xkb] Internal error! Bad length in XkbSetMap (after set)\n");
        client.errorValue = cast(uint)(values - (cast(char*) &req[1]));
        return BadLength;
    }
    if (req.flags & XkbSetMapRecomputeActions) {
        KeyCode first = void, last = void, firstMM = void, lastMM = void;

        if (change.map.num_key_syms > 0) {
            first = change.map.first_key_sym;
            last = cast(ubyte)(first + change.map.num_key_syms - 1);
        }
        else
            first = last = 0;
        if (change.map.num_modmap_keys > 0) {
            firstMM = change.map.first_modmap_key;
            lastMM = cast(ubyte)(firstMM + change.map.num_modmap_keys - 1);
        }
        else
            firstMM = lastMM = 0;
        if ((last > 0) && (lastMM > 0)) {
            if (firstMM < first)
                first = firstMM;
            if (lastMM > last)
                last = lastMM;
        }
        else if (lastMM > 0) {
            first = firstMM;
            last = lastMM;
        }
        if (last > 0) {
            uint check = 0;

            XkbUpdateActions(dev, first, cast(ubyte)(last - first + 1), &change, &check,
                             &cause);
            if (check)
                XkbCheckSecondaryEffects(xkbi, check, &change, &cause);
        }
    }
    if (!sentNKN)
        XkbSendNotification(dev, &change, &cause);

    return Success;
 allocFailure:
    return BadAlloc;
}

int ProcXkbSetMap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSetMapReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"present");
    mixin(X_REQUEST_FIELD_CARD16!"flags");
    mixin(X_REQUEST_FIELD_CARD16!"totalSyms");
    mixin(X_REQUEST_FIELD_CARD16!"totalActs");
    mixin(X_REQUEST_FIELD_CARD16!"virtualMods");

    DeviceIntPtr dev = void, master = void;
    char* tmp = void;
    int rc = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixManageAccess`));
    mixin(CHK_MASK_LEGAL!(`0x01`, `stuff.present`, `XkbAllMapComponentsMask`));

    /* first verify the request length carefully */
    rc = _XkbSetMapCheckLength(stuff);
    if (rc != Success)
        return rc;

    tmp = cast(char*) &stuff[1];

    /* Check if we can to the SetMap on the requested device. If this
       succeeds, do the same thing for all extension devices (if needed).
       If any of them fails, fail.  */
    rc = _XkbSetMapChecks(client, dev, stuff, tmp, TRUE);

    if (rc != Success)
        return rc;

    master = GetMaster(dev, MASTER_KEYBOARD);

    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {
                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success) {
                    rc = _XkbSetMapChecks(client, other, stuff, tmp, FALSE);
                    if (rc != Success)
                        return rc;
                }
            }
        }
    } else {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if (other != dev && GetMaster(other, MASTER_KEYBOARD) != dev &&
                (other != master || dev != master.lastSlave))
                continue;

            rc = _XkbSetMapChecks(client, other, stuff, tmp, FALSE);
            if (rc != Success)
                return rc;
        }
    }

    /* We know now that we will succeed with the SetMap. In theory anyway. */
    rc = _XkbSetMap(client, dev, stuff, tmp);
    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {
                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success)
                    _XkbSetMap(client, other, stuff, tmp);
                /* ignore rc. if the SetMap failed although the check above
                   reported true there isn't much we can do. we still need to
                   set all other devices, hoping that at least they stay in
                   sync. */
            }
        }
    } else {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if (other != dev && GetMaster(other, MASTER_KEYBOARD) != dev &&
                (other != master || dev != master.lastSlave))
                continue;

            _XkbSetMap(client, other, stuff, tmp); //ignore rc
        }
    }

    return Success;
}

private Status XkbComputeGetCompatMapReplySize(XkbCompatMapPtr compat, xkbGetCompatMapReply* rep)
{
    uint size = void, nGroups = void;

    nGroups = 0;
    if (rep.groups != 0) {
        int i = void, bit = void;

        for (i = 0, bit = 1; i < XkbNumKbdGroups; i++, bit <<= 1) {
            if (rep.groups & bit)
                nGroups++;
        }
    }
    size = cast(uint)(nGroups * xkbModsWireDesc.sizeof);
    size += (rep.nSI * xkbSymInterpretWireDesc.sizeof);
    rep.length= cast(uint)(size / 4);
    return Success;
}

private void XkbAssembleCompatMap(ClientPtr client, XkbCompatMapPtr compat, xkbGetCompatMapReply rep, x_rpcbuf_t* rpcbuf)
{
        uint i = void, bit = void;
        XkbSymInterpretPtr sym = &compat.sym_interpret[rep.firstSI];

        for (i = 0; i < rep.nSI; i++, sym++) {
            /* write xkbSymInterpretWireDesc */
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)sym.sym);
            x_rpcbuf_write_CARD8(rpcbuf, sym.mods);
            x_rpcbuf_write_CARD8(rpcbuf, sym.match);
            x_rpcbuf_write_CARD8(rpcbuf, sym.virtual_mod);
            x_rpcbuf_write_CARD8(rpcbuf, sym.flags);
            /* write xkbActionWireDesc */
            x_rpcbuf_write_binary_pad(rpcbuf, &sym.act, xkbActionWireDesc.sizeof);
        }

        if (rep.groups) {
            for (i = 0, bit = 1; i < XkbNumKbdGroups; i++, bit <<= 1) {
                if (rep.groups & bit) {
                    /* write xkbModsWireDesc */
                    x_rpcbuf_write_CARD8(rpcbuf, compat.groups[i].mask);
                    x_rpcbuf_write_CARD8(rpcbuf, compat.groups[i].real_mods);
                    x_rpcbuf_write_CARD16(rpcbuf, compat.groups[i].vmods);
                }
            }
        }
        x_rpcbuf_pad(rpcbuf);
}

int ProcXkbGetCompatMap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetCompatMapReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"firstSI");
    mixin(X_REQUEST_FIELD_CARD16!"nSI");

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    DeviceIntPtr dev = void;
    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));

    XkbCompatMapPtr compat = dev.key.xkbInfo.desc.compat;

    CARD16 firstSI = stuff.firstSI;
    CARD16 nSI = stuff.nSI;

    if (stuff.getAllSI) {
        firstSI = 0;
        nSI = compat.num_si;
    }
    else if (((cast(uint) stuff.nSI) > 0) &&
             (cast(uint) (stuff.firstSI + stuff.nSI - 1) >= compat.num_si)) {
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x05", "compat.num_si"));
        return BadValue;
    }

    xkbGetCompatMapReply reply = {
        deviceID: cast(ubyte)dev.id,
        firstSI: firstSI,
        nSI: nSI,
        nTotalSI: compat.num_si,
        groups: stuff.groups,
    };

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    XkbAssembleCompatMap(client, compat, reply, &rpcbuf);

    if (rpcbuf.error)
        return BadAlloc;

    mixin(X_REPLY_FIELD_CARD16!"firstSI");
    mixin(X_REPLY_FIELD_CARD16!"nSI");
    mixin(X_REPLY_FIELD_CARD16!"nTotalSI");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/**
 * Apply the given request on the given device.
 * If dryRun is TRUE, then value checks are performed, but the device isn't
 * modified.
 */
private int _XkbSetCompatMap(ClientPtr client, DeviceIntPtr dev, xkbSetCompatMapReq* req, char* data, BOOL dryRun)
{
    XkbSrvInfoPtr xkbi = void;
    XkbDescPtr xkb = void;
    XkbCompatMapPtr compat = void;
    int nGroups = void;
    uint i = void, bit = void;

    xkbi = dev.key.xkbInfo;
    xkb = xkbi.desc;
    compat = xkb.compat;

    if ((req.nSI > 0) || (req.truncateSI)) {
        xkbSymInterpretWireDesc* wire = void;

        if (req.firstSI > compat.num_si) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x02", "compat.num_si"));
            return BadValue;
        }
        wire = cast(xkbSymInterpretWireDesc*) data;
        wire += req.nSI;
        data = cast(char*) wire;
    }

    nGroups = 0;
    if (req.groups != 0) {
        for (i = 0, bit = 1; i < XkbNumKbdGroups; i++, bit <<= 1) {
            if (req.groups & bit)
                nGroups++;
        }
    }
    data += nGroups * xkbModsWireDesc.sizeof;
    if (((data - (cast(char*) req)) / 4) != req.length) {
        return BadLength;
    }

    /* Done all the checks we can do */
    if (dryRun)
        return Success;

    data = cast(char*) &req[1];
    if (req.nSI > 0) {
        xkbSymInterpretWireDesc* wire = cast(xkbSymInterpretWireDesc*) data;
        XkbSymInterpretPtr sym = void;
        uint skipped = 0;

        if (cast(uint) (req.firstSI + req.nSI) > USHRT_MAX)
            return BadValue;
        if (cast(uint) (req.firstSI + req.nSI) > compat.size_si) {
            compat.num_si = compat.size_si = cast(ushort)(req.firstSI + req.nSI);
            compat.sym_interpret = cast(_XkbSymInterpretRec*)reallocarray(compat.sym_interpret,
                                                 compat.size_si,
                                                 XkbSymInterpretRec.sizeof);
            if (!compat.sym_interpret) {
                compat.num_si = compat.size_si = 0;
                return BadAlloc;
            }
        }
        else if (req.truncateSI || req.firstSI + req.nSI > compat.num_si) {
            compat.num_si = cast(ushort)(req.firstSI + req.nSI);
        }
        sym = &compat.sym_interpret[req.firstSI];
        for (i = 0; i < req.nSI; i++, wire++) {
            if (client.swapped) {
                swapl(&wire.sym);
            }
            if (wire.sym == NoSymbol && wire.match == XkbSI_AnyOfOrNone &&
                (wire.mods & 0xff) == 0xff &&
                wire.act.type == XkbSA_XFree86Private) {
                ErrorF("XKB: Skipping broken Any+AnyOfOrNone(All) -> Private "
                       ~ "action from client\n");
                skipped++;
                continue;
            }
            sym.sym = wire.sym;
            sym.mods = wire.mods;
            sym.match = wire.match;
            sym.flags = wire.flags;
            sym.virtual_mod = wire.virtualMod;
            memcpy(cast(char*) &sym.act, cast(char*) &wire.act,
                   xkbActionWireDesc.sizeof);
            sym++;
        }
        if (skipped) {
            if (req.firstSI + req.nSI < compat.num_si)
                memmove(sym, sym + skipped,
                        (compat.num_si - req.firstSI - req.nSI) *
                        typeof(*sym).sizeof);
            compat.num_si -= skipped;
        }
        data = cast(char*) wire;
    }
    else if (req.truncateSI) {
        compat.num_si = req.firstSI;
    }

    if (req.groups != 0) {
        xkbModsWireDesc* wire = cast(xkbModsWireDesc*) data;

        for (i = 0, bit = 1; i < XkbNumKbdGroups; i++, bit <<= 1) {
            if (req.groups & bit) {
                if (client.swapped) {
                    swaps(&wire.virtualMods);
                }
                compat.groups[i].mask = wire.realMods;
                compat.groups[i].real_mods = wire.realMods;
                compat.groups[i].vmods = wire.virtualMods;
                if (wire.virtualMods != 0) {
                    uint tmp = void;

                    tmp = XkbMaskForVMask(xkb, wire.virtualMods);
                    compat.groups[i].mask |= tmp;
                }
                data += xkbModsWireDesc.sizeof;
                wire = cast(xkbModsWireDesc*) data;
            }
        }
    }
    i = mixin(XkbPaddedSize!("(data - (cast(char*) req))"));
    if ((i / 4) != req.length) {
        ErrorF("[xkb] Internal length error on read in _XkbSetCompatMap\n");
        return BadLength;
    }

    if (dev.xkb_interest) {
        xkbCompatMapNotify ev = void;

        ev.deviceID= cast(ubyte)(dev.id);
        ev.changedGroups = req.groups;
        ev.firstSI = req.firstSI;
        ev.nSI = req.nSI;
        ev.nTotalSI = compat.num_si;
        XkbSendCompatMapNotify(dev, &ev);
    }

    if (req.recomputeActions) {
        XkbChangesRec change = { 0 };
        uint check = void;
        XkbEventCauseRec cause = { 0 };

        mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbSetCompatMap`, `client`));
        XkbUpdateActions(dev, xkb.min_key_code, cast(ubyte)mixin(XkbNumKeys!("xkb")), &change,
                         &check, &cause);
        if (check)
            XkbCheckSecondaryEffects(xkbi, check, &change, &cause);
        XkbSendNotification(dev, &change, &cause);
    }
    return Success;
}

int ProcXkbSetCompatMap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSetCompatMapReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"firstSI");
    mixin(X_REQUEST_FIELD_CARD16!"nSI");

    DeviceIntPtr dev = void;
    char* data = void;
    int rc = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixManageAccess`));

    data = cast(char*) &stuff[1];

    /* check first using a dry-run */
    rc = _XkbSetCompatMap(client, dev, stuff, data, TRUE);
    if (rc != Success)
        return rc;
    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {
                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success) {
                    /* dry-run */
                    rc = _XkbSetCompatMap(client, other, stuff, data, TRUE);
                    if (rc != Success)
                        return rc;
                }
            }
        }
    }

    /* Yay, the dry-runs succeed. Let's apply */
    rc = _XkbSetCompatMap(client, dev, stuff, data, FALSE);
    if (rc != Success)
        return rc;
    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {
                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success) {
                    rc = _XkbSetCompatMap(client, other, stuff, data, FALSE);
                    if (rc != Success)
                        return rc;
                }
            }
        }
    }

    return Success;
}

int ProcXkbGetIndicatorState(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetIndicatorStateReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");

    XkbSrvLedInfoPtr sli = void;
    DeviceIntPtr dev = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixReadAccess`));

    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId,
                            cast(uint)XkbXI_IndicatorStateMask);
    if (!sli)
        return BadAlloc;

    xkbGetIndicatorStateReply reply = {
        deviceID: cast(ubyte)dev.id,
        state: sli.effectiveState
    };

    mixin(X_REPLY_FIELD_CARD32!"state");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private Status XkbComputeGetIndicatorMapReplySize(XkbIndicatorPtr indicators, xkbGetIndicatorMapReply* rep)
{
    int i = void, bit = void;
    int nIndicators = void;

    rep.realIndicators= cast(uint)(indicators.phys_indicators);
    for (i = nIndicators = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
        if (rep.which & bit)
            nIndicators++;
    }
    rep.length= cast(uint)((nIndicators * xkbIndicatorMapWireDesc.sizeof) / 4);
    rep.nIndicators= cast(ubyte)(nIndicators);
    return Success;
}

private void XkbAssembleIndicatorMap(ClientPtr client, XkbIndicatorPtr indicators, xkbGetIndicatorMapReply rep, x_rpcbuf_t* rpcbuf)
{
    int i = void;
    uint bit = void;

    for (i = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
        if (rep.which & bit) {
            XkbIndicatorMapPtr entry = &indicators.maps[i];
            x_rpcbuf_write_CARD8(rpcbuf, entry.flags);
            x_rpcbuf_write_CARD8(rpcbuf, entry.which_groups);
            x_rpcbuf_write_CARD8(rpcbuf, entry.groups);
            x_rpcbuf_write_CARD8(rpcbuf, entry.which_mods);
            x_rpcbuf_write_CARD8(rpcbuf, entry.mods.mask);
            x_rpcbuf_write_CARD8(rpcbuf, entry.mods.real_mods);
            x_rpcbuf_write_CARD16(rpcbuf, entry.mods.vmods);
            x_rpcbuf_write_CARD32(rpcbuf, entry.ctrls);
        }
    }
}

int ProcXkbGetIndicatorMap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetIndicatorMapReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD32!"which");

    DeviceIntPtr dev = void;
    XkbDescPtr xkb = void;
    XkbIndicatorPtr leds = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));

    xkb = dev.key.xkbInfo.desc;
    leds = xkb.indicators;

    xkbGetIndicatorMapReply reply = {
        deviceID: cast(ubyte)dev.id,
        which: stuff.which
    };
    XkbComputeGetIndicatorMapReplySize(leds, &reply);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    XkbAssembleIndicatorMap(client, leds, reply, &rpcbuf);

    if (rpcbuf.error)
        return BadAlloc;

    mixin(X_REPLY_FIELD_CARD32!"which");
    mixin(X_REPLY_FIELD_CARD32!"realIndicators");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

/**
 * Apply the given map to the given device. Which specifies which components
 * to apply.
 */
private int _XkbSetIndicatorMap(ClientPtr client, DeviceIntPtr dev, int which, xkbIndicatorMapWireDesc* desc)
{
    XkbSrvInfoPtr xkbi = void;
    XkbSrvLedInfoPtr sli = void;
    XkbEventCauseRec cause = { 0 };
    int i = void, bit = void;

    xkbi = dev.key.xkbInfo;

    sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId,
                            cast(uint)XkbXI_IndicatorMapsMask);
    if (!sli)
        return BadAlloc;

    for (i = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
        if (which & bit) {
            sli.maps[i].flags = desc.flags;
            sli.maps[i].which_groups = desc.whichGroups;
            sli.maps[i].groups = desc.groups;
            sli.maps[i].which_mods = desc.whichMods;
            sli.maps[i].mods.mask = desc.mods;
            sli.maps[i].mods.real_mods = desc.mods;
            sli.maps[i].mods.vmods = desc.virtualMods;
            sli.maps[i].ctrls = cast(uint)desc.ctrls;
            if (desc.virtualMods != 0) {
                uint tmp = void;

                tmp = XkbMaskForVMask(xkbi.desc, desc.virtualMods);
                sli.maps[i].mods.mask = cast(ubyte)(desc.mods | tmp);
            }
            desc++;
        }
    }

    mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbSetIndicatorMap`, `client`));
    XkbApplyLedMapChanges(dev, sli, which, null, null, &cause);

    return Success;
}

int ProcXkbSetIndicatorMap(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSetIndicatorMapReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD32!"which");

    int i = void, bit = void;
    int nIndicators = void;
    DeviceIntPtr dev = void;
    xkbIndicatorMapWireDesc* from = void;
    int rc = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixSetAttrAccess`));

    if (stuff.which == 0)
        return Success;

    for (nIndicators = i = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
        if (stuff.which & bit)
            nIndicators++;
    }
    if (client.req_len != ((((xkbSetIndicatorMapReq).sizeof +
                           (nIndicators * xkbIndicatorMapWireDesc.sizeof))) /
                          4)) {
        return BadLength;
    }

    from = cast(xkbIndicatorMapWireDesc*) &stuff[1];
    for (i = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
        if (stuff.which & bit) {
            if (client.swapped) {
                swaps(&from.virtualMods);
                swapl(&from.ctrls);
            }
            mixin(CHK_MASK_LEGAL!(`i`, `from.whichGroups`, `XkbIM_UseAnyGroup`));
            mixin(CHK_MASK_LEGAL!(`i`, `from.whichMods`, `XkbIM_UseAnyMods`));
            from++;
        }
    }

    from = cast(xkbIndicatorMapWireDesc*) &stuff[1];
    rc = _XkbSetIndicatorMap(client, dev, cast(int)stuff.which, from);
    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {
                rc = dixCallDeviceAccessCallback(client, other, DixSetAttrAccess);
                if (rc == Success)
                    _XkbSetIndicatorMap(client, other, cast(int)stuff.which, from);
            }
        }
    }

    return Success;
}

int ProcXkbGetNamedIndicator(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetNamedIndicatorReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"ledClass");
    mixin(X_REQUEST_FIELD_CARD16!"ledID");
    mixin(X_REQUEST_FIELD_CARD32!"indicator");

    DeviceIntPtr dev = void;
    int i = 0;
    XkbSrvLedInfoPtr sli = void;
    XkbIndicatorMapPtr map = null;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_LED_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixReadAccess`));
    mixin(CHK_ATOM_ONLY!(`stuff.indicator`));

    sli = XkbFindSrvLedInfo(dev, stuff.ledClass, stuff.ledID, 0);
    if (!sli)
        return BadAlloc;

    i = 0;
    map = null;
    if ((sli.names) && (sli.maps)) {
        for (i = 0; i < XkbNumIndicators; i++) {
            if (stuff.indicator == sli.names[i]) {
                map = &sli.maps[i];
                break;
            }
        }
    }

    xkbGetNamedIndicatorReply reply = {
        deviceID: cast(ubyte)dev.id,
        indicator: stuff.indicator,
        supported: cast(ubyte)TRUE,
        ndx: XkbNoIndicator,
    };
    if (map !is null) {
        reply.found = TRUE;
        reply.on = ((sli.effectiveState & (1 << i)) != 0);
        reply.realIndicator = ((sli.physIndicators & (1 << i)) != 0);
        reply.ndx = cast(ubyte)i;
        reply.flags = map.flags;
        reply.whichGroups = map.which_groups;
        reply.groups = map.groups;
        reply.whichMods = map.which_mods;
        reply.mods = map.mods.mask;
        reply.realMods = map.mods.real_mods;
        reply.virtualMods = cast(ushort)map.mods.vmods;
        reply.ctrls = map.ctrls;
    }

    mixin(X_REPLY_FIELD_CARD32!"indicator");
    mixin(X_REPLY_FIELD_CARD16!"virtualMods");
    mixin(X_REPLY_FIELD_CARD32!"ctrls");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/**
 * Find the IM on the device.
 * Returns the map, or NULL if the map doesn't exist.
 * If the return value is NULL, led_return is undefined. Otherwise, led_return
 * is set to the led index of the map.
 */
private XkbIndicatorMapPtr _XkbFindNamedIndicatorMap(XkbSrvLedInfoPtr sli, Atom indicator, int* led_return)
{
    XkbIndicatorMapPtr map = void;

    /* search for the right indicator */
    map = null;
    if (sli.names && sli.maps) {
        int led = void;

        for (led = 0; (led < XkbNumIndicators) && (map is null); led++) {
            if (sli.names[led] == indicator) {
                map = &sli.maps[led];
                *led_return = led;
                break;
            }
        }
    }

    return map;
}

/**
 * Creates an indicator map on the device. If dryRun is TRUE, it only checks
 * if creation is possible, but doesn't actually create it.
 */
private int _XkbCreateIndicatorMap(DeviceIntPtr dev, Atom indicator, int ledClass, int ledID, XkbIndicatorMapPtr* map_return, int* led_return, Bool dryRun)
{
    XkbSrvLedInfoPtr sli = void;
    XkbIndicatorMapPtr map = void;
    int led = void;

    sli = XkbFindSrvLedInfo(dev, ledClass, ledID, XkbXI_IndicatorsMask);
    if (!sli)
        return BadAlloc;

    map = _XkbFindNamedIndicatorMap(sli, indicator, &led);

    if (!map) {
        /* find first unused indicator maps and assign the name to it */
        for (led = 0, map = null; (led < XkbNumIndicators) && (map is null);
             led++) {
            if ((sli.names) && (sli.maps) && (sli.names[led] == None) &&
                (!mixin(XkbIM_InUse!("&sli.maps[led]")))) {
                map = &sli.maps[led];
                if (!dryRun)
                    sli.names[led] = indicator;
                break;
            }
        }
    }

    if (!map)
        return BadAlloc;

    *led_return = led;
    *map_return = map;
    return Success;
}

private int _XkbSetNamedIndicator(ClientPtr client, DeviceIntPtr dev, xkbSetNamedIndicatorReq* stuff)
{
    uint statec = void, namec = void, mapc = void;
    XkbSrvLedInfoPtr sli = void;
    int led = 0;
    XkbIndicatorMapPtr map = void;
    DeviceIntPtr kbd = void;
    XkbEventCauseRec cause = { 0 };
    xkbExtensionDeviceNotify ed = { 0 };
    XkbChangesRec changes = { 0 };
    int rc = void;

    rc = _XkbCreateIndicatorMap(dev, stuff.indicator, stuff.ledClass,
                                stuff.ledID, &map, &led, FALSE);
    if (rc != Success || !map)  /* oh-oh */
        return rc;

    sli = XkbFindSrvLedInfo(dev, stuff.ledClass, stuff.ledID,
                            XkbXI_IndicatorsMask);
    if (!sli)
        return BadAlloc;

    namec = mapc = statec = 0;

    namec |= (1 << led);
    sli.namesPresent |= ((stuff.indicator != None) ? (1 << led) : 0);

    if (stuff.setMap) {
        map.flags = stuff.flags;
        map.which_groups = stuff.whichGroups;
        map.groups = stuff.groups;
        map.which_mods = stuff.whichMods;
        map.mods.mask = stuff.realMods;
        map.mods.real_mods = stuff.realMods;
        map.mods.vmods = stuff.virtualMods;
        map.ctrls = cast(uint)stuff.ctrls;
        mapc |= (1 << led);
    }

    if ((stuff.setState) && ((map.flags & XkbIM_NoExplicit) == 0)) {
        if (stuff.on)
            sli.explicitState |= (1 << led);
        else
            sli.explicitState &= ~(1 << led);
        statec |= ((sli.effectiveState ^ sli.explicitState) & (1 << led));
    }

    mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbSetNamedIndicator`, `client`));
    if (namec)
        XkbApplyLedNameChanges(dev, sli, namec, &ed, &changes, &cause);
    if (mapc)
        XkbApplyLedMapChanges(dev, sli, mapc, &ed, &changes, &cause);
    if (statec)
        XkbApplyLedStateChanges(dev, sli, statec, &ed, &changes, &cause);

    kbd = dev;
    if ((sli.flags & XkbSLI_HasOwnState) == 0)
        kbd = inputInfo.keyboard;
    XkbFlushLedEvents(dev, kbd, sli, &ed, &changes, &cause);

    return Success;
}

int ProcXkbSetNamedIndicator(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbSetNamedIndicatorReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"ledClass");
    mixin(X_REQUEST_FIELD_CARD16!"ledID");
    mixin(X_REQUEST_FIELD_CARD32!"indicator");
    mixin(X_REQUEST_FIELD_CARD16!"virtualMods");
    mixin(X_REQUEST_FIELD_CARD32!"ctrls");

    int rc = void;
    DeviceIntPtr dev = void;
    int led = 0;
    XkbIndicatorMapPtr map = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_LED_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixSetAttrAccess`));
    mixin(CHK_ATOM_ONLY!(`stuff.indicator`));
    mixin(CHK_MASK_LEGAL!(`0x10`, `stuff.whichGroups`, `XkbIM_UseAnyGroup`));
    mixin(CHK_MASK_LEGAL!(`0X11`, `stuff.whichMods`, `XkbIM_UseAnyMods`));

    /* Dry-run for checks */
    rc = _XkbCreateIndicatorMap(dev, stuff.indicator,
                                stuff.ledClass, stuff.ledID,
                                &map, &led, TRUE);
    if (rc != Success || !map)  /* couldn't be created or didn't exist */
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd ||
        stuff.deviceSpec == XkbUseCorePtr) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev && (other.kbdfeed ||
                                                             other.leds) &&
                (dixCallDeviceAccessCallback(client, other, DixSetAttrAccess)
                 == Success)) {
                rc = _XkbCreateIndicatorMap(other, stuff.indicator,
                                            stuff.ledClass, stuff.ledID, &map,
                                            &led, TRUE);
                if (rc != Success || !map)
                    return rc;
            }
        }
    }

    /* All checks passed, let's do it */
    rc = _XkbSetNamedIndicator(client, dev, stuff);
    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd ||
        stuff.deviceSpec == XkbUseCorePtr) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev && (other.kbdfeed ||
                                                             other.leds) &&
                (dixCallDeviceAccessCallback(client, other, DixSetAttrAccess)
                 == Success)) {
                _XkbSetNamedIndicator(client, other, stuff);
            }
        }
    }

    return Success;
}

private CARD32 _XkbCountAtoms(Atom* atoms, int maxAtoms, int* count)
{
    uint i = void, bit = void, nAtoms = void;
    CARD32 atomsPresent = void;

    for (i = nAtoms = atomsPresent = 0, bit = 1; i < maxAtoms; i++, bit <<= 1) {
        if (atoms[i] != None) {
            atomsPresent |= bit;
            nAtoms++;
        }
    }
    if (count)
        *count = nAtoms;
    return atomsPresent;
}

private void __rpcbuf_write_atoms(x_rpcbuf_t* rpcbuf, Atom* atoms, size_t maxAtoms)
{
    for (size_t i = 0; i < maxAtoms; i++) {
        if (atoms[i] != None)
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)atoms[i]);
    }
}

private Status XkbComputeGetNamesReplySize(XkbDescPtr xkb, xkbGetNamesReply* rep)
{
    uint which = void, length = void;
    int i = void;

    rep.minKeyCode = xkb.min_key_code;
    rep.maxKeyCode = xkb.max_key_code;
    which = cast(uint)rep.which;
    length = 0;
    if (xkb.names !is null) {
        if (which & XkbKeycodesNameMask)
            length++;
        if (which & XkbGeometryNameMask)
            length++;
        if (which & XkbSymbolsNameMask)
            length++;
        if (which & XkbPhysSymbolsNameMask)
            length++;
        if (which & XkbTypesNameMask)
            length++;
        if (which & XkbCompatNameMask)
            length++;
    }
    else
        which &= ~XkbComponentNamesMask;

    if (xkb.map !is null) {
        if (which & XkbKeyTypeNamesMask)
            length += xkb.map.num_types;
        rep.nTypes = xkb.map.num_types;
        if (which & XkbKTLevelNamesMask) {
            XkbKeyTypePtr pType = xkb.map.types;
            int nKTLevels = 0;

            length += mixin(XkbPaddedSize!("xkb.map.num_types")) / 4;
            for (i = 0; i < xkb.map.num_types; i++, pType++) {
                if (pType.level_names !is null)
                    nKTLevels += pType.num_levels;
            }
            rep.nKTLevels = cast(ushort)nKTLevels;
            length += nKTLevels;
        }
    }
    else {
        rep.nTypes = 0;
        rep.nKTLevels = 0;
        which &= ~(XkbKeyTypeNamesMask | XkbKTLevelNamesMask);
    }

    rep.minKeyCode = xkb.min_key_code;
    rep.maxKeyCode = xkb.max_key_code;
    rep.indicators = 0;
    rep.virtualMods = 0;
    rep.groupNames = 0;
    if (xkb.names !is null) {
        if (which & XkbIndicatorNamesMask) {
            int nLeds = void;

            rep.indicators =
                _XkbCountAtoms(xkb.names.indicators.ptr, XkbNumIndicators,
                               &nLeds);
            length += nLeds;
            if (nLeds == 0)
                which &= ~XkbIndicatorNamesMask;
        }

        if (which & XkbVirtualModNamesMask) {
            int nVMods = void;

            rep.virtualMods =
                cast(ushort)_XkbCountAtoms(xkb.names.vmods.ptr, XkbNumVirtualMods, &nVMods);
            length += nVMods;
            if (nVMods == 0)
                which &= ~XkbVirtualModNamesMask;
        }

        if (which & XkbGroupNamesMask) {
            int nGroups = void;

            rep.groupNames =
                cast(ubyte)_XkbCountAtoms(xkb.names.groups.ptr, XkbNumKbdGroups, &nGroups);
            length += nGroups;
            if (nGroups == 0)
                which &= ~XkbGroupNamesMask;
        }

        if ((which & XkbKeyNamesMask) && (xkb.names.keys))
            length += rep.nKeys;
        else
            which &= ~XkbKeyNamesMask;

        if ((which & XkbKeyAliasesMask) &&
            (xkb.names.key_aliases) && (xkb.names.num_key_aliases > 0)) {
            rep.nKeyAliases = xkb.names.num_key_aliases;
            length += rep.nKeyAliases * 2;
        }
        else {
            which &= ~XkbKeyAliasesMask;
            rep.nKeyAliases = 0;
        }

        if ((which & XkbRGNamesMask) && (xkb.names.num_rg > 0))
            length += xkb.names.num_rg;
        else
            which &= ~XkbRGNamesMask;
    }
    else {
        which &= ~(XkbIndicatorNamesMask | XkbVirtualModNamesMask);
        which &= ~(XkbGroupNamesMask | XkbKeyNamesMask | XkbKeyAliasesMask);
        which &= ~XkbRGNamesMask;
    }

    rep.length= cast(uint)(length);
    rep.which = which;
    return Success;
}

private void XkbAssembleNames(ClientPtr client, XkbDescPtr xkb, xkbGetNamesReply rep, x_rpcbuf_t* rpcbuf)
{
    uint i = void, which = void;

    which = cast(uint)rep.which;

    if (xkb.names) {
        if (which & XkbKeycodesNameMask) {
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)xkb.names.keycodes);
        }
        if (which & XkbGeometryNameMask) {
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)xkb.names.geometry);
        }
        if (which & XkbSymbolsNameMask) {
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)xkb.names.symbols);
        }
        if (which & XkbPhysSymbolsNameMask) {
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)xkb.names.phys_symbols);
        }
        if (which & XkbTypesNameMask) {
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)xkb.names.types);
        }
        if (which & XkbCompatNameMask) {
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)xkb.names.compat);
        }
        if (which & XkbKeyTypeNamesMask) {
            for (i = 0; i < xkb.map.num_types; i++) {
                x_rpcbuf_write_CARD32(rpcbuf, cast(uint)xkb.map.types[i].name);
            }
        }
        if (which & XkbKTLevelNamesMask && xkb.map) {
            XkbKeyTypePtr type = xkb.map.types;

            for (i = 0; i < rep.nTypes; i++, type++) {
                /* Either no name or all of them, even empty ones */
                x_rpcbuf_write_CARD8(rpcbuf, type.level_names ? type.num_levels : 0);
            }
            x_rpcbuf_pad(rpcbuf);

            type = xkb.map.types;
            for (i = 0; i < xkb.map.num_types; i++, type++) {
                for (int l = 0; l < type.num_levels; l++) {
                    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)type.level_names[l]);
                }
            }
        }
        if (which & XkbIndicatorNamesMask) {
            __rpcbuf_write_atoms(rpcbuf, xkb.names.indicators.ptr, XkbNumIndicators);
        }
        if (which & XkbVirtualModNamesMask) {
            __rpcbuf_write_atoms(rpcbuf, xkb.names.vmods.ptr, XkbNumVirtualMods);
        }
        if (which & XkbGroupNamesMask) {
            __rpcbuf_write_atoms(rpcbuf, xkb.names.groups.ptr, XkbNumKbdGroups);
        }
        if (which & XkbKeyNamesMask) {
            x_rpcbuf_write_binary_pad(rpcbuf,
                                      &(xkb.names.keys[rep.firstKey]),
                                      ((XkbKeyNameRec).sizeof * rep.nKeys));
        }
        if (which & XkbKeyAliasesMask) {
            x_rpcbuf_write_binary_pad(rpcbuf,
                                      xkb.names.key_aliases,
                                      ((XkbKeyAliasRec).sizeof * rep.nKeyAliases));
        }
        if ((which & XkbRGNamesMask) && (rep.nRadioGroups > 0)) {
            x_rpcbuf_write_CARD32s(rpcbuf, xkb.names.radio_groups, rep.nRadioGroups);
        }
    }
}

int ProcXkbGetNames(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetNamesReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD32!"which");

    DeviceIntPtr dev = void;
    XkbDescPtr xkb = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));
    mixin(CHK_MASK_LEGAL!(`0x01`, `stuff.which`, `XkbAllNamesMask`));

    xkb = dev.key.xkbInfo.desc;

    xkbGetNamesReply reply = {
        deviceID: cast(ubyte)dev.id,
        which: stuff.which,
        nTypes: xkb.map.num_types,
        firstKey: xkb.min_key_code,
        nKeys: cast(ubyte)mixin(XkbNumKeys!("xkb")),
        nKeyAliases: xkb.names ? xkb.names.num_key_aliases : 0,
        nRadioGroups: cast(ubyte)(xkb.names ? xkb.names.num_rg : 0)
    };
    XkbComputeGetNamesReplySize(xkb, &reply);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    XkbAssembleNames(client, xkb, reply, &rpcbuf);

    if (rpcbuf.error)
        return BadAlloc;

    mixin(X_REPLY_FIELD_CARD32!"which");
    mixin(X_REPLY_FIELD_CARD16!"virtualMods");
    mixin(X_REPLY_FIELD_CARD32!"indicators");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private CARD32* _XkbCheckAtoms(CARD32* wire, int nAtoms, int swapped, Atom* pError)
{
    int i = void;

    for (i = 0; i < nAtoms; i++, wire++) {
        if (swapped) {
            swapl(wire);
        }
        if (((cast(Atom) (*wire)) != None) && (!ValidAtom(cast(Atom) (*wire)))) {
            *pError = (cast(Atom) (*wire));
            return null;
        }
    }
    return wire;
}

private CARD32* _XkbCheckMaskedAtoms(CARD32* wire, int nAtoms, CARD32 present, int swapped, Atom* pError)
{
    uint i = void, bit = void;

    for (i = 0, bit = 1; (i < nAtoms) && (present); i++, bit <<= 1) {
        if ((present & bit) == 0)
            continue;
        if (swapped) {
            swapl(wire);
        }
        if (((cast(Atom) (*wire)) != None) && (!ValidAtom((cast(Atom) (*wire))))) {
            *pError = cast(Atom) (*wire);
            return null;
        }
        wire++;
    }
    return wire;
}

private Atom* _XkbCopyMaskedAtoms(Atom* wire, Atom* dest, int nAtoms, CARD32 present)
{
    int i = void, bit = void;

    for (i = 0, bit = 1; (i < nAtoms) && (present); i++, bit <<= 1) {
        if ((present & bit) == 0)
            continue;
        dest[i] = *wire++;
    }
    return wire;
}

private Bool _XkbCheckTypeName(Atom name, int typeNdx)
{
    const(char)* str = void;

    str = NameForAtom(name);
    if ((strcmp(str, "ONE_LEVEL") == 0) || (strcmp(str, "TWO_LEVEL") == 0) ||
        (strcmp(str, "ALPHABETIC") == 0) || (strcmp(str, "KEYPAD") == 0))
        return FALSE;
    return TRUE;
}

/**
 * Check the device-dependent data in the request against the device. Returns
 * Success, or the appropriate error code.
 */
private int _XkbSetNamesCheck(ClientPtr client, DeviceIntPtr dev, xkbSetNamesReq* stuff, CARD32* data)
{
    XkbDescRec* xkb = void;
    CARD32* tmp = void;
    Atom bad = None;

    tmp = data;
    xkb = dev.key.xkbInfo.desc;

    if (stuff.which & XkbKeyTypeNamesMask) {
        int i = void;
        CARD32* old = void;

        if (stuff.nTypes < 1) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x02", "stuff.nTypes"));
            return BadValue;
        }
        if (cast(uint) (stuff.firstType + stuff.nTypes - 1) >=
            xkb.map.num_types) {
            client.errorValue =
                mixin(_XkbErrCode4!("0x03", "stuff.firstType", "stuff.nTypes", "xkb.map.num_types"));
            return BadValue;
        }
        if ((cast(uint) stuff.firstType) <= XkbLastRequiredType) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x04", "stuff.firstType"));
            return BadAccess;
        }
        if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + stuff.nTypes))
            return BadLength;
        old = tmp;
        tmp = _XkbCheckAtoms(tmp, stuff.nTypes, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
        for (i = 0; i < stuff.nTypes; i++, old++) {
            if (!_XkbCheckTypeName(cast(Atom)( *old), stuff.firstType + i))
                client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x05", "i"));
        }
    }
    if (stuff.which & XkbKTLevelNamesMask) {
        uint i = void;
        XkbKeyTypePtr type = void;
        CARD8* width = void;

        if (stuff.nKTLevels < 1) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x05", "stuff.nKTLevels"));
            return BadValue;
        }
        if (cast(uint) (stuff.firstKTLevel + stuff.nKTLevels - 1) >=
            xkb.map.num_types) {
            client.errorValue = cast(uint)mixin(_XkbErrCode4!("0x06", "stuff.firstKTLevel", "stuff.nKTLevels", "xkb.map.num_types"));
            return BadValue;
        }
        width = cast(CARD8*) tmp;
        tmp = cast(CARD32*) ((cast(char*) tmp) + mixin(XkbPaddedSize!("stuff.nKTLevels")));
        if (!_XkbCheckRequestBounds(client, stuff, width, tmp))
            return BadLength;
        type = &xkb.map.types[stuff.firstKTLevel];
        for (i = 0; i < stuff.nKTLevels; i++, type++) {
            if (width[i] == 0)
                continue;
            else if (width[i] != type.num_levels) {
                client.errorValue = cast(uint)mixin(_XkbErrCode4!("0x07", "i + stuff.firstKTLevel", "type.num_levels", "width[i]"));
                return BadMatch;
            }
            if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + width[i]))
                return BadLength;
            tmp = _XkbCheckAtoms(tmp, width[i], client.swapped, &bad);
            if (!tmp) {
                client.errorValue = cast(uint)bad;
                return BadAtom;
            }
        }
    }
    if (stuff.which & XkbIndicatorNamesMask) {
        if (stuff.indicators == 0) {
            client.errorValue = cast(uint)0x08;
            return BadMatch;
        }
        if (!_XkbCheckRequestBounds(client, stuff, tmp,
                                    tmp + Ones(stuff.indicators)))
            return BadLength;
        tmp = _XkbCheckMaskedAtoms(tmp, XkbNumIndicators, stuff.indicators,
                                   client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (stuff.which & XkbVirtualModNamesMask) {
        if (stuff.virtualMods == 0) {
            client.errorValue = cast(uint)0x09;
            return BadMatch;
        }
        if (!_XkbCheckRequestBounds(client, stuff, tmp,
                                    tmp + Ones(stuff.virtualMods)))
            return BadLength;
        tmp = _XkbCheckMaskedAtoms(tmp, XkbNumVirtualMods,
                                   cast(CARD32) stuff.virtualMods,
                                   client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (stuff.which & XkbGroupNamesMask) {
        if (stuff.groupNames == 0) {
            client.errorValue = cast(uint)0x0a;
            return BadMatch;
        }
        if (!_XkbCheckRequestBounds(client, stuff, tmp,
                                    tmp + Ones(stuff.groupNames)))
            return BadLength;
        tmp = _XkbCheckMaskedAtoms(tmp, XkbNumKbdGroups,
                                   cast(CARD32) stuff.groupNames,
                                   client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (stuff.which & XkbKeyNamesMask) {
        if (stuff.firstKey < cast(uint) xkb.min_key_code) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x0b", "xkb.min_key_code",
                                              "stuff.firstKey"));
            return BadValue;
        }
        if ((cast(uint) (stuff.firstKey + stuff.nKeys - 1) >
             xkb.max_key_code) || (stuff.nKeys < 1)) {
            client.errorValue =
                mixin(_XkbErrCode4!("0x0c", "xkb.max_key_code", "stuff.firstKey", "stuff.nKeys"));
            return BadValue;
        }
        if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + stuff.nKeys))
            return BadLength;
        tmp += stuff.nKeys;
    }
    if ((stuff.which & XkbKeyAliasesMask) && (stuff.nKeyAliases > 0)) {
        if (!_XkbCheckRequestBounds(client, stuff, tmp,
                                    tmp + (stuff.nKeyAliases * 2)))
            return BadLength;
        tmp += stuff.nKeyAliases * 2;
    }
    if (stuff.which & XkbRGNamesMask) {
        if (stuff.nRadioGroups < 1) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x0d", "stuff.nRadioGroups"));
            return BadValue;
        }
        if (!_XkbCheckRequestBounds(client, stuff, tmp,
                                    tmp + stuff.nRadioGroups))
            return BadLength;
        tmp = _XkbCheckAtoms(tmp, stuff.nRadioGroups, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if ((tmp - (cast(CARD32*) stuff)) != client.req_len) {
        client.errorValue = cast(uint)client.req_len;
        return BadLength;
    }

    return Success;
}

private int _XkbSetNames(ClientPtr client, DeviceIntPtr dev, xkbSetNamesReq* stuff)
{
    XkbDescRec* xkb = void;
    XkbNamesRec* names = void;
    CARD32* tmp = void;
    xkbNamesNotify nn = { 0 };

    tmp = cast(CARD32*) &stuff[1];
    xkb = dev.key.xkbInfo.desc;
    names = xkb.names;

    if (XkbAllocNames(xkb, cast(uint)stuff.which, stuff.nRadioGroups,
                      stuff.nKeyAliases) != Success) {
        return BadAlloc;
    }

    memset(&nn, 0, xkbNamesNotify.sizeof);
    nn.changed = cast(ushort)stuff.which;
    tmp = cast(CARD32*) &stuff[1];
    if (stuff.which & XkbKeycodesNameMask)
        names.keycodes = *tmp++;
    if (stuff.which & XkbGeometryNameMask)
        names.geometry = *tmp++;
    if (stuff.which & XkbSymbolsNameMask)
        names.symbols = *tmp++;
    if (stuff.which & XkbPhysSymbolsNameMask)
        names.phys_symbols = *tmp++;
    if (stuff.which & XkbTypesNameMask)
        names.types = *tmp++;
    if (stuff.which & XkbCompatNameMask)
        names.compat = *tmp++;
    if ((stuff.which & XkbKeyTypeNamesMask) && (stuff.nTypes > 0)) {
        uint i = void;
        XkbKeyTypePtr type = void;

        type = &xkb.map.types[stuff.firstType];
        for (i = 0; i < stuff.nTypes; i++, type++) {
            type.name = *tmp++;
        }
        nn.firstType = stuff.firstType;
        nn.nTypes = stuff.nTypes;
    }
    if (stuff.which & XkbKTLevelNamesMask) {
        XkbKeyTypePtr type = void;
        uint i = void;
        CARD8* width = void;

        width = cast(CARD8*) tmp;
        tmp = cast(CARD32*) ((cast(char*) tmp) + mixin(XkbPaddedSize!("stuff.nKTLevels")));
        type = &xkb.map.types[stuff.firstKTLevel];
        for (i = 0; i < stuff.nKTLevels; i++, type++) {
            if (width[i] > 0) {
                if (type.level_names) {
                    uint n = void;

                    for (n = 0; n < width[i]; n++) {
                        type.level_names[n] = tmp[n];
                    }
                }
                tmp += width[i];
            }
        }
        nn.firstLevelName = 0;
        nn.nLevelNames = stuff.nTypes;
    }
    if (stuff.which & XkbIndicatorNamesMask) {
        tmp = _XkbCopyMaskedAtoms(cast(uint*)tmp, names.indicators.ptr, XkbNumIndicators,
                                  stuff.indicators);
        nn.changedIndicators = stuff.indicators;
    }
    if (stuff.which & XkbVirtualModNamesMask) {
        tmp = _XkbCopyMaskedAtoms(cast(uint*)tmp, names.vmods.ptr, XkbNumVirtualMods,
                                  stuff.virtualMods);
        nn.changedVirtualMods = stuff.virtualMods;
    }
    if (stuff.which & XkbGroupNamesMask) {
        tmp = _XkbCopyMaskedAtoms(cast(uint*)tmp, names.groups.ptr, XkbNumKbdGroups,
                                  stuff.groupNames);
        nn.changedVirtualMods = stuff.groupNames;
    }
    if (stuff.which & XkbKeyNamesMask) {
        memcpy(cast(char*) &names.keys[stuff.firstKey], cast(char*) tmp,
               stuff.nKeys * XkbKeyNameLength);
        tmp += stuff.nKeys;
        nn.firstKey = stuff.firstKey;
        nn.nKeys = stuff.nKeys;
    }
    if (stuff.which & XkbKeyAliasesMask) {
        if (stuff.nKeyAliases > 0) {
            int na = stuff.nKeyAliases;

            if (XkbAllocNames(xkb, XkbKeyAliasesMask, 0, na) != Success)
                return BadAlloc;
            memcpy(cast(char*) names.key_aliases, cast(char*) tmp,
                   stuff.nKeyAliases * XkbKeyAliasRec.sizeof);
            tmp += stuff.nKeyAliases * 2;
        }
        else if (names.key_aliases !is null) {
            free(names.key_aliases);
            names.key_aliases = null;
            names.num_key_aliases = cast(ubyte)0;
        }
        nn.nAliases = names.num_key_aliases;
    }
    if (stuff.which & XkbRGNamesMask) {
        if (stuff.nRadioGroups > 0) {
            uint i = void, nrg = void;

            nrg = stuff.nRadioGroups;
            if (XkbAllocNames(xkb, XkbRGNamesMask, nrg, 0) != Success)
                return BadAlloc;

            for (i = 0; i < stuff.nRadioGroups; i++) {
                names.radio_groups[i] = tmp[i];
            }
            tmp += stuff.nRadioGroups;
        }
        else if (names.radio_groups) {
            free(names.radio_groups);
            names.radio_groups = null;
            names.num_rg = cast(ushort)0;
        }
        nn.nRadioGroups = cast(ubyte)names.num_rg;
    }
    if (nn.changed) {
        Bool needExtEvent = void;

        needExtEvent = (nn.changed & XkbIndicatorNamesMask) != 0;
        XkbSendNamesNotify(dev, &nn);
        if (needExtEvent) {
            XkbSrvLedInfoPtr sli = void;
            xkbExtensionDeviceNotify edev = void;
            int i = void;
            uint bit = void;

            sli = XkbFindSrvLedInfo(dev, XkbDfltXIClass, XkbDfltXIId,
                                    XkbXI_IndicatorsMask);
            sli.namesPresent = 0;
            for (i = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
                if (names.indicators[i] != None)
                    sli.namesPresent |= bit;
            }
            memset(&edev, 0, xkbExtensionDeviceNotify.sizeof);
            edev.reason = cast(ushort)XkbXI_IndicatorNamesMask;
            edev.ledClass = KbdFeedbackClass;
            edev.ledID = dev.kbdfeed.ctrl.id;
            edev.ledsDefined = sli.namesPresent | sli.mapsPresent;
            edev.ledState = sli.effectiveState;
            edev.firstBtn = 0;
            edev.nBtns = 0;
            edev.supported = cast(ushort)XkbXI_AllFeaturesMask;
            edev.unsupported = 0;
            XkbSendExtensionDeviceNotify(dev, client, &edev);
        }
    }
    return Success;
}

int ProcXkbSetNames(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSetNamesReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"virtualMods");
    mixin(X_REQUEST_FIELD_CARD32!"which");
    mixin(X_REQUEST_FIELD_CARD32!"indicators");
    mixin(X_REQUEST_FIELD_CARD16!"totalKTLevelNames");

    DeviceIntPtr dev = void;
    CARD32* tmp = void;
    Atom bad = void;
    int rc = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixManageAccess`));
    mixin(CHK_MASK_LEGAL!(`0x01`, `stuff.which`, `XkbAllNamesMask`));

    /* check device-independent stuff */
    tmp = cast(CARD32*) &stuff[1];

    if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + 1))
        return BadLength;
    if (stuff.which & XkbKeycodesNameMask) {
        tmp = _XkbCheckAtoms(tmp, 1, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + 1))
        return BadLength;
    if (stuff.which & XkbGeometryNameMask) {
        tmp = _XkbCheckAtoms(tmp, 1, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + 1))
        return BadLength;
    if (stuff.which & XkbSymbolsNameMask) {
        tmp = _XkbCheckAtoms(tmp, 1, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + 1))
        return BadLength;
    if (stuff.which & XkbPhysSymbolsNameMask) {
        tmp = _XkbCheckAtoms(tmp, 1, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + 1))
        return BadLength;
    if (stuff.which & XkbTypesNameMask) {
        tmp = _XkbCheckAtoms(tmp, 1, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }
    if (!_XkbCheckRequestBounds(client, stuff, tmp, tmp + 1))
        return BadLength;
    if (stuff.which & XkbCompatNameMask) {
        tmp = _XkbCheckAtoms(tmp, 1, client.swapped, &bad);
        if (!tmp) {
            client.errorValue = cast(uint)bad;
            return BadAtom;
        }
    }

    /* start of device-dependent tests */
    rc = _XkbSetNamesCheck(client, dev, stuff, tmp);
    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {

                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success) {
                    rc = _XkbSetNamesCheck(client, other, stuff, tmp);
                    if (rc != Success)
                        return rc;
                }
            }
        }
    }

    /* everything is okay -- update names */

    rc = _XkbSetNames(client, dev, stuff);
    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {

                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success)
                    _XkbSetNames(client, other, stuff);
            }
        }
    }

    /* everything is okay -- update names */

    return Success;
}

import xkb.xkbgeom_priv;

enum string	XkbSizeCountedString(string s) = `((` ~ s ~ `)?((((2+strlen(` ~ s ~ `))+3)/4)*4):4)`;

/**
 * Write the zero-terminated string str into wire as a pascal string with a
 * 16-bit length field prefixed before the actual string.
 *
 * @param wire The destination array, usually the wire struct
 * @param str The source string as zero-terminated C string
 * @param swap If TRUE, the length field is swapped.
 *
 * @return The input string in the format <string length><string> with a
 * (swapped) 16 bit string length, non-zero terminated.
 */
private char* XkbWriteCountedString(char* wire, const(char)* str, Bool swap)
{
    CARD16 len = void; CARD16* pLen = void; CARD16 paddedLen = void;

    if (!str)
        return wire;

    len = cast(ushort)strlen(str);
    pLen = cast(CARD16*) wire;
    *pLen = len;
    if (swap) {
        swaps(pLen);
    }
    paddedLen = cast(ushort)(pad_to_int32(((len) + len).sizeof) - len.sizeof);
    strncpy(&wire[len.sizeof], str, paddedLen);
    wire += ((len) + paddedLen).sizeof;
    return wire;
}

private int XkbSizeGeomProperties(XkbGeometryPtr geom)
{
    int i = void, size = void;
    XkbPropertyPtr prop = void;

    for (size = i = 0, prop = geom.properties; i < geom.num_properties;
         i++, prop++) {
        size += mixin(XkbSizeCountedString!(`prop.name`));
        size += mixin(XkbSizeCountedString!(`prop.value`));
    }
    return size;
}

pragma(inline, true) private void XkbWriteGeomProperties(x_rpcbuf_t* rpcbuf, XkbGeometryPtr geom)
{
    int i = void;
    XkbPropertyPtr prop = void;

    for (i = 0, prop = geom.properties; i < geom.num_properties; i++, prop++) {
        x_rpcbuf_write_counted_string_pad(rpcbuf, prop.name);
        x_rpcbuf_write_counted_string_pad(rpcbuf, prop.value);
    }
}

private int XkbSizeGeomKeyAliases(XkbGeometryPtr geom)
{
    return geom.num_key_aliases * (2 * XkbKeyNameLength);
}

pragma(inline, true) private void XkbWriteGeomKeyAliases(x_rpcbuf_t* rpcbuf, XkbGeometryPtr geom)
{
    x_rpcbuf_write_CARD8s(rpcbuf,
                          cast(CARD8*) geom.key_aliases,
                          geom.num_key_aliases * XkbKeyAliasRec.sizeof);
}

private int XkbSizeGeomColors(XkbGeometryPtr geom)
{
    int i = void, size = void;
    XkbColorPtr color = void;

    for (i = size = 0, color = geom.colors; i < geom.num_colors; i++, color++) {
        size += mixin(XkbSizeCountedString!(`color.spec`));
    }
    return size;
}

pragma(inline, true) private void XkbWriteGeomColors(x_rpcbuf_t* rpcbuf, XkbGeometryPtr geom)
{
    int i = void;
    XkbColorPtr color = void;

    for (i = 0, color = geom.colors; i < geom.num_colors; i++, color++) {
        x_rpcbuf_write_counted_string_pad(rpcbuf, color.spec);
    }
}

private int XkbSizeGeomShapes(XkbGeometryPtr geom)
{
    int i = void, size = void;
    XkbShapePtr shape = void;

    for (i = size = 0, shape = geom.shapes; i < geom.num_shapes; i++, shape++) {
        int n = void;
        XkbOutlinePtr ol = void;

        size += xkbShapeWireDesc.sizeof;
        for (n = 0, ol = shape.outlines; n < shape.num_outlines; n++, ol++) {
            size += xkbOutlineWireDesc.sizeof;
            size += ol.num_points * xkbPointWireDesc.sizeof;
        }
    }
    return size;
}

private void XkbWriteGeomShapes(x_rpcbuf_t* rpcbuf, XkbGeometryPtr geom)
{
    int i = void;
    XkbShapePtr shape = void;

    for (i = 0, shape = geom.shapes; i < geom.num_shapes; i++, shape++) {
        int o = void;
        XkbOutlinePtr ol = void;

        /* write xkbShapeWireDesc */
        x_rpcbuf_write_CARD32(rpcbuf, cast(uint)shape.name);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)shape.num_outlines);
        x_rpcbuf_write_CARD8(
            rpcbuf,
            cast(ubyte)(shape.primary ? mixin(XkbOutlineIndex!("shape", "shape.primary")) : XkbNoShape));
        x_rpcbuf_write_CARD8(rpcbuf,
            cast(ubyte)(shape.approx ? mixin(XkbOutlineIndex!("shape", "shape.approx")) : XkbNoShape));
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)0); /* pad1 */

        for (o = 0, ol = shape.outlines; o < shape.num_outlines; o++, ol++) {
            int p = void;
            XkbPointPtr pt = void;

            /* write xkbOutlineWireDesc */
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)ol.num_points);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)ol.corner_radius);
            x_rpcbuf_pad(rpcbuf);

            for (p = 0, pt = ol.points; p < ol.num_points; p++, pt++) {
                /* write xkbPointWireDesc */
                x_rpcbuf_write_INT16(rpcbuf, cast(short)pt.x);
                x_rpcbuf_write_INT16(rpcbuf, cast(short)pt.y);
            }
        }
    }
}

private int XkbSizeGeomDoodads(int num_doodads, XkbDoodadPtr doodad)
{
    int i = void, size = void;

    for (i = size = 0; i < num_doodads; i++, doodad++) {
        size += xkbAnyDoodadWireDesc.sizeof;
        if (doodad.any.type == XkbTextDoodad) {
            size += mixin(XkbSizeCountedString!(`doodad.text.text`));
            size += mixin(XkbSizeCountedString!(`doodad.text.font`));
        }
        else if (doodad.any.type == XkbLogoDoodad) {
            size += mixin(XkbSizeCountedString!(`doodad.logo.logo_name`));
        }
    }
    return size;
}

private void XkbWriteGeomDoodads(x_rpcbuf_t* rpcbuf, int num_doodads, XkbDoodadPtr doodad)
{
    int i = void;

    for (i = 0; i < num_doodads; i++, doodad++) {
        /* write xkbAnyDoodadWireDesc head part */
        x_rpcbuf_write_CARD32(rpcbuf, cast(uint)doodad.any.name);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.any.type);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.any.priority);
        x_rpcbuf_write_INT16(rpcbuf, cast(short)doodad.any.top);
        x_rpcbuf_write_INT16(rpcbuf, cast(short)doodad.any.left);
        x_rpcbuf_write_INT16(rpcbuf, cast(short)doodad.any.angle);

        switch (doodad.any.type) {
        case XkbOutlineDoodad:
        case XkbSolidDoodad:
            /* write xkbShapeDoodadWireDesc head part */
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.shape.color_ndx);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.shape.shape_ndx);
            x_rpcbuf_write_CARD16(rpcbuf, 0); /* pad1 */
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)0); /* pad2 */
            break;
        case XkbTextDoodad:
            /* write xkbTextDoodadWireDesc head part */
            x_rpcbuf_write_CARD16(rpcbuf, doodad.text.width);
            x_rpcbuf_write_CARD16(rpcbuf, doodad.text.height);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.text.color_ndx);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)0); /* pad1 */
            x_rpcbuf_write_CARD16(rpcbuf, 0); /* pad2 */
            x_rpcbuf_write_counted_string_pad(rpcbuf, doodad.text.text);
            x_rpcbuf_write_counted_string_pad(rpcbuf, doodad.text.font);
            break;
        case XkbIndicatorDoodad:
            /* write xkbIndicatorDoodadWireDesc head part */
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.indicator.shape_ndx);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.indicator.on_color_ndx);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.indicator.off_color_ndx);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)0); /* pad1 */
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)0); /* pad2 */
            break;
        case XkbLogoDoodad:
            /* write xkbLogoDoodadWireDesc head part */
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.logo.color_ndx);
            x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)doodad.logo.shape_ndx);
            x_rpcbuf_write_CARD16(rpcbuf, 0); /* pad1 */
            x_rpcbuf_write_CARD32(rpcbuf, cast(uint)0); /* pad2 */
            x_rpcbuf_write_counted_string_pad(rpcbuf, doodad.logo.logo_name);
            break;
        default:
            ErrorF("[xkb] Unknown doodad type %d in XkbWriteGeomDoodads\n",
                   doodad.any.type);
            ErrorF("[xkb] Ignored\n");
            break;
        }
    }
}

private void XkbWriteGeomOverlay(x_rpcbuf_t* rpcbuf, XkbOverlayPtr ol)
{
    int r = void;
    XkbOverlayRowPtr row = void;

    /* write xkbOverlayWireDesc */
    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)ol.name);
    x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)ol.num_rows);
    x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)0); /* pad1 */
    x_rpcbuf_write_CARD16(rpcbuf, 0); /* pad2 */

    for (r = 0, row = ol.rows; r < ol.num_rows; r++, row++) {
        uint k = void;
        XkbOverlayKeyPtr key = void;

        /* write xkbOverlayRowWireDesc */
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)row.row_under);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)row.num_keys);
        x_rpcbuf_write_CARD16(rpcbuf, 0); /* pad1 */

        for (k = 0, key = row.keys; k < row.num_keys; k++, key++) {
            /* write xkbOverlayKeyWireDesc */
            x_rpcbuf_write_CARD8s(rpcbuf, cast(CARD8*)key.over.name, XkbKeyNameLength);
            x_rpcbuf_write_CARD8s(rpcbuf, cast(CARD8*)key.under.name, XkbKeyNameLength);
        }
    }
}

private int XkbSizeGeomSections(XkbGeometryPtr geom)
{
    int i = void, size = void;
    XkbSectionPtr section = void;

    for (i = size = 0, section = geom.sections; i < geom.num_sections;
         i++, section++) {
        size += xkbSectionWireDesc.sizeof;
        if (section.rows) {
            int r = void;
            XkbRowPtr row = void;

            for (r = 0, row = section.rows; r < section.num_rows; row++, r++) {
                size += xkbRowWireDesc.sizeof;
                size += row.num_keys * xkbKeyWireDesc.sizeof;
            }
        }
        if (section.doodads)
            size += XkbSizeGeomDoodads(section.num_doodads, section.doodads);
        if (section.overlays) {
            int o = void;
            XkbOverlayPtr ol = void;

            for (o = 0, ol = section.overlays; o < section.num_overlays;
                 o++, ol++) {
                int r = void;
                XkbOverlayRowPtr row = void;

                size += xkbOverlayWireDesc.sizeof;
                for (r = 0, row = ol.rows; r < ol.num_rows; r++, row++) {
                    size += xkbOverlayRowWireDesc.sizeof;
                    size += row.num_keys * xkbOverlayKeyWireDesc.sizeof;
                }
            }
        }
    }
    return size;
}

private void XkbWriteGeomSections(x_rpcbuf_t* rpcbuf, XkbGeometryPtr geom)
{
    int i = void;
    XkbSectionPtr section = void;

    for (i = 0, section = geom.sections; i < geom.num_sections;
         i++, section++) {

        /* write xkbSectionWireDesc */
        x_rpcbuf_write_CARD32(rpcbuf, cast(uint)section.name);
        x_rpcbuf_write_INT16(rpcbuf, cast(short)section.top);
        x_rpcbuf_write_INT16(rpcbuf, cast(short)section.left);
        x_rpcbuf_write_CARD16(rpcbuf, section.width);
        x_rpcbuf_write_CARD16(rpcbuf, section.height);
        x_rpcbuf_write_INT16(rpcbuf, cast(short)section.angle);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)section.priority);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)section.num_rows);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)section.num_doodads);
        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)section.num_overlays);
        x_rpcbuf_write_CARD16(rpcbuf, 0); /* pad1 */

        if (section.rows) {
            int r = void;
            XkbRowPtr row = void;

            for (r = 0, row = section.rows; r < section.num_rows; r++, row++) {
                /* write xkbRowWireDesc */
                x_rpcbuf_write_INT16(rpcbuf, cast(short)row.top);
                x_rpcbuf_write_INT16(rpcbuf, cast(short)row.left),
                x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)row.num_keys);
                x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)row.vertical);
                x_rpcbuf_write_CARD16(rpcbuf, 0); /* pad1 */

                if (row.keys) {
                    int k = void;
                    XkbKeyPtr key = void;

                    for (k = 0, key = row.keys; k < row.num_keys; k++, key++) {
                        /* xkbKeyWireDesc */
                        x_rpcbuf_write_CARD8s(rpcbuf, cast(CARD8*)key.name.name, XkbKeyNameLength);
                        x_rpcbuf_write_INT16(rpcbuf, cast(short)key.gap);
                        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)key.shape_ndx);
                        x_rpcbuf_write_CARD8(rpcbuf, cast(ubyte)key.color_ndx);
                    }
                }
            }
        }

        if (section.doodads) {
            XkbWriteGeomDoodads(rpcbuf, section.num_doodads, section.doodads);
        }
        if (section.overlays) {
            int o = void;
            for (o = 0; o < section.num_overlays; o++) {
                XkbWriteGeomOverlay(rpcbuf, &section.overlays[o]);
            }
        }
    }
}

private Status XkbComputeGetGeometryReplySize(XkbGeometryPtr geom, xkbGetGeometryReply* rep, Atom name)
{
    int len = void;

    if (geom !is null) {
        len = cast(uint)mixin(XkbSizeCountedString!(`geom.label_font`));
        len += XkbSizeGeomProperties(geom);
        len += XkbSizeGeomColors(geom);
        len += XkbSizeGeomShapes(geom);
        len += XkbSizeGeomSections(geom);
        len += XkbSizeGeomDoodads(geom.num_doodads, geom.doodads);
        len += XkbSizeGeomKeyAliases(geom);
        rep.length= cast(uint)(len / 4);
        rep.found = TRUE;
        rep.name = cast(uint)geom.name;
        rep.widthMM = geom.width_mm;
        rep.heightMM = geom.height_mm;
        rep.nProperties = geom.num_properties;
        rep.nColors = geom.num_colors;
        rep.nShapes = geom.num_shapes;
        rep.nSections = geom.num_sections;
        rep.nDoodads = geom.num_doodads;
        rep.nKeyAliases = geom.num_key_aliases;
        rep.baseColorNdx = cast(ubyte)mixin(XkbGeomColorIndex!("geom", "geom.base_color"));
        rep.labelColorNdx = cast(ubyte)mixin(XkbGeomColorIndex!("geom", "geom.label_color"));
    }
    else {
        rep.length= cast(uint)(0);
        rep.found = FALSE;
        rep.name = cast(uint)name;
        rep.widthMM = rep.heightMM = 0;
        rep.nProperties = rep.nColors = rep.nShapes = 0;
        rep.nSections = rep.nDoodads = 0;
        rep.nKeyAliases = 0;
        rep.labelColorNdx = rep.baseColorNdx = 0;
    }
    return Success;
}

private void XkbAssembleGeometry(ClientPtr client, XkbGeometryPtr geom, xkbGetGeometryReply rep, x_rpcbuf_t* rpcbuf)
{
    if (geom is null)
        return;

    x_rpcbuf_write_counted_string_pad(rpcbuf, geom.label_font);

    if (rep.nProperties > 0) {
        XkbWriteGeomProperties(rpcbuf, geom);
    }
    if (rep.nColors > 0) {
        XkbWriteGeomColors(rpcbuf, geom);
    }
    if (rep.nShapes > 0) {
        XkbWriteGeomShapes(rpcbuf, geom);
    }
    if (rep.nSections > 0) {
        XkbWriteGeomSections(rpcbuf, geom);
    }
    if (rep.nDoodads > 0) {
        XkbWriteGeomDoodads(rpcbuf, geom.num_doodads, geom.doodads);
    }
    if (rep.nKeyAliases > 0) {
        XkbWriteGeomKeyAliases(rpcbuf, geom);
    }
}

int ProcXkbGetGeometry(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetGeometryReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD32!"name");

    DeviceIntPtr dev = void;
    XkbGeometryPtr geom = void;
    Bool shouldFree = void;
    Status status = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));
    mixin(CHK_ATOM_OR_NONE!(`stuff.name`));

    geom = XkbLookupNamedGeometry(dev, stuff.name, &shouldFree);
    x_rpcbuf_t rpcbuf;
    xkbGetGeometryReply reply = {
        deviceID: cast(ubyte)dev.id,
    };
    status = XkbComputeGetGeometryReplySize(geom, &reply, stuff.name);
    if (status != Success)
        goto free_out;

    rpcbuf.swapped = client.swapped;
    rpcbuf.err_clear = TRUE;
    XkbAssembleGeometry(client, geom, reply, &rpcbuf);

    mixin(X_REPLY_FIELD_CARD32!"name");
    mixin(X_REPLY_FIELD_CARD16!"widthMM");
    mixin(X_REPLY_FIELD_CARD16!"heightMM");
    mixin(X_REPLY_FIELD_CARD16!"nProperties");
    mixin(X_REPLY_FIELD_CARD16!"nColors");
    mixin(X_REPLY_FIELD_CARD16!"nShapes");
    mixin(X_REPLY_FIELD_CARD16!"nSections");
    mixin(X_REPLY_FIELD_CARD16!"nDoodads");
    mixin(X_REPLY_FIELD_CARD16!"nKeyAliases");

    status = mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));

free_out:
    if (shouldFree)
        XkbFreeGeometry(geom, XkbGeomAllMask, TRUE);

    return status;
}

private Status _GetCountedString(char** wire_inout, ClientPtr client, char** str)
{
    char* wire = void, next = void;
    CARD16 len = void;

    wire = *wire_inout;

    if (client.req_len <
        bytes_to_int32(wire + 2 - cast(char*) client.requestBuffer))
        return BadValue;

    len = *cast(CARD16*) wire;
    if (client.swapped) {
        swaps(&len);
    }
    next = wire + mixin(XkbPaddedSize!("len + 2"));
    /* Check we're still within the size of the request */
    if (client.req_len <
        bytes_to_int32(next - cast(char*) client.requestBuffer))
        return BadValue;
    *str = cast(char*)calloc(1, len + 1);
    if (!*str)
        return BadAlloc;
    memcpy(*str, &wire[2], len);
    *(*str + len) = '\0';
    *wire_inout = next;
    return Success;
}

private Status _CheckSetDoodad(char** wire_inout, xkbSetGeometryReq* req, XkbGeometryPtr geom, XkbSectionPtr section, ClientPtr client)
{
    char* wire = void;
    xkbDoodadWireDesc* dWire = void;
    xkbAnyDoodadWireDesc any = void;
    xkbTextDoodadWireDesc text = void;
    XkbDoodadPtr doodad = void;
    Status status = void;

    dWire = cast(xkbDoodadWireDesc*) (*wire_inout);
    if (!_XkbCheckRequestBounds(client, req, dWire, dWire + 1))
        return BadLength;

    any = dWire.any;
    wire = cast(char*) &dWire[1];
    if (client.swapped) {
        swapl(&any.name);
        swaps(&any.top);
        swaps(&any.left);
        swaps(&any.angle);
    }
    mixin(CHK_ATOM_ONLY!(`dWire.any.name`));
    doodad = XkbAddGeomDoodad(geom, section, any.name);
    if (!doodad)
        return BadAlloc;
    doodad.any.type = dWire.any.type;
    doodad.any.priority = dWire.any.priority;
    doodad.any.top = any.top;
    doodad.any.left = any.left;
    doodad.any.angle = any.angle;
    switch (doodad.any.type) {
    case XkbOutlineDoodad:
    case XkbSolidDoodad:
        if (dWire.shape.colorNdx >= geom.num_colors) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x40", "geom.num_colors",
                                              "dWire.shape.colorNdx"));
            return BadMatch;
        }
        if (dWire.shape.shapeNdx >= geom.num_shapes) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x41", "geom.num_shapes",
                                              "dWire.shape.shapeNdx"));
            return BadMatch;
        }
        doodad.shape.color_ndx = dWire.shape.colorNdx;
        doodad.shape.shape_ndx = dWire.shape.shapeNdx;
        break;
    case XkbTextDoodad:
        if (dWire.text.colorNdx >= geom.num_colors) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x42", "geom.num_colors",
                                              "dWire.text.colorNdx"));
            return BadMatch;
        }
        text = dWire.text;
        if (client.swapped) {
            swaps(&text.width);
            swaps(&text.height);
        }
        doodad.text.width = text.width;
        doodad.text.height = text.height;
        doodad.text.color_ndx = dWire.text.colorNdx;
        status = _GetCountedString(&wire, client, &doodad.text.text);
        if (status != Success)
            return status;
        status = _GetCountedString(&wire, client, &doodad.text.font);
        if (status != Success) {
            free (doodad.text.text);
            return status;
        }
        break;
    case XkbIndicatorDoodad:
        if (dWire.indicator.onColorNdx >= geom.num_colors) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x43", "geom.num_colors",
                                              "dWire.indicator.onColorNdx"));
            return BadMatch;
        }
        if (dWire.indicator.offColorNdx >= geom.num_colors) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x44", "geom.num_colors",
                                              "dWire.indicator.offColorNdx"));
            return BadMatch;
        }
        if (dWire.indicator.shapeNdx >= geom.num_shapes) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x45", "geom.num_shapes",
                                              "dWire.indicator.shapeNdx"));
            return BadMatch;
        }
        doodad.indicator.shape_ndx = dWire.indicator.shapeNdx;
        doodad.indicator.on_color_ndx = dWire.indicator.onColorNdx;
        doodad.indicator.off_color_ndx = dWire.indicator.offColorNdx;
        break;
    case XkbLogoDoodad:
        if (dWire.logo.colorNdx >= geom.num_colors) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x46", "geom.num_colors",
                                              "dWire.logo.colorNdx"));
            return BadMatch;
        }
        if (dWire.logo.shapeNdx >= geom.num_shapes) {
            client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x47", "geom.num_shapes",
                                              "dWire.logo.shapeNdx"));
            return BadMatch;
        }
        doodad.logo.color_ndx = dWire.logo.colorNdx;
        doodad.logo.shape_ndx = dWire.logo.shapeNdx;
        status = _GetCountedString(&wire, client, &doodad.logo.logo_name);
        if (status != Success)
            return status;
        break;
    default:
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x4F", "dWire.any.type"));
        return BadValue;
    }
    *wire_inout = wire;
    return Success;
}

private Status _CheckSetOverlay(char** wire_inout, xkbSetGeometryReq* req, XkbGeometryPtr geom, XkbSectionPtr section, ClientPtr client)
{
    int r = void;
    char* wire = void;
    XkbOverlayPtr ol = void;
    xkbOverlayWireDesc* olWire = void;
    xkbOverlayRowWireDesc* rWire = void;

    wire = *wire_inout;
    olWire = cast(xkbOverlayWireDesc*) wire;
    if (!_XkbCheckRequestBounds(client, req, olWire, olWire + 1))
        return BadLength;

    if (client.swapped) {
        swapl(&olWire.name);
    }
    mixin(CHK_ATOM_ONLY!(`olWire.name`));
    ol = XkbAddGeomOverlay(section, olWire.name, olWire.nRows);
    rWire = cast(xkbOverlayRowWireDesc*) &olWire[1];
    for (r = 0; r < olWire.nRows; r++) {
        int k = void;
        xkbOverlayKeyWireDesc* kWire = void;
        XkbOverlayRowPtr row = void;

        if (!_XkbCheckRequestBounds(client, req, rWire, rWire + 1))
            return BadLength;

        if (rWire.rowUnder > section.num_rows) {
            client.errorValue = cast(uint)mixin(_XkbErrCode4!("0x20", "r", "section.num_rows", "rWire.rowUnder"));
            return BadMatch;
        }
        row = XkbAddGeomOverlayRow(ol, rWire.rowUnder, rWire.nKeys);
        kWire = cast(xkbOverlayKeyWireDesc*) &rWire[1];
        for (k = 0; k < rWire.nKeys; k++, kWire++) {
            if (!_XkbCheckRequestBounds(client, req, kWire, kWire + 1))
                return BadLength;

            if (XkbAddGeomOverlayKey(ol, row,
                                     cast(char*) kWire.over,
                                     cast(char*) kWire.under) is null) {
                client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x21", "r", "k"));
                return BadMatch;
            }
        }
        rWire = cast(xkbOverlayRowWireDesc*) kWire;
    }
    olWire = cast(xkbOverlayWireDesc*) rWire;
    wire = cast(char*) olWire;
    *wire_inout = wire;
    return Success;
}

private Status _CheckSetSections(XkbGeometryPtr geom, xkbSetGeometryReq* req, char** wire_inout, ClientPtr client)
{
    Status status = void;
    int s = void;
    char* wire = void;
    xkbSectionWireDesc* sWire = void;
    XkbSectionPtr section = void;

    wire = *wire_inout;
    if (req.nSections < 1)
        return Success;
    sWire = cast(xkbSectionWireDesc*) wire;
    for (s = 0; s < req.nSections; s++) {
        int r = void;
        xkbRowWireDesc* rWire = void;

        if (!_XkbCheckRequestBounds(client, req, sWire, sWire + 1))
            return BadLength;

        if (client.swapped) {
            swapl(&sWire.name);
            swaps(&sWire.top);
            swaps(&sWire.left);
            swaps(&sWire.width);
            swaps(&sWire.height);
            swaps(&sWire.angle);
        }
        mixin(CHK_ATOM_ONLY!(`sWire.name`));
        section = XkbAddGeomSection(geom, sWire.name, sWire.nRows,
                                    sWire.nDoodads, sWire.nOverlays);
        if (!section)
            return BadAlloc;
        section.priority = sWire.priority;
        section.top = sWire.top;
        section.left = sWire.left;
        section.width = sWire.width;
        section.height = sWire.height;
        section.angle = sWire.angle;
        rWire = cast(xkbRowWireDesc*) &sWire[1];
        for (r = 0; r < sWire.nRows; r++) {
            int k = void;
            XkbRowPtr row = void;
            xkbKeyWireDesc* kWire = void;

            if (!_XkbCheckRequestBounds(client, req, rWire, rWire + 1))
                return BadLength;

            if (client.swapped) {
                swaps(&rWire.top);
                swaps(&rWire.left);
            }
            row = XkbAddGeomRow(section, rWire.nKeys);
            if (!row)
                return BadAlloc;
            row.top = rWire.top;
            row.left = rWire.left;
            row.vertical = rWire.vertical;
            kWire = cast(xkbKeyWireDesc*) &rWire[1];
            for (k = 0; k < rWire.nKeys; k++, kWire++) {
                XkbKeyPtr key = void;

                if (!_XkbCheckRequestBounds(client, req, kWire, kWire + 1))
                    return BadLength;

                key = XkbAddGeomKey(row);
                if (!key)
                    return BadAlloc;
                memcpy(key.name.name.ptr, kWire.name.ptr, XkbKeyNameLength);
                key.gap = kWire.gap;
                key.shape_ndx = kWire.shapeNdx;
                key.color_ndx = kWire.colorNdx;
                if (key.shape_ndx >= geom.num_shapes) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x10", "key.shape_ndx",
                                                      "geom.num_shapes"));
                    return BadMatch;
                }
                if (key.color_ndx >= geom.num_colors) {
                    client.errorValue = cast(uint)mixin(_XkbErrCode3!("0X11", "key.color_ndx",
                                                      "geom.num_colors"));
                    return BadMatch;
                }
            }
            rWire = cast(xkbRowWireDesc*)kWire;
        }
        wire = cast(char*) rWire;
        if (sWire.nDoodads > 0) {
            int d = void;

            for (d = 0; d < sWire.nDoodads; d++) {
                status = _CheckSetDoodad(&wire, req, geom, section, client);
                if (status != Success)
                    return status;
            }
        }
        if (sWire.nOverlays > 0) {
            int o = void;

            for (o = 0; o < sWire.nOverlays; o++) {
                status = _CheckSetOverlay(&wire, req, geom, section, client);
                if (status != Success)
                    return status;
            }
        }
        sWire = cast(xkbSectionWireDesc*) wire;
    }
    wire = cast(char*) sWire;
    *wire_inout = wire;
    return Success;
}

private Status _CheckSetShapes(XkbGeometryPtr geom, xkbSetGeometryReq* req, char** wire_inout, ClientPtr client)
{
    int i = void;
    char* wire = void;

    wire = *wire_inout;
    if (req.nShapes < 1) {
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("0x06", "req.nShapes"));
        return BadValue;
    }
    else {
        xkbShapeWireDesc* shapeWire = void;
        XkbShapePtr shape = void;
        int o = void;

        shapeWire = cast(xkbShapeWireDesc*) wire;
        for (i = 0; i < req.nShapes; i++) {
            xkbOutlineWireDesc* olWire = void;
            XkbOutlinePtr ol = void;

            if (!_XkbCheckRequestBounds(client, req, shapeWire, shapeWire + 1))
                return BadLength;

            shape =
                XkbAddGeomShape(geom, shapeWire.name, shapeWire.nOutlines);
            if (!shape)
                return BadAlloc;
            olWire = cast(xkbOutlineWireDesc*) (&shapeWire[1]);
            for (o = 0; o < shapeWire.nOutlines; o++) {
                int p = void;
                XkbPointPtr pt = void;
                xkbPointWireDesc* ptWire = void;

                if (!_XkbCheckRequestBounds(client, req, olWire, olWire + 1))
                    return BadLength;

                ol = XkbAddGeomOutline(shape, olWire.nPoints);
                if (!ol)
                    return BadAlloc;
                ol.corner_radius = olWire.cornerRadius;
                ptWire = cast(xkbPointWireDesc*) &olWire[1];
                for (p = 0, pt = ol.points; p < olWire.nPoints; p++, pt++, ptWire++) {
                    if (!_XkbCheckRequestBounds(client, req, ptWire, ptWire + 1))
                        return BadLength;

                    pt.x = ptWire.x;
                    pt.y = ptWire.y;
                    if (client.swapped) {
                        swaps(&pt.x);
                        swaps(&pt.y);
                    }
                }
                ol.num_points = olWire.nPoints;
                olWire = cast(xkbOutlineWireDesc*)ptWire;
            }
            if (shapeWire.primaryNdx != XkbNoShape)
                shape.primary = &shape.outlines[shapeWire.primaryNdx];
            if (shapeWire.approxNdx != XkbNoShape)
                shape.approx = &shape.outlines[shapeWire.approxNdx];
            shapeWire = cast(xkbShapeWireDesc*) olWire;
        }
        wire = cast(char*) shapeWire;
    }
    if (geom.num_shapes != req.nShapes) {
        client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x07", "geom.num_shapes", "req.nShapes"));
        return BadMatch;
    }

    *wire_inout = wire;
    return Success;
}

private Status _CheckSetGeom(XkbGeometryPtr geom, xkbSetGeometryReq* req, ClientPtr client)
{
    int i = void;
    Status status = void;
    char* wire = void;

    wire = cast(char*) &req[1];
    status = _GetCountedString(&wire, client, &geom.label_font);
    if (status != Success)
        return status;

    for (i = 0; i < req.nProperties; i++) {
        char* name = void, val = void;

        status = _GetCountedString(&wire, client, &name);
        if (status != Success)
            return status;
        status = _GetCountedString(&wire, client, &val);
        if (status != Success) {
            free(name);
            return status;
        }
        if (XkbAddGeomProperty(geom, name, val) is null) {
            free(name);
            free(val);
            return BadAlloc;
        }
        free(name);
        free(val);
    }

    if (req.nColors < 2) {
        client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x01", "2", "req.nColors"));
        return BadValue;
    }
    if (req.baseColorNdx > req.nColors) {
        client.errorValue =
            mixin(_XkbErrCode3!(`0x03`, `req.nColors`, `req.baseColorNdx`));
        return BadMatch;
    }
    if (req.labelColorNdx > req.nColors) {
        client.errorValue =
            mixin(_XkbErrCode3!(`0x03`, `req.nColors`, `req.labelColorNdx`));
        return BadMatch;
    }
    if (req.labelColorNdx == req.baseColorNdx) {
        client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x04", "req.baseColorNdx",
                                          "req.labelColorNdx"));
        return BadMatch;
    }

    for (i = 0; i < req.nColors; i++) {
        char* name = void;

        status = _GetCountedString(&wire, client, &name);
        if (status != Success)
            return status;
        if (!XkbAddGeomColor(geom, name, geom.num_colors)) {
            free(name);
            return BadAlloc;
        }
        free(name);
    }
    if (req.nColors != geom.num_colors) {
        client.errorValue = cast(uint)mixin(_XkbErrCode3!("0x05", "req.nColors", "geom.num_colors"));
        return BadMatch;
    }
    geom.label_color = &geom.colors[req.labelColorNdx];
    geom.base_color = &geom.colors[req.baseColorNdx];

    if ((status = _CheckSetShapes(geom, req, &wire, client)) != Success)
        return status;

    if ((status = _CheckSetSections(geom, req, &wire, client)) != Success)
        return status;

    for (i = 0; i < req.nDoodads; i++) {
        status = _CheckSetDoodad(&wire, req, geom, null, client);
        if (status != Success)
            return status;
    }

    for (i = 0; i < req.nKeyAliases; i++) {
        if (!_XkbCheckRequestBounds(client, req, wire, wire + 2 * XkbKeyNameLength))
                return BadLength;

        if (XkbAddGeomKeyAlias(geom, &wire[XkbKeyNameLength], wire) is null)
            return BadAlloc;
        wire += 2 * XkbKeyNameLength;
    }
    return Success;
}

private int _XkbSetGeometry(ClientPtr client, DeviceIntPtr dev, xkbSetGeometryReq* stuff)
{
    XkbDescPtr xkb = void;
    Bool new_name = void;
    XkbGeometryPtr geom = void, old = void;
    Status status = void;

    xkb = dev.key.xkbInfo.desc;
    old = xkb.geom;
    xkb.geom = null;

    XkbGeometrySizesRec sizes = {
        which: XkbGeomAllMask,
        num_properties: stuff.nProperties,
        num_colors: stuff.nColors,
        num_shapes: stuff.nShapes,
        num_sections: stuff.nSections,
        num_doodads: stuff.nDoodads,
        num_key_aliases: stuff.nKeyAliases,
    };

    if ((status = XkbAllocGeometry(xkb, &sizes)) != Success) {
        xkb.geom = old;
        return status;
    }
    geom = xkb.geom;
    geom.name = stuff.name;
    geom.width_mm = stuff.widthMM;
    geom.height_mm = stuff.heightMM;
    if ((status = _CheckSetGeom(geom, stuff, client)) != Success) {
        XkbFreeGeometry(geom, XkbGeomAllMask, TRUE);
        xkb.geom = old;
        return status;
    }
    new_name = (xkb.names.geometry != geom.name);
    xkb.names.geometry = geom.name;
    if (old)
        XkbFreeGeometry(old, XkbGeomAllMask, TRUE);
    if (new_name) {
        xkbNamesNotify nn = {
            changed: cast(ushort)XkbGeometryNameMask,
        };
        XkbSendNamesNotify(dev, &nn);
    }

    xkbNewKeyboardNotify nkn = {
        deviceID: cast(ubyte)dev.id,
        minKeyCode: cast(ubyte)xkb.min_key_code,
        maxKeyCode: cast(ubyte)xkb.max_key_code,
        requestMajor: cast(ubyte)XkbReqCode,
        requestMinor: X_kbSetGeometry,
        changed: cast(ushort)XkbNKN_GeometryMask,
    };
    nkn.oldDeviceID = cast(ubyte)dev.id;
    nkn.oldMinKeyCode = cast(ubyte)xkb.min_key_code;
    nkn.oldMaxKeyCode = cast(ubyte)xkb.max_key_code;

    XkbSendNewKeyboardNotify(dev, &nkn);
    return Success;
}

int ProcXkbSetGeometry(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSetGeometryReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD32!"name");
    mixin(X_REQUEST_FIELD_CARD16!"widthMM");
    mixin(X_REQUEST_FIELD_CARD16!"heightMM");
    mixin(X_REQUEST_FIELD_CARD16!"nProperties");
    mixin(X_REQUEST_FIELD_CARD16!"nColors");
    mixin(X_REQUEST_FIELD_CARD16!"nDoodads");
    mixin(X_REQUEST_FIELD_CARD16!"nKeyAliases");

    DeviceIntPtr dev = void;
    int rc = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixManageAccess`));
    mixin(CHK_ATOM_OR_NONE!(`stuff.name`));

    rc = _XkbSetGeometry(client, dev, stuff);
    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if ((other != dev) && other.key && !InputDevIsMaster(other) &&
                GetMaster(other, MASTER_KEYBOARD) == dev) {
                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success)
                    _XkbSetGeometry(client, other, stuff);
            }
        }
    }

    return Success;
}

int ProcXkbPerClientFlags(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbPerClientFlagsReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD32!"change");
    mixin(X_REQUEST_FIELD_CARD32!"value");
    mixin(X_REQUEST_FIELD_CARD32!"ctrlsToChange");
    mixin(X_REQUEST_FIELD_CARD32!"autoCtrls");
    mixin(X_REQUEST_FIELD_CARD32!"autoCtrlValues");

    DeviceIntPtr dev = void;
    XkbInterestPtr interest = void;
    Mask access_mode = DixGetAttrAccess | DixSetAttrAccess;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `access_mode`));
    mixin(CHK_MASK_LEGAL!(`0x01`, `stuff.change`, `XkbPCF_AllFlagsMask`));
    mixin(CHK_MASK_MATCH!(`0x02`, `stuff.change`, `stuff.value`));

    interest = XkbFindClientResource(cast(DevicePtr) dev, client);
    if (stuff.change) {
        client.xkbClientFlags &= ~stuff.change;
        client.xkbClientFlags |= stuff.value;
    }
    if (stuff.change & XkbPCF_AutoResetControlsMask) {
        Bool want = void;

        want = cast(int)(stuff.value & XkbPCF_AutoResetControlsMask);
        if (interest && !want) {
            interest.autoCtrls = interest.autoCtrlValues = 0;
        }
        else if (want && (!interest)) {
            XID id = FakeClientID(client.index);

            if (!AddResource(cast(uint)id, RT_XKBCLIENT, dev))
                return BadAlloc;
            interest = XkbAddClientResource(cast(DevicePtr) dev, client, id);
            if (!interest)
                return BadAlloc;
        }
        if (interest && want) {
            uint affect = void;

            affect = cast(uint)stuff.ctrlsToChange;

            mixin(CHK_MASK_LEGAL!(`0x03`, `affect`, `XkbAllBooleanCtrlsMask`));
            mixin(CHK_MASK_MATCH!(`0x04`, `affect`, `stuff.autoCtrls`));
            mixin(CHK_MASK_MATCH!(`0x05`, `stuff.autoCtrls`, `stuff.autoCtrlValues`));

            interest.autoCtrls &= ~affect;
            interest.autoCtrlValues &= ~affect;
            interest.autoCtrls |= stuff.autoCtrls & affect;
            interest.autoCtrlValues |= stuff.autoCtrlValues & affect;
        }
    }

    xkbPerClientFlagsReply reply = {
        supported: cast(ubyte)XkbPCF_AllFlagsMask,
        value: client.xkbClientFlags & XkbPCF_AllFlagsMask,
        autoCtrls: interest ? interest.autoCtrls : 0,
        autoCtrlValues:  interest ? interest.autoCtrlValues : 0,
    };

    mixin(X_REPLY_FIELD_CARD32!"supported");
    mixin(X_REPLY_FIELD_CARD32!"value");
    mixin(X_REPLY_FIELD_CARD32!"autoCtrls");
    mixin(X_REPLY_FIELD_CARD32!"autoCtrlValues");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

/* all latin-1 alphanumerics, plus parens, minus, underscore, slash */
/* and wildcards */
private const(uint)[32] componentSpecLegal = [
    0x00, 0x00, 0x00, 0x00, 0x00, 0xa7, 0xff, 0x87,
    0xfe, 0xff, 0xff, 0x87, 0xfe, 0xff, 0xff, 0x07,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xff
];

/* same as above but accepts percent, plus and bar too */
private const(uint)[32] componentExprLegal = [
    0x00, 0x00, 0x00, 0x00, 0x20, 0xaf, 0xff, 0x87,
    0xfe, 0xff, 0xff, 0x87, 0xfe, 0xff, 0xff, 0x17,
    0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00,
    0xff, 0xff, 0x7f, 0xff, 0xff, 0xff, 0x7f, 0xff
];

private char* GetComponentSpec(ClientPtr client, xkbGetKbdByNameReq* stuff, ubyte** pWire, Bool allowExpr, int* errRtrn)
{
    int len = void;
    int i = void;
    ubyte* wire = void, str = void, tmp = void;
    const(ubyte)* legal = void;

    if (allowExpr)
        legal = cast(ubyte*)&componentExprLegal[0];
    else
        legal = cast(ubyte*)&componentSpecLegal[0];

    wire = *pWire;
    if (!_XkbCheckRequestBounds(client, stuff, wire, wire + 1)) {
        *errRtrn = BadLength;
        return null;
    }
    len = (*cast(ubyte*) wire++);
    if (len > 0) {
        if (!_XkbCheckRequestBounds(client, stuff, wire, wire + len)) {
            *errRtrn = BadLength;
            return null;
        }
        str = cast(ubyte*) calloc(1, len + 1);
        if (str) {
            tmp = str;
            for (i = 0; i < len; i++) {
                if (legal[(*wire) / 8] & (1 << ((*wire) % 8)))
                    *tmp++ = *wire++;
                else
                    wire++;
            }
            if (tmp != str)
                *tmp++ = '\0';
            else {
                free(str);
                str = null;
            }
        }
        else {
            *errRtrn = BadAlloc;
        }
    }
    else {
        str = null;
    }
    *pWire = wire;
    return cast(char*) str;
}

int ProcXkbListComponents(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbListComponentsReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"maxNames");

    DeviceIntPtr dev = void;
    uint len = void;
    ubyte* str = void;
    ubyte size = void;
    int i = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));

    /* The request is followed by six Pascal strings (i.e. size in characters
     * followed by a string pattern) describing what the client wants us to
     * list.  We don't care, but might as well check they haven't got the
     * length wrong. */
    str = cast(ubyte*) &stuff[1];
    for (i = 0; i < 6; i++) {
        if (!_XkbCheckRequestBounds(client, stuff, str, str + 1))
            return BadLength;
        size = *(cast(ubyte*)str);
        len = cast(uint)((str + size + 1) - (cast(ubyte*) stuff));
        if ((mixin(XkbPaddedSize!("len")) / 4) > client.req_len)
            return BadLength;
        str += (size + 1);
    }
    if ((mixin(XkbPaddedSize!("len")) / 4) != client.req_len)
        return BadLength;

    xkbListComponentsReply reply = {
        deviceID: cast(ubyte)dev.id,
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private uint XkbConvertGetByNameComponents(Bool toXkm, uint orig)
{
    uint rtrn = void;

    rtrn = 0;
    if (toXkm) {
        if (orig & XkbGBN_TypesMask)
            rtrn |= XkmTypesMask;
        if (orig & XkbGBN_CompatMapMask)
            rtrn |= XkmCompatMapMask;
        if (orig & XkbGBN_SymbolsMask)
            rtrn |= XkmSymbolsMask;
        if (orig & XkbGBN_IndicatorMapMask)
            rtrn |= XkmIndicatorsMask;
        if (orig & XkbGBN_KeyNamesMask)
            rtrn |= XkmKeyNamesMask;
        if (orig & XkbGBN_GeometryMask)
            rtrn |= XkmGeometryMask;
    }
    else {
        if (orig & XkmTypesMask)
            rtrn |= XkbGBN_TypesMask;
        if (orig & XkmCompatMapMask)
            rtrn |= XkbGBN_CompatMapMask;
        if (orig & XkmSymbolsMask)
            rtrn |= XkbGBN_SymbolsMask;
        if (orig & XkmIndicatorsMask)
            rtrn |= XkbGBN_IndicatorMapMask;
        if (orig & XkmKeyNamesMask)
            rtrn |= XkbGBN_KeyNamesMask;
        if (orig & XkmGeometryMask)
            rtrn |= XkbGBN_GeometryMask;
        if (orig != 0)
            rtrn |= XkbGBN_OtherNamesMask;
    }
    return rtrn;
}

int ProcXkbGetKbdByName(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbGetKbdByNameReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"want");
    mixin(X_REQUEST_FIELD_CARD16!"need");

    DeviceIntPtr dev = void;
    DeviceIntPtr tmpd = void;
    DeviceIntPtr master = void;
    XkbDescPtr xkb = void, new_ = void;
    XkbEventCauseRec cause = { 0 };
    ubyte* str = void;
    char[PATH_MAX] mapFile = 0;
    uint len = void;
    uint fwant = void, fneed = void;
    int status = void;
    Bool geom_changed = void;
    XkbSrvLedInfoPtr old_sli = void;
    XkbSrvLedInfoPtr sli = void;
    Mask access_mode = DixGetAttrAccess | DixManageAccess;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_MASK_LEGAL!(`0x01`, `stuff.want`, `XkbGBN_AllComponentsMask`));
    mixin(CHK_MASK_LEGAL!(`0x02`, `stuff.need`, `XkbGBN_AllComponentsMask`));

    mixin(CHK_KBD_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `access_mode`));
    master = GetMaster(dev, MASTER_KEYBOARD);

    xkb = dev.key.xkbInfo.desc;
    status = Success;
    str = cast(ubyte*) &stuff[1];
    {
        char* keymap = GetComponentSpec(client, stuff, &str, TRUE, &status);  /* keymap, unsupported */
        if (keymap) {
            free(keymap);
            return BadMatch;
        }
    }

    XkbComponentNamesRec names = {
        keycodes: GetComponentSpec(client, stuff, &str, TRUE, &status),
        types: GetComponentSpec(client, stuff, &str, TRUE, &status),
        compat: GetComponentSpec(client, stuff, &str, TRUE, &status),
        symbols: GetComponentSpec(client, stuff, &str, TRUE, &status),
        geometry: GetComponentSpec(client, stuff, &str, TRUE, &status),
    };

    if (status == Success) {
        len = cast(uint)(str - (cast(ubyte*) stuff));
        if ((mixin(XkbPaddedSize!("len")) / 4) != client.req_len)
            status = BadLength;
    }

    if (status != Success) {
        free(names.keycodes);
        free(names.types);
        free(names.compat);
        free(names.symbols);
        free(names.geometry);
        return status;
    }

    if (stuff.load)
        fwant = XkbGBN_AllComponentsMask;
    else
        fwant = stuff.want | stuff.need;
    if ((!names.compat) &&
        (fwant & (XkbGBN_CompatMapMask | XkbGBN_IndicatorMapMask))) {
        names.compat = cast(char*)Xstrdup("%");
    }
    if ((!names.types) && (fwant & (XkbGBN_TypesMask))) {
        names.types = cast(char*)Xstrdup("%");
    }
    if ((!names.symbols) && (fwant & XkbGBN_SymbolsMask)) {
        names.symbols = cast(char*)Xstrdup("%");
    }
    geom_changed = ((names.geometry !is null) &&
                    (strcmp(names.geometry, "%") != 0));
    if ((!names.geometry) && (fwant & XkbGBN_GeometryMask)) {
        names.geometry = cast(char*)Xstrdup("%");
        geom_changed = FALSE;
    }

    fwant =
        XkbConvertGetByNameComponents(TRUE, stuff.want) | XkmVirtualModsMask;
    fneed = XkbConvertGetByNameComponents(TRUE, stuff.need);

    if (stuff.load) {
        fneed |= XkmKeymapRequired;
        fwant |= XkmKeymapLegal;
    }
    if ((fwant | fneed) & XkmSymbolsMask) {
        fneed |= XkmKeyNamesIndex | XkmTypesIndex;
        fwant |= XkmIndicatorsIndex;
    }

    /* We pass dev in here so we can get the old names out if needed. */
    uint found = XkbDDXLoadKeymapByNames(dev, &names, fwant, fneed, &new_,
                                         mapFile.ptr, PATH_MAX);
    uint reported = XkbConvertGetByNameComponents(FALSE, fwant | fneed);
    if (new_ is null)
        reported = 0;

    Bool loaded = 0;

    stuff.want |= stuff.need;

    xkbGetMapReply mrep = { type: X_Reply, sequenceNumber: cast(ushort)client.sequence };
    xkbGetCompatMapReply crep = { type: X_Reply, sequenceNumber: cast(ushort)client.sequence };
    xkbGetIndicatorMapReply irep = { type: X_Reply, sequenceNumber: cast(ushort)client.sequence };
    xkbGetNamesReply nrep = { type: X_Reply, sequenceNumber: cast(ushort)client.sequence };
    xkbGetGeometryReply grep = { type: X_Reply, sequenceNumber: cast(ushort)client.sequence };

    if (new_) {
        if (stuff.load)
            loaded = TRUE;
        if (stuff.load ||
            ((reported & XkbGBN_SymbolsMask) && (new_.compat))) {
            XkbChangesRec changes = { 0 };
            XkbUpdateDescActions(new_,
                                 new_.min_key_code,cast(ubyte) mixin(XkbNumKeys!("new_")), &changes);
        }

        if (new_.map is null)
            reported &= ~(XkbGBN_SymbolsMask | XkbGBN_TypesMask);
        else if (reported & (XkbGBN_SymbolsMask | XkbGBN_TypesMask)) {
            mrep.deviceID = cast(ubyte)dev.id;
            mrep.length= cast(uint)(mixin(X_REPLY_HEADER_UNITS!("xkbGetMapReply")));
            mrep.minKeyCode = new_.min_key_code;
            mrep.maxKeyCode = new_.max_key_code;
            mrep.totalSyms = mrep.totalActs =
                mrep.totalKeyBehaviors = mrep.totalKeyExplicit =
                mrep.totalModMapKeys = mrep.totalVModMapKeys = cast(ubyte)0;
            if (reported & (XkbGBN_TypesMask | XkbGBN_ClientSymbolsMask)) {
                mrep.present |= XkbKeyTypesMask;
                mrep.nTypes = mrep.totalTypes = new_.map.num_types;
            }
            if (reported & XkbGBN_ClientSymbolsMask) {
                mrep.present |= (XkbKeySymsMask | XkbModifierMapMask);
                mrep.firstKeySym = mrep.firstModMapKey = new_.min_key_code;
                mrep.nKeySyms = mrep.nModMapKeys = cast(ubyte)mixin(XkbNumKeys!("new_"));
            }
            if (reported & XkbGBN_ServerSymbolsMask) {
                mrep.present |= XkbAllServerInfoMask;
                mrep.virtualMods = cast(ushort)~0;
                mrep.firstKeyAct = mrep.firstKeyBehavior =
                    mrep.firstKeyExplicit = new_.min_key_code;
                mrep.nKeyActs = mrep.nKeyBehaviors =
                    mrep.nKeyExplicit = cast(ubyte)mixin(XkbNumKeys!("new_"));
                mrep.firstVModMapKey = new_.min_key_code;
                mrep.nVModMapKeys = cast(ubyte)mixin(XkbNumKeys!("new_"));
            }
            XkbComputeGetMapReplySize(new_, &mrep);
        }
        if (new_.compat is null)
            reported &= ~XkbGBN_CompatMapMask;
        else if (reported & XkbGBN_CompatMapMask) {
            crep.deviceID = cast(ubyte)dev.id;
            crep.groups = cast(ubyte)XkbAllGroupsMask;
            crep.nSI = crep.nTotalSI = new_.compat.num_si;
            XkbComputeGetCompatMapReplySize(new_.compat, &crep);
        }
        if (new_.indicators is null)
            reported &= ~XkbGBN_IndicatorMapMask;
        else if (reported & XkbGBN_IndicatorMapMask) {
            irep.deviceID = cast(ubyte)dev.id;
            irep.which = XkbAllIndicatorsMask;
            XkbComputeGetIndicatorMapReplySize(new_.indicators, &irep);
        }
        if (new_.names is null)
            reported &= ~(XkbGBN_OtherNamesMask | XkbGBN_KeyNamesMask);
        else if (reported & (XkbGBN_OtherNamesMask | XkbGBN_KeyNamesMask)) {
            nrep.deviceID = cast(ubyte)dev.id;
            nrep.minKeyCode = new_.min_key_code;
            nrep.maxKeyCode = new_.max_key_code;
            if (reported & XkbGBN_OtherNamesMask) {
                nrep.which = XkbAllNamesMask;
                if (new_.map !is null)
                    nrep.nTypes = new_.map.num_types;
                nrep.groupNames = cast(ubyte)XkbAllGroupsMask;
                nrep.virtualMods = XkbAllVirtualModsMask;
                nrep.indicators = XkbAllIndicatorsMask;
                nrep.nRadioGroups = cast(ubyte)new_.names.num_rg;
            }
            if (reported & XkbGBN_KeyNamesMask) {
                nrep.which |= XkbKeyNamesMask;
                nrep.firstKey = new_.min_key_code;
                nrep.nKeys = cast(ubyte)mixin(XkbNumKeys!("new_"));
                nrep.nKeyAliases = new_.names.num_key_aliases;
                if (nrep.nKeyAliases)
                    nrep.which |= XkbKeyAliasesMask;
            }
            else {
                nrep.which &= ~(XkbKeyNamesMask | XkbKeyAliasesMask);
            }
            XkbComputeGetNamesReplySize(new_, &nrep);
        }
        if (new_.geom is null)
            reported &= ~XkbGBN_GeometryMask;
        else if (reported & XkbGBN_GeometryMask) {
            grep.deviceID = cast(ubyte)dev.id;
            grep.found = TRUE;
            XkbComputeGetGeometryReplySize(new_.geom, &grep, None);
        }
    }

    xkbGetKbdByNameReply reply = {
        deviceID: cast(ubyte)dev.id,
        minKeyCode: xkb.min_key_code,
        maxKeyCode: xkb.max_key_code,
        reported: cast(ushort)reported,
        found: cast(ushort)found,
        loaded: cast(ubyte)loaded,
    };

    if (client.swapped) {
        swaps(&reply.found);
        swaps(&reply.reported);
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (reported & (XkbGBN_SymbolsMask | XkbGBN_TypesMask)) {
        x_rpcbuf_t childbuf = { swapped: client.swapped, err_clear: TRUE };

        XkbAssembleMap(client, new_, mrep, &childbuf);

        if (childbuf.error)
            return BadAlloc;

        if (childbuf.wpos != (mrep.length * 4))
            LogMessage(X_WARNING, "ProcXkbGetKbdByName() childbuf size (%ld) mismatch mrep size (%ld // %ld units)\n",
                       cast(c_ulong)childbuf.wpos, cast(c_ulong)mrep.length * 4, cast(c_ulong)mrep.length);

        if (client.swapped) {
            swaps(&mrep.sequenceNumber);
            swapl(&mrep.length);
            swaps(&mrep.present);
            swaps(&mrep.totalSyms);
            swaps(&mrep.totalActs);
        }

        x_rpcbuf_write_binary_pad(&rpcbuf, &mrep, mrep.sizeof);
        x_rpcbuf_write_rpcbuf_pad(&rpcbuf, &childbuf);
    }

    if (reported & XkbGBN_CompatMapMask) {
        x_rpcbuf_t childbuf = { swapped: client.swapped, err_clear: TRUE };

        XkbAssembleCompatMap(client, new_.compat, crep, &childbuf);

        if (childbuf.wpos != (crep.length * 4))
            LogMessage(X_WARNING, "ProcXkbGetKbdByName() childbuf size (%ld) mismatch crep size (%ld // %ld units)\n",
                       cast(c_ulong)childbuf.wpos, cast(c_ulong)crep.length * 4, cast(c_ulong)crep.length);

        if (client.swapped) {
            swaps(&crep.sequenceNumber);
            swapl(&crep.length);
            swaps(&crep.firstSI);
            swaps(&crep.nSI);
            swaps(&crep.nTotalSI);
        }

        x_rpcbuf_write_binary_pad(&rpcbuf, &crep, crep.sizeof);
        x_rpcbuf_write_rpcbuf_pad(&rpcbuf, &childbuf);
    }

    if (reported & XkbGBN_IndicatorMapMask) {
        x_rpcbuf_t childbuf = { swapped: client.swapped, err_clear: TRUE };

        XkbAssembleIndicatorMap(client, new_.indicators, irep, &childbuf);

        if (childbuf.error)
            return BadAlloc;

        if (childbuf.wpos != (irep.length * 4))
            LogMessage(X_WARNING, "ProcXkbGetKbdByName() childbuf size (%ld) mismatch irep size (%ld // %ld units)\n",
                       cast(c_ulong)childbuf.wpos, cast(c_ulong)irep.length * 4, cast(c_ulong)irep.length);

        if (client.swapped) {
            swaps(&irep.sequenceNumber);
            swapl(&irep.length);
            swapl(&irep.which);
            swapl(&irep.realIndicators);
        }

        x_rpcbuf_write_binary_pad(&rpcbuf, &irep, irep.sizeof);
        x_rpcbuf_write_rpcbuf_pad(&rpcbuf, &childbuf);
    }

    if (reported & (XkbGBN_KeyNamesMask | XkbGBN_OtherNamesMask)) {
        x_rpcbuf_t childbuf = { swapped: client.swapped, err_clear: TRUE };

        XkbAssembleNames(client, new_, nrep, &childbuf);

        if (childbuf.wpos != (nrep.length * 4))
            LogMessage(X_WARNING, "ProcXkbGetKbdByName() childbuf size (%ld) mismatch nrep size (%ld // %ld units)\n",
                       cast(c_ulong)childbuf.wpos, cast(c_ulong)nrep.length * 4, cast(c_ulong)nrep.length);

        if (client.swapped) {
            swaps(&nrep.sequenceNumber);
            swapl(&nrep.length);
            swapl(&nrep.which);
            swaps(&nrep.virtualMods);
            swapl(&nrep.indicators);
        }

        x_rpcbuf_write_binary_pad(&rpcbuf, &nrep, nrep.sizeof);
        x_rpcbuf_write_rpcbuf_pad(&rpcbuf, &childbuf);
    }

    if (reported & XkbGBN_GeometryMask) {
        x_rpcbuf_t childbuf = { swapped: client.swapped, err_clear: TRUE };

        XkbAssembleGeometry(client, new_.geom, grep, &childbuf);

        if (client.swapped) {
            swaps(&grep.sequenceNumber);
            swapl(&grep.length);
            swapl(&grep.name);
            swaps(&grep.widthMM);
            swaps(&grep.heightMM);
            swaps(&grep.nProperties);
            swaps(&grep.nColors);
            swaps(&grep.nShapes);
            swaps(&grep.nSections);
            swaps(&grep.nDoodads);
            swaps(&grep.nKeyAliases);
        }

        x_rpcbuf_write_binary_pad(&rpcbuf, &grep, grep.sizeof);
        x_rpcbuf_write_rpcbuf_pad(&rpcbuf, &childbuf);
    }

    mixin(X_REPLY_FIELD_CARD16!"found");
    mixin(X_REPLY_FIELD_CARD16!"reported");

    status = mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));

    if (loaded) {
        XkbDescPtr old_xkb = void;

        old_xkb = xkb;
        xkb = new_;
        dev.key.xkbInfo.desc = xkb;
        new_ = old_xkb;          /* so it'll get freed automatically */

        XkbCopyControls(xkb, old_xkb);

        xkbNewKeyboardNotify nkn = {
            deviceID: cast(ubyte)dev.id,
            minKeyCode: new_.min_key_code,
            maxKeyCode: new_.max_key_code,
            oldMinKeyCode: xkb.min_key_code,
            oldMaxKeyCode: xkb.max_key_code,
            requestMajor: cast(ubyte)XkbReqCode,
            requestMinor: X_kbGetKbdByName,
            changed: cast(ushort)XkbNKN_KeycodesMask,
        };
        nkn.oldDeviceID = cast(ubyte)dev.id;

        if (geom_changed)
            nkn.changed |= XkbNKN_GeometryMask;
        XkbSendNewKeyboardNotify(dev, &nkn);

        /* Update the map and LED info on the device itself, as well as
         * any slaves if it's an MD, or its MD if it's an SD and was the
         * last device used on that MD. */
        for (tmpd = inputInfo.devices; tmpd; tmpd = tmpd.next) {
            if (tmpd != dev && GetMaster(tmpd, MASTER_KEYBOARD) != dev &&
                (tmpd != master || dev != master.lastSlave))
                continue;

            if (tmpd != dev)
                XkbDeviceApplyKeymap(tmpd, xkb);

            if (tmpd.kbdfeed && tmpd.kbdfeed.xkb_sli) {
                old_sli = tmpd.kbdfeed.xkb_sli;
                tmpd.kbdfeed.xkb_sli = null;
                sli = XkbAllocSrvLedInfo(tmpd, tmpd.kbdfeed, null, 0);
                if (sli) {
                    sli.explicitState = old_sli.explicitState;
                    sli.effectiveState = old_sli.effectiveState;
                }
                tmpd.kbdfeed.xkb_sli = sli;
                XkbFreeSrvLedInfo(old_sli);
            }
        }
    }
    if ((new_ !is null) && (new_ != xkb)) {
        XkbFreeKeyboard(new_, XkbAllComponentsMask, TRUE);
        new_ = null;
    }
    XkbFreeComponentNames(&names, FALSE);
    mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbGetKbdByName`, `client`));
    XkbUpdateAllDeviceIndicators(null, &cause);

    return status;
}

private int ComputeDeviceLedInfoSize(DeviceIntPtr dev, uint what, XkbSrvLedInfoPtr sli)
{
    int nNames = 0, nMaps = 0;
    uint n = void, bit = void;

    if (sli is null)
        return 0;

    if ((what & XkbXI_IndicatorNamesMask) == 0)
        sli.namesPresent = 0;
    if ((what & XkbXI_IndicatorMapsMask) == 0)
        sli.mapsPresent = 0;

    for (n = 0, bit = 1; n < XkbNumIndicators; n++, bit <<= 1) {
        if (sli.names && sli.names[n] != None) {
            sli.namesPresent |= bit;
            nNames++;
        }
        if (sli.maps && mixin(XkbIM_InUse!("&sli.maps[n]"))) {
            sli.mapsPresent |= bit;
            nMaps++;
        }
    }
    return cast(int)((nNames * 4) + (nMaps * xkbIndicatorMapWireDesc.sizeof));
}

private int CheckDeviceLedFBs(DeviceIntPtr dev, int class_, int id, int present, ClientPtr client, int* r_length, int* r_nFBs)
{
    int nFBs = 0;
    int length = 0;
    Bool classOk = FALSE;

    if (class_ == XkbDfltXIClass) {
        if (dev.kbdfeed)
            class_ = KbdFeedbackClass;
        else if (dev.leds)
            class_ = LedFeedbackClass;
        else {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("XkbErr_BadClass", "class_"));
            return XkbKeyboardErrorCode;
        }
    }

    if ((dev.kbdfeed) &&
        ((class_ == KbdFeedbackClass) || (class_ == XkbAllXIClasses))) {
        KbdFeedbackPtr kf = void;

        classOk = TRUE;
        for (kf = dev.kbdfeed; (kf); kf = kf.next) {
            if ((id != XkbAllXIIds) && (id != XkbDfltXIId) &&
                (id != kf.ctrl.id))
                continue;
            nFBs++;
            length += xkbDeviceLedsWireDesc.sizeof;
            if (!kf.xkb_sli)
                kf.xkb_sli = XkbAllocSrvLedInfo(dev, kf, null, 0);
            length += ComputeDeviceLedInfoSize(dev, present, kf.xkb_sli);
            if (id != XkbAllXIIds)
                break;
        }
    }
    if ((dev.leds) &&
        ((class_ == LedFeedbackClass) || (class_ == XkbAllXIClasses))) {
        LedFeedbackPtr lf = void;

        classOk = TRUE;
        for (lf = dev.leds; (lf); lf = lf.next) {
            if ((id != XkbAllXIIds) && (id != XkbDfltXIId) &&
                (id != lf.ctrl.id))
                continue;
            nFBs++;
            length += xkbDeviceLedsWireDesc.sizeof;
            if (!lf.xkb_sli)
                lf.xkb_sli = XkbAllocSrvLedInfo(dev, null, lf, 0);
            length += ComputeDeviceLedInfoSize(dev, present, lf.xkb_sli);
            if (id != XkbAllXIIds)
                break;
        }
    }
    if (nFBs > 0) {
        *r_length = length;
        *r_nFBs = nFBs;
        return Success;
    }
    if (classOk)
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("XkbErr_BadId", "id"));
    else
        client.errorValue = cast(uint)mixin(_XkbErrCode2!("XkbErr_BadClass", "class_"));
    return XkbKeyboardErrorCode;
}

private int FillDeviceLedInfo(XkbSrvLedInfoPtr sli, x_rpcbuf_t* rpcbuf, ClientPtr client)
{
    size_t oldpos = rpcbuf.wpos;

    /* write xkbDeviceLedsWireDesc */
    x_rpcbuf_write_CARD16(rpcbuf, sli.class_);
    x_rpcbuf_write_CARD16(rpcbuf, sli.id);
    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)sli.namesPresent);
    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)sli.mapsPresent);
    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)sli.physIndicators);
    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)sli.effectiveState);

    if (sli.namesPresent | sli.mapsPresent) {
        uint i = void, bit = void;

        if (sli.namesPresent) {
            for (i = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
                if (sli.namesPresent & bit) {
                    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)sli.names[i]);
                }
            }
        }
        if (sli.mapsPresent) {
            for (i = 0, bit = 1; i < XkbNumIndicators; i++, bit <<= 1) {
                if (sli.mapsPresent & bit) {
                    /* write xkbIndicatorMapWireDesc */
                    x_rpcbuf_write_CARD8(rpcbuf, sli.maps[i].flags);
                    x_rpcbuf_write_CARD8(rpcbuf, sli.maps[i].which_groups);
                    x_rpcbuf_write_CARD8(rpcbuf, sli.maps[i].groups);
                    x_rpcbuf_write_CARD8(rpcbuf, sli.maps[i].which_mods);
                    x_rpcbuf_write_CARD8(rpcbuf, sli.maps[i].mods.mask);
                    x_rpcbuf_write_CARD8(rpcbuf, sli.maps[i].mods.real_mods);
                    x_rpcbuf_write_CARD16(rpcbuf, sli.maps[i].mods.vmods);
                    x_rpcbuf_write_CARD32(rpcbuf, cast(uint)sli.maps[i].ctrls);
                }
            }
        }
    }
    return cast(int)(rpcbuf.wpos - oldpos);
}

private int FillDeviceLedFBs(DeviceIntPtr dev, int class_, int id, uint wantLength, char* buffer, ClientPtr client)
{
    int length = 0;

    if (class_ == XkbDfltXIClass) {
        if (dev.kbdfeed)
            class_ = KbdFeedbackClass;
        else if (dev.leds)
            class_ = LedFeedbackClass;
    }
    if ((dev.kbdfeed) &&
        ((class_ == KbdFeedbackClass) || (class_ == XkbAllXIClasses))) {
        KbdFeedbackPtr kf = void;

        for (kf = dev.kbdfeed; (kf); kf = kf.next) {
            if ((id == XkbAllXIIds) || (id == XkbDfltXIId) ||
                (id == kf.ctrl.id)) {

                x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
                int written = FillDeviceLedInfo(kf.xkb_sli, &rpcbuf, client);
                memcpy(buffer, rpcbuf.buffer, rpcbuf.wpos);
                x_rpcbuf_clear(&rpcbuf);

                buffer += written;
                length += written;
                if (id != XkbAllXIIds)
                    break;
            }
        }
    }
    if ((dev.leds) &&
        ((class_ == LedFeedbackClass) || (class_ == XkbAllXIClasses))) {
        LedFeedbackPtr lf = void;

        for (lf = dev.leds; (lf); lf = lf.next) {
            if ((id == XkbAllXIIds) || (id == XkbDfltXIId) ||
                (id == lf.ctrl.id)) {
                x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
                int written = FillDeviceLedInfo(lf.xkb_sli, &rpcbuf, client);
                memcpy(buffer, rpcbuf.buffer, rpcbuf.wpos);
                x_rpcbuf_clear(&rpcbuf);

                buffer += written;
                length += written;
                if (id != XkbAllXIIds)
                    break;
            }
        }
    }
    if (length == wantLength)
        return Success;
    else
        return BadLength;
}

int ProcXkbGetDeviceInfo(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xkbGetDeviceInfoReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"wanted");
    mixin(X_REQUEST_FIELD_CARD16!"ledClass");
    mixin(X_REQUEST_FIELD_CARD16!"ledID");

    DeviceIntPtr dev = void;
    int status = void;
    uint length = void, nameLen = void;
    CARD16 ledClass = void, ledID = void;
    uint wanted = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    wanted = stuff.wanted;

    mixin(CHK_ANY_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixGetAttrAccess`));
    mixin(CHK_MASK_LEGAL!(`0x01`, `wanted`, `XkbXI_AllDeviceFeaturesMask`));

    if ((!dev.button) || ((stuff.nBtns < 1) && (!stuff.allBtns)))
        wanted &= ~XkbXI_ButtonActionsMask;
    if ((!dev.kbdfeed) && (!dev.leds))
        wanted &= ~XkbXI_IndicatorsMask;

    nameLen = cast(uint)mixin(XkbSizeCountedString!(`dev.name`));

    xkbGetDeviceInfoReply reply = {
        deviceID: cast(ubyte)dev.id,
        length: bytes_to_int32(nameLen),
        present: cast(ushort)wanted,
        supported: cast(ubyte)XkbXI_AllDeviceFeaturesMask,
        totalBtns: dev.button ? dev.button.numButtons : 0,
        hasOwnState: (dev.key && dev.key.xkbInfo),
        dfltKbdFB: dev.kbdfeed ? dev.kbdfeed.ctrl.id : XkbXINone,
        dfltLedFB: dev.leds ? dev.leds.ctrl.id : XkbXINone,
        devType: cast(uint)dev.xinput_type
    };

    ledClass = stuff.ledClass;
    ledID = stuff.ledID;

    if (wanted & XkbXI_ButtonActionsMask) {
        if (stuff.allBtns) {
            stuff.firstBtn = 0;
            stuff.nBtns = dev.button.numButtons;
        }

        if ((stuff.firstBtn + stuff.nBtns) > dev.button.numButtons) {
            client.errorValue = cast(uint)mixin(_XkbErrCode4!("0x02", "dev.button.numButtons", "stuff.firstBtn", "stuff.nBtns"));
            return BadValue;
        }
        else {
            reply.firstBtnWanted = stuff.firstBtn;
            reply.nBtnsWanted = stuff.nBtns;
            if (dev.button.xkb_acts !is null) {
                XkbAction* act = void;
                int i = void;

                reply.firstBtnRtrn = stuff.firstBtn;
                reply.nBtnsRtrn = stuff.nBtns;
                act = &dev.button.xkb_acts[reply.firstBtnWanted];
                for (i = 0; i < reply.nBtnsRtrn; i++, act++) {
                    if (act.type != XkbSA_NoAction)
                        break;
                }
                reply.firstBtnRtrn += i;
                reply.nBtnsRtrn -= i;
                act =
                    &dev.button.xkb_acts[reply.firstBtnRtrn + reply.nBtnsRtrn - 1];
                for (i = 0; i < reply.nBtnsRtrn; i++, act--) {
                    if (act.type != XkbSA_NoAction)
                        break;
                }
                reply.nBtnsRtrn -= i;
            }
            reply.length += (reply.nBtnsRtrn * xkbActionWireDesc.sizeof) / 4;
        }
    }

    int led_len = 0;
    int nDeviceLedFBs = 0;

    if (wanted & XkbXI_IndicatorsMask) {
        status = CheckDeviceLedFBs(dev, ledClass, ledID, reply.present, client, &led_len, &nDeviceLedFBs);
        if (status != Success)
            return status;
        reply.nDeviceLedFBs = cast(ushort)nDeviceLedFBs;
        reply.length += bytes_to_int32(led_len);
    }

    length = cast(uint)reply.length * 4;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (rpcbuf.swapped) {
        swaps(&reply.present);
        swaps(&reply.supported);
        swaps(&reply.unsupported);
        swaps(&reply.nDeviceLedFBs);
        swaps(&reply.dfltKbdFB);
        swaps(&reply.dfltLedFB);
        swapl(&reply.devType);
    }

    int sz = cast(int)(nameLen + reply.nBtnsRtrn * ((xkbActionWireDesc).sizeof + led_len));
    char* buf = cast(char*)x_rpcbuf_reserve(&rpcbuf, sz);
    if (!buf)
        return BadAlloc;
    char* walk = buf;

    XkbWriteCountedString(walk, dev.name, client.swapped);
    walk += nameLen;

    if (reply.nBtnsRtrn > 0) {
        memcpy(walk,
               &dev.button.xkb_acts[reply.firstBtnRtrn],
               ((xkbActionWireDesc).sizeof * reply.nBtnsRtrn));
        walk += ((xkbActionWireDesc).sizeof * reply.nBtnsRtrn);
    }

    length -= walk - buf;

    if (nDeviceLedFBs > 0) {
        status = FillDeviceLedFBs(dev, ledClass, ledID, length, walk, client);
        if (status != Success) {
            x_rpcbuf_clear(&rpcbuf);
            return status;
        }
    }
    else if (length != 0) {
        ErrorF("[xkb] Internal Error!  BadLength in ProcXkbGetDeviceInfo\n");
        ErrorF("[xkb]                  Wrote %d fewer bytes than expected\n",
               length);
        x_rpcbuf_clear(&rpcbuf);
        return BadLength;
    }

    mixin(X_REPLY_FIELD_CARD16!"present");
    mixin(X_REPLY_FIELD_CARD16!"supported");
    mixin(X_REPLY_FIELD_CARD16!"unsupported");
    mixin(X_REPLY_FIELD_CARD16!"nDeviceLedFBs");
    mixin(X_REPLY_FIELD_CARD16!"dfltKbdFB");
    mixin(X_REPLY_FIELD_CARD16!"dfltLedFB");
    mixin(X_REPLY_FIELD_CARD32!"devType");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private char* CheckSetDeviceIndicators(char* wire, DeviceIntPtr dev, int num, int* status_rtrn, ClientPtr client, xkbSetDeviceInfoReq* stuff)
{
    xkbDeviceLedsWireDesc* ledWire = void;
    int i = void;
    XkbSrvLedInfoPtr sli = void;

    ledWire = cast(xkbDeviceLedsWireDesc*) wire;
    for (i = 0; i < num; i++) {
        if (!_XkbCheckRequestBounds(client, stuff, ledWire, ledWire + 1)) {
            *status_rtrn = BadLength;
            return cast(char*) ledWire;
        }

        if (client.swapped) {
            swaps(&ledWire.ledClass);
            swaps(&ledWire.ledID);
            swapl(&ledWire.namesPresent);
            swapl(&ledWire.mapsPresent);
            swapl(&ledWire.physIndicators);
        }

        sli = XkbFindSrvLedInfo(dev, ledWire.ledClass, ledWire.ledID,
                                XkbXI_IndicatorsMask);
        if (sli !is null) {
            int n = void;
            uint bit = void;
            int nMaps = void, nNames = void;
            CARD32* atomWire = void;
            xkbIndicatorMapWireDesc* mapWire = void;

            nMaps = nNames = 0;
            for (n = 0, bit = 1; n < XkbNumIndicators; n++, bit <<= 1) {
                if (ledWire.namesPresent & bit)
                    nNames++;
                if (ledWire.mapsPresent & bit)
                    nMaps++;
            }
            atomWire = cast(CARD32*) &ledWire[1];
            if (nNames > 0) {
                for (n = 0; n < nNames; n++) {
                    if (!_XkbCheckRequestBounds(client, stuff, atomWire, atomWire + 1)) {
                        *status_rtrn = BadLength;
                        return cast(char*) atomWire;
                    }

                    if (client.swapped) {
                        swapl(atomWire);
                    }
                    mixin(CHK_ATOM_OR_NONE3!(`(cast(Atom) (*atomWire))`, `client.errorValue`,
                                      `*status_rtrn`, `null`));
                    atomWire++;
                }
            }
            mapWire = cast(xkbIndicatorMapWireDesc*) atomWire;
            if (nMaps > 0) {
                for (n = 0; n < nMaps; n++) {
                    if (!_XkbCheckRequestBounds(client, stuff, mapWire, mapWire + 1)) {
                        *status_rtrn = BadLength;
                        return cast(char*) mapWire;
                    }
                    if (client.swapped) {
                        swaps(&mapWire.virtualMods);
                        swapl(&mapWire.ctrls);
                    }
                    mixin(CHK_MASK_LEGAL3!(`0x21`, `mapWire.whichGroups`,
                                    `XkbIM_UseAnyGroup`,
                                    `client.errorValue`, `*status_rtrn`, `null`));
                    mixin(CHK_MASK_LEGAL3!(`0x22`, `mapWire.whichMods`, `XkbIM_UseAnyMods`,
                                    `client.errorValue`, `*status_rtrn`, `null`));
                    mapWire++;
                }
            }
            ledWire = cast(xkbDeviceLedsWireDesc*) mapWire;
        }
        else {
            /* SHOULD NEVER HAPPEN */
            return cast(char*) ledWire;
        }
    }
    return cast(char*) ledWire;
}

private char* SetDeviceIndicators(char* wire, DeviceIntPtr dev, uint changed, int num, int* status_rtrn, ClientPtr client, xkbExtensionDeviceNotify* ev, xkbSetDeviceInfoReq* stuff)
{
    xkbDeviceLedsWireDesc* ledWire = void;
    int i = void;
    XkbEventCauseRec cause = { 0 };
    uint namec = void, mapc = void, statec = void;
    xkbExtensionDeviceNotify ed = { 0 };
    XkbChangesRec changes = { 0 };
    DeviceIntPtr kbd = void;

    memset(cast(char*) &ed, 0, xkbExtensionDeviceNotify.sizeof);
    memset(cast(char*) &changes, 0, XkbChangesRec.sizeof);
    mixin(XkbSetCauseXkbReq!(`&cause`, `X_kbSetDeviceInfo`, `client`));
    ledWire = cast(xkbDeviceLedsWireDesc*) wire;
    for (i = 0; i < num; i++) {
        int n = void;
        uint bit = void;
        CARD32* atomWire = void;
        xkbIndicatorMapWireDesc* mapWire = void;
        XkbSrvLedInfoPtr sli = void;

        namec = mapc = statec = 0;
        sli = XkbFindSrvLedInfo(dev, ledWire.ledClass, ledWire.ledID,
                                cast(uint)XkbXI_IndicatorMapsMask);
        if (!sli) {
            /* SHOULD NEVER HAPPEN!! */
            return cast(char*) ledWire;
        }

        atomWire = cast(CARD32*) &ledWire[1];
        if (changed & XkbXI_IndicatorNamesMask) {
            namec = cast(uint)(sli.namesPresent | ledWire.namesPresent);
            memset(cast(char*) sli.names, 0, XkbNumIndicators * Atom.sizeof);
        }
        if (ledWire.namesPresent) {
            sli.namesPresent = ledWire.namesPresent;
            memset(cast(char*) sli.names, 0, XkbNumIndicators * Atom.sizeof);
            for (n = 0, bit = 1; n < XkbNumIndicators; n++, bit <<= 1) {
                if (ledWire.namesPresent & bit) {
                    sli.names[n] = cast(Atom)( *atomWire);
                    if (sli.names[n] == None)
                        ledWire.namesPresent &= ~bit;
                    atomWire++;
                }
            }
        }
        mapWire = cast(xkbIndicatorMapWireDesc*) atomWire;
        if (changed & XkbXI_IndicatorMapsMask) {
            mapc = cast(uint)(sli.mapsPresent | ledWire.mapsPresent);
            sli.mapsPresent = ledWire.mapsPresent;
            memset(cast(char*) sli.maps, 0,
                   XkbNumIndicators * XkbIndicatorMapRec.sizeof);
        }
        if (ledWire.mapsPresent) {
            for (n = 0, bit = 1; n < XkbNumIndicators; n++, bit <<= 1) {
                if (ledWire.mapsPresent & bit) {
                    sli.maps[n].flags = mapWire.flags;
                    sli.maps[n].which_groups = mapWire.whichGroups;
                    sli.maps[n].groups = mapWire.groups;
                    sli.maps[n].which_mods = mapWire.whichMods;
                    sli.maps[n].mods.mask = mapWire.mods;
                    sli.maps[n].mods.real_mods = mapWire.realMods;
                    sli.maps[n].mods.vmods = mapWire.virtualMods;
                    sli.maps[n].ctrls =cast(uint)mapWire.ctrls;
                    mapWire++;
                }
            }
        }
        if (changed & XkbXI_IndicatorStateMask) {
            statec = cast(uint)(sli.effectiveState ^ ledWire.state);
            sli.explicitState &= ~statec;
            sli.explicitState |= (ledWire.state & statec);
        }
        if (namec)
            XkbApplyLedNameChanges(dev, sli, namec, &ed, &changes, &cause);
        if (mapc)
            XkbApplyLedMapChanges(dev, sli, mapc, &ed, &changes, &cause);
        if (statec)
            XkbApplyLedStateChanges(dev, sli, statec, &ed, &changes, &cause);

        kbd = dev;
        if ((sli.flags & XkbSLI_HasOwnState) == 0)
            kbd = inputInfo.keyboard;

        XkbFlushLedEvents(dev, kbd, sli, &ed, &changes, &cause);
        ledWire = cast(xkbDeviceLedsWireDesc*) mapWire;
    }
    return cast(char*) ledWire;
}

private int _XkbSetDeviceInfoCheck(ClientPtr client, DeviceIntPtr dev, xkbSetDeviceInfoReq* stuff)
{
    char* wire = void;

    wire = cast(char*) &stuff[1];
    if (stuff.change & XkbXI_ButtonActionsMask) {
        int sz = stuff.nBtns * xkbActionWireDesc.sizeof;
        if (!_XkbCheckRequestBounds(client, stuff, wire, cast(char*) wire + sz))
            return BadLength;

        if (!dev.button) {
            client.errorValue = cast(uint)mixin(_XkbErrCode2!("XkbErr_BadClass", "ButtonClass"));
            return XkbKeyboardErrorCode;
        }
        if ((stuff.firstBtn + stuff.nBtns) > dev.button.numButtons) {
            client.errorValue =
                mixin(_XkbErrCode4!("0x02", "stuff.firstBtn", "stuff.nBtns", "dev.button.numButtons"));
            return BadMatch;
        }
        wire += sz;
    }
    if (stuff.change & XkbXI_IndicatorsMask) {
        int status = Success;

        wire = CheckSetDeviceIndicators(wire, dev, stuff.nDeviceLedFBs,
                                        &status, client, stuff);
        if (status != Success)
            return status;
    }
    if (((wire - (cast(char*) stuff)) / 4) != client.req_len)
        return BadLength;

    return Success;
}

private int _XkbSetDeviceInfo(ClientPtr client, DeviceIntPtr dev, xkbSetDeviceInfoReq* stuff)
{
    char* wire = void;
    xkbExtensionDeviceNotify ed = { 0 };

    ed.deviceID = cast(ubyte)dev.id;
    wire = cast(char*) &stuff[1];
    if (stuff.change & XkbXI_ButtonActionsMask) {
        int nBtns = void, sz = void, i = void;
        XkbAction* acts = void;
        DeviceIntPtr kbd = void;

        nBtns = dev.button.numButtons;
        acts = dev.button.xkb_acts;
        if (acts is null) {
            acts = cast(XkbAction*) calloc(nBtns, XkbAction.sizeof);
            if (!acts)
                return BadAlloc;
            dev.button.xkb_acts = acts;
        }
        if (stuff.firstBtn + stuff.nBtns > nBtns)
            return BadValue;
        sz = stuff.nBtns * xkbActionWireDesc.sizeof;
        memcpy(cast(char*) &acts[stuff.firstBtn], cast(char*) wire, sz);
        wire += sz;
        ed.reason |= XkbXI_ButtonActionsMask;
        ed.firstBtn = stuff.firstBtn;
        ed.nBtns = stuff.nBtns;

        if (dev.key)
            kbd = dev;
        else
            kbd = inputInfo.keyboard;
        acts = &dev.button.xkb_acts[stuff.firstBtn];
        for (i = 0; i < stuff.nBtns; i++, acts++) {
            if (acts.type != XkbSA_NoAction)
                XkbSetActionKeyMods(kbd.key.xkbInfo.desc, acts, 0);
        }
    }
    if (stuff.change & XkbXI_IndicatorsMask) {
        int status = Success;

        wire = SetDeviceIndicators(wire, dev, stuff.change,
                                   stuff.nDeviceLedFBs, &status, client, &ed,
                                   stuff);
        if (status != Success)
            return status;
    }
    if ((stuff.change) && (ed.reason))
        XkbSendExtensionDeviceNotify(dev, client, &ed);
    return Success;
}

int ProcXkbSetDeviceInfo(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSetDeviceInfoReq);
    mixin(X_REQUEST_FIELD_CARD16!"deviceSpec");
    mixin(X_REQUEST_FIELD_CARD16!"change");
    mixin(X_REQUEST_FIELD_CARD16!"nDeviceLedFBs");

    DeviceIntPtr dev = void;
    int rc = void;

    if (!(client.xkbClientFlags & _XkbClientInitialized))
        return BadAccess;

    mixin(CHK_ANY_DEVICE!(`dev`, `stuff.deviceSpec`, `client`, `DixManageAccess`));
    mixin(CHK_MASK_LEGAL!(`0x01`, `stuff.change`, `XkbXI_AllFeaturesMask`));

    rc = _XkbSetDeviceInfoCheck(client, dev, stuff);

    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd ||
        stuff.deviceSpec == XkbUseCorePtr) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if (((other != dev) && !InputDevIsMaster(other) &&
                 GetMaster(other, MASTER_KEYBOARD) == dev) &&
                ((stuff.deviceSpec == XkbUseCoreKbd && other.key) ||
                 (stuff.deviceSpec == XkbUseCorePtr && other.button))) {
                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success) {
                    rc = _XkbSetDeviceInfoCheck(client, other, stuff);
                    if (rc != Success)
                        return rc;
                }
            }
        }
    }

    /* checks done, apply */
    rc = _XkbSetDeviceInfo(client, dev, stuff);
    if (rc != Success)
        return rc;

    if (stuff.deviceSpec == XkbUseCoreKbd ||
        stuff.deviceSpec == XkbUseCorePtr) {
        DeviceIntPtr other = void;

        for (other = inputInfo.devices; other; other = other.next) {
            if (((other != dev) && !InputDevIsMaster(other) &&
                 GetMaster(other, MASTER_KEYBOARD) == dev) &&
                ((stuff.deviceSpec == XkbUseCoreKbd && other.key) ||
                 (stuff.deviceSpec == XkbUseCorePtr && other.button))) {
                rc = dixCallDeviceAccessCallback(client, other, DixManageAccess);
                if (rc == Success) {
                    rc = _XkbSetDeviceInfo(client, other, stuff);
                    if (rc != Success)
                        return rc;
                }
            }
        }
    }

    return Success;
}

int ProcXkbSetDebuggingFlags(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xkbSetDebuggingFlagsReq);
    mixin(X_REQUEST_FIELD_CARD32!"affectFlags");
    mixin(X_REQUEST_FIELD_CARD32!"flags");
    mixin(X_REQUEST_FIELD_CARD32!"affectCtrls");
    mixin(X_REQUEST_FIELD_CARD32!"ctrls");
    mixin(X_REQUEST_FIELD_CARD16!"msgLength");

    CARD32 newFlags = void, newCtrls = void, extraLength = void;
    int rc = void;

    rc = dixCallServerAccessCallback(client, DixDebugAccess);
    if (rc != Success)
        return rc;

    newFlags = xkbDebugFlags & (~stuff.affectFlags);
    newFlags |= (stuff.flags & stuff.affectFlags);
    newCtrls = xkbDebugCtrls & (~stuff.affectCtrls);
    newCtrls |= (stuff.ctrls & stuff.affectCtrls);
    if (xkbDebugFlags || newFlags || stuff.msgLength) {
        ErrorF("[xkb] XkbDebug: Setting debug flags to 0x%lx\n",
               cast(c_long) newFlags);
        if (newCtrls != xkbDebugCtrls)
            ErrorF("[xkb] XkbDebug: Setting debug controls to 0x%lx\n",
                   cast(c_long) newCtrls);
    }
    extraLength = (client.req_len << 2) - sz_xkbSetDebuggingFlagsReq;
    if (stuff.msgLength > 0) {
        char* msg = void;

        if (extraLength < mixin(XkbPaddedSize!("stuff.msgLength"))) {
            ErrorF
                ("[xkb] XkbDebug: msgLength= %d, length= %ld (should be %d)\n",
                 stuff.msgLength, cast(c_long) extraLength,
                 mixin(XkbPaddedSize!("stuff.msgLength")));
            return BadLength;
        }
        msg = cast(char*) &stuff[1];
        if (msg[stuff.msgLength - 1] != '\0') {
            ErrorF("[xkb] XkbDebug: message not null-terminated\n");
            return BadValue;
        }
        ErrorF("[xkb] XkbDebug: %s\n", msg);
    }
    xkbDebugFlags = newFlags;
    xkbDebugCtrls = newCtrls;

    xkbSetDebuggingFlagsReply reply = {
        currentFlags: newFlags,
        currentCtrls: newCtrls,
        supportedFlags: ~0,
        supportedCtrls: ~0
    };

    mixin(X_REPLY_FIELD_CARD32!"currentFlags");
    mixin(X_REPLY_FIELD_CARD32!"currentCtrls");
    mixin(X_REPLY_FIELD_CARD32!"supportedFlags");
    mixin(X_REPLY_FIELD_CARD32!"supportedCtrls");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcXkbDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_kbUseExtension:
        return ProcXkbUseExtension(client);
    case X_kbSelectEvents:
        return ProcXkbSelectEvents(client);
    case X_kbBell:
        return ProcXkbBell(client);
    case X_kbGetState:
        return ProcXkbGetState(client);
    case X_kbLatchLockState:
        return ProcXkbLatchLockState(client);
    case X_kbGetControls:
        return ProcXkbGetControls(client);
    case X_kbSetControls:
        return ProcXkbSetControls(client);
    case X_kbGetMap:
        return ProcXkbGetMap(client);
    case X_kbSetMap:
        return ProcXkbSetMap(client);
    case X_kbGetCompatMap:
        return ProcXkbGetCompatMap(client);
    case X_kbSetCompatMap:
        return ProcXkbSetCompatMap(client);
    case X_kbGetIndicatorState:
        return ProcXkbGetIndicatorState(client);
    case X_kbGetIndicatorMap:
        return ProcXkbGetIndicatorMap(client);
    case X_kbSetIndicatorMap:
        return ProcXkbSetIndicatorMap(client);
    case X_kbGetNamedIndicator:
        return ProcXkbGetNamedIndicator(client);
    case X_kbSetNamedIndicator:
        return ProcXkbSetNamedIndicator(client);
    case X_kbGetNames:
        return ProcXkbGetNames(client);
    case X_kbSetNames:
        return ProcXkbSetNames(client);
    case X_kbGetGeometry:
        return ProcXkbGetGeometry(client);
    case X_kbSetGeometry:
        return ProcXkbSetGeometry(client);
    case X_kbPerClientFlags:
        return ProcXkbPerClientFlags(client);
    case X_kbListComponents:
        return ProcXkbListComponents(client);
    case X_kbGetKbdByName:
        return ProcXkbGetKbdByName(client);
    case X_kbGetDeviceInfo:
        return ProcXkbGetDeviceInfo(client);
    case X_kbSetDeviceInfo:
        return ProcXkbSetDeviceInfo(client);
    case X_kbSetDebuggingFlags:
        return ProcXkbSetDebuggingFlags(client);
    default:
        return BadRequest;
    }
}

private int XkbClientGone(void* data, XID id)
{
    DevicePtr pXDev = cast(DevicePtr) data;

    if (!XkbRemoveResourceClient(pXDev, id)) {
        ErrorF
            ("[xkb] Internal Error! bad RemoveResourceClient in XkbClientGone\n");
    }
    return 1;
}

void XkbExtensionInit()
{
    ExtensionEntry* extEntry = void;

    RT_XKBCLIENT = CreateNewResourceType(&XkbClientGone, "XkbClient");
    if (!RT_XKBCLIENT)
        return;

    if (!XkbInitPrivates())
        return;

    if ((extEntry = AddExtension(XkbName, XkbNumberEvents, XkbNumberErrors,
                                 &ProcXkbDispatch, &ProcXkbDispatch,
                                 null, &StandardMinorOpcode))!is null) {
        XkbReqCode = cast(ubyte) extEntry.base;
        XkbEventBase = cast(ubyte) extEntry.eventBase;
        XkbErrorBase = cast(ubyte) extEntry.errorBase;
        XkbKeyboardErrorCode = XkbErrorBase + XkbKeyboard;
    }
    return;
}
