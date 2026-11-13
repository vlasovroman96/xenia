module dix.privates;
@nogc nothrow:
extern(C): __gshared:
/*

Copyright 1993, 1998  The Open Group

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
 * Copyright © 2010, Keith Packard
 * Copyright © 2010, Jamey Sharp
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */

import build.dix_config;

import core.stdc.stddef;

import dix.colormap_priv;
import dix.screenint_priv;

import dix.window;
import dix.gc;
import dix.cursor;
import dix.inputstr;
import dix.scrnintstr;
import dix.inputstr;
import dix.extension;
import dix.resource;
import dix.dixutils;
import dix.input_priv;
import dix.events;
import os.log;
import dix.pixmap;

//public import x11.Xdefs;
// //public import x11.Xosdefs;
// //public import x11.Xfuncproto;
public import core.stdc.assert_;

/*****************************************************************
 * STUFF FOR PRIVATES
 *****************************************************************/
struct _Private;
alias PrivateRec = _Private;
alias PrivatePtr = _Private*;

/* WARNING: the values, as well as the total number are part of public ABI.
   Adding a new one will lead to increased size as well as different field
   offsets within ScreenRec.
*/
enum DevPrivateType {
    /* XSELinux uses the same private keys for numerous objects

       This black magic - keys of this type have very special handling:
       their corresponding space is allocated at the top of the private
       areas, in *several* object types (see xselinux_private[] array),
       and xselinux uses the same keys for all object types
    */
    PRIVATE_XSELINUX,

    /* Otherwise, you get a private in just the requested structure
     */
    /* These can have objects created before all of the keys are registered */
    PRIVATE_SCREEN,
    PRIVATE_EXTENSION,
    PRIVATE_COLORMAP,
    PRIVATE_DEVICE,

    /* These cannot have any objects before all relevant keys are registered */
    PRIVATE_CLIENT,
    PRIVATE_PROPERTY,
    PRIVATE_SELECTION,
    PRIVATE_WINDOW,
    PRIVATE_PIXMAP,
    PRIVATE_GC,
    PRIVATE_CURSOR,
    PRIVATE_CURSOR_BITS,

    /* extension privates */
    PRIVATE_GLYPH,
    PRIVATE_GLYPHSET,
    PRIVATE_PICTURE,
    PRIVATE_SYNC_FENCE,

    /* last private type */
    PRIVATE_LAST,
}
alias PRIVATE_XSELINUX = DevPrivateType.PRIVATE_XSELINUX;
alias PRIVATE_SCREEN = DevPrivateType.PRIVATE_SCREEN;
alias PRIVATE_EXTENSION = DevPrivateType.PRIVATE_EXTENSION;
alias PRIVATE_COLORMAP = DevPrivateType.PRIVATE_COLORMAP;
alias PRIVATE_DEVICE = DevPrivateType.PRIVATE_DEVICE;
alias PRIVATE_CLIENT = DevPrivateType.PRIVATE_CLIENT;
alias PRIVATE_PROPERTY = DevPrivateType.PRIVATE_PROPERTY;
alias PRIVATE_SELECTION = DevPrivateType.PRIVATE_SELECTION;
alias PRIVATE_WINDOW = DevPrivateType.PRIVATE_WINDOW;
alias PRIVATE_PIXMAP = DevPrivateType.PRIVATE_PIXMAP;
alias PRIVATE_GC = DevPrivateType.PRIVATE_GC;
alias PRIVATE_CURSOR = DevPrivateType.PRIVATE_CURSOR;
alias PRIVATE_CURSOR_BITS = DevPrivateType.PRIVATE_CURSOR_BITS;
alias PRIVATE_GLYPH = DevPrivateType.PRIVATE_GLYPH;
alias PRIVATE_GLYPHSET = DevPrivateType.PRIVATE_GLYPHSET;
alias PRIVATE_PICTURE = DevPrivateType.PRIVATE_PICTURE;
alias PRIVATE_SYNC_FENCE = DevPrivateType.PRIVATE_SYNC_FENCE;
alias PRIVATE_LAST = DevPrivateType.PRIVATE_LAST;


struct _DevPrivateKeyRec {
    int offset;
    int size;
    Bool initialized;
    Bool allocated;
    DevPrivateType type;
    _DevPrivateKeyRec* next;
}alias DevPrivateKeyRec = _DevPrivateKeyRec;
alias DevPrivateKey = _DevPrivateKeyRec*;

struct _DevPrivateSetRec {
    DevPrivateKey key;
    uint offset;
    int created;
    int allocated;
}alias DevPrivateSetRec = _DevPrivateSetRec;
alias DevPrivateSetPtr = _DevPrivateSetRec*;

