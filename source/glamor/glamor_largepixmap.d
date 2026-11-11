module glamor.glamor_largepixmap;
@nogc nothrow:
extern(C): __gshared:
import build.dix_config;

import core.stdc.assert_;
import core.stdc.stdlib;
import core.stdc.stdint; /* For INT16_MAX */

import os.bug_priv;

import glamor.glamor_priv;
import externs.X11.extensions.render_;
import glamor.glamor;
import externs.attrs;
import region;
import dix.picture;
import common.math;

alias INT16_MAX = core.stdc.stdint.INT16_MAX;

pragma(inline, true) private glamor_pixmap_private* __glamor_large(glamor_pixmap_private* pixmap_priv) {
    assert(glamor_pixmap_priv_is_large(pixmap_priv));
    return pixmap_priv;
}

enum string COMPOSITE_REGION(string region) = `{				
	if (!glamor_composite_clipped_region(op,		
			 null_source ? null : source,		
			 null_mask ? null : mask, dest,		
			 null_source ? null : source_pixmap,    
			 null_mask ? null : mask_pixmap, 	
			 dest_pixmap, ` ~ region ~ `,		        
			 x_source, y_source, x_mask, y_mask,	
			 x_dest, y_dest)) {			
		assert(0);					
	}							
   }`;

/**
 * Clip the boxes regards to each pixmap's block array.
 *
 * Should translate the region to relative coords to the pixmap,
 * start at (0,0).
 */
version (none) {
//#define DEBUGF(str, ...)  do {} while(0)
enum string DEBUGF(string str) = `ErrorF(` ~ str ~ `, ##__VA_ARGS__)`;
//#define DEBUGRegionPrint(x) do {} while (0)
enum DEBUGRegionPrint = RegionPrint;
}

private glamor_pixmap_clipped_regions* __glamor_compute_clipped_regions(int block_w, int block_h, int block_stride, int x, int y, int w, int h, RegionPtr region, int* n_region, int reverse, int upsidedown)
{
    glamor_pixmap_clipped_regions* clipped_regions = void;
    BoxPtr extent = void;
    int start_x = void, start_y = void, end_x = void, end_y = void;
    int start_block_x = void, start_block_y = void;
    int end_block_x = void, end_block_y = void;
    int loop_start_block_x = void, loop_start_block_y = void;
    int loop_end_block_x = void, loop_end_block_y = void;
    int loop_block_stride = void;
    int i = void, j = void, delta_i = void, delta_j = void;
    RegionRec temp_region = void;
    RegionPtr current_region = void;
    int block_idx = void;
    int k = 0;
    int temp_block_idx = void;

    extent = RegionExtents(region);
    start_x = mixin(MAX!("x", "extent.x1"));
    start_y = mixin(MAX!("y", "extent.y1"));
    end_x = mixin(MIN!("x + w", "extent.x2"));
    end_y = mixin(MIN!("y + h", "extent.y2"));

    //mixin(DEBUGF!(`"start compute clipped regions:\n"`));
    //mixin(DEBUGF!(`"block w %d h %d  x %d y %d w %d h %d, block_stride %d \n"`,
        //    `block_w`, `block_h`, `x`, `y`, `w`, `h`, `block_stride`));
    // DEBUGRegionPrint(region);

    //mixin(DEBUGF!(`"start_x %d start_y %d end_x %d end_y %d \n"`, `start_x`, `start_y`,
        //    `end_x`, `end_y`));

    if (start_x >= end_x || start_y >= end_y) {
        *n_region = 0;
        return null;
    }

    start_block_x = (start_x - x) / block_w;
    start_block_y = (start_y - y) / block_h;
    end_block_x = (end_x - x) / block_w;
    end_block_y = (end_y - y) / block_h;

    clipped_regions = cast(glamor_pixmap_clipped_regions*) calloc((end_block_x - start_block_x + 1)
                             * (end_block_y - start_block_y + 1),
                             typeof(*clipped_regions).sizeof);
    if (!clipped_regions) {
        *n_region = 0;
        return null;
    }

    //mixin(DEBUGF!(`"startx %d starty %d endx %d endy %d \n"`,
        //    `start_x`, `start_y`, `end_x`, `end_y`));
    //mixin(DEBUGF!(`"start_block_x %d end_block_x %d \n"`, `start_block_x`, `end_block_x`));
    //mixin(DEBUGF!(`"start_block_y %d end_block_y %d \n"`, `start_block_y`, `end_block_y`));

    if (!reverse) {
        loop_start_block_x = start_block_x;
        loop_end_block_x = end_block_x + 1;
        delta_i = 1;
    }
    else {
        loop_start_block_x = end_block_x;
        loop_end_block_x = start_block_x - 1;
        delta_i = -1;
    }

    if (!upsidedown) {
        loop_start_block_y = start_block_y;
        loop_end_block_y = end_block_y + 1;
        delta_j = 1;
    }
    else {
        loop_start_block_y = end_block_y;
        loop_end_block_y = start_block_y - 1;
        delta_j = -1;
    }

    loop_block_stride = delta_j * block_stride;
    block_idx = (loop_start_block_y - delta_j) * block_stride;

    for (j = loop_start_block_y; j != loop_end_block_y; j += delta_j) {
        block_idx += loop_block_stride;
        temp_block_idx = block_idx + loop_start_block_x;
        for (i = loop_start_block_x;
             i != loop_end_block_x; i += delta_i, temp_block_idx += delta_i) {
            BoxRec temp_box = void;

            temp_box.x1 = cast(short)(x + i * block_w);
            temp_box.y1 = cast(short)(y + j * block_h);
            temp_box.x2 = cast(short)mixin(MIN!("temp_box.x1 + block_w", "end_x"));
            temp_box.y2 = cast(short)mixin(MIN!("temp_box.y1 + block_h", "end_y"));
            RegionInitBoxes(&temp_region, &temp_box, 1);
            //mixin(DEBUGF!(`"block idx %d \n"`, `temp_block_idx`));
            // DEBUGRegionPrint(&temp_region);
            current_region = RegionCreate(null, 4);
            // RegionIntersect(current_region, &temp_region, region);
            //mixin(DEBUGF!(`"i %d j %d  region: \n"`, `i`, `j`));
            // DEBUGRegionPrint(current_region);
            if (RegionNumRects(current_region)) {
                clipped_regions[k].region = current_region;
                clipped_regions[k].block_idx = temp_block_idx;
                k++;
            }
            else
                RegionDestroy(current_region);
            RegionUninit(&temp_region);
        }
    }

    *n_region = k;
    return clipped_regions;
}

/**
 * Do a two round clipping,
 * first is to clip the region regard to current pixmap's
 * block array. Then for each clipped region, do a inner
 * block clipping. This is to make sure the final result
 * will be shapped by inner_block_w and inner_block_h, and
 * the final region also will not cross the pixmap's block
 * boundary.
 *
 * This is mainly used by transformation support when do
 * compositing.
 */

