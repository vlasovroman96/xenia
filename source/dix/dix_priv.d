module dix.dix_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
/* This file holds global DIX settings to be used inside the Xserver,
 *  but NOT supposed to be accessed directly by external server modules like
 *  drivers or extension modules. Thus the definitions here are not part of the
 *  Xserver's module API/ABI.
 */

//public import x11.Xdefs;
// // //public import x11.Xfuncproto;
//public import externs.X11.extensions.XI;

public import dix.input_priv;
public import dix.resource_priv;
public import dix.rpcbuf_priv;

public import dix.callback;
public import include.cursor;
public import include.dix;
public import include.events;
public import include.gc;
public import include.input;
public import include.os;
public import include.resource;
public import include.window;
public import dix.resource;
public import dix.dixutils;
public import dix.globals;
public import dix.events;

import os.io;

/* pad scanline to a longword */
enum BITMAP_SCANLINE_UNIT =    32;

enum string LEGAL_NEW_RESOURCE(string id,string client) = `
        if (!LegalNewID((` ~ id ~ `), (` ~ client ~ `))) {      
            (` ~ client ~ `).errorValue = (` ~ id ~ `);        
            return BadIDChoice;                 
        }`;                                       

import std.conv;
/* static assert for protocol structure sizes */
version (__size_assert) {} else {
    import std.conv;
    import std.string;
enum __size_assert(alias what, size_t howmuch) = `
  alias _size_wrong_ = char[(`~what.stringof~`.sizeof == `~howmuch.stringof~`) ? 1 : -1];`;
}
mixin template XTYPE_SIZE_ASSERT(alias typename) {
    mixin(__size_assert!(typename, typename.sizeof));
};

/* server setting: maximum size for big requests */
enum MAX_BIG_REQUEST_SIZE = 4194303;
// c_long maxBigRequestSize;

// char dispatchExceptionAtReset;
// int terminateDelay;
Bool touchEmulatePointer;

alias HWEventQueueType = int;
alias HWEventQueuePtr = HWEventQueueType*;

HWEventQueuePtr[2] checkForInput;

 /* -retro mode */
// Bool party_like_its_1989;

/* needed by libglx and libglamor (server modules) */
// bool enableIndirectGLX;

/*
 * @brief callback right after one screen's root window has been initialized
 *
 * For extensions that need additional setup after root window is completely
 * initialized (eg. possible to create new windows), but before any client
 * can connect. Called once per screen (supplied as arg) - the screen's
 * CreateWindow proc already had been called on the root window.
 *
 * Not for DDXs / drivers: those already informed by screen's CreateWindow
 * proc being called on the root window.
 */
CallbackListPtr PostInitRootWindowCallback;

pragma(inline, true) bool InputCheckPending()
{
    return (*checkForInput[0] != *checkForInput[1]);
}

pragma(inline, true) void SetInputCheck(HWEventQueuePtr c0, HWEventQueuePtr c1)
{
    checkForInput[0] = c0;
    checkForInput[1] = c1;
}

void ClearWorkQueue();
void ProcessWorkQueue();
// void ProcessWorkQueueZombies();

// void CloseDownClient(ClientPtr client);
ClientPtr GetCurrentClient();
// void InitClient(ClientPtr client, int i, void* ospriv);

// int FillFontPath(x_rpcbuf_t* rpcbuf);

/* lookup builtin color by name */
Bool dixLookupBuiltinColor(char* name, uint len, ushort* pred, ushort* pgreen, ushort* pblue);

void DeleteWindowFromAnySaveSet(WindowPtr pWin);

enum string VALIDATE_DRAWABLE_AND_GC(string drawID, string pDraw, string mode) = `                                                           
        int tmprc = dixLookupDrawable(&(` ~ pDraw ~ `), ` ~ drawID ~ `, client, M_ANY, ` ~ mode ~ `); 
        if (tmprc != Success)                                           
            return tmprc;                                               
        tmprc = dixLookupGC(&(pGC), stuff.gc, client, DixUseAccess);   
        if (tmprc != Success)                                           
            return tmprc;                                               
        if ((pGC.depth != ` ~ pDraw ~ `.depth) || (pGC.pScreen != ` ~ pDraw ~ `.pScreen)) 
            return BadMatch;                                            
        if (pGC.serialNumber != ` ~ pDraw ~ `.serialNumber)                   
            ValidateGC(` ~ pDraw ~ `, pGC);`
        ;

