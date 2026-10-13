module glx.glxbuiltin;
@nogc nothrow:
extern(C): __gshared:

import x11.Xdefs;
import x11.Xmd;

import build.dix_config;
import include.glx_extinit : __GLXprovider;
import include.xf86Module : LoaderSymbol;
import glx.glxext : xeniaGlxCreateVendor, xeniaGlxPushProvider;


/*
 * Xenia builds the GLX server implementation into the X server executable,
 * unlike the traditional Xorg layout where this is done by libglx.so.
 * Keep the provider/callback setup, but don't load the external GLX module.
 */
Bool xeniaGlxBuiltinInit()
{
    static Bool setupDone = False;
    __GLXprovider* provider = null;

    if (setupDone)
        return True;

    provider = cast(__GLXprovider*)LoaderSymbol("__glXDRI2Provider");
    if (provider !is null)
        xeniaGlxPushProvider(provider);

    if (!xeniaGlxCreateVendor())
        return False;

    setupDone = True;
    return True;
}
