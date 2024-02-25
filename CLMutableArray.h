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

#ifndef _CLMUTABLEARRAY_H
#define _CLMUTABLEARRAY_H

#import <ClearLake/CLArray.h>
#import <ClearLake/CLRange.h>

@interface CLMutableArray:CLArray <CLCopying>
-(void) addObject:(id) anObject;
-(void) removeAllObjects;
@end

@protocol CLMutableArraySubclass
-(void) insertObject:(id) anObject atIndex:(CLUInteger) index;
-(void) removeObjectsInRange:(CLRange) aRange;
@end

@interface CLMutableArray (CLSubclassMethods) <CLMutableArraySubclass>
@end

@interface CLMutableArray (CLMutableArrayModifying)
-(void) addObjects:(id) firstObj, ...;
-(void) addObjectsFromArray:(CLArray *) otherArray;
-(void) removeObject:(id) anObject;
-(void) removeLastObject;
-(void) removeObjectAtIndex:(CLUInteger) index;
-(void) removeObjectsInArray:(CLArray *) anArray;
-(void) sortUsingSelector:(SEL) comparator;
-(void) sortUsingDescriptors:(CLArray *) sortDescriptors;
@end

#endif /* _CLMUTABLEARRAY_H */
