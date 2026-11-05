module dix.extension_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X112
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import dix.callback;
public import dix.extension;
public import common.misc;

enum EXTENSION_MAJOR_APPLE_WM =            (EXTENSION_BASE + 0);
enum EXTENSION_MAJOR_APPLE_DRI =           (EXTENSION_BASE + 1);
enum EXTENSION_MAJOR_BIG_REQUESTS =        (EXTENSION_BASE + 2);
enum EXTENSION_MAJOR_COMPOSITE =           (EXTENSION_BASE + 3);
enum EXTENSION_MAJOR_DAMAGE =              (EXTENSION_BASE + 4);
enum EXTENSION_MAJOR_DOUBLE_BUFFER =       (EXTENSION_BASE + 5);
enum EXTENSION_MAJOR_DPMS =                (EXTENSION_BASE + 6);
enum EXTENSION_MAJOR_DRI2 =                (EXTENSION_BASE + 7);
enum EXTENSION_MAJOR_DRI3 =                (EXTENSION_BASE + 8);
enum EXTENSION_MAJOR_GENERIC_EVENT =       (EXTENSION_BASE + 9);
enum EXTENSION_MAJOR_GLX =                 (EXTENSION_BASE + 10);
enum EXTENSION_MAJOR_MIT_SCREEN_SAVER =    (EXTENSION_BASE + 11);
enum EXTENSION_MAJOR_NAMESPACE =           (EXTENSION_BASE + 12);
enum EXTENSION_MAJOR_PRESENT =             (EXTENSION_BASE + 13);
enum EXTENSION_MAJOR_RANDR =               (EXTENSION_BASE + 14);
enum EXTENSION_MAJOR_RECORD =              (EXTENSION_BASE + 15);
enum EXTENSION_MAJOR_RENDER =              (EXTENSION_BASE + 16);
enum EXTENSION_MAJOR_SECURITY =            (EXTENSION_BASE + 17);
enum EXTENSION_MAJOR_SELINUX =             (EXTENSION_BASE + 18);
enum EXTENSION_MAJOR_SHAPE =               (EXTENSION_BASE + 19);
enum EXTENSION_MAJOR_SHM =                 (EXTENSION_BASE + 20);
enum EXTENSION_MAJOR_SYNC =                (EXTENSION_BASE + 21);
enum EXTENSION_MAJOR_WINDOWS_DRI =         (EXTENSION_BASE + 22);
enum EXTENSION_MAJOR_XFIXES =              (EXTENSION_BASE + 23);
// enum EXTENSION_MAJOR_XF86_BIGFONT =        (EXTENSION_BASE + 24);
enum EXTENSION_MAJOR_XF86_DGA =            (EXTENSION_BASE + 24);
enum EXTENSION_MAJOR_XF86_DRI =            (EXTENSION_BASE + 25);
enum EXTENSION_MAJOR_XF86_VIDMODE =        (EXTENSION_BASE + 26);
enum EXTENSION_MAJOR_XC_MISC =             (EXTENSION_BASE + 27);
enum EXTENSION_MAJOR_XINPUT =              (EXTENSION_BASE + 28);
enum EXTENSION_MAJOR_XINERAMA =            (EXTENSION_BASE + 29);
enum EXTENSION_MAJOR_XKEYBOARD =           (EXTENSION_BASE + 30);
enum EXTENSION_MAJOR_XRESOURCE =           (EXTENSION_BASE + 31);
enum EXTENSION_MAJOR_XTEST =               (EXTENSION_BASE + 32);
enum EXTENSION_MAJOR_XVIDEO =              (EXTENSION_BASE + 33);
enum EXTENSION_MAJOR_XVMC =                (EXTENSION_BASE + 34);

enum RESERVED_EXTENSIONS =                 37;

struct ExtensionAccessCallbackParam {
    ClientPtr client;
    _ExtensionEntry* ext;
    Mask access_mode;
    int status;
}

// CallbackListPtr ExtensionAccessCallback;
// CallbackListPtr ExtensionDispatchCallback;

 /* _XSERVER_EXTENSION_PRIV_H */
