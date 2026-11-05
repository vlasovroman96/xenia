module hw.xfree86.xext.vidmode;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1995  Kaleb S. KEITHLEY

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
"Software"), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL Kaleb S. KEITHLEY BE LIABLE FOR ANY CLAIM, DAMAGES
OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of Kaleb S. KEITHLEY
shall not be used in advertising or otherwise to promote the sale, use
or other dealings in this Software without prior written authorization
from Kaleb S. KEITHLEY

*/
/* THIS IS NOT AN X CONSORTIUM STANDARD OR AN X PROJECT TEAM SPECIFICATION */

import build.dix_config;
import build.xlibre_server;

static if(XF86VIDMODE){

//import x11.X;
//import x11.Xproto;
import externs.X11.extensions.xf86vmproto;

import dix.dix_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.swapreq;

import dix.screenint_priv;
import os.log_priv;
import os.osdep;

import common.misc;
import dix.dixstruct_priv;
import include.scrnintstr;
import include.servermd;
import include.vidmodestr;
import common.protocol_versions;
import dix.extension;
private int VidModeErrorBase;
private int VidModeAllowNonLocal;

private DevPrivateKeyRec VidModeClientPrivateKeyRec;
enum VidModeClientPrivateKey = (&VidModeClientPrivateKeyRec);

private DevPrivateKeyRec VidModePrivateKeyRec;
enum VidModePrivateKey = (&VidModePrivateKeyRec);

/* This holds the client's version information */
struct _VidModePrivRec {
    int major;
    int minor;
}alias VidModePrivRec = _VidModePrivRec;
alias VidModePrivPtr = VidModePrivRec*;

enum string VM_GETPRIV(string c) = `(cast(VidModePrivPtr) 
    dixLookupPrivate(&(` ~ c ~ `).devPrivates, VidModeClientPrivateKey))`;
enum string VM_SETPRIV(string c,string p) = `
    dixSetPrivate(&(` ~ c ~ `).devPrivates, VidModeClientPrivateKey, ` ~ p ~ `);`;

version (DEBUG) {
enum string DEBUG_P(string x) = `DebugF(x"\n")`;
} else {
//#define DEBUG_P(x) /**/
}

private DisplayModePtr VidModeCreateMode()
{
    DisplayModePtr mode = cast(DisplayModeRec*) calloc(1, DisplayModeRec.sizeof);
    if (mode !is null) {
        mode.name = "";
        mode.VScan = 1;        /* divides refresh rate. default = 1 */
        mode.Private = null;
        mode.next = mode;
        mode.prev = mode;
    }
    return mode;
}

private void VidModeCopyMode(DisplayModePtr modefrom, DisplayModePtr modeto)
{
    memcpy(modeto, modefrom, DisplayModeRec.sizeof);
}

private int VidModeGetModeValue(DisplayModePtr mode, int valtyp)
{
    int ret = 0;

    switch (valtyp) {
    case VIDMODE_H_DISPLAY:
        ret = mode.HDisplay;
        break;
    case VIDMODE_H_SYNCSTART:
        ret = mode.HSyncStart;
        break;
    case VIDMODE_H_SYNCEND:
        ret = mode.HSyncEnd;
        break;
    case VIDMODE_H_TOTAL:
        ret = mode.HTotal;
        break;
    case VIDMODE_H_SKEW:
        ret = mode.HSkew;
        break;
    case VIDMODE_V_DISPLAY:
        ret = mode.VDisplay;
        break;
    case VIDMODE_V_SYNCSTART:
        ret = mode.VSyncStart;
        break;
    case VIDMODE_V_SYNCEND:
        ret = mode.VSyncEnd;
        break;
    case VIDMODE_V_TOTAL:
        ret = mode.VTotal;
        break;
    case VIDMODE_FLAGS:
        ret = mode.Flags;
        break;
    case VIDMODE_CLOCK:
        ret = mode.Clock;
        break;
    default: break;}
    return ret;
}

private void VidModeSetModeValue(DisplayModePtr mode, int valtyp, int val)
{
    switch (valtyp) {
    case VIDMODE_H_DISPLAY:
        mode.HDisplay = val;
        break;
    case VIDMODE_H_SYNCSTART:
        mode.HSyncStart = val;
        break;
    case VIDMODE_H_SYNCEND:
        mode.HSyncEnd = val;
        break;
    case VIDMODE_H_TOTAL:
        mode.HTotal = val;
        break;
    case VIDMODE_H_SKEW:
        mode.HSkew = val;
        break;
    case VIDMODE_V_DISPLAY:
        mode.VDisplay = val;
        break;
    case VIDMODE_V_SYNCSTART:
        mode.VSyncStart = val;
        break;
    case VIDMODE_V_SYNCEND:
        mode.VSyncEnd = val;
        break;
    case VIDMODE_V_TOTAL:
        mode.VTotal = val;
        break;
    case VIDMODE_FLAGS:
        mode.Flags = val;
        break;
    case VIDMODE_CLOCK:
        mode.Clock = val;
        break;
    default: break;}
    return;
}

private int ClientMajorVersion(ClientPtr client)
{
    VidModePrivPtr pPriv = void;

    pPriv = mixin(VM_GETPRIV!(`client`));
    if (!pPriv)
        return 0;
    else
        return pPriv.major;
}

private int ProcVidModeQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeQueryVersionReq);

    // DEBUG_P("XF86VidModeQueryVersion");

    xXF86VidModeQueryVersionReply reply = {
        majorVersion: SERVER_XF86VIDMODE_MAJOR_VERSION,
        minorVersion: SERVER_XF86VIDMODE_MINOR_VERSION
    };

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcVidModeGetModeLine(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetModeLineReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    VidModePtr pVidMode = void;
    DisplayModePtr mode = void;
    int dotClock = void;
    int ver = void;

    // DEBUG_P("XF86VidModeGetModeline");

    ver = ClientMajorVersion(client);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.GetCurrentModeline(pScreen, &mode, &dotClock))
        return BadValue;

    xXF86VidModeGetModeLineReply reply = {
        dotclock: dotClock,
        hdisplay: cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_DISPLAY),
        hsyncstart: cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_SYNCSTART),
        hsyncend: cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_SYNCEND),
        htotal: cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_TOTAL),
        hskew: cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_SKEW),
        vdisplay: cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_DISPLAY),
        vsyncstart: cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_SYNCSTART),
        vsyncend: cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_SYNCEND),
        vtotal: cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_TOTAL),
        flags: VidModeGetModeValue(mode, VIDMODE_FLAGS),
        /*
         * Older servers sometimes had server privates that the VidMode
         * extension made available. So to be compatible pretend that
         * there are no server privates to pass to the client.
         */
        privsize: 0,
    };

    DebugF("GetModeLine - scrn: %d clock: %ld\n",
           stuff.screen, cast(c_ulong) reply.dotclock);
    DebugF("GetModeLine - hdsp: %d hbeg: %d hend: %d httl: %d\n",
           reply.hdisplay, reply.hsyncstart, reply.hsyncend, reply.htotal);
    DebugF("              vdsp: %d vbeg: %d vend: %d vttl: %d flags: %ld\n",
           reply.vdisplay, reply.vsyncstart, reply.vsyncend,
           reply.vtotal, cast(c_ulong) reply.flags);

    mixin(X_REPLY_FIELD_CARD32!"dotclock");
    mixin(X_REPLY_FIELD_CARD16!"hdisplay");
    mixin(X_REPLY_FIELD_CARD16!"hsyncstart");
    mixin(X_REPLY_FIELD_CARD16!"hsyncend");
    mixin(X_REPLY_FIELD_CARD16!"htotal");
    mixin(X_REPLY_FIELD_CARD16!"hskew");
    mixin(X_REPLY_FIELD_CARD16!"vdisplay");
    mixin(X_REPLY_FIELD_CARD16!"vsyncstart");
    mixin(X_REPLY_FIELD_CARD16!"vsyncend");
    mixin(X_REPLY_FIELD_CARD16!"vtotal");
    mixin(X_REPLY_FIELD_CARD32!"flags");
    mixin(X_REPLY_FIELD_CARD32!"privsize");

    if (ver < 2) {
        xXF86OldVidModeGetModeLineReply oldrep = {
            dotclock: reply.dotclock,
            hdisplay: reply.hdisplay,
            hsyncstart: reply.hsyncstart,
            hsyncend: reply.hsyncend,
            htotal: reply.htotal,
            vdisplay: reply.vdisplay,
            vsyncstart: reply.vsyncstart,
            vsyncend: reply.vsyncend,
            vtotal: reply.vtotal,
            flags: reply.flags,
            privsize: reply.privsize
        };
        return mixin(X_SEND_REPLY_SIMPLE!("client", "oldrep"));
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private void fillModeInfoV1(x_rpcbuf_t* rpcbuf, int dotClock, DisplayModePtr mode)
{
    /* 0.x version -- xXF86OldVidModeModeInfo */
    x_rpcbuf_write_CARD32(rpcbuf, dotClock);
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_DISPLAY));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_SYNCSTART));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_SYNCEND));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_TOTAL));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_DISPLAY));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_SYNCSTART));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_SYNCEND));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_TOTAL));
    x_rpcbuf_write_CARD32(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_FLAGS));
    x_rpcbuf_reserve0(rpcbuf, CARD32.sizeof); /* unused ? */
}

