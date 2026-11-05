module glx.glxcmdsswap;
@nogc nothrow:
extern(C): __gshared:
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

import dix.dix_priv;

import glx.glxserver;
import glx.glxutil;
import externs.glxtokens;
import glx.unpack;
import dix.pixmap;
import dix.window;
import glx.glxext;
import glx.indirect_dispatch;
import glx.indirect_table;
import glx.indirect_util;
 import Xext.glx.fix;
import glx.glxcmds;
import glx.xfont;
import glx.vndext;

alias UINT32_MAX = core.stdc.stdint.UINT32_MAX;
// alias UINT32_MAX = core.stdc.stdint.UINT32_MAX;
alias CARD32 = x11.Xmd.CARD32;
alias BadLength = x11.X.BadLength;
alias BadAlloc = x11.X.BadAlloc;
alias BadMatch = x11.X.BadMatch;
alias None = x11.X.None;
alias Success = x11.X.Success;
alias BadValue = x11.X.BadValue;
alias BadRequest = x11.X.BadRequest;
alias INT32 = x11.Xmd.INT32;
alias BadImplementation = x11.X.BadImplementation;
/************************************************************************/

/*
** Byteswapping versions of GLX commands.  In most cases they just swap
** the incoming arguments and then call the unswapped routine.  For commands
** that have replies, a separate swapping routine for the reply is provided;
** it is called at the end of the unswapped routine.
*/

int __glXDispSwap_CreateContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCreateContextReq* req = cast(xGLXCreateContextReq*) pc;

    swaps(&req.length);
    swapl(&req.context);
    swapl(&req.visual);
    swapl(&req.screen);
    swapl(&req.shareList);

    return __glXDisp_CreateContext(cl, pc);
}

int __glXDispSwap_CreateNewContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCreateNewContextReq* req = cast(xGLXCreateNewContextReq*) pc;

    swaps(&req.length);
    swapl(&req.context);
    swapl(&req.fbconfig);
    swapl(&req.screen);
    swapl(&req.renderType);
    swapl(&req.shareList);

    return __glXDisp_CreateNewContext(cl, pc);
}

int __glXDispSwap_CreateContextWithConfigSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreateContextWithConfigSGIXReq* req = cast(xGLXCreateContextWithConfigSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateContextWithConfigSGIXReq);

    swaps(&req.length);
    swapl(&req.context);
    swapl(&req.fbconfig);
    swapl(&req.screen);
    swapl(&req.renderType);
    swapl(&req.shareList);

    return __glXDisp_CreateContextWithConfigSGIX(cl, pc);
}

int __glXDispSwap_DestroyContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXDestroyContextReq* req = cast(xGLXDestroyContextReq*) pc;

    swaps(&req.length);
    swapl(&req.context);

    return __glXDisp_DestroyContext(cl, pc);
}

int __glXDispSwap_MakeCurrent(__GLXclientState* cl, GLbyte* pc)
{
    return BadImplementation;
}

int __glXDispSwap_MakeContextCurrent(__GLXclientState* cl, GLbyte* pc)
{
    return BadImplementation;
}

int __glXDispSwap_MakeCurrentReadSGI(__GLXclientState* cl, GLbyte* pc)
{
    return BadImplementation;
}

int __glXDispSwap_IsDirect(__GLXclientState* cl, GLbyte* pc)
{
    xGLXIsDirectReq* req = cast(xGLXIsDirectReq*) pc;

    swaps(&req.length);
    swapl(&req.context);

    return __glXDisp_IsDirect(cl, pc);
}

int __glXDispSwap_QueryVersion(__GLXclientState* cl, GLbyte* pc)
{
    xGLXQueryVersionReq* req = cast(xGLXQueryVersionReq*) pc;

    swaps(&req.length);
    swapl(&req.majorVersion);
    swapl(&req.minorVersion);

    return __glXDisp_QueryVersion(cl, pc);
}