// int dixLookupGC(GCPtr* result, XID id, ClientPtr client, Mask access_mode);

// int dixLookupResourceOwner(ClientPtr* result, XID id, ClientPtr client, Mask access_mode);

// Bool CreateConnectionBlock();

// void EnableLimitedSchedulingLatency();

// void DisableLimitedSchedulingLatency();

int dix_main(int argc, char** argv, char** envp);

// void SetMaskForEvent(int deviceid, Mask mask, int event);

// void EnqueueEvent(InternalEvent* ev, DeviceIntPtr device);

void PlayReleasedEvents();

// void ActivatePointerGrab(DeviceIntPtr mouse, GrabPtr grab, TimeStamp time, Bool autoGrab);

// void DeactivatePointerGrab(DeviceIntPtr mouse);

// void ActivateKeyboardGrab(DeviceIntPtr keybd, GrabPtr grab, TimeStamp time, Bool passive);

// void DeactivateKeyboardGrab(DeviceIntPtr keybd);

// BOOL ActivateFocusInGrab(DeviceIntPtr dev, WindowPtr old, WindowPtr win);

// void AllowSome(ClientPtr client, TimeStamp time, DeviceIntPtr thisDev, int newState);

// void ReleaseActiveGrabs(ClientPtr client);

// GrabPtr CheckPassiveGrabsOnWindow(WindowPtr pWin, DeviceIntPtr device, InternalEvent* event, BOOL checkCore, BOOL activate);

// int DeliverDeviceEvents(WindowPtr pWin, InternalEvent* event, GrabPtr grab, WindowPtr stopAt, DeviceIntPtr dev);

// int DeliverOneGrabbedEvent(InternalEvent* event, DeviceIntPtr dev, InputLevel level);

void DeliverTouchEvents(DeviceIntPtr dev, TouchPointInfoPtr ti, InternalEvent* ev, XID resource);

Bool DeliverGestureEventToOwner(DeviceIntPtr dev, GestureInfoPtr gi, InternalEvent* ev);

// void InitializeSprite(DeviceIntPtr pDev, WindowPtr pWin);
// void FreeSprite(DeviceIntPtr pDev);
// void UpdateSpriteForScreen(DeviceIntPtr pDev, ScreenPtr pScreen);

// Bool CheckDeviceGrabs(DeviceIntPtr device, InternalEvent* event, WindowPtr ancestor);

// void DeliverFocusedEvent(DeviceIntPtr keybd, InternalEvent* event, WindowPtr window);

// int DeliverGrabbedEvent(InternalEvent* event, DeviceIntPtr thisDev, Bool deactivateGrab);

// void FreezeThisEventIfNeededForSyncGrab(DeviceIntPtr thisDev, InternalEvent* event);

// void FixKeyState(DeviceEvent* event, DeviceIntPtr keybd);

// void RecalculateDeliverableEvents(WindowPtr pWin);

// void DoFocusEvents(DeviceIntPtr dev, WindowPtr fromWin, WindowPtr toWin, int mode);

int SetInputFocus(ClientPtr client, DeviceIntPtr dev, Window focusID, CARD8 revertTo, Time ctime, Bool followOK);

// int GrabDevice(ClientPtr client, DeviceIntPtr dev, uint this_mode, uint other_mode, Window grabWindow, uint ownerEvents, Time ctime, GrabMask* mask, int grabtype, Cursor curs, Window confineToWin, CARD8* status);

void InitEvents();

void CloseDownEvents();

// void DeleteWindowFromAnyEvents(WindowPtr pWin, Bool freeResources);

// Mask EventMaskForClient(WindowPtr pWin, ClientPtr client);

// Bool CheckMotion(DeviceEvent* ev, DeviceIntPtr pDev);

// int SetClientPointer(ClientPtr client, DeviceIntPtr device);

Bool IsInterferingGrab(ClientPtr client, DeviceIntPtr dev, xEvent* events);

