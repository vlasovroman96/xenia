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
import pix.server.dispatcher;
import pix.server.serverGrab;

struct XServer {
	//Sparce array of clients
	Array!ClientPtr clients;
	ClientPtr		serverClient;
	int				currentMaxClients;

	Dispatcher		dispatcher;
	ServerGrabInfo	grabbing;

	void initClients() {
		//for backward compatible
		this.clients.length = MAXCLIENTS;

		this.clients[1..LimitClients] = null;

		this.serverClient = new ClientRec;
		if (!server.serverClient)
			FatalError("couldn't create server client");

		InitClient(server.serverClient, 0, cast(void*) null);

		this.clients[0] = this.serverClient;
		this.currentMaxClients = 1;
	}

	@property 
	auto activeClients() {
		return clients[0..currentMaxClients]
			.filter!(a => a != null);
	}

	alias isGrabbed = grabbing.isGrabbed;
	alias isGrabbedBy = grabbing.isGrabbedBy;
}