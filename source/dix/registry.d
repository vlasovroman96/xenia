module registry;
@nogc nothrow:
extern(C): __gshared:

template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
/************************************************************

Author: Eamon Walsh <ewalsh@tycho.nsa.gov>

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
this permission notice appear in supporting documentation.  This permission
notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

********************************************************/

import build.dix_config;

import core.stdc.stdlib;
import core.stdc.string;
//import x11.X;
//import x11.Xproto;

import registry;

import dix.registry_priv;

import dix.resource;
import os.log;
import dix.extension;
import core.stdc.stdio;
import os.os;
import x11.Xdefs;


enum BASE_SIZE = 16;

// version (X_REGISTRY_REQUEST) {
enum CORE = "X11";
enum FILENAME = SERVER_MISC_CONFIG_PATH ~ "/protocol.txt";

enum PROT_COMMENT = '#';
enum PROT_REQUEST = 'R';
enum PROT_EVENT = 'V';
enum PROT_ERROR = 'E';

FILE* fh;

char*** requests; char** events, errors;
uint nmajor; uint* nminor; uint nevent, nerror;
// }

static if (X_REGISTRY_RESOURCE) {
const(char)** resources;
uint nresource;
}

static if (X_REGISTRY_RESOURCE || X_REGISTRY_REQUEST) {
/*
 * File parsing routines
 */
//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
int double_size_(void* p, uint n, uint size)
{
    char** ptr = cast(char**) p;
    uint s = void, f = void;

    if (n) {
        s = n * size;
        n *= 2 * size;
        f = n;
    }
    else {
        s = 0;
        n = f = BASE_SIZE * size;
    }

    *ptr = cast(char*) realloc(*ptr, n);
    if (!*ptr) {
        dixResetRegistry();
        return False;
    }
    memset(*ptr + s, 0, f - s);
    return True;
}
}

