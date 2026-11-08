module os.ospoll;
@nogc nothrow:
extern(C): __gshared:

// private template HasVersion(string versionId) {
// 	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
// }
/*
 * Copyright © 2016 Keith Packard
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

import build.xlibre_server;
import build.dix_config;

import core.stdc.assert_;
import core.stdc.string;
import core.stdc.stdlib;
import core.sys.posix.unistd;

version (Windows) {
import core.sys.windows.winsock2;
}

import os.fd_notify;
import os.xserver_poll;

import os.ospoll;
import common.list;
import core.sys.linux.epoll;

static if (!HAVE_OSPOLL && HasVersion!"HAVE_POLLSET_CREATE") {
import sys.pollset;
enum POLLSET =         1;
enum HAVE_OSPOLL =     1;
}

static if (!HAVE_OSPOLL && HasVersion!"HAVE_PORT_CREATE") {
import port;
import core.sys.posix.poll;
enum PORT =            1;
enum HAVE_OSPOLL =     1;
}

static if (!HAVE_OSPOLL && HasVersion!"HAVE_EPOLL_CREATE1") {
import sys.epoll;
enum EPOLL =           1;
enum HAVE_OSPOLL =     1;
}

static if (!HAVE_OSPOLL) {
import xserver_poll;
enum POLL =            1;
enum HAVE_OSPOLL =     1;
}
else {
    enum POLL = false;
}


static if (POLLSET) {

// pollset-based implementation (as seen on AIX)
struct ospollfd {
    int fd;
    int xevents;
    short revents;
    _ospoll_trigger trigger;
    void function(int fd, int xevents, void* data) @nogc nothrow callback;
    void* data;
};

struct ospoll {
    pollset_t ps;
    ospollfd* fds;
    int num;
    int size;
};

}

// Оригинальная структура триггера из Xorg
struct ospoll_trigger 
{
    int[2] fds; // Пайп для отправки сигнала прерывания (fds[0] - чтение, fds[1] - запись)
}
alias ospoll_trigger_ptr = ospoll_trigger*;

// //--- Прототипы функций управления триггером (extern(C) для совместимости) ---
extern(C):

// Создание и инициализация триггера
// bool ospoll_trigger_create(ospoll_index_ptr ospoll, ospoll_trigger_ptr trigger);

// // Уничтожение триггера и закрытие дескрипторов
// void ospoll_trigger_destroy(ospoll_trigger_ptr trigger);

// // Сам вызов "взвода" триггера (запись байта в пайп), который прерывает epoll_wait
// void ospoll_trigger(ospoll_trigger_ptr trigger);

static if (EPOLL || PORT) {

/* epoll-based implementation */
struct ospollfd {
    int fd;
    int xevents;
    _ospoll_trigger trigger;
    void function(int fd, int xevents, void* data) @nogc nothrow callback;
    void* data;
    XList deleted;
};

struct ospoll {
    int epoll_fd;
    ospollfd** fds;
    int num;
    int size;
    XList deleted;
};

}

static if (POLL) {

/* poll-based implementation */
struct ospollfd {
    short revents;
    ospoll_trigger trigger;
    void function(int fd, int revents, void* data) callback;
    void* data;
};

struct ospoll {
    pollfd* fds;
    ospollfd* osfds;
    int num;
    int size;
    bool changed;
};

}

enum _ospoll_trigger {
    ospoll_trigger_edge,
    ospoll_trigger_level
};

/* Binary search for the specified file descriptor
 *
 * Returns position if found
 * Returns -position - 1 if not found
 */

private int ospoll_find(ospoll* ospoll, int fd)
{
    int lo = 0;
    int hi = ospoll.num - 1;

    while (lo <= hi) {
        int m = (lo + hi) >> 1;
static if (EPOLL || PORT) {
        int t = ospoll.fds[m].fd;
}
static if (POLL || POLLSET) {
        int t = ospoll.fds[m].fd;
}

        if (t < fd)
            lo = m + 1;
        else if (t > fd)
            hi = m - 1;
        else
            return m;
    }
    return -(lo + 1);
}

static if (EPOLL || PORT) {
private void ospoll_clean_deleted(ospoll* ospoll)
{
    foreach(osfd; ospoll.deleted.byEntriesSafe!(ospollfd, "deleted")){
        osfd.deleted.removeFromList();
        free(osfd);
    }
}
}

/* Insert an element into an array
 *
 * base: base address of array
 * num:  number of elements in the array before the insert
 * size: size of each element
 * pos:  position to insert at
 */
