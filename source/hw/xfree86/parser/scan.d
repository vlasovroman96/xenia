module scan;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 1997  Metro Link Incorporated
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
 * THE X CONSORTIUM BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of the Metro Link shall not be
 * used in advertising or otherwise to promote the sale, use or other dealings
 * in this Software without prior written authorization from Metro Link.
 *
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
import build.xorg_config;

import core.stdc.ctype;
import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.string;
import core.sys.posix.sys.types;
import core.sys.posix.dirent;
import core.sys.posix.unistd;
import core.stdc.stdarg;
import core.sys.posix.dirent;
//import x11.Xdefs;
////import x11.Xfuncproto;
import core.stdc.limits;
import xf86AutoConfig_;

import os.xhostname;

import xf86Parser_priv;

import Configint;
import xf86tokens;
import os.log;
import externs.gnu;
import os.os;
// #define PATHS_H
enum string DATADIR =          "/usr/share";
enum string SYSCONFDIR =       "/etc";
enum string VARRUNDIR =        "/var/run";
enum string LOCALSTATEDIR =    "/var";
enum string LIBDIR =           "/usr/lib";

enum CONFIG_BUF_LEN =     1024;
enum CONFIG_MAX_FILES =   64;

struct _ConfigFiles {
    FILE* file;
    char* path;
}private _ConfigFiles[CONFIG_MAX_FILES] configFilesList;
// private const(char)** builtinConfig = null;
private int builtinIndex = 0;
private int configPos = 0;       /* current readers position */
private int configLineNo = 0;    /* linenumber */
private char* configBuf, configRBuf;    /* buffer for lines */
private char* configSection = null;      /* name of current section being parsed */
private int numFiles = 0;        /* number of config files */
private int curFileIndex = 0;    /* index of current config file */
private int pushToken = LOCK_TOKEN;
private int eol_seen = 0;        /* private state to handle comments */
LexRec xf86_lex_val;

/*
 * xf86getNextLine --
 *
 *  read from the configFilesList FILE stream until we encounter a new
 *  line; this is effectively just a big wrapper for fgets(3).
 *
 *  xf86getToken() assumes that we will read up to the next
 *  newline; we need to grow configBuf and configRBuf as needed to
 *  support that.
 */

private char* xf86getNextLine()
{
    static int configBufLen = CONFIG_BUF_LEN;
    char* tmpConfigBuf = void, tmpConfigRBuf = void;
    int c = void, i = void, pos = 0, eolFound = 0;
    char* ret = null;

    /*
     * reallocate the string if it was grown last time (i.e., is no
     * longer CONFIG_BUF_LEN); we calloc the new strings first, so
     * that if either of the callocs fail, we can fall back on the
     * existing buffer allocations
     */

    if (configBufLen != CONFIG_BUF_LEN) {

        tmpConfigBuf = cast(char*) calloc(1, CONFIG_BUF_LEN);
        tmpConfigRBuf = cast(char*) calloc(1, CONFIG_BUF_LEN);

        if (!tmpConfigBuf || !tmpConfigRBuf) {

            /*
             * at least one of the callocs failed; keep the old buffers
             * and free any partial allocations
             */

            free(tmpConfigBuf);
            free(tmpConfigRBuf);

        }
        else {

            /*
             * calloc succeeded; free the old buffers and use the new
             * buffers
             */

            configBufLen = CONFIG_BUF_LEN;

            free(configBuf);
            free(configRBuf);

            configBuf = tmpConfigBuf;
            configRBuf = tmpConfigRBuf;
        }
    }

    /* read in another block of chars */

    do {
        ret = fgets(configBuf + pos, configBufLen - pos - 1,
                    configFilesList[curFileIndex].file);

        if (!ret) {
            /*
             * if the file doesn't end in a newline, add one
             * and trigger another read
             */
            if (pos != 0) {
                strcpy(&configBuf[pos], "\n");
                ret = configBuf;
            }
            else
                break;
        }

        /* search for EOL in the new block of chars */

        for (i = pos; i < (configBufLen - 1); i++) {
            c = configBuf[i];

            if (c == '\0')
                break;

            if ((c == '\n') || (c == '\r')) {
                eolFound = 1;
                break;
            }
        }

        /*
         * if we didn't find EOL, then grow the string and
         * read in more
         */

        if (!eolFound) {

            tmpConfigBuf = cast(char*) realloc(configBuf, configBufLen + CONFIG_BUF_LEN);
            tmpConfigRBuf = cast(char*) realloc(configRBuf, configBufLen + CONFIG_BUF_LEN);

            if (!tmpConfigBuf || !tmpConfigRBuf) {

                /*
                 * at least one of the reallocations failed; use the
                 * new allocation that succeeded, but we have to
                 * fallback to the previous configBufLen size and use
                 * the string we have, even though we don't have an
                 * EOL
                 */

                if (tmpConfigBuf)
                    configBuf = tmpConfigBuf;
                if (tmpConfigRBuf)
                    configRBuf = tmpConfigRBuf;

                break;

            }
            else {

                /* reallocation succeeded */

                configBuf = tmpConfigBuf;
                configRBuf = tmpConfigRBuf;
                pos = i;
                configBufLen += CONFIG_BUF_LEN;
            }
        }

    } while (!eolFound);

    return ret;
}

