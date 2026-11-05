module xkb.xkbPrivate;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import core.stdc.stdio;
//import x11.X;

import hw.xfree86.common.action_priv;
import xkb.xkbsrv_priv;

import include.windowstr;
import os.os;
import xf86_priv;
import externs.gnu;
import externs.X11.extensions.XKB;
import include.xkbstr;


// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int XkbDDXPrivate(DeviceIntPtr dev, KeyCode key, XkbAction* act)
{
    XkbAnyAction* xf86act = &(act.any);
    char[XkbAnyActionDataSize + 1] msgbuf = void;

    if (xf86act.type == XkbSA_XFree86Private) {
        memcpy(msgbuf.ptr, xf86act.data.ptr, XkbAnyActionDataSize);
        msgbuf[XkbAnyActionDataSize] = '\0';
        if (strcasecmp(msgbuf.ptr, "-vmode") == 0)
            xf86ProcessActionEvent(ACTION_PREV_MODE, null);
        else if (strcasecmp(msgbuf.ptr, "+vmode") == 0)
            xf86ProcessActionEvent(ACTION_NEXT_MODE, null);
    }

    return 0;
}
