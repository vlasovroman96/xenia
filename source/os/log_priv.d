module os.log_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import os.osdep;

/**
 * @brief initialize logging and open log files
 *
 * Make backup of existing log file, create a new one and open it for logging.
 *
 * - May be called with NULL or "", if no logging is desired.
 *
 * - Must always be called, otherwise log messages will fill up the buffer and
 *   let it grow infinitely.
 *
 * - if "%s" is present in fname, it will be replaced with the display string or pid
 *
 * @param fname log file name template. if NULL, dont write any log.
 * @param backup name for the old logfile.
 * @return new log file name
 */
// const(char)* LogInit(const(char)* fname, const(char)* backup);

/**
 * @brief rename the current log file according display name
 *
 * Renames the current log file with per display prefix (e.g. "Xorg.log.0")
 *
 */
// void LogSetDisplay();

/**
 * @brief log exit code, then flush and close log file and write
 *
 * Logs the exit code (and success/error state), then flush and close log file.
 */
// void LogClose(ExitCode error);

version (DEBUG)
{
    alias DebugF = ErrorF;
}
else
{
    extern(C) @nogc nothrow
    void DebugF(const(char)* fmt, ...) {}
}

/**
 * @brief console log verbosity (stderr)
 *
 * The verbosity level of logging to console. All messages with verbosity
 * level below this one will be written to stderr
 */
// int xorgLogVerbosity;

/**
 * @brief log file verbosity
 *
 * The verbosity level of logging to per-display file. All messages with
 * verbosity level below this one will be written to the log file.
 */
// int xorgLogFileVerbosity;

/**
 * @brief force fsync() on each log write
 *
 * If set to True, force fsync() on each log write.
 */
// Bool xorgLogSync;

/**
 * @brief syslog verbosity
 *
 * The verbosity level of logging to syslog. All messages with
 * verbosity level below this one will be sent to local syslog daemon.
 */
int xorgSyslogVerbosity;

/**
 * @brief syslog identifier
 *
 * The identifier prefix used for syslog logging.
 * Per default will be filled with basename(argv[0]). DDX'es can override
 * this before calling LogInit()
 */
const(char)* xorgSyslogIdent;

/*
 * print log markers into the log file
 */
// void LogPrintMarkers();

 /* __XORG_OS_LOGGING_H */
