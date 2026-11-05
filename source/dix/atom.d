module dix.atom;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/***********************************************************

Copyright 1987, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall not be
used in advertising or otherwise to promote the sale, use or other dealings
in this Software without prior written authorization from The Open Group.

Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.

                        All Rights Reserved

Permission to use, copy, modify, and distribute this software and its
documentation for any purpose and without fee is hereby granted,
provided that the above copyright notice appear in all copies and that
both that copyright notice and this permission notice appear in
supporting documentation, and that the name of Digital not be
used in advertising or publicity pertaining to distribution of the
software without specific, written prior permission.

DIGITAL DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE, INCLUDING
ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO EVENT SHALL
DIGITAL BE LIABLE FOR ANY SPECIAL, INDIRECT OR CONSEQUENTIAL DAMAGES OR
ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE, DATA OR PROFITS,
WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER TORTIOUS ACTION,
ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE OF THIS
SOFTWARE.

******************************************************************/

import build.dix_config;

import core.stdc.stdio;
import core.stdc.string;
//import x11.X;
import externs.X11.Xatom;
import os.log;
import externs.gnu;

import dix.atom_priv;
import dix.dix_priv;

import common.misc;
import include.resource;
import externs.gnu;
import atoms;
alias strncmp = core.stdc.string.strncmp;


// enum Atom : int {
//     ATOM
// }
// alias Atom = uint;
// enum None = 0;
// enum XA_LAST_PREDEFINED = 68;
// enum BAD_RESOURCE = 0;

enum InitialTableSize = 256;

struct _Node {
    _Node* left, right;
    Atom a;
    uint fingerPrint;
    const(char)* string_;
}alias NodeRec = _Node;
alias NodePtr = _Node*;

private Atom lastAtom = 0;
private NodePtr atomRoot = null;
private c_ulong tableLength;
private NodePtr* nodeTable;

// Atom MakeAtom(const(char)* string, uint len, Bool makeit);

Atom
MakeAtom(const char *string_, uint len, Bool makeit)
{
    NodePtr *np = &atomRoot;
    uint fp = 0;
    for (uint i = 0; i < (len + 1) / 2; i++) {
        fp = fp * 27 + cast(uint)string_[i];
        fp = fp * 27 + cast(uint)string_[len - 1 - i];
    }
    while (*np !is null) {
        if (fp < (*np).fingerPrint)
            np = &((*np).left);
        else if (fp > (*np).fingerPrint)
            np = &((*np).right);
        else {                  /* now start testing the string_s */
//         pragma(msg, "strncmp = ", strncmp.stringof);
// pragma(msg, "typeof(strncmp) = ", typeof(strncmp).stringof);
            int comp = strncmp(string_, (*np).string_, len);
            if ((comp < 0) || ((comp == 0) && (len < strlen((*np).string_))))
                np = &((*np).left);
            else if (comp > 0)
                np = &((*np).right);
            else
                return (*np).a;
        }
    }
    if (makeit) {
        NodePtr nd = cast(NodePtr)calloc(1, (NodeRec).sizeof);
        if (!nd)
            return BAD_RESOURCE;
        if (lastAtom < XA_LAST_PREDEFINED) {
            nd.string_ = string_;
        }
        else {
            nd.string_ = cast(const(char)*)strndup(string_, len);
            if (!nd.string_) {
                free(nd);
                return BAD_RESOURCE;
            }
        }
        if ((lastAtom + 1) >= tableLength) {
            NodePtr *table;

            table = cast(NodePtr*)reallocarray(nodeTable, tableLength, 2 * NodePtr.sizeof);
            if (!table) {
                if (nd.string_ != string_) {
                    /* nd.string_ has been strdup'ed */
                    free(cast(void*)nd.string_);
                }
                free(nd);
                return BAD_RESOURCE;
            }
            tableLength <<= 1;
            nodeTable = table;
        }
        *np = nd;
        nd.left = nd.right = null;
        nd.fingerPrint = fp;
        nd.a = ++lastAtom;
        nodeTable[lastAtom] = nd;
        return nd.a;
    }
    else
        return None;
}


Bool
ValidAtom(Atom atom)
{
    return (atom != None) && (atom <= lastAtom);
}

const(char)* NameForAtom(Atom atom)
{
    if (atom > lastAtom)
        return null;

    if (nodeTable[atom] is null)
        return null;

    return nodeTable[atom].string_;
}

private void FreeAtom(NodePtr patom)
{
    if (patom.left)
        FreeAtom(patom.left);
    if (patom.right)
        FreeAtom(patom.right);
    if (patom.a > XA_LAST_PREDEFINED) {
        /*
         * All strings above XA_LAST_PREDEFINED are strdup'ed, so it's safe to
         * cast here
         */
        free(cast(char*) patom.string_);
    }
    free(patom);
}

void FreeAllAtoms()
{
    if (atomRoot is null)
        return;
    FreeAtom(atomRoot);
    atomRoot = null;
    free(nodeTable);
    nodeTable = null;
    lastAtom = None;
}

void InitAtoms()
{
    FreeAllAtoms();
    tableLength = InitialTableSize;
    nodeTable = cast(NodePtr*) calloc(InitialTableSize, NodePtr.sizeof);
    if (!nodeTable)
        FatalError("creating atom table");
    nodeTable[None] = null;
    MakePredeclaredAtoms();
    if (lastAtom != XA_LAST_PREDEFINED)
        FatalError("builtin atom number mismatch");
}
