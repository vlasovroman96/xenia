module composite.compositeext_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 1987, 1998  The Open Group
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import x11.Xdefs;

public import dix.scrintstr;

Bool CompositeIsImplicitRedirectException(ScreenPtr pScreen, XID parentVisual, XID winVisual);

 /* _XSERVER_COMPOSITEEXT_PRIV_H_ */
