module os.inputthread;
@nogc nothrow:
extern(C): __gshared:
/* inputthread.c -- Threaded generation of input events.
 *
 * Copyright © 2007-2008 Tiago Vignatti <vignatti at freedesktop org>
 * Copyright © 2010 Nokia
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE COPYRIGHT HOLDER(S) OR AUTHOR(S) BE LIABLE FOR ANY CLAIM, DAMAGES OR
 * OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
 * ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
 * OTHER DEALINGS IN THE SOFTWARE.
 *
 * Authors: Fernando Carrijo <fcarrijo at freedesktop org>
 *          Tiago Vignatti <vignatti at freedesktop org>
 */

import build.dix_config;

import core.stdc.stdio;
import core.stdc.errno;
import core.stdc.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.pthread;

import dix.input_priv;
import os.ddx_priv;
import os.log_priv;
import os.ossock;

import dix.inputstr;
import os.osdep;
import os.log;
import os.connection;
import core.sys.posix.fcntl;
import core.sys.posix.sys.types;
import core.sys.posix.sys.ipc;
import core.sys.posix.sys.shm;
import core.sys.posix.sys.mman;
import core.sys.posix.unistd;
import core.sys.posix.sys.stat;
import core.sys.posix.fcntl;
import sigio;
import x11.Xdefs;

