module xkb.xkb_procs;
@nogc nothrow:
extern(C): __gshared:

import common.xlibre_ptrtypes;
 
int ProcXkbUseExtension(ClientPtr client);
int ProcXkbSelectEvents(ClientPtr client);
int ProcXkbBell(ClientPtr client);
int ProcXkbGetState(ClientPtr client);
int ProcXkbLatchLockState(ClientPtr client);
int ProcXkbGetControls(ClientPtr client);
int ProcXkbSetControls(ClientPtr client);
int ProcXkbGetMap(ClientPtr client);
int ProcXkbSetMap(ClientPtr client);
int ProcXkbGetCompatMap(ClientPtr client);
int ProcXkbSetCompatMap(ClientPtr client);
int ProcXkbGetIndicatorState(ClientPtr client);
int ProcXkbGetIndicatorMap(ClientPtr client);
int ProcXkbSetIndicatorMap(ClientPtr client);
int ProcXkbGetNamedIndicator(ClientPtr client);
int ProcXkbSetNamedIndicator(ClientPtr client);
int ProcXkbGetNames(ClientPtr client);
int ProcXkbSetNames(ClientPtr client);
int ProcXkbGetGeometry(ClientPtr client);
int ProcXkbSetGeometry(ClientPtr client);
int ProcXkbPerClientFlags(ClientPtr client);
int ProcXkbListComponents(ClientPtr client);
int ProcXkbGetKbdByName(ClientPtr client);
int ProcXkbGetDeviceInfo(ClientPtr client);
int ProcXkbSetDeviceInfo(ClientPtr client);
int ProcXkbSetDebuggingFlags(ClientPtr client);