private int StringToToken(const(char)* str, const(xf86ConfigSymTabRec)* tab)
{
    int i = void;

    for (i = 0; tab[i].token != -1; i++) {
        if (!xf86nameCompare(tab[i].name, str))
            return tab[i].token;
    }
    return ERROR_TOKEN;
}

/*
 * xf86getToken --
 *      Read next Token from the config file. Handle the global variable
 *      pushToken.
 */
int xf86getToken(const(xf86ConfigSymTabRec)* tab)
{
    int c = void, i = void;

    /*
     * First check whether pushToken has a different value than LOCK_TOKEN.
     * In this case rBuf[] contains a valid STRING/TOKEN/NUMBER. But in the
     * oth * case the next token must be read from the input.
     */
    if (pushToken == EOF_TOKEN)
        return EOF_TOKEN;
    else if (pushToken == LOCK_TOKEN) {
        /*
         * eol_seen is only set for the first token after a newline.
         */
        eol_seen = 0;

        c = configBuf[configPos];

        /*
         * Get start of next Token. EOF is handled,
         * whitespaces are skipped.
         */

 again:
        if (!c) {
            char* ret = void;

            if (numFiles > 0)
                ret = xf86getNextLine();
            else {
                if (builtinConfig[builtinIndex] is null)
                    ret = null;
                else {
                    strlcpy(configBuf,
                            builtinConfig[builtinIndex], CONFIG_BUF_LEN);
                    ret = configBuf;
                    builtinIndex++;
                }
            }
            if (ret is null) {
                /*
                 * if necessary, move to the next file and
                 * read the first line
                 */
                if (curFileIndex + 1 < numFiles) {
                    curFileIndex++;
                    configLineNo = 0;
                    goto again;
                }
                else
                    return pushToken = EOF_TOKEN;
            }
            configLineNo++;
            configPos = 0;
            eol_seen = 1;
        }

        i = 0;
        for (;;) {
            c = configBuf[configPos++];
            configRBuf[i++] = cast(char)c;
            switch (c) {
            case ' ':
            case '\t':
            case '\r':
                continue;
            case '\n':
                i = 0;
                continue;
            default: break;}
            break;
        }
        if (c == '\0')
            goto again;

        if (c == '#') {
            do {
                configRBuf[i++] = (c = configBuf[configPos++]);
            }
            while ((c != '\n') && (c != '\r') && (c != '\0'));
            configRBuf[i] = '\0';
            /* XXX private copy.
             * Use xf86addComment when setting a comment.
             */
            xf86_lex_val.str = strdup(configRBuf);
            return COMMENT;
        }

        /* GJA -- handle '-' and ','  * Be careful: "-hsync" is a keyword. */
        else if ((c == ',') && !isalpha(cast(ubyte)configBuf[configPos])) {
            return COMMA;
        }
        else if ((c == '-') && !isalpha(cast(ubyte)configBuf[configPos])) {
            return DASH;
        }

        /*
         * Numbers are returned immediately ...
         */
        if (isdigit(c)) {
            int base = void;

            if (c == '0')
                if ((configBuf[configPos] == 'x') ||
                    (configBuf[configPos] == 'X')) {
                    base = 16;
                    xf86_lex_val.numType = PARSE_HEX;
                }
                else {
                    base = 8;
                    xf86_lex_val.numType = PARSE_OCTAL;
                }
            else {
                base = 10;
                xf86_lex_val.numType = PARSE_DECIMAL;
            }

            configRBuf[0] = cast(char)c;
            i = 1;
            while (isdigit(c = configBuf[configPos++]) ||
                   (c == '.') || (c == 'x') || (c == 'X') ||
                   ((base == 16) && (((c >= 'a') && (c <= 'f')) ||
                                     ((c >= 'A') && (c <= 'F')))))
                configRBuf[i++] = cast(char)c;
            configPos--;        /* GJA -- one too far */
            configRBuf[i] = '\0';
            xf86_lex_val.num = cast(int)strtoul(configRBuf, null, 0);
            xf86_lex_val.realnum = atof(configRBuf);
            return NUMBER;
        }

        /*
         * All Strings START with a \" ...
         */
        else if (c == '\"') {
            i = -1;
            do {
                configRBuf[++i] = (c = configBuf[configPos++]);
            }
            while ((c != '\"') && (c != '\n') && (c != '\r') && (c != '\0'));
            configRBuf[i] = '\0';
            xf86_lex_val.str = cast(char*)calloc(1, strlen(configRBuf) + 1);
            strcpy(xf86_lex_val.str, configRBuf);        /* private copy ! */
            return XF86_TOKEN_STRING;
        }

        /*
         * ... and now we MUST have a valid token.  The search is
         * handled later along with the pushed tokens.
         */
        else {
            configRBuf[0] = cast(char)c;
            i = 0;
            do {
                configRBuf[++i] = (c = configBuf[configPos++]);
            }
            while ((c != ' ') && (c != '\t') && (c != '\n') && (c != '\r') &&
                   (c != '\0') && (c != '#'));
            --configPos;
            configRBuf[i] = '\0';
            i = 0;
        }

    }
    else {

        /*
         * Here we deal with pushed tokens. Reinitialize pushToken again. If
         * the pushed token was NUMBER || STRING return them again ...
         */
        int temp = pushToken;

        pushToken = LOCK_TOKEN;

        if (temp == COMMA || temp == DASH)
            return temp;
        if (temp == NUMBER || temp == XF86_TOKEN_STRING)
            return temp;
    }

    /*
     * Joop, at last we have to lookup the token ...
     */
    if (tab)
        return StringToToken(configRBuf, tab);

    return ERROR_TOKEN;         /* Error catcher */
}

