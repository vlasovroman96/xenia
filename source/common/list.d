module common.list;
@nogc nothrow:
extern(C): __gshared:
/*
 * Copyright © 2010 Intel Corporation
 * Copyright © 2010 Francisco Jerez <currojerez@riseup.net>
 *
 * Permission is hereby granted, free of charge, to any person obtaining a
 * copy of this software and associated documentation files (the "Software"),
 * to deal in the Software without restriction, including without limitation
 * the rights to use, copy, modify, merge, publish, distribute, sublicense,
 * and/or sell copies of the Software, and to permit persons to whom the
 * Software is furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice (including the next
 * paragraph) shall be included in all copies or substantial portions of the
 * Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.  IN NO EVENT SHALL
 * THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
 * FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
 * IN THE SOFTWARE.
 *
 */

 
import std.traits : isPointer;

/**
 * @file Classic doubly-link circular list implementation.
 * For real usage examples of the linked list, see the file test/list.c
 *
 * Example:
 * We need to keep a list of struct foo in the parent struct bar, i.e. what
 * we want is something like this.
 *
 *     struct bar {
 *          ...
 *          struct foo *list_of_foos; -----> struct foo {}, struct foo {}, struct foo{}
 *          ...
 *     }
 *
 * We need one list head in bar and a list element in all list_of_foos (both are of
 * data type 'struct xorg_list').
 *
 *     struct bar {
 *          ...
 *          struct XList list_of_foos;
 *          ...
 *     }
 *
 *     struct foo {
 *          ...
 *          struct XList entry;
 *          ...
 *     }
 *
 * Now we initialize the list head:
 *
 *     struct bar bar;
 *     ...
 *     xorg_list_init(&bar.list_of_foos);
 *
 * Then we create the first element and add it to this list:
 *
 *     struct foo *foo = malloc(...);
 *     ....
 *     xorg_list_add(&foo->entry, &bar.list_of_foos);
 *
 * Repeat the above for each element you want to add to the list. Deleting
 * works with the element itself.
 *      xorg_list_del(&foo->entry);
 *      free(foo);
 *
 * Note: calling xorg_list_del(&bar.list_of_foos) will set bar.list_of_foos to an empty
 * list again.
 *
 * Looping through the list requires a 'struct foo' as iterator and the
 * name of the field the subnodes use.
 *
 * struct foo *iterator;
 * //mixin(xorg_list_for_each_entry!("iterator", "&bar.list_of_foos", "entry", q{ {
 *      if (iterator->something == ...)
 *             ...
 * }
 *
 * Note: You must not call xorg_list_del() on the iterator if you continue the
 * loop. You need to run the safe for-each loop instead:
 *
 * struct foo *iterator, *next;
 * mixin(xorg_list_for_each_entry_safe!("iterator", "next", "bar.list_of_foos", "entry") {
 *      if (...)
 *              xorg_list_del(&iterator->entry);
 * }
 *
 * WARNING: entries MUST NOT be added to the list twice, otherwise iterating
 *          will end up in infinite loop.
 * WARNING: entries MUST NOT be added to multiple lists - use separate entry
 *          nodes within the container struct, if it needs to be added to
 *          several lists at the same time.
 */

/**
 * The linkage struct for list nodes. This struct must be part of your
 * to-be-linked struct. struct XList is required for both the head of the
 * list and for each list node.
 *
 * Position and name of the struct XList field is irrelevant.
 * There are no requirements that elements of a list are of the same type.
 * There are no requirements for a list head, any struct XList can be a list
 * head.
 */
struct XList {
    XList* next, prev;

@nogc nothrow:

    /** 
     * Initialize list
     */
    void _init() {
        this.next = this.prev = &this;
    }

    alias initList = _init;

    /**
     * Initilize list only if both pointers are **null**
     */
    void autoinit() {
        if (!this.prev && !this.next)
            this._init();
    }

    /** 
     * Inserting element to the next position 
     */
    void insertNext(XList* elem) {
        elem.prev = &this;
        elem.next = this.next;
        next.prev = elem;
        this.next = elem;
    }

    /** 
     * Inserting element after list head 
     */
    void addListNext(XList* elem) {
        this.autoinit();
        this.insertNext(elem);
    }

    /** 
     * Inserting element to the end of the list 
     */
    void appendList(XList* elem) {
        this.autoinit();
        this.prev.insertNext(elem);
    }

    /** 
     * Cutting off element from the list 
     */
    void cutOff() {
        this.next.prev = this.prev;
        this.prev.next = this.next;
    }

    /** 
     * Deleting element from the list 
     */
    void removeFromList() {
        this.cutOff();
        this.initList();
    }