pragma(inline, true) private void array_insert(void* base, size_t num, size_t size, size_t pos)
{
    char* b = cast(char*)base;

    memmove(b + (pos+1) * size,
            b + pos * size,
            (num - pos) * size);
}

/* Delete an element from an array
 *
 * base: base address of array
 * num:  number of elements in the array before the delete
 * size: size of each element
 * pos:  position to delete from
 */
pragma(inline, true) private void array_delete(void* base, size_t num, size_t size, size_t pos)
{
    char* b = cast(char*)base;

    memmove(b + pos * size, b + (pos + 1) * size,
            (num - pos - 1) * size);
}


ospoll* ospoll_create()
{
static if (POLLSET) {
    ospoll* ospoll = cast(ospoll*) cast(ospoll*) calloc(1, ospoll.sizeof);

    ospoll.ps = pollset_create(-1);
    if (ospoll.ps < 0) {
        free (ospoll);
        return null;
    }
    return ospoll;
}
static if (PORT) {
    ospoll* ospoll = cast(ospoll*) cast(ospoll*) calloc(1, ospoll.sizeof);

    ospoll.epoll_fd = port_create();
    if (ospoll.epoll_fd < 0) {
        free (ospoll);
        return null;
    }
    xorg_list_init(&ospoll.deleted);
    return ospoll;
}
static if (EPOLL) {
    ospoll* ospoll = cast(ospoll*) cast(ospoll*) calloc(1, ospoll.sizeof);
    if (ospoll is null)
        return null;
    ospoll.epoll_fd = epoll_create1(EPOLL_CLOEXEC);
    if (ospoll.epoll_fd < 0) {
        free (ospoll);
        return null;
    }
    ospoll.deleted.initList();
    return ospoll;
}
static if (POLL) {
    return cast(ospoll*) calloc(1, ospoll.sizeof);
}
}

void ospoll_destroy(ospoll* ospoll)
{
static if (POLLSET) {
    if (ospoll) {
        assert (ospoll.num == 0);
        pollset_destroy(ospoll.ps);
        free(ospoll.fds);
        free(ospoll);
    }
}
static if (EPOLL || PORT) {
    if (ospoll) {
        assert (ospoll.num == 0);
        close(ospoll.epoll_fd);
        ospoll_clean_deleted(ospoll);
        free(ospoll.fds);
        free(ospoll);
    }
}
static if (POLL) {
    if (ospoll) {
        assert (ospoll.num == 0);
        free (ospoll.fds);
        free (ospoll.osfds);
        free (ospoll);
    }
}
}