int xf86getSubToken(char** comment)
{
    int token = void;

    for (;;) {
        token = xf86getToken(null);
        if (token == COMMENT) {
            if (comment) {
                *comment = xf86addComment(*comment, xf86_lex_val.str);
                free(xf86_lex_val.str);
                xf86_lex_val.str = null;
            }
        }
        else
            return token;
    }
 /*NOTREACHED*/}

int xf86getSubTokenWithTab(char** comment, const(xf86ConfigSymTabRec)* tab)
{
    int token = void;

    for (;;) {
        token = xf86getToken(tab);
        if (token == COMMENT) {
            if (comment) {
                *comment = xf86addComment(*comment, xf86_lex_val.str);
                free(xf86_lex_val.str);
                xf86_lex_val.str = null;
            }
        }
        else
            return token;
    }
 /*NOTREACHED*/}

void xf86unGetToken(int token)
{
    pushToken = token;
}

char* xf86tokenString()
{
    return configRBuf;
}

int xf86pathIsAbsolute(const(char)* path)
{
    if (path && path[0] == '/')
        return 1;
    return 0;
}

/* A path is "safe" if it is relative and if it contains no ".." elements. */
int xf86pathIsSafe(const(char)* path)
{
    if (xf86pathIsAbsolute(path))
        return 0;

    /* Compare with ".." */
    if (!strcmp(path, ".."))
        return 0;

    /* Look for leading "../" */
    if (!strncmp(path, "../", 3))
        return 0;

    /* Look for trailing "/.." */
    if ((strlen(path) > 3) && !strcmp(path + strlen(path) - 3, "/.."))
        return 0;

    /* Look for "/../" */
    if (strstr(path, "/../"))
        return 0;

    return 1;
}