struct _DevScreenPrivateKeyRec {
    DevPrivateKeyRec screenKey;
}alias DevScreenPrivateKeyRec = _DevScreenPrivateKeyRec;
alias DevScreenPrivateKeyPtr = _DevScreenPrivateKeyRec*;

/*
 * Let drivers know how to initialize private keys
 */

enum HAS_DEVPRIVATEKEYREC =		1;
enum HAS_DIXREGISTERPRIVATEKEY =	1;

/*
 * @brief Register a new private index for the private type.
 *
 * This initializes the specified key and optionally requests pre-allocated
 * private space for your driver/module. If you request no extra space, you
 * may set and get a single pointer value using this private key. Otherwise,
 * you can get the address of the extra space and store whatever data you like
 * there.
 *
 * Maybe called multiple times on the same key, but the size and type must
 * match or the server will abort.
 *
 * Note: this may move around the private storage area to different address,
 * thus any pointers taken by GetPrivateAddr() et al have to be considered
 * invalid after calling this function.
 *
 * @param key   pointer to key (will be written to)
 * @param type  the object type the key is used for
 * @param size  size of the storage reserved for that key (zero => void*)
 * @return      False if it fails to allocate memory during its operation.
 */
 Bool dixRegisterPrivateKey(DevPrivateKey key, DevPrivateType type, uint size);

/*
 * Check whether a private key has been registered
 */
pragma(inline, true) Bool dixPrivateKeyRegistered(DevPrivateKey key)
{
    return key.initialized;
}

/*
 * Get the address of the private storage.
 *
 * For keys with pre-defined storage, this gets the base of that storage
 * Otherwise, it returns the place where the private pointer is stored.

 */
pragma(inline, true) void* dixGetPrivateAddr(PrivatePtr* privates, const(DevPrivateKey) key)
{
    assert(key.initialized);
    return cast(char*) (*privates) + key.offset;
}

/*
 * Fetch a private pointer stored in the object
 *
 * Returns the pointer stored with dixSetPrivate.
 * This must only be used with keys that have
 * no pre-defined storage
 */
pragma(inline, true) void* dixGetPrivate(PrivatePtr* privates, const(DevPrivateKey) key)
{
    assert(key.size == 0);
    return *cast(void**) dixGetPrivateAddr(privates, key);
}

/*
 * Associate 'val' with 'key' in 'privates' so that later calls to
 * dixLookupPrivate(privates, key) will return 'val'.
 */
pragma(inline, true) void dixSetPrivate(PrivatePtr* privates, const(DevPrivateKey) key, void* val)
{
    assert(key.size == 0);
    *cast(void**) dixGetPrivateAddr(privates, key) = val;
}

/*
 * Lookup a pointer to the private record.
 *
 * For privates with defined storage, return the address of the
 * storage. For privates without defined storage, return the pointer
 * contents
 */
pragma(inline, true) void* dixLookupPrivate(PrivatePtr* privates, const(DevPrivateKey) key)
{
    if (key.size)
        return dixGetPrivateAddr(privates, key);
    else
        return dixGetPrivate(privates, key);
}

/*
 * Look up the address of the pointer to the storage
 *
 * This returns the place where the private pointer is stored,
 * which is only valid for privates without predefined storage.
 */
pragma(inline, true) void** dixLookupPrivateAddr(PrivatePtr* privates, const(DevPrivateKey) key)
{
    assert(key.size == 0);
    return cast(void**) dixGetPrivateAddr(privates, key);
}

int dixRegisterScreenPrivateKey(DevScreenPrivateKeyPtr key, ScreenPtr pScreen, DevPrivateType type, uint size);

// int _dixGetScreenPrivateKey(const(DevScreenPrivateKeyPtr) key, ScreenPtr pScreen);

pragma(inline, true) private void* dixGetScreenPrivateAddr(PrivatePtr* privates, DevScreenPrivateKeyPtr key, ScreenPtr pScreen)
{
    return dixGetPrivateAddr(privates, _dixGetScreenPrivateKey(key, pScreen));
}

pragma(inline, true) private void* dixGetScreenPrivate(PrivatePtr* privates, DevScreenPrivateKeyPtr key, ScreenPtr pScreen)
{
    return dixGetPrivate(privates, _dixGetScreenPrivateKey(key, pScreen));
}

pragma(inline, true) void dixSetScreenPrivate(PrivatePtr* privates, DevScreenPrivateKeyPtr key, ScreenPtr pScreen, void* val)
{
    dixSetPrivate(privates, _dixGetScreenPrivateKey(key, pScreen), val);
}

