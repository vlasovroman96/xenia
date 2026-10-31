module dix.request_priv;
@nogc nothrow:
extern(C): __gshared:
/* SPDX-License-Identifier: MIT OR X11
 *
 * Copyright © 2024 Enrico Weigelt, metux IT consult <info@metux.net>
 */
 
//public import x11.Xproto;

public import dix.rpcbuf_priv; /* x_rpcbuf_t */
public import dix.dixstruct_priv;
public import include.misc;    /* bytes_to_int32 */
public import include.os;      /* WriteToClient */
import dix.request_priv;
import os.io;

enum string REQUEST(alias type) = 
    type.stringof ~`* stuff = cast(`~type.stringof~`*)client.requestBuffer;`;

enum string REQUEST_SIZE_MATCH(string req) = ` 
        if (((`~req~`).sizeof >> 2) != client.req_len)                      
            return(BadLength); `;

enum string REQUEST_AT_LEAST_SIZE(alias req) = `
    {                                                                
        if ((`~req.stringof~`.sizeof >> 2) > client.req_len)                      
            return(BadLength);                                          
    }`;

enum string REQUEST_AT_LEAST_EXTRA_SIZE(string req, string extra) = `                                                            
        if ((((` ~ req ~ `).sizeof + (cast(ulong) (` ~ extra ~ `))) >> 2) > client.req_len) 
            return(BadLength);                                          `
            ;

enum string REQUEST_FIXED_SIZE(string req, string n) = `                                  
        if ((((` ~ req~`).sizeof >> 2) > client.req_len) ||            
            (((` ~ n ~ `) >> 2) >= client.req_len) ||                         
            (((cast(ulong) (` ~ req ~ `).sizeof + (` ~ n ~ `) + 3) >> 2) != cast(ulong) client.req_len)) 
            return(BadLength);                                          
`;
/*
 * @brief write rpc buffer to client and then clear it
 *
 * @param pClient the client to write buffer to
 * @param rpcbuf  the buffer whose contents will be written
 * @return the result of WriteToClient() call
 */
pragma(inline, true) private ssize_t WriteRpcbufToClient(ClientPtr pClient, x_rpcbuf_t* rpcbuf) {
    /* explicitly casting between (s)size_t and int - should be safe,
       since payloads are always small enough to easily fit into int. */
    ssize_t ret = WriteToClient(pClient,
                                cast(int)rpcbuf.wpos,
                                rpcbuf.buffer);
    x_rpcbuf_clear(rpcbuf);
    return ret;
}

int __write_reply_hdr_simple(ClientPtr pClient, void* hdrData, size_t hdrLen)
{
    xGenericReply* reply = cast(xGenericReply*)hdrData;
    reply.type = X_Reply;
    reply.length = (bytes_to_int32(hdrLen - xGenericReply.sizeof));
    reply.sequenceNumber = cast(CARD16)pClient.sequence; /* shouldn't go above 64k */

    if (pClient.swapped) {
         swaps(&reply.sequenceNumber);
         swapl(&reply.length);
    }

    WriteToClient(pClient, cast(int)hdrLen, hdrData);
    return Success;
}

/* compute the amount of extra units a reply header needs.
 *
 * all reply header structs are at least the size of xGenericReply
 * we have to count how many units the header is bigger than xGenericReply
 *
 */
enum string X_REPLY_HEADER_UNITS(string hdrtype) = `
    (bytes_to_int32((((` ~ hdrtype ~ `).sizeof - xGenericReply.sizeof))))`;

pragma(inline, true) int __write_reply_hdr_and_rpcbuf(ClientPtr pClient, void* hdrData, size_t hdrLen, x_rpcbuf_t* rpcbuf)
{
    if (rpcbuf.error)
        return BadAlloc;

    xGenericReply* reply = cast(xGenericReply*)hdrData;
    reply.type = X_Reply;
    reply.length = (bytes_to_int32(hdrLen - xGenericReply.sizeof))
                  + x_rpcbuf_wsize_units(rpcbuf);
    reply.sequenceNumber = cast(CARD16)pClient.sequence; /* shouldn't go above 64k */

    if (pClient.swapped) {
         swaps(&reply.sequenceNumber);
         swapl(&reply.length);
    }

    WriteToClient(pClient, cast(int)hdrLen, hdrData);
    WriteRpcbufToClient(pClient, rpcbuf);

    return Success;
}

// pragma(inline, true) private int __write_reply_hdr_simple(ClientPtr pClient, void* hdrData, size_t hdrLen)
// {
//     xGenericReply* reply = hdrData;
//     reply.type = X_Reply;
//     reply.length = (bytes_to_int32(hdrLen - xGenericReply.sizeof));
//     reply.sequenceNumber = cast(CARD16)pClient.sequence; /* shouldn't go above 64k */

//     if (pClient.swapped) {
//          swaps(&reply.sequenceNumber);
//          swapl(&reply.length);
//     }

