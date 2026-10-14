module hw.xfree86.os_support.misc.SlowBcopy;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*******************************************************************************
  for Alpha Linux
*******************************************************************************/

/*
 *   Create a dependency that should be immune from the effect of register
 *   renaming as is commonly seen in superscalar processors.  This should
 *   insert a minimum of 100-ns delays between reads/writes at clock rates
 *   up to 100 MHz---GGL
 *
 *   Slowbcopy(char *src, char *dst, int count)
 *
 */
import build.xorg_config;

//import x11.X;
import include.xf86;
import include.xf86Priv;
import include.xf86_OSlib;
import hw.xfree86.utils.compiler;

/* The outb() isn't needed on my machine, but who knows ... -- ost */
void xf86SlowBcopy(ubyte* src, ubyte* dst, int len)
{
    while (len--)
        *dst++ = *src++;
}

version (Alpha) {

version (linux) {

c_ulong _bus_base();

enum string useSparse() = `(!_bus_base())`;

enum SPARSE = (7);

} else {

enum string useSparse() = `0`;

enum SPARSE = 0;

}

void xf86SlowBCopyFromBus(ubyte* src, ubyte* dst, int count)
{
    if (mixin(useSparse!())) {
        c_ulong addr = void;
        c_long result = void;

        addr = cast(c_ulong) src;
        while (count) {
            result = *cast(/*volatile*/ int*) addr;
            result >>= ((addr >> SPARSE) & 3) * 8;
            *dst++ = cast(ubyte) (0xffUL & result);
            addr += 1 << SPARSE;
            count--;
            outb(0x80, 0x00);
        }
    }
    else
        xf86SlowBcopy(src, dst, count);
}

void xf86SlowBCopyToBus(ubyte* src, ubyte* dst, int count)
{
    if (mixin(useSparse!())) {
        c_ulong addr = void;

        addr = cast(c_ulong) dst;
        while (count) {
            *cast(/*volatile*/ uint*) addr =
                cast(ushort) (*src) * 0x01010101;
            src++;
            addr += 1 << SPARSE;
            count--;
            outb(0x80, 0x00);
        }
    }
    else
        xf86SlowBcopy(src, dst, count);
}
}