/*
 * This function substitutes the following escape sequences:
 *
 *    %A    cmdline argument as an absolute path (must be absolute to match)
 *    %R    cmdline argument as a relative path
 *    %S    cmdline argument as a "safe" path (relative, and no ".." elements)
 *    %X    default config file name ("xorg.conf")
 *    %H    hostname
 *    %E    config file environment ($XORGCONFIG) as an absolute path
 *    %F    config file environment ($XORGCONFIG) as a relative path
 *    %G    config file environment ($XORGCONFIG) as a safe path
 *    %P    projroot
 *    %C    sysconfdir
 *    %D    datadir
 *    %%    %
 */

enum XCONFIGSUFFIX =	".conf";
enum XCONFENV =	"XORGCONFIG";

enum BAIL_OUT =		`{									
							free(result);				
							return null;						
						} `;

enum CHECK_LENGTH =	`{									
							if (l > PATH_MAX) {					
								mixin(BAIL_OUT);						
							}									
						} `;

enum string APPEND_STR(string s) = `{									
							if (strlen(` ~ s ~ `) + l > PATH_MAX) {		
								mixin(BAIL_OUT);						
							} else {							
								strcpy(result + l, ` ~ s ~ `);			
								l += strlen(` ~ s ~ `);					
							}									
						} `;

private char* DoSubstitution(const(char)* template_, const(char)* cmdline, const(char)* projroot, int* cmdlineUsed, int* envUsed, const(char)* XConfigFile)
{
    int i = void, l = void;
    static const(char)* env = null;
    static char* hostname = null;

    if (!template_)
        return null;

    if (cmdlineUsed)
        *cmdlineUsed = 0;
    if (envUsed)
        *envUsed = 0;

    char* result = cast(char*) calloc(1, PATH_MAX + 1);
    if (!result)
        return null;

    l = 0;
    for (i = 0; template_[i]; i++) {
        if (template_[i] != '%') {
            result[l++] = template_[i];
            mixin(CHECK_LENGTH);
        }
        else {
            switch (template_[++i]) {
            case 'A':
                if (cmdline && xf86pathIsAbsolute(cmdline)) {
                    mixin(APPEND_STR!(`cmdline`));
                    if (cmdlineUsed)
                        *cmdlineUsed = 1;
                }
                else
                    mixin(BAIL_OUT);
                break;
            case 'R':
                if (cmdline && !xf86pathIsAbsolute(cmdline)) {
                    mixin(APPEND_STR!(`cmdline`));
                    if (cmdlineUsed)
                        *cmdlineUsed = 1;
                }
                else
                    mixin(BAIL_OUT);
                break;
            case 'S':
                if (cmdline && xf86pathIsSafe(cmdline)) {
                    mixin(APPEND_STR!(`cmdline`));
                    if (cmdlineUsed)
                        *cmdlineUsed = 1;
                }
                else
                    mixin(BAIL_OUT);
                break;
            case 'X':
                mixin(APPEND_STR!(`XConfigFile`));
                break;
            case 'H':
                if (!hostname) {
                    xhostname hn = void;
                    if (f_xhostname(&hn))
                        hostname = strdup(hn.name.ptr);
                }
                if (hostname)
                    mixin(APPEND_STR!(`hostname`));
                break;
            case 'E':
                if (!env)
                    env = getenv(XCONFENV);
                if (env && xf86pathIsAbsolute(env)) {
                    mixin(APPEND_STR!(`env`));
                    if (envUsed)
                        *envUsed = 1;
                }
                else
                    mixin(BAIL_OUT);
                break;
            case 'F':
                if (!env)
                    env = getenv(XCONFENV);
                if (env && !xf86pathIsAbsolute(env)) {
                    mixin(APPEND_STR!(`env`));
                    if (envUsed)
                        *envUsed = 1;
                }
                else
                    mixin(BAIL_OUT);
                break;
            case 'G':
                if (!env)
                    env = getenv(XCONFENV);
                if (env && xf86pathIsSafe(env)) {
                    mixin(APPEND_STR!(`env`));
                    if (envUsed)
                        *envUsed = 1;
                }
                else
                    mixin(BAIL_OUT);
                break;
            case 'P':
                if (projroot && xf86pathIsAbsolute(projroot))
                    mixin(APPEND_STR!(`projroot`));
                else
                    mixin(BAIL_OUT);
                break;
            case 'C':
                mixin(APPEND_STR!(`SYSCONFDIR`));
                break;
            case 'D':
                mixin(APPEND_STR!(`DATADIR`));
                break;
            case '%':
                result[l++] = '%';
                mixin(CHECK_LENGTH);
                break;
            default:
                fprintf(stderr, "invalid escape %%%c found in path template\n",
                        template_[i]);
                mixin(BAIL_OUT);
                break;
            }
        }
    }
version (DEBUG) {
    fprintf(stderr, "Converted `%s' to `%s'\n", template_, result);
}
    return result;
}

