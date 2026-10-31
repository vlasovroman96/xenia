module xkb.xkbEvents;
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
//import x11.keysym;
//import externs.X11.extensions.XI;
// //import externs.X11.extensions.XIproto;

import dix.dix_priv;
import dix.exevents_priv;
import dix.input_priv;
import os.log_priv;
import xkb.xkbsrv_priv;

import include.inputstr;
import Xi.exglobals;
import include.windowstr;
import externs.X11.extensions.XKBproto;
// import externs.X11.extensions.XKBstr;
import include.xkbstr;
import include.misc;
import include.inputstr;
import include.exevents;
import dix.events;
import mi.mipointer;
import include.xkbstr;
import os.WaitFor;
import include.xkbstr;
import os.log;
import os.utils;
import dix.events;
import externs.gnu;
import dix.devices;
import dix.inpututils;


/***====================================================================***/

/*
 * This function sends out two kinds of notification:
 *   - Core mapping notify events sent to clients for whom kbd is the
 *     current core ('picked') keyboard _and_ have not explicitly
 *     selected for XKB mapping notify events;
 *   - Xi mapping events, sent unconditionally to all clients who have
 *     explicitly selected for them (including those who have explicitly
 *     selected for XKB mapping notify events!).
 */
private void XkbSendLegacyMapNotify(DeviceIntPtr kbd, CARD16 xkb_event, CARD16 changed, int first_key, int num_keys)
{
    int i = void;
    int keymap_changed = 0;
    int modmap_changed = 0;
    CARD32 time = GetTimeInMillis();

    if (xkb_event == XkbNewKeyboardNotify) {
        if (changed & XkbNKN_KeycodesMask) {
            keymap_changed = 1;
            modmap_changed = 1;
        }
    }
    else if (xkb_event == XkbMapNotify) {
        if (changed & XkbKeySymsMask)
            keymap_changed = 1;
        if (changed & XkbModifierMapMask)
            modmap_changed = 1;
    }
    if (!keymap_changed && !modmap_changed)
        return;

    /* 0 is serverClient. */
    for (i = 1; i < currentMaxClients; i++) {
        if (!clients[i] || clients[i].clientState != ClientStateRunning)
            continue;

        /* XKB allows clients to restrict the MappingNotify events sent to
         * them.  This was broken for three years.  Sorry. */
        if (xkb_event == XkbMapNotify &&
            (clients[i].xkbClientFlags & _XkbClientInitialized) &&
            !(clients[i].mapNotifyMask & changed))
            continue;
        /* Emulate previous server behaviour: any client which has activated
         * XKB will not receive core events emulated from a NewKeyboardNotify
         * at all. */
        if (xkb_event == XkbNewKeyboardNotify &&
            (clients[i].xkbClientFlags & _XkbClientInitialized))
            continue;

        /* Don't send core events to clients who don't know about us. */
        if (!XIShouldNotify(clients[i], kbd))
            continue;

        if (keymap_changed) {
            xEvent core_mn;
            core_mn.u.u.type = MappingNotify ;
            core_mn.u.mappingNotify.request = MappingKeyboard;

            /* Clip the keycode range to what the client knows about, so it
             * doesn't freak out. */
            if (first_key >= clients[i].minKC)
                core_mn.u.mappingNotify.firstKeyCode = cast(ubyte)first_key;
            else
                core_mn.u.mappingNotify.firstKeyCode = clients[i].minKC;
            if (first_key + num_keys - 1 <= clients[i].maxKC)
                core_mn.u.mappingNotify.count = cast(ubyte)num_keys;
            else
                core_mn.u.mappingNotify.count = cast(ubyte)(clients[i].maxKC -
                    clients[i].minKC + 1);

            WriteEventsToClient(clients[i], 1, &core_mn);
        }
        if (modmap_changed) {
            xEvent core_mn;
                core_mn.u.mappingNotify.request = MappingModifier;
                core_mn.u.mappingNotify.firstKeyCode = 0;
                core_mn.u.mappingNotify.count = 0;
            core_mn.u.u.type = MappingNotify;
            WriteEventsToClient(clients[i], 1, &core_mn);
        }
    }

    /* Hmm, maybe we can accidentally generate Xi events for core devices
     * here? Clients might be upset, but that seems better than the
     * alternative of stale keymaps. -ds */
    if (keymap_changed) {
        deviceMappingNotify xi_mn = {
            type: cast(ubyte)DeviceMappingNotify,
            deviceid: cast(ubyte)cast(ubyte)kbd.id,
            request: MappingKeyboard,
            firstKeyCode:cast(ubyte) first_key,
            count: cast(ubyte)num_keys,
            time: time
        };
        SendEventToAllWindows(kbd, DeviceMappingNotifyMask, cast(xEvent*) &xi_mn,
                              1);
    }
    if (modmap_changed) {
        deviceMappingNotify xi_mn = {
            type: cast(ubyte)DeviceMappingNotify,
            deviceid: cast(ubyte)cast(ubyte)kbd.id,
            request: MappingModifier,
            firstKeyCode: 0,
            count: 0,
            time: time
        };
        SendEventToAllWindows(kbd, DeviceMappingNotifyMask, cast(xEvent*) &xi_mn,
                              1);
    }
}

