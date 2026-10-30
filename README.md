# Xenia

An ongoing effort to port the XLibre/Xorg X server from C to D.

<img width="1920" height="1080" alt="Снимок экрана_2026-10-14_10-36-50" src="https://github.com/user-attachments/assets/20688709-7e8e-4c2b-9fc0-4140bb8d0362" />

Xenia running XFCE on real hardware with AMD GPU acceleration.

## Project Goal

The primary goal is to port the reference implementation of an X11 server to D while preserving compatibility with the existing X11 ecosystem. After stabilization, the codebase will be gradually refactored to use idiomatic D and modern programming practices.

## Current Stage

The port itself is largely complete: all of the priority source code has been ported to D.

| Part of xserver | State |
|--|--|
| XFree86 | Ready |
| Xnest | Ported, not included in the build yet
| kdrive | Ported, not included in the build yet
| Xwin | Ported, not included in the build yet
| Xquartz | Ported, not included in the build yet

The following desktop environments have been tested:

| Tested DE | State |
|--|--|
| Plasma | Works |
| Cinnamon | Works 
| XFCE | Works 
|MATE| Works


## Plans

Once stabilization is complete, the plan is to gradually refactor the ported D-like-C code into idiomatic D, making full use of the language's capabilities. The idea is that this should improve not only the project's structure and maintainability, but eventually its overall architecture as well.

## Compiling and Running

1. `git clone https://github.com/vlasovroman96/xenia` 
2. `cd xenia`
3. `dub build`
4. You may need to install additional dependencies to build successfully. Check the documentation for your OS and environment.

## Testing 

## Testing

1. Log out of your current desktop environment.
2. Switch to a TTY and start Xenia:

   ```sh
   cd xenia
   ./xenia
   ```

   Leave Xenia running.

3. Switch to another TTY or connect via SSH.
4. Set the display used by Xenia:

   ```sh
   export DISPLAY=:0
   ```

5. Start the desktop environment you want to test:

   | Desktop environment | Command |
   |---|---|
   | KDE Plasma(only 6.7+) | `dbus-run-session -- startplasma-x11` |
   | Cinnamon | `dbus-run-session -- cinnamon-session` |
   | Xfce | `dbus-run-session -- startxfce4` |
   | MATE | `dbus-run-session -- mate-session` |
   | LXQt | `dbus-run-session -- startlxqt` |

   Replace `:0` with the actual display number if necessary.


## Known Problems
* I don't have access to enough hardware configurations to test Xenia thoroughly, so there may be bugs I haven't caught.
* Compiling and running the server in a VM is **VIOLENCE**.

  For example, you may need to install various libraries and dependencies (see the XLibre/Xorg documentation), as well as the `xlibre-video-vmware` driver **(Xenia is based on the XLibre 25.1.0 codebase)** with the patches from [this issue](https://github.com/X11Libre/xf86-video-vmware/issues/21).

  In the future, I'm planning to stabilize the build system.

* That said, the current state of the source code is, to put it mildly, worse than terrible.

  The `source` directory is essentially a clone of the XLibre repository that has been processed through `ctod`, followed by **FIVE** (5!!!) months of manual work to get the resulting code into a compilable state. For the most part, it is currently just a somewhat rough, almost literal translation of the C code into D, which is exactly what it is at this stage. As a result, many of the peculiarities of the original C implementation have been preserved. For example, the code contains a huge amount of commented-out, duplicated, and effectively dead code. Some subsystems are currently disabled and have not yet been ported.

* In addition, there is currently no proper build infrastructure to speak of: many parameters that would normally be handled by a build system or configuration are, for the time being, literally hard-coded into the source.

  This is another consequence of prioritizing the port itself and getting the server into a working state rather than building convenient infrastructure and cleaning up the code.

* The original `xfree86` implementation was given priority, since porting the additional components at this stage would have required a significant amount of time.

* Some OS-dependent components have also not yet been ported, particularly those for which I do not have the corresponding hardware configuration needed for proper testing.

  In the future, the system-dependent portion is planned to be moved into a completely separate layer.
