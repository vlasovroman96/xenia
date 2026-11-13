module randr.rrmode;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2006 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */
import build.dix_config;

import dix.dix_priv;
import dix.request_priv;
import randr.randrstr_priv;
import randr.rrdispatch_priv;
import randr.rrcrtc;
import dix.resource;
import randr.rroutput;
import randr.rrmode;
import randr.rroutput;
import randr.rroutput;
import os.io;
import dix.events;
import dix.pixmap;
import randr.rrproperty;
import render.filter;
import dix.swapreq;
import randr.rrmode;
import common.bytes;

RESTYPE RRModeType;

private Bool RRModeEqual(xRRModeInfo* a, xRRModeInfo* b)
{
    if (a.width != b.width)
        return FALSE;
    if (a.height != b.height)
        return FALSE;
    if (a.dotClock != b.dotClock)
        return FALSE;
    if (a.hSyncStart != b.hSyncStart)
        return FALSE;
    if (a.hSyncEnd != b.hSyncEnd)
        return FALSE;
    if (a.hTotal != b.hTotal)
        return FALSE;
    if (a.hSkew != b.hSkew)
        return FALSE;
    if (a.vSyncStart != b.vSyncStart)
        return FALSE;
    if (a.vSyncEnd != b.vSyncEnd)
        return FALSE;
    if (a.vTotal != b.vTotal)
        return FALSE;
    if (a.nameLength != b.nameLength)
        return FALSE;
    if (a.modeFlags != b.modeFlags)
        return FALSE;
    return TRUE;
}

/*
 * Keep a list so it's easy to find modes in the resource database.
 */
private int num_modes;
private RRModePtr* modes;

private RRModePtr RRModeCreate(xRRModeInfo* modeInfo, const(char)* name, ScreenPtr userScreen)
{
    RRModePtr mode = void; RRModePtr* newModes = void;

    if (!RRInit())
        return null;

    mode = cast(RRModePtr)calloc(1, ((RRModeRec).sizeof + modeInfo.nameLength + 1));
    if (!mode)
        return null;
    mode.refcnt = 1;
    mode.mode = *modeInfo;
    mode.name = cast(char*) (mode + 1);
    memcpy(mode.name, name, modeInfo.nameLength);
    mode.name[modeInfo.nameLength] = '\0';
    mode.userScreen = userScreen;

    if (num_modes)
        newModes = cast(RRModePtr*) reallocarray(modes, num_modes + 1, RRModePtr.sizeof);
    else
        newModes = cast(RRModePtr*) cast(RRModePtr*) calloc(1, RRModePtr.sizeof);

    if (!newModes) {
        free(mode);
        return null;
    }

    mode.mode.id = cast(uint)dixAllocServerXID();
    if (!AddResource(cast(uint)mode.mode.id, RRModeType, cast(void*) mode)) {
        free(newModes);
        return null;
    }
    modes = newModes;
    modes[num_modes++] = mode;

    /*
     * give the caller a reference to this mode
     */
    ++mode.refcnt;
    return mode;
}

private RRModePtr RRModeFindByName(const(char)* name, CARD16 nameLength)
{
    int i = void;
    RRModePtr mode = void;

    for (i = 0; i < num_modes; i++) {
        mode = modes[i];
        if (mode.mode.nameLength == nameLength &&
            !memcmp(name, mode.name, nameLength)) {
            return mode;
        }
    }
    return null;
}

RRModePtr RRModeGet(xRRModeInfo* modeInfo, const(char)* name)
{
    int i = void;

    for (i = 0; i < num_modes; i++) {
        RRModePtr mode = modes[i];

        if (RRModeEqual(&mode.mode, modeInfo) &&
            !memcmp(name, mode.name, modeInfo.nameLength)) {
            ++mode.refcnt;
            return mode;
        }
    }

    return RRModeCreate(modeInfo, name, null);
}

private RRModePtr RRModeCreateUser(ScreenPtr pScreen, xRRModeInfo* modeInfo, const(char)* name, int* error)
{
    RRModePtr mode = void;

    mode = RRModeFindByName(name, modeInfo.nameLength);
    if (mode) {
        *error = BadName;
        return null;
    }

    mode = RRModeCreate(modeInfo, name, pScreen);
    if (!mode) {
        *error = BadAlloc;
        return null;
    }
    *error = Success;
    return mode;
}

RRModePtr* RRModesForScreen(ScreenPtr pScreen, int* num_ret)
{
    mixin(rrScrPriv!("pScreen"));
    int o = void, c = void, m = void;
    RRModePtr* screen_modes = void;
    int num_screen_modes = 0;

    screen_modes = cast(RRModePtr*) calloc((num_modes ? num_modes : 1), RRModePtr.sizeof);
    if (!screen_modes)
        return null;

    /*
     * Add modes from all outputs
     */
    for (o = 0; o < pScrPriv.numOutputs; o++) {
        RROutputPtr output = pScrPriv.outputs[o];
        int n = void;

        for (m = 0; m < output.numModes + output.numUserModes; m++) {
            RRModePtr mode = (m < output.numModes ?
                              output.modes[m] :
                              output.userModes[m - output.numModes]);
            for (n = 0; n < num_screen_modes; n++)
                if (screen_modes[n] == mode)
                    break;
            if (n == num_screen_modes)
                screen_modes[num_screen_modes++] = mode;
        }
    }
    /*
     * Add modes from all crtcs. The goal is to
     * make sure all available and active modes
     * are visible to the client
     */
    for (c = 0; c < pScrPriv.numCrtcs; c++) {
        RRCrtcPtr crtc = pScrPriv.crtcs[c];
        RRModePtr mode = crtc.mode;
        int n = void;

        if (!mode)
            continue;
        for (n = 0; n < num_screen_modes; n++)
            if (screen_modes[n] == mode)
                break;
        if (n == num_screen_modes)
            screen_modes[num_screen_modes++] = mode;
    }
    /*
     * Add all user modes for this screen
     */
    for (m = 0; m < num_modes; m++) {
        RRModePtr mode = modes[m];
        int n = void;

        if (mode.userScreen != pScreen)
            continue;
        for (n = 0; n < num_screen_modes; n++)
            if (screen_modes[n] == mode)
                break;
        if (n == num_screen_modes)
            screen_modes[num_screen_modes++] = mode;
    }

    *num_ret = num_screen_modes;
    return screen_modes;
}

