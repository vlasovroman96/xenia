module Xext.xf86bigfont;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*
 * BIGFONT extension for sharing font metrics between clients (if possible)
 * and for transmitting font metrics to clients in a compressed form.
 *
 * Copyright (c) 1999-2000  Bruno Haible
 * Copyright (c) 1999-2000  The XFree86 Project, Inc.
 */

/* THIS IS NOT AN X CONSORTIUM STANDARD */

/*
 * Big fonts suffer from the following: All clients that have opened a
 * font can access the complete glyph metrics array (the XFontStruct member
 * `per_char') directly, without going through a macro. Moreover these
 * glyph metrics are ink metrics, i.e. are not redundant even for a
 * fixed-width font. For a Unicode font, the size of this array is 768 KB.
 *
 * Problems: 1. It eats a lot of memory in each client. 2. All this glyph
 * metrics data is piped through the socket when the font is opened.
 *
 * This extension addresses these two problems for local clients, by using
 * shared memory. It also addresses the second problem for non-local clients,
 * by compressing the data before transmit by a factor of nearly 6.
 *
 * If you use this extension, your OS ought to nicely support shared memory.
 * This means: Shared memory should be swappable to the swap, and the limits
 * should be high enough (SHMMNI at least 64, SHMMAX at least 768 KB,
 * SHMALL at least 48 MB). It is a plus if your OS allows shmat() calls
 * on segments that have already been marked "removed", because it permits
 * these segments to be cleaned up by the OS if the X server is killed with
 * signal SIGKILL.
 *
 * This extension is transparently exploited by Xlib (functions XQueryFont,
 * XLoadQueryFont).
 */

import build.xlibre_server;


import core.sys.posix.sys.types;
import core.stdc.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.sys.shm;
import core.sys.posix.sys.stat;


import core.stdc.time;
import core.stdc.errno;

static if(CONFIG_MITSHM) {
version (Cygwin) {
import sys.param;
}
// import sys.sysmacros;
import core.sys.posix.sys.ipc;
import core.sys.posix.sys.shm;
import core.sys.posix.sys.stat;
} /* CONFIG_MITSHM */

//import x11.X;
//import x11.Xproto;
// //import externs.X11.extensions.xf86bigfproto;
// //import externs.X11.fonts.fontstruct; // libxfont2.h missed to include that
import externs.X11.fonts.libxfont2;

import dix.dix_priv;
import dix.request_priv;
import miext.extinit_priv;
import os.osdep;

import common.misc;
import include.os;
import os.osdep;
import dix.dixstruct_priv;
import dix.gc;
import dix.dixfonts;
import include.protocol_versions;

import Xext.xf86bigfontsrv;
import externs.X11.extensions.xf86bigfproto;
import externs.X11.fonts.fontstruct;
import externs.attrs;
import os.log;
import dix.extension;
import dix.dixutils;
import externs.X11.fonts.fontproto;
import Xext.shm_priv;

enum string FONTCHARSET(string font)	 = font;
enum string FONTMAXBOUNDS(string font,string field) = `(`~font~`).info.maxbounds.`~field;
enum string FONTMINBOUNDS(string font,string field) = `(`~font~`).info.minbounds.`~field;
enum string TERMINALFONT(string font) =`	  (`~font~`).info.terminalFont`;
enum string FONTASCENT(string font) =`	  (`~font~`).info.fontAscent`;
enum string FONTDESCENT(string font) =`	  (`~font~`).info.fontDescent`;
enum string FONTGLYPHS(string font) =`	  null`;
enum string FONTCONSTMETRICS(string font) =`	  (`~font~`).info.constantMetrics`;
enum string FONTCONSTWIDTH(string font) =`	  (`~font~`).info.constantWidth`;
enum string FONTALLEXIST(string font) =`	  (`~font~`).info.allExist`;
enum string FONTFIRSTCOL(string font) =`	  (`~font~`).info.firstCol`;
enum string FONTLASTCOL(string font) =`	  (`~font~`).info.lastCol`;
enum string FONTFIRSTROW(string font) =`	  (`~font~`).info.firstRow`;
enum string FONTLASTROW(string font) =`	  (`~font~`).info.lastRow`;
enum string FONTDEFAULTCH(string font) =`	  (`~font~`).info.defaultCh`;
enum string FONTINKMIN(string font) =`	  (&((`~font~`).info.ink_minbounds))`;
enum string FONTINKMAX(string font) =`	  (&((`~font~`).info.ink_maxbounds))`;
enum string FONTPROPS(string font) =`		  (`~font~`).info.props`;
enum string FONTGLYPHBITS(string base,string pci) =`	  (cast(ubyte *) (`~pci~`).bits)`;
enum string FONTINFONPROPS(string font) =`	  (`~font~`).info.nprops`;

