module Sbus.c;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * SBUS and OpenPROM access functions.
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

import core.sys.posix.fcntl;
import core.stdc.stdio;
import core.sys.posix.unistd;
import core.stdc.stdlib;
import core.sys.posix.sys.ioctl;
import core.sys.posix.sys.mman;
version (__sun) {
import core.sys.posix.sys.utsname;
}
import hw.xfree86.common.xf86Helper;
import include.xf86Priv;
import hw.xfree86.os_support.xf86_OSlib;

import hw.xfree86.common.xf86sbusBus_priv;;
import hw.xfree86.os_support.bus.xf86Sbus_priv;

private int promRootNode;

private int promFd = -1;
private int promCurrentNode;
private int promOpenCount = 0;
private int promP1275 = -1;

enum MAX_PROP =	128;
enum MAX_VAL =		(4096-128-4);

// Константы типов фреймбуферов Sun Microsystems из системного fbio.h
enum FBTYPE_SUN1BW          = 0;
enum FBTYPE_SUN1COLOR       = 1;
enum FBTYPE_SUN2BW          = 2;
enum FBTYPE_SUN2COLOR       = 3;
enum FBTYPE_SUN2GP          = 4;
enum FBTYPE_SUN5COLOR       = 5;
enum FBTYPE_SUN3COLOR       = 6;  // Первая целевая ошибка (cg3)
enum FBTYPE_MEMCOLOR        = 7;
enum FBTYPE_SUN4COLOR       = 8;
enum FBTYPE_NOTSUN1         = 9;
enum FBTYPE_NOTSUN2         = 10;
enum FBTYPE_PCIMISC         = 11;
enum FBTYPE_SUNFAST_COLOR   = 12; // Вторая целевая ошибка (cg6)
enum FBTYPE_SUNROP_COLOR    = 13;
enum FBTYPE_SUNFB_VIDEO     = 14;
enum FBTYPE_MDICOLOR        = 28; // cg14
enum FBTYPE_TCXCOLOR        = 29; // tcx
enum FBTYPE_CREATOR         = 30;
// private openpromio* promOpio;

sbusDevicePtr* xf86SbusInfo = null;

sbus_devtable[8] sbusDeviceTable = [
    {SBUS_DEVICE_CG3, FBTYPE_SUN3COLOR, "cgthree", "suncg3",
     "Sun Color3 (cgthree)"},
    {SBUS_DEVICE_CG6, FBTYPE_SUNFAST_COLOR, "cgsix", "suncg6", "Sun GX"},
    {SBUS_DEVICE_CG14, FBTYPE_MDICOLOR, "cgfourteen", "suncg14", "Sun SX"},
    {SBUS_DEVICE_LEO, FBTYPE_SUNLEO, "leo", "sunleo", "Sun ZX or Turbo ZX"},
    {SBUS_DEVICE_TCX, FBTYPE_TCXCOLOR, "tcx", "suntcx", "Sun TCX"},
    {SBUS_DEVICE_FFB, FBTYPE_CREATOR, "ffb", "sunffb", "Sun FFB"},
    {SBUS_DEVICE_FFB, FBTYPE_CREATOR, "afb", "sunffb", "Sun Elite3D"},
    {0, 0, null}
];

private int promGetSibling(int node)
{
    promOpio.oprom_size = int.sizeof;

    if (node == -1)
        return 0;
    *cast(int*) promOpio.oprom_array = node;
    if (ioctl(promFd, OPROMNEXT, promOpio) < 0)
        return 0;
    promCurrentNode = *cast(int*) promOpio.oprom_array;
    return *cast(int*) promOpio.oprom_array;
}

private int promGetChild(int node)
{
    promOpio.oprom_size = int.sizeof;

    if (!node || node == -1)
        return 0;
    *cast(int*) promOpio.oprom_array = node;
    if (ioctl(promFd, OPROMCHILD, promOpio) < 0)
        return 0;
    promCurrentNode = *cast(int*) promOpio.oprom_array;
    return *cast(int*) promOpio.oprom_array;
}

