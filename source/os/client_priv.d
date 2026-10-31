module os.client_priv;
@nogc nothrow:
extern(C): __gshared:
import core.stdc.config: c_long, c_ulong;
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 * Copyright © 2010 Nokia Corporation and/or its subsidiary(-ies).
 */
 
public import core.sys.posix.sys.types;
public import x11.Xdefs;
// //public import x11.Xfuncproto;

public import dix.callback;
import dix.dixstruct_priv;

/* Client IDs. Use GetClientPid, GetClientCmdName and GetClientCmdArgs
 * instead of accessing the fields directly. */
struct _ClientId {
    pid_t pid;                  /* process ID, -1 if not available */
    const(char)* cmdname;        /* process name, NULL if not available */
    const(char)* cmdargs;        /* process arguments, NULL if not available */
}
alias ClientIdPtr = _ClientId*;

// struct _Client;

/* Initialize and clean up. */
void ReserveClientIds(_Client* client);
void ReleaseClientIds(_Client* client);

/* Determine client IDs for caching. Exported on purpose for
 * extensions such as SELinux. */
pid_t DetermineClientPid(_Client* client);
void DetermineClientCmd(pid_t, const(char)** cmdname, const(char)** cmdargs);

/* Query cached client IDs. Exported on purpose for drivers. */
pid_t GetClientPid(_Client* client);
const(char)* GetClientCmdName(_Client* client);
const(char)* GetClientCmdArgs(_Client* client);

// Bool ClientIsLocal(_Client* client);
XID AuthorizationIDOfClient(_Client* client);
const(char)* ClientAuthorized(_Client* client, uint proto_n, char* auth_proto, uint string_n, char* auth_string);
Bool AddClientOnOpenFD(int fd);
void ListenOnOpenFD(int fd, int noxauth);
// int ReadRequestFromClient(_Client* client);
// int WriteFdToClient(_Client* client, int fd, Bool do_close);
// Bool InsertFakeRequest(_Client* client, char* data, int count);
// void FlushAllOutput();
// void FlushIfCriticalOutputPending();
// void ResetOsBuffers();
// void NotifyParentProcess();
// void CreateWellKnownSockets();
// void CloseWellKnownConnections();

// exported for nvidia driver
// void SetCriticalOutputPending();

/* exported only for DRI module, but should not be used by external drivers */
// void ResetCurrentRequest(_Client* client);

/* stuff for ReplyCallback */
// CallbackListPtr ReplyCallback;
struct ReplyInfoRec {
    ClientPtr client;
    const(void)* replyData;
    c_ulong dataLenBytes; /* actual bytes from replyData + pad bytes */
    c_ulong bytesRemaining;
    Bool startOfReply;
    c_ulong padBytes;     /* pad bytes from zeroed array */
}

 /* _XSERVER_DIX_CLIENT_PRIV_H */
