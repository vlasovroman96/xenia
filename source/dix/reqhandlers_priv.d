module dix.reqhandlers_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
public import os.os;


/*
 * prototypes for various X11 request handlers
 *
 * those should only be called by the dispatcher
 */

/* events.c */
// XRetCode ProcAllowEvents(ClientPtr pClient);
// XRetCode ProcChangeActivePointerGrab(ClientPtr pClient);
// XRetCode ProcGrabButton(ClientPtr pClient);
// XRetCode ProcGetInputFocus(ClientPtr pClient);
// XRetCode ProcGrabKey(ClientPtr pClient);
// XRetCode ProcGrabKeyboard(ClientPtr pClient);
// XRetCode ProcGrabPointer(ClientPtr pClient);
// XRetCode ProcQueryPointer(ClientPtr pClient);
// XRetCode ProcRecolorCursor(ClientPtr pClient);
// XRetCode ProcSendEvent(ClientPtr pClient);
// XRetCode ProcSetInputFocus(ClientPtr pClient);
// XRetCode ProcUngrabButton(ClientPtr pClient);
// XRetCode ProcUngrabKey(ClientPtr pClient);
// XRetCode ProcUngrabKeyboard(ClientPtr pClient);
// XRetCode ProcUngrabPointer(ClientPtr pClient);
// XRetCode ProcWarpPointer(ClientPtr pClient);

// XRetCode SProcChangeActivePointerGrab(ClientPtr pClient);
// XRetCode SProcGrabKey(ClientPtr pClient);
// XRetCode SProcGrabKeyboard(ClientPtr pClient);
// XRetCode SProcRecolorCursor(ClientPtr pClient);
// XRetCode SProcSetInputFocus(ClientPtr pClient);
// // XRetCode SProcSendEvent(ClientPtr pClient);
// XRetCode SProcUngrabButton(ClientPtr pClient);
// XRetCode SProcUngrabKey(ClientPtr pClient);
// XRetCode SProcUngrabKeyboard(ClientPtr pClient);
// XRetCode SProcWarpPointer(ClientPtr pClient);

 /* _XSERVER_DIX_REQHANDLERS_H */
