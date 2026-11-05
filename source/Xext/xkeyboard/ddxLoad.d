module xkb.ddxLoad;
@nogc nothrow:
extern(C): __gshared:
/************************************************************
Copyright (c) 1993 by Silicon Graphics Computer Systems, Inc.

Permission to use, copy, modify, and distribute this
software and its documentation for any purpose and without
fee is hereby granted, provided that the above copyright
notice appear in all copies and that both that copyright
notice and this permission notice appear in supporting
documentation, and that the name of Silicon Graphics not be
used in advertising or publicity pertaining to distribution
of the software without specific prior written permission.
Silicon Graphics makes no representation about the suitability
of this software for any purpose. It is provided "as is"
without any express or implied warranty.

SILICON GRAPHICS DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS
SOFTWARE, INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY
AND FITNESS FOR A PARTICULAR PURPOSE. IN NO EVENT SHALL SILICON
GRAPHICS BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL
DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE
OR OTHER TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION  WITH
THE USE OR PERFORMANCE OF THIS SOFTWARE.

********************************************************/

import build.dix_config;

import config.xkb_config;

import core.stdc.stdio;
import core.stdc.stdlib;
import core.stdc.ctype;
import core.sys.posix.unistd;

//import x11.X;
// //import x11.Xos;
//import x11.Xproto;
//import x11.keysym;
//import externs.X11.extensions.XI;
import externs.X11.extensions.XKM;

import dix.dix_priv;
import os.log_priv;
import os.osdep;
import xkb.xkbfile_priv;
import xkb.xkbfmisc_priv;
import xkb.xkbrules_priv;
import xkb.xkbsrv_priv;

import dix.inputstr;import dix.scrnintstr;
import include.windowstr;
import include.xkbstr;
import externs.gnu;
import os.log;
import xkb.maprules;


enum	PRE_ERROR_MSG = "\"The XKEYBOARD keymap compiler (xkbcomp) reports:\"";
enum	ERROR_PREFIX =	"\"> \"";
enum	POST_ERROR_MSG1 = "\"Errors from xkbcomp are not fatal to the X server\"";
enum	POST_ERROR_MSG2 = "\"End of messages from xkbcomp\"";

version (Windows) {
enum PATHSEPARATOR = "\\";
} else {
enum PATHSEPARATOR = "/";
}



private void OutputDirectory(char* outdir, size_t size)
{
    const(char)* directory = null;
    const(char)* pathsep = "";
    int r = -1;

version (Windows) {} else {
    /* Can we write an xkm and then open it too? */
    if (access(XKM_OUTPUT_DIR, W_OK | X_OK) == 0) {
        directory = XKM_OUTPUT_DIR;
    } else {
        const(char)* xdg_runtime_dir = getenv("XDG_RUNTIME_DIR");

        if (xdg_runtime_dir && xdg_runtime_dir[0] == '/' &&
            access(xdg_runtime_dir, W_OK | X_OK) == 0)
            directory = xdg_runtime_dir;
    }

    if (directory && directory[strlen(directory) - 1] != '/')
        pathsep = "/";

} version (Windows) {
    directory = Win32TempDir();
    pathsep = "\\";
}

    if (directory)
        r = snprintf(outdir, size, "%s%s", directory, pathsep);
    if (r < 0 || r >= size) {
        assert(strlen("/tmp/") < size);
        strcpy(outdir, "/tmp/");
    }
}

/**
 * Callback invoked by XkbRunXkbComp. Write to out to talk to xkbcomp.
 */
alias xkbcomp_buffer_callback = void function(FILE* out_, void* userdata);

/**
 * Start xkbcomp, let the callback write into xkbcomp's stdin. When done,
 * return a strdup'd copy of the file name we've written to.
 */
