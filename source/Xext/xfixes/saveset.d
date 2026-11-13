module saveset;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2002 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of Keith Packard not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission.  Keith Packard makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * KEITH PACKARD DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL KEITH PACKARD BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 */

import build.dix_config;

import dix.dix_priv;
import dix.request_priv;
import dix.resource_priv;

import xfixes.xfixesint;
import externs.X11.extensions.xfixesproto;
import common.swap;


int ProcXFixesChangeSaveSet(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXFixesChangeSaveSetReq);
    mixin(X_REQUEST_FIELD_CARD32!"window");

    Bool toRoot = void, map = void;
    int result = void;
    WindowPtr pWin = void;

    result = dixLookupWindow(&pWin, stuff.window, client, DixManageAccess);
    if (result != Success)
        return result;
    if (client.clientAsMask == (CLIENT_BITS(pWin.drawable.id)))
        return BadMatch;
    if ((stuff.mode != SetModeInsert) && (stuff.mode != SetModeDelete)) {
        client.errorValue = cast(uint)stuff.mode;
        return BadValue;
    }
    if ((stuff.target != SaveSetNearest) && (stuff.target != SaveSetRoot)) {
        client.errorValue = cast(uint)stuff.target;
        return BadValue;
    }
    if ((stuff.map != SaveSetMap) && (stuff.map != SaveSetUnmap)) {
        client.errorValue = cast(uint)stuff.map;
        return BadValue;
    }
    toRoot = (stuff.target == SaveSetRoot);
    map = (stuff.map == SaveSetMap);
    return AlterSaveSetForClient(client, pWin, stuff.mode, toRoot, map);
}
