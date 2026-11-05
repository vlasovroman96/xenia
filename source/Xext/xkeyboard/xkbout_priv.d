module xkb.xkbout_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import core.stdc.stdio;
//public import x11.X;
//public import x11.Xdefs;

public import xkb.xkbsrv_priv;
// import externs.X11.extensions.XKBstr;
import xkb.xkbstr;


alias XkbFileAddOnFunc = void function(FILE* file, XkbDescPtr result, Bool topLevel, Bool showImplicit, int fileSection, void* priv);

Bool XkbWriteXKBKeyTypes(FILE* file, XkbDescPtr result, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv);
Bool XkbWriteXKBKeycodes(FILE* file, XkbDescPtr result, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv);
Bool XkbWriteXKBCompatMap(FILE* file, XkbDescPtr result, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv);
Bool XkbWriteXKBSymbols(FILE* file, XkbDescPtr result, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv);
Bool XkbWriteXKBGeometry(FILE* file, XkbDescPtr result, Bool topLevel, Bool showImplicit, XkbFileAddOnFunc addOn, void* priv);

 /* _XSERVER_XKB_XKBFOUT_PRIV_H */
