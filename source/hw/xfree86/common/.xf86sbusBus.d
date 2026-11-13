module xf86sbusBus;
@nogc nothrow:
extern(C): __gshared:
/*
 * SBUS bus-specific code.
 *
 * Copyright (C) 2000 Jakub Jelinek (jakub@redhat.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * JAKUB JELINEK BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER
 * IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
 * CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
 */
import build.xorg_config;

import core.stdc.ctype;
import core.stdc.stdio;
import core.sys.posix.unistd;
//import x11.X;
import os.os;
import xf86_priv;
import hw.xfree86.common.xf86Priv;
import hw.xfree86.os_support.xf86_OSlib;
import xf86cmap;

import xf86Bus;

import hw.xfree86.common.xf86sbusBus_priv;;
import hw.xfree86.os_support.bus.xf86Sbus_priv;
import xf86sbusBus;
import externs.linux.fbio;
import xf86platformBus_priv;
import xf86Globals;
import hw.xfree86.common.xf86Xinput;
import os.log;
import xf86pciBus;
import drm_platform;
import core.stdc.string;
import externs.gnu;
import hw.xfree86.common.xf86Helper;
import dix.events;
// import Sbus.c;
import os.log_priv;
import dix.screen_hooks;

public import hw.xfree86.common.xf86str;

enum SBUS_DEVICE_CG3 =		0x0003;
enum SBUS_DEVICE_CG6 =		0x0005;
enum SBUS_DEVICE_CG14 =	0x0008;
enum SBUS_DEVICE_LEO =		0x0009;
enum SBUS_DEVICE_TCX =		0x000a;
enum SBUS_DEVICE_FFB =		0x000b;

struct sbus_prom_node {
    int node;
    /* Because of misdesigned openpromio */
    int[2] cookie;
}alias sbusPromNode = sbus_prom_node;
alias sbusPromNodePtr = sbus_prom_node*;

struct sbus_device {
    int devId;
    int fbNum;
    int fd;
    int width, height;
    sbusPromNode node;
    const(char)* descr;
    const(char)* device;
}alias sbusDevice = sbus_device;
alias sbusDevicePtr = sbus_device*;

void  xf86MatchSbusInstances(const(char)* driverName, int sbusDevId, GDevPtr* devList, int numDevs, DriverPtr drvp, int** foundEntities);
void  xf86GetSbusInfoForEntity(int entityIndex);
void  xf86SbusUseBuiltinMode(ScrnInfoPtr pScrn, sbusDevicePtr psdp);
void * xf86MapSbusMem(sbusDevicePtr psdp, c_ulong offset, c_ulong size);
void  xf86UnmapSbusMem(sbusDevicePtr psdp, void* addr, c_ulong size);
void  xf86SbusHideOsHwCursor(sbusDevicePtr psdp);
void  xf86SbusSetOsHwCursorCmap(sbusDevicePtr psdp, int bg, int fg);
void  xf86SbusHandleColormaps(ScreenPtr pScreen, sbusDevicePtr psdp);

// void  sparcPromInit();
// void  sparcPromClose();
// void  sparcPromGetBool(sbusPromNodePtr pnode, const(char)* prop);

                          /* _XF86_SBUSBUS_H */



private int xf86nSbusInfo;


