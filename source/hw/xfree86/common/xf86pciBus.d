module xf86pciBus;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright (c) 1997-2003 by The XFree86 Project, Inc.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Except as contained in this notice, the name of the copyright holder(s)
 * and author(s) shall not be used in advertising or otherwise to promote
 * the sale, use or other dealings in this Software without prior written
 * authorization from the copyright holder(s) and author(s).
 */
/*
 * This file contains the interfaces to the bus-specific code
 */
import build.xlibre_server;

import core.stdc.ctype;
import core.sys.posix.dirent;
import core.stdc.stdlib;
import core.sys.posix.unistd;
import externs.pciaccess;
//import x11.X;

import os.log_priv;
import os.osdep;

import xf86_pci_priv;
import os.os;
import hw.xfree86.os_support.bus.Pci;
import xf86_priv;
import hw.xfree86.common.xf86Priv;

import hw.xfree86.common.xf86MatchDrivers;

/* Bus-specific headers */
import xf86Bus;

import hw.xfree86.os_support.xf86_OSproc;;
import xf86DGA;
import xf86pciBus;
import hw.xfree86.common.xf86Helper;
import hw.xfree86.modes.xf86Crtc;
import xf86cmap;
import dix.resource;
import dix.dixutils;
import os.log;
import xf86Globals;
import hw.xfree86.common.xf86Option;
import core.stdc.stdio;
import core.stdc.stdlib;
import externs.gnu;

public import externs.pciaccess;

/*
 * PCI cfg space definitions (e.g. stuff right out of the PCI spec)
 */

/* Device identification register */
enum PCI_ID_REG =			0x00;

/* Command and status register */
enum PCI_CMD_STAT_REG =		0x04;
enum PCI_CMD_BASE_REG =		0x10;
enum PCI_CMD_BIOS_REG =		0x30;
enum PCI_CMD_MASK =			0xffff;
enum PCI_CMD_IO_ENABLE =		0x01;
enum PCI_CMD_MEM_ENABLE =		0x02;
enum PCI_CMD_MASTER_ENABLE =		0x04;
enum PCI_CMD_SPECIAL_ENABLE =		0x08;
enum PCI_CMD_INVALIDATE_ENABLE =	0x10;
enum PCI_CMD_PALETTE_ENABLE =		0x20;
enum PCI_CMD_PARITY_ENABLE =		0x40;
enum PCI_CMD_STEPPING_ENABLE =		0x80;
enum PCI_CMD_SERR_ENABLE =		0x100;
enum PCI_CMD_BACKTOBACK_ENABLE =	0x200;
enum PCI_CMD_BIOS_ENABLE =		0x01;

/* base class */
enum PCI_CLASS_REG =		0x08;
enum PCI_CLASS_MASK =		0xff000000;
enum PCI_CLASS_SHIFT =		24;
enum string PCI_CLASS_EXTRACT(string x) = `
	(((` ~ x ~ `) & PCI_CLASS_MASK) >> PCI_CLASS_SHIFT)`;

/* base class values */
enum PCI_CLASS_PREHISTORIC =		0x00;
enum PCI_CLASS_MASS_STORAGE =		0x01;
enum PCI_CLASS_NETWORK =		0x02;
enum PCI_CLASS_DISPLAY =		0x03;
enum PCI_CLASS_MULTIMEDIA =		0x04;
enum PCI_CLASS_MEMORY =		0x05;
enum PCI_CLASS_BRIDGE =		0x06;
enum PCI_CLASS_COMMUNICATIONS =	0x07;
enum PCI_CLASS_SYSPERIPH =		0x08;
enum PCI_CLASS_INPUT =			0x09;
enum PCI_CLASS_DOCKING =		0x0a;
enum PCI_CLASS_PROCESSOR =		0x0b;
enum PCI_CLASS_SERIALBUS =		0x0c;
enum PCI_CLASS_WIRELESS =		0x0d;
enum PCI_CLASS_I2O =			0x0e;
enum PCI_CLASS_SATELLITE =		0x0f;
enum PCI_CLASS_CRYPT =			0x10;
enum PCI_CLASS_DATA_ACQUISITION =	0X11;
enum PCI_CLASS_UNDEFINED =		0xff;

/* sub class */
enum PCI_SUBCLASS_MASK =	0x00ff0000;
enum PCI_SUBCLASS_SHIFT =	16;
enum string PCI_SUBCLASS_EXTRACT(string x) = `
	(((` ~ x ~ `) & PCI_SUBCLASS_MASK) >> PCI_SUBCLASS_SHIFT)`;

/* Sub class values */
/* 0x00 prehistoric subclasses */
enum PCI_SUBCLASS_PREHISTORIC_MISC =	0x00;
enum PCI_SUBCLASS_PREHISTORIC_VGA =	0x01;

/* 0x03 display subclasses */
enum PCI_SUBCLASS_DISPLAY_VGA =	0x00;
enum PCI_SUBCLASS_DISPLAY_XGA =	0x01;
enum PCI_SUBCLASS_DISPLAY_MISC =	0x80;

/* 0x04 multimedia subclasses */
enum PCI_SUBCLASS_MULTIMEDIA_VIDEO =	0x00;
enum PCI_SUBCLASS_MULTIMEDIA_AUDIO =	0x01;
enum PCI_SUBCLASS_MULTIMEDIA_MISC =	0x80;

/* 0x06 bridge subclasses */
enum PCI_SUBCLASS_BRIDGE_HOST =	0x00;
enum PCI_SUBCLASS_BRIDGE_ISA =		0x01;
enum PCI_SUBCLASS_BRIDGE_EISA =	0x02;
enum PCI_SUBCLASS_BRIDGE_MC =		0x03;
enum PCI_SUBCLASS_BRIDGE_PCI =		0x04;
enum PCI_SUBCLASS_BRIDGE_PCMCIA =	0x05;
enum PCI_SUBCLASS_BRIDGE_NUBUS =	0x06;
enum PCI_SUBCLASS_BRIDGE_CARDBUS =	0x07;
enum PCI_SUBCLASS_BRIDGE_RACEWAY =	0x08;
enum PCI_SUBCLASS_BRIDGE_MISC =	0x80;
enum PCI_IF_BRIDGE_PCI_SUBTRACTIVE =	0x01;

/* 0x0b processor subclasses */
enum PCI_SUBCLASS_PROCESSOR_386 =	0x00;
enum PCI_SUBCLASS_PROCESSOR_486 =	0x01;
enum PCI_SUBCLASS_PROCESSOR_PENTIUM =	0x02;
enum PCI_SUBCLASS_PROCESSOR_ALPHA =	0x10;
enum PCI_SUBCLASS_PROCESSOR_POWERPC =	0x20;
enum PCI_SUBCLASS_PROCESSOR_MIPS =	0x30;
enum PCI_SUBCLASS_PROCESSOR_COPROC =	0x40;

