module xkb.xkbconsts;

// module xkb.xkbconstants;

public:
enum XkbSA_NoAction          = 0x00;
enum XkbSA_SetMods           = 0x01;
enum XkbSA_LatchMods         = 0x02;
enum XkbSA_LockMods          = 0x03;
enum XkbSA_SetGroup          = 0x04;
enum XkbSA_LatchGroup        = 0x05;
enum XkbSA_LockGroup         = 0x06;
enum XkbSA_MovePtr           = 0x07;
enum XkbSA_PtrBtn            = 0x08;
enum XkbSA_LockPtrBtn        = 0x09;
enum XkbSA_SetPtrDflt        = 0x0a;
enum XkbSA_ISLock            = 0x0b;
enum XkbSA_Terminate         = 0x0c;
enum XkbSA_SwitchScreen      = 0x0d;
enum XkbSA_SetControls       = 0x0e;
enum XkbSA_LockControls      = 0x0f;
enum XkbSA_ActionMessage     = 0x10;
enum XkbSA_RedirectKey       = 0x11;
enum XkbSA_DeviceBtn         = 0x12;
enum XkbSA_LockDeviceBtn     = 0x13;
enum XkbSA_DeviceValuator    = 0x14;

enum XkbSA_LastAction        = XkbSA_DeviceValuator;
enum XkbSA_NumActions        = XkbSA_LastAction + 1;