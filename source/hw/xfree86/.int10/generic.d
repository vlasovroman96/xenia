module generic;
@nogc nothrow:
extern(C): __gshared:
/*
 *                   XFree86 int10 module
 *   execute BIOS int 10h calls in x86 real mode environment
 *                 Copyright 1999 Egbert Eich
 */
import build.xorg_config;

import core.stdc.errno;
import core.stdc.string;
import core.sys.posix.unistd;

import include.xf86;
import include.xf86_OSproc;;
import xf86Bus;
import hw.xfree86.utils.compiler;
version = _INT10_PRIVATE;
import xf86int10_priv;
import hw.xfree86.os_support.int10Defines;
import hw.xfree86.os_support.bus.Pci;
import include.xf86int10; 
import helper_mem;
// import stub;
import core.sys.posix.unistd;
import xf86pciBus;
import hw.xfree86.common.xf86Helper;
import helper_exec;
import externs.gnu;

enum string ALLOC_ENTRIES(string x) = `((V_RAM / ` ~ x ~ `) - 1)`;

import core.stdc.string;             /* needed for memmove */

auto ldl_u(uint* p)
{
    uint ret = void;

    memmove(&ret, p, typeof(*p).sizeof);
    return ret;
}

auto ldw_u(ushort* p)
{
    ushort ret = void;

    memmove(&ret, p, typeof(*p).sizeof);
    return ret;
}

auto stl_u(uint val, uint* p)
{
    uint tmp = val;

    memmove(p, &tmp, typeof(*p).sizeof);
}

auto stw_u(ushort val, ushort* p)
{
    ushort tmp = val;

    memmove(p, &tmp, typeof(*p).sizeof);
}








/*
 * the emulator cannot pass a pointer to the current xf86Int10InfoRec
 * to the memory access functions therefore store it here.
 */

struct genericInt10Priv {
    int shift;
    int entries;
    void* base;
    void* vRam;
    int highMemory;
    void* sysMem;
    char* alloc;
}

enum string INTPriv(string x) = `(cast(genericInt10Priv*)` ~ x ~ `.private_)`;

int10MemRec genericMem = {
    &read_b,
    &read_w,
    &read_l,
    &write_b,
    &write_w,
    &write_l
};




private void* sysMem = null;

version (_PC) {
enum string GET_HIGH_BASE(string x) = `(((V_BIOS + (` ~ x ~ `) + getpagesize() - 1)/getpagesize()) 
                              * getpagesize())`;

private Bool readIntVec(pci_device* dev, ubyte* buf, int len)
{
    void* map = void;

    if (pci_device_map_legacy(dev, 0, len, 0, &map))
        return FALSE;

    memcpy(buf, map, len);
    pci_device_unmap_legacy(dev, map, len);

    return TRUE;
}
} /* _PC */