/*
 * Given some searching parameters, locate and open the xorg config file.
 */
private char* OpenConfigFile(const(char)* path, const(char)* cmdline, const(char)* projroot, const(char)* confname)
{
    char* filepath = null;
    char* pathcopy = void;
    const(char)* template_ = void;
    int cmdlineUsed = 0;
    FILE* file = null;

    pathcopy = strdup(path);
    for (template_ = strtok(pathcopy, ","); template_ && !file;
         template_ = strtok(null, ",")) {
        filepath = DoSubstitution(template_, cmdline, projroot,
                                  &cmdlineUsed, null, confname);
        if (!filepath)
            continue;
        if (cmdline && !cmdlineUsed) {
            free(filepath);
            filepath = null;
            continue;
        }
        file = fopen(filepath, "r");
        if (!file) {
            free(filepath);
            filepath = null;
        }
    }

    free(pathcopy);
    if (file) {
        configFilesList[numFiles].file = file;
        configFilesList[numFiles].path = strdup(filepath);
        numFiles++;
    }
    return filepath;
}

/*
 * Match non-hidden files in the xorg config directory with a .conf
 * suffix. This filter is passed to scandir(3).
 */
private int ConfigFilter(const(dirent)* de)
{
    const(char)* name = de.d_name.ptr;
    size_t len = void;
    size_t suflen = strlen(XCONFIGSUFFIX);

    if (!name || name[0] == '.')
        return 0;
    len = strlen(name);
    if (len <= suflen)
        return 0;
    if (strcmp(&name[len - suflen], XCONFIGSUFFIX) != 0)
        return 0;
    return 1;
}

private Bool AddConfigDirFiles(const(char)* dirpath, dirent** list, int num)
{
    int i = void;
    Bool openedFile = False;
    Bool warnOnce = False;

    for (i = 0; i < num; i++) {
        FILE* file = void;

        if (numFiles >= CONFIG_MAX_FILES) {
            if (!warnOnce) {
                ErrorF("Maximum number of configuration " ~ "files opened\n");
                warnOnce = True;
            }
            continue;
        }

        char* path = cast(char*) calloc(1, PATH_MAX + 1);
        snprintf(path, PATH_MAX + 1, "%s/%s", dirpath, list[i].d_name.ptr);
        file = fopen(path, "r");
        if (!file) {
            free(path);
            continue;
        }
        openedFile = True;

        configFilesList[numFiles].file = file;
        configFilesList[numFiles].path = path;
        numFiles++;
    }

    return openedFile;
}

/*
 * Given some searching parameters, locate and open the xorg config
 * directory. The directory does not need to contain config files.
 */
private char* OpenConfigDir(const(char)* path, const(char)* cmdline, const(char)* projroot, const(char)* confname)
{
    char* dirpath = null, pathcopy = void;
    const(char)* template_ = void;
    Bool found = False;
    int cmdlineUsed = 0;

    pathcopy = strdup(path);
    for (template_ = strtok(pathcopy, ","); template_ && !found;
         template_ = strtok(null, ",")) {
        dirent** list = null;
        int num = void;

        dirpath = DoSubstitution(template_, cmdline, projroot,
                                 &cmdlineUsed, null, confname);
        if (!dirpath)
            continue;
        if (cmdline && !cmdlineUsed) {
            free(dirpath);
            dirpath = null;
            continue;
        }

        /* match files named *.conf */
        num = scandir(dirpath, &list, &ConfigFilter, &alphasort);
        if (num < 0) {
            list = null;
            num = 0;
        }
        found = AddConfigDirFiles(dirpath, list, num);
        if (!found) {
            free(dirpath);
            dirpath = null;
        }
        while (num--)
            free(list[num]);
        free(list);
    }

    free(pathcopy);
    return dirpath;
}

