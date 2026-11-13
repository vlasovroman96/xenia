module stub_init;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import hw.xfree86.os_support.xf86_os_support;
import hw.xfree86.os_support.xf86_OSlib;

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86OpenConsole()
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86CloseConsole()
{
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
Bool xf86VTKeepTtyIsSet()
{
     return False;
}


//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int xf86ProcessArgument(int argc, char** argv, int i)
{
    return 0;
}

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
void xf86UseMsg()
{
}

void xf86OSInputThreadInit()
{
    return;
}
