module os.log;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
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

/*
 * Copyright (c) 1997-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */

version = _POSIX_THREAD_SAFE_FUNCTIONS; // for localtime_r on mingw32

import build.dix_config;

import core.stdc.errno;
import core.stdc.stdio;
import core.stdc.stdarg;
import core.stdc.stdlib;             /* for calloc() */
import core.stdc.string;             /* for strerror*() */
import core.sys.posix.sys.stat;
import core.stdc.time;
// //import x11.Xfuncproto;
// //import x11.Xos;
import externs.gnu;
import core.sys.posix.unistd;
import core.sys.posix.fcntl;
import os.WaitFor;



version (CONFIG_SYSLOG) {
import core.sys.posix.syslog;
}

import dix.dix_priv;
import dix.input_priv;
import os.audit_priv;
import os.bug_priv;
import os.ddx_priv;
import os.fmt;
import os.log_priv;
// import os.osdep;


version (XF86BIGFONT) {
import Xext.xf86bigfontsrv;
}

version (__clang__) {
// #pragma clang diagnostic ignored "-Wformat-nonliteral"
}
import core.sys.posix.pthread;

/* Default logging parameters. */
enum DEFAULT_LOG_VERBOSITY =		0;
enum DEFAULT_LOG_FILE_VERBOSITY =	3;
enum DEFAULT_SYSLOG_VERBOSITY =	0;

private int logFileFd = -1;
Bool xorgLogSync = False;
int xorgLogVerbosity = DEFAULT_LOG_VERBOSITY;
int xorgLogFileVerbosity = DEFAULT_LOG_FILE_VERBOSITY;
// version (CONFIG_SYSLOG) {
// int xorgSyslogVerbosity = DEFAULT_SYSLOG_VERBOSITY;
// const(char)* xorgSyslogIdent = "X";
// }

/* Buffer to information logged before the log file is opened. */
private char* saveBuffer = null;
private int bufferSize = 0, bufferUnused = 0, bufferPos = 0;
private Bool needBuffer = True;

// version (OSX) {
// private char[4096] __crashreporter_info_buff__ = 0;

// // private const(char)* __crashreporter_info__; __attribute__ ((__used__)) =
//     __gshared const(char)* __crashreporter_info__;

//     static this()
//     {
//         __crashreporter_info__ = &__crashreporter_info_buff__[0];
//     }
// }

/* Prefix strings for log messages. */
enum X_UNKNOWN_STRING =		"(\?\?)";
enum X_PROBE_STRING =			"(--)";
enum X_CONFIG_STRING =			"(**)";
enum X_DEFAULT_STRING =		"(==)";
enum X_CMDLINE_STRING =		"(++)";
enum X_NOTICE_STRING =			"(!!)";
enum X_ERROR_STRING =			"(EE)";
enum X_WARNING_STRING =		"(WW)";
enum X_INFO_STRING =			"(II)";
enum X_NOT_IMPLEMENTED_STRING =	"(NI)";
enum X_DEBUG_STRING =			"(DB)";
enum X_NONE_STRING =			"";

private size_t strlen_sigsafe(const(char)* s)
{
    size_t len = void;
    for (len = 0; s[len]; len++){}
    return len;
}

/*
 * LogFilePrep is called to setup files for logging, including getting
 * an old file out of the way, but it doesn't actually open the file,
 * since it may be used for renaming a file we're already logging to.
 */
// #pragma GCC diagnostic push
// #pragma GCC diagnostic ignored "-Wformat-nonliteral"

private char* LogFilePrep(const(char)* fname, const(char)* backup, const(char)* idstring)
{
    char* logFileName = null;

    /* the format string below is controlled by the user,
       this code should never be called with elevated privileges */
    if (asprintf(&logFileName, fname, idstring) == -1)
        FatalError("Cannot allocate space for the log file name\n");

    if (backup && *backup) {
        stat_t buf = void;

        if (!stat(logFileName, &buf) && S_ISREG(buf.st_mode)) {
            char* suffix = void;
            char* oldLog = void;

            if ((asprintf(&suffix, backup, idstring) == -1) ||
                (asprintf(&oldLog, "%s%s", logFileName, suffix) == -1)) {
                FatalError("Cannot allocate space for the log file name\n");
            }
            free(suffix);

            if (rename(logFileName, oldLog) == -1) {
                FatalError("Cannot move old log file \"%s\" to \"%s\"\n",
                           logFileName, oldLog);
            }
            free(oldLog);
        }
    }
    else {
        if (remove(logFileName) != 0 && errno != ENOENT) {
            FatalError("Cannot remove old log file \"%s\": %s\n",
                       logFileName, strerror(errno));
        }
    }

    return logFileName;
}
// #pragma GCC diagnostic pop

