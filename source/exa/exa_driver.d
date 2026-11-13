module exa_driver;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;

/*
 * Copyright © 2009 Maarten Maathuis
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
 * SOFTWARE.
 *
 */

import build.dix_config;

import core.stdc.string;

import exa.exa_priv;
import exa.exa_offscreen;
import exa.exa;
import fb.fb;
import dix.picture;

/* This file holds the driver allocated pixmaps specific implementation. */

/**
 * The ExaDriver structure is allocated through exaDriverAlloc(), and then
 * fllled in by drivers.
 */
struct _ExaDriver {
    /**
     * exa_major and exa_minor should be set by the driver to the version of
     * EXA which the driver was compiled for (or configures itself at runtime
     * to support).  This allows EXA to extend the structure for new features
     * without breaking ABI for drivers compiled against older versions.
     */
    int exa_major, exa_minor;

    /**
     * memoryBase is the address of the beginning of framebuffer memory.
     * The visible screen should be within memoryBase to memoryBase +
     * memorySize.
     */
    CARD8* memoryBase;

    /**
     * offScreenBase is the offset from memoryBase of the beginning of the area
     * to be managed by EXA's linear offscreen memory manager.
     *
     * In XFree86 DDX drivers, this is probably:
     *   (pScrn->displayWidth * cpp * pScrn->virtualY)
     */
    c_ulong offScreenBase;

    /**
     * memorySize is the length (in bytes) of framebuffer memory beginning
     * from memoryBase.
     *
     * The offscreen memory manager will manage the area beginning at
     * (memoryBase + offScreenBase), with a length of (memorySize -
     * offScreenBase)
     *
     * In XFree86 DDX drivers, this is probably (pScrn->videoRam * 1024)
     */
    c_ulong memorySize;

    /**
     * pixmapOffsetAlign is the byte alignment necessary for pixmap offsets
     * within framebuffer.
     *
     * Hardware typically has a required alignment of offsets, which may or may
     * not be a power of two.  EXA will ensure that pixmaps managed by the
     * offscreen memory manager meet this alignment requirement.
     */
    int pixmapOffsetAlign;

    /**
     * pixmapPitchAlign is the byte alignment necessary for pixmap pitches
     * within the framebuffer.
     *
     * Hardware typically has a required alignment of pitches for acceleration.
     * For 3D hardware, Composite acceleration often requires that source and
     * mask pixmaps (textures) have a power-of-two pitch, which can be demanded
     * using EXA_OFFSCREEN_ALIGN_POT.  These pitch requirements only apply to
     * pixmaps managed by the offscreen memory manager.  Thus, it is up to the
     * driver to ensure that the visible screen has an appropriate pitch for
     * acceleration.
     */
    int pixmapPitchAlign;

    /**
     * The flags field is bitfield of boolean values controlling EXA's behavior.
     *
     * The flags include EXA_OFFSCREEN_PIXMAPS, EXA_OFFSCREEN_ALIGN_POT, and
     * EXA_TWO_BITBLT_DIRECTIONS.
     */
    int flags;

    /** @{ */
    /**
     * maxX controls the X coordinate limitation for rendering from the card.
     * The driver should never receive a request for rendering beyond maxX
     * in the X direction from the origin of a pixmap.
     */
    int maxX;

    /**
     * maxY controls the Y coordinate limitation for rendering from the card.
     * The driver should never receive a request for rendering beyond maxY
     * in the Y direction from the origin of a pixmap.
     */
    int maxY;
    /** @} */

    /* private */
    ExaOffscreenArea* offScreenAreas;
    Bool needsSync;
    int lastMarker;

