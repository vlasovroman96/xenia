module Xext.hashtable;
@nogc nothrow:
extern(C): __gshared:
import build.dix_config;

import core.stdc.stdlib;

import dix.resource_priv;

import common.misc;
import Xext.hashtable;
import common.list;

/* HashResourceID */
import dix.resource;

enum INITHASHSIZE = 6;
enum MAXHASHSIZE = 11;

/** @brief A hashing function.

  @param[in/out] cdata  Opaque data that can be passed to HtInit that will
                        eventually end up here
  @param[in] ptr        The data to be hashed. The size of the data, if
                        needed, can be configured via a record that can be
                        passed via cdata.
  @param[in] numBits    The number of bits this hash needs to have in the
                        resulting hash

  @return  A numBits-bit hash of the data
*/
alias HashFunc = uint function(void * cdata, const void * ptr, int numBits);
alias HashCompareFunc = int function(void * cdata, const void * l, const void * r);

struct HtGenericHashSetupRec{
    int             keySize;
} 
alias HtGenericHashSetupPtr = HtGenericHashSetupRec*;

struct HashTableRec {
    int keySize;
    int dataSize;

    int elements;   /* number of elements inserted */
    int bucketBits; /* number of buckets is 1 << bucketBits */
    XList* buckets;  /* array of bucket list heads */

    HashFunc hash;
    HashCompareFunc compare;

    void* cdata;
}

alias HashTable = HashTableRec*;

struct _BucketRec {
    XList l;
    void* key;
    void* data;
}alias BucketRec = _BucketRec;
alias BucketPtr = _BucketRec*;

HashTable ht_create(int keySize, int dataSize, HashFunc hash, HashCompareFunc compare, void* cdata)
{
    int c = void;
    int numBuckets = void;
    HashTable ht = cast(HashTable)cast(HashTableRec*) calloc(1, HashTableRec.sizeof);

    if (!ht) {
        return null;
    }

    ht.keySize = keySize;
    ht.dataSize = dataSize;
    ht.hash = hash;
    ht.compare = compare;
    ht.elements = 0;
    ht.bucketBits = INITHASHSIZE;
    numBuckets = 1 << ht.bucketBits;
    ht.buckets = cast(XList*)calloc(numBuckets, typeof(*ht.buckets).sizeof);
    ht.cdata = cdata;

    if (ht.buckets) {
        for (c = 0; c < numBuckets; ++c) {
            ht.buckets[c].initList();
        }
        return ht;
    } else {
        free(ht);
        return null;
    }
}

void ht_destroy(HashTable ht)
{
    int c;
    int numBuckets = 1 << ht.bucketBits;
    for (c = 0; c < numBuckets; ++c) {
        foreach(it; ht.buckets[c].byEntriesSafe!(BucketPtr, "l")) {
            it.l.removeFromList();
            free(it.key);
            free(it.data);
            free(it);
        }
    }
    free(ht.buckets);
    free(ht);
}

private Bool double_size(HashTable ht)
{
    XList* newBuckets = void;
    int numBuckets = 1 << ht.bucketBits;
    int newBucketBits = ht.bucketBits + 1;
    int newNumBuckets = 1 << newBucketBits;
    int c = void;

    newBuckets = cast(XList*) calloc(newNumBuckets, typeof(*ht.buckets).sizeof);
    if (newBuckets) {
        for (c = 0; c < newNumBuckets; ++c) {
            newBuckets[c].initList();
        }

        for (c = 0; c < numBuckets; ++c) {
            foreach(it; ht.buckets[c].byEntriesSafe!(BucketPtr, "l")) {
                XList* newBucket = &newBuckets[ht.hash(ht.cdata, it.key, newBucketBits)];
                it.l.removeFromList();
                newBucket.addListNext(&it.l);
            }
        }
        free(ht.buckets);

        ht.buckets = newBuckets;
        ht.bucketBits = newBucketBits;
        return TRUE;
    } else {
        return FALSE;
    }
}