glamor_pixmap_clipped_regions* glamor_compute_clipped_regions_ext(PixmapPtr pixmap, RegionPtr region, int* n_region, int inner_block_w, int inner_block_h, int reverse, int upsidedown)
{
    glamor_pixmap_private* pixmap_priv = glamor_get_pixmap_private(pixmap);
    glamor_pixmap_clipped_regions* clipped_regions = void, inner_regions = void, result_regions = void;
    int i = void, j = void, x = void, y = void, k = void, inner_n_regions = void;
    int width = void, height = void;
    BoxPtr box_array = void;
    BoxRec small_box = void;
    int block_w = void, block_h = void;

    //mixin(DEBUGF!(`"ext called \n"`));

    if (glamor_pixmap_priv_is_small(pixmap_priv)) {
        clipped_regions = cast(glamor_pixmap_clipped_regions*) calloc(1, typeof(*clipped_regions).sizeof);
        if (clipped_regions is null) {
            *n_region = 0;
            return null;
        }
        clipped_regions[0].region = RegionCreate(null, 1);
        clipped_regions[0].block_idx = 0;
        RegionCopy(clipped_regions[0].region, region);
        *n_region = 1;
        block_w = pixmap.drawable.width;
        block_h = pixmap.drawable.height;
        box_array = &small_box;
        small_box.x1 = small_box.y1 = 0;
        small_box.x2 = cast(short)block_w;
        small_box.y2 = cast(short)block_h;
    }
    else {
        mixin(BUG_RETURN_VAL!("!pixmap_priv", "null"));
        glamor_pixmap_private* priv = __glamor_large(pixmap_priv);

        clipped_regions = __glamor_compute_clipped_regions(priv.block_w,
                                                           priv.block_h,
                                                           priv.block_wcnt,
                                                           0, 0,
                                                           pixmap.drawable.width,
                                                           pixmap.drawable.height,
                                                           region, n_region,
                                                           reverse, upsidedown);

        if (clipped_regions is null) {
            *n_region = 0;
            return null;
        }
        block_w = priv.block_w;
        block_h = priv.block_h;
        box_array = priv.box_array;
    }
    if (inner_block_w >= block_w && inner_block_h >= block_h)
        return clipped_regions;
    result_regions = cast(glamor_pixmap_clipped_regions*) calloc(*n_region
                            * ((block_w + inner_block_w - 1) /
                               inner_block_w)
                            * ((block_h + inner_block_h - 1) /
                               inner_block_h), typeof(*result_regions).sizeof);
    if (!result_regions) {
        *n_region = 0;
        free(clipped_regions);
        return null;
    }

    k = 0;
    for (i = 0; i < *n_region; i++) {
        x = box_array[clipped_regions[i].block_idx].x1;
        y = box_array[clipped_regions[i].block_idx].y1;
        width = box_array[clipped_regions[i].block_idx].x2 - x;
        height = box_array[clipped_regions[i].block_idx].y2 - y;
        inner_regions = __glamor_compute_clipped_regions(inner_block_w,
                                                         inner_block_h,
                                                         0, x, y,
                                                         width,
                                                         height,
                                                         clipped_regions[i].
                                                         region,
                                                         &inner_n_regions,
                                                         reverse, upsidedown);
        for (j = 0; j < inner_n_regions; j++) {
            result_regions[k].region = inner_regions[j].region;
            result_regions[k].block_idx = clipped_regions[i].block_idx;
            k++;
        }
        free(inner_regions);
    }
    *n_region = k;
    free(clipped_regions);
    return result_regions;
}

/*
 *
 * For the repeat pad mode, we can simply convert the region and
 * let the out-of-box region can cover the needed edge of the source/mask
 * Then apply a normal clip we can get what we want.
 */
private RegionPtr _glamor_convert_pad_region(RegionPtr region, int w, int h)
{
    RegionPtr pad_region = void;
    int nrect = void;
    BoxPtr box = void;
    int overlap = void;

    nrect = RegionNumRects(region);
    box = RegionRects(region);
    pad_region = RegionCreate(null, 4);
    if (pad_region is null)
        return null;
    while (nrect--) {
        BoxRec pad_box = void;
        RegionRec temp_region = void;

        pad_box = *box;
        if (pad_box.x1 < 0 && pad_box.x2 <= 0)
            pad_box.x2 = 1;
        else if (pad_box.x1 >= w && pad_box.x2 > w)
            pad_box.x1 = cast(short)(w - 1);
        if (pad_box.y1 < 0 && pad_box.y2 <= 0)
            pad_box.y2 = 1;
        else if (pad_box.y1 >= h && pad_box.y2 > h)
            pad_box.y1 = cast(short)(h - 1);
        RegionInitBoxes(&temp_region, &pad_box, 1);
        RegionAppend(pad_region, &temp_region);
        RegionUninit(&temp_region);
        box++;
    }
    RegionValidate(pad_region, &overlap);
    return pad_region;
}

/*
 * For one type of large pixmap, its one direction is not exceed the
 * size limitation, and in another word, on one direction it has only
 * one block.
 *
 * This case of reflect repeating, we can optimize it and avoid repeat
 * clip on that direction. We can just enlarge the repeat box and can
 * cover all the dest region on that direction. But latter, we need to
 * fixup the clipped result to get a correct coords for the subsequent
 * processing. This function is to do the coords correction.
 *
 * */
private void _glamor_largepixmap_reflect_fixup(short* xy1, short* xy2, int wh)
{
    int odd1 = void, odd2 = void;
    int c1 = void, c2 = void;

    if (*xy2 - *xy1 > wh) {
        *xy1 = 0;
        *xy2 = cast(short)wh;
        return;
    }
    c1 = modulus(*xy1, wh);
    odd1 = ((*xy1 - c1) / wh) & 0x1;
    c2 = modulus(*xy2, wh);
    odd2 = ((*xy2 - c2) / wh) & 0x1;

    if (odd1 && odd2) {
        *xy1 = cast(short)(wh - c2);
        *xy2 = cast(short)(wh - c1);
    }
    else if (odd1 && !odd2) {
        *xy1 = 0;
        *xy2 = cast(short)mixin(MAX!("c2", "wh - c1"));
    }
    else if (!odd1 && odd2) {
        *xy2 = cast(short)wh;
        *xy1 = cast(short)mixin(MIN!("c1", "wh - c2"));
    }
    else {
        *xy1 = cast(short)c1;
        *xy2 = cast(short)c2;
    }
}

/**
 * Clip the boxes regards to each pixmap's block array.
 *
 * Should translate the region to relative coords to the pixmap,
 * start at (0,0).
 *
 * @is_transform: if it is set, it has a transform matrix.
 *
 */