private char* RunXkbComp(xkbcomp_buffer_callback callback, void* userdata)
{
    FILE* out_ = void;
    char* buf = null;
    char[PATH_MAX] keymap = 0;
    char[PATH_MAX] xkm_output_dir = 0;

    const(char)* emptystring = "";
    char* xkbbasedirflag = null;
    const(char)* xkbbindir = emptystring;
    const(char)* xkbbindirsep = emptystring;

version (Windows) {
    /* WIN32 has no popen. The input must be stored in a file which is
       used as input for xkbcomp. xkbcomp does not read from stdin. */
    char[PATH_MAX] tmpname = 0;
    const(char)* xkmfile = tmpname;
} else {
    const(char)* xkmfile = "-";
}

    snprintf(keymap.ptr, keymap.sizeof, "server-%s", display);

    OutputDirectory(xkm_output_dir.ptr, xkm_output_dir.sizeof);

version (Windows) {
    strcpy(tmpname.ptr, Win32TempDir());
    strcat(tmpname.ptr, "\\xkb_XXXXXX");
    cast(void) mktemp(tmpname.ptr);
}

    if (XkbBaseDirectory !is null) {
        if (asprintf(&xkbbasedirflag, "\"-R%s\"", XkbBaseDirectory) == -1)
            xkbbasedirflag = null;
    }

    if (XkbBinDirectory !is null) {
        int ld = cast(int)strlen(XkbBinDirectory);
        int lps = cast(int)strlen(PATHSEPARATOR);

        xkbbindir = XkbBinDirectory;

        if ((ld >= lps) && (strcmp(xkbbindir + ld - lps, PATHSEPARATOR) != 0)) {
            xkbbindirsep = PATHSEPARATOR;
        }
    }

    if (asprintf(&buf,
                 "\"%s%sxkbcomp\" -w %d %s -xkm \"%s\" "
                 ~ "-em1 %s -emp %s -eml %s \"%s%s.xkm\"",
                 xkbbindir, xkbbindirsep,
                 ((xkbDebugFlags < 2) ? 1 :
                  ((xkbDebugFlags > 10) ? 10 : cast(int) xkbDebugFlags)),
                 xkbbasedirflag ? xkbbasedirflag : "".ptr, xkmfile,
                 PRE_ERROR_MSG.ptr, ERROR_PREFIX.ptr, POST_ERROR_MSG1.ptr,
                 xkm_output_dir.ptr, keymap.ptr) == -1)
        buf = null;

    free(xkbbasedirflag);

    if (!buf) {
        LogMessage(X_ERROR,
                   "XKB: Could not invoke xkbcomp: not enough memory\n");
        return null;
    }

version (Windows) {
    out_ = fopen(tmpname.ptr, "w");
}
else {
    out_ = cast(FILE*)Popen(cast(char*)buf, "w");

}

    if (out_ !is null) {
        /* Now write to xkbcomp */
        (*callback)(out_, userdata);

        int cls;

version (Windows) {

    cls = (fclose(out_) == 0 && system(buf) >= 0);
} else {
        cls = Pclose(cast(void*)out_) == 0;
}
        if (cls)
        {
            if (xkbDebugFlags)
                DebugF("[xkb] xkb executes: %s\n", buf);
            free(buf);
version (Windows) {
            unlink(tmpname.ptr);
}
            return strdup(keymap.ptr);
        }
        else {
            LogMessage(X_ERROR, "Error compiling keymap (%s) executing '%s'\n",
                       keymap.ptr, buf);
        }
version (Windows) {
        /* remove the temporary file */
        unlink(tmpname.ptr);
}
    }
    else {
version (Windows) {} else {
        LogMessage(X_ERROR, "XKB: Could not invoke xkbcomp\n");
} version (Windows) {
        LogMessage(X_ERROR, "Could not open file %s\n", tmpname.ptr);
}
    }
    free(buf);
    return null;
}

struct XkbKeymapNamesCtx {
    XkbDescPtr xkb;
    XkbComponentNamesPtr names;
    uint want;
    uint need;
}

private void xkb_write_keymap_for_names_cb(FILE* out_, void* userdata)
{
    XkbKeymapNamesCtx* ctx = cast(XkbKeymapNamesCtx*)userdata;
version (DEBUG) {
    if (xkbDebugFlags) {
        ErrorF("[xkb] XkbDDXCompileKeymapByNames compiling keymap:\n");
        XkbWriteXKBKeymapForNames(stderr, ctx.names, ctx.xkb, ctx.want, ctx.need);
    }
}
    XkbWriteXKBKeymapForNames(out_, ctx.names, ctx.xkb, ctx.want, ctx.need);
}

private Bool XkbDDXCompileKeymapByNames(XkbDescPtr xkb, XkbComponentNamesPtr names, uint want, uint need, char* nameRtrn, int nameRtrnLen)
{
    char* keymap = void;
    Bool rc = FALSE;
    XkbKeymapNamesCtx ctx = {
        xkb: xkb,
        names: names,
        want: want,
        need: need
    };

    keymap = RunXkbComp(&xkb_write_keymap_for_names_cb, &ctx);

    if (keymap) {
        if(nameRtrn)
            strlcpy(nameRtrn, keymap, nameRtrnLen);

        free(keymap);
        rc = TRUE;
    } else if (nameRtrn)
        *nameRtrn = '\0';

    return rc;
}

struct XkbKeymapString {
    const(char)* keymap;
    size_t len;
}

private void xkb_write_keymap_string_cb(FILE* out_, void* userdata)
{
    XkbKeymapString* s = cast(XkbKeymapString*)userdata;
    fwrite(s.keymap, s.len, 1, out_);
}

