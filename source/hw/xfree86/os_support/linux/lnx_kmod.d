module hw.xfree86.os_support.linux.lnx_kmod;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import core.stdc.errno;
import core.sys.posix.fcntl;
import core.sys.posix.unistd;
import core.sys.posix.sys.wait;
import core.stdc.signal;
import include.xf86_OSlib;
import include.xf86;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.socket;
import core.sys.posix.sys.un;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import core.stdc.errno;
import core.stdc.stdlib;
import core.sys.posix.stdlib;

import os.log_priv;

import os.os;
import xf86_priv;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_os_support;
import include.xf86_OSproc;;
import include.xf86Privstr;

import os.log;
import xf86Events;
import xf86Globals;
import externs.sys.sysmacros;;
import os.utils;

enum MODPROBE_PATH_FILE =      "/proc/sys/kernel/modprobe";
enum MAX_PATH =                1024;

version (none) {
/* XFree86 #defines execl to be the xf86execl() function which does
 * a fork AND exec.  We don't want that.  We want the regular,
 * standard execl().
 */
version (execl) {
}
}

/*
 * Load a Linux kernel module.
 * This is used by the DRI/DRM to load a DRM kernel module when
 * the X server starts.  It could be used for other purposes in the future.
 * Input:
 *    modName - name of the kernel module (Ex: "tdfx")
 * Return:
 *    0 for failure, 1 for success
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86LoadKernelModule(const(char)* modName)
{
    char[MAX_PATH] mpPath = "";
    int fd = -1, status = void;
    pid_t pid = void;

    /* get the path to the modprobe program */
    fd = open(MODPROBE_PATH_FILE, O_RDONLY);
    if (fd >= 0) {
        int count = cast(int)read(fd, mpPath.ptr, MAX_PATH - 1);

        if (count <= 0) {
            mpPath[0] = 0;
        }
        else if (mpPath[count - 1] == '\n') {
            mpPath[count - 1] = 0;      /* replaces \n with \0 */
        }
        close(fd);
        /* if this worked, mpPath will be "/sbin/modprobe" or similar. */
    }

    if (mpPath[0] == 0) {
        /* we failed to get the path from the system, use a default */
        strcpy(mpPath.ptr, "/sbin/modprobe");
    }

    /* now fork/exec the modprobe command */
    /*
     * It would be good to capture stdout/stderr so that it can be directed
     * to the log file.  modprobe errors currently are missing from the log
     * file.
     */
    switch (pid = fork()) {
    case 0:                    /* child */
        /* change real/effective user ID to 0/0 as we need to
         * preinstall agpgart module for some DRM modules
         */
        if (setreuid(0, 0)) {
            LogMessageVerb(X_WARNING, 1, "LoadKernelModule: "
                           ~ "Setting of real/effective user Id to 0/0 failed");
        }
        setenv("PATH", "/sbin", 1);
        execl(mpPath.ptr, "modprobe", modName, null);
        LogMessageVerb(X_WARNING, 1, "LoadKernelModule %s\n", strerror(errno));
        exit(EXIT_FAILURE);     /* if we get here the child's exec failed */
        break;
    case -1:                   /* fork failed */
        return 0;
    default:                   /* fork worked */
    {
        /* XXX we loop over waitpid() because it sometimes fails on
         * the first attempt.  Don't know why!
         */
        int count = 0, p = void;

        do {
            p = waitpid(pid, &status, 0);
        } while (p == -1 && count++ < 4);

        if (p == -1) {
            return 0;
        }

        if (WIFEXITED(status) && WEXITSTATUS(status) == 0) {
            return 1;           /* success! */
        }
        else {
            return 0;
        }
    }
    }

    /* never get here */
    return 0;
}