private glamor_pixmap_clipped_regions* _glamor_compute_clipped_regions(PixmapPtr pixmap, glamor_pixmap_private* pixmap_priv, RegionPtr region, int* n_region, int repeat_type, int is_transform, int reverse, int upsidedown)
{
    glamor_pixmap_clipped_regions* clipped_regions = void;
    BoxPtr extent = void;
    int i = void, j = void;
    RegionPtr current_region = void;
    int pixmap_width = void, pixmap_height = void;
    int m = void;
    BoxRec repeat_box = void;
    RegionRec repeat_region = void;
    int right_shift = 0;
    int down_shift = 0;
    int x_center_shift = 0, y_center_shift = 0;
    glamor_pixmap_private* priv = void;

    // DEBUGRegionPrint(region);
    if (glamor_pixmap_priv_is_small(pixmap_priv)) {
        clipped_regions = cast(glamor_pixmap_clipped_regions*) calloc(1, typeof(*clipped_regions).sizeof);
        if (!clipped_regions) {
            *n_region = 0;
            return null;
        }

        clipped_regions[0].region = RegionCreate(null, 1);
        clipped_regions[0].block_idx = 0;
        RegionCopy(clipped_regions[0].region, region);
        *n_region = 1;
        return clipped_regions;
    }

    priv = __glamor_large(pixmap_priv);

    pixmap_width = pixmap.drawable.width;
    pixmap_height = pixmap.drawable.height;
    if (repeat_type == 0 || repeat_type == RepeatPad) {
        RegionPtr saved_region = null;

        if (repeat_type == RepeatPad) {
            saved_region = region;
            region =
                _glamor_convert_pad_region(saved_region, pixmap_width,
                                           pixmap_height);
            if (region is null) {
                *n_region = 0;
                return null;
            }
        }
        clipped_regions = __glamor_compute_clipped_regions(priv.block_w,
                                                           priv.block_h,
                                                           priv.block_wcnt,
                                                           0, 0,
                                                           pixmap.drawable.width,
                                                           pixmap.drawable.height,
                                                           region, n_region,
                                                           reverse, upsidedown);
        if (saved_region)
            RegionDestroy(region);
        return clipped_regions;
    }
    extent = RegionExtents(region);

    x_center_shift = extent.x1 / pixmap_width;
    if (x_center_shift < 0)
        x_center_shift--;
    if (abs(x_center_shift) & 1)
        x_center_shift++;
    y_center_shift = extent.y1 / pixmap_height;
    if (y_center_shift < 0)
        y_center_shift--;
    if (abs(y_center_shift) & 1)
        y_center_shift++;

    if (extent.x1 < 0)
        right_shift = ((-extent.x1 + pixmap_width - 1) / pixmap_width);
    if (extent.y1 < 0)
        down_shift = ((-extent.y1 + pixmap_height - 1) / pixmap_height);

    if (right_shift != 0 || down_shift != 0) {
        if (repeat_type == RepeatReflect) {
            right_shift = (right_shift + 1) & ~1;
            down_shift = (down_shift + 1) & ~1;
        }
        RegionTranslate(region, right_shift * pixmap_width,
                        down_shift * pixmap_height);
    }

    extent = RegionExtents(region);
    /* Tile a large pixmap to another large pixmap.
     * We can't use the target large pixmap as the
     * loop variable, instead we need to loop for all
     * the blocks in the tile pixmap.
     *
     * simulate repeat each single block to cover the
     * target's blocks. Two special case:
     * a block_wcnt == 1 or block_hcnt ==1, then we
     * only need to loop one direction as the other
     * direction is fully included in the first block.
     *
     * For the other cases, just need to start
     * from a proper shiftx/shifty, and then increase
     * y by tile_height each time to walk through the
     * target block and then walk through the target
     * at x direction by increate tile_width each time.
     *
     * This way, we can consolidate all the sub blocks
     * of the target boxes into one tile source's block.
     *
     * */
    m = 0;
    clipped_regions = cast(glamor_pixmap_clipped_regions*) calloc(priv.block_wcnt * priv.block_hcnt,
                             typeof(*clipped_regions).sizeof);
    if (clipped_regions is null) {
        *n_region = 0;
        return null;
    }
    if (right_shift != 0 || down_shift != 0) {
        //mixin(DEBUGF!(`"region to be repeated shifted \n"`));
        // DEBUGRegionPrint(region);
    }
    //mixin(DEBUGF!(`"repeat pixmap width %d height %d \n"`, `pixmap_width`, `pixmap_height`));
    //mixin(DEBUGF!(`"extent x1 %d y1 %d x2 %d y2 %d \n"`, `extent.x1`, `extent.y1`,
        //    `extent.x2`, `extent.y2`));
    for (j = 0; j < priv.block_hcnt; j++) {
        for (i = 0; i < priv.block_wcnt; i++) {
            int dx = pixmap_width;
            int dy = pixmap_height;
            int idx = void;
            int shift_x = void;
            int shift_y = void;
            int saved_y1 = void, saved_y2 = void;
            int x_idx = 0, y_idx = 0, saved_y_idx = 0;
            RegionRec temp_region = void;
            BoxRec reflect_repeat_box = void;
            BoxPtr valid_repeat_box = void;

            shift_x = (extent.x1 / pixmap_width) * pixmap_width;
            shift_y = (extent.y1 / pixmap_height) * pixmap_height;
            idx = j * priv.block_wcnt + i;
            if (repeat_type == RepeatReflect) {
                x_idx = (extent.x1 / pixmap_width);
                y_idx = (extent.y1 / pixmap_height);
            }

            /* Construct a rect to clip the target region. */
            repeat_box.x1 = cast(short)(shift_x + priv.box_array[idx].x1);
            repeat_box.y1 = cast(short)(shift_y + priv.box_array[idx].y1);
            if (priv.block_wcnt == 1) {
                repeat_box.x2 = cast(short)extent.x2;
                dx = extent.x2 - repeat_box.x1;
            }
            else
                repeat_box.x2 = cast(short)(shift_x + priv.box_array[idx].x2);
            if (priv.block_hcnt == 1) {
                repeat_box.y2 = cast(short)(extent.y2);
                dy = extent.y2 - repeat_box.y1;
            }
            else
                repeat_box.y2 =cast(short) (shift_y + priv.box_array[idx].y2);

            current_region = RegionCreate(null, 4);
            RegionInit(&temp_region, null, 4);
            //mixin(DEBUGF!(`"init repeat box %d %d %d %d \n"`,
                //    `repeat_box.x1`, `repeat_box.y1`, `repeat_box.x2`, `repeat_box.y2`));

            if (repeat_type == RepeatNormal) {
                saved_y1 = repeat_box.y1;
                saved_y2 = repeat_box.y2;
                for (; repeat_box.x1 < extent.x2;
                     repeat_box.x1 += dx, repeat_box.x2 += dx) {
                    repeat_box.y1 = cast(short)saved_y1;
                    repeat_box.y2 = cast(short)saved_y2;
                    for (repeat_box.y1 = cast(short)saved_y1, repeat_box.y2 = cast(short)saved_y2;
                         repeat_box.y1 < extent.y2;
                         repeat_box.y1 += cast(short)dy, repeat_box.y2 += cast(short)dy) {

                        RegionInitBoxes(&repeat_region, &repeat_box, 1);
                        //mixin(DEBUGF!(`"Start to clip repeat region: \n"`));
                        // DEBUGRegionPrint(&repeat_region);
                        RegionIntersect(&temp_region, &repeat_region, region);
                        //mixin(DEBUGF!(`"clip result:\n"`));
                        // DEBUGRegionPrint(&temp_region);
                        RegionAppend(current_region, &temp_region);
                        RegionUninit(&repeat_region);
                    }
                }
            }
            else if (repeat_type == RepeatReflect) {
                saved_y1 = repeat_box.y1;
                saved_y2 = repeat_box.y2;
                saved_y_idx = y_idx;
                for (;; repeat_box.x1 += dx, repeat_box.x2 += dx) {
                    repeat_box.y1 = cast(short)saved_y1;
                    repeat_box.y2 = cast(short)saved_y2;
                    y_idx = saved_y_idx;
                    reflect_repeat_box.x1 = (x_idx & 1) ?
                        cast(short)((2 * x_idx + 1) * dx - repeat_box.x2) : cast(short)repeat_box.x1;
                    reflect_repeat_box.x2 = (x_idx & 1) ?
                        cast(short)((2 * x_idx + 1) * dx - repeat_box.x1) : cast(short)repeat_box.x2;
                    valid_repeat_box = &reflect_repeat_box;

                    if (valid_repeat_box.x1 >= extent.x2)
                        break;
                    for (repeat_box.y1 = cast(short)saved_y1, repeat_box.y2 = cast(short)saved_y2;;
                         repeat_box.y1 += cast(short)dy, repeat_box.y2 += cast(short)dy) {

                        //mixin(DEBUGF!(`"x_idx %d y_idx %d dx %d dy %d\n"`, `x_idx`, `y_idx`,
                            //    `dx`, `dy`));
                        //mixin(DEBUGF!(`"repeat box %d %d %d %d \n"`, `repeat_box.x1`,
                            //    `repeat_box.y1`, `repeat_box.x2`, `repeat_box.y2`));

                        if (priv.block_hcnt > 1) {
                            reflect_repeat_box.y1 = (y_idx & 1) ?
                                cast(short)((2 * y_idx + 1) * dy -
                                 repeat_box.y2) : cast(short)repeat_box.y1;
                            reflect_repeat_box.y2 =
                                (y_idx & 1) ? cast(short)((2 * y_idx + 1) * dy -
                                               repeat_box.y1) : cast(short)repeat_box.y2;
                        }
                        else {
                            reflect_repeat_box.y1 = cast(short)repeat_box.y1;
                            reflect_repeat_box.y2 = cast(short)repeat_box.y2;
                        }

                        //mixin(DEBUGF!(`"valid_repeat_box x1 %d y1 %d \n"`,
                            //    `valid_repeat_box.x1`, `valid_repeat_box.y1`));
                        if (valid_repeat_box.y1 >= extent.y2)
                            break;
                        RegionInitBoxes(&repeat_region, valid_repeat_box, 1);
                        //mixin(DEBUGF!(`"start to clip repeat[reflect] region: \n"`));
                        // DEBUGRegionPrint(&repeat_region);
                        RegionIntersect(&temp_region, &repeat_region, region);
                        //mixin(DEBUGF!(`"result:\n"`));
                        // DEBUGRegionPrint(&temp_region);
                        if (is_transform && RegionNumRects(&temp_region)) {
                            BoxRec temp_box = void;
                            BoxPtr temp_extent = void;

                            temp_extent = RegionExtents(&temp_region);
                            if (priv.block_wcnt > 1) {
                                if (x_idx & 1) {
                                    temp_box.x1 =
                                        cast(short)((2 * x_idx + 1) * dx -
                                         temp_extent.x2);
                                    temp_box.x2 =
                                        cast(short)((2 * x_idx + 1) * dx -
                                         temp_extent.x1);
                                }
                                else {
                                    temp_box.x1 = cast(short)temp_extent.x1;
                                    temp_box.x2 = cast(short)temp_extent.x2;
                                }
                                temp_box.x1 = cast(short)modulus(temp_box.x1, pixmap_width);
                                temp_box.x2 = cast(short)modulus(temp_box.x2, pixmap_width);
                                if (temp_box.x2 == 0)
                                    temp_box.x2 = cast(short)pixmap_width;
                            }
                            else {
                                temp_box.x1 = cast(short)temp_extent.x1;
                                temp_box.x2 = cast(short)temp_extent.x2;
                                _glamor_largepixmap_reflect_fixup(&temp_box.x1,
                                                                  &temp_box.x2,
                                                                  pixmap_width);
                            }

                            if (priv.block_hcnt > 1) {
                                if (y_idx & 1) {
                                    temp_box.y1 =
                                        cast(short)((2 * y_idx + 1) * dy -
                                         temp_extent.y2);
                                    temp_box.y2 =
                                        cast(short)((2 * y_idx + 1) * dy -
                                         temp_extent.y1);
                                }
                                else {
                                    temp_box.y1 = cast(short)temp_extent.y1;
                                    temp_box.y2 = cast(short)temp_extent.y2;
                                }

                                temp_box.y1 = cast(short)modulus(temp_box.y1, pixmap_height);
                                temp_box.y2 = cast(short)modulus(temp_box.y2, pixmap_height);
                                if (temp_box.y2 == 0)
                                    temp_box.y2 = cast(short)pixmap_height;
                            }
                            else {
                                temp_box.y1 = cast(short)temp_extent.y1;
                                temp_box.y2 = cast(short)temp_extent.y2;
                                _glamor_largepixmap_reflect_fixup(&temp_box.y1,
                                                                  &temp_box.y2,
                                                                  pixmap_height);
                            }

                            RegionInitBoxes(&temp_region, &temp_box, 1);
                            RegionTranslate(&temp_region,
                                            x_center_shift * pixmap_width,
                                            y_center_shift * pixmap_height);
                            //mixin(DEBUGF!(`"for transform result:\n"`));
                            // DEBUGRegionPrint(&temp_region);
                        }
                        RegionAppend(current_region, &temp_region);
                        RegionUninit(&repeat_region);
                        y_idx++;
                    }
                    x_idx++;
                }
            }
            //mixin(DEBUGF!(`"dx %d dy %d \n"`, `dx`, `dy`));

            if (RegionNumRects(current_region)) {

                if ((right_shift != 0 || down_shift != 0) &&
                    !(is_transform && repeat_type == RepeatReflect))
                    RegionTranslate(current_region, -right_shift * pixmap_width,
                                    -down_shift * pixmap_height);
                clipped_regions[m].region = current_region;
                clipped_regions[m].block_idx = idx;
                m++;
            }
            else
                RegionDestroy(current_region);
            RegionUninit(&temp_region);
        }
    }

    if (right_shift != 0 || down_shift != 0)
        RegionTranslate(region, -right_shift * pixmap_width,
                        -down_shift * pixmap_height);
    *n_region = m;

    return clipped_regions;
}

