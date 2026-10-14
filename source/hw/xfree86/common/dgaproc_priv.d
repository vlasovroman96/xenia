module hw.xfree86.common.dgaproc_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import include.screenint;
public import include.input;
import x11.Xdefs;
// Bool DGAScreenAvailable(ScreenPtr pScreen);
// Bool DGAActive(int Index);

Bool DGAVTSwitch();
Bool DGAStealButtonEvent(DeviceIntPtr dev, int Index, int button, int is_down);
Bool DGAStealMotionEvent(DeviceIntPtr dev, int Index, int dx, int dy);
Bool DGAStealKeyEvent(DeviceIntPtr dev, int Index, int key_code, int is_down);

 /* __XSERVER_XFREE86_DGAPROC_H */
