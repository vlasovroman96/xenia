module glx.glxcmds;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * SGI FREE SOFTWARE LICENSE B (Version 2.0, Sept. 18, 2008)
 * Copyright (C) 1991-2000 Silicon Graphics, Inc. All Rights Reserved.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice including the dates of first publication and
 * either this permission notice or a reference to
 * http://oss.sgi.com/projects/FreeB/
 * shall be included in all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
 * OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL
 * SILICON GRAPHICS, INC. BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY,
 * WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF
 * OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 * Except as contained in this notice, the name of Silicon Graphics, Inc.
 * shall not be used in advertising or otherwise to promote the sale, use or
 * other dealings in this Software without prior written authorization from
 * Silicon Graphics, Inc.
 */

import build.dix_config;

import core.stdc.string;
import core.stdc.assert_;
import externs.glxtokens;
// //import externs.X11.extensions.presenttokens;
import os.utils;

import dix.dix_priv;
import dix.resource_priv;
import dix.request_priv;
import dix.rpcbuf_priv;
import dix.screenint_priv;
import dix.window_priv;
import os.bug_priv;
import present.present_priv;
//  import Xext.glx.fix;
// public import externs.glxproto;
public import externs.glxtokens;

import glx.glxserver;
import glx.unpack;
import include.pixmapstr;
import include.windowstr;
import glx.glxutil;
import glx.glxext;
import glx.indirect_dispatch;
import glx.indirect_table;
import glx.indirect_util;
import include.protocol_versions;
import include.glxvndabi;
import Xext.xace;
import glx.glxscreens_h;
import glx.vndext;
import externs.attrs;
import os.io;
// import externs.glxproto;
import dix.events;
import externs.X11.extensions.presenttokens;
import Xext.glx.fix;

alias __GLX_SINGLE_HDR_SIZE = sz_xGLXSingleReq;
alias __GLX_VENDPRIV_HDR_SIZE = sz_xGLXVendorPrivateReq;

// //!! EDX: Duuuude...
alias UINT32_MAX = core.stdc.stdint.UINT32_MAX;
alias INT32 = x11.Xmd.INT32;

// alias CARD32 = x11.Xmd.CARD32;
// alias BadLength = x11.X.BadLength;
// alias BadAlloc = x11.X.BadAlloc;
// alias BadMatch = x11.X.BadMatch;
// alias None = x11.X.None;
// alias Success = x11.X.Success;
// alias BadValue = x11.X.BadValue;
// alias BadRequest = x11.X.BadRequest;
// alias INT32 = x11.Xmd.INT32;
// alias BadImplementation = x11.X.BadImplementation;
// alias ZPixmap = x11.X.ZPixmap;
// alias IncludeInferiors = x11.X.IncludeInferiors;
// alias BadAccess = x11.X.BadAccess;
// alias BadPixmap = x11.X.BadPixmap;
// alias BadPixmap = x11.X.BadPixmap;




private char[4] GLXServerVendorName = "SGI";

int validGlxScreen(ClientPtr client, int screen, __GLXscreen** pGlxScreen, int* err)
{
    /*
     ** Check if screen exists.
     */
    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)screen);
    if (!pScreen) {
        client.errorValue = cast(uint)screen;
        *err = BadValue;
        return FALSE;
    }
    *pGlxScreen = xeniaGlxGetScreen(pScreen);

    return TRUE;
}
alias XID = x11.X.XID;

int validGlxFBConfig(ClientPtr client, __GLXscreen* pGlxScreen, XID id, __GLXconfig** config, int* err)
{
    __GLXconfig* m = void;

    for (m = pGlxScreen.fbconfigs; m !is null; m = m.next)
        if (m.fbconfigID == id) {
            *config = m;
            return TRUE;
        }

    client.errorValue = cast(uint)id;
    *err = __glXError(GLXBadFBConfig);

    return FALSE;
}

private int validGlxVisual(ClientPtr client, __GLXscreen* pGlxScreen, XID id, __GLXconfig** config, int* err)
{
    int i = void;

    for (i = 0; i < pGlxScreen.numVisuals; i++)
        if (pGlxScreen.visuals[i].visualID == id) {
            *config = pGlxScreen.visuals[i];
            return TRUE;
        }

    client.errorValue = cast(uint)id;
    *err = BadValue;

    return FALSE;
}

private int validGlxFBConfigForWindow(ClientPtr client, __GLXconfig* config, DrawablePtr pDraw, int* err)
{
    ScreenPtr pScreen = pDraw.pScreen;
    VisualPtr pVisual = null;
    XID vid = void;
    int i = void;

    vid = mixin(wVisual!("cast(WindowPtr)pDraw"));
    for (i = 0; i < pScreen.numVisuals; i++) {
        if (pScreen.visuals[i].vid == vid) {
            pVisual = &pScreen.visuals[i];
            break;
        }
    }

    mixin(BUG_RETURN_VAL!("!pVisual", "FALSE"));

    /* FIXME: What exactly should we check here... */
    if (pVisual is null ||
        pVisual.class_ != glxConvertToXVisualType(config.visualType) ||
        !(config.drawableType & GLX_WINDOW_BIT)) {
        client.errorValue = cast(uint)pDraw.id;
        *err = BadMatch;
        return FALSE;
    }

    return TRUE;
}

int validGlxContext(ClientPtr client, XID id, int access_mode, __GLXcontext** context, int* err)
{
    /* no ghost contexts */
    if (id & SERVER_BIT) {
        *err = __glXError(GLXBadContext);
        return FALSE;
    }

    *err = dixLookupResourceByType(cast(void**) context, id,
                                   __glXContextRes, client, access_mode);
    if (*err != Success || (*context).idExists == GL_FALSE) {
        client.errorValue = cast(uint)id;
        if (*err == BadValue || *err == Success)
            *err = __glXError(GLXBadContext);
        return FALSE;
    }

    return TRUE;
}

int validGlxDrawable(ClientPtr client, XID id, int type, int access_mode, __GLXdrawable** drawable, int* err)
{
    int rc = void;

    rc = dixLookupResourceByType(cast(void**) drawable, id,
                                 __glXDrawableRes, client, access_mode);
    if (rc != Success && rc != BadValue) {
        *err = rc;
        client.errorValue = cast(uint)id;
        return FALSE;
    }

    /* If the ID of the glx drawable we looked up doesn't match the id
     * we looked for, it's because we looked it up under the X
     * drawable ID (see DoCreateGLXDrawable). */
    if (rc == BadValue ||
        (*drawable).drawId != id ||
        (type != GLX_DRAWABLE_ANY && type != (*drawable).type)) {
        client.errorValue = cast(uint)id;
        switch (type) {
        case GLX_DRAWABLE_WINDOW:
            *err = __glXError(GLXBadWindow);
            return FALSE;
        case GLX_DRAWABLE_PIXMAP:
            *err = __glXError(GLXBadPixmap);
            return FALSE;
        case GLX_DRAWABLE_PBUFFER:
            *err = __glXError(GLXBadPbuffer);
            return FALSE;
        case GLX_DRAWABLE_ANY:
            *err = __glXError(GLXBadDrawable);
            return FALSE;
        default: break;}
    }

    return TRUE;
}

void __glXContextDestroy(__GLXcontext* context)
{
    lastGLContext = null;
}

private void __glXdirectContextDestroy(__GLXcontext* context)
{
    __glXContextDestroy(context);
    free(context);
}

private int __glXdirectContextLoseCurrent(__GLXcontext* context)
{
    return GL_TRUE;
}

__GLXcontext* __glXdirectContextCreate(__GLXscreen* screen, __GLXconfig* modes, __GLXcontext* shareContext)
{
    __GLXcontext* context = void;

    context = cast(__GLXcontext*) cast(__GLXcontext*) calloc(1, __GLXcontext.sizeof);
    if (context is null)
        return null;

    context.config = modes;
    context.destroy = &__glXdirectContextDestroy;
    context.loseCurrent = &__glXdirectContextLoseCurrent;

    return context;
}

/**
 * Create a GL context with the given properties.  This routine is used
 * to implement \c glXCreateContext, \c glXCreateNewContext, and
 * \c glXCreateContextWithConfigSGIX.  This works because of the hack way
 * that GLXFBConfigs are implemented.  Basically, the FBConfigID is the
 * same as the VisualID.
 */