private void fillModeInfoV2(x_rpcbuf_t* rpcbuf, int dotClock, DisplayModePtr mode)
{
    /* xXF86VidModeModeInfo -- v2 */
    x_rpcbuf_write_CARD32(rpcbuf, dotClock);
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_DISPLAY));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_SYNCSTART));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_SYNCEND));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_H_TOTAL));
    x_rpcbuf_write_CARD32(rpcbuf, VidModeGetModeValue(mode, VIDMODE_H_SKEW));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_DISPLAY));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_SYNCSTART));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_SYNCEND));
    x_rpcbuf_write_CARD16(rpcbuf, cast(ushort)VidModeGetModeValue(mode, VIDMODE_V_TOTAL));
    x_rpcbuf_reserve0(rpcbuf, CARD32.sizeof); /* pad1 */
    x_rpcbuf_write_CARD32(rpcbuf, VidModeGetModeValue(mode, VIDMODE_FLAGS));
    x_rpcbuf_reserve0(rpcbuf, ((CARD32).sizeof * 4)); /* reserved[1,2,3], privsize */
}

private int ProcVidModeGetAllModeLines(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetAllModeLinesReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    VidModePtr pVidMode = void;
    DisplayModePtr mode = void;
    int modecount = void, dotClock = void;
    int ver = void;

    // DEBUG_P("XF86VidModeGetAllModelines");

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    ver = ClientMajorVersion(client);
    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    modecount = pVidMode.GetNumOfModes(pScreen);
    if (modecount < 1)
        return VidModeErrorBase + XF86VidModeExtensionDisabled;

    if (!pVidMode.GetFirstModeline(pScreen, &mode, &dotClock))
        return BadValue;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    do {
        if (ver < 2)
            fillModeInfoV1(&rpcbuf, dotClock, mode);
        else
            fillModeInfoV2(&rpcbuf, dotClock, mode);
    } while (pVidMode.GetNextModeline(pScreen, &mode, &dotClock));

    xXF86VidModeGetAllModeLinesReply reply = {
        modecount: modecount
    };

    mixin(X_REPLY_FIELD_CARD32!"modecount");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

enum string MODEMATCH(string mode,string stuff) = `
     (VidModeGetModeValue(` ~ mode ~ `, VIDMODE_H_DISPLAY)  == ` ~ stuff ~ `.hdisplay 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_H_SYNCSTART)  == ` ~ stuff ~ `.hsyncstart 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_H_SYNCEND)  == ` ~ stuff ~ `.hsyncend 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_H_TOTAL)  == ` ~ stuff ~ `.htotal 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_V_DISPLAY)  == ` ~ stuff ~ `.vdisplay 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_V_SYNCSTART)  == ` ~ stuff ~ `.vsyncstart 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_V_SYNCEND)  == ` ~ stuff ~ `.vsyncend 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_V_TOTAL)  == ` ~ stuff ~ `.vtotal 
     && VidModeGetModeValue(` ~ mode ~ `, VIDMODE_FLAGS)  == ` ~ stuff ~ `.flags )`;



private int ProcVidModeAddModeLine(ClientPtr client)
{
    int len = void;

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    // DEBUG_P("XF86VidModeAddModeline");

    if (ClientMajorVersion(client) < 2) {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86OldVidModeAddModeLineReq);
        len =
            cast(int)(client.req_len -
            bytes_to_int32(xXF86OldVidModeAddModeLineReq.sizeof));

        mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        if (len != stuff.privsize)
            return BadLength;

        xXF86VidModeAddModeLineReq newstuff = {
            length: cast(ushort)client.req_len,
            screen: stuff.screen,
            dotclock: stuff.dotclock,
            hdisplay: stuff.hdisplay,
            hsyncstart: stuff.hsyncstart,
            hsyncend: stuff.hsyncend,
            htotal: stuff.htotal,
            hskew: 0,
            vdisplay: stuff.vdisplay,
            vsyncstart: stuff.vsyncstart,
            vsyncend: stuff.vsyncend,
            vtotal: stuff.vtotal,
            flags: stuff.flags,
            privsize: stuff.privsize,
            after_dotclock: stuff.after_dotclock,
            after_hdisplay: stuff.after_hdisplay,
            after_hsyncstart: stuff.after_hsyncstart,
            after_hsyncend: stuff.after_hsyncend,
            after_htotal: stuff.after_htotal,
            after_hskew: 0,
            after_vdisplay: stuff.after_vdisplay,
            after_vsyncstart: stuff.after_vsyncstart,
            after_vsyncend: stuff.after_vsyncend,
            after_vtotal: stuff.after_vtotal,
            after_flags: stuff.after_flags,
        };
        return VidModeAddModeLine(client, &newstuff);
    }
    else {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86VidModeAddModeLineReq);
        len =
            cast(int)(client.req_len -
            bytes_to_int32(xXF86VidModeAddModeLineReq.sizeof));

        mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"hskew");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        if (len != stuff.privsize)
            return BadLength;

        return VidModeAddModeLine(client, stuff);
    }
}

