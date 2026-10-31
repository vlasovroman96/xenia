module dix.dixaccess;
@nogc nothrow:
extern(C): __gshared:
/***********************************************************

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL THE
OPEN GROUP BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN
AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN
CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.

******************************************************************/

 
/* These are the access modes that can be passed in the last parameter
 * to several of the dix lookup functions.  They were originally part
 * of the Security extension, now used by XACE.
 *
 * You can or these values together to indicate multiple modes
 * simultaneously.
 */

enum DixUnknownAccess =	0       /* don't know intentions */;
enum DixReadAccess =		(1<<0)  /* inspecting the object */;
enum DixWriteAccess =		(1<<1)  /* changing the object */;
enum DixDestroyAccess =	(1<<2)  /* destroying the object */;
enum DixCreateAccess =		(1<<3)  /* creating the object */;
enum DixGetAttrAccess =	(1<<4)  /* get object attributes */;
enum DixSetAttrAccess =	(1<<5)  /* set object attributes */;
enum DixListPropAccess =	(1<<6)  /* list properties of object */;
enum DixGetPropAccess =	(1<<7)  /* get properties of object */;
enum DixSetPropAccess =	(1<<8)  /* set properties of object */;
enum DixGetFocusAccess =	(1<<9)  /* get focus of object */;
enum DixSetFocusAccess =	(1<<10) /* set focus of object */;
enum DixListAccess =		(1<<11) /* list objects */;
enum DixAddAccess =		(1<<12) /* add object */;
enum DixRemoveAccess =		(1<<13) /* remove object */;
enum DixHideAccess =		(1<<14) /* hide object */;
enum DixShowAccess =		(1<<15) /* show object */;
enum DixBlendAccess =		(1<<16) /* mix contents of objects */;
enum DixGrabAccess =		(1<<17) /* exclusive access to object */;
enum DixFreezeAccess =		(1<<18) /* freeze status of object */;
enum DixForceAccess =		(1<<19) /* force status of object */;
enum DixInstallAccess =	(1<<20) /* install object */;
enum DixUninstallAccess =	(1<<21) /* uninstall object */;
enum DixSendAccess =		(1<<22) /* send to object */;
enum DixReceiveAccess =	(1<<23) /* receive from object */;
enum DixUseAccess =		(1<<24) /* use object */;
enum DixManageAccess =		(1<<25) /* manage object */;
enum DixDebugAccess =		(1<<26) /* debug object */;
enum DixBellAccess =		(1<<27) /* audible sound */;
enum DixPostAccess =		(1<<28) /* post or follow-up call */;

                          /* DIX_ACCESS_H */