pragma(inline, true) private void doLogSync() {
version (Windows) {} else {
    fsync(logFileFd);
}
}

private void initSyslog() {
version (CONFIG_SYSLOG) {
    static char[4096] buffer = 0;
    strcpy(buffer.ptr, xorgSyslogIdent);

    snprintf(buffer.ptr, buffer.sizeof, "%s :%s", xorgSyslogIdent, (display ? display : "<>"));

    /* initialize syslog */
    openlog(buffer.ptr, LOG_PID, LOG_LOCAL1);
}
}

private void LogFailedWriteStdout(const(void)* buf, size_t len)
{
        if (write(STDOUT_FILENO, buf, len)==-1)
        {
	    /* We can't write to the logfile, stderr, and stdout; something
	     * bad is probably happening, but we can't really do anything */
            return;
        }
}
private void LogFailedWrite(const(void)* buf, size_t len)
{
    if (write(STDERR_FILENO, buf, len)==-1)
    {
	/* We can't even write to stderr, let's try stdout as a last resort. */
        {
            char[24] error = "Can't write to stderr: ";
            LogFailedWriteStdout(error.ptr,error.sizeof);
        }
version (Windows) {} else {
        char[256] dsc = 0;
        cast(void) !strerror_r(errno,dsc.ptr,dsc.sizeof);
} version (Windows) {
        char* dsc = void;
        dsc=strerror(errno.ptr);
}
        LogFailedWriteStdout(dsc.ptr,strlen(dsc.ptr));
        LogFailedWriteStdout("\n".ptr,1);
        {
	    char[44] error = "Intended to write the following to stderr:\n";
            LogFailedWriteStdout(error.ptr,error.sizeof);
        }
        LogFailedWriteStdout(buf,len);
    }
}

private void LogWrite(int fd, const(void)* buf, size_t len)
{
    if (write(fd, buf, len)==-1)
    {
	/* If the write() call fails, we can not log this event to the log file,
	 * but we still have the stderr.
         */
        {
            char[26] error = "Can't write to log file: ";
            LogFailedWrite(error.ptr,error.sizeof);
        }
version (Windows) {} else {
        char[256] dsc = 0;
        cast(void) !strerror_r(errno,dsc.ptr,dsc.sizeof);
} version (Windows) {
        char* dsc = void;
        dsc=strerror(errno);
}
        LogFailedWrite(dsc.ptr,strlen(dsc.ptr));
        LogFailedWrite("\n".ptr,1);
        {
            char[46] error = "Intended to write the following to log file:\n";
            LogFailedWrite(error.ptr,error.length);
        }
        LogFailedWrite(buf,len);
    }

}

/*
 * LogInit is called to start logging to a file.  It is also called (with
 * NULL arguments) when logging to a file is not wanted.  It must always be
 * called, otherwise log messages will continue to accumulate in a buffer.
 *
 * %s, if present in the fname or backup strings, is expanded to the display
 * string (or to a string containing the pid if the display is not yet set).
 */

private char* saved_log_fname;
private char* saved_log_backup;
private char* saved_log_tempname;

