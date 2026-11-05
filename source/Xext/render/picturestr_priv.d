module render.picturestr_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 2000 SuSE, Inc.
 */
 
public import dix.picturestr;
public import include.scrnintstr;
public import render.glyphstr_priv;
public import include.resource;
public import include.privates;
public import render.render;

enum PICT_GRADIENT_STOPTABLE_SIZE = 1024;

// RESTYPE PictureType;
// RESTYPE PictFormatType;
// RESTYPE GlyphSetType;

enum string VERIFY_PICTURE(string pPicture, string pid, string client, string mode) = `{
    int tmprc = dixLookupResourceByType(cast(void**)&(` ~ pPicture ~ `), ` ~ pid ~ `,
	                                PictureType, ` ~ client ~ `, ` ~ mode ~ `);
    if (tmprc != Success)
	return tmprc;
}`;

enum string VERIFY_ALPHA(string pPicture, string pid, string client, string mode) = `{
    if (` ~ pid ~ ` == None) 
	` ~ pPicture ~ ` = null; 
    else { 
	` ~ VERIFY_PICTURE!(pPicture, pid, client, mode) ~ `; 
    } 
} 
`;
Bool AnimCurInit(ScreenPtr pScreen);

int AnimCursorCreate(CursorPtr* cursors, CARD32* deltas, int ncursor, CursorPtr* ppCursor, ClientPtr client, XID cid);

// static if(XINERAMA){
// void PanoramiXRenderInit();
// void PanoramiXRenderReset();
// } /* XINERAMA */

 /* _XSERVER_PICTURESTR_PRIV_H_ */
