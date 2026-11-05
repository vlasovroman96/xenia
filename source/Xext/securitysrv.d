module Xext.securitysrv;
// import Xext. 
@nogc nothrow:
extern(C): __gshared:
/*
Copyright 1996, 1998  The Open Group

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

/* Xserver internals for Security extension - moved here from
   _SECURITY_SERVER section of <X11/extensions/security.h> */

 
// //public import externs.X11.extensions.secur;

public import dix.input;              /* for DeviceIntPtr */
public import dix.pixmap;             /* for DrawablePtr */
public import dix.resource;           /* for RESTYPE */
public import dix.inputstr;              /* for DeviceIntPtr */
import security;              /* for DeviceIntPtr */


/* resource type to pass in LookupIDByType for authorizations */
// RESTYPE SecurityAuthorizationResType;

/* this is what we store for an authorization */
struct _SecurityAuthorizationRec {
    XID id;                     /* resource ID */
    CARD32 timeout;             /* how long to live in seconds after refcnt == 0 */
    uint trustLevel;    /* trusted/untrusted */
    XID group;                  /* see embedding extension */
    uint refcnt;        /* how many clients connected with this auth */
    uint secondsRemaining;      /* overflow time amount for >49 days */
    OsTimerPtr timer;           /* timer for this auth */
    _OtherClients* eventClients; /* clients wanting events */
}alias SecurityAuthorizationRec = _SecurityAuthorizationRec;
alias SecurityAuthorizationPtr = SecurityAuthorizationRec*;

struct SecurityValidateGroupInfoRec {
    XID group;                  /* the group that was sent in GenerateAuthorization */
    Bool valid;                 /* did anyone recognize it? if so, set to TRUE */
}

/* Give this value or higher to the -audit option to get security messages */
enum SECURITY_AUDIT_LEVEL = 4;

                          /* _SECURITY_SRV_H */
