module InitOutput;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*

Copyright 1993, 1998  The Open Group

Permission to use, copy, modify, distribute, and sell this software and its
documentation for any purpose is hereby granted without fee, provided that
the above copyright notice appear in all copies and that both that
copyright notice and this permission notice appear in supporting
documentation.

The above copyright notice and this permission notice shall be included
in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
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

import build.dix_config;

version (Windows) {
//import externs.X11.Xwinsock;
}
import core.stdc.stdio;
//import x11.X;
//import x11.Xproto;
// //import x11.Xos;

import dix.colormap_priv;
import dix.dix_priv;
import dix.screenint_priv;
import include.extinit;
import mi.mi_priv;
import mi.mipointer_priv;
import os.cmdline;
import os.ddx_priv;
import os.osdep;
import os.xhostname;

import include.scrnintstr;
import include.servermd;
enum PSZ = 8;
import include.fb;
import include.gcstruct;
import include.input;
import mi.mipointer;
import mi.micmap;
import glx.glxext;

import core.sys.posix.sys.types;
version (HAVE_MMAP) {
import core.sys.posix.sys.mman;
enum MAP_FILE = 0;

}                          /* HAVE_MMAP */
import core.sys.posix.sys.stat;
import core.stdc.errno;
version (Windows) {} else {
import externs.sys.param;
}
import externs.X11.XWDFile;
static if(CONFIG_MITSHM){
import core.sys.posix.sys.ipc;
import core.sys.posix.sys.shm;
} /* CONFIG-MITSHM */
import include.dix;
import include.miline;
import include.glx_extinit;
import include.randrstr;

static if (GLAMOR) {
import include.glamor;
import glamor.glamor_egl;

import core.sys.posix.unistd;
import core.sys.posix.fcntl;
}

enum VFB_DEFAULT_WIDTH =      1280;
enum VFB_DEFAULT_HEIGHT =     1024;
enum VFB_DEFAULT_DEPTH =        24;
enum VFB_DEFAULT_WHITEPIXEL =    1;
enum VFB_DEFAULT_BLACKPIXEL =    0;
enum VFB_DEFAULT_LINEBIAS =      0;
enum VFB_DEFAULT_NUM_CRTCS =     1;
enum XWD_WINDOW_NAME_LEN =      60;

struct _VfbCrtcInfo {
    int width;
    int height;
    int x;
    int y;
    int numOutputs;
}alias vfbCrtcInfo = _VfbCrtcInfo;
alias vfbCrtcInfoPtr = vfbCrtcInfo*;

struct _VfbScreenInfo {
    int width;
    int paddedBytesWidth;
    int paddedWidth;
    int height;
    int depth;
    int bitsPerPixel;
    int sizeInBytes;
    int ncolors;
    int numCrtcs;
    vfbCrtcInfoPtr crtcs;
    char* pfbMemory;
    XWDColor* pXWDCmap;
    XWDFileHeader* pXWDHeader;
    Pixel blackPixel;
    Pixel whitePixel;
    uint lineBias;
    CloseScreenProcPtr closeScreen;

version (HAVE_MMAP) {
    int mmap_fd;
    char[MAXPATHLEN] mmap_file = 0;
}

static if(CONFIG_MITSHM){
    int shmid;
} /* CONFIG_MITSHM */
static if (GLAMOR) {
    int dri_fd;
}
}alias vfbScreenInfo = _VfbScreenInfo;
alias vfbScreenInfoPtr = vfbScreenInfo*;

 int vfbNumScreens;
 vfbScreenInfo* vfbScreens;

 vfbScreenInfo defaultScreenInfo = {
    width: VFB_DEFAULT_WIDTH,
    height: VFB_DEFAULT_HEIGHT,
    depth: VFB_DEFAULT_DEPTH,
    blackPixel: VFB_DEFAULT_BLACKPIXEL,
    whitePixel: VFB_DEFAULT_WHITEPIXEL,
    lineBias: VFB_DEFAULT_LINEBIAS,
};

 Bool[33] vfbPixmapDepths;

version (HAVE_MMAP) {
 char* pfbdir = null;
}
enum fbMemType { NORMAL_MEMORY_FB, SHARED_MEMORY_FB, MMAPPED_FILE_FB }
alias NORMAL_MEMORY_FB = fbMemType.NORMAL_MEMORY_FB;
alias SHARED_MEMORY_FB = fbMemType.SHARED_MEMORY_FB;
alias MMAPPED_FILE_FB = fbMemType.MMAPPED_FILE_FB;

 fbMemType fbmemtype = NORMAL_MEMORY_FB;
 char needswap = 0;
 Bool Render = TRUE;
static if (GLAMOR) {
 Bool use_glamor = FALSE;
 char* render_node = null;
}

enum string swapcopy16(string _dst, string _src) = `
    if (needswap) { CARD16 _s = ` ~ _src ~ `; cpswaps(_s, ` ~ _dst ~ `); } 
    else ` ~ _dst ~ ` = ` ~ _src ~ `;`;