int XItoCoreType(int xi_type);

// Bool DevHasCursor(DeviceIntPtr pDev);

Bool IsPointerEvent(InternalEvent* event);

Bool IsTouchEvent(InternalEvent* event);

Bool IsGestureEvent(InternalEvent* event);

Bool IsGestureBeginEvent(InternalEvent* event);

Bool IsGestureEndEvent(InternalEvent* event);

void CopyKeyClass(DeviceIntPtr device, DeviceIntPtr master);

// int CorePointerProc(DeviceIntPtr dev, int what);

// int CoreKeyboardProc(DeviceIntPtr dev, int what);

alias xQueryFontReplyPtr = xQueryFontReply*;
// void QueryFont(FontPtr pFont, xQueryFontReplyPtr pReply, int nProtoCCIStructs);

// Bool whiteRoot;

// /*volatile*/ char isItTimeToYield;

/* bit values for dispatchException */
enum DE_TERMINATE = 2;
enum DE_PRIORITYCHANGE = 4     /* set when a client's priority changes */;

// /*volatile*/ char dispatchException;

// int ScreenSaverBlanking;
// int ScreenSaverAllowExposures;
// int defaultScreenSaverBlanking;
// int defaultScreenSaverAllowExposures;
const(char)* display;
int displayfd = -1;;
// Bool explicit_display;

Bool disableBackingStore;
Bool enableBackingStore;

/* in generated BuiltInAtoms.c */
// void MakePredeclaredAtoms();

void dixFreeScreen(ScreenPtr pScreen);

/*
 * @brief call the screen's UnrealizeWindow proc
 *
 * Calls the Screen's UnrealizeWindow proc and sets pWin->realized
 * to FALSE.
 *
 * @param pWin the window that's being unrealized
 */
// void dixScreenRaiseUnrealizeWindow(WindowPtr pWin);

/*
 * @brief call screen's window destructors
 * @see dixScreenHookWindowDestroy
 * @param pWin the window thats being destroyed
 * @result the ScreenRec's DestroyWindow() return value
 *
 * Call the pluggable window destructors that extensions might have registered on
 * the screen, and finally call ScreenRec's DestroyWindow proc.
 *
 * Should only be called by DIX itself.
 */
// int dixScreenRaiseWindowDestroy(WindowPtr pWin);

/*
 * @brief call screen's window position notification hooks
 * @see dixScreenHookWindowPosition
 * @param pWin the window to notify on
 *
 * Call the pluggable window position hooks that extensions might have registered on
 * the screen, and finally call ScreenRec's PositionWindow proc.
 *
 * Should only be called by DIX itself.
 */
// void dixScreenRaiseWindowPosition(WindowPtr pWin, uint x, uint y);

/*
 * @brief call screen's close hooks
 * @see dixScreenHookClose
 * @param pScreen the screen being closed
 *
 * Call the pluggable screen close hooks that extensions might have registered on
 * the screen, and finally call ScreenRec's CloseScreen proc.
 *
 * Should only be called by DIX itself.
 */
void dixScreenRaiseClose(ScreenPtr pScreen);

/*
 * @brief call screen's PixmapDestroy hook
 * @see dixScreenHookPixmapDestroy
 * @param pPixmap the pixmap being destroyed
 *
 * Call the pluggable pixmap destroy pixmap hooks that extensions might have
 * registered on the screen.
 * Note that it's *only* called, when the pixmap is really being destroyed
 * (instead of just unref'ed)
 *
 * Should only be called by DIX itself, by dixDestroyPixmap()
 * It must be called *before* the ScreenRec->DestroyPixmap() is called, any
 * only if the reference counter reaches 1.
 */
void dixScreenRaisePixmapDestroy(PixmapPtr pPixmap);

/*
 * @brief call screen's CreateScreenResources chain
 * @see dixScreenHookPostCreateResources
 * @param pScreen the screen to run on
 *
 * Call the screen's CreateScreenResources() proc, and if it returns TRUE,
 * run the installed hooks afterwards.
 *
 * Should only be called by DIX itself.
 */
Bool dixScreenRaiseCreateResources(ScreenPtr pScreen);

