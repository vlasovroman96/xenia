module glx.vnd_dispatch_stubs;
@nogc nothrow:
extern(C): __gshared:

template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}

import build.dix_config;

import dix.dix_priv;
import dix.screenint_priv;

import include.dix;
import include.vndserver;
import glx.vndext;
import glx.vndserver_priv;;


// HACK: The opcode in old glxproto.h has a typo in it.
// static if (!HasVersion!"X_GLXCreateContextAttribsARB") {
// enum X_GLXCreateContextAttribsARB = X_GLXCreateContextAtrribsARB;
// }

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) GlxServerVendor* vendorForScreen(ClientPtr pClient, CARD32 screen)
{
    ScreenPtr pScreen = dixGetScreenPtr(cast(uint)cast(uint)screen);
    if (!pScreen)
        return null;

    return glxServer.getVendorForScreen(pClient, pScreen);
}

int dispatch_Render(ClientPtr client)
{
    mixin(REQUEST!xGLXRenderReq);
    CARD32 contextTag = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_AT_LEAST_SIZE!("glxServer"));
    contextTag = GlxCheckSwap(client, stuff.contextTag);
    vendor = glxServer.getContextTag(client, cast(uint)contextTag);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)contextTag;
        return GlxErrorBase + GLXBadContextTag;
    }
}
int dispatch_RenderLarge(ClientPtr client)
{
    mixin(REQUEST!xGLXRenderLargeReq);
    CARD32 contextTag = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    contextTag = GlxCheckSwap(client, stuff.contextTag);
    vendor = glxServer.getContextTag(client, cast(uint)contextTag);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)contextTag;
        return GlxErrorBase + GLXBadContextTag;
    }
}
int dispatch_CreateContext(ClientPtr client)
{
    mixin(REQUEST!xGLXCreateContextReq);
    CARD32 screen = void, context = void;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);
    context = GlxCheckSwap(client, stuff.context);
    mixin(LEGAL_NEW_RESOURCE!("context", "client"));

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        if (!glxServer.addXIDMap(context, vendor)) {
            return BadAlloc;
        }
        ret = glxServer.forwardRequest(vendor, client);
        if (ret != Success) {
            glxServer.removeXIDMap(context);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_DestroyContext(ClientPtr client)
{
    mixin(REQUEST!xGLXDestroyContextReq);
    CARD32 context = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    context = GlxCheckSwap(client, stuff.context);
    vendor = glxServer.getXIDMap(context);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        if (ret == Success) {
            glxServer.removeXIDMap(context);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)context;
        return GlxErrorBase + GLXBadContext;
    }
}
int dispatch_WaitGL(ClientPtr client)
{
    mixin(REQUEST!xGLXWaitGLReq);
    CARD32 contextTag = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    contextTag = GlxCheckSwap(client, stuff.contextTag);
    vendor = glxServer.getContextTag(client, cast(uint)contextTag);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)contextTag;
        return GlxErrorBase + GLXBadContextTag;
    }
}
int dispatch_WaitX(ClientPtr client)
{
    mixin(REQUEST!xGLXWaitXReq);
    CARD32 contextTag = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    contextTag = GlxCheckSwap(client, stuff.contextTag);
    vendor = glxServer.getContextTag(client, cast(uint)contextTag);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)contextTag;
        return GlxErrorBase + GLXBadContextTag;
    }
}
int dispatch_UseXFont(ClientPtr client)
{
    mixin(REQUEST!xGLXUseXFontReq);
    CARD32 contextTag = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    contextTag = GlxCheckSwap(client, stuff.contextTag);
    vendor = glxServer.getContextTag(client, cast(uint)contextTag);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)contextTag;
        return GlxErrorBase + GLXBadContextTag;
    }
}
int dispatch_CreateGLXPixmap(ClientPtr client)
{
    mixin(REQUEST!xGLXCreateGLXPixmapReq);
    CARD32 screen = void, glxpixmap = void;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);
    glxpixmap = GlxCheckSwap(client, stuff.glxpixmap);
    mixin(LEGAL_NEW_RESOURCE!("glxpixmap", "client"));

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        if (!glxServer.addXIDMap(glxpixmap, vendor)) {
            return BadAlloc;
        }
        ret = glxServer.forwardRequest(vendor, client);
        if (ret != Success) {
            glxServer.removeXIDMap(glxpixmap);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_GetVisualConfigs(ClientPtr client)
{
    mixin(REQUEST!xGLXGetVisualConfigsReq);
    CARD32 screen = void;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor != null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_DestroyGLXPixmap(ClientPtr client)
{
    mixin(REQUEST!xGLXDestroyGLXPixmapReq);
    CARD32 glxpixmap = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    glxpixmap = GlxCheckSwap(client, stuff.glxpixmap);
    vendor = glxServer.getXIDMap(glxpixmap);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)glxpixmap;
        return GlxErrorBase + GLXBadPixmap;
    }
}
int dispatch_QueryExtensionsString(ClientPtr client)
{
    mixin(REQUEST!xGLXQueryExtensionsStringReq);
    CARD32 screen = void;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_QueryServerString(ClientPtr client)
{
    mixin(REQUEST!xGLXQueryServerStringReq);
    CARD32 screen = void;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_ChangeDrawableAttributes(ClientPtr client)
{
    mixin(REQUEST!xGLXChangeDrawableAttributesReq);
    CARD32 drawable = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    drawable = GlxCheckSwap(client, stuff.drawable);
    vendor = glxServer.getXIDMap(drawable);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)drawable;
        return BadDrawable;
    }
}
int dispatch_CreateNewContext(ClientPtr client)
{
    mixin(REQUEST!xGLXCreateNewContextReq);
    CARD32 screen = void, context = void;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);
    context = GlxCheckSwap(client, stuff.context);
    mixin(LEGAL_NEW_RESOURCE!("context", "client"));

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        if (!glxServer.addXIDMap(context, vendor)) {
            return BadAlloc;
        }
        ret = glxServer.forwardRequest(vendor, client);
        if (ret != Success) {
            glxServer.removeXIDMap(context);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_CreatePbuffer(ClientPtr client)
{
    mixin(REQUEST!xGLXCreatePbufferReq);
    CARD32 screen = void, pbuffer = void;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);
    pbuffer = GlxCheckSwap(client, stuff.pbuffer);
    mixin(LEGAL_NEW_RESOURCE!("pbuffer", "client"));

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        if (!glxServer.addXIDMap(pbuffer, vendor)) {
            return BadAlloc;
        }
        ret = glxServer.forwardRequest(vendor, client);
        if (ret != Success) {
            glxServer.removeXIDMap(pbuffer);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_CreatePixmap(ClientPtr client)
{
    mixin(REQUEST!xGLXCreatePixmapReq);
    CARD32 screen = void, glxpixmap = void;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);
    glxpixmap = GlxCheckSwap(client, stuff.glxpixmap);
    mixin(LEGAL_NEW_RESOURCE!("glxpixmap", "client"));

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        if (!glxServer.addXIDMap(glxpixmap, vendor)) {
            return BadAlloc;
        }
        ret = glxServer.forwardRequest(vendor, client);
        if (ret != Success) {
            glxServer.removeXIDMap(glxpixmap);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_CreateWindow(ClientPtr client)
{
    mixin(REQUEST!xGLXCreateWindowReq);
    CARD32 screen = void, glxwindow = void;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);
    glxwindow = GlxCheckSwap(client, stuff.glxwindow);
    mixin(LEGAL_NEW_RESOURCE!("glxwindow", "client"));

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        if (!glxServer.addXIDMap(glxwindow, vendor)) {
            return BadAlloc;
        }
        ret = glxServer.forwardRequest(vendor, client);
        if (ret != Success) {
            glxServer.removeXIDMap(glxwindow);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_CreateContextAttribsARB(ClientPtr client)
{
    mixin(REQUEST!xGLXCreateContextAttribsARBReq);
    CARD32 screen = void, context = void;
    mixin(REQUEST_AT_LEAST_SIZE!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);
    context = GlxCheckSwap(client, stuff.context);
    mixin(LEGAL_NEW_RESOURCE!("context", "client"));

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        if (!glxServer.addXIDMap(context, vendor)) {
            return BadAlloc;
        }
        ret = glxServer.forwardRequest(vendor, client);
        if (ret != Success) {
            glxServer.removeXIDMap(context);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_DestroyPbuffer(ClientPtr client)
{
    mixin(REQUEST!xGLXDestroyPbufferReq);
    CARD32 pbuffer = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    pbuffer = GlxCheckSwap(client, stuff.pbuffer);
    vendor = glxServer.getXIDMap(pbuffer);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        if (ret == Success) {
            glxServer.removeXIDMap(pbuffer);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)pbuffer;
        return GlxErrorBase + GLXBadPbuffer;
    }
}
int dispatch_DestroyPixmap(ClientPtr client)
{
    mixin(REQUEST!xGLXDestroyPixmapReq);
    CARD32 glxpixmap = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    glxpixmap = GlxCheckSwap(client, stuff.glxpixmap);
    vendor = glxServer.getXIDMap(glxpixmap);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        if (ret == Success) {
            glxServer.removeXIDMap(glxpixmap);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)glxpixmap;
        return GlxErrorBase + GLXBadPixmap;
    }
}
int dispatch_DestroyWindow(ClientPtr client)
{
    mixin(REQUEST!xGLXDestroyWindowReq);
    CARD32 glxwindow = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    glxwindow = GlxCheckSwap(client, stuff.glxwindow);
    vendor = glxServer.getXIDMap(glxwindow);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        if (ret == Success) {
            glxServer.removeXIDMap(glxwindow);
        }
        return ret;
    } else {
        client.errorValue = cast(uint)glxwindow;
        return GlxErrorBase + GLXBadWindow;
    }
}
int dispatch_GetDrawableAttributes(ClientPtr client)
{
    mixin(REQUEST!xGLXGetDrawableAttributesReq);
    CARD32 drawable = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    drawable = GlxCheckSwap(client, stuff.drawable);
    vendor = glxServer.getXIDMap(drawable);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)drawable;
        return BadDrawable;
    }
}
int dispatch_GetFBConfigs(ClientPtr client)
{
    mixin(REQUEST!xGLXGetFBConfigsReq);
    CARD32 screen = void;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    screen = GlxCheckSwap(client, stuff.screen);

    //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
    GlxServerVendor* vendor = vendorForScreen(client, screen);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)screen;
        return BadMatch;
    }
}
int dispatch_QueryContext(ClientPtr client)
{
    mixin(REQUEST!xGLXQueryContextReq);
    CARD32 context = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    context = GlxCheckSwap(client, stuff.context);
    vendor = glxServer.getXIDMap(context);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)context;
        return GlxErrorBase + GLXBadContext;
    }
}
int dispatch_IsDirect(ClientPtr client)
{
    mixin(REQUEST!xGLXIsDirectReq);
    CARD32 context = void;
    GlxServerVendor* vendor = null;
    mixin(REQUEST_SIZE_MATCH!("*stuff"));
    context = GlxCheckSwap(client, stuff.context);
    vendor = glxServer.getXIDMap(context);
    if (vendor !is null) {
        int ret = void;
        ret = glxServer.forwardRequest(vendor, client);
        return ret;
    } else {
        client.errorValue = cast(uint)context;
        return GlxErrorBase + GLXBadContext;
    }
}