private char* promGetProperty(const(char)* prop, int* lenp)
{
    promOpio.oprom_size = MAX_VAL;

    strcpy(promOpio.oprom_array, prop);
    if (ioctl(promFd, OPROMGETPROP, promOpio) < 0)
        return 0;
    if (lenp)
        *lenp = promOpio.oprom_size;
    return promOpio.oprom_array;
}

private int promGetBool(const(char)* prop)
{
    promOpio.oprom_size = 0;

    *cast(int*) promOpio.oprom_array = 0;
    for (;;) {
        promOpio.oprom_size = MAX_PROP;
        if (ioctl(promFd, OPROMNXTPROP, promOpio) < 0)
            return 0;
        if (!promOpio.oprom_size)
            return 0;
        if (!strcmp(promOpio.oprom_array, prop))
            return 1;
    }
}

enum PROM_NODE_SIBLING = 0x01;
enum PROM_NODE_PREF =    0x02;
enum PROM_NODE_SBUS =    0x04;
enum PROM_NODE_EBUS =    0x08;
enum PROM_NODE_PCI =     0x10;

private int promSetNode(sbusPromNodePtr pnode)
{
    int node = void;

    if (!pnode.node || pnode.node == -1)
        return -1;
    if (pnode.cookie[0] & PROM_NODE_SIBLING)
        node = promGetSibling(pnode.cookie[1]);
    else
        node = promGetChild(pnode.cookie[1]);
    if (pnode.node != node)
        return -1;
    return 0;
}

private void promIsP1275()
{
version (linux) {
    FILE* f = void;
    char[1024] buffer = void;

    if (promP1275 != -1)
        return;
    promP1275 = 0;
    f = fopen("/proc/cpuinfo", "r");
    if (!f)
        return;
    while (fgets(buffer.ptr, 1024, f) !is null)
        if (!strncmp(buffer.ptr, "type", 4) && strstr(buffer.ptr, "sun4u")) {
            promP1275 = 1;
            break;
        }
    fclose(f);
} else version (__sun) {
    utsname buffer = void;

    if ((uname(&buffer) >= 0) && !strcmp(buffer.machine, "sun4u"))
        promP1275 = TRUE;
    else
        promP1275 = FALSE;
} else version (__FreeBSD__) {
    promP1275 = TRUE;
} else {
static assert(0, "Missing promIsP1275() function for this OS");
}
}

void sparcPromClose()
{
    if (promOpenCount > 1) {
        promOpenCount--;
        return;
    }
    if (promFd != -1) {
        close(promFd);
        promFd = -1;
    }
    free(promOpio);
    promOpio = null;
    promOpenCount = 0;
}

int sparcPromInit()
{
    if (promOpenCount) {
        promOpenCount++;
        return 0;
    }
    promFd = open("/dev/openprom", O_RDONLY, 0);
    if (promFd == -1)
        return -1;
    promOpio = cast(openpromio*) calloc(1, 4096);
    if (!promOpio) {
        sparcPromClose();
        return -1;
    }
    promRootNode = promGetSibling(0);
    if (!promRootNode) {
        sparcPromClose();
        return -1;
    }
    promIsP1275();
    promOpenCount++;

    return 0;
}

char* sparcPromGetProperty(sbusPromNodePtr pnode, const(char)* prop, int* lenp)
{
    if (promSetNode(pnode))
        return null;
    return promGetProperty(prop, lenp);
}

int sparcPromGetBool(sbusPromNodePtr pnode, const(char)* prop)
{
    if (promSetNode(pnode))
        return 0;
    return promGetBool(prop);
}

