module include.xf86Module;
@nogc nothrow:
extern(C): __gshared:
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

/*
 * This file contains the parts of the loader interface that are visible
 * to modules.  This is the only loader-related header that modules should
 * include.
 *
 * It should include a bare minimum of other headers.
 *
 * Longer term, the module/loader code should probably live directly under
 * Xserver/.
 *
 * XXX This file arguably belongs in xfree86/loader/.
 */

 
// //public import x11.Xfuncproto;
public import x11.Xdefs;
public import x11.Xmd;

enum NULL = cast(void *)null;


enum DEFAULT_LIST = cast(byte*)-1;

/* Built-in ABI classes.  These definitions must not be changed. */
enum ABI_CLASS_NONE =		NULL;
enum ABI_CLASS_ANSIC =		"X.Org ANSI C Emulation";
enum ABI_CLASS_VIDEODRV =	"X.Org Video Driver";
enum ABI_CLASS_XINPUT =	"X.Org XInput driver";
enum ABI_CLASS_EXTENSION =	"X.Org Server Extension";

enum ABI_MINOR_MASK =		0x0000FFFF;
enum ABI_MAJOR_MASK =		0xFFFF0000;
enum string GET_ABI_MINOR(alias v) = `((` ~ v ~ `) & ABI_MINOR_MASK)`;
enum string GET_ABI_MAJOR(alias v) = `(((` ~ v ~ `) & ABI_MAJOR_MASK) >> 16)`;
// enum string SET_ABI_VERSION(alias maj, alias min) = `
// 		((((` ~ maj.stringof ~ `) << 16) & ABI_MAJOR_MASK) | ((` ~ min.stringof ~ `) & ABI_MINOR_MASK))`;
auto SET_ABI_VERSION(T)(T maj, T min) {
    return (((maj << 16) & ABI_MAJOR_MASK) | (min & ABI_MINOR_MASK));
}

/*
 * ABI versions.  Each version has a major and minor revision.  Modules
 * using lower minor revisions must work with servers of a higher minor
 * revision.  There is no compatibility between different major revisions.
 * Whenever the ABI_ANSIC_VERSION is changed, the others must also be
 * changed.  The minor revision mask is 0x0000FFFF and the major revision
 * mask is 0xFFFF0000.
 */
enum ABI_ANSIC_VERSION =	SET_ABI_VERSION(1, 4);

/* XXX This is a compile-time option that changes abi XXX */
/* TODO: Remove this toggle in 26.0 */
// version (CONFIG_LEGACY_NVIDIA_PADDING) {
enum ABI_VIDEODRV_VERSION =	SET_ABI_VERSION(28, 1);
// } else {
// enum ABI_VIDEODRV_VERSION =    SET_ABI_VERSION(28, 0);
// }
enum ABI_XINPUT_VERSION =	SET_ABI_VERSION(26, 0);
enum ABI_EXTENSION_VERSION =	SET_ABI_VERSION(11, 0);

/* hack to get both modern and ancient nvidia DDX drivers to work at the same time */
enum ABI_NVIDIA_VERSION =      SET_ABI_VERSION(25, 2);

enum MODINFOSTRING1 =	0xef23fdc5;
enum MODINFOSTRING2 =	0x10dc023a;

enum MODULEVENDORSTRING =	"X.Org Foundation";


/* Error return codes for errmaj */
enum LoaderErrorCode {
    LDR_NOERROR = 0,
    LDR_NOMEM,                  /* memory allocation failed */
    LDR_NOENT,                  /* Module file does not exist */
    LDR_NOLOAD,                 /* type specific loader failed */
    LDR_ONCEONLY,               /* Module should only be loaded once (not an error) */
    LDR_MISMATCH,               /* the module include.didn't match the spec'd requirements */
    LDR_BADUSAGE,               /* LoadModule is called with bad arguments */
    LDR_INVALID,                /* The module include.doesn't have a valid ModuleData object */
    LDR_BADOS,                  /* The module include.doesn't support the OS */
    LDR_MODSPECIFIC             /* A module-specific error in the SetupProc */
}
alias LDR_NOERROR = LoaderErrorCode.LDR_NOERROR;
alias LDR_NOMEM = LoaderErrorCode.LDR_NOMEM;
alias LDR_NOENT = LoaderErrorCode.LDR_NOENT;
alias LDR_NOLOAD = LoaderErrorCode.LDR_NOLOAD;
alias LDR_ONCEONLY = LoaderErrorCode.LDR_ONCEONLY;
alias LDR_MISMATCH = LoaderErrorCode.LDR_MISMATCH;
alias LDR_BADUSAGE = LoaderErrorCode.LDR_BADUSAGE;
alias LDR_INVALID = LoaderErrorCode.LDR_INVALID;
alias LDR_BADOS = LoaderErrorCode.LDR_BADOS;
alias LDR_MODSPECIFIC = LoaderErrorCode.LDR_MODSPECIFIC;


/*
 * Some common module include.classes.  The moduleclass can be used to identify
 * that modules loaded are of the correct type.  This is a finer
 * classification than the ABI classes even though the default set of
 * classes have the same names.  For example, not all modules that require
 * the video driver ABI are themselves video drivers.
 */
enum MOD_CLASS_NONE =		NULL;
enum MOD_CLASS_VIDEODRV =	"X.Org Video Driver";
enum MOD_CLASS_XINPUT =	"X.Org XInput Driver";
enum MOD_CLASS_EXTENSION =	"X.Org Server Extension";

