/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * This file is part of ClearLake.
 *
 * ClearLake is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 3, or (at your option) any later
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

#import "CLHashTable.h"
#import "CLArray.h"
#import "CLMutableString.h"

typedef u_int8_t CLUInteger8;

#include <stdlib.h>

@implementation CLHashTable

-(id) init
{
  /* Default is to take 64k */
  return [self initWithSize:0x10000 / sizeof(void *)];
}

-(id) initWithSize:(CLInteger) size
{
  [super init];
  length = size;
  count = 0;
  first = -1;
  if (!(table = calloc(length, sizeof(CLBucket *))))
    [self error:@"Could not allocate table"];
  return self;
}
  
-(void) dealloc
{
  int i, j;
  CLBucket *aBucket, *aBucket2;


  for (i = first; i >= 0; i = j) {
    aBucket = table[i];
    j = aBucket->nv;
    while (aBucket) {
      aBucket2 = aBucket->next;
      free(aBucket);
      aBucket = aBucket2;
    }
  }
  
  free(table);
  [super dealloc];
  return;
}

-(id) copy
{
  [self error:@"Cannot copy"];
  return nil;
}

-(void) linkBucket:(CLBucket *) aBucket val:(CLUInteger) val
{
  if (first < 0) {
    first = val;
    aBucket->pv = aBucket->nv = -1;
  }
  else {
    aBucket->pv = first;
    aBucket->nv = table[first]->nv;
    table[first]->nv = val;
    if (aBucket->nv >= 0)
      table[aBucket->nv]->pv = val;
  }

  return;
}

-(void) unlinkBucket:(CLBucket *) aBucket val:(CLUInteger) val
{
  if (aBucket->pv >= 0)
    table[aBucket->pv]->nv = aBucket->nv;
  if (aBucket->nv >= 0)
    table[aBucket->nv]->pv = aBucket->pv;
  if (val == first) {
    if (aBucket->pv >= 0)
      first = aBucket->pv;
    else
      first = aBucket->nv;
    while (first >= 0 && table[first]->pv >= 0)
      first = table[first]->pv;
  }

  return;
}

-(void) setData:(void *) data forKey:(id) aKey hash:(CLUInteger) aValue
{
  CLUInteger val = aValue % length;
  CLBucket *aBucket;


  if (!(aBucket = calloc(1, sizeof(CLBucket))))
    [self error:@"Could not allocate aBucket"];
  aBucket->key = aKey;
  aBucket->data = data;
  
  if (!table[val]) {
    table[val] = aBucket;
    [self linkBucket:aBucket val:val];
  }
  else {
    aBucket->next = table[val];
    table[val] = aBucket;
    aBucket->pv = aBucket->next->pv;
    aBucket->nv = aBucket->next->nv;
  }
  count++;

  return;
}

-(void *) dataForKey:(id) aKey hash:(CLUInteger) aValue
{
  CLBucket *aBucket;
  

  if ((aBucket = [self bucketForKey:aKey hash:aValue selector:@selector(isEqual:)]))
    return aBucket->data;
  return NULL;
}

-(CLBucket *) bucketForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel
{
  CLUInteger val = aValue % length;
  CLBucket *aBucket;
  IMP imp;


  aBucket = table[val];
  while (aBucket) {
    imp = [aBucket->key methodFor:aSel];
    if (((BOOL (*) (id,SEL,id)) imp)(aBucket->key, aSel, aKey))
      return aBucket;
    aBucket = aBucket->next;
  }

  return NULL;
}

-(void *) dataForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel
{
  CLBucket *aBucket;
  

  if ((aBucket = [self bucketForKey:aKey hash:aValue selector:aSel]))
    return aBucket->data;
  return NULL;
}

-(CLBucket *) bucketForKeyIdenticalTo:(id) aKey hash:(CLUInteger) aValue
{
  CLUInteger val = aValue % length;
  CLBucket *aBucket;


  aBucket = table[val];
  while (aBucket) {
    if (aBucket->key == aKey)
      return aBucket;
    aBucket = aBucket->next;
  }

  return NULL;
}

-(void *) dataForKeyIdenticalTo:(id) aKey hash:(CLUInteger) aValue
{
  CLBucket *aBucket;
  

  if ((aBucket = [self bucketForKeyIdenticalTo:aKey hash:aValue]))
    return aBucket->data;
  return NULL;
}

-(id) keyForKey:(id) aKey hash:(CLUInteger) aValue
{
  return [self keyForKey:aKey hash:aValue selector:@selector(isEqual:)];
}

-(id) keyForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel
{
  CLBucket *aBucket;


  if ((aBucket = [self bucketForKey:aKey hash:aValue selector:aSel]))
    return aBucket->key;
  return NULL;
}
  
-(void *) removeDataForKey:(id) aKey hash:(CLUInteger) aValue
{
  return [self removeDataForKey:aKey hash:aValue selector:@selector(isEqual:)];
}

-(void *) removeDataForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel
{
  CLUInteger val = aValue % length;
  CLBucket *aBucket, *pBucket;
  void *data;
  IMP imp;


  for (pBucket = NULL, aBucket = table[val]; aBucket;
       pBucket = aBucket, aBucket = aBucket->next) {
    imp = [aBucket->key methodFor:aSel];
    if (((BOOL (*) (id,SEL,id)) imp)(aBucket->key, aSel, aKey)) {
      if (pBucket)
	pBucket->next = aBucket->next;
      else {
	table[val] = aBucket->next;
	if (!table[val])
	  [self unlinkBucket:aBucket val:val];
	else {
	  aBucket->next->pv = aBucket->pv;
	  aBucket->next->nv = aBucket->nv;
	}
      }
      data = aBucket->data;
      free(aBucket);
      count--;
      return data;
    }
  }

  return NULL;
}