glamor_pixmap_clipped_regions* glamor_compute_clipped_regions(PixmapPtr pixmap, RegionPtr region, int* n_region, int repeat_type, int reverse, int upsidedown)
{
    glamor_pixmap_private* priv = glamor_get_pixmap_private(pixmap);
    return _glamor_compute_clipped_regions(pixmap, priv, region, n_region, repeat_type,
                                           0, reverse, upsidedown);
}

/* XXX overflow still exist. maybe we need to change to use region32.
 * by default. Or just use region32 for repeat cases?
 **/
private glamor_pixmap_clipped_regions* glamor_compute_transform_clipped_regions(PixmapPtr pixmap, pixman_transform* transform, RegionPtr region, int* n_region, int dx, int dy, int repeat_type, int reverse, int upsidedown)
{
    glamor_pixmap_private* priv = glamor_get_pixmap_private(pixmap);
    BoxPtr temp_extent = void;
    pixman_box32 temp_box = void;
    pixman_box16 short_box = void;
    RegionPtr temp_region = void;
    glamor_pixmap_clipped_regions* ret = void;

    temp_region = RegionCreate(null, 4);
    temp_extent = RegionExtents(region);
    //mixin(DEBUGF!(`"dest region \n"`));
    // DEBUGRegionPrint(region);
    /* dx/dy may exceed MAX SHORT. we have to use
     * a box32 to represent it.*/
    temp_box.x1 = temp_extent.x1 + dx;
    temp_box.x2 = temp_extent.x2 + dx;
    temp_box.y1 = temp_extent.y1 + dy;
    temp_box.y2 = temp_extent.y2 + dy;

    //mixin(DEBUGF!(`"source box %d %d %d %d \n"`, `temp_box.x1`, `temp_box.y1`, `temp_box.x2`,
        //    `temp_box.y2`));
    if (transform)
        glamor_get_transform_extent_from_box(&temp_box, transform);
    if (repeat_type == RepeatNone) {
        if (temp_box.x1 < 0)
            temp_box.x1 = 0;
        if (temp_box.y1 < 0)
            temp_box.y1 = 0;
        temp_box.x2 = mixin(MIN!("temp_box.x2", "pixmap.drawable.width"));
        temp_box.y2 = mixin(MIN!("temp_box.y2", "pixmap.drawable.height"));
    }
    /* Now copy back the box32 to a box16 box, avoiding overflow. */
    short_box.x1 = cast(short)mixin(MIN!("temp_box.x1", "INT16_MAX"));
    short_box.y1 = cast(short)mixin(MIN!("temp_box.y1", "INT16_MAX"));
    short_box.x2 = cast(short)mixin(MIN!("temp_box.x2", "INT16_MAX"));
    short_box.y2 = cast(short)mixin(MIN!("temp_box.y2", "INT16_MAX"));
    RegionInitBoxes(temp_region, &short_box, 1);
    //mixin(DEBUGF!(`"copy to temp source region \n"`));
    // DEBUGRegionPrint(temp_region);
    ret = _glamor_compute_clipped_regions(pixmap,
                                          priv,
                                          temp_region,
                                          n_region,
                                          repeat_type, 1, reverse, upsidedown);
    //mixin(DEBUGF!(`"n_regions = %d \n"`, `*n_region`));
    RegionDestroy(temp_region);

    return ret;
}