pragma(inline, true) void* dixLookupScreenPrivate(PrivatePtr* privates, DevScreenPrivateKeyPtr key, ScreenPtr pScreen)
{
    return dixLookupPrivate(privates, _dixGetScreenPrivateKey(key, pScreen));
}

pragma(inline, true) private void** dixLookupScreenPrivateAddr(PrivatePtr* privates, DevScreenPrivateKeyPtr key, ScreenPtr pScreen)
{
    return dixLookupPrivateAddr(privates,
                                _dixGetScreenPrivateKey(key, pScreen));
}

/*
 * These functions relate to allocations related to a specific screen;
 * space will only be available for objects allocated for use on that
 * screen. As such, only objects which are related directly to a specific
 * screen are candidates for allocation this way, this includes
 * windows, pixmaps, gcs, pictures and colormaps. This key is
 * used just like any other key using dixGetPrivate and friends.
 *
 * This is distinctly different from the ScreenPrivateKeys above which
 * allocate space in global objects like cursor bits for a specific
 * screen, allowing multiple screen-related chunks of storage in a
 * single global object.
 */

enum HAVE_SCREEN_SPECIFIC_PRIVATE_KEYS =       1;

int dixRegisterScreenSpecificPrivateKey(ScreenPtr pScreen, DevPrivateKey key, DevPrivateType type, uint size);

/* Clean up screen-specific privates before CloseScreen */
void dixFreeScreenSpecificPrivates(ScreenPtr pScreen);

/* Initialize screen-specific privates in AddScreen */
void dixInitScreenSpecificPrivates(ScreenPtr pScreen);

/* is this private created - so hotplug can avoid crashing */
Bool dixPrivatesCreated(DevPrivateType type);

// int* _dixAllocateScreenObjectWithPrivates(ScreenPtr pScreen, uint size, uint offset, DevPrivateType type);

enum string dixAllocateScreenObjectWithPrivates(string s, string t, string type) = `_dixAllocateScreenObjectWithPrivates(cast(ScreenPtr)` ~ s ~ `, ` ~ t ~ `.sizeof, `~t~`.devPrivates.offsetof, ` ~ type ~ `)`;

int dixScreenSpecificPrivatesSize(ScreenPtr pScreen, DevPrivateType type);

// int _dixInitScreenPrivates(ScreenPtr pScreen, PrivatePtr* privates, void* addr, DevPrivateType type);

enum string dixInitScreenPrivates(string s, string o, string v, string type) = `_dixInitScreenPrivates(` ~ s ~ `, &(` ~ o ~ `).devPrivates, (` ~ v ~ `), ` ~ type ~ `);`;

/*
 * Allocates private data separately from main object.
 *
 * For objects created during server initialization, this allows those
 * privates to be re-allocated as new private keys are registered.
 *
 * This includes screens, the serverClient, default colormaps and
 * extensions entries.
 */
int dixAllocatePrivates(PrivatePtr* privates, DevPrivateType type);

/*
 * Frees separately allocated private data
 */
// int dixFreePrivates(PrivatePtr privates, DevPrivateType type);

/*
 * Initialize privates by zeroing them
 */
// int _dixInitPrivates(PrivatePtr* privates, void* addr, DevPrivateType type);

enum string dixInitPrivates(string o, string v, string type) = `_dixInitPrivates(&(` ~ o ~ `).devPrivates, (` ~ v ~ `), ` ~ type ~ `);`;

/*
 * Clean up privates
 */
// int _dixFiniPrivates(PrivatePtr privates, DevPrivateType type);

enum string dixFiniPrivates(string o,string t) = `_dixFiniPrivates((` ~ o ~ `).devPrivates,` ~ t ~ `);`;

/*
 * Allocates private data at object creation time. Required
 * for almost all objects, except for the list described
 * above for dixAllocatePrivates.
 */
// int* _dixAllocateObjectWithPrivates(uint size, uint clear, uint offset, DevPrivateType type);

enum string dixAllocateObjectWithPrivates(string t, string type) = `cast(`~t~`*) _dixAllocateObjectWithPrivates(` ~ t ~ `.sizeof, ` ~ t ~ `.sizeof, `~t~`.devPrivates.offsetof, ` ~ type ~ `)`;

// int _mixin(dixFreeObjectWithPrivatesM!("void* object", "PrivatePtr privates, DevPrivateType type"));

enum string dixFreeObjectWithPrivatesM(string o, string t) = `dixFreeObjectWithPrivates(` ~ o ~ `, ` ~ o ~ `.devPrivates, ` ~ t ~ `);`;

/*
 * Return size of privates for the specified type
 */
int dixPrivatesSize(DevPrivateType type);

