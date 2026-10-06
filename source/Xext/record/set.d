module set;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1995, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR
OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
OTHER DEALINGS IN THE SOFTWARE.

Except as contained in this notice, the name of The Open Group shall
not be used in advertising or otherwise to promote the sale, use or
other dealings in this Software without prior written authorization
from The Open Group.

*/

/*

    See the header set.h for a description of the set ADT.

    Implementation Strategy

    A bit vector is an obvious choice to represent the set, but may take
    too much memory, depending on the numerically largest member in the
    set.  One expected common case is for the client to ask for *all*
    protocol.  This means it would ask for minor opcodes 0 through 65535.
    Representing this as a bit vector takes 8K -- and there may be
    multiple minor opcode intervals, as many as one per major (extension)
    opcode).  In such cases, a list-of-intervals representation would be
    preferable to reduce memory consumption.  Both representations will be
    implemented, and RecordCreateSet will decide heuristically which one
    to use based on the set members.

*/

import build.dix_config;

import core.stdc.string;

import include.misc;
import set;

enum string RecordIsMemberOfSet(string _pSet, string _m) = `
(*(`~_pSet~`).ops.IsMemberOfSet)((`~_pSet~`), (`~_m~`))`;

enum string RecordIterateSet(string _pSet, string _pIter, string _interval) =`
 (*(`~_pSet~`).ops.IterateSet)((`~_pSet~`),
	(`~_pIter~`), (`~_interval~`))`;

/* an interval of set members */
struct  RecordSetInterval{
    CARD16 first;
    CARD16 last;
};

struct _RecordSetRec {
    RecordSetOperations *ops;
} ;

alias RecordSetRec = _RecordSetRec;
alias RecordSetPtr = RecordSetRec*;

struct RecordSetOperations{
    void function(RecordSetPtr pSet) @nogc nothrow DestroySet;
    c_ulong function (RecordSetPtr pSet, int possible_member) @nogc nothrow IsMemberOfSet;
    RecordSetIteratePtr function(RecordSetPtr pSet,
                                       RecordSetIteratePtr pIter,
                                       RecordSetInterval * interval) @nogc nothrow IterateSet;
} ;

alias RecordSetIteratePtr = void*;

/*
 * Ideally we would always use _Alignof(type) here, but that requires C11, so
 * we approximate this using sizeof(void*) for older C standards as that
 * should be a valid assumption on all supported architectures.
 */
// static if (HasVersion!"__STDC__" && (__STDC_VERSION__ - 0 >= 201112L)) {
// enum string MinSetAlignment(string type) = `max(_Alignof(` ~ type ~ `), _Alignof(unsigned long))`;
// } else {
enum string MinSetAlignment(string type) = `cast(int)max((void*).sizeof, c_ulong.sizeof)`;
// }

private int maxMemberInInterval(RecordSetInterval* pIntervals, int nIntervals)
{
    int i = void;
    int maxMember = -1;

    for (i = 0; i < nIntervals; i++) {
        if (maxMember < cast(int) pIntervals[i].last)
            maxMember = pIntervals[i].last;
    }
    return maxMember;
}

private void NoopDestroySet(RecordSetPtr pSet)
{
}

/***************************************************************************/

/* set operations for bit vector representation */

struct _BitVectorSet {
    RecordSetRec baseSet;
    int maxMember;
    /* followed by the bit vector itself */
}alias BitVectorSet = _BitVectorSet;
alias BitVectorSetPtr = _BitVectorSet*;

enum BITS_PER_LONG = ulong.sizeof * 8;

private void BitVectorDestroySet(RecordSetPtr pSet)
{
    free(pSet);
}

private c_ulong BitVectorIsMemberOfSet(RecordSetPtr pSet, int pm)
{
    BitVectorSetPtr pbvs = cast(BitVectorSetPtr) pSet;
    c_ulong* pbitvec = void;

    if (cast(int) pm > pbvs.maxMember)
        return FALSE;
    pbitvec = cast(c_ulong*) (&pbvs[1]);
    return (pbitvec[pm / BITS_PER_LONG] &
            (cast(c_ulong) 1 << (pm % BITS_PER_LONG)));
}

private int BitVectorFindBit(RecordSetPtr pSet, int iterbit, Bool bitval)
{
    BitVectorSetPtr pbvs = cast(BitVectorSetPtr) pSet;
    c_ulong* pbitvec = cast(c_ulong*) (&pbvs[1]);
    int startlong = void;
    int startbit = void;
    int walkbit = void;
    int maxMember = void;
    c_ulong skipval = void;
    c_ulong bits = void;
    c_ulong usefulbits = void;

    startlong = cast(int)(iterbit / BITS_PER_LONG);
    pbitvec += cast(int)startlong;
    startbit = cast(int)(startlong * BITS_PER_LONG);
    skipval = bitval ? 0L : ~0L;
    maxMember = pbvs.maxMember;

    if (startbit > maxMember)
        return -1;
    bits = *pbitvec;
    usefulbits = ~((cast(c_ulong) 1 << (iterbit - startbit)) - 1);
    if ((bits & usefulbits) == (skipval & usefulbits)) {
        pbitvec++;
        startbit += BITS_PER_LONG;

        while (startbit <= maxMember && *pbitvec == skipval) {
            pbitvec++;
            startbit += BITS_PER_LONG;
        }
        if (startbit > maxMember)
            return -1;
    }

    walkbit = (startbit < iterbit) ? iterbit - startbit : 0;

    bits = *pbitvec;
    while (walkbit < BITS_PER_LONG &&
           ((!(bits & (cast(c_ulong) 1 << walkbit))) == bitval))
        walkbit++;

    return startbit + walkbit;
}

