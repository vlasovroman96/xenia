module common.servermd;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2026, Roman Vlasov
 * Copyright 1987, 1998  The Open Group
 * Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.
 *
 * See COPYING for the full license texts.
 */

import build.dix_config;

import x11.X;		/* for X_LITTLE_ENDIAN/X_BIG_ENDIAN */

enum IMAGE_BYTE_ORDER = 
    (X_BYTE_ORDER == X_LITTLE_ENDIAN) ? LSBFirst : MSBFirst;
enum BITMAP_BIT_ORDER = 
    (X_BYTE_ORDER == X_LITTLE_ENDIAN) ? LSBFirst : MSBFirst;