/*
 * @brief mark event ID as critical
 * @param event the event to add to the critical events bitmap
 */
// void SetCriticalEvent(int event);

/**
 * @brief try to deliver (single) event to interested parties.
 *
 * @param pWindow       target window
 * @param pEvent        event to be delivered
 * @param filter        filter mask based on event type
 * @param skipClient    don't deliver to this client (if not NULL)
 * @return TRUE when event was delivered
 */
// Bool MaybeDeliverEventToClient(WindowPtr pWindow, xEvent* pEvent, Mask filter, ClientPtr skipClient);

/*
 * @brief select window events to listen on
 *
 * @param pWindow   window to listen on
 * @param pClient   the client that's listening on the events
 * @param mask      mask of events to listen on
 * @return X error code
 */
// XRetCode EventSelectForWindow(WindowPtr pWindow, ClientPtr pClient, Mask mask);

/*
 * @brief set block propagation of specific events on window
 *
 * @param pWindow       window to act on
 * @param pClient       client to act on
 * @param mask          mask of events to not propagate
 * @param checkOptional set to w/ TRUE when window's optional structure changed
 * @return X error code
 */
// int EventSuppressForWindow(WindowPtr pWindow, ClientPtr pClient, Mask mask, Bool* checkOptional);

/*
 * @brief allocate new ClientRec and initialize it
 *
 * Returns NULL on allocation failure or when client limit reached.
 *
 * @param ospriv pointer to OS layer's internal data
 * @return pointer to new ClientRec or NULL on failure
 */
// ClientPtr NextAvailableClient(void* ospriv);

/*
 * @brief mark exception on client - will be closed down later
 *
 * @param pClient pointer to client that has exception
 */
// void dixMarkClientException(ClientPtr pClient);

alias ClientSleepProcPtr = Bool function(ClientPtr client, void* closure);

/*
 * @brief put a client to sleep
 *
 * @param pClient   the client to put into sleep
 * @param func  called when client wakes up
 * @param closure   data passed to the callback function
 */
// Bool ClientSleep(ClientPtr pClient, ClientSleepProcPtr func, void* closure);

/*
 * @brief signal to sleeping client there's work to do
 *
 * @param pClient   the client to signal to
 * @return TRUE on success
 */
// Bool dixClientSignal(ClientPtr pClient);

enum CLIENT_SIGNAL_ANY = (cast(void *)-1);
/*
 * @brief signal to all sleeping clients matching client, func, closure
 *
 * If any of the client, func and closure parameters may be CLIENT_SIGNAL_ANY,
 * so those will be matching any value
 *
 * @param pClient   match for client
 * @param func      match for callback function
 * @param closure   match for callback closure
 * @return number of matched / queued clients
 */
int ClientSignalAll(ClientPtr pClient, ClientSleepProcPtr func, void* closure);

/*
 * @brief wake up a client and restart request processing of this client
 *
 * @param pClient pointer to client structure
 */
// void ClientWakeup(ClientPtr pclient);

/*
 * @brief check whether client is asleep
 *
 * @param pClient pointer to client structure
 * @return TRUE if client is sleeping and has no work to do
 */
// Bool ClientIsAsleep(ClientPtr pClient);

/*
 * @brief send error packet (xError) to client
 *
 * @param pClient     pointer to client structure
 * @param majorCode   major opcode of failed request
 * @param minorCode   minor opcode of failed request
 * @param resId       ID of resource the failure occured on
 * @param errorCode   error code value
 */
// void SendErrorToClient(ClientPtr pClient, CARD8 majorCode, CARD16 minorCode, XID resId, BYTE errorCode);

/*
 * @brief send GraphicsExposure events for given region to client

 * Sends a series of GraphicsExposure events spanning the given region to the
 * client. If region is empty or NULL, sending NoExpose event instead.
 *
 + @param pClient     the client to send events to
 * @param pRegion     the region the events are based on
 * @param drawable    ID of the drawable the events are related to
 * @param majorOpcode major opcode of request which caused the expose event
 * @param minorOpcode minor opcode of request which caused the expose event
 */
// public import dix.dispatch;

// void SendGraphicsExpose(ClientPtr pClient, RegionPtr pRegion, XID drawable, BYTE majorOpcode, CARD16 minorOpcode);