/*
 * Dump out private stats to ErrorF
 */
void dixPrivateUsage();

/*
 * Resets the privates subsystem.  dixResetPrivates is called from the main loop
 //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
 * before each server generation.  This function must only be called by main().
 */
// int dixResetPrivates();

/*
 * Looks up the offset where the devPrivates field is located.
 *
 * Returns -1 if the specified resource has no dev privates.
 * The position of the devPrivates field varies by structure
 * and calling code might only know the resource type, not the
 * structure definition.
 */
int dixLookupPrivateOffset(RESTYPE type);

/*
 * Convenience macro for adding an offset to an object pointer
 * when making a call to one of the devPrivates functions
 */
enum string DEVPRIV_AT(string ptr, string offset) = `(cast(PrivatePtr*)(cast(char*)(` ~ ptr ~ `) + ` ~ offset ~ `))`;

private DevPrivateSetRec[PRIVATE_LAST] global_keys;

private const(Bool)[PRIVATE_LAST] xselinux_private = [
    PRIVATE_SCREEN: True,
    PRIVATE_CLIENT: True,
    PRIVATE_WINDOW: True,
    PRIVATE_PIXMAP: True,
    PRIVATE_GC: True,
    PRIVATE_CURSOR: True,
    PRIVATE_COLORMAP: True,
    PRIVATE_DEVICE: True,
    PRIVATE_EXTENSION: True,
    PRIVATE_SELECTION: True,
    PRIVATE_PROPERTY: True,
    PRIVATE_PICTURE: True,
    PRIVATE_GLYPHSET: True,
];

private const(char)*[PRIVATE_LAST] key_names = [
    /* XSELinux uses the same private keys for numerous objects */
    PRIVATE_XSELINUX: "XSELINUX",

    /* Otherwise, you get a private in just the requested structure
     */
    /* These can have objects created before all of the keys are registered */
    PRIVATE_SCREEN: "SCREEN",
    PRIVATE_EXTENSION: "EXTENSION",
    PRIVATE_COLORMAP: "COLORMAP",
    PRIVATE_DEVICE: "DEVICE",

    /* These cannot have any objects before all relevant keys are registered */
    PRIVATE_CLIENT: "CLIENT",
    PRIVATE_PROPERTY: "PROPERTY",
    PRIVATE_SELECTION: "SELECTION",
    PRIVATE_WINDOW: "WINDOW",
    PRIVATE_PIXMAP: "PIXMAP",
    PRIVATE_GC: "GC",
    PRIVATE_CURSOR: "CURSOR",
    PRIVATE_CURSOR_BITS: "CURSOR_BITS",

    /* extension privates */
    PRIVATE_GLYPH: "GLYPH",
    PRIVATE_GLYPHSET: "GLYPHSET",
    PRIVATE_PICTURE: "PICTURE",
    PRIVATE_SYNC_FENCE: "SYNC_FENCE",
];

private const(Bool)[PRIVATE_LAST] screen_specific_private = [
    PRIVATE_SCREEN: False,
    PRIVATE_CLIENT: False,
    PRIVATE_WINDOW: True,
    PRIVATE_PIXMAP: True,
    PRIVATE_GC: True,
    PRIVATE_CURSOR: False,
    PRIVATE_COLORMAP: False,
    PRIVATE_DEVICE: False,
    PRIVATE_EXTENSION: False,
    PRIVATE_SELECTION: False,
    PRIVATE_PROPERTY: False,
    PRIVATE_PICTURE: True,
    PRIVATE_GLYPHSET: False,
];

alias FixupFunc = Bool function(PrivatePtr* privates, int offset, uint bytes);

enum FixupType { FixupMove, FixupRealloc }
alias FixupMove = FixupType.FixupMove;
alias FixupRealloc = FixupType.FixupRealloc;


private Bool dixReallocPrivates(PrivatePtr* privates, int old_offset, uint bytes)
{
    void* new_privates = void;

    new_privates = realloc(*privates, old_offset + bytes);
    if (!new_privates)
        return False;
    memset(cast(char*) new_privates + old_offset, '\0', bytes);
    *privates = cast(_Private*)new_privates;
    return True;
}

private Bool dixMovePrivates(PrivatePtr* privates, int new_offset, uint bytes)
{
    memmove(cast(char*) *privates + bytes, *privates, new_offset - bytes);
    memset(*privates, '\0', bytes);
    return True;
}