    /** @name Solid
     * @{
     */
    /**
     * PrepareSolid() sets up the driver for doing a solid fill.
     * @param pPixmap Destination pixmap
     * @param alu raster operation
     * @param planemask write mask for the fill
     * @param fg "foreground" color for the fill
     *
     * This call should set up the driver for doing a series of solid fills
     * through the Solid() call.  The alu raster op is one of the GX*
     * graphics functions listed in X.h, and typically maps to a similar
     * single-byte "ROP" setting in all hardware.  The planemask controls
     * which bits of the destination should be affected, and will only represent
     * the bits up to the depth of pPixmap.  The fg is the pixel value of the
     * foreground color referred to in ROP descriptions.
     *
     * Note that many drivers will need to store some of the data in the driver
     * private record, for sending to the hardware with each drawing command.
     *
     * The PrepareSolid() call is required of all drivers, but it may fail for any
     * reason.  Failure results in a fallback to software rendering.
     */
    Bool function(PixmapPtr pPixmap, int alu, Pixel planemask, Pixel fg) @nogc nothrow PrepareSolid;

    /**
     * Solid() performs a solid fill set up in the last PrepareSolid() call.
     *
     * @param pPixmap destination pixmap
     * @param x1 left coordinate
     * @param y1 top coordinate
     * @param x2 right coordinate
     * @param y2 bottom coordinate
     *
     * Performs the fill set up by the last PrepareSolid() call, covering the
     * area from (x1,y1) to (x2,y2) in pPixmap.  Note that the coordinates are
     * in the coordinate space of the destination pixmap, so the driver will
     * need to set up the hardware's offset and pitch for the destination
     * coordinates according to the pixmap's offset and pitch within
     * framebuffer.  This likely means using exaGetPixmapOffset() and
     * exaGetPixmapPitch().
     *
     * This call is required if PrepareSolid() ever succeeds.
     */
    void function(PixmapPtr pPixmap, int x1, int y1, int x2, int y2) @nogc nothrow Solid;

    /**
     * DoneSolid() finishes a set of solid fills.
     *
     * @param pPixmap destination pixmap.
     *
     * The DoneSolid() call is called at the end of a series of consecutive
     * Solid() calls following a successful PrepareSolid().  This allows drivers
     * to finish up emitting drawing commands that were buffered, or clean up
     * state from PrepareSolid().
     *
     * This call is required if PrepareSolid() ever succeeds.
     */
    void function(PixmapPtr pPixmap) @nogc nothrow DoneSolid;
    /** @} */

    /** @name Copy
     * @{
     */
    /**
     * PrepareCopy() sets up the driver for doing a copy within video
     * memory.
     *
     * @param pSrcPixmap source pixmap
     * @param pDstPixmap destination pixmap
     * @param dx X copy direction
     * @param dy Y copy direction
     * @param alu raster operation
     * @param planemask write mask for the fill
     *
     * This call should set up the driver for doing a series of copies from the
     * the pSrcPixmap to the pDstPixmap.  The dx flag will be positive if the
     * hardware should do the copy from the left to the right, and dy will be
     * positive if the copy should be done from the top to the bottom.  This
     * is to deal with self-overlapping copies when pSrcPixmap == pDstPixmap.
     * If your hardware can only support blits that are (left to right, top to
     * bottom) or (right to left, bottom to top), then you should set
     * #EXA_TWO_BITBLT_DIRECTIONS, and EXA will break down Copy operations to
     * ones that meet those requirements.  The alu raster op is one of the GX*
     * graphics functions listed in X.h, and typically maps to a similar
     * single-byte "ROP" setting in all hardware.  The planemask controls which
     * bits of the destination should be affected, and will only represent the
     * bits up to the depth of pPixmap.
     *
     * Note that many drivers will need to store some of the data in the driver
     * private record, for sending to the hardware with each drawing command.
     *
     * The PrepareCopy() call is required of all drivers, but it may fail for any
     * reason.  Failure results in a fallback to software rendering.
     */
    Bool function(PixmapPtr pSrcPixmap, PixmapPtr pDstPixmap, int dx, int dy, int alu, Pixel planemask) @nogc nothrow PrepareCopy;