private uint XkbDDXLoadKeymapFromString(DeviceIntPtr keybd, const(char)* keymap, int keymap_length, uint want, uint need, XkbDescPtr* xkbRtrn)
{
    uint have = void;
    char* map_name = void;
    XkbKeymapString map = {
        keymap: keymap,
        len: keymap_length
    };

    *xkbRtrn = null;

    map_name = RunXkbComp(&xkb_write_keymap_string_cb, &map);
    if (!map_name) {
        LogMessage(X_ERROR, "XKB: Couldn't compile keymap\n");
        return 0;
    }

    have = LoadXKM(want, need, map_name, xkbRtrn);
    free(map_name);

    return have;
}

private FILE* XkbDDXOpenConfigFile(const(char)* mapName, char* fileNameRtrn, int fileNameRtrnLen)
{
    char[PATH_MAX] buf = 0;
    char[PATH_MAX] xkm_output_dir = 0;
    FILE* file = void;


    buf[0] = '\0';
    if (mapName !is null) {
        OutputDirectory(xkm_output_dir.ptr, xkm_output_dir.sizeof);
            bool cond = (XkbBaseDirectory !is null) && (xkm_output_dir[0] != '/');
// static if(WIN32) {
//             cond = cond && (!isalpha(xkm_output_dir[0]) || xkm_output_dir[1] != ':');
// }
        if (cond) {
            if (snprintf(buf.ptr, PATH_MAX, "%s/%s%s.xkm", XkbBaseDirectory,
                         xkm_output_dir.ptr, mapName) >= PATH_MAX)
                buf[0] = '\0';
        }
        else {
            if (snprintf(buf.ptr, PATH_MAX, "%s%s.xkm", xkm_output_dir.ptr, mapName)
                >= PATH_MAX)
                buf[0] = '\0';
        }
        if (buf[0] != '\0')
            file = fopen(buf.ptr, "rb");
        else
            file = null;
    }
    else
        file = null;
    if ((fileNameRtrn !is null) && (fileNameRtrnLen > 0)) {
        strlcpy(fileNameRtrn, buf.ptr, fileNameRtrnLen);
    }
    return file;
}

private uint LoadXKM(uint want, uint need, const(char)* keymap, XkbDescPtr* xkbRtrn)
{
    FILE* file = void;
    char[PATH_MAX] fileName = 0;
    uint missing = void;

    file = XkbDDXOpenConfigFile(keymap, fileName.ptr, PATH_MAX);
    if (file is null) {
        LogMessage(X_ERROR, "Couldn't open compiled keymap file %s\n",
                   fileName.ptr);
        return 0;
    }
    missing = XkmReadFile(file, need, want, xkbRtrn);
    if (*xkbRtrn is null) {
        LogMessage(X_ERROR, "Error loading keymap %s\n", fileName.ptr);
        fclose(file);
        cast(void) unlink(fileName.ptr);
        return 0;
    }
    else {
        DebugF("Loaded XKB keymap %s, defined=0x%x\n", fileName.ptr,
               (*xkbRtrn).defined);
    }
    fclose(file);
    cast(void) unlink(fileName.ptr);
    return (need | want) & (~missing);
}

uint XkbDDXLoadKeymapByNames(DeviceIntPtr keybd, XkbComponentNamesPtr names, uint want, uint need, XkbDescPtr* xkbRtrn, char* nameRtrn, int nameRtrnLen)
{
    XkbDescPtr xkb = void;

    *xkbRtrn = null;
    if ((keybd is null) || (keybd.key is null) ||
        (keybd.key.xkbInfo is null))
        xkb = null;
    else
        xkb = keybd.key.xkbInfo.desc;
    if ((names.keycodes is null) && (names.types is null) &&
        (names.compat is null) && (names.symbols is null) &&
        (names.geometry is null)) {
        LogMessage(X_ERROR, "XKB: No components provided for device %s\n",
                   keybd && keybd.name ? keybd.name : "(unnamed keyboard)");
        return 0;
    }
    else if (!XkbDDXCompileKeymapByNames(xkb, names, want, need,
                                         nameRtrn, nameRtrnLen)) {
        LogMessage(X_ERROR, "XKB: Couldn't compile keymap\n");
        return 0;
    }

    return LoadXKM(want, need, nameRtrn, xkbRtrn);
}