/*
 * @brief alter the SaveSet of a window (see automatic reparenting when client gone)
 *
 * @param pClient pointer to client structure
 * @param pWindow pointer to window structure whose SaveSet is changed
 * @param mode    what to do when client goes away
 * @param toRoot  TRUE to reparent to root when parent's client gone
 * @param map     TRUE if window shall remain mapped
 * @return X return code
 */
// XRetCode AlterSaveSetForClient(ClientPtr pClient, WindowPtr pWin, uint mode, Bool toRoot, Bool map);

/**
 * @brief deliver the given events to the given client.
 *
 * More than one event may be delivered at a time. This is the case with
 * DeviceMotionNotifies which may be followed by DeviceValuator events.
 *
 * TryClientEvents() is the last station before actually writing the events to
 * the socket. Anything that is not filtered here, will get delivered to the
 * client.
 * An event is only delivered if
 *   - mask and filter match up.
 *   - no other client has a grab on the device that caused the event.
 *
 *
 * @param client The target client to deliver to.
 * @param dev The device the event came from. May be NULL.
 * @param pEvents The events to be delivered.
 * @param count Number of elements in pEvents.
 * @param mask Event mask as set by the window.
 * @param filter Mask based on event type.
 * @param grab Possible grab on the device that caused the event.
 *
 * @return 1 if event was delivered, 0 if not or -1 if grab was not set by the
 * client.
 */
// void  TryClientEvents(ClientPtr pClient, DeviceIntPtr device, xEventPtr pEvents, size_t count, Mask mask, Mask filter, GrabPtr grab);

/**
 * @brief deliver event to a window and its immediate parent.
 *
 * Used for most window events (CreateNotify, ConfigureNotify, etc.).
 * Not useful for events that propagate up the tree or extension events
 *
 * In case of a ReparentNotify event, the event will be delivered to the
 * otherParent as well.
 *
 * @param pWindow       Window to deliver events to.
 * @param events        Events to deliver.
 * @param count         number of events in xE.
 * @param otherParent   Used for ReparentNotify events.
 */
// EventDeliveryState DeliverEvents(WindowPtr pWindow, xEventPtr events, size_t nEvents, WindowPtr otherParent);

/**
 * @brief deliver events to a window.
 *
 * At this point, we do not yet know if the event actually needs to be delivered.
 * May activate a grab if the event is a button press.
 *
 * Core events are always delivered to the window owner. If the filter is
 * something other than CantBeFiltered, the event is also delivered to other
 * clients with the matching mask on the window.
 *
 * More than one event may be delivered at a time. This is the case with
 * DeviceMotionNotifies which may be followed by DeviceValuator events.
 *
 * @param pWindow   The window that would get the event.
 * @param pEvents   The events to be delivered.
 * @param count     Number of elements in pEvents.
 * @param filter    Mask based on event type.
 * @param grab      Possible grab on the device that caused the event.
 *
 * @return a positive number if at least one successful delivery has been
 * made, 0 if no events were delivered, or a negative number if the event
 * has not been delivered _and_ rejected by at least one client.
 */
// int DeliverEventsToWindow(DeviceIntPtr pDev, WindowPtr pWindow, xEventPtr pEvents, size_t count, Mask filter, GrabPtr grab);

/*
 * @brief callback when root window has is finalized
 */
/* only exported temporariy for Nvidia legacy */
CallbackListPtr RootWindowFinalizeCallback;

/*
 * @brief do post actions necessary when window got a new cursor
 *
 * currently just for updating cursors on input devices
 *
 * @param pWindow   window that just got a new cursor
 */
// void WindowHasNewCursor(WindowPtr pWin);

/*
 * @brief do post actions necessary when windows have been restructured
 *
 * currently updates the sprite position and the sprite's cursor.
 */
// void WindowsRestructured();

/*
 * @brief do post actions necessary whn screens have been restructured
 *
 * currently eg. fixing up cursors and their confinements (randr)
 */
// void ScreenRestructured(ScreenPtr pScreen);

/*
 * @brief destructor for X11_RESTYPE_OTHERCLIENT resources
 *
 * @param value     pointer to resource data
 * @param id        ID of the resource
 * @return (undefined/ignored)
 */
