module pix.server.serverGrab;

import dix.dixstruct_priv;

enum ServerGrabState {
	ServerGrabbed,
	ServerUngrabbed,
    ClientPervious,
	ClientImpervious
}

//TODO: Check for ABI 
struct ServerGrabInfo {
    ClientPtr client;
    ServerGrabState grabstate;
	// CallbackListPtr ServerGrabCallback;
	@nogc nothrow
	bool isGrabbedBy(ClientPtr who) => client == who;

	@nogc nothrow
	bool isGrabbed() => !isGrabbedBy(null);

	@nogc nothrow
	void ungrab() {
		client = null;
	}

	@nogc nothrow
	void grabServer(ClientPtr client, ServerGrabState state)
	in {
		assert(client);
	}
	do {
		this.client = client;
		this.grabstate = state;
	}
}
