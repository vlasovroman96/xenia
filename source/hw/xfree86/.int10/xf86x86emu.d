module xf86x86emu;
@nogc nothrow:
extern(C): __gshared:
/*
 *                   XFree86 int10 module
 *   execute BIOS int 10h calls in x86 real mode environment
 *                 Copyright 1999 Egbert Eich
 */
import build.xorg_config;

import include.xf86;
import hw.xfree86.os_support.xf86_OSproc;;
import include.xf86Pci;
version = _INT10_PRIVATE;
import xf86int10_priv;
import hw.xfree86.os_support.int10Defines;
import x86emu;
import include.xf86int10;


// enum string M = `_X86EMU_env`;

// alias X86_EAX = _X86EMU_env.x86.R_EAX;
// alias X86_EBX = _X86EMU_env.x86.R_EBX;
// alias X86_ECX = _X86EMU_env.x86.R_ECX;
// alias X86_EDX = _X86EMU_env.x86.R_EDX;
// alias X86_ESI = _X86EMU_env.x86.R_ESI;
// alias X86_EDI = _X86EMU_env.x86.R_EDI;
// alias X86_EBP = _X86EMU_env.x86.R_EBP;
// alias X86_EIP = _X86EMU_env.x86.R_EIP;
// alias X86_ESP = _X86EMU_env.x86.R_ESP;
// alias X86_EFLAGS = _X86EMU_env.x86.R_EFLG;

// alias X86_FLAGS = _X86EMU_env.x86.R_FLG;
// alias X86_AX = _X86EMU_env.x86.R_AX;
// alias X86_BX = _X86EMU_env.x86.R_BX;
// alias X86_CX = _X86EMU_env.x86.R_CX;
// alias X86_DX = _X86EMU_env.x86.R_DX;
// alias X86_SI = _X86EMU_env.x86.R_SI;
// alias X86_DI = _X86EMU_env.x86.R_DI;
// alias X86_BP = _X86EMU_env.x86.R_BP;
// alias X86_IP = _X86EMU_env.x86.R_IP;
// alias X86_SP = _X86EMU_env.x86.R_SP;
// alias X86_CS = _X86EMU_env.x86.R_CS;
// alias X86_DS = _X86EMU_env.x86.R_DS;
// alias X86_ES = _X86EMU_env.x86.R_ES;
// alias X86_SS = _X86EMU_env.x86.R_SS;
// alias X86_FS = _X86EMU_env.x86.R_FS;
// alias X86_GS = _X86EMU_env.x86.R_GS;

// alias X86_AL = _X86EMU_env.x86.R_AL;
// alias X86_BL = _X86EMU_env.x86.R_BL;
// alias X86_CL = _X86EMU_env.x86.R_CL;
// alias X86_DL = _X86EMU_env.x86.R_DL;

// alias X86_AH = _X86EMU_env.x86.R_AH;
// alias X86_BH = _X86EMU_env.x86.R_BH;
// alias X86_CH = _X86EMU_env.x86.R_CH;
// alias X86_DH = _X86EMU_env.x86.R_DH;
// alias M = _X86EMU_env;

private void x86emu_do_int(int num)
{
    Int10Current.num = num;

    if (!int_handler(Int10Current)) {
        X86EMU_halt_sys();
    }
}

void xf86ExecX86int10(xf86Int10InfoPtr pInt)
{
    int sig = setup_int(pInt);

    if (sig < 0)
        return;

    if (int_handler(pInt)) {
        X86EMU_exec();
    }

    finish_int(pInt, sig);
}

Bool xf86Int10ExecSetup(xf86Int10InfoPtr pInt)
{
    int i = void;
    X86EMU_intrFuncs[256] intFuncs = void;

    X86EMU_pioFuncs pioFuncs = {
        inb: x_inb,
        inw: x_inw,
        inl: x_inl,
        outb: x_outb,
        outw: x_outw,
        outl: x_outl
    };

    X86EMU_memFuncs memFuncs = {
        (&Mem_rb),
        (&Mem_rw),
        (&Mem_rl),
        (&Mem_wb),
        (&Mem_ww),
        (&Mem_wl)
    };

    X86EMU_setupMemFuncs(&memFuncs);

    pInt.cpuRegs = &M;
    M.mem_base = 0;
    M.mem_size = 1024 * 1024 + 1024;
    X86EMU_setupPioFuncs(&pioFuncs);

    for (i = 0; i < 256; i++)
        intFuncs[i] = x86emu_do_int;
    X86EMU_setupIntrFuncs(intFuncs.ptr);
    return TRUE;
}

void printk(const(char)* fmt, ...)
{
    va_list argptr = void;

    core.stdc.stdarg.va_start(argptr, fmt);
    LogVMessageVerb(X_NONE, -1, fmt, argptr);
    core.stdc.stdarg.va_end(argptr);
}
