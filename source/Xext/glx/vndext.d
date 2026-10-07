module glx.vndext;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright (c) 2016, NVIDIA CORPORATION.
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and/or associated documentation files (the
 * "Materials"), to deal in the Materials without restriction, including
 * without limitation the rights to use, copy, modify, merge, publish,
 * distribute, sublicense, and/or sell copies of the Materials, and to
 * permit persons to whom the Materials are furnished to do so, subject to
 * the following conditions:
 *
 * The above copyright notice and this permission notice shall be included
 * unaltered in all copies or substantial portions of the Materials.
 * Any additions, deletions, or changes to the original source files
 * must be clearly indicated in accompanying documentation.
 *
 * If only executable code is distributed, then the accompanying
 * documentation must state that "this software is based in part on the
 * work of the Khronos Group."
 *
 * THE MATERIALS ARE PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
 * EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
 * MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
 * IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
 * CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
 * TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
 * MATERIALS OR THE USE OR OTHER DEALINGS IN THE MATERIALS.
 */
import build.dix_config;

import x11.X;
// import dix.callback
import include.privates;
import glx.vndserver_priv;

// // import core.stdc.string;
// import include.scrnintstr;
// // import include.windowstr;
// // import include.dixstruct;
import include.extnsionst;
import include.glx_extinit;

// // import externs.glxproto;
import glx.vndservervendor;
// import dix.resource;
import dix.callback;
import dix.dix_priv;
import dix.screenint_priv;
import miext.extinit_priv;
import dix.extension;
import glx.glxscreens;


Bool noGlxExtension = FALSE;

ExtensionEntry* GlxExtensionEntry;
int GlxErrorBase = 0;
CallbackListRec vndInitCallbackList;
CallbackListPtr vndInitCallbackListPtr = &vndInitCallbackList;

private DevPrivateKeyRec glvXGLVScreenPrivKey;
private DevPrivateKeyRec glvXGLVClientPrivKey;

// The resource type used to keep track of the vendor library for XID's.
// RESTYPE idResource;

private int idResourceDeleteCallback(void* value, XID id)
{
    return 0;
}

private GlxScreenPriv* xglvGetScreenPrivate(ScreenPtr pScreen)
{
    return cast(GlxScreenPriv*)dixLookupPrivate(&pScreen.devPrivates, &glvXGLVScreenPrivKey);
}

private void xglvSetScreenPrivate(ScreenPtr pScreen, void* priv)
{
    dixSetPrivate(&pScreen.devPrivates, &glvXGLVScreenPrivKey, priv);
}

GlxScreenPriv* GlxGetScreen(ScreenPtr pScreen)
{
    if (pScreen !is null) {
        GlxScreenPriv* priv = xglvGetScreenPrivate(pScreen);
        if (priv is null) {
            priv = cast(GlxScreenPriv*) cast(GlxScreenPriv*) calloc(1, GlxScreenPriv.sizeof);
            if (priv is null) {
                return null;
            }

            xglvSetScreenPrivate(pScreen, priv);
        }
        return priv;
    } else {
        return null;
    }
}

private void GlxMappingReset()
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        GlxScreenPriv* priv = xglvGetScreenPrivate(walkScreen);
        if (priv !is null) {
            xglvSetScreenPrivate(walkScreen, null);
            free(priv);
        }
    });
}

private Bool GlxMappingInit()
{
    mixin(DIX_FOR_EACH_SCREEN!q{
        if (GlxGetScreen(walkScreen) is null) {
            GlxMappingReset();
            return FALSE;
        }
    });

    idResource = CreateNewResourceType(&idResourceDeleteCallback,
                                       "GLXServerIDRes");
    if (idResource == X11_RESTYPE_NONE)
    {
        GlxMappingReset();
        return FALSE;
    }
    return TRUE;
}

private GlxClientPriv* xglvGetClientPrivate(ClientPtr pClient)
{
    return cast(GlxClientPriv*)dixLookupPrivate(&pClient.devPrivates, &glvXGLVClientPrivKey);
}

private void xglvSetClientPrivate(ClientPtr pClient, void* priv)
{
    dixSetPrivate(&pClient.devPrivates, &glvXGLVClientPrivKey, priv);
}

GlxClientPriv* GlxGetClientData(ClientPtr client)
{
    GlxClientPriv* cl = xglvGetClientPrivate(client);
    if (cl is null) {
        cl = cast(GlxClientPriv*) calloc(1, ((GlxClientPriv).sizeof
                + screenInfo.numScreens * (GlxServerVendor*).sizeof));
        if (cl !is null) {
            cl.vendors = cast(GlxServerVendor**) (cl + 1);
            mixin(DIX_FOR_EACH_SCREEN!q{
                cl.vendors[walkScreenIdx] = GlxGetVendorForScreen(null, walkScreen);
            });
            xglvSetClientPrivate(client, cl);
        }
    }
    return cl;
}

