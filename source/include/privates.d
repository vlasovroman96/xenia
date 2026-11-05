module include.privates;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

******************************************************************/

version (PRIVATES_H) {} else {
enum PRIVATES_H = 1;

//public import x11.Xdefs;
// //public import x11.Xosdefs;
// //public import x11.Xfuncproto;
public import core.stdc.assert_;
public import common.misc;
public import dix.privates;

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
 * @return      FALSE if it fails to allocate memory during its operation.
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

public import include.resource;

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

int _dixInitScreenPrivates(ScreenPtr pScreen, PrivatePtr* privates, void* addr, DevPrivateType type);

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
int dixFreePrivates(PrivatePtr privates, DevPrivateType type);

/*
 * Initialize privates by zeroing them
 */
int _dixInitPrivates(PrivatePtr* privates, void* addr, DevPrivateType type);

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
int dixResetPrivates();

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

}                          /* PRIVATES_H */
