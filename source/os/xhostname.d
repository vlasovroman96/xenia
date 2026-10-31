module os.xhostname;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
import build.dix_config;

// import core.stdc.errno;
// import core.stdc.string;
// import core.sys.posix.unistd;

// version(Windows) {
// import winsock;
// }

import os.xhostname;
// import include.picture;
// import mi.miinitext;
// import dix.dixstruct_priv;
import Xext.dpmsproc;
import core.sys.posix.fcntl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.ipc;
import core.sys.posix.sys.shm;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;
import core.sys.posix.stdio;
import core.stdc.stdio;

// import core.sys.posix.stdio;
// import os.connection;
import core.sys.posix.unistd;

version = X_INCLUDE_NETDB_H;
// //import x11.Xos_r;

import core.stdc.errno;
// import Xext.dpms;
import std.stdio;
import core.stdc.stdio;

enum XHOSTNAME_MAX = 2048;

struct xhostname {
    char[XHOSTNAME_MAX] name;
};

int f_xhostname(xhostname* hn)
{
    /* being extra-paranoid here */
    memset(hn, 0, xhostname.sizeof);
    int ret = gethostname(hn.name.ptr, typeof(hn.name).sizeof);

    if (ret == -1) {
        hn.name[0] = 0;
        return errno;
    }

    hn.name[((hn.name.sizeof)-1)] = 0;
    return ret;
}