void GlxFreeClientData(ClientPtr client)
{
    GlxClientPriv* cl = xglvGetClientPrivate(client);
    if (cl !is null) {
        uint i = void;
        for (i = 0; i < cl.contextTagCount; i++) {
            GlxContextTagInfo* tag = &cl.contextTags[i];
            if (tag.vendor !is null) {
                tag.vendor.glxvc.makeCurrent(client, tag.tag,
                                               None, None, None, 0);
            }
        }
        xglvSetClientPrivate(client, null);
        free(cl.contextTags);
        free(cl);
    }
}

private void GLXClientCallback(CallbackListPtr* list, void* closure, void* data)
{
    NewClientInfoRec* clientinfo = cast(NewClientInfoRec*) data;
    ClientPtr client = clientinfo.client;

    switch (client.clientState)
    {
        case ClientStateRetained:
        case ClientStateGone:
            GlxFreeClientData(client);
            break;
    default: break;}
}

private void GLXReset(ExtensionEntry* extEntry)
{
    // LogMessageVerb(X_INFO, 1, "GLX: GLXReset\n");

    GlxVendorExtensionReset(extEntry);
    GlxDispatchReset();
    GlxMappingReset();

    if ((dispatchException & DE_TERMINATE) == DE_TERMINATE) {
        while (vndInitCallbackList.list !is null) {
            CallbackPtr next = vndInitCallbackList.list.next;
            free(vndInitCallbackList.list);
            vndInitCallbackList.list = next;
        }
    }
}

void GlxExtensionInit()
{
    ExtensionEntry* extEntry = void;
    GlxExtensionEntry = null;

    // Init private keys, per-screen data
    if (!dixRegisterPrivateKey(&glvXGLVScreenPrivKey, PRIVATE_SCREEN, 0))
        return;
    if (!dixRegisterPrivateKey(&glvXGLVClientPrivKey, PRIVATE_CLIENT, 0))
        return;

    if (!GlxMappingInit()) {
        return;
    }

    if (!GlxDispatchInit()) {
        return;
    }

    if (!AddCallback(&ClientStateCallback, &GLXClientCallback, null)) {
        return;
    }

    extEntry = AddExtension(GLX_EXTENSION_NAME, __GLX_NUMBER_EVENTS,
                            __GLX_NUMBER_ERRORS, &GlxDispatchRequest,
                            &GlxDispatchRequest, &GLXReset, &StandardMinorOpcode);
    if (!extEntry) {
        return;
    }

    GlxExtensionEntry = extEntry;
    GlxErrorBase = extEntry.errorBase;
    CallCallbacks(&vndInitCallbackListPtr, extEntry);

    /* We'd better have found at least one vendor */
    mixin(DIX_FOR_EACH_SCREEN!q{
        if (GlxGetVendorForScreen(serverClient, walkScreen))
            return;
    });

    extEntry.base = 0;
}


private int GlxForwardRequest(GlxServerVendor* vendor, ClientPtr client)
{
    return vendor.glxvc.handleRequest(client);
}

private GlxServerVendor* GlxGetContextTag(ClientPtr client, GLXContextTag tag)
{
    GlxContextTagInfo* tagInfo = GlxLookupContextTag(client, cast(uint)tag);

    if (tagInfo !is null) {
        return tagInfo.vendor;
    } else {
        return null;
    }
}

private Bool GlxSetContextTagPrivate(ClientPtr client, GLXContextTag tag, void* data)
{
    GlxContextTagInfo* tagInfo = GlxLookupContextTag(client, cast(uint)tag);
    if (tagInfo !is null) {
        tagInfo.data = data;
        return TRUE;
    } else {
        return FALSE;
    }
}

private void* GlxGetContextTagPrivate(ClientPtr client, GLXContextTag tag)
{
    GlxContextTagInfo* tagInfo = GlxLookupContextTag(client, cast(uint)tag);
    if (tagInfo !is null) {
        return tagInfo.data;
    } else {
        return null;
    }
}

private GlxServerImports* GlxAllocateServerImports()
{
    return cast(GlxServerImports*)cast(GlxServerImports*) calloc(1, GlxServerImports.sizeof);
}

private void GlxFreeServerImports(GlxServerImports* imports)
{
    free(imports);
}

__gshared GlxServerExports xeniaGlxServer = {
    majorVersion: GLXSERVER_VENDOR_ABI_MAJOR_VERSION,
    minorVersion: GLXSERVER_VENDOR_ABI_MINOR_VERSION,

    extensionInitCallback: &vndInitCallbackListPtr,

    allocateServerImports: &GlxAllocateServerImports,
    freeServerImports: &GlxFreeServerImports,

    createVendor: &GlxCreateVendor,
    destroyVendor: &GlxDestroyVendor,
    setScreenVendor: &GlxSetScreenVendor,

    addXIDMap: &GlxAddXIDMap,
    getXIDMap: &GlxGetXIDMap,
    removeXIDMap: &GlxRemoveXIDMap,
    getContextTag: &GlxGetContextTag,
    setContextTagPrivate: &GlxSetContextTagPrivate,
    getContextTagPrivate: &GlxGetContextTagPrivate,
    getVendorForScreen: &GlxGetVendorForScreen,
    forwardRequest: & GlxForwardRequest,
    setClientScreenVendor: &GlxSetClientScreenVendor,
};

const(GlxServerExports)* glvndGetExports()
{
    return &xeniaGlxServer;
}