private void CheckSbusDevice(const(char)* device, int fbNum)
{
    int fd = void, i = void;
    fbgattr fbattr_ = void;
    sbusDevicePtr psdp = void;

    fd = open(device, O_RDONLY, 0);
    if (fd < 0)
        return;
    memset(&fbattr_, 0, fbgattr.sizeof);
    if (ioctl(fd, FBIOGATTR, &fbattr_) < 0) {
        if (ioctl(fd, FBIOGTYPE, &fbattr_.fbtype_) < 0) {
            close(fd);
            return;
        }
    }
    close(fd);
    for (i = 0; sbusDeviceTable[i].devId; i++)
        if (sbusDeviceTable[i].fbType == fbattr_.fbtype_.fb_type)
            break;
    if (!sbusDeviceTable[i].devId)
        return;
    xf86SbusInfo =
        cast(sbusDevicePtr*) XNFreallocarray(xf86SbusInfo, ++xf86nSbusInfo + 1, psdp.sizeof);
    xf86SbusInfo[xf86nSbusInfo] = null;
    xf86SbusInfo[xf86nSbusInfo - 1] = psdp = cast(sbus_device*)XNFcallocarray(1, sbusDevice.sizeof);
    psdp.devId = sbusDeviceTable[i].devId;
    psdp.fbNum = fbNum;
    psdp.device = cast(const(char)*)XNFstrdup(device);
    psdp.width = fbattr_.fbtype_.fb_width;
    psdp.height = fbattr_.fbtype_.fb_height;
    psdp.fd = -1;
}

void xf86SbusProbe()
{
    int i = void, useProm = 0;
    char[32] fbDevName = void;
    sbusDevicePtr psdp = void; sbusDevicePtr* psdpp = void;

    xf86SbusInfo = cast(sbusDevicePtr*) calloc(1, sbusDevicePtr.sizeof);
    *xf86SbusInfo = null;
    for (i = 0; i < 32; i++) {
        snprintf(fbDevName.ptr, fbDevName.sizeof, "/dev/fb%d", i);
        CheckSbusDevice(fbDevName.ptr, i);
    }
    if (sparcPromInit() >= 0) {
        useProm = 1;
        sparcPromAssignNodes();
    }
    for (psdpp = xf86SbusInfo; ((psdp = *psdpp) !is null); psdpp++) {
        for (i = 0; sbusDeviceTable[i].devId; i++)
            if (sbusDeviceTable[i].devId == psdp.devId)
                psdp.descr = sbusDeviceTable[i].descr;
        /*
         * If we can use PROM information and found the PROM node for this
         * device, we can tell more about the card.
         */
        if (useProm && psdp.node.node) {
            char* prop = void, promPath = void;
            int len = void, chiprev = void, vmsize = void;

            switch (psdp.devId) {
            case SBUS_DEVICE_CG6:
                chiprev = 0;
                vmsize = 0;
                prop = sparcPromGetProperty(&psdp.node, "chiprev", &len);
                if (prop && len == 4)
                    chiprev = *cast(int*) prop;
                prop = sparcPromGetProperty(&psdp.node, "vmsize", &len);
                if (prop && len == 4)
                    vmsize = *cast(int*) prop;
                switch (chiprev) {
                case 1:
                case 2:
                case 3:
                case 4:
                    psdp.descr = "Sun Double width GX";
                    break;
                case 5:
                case 6:
                case 7:
                case 8:
                case 9:
                    psdp.descr = "Sun Single width GX";
                    break;
                case 11:
                    switch (vmsize) {
                    case 2:
                        psdp.descr = "Sun Turbo GX with 1M VSIMM";
                        break;
                    case 4:
                        psdp.descr = "Sun Turbo GX Plus";
                        break;
                    default:
                        psdp.descr = "Sun Turbo GX";
                        break;
                    }
                goto default;
                default: break;}
                break;
            case SBUS_DEVICE_CG14:
                prop = sparcPromGetProperty(&psdp.node, "reg", &len);
                vmsize = 0;
                if (prop && !(len % 12) && len > 0)
                    vmsize = *cast(int*) (prop + len - 4);
                switch (vmsize) {
                case 0x400000:
                    psdp.descr = "Sun SX with 4M VSIMM";
                    break;
                case 0x800000:
                    psdp.descr = "Sun SX with 8M VSIMM";
                    break;
                default: break;}
                break;
            case SBUS_DEVICE_LEO:
                prop = sparcPromGetProperty(&psdp.node, "model", &len);
                if (prop && len > 0 && !strstr(prop, "501-2503"))
                    psdp.descr = "Sun Turbo ZX";
                break;
            case SBUS_DEVICE_TCX:
                if (sparcPromGetBool(&psdp.node, "tcx-8-bit"))
                    psdp.descr = "Sun TCX (8bit)";
                else
                    psdp.descr = "Sun TCX (S24)";
                break;
            case SBUS_DEVICE_FFB:
                prop = sparcPromGetProperty(&psdp.node, "name", &len);
                chiprev = 0;
                prop = sparcPromGetProperty(&psdp.node, "board_type", &len);
                if (prop && len == 4)
                    chiprev = *cast(int*) prop;
                if (strstr(prop, "afb")) {
                    if (chiprev == 3)
                        psdp.descr = "Sun|Elite3D-M6 Horizontal";
                }
                else {
                    switch (chiprev) {
                    case 0x08:
                        psdp.descr = "Sun FFB 67MHz Creator";
                        break;
                    case 0x0b:
                        psdp.descr = "Sun FFB 67MHz Creator 3D";
                        break;
                    case 0x1b:
                        psdp.descr = "Sun FFB 75MHz Creator 3D";
                        break;
                    case 0x20:
                    case 0x28:
                        psdp.descr = "Sun FFB2 Vertical Creator";
                        break;
                    case 0x23:
                    case 0x2b:
                        psdp.descr = "Sun FFB2 Vertical Creator 3D";
                        break;
                    case 0x30:
                        psdp.descr = "Sun FFB2+ Vertical Creator";
                        break;
                    case 0x33:
                        psdp.descr = "Sun FFB2+ Vertical Creator 3D";
                        break;
                    case 0x40:
                    case 0x48:
                        psdp.descr = "Sun FFB2 Horizontal Creator";
                        break;
                    case 0x43:
                    case 0x4b:
                        psdp.descr = "Sun FFB2 Horizontal Creator 3D";
                        break;
                    default: break;}
                }
                break;
            default: break;}

            LogMessageVerb(X_PROBED, 1, "SBUS:(0x%08x) %s", psdp.node.node, psdp.descr);
            promPath = sparcPromNode2Pathname(&psdp.node);
            if (promPath) {
                xf86ErrorF(" at %s", promPath);
                free(promPath);
            }
        }
        else
            LogMessageVerb(X_PROBED, 1, "SBUS: %s", psdp.descr);
        xf86ErrorF("\n");
    }
    if (useProm)
        sparcPromClose();
}

