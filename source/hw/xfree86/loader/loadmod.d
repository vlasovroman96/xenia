module loadmod;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright 1995-1998 by Metro Link, Inc.
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Metro Link, Inc. not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Metro Link, Inc. makes no
 * representations about the suitability of this software for any purpose.
 *  It is provided "as is" without express or implied warranty.
 *
 * METRO LINK, INC. DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL METRO LINK, INC. BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */
/*
 * Copyright (c) 1997-2002 by The XFree86 Project, Inc.
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

import include.dix;
import include.os;
import hw.xfree86.loader.loaderProcs;
import include.xf86Module;
import hw.xfree86.loader.loader;
import xf86Module_priv;
import build.xlibre_server;

import core.sys.posix.sys.stat;
import core.sys.posix.sys.types;
import externs.regex;
import core.sys.posix.dirent;
import core.stdc.limits;
import os.log;
import externs.gnu;

enum XORG_MODULE_ABI_TAG = "xlibre-25";

struct _pattern {
    const(char)* pattern;
    regex_t rex;
}
alias PatternRec = _pattern;
alias PatternPtr = _pattern*;

/* Prototypes for static functions */
private char* FindModule(const(char)*, const(char)*, PatternPtr);

private char* LoaderGetCanonicalName(const(char)*, PatternPtr);


const(ModuleVersions) LoaderVersionInfo = {
    XORG_VERSION_CURRENT,
    ABI_ANSIC_VERSION,
    ABI_VIDEODRV_VERSION,
    ABI_XINPUT_VERSION,
    ABI_EXTENSION_VERSION,
};

private int[1] ModuleDuplicated = [ 0 ];

private void FreeStringList(char** paths)
{
    char** p = void;

    if (!paths)
        return;

    for (p = paths; *p; p++)
        free(*p);

    free(paths);
}

private char** defaultPathList = null;

struct LoaderModulePathListItem {
    xorg_list entry;
    char* name;
    char** paths;
}

xorg_list modulePathLists;

void LoaderInitPath() {
    /* defaultPathList is already set in xf86Init */
    xorg_list_init(&modulePathLists);
}

void LoaderClosePath() {
    LoaderModulePathListItem* item = void, next = void;
    mixin(xorg_list_for_each_entry_safe!("item", "next", "&modulePathLists", "entry", q{
        xorg_list_del(&item.entry);
        free(item.name);
        if (item.paths)
            FreeStringList(item.paths);
        free(item);
    }));
    xorg_list_del(&modulePathLists);
    FreeStringList(defaultPathList);
}

private Bool PathIsAbsolute(const(char)* path)
{
    return *path == '/';
}

/*
 * Convert a comma-separated path into a NULL-terminated array of path
 * elements, rejecting any that are not full absolute paths, and appending
 * a '/' when it isn't already present.
 */
private char** InitPathList(const(char)* path)
{
    char* fullpath = null;
    char* elem = null;
    char** list = null, save = null;
    int len = void;
    int addslash = void;
    int n = 0;

    fullpath = strdup(path);
    if (!fullpath)
        return null;
    elem = strtok(fullpath, ",");
    while (elem) {
        if (PathIsAbsolute(elem)) {
            len = cast(int)strlen(elem);
            addslash = (elem[len - 1] != '/');
            if (addslash)
                len++;
            save = list;
            list = cast(char**)reallocarray(list, n + 2, (char*).sizeof);
            if (!list) {
                if (save) {
                    save[n] = null;
                    FreeStringList(save);
                }
                free(fullpath);
                return null;
            }
            list[n] = cast(char*)calloc(1, len + 1);
            if (!list[n]) {
                FreeStringList(list);
                free(fullpath);
                return null;
            }
            strcpy(list[n], elem);
            if (addslash) {
                list[n][len - 1] = '/';
                list[n][len] = '\0';
            }
            n++;
        }
        elem = strtok(null, ",");
    }
    if (list)
        list[n] = null;
    free(fullpath);
    return list;
}

/*
 * Set a default search path or a search path for a specific driver
 */