Bool XkbDDXNamesFromRules(DeviceIntPtr keybd, const(char)* rules_name, XkbRF_VarDefsPtr defs, XkbComponentNamesPtr names)
{
    char[PATH_MAX] buf = 0;
    FILE* file = void;
    Bool complete = void;
    XkbRF_RulesPtr rules = void;

    if (!rules_name)
        return FALSE;

    if (snprintf(buf.ptr, PATH_MAX, "%s/rules/%s", XkbBaseDirectory, rules_name)
        >= PATH_MAX) {
        LogMessage(X_ERROR, "XKB: Rules name is too long\n");
        return FALSE;
    }

    file = fopen(buf.ptr, "r");
    if (!file) {
        LogMessage(X_ERROR, "XKB: Couldn't open rules file %s\n", buf.ptr);
        return FALSE;
    }

    rules = XkbRF_Create();
    if (!rules) {
        LogMessage(X_ERROR, "XKB: Couldn't create rules struct\n");
        fclose(file);
        return FALSE;
    }

    if (!XkbRF_LoadRules(file, rules)) {
        LogMessage(X_ERROR, "XKB: Couldn't parse rules file %s\n", rules_name);
        fclose(file);
        XkbRF_Free(rules);
        return FALSE;
    }

    memset(names, 0, typeof(*names).sizeof);
    complete = XkbRF_GetComponents(rules, defs, names);
    fclose(file);
    XkbRF_Free(rules);

    if (!complete)
        LogMessage(X_ERROR, "XKB: Rules returned no components\n");

    return complete;
}

private Bool XkbRMLVOtoKcCGST(DeviceIntPtr dev, XkbRMLVOSet* rmlvo, XkbComponentNamesPtr kccgst)
{
    XkbRF_VarDefsRec mlvo = void;

    mlvo.model = rmlvo.model;
    mlvo.layout = rmlvo.layout;
    mlvo.variant = rmlvo.variant;
    mlvo.options = rmlvo.options;

    return XkbDDXNamesFromRules(dev, rmlvo.rules, &mlvo, kccgst);
}

/**
 * Compile the given RMLVO keymap and return it. Returns the XkbDescPtr on
 * success or NULL on failure. If the components compiled are not a superset
 * or equal to need, the compilation is treated as failure.
 */
private XkbDescPtr XkbCompileKeymapForDevice(DeviceIntPtr dev, XkbRMLVOSet* rmlvo, int need)
{
    XkbDescPtr xkb = null;
    uint provided = void;
    XkbComponentNamesRec kccgst = { null };
    char[PATH_MAX] name = 0;

    if (XkbRMLVOtoKcCGST(dev, rmlvo, &kccgst)) {
        provided =
            XkbDDXLoadKeymapByNames(dev, &kccgst, XkmAllIndicesMask, need, &xkb,
                                    name.ptr, PATH_MAX);
        if ((need & provided) != need) {
            if (xkb) {
                XkbFreeKeyboard(xkb, 0, TRUE);
                xkb = null;
            }
        }
    }

    XkbFreeComponentNames(&kccgst, FALSE);
    return xkb;
}

private XkbDescPtr KeymapOrDefaults(DeviceIntPtr dev, XkbDescPtr xkb)
{
    XkbRMLVOSet dflts = void;

    if (xkb)
        return xkb;

    /* we didn't get what we really needed. And that will likely leave
     * us with a keyboard that doesn't work. Use the defaults instead */
    LogMessage(X_ERROR, "XKB: Failed to load keymap. Loading default "
                        ~ "keymap instead.\n");

    XkbGetRulesDflts(&dflts);

    xkb = XkbCompileKeymapForDevice(dev, &dflts, 0);

    XkbFreeRMLVOSet(&dflts, FALSE);

    return xkb;
}


XkbDescPtr XkbCompileKeymap(DeviceIntPtr dev, XkbRMLVOSet* rmlvo)
{
    XkbDescPtr xkb = void;
    uint need = void;

    if (!dev || !rmlvo) {
        LogMessage(X_ERROR, "XKB: No device or RMLVO specified\n");
        return null;
    }

    /* These are the components we really really need */
    need = XkmSymbolsMask | XkmCompatMapMask | XkmTypesMask |
        XkmKeyNamesMask | XkmVirtualModsMask;

    xkb = XkbCompileKeymapForDevice(dev, rmlvo, need);

    return KeymapOrDefaults(dev, xkb);
}

XkbDescPtr XkbCompileKeymapFromString(DeviceIntPtr dev, const(char)* keymap, int keymap_length)
{
    XkbDescPtr xkb = void;
    uint need = void, provided = void;

    if (!dev || !keymap) {
        LogMessage(X_ERROR, "XKB: No device or keymap specified\n");
        return null;
    }

    /* These are the components we really really need */
    need = XkmSymbolsMask | XkmCompatMapMask | XkmTypesMask |
           XkmKeyNamesMask | XkmVirtualModsMask;

    provided =
        XkbDDXLoadKeymapFromString(dev, keymap, keymap_length,
                                   XkmAllIndicesMask, need, &xkb);
    if ((need & provided) != need) {
        if (xkb) {
            XkbFreeKeyboard(xkb, 0, TRUE);
            xkb = null;
        }
    }

    return KeymapOrDefaults(dev, xkb);
}