private int VidModeAddModeLine(ClientPtr client, xXF86VidModeAddModeLineReq* stuff)
{
    DisplayModePtr mode = void;
    VidModePtr pVidMode = void;
    int dotClock = void;

    DebugF("AddModeLine - scrn: %d clock: %ld\n",
           cast(int) stuff.screen, cast(c_ulong) stuff.dotclock);
    DebugF("AddModeLine - hdsp: %d hbeg: %d hend: %d httl: %d\n",
           stuff.hdisplay, stuff.hsyncstart,
           stuff.hsyncend, stuff.htotal);
    DebugF("              vdsp: %d vbeg: %d vend: %d vttl: %d flags: %ld\n",
           stuff.vdisplay, stuff.vsyncstart, stuff.vsyncend,
           stuff.vtotal, cast(c_ulong) stuff.flags);
    DebugF("      after - scrn: %d clock: %ld\n",
           cast(int) stuff.screen, cast(c_ulong) stuff.after_dotclock);
    DebugF("              hdsp: %d hbeg: %d hend: %d httl: %d\n",
           stuff.after_hdisplay, stuff.after_hsyncstart,
           stuff.after_hsyncend, stuff.after_htotal);
    DebugF("              vdsp: %d vbeg: %d vend: %d vttl: %d flags: %ld\n",
           stuff.after_vdisplay, stuff.after_vsyncstart,
           stuff.after_vsyncend, stuff.after_vtotal,
           cast(c_ulong) stuff.after_flags);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    if (stuff.hsyncstart < stuff.hdisplay ||
        stuff.hsyncend < stuff.hsyncstart ||
        stuff.htotal < stuff.hsyncend ||
        stuff.vsyncstart < stuff.vdisplay ||
        stuff.vsyncend < stuff.vsyncstart || stuff.vtotal < stuff.vsyncend)
        return BadValue;

    if (stuff.after_hsyncstart < stuff.after_hdisplay ||
        stuff.after_hsyncend < stuff.after_hsyncstart ||
        stuff.after_htotal < stuff.after_hsyncend ||
        stuff.after_vsyncstart < stuff.after_vdisplay ||
        stuff.after_vsyncend < stuff.after_vsyncstart ||
        stuff.after_vtotal < stuff.after_vsyncend)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (stuff.after_htotal != 0 || stuff.after_vtotal != 0) {
        Bool found = FALSE;

        if (pVidMode.GetFirstModeline(pScreen, &mode, &dotClock)) {
            do {
                if ((pVidMode.GetDotClock(pScreen, cast(int)stuff.dotclock)
                     == dotClock) && mixin(MODEMATCH!(`mode`, `stuff`))) {
                    found = TRUE;
                    break;
                }
            } while (pVidMode.GetNextModeline(pScreen, &mode, &dotClock));
        }
        if (!found)
            return BadValue;
    }

    mode = VidModeCreateMode();
    if (mode is null)
        return BadValue;

    VidModeSetModeValue(mode, VIDMODE_CLOCK, cast(int)stuff.dotclock);
    VidModeSetModeValue(mode, VIDMODE_H_DISPLAY, cast(int)stuff.hdisplay);
    VidModeSetModeValue(mode, VIDMODE_H_SYNCSTART, cast(int)stuff.hsyncstart);
    VidModeSetModeValue(mode, VIDMODE_H_SYNCEND, cast(int)stuff.hsyncend);
    VidModeSetModeValue(mode, VIDMODE_H_TOTAL, cast(int)stuff.htotal);
    VidModeSetModeValue(mode, VIDMODE_H_SKEW, cast(int)stuff.hskew);
    VidModeSetModeValue(mode, VIDMODE_V_DISPLAY, cast(int)stuff.vdisplay);
    VidModeSetModeValue(mode, VIDMODE_V_SYNCSTART, cast(int)stuff.vsyncstart);
    VidModeSetModeValue(mode, VIDMODE_V_SYNCEND, cast(int)stuff.vsyncend);
    VidModeSetModeValue(mode, VIDMODE_V_TOTAL, cast(int)stuff.vtotal);
    VidModeSetModeValue(mode, VIDMODE_FLAGS, cast(int)stuff.flags);

    if (stuff.privsize)
        DebugF("AddModeLine - Privates in request have been ignored\n");

    /* Check that the mode is consistent with the monitor specs */
    switch (pVidMode.CheckModeForMonitor(pScreen, mode)) {
    case MODE_OK:
        break;
    case MODE_HSYNC:
    case MODE_H_ILLEGAL:
        free(mode);
        return VidModeErrorBase + XF86VidModeBadHTimings;
    case MODE_VSYNC:
    case MODE_V_ILLEGAL:
        free(mode);
        return VidModeErrorBase + XF86VidModeBadVTimings;
    default:
        free(mode);
        return VidModeErrorBase + XF86VidModeModeUnsuitable;
    }

    /* Check that the driver is happy with the mode */
    if (pVidMode.CheckModeForDriver(pScreen, mode) != MODE_OK) {
        free(mode);
        return VidModeErrorBase + XF86VidModeModeUnsuitable;
    }

    pVidMode.SetCrtcForMode(pScreen, mode);

    pVidMode.AddModeline(pScreen, mode);

    DebugF("AddModeLine - Succeeded\n");

    return Success;
}