/***====================================================================***/

void XkbSendNewKeyboardNotify(DeviceIntPtr kbd, xkbNewKeyboardNotify* pNKN)
{
    int i = void;
    Time time = GetTimeInMillis();
    CARD16 changed = cast(ushort)pNKN.changed;

    pNKN.type = cast(ubyte)(cast(ubyte)(XkbEventCode + XkbEventBase));
    pNKN.xkbType = XkbNewKeyboardNotify;

    for (i = 1; i < currentMaxClients; i++) {
        if (!clients[i] || clients[i].clientState != ClientStateRunning)
            continue;

        if (!(clients[i].newKeyboardNotifyMask & changed))
            continue;

        pNKN.time = cast(uint)time;
        pNKN.changed = changed;
        if (clients[i].swapped) {
            swapl(&pNKN.time);
            swaps(&pNKN.changed);
        }
        xmitClientEvent(clients[i], *cast(xEvent*)pNKN);

        if (changed & XkbNKN_KeycodesMask) {
            clients[i].minKC = pNKN.minKeyCode;
            clients[i].maxKC = pNKN.maxKeyCode;
        }
    }

    XkbSendLegacyMapNotify(kbd, XkbNewKeyboardNotify, changed, pNKN.minKeyCode,
                           pNKN.maxKeyCode - pNKN.minKeyCode + 1);

    return;
}

/***====================================================================***/

void XkbSendStateNotify(DeviceIntPtr kbd, xkbStateNotify* pSN)
{
    XkbSrvInfoPtr xkbi = void;
    XkbStatePtr state;
    XkbInterestPtr interest = void;
    Time time = void;
    CARD16 changed = void, bState = void;

    interest = kbd.xkb_interest;
    if (!interest || !kbd.key || !kbd.key.xkbInfo)
        return;
    xkbi = kbd.key.xkbInfo;
    state = &xkbi.state;

    pSN.type = cast(ubyte)(cast(ubyte)(XkbEventCode + XkbEventBase));
    pSN.xkbType = XkbStateNotify;
    pSN.deviceID = cast(ubyte)cast(ubyte)kbd.id;
    pSN.time = time = GetTimeInMillis();
    pSN.mods = state.mods;
    pSN.baseMods = state.base_mods;
    pSN.latchedMods = state.latched_mods;
    pSN.lockedMods = state.locked_mods;
    pSN.group = state.group;
    pSN.baseGroup = state.base_group;
    pSN.latchedGroup = state.latched_group;
    pSN.lockedGroup = state.locked_group;
    pSN.compatState = state.compat_state;
    pSN.grabMods = state.grab_mods;
    pSN.compatGrabMods = state.compat_grab_mods;
    pSN.lookupMods = state.lookup_mods;
    pSN.compatLookupMods = state.compat_lookup_mods;
    pSN.ptrBtnState = state.ptr_buttons;
    changed = pSN.changed;
    bState = pSN.ptrBtnState;

    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.stateNotifyMask & changed)) {
            pSN.time = cast(uint)time;
            pSN.changed = changed;
            pSN.ptrBtnState = bState;
            if (interest.client.swapped) {
                swapl(&pSN.time);
                swaps(&pSN.changed);
                swaps(&pSN.ptrBtnState);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pSN);
        }
        interest = interest.next;
    }
    return;
}

/***====================================================================***/

/*
 * This function sends out XKB mapping notify events to clients which
 * have explicitly selected for them.  Core and Xi events are handled by
 * XkbSendLegacyMapNotify. */
