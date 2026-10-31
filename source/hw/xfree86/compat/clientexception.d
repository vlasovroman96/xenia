module clientexception;
@nogc nothrow:
extern(C): __gshared:
import build.dix_config;

////import x11.Xfuncproto;

import dix.dix_priv;
import dix.dispatch;

import xf86_compat;

/*
 * this is specifically for NVidia proprietary driver: they're again lagging
 * behind a year, doing at least some minimal cleanup of their code base.
 * All attempts to get in direct contact with them have failed.
 */
export 
void MarkClientException(ClientPtr pClient)
{
    xf86NVidiaBugInternalFunc("MarkClientException()");

    dixMarkClientException(pClient);
}