int __glXDispSwap_WaitGL(__GLXclientState* cl, GLbyte* pc)
{
    xGLXWaitGLReq* req = cast(xGLXWaitGLReq*) pc;

    swaps(&req.length);
    swapl(&req.contextTag);

    return __glXDisp_WaitGL(cl, pc);
}

int __glXDispSwap_WaitX(__GLXclientState* cl, GLbyte* pc)
{
    xGLXWaitXReq* req = cast(xGLXWaitXReq*) pc;

    swaps(&req.length);
    swapl(&req.contextTag);

    return __glXDisp_WaitX(cl, pc);
}

int __glXDispSwap_CopyContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCopyContextReq* req = cast(xGLXCopyContextReq*) pc;

    swaps(&req.length);
    swapl(&req.source);
    swapl(&req.dest);
    swapl(&req.mask);
    swapl(&req.contextTag);

    return __glXDisp_CopyContext(cl, pc);
}

int __glXDispSwap_GetVisualConfigs(__GLXclientState* cl, GLbyte* pc)
{
    xGLXGetVisualConfigsReq* req = cast(xGLXGetVisualConfigsReq*) pc;

    swapl(&req.screen);
    return __glXDisp_GetVisualConfigs(cl, pc);
}

int __glXDispSwap_GetFBConfigs(__GLXclientState* cl, GLbyte* pc)
{
    xGLXGetFBConfigsReq* req = cast(xGLXGetFBConfigsReq*) pc;

    swapl(&req.screen);
    return __glXDisp_GetFBConfigs(cl, pc);
}

int __glXDispSwap_GetFBConfigsSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXGetFBConfigsSGIXReq* req = cast(xGLXGetFBConfigsSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXGetFBConfigsSGIXReq);

    swapl(&req.screen);
    return __glXDisp_GetFBConfigsSGIX(cl, pc);
}

int __glXDispSwap_CreateGLXPixmap(__GLXclientState* cl, GLbyte* pc)
{
    xGLXCreateGLXPixmapReq* req = cast(xGLXCreateGLXPixmapReq*) pc;

    swaps(&req.length);
    swapl(&req.screen);
    swapl(&req.visual);
    swapl(&req.pixmap);
    swapl(&req.glxpixmap);

    return __glXDisp_CreateGLXPixmap(cl, pc);
}

int __glXDispSwap_CreatePixmap(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreatePixmapReq* req = cast(xGLXCreatePixmapReq*) pc;
    CARD32* attribs = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreatePixmapReq);

    swaps(&req.length);
    swapl(&req.screen);
    swapl(&req.fbconfig);
    swapl(&req.pixmap);
    swapl(&req.glxpixmap);
    swapl(&req.numAttribs);

    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXCreatePixmapReq", "req.numAttribs << 3"));
    attribs = cast(CARD32*) (req + 1);
    SwapLongs(attribs, req.numAttribs << 1);

    return __glXDisp_CreatePixmap(cl, pc);
}

int __glXDispSwap_CreateGLXPixmapWithConfigSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreateGLXPixmapWithConfigSGIXReq* req = cast(xGLXCreateGLXPixmapWithConfigSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateGLXPixmapWithConfigSGIXReq);

    swaps(&req.length);
    swapl(&req.screen);
    swapl(&req.fbconfig);
    swapl(&req.pixmap);
    swapl(&req.glxpixmap);

    return __glXDisp_CreateGLXPixmapWithConfigSGIX(cl, pc);
}

int __glXDispSwap_DestroyGLXPixmap(__GLXclientState* cl, GLbyte* pc)
{
    xGLXDestroyGLXPixmapReq* req = cast(xGLXDestroyGLXPixmapReq*) pc;

    swaps(&req.length);
    swapl(&req.glxpixmap);

    return __glXDisp_DestroyGLXPixmap(cl, pc);
}

int __glXDispSwap_DestroyPixmap(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXDestroyGLXPixmapReq* req = cast(xGLXDestroyGLXPixmapReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXDestroyGLXPixmapReq);

    swaps(&req.length);
    swapl(&req.glxpixmap);

    return __glXDisp_DestroyGLXPixmap(cl, pc);
}