/*
 * xf86initConfigFiles -- Setup global variables and buffers.
 */
void xf86initConfigFiles()
{
    curFileIndex = 0;
    configPos = 0;
    configLineNo = 0;
    pushToken = LOCK_TOKEN;

    configBuf = cast(char*) calloc(1, CONFIG_BUF_LEN);
    configRBuf = cast(char*) calloc(1, CONFIG_BUF_LEN);
    configBuf[0] = '\0';        /* sanity ... */
}

/*
 * xf86openConfigFile --
 *
 * This function take a config file search path (optional), a command-line
 * specified file name (optional) and the ProjectRoot path (optional) and
 * locates and opens a config file based on that information.  If a
 * command-line file name is specified, then this function fails if none
 * of the located files.
 *
 * The return value is a pointer to the actual name of the file that was
 * opened.  When no file is found, the return value is NULL. The caller should
 * free() the returned value.
 *
 * The escape sequences allowed in the search path are defined above.
 *
 */

enum DEFAULT_CONF_PATH =	"/etc/X11/%S," ~
							"%P/etc/X11/%S," ~
							"/etc/X11/%G," ~
							"%P/etc/X11/%G," ~
							"/etc/X11/%X-%M," ~
							"/etc/X11/%X," ~
							"/etc/%X," ~
							"%P/etc/X11/%X.%H," ~
							"%P/etc/X11/%X-%M," ~
							"%P/etc/X11/%X," ~
							"%P/lib/X11/%X.%H," ~
							"%P/lib/X11/%X-%M," ~
							"%P/lib/X11/%X";


char* xf86openConfigFile(const(char)* path, const(char)* cmdline, const(char)* projroot)
{
    if (!path || !path[0])
        path = DEFAULT_CONF_PATH;
    if (!projroot || !projroot[0])
        projroot = PROJECTROOT;

    /* Search for a config file */
    return OpenConfigFile(path, cmdline, projroot, XCONFIGFILE);
}

/*
 * xf86openConfigDirFiles --
 *
 * This function take a config directory search path (optional), a
 * command-line specified directory name (optional) and the ProjectRoot path
 * (optional) and locates and opens a config directory based on that
 * information.  If a command-line name is specified, then this function
 * fails if it is not found.
 *
 * The return value is a pointer to the actual name of the directory that was
 * opened.  When no directory is found, the return value is NULL. The caller
 * should free() the returned value.
 *
 * The escape sequences allowed in the search path are defined above.
 *
 */
char* xf86openConfigDirFiles(const(char)* path, const(char)* cmdline, const(char)* projroot)
{
    if (!path || !path[0])
        path = DEFAULT_CONF_PATH;
    if (!projroot || !projroot[0])
        projroot = PROJECTROOT;

    /* Search for the multiconf directory */
    return OpenConfigDir(path, cmdline, projroot, XCONFIGDIR);
}

void xf86closeConfigFile()
{
    int i = void;

    free(configRBuf);
    configRBuf = null;
    free(configBuf);
    configBuf = null;

    if (numFiles == 0) {
        builtinConfig = null;
        builtinIndex = 0;
    }
    for (i = 0; i < numFiles; i++) {
        fclose(configFilesList[i].file);
        configFilesList[i].file = null;
        free(configFilesList[i].path);
        configFilesList[i].path = null;
    }
    numFiles = 0;
}

void xf86setBuiltinConfig(const(char)** config)
{
    builtinConfig = config;
}

void xf86parseError(const(char)* format, ...)
{
    va_list ap = void;
    const(char)* filename = numFiles ? configFilesList[curFileIndex].path
        : "<builtin configuration>";

    ErrorF("Parse error on line %d of section %s in file %s\n\t",
           configLineNo, configSection, filename);
    core.stdc.stdarg.va_start(ap, format);
    LogVMessageVerb(X_NONE, -1, format, ap);
    core.stdc.stdarg.va_end(ap);

    ErrorF("\n");
}

