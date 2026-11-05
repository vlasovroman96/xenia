module lookup;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 *
 * @brief DIX lookup functions
 */
import build.dix_config;

import dix.dix_priv;
import dix.resource_priv;
import dix.input;
import include.inputstr;
import include.windowstr;

ClientPtr dixClientForWindow(WindowPtr pWin) {
    if (!pWin)
        return null;

    return dixClientForXID(pWin.drawable.id);
}

ClientPtr dixClientForGrab(GrabPtr pGrab) {
    if (!pGrab)
        return null;

    return dixClientForXID(pGrab.resource);
}

ClientPtr dixClientForInputClients(InputClientsPtr pInputClients) {
    if (!pInputClients)
        return null;

    return dixClientForXID(pInputClients.resource);
}

ClientPtr dixClientForOtherClients(OtherClientsPtr pOtherClients) {
    if (!pOtherClients)
        return null;

    return dixClientForXID(pOtherClients.resource);
}