/* This structure is expected to be returned by the initfunc */
struct XF86ModuleVersionInfo {
    const(char)* modname;        /* name of module, e.g. "foo" */
    const(char)* vendor;         /* vendor specific string */
    CARD32 _modinfo1_;          /* constant MODINFOSTRING1/2 to find */
    CARD32 _modinfo2_;          /* infoarea with a binary editor or sign tool */
    CARD32 xf86version;         /* contains XF86_VERSION_CURRENT */
    CARD8 majorversion;         /* module-specific major version */
    CARD8 minorversion;         /* module-specific minor version */
    CARD16 patchlevel;          /* module-specific patch level */
    const(char)* abiclass;       /* ABI class that the module include.uses */
    CARD32 abiversion;          /* ABI version */
    const(char)* moduleclass;    /* module include.class description */
    CARD32[4] checksum;         /* contains a digital signature of the */
    /* version info structure */
}

/*
 * This structure can be used to callers of LoadModule and LoadSubModule to
 * specify version and/or ABI requirements.
 */
struct XF86ModReqInfo {
    CARD8 majorversion;         /* module-specific major version */
    CARD8 minorversion;         /* module-specific minor version */
    CARD16 patchlevel;          /* module-specific patch level */
    const(char)* abiclass;       /* ABI class that the module include.uses */
    CARD32 abiversion;          /* ABI version */
    const(char)* moduleclass;    /* module include.class */
}

enum string MODULE_VERSION_NUMERIC(string maj, string min, string patch) = `
	((((` ~ maj ~ `) & 0xFF) << 24) | (((` ~ min ~ `) & 0xFF) << 16) | (` ~ patch ~ ` & 0xFFFF))`;

/* Prototypes for Loader functions that are exported to modules */
void * LoadSubModule(void*, const(char)*, const(char)**, const(char)**, void*, const(XF86ModReqInfo)*, int*, int*);
void * LoaderSymbol(const(char)*);
// void * LoaderSymbolFromModule(void*, const(char)*);
void  LoaderErrorMsg(const(char)*, const(char)*, int, int);

/* deprecated, only kept for backwards compat w/ proprietary NVidia driver */
//  Bool  _X_DEPRECATED;
// void  _X_DEPRECATED;

alias ModuleSetupProc = void* function(void*, void*, int*, int*);
alias ModuleTearDownProc = void function(void*);

enum string MODULESETUPPROTO(string func) = `void* func(void*, void*, int*, int*);`;

/*
 * Module information header. Every loadable module include.needs to export a symbol
 * of that type, so the loader can call into the module include.for initialization.
 * The symbol must be named <modulename> + "ModuleData".
 */
struct XF86ModuleData {
    /* must point to structure with version information */
    XF86ModuleVersionInfo* vers;
    /* called on module include.load (if not null) */
    ModuleSetupProc setup;
    /* called on module include.teardown with setup()'s result as parameter (if not null) */
    ModuleTearDownProc teardown;
}

/*
 * declare module include.version info structure for an input driver module
 */
enum string XF86_MODULE_VERSION_INPUT(string _name, string _major, string _minor, string _patchlevel) = `
    static XF86ModuleVersionInfo modVersion = { 
        modname: ` ~ _name ~ `,                  
        vendor: MODULEVENDORSTRING,     
        _modinfo1_: MODINFOSTRING1,         
        _modinfo2_: MODINFOSTRING2,         
        xf86version: XORG_VERSION_CURRENT,   
        majorversion: ` ~ _major ~ `,                 
        minorversion: ` ~ _minor ~ `,                 
        patchlevel: ` ~ _patchlevel ~ `,            
        abiclass: ABI_CLASS_XINPUT,       
        abiversion: ABI_XINPUT_VERSION,     
        moduleclass: MOD_CLASS_XINPUT,       
    };`;

/*
 * declare module include.version info structure for an video driver module
 */
enum string XF86_MODULE_VERSION_VIDEO(string _name, string _major, string _minor, string _patchlevel) = `
    static XF86ModuleVersionInfo modVersion = { 
        modname: ` ~ _name ~ `,                  
        vendor: MODULEVENDORSTRING,     
        _modinfo1_: MODINFOSTRING1,         
        _modinfo2_: MODINFOSTRING2,         
        xf86version: XORG_VERSION_CURRENT,   
        majorversion: ` ~ _major ~ `,                 
        minorversion: ` ~ _minor ~ `,                 
        patchlevel: ` ~ _patchlevel ~ `,            
        abiclass: ABI_CLASS_VIDEODRV,     
        abiversion: ABI_VIDEODRV_VERSION,   
        moduleclass: MOD_CLASS_VIDEODRV,     
    };`;

enum string XF86_MODULE_DATA_INPUT(string _modname, string _setup, string _teardown, string _name, string _major, string _minor, string _patchlevel) = `
    ` ~ XF86_MODULE_VERSION_INPUT!(_name, _major, _minor, _patchlevel) ~ ` 
    void  XF86ModuleData = { 
        vers: &modVersion, 
        setup: ` ~ _setup ~ `, 
        teardown: ` ~ _teardown ~ `, 
    };`;

enum string XF86_MODULE_DATA_VIDEO(string _modname, string _setup, string _teardown, string _name, string _major, string _minor, string _patchlevel) = `
    ` ~ XF86_MODULE_VERSION_VIDEO!(_name, _major, _minor, _patchlevel) ~ ` 
    void  XF86ModuleData = { 
        vers: &modVersion, 
        setup: ` ~ _setup ~ `, 
        teardown: ` ~ _teardown ~ `, 
    };`;

 /* _XF86MODULE_H */
