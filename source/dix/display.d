module dix.display;
@nogc nothrow:
extern(C): __gshared:
public import dix.dix_priv;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
// import build.dix_config;

// import dix.dix_priv;
// import include.dix;
// import include.screenint;

// const(char)* display = "0";
// int displayfd = -1;

const(char)* dixGetDisplayName(ScreenPtr* pScreen)
{
    // pScreen currently is ignored as the value is global,
    // but this might perhaps change in the future.
    return display;
}