void LoaderSetPath(const(char)* driver, const(char)* path)
{
    LoaderModulePathListItem* item = void;

    if (!driver) {
        if (path) {
            FreeStringList(defaultPathList);
            defaultPathList = InitPathList(path);
        }
        return;
    }

    mixin(xorg_list_for_each_entry!("item", "&modulePathLists", "entry", q{
        if (!strcmp(item.name, driver)) {
            FreeStringList(item.paths);
            if (path)
                item.paths = InitPathList(path);
            else
                item.paths = null;
            return;
        }
    }));

    item = cast(LoaderModulePathListItem*) malloc(LoaderModulePathListItem.sizeof);
    if (item) {
        item.name = strdup(driver);
        if (path)
            item.paths = InitPathList(path);
        else
            item.paths = null;
    }
    if (item && item.name && (!path || item.paths))
        xorg_list_add(&item.entry, &modulePathLists);
    else {
        LogMessage(X_ERROR, "Failed to store module search path \"%s\" for module %s\n",
            path ? path : "<NULL>", driver);
        if (item) {
            if (item.name) free(item.name);
            if (item.paths) FreeStringList(item.paths);
            free(item);
        }
    }
}

/*
 * Get a default search path or a search path for a specific driver
 * and make it effective
 */
private char** LoaderGetPath(const(char)* module_)
{
    LoaderModulePathListItem* item = void;

    mixin(xorg_list_for_each_entry!("item", "&modulePathLists", "entry", q{
        if (!strcmp(item.name, module_)) {
            if (item.paths)
                return item.paths;
            else
                return defaultPathList;
        }
    }));

    return defaultPathList;
}

/* Standard set of module subdirectories to search, in order of preference */
private const(char)*[4] stdSubdirs = [
    // first try loading from per-ABI subdir
    XORG_MODULE_ABI_TAG ~"/",
    // next try loading from legacy xlibre-25.0 ABI subdir
    // TODO remove this in version 26
    "xlibre-25.0/",
    // now try loading from legacy / unversioned directories
    "",
    null
];

/*
 * Standard set of module name patterns to check, in order of preference
 * These are regular expressions (suitable for use with POSIX regex(3)).
 *
 * This list assumes that you're an ELFish platform and therefore your
 * shared libraries are named something.so.  If we're ever nuts enough
 * to port this DDX to, say, Darwin, we'll need to fix this.
 */
private PatternRec[7] stdPatterns;

static this() {
version(_CYGWIN_ ){
    stdPatterns[0] = PatternRec("^cyg(.*)\\.dll$",),
    stdPatterns[1] = PatternRec("(.*)_drv\\.dll$",),
    stdPatterns[2] = PatternRec("(.*)\\.dll$",);

}
else {
    stdPatterns[0] = PatternRec("^lib(.*)\\.so$",),
    stdPatterns[1] = PatternRec("(.*)_drv\\.so$",),
    stdPatterns[2] = PatternRec("(.*)\\.so$",);
}
// #endif
    stdPatterns[3] = PatternRec(null, ); 
    // {null,}
// ];
}

private PatternPtr InitPatterns(const(char)** patternlist)
{
    char[80] errmsg = void;
    int i = void, e = void;
    PatternPtr patterns = null;
    PatternPtr p = null;
    static int firstTime = 1;
    const(char)** s = void;

    if (firstTime) {
        /* precompile stdPatterns */
        firstTime = 0;
        for (p = stdPatterns.ptr; p.pattern !is null; p++) 
            if ((e = regcomp(&p.rex, p.pattern, REG_EXTENDED)) != 0) {
                regerror(e, &p.rex, errmsg.ptr, errmsg.sizeof);
                FatalError("InitPatterns: regcomp error for `%s': %s\n",
                           p.pattern, errmsg.ptr);
            }
    }

    if (patternlist) {
        for (i = 0, s = patternlist; *s; i++, s++)
            if (*s is cast(char*)DEFAULT_LIST)
                i += mixin(ARRAY_SIZE!("stdPatterns")) - 1 - 1;
        patterns = cast(PatternPtr)calloc(i + 1, PatternRec.sizeof);
        if (!patterns) {
            return null;
        }
        for (i = 0, s = patternlist; *s; i++, s++)
            if (*s !is cast(char*)DEFAULT_LIST) {
                p = patterns + i;
                p.pattern = *s;
                if ((e = regcomp(&p.rex, p.pattern, REG_EXTENDED)) != 0) {
                    regerror(e, &p.rex, errmsg.ptr, errmsg.sizeof);
                    ErrorF("InitPatterns: regcomp error for `%s': %s\n",
                           p.pattern, errmsg.ptr);
                    i--;
                }
            }
            else {
                for (p = stdPatterns.ptr; p.pattern; p++, i++)
                    patterns[i] = *p;
                if (p != stdPatterns.ptr)
                    i--;
            }
        patterns[i].pattern = null;
    }
    else
        patterns = stdPatterns.ptr;
    return patterns;
}

private void FreePatterns(PatternPtr patterns)
{
    if (patterns && patterns != stdPatterns.ptr)
        free(patterns);
}

