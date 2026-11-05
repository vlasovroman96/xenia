module os.serverlock;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
/*

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts,
Copyright 1994 Quarterdeck Office Systems.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the names of Digital and
Quarterdeck not be used in advertising or publicity pertaining to
distribution of the software without specific, written prior
permission.

DIGITAL AND QUARTERDECK DISCLAIM ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND
FITNESS, IN NO EVENT SHALL DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT
OR CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS
OF USE, DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE
OR PERFORMANCE OF THIS SOFTWARE.

*/
import build.dix_config;

import core.stdc.errno;
import core.sys.posix.fcntl;
// //import stdbool;
import core.stdc.string;
import core.sys.posix.sys.stat;
import core.sys.posix.unistd;

import dix.dix_priv;
import os.serverlock;
import os.osdep;

import os.os;

/*
 * Explicit support for a server lock file like the ones used for UUCP.
 * For architectures with virtual terminals that can run more than one
 * server at a time.  This keeps the servers from stomping on each other
 * if the user forgets to give them different display numbers.
 */
enum LOCK_DIR = "/tmp";
enum LOCK_TMP_PREFIX = "/.tX";
enum LOCK_PREFIX = "/.X";
enum LOCK_SUFFIX = "-lock";

version (LOCK_SERVER) {

private Bool StillLocking = FALSE;
private char[PATH_MAX] LockFile = 0;
private Bool nolock = FALSE;

/*
 * LockServer --
 *      Check if the server lock file exists.  If so, check if the PID
 *      contained inside is valid.  If so, then die.  Otherwise, create
 *      the lock file containing the PID.
 */
void LockServer()
{
    char[PATH_MAX] tmp = void; char[12] pid_str = void;
    int lfd = void, i = void, haslock = void, l_pid = void, t = void;
    const(char)* tmppath = LOCK_DIR;
    int len = void;
    char[20] port = void;

    if (nolock || NoListenAll)
        return;
    /*
     * Path names
     */
    snprintf(port.ptr, port.sizeof, "%d", atoi(display));
    len = strlen(LOCK_PREFIX) > strlen(LOCK_TMP_PREFIX) ? strlen(LOCK_PREFIX) :
        strlen(LOCK_TMP_PREFIX);
    len += strlen(tmppath) + strlen(port.ptr) + strlen(LOCK_SUFFIX) + 1;
    if (len > LockFile.sizeof)
        FatalError("Display name `%s' is too long\n", port.ptr);
    cast(void) sprintf(tmp.ptr, "%s" ~LOCK_TMP_PREFIX ~ "%s"~ LOCK_SUFFIX, tmppath, port.ptr);
    cast(void) sprintf(LockFile.ptr, "%s"~ LOCK_PREFIX ~ "%s"~ LOCK_SUFFIX, tmppath, port.ptr);

    /*
     * Create a temporary file containing our PID.  Attempt three times
     * to create the file.
     */
    StillLocking = TRUE;
    i = 0;
    do {
        i++;
        lfd = open(tmp.ptr, O_CREAT | O_EXCL | O_WRONLY, octal!"0644");
        if (lfd < 0)
            sleep(2);
        else
            break;
    } while (i < 3);
    if (lfd < 0) {
        unlink(tmp.ptr);
        i = 0;
        do {
            i++;
            lfd = open(tmp.ptr, O_CREAT | O_EXCL | O_WRONLY, octal!"0644");
            if (lfd < 0)
                sleep(2);
            else
                break;
        } while (i < 3);
    }
    if (lfd < 0)
        FatalError("Could not create lock file in %s\n", tmp.ptr);
    snprintf(pid_str.ptr, pid_str.sizeof, "%10lu\n", cast(c_ulong) getpid());
    if (write(lfd, pid_str.ptr, 11) != 11)
        FatalError("Could not write pid to lock file in %s\n", tmp.ptr);
    cast(void) fchmod(lfd, octal!"0444");
    cast(void) close(lfd);

    /*
     * OK.  Now the tmp file exists.  Try three times to move it in place
     * for the lock.
     */
    i = 0;
    haslock = 0;
    while ((!haslock) && (i++ < 3)) {
        haslock = (link(tmp.ptr, LockFile.ptr) == 0);
        if (haslock) {
            /*
             * We're done.
             */
            break;
        }
        else if (errno == EEXIST) {
            /*
             * Read the pid from the existing file
             */
            lfd = open(LockFile.ptr, O_RDONLY | O_NOFOLLOW);
            if (lfd < 0) {
                unlink(tmp.ptr);
                FatalError("Can't read lock file %s\n", LockFile.ptr);
            }
            pid_str[0] = '\0';
            if (read(lfd, pid_str.ptr, 11) != 11) {
                /*
                 * Bogus lock file.
                 */
                unlink(LockFile.ptr);
                close(lfd);
                continue;
            }
            pid_str[11] = '\0';
            sscanf(pid_str.ptr, "%d", &l_pid);
            close(lfd);

            /*
             * Now try to kill the PID to see if it exists.
             */
            errno = 0;
            t = kill(l_pid, 0);
            if ((t < 0) && (errno == ESRCH)) {
                /*
                 * Stale lock file.
                 */
                unlink(LockFile.ptr);
                continue;
            }
            else if (((t < 0) && (errno == EPERM)) || (t == 0)) {
                /*
                 * Process is still active.
                 */
                unlink(tmp.ptr);
                FatalError
                    ("Server is already active for display %s\n%s %s\n%s\n",
                     port.ptr, "\tIf this server is no longer running, remove",
                     LockFile.ptr, "\tand start again.");
            }
        }
        else {
            unlink(tmp.ptr);
            FatalError
                ("Linking lock file (%s) in place failed: %s\n",
                 LockFile.ptr, strerror(errno));
        }
    }
    unlink(tmp.ptr);
    if (!haslock)
        FatalError("Could not create server lock file: %s\n", LockFile.ptr);
    StillLocking = FALSE;
}

/*
 * UnlockServer --
 *      Remove the server lock file.
 */
void UnlockServer()
{
    if (nolock || NoListenAll)
        return;

    if (!StillLocking) {

        cast(void) unlink(LockFile.ptr);
    }
}

void DisableServerLock() {
    nolock = TRUE;
}

void LockServerUseMsg() {
    ErrorF("-nolock                disable the locking mechanism\n");
}

} else { /* LOCK_SERVER */

void LockServer() {}
void UnlockServer() {}
void DisableServerLock() {}
void LockServerUseMsg() {}

} /* LOCK_SERVER */