private int DoCreateContext(__GLXclientState* cl, GLXContextID gcId, GLXContextID shareList, __GLXconfig* config, __GLXscreen* pGlxScreen, GLboolean isDirect, int renderType)
{
    ClientPtr client = cl.client;
    __GLXcontext* glxc = void, shareglxc = void;
    int err = void;

    /*
     ** Find the display list space that we want to share.
     **
     ** NOTE: In a multithreaded X server, we would need to keep a reference
     ** count for each display list so that if one client destroyed a list that
     ** another client was using, the list would not really be freed until it
     ** was no longer in use.  Since this sample implementation has no support
     ** for multithreaded servers, we don't do this.
     */
    if (shareList == None) {
        shareglxc = null;
    }
    else {
        if (!validGlxContext(client, cast(uint)shareList, DixReadAccess,
                             &shareglxc, &err))
            return err;

        /* Page 26 (page 32 of the PDF) of the GLX 1.4 spec says:
         *
         *     "The server context state for all sharing contexts must exist
         *     in a single address space or a BadMatch error is generated."
         *
         * If the share context is indirect, force the new context to also be
         * indirect.  If the shard context is direct but the new context
         * cannot be direct, generate BadMatch.
         */
        if (shareglxc.isDirect && !isDirect) {
            client.errorValue = cast(uint)cast(uint)shareList;
            return BadMatch;
        }
        else if (!shareglxc.isDirect) {
            /*
             ** Create an indirect context regardless of what the client asked
             ** for; this way we can share display list space with shareList.
             */
            isDirect = GL_FALSE;
        }

        /* Core GLX doesn't explicitly require this, but GLX_ARB_create_context
         * does (see glx/createcontext.c), and it's assumed by our
         * implementation anyway, so let's be consistent about it.
         */
        if (shareglxc.pGlxScreen != pGlxScreen) {
            client.errorValue = cast(uint)shareglxc.pGlxScreen.pScreen.myNum;
            return BadMatch;
        }
    }

    /*
     ** Allocate memory for the new context
     */
    if (!isDirect) {
        /* Only allow creating indirect GLX contexts if allowed by
         * server command line.  Indirect GLX is of limited use (since
         * it's only GL 1.4), it's slower than direct contexts, and
         * it's a massive attack surface for buffer overflow type
         * errors.
         */
        if (!enableIndirectGLX) {
            client.errorValue = cast(uint)isDirect;
            return BadValue;
        }

        /* Without any attributes, the only error that the driver should be
         * able to generate is BadAlloc.  As result, just drop the error
         * returned from the driver on the floor.
         */
        glxc = pGlxScreen.createContext(pGlxScreen, config, shareglxc,
                                         0, null, &err);
    }
    else
        glxc = __glXdirectContextCreate(pGlxScreen, config, shareglxc);
    if (!glxc) {
        return BadAlloc;
    }

    /* Initialize the GLXcontext structure.
     */
    glxc.pGlxScreen = pGlxScreen;
    glxc.config = config;
    glxc.id = cast(uint)gcId;
    glxc.share_id = cast(uint)shareList;
    glxc.idExists = GL_TRUE;
    glxc.isDirect = isDirect;
    glxc.renderMode = GL_RENDER;
    glxc.renderType = renderType;

    /* The GLX_ARB_create_context_robustness spec says:
     *
     *     "The default value for GLX_CONTEXT_RESET_NOTIFICATION_STRATEGY_ARB
     *     is GLX_NO_RESET_NOTIFICATION_ARB."
     *
     * Without using glXCreateContextAttribsARB, there is no way to specify a
     * non-default reset notification strategy.
     */
    glxc.resetNotificationStrategy = GLX_NO_RESET_NOTIFICATION_ARB;

static if (GLX_CONTEXT_RELEASE_BEHAVIOR_ARB) {
    /* The GLX_ARB_context_flush_control spec says:
     *
     *     "The default value [for GLX_CONTEXT_RELEASE_BEHAVIOR] is
     *     CONTEXT_RELEASE_BEHAVIOR_FLUSH, and may in some cases be changed
     *     using platform-specific context creation extensions."
     *
     * Without using glXCreateContextAttribsARB, there is no way to specify a
     * non-default release behavior.
     */
    glxc.releaseBehavior = GLX_CONTEXT_RELEASE_BEHAVIOR_FLUSH_ARB;
}

    /* Add the new context to the various global tables of GLX contexts.
     */
    if (!__glXAddContext(glxc)) {
        (*glxc.destroy) (glxc);
        client.errorValue = cast(uint)cast(uint)gcId;
        return BadAlloc;
    }

    return Success;
}

int __glXDisp_CreateContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCreateContextReq* req = cast(xGLXCreateContextReq*) pc;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    if (!validGlxScreen(cl.client, req.screen, &pGlxScreen, &err))
        return err;
    if (!validGlxVisual(cl.client, pGlxScreen, req.visual, &config, &err))
        return err;

    return DoCreateContext(cl, req.context, req.shareList,
                           config, pGlxScreen, cast(ubyte)req.isDirect,
                           GLX_RGBA_TYPE);
}

int __glXDisp_CreateNewContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCreateNewContextReq* req = cast(xGLXCreateNewContextReq*) pc;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    if (!validGlxScreen(cl.client, req.screen, &pGlxScreen, &err))
        return err;
    if (!validGlxFBConfig(cl.client, pGlxScreen, req.fbconfig, &config, &err))
        return err;

    return DoCreateContext(cl, req.context, req.shareList,
                           config, pGlxScreen, cast(ubyte)req.isDirect,
                           req.renderType);
}

int __glXDisp_CreateContextWithConfigSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreateContextWithConfigSGIXReq* req = cast(xGLXCreateContextWithConfigSGIXReq*) pc;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateContextWithConfigSGIXReq);

    if (!validGlxScreen(cl.client, req.screen, &pGlxScreen, &err))
        return err;
    if (!validGlxFBConfig(cl.client, pGlxScreen, req.fbconfig, &config, &err))
        return err;

    return DoCreateContext(cl, req.context, req.shareList,
                           config, pGlxScreen, cast(ubyte)req.isDirect,
                           req.renderType);
}

int __glXDisp_DestroyContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXDestroyContextReq* req = cast(xGLXDestroyContextReq*) pc;
    __GLXcontext* glxc = void;
    int err = void;

    if (!validGlxContext(cl.client, req.context, DixDestroyAccess,
                         &glxc, &err))
        return err;

    glxc.idExists = GL_FALSE;
    if (glxc.currentClient) {
        XID ghost = FakeClientID(glxc.currentClient.index);

        if (!AddResource(cast(uint)ghost, __glXContextRes, glxc))
            return BadAlloc;
        ChangeResourceValue(glxc.id, __glXContextRes, null);
        glxc.id = ghost;
    }

    FreeResourceByType(req.context, __glXContextRes, FALSE);

    return Success;
}

__GLXcontext* __glXLookupContextByTag(__GLXclientState* cl, GLXContextTag tag)
{
    return cast(__GLXcontext*)glxServer.getContextTagPrivate(cl.client, tag);
}

private __GLXconfig* inferConfigForWindow(__GLXscreen* pGlxScreen, WindowPtr pWin)
{
    int i = void, vid = cast(int)mixin(wVisual!("pWin"));

    for (i = 0; i < pGlxScreen.numVisuals; i++)
        if (pGlxScreen.visuals[i].visualID == vid)
            return pGlxScreen.visuals[i];

    return null;
}

/**
 * This is a helper function to handle the legacy (pre GLX 1.3) cases
 * where passing an X window to glXMakeCurrent is valid.  Given a
 * resource ID, look up the GLX drawable if available, otherwise, make
 * sure it's an X window and create a GLX drawable one the fly.
 */
private __GLXdrawable* __glXGetDrawable(__GLXcontext* glxc, GLXDrawable drawId, ClientPtr client, int* error)
{
    DrawablePtr pDraw = void;
    __GLXdrawable* pGlxDraw = void;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    int rc = void;

    rc = dixLookupResourceByType(cast(void**)&pGlxDraw, cast(uint)drawId,
                                 __glXDrawableRes, client, DixWriteAccess);
    if (rc == Success &&
        /* If pGlxDraw->drawId == drawId, drawId is a valid GLX drawable.
         * Otherwise, if pGlxDraw->type == GLX_DRAWABLE_WINDOW, drawId is
         * an X window, but the client has already created a GLXWindow
         * associated with it, so we don't want to create another one. */
        (pGlxDraw.drawId == drawId ||
         pGlxDraw.type == GLX_DRAWABLE_WINDOW)) {
        if (glxc !is null &&
            glxc.config !is null &&
            glxc.config != pGlxDraw.config) {
            client.errorValue = cast(uint)cast(uint)drawId;
            *error = BadMatch;
            return null;
        }

        return pGlxDraw;
    }

    /* No active context and an unknown drawable, bail. */
    if (glxc is null) {
        client.errorValue = cast(uint)cast(uint)drawId;
        *error = BadMatch;
        return null;
    }

    /* The drawId wasn't a GLX drawable.  Make sure it's a window and
     * create a GLXWindow for it.  Check that the drawable screen
     * matches the context screen and that the context fbconfig is
     * compatible with the window visual. */

    rc = dixLookupDrawable(&pDraw, cast(uint)drawId, client, 0, DixGetAttrAccess);
    if (rc != Success || pDraw.type != DRAWABLE_WINDOW) {
        client.errorValue = cast(uint)cast(uint)drawId;
        *error = __glXError(GLXBadDrawable);
        return null;
    }

    pGlxScreen = glxc.pGlxScreen;
    if (pDraw.pScreen != pGlxScreen.pScreen) {
        client.errorValue = cast(uint)pDraw.pScreen.myNum;
        *error = BadMatch;
        return null;
    }

    config = glxc.config;
    if (!config)
        config = inferConfigForWindow(pGlxScreen, cast(WindowPtr)pDraw);
    if (!config) {
        /*
         * If we get here, we've tried to bind a no-config context to a
         * window without a corresponding fbconfig, presumably because
         * we don't support GL on it (PseudoColor perhaps). From GLX Section
         * 3.3.7 "Rendering Contexts":
         *
         * "If draw or read are not compatible with ctx a BadMatch error
         * is generated."
         */
        *error = BadMatch;
        return null;
    }

    if (!validGlxFBConfigForWindow(client, config, pDraw, error))
        return null;

    pGlxDraw = pGlxScreen.createDrawable(client, pGlxScreen, pDraw, cast(uint)drawId,
                                          GLX_DRAWABLE_WINDOW, cast(uint)drawId, config);
    if (!pGlxDraw) {
	*error = BadAlloc;
	return null;
    }

    /* since we are creating the drawablePrivate, drawId should be new */
    if (!AddResource(cast(uint)cast(uint)drawId, __glXDrawableRes, pGlxDraw)) {
        *error = BadAlloc;
        return null;
    }

    return pGlxDraw;
}

/*****************************************************************************/
/*
** Make an OpenGL context and drawable current.
*/