/* PCI-PCI bridge mapping registers */
enum PCI_PCI_BRIDGE_BUS_REG =		0x18;
enum PCI_SUBORDINATE_BUS_MASK =	0x00ff0000;
enum PCI_SECONDARY_BUS_MASK =		0x0000ff00;
enum PCI_PRIMARY_BUS_MASK =		0x000000ff;

enum PCI_PCI_BRIDGE_IO_REG =		0x1c;
enum PCI_PCI_BRIDGE_MEM_REG =		0x20;
enum PCI_PCI_BRIDGE_PMEM_REG =		0x24;

enum PCI_PCI_BRIDGE_CONTROL_REG =	0x3E;
enum PCI_PCI_BRIDGE_PARITY_EN =	0x01;
enum PCI_PCI_BRIDGE_SERR_EN =		0x02;
enum PCI_PCI_BRIDGE_ISA_EN =		0x04;
enum PCI_PCI_BRIDGE_VGA_EN =		0x08;
enum PCI_PCI_BRIDGE_MASTER_ABORT_EN =	0x20;
enum PCI_PCI_BRIDGE_SECONDARY_RESET =	0x40;
enum PCI_PCI_BRIDGE_FAST_B2B_EN =	0x80;

/* Subsystem identification register */
enum PCI_SUBSYSTEM_ID_REG =		0x2c;

/* User defined cfg space regs */
enum PCI_REG_USERCONFIG =		0x40;
enum PCI_OPTION_REG =			0x40;

enum string MATCH_PCI_DEVICES(string x,string  y) = `(((`~x~`).domain == (`~y~`).domain) &&        
                                 ((`~x~`).bus == (`~y~`).bus) &&              
                                 ((`~x~`).func == (`~y~`).func) &&            
                                 ((`~x~`).dev == (`~y~`).dev))`;

enum PCI_VENDOR_GENERIC =		0x00FF;


enum string PCIINFOCLASSES(string c) = `
    ( (((` ~ c ~ `) & 0x00ff0000) == (PCI_CLASS_PREHISTORIC << 16)) 
      || (((` ~ c ~ `) & 0x00ff0000) == (PCI_CLASS_DISPLAY << 16)) 
      || ((((` ~ c ~ `) & 0x00ffff00) 
	   == ((PCI_CLASS_MULTIMEDIA << 16) | (PCI_SUBCLASS_MULTIMEDIA_VIDEO << 8)))) 
      || ((((` ~ c ~ `) & 0x00ffff00) 
	   == ((PCI_CLASS_PROCESSOR << 16) | (PCI_SUBCLASS_PROCESSOR_COPROC << 8)))) )`;

/*
 * PCI classes that have messages printed always.  The others are only
 * have a message printed when the vendor/dev IDs are recognised.
 */
enum string PCIALWAYSPRINTCLASSES(string c) = `
    ( (((` ~ c ~ `) & 0x00ffff00) 
       == ((PCI_CLASS_PREHISTORIC << 16) | (PCI_SUBCLASS_PREHISTORIC_VGA << 8))) 
      || (((` ~ c ~ `) & 0x00ff0000) == (PCI_CLASS_DISPLAY << 16)) 
      || ((((` ~ c ~ `) & 0x00ffff00) 
	   == ((PCI_CLASS_MULTIMEDIA << 16) | (PCI_SUBCLASS_MULTIMEDIA_VIDEO << 8)))) )`;

enum string IS_VGA(string c) = `
    (((` ~ c ~ `) & 0x00ffff00) 
	 == ((PCI_CLASS_DISPLAY << 16) | (PCI_SUBCLASS_DISPLAY_VGA << 8)))`;

private pci_slot_match xf86IsolateDevice = {
    PCI_MATCH_ANY, PCI_MATCH_ANY, PCI_MATCH_ANY, PCI_MATCH_ANY, 0
};

/*
 * xf86Bus.c interface
 */

void xf86PciProbe()
{
    int i = 0, k = void;
    int num = 0;
    pci_device* info = void;
    pci_device_iterator* iter = void;
    pci_device** xf86PciVideoInfo = null;

    if (!xf86scanpci()) {
        xf86PciVideoInfo = null;
        return;
    }

    iter = pci_slot_match_iterator_create(&xf86IsolateDevice);
    while ((info = pci_device_next(iter)) !is null) {
        if (mixin(PCIINFOCLASSES!(`info.device_class`))) {
            num++;
            xf86PciVideoInfo = cast(pci_device**)XNFreallocarray(xf86PciVideoInfo,
                                               num + 1,
                                               (pci_device*).sizeof);
            xf86PciVideoInfo[num] = null;
            xf86PciVideoInfo[num - 1] = info;

            pci_device_probe(info);
            if (primaryBus.type == BUS_NONE && (pci_device_is_boot_vga(info) ||
                                                pci_device_is_boot_display(info))) {
                primaryBus.type = BUS_PCI;
                primaryBus.id.pci = info;
            }
            info.user_data = 0;
        }
    }
    free(iter);

    /* If we haven't found a primary device try a different heuristic */
    if (primaryBus.type == BUS_NONE && num) {
        for (i = 0; i < num; i++) {
            ushort command = void;

            info = xf86PciVideoInfo[i];
            pci_device_cfg_read_u16(info, &command, 4);

            if ((command & PCI_CMD_MEM_ENABLE)
                && ((num == 1) || mixin(IS_VGA!(`info.device_class`)))) {
                if (primaryBus.type == BUS_NONE) {
                    primaryBus.type = BUS_PCI;
                    primaryBus.id.pci = info;
                }
                else {
                    LogMessageVerb(X_NOTICE, 1,
                                   "More than one possible primary device found\n");
                    primaryBus.type ^= cast(BusType) (-1);
                }
            }
        }
    }

    /* Print a summary of the video devices found */
    for (k = 0; k < num; k++) {
        const(char)* prim = " ";
        Bool memdone = FALSE, iodone = FALSE;

        info = xf86PciVideoInfo[k];

        if (!mixin(PCIALWAYSPRINTCLASSES!(`info.device_class`)))
            continue;

        if (xf86IsPrimaryPci(info))
            prim = "*";

        LogMessageVerb(X_PROBED, 1, "PCI:%s(%u@%u:%u:%u) %04x:%04x:%04x:%04x ", prim,
                       info.bus, info.domain, info.dev, info.func,
                       info.vendor_id, info.device_id,
                       info.subvendor_id, info.subdevice_id);

        xf86ErrorF("rev %d", info.revision);

        for (i = 0; i < 6; i++) {
            pci_mem_region* r = &info.regions[i];

            if (r.size && !r.is_IO) {
                if (!memdone) {
                    xf86ErrorF(", Mem @ ");
                    memdone = TRUE;
                }
                else
                    xf86ErrorF(", ");
                xf86ErrorF("0x%08lx/%ld", cast(c_long) r.base_addr, cast(c_long) r.size);
            }
        }

        for (i = 0; i < 6; i++) {
            pci_mem_region* r = &info.regions[i];

            if (r.size && r.is_IO) {
                if (!iodone) {
                    xf86ErrorF(", I/O @ ");
                    iodone = TRUE;
                }
                else
                    xf86ErrorF(", ");
                xf86ErrorF("0x%08lx/%ld", cast(c_long) r.base_addr, cast(c_long) r.size);
            }
        }

        if (info.rom_size) {
            xf86ErrorF(", BIOS @ 0x\?\?\?\?\?\?\?\?/%ld",
                       cast(c_long) info.rom_size);
        }

        xf86ErrorF("\n");
    }
    free(xf86PciVideoInfo);
}

