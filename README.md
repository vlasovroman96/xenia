# Xenia

An ongoing effort to port the XLibre/Xorg X server from C to D.

<img width="1920" height="1080" alt="Снимок экрана_2026-10-14_10-36-50" src="https://github.com/user-attachments/assets/20688709-7e8e-4c2b-9fc0-4140bb8d0362" />
Xenia X server (xfce4-session) on real machine+Arch Linux with Firefox and a terminal.

## Project Goal

The primary goal is to rewrite the reference implementation of an X11 server in D while preserving compatibility with the existing X11 ecosystem.

## Current Stage

The port itself is largely complete: all of the priority source code has been ported to D. The project is currently in the stabilization phase, where the correctness of the resulting implementation is being verified and the bugs that have been found are being fixed.

## Plans

Once stabilization is complete, the plan is to gradually refactor the ported D-like-C code into idiomatic D, making full use of the language's capabilities. The idea is that this should improve not only the project's structure and maintainability, but eventually its overall architecture as well.

## Compiling and Running

1. See *Known Problems* below.
2. Try `dub build`. Other steps may depend on your environment, operating system, and other factors.

## Known Problems

* I **ABSOLUTELY** do not recommend that you try this on your main machine. Seriously, **DON'T DO IT**.
* Compiling and running the server in a VM is **VIOLENCE**.

  For example, you may need to install various libraries and dependencies (see the XLibre/Xorg documentation), as well as the `xlibre-video-vmware` driver **(Xenia is based on the XLibre 2.1.9 codebase)** with the patches from [this issue](https://github.com/X11Libre/xf86-video-vmware/issues/21).

  In the future, I'm planning to stabilize the build system.

* That said, the current state of the source code is, to put it mildly, worse than terrible.

  The `source` directory is essentially a clone of the XLibre repository that has been processed through `ctod`, followed by **FIVE** (5!!!) months of manual work to get the resulting code into a compilable state. For the most part, it is currently just a somewhat rough, almost literal translation of the C code into D, which is exactly what it is at this stage. As a result, many of the peculiarities of the original C implementation have been preserved. For example, the code contains a huge amount of commented-out, duplicated, and effectively dead code. Some subsystems are currently disabled and have not yet been ported.

* In addition, there is currently no proper build infrastructure to speak of: many parameters that would normally be handled by a build system or configuration are, for the time being, literally hard-coded into the source.

  This is another consequence of prioritizing the port itself and getting the server into a working state rather than building convenient infrastructure and cleaning up the code.

* Some parts of the server, such as *kdrive*, *xnest*, and other additional components, have not yet been ported.

  The original `xfree86` implementation was given priority, since porting the additional components at this stage would have required a significant amount of time.

* Some OS-dependent components have also not yet been ported, particularly those for which I do not have the corresponding hardware configuration needed for proper testing.

  In the future, the system-dependent portion is planned to be moved into a completely separate layer.
