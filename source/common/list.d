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

 
public import core.stdc.stddef; /* offsetof() */

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
 * mixin(xorg_list_for_each_entry!("iterator", "&bar.list_of_foos", "entry", q{ {
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
}

/**
 * Remove the element from the list it is in. Using this function will reset
 * the pointers to/from this element so it is removed from the list. It does
 * NOT free the element itself or manipulate it otherwise.
 *
 * Using xorg_list_del on a pure list head (like in the example at the top of
 * this file) will NOT remove the first element from
 * the list but rather reset the list as empty list.
 *
 * Example:
 * xorg_list_del(&foo->entry);
 *
 * @param entry The element to remove.
 */
// pragma(inline, true) void xorg_list_del(XList* entry)
// {
//     entry.cutOff();
//     entry.initList();
// }

/**
 * Check if the list is empty.
 *
 * Example:
 * xorg_list_is_empty(&bar->list_of_foos);
 *
 * @return True if the list is empty or False if the list contains one or more
 * elements.
 */
pragma(inline, true) int xorg_list_is_empty(XList* head)
{
    return ((head.next is null) || (head.next == head));
}

/**
 * @brief check whether element already is in list
 *
 * @param entry The element to check for
 * @param head The existing list.
 * @return zero when entry isn't present in list, otherwise non-zero
 */
pragma(inline, true) int xorg_list_present(XList* entry, XList* head)
{
    for (XList* l = head.next; l && (l != head); l=l.next) {
        if (l == entry)
            return 1;
    }
    return 0;
}

/**
 * @brief prepend a new element to the end of the list if not existing yet
 *
 * Same as xorg_list_add(), but protecting against duplicate insertion.
 *
 * @param entry The new element to append to the list.
 * @param head The existing list.
 * @return zero if element already in list, otherwise non-zero
 */
pragma(inline, true) int xorg_list_add_ndup(XList* entry, XList* head)
{
    if (xorg_list_present(entry, head))
        return 0;

    head.addListNext(entry);
    return 1;
}

/**
 * @brief append a new element to the end of the list if not existing yet
 *
 * Same as xorg_list_append(), but protecting against duplicate insertion.
 *
 * @param entry The new element to append to the list.
 * @param head The existing list.
 * @return zero if element already in list, otherwise non-zero
 */
pragma(inline, true) int xorg_list_append_ndup(XList* entry, XList* head)
{
    if (xorg_list_present(entry, head))
        return 0;

    head.appendList(entry);
    return 1;
}

/**
 * Returns a pointer to the container of this list element.
 *
 * Example:
 * struct foo* f;
 * f = container_of(&foo->entry, struct foo, entry);
 * assert(f == foo);
 *
 * @param ptr Pointer to the struct xorg_list.
 * @param type Data type of the list element.
 * @param member Member name of the struct XList field in the list element.
 * @return A pointer to the data struct containing the list head.
 */

// version (container_of) {} else {
// enum string container_of(string ptr, string type, string member) = `
//     cast(type*)(cast(char*)(` ~ ptr ~ `) - ` ~type~`.`~member~`.offsetof)`;
// }

template offsetof(T, string member)
{
    enum offsetof =
        __traits(getMember, T.init, member).offsetof;
}

T* containerOf(T, string member)(void* ptr)
{
    enum offset = __traits(getMember, T.init, member).offsetof;

    return cast(T*)(cast(ubyte*)ptr - offset);
}

/**
 * Alias of container_of
 */
enum xorg_list_entry(string ptr, string type, string member) =
    "containerOf!(" ~ type ~ ", \"" ~ member ~ "\")(" ~ ptr ~ ")";

/**
 * Retrieve the first list entry for the given list pointer.
 *
 * Example:
 * struct foo *first;
 * first = xorg_list_first_entry(&bar->list_of_foos, struct foo, list_of_foos);
 *
 * @param ptr The list head
 * @param type Data type of the list element to retrieve
 * @param member Member name of the struct XList field in the list element.
 * @return A pointer to the first list element.
 */
enum string xorg_list_first_entry(string ptr, string type, string member) = "
    " ~ xorg_list_entry!("(" ~ ptr ~ ").next", type, member) ~ "";

/**
 * Retrieve the last list entry for the given listpointer.
 *
 * Example:
 * struct foo *first;
 * first = mixin(xorg_list_last_entry!("&bar->list_of_foos", "struct foo", "list_of_foos"));
 *
 * @param ptr The list head
 * @param type Data type of the list element to retrieve
 * @param member Member name of the struct XList field in the list element.
 * @return A pointer to the last list element.
 */
enum string xorg_list_last_entry(string ptr, string type, string member) = `
    ` ~ xorg_list_entry!(`(` ~ ptr ~ `).prev`, type, member) ~ ``;

alias __container_of(alias ptr, alias sample, alias member) = 
    container_of!(sample, member )(ptr);

/**
 * Loop through the list given by head and set pos to struct in the list.
 *
 * Example:
 * struct foo *iterator;
 * xorg_list_for_each_entry(iterator, &bar->list_of_foos, entry) {
 *      [modify iterator]
 * }
 *
 * This macro is not safe for node deletion. Use xorg_list_for_each_entry_safe
 * instead.
 *
 * @param pos Iterator variable of the type of the list elements.
 * @param head List head
 * @param member Member name of the struct XList in the list elements.
 *
 */
//  pragma(msg, xorg_list_for_each_entry!(
//     "ref_",
//     "&pPriv.reference_list",
//     "link",
//     q{}
// ));
template xorg_list_for_each_entry(string pos, string head, string member, string bodyCode)
{
    const string xorg_list_for_each_entry = 
        "for (" ~ pos ~ " = containerOf!(typeof(*" ~ pos ~ "), \"" ~ member ~ "\")((" ~ head ~ ").next); "
        ~ "(((" ~ head ~ ").next !is null) && &" ~ pos ~ "." ~ member ~ " !is (" ~ head ~ ")); "
        ~ pos ~ " = containerOf!(typeof(*" ~ pos ~ "), \"" ~ member ~ "\")(" ~ pos ~ "." ~ member ~ ".next)) {"
        ~ bodyCode
        ~ "}";
}
/*
 * Loop through the list, keeping a backup pointer to the element. This
 * macro allows for the deletion of a list element while looping through the
 * list.
 *
 * See xorg_list_for_each_entry for more details.
 */
template xorg_list_for_each_entry_safe(
    string pos,
    string tmp,
    string head,
    string member,
    string bodyCode)
{
    enum xorg_list_for_each_entry_safe =
        "for ("
        ~ pos ~ " = containerOf!(typeof(*" ~ pos ~ "), \"" ~ member ~ "\")((" ~ head ~ ").next), "
        ~ tmp ~ " = containerOf!(typeof(*" ~ pos ~ "), \"" ~ member ~ "\")(" ~ pos ~ "." ~ member ~ ".next); "
        ~ "(((" ~ head ~ ").next !is null) && &" ~ pos ~ "." ~ member ~ " != (" ~ head ~ ")); "
        ~ pos ~ " = " ~ tmp ~ ", "
        ~ tmp ~ " = containerOf!(typeof(*" ~ tmp ~ "), \"" ~ member ~ "\")(" ~ pos ~ "." ~ member ~ ".next)) {"
        ~ bodyCode
        ~ "}";
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
 * mixin(nt_list_init!("list", "next"));
 *
 * @param list The list element that will be the start of the list
 * @param member Member name of the field pointing to next struct
 */
enum string nt_list_init(string _list, string _member) = `
	(` ~ _list ~ `).` ~ _member ~ ` = null`;

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
enum string nt_list_next(string _list, string _member) = `
	(` ~ _list ~ `).` ~ _member ~ ``;

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
			__prev = ` ~ `cast(typeof(__prev))`~nt_list_next!(`__prev`, _member) ~ `;	
		    if (__prev.` ~ _member ~ `)			
			__prev.` ~ _member ~ ` = __e.` ~ _member ~ `;		
		}						
		` ~ nt_list_init!(`__e`, _member) ~ `;`;

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