void XkbSendMapNotify(DeviceIntPtr kbd, xkbMapNotify* pMN)
{
    int i = void;
    CARD32 time = GetTimeInMillis();
    CARD16 changed = cast(ushort)pMN.changed;
    XkbSrvInfoPtr xkbi = kbd.key.xkbInfo;

    pMN.minKeyCode = xkbi.desc.min_key_code;
    pMN.maxKeyCode = xkbi.desc.max_key_code;
    pMN.type = cast(ubyte)(cast(ubyte)(XkbEventCode + XkbEventBase));
    pMN.xkbType = XkbMapNotify;
    pMN.deviceID = cast(ubyte)cast(ubyte)kbd.id;

    /* 0 is serverClient. */
    for (i = 1; i < currentMaxClients; i++) {
        if (!clients[i] || clients[i].clientState != ClientStateRunning)
            continue;

        if (!(clients[i].mapNotifyMask & changed))
            continue;

        pMN.time = time;
        pMN.changed = changed;

        if (clients[i].swapped) {
            swapl(&pMN.time);
            swaps(&pMN.changed);
        }
        xmitClientEvent(clients[i], *cast(xEvent*)pMN);
    }

    XkbSendLegacyMapNotify(kbd, XkbMapNotify, changed, pMN.firstKeySym,
                           pMN.nKeySyms);
}

int XkbComputeControlsNotify(DeviceIntPtr kbd, XkbControlsPtr old, XkbControlsPtr new_, xkbControlsNotify* pCN, Bool forceCtrlProc)
{
    int i = void;
    CARD32 changedControls = void;

    changedControls = 0;

    if (!kbd || !kbd.kbdfeed)
        return 0;

    if (old.enabled_ctrls != new_.enabled_ctrls)
        changedControls |= XkbControlsEnabledMask;
    if ((old.repeat_delay != new_.repeat_delay) ||
        (old.repeat_interval != new_.repeat_interval))
        changedControls |= XkbRepeatKeysMask;
    for (i = 0; i < XkbPerKeyBitArraySize; i++)
        if (old.per_key_repeat[i] != new_.per_key_repeat[i])
            changedControls |= XkbPerKeyRepeatMask;
    if (old.slow_keys_delay != new_.slow_keys_delay)
        changedControls |= XkbSlowKeysMask;
    if (old.debounce_delay != new_.debounce_delay)
        changedControls |= XkbBounceKeysMask;
    if ((old.mk_delay != new_.mk_delay) ||
        (old.mk_interval != new_.mk_interval) ||
        (old.mk_dflt_btn != new_.mk_dflt_btn))
        changedControls |= XkbMouseKeysMask;
    if ((old.mk_time_to_max != new_.mk_time_to_max) ||
        (old.mk_curve != new_.mk_curve) ||
        (old.mk_max_speed != new_.mk_max_speed))
        changedControls |= XkbMouseKeysAccelMask;
    if (old.ax_options != new_.ax_options)
        changedControls |= XkbAccessXKeysMask;
    if ((old.ax_options ^ new_.ax_options) & XkbAX_SKOptionsMask)
        changedControls |= XkbStickyKeysMask;
    if ((old.ax_options ^ new_.ax_options) & XkbAX_FBOptionsMask)
        changedControls |= XkbAccessXFeedbackMask;
    if ((old.ax_timeout != new_.ax_timeout) ||
        (old.axt_ctrls_mask != new_.axt_ctrls_mask) ||
        (old.axt_ctrls_values != new_.axt_ctrls_values) ||
        (old.axt_opts_mask != new_.axt_opts_mask) ||
        (old.axt_opts_values != new_.axt_opts_values)) {
        changedControls |= XkbAccessXTimeoutMask;
    }
    if ((old.internal.mask != new_.internal.mask) ||
        (old.internal.real_mods != new_.internal.real_mods) ||
        (old.internal.vmods != new_.internal.vmods))
        changedControls |= XkbInternalModsMask;
    if ((old.ignore_lock.mask != new_.ignore_lock.mask) ||
        (old.ignore_lock.real_mods != new_.ignore_lock.real_mods) ||
        (old.ignore_lock.vmods != new_.ignore_lock.vmods))
        changedControls |= XkbIgnoreLockModsMask;

    if (new_.enabled_ctrls & XkbRepeatKeysMask)
        kbd.kbdfeed.ctrl.autoRepeat = TRUE;
    else
        kbd.kbdfeed.ctrl.autoRepeat = FALSE;

    if (kbd.kbdfeed && kbd.kbdfeed.CtrlProc &&
        (changedControls || forceCtrlProc))
        (*kbd.kbdfeed.CtrlProc) (kbd, &kbd.kbdfeed.ctrl);

    if ((!changedControls) && (old.num_groups == new_.num_groups))
        return 0;

    if (!kbd.xkb_interest)
        return 0;

    pCN.changedControls = changedControls;
    pCN.enabledControls = new_.enabled_ctrls;
    pCN.enabledControlChanges = (new_.enabled_ctrls ^ old.enabled_ctrls);
    pCN.numGroups = new_.num_groups;

    return 1;
}

