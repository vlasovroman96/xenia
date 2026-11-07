module os.busfault;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2013 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */

import build.dix_config;

// //import x11.Xos;
//import x11.Xdefs;

import os.busfault;

import common.misc;
import common.list;
import core.stdc.stddef;
import core.stdc.stdlib;
import core.stdc.stdint;
import core.sys.posix.sys.mman;
import core.stdc.signal;
import os.log;
import externs.attrs;

alias busfault_notify_ptr = void function(void *context);

struct busfault {
    XList list;

    void* addr;
    size_t size;

    Bool valid;

    busfault_notify_ptr notify;
    void* context;
}

private Bool busfaulted;
private XList busfaults;

busfault* busfault_register_mmap(void* addr, size_t size, busfault_notify_ptr notify, void* context)
{
    busfault* busfault_ = void;

    busfault_ = cast(busfault*) cast(busfault*) calloc(1, busfault.sizeof);
    if (!busfault_)
        return null;

    busfault_.addr = addr;
    busfault_.size = size;
    busfault_.notify = notify;
    busfault_.context = context;
    busfault_.valid = TRUE;

    busfaults.addListNext(&busfault_.list);
    return busfault_;
}

void busfault_unregister(busfault* busfault)
{
    busfault.list.removeFromList();
    free(busfault);
}

void busfault_check()
{
    busfault* busfault = void, tmp = void;

    if (!busfaulted)
        return;

    busfaulted = FALSE;

    mixin(xorg_list_for_each_entry_safe!("busfault", "tmp", "&busfaults", "list", q{
        if (!busfault.valid)
            (*busfault.notify)(busfault.context);
    }));
}

private void function(int sig, siginfo_t* info, void* param) previous_busfault_sigaction;

private void busfault_sigaction(int sig, siginfo_t* info, void* param)
{
    void* fault = info.si_addr;
    busfault* busfault_ = null;
    void* new_addr = void;

    /* Locate the faulting address in our list of shared segments
     */
    foreach(iter; busfaults.byEntries!busfault) {
        if (cast(char*) iter.addr <= cast(char*) fault && cast(char*) fault < cast(char*) iter.addr + iter.size) {
            busfault_ = iter;
            break;
        }
    }
    if (!busfault_)
        goto panic_;

    if (!busfault_.valid)
        goto panic_;

    busfault_.valid = FALSE;
    busfaulted = TRUE;

    /* The client truncated the file; unmap the shared file, map
     * /dev/zero over that area and keep going
     */

    new_addr = mmap(busfault_.addr, busfault_.size, PROT_READ|PROT_WRITE,
                    MAP_ANON|MAP_PRIVATE|MAP_FIXED, -1, 0);

    if (new_addr == MAP_FAILED)
        goto panic_;

    return;
panic_:
    if (previous_busfault_sigaction)
        (*previous_busfault_sigaction)(sig, info, param);
    else
        FatalError("bus error\n");
}

Bool busfault_init()
{
    sigaction_t act = void, old_act = void;

    act.sa_sigaction = &busfault_sigaction;
    act.sa_flags = SA_SIGINFO;
    sigemptyset(&act.sa_mask);
    if (sigaction(SIGBUS, &act, &old_act) < 0)
        return FALSE;
    previous_busfault_sigaction = assumeNoGC(old_act.sa_sigaction);
    busfaults.initList();
    return TRUE;
}