static if (X_REGISTRY_REQUEST) {
/*
 * Request/event/error registry functions
 */
void RegisterRequestName(uint major, uint minor, char* name)
{
    while (major >= nmajor) {
        if (!double_size_(&requests, nmajor, (char**).sizeof))
            return;
        if (!double_size_(&nminor, nmajor, uint.sizeof))
            return;
        nmajor = nmajor ? nmajor * 2 : BASE_SIZE;
    }
    while (minor >= nminor[major]) {
        if (!double_size_(requests + major, nminor[major], (char*).sizeof))
            return;
        nminor[major] = nminor[major] ? nminor[major] * 2 : BASE_SIZE;
    }

    free(requests[major][minor]);
    requests[major][minor] = name;
}

void RegisterEventName(uint event, char* name)
{
    while (event >= nevent) {
        if (!double_size_(&events, nevent, (char*).sizeof))
            return;
        nevent = nevent ? nevent * 2 : BASE_SIZE;
    }

    free(events[event]);
    events[event] = name;
}

void RegisterErrorName(uint error, char* name)
{
    while (error >= nerror) {
        if (!double_size_(&errors, nerror, (char*).sizeof))
            return;
        nerror = nerror ? nerror * 2 : BASE_SIZE;
    }

    free(errors[error]);
    errors[error] = name;
}

void RegisterExtensionNames(ExtensionEntry* extEntry)
{
    char[256] buf = void; char* lineobj = void, ptr = void;
    uint offset = void;

    if (fh is null)
        return;

    rewind(fh);

    while (fgets(buf.ptr, buf.sizeof, fh)) {
        lineobj = null;
        ptr = strchr(buf.ptr, '\n');
        if (ptr)
            *ptr = 0;

        /* Check for comments or empty lines */
        switch (buf[0]) {
        case PROT_REQUEST:
        case PROT_EVENT:
        case PROT_ERROR:
            break;
        case PROT_COMMENT:
        case '\0':
            continue;
        default:
            goto invalid;
        }

        /* Check for space character in the fifth position */
        ptr = strchr(buf.ptr, ' ');
        if (!ptr || ptr != buf.ptr + 4)
            goto invalid;

        /* Duplicate the string after the space */
        lineobj = strdup(ptr + 1);
        if (!lineobj)
            continue;

        /* Check for a colon somewhere on the line */
        ptr = strchr(buf.ptr, ':');
        if (!ptr)
            goto invalid;

        /* Compare the part before colon with the target extension name */
        *ptr = 0;
        if (strcmp(buf.ptr + 5, extEntry.name))
            goto skip;

        /* Get the opcode for the request, event, or error */
        offset = cast(uint)strtol(buf.ptr + 1, &ptr, 10);
        if (offset == 0 && ptr == buf.ptr + 1)
            goto invalid;

        /* Save the strdup result in the registry */
        switch (buf[0]) {
        case PROT_REQUEST:
            if (extEntry.base)
                RegisterRequestName(extEntry.base, offset, lineobj);
            else
                RegisterRequestName(offset, 0, lineobj);
            continue;
        case PROT_EVENT:
            RegisterEventName(extEntry.eventBase + offset, lineobj);
            continue;
        case PROT_ERROR:
            RegisterErrorName(extEntry.errorBase + offset, lineobj);
            continue;
        default: break;}

 invalid:
        LogMessage(X_WARNING, "Invalid line in " ~ FILENAME ~ ", skipping\n");
 skip:
        free(lineobj);
    }
}

const(char)* LookupRequestName(int major, int minor)
{
    if (major >= nmajor)
        return XREGISTRY_UNKNOWN;
    if (minor >= nminor[major])
        return XREGISTRY_UNKNOWN;

    return requests[major][minor] ? requests[major][minor] : XREGISTRY_UNKNOWN;
}

const(char)* LookupMajorName(int major)
{
    if (major < 128) {
        const(char)* retval = void;

        if (major >= nmajor)
            return XREGISTRY_UNKNOWN;
        if (0 >= nminor[major])
            return XREGISTRY_UNKNOWN;

        retval = requests[major][0];
        return retval ? retval + CORE.sizeof : XREGISTRY_UNKNOWN;
    }
    else {
        ExtensionEntry* extEntry = GetExtensionEntry(major);

        return extEntry ? extEntry.name : XREGISTRY_UNKNOWN;
    }
}

const(char)* LookupEventName(int event)
{
    event &= 127;
    if (event >= nevent)
        return XREGISTRY_UNKNOWN;

    return events[event] ? events[event] : XREGISTRY_UNKNOWN;
}

const(char)* LookupErrorName(int error)
{
    if (error >= nerror)
        return XREGISTRY_UNKNOWN;

    return errors[error] ? errors[error] : XREGISTRY_UNKNOWN;
}
} /* X_REGISTRY_REQUEST */

pragma(inline, true) void __accbit(Mask val, Mask mask, const(char)* name, char* buf, int sz) {
    if ((val & mask) == mask) {
        if (buf[0])
            strncat(buf, ",", sz);
        strncat(buf, name, sz);
    }
}

void LookupDixAccessName(Mask acc, char* buf, int sz) {
    buf[0] = 0;
    __accbit(acc, DixReadAccess,      "Read",      buf, sz);
    __accbit(acc, DixWriteAccess,     "Write",     buf, sz);
    __accbit(acc, DixDestroyAccess,   "Destroy",   buf, sz);
    __accbit(acc, DixCreateAccess,    "Create",    buf, sz);
    __accbit(acc, DixGetAttrAccess,   "GetAttr",   buf, sz);
    __accbit(acc, DixSetAttrAccess,   "SetAttr",   buf, sz);
    __accbit(acc, DixListPropAccess,  "ListProp",  buf, sz);
    __accbit(acc, DixGetPropAccess,   "GetProp",   buf, sz);
    __accbit(acc, DixSetPropAccess,   "SetProp",   buf, sz);
    __accbit(acc, DixGetFocusAccess,  "GetFocus",  buf, sz);
    __accbit(acc, DixSetFocusAccess,  "SetFocus",  buf, sz);
    __accbit(acc, DixListAccess,      "List",      buf, sz);
    __accbit(acc, DixAddAccess,       "Add",       buf, sz);
    __accbit(acc, DixRemoveAccess,    "Remove",    buf, sz);
    __accbit(acc, DixHideAccess,      "Hide",      buf, sz);
    __accbit(acc, DixShowAccess,      "Show",      buf, sz);
    __accbit(acc, DixBlendAccess,     "Blend",     buf, sz);
    __accbit(acc, DixGrabAccess,      "Grab",      buf, sz);
    __accbit(acc, DixFreezeAccess,    "Freeze",    buf, sz);
    __accbit(acc, DixForceAccess,     "Force",     buf, sz);
    __accbit(acc, DixInstallAccess,   "Install",   buf, sz);
    __accbit(acc, DixUninstallAccess, "Uninstall", buf, sz);
    __accbit(acc, DixSendAccess,      "Send",      buf, sz);
    __accbit(acc, DixReceiveAccess,   "Receive",   buf, sz);
    __accbit(acc, DixUseAccess,       "Use",       buf, sz);
    __accbit(acc, DixManageAccess,    "Manage",    buf, sz);
    __accbit(acc, DixDebugAccess,     "Debug",     buf, sz);
    __accbit(acc, DixBellAccess,      "Bell",      buf, sz);
    __accbit(acc, DixPostAccess,      "Post",      buf, sz);
    buf[sz-1] = 0;
}