void XkbSendControlsNotify(DeviceIntPtr kbd, xkbControlsNotify* pCN)
{
    int initialized = void;
    CARD32 changedControls = void, enabledControls = void, enabledChanges = 0;
    XkbSrvInfoPtr xkbi = void;
    XkbInterestPtr interest = void;
    Time time = 0;

    interest = kbd.xkb_interest;
    if (!interest || !kbd.key || !kbd.key.xkbInfo)
        return;
    xkbi = kbd.key.xkbInfo;

    initialized = 0;
    enabledControls = xkbi.desc.ctrls.enabled_ctrls;
    changedControls = pCN.changedControls;
    pCN.numGroups = xkbi.desc.ctrls.num_groups;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.ctrlsNotifyMask & changedControls)) {
            if (!initialized) {
                pCN.type = cast(ubyte)(cast(ubyte)(XkbEventCode + XkbEventBase));
                pCN.xkbType = XkbControlsNotify;
                pCN.deviceID = cast(ubyte)cast(ubyte)kbd.id;
                pCN.time = time = GetTimeInMillis();
                enabledChanges = pCN.enabledControlChanges;
                initialized = 1;
            }
            pCN.changedControls = changedControls;
            pCN.enabledControls = enabledControls;
            pCN.enabledControlChanges = enabledChanges;
            pCN.time = cast(uint)time;
            if (interest.client.swapped) {
                swapl(&pCN.changedControls);
                swapl(&pCN.enabledControls);
                swapl(&pCN.enabledControlChanges);
                swapl(&pCN.time);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pCN);
        }
        interest = interest.next;
    }
    return;
}

private void XkbSendIndicatorNotify(DeviceIntPtr kbd, int xkbType, xkbIndicatorNotify* pEv)
{
    int initialized = void;
    XkbInterestPtr interest = void;
    Time time = 0;
    CARD32 state = void, changed = void;

    interest = kbd.xkb_interest;
    if (!interest)
        return;

    initialized = 0;
    state = pEv.state;
    changed = pEv.changed;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (((xkbType == XkbIndicatorStateNotify) &&
              (interest.iStateNotifyMask & changed)) ||
             ((xkbType == XkbIndicatorMapNotify) &&
              (interest.iMapNotifyMask & changed)))) {
            if (!initialized) {
                pEv.type = cast(ubyte)(cast(ubyte)(XkbEventCode + XkbEventBase));
                pEv.xkbType = cast(ubyte)xkbType;
                pEv.deviceID = cast(ubyte)cast(ubyte)kbd.id;
                pEv.time = time = GetTimeInMillis();
                initialized = 1;
            }
            pEv.time = cast(uint)time;
            pEv.changed = changed;
            pEv.state = state;
            if (interest.client.swapped) {
                swapl(&pEv.time);
                swapl(&pEv.changed);
                swapl(&pEv.state);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pEv);
        }
        interest = interest.next;
    }
    return;
}

void XkbHandleBell(BOOL force, BOOL eventOnly, DeviceIntPtr kbd, CARD8 percent, void* pCtrl, CARD8 class_, Atom name, WindowPtr pWin, ClientPtr pClient)
{
    xkbBellNotify bn = { 0 };
    int initialized = void;
    XkbSrvInfoPtr xkbi = void;
    XkbInterestPtr interest = void;
    CARD8 id = void;
    CARD16 pitch = void, duration = void;
    Time time = 0;
    XID winID = 0;

    if (!kbd.key || !kbd.key.xkbInfo)
        return;

    xkbi = kbd.key.xkbInfo;

    if ((force || (xkbi.desc.ctrls.enabled_ctrls & XkbAudibleBellMask)) &&
        (!eventOnly)) {
        if (kbd.kbdfeed.BellProc)
            (*kbd.kbdfeed.BellProc) (percent, kbd, cast(void*) pCtrl, class_);
    }
    interest = kbd.xkb_interest;
    if ((!interest) || (force))
        return;

    if (class_ == KbdFeedbackClass) {
        KeybdCtrl* pKeyCtrl = cast(KeybdCtrl*) pCtrl;

        id = pKeyCtrl.id;
        pitch = cast(ushort)pKeyCtrl.bell_pitch;
        duration = cast(ushort)pKeyCtrl.bell_duration;
    }
    else if (class_ == BellFeedbackClass) {
        BellCtrl* pBellCtrl = cast(BellCtrl*) pCtrl;

        id = pBellCtrl.id;
        pitch = cast(ushort)pBellCtrl.pitch;
        duration = cast(ushort)pBellCtrl.duration;
    }
    else
        return;

    initialized = 0;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.bellNotifyMask)) {
            if (!initialized) {
                time = GetTimeInMillis();
                bn.type = cast(ubyte)(cast(ubyte)(XkbEventCode + XkbEventBase));
                bn.xkbType = XkbBellNotify;
                bn.deviceID = cast(ubyte)cast(ubyte)kbd.id;
                bn.bellClass =
                bn.bellID = id;
                bn.percent = percent;
                bn.eventOnly = (eventOnly != 0);
                winID = (pWin ? pWin.drawable.id : None);
                initialized = 1;
            }
            bn.time = cast(uint)time;
            bn.pitch = pitch;
            bn.duration = duration;
            bn.name = cast(uint)name;
            bn.window = cast(uint)winID;
            if (interest.client.swapped) {
                swapl(&bn.time);
                swaps(&bn.pitch);
                swaps(&bn.duration);
                swapl(&bn.name);
                swapl(&bn.window);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)&bn);
        }
        interest = interest.next;
    }
    return;
}