    /**
     * Copy() performs a copy set up in the last PrepareCopy call.
     *
     * @param pDstPixmap destination pixmap
     * @param srcX source X coordinate
     * @param srcY source Y coordinate
     * @param dstX destination X coordinate
     * @param dstY destination Y coordinate
     * @param width width of the rectangle to be copied
     * @param height height of the rectangle to be copied.
     *
     * Performs the copy set up by the last PrepareCopy() call, copying the
     * rectangle from (srcX, srcY) to (srcX + width, srcY + width) in the source
     * pixmap to the same-sized rectangle at (dstX, dstY) in the destination
     * pixmap.  Those rectangles may overlap in memory, if
     * pSrcPixmap == pDstPixmap.  Note that this call does not receive the
     * pSrcPixmap as an argument -- if it's needed in this function, it should
     * be stored in the driver private during PrepareCopy().  As with Solid(),
     * the coordinates are in the coordinate space of each pixmap, so the driver
     * will need to set up source and destination pitches and offsets from those
     * pixmaps, probably using exaGetPixmapOffset() and exaGetPixmapPitch().
     *
     * This call is required if PrepareCopy ever succeeds.
     */
    void function(PixmapPtr pDstPixmap, int srcX, int srcY, int dstX, int dstY, int width, int height) @nogc nothrow Copy;

    /**
     * DoneCopy() finishes a set of copies.
     *
     * @param pPixmap destination pixmap.
     *
     * The DoneCopy() call is called at the end of a series of consecutive
     * Copy() calls following a successful PrepareCopy().  This allows drivers
     * to finish up emitting drawing commands that were buffered, or clean up
     * state from PrepareCopy().
     *
     * This call is required if PrepareCopy() ever succeeds.
     */
    void function(PixmapPtr pDstPixmap) @nogc nothrow DoneCopy;
    /** @} */

    /** @name Composite
     * @{
     */
    /**
     * CheckComposite() checks to see if a composite operation could be
     * accelerated.
     *
     * @param op Render operation
     * @param pSrcPicture source Picture
     * @param pMaskPicture mask picture
     * @param pDstPicture destination Picture
     *
     * The CheckComposite() call checks if the driver could handle acceleration
     * of op with the given source, mask, and destination pictures.  This allows
     * drivers to check source and destination formats, supported operations,
     * transformations, and component alpha state, and send operations it can't
     * support to software rendering early on.  This avoids costly pixmap
     * migration to the wrong places when the driver can't accelerate
     * operations.  Note that because migration hasn't happened, the driver
     * can't know during CheckComposite() what the offsets and pitches of the
     * pixmaps are going to be.
     *
     * See PrepareComposite() for more details on likely issues that drivers
     * will have in accelerating Composite operations.
     *
     * The CheckComposite() call is recommended if PrepareComposite() is
     * implemented, but is not required.
     */
    Bool function(int op, PicturePtr pSrcPicture, PicturePtr pMaskPicture, PicturePtr pDstPicture) @nogc nothrow CheckComposite;