int xorgGlxMakeCurrent(ClientPtr client, GLXContextTag tag, XID drawId, XID readId, XID contextId, GLXContextTag newContextTag)
{
    __GLXclientState* cl = glxGetClient(client);
    __GLXcontext* glxc = null, prevglxc = null;
    __GLXdrawable* drawPriv = null;
    __GLXdrawable* readPriv = null;
    int error = void;

    /* Drawables but no context makes no sense */
    if (!contextId && (drawId || readId))
        return BadMatch;

    /* If either drawable is null, the other must be too */
    if ((drawId == None) != (readId == None))
        return BadMatch;

    /* Look up old context. If we have one, it must be in a usable state. */
    if (tag != 0) {
        prevglxc = cast(__GLXcontext*)glxServer.getContextTagPrivate(client, tag);

        if (prevglxc && prevglxc.renderMode != GL_RENDER) {
            /* Oops.  Not in render mode render. */
            client.errorValue = cast(uint)prevglxc.id;
            return __glXError(GLXBadContextState);
        }
    }

    /* Look up new context. It must not be current for someone else. */
    if (contextId != None) {
        if (!validGlxContext(client, contextId, DixUseAccess, &glxc, &error))
            return error;

        if ((glxc != prevglxc) && glxc.currentClient)
            return BadAccess;

        if (drawId) {
            int status = 0;
            drawPriv = __glXGetDrawable(glxc, drawId, client, &status);
            if (drawPriv is null)
                return status;
        }

        if (readId) {
            int status = 0;
            readPriv = __glXGetDrawable(glxc, readId, client, &status);
            if (readPriv is null)
                return status;
        }
    }

    if (prevglxc) {
        /* Flush the previous context if needed. */
        Bool need_flush = !prevglxc.isDirect;
static if (GLX_CONTEXT_RELEASE_BEHAVIOR_ARB) {
        if (prevglxc.releaseBehavior == GLX_CONTEXT_RELEASE_BEHAVIOR_NONE_ARB)
            need_flush = GL_FALSE;
}
        if (need_flush) {
            if (!__glXForceCurrent(cl, tag, cast(int*) &error))
                return error;
            glFlush();
        }

        /* Make the previous context not current. */
        if (!(*prevglxc.loseCurrent) (prevglxc))
            return __glXError(GLXBadContext);

        lastGLContext = null;
        if (!prevglxc.isDirect) {
            prevglxc.drawPriv = null;
            prevglxc.readPriv = null;
        }
    }

    if (glxc && !glxc.isDirect) {
        glxc.drawPriv = drawPriv;
        glxc.readPriv = readPriv;

        /* make the context current */
        lastGLContext = glxc;
        if (!(*glxc.makeCurrent) (glxc)) {
            lastGLContext = null;
            glxc.drawPriv = null;
            glxc.readPriv = null;
            return __glXError(GLXBadContext);
        }
    }

    glxServer.setContextTagPrivate(client, newContextTag, glxc);
    if (glxc)
        glxc.currentClient = client;

    if (prevglxc) {
        prevglxc.currentClient = null;
        if (!prevglxc.idExists) {
            FreeResourceByType(prevglxc.id, __glXContextRes, FALSE);
        }
    }

    return Success;
}

int __glXDisp_MakeCurrent(__GLXclientState* cl, GLbyte* pc)
{
    return BadImplementation;
}

int __glXDisp_MakeContextCurrent(__GLXclientState* cl, GLbyte* pc)
{
    return BadImplementation;
}

int __glXDisp_MakeCurrentReadSGI(__GLXclientState* cl, GLbyte* pc)
{
    return BadImplementation;
}

int __glXDisp_IsDirect(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXIsDirectReq* req = cast(xGLXIsDirectReq*) pc;
    __GLXcontext* glxc = void;
    int err = void;

    if (!validGlxContext(cl.client, req.context, DixReadAccess, &glxc, &err))
        return err;

    xGLXIsDirectReply reply = {
        isDirect: glxc.isDirect
    };

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int __glXDisp_QueryVersion(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXQueryVersionReq* req = cast(xGLXQueryVersionReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXQueryVersionReq);

    GLuint major = req.majorVersion;
    GLuint minor = req.minorVersion;
    // cast(void) major;
    // cast(void) minor;

    /*
     ** Server should take into consideration the version numbers sent by the
     ** client if it wants to work with older clients; however, in this
     ** implementation the server just returns its version number.
     */
    xGLXQueryVersionReply reply = {
        majorVersion: SERVER_GLX_MAJOR_VERSION,
        minorVersion: SERVER_GLX_MINOR_VERSION
    };

    if (client.swapped) {
        swapl(&reply.majorVersion);
        swapl(&reply.minorVersion);
    }

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

int __glXDisp_WaitGL(__GLXclientState* cl, GLbyte* pc)
{
    xGLXWaitGLReq* req = cast(xGLXWaitGLReq*) pc;
    GLXContextTag tag = void;
    __GLXcontext* glxc = null;
    int error = void;

    tag = req.contextTag;
    if (tag) {
        glxc = __glXLookupContextByTag(cl, tag);
        if (!glxc)
            return __glXError(GLXBadContextTag);

        if (!__glXForceCurrent(cl, req.contextTag, &error))
            return error;

        glFinish();
    }

    if (glxc && glxc.drawPriv && glxc.drawPriv.waitGL)
        assumeNoGC(glxc.drawPriv.waitGL) (glxc.drawPriv);

    return Success;
}

int __glXDisp_WaitX(__GLXclientState* cl, GLbyte* pc)
{
    xGLXWaitXReq* req = cast(xGLXWaitXReq*) pc;
    GLXContextTag tag = void;
    __GLXcontext* glxc = null;
    int error = void;

    tag = req.contextTag;
    if (tag) {
        glxc = __glXLookupContextByTag(cl, tag);
        if (!glxc)
            return __glXError(GLXBadContextTag);

        if (!__glXForceCurrent(cl, req.contextTag, &error))
            return error;
    }

    if (glxc && glxc.drawPriv && glxc.drawPriv.waitX)
        assumeNoGC(glxc.drawPriv.waitX) (glxc.drawPriv);

    return Success;
}

int __glXDisp_CopyContext(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCopyContextReq* req = cast(xGLXCopyContextReq*) pc;
    GLXContextID source = void;
    GLXContextID dest = void;
    GLXContextTag tag = void;
    c_ulong mask = void;
    __GLXcontext* src = void, dst = void;
    int error = void;

    source = req.source;
    dest = req.dest;
    tag = req.contextTag;
    mask = req.mask;
    if (!validGlxContext(cl.client, cast(uint)source, DixReadAccess, &src, &error))
        return error;
    if (!validGlxContext(cl.client, cast(uint)dest, DixWriteAccess, &dst, &error))
        return error;

    /*
     ** They must be in the same address space, and same screen.
     ** NOTE: no support for direct rendering contexts here.
     */
    if (src.isDirect || dst.isDirect || (src.pGlxScreen != dst.pGlxScreen)) {
        client.errorValue = cast(uint)cast(uint)source;
        return BadMatch;
    }

    /*
     ** The destination context must not be current for any client.
     */
    if (dst.currentClient) {
        client.errorValue = cast(uint)cast(uint)dest;
        return BadAccess;
    }

    if (tag) {
        __GLXcontext* tagcx = __glXLookupContextByTag(cl, tag);

        if (!tagcx) {
            return __glXError(GLXBadContextTag);
        }
        if (tagcx != src) {
            /*
             ** This would be caused by a faulty implementation of the client
             ** library.
             */
            return BadMatch;
        }
        /*
         ** In this case, glXCopyContext is in both GL and X streams, in terms
         ** of sequentiality.
         */
        if (__glXForceCurrent(cl, tag, &error)) {
            /*
             ** Do whatever is needed to make sure that all preceding requests
             ** in both streams are completed before the copy is executed.
             */
            glFinish();
        }
        else {
            return error;
        }
    }
    /*
     ** Issue copy.  The only reason for failure is a bad mask.
     */
    if (!(*dst.copy) (dst, src, mask)) {
        client.errorValue = cast(uint)cast(uint)mask;
        return BadValue;
    }
    return Success;
}

enum {
    GLX_VIS_CONFIG_UNPAIRED = 18,
    GLX_VIS_CONFIG_PAIRED = 22
}

enum {
    GLX_VIS_CONFIG_TOTAL = GLX_VIS_CONFIG_UNPAIRED + GLX_VIS_CONFIG_PAIRED
}

int __glXDisp_GetVisualConfigs(__GLXclientState* cl, GLbyte* pc)
{
    xGLXGetVisualConfigsReq* req = cast(xGLXGetVisualConfigsReq*) pc;
    ClientPtr client = cl.client;
    __GLXscreen* pGlxScreen = void;
    __GLXconfig* modes = void;
    int err = void;

    if (!validGlxScreen(cl.client, req.screen, &pGlxScreen, &err))
        return err;

    xGLXGetVisualConfigsReply reply = {
        numVisuals: pGlxScreen.numVisuals,
        numProps: GLX_VIS_CONFIG_TOTAL
    };

    if (client.swapped) {
        swapl(&reply.numVisuals);
        swapl(&reply.numProps);
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    for (int i = 0; i < pGlxScreen.numVisuals; i++) {
        modes = pGlxScreen.visuals[i];

        x_rpcbuf_write_CARD32(&rpcbuf, modes.visualID);
        x_rpcbuf_write_CARD32(&rpcbuf, glxConvertToXVisualType(modes.visualType));
        x_rpcbuf_write_CARD32(&rpcbuf, (modes.renderType & GLX_RGBA_BIT) ? GL_TRUE : GL_FALSE);

        x_rpcbuf_write_CARD32(&rpcbuf, modes.redBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.greenBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.blueBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.alphaBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.accumRedBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.accumGreenBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.accumBlueBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.accumAlphaBits);

        x_rpcbuf_write_CARD32(&rpcbuf, modes.doubleBufferMode);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.stereoMode);

        x_rpcbuf_write_CARD32(&rpcbuf, modes.rgbBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.depthBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.stencilBits);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.numAuxBuffers);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.level);

        /*
         ** Add token/value pairs for extensions.
         */
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_VISUAL_CAVEAT_EXT);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.visualRating);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_TRANSPARENT_TYPE);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.transparentPixel);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_TRANSPARENT_RED_VALUE);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.transparentRed);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_TRANSPARENT_GREEN_VALUE);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.transparentGreen);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_TRANSPARENT_BLUE_VALUE);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.transparentBlue);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_TRANSPARENT_ALPHA_VALUE);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.transparentAlpha);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_TRANSPARENT_INDEX_VALUE);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.transparentIndex);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_SAMPLES_SGIS);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.samples);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_SAMPLE_BUFFERS_SGIS);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.sampleBuffers);
        x_rpcbuf_write_CARD32(&rpcbuf, GLX_VISUAL_SELECT_GROUP_SGIX);
        x_rpcbuf_write_CARD32(&rpcbuf, modes.visualSelectGroup);
        /* Add attribute only if its value is not default. */
        if (modes.sRGBCapable != GL_FALSE) {
            x_rpcbuf_write_CARD32(&rpcbuf, GLX_FRAMEBUFFER_SRGB_CAPABLE_EXT);
            x_rpcbuf_write_CARD32(&rpcbuf, modes.sRGBCapable);
        } else {
            /* Pad with zeroes, so that attributes count is constant. */
            x_rpcbuf_reserve0(&rpcbuf, ((CARD32).sizeof * 2));
        }
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