void XkbSendAccessXNotify(DeviceIntPtr kbd, xkbAccessXNotify* pEv)
{
    int initialized = void;
    XkbInterestPtr interest = void;
    Time time = 0;
    CARD16 sk_delay = void, db_delay = void;

    interest = kbd.xkb_interest;
    if (!interest)
        return;

    initialized = 0;
    sk_delay = pEv.slowKeysDelay;
    db_delay = pEv.debounceDelay;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.accessXNotifyMask & (1 << pEv.detail))) {
            if (!initialized) {
                pEv.type = cast(ubyte)(XkbEventCode + XkbEventBase);
                pEv.xkbType = XkbAccessXNotify;
                pEv.deviceID = cast(ubyte)kbd.id;
                pEv.time = time = GetTimeInMillis();
                initialized = 1;
            }
            pEv.time = cast(uint)time;
            pEv.slowKeysDelay = sk_delay;
            pEv.debounceDelay = db_delay;
            if (interest.client.swapped) {
                swapl(&pEv.time);
                swaps(&pEv.slowKeysDelay);
                swaps(&pEv.debounceDelay);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pEv);
        }
        interest = interest.next;
    }
    return;
}

void XkbSendNamesNotify(DeviceIntPtr kbd, xkbNamesNotify* pEv)
{
    int initialized = void;
    XkbInterestPtr interest = void;
    Time time = 0;
    CARD16 changed = void, changedVirtualMods = void;
    CARD32 changedIndicators = void;

    interest = kbd.xkb_interest;
    if (!interest)
        return;

    initialized = 0;
    changed = pEv.changed;
    changedIndicators = pEv.changedIndicators;
    changedVirtualMods = pEv.changedVirtualMods;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.namesNotifyMask & pEv.changed)) {
            if (!initialized) {
                pEv.type = cast(ubyte)(XkbEventCode + XkbEventBase);
                pEv.xkbType = XkbNamesNotify;
                pEv.deviceID = cast(ubyte)kbd.id;
                pEv.time = time = GetTimeInMillis();
                initialized = 1;
            }
            pEv.sequenceNumber = cast(ushort)interest.client.sequence;
            pEv.time = cast(uint)time;
            pEv.changed = changed;
            pEv.changedIndicators = changedIndicators;
            pEv.changedVirtualMods = changedVirtualMods;
            if (interest.client.swapped) {
                swaps(&pEv.sequenceNumber);
                swapl(&pEv.time);
                swaps(&pEv.changed);
                swapl(&pEv.changedIndicators);
                swaps(&pEv.changedVirtualMods);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pEv);
        }
        interest = interest.next;
    }
    return;
}

void XkbSendCompatMapNotify(DeviceIntPtr kbd, xkbCompatMapNotify* pEv)
{
    int initialized = void;
    XkbInterestPtr interest = void;
    Time time = 0;
    CARD16 firstSI = 0, nSI = 0, nTotalSI = 0;

    interest = kbd.xkb_interest;
    if (!interest)
        return;

    initialized = 0;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.compatNotifyMask)) {
            if (!initialized) {
                pEv.type = cast(ubyte)(XkbEventCode + XkbEventBase);
                pEv.xkbType = XkbCompatMapNotify;
                pEv.deviceID = cast(ubyte)kbd.id;
                pEv.time = time = GetTimeInMillis();
                firstSI = pEv.firstSI;
                nSI = pEv.nSI;
                nTotalSI = pEv.nTotalSI;
                initialized = 1;
            }
            pEv.time = cast(uint)time;
            pEv.firstSI = firstSI;
            pEv.nSI = nSI;
            pEv.nTotalSI = nTotalSI;
            if (interest.client.swapped) {
                swapl(&pEv.time);
                swaps(&pEv.firstSI);
                swaps(&pEv.nSI);
                swaps(&pEv.nTotalSI);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pEv);
        }
        interest = interest.next;
    }
    return;
}

