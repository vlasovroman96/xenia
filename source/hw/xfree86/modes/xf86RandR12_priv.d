module xf86RandR12_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xdefs;
//public import externs.X11.extensions._render;

public import include.randrstr;
public import xf86RandR12;
import dix.colormapst;


void xf86RandR12LoadPalette(ScrnInfoPtr pScrn, int numColors, int* indices, LOCO* colors, VisualPtr pVisual);
Bool xf86RandR12InitGamma(ScrnInfoPtr pScrn, uint gammaSize);

void xf86RandR12CloseScreen(ScreenPtr pScreen);
Bool xf86RandR12CreateScreenResources(ScreenPtr pScreen);

 /* _XSERVER_XF86RANDR12_PRIV_H_ */