/*
 * Parse a BUS ID string, and return the SBUS bus parameters if it was
 * in the correct format for a SBUS bus id.
 */

private Bool xf86ParseSbusBusString(const(char)* busID, int* fbNum)
{
    /*
     * The format is assumed to be one of:
     * "fbN", e.g. "fb1", which means the device corresponding to /dev/fbN
     * "nameN", e.g. "cgsix0", which means Nth instance of card NAME
     * "/prompath", e.g. "/sbus@0,10001000/cgsix@3,0" which is PROM pathname
     * to the device.
     */

    const(char)* id = void;
    int i = void, len = void;

    if (StringToBusType(busID, &id) != BUS_SBUS)
        return False;

    if (*id != '/') {
        if (!strncmp(id, "fb", 2)) {
            if (!isdigit(id[2]))
                return False;
            *fbNum = atoi(id + 2);
            return True;
        }
        else {
            sbusDevicePtr* psdpp = void;
            int devId = void;

            for (i = 0, len = 0; sbusDeviceTable[i].devId; i++) {
                len = cast(int)strlen(sbusDeviceTable[i].promName);
                if (!strncmp(sbusDeviceTable[i].promName, id, len)
                    && isdigit(id[len]))
                    break;
            }
            devId = sbusDeviceTable[i].devId;
            if (!devId)
                return False;
            i = atoi(id + len);
            for (psdpp = xf86SbusInfo; *psdpp; ++psdpp) {
                if ((*psdpp).devId != devId)
                    continue;
                if (!i) {
                    *fbNum = (*psdpp).fbNum;
                    return True;
                }
                i--;
            }
        }
        return False;
    }

    if (sparcPromInit() >= 0) {
        i = sparcPromPathname2Node(id);
        sparcPromClose();
        if (i) {
            sbusDevicePtr* psdpp = void;

            for (psdpp = xf86SbusInfo; *psdpp; ++psdpp) {
                if ((*psdpp).node.node == i) {
                    *fbNum = (*psdpp).fbNum;
                    return True;
                }
            }
        }
    }
    return False;
}