private Bool fixupOneScreen(ScreenPtr pScreen, FixupFunc fixup, uint bytes)
{
    uintptr_t old = void;
    char* new_ = void;
    int size = void;

    old = cast(uintptr_t) pScreen.devPrivates;
    size = global_keys[PRIVATE_SCREEN].offset;
    if (!fixup (&pScreen.devPrivates, size, bytes))
        return False;

    /* Screen privates can contain screen-specific private keys
     * for other types. When they move, the linked list we use to
     * track them gets scrambled. Fix that by computing the change
     * in the location of each private adjusting our linked list
     * pointers to match
     */

    new_ = cast(char*) pScreen.devPrivates;

    /* Moving means everyone shifts up in the privates by 'bytes' amount,
     * realloc means the base pointer moves
     */
    if (fixup == &dixMovePrivates)
        new_ += bytes;

    if (cast(uintptr_t) new_ != old) {
        for (DevPrivateType type = PRIVATE_XSELINUX; type < PRIVATE_LAST; type++)

            /* Walk the privates list, being careful as the
             * pointers are scrambled before we patch them.
             */
            for ({DevPrivateKey key = void; DevPrivateKey* keyp = &pScreen.screenSpecificPrivates[type].key;}
                 (key = *keyp) !is null;
                 keyp = &key.next)
            {

                /* Only mangle things if the private structure
                 * is contained within the allocation. Privates
                 * stored elsewhere will be left alone
                 */
                if (old <= cast(uintptr_t) key && cast(uintptr_t) key < old + size)
                {
                    /* Compute new location of key (deriving from the new
                     * allocation to avoid UB) */
                    key = cast(DevPrivateKey) (new_ + (cast(uintptr_t) key - old));

                    /* Patch the list */
                    *keyp = key;
                }
            }
    }
    return True;
}

private Bool fixupScreens(FixupFunc fixup, uint bytes)
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        if (!fixupOneScreen (walkScreen, fixup, bytes))
            return False;
    });
    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        if (!fixupOneScreen (walkScreen, fixup, bytes))
            return False;
    }"));
    return True;
}

private Bool fixupServerClient(FixupFunc fixup, uint bytes)
{
    if (serverClient)
        return fixup(&serverClient.devPrivates, global_keys[PRIVATE_CLIENT].offset,
                     bytes);
    return True;
}

private Bool fixupExtensions(FixupFunc fixup, uint bytes)
{
    ExtensionEntry* extension = void;

    for (ubyte major = EXTENSION_BASE; ((extension = GetExtensionEntry(major)) !is null);
         major++)
        if (!fixup
            (&extension.devPrivates, global_keys[PRIVATE_EXTENSION].offset, bytes))
            return False;
    return True;
}

private Bool fixupDefaultColormaps(FixupFunc fixup, uint bytes)
{
    mixin(DIX_FOR_EACH_SCREEN!("{
        ColormapPtr cmap = void;
        dixLookupResourceByType(cast(void**) &cmap,
                                cast(uint)walkScreen.defColormap, X11_RESTYPE_COLORMAP,
                                serverClient, DixCreateAccess);
        if (cmap &&
            !fixup(&cmap.devPrivates, walkScreen.screenSpecificPrivates[PRIVATE_COLORMAP].offset, bytes))
            return False;
    }"));
    return True;
}

private Bool fixupDeviceList(DeviceIntPtr device, FixupFunc fixup, uint bytes)
{
    while (device) {
        if (!fixup(&device.devPrivates, global_keys[PRIVATE_DEVICE].offset, bytes))
            return False;
        device = device.next;
    }
    return True;
}

private Bool fixupDevices(FixupFunc fixup, uint bytes)
{
    return (fixupDeviceList(inputInfo.devices, fixup, bytes) &&
            fixupDeviceList(inputInfo.off_devices, fixup, bytes));
}

private Bool function(FixupFunc, uint)[PRIVATE_LAST] allocated_early = [
    PRIVATE_SCREEN: &fixupScreens,
    PRIVATE_CLIENT: &fixupServerClient,
    PRIVATE_EXTENSION: &fixupExtensions,
    PRIVATE_COLORMAP: &fixupDefaultColormaps,
    PRIVATE_DEVICE: &fixupDevices,
];

private void grow_private_set(DevPrivateSetPtr set, uint bytes)
{
    for (DevPrivateKey k = set.key; k; k = k.next)
        k.offset += bytes;
    set.offset += bytes;
}

private void grow_screen_specific_set(DevPrivateType type, uint bytes)
{
    /* Update offsets for all screen-specific keys */
    mixin(DIX_FOR_EACH_SCREEN!q{
        grow_private_set(&walkScreen.screenSpecificPrivates[type], bytes);
    });
    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        grow_private_set(&walkScreen.screenSpecificPrivates[type], bytes);
    }"));
}

