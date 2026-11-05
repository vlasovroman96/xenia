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
import    dix.window;
import    dix.dixfonts;
import    region;
import    dix.globals;
import    dix.gc;
import dix.screen_hooks;

public import dix.picturestr;

public import hw.xfree86.common.xf86str;

/*
 * User defined callback function.  Passed a pointer to the ScrnInfo struct,
 * the number of dirty rectangles, and a pointer to the first dirty rectangle
 * in the array.
 */
alias RefreshAreaFuncPtr = void function(ScrnInfoPtr, int, BoxPtr);

/*
 * ShadowFBInit initializes the shadowfb subsystem.  refreshArea is a pointer
 * to a user supplied callback function.  This function will be called after
 * any operation that modifies the framebuffer.  The newly dirtied rectangles
 * are passed to the callback.
 *
 * Returns FALSE in the event of an error.
 */
void  ShadowFBInit(ScreenPtr pScreen, RefreshAreaFuncPtr refreshArea);

/*
 * ShadowFBInit2 is a more featureful refinement of the original shadowfb.
 * ShadowFBInit2 allows you to specify two callbacks, one to be called
 * immediately before an operation that modifies the framebuffer, and another
 * to be called immediately after.
 *
 * Returns FALSE in the event of an error
 */
void  ShadowFBInit2(ScreenPtr pScreen, RefreshAreaFuncPtr preRefreshArea, RefreshAreaFuncPtr postRefreshArea);

alias shadowBufPtr = _shadowBuf*;

alias ShadowUpdateProc = void function(ScreenPtr pScreen, shadowBufPtr pBuf);

enum SHADOW_WINDOW_RELOCATE = 1;
enum SHADOW_WINDOW_READ = 2;
enum SHADOW_WINDOW_WRITE = 4;

alias ShadowWindowProc = void* function(ScreenPtr pScreen, CARD32 row, CARD32 offset, int mode, CARD32* size, void* closure);

struct _shadowBuf {
    DamagePtr pDamage;
    ShadowUpdateProc update;
    ShadowWindowProc window;
    PixmapPtr pPixmap;
    void* closure;
    int randr;

    /* screen wrappers */
    GetImageProcPtr GetImage;
    void* _dummy1; // required in place of a removed field for ABI compatibility
    ScreenBlockHandlerProcPtr BlockHandler;
}

alias shadowBufRec = _shadowBuf; 

/* Match defines from randr extension */
enum SHADOW_ROTATE_0 =	    1;
enum SHADOW_ROTATE_90 =    2;
enum SHADOW_ROTATE_180 =   4;
enum SHADOW_ROTATE_270 =   8;
enum SHADOW_ROTATE_ALL =   (SHADOW_ROTATE_0|SHADOW_ROTATE_90|
			     SHADOW_ROTATE_180|SHADOW_ROTATE_270);
enum SHADOW_REFLECT_X =    16;
enum SHADOW_REFLECT_Y =    32;
enum SHADOW_REFLECT_ALL =  (SHADOW_REFLECT_X|SHADOW_REFLECT_Y);

// void  shadowSetup(ScreenPtr pScreen);

void  shadowAdd(ScreenPtr pScreen, PixmapPtr pPixmap, ShadowUpdateProc update, ShadowWindowProc window, int randr, void* closure);

void  shadowRemove(ScreenPtr pScreen, PixmapPtr pPixmap);

void  shadowUpdateAfb4(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateAfb8(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateIplan2p4(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateIplan2p8(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdatePacked(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdatePlanar4(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdatePlanar4x8(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotatePacked(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate8_90(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate16_90(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate16_90YX(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate32_90(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate8_180(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate16_180(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate32_180(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate8_270(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate16_270(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate16_270YX(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate32_270(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate8(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate16(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdateRotate32(ScreenPtr pScreen, shadowBufPtr pBuf);

void  shadowUpdate32to24(ScreenPtr pScreen, shadowBufPtr pBuf);

alias shadowUpdateProc = void function(ScreenPtr, shadowBufPtr);

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