private char* FindModuleInSubdir(const(char)* dirpath, const(char)* module_)
{
    dirent* direntry = null;
    DIR* dir = null;
    char* ret = null; char[PATH_MAX] tmpBuf = void;
    stat_t stat_buf = void;

    dir = opendir(dirpath);
    if (!dir)
        return null;

    while ((direntry = readdir(dir)) !is null) {
        if (direntry.d_name[0] == '.')
            continue;
        snprintf(tmpBuf.ptr, PATH_MAX, "%s%s/", dirpath, direntry.d_name.ptr);
        /* the stat with the appended / fails for normal files,
           and works for sub dirs fine, looks a bit strange in strace
           but does seem to work */
        if ((stat(tmpBuf.ptr, &stat_buf) == 0) && S_ISDIR(stat_buf.st_mode)) {
            if ((ret = FindModuleInSubdir(tmpBuf.ptr, module_)) !is null)
                break;
            continue;
        }

version (Cygwin) {
        snprintf(tmpBuf.ptr, PATH_MAX, "cyg%s.dll", module_);
} else {
        snprintf(tmpBuf.ptr, PATH_MAX, "lib%s.so", module_);
}
        if (strcmp(direntry.d_name.ptr, tmpBuf.ptr) == 0) {
            if (asprintf(&ret, "%s%s", dirpath, tmpBuf.ptr) == -1)
                ret = null;
            break;
        }

version (Cygwin) {
        snprintf(tmpBuf.ptr, PATH_MAX, "%s_drv.dll", module_);
} else {
        snprintf(tmpBuf.ptr, PATH_MAX, "%s_drv.so", module_);
}
        if (strcmp(direntry.d_name.ptr, tmpBuf.ptr) == 0) {
            if (asprintf(&ret, "%s%s", dirpath, tmpBuf.ptr) == -1)
                ret = null;
            break;
        }

version (Cygwin) {
        snprintf(tmpBuf.ptr, PATH_MAX, "%s.dll", module_);
} else {
        snprintf(tmpBuf.ptr, PATH_MAX, "%s.so", module_);
}
        if (strcmp(direntry.d_name.ptr, tmpBuf.ptr) == 0) {
            if (asprintf(&ret, "%s%s", dirpath, tmpBuf.ptr) == -1)
                ret = null;
            break;
        }
    }

    closedir(dir);
    return ret;
}

private char* FindModule(const(char)* module_, const(char)* dirname, PatternPtr patterns)
{
    char[PATH_MAX + 1] buf = void;
    char* name = null;
    const(char)** s = void;

    if (strlen(dirname) > PATH_MAX)
        return null;

    for (s = stdSubdirs.ptr; *s; s++) {
        snprintf(buf.ptr, PATH_MAX, "%s%s", dirname, *s);
        if ((name = FindModuleInSubdir(buf.ptr, module_))!is null)
            break;
    }

    return name;
}

private const(char)** _LoaderListDir(const(char)* subdir, const(char)** patternlist, int* saved_len)
{
    char[PATH_MAX + 1] buf = void;
    char** pathlist = void;
    char** elem = void;
    PatternPtr patterns = null;
    PatternPtr p = void;
    DIR* d = void;
    dirent* dp = void;
    regmatch_t[2] match = void;
    stat_t stat_buf = void;
    int len = void, dirlen = void;
    char* fp = void;
    char** listing = null;
    char** save = void;
    char** ret = null;
    int n = 0;

    if (((pathlist = defaultPathList)is null))
        return null;
    if (((patterns = InitPatterns(patternlist)) is null))
        goto bail;

    for (elem = pathlist; *elem; elem++) {
        dirlen = snprintf(buf.ptr, PATH_MAX, "%s/%s", *elem, subdir);
        fp = buf.ptr + dirlen;
        if (stat(buf.ptr, &stat_buf) == 0 && S_ISDIR(stat_buf.st_mode) &&
            (d = opendir(buf.ptr))!is null) {
            if (buf[dirlen - 1] != '/') {
                buf[dirlen++] = '/';
                fp++;
            }
            while ((dp = readdir(d))!is null) {
                if (dirlen + strlen(dp.d_name.ptr) > PATH_MAX)
                    continue;
                strcpy(fp, dp.d_name.ptr);
                if (!(stat(buf.ptr, &stat_buf) == 0 && S_ISREG(stat_buf.st_mode)))
                    continue;
                for (p = patterns; p.pattern; p++) {
                    if (regexec(&p.rex, dp.d_name.ptr, 2, match.ptr, 0) == 0 &&
                        match[1].rm_so != -1) {
                        len = cast(int)(match[1].rm_eo - match[1].rm_so);
                        save = listing;
                        listing = cast(char**)reallocarray(listing, n + 2, (char*).sizeof);
                        if (!listing) {
                            if (save) {
                                save[n] = null;
                                FreeStringList(save);
                            }
                            closedir(d);
                            goto bail;
                        }
                        listing[n] = cast(char*)calloc(1, len + 1);
                        if (!listing[n]) {
                            FreeStringList(listing);
                            closedir(d);
                            goto bail;
                        }
                        strncpy(listing[n], dp.d_name.ptr + match[1].rm_so, len);
                        listing[n][len] = '\0';
                        n++;
                        break;
                    }
                }
            }
            closedir(d);
        }
    }
    if (listing)
        listing[n] = null;
    ret = listing;

 bail:
    FreePatterns(patterns);
    *saved_len = ret ? n : 0;
    return cast(const(char)**) ret;
}