Bool dixRegisterPrivateKey(DevPrivateKey key, DevPrivateType type, uint size)
{
    int offset = void;
    uint bytes = void;

    if (key.initialized) {
        assert(size == key.size);
        return True;
    }

    /* Compute required space */
    bytes = size;
    if (size == 0)
        bytes = (void*).sizeof;

    /* align to pointer size */
    bytes = cast(uint)(bytes + (void*).sizeof - 1) & ~((void*).sizeof - 1);

    /* Update offsets for all affected keys */
    if (type == PRIVATE_XSELINUX) {

        /* Resize if we can, or make sure nothing's allocated if we can't
         *
         * special magic for PRIVATE_XSELINUX type keys - those are registered
         * at the same offset in several object types.
         */
        for (DevPrivateType t = PRIVATE_XSELINUX; t < PRIVATE_LAST; t++)
            if (xselinux_private[t]) {
                if (!allocated_early[t])
                    assert(!global_keys[t].created);
                else if (!allocated_early[t] (&dixReallocPrivates, bytes))
                    return False;
            }

        /* Move all existing keys up in the privates space to make
         * room for this new global key
         */
        for (DevPrivateType t = PRIVATE_XSELINUX; t < PRIVATE_LAST; t++) {
            if (xselinux_private[t]) {
                grow_private_set(&global_keys[t], bytes);
                grow_screen_specific_set(t, bytes);
                if (allocated_early[t])
                    allocated_early[t] (&dixMovePrivates, bytes);
            }

        }

        offset = 0;
    }
    else {
        /* Resize if we can, or make sure nothing's allocated if we can't */
        if (!allocated_early[type])
            assert(!global_keys[type].created);
        else if (!allocated_early[type] (&dixReallocPrivates, bytes))
            return False;
        offset = global_keys[type].offset;
        global_keys[type].offset += bytes;
        grow_screen_specific_set(type, bytes);
    }

    /* Setup this key */
    key.offset = offset;
    key.size = size;
    key.initialized = True;
    key.type = type;
    key.allocated = False;
    key.next = global_keys[type].key;
    global_keys[type].key = key;

    return True;
}

Bool dixRegisterScreenPrivateKey(DevScreenPrivateKeyPtr screenKey, ScreenPtr pScreen, DevPrivateType type, uint size)
{
    DevPrivateKey key = void;

    if (!dixRegisterPrivateKey(&screenKey.screenKey, PRIVATE_SCREEN, 0))
        return False;
    key = cast(_DevPrivateKeyRec*)dixGetPrivate(&pScreen.devPrivates, &screenKey.screenKey);
    if (key !is null) {
        assert(key.size == size);
        assert(key.type == type);
        return True;
    }
    key = cast(DevPrivateKeyRec*) calloc(1, DevPrivateKeyRec.sizeof);
    if (!key)
        return False;
    if (!dixRegisterPrivateKey(key, type, size)) {
        free(key);
        return False;
    }
    key.allocated = True;
    dixSetPrivate(&pScreen.devPrivates, &screenKey.screenKey, key);
    return True;
}

DevPrivateKey _dixGetScreenPrivateKey(const(DevScreenPrivateKeyPtr) key, ScreenPtr pScreen)
{
    return cast(DevPrivateKey)dixGetPrivate(&pScreen.devPrivates, &key.screenKey);
}

/*
 * Initialize privates by zeroing them
 */
void _dixInitPrivates(PrivatePtr* privates, void* addr, DevPrivateType type) @nogc nothrow
{
    assert (!screen_specific_private[type]);

    global_keys[type].created++;
    if (xselinux_private[type])
        global_keys[PRIVATE_XSELINUX].created++;
    if (global_keys[type].offset == 0)
        addr = null;
    *privates = cast(_Private*)addr;
    if (addr)
        memset(addr, '\0', global_keys[type].offset);
}

/*
 * Clean up privates
 */
void _dixFiniPrivates(PrivatePtr privates, DevPrivateType type)
{
    global_keys[type].created--;
    if (xselinux_private[type])
        global_keys[PRIVATE_XSELINUX].created--;
}

/*
 * Allocate new object with privates.
 *
 * This is expected to be invoked from the
 * dixAllocateObjectWithPrivates macro
 */