enum string swapcopy32(string _dst, string _src) = `
    if (needswap) { CARD32 _s = ` ~ _src ~ `; cpswapl(_s, ` ~ _dst ~ `); } 
    else ` ~ _dst ~ ` = ` ~ _src ~ `;`;

 void vfbAddCrtcInfo(vfbScreenInfoPtr screen, int numCrtcs)
{
    int i = void;
    int count = numCrtcs - screen.numCrtcs;

    if (count > 0) {
        vfbCrtcInfoPtr crtcs = reallocarray(screen.crtcs, numCrtcs, typeof(*crtcs).sizeof);
        if (!crtcs)
            FatalError("Not enough memory for %d CRTCs", numCrtcs);

        memset(crtcs + screen.numCrtcs, 0, count * typeof(*crtcs).sizeof);

        for (i = screen.numCrtcs; i < numCrtcs; ++i) {
            crtcs[i].width = screen.width;
            crtcs[i].height = screen.height;
        }

        screen.crtcs = crtcs;
        screen.numCrtcs = numCrtcs;
    }
}

 vfbScreenInfoPtr vfbInitializeScreenInfo(vfbScreenInfoPtr screen)
{
    *screen = defaultScreenInfo;
    vfbAddCrtcInfo(screen, VFB_DEFAULT_NUM_CRTCS);

    /* First CRTC initializes with one output */
    if (screen.numCrtcs > 0)
        screen.crtcs[0].numOutputs = 1;

    return screen;
}

 void vfbInitializePixmapDepths()
{
    int i = void;

    vfbPixmapDepths[1] = TRUE;  /* always need bitmaps */
    for (i = 2; i <= 32; i++)
        vfbPixmapDepths[i] = FALSE;
}

 int vfbBitsPerPixel(int depth)
{
    if (depth == 1)
        return 1;
    else if (depth <= 8)
        return 8;
    else if (depth <= 16)
        return 16;
    else
        return 32;
}

 void freeScreenInfo(vfbScreenInfoPtr pvfb)
{
    switch (fbmemtype) {
version (HAVE_MMAP) {
    case MMAPPED_FILE_FB:
        if (-1 == unlink(pvfb.mmap_file)) {
            perror("unlink");
            ErrorF("unlink %s failed, %s",
                   pvfb.mmap_file, strerror(errno));
        }
        break;
} else {                           /* HAVE_MMAP */
    case MMAPPED_FILE_FB:
        break;
}                          /* HAVE_MMAP */

static if(CONFIG_MITSHM){
    case SHARED_MEMORY_FB:
        if (-1 == shmdt(cast(char*) pvfb.pXWDHeader)) {
            perror("shmdt");
            ErrorF("shmdt failed, %s", strerror(errno));
        }
        break;
} else { /* CONFIG_MITSHM */
    case SHARED_MEMORY_FB:
        break;
} /* CONFIG_MITSHM */

    case NORMAL_MEMORY_FB:
        free(pvfb.pXWDHeader);
        break;
    default: break;}

    free(pvfb.crtcs);
}

void ddxGiveUp(ExitCode error)
{
    int i = void;

    /* clean up the framebuffers */
    for (i = 0; i < vfbNumScreens; i++) {
        freeScreenInfo(&vfbScreens[i]);
    }
}

void OsVendorInit()
{
}

void OsVendorFatalError(const(char)* f, va_list args)
{
}

static if (INPUTTHREAD) {
/** This function is called in Xserver/os/inputthread.c when starting
    the input thread. */
void ddxInputThreadInit()
{
}
}

void ddxUseMsg()
{
    ErrorF("-screen scrn WxHxD     set screen's width, height, depth\n");
    ErrorF("-pixdepths list-of-int support given pixmap depths\n");
    ErrorF("+/-render		   turn on/off RENDER extension support"
           ~ "(default on)\n");
    ErrorF("-linebias n            adjust thin line pixelization\n");
    ErrorF("-blackpixel n          pixel value for black\n");
    ErrorF("-whitepixel n          pixel value for white\n");

version (HAVE_MMAP) {
    ErrorF
        ("-fbdir directory       put framebuffers in mmap'ed files in directory\n");
}

static if(CONFIG_MITSHM){
    ErrorF("-shmem                 put framebuffers in shared memory\n");
} /* CONFIG_MITSHM */

static if (GLAMOR) {
    ErrorF("-glamor                enable glamor render acceleration\n");
    ErrorF("-dri </dev/dri/renderDxxx>  render device to use\n");
}

    ErrorF("-crtcs n               number of CRTCs per screen (default: %d)\n",
           VFB_DEFAULT_NUM_CRTCS);
}