/*
 * If the slot requested is already in use, return -1.
 * Otherwise, claim the slot for the screen requesting it.
 */

int xf86ClaimPciSlot(pci_device* d, DriverPtr drvp, int chipset, GDevPtr dev, Bool active)
{
    EntityPtr p;
    int num = void;

    if (xf86CheckPciSlot(d)) {
        num = xf86AllocateEntity();
        p = xf86Entities[num];
        p.driver = drvp;
        p.chipset = chipset;
        p.bus.type = BUS_PCI;
        p.bus.id.pci = d;
        p.active = active;
        p.inUse = FALSE;
        if (dev)
            xf86AddDevToEntity(num, dev);

        return num;
    }
    else
        return -1;
}

/*
 * Unclaim PCI slot, e.g. if probing failed, so that a different driver can claim.
 */
void xf86UnclaimPciSlot(pci_device* d, GDevPtr dev)
{
    int i = void;

    for (i = 0; i < xf86NumEntities; i++) {
        EntityPtr p = xf86Entities[i];

        if ((p.bus.type == BUS_PCI) && (p.bus.id.pci == d)) {
            /* Probably the slot should be deallocated? */
            xf86RemoveDevFromEntity(i, dev);
            p.bus.type = BUS_NONE;
            return;
        }
    }
}

/*
 * Parse a BUS ID string, and return the PCI bus parameters if it was
 * in the correct format for a PCI bus id.
 */

Bool xf86ParsePciBusString(const(char)* busID, int* bus, int* device, int* func)
{
    /*
     * The format is assumed to be "bus[@domain]:device[:func]", where domain,
     * bus, device and func are decimal integers.  domain and func may be
     * omitted and assumed to be zero, although doing this isn't encouraged.
     */

    char* p = void, s = void, d = void;
    const(char)* id = void;
    int i = void;

    if (StringToBusType(busID, &id) != BUS_PCI)
        return FALSE;

    s = cast(char*)Xstrdup(id);
    p = strtok(s, ":");
    if (p is null || *p == 0) {
        free(s);
        return FALSE;
    }
    d = strpbrk(p, "@");
    if (d !is null) {
        *(d++) = 0;
        for (i = 0; d[i] != 0; i++) {
            if (!isdigit(cast(ubyte)d[i])) {
                free(s);
                return FALSE;
            }
        }
    }
    for (i = 0; p[i] != 0; i++) {
        if (!isdigit(cast(ubyte)p[i])) {
            free(s);
            return FALSE;
        }
    }
    *bus = atoi(p);
    if (d !is null && *d != 0)
        *bus += atoi(d) << 8;
    p = strtok(null, ":");
    if (p is null || *p == 0) {
        free(s);
        return FALSE;
    }
    for (i = 0; p[i] != 0; i++) {
        if (!isdigit(cast(ubyte)p[i])) {
            free(s);
            return FALSE;
        }
    }
    *device = atoi(p);
    *func = 0;
    p = strtok(null, ":");
    if (p is null || *p == 0) {
        free(s);
        return TRUE;
    }
    for (i = 0; p[i] != 0; i++) {
        if (!isdigit(cast(ubyte)p[i])) {
            free(s);
            return FALSE;
        }
    }
    *func = atoi(p);
    free(s);
    return TRUE;
}

/*
 * Compare a BUS ID string with a PCI bus id.  Return TRUE if they match.
 */

Bool xf86ComparePciBusString(const(char)* busID, int bus, int device, int func)
{
    int ibus = void, idevice = void, ifunc = void;

    if (xf86ParsePciBusString(busID, &ibus, &idevice, &ifunc)) {
        return bus == ibus && device == idevice && func == ifunc;
    }
    else {
        return FALSE;
    }
}

/*
 * xf86IsPrimaryPci() -- return TRUE if primary device
 * is PCI and bus, dev and func numbers match.
 */

Bool xf86IsPrimaryPci(pci_device* pPci)
{
    /* Add max. 1 screen for the IgnorePrimary fallback path */
    if (xf86ProbeIgnorePrimary && xf86NumScreens == 0)
        return TRUE;

    if (primaryBus.type == BUS_PCI)
        return pPci == primaryBus.id.pci;
static if(XSERVER_PLATFORM_BUS){
    if (primaryBus.type == BUS_PLATFORM)
        if (primaryBus.id.plat.pdev)
            if (mixin(MATCH_PCI_DEVICES!("primaryBus.id.plat.pdev", "pPci")))
                return TRUE;
}
    return FALSE;
}

/*
 * xf86GetPciInfoForEntity() -- Get the pciVideoRec of entity.
 */
pci_device* xf86GetPciInfoForEntity(int entityIndex)
{
    EntityPtr p = void;

    if (entityIndex >= xf86NumEntities)
        return null;

    p = xf86Entities[entityIndex];
    switch (p.bus.type) {
    case BUS_PCI:
        return p.bus.id.pci;
    case BUS_PLATFORM:
        return p.bus.id.plat.pdev;
    default:
        break;
    }
    return null;
}

/*
 * xf86CheckPciMemBase() checks that the memory base value matches one of the
 * PCI base address register values for the given PCI device.
 */
Bool xf86CheckPciMemBase(pci_device* pPci, memType base)
{
    int i = void;

    for (i = 0; i < 6; i++)
        if (base == pPci.regions[i].base_addr)
            return TRUE;
    return FALSE;
}

/*
 * Check if the slot requested is free.  If it is already in use, return FALSE.
 */

