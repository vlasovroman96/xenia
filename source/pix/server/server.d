module pix.server.server;

import build.xlibre_server;
import dix.dixstruct_priv;
import std.container.array;
import abi.globals;
import os.osinit;
import dix.dispatch;
import os.log;
import std.algorithm;
import std.range;

struct XServer {
	//Sparce array of clients
	Array!ClientPtr _clients;
	ClientPtr 		serverClient;
	int				currentMaxClients;

	void initClients() {
		//for backward compatible
		this._clients.length = MAXCLIENTS;

		this._clients[1..LimitClients] = null;

		this.serverClient = new ClientRec;
		if (!server.serverClient)
			FatalError("couldn't create server client");

		InitClient(server.serverClient, 0, cast(void*) null);

		this._clients[0] = this.serverClient;
        this.currentMaxClients = 1;
	}
}