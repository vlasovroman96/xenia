module hw.xfree86.os_support.linux.int10.linux;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * linux specific part of the int10 module
 * Copyright 1999, 2000, 2001, 2002, 2003, 2004, 2008 Egbert Eich
 */
import build.xorg_config;

import include.xf86;
import include.xf86_OSproc;;
import include.xf86Pci;
import hw.xfree86.utils.compiler;
version = _INT10_PRIVATE;
// import xf86int10;
version (__sparc__) {
enum DEV_MEM = "/dev/fb";
} else {
enum DEV_MEM = "/dev/mem";
}
enum string ALLOC_ENTRIES(string x) = `((V_RAM / ` ~ x ~ `) - 1)`;
enum SHMERRORPTR = cast(void *)(-1);

import core.sys.posix.fcntl;
import core.stdc.errno;
import core.sys.posix.sys.mman;
import core.sys.posix.sys.ipc;
import core.sys.posix.sys.shm;
import core.sys.posix.unistd;
import core.stdc.string;
import xf86Bus;

import include.xf86int10;

private int counter = 0;
private x_server_generation_t int10Generation = 0;








int10MemRec linuxMem = {
    &read_b,
    &read_w,
    &read_l,
    &write_b,
    &write_w,
    &write_l
};

struct linuxInt10Priv {
    int lowMem;
    int highMem;
    char* base;
    char* base_high;
    char* alloc;
}

private Bool readLegacy(pci_device* dev, ubyte* buf, int base, int len)
{
    void* map = void;

    if (pci_device_map_legacy(dev, base, len, 0, &map))
        return FALSE;

    memcpy(buf, map, len);
    pci_device_unmap_legacy(dev, map, len);

    return TRUE;
}

