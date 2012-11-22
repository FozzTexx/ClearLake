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

#ifndef _CLARRAY_H
#define _CLARRAY_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLRange.h>

@interface CLArray:CLObject <CLCopying, CLMutableCopying, CLPropertyList, CLArchiving>
{
  id *dataPtr;
  CLUInteger numElements, maxElements;
}

+(id) array;
+(id) arrayWithObjects:(id) firstObj, ...;
+(id) arrayWithObjects:(const id *) objects count:(CLUInteger) count;
  
-(id) init;
-(id) initWithObjects:(id) firstObj, ...;
-(id) initWithObjects:(const id *) objects count:(CLUInteger) count;
-(id) initWithArray:(CLArray *) anArray;
-(id) initWithArray:(CLArray *) anArray copyItems:(BOOL) flag;
-(void) dealloc;

-(CLUInteger) count;
-(id) lastObject;
-(id) objectAtIndex:(CLUInteger) index;
-(void) getObjects:(id *) objects;
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
-(CLArray *) subarrayWithRange:(CLRange) range;
  
-(BOOL) containsMultipleObjects;

-(CLString *) propertyList;
-(CLString *) json;
-(CLString *) description;

@end

#endif /* _CLARRAY_H */