static if (X_REGISTRY_RESOURCE) {
/*
 * Resource registry functions
 */

void RegisterResourceName(RESTYPE resource, const(char)* name)
{
    resource &= TypeMask;

    while (resource >= nresource) {
        if (!.double_size_(&resources, nresource, (char*).sizeof))
            return;
        nresource = nresource ? nresource * 2 : BASE_SIZE;
    }

    resources[resource] = name;
}

const(char)* LookupResourceName(RESTYPE resource)
{
    resource &= TypeMask;
    if (resource >= nresource)
        return XREGISTRY_UNKNOWN;

    return resources[resource] ? resources[resource] : XREGISTRY_UNKNOWN;
}
} /* X_REGISTRY_RESOURCE */

void dixFreeRegistry()
{
version (X_REGISTRY_REQUEST) {
    /* Free all memory */
    while (nmajor--) {
        while (nminor[nmajor])
            free(requests[nmajor][--nminor[nmajor]]);
        free(requests[nmajor]);
    }
    free(requests);
    free(nminor);

    while (nevent--)
        free(events[nevent]);
    free(events);

    while (nerror--)
        free(errors[nerror]);
    free(errors);
    requests = null;
    nminor = null;
    events = null;
    errors = null;
    nmajor = nevent = nerror = 0;
}

static if (X_REGISTRY_RESOURCE) {
    free(resources);

    resources = null;
    nresource = 0;
}
}

void dixCloseRegistry()
{
version (X_REGISTRY_REQUEST) {
    if (fh) {
	fclose(fh);
        fh = null;
    }
}
}

/*
 * Setup and teardown
 */
void dixResetRegistry()
{
version (X_REGISTRY_REQUEST) {
    ExtensionEntry extEntry = { name: CORE };
}

    dixFreeRegistry();

version (X_REGISTRY_REQUEST) {
    /* Open the protocol file */
    fh = fopen(FILENAME, "r");
    if (!fh)
        LogMessage(X_WARNING,
                   "Failed to open protocol names file " ~ FILENAME ~ "\n");

    /* Add the core protocol */
    RegisterExtensionNames(&extEntry);
}

static if (X_REGISTRY_RESOURCE) {
    /* Add built-in resources */
    RegisterResourceName(X11_RESTYPE_NONE, "NONE");
    RegisterResourceName(X11_RESTYPE_WINDOW, "WINDOW");
    RegisterResourceName(X11_RESTYPE_PIXMAP, "PIXMAP");
    RegisterResourceName(X11_RESTYPE_GC, "GC");
    RegisterResourceName(X11_RESTYPE_FONT, "FONT");
    RegisterResourceName(X11_RESTYPE_CURSOR, "CURSOR");
    RegisterResourceName(X11_RESTYPE_COLORMAP, "COLORMAP");
    RegisterResourceName(X11_RESTYPE_CMAPENTRY, "COLORMAP ENTRY");
    RegisterResourceName(X11_RESTYPE_OTHERCLIENT, "OTHER CLIENT");
    RegisterResourceName(X11_RESTYPE_PASSIVEGRAB, "PASSIVE GRAB");
}
}