private int ProcVidModeDeleteModeLine(ClientPtr client)
{
    int len = void;

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    // DEBUG_P("XF86VidModeDeleteModeline");

    if (ClientMajorVersion(client) < 2) {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86OldVidModeDeleteModeLineReq);
        mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        len =
            cast(int)(client.req_len -
            bytes_to_int32(xXF86OldVidModeDeleteModeLineReq.sizeof));
        if (len != stuff.privsize) {
            DebugF("req_len = %ld, sizeof(Req) = %d, privsize = %ld, "
                   ~ "len = %d, length = %d\n",
                   cast(c_ulong) client.req_len,
                   cast(int) xXF86VidModeDeleteModeLineReq.sizeof >> 2,
                   cast(c_ulong) stuff.privsize, len, client.req_len);
            return BadLength;
        }

        /* convert from old format */
        xXF86VidModeDeleteModeLineReq newstuff = {
            length: cast(ushort)client.req_len,
            screen: stuff.screen,
            dotclock: stuff.dotclock,
            hdisplay: stuff.hdisplay,
            hsyncstart: stuff.hsyncstart,
            hsyncend: stuff.hsyncend,
            htotal: stuff.htotal,
            hskew: 0,
            vdisplay: stuff.vdisplay,
            vsyncstart: stuff.vsyncstart,
            vsyncend: stuff.vsyncend,
            vtotal: stuff.vtotal,
            flags: stuff.flags,
            privsize: stuff.privsize,
        };
        return VidModeDeleteModeLine(client, &newstuff);
    }
    else {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86VidModeDeleteModeLineReq);
        mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"hskew");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        len =
            cast(int)(client.req_len -
            bytes_to_int32(xXF86VidModeDeleteModeLineReq.sizeof));
        if (len != stuff.privsize) {
            DebugF("req_len = %ld, sizeof(Req) = %d, privsize = %ld, "
                   ~ "len = %d, length = %d\n",
                   cast(c_ulong) client.req_len,
                   cast(int) xXF86VidModeDeleteModeLineReq.sizeof >> 2,
                   cast(c_ulong) stuff.privsize, len, client.req_len);
            return BadLength;
        }
        return VidModeDeleteModeLine(client, stuff);
    }
}

private int VidModeDeleteModeLine(ClientPtr client, xXF86VidModeDeleteModeLineReq* stuff)
{
    int dotClock = void;
    DisplayModePtr mode = void;
    VidModePtr pVidMode = void;

    DebugF("DeleteModeLine - scrn: %d clock: %ld\n",
           cast(int) stuff.screen, cast(c_ulong) stuff.dotclock);
    DebugF("                 hdsp: %d hbeg: %d hend: %d httl: %d\n",
           stuff.hdisplay, stuff.hsyncstart,
           stuff.hsyncend, stuff.htotal);
    DebugF("                 vdsp: %d vbeg: %d vend: %d vttl: %d flags: %ld\n",
           stuff.vdisplay, stuff.vsyncstart, stuff.vsyncend, stuff.vtotal,
           cast(c_ulong) stuff.flags);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.GetCurrentModeline(pScreen, &mode, &dotClock))
        return BadValue;

    DebugF("Checking against clock: %d (%d)\n",
           VidModeGetModeValue(mode, VIDMODE_CLOCK), dotClock);
    DebugF("                 hdsp: %d hbeg: %d hend: %d httl: %d\n",
           VidModeGetModeValue(mode, VIDMODE_H_DISPLAY),
           VidModeGetModeValue(mode, VIDMODE_H_SYNCSTART),
           VidModeGetModeValue(mode, VIDMODE_H_SYNCEND),
           VidModeGetModeValue(mode, VIDMODE_H_TOTAL));
    DebugF("                 vdsp: %d vbeg: %d vend: %d vttl: %d flags: %d\n",
           VidModeGetModeValue(mode, VIDMODE_V_DISPLAY),
           VidModeGetModeValue(mode, VIDMODE_V_SYNCSTART),
           VidModeGetModeValue(mode, VIDMODE_V_SYNCEND),
           VidModeGetModeValue(mode, VIDMODE_V_TOTAL),
           VidModeGetModeValue(mode, VIDMODE_FLAGS));

    if ((pVidMode.GetDotClock(pScreen, cast(int)stuff.dotclock) == dotClock) &&
        mixin(MODEMATCH!(`mode`, `stuff`)))
        return BadValue;

    if (!pVidMode.GetFirstModeline(pScreen, &mode, &dotClock))
        return BadValue;

    do {
        DebugF("Checking against clock: %d (%d)\n",
               VidModeGetModeValue(mode, VIDMODE_CLOCK), dotClock);
        DebugF("                 hdsp: %d hbeg: %d hend: %d httl: %d\n",
               VidModeGetModeValue(mode, VIDMODE_H_DISPLAY),
               VidModeGetModeValue(mode, VIDMODE_H_SYNCSTART),
               VidModeGetModeValue(mode, VIDMODE_H_SYNCEND),
               VidModeGetModeValue(mode, VIDMODE_H_TOTAL));
        DebugF("                 vdsp: %d vbeg: %d vend: %d vttl: %d flags: %d\n",
               VidModeGetModeValue(mode, VIDMODE_V_DISPLAY),
               VidModeGetModeValue(mode, VIDMODE_V_SYNCSTART),
               VidModeGetModeValue(mode, VIDMODE_V_SYNCEND),
               VidModeGetModeValue(mode, VIDMODE_V_TOTAL),
               VidModeGetModeValue(mode, VIDMODE_FLAGS));

        if ((pVidMode.GetDotClock(pScreen, cast(int)stuff.dotclock) == dotClock) &&
            mixin(MODEMATCH!(`mode`, `stuff`))) {
            pVidMode.DeleteModeline(pScreen, mode);
            DebugF("DeleteModeLine - Succeeded\n");
            return Success;
        }
    } while (pVidMode.GetNextModeline(pScreen, &mode, &dotClock));

    return BadValue;
}



private int ProcVidModeModModeLine(ClientPtr client)
{
    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    // DEBUG_P("XF86VidModeModModeline");

    if (ClientMajorVersion(client) < 2) {
        mixin(X_REQUEST_HEAD_AT_LEAST!(xXF86OldVidModeDeleteModeLineReq));

         mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        int len = cast(int)(client.req_len -
            bytes_to_int32(xXF86OldVidModeModModeLineReq.sizeof));
        if (len != stuff.privsize)
            return BadLength;

        /* convert from old format */
        xXF86VidModeModModeLineReq newstuff = {
            length: cast(ushort)client.req_len,
            screen: stuff.screen,
            hdisplay: stuff.hdisplay,
            hsyncstart: stuff.hsyncstart,
            hsyncend: stuff.hsyncend,
            htotal: stuff.htotal,
            hskew: 0,
            vdisplay: stuff.vdisplay,
            vsyncstart: stuff.vsyncstart,
            vsyncend: stuff.vsyncend,
            vtotal: stuff.vtotal,
            flags: stuff.flags,
            privsize: stuff.privsize,
        };
        return VidModeModModeLine(client, &newstuff);
    }
    else {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86VidModeModModeLineReq);
        mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"hskew");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        int len = cast(int)(client.req_len -
            bytes_to_int32(xXF86VidModeModModeLineReq.sizeof));
        if (len != stuff.privsize)
            return BadLength;
        return VidModeModModeLine(client, stuff);
    }
}