    /**
     * PrepareComposite() sets up the driver for doing a Composite operation
     * described in the Render extension protocol spec.
     *
     * @param op Render operation
     * @param pSrcPicture source Picture
     * @param pMaskPicture mask picture
     * @param pDstPicture destination Picture
     * @param pSrc source pixmap
     * @param pMask mask pixmap
     * @param pDst destination pixmap
     *
     * This call should set up the driver for doing a series of Composite
     * operations, as described in the Render protocol spec, with the given
     * pSrcPicture, pMaskPicture, and pDstPicture.  The pSrc, pMask, and
     * pDst are the pixmaps containing the pixel data, and should be used for
     * setting the offset and pitch used for the coordinate spaces for each of
     * the Pictures.
     *
     * Notes on interpreting Picture structures:
     * - The Picture structures will always have a valid pDrawable.
     * - The Picture structures will never have alphaMap set.
     * - The mask Picture (and therefore pMask) may be NULL, in which case the
     *   operation is simply src OP dst instead of src IN mask OP dst, and
     *   mask coordinates should be ignored.
     * - pMarkPicture may have componentAlpha set, which greatly changes
     *   the behavior of the Composite operation.  componentAlpha has no effect
     *   when set on pSrcPicture or pDstPicture.
     * - The source and mask Pictures may have a transformation set
     *   (Picture->transform != NULL), which means that the source coordinates
     *   should be transformed by that transformation, resulting in scaling,
     *   rotation, etc.  The PictureTransformPoint() call can transform
     *   coordinates for you.  Transforms have no effect on Pictures when used
     *   as a destination.
     * - The source and mask pictures may have a filter set.  PictFilterNearest
     *   and PictFilterBilinear are defined in the Render protocol, but others
     *   may be encountered, and must be handled correctly (usually by
     *   PrepareComposite failing, and falling back to software).  Filters have
     *   no effect on Pictures when used as a destination.
     * - The source and mask Pictures may have repeating set, which must be
     *   respected.  Many chipsets will be unable to support repeating on
     *   pixmaps that have a width or height that is not a power of two.
     *
     * If your hardware can't support source pictures (textures) with
     * non-power-of-two pitches, you should set #EXA_OFFSCREEN_ALIGN_POT.
     *
     * Note that many drivers will need to store some of the data in the driver
     * private record, for sending to the hardware with each drawing command.
     *
     * The PrepareComposite() call is not required.  However, it is highly
     * recommended for performance of antialiased font rendering and performance
     * of cairo applications.  Failure results in a fallback to software
     * rendering.
     */
    Bool function(int op, PicturePtr pSrcPicture, PicturePtr pMaskPicture, PicturePtr pDstPicture, PixmapPtr pSrc, PixmapPtr pMask, PixmapPtr pDst) @nogc nothrow PrepareComposite;

    /**
     * Composite() performs a Composite operation set up in the last
     * PrepareComposite() call.
     *
     * @param pDstPixmap destination pixmap
     * @param srcX source X coordinate
     * @param srcY source Y coordinate
     * @param maskX source X coordinate
     * @param maskY source Y coordinate
     * @param dstX destination X coordinate
     * @param dstY destination Y coordinate
     * @param width destination rectangle width
     * @param height destination rectangle height
     *
     * Performs the Composite operation set up by the last PrepareComposite()
     * call, to the rectangle from (dstX, dstY) to (dstX + width, dstY + height)
     * in the destination Pixmap.  Note that if a transformation was set on
     * the source or mask Pictures, the source rectangles may not be the same
     * size as the destination rectangles and filtering.  Getting the coordinate
     * transformation right at the subpixel level can be tricky, and rendercheck
     * can test this for you.
     *
     * This call is required if PrepareComposite() ever succeeds.
     */
    void function(PixmapPtr pDst, int srcX, int srcY, int maskX, int maskY, int dstX, int dstY, int width, int height) @nogc nothrow Composite;

    /**
     * DoneComposite() finishes a set of Composite operations.
     *
     * @param pPixmap destination pixmap.
     *
     * The DoneComposite() call is called at the end of a series of consecutive
     * Composite() calls following a successful PrepareComposite().  This allows
     * drivers to finish up emitting drawing commands that were buffered, or
     * clean up state from PrepareComposite().
     *
     * This call is required if PrepareComposite() ever succeeds.
     */
    void function(PixmapPtr pDst) @nogc nothrow DoneComposite;
    /** @} */

    /**
     * UploadToScreen() loads a rectangle of data from src into pDst.
     *
     * @param pDst destination pixmap
     * @param x destination X coordinate.
     * @param y destination Y coordinate
     * @param width width of the rectangle to be copied
     * @param height height of the rectangle to be copied
     * @param src pointer to the beginning of the source data
     * @param src_pitch pitch (in bytes) of the lines of source data.
     *
     * UploadToScreen() copies data in system memory beginning at src (with
     * pitch src_pitch) into the destination pixmap from (x, y) to
     * (x + width, y + height).  This is typically done with hostdata uploads,
     * where the CPU sets up a blit command on the hardware with instructions
     * that the blit data will be fed through some sort of aperture on the card.
     *
     * If UploadToScreen() is performed asynchronously, it is up to the driver
     * to call exaMarkSync().  This is in contrast to most other acceleration
     * calls in EXA.
     *
     * UploadToScreen() can aid in pixmap migration, but is most important for
     * the performance of exaGlyphs() (antialiased font drawing) by allowing
     * pipelining of data uploads, avoiding a sync of the card after each glyph.
     *
     * @return True if the driver successfully uploaded the data.  False
     * indicates that EXA should fall back to doing the upload in software.
     *
     * UploadToScreen() is not required, but is recommended if Composite
     * acceleration is supported.
     */
    Bool function(PixmapPtr pDst, int x, int y, int w, int h, char* src, int src_pitch) @nogc nothrow UploadToScreen;

