module os.xserver_poll;
@nogc nothrow:
extern(C): __gshared:

private template HasVersion(string versionId) {
	mixin("version("~versionId~") {enum HasVersion = true;} else {enum HasVersion = false;}");
}
import core.stdc.config: c_long, c_ulong;
/*---------------------------------------------------------------------------*\
  $Id$

  NAME

	poll - select(2)-based poll() emulation function for BSD systems.

  SYNOPSIS
	#include "poll.h"

	struct pollfd
	{
	    int     fd;
	    short   events;
	    short   revents;
	}

	int poll (struct pollfd *pArray, unsigned long n_fds, int timeout)

  DESCRIPTION

	This file, and the accompanying "poll.h", implement the System V
	poll(2) system call for BSD systems (which typically do not provide
	poll()).  Poll() provides a method for multiplexing input and output
	on multiple open file descriptors; in traditional BSD systems, that
	capability is provided by select().  While the semantics of select()
	differ from those of poll(), poll() can be readily emulated in terms
	of select() -- which is how this function is implemented.

  REFERENCES
	Stevens, W. Richard. Unix Network Programming.  Prentice-Hall, 1990.

  NOTES
	1. This software requires an ANSI C compiler.

  LICENSE

  This software is released under the following BSD license, adapted from
  http://opensource.org/licenses/bsd-license.php

  Copyright (c) 1995-2011, Brian M. Clapper
  All rights reserved.

  Redistribution and use in source and binary forms, with or without
  modification, are permitted provided that the following conditions are met:

  * Redistributions of source code must retain the above copyright notice,
    this list of conditions and the following disclaimer.

  * Redistributions in binary form must reproduce the above copyright
    notice, this list of conditions and the following disclaimer in the
    documentation and/or other materials provided with the distribution.

  * Neither the name of the clapper.org nor the names of its contributors
    may be used to endorse or promote products derived from this software
    without specific prior written permission.

  THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS
  IS" AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO,
  THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR
  PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT HOLDER OR
  CONTRIBUTORS BE LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL,
  EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
  PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR
  PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF
  LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
  NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS
  SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.
\*---------------------------------------------------------------------------*/


/*---------------------------------------------------------------------------*\
				 Includes
\*---------------------------------------------------------------------------*/

import build.dix_config;

import core.sys.posix.unistd;			     
import core.sys.posix.sys.types;                      
import core.sys.posix.sys.time;                        
import core.stdc.assert_;                          
import core.stdc.string;
import core.sys.posix.poll : pollfd;        
import core.sys.posix.sys.select : fd_set;  
import core.stdc.stddef;               

import core.stdc.assert_;
import core.stdc.string;
import core.stdc.stdlib;
import core.sys.posix.unistd;
import core.sys.posix.poll;

version (Windows) {
import core.sys.windows.winsock2;
}

import os.fd_notify;
import os.xserver_poll;

import os.ospoll;
import include.list;
import core.sys.linux.epoll;                   

static if (HasVersion!"Windows" && !HasVersion!"Cygwin") {
//import externs.X11.Xwinsock;
}

import os.xserver_poll;

/*---------------------------------------------------------------------------*\
				  Macros
\*---------------------------------------------------------------------------*/

version (MAX) {} else {
enum string MAX(string a,string b) = `((` ~ a ~ `) > (` ~ b ~ `) ? (` ~ a ~ `) : (` ~ b ~ `))`;
}

/*---------------------------------------------------------------------------*\
			     Private Functions
\*---------------------------------------------------------------------------*/

private int map_poll_spec(pollfd* pArray, size_t n_fds, fd_set* pReadSet, fd_set* pWriteSet, fd_set* pExceptSet)
{
    size_t i = void;                      /* loop control */
    pollfd* pCur = void;           /* current array element */
    int max_fd = -1;            /* return value */

    /*
       Map the poll() structures into the file descriptor sets required
       by select().
    */
    for (i = 0, pCur = pArray; i < n_fds; i++, pCur++)
    {
        /* Skip any bad FDs in the array. */

        if (pCur.fd < 0)
            continue;

	if (pCur.events & POLLIN)
	{
	    /* "Input Ready" notification desired. */
	    FD_SET (pCur.fd, pReadSet);
	}

	if (pCur.events & POLLOUT)
	{
	    /* "Output Possible" notification desired. */
	    FD_SET (pCur.fd, pWriteSet);
	}

	if (pCur.events & POLLPRI)
	{
	    /*
	       "Exception Occurred" notification desired.  (Exceptions
	       include out of band data.
	    */
	    FD_SET (pCur.fd, pExceptSet);
	}

	max_fd = mixin(MAX! (`max_fd`, `pCur.fd`));
    }

    return max_fd;
}

