module hw.cfree86.compat.xf86Helper;
@nogc nothrow:
extern(C): __gshared:
import build.dix_config;

////import x11.Xfuncproto;


import hw.xfree86.common.xf86Priv;
import xf86Bus;


/*
 * this is specifically for NVidia proprietary driver: they're again lagging
 * behind a year, doing at least some minimal cleanup of their code base.
 * All attempts to get in direct contact with them have failed.
 */

/*
 * this is only needed for the 570.x nvidia drivers
 */

export 

Bool xf86IsScreenPrimary(ScrnInfoPtr pScrn)
{
    int i = void;

    for (i = 0; i < pScrn.numEntities; i++) {
        if (xf86IsEntityPrimary(i))
            return TRUE;
    }
    return FALSE;
}