private int VidModeModModeLine(ClientPtr client, xXF86VidModeModModeLineReq* stuff)
{
    VidModePtr pVidMode = void;
    DisplayModePtr mode = void;
    int dotClock = void;

    DebugF("ModModeLine - scrn: %d hdsp: %d hbeg: %d hend: %d httl: %d\n",
           cast(int) stuff.screen, stuff.hdisplay, stuff.hsyncstart,
           stuff.hsyncend, stuff.htotal);
    DebugF("              vdsp: %d vbeg: %d vend: %d vttl: %d flags: %ld\n",
           stuff.vdisplay, stuff.vsyncstart, stuff.vsyncend,
           stuff.vtotal, cast(c_ulong) stuff.flags);

    if (stuff.hsyncstart < stuff.hdisplay ||
        stuff.hsyncend < stuff.hsyncstart ||
        stuff.htotal < stuff.hsyncend ||
        stuff.vsyncstart < stuff.vdisplay ||
        stuff.vsyncend < stuff.vsyncstart || stuff.vtotal < stuff.vsyncend)
        return BadValue;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.GetCurrentModeline(pScreen, &mode, &dotClock))
        return BadValue;

    DisplayModePtr modetmp = VidModeCreateMode();
    if (!modetmp)
        return BadAlloc;

    VidModeCopyMode(mode, modetmp);

    VidModeSetModeValue(modetmp, VIDMODE_H_DISPLAY, cast(int)stuff.hdisplay);
    VidModeSetModeValue(modetmp, VIDMODE_H_SYNCSTART, cast(int)stuff.hsyncstart);
    VidModeSetModeValue(modetmp, VIDMODE_H_SYNCEND, cast(int)stuff.hsyncend);
    VidModeSetModeValue(modetmp, VIDMODE_H_TOTAL, cast(int)stuff.htotal);
    VidModeSetModeValue(modetmp, VIDMODE_H_SKEW, cast(int)stuff.hskew);
    VidModeSetModeValue(modetmp, VIDMODE_V_DISPLAY, cast(int)stuff.vdisplay);
    VidModeSetModeValue(modetmp, VIDMODE_V_SYNCSTART, cast(int)stuff.vsyncstart);
    VidModeSetModeValue(modetmp, VIDMODE_V_SYNCEND, cast(int)stuff.vsyncend);
    VidModeSetModeValue(modetmp, VIDMODE_V_TOTAL, cast(int)stuff.vtotal);
    VidModeSetModeValue(modetmp, VIDMODE_FLAGS, cast(int)stuff.flags);

    if (stuff.privsize)
        DebugF("ModModeLine - Privates in request have been ignored\n");

    /* Check that the mode is consistent with the monitor specs */
    switch (pVidMode.CheckModeForMonitor(pScreen, modetmp)) {
    case MODE_OK:
        break;
    case MODE_HSYNC:
    case MODE_H_ILLEGAL:
        free(modetmp);
        return VidModeErrorBase + XF86VidModeBadHTimings;
    case MODE_VSYNC:
    case MODE_V_ILLEGAL:
        free(modetmp);
        return VidModeErrorBase + XF86VidModeBadVTimings;
    default:
        free(modetmp);
        return VidModeErrorBase + XF86VidModeModeUnsuitable;
    }

    /* Check that the driver is happy with the mode */
    if (pVidMode.CheckModeForDriver(pScreen, modetmp) != MODE_OK) {
        free(modetmp);
        return VidModeErrorBase + XF86VidModeModeUnsuitable;
    }
    free(modetmp);

    VidModeSetModeValue(mode, VIDMODE_H_DISPLAY, cast(int)stuff.hdisplay);
    VidModeSetModeValue(mode, VIDMODE_H_SYNCSTART, cast(int)stuff.hsyncstart);
    VidModeSetModeValue(mode, VIDMODE_H_SYNCEND, cast(int)stuff.hsyncend);
    VidModeSetModeValue(mode, VIDMODE_H_TOTAL, cast(int)stuff.htotal);
    VidModeSetModeValue(mode, VIDMODE_H_SKEW, cast(int)stuff.hskew);
    VidModeSetModeValue(mode, VIDMODE_V_DISPLAY, cast(int)stuff.vdisplay);
    VidModeSetModeValue(mode, VIDMODE_V_SYNCSTART, cast(int)stuff.vsyncstart);
    VidModeSetModeValue(mode, VIDMODE_V_SYNCEND, cast(int)stuff.vsyncend);
    VidModeSetModeValue(mode, VIDMODE_V_TOTAL, cast(int)stuff.vtotal);
    VidModeSetModeValue(mode, VIDMODE_FLAGS, cast(int)stuff.flags);

    pVidMode.SetCrtcForMode(pScreen, mode);
    pVidMode.SwitchMode(pScreen, mode);

    DebugF("ModModeLine - Succeeded\n");
    return Success;
}



private int ProcVidModeValidateModeLine(ClientPtr client)
{
    int len = void;

    // DEBUG_P("XF86VidModeValidateModeline");

    if (ClientMajorVersion(client) < 2) {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86OldVidModeValidateModeLineReq);
        mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        len = cast(int)(client.req_len -
            bytes_to_int32(xXF86OldVidModeValidateModeLineReq.sizeof));
        if (len != stuff.privsize)
            return BadLength;

        xXF86VidModeValidateModeLineReq newstuff = {
            length: cast(ushort)client.req_len,
            screen: stuff.screen,
            dotclock: stuff.dotclock,
            hdisplay: stuff.hdisplay,
            hsyncstart: stuff.hsyncstart,
            hsyncend: stuff.hsyncend,
            htotal: stuff.htotal,
            hskew: 0,
            vdisplay: stuff.vdisplay,
            vsyncstart: stuff.vsyncstart,
            vsyncend: stuff.vsyncend,
            vtotal: stuff.vtotal,
            flags: stuff.flags,
            privsize: stuff.privsize,
        };
        return VidModeValidateModeLine(client, &newstuff);
    }
    else {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86VidModeValidateModeLineReq);
        mixin(X_REQUEST_FIELD_CARD32!"screen");
        mixin(X_REQUEST_FIELD_CARD16!"hdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"hsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"htotal");
        mixin(X_REQUEST_FIELD_CARD16!"hskew");
        mixin(X_REQUEST_FIELD_CARD16!"vdisplay");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncstart");
        mixin(X_REQUEST_FIELD_CARD16!"vsyncend");
        mixin(X_REQUEST_FIELD_CARD16!"vtotal");
        mixin(X_REQUEST_FIELD_CARD32!"flags");
        mixin(X_REQUEST_FIELD_CARD32!"privsize");
        mixin(X_REQUEST_REST_CARD32!());

        len =
            cast(int)(client.req_len -
            bytes_to_int32(xXF86VidModeValidateModeLineReq.sizeof));
        if (len != stuff.privsize)
            return BadLength;
        return VidModeValidateModeLine(client, stuff);
    }
}