/*
 * Compare a BUS ID string with a SBUS bus id.  Return True if they match.
 */

private Bool xf86CompareSbusBusString(const(char)* busID, int fbNum)
{
    int iFbNum = void;

    if (xf86ParseSbusBusString(busID, &iFbNum)) {
        return fbNum == iFbNum;
    }
    else {
        return False;
    }
}

/*
 * Check if the slot requested is free.  If it is already in use, return False.
 */

private Bool xf86CheckSbusSlot(int fbNum)
{
    int i = void;
    EntityPtr p = void;

    for (i = 0; i < xf86NumEntities; i++) {
        p = xf86Entities[i];
        /* Check if this SBUS slot is taken */
        if (p.bus.type == BUS_SBUS && p.bus.id.sbus.fbNum == fbNum)
            return False;
    }

    return True;
}

/*
 * If the slot requested is already in use, return -1.
 * Otherwise, claim the slot for the screen requesting it.
 */

private int xf86ClaimSbusSlot(sbusDevicePtr psdp, DriverPtr drvp, GDevPtr dev, Bool active)
{
    EntityPtr p = void;

    int num = void;

    if (xf86CheckSbusSlot(psdp.fbNum)) {
        num = xf86AllocateEntity();
        p = xf86Entities[num];
        p.driver = drvp;
        p.chipset = -1;
        p.bus.type = BUS_SBUS;
        xf86AddDevToEntity(num, dev);
        p.bus.id.sbus.fbNum = psdp.fbNum;
        p.active = active;
        p.inUse = False;
        return num;
    }
    else
        return -1;
}