    /**
     * UploadToScratch() is no longer used and will be removed next time the EXA
     * major version needs to be bumped.
     */
    Bool function(PixmapPtr pSrc, PixmapPtr pDst) @nogc nothrow UploadToScratch;

    /**
     * DownloadFromScreen() loads a rectangle of data from pSrc into dst
     *
     * @param pSrc source pixmap
     * @param x source X coordinate.
     * @param y source Y coordinate
     * @param width width of the rectangle to be copied
     * @param height height of the rectangle to be copied
     * @param dst pointer to the beginning of the destination data
     * @param dst_pitch pitch (in bytes) of the lines of destination data.
     *
     * DownloadFromScreen() copies data from offscreen memory in pSrc from
     * (x, y) to (x + width, y + height), to system memory starting at
     * dst (with pitch dst_pitch).  This would usually be done
     * using scatter-gather DMA, supported by a DRM call, or by blitting to AGP
     * and then synchronously reading from AGP.  Because the implementation
     * might be synchronous, EXA leaves it up to the driver to call
     * exaMarkSync() if DownloadFromScreen() was asynchronous.  This is in
     * contrast to most other acceleration calls in EXA.
     *
     * DownloadFromScreen() can aid in the largest bottleneck in pixmap
     * migration, which is the read from framebuffer when evicting pixmaps from
     * framebuffer memory.  Thus, it is highly recommended, even though
     * implementations are typically complicated.
     *
     * @return True if the driver successfully downloaded the data.  False
     * indicates that EXA should fall back to doing the download in software.
     *
     * DownloadFromScreen() is not required, but is highly recommended.
     */
    Bool function(PixmapPtr pSrc, int x, int y, int w, int h, char* dst, int dst_pitch) @nogc nothrow DownloadFromScreen;

    /**
     * MarkSync() requests that the driver mark a synchronization point,
     * returning an driver-defined integer marker which could be requested for
     * synchronization to later in WaitMarker().  This might be used in the
     * future to avoid waiting for full hardware stalls before accessing pixmap
     * data with the CPU, but is not important in the current incarnation of
     * EXA.
     *
     * Note that drivers should call exaMarkSync() when they have done some
     * acceleration, rather than their own MarkSync() handler, as otherwise EXA
     * will be unaware of the driver's acceleration and not sync to it during
     * fallbacks.
     *
     * MarkSync() is optional.
     */
    int function(ScreenPtr pScreen) @nogc nothrow MarkSync;

    /**
     * WaitMarker() waits for all rendering before the given marker to have
     * completed.  If the driver does not implement MarkSync(), marker is
     * meaningless, and all rendering by the hardware should be completed before
     * WaitMarker() returns.
     *
     * Note that drivers should call exaWaitSync() to wait for all acceleration
     * to finish, as otherwise EXA will be unaware of the driver having
     * synchronized, resulting in excessive WaitMarker() calls.
     *
     * WaitMarker() is required of all drivers.
     */
    void function(ScreenPtr pScreen, int marker) @nogc nothrow WaitMarker;