int __glXDispSwap_QueryContext(__GLXclientState* cl, GLbyte* pc)
{
    xGLXQueryContextReq* req = cast(xGLXQueryContextReq*) pc;

    swapl(&req.context);

    return __glXDisp_QueryContext(cl, pc);
}

int __glXDispSwap_CreatePbuffer(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreatePbufferReq* req = cast(xGLXCreatePbufferReq*) pc;

    CARD32* attribs = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreatePbufferReq);

    swapl(&req.screen);
    swapl(&req.fbconfig);
    swapl(&req.pbuffer);
    swapl(&req.numAttribs);

    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXCreatePbufferReq", "req.numAttribs << 3"));
    attribs = cast(CARD32*) (req + 1);
    SwapLongs(attribs, req.numAttribs << 1);

    return __glXDisp_CreatePbuffer(cl, pc);
}

int __glXDispSwap_CreateGLXPbufferSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreateGLXPbufferSGIXReq* req = cast(xGLXCreateGLXPbufferSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateGLXPbufferSGIXReq);

    swapl(&req.screen);
    swapl(&req.fbconfig);
    swapl(&req.pbuffer);
    swapl(&req.width);
    swapl(&req.height);

    return __glXDisp_CreateGLXPbufferSGIX(cl, pc);
}

int __glXDispSwap_DestroyPbuffer(__GLXclientState* cl, GLbyte* pc)
{
    xGLXDestroyPbufferReq* req = cast(xGLXDestroyPbufferReq*) pc;

    swapl(&req.pbuffer);

    return __glXDisp_DestroyPbuffer(cl, pc);
}

int __glXDispSwap_DestroyGLXPbufferSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXDestroyGLXPbufferSGIXReq* req = cast(xGLXDestroyGLXPbufferSGIXReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXDestroyGLXPbufferSGIXReq);

    swapl(&req.pbuffer);

    return __glXDisp_DestroyGLXPbufferSGIX(cl, pc);
}

int __glXDispSwap_ChangeDrawableAttributes(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXChangeDrawableAttributesReq* req = cast(xGLXChangeDrawableAttributesReq*) pc;
    CARD32* attribs = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXChangeDrawableAttributesReq);

    swapl(&req.drawable);
    swapl(&req.numAttribs);

    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    if (((((xGLXChangeDrawableAttributesReq).sizeof +
          (req.numAttribs << 3))) >> 2) < client.req_len)
        return BadLength;

    attribs = cast(CARD32*) (req + 1);
    SwapLongs(attribs, req.numAttribs << 1);

    return __glXDisp_ChangeDrawableAttributes(cl, pc);
}

int __glXDispSwap_ChangeDrawableAttributesSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXChangeDrawableAttributesSGIXReq* req = cast(xGLXChangeDrawableAttributesSGIXReq*) pc;
    CARD32* attribs = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXChangeDrawableAttributesSGIXReq);

    swapl(&req.drawable);
    swapl(&req.numAttribs);

    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXChangeDrawableAttributesSGIXReq",
                       "req.numAttribs << 3"));
    attribs = cast(CARD32*) (req + 1);
    SwapLongs(attribs, req.numAttribs << 1);

    return __glXDisp_ChangeDrawableAttributesSGIX(cl, pc);
}

int __glXDispSwap_CreateWindow(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXCreateWindowReq* req = cast(xGLXCreateWindowReq*) pc;

    CARD32* attribs = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXCreateWindowReq);

    swapl(&req.screen);
    swapl(&req.fbconfig);
    swapl(&req.window);
    swapl(&req.glxwindow);
    swapl(&req.numAttribs);

    if (req.numAttribs > (UINT32_MAX >> 3)) {
        client.errorValue = cast(uint)req.numAttribs;
        return BadValue;
    }
    mixin(REQUEST_FIXED_SIZE!("xGLXCreateWindowReq", "req.numAttribs << 3"));
    attribs = cast(CARD32*) (req + 1);
    SwapLongs(attribs, req.numAttribs << 1);

    return __glXDisp_CreateWindow(cl, pc);
}