const(char)** LoaderListDir(const(char)* subdir, const(char)** patternlist)
{
    int len = 0;
    const(char)** ret = null;
    int subdirlen = cast(int)strlen(subdir);
    for (int i = 0; i < stdSubdirs.sizeof / typeof(*stdSubdirs.ptr).sizeof; i++) {
        int prefixsize = typeof(stdSubdirs[i]).sizeof;
        char* dir = cast(char*) malloc(prefixsize + subdirlen);
        if (!dir) {
            free(ret);
            return null;
        }
        memcpy(dir, stdSubdirs[i], prefixsize - 1);
        memcpy(dir + prefixsize - 1, subdir, subdirlen + 1);

        int sublen = 0;
        const(char)** subret = _LoaderListDir(dir, patternlist, &sublen);
        free(dir);
        if (!subret) {
            continue;
        }

        int oldlen = len;
        len += sublen;
        void* tmp = reallocarray(ret, len + 1, typeof(*ret).sizeof);
        if (!tmp) {
            free(ret);
            return null;
        }

        ret = cast(const(char)**) tmp;
        memcpy(ret + oldlen, subret, sublen);
    }
    if (ret) {
        ret[len] = null;
    }
    return ret;
}

private Bool CheckVersion(const(char)* module_, XF86ModuleVersionInfo* data, const(XF86ModReqInfo)* req)
{
    int[4] vercode = void;
    c_long ver = data.xf86version;

    LogMessage(X_INFO, "Module %s: vendor=\"%s\"\n",
               data.modname ? data.modname : "UNKNOWN!",
               data.vendor ? data.vendor : "UNKNOWN!");

    vercode[0] = cast(int)(ver / 10000000);
    vercode[1] = cast(int)((ver / 100000) % 100);
    vercode[2] = cast(int)((ver / 1000) % 100);
    vercode[3] = cast(int)(ver % 1000);
    LogMessageVerb(X_NONE, 1, "\tcompiled for %d.%d.%d", vercode[0], vercode[1], vercode[2]);
    if (vercode[3] != 0)
        LogMessageVerb(X_NONE, 1, ".%d", vercode[3]);
    LogMessageVerb(X_NONE, 1, ", module version = %d.%d.%d\n", data.majorversion,
                   data.minorversion, data.patchlevel);

    if (data.moduleclass)
        LogMessageVerb(X_NONE, 2, "\tModule class: %s\n", data.moduleclass);

    ver = -1;
    if (data.abiclass) {
        int abimaj = void, abimin = void;
        int vermaj = void, vermin = void;

        if (!strcmp(data.abiclass, ABI_CLASS_ANSIC))
            ver = LoaderVersionInfo.ansicVersion;
        else if (!strcmp(data.abiclass, ABI_CLASS_VIDEODRV))
            ver = LoaderVersionInfo.videodrvVersion;
        else if (!strcmp(data.abiclass, ABI_CLASS_XINPUT))
            ver = LoaderVersionInfo.xinputVersion;
        else if (!strcmp(data.abiclass, ABI_CLASS_EXTENSION))
            ver = LoaderVersionInfo.extensionVersion;

        abimaj = mixin(GET_ABI_MAJOR!("data.abiversion"));
        abimin = mixin(GET_ABI_MINOR!("data.abiversion"));
        LogMessageVerb(X_NONE, 2, "\tABI class: %s, version %d.%d\n",
                       data.abiclass, abimaj, abimin);
        if (ver != -1) {
            vermaj = mixin(GET_ABI_MAJOR!("ver"));
            vermin = mixin(GET_ABI_MINOR!("ver"));
            if (abimaj != vermaj) {
                LogMessageVerb(LoaderIgnoreAbi ? X_WARNING : X_ERROR, 0,
                               "%s: module ABI major version (%d) "
                               ~ "doesn't match the server's version (%d)\n",
                               module_, abimaj, vermaj);
                if (!LoaderIgnoreAbi)
                    return FALSE;
            }
            else if (abimin > vermin) {
                LogMessageVerb(LoaderIgnoreAbi ? X_WARNING : X_ERROR, 0,
                               "%s: module ABI minor version (%d) "
                               ~ "is newer than the server's version (%d)\n",
                               module_, abimin, vermin);
                if (!LoaderIgnoreAbi)
                    return FALSE;
            }
        }
    }

    /* Check against requirements that the caller has specified */
    if (req) {
        if (data.majorversion != req.majorversion) {
            LogMessageVerb(X_WARNING, 2, "%s: module major version (%d) "
                           ~ "doesn't match required major version (%d)\n",
                           module_, data.majorversion, req.majorversion);
            return FALSE;
        }
        else if (data.minorversion < req.minorversion) {
            LogMessageVerb(X_WARNING, 2, "%s: module minor version (%d) is "
                          ~ "less than the required minor version (%d)\n",
                          module_, data.minorversion, req.minorversion);
            return FALSE;
        }
        else if (data.minorversion == req.minorversion &&
                 data.patchlevel < req.patchlevel) {
            LogMessageVerb(X_WARNING, 2, "%s: module patch level (%d) "
                           ~ "is less than the required patch level "
                           ~ "(%d)\n", module_, data.patchlevel, req.patchlevel);
            return FALSE;
        }
        if (req.moduleclass) {
            if (!data.moduleclass ||
                strcmp(req.moduleclass, data.moduleclass)) {
                LogMessageVerb(X_WARNING, 2, "%s: Module class (%s) doesn't "
                               ~ "match the required class (%s)\n", module_,
                               data.moduleclass ? data.moduleclass : "<NONE>",
                               req.moduleclass);
                return FALSE;
            }
        }
        else if (req.abiclass != ABI_CLASS_NONE) {
            if (!data.abiclass || strcmp(req.abiclass, data.abiclass)) {
                LogMessageVerb(X_WARNING, 2, "%s: ABI class (%s) doesn't match"
                               ~ " the required ABI class (%s)\n", module_,
                               data.abiclass ? data.abiclass : "<NONE>",
                               req.abiclass);
                return FALSE;
            }
        }
        if (req.abiclass != ABI_CLASS_NONE) {
            int reqmaj = void, reqmin = void, maj = void, min = void;

            reqmaj = mixin(GET_ABI_MAJOR!("req.abiversion"));
            reqmin = mixin(GET_ABI_MINOR!("req.abiversion"));
            maj = mixin(GET_ABI_MAJOR!("data.abiversion"));
            min = mixin(GET_ABI_MINOR!("data.abiversion"));
            if (maj != reqmaj) {
                LogMessageVerb(X_WARNING, 2, "%s: ABI major version (%d) "
                               ~ "doesn't match the required ABI major version "
                               ~ "(%d)\n", module_, maj, reqmaj);
                return FALSE;
            }
            /* XXX Maybe this should be the other way around? */
            if (min > reqmin) {
                LogMessageVerb(X_WARNING, 2, "%s: module ABI minor version "
                               ~ "(%d) is newer than that available (%d)\n",
                               module_, min, reqmin);
                return FALSE;
            }
        }
    }
    return TRUE;
}