Bool xf86CheckPciSlot(const(pci_device)* d)
{
    return xf86CheckSlot(d, BUS_PCI);
}

enum string END_OF_MATCHES(string m) = `
    (((` ~ m ~ `).vendor_id == 0) && ((` ~ m ~ `).device_id == 0) && ((` ~ m ~ `).subvendor_id == 0))`;

Bool xf86PciAddMatchingDev(DriverPtr drvp)
{
    const(pci_id_match*) devices = drvp.supported_devices;
    int j = void;
    pci_device* pPci = void;
    pci_device_iterator* iter = void;
    int numFound = 0;

    iter = pci_id_match_iterator_create(null);
    while ((pPci = pci_device_next(iter)) !is null) {
        /* Determine if this device is supported by the driver.  If it is,
         * add it to the list of devices to configure.
         */
        for (j = 0; !mixin(END_OF_MATCHES!(`devices[j]`)); j++) {
            if (PCI_ID_COMPARE(devices[j].vendor_id, pPci.vendor_id)
                && PCI_ID_COMPARE(devices[j].device_id, pPci.device_id)
                && ((devices[j].device_class_mask & pPci.device_class)
                    == devices[j].device_class)) {
                if (xf86CheckPciSlot(pPci)) {
                    GDevPtr pGDev = xf86AddBusDeviceToConfigure(drvp.driverName, BUS_PCI,
                                                    pPci, -1);
                    if (pGDev !is null) {
                        /* After configure pass 1, chipID and chipRev are
                         * treated as over-rides, so clobber them here.
                         */
                        pGDev.chipID = -1;
                        pGDev.chipRev = -1;
                    }

                    numFound++;
                }

                break;
            }
        }
    }

    pci_iterator_destroy(iter);

    return numFound != 0;
}

Bool xf86PciProbeDev(DriverPtr drvp)
{
    int i = void, j = void;
    pci_device* pPci = void;
    Bool foundScreen = FALSE;
    const(pci_id_match*) devices = drvp.supported_devices;
    GDevPtr* devList = void;
    const(uint) numDevs = xf86MatchDevice(drvp.driverName, &devList);

    for (i = 0; i < numDevs; i++) {
        pci_device_iterator* iter = void;
        uint device_id = void;

        /* Find the pciVideoRec associated with this device section.
         */
        iter = pci_id_match_iterator_create(null);
        while ((pPci = pci_device_next(iter)) !is null) {
            if (devList[i].busID && *devList[i].busID) {
                if (xf86ComparePciBusString(devList[i].busID,
                                            ((pPci.domain << 8)
                                             | pPci.bus),
                                            pPci.dev, pPci.func)) {
                    break;
                }
            }
            else if (xf86IsPrimaryPci(pPci)) {
                break;
            }
        }

        pci_iterator_destroy(iter);

        if (pPci is null) {
            continue;
        }
        device_id = (devList[i].chipID > 0)
            ? devList[i].chipID : pPci.device_id;

        /* Once the pciVideoRec is found, determine if the device is supported
         * by the driver.  If it is, probe it!
         */
        for (j = 0; !mixin(END_OF_MATCHES!(`devices[j]`)); j++) {
            if (PCI_ID_COMPARE(devices[j].vendor_id, pPci.vendor_id)
                && PCI_ID_COMPARE(devices[j].device_id, device_id)
                && ((devices[j].device_class_mask & pPci.device_class)
                    == devices[j].device_class)) {
                int entry = void;

                /* Allow the same entity to be used more than once for
                 * devices with multiple screens per entity.  This assumes
                 * implicitly that there will be a screen == 0 instance.
                 *
                 * FIXME Need to make sure that two different drivers don't
                 * FIXME claim the same screen > 0 instance.
                 */
                if ((devList[i].screen == 0) && !xf86CheckPciSlot(pPci))
                    continue;

                DebugF("%s: card at %d:%d:%d is claimed by a Device section\n",
                       drvp.driverName, pPci.bus, pPci.dev, pPci.func);

                /* Allocate an entry in the lists to be returned */
                entry = xf86ClaimPciSlot(pPci, drvp, device_id,
                                         devList[i], devList[i].active);

                if ((entry == -1) && (devList[i].screen > 0)) {
                    uint k = void;

                    for (k = 0; k < xf86NumEntities; k++) {
                        EntityPtr pEnt = xf86Entities[k];

                        if (pEnt.bus.type != BUS_PCI)
                            continue;
                        if (pEnt.bus.id.pci == pPci) {
                            entry = k;
                            xf86AddDevToEntity(k, devList[i]);
                            break;
                        }
                    }
                }

                if (entry != -1) {
                    if ((*drvp.PciProbe) (drvp, entry, pPci,
                                           devices[j].match_data)) {
                        foundScreen = TRUE;
                    }
                    else
                        xf86UnclaimPciSlot(pPci, devList[i]);
                }

                break;
            }
        }
    }
    free(devList);

    return foundScreen;
}

void xf86PciIsolateDevice(const(char)* argument)
{
    int bus = void, device = void, func = void;

    if (sscanf(argument, "PCI:%d:%d:%d", &bus, &device, &func) == 3) {
        xf86IsolateDevice.domain = mixin(PCI_DOM_FROM_BUS!("bus"));
        xf86IsolateDevice.bus = mixin(PCI_BUS_NO_DOMAIN!("bus"));
        xf86IsolateDevice.dev = device;
        xf86IsolateDevice.func = func;
    }
    else
        FatalError("Invalid isolated device specification\n");
}

private Bool pciDeviceHasBars(pci_device* pci)
{
    int i = void;

    for (i = 0; i < 6; i++)
        if (pci.regions[i].size)
            return TRUE;

    if (pci.rom_size)
        return TRUE;

    return FALSE;
}

struct Inst {
    pci_device* pci;
    GDevPtr dev;
    Bool foundHW;               /* PCIid in list of supported chipsets */
    Bool claimed;               /* BusID matches with a device section */
    int chip;
    int screen;
}

/**
 * Find set of unclaimed devices matching a given vendor ID.
 *
 * Used by drivers to find as yet unclaimed devices matching the specified
 * vendor ID.
 *
 * \param driverName     Name of the driver.  This is used to find Device
 *                       sections in the config file.
 * \param vendorID       PCI vendor ID of associated devices.  If zero, then
 *                       the true vendor ID must be encoded in the \c PCIid
 *                       fields of the \c PCIchipsets entries.
 * \param chipsets       Symbol table used to associate chipset names with
 *                       PCI IDs.
 * \param devList        List of Device sections parsed from the config file.
 * \param numDevs        Number of entries in \c devList.
 * \param drvp           Pointer the driver's control structure.
 * \param foundEntities  Returned list of entity indices associated with the
 *                       driver.
 *
 * \returns
 * The number of elements in returned in \c foundEntities on success or zero
 * on failure.
 *
 * \todo
 * This function does a bit more than short description says.  Fill in some
 * more of the details of its operation.
 *
 * \todo
 * The \c driverName parameter is redundant.  It is the same as
 * \c DriverRec::driverName.  In a future version of this function, remove
 * that parameter.
 */
