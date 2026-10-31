module Xext.dpmsproc;
@nogc nothrow:
extern(C): __gshared:
/* Prototypes for functions that the DDX must provide */

 
public import build.dix_config;

public import dix.dixstruct_priv;
// public import Xext.dpms;


// int DPMSSet(ClientPtr client, int level);
Bool DPMSSupported();

// CARD32 DPMSStandbyTime;
// CARD32 DPMSSuspendTime;
// CARD32 DPMSOffTime;
// CARD16 DPMSPowerLevel;
// Bool DPMSEnabled;
// Bool DPMSDisabledSwitch;