void* _dixAllocateObjectWithPrivates(uint baseSize, uint clear, uint offset, DevPrivateType type) @nogc nothrow
{
    uint totalSize = void;
    PrivatePtr privates = void;
    PrivatePtr* devPrivates = void;

    assert(type > PRIVATE_SCREEN);
    assert(type < PRIVATE_LAST);
    assert(!screen_specific_private[type]);

    /* round up so that void * is aligned */
    baseSize = cast(uint)((baseSize + (void*).sizeof - 1) & ~((void*).sizeof - 1));
    totalSize = baseSize + global_keys[type].offset;
    void* object = calloc(1, totalSize);
    if (!object)
        return null;

    memset(object, '\0', clear);
    privates = cast(PrivatePtr) ((cast(char*) object) + baseSize);
    devPrivates = cast(PrivatePtr*) (cast(char*) object + offset);

    _dixInitPrivates(devPrivates, privates, type);

    return object;
}

/*
 * Allocate privates separately from containing object.
 * Used for clients and screens.
 */
Bool dixAllocatePrivates(PrivatePtr* privates, DevPrivateType type)
{
    uint size = void;
    PrivatePtr p = void;

    assert(type > PRIVATE_XSELINUX);
    assert(type < PRIVATE_LAST);
    assert(!screen_specific_private[type]);

    size = global_keys[type].offset;
    if (!size) {
        p = null;
    }
    else {
        if (((p = cast(_Private*)calloc(1, size)) is null))
            return False;
    }

    _dixInitPrivates(privates, p, type);
    ++global_keys[type].allocated;

    return True;
}

/*
 * Free an object that has privates
 *
 * This is expected to be invoked from the
 * dixFreeObjectWithPrivates macro
 */
void dixFreeObjectWithPrivates(void* object, PrivatePtr privates, DevPrivateType type)
{
    _dixFiniPrivates(privates, type);
    free(object);
}

// pragma(msg, __traits(getFunctionAttributes, free));
// pragma(msg, __traits(getFunctionAttributes, _dixFiniPrivates));
// pragma(msg, __traits(getFunctionAttributes, dixFreeObjectWithPrivates));

/*
 * Called to free screen or client privates
 */
void dixFreePrivates(PrivatePtr privates, DevPrivateType type)
{
    if (!privates)
        return;

    _dixFiniPrivates(privates, type);
    --global_keys[type].allocated;
    free(privates);
}

/*
 * Return size of privates for the specified type
 */
int dixPrivatesSize(DevPrivateType type)
{
    assert(type >= PRIVATE_SCREEN);
    assert(type < PRIVATE_LAST);
    assert (!screen_specific_private[type]);

    return global_keys[type].offset;
}

/* Table of devPrivates offsets */
private const(int)[8] offsets = [
    -1,                                 /* X11_RESTYPE_NONE */
    WindowRec.devPrivates.offsetof,   /* X11_RESTYPE_WINDOW */
    PixmapRec.devPrivates.offsetof,   /* X11_RESTYPE_PIXMAP */
    GCRec.devPrivates.offsetof,       /* X11_RESTYPE_GC */
    -1,                                 /* X11_RESTYPE_FONT */
    CursorRec.devPrivates.offsetof,   /* X11_RESTYPE_CURSOR */
    ColormapRec.devPrivates.offsetof, /* X11_RESTYPE_COLORMAP */
];

int dixLookupPrivateOffset(RESTYPE type)
{
    /*
     * Special kludge for DBE which registers a new resource type that
     * points at pixmaps (thanks, DBE)
     */
    if (type & RC_DRAWABLE) {
        if (type == X11_RESTYPE_WINDOW)
            return offsets[X11_RESTYPE_WINDOW & TypeMask];
        else
            return offsets[X11_RESTYPE_PIXMAP & TypeMask];
    }
    type = type & TypeMask;
    if (type < offsets.length)
        return offsets[type];
    return -1;
}

/*
 * Screen-specific privates
 */

Bool dixRegisterScreenSpecificPrivateKey(ScreenPtr pScreen, DevPrivateKey key, DevPrivateType type, uint size)
{
    int offset = void;
    uint bytes = void;

    if (!screen_specific_private[type])
        FatalError("Attempt to allocate screen-specific private storage for type %s\n",
                   key_names[type]);

    if (key.initialized) {
        assert(size == key.size);
        return True;
    }

    /* Compute required space */
    bytes = size;
    if (size == 0)
        bytes = (void*).sizeof;

    /* align to void * size */
    bytes = cast(uint)((bytes + (void*).sizeof - 1) & ~((void*).sizeof - 1));

    assert (!allocated_early[type]);
    assert (!pScreen.screenSpecificPrivates[type].created);
    offset = pScreen.screenSpecificPrivates[type].offset;
    pScreen.screenSpecificPrivates[type].offset += bytes;

    /* Setup this key */
    key.offset = offset;
    key.size = size;
    key.initialized = True;
    key.type = type;
    key.allocated = False;
    key.next = pScreen.screenSpecificPrivates[type].key;
    pScreen.screenSpecificPrivates[type].key = key;

    return True;
}