int xf86MatchSbusInstances(const(char)* driverName, int sbusDevId, GDevPtr* devList, int numDevs, DriverPtr drvp, int** foundEntities)
{
    int i = void, j = void;
    sbusDevicePtr psdp = void; sbusDevicePtr* psdpp = void;
    int numClaimedInstances = 0;
    int allocatedInstances = 0;
    int numFound = 0;
    GDevPtr devBus = null;
    GDevPtr dev = null;
    int* retEntities = null;
    int useProm = 0;

    struct Inst {
        sbusDevicePtr sbus = void;
        GDevPtr dev = void;
        Bool claimed = void;           /* BusID matches with a device section */
    }Inst* instances = null;

    *foundEntities = null;
    for (psdpp = xf86SbusInfo, psdp = *psdpp; psdp; psdp = *++psdpp) {
        if (psdp.devId != sbusDevId)
            continue;
        if (psdp.fd == -2)
            continue;
        ++allocatedInstances;
        instances = cast(Inst*)XNFreallocarray(instances,
                                    allocatedInstances, Inst.sizeof);
        instances[allocatedInstances - 1].sbus = psdp;
        instances[allocatedInstances - 1].dev = null;
        instances[allocatedInstances - 1].claimed = False;
        numFound++;
    }

    /*
     * This may be debatable, but if no SBUS devices with a matching vendor
     * type is found, return zero now.  It is probably not desirable to
     * allow the config file to override this.
     */
    if (allocatedInstances <= 0) {
        free(instances);
        return 0;
    }

    if (sparcPromInit() >= 0)
        useProm = 1;

    if (xf86DoConfigure && xf86DoConfigurePass1) {
        GDevPtr pGDev = void;
        int actualcards = 0;

        for (i = 0; i < allocatedInstances; i++) {
            actualcards++;
            pGDev = xf86AddBusDeviceToConfigure(drvp.driverName, BUS_SBUS,
                                                instances[i].sbus, -1);
            if (pGDev) {
                /*
                 * XF86Match???Instances() treat chipID and chipRev as
                 * overrides, so clobber them here.
                 */
                pGDev.chipID = pGDev.chipRev = -1;
            }
        }
        free(instances);
        if (useProm)
            sparcPromClose();
        return actualcards;
    }

    DebugF("%s instances found: %d\n", driverName, allocatedInstances);

    for (i = 0; i < allocatedInstances; i++) {
        char* promPath = null;

        psdp = instances[i].sbus;
        devBus = null;
        dev = null;
        if (useProm && psdp.node.node)
            promPath = sparcPromNode2Pathname(&psdp.node);

        for (j = 0; j < numDevs; j++) {
            if (devList[j].busID && *devList[j].busID) {
                if (xf86CompareSbusBusString(devList[j].busID, psdp.fbNum)) {
                    if (devBus)
                        LogMessageVerb(X_WARNING, 0,
                                      "%s: More than one matching Device section for "
                                      ~ "instance (BusID: %s) found: %s\n",
                                      driverName, devList[j].identifier,
                                      devList[j].busID);
                    else
                        devBus = devList[j];
                }
            }
            else {
                if (!dev && !devBus) {
                    if (promPath)
                        LogMessageVerb(X_PROBED, 1,
                                       "Assigning device section with no busID to SBUS:%s\n",
                                       promPath);
                    else
                        LogMessageVerb(X_PROBED, 1,
                                       "Assigning device section with no busID to SBUS:fb%d\n",
                                       psdp.fbNum);
                    dev = devList[j];
                }
                else
                    LogMessageVerb(X_WARNING, 0,
                                  "%s: More than one matching Device section "
                                  ~ "found: %s\n", driverName,
                                  devList[j].identifier);
            }
        }
        if (devBus)
            dev = devBus;       /* busID preferred */
        if (!dev && psdp.fd != -2) {
            if (promPath) {
                LogMessageVerb(X_WARNING, 0, "%s: No matching Device section "
                              ~ "for instance (BusID SBUS:%s) found\n",
                              driverName, promPath);
            }
            else
                LogMessageVerb(X_WARNING, 0, "%s: No matching Device section "
                              ~ "for instance (BusID SBUS:fb%d) found\n",
                              driverName, psdp.fbNum);
        }
        else if (dev) {
            numClaimedInstances++;
            instances[i].claimed = True;
            instances[i].dev = dev;
        }
        free(promPath);
    }

    DebugF("%s instances found: %d\n", driverName, numClaimedInstances);

    /*
     * Of the claimed instances, check that another driver hasn't already
     * claimed its slot.
     */
    numFound = 0;
    for (i = 0; i < allocatedInstances && numClaimedInstances > 0; i++) {
        if (!instances[i].claimed)
            continue;
        psdp = instances[i].sbus;
        if (!xf86CheckSbusSlot(psdp.fbNum))
            continue;

        DebugF("%s: card at fb%d %08x is claimed by a Device section\n",
               driverName, psdp.fbNum, psdp.node.node);

        /* Allocate an entry in the lists to be returned */
        numFound++;
        retEntities = cast(int*) XNFreallocarray(retEntities, numFound, int.sizeof);
        retEntities[numFound - 1]
            = xf86ClaimSbusSlot(psdp, drvp, instances[i].dev,
                                instances[i].dev.active ? True : False);
    }
    free(instances);
    if (numFound > 0) {
        *foundEntities = retEntities;
    }

    if (useProm)
        sparcPromClose();

    return numFound;
}

