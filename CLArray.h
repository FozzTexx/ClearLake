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

#ifndef _CLARRAY_H
#define _CLARRAY_H

#include <stdarg.h>

#import <ClearLake/CLObject.h>
#import <ClearLake/CLRange.h>

#define CLARRAY_BLOCKSIZE       256

typedef struct {
  id *dataPtr;
  CLUInteger numElements, maxElements;
} CLArrayStorage;

@interface CLArray:CLObject <CLCopying, CLMutableCopying, CLPropertyList>
{
  void *arrayData;
}

+(id) array;
+(id) arrayWithObjects:(id) firstObj, ...;
+(id) arrayWithObjects:(const id *) objects count:(CLUInteger) count;

-(CLUInteger) indexOfObject:(id) anObject;
-(CLUInteger) indexOfObjectIdenticalTo:(id) anObject;
-(CLArray *) sortedArrayUsingSelector:(SEL) comparator;
-(CLArray *) sortedArrayUsingDescriptors:(CLArray *) sortDescriptors;
-(BOOL) containsObject:(id) anObject;
-(BOOL) containsObjectIdenticalTo:(id) anObject;
-(CLString *) componentsJoinedByString:(CLString *) separator;
-(CLString *) componentsJoinedAsCSV;
-(CLString *) componentsJoinedAsCSVUsingString:(CLString *) separator;
-(CLArray *) arrayByAddingObjectsFromArray:(CLArray *) otherArray;
-(CLArray *) arrayByAddingObject:(id) anObject;

-(BOOL) containsMultipleObjects;

-(CLString *) propertyList;
-(CLString *) json;
-(CLString *) description;

@end

@protocol CLArraySubclass
-(id) initWithObjects:(const id *) objects count:(unsigned) count;
-(CLUInteger) count;
-(id) objectAtIndex:(CLUInteger) index;
@end

@interface CLArray (CLSubclassMethods) <CLArraySubclass>
@end

@interface CLArray (CLArrayAccess)
-(void) getObjects:(id *) objects;
-(id) lastObject;
-(CLArray *) subarrayWithRange:(CLRange) range;
@end

@interface CLArray (CLArrayCreation)
-(id) initWithArray:(CLArray *) anArray;
-(id) initWithArray:(CLArray *) anArray copyItems:(BOOL) copyFlag;
-(id) initWithObject:(id) firstObj andArguments:(va_list) argList;
-(id) initWithObjects:(id) firstObj, ...;
@end

@interface CLArray (CLArrayArchiving) <CLArchiving>
@end

@interface CLInternalArray:CLArray
@end

extern void *CLInternalArrayInitStorage(const id *objects, unsigned count);
extern void CLInternalArrayDeallocStorage(CLArrayStorage *storage);

#endif /* _CLARRAY_H */