    /** @{ */
    /**
     * PrepareAccess() is called before CPU access to an offscreen pixmap.
     *
     * @param pPix the pixmap being accessed
     * @param index the index of the pixmap being accessed.
     *
     * PrepareAccess() will be called before CPU access to an offscreen pixmap.
     * This can be used to set up hardware surfaces for byteswapping or
     * untiling, or to adjust the pixmap's devPrivate.ptr for the purpose of
     * making CPU access use a different aperture.
     *
     * The index is one of #EXA_PREPARE_DEST, #EXA_PREPARE_SRC,
     * #EXA_PREPARE_MASK, #EXA_PREPARE_AUX_DEST, #EXA_PREPARE_AUX_SRC, or
     * #EXA_PREPARE_AUX_MASK. Since only up to #EXA_NUM_PREPARE_INDICES pixmaps
     * will have PrepareAccess() called on them per operation, drivers can have
     * a small, statically-allocated space to maintain state for PrepareAccess()
     * and FinishAccess() in.  Note that PrepareAccess() is only called once per
     * pixmap and operation, regardless of whether the pixmap is used as a
     * destination and/or source, and the index may not reflect the usage.
     *
     * PrepareAccess() may fail.  An example might be the case of hardware that
     * can set up 1 or 2 surfaces for CPU access, but not 3.  If PrepareAccess()
     * fails, EXA will migrate the pixmap to system memory.
     * DownloadFromScreen() must be implemented and must not fail if a driver
     * wishes to fail in PrepareAccess().  PrepareAccess() must not fail when
     * pPix is the visible screen, because the visible screen can not be
     * migrated.
     *
     * @return True if PrepareAccess() successfully prepared the pixmap for CPU
     * drawing.
     * @return False if PrepareAccess() is unsuccessful and EXA should use
     * DownloadFromScreen() to mitigate the pixmap out.
     */
    Bool function(PixmapPtr pPix, int index) @nogc nothrow PrepareAccess;

    /**
     * FinishAccess() is called after CPU access to an offscreen pixmap.
     *
     * @param pPix the pixmap being accessed
     * @param index the index of the pixmap being accessed.
     *
     * FinishAccess() will be called after finishing CPU access of an offscreen
     * pixmap set up by PrepareAccess().  Note that the FinishAccess() will not be
     * called if PrepareAccess() failed and the pixmap was migrated out.
     */
    void function(PixmapPtr pPix, int index) @nogc nothrow FinishAccess;

    /**
     * PixmapIsOffscreen() is an optional driver replacement to
     * exaPixmapHasGpuCopy(). Set to NULL if you want the standard behaviour
     * of exaPixmapHasGpuCopy().
     *
     * @param pPix the pixmap
     * @return True if the given drawable is in framebuffer memory.
     *
     * exaPixmapHasGpuCopy() is used to determine if a pixmap is in offscreen
     * memory, meaning that acceleration could probably be done to it, and that it
     * will need to be wrapped by PrepareAccess()/FinishAccess() when accessing it
     * with the CPU.
     *
     *
     */
    Bool function(PixmapPtr pPix) @nogc nothrow PixmapIsOffscreen;

        /** @name PrepareAccess() and FinishAccess() indices
	 * @{
	 */
        /**

        /** @} */

    /**
     * maxPitchPixels controls the pitch limitation for rendering from
     * the card.
     * The driver should never receive a request for rendering a pixmap
     * that has a pitch (in pixels) beyond maxPitchPixels.
     *
     * Setting this field is optional -- if your hardware doesn't have
     * a pitch limitation in pixels, don't set this. If neither this value
     * nor maxPitchBytes is set, then maxPitchPixels is set to maxX.
     * If set, it must not be smaller than maxX.
     *
     * @sa maxPitchBytes
     */
    int maxPitchPixels;

    /**
     * maxPitchBytes controls the pitch limitation for rendering from
     * the card.
     * The driver should never receive a request for rendering a pixmap
     * that has a pitch (in bytes) beyond maxPitchBytes.
     *
     * Setting this field is optional -- if your hardware doesn't have
     * a pitch limitation in bytes, don't set this.
     * If set, it must not be smaller than maxX * 4.
     * There's no default value for maxPitchBytes.
     *
     * @sa maxPitchPixels
     */
    int maxPitchBytes;

    /* Hooks to allow driver to its own pixmap memory management */
    void* function(ScreenPtr pScreen, int size, int align_) @nogc nothrow CreatePixmap;
    void function(ScreenPtr pScreen, void* driverPriv) @nogc nothrow DestroyPixmap;
    /**
     * Returning a pixmap with non-NULL devPrivate.ptr implies a pixmap which is
     * not offscreen, which will never be accelerated and Prepare/FinishAccess won't
     * be called.
     */
    Bool function(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData) @nogc nothrow ModifyPixmapHeader;

