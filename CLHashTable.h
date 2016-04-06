/* Copyright 2008-2016 by
 *   Chris Osborn <fozztexx@fozztexx.com>
 *   Rob Watts <rob@rawatts.com>
 *
 * This file is part of ClearLake.
 *
 * ClearLake is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 2.1, or (at your option) any later
 * version.
 *
 * ClearLake is distributed in the hope that it will be useful, but WITHOUT ANY
 * WARRANTY; without even the implied warranty of MERCHANTABILITY or
 * FITNESS FOR A PARTICULAR PURPOSE. See the GNU General Public License
 * for more details.
 * 
 * You should have received a copy of the GNU General Public License
 * along with ClearLake; see the file COPYING. If not see
 * <http://www.gnu.org/licenses/>.
 */

#ifndef _CLHASHTABLE_H
#define _CLHASHTABLE_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLRuntime.h>

#include <sys/types.h>
#include <stdint.h>
#include <stdio.h>

#define CLHashTableDefaultSize (0x10000 / sizeof(void *))
#define HASHTABLE_AS_STRUCT

typedef struct CLBucket {
  id key;
  void *data;
  struct CLBucket *next;
  CLInteger pv, nv;
} CLBucket;

typedef struct CLHashTable {
  CLInteger length, count;
  CLBucket **table;
  CLInteger first;
} CLHashTable;

#if 0
extern CLHashTable *CLHashTableAlloc(CLInteger size);
extern void CLHashTableFree(CLHashTable *ht);
extern void CLHashTableSetData(CLHashTable *ht, void *data, id aKey, CLUInteger hash);
extern void *CLHashTableDataForKey(CLHashTable *ht, id aKey, CLUInteger hash, SEL selector);
extern void *CLHashTableDataForIdenticalKey(CLHashTable *ht, id aKey, CLUInteger hash);
extern id CLHashTableKeyForKey(CLHashTable *ht, id aKey, CLUInteger hash, SEL selector);
extern void *CLHashTableRemoveDataForKey(CLHashTable *ht, id aKey, CLUInteger hash, SEL selector);
extern void *CLHashTableRemoveDataForIdenticalKey(CLHashTable *ht, id aKey, CLUInteger hash);
extern void CLHashTableGetKeys(CLHashTable *ht, id *buf);
extern void CLHashTableGetData(CLHashTable *ht, void **buf);
#else
#include <stdlib.h>

CL_INLINE CLHashTable *CLHashTableAlloc(CLInteger size)
{
  CLHashTable *ht;
#if (DEBUG_LEAK || DEBUG_RETAIN) && defined(calloc)
  id self = nil;
#endif


  ht = calloc(1, sizeof(CLHashTable));
  ht->length = size;
  ht->count = 0;
  ht->first = -1;
  ht->table = calloc(ht->length, sizeof(CLBucket *));
  return ht;
}

CL_INLINE void CLHashTableFree(CLHashTable *ht)
{
  int i, j;
  CLBucket *aBucket, *aBucket2;
#if (DEBUG_LEAK || DEBUG_RETAIN) && defined(free)
  id self = nil;
#endif


  for (i = ht->first; i >= 0; i = j) {
    aBucket = ht->table[i];
    j = aBucket->nv;
    while (aBucket) {
      aBucket2 = aBucket->next;
      free(aBucket);
      aBucket = aBucket2;
    }
  }
  
  free(ht->table);
  free(ht);
  return;
}

CL_INLINE void CLHashTableLinkBucket(CLHashTable *ht, CLBucket *aBucket, CLUInteger val)
{
  if (ht->first < 0) {
    ht->first = val;
    aBucket->pv = aBucket->nv = -1;
  }
  else {
    aBucket->pv = ht->first;
    aBucket->nv = ht->table[ht->first]->nv;
    ht->table[ht->first]->nv = val;
    if (aBucket->nv >= 0)
      ht->table[aBucket->nv]->pv = val;
  }

  return;
}

CL_INLINE void CLHashTableUnlinkBucket(CLHashTable *ht, CLBucket *aBucket, CLUInteger val)
{
  if (aBucket->pv >= 0)
    ht->table[aBucket->pv]->nv = aBucket->nv;
  if (aBucket->nv >= 0)
    ht->table[aBucket->nv]->pv = aBucket->pv;
  if (val == ht->first) {
    if (aBucket->pv >= 0)
      ht->first = aBucket->pv;
    else
      ht->first = aBucket->nv;
    while (ht->first >= 0 && ht->table[ht->first]->pv >= 0)
      ht->first = ht->table[ht->first]->pv;
  }

  return;
}

CL_INLINE void CLHashTableSetData(CLHashTable *ht, void *data, id aKey, CLUInteger hash)
{
  CLUInteger val = hash % ht->length;
  CLBucket *aBucket;
#if (DEBUG_LEAK || DEBUG_RETAIN) && defined(calloc)
  id self = nil;
#endif


  aBucket = calloc(1, sizeof(CLBucket));
  aBucket->key = aKey;
  aBucket->data = data;
  
  if (!ht->table[val]) {
    ht->table[val] = aBucket;
    CLHashTableLinkBucket(ht, aBucket, val);
  }
  else {
    aBucket->next = ht->table[val];
    ht->table[val] = aBucket;
    aBucket->pv = aBucket->next->pv;
    aBucket->nv = aBucket->next->nv;
  }
  ht->count++;

  return;
}