int __glXDispSwap_DestroyWindow(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXDestroyWindowReq* req = cast(xGLXDestroyWindowReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXDestroyWindowReq);

    swapl(&req.glxwindow);

    return __glXDisp_DestroyWindow(cl, pc);
}

int __glXDispSwap_SwapBuffers(__GLXclientState* cl, GLbyte* pc)
{
    xGLXSwapBuffersReq* req = cast(xGLXSwapBuffersReq*) pc;

    swaps(&req.length);
    swapl(&req.contextTag);
    swapl(&req.drawable);

    return __glXDisp_SwapBuffers(cl, pc);
}

int __glXDispSwap_UseXFont(__GLXclientState* cl, GLbyte* pc)
{
    xGLXUseXFontReq* req = cast(xGLXUseXFontReq*) pc;

    swaps(&req.length);
    swapl(&req.contextTag);
    swapl(&req.font);
    swapl(&req.first);
    swapl(&req.count);
    swapl(&req.listBase);

    return __glXDisp_UseXFont(cl, pc);
}

int __glXDispSwap_QueryExtensionsString(__GLXclientState* cl, GLbyte* pc)
{
    xGLXQueryExtensionsStringReq* req = cast(xGLXQueryExtensionsStringReq*) pc;

    swaps(&req.length);
    swapl(&req.screen);

    return __glXDisp_QueryExtensionsString(cl, pc);
}

int __glXDispSwap_QueryServerString(__GLXclientState* cl, GLbyte* pc)
{
    xGLXQueryServerStringReq* req = cast(xGLXQueryServerStringReq*) pc;

    swaps(&req.length);
    swapl(&req.screen);
    swapl(&req.name);

    return __glXDisp_QueryServerString(cl, pc);
}

int __glXDispSwap_ClientInfo(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXClientInfoReq* req = cast(xGLXClientInfoReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXClientInfoReq);

    swaps(&req.length);
    swapl(&req.major);
    swapl(&req.minor);
    swapl(&req.numbytes);

    return __glXDisp_ClientInfo(cl, pc);
}

int __glXDispSwap_QueryContextInfoEXT(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXQueryContextInfoEXTReq* req = cast(xGLXQueryContextInfoEXTReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXQueryContextInfoEXTReq);

    swaps(&req.length);
    swapl(&req.context);

    return __glXDisp_QueryContextInfoEXT(cl, pc);
}

int __glXDispSwap_BindTexImageEXT(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    XeGLXDrawable* drawId = void;
    int* buffer = void;
    CARD32* num_attribs = void;

    if ((((xGLXVendorPrivateReq).sizeof + 12)) >> 2 > client.req_len)
        return BadLength;

    pc += __GLX_VENDPRIV_HDR_SIZE;

    drawId = (cast(XeGLXDrawable*) (pc));
    buffer = (cast(int*) (pc + 4));
    num_attribs = (cast(CARD32*) (pc + 8));

    swaps(&req.length);
    swapl(&req.contextTag);
    swapl(drawId);
    swapl(buffer);
    swapl(num_attribs);

    return __glXDisp_BindTexImageEXT(cl, cast(GLbyte*) req);
}

int __glXDispSwap_ReleaseTexImageEXT(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    XeGLXDrawable* drawId = void;
    int* buffer = void;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "8"));

    pc += __GLX_VENDPRIV_HDR_SIZE;

    drawId = (cast(XeGLXDrawable*) (pc));
    buffer = (cast(int*) (pc + 4));

    swaps(&req.length);
    swapl(&req.contextTag);
    swapl(drawId);
    swapl(buffer);

    return __glXDisp_ReleaseTexImageEXT(cl, cast(GLbyte*) req);
}

