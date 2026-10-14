module include.shadow;
@nogc nothrow:
extern(C): __gshared:
/*
 *
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

 
public import include.scrnintstr;

public import include.picturestr;

public import dix.damage;
public import dix.damage;
import include.shadow;
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

                          /* _SHADOW_H_ */