void XkbSendActionMessage(DeviceIntPtr kbd, xkbActionMessage* pEv)
{
    int initialized = void;
    XkbSrvInfoPtr xkbi = void;
    XkbInterestPtr interest = void;
    Time time = 0;

    interest = kbd.xkb_interest;
    if (!interest || !kbd.key || !kbd.key.xkbInfo)
        return;

    xkbi = kbd.key.xkbInfo;

    initialized = 0;
    pEv.mods = xkbi.state.mods;
    pEv.group = xkbi.state.group;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.actionMessageMask)) {
            if (!initialized) {
                pEv.type = cast(ubyte)(XkbEventCode + XkbEventBase);
                pEv.xkbType = XkbActionMessage;
                pEv.deviceID = cast(ubyte)kbd.id;
                pEv.time = time = GetTimeInMillis();
                initialized = 1;
            }
            pEv.time = cast(uint)time;
            if (interest.client.swapped) {
                swapl(&pEv.time);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pEv);
        }
        interest = interest.next;
    }
    return;
}

void XkbSendExtensionDeviceNotify(DeviceIntPtr dev, ClientPtr client, xkbExtensionDeviceNotify* pEv)
{
    int initialized = void;
    XkbInterestPtr interest = void;
    Time time = 0;
    CARD32 defined = void, state = void;
    CARD16 reason = void;

    interest = dev.xkb_interest;
    if (!interest)
        return;

    initialized = 0;
    reason = pEv.reason;
    defined = pEv.ledsDefined;
    state = pEv.ledState;
    while (interest) {
        if ((!interest.client.clientGone) &&
            (interest.client.xkbClientFlags & _XkbClientInitialized) &&
            (interest.extDevNotifyMask & reason)) {
            if (!initialized) {
                pEv.type = cast(ubyte)(XkbEventCode + XkbEventBase);
                pEv.xkbType = XkbExtensionDeviceNotify;
                pEv.deviceID = cast(ubyte)dev.id;
                pEv.time = time = GetTimeInMillis();
                initialized = 1;
            }
            else {
                pEv.time = cast(uint)time;
                pEv.ledsDefined = defined;
                pEv.ledState = state;
                pEv.reason = reason;
                pEv.supported = cast(ushort)XkbXI_AllFeaturesMask;
            }
            if (interest.client.swapped) {
                swapl(&pEv.time);
                swapl(&pEv.ledsDefined);
                swapl(&pEv.ledState);
                swaps(&pEv.reason);
                swaps(&pEv.supported);
            }
            xmitClientEvent(interest.client, *cast(xEvent*)pEv);
        }
        interest = interest.next;
    }
    return;
}

