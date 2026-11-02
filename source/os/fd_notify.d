module os.fd_notify;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 *
 * @brief: defines needed for SetNotifyFd() as well as ospoll
 */
 
enum X_NOTIFY_NONE =   0x0;
enum X_NOTIFY_READ =   0x1;
enum X_NOTIFY_WRITE =  0x2;
enum X_NOTIFY_ERROR =  0x4     /* don't need to select for, always reported */;

 /* _XSERVER_INCLUDE_FDNOTIFY_H */