private int VidModeValidateModeLine(ClientPtr client, xXF86VidModeValidateModeLineReq* stuff)
{
    VidModePtr pVidMode = void;
    DisplayModePtr mode = void, modetmp = null;
    int status = void, dotClock = void;

    DebugF("ValidateModeLine - scrn: %d clock: %ld\n",
           cast(int) stuff.screen, cast(c_ulong) stuff.dotclock);
    DebugF("                   hdsp: %d hbeg: %d hend: %d httl: %d\n",
           stuff.hdisplay, stuff.hsyncstart,
           stuff.hsyncend, stuff.htotal);
    DebugF("                   vdsp: %d vbeg: %d vend: %d vttl: %d flags: %ld\n",
           stuff.vdisplay, stuff.vsyncstart, stuff.vsyncend, stuff.vtotal,
           cast(c_ulong) stuff.flags);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    status = MODE_OK;

    if (stuff.hsyncstart < stuff.hdisplay ||
        stuff.hsyncend < stuff.hsyncstart ||
        stuff.htotal < stuff.hsyncend ||
        stuff.vsyncstart < stuff.vdisplay ||
        stuff.vsyncend < stuff.vsyncstart ||
        stuff.vtotal < stuff.vsyncend) {
        status = MODE_BAD;
        goto status_reply;
    }

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.GetCurrentModeline(pScreen, &mode, &dotClock))
        return BadValue;

    modetmp = VidModeCreateMode();
    if (!modetmp)
        return BadAlloc;

    VidModeCopyMode(mode, modetmp);

    VidModeSetModeValue(modetmp, VIDMODE_H_DISPLAY, cast(int)stuff.hdisplay);
    VidModeSetModeValue(modetmp, VIDMODE_H_SYNCSTART, cast(int)stuff.hsyncstart);
    VidModeSetModeValue(modetmp, VIDMODE_H_SYNCEND, cast(int)stuff.hsyncend);
    VidModeSetModeValue(modetmp, VIDMODE_H_TOTAL, cast(int)stuff.htotal);
    VidModeSetModeValue(modetmp, VIDMODE_H_SKEW, cast(int)stuff.hskew);
    VidModeSetModeValue(modetmp, VIDMODE_V_DISPLAY, cast(int)stuff.vdisplay);
    VidModeSetModeValue(modetmp, VIDMODE_V_SYNCSTART, cast(int)stuff.vsyncstart);
    VidModeSetModeValue(modetmp, VIDMODE_V_SYNCEND, cast(int)stuff.vsyncend);
    VidModeSetModeValue(modetmp, VIDMODE_V_TOTAL, cast(int)stuff.vtotal);
    VidModeSetModeValue(modetmp, VIDMODE_FLAGS, cast(int)stuff.flags);
    if (stuff.privsize)
        DebugF("ValidateModeLine - Privates in request have been ignored\n");

    /* Check that the mode is consistent with the monitor specs */
    if ((status =
         pVidMode.CheckModeForMonitor(pScreen, modetmp)) != MODE_OK)
        goto status_reply;

    /* Check that the driver is happy with the mode */
    status = pVidMode.CheckModeForDriver(pScreen, modetmp);

 status_reply:
    free(modetmp);

    xXF86VidModeValidateModeLineReply reply = {
        status: status
    };

    DebugF("ValidateModeLine - Succeeded (status = %d)\n", status);

    mixin(X_REPLY_FIELD_CARD32!"status");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcVidModeSwitchMode(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeSwitchModeReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");
    mixin(X_REQUEST_FIELD_CARD16!"zoom");

    VidModePtr pVidMode = void;

    // DEBUG_P("XF86VidModeSwitchMode");

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    pVidMode.ZoomViewport(pScreen, cast(short) stuff.zoom);

    return Success;
}



private int ProcVidModeSwitchToMode(ClientPtr client)
{
    int len = void;

    // DEBUG_P("XF86VidModeSwitchToMode");

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    if (ClientMajorVersion(client) < 2) {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86OldVidModeSwitchToModeReq);
        mixin(X_REQUEST_FIELD_CARD32!"screen");

        len =
            cast(int)(client.req_len -
            bytes_to_int32(xXF86OldVidModeSwitchToModeReq.sizeof));
        if (len != stuff.privsize)
            return BadLength;

        /* convert from old format */
        xXF86VidModeSwitchToModeReq newstuff = {
            length: cast(ushort)client.req_len,
            screen: stuff.screen,
            dotclock: stuff.dotclock,
            hdisplay: stuff.hdisplay,
            hsyncstart: stuff.hsyncstart,
            hsyncend: stuff.hsyncend,
            htotal: stuff.htotal,
            vdisplay: stuff.vdisplay,
            vsyncstart: stuff.vsyncstart,
            vsyncend: stuff.vsyncend,
            vtotal: stuff.vtotal,
            flags: stuff.flags,
            privsize: stuff.privsize,
        };
        return VidModeSwitchToMode(client, &newstuff);
    }
    else {
        mixin(X_REQUEST_HEAD_AT_LEAST!xXF86VidModeSwitchToModeReq);
        mixin(X_REQUEST_FIELD_CARD32!"screen");

        len =
            cast(int)(client.req_len -
            bytes_to_int32(xXF86VidModeSwitchToModeReq.sizeof));
        if (len != stuff.privsize)
            return BadLength;
        return VidModeSwitchToMode(client, stuff);
    }
}

private int VidModeSwitchToMode(ClientPtr client, xXF86VidModeSwitchToModeReq* stuff)
{
    VidModePtr pVidMode = void;
    DisplayModePtr mode = void;
    int dotClock = void;

    DebugF("SwitchToMode - scrn: %d clock: %ld\n",
           cast(int) stuff.screen, cast(c_ulong) stuff.dotclock);
    DebugF("               hdsp: %d hbeg: %d hend: %d httl: %d\n",
           stuff.hdisplay, stuff.hsyncstart,
           stuff.hsyncend, stuff.htotal);
    DebugF("               vdsp: %d vbeg: %d vend: %d vttl: %d flags: %ld\n",
           stuff.vdisplay, stuff.vsyncstart, stuff.vsyncend, stuff.vtotal,
           cast(c_ulong) stuff.flags);

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.GetCurrentModeline(pScreen, &mode, &dotClock))
        return BadValue;

    if ((pVidMode.GetDotClock(pScreen, cast(int)stuff.dotclock) == dotClock)
        && mixin(MODEMATCH!(`mode`, `stuff`)))
        return Success;

    if (!pVidMode.GetFirstModeline(pScreen, &mode, &dotClock))
        return BadValue;

    do {
        DebugF("Checking against clock: %d (%d)\n",
               VidModeGetModeValue(mode, VIDMODE_CLOCK), dotClock);
        DebugF("                 hdsp: %d hbeg: %d hend: %d httl: %d\n",
               VidModeGetModeValue(mode, VIDMODE_H_DISPLAY),
               VidModeGetModeValue(mode, VIDMODE_H_SYNCSTART),
               VidModeGetModeValue(mode, VIDMODE_H_SYNCEND),
               VidModeGetModeValue(mode, VIDMODE_H_TOTAL));
        DebugF("                 vdsp: %d vbeg: %d vend: %d vttl: %d flags: %d\n",
               VidModeGetModeValue(mode, VIDMODE_V_DISPLAY),
               VidModeGetModeValue(mode, VIDMODE_V_SYNCSTART),
               VidModeGetModeValue(mode, VIDMODE_V_SYNCEND),
               VidModeGetModeValue(mode, VIDMODE_V_TOTAL),
               VidModeGetModeValue(mode, VIDMODE_FLAGS));

        if ((pVidMode.GetDotClock(pScreen, cast(int)stuff.dotclock) == dotClock) &&
            mixin(MODEMATCH!(`mode`, `stuff`))) {

            if (!pVidMode.SwitchMode(pScreen, mode))
                return BadValue;

            DebugF("SwitchToMode - Succeeded\n");
            return Success;
        }
    } while (pVidMode.GetNextModeline(pScreen, &mode, &dotClock));

    return BadValue;
}