int xf86MatchPciInstances(const(char)* driverName, int vendorID, SymTabPtr chipsets, PciChipsets* PCIchipsets, GDevPtr* devList, int numDevs, DriverPtr drvp, int** foundEntities)
{
    int i = void, j = void;
    pci_device* pPci = void;
    pci_device_iterator* iter = void;
    Inst* instances = null;
    int numClaimedInstances = 0;
    int allocatedInstances = 0;
    int numFound = 0;
    SymTabRec* c = void;
    PciChipsets* id = void;
    int* retEntities = null;

    *foundEntities = null;

    /* Each PCI device will contribute at least one entry.  Each device
     * section can contribute at most one entry.  The sum of the two is
     * guaranteed to be larger than the maximum possible number of entries.
     * Do this calculation and memory allocation once now to eliminate the
     * need for realloc calls inside the loop.
     */
    if (!(xf86DoConfigure && xf86DoConfigurePass1)) {
        uint max_entries = numDevs;

        iter = pci_slot_match_iterator_create(null);
        while ((pPci = pci_device_next(iter)) !is null) {
            max_entries++;
        }

        pci_iterator_destroy(iter);
        instances = cast(Inst*) XNFreallocarray(null, max_entries, Inst.sizeof);
    }

    iter = pci_slot_match_iterator_create(null);
    while ((pPci = pci_device_next(iter)) !is null) {
        uint device_class = pPci.device_class;
        Bool foundVendor = FALSE;

        /* Convert the pre-PCI 2.0 device class for a VGA adapter to the
         * 2.0 version of the same class.
         */
        if (device_class == 0x00000101) {
            device_class = 0x00030000;
        }

        /* Find PCI devices that match the given vendor ID.  The vendor ID is
         * either specified explicitly as a parameter to the function or
         * implicitly encoded in the high bits of id->PCIid.
         *
         * The first device with a matching vendor is recorded, even if the
         * device ID doesn't match.  This is done because the Device section
         * in the xorg.conf file can over-ride the device ID.  A matching PCI
         * ID might not be found now, but after the device ID over-ride is
         * applied there /might/ be a match.
         */
        for (id = PCIchipsets; id.PCIid != -1; id++) {
            const(uint) vendor_id = ((id.PCIid & 0xFFFF0000) >> 16)
                | vendorID;
            const(uint) device_id = (id.PCIid & 0x0000FFFF);
            const(uint) match_class = 0x00030000 | id.PCIid;

            if ((vendor_id == pPci.vendor_id)
                || ((vendorID == PCI_VENDOR_GENERIC) &&
                    (match_class == device_class))) {
                if (!foundVendor && (instances !is null)) {
                    ++allocatedInstances;
                    instances[allocatedInstances - 1].pci = pPci;
                    instances[allocatedInstances - 1].dev = null;
                    instances[allocatedInstances - 1].claimed = FALSE;
                    instances[allocatedInstances - 1].foundHW = FALSE;
                    instances[allocatedInstances - 1].screen = 0;
                }

                foundVendor = TRUE;

                if ((device_id == pPci.device_id)
                    || ((vendorID == PCI_VENDOR_GENERIC)
                        && (match_class == device_class))) {
                    if (instances !is null) {
                        instances[allocatedInstances - 1].foundHW = TRUE;
                        instances[allocatedInstances - 1].chip = cast(short)id.numChipset;
                    }

                    if (xf86DoConfigure && xf86DoConfigurePass1) {
                        if (xf86CheckPciSlot(pPci)) {
                            GDevPtr pGDev = xf86AddBusDeviceToConfigure(drvp.driverName,
                                                            BUS_PCI, pPci, -1);

                            if (pGDev) {
                                /* After configure pass 1, chipID and chipRev
                                 * are treated as over-rides, so clobber them
                                 * here.
                                 */
                                pGDev.chipID = -1;
                                pGDev.chipRev = -1;
                            }

                            numFound++;
                        }
                    }
                    else {
                        numFound++;
                    }

                    break;
                }
            }
        }
    }

    pci_iterator_destroy(iter);

    /* In "probe only" or "configure" mode (signaled by instances being NULL),
     * our work is done.  Return the number of detected devices.
     */
    if (instances is null) {
        return numFound;
    }

    /*
     * This may be debatable, but if no PCI devices with a matching vendor
     * type is found, return zero now.  It is probably not desirable to
     * allow the config file to override this.
     */
    if (allocatedInstances <= 0) {
        free(instances);
        return 0;
    }

    DebugF("%s instances found: %d\n", driverName, allocatedInstances);

    /*
     * Check for devices that need duplicated instances.  This is required
     * when there is more than one screen per entity.
     *
     * XXX This currently doesn't work for cases where the BusID isn't
     * specified explicitly in the config file.
     */

    for (j = 0; j < numDevs; j++) {
        if (devList[j].screen > 0 && devList[j].busID && *devList[j].busID) {
            for (i = 0; i < allocatedInstances; i++) {
                pPci = instances[i].pci;
                if (xf86ComparePciBusString(devList[j].busID,
                                            mixin(PCI_MAKE_BUS!("pPci.domain",
                                                         "pPci.bus")), pPci.dev,
                                            pPci.func)) {
                    allocatedInstances++;
                    instances[allocatedInstances - 1] = instances[i];
                    instances[allocatedInstances - 1].screen =
                        devList[j].screen;
                    numFound++;
                    break;
                }
            }
        }
    }

    for (i = 0; i < allocatedInstances; i++) {
        GDevPtr dev = null;
        GDevPtr devBus = null;

        pPci = instances[i].pci;
        for (j = 0; j < numDevs; j++) {
            if (devList[j].busID && *devList[j].busID) {
                if (xf86ComparePciBusString(devList[j].busID,
                                            mixin(PCI_MAKE_BUS!("pPci.domain",
                                                         "pPci.bus")), pPci.dev,
                                            pPci.func) &&
                    devList[j].screen == instances[i].screen) {

                    if (devBus)
                        LogMessageVerb(X_WARNING, 0,
                                       "%s: More than one matching Device section for "
                                       ~ "instances\n\t(BusID: %s) found: %s\n",
                                       driverName, devList[j].busID,
                                       devList[j].identifier);
                    else
                        devBus = devList[j];
                }
            }
            else {
                /*
                 * if device section without BusID is found
                 * only assign to it to the primary device.
                 */
                if (xf86IsPrimaryPci(pPci)) {
                    LogMessageVerb(X_PROBED, 1, "Assigning device section with no busID to primary device\n");
                    if (dev || devBus)
                        LogMessageVerb(X_WARNING, 0,
                                       "%s: More than one matching Device section "
                                       ~ "found: %s\n", driverName,
                                       devList[j].identifier);
                    else
                        dev = devList[j];
                }
            }
        }
        if (devBus)
            dev = devBus;       /* busID preferred */
        if (!dev) {
            if (xf86CheckPciSlot(pPci) && pciDeviceHasBars(pPci)) {
                LogMessageVerb(X_WARNING, 0, "%s: No matching Device section "
                               ~ "for instance (BusID PCI:%u@%u:%u:%u) found\n",
                               driverName, pPci.bus, pPci.domain, pPci.dev,
                               pPci.func);
            }
        }
        else {
            numClaimedInstances++;
            instances[i].claimed = TRUE;
            instances[i].dev = dev;
        }
    }
    DebugF("%s instances found: %d\n", driverName, numClaimedInstances);
    /*
     * Now check that a chipset or chipID override in the device section
     * is valid.  Chipset has precedence over chipID.
     * If chipset is not valid ignore BusSlot completely.
     */
    for (i = 0; i < allocatedInstances && numClaimedInstances > 0; i++) {
        MessageType from = X_PROBED;

        if (!instances[i].claimed) {
            continue;
        }
        if (instances[i].dev.chipset) {
            for (c = chipsets; c.token >= 0; c++) {
                if (xf86NameCmp(c.name, instances[i].dev.chipset) == 0)
                    break;
            }
            if (c.token == -1) {
                instances[i].claimed = FALSE;
                numClaimedInstances--;
                LogMessageVerb(X_WARNING, 0, "%s: Chipset \"%s\" in Device "
                               ~ "section \"%s\" isn't valid for this driver\n",
                               driverName, instances[i].dev.chipset,
                               instances[i].dev.identifier);
            }
            else {
                instances[i].chip = cast(short)c.token;

                for (id = PCIchipsets; id.numChipset >= 0; id++) {
                    if (id.numChipset == instances[i].chip)
                        break;
                }
                if (id.numChipset >= 0) {
                    LogMessageVerb(X_CONFIG, 1, "Chipset override: %s\n",
                                   instances[i].dev.chipset);
                    from = X_CONFIG;
                }
                else {
                    instances[i].claimed = FALSE;
                    numClaimedInstances--;
                    LogMessageVerb(X_WARNING, 0, "%s: Chipset \"%s\" in Device "
                                   ~ "section \"%s\" isn't a valid PCI chipset\n",
                                   driverName, instances[i].dev.chipset,
                                   instances[i].dev.identifier);
                }
            }
        }
        else if (instances[i].dev.chipID > 0) {
            for (id = PCIchipsets; id.numChipset >= 0; id++) {
                if (id.PCIid == instances[i].dev.chipID)
                    break;
            }
            if (id.numChipset == -1) {
                instances[i].claimed = FALSE;
                numClaimedInstances--;
                LogMessageVerb(X_WARNING, 0, "%s: ChipID 0x%04X in Device "
                               ~ "section \"%s\" isn't valid for this driver\n",
                               driverName, instances[i].dev.chipID,
                               instances[i].dev.identifier);
            }
            else {
                instances[i].chip = cast(short)id.numChipset;
                LogMessageVerb(X_CONFIG, 1, "ChipID override: 0x%04X\n",
                               instances[i].dev.chipID);
                from = X_CONFIG;
            }
        }
        else if (!instances[i].foundHW) {
            /*
             * This means that there was no override and the PCI chipType
             * doesn't match one that is supported
             */
            instances[i].claimed = FALSE;
            numClaimedInstances--;
        }
        if (instances[i].claimed == TRUE) {
            for (c = chipsets; c.token >= 0; c++) {
                if (c.token == instances[i].chip)
                    break;
            }
            LogMessageVerb(from, 1, "Chipset %s found\n", c.name);
        }
    }

    /*
     * Of the claimed instances, check that another driver hasn't already
     * claimed its slot.
     */
    numFound = 0;
    for (i = 0; i < allocatedInstances && numClaimedInstances > 0; i++) {
        if (!instances[i].claimed)
            continue;
        pPci = instances[i].pci;

        /*
         * Allow the same entity to be used more than once for devices with
         * multiple screens per entity.  This assumes implicitly that there
         * will be a screen == 0 instance.
         *
         * XXX Need to make sure that two different drivers don't claim
         * the same screen > 0 instance.
         */
        if (instances[i].screen == 0 && !xf86CheckPciSlot(pPci))
            continue;

        DebugF("%s: card at %d:%d:%d is claimed by a Device section\n",
               driverName, pPci.bus, pPci.dev, pPci.func);

        /* Allocate an entry in the lists to be returned */
        numFound++;
        retEntities = cast(int*) XNFreallocarray(retEntities, numFound, int.sizeof);
        retEntities[numFound - 1] = xf86ClaimPciSlot(pPci, drvp,
                                                     instances[i].chip,
                                                     instances[i].dev,
                                                     instances[i].dev.active);
        if (retEntities[numFound - 1] == -1 && instances[i].screen > 0) {
            for (j = 0; j < xf86NumEntities; j++) {
                EntityPtr pEnt = xf86Entities[j];

                if (pEnt.bus.type != BUS_PCI)
                    continue;
                if (pEnt.bus.id.pci == pPci) {
                    retEntities[numFound - 1] = j;
                    xf86AddDevToEntity(j, instances[i].dev);
                    break;
                }
            }
        }
    }
    free(instances);
    if (numFound > 0) {
        *foundEntities = retEntities;
    }

    return numFound;
}