xf86Int10InfoPtr xf86ExtendedInitInt10(int entityIndex, int Flags)
{
    xf86Int10InfoPtr pInt = null;
    int screen = void;
    int fd = void;
    static void* vidMem = null;
    static void* sysMem = null;
    void* vMem = null;
    void* options = null;
    int low_mem = void;
    int high_mem = -1;
    char* base = cast(char*)SHMERRORPTR;
    char* base_high = cast(char*)SHMERRORPTR;
    int pagesize = void;
    memType cs = void;
    legacyVGARec vga = void;
    Bool videoBiosMapped = FALSE;
    ScrnInfoPtr pScrn = void;
    if (int10Generation != serverGeneration) {
        counter = 0;
        int10Generation = serverGeneration;
    }

    pScrn = xf86FindScreenForEntity(entityIndex);
    screen = pScrn.scrnIndex;

    options = xf86HandleInt10Options(pScrn, entityIndex);

    if (int10skip(options)) {
        free(options);
        return null;
    }

    if ((!vidMem) || (!sysMem)) {
        if ((fd = open(DEV_MEM, O_RDWR, 0)) >= 0) {
            if (!sysMem) {
                DebugF("Mapping sys bios area\n");
                if ((sysMem = mmap(cast(void*) (SYS_BIOS), BIOS_SIZE,
                                   PROT_READ | PROT_EXEC,
                                   MAP_SHARED | MAP_FIXED, fd, SYS_BIOS))
                    == MAP_FAILED) {
                    xf86DrvMsg(screen, X_ERROR, "Cannot map SYS BIOS\n");
                    close(fd);
                    goto error0;
                }
            }
            if (!vidMem) {
                DebugF("Mapping VRAM area\n");
                if ((vidMem = mmap(cast(void*) (V_RAM), VRAM_SIZE,
                                   PROT_READ | PROT_WRITE | PROT_EXEC,
                                   MAP_SHARED | MAP_FIXED, fd, V_RAM))
                    == MAP_FAILED) {
                    xf86DrvMsg(screen, X_ERROR, "Cannot map V_RAM\n");
                    close(fd);
                    goto error0;
                }
            }
            close(fd);
        }
        else {
            xf86DrvMsg(screen, X_ERROR, "Cannot open %s\n", DEV_MEM);
            goto error0;
        }
    }

    pInt = cast(xf86Int10InfoPtr) XNFcallocarray(1, xf86Int10InfoRec.sizeof);
    pInt.pScrn = pScrn;
    pInt.entityIndex = entityIndex;
    pInt.dev = xf86GetPciInfoForEntity(entityIndex);

    if (!xf86Int10ExecSetup(pInt))
        goto error0;
    pInt.mem = &linuxMem;
    pagesize = getpagesize();
    pInt.private_ = cast(void*) XNFcallocarray(1, linuxInt10Priv.sizeof);
    (cast(linuxInt10Priv*) pInt.private_).alloc =
        cast(void*) XNFcallocarray(1, mixin(ALLOC_ENTRIES!(`pagesize`)));

    if (!xf86IsEntityPrimary(entityIndex)) {
        DebugF("Mapping high memory area\n");
        if ((high_mem = shmget(counter++, HIGH_MEM_SIZE,
                               IPC_CREAT | SHM_R | SHM_W)) == -1) {
            if (errno == ENOSYS)
                xf86DrvMsg(screen, X_ERROR, "shmget error\n Please reconfigure"
                           ~ " your kernel to include System V IPC support\n");
            else
                xf86DrvMsg(screen, X_ERROR,
                           "shmget(highmem) error: %s\n", strerror(errno));
            goto error1;
        }
    }
    else {
        DebugF("Mapping Video BIOS\n");
        videoBiosMapped = TRUE;
        if ((fd = open(DEV_MEM, O_RDWR, 0)) >= 0) {
            if ((vMem = mmap(cast(void*) (V_BIOS), SYS_BIOS - V_BIOS,
                             PROT_READ | PROT_WRITE | PROT_EXEC,
                             MAP_SHARED | MAP_FIXED, fd, V_BIOS))
                == MAP_FAILED) {
                xf86DrvMsg(screen, X_ERROR, "Cannot map V_BIOS\n");
                close(fd);
                goto error1;
            }
            close(fd);
        }
        else
            goto error1;
    }
    (cast(linuxInt10Priv*) pInt.private_).highMem = high_mem;

    DebugF("Mapping 640kB area\n");
    if ((low_mem = shmget(counter++, V_RAM, IPC_CREAT | SHM_R | SHM_W)) == -1) {
        xf86DrvMsg(screen, X_ERROR,
                   "shmget(lowmem) error: %s\n", strerror(errno));
        goto error2;
    }

    (cast(linuxInt10Priv*) pInt.private_).lowMem = low_mem;
    base = shmat(low_mem, 0, 0);
    if (base == SHMERRORPTR) {
        xf86DrvMsg(screen, X_ERROR,
                   "shmat(low_mem) error: %s\n", strerror(errno));
        goto error3;
    }
    (cast(linuxInt10Priv*) pInt.private_).base = base;
    if (high_mem > -1) {
        base_high = shmat(high_mem, 0, 0);
        if (base_high == SHMERRORPTR) {
            xf86DrvMsg(screen, X_ERROR,
                       "shmat(high_mem) error: %s\n", strerror(errno));
            goto error3;
        }
        (cast(linuxInt10Priv*) pInt.private_).base_high = base_high;
    }
    else
        (cast(linuxInt10Priv*) pInt.private_).base_high = null;

    if (!MapCurrentInt10(pInt))
        goto error3;

    Int10Current = pInt;

    DebugF("Mapping int area\n");
    /* note: yes, we really are writing the 0 page here */
    if (!readLegacy(pInt.dev, cast(ubyte*) 0, 0, LOW_PAGE_SIZE)) {
        xf86DrvMsg(screen, X_ERROR, "Cannot read int vect\n");
        goto error3;
    }
    DebugF("done\n");
    /*
     * Read in everything between V_BIOS and SYS_BIOS as some system BIOSes
     * have executable code there.  Note that xf86ReadBIOS() can only bring in
     * 64K bytes at a time.
     */
    if (!videoBiosMapped) {
        memset(cast(void*) V_BIOS, 0, SYS_BIOS - V_BIOS);
        DebugF("Reading BIOS\n");
        for (cs = V_BIOS; cs < SYS_BIOS; cs += V_BIOS_SIZE)
            if (!readLegacy(pInt.dev, cast(void*)cs, cs, V_BIOS_SIZE))
                xf86DrvMsg(screen, X_WARNING,
                           "Unable to retrieve all of segment 0x%06lX.\n",
                           cast(c_long) cs);
        DebugF("done\n");
    }

    if (xf86IsEntityPrimary(entityIndex) && !(initPrimary(options))) {
        if (!xf86int10GetBiosSegment(pInt, null))
            goto error3;

        set_return_trap(pInt);
version (_PC) {
        pInt.Flags = Flags & (SET_BIOS_SCRATCH | RESTORE_BIOS_SCRATCH);
        if (!(pInt.Flags & SET_BIOS_SCRATCH))
            pInt.Flags &= ~RESTORE_BIOS_SCRATCH;
        xf86Int10SaveRestoreBIOSVars(pInt, TRUE);
}
    }
    else {
        const(BusType) location_type = xf86int10GetBiosLocationType(pInt);

        switch (location_type) {
        case BUS_PCI:{
            int err = void;
            pci_device* rom_device = xf86GetPciInfoForEntity(pInt.entityIndex);

            pci_device_enable(rom_device);
            err = pci_device_read_rom(rom_device, cast(ubyte*) (V_BIOS));
            if (err) {
                xf86DrvMsg(screen, X_ERROR, "Cannot read V_BIOS (%s)\n",
                           strerror(err));
                goto error3;
            }

            pInt.BIOSseg = V_BIOS >> 4;
            break;
        }
        default:
            goto error3;
        }

        pInt.num = 0xe6;
        reset_int_vect(pInt);
        set_return_trap(pInt);
        LockLegacyVGA(pInt, &vga);
        xf86ExecX86int10(pInt);
        UnlockLegacyVGA(pInt, &vga);
    }
version (DEBUG) {
    dprint(0xc0000, 0x20);
}

    free(options);
    return pInt;

 error3:
    if (base_high)
        shmdt(base_high);
    shmdt(base);
    shmdt(0);
    if (base_high)
        shmdt(cast(char*) HIGH_MEM);
    shmctl(low_mem, IPC_RMID, null);
    Int10Current = null;
 error2:
    if (high_mem > -1)
        shmctl(high_mem, IPC_RMID, null);
 error1:
    if (vMem)
        munmap(vMem, SYS_BIOS - V_BIOS);
    free((cast(linuxInt10Priv*) pInt.private_).alloc);
    free(pInt.private_);
 error0:
    free(options);
    free(pInt);
    return null;
}