const(char)* LogInit(const(char)* fname, const(char)* backup)
{
    char* logFileName = null;

    if (fname && *fname) {
        if (displayfd != -1) {
            /* Display isn't set yet, so we can't use it in filenames yet. */
            char[32] pidstring = void;
            snprintf(pidstring.ptr, pidstring.sizeof, "pid-%ld",
                     cast(c_ulong) getpid());
            logFileName = LogFilePrep(fname, backup, pidstring.ptr);
            saved_log_tempname = logFileName;

            /* Save the patterns for use when the display is named. */
            saved_log_fname = strdup(fname);
            if (backup is null)
                saved_log_backup = null;
            else
                saved_log_backup = strdup(backup);
        } else
            logFileName = LogFilePrep(fname, backup, display);

        if ((logFileFd = open(logFileName, O_WRONLY | O_CREAT, S_IRUSR|S_IWUSR|S_IRGRP)) == -1)
            FatalError("Cannot open log file \"%s\": %s\n", logFileName, strerror(errno));

        /* Flush saved log information. */
        if (saveBuffer && bufferSize > 0) {
            LogWrite(logFileFd, saveBuffer, bufferPos);
            doLogSync();
        }
    }

    /*
     * Unconditionally free the buffer, and flag that the buffer is no longer
     * needed.
     */
    if (saveBuffer && bufferSize > 0) {
        free(saveBuffer);
        saveBuffer = null;
        bufferSize = 0;
    }
    needBuffer = False;

    initSyslog();
    return logFileName;
}

void LogSetDisplay()
{
    if (saved_log_fname && strstr(saved_log_fname, "%s")) {
        char* logFileName = void;

        logFileName = LogFilePrep(saved_log_fname, saved_log_backup, display);

        if (rename(saved_log_tempname, logFileName) == 0) {
            LogMessageVerb(X_PROBED, 0,
                           "Log file renamed from \"%s\" to \"%s\"\n",
                           saved_log_tempname, logFileName);

            if (strlen(saved_log_tempname) >= strlen(logFileName))
                strncpy(saved_log_tempname, logFileName,
                        strlen(saved_log_tempname));
        }
        else {
            ErrorF("Failed to rename log file \"%s\" to \"%s\": %s\n",
                   saved_log_tempname, logFileName, strerror(errno));
        }

        /* free newly allocated string - can't free old one since existing
           pointers to it may exist in DDX callers. */
        free(logFileName);
        free(saved_log_fname);
        free(saved_log_backup);
    }
    initSyslog();
}

void LogClose(ExitCode error)
{
    //Хочу кушать
    if (logFileFd != -1) {
        int msgtype = (error == EXIT_NO_ERROR) ? X_INFO : X_ERROR;
        // LogMessageVerb(msgtype, -1,
        //         "Server terminated %s (%d). Closing log file.\n",
        //         (error == EXIT_NO_ERROR) ? "successfully" : "with error",
        //         error);
        close(logFileFd);
        logFileFd = -1;
    }
}

enum {
    LMOD_LONG     = 0x1,
    LMOD_LONGLONG = 0x2,
    LMOD_SHORT    = 0x4,
    LMOD_SIZET    = 0x8,
}

/**
 * Parse non-digit length modifiers and set the corresponding flag in
 * flags_return.
 *
 * @return the number of bytes parsed
 */
private int parse_length_modifier(const(char)* format, size_t len, int* flags_return)
{
    int idx = 0;
    int length_modifier = 0;

    while (idx < len) {
        switch (format[idx]) {
            case 'l':
                mixin(BUG_RETURN_VAL!("length_modifier & LMOD_SHORT", "0"));

                if (length_modifier & LMOD_LONG)
                    length_modifier |= LMOD_LONGLONG;
                else
                    length_modifier |= LMOD_LONG;
                break;
            case 'h':
                mixin(BUG_RETURN_VAL!("length_modifier & (LMOD_LONG|LMOD_LONGLONG)", "0"));
                length_modifier |= LMOD_SHORT;
                /* gcc says 'short int' is promoted to 'int' when
                 * passed through '...', so ignored during
                 * processing */
                break;
            case 'z':
                length_modifier |= LMOD_SIZET;
                break;
            default:
                goto out_;
        }
        idx++;
    }

out_:
    *flags_return = length_modifier;
    return idx;
}

/**
 * Signal-safe snprintf, with some limitations over snprintf. Be careful
 * which directives you use.
 */
