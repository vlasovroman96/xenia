module os.auth;
@nogc nothrow:
extern(C): __gshared:
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
 * authorization hooks for the server
 * Author:  Keith Packard, MIT X Consortium
 */

import build.dix_config;

//import   x11.X;
static import   externs.X11.Xauth;
import   include.misc;
import os.osdep;
import dix.dixstruct_priv;
import   core.sys.posix.sys.types;
import   core.sys.posix.sys.stat;
import   core.stdc.errno;
import os.log;
version (Windows) {
import    X11.Xw32defs;
}
import   core.stdc.stdlib;       /* for arc4random_buf() */
import os.access;
import os.auth;
import externs.attrs;
import os.utils;

static if(XDMCP){
import os.xdmcp;
}

enum XAUTH_PROTO_MIT = "MIT-MAGIC-COOKIE-1";
enum XAUTH_PROTO_XDM = "XDM-AUTHORIZATION-1";

import x11.X;
import x11.Xmd;
import x11.Xdefs;

alias FILE = core.stdc.stdio.FILE;
alias _IO_FILE = externs.X11.Xauth._IO_FILE*;
alias strerror = core.stdc.string.strerror;
alias strlen = core.stdc.string.strlen;
alias memcmp = core.stdc.string.memcmp;

enum LCC_UID_SET =     (1 << 0);
enum LCC_GID_SET =     (1 << 1);
enum LCC_PID_SET =     (1 << 2);
enum LCC_ZID_SET =     (1 << 3);


struct LocalClientCredRec{
    int fieldsSet;              /* Bit mask of fields set */
    int euid;                   /* Effective uid */
    int egid;                   /* Primary effective group id */
    int nSuppGids;              /* Number of supplementary group ids */
    int *pSuppGids;             /* Array of supplementary group ids */
    int pid;                    /* Process id */
    int zoneid;                 /* Only set on Solaris 10 & later */
} ;

alias AuthInitFunc = void function() @nogc nothrow;

// enum AuthAddCArgs = "ushort data, const char *data";
alias AuthAddCFunc = XID function(ushort, const char*) @nogc nothrow;

// enum AuthCheckArgs = "ushort , const char *data, ClientPtr client, const char **reason";
alias AuthCheckFunc = XID function(ushort, const char*, ClientPtr, const char**) @nogc nothrow;

enum AuthFromIDArgs = "XID, ushort *, char **";
alias AuthFromIDFunc = int function(XID, ushort *, char **) @nogc nothrow;

enum AuthGenCArgs = "uint, const char *data, uint *_return, char **data_return";
alias AuthGenCFunc = XID function(uint, const char *, uint *, char **) @nogc nothrow;

enum AuthRemCArgs = "ushort , const char *data";
alias AuthRemCFunc = int function(ushort, const char *) @nogc nothrow;

enum AuthRstCArgs = "";
alias AuthRstCFunc = int function() @nogc nothrow;

import os.xdmauth;
import os.mitauth;

struct protocol {
    const(char)* name;
    AuthAddCFunc Add;           /* new authorization data */
    AuthCheckFunc Check;        /* verify client authorization data */
    AuthRstCFunc Reset;         /* delete all authorization data entries */
    AuthFromIDFunc FromID;      /* convert ID to cookie */
    AuthRemCFunc Remove;        /* remove a specific cookie */
    AuthGenCFunc Generate;
}

version (HASXDMAUTH)
{
    private static protocol[2] protocols = [
        {
            name: XAUTH_PROTO_MIT,
            Add: MitAddCookie,
            Check: MitCheckCookie,
            Reset: MitResetCookie,
            FromID: MitFromID,
            Remove: MitRemoveCookie,
            Generate: MitGenerateCookie
        },
        {
            name: XAUTH_PROTO_XDM,
            Add: XdmAddCookie,
            Check: XdmCheckCookie,
            Reset: XdmResetCookie,
            FromID: XdmFromID,
            Remove: XdmRemoveCookie,
        },
    ];
}
else
{
    private static protocol[1] protocols = [
        {
            name: XAUTH_PROTO_MIT,
            Add: &MitAddCookie,
            Check: &MitCheckCookie,
            Reset: &MitResetCookie,
            FromID: &MitFromID,
            Remove: &MitRemoveCookie,
            Generate: &MitGenerateCookie
        },
    ];
}

enum NUM_AUTHORIZATION =  protocols.length;

/*
 * Initialize all classes of authorization by reading the
 * specified authorization file
 */

private const(char)* authorization_file = null;

private Bool ShouldLoadAuth = TRUE;

void InitAuthorization(const(char)* file_name)
{
    authorization_file = file_name;
}

