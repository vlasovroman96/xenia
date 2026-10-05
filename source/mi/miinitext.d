module mi.miinitext;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

/*
 * Copyright (c) 2000 by The XFree86 Project, Inc.
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

import build.dix_config;
import build.xlibre_server;
import Xext.dri2.dri2ext;
import externs.X11.extensions.dri2proto;

version (HAVE_XORG_CONFIG_H) {
import build.xorg_config;
import xf86Extensions;
}

/* some DDXes must explicitly prohibit some extensions */
version (DISABLE_EXT_DPMS) {
}

version (DISABLE_EXT_MITSHM) {
}
import glx.vndext;

import miext.extinit_priv;

import include.misc;
import include.extension;
import mi.micmap;
import include.os;
import include.globals;
import Xext.xres;
import mi.miinitext;
import os.log;
import externs.gnu;
import Xext.panoramiX;
import Xext.shape;
import xfixes.xfixes;
import render.render;
import damageext.c;
import geext;
import Xi.extinit;
import Xext.saver;
import composite.compext;

import Xext.dpms;
import Xext.bigreq;

import Xext.sync;

// import Xext.geext;
import xkb.xkb.xkb;
import xcmisc;
import dri3.dri3;
import Xext.shm;
import present.present_screen;
import randr.randr;
import Xext.xtest;

private const ExtensionModule[] staticExtensions = () {
    ExtensionModule[] result;

    result ~= ExtensionModule(&GEExtensionInit, "Generic Event Extension", null);
    result ~= ExtensionModule(&ShapeExtensionInit, "SHAPE", &noShapeExtension);

    static if (is(typeof({ static if(CONFIG_MITSHM){} }))) {
        static if(CONFIG_MITSHM)result ~= ExtensionModule(&ShmExtensionInit, "MIT-SHM", &noMITShmExtension);
    }

    result ~= ExtensionModule(&XInputExtensionInit, "XInputExtension", null);

    static if (XTEST) result ~= ExtensionModule(&XTestExtensionInit, "XTEST", &noTestExtensions);

    result ~= ExtensionModule(&BigReqExtensionInit, "BIG-REQUESTS", null);
    result ~= ExtensionModule(&SyncExtensionInit, "SYNC", null);
    result ~= ExtensionModule(&XkbExtensionInit, "XKEYBOARD", null);
    result ~= ExtensionModule(&XCMiscExtensionInit, "XC-MISC", null);

    version (XCSECURITY) result ~= ExtensionModule(&SecurityExtensionInit, "SECURITY", &noSecurityExtension);
    version (CONFIG_NAMESPACE) result ~= ExtensionModule(&NamespaceExtensionInit, "NAMESPACE", &noNamespaceExtension);
    static if(XINERAMA)result ~= ExtensionModule(&PanoramiXExtensionInit, "XINERAMA", &noPanoramiXExtension);

    result ~= ExtensionModule(&XFixesExtensionInit, "XFIXES", &noXFixesExtension);

    version (XF86BIGFONT) result ~= ExtensionModule(&XFree86BigfontExtensionInit, "XFree86-Bigfont", &noXFree86BigfontExtension);

    result ~= ExtensionModule(&RenderExtensionInit, "RENDER", &noRenderExtension);

    result ~= ExtensionModule(&RRExtensionInit, "RANDR", &noRRExtension);
    result ~= ExtensionModule(&CompositeExtensionInit, "COMPOSITE", &noCompositeExtension);
    // result ~= ExtensionModule(&CompositeExtensionInit, "COMPOSITE", &noCompositeExtension);

    result ~= ExtensionModule(&DamageExtensionInit, "DAMAGE", &noDamageExtension);

    result ~= ExtensionModule(&ScreenSaverExtensionInit, "MIT-SCREEN-SAVER", &noScreenSaverExtension);
    version (DBE) result ~= ExtensionModule(&DbeExtensionInit, "DOUBLE-BUFFER", &noDbeExtension);
    version (XRECORD) result ~= ExtensionModule(&RecordExtensionInit, "RECORD", &noTestExtensions);
    result ~= ExtensionModule(&DPMSExtensionInit, "DPMS", &noDPMSExtension);
    result ~= ExtensionModule(&present_extension_init, "Present", null);
    result ~= ExtensionModule(&DRI2ExtensionInit, DRI2_NAME, &noDRI2Extension);
    result ~= ExtensionModule(&dri3_extension_init, "DRI3", null);
    result ~= ExtensionModule(&ResExtensionInit, "X-Resource", &noResExtension);

    version (XV)
    {
        result ~= ExtensionModule(&XvExtensionInit, "XVideo", &noXvExtension);
        result ~= ExtensionModule(&XvMCExtensionInit, "XVideo-MotionCompensation", &noXvExtension);
    }

    // version (XSELINUX) result ~= ExtensionModule(&SELinuxExtensionInit, "SELinux", &noSELinuxExtension);
    result ~= ExtensionModule(&GlxExtensionInit, "GLX", &noGlxExtension);
    // result ~= ExtensionModule(&GlxExtensionInit, "GLX", &noGlxExtension);

    return result;
}();