private timeval* map_timeout(int poll_timeout, timeval* pSelTimeout)
{
    timeval* pResult = void;

    /*
       Map the poll() timeout value into a select() timeout.  The possible
       values of the poll() timeout value, and their meanings, are:

       VALUE	MEANING

       -1	wait indefinitely (until signal occurs)
        0	return immediately, don't block
       >0	wait specified number of milliseconds

       select() uses a "struct timeval", which specifies the timeout in
       seconds and microseconds, so the milliseconds value has to be mapped
       accordingly.
    */

    assert (pSelTimeout != cast(timeval*) null);

    switch (poll_timeout)
    {
	case -1:
	    /*
	       A NULL timeout structure tells select() to wait indefinitely.
	    */
	    pResult = cast(timeval*) null;
	    break;

	case 0:
	    /*
	       "Return immediately" (test) is specified by all zeros in
	       a timeval structure.
	    */
	    pSelTimeout.tv_sec  = 0;
	    pSelTimeout.tv_usec = 0;
	    pResult = pSelTimeout;
	    break;

	default:
	    /* Wait the specified number of milliseconds. */
	    pSelTimeout.tv_sec  = poll_timeout / 1000; /* get seconds */
	    poll_timeout        %= 1000;                /* remove seconds */
	    pSelTimeout.tv_usec = poll_timeout * 1000; /* get microseconds */
	    pResult = pSelTimeout;
	    break;
    }


    return pResult;
}

private void map_select_results(pollfd* pArray, size_t n_fds, fd_set* pReadSet, fd_set* pWriteSet, fd_set* pExceptSet)
{
    c_ulong i = void;                   /* loop control */
    pollfd* pCur = void;        /* current array element */

    for (i = 0, pCur = pArray; i < n_fds; i++, pCur++)
    {
        /* Skip any bad FDs in the array. */

        if (pCur.fd < 0)
            continue;

	/* Exception events take priority over input events. */

	pCur.revents = 0;
	if (FD_ISSET (pCur.fd, pExceptSet))
	    pCur.revents |= POLLPRI;

	else if (FD_ISSET (pCur.fd, pReadSet))
	    pCur.revents |= POLLIN;

	if (FD_ISSET (pCur.fd, pWriteSet))
	    pCur.revents |= POLLOUT;
    }

    return;
}

/*---------------------------------------------------------------------------*\
			     Public Functions
\*---------------------------------------------------------------------------*/

int xserver_poll(pollfd* pArray, size_t n_fds, int timeout)
{
    fd_set read_descs = void;                          /* input file descs */
    fd_set write_descs = void;                         /* output file descs */
    fd_set except_descs = void;                        /* exception descs */
    timeval stime = void;                       /* select() timeout value */
    int ready_descriptors = void;                   /* function result */
    int max_fd = void;                              /* maximum fd value */
    timeval* pTimeout = void;                   /* actually passed */

    FD_ZERO (&read_descs);
    FD_ZERO (&write_descs);
    FD_ZERO (&except_descs);

    assert (pArray != cast(pollfd*) null);

    /* Map the poll() file descriptor list in the select() data structures. */

    max_fd = map_poll_spec (pArray, n_fds,
			    &read_descs, &write_descs, &except_descs);

    /* Map the poll() timeout value in the select() timeout structure. */

    pTimeout = map_timeout (timeout, &stime);

    /* Make the select() call. */

    ready_descriptors = select (max_fd + 1, &read_descs, &write_descs,
				&except_descs, pTimeout);

    if (ready_descriptors >= 0)
    {
	map_select_results (pArray, n_fds,
			    &read_descs, &write_descs, &except_descs);
    }

    return ready_descriptors;
}
