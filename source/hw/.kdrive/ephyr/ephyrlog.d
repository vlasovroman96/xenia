module ephyrlog;
@nogc nothrow:
extern(C): __gshared:
/*
 * Xephyr - A kdrive X server that runs in a host X window.
 *          Authored by Matthew Allum <mallum@openedhand.com>
 *
 * Copyright © 2007 OpenedHand Ltd
 *
 * Permission to use, copy, modify, distribute, and sell this software and its
 * documentation for any purpose is hereby granted without fee, provided that
 * the above copyright notice appear in all copies and that both that
 * copyright notice and this permission notice appear in supporting
 * documentation, and that the name of OpenedHand Ltd not be used in
 * advertising or publicity pertaining to distribution of the software without
 * specific, written prior permission. OpenedHand Ltd makes no
 * representations about the suitability of this software for any purpose.  It
 * is provided "as is" without express or implied warranty.
 *
 * OpenedHand Ltd DISCLAIMS ALL WARRANTIES WITH REGARD TO THIS SOFTWARE,
 * INCLUDING ALL IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS, IN NO
 * EVENT SHALL OpenedHand Ltd BE LIABLE FOR ANY SPECIAL, INDIRECT OR
 * CONSEQUENTIAL DAMAGES OR ANY DAMAGES WHATSOEVER RESULTING FROM LOSS OF USE,
 * DATA OR PROFITS, WHETHER IN AN ACTION OF CONTRACT, NEGLIGENCE OR OTHER
 * TORTIOUS ACTION, ARISING OUT OF OR IN CONNECTION WITH THE USE OR
 * PERFORMANCE OF THIS SOFTWARE.
 *
 * Authors:
 *    Dodji Seketeli <dodji@openedhand.com>
 */
 
public import core.stdc.assert_;
public import os.os;

version (DEBUG) {} else {
/*we are not in debug mode*/
//#define EPHYR_LOG(...)
//#define EPHYR_LOG_ERROR(...)
}                          /*!DEBUG */

enum ERROR_LOG_LEVEL = 3;
enum INFO_LOG_LEVEL = 4;

version (EPHYR_LOG) {} else {
enum string EPHYR_LOG() = `
LogMessageVerb(X_NOTICE, INFO_LOG_LEVEL, "in %s:%d:%s: ",
                      __FILE__, __LINE__, __FUNCTION__.ptr) ; 
LogMessageVerb(X_NOTICE, INFO_LOG_LEVEL, __VA_ARGS__)`;
}                          /*nomadik_log */

version (EPHYR_LOG_ERROR) {} else {
enum string EPHYR_LOG_ERROR() = ``;
// LogMessageVerb(X_NOTICE, ERROR_LOG_LEVEL, "Error:in %s:%d:%s: ",
//                       __FILE__, __LINE__, __FUNCTION__.ptr) ; 
// // LogMessageVerb(X_NOTICE, ERROR_LOG_LEVEL, __VA_ARGS__)`;
}                          /*EPHYR_LOG_ERROR */

version (EPHYR_RETURN_IF_FAIL) {} else {
enum string EPHYR_RETURN_IF_FAIL(string cond) = ``;
// if (!(` ~ cond ~ `)) {` ~ EPHYR_LOG_ERROR!(`"condition %s failed\n"`~`, #cond`) ~ `;return;}`;
}                          /*nomadik_return_if_fail */

version (EPHYR_RETURN_VAL_IF_FAIL) {} else {
enum string EPHYR_RETURN_VAL_IF_FAIL(string cond,string val) = ``;
// if (!(` ~ cond ~ `)) {` ~ EPHYR_LOG_ERROR!() ~ `;return ` ~ val ~ `;}`;
}                          /*nomadik_return_val_if_fail */

 /*__EPHYRLOG_H__*/