void ListStaticExtensions()
{
    // const(ExtensionModule)* ext = void;
    // int i = void;

    // ErrorF(" Only the following extensions can be run-time enabled/disabled:\n");
    // for (i = 0; i < mixin(ARRAY_SIZE!("staticExtensions.ptr")) - 1; i++) {
    //     ext = &staticExtensions[i];
    //     if (ext.disablePtr !is null) {
    //         ErrorF("\t%s\n", ext.name);
    //     }
    // }
}

Bool EnableDisableExtension(const(char)* name, Bool enable)
{
    ExtensionModule* ext = void;
    int i = void;

    for (i = 0; i < mixin(ARRAY_SIZE!("staticExtensions")); i++) {
        ext = cast(ExtensionModule*)&staticExtensions[i];
        if (strcasecmp(name, ext.name) == 0) {
            if (ext.disablePtr !is null) {
                *ext.disablePtr = !enable;
                return TRUE;
            }
            else {
                /* Extension is always on, impossible to disable */
                return enable;  /* okay if they wanted to enable,
                                   fail if they tried to disable */
            }
        }
    }

    return FALSE;
}

void EnableDisableExtensionError(const(char)* name, Bool enable)
{
    const(ExtensionModule)* ext = void;
    int i = void;
    Bool found = FALSE;

    for (i = 0; i < mixin(ARRAY_SIZE!("staticExtensions")); i++) {
        ext = &staticExtensions[i];
        if ((strcmp(name, ext.name) == 0) && (ext.disablePtr is null)) {
            ErrorF("[mi] Extension \"%s\" can not be disabled\n", name);
            found = TRUE;
            break;
        }
    }
    if (found == FALSE) {
        ErrorF("[mi] Extension \"%s\" is not recognized\n", name);
        /* Disabling a non-existing extension is a no-op anyway */
        if (enable == FALSE)
            return;
    }
    ListStaticExtensions();
}

private ExtensionModule* ExtensionModuleList = null;
private int numExtensionModules = 0;

private void AddStaticExtensions()
{
    static Bool listInitialised = FALSE;

    if (listInitialised)
        return;
    listInitialised = TRUE;

    /* Add built-in extensions to the list. */
    LoadExtensionList(cast(ExtensionModule*)staticExtensions.ptr, cast(int)mixin(ARRAY_SIZE!("staticExtensions")), TRUE);
}

void InitExtensions(int argc, char** argv)
{
    int i = void;
    ExtensionModule* ext = void;

    AddStaticExtensions();

    for (i = 0; i < numExtensionModules; i++) {
        ext = &ExtensionModuleList[i];
        if (ext.initFunc !is null &&
            (ext.disablePtr is null || !*ext.disablePtr)) {
            LogMessageVerb(X_INFO, 3, "Initializing extension %s\n",
                           ext.name);

            (ext.initFunc) ();
        }
    }
}

private ExtensionModule* NewExtensionModuleList(int size)
{
    ExtensionModule* save = ExtensionModuleList;
    int n = void;

    /* Sanity check */
    if (!ExtensionModuleList)
        numExtensionModules = 0;

    n = numExtensionModules + size;
    ExtensionModuleList = cast(ExtensionModule*)reallocarray(ExtensionModuleList, n,
                                       ExtensionModule.sizeof);
    if (ExtensionModuleList is null) {
        ExtensionModuleList = save;
        return null;
    }
    else {
        numExtensionModules += size;
        return ExtensionModuleList + (numExtensionModules - size);
    }
}

void LoadExtensionList(ExtensionModule* ext, int size, Bool builtin)
{
    ExtensionModule* newext = void;
    int i = void;

    /* Make sure built-in extensions get added to the list before those
     * in modules. */
    AddStaticExtensions();

    if (((newext = NewExtensionModuleList(size)) is null))
        return;

    for (i = 0; i < size; i++, newext++) {
        newext.name = ext[i].name;
        newext.initFunc = ext[i].initFunc;
        newext.disablePtr = ext[i].disablePtr;
    }
}
