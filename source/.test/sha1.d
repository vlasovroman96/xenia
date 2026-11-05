module sha1;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT
 *
 * Copyright (c) 2025, Oracle and/or its affiliates.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER
 * DEALINGS IN THE SOFTWARE.
 */

/**
 * Tests for x_sha1_* functions provided in os/xsha1.c.
 */

/* Test relies on assert() */
import build.dix_config;

import core.stdc.assert_;
import os.os;
import os.xsha1;
import test.tests_common;
import test.tests;


private void raw_to_hex(const(ubyte)* raw, size_t raw_size, ubyte* hex, size_t hex_size)
{
    static const(char)* hex_digits = "0123456789abcdef";
    size_t i = void, o = void;

    assert(hex_size >= (raw_size * 2) + 1);

    for (i = o = 0; i < raw_size; i++) {
        hex[o++] = hex_digits[raw[i] >> 4];
        hex[o++] = hex_digits[raw[i] & 0x0f];
    }
    hex[o] = '\0';
}

private void sha1_test_repeated_blocks(void* data, size_t length, uint repeat, const(char)* expected_hash)
{
    void* ctx = void;
    ubyte[20] raw_result = void;
    ubyte[41] hex_result = void;

    assert((ctx = x_sha1_init()) !is null);
    for (uint i = 0; i < repeat; i++) {
        assert(x_sha1_update(ctx, data, length) == 1);
    }
    assert(x_sha1_final(ctx, raw_result.ptr) == 1);
    raw_to_hex(raw_result.ptr, raw_result.sizeof, hex_result.ptr, hex_result.sizeof);
    assert(strcmp(cast(char*)hex_result, expected_hash) == 0);
}

private void sha1_test_string(const(char)* string, const(char)* expected_hash)
{
    sha1_test_repeated_blocks(cast(void*) string, strlen(string), 1, expected_hash);
}

private void sha1_checks()
{
    char[4096] test_data = void;

    /* some test data of our own */
    sha1_test_string("This is a test.  This is only a test.\n",
                     "7679a5fb1320e69f4550c84560fc6ef10ace4550");

    memset(test_data.ptr, 'X', test_data.sizeof);
    sha1_test_repeated_blocks(test_data.ptr, test_data.sizeof, 11,
                              "5392c69de307625c9ff5e7d8190332857deac9f9");

    /* Test data from https://di-mgt.com.au/sha_testvectors.html */
    sha1_test_string("abc",
                     "a9993e364706816aba3e25717850c26c9cd0d89d");

    sha1_test_string("",
                     "da39a3ee5e6b4b0d3255bfef95601890afd80709");

    sha1_test_string("abcdbcdecdefdefgefghfghighijhijkijkljklmklmnlmnomnopnopq",
                     "84983e441c3bd26ebaae4aa1f95129e5e54670f1");

    sha1_test_string("abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmn"
                     ~ "hijklmnoijklmnopjklmnopqklmnopqrlmnopqrsmnopqrstnopqrstu",
                     "a49b2446a02c645bf419f995b67091253a04a259");

    memset(test_data.ptr, 'a', 4000);
    sha1_test_repeated_blocks(test_data.ptr, 4000, 250, /* 4000 * 250 = 1 million */
                              "34aa973cd4c4daa4f61eeb2bdbad27316534016f");

    const(char)* long_string = "abcdefghbcdefghicdefghijdefghijkefghijklfghijklmghijklmnhijklmno";
    const(size_t) long_length = strlen(long_string);
    assert((test_data.sizeof % long_length) == 0);
    for (size_t i = 0; i < (test_data.sizeof / long_length) ; i++) {
        memcpy(test_data.ptr + (i * long_length), long_string, long_length);
    }
    sha1_test_repeated_blocks(test_data.ptr, test_data.sizeof,
                              16777216 / (test_data.sizeof / long_length),
                              "7789f0c9ef7bfc40d93311143dfbe69e2017f592");
}

const(testfunc_t)* sha1_test()
{
    static const(testfunc_t)[3] testfuncs = [
        sha1_checks,
        null,
    ];

    return testfuncs;
}