void xf86validationError(const(char)* format, ...)
{
    va_list ap = void;
    const(char)* filename = numFiles ? configFilesList[curFileIndex].path
        : "<builtin configuration>";

    ErrorF("Data incomplete in file %s\n\t", filename);
    core.stdc.stdarg.va_start(ap, format);
    LogVMessageVerb(X_NONE, -1, format, ap);
    core.stdc.stdarg.va_end(ap);

    ErrorF("\n");
}

void xf86setSection(const(char)* section)
{
    free(configSection);
    configSection = strdup(section);
}

/*
 * xf86getToken --
 *  Lookup a string if it is actually a token in disguise.
 */
int xf86getStringToken(const(xf86ConfigSymTabRec)* tab)
{
    return StringToToken(xf86_lex_val.str, tab);
}

/*
 * Compare two names.  The characters '_', ' ', and '\t' are ignored
 * in the comparison.
 */
int xf86nameCompare(const(char)* s1, const(char)* s2)
{
    char c1 = void, c2 = void;

    if (!s1 || *s1 == 0) {
        if (!s2 || *s2 == 0)
            return 0;
        else
            return 1;
    } else if (!s2 || *s2 == 0) {
        return -1;
    }

    while (*s1 == '_' || *s1 == ' ' || *s1 == '\t')
        s1++;
    while (*s2 == '_' || *s2 == ' ' || *s2 == '\t')
        s2++;
    c1 = cast(char)(isupper(cast(ubyte)*s1) ? tolower(cast(ubyte)*s1) : *s1);
    c2 = cast(char)(isupper(cast(ubyte)*s2) ? tolower(cast(ubyte)*s2) : *s2);
    while (c1 == c2) {
        if (c1 == '\0')
            return 0;
        s1++;
        s2++;
        while (*s1 == '_' || *s1 == ' ' || *s1 == '\t')
            s1++;
        while (*s2 == '_' || *s2 == ' ' || *s2 == '\t')
            s2++;
        c1 = cast(char)(isupper(cast(ubyte)*s1) ? tolower(cast(ubyte)*s1) : *s1);
        c2 = cast(char)(isupper(cast(ubyte)*s2) ? tolower(cast(ubyte)*s2) : *s2);
    }
    return c1 - c2;
}

char* xf86addComment(char* cur, const(char)* add)
{
    char* str = void;
    const(char)* cstr = void;
    int len = void, curlen = void, iscomment = void, hasnewline = 0, insnewline = void, endnewline = void;

    if (add is null || add[0] == '\0')
        return cur;

    if (cur) {
        curlen = cast(int)strlen(cur);
        if (curlen)
            hasnewline = cur[curlen - 1] == '\n';
        eol_seen = 0;
    }
    else
        curlen = 0;

    cstr = add;
    iscomment = 0;
    while (*cstr) {
        if (*cstr != ' ' && *cstr != '\t')
            break;
        ++cstr;
    }
    iscomment = (*cstr == '#');

    len = cast(int)strlen(add);
    endnewline = add[len - 1] == '\n';

    insnewline = eol_seen || (curlen && !hasnewline);
    if (insnewline)
        len++;
    if (!iscomment)
        len++;
    if (!endnewline)
        len++;

    /* Allocate + 1 char for '\0' terminator. */
    str = cast(char*) realloc(cur, curlen + len + 1);
    if (!str)
        return cur;

    cur = str;

    if (insnewline)
        cur[curlen++] = '\n';
    if (!iscomment)
        cur[curlen++] = '#';
    strcpy(cur + curlen, add);
    if (!endnewline)
        strcat(cur, "\n");

    return cur;
}

Bool xf86getBoolValue(Bool* val, const(char)* str)
{
    if (!val || !str)
        return False;
    if (*str == '\0') {
        *val = True;
    }
    else {
        if (xf86nameCompare(str, "1") == 0)
            *val = True;
        else if (xf86nameCompare(str, "on") == 0)
            *val = True;
        else if (xf86nameCompare(str, "true") == 0)
            *val = True;
        else if (xf86nameCompare(str, "yes") == 0)
            *val = True;
        else if (xf86nameCompare(str, "0") == 0)
            *val = False;
        else if (xf86nameCompare(str, "off") == 0)
            *val = False;
        else if (xf86nameCompare(str, "false") == 0)
            *val = False;
        else if (xf86nameCompare(str, "no") == 0)
            *val = False;
        else
            return False;
    }
    return True;
}
