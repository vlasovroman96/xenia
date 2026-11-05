module common.xlibre_ptrtypes;

public import x11.Xdefs;
import hw.xfree86.common.xf86str;
import os.client_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 *
 * @brief
 * This header holds forward definitions for pointer types used in many places.
 * Helpful for uncluttering the includes a bit, so we have less complex dependencies.
 *
 * External drivers rarely have a reason for directly including it.
 */
 
// struct _Client;
// version (_XTYPEDEF_CLIENTPTR) {

// alias ClientPtr = _Client*;
// } else {
// version = _XTYPEDEF_CLIENTPTR;
// }
alias ClientRec = _Client;

public import dix.window_priv;

// struct _ClientId;
alias ClientIdPtr = _ClientId*;

// struct _Window;
alias WindowPtr = _Window*;
alias WindowRec = _Window;

// struct _ScrnInfoRec;
alias ScrnInfoPtr = _ScrnInfoRec*;
alias ScrnInfoRec = _ScrnInfoRec;

 /* _XLIBRE_SDK_PTRTYPES_H */
