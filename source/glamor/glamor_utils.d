module glamor.glamor_utils;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/*
 * Copyright © 2014 Keith Packard
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that copyright
 * notice and this permission notice appear in supporting documentation, and
 * that the name of the copyright holders not be used in advertising or
 * publicity pertaining to distribution of the software without specific,
 * written prior permission.  The copyright holders make no representations
 * about the suitability of this software for any purpose.  It is provided "as
 * is" without express or implied warranty.
 *
 * THE COPYRIGHT HOLDERS DISCLAIM ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL THE COPYRIGHT HOLDERS BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR PERFORMANCE
 * OF THIS SOFTWARE.
 */
import build.dix_config;

import glamor.glamor_priv;
import externs.X11.extensions.renderproto;
import dix.gc;
import dix.dixutils;



alias UINT16_MAX = core.stdc.stdint.UINT16_MAX;

void glamor_solid_boxes(DrawablePtr drawable, BoxPtr box, int nbox, c_ulong fg_pixel)
{
    GCPtr gc = void;
    xRectangle* rect = void;
    int n = void;

    rect = cast(xRectangle*) calloc(nbox, xRectangle.sizeof);
    if (!rect)
        return;
    for (n = 0; n < nbox; n++) {
        rect[n].x = box[n].x1;
        rect[n].y = box[n].y1;
        rect[n].width = cast(ushort)(box[n].x2 - box[n].x1);
        rect[n].height = cast(ushort)(box[n].y2 - box[n].y1);
    }

    gc = GetScratchGC(drawable.depth, drawable.pScreen);
    if (gc) {
        ChangeGCVal[1] vals = void;

        vals[0].val = cast(uint)fg_pixel;
        ChangeGC(null, gc, cast(uint)GCForeground, vals.ptr);
        ValidateGC(drawable, gc);
        gc.ops.PolyFillRect(drawable, gc, nbox, rect);
        FreeScratchGC(gc);
    }
    free(rect);
}

void glamor_solid(PixmapPtr pixmap, int x, int y, int width, int height, c_ulong fg_pixel)
{
    DrawablePtr drawable = &pixmap.drawable;
    GCPtr gc = void;
    ChangeGCVal[1] vals = void;
    xRectangle rect = void;

    vals[0].val = cast(uint)fg_pixel;
    gc = GetScratchGC(drawable.depth, drawable.pScreen);
    if (!gc)
        return;
    ChangeGC(null, gc, cast(uint)GCForeground, vals.ptr);
    ValidateGC(drawable, gc);
    rect.x = cast(short)x;
    rect.y = cast(short)y;
    rect.width = cast(ushort)width;
    rect.height = cast(ushort)height;
    gc.ops.PolyFillRect(drawable, gc, 1, &rect);
    FreeScratchGC(gc);
}

// static if (GLAMOR_PRIV_H) {} else {
// static assert(0, This file can only be included by glamor_priv.h);
// }

public import include.mipict;
public import os.bug_priv;

public import glamor.glamor_prepare;

enum string v_from_x_coord_x(string _xscale_, string _x_) = `( 2 * (` ~ _x_ ~ `) * (` ~ _xscale_ ~ `) - 1.0)`;
enum string v_from_x_coord_y(string _yscale_, string _y_) = `(2 * (` ~ _y_ ~ `) * (` ~ _yscale_ ~ `) - 1.0)`;
enum string t_from_x_coord_x(string _xscale_, string _x_) = `((` ~ _x_ ~ `) * (` ~ _xscale_ ~ `))`;
enum string t_from_x_coord_y(string _yscale_, string _y_) = `((` ~ _y_ ~ `) * (` ~ _yscale_ ~ `))`;

enum string pixmap_priv_get_dest_scale(string pixmap, string _pixmap_priv_, string _pxscale_, string _pyscale_) = `
  {                                                                   
    int _w_ = void, _h_ = void;                                                         
    `~PIXMAP_PRIV_GET_ACTUAL_SIZE!(pixmap,_pixmap_priv_,`_w_`,`_h_`)~`;        
    *(` ~ _pxscale_ ~ `) = 1.0 / _w_;                                            
    *(` ~ _pyscale_ ~ `) = 1.0 / _h_;                                            
   } `;

enum string pixmap_priv_get_scale(string _pixmap_priv_, string _pxscale_, string _pyscale_) = `
   {									
    *(` ~ _pxscale_ ~ `) = 1.0 / (` ~ _pixmap_priv_ ~ `).fbo.width;			
    *(` ~ _pyscale_ ~ `) = 1.0 / (` ~ _pixmap_priv_ ~ `).fbo.height;			
  }`;

enum string PIXMAP_PRIV_GET_ACTUAL_SIZE(string pixmap, string priv, string w, string h) = `
  {								
	if (glamor_pixmap_priv_is_large(` ~ priv ~ `)) {	
		` ~ w ~ ` = ` ~ priv ~ `.box.x2 - ` ~ priv ~ `.box.x1;	
		` ~ h ~ ` = ` ~ priv ~ `.box.y2 - ` ~ priv ~ `.box.y1;	
	} else {						
		` ~ w ~ ` = (` ~ pixmap ~ `).drawable.width;		
		` ~ h ~ ` = (` ~ pixmap ~ `).drawable.height;		
	}							
  }`;