void XkbSendNotification(DeviceIntPtr kbd, XkbChangesPtr pChanges, XkbEventCausePtr cause)
{
    XkbSrvLedInfoPtr sli = void;

    sli = null;
    if (pChanges.state_changes) {
        xkbStateNotify sn = {
            changed: pChanges.state_changes,
            keycode: cause.kc,
            eventType: cause.event,
            requestMajor: cause.mjr,
            requestMinor: cause.mnr,
        };
        XkbSendStateNotify(kbd, &sn);
    }
    if (pChanges.map.changed) {
        xkbMapNotify mn = {
            changed: pChanges.map.changed,
            firstType: pChanges.map.first_type,
            nTypes: pChanges.map.num_types,
            firstKeySym: pChanges.map.first_key_sym,
            nKeySyms: pChanges.map.num_key_syms,
            firstKeyAct: pChanges.map.first_key_act,
            nKeyActs: pChanges.map.num_key_acts,
            firstKeyBehavior: pChanges.map.first_key_behavior,
            nKeyBehaviors: pChanges.map.num_key_behaviors,
            virtualMods: pChanges.map.vmods,
            firstKeyExplicit: pChanges.map.first_key_explicit,
            nKeyExplicit: pChanges.map.num_key_explicit,
            firstModMapKey: pChanges.map.first_modmap_key,
            nModMapKeys: pChanges.map.num_modmap_keys,
            firstVModMapKey: pChanges.map.first_vmodmap_key,
            nVModMapKeys: pChanges.map.num_vmodmap_keys,
        };
        XkbSendMapNotify(kbd, &mn);
    }
    if ((pChanges.ctrls.changed_ctrls) ||
        (pChanges.ctrls.enabled_ctrls_changes)) {
        xkbControlsNotify cn = {
            changedControls: pChanges.ctrls.changed_ctrls,
            enabledControlChanges: pChanges.ctrls.enabled_ctrls_changes,
            keycode: cause.kc,
            eventType: cause.event,
            requestMajor: cast(ubyte)cause.mjr,
            requestMinor: cause.mnr
        };
        XkbSendControlsNotify(kbd, &cn);
    }
    if (pChanges.indicators.map_changes) {
        if (sli is null)
            sli = XkbFindSrvLedInfo(kbd, XkbDfltXIClass, XkbDfltXIId, 0);
        xkbIndicatorNotify in_ = {
            state: sli.effectiveState,
            changed: pChanges.indicators.map_changes,
        };
        XkbSendIndicatorNotify(kbd, XkbIndicatorMapNotify, &in_);
    }
    if (pChanges.indicators.state_changes) {
        if (sli is null)
            sli = XkbFindSrvLedInfo(kbd, XkbDfltXIClass, XkbDfltXIId, 0);
        xkbIndicatorNotify in_ = {
            state: sli.effectiveState,
            changed: pChanges.indicators.state_changes
        };
        XkbSendIndicatorNotify(kbd, XkbIndicatorStateNotify, &in_);
    }
    if (pChanges.names.changed) {
        xkbNamesNotify nn = {
            changed: cast(ushort)pChanges.names.changed,
            firstType: pChanges.names.first_type,
            nTypes: pChanges.names.num_types,
            firstLevelName: pChanges.names.first_lvl,
            nLevelNames: pChanges.names.num_lvls,
            nRadioGroups: pChanges.names.num_rg,
            changedVirtualMods: pChanges.names.changed_vmods,
            changedIndicators: cast(uint)pChanges.names.changed_indicators,
        };
        XkbSendNamesNotify(kbd, &nn);
    }
    if ((pChanges.compat.changed_groups) || (pChanges.compat.num_si > 0)) {
        xkbCompatMapNotify cmn = {
            changedGroups: pChanges.compat.changed_groups,
            firstSI: pChanges.compat.first_si,
            nSI: pChanges.compat.num_si,
            nTotalSI: kbd.key.xkbInfo.desc.compat.num_si,
        };
        XkbSendCompatMapNotify(kbd, &cmn);
    }
    return;
}

/***====================================================================***/

void XkbFilterEvents(ClientPtr client, int nEvents, xEvent* xE)
{
    DeviceIntPtr dev = null;
    XkbSrvInfoPtr xkbi = void;
    CARD8 type = xE[0].u.u.type;

    if (xE.u.u.type & EXTENSION_EVENT_BASE)
        dev = XIGetDevice(xE);

    if (!dev)
        dev = PickKeyboard(client);

    if (!dev.key)
        return;

    xkbi = dev.key.xkbInfo;

    if (client.xkbClientFlags & _XkbClientInitialized) {
        if ((xkbDebugFlags & 0x10) &&
            (type == KeyPress || type == KeyRelease ||
             type == DeviceKeyPress || type == DeviceKeyRelease))
            DebugF("[xkb] XkbFilterWriteEvents (XKB client): state 0x%04x\n",
                   xE[0].u.keyButtonPointer.state);

        if (dev.deviceGrab.grab != NullGrab && dev.deviceGrab.fromPassiveGrab
            && (type == KeyPress || type == KeyRelease || type == DeviceKeyPress
                || type == DeviceKeyRelease)) {
            uint state = void, flags = void;

            flags = client.xkbClientFlags;
            state = xkbi.state.compat_grab_mods;
            if (flags & XkbPCF_GrabsUseXKBStateMask) {
                int group = void;

                if (flags & XkbPCF_LookupStateWhenGrabbed) {
                    group = xkbi.state.group;
                    state = xkbi.state.lookup_mods;
                }
                else {
                    state = xkbi.state.grab_mods;
                    group = xkbi.state.base_group + xkbi.state.latched_group;
                    if (group < 0 || group >= xkbi.desc.ctrls.num_groups)
                        group = XkbAdjustGroup(group, xkbi.desc.ctrls);
                }
                state = mixin(XkbBuildCoreState!("state", "group"));
            }
            else if (flags & XkbPCF_LookupStateWhenGrabbed) {
                state = xkbi.state.compat_lookup_mods;
            }
            xE[0].u.keyButtonPointer.state = cast(ushort)state;
        }
    }
    else {
        if ((xkbDebugFlags & 0x4) &&
            (xE[0].u.u.type == KeyPress || xE[0].u.u.type == KeyRelease ||
             xE[0].u.u.type == DeviceKeyPress ||
             xE[0].u.u.type == DeviceKeyRelease)) {
            DebugF("[xkb] XKbFilterWriteEvents (non-XKB):\n");
            DebugF("[xkb] event= 0x%04x\n", xE[0].u.keyButtonPointer.state);
            DebugF("[xkb] lookup= 0x%02x, grab= 0x%02x\n",
                   xkbi.state.lookup_mods, xkbi.state.grab_mods);
            DebugF("[xkb] compat lookup= 0x%02x, grab= 0x%02x\n",
                   xkbi.state.compat_lookup_mods,
                   xkbi.state.compat_grab_mods);
        }
        if (type >= KeyPress && type <= MotionNotify) {
            CARD16 old = void, new_ = void;

            old = xE[0].u.keyButtonPointer.state & ~0x1f00;
            new_ = xE[0].u.keyButtonPointer.state & 0x1F00;

            if (old == mixin(XkbStateFieldFromRec!("&xkbi.state")))
                new_ |= xkbi.state.compat_lookup_mods;
            else
                new_ |= xkbi.state.compat_grab_mods;
            xE[0].u.keyButtonPointer.state = new_;
        }
        else if (type == EnterNotify || type == LeaveNotify) {
            xE[0].u.enterLeave.state &= 0x1F00;
            xE[0].u.enterLeave.state |= xkbi.state.compat_grab_mods;
        }
        else if (type >= DeviceKeyPress && type <= DeviceMotionNotify) {
            CARD16 old = void, new_ = void;
            deviceKeyButtonPointer* kbp = cast(deviceKeyButtonPointer*) &xE[0];

            old = kbp.state & ~0x1F00;
            new_ = kbp.state & 0x1F00;
            if (old == mixin(XkbStateFieldFromRec!("&xkbi.state")))
                new_ |= xkbi.state.compat_lookup_mods;
            else
                new_ |= xkbi.state.compat_grab_mods;
            kbp.state = new_;
        }
    }
}

