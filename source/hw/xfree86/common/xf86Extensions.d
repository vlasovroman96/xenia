module xf86Extensions;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2011 Daniel Stone
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 *
 * Author: Daniel Stone <daniel@fooishbar.org>
 */
import build.xorg_config;

// import xf86_priv;
// import xf86Config;
import include.xf86Module;
import xf86Extensions;
import xf86Opt_priv;
import hw.xfree86.common.xf86Option;
import include.xf86Parser;
import xf86Globals;
import externs.gnu;
import mi.miinitext;
import dix.inpututils;
import xf86VidMode;
import xf86DGA;
import hw.xfree86.dri.xf86dri;
import externs.X11.extensions.xf86vmproto;
import externs.X11.extensions.xf86dgaproto;
import build.xlibre_server;
import build.xlibre_server;

version (XSELINUX) {
import xselinux;
}
import build.xlibre_server;

static if(XFreeXDGA){
//import externs.X11.extensions.xf86dgaproto;
}

static if(build.xlibre_server.XF86VIDMODE){
//import externs.X11.extensions.xf86vmproto;
import include.vidmodestr;
}

alias InitExtension = void function();

struct ExtensionModule {
    InitExtension initFunc;
    const(char)* name;
    Bool* disablePtr;
}

Bool noXFree86VidModeExtension = 0;
Bool noXFree86DGAExtension = 0;
Bool noXFree86DRIExtension = 0;

/*
 * DDX-specific extensions.
 */
private ExtensionModule[4] extensionModules;

private bool extensionModulesInitialized;

private void initializeExtensionModules()
{
    if (extensionModulesInitialized)
        return;

    int i = 0;

    static if (XF86VIDMODE)
    {
        extensionModules[i++] = ExtensionModule(
            &XFree86VidModeExtensionInit,
            XF86VIDMODENAME,
            &noXFree86VidModeExtension
        );
    }

    static if (XFreeXDGA)
    {
        extensionModules[i++] = ExtensionModule(
            &XFree86DGAExtensionInit,
            XF86DGANAME,
            &noXFree86DGAExtension
        );
    }

    static if (XF86DRI)
    {
        extensionModules[i++] = ExtensionModule(
            &XFree86DRIExtensionInit,
            "XFree86-DRI",
            &noXFree86DRIExtension
        );
    }

    extensionModulesInitialized = true;
}
    

private void load_extension_config()
{
    XF86ConfModulePtr mod_con = xf86configptr.conf_modules;
    XF86LoadPtr modp = void;

    /* Only the best. */
    if (!mod_con)
        return;

    mixin(nt_list_for_each_entry!("modp", "mod_con.mod_load_lst", "list.next", q{
        InputOption* opt = void;

        if (strcasecmp(modp.load_name, "extmod") != 0)
            continue;

        /* extmod options are of the form "omit <extension-name>" */
        mixin(nt_list_for_each_entry!("opt", "modp.load_opt", "list.next", q{
            const(char)* key = input_option_get_key(opt);
            if (strncasecmp(key, "omit", 4) != 0 || strlen(key) < 5)
                continue;
            if (EnableDisableExtension(key + 4, FALSE))
                xf86MarkOptionUsed(opt);
        }));

// version (XSELINUX) {
//         if ((opt = xf86FindOption(cast(_InputOption*)modp.load_opt,
//                                   "SELinux mode disabled"))) {
//             xf86MarkOptionUsed(opt);
//             selinuxEnforcingState = SELINUX_MODE_DISABLED;
//         }
//         if ((opt = xf86FindOption(cast(_InputOption*)modp.load_opt,
//                                   "SELinux mode permissive"))) {
//             xf86MarkOptionUsed(opt);
//             selinuxEnforcingState = SELINUX_MODE_PERMISSIVE;
//         }
//         if ((opt = xf86FindOption(cast(_InputOption*)modp.load_opt,
//                                   "SELinux mode enforcing"))) {
//             xf86MarkOptionUsed(opt);
//             selinuxEnforcingState = SELINUX_MODE_ENFORCING;
//         }
// }
    }));
}

void xf86ExtensionInit()
{
    load_extension_config();

    initializeExtensionModules();

    LoadExtensionList(cast(ExtensionModule*)extensionModules.ptr, extensionModules.length, TRUE);
}
