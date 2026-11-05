module os.backtrace;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright 2008 Red Hat, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

import build.dix_config;

import include.os;
import common.misc;

import core.stdc.errno;
import core.stdc.string;

version (Windows) {} else {
import core.sys.posix.sys.wait;
}

version (HAVE_LIBUNWIND) {

version = UNW_LOCAL_ONLY;
import libunwind;

 

import core.sys.posix.dlfcn;

private void print_registers(int frame, unw_cursor_t cursor)
{
    struct _Regs
    {
        const(char)* name;
        int regnum;
    }

version (UNW_TARGET_X86_64)
{
    const _Regs[16] regs = [
        { "rax", UNW_X86_64_RAX },
        { "rbx", UNW_X86_64_RBX },
        { "rcx", UNW_X86_64_RCX },
        { "rdx", UNW_X86_64_RDX },
        { "rsi", UNW_X86_64_RSI },
        { "rdi", UNW_X86_64_RDI },
        { "rbp", UNW_X86_64_RBP },
        { "rsp", UNW_X86_64_RSP },
        { " r8", UNW_X86_64_R8  },
        { " r9", UNW_X86_64_R9  },
        { "r10", UNW_X86_64_R10 },
        { "r11", UNW_X86_64_R11 },
        { "r12", UNW_X86_64_R12 },
        { "r13", UNW_X86_64_R13 },
        { "r14", UNW_X86_64_R14 },
        { "r15", UNW_X86_64_R15 },
    ];
}
else
{
    const _Regs[] regs = [];
}

    const int num_regs = cast(int) regs.length;

    int ret;
    int i;

    if (num_regs == 0)
        return;

    /*
     * Advance the cursor from the signal frame to the one that triggered the
     * signal.
     */
    frame++;
    ret = unw_step(&cursor);

    if (ret < 0) {
        ErrorF("unw_step failed: %s [%d]\n", unw_strerror(ret), ret);
        return;
    }

    ErrorF("\n");
    ErrorF("Registers at frame #%d:\n", frame);

    for (i = 0; i < num_regs; i++) {
        unw_word_t val;

        ret = unw_get_reg(&cursor, regs[i].regnum, &val);

        if (ret < 0) {
            ErrorF("unw_get_reg(%s) failed: %s [%d]\n",
                   regs[i].name,
                   unw_strerror(ret),
                   ret);
        }
        else {
            ErrorF("  %s: 0x%" ~ PRIxPTR ~ "\n",
                   regs[i].name,
                   val);
        }
    }
}
void xorg_backtrace()
{
    unw_cursor_t cursor = void, signal_cursor = void;
    unw_context_t context = void;
    unw_word_t ip = void;
    unw_word_t off = void;
    unw_proc_info_t pip = void;
    int ret = void, i = 0, signal_frame = -1;
    char[256] procname = void;
    const(char)* filename = void;
    Dl_info dlinfo = void;

    pip.unwind_info = null;
    ret = unw_getcontext(&context);
    if (ret) {
        ErrorF("unw_getcontext failed: %s [%d]\n", unw_strerror(ret), ret);
        return;
    }

    ret = unw_init_local(&cursor, &context);
    if (ret) {
        ErrorF("unw_init_local failed: %s [%d]\n", unw_strerror(ret), ret);
        return;
    }

    ErrorF("\n");
    ErrorF("Backtrace:\n");
    ret = unw_step(&cursor);
    while (ret > 0) {
        ret = unw_get_proc_info(&cursor, &pip);
        if (ret) {
            ErrorF("unw_get_proc_info failed: %s [%d]\n", unw_strerror(ret), ret);
            break;
        }

        off = 0;
        ret = unw_get_proc_name(&cursor, procname.ptr, 256, &off);
        if (ret && ret != -UNW_ENOMEM) {
            if (ret != -UNW_EUNSPEC)
                ErrorF("unw_get_proc_name failed: %s [%d]\n", unw_strerror(ret), ret);
            procname[0] = '?';
            procname[1] = 0;
        }

        if (unw_get_reg (&cursor, UNW_REG_IP, &ip) < 0)
          ip = pip.start_ip + off;
        if (dladdr(cast(void*)cast(uintptr_t)(ip), &dlinfo) && dlinfo.dli_fname &&
                *dlinfo.dli_fname)
            filename = dlinfo.dli_fname;
        else
            filename = "?";


        if (unw_is_signal_frame(&cursor)) {
            signal_cursor = cursor;
            signal_frame = i;

            ErrorF("%u: <signal handler called>\n", i++);
        } else {
            ErrorF("%u: %s (%s%s+0x%x) [%p]\n", i++, filename, procname.ptr,
                   ret == -UNW_ENOMEM ? "..." : "", cast(int)off,
                cast(void*)cast(uintptr_t)(ip));
        }

        ret = unw_step(&cursor);
        if (ret < 0)
            ErrorF("unw_step failed: %s [%d]\n", unw_strerror(ret), ret);
    }

    if (signal_frame >= 0)
        print_registers(signal_frame, signal_cursor);

    ErrorF("\n");
}
} else { /* HAVE_LIBUNWIND */
version (HAVE_BACKTRACE) {
 

import core.sys.posix.dlfcn;
import execinfo;

enum BT_SIZE = 64;
void xorg_backtrace()
{
    void*[BT_SIZE] array = void;
    const(char)* mod = void;
    int size = void, i = void;
    Dl_info info = void;

    ErrorF("\n");
    ErrorF("Backtrace:\n");
    size = backtrace(array.ptr, BT_SIZE);
    for (i = 0; i < size; i++) {
        int rc = dladdr(array[i], &info);

        if (rc == 0) {
            ErrorF("%u: ?? [%p]\n", i, array[i]);
            continue;
        }
        mod = (info.dli_fname && *info.dli_fname) ? info.dli_fname : "(vdso)";
        if (info.dli_saddr)
            ErrorF(
                "%u: %s (%s+0x%x) [%p]\n",
                i,
                mod,
                info.dli_sname,
                cast(uint)(cast(char*) array[i] -
                               cast(char*) info.dli_saddr),
                array[i]);
        else
            ErrorF(
                "%u: %s (%p+0x%x) [%p]\n",
                i,
                mod,
                info.dli_fbase,
                cast(uint)(cast(char*) array[i] -
                               cast(char*) info.dli_fbase),
                array[i]);
    }
    ErrorF("\n");
}

} else {                           /* not glibc or glibc < 2.1 */

static if (HasVersion!"__sun" && HasVersion!"__SVR4") {
version = HAVE_PSTACK;
}

version (HAVE_WALKCONTEXT) {   /* Solaris 9 & later */

import core.sys.posix.ucontext;
import core.stdc.signal;
import core.sys.posix.dlfcn;
import sys.elf;

version (_LP64) {
enum ElfSym = Elf64_Sym;
} else {
enum ElfSym = Elf32_Sym;
}

/* Called for each frame on the stack to print its contents */
private int xorg_backtrace_frame(uintptr_t pc, int signo, void* arg)
{
    Dl_info dlinfo = void;
    ElfSym* dlsym = void;
    char[32] header = void;
    int depth = *(cast(int*) arg);

    if (signo) {
        char[SIG2STR_MAX] signame = void;

        if (sig2str(signo, signame.ptr) != 0) {
            strcpy(signame.ptr, "unknown");
        }

        ErrorF("** Signal %u (%s)\n", signo, signame.ptr);
    }

    snprintf(header.ptr, header.sizeof, "%d: 0x%lx", depth, pc);
    *(cast(int*) arg) = depth + 1;

    /* Ask system dynamic loader for info on the address */
    if (dladdr1(cast(void*) pc, &dlinfo, cast(void**) &dlsym, RTLD_DL_SYMENT)) {
        c_ulong offset = pc - cast(uintptr_t) dlinfo.dli_saddr;
        const(char)* symname = void;

        if (offset < dlsym.st_size) {  /* inside a function */
            symname = dlinfo.dli_sname;
        }
        else {                  /* found which file it was in, but not which function */
            symname = "<section start>";
            offset = pc - cast(uintptr_t) dlinfo.dli_fbase;
        }
        ErrorF("%s: %s:%s+0x%x\n", header.ptr, dlinfo.dli_fname, symname, offset);

    }
    else {
        /* Couldn't find symbol info from system dynamic loader, should
         * probably poke elfloader here, but haven't written that code yet,
         * so we just print the pc.
         */
        ErrorF("%s\n", header.ptr);
    }

    return 0;
}
}                          /* HAVE_WALKCONTEXT */

version (HAVE_PSTACK) {
import core.sys.posix.unistd;

private int xorg_backtrace_pstack()
{
    pid_t kidpid = void;
    int[2] pipefd = void;

    if (pipe(pipefd.ptr) != 0) {
        return -1;
    }

    kidpid = fork1();

    if (kidpid == -1) {
        /* ERROR */
        return -1;
    }
    else if (kidpid == 0) {
        /* CHILD */
        char[16] parent = void;

        seteuid(0);
        close(STDIN_FILENO);
        close(STDOUT_FILENO);
        dup2(pipefd[1], STDOUT_FILENO);
        closefrom(STDERR_FILENO);

        snprintf(parent.ptr, parent.sizeof, "%d", getppid());
        execle("/usr/bin/pstack", "pstack", parent.ptr, null);
        exit(1);
    }
    else {
        /* PARENT */
        char[256] btline = void;
        int kidstat = void;
        int bytesread = void;
        int done = 0;

        close(pipefd[1]);

        while (!done) {
            bytesread = read(pipefd[0], btline.ptr, ((btline).ptr - 1).sizeof);

            if (bytesread > 0) {
                btline[bytesread] = 0;
                ErrorF("%s", btline.ptr);
            }
            else if ((bytesread < 0) || ((errno != EINTR) && (errno != EAGAIN)))
                done = 1;
        }
        close(pipefd[0]);
        waitpid(kidpid, &kidstat, 0);
        if (kidstat != 0)
            return -1;
    }
    return 0;
}
}                          /* HAVE_PSTACK */

static if (HasVersion!"HAVE_PSTACK" || HasVersion!"HAVE_WALKCONTEXT") {

void xorg_backtrace()
{

    ErrorF("\n");
    ErrorF("Backtrace:\n");

version (HAVE_PSTACK) {
/* First try fork/exec of pstack - otherwise fall back to walkcontext
   pstack is preferred since it can print names of non-exported functions */

    if (HAVE_PSTACK && xorg_backtrace_pstack() < 0)
    {
version (HAVE_WALKCONTEXT) {
        ucontext_t u = void;
        int depth = 1;

        if (getcontext(&u) == 0)
            walkcontext(&u, &xorg_backtrace_frame, &depth);
        else 
        ErrorF("Failed to get backtrace info: %s\n", strerror(errno));
}
else 
        ErrorF("Failed to get backtrace info: %s\n", strerror(errno));
    }
    ErrorF("\n");}
}

} else {

/* Default fallback if we can't find any way to get a backtrace */
void xorg_backtrace()
{
    return;
}

}
}
}