private int ProcVidModeLockModeSwitch(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeLockModeSwitchReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");
    mixin(X_REQUEST_FIELD_CARD16!"lock");

    VidModePtr pVidMode = void;

    // DEBUG_P("XF86VidModeLockModeSwitch");

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.LockZoom(pScreen, cast(short) stuff.lock))
        return VidModeErrorBase + XF86VidModeZoomLocked;

    return Success;
}

pragma(inline, true) private CARD32 _combine_f(vidMonitorValue a, vidMonitorValue b)
{
    CARD32 buf = (cast(ushort) a.f) |
        (cast(ushort) b.f << 16);
    return buf;
}

private int ProcVidModeGetMonitor(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetMonitorReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    // DEBUG_P("XF86VidModeGetMonitor");

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    VidModePtr pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    const(int) nHsync = pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_NHSYNC, 0).i;
    const(int) nVrefresh = pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_NVREFRESH, 0).i;

    const(char)* vendorStr = cast(const(char)*)pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_VENDOR, 0).ptr;
    const(char)* modelStr = cast(const(char)*)pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_MODEL, 0).ptr;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    for (int i = 0; i < nHsync; i++) {
        x_rpcbuf_write_CARD32(
            &rpcbuf,
            _combine_f(pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_HSYNC_LO, i),
                       pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_HSYNC_HI, i)));
    }

    for (int i = 0; i < nVrefresh; i++) {
        x_rpcbuf_write_CARD32(
            &rpcbuf,
            _combine_f(pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_VREFRESH_LO, i),
                       pVidMode.GetMonitorValue(pScreen, VIDMODE_MON_VREFRESH_HI, i)));
    }

    x_rpcbuf_write_string_pad(&rpcbuf, vendorStr);
    x_rpcbuf_write_string_pad(&rpcbuf, modelStr);

    xXF86VidModeGetMonitorReply reply = {
        nhsync: cast(ubyte)nHsync,
        nvsync: cast(ubyte)nVrefresh,
        vendorLength: cast(ubyte)x_safe_strlen(vendorStr),
        modelLength: cast(ubyte)x_safe_strlen(modelStr),
    };

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcVidModeGetViewPort(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetViewPortReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    VidModePtr pVidMode = void;
    int x = void, y = void;

    // DEBUG_P("XF86VidModeGetViewPort");

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    pVidMode.GetViewPort(pScreen, &x, &y);

    xXF86VidModeGetViewPortReply reply = {
        x: x,
        y: y
    };

    mixin(X_REPLY_FIELD_CARD32!"x");
    mixin(X_REPLY_FIELD_CARD32!"y");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcVidModeSetViewPort(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeSetViewPortReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");
    mixin(X_REQUEST_FIELD_CARD32!"x");
    mixin(X_REQUEST_FIELD_CARD32!"y");

    VidModePtr pVidMode = void;

    // DEBUG_P("XF86VidModeSetViewPort");

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.SetViewPort(pScreen, cast(int)stuff.x, cast(int)stuff.y))
        return BadValue;

    return Success;
}

private int ProcVidModeGetDotClocks(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetDotClocksReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    VidModePtr pVidMode = void;
    int numClocks = void;
    Bool ClockProg = void;

    // DEBUG_P("XF86VidModeGetDotClocks");

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    numClocks = pVidMode.GetNumOfClocks(pScreen, &ClockProg);

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (!ClockProg) {
        int* Clocks = cast(int*) calloc(numClocks, int.sizeof);
        if (!Clocks)
            return BadValue;
        if (!pVidMode.GetClocks(pScreen, Clocks)) {
            free(Clocks);
            return BadValue;
        }

        for (int n = 0; n < numClocks; n++)
            x_rpcbuf_write_CARD32(&rpcbuf, Clocks[n]);

        free(Clocks);
    }

    xXF86VidModeGetDotClocksReply reply = {
        clocks: numClocks,
        maxclocks: MAXCLOCKS,
        flags: (ClockProg ? CLKFLAG_PROGRAMABLE : 0),
    };

    mixin(X_REPLY_FIELD_CARD32!"clocks");
    mixin(X_REPLY_FIELD_CARD32!"maxclocks");
    mixin(X_REPLY_FIELD_CARD32!"flags");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcVidModeSetGamma(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeSetGammaReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");
    mixin(X_REQUEST_FIELD_CARD32!"red");
    mixin(X_REQUEST_FIELD_CARD32!"green");
    mixin(X_REQUEST_FIELD_CARD32!"blue");

    VidModePtr pVidMode = void;

    // DEBUG_P("XF86VidModeSetGamma");

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.SetGamma(pScreen, (cast(float) stuff.red) / 10000.,
                         (cast(float) stuff.green) / 10000.,
                         (cast(float) stuff.blue) / 10000.))
        return BadValue;

    return Success;
}

private int ProcVidModeGetGamma(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetGammaReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    VidModePtr pVidMode = void;
    float red = void, green = void, blue = void;

    // DEBUG_P("XF86VidModeGetGamma");

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (!pVidMode.GetGamma(pScreen, &red, &green, &blue))
        return BadValue;

    xXF86VidModeGetGammaReply reply = {
        red: cast(CARD32) (red * 10000.),
        green: cast(CARD32) (green * 10000.),
        blue: cast(CARD32) (blue * 10000.)
    };

    mixin(X_REPLY_FIELD_CARD32!"red");
    mixin(X_REPLY_FIELD_CARD32!"green");
    mixin(X_REPLY_FIELD_CARD32!"blue");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcVidModeSetGammaRamp(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_AT_LEAST!xXF86VidModeSetGammaRampReq);
    mixin(X_REQUEST_FIELD_CARD16!"size");
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    mixin(REQUEST_FIXED_SIZE!("xXF86VidModeSetGammaRampReq",
                       "((stuff.size + 1) & ~1) * 6"));
    mixin(X_REQUEST_REST_CARD16!());

    CARD16* r = void, g = void, b = void;
    VidModePtr pVidMode = void;

    /* limited to local-only connections */
    if (!VidModeAllowNonLocal && !client.local)
        return VidModeErrorBase + XF86VidModeClientNotLocal;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (stuff.size != pVidMode.GetGammaRampSize(pScreen))
        return BadValue;

    int length = (stuff.size + 1) & ~1;

    mixin(REQUEST_FIXED_SIZE!("xXF86VidModeSetGammaRampReq", "length * 6"));

    r = cast(CARD16*) &stuff[1];
    g = r + length;
    b = g + length;

    if (!pVidMode.SetGammaRamp(pScreen, stuff.size, r, g, b))
        return BadValue;

    return Success;
}