private ModuleDescPtr AddSibling(ModuleDescPtr head, ModuleDescPtr new_)
{
    new_.sib = head;
    return new_;
}

void* LoadSubModule(void* _parent, const(char)* module_, const(char)** subdirlist, const(char)** patternlist, void* options, const(XF86ModReqInfo)* modreq, int* errmaj, int* errmin)
{
    ModuleDescPtr submod = void;
    ModuleDescPtr parent = cast(ModuleDescPtr) _parent;

    LogMessageVerb(X_INFO, 3, "Loading sub module \"%s\"\n", module_);

    if (PathIsAbsolute(module_)) {
        LogMessage(X_ERROR, "LoadSubModule: "
                   ~ "Absolute module path not permitted: \"%s\"\n", module_);
        if (errmaj)
            *errmaj = LDR_BADUSAGE;
        if (errmin)
            *errmin = 0;
        return null;
    }

    submod = LoadModule(module_, options, modreq, errmaj);
    if (submod && submod != cast(ModuleDescPtr) 1) {
        parent.child = AddSibling(parent.child, submod);
        submod.parent = parent;
    }
    return submod;
}

ModuleDescPtr DuplicateModule(ModuleDescPtr mod, ModuleDescPtr parent)
{
    ModuleDescPtr ret = void;

    if (!mod)
        return null;

    ret = cast(ModuleDesc*) calloc(1, ModuleDesc.sizeof);
    if (ret is null)
        return null;

    ret.handle = mod.handle;

    ret.SetupProc = mod.SetupProc;
    ret.TearDownProc = mod.TearDownProc;
    ret.TearDownData = cast(void*)ModuleDuplicated.ptr;
    ret.child = DuplicateModule(cast(module_desc*)mod.child, ret);
    ret.sib = DuplicateModule(cast(module_desc*)mod.sib, parent);
    ret.parent = parent;
    ret.VersionInfo = mod.VersionInfo;

    return ret;
}