/*
 * As transform and repeatpad mode.
 * We may get a clipped result which in multiple regions.
 * It's not easy to do a 2nd round clipping just as we do
 * without transform/repeatPad. As it's not easy to reverse
 * the 2nd round clipping result with a transform/repeatPad mode,
 * or even impossible for some transformation.
 *
 * So we have to merge the fragmental region into one region
 * if the clipped result cross the region boundary.
 */
private void glamor_merge_clipped_regions(PixmapPtr pixmap, glamor_pixmap_private* pixmap_priv, int repeat_type, glamor_pixmap_clipped_regions* clipped_regions, int* n_regions, int* need_clean_fbo)
{
    BoxRec temp_box = void, copy_box = void;
    RegionPtr temp_region = void;
    glamor_pixmap_private* temp_priv = void;
    PixmapPtr temp_pixmap = void;
    int overlap = void;
    int i = void;
    int pixmap_width = void, pixmap_height = void;
    glamor_pixmap_private* priv = void;

    priv = __glamor_large(pixmap_priv);
    pixmap_width = pixmap.drawable.width;
    pixmap_height =pixmap.drawable.height;

    temp_region = RegionCreate(null, 4);
    for (i = 0; i < *n_regions; i++) {
        //mixin(DEBUGF!(`"Region %d:\n"`, `i`));
        // DEBUGRegionPrint(clipped_regions[i].region);
        RegionAppend(temp_region, clipped_regions[i].region);
    }

    RegionValidate(temp_region, &overlap);
    //mixin(DEBUGF!(`"temp region: \n"`));
    // DEBUGRegionPrint(temp_region);

    temp_box = *RegionExtents(temp_region);

    //mixin(DEBUGF!(`"need copy region: \n"`));
    //mixin(DEBUGF!(`"%d %d %d %d \n"`, `temp_box.x1`, `temp_box.y1`, `temp_box.x2`,
        //    `temp_box.y2`));
    temp_pixmap =
        glamor_create_pixmap(pixmap.drawable.pScreen,
                             temp_box.x2 - temp_box.x1,
                             temp_box.y2 - temp_box.y1,
                             pixmap.drawable.depth,
                             GLAMOR_CREATE_PIXMAP_FIXUP);
    if (temp_pixmap is null) {
        assert(0);
        return;
    }

    temp_priv = glamor_get_pixmap_private(temp_pixmap);
    assert(glamor_pixmap_priv_is_small(temp_priv));

    priv.box = temp_box;
    if (temp_box.x1 >= 0 && temp_box.x2 <= pixmap_width
        && temp_box.y1 >= 0 && temp_box.y2 <= pixmap_height) {
        int dx = void, dy = void;

        copy_box.x1 = 0;
        copy_box.y1 = 0;
        copy_box.x2 = cast(short)(temp_box.x2 - temp_box.x1);
        copy_box.y2 = cast(short)(temp_box.y2 - temp_box.y1);
        dx = temp_box.x1;
        dy = temp_box.y1;
        glamor_copy(&pixmap.drawable,
                    &temp_pixmap.drawable,
                    null, &copy_box, 1, dx, dy, 0, 0, 0, null);
//              glamor_solid(temp_pixmap, 0, 0, temp_pixmap->drawable.width,
//                             temp_pixmap->drawable.height, GXcopy, 0xffffffff, 0xff00);
    }
    else {
        for (i = 0; i < *n_regions; i++) {
            BoxPtr box = void;
            int nbox = void;

            box = REGION_RECTS(clipped_regions[i].region);
            nbox = REGION_NUM_RECTS(clipped_regions[i].region);
            while (nbox--) {
                int dx = void, dy = void, c = void, d = void;

                //mixin(DEBUGF!(`"box x1 %d y1 %d x2 %d y2 %d \n"`,
                    //    `box.x1`, `box.y1`, `box.x2`, `box.y2`));
                c = modulus(box.x1, pixmap_width);
                dx = c - (box.x1 - temp_box.x1);
                copy_box.x1 = cast(short)(box.x1 - temp_box.x1);
                copy_box.x2 = cast(short)(box.x2 - temp_box.x1);

                d = modulus(box.y1, pixmap_height);
                dy = d - (box.y1 - temp_box.y1);
                copy_box.y1 = cast(short)(box.y1 - temp_box.y1);
                copy_box.y2 = cast(short)(box.y2 - temp_box.y1);

                //mixin(DEBUGF!(`"copying box %d %d %d %d, dx %d dy %d\n"`,
                    //    `copy_box.x1`, `copy_box.y1`, `copy_box.x2`,
                    //    `copy_box.y2`, `dx`, `dy`));

                glamor_copy(&pixmap.drawable,
                            &temp_pixmap.drawable,
                            null, &copy_box, 1, dx, dy, 0, 0, 0, null);

                box++;
            }
        }
        //glamor_solid(temp_pixmap, 0, 0, temp_pixmap->drawable.width,
        //             temp_pixmap->drawable.height, GXcopy, 0xffffffff, 0xff);
    }
    /* The first region will be released at caller side. */
    for (i = 1; i < *n_regions; i++)
        RegionDestroy(clipped_regions[i].region);
    RegionDestroy(temp_region);
    priv.box = temp_box;
    priv.fbo = glamor_pixmap_detach_fbo(temp_priv);
    //mixin(DEBUGF!(`"priv box x1 %d y1 %d x2 %d y2 %d \n"`,
        //    `priv.box.x1`, `priv.box.y1`, `priv.box.x2`, `priv.box.y2`));
    glamor_destroy_pixmap(temp_pixmap);
    *need_clean_fbo = 1;
    *n_regions = 1;
}

/**
 * Given an expected transformed block width and block height,
 *
 * This function calculate a new block width and height which
 * guarantee the transform result will not exceed the given
 * block width and height.
 *
 * For large block width and height (> 2048), we choose a
 * smaller new width and height and to reduce the cross region
 * boundary and can avoid some overhead.
 *
 **/
private Bool glamor_get_transform_block_size(pixman_transform* transform, int block_w, int block_h, int* transformed_block_w, int* transformed_block_h)
{
    double a = void, b = void, c = void, d = void, e = void, f = void, g = void, h = void;
    double scale = void;
    int width = void, height = void;

    a = pixman_fixed_to_double(transform.matrix[0][0]);
    b = pixman_fixed_to_double(transform.matrix[0][1]);
    c = pixman_fixed_to_double(transform.matrix[1][0]);
    d = pixman_fixed_to_double(transform.matrix[1][1]);
    scale = pixman_fixed_to_double(transform.matrix[2][2]);
    if (block_w > 2048) {
        /* For large block size, we shrink it to smaller box,
         * thus latter we may get less cross boundary regions and
         * thus can avoid some extra copy.
         *
         **/
        width = block_w / 4;
        height = block_h / 4;
    }
    else {
        width = block_w - 2;
        height = block_h - 2;
    }
    e = a + b;
    f = c + d;

    g = a - b;
    h = c - d;

    e = mixin(MIN!("block_w", "floor(width * scale) / "~  MAX!("fabs(e)", "fabs(g)")));
    f = mixin(MIN!("block_h", "floor(height * scale) / "~ MAX!("fabs(f)", "fabs(h)")));
    *transformed_block_w = cast(int)mixin(MIN!("e", "f")) - 1;
    *transformed_block_h = cast(int)*transformed_block_w;
    if (*transformed_block_w <= 0 || *transformed_block_h <= 0)
        return FALSE;
    //mixin(DEBUGF!(`"original block_w/h %d %d, fixed %d %d \n"`, `block_w`, `block_h`,
        //    `*transformed_block_w`, `*transformed_block_h`));
    return TRUE;
}

