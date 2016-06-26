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
#import "CLFault.h"

#include <stdlib.h>
#include <string.h>
#include <stdarg.h>

static id *CLQsortDescriptors;
static CLUInteger CLQsortLen;
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
  
  if ([object1 isFault])
    [object1 fault];
  
  if ((imp = [object1 methodFor:CLQsortComparator]))
    return ((CLComparisonResult (*) (id,SEL,id)) imp)(object1, CLQsortComparator, object2);

  return CLOrderedSame;
}

static int CLQsortCompareByDescriptors(const void *ptr1, const void *ptr2)
{
  int i;
  CLComparisonResult res = 0;
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

  for (i = 0; i < CLQsortLen; i++)
    if ((res = [CLQsortDescriptors[i] compareObject:object1 toObject:object2]))
      break;

  return res;
}

@implementation CLMutableArray

+(void) load
{
  CLMutableArrayClass = [CLMutableArray class];
  return;
}

-(void) grow
{
#if 0
  if (maxElements < 128)
    maxElements *= 2;
  else
#endif
    maxElements += 256;
  if (!(dataPtr = realloc(dataPtr, maxElements * sizeof(id) + 1)))
    [self error:@"Unable to allocate memory"];
  return;
}

-(void) addObject:(id) anObject
{
  return [(CLMutableArray *) self insertObject:anObject atIndex:numElements];
}

-(void) addObjects:(id) firstObj, ...
{
  int i, j;
  va_list ap;

  
  va_start(ap, firstObj);
  for (i = 1; va_arg(ap, id); i++)
    ;
  va_end(ap);

  while (numElements + i > maxElements)
    [self grow];
  j = numElements;
  numElements += i;
  dataPtr[j] = [firstObj retain];

  va_start(ap, firstObj);
  for (j++ ; j < numElements; j++)
    dataPtr[j] = [va_arg(ap, id) retain];
  va_end(ap);

  return;
}

-(void) insertObject:(id) anObject atIndex:(CLUInteger) index
{
  if (!anObject)
    [self error:@"Attempt to insert nil"];
  if (index > numElements)
    [self error:@"Index out of range"];
  
  if (numElements+1 > maxElements)
    [self grow];
  if (numElements - index)
    memmove(&dataPtr[index+1], &dataPtr[index], (numElements - index) * sizeof(id));
  dataPtr[index] = anObject;
  numElements++;
  [anObject retain];
  return;
}

-(void) removeObject:(id) anObject
{
  int i;


  for (i = 0; i < numElements; i++)
    if ([dataPtr[i] isEqual:anObject]) {
      [(CLMutableArray *) self removeObjectAtIndex:i];
      break;
    }
      

  return;
}

-(void) removeObjectAtIndex:(CLUInteger) index
{
  [self removeObjectsInRange:CLMakeRange(index, 1)];
}
  
-(void) removeLastObject
{
  if (!numElements) {
    /* FIXME - raise an exception */
    return;
  }
  [self removeObjectsInRange:CLMakeRange(numElements-1, 1)];
  return;
}

-(void) removeAllObjects
{
  [self removeObjectsInRange:CLMakeRange(0, numElements)];
  return;
}

-(void) addObjectsFromArray:(CLArray *) otherArray
{
  CLUInteger i;

  
  while (numElements + [otherArray count] > maxElements)
    [self grow];
  [otherArray getObjects:&dataPtr[numElements]];
  i = numElements;
  numElements += [otherArray count];
  for (; i < numElements; i++)
    [dataPtr[i] retain];
  return;
}

-(void) removeObjectsInArray:(CLArray *) anArray
{
  CLUInteger i;


  for (i = 0; i < numElements; i++)
    if ([anArray containsObject:dataPtr[i]]) {
      [self removeObjectsInRange:CLMakeRange(i, 1)];
      i--;
    }

  return;
}

-(void) removeObjectsInRange:(CLRange) aRange
{
  CLUInteger i;
  id *oldData;

  
  if (CLMaxRange(aRange) > numElements || !aRange.length)
    return;

  if (!(oldData = alloca(sizeof(id) * aRange.length)))
    [self error:@"Unable to allocate memory"];
  memcpy(oldData, &dataPtr[aRange.location], aRange.length * sizeof(id));

  if (numElements - CLMaxRange(aRange))
    memmove(&dataPtr[aRange.location], &dataPtr[CLMaxRange(aRange)],
	    (numElements - CLMaxRange(aRange)) * sizeof(id));
  numElements -= aRange.length;

  for (i = 0; i < aRange.length; i++)
    [oldData[i] release];
  
  return;
}

-(void) sortUsingDescriptors:(CLArray *) sortDescriptors
{
  if (numElements < 2)
    return;
  
  CLQsortLen = [sortDescriptors count];
  if (!(CLQsortDescriptors = alloca(sizeof(id) * CLQsortLen)))
    [self error:@"Unable to allocate memory"];
  [sortDescriptors getObjects:CLQsortDescriptors];
  qsort(dataPtr, numElements, sizeof(id), CLQsortCompareByDescriptors);

  return;
}

-(void) sortUsingSelector:(SEL) comparator
{
  if (numElements > 1) {
    CLQsortComparator = comparator;
    qsort(dataPtr, numElements, sizeof(id), CLQsortCompareBySelector);
  }
  
  return;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
#include <stdio.h>
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLMutableArray *anArray = [self mutableCopy];
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

  anArray->isa = CLArrayClass;
  return anArray;
}
#else
-(id) copy
{
  CLMutableArray *anArray = [self mutableCopy];


  anArray->isa = CLArrayClass;
  return anArray;
}
#endif

@end