private int vpnprintf(char* string, int size_in, const(char)* f, va_list args)
{
    int f_idx = 0;
    int s_idx = 0;
    int f_len = cast(int)strlen_sigsafe(f);
    char* string_arg = void;
    char[21] number = void;
    int p_len = void;
    int i = void;
    ulong ui = void;
    long si = void;
    size_t size = size_in;
    int precision = void;

    for (; f_idx < f_len && s_idx < size - 1; f_idx++) {
        int length_modifier = 0;
        if (f[f_idx] != '%') {
            string[s_idx++] = f[f_idx];
            continue;
        }

        f_idx++;

        if (f[f_idx] == '#')
        /* silently ignore alternate form */
            f_idx++;

        /* silently ignore reverse justification */
        if (f[f_idx] == '-')
            f_idx++;

        /* silently swallow minimum field width */
        if (f[f_idx] == '*') {
            f_idx++;
            va_arg!int(args);
        } else {
            while (f_idx < f_len && ((f[f_idx] >= '0' && f[f_idx] <= '9')))
                f_idx++;
        }

        /* is there a precision? */
        precision = cast(int)size;
        if (f[f_idx] == '.') {
            f_idx++;
            if (f[f_idx] == '*') {
                f_idx++;
                /* precision is supplied in an int argument */
                precision = va_arg!int(args);
            } else {
                /* silently swallow precision digits */
                while (f_idx < f_len && ((f[f_idx] >= '0' && f[f_idx] <= '9')))
                    f_idx++;
            }
        }

        /* non-digit length modifiers */
        if (f_idx < f_len) {
            int parsed_bytes = parse_length_modifier(&f[f_idx], f_len - f_idx, &length_modifier);
            if (parsed_bytes < 0)
                return 0;
            f_idx += parsed_bytes;
        }

        if (f_idx >= f_len)
            break;

        switch (f[f_idx]) {
        case 's':
            string_arg = va_arg!(char*)(args);

            if (string_arg) {
                for (i = 0; string_arg[i] != 0 && s_idx < size - 1 && s_idx < precision; i++)
                    string[s_idx++] = string_arg[i];
            }
            break;

        case 'u':
            if (length_modifier & LMOD_LONGLONG)
                ui = va_arg!(ulong)(args);
            else if (length_modifier & LMOD_LONG)
                ui = va_arg!(ulong)(args);
            else if (length_modifier & LMOD_SIZET)
                ui = va_arg!size_t(args);
            else
                ui = va_arg!uint(args);

            FormatUInt64(ui, number.ptr);
            p_len = cast(int)strlen_sigsafe(number.ptr);

            for (i = 0; i < p_len && s_idx < size - 1; i++)
                string[s_idx++] = number[i];
            break;
        case 'i':
        case 'd':
            if (length_modifier & LMOD_LONGLONG)
                si = va_arg!long(args);
            else if (length_modifier & LMOD_LONG)
                si = va_arg!long(args);
            else if (length_modifier & LMOD_SIZET)
                si = va_arg!ssize_t(args);
            else
                si = va_arg!int(args);

            FormatInt64(si, number.ptr);
            p_len = cast(int)strlen_sigsafe(number.ptr);

            for (i = 0; i < p_len && s_idx < size - 1; i++)
                string[s_idx++] = number[i];
            break;

        case 'p':
            string[s_idx++] = '0';
            if (s_idx < size - 1)
                string[s_idx++] = 'x';
            ui = cast(uintptr_t)va_arg!(void*)(args);
            FormatUInt64Hex(ui, number.ptr);
            p_len = cast(int)strlen_sigsafe(number.ptr);

            for (i = 0; i < p_len && s_idx < size - 1; i++)
                string[s_idx++] = number[i];
            break;

        case 'x':
        case 'X': // not actually upper case, but at least accepting '%X'
            if (length_modifier & LMOD_LONGLONG)
                ui = va_arg!long(args);
            else if (length_modifier & LMOD_LONG)
                ui = va_arg!long(args);
            else if (length_modifier & LMOD_SIZET)
                ui = va_arg!size_t(args);
            else
                ui = va_arg!uint(args);

            FormatUInt64Hex(ui, number.ptr);
            p_len = cast(int)strlen_sigsafe(number.ptr);

            for (i = 0; i < p_len && s_idx < size - 1; i++)
                string[s_idx++] = number[i];
            break;
        case 'f':
            {
                double d = va_arg!double(args);
                FormatDouble(d, number.ptr);
                p_len = cast(int)strlen_sigsafe(number.ptr);

                for (i = 0; i < p_len && s_idx < size - 1; i++)
                    string[s_idx++] = number[i];
            }
            break;
        case 'c':
            {
                char c = va_arg!char(args);
                if (s_idx < size - 1)
                    string[s_idx++] = c;
            }
            break;
        case '%':
            string[s_idx++] = '%';
            break;
        default:
            // BUG_WARN_MSG(f[f_idx], "Unsupported printf directive '%c'\n", f[f_idx]);
            va_arg!(char*)(args);
            string[s_idx++] = '%';
            if (s_idx < size - 1)
                string[s_idx++] = f[f_idx];
            break;
        }
    }

    string[s_idx] = '\0';

    return s_idx;
}

