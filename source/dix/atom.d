module dix.atom;
@nogc nothrow:
extern(C): __gshared:

/* SPDX-License-Identifier: MIT OR X11
 * 
 * Copyright © 2026, Roman Vlasov
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright 1987, 1998  The Open Group
 * Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.
 * 
 * See COPYING for the full license texts.
 */

import core.stdc.stdlib;
import core.stdc.string;
import externs.X11.Xatom;
import os.log;
import dix.dix_priv;
import dix.resource;
import atoms;

string charsToString(const char* chars) {
    return cast(immutable(char)[])chars[0..strlen(chars)];
}

// Atom-string pair
struct AtomData {
    Atom id;
    string string_;
}

// Atom-pair binary-tree node for fast searching
struct AtomBinTreeNode {
    AtomData atom;
    AtomBinTreeNode* left, right;
    uint fingerPrint;
}
alias NodePtr = AtomBinTreeNode*;

struct AtomManager {
    enum InitialTableSize = 256;
    private Atom lastAtom = 0;
    private NodePtr atomRoot = null;
    private size_t tableLength;
    private NodePtr* nodeTable;

@nogc nothrow:
    Atom makeAtom(const char *string_, uint len, Bool makeit) {
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
                int comp = strncmp(string_, (*np).atom.string_.ptr, len);
                if ((comp < 0) || ((comp == 0) && len < (*np).atom.string_.length))
                    np = &((*np).left);
                else if (comp > 0)
                    np = &((*np).right);
                else
                    return (*np).atom.id;
            }
        }
        if (makeit) {
            NodePtr nd = cast(NodePtr)calloc(1, AtomBinTreeNode.sizeof);
            if (!nd)
                return BAD_RESOURCE;
            if (lastAtom < XA_LAST_PREDEFINED) {
                nd.atom.string_ = string_.charsToString;
            }
            else {
                nd.atom.string_ = strndup(string_, len).charsToString;
                if (!nd.atom.string_) {
                    free(nd);
                    return BAD_RESOURCE;
                }
            }
            if ((lastAtom + 1) >= tableLength) {
                NodePtr *table;

                table = cast(NodePtr*)reallocarray(nodeTable, tableLength, 2 * NodePtr.sizeof);
                if (!table) {
                    if (nd.atom.string_ .ptr != string_) {
                        /* nd.atom.string_ has been strdup'ed */
                        free(cast(void*)nd.atom.string_.ptr);
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
            nd.atom.id = ++lastAtom;
            nodeTable[lastAtom] = nd;
            return nd.atom.id;
        }
        else
            return None;
    }

    Bool validAtom(Atom atom) {
        return (atom != None) && (atom <= lastAtom);
    }

    const(char)* nameForAtom(Atom atom) {
        if (atom > lastAtom)
            return null;

        if (nodeTable[atom] is null)
            return null;

        return nodeTable[atom].atom.string_.ptr;
    }

    private void freeAtom(NodePtr patom) {
        if (patom.left)
            freeAtom(patom.left);
        if (patom.right)
            freeAtom(patom.right);
        if (patom.atom.id > XA_LAST_PREDEFINED) {
            /*
            * All strings above XA_LAST_PREDEFINED are strdup'ed, so it's safe to
            * cast here
            */
            free(cast(char*) patom.atom.string_.ptr);
        }
        free(patom);
    }

    void freeAllAtoms() {
        if (atomRoot is null)
            return;
        freeAtom(atomRoot);
        atomRoot = null;
        free(nodeTable);
        nodeTable = null;
        lastAtom = None;
    }

    void initAtoms() {
        freeAllAtoms();
        tableLength = InitialTableSize;
        nodeTable = cast(NodePtr*) calloc(InitialTableSize, NodePtr.sizeof);
        if (!nodeTable)
            FatalError("creating atom table");
        nodeTable[None] = null;
        MakePredeclaredAtoms();
        if (lastAtom != XA_LAST_PREDEFINED)
            FatalError("builtin atom number mismatch");
    }
}