Bool noXFree86BigfontExtension = FALSE;



static if(CONFIG_MITSHM) {

/* A random signature, transmitted to the clients so they can verify that the
   shared memory segment they are attaching to was really established by the
   X server they are talking to. */
CARD32 signature;

/* Index for additional information stored in a FontRec's devPrivates array. */
int FontShmdescIndex;

private uint pagesize;

private Bool badSysCall = FALSE;

static if (HasVersion!"__FreeBSD__" || HasVersion!"__NetBSD__" || HasVersion!"__OpenBSD__" || HasVersion!"Cygwin" || HasVersion!"__DragonFly__") {

private void SigSysHandler(int signo)
{
    badSysCall = TRUE;
}

private Bool CheckForShmSyscall()
{
    void function(int) oldHandler = void;
    int shmid = -1;

    /* If no SHM support in the kernel, the bad syscall will generate SIGSYS */
    oldHandler = OsSignal(SIGSYS, &SigSysHandler);

    badSysCall = FALSE;
    shmid = shmget(IPC_PRIVATE, 4096, IPC_CREAT);
    if (shmid != -1) {
        /* Successful allocation - clean up */
        shmctl(shmid, IPC_RMID, null);
    }
    else {
        /* Allocation failed */
        badSysCall = TRUE;
    }
    OsSignal(SIGSYS, oldHandler);
    return !badSysCall;
}

version = MUST_CHECK_FOR_SHM_SYSCALL;

}

/* ========== Management of shared memory segments ========== */

version (linux) {
/* On Linux, shared memory marked as "removed" can still be attached.
   Nice feature, because the kernel will automatically free the associated
   storage when the server and all clients are gone. */
version = EARLY_REMOVE;
}

struct _ShmDesc {
    _ShmDesc* next;
    _ShmDesc** prev;
    int shmid;
    char* attach_addr;
}alias ShmDescRec = _ShmDesc;
alias ShmDescPtr = _ShmDesc*;

private ShmDescPtr ShmList = cast(ShmDescPtr) null;

private ShmDescPtr shmalloc(uint size)
{
    int shmid = void;
    char* addr = void;

version (MUST_CHECK_FOR_SHM_SYSCALL) {
    if (pagesize == 0) {
        return cast(ShmDescPtr) null;
    }
}

    /* On some older Linux systems, the number of shared memory segments
       system-wide is 127. In Linux 2.4, it is 4095.
       Therefore there is a tradeoff to be made between allocating a
       shared memory segment on one hand, and allocating memory and piping
       the glyph metrics on the other hand. If the glyph metrics size is
       small, we prefer the traditional way. */
    if (size < 3500) {
        return cast(ShmDescPtr) null;
    }

    ShmDescPtr pDesc = cast(ShmDescPtr)cast(ShmDescRec*) calloc(1, ShmDescRec.sizeof);
    if (!pDesc) {
        return cast(ShmDescPtr) null;
    }

    size = (size + pagesize - 1) & -pagesize;
    shmid = shmget(IPC_PRIVATE, size, S_IWUSR | S_IRUSR | S_IRGRP | S_IROTH);
    if (shmid == -1) {
        ErrorF(XF86BIGFONTNAME~ " extension: shmget() failed, size = %u, %s\n",
               size, strerror(errno));
        free(pDesc);
        return cast(ShmDescPtr) null;
    }

    if ((addr = cast(char*)shmat(shmid, null, 0)) == cast(void*) -1) {
        ErrorF(XF86BIGFONTNAME ~" extension: shmat() failed, size = %u, %s\n",
               size, strerror(errno));
        shmctl(shmid, IPC_RMID, cast(shmid_ds*) null);
        free(pDesc);
        return cast(ShmDescPtr) null;
    }

version (EARLY_REMOVE) {
    shmctl(shmid, IPC_RMID, cast(shmid_ds*) null);
}

    pDesc.shmid = shmid;
    pDesc.attach_addr = addr;
    if (ShmList) {
        ShmList.prev = &pDesc.next;
    }
    pDesc.next = ShmList;
    pDesc.prev = &ShmList;
    ShmList = pDesc;

    return pDesc;
}

private void shmdealloc(ShmDescPtr pDesc)
{
version (EARLY_REMOVE) {} else {
    shmctl(pDesc.shmid, IPC_RMID, cast(void*) 0);
}
    shmdt(pDesc.attach_addr);

    if (pDesc.next) {
        pDesc.next.prev = pDesc.prev;
    }
    *pDesc.prev = pDesc.next;
    free(pDesc);
}

/* Called when a font is closed. */
void XF86BigfontFreeFontShm(FontPtr pFont)
{
    ShmDescPtr pDesc = void;

    /* If during shutdown of the server, XF86BigfontCleanup() has already
     * called shmdealloc() for all segments, we don't need to do it here.
     */
    if (!ShmList)
        return;

    pDesc = cast(ShmDescPtr) mixin(FontGetPrivate!("pFont", "FontShmdescIndex"));
    if (pDesc) {
        shmdealloc(pDesc);
    }
}

/* Called upon fatal signal. */
void XF86BigfontCleanup()
{
    while (ShmList) {
        shmdealloc(ShmList);
    }
}

} else { /* CONFIG_MITSHM */

void XF86BigfontFreeFontShm(FontPtr pFont) { }
void XF86BigfontCleanup() { }

} /* CONFIG_MITSHM */