private void LogSyslogWrite(int verb, const(char)* buf, size_t len, Bool end_line) {
version (CONFIG_SYSLOG) {
    if (inSignalContext) // syslog() ins't signal-safe yet :(
        return;          // shall we try syslog(2) syscall instead ?

    if (verb >= 0 && xorgSyslogVerbosity < verb)
        return;

    syslog(LOG_PID, "%.*s", cast(int)len, buf);
}
}

/* This function does the actual log message writes. It must be signal safe.
 * When attempting to call non-signal-safe functions, guard them with a check
 * of the inSignalContext global variable. */
private void LogSWrite(int verb, const(char)* buf, size_t len, Bool end_line)
{
    static Bool newline = True;

    LogSyslogWrite(verb, buf, len, end_line);

    if (verb < 0 || xorgLogVerbosity >= verb) {
        LogWrite(2, buf, len);
    }

    if (verb < 0 || xorgLogFileVerbosity >= verb) {
        if (inSignalContext && logFileFd >= 0) {
            LogWrite(logFileFd, buf, len);
            if (xorgLogSync){
                doLogSync();
            }
        }
        else if (!inSignalContext && logFileFd != -1) {
            if (newline) {
                time_t t = time(null);
                tm tm = void;
                char[32] fmt_tm = void;
                size_t fmt_len = void;

                localtime_r(&t, &tm);
                fmt_len = strftime(
                                fmt_tm.ptr,
                                fmt_tm.length,
                                "[%Y-%m-%d %H:%M:%S] ",
                                &tm);
                LogWrite(logFileFd, fmt_tm.ptr, fmt_len);
            }
            newline = end_line;
            LogWrite(logFileFd, buf, len);
            if (xorgLogSync) {
                doLogSync();
            }
        }
        else if (!inSignalContext && needBuffer) {
            if (len > bufferUnused) {
                bufferSize += 1024;
                bufferUnused += 1024;
                saveBuffer = cast(char*) realloc(saveBuffer, bufferSize);
                if (!saveBuffer) {
                    FatalError("realloc() failed while saving log messages\n");
                }
            }
            bufferUnused -= len;
            memcpy(saveBuffer + bufferPos, buf, len);
            bufferPos += len;
        }
    }
}

/* Returns the Message Type string to prepend to a logging message, or NULL
 * if the message will be dropped due to insufficient verbosity. */
private const(char)* LogMessageTypeVerbString(MessageType type, int verb)
{
    if (type == X_ERROR)
        verb = 0;

    if (xorgLogVerbosity < verb && xorgLogFileVerbosity < verb)
        return null;

    switch (type) {
    case X_PROBED:
        return X_PROBE_STRING;
    case X_CONFIG:
        return X_CONFIG_STRING;
    case X_DEFAULT:
        return X_DEFAULT_STRING;
    case X_CMDLINE:
        return X_CMDLINE_STRING;
    case X_NOTICE:
        return X_NOTICE_STRING;
    case X_ERROR:
        return X_ERROR_STRING;
    case X_WARNING:
        return X_WARNING_STRING;
    case X_INFO:
        return X_INFO_STRING;
    case X_NOT_IMPLEMENTED:
        return X_NOT_IMPLEMENTED_STRING;
    case X_UNKNOWN:
        return X_UNKNOWN_STRING;
    case X_NONE:
        return X_NONE_STRING;
    case X_DEBUG:
        return X_DEBUG_STRING;
    default:
        return X_UNKNOWN_STRING;
    }
}

