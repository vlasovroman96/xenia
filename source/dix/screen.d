module screen;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
import build.dix_config;

import dix.callback;
import dix.dix_priv;
import dix.gc_priv;
import dix.screensaver_priv;
import dix.scrintstr;
import dix.scrnintstr;
import dix.dispatch;

// CallbackListPtr ScreenSaverAccessCallback = null;
// CallbackListPtr ScreenAccessCallback = null;

void dixFreeScreen(ScreenPtr pScreen)
{
    if (!pScreen)
        return;

    FreeGCperDepth(pScreen);
    dixDestroyPixmap(pScreen.defaultStipple, 0);
    dixFreeScreenSpecificPrivates(pScreen);
    dixScreenRaiseClose(pScreen);
    dixFreePrivates(pScreen.devPrivates, PRIVATE_SCREEN);
    DeleteCallbackList(&pScreen.hookWindowDestroy);
    DeleteCallbackList(&pScreen.hookWindowPosition);
    DeleteCallbackList(&pScreen.hookClose);
    DeleteCallbackList(&pScreen.hookPostClose);
    DeleteCallbackList(&pScreen.hookPixmapDestroy);
    DeleteCallbackList(&pScreen.hookPostCreateResources);
    free(pScreen);
}
