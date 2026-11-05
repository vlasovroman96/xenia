module Xext.xacestr;
@nogc nothrow:
extern(C): __gshared:
/************************************************************

Author: Eamon Walsh <ewalsh@tycho.nsa.gov>

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
this permission notice appear in supporting documentation.  This permission
notice shall be included in all copies or substantial portions of the
Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
AUTHOR BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

********************************************************/

 
public import dix.selection_priv;

public import dix.resource;
public import dix.extension;
public import include.window;
public import dix.input;
public import Xext.xace;

/* XACE_RESOURCE_ACCESS */
struct XaceResourceAccessRec {
    ClientPtr client;
    XID id;
    RESTYPE rtype;
    void* res;
    RESTYPE ptype;
    void* parent;
    Mask access_mode;
    int status;
}

/* XACE_PROPERTY_ACCESS */
struct XacePropertyAccessRec {
    ClientPtr client;
    WindowPtr pWin;
    PropertyPtr* ppProp;
    Mask access_mode;
    int status;
}

/* XACE_SEND_ACCESS */
struct XaceSendAccessRec {
    ClientPtr client;
    DeviceIntPtr dev;
    WindowPtr pWin;
    xEventPtr events;
    int count;
    int status;
}

/* XACE_RECEIVE_ACCESS */
struct XaceReceiveAccessRec {
    ClientPtr client;
    WindowPtr pWin;
    xEventPtr events;
    int count;
    int status;
}

/* XACE_SELECTION_ACCESS */
struct XaceSelectionAccessRec {
    ClientPtr client;
    _Selection** ppSel;
    Mask access_mode;
    int status;
}

                          /* _XACESTR_H */