int OtherClientGone(void* value, XID id);

/*
 * @brief check whether one window is parent of another
 *
 * @param parent    the alleged parent
 * @param child     the alleged child
 * @return TRUE if `child` is a child window of `parent`
 */
// Bool WindowIsParent(WindowPtr parent, WindowPtr child);

/*
 * @brief call the block handlers
 *
 * @param timeout   os-specific timeout value
 */
void BlockHandler(void* timeout);

/*
 * @brief call the wakeup handlers
 *
 * @param result    32 bit opaque value from the wait
 */
void WakeupHandler(int result);

/*
 * @brief initialize the block and wakeup handlers
 */
void InitBlockAndWakeupHandlers();

/*
 * @brief retrieve owning client for given XID
 *
 * just lookup by ID space, the resource doens't need to actually exist
 */
pragma(inline, true) private ClientPtr dixLookupXIDOwner(XID xid)
{
    int clientId = dixClientIdForXID(xid);
    if (clientId < currentMaxClients)
        return clients[clientId];
    return null;
}

/*
 * @brief make atom from null-terminated string
 *
 * if atom already existing, return the existing Atom ID
 *
 * @param name  the atom name
 * @return atom ID
 */
pragma(inline, true) Atom dixAddAtom(const(char)* name) {
    return MakeAtom(name, cast(uint)strlen(name), TRUE);
}

/*
 * @brief retrieve atom ID by name
 *
 * if the atom doesn't exist yet, 0 / NONE is returned
 *
 * @param name  the atom name
 * @return atom ID
 */
pragma(inline, true) Atom dixGetAtomID(const(char)* name) {
    return MakeAtom(name, cast(uint)strlen(name), FALSE);
}

/*
 * transmit raw event into client's buffer
 * the struct already needs to be filled with all on-wire data, and
 * byte-swapping must have been done (if client is swapped)
 *
 * the sequenceNumber field is automatically filled and byte-swapped
 *
 * @param client      pointer to the client (ClientPtr)
 * @param event       pointer to the event
 * @return            return value of WriteToClient
 */
pragma(inline, true) int xmitClientEvent(ClientPtr pClient, xEvent ev)
{
    ev.u.u.sequenceNumber = cast(CARD16)pClient.sequence; /* shouldn't go above 64k */

    if (pClient.swapped)
        swaps(&ev.u.u.sequenceNumber);

    return WriteToClient(pClient, xEvent.sizeof, &ev);
}

/*
 * allocate color for given client
 * the colors channel values need to be filled into the fields pointed
 * to by the parameters, and the actually allocated ones are returned there
 *
 * @param client  pointer to client
 * @param cmap    XID of the cmap to use
 * @param red     pointer to red channel value
 * @param green   pointer to green channel value
 * @param blue    pointer to blue channel value
 * @param pixel   pointer to return buffer for pixel value
 * @return        X11 error code
 */
// int dixAllocColor(ClientPtr client, Colormap cmap, CARD16* red, CARD16* green, CARD16* blue, CARD32* pixel);

// void ReplyNotSwappd(ClientPtr pClient, int size, void* pbuf);

/*
 * Byte swap a list of CARD32s
 *
 * @param list    pointer to list of clients
 * @param count   amount of CARD32s to swap
 */
pragma(inline, true) void SwapLongs(CARD32* list, c_ulong count) {
    while (count >= 8) {
        swapl(list + 0);
        swapl(list + 1);
        swapl(list + 2);
        swapl(list + 3);
        swapl(list + 4);
        swapl(list + 5);
        swapl(list + 6);
        swapl(list + 7);
        list += 8;
        count -= 8;
    }
    if (count != 0) {
        do {
            swapl(list);
            list++;
        } while (--count != 0);
    }
}

enum string SwapRestL(string stuff) = `
    SwapLongs(
        cast(CARD32*)(` ~ stuff ~ ` + 1),
        (
            client.req_len - 
                (
                    (
                        (*` ~ stuff ~ `).sizeof >> 2
                    )
                )
        )
    );`;

 /* _XSERVER_DIX_PRIV_H */