enum string glamor_pixmap_fbo_fix_wh_ratio(string wh, string pixmap, string priv) = `
  {								
	int actual_w = void, actual_h = void;					
	` ~ PIXMAP_PRIV_GET_ACTUAL_SIZE!(pixmap, priv, `actual_w`, `actual_h`) ~ `;	
	` ~ wh ~ `[0] = cast(float)` ~ priv ~ `.fbo.width / actual_w;	
	` ~ wh ~ `[1] = cast(float)` ~ priv ~ `.fbo.height / actual_h;	
	` ~ wh ~ `[2] = 1.0 / ` ~ priv ~ `.fbo.width;			
	` ~ wh ~ `[3] = 1.0 / ` ~ priv ~ `.fbo.height;			
  } `;

enum string pixmap_priv_get_fbo_off(string _priv_, string _xoff_, string _yoff_) = `
   {								
        if ((` ~ _priv_ ~ ` && glamor_pixmap_priv_is_large(` ~ _priv_ ~ `))) { 
		*(` ~ _xoff_ ~ `) = - (` ~ _priv_ ~ `).box.x1;	
		*(` ~ _yoff_ ~ `) = - (` ~ _priv_ ~ `).box.y1;	
	} else {						
		*(` ~ _xoff_ ~ `) = 0;					
		*(` ~ _yoff_ ~ `) = 0;					
	}							
   } `;

enum string xFixedToFloat(string _val_) = `(cast(float)`~xFixedToInt!(_val_) ~`			
			      + (cast(float)`~xFixedFrac!(_val_) ~ ` / 65536.0))`;

enum string glamor_picture_get_matrixf(string _picture_, string _matrix_) = `
  {									
    int _i_ = void;								
    if ((` ~ _picture_ ~ `).transform)						
      {									
	for(_i_ = 0; _i_ < 3; _i_++)					
	  {								
	    (` ~ _matrix_ ~ `)[_i_ * 3 + 0] =					
	      ` ~ xFixedToFloat!(`(`~_picture_ ~ `).transform.matrix[_i_][0]`) ~ `;	
	    (` ~ _matrix_ ~ `)[_i_ * 3 + 1] =					
	      ` ~ xFixedToFloat!(`(` ~ _picture_ ~ `).transform.matrix[_i_][1]`) ~ `;	
	    (` ~ _matrix_ ~ `)[_i_ * 3 + 2] = 
	      ` ~ xFixedToFloat!(`(` ~ _picture_ ~ `).transform.matrix[_i_][2]`) ~ `;	
	  }								
      }									
  } `;

enum string fmod(string x, string w) = `(` ~ x ~ ` - ` ~ w ~ ` * floor(cast(float)` ~ x ~ `/` ~ w ~ `))`;

enum string fmodulus(string x, string w, string c) = `{` ~ c ~ ` = ` ~ fmod!(x, w) ~ `;		
				    ` ~ c ~ ` = ` ~ c ~ ` >= 0 ? ` ~ c ~ ` : ` ~ c ~ ` + ` ~ w ~ `;}	
			`;
/* @x: is current coord
 * @x2: is the right/bottom edge
 * @w: is current width or height
 * @odd: is output value, 0 means we are in an even region, 1 means we are in a
 * odd region.
 * @c: is output value, equal to x mod w. */
enum string fodd_repeat_mod(string x, string x2, string w, string odd, string c) = `
  {						
	float shift = void;				
	` ~ fmodulus!(`(` ~ x ~ `)`, w, c) ~ `; 			
	shift = fabs((` ~ x ~ `) - (` ~ c ~ `));		
	shift = floor(fabs(round(shift)) / ` ~ w ~ `);	
	` ~ odd ~ ` = cast(int)shift & 1;			
	if (` ~ odd ~ ` && (((` ~ x2 ~ ` % ` ~ w ~ `) == 0) &&		
	    round(fabs(` ~ x ~ `)) == ` ~ x2 ~ `))		
		` ~ odd ~ ` = 0;			
  }`;

/* @txy: output value, is the corrected coords.
 * @xy: input coords to be fixed up.
 * @cd: xy mod wh, is a input value.
 * @wh: current width or height.
 * @bxy1,bxy2: current box edge's x1/x2 or y1/y2
 *
 * case 1:
 *  ----------
 *  |  *     |
 *  |        |
 *  ----------
 *  tx = (c - x1) mod w
 *
 *  case 2:
 *     ---------
 *  *  |       |
 *     |       |
 *     ---------
 *   tx = - (c - (x1 mod w))
 *
 *   case 3:
 *
 *   ----------
 *   |        |  *
 *   |        |
 *   ----------
 *   tx = ((x2 mod x) - c) + (x2 - x1)
 **/
enum string __glamor_repeat_reflect_fixup(string txy, string xy,		
				string cd, string wh, string bxy1, string bxy2) = `
  {							
	` ~ cd ~ ` = ` ~ wh ~ ` - ` ~ cd ~ `;					
	if ( ` ~ xy ~ ` >= ` ~ bxy1 ~ ` && ` ~ xy ~ ` < ` ~ bxy2 ~ `) {			
		` ~ cd ~ ` = ` ~ cd ~ ` - ` ~ bxy1 ~ `;				
		` ~ fmodulus!(cd, wh, txy) ~ `;			
	} else	if (` ~ xy ~ ` < ` ~ bxy1 ~ `) {			
		float bxy1_mod = void;				
		` ~ fmodulus!(bxy1, wh, `bxy1_mod`) ~ `;		
		` ~ txy ~ ` = -(` ~ cd ~ ` - bxy1_mod);			
	}						
	else if (` ~ xy ~ ` >= ` ~ bxy2 ~ `)	{			
		float bxy2_mod = void;				
		` ~ fmodulus!(bxy2, wh, `bxy2_mod`) ~ `;		
		if (bxy2_mod == 0)			
			bxy2_mod = ` ~ wh ~ `;			
		` ~ txy ~ ` = (bxy2_mod - ` ~ cd ~ `) + ` ~ bxy2 ~ ` - ` ~ bxy1 ~ `;	
	} else {assert(0); ` ~ txy ~ ` = 0;}			
  }`;

