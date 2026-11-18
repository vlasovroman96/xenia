module dix.devCursor;

@nogc nothrow:
extern(C): 

/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026, Roman Vlasov
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright (c) 2006, Red Hat, Inc.
 * Copyright 1987, 1998  The Open Group
 * Copyright (c) 1991, 1997 Digital Equipment Corporation, Maynard, Massachusetts.
 * Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts,
 * 
 * See COPYING for the full license texts.
 * 
 */

public import common.list;
public import dix.cursor;
public import dix.inputstr;

/* used as NULL-terminated list */
struct DevCursNodeRec {
    CursorPtr cursor;
    DeviceIntPtr dev;
    DevCursNodeRec* next;
}

alias DevCursNodePtr = DevCursNodeRec*;
alias DevCursorList = DevCursNodeRec*;