private const(char)*[13] compiled_in_modules = [
    "ddc",
    "fb",
    "i2c",
    "ramdac",
    "dbe",
    "record",
    "extmod",
    "dri",
    "dri2",
    "glx",
    null
];

static this() {
bool isDRI3 = false;
version( DRI3){
    isDRI3 = true;
    compiled_in_modules[10] = "dri3";
    compiled_in_modules[11] = null;
}
version( PRESENT){
    static if(isDRI3) {
        compiled_in_modules[11] = "present";
        compiled_in_modules[12] = null;
    }
    else {
       compiled_in_modules[10] = "present";
       compiled_in_modules[11] = null;
    }
}
}

/*
 * LoadModule: load a module
 *
 * module       The module name.  Normally this is not a filename but the
 *              module's "canonical name.  A full pathname is, however,
 *              also accepted.
 * options      A NULL terminated list of Options that are passed to the
 *              module's SetupProc function.
 * modreq       An optional XF86ModReqInfo* containing
 *              version/ABI/vendor-ABI requirements to check for when
 *              loading the module.  The following fields of the
 *              XF86ModReqInfo struct are checked:
 *                majorversion - must match the module's majorversion exactly
 *                minorversion - the module's minorversion must be >= this
 *                patchlevel   - the module's minorversion.patchlevel must be
 *                               >= this.  Patchlevel is ignored when
 *                               minorversion is not set.
 *                abiclass     - (string) must match the module's abiclass
 *                abiversion   - must be consistent with the module's
 *                               abiversion (major equal, minor no older)
 *                moduleclass  - string must match the module's moduleclass
 *                               string
 *              "don't care" values are ~0 for numbers, and NULL for strings
 * errmaj       Major error return.
 *
 */
