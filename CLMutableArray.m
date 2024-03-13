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

#import "CLMutableArray.h"
#import "CLArrayDatastore.h"
#import "CLSortDescriptor.h"
#import "CLNull.h"
#import "CLString.h"
#import "CLClassConstants.h"
#import "CLFault.h"
#import "CLStream.h"

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

#if 0
static CLMutableArray *CLQsortStack = nil;
#endif
static SEL CLQsortComparator;

static int CLQsortCompareBySelector(const void *ptr1, const void *ptr2)
{
  IMP imp;
  id object1, object2;


  object1 = *(id *) ptr1;
  object2 = *(id *) ptr2;
  if (object1 == CLNullObject)
    object1 = nil;
  if (object2 == CLNullObject)
    object2 = nil;

  if (!object1 && object2)
    return CLOrderedAscending;
  if (object1 && !object2)
    return CLOrderedDescending;

  if ((imp = [object1 methodFor:CLQsortComparator]))
    return ((CLComparisonResult (*) (id,SEL,id)) imp)(object1, CLQsortComparator, object2);

  return CLOrderedSame;
}

#if 0
static int CLQsortCompareByDescriptors(const void *ptr1, const void *ptr2)
{
  int i;
  CLComparisonResult res = 0;
  id object1, object2;
  unsigned int len;
  CLArray *descriptors;


  object1 = *(id *) ptr1;
  object2 = *(id *) ptr2;
  if (object1 == CLNullObject)
    object1 = nil;
  if (object2 == CLNullObject)
    object2 = nil;

  if (!object1 && object2)
    return CLOrderedAscending;
  if (object1 && !object2)
    return CLOrderedDescending;

  descriptors = [CLQsortStack lastObject];
  len = [descriptors count];

  for (i = 0; i < len; i++)
    if ((res = [[descriptors objectAtIndex:i] compareObject:object1 toObject:object2]))
      break;

  return res;
}
#endif

@implementation CLMutableArray

+(id) alloc
{
  if (self == CLMutableArrayClass)
    self = CLMutableArrayDatastoreClass;
  return [super alloc];
}

+(id) array
{
  return [[[CLMutableArrayDatastore alloc] init] autorelease];
}

#if DEBUG_RETAIN
#undef copy
#undef retain
#include <stdio.h>
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLMutableArray *anArray = [[CLMutableArrayDatastore alloc] initWithArray:self];
  extern int CLLeakPrint;


  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx copy %s - 0x%lx %s:%i %i\n",
            (unsigned long) self, className, (unsigned long) retainer,
            file, line, [self retainCount] + 1);
    CLLeakPrint = pl;
  }

  return anArray;
}
#else
-(id) copy
{
  return [[[CLMutableArrayDatastore alloc] initWithArray:self] autorelease];
}
#endif

@end

@implementation CLMutableArray (CLMutableArrayModifying)

-(void) addObject:(id) anObject
{
  return [self insertObject:anObject atIndex:[self count]];
}

-(void) addObjects:(id) firstObj, ...
{
  va_list ap;
  id anObject;


  [self addObject:firstObj];
  va_start(ap, firstObj);
  while ((anObject = va_arg(ap, id)))
    [self addObject:anObject];
  va_end(ap);

  return;
}

-(void) addObjects:(const id *) objects count:(CLUInteger) count
{
  CLUInteger idx;


  for (idx = 0; idx < count; idx++)
    [self addObject:objects[idx]];
  return;
}

-(void) addObjectsFromArray:(CLArray *) otherArray
{
  CLUInteger idx, count;


  for (idx = 0, count = [otherArray count]; idx < count; idx++)
    [self addObject:[otherArray objectAtIndex:idx]];

  return;
}

-(void) removeObject:(id) anObject
{
  CLUInteger idx;


  idx = [self indexOfObject:anObject];
  if (idx != CLNotFound)
    [self removeObjectAtIndex:idx];
  return;
}

-(void) removeObjectAtIndex:(CLUInteger) index
{
  [self removeObjectsInRange:CLMakeRange(index, 1)];
}

-(void) removeAllObjects
{
  [self removeObjectsInRange:CLMakeRange(0, [self count])];
  return;
}

-(void) removeLastObject
{
  CLUInteger count;


  count = [self count];
  if (!count) {
    /* FIXME - raise an exception */
    return;
  }
  [self removeObjectsInRange:CLMakeRange(count - 1, 1)];
  return;
}

-(void) removeObjectsInArray:(CLArray *) anArray
{
  CLUInteger idx, count, pos;


  for (idx = 0, count = [anArray count]; idx < count; idx++) {
    pos = [self indexOfObject:[anArray objectAtIndex:idx]];
    if (pos != CLNotFound)
      [self removeObjectAtIndex:pos];
  }

  return;
}

-(void) sortUsingDescriptors:(CLArray *) sortDescriptors
{
  [self error:@"Not implemented"];
  return;
}

-(void) sortUsingSelector:(SEL) comparator
{
  CLUInteger count = [self count];
  id *data;


  if (count > 1) {
    CLQsortComparator = comparator;

    if (!(data = alloca(sizeof(id) * count)))
      [self error:@"Unable to allocate memory"];
    [self getObjects:data];

    qsort(data, count, sizeof(id), CLQsortCompareBySelector);
    [self addObjects:data count:count];
    [self removeObjectsInRange:CLMakeRange(0, count)];
  }

  return;
}

@end

@implementation CLMutableArray (CLSubclassMethods)

-(id) init
{
  if ([self class] == CLArrayClass)
    [self error:@"%s: %s must be implemented by subclass",
          object_getClassName(self), sel_getName(_cmd)];
  return [super init];
}

-(void) insertObject:(id) anObject atIndex:(CLUInteger) index
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return;
}

-(void) removeObjectsInRange:(CLRange) aRange
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return;
}

@end
