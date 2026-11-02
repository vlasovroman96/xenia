module fb.fbpict_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import externs.X11.extensions.renderproto;

public import fb.fbpict;
public import include.picture;

// void fbRasterizeTrapezoid(PicturePtr alpha, xTrapezoid* trap, int x_off, int y_off);

// void fbAddTriangles(PicturePtr pPicture, INT16 xOff, INT16 yOff, int ntri, xTriangle* tris);

// void fbTrapezoids(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntrap, xTrapezoid* traps);

// void  fbTriangles(CARD8 op, PicturePtr pSrc, PicturePtr pDst, PictFormatPtr maskFormat, INT16 xSrc, INT16 ySrc, int ntris, xTriangle* tris);

 /* XORG_FBPICT_PRIV_H */