-(void *) removeDataForKeyIdenticalTo:(id) aKey hash:(CLUInteger) aValue
{
  CLUInteger val = aValue % length;
  CLBucket *aBucket, *pBucket;
  void *data;


  for (pBucket = NULL, aBucket = table[val]; aBucket;
       pBucket = aBucket, aBucket = aBucket->next)
    if (aBucket->key == aKey) {
      if (pBucket)
	pBucket->next = aBucket->next;
      else {
	table[val] = aBucket->next;
	if (!table[val])
	  [self unlinkBucket:aBucket val:val];
	else {
	  aBucket->next->pv = aBucket->pv;
	  aBucket->next->nv = aBucket->nv;
	}
      }
      data = aBucket->data;
      free(aBucket);
      count--;
      return data;
    }

  return NULL;
}

-(CLUInteger) count
{
  return count;
}

-(void) getKeys:(id *) buf
{
  CLInteger i, j;
  CLBucket *aBucket;


  for (i = first, j = 0; i >= 0; i = table[i]->nv) {
    aBucket = table[i];
    while (aBucket) {
      if (j >= count)
	[self error:@"Corrupted bucket list"];
      buf[j++] = aBucket->key;
      aBucket = aBucket->next;
    }
  }

  return;
}

-(void) getData:(void **) buf
{
  CLInteger i, j;
  CLBucket *aBucket;


  for (i = first, j = 0; i >= 0; i = table[i]->nv) {
    aBucket = table[i];
    while (aBucket) {
      buf[j++] = aBucket->data;
      aBucket = aBucket->next;
    }
  }
  
  return;
}

-(CLArray *) allKeys
{
  id *keys;
  CLArray *anArray;


  if (!count)
    return nil;
  
  if (!(keys = malloc(sizeof(id) * count)))
    [self error:@"Could not allocate keys"];
  [self getKeys:keys];
  anArray = [[CLArray alloc] initWithObjects:keys count:count];
  free(keys);
  return [anArray autorelease];
}
  
-(CLString *) propertyList
{
  CLUInteger i;
  CLMutableString *mString;
  id *keys;


  mString = [[CLMutableString alloc] initWithString:@"{\n"];

  keys = malloc(sizeof(id) * count);
  [self getKeys:keys];
  for (i = 0; i < count; i++)
    [mString appendFormat:@"  %@ = %@;\n",
	     CLPropertyListString(keys[i]),
	     CLPropertyListString([self dataForKey:keys[i] hash:[keys[i] hash]])];
  free(keys);

  [mString appendString:@"}\n"];

  return [mString autorelease];
}

-(CLString *) description
{
  return [self propertyList];
}

@end

typedef u_int8_t CLUinteger8;

#define hashsize(n) ((CLUInteger32)1<<(n))
#define hashmask(n) (hashsize(n)-1)

#define mix(a,b,c) \
{ \
  a -= b; a -= c; a ^= (c>>13); \
  b -= c; b -= a; b ^= (a<<8); \
  c -= a; c -= b; c ^= (b>>13); \
  a -= b; a -= c; a ^= (c>>12);  \
  b -= c; b -= a; b ^= (a<<16); \
  c -= a; c -= b; c ^= (b>>5); \
  a -= b; a -= c; a ^= (c>>3);  \
  b -= c; b -= a; b ^= (a<<10); \
  c -= a; c -= b; c ^= (b>>15); \
}

/* http://www.azillionmonkeys.com/qed/hash.html */

CLUInteger32 CLHashBytes(const void *buf, register CLUInteger32 length,
			 register CLUInteger32 initval)
{
  register CLUInteger32 a, b, c, len;
  const register CLUInteger8 *k = buf;


  len = length;
  a = b = 0x9e3779b9;
  c = initval;

  while (len >= 12) {
    a += (k[0]+((CLUInteger32)k[1]<<8)+((CLUInteger32)k[2]<<16)+((CLUInteger32)k[3]<<24));
    b += (k[4]+((CLUInteger32)k[5]<<8)+((CLUInteger32)k[6]<<16)+((CLUInteger32)k[7]<<24));
    c += (k[8]+((CLUInteger32)k[9]<<8)+((CLUInteger32)k[10]<<16)+((CLUInteger32)k[11]<<24));
    mix(a,b,c);
    k += 12; len -= 12;
  }

  c += length;
  switch (len) {
    /* all the case statements fall through */
  case 11: c+=((CLUInteger32)k[10]<<24);
  case 10: c+=((CLUInteger32)k[9]<<16);
  case 9 : c+=((CLUInteger32)k[8]<<8);
    /* the first byte of c is reserved for the length */
  case 8 : b+=((CLUInteger32)k[7]<<24);
  case 7 : b+=((CLUInteger32)k[6]<<16);
  case 6 : b+=((CLUInteger32)k[5]<<8);
  case 5 : b+=k[4];
  case 4 : a+=((CLUInteger32)k[3]<<24);
  case 3 : a+=((CLUInteger32)k[2]<<16);
  case 2 : a+=((CLUInteger32)k[1]<<8);
  case 1 : a+=k[0];
    /* case 0: nothing left to add */
  }
  mix(a,b,c);

  return c;
}