    /* hooks for drivers with tiling support:
     * driver MUST fill out new_fb_pitch with valid pitch of pixmap
     */
    void* function(ScreenPtr pScreen, int width, int height, int depth, int usage_hint, int bitsPerPixel, int* new_fb_pitch) @nogc nothrow CreatePixmap2;
    /** @} */
    Bool function(PixmapPtr pPixmap, ScreenPtr secondary, void** handle_p) @nogc nothrow SharePixmapBacking;

    Bool function(PixmapPtr pPixmap, void* handle) @nogc nothrow SetSharedPixmapBacking;

}alias ExaDriverRec = _ExaDriver;
alias ExaDriverPtr = _ExaDriver*;

//pragma(mangle, mixin(cFixer!(__MODULE__, __LINE__)))
pragma(inline, true) private void* ExaGetPixmapAddress(PixmapPtr p)
{
    mixin(ExaPixmapPriv!("p"));

    return pExaPixmap.sys_ptr;
}

/**
 * exaCreatePixmap() creates a new pixmap.
 *
 * Pixmaps are always marked as pinned, because exa has no control over them.
 */
PixmapPtr exaCreatePixmap_driver(ScreenPtr pScreen, int w, int h, int depth, uint usage_hint)
{
    PixmapPtr pPixmap = void;
    ExaPixmapPrivPtr pExaPixmap = void;
    int bpp = void;
    size_t paddedWidth = void, datasize = void;

    mixin(ExaScreenPriv!("pScreen"));

    if (w > 32767 || h > 32767)
        return NullPixmap;

    mixin(swap!("pExaScr", "pScreen", "CreatePixmap"));
    pPixmap = pScreen.CreatePixmap(pScreen, 0, 0, depth, usage_hint);
    mixin(swap!("pExaScr", "pScreen", "CreatePixmap"));

    if (!pPixmap)
        return null;

    pExaPixmap = mixin(ExaGetPixmapPriv!("pPixmap"));
    pExaPixmap.driverPriv = null;

    bpp = pPixmap.drawable.bitsPerPixel;

    /* Set this before driver hooks, to allow for driver pixmaps without gpu
     * memory to back it. These pixmaps have a valid pointer at all times.
     */
    pPixmap.devPrivate.ptr = null;

    if (pExaScr.info.CreatePixmap2) {
        int new_pitch = 0;

        pExaPixmap.driverPriv =
            pExaScr.info.CreatePixmap2(pScreen, w, h, depth, usage_hint, bpp,
                                         &new_pitch);
        paddedWidth = pExaPixmap.fb_pitch = new_pitch;
    }
    else {
        paddedWidth = ((w * bpp + FB_MASK) >> FB_SHIFT) * FbBits.sizeof;
        if (paddedWidth / 4 > 32767)
            return NullPixmap;

        exaSetFbPitch(pExaScr, pExaPixmap, w, h, bpp);

        if (paddedWidth < pExaPixmap.fb_pitch)
            paddedWidth = pExaPixmap.fb_pitch;
        datasize = h * paddedWidth;
        pExaPixmap.driverPriv =
            pExaScr.info.CreatePixmap(pScreen, cast(int)datasize, 0);
    }

    if (!pExaPixmap.driverPriv) {
        // don't need to protect from calling our own (wrapped) DestroyPixmap
        // handler, because it can deal with half-initialized state
        dixDestroyPixmap(pPixmap, 0);
        return null;
    }

    /* Allow ModifyPixmapHeader to set sys_ptr appropriately. */
    pExaPixmap.score = EXA_PIXMAP_SCORE_PINNED;
    pExaPixmap.fb_ptr = null;
    pExaPixmap.pDamage = null;
    pExaPixmap.sys_ptr = null;

    (*pScreen.ModifyPixmapHeader) (pPixmap, w, h, 0, 0, cast(int)paddedWidth, null);

    pExaPixmap.area = null;

    exaSetAccelBlock(pExaScr, pExaPixmap, w, h, bpp);

    pExaPixmap.use_gpu_copy = exaPixmapHasGpuCopy(pPixmap);

    /* During a fallback we must prepare access. */
    if (pExaScr.fallback_counter)
        exaPrepareAccess(&pPixmap.drawable, EXA_PREPARE_AUX_DEST);

    return pPixmap;
}