xf86Int10InfoPtr xf86ExtendedInitInt10(int entityIndex, int Flags)
{
    xf86Int10InfoPtr pInt = void;
    void* base = null;
    void* vbiosMem = null;
    void* options = null;
    legacyVGARec vga = void;
    ScrnInfoPtr pScrn = void;

    pScrn = xf86FindScreenForEntity(entityIndex);

    options = xf86HandleInt10Options(pScrn, entityIndex);

    if (int10skip(options)) {
        free(options);
        return null;
    }

    pInt = cast(xf86Int10InfoPtr) XNFcallocarray(1, xf86Int10InfoRec.sizeof);
    pInt.entityIndex = entityIndex;
    if (!xf86Int10ExecSetup(pInt))
        goto error0;
    pInt.mem = &genericMem;
    pInt.private_ = cast(void*) XNFcallocarray(1, genericInt10Priv.sizeof);
    mixin(INTPriv!(`pInt`)).alloc = cast(char*) XNFcallocarray(1, mixin(ALLOC_ENTRIES!(`getpagesize()`)));
    pInt.pScrn = pScrn;
    base = mixin(INTPriv!(`pInt`)).base = XNFalloc(SYS_BIOS);

    /* FIXME: Shouldn't this be a failure case?  Leaving dev as NULL seems like
     * FIXME: an error
     */
    pInt.dev = xf86GetPciInfoForEntity(entityIndex);

    /*
     * we need to map video RAM MMIO as some chipsets map mmio
     * registers into this range.
     */
    MapVRam(pInt);
version (_PC) {
    if (!sysMem)
        pci_device_map_legacy(pInt.dev, V_BIOS, BIOS_SIZE + SYS_BIOS - V_BIOS,
                              PCI_DEV_MAP_FLAG_WRITABLE, &sysMem);
    mixin(INTPriv!(`pInt`)).sysMem = sysMem;

    if (!readIntVec(pInt.dev, base, LOW_PAGE_SIZE)) {
        xf86DrvMsg(pScrn.scrnIndex, X_ERROR, "Cannot read int vect\n");
        goto error1;
    }

    /*
     * Retrieve everything between V_BIOS and SYS_BIOS as some system BIOSes
     * have executable code there.
     */
    memset(cast(char*) base + V_BIOS, 0, SYS_BIOS - V_BIOS);
    mixin(INTPriv!(`pInt`)).highMemory = V_BIOS;

    if (xf86IsEntityPrimary(entityIndex) && !(initPrimary(options))) {
        if (!xf86int10GetBiosSegment(pInt, cast(ubyte*) sysMem - V_BIOS))
            goto error1;

        set_return_trap(pInt);

        pInt.Flags = Flags & (SET_BIOS_SCRATCH | RESTORE_BIOS_SCRATCH);
        if (!(pInt.Flags & SET_BIOS_SCRATCH))
            pInt.Flags &= ~RESTORE_BIOS_SCRATCH;
        xf86Int10SaveRestoreBIOSVars(pInt, TRUE);

    }
    else {
        const(BusType) location_type = xf86int10GetBiosLocationType(pInt);
        int bios_location = V_BIOS;

        reset_int_vect(pInt);
        set_return_trap(pInt);

        switch (location_type) {
        case BUS_PCI:{
            int err = void;
            pci_device* rom_device = xf86GetPciInfoForEntity(pInt.entityIndex);

            vbiosMem = cast(ubyte*) base + bios_location;
            err = pci_device_read_rom(rom_device, vbiosMem);
            if (err) {
                xf86DrvMsg(pScrn.scrnIndex, X_ERROR, "Cannot read V_BIOS (3) %s\n",
                           strerror(err));
                goto error1;
            }
            mixin(INTPriv!(`pInt`)).highMemory = mixin(GET_HIGH_BASE!(`rom_device.rom_size`));
            break;
        }
        default:
            goto error1;
        }
        pInt.BIOSseg = V_BIOS >> 4;
        pInt.num = 0xe6;
        LockLegacyVGA(pInt, &vga);
        xf86ExecX86int10(pInt);
        UnlockLegacyVGA(pInt, &vga);
    }
} else {
    if (!sysMem) {
        sysMem = XNFalloc(BIOS_SIZE);
        setup_system_bios(sysMem);
    }
    mixin(INTPriv!(`pInt`)).sysMem = sysMem;
    setup_int_vect(pInt);
    set_return_trap(pInt);

    /* Retrieve the entire legacy video BIOS segment.  This can be up to
     * 128KiB.
     */
    vbiosMem = cast(char*) base + V_BIOS;
    memset(vbiosMem, 0, 2 * V_BIOS_SIZE);
    if (pci_device_read_rom(pInt.dev, vbiosMem) != 0
        || pInt.dev.rom_size < V_BIOS_SIZE) {
        xf86DrvMsg(pScrn.scrnIndex, X_WARNING,
                   "Unable to retrieve all of segment 0x0C0000.\n");
    }

    /*
     * If this adapter is the primary, use its post-init BIOS (if we can find
     * it).
     */
    {
        int bios_location = V_BIOS;
        Bool done = FALSE;

        vbiosMem = cast(ubyte*) base + bios_location;

        if (xf86IsEntityPrimary(entityIndex)) {
            if (int10_check_bios(pScrn.scrnIndex, bios_location >> 4, cast(ubyte*)vbiosMem))
                done = TRUE;
            else
                xf86DrvMsg(pScrn.scrnIndex, X_INFO,
                           "No legacy BIOS found -- trying PCI\n");
        }
        if (!done) {
            int err = void;
            pci_device* rom_device = xf86GetPciInfoForEntity(pInt.entityIndex);

            err = pci_device_read_rom(rom_device, vbiosMem);
            if (err) {
                xf86DrvMsg(pScrn.scrnIndex, X_ERROR, "Cannot read V_BIOS (5) %s\n",
                           strerror(err));
                goto error1;
            }
        }
    }

    pInt.BIOSseg = V_BIOS >> 4;
    pInt.num = 0xe6;
    LockLegacyVGA(pInt, &vga);
    xf86ExecX86int10(pInt);
    UnlockLegacyVGA(pInt, &vga);
}
    free(options);
    return pInt;

 error1:
    free(base);
    UnmapVRam(pInt);
    free(mixin(INTPriv!(`pInt`)).alloc);
    free(pInt.private_);
 error0:
    free(pInt);
    free(options);

    return null;
}