/***====================================================================***/

XkbInterestPtr XkbFindClientResource(DevicePtr inDev, ClientPtr client)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) inDev;
    XkbInterestPtr interest = void;

    if (dev.xkb_interest) {
        interest = dev.xkb_interest;
        while (interest) {
            if (interest.client == client) {
                return interest;
            }
            interest = interest.next;
        }
    }
    return null;
}

XkbInterestPtr XkbAddClientResource(DevicePtr inDev, ClientPtr client, XID id)
{
    DeviceIntPtr dev = cast(DeviceIntPtr) inDev;
    XkbInterestPtr interest = void;

    interest = dev.xkb_interest;
    while (interest) {
        if (interest.client == client)
            return ((interest.resource == id) ? interest : null);
        interest = interest.next;
    }
    interest = cast(XkbInterestRec*) calloc(1, XkbInterestRec.sizeof);
    if (interest) {
        interest.dev = dev;
        interest.client = client;
        interest.resource = id;
        interest.next = dev.xkb_interest;
        dev.xkb_interest = interest;
        return interest;
    }
    return null;
}

int XkbRemoveResourceClient(DevicePtr inDev, XID id)
{
    XkbSrvInfoPtr xkbi = void;
    DeviceIntPtr dev = cast(DeviceIntPtr) inDev;
    XkbInterestPtr interest = void;
    Bool found = void;
    c_ulong autoCtrls = void, autoValues = void;
    ClientPtr client = null;

    found = FALSE;

    if (!dev.key || !dev.key.xkbInfo)
        return found;

    autoCtrls = autoValues = 0;
    if (dev.xkb_interest) {
        interest = dev.xkb_interest;
        if (interest && (interest.resource == id)) {
            dev.xkb_interest = interest.next;
            autoCtrls = interest.autoCtrls;
            autoValues = interest.autoCtrlValues;
            client = interest.client;
            FreeResource(cast(uint)interest.resource, RT_XKBCLIENT);
            free(interest);
            found = TRUE;
        }
        while ((!found) && (interest.next)) {
            if (interest.next.resource == id) {
                XkbInterestPtr victim = interest.next;

                interest.next = victim.next;
                autoCtrls = victim.autoCtrls;
                autoValues = victim.autoCtrlValues;
                client = victim.client;
                FreeResource(cast(uint)victim.resource, RT_XKBCLIENT);
                free(victim);
                found = TRUE;
            }
            interest = interest.next;
        }
    }
    if (found && autoCtrls && dev.key && dev.key.xkbInfo) {
        XkbEventCauseRec cause = { 0 };

        xkbi = dev.key.xkbInfo;
        mixin(XkbSetCauseXkbReq!("&cause", "X_kbPerClientFlags", "client"));
        XkbEnableDisableControls(xkbi, autoCtrls, autoValues, null, &cause);
    }
    return found;
}