enum __GLX_TOTAL_FBCONFIG_ATTRIBS = (44);
enum __GLX_FBCONFIG_ATTRIBS_LENGTH = (__GLX_TOTAL_FBCONFIG_ATTRIBS * 2);
/**
 * Send the set of GLXFBConfigs to the client.  There is not currently
 * and interface into the driver on the server-side to get GLXFBConfigs,
 * so we "invent" some based on the \c __GLXvisualConfig structures that
 * the driver does supply.
 *
 * The reply format for both \c glXGetFBConfigs and \c glXGetFBConfigsSGIX
 * is the same, so this routine pulls double duty.
 */

private int DoGetFBConfigs(__GLXclientState* cl, uint screen)
{
    ClientPtr client = cl.client;
    __GLXscreen* pGlxScreen = void;
    CARD32[__GLX_FBCONFIG_ATTRIBS_LENGTH] buf = void;
    int p = void, err = void;
    __GLXconfig* modes = void;

    if (!validGlxScreen(cl.client, screen, &pGlxScreen, &err))
        return err;

    x_rpcbuf_t rpcbuf;
        rpcbuf.swapped = client.swapped; 
        rpcbuf.err_clear = TRUE ;

    for (modes = pGlxScreen.fbconfigs; modes != null; modes = modes.next) {
        p = 0;

enum string WRITE_PAIR(string tag,string value) = `
    { buf[p++] = ` ~ tag ~ ` ; buf[p++] = ` ~ value ~ ` ; }`;

        mixin(WRITE_PAIR!(`GLX_VISUAL_ID`, `modes.visualID`));
        mixin(WRITE_PAIR!(`GLX_FBCONFIG_ID`, `modes.fbconfigID`));
        mixin(WRITE_PAIR!(`GLX_X_RENDERABLE`,
                   `(modes.drawableType & (GLX_WINDOW_BIT | GLX_PIXMAP_BIT)
                    ? GL_TRUE
                    : GL_FALSE)`));

        mixin(WRITE_PAIR!(`GLX_RGBA`,
                   `(modes.renderType & GLX_RGBA_BIT) ? GL_TRUE : GL_FALSE`));
        mixin(WRITE_PAIR!(`GLX_RENDER_TYPE`, `modes.renderType`));
        mixin(WRITE_PAIR!(`GLX_DOUBLEBUFFER`, `modes.doubleBufferMode`));
        mixin(WRITE_PAIR!(`GLX_STEREO`, `modes.stereoMode`));

        mixin(WRITE_PAIR!(`GLX_BUFFER_SIZE`, `modes.rgbBits`));
        mixin(WRITE_PAIR!(`GLX_LEVEL`, `modes.level`));
        mixin(WRITE_PAIR!(`GLX_AUX_BUFFERS`, `modes.numAuxBuffers`));
        mixin(WRITE_PAIR!(`GLX_RED_SIZE`, `modes.redBits`));
        mixin(WRITE_PAIR!(`GLX_GREEN_SIZE`, `modes.greenBits`));
        mixin(WRITE_PAIR!(`GLX_BLUE_SIZE`, `modes.blueBits`));
        mixin(WRITE_PAIR!(`GLX_ALPHA_SIZE`, `modes.alphaBits`));
        mixin(WRITE_PAIR!(`GLX_ACCUM_RED_SIZE`, `modes.accumRedBits`));
        mixin(WRITE_PAIR!(`GLX_ACCUM_GREEN_SIZE`, `modes.accumGreenBits`));
        mixin(WRITE_PAIR!(`GLX_ACCUM_BLUE_SIZE`, `modes.accumBlueBits`));
        mixin(WRITE_PAIR!(`GLX_ACCUM_ALPHA_SIZE`, `modes.accumAlphaBits`));
        mixin(WRITE_PAIR!(`GLX_DEPTH_SIZE`, `modes.depthBits`));
        mixin(WRITE_PAIR!(`GLX_STENCIL_SIZE`, `modes.stencilBits`));
        mixin(WRITE_PAIR!(`GLX_X_VISUAL_TYPE`, `modes.visualType`));
        mixin(WRITE_PAIR!(`GLX_CONFIG_CAVEAT`, `modes.visualRating`));
        mixin(WRITE_PAIR!(`GLX_TRANSPARENT_TYPE`, `modes.transparentPixel`));
        mixin(WRITE_PAIR!(`GLX_TRANSPARENT_RED_VALUE`, `modes.transparentRed`));
        mixin(WRITE_PAIR!(`GLX_TRANSPARENT_GREEN_VALUE`, `modes.transparentGreen`));
        mixin(WRITE_PAIR!(`GLX_TRANSPARENT_BLUE_VALUE`, `modes.transparentBlue`));
        mixin(WRITE_PAIR!(`GLX_TRANSPARENT_ALPHA_VALUE`, `modes.transparentAlpha`));
        mixin(WRITE_PAIR!(`GLX_TRANSPARENT_INDEX_VALUE`, `modes.transparentIndex`));
        mixin(WRITE_PAIR!(`GLX_SWAP_METHOD_OML`, `modes.swapMethod`));
        mixin(WRITE_PAIR!(`GLX_SAMPLES_SGIS`, `modes.samples`));
        mixin(WRITE_PAIR!(`GLX_SAMPLE_BUFFERS_SGIS`, `modes.sampleBuffers`));
        mixin(WRITE_PAIR!(`GLX_VISUAL_SELECT_GROUP_SGIX`, `modes.visualSelectGroup`));
        mixin(WRITE_PAIR!(`GLX_DRAWABLE_TYPE`, `modes.drawableType`));
        mixin(WRITE_PAIR!(`GLX_BIND_TO_TEXTURE_RGB_EXT`, `modes.bindToTextureRgb`));
        mixin(WRITE_PAIR!(`GLX_BIND_TO_TEXTURE_RGBA_EXT`, `modes.bindToTextureRgba`));
        mixin(WRITE_PAIR!(`GLX_BIND_TO_MIPMAP_TEXTURE_EXT`, `modes.bindToMipmapTexture`));
        mixin(WRITE_PAIR!(`GLX_BIND_TO_TEXTURE_TARGETS_EXT`,
                   `modes.bindToTextureTargets`));
	/* can't report honestly until mesa is fixed */
	mixin(WRITE_PAIR!(`GLX_Y_INVERTED_EXT`, `GLX_DONT_CARE`));
	if (modes.drawableType & GLX_PBUFFER_BIT) {
	    mixin(WRITE_PAIR!(`GLX_MAX_PBUFFER_WIDTH`, `modes.maxPbufferWidth`));
	    mixin(WRITE_PAIR!(`GLX_MAX_PBUFFER_HEIGHT`, `modes.maxPbufferHeight`));
	    mixin(WRITE_PAIR!(`GLX_MAX_PBUFFER_PIXELS`, `modes.maxPbufferPixels`));
	    mixin(WRITE_PAIR!(`GLX_OPTIMAL_PBUFFER_WIDTH_SGIX`,
		       `modes.optimalPbufferWidth`));
	    mixin(WRITE_PAIR!(`GLX_OPTIMAL_PBUFFER_HEIGHT_SGIX`,
		       `modes.optimalPbufferHeight`));
	}
        /* Add attribute only if its value is not default. */
        if (modes.sRGBCapable != GL_FALSE) {
            mixin(WRITE_PAIR!(`GLX_FRAMEBUFFER_SRGB_CAPABLE_EXT`, `modes.sRGBCapable`));
        }
        /* Pad the remaining place with zeroes, so that attributes count is constant. */
        while (p < __GLX_FBCONFIG_ATTRIBS_LENGTH) {
            mixin(WRITE_PAIR!(`0`, `0`));
        }
        assert(p == __GLX_FBCONFIG_ATTRIBS_LENGTH);

        x_rpcbuf_write_CARD32s(&rpcbuf, buf.ptr, __GLX_FBCONFIG_ATTRIBS_LENGTH);
    }

    xGLXGetFBConfigsReply reply;
        reply.numFBConfigs = pGlxScreen.numFBConfigs;
        reply.numAttribs = __GLX_TOTAL_FBCONFIG_ATTRIBS;

    mixin(X_REPLY_FIELD_CARD32!("numFBConfigs"));
    mixin(X_REPLY_FIELD_CARD32!("numAttribs"));

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int __glXDisp_GetFBConfigs(__GLXclientState* cl, GLbyte* pc)
{
    xGLXGetFBConfigsReq* req = cast(xGLXGetFBConfigsReq*) pc;

    return DoGetFBConfigs(cl, req.screen);
}

int __glXDisp_GetFBConfigsSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXGetFBConfigsSGIXReq* req = cast(xGLXGetFBConfigsSGIXReq*) pc;

    /* work around mesa bug, don't use REQUEST_SIZE_MATCH */
    mixin(REQUEST_AT_LEAST_SIZE!xGLXGetFBConfigsSGIXReq);
    return DoGetFBConfigs(cl, req.screen);
}

GLboolean __glXDrawableInit(__GLXdrawable* drawable, __GLXscreen* screen, DrawablePtr pDraw, int type, XID drawId, __GLXconfig* config)
{
    drawable.pDraw = pDraw;
    drawable.type = type;
    drawable.drawId = drawId;
    drawable.config = config;
    drawable.eventMask = 0;

    return GL_TRUE;
}

void __glXDrawableRelease(__GLXdrawable* drawable)
{
}

private int DoCreateGLXDrawable(ClientPtr client, __GLXscreen* pGlxScreen, __GLXconfig* config, DrawablePtr pDraw, XID drawableId, XID glxDrawableId, int type)
{
    __GLXdrawable* pGlxDraw = void;

    if (pGlxScreen.pScreen != pDraw.pScreen)
        return BadMatch;

    pGlxDraw = pGlxScreen.createDrawable(client, pGlxScreen, pDraw,
                                          drawableId, type,
                                          glxDrawableId, config);
    if (pGlxDraw is null)
        return BadAlloc;

    if (!AddResource(cast(uint)glxDrawableId, __glXDrawableRes, pGlxDraw))
        return BadAlloc;

    /*
     * Windows aren't refcounted, so track both the X and the GLX window
     * so we get called regardless of destruction order.
     */
    if (drawableId != glxDrawableId && type == GLX_DRAWABLE_WINDOW &&
        !AddResource(cast(uint)pDraw.id, __glXDrawableRes, pGlxDraw))
        return BadAlloc;

    return Success;
}