Bool MapCurrentInt10(xf86Int10InfoPtr pInt)
{
    void* addr = void;
    int fd = -1;

    if (Int10Current) {
        shmdt(0);
        if ((cast(linuxInt10Priv*) Int10Current.private_).highMem >= 0)
            shmdt(cast(char*) HIGH_MEM);
        else
            munmap(cast(void*) V_BIOS, (SYS_BIOS - V_BIOS));
    }
    addr =
        shmat((cast(linuxInt10Priv*) pInt.private_).lowMem, cast(char*) 1, SHM_RND);
    if (addr == SHMERRORPTR) {
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR, "Cannot shmat() low memory\n");
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR,
                   "shmat(low_mem) error: %s\n", strerror(errno));
        return FALSE;
    }
    if (mprotect(cast(void*) 0, V_RAM, PROT_READ | PROT_WRITE | PROT_EXEC) != 0)
        xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR,
                   "Cannot set EXEC bit on low memory: %s\n", strerror(errno));

    if ((cast(linuxInt10Priv*) pInt.private_).highMem >= 0) {
        addr = shmat((cast(linuxInt10Priv*) pInt.private_).highMem,
                     cast(char*) HIGH_MEM, 0);
        if (addr == SHMERRORPTR) {
            xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR,
                       "Cannot shmat() high memory\n");
            xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR,
                       "shmget error: %s\n", strerror(errno));
            return FALSE;
        }
        if (mprotect(cast(void*) HIGH_MEM, HIGH_MEM_SIZE,
                     PROT_READ | PROT_WRITE | PROT_EXEC) != 0)
            xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR,
                       "Cannot set EXEC bit on high memory: %s\n",
                       strerror(errno));
    }
    else {
        if ((fd = open(DEV_MEM, O_RDWR, 0)) >= 0) {
            if (mmap(cast(void*) (V_BIOS), SYS_BIOS - V_BIOS,
                     PROT_READ | PROT_WRITE | PROT_EXEC,
                     MAP_SHARED | MAP_FIXED, fd, V_BIOS)
                == MAP_FAILED) {
                xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR, "Cannot map V_BIOS\n");
                close(fd);
                return FALSE;
            }
        }
        else {
            xf86DrvMsg(pInt.pScrn.scrnIndex, X_ERROR, "Cannot open %s\n", DEV_MEM);
            return FALSE;
        }
        close(fd);
    }

    return TRUE;
}

