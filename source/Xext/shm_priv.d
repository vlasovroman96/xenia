module Xext.shm_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */

 
public import dix.resource;
public import include.shmint;
import os.busfault;
import x11.Xdefs;

struct _ShmDesc {
    _ShmDesc* next;
    int shmid;
    int refcnt;
    char* addr;
    Bool writable;
    c_ulong size;
// version (SHM_FD_PASSING) {
    Bool is_fd;
    busfault* _busfault;
    XID resource;
// }
}alias ShmDescRec = _ShmDesc;
alias ShmDescPtr = _ShmDesc*;

RESTYPE ShmSegType;

 /* _XSERVER_XEXT_SHM_PRIV_H */