private int DoCreateGLXPixmap(ClientPtr client, __GLXscreen* pGlxScreen, __GLXconfig* config, XID drawableId, XID glxDrawableId)
{
    DrawablePtr pDraw = void;
    int err = void;

    err = dixLookupDrawable(&pDraw, drawableId, client, 0, DixAddAccess);
    if (err != Success) {
        client.errorValue = cast(uint)drawableId;
        return err;
    }
    if (pDraw.type != DRAWABLE_PIXMAP) {
        client.errorValue = cast(uint)drawableId;
        return BadPixmap;
    }

    err = DoCreateGLXDrawable(client, pGlxScreen, config, pDraw, drawableId,
                              glxDrawableId, GLX_DRAWABLE_PIXMAP);

    if (err == Success)
        (cast(PixmapPtr) pDraw).refcnt++;

    return err;
}

private void determineTextureTarget(ClientPtr client, XID glxDrawableID, CARD32* attribs, CARD32 numAttribs)
{
    GLenum target = 0;
    GLenum format = 0;
    int i = void, err = void;
    __GLXdrawable* pGlxDraw = void;

    if (!validGlxDrawable(client, glxDrawableID, GLX_DRAWABLE_PIXMAP,
                          DixWriteAccess, &pGlxDraw, &err))
        /* We just added it in CreatePixmap, so we should never get here. */
        return;

    for (i = 0; i < numAttribs; i++) {
        if (attribs[2 * i] == GLX_TEXTURE_TARGET_EXT) {
            switch (attribs[2 * i + 1]) {
            case GLX_TEXTURE_2D_EXT:
                target = GL_TEXTURE_2D;
                break;
            case GLX_TEXTURE_RECTANGLE_EXT:
                target = GL_TEXTURE_RECTANGLE_ARB;
                break;
            default: break;}
        }

        if (attribs[2 * i] == GLX_TEXTURE_FORMAT_EXT)
            format = cast(uint)attribs[2 * i + 1];
    }

    if (!target) {
        int w = pGlxDraw.pDraw.width, h = pGlxDraw.pDraw.height;

        if (h & (h - 1) || w & (w - 1))
            target = GL_TEXTURE_RECTANGLE_ARB;
        else
            target = GL_TEXTURE_2D;
    }

    pGlxDraw.target = target;
    pGlxDraw.format = format;
}

int __glXDisp_CreateGLXPixmap(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCreateGLXPixmapReq* req = cast(xGLXCreateGLXPixmapReq*) pc;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    if (!validGlxScreen(cl.client, req.screen, &pGlxScreen, &err))
        return err;
    if (!validGlxVisual(cl.client, pGlxScreen, req.visual, &config, &err))
        return err;

    return DoCreateGLXPixmap(cl.client, pGlxScreen, config,
                             req.pixmap, req.glxpixmap);
}

int __glXDisp_CreatePixmap(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreatePixmapReq* req = cast(xGLXCreatePixmapReq*) pc;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreatePixmapReq);
    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXCreatePixmapReq", "req.numAttribs << 3"));

    if (!validGlxScreen(cl.client, req.screen, &pGlxScreen, &err))
        return err;
    if (!validGlxFBConfig(cl.client, pGlxScreen, req.fbconfig, &config, &err))
        return err;

    err = DoCreateGLXPixmap(cl.client, pGlxScreen, config,
                            req.pixmap, req.glxpixmap);
    if (err != Success)
        return err;

    determineTextureTarget(cl.client, req.glxpixmap,
                           cast(CARD32*) (req + 1), req.numAttribs);

    return Success;
}

int __glXDisp_CreateGLXPixmapWithConfigSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreateGLXPixmapWithConfigSGIXReq* req = cast(xGLXCreateGLXPixmapWithConfigSGIXReq*) pc;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateGLXPixmapWithConfigSGIXReq);

    if (!validGlxScreen(cl.client, req.screen, &pGlxScreen, &err))
        return err;
    if (!validGlxFBConfig(cl.client, pGlxScreen, req.fbconfig, &config, &err))
        return err;

    return DoCreateGLXPixmap(cl.client, pGlxScreen,
                             config, req.pixmap, req.glxpixmap);
}

private int DoDestroyDrawable(__GLXclientState* cl, XID glxdrawable, int type)
{
    __GLXdrawable* pGlxDraw = void;
    int err = void;

    if (!validGlxDrawable(cl.client, glxdrawable, type,
                          DixDestroyAccess, &pGlxDraw, &err))
        return err;

    FreeResource(cast(uint)glxdrawable, FALSE);

    return Success;
}

int __glXDisp_DestroyGLXPixmap(__GLXclientState* cl, GLbyte* pc)
{
    xGLXDestroyGLXPixmapReq* req = cast(xGLXDestroyGLXPixmapReq*) pc;

    return DoDestroyDrawable(cl, req.glxpixmap, GLX_DRAWABLE_PIXMAP);
}

int __glXDisp_DestroyPixmap(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXDestroyPixmapReq* req = cast(xGLXDestroyPixmapReq*) pc;

    /* should be REQUEST_SIZE_MATCH, but mesa's glXDestroyPixmap used to set
     * length to 3 instead of 2 */
    mixin(REQUEST_AT_LEAST_SIZE!xGLXDestroyPixmapReq);

    return DoDestroyDrawable(cl, req.glxpixmap, GLX_DRAWABLE_PIXMAP);
}

private int DoCreatePbuffer(ClientPtr client, int screenNum, XID fbconfigId, int width, int height, XID glxDrawableId)
{
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    PixmapPtr pPixmap = void;
    int err = void;

    if (!validGlxScreen(client, screenNum, &pGlxScreen, &err))
        return err;
    if (!validGlxFBConfig(client, pGlxScreen, fbconfigId, &config, &err))
        return err;

    pPixmap = (*pGlxScreen.pScreen.CreatePixmap) (pGlxScreen.pScreen,
                                                    width, height,
                                                    config.rgbBits, 0);
    if (!pPixmap)
        return BadAlloc;

    err = XaceHookResourceAccess(client, glxDrawableId, X11_RESTYPE_PIXMAP,
                   pPixmap, X11_RESTYPE_NONE, null, DixCreateAccess);
    if (err != Success) {
        dixDestroyPixmap(pPixmap, 0);
        return err;
    }

    /* Assign the pixmap the same id as the pbuffer and add it as a
     * resource so it and the DRI2 drawable will be reclaimed when the
     * pbuffer is destroyed. */
    pPixmap.drawable.id = glxDrawableId;
    if (!AddResource(cast(uint)pPixmap.drawable.id, X11_RESTYPE_PIXMAP, pPixmap))
        return BadAlloc;

    return DoCreateGLXDrawable(client, pGlxScreen, config, &pPixmap.drawable,
                               glxDrawableId, glxDrawableId,
                               GLX_DRAWABLE_PBUFFER);
}

int __glXDisp_CreatePbuffer(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreatePbufferReq* req = cast(xGLXCreatePbufferReq*) pc;
    CARD32* attrs = void;
    int width = void, height = void, i = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreatePbufferReq);
    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXCreatePbufferReq", "req.numAttribs << 3"));

    attrs = cast(CARD32*) (req + 1);
    width = 0;
    height = 0;

    for (i = 0; i < req.numAttribs; i++) {
        switch (attrs[i * 2]) {
        case GLX_PBUFFER_WIDTH:
            width = cast(int)attrs[i * 2 + 1];
            break;
        case GLX_PBUFFER_HEIGHT:
            height = cast(int)attrs[i * 2 + 1];
            break;
        case GLX_LARGEST_PBUFFER:
            /* FIXME: huh... */
            break;
        default: break;}
    }

    return DoCreatePbuffer(cl.client, req.screen, req.fbconfig,
                           width, height, req.pbuffer);
}

int __glXDisp_CreateGLXPbufferSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreateGLXPbufferSGIXReq* req = cast(xGLXCreateGLXPbufferSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateGLXPbufferSGIXReq);

    /*
     * We should really handle attributes correctly, but this extension
     * is so rare I have difficulty caring.
     */
    return DoCreatePbuffer(cl.client, req.screen, req.fbconfig,
                           req.width, req.height, req.pbuffer);
}

int __glXDisp_DestroyPbuffer(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXDestroyPbufferReq* req = cast(xGLXDestroyPbufferReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXDestroyPbufferReq);

    return DoDestroyDrawable(cl, req.pbuffer, GLX_DRAWABLE_PBUFFER);
}

int __glXDisp_DestroyGLXPbufferSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXDestroyGLXPbufferSGIXReq* req = cast(xGLXDestroyGLXPbufferSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXDestroyGLXPbufferSGIXReq);

    return DoDestroyDrawable(cl, req.pbuffer, GLX_DRAWABLE_PBUFFER);
}

private int DoChangeDrawableAttributes(ClientPtr client, XID glxdrawable, int numAttribs, CARD32* attribs)
{
    __GLXdrawable* pGlxDraw = void;
    int i = void, err = void;

    if (!validGlxDrawable(client, glxdrawable, GLX_DRAWABLE_ANY,
                          DixSetAttrAccess, &pGlxDraw, &err))
        return err;

    for (i = 0; i < numAttribs; i++) {
        switch (attribs[i * 2]) {
        case GLX_EVENT_MASK:
            /* All we do is to record the event mask so we can send it
             * back when queried.  We never actually clobber the
             * pbuffers, so we never need to send out the event. */
            pGlxDraw.eventMask = attribs[i * 2 + 1];
            break;
        default: break;}
    }

    return Success;
}

int __glXDisp_ChangeDrawableAttributes(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXChangeDrawableAttributesReq* req = cast(xGLXChangeDrawableAttributesReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXChangeDrawableAttributesReq);
    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
version (none) {
    /* mesa sends an additional 8 bytes */
    mixin(REQUEST_FIXED_SIZE!("xGLXChangeDrawableAttributesReq", "req.numAttribs << 3"));
} else {
    if (((((xGLXChangeDrawableAttributesReq).sizeof +
          (req.numAttribs << 3))) >> 2) < client.req_len)
        return BadLength;
}

    return DoChangeDrawableAttributes(cl.client, req.drawable,
                                      req.numAttribs, cast(CARD32*) (req + 1));
}

int __glXDisp_ChangeDrawableAttributesSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXChangeDrawableAttributesSGIXReq* req = cast(xGLXChangeDrawableAttributesSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXChangeDrawableAttributesSGIXReq);
    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXChangeDrawableAttributesSGIXReq",
                       "req.numAttribs << 3"));

    return DoChangeDrawableAttributes(cl.client, req.drawable,
                                      req.numAttribs, cast(CARD32*) (req + 1));
}

int __glXDisp_CreateWindow(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCreateWindowReq* req = cast(xGLXCreateWindowReq*) pc;
    __GLXconfig* config = void;
    __GLXscreen* pGlxScreen = void;
    ClientPtr client = cl.client;
    DrawablePtr pDraw = void;
    int err = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateWindowReq);
    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXCreateWindowReq", "req.numAttribs << 3"));

    if (!validGlxScreen(client, req.screen, &pGlxScreen, &err))
        return err;
    if (!validGlxFBConfig(client, pGlxScreen, req.fbconfig, &config, &err))
        return err;

    err = dixLookupDrawable(&pDraw, req.window, client, 0, DixAddAccess);
    if (err != Success || pDraw.type != DRAWABLE_WINDOW) {
        client.errorValue = cast(uint)req.window;
        return BadWindow;
    }

    if (!validGlxFBConfigForWindow(client, config, pDraw, &err))
        return err;

    return DoCreateGLXDrawable(client, pGlxScreen, config,
                               pDraw, req.window,
                               req.glxwindow, GLX_DRAWABLE_WINDOW);
}

int __glXDisp_DestroyWindow(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXDestroyWindowReq* req = cast(xGLXDestroyWindowReq*) pc;

    /* mesa's glXDestroyWindow used to set length to 3 instead of 2 */
    mixin(REQUEST_AT_LEAST_SIZE!xGLXDestroyWindowReq);

    return DoDestroyDrawable(cl, req.glxwindow, GLX_DRAWABLE_WINDOW);
}

/*****************************************************************************/

/*
** NOTE: There is no portable implementation for swap buffers as of
** this time that is of value.  Consequently, this code must be
** implemented by somebody other than SGI.
*/
int __glXDisp_SwapBuffers(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXSwapBuffersReq* req = cast(xGLXSwapBuffersReq*) pc;
    GLXContextTag tag = void;
    XID drawId = void;
    __GLXcontext* glxc = null;
    __GLXdrawable* pGlxDraw = void;
    int error = void;

    tag = req.contextTag;
    drawId = req.drawable;
    if (tag) {
        glxc = __glXLookupContextByTag(cl, tag);
        if (!glxc) {
            return __glXError(GLXBadContextTag);
        }
        /*
         ** The calling thread is swapping its current drawable.  In this case,
         ** glxSwapBuffers is in both GL and X streams, in terms of
         ** sequentiality.
         */
        if (__glXForceCurrent(cl, tag, &error)) {
            /*
             ** Do whatever is needed to make sure that all preceding requests
             ** in both streams are completed before the swap is executed.
             */
            glFinish();
        }
        else {
            return error;
        }
    }

    pGlxDraw = __glXGetDrawable(glxc, drawId, client, &error);
    if (pGlxDraw is null)
        return error;

    if (pGlxDraw.type == DRAWABLE_WINDOW &&
        assumeNoGC(pGlxDraw.swapBuffers) (cl.client, pGlxDraw) == GL_FALSE)
        return __glXError(GLXBadDrawable);

    return Success;
}

private int DoQueryContext(__GLXclientState* cl, GLXContextID gcId)
{
    ClientPtr client = cl.client;
    __GLXcontext* ctx = void;
    int err = void;

    if (!validGlxContext(cl.client, cast(uint)gcId, DixReadAccess, &ctx, &err))
        return err;

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    x_rpcbuf_write_CARD32(&rpcbuf, GLX_SHARE_CONTEXT_EXT);
    x_rpcbuf_write_CARD32(&rpcbuf, cast(int) (ctx.share_id));
    x_rpcbuf_write_CARD32(&rpcbuf, GLX_VISUAL_ID_EXT);
    x_rpcbuf_write_CARD32(&rpcbuf, cast(int) (ctx.config ? ctx.config.visualID : 0));
    x_rpcbuf_write_CARD32(&rpcbuf, GLX_SCREEN_EXT);
    x_rpcbuf_write_CARD32(&rpcbuf, cast(int) (ctx.pGlxScreen.pScreen.myNum));
    x_rpcbuf_write_CARD32(&rpcbuf, GLX_FBCONFIG_ID);
    x_rpcbuf_write_CARD32(&rpcbuf, cast(int) (ctx.config ? ctx.config.fbconfigID : 0));
    x_rpcbuf_write_CARD32(&rpcbuf, GLX_RENDER_TYPE);
    x_rpcbuf_write_CARD32(&rpcbuf, cast(int) (ctx.renderType));

    xGLXQueryContextInfoEXTReply reply = {
        n: cast(uint)((rpcbuf.wpos / CARD32.sizeof) / 2),
    };

    if (client.swapped) {
        swapl(&reply.n);
    }

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int __glXDisp_QueryContextInfoEXT(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXQueryContextInfoEXTReq* req = cast(xGLXQueryContextInfoEXTReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXQueryContextInfoEXTReq);

    return DoQueryContext(cl, req.context);
}

int __glXDisp_QueryContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXQueryContextReq* req = cast(xGLXQueryContextReq*) pc;

    return DoQueryContext(cl, req.context);
}

int __glXDisp_BindTexImageEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    ClientPtr client = cl.client;
    __GLXcontext* context = void;
    __GLXdrawable* pGlxDraw = void;
    GLXDrawable drawId = void;
    int buffer = void;
    int error = void;
    CARD32 num_attribs = void;

    if ((((xGLXVendorPrivateReq).sizeof + 12)) >> 2 > client.req_len)
        return BadLength;

    pc += __GLX_VENDPRIV_HDR_SIZE;

    drawId = *(cast(CARD32*) (pc));
    buffer = cast(int)*(cast(INT32*) (pc + 4));
    num_attribs = *(cast(CARD32*) (pc + 8));
    if (num_attribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)num_attribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "12 + (num_attribs << 3)"));

    if (buffer != GLX_FRONT_LEFT_EXT)
        return __glXError(GLXBadPixmap);

    context = __glXForceCurrent(cl, req.contextTag, &error);
    if (!context)
        return error;

    if (!validGlxDrawable(client, cast(uint)drawId, GLX_DRAWABLE_PIXMAP,
                          DixReadAccess, &pGlxDraw, &error))
        return error;

    if (!context.bindTexImage)
        return __glXError(GLXUnsupportedPrivateRequest);

    return context.bindTexImage(context, buffer, pGlxDraw);
}

int __glXDisp_ReleaseTexImageEXT(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    ClientPtr client = cl.client;
    __GLXdrawable* pGlxDraw = void;
    __GLXcontext* context = void;
    GLXDrawable drawId = void;
    int buffer = void;
    int error = void;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "8"));

    pc += __GLX_VENDPRIV_HDR_SIZE;

    drawId = *(cast(CARD32*) (pc));
    buffer = cast(int)*(cast(INT32*) (pc + 4));

    context = __glXForceCurrent(cl, req.contextTag, &error);
    if (!context)
        return error;

    if (!validGlxDrawable(client, cast(uint)drawId, GLX_DRAWABLE_PIXMAP,
                          DixReadAccess, &pGlxDraw, &error))
        return error;

    if (!context.releaseTexImage)
        return __glXError(GLXUnsupportedPrivateRequest);

    return context.releaseTexImage(context, buffer, pGlxDraw);
}

int __glXDisp_CopySubBufferMESA(__GLXclientState* cl, GLbyte* pc)
{
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    GLXContextTag tag = req.contextTag;
    __GLXcontext* glxc = null;
    __GLXdrawable* pGlxDraw = void;
    ClientPtr client = cl.client;
    GLXDrawable drawId = void;
    int error = void;
    int x = void, y = void, width = void, height = void;

    cast(void) client;
    cast(void) req;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "20"));

    pc += __GLX_VENDPRIV_HDR_SIZE;

    drawId = *(cast(CARD32*) (pc));
    x = cast(int)*(cast(INT32*) (pc + 4));
    y = cast(int)*(cast(INT32*) (pc + 8));
    width = cast(int)*(cast(INT32*) (pc + 12));
    height = cast(int)*(cast(INT32*) (pc + 16));

    if (tag) {
        glxc = __glXLookupContextByTag(cl, tag);
        if (!glxc) {
            return __glXError(GLXBadContextTag);
        }
        /*
         ** The calling thread is swapping its current drawable.  In this case,
         ** glxSwapBuffers is in both GL and X streams, in terms of
         ** sequentiality.
         */
        if (__glXForceCurrent(cl, tag, &error)) {
            /*
             ** Do whatever is needed to make sure that all preceding requests
             ** in both streams are completed before the swap is executed.
             */
            glFinish();
        }
        else {
            return error;
        }
    }

    pGlxDraw = __glXGetDrawable(glxc, drawId, client, &error);
    if (!pGlxDraw)
        return error;

    if (pGlxDraw is null ||
        pGlxDraw.type != GLX_DRAWABLE_WINDOW ||
        pGlxDraw.copySubBuffer is null)
        return __glXError(GLXBadDrawable);

    assumeNoGC(pGlxDraw.copySubBuffer) (pGlxDraw, x, y, width, height);

    return Success;
}

/* hack for old glxext.h */
enum GLX_STEREO_TREE_EXT =                 0x20F5;


