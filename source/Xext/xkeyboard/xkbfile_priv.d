module xkb.xkbfile_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 1994 by Silicon Graphics Computer Systems, Inc.
 */
 
public import core.stdc.stdio;
//public import x11.X;
//public import x11.Xdefs;

public import xkb.xkbsrv_priv;
import xkb.xkbstr;


/* XKB error codes */
enum _XkbErrMissingNames =		1;
enum _XkbErrMissingTypes =		2;
enum _XkbErrMissingReqTypes =		3;
enum _XkbErrMissingSymbols =		4;
enum _XkbErrMissingCompatMap =		7;
enum _XkbErrMissingGeometry =		9;
enum _XkbErrIllegalContents =		12;
enum _XkbErrBadValue =			16;
enum _XkbErrBadMatch =			17;
enum _XkbErrBadTypeName =		18;
enum _XkbErrBadTypeWidth =		19;
enum _XkbErrBadFileType =		20;
enum _XkbErrBadFileVersion =		21;
enum _XkbErrBadAlloc =			23;
enum _XkbErrBadLength =		24;
enum _XkbErrBadImplementation =	26;

/*
 * read xkm file
 *
 * @param file the FILE to read from
 * @param need mask of needed elements (fails if some are missing)
 * @param want mask of wanted elements
 * @param result pointer to xkb descriptor to load the data into
 * @return mask of elements missing (from need | want)
 */
uint XkmReadFile(FILE* file, uint need, uint want, XkbDescPtr* result);

 /* _XSERVER_XKB_XKBFILE_PRIV_H */