enum LOG_MSG_BUF_SIZE = 1024;

private ssize_t prepMsgHdr(MessageType type, int verb, char* buf)
{
    const(char)* type_str = LogMessageTypeVerbString(type, verb);
    if (!type_str)
        return -1;

    size_t prefixLen = strlen_sigsafe(type_str);
    if (prefixLen) {
        memcpy(buf, type_str, prefixLen + 1); // rely on buffer being big enough
        buf[prefixLen] = ' ';
        prefixLen++;
    }
    buf[prefixLen] = 0;
    return prefixLen;
}

pragma(inline, true) private void writeLog(int verb, char* buf, int len)
{
    /* Force '\n' at end of truncated line */
    if (LOG_MSG_BUF_SIZE  - len == 1)
        buf[len - 1] = '\n';

    LogSWrite(verb, buf, len, (buf[len - 1] == '\n'));
}

/* signal safe */
void LogVMessageVerb(MessageType type, int verb, const(char)* format, va_list args)
{
    char[LOG_MSG_BUF_SIZE] buf = void;

    size_t len = prepMsgHdr(type, verb, buf.ptr);
    if (len == -1)
        return;

    len += vpnprintf(&buf[len], cast(int)((buf).length - len), format, args);

    writeLog(verb, buf.ptr, cast(int)len);
}

/* Log message with verbosity level specified. -- signal safe */
void LogMessageVerb(MessageType type, int verb, const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    LogVMessageVerb(type, verb, format, ap);
    core.stdc.stdarg.va_end(ap);
}

/* Log a message with the standard verbosity level of 1. */
void LogMessage(MessageType type, const(char)* format, ...)
{
    va_list ap = void;

    core.stdc.stdarg.va_start(ap, format);
    LogVMessageVerb(type, 1, format, ap);
    core.stdc.stdarg.va_end(ap);
}


private void LogVHdrMessageVerb(MessageType type, int verb, const(char)* msg_format, va_list msg_args, const(char)* hdr_format, va_list hdr_args)
{
    char[LOG_MSG_BUF_SIZE] buf = void;

    size_t len = prepMsgHdr(type, verb, buf.ptr);
    if (len == -1)
        return;

    if (hdr_format && ((buf).ptr - len).sizeof > 1)
        len += vpnprintf(&buf[len], cast(int)((buf).length - len), hdr_format, hdr_args);

    if (msg_format && ((buf).length - len) > 1)
        len += vpnprintf(&buf[len], cast(int)((buf).length - len), msg_format, msg_args);

    writeLog(verb, buf.ptr, cast(int)len);
}

void LogHdrMessageVerb(MessageType type, int verb, const(char)* msg_format, va_list msg_args, const(char)* hdr_format, ...)
{
    va_list hdr_args = void;

    core.stdc.stdarg.va_start(hdr_args, hdr_format);
    LogVHdrMessageVerb(type, verb, msg_format, msg_args, hdr_format, hdr_args);
    core.stdc.stdarg.va_end(hdr_args);
}

enum AUDIT_PREFIX = "AUDIT: %s: %ld: ";
enum AUDIT_TIMEOUT = ((CARD32)(120 * 1000))    /* 2 mn */;


private int nrepeat = 0;
private int oldlen = -1;
private OsTimerPtr auditTimer = null;

int auditTrailLevel = 1;

void FreeAuditTimer()
{
    if (auditTimer !is null) {
        /* Force output of pending messages */
        TimerForce(auditTimer);
        TimerFree(auditTimer);
        auditTimer = null;
    }
}

private char* AuditPrefix()
{
    time_t tm = void;
    char* autime = void, s = void;
    int len = void;

    time(&tm);
    autime = ctime(&tm);
    if ((s = strchr(autime, '\n')) !is null)
        *s = '\0';
    len = cast(int)(strlen(AUDIT_PREFIX) + strlen(autime) + 10 + 1);
    char* tmpBuf = cast(char*) calloc(1, len);
    if (!tmpBuf)
        return null;
    snprintf(tmpBuf, len, AUDIT_PREFIX, autime, cast(c_ulong) getpid());
    return tmpBuf;
}

