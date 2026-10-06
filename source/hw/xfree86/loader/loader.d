module hw.xfree86.loader.loader;
@nogc nothrow:
extern(C): __gshared:
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

import core.stdc.string;
import include.os;
// import hw.xfree86.loader.loader;
import hw.xfree86.loader.loaderProcs;
import os.log;
import loadmod;

enum RTLD_DEFAULT = null;

version (Posix) {
    version = HAVE_DLFCN_H;
}

version (HAVE_DLFCN_H) {

import core.sys.posix.dlfcn;
//import x11.Xos;
import include.xf86Module;

} else {
static assert(0, "i have no dynamic linker and i must scream");
}

version (XORG_NO_SDKSYMS) {} else {
void*[1] xorg_symbols;
}

struct  ModuleVersions{
    int xf86Version;
    int ansicVersion;
    int videodrvVersion;
    int xinputVersion;
    int extensionVersion;
    int fontVersion;
};

void LoaderInit()
{
version (XORG_NO_SDKSYMS) {} else {
    LogMessageVerb(X_INFO, 2, "Loader magic: %p\n", cast(void*) xorg_symbols);
}
    LogMessageVerb(X_INFO, 2, "Module ABI versions:\n");
    LogMessageVerb(X_NONE, 2, "\t%s: %d.%d\n", ABI_CLASS_ANSIC.ptr,
                   mixin(GET_ABI_MAJOR!("LoaderVersionInfo.ansicVersion").ptr),
                   mixin(GET_ABI_MINOR!("LoaderVersionInfo.ansicVersion").ptr));
    LogMessageVerb(X_NONE, 2, "\t%s: %d.%d\n", ABI_CLASS_VIDEODRV.ptr,
                   mixin(GET_ABI_MAJOR!("LoaderVersionInfo.videodrvVersion").ptr),
                   mixin(GET_ABI_MINOR!("LoaderVersionInfo.videodrvVersion").ptr));
    LogMessageVerb(X_NONE, 2, "\t%s : %d.%d\n", ABI_CLASS_XINPUT.ptr,
                   mixin(GET_ABI_MAJOR!("LoaderVersionInfo.xinputVersion").ptr),
                   mixin(GET_ABI_MINOR!("LoaderVersionInfo.xinputVersion").ptr));
    LogMessageVerb(X_NONE, 2, "\t%s : %d.%d\n", ABI_CLASS_EXTENSION.ptr,
                   mixin(GET_ABI_MAJOR!("LoaderVersionInfo.extensionVersion").ptr),
                   mixin(GET_ABI_MINOR!("LoaderVersionInfo.extensionVersion").ptr));

    LoaderInitPath();
}

void LoaderClose()
{
    LoaderClosePath();
}

/* Public Interface to the loader. */

void* LoaderOpen(const(char)* module_, int* errmaj)
{
    void* ret = void;

version (DEBUG) {
    ErrorF("LoaderOpen(%s)\n", module_);
}

    LogMessage(X_INFO, "Loading %s\n", module_);

    if (((ret = dlopen(module_, RTLD_LAZY | RTLD_GLOBAL)) is null)) {
        LogMessage(X_ERROR, "Failed to load %s: %s\n", module_, dlerror());
        if (errmaj)
            *errmaj = LDR_NOLOAD;
        return null;
    }

    return ret;
}

void* LoaderSymbol(const(char)* name)
{
    static void* global_scope = null;
    void* p = void;

    p = dlsym(RTLD_DEFAULT, name);
    if (p !is null)
        return p;

    if (!global_scope)
        global_scope = dlopen(null, RTLD_LAZY | RTLD_GLOBAL);

    if (global_scope)
        return dlsym(global_scope, name);

    return null;
}

void* LoaderSymbolFromModule(void* handle, const(char)* name)
{
    ModuleDescPtr mod = cast(ModuleDescPtr)handle;
    return dlsym(mod.handle, name);
}

void LoaderUnload(const(char)* name, void* handle)
{
    LogMessageVerb(X_INFO, 1, "Unloading %s\n", name);
    if (handle)
        dlclose(handle);
}

Bool LoaderIgnoreAbi = FALSE;
Bool is_nvidia_proprietary = FALSE;

void LoaderSetIgnoreAbi()
{
    /* Only used to keep consistency with the loader api */
    /* This really doesn't have to be a proc */
    LoaderIgnoreAbi = TRUE;
}

Bool LoaderShouldIgnoreABI()
{
    /* The nvidia proprietary DDX driver calls this deprecated function */
    return is_nvidia_proprietary || LoaderIgnoreAbi;
}

int LoaderGetABIVersion(const(char)* abiclass)
{
    struct _Classes {
        const(char)* name = void;
        int version_ = void;
    }
    _Classes[5] classes;
    classes[0] = _Classes(ABI_CLASS_ANSIC, LoaderVersionInfo.ansicVersion);
        /*
         * XXX This is a hack. XXX
         *
         * The 470 nvidia driver only knows about an older abi
         * where struct _Screen has an extra field.
         *
         * The modern nvidia drivers (e.g. 570) know about both
         * abi's, and have different code paths for supporting
         * both abi's.
         *
         * The modern nvidia drivers use this function to determine
         * what video abi the X server uses, so it knows whether or
         * not to use the newer abi, or the older abi, where
         * struct _Screen has an extra field.
         *
         * The X server implements the older abi for struct _Screen,
         * that the 470 driver knows, and we lie to the nvidia drivers
         * that we use that older abi for the entire X server, so that
         * modern nvidia drivers know to use the code path for supporting
         * this older abi.
         *
         * We lie to the nvidia driver and claim to have an older abi
         * so that both modern and old nvidia drivers work.
         *
         * In the future, nvidia might remove the code path for supporting
         * the old abi from it's DDX driver.
         *
         * When that happens, unless we want to add major hacks and
         * complexity to the codebase, we will no longer be able to
         * support both abi's at once.
         *
         * Therefore we have added a compile-time flag that switches
         * between abi's.
         */
         int ver = LoaderVersionInfo.videodrvVersion;
        //  version(CONFIG_LEGACY_NVIDIA_PADDING) {
            ver = is_nvidia_proprietary ?  ABI_NVIDIA_VERSION : LoaderVersionInfo.videodrvVersion;
        //  }
        classes[1] = _Classes(ABI_CLASS_VIDEODRV, ver);

        classes[2] = _Classes(ABI_CLASS_XINPUT, LoaderVersionInfo.xinputVersion);
        classes[3] = _Classes(ABI_CLASS_EXTENSION, LoaderVersionInfo.extensionVersion),
        classes[4] = _Classes(null, 0);
    int i = void;

    for (i = 0; classes[i].name; i++) {
        if (!strcmp(classes[i].name, abiclass)) {
            return classes[i].version_;
        }
    }

    return 0;
}