enum string VECTOR_FROM_POINT(string p, string x, string y) = `{
	` ~ p ~ `.v[0] = ` ~ x ~ `;  
	` ~ p ~ `.v[1] = ` ~ y ~ `;  
	` ~ p ~ `.v[2] = 1.0; }`;
private void glamor_get_transform_extent_from_box(pixman_box32* box, pixman_transform* transform)
{
    pixman_f_vector p0 = void, p1 = void, p2 = void, p3 = void;
    float min_x = void, min_y = void, max_x = void, max_y = void;

    pixman_f_transform ftransform = void;

    mixin(VECTOR_FROM_POINT!(`p0`, `box.x1`, `box.y1`));
    mixin(VECTOR_FROM_POINT!(`p1`, `box.x2`, `box.y1`));
    mixin(VECTOR_FROM_POINT!(`p2`, `box.x2`, `box.y2`));
    mixin(VECTOR_FROM_POINT!(`p3`, `box.x1`, `box.y2`));

    assumeNoGC(&pixman_f_transform_from_pixman_transform)(&ftransform, transform);
    assumeNoGC(&pixman_f_transform_point)(&ftransform, &p0);
    assumeNoGC(&pixman_f_transform_point)(&ftransform, &p1);
    assumeNoGC(&pixman_f_transform_point)(&ftransform, &p2);
    assumeNoGC(&pixman_f_transform_point)(&ftransform, &p3);

    min_x = mixin(MIN!("p0.v[0]", "p1.v[0]"));
    min_x = mixin(MIN!("min_x", "p2.v[0]"));
    min_x = mixin(MIN!("min_x", "p3.v[0]"));

    min_y = mixin(MIN!("p0.v[1]", "p1.v[1]"));
    min_y = mixin(MIN!("min_y", "p2.v[1]"));
    min_y = mixin(MIN!("min_y", "p3.v[1]"));

    max_x = mixin(MAX!("p0.v[0]", "p1.v[0]"));
    max_x = mixin(MAX!("max_x", "p2.v[0]"));
    max_x = mixin(MAX!("max_x", "p3.v[0]"));

    max_y = mixin(MAX!("p0.v[1]", "p1.v[1]"));
    max_y = mixin(MAX!("max_y", "p2.v[1]"));
    max_y = mixin(MAX!("max_y", "p3.v[1]"));
    box.x1 = cast(int)(floor(min_x) - 1);
    box.y1 = cast(int)(floor(min_y) - 1);
    box.x2 = cast(int)(ceil(max_x) + 1);
    box.y2 = cast(int)(ceil(max_y) + 1);
}

private void _glamor_process_transformed_clipped_region(PixmapPtr pixmap, glamor_pixmap_private* priv, int repeat_type, glamor_pixmap_clipped_regions* clipped_regions, int* n_regions, int* need_clean_fbo)
{
    int shift_x = void, shift_y = void;

    if (*n_regions != 1) {
        /* Merge all source regions into one region. */
        glamor_merge_clipped_regions(pixmap, priv, repeat_type,
                                     clipped_regions, n_regions,
                                     need_clean_fbo);
    }
    else {
        glamor_set_pixmap_fbo_current(priv, clipped_regions[0].block_idx);
        if (repeat_type == RepeatReflect || repeat_type == RepeatNormal) {
            /* The required source areas are in one region,
             * we need to shift the corresponding box's coords to proper position,
             * thus we can calculate the relative coords correctly.*/
            BoxPtr temp_box = void;
            int rem = void;

            temp_box = RegionExtents(clipped_regions[0].region);
            rem = modulus(temp_box.x1, pixmap.drawable.width);
            shift_x = (temp_box.x1 - rem) / pixmap.drawable.width;
            rem = modulus(temp_box.y1, pixmap.drawable.height);
            shift_y = (temp_box.y1 - rem) / pixmap.drawable.height;

            if (shift_x != 0) {
                __glamor_large(priv).box.x1 +=
                    shift_x * pixmap.drawable.width;
                __glamor_large(priv).box.x2 +=
                    shift_x * pixmap.drawable.width;
            }
            if (shift_y != 0) {
                __glamor_large(priv).box.y1 +=
                    shift_y * pixmap.drawable.height;
                __glamor_large(priv).box.y2 +=
                    shift_y * pixmap.drawable.height;
            }
        }
    }
}