bool ospoll_add(ospoll* ospoll, int fd, _ospoll_trigger trigger, void function(int fd, int xevents, void* data) @nogc nothrow callback, void* data)
{
    int pos = ospoll_find(ospoll, fd);
static if (POLLSET) {
    if (pos < 0) {
        if (ospoll.num == ospoll.size) {
            ospollfd* new_fds = void;
            int new_size = ospoll.size ? ospoll.size * 2 : MAXCLIENTS * 2;

            new_fds = cast(ospollfd*) realloc(ospoll.fds, new_size * typeof(ospoll.fds[0]).sizeof);
            if (!new_fds)
                return false;
            ospoll.fds = new_fds;
            ospoll.size = new_size;
        }
        pos = -pos - 1;
        array_insert(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        ospoll.num++;

        ospoll.fds[pos].fd = fd;
        ospoll.fds[pos].xevents = 0;
        ospoll.fds[pos].revents = 0;
    }
    ospoll.fds[pos].trigger = trigger;
    ospoll.fds[pos].callback = callback;
    ospoll.fds[pos].data = data;
}
static if (PORT) {
    ospollfd* osfd = void;

    if (pos < 0) {
        osfd = cast(ospollfd*) cast(ospollfd*) calloc(1, ospollfd.sizeof);
        if (!osfd)
            return false;

        if (ospoll.num >= ospoll.size) {
            ospollfd** new_fds = void;
            int new_size = ospoll.size ? ospoll.size * 2 : MAXCLIENTS * 2;

            new_fds = cast(ospollfd**) realloc(ospoll.fds, new_size * typeof(ospoll.fds[0]).sizeof);
            if (!new_fds) {
                free (osfd);
                return false;
            }
            ospoll.fds = new_fds;
            ospoll.size = new_size;
        }

        osfd.fd = fd;
        osfd.xevents = 0;

        pos = -pos - 1;
        array_insert(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        ospoll.fds[pos] = osfd;
        ospoll.num++;
    } else {
        osfd = ospoll.fds[pos];
    }
    osfd.data = data;
    osfd.callback = callback;
    osfd.trigger = trigger;
}
static if (EPOLL) {
    ospollfd* osfd = void;

    if (pos < 0) {

        epoll_event ev = void;

        osfd = cast(ospollfd*) cast(ospollfd*) calloc(1, ospollfd.sizeof);
        if (!osfd)
            return false;

        if (ospoll.num >= ospoll.size) {
            ospollfd** new_fds = void;
            int new_size = ospoll.size ? ospoll.size * 2 : MAXCLIENTS * 2;

            new_fds = cast(ospollfd**) realloc(ospoll.fds, new_size * typeof(ospoll.fds[0]).sizeof);
            if (!new_fds) {
                free (osfd);
                return false;
            }
            ospoll.fds = new_fds;
            ospoll.size = new_size;
        }

        ev.events = 0;
        ev.data.ptr = osfd;
        if (trigger == _ospoll_trigger.ospoll_trigger_edge)
            ev.events |= EPOLLET;
        if (epoll_ctl(ospoll.epoll_fd, EPOLL_CTL_ADD, fd, &ev) == -1) {
            free(osfd);
            return false;
        }
        osfd.fd = fd;
        osfd.xevents = 0;

        pos = -pos - 1;
        array_insert(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        ospoll.fds[pos] = osfd;
        ospoll.num++;
    } else {
        osfd = ospoll.fds[pos];
    }
    osfd.data = data;
    osfd.callback = callback;
    osfd.trigger = trigger;
}
static if (POLL) {
    if (pos < 0) {
        if (ospoll.num == ospoll.size) {
            pollfd* new_fds = void;
            ospollfd* new_osfds = void;
            int new_size = ospoll.size ? ospoll.size * 2 : MAXCLIENTS * 2;

            new_fds = cast(pollfd*) realloc(ospoll.fds, new_size * typeof(ospoll.fds[0]).sizeof);
            if (!new_fds)
                return false;
            ospoll.fds = new_fds;
            new_osfds = cast(ospollfd*) realloc(ospoll.osfds, new_size * typeof(ospoll.osfds[0]).sizeof);
            if (!new_osfds)
                return false;
            ospoll.osfds = new_osfds;
            ospoll.size = new_size;
        }
        pos = -pos - 1;
        array_insert(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        array_insert(ospoll.osfds, ospoll.num, typeof(ospoll.osfds[0]).sizeof, pos);
        ospoll.num++;
        ospoll.changed = true;

        ospoll.fds[pos].fd = fd;
        ospoll.fds[pos].events = 0;
        ospoll.fds[pos].revents = 0;
        ospoll.osfds[pos].revents = 0;
    }
    ospoll.osfds[pos].trigger = trigger;
    ospoll.osfds[pos].callback = callback;
    ospoll.osfds[pos].data = data;
}
    return true;
}

void ospoll_remove(ospoll* ospoll, int fd)
{
    int pos = ospoll_find(ospoll, fd);

    pos = ospoll_find(ospoll, fd);
    if (pos >= 0) {
static if (POLLSET) {
        ospollfd* osfd = &ospoll.fds[pos];
        poll_ctl ctl = { cmd: PS_DELETE, fd: fd };
        pollset_ctl(ospoll.ps, &ctl, 1);

        array_delete(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        ospoll.num--;
}
static if (PORT) {
        ospollfd* osfd = ospoll.fds[pos];
        port_dissociate(ospoll.epoll_fd, PORT_SOURCE_FD, fd);

        array_delete(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        ospoll.num--;
        osfd.callback = null;
        osfd.data = null;
        ospoll.deleted.addListNext(&osfd.deleted);
}
static if (EPOLL) {
        ospollfd* osfd = ospoll.fds[pos];
        epoll_event ev = void;
        ev.events = 0;
        ev.data.ptr = osfd;
        cast(void) epoll_ctl(ospoll.epoll_fd, EPOLL_CTL_DEL, fd, &ev);

        array_delete(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        ospoll.num--;
        osfd.callback = null;
        osfd.data = null;
        ospoll.deleted.addListNext(&osfd.deleted);
}
static if (POLL) {
        array_delete(ospoll.fds, ospoll.num, typeof(ospoll.fds[0]).sizeof, pos);
        array_delete(ospoll.osfds, ospoll.num, typeof(ospoll.osfds[0]).sizeof, pos);
        ospoll.num--;
        ospoll.changed = true;
}
    }
}

static if (PORT) {
private void epoll_mod(ospoll* ospoll, ospollfd* osfd)
{
    int events = 0;
    if (osfd.xevents & X_NOTIFY_READ)
        events |= POLLIN;
    if (osfd.xevents & X_NOTIFY_WRITE)
        events |= POLLOUT;
    port_associate(ospoll.epoll_fd, PORT_SOURCE_FD, osfd.fd, events, osfd);
}
}

static if (EPOLL) {
private void epoll_mod(ospoll* ospoll, ospollfd* osfd)
{
    epoll_event ev = void;
    ev.events = 0;
    if (osfd.xevents & X_NOTIFY_READ)
        ev.events |= EPOLLIN;
    if (osfd.xevents & X_NOTIFY_WRITE)
        ev.events |= EPOLLOUT;
    if (osfd.trigger == _ospoll_trigger.ospoll_trigger_edge)
        ev.events |= EPOLLET;
    ev.data.ptr = osfd;
    cast(void) epoll_ctl(ospoll.epoll_fd, EPOLL_CTL_MOD, osfd.fd, &ev);
}
}

void ospoll_listen(ospoll* ospoll, int fd, int xevents)
{
    int pos = ospoll_find(ospoll, fd);

    if (pos >= 0) {
static if (POLLSET) {
        poll_ctl ctl = { cmd: PS_MOD, fd: fd };
        if (xevents & X_NOTIFY_READ) {
            ctl.events |= POLLIN;
            ospoll.fds[pos].revents &= ~POLLIN;
        }
        if (xevents & X_NOTIFY_WRITE) {
            ctl.events |= POLLOUT;
            ospoll.fds[pos].revents &= ~POLLOUT;
        }
        pollset_ctl(ospoll.ps, &ctl, 1);
        ospoll.fds[pos].xevents |= xevents;
}
static if (EPOLL || PORT) {
        ospollfd* osfd = ospoll.fds[pos];
        osfd.xevents |= xevents;
        epoll_mod(ospoll, osfd);
}
static if (POLL) {
        if (xevents & X_NOTIFY_READ) {
            ospoll.fds[pos].events |= POLLIN;
            ospoll.osfds[pos].revents &= ~POLLIN;
        }
        if (xevents & X_NOTIFY_WRITE) {
            ospoll.fds[pos].events |= POLLOUT;
            ospoll.osfds[pos].revents &= ~POLLOUT;
        }
}
    }
}

void ospoll_mute(ospoll* ospoll, int fd, int xevents)
{
    int pos = ospoll_find(ospoll, fd);

    if (pos >= 0) {
static if (POLLSET) {
        ospollfd* osfd = &ospoll.fds[pos];
        osfd.xevents &= ~xevents;
        poll_ctl ctl = { cmd: PS_DELETE, fd: fd };
        pollset_ctl(ospoll.ps, &ctl, 1);
        if (osfd.xevents) {
            ctl.cmd = PS_ADD;
            if (osfd.xevents & X_NOTIFY_READ) {
                ctl.events |= POLLIN;
            }
            if (osfd.xevents & X_NOTIFY_WRITE) {
                ctl.events |= POLLOUT;
            }
            pollset_ctl(ospoll.ps, &ctl, 1);
        }
}
static if (EPOLL || PORT) {
        ospollfd* osfd = ospoll.fds[pos];
        osfd.xevents &= ~xevents;
        epoll_mod(ospoll, osfd);
}
static if (POLL) {
        if (xevents & X_NOTIFY_READ)
            ospoll.fds[pos].events &= ~POLLIN;
        if (xevents & X_NOTIFY_WRITE)
            ospoll.fds[pos].events &= ~POLLOUT;
}
    }
}


int ospoll_wait(ospoll* ospoll, int timeout)
{
    int nready = void;
static if (POLLSET) {
enum MAX_EVENTS =      256;
    pollfd[MAX_EVENTS] events = void;

    nready = pollset_poll(ospoll.ps, events.ptr, MAX_EVENTS, timeout);
    for (int i = 0; i < nready; i++) {
        pollfd* ev = &events[i];
        int pos = ospoll_find(ospoll, ev.fd);
        ospollfd* osfd = &ospoll.fds[pos];
        short revents = ev.revents;
        short oldevents = osfd.revents;

        osfd.revents = (revents & (POLLIN|POLLOUT));
        if (osfd.trigger == _ospoll_trigger.ospoll_trigger_edge)
            revents &= ~oldevents;
        if (revents) {
            int xevents = 0;
            if (revents & POLLIN)
                xevents |= X_NOTIFY_READ;
            if (revents & POLLOUT)
                xevents |= X_NOTIFY_WRITE;
            if (revents & (~(POLLIN|POLLOUT)))
                xevents |= X_NOTIFY_ERROR;
            osfd.callback(osfd.fd, xevents, osfd.data);
        }
    }
}
static if (PORT) {
enum MAX_EVENTS =      256;
    port_event_t[MAX_EVENTS] events = void;
    uint_t nget = 1;
    timespec_t port_timeout = {
        tv_sec: timeout / 1000,
        tv_nsec: (timeout % 1000) * 1000000
    };

    nready = 0;
    if (port_getn(ospoll.epoll_fd, events.ptr, MAX_EVENTS, &nget, &port_timeout)
        == 0) {
        nready = nget;
    }
    for (int i = 0; i < nready; i++) {
        port_event_t* ev = &events[i];
        ospollfd* osfd = ev.portev_user;
        uint revents = ev.portev_events;
        int xevents = 0;

        if (revents & POLLIN)
            xevents |= X_NOTIFY_READ;
        if (revents & POLLOUT)
            xevents |= X_NOTIFY_WRITE;
        if (revents & (~(POLLIN|POLLOUT)))
            xevents |= X_NOTIFY_ERROR;

        if (osfd.callback)
            osfd.callback(osfd.fd, xevents, osfd.data);

        if (osfd.trigger == ospoll_trigger_level &&
            !osfd.deleted.isEmpty()) {
            epoll_mod(ospoll, osfd);
        }
    }
    ospoll_clean_deleted(ospoll);
}
static if (EPOLL) {
enum MAX_EVENTS =      256;
    epoll_event[MAX_EVENTS] events = void;
    int i = void;

    nready = epoll_wait(ospoll.epoll_fd, events.ptr, MAX_EVENTS, timeout);
    for (i = 0; i < nready; i++) {
        epoll_event* ev = &events[i];
        ospollfd* osfd = cast(ospollfd*)ev.data.ptr;
        uint revents = ev.events;
        int xevents = 0;

        if (revents & EPOLLIN)
            xevents |= X_NOTIFY_READ;
        if (revents & EPOLLOUT)
            xevents |= X_NOTIFY_WRITE;
        if (revents & (~(EPOLLIN|EPOLLOUT)))
            xevents |= X_NOTIFY_ERROR;

        if (osfd.callback)
            osfd.callback(osfd.fd, xevents, osfd.data);
    }
    ospoll_clean_deleted(ospoll);
}
static if (POLL) {
    nready = xserver_poll(ospoll.fds, ospoll.num, timeout);
    ospoll.changed = false;
    if (nready > 0) {
        int f = void;
        for (f = 0; f < ospoll.num; f++) {
            short revents = ospoll.fds[f].revents;
            short oldevents = ospoll.osfds[f].revents;

            ospoll.osfds[f].revents = (revents & (POLLIN|POLLOUT));
            if (ospoll.osfds[f].trigger == _ospoll_trigger.ospoll_trigger_edge)
                revents &= ~oldevents;
            if (revents) {
                int xevents = 0;
                if (revents & POLLIN)
                    xevents |= X_NOTIFY_READ;
                if (revents & POLLOUT)
                    xevents |= X_NOTIFY_WRITE;
                if (revents & (~(POLLIN|POLLOUT)))
                    xevents |= X_NOTIFY_ERROR;
                ospoll.osfds[f].callback(ospoll.fds[f].fd, xevents,
                                          ospoll.osfds[f].data);

                /* Check to see if the arrays have changed, and just go back
                 * around again
                 */
                if (ospoll.changed)
                    break;
            }
        }
    }
}
    return nready;
}

void ospoll_reset_events(ospoll* ospoll, int fd)
{
static if (POLLSET) {
    int pos = ospoll_find(ospoll, fd);

    if (pos < 0)
        return;

    ospoll.fds[pos].revents = 0;
}
static if (PORT) {
    int pos = ospoll_find(ospoll, fd);

    if (pos < 0)
        return;

    epoll_mod(ospoll, ospoll.fds[pos]);
}
static if (POLL) {
    int pos = ospoll_find(ospoll, fd);

    if (pos < 0)
        return;

    ospoll.osfds[pos].revents = 0;
}
}

void* ospoll_data(ospoll* ospoll, int fd)
{
    int pos = ospoll_find(ospoll, fd);

    if (pos < 0)
        return null;
static if (POLLSET) {
    return ospoll.fds[pos].data;
}
static if (EPOLL || PORT) {
    return ospoll.fds[pos].data;
}
static if (POLL) {
    return ospoll.osfds[pos].data;
}
}