ModuleDescPtr LoadModule(const(char)* module_, void* options, const(XF86ModReqInfo)* modreq, int* errmaj)
{
    XF86ModuleData* initdata = null;
    char** pathlist = null;
    char* found = null;
    char* name = null;
    char** path_elem = null;
    char* p = null;
    ModuleDescPtr ret = null;
    PatternPtr patterns = null;
    int noncanonical = 0;
    char* m = null;
    const(char)** cim = void;

    LogMessageVerb(X_INFO, 3, "LoadModule: \"%s\"", module_);

    /* Ignore abi check for the nvidia proprietary DDX driver */
    is_nvidia_proprietary = !strcmp(module_, "nvidia");

    patterns = InitPatterns(null);
    name = LoaderGetCanonicalName(module_, patterns);
    noncanonical = (name && strcmp(module_, name) != 0);
    if (noncanonical) {
        LogMessageVerb(X_NONE, 3, " (%s)\n", name);
        LogMessageVerb(X_WARNING, 1,
                       "LoadModule: given non-canonical module name \"%s\"\n",
                       module_);
        m = name;
    }
    else {
        LogMessageVerb(X_NONE, 3, "\n");
        m = cast(char*) module_;
    }

    if (is_nvidia_proprietary) {
        LogMessage(X_WARNING, "LoadModule: If you are using one of the legacy "
                              ~ "branches of the nvidia proprierary DDX driver "
                              ~ "(e.g. 470, 390, 340, etc.)\n");
        LogMessage(X_WARNING, "LoadModule: you need to build Xlibre "
                              ~ "with -Dlegacy_nvidia_padding=true\n");
        LogMessage(X_WARNING, "LoadModule: Otherwise, you will get a "
                              ~ "segmentation fault due to the abi mismatch "
                              ~ "between the new X server abi and the one these "
                              ~ "old drivers are compiled against.\n");
        LogMessage(X_WARNING, "LoadModule: If you are using one of the maintained "
                              ~ "branches of the nvidia nvidia kernel drivers,\n");
        LogMessage(X_WARNING, "LoadModule: you can try using the in-tree, open-source modesetting "
                              ~ "DDX driver instead of the proprietary nvidia DDX driver.\n");
        if (!LoaderIgnoreAbi) {
            /* warn every time this is hit */
            LogMessage(X_WARNING, "LoadModule: Implicitly ignoring abi mismatch "
                       ~ "for the nvidia proprierary DDX driver\n");
        }
    }

    /* Backward compatibility, vbe and int10 are merged into int10 now */
    if (!strcmp(m, "vbe"))
        m = name = strdup("int10");

    assert(m);

    for (cim = compiled_in_modules.ptr; *cim; cim++)
        if (!strcmp(m, *cim)) {
            LogMessageVerb(X_INFO, 3, "Module \"%s\" already built-in\n", m);
            ret = cast(ModuleDescPtr) 1;
            goto LoadModule_exit;
        }

    if (!name) {
        if (errmaj)
            *errmaj = LDR_BADUSAGE;
        goto LoadModule_fail;
    }
    ret = cast(ModuleDesc*) calloc(1, ModuleDesc.sizeof);
    if (!ret) {
        if (errmaj)
            *errmaj = LDR_NOMEM;
        goto LoadModule_fail;
    }

    pathlist = LoaderGetPath(name);
    if (!pathlist) {
        /* This could be a calloc failure too */
        if (errmaj)
            *errmaj = LDR_BADUSAGE;
        goto LoadModule_fail;
    }

    /*
     * if the module name is not a full pathname, we need to
     * check the elements in the path
     */
    if (PathIsAbsolute(module_))
        found = cast(char*)Xstrdup(module_);
    path_elem = pathlist;
    while (!found && *path_elem !is null) {
        found = FindModule(m, *path_elem, patterns);
        path_elem++;
        /*
         * When the module name isn't the canonical name, search for the
         * former if no match was found for the latter.
         */
        if (!*path_elem && m == name) {
            path_elem = pathlist;
            m = cast(char*) module_;
        }
    }

    /*
     * did we find the module?
     */
    if (!found) {
        LogMessage(X_WARNING, "Warning, couldn't open module %s\n", module_);
        if (errmaj)
            *errmaj = LDR_NOENT;
        goto LoadModule_fail;
    }
    ret.handle = LoaderOpen(found, errmaj);
    if (ret.handle is null)
        goto LoadModule_fail;

    /* drop any explicit suffix from the module name */
    p = strchr(name, '.');
    if (p)
        *p = '\0';

    /*
     * now check if the special data object <modulename>ModuleData is
     * present.
     */
    if (asprintf(&p, "%sModuleData", name) == -1) {
        p = null;
        if (errmaj)
            *errmaj = LDR_NOMEM;
        goto LoadModule_fail;
    }
    initdata = cast(XF86ModuleData*)LoaderSymbolFromModule(ret, p);
    if (initdata) {
        ModuleSetupProc setup = void;
        ModuleTearDownProc teardown = void;
        XF86ModuleVersionInfo* vers = void;

        vers = initdata.vers;
        setup = initdata.setup;
        teardown = initdata.teardown;

        if (vers) {
            if (!CheckVersion(module_, vers, modreq)) {
                if (errmaj)
                    *errmaj = LDR_MISMATCH;
                goto LoadModule_fail;
            }
        }
        else {
            LogMessage(X_ERROR, "LoadModule: Module %s does not supply"
                       ~ " version information\n", module_);
            if (errmaj)
                *errmaj = LDR_INVALID;
            goto LoadModule_fail;
        }
        if (setup)
            ret.SetupProc = setup;
        if (teardown)
            ret.TearDownProc = teardown;
        ret.VersionInfo = vers;
    }
    else {
        /* no initdata, fail the load */
        LogMessage(X_ERROR, "LoadModule: Module %s does not have a %s "
                   ~ "data object.\n", module_, p);
        if (errmaj)
            *errmaj = LDR_INVALID;
        goto LoadModule_fail;
    }
    if (ret.SetupProc) {
        ret.TearDownData = ret.SetupProc(ret, options, errmaj, null);
        if (!ret.TearDownData) {
            goto LoadModule_fail;
        }
    }
    else if (options) {
        LogMessage(X_WARNING, "Module Options present, but no SetupProc "
                   ~ "available for %s\n", module_);
    }
    goto LoadModule_exit;

 LoadModule_fail:
    UnloadModule(cast(module_desc*)ret);
    ret = null;

 LoadModule_exit:
    FreePatterns(patterns);
    free(found);
    free(name);
    free(p);

    return ret;
}