/*
 * xf86ConfigPciEntityInactive() -- This function can be used
 * to configure an inactive entity as well as to reconfigure an
 * previously active entity inactive. If the entity has been
 * assigned to a screen before it will be removed. If p_chip is
 * non-NULL all static resources listed there will be registered.
 */
void xf86ConfigPciEntityInactive(EntityInfoPtr pEnt, PciChipsets* p_chip, EntityProc init, EntityProc enter, EntityProc leave, void* private_)
{
    ScrnInfoPtr pScrn = void;

    if ((pScrn = xf86FindScreenForEntity(pEnt.index)) !is null)
        xf86RemoveEntityFromScreen(pScrn, pEnt.index);
}

ScrnInfoPtr xf86ConfigPciEntity(ScrnInfoPtr pScrn, int scrnFlag, int entityIndex, PciChipsets* p_chip, void* dummy, EntityProc init, EntityProc enter, EntityProc leave, void* private_)
{
    EntityInfoPtr pEnt = xf86GetEntityInfo(entityIndex);

    if (dummy || init || enter || leave)
        FatalError("Legacy entity access functions are unsupported\n");

    if (!pEnt)
        return pScrn;

    if (!(pEnt.location.type == BUS_PCI)
        || !xf86GetPciInfoForEntity(entityIndex)) {
        free(pEnt);
        return pScrn;
    }
    if (!pEnt.active) {
        xf86ConfigPciEntityInactive(pEnt, p_chip, init, enter, leave, private_);
        free(pEnt);
        return pScrn;
    }

    if (!pScrn)
        pScrn = xf86AllocateScreen(pEnt.driver, scrnFlag);
    if (xf86IsEntitySharable(entityIndex)) {
        xf86SetEntityShared(entityIndex);
    }
    xf86AddEntityToScreen(pScrn, entityIndex);
    if (xf86IsEntityShared(entityIndex)) {
        return pScrn;
    }
    free(pEnt);

    return pScrn;
}