//     WriteToClient(pClient, cast(int)hdrLen, hdrData);
//     return Success;
// }

/*
 * send reply with header struct (not pointer!) along with rpcbuf payload
 *
 * @param client      pointer to the client (ClientPtr)
 * @param hdrstruct   the header struct (not pointer, the struct itself!)
 * @param rpcbuf      the rpcbuf to send (not pointer, the struct itself!)
 * return             X11 result code
 */
enum string X_SEND_REPLY_WITH_RPCBUF(string client, string hdrstruct, string rpcbuf) = `
    __write_reply_hdr_and_rpcbuf(` ~ client ~ `, &(` ~ hdrstruct ~ `), ` ~ hdrstruct ~ `.sizeof, &(` ~ rpcbuf ~ `))`;

/*
 * send reply with header struct (not pointer!) without any payload
 *
 * @param client      pointer to the client (ClientPtr)
 * @param hdrstruct   the header struct (not pointer, the struct itself!)
 * @return            X11 result code (=Success)
 */
enum string X_SEND_REPLY_SIMPLE(string client, string hdrstruct) = `
    __write_reply_hdr_simple(` ~ client ~ `, &(` ~ hdrstruct ~ `), ` ~ hdrstruct ~ `.sizeof)`;

/*
 * macros for request handlers
 *
 * these are handling request packet checking and swapping of multi-byte
 * values, if necessary. (length field is already swapped earlier)
 */

enum string X_REQUEST_HEAD_STRUCT(alias T) =
    q{
        auto stuff = cast(} ~ T.stringof ~ q{*)client.requestBuffer;

        if (stuff is null)
            return BadLength;

        if (client.req_len < (} ~ T.stringof ~ q{.sizeof >> 2))
            return BadLength;
    };

/* declare request struct and check size (at least as big) */
enum string X_REQUEST_HEAD_AT_LEAST(alias type) = `
    mixin(REQUEST!` ~ type.stringof ~ `); 
    if (stuff is null) return (BadLength); 
    mixin(REQUEST_AT_LEAST_SIZE!` ~ type.stringof ~ `); 
`;
/* declare request struct, do NOT check size !*/
enum string X_REQUEST_HEAD_NO_CHECK(string type) = `
    mixin(REQUEST!` ~ type ~ `); 
    if (stuff is null) return (BadLength); 
`;
/* swap a CARD16 request struct field if necessary */
enum string X_REQUEST_FIELD_CARD16(string field) = `
    if (client.swapped) swaps(&stuff.` ~ field ~ `);`;

/* swap a CARD32 request struct field if necessary */
enum string X_REQUEST_FIELD_CARD32(alias field) = `
    if (client.swapped) swapl(&stuff.` ~ field ~ `);`;

/* swap a CARD64 request struct field if necessary */
enum string X_REQUEST_FIELD_CARD64(string field) = `
    if (client.swapped) swapll(&stuff.` ~ field~ `);`;

/* swap CARD16 rest of request (after the struct) */
enum string X_REQUEST_REST_CARD16() = `
    if (client.swapped) mixin(SwapRestS!("stuff"));`;

/* swap CARD32 rest of request (after the struct) */
enum string X_REQUEST_REST_CARD32() = `
    if (client.swapped) mixin(SwapRestL!("stuff"));`;

/* swap CARD16 rest of request (after the struct) - check fixed count */
enum string X_REQUEST_REST_COUNT_CARD16(string count) = `
    mixin(REQUEST_FIXED_SIZE!("*stuff", "` ~ count ~ ` * CARD16.sizeof")); 
    CARD16* request_rest = cast(CARD16*) (&stuff[1]); 
    { if (client.swapped) SwapShorts(cast(short*)request_rest, ` ~ count ~ `); } `;

/* swap CARD32 rest of request (after the struct) - check fixed count */
enum string X_REQUEST_REST_COUNT_CARD32(string count) = `
    mixin(REQUEST_FIXED_SIZE!("*stuff", "` ~ count ~ ` * CARD32.sizeof")); 
    CARD32* request_rest = cast(CARD32*) (&stuff[1]); 
    if (client.swapped) SwapLongs(request_rest, ` ~ count ~ `); 
`;
/*
 * macros for request handlers
 *
 * these are handling reply struct field byte-swapping if necessary
 */

/* swap a CARD16 field (if necessary) in reply struct */
enum string X_REPLY_FIELD_CARD16(string field) = `
    if (client.swapped) swaps(&reply.` ~ field ~ `);`;

/* swap a CARD32 field (if necessary) in reply struct */
enum string X_REPLY_FIELD_CARD32(string field) = `
    if (client.swapped) swapl(&reply.` ~ field ~ `);`;

/* swap a CARD64 field (if necessary) in reply struct */
enum string X_REPLY_FIELD_CARD64(string field) = `
    if (client.swapped) swapll(&reply.` ~ field ~ `);`;

 /* _XSERVER_DIX_REQUEST_PRIV_H */
