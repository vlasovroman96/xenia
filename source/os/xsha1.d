module os.xsha1;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/* SPDX-License-Identifier: MIT
 *
 * Copyright © 2007 Carl Worth
 * Copyright © 2009 Jeremy Huddleston, Julien Cristau, and Matthieu Herrb
 * Copyright © 2009-2010 Mikhail Gusarov
 * Copyright © 2012 Yaakov Selkowitz and Keith Packard
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

import build.dix_config;

import os.os;
import os.xsha1;

static if (HasVersion!"HAVE_SHA1_IN_LIBMD"  /* Use libmd for SHA1 */ 
	|| HasVersion!"HAVE_SHA1_IN_LIBC") {   /* Use libc for SHA1 */

static if (HasVersion!"__DragonFly__" || HasVersion!"__FreeBSD__") {
import sha;
enum	SHA1End =		SHA1_End;
enum	SHA1File =	SHA1_File;
enum	SHA1Final =	SHA1_Final;
enum	SHA1Init =	SHA1_Init;
enum	SHA1Update =	SHA1_Update;
} else {
import sha1;
}

void* x_sha1_init()
{
    SHA1_CTX* ctx = cast(SHA1_CTX*) cast(SHA1_CTX*) calloc(1, SHA1_CTX.sizeof);
    if (!ctx)
        return null;
    SHA1Init(ctx);
    return ctx;
}

int x_sha1_update(void* ctx, void* data, int size)
{
    SHA1_CTX* sha1_ctx = ctx;

    SHA1Update(sha1_ctx, data, size);
    return 1;
}

int x_sha1_final(void* ctx, ubyte* result)
{
    SHA1_CTX* sha1_ctx = ctx;

    SHA1Final(result, sha1_ctx);
    free(sha1_ctx);
    return 1;
}

} else version (HAVE_SHA1_IN_COMMONCRYPTO) {        /* Use CommonCrypto for SHA1 */

import CommonCrypto.CommonDigest;

void* x_sha1_init()
{
    CC_SHA1_CTX* ctx = cast(CC_SHA1_CTX*) cast(CC_SHA1_CTX*) calloc(1, CC_SHA1_CTX.sizeof);

    if (!ctx)
        return null;
    CC_SHA1_Init(ctx);
    return ctx;
}

int x_sha1_update(void* ctx, void* data, int size)
{
    CC_SHA1_CTX* sha1_ctx = ctx;

    CC_SHA1_Update(sha1_ctx, data, size);
    return 1;
}

int x_sha1_final(void* ctx, ubyte* result)
{
    CC_SHA1_CTX* sha1_ctx = ctx;

    CC_SHA1_Final(result, sha1_ctx);
    free(sha1_ctx);
    return 1;
}

} else version (HAVE_SHA1_IN_CRYPTOAPI) {        /* Use CryptoAPI for SHA1 */

version = WIN32_LEAN_AND_MEAN;
//import externs.X11.Xwindows;
import core.sys.windows.wincrypt;

private HCRYPTPROV hProv;

void* x_sha1_init()
{
    HCRYPTHASH* ctx = cast(HCRYPTHASH*) cast(HCRYPTHASH*) calloc(1, HCRYPTHASH.sizeof);

    if (!ctx)
        return null;
    CryptAcquireContext(&hProv, null, MS_DEF_PROV, PROV_RSA_FULL, CRYPT_VERIFYCONTEXT);
    CryptCreateHash(hProv, CALG_SHA1, 0, 0, ctx);
    return ctx;
}

int x_sha1_update(void* ctx, void* data, int size)
{
    HCRYPTHASH* hHash = ctx;

    CryptHashData(*hHash, data, size, 0);
    return 1;
}

int x_sha1_final(void* ctx, ubyte* result)
{
    HCRYPTHASH* hHash = ctx;
    DWORD len = 20;

    CryptGetHashParam(*hHash, HP_HASHVAL, result, &len, 0);
    CryptDestroyHash(*hHash);
    CryptReleaseContext(hProv, 0);
    free(ctx);
    return 1;
}

} else version (HAVE_SHA1_IN_LIBNETTLE) {   /* Use libnettle for SHA1 */

import nettle.sha1;
import nettle.version_;

void* x_sha1_init()
{
    sha1_ctx* ctx = cast(sha1_ctx*) cast(sha1_ctx*) calloc(1, sha1_ctx.sizeof);

    if (!ctx)
        return null;
    sha1_init(ctx);
    return ctx;
}

int x_sha1_update(void* ctx, void* data, int size)
{
    sha1_update(ctx, size, data);
    return 1;
}

int x_sha1_final(void* ctx, ubyte* result)
{
static if (NETTLE_VERSION_MAJOR < 4) {
    sha1_digest(ctx, 20, result);
} else {
    sha1_digest(ctx, result);
}
    free(ctx);
    return 1;
}

} else version (HAVE_SHA1_IN_LIBGCRYPT) {   /* Use libgcrypt for SHA1 */

import gcrypt;

void* x_sha1_init()
{
    static int init;
    gcry_md_hd_t h = void;
    gcry_error_t err = void;

    if (!init) {
        if (!gcry_check_version(null))
            return null;
        gcry_control(GCRYCTL_DISABLE_SECMEM, 0);
        gcry_control(GCRYCTL_INITIALIZATION_FINISHED, 0);
        init = 1;
    }

    err = gcry_md_open(&h, GCRY_MD_SHA1, 0);
    if (err)
        return null;
    return h;
}

int x_sha1_update(void* ctx, void* data, int size)
{
    gcry_md_hd_t h = ctx;

    gcry_md_write(h, data, size);
    return 1;
}

int x_sha1_final(void* ctx, ubyte* result)
{
    gcry_md_hd_t h = ctx;

    memcpy(result, gcry_md_read(h, GCRY_MD_SHA1), 20);
    gcry_md_close(h);
    return 1;
}

} else version (HAVE_SHA1_IN_LIBSHA1) {     /* Use libsha1 */

import libsha1;

void* x_sha1_init()
{
    sha1_ctx* ctx = cast(sha1_ctx*) cast(sha1_ctx*) calloc(1, sha1_ctx.sizeof);

    if (!ctx)
        return null;
    sha1_begin(ctx);
    return ctx;
}

int x_sha1_update(void* ctx, void* data, int size)
{
    sha1_hash(data, size, ctx);
    return 1;
}

int x_sha1_final(void* ctx, ubyte* result)
{
    sha1_end(result, ctx);
    free(ctx);
    return 1;
}

} else {                           /* Use OpenSSL's libcrypto */

import externs.openssl.opensslv;
static if (OPENSSL_VERSION_MAJOR >= 3) {
}
version = USE_EVP;

// version (USE_EVP) {
// import externs.openssl.evp;
// } else {
import core.stdc.stddef;             /* buggy externs.openssl/sha.h wants size_t */
import externs.openssl.sha;
// }

// version (USE_EVP) {
// private EVP_MD* sha1 = null;
// }

void* x_sha1_init()
{
    int ret = void;
// version (USE_EVP) {
//     EVP_MD_CTX* ctx = void;

//     if (sha1 is null) {
//         sha1 = EVP_MD_fetch(null, "SHA1", null);
//         if (sha1 is null)
//             return null;
//     }
//     ctx = EVP_MD_CTX_new();
//     if (ctx is null)
//         return null;
//     ret = EVP_DigestInit_ex2(ctx, sha1, null);
//     if (!ret) {
//         EVP_MD_CTX_free(ctx);
//         return null;
//     }
// } else {
    SHA_CTX* ctx = cast(SHA_CTX*) cast(SHA_CTX*) calloc(1, SHA_CTX.sizeof);

    if (!ctx)
        return null;
    ret = SHA1_Init(ctx);
    if (!ret) {
        free(ctx);
        return null;
    }
// }
    return ctx;
}

int x_sha1_update(void* ctx, void* data, int size)
{
    int ret = void;
// version (USE_EVP) {
//     EVP_MD_CTX* sha_ctx = ctx;

//     ret = EVP_DigestUpdate(sha_ctx, data, size);
//     if (!ret)
//         EVP_MD_CTX_free(sha_ctx);
// } else {
    SHA_CTX* sha_ctx = cast(SHA_CTX*)ctx;

    ret = SHA1_Update(sha_ctx, data, size);
    if (!ret)
        free(sha_ctx);
// }
    return ret;
}

int x_sha1_final(void* ctx, ubyte* result)
{
    int ret = void;
// version (USE_EVP) {
//     EVP_MD_CTX* sha_ctx = ctx;
//     uint result_len = 20; /* size of result buffer */

//     ret = EVP_DigestFinal_ex(sha_ctx, result, &result_len);
//     EVP_MD_CTX_free(sha_ctx);
// } else {
    SHA_CTX* sha_ctx = cast(SHA_CTX*)ctx;

    ret = SHA1_Final(result, sha_ctx);
    free(sha_ctx);
// }
    return ret;
}

}
