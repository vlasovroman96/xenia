module pix.server.dispatcher;

import dix.dixstruct_priv;

struct Dispatcher {
	ClientPtr currentClient; /* Client for the request currently being dispatched */
}