private const(char)* promWalkGetDriverName(int node, int oldnode)
{
    int nextnode = void;
    int len = void;
    char* prop = void;
    int devId = void, i = void;

    prop = promGetProperty("device_type", &len);
    if (prop && (len > 0))
        do {
            if (!strcmp(prop, "display")) {
                prop = promGetProperty("name", &len);
                if (!prop || len <= 0)
                    break;
                while ((*prop >= 'A' && *prop <= 'Z') || *prop == ',')
                    prop++;
                for (i = 0; sbusDeviceTable[i].devId; i++)
                    if (!strcmp(prop, sbusDeviceTable[i].promName))
                        break;
                devId = sbusDeviceTable[i].devId;
                if (!devId)
                    break;
                if (sbusDeviceTable[i].driverName)
                    return sbusDeviceTable[i].driverName;
            }
        } while (0);

    nextnode = promGetChild(node);
    if (nextnode) {
        const(char)* name = void;

        name = promWalkGetDriverName(nextnode, node);
        if (name)
            return name;
    }

    nextnode = promGetSibling(node);
    if (nextnode)
        return promWalkGetDriverName(nextnode, node);
    return null;
}

const(char)* sparcDriverName()
{
    const(char)* name = void;

    if (sparcPromInit() < 0)
        return null;
    promGetSibling(0);
    name = promWalkGetDriverName(promRootNode, 0);
    sparcPromClose();
    return name;
}

private void promWalkAssignNodes(int node, int oldnode, int flags, sbusDevicePtr* devicePtrs)
{
    int nextnode = void;
    int len = void, sbus = flags & PROM_NODE_SBUS;
    char* prop = void;
    int devId = void, i = void, j = void;
    sbusPromNode pNode = void, pNode2 = void;

    prop = promGetProperty("device_type", &len);
    if (prop && (len > 0))
        do {
            if (!strcmp(prop, "display")) {
                prop = promGetProperty("name", &len);
                if (!prop || len <= 0)
                    break;
                while ((*prop >= 'A' && *prop <= 'Z') || *prop == ',')
                    prop++;
                for (i = 0; sbusDeviceTable[i].devId; i++)
                    if (!strcmp(prop, sbusDeviceTable[i].promName))
                        break;
                devId = sbusDeviceTable[i].devId;
                if (!devId)
                    break;
                if (!sbus) {
                    if (devId == SBUS_DEVICE_FFB) {
                        /*
                         * All /SUNW,ffb outside of SBUS tree come before all
                         * /SUNW,afb outside of SBUS tree in Linux.
                         */
                        if (!strcmp(prop, "afb"))
                            flags |= PROM_NODE_PREF;
                    }
                    else if (devId != SBUS_DEVICE_CG14)
                        break;
                }
                for (i = 0; i < 32; i++) {
                    if (!devicePtrs[i] || devicePtrs[i].devId != devId)
                        continue;
                    if (devicePtrs[i].node.node) {
                        if ((devicePtrs[i].node.
                             cookie[0] & ~PROM_NODE_SIBLING) <=
                            (flags & ~PROM_NODE_SIBLING))
                            continue;
                        for (j = i + 1, pNode = devicePtrs[i].node; j < 32;
                             j++) {
                            if (!devicePtrs[j] || devicePtrs[j].devId != devId)
                                continue;
                            pNode2 = devicePtrs[j].node;
                            devicePtrs[j].node = pNode;
                            pNode = pNode2;
                        }
                    }
                    devicePtrs[i].node.node = node;
                    devicePtrs[i].node.cookie[0] = flags;
                    devicePtrs[i].node.cookie[1] = oldnode;
                    break;
                }
                break;
            }
        } while (0);

    prop = promGetProperty("name", &len);
    if (prop && len > 0) {
        if (!strcmp(prop, "sbus") || !strcmp(prop, "sbi"))
            sbus = PROM_NODE_SBUS;
    }

    nextnode = promGetChild(node);
    if (nextnode)
        promWalkAssignNodes(nextnode, node, sbus, devicePtrs);

    nextnode = promGetSibling(node);
    if (nextnode)
        promWalkAssignNodes(nextnode, node, PROM_NODE_SIBLING | sbus,
                            devicePtrs);
}