private int ProcVidModeGetGammaRamp(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetGammaRampReq);
    mixin(X_REQUEST_FIELD_CARD16!"size");
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    VidModePtr pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    if (stuff.size != pVidMode.GetGammaRampSize(pScreen))
        return BadValue;

    const(int) length = (stuff.size + 1) & ~1;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    if (stuff.size) {
        size_t ramplen = length * 3 * CARD16.sizeof;
        CARD16* ramp = cast(ushort*)x_rpcbuf_reserve(&rpcbuf, ramplen);
        if (!ramp)
            return BadAlloc;

        if (!pVidMode.GetGammaRamp(pScreen, stuff.size,
                                 ramp, ramp + length, ramp + (length * 2))) {
            x_rpcbuf_clear(&rpcbuf);
            return BadValue;
        }

        if (rpcbuf.swapped)
            SwapShorts(cast(short*) rpcbuf.buffer, rpcbuf.wpos / CARD16.sizeof);
    }

    xXF86VidModeGetGammaRampReply reply = {
        size: stuff.size
    };

    mixin(X_REPLY_FIELD_CARD16!"size");

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

private int ProcVidModeGetGammaRampSize(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetGammaRampSizeReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    VidModePtr pVidMode = void;

    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)stuff.screen);
    if (!pScreen)
        return BadValue;

    pVidMode = VidModeGetPtr(pScreen);
    if (pVidMode is null)
        return BadImplementation;

    xXF86VidModeGetGammaRampSizeReply reply = {
        size: cast(ushort)pVidMode.GetGammaRampSize(pScreen)
    };

    mixin(X_REPLY_FIELD_CARD16!"size");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcVidModeGetPermissions(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeGetPermissionsReq);
    mixin(X_REQUEST_FIELD_CARD16!"screen");

    if (!dixScreenExists(stuff.screen))
        return BadValue;

    xXF86VidModeGetPermissionsReply reply = {
        permissions: (XF86VM_READ_PERMISSION |
                        ((VidModeAllowNonLocal || client.local) ?
                            XF86VM_WRITE_PERMISSION : 0)),
    };

    mixin(X_REPLY_FIELD_CARD32!"permissions");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private int ProcVidModeSetClientVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86VidModeSetClientVersionReq);
    mixin(X_REQUEST_FIELD_CARD16!"major");
    mixin(X_REQUEST_FIELD_CARD16!"minor");

    VidModePrivPtr pPriv = void;

    // DEBUG_P("XF86VidModeSetClientVersion");

    if ((pPriv = mixin(VM_GETPRIV!(`client`))) is null) {
        pPriv = cast(VidModePrivRec*) calloc(1, VidModePrivRec.sizeof);
        if (!pPriv)
            return BadAlloc;
        mixin(VM_SETPRIV!(`client`, `pPriv`));
    }
    pPriv.major = stuff.major;

    pPriv.minor = stuff.minor;

    return Success;
}

private int ProcVidModeDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);
    switch (stuff.data) {
    case X_XF86VidModeQueryVersion:
        return ProcVidModeQueryVersion(client);
    case X_XF86VidModeGetModeLine:
        return ProcVidModeGetModeLine(client);
    case X_XF86VidModeGetMonitor:
        return ProcVidModeGetMonitor(client);
    case X_XF86VidModeGetAllModeLines:
        return ProcVidModeGetAllModeLines(client);
    case X_XF86VidModeValidateModeLine:
        return ProcVidModeValidateModeLine(client);
    case X_XF86VidModeGetViewPort:
        return ProcVidModeGetViewPort(client);
    case X_XF86VidModeGetDotClocks:
        return ProcVidModeGetDotClocks(client);
    case X_XF86VidModeSetClientVersion:
        return ProcVidModeSetClientVersion(client);
    case X_XF86VidModeGetGamma:
        return ProcVidModeGetGamma(client);
    case X_XF86VidModeGetGammaRamp:
        return ProcVidModeGetGammaRamp(client);
    case X_XF86VidModeGetGammaRampSize:
        return ProcVidModeGetGammaRampSize(client);
    case X_XF86VidModeGetPermissions:
        return ProcVidModeGetPermissions(client);
    case X_XF86VidModeAddModeLine:
        return ProcVidModeAddModeLine(client);
    case X_XF86VidModeDeleteModeLine:
        return ProcVidModeDeleteModeLine(client);
    case X_XF86VidModeModModeLine:
        return ProcVidModeModModeLine(client);
    case X_XF86VidModeSwitchMode:
        return ProcVidModeSwitchMode(client);
    case X_XF86VidModeSwitchToMode:
        return ProcVidModeSwitchToMode(client);
    case X_XF86VidModeLockModeSwitch:
        return ProcVidModeLockModeSwitch(client);
    case X_XF86VidModeSetViewPort:
        return ProcVidModeSetViewPort(client);
    case X_XF86VidModeSetGamma:
        return ProcVidModeSetGamma(client);
    case X_XF86VidModeSetGammaRamp:
        return ProcVidModeSetGammaRamp(client);
    default:
        return BadRequest;
    }
}

void VidModeAddExtension(Bool allow_non_local)
{
    ExtensionEntry* extEntry = void;

    // DEBUG_P("VidModeAddExtension");

    if (!dixRegisterPrivateKey(VidModeClientPrivateKey, PRIVATE_CLIENT, 0))
        return;

    if ((extEntry = AddExtension(XF86VIDMODENAME,
                                 XF86VidModeNumberEvents,
                                 XF86VidModeNumberErrors,
                                 &ProcVidModeDispatch,
                                 &ProcVidModeDispatch,
                                 null, &StandardMinorOpcode)) !is null) {
        VidModeErrorBase = extEntry.errorBase;
        VidModeAllowNonLocal = allow_non_local;
    }
}

VidModePtr VidModeGetPtr(ScreenPtr pScreen)
{
    return cast(VidModePtr) (dixLookupPrivate(&pScreen.devPrivates, VidModePrivateKey));
}

VidModePtr VidModeInit(ScreenPtr pScreen)
{
    if (!dixRegisterPrivateKey(VidModePrivateKey, PRIVATE_SCREEN, VidModeRec.sizeof))
        return null;

    return VidModeGetPtr(pScreen);
}

 }/* XF86VIDMODE */
