module dix.main;

/* 
 * SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2026, Roman Vlasov
 * Copyright (c) 1991, 1997 Digital Equipment Corporation, Maynard, Massachusetts.
 * Copyright 1987, 1998  The Open Group
 * Copyright 1987 by Digital Equipment Corporation, Maynard, Massachusetts.
 *
 * See COPYING for the full license texts.
 */

//Need secodary cleaning after refactoring
import build.xlibre_server;
import externs.X11.fonts.libxfont2;
import dix.atom;
import dix.cursor_priv;
import dix.registry_priv;
import dix.screensaver_priv;
import dix.selection_priv;
import os.client_priv;
import os.ddx_priv;
import os.serverlock;
import Xext.panoramiXsrv;
import dix.dixfonts;
import os.osinit;
import os.log;
import dix.dix_priv;
import externs.attrs;
import os.connection;
import os.WaitFor;
import mi.miinitext;
import dix.dispatch;
import std.algorithm;
import std.string;
import std.array;

static if(DPMSExtension) {
    import Xext.dpmsproc;
}

int dix_main(string[] args) {
    display = "0";

    //TODO: delete this after CheckUserParameters etc. reworking
    auto argv = args.map!(a => cast(char*)a.toStringz).array;

    InitRegions();

    CheckUserParameters(cast(int)args.length, argv.ptr);

    CheckUserAuthorization();

    ProcessCommandLine(cast(int)args.length, argv.ptr);

        ScreenSaverTime = defaultScreenSaverTime;
        ScreenSaverInterval = defaultScreenSaverInterval;
        ScreenSaverBlanking = defaultScreenSaverBlanking;
        ScreenSaverAllowExposures = defaultScreenSaverAllowExposures;

        InitBlockAndWakeupHandlers();
        /* Perform any operating system dependent initializations you'd like */
        OsInit();

            CreateWellKnownSockets();
            server.initClients();

            // if (!server.serverClient)
            //     FatalError("couldn't create server client");
            // InitClient(server.serverClient, 0, cast(void*) null);

        import abi.globals;
        abi.globals.clients = server.clients.data;
        abi.globals.serverClient = server.serverClient;
        abi.globals.currentMaxClients = &server.currentMaxClients;

        /* clear any existing selections */
        InitSelections();

        /* Initialize privates before first allocation */
        dixResetPrivates();

        /* Initialize server client devPrivates, to be reallocated as
         * more client privates are registered
         */
        if (!dixAllocatePrivates(&server.serverClient.devPrivates, PRIVATE_CLIENT))
            FatalError("failed to create server client privates");

        if (!InitClientResources(server.serverClient)) /* for root resources */
            FatalError("couldn't init server resources");

        HWEventQueueType[2] alwaysCheckForInput = [ 0, 1 ];
        SetInputCheck(&alwaysCheckForInput[0], &alwaysCheckForInput[1]);
        screenInfo.numScreens = 0;

        atomMgr.initAtoms();
        InitEvents();
        assumeNoGC(&xfont2_init_glyph_caching)();
        dixResetRegistry();
        InitFonts();
        InitCallbackManager();
        InitOutput(cast(int)args.length, argv.ptr);

        if (screenInfo.numScreens < 1)
            FatalError("no screens found");
        LogMessageVerb(X_INFO, 1, "Output(s) initialized\n");

        InitExtensions(cast(int)args.length, argv.ptr);
        LogMessageVerb(X_INFO, 1, "Extensions initialized\n");

        mixin(DIX_FOR_EACH_GPU_SCREEN!("{
            if (!PixmapScreenInit(walkScreen))
                FatalError(\"failed to create screen pixmap properties\");
            if (!dixScreenRaiseCreateResources(walkScreen))
                FatalError(\"failed to create screen resources\");
        }"));

        /* Let all screens register the necessary privates */
    
        mixin(DIX_FOR_EACH_SCREEN!("{
            if (!PixmapScreenInit(walkScreen))
                FatalError(\"failed to create screen pixmap properties\");
            if (!dixScreenRaiseCreateResources(walkScreen))
                FatalError(\"failed to create screen resources\");
        }"));

        /* Then use these privates to initialize root windows etc */

        mixin(DIX_FOR_EACH_SCREEN!("{
            if (!CreateGCperDepth(walkScreen))
                FatalError(\"failed to create scratch GCs\");
            if (!CreateDefaultStipple(walkScreen))
                FatalError(\"failed to create default stipple\");
            if (!CreateRootWindow(walkScreen))
                FatalError(\"failed to create root window\");
            CallCallbacks(&RootWindowFinalizeCallback, walkScreen);
        }"));

        if (SetDefaultFontPath(defaultFontPath) != Success) {
            ErrorF("[dix] failed to set default font path '%s'",
                   defaultFontPath);
        }
        if (!SetDefaultFont("fixed")) {
            FatalError("could not open default font");
        }

        if (((rootCursor = CreateRootCursor()) is null)) {
            FatalError("could not open default cursor font");
        }

        rootCursor = RefCursor(rootCursor);

static if(XINERAMA){
//         /*
//          * Consolidate window and colourmap information for each screen
//          */
        if (!noPanoramiXExtension)
            PanoramiXConsolidate();
} /* XINERAMA */

        mixin(DIX_FOR_EACH_SCREEN!("{
            walkScreen.root.initRootWindow();
            CallCallbacks(&PostInitRootWindowCallback, walkScreen);
        }"));

        LogMessageVerb(X_INFO, 1, "Screen(s) initialized\n");

        InitCoreDevices();
        InitInput(cast(int)args.length, argv.ptr);
        InitAndStartDevices();
        LogMessageVerb(X_INFO, 1, "Input(s) initialized\n");

        ReserveClientIds(server.serverClient);

        dixSaveScreens(server.serverClient, SCREEN_SAVER_FORCER, ScreenSaverReset);

        dixCloseRegistry();

static if(XINERAMA) {
        if (!noPanoramiXExtension) {
            if (!PanoramiXCreateConnectionBlock()) {
                FatalError("could not create connection block info");
            }
        }
        else/* XINERAMA */
        {
            if (!CreateConnectionBlock()) {
                FatalError("could not create connection block info");
            }
        }

}
else {
            if (!CreateConnectionBlock()) {
                FatalError("could not create connection block info");
            }
}

        NotifyParentProcess();

        InputThreadInit();

        Dispatch();

        UnrefCursor(rootCursor);

        UndisplayDevices();
        DisableAllDevices();

        /* Now free up whatever must be freed */
        if (screenIsSaved == SCREEN_SAVER_ON)
            dixSaveScreens(server.serverClient, SCREEN_SAVER_OFF, ScreenSaverReset);
        FreeScreenSaverTimer();
        CloseDownExtensions();

static if(XINERAMA){
        {
            Bool remember_it = noPanoramiXExtension;

            noPanoramiXExtension = True;
            FreeAllResources();
            noPanoramiXExtension = remember_it;
        }
} else {
        FreeAllResources();
} /* XINERAMA */

        CloseInput();

        InputThreadFini();

        mixin(DIX_FOR_EACH_SCREEN!("{ walkScreen.root = NullWindow; }"));

        CloseDownDevices();

        CloseDownEvents();

        if (screenInfo.numGPUScreens > 0) {
            for (int walkScreenIdx = screenInfo.numGPUScreens - 1; walkScreenIdx >= 0; walkScreenIdx--) {
                ScreenPtr walkScreen = screenInfo.gpuscreens[walkScreenIdx];
                dixFreeScreen(walkScreen);
                screenInfo.numGPUScreens = walkScreenIdx;
            }
        }
        memset(&screenInfo.gpuscreens, 0, typeof(screenInfo.gpuscreens).sizeof);

        if (screenInfo.numScreens > 0) {
            for (int walkScreenIdx = screenInfo.numScreens - 1; walkScreenIdx >= 0; walkScreenIdx--) {
                ScreenPtr walkScreen = screenInfo.screens[walkScreenIdx];
                dixFreeScreen(walkScreen);
                screenInfo.numScreens = walkScreenIdx;
            }
        }
        memset(&screenInfo.screens, 0, typeof(screenInfo.screens).sizeof);

        ReleaseClientIds(server.serverClient);
        dixFreePrivates(server.serverClient.devPrivates, PRIVATE_CLIENT);
        server.serverClient.devPrivates = null;

	dixFreeRegistry();

        FreeFonts();

        atomMgr.freeAllAtoms();

        FreeAuditTimer();

        DeleteCallbackManager();

        ClearWorkQueue();

        CloseWellKnownConnections();
        UnlockServer();

        ddxGiveUp(EXIT_NO_ERROR);

        free(ConnectionInfo);
        ConnectionInfo = null;

    return 0;
}