private RecordSetIteratePtr BitVectorIterateSet(RecordSetPtr pSet, RecordSetIteratePtr pIter, RecordSetInterval* pInterval)
{
    int iterbit = cast(int) cast(c_long) pIter;
    int b = void;

    b = BitVectorFindBit(pSet, iterbit, TRUE);
    if (b == -1)
        return cast(RecordSetIteratePtr) 0;
    pInterval.first = cast(ushort)b;

    b = BitVectorFindBit(pSet, b, FALSE);
    pInterval.last = cast(ushort)((b < 0) ? (cast(BitVectorSetPtr) pSet).maxMember : b - 1);
    return cast(RecordSetIteratePtr)(pInterval.last + 1);
}

private RecordSetOperations BitVectorSetOperations = {
    &BitVectorDestroySet, &BitVectorIsMemberOfSet, &BitVectorIterateSet
};

private RecordSetOperations BitVectorNoFreeOperations = {
    &NoopDestroySet, &BitVectorIsMemberOfSet, &BitVectorIterateSet
};

private int BitVectorSetMemoryRequirements(RecordSetInterval* pIntervals, int nIntervals, int maxMember, int* alignment)
{
    int nlongs = void;

    *alignment = mixin(MinSetAlignment!(`BitVectorSet`));
    nlongs = cast(int)((maxMember + BITS_PER_LONG) / BITS_PER_LONG);
    return cast(int)(((BitVectorSet).sizeof + nlongs * c_ulong.sizeof));
}

private RecordSetPtr BitVectorCreateSet(RecordSetInterval* pIntervals, int nIntervals, void* pMem, int memsize)
{
    BitVectorSetPtr pbvs = void;
    int i = void, j = void;
    c_ulong* pbitvec = void;

    /* allocate all storage needed by this set in one chunk */

    if (pMem) {
        memset(pMem, 0, memsize);
        pbvs = cast(BitVectorSetPtr) pMem;
        pbvs.baseSet.ops = &BitVectorNoFreeOperations;
    }
    else {
        pbvs = cast(BitVectorSetPtr) calloc(1, memsize);
        if (!pbvs)
            return null;
        pbvs.baseSet.ops = &BitVectorSetOperations;
    }

    pbvs.maxMember = maxMemberInInterval(pIntervals, nIntervals);

    /* fill in the set */

    pbitvec = cast(c_ulong*) (&pbvs[1]);
    for (i = 0; i < nIntervals; i++) {
        for (j = pIntervals[i].first; j <= cast(int) pIntervals[i].last; j++) {
            pbitvec[j / BITS_PER_LONG] |=
                (cast(c_ulong) 1 << (j % BITS_PER_LONG));
        }
    }
    return cast(RecordSetPtr) pbvs;
}

/***************************************************************************/

/* set operations for interval list representation */

struct _IntervalListSet {
    RecordSetRec baseSet;
    int nIntervals;
    /* followed by the intervals (RecordSetInterval) */
}alias IntervalListSet = _IntervalListSet;
alias IntervalListSetPtr = IntervalListSet*;

private void IntervalListDestroySet(RecordSetPtr pSet)
{
    free(pSet);
}

private c_ulong IntervalListIsMemberOfSet(RecordSetPtr pSet, int pm)
{
    IntervalListSetPtr prls = cast(IntervalListSetPtr) pSet;
    RecordSetInterval* pInterval = cast(RecordSetInterval*) (&prls[1]);
    int hi = void, lo = void, probe = void;

    /* binary search */
    lo = 0;
    hi = prls.nIntervals - 1;
    while (lo <= hi) {
        probe = (hi + lo) / 2;
        if (pm >= pInterval[probe].first && pm <= pInterval[probe].last)
            return 1;
        else if (pm < pInterval[probe].first)
            hi = probe - 1;
        else
            lo = probe + 1;
    }
    return 0;
}

private RecordSetIteratePtr IntervalListIterateSet(RecordSetPtr pSet, RecordSetIteratePtr pIter, RecordSetInterval* pIntervalReturn)
{
    RecordSetInterval* pInterval = cast(RecordSetInterval*) pIter;
    IntervalListSetPtr prls = cast(IntervalListSetPtr) pSet;

    if (pInterval is null) {
        pInterval = cast(RecordSetInterval*) (&prls[1]);
    }

    if ((pInterval - cast(RecordSetInterval*) (&prls[1])) < prls.nIntervals) {
        *pIntervalReturn = *pInterval;
        return cast(RecordSetIteratePtr) (++pInterval);
    }
    else
        return cast(RecordSetIteratePtr) null;
}

