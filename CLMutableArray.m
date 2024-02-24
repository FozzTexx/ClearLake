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
#import "CLSortDescriptor.h"
#import "CLNull.h"
#import "CLString.h"
#import "CLClassConstants.h"
#import "CLFault.h"
#import "CLStream.h"

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

static CLMutableArray *CLQsortStack = nil;
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

@implementation CLMutableArray

+(id) alloc
{
  if (self == CLMutableArrayClass)
    self = CLInternalMutableArrayClass;
  return [super alloc];
}

+(id) array
{
  return [[[CLInternalMutableArray alloc] init] autorelease];
}

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

#if DEBUG_RETAIN
#undef copy
#undef retain
#include <stdio.h>
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLMutableArray *anArray = [[CLInternalMutableArray alloc] initWithArray:self];
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
  return [[[CLInternalMutableArray alloc] initWithArray:self] autorelease];
}
#endif

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

@implementation CLInternalMutableArray

-(void) grow
{
  CLArrayStorage *storage = arrayData;


  storage->maxElements += CLARRAY_BLOCKSIZE;
  if (!(storage->dataPtr = realloc(storage->dataPtr, storage->maxElements * sizeof(id))))
    [self error:@"Unable to allocate memory"];

  return;
}

-(void) addObjects:(id) firstObj, ...
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx, count;
  va_list ap;


  va_start(ap, firstObj);
  for (count = 1; va_arg(ap, id); count++)
    ;
  va_end(ap);

  while (storage->numElements + count > storage->maxElements)
    [self grow];
  idx = storage->numElements;
  storage->numElements += count;
  storage->dataPtr[idx] = [firstObj retain];

  va_start(ap, firstObj);
  for (idx++ ; idx < storage->numElements; idx++)
    storage->dataPtr[idx] = [va_arg(ap, id) retain];
  va_end(ap);

  return;
}

-(void) addObjectsFromArray:(CLArray *) otherArray
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;


  while (storage->numElements + [otherArray count] > storage->maxElements)
    [self grow];
  [otherArray getObjects:&storage->dataPtr[storage->numElements]];
  idx = storage->numElements;
  storage->numElements += [otherArray count];
  for (; idx < storage->numElements; idx++)
    [storage->dataPtr[idx] retain];
  return;
}

-(void) insertObject:(id) anObject atIndex:(CLUInteger) index
{
  CLArrayStorage *storage = arrayData;


  if (!anObject)
    [self error:@"Attempt to insert nil"];
  if (index > storage->numElements)
    [self error:@"Index out of range"];

  if (storage->numElements+1 > storage->maxElements)
    [self grow];
  if (storage->numElements - index)
    memmove(&storage->dataPtr[index+1], &storage->dataPtr[index],
            (storage->numElements - index) * sizeof(id));
  storage->dataPtr[index] = anObject;
  storage->numElements++;
  [anObject retain];
  return;
}

-(void) removeObject:(id) anObject
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;


  for (idx = 0; idx < storage->numElements; idx++)
    if ([storage->dataPtr[idx] isEqual:anObject]) {
      [(CLMutableArray *) self removeObjectAtIndex:idx];
      break;
    }


  return;
}

-(void) removeObjectsInArray:(CLArray *) anArray
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx, count, pos;
  CLArray *longer, *shorter;


  longer = anArray;
  shorter = self;
  if ([anArray count] < storage->numElements) {
    shorter = anArray;
    longer = self;
  }

  for (idx = 0, count = [shorter count]; idx < count; idx++) {
    pos = [longer indexOfObject:[shorter objectAtIndex:idx]];
    if (pos != CLNotFound) {
      if (longer == self)
        [self removeObjectsInRange:CLMakeRange(pos, 1)];
      else {
        [self removeObjectsInRange:CLMakeRange(idx, 1)];
        idx--;
      }
    }
  }

  return;
}

-(void) removeObjectsInRange:(CLRange) aRange
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;
  id *oldData;


  if (CLMaxRange(aRange) > storage->numElements || !aRange.length)
    return;

  if (!(oldData = alloca(sizeof(id) * aRange.length)))
    [self error:@"Unable to allocate memory"];
  memcpy(oldData, &storage->dataPtr[aRange.location], aRange.length * sizeof(id));

  if (storage->numElements - CLMaxRange(aRange))
    memmove(&storage->dataPtr[aRange.location], &storage->dataPtr[CLMaxRange(aRange)],
            (storage->numElements - CLMaxRange(aRange)) * sizeof(id));
  storage->numElements -= aRange.length;

  for (idx = 0; idx < aRange.length; idx++)
    [oldData[idx] release];

  return;
}

-(void) sortUsingDescriptors:(CLArray *) sortDescriptors
{
  CLArrayStorage *storage = arrayData;


  if (storage->numElements < 2)
    return;

  if (!CLQsortStack) {
    CLQsortStack = [[CLMutableArray alloc] init];
    CLAddToCleanup(CLQsortStack);
  }

  [CLQsortStack addObject:sortDescriptors];
  qsort(storage->dataPtr, storage->numElements, sizeof(id), CLQsortCompareByDescriptors);
  [CLQsortStack removeLastObject];

  return;
}

-(void) sortUsingSelector:(SEL) comparator
{
  CLArrayStorage *storage = arrayData;


  if (storage->numElements > 1) {
    CLQsortComparator = comparator;
    qsort(storage->dataPtr, storage->numElements, sizeof(id), CLQsortCompareBySelector);
  }

  return;
}

@end

@implementation CLInternalMutableArray (CopiedFromInternalArray)

-(id) init
{
  return [self initWithObjects:NULL count:0];
}

-(id) initWithObjects:(const id *) objects count:(unsigned) count
{
  [super init];
  arrayData = CLInternalArrayInitStorage(objects, count);
  return self;
}

-(void) dealloc
{
  CLInternalArrayDeallocStorage((CLArrayStorage *) arrayData);
  [super dealloc];
  return;
}

-(CLUInteger) count
{
  return ((CLArrayStorage *) arrayData)->numElements;
}

-(id) objectAtIndex:(CLUInteger) index
{
  CLArrayStorage *storage = arrayData;


  if (index >= storage->numElements)
    [self error:@"index beyond length"];
  return (id) storage->dataPtr[index];
}

-(id) read:(CLStream *) stream
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;


  [super read:stream];
  [stream readTypes:@"I", &storage->numElements];
  storage->maxElements = storage->numElements;
  if (!(storage->dataPtr = malloc(sizeof(id) * storage->maxElements)))
    [self error:@"Unable to alloc dataPtr"];
  for (idx = 0; idx < storage->numElements; idx++)
    [stream readTypes:@"@", &storage->dataPtr[idx]];
  return self;
}

-(void) write:(CLStream *) stream
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;


  [super write:stream];
  [stream writeTypes:@"I", &storage->numElements];
  for (idx = 0; idx < storage->numElements; idx++)
    [stream writeTypes:@"@", &storage->dataPtr[idx]];
  return;
}

@end