void xf86VideoPtrToDriverList(pci_device* dev, XF86MatchedDrivers* md)
{
    int i = void;

    /* Add more entries here if we ever return more than 4 drivers for
       any device */
    const(char)*[5] driverList = [ null, null, null, null, null ];

    switch (dev.vendor_id) {
        /* AMD Geode LX */
    case 0x1022:
        if (dev.device_id == 0x2081)
            driverList[0] = "geode";
        break;
        /* older Geode products acquired by AMD still carry an NSC vendor_id */
    case 0x100b:
        if (dev.device_id == 0x0030) {
            /* NSC Geode GX2 specifically */
            driverList[0] = "geode";
            /* GX2 support started its life in the NSC tree and was later
               forked by AMD for GEODE so we keep it as a backup */
            driverList[1] = "nsc";
        }
        else
            /* other NSC variant e.g. 0x0104 (SC1400), 0x0504 (SCx200) */
            driverList[0] = "nsc";
        break;
        /* Cyrix Geode GX1 */
    case 0x1078:
        if (dev.device_id == 0x0104)
            driverList[0] = "cyrix";
        break;
    case 0X1142:
        driverList[0] = "apm";
        break;
    case 0xedd8:
        driverList[0] = "ark";
        break;
    case 0x1a03:
        driverList[0] = "ast";
        break;
    case 0x1002:
        driverList[0] = "ati";
        break;
    case 0x102c:
        driverList[0] = "chips";
        break;
    case 0x1013:
        driverList[0] = "cirrus";
        break;
    case 0x3d3d:
        driverList[0] = "glint";
        break;
    case 0x105d:
        driverList[0] = "i128";
        break;
    case 0x8086:
	switch (dev.device_id)
	{
		/* Intel i740 */
		case 0x00d1:
		case 0x7800:
			driverList[0] = "i740";
			break;
		/* GMA500/Poulsbo */
		case 0x8108:
		case 0x8109:
			/* Try psb driver on Poulsbo - if available */
			driverList[0] = "psb";
			driverList[1] = "psb_drv";
			break;
		/* GMA600/Oaktrail */
		case 0x4100:
		case 0x4101:
		case 0x4102:
		case 0x4103:
		case 0x4104:
		case 0x4105:
		case 0x4106:
		case 0x4107:
		/* Atom E620/Oaktrail */
		case 0x4108:
		/* Medfield */
		case 0x0130:
		case 0x0131:
		case 0x0132:
		case 0x0133:
		case 0x0134:
		case 0x0135:
		case 0x0136:
		case 0x0137:
		/* GMA 3600/CDV */
		case 0x0be0:
		case 0x0be1:
		case 0x0be2:
		case 0x0be3:
		case 0x0be4:
		case 0x0be5:
		case 0x0be6:
		case 0x0be7:
		case 0x0be8:
		case 0x0be9:
		case 0x0bea:
		case 0x0beb:
		case 0x0bec:
		case 0x0bed:
		case 0x0bee:
		case 0x0bef:
			/* Use fbdev/vesa driver on Oaktrail, Medfield, CDV */
			break;
		/* Default to intel only on pre-gen3 chips */
		case 0x7121:
		case 0x7123:
		case 0x7125:
		case 0X1132:
		case 0x3577:
		case 0x2562:
		case 0x3582:
		case 0x358e:
		case 0x2572:
			driverList[0] = "intel";
			break;
        default: break;}
        break;
    case 0x102b:
        driverList[0] = "mga";
        break;
    case 0x10c8:
        driverList[0] = "neomagic";
        break;
    case 0x10de:
    case 0x12d2:
    {
        int idx = 0;

static if (HasVersion!"linux" || HasVersion!"__NetBSD__") {
        driverList[idx++] = "nouveau";
}
        driverList[idx++] = "modesetting";
        driverList[idx++] = "nvidia";
        driverList[idx++] = "nv";
        break;
    }
    case 0X1106:
        driverList[0] = "openchrome";
        break;
    case 0x1b36:
        driverList[0] = "qxl";
        break;
    case 0X1163:
        driverList[0] = "rendition";
        break;
    case 0x5333:
        switch (dev.device_id) {
        case 0x88d0:
        case 0x88d1:
        case 0x88f0:
        case 0x8811:
        case 0x8812:
        case 0x8814:
        case 0x8901:
            driverList[0] = "s3";
            break;
        case 0x5631:
        case 0x883d:
        case 0x8a01:
        case 0x8a10:
        case 0x8c01:
        case 0x8c03:
        case 0x8904:
        case 0x8a13:
            driverList[0] = "s3virge";
            break;
        default:
            driverList[0] = "savage";
            break;
        }
        break;
    case 0x1039:
        driverList[0] = "sis";
        break;
    case 0x126f:
        driverList[0] = "siliconmotion";
        break;
    case 0x121a:
        if (dev.device_id < 0x0003)
            driverList[0] = "voodoo";
        else
            driverList[0] = "tdfx";
        break;
    case 0x1011:
        driverList[0] = "tga";
        break;
    case 0x1023:
        driverList[0] = "trident";
        break;
    case 0x100c:
        driverList[0] = "tseng";
        break;
    case 0x80ee:
        driverList[0] = "vboxvideo";
        break;
    case 0x15ad:
        driverList[0] = "vmware";
        break;
    case 0x18ca:
        if (dev.device_id == 0x47)
            driverList[0] = "xgixp";
        else
            driverList[0] = "xgi";
        break;
    default:
        break;
    }
    for (i = 0; driverList[i] !is null; i++) {
        xf86AddMatchedDriver(md, driverList[i]);
    }
}