/* Clean up screen-specific privates before CloseScreen */
void dixFreeScreenSpecificPrivates(ScreenPtr pScreen)
{
    for (DevPrivateType t = PRIVATE_XSELINUX; t < PRIVATE_LAST; t++) {
        for (DevPrivateKey key = pScreen.screenSpecificPrivates[t].key; key; key = key.next) {
            key.initialized = False;
        }
    }
}

/* Initialize screen-specific privates in AddScreen */
void dixInitScreenSpecificPrivates(ScreenPtr pScreen)
{
    for (DevPrivateType t = PRIVATE_XSELINUX; t < PRIVATE_LAST; t++)
        pScreen.screenSpecificPrivates[t].offset = global_keys[t].offset;
}

/* Initialize screen-specific privates in AddScreen */
void _dixInitScreenPrivates(ScreenPtr pScreen, PrivatePtr* privates, void* addr, DevPrivateType type)
{
    int privates_size = void;
    assert (screen_specific_private[type]);

    if (pScreen) {
        privates_size = pScreen.screenSpecificPrivates[type].offset;
        pScreen.screenSpecificPrivates[type].created++;
    }
    else
        privates_size = global_keys[type].offset;

    global_keys[type].created++;
    if (xselinux_private[type])
        global_keys[PRIVATE_XSELINUX].created++;
    if (privates_size == 0)
        addr = null;
    *privates = cast(_Private*)addr;
    if (addr)
        memset(addr, '\0', privates_size);
}

void* _dixAllocateScreenObjectWithPrivates(ScreenPtr pScreen, uint baseSize, uint offset, DevPrivateType type)
{
    uint totalSize = void;
    PrivatePtr privates = void;
    PrivatePtr* devPrivates = void;
    int privates_size = void;

    assert(type > PRIVATE_SCREEN);
    assert(type < PRIVATE_LAST);
    assert (screen_specific_private[type]);

    if (pScreen)
        privates_size = pScreen.screenSpecificPrivates[type].offset;
    else
        privates_size = global_keys[type].offset;
    /* round up so that pointer is aligned */
    baseSize = cast(uint)((baseSize + (void*).sizeof - 1) & ~((void*).sizeof - 1));
    totalSize = baseSize + privates_size;
    void* object = calloc(1, totalSize);
    if (!object)
        return null;

    privates = cast(PrivatePtr) ((cast(char*) object) + baseSize);
    devPrivates = cast(PrivatePtr*) (cast(char*) object + offset);

    _dixInitScreenPrivates(pScreen, devPrivates, privates, type);

    return object;
}

int dixScreenSpecificPrivatesSize(ScreenPtr pScreen, DevPrivateType type)
{
    assert(type >= PRIVATE_SCREEN);
    assert(type < PRIVATE_LAST);

    if (screen_specific_private[type])
        return pScreen.screenSpecificPrivates[type].offset;
    else
        return global_keys[type].offset;
}

void dixPrivateUsage()
{
    int objects = 0;
    int bytes = 0;
    int alloc = 0;

    for (DevPrivateType t = cast(DevPrivateType)(PRIVATE_XSELINUX + 1); t < PRIVATE_LAST; t++) {
        if (global_keys[t].offset) {
            ErrorF
                ("%s: %d objects of %d bytes = %d total bytes %d private allocs\n",
                 key_names[t], global_keys[t].created, global_keys[t].offset,
                 global_keys[t].created * global_keys[t].offset, global_keys[t].allocated);
            bytes += global_keys[t].created * global_keys[t].offset;
            objects += global_keys[t].created;
            alloc += global_keys[t].allocated;
        }
    }
    ErrorF("TOTAL: %d objects, %d bytes, %d allocs\n", objects, bytes, alloc);
}

void dixResetPrivates()
{
    for (DevPrivateType t = PRIVATE_XSELINUX; t < PRIVATE_LAST; t++) {
        for (DevPrivateKey key = global_keys[t].key, next = void; key; key = next) {
            next = key.next;
            key.offset = 0;
            key.initialized = False;
            key.size = 0;
            key.type = cast(DevPrivateType)0;
            if (key.allocated)
                free(key);
        }
        if (global_keys[t].created) {
            ErrorF("%d %ss still allocated at reset\n",
                   global_keys[t].created, key_names[t]);
            dixPrivateUsage();
        }
        global_keys[t].key = null;
        global_keys[t].offset = 0;
        global_keys[t].created = 0;
        global_keys[t].allocated = 0;
    }
}

Bool dixPrivatesCreated(DevPrivateType type)
{
    if (global_keys[type].created)
        return True;
    else
        return False;
}