int __glXDispSwap_CopySubBufferMESA(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateReq* req = cast(xGLXVendorPrivateReq*) pc;
    XeGLXDrawable* drawId = void;
    int* buffer = void;

    mixin(REQUEST_FIXED_SIZE!("xGLXVendorPrivateReq", "20"));

    cast(void) drawId;
    cast(void) buffer;

    pc += __GLX_VENDPRIV_HDR_SIZE;

    swaps(&req.length);
    swapl(&req.contextTag);
    swapl(cast(CARD32*)(pc));
    swapl(cast(CARD32*)(pc + 4));
    swapl(cast(CARD32*)(pc + 8));
    swapl(cast(CARD32*)(pc + 12));
    swapl(cast(CARD32*)(pc + 16));

    return __glXDisp_CopySubBufferMESA(cl, cast(GLbyte*) req);

}

int __glXDispSwap_GetDrawableAttributesSGIX(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateWithReplyReq* req = cast(xGLXVendorPrivateWithReplyReq*) pc;
    CARD32* data = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXGetDrawableAttributesSGIXReq);

    data = cast(CARD32*) (req + 1);
    swaps(&req.length);
    swapl(&req.contextTag);
    swapl(data);

    return __glXDisp_GetDrawableAttributesSGIX(cl, pc);
}

int __glXDispSwap_GetDrawableAttributes(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXGetDrawableAttributesReq* req = cast(xGLXGetDrawableAttributesReq*) pc;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXGetDrawableAttributesReq);

    swaps(&req.length);
    swapl(&req.drawable);

    return __glXDisp_GetDrawableAttributes(cl, pc);
}

/************************************************************************/

/*
** Render and Renderlarge are not in the GLX API.  They are used by the GLX
** client library to send batches of GL rendering commands.
*/

int __glXDispSwap_Render(__GLXclientState* cl, GLbyte* pc)
{
    return __glXDisp_Render(cl, pc);
}

/*
** Execute a large rendering request (one that spans multiple X requests).
*/
int __glXDispSwap_RenderLarge(__GLXclientState* cl, GLbyte* pc)
{
    return __glXDisp_RenderLarge(cl, pc);
}

/************************************************************************/

/*
** No support is provided for the vendor-private requests other than
** allocating these entry points in the dispatch table.
*/

int __glXDispSwap_VendorPrivate(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateReq* req = void;
    GLint vendorcode = void;
    __GLXdispatchVendorPrivProcPtr proc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXVendorPrivateReq);

    req = cast(xGLXVendorPrivateReq*) pc;
    swaps(&req.length);
    swapl(&req.vendorCode);

    vendorcode = req.vendorCode;

    proc = cast(__GLXdispatchVendorPrivProcPtr)
        __glXGetProtocolDecodeFunction(&VendorPriv_dispatch_info,
                                       vendorcode, 1);
    if (proc !is null) {
        return (*proc) (cl, cast(GLbyte*) req);
    }

    cl.client.errorValue = cast(uint)req.vendorCode;
    return __glXError(GLXUnsupportedPrivateRequest);
}

int __glXDispSwap_VendorPrivateWithReply(__GLXclientState* cl, GLbyte* pc)
{
    ClientPtr client = cl.client;
    xGLXVendorPrivateWithReplyReq* req = void;
    GLint vendorcode = void;
    __GLXdispatchVendorPrivProcPtr proc = void;

    mixin(REQUEST_AT_LEAST_SIZE!xGLXVendorPrivateWithReplyReq);

    req = cast(xGLXVendorPrivateWithReplyReq*) pc;
    swaps(&req.length);
    swapl(&req.vendorCode);

    vendorcode = req.vendorCode;

    proc = cast(__GLXdispatchVendorPrivProcPtr)
        __glXGetProtocolDecodeFunction(&VendorPriv_dispatch_info,
                                       vendorcode, 1);
    if (proc !is null) {
        return (*proc) (cl, cast(GLbyte*) req);
    }

    cl.client.errorValue = cast(uint)req.vendorCode;
    return __glXError(GLXUnsupportedPrivateRequest);
}
