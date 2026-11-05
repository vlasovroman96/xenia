module mi.mipointer_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xdefs;

public import dix.screenint_priv;
public import dix.input;
public import mi.mipointer;

// void miPointerWarpCursor(DeviceIntPtr pDev, ScreenPtr pScreen, int x, int y);
// void miPointerSetScreen(DeviceIntPtr pDev, int screen_num, int x, int y);
// void miPointerUpdateSprite(DeviceIntPtr pDev);

 /* Invalidate current sprite, forcing reload on next
  * sprite setting (window crossing, grab action, etc)
  */
void miPointerInvalidateSprite(DeviceIntPtr pDev);

/* Sets whether the sprite should be updated immediately on pointer moves */
// Bool miPointerSetWaitForUpdate(ScreenPtr pScreen, Bool wait);

DevPrivateKeyRec miPointerPrivKeyRec;

enum miPointerPrivKey = (&miPointerPrivKeyRec);

 /* _XSERVER_MI_MIPOINTER_PRIV_H */