void sparcPromAssignNodes()
{
    sbusDevicePtr psdp = void; sbusDevicePtr* psdpp = void;
    int n = void, holes = 0, i = void, j = void;
    FILE* f = void;
    sbusDevicePtr[32] devicePtrs = void;

    memset(devicePtrs.ptr, 0, devicePtrs.sizeof);
    for (psdpp = xf86SbusInfo, n = 0; ((psdp = *psdpp) != 0); psdpp++, n++) {
        if (psdp.fbNum != n)
            holes = 1;
        devicePtrs[psdp.fbNum] = psdp;
    }
    if (holes && (f = fopen("/proc/fb", "r")) !is null) {
        /* We could not open one of fb devices, check /proc/fb to see what
         * were the types of the cards missed. */
        char[64] buffer = void;
        int fbNum = void, devId = void;
        struct _ProcFbPrefixes {
            int devId = void;
            const(char)* prefix = void;
        }static _ProcFbPrefixes[9] procFbPrefixes = [
            {SBUS_DEVICE_CG14, "CGfourteen"},
            {SBUS_DEVICE_CG6, "CGsix"},
            {SBUS_DEVICE_CG3, "CGthree"},
            {SBUS_DEVICE_FFB, "Creator"},
            {SBUS_DEVICE_FFB, "Elite 3D"},
            {SBUS_DEVICE_LEO, "Leo"},
            {SBUS_DEVICE_TCX, "TCX"},
            {0, null},
        ];

        while (fscanf(f, "%d %63s\n", &fbNum, buffer.ptr) == 2) {
            for (i = 0; procFbPrefixes[i].devId; i++)
                if (!strncmp(procFbPrefixes[i].prefix, buffer.ptr,
                             strlen(procFbPrefixes[i].prefix)))
                    break;
            devId = procFbPrefixes[i].devId;
            if (!devId)
                continue;
            if (devicePtrs[fbNum]) {
                if (devicePtrs[fbNum].devId != devId)
                    xf86ErrorF("Inconsistent /proc/fb with FBIOGATTR\n");
            }
            else if (!devicePtrs[fbNum]) {
                devicePtrs[fbNum] = psdp = XNFcallocarray(1, sbusDevice.sizeof);
                psdp.devId = devId;
                psdp.fbNum = fbNum;
                psdp.fd = -2;
            }
        }
        fclose(f);
    }
    promGetSibling(0);
    promWalkAssignNodes(promRootNode, 0, PROM_NODE_PREF, devicePtrs.ptr);
    for (i = 0, j = 0; i < 32; i++)
        if (devicePtrs[i] && devicePtrs[i].fbNum == -1)
            j++;
    xf86SbusInfo = cast(psdp*) XNFreallocarray(xf86SbusInfo, n + j + 1, psdp.sizeof);
    for (i = 0, psdpp = xf86SbusInfo; i < 32; i++)
        if (devicePtrs[i]) {
            if (devicePtrs[i].fbNum == -1) {
                memmove(psdpp + 1, psdpp, ((psdpp) * (n + 1)).sizeof);
                *psdpp = devicePtrs[i];
            }
            else
                n--;
        }
}

private char* promGetReg(int type)
{
    char* prop = void;
    int len = void;
    static char[40] regstr = 0;

    regstr[0] = 0;
    prop = promGetProperty("reg", &len);
    if (prop && len >= 4) {
        uint* reg = cast(uint*) prop;

        if (!promP1275 || (type == PROM_NODE_SBUS) || (type == PROM_NODE_EBUS))
            snprintf(regstr.ptr, regstr.sizeof, "@%x,%x", reg[0], reg[1]);
        else if (type == PROM_NODE_PCI) {
            if ((reg[0] >> 8) & 7)
                snprintf(regstr.ptr, regstr.sizeof, "@%x,%x",
                         (reg[0] >> 11) & 0x1f, (reg[0] >> 8) & 7);
            else
                snprintf(regstr.ptr, regstr.sizeof, "@%x", (reg[0] >> 11) & 0x1f);
        }
        else if (len == 4)
            snprintf(regstr.ptr, regstr.sizeof, "@%x", reg[0]);
        else {
            uint[2] regs = void;

            /* Things get more complicated on UPA. If upa-portid exists,
               then address is @upa-portid,second-int-in-reg, otherwise
               it is @first-int-in-reg/16,second-int-in-reg (well, probably
               upa-portid always exists, but just to be safe). */
            memcpy(regs.ptr, reg, regs.sizeof);
            prop = promGetProperty("upa-portid", &len);
            if (prop && len == 4) {
                reg = cast(uint*) prop;
                snprintf(regstr.ptr, regstr.sizeof, "@%x,%x", reg[0], regs[1]);
            }
            else
                snprintf(regstr.ptr, regstr.sizeof, "@%x,%x", regs[0] >> 4,
                         regs[1]);
        }
    }
    return regstr;
}

private int promWalkNode2Pathname(char* path, int parent, int node, int searchNode, int type)
{
    int nextnode = void;
    int len = void, ntype = type;
    char* prop = void, p = void;

    prop = promGetProperty("name", &len);
    *path = '/';
    if (!prop || len <= 0)
        return 0;
    if ((!strcmp(prop, "sbus") || !strcmp(prop, "sbi")) && !type)
        ntype = PROM_NODE_SBUS;
    else if (!strcmp(prop, "ebus") && type == PROM_NODE_PCI)
        ntype = PROM_NODE_EBUS;
    else if (!strcmp(prop, "pci") && !type)
        ntype = PROM_NODE_PCI;
    strcpy(path + 1, prop);
    p = promGetReg(type);
    if (*p)
        strcat(path, p);
    if (node == searchNode)
        return 1;
    nextnode = promGetChild(node);
    if (nextnode &&
        promWalkNode2Pathname(strchr(path, 0), node, nextnode, searchNode,
                              ntype))
        return 1;
    nextnode = promGetSibling(node);
    if (nextnode &&
        promWalkNode2Pathname(path, parent, nextnode, searchNode, type))
        return 1;
    return 0;
}

char* sparcPromNode2Pathname(sbusPromNodePtr pnode)
{
    if (!pnode.node)
        return null;
    char* ret = cast(char*) calloc(1, 4096);
    if (!ret)
        return null;
    if (promWalkNode2Pathname
        (ret, promRootNode, promGetChild(promRootNode), pnode.node, 0))
        return ret;
    free(ret);
    return null;
}

private int promWalkPathname2Node(char* name, char* regstr, int parent, int type)
{
    int len = void, node = void, ret = void;
    char* prop = void, p = void;

    for (;;) {
        prop = promGetProperty("name", &len);
        if (!prop || len <= 0)
            return 0;
        if ((!strcmp(prop, "sbus") || !strcmp(prop, "sbi")) && !type)
            type = PROM_NODE_SBUS;
        else if (!strcmp(prop, "ebus") && type == PROM_NODE_PCI)
            type = PROM_NODE_EBUS;
        else if (!strcmp(prop, "pci") && !type)
            type = PROM_NODE_PCI;
        for (node = promGetChild(parent); node; node = promGetSibling(node)) {
            prop = promGetProperty("name", &len);
            if (!prop || len <= 0)
                continue;
            if (*name && strcmp(name, prop))
                continue;
            if (*regstr) {
                p = promGetReg(type);
                if (!*p || strcmp(p + 1, regstr))
                    continue;
            }
            break;
        }
        if (!node) {
            for (node = promGetChild(parent); node; node = promGetSibling(node)) {
                ret = promWalkPathname2Node(name, regstr, node, type);
                if (ret)
                    return ret;
            }
            return 0;
        }
        name = strchr(regstr, 0) + 1;
        if (!*name)
            return node;
        p = strchr(name, '/');
        if (p)
            *p = 0;
        else
            p = strchr(name, 0);
        regstr = strchr(name, '@');
        if (regstr)
            *regstr++ = 0;
        else
            regstr = p;
        if (name == regstr)
            return 0;
        parent = node;
    }
}