/* Called when a server generation dies. */
private void XF86BigfontResetProc(ExtensionEntry* extEntry)
{
    /* This function is normally called from CloseDownExtensions(), called
     //pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
     * from main(). It will be followed by a call to FreeAllResources(),
     * which will call XF86BigfontFreeFontShm() for each font. Thus it
     * appears that we do not need to do anything in this function. --
     * But I prefer to write robust code, and not keep shared memory lying
     * around when it's not needed any more. (Someone might close down the
     * extension without calling FreeAllResources()...)
     */
    XF86BigfontCleanup();
}

/* ========== Handling of extension specific requests ========== */


private int ProcXF86BigfontQueryVersion(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86BigfontQueryVersionReq);

static if(CONFIG_MITSHM)
    xXF86BigfontQueryVersionReply reply = {
        majorVersion: SERVER_XF86BIGFONT_MAJOR_VERSION,
        minorVersion: SERVER_XF86BIGFONT_MINOR_VERSION,
        uid: geteuid(),
        gid: getegid(),
        signature: .signature,
        capabilities: (client.local && !client.swapped)
                         ? XF86Bigfont_CAP_LocalShm : 0
    };
else {
        xXF86BigfontQueryVersionReply reply = {
        majorVersion: SERVER_XF86BIGFONT_MAJOR_VERSION,
        minorVersion: SERVER_XF86BIGFONT_MINOR_VERSION,
        uid: geteuid(),
        gid: getegid()};
}

    mixin(X_REPLY_FIELD_CARD16!("majorVersion"));
    mixin(X_REPLY_FIELD_CARD16!("minorVersion"));
    mixin(X_REPLY_FIELD_CARD32!"uid");
    mixin(X_REPLY_FIELD_CARD32!"gid");
    mixin(X_REPLY_FIELD_CARD32!"signature");

    return mixin(X_SEND_REPLY_SIMPLE!("client", "reply"));
}

