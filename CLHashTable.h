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

#import <ClearLake/CLObject.h>

#include <sys/types.h>
#include <stdint.h>

@class CLArray;

typedef struct CLBucket {
  id key;
  void *data;
  struct CLBucket *next;
  CLInteger pv, nv;
} CLBucket;

@interface CLHashTable:CLObject <CLCopying>
{
  CLInteger length, count;
  CLBucket **table;
  CLInteger first;
}

-(id) init;
-(id) initWithSize:(CLInteger) size;
-(void) dealloc;

-(void) setData:(void *) data forKey:(id) aKey hash:(CLUInteger) aValue;
-(void *) dataForKey:(id) aKey hash:(CLUInteger) aValue;
-(CLBucket *) bucketForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel;
-(void *) dataForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel;
-(CLBucket *) bucketForKeyIdenticalTo:(id) aKey hash:(CLUInteger) aValue;
-(void *) dataForKeyIdenticalTo:(id) aKey hash:(CLUInteger) aValue;
-(id) keyForKey:(id) aKey hash:(CLUInteger) aValue;
-(id) keyForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel;
-(void *) removeDataForKey:(id) aKey hash:(CLUInteger) aValue;
-(void *) removeDataForKey:(id) aKey hash:(CLUInteger) aValue selector:(SEL) aSel;
-(void *) removeDataForKeyIdenticalTo:(id) aKey hash:(CLUInteger) aValue;
-(CLUInteger) count;
-(void) getKeys:(id *) buf;
-(void) getData:(void **) buf;
-(CLArray *) allKeys;

@end

typedef u_int32_t CLUInteger32;
#define CLUInteger32Max   UINT32_MAX

extern CLUInteger32 CLHashBytes(const void *buf, register CLUInteger32 length,
				register CLUInteger32 initval);
