module xf86VGAarbiter_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xdefs;
import build.xlibre_server;

public import hw.xfree86.common.xf86str;

static if(XSERVER_LIBPCIACCESS){








} else { /* XSERVER_LIBPCIACCESS */

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void xf86VGAarbiterInit() {}
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void xf86VGAarbiterFini() {}
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void xf86VGAarbiterScrnInit(ScrnInfoPtr pScrn) {}
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void xf86VGAarbiterWrapFunctions() {}
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void xf86VGAarbiterLock(ScrnInfoPtr pScrn) {}
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void xf86VGAarbiterUnlock(ScrnInfoPtr pScrn) {}

} /* XSERVER_LIBPCIACCESS */

Bool xf86VGAarbiterAllowDRI(ScreenPtr pScreen);

 /* _XSERVER_XF86VGAARBITERPRIV_H */
