module xkb.ddxPrivate;
@nogc nothrow:
extern(C): __gshared:

import build.dix_config;

//import x11.X;

import xkb.xkbsrv_priv;

import include.windowstr;
import include.xkbstr;


// //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
// int XkbDDXPrivate(DeviceIntPtr dev, KeyCode key, XkbAction* act)
// {
//     return 0;
// }
