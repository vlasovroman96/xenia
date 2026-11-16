module abi.common;

/* SPDX-License-Identifier: MIT OR X11
 * 
 * Copyright © 2026, Roman Vlasov
 * 
 * See COPYING for the full license texts.
 */

import core.stdc.string;

@nogc: nothrow:
string charsToString(const char* chars) {
    return cast(string)chars[0..strlen(chars)];
}