Bool glamor_composite_largepixmap_region(CARD8 op, PicturePtr source, PicturePtr mask, PicturePtr dest, PixmapPtr source_pixmap, PixmapPtr mask_pixmap, PixmapPtr dest_pixmap, RegionPtr region, Bool force_clip, INT16 x_source, INT16 y_source, INT16 x_mask, INT16 y_mask, INT16 x_dest, INT16 y_dest, CARD16 width, CARD16 height)
{
    ScreenPtr screen = dest_pixmap.drawable.pScreen;
    glamor_screen_private* glamor_priv = glamor_get_screen_private(screen);
    glamor_pixmap_private* source_pixmap_priv = glamor_get_pixmap_private(source_pixmap);
    glamor_pixmap_private* mask_pixmap_priv = glamor_get_pixmap_private(mask_pixmap);
    glamor_pixmap_private* dest_pixmap_priv = glamor_get_pixmap_private(dest_pixmap);
    glamor_pixmap_clipped_regions* clipped_dest_regions = void;
    glamor_pixmap_clipped_regions* clipped_source_regions = void;
    glamor_pixmap_clipped_regions* clipped_mask_regions = void;
    int n_dest_regions = void;
    int n_mask_regions = void;
    int n_source_regions = void;
    int i = void, j = void, k = void;
    int need_clean_source_fbo = 0;
    int need_clean_mask_fbo = 0;
    int is_normal_source_fbo = 0;
    int is_normal_mask_fbo = 0;
    int fixed_block_width = void, fixed_block_height = void;
    int dest_block_width = void, dest_block_height = void;
    int null_source = void, null_mask = void;
    glamor_pixmap_private* need_free_source_pixmap_priv = null;
    glamor_pixmap_private* need_free_mask_pixmap_priv = null;
    int source_repeat_type = 0, mask_repeat_type = 0;
    int ok = TRUE;

    if (source_pixmap == dest_pixmap) {
        // glamor_fallback("source and dest pixmaps are the same\n");
        return FALSE;
    }
    if (mask_pixmap == dest_pixmap) {
        // glamor_fallback("mask and dest pixmaps are the same\n");
        return FALSE;
    }

    if (source.repeat)
        source_repeat_type = source.repeatType;
    else
        source_repeat_type = RepeatNone;

    if (mask && mask.repeat)
        mask_repeat_type = mask.repeatType;
    else
        mask_repeat_type = RepeatNone;

    if (glamor_pixmap_priv_is_large(dest_pixmap_priv)) {
        dest_block_width = __glamor_large(dest_pixmap_priv).block_w;
        dest_block_height = __glamor_large(dest_pixmap_priv).block_h;
    } else {
        dest_block_width = dest_pixmap.drawable.width;
        dest_block_height = dest_pixmap.drawable.height;
    }
    fixed_block_width = dest_block_width;
    fixed_block_height = dest_block_height;

    /* If we got an totally out-of-box region for a source or mask
     * region without repeat, we need to set it as null_source and
     * give it a solid color (0,0,0,0). */
    null_source = 0;
    null_mask = 0;
    RegionTranslate(region, -dest.pDrawable.x, -dest.pDrawable.y);

    /* need to transform the dest region to the correct sourcei/mask region.
     * it's a little complex, as one single edge of the
     * target region may be transformed to cross a block boundary of the
     * source or mask. Then it's impossible to handle it as usual way.
     * We may have to split the original dest region to smaller region, and
     * make sure each region's transformed region can fit into one texture,
     * and then continue this loop again, and each time when a transformed region
     * cross the bound, we need to copy it to a single pixmap and do the composition
     * with the new pixmap. If the transformed region doesn't cross a source/mask's
     * boundary then we don't need to copy.
     *
     */
    if (source_pixmap_priv
        && source.transform
        && glamor_pixmap_priv_is_large(source_pixmap_priv)) {
        int source_transformed_block_width = void, source_transformed_block_height = void;

        if (!glamor_get_transform_block_size(source.transform,
                                             __glamor_large(source_pixmap_priv).block_w,
                                             __glamor_large(source_pixmap_priv).block_h,
                                             &source_transformed_block_width,
                                             &source_transformed_block_height))
        {
            //mixin(DEBUGF!(`"source block size less than 1, fallback.\n"`));
            RegionTranslate(region, dest.pDrawable.x, dest.pDrawable.y);
            return FALSE;
        }
        fixed_block_width =
            min(fixed_block_width, source_transformed_block_width);
        fixed_block_height =
            min(fixed_block_height, source_transformed_block_height);
        //mixin(DEBUGF!(`"new source block size %d x %d \n"`, `fixed_block_width`,
            //    `fixed_block_height`));
    }

    if (mask_pixmap_priv
        && mask.transform && glamor_pixmap_priv_is_large(mask_pixmap_priv)) {
        int mask_transformed_block_width = void, mask_transformed_block_height = void;

        if (!glamor_get_transform_block_size(mask.transform,
                                             __glamor_large(mask_pixmap_priv).block_w,
                                             __glamor_large(mask_pixmap_priv).block_h,
                                             &mask_transformed_block_width,
                                             &mask_transformed_block_height)) {
            //mixin(DEBUGF!(`"mask block size less than 1, fallback.\n"`));
            RegionTranslate(region, dest.pDrawable.x, dest.pDrawable.y);
            return FALSE;
        }
        fixed_block_width =
            min(fixed_block_width, mask_transformed_block_width);
        fixed_block_height =
            min(fixed_block_height, mask_transformed_block_height);
        //mixin(DEBUGF!(`"new mask block size %d x %d \n"`, `fixed_block_width`,
            //    `fixed_block_height`));
    }

    /*compute the correct block width and height whose transformed source/mask
     *region can fit into one texture.*/
    if (force_clip || fixed_block_width < dest_block_width
        || fixed_block_height < dest_block_height)
        clipped_dest_regions =
            glamor_compute_clipped_regions_ext(dest_pixmap, region,
                                               &n_dest_regions,
                                               fixed_block_width,
                                               fixed_block_height, 0, 0);
    else
        clipped_dest_regions = glamor_compute_clipped_regions(dest_pixmap,
                                                              region,
                                                              &n_dest_regions,
                                                              0, 0, 0);
    //mixin(DEBUGF!(`"dest clipped result %d region: \n"`, `n_dest_regions`));
    if (source_pixmap_priv
        && (source_pixmap_priv == dest_pixmap_priv ||
            source_pixmap_priv == mask_pixmap_priv)
        && glamor_pixmap_priv_is_large(source_pixmap_priv)) {
        /* XXX self-copy... */
        need_free_source_pixmap_priv = source_pixmap_priv;
        source_pixmap_priv = cast(glamor_pixmap_private*) calloc(1, typeof(*source_pixmap_priv).sizeof);
        mixin(BUG_RETURN_VAL!("!source_pixmap_priv", "FALSE"));
        *source_pixmap_priv = *need_free_source_pixmap_priv;
        need_free_source_pixmap_priv = source_pixmap_priv;
    }
    assert(mask_pixmap_priv != dest_pixmap_priv);

    for (i = 0; i < n_dest_regions; i++) {
        //mixin(DEBUGF!(`"dest region %d  idx %d\n"`, `i`,
            //    `clipped_dest_regions[i].block_idx`));
        // DEBUGRegionPrint(clipped_dest_regions[i].region);
        glamor_set_pixmap_fbo_current(dest_pixmap_priv,
                               clipped_dest_regions[i].block_idx);
        if (source_pixmap_priv &&
            glamor_pixmap_priv_is_large(source_pixmap_priv)) {
            if (!source.transform && source_repeat_type != RepeatPad) {
                RegionTranslate(clipped_dest_regions[i].region,
                                x_source - x_dest, y_source - y_dest);
                clipped_source_regions =
                    glamor_compute_clipped_regions(source_pixmap,
                                                   clipped_dest_regions[i].
                                                   region, &n_source_regions,
                                                   source_repeat_type, 0, 0);
                is_normal_source_fbo = 1;
            }
            else {
                clipped_source_regions =
                    glamor_compute_transform_clipped_regions(source_pixmap,
                                                             source.transform,
                                                             clipped_dest_regions
                                                             [i].region,
                                                             &n_source_regions,
                                                             x_source - x_dest,
                                                             y_source - y_dest,
                                                             source_repeat_type,
                                                             0, 0);
                is_normal_source_fbo = 0;
                if (n_source_regions == 0) {
                    /* Pad the out-of-box region to (0,0,0,0). */
                    null_source = 1;
                    n_source_regions = 1;
                }
                else
                    _glamor_process_transformed_clipped_region
                        (source_pixmap, source_pixmap_priv, source_repeat_type,
                         clipped_source_regions, &n_source_regions,
                         &need_clean_source_fbo);
            }
            //mixin(DEBUGF!(`"source clipped result %d region: \n"`, `n_source_regions`));
            for (j = 0; j < n_source_regions; j++) {
                if (is_normal_source_fbo)
                    glamor_set_pixmap_fbo_current(source_pixmap_priv,
                                           clipped_source_regions[j].block_idx);

                if (mask_pixmap_priv &&
                    glamor_pixmap_priv_is_large(mask_pixmap_priv)) {
                    if (is_normal_mask_fbo && is_normal_source_fbo) {
                        /* both mask and source are normal fbo box without transform or repeatpad.
                         * The region is clipped against source and then we clip it against mask here.*/
                        //mixin(DEBUGF!(`"source region %d  idx %d\n"`, `j`,
                            //    `clipped_source_regions[j].block_idx`));
                        // DEBUGRegionPrint(clipped_source_regions[j].region);
                        RegionTranslate(clipped_source_regions[j].region,
                                        -x_source + x_mask, -y_source + y_mask);
                        clipped_mask_regions =
                            glamor_compute_clipped_regions(mask_pixmap,
                                                           clipped_source_regions
                                                           [j].region,
                                                           &n_mask_regions,
                                                           mask_repeat_type, 0,
                                                           0);
                        is_normal_mask_fbo = 1;
                    }
                    else if (is_normal_mask_fbo && !is_normal_source_fbo) {
                        assert(n_source_regions == 1);
                        /* The source fbo is not a normal fbo box, it has transform or repeatpad.
                         * the valid clip region should be the clip dest region rather than the
                         * clip source region.*/
                        RegionTranslate(clipped_dest_regions[i].region,
                                        -x_dest + x_mask, -y_dest + y_mask);
                        clipped_mask_regions =
                            glamor_compute_clipped_regions(mask_pixmap,
                                                           clipped_dest_regions
                                                           [i].region,
                                                           &n_mask_regions,
                                                           mask_repeat_type, 0,
                                                           0);
                        is_normal_mask_fbo = 1;
                    }
                    else {
                        /* This mask region has transform or repeatpad, we need clip it against the previous
                         * valid region rather than the mask region. */
                        if (!is_normal_source_fbo)
                            clipped_mask_regions =
                                glamor_compute_transform_clipped_regions
                                (mask_pixmap, mask.transform,
                                 clipped_dest_regions[i].region,
                                 &n_mask_regions, x_mask - x_dest,
                                 y_mask - y_dest, mask_repeat_type, 0, 0);
                        else
                            clipped_mask_regions =
                                glamor_compute_transform_clipped_regions
                                (mask_pixmap, mask.transform,
                                 clipped_source_regions[j].region,
                                 &n_mask_regions, x_mask - x_source,
                                 y_mask - y_source, mask_repeat_type, 0, 0);
                        is_normal_mask_fbo = 0;
                        if (n_mask_regions == 0) {
                            /* Pad the out-of-box region to (0,0,0,0). */
                            null_mask = 1;
                            n_mask_regions = 1;
                        }
                        else
                            _glamor_process_transformed_clipped_region
                                (mask_pixmap, mask_pixmap_priv, mask_repeat_type,
                                 clipped_mask_regions, &n_mask_regions,
                                 &need_clean_mask_fbo);
                    }
                    //mixin(DEBUGF!(`"mask clipped result %d region: \n"`, `n_mask_regions`));



                    for (k = 0; k < n_mask_regions; k++) {
                        //mixin(DEBUGF!(`"mask region %d  idx %d\n"`, `k`,
                            //    `clipped_mask_regions[k].block_idx`));
                        // DEBUGRegionPrint(clipped_mask_regions[k].region);
                        if (is_normal_mask_fbo) {
                            glamor_set_pixmap_fbo_current(mask_pixmap_priv,
                                                   clipped_mask_regions[k].
                                                   block_idx);
                            //mixin(DEBUGF!(`"mask fbo off %d %d \n"`,
                                //    `__glamor_large(mask_pixmap_priv).box.x1`,
                                //    `__glamor_large(mask_pixmap_priv).box.y1`));
                            //mixin(DEBUGF!(`"start composite mask hasn't transform.\n"`));
                            RegionTranslate(clipped_mask_regions[k].region,
                                            x_dest - x_mask +
                                            dest.pDrawable.x,
                                            y_dest - y_mask +
                                            dest.pDrawable.y);
                            mixin(COMPOSITE_REGION!(`clipped_mask_regions[k].region`));
                        }
                        else if (!is_normal_mask_fbo && !is_normal_source_fbo) {
                            //mixin(DEBUGF!
                                // (`"start composite both mask and source have transform.\n"`));
                            RegionTranslate(clipped_dest_regions[i].region,
                                            dest.pDrawable.x,
                                            dest.pDrawable.y);
                            mixin(COMPOSITE_REGION!(`clipped_dest_regions[i].region`));
                        }
                        else {
                            //mixin(DEBUGF!
                                // (`"start composite only mask has transform.\n"`));
                            RegionTranslate(clipped_source_regions[j].region,
                                            x_dest - x_source +
                                            dest.pDrawable.x,
                                            y_dest - y_source +
                                            dest.pDrawable.y);
                            mixin(COMPOSITE_REGION!(`clipped_source_regions[j].region`));
                        }
                        RegionDestroy(clipped_mask_regions[k].region);
                    }
                    free(clipped_mask_regions);
                    if (null_mask)
                        null_mask = 0;
                    if (need_clean_mask_fbo) {
                        assert(is_normal_mask_fbo == 0);
                        glamor_destroy_fbo(glamor_priv, mask_pixmap_priv.fbo);
                        mask_pixmap_priv.fbo = null;
                        need_clean_mask_fbo = 0;
                    }
                }
                else {
                    if (is_normal_source_fbo) {
                        RegionTranslate(clipped_source_regions[j].region,
                                        -x_source + x_dest + dest.pDrawable.x,
                                        -y_source + y_dest +
                                        dest.pDrawable.y);
                        mixin(COMPOSITE_REGION!(`clipped_source_regions[j].region`));
                    }
                    else {
                        /* Source has transform or repeatPad. dest regions is the right
                         * region to do the composite. */
                        RegionTranslate(clipped_dest_regions[i].region,
                                        dest.pDrawable.x, dest.pDrawable.y);
                        mixin(COMPOSITE_REGION!(`clipped_dest_regions[i].region`));
                    }
                }
                if (clipped_source_regions && clipped_source_regions[j].region)
                    RegionDestroy(clipped_source_regions[j].region);
            }
            free(clipped_source_regions);
            if (null_source)
                null_source = 0;
            if (need_clean_source_fbo) {
                assert(is_normal_source_fbo == 0);
                glamor_destroy_fbo(glamor_priv, source_pixmap_priv.fbo);
                source_pixmap_priv.fbo = null;
                need_clean_source_fbo = 0;
            }
        }
        else {
            if (mask_pixmap_priv &&
                glamor_pixmap_priv_is_large(mask_pixmap_priv)) {
                if (!mask.transform && mask_repeat_type != RepeatPad) {
                    RegionTranslate(clipped_dest_regions[i].region,
                                    x_mask - x_dest, y_mask - y_dest);
                    clipped_mask_regions =
                        glamor_compute_clipped_regions(mask_pixmap,
                                                       clipped_dest_regions[i].
                                                       region, &n_mask_regions,
                                                       mask_repeat_type, 0, 0);
                    is_normal_mask_fbo = 1;
                }
                else {
                    clipped_mask_regions =
                        glamor_compute_transform_clipped_regions
                        (mask_pixmap, mask.transform,
                         clipped_dest_regions[i].region, &n_mask_regions,
                         x_mask - x_dest, y_mask - y_dest, mask_repeat_type, 0,
                         0);
                    is_normal_mask_fbo = 0;
                    if (n_mask_regions == 0) {
                        /* Pad the out-of-box region to (0,0,0,0). */
                        null_mask = 1;
                        n_mask_regions = 1;
                    }
                    else
                        _glamor_process_transformed_clipped_region
                            (mask_pixmap, mask_pixmap_priv, mask_repeat_type,
                             clipped_mask_regions, &n_mask_regions,
                             &need_clean_mask_fbo);
                }

                for (k = 0; k < n_mask_regions; k++) {
                    //mixin(DEBUGF!(`"mask region %d  idx %d\n"`, `k`,
                        //    `clipped_mask_regions[k].block_idx`));
                    // DEBUGRegionPrint(clipped_mask_regions[k].region);
                    if (is_normal_mask_fbo) {
                        glamor_set_pixmap_fbo_current(mask_pixmap_priv,
                                               clipped_mask_regions[k].
                                               block_idx);
                        RegionTranslate(clipped_mask_regions[k].region,
                                        x_dest - x_mask + dest.pDrawable.x,
                                        y_dest - y_mask + dest.pDrawable.y);
                        mixin(COMPOSITE_REGION!(`clipped_mask_regions[k].region`));
                    }
                    else {
                        RegionTranslate(clipped_dest_regions[i].region,
                                        dest.pDrawable.x, dest.pDrawable.y);
                        mixin(COMPOSITE_REGION!(`clipped_dest_regions[i].region`));
                    }
                    RegionDestroy(clipped_mask_regions[k].region);
                }
                free(clipped_mask_regions);
                if (null_mask)
                    null_mask = 0;
                if (need_clean_mask_fbo) {
                    glamor_destroy_fbo(glamor_priv, mask_pixmap_priv.fbo);
                    mask_pixmap_priv.fbo = null;
                    need_clean_mask_fbo = 0;
                }
            }
            else {
                RegionTranslate(clipped_dest_regions[i].region,
                                dest.pDrawable.x, dest.pDrawable.y);
                mixin(COMPOSITE_REGION!(`clipped_dest_regions[i].region`));
            }
        }
        RegionDestroy(clipped_dest_regions[i].region);
    }
    free(clipped_dest_regions);
    free(need_free_source_pixmap_priv);
    free(need_free_mask_pixmap_priv);
    ok = TRUE;
    return ok;
}