version (linux) {
private int xchomp(char* line)
{
    size_t len = 0;

    if (!line) {
        return 1;
    }

    len = strlen(line);
    if (line[len - 1] == '\n' && len > 0) {
        line[len - 1] = '\0';
    }
    return 0;
}

/* This function is used to provide a workaround for binary drivers that
 * don't export their PCI ID's properly. If distros don't end up using this
 * feature it can and should be removed because the symbol-based resolution
 * scheme should be the primary one */
void xf86MatchDriverFromFiles(ushort match_vendor, ushort match_chip, XF86MatchedDrivers* md)
{
    DIR* idsdir = void;
    FILE* fp = void;
    dirent* direntry = void;
    char* line = null, tmpMatch = void;
    size_t len = void;
    ssize_t read = void;
    char[512] path_name = void; char[5] vendor_str = void, chip_str = void;
    ushort vendor = void, chip = void;
    int j = void;

    idsdir = opendir(PCI_TXT_IDS_PATH);
    if (!idsdir)
        return;

    LogMessageVerb(X_INFO, 1,
                   "Scanning %s directory for additional PCI ID's supported by the drivers\n",
                   PCI_TXT_IDS_PATH.ptr);
    direntry = readdir(idsdir);
    /* Read the directory */
    while (direntry) {
        if (direntry.d_name[0] == '.') {
            direntry = readdir(idsdir);
            continue;
        }
        len = strlen(direntry.d_name.ptr);
        /* A tiny bit of sanity checking. We should probably do better */
        if (strncmp(&(direntry.d_name[len - 4]), ".ids", 4) == 0) {
            /* We need the full path name to open the file */
            snprintf(path_name.ptr, path_name.sizeof, "%s/%s",
                     PCI_TXT_IDS_PATH.ptr, direntry.d_name.ptr);
            fp = fopen(path_name.ptr, "r");
            if (fp is null) {
                LogMessageVerb(X_ERROR, 1, "Could not open %s for reading. Exiting.\n",
                               path_name.ptr);
                goto end;
            }
            /* Read the file */
            bool cond = (read = getline(&line, &len, fp)) != -1;

version (__GLIBC__) {
            cond = (line = fgetln(fp, &len)) !is null;
}
            // while ((read = getline(&line, &len, fp)) != -1) {
            while (cond) {
                xchomp(line);
                if (isdigit(line[0])) {
                    strlcpy(vendor_str.ptr, line, vendor_str.sizeof);
                    vendor = cast(short) strtol(vendor_str.ptr, null, 16);
                    if ((strlen(&line[4])) == 0) {
                        chip_str[0] = '\0';
                        chip = cast(short)-1;
                    }
                    else {
                        /* Handle trailing whitespace */
                        if (isspace(line[4])) {
                            chip_str[0] = '\0';
                            chip = cast(short)-1;
                        }
                        else {
                            /* Ok, it's a real ID */
                            strlcpy(chip_str.ptr, &line[4], chip_str.sizeof);
                            chip = cast(short)cast(int) strtol(chip_str.ptr, null, 16);
                        }
                    }
                    if (vendor == match_vendor && chip == match_chip) {
                        tmpMatch =
                            cast(char*) calloc(1, (char.sizeof *
                                            strlen(direntry.d_name.ptr) - 3));
                        if (!tmpMatch) {
                            LogMessageVerb(X_ERROR, 1,
                                           "Could not allocate space for the module name. Exiting.\n");
                            goto end;
                        }
                        /* hack off the .ids suffix. This should guard
                         * against other problems, but it will end up
                         * taking off anything after the first '.' */
                        for (j = 0; j < (strlen(direntry.d_name.ptr) - 3); j++) {
                            if (direntry.d_name[j] == '.') {
                                tmpMatch[j] = '\0';
                                break;
                            }
                            else {
                                tmpMatch[j] = direntry.d_name[j];
                            }
                        }
                        xf86AddMatchedDriver(md, tmpMatch);
                        LogMessageVerb(X_INFO, 1, "Matched %s from file name %s\n",
                                       tmpMatch, direntry.d_name.ptr);
                        free(tmpMatch);
                    }
                }
                else {
                    /* TODO Handle driver overrides here */
                }
            }
            fclose(fp);}
        }
        direntry = readdir(idsdir);
 end:
    free(line);
    closedir(idsdir);
}
                       /* __linux__ */

void xf86PciMatchDriver(XF86MatchedDrivers* md)
{
    pci_device* info = null;
    pci_device_iterator* iter = void;

    /* Find the primary device, and get some information about it. */
    iter = pci_slot_match_iterator_create(null);
    while ((info = pci_device_next(iter)) !is null) {
        if (xf86IsPrimaryPci(info)) {
            break;
        }
    }

    pci_iterator_destroy(iter);
version (linux) {
    if (info)
        xf86MatchDriverFromFiles(info.vendor_id, info.device_id, md);
}

    if (info !is null) {
        xf86VideoPtrToDriverList(info, md);
    }
}

Bool xf86PciConfigure(void* busData, pci_device* pDev)
{
    pci_device* pVideo = null;

    pVideo = cast(pci_device*) busData;
    if (pDev &&
        (pDev.domain == pVideo.domain) &&
        (pDev.bus == pVideo.bus) &&
        (pDev.dev == pVideo.dev) && (pDev.func == pVideo.func))
        return 0;

    return 1;
}

void xf86PciConfigureNewDev(void* busData, pci_device* pVideo, GDevRec* GDev, int* chipset)
{
    char[8] busnum = void;
    char* tmp = void;

    pVideo = cast(pci_device*) busData;

    snprintf(busnum.ptr, busnum.sizeof, "%d", pVideo.bus);

    XNFasprintf(&tmp, "PCI:%s:%d:%d",
                busnum.ptr, pVideo.dev, pVideo.func);
    GDev.busID = tmp;

    GDev.chipID = pVideo.device_id;
    GDev.chipRev = pVideo.revision;

    if (*chipset < 0)
        *chipset = (pVideo.vendor_id << 16) | pVideo.device_id;
}

char* DRICreatePCIBusID(const(pci_device)* dev)
{
    char* busID = void;

    if (asprintf(&busID, "pci:%04x:%02x:%02x.%d",
                 dev.domain, dev.bus, dev.dev, dev.func) == -1)
        return null;

    return busID;
}

}