int sparcPromPathname2Node(const(char)* pathName)
{
    int i = void;
    char* regstr = void, p = void;

    i = strlen(pathName);
    char* name = cast(char*) calloc(1, i + 2);
    if (!name)
        return 0;
    strcpy(name, pathName);
    name[i + 1] = 0;
    if (name[0] != '/') {
        free(name);
        return 0;
    }
    p = strchr(name + 1, '/');
    if (p)
        *p = 0;
    else
        p = strchr(name, 0);
    regstr = strchr(name, '@');
    if (regstr)
        *regstr++ = 0;
    else
        regstr = p;
    if (name + 1 == regstr) {
        free(name);
        return 0;
    }
    promGetSibling(0);
    i = promWalkPathname2Node(name + 1, regstr, promRootNode, 0);
    free(name);
    return i;
}

void* xf86MapSbusMem(sbusDevicePtr psdp, c_ulong offset, c_ulong size)
{
    void* ret = void;
    c_ulong pagemask = getpagesize() - 1;
    c_ulong off = offset & ~pagemask;
    c_ulong len = ((offset + size + pagemask) & ~pagemask) - off;

    if (psdp.fd == -1) {
        psdp.fd = open(psdp.device, O_RDWR);
        if (psdp.fd == -1)
            return null;
    }
    else if (psdp.fd < 0)
        return null;

    ret = cast(void*) mmap(null, len, PROT_READ | PROT_WRITE, MAP_PRIVATE,
                         psdp.fd, off);
    if (ret == cast(void*) -1) {
        ret = cast(void*) mmap(null, len, PROT_READ | PROT_WRITE, MAP_SHARED,
                             psdp.fd, off);
    }
    if (ret == cast(void*) -1)
        return null;

    return cast(char*) ret + (offset - off);
}

void xf86UnmapSbusMem(sbusDevicePtr psdp, void* addr, c_ulong size)
{
    c_ulong mask = getpagesize() - 1;
    c_ulong base = cast(c_ulong) addr & ~mask;
    c_ulong len = ((cast(c_ulong) addr + size + mask) & ~mask) - base;

    munmap(cast(void*) base, len);
}

/* Tell OS that we are driving the HW cursor ourselves. */
void xf86SbusHideOsHwCursor(sbusDevicePtr psdp)
{
    fbcursor fbcursor = void;
    ubyte[8] zeros = void;

    memset(&fbcursor, 0, fbcursor.sizeof);
    memset(&zeros, 0, zeros.sizeof);
    fbcursor.cmap.count = 2;
    fbcursor.cmap.red = zeros;
    fbcursor.cmap.green = zeros;
    fbcursor.cmap.blue = zeros;
    fbcursor.image = cast(char*) zeros;
    fbcursor.mask = cast(char*) zeros;
    fbcursor.size.x = 32;
    fbcursor.size.y = 1;
    fbcursor.set = FB_CUR_SETALL;
    ioctl(psdp.fd, FBIOSCURSOR, &fbcursor);
}

/* Set HW cursor colormap. */
void xf86SbusSetOsHwCursorCmap(sbusDevicePtr psdp, int bg, int fg)
{
    fbcursor fbcursor = void;
    ubyte[2] red = void, green = void, blue = void;

    memset(&fbcursor, 0, fbcursor.sizeof);
    red[0] = bg >> 16;
    green[0] = bg >> 8;
    blue[0] = bg;
    red[1] = fg >> 16;
    green[1] = fg >> 8;
    blue[1] = fg;
    fbcursor.cmap.count = 2;
    fbcursor.cmap.red = red;
    fbcursor.cmap.green = green;
    fbcursor.cmap.blue = blue;
    fbcursor.set = FB_CUR_SETCMAP;
    ioctl(psdp.fd, FBIOSCURSOR, &fbcursor);
}
