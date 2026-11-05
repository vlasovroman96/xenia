module log;
@nogc nothrow:
extern(C): __gshared:
import build.dix_config;

////import x11.Xfuncproto;

import os.os;

import xf86_compat;
import os.log;

/*
 * this is specifically for NVidia proprietary driver: they're again lagging
 * behind a year, doing at least some minimal cleanup of their code base.
 * All attempts to get in direct contact with them have failed.
 */
export void xf86Msg(MessageType type, const char *format, ...);

void xf86Msg(MessageType type, const(char)* format, ...)
{
    xf86NVidiaBugInternalFunc("xf86Msg()");

    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    LogVMessageVerb(type, 1, format, ap);
    core.stdc.stdarg.va_end(ap);
}


/*
 * this is only needed for the 570.x nvidia drivers
 */

export void xf86MsgVerb(MessageType type, int verb, const char *format, ...) ;

void xf86MsgVerb(MessageType type, int verb, const(char)* format, ...)
{
    static char reportxf86MsgVerb = 1;

    if (reportxf86MsgVerb) {
        xf86NVidiaBugInternalFunc("xf86MsgVerb()");
        reportxf86MsgVerb = 0;
    }

    va_list ap = void;
    core.stdc.stdarg.va_start(ap, format);
    LogVMessageVerb(type, verb, format, ap);
    core.stdc.stdarg.va_end(ap);
}
