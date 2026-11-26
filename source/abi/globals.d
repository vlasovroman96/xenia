module abi.globals;

import dix.dixstruct_priv;
import build.xorg_server;

extern(C): export: __gshared:

ClientPtr[MAXCLIENTS] clients;
ClientPtr serverClient;
int* currentMaxClients;