/*
** Get drawable attributes
*/
private int DoGetDrawableAttributes(__GLXclientState* cl, XID drawId)
{
    ClientPtr client = cl.client;
    __GLXdrawable* pGlxDraw = null;
    DrawablePtr pDraw = void;
    CARD32[20] attributes = void;
    int num = 0, error = void;

    if (!validGlxDrawable(client, drawId, GLX_DRAWABLE_ANY,
                          DixGetAttrAccess, &pGlxDraw, &error)) {
        /* hack for GLX 1.2 naked windows */
        int err = dixLookupWindow(cast(WindowPtr*)&pDraw, drawId, client,
                                  DixGetAttrAccess);
        if (err != Success)
            return __glXError(GLXBadDrawable);
    }
    if (pGlxDraw)
        pDraw = pGlxDraw.pDraw;

enum string ATTRIB(string a, string v) = `{ 
    attributes[2*num] = (` ~ a ~ `); 
    attributes[2*num+1] = cast(typeof(attributes[0]))(` ~ v ~ `); 
    num++; 
    }`;

    mixin(ATTRIB!(`GLX_Y_INVERTED_EXT`, `GL_FALSE`));
    mixin(ATTRIB!(`GLX_WIDTH`, `pDraw.width`));
    mixin(ATTRIB!(`GLX_HEIGHT`, `pDraw.height`));
    mixin(ATTRIB!(`GLX_SCREEN`, `pDraw.pScreen.myNum`));
    if (pGlxDraw) {
        mixin(ATTRIB!(`GLX_TEXTURE_TARGET_EXT`,
               `pGlxDraw.target == GL_TEXTURE_2D ?
                GLX_TEXTURE_2D_EXT : GLX_TEXTURE_RECTANGLE_EXT`));
        mixin(ATTRIB!(`GLX_EVENT_MASK`, `pGlxDraw.eventMask`));
        mixin(ATTRIB!(`GLX_FBCONFIG_ID`, `pGlxDraw.config.fbconfigID`));
        if (pGlxDraw.type == GLX_DRAWABLE_PBUFFER) {
            mixin(ATTRIB!(`GLX_PRESERVED_CONTENTS`, `GL_TRUE`));
        }
        if (pGlxDraw.type == GLX_DRAWABLE_WINDOW) {
            mixin(ATTRIB!(`GLX_STEREO_TREE_EXT`, `0`));
        }
    }

    /* GLX_EXT_get_drawable_type */
    if (!pGlxDraw || pGlxDraw.type == GLX_DRAWABLE_WINDOW)
        mixin(ATTRIB!(`GLX_DRAWABLE_TYPE`, `GLX_WINDOW_BIT`));
    else if (pGlxDraw.type == GLX_DRAWABLE_PIXMAP)
        mixin(ATTRIB!(`GLX_DRAWABLE_TYPE`, `GLX_PIXMAP_BIT`));
    else if (pGlxDraw.type == GLX_DRAWABLE_PBUFFER)
        mixin(ATTRIB!(`GLX_DRAWABLE_TYPE`, `GLX_PBUFFER_BIT`));
    xGLXGetDrawableAttributesReply reply = {
        numAttribs: num
    };

    if (client.swapped) {
        swapl(&reply.numAttribs);
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };
    x_rpcbuf_write_CARD32s(&rpcbuf, attributes.ptr, num << 1);

    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

int __glXDisp_GetDrawableAttributes(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXGetDrawableAttributesReq* req = cast(xGLXGetDrawableAttributesReq*) pc;

    /* this should be REQUEST_SIZE_MATCH, but mesa sends an additional 4 bytes */
    mixin(REQUEST_AT_LEAST_SIZE!xGLXGetDrawableAttributesReq);

    return DoGetDrawableAttributes(cl, req.drawable);
}

int __glXDisp_GetDrawableAttributesSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXGetDrawableAttributesSGIXReq* req = cast(xGLXGetDrawableAttributesSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXGetDrawableAttributesSGIXReq);

    return DoGetDrawableAttributes(cl, req.drawable);
}

/************************************************************************/

/*
** Render and Renderlarge are not in the GLX API.  They are used by the GLX
** client library to send batches of GL rendering commands.
*/

/*
** Reset state used to keep track of large (multi-request) commands.
*/
private void ResetLargeCommandStatus(__GLXcontext* cx)
{
    cx.largeCmdBytesSoFar = 0;
    cx.largeCmdBytesTotal = 0;
    cx.largeCmdRequestsSoFar = 0;
    cx.largeCmdRequestsTotal = 0;
}

/*
** Execute all the drawing commands in a request.
*/
int __glXDisp_Render(__GLXclientState* cl, GLbyte* pc)
{
    xGLXRenderReq* req = void;
    ClientPtr client = cl.client;
    int left = void, cmdlen = void, error = void;
    int commandsDone = void;
    CARD16 opcode = void;
    __GLXrenderHeader* hdr = void;
    __GLXcontext* glxc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXRenderReq);

    req = cast(xGLXRenderReq*) pc;
    if (client.swapped) {
        swaps(&req.length);
        swapl(&req.contextTag);
    }

    glxc = __glXForceCurrent(cl, req.contextTag, &error);
    if (!glxc) {
        return error;
    }

    commandsDone = 0;
    pc += xGLXRenderReq.sizeof;
    left = cast(int)((req.length << 2) - xGLXRenderReq.sizeof);
    while (left > 0) {
        __GLXrenderSizeData entry = void;
        int extra = 0;
        __GLXdispatchRenderProcPtr proc = void;
        int err = void;

        if (left < __GLXrenderHeader.sizeof)
            return BadLength;

        /*
         ** Verify that the header length and the overall length agree.
         ** Also, each command must be word aligned.
         */
        hdr = cast(__GLXrenderHeader*) pc;
        if (client.swapped) {
            swaps(&hdr.length);
            swaps(&hdr.opcode);
        }
        cmdlen = hdr.length;
        opcode = hdr.opcode;

        if (left < cmdlen)
            return BadLength;

        /*
         ** Check for core opcodes and grab entry data.
         */
        err = __glXGetProtocolSizeData(&Render_dispatch_info, opcode, &entry);
        proc = cast(__GLXdispatchRenderProcPtr)
            __glXGetProtocolDecodeFunction(&Render_dispatch_info,
                                           opcode, client.swapped);

        if ((err < 0) || (proc is null)) {
            client.errorValue = cast(uint)commandsDone;
            return __glXError(GLXBadRenderRequest);
        }

        if (cmdlen < entry.bytes) {
            return BadLength;
        }

        if (entry.varsize) {
            /* variable size command */
            extra = (*entry.varsize) (pc + __GLX_RENDER_HDR_SIZE,
                                      client.swapped,
                                      left - __GLX_RENDER_HDR_SIZE);
            if (extra < 0) {
                return BadLength;
            }
        }

        if (cmdlen != safe_pad(safe_add(entry.bytes, extra))) {
            return BadLength;
        }

        /*
         ** Skip over the header and execute the command.  We allow the
         ** caller to trash the command memory.  This is useful especially
         ** for things that require double alignment - they can just shift
         ** the data towards lower memory (trashing the header) by 4 bytes
         ** and achieve the required alignment.
         */
        (*proc) (pc + __GLX_RENDER_HDR_SIZE);
        pc += cmdlen;
        left -= cmdlen;
        commandsDone++;
    }
    return Success;
}

