module dix.registry_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import dix.extension;
public import dix.resource;
import x11.Xdefs;

/*
 * Result returned from any unsuccessful lookup
 */
enum XREGISTRY_UNKNOWN = "<unknown>";

/*
 * Setup and teardown
 */
void dixResetRegistry();
void dixFreeRegistry();
void dixCloseRegistry();

/* Functions used by the X-Resource extension */
// void RegisterResourceName(RESTYPE type, const(char)* name);
// const(char)* LookupResourceName(RESTYPE rtype);

void RegisterExtensionNames(_ExtensionEntry* ext);

/*
 * Lookup functions.  The returned string must not be modified or freed.
 */
// const(char)* LookupMajorName(int major);
// const(char)* LookupRequestName(int major, int minor);
// const(char)* LookupEventName(int event);
// const(char)* LookupErrorName(int error);

void LookupDixAccessName(Mask acc, char* buf, int sz);

 /* _XSERVER_DIX_REGISTRY_H */