enum string _glamor_repeat_reflect_fixup(string txy, string xy, string cd, string odd,	
				     string wh, string bxy1, string bxy2) = `
  {							
	if (` ~ odd ~ `) {					
		` ~ __glamor_repeat_reflect_fixup!(txy, xy, 	
			cd, wh, bxy1, bxy2) ~ `;		
	} else						
		` ~ txy ~ ` = ` ~ xy ~ ` - ` ~ bxy1 ~ `;			
  }`;

enum string _glamor_get_reflect_transform_coords(string pixmap, string priv, string repeat_type,	
					    string tx1, string ty1, 		
				            string _x1_, string _y1_) = `
  {								
	int odd_x = void, odd_y = void;					
	float c = void, d = void;						
	` ~ fodd_repeat_mod!(_x1_,`` ~ priv ~ `.box.x2`,			
		    `(` ~ pixmap ~ `).drawable.width`,		
		    `odd_x`, `c`) ~ `;					
	` ~ fodd_repeat_mod!(_y1_,	`` ~ priv ~ `.box.y2`,			
		    `(` ~ pixmap ~ `).drawable.height`,		
		    `odd_y`, `d`) ~ `;					
	//DEBUGF("c %f d %f oddx %d oddy %d \n",			
		// c, d, odd_x, odd_y);				
	//DEBUGF("x2 %d x1 %d fbo->width %d \n", ` ~ priv ~ `.box.x2,	
		// ` ~ priv ~ `.box.x1, ` ~ priv ~ `.fbo.width);		
	//DEBUGF("y2 %d y1 %d fbo->height %d \n", ` ~ priv ~ `.box.y2, 	
		// ` ~ priv ~ `.box.y1, ` ~ priv ~ `.fbo.height);		
	` ~ _glamor_repeat_reflect_fixup!(tx1, _x1_, `c`, `odd_x`,	
		`(` ~ pixmap ~ `).drawable.width`,		
		`` ~ priv ~ `.box.x1`, `` ~ priv ~ `.box.x2`) ~ `;			
	` ~ _glamor_repeat_reflect_fixup!(ty1, _y1_, `d`, `odd_y`,	
		`(` ~ pixmap ~ `).drawable.height`,		
		`` ~ priv ~ `.box.y1`, `` ~ priv ~ `.box.y2`) ~ `;			
   }`;

enum string _glamor_get_repeat_coords(string pixmap, string priv, string repeat_type, string tx1,	
				  string ty1, string tx2, string ty2,		
				  string _x1_, string _y1_, string _x2_,		
				  string _y2_, string c, string d, string odd_x, string odd_y) = `
  {								
	if (` ~ repeat_type ~ ` == RepeatReflect) {			
		//DEBUGF("x1 y1 %d %d\n",				
			// ` ~ _x1_ ~ `, ` ~ _y1_ ~ ` );				
		//DEBUGF("width %d box.x1 %d \n",			
		    //    (` ~ pixmap ~ `).drawable.width,	
		    //    ` ~ priv ~ `.box.x1);				
		if (` ~ odd_x ~ `) {					
			` ~ c ~ ` = (` ~ pixmap ~ `).drawable.width	
				- ` ~ c ~ `;				
			` ~ tx1 ~ ` = ` ~ c ~ ` - ` ~ priv ~ `.box.x1;			
			` ~ tx2 ~ ` = ` ~ tx1 ~ ` - ((` ~ _x2_ ~ `) - (` ~ _x1_ ~ `));		
		} else {					
			` ~ tx1 ~ ` = ` ~ c ~ ` - ` ~ priv ~ `.box.x1;			
			` ~ tx2 ~ ` = ` ~ tx1 ~ ` + ((` ~ _x2_ ~ `) - (` ~ _x1_ ~ `));		
		}						
		if (` ~ odd_y ~ `){					
			` ~ d ~ ` = (` ~ pixmap ~ `).drawable.height
			    - ` ~ d ~ `;				
			` ~ ty1 ~ ` = ` ~ d ~ ` - ` ~ priv ~ `.box.y1;			
			` ~ ty2 ~ ` = ` ~ ty1 ~ ` - ((` ~ _y2_ ~ `) - (` ~ _y1_ ~ `));		
		} else {					
			` ~ ty1 ~ ` = ` ~ d ~ ` - ` ~ priv ~ `.box.y1;			
			` ~ ty2 ~ ` = ` ~ ty1 ~ ` + ((` ~ _y2_ ~ `) - (` ~ _y1_ ~ `));		
		}						
	} else { /* RepeatNormal*/				
		` ~ tx1 ~ ` = (` ~ c ~ ` - ` ~ priv ~ `.box.x1);  			
		` ~ ty1 ~ ` = (` ~ d ~ ` - ` ~ priv ~ `.box.y1);			
		` ~ tx2 ~ ` = ` ~ tx1 ~ ` + ((` ~ _x2_ ~ `) - (` ~ _x1_ ~ `));			
		` ~ ty2 ~ ` = ` ~ ty1 ~ ` + ((` ~ _y2_ ~ `) - (` ~ _y1_ ~ `));			
	}							
   }`;

