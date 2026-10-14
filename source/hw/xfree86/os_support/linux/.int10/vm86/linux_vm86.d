module linux_vm86;
@nogc nothrow:
extern(C): __gshared:
import build.xorg_config;

import core.stdc.errno;
import core.stdc.string;

import include.xf86;
import include.xf86_OSproc;;
import include.xf86Pci;
import hw.xfree86.utils.compiler;
version = _INT10_PRIVATE;
// import xf86int10;

// enum REG = pInt;

version (_VM86_LINUX) {
import hw.xfree86.os_support.int10Defines;


private vm86_struct vm86_s;

Bool xf86Int10ExecSetup(xf86Int10InfoPtr pInt)
{
    auto VM86S() => cast(vm86_struct *)pInt.cpuRegs;

    pInt.cpuRegs = &vm86_s;
    VM86S.flags = 0;
    VM86S.screen_bitmap = 0;
    VM86S.cpu_type = CPU_586;
    memset(&VM86S.int_revectored, 0xff, typeof(VM86S.int_revectored).sizeof);
    memset(&VM86S.int21_revectored, 0xff, typeof(VM86S.int21_revectored).sizeof);
    return TRUE;
}

/* get the linear address */
enum LIN_PREF_SI = ((pref_seg << 4) + X86_SI);
enum LWECX =       ((prefix66 ^ prefix67) ? X86_ECX : X86_CX);
enum LWECX_ZERO =  {if (prefix66 ^ prefix67) X86_ECX = 0; else X86_CX = 0;};
enum DF = (1 << 10);

/* vm86 fault handling */
private Bool vm86_GP_fault(xf86Int10InfoPtr pInt)
{
    ubyte* csp = void, lina = void;
    CARD32 org_eip = void;
    int pref_seg = void;
    int done = void, is_rep = void, prefix66 = void, prefix67 = void;

    // csp = lina = SEG_ADR(cast(ubyte*), X86_CS, IP);
    csp = lina = SEG_ADR(X86_CS, IP);


    is_rep = 0;
    prefix66 = prefix67 = 0;
    pref_seg = -1;

    /* eat up prefixes */
    done = 0;
    do {
        switch (MEM_RB(pInt, cast(int) csp++)) {
        case 0x66:             /* operand prefix */
            prefix66 = 1;
            break;
        case 0x67:             /* address prefix */
            prefix67 = 1;
            break;
        case 0x2e:             /* CS */
            pref_seg = X86_CS;
            break;
        case 0x3e:             /* DS */
            pref_seg = X86_DS;
            break;
        case 0x26:             /* ES */
            pref_seg = X86_ES;
            break;
        case 0x36:             /* SS */
            pref_seg = X86_SS;
            break;
        case 0x65:             /* GS */
            pref_seg = X86_GS;
            break;
        case 0x64:             /* FS */
            pref_seg = X86_FS;
            break;
        case 0xf0:             /* lock */
            break;
        case 0xf2:             /* repnz */
        case 0xf3:             /* rep */
            is_rep = 1;
            break;
        default:
            done = 1;
        }
    } while (!done);
    csp--;                      /* oops one too many */
    org_eip = X86_EIP;
    X86_IP += (csp - lina);

    switch (MEM_RB(pInt, cast(int) csp)) {
    case 0x6c:                 /* insb */
        /* NOTE: ES can't be overwritten; prefixes 66,67 should use esi,edi,ecx
         * but is anyone using extended regs in real mode? */
        /* WARNING: no test for DI wrapping! */
        X86_EDI += port_rep_inb(pInt, X86_DX, SEG_EADR((CARD32), X86_ES, DI),
                                X86_FLAGS & DF, is_rep ? LWECX : 1);
        if (is_rep)
            LWECX_ZERO;
        X86_IP++;
        break;

    case 0x6d:                 /* (rep) insw / insd */
        /* NOTE: ES can't be overwritten */
        /* WARNING: no test for _DI wrapping! */
        if (prefix66) {
            X86_DI += port_rep_inl(pInt, X86_DX, SEG_ADR((CARD32), X86_ES, DI),
                                   X86_EFLAGS & DF, is_rep ? LWECX : 1);
        }
        else {
            X86_DI += port_rep_inw(pInt, X86_DX, SEG_ADR((CARD32), X86_ES, DI),
                                   X86_FLAGS & DF, is_rep ? LWECX : 1);
        }
        if (is_rep)
            LWECX_ZERO;
        X86_IP++;
        break;

    case 0x6e:                 /* (rep) outsb */
        if (pref_seg < 0)
            pref_seg = X86_DS;
        /* WARNING: no test for _SI wrapping! */
        X86_SI += port_rep_outb(pInt, X86_DX, cast(CARD32) LIN_PREF_SI,
                                X86_FLAGS & DF, is_rep ? LWECX : 1);
        if (is_rep)
            LWECX_ZERO;
        X86_IP++;
        break;

    case 0x6f:                 /* (rep) outsw / outsd */
        if (pref_seg < 0)
            pref_seg = X86_DS;
        /* WARNING: no test for _SI wrapping! */
        if (prefix66) {
            X86_SI += port_rep_outl(pInt, X86_DX, cast(CARD32) LIN_PREF_SI,
                                    X86_EFLAGS & DF, is_rep ? LWECX : 1);
        }
        else {
            X86_SI += port_rep_outw(pInt, X86_DX, cast(CARD32) LIN_PREF_SI,
                                    X86_FLAGS & DF, is_rep ? LWECX : 1);
        }
        if (is_rep)
            LWECX_ZERO;
        X86_IP++;
        break;

    case 0xe5:                 /* inw xx, inl xx */
        if (prefix66)
            X86_EAX = x_inl(csp[1]);
        else
            X86_AX = x_inw(csp[1]);
        X86_IP += 2;
        break;

    case 0xe4:                 /* inb xx */
        X86_AL = x_inb(csp[1]);
        X86_IP += 2;
        break;

    case 0xed:                 /* inw dx, inl dx */
        if (prefix66)
            X86_EAX = x_inl(X86_DX);
        else
            X86_AX = x_inw(X86_DX);
        X86_IP += 1;
        break;

    case 0xec:                 /* inb dx */
        X86_AL = x_inb(X86_DX);
        X86_IP += 1;
        break;

    case 0xe7:                 /* outw xx */
        if (prefix66)
            x_outl(csp[1], X86_EAX);
        else
            x_outw(csp[1], X86_AX);
        X86_IP += 2;
        break;

    case 0xe6:                 /* outb xx */
        x_outb(csp[1], X86_AL);
        X86_IP += 2;
        break;

    case 0xef:                 /* outw dx */
        if (prefix66)
            x_outl(X86_DX, X86_EAX);
        else
            x_outw(X86_DX, X86_AX);
        X86_IP += 1;
        break;

    case 0xee:                 /* outb dx */
        x_outb(X86_DX, X86_AL);
        X86_IP += 1;
        break;

    case 0xf4:
        DebugF("hlt at %p\n", lina);
        return FALSE;

    case 0x0f:
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR,
                   "CPU 0x0f Trap at CS:EIP=0x%4.4x:0x%8.8lx\n", X86_CS,
                   X86_EIP);
        goto op0ferr;

    default:
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR, "unknown reason for exception\n");

 op0ferr:
        dump_registers(pInt);
        stack_trace(pInt);
        dump_code(pInt);
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR, "cannot continue\n");
        return FALSE;
    }                           /* end of switch() */
    return TRUE;
}