void* ht_add(HashTable ht, const(void)* key)
{
    uint index = ht.hash(ht.cdata, key, ht.bucketBits);
    XList* bucket = &ht.buckets[index];
    BucketRec* elem = cast(BucketRec*) cast(BucketRec*) calloc(1, BucketRec.sizeof);
    if (!elem) {
        goto outOfMemory;
    }
    elem.key = calloc(1, ht.keySize);
    if (!elem.key) {
        goto outOfMemory;
    }
    /* we avoid signaling an out-of-memory error if dataSize is 0 */
    elem.data = calloc(1, ht.dataSize);
    if (ht.dataSize && !elem.data) {
        goto outOfMemory;
    }
    bucket.addListNext(&elem.l);
    ++ht.elements;

    memcpy(elem.key, key, ht.keySize);

    if (ht.elements > 4 * (1 << ht.bucketBits) &&
        ht.bucketBits < MAXHASHSIZE) {
        if (!double_size(ht)) {
            --ht.elements;
            elem.l.removeFromList();
            goto outOfMemory;
        }
    }

    /* if memory allocation has failed due to dataSize being 0, return
       a "dummy" pointer pointing at the of the key */
    return elem.data ? elem.data : (cast(char*) elem.key + ht.keySize);

 outOfMemory:
    if (elem) {
        free(elem.key);
        free(elem.data);
        free(elem);
    }

    return null;
}

void ht_remove(HashTable ht, const(void)* key)
{
    uint index = ht.hash(ht.cdata, key, ht.bucketBits);
    XList* bucket = &ht.buckets[index];

    foreach(it; bucket.byEntries!(BucketPtr, "l")) {
        if (ht.compare(ht.cdata, key, it.key) == 0) {
            it.l.removeFromList();
            --ht.elements;
            free(it.key);
            free(it.data);
            free(it);
            return;
        }
    }
}

void* ht_find(HashTable ht, const(void)* key)
{
    uint index = ht.hash(ht.cdata, key, ht.bucketBits);
    XList* bucket = &ht.buckets[index];

    foreach(it; bucket.byEntries!(BucketPtr, "l")) {
        if (ht.compare(ht.cdata, key, it.key) == 0) {
            return it.data ? it.data : (cast(char*) it.key + ht.keySize);
        }
    }

    return null;
}

void ht_dump_distribution(HashTable ht)
{
    int c = void;
    int numBuckets = 1 << ht.bucketBits;
    for (c = 0; c < numBuckets; ++c) {
        int n = 0;

        foreach(it; ht.buckets[c].byEntries!(BucketPtr, "l")) {
            ++n;
        }
        printf("%d: %d\n", c, n);
    }
}

/* Picked the function from http://burtleburtle.net/bob/hash/doobs.html by
   Bob Jenkins, which is released in public domain */
private CARD32 one_at_a_time_hash(const(void)* data, int len)
{
    CARD32 hash = void;
    int i = void;
    const(char)* key = cast(const(char)*) data;
    for (hash=0, i=0; i<len; ++i) {
        hash += key[i];
        hash += (hash << 10);
        hash ^= (hash >> 6);
    }
    hash += (hash << 3);
    hash ^= (hash >> 11);
    hash += (hash << 15);
    return hash;
}

uint ht_generic_hash(void* cdata, const(void)* ptr, int numBits)
{
    HtGenericHashSetupPtr setup = cast(HtGenericHashSetupPtr)cdata;
    return one_at_a_time_hash(ptr, setup.keySize) & ~((~0U) << numBits);
}

int ht_generic_compare(void* cdata, const(void)* l, const(void)* r)
{
    HtGenericHashSetupPtr setup = cast(HtGenericHashSetupPtr)cdata;
    return memcmp(l, r, setup.keySize);
}

uint ht_resourceid_hash(void* cdata, const(void)* data, int numBits)
{
    const(XID)* idPtr = cast(const(XID)*) data;
    XID id = *idPtr & RESOURCE_ID_MASK;
    cast(void) cdata;
    return HashResourceID(id, numBits);
}

int ht_resourceid_compare(void* cdata, const(void)* a, const(void)* b)
{
    const(XID)* xa = cast(const(XID)*)a;
    const(XID)* xb = cast(const(XID)*)b;
    cast(void) cdata;
    return
        *xa < *xb ? -1 :
        *xa > *xb ? 1 :
        0;
}

void ht_dump_contents(HashTable ht, void function(void* opaque, void* key) @nogc nothrow print_key , void function(void* opaque, void* value) @nogc nothrow print_value, void* opaque)
{
    int c = void;
    int numBuckets = 1 << ht.bucketBits;
    for (c = 0; c < numBuckets; ++c) {
        int n = 0;

        printf("%d: ", c);
        foreach(it; ht.buckets[c].byEntries!(BucketPtr, "l")) {
            if (n > 0) {
                printf(", ");
            }
            print_key(opaque, it.key);
            printf("->");
            print_value(opaque, it.data);
            ++n;
        }
        printf("\n");
    }
}
