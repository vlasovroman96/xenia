module dix.window_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2025 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.X;

public import dix.window;

enum string wTrackParent(string w,string field) = `(((` ~ w ~ `).optional ? 
                                    (` ~ w ~ `).optional.` ~ field ~ ` 
                                 : FindWindowWithOptional(` ~ w ~ `).optional.` ~ field ~ `))`;
enum string wUseDefault(string w,string field,string def) = `((` ~ w ~ `).optional ? 
                                    (` ~ w ~ `).optional.` ~ field ~ ` 
                                 : ` ~ def ~ `)`;

enum string wVisual(string w) = `` ~ wTrackParent!(w, `visual`) ~ ``;
enum string wCursor(string w) = `((` ~ w ~ `).cursorIsNone ? null : ` ~ wTrackParent!(w, `cursor`) ~ `)`;
enum string wColormap(string w) = `((` ~ w ~ `).drawable.class_ == InputOnly ? None : ` ~ wTrackParent!(w, `colormap`) ~ `)`;
enum string wDontPropagateMask(string w) = `` ~ wUseDefault!(w, `dontPropagateMask`, `DontPropagateMasks[(` ~ w ~ `).dontPropagate]`) ~ ``;
enum string wOtherEventMasks(string w) = `` ~ wUseDefault!(w, `otherEventMasks`, `0`) ~ ``;
enum string wOtherClients(string w) = `` ~ wUseDefault!(w, `otherClients`, `null`) ~ ``;
enum string wOtherInputMasks(string w) = `` ~ wUseDefault!(w, `inputMasks`, `null`) ~ ``;
enum string wPassiveGrabs(string w) = `` ~ wUseDefault!(w, `passiveGrabs`, `null`) ~ ``;
enum string wBackingBitPlanes(string w) = `` ~ wUseDefault!(w, `backingBitPlanes`, `~0L`) ~ ``;
enum string wBackingPixel(string w) = `` ~ wUseDefault!(w, `backingPixel`, `0`) ~ ``;
enum string wBoundingShape(string w) = `` ~ wUseDefault!(w, `boundingShape`, `null`) ~ ``;
enum string wClipShape(string w) = `` ~ wUseDefault!(w, `clipShape`, `null`) ~ ``;
enum string wInputShape(string w) = `` ~ wUseDefault!(w, `inputShape`, `null`) ~ ``;

enum string SameBackground(string as, string a, string bs, string b) = `
    ((` ~ as ~ `) == (` ~ bs ~ `) && ((` ~ as ~ `) == None ||				
                      (` ~ as ~ `) == ParentRelative ||			
                      SamePixUnion(` ~ a ~ `,` ~ b ~ `,` ~ as ~ ` == BackgroundPixel)))`;

enum string SameBorder(string as, string a, string bs, string b) = `EqualPixUnion(` ~ as ~ `, ` ~ a ~ `, ` ~ bs ~ `, ` ~ b ~ `)`;

/*
 * @brief create a window
 *
 * Creates a window with given XID, geometry, etc
 *
 * @return pointer to new Window or NULL on error (see error pointer)
 */
// WindowPtr dixCreateWindow(Window wid, WindowPtr pParent, int x, int y, uint w, uint h, uint bw, uint windowclass, Mask vmask, XID* vlist, int depth, ClientPtr client, VisualID visual, int* error);
/*
 * @brief Make sure the window->optional structure exists.
 *
 * allocate if window->optional == NULL, otherwise do nothing.
 *
 * @param pWin the window to operate on
 * @return False if allocation failed, otherwise True
 */
// Bool MakeWindowOptional(WindowPtr pWin);

/*
 * @brief check whether a window (ID) is a screen root window
 *
 * The underlying resource query is explicitly done on behalf of serverClient,
 * so XACE resource hooks don't recognize this as a client action.
 * It's explicitly designed for use in hooks that don't wanna cause unncessary
 * traffic in other XACE resource hooks: things done by the serverClient usually
 * considered safe enough for not needing any additional security checks.
 * (we don't have any way for completely skipping the XACE hook yet)
 */
Bool dixWindowIsRoot(Window window);

/*
 * @brief lower part of X_CreateWindow request handler.
 * Called by ProcCreateWindow() as well as PanoramiXCreateWindow()
 */
// int DoCreateWindowReq(ClientPtr client, xCreateWindowReq* stuff, XID* xids);

// void PrintPassiveGrabs();
// void PrintWindowTree();

 /* _XSERVER_DIX_WINDOW_PRIV_H */