void UnloadModule(ModuleDescPtr mod)
{
    if (mod == cast(ModuleDescPtr) 1)
        return;

    if (mod is null)
        return;

    if (mod.VersionInfo) {
        const(char)* name = mod.VersionInfo.modname;

        if (mod.parent)
            LogMessageVerb(X_INFO, 3, "UnloadSubModule: \"%s\"\n", name);
        else
            LogMessageVerb(X_INFO, 3, "UnloadModule: \"%s\"\n", name);

        if (mod.TearDownData != ModuleDuplicated.ptr) {
            if ((mod.TearDownProc) && (mod.TearDownData))
                mod.TearDownProc(mod.TearDownData);
            LoaderUnload(name, mod.handle);
        }
    }

    if (mod.child)
        UnloadModule(cast(module_desc*)mod.child);
    if (mod.sib)
        UnloadModule(cast(module_desc*)mod.sib);
    free(mod);
}

void UnloadSubModule(ModuleDescPtr mod)
{
    /* Some drivers are calling us on built-in submodules, ignore them */
    if (mod == cast(ModuleDescPtr) 1)
        return;
    RemoveChild(mod);
    UnloadModule(cast(module_desc*)mod);
}

private void RemoveChild(ModuleDescPtr child)
{
    ModuleDescPtr mdp = void;
    ModuleDescPtr prevsib = void;
    ModuleDescPtr parent = void;

    if (!child.parent)
        return;

    parent = child.parent;
    if (parent.child == child) {
        parent.child = child.sib;
        child.sib = null;
        return;
    }

    prevsib = parent.child;
    mdp = prevsib.sib;
    while (mdp && mdp != child) {
        prevsib = mdp;
        mdp = mdp.sib;
    }
    if (mdp == child)
        prevsib.sib = child.sib;
    child.sib = null;
    return;
}

void LoaderErrorMsg(const(char)* name, const(char)* modname, int errmaj, int errmin)
{
    const(char)* msg = void;
    MessageType type = X_ERROR;

    switch (errmaj) {
    case LDR_NOERROR:
        msg = "no error";
        break;
    case LDR_NOMEM:
        msg = "out of memory";
        break;
    case LDR_NOENT:
        msg = "module does not exist";
        break;
    case LDR_NOLOAD:
        msg = "loader failed";
        break;
    case LDR_ONCEONLY:
        msg = "already loaded";
        type = X_INFO;
        break;
    case LDR_MISMATCH:
        msg = "module requirement mismatch";
        break;
    case LDR_BADUSAGE:
        msg = "invalid argument(s) to LoadModule()";
        break;
    case LDR_INVALID:
        msg = "invalid module";
        break;
    case LDR_BADOS:
        msg = "module doesn't support this OS";
        break;
    case LDR_MODSPECIFIC:
        msg = "module-specific error";
        break;
    default:
        msg = "unknown error";
    }
    if (name)
        LogMessage(type, "%s: Failed to load module \"%s\" (%s, %d)\n",
                   name, modname, msg, errmin);
    else
        LogMessage(type, "Failed to load module \"%s\" (%s, %d)\n",
                   modname, msg, errmin);
}

/* Given a module path or file name, return the module's canonical name */
private char* LoaderGetCanonicalName(const(char)* modname, PatternPtr patterns)
{
    const(char)* s = void;
    int len = void;
    PatternPtr p = void;
    regmatch_t[2] match = void;

    /* Strip off any leading path */
    s = strrchr(modname, '/');
    if (s is null)
        s = modname;
    else
        s++;

    /* Find the first regex that is matched */
    for (p = patterns; p.pattern; p++)
        if (regexec(&p.rex, s, 2, match.ptr, 0) == 0 && match[1].rm_so != -1) {
            len = cast(int)(match[1].rm_eo - match[1].rm_so);
            char* str = cast(char*) calloc(1, len + 1);
            if (!str)
                return null;
            strncpy(str, s + match[1].rm_so, len);
            str[len] = '\0';
            return str;
        }

    /* If there is no match, return the whole name minus the leading path */
    return strdup(s);
}

/*
 * Return the module version information.
 */
c_ulong LoaderGetModuleVersion(ModuleDescPtr mod)
{
    if (!mod || mod == cast(ModuleDescPtr) 1 || !mod.VersionInfo)
        return 0;

    return mixin(MODULE_VERSION_NUMERIC!("mod.VersionInfo.majorversion",
                                  "mod.VersionInfo.minorversion",
                                  "mod.VersionInfo.patchlevel"));
}