private void swapCharInfo(xCharInfo* pCI)
{
    swaps(&pCI.leftSideBearing);
    swaps(&pCI.rightSideBearing);
    swaps(&pCI.characterWidth);
    swaps(&pCI.ascent);
    swaps(&pCI.descent);
    swaps(&pCI.attributes);
}

pragma(inline, true) private void writeCharInfo(x_rpcbuf_t* rpcbuf, xCharInfo CI) {
    x_rpcbuf_write_INT16(rpcbuf, CI.leftSideBearing);
    x_rpcbuf_write_INT16(rpcbuf, CI.rightSideBearing);
    x_rpcbuf_write_INT16(rpcbuf, CI.characterWidth);
    x_rpcbuf_write_INT16(rpcbuf, CI.ascent);
    x_rpcbuf_write_INT16(rpcbuf, CI.descent);
    x_rpcbuf_write_CARD16(rpcbuf, CI.attributes);
}

/* static CARD32 hashCI (xCharInfo *p); */
enum string hashCI(string p) = `
	cast(CARD32)(((` ~ p ~ `.leftSideBearing << 27) + (` ~ p ~ `.leftSideBearing >> 5) + 
	          (` ~ p ~ `.rightSideBearing << 23) + (` ~ p ~ `.rightSideBearing >> 9) + 
	          (` ~ p ~ `.characterWidth << 16) + 
	          (` ~ p ~ `.ascent << 11) + (` ~ p ~ `.descent << 6)) ^ ` ~ p ~ `.attributes)`;

static int
ProcXF86BigfontQueryFont(ClientPtr client)
{
    mixin(X_REQUEST_HEAD_STRUCT!xXF86BigfontQueryFontReq);
    mixin(X_REQUEST_FIELD_CARD32!"id");

    FontPtr pFont;
    CARD32 stuff_flags;
    xCharInfo* pmax;
    xCharInfo* pmin;
    int nCharInfos;
    int shmid;

static if(CONFIG_MITSHM){
    ShmDescPtr pDesc = null;
} else {
    enum pDesc = 0;
} /* CONFIG_MITSHM */
    xCharInfo* pCI;
    CARD16* pIndex2UniqIndex;
    CARD16* pUniqIndex2Index;
    CARD32 nUniqCharInfos;

    /* protocol version is decided based on request packet size */
    switch (client.req_len) {
    case 2:                    /* client with version 1.0 libX11 */
        stuff_flags = (client.local &&
                       !client.swapped ? XF86Bigfont_FLAGS_Shm : 0);
        break;
    case 3:                    /* client with version 1.1 libX11 */
        stuff_flags = stuff.flags;
        break;
    default:
        return BadLength;
    }

    if (dixLookupFontable(&pFont, stuff.id, client, DixGetAttrAccess) !=
        Success)
        return BadFont;         /* protocol spec says only error is BadFont */

    pmax = mixin(FONTINKMAX!("pFont"));
    pmin = mixin(FONTINKMIN!("pFont"));
    nCharInfos =
        (pmax.rightSideBearing == pmin.rightSideBearing
         && pmax.leftSideBearing == pmin.leftSideBearing
         && pmax.descent == pmin.descent
         && pmax.ascent == pmin.ascent
         && pmax.characterWidth == pmin.characterWidth)
        ? 0 : mixin(N2dChars!("pFont"));
    shmid = -1;
    pCI = null;
    pIndex2UniqIndex = null;
    pUniqIndex2Index = null;
    nUniqCharInfos = 0;

if (nCharInfos > 0)
{
    static if(CONFIG_MITSHM)
    {
        if (!badSysCall)
        {
            pDesc = cast(ShmDescPtr)
                mixin(FontGetPrivate!(
                    "pFont",
                    "FontShmdescIndex"
                ));
        }

        /*
         * Existing shared memory block.
         */
        if (pDesc)
        {
            pCI = cast(xCharInfo*) pDesc.attach_addr;

            if (stuff_flags & XF86Bigfont_FLAGS_Shm)
            {
                shmid = pDesc.shmid;
            }
        }
        else
        {
            /*
             * Try to allocate new SHM block.
             */
            if (
                (stuff_flags & XF86Bigfont_FLAGS_Shm) &&
                !badSysCall
            )
            {
                pDesc = shmalloc(
                    cast(uint)(nCharInfos * xCharInfo.sizeof +
                    CARD32.sizeof)
                );
            }

            /*
             * SHM allocation succeeded.
             */
            if (pDesc)
            {
                pCI = cast(xCharInfo*)
                    pDesc.attach_addr;

                shmid = pDesc.shmid;
            }
        }
    }

    /*
     * Fallback allocation.
     */
    if (pCI is null)
    {
        pCI = cast(xCharInfo*)
            calloc(nCharInfos, xCharInfo.sizeof);

        if (pCI is null)
        {
            return BadAlloc;
        }
    }

    /*
     * Fill metrics.
     */
    {
        xCharInfo* prCI = pCI;
        int ninfos = 0;
        int ncols =
            pFont.info.lastCol -
            pFont.info.firstCol + 1;

        for (
            int row = pFont.info.firstRow;
            row <= pFont.info.lastRow &&
            ninfos < nCharInfos;
            row++
        )
        {
            ubyte[512] chars;
            xCharInfo*[256] tmpCharInfos;

            c_ulong count;
            c_ulong i = 0;

            for (
                int col = pFont.info.firstCol;
                col <= pFont.info.lastCol;
                col++
            )
            {
                chars[i++] = cast(ubyte) row;
                chars[i++] = cast(ubyte) col;
            }

            (cast( int function(
                FontPtr,
                c_ulong,
                ubyte*,
                FontEncoding,
                c_ulong*,
                xCharInfo**
            ) @nogc nothrow ) pFont.get_metrics)(
                pFont,
                ncols,
                chars.ptr,
                TwoD16Bit,
                &count,
                tmpCharInfos.ptr
            );

            for (
                i = 0;
                i < count && ninfos < nCharInfos;
                i++
            )
            {
                *prCI++ = *tmpCharInfos[i];
                ninfos++;
            }
        }
    }

    static if(CONFIG_MITSHM)
    {
        /*
         * Attach signature to SHM block.
         */
        if (pDesc && !badSysCall)
        {
            *cast(CARD32*)
                (pCI + nCharInfos) = signature;

            if (
                !xfont2_font_set_private(
                    pFont,
                    FontShmdescIndex,
                    pDesc
                )
            )
            {
                shmdealloc(pDesc);
                return BadAlloc;
            }
        }
    }

    /*
     * Deduplicate metrics for non-SHM transport.
     */
        if (shmid == -1) {
            /* Cannot use shared memory, so remove-duplicates the xCharInfos
               using a temporary hash table. */
            /* Note that CARD16 is suitable as index type, because
               nCharInfos <= 0x10000. */
            CARD32 hashModulus;
            CARD16* pHash2UniqIndex;
            CARD16* pUniqIndex2NextUniqIndex;
            CARD32 NextIndex;
            CARD32 NextUniqIndex;
            CARD16* tmp;
            CARD32 i, j;

            hashModulus = 67;
            if (hashModulus > nCharInfos + 1)
                hashModulus = nCharInfos + 1;

            tmp = cast(CARD16*) calloc(4 * nCharInfos + 1, CARD16.sizeof);
            if (!tmp) {
                if (!pDesc) {
                    free(pCI);
                }
                return BadAlloc;
            }
            pIndex2UniqIndex = tmp;
            /* nCharInfos elements */
            pUniqIndex2Index = tmp + nCharInfos;
            /* max. nCharInfos elements */
            pUniqIndex2NextUniqIndex = tmp + 2 * nCharInfos;
            /* max. nCharInfos elements */
            pHash2UniqIndex = tmp + 3 * nCharInfos;
            /* hashModulus (<= nCharInfos+1) elements */

            /* Note that we can use 0xffff as end-of-list indicator, because
               even if nCharInfos = 0x10000, 0xffff can not occur as valid
               entry before the last element has been inserted. And once the
               last element has been inserted, we don't need the hash table
               any more. */
            for (j = 0; j < hashModulus; j++) {
                pHash2UniqIndex[j] = cast(CARD16) (-1);
            }

            NextUniqIndex = 0;
            for (NextIndex = 0; NextIndex < nCharInfos; NextIndex++) {
                xCharInfo* p = &pCI[NextIndex];
                CARD32 hashCode = mixin(hashCI!(`p`)) % hashModulus;

                for (i = pHash2UniqIndex[hashCode];
                     i != cast(CARD16) (-1); i = pUniqIndex2NextUniqIndex[i]) {
                    j = pUniqIndex2Index[i];
                    if (pCI[j].leftSideBearing == p.leftSideBearing
                        && pCI[j].rightSideBearing == p.rightSideBearing
                        && pCI[j].characterWidth == p.characterWidth
                        && pCI[j].ascent == p.ascent
                        && pCI[j].descent == p.descent
                        && pCI[j].attributes == p.attributes)
                        break;
                }
                if (i != cast(CARD16) (-1)) {
                    /* Found *p at Index j, UniqIndex i */
                    pIndex2UniqIndex[NextIndex] = cast(ushort)i;
                }
                else {
                    /* Allocate a new entry in the Uniq table */
                    if (hashModulus <= 2 * NextUniqIndex
                        && hashModulus < nCharInfos + 1) {
                        /* Time to increate hash table size */
                        hashModulus = 2 * hashModulus + 1;
                        if (hashModulus > nCharInfos + 1) {
                            hashModulus = nCharInfos + 1;
                        }
                        for (j = 0; j < hashModulus; j++) {
                            pHash2UniqIndex[j] = cast(CARD16) (-1);
                        }
                        for (i = 0; i < NextUniqIndex; i++) {
                            pUniqIndex2NextUniqIndex[i] = cast(CARD16) (-1);
                        }
                        for (i = 0; i < NextUniqIndex; i++) {
                            j = pUniqIndex2Index[i];
                            p = &pCI[j];
                            hashCode = mixin(hashCI!(`p`)) % hashModulus;
                            pUniqIndex2NextUniqIndex[i] = pHash2UniqIndex[hashCode];
                            pHash2UniqIndex[hashCode] = cast(ushort)i;
                        }
                        p = &pCI[NextIndex];
                        hashCode = mixin(hashCI!(`p`)) % hashModulus;
                    }
                    i = NextUniqIndex++;
                    pUniqIndex2NextUniqIndex[i] = pHash2UniqIndex[hashCode];
                    pHash2UniqIndex[hashCode] = cast(ushort)i;
                    pUniqIndex2Index[i] = cast(ushort)NextIndex;
                    pIndex2UniqIndex[NextIndex] = cast(ushort)i;
                }
            }
            nUniqCharInfos = NextUniqIndex;
            /* fprintf(stderr, "font metrics: nCharInfos = %d, nUniqCharInfos = %d, hashModulus = %d\n", nCharInfos, nUniqCharInfos, hashModulus); */
        }
    }

    {
        int nfontprops = pFont.info.nprops;
        xXF86BigfontQueryFontReply reply = {
            minBounds: pFont.info.ink_minbounds,
            maxBounds: pFont.info.ink_maxbounds,
            minCharOrByte2: pFont.info.firstCol,
            maxCharOrByte2: pFont.info.lastCol,
            defaultChar: pFont.info.defaultCh,
            nFontProps: cast(ushort)pFont.info.nprops,
            drawDirection: cast(ubyte)pFont.info.drawDirection,
            minByte1: cast(ubyte)pFont.info.firstRow,
            maxByte1: cast(ubyte)pFont.info.lastRow,
            allCharsExist: cast(ubyte)pFont.info.allExist,
            fontAscent: pFont.info.fontAscent,
            fontDescent: pFont.info.fontDescent,
            nCharInfos: nCharInfos,
            nUniqCharInfos: nUniqCharInfos,
            shmid: shmid,
        };

        mixin(X_REPLY_FIELD_CARD16!"minCharOrByte2");
        mixin(X_REPLY_FIELD_CARD16!"maxCharOrByte2");
        mixin(X_REPLY_FIELD_CARD16!"defaultChar");
        mixin(X_REPLY_FIELD_CARD16!"nFontProps");
        mixin(X_REPLY_FIELD_CARD16!"fontAscent");
        mixin(X_REPLY_FIELD_CARD16!"fontDescent");
        mixin(X_REPLY_FIELD_CARD32!"nCharInfos");
        mixin(X_REPLY_FIELD_CARD32!"nUniqCharInfos");
        mixin(X_REPLY_FIELD_CARD32!"shmid");
        mixin(X_REPLY_FIELD_CARD32!"shmsegoffset");

        if (client.swapped) {
            swapCharInfo(&reply.minBounds);
            swapCharInfo(&reply.maxBounds);
        }

        x_rpcbuf_t rpcbuf = { swapped: client.swapped, err_clear: TRUE };

        for (int i = 0; i < nfontprops; i++) {
            x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)pFont.info.props[i].name);
            x_rpcbuf_write_CARD32(&rpcbuf, cast(uint)pFont.info.props[i].value);
        }

        if (nCharInfos > 0 && shmid == -1) {
            for (int i = 0; i < nUniqCharInfos; i++) {
                writeCharInfo(&rpcbuf, pCI[pUniqIndex2Index[i]]);
            }
            x_rpcbuf_write_CARD16s(&rpcbuf, pIndex2UniqIndex, nCharInfos);
        }

        int rc = mixin(X_SEND_REPLY_WITH_RPCBUF!("client", "reply", "rpcbuf"));

        if (nCharInfos > 0) {
            if (shmid == -1) {
                free(pIndex2UniqIndex);
            }
            if (!pDesc) {
                free(pCI);
            }
        }
        return rc;
    }
}

private int ProcXF86BigfontDispatch(ClientPtr client)
{
    mixin(REQUEST!xReq);

    switch (stuff.data) {
    case X_XF86BigfontQueryVersion:
        return ProcXF86BigfontQueryVersion(client);
    case X_XF86BigfontQueryFont:
        return ProcXF86BigfontQueryFont(client);
    default:
        return BadRequest;
    }
}

void XFree86BigfontExtensionInit()
{
    if (AddExtension(XF86BIGFONTNAME,
                     XF86BigfontNumberEvents,
                     XF86BigfontNumberErrors,
                     &ProcXF86BigfontDispatch,
                     &ProcXF86BigfontDispatch,
                     &XF86BigfontResetProc, &StandardMinorOpcode)) {
static if(CONFIG_MITSHM){
version (MUST_CHECK_FOR_SHM_SYSCALL) {
        /*
         * Note: Local-clients will not be optimized without shared memory
         * support. Remote-client optimization does not depend on shared
         * memory support.  Thus, the extension is still registered even
         * when shared memory support is not functional.
         */
        if (!CheckForShmSyscall()) {
            ErrorF(XF86BIGFONTNAME~
                   " extension local-client optimization disabled due to lack of shared memory support in the kernel\n");
            return;
        }
}

        srand(cast(uint) time(null));
        signature = (cast(uint) (65536.0 / (RAND_MAX + 1.0) * rand()) << 16)
            + cast(uint) (65536.0 / (RAND_MAX + 1.0) * rand());
        /* fprintf(stderr, "signature = 0x%08X\n", signature); */

        FontShmdescIndex = xfont2_allocate_font_private_index();

static if (!HasVersion!"CSRG_BASED" && !HasVersion!"Cygwin") {
        pagesize = SHMLBA;
} else {
version (_SC_PAGESIZE) {
        pagesize = sysconf(_SC_PAGESIZE);
} else {
        pagesize = getpagesize();
}
}
} /* CONFIG_MITSHM */
    }
}