    /** 
     * Returns true if list is empty
     */
    int isEmpty() {
        return (!this.next || this.next == &this);
    }

    /** 
     * Returns true if element presents in the list
     */
    int isPresent(XList* elem) {
        for (XList* l = this.next; l && (l != &this); l=l.next) {
            if (l == elem)
                return 1;
        }
        return 0;
    }

    /** 
     * Adds element only if it not presents in the list
     */
    int addNoDups(XList* elem) {
        if (this.isPresent(elem))
            return 0;

        this.addListNext(elem);
        return 1;
    }

    /** 
     * Appends element only if it not presents in the list
     */
    int appendNoDups(XList* elem) {
        if (this.isPresent(elem))
            return 0;

        this.appendList(elem);
        return 1;
    }

    /** 
     * Returns: 
     *      Container instance of type **T** where XList node element has name **member**
     */
    auto getContainer(T, string member = "list")() {
        enum offset = __traits(getMember, T.init, member).offsetof;

        static if(isPointer!T) {
            alias RetType = T;
        }
        else
            alias RetType = T*;

        return cast(RetType)(cast(ubyte*)&this - offset);
    }

    /**
     * Retrieve the first/last list entry for the given list pointer.
     */
    auto getFirstEntry(T, string member = "list")() {
        return this.next.getContainer!(T, member);
    }

    //ditto
    auto getLastEntry(T, string member = "list")() {
        return this.prev.getContainer!(T, member);
    }

    /** 
     * Returns:
     *      Entries range 
     */
    auto byEntries(T, string member = "list")() {
        struct Entries {
            XList* start;
            XList* current;

            auto front() => current.getContainer!(T, member);
            bool empty() => current == start;
            void popFront() { current = current.next; }
        }

        return Entries(&this, this.next);
    }

    auto byEntriesSafe(T, string member = "list")() {
        struct Entries {
            XList* head;
            XList* current;
            XList* next;

            auto front() => current.getContainer!(T, member);
            bool empty() => current == head;
            void popFront() { 
                current = next; 
                if(current != head)
                    next = current.next;    
            }
        }

        return Entries(&this, this.next, this.next.next);
    }
}

template offsetOf(T, string member)
{
    enum offsetOf =
        __traits(getMember, T.init, member).offsetof;
}

@property
auto containerOf(T, string member)(void* ptr)
{
    enum offset = offsetOf!(T, member);

    static if(isPointer!T) {
        alias RetType = T;
    }
    else
        alias RetType = T*;

    return cast(RetType)(cast(ubyte*)ptr - offset);
}

// alias 
/* NULL-Terminated List Interface
 *
 * The interface below does _not_ use the struct XList as described above.
 * It is mainly for legacy structures that cannot easily be switched to
 * struct xorg_list.
 *
 * This interface is for structs like
 *      struct foo {
 *          [...]
 *          struct foo *next;
 *           [...]
 *      };
 *
 * The position and field name of "next" are arbitrary.
 */

/**
 * Init the element as null-terminated list.
 *
 * Example:
 * struct foo *list = malloc();
 * foo.ntListInit!"next";
 *
 * @param listEntry The list element that will be the start of the list
 * @param member Member name of the field pointing to next struct
 */
void ntListInit(string member, T)(T listEntry) {
    mixin("listEntry." ~ member) = null;
}

/**
 * Returns the next element in the list or NULL on termination.
 *
 * Example:
 * struct foo *element = list;
 * while ((element = nt_list_next(element, next)) { }
 *
 * This macro is not safe for node deletion. Use nt_list_for_each_entry_safe
 * instead.
 *
 * @param list The list or current element.
 * @param member Member name of the field pointing to next struct.
 */
auto ntListGetNext(string mem = "next", T)(T entryNode) {
    return mixin("entryNode." ~ mem); 
}

/**
 * Iterate through each element in the list.
 *
 * Example:
 * struct foo *iterator;
 * nt_list_for_each_entry(iterator, list, next) {
 *      [modify iterator]
 * }
 *
 * @param entry Assigned to the current list element
 * @param list The list to iterate through.
 * @param member Member name of the field pointing to next struct.
 */
enum string nt_list_for_each_entry(string _entry, string _list, string _member, string lambda) = `
	for (` ~ _entry ~ ` = ` ~ _list ~ `; ` ~ _entry ~ `; ` ~ _entry ~ ` = cast(typeof(`~_entry~`))(` ~ _entry ~ `).` ~ _member ~ `){` ~ lambda~`}`;