private void MapVRam(xf86Int10InfoPtr pInt)
{
    int pagesize = getpagesize();
    int size = ((VRAM_SIZE + pagesize - 1) / pagesize) * pagesize;

    pci_device_map_legacy(pInt.dev, V_RAM, size, PCI_DEV_MAP_FLAG_WRITABLE,
                          &(mixin(INTPriv!(`pInt`)).vRam));
    pInt.io = pci_legacy_open_io(pInt.dev, 0, 64 * 1024);
}

private void UnmapVRam(xf86Int10InfoPtr pInt)
{
    int pagesize = getpagesize();
    int size = ((VRAM_SIZE + pagesize - 1) / pagesize) * pagesize;

    pci_device_unmap_legacy(pInt.dev, mixin(INTPriv!(`pInt`)).vRam, size);
    pci_device_close_io(pInt.dev, pInt.io);
    pInt.io = null;
}

Bool MapCurrentInt10(xf86Int10InfoPtr pInt)
{
    /* nothing to do here */
    return TRUE;
}

void xf86FreeInt10(xf86Int10InfoPtr pInt)
{
    if (!pInt)
        return;
version (_PC) {
    xf86Int10SaveRestoreBIOSVars(pInt, FALSE);
}
    if (Int10Current == pInt)
        Int10Current = null;
    free(mixin(INTPriv!(`pInt`)).base);
    UnmapVRam(pInt);
    free(mixin(INTPriv!(`pInt`)).alloc);
    free(pInt.private_);
    free(pInt);
}

void* xf86Int10AllocPages(xf86Int10InfoPtr pInt, int num, int* off)
{
    int pagesize = getpagesize();
    int num_pages = mixin(ALLOC_ENTRIES!(`pagesize`));
    int i = void, j = void;

    for (i = 0; i < (num_pages - num); i++) {
        if (mixin(INTPriv!(`pInt`)).alloc[i] == 0) {
            for (j = i; j < (num + i); j++)
                if (mixin(INTPriv!(`pInt`)).alloc[j] != 0)
                    break;
            if (j == (num + i))
                break;
            i += num;
        }
    }
    if (i == (num_pages - num))
        return null;

    for (j = i; j < (i + num); j++)
        mixin(INTPriv!(`pInt`)).alloc[j] = 1;

    *off = (i + 1) * pagesize;

    return cast(char*) mixin(INTPriv!(`pInt`)).base + *off;
}

void xf86Int10FreePages(xf86Int10InfoPtr pInt, void* pbase, int num)
{
    int pagesize = getpagesize();
    int first = cast(int)(((cast(char*) pbase - cast(char*) mixin(INTPriv!(`pInt`)).base) / pagesize) - 1);
    int i = void;

    for (i = first; i < (first + num); i++)
        mixin(INTPriv!(`pInt`)).alloc[i] = 0;
}

enum string OFF(string addr) = `((` ~ addr ~ `) & 0xffff)`;
version (_PC) {
enum HIGH_OFFSET = (INTPriv(pInt).highMemory);
enum HIGH_BASE =   V_BIOS;
} else {
enum HIGH_OFFSET = SYS_BIOS;
enum HIGH_BASE =   SYS_BIOS;
}
enum string SYS(string addr) = `((` ~ addr ~ `) >= HIGH_OFFSET)`;
enum string V_ADDR(string addr) = `
	  (` ~ SYS!(addr) ~ ` ? (cast(char*)` ~ INTPriv!(`pInt`) ~ `.sysMem) + (` ~ addr ~ ` - HIGH_BASE) 
	   : ((cast(char*)(` ~ INTPriv!(`pInt`) ~ `.base) + ` ~ addr ~ `)))`;
enum string VRAM_ADDR(string addr) = `(` ~ addr ~ ` - V_RAM)`;
enum string VRAM_BASE = `(INTPriv!(pInt).vRam);`;

enum string VRAM(string addr) = `((` ~ addr ~ ` >= V_RAM) && (` ~ addr ~ ` < (V_RAM + VRAM_SIZE)))`;
enum string V_ADDR_RB(string addr) = `
	((` ~ VRAM!(addr) ~ `) ? MMIO_IN8(cast(ubyte*)VRAM_BASE,` ~ VRAM_ADDR!(addr) ~ `) 
	   : *cast(ubyte*) ` ~ V_ADDR!(addr) ~ `)`;