static if (INPUTTHREAD) {

Bool InputThreadEnable = true;

/**
 * An input device as seen by the threaded input facility
 */

enum InputDeviceState {
    device_state_added,
    device_state_running,
    device_state_removed
}
alias device_state_added = InputDeviceState.device_state_added;
alias device_state_running = InputDeviceState.device_state_running;
alias device_state_removed = InputDeviceState.device_state_removed;


struct InputThreadDevice {
    XList node;
    NotifyFdProcPtr readInputProc;
    void* readInputArgs;
    int fd;
    InputDeviceState state;
}

/**
 * The threaded input facility.
 *
 * For now, we have one instance for all input devices.
 */
struct InputThreadInfo {
    pthread_t thread;
    XList devs;
    ospoll* fds;
    int readPipe;
    int writePipe;
    Bool changed;
    Bool running;
}


alias sigset_t = core.sys.posix.signal.sigset_t;

private InputThreadInfo* inputThreadInfo;

private int hotplugPipeRead = -1;
private int hotplugPipeWrite = -1;

private int input_mutex_count;

version (PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP) {
private pthread_mutex_t input_mutex = PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP;
} else {
private pthread_mutex_t input_mutex;
private Bool input_mutex_initialized;
}

int in_input_thread()
{
    return inputThreadInfo &&
           pthread_equal(pthread_self(), inputThreadInfo.thread);
}

void input_lock()
{
version (PTHREAD_RECURSIVE_MUTEX_INITIALIZER_NP) {} else {
    if (!input_mutex_initialized) {
        pthread_mutexattr_t mutex_attr = void;

        input_mutex_initialized = True;
        pthread_mutexattr_init(&mutex_attr);
        pthread_mutexattr_settype(&mutex_attr, PTHREAD_MUTEX_RECURSIVE);
        pthread_mutex_init(&input_mutex, &mutex_attr);
    }
}
    pthread_mutex_lock(&input_mutex);
    ++input_mutex_count;
}

void input_unlock()
{
    --input_mutex_count;
    pthread_mutex_unlock(&input_mutex);
}

void input_force_unlock()
{
    if (pthread_mutex_trylock(&input_mutex) == 0) {
        input_mutex_count++;
        /* unlock +1 times for the trylock */
        while (input_mutex_count > 0)
            input_unlock();
    }
}

/**
 * Notify a thread about the availability of new asynchronously enqueued input
 * events.
 *
 * @see WaitForSomething()
 */
private void InputThreadFillPipe(int writeHead)
{
    int ret = void;
    char byte_ = 0;

    do {
        ret = cast(int)write(writeHead, &byte_, 1);
    } while (ret < 0 && ossock_wouldblock(errno));
}

/**
 * Consume eventual notifications left by a thread.
 *
 * @see WaitForSomething()
 * @see InputThreadFillPipe()
 */
private int InputThreadReadPipe(int readHead)
{
    int ret = void; int[10] array = void;

    ret = cast(int)read(readHead, &array, array.sizeof);
    if (ret >= 0)
        return ret;

    if (errno != EAGAIN)
        FatalError("input-thread: draining pipe (%d)", errno);

    return 1;
}

private void InputReady(int fd, int xevents, void* data)
{
    InputThreadDevice* dev = cast(InputThreadDevice*)data;

    input_lock();
    if (dev.state == device_state_running)
        dev.readInputProc(fd, xevents, dev.readInputArgs);
    input_unlock();
}

/**
 * Register an input device in the threaded input facility
 *
 * @param fd File descriptor which identifies the input device
 * @param readInputProc Procedure used to read input from the device
 * @param readInputArgs Arguments to be consumed by the above procedure
 *
 * return 1 if success; 0 otherwise.
 */
int InputThreadRegisterDev(int fd, NotifyFdProcPtr readInputProc, void* readInputArgs)
{
    InputThreadDevice* dev = void;

    if (!inputThreadInfo)
        return SetNotifyFd(fd, readInputProc, X_NOTIFY_READ, readInputArgs);

    input_lock();

    dev = null;
    foreach(old; inputThreadInfo.devs.byEntries!(InputThreadDevice, "node")) {
        if (old.fd == fd && old.state != device_state_removed) {
            dev = old;
            break;
        }
    }

    if (dev) {
        dev.readInputProc = readInputProc;
        dev.readInputArgs = readInputArgs;
    } else {
        dev = cast(InputThreadDevice*) cast(InputThreadDevice*) calloc(1, InputThreadDevice.sizeof);
        if (dev is null) {
            DebugF("input-thread: could not register device\n");
            input_unlock();
            return 0;
        }

        dev.fd = fd;
        dev.readInputProc = readInputProc;
        dev.readInputArgs = readInputArgs;
        dev.state = device_state_added;

        /* Do not prepend, so that any dev->state == device_state_removed
         * with the same dev->fd get processed first. */
        inputThreadInfo.devs.appendList(&dev.node);
    }

    inputThreadInfo.changed = True;

    input_unlock();

    DebugF("input-thread: registered device %d\n", fd);
    InputThreadFillPipe(hotplugPipeWrite);

    return 1;
}

/**
 * Unregister a device in the threaded input facility
 *
 * @param fd File descriptor which identifies the input device
 *
 * @return 1 if success; 0 otherwise.
 */
int InputThreadUnregisterDev(int fd)
{
    InputThreadDevice* dev_ = void;
    Bool found_device = False;

    /* return silently if input thread is already finished (e.g., at
     * DisableDevice time, evdev tries to call this function again through
     * xf86RemoveEnabledDevice) */
    if (!inputThreadInfo) {
        RemoveNotifyFd(fd);
        return 1;
    }

    input_lock();
    foreach(dev; inputThreadInfo.devs.byEntries!(InputThreadDevice, "node")) {
        if (dev.fd == fd) {
            found_device = True;
            dev_ = dev;
            break;
        }
    }

    /* fd didn't match any registered device. */
    if (!found_device) {
        input_unlock();
        return 0;
    }

    dev_.state = device_state_removed;
    inputThreadInfo.changed = True;

    input_unlock();

    InputThreadFillPipe(hotplugPipeWrite);
    DebugF("input-thread: unregistered device: %d\n", fd);

    return 1;
}

private void InputThreadPipeNotify(int fd, int revents, void* data)
{
    /* Empty pending input, shut down if the pipe has been closed */
    if (InputThreadReadPipe(hotplugPipeRead) == 0) {
        inputThreadInfo.running = False;
    }
}

/**
 * The workhorse of threaded input event generation.
 *
 * Or if you prefer: The WaitForSomething for input devices. :)
 *
 * Runs in parallel with the server main thread, listening to input devices in
 * an endless loop. Whenever new input data is made available, calls the
 * proper device driver's routines which are ultimately responsible for the
 * generation of input events.
 *
 * @see InputThreadPreInit()
 * @see InputThreadInit()
 */

private void* InputThreadDoWork(void* arg)
{
    sigset_t set = void;

    /* Don't handle any signals on this thread */
    sigfillset(&set);
    pthread_sigmask(SIG_BLOCK, &set, null);

    ddxInputThreadInit();

    inputThreadInfo.running = True;

version (HAVE_PTHREAD_SETNAME_NP_WITH_TID) {
    pthread_setname_np (pthread_self(), "InputThread");
} else version (HAVE_PTHREAD_SETNAME_NP_WITHOUT_TID) {
    pthread_setname_np ("InputThread");
}

    ospoll_add(inputThreadInfo.fds, hotplugPipeRead,
               _ospoll_trigger.ospoll_trigger_level,
               &InputThreadPipeNotify,
               null);
    ospoll_listen(inputThreadInfo.fds, hotplugPipeRead, X_NOTIFY_READ);

    while (inputThreadInfo.running)
    {
        DebugF("input-thread: %s waiting for devices\n", __FUNCTION__.ptr);

        /* Check for hotplug changes and modify the ospoll structure to suit */
        if (inputThreadInfo.changed) {
            input_lock();
            inputThreadInfo.changed = False;
            foreach(dev; inputThreadInfo.devs.byEntriesSafe!(InputThreadDevice, "node")){
                switch (dev.state) {
                case device_state_added:
                    ospoll_add(inputThreadInfo.fds, dev.fd,
                               _ospoll_trigger.ospoll_trigger_level,
                               &InputReady,
                               dev);
                    ospoll_listen(inputThreadInfo.fds, dev.fd, X_NOTIFY_READ);
                    dev.state = device_state_running;
                    break;
                case device_state_running:
                    break;
                case device_state_removed:
                    ospoll_remove(inputThreadInfo.fds, dev.fd);
                    dev.node.removeFromList();
                    free(dev);
                    break;
                default: break;}
            }
            input_unlock();
        }

        if (ospoll_wait(inputThreadInfo.fds, -1) < 0) {
            if (errno == EINVAL)
                FatalError("input-thread: %s (%s)", __FUNCTION__.ptr, strerror(errno));
            else if (errno != EINTR)
                ErrorF("input-thread: %s (%s)\n", __FUNCTION__.ptr, strerror(errno));
        }

        /* Kick main thread to process the generated input events and drain
         * events from hotplug pipe */
        InputThreadFillPipe(inputThreadInfo.writePipe);
    }

    ospoll_remove(inputThreadInfo.fds, hotplugPipeRead);

    return null;
}

private void InputThreadNotifyPipe(int fd, int mask, void* data)
{
    InputThreadReadPipe(fd);
}

/**
 * Pre-initialize the facility used for threaded generation of input events
 *
 */
void InputThreadPreInit()
{
    int[2] fds = void, hotplugPipe = void;
    int flags = void;

    if (!InputThreadEnable)
        return;

    if (pipe(fds) < 0)
        FatalError("input-thread: could not create pipe");

     if (pipe(hotplugPipe) < 0)
        FatalError("input-thread: could not create pipe");

    inputThreadInfo = cast(InputThreadInfo*) cast(InputThreadInfo*) calloc(1, InputThreadInfo.sizeof);
    if (!inputThreadInfo)
        FatalError("input-thread: could not allocate memory");

    inputThreadInfo.changed = False;

    inputThreadInfo.thread = 0;
    inputThreadInfo.devs.initList();
    inputThreadInfo.fds = ospoll_create();

    /* By making read head non-blocking, we ensure that while the main thread
     * is busy servicing client requests, the dedicated input thread can work
     * in parallel.
     */
    inputThreadInfo.readPipe = fds[0];
    fcntl(inputThreadInfo.readPipe, F_SETFL, O_NONBLOCK);
    flags = fcntl(inputThreadInfo.readPipe, F_GETFD);
    if (flags != -1) {
        flags |= FD_CLOEXEC;
        cast(void)fcntl(inputThreadInfo.readPipe, F_SETFD, flags);
    }
    SetNotifyFd(inputThreadInfo.readPipe, &InputThreadNotifyPipe, X_NOTIFY_READ, null);

    inputThreadInfo.writePipe = fds[1];

    hotplugPipeRead = hotplugPipe[0];
    fcntl(hotplugPipeRead, F_SETFL, O_NONBLOCK);
    flags = fcntl(hotplugPipeRead, F_GETFD);
    if (flags != -1) {
        flags |= FD_CLOEXEC;
        cast(void)fcntl(hotplugPipeRead, F_SETFD, flags);
    }
    hotplugPipeWrite = hotplugPipe[1];

version (linux) {} else { /* Linux does not deal well with renaming the main thread */
version (HAVE_PTHREAD_SETNAME_NP_WITH_TID) {
    pthread_setname_np (pthread_self(), "MainThread");
} else version (HAVE_PTHREAD_SETNAME_NP_WITHOUT_TID) {
    pthread_setname_np ("MainThread");
}
}

}

/**
 * Start the threaded generation of input events. This routine complements what
 * was previously done by InputThreadPreInit(), being only responsible for
 * creating the dedicated input thread.
 *
 */
void InputThreadInit()
{
    pthread_attr_t attr = void;

    /* If the driver hasn't asked for input thread support by calling
     * InputThreadPreInit, then do nothing here
     */
    if (!inputThreadInfo)
        return;

    pthread_attr_init(&attr);

    /* For OSes that differentiate between processes and threads, the following
     * lines have sense. Linux uses the 1:1 thread model. The scheduler handles
     * every thread as a normal process. Therefore this probably has no meaning
     * if we are under Linux.
     */
    if (pthread_attr_setscope(&attr, PTHREAD_SCOPE_SYSTEM) != 0)
        ErrorF("input-thread: error setting thread scope\n");

    DebugF("input-thread: creating thread\n");
    pthread_create(&inputThreadInfo.thread, &attr,
                   &InputThreadDoWork, null);

    pthread_attr_destroy (&attr);
}

/**
 * Stop the threaded generation of input events
 *
 * This function is supposed to be called at server shutdown time only.
 */
void InputThreadFini()
{
    if (!inputThreadInfo)
        return;

    /* Close the pipe to get the input thread to shut down */
    close(hotplugPipeWrite);
    input_force_unlock();
    pthread_join(inputThreadInfo.thread, null);

    foreach(dev; inputThreadInfo.devs.byEntriesSafe!(InputThreadDevice, "node")){
        ospoll_remove(inputThreadInfo.fds, dev.fd);
        free(dev);
    }
    inputThreadInfo.devs.initList();
    ospoll_destroy(inputThreadInfo.fds);

    RemoveNotifyFd(inputThreadInfo.readPipe);
    close(inputThreadInfo.readPipe);
    close(inputThreadInfo.writePipe);
    inputThreadInfo.readPipe = -1;
    inputThreadInfo.writePipe = -1;

    close(hotplugPipeRead);
    hotplugPipeRead = -1;
    hotplugPipeWrite = -1;

    free(inputThreadInfo);
    inputThreadInfo = null;
}

int xthread_sigmask(int how, const(sigset_t)* set, sigset_t* oldset)
{
    return pthread_sigmask(how, set, oldset);
}

} else { /* INPUTTHREAD */

// Bool InputThreadEnable = False;

// void input_lock() {}
// void input_unlock() {}
// void input_force_unlock() {}

// void InputThreadPreInit() {}
// void InputThreadInit() {}
// void InputThreadFini() {}
// int in_input_thread() { return 0; }

// int InputThreadRegisterDev(int fd, NotifyFdProcPtr readInputProc, void* readInputArgs)
// {
//     return SetNotifyFd(fd, readInputProc, X_NOTIFY_READ, readInputArgs);
// }

// int InputThreadUnregisterDev(int fd)
// {
//     RemoveNotifyFd(fd);
//     return 1;
// }

// int xthread_sigmask(int how, const(sigset_t)* set, sigset_t* oldset)
// {
// version (HAVE_SIGPROCMASK) {
//     return sigprocmask(how, set, oldset);
// } else {
//     return 0;
// }
// }

}