CL_INLINE CLBucket *CLHashTableBucketForKey(CLHashTable *ht, id aKey, CLUInteger hash, SEL selector)
{
  CLUInteger val = hash % ht->length;
  CLBucket *aBucket;
  IMP imp;


  aBucket = ht->table[val];
  while (aBucket) {
    imp = objc_msg_lookup(aBucket->key, selector);
    if (aBucket->key == aKey || ((BOOL (*) (id,SEL,id)) imp)(aBucket->key, selector, aKey))
      return aBucket;
    aBucket = aBucket->next;
  }

  return NULL;
}

CL_INLINE CLBucket *CLHashTableBucketForIdenticalKey(CLHashTable *ht, id aKey, CLUInteger hash)
{
  CLUInteger val = hash % ht->length;
  CLBucket *aBucket;


  aBucket = ht->table[val];
  while (aBucket) {
    if (aBucket->key == aKey)
      return aBucket;
    aBucket = aBucket->next;
  }

  return NULL;
}

CL_INLINE void *CLHashTableDataForKey(CLHashTable *ht, id aKey, CLUInteger hash, SEL selector)
{
  CLBucket *aBucket;
  

  if ((aBucket = CLHashTableBucketForKey(ht, aKey, hash, selector)))
    return aBucket->data;
  return NULL;
}

CL_INLINE void *CLHashTableDataForIdenticalKey(CLHashTable *ht, id aKey, CLUInteger hash)
{
  CLBucket *aBucket;
  

  if ((aBucket = CLHashTableBucketForIdenticalKey(ht, aKey, hash)))
    return aBucket->data;
  return NULL;
}

CL_INLINE id CLHashTableKeyForKey(CLHashTable *ht, id aKey, CLUInteger hash, SEL selector)
{
  CLBucket *aBucket;


  if ((aBucket = CLHashTableBucketForKey(ht, aKey, hash, selector)))
    return aBucket->key;
  return NULL;
}

CL_INLINE void *CLHashTableRemoveDataForKey(CLHashTable *ht, id aKey, CLUInteger hash, SEL selector)
{
  CLUInteger val = hash % ht->length;
  CLBucket *aBucket, *pBucket;
  void *data;
  IMP imp;
#if (DEBUG_LEAK || DEBUG_RETAIN) && defined(free)
  id self = nil;
#endif


  for (pBucket = NULL, aBucket = ht->table[val]; aBucket;
       pBucket = aBucket, aBucket = aBucket->next) {
    imp = objc_msg_lookup(aBucket->key, selector);
    if (aBucket->key == aKey || ((BOOL (*) (id,SEL,id)) imp)(aBucket->key, selector, aKey)) {
      if (pBucket)
	pBucket->next = aBucket->next;
      else {
	ht->table[val] = aBucket->next;
	if (!ht->table[val])
	  CLHashTableUnlinkBucket(ht, aBucket, val);
	else {
	  aBucket->next->pv = aBucket->pv;
	  aBucket->next->nv = aBucket->nv;
	}
      }
      data = aBucket->data;
      free(aBucket);
      ht->count--;
      return data;
    }
  }

  return NULL;
}

CL_INLINE void *CLHashTableRemoveDataForIdenticalKey(CLHashTable *ht, id aKey, CLUInteger hash)
{
  CLUInteger val = hash % ht->length;
  CLBucket *aBucket, *pBucket;
  void *data;
#if (DEBUG_LEAK || DEBUG_RETAIN) && defined(free)
  id self = nil;
#endif


  for (pBucket = NULL, aBucket = ht->table[val]; aBucket;
       pBucket = aBucket, aBucket = aBucket->next)
    if (aBucket->key == aKey) {
      if (pBucket)
	pBucket->next = aBucket->next;
      else {
	ht->table[val] = aBucket->next;
	if (!ht->table[val])
	  CLHashTableUnlinkBucket(ht, aBucket, val);
	else {
	  aBucket->next->pv = aBucket->pv;
	  aBucket->next->nv = aBucket->nv;
	}
      }
      data = aBucket->data;
      free(aBucket);
      ht->count--;
      return data;
    }

  return NULL;
}

CL_INLINE void CLHashTableGetKeys(CLHashTable *ht, id *buf)
{
  CLInteger i, j;
  CLBucket *aBucket;


  for (i = ht->first, j = 0; i >= 0; i = ht->table[i]->nv) {
    aBucket = ht->table[i];
    while (aBucket) {
      if (j >= ht->count) {
	fprintf(stderr, "Corrupted hash table\n");
	abort();
      }
      buf[j++] = aBucket->key;
      aBucket = aBucket->next;
    }
  }

  return;
}

CL_INLINE void CLHashTableGetData(CLHashTable *ht, void **buf)
{
  CLInteger i, j;
  CLBucket *aBucket;


  for (i = ht->first, j = 0; i >= 0; i = ht->table[i]->nv) {
    aBucket = ht->table[i];
    while (aBucket) {
      buf[j++] = aBucket->data;
      aBucket = aBucket->next;
    }
  }
  
  return;
}
#endif /* INLINE */

typedef u_int32_t CLUInteger32;
#define CLUInteger32Max   UINT32_MAX

extern CLUInteger32 CLHashBytes(const void *buf, register CLUInteger32 length,
				register CLUInteger32 initval);

#endif /* _CLHASHTABLE_H */