/* _x1_ ... _y2_ may has fractional. */
enum string glamor_get_repeat_transform_coords(string pixmap, string priv, string repeat_type, string tx1, 
					   string ty1, string _x1_, string _y1_) = `
  {									
	//DEBUGF("width %d box.x1 %d x2 %d y1 %d y2 %d\n",		
		// (` ~ pixmap ~ `).drawable.width,			
		// ` ~ priv ~ `.box.x1, ` ~ priv ~ `.box.x2, ` ~ priv ~ `.box.y1,		
		// ` ~ priv ~ `.box.y2);						
	//DEBUGF("x1 %f y1 %f \n", ` ~ _x1_ ~ `, ` ~ _y1_ ~ `);				
	if (` ~ repeat_type ~ ` != RepeatReflect) {				
		` ~ tx1 ~ ` = ` ~ _x1_ ~ ` - ` ~ priv ~ `.box.x1;				
		` ~ ty1 ~ ` = ` ~ _y1_ ~ ` - ` ~ priv ~ `.box.y1;				
	} else			
                ` ~ _glamor_get_reflect_transform_coords!(pixmap, priv, repeat_type, 
				  tx1, ty1, 				
				  _x1_, _y1_) ~ `;				
	//DEBUGF("tx1 %f ty1 %f \n", ` ~ tx1 ~ `, ` ~ ty1 ~ `);				
   }`;

/* _x1_ ... _y2_ must be integer. */
enum string glamor_get_repeat_coords(string pixmap, string priv, string repeat_type, string tx1,		
				 string ty1, string tx2, string ty2, string _x1_, string _y1_, string _x2_,	
				 string _y2_) = `
  {									
	int c = void, d = void;							
	int odd_x = 0, odd_y = 0;					
	//DEBUGF("width %d box.x1 %d x2 %d y1 %d y2 %d\n",		
		// (` ~ pixmap ~ `).drawable.width,			
		// ` ~ priv ~ `.box.x1, ` ~ priv ~ `.box.x2,				
		// ` ~ priv ~ `.box.y1, ` ~ priv ~ `.box.y2);				
	`~modulus!(_x1_ , pixmap ~ `.drawable.width`, `c`) ~`; 	
	`~modulus!(_y1_, pixmap~`.drawable.height`, `d`)~`;	
	//DEBUGF("c %d d %d \n", c, d);					
	if (` ~ repeat_type ~ ` == RepeatReflect) {				
		odd_x = abs((` ~ _x1_ ~ ` - c)					
                            / ((` ~ pixmap ~ `).drawable.width)) & 1;            
		odd_y = abs((` ~ _y1_ ~ ` - d)					
                            / ((` ~ pixmap ~ `).drawable.height)) & 1;           
	}								
	` ~ _glamor_get_repeat_coords!(pixmap, priv, repeat_type, tx1, ty1, tx2, ty2, 
				  _x1_, _y1_, _x2_, _y2_, `c`, `d`,		
				  `odd_x`, `odd_y`) ~ `;			
   }`;

enum string glamor_transform_point(string matrix, string tx, string ty, string x, string y) = `
  {									
    int _i_ = void;								
    float[4] _result_ = void;							
    for (_i_ = 0; _i_ < 3; _i_++) {					
      _result_[_i_] = ` ~ matrix ~ `[_i_ * 3] * `~x~` + ` ~ matrix ~ `[_i_ * 3 + 1] * `~y~`
	+ ` ~ matrix ~ `[_i_ * 3 + 2];					
    }									
    ` ~ tx ~ ` = _result_[0] / _result_[2];					
    ` ~ ty ~ ` = _result_[1] / _result_[2];					
  }`;

enum string _glamor_set_normalize_tpoint(string xscale, string yscale, string _tx_, string _ty_,	
				     string texcoord) = `
  {									
	(` ~ texcoord ~ `)[0] = ` ~ t_from_x_coord_x!(xscale, _tx_) ~ `;			
        (` ~ texcoord ~ `)[1] = ` ~ t_from_x_coord_y!(yscale, _ty_) ~ `;                 
        //DEBUGF("normalized point tx %f ty %f \n", (` ~ texcoord ~ `)[0],	
		// (` ~ texcoord ~ `)[1]);						
  }`;

enum string glamor_set_transformed_point(string priv, string matrix, string xscale,              
				     string yscale, string texcoord,			
                                     string x, string y) = `
  {									
    float tx = void, ty = void;							
    int fbo_x_off = void, fbo_y_off = void;						
    ` ~ pixmap_priv_get_fbo_off!(priv, `&fbo_x_off`, `&fbo_y_off`) ~ `;		
    ` ~ glamor_transform_point!(matrix, `tx`, `ty`, x, y) ~ `;			
    //DEBUGF("tx %f ty %f fbooff %d %d \n",				
	    // tx, ty, fbo_x_off, fbo_y_off);				
									
    tx += fbo_x_off;							
    ty += fbo_y_off;							
    (` ~ texcoord ~ `)[0] = ` ~ t_from_x_coord_x!(xscale, `tx`) ~ `;			
    (` ~ texcoord ~ `)[1] = ` ~ t_from_x_coord_y!(yscale, `ty`) ~ `;                       
    //DEBUGF("normalized tx %f ty %f \n", (` ~ texcoord ~ `)[0], (` ~ texcoord ~ `)[1]);	
  }`;