private int LoadAuthorization()
{
    FILE* f = void;
    externs.X11.Xauth.Xauth* auth = void;
    int i = void;
    int count = 0;

    ShouldLoadAuth = FALSE;
    if (!authorization_file)
        return 0;

    errno = 0;
    f = cast(FILE*)Fopen(authorization_file, "r");
    if (!f) {
        LogMessageVerb(X_ERROR, 0,
                       "Failed to open authorization file \"%s\": %s\n",
                       authorization_file,
                       errno != 0 ? strerror(errno) : "Unknown error");
        return -1;
    }

    while ((auth = externs.X11.Xauth.XauReadAuth(cast(FILE*)f)) !is null) {
        for (i = 0; i < NUM_AUTHORIZATION; i++) {
            if (strlen(protocols[i].name) == auth.name_length &&
                memcmp(protocols[i].name, auth.name,
                       cast(int) auth.name_length) == 0 && protocols[i].Add) {
                if (protocols[i].Add(auth.data_length, auth.data))
                    count++;
            }
        }
        externs.X11.Xauth.XauDisposeAuth(auth);
    }

    Fclose(cast(_IO_FILE)f);
    return count;
}

static if(XDMCP){
/*
 * XdmcpInit calls this function to discover all authorization
 * schemes supported by the display
 */
void RegisterAuthorizations()
{
    int i = void;

    for (i = 0; i < NUM_AUTHORIZATION; i++)
        XdmcpRegisterAuthorization(protocols[i].name);
}
}

XID CheckAuthorization(uint name_length, const(char)* name, uint data_length, const(char)* data, ClientPtr client, const(char)** reason)
{                               /* failure message.  NULL for default msg */
    int i = void;
    stat_t buf = void;
    static time_t lastmod = 0;
    static Bool loaded = FALSE;

    if (!authorization_file || stat(authorization_file, &buf)) {
        if (lastmod != 0) {
            lastmod = 0;
            ShouldLoadAuth = TRUE;      /* stat lost, so force reload */
        }
    }
    else if (buf.st_mtim.tv_sec > lastmod) {
        lastmod = buf.st_mtim.tv_sec;
        ShouldLoadAuth = TRUE;
    }
    if (ShouldLoadAuth) {
        int loadauth = LoadAuthorization();

        /*
         * If the authorization file has at least one entry for this server,
         * disable local access. (loadauth > 0)
         *
         * If there are zero entries (either initially or when the
         * authorization file is later reloaded), or if a valid
         * authorization file was never loaded, enable local access.
         * (loadauth == 0 || !loaded)
         *
         * If the authorization file was loaded initially (with valid
         * entries for this server), and reloading it later fails, don't
         * change anything. (loadauth == -1 && loaded)
         */

        if (loadauth > 0) {
            DisableLocalAccess(); /* got at least one */
            loaded = TRUE;
        }
        else if (loadauth == 0 || !loaded)
            EnableLocalAccess();
    }
    if (name_length) {
        for (i = 0; i < NUM_AUTHORIZATION; i++) {
            if (strlen(protocols[i].name) == name_length &&
                memcmp(protocols[i].name, name, cast(int) name_length) == 0) {
                return (*protocols[i].Check) (cast(ushort)data_length, data, client,
                                              reason);
            }
            *reason = "Authorization protocol not supported by server\n";
        }
    }
    else
        *reason = "Authorization required, but no authorization protocol specified\n";
    return cast(XID) ~0L;
}

void ResetAuthorization()
{
    int i = void;

    for (i = 0; i < NUM_AUTHORIZATION; i++)
        if (protocols[i].Reset)
            (*protocols[i].Reset) ();
    ShouldLoadAuth = TRUE;
}

int AuthorizationFromID(XID id, ushort* name_lenp, const(char)** namep, ushort* data_lenp, char** datap)
{
    int i = void;

    for (i = 0; i < NUM_AUTHORIZATION; i++) {
        if (protocols[i].FromID &&
            (*protocols[i].FromID) (id, data_lenp, datap)) {
            *name_lenp = cast(ushort)strlen(protocols[i].name);
            *namep = protocols[i].name;
            return 1;
        }
    }
    return 0;
}

int RemoveAuthorization(ushort name_length, const(char)* name, ushort data_length, const(char)* data)
{
    int i = void;

    for (i = 0; i < NUM_AUTHORIZATION; i++) {
        if (strlen(protocols[i].name) == name_length &&
            memcmp(protocols[i].name, name, cast(int) name_length) == 0 &&
            protocols[i].Remove) {
            return (*protocols[i].Remove) (data_length, data);
        }
    }
    return 0;
}

int AddAuthorization(uint name_length, const(char)* name, uint data_length, char* data)
{
    int i = void;

    for (i = 0; i < NUM_AUTHORIZATION; i++) {
        if (strlen(protocols[i].name) == name_length &&
            memcmp(protocols[i].name, name, cast(int) name_length) == 0 &&
            protocols[i].Add) {
            return cast(int)protocols[i].Add(cast(ushort)data_length, data);
        }
    }
    return 0;
}

XID GenerateAuthorization(uint name_length, const(char)* name, uint data_length, const(char)* data, uint* data_length_return, char** data_return)
{
    int i = void;

    for (i = 0; i < NUM_AUTHORIZATION; i++) {
        if (strlen(protocols[i].name) == name_length &&
            memcmp(protocols[i].name, name, cast(int) name_length) == 0 &&
            protocols[i].Generate) {
            return protocols[i].Generate(data_length, data,
                                         data_length_return, data_return);
        }
    }
    return 0;
}