/*
 * xf86GetSbusInfoForEntity() -- Get the sbusDevicePtr of entity.
 */
sbusDevicePtr xf86GetSbusInfoForEntity(int entityIndex)
{
    sbusDevicePtr* psdpp = void;
    EntityPtr p = xf86Entities[entityIndex];

    if (entityIndex >= xf86NumEntities || p.bus.type != BUS_SBUS)
        return null;

    for (psdpp = xf86SbusInfo; *psdpp !is null; psdpp++) {
        if (p.bus.id.sbus.fbNum == (*psdpp).fbNum)
            return *psdpp;
    }
    return null;
}

void xf86SbusUseBuiltinMode(ScrnInfoPtr pScrn, sbusDevicePtr psdp)
{
    DisplayModePtr mode = void;

    mode = cast(_DisplayModeRec*)XNFcallocarray(DisplayModeRec.sizeof, 1);
    mode.name = "current";
    mode.next = mode;
    mode.prev = mode;
    mode.type = M_T_BUILTIN;
    mode.Clock = 100000000;
    mode.HDisplay = psdp.width;
    mode.HSyncStart = psdp.width;
    mode.HSyncEnd = psdp.width;
    mode.HTotal = psdp.width;
    mode.VDisplay = psdp.height;
    mode.VSyncStart = psdp.height;
    mode.VSyncEnd = psdp.height;
    mode.VTotal = psdp.height;
    mode.SynthClock = mode.Clock;
    mode.CrtcHDisplay = mode.HDisplay;
    mode.CrtcHSyncStart = mode.HSyncStart;
    mode.CrtcHSyncEnd = mode.HSyncEnd;
    mode.CrtcHTotal = mode.HTotal;
    mode.CrtcVDisplay = mode.VDisplay;
    mode.CrtcVSyncStart = mode.VSyncStart;
    mode.CrtcVSyncEnd = mode.VSyncEnd;
    mode.CrtcVTotal = mode.VTotal;
    mode.CrtcHAdjusted = False;
    mode.CrtcVAdjusted = False;
    pScrn.modes = mode;
    pScrn.virtualX = psdp.width;
    pScrn.virtualY = psdp.height;
}

private DevPrivateKeyRec sbusPaletteKeyRec;
enum sbusPaletteKey = (&sbusPaletteKeyRec);

struct _sbusCmap {
    sbusDevicePtr psdp;
    Bool origCmapValid;
    ubyte[16] origRed;
    ubyte[16] origGreen;
    ubyte[16] origBlue;
}alias sbusCmapRec = _sbusCmap;
alias sbusCmapPtr = _sbusCmap*;

enum string SBUSCMAPPTR(string pScreen) = `(cast(sbusCmapPtr) 
    dixLookupPrivate(&(` ~ pScreen ~ `).devPrivates, sbusPaletteKey))`;

private void xf86SbusCmapLoadPalette(ScrnInfoPtr pScrn, int numColors, int* indices, LOCO* colors, VisualPtr pVisual)
{
    int i = void, index = void;
    sbusCmapPtr cmap = void;
    fbcmap fbcmap = void;
    ubyte* data = void;

    cmap = mixin(SBUSCMAPPTR!(`pScrn.pScreen`));
    if (!cmap)
        return;
    fbcmap.count = 0;
    fbcmap.index = indices[0];
    fbcmap.red = data = cast(ubyte*) calloc(numColors, 3);
    if (!data)
        return;
    fbcmap.green = data + numColors;
    fbcmap.blue = fbcmap.green + numColors;
    for (i = 0; i < numColors; i++) {
        index = indices[i];
        if (fbcmap.count && index != fbcmap.index + fbcmap.count) {
            ioctl(cmap.psdp.fd, FBIOPUTCMAP, &fbcmap);
            fbcmap.count = 0;
            fbcmap.index = index;
        }
        fbcmap.red[fbcmap.count] = cast(ubyte)colors[index].red;
        fbcmap.green[fbcmap.count] = cast(ubyte)colors[index].green;
        fbcmap.blue[fbcmap.count++] = cast(ubyte)colors[index].blue;
    }
    ioctl(cmap.psdp.fd, FBIOPUTCMAP, &fbcmap);
    free(data);
}

