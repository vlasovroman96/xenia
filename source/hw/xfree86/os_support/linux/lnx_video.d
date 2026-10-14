module lnx_video;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright 1992 by Orest Zborowski <obz@Kodak.com>
 * Copyright 1993 by David Wexelblat <dwex@goblin.org>
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the names of Orest Zborowski and David Wexelblat
 * not be used in advertising or publicity pertaining to distribution of
 * the software without specific, written prior permission.  Orest Zborowski
 * and David Wexelblat make no representations about the suitability of this
 * software for any purpose.  It is provided "as is" without express or
 * implied warranty.
 *
 * OREST ZBOROWSKI AND DAVID WEXELBLAT DISCLAIMS ALL WARRANTIES WITH REGARD
 * TO THIS SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
 * FITNESS, IN NO EVENT SHALL OREST ZBOROWSKI OR DAVID WEXELBLAT BE LIABLE
 * FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES
 * WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS, WHETHER IN AN
 * ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION, ARISING OUT OF
 * OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS SOFTWARE.
 *
 */
import build.xorg_config;

import core.stdc.errno;
import core.stdc.string;
import core.sys.posix.sys.mman;
//import x11.X;

import include.input;
import include.scrnintstr;

import include.xf86;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86Priv;
import include.xf86_OSlib;
import os.log;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd;
import externs.gnu;

private Bool ExtendedEnabled = FALSE;

version (__IA64__) {

import hw.xfree86.utils.compiler;
import sys.io;

} 
static if (!HasVersion!"__powerpc__" && 
      !HasVersion!"__mc68000__" && 
      !HasVersion!"__sparc__" && 
      !HasVersion!"__mips__" && 
      !HasVersion!"__nds32__" && 
      !HasVersion!"__arm__" && 
      !HasVersion!"__aarch64__" && 
      !HasVersion!"__arc__" && 
      !HasVersion!"__xtensa__") {

/*
 * Due to conflicts with "compiler.h", don't rely on <sys/io.h> to declare
 * these.
 */
int ioperm(c_ulong __from, c_ulong __num, int __turn_on);
int iopl(int __level);

}

/***************************************************************************/
/* Video Memory Mapping section                                            */
/***************************************************************************/

void xf86OSInitVidMem(VidMemInfoPtr pVidMem)
{
    pVidMem.initialised = TRUE;
}

/***************************************************************************/
/* I/O Permissions section                                                 */
/***************************************************************************/

version (__powerpc__) {
/*volatile*/ ubyte* ioBase = null;

enum __NR_pciconfig_iobase =	200;


private Bool hwEnableIO()
{
    int fd = void;
    uint ioBase_phys = syscall(__NR_pciconfig_iobase, 2, 0, 0);

    fd = open("/dev/mem", O_RDWR);
    if (ioBase is null) {
        ioBase = cast(/*volatile*/ ubyte*) mmap(0, 0x20000,
                                                 PROT_READ | PROT_WRITE,
                                                 MAP_SHARED, fd, ioBase_phys);
    }
    close(fd);

    return ioBase != MAP_FAILED;
}

private void hwDisableIO()
{
    munmap(ioBase, 0x20000);
    ioBase = null;
}

} else static if (HasVersion!"__i386__" || HasVersion!"X86_64" || 
      HasVersion!"Alpha") {

private Bool hwEnableIO()
{
    short i = void;
    size_t n = 0;
    int begin = void, end = void;
    char* buf = null; char[5] target = void;
    FILE* fp = void;

    /* xf86-video-vesa and others (at least mach64) need access to all I/O ports */
    if (iopl(3)) {
        ErrorF("xf86EnableIO: failed to set I/O privilege level to 3 (%s)\n",
           strerror(errno));
        /* Since Linux 2.6.8, 65,536 I/O ports can be specified */
        if (ioperm(0, 65536, 1)) {
            ErrorF("xf86EnableIO: failed to enable I/O ports 0000-ffff (%s)\n",
               strerror(errno));
            if (ioperm(0, 1024, 1)) {
                ErrorF("xf86EnableIO: failed to enable I/O ports 0000-03ff (%s)\n",
                   strerror(errno));
                return FALSE;
            }
        }
    }

static if (!HasVersion!"Alpha") {
    target[4] = '\0';

    /* trap access to the keyboard controller(s) and timer chip(s) */
    fp = fopen("/proc/ioports", "r");
    while (getline(&buf, &n, fp) != -1) {
        if ((strstr(buf, "keyboard") !is null) || (strstr(buf, "timer") !is null)) {
            for (i=0; i<4; i++)
                target[i] = buf[i+2];
            begin = atoi(target.ptr);

            for (i=0; i<4; i++)
                target[i] = buf[i+7];
            end = atoi(target.ptr);

            ioperm(begin, end-begin+1, 0);
        }
    }
    free(buf);
    fclose(fp);
}

    return TRUE;
}

private void hwDisableIO()
{
    iopl(0);
    ioperm(0, 1024, 0);
}

} else { /* non-IO architectures */

enum string hwEnableIO() = `TRUE`;
enum string hwDisableIO() = ``;

}


//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86EnableIO()
{
    if (ExtendedEnabled)
        return TRUE;

    ExtendedEnabled = hwEnableIO();

    return ExtendedEnabled;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86DisableIO()
{
    if (!ExtendedEnabled)
        return;

    hwDisableIO();

    ExtendedEnabled = FALSE;
}
