module glx.vndservermapping;
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

import glx.vndserver_priv;

import include.pixmapstr;

import glx.vndservervendor;
import dix.dixutils;
import dix.resource;


private ClientPtr requestClient = null;

void GlxSetRequestClient(ClientPtr client)
{
    requestClient = client;
}

private GlxServerVendor* LookupXIDMapResource(XID id)
{
    void* ptr = null;
    int rv = void;

    rv = dixLookupResourceByType(&ptr, id, idResource, null, DixReadAccess);
    if (rv == Success) {
        return cast(GlxServerVendor*) ptr;
    } else {
        return null;
    }
}

GlxServerVendor* GlxGetXIDMap(XID id)
{
    GlxServerVendor* vendor = LookupXIDMapResource(id);

    if (vendor is null) {
        // If we haven't seen this XID before, then it may be a drawable that
        // wasn't created through GLX, like a regular X window or pixmap. Try
        // to look up a matching drawable to find a screen number for it.
        void* ptr = null;
        int rv = dixLookupResourceByClass(&ptr, id, RC_DRAWABLE, null,
                                         DixGetAttrAccess);
        if (rv == Success && ptr !is null) {
            DrawablePtr draw = cast(DrawablePtr) ptr;
            vendor = GlxGetVendorForScreen(requestClient, draw.pScreen);
        }
    }
    return vendor;
}

Bool GlxAddXIDMap(XID id, GlxServerVendor* vendor)
{
    if (id == 0 || vendor is null) {
        return FALSE;
    }
    if (LookupXIDMapResource(id) !is null) {
        return FALSE;
    }
    return AddResource(cast(uint)id, idResource, vendor);
}

void GlxRemoveXIDMap(XID id)
{
    FreeResourceByType(id, idResource, FALSE);
}

GlxContextTagInfo* GlxAllocContextTag(ClientPtr client, GlxServerVendor* vendor)
{
    GlxClientPriv* cl = void;
    uint index = void;

    if (vendor is null) {
        return null;
    }

    cl = GlxGetClientData(client);
    if (cl is null) {
        return null;
    }

    // Look for a free tag index.
    for (index=0; index<cl.contextTagCount; index++) {
        if (cl.contextTags[index].vendor is null) {
            break;
        }
    }
    if (index >= cl.contextTagCount) {
        // We didn't find a free entry, so grow the array.
        GlxContextTagInfo* newTags = void;
        uint newSize = cl.contextTagCount * 2;
        if (newSize == 0) {
            // TODO: What's a good starting size for this?
            newSize = 16;
        }

        newTags = cast(GlxContextTagInfo*)
            realloc(cl.contextTags, newSize * GlxContextTagInfo.sizeof);
        if (newTags is null) {
            return null;
        }

        memset(&newTags[cl.contextTagCount], 0,
                (newSize - cl.contextTagCount) * GlxContextTagInfo.sizeof);

        index = cl.contextTagCount;
        cl.contextTags = newTags;
        cl.contextTagCount = newSize;
    }

    assert(index < cl.contextTagCount);
    memset(&cl.contextTags[index], 0, GlxContextTagInfo.sizeof);
    cl.contextTags[index].tag = cast(GLXContextTag) (index + 1);
    cl.contextTags[index].client = client;
    cl.contextTags[index].vendor = vendor;
    return &cl.contextTags[index];
}

GlxContextTagInfo* GlxLookupContextTag(ClientPtr client, GLXContextTag tag)
{
    GlxClientPriv* cl = GlxGetClientData(client);
    if (cl is null) {
        return null;
    }

    if (tag > 0 && (tag - 1) < cl.contextTagCount) {
        if (cl.contextTags[tag - 1].vendor !is null) {
            assert(cl.contextTags[tag - 1].client == client);
            return &cl.contextTags[tag - 1];
        }
    }
    return null;
}

void GlxFreeContextTag(GlxContextTagInfo* tagInfo)
{
    if (tagInfo !is null) {
        tagInfo.client = null;
        tagInfo.vendor = null;
        tagInfo.data = null;
        tagInfo.context = None;
        tagInfo.drawable = None;
        tagInfo.readdrawable = None;
    }
}

Bool GlxSetScreenVendor(ScreenPtr screen, GlxServerVendor* vendor)
{
    GlxScreenPriv* priv = void;

    if (vendor is null) {
        return FALSE;
    }

    priv = GlxGetScreen(screen);
    if (priv is null) {
        return FALSE;
    }

    if (priv.vendor !is null) {
        return FALSE;
    }

    priv.vendor = vendor;
    return TRUE;
}

Bool GlxSetClientScreenVendor(ClientPtr client, ScreenPtr screen, GlxServerVendor* vendor)
{
    GlxClientPriv* cl = void;

    if (screen is null || screen.isGPU) {
        return FALSE;
    }

    cl = GlxGetClientData(client);
    if (cl is null) {
        return FALSE;
    }

    if (vendor !is null) {
        cl.vendors[screen.myNum] = vendor;
    } else {
        cl.vendors[screen.myNum] = GlxGetVendorForScreen(null, screen);
    }
    return TRUE;
}

GlxServerVendor* GlxGetVendorForScreen(ClientPtr client, ScreenPtr screen)
{
    // Note that the client won't be sending GPU screen numbers, so we don't
    // need per-client mappings for them.
    if (client !is null && !screen.isGPU) {
        GlxClientPriv* cl = GlxGetClientData(client);
        if (cl !is null) {
            return cl.vendors[screen.myNum];
        } else {
            return null;
        }
    } else {
        GlxScreenPriv* priv = GlxGetScreen(screen);
        if (priv !is null) {
            return priv.vendor;
        } else {
            return null;
        }
    }
}
