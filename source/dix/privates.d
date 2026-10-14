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

import include.windowstr;
import include.resource;
import include.privates;
import include.gcstruct;
import dix.cursor;
import include.inputstr;
import include.scrnintstr;
import include.extnsionst;
import include.inputstr;
import dix.extension;
import dix.resource;
import dix.dixutils;
import dix.input_priv;
import dix.events;
import os.log;

private DevPrivateSetRec[PRIVATE_LAST] global_keys;

private const(Bool)[PRIVATE_LAST] xselinux_private = [
    PRIVATE_SCREEN: TRUE,
    PRIVATE_CLIENT: TRUE,
    PRIVATE_WINDOW: TRUE,
    PRIVATE_PIXMAP: TRUE,
    PRIVATE_GC: TRUE,
    PRIVATE_CURSOR: TRUE,
    PRIVATE_COLORMAP: TRUE,
    PRIVATE_DEVICE: TRUE,
    PRIVATE_EXTENSION: TRUE,
    PRIVATE_SELECTION: TRUE,
    PRIVATE_PROPERTY: TRUE,
    PRIVATE_PICTURE: TRUE,
    PRIVATE_GLYPHSET: TRUE,
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
    PRIVATE_SCREEN: FALSE,
    PRIVATE_CLIENT: FALSE,
    PRIVATE_WINDOW: TRUE,
    PRIVATE_PIXMAP: TRUE,
    PRIVATE_GC: TRUE,
    PRIVATE_CURSOR: FALSE,
    PRIVATE_COLORMAP: FALSE,
    PRIVATE_DEVICE: FALSE,
    PRIVATE_EXTENSION: FALSE,
    PRIVATE_SELECTION: FALSE,
    PRIVATE_PROPERTY: FALSE,
    PRIVATE_PICTURE: TRUE,
    PRIVATE_GLYPHSET: FALSE,
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
        return FALSE;
    memset(cast(char*) new_privates + old_offset, '\0', bytes);
    *privates = cast(_Private*)new_privates;
    return TRUE;
}

private Bool dixMovePrivates(PrivatePtr* privates, int new_offset, uint bytes)
{
    memmove(cast(char*) *privates + bytes, *privates, new_offset - bytes);
    memset(*privates, '\0', bytes);
    return TRUE;
}

private Bool fixupOneScreen(ScreenPtr pScreen, FixupFunc fixup, uint bytes)
{
    uintptr_t old = void;
    char* new_ = void;
    int size = void;

    old = cast(uintptr_t) pScreen.devPrivates;
    size = global_keys[PRIVATE_SCREEN].offset;
    if (!fixup (&pScreen.devPrivates, size, bytes))
        return FALSE;

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
    return TRUE;
}

private Bool fixupScreens(FixupFunc fixup, uint bytes)
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        if (!fixupOneScreen (walkScreen, fixup, bytes))
            return FALSE;
    });
    mixin(DIX_FOR_EACH_GPU_SCREEN!("{
        if (!fixupOneScreen (walkScreen, fixup, bytes))
            return FALSE;
    }"));
    return TRUE;
}

private Bool fixupServerClient(FixupFunc fixup, uint bytes)
{
    if (serverClient)
        return fixup(&serverClient.devPrivates, global_keys[PRIVATE_CLIENT].offset,
                     bytes);
    return TRUE;
}

private Bool fixupExtensions(FixupFunc fixup, uint bytes)
{
    ExtensionEntry* extension = void;

    for (ubyte major = EXTENSION_BASE; ((extension = GetExtensionEntry(major)) !is null);
         major++)
        if (!fixup
            (&extension.devPrivates, global_keys[PRIVATE_EXTENSION].offset, bytes))
            return FALSE;
    return TRUE;
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
            return FALSE;
    }"));
    return TRUE;
}

private Bool fixupDeviceList(DeviceIntPtr device, FixupFunc fixup, uint bytes)
{
    while (device) {
        if (!fixup(&device.devPrivates, global_keys[PRIVATE_DEVICE].offset, bytes))
            return FALSE;
        device = device.next;
    }
    return TRUE;
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
        return TRUE;
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
                    return FALSE;
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
            return FALSE;
        offset = global_keys[type].offset;
        global_keys[type].offset += bytes;
        grow_screen_specific_set(type, bytes);
    }

    /* Setup this key */
    key.offset = offset;
    key.size = size;
    key.initialized = TRUE;
    key.type = type;
    key.allocated = FALSE;
    key.next = global_keys[type].key;
    global_keys[type].key = key;

    return TRUE;
}

Bool dixRegisterScreenPrivateKey(DevScreenPrivateKeyPtr screenKey, ScreenPtr pScreen, DevPrivateType type, uint size)
{
    DevPrivateKey key = void;

    if (!dixRegisterPrivateKey(&screenKey.screenKey, PRIVATE_SCREEN, 0))
        return FALSE;
    key = cast(_DevPrivateKeyRec*)dixGetPrivate(&pScreen.devPrivates, &screenKey.screenKey);
    if (key !is null) {
        assert(key.size == size);
        assert(key.type == type);
        return TRUE;
    }
    key = cast(DevPrivateKeyRec*) calloc(1, DevPrivateKeyRec.sizeof);
    if (!key)
        return FALSE;
    if (!dixRegisterPrivateKey(key, type, size)) {
        free(key);
        return FALSE;
    }
    key.allocated = TRUE;
    dixSetPrivate(&pScreen.devPrivates, &screenKey.screenKey, key);
    return TRUE;
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
            return FALSE;
    }

    _dixInitPrivates(privates, p, type);
    ++global_keys[type].allocated;

    return TRUE;
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

import dix.window;
import include.pixmapstr;


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
    if (type < mixin(ARRAY_SIZE!("offsets")))
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
        return TRUE;
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
    key.initialized = TRUE;
    key.type = type;
    key.allocated = FALSE;
    key.next = pScreen.screenSpecificPrivates[type].key;
    pScreen.screenSpecificPrivates[type].key = key;

    return TRUE;
}

/* Clean up screen-specific privates before CloseScreen */
void dixFreeScreenSpecificPrivates(ScreenPtr pScreen)
{
    for (DevPrivateType t = PRIVATE_XSELINUX; t < PRIVATE_LAST; t++) {
        for (DevPrivateKey key = pScreen.screenSpecificPrivates[t].key; key; key = key.next) {
            key.initialized = FALSE;
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
            key.initialized = FALSE;
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
        return TRUE;
    else
        return FALSE;
}