private void xf86SbusCmapCloseScreen(CallbackListPtr* pcbl, ScreenPtr pScreen, void* unused)
{
    sbusCmapPtr cmap = void;
    fbcmap fbcmap = void;

    // dixScreenUnhook(pScreen, xf86SbusCmapCloseScreen);

    cmap = mixin(SBUSCMAPPTR!(`pScreen`));
    if (!cmap)
        return;

    if (cmap.origCmapValid) {
        fbcmap.index = 0;
        fbcmap.count = 16;
        fbcmap.red = cmap.origRed.ptr;
        fbcmap.green = cmap.origGreen.ptr;
        fbcmap.blue = cmap.origBlue.ptr;
        ioctl(cmap.psdp.fd, FBIOPUTCMAP, &fbcmap);
    }
    free(cmap);
    dixSetPrivate(&pScreen.devPrivates, sbusPaletteKey, null);
}

Bool xf86SbusHandleColormaps(ScreenPtr pScreen, sbusDevicePtr psdp)
{
    sbusCmapPtr cmap = void;
    fbcmap fbcmap = void;
    ubyte[2] data = void;

    if (!dixRegisterPrivateKey(sbusPaletteKey, PRIVATE_SCREEN, 0))
        FatalError("Cannot register sbus private key");

    cmap = cast(sbusCmapRec*)XNFcallocarray(1, sbusCmapRec.sizeof);
    dixSetPrivate(&pScreen.devPrivates, sbusPaletteKey, cmap);
    cmap.psdp = psdp;
    fbcmap.index = 0;
    fbcmap.count = 16;
    fbcmap.red = cmap.origRed.ptr;
    fbcmap.green = cmap.origGreen.ptr;
    fbcmap.blue = cmap.origBlue.ptr;
    if (ioctl(psdp.fd, FBIOGETCMAP, &fbcmap) >= 0)
        cmap.origCmapValid = True;
    fbcmap.index = 0;
    fbcmap.count = 2;
    fbcmap.red = data.ptr;
    fbcmap.green = data.ptr;
    fbcmap.blue = data.ptr;
    if (pScreen.whitePixel == 0) {
        data[0] = 255;
        data[1] = 0;
    }
    else {
        data[0] = 0;
        data[1] = 255;
    }
    ioctl(psdp.fd, FBIOPUTCMAP, &fbcmap);
    dixScreenHookClose(pScreen, &xf86SbusCmapCloseScreen);
    return xf86HandleColormaps(pScreen, 256, 8,
                               &xf86SbusCmapLoadPalette, null, 0);
}

Bool xf86SbusConfigure(void* busData, sbusDevicePtr sBus)
{
    if (sBus && sBus.fbNum == (cast(sbusDevicePtr) busData).fbNum)
        return 0;
    return 1;
}

void xf86SbusConfigureNewDev(void* busData, sbusDevicePtr sBus, GDevRec* GDev)
{
    char* promPath = null;
    char* tmp = void;

    sBus = cast(sbusDevicePtr) busData;
    GDev.identifier = sBus.descr;
    if (sparcPromInit() >= 0) {
        promPath = sparcPromNode2Pathname(&sBus.node);
        sparcPromClose();
    }
    if (promPath) {
        XNFasprintf(&tmp, "SBUS:%s", promPath);
        free(promPath);
    }
    else {
        XNFasprintf(&tmp, "SBUS:fb%d", sBus.fbNum);
    }
    GDev.busID = tmp;
}
