module misc;
@nogc nothrow:
extern(C): __gshared:
/**
 * Copyright © 2011 Red Hat, Inc.
 *
 *  Permission is hereby granted, free of charge, to any person obtaining a
 *  copy of this software and associated documentation files (the "Software"),
 *  to deal in the Software without restriction, including without limitation
 *  the rights to use, copy, modify, merge, publish, distribute, sublicense,
 *  and/or sell copies of the Software, and to permit persons to whom the
 *  Software is furnished to do so, subject to the following conditions:
 *
 *  The above copyright notice and this permission notice (including the next
 *  paragraph) shall be included in all copies or substantial portions of the
 *  Software.
 *
 *  THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 *  IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 *  FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 *  THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 *  LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 *  FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 *  DEALINGS IN THE SOFTWARE.
 */

/* Test relies on assert() */
import build.dix_config;

import core.stdc.stdint;

import dix.input_priv;
import dix.screenint_priv;
import os.fmt;

import include.misc;
import include.scrnintstr;
import include.dixstruct;
import test.tests_common;
// import x11.Xmd;
// import x11.Xdefs;
// import x11.X;
import include.xlibre_ptrtypes;
import test.tests;


private void dix_version_compare()
{
    int rc = void;

    rc = version_compare(0, 0, 1, 0);
    assert(rc < 0);
    rc = version_compare(1, 0, 0, 0);
    assert(rc > 0);
    rc = version_compare(0, 0, 0, 0);
    assert(rc == 0);
    rc = version_compare(1, 0, 1, 0);
    assert(rc == 0);
    rc = version_compare(1, 0, 0, 9);
    assert(rc > 0);
    rc = version_compare(0, 9, 1, 0);
    assert(rc < 0);
    rc = version_compare(1, 0, 1, 9);
    assert(rc < 0);
    rc = version_compare(1, 9, 1, 0);
    assert(rc > 0);
    rc = version_compare(2, 0, 1, 9);
    assert(rc > 0);
    rc = version_compare(1, 9, 2, 0);
    assert(rc < 0);
}

pragma(inline, true) private void set_screen(uint idx, short x, short y, short w, short h)
{
    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)idx);
    pScreen.x = x;
    pScreen.y = y;
    pScreen.width = w;
    pScreen.height = h;
}

private void dix_update_desktop_dimensions()
{
    int i = void;
    ScreenRec[MAXSCREENS] screens = void;

    for (i = 0; i < MAXSCREENS; i++)
        screenInfo.screens[i] = &screens[i];

    short x = 0;
    short y = 0;
    short w = 10;
    short h = 5;
    short w2 = 35;
    short h2 = 25;

enum string assert_dimensions(string _x, string _y, string _w, string _h) = `
    update_desktop_dimensions();          
    assert(screenInfo.x == ` ~ _x ~ `);           
    assert(screenInfo.y == ` ~ _y ~ `);           
    assert(screenInfo.width == ` ~ _w ~ `);       
    assert(screenInfo.height == ` ~ _h ~ `);`;

    /* single screen */
    screenInfo.numScreens = 1;
    set_screen(0, x, y, w, h);
    mixin(assert_dimensions!(`x`, `y`, `w`, `h`));

    /* dualhead rightof */
    screenInfo.numScreens = 2;
    set_screen(1, w, 0, w2, h2);
    mixin(assert_dimensions!(`x`, `y`, `w + w2`, `h2`));

    /* dualhead belowof */
    screenInfo.numScreens = 2;
    set_screen(1, 0, h, w2, h2);
    mixin(assert_dimensions!(`x`, `y`, `w2`, `h + h2`));

    /* triplehead L shape */
    screenInfo.numScreens = 3;
    set_screen(1, 0, h, w2, h2);
    set_screen(2, w2, h2, w, h);
    mixin(assert_dimensions!(`x`, `y`, `w + w2`, `h + h2`));

    /* quadhead 2x2 */
    screenInfo.numScreens = 4;
    set_screen(1, 0, h, w, h);
    set_screen(2, w, h, w, h2);
    set_screen(3, w, 0, w2, h);
    mixin(assert_dimensions!(`x`, `y`, `w + w2`, `h + h2`));

    /* quadhead horiz line */
    screenInfo.numScreens = 4;
    set_screen(1, w, 0, w, h);
    set_screen(2, 2 * w, 0, w, h);
    set_screen(3, 3 * w, 0, w, h);
    mixin(assert_dimensions!(`x`, `y`, `4 * w`, `h`));

    /* quadhead vert line */
    screenInfo.numScreens = 4;
    set_screen(1, 0, h, w, h);
    set_screen(2, 0, 2 * h, w, h);
    set_screen(3, 0, 3 * h, w, h);
    mixin(assert_dimensions!(`x`, `y`, `w`, `4 * h`));

    /* x overlap */
    screenInfo.numScreens = 2;
    set_screen(0, 0, 0, w2, h2);
    set_screen(1, w, 0, w2, h2);
    mixin(assert_dimensions!(`x`, `y`, `w2 + w`, `h2`));

    /* y overlap */
    screenInfo.numScreens = 2;
    set_screen(0, 0, 0, w2, h2);
    set_screen(1, 0, h, w2, h2);
    mixin(assert_dimensions!(`x`, `y`, `w2`, `h2 + h`));

    /* negative origin */
    screenInfo.numScreens = 1;
    set_screen(0, -w2, -h2, w, h);
    mixin(assert_dimensions!(`-w2`, `-h2`, `w`, `h`));

    /* dualhead negative origin, overlap */
    screenInfo.numScreens = 2;
    set_screen(0, -w2, -h2, w2, h2);
    set_screen(1, -w, -h, w, h);
    mixin(assert_dimensions!(`-w2`, `-h2`, `w2`, `h2`));
}

private int dix_request_fixed_size_overflow(ClientRec* client)
{
    xReq req = { 0 };

    client.req_len = req.length = 1;
    mixin(REQUEST_FIXED_SIZE!("req", "4096"));
    return Success;
}

private int dix_request_fixed_size_match(ClientRec* client)
{
    xReq req = { 0 };

    client.req_len = req.length = 9;
    mixin(REQUEST_FIXED_SIZE!("req", "30"));
    return Success;
}

private void dix_request_size_checks()
{
    ClientRec client = { 0 };
    int rc = void;

    rc = dix_request_fixed_size_overflow(&client);
    assert(rc == BadLength);

    rc = dix_request_fixed_size_match(&client);
    assert(rc == Success);
}

private void bswap_test()
{
    const(ushort) test_16 = 0xaabb;
    const(ushort) expect_16 = 0xbbaa;
    const(uint) test_32 = 0xaabbccdd;
    const(uint) expect_32 = 0xddccbbaa;
    const(ulong) test_64 = 0X11223344aabbccdduL;
    const(ulong) expect_64 = 0xddccbbaa44332211uL;
    ushort result_16 = void;
    uint result_32 = void;
    ulong result_64 = void;

    assert(bswap_16(test_16) == expect_16);
    assert(bswap_32(test_32) == expect_32);
    assert(bswap_64(test_64) == expect_64);

    result_16 = test_16;
    swaps(&result_16);
    assert(result_16 == expect_16);

    result_32 = test_32;
    swapl(&result_32);
    assert(result_32 == expect_32);

    result_64 = test_64;
    swapll(&result_64);
    assert(result_64 == expect_64);
}

const(testfunc_t)* misc_test()
{
    static const(testfunc_t)[6] testfuncs = [
        dix_version_compare,
        dix_update_desktop_dimensions,
        dix_request_size_checks,
        bswap_test,
        null,
    ];
    return testfuncs;
}
