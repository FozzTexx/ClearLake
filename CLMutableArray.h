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

#ifndef _CLMUTABLEARRAY_H
#define _CLMUTABLEARRAY_H

#import <ClearLake/CLArray.h>
#import <ClearLake/CLRange.h>

@interface CLMutableArray:CLArray <CLCopying>
-(void) addObject:(id) anObject;
-(void) addObjects:(id) firstObj, ...;
-(void) insertObject:(id) anObject atIndex:(CLUInteger) index;
-(void) removeObject:(id) anObject;
-(void) removeObjectAtIndex:(CLUInteger) index;
-(void) removeLastObject;
-(void) removeAllObjects;
-(void) addObjectsFromArray:(CLArray *) otherArray;
-(void) removeObjectsInArray:(CLArray *) anArray;
-(void) removeObjectsInRange:(CLRange) aRange;
-(void) sortUsingDescriptors:(CLArray *) sortDescriptors;
-(void) sortUsingSelector:(SEL) comparator;
@end

#endif /* _CLMUTABLEARRAY_H */