enum string glamor_set_transformed_normalize_tcoords_ext( string priv,		
						  string matrix,		
						  string xscale,		
						  string yscale,		
                                                  string tx1, string ty1, string tx2, string ty2,   
                                                  string texcoords,		
						  string stride) = `
  {									
    ` ~ glamor_set_transformed_point!(priv, matrix, xscale, yscale,		
				 texcoords, tx1, ty1) ~ `;                  
    ` ~ glamor_set_transformed_point!(priv, matrix, xscale, yscale,		
				 `` ~ texcoords ~ ` + 1 * ` ~ stride ~ ``, tx2, ty1) ~ `;     
    ` ~ glamor_set_transformed_point!(priv, matrix, xscale, yscale,		
				 `` ~ texcoords ~ ` + 2 * ` ~ stride ~ ``, tx2, ty2) ~ `;     
    ` ~ glamor_set_transformed_point!(priv, matrix, xscale, yscale,		
				 `` ~ texcoords ~ ` + 3 * ` ~ stride ~ ``, tx1, ty2) ~ `;     
  }`;

enum string glamor_set_repeat_transformed_normalize_tcoords_ext(string pixmap, string priv, 
							 string repeat_type,	
							 string matrix,	
							 string xscale,	
							 string yscale,	
							 string _x1_, string _y1_,	
							 string _x2_, string _y2_,   	
							 string texcoords,	
							 string stride) = `
  {									
    if ((glamor_pixmap_priv_is_small(` ~ priv ~ `))) {		
	` ~ glamor_set_transformed_normalize_tcoords_ext!(priv, matrix, xscale,	
						 yscale, _x1_, _y1_,	
						 _x2_, _y2_,	
						 texcoords, stride) ~ `;
    } else {								
    float tx1 = void, ty1 = void, tx2 = void, ty2 = void, tx3 = void, ty3 = void, tx4 = void, ty4 = void;			
    float ttx1 = void, tty1 = void, ttx2 = void, tty2 = void, ttx3 = void, tty3 = void, ttx4 = void, tty4 = void;		
    //DEBUGF("original coords %d %d %d %d\n", ` ~ _x1_ ~ `, ` ~ _y1_ ~ `, ` ~ _x2_ ~ `, ` ~ _y2_ ~ `);	
    ` ~ glamor_transform_point!(matrix, `tx1`, `ty1`, _x1_, _y1_) ~ `;		
    ` ~ glamor_transform_point!(matrix, `tx2`, `ty2`, _x2_, _y1_) ~ `;		
    ` ~ glamor_transform_point!(matrix, `tx3`, `ty3`, _x2_, _y2_) ~ `;		
    ` ~ glamor_transform_point!(matrix, `tx4`, `ty4`, _x1_, _y2_) ~ `;		
    //DEBUGF("transformed %f %f %f %f %f %f %f %f\n",			
	//    tx1, ty1, tx2, ty2, tx3, ty3, tx4, ty4);		
    ` ~ glamor_get_repeat_transform_coords!(pixmap, priv, repeat_type, 
				       `ttx1`, `tty1`, 			
				       `tx1`, `ty1`) ~ `;			
    ` ~ glamor_get_repeat_transform_coords!(pixmap, priv, repeat_type, 	
				       `ttx2`, `tty2`, 			
				       `tx2`, `ty2`) ~ `;			
    ` ~ glamor_get_repeat_transform_coords!(pixmap, priv, repeat_type, 	
				       `ttx3`, `tty3`, 			
				       `tx3`, `ty3`) ~ `;			
    ` ~ glamor_get_repeat_transform_coords!(pixmap, priv, repeat_type, 	
				       `ttx4`, `tty4`, 			
				       `tx4`, `ty4`) ~ `;			
    //DEBUGF("repeat transformed %f %f %f %f %f %f %f %f\n", ttx1, tty1, 	
	    // ttx2, tty2,	ttx3, tty3, ttx4, tty4);			
    ` ~ _glamor_set_normalize_tpoint!(xscale, yscale, `ttx1`, `tty1`,		
				 texcoords) ~ `;			
    ` ~ _glamor_set_normalize_tpoint!(xscale, yscale, `ttx2`, `tty2`,		
				 `` ~ texcoords ~ ` + 1 * ` ~ stride ~ ``) ~ `;	
    ` ~ _glamor_set_normalize_tpoint!(xscale, yscale, `ttx3`, `tty3`,		
				 `` ~ texcoords ~ ` + 2 * ` ~ stride ~ ``) ~ `;	
    ` ~ _glamor_set_normalize_tpoint!(xscale, yscale, `ttx4`, `tty4`,		
				 `` ~ texcoords ~ ` + 3 * ` ~ stride ~ ``) ~ `;	
   }									
  } `;

enum string glamor_set_repeat_transformed_normalize_tcoords( string pixmap,        
                                                         string priv,          
							 string repeat_type,	
							 string matrix,	
							 string xscale,	
							 string yscale,	
							 string _x1_, string _y1_,	
							 string _x2_, string _y2_,   	
							 string texcoords) = `
  {									
      ` ~ glamor_set_repeat_transformed_normalize_tcoords_ext!( pixmap,      
                                                           priv,	
							 repeat_type,	
							 matrix,	
							 xscale,	
							 yscale,	
							 _x1_, _y1_,	
							 _x2_, _y2_,   	
							 texcoords,	
							 `2`) ~ `;	
  } while (0)`;