void AuditF(const(char)* f, ...)
{
    va_list args = void;

    core.stdc.stdarg.va_start(args, f);

    VAuditF(f, args);
    core.stdc.stdarg.va_end(args);
}

private CARD32 AuditFlush(OsTimerPtr timer, CARD32 now, void* arg)
{
    char* prefix = void;

    if (nrepeat > 0) {
        prefix = AuditPrefix();
        ErrorF("%slast message repeated %d times\n",
               prefix !is null ? prefix : "", nrepeat);
        nrepeat = 0;
        free(prefix);
        return AUDIT_TIMEOUT;
    }
    else {
        /* if the timer expires without anything to print, flush the message */
        oldlen = -1;
        return 0;
    }
}

void VAuditF(const(char)* f, va_list args)
{
    char* prefix = void;
    char[1024] buf = void;
    int len = void;
    static char[1024] oldbuf = 0;

    prefix = AuditPrefix();
    len = vsnprintf(buf.ptr, buf.sizeof, f, args);

    if (len == oldlen && strcmp(buf.ptr, oldbuf.ptr) == 0) {
        /* Message already seen */
        nrepeat++;
    }
    else {
        /* new message */
        if (auditTimer !is null)
            TimerForce(auditTimer);
        ErrorF("%s%s", prefix !is null ? prefix : "", buf.ptr);
        strlcpy(oldbuf.ptr, buf.ptr, oldbuf.sizeof);
        oldlen = len;
        nrepeat = 0;
        auditTimer = TimerSet(auditTimer, 0, AUDIT_TIMEOUT, &AuditFlush, null);
    }
    free(prefix);
}

void FatalError(const(char)* f, ...)
{
    va_list args = void;
    va_list args2 = void;
    static Bool beenhere = False;

    if (beenhere)
        ErrorF("\nFatalError re-entered, aborting\n");
    else
        ErrorF("\nFatal server error:\n");

    core.stdc.stdarg.va_start(args, f);

    /* Make a copy for OsVendorFatalError */
    core.stdc.stdarg.va_copy(args2, args);

version (OSX) {
    {
        va_list apple_args = void;

        core.stdc.stdarg.va_copy(apple_args, args);
        cast(void)vsnprintf(__crashreporter_info_buff__.ptr,
                        __crashreporter_info_buff__.sizeof, f, apple_args);
        core.stdc.stdarg.va_end(apple_args);
    }
}
    LogVMessageVerb(X_NONE, -1, f, args);
    core.stdc.stdarg.va_end(args);
    ErrorF("\n");
    if (!beenhere)
        OsVendorFatalError(f, args2);
    core.stdc.stdarg.va_end(args2);
    if (!beenhere) {
        beenhere = True;
        AbortServer();
    }
    else
        OsAbort();
 /*NOTREACHED*/}

void ErrorF(const(char)* f, ...)
{
    va_list args = void;

    core.stdc.stdarg.va_start(args, f);
    LogVMessageVerb(X_NONE, -1, f, args);
    core.stdc.stdarg.va_end(args);
}

void LogPrintMarkers()
{
    /* Show what the message marker symbols mean. */
    LogMessageVerb(X_NONE, 0, "Markers: ");
    LogMessageVerb(X_PROBED, 0, "probed, ");
    LogMessageVerb(X_CONFIG, 0, "from config file, ");
    LogMessageVerb(X_DEFAULT, 0, "default setting,\n\t");
    LogMessageVerb(X_CMDLINE, 0, "from command line, ");
    LogMessageVerb(X_NOTICE, 0, "notice, ");
    LogMessageVerb(X_INFO, 0, "informational,\n\t");
    LogMessageVerb(X_WARNING, 0, "warning, ");
    LogMessageVerb(X_ERROR, 0, "error, ");
    LogMessageVerb(X_NOT_IMPLEMENTED, 0, "not implemented, ");
    LogMessageVerb(X_UNKNOWN, 0, "unknown.\n");
}