/**
 * Iterate through each element in the list, keeping a backup pointer to the
 * element. This macro allows for the deletion of a list element while
 * looping through the list.
 *
 * See nt_list_for_each_entry for more details.
 *
 * @param entry Assigned to the current list element
 * @param tmp The pointer to the next element
 * @param list The list to iterate through.
 * @param member Member name of the field pointing to next struct.
 */
enum string nt_list_for_each_entry_safe(string _entry, string _tmp, string _list, string _member, string funcbody) = `
	for (` ~ _entry ~ ` = ` ~ _list ~ `, ` ~ _tmp ~ ` = (` ~ _entry ~ `) ? cast(typeof(`~_entry~`))(` ~ _entry ~ `).` ~ _member ~ ` : null;
		` ~ _entry ~ `;							
		` ~ _entry ~ ` = ` ~ _tmp ~ `, ` ~ _tmp ~ ` = (` ~ _tmp ~ `) ? cast(typeof(`~_tmp~`))(` ~ _tmp ~ `).` ~ _member ~ `: null) {
            `~funcbody~`
        }`;

/**
 * Append the element to the end of the list. This macro may be used to
 * merge two lists.
 *
 * Example:
 * struct foo *elem = malloc(...);
 * mixin(nt_list_init!("elem", "next"))
 * nt_list_append(elem, list, struct foo, next);
 *
 * Resulting list order:
 * list_item_0 -> list_item_1 -> ... -> elem_item_0 -> elem_item_1 ...
 *
 * @param entry An entry (or list) to append to the list
 * @param list The list to append to. This list must be a valid list, not
 * NULL.
 * @param type The list type
 * @param member Member name of the field pointing to next struct
 */
enum string nt_list_append(string _entry, string _list, string _type, string _member) = `
	`~_type~`* __iterator = ` ~ _list ~ `;					
	while (__iterator.` ~ _member ~ `) { __iterator = cast(`~_type~`*)__iterator.` ~ _member ~ `;}
	__iterator.` ~ _member ~ ` = ` ~ _entry ~ `;`;

/**
 * Insert the element at the next position in the list. This macro may be
 * used to insert a list into a list.
 *
 * struct foo *elem = malloc(...);
 * mixin(nt_list_init!("elem", "next"))
 * nt_list_insert(elem, list, struct foo, next);
 *
 * Resulting list order:
 * list_item_0 -> elem_item_0 -> elem_item_1 ... -> list_item_1 -> ...
 *
 * @param entry An entry (or list) to append to the list
 * @param list The list to insert to. This list must be a valid list, not
 * NULL.
 * @param type The list type
 * @param member Member name of the field pointing to next struct
 */
enum string nt_list_insert(string _entry, string _list, string _type, string _member) = `
    do {								
	` ~ nt_list_append!(`(` ~ _list ~ `).` ~ _member ~ ``, _entry, _type, _member) ~ `;	
	(` ~ _list ~ `).` ~ _member ~ ` = ` ~ _entry ~ `;					
    } while (0)`;

/**
 * Delete the entry from the list by iterating through the list and
 * removing any reference from the list to the entry.
 *
 * Example:
 * struct foo *elem = <assign to right element>
 * nt_list_del(elem, list, struct foo, next);
 *
 * @param entry The entry to delete from the list. entry is always
 * re-initialized as a null-terminated list.
 * @param list The list containing the entry, set to the new list without
 * the removed entry.
 * @param type The list type
 * @param member Member name of the field pointing to the next entry
 */
enum string nt_list_del(string _entry, string _list, string _type, string _member) = `					
		`~_type~`* __e = ` ~ _entry ~ `;				
		if (__e is null || ` ~ _list ~ ` is null) break;        
		if ((` ~ _list ~ `) == __e) {				
		    ` ~ _list ~ ` = cast(`~_type~`*)__e.` ~ _member ~ `;			
		} else {					
		    `~_type~`* __prev = ` ~ _list ~ `;			
		    while (__prev.` ~ _member ~ ` && __prev.` ~ _member ~ ` != __e)	
			__prev = ` ~ `cast(typeof(__prev)) __prev.ntListGetNext!("`~_member~`");	
		    if (__prev.` ~ _member ~ `)			
			__prev.` ~ _member ~ ` = __e.` ~ _member ~ `;		
		}						
		__e.ntListInit!("` ~_member~`");`;

/**
 * DO NOT USE THIS.
 * This is a remainder of the xfree86 DDX attempt of having a set of generic
 * list functions. Unfortunately, the xf86OptionRec uses it and we can't
 * easily get rid of it. Do not use for new code.
 */
struct generic_list_rec {
    void* next;
}alias GenericListRec = generic_list_rec;
alias GenericListPtr = generic_list_rec*;
alias glp = generic_list_rec*;