enum string _glamor_set_normalize_tcoords(string xscale, string yscale, string tx1,		
				      string ty1, string tx2, string ty2,			
				      string vertices, string stride) = `
  {									
    /* vertices may be write-only, so we use following			\
     * temporary variable. */ 						
    float _t0_ = void, _t1_ = void, _t2_ = void, _t5_ = void;					
    (` ~ vertices ~ `)[0] = _t0_ = ` ~ t_from_x_coord_x!(xscale, tx1) ~ `;		
    (` ~ vertices ~ `)[1 * ` ~ stride ~ `] = _t2_ = ` ~ t_from_x_coord_x!(xscale, tx2) ~ `;	
    (` ~ vertices ~ `)[2 * ` ~ stride ~ `] = _t2_;					
    (` ~ vertices ~ `)[3 * ` ~ stride ~ `] = _t0_;					
    (` ~ vertices ~ `)[1] = _t1_ = ` ~ t_from_x_coord_y!(yscale, ty1) ~ `;               
    (` ~ vertices ~ `)[2 * ` ~ stride ~ ` + 1] = _t5_ = ` ~ t_from_x_coord_y!(yscale, ty2) ~ `;  
    (` ~ vertices ~ `)[1 * ` ~ stride ~ ` + 1] = _t1_;					
    (` ~ vertices ~ `)[3 * ` ~ stride ~ ` + 1] = _t5_;					
  }`;

enum string glamor_set_normalize_tcoords_ext(string priv, string xscale, string yscale,		
				     string x1, string y1, string x2, string y2,			
                                     string vertices, string stride) = `
  {									
     if (glamor_pixmap_priv_is_large(` ~ priv ~ `)) {		
	float tx1 = void, tx2 = void, ty1 = void, ty2 = void;					
	int fbo_x_off = void, fbo_y_off = void;					
	` ~ pixmap_priv_get_fbo_off!(priv, `&fbo_x_off`, `&fbo_y_off`) ~ `;		
	tx1 = ` ~ x1 ~ ` + fbo_x_off; 						
	tx2 = ` ~ x2 ~ ` + fbo_x_off;						
	ty1 = ` ~ y1 ~ ` + fbo_y_off;						
	ty2 = ` ~ y2 ~ ` + fbo_y_off;						
	` ~ _glamor_set_normalize_tcoords!(xscale, yscale, `tx1`, `ty1`,		
                                      `tx2`, `ty2`, vertices,               
				   stride) ~ `;				
     } else								
	` ~ _glamor_set_normalize_tcoords!(xscale, yscale, x1, y1,		
                                      x2, y2, vertices, stride) ~ `;        
 }`;

enum string glamor_set_repeat_normalize_tcoords_ext(string pixmap, string priv, string repeat_type, 
					    string xscale, string yscale,		
					    string _x1_, string _y1_, string _x2_, string _y2_,	
	                                    string vertices, string stride) = `
  {									
     if ((glamor_pixmap_priv_is_large(` ~ priv ~ `))) {		
	float tx1 = void, tx2 = void, ty1 = void, ty2 = void;					
	if (` ~ repeat_type ~ ` == RepeatPad) {					
		tx1 = ` ~ _x1_ ~ ` - ` ~ priv ~ `.box.x1;			        
		ty1 = ` ~ _y1_ ~ ` - ` ~ priv ~ `.box.y1;			        
		tx2 = tx1 + ((` ~ _x2_ ~ `) - (` ~ _x1_ ~ `));				
		ty2 = ty1 + ((` ~ _y2_ ~ `) - (` ~ _y1_ ~ `));				
	} else {							
            ` ~ glamor_get_repeat_coords!(pixmap, priv, repeat_type,         
				 `tx1`, `ty1`, `tx2`, `ty2`,			
				 _x1_, _y1_, _x2_, _y2_) ~ `;		
	}								
	` ~ _glamor_set_normalize_tcoords!(xscale, yscale, `tx1`, `ty1`,		
                                      `tx2`, `ty2`, vertices,               
				   stride) ~ `;				
     } else								
	` ~ _glamor_set_normalize_tcoords!(xscale, yscale, _x1_, _y1_,	
                                      _x2_, _y2_, vertices,             
				   stride) ~ `;				
 } `;

enum string glamor_set_normalize_tcoords_tri_stripe(string xscale, string yscale,		
						string x1, string y1, string x2, string y2,		
						string vertices) = `
    {								
	(` ~ vertices ~ `)[0] = ` ~ t_from_x_coord_x!(xscale, x1) ~ `;			
	(` ~ vertices ~ `)[2] = ` ~ t_from_x_coord_x!(xscale, x2) ~ `;			
	(` ~ vertices ~ `)[6] = (` ~ vertices ~ `)[2];					
	(` ~ vertices ~ `)[4] = (` ~ vertices ~ `)[0];					
        (` ~ vertices ~ `)[1] = ` ~ t_from_x_coord_y!(yscale, y1) ~ `;                   
        (` ~ vertices ~ `)[7] = ` ~ t_from_x_coord_y!(yscale, y2) ~ `;                   
	(` ~ vertices ~ `)[3] = (` ~ vertices ~ `)[1];					
	(` ~ vertices ~ `)[5] = (` ~ vertices ~ `)[7];					
    }`;

enum string glamor_set_tcoords_tri_strip(string x1, string y1, string x2, string y2, string vertices) = `
    {								
	(` ~ vertices ~ `)[0] = (` ~ x1 ~ `);						
	(` ~ vertices ~ `)[2] = (` ~ x2 ~ `);						
	(` ~ vertices ~ `)[6] = (` ~ vertices ~ `)[2];					
	(` ~ vertices ~ `)[4] = (` ~ vertices ~ `)[0];					
        (` ~ vertices ~ `)[1] = (` ~ y1 ~ `);                                           
        (` ~ vertices ~ `)[7] = (` ~ y2 ~ `);                                           
	(` ~ vertices ~ `)[3] = (` ~ vertices ~ `)[1];					
	(` ~ vertices ~ `)[5] = (` ~ vertices ~ `)[7];					
    }`;