void RRModeDestroy(RRModePtr mode)
{
    int m = void;

    if (--mode.refcnt > 0)
        return;
    for (m = 0; m < num_modes; m++) {
        if (modes[m] == mode) {
            memmove(modes + m, modes + m + 1,
                    (num_modes - m - 1) * RRModePtr.sizeof);
            num_modes--;
            if (!num_modes) {
                free(modes);
                modes = null;
            }
            break;
        }
    }

    free(mode);
}

private int RRModeDestroyResource(void* value, XID pid)
{
    RRModeDestroy(cast(RRModePtr) value);
    return 1;
}

/*
 * Initialize mode type
 */
Bool RRModeInit()
{
    assert(num_modes == 0);
    assert(modes is null);
    RRModeType = CreateNewResourceType(&RRModeDestroyResource, "MODE");
    if (!RRModeType)
        return FALSE;

    return TRUE;
}

/*
 * Initialize mode type error value
 */
void RRModeInitErrorValue()
{
    SetResourceTypeErrorValue(RRModeType, RRErrorBase + BadRRMode);
}

int ProcRRCreateMode(ClientPtr client)
{
    mixin(REQUEST!xRRCreateModeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRCreateModeReq);

    if (client.swapped) {
        swapl(&stuff.window);
        xRRModeInfo* modeinfo = &stuff.modeInfo;
        swapl(&modeinfo.id);
        swaps(&modeinfo.width);
        swaps(&modeinfo.height);
        swapl(&modeinfo.dotClock);
        swaps(&modeinfo.hSyncStart);
        swaps(&modeinfo.hSyncEnd);
        swaps(&modeinfo.hTotal);
        swaps(&modeinfo.hSkew);
        swaps(&modeinfo.vSyncStart);
        swaps(&modeinfo.vSyncEnd);
        swaps(&modeinfo.vTotal);
        swaps(&modeinfo.nameLength);
        swapl(&modeinfo.modeFlags);
    }

    WindowPtr pWin = void;
    ScreenPtr pScreen = void;
    xRRModeInfo* modeInfo = void;
    c_long units_after = void;
    char* name = void;
    int error = void, rc = void;
    RRModePtr mode = void;

    rc = dixLookupWindow(&pWin, stuff.window, client, DixGetAttrAccess);
    if (rc != Success)
        return rc;

    pScreen = pWin.drawable.pScreen;

    modeInfo = &stuff.modeInfo;
    name = cast(char*) (stuff + 1);
    units_after = (client.req_len - int32ForBytes(xRRCreateModeReq.sizeof));

    /* check to make sure requested name fits within the data provided */
    if (int32ForBytes(modeInfo.nameLength) > units_after)
        return BadLength;

    mode = RRModeCreateUser(pScreen, modeInfo, name, &error);
    if (!mode)
        return error;

    xRRCreateModeReply reply = {
        mode: mode.mode.id
    };

    /* Drop out reference to this mode */
    RRModeDestroy(mode);

    if (client.swapped) {
        swapl(&reply.mode);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int ProcRRDestroyMode(ClientPtr client)
{
    mixin(REQUEST!xRRDestroyModeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRDestroyModeReq);

    if (client.swapped)
        swapl(&stuff.mode);

    RRModePtr mode = void;
    mixin(VERIFY_RR_MODE!("stuff.mode", "mode", "DixDestroyAccess"));

    if (!mode.userScreen)
        return BadMatch;
    if (mode.refcnt > 1)
        return BadAccess;
    FreeResource(cast(uint)stuff.mode, 0);
    return Success;
}

int ProcRRAddOutputMode(ClientPtr client)
{
    mixin(REQUEST!xRRAddOutputModeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRAddOutputModeReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.mode);
    }

    RROutputPtr output = void;
    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));

    RRModePtr mode = void;
    mixin(VERIFY_RR_MODE!("stuff.mode", "mode", "DixUseAccess"));

    if (RROutputIsLeased(output))
        return BadAccess;

    return RROutputAddUserMode(output, mode);
}

int ProcRRDeleteOutputMode(ClientPtr client)
{
    mixin(REQUEST!xRRDeleteOutputModeReq);
    mixin(REQUEST_AT_LEAST_SIZE!xRRDeleteOutputModeReq);

    if (client.swapped) {
        swapl(&stuff.output);
        swapl(&stuff.mode);
    }

    RROutputPtr output = void;
    mixin(VERIFY_RR_OUTPUT!("stuff.output", "output", "DixReadAccess"));

    RRModePtr mode = void;
    mixin(VERIFY_RR_MODE!("stuff.mode", "mode", "DixUseAccess"));

    if (RROutputIsLeased(output))
        return BadAccess;

    return RROutputDeleteUserMode(output, mode);
}
