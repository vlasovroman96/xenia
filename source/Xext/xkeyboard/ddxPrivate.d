module xkb.ddxPrivate;
@nogc nothrow:
extern(C): __gshared:

import build.dix_config;

//import x11.X;

import xkb.xkbsrv_priv;

import dix.window;
import xkb.xkbstr;


// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// int XkbDDXPrivate(DeviceIntPtr dev, KeyCode key, XkbAction* act)
// {
//     return 0;
// }