enum string glamor_set_normalize_vcoords_ext(string priv, string xscale, string yscale,		
				     string x1, string y1, string x2, string y2,			
                                         string vertices, string stride) = `
  {									
    int fbo_x_off = void, fbo_y_off = void;						
    /* vertices may be write-only, so we use following			\
     * temporary variable. */						
    float _t0_ = void, _t1_ = void, _t2_ = void, _t5_ = void;					
    ` ~ pixmap_priv_get_fbo_off!(priv, `&fbo_x_off`, `&fbo_y_off`) ~ `;		
    (` ~ vertices ~ `)[0] = _t0_ = ` ~ v_from_x_coord_x!(xscale, `` ~ x1 ~ ` + fbo_x_off`) ~ `;	
    (` ~ vertices ~ `)[1 * ` ~ stride ~ `] = _t2_ = ` ~ v_from_x_coord_x!(xscale,		
					`` ~ x2 ~ ` + fbo_x_off`) ~ `;		
    (` ~ vertices ~ `)[2 * ` ~ stride ~ `] = _t2_;					
    (` ~ vertices ~ `)[3 * ` ~ stride ~ `] = _t0_;					
    (` ~ vertices ~ `)[1] = _t1_ = ` ~ v_from_x_coord_y!(yscale, `` ~ y1 ~ ` + fbo_y_off`) ~ `;    
    (` ~ vertices ~ `)[2 * ` ~ stride ~ ` + 1] = _t5_ =                                 
        ` ~ v_from_x_coord_y!(yscale, `` ~ y2 ~ ` + fbo_y_off`) ~ `;                       
    (` ~ vertices ~ `)[1 * ` ~ stride ~ ` + 1] = _t1_;					
    (` ~ vertices ~ `)[3 * ` ~ stride ~ ` + 1] = _t5_;					
  }`;

enum string glamor_set_normalize_vcoords_tri_strip(string xscale, string yscale,		
					       string x1, string y1, string x2, string y2,		
					       string vertices) = `
    {								
	(` ~ vertices ~ `)[0] = ` ~ v_from_x_coord_x!(xscale, x1) ~ `;			
	(` ~ vertices ~ `)[2] = ` ~ v_from_x_coord_x!(xscale, x2) ~ `;			
	(` ~ vertices ~ `)[6] = (` ~ vertices ~ `)[2];					
	(` ~ vertices ~ `)[4] = (` ~ vertices ~ `)[0];					
        (` ~ vertices ~ `)[1] = ` ~ v_from_x_coord_y!(yscale, y1) ~ `;                   
        (` ~ vertices ~ `)[7] = ` ~ v_from_x_coord_y!(yscale, y2) ~ `;                   
	(` ~ vertices ~ `)[3] = (` ~ vertices ~ `)[1];					
	(` ~ vertices ~ `)[5] = (` ~ vertices ~ `)[7];					
    }`;

enum string glamor_set_normalize_pt(string xscale, string yscale, string x, string y,		
                                string pt) = `
    {							
        (` ~ pt ~ `)[0] = ` ~ t_from_x_coord_x!(xscale, x) ~ `;			
        (` ~ pt ~ `)[1] = ` ~ t_from_x_coord_y!(yscale, y) ~ `;                  
    }`;

enum string glamor_set_circle_centre(string width, string height, string x, string y,	
				 string c) = `
    {						
        (` ~ c ~ `)[0] = cast(float)` ~ x ~ `;				
        (` ~ c ~ `)[1] = cast(float)` ~ y ~ `;				
    }`;

version (ALIGN) {} else { /* FreeBSD already has it */
enum string ALIGN(string i,string m) = `(((` ~ i ~ `) + (` ~ m ~ `) - 1) & ~((` ~ m ~ `) - 1))`;
}
enum string MIN(string a,string b) = `((` ~ a ~ `) < (` ~ b ~ `) ? (` ~ a ~ `) : (` ~ b ~ `))`;
enum string MAX(string a,string b) = `((` ~ a ~ `) > (` ~ b ~ `) ? (` ~ a ~ `) : (` ~ b ~ `))`;

enum string glamor_check_fbo_size(string _glamor_,string _w_, string _h_) = `((` ~ _w_ ~ `) > 0 && (` ~ _h_ ~ `) > 0 
                                                    && (` ~ _w_ ~ `) <= ` ~ _glamor_ ~ `.max_fbo_size  
                                                    && (` ~ _h_ ~ `) <= ` ~ _glamor_ ~ `.max_fbo_size)`;

pragma(inline, true) Bool GLAMOR_PIXMAP_PRIV_HAS_FBO(glamor_pixmap_private* pixmap_priv) {
    mixin(BUG_RETURN_VAL!("pixmap_priv", "FALSE"));
    return pixmap_priv.gl_fbo == GLAMOR_FBO_NORMAL;
}

enum REVERT_NONE =       		0;
enum REVERT_NORMAL =     		1;
enum REVERT_UPLOADING_A1 =		3;

enum SWAP_UPLOADING =	  	2;
enum SWAP_NONE_UPLOADING =	3;

