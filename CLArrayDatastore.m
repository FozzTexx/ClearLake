/* Copyright 2024 by
 *   Chris Osborn <fozztexx@fozztexx.com>
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

#import "CLArrayDatastore.h"
#import "CLConstantString.h"
#import "CLStream.h"
#import "CLNull.h"
#import "CLSortDescriptor.h"

#include <stdlib.h>
#include <string.h>
#include <alloca.h>

@interface CLArray (CLArrayDatastoreCommon)
-(id) _datastoreInitWithObjects:(const id *) objects count:(unsigned) count;
-(void) _datastoreDealloc;
-(CLUInteger) _datastoreCount;
-(id) _datastoreObjectAtIndex:(CLUInteger) index;
-(id) _datastoreRead:(CLStream *) stream;
-(void) _datastoreWrite:(CLStream *) stream;
-(void) _datastoreGetObjects:(id *) objects;
-(CLArray *) _datastoreSubarrayWithRange:(CLRange) range;
@end

@implementation CLArray (CLArrayDatastoreCommon)

-(id) _datastoreInitWithObjects:(const id *) objects count:(unsigned) count
{
  CLArrayStorage *storage;


  [super init];
  if (!(storage = malloc(sizeof(*storage))))
    [self error:@"Unable to allocate memory"];

  storage->numElements = 0;
  storage->maxElements = count;
  if (!(storage->dataPtr = malloc(sizeof(id) * count)))
    [self error:@"Unable to allocate memory"];

  if (objects) {
    storage->numElements = count;
    memcpy(storage->dataPtr, objects, sizeof(id) * count);
    for (; count; objects++, count--)
      [*objects retain];
  }

  arrayData = storage;
  return self;
}

-(void) _datastoreDealloc
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;


  for (idx = 0; idx < storage->numElements; idx++)
    [storage->dataPtr[idx] release];
  free(storage->dataPtr);
  free(storage);
  return;
}

-(CLUInteger) _datastoreCount
{
  return ((CLArrayStorage *) arrayData)->numElements;
}

-(id) _datastoreObjectAtIndex:(CLUInteger) index
{
  CLArrayStorage *storage = arrayData;


  if (index >= storage->numElements)
    [self error:@"index beyond length"];
  return (id) storage->dataPtr[index];
}

-(id) _datastoreRead:(CLStream *) stream
{
  CLArrayStorage *storage;
  CLUInteger idx;


  self = [super read:stream];
  if (!(storage = malloc(sizeof(*storage))))
    [self error:@"Unable to allocate memory"];
  arrayData = storage;
  [stream readTypes:@"I", &storage->numElements];
  storage->maxElements = storage->numElements;
  if (!(storage->dataPtr = malloc(sizeof(id) * storage->maxElements)))
    [self error:@"Unable to alloc dataPtr"];
  for (idx = 0; idx < storage->numElements; idx++)
    [stream readTypes:@"@", &storage->dataPtr[idx]];
  return self;
}

-(void) _datastoreWrite:(CLStream *) stream
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;


  [super write:stream];
  [stream writeTypes:@"I", &storage->numElements];
  for (idx = 0; idx < storage->numElements; idx++)
    [stream writeTypes:@"@", &storage->dataPtr[idx]];
  return;
}

-(void) _datastoreGetObjects:(id *) objects
{
  CLArrayStorage *storage = arrayData;


  if (storage->numElements)
    memcpy(objects, storage->dataPtr, sizeof(id) * storage->numElements);
  return;
}

-(CLArray *) _datastoreSubarrayWithRange:(CLRange) range
{
  CLArrayStorage *storage = arrayData;


  if (range.location >= storage->numElements || CLMaxRange(range) > storage->numElements) {
    /* FIXME - raise an exception */
    return nil;
  }

  return [[self class] arrayWithObjects:&storage->dataPtr[range.location] count:range.length];
}

@end

@implementation CLArrayDatastore

-(id) init
{
  return [self initWithObjects:NULL count:0];
}

-(id) initWithObjects:(const id *) objects count:(unsigned) count
{
  return [self _datastoreInitWithObjects:objects count:count];
}

-(void) dealloc
{
  [self _datastoreDealloc];
  [super dealloc];
  return;
}

-(CLUInteger) count
{
  return [self _datastoreCount];
}

-(id) objectAtIndex:(CLUInteger) index
{
  return [self _datastoreObjectAtIndex:index];
}

-(id) read:(CLStream *) stream
{
  return [self _datastoreRead:stream];
}

-(void) write:(CLStream *) stream
{
  [self _datastoreWrite:stream];
  return;
}

-(void) getObjects:(id *) objects
{
  [self _datastoreGetObjects:objects];
  return;
}

-(CLArray *) subarrayWithRange:(CLRange) range
{
  return [self _datastoreSubarrayWithRange:range];
}

@end

@implementation CLMutableArrayDatastore

-(id) init
{
  return [self initWithObjects:NULL count:0];
}

-(id) initWithObjects:(const id *) objects count:(unsigned) count
{
  return [self _datastoreInitWithObjects:objects count:count];
}

-(void) dealloc
{
  [self _datastoreDealloc];
  [super dealloc];
  return;
}

-(CLUInteger) count
{
  return [self _datastoreCount];
}

-(id) objectAtIndex:(CLUInteger) index
{
  return [self _datastoreObjectAtIndex:index];
}

-(id) read:(CLStream *) stream
{
  return [self _datastoreRead:stream];
}

-(void) write:(CLStream *) stream
{
  [self _datastoreWrite:stream];
  return;
}

-(void) getObjects:(id *) objects
{
  [self _datastoreGetObjects:objects];
  return;
}

-(CLArray *) subarrayWithRange:(CLRange) range
{
  return [self _datastoreSubarrayWithRange:range];
}

-(void) grow
{
  CLArrayStorage *storage = arrayData;


  storage->maxElements += CLARRAY_BLOCKSIZE;
  if (!(storage->dataPtr = realloc(storage->dataPtr, storage->maxElements * sizeof(id))))
    [self error:@"Unable to allocate memory"];

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

@end

#if 0

@implementation CLMutableArrayDatastore (DirectAccess)

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

#endif
