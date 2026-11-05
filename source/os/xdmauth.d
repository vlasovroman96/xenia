module os.xdmauth;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1988, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

*/

/*
 * XDM-AUTHENTICATION-1 (XDMCP authentication) and
 * XDM-AUTHORIZATION-1 (client authorization) protocols
 *
 * Author:  Keith Packard, MIT X Consortium
 */

import build.dix_config;

import core.stdc.stdio;
//import x11.X;

import os.auth;
import os.io_priv;
import os.Xtrans;

import os.os;
import os.osdep;

static if(XDMCP){
import os.xdmcp;
}

import os.xdmauth;
import dix.dixstruct_priv;

version (HASXDMAUTH) {

private Bool authFromXDMCP;

static if(XDMCP){
//import x11.Xmd;
//import externs.xdmcp;

/* XDM-AUTHENTICATION-1 */

private XdmAuthKeyRec privateKey;
private char[21] XdmAuthenticationName = "XDM-AUTHENTICATION-1";

enum XdmAuthenticationNameLen = (XdmAuthenticationName.sizeof - 1);
private XdmAuthKeyRec global_rho;

private Bool XdmAuthenticationValidator(ARRAY8Ptr privateData, ARRAY8Ptr incomingData, xdmOpCode packet_type)
{
    XdmAuthKeyPtr incoming = void;

    XdmcpUnwrap(incomingData.data, cast(ubyte*) &privateKey,
                incomingData.data, incomingData.length);
    if (packet_type == ACCEPT) {
        if (incomingData.length != 8)
            return FALSE;
        incoming = cast(XdmAuthKeyPtr) incomingData.data;
        XdmcpDecrementKey(incoming);
        return XdmcpCompareKeys(incoming, &global_rho);
    }
    return FALSE;
}

private Bool XdmAuthenticationGenerator(ARRAY8Ptr privateData, ARRAY8Ptr outgoingData, xdmOpCode packet_type)
{
    outgoingData.length = 0;
    outgoingData.data = 0;
    if (packet_type == REQUEST) {
        if (XdmcpAllocARRAY8(outgoingData, 8))
            XdmcpWrap(cast(ubyte*) &global_rho, cast(ubyte*) &privateKey,
                      outgoingData.data, 8);
    }
    return TRUE;
}

private Bool XdmAuthenticationAddAuth(int name_len, const(char)* name, int data_len, char* data)
{
    Bool ret = void;

    XdmcpUnwrap(cast(ubyte*) data, cast(ubyte*) &privateKey,
                cast(ubyte*) data, data_len);
    authFromXDMCP = TRUE;
    ret = AddAuthorization(name_len, name, data_len, data);
    authFromXDMCP = FALSE;
    return ret;
}

enum string atox(string c) = `('0' <= ` ~ c ~ ` && ` ~ c ~ ` <= '9' ? ` ~ c ~ ` - '0' : 
		 'a' <= ` ~ c ~ ` && ` ~ c ~ ` <= 'f' ? ` ~ c ~ ` - 'a' + 10 : 
		 'A' <= ` ~ c ~ ` && ` ~ c ~ ` <= 'F' ? ` ~ c ~ ` - 'A' + 10 : -1)`;

private int HexToBinary(const(char)* in_, char* out_, int len)
{
    int top = void, bottom = void;

    while (len > 0) {
        top = mixin(atox!(`in_[0]`));
        if (top == -1)
            return 0;
        bottom = mixin(atox!(`in_[1]`));
        if (bottom == -1)
            return 0;
        *out_++ = (top << 4) | bottom;
        in_ += 2;
        len -= 2;
    }
    if (len)
        return 0;
    *out_++ = '\0';
    return 1;
}

void XdmAuthenticationInit(const(char)* cookie, int cookie_len)
{
    memset(privateKey.data, 0, 8);
    if (!strncmp(cookie, "0x", 2) || !strncmp(cookie, "0X", 2)) {
        if (cookie_len > 2 + 2 * 8)
            cookie_len = 2 + 2 * 8;
        HexToBinary(cookie + 2, cast(char*) privateKey.data, cookie_len - 2);
    }
    else {
        if (cookie_len > 7)
            cookie_len = 7;
        memmove(privateKey.data + 1, cookie, cookie_len);
    }
    XdmcpGenerateKey(&global_rho);
    XdmcpRegisterAuthentication(XdmAuthenticationName.ptr, XdmAuthenticationNameLen,
                                cast(char*) &global_rho,
                                global_rho.sizeof,
                                cast(ValidatorFunc) XdmAuthenticationValidator,
                                cast(GeneratorFunc) XdmAuthenticationGenerator,
                                cast(AddAuthorFunc) XdmAuthenticationAddAuth);
}

}                        /* XDMCP */

/* XDM-AUTHORIZATION-1 */
struct _XdmAuthorization {
    _XdmAuthorization* next;
    XdmAuthKeyRec rho;
    XdmAuthKeyRec key;
    XID id;
}alias XdmAuthorizationRec = _XdmAuthorization;
alias XdmAuthorizationPtr = _XdmAuthorization*;

private XdmAuthorizationPtr xdmAuth;

struct _XdmClientAuth {
    _XdmClientAuth* next;
    XdmAuthKeyRec rho;
    char[6] client = 0;
    c_long time;
}alias XdmClientAuthRec = _XdmClientAuth;
alias XdmClientAuthPtr = _XdmClientAuth*;

private XdmClientAuthPtr xdmClients;
private c_long clockOffset;
private Bool gotClock;

enum TwentyMinutes =	(20 * 60);
enum TwentyFiveMinutes = (25 * 60);

private Bool XdmClientAuthCompare(const(XdmClientAuthPtr) a, const(XdmClientAuthPtr) b)
{
    int i = void;

    if (!XdmcpCompareKeys(&a.rho, &b.rho))
        return FALSE;
    for (i = 0; i < 6; i++)
        if (a.client[i] != b.client[i])
            return FALSE;
    return a.time == b.time;
}

private void XdmClientAuthDecode(const(ubyte)* plain, XdmClientAuthPtr auth)
{
    int i = void, j = void;

    j = 0;
    for (i = 0; i < 8; i++) {
        auth.rho.data[i] = plain[j];
        ++j;
    }
    for (i = 0; i < 6; i++) {
        auth.client[i] = plain[j];
        ++j;
    }
    auth.time = 0;
    for (i = 0; i < 4; i++) {
        auth.time |= plain[j] << ((3 - i) << 3);
        j++;
    }
}

private void XdmClientAuthTimeout(c_long now)
{
    XdmClientAuthPtr client = void, next = void, prev = void;

    prev = 0;
    for (client = xdmClients; client; client = next) {
        next = client.next;
        if (labs(now - client.time) > TwentyFiveMinutes) {
            if (prev)
                prev.next = next;
            else
                xdmClients = next;
            free(client);
        }
        else
            prev = client;
    }
}

private XdmClientAuthPtr XdmAuthorizationValidate(ubyte* plain, int length, XdmAuthKeyPtr rho, ClientPtr xclient, const(char)** reason)
{
    XdmClientAuthPtr client = void, existing = void;
    c_long now = void;
    int i = void;

    if (length != (192 / 8)) {
        if (reason)
            *reason = "Bad XDM authorization key length";
        return null;
    }
    client = cast(XdmClientAuthRec*) calloc(1, XdmClientAuthRec.sizeof);
    if (!client)
        return null;
    XdmClientAuthDecode(plain, client);
    if (!XdmcpCompareKeys(&client.rho, rho)) {
        free(client);
        if (reason)
            *reason = "Invalid XDM-AUTHORIZATION-1 key (failed key comparison)";
        return null;
    }
    for (i = 18; i < 24; i++)
        if (plain[i] != 0) {
            free(client);
            if (reason)
                *reason = "Invalid XDM-AUTHORIZATION-1 key (failed NULL check)";
            return null;
        }
    if (xclient) {
        int family = void, addr_len = void;
        Xtransaddr* addr = void;

        if (_XSERVTransGetPeerAddr((cast(OsCommPtr) xclient.osPrivate).trans_conn,
                                   &family, &addr_len, &addr) == 0
            && _XSERVTransConvertAddress(&family, &addr_len, &addr) == 0) {
            if (family == FamilyInternet &&
                memcmp(cast(char*) addr, client.client, 4) != 0) {
                free(client);
                free(addr);
                if (reason)
                    *reason =
                        "Invalid XDM-AUTHORIZATION-1 key (failed address comparison)";
                return null;

            }
            free(addr);
        }
    }
    now = time(0);
    if (!gotClock) {
        clockOffset = client.time - now;
        gotClock = TRUE;
    }
    now += clockOffset;
    XdmClientAuthTimeout(now);
    if (labs(client.time - now) > TwentyMinutes) {
        free(client);
        if (reason)
            *reason = "Excessive XDM-AUTHORIZATION-1 time offset";
        return null;
    }
    for (existing = xdmClients; existing; existing = existing.next) {
        if (XdmClientAuthCompare(existing, client)) {
            free(client);
            if (reason)
                *reason = "XDM authorization key matches an existing client!";
            return null;
        }
    }
    return client;
}

XID XdmAddCookie(ushort data_length, const(char)* data)
{
    ubyte* rho_bits = void, key_bits = void;

    switch (data_length) {
    case 16:                   /* auth from files is 16 bytes long */
static if(XDMCP){
        if (authFromXDMCP) {
            /* R5 xdm sent bogus authorization data in the accept packet,
             * but we can recover */
            rho_bits = global_rho.data;
            key_bits = cast(ubyte*) data;
            key_bits[0] = '\0';
        }
        else
        {
            rho_bits = cast(ubyte*) data;
            key_bits = cast(ubyte*) (data + 8);
        }
}
else {
    rho_bits = cast(ubyte*) data;
    key_bits = cast(ubyte*) (data + 8);
}
        break;
static if(XDMCP){
    case 8:                    /* auth from XDMCP is 8 bytes long */
        rho_bits = global_rho.data;
        key_bits = cast(ubyte*) data;
        break;
}
    default:
        return 0;
    }
    /* the first octet of the key must be zero */
    if (key_bits[0] != '\0')
        return 0;

    /* check for possible duplicate and return it */
    for (XdmAuthorizationRec* walk = xdmAuth; walk; walk=walk.next) {
        if ((memcmp(walk.key.data, key_bits, 8)==0) &&
            (memcmp(walk.rho.data, rho_bits, 8)==0))
            return walk.id;
    }

    XdmAuthorizationPtr new_ = cast(XdmAuthorizationRec*) calloc(1, XdmAuthorizationRec.sizeof);
    if (!new_)
        return 0;
    new_.next = xdmAuth;
    xdmAuth = new_;
    memcpy(new_.key.data, key_bits, 8);
    memcpy(new_.rho.data, rho_bits, 8);
    new_.id = dixAllocServerXID();
    return new_.id;
}

XID XdmCheckCookie(ushort cookie_length, const(char)* cookie, ClientPtr xclient, const(char)** reason)
{
    XdmAuthorizationPtr auth = void;
    XdmClientAuthPtr client = void;

    /* Auth packets must be a multiple of 8 bytes long */
    if (cookie_length & 7)
        return (XID) -1;
    ubyte* plain = cast(ubyte*) calloc(1, cookie_length);
    if (!plain)
        return (XID) -1;
    for (auth = xdmAuth; auth; auth = auth.next) {
        XdmcpUnwrap(cast(ubyte*) cookie, cast(ubyte*) &auth.key,
                    plain, cookie_length);
        if ((client =
             XdmAuthorizationValidate(plain, cookie_length, &auth.rho, xclient,
                                      reason)) !is null) {
            client.next = xdmClients;
            xdmClients = client;
            free(plain);
            return auth.id;
        }
    }
    free(plain);
    return (XID) -1;
}

int XdmResetCookie()
{
    XdmAuthorizationPtr auth = void, next_auth = void;
    XdmClientAuthPtr client = void, next_client = void;

    for (auth = xdmAuth; auth; auth = next_auth) {
        next_auth = auth.next;
        free(auth);
    }
    xdmAuth = 0;
    for (client = xdmClients; client; client = next_client) {
        next_client = client.next;
        free(client);
    }
    xdmClients = cast(XdmClientAuthPtr) 0;
    return 1;
}

int XdmFromID(XID id, ushort* data_lenp, char** datap)
{
    XdmAuthorizationPtr auth = void;

    for (auth = xdmAuth; auth; auth = auth.next) {
        if (id == auth.id) {
            *data_lenp = 16;
            *datap = cast(char*) &auth.rho;
            return 1;
        }
    }
    return 0;
}

int XdmRemoveCookie(ushort data_length, const(char)* data)
{
    XdmAuthorizationPtr auth = void;
    XdmAuthKeyPtr key_bits = void, rho_bits = void;

    switch (data_length) {
    case 16:
        rho_bits = cast(XdmAuthKeyPtr) data;
        key_bits = cast(XdmAuthKeyPtr) (data + 8);
        break;
static if(XDMCP){
    case 8:
        rho_bits = &global_rho;
        key_bits = cast(XdmAuthKeyPtr) data;
        break;
}
    default:
        return 0;
    }
    for (auth = xdmAuth; auth; auth = auth.next) {
        if (XdmcpCompareKeys(rho_bits, &auth.rho) &&
            XdmcpCompareKeys(key_bits, &auth.key)) {
            xdmAuth = auth.next;
            free(auth);
            return 1;
        }
    }
    return 0;
}

}
