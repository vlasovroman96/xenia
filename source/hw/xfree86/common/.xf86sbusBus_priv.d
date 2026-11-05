module hw.xfree86.common.xf86sbusBus_priv;;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 2000 Jakub Jelinek (jakub@redhat.com)
 */
 
public import x11.Xdefs;

public import xf86sbusBus;

struct sbus_devtable {
    int devId;
    int fbType;
    const(char)* promName;
    const(char)* driverName;
    const(char)* descr;
}

// sbusDevicePtr* xf86SbusInfo;
// sbus_devtable[1] sbusDeviceTable;

Bool xf86SbusConfigure(void* busData, sbusDevicePtr sBus);
void xf86SbusConfigureNewDev(void* busData, sbusDevicePtr sBus, GDevRec* GDev);
void xf86SbusProbe();

// char* sparcPromGetProperty(sbusPromNodePtr pnode, const(char)* prop, int* lenp);
// void sparcPromAssignNodes();
// char* sparcPromNode2Pathname(sbusPromNodePtr pnode);
// int sparcPromPathname2Node(const(char)* pathName);
const(char)* sparcDriverName();

 /* _XSERVER_XF86_SBUSBUS_H */
