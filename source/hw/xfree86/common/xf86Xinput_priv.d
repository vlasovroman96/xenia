module xf86Xinput_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
import include.xf86;

// InputInfoPtr xf86InputDevs;

int xf86NewInputDevice(InputInfoPtr pInfo, DeviceIntPtr* pdev, BOOL is_auto);
// InputInfoPtr xf86AllocateInput();

// void xf86InputEnableVTProbe();

// InputDriverPtr xf86LookupInputDriver(const(char)* name);

InputInfoPtr xf86LookupInput(const(char)* name);

// void xf86AddInputEventDrainCallback(CallbackProcPtr callback, void* param);

// void xf86RemoveInputEventDrainCallback(CallbackProcPtr callback, void* param);

// Bool MatchAttrToken(const(char)* attr, xorg_list* groups);

 /* _XSERVER__XF86XINPUT_H */