/* borrowed from uxa */
pragma(inline, true) Bool glamor_get_rgba_from_pixel(CARD32 pixel, float* red, float* green, float* blue, float* alpha, CARD32 format)
{
    int rshift = void, bshift = void, gshift = void, ashift = void;

    int rbits = cast(int)PIXMAN_FORMAT_R(format);
    int gbits = cast(int)PIXMAN_FORMAT_G(format);
    int bbits = cast(int)PIXMAN_FORMAT_B(format);
    int abits = cast(int)PIXMAN_FORMAT_A(format);

    if (PIXMAN_FORMAT_TYPE(format) == PIXMAN_TYPE_A) {
        rshift = gshift = bshift = ashift = 0;
    }
    else if (PIXMAN_FORMAT_TYPE(format) == PIXMAN_TYPE_ARGB) {
        bshift = 0;
        gshift = bbits;
        rshift = gshift + gbits;
        ashift = rshift + rbits;
    }
    else if (PIXMAN_FORMAT_TYPE(format) == PIXMAN_TYPE_ABGR) {
        rshift = 0;
        gshift = rbits;
        bshift = gshift + gbits;
        ashift = bshift + bbits;
    }
    else if (PIXMAN_FORMAT_TYPE(format) == PIXMAN_TYPE_BGRA) {
        ashift = 0;
        rshift = abits;
        if (abits == 0)
            rshift = cast(int)(PIXMAN_FORMAT_BPP(format) - (rbits + gbits + bbits));
        gshift = rshift + rbits;
        bshift = gshift + gbits;
    }
    else {
        return FALSE;
    }
enum string COLOR_INT_TO_FLOAT(string _fc_, string _p_, string _s_, string _bits_) = `
  *` ~ _fc_ ~ ` = (((` ~ _p_ ~ `) >> (` ~ _s_ ~ `)) & (( 1 << (` ~ _bits_ ~ `)) - 1))	
    / cast(float)((1<<(` ~ _bits_ ~ `)) - 1);`;

    if (rbits)
        mixin(COLOR_INT_TO_FLOAT!(`red`, `pixel`, `rshift`, `rbits`));
    else
        *red = 0;

    if (gbits)
        mixin(COLOR_INT_TO_FLOAT!(`green`, `pixel`, `gshift`, `gbits`));
    else
        *green = 0;

    if (bbits)
        mixin(COLOR_INT_TO_FLOAT!(`blue`, `pixel`, `bshift`, `bbits`));
    else
        *blue = 0;

    if (abits)
        mixin(COLOR_INT_TO_FLOAT!(`alpha`, `pixel`, `ashift`, `abits`));
    else
        *alpha = 1;

    return TRUE;
}

pragma(inline, true) void glamor_get_rgba_from_color(const(xRenderColor)* color, float* rgba)
{
    rgba[0] = color.red   / cast(float)UINT16_MAX;
    rgba[1] = color.green / cast(float)UINT16_MAX;
    rgba[2] = color.blue  / cast(float)UINT16_MAX;
    rgba[3] = color.alpha / cast(float)UINT16_MAX;
}

pragma(inline, true) Bool glamor_is_large_pixmap(PixmapPtr pixmap)
{
    glamor_pixmap_private* priv = void;

    priv = glamor_get_pixmap_private(pixmap);
    return (glamor_pixmap_priv_is_large(priv));
}

pragma(inline, true) void glamor_make_current(glamor_screen_private* glamor_priv)
{
    if (lastGLContext != glamor_priv.ctx.ctx) {
        lastGLContext = glamor_priv.ctx.ctx;
        glamor_priv.ctx.make_current(&glamor_priv.ctx);
    }
    glamor_priv.dirty = TRUE;
}

pragma(inline, true) void glamor_flush(glamor_screen_private* glamor_priv)
{
    if (glamor_priv.dirty) {
        glamor_make_current(glamor_priv);
        glFlush();
        glamor_priv.dirty = FALSE;
    }
}

pragma(inline, true) BoxRec glamor_no_rendering_bounds()
{
    BoxRec bounds = {
        x1: 0,
        y1: 0,
        x2: MAXSHORT,
        y2: MAXSHORT,
    };

    return bounds;
}

pragma(inline, true) BoxRec glamor_start_rendering_bounds()
{
    BoxRec bounds = {
        x1: MAXSHORT,
        y1: MAXSHORT,
        x2: 0,
        y2: 0,
    };

    return bounds;
}

pragma(inline, true) void glamor_bounds_union_rect(BoxPtr bounds, xRectangle* rect)
{
    bounds.x1 = cast(short)min(bounds.x1, rect.x);
    bounds.y1 = cast(short)min(bounds.y1, rect.y);
    bounds.x2 = cast(short)min(SHRT_MAX, max(bounds.x2, rect.x + rect.width));
    bounds.y2 = cast(short)min(SHRT_MAX, max(bounds.y2, rect.y + rect.height));
}

pragma(inline, true) void glamor_bounds_union_box(BoxPtr bounds, BoxPtr box)
{
    bounds.x1 = cast(short)min(bounds.x1, box.x1);
    bounds.y1 = cast(short)min(bounds.y1, box.y1);
    bounds.x2 = cast(short)max(bounds.x2, box.x2);
    bounds.y2 = cast(short)max(bounds.y2, box.y2);
}

/**
 * Helper function for implementing draws with GL_QUADS on GLES2,
 * where we don't have them.
 */
pragma(inline, true) void glamor_glDrawArrays_GL_QUADS(glamor_screen_private* glamor_priv, uint count)
{
    if (glamor_priv.use_quads) {
        glDrawArrays(GL_QUADS, 0, count * 4);
    } else {
        glamor_gldrawarrays_quads_using_indices(glamor_priv, count);
    }
}

pragma(inline, true) Bool glamor_glsl_has_ints(glamor_screen_private* glamor_priv) {
    return glamor_priv.glsl_version >= 130 || glamor_priv.use_gpu_shader4;
}