enum string V_ADDR_RW(string addr) = `
	((` ~ VRAM!(addr) ~ `) ? MMIO_IN16(cast(ushort*)VRAM_BASE,` ~ VRAM_ADDR!(addr) ~ `) 
	   : ldw_u(cast(ushort*)` ~ V_ADDR!(addr) ~ `))`;
enum string V_ADDR_RL(string addr) = `
	((` ~ VRAM!(addr) ~ `) ? MMIO_IN32(cast(uint*)VRAM_BASE,` ~ VRAM_ADDR!(addr) ~ `) 
	   : ldl_u(cast(uint*)` ~ V_ADDR!(addr) ~ `))`;

enum string V_ADDR_WB(string addr,string val) = `
	if(` ~ VRAM!(addr) ~ `) 
	    MMIO_OUT8(cast(ubyte*)VRAM_BASE,` ~ VRAM_ADDR!(addr) ~ `,cast(ubyte)` ~ val ~ `); 
	else 
	    *cast(ubyte*) ` ~ V_ADDR!(addr) ~ ` = cast(ubyte)(` ~ val ~ `);`;
enum string V_ADDR_WW(string addr,string val) = `
	if(` ~ VRAM!(addr) ~ `) 
	    MMIO_OUT16(cast(ushort*)VRAM_BASE,` ~ VRAM_ADDR!(addr) ~ `,` ~ val ~ `); 
	else 
	    stw_u((` ~ val ~ `),cast(ushort*)(` ~ V_ADDR!(addr) ~ `));`;

enum string V_ADDR_WL(string addr,string val) = `
	if (` ~ VRAM!(addr) ~ `) 
	    MMIO_OUT32(cast(uint*)VRAM_BASE,` ~ VRAM_ADDR!(addr) ~ `,` ~ val ~ `); 
	else 
	    stl_u(` ~ val ~ `,cast(uint*)(` ~ V_ADDR!(addr) ~ `));`;

private ubyte read_b(xf86Int10InfoPtr pInt, int addr)
{
    return mixin(V_ADDR_RB!(`addr`));
}

private ushort read_w(xf86Int10InfoPtr pInt, int addr)
{
static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
    if (mixin(OFF!(`addr + 1`)) > 0)
        return mixin(V_ADDR_RW!(`addr`));
}
    return mixin(V_ADDR_RB!(`addr`)) | (mixin(V_ADDR_RB!(`addr + 1`)) << 8);
}

private uint read_l(xf86Int10InfoPtr pInt, int addr)
{
static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
    if (mixin(OFF!(`addr + 3`)) > 2)
        return mixin(V_ADDR_RL!(`addr`));
}
    return mixin(V_ADDR_RB!(`addr`)) |
        (mixin(V_ADDR_RB!(`addr + 1`)) << 8) |
        (mixin(V_ADDR_RB!(`addr + 2`)) << 16) | (mixin(V_ADDR_RB!(`addr + 3`)) << 24);
}

private void write_b(xf86Int10InfoPtr pInt, int addr, ubyte val)
{
    mixin(V_ADDR_WB!(`addr`, `val`));
}

private void write_w(xf86Int10InfoPtr pInt, int addr, CARD16 val)
{
static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
    if (mixin(OFF!(`addr + 1`)) > 0) {
        mixin(V_ADDR_WW!(`addr`, `val`));
    }
}
    mixin(V_ADDR_WB!(`addr`, `val`));
    mixin(V_ADDR_WB!(`addr + 1`, `val >> 8`));
}

private void write_l(xf86Int10InfoPtr pInt, int addr, uint val)
{
static if (X_BYTE_ORDER == X_LITTLE_ENDIAN) {
    if (mixin(OFF!(`addr + 3`)) > 2) {
        mixin(V_ADDR_WL!(`addr`, `val`));
    }
}
    mixin(V_ADDR_WB!(`addr`, `val`));
    mixin(V_ADDR_WB!(`addr + 1`, `val >> 8`));
    mixin(V_ADDR_WB!(`addr + 2`, `val >> 16`));
    mixin(V_ADDR_WB!(`addr + 3`, `val >> 24`));
}

void* xf86int10Addr(xf86Int10InfoPtr pInt, uint addr)
{
    return mixin(V_ADDR!(`addr`));
}