Bool exaModifyPixmapHeader_driver(PixmapPtr pPixmap, int width, int height, int depth, int bitsPerPixel, int devKind, void* pPixData)
{
    ScreenPtr pScreen = void;
    ExaScreenPrivPtr pExaScr = void;
    ExaPixmapPrivPtr pExaPixmap = void;
    Bool ret = void;

    if (!pPixmap)
        return False;

    pScreen = pPixmap.drawable.pScreen;
    pExaScr = mixin(ExaGetScreenPriv!("pScreen"));
    pExaPixmap = mixin(ExaGetPixmapPriv!("pPixmap"));

    if (pExaPixmap) {
        if (pPixData)
            pExaPixmap.sys_ptr = cast(ubyte*)pPixData;

        if (devKind > 0)
            pExaPixmap.sys_pitch = devKind;

        if (width > 0 && height > 0 && bitsPerPixel > 0) {
            exaSetFbPitch(pExaScr, pExaPixmap, width, height, bitsPerPixel);

            exaSetAccelBlock(pExaScr, pExaPixmap, width, height, bitsPerPixel);
        }
    }

    if (pExaScr.info.ModifyPixmapHeader) {
        ret = pExaScr.info.ModifyPixmapHeader(pPixmap, width, height, depth,
                                                bitsPerPixel, devKind,
                                                pPixData);
        /* For EXA_HANDLES_PIXMAPS, we set pPixData to NULL.
         * If pPixmap->devPrivate.ptr is non-NULL, then we've got a
         * !has_gpu_copy pixmap. We need to store the pointer,
         * because PrepareAccess won't be called.
         */
        if (!pPixData && pPixmap.devPrivate.ptr && pPixmap.devKind) {
            pExaPixmap.sys_ptr = cast(ubyte*)pPixmap.devPrivate.ptr;
            pExaPixmap.sys_pitch = pPixmap.devKind;
        }
        if (ret == True)
            goto out_;
    }

    mixin(swap!("pExaScr", "pScreen", "ModifyPixmapHeader"));
    ret = pScreen.ModifyPixmapHeader(pPixmap, width, height, depth,
                                      bitsPerPixel, devKind, pPixData);
    mixin(swap!("pExaScr", "pScreen", "ModifyPixmapHeader"));

 out_:
    /* Always NULL this, we don't want lingering pointers. */
    pPixmap.devPrivate.ptr = null;

    return ret;
}

void exaPixmapDestroy_driver(CallbackListPtr* pcbl, ScreenPtr pScreen, PixmapPtr pPixmap)
{
    mixin(ExaScreenPriv!("pScreen"));

    mixin(ExaPixmapPriv!("pPixmap"));;
    if (!pExaPixmap) // we're called on an error path
        return;

    exaDestroyPixmap(pPixmap);

    if (pExaPixmap.driverPriv)
        pExaScr.info.DestroyPixmap(pScreen, pExaPixmap.driverPriv);
    pExaPixmap.driverPriv = null;
}

Bool exaPixmapHasGpuCopy_driver(PixmapPtr pPixmap)
{
    ScreenPtr pScreen = pPixmap.drawable.pScreen;

    mixin(ExaScreenPriv!("pScreen"));
    void* saved_ptr = void;
    Bool ret = void;

    saved_ptr = pPixmap.devPrivate.ptr;
    pPixmap.devPrivate.ptr = ExaGetPixmapAddress(pPixmap);
    ret = pExaScr.info.PixmapIsOffscreen(pPixmap);
    pPixmap.devPrivate.ptr = saved_ptr;

    return ret;
}