private int do_vm86(xf86Int10InfoPtr pInt)
{
    int retval = void;

    retval = vm86_rep(VM86S);

    switch (VM86_TYPE(retval)) {
    case VM86_UNKNOWN:
        if (!vm86_GP_fault(pInt))
            return 0;
        break;
    case VM86_STI:
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR, "vm86_sti :-((\n");
        dump_registers(pInt);
        dump_code(pInt);
        stack_trace(pInt);
        return 0;
    case VM86_INTx:
        pInt.num = VM86_ARG(retval);
        if (!int_handler(pInt)) {
            xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR,
                       "Unknown vm86_int: 0x%X\n\n", VM86_ARG(retval));
            dump_registers(pInt);
            dump_code(pInt);
            stack_trace(pInt);
            return 0;
        }
        /* I'm not sure yet what to do if we can handle ints */
        break;
    case VM86_SIGNAL:
        return 1;
        /*
         * we used to warn here and bail out - but now the sigio stuff
         * always fires signals at us. So we just ignore them for now.
         */
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_WARNING, "received signal\n");
        return 0;
    default:
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR, "unknown type(0x%x)=0x%x\n",
                   VM86_ARG(retval), VM86_TYPE(retval));
        dump_registers(pInt);
        dump_code(pInt);
        stack_trace(pInt);
        return 0;
    }

    return 1;
}

void xf86ExecX86int10(xf86Int10InfoPtr pInt)
{
    int sig = setup_int(pInt);

    if (int_handler(pInt))
        while (do_vm86(pInt)) {
        }{}

    finish_int(pInt, sig);
}

private int vm86_rep(vm86_struct* ptr)
{
    int __res = void;

version (__PIC__)
{
    asm
    {
        push EBX;
        push GS;

        mov EBX, ptr;
        mov EAX, 113;

        int 0x80;

        pop GS;
        pop EBX;

        mov __res, EAX;
    }
}
else
{
    asm
    {
        push GS;

        mov EAX, 113;
        mov EBX, ptr;

        int 0x80;

        pop GS;

        mov __res, EAX;
    }
}

    if (__res < 0) {
        errno = -__res;
        __res = -1;
    }
    else
        errno = 0;
    return __res;
}

}