void xf86FreeInt10(xf86Int10InfoPtr pInt)
{
    if (!pInt)
        return;

version (_PC) {
    xf86Int10SaveRestoreBIOSVars(pInt, FALSE);
}
    if (Int10Current == pInt) {
        shmdt(0);
        if ((cast(linuxInt10Priv*) pInt.private_).highMem >= 0)
            shmdt(cast(char*) HIGH_MEM);
        else
            munmap(cast(void*) V_BIOS, (SYS_BIOS - V_BIOS));
        Int10Current = null;
    }

    if ((cast(linuxInt10Priv*) pInt.private_).base_high)
        shmdt((cast(linuxInt10Priv*) pInt.private_).base_high);
    shmdt((cast(linuxInt10Priv*) pInt.private_).base);
    shmctl((cast(linuxInt10Priv*) pInt.private_).lowMem, IPC_RMID, null);
    if ((cast(linuxInt10Priv*) pInt.private_).highMem >= 0)
        shmctl((cast(linuxInt10Priv*) pInt.private_).highMem, IPC_RMID, null);
    free((cast(linuxInt10Priv*) pInt.private_).alloc);
    free(pInt.private_);
    free(pInt);
}

void* xf86Int10AllocPages(xf86Int10InfoPtr pInt, int num, int* off)
{
    int pagesize = getpagesize();
    int num_pages = mixin(ALLOC_ENTRIES!(`pagesize`));
    int i = void, j = void;

    for (i = 0; i < (num_pages - num); i++) {
        if ((cast(linuxInt10Priv*) pInt.private_).alloc[i] == 0) {
            for (j = i; j < (num + i); j++)
                if (((cast(linuxInt10Priv*) pInt.private_).alloc[j] != 0))
                    break;
            if (j == (num + i))
                break;
            else
                i = i + num;
        }
    }
    if (i == (num_pages - num))
        return null;

    for (j = i; j < (i + num); j++)
        (cast(linuxInt10Priv*) pInt.private_).alloc[j] = 1;

    *off = (i + 1) * pagesize;

    return (cast(linuxInt10Priv*) pInt.private_).base + ((i + 1) * pagesize);
}

void xf86Int10FreePages(xf86Int10InfoPtr pInt, void* pbase, int num)
{
    int pagesize = getpagesize();
    int first = ((cast(c_ulong) pbase
                  - cast(c_ulong) (cast(linuxInt10Priv*) pInt.private_).base)
                 / pagesize) - 1;
    int i = void;

    for (i = first; i < (first + num); i++)
        (cast(linuxInt10Priv*) pInt.private_).alloc[i] = 0;
}

private CARD8 read_b(xf86Int10InfoPtr pInt, int addr)
{
    return *(cast(CARD8*) cast(memType) addr);
}

private CARD16 read_w(xf86Int10InfoPtr pInt, int addr)
{
    return *(cast(CARD16*) cast(memType) addr);
}

private CARD32 read_l(xf86Int10InfoPtr pInt, int addr)
{
    return *(cast(CARD32*) cast(memType) addr);
}

private void write_b(xf86Int10InfoPtr pInt, int addr, CARD8 val)
{
    *(cast(CARD8*) cast(memType) addr) = val;
}

private void write_w(xf86Int10InfoPtr pInt, int addr, CARD16 val)
{
    *(cast(CARD16*) cast(memType) addr) = val;
}

private void write_l(xf86Int10InfoPtr pInt, int addr, CARD32 val)
{
    *(cast(CARD32*) cast(memType) addr) = val;
}

void* xf86int10Addr(xf86Int10InfoPtr pInt, CARD32 addr)
{
    if (addr < V_RAM)
        return (cast(linuxInt10Priv*) pInt.private_).base + addr;
    else if (addr < V_BIOS)
        return cast(void*) cast(memType) addr;
    else if (addr < SYS_BIOS) {
        if ((cast(linuxInt10Priv*) pInt.private_).base_high)
            return cast(void*) ((cast(linuxInt10Priv*) pInt.private_).base_high
                              - V_BIOS + addr);
        else
            return cast(void*) cast(memType) addr;
    }
    else
        return cast(void*) cast(memType) addr;
}
