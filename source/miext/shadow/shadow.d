module miext.shadow.shadow;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2000 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;

import core.stdc.stdlib;
import x11.X;

import dix.screen_hooks_priv;

import    dix.scrnintstr;
import    include.windowstr;
import    dix.dixfonts;
import    region;
import    dix.globals;
import    dix.gc;
import include.shadow;
import dix.screen_hooks;

private DevPrivateKeyRec shadowScrPrivateKeyRec;
enum shadowScrPrivateKey = (&shadowScrPrivateKeyRec);

enum string shadowGetBuf(string pScr) = `(cast(shadowBufPtr) 
    dixLookupPrivate(&(` ~ pScr ~ `).devPrivates, shadowScrPrivateKey))`;
enum string shadowBuf(string pScr) = `shadowBufPtr pBuf = ` ~ shadowGetBuf!(pScr) ~ `;`;

enum string wrap(string priv, string real_, string mem) = `{
    ` ~ priv ~ `.` ~ mem ~ ` = ` ~ real_ ~ `.` ~ mem ~ `; 
    ` ~ real_ ~ `.` ~ mem ~ ` = &shadow`~mem~`; 
}`;

enum string unwrap(string priv, string real_, string mem) = `{
    ` ~ real_ ~ `.` ~ mem ~ ` = ` ~ priv ~ `.` ~ mem ~ `; 
}`;

private void shadowRedisplay(ScreenPtr pScreen)
{
    mixin(shadowBuf!(`pScreen`));
    RegionPtr pRegion = void;

    if (!pBuf || !pBuf.pDamage || !pBuf.update)
        return;
    pRegion = DamageRegion(pBuf.pDamage);
    if (RegionNotEmpty(pRegion)) {
        (*pBuf.update) (pScreen, pBuf);
        DamageEmpty(pBuf.pDamage);
    }
}

private void shadowBlockHandler(ScreenPtr pScreen, void* timeout)
{
    mixin(shadowBuf!(`pScreen`));

    shadowRedisplay(pScreen);

    mixin(unwrap!(`pBuf`, `pScreen`, `BlockHandler`));
    pScreen.BlockHandler(pScreen, timeout);
    mixin(wrap!(`pBuf`, `pScreen`, `BlockHandler`));
}

private void shadowGetImage(DrawablePtr pDrawable, int sx, int sy, int w, int h, uint format, c_ulong planeMask, char* pdstLine)
{
    ScreenPtr pScreen = pDrawable.pScreen;

    mixin(shadowBuf!(`pScreen`));

    /* Many apps use GetImage to sync with the visible frame buffer */
    if (pDrawable.type == DRAWABLE_WINDOW)
        shadowRedisplay(pScreen);
    mixin(unwrap!(`pBuf`, `pScreen`, `GetImage`));
    pScreen.GetImage(pDrawable, sx, sy, w, h, format, planeMask, pdstLine);
    mixin(wrap!(`pBuf`, `pScreen`, `GetImage`));
}

private void shadowCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    dixScreenUnhookClose(pScreen, &shadowCloseScreen);

    mixin(shadowBuf!(`pScreen`));
    mixin(unwrap!(`pBuf`, `pScreen`, `GetImage`));
    mixin(unwrap!(`pBuf`, `pScreen`, `BlockHandler`));
    shadowRemove(pScreen, pBuf.pPixmap);
    DamageDestroy(pBuf.pDamage);
    dixDestroyPixmap(pBuf.pPixmap, 0);
    free(pBuf);
}

Bool shadowSetup(ScreenPtr pScreen)
{

    if (!dixRegisterPrivateKey(&shadowScrPrivateKeyRec, PRIVATE_SCREEN, 0))
        return FALSE;

    if (!DamageSetup(pScreen))
        return FALSE;

    shadowBufPtr pBuf = cast(shadowBufRec*) calloc(1, shadowBufRec.sizeof);
    if (!pBuf)
        return FALSE;
    pBuf.pDamage = DamageCreate(cast(DamageReportFunc) null,
                                 cast(DamageDestroyFunc) null,
                                 DamageReportNone, TRUE, pScreen, pScreen);
    if (!pBuf.pDamage) {
        free(pBuf);
        return FALSE;
    }

    dixScreenHookClose(pScreen, &shadowCloseScreen);

    mixin(wrap!(`pBuf`, `pScreen`, `GetImage`));
    mixin(wrap!(`pBuf`, `pScreen`, `BlockHandler`));
    pBuf.update = null;
    pBuf.window = null;
    pBuf.pPixmap = null;
    pBuf.closure = null;
    pBuf.randr = 0;

    dixSetPrivate(&pScreen.devPrivates, shadowScrPrivateKey, pBuf);
    return TRUE;
}

Bool shadowAdd(ScreenPtr pScreen, PixmapPtr pPixmap, ShadowUpdateProc update, ShadowWindowProc window, int randr, void* closure)
{
    mixin(shadowBuf!(`pScreen`));

    /*
     * Map simple rotation values to bitmasks; fortunately,
     * these are all unique
     */
    switch (randr) {
    case 0:
        randr = SHADOW_ROTATE_0;
        break;
    case 90:
        randr = SHADOW_ROTATE_90;
        break;
    case 180:
        randr = SHADOW_ROTATE_180;
        break;
    case 270:
        randr = SHADOW_ROTATE_270;
        break;
    default: break;}
    pBuf.update = update;
    pBuf.window = window;
    pBuf.randr = randr;
    pBuf.closure = closure;
    pBuf.pPixmap = pPixmap;
    DamageRegister(&pPixmap.drawable, pBuf.pDamage);
    return TRUE;
}

void shadowRemove(ScreenPtr pScreen, PixmapPtr pPixmap)
{
    mixin(shadowBuf!(`pScreen`));

    if (pBuf.pPixmap) {
        DamageUnregister(pBuf.pDamage);
        pBuf.update = null;
        pBuf.window = null;
        pBuf.randr = 0;
        pBuf.closure = null;
        pBuf.pPixmap = null;
    }
}