private RecordSetOperations IntervalListSetOperations = {
    &IntervalListDestroySet, &IntervalListIsMemberOfSet, &IntervalListIterateSet
};

private RecordSetOperations IntervalListNoFreeOperations = {
    &NoopDestroySet, &IntervalListIsMemberOfSet, &IntervalListIterateSet
};

private int IntervalListMemoryRequirements(RecordSetInterval* pIntervals, int nIntervals, int maxMember, int* alignment)
{
    *alignment = mixin(MinSetAlignment!(`IntervalListSet`));
    return cast(int)((IntervalListSet).sizeof + nIntervals * RecordSetInterval.sizeof);
}

private RecordSetPtr IntervalListCreateSet(RecordSetInterval* pIntervals, int nIntervals, void* pMem, int memsize)
{
    IntervalListSetPtr prls = void;
    int i = void, j = void, k = void;
    RecordSetInterval* stackIntervals = null;
    CARD16 first = void;

    if (nIntervals > 0) {
        stackIntervals = cast(RecordSetInterval*) calloc(nIntervals, RecordSetInterval.sizeof);
        if (!stackIntervals)
            return null;

        /* sort intervals, store in stackIntervals (insertion sort) */

        for (i = 0; i < nIntervals; i++) {
            first = pIntervals[i].first;
            for (j = 0; j < i; j++) {
                if (first < stackIntervals[j].first)
                    break;
            }
            for (k = i; k > j; k--) {
                stackIntervals[k] = stackIntervals[k - 1];
            }
            stackIntervals[j] = pIntervals[i];
        }

        /* merge abutting/overlapping intervals */

        for (i = 0; i < nIntervals - 1;) {
            if ((stackIntervals[i].last + cast(uint) 1) <
                stackIntervals[i + 1].first) {
                i++;            /* disjoint intervals */
            }
            else {
                stackIntervals[i].last = max(stackIntervals[i].last,
                                             stackIntervals[i + 1].last);
                nIntervals--;
                for (j = i + 1; j < nIntervals; j++)
                    stackIntervals[j] = stackIntervals[j + 1];
            }
        }
    }

    /* allocate and fill in set structure */

    if (pMem) {
        prls = cast(IntervalListSetPtr) pMem;
        prls.baseSet.ops = &IntervalListNoFreeOperations;
    }
    else {
        prls = cast(IntervalListSetPtr)
            calloc(1, ((IntervalListSet).sizeof +
                   nIntervals * RecordSetInterval.sizeof));
        if (!prls)
            goto bailout;
        prls.baseSet.ops = &IntervalListSetOperations;
    }
    if (stackIntervals)
        memcpy(&prls[1], stackIntervals, nIntervals * RecordSetInterval.sizeof);
    prls.nIntervals = nIntervals;
 bailout:
    free(stackIntervals);
    return cast(RecordSetPtr) prls;
}

alias RecordCreateSetProcPtr = RecordSetPtr function(RecordSetInterval* pIntervals, int nIntervals, void* pMem, int memsize);

private int _RecordSetMemoryRequirements(RecordSetInterval* pIntervals, int nIntervals, int* alignment, RecordCreateSetProcPtr* ppCreateSet)
{
    int bmsize = void, rlsize = void, bma = void, rla = void;
    int maxMember = void;

    /* find maximum member of set so we know how big to make the bit vector */
    maxMember = maxMemberInInterval(pIntervals, nIntervals);

    bmsize = BitVectorSetMemoryRequirements(pIntervals, nIntervals, maxMember,
                                            &bma);
    rlsize = IntervalListMemoryRequirements(pIntervals, nIntervals, maxMember,
                                            &rla);
    if (((nIntervals > 1) && (maxMember <= 255))
        || (bmsize < rlsize)) {
        *alignment = bma;
        *ppCreateSet = &BitVectorCreateSet;
        return bmsize;
    }
    else {
        *alignment = rla;
        *ppCreateSet = &IntervalListCreateSet;
        return rlsize;
    }
}

/***************************************************************************/

/* user-visible functions */

int RecordSetMemoryRequirements(RecordSetInterval* pIntervals, int nIntervals, int* alignment)
{
    RecordCreateSetProcPtr pCreateSet = void;

    return _RecordSetMemoryRequirements(pIntervals, nIntervals, alignment,
                                        &pCreateSet);
}

RecordSetPtr RecordCreateSet(RecordSetInterval* pIntervals, int nIntervals, void* pMem, int memsize)
{
    RecordCreateSetProcPtr pCreateSet = void;
    int alignment = void;
    int size = void;

    size = _RecordSetMemoryRequirements(pIntervals, nIntervals, &alignment,
                                        &pCreateSet);
    if (pMem) {
        if ((cast(c_long) pMem & (alignment - 1)) || memsize < size)
            return null;
    }
    return (*pCreateSet) (pIntervals, nIntervals, pMem, size);
}