int ddxProcessArgument(int argc, char** argv, int i)
{
    static Bool firstTime = TRUE;
    static int lastScreen = -1;
    vfbScreenInfo* currentScreen = void;

    if (firstTime) {
        vfbInitializePixmapDepths();
        firstTime = FALSE;
    }

    if (lastScreen == -1)
        currentScreen = vfbInitializeScreenInfo(&defaultScreenInfo);
    else
        currentScreen = &vfbScreens[lastScreen];

    if (strcmp(argv[i], "-screen") == 0) {      /* -screen n WxHxD */
        int screenNum = void;

        CHECK_FOR_REQUIRED_ARGUMENTS(2);
        screenNum = atoi(argv[i + 1]);
        /* The protocol only has a CARD8 for number of screens in the
           connection setup block, so don't allow more than that. */
        if ((screenNum < 0) || (screenNum >= 255)) {
            ErrorF("Invalid screen number %d\n", screenNum);
            UseMsg();
            FatalError("Invalid screen number %d passed to -screen\n",
                       screenNum);
        }

        if (vfbNumScreens <= screenNum) {
            vfbScreens =
                reallocarray(vfbScreens, screenNum + 1, typeof(*vfbScreens).sizeof);
            if (!vfbScreens)
                FatalError("Not enough memory for screen %d\n", screenNum);
            for (; vfbNumScreens <= screenNum; ++vfbNumScreens)
                vfbInitializeScreenInfo(&vfbScreens[vfbNumScreens]);
        }

        if (3 != sscanf(argv[i + 2], "%dx%dx%d",
                        &vfbScreens[screenNum].width,
                        &vfbScreens[screenNum].height,
                        &vfbScreens[screenNum].depth)) {
            ErrorF("Invalid screen configuration %s\n", argv[i + 2]);
            UseMsg();
            FatalError("Invalid screen configuration %s for -screen %d\n",
                       argv[i + 2], screenNum);
        }

        lastScreen = screenNum;
        return 3;
    }

    if (strcmp(argv[i], "-pixdepths") == 0) {   /* -pixdepths list-of-depth */
        int depth = void, ret = 1;

        CHECK_FOR_REQUIRED_ARGUMENTS(1);
        while ((++i < argc) && (depth = atoi(argv[i])) != 0) {
            if (depth < 0 || depth > 32) {
                ErrorF("Invalid pixmap depth %d\n", depth);
                UseMsg();
                FatalError("Invalid pixmap depth %d passed to -pixdepths\n",
                           depth);
            }
            vfbPixmapDepths[depth] = TRUE;
            ret++;
        }
        return ret;
    }

    if (strcmp(argv[i], "+render") == 0) {      /* +render */
        Render = TRUE;
        return 1;
    }

    if (strcmp(argv[i], "-render") == 0) {      /* -render */
        Render = FALSE;
        noCompositeExtension = TRUE;
        return 1;
    }

    if (strcmp(argv[i], "-blackpixel") == 0) {  /* -blackpixel n */
        CHECK_FOR_REQUIRED_ARGUMENTS(1);
        currentScreen.blackPixel = atoi(argv[++i]);
        return 2;
    }

    if (strcmp(argv[i], "-whitepixel") == 0) {  /* -whitepixel n */
        CHECK_FOR_REQUIRED_ARGUMENTS(1);
        currentScreen.whitePixel = atoi(argv[++i]);
        return 2;
    }

    if (strcmp(argv[i], "-linebias") == 0) {    /* -linebias n */
        CHECK_FOR_REQUIRED_ARGUMENTS(1);
        currentScreen.lineBias = atoi(argv[++i]);
        return 2;
    }

version (HAVE_MMAP) {
    if (strcmp(argv[i], "-fbdir") == 0) {       /* -fbdir directory */
        CHECK_FOR_REQUIRED_ARGUMENTS(1);
        pfbdir = argv[++i];
        fbmemtype = MMAPPED_FILE_FB;
        return 2;
    }
}                          /* HAVE_MMAP */

static if(CONFIG_MITSHM){
    if (strcmp(argv[i], "-shmem") == 0) {       /* -shmem */
        fbmemtype = SHARED_MEMORY_FB;
        return 1;
    }
} /* CONFIG_MITSHM */

static if (GLAMOR) {
    if (strcmp(argv[i], "-glamor") == 0) {
        use_glamor = TRUE;
        return 1;
    }

    if (strcmp(argv[i], "-dri") == 0) {
        if (i + 1 < argc) {
            render_node = strdup(argv[i + 1]);
            return 2;
        }
        UseMsg();
        exit(1);
    }
}

    if (strcmp(argv[i], "-crtcs") == 0) {       /* -crtcs n */
        int numCrtcs = void;

        CHECK_FOR_REQUIRED_ARGUMENTS(1);
        numCrtcs = atoi(argv[i + 1]);

        if (numCrtcs < 1) {
            ErrorF("Invalid number of CRTCs %d\n", numCrtcs);
            UseMsg();
            FatalError("Invalid number of CRTCs (%d) passed to -crtcs\n",
                       numCrtcs);

        }

        vfbAddCrtcInfo(currentScreen, numCrtcs);
        return 2;
    }

    return 0;
}

 void vfbInstallColormap(ColormapPtr pmap)
{
    ColormapPtr oldpmap = GetInstalledmiColormap(pmap.pScreen);

    if (pmap != oldpmap) {
        int entries = void;
        XWDFileHeader* pXWDHeader = void;
        VisualPtr pVisual = void;
        Pixel* ppix = void;
        xrgb* prgb = void;
        xColorItem* defs = void;
        int i = void;

        miInstallColormap(pmap);

        entries = pmap.pVisual.ColormapEntries;
        pXWDHeader = vfbScreens[pmap.pScreen.myNum].pXWDHeader;
        pVisual = pmap.pVisual;

        mixin(swapcopy32!(`pXWDHeader.visual_class`, `pVisual.class_`));
        mixin(swapcopy32!(`pXWDHeader.red_mask`, `pVisual.redMask`));
        mixin(swapcopy32!(`pXWDHeader.green_mask`, `pVisual.greenMask`));
        mixin(swapcopy32!(`pXWDHeader.blue_mask`, `pVisual.blueMask`));
        mixin(swapcopy32!(`pXWDHeader.bits_per_rgb`, `pVisual.bitsPerRGBValue`));
        mixin(swapcopy32!(`pXWDHeader.colormap_entries`, `pVisual.ColormapEntries`));

        ppix = cast(Pixel*) calloc(entries, Pixel.sizeof);
        prgb = cast(xrgb*) calloc(entries, xrgb.sizeof);
        defs = cast(xColorItem*) calloc(entries, xColorItem.sizeof);
        if (!ppix || !prgb || !defs)
            goto out_;

        for (i = 0; i < entries; i++)
            ppix[i] = i;
        /* XXX truecolor */
        QueryColors(pmap, entries, ppix, prgb, serverClient);

        for (i = 0; i < entries; i++) { /* convert xrgbs to xColorItems */
            defs[i].pixel = ppix[i] & 0xff;     /* change pixel to index */
            defs[i].red = prgb[i].red;
            defs[i].green = prgb[i].green;
            defs[i].blue = prgb[i].blue;
            defs[i].flags = DoRed | DoGreen | DoBlue;
        }
        (*pmap.pScreen.StoreColors) (pmap, entries, defs);

out_:
        free(ppix);
        free(prgb);
        free(defs);
    }
}

 void vfbStoreColors(ColormapPtr pmap, int ndef, xColorItem* pdefs)
{
    XWDColor* pXWDCmap = void;
    int i = void;

    if (pmap != GetInstalledmiColormap(pmap.pScreen)) {
        return;
    }

    pXWDCmap = vfbScreens[pmap.pScreen.myNum].pXWDCmap;

    if ((pmap.pVisual.class_ | DynamicClass) == DirectColor) {
        return;
    }

    for (i = 0; i < ndef; i++) {
        if (pdefs[i].flags & DoRed) {
            mixin(swapcopy16!(`pXWDCmap[pdefs[i].pixel].red`, `pdefs[i].red`));
        }
        if (pdefs[i].flags & DoGreen) {
            mixin(swapcopy16!(`pXWDCmap[pdefs[i].pixel].green`, `pdefs[i].green`));
        }
        if (pdefs[i].flags & DoBlue) {
            mixin(swapcopy16!(`pXWDCmap[pdefs[i].pixel].blue`, `pdefs[i].blue`));
        }
    }
}

