module miext.extinit_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 1996 Thomas E. Dickey <dickey@clark.net>
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
 import build.xlibre_server;

static if(DRI2){
//public import externs.X11.extensions.dri2proto;
// Bool noDRI2Extension;
// void DRI2ExtensionInit();
}

/* required by: the 470 and 390 nvidia DDX drivers */
// Bool  noDamageExtension;

// Bool noDbeExtension;
// Bool noDPMSExtension;
// Bool noGlxExtension;
// Bool noMITShmExtension;
// Bool noRenderExtension;
// Bool noResExtension;
// Bool noRRExtension;
// Bool noScreenSaverExtension;
// Bool noSecurityExtension;
// Bool noSELinuxExtension;
// Bool noShapeExtension;
// Bool noTestExtensions;
// Bool noXFixesExtension;
// Bool noXFree86BigfontExtension;
// Bool noNamespaceExtension;

// Bool PanoramiXExtensionDisabledHack;

// Bool noPseudoramiXExtension;

char* namespaceConfigFile;

// void CompositeExtensionInit();
// // void DamageExtensionInit();
// void DbeExtensionInit();
// void DPMSExtensionInit();
// void GEExtensionInit();
// void GlxExtensionInit();
// void PanoramiXExtensionInit();
// void RRExtensionInit();
// void RecordExtensionInit();
// // void RenderExtensionInit();
// void ResExtensionInit();
// void ScreenSaverExtensionInit();
// void ShapeExtensionInit();
// void ShmExtensionInit();
// void SyncExtensionInit();
// void XCMiscExtensionInit();
// void SecurityExtensionInit();
// void XFree86BigfontExtensionInit();
// void BigReqExtensionInit();
// // void XFixesExtensionInit();
// void XInputExtensionInit();
// void XkbExtensionInit();
// void SELinuxExtensionInit();
// void XTestExtensionInit();
// void XvExtensionInit();
// void XvMCExtensionInit();
// void dri3_extension_init();
// void PseudoramiXExtensionInit();
// void present_extension_init();
// void NamespaceExtensionInit();

 /* _XSERVER_EXTINIT_PRIV_H */