/*
** Execute a large rendering request (one that spans multiple X requests).
*/
int __glXDisp_RenderLarge(__GLXclientState* cl, GLbyte* pc)
{
    xGLXRenderLargeReq* req = void;
    ClientPtr client = cl.client;
    size_t dataBytes = void;
    __GLXrenderLargeHeader* hdr = void;
    __GLXcontext* glxc = void;
    int error = void;
    CARD16 opcode = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXRenderLargeReq);

    req = cast(xGLXRenderLargeReq*) pc;
    if (client.swapped) {
        swaps(&req.length);
        swapl(&req.contextTag);
        swapl(&req.dataBytes);
        swaps(&req.requestNumber);
        swaps(&req.requestTotal);
    }

    glxc = __glXForceCurrent(cl, req.contextTag, &error);
    if (!glxc) {
        return error;
    }
    if (safe_pad(req.dataBytes) < 0)
        return BadLength;
    dataBytes = req.dataBytes;

    /*
     ** Check the request length.
     */
    if ((req.length << 2) != safe_pad(cast(int)dataBytes) + xGLXRenderLargeReq.sizeof) {
        client.errorValue = cast(uint)req.length;
        /* Reset in case this isn't 1st request. */
        ResetLargeCommandStatus(glxc);
        return BadLength;
    }
    pc += xGLXRenderLargeReq.sizeof;

    if (glxc.largeCmdRequestsSoFar == 0) {
        __GLXrenderSizeData entry = void;
        int extra = 0;
        int left = cast(int)((req.length << 2) - xGLXRenderLargeReq.sizeof);
        int cmdlen = void;
        int err = void;

        /*
         ** This is the first request of a multi request command.
         ** Make enough space in the buffer, then copy the entire request.
         */
        if (req.requestNumber != 1) {
            client.errorValue = cast(uint)req.requestNumber;
            return __glXError(GLXBadLargeRequest);
        }

        if (dataBytes < __GLX_RENDER_LARGE_HDR_SIZE)
            return BadLength;

        hdr = cast(__GLXrenderLargeHeader*) pc;
        if (client.swapped) {
            swapl(&hdr.length);
            swapl(&hdr.opcode);
        }
        opcode = cast(ushort)hdr.opcode;
        if ((cmdlen = safe_pad(hdr.length)) < 0)
            return BadLength;

        /*
         ** Check for core opcodes and grab entry data.
         */
        err = __glXGetProtocolSizeData(&Render_dispatch_info, opcode, &entry);
        if (err < 0) {
            client.errorValue = cast(uint)opcode;
            return __glXError(GLXBadLargeRequest);
        }

        if (entry.varsize) {
            /*
             ** If it's a variable-size command (a command whose length must
             ** be computed from its parameters), all the parameters needed
             ** will be in the 1st request, so it's okay to do this.
             */
            extra = (*entry.varsize) (pc + __GLX_RENDER_LARGE_HDR_SIZE,
                                      client.swapped,
                                      left - __GLX_RENDER_LARGE_HDR_SIZE);
            if (extra < 0) {
                return BadLength;
            }
        }

        /* the +4 is safe because we know entry.bytes is small */
        if (cmdlen != safe_pad(safe_add(entry.bytes + 4, extra))) {
            return BadLength;
        }

        /*
         ** Make enough space in the buffer, then copy the entire request.
         */
        if (glxc.largeCmdBufSize < cmdlen) {
	    GLbyte* newbuf = glxc.largeCmdBuf;

	    if (((newbuf = cast(GLbyte*) realloc(newbuf, cmdlen)) is null))
		return BadAlloc;

	    glxc.largeCmdBuf = newbuf;
            glxc.largeCmdBufSize = cmdlen;
        }
        memcpy(glxc.largeCmdBuf, pc, dataBytes);

        glxc.largeCmdBytesSoFar = cast(int)dataBytes;
        glxc.largeCmdBytesTotal = cmdlen;
        glxc.largeCmdRequestsSoFar = 1;
        glxc.largeCmdRequestsTotal = req.requestTotal;
        return Success;

    }
    else {
        /*
         ** We are receiving subsequent (i.e. not the first) requests of a
         ** multi request command.
         */
        int bytesSoFar = void; /* including this packet */

        /*
         ** Check the request number and the total request count.
         */
        if (req.requestNumber != glxc.largeCmdRequestsSoFar + 1) {
            client.errorValue = cast(uint)req.requestNumber;
            ResetLargeCommandStatus(glxc);
            return __glXError(GLXBadLargeRequest);
        }
        if (req.requestTotal != glxc.largeCmdRequestsTotal) {
            client.errorValue = cast(uint)req.requestTotal;
            ResetLargeCommandStatus(glxc);
            return __glXError(GLXBadLargeRequest);
        }

        /*
         ** Check that we didn't get too much data.
         */
        if ((bytesSoFar = safe_add(cast(int)glxc.largeCmdBytesSoFar, cast(int)dataBytes)) < 0) {
            client.errorValue = cast(uint)cast(uint)dataBytes;
            ResetLargeCommandStatus(glxc);
            return __glXError(GLXBadLargeRequest);
        }

        if (bytesSoFar > glxc.largeCmdBytesTotal) {
            client.errorValue = cast(uint)cast(uint)dataBytes;
            ResetLargeCommandStatus(glxc);
            return __glXError(GLXBadLargeRequest);
        }

        memcpy(glxc.largeCmdBuf + glxc.largeCmdBytesSoFar, pc, dataBytes);
        glxc.largeCmdBytesSoFar += dataBytes;
        glxc.largeCmdRequestsSoFar++;

        if (req.requestNumber == glxc.largeCmdRequestsTotal) {
            __GLXdispatchRenderProcPtr proc = void;

            /*
             ** This is the last request; it must have enough bytes to complete
             ** the command.
             */
            /* NOTE: the pad macro below is needed because the client library
             ** pads the total byte count, but not the per-request byte counts.
             ** The Protocol Encoding says the total byte count should not be
             ** padded, so a proposal will be made to the ARB to relax the
             ** padding constraint on the total byte count, thus preserving
             ** backward compatibility.  Meanwhile, the padding done below
             ** fixes a bug that did not allow large commands of odd sizes to
             ** be accepted by the server.
             */
            if (safe_pad(glxc.largeCmdBytesSoFar) != glxc.largeCmdBytesTotal) {
                client.errorValue = cast(uint)cast(uint)dataBytes;
                ResetLargeCommandStatus(glxc);
                return __glXError(GLXBadLargeRequest);
            }
            hdr = cast(__GLXrenderLargeHeader*) glxc.largeCmdBuf;
            /*
             ** The opcode and length field in the header had already been
             ** swapped when the first request was received.
             **
             ** Use the opcode to index into the procedure table.
             */
            opcode = cast(ushort)hdr.opcode;

            proc = cast(__GLXdispatchRenderProcPtr)
                __glXGetProtocolDecodeFunction(&Render_dispatch_info, opcode,
                                               client.swapped);
            if (proc is null) {
                client.errorValue = cast(uint)opcode;
                return __glXError(GLXBadLargeRequest);
            }

            /*
             ** Skip over the header and execute the command.
             */
            (*proc) (glxc.largeCmdBuf + __GLX_RENDER_LARGE_HDR_SIZE);

            /*
             ** Reset for the next RenderLarge series.
             */
            ResetLargeCommandStatus(glxc);
        }
        else {
            /*
             ** This is neither the first nor the last request.
             */
        }
        return Success;
    }
}

/************************************************************************/

/*
** No support is provided for the vendor-private requests other than
** allocating the entry points in the dispatch table.
*/

int __glXDisp_VendorPrivate(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    GLint vendorcode = req.vendorCode;
    __GLXdispatchVendorPrivProcPtr proc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXVendorPrivateReq);

    proc = cast(__GLXdispatchVendorPrivProcPtr)
        __glXGetProtocolDecodeFunction(&VendorPriv_dispatch_info,
                                       vendorcode, 0);
    if (proc !is null) {
        return (*proc) (cl, cast(GLbyte*) req);
    }

    cl.client.errorValue = cast(uint)req.vendorCode;
    return __glXError(GLXUnsupportedPrivateRequest);
}

int __glXDisp_VendorPrivateWithReply(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    GLint vendorcode = req.vendorCode;
    __GLXdispatchVendorPrivProcPtr proc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXVendorPrivateReq);

    proc = cast(__GLXdispatchVendorPrivProcPtr)
        __glXGetProtocolDecodeFunction(&VendorPriv_dispatch_info,
                                       vendorcode, 0);
    if (proc !is null) {
        return (*proc) (cl, cast(GLbyte*) req);
    }

    cl.client.errorValue = cast(uint)vendorcode;
    return __glXError(GLXUnsupportedPrivateRequest);
}

int __glXDisp_QueryExtensionsString(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXQueryExtensionsStringReq* req = cast(xGLXQueryExtensionsStringReq*) pc;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    if (!validGlxScreen(client, req.screen, &pGlxScreen, &err))
        return err;

    /* client expects payload to contain a null terminated string
     * and uses this header to determine how many bytes to process */
    size_t n = strlen(pGlxScreen.GLXextensions) + 1;
    xGLXQueryExtensionsStringReply reply = {
        n: cast(uint)n
    };

    if (client.swapped) {
        swapl(&reply.n);
    }

    x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

    x_rpcbuf_write_string_0t_pad(&rpcbuf, pGlxScreen.GLXextensions);
    return mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));
}

enum GLX_VENDOR_NAMES_EXT = 0x20F6;


int __glXDisp_QueryServerString(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXQueryServerStringReq* req = cast(xGLXQueryServerStringReq*) pc;
    size_t n = void, length = void;
    const(char)* ptr = void;
    char* buf = void;
    __GLXscreen* pGlxScreen = void;
    int err = void;

    if (!validGlxScreen(client, req.screen, &pGlxScreen, &err))
        return err;

    switch (req.name) {
    case GLX_VENDOR:
        ptr = GLXServerVendorName.ptr;
        break;
    case GLX_VERSION:
        ptr = "1.4";
        break;
    case GLX_EXTENSIONS:
        ptr = pGlxScreen.GLXextensions;
        break;
    case GLX_VENDOR_NAMES_EXT:
        if (pGlxScreen.glvnd) {
            ptr = pGlxScreen.glvnd;
            break;
        }
        /* else fall through */
        goto default;
    default:
        return BadValue;
    }

    n = strlen(ptr) + 1;
    length = mixin(__GLX_PAD!("n")) >> 2;

    xGLXQueryServerStringReply reply = {
        type: X_Reply,
        sequenceNumber: cast(ushort)client.sequence,
        length: cast(uint)length,
        n: cast(uint)n
    };

    buf = cast(char*) calloc(length, 4);
    if (buf is null) {
        return BadAlloc;
    }
    memcpy(buf, ptr, n);

    if (client.swapped) {
        swaps(&reply.sequenceNumber);
        swapl(&reply.length);
        swapl(&reply.n);
        WriteToClient(client, xGLXQueryServerStringReply.sizeof, &reply);
        /** no swap is needed for an array of chars **/
        WriteToClient(client, cast(uint)(length << 2), buf);
    }
    else {
        WriteToClient(client, xGLXQueryServerStringReply.sizeof, &reply);
        WriteToClient(client, cast(int) (length << 2), buf);
    }

    free(buf);
    return Success;
}

int __glXDisp_ClientInfo(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXClientInfoReq* req = cast(xGLXClientInfoReq*) pc;
    const(char)* buf = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXClientInfoReq);

    buf = cast(const(char)*) (req + 1);
    if (!memchr(buf, 0, (client.req_len << 2) - xGLXClientInfoReq.sizeof))
        return BadLength;

    free(cl.GLClientextensions);
    cl.GLClientextensions = strdup(buf);
    if (!cl.GLClientextensions)
        return BadAlloc;

    return Success;
}

import externs.glxtokens;

void __glXsendSwapEvent(__GLXdrawable* drawable, int type, CARD64 ust, CARD64 msc, CARD32 sbc)
{
    ClientPtr client = dixClientForXID(drawable.drawId);
    if (!client)
        return;

    xGLXBufferSwapComplete2 wire = {
        type: cast(ubyte)(__glXEventBase + GLX_BufferSwapComplete)
    };

    if (!client)
        return;

    if (!(drawable.eventMask & GLX_BUFFER_SWAP_COMPLETE_INTEL_MASK))
        return;

    wire.event_type = cast(ushort)type;
    wire.drawable = cast(uint)drawable.drawId;
    wire.ust_hi = ust >> 32;
    wire.ust_lo = ust & 0xffffffff;
    wire.msc_hi = msc >> 32;
    wire.msc_lo = msc & 0xffffffff;
    wire.sbc = cast(uint)sbc;

    WriteEventsToClient(client, 1, cast(xEvent*) &wire);
}

static if (PRESENT) {
private void __glXpresentCompleteNotify(WindowPtr window, CARD8 present_kind, CARD8 present_mode, CARD32 serial, ulong ust, ulong msc)
{
    __GLXdrawable* drawable = void;
    int glx_type = void;
    int rc = void;

    if (present_kind != PresentCompleteKindPixmap)
        return;

    rc = dixLookupResourceByType(cast(void**) &drawable, window.drawable.id,
                                 __glXDrawableRes, serverClient, DixGetAttrAccess);

    if (rc != Success)
        return;

    if (present_mode == PresentCompleteModeFlip)
        glx_type = GLX_FLIP_COMPLETE_INTEL;
    else
        glx_type = GLX_BLIT_COMPLETE_INTEL;

    __glXsendSwapEvent(drawable, glx_type, ust, msc, serial);
}

void __glXregisterPresentCompleteNotify()
{
    present_register_complete_notify(&__glXpresentCompleteNotify);
}
}