version (HAVE_MMAP) {

/* this flushes any changes to the screens out to the mmapped file */
 void vfbBlockHandler(void* blockData, void* timeout)
{
    int i = void;

    for (i = 0; i < vfbNumScreens; i++) {
version (MS_ASYNC) {
        if (-1 == msync(cast(caddr_t) vfbScreens[i].pXWDHeader,
                        cast(size_t) vfbScreens[i].sizeInBytes, MS_ASYNC))
                                {
            perror("msync");
            ErrorF("msync failed, %s", strerror(errno));
        }
} else {
        /* silly NetBSD and who else? */
        if (-1 == msync(cast(caddr_t) vfbScreens[i].pXWDHeader,
                        cast(size_t) vfbScreens[i].sizeInBytes))
                                {
            perror("msync");
            ErrorF("msync failed, %s", strerror(errno));
        }
}
}

 void vfbWakeupHandler(void* blockData, int result)
{
}

 void vfbAllocateMmappedFramebuffer(vfbScreenInfoPtr pvfb)
{
enum DUMMY_BUFFER_SIZE = 65536;
    char[DUMMY_BUFFER_SIZE] dummyBuffer = void;
    int currentFileSize = void, writeThisTime = void;

    snprintf(pvfb.mmap_file, typeof(pvfb.mmap_file).sizeof, "%s/Xvfb_screen%d",
             pfbdir, cast(int) (pvfb - vfbScreens));
    if (-1 == (pvfb.mmap_fd = open(pvfb.mmap_file, O_CREAT | O_RDWR, octal!"0666"))) {
        perror("open");
        ErrorF("open %s failed, %s", pvfb.mmap_file, strerror(errno));
        return;
    }

    /* Extend the file to be the proper size */

    memset(dummyBuffer.ptr, 0, DUMMY_BUFFER_SIZE);
    for (currentFileSize = 0;
         currentFileSize < pvfb.sizeInBytes;
         currentFileSize += writeThisTime) {
        writeThisTime = min(DUMMY_BUFFER_SIZE,
                            pvfb.sizeInBytes - currentFileSize);
        if (-1 == write(pvfb.mmap_fd, dummyBuffer.ptr, writeThisTime)) {
            perror("write");
            ErrorF("write %s failed, %s", pvfb.mmap_file, strerror(errno));
            return;
        }
    }

    /* try to mmap the file */

    pvfb.pXWDHeader = cast(XWDFileHeader*) mmap(cast(caddr_t) null, pvfb.sizeInBytes,
                                              PROT_READ | PROT_WRITE,
                                              MAP_FILE | MAP_SHARED,
                                              pvfb.mmap_fd, 0);
    if (-1 == cast(c_long) pvfb.pXWDHeader) {
        perror("mmap");
        ErrorF("mmap %s failed, %s", pvfb.mmap_file, strerror(errno));
        pvfb.pXWDHeader = null;
        return;
    }

    if (!RegisterBlockAndWakeupHandlers(&vfbBlockHandler, &vfbWakeupHandler,
                                        null)) {
        pvfb.pXWDHeader = null;
    }
}
}                          /* HAVE_MMAP */

static if(CONFIG_MITSHM){
 void vfbAllocateSharedMemoryFramebuffer(vfbScreenInfoPtr pvfb)
{
    /* create the shared memory segment */

    pvfb.shmid = shmget(IPC_, pvfb.sizeInBytes, IPC_CREAT | octal!"0777");
    if (pvfb.shmid < 0) {
        perror("shmget");
        ErrorF("shmget %d bytes failed, %s", pvfb.sizeInBytes,
               strerror(errno));
        return;
    }

    /* try to attach it */

    pvfb.pXWDHeader = cast(XWDFileHeader*) shmat(pvfb.shmid, 0, 0);
    if (-1 == cast(c_long) pvfb.pXWDHeader) {
        perror("shmat");
        ErrorF("shmat failed, %s", strerror(errno));
        pvfb.pXWDHeader = null;
        return;
    }

    ErrorF("screen %d shmid %d\n", cast(int) (pvfb - vfbScreens), pvfb.shmid);
}
} /* CONFIG_MITSHM */

 char* vfbAllocateFramebufferMemory(vfbScreenInfoPtr pvfb)
{
    if (pvfb.pfbMemory)
        return pvfb.pfbMemory; /* already done */

    pvfb.sizeInBytes = pvfb.paddedBytesWidth * pvfb.height;

    /* Calculate how many entries in colormap.  This is rather bogus, because
     * the visuals haven't even been set up yet, but we need to know because we
     * have to allocate space in the file for the colormap.  The number 10
     * below comes from the MAX_PSEUDO_DEPTH define in cfbcmap.c.
     */

    if (pvfb.depth <= 10) {    /* single index colormaps */
        pvfb.ncolors = 1 << pvfb.depth;
    }
    else {                      /* decomposed colormaps */
        int nplanes_per_color_component = pvfb.depth / 3;

        if (pvfb.depth % 3)
            nplanes_per_color_component++;
        pvfb.ncolors = 1 << nplanes_per_color_component;
    }

    /* add extra bytes for XWDFileHeader, window name, and colormap */

    pvfb.sizeInBytes += XWDheader.sizeof + XWD_WINDOW_NAME_LEN +
        pvfb.ncolors * XWDColor.sizeof;

    pvfb.pXWDHeader = null;
    switch (fbmemtype) {
version (HAVE_MMAP) {
    case MMAPPED_FILE_FB:
        vfbAllocateMmappedFramebuffer(pvfb);
        break;
} else {
    case MMAPPED_FILE_FB:
        break;
}

static if(CONFIG_MITSHM){
    case SHARED_MEMORY_FB:
        vfbAllocateSharedMemoryFramebuffer(pvfb);
        break;
} else { /* CONFIG_MITSHM */
    case SHARED_MEMORY_FB:
        break;
} /* CONFIG_MITSHM */

    case NORMAL_MEMORY_FB:
        pvfb.pXWDHeader = cast(XWDFileHeader*) calloc(1, pvfb.sizeInBytes);
        break;
    default: break;}

    if (pvfb.pXWDHeader) {
        pvfb.pXWDCmap = cast(XWDColor*) (cast(char*) pvfb.pXWDHeader
                                       + XWDheader.sizeof +
                                       XWD_WINDOW_NAME_LEN);
        pvfb.pfbMemory = cast(char*) (pvfb.pXWDCmap + pvfb.ncolors);

        return pvfb.pfbMemory;
    }

    return null;
}

 void vfbWriteXWDFileHeader(ScreenPtr pScreen)
{
    vfbScreenInfoPtr pvfb = &vfbScreens[pScreen.myNum];
    XWDFileHeader* pXWDHeader = pvfb.pXWDHeader;
    c_ulong swaptest = 1;
    int i = void;

    needswap = *cast(char*) &swaptest;

    pXWDHeader.header_size =
        cast(char*) pvfb.pXWDCmap - cast(char*) pvfb.pXWDHeader;
    pXWDHeader.file_version = XWD_FILE_VERSION;

    pXWDHeader.pixmap_format = ZPixmap;
    pXWDHeader.pixmap_depth = pvfb.depth;
    pXWDHeader.pixmap_height = pXWDHeader.window_height = pvfb.height;
    pXWDHeader.xoffset = 0;
    pXWDHeader.byte_order = IMAGE_BYTE_ORDER;
    pXWDHeader.bitmap_bit_order = BITMAP_BIT_ORDER;
version (INTERNAL_VS_EXTERNAL_PADDING) {} else {
    pXWDHeader.pixmap_width = pXWDHeader.window_width = pvfb.width;
    pXWDHeader.bitmap_unit = BITMAP_SCANLINE_UNIT;
    pXWDHeader.bitmap_pad = BITMAP_SCANLINE_PAD;
} version (INTERNAL_VS_EXTERNAL_PADDING) {
    pXWDHeader.pixmap_width = pXWDHeader.window_width = pvfb.paddedWidth;
    pXWDHeader.bitmap_unit = BITMAP_SCANLINE_UNIT_PROTO;
    pXWDHeader.bitmap_pad = BITMAP_SCANLINE_PAD_PROTO;
}
    pXWDHeader.bits_per_pixel = pvfb.bitsPerPixel;
    pXWDHeader.bytes_per_line = pvfb.paddedBytesWidth;
    pXWDHeader.ncolors = pvfb.ncolors;

    /* visual related fields are written when colormap is installed */

    pXWDHeader.window_x = pXWDHeader.window_y = 0;
    pXWDHeader.window_bdrwidth = 0;

    /* write xwd "window" name: Xvfb hostname:server.screen */
    xhostname hn = void;
    f_xhostname(&hn);
    hn.name[XWD_WINDOW_NAME_LEN - 1] = 0;
    snprintf(cast(char*)(pXWDHeader + 1), XWD_WINDOW_NAME_LEN,
         "Xvfb %.40s:%.10s.%d", hn.name, display, pScreen.myNum);

    /* write colormap pixel slot values */

    for (i = 0; i < pvfb.ncolors; i++) {
        pvfb.pXWDCmap[i].pixel = i;
    }

    /* byte swap to most significant byte first */

    if (needswap) {
        SwapLongs(cast(CARD32*) pXWDHeader, XWDheader.sizeof / 4);
        for (i = 0; i < pvfb.ncolors; i++) {
            swapl(&pvfb.pXWDCmap[i].pixel);
        }
    }
}

 Bool vfbCursorOffScreen(ScreenPtr* ppScreen, int* x, int* y)
{
    return FALSE;
}

 void vfbCrossScreen(ScreenPtr pScreen, Bool entering)
{
}

 miPointerScreenFuncRec vfbPointerCursorFuncs = {
    vfbCursorOffScreen,
    vfbCrossScreen,
    miPointerWarpCursor
};

 Bool vfbCloseScreen(ScreenPtr pScreen)
{
    vfbScreenInfoPtr pvfb = &vfbScreens[pScreen.myNum];

    pScreen.CloseScreen = pvfb.closeScreen;

    /*
     * fb overwrites miCloseScreen, so do this here
     */
    dixDestroyPixmap(pScreen.dev, 0);
    pScreen.dev = null;

static if (GLAMOR) {
    if (pvfb.dri_fd >= 0) {
        close(pvfb.dri_fd);
        pvfb.dri_fd = -1;
        free(render_node);
        render_node = null;
    }
}

    return pScreen.CloseScreen(pScreen);
}

static if (GLAMOR) {
 Bool vfbGlamorInit(ScreenPtr pScreen)
{
    vfbScreenInfoPtr pvfb = &vfbScreens[pScreen.myNum];

    if (!use_glamor && !render_node) {
        return FALSE;
    }

    pvfb.dri_fd = render_node ? open(render_node, O_RDWR | O_CLOEXEC) : -1;

    glamor_egl_conf_t glamor_egl_conf = {
                                         screen: pScreen,
                                         fd: pvfb.dri_fd,
                                         llvmpipe_allowed: TRUE,
                                         force_glamor: TRUE,
                                        };

    if (!glamor_egl_init_internal(&glamor_egl_conf, null)) {
        close(pvfb.dri_fd);
        return FALSE;
    }

    const(char)* renderer = cast(const(char)*)glGetString(GL_RENDERER);

    int flags = GLAMOR_USE_EGL_SCREEN;
    if (!renderer ||
        strstr(renderer, "softpipe") ||
        strstr(renderer, "llvmpipe")) {
        flags |= GLAMOR_NO_RENDER_ACCEL;
    }

    if (pvfb.dri_fd < 0 || flags & GLAMOR_NO_RENDER_ACCEL) {
        flags |= GLAMOR_NO_DRI3;
    }

    if (!glamor_init(pScreen, flags)) {
        close(pvfb.dri_fd);
        return FALSE;
    }

    return TRUE;
}
}

 Bool vfbRROutputValidateMode(ScreenPtr pScreen, RROutputPtr output, RRModePtr mode)
{
    mixin(rrScrPriv!("pScreen"));

    if (pScrPriv.minWidth <= mode.mode.width &&
        pScrPriv.maxWidth >= mode.mode.width &&
        pScrPriv.minHeight <= mode.mode.height &&
        pScrPriv.maxHeight >= mode.mode.height)
        return TRUE;
    else
        return FALSE;
}

 Bool vfbRRScreenSetSize(ScreenPtr pScreen, CARD16 width, CARD16 height, CARD32 mmWidth, CARD32 mmHeight)
{
    rrScrPrivPtr pScrPriv = mixin(rrGetScrPriv!("pScreen"));

    // Prevent screen updates while we change things around
    SetRootClip(pScreen, ROOT_CLIP_NONE);

    pScreen.width = width;
    pScreen.height = height;
    pScreen.mmWidth = mmWidth;
    pScreen.mmHeight = mmHeight;

    // Restore the ability to update screen, now with new dimensions
    SetRootClip(pScreen, ROOT_CLIP_FULL);

    RRScreenSizeNotify (pScreen);
    RRTellChanged(pScreen);

    return RROutputSetPhysicalSize(pScrPriv.outputs[pScreen.myNum], mmWidth, mmHeight);
}

 Bool vfbRRCrtcSet(ScreenPtr pScreen, RRCrtcPtr crtc, RRModePtr mode, int x, int y, Rotation rotation, int numOutputs, RROutputPtr* outputs)
{
    vfbCrtcInfoPtr pvci = crtc.dev;

    if (pvci) {
        if (mode) {
            pvci.width = mode.mode.width;
            pvci.height = mode.mode.height;
        }

        pvci.x = x;
        pvci.y = y;
        pvci.numOutputs = numOutputs;
    }
    return RRCrtcNotify(crtc, mode, x, y, rotation, null, numOutputs, outputs);
}

 Bool vfbRRGetInfo(ScreenPtr pScreen, Rotation* rotations)
{
    /* Don't support rotations */
    *rotations = RR_Rotate_0;

    return TRUE;
}

 Bool vfbRandRInit(ScreenPtr pScreen)
{
    rrScrPrivPtr pScrPriv = void;

static if (RANDR_12_INTERFACE) {
    RRModePtr mode = void;
    RRCrtcPtr crtc = void;
    RROutputPtr output = void;
    xRRModeInfo modeInfo = void;
    char[64] name = void;
    int i = void;
    vfbScreenInfoPtr pvfb = &vfbScreens[pScreen.myNum];
}
    int mmWidth = void, mmHeight = void;

    if (!RRScreenInit(pScreen))
        return FALSE;
    pScrPriv = mixin(rrGetScrPriv!("pScreen"));
    pScrPriv.rrGetInfo = vfbRRGetInfo;
static if (RANDR_12_INTERFACE) {
    pScrPriv.rrCrtcSet = vfbRRCrtcSet;
    pScrPriv.rrScreenSetSize = vfbRRScreenSetSize;
    pScrPriv.rrOutputSetProperty = null;
static if (RANDR_13_INTERFACE) {
    pScrPriv.rrOutputGetProperty = null;
}
    pScrPriv.rrOutputValidateMode = vfbRROutputValidateMode;
    pScrPriv.rrModeDestroy = null;

    RRScreenSetSizeRange(pScreen, 1, 1, pScreen.width, pScreen.height);

    for (i = 0; i < pvfb.numCrtcs; i++) {
        vfbCrtcInfoPtr pvci = &pvfb.crtcs[i];

        mmWidth = pvci.width * 25.4 / monitorResolution;
        mmHeight = pvci.height * 25.4 / monitorResolution;

        crtc = RRCrtcCreate(pScreen, pvci);
        if (!crtc)
            return FALSE;

        /* Set gamma to avoid xrandr complaints */
        RRCrtcGammaSetSize(crtc, 256);

        /* Setup an Output for each CRTC: 'screen' for the first, then 'screen_N' */
        snprintf(name.ptr, name.sizeof, i == 0 ? "screen" : "screen_%d", i);
        output = RROutputCreate(pScreen, name.ptr, strlen(name.ptr), null);
        if (!output)
            return FALSE;
        if (!RROutputSetClones(output, null, 0))
            return FALSE;
        if (!RROutputSetCrtcs(output, &crtc, 1))
            return FALSE;
        if (!RROutputSetConnection(output, RR_Connected))
            return FALSE;
        if (!RROutputSetPhysicalSize(output, mmWidth, mmHeight))
            return FALSE;

        /* Setup a Mode and notify only for CRTCs with Outputs */
        if (pvci.numOutputs > 0) {
            snprintf(name.ptr, name.sizeof, "%dx%d", pvci.width, pvci.height);
            memset(&modeInfo, '\0', modeInfo.sizeof);
            modeInfo.width = pvci.width;
            modeInfo.height = pvci.height;
            modeInfo.nameLength = cast(ushort)strlen(name.ptr);

            mode = RRModeGet(&modeInfo, name.ptr);
            if (!mode)
                return FALSE;
            if (!RROutputSetModes(output, &mode, 1, 0))
                return FALSE;
            if (!RRCrtcNotify(crtc, mode, pvci.x, pvci.y, RR_Rotate_0, null,
                              1, &output))
                return FALSE;
        }
    }
}
    return TRUE;
}

 Bool vfbScreenInit(ScreenPtr pScreen, int argc, char** argv)
{
    vfbScreenInfoPtr pvfb = &vfbScreens[pScreen.myNum];
    int dpix = monitorResolution, dpiy = monitorResolution;
    int ret = void;
    char* pbits = void;

    if (dpix == 0)
        dpix = 100;

    if (dpiy == 0)
        dpiy = 100;

    pvfb.paddedBytesWidth = PixmapBytePad(pvfb.width, pvfb.depth);
    pvfb.bitsPerPixel = vfbBitsPerPixel(pvfb.depth);
    if (pvfb.bitsPerPixel >= 8)
        pvfb.paddedWidth = pvfb.paddedBytesWidth / (pvfb.bitsPerPixel / 8);
    else
        pvfb.paddedWidth = pvfb.paddedBytesWidth * 8;
    pbits = vfbAllocateFramebufferMemory(pvfb);
    if (!pbits)
        return FALSE;

    switch (pvfb.depth) {
    case 8:
        miSetVisualTypesAndMasks(8,
                                 ((1 << StaticGray) |
                                  (1 << GrayScale) |
                                  (1 << StaticColor) |
                                  (1 << PseudoColor) |
                                  (1 << TrueColor) |
                                  (1 << DirectColor)), 8, PseudoColor, 0, 0, 0);
        break;
    case 15:
        miSetVisualTypesAndMasks(15,
                                 ((1 << TrueColor) |
                                  (1 << DirectColor)),
                                 8, TrueColor, 0x7c00, 0x03e0, 0x001f);
        break;
    case 16:
        miSetVisualTypesAndMasks(16,
                                 ((1 << TrueColor) |
                                  (1 << DirectColor)),
                                 8, TrueColor, 0xf800, 0x07e0, 0x001f);
        break;
    case 24:
        miSetVisualTypesAndMasks(24,
                                 ((1 << TrueColor) |
                                  (1 << DirectColor)),
                                 8, TrueColor, 0xff0000, 0x00ff00, 0x0000ff);
        break;
    case 30:
        miSetVisualTypesAndMasks(30,
                                 ((1 << TrueColor) |
                                  (1 << DirectColor)),
                                 10, TrueColor, 0x3ff00000, 0x000ffc00,
                                 0x000003ff);
        break;
    default:
        return FALSE;
    }

    miSetPixmapDepths();

    ret = fbScreenInit(pScreen, pbits, pvfb.width, pvfb.height,
                       dpix, dpiy, pvfb.paddedWidth, pvfb.bitsPerPixel);

    if (!ret)
        return FALSE;

    if (Render) {
        fbPictureInit(pScreen, 0, 0);
static if (GLAMOR) {
        vfbGlamorInit(pScreen);
}
    }

    if (!vfbRandRInit(pScreen))
       return FALSE;

    pScreen.InstallColormap = vfbInstallColormap;
    pScreen.StoreColors = vfbStoreColors;

    miDCInitialize(pScreen, &vfbPointerCursorFuncs);

    vfbWriteXWDFileHeader(pScreen);

    pScreen.blackPixel = pvfb.blackPixel;
    pScreen.whitePixel = pvfb.whitePixel;

    ret = fbCreateDefColormap(pScreen);

    miSetZeroLineBias(pScreen, pvfb.lineBias);

    pvfb.closeScreen = pScreen.CloseScreen;
    pScreen.CloseScreen = vfbCloseScreen;

    return ret;

}                               /* end vfbScreenInit */

void InitOutput(int argc, char** argv)
{
    int i = void;
    int NumFormats = 0;

    if (!monitorResolution)
               monitorResolution = 96;

    /* initialize pixmap formats */

    /* must have a pixmap depth to match every screen depth */
    for (i = 0; i < vfbNumScreens; i++) {
        vfbPixmapDepths[vfbScreens[i].depth] = TRUE;
    }

    /* RENDER needs a good set of pixmaps. */
    if (Render) {
        vfbPixmapDepths[1] = TRUE;
        vfbPixmapDepths[4] = TRUE;
        vfbPixmapDepths[8] = TRUE;
version (none) {
        vfbPixmapDepths[12] = TRUE;
}
/*	vfbPixmapDepths[15] = TRUE; */
        vfbPixmapDepths[16] = TRUE;
        vfbPixmapDepths[24] = TRUE;
version (none) {
        vfbPixmapDepths[30] = TRUE;
}
        vfbPixmapDepths[32] = TRUE;
    }

    xeniaGlxCreateVendor();

    for (i = 1; i <= 32; i++) {
        if (vfbPixmapDepths[i]) {
            if (NumFormats >= MAXFORMATS)
                FatalError("MAXFORMATS is too small for this server\n");
            screenInfo.formats[NumFormats].depth = i;
            screenInfo.formats[NumFormats].bitsPerPixel = vfbBitsPerPixel(i);
            screenInfo.formats[NumFormats].scanlinePad = BITMAP_SCANLINE_PAD;
            NumFormats++;
        }
    }

    screenInfo.imageByteOrder = IMAGE_BYTE_ORDER;
    screenInfo.bitmapScanlineUnit = BITMAP_SCANLINE_UNIT;
    screenInfo.bitmapScanlinePad = BITMAP_SCANLINE_PAD;
    screenInfo.bitmapBitOrder = BITMAP_BIT_ORDER;
    screenInfo.numPixmapFormats = NumFormats;

    /* initialize screens */

    if (vfbNumScreens < 1) {
        vfbScreens = &defaultScreenInfo;
        vfbNumScreens = 1;
    }
    for (i = 0; i < vfbNumScreens; i++) {
        if (-1 == AddScreen(&vfbScreenInit, argc, argv)) {
            FatalError("Couldn't add screen %d", i);
        }
    }

}                               /* end InitOutput */
}