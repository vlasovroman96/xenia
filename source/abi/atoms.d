module abi.atoms;

import externs.X11.Xatom;
import dix.globals;

@nogc: nothrow:
extern(C): 

Atom MakeAtom(const char *string_, uint len, Bool makeit) => atomMgr.makeAtom(string_, len, makeit);
Bool ValidAtom(Atom atom) => atomMgr.validAtom(atom);
const(char)* NameForAtom(Atom atom) => atomMgr.nameForAtom(atom);
void FreeAllAtoms() => atomMgr.freeAllAtoms();
void InitAtoms() => atomMgr.initAtoms();