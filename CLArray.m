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

#import "CLArray.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLStream.h"
#import "CLCharacterSet.h"
#import "CLNull.h"
#import "CLStackString.h"
#import "CLClassConstants.h"
#import "CLValue.h"

#include <stdlib.h>
#include <wctype.h>
#include <string.h>

@implementation CLArray

+(id) array
{
  return [[[CLInternalArray alloc] init] autorelease];
}

+(id) arrayWithObjects:(id) firstObj, ...
{
  va_list ap;
  id anObject;


  va_start(ap, firstObj);
  anObject = [[[CLInternalArray alloc] initWithObject:firstObj andArguments:ap] autorelease];
  va_end(ap);
  return anObject;
}

+(id) arrayWithObjects:(const id *) objects count:(CLUInteger) count
{
  return [[[CLInternalArray alloc] initWithObjects:objects count:count] autorelease];
}
  
-(id) init
{
  return [self initWithObjects:NULL count:0];
}

-(id) mutableCopy
{
  return [[CLMutableArray alloc] initWithArray:self];
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLMutableArray *mArray = nil;
  CLUInteger idx, count;
  CLRange aRange;
  CLString *aString;
  id anObject;
  unistr stackStr;


  *found = NO;
  
  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else {
    stackStr = CLCloneStackString(aBinding);
    stackStr.len = aRange.location;
    aString = (CLString *) &stackStr;
  }

  if (![aString isEqualToString:@"objects"])
    return [super objectValueForBinding:aBinding found:found];

  *found = YES;
  if (!aRange.length)
    return self;
  
  stackStr = CLCloneStackString(aBinding);
  stackStr.str += CLMaxRange(aRange);
  stackStr.len -= CLMaxRange(aRange);
  aString = (CLString *) &stackStr;
  for (idx = 0, count = [self count]; idx < count; idx++) {
    if (!mArray) {
      mArray = [[CLMutableArray alloc] init];
    }
    if ((anObject = [[self objectAtIndex:idx] objectValueForBinding:aString]))
      [mArray addObject:anObject];
  }

  [mArray immutable];
  return [mArray autorelease];
}

-(CLUInteger) indexOfObject:(id) anObject
{
  CLUInteger idx, count;


  idx = [self indexOfObjectIdenticalTo:anObject];
  if (idx != CLNotFound)
    return idx;
  
  for (idx = 0, count = [self count]; idx < count; idx++)
    if ([[self objectAtIndex:idx] isEqual:anObject])
      return idx;

  return CLNotFound;
}

-(CLUInteger) indexOfObjectIdenticalTo:(id) anObject
{
  CLUInteger idx, count;


  for (idx = 0, count = [self count]; idx < count; idx++)
    if ([self objectAtIndex:idx] == anObject)
      return idx;

  return CLNotFound;
}

-(CLArray *) sortedArrayUsingSelector:(SEL) comparator
{
  CLMutableArray *mArray;


  mArray = [self mutableCopy];
  [mArray sortUsingSelector:comparator];
  [mArray immutable];
  return [mArray autorelease];
}

-(CLArray *) sortedArrayUsingDescriptors:(CLArray *) sortDescriptors
{
  CLMutableArray *mArray;


  mArray = [self mutableCopy];
  [mArray sortUsingDescriptors:sortDescriptors];
  [mArray immutable];
  return [mArray autorelease];
}

-(BOOL) containsObject:(id) anObject
{
  return [self indexOfObject:anObject] != CLNotFound;
}

-(BOOL) containsObjectIdenticalTo:(id) anObject
{
  return [self indexOfObjectIdenticalTo:anObject] != CLNotFound;
}

-(CLString *) componentsJoinedByString:(CLString *) separator
{
  CLMutableString *mString;
  CLUInteger idx, count;


  mString = [[CLMutableString alloc] init];
  for (idx = 0, count = [self count]; idx < count; idx++) {
    if (idx)
      [mString appendString:separator];
    [mString appendString:[[self objectAtIndex:idx] description]];
  }

  return [mString autorelease];
}

-(CLString *) componentsJoinedAsCSV
{
  return [self componentsJoinedAsCSVUsingString:@","];
}

-(CLString *) componentsJoinedAsCSVUsingString:(CLString *) separator
{
  CLMutableString *mString;
  CLUInteger idx, count;
  CLCharacterSet *notAlnumSet = [[CLCharacterSet alphaNumericCharacterSet] invertedSet];
  CLString *aString;
  CLRange aRange;
  

  mString = [[CLMutableString alloc] init];
  for (idx = 0, count = [self count]; idx < count; idx++) {
    if (idx)
      [mString appendString:separator];

    /* FIXME - should we really special case nulls? */
    if ([self objectAtIndex:idx] != CLNullObject) {
      aString = [[self objectAtIndex:idx] description];
      aRange = [aString rangeOfCharacterFromSet:notAlnumSet];
      if (aRange.length) {
	aString = [aString stringByReplacingOccurrencesOfString:@"\""
			   withString:@"\"\""];
	aString = [CLString stringWithFormat:@"\"%@\"", aString];
      }
      [mString appendString:aString];
    }
  }

  return [mString autorelease];
}

-(CLArray *) arrayByAddingObjectsFromArray:(CLArray *) otherArray
{
  CLArray *anArray;
  id *data;
  CLUInteger len;


  len = [self count] + [otherArray count];
  if (!(data = alloca(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [self getObjects:data];
  [otherArray getObjects:&data[[self count]]];
  anArray = [[self class] arrayWithObjects:data count:len];
  return anArray;
}

-(CLArray *) arrayByAddingObject:(id) anObject
{
  CLArray *anArray;
  id *data;
  CLUInteger len;


  len = [self count] + 1;
  if (!(data = alloca(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [self getObjects:data];
  data[len - 1] = anObject;
  anArray = [[self class] arrayWithObjects:data count:len];
  return anArray;
}

-(BOOL) containsMultipleObjects
{
  if ([self count] < 2)
    return NO;
  return YES;
}

-(CLString *) propertyList
{
  CLUInteger idx, count;
  CLMutableString *mString;


  mString = [[CLMutableString alloc] initWithString:@"("];
  for (idx = 0, count = [self count]; idx < count; idx++) {
    if (idx)
      [mString appendString:@", "];
    [mString appendString:CLPropertyListString([self objectAtIndex:idx])];
  }
  [mString appendString:@")"];

  return [mString autorelease];
}

-(CLString *) json
{
  CLUInteger idx, count;
  CLMutableString *mString;


  mString = [[CLMutableString alloc] initWithString:@"["];
  for (idx = 0, count = [self count]; idx < count; idx++) {
    if (idx)
      [mString appendString:@", "];
    [mString appendString:CLJSONString([self objectAtIndex:idx])];
  }
  [mString appendString:@"]"];

  return [mString autorelease];
}

-(CLString *) description
{
  return [self propertyList];
}

-(BOOL) isEqual:(id) anObject
{
  CLUInteger idx, count;


  if (self == anObject)
    return YES;
  
  if (![anObject isKindOfClass:CLArrayClass])
    return NO;

  if ([self count] != [anObject count])
    return NO;
  
  for (idx = 0, count = [self count]; idx < count; idx++)
    if (![[self objectAtIndex:idx] isEqual:[anObject objectAtIndex:idx]])
      return NO;

  return YES;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  return [self retain:file :line :retainer];
}
#else
-(id) copy
{
  return [self retain];
}
#endif

@end

@implementation CLArray (CLArrayCreation)

-(id) initWithArray:(CLArray *) anArray
{
  return [self initWithArray:anArray copyItems:NO];
}

-(id) initWithArray:(CLArray *) anArray copyItems:(BOOL) copyFlag
{
  CLUInteger idx, count;
  id anObject, *buf;


  count = [anArray count];
  if (!(buf = alloca(sizeof(id) * count)))
    [self error:@"Unable to allocate memory"];
  
  for (idx = 0; idx < count; idx++) {
    anObject = [anArray objectAtIndex:idx];
    if (copyFlag)
      anObject = [anObject copy];
    buf[idx] = anObject;
  }

  [self initWithObjects:buf count:count];

  if (copyFlag) {
    for (idx = 0; idx < count; idx++)
      [buf[idx] release];
  }

  return self;
}

-(id) initWithObject:(id) firstObj andArguments:(va_list) argList
{
  CLUInteger idx, count;
  va_list argCopy;
  id anObject, *buf;


  va_copy(argCopy, argList);
  for (count = 1; va_arg(argList, id); count++)
    ;

  if (!(buf = alloca(sizeof(id) * count)))
    [self error:@"Unable to allocate memory"];

  buf[0] = [firstObj retain];
  for (idx = 1; (anObject = va_arg(argCopy, id)); idx++)
    buf[idx] = [anObject retain];
  va_end(argCopy);

  [self initWithObjects:buf count:count];

  return self;
}

-(id) initWithObjects:(id) firstObj, ...
{
  va_list ap;


  va_start(ap, firstObj);
  [self initWithObject:firstObj andArguments:ap];
  va_end(ap);
  return self;
}

@end

@implementation CLArray (CLArrayAccess)

-(id) initWithObjects:(const id *) objects count:(unsigned) count
{
  CLArrayStorage *storage;


  [super init];
  arrayData = storage = malloc(sizeof(*storage));
  storage->numElements = storage->maxElements = count;
  if (!(storage->dataPtr = malloc(sizeof(id) * count)))
    [self error:@"Unable to allocate memory"];
  memcpy(storage->dataPtr, objects, sizeof(id) * count);
  for (; count; objects++, count--)
    [*objects retain];
  return self;
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

-(id) lastObject
{
  CLUInteger count = [self count];


  if (!count)
    return nil;
  return [self objectAtIndex:count - 1];
}

-(void) getObjects:(id *) objects
{
  CLUInteger idx, count;


  for (idx = 0, count = [self count]; idx < count; idx++)
    objects[idx] = [self objectAtIndex:idx];
  return;
}

-(CLArray *) subarrayWithRange:(CLRange) range
{
  CLUInteger idx;
  id *buf;


  if (CLMaxRange(range) > [self count]) {
    /* FIXME - raise an exception */
    return nil;
  }

  if (!(buf = alloca(sizeof(id) * range.length)))
    [self error:@"Unable to allocate memory"];
  for (idx = 0; idx < range.length; idx++)
    buf[idx] = [self objectAtIndex:idx + range.location];

  return [[self class] arrayWithObjects:buf count:range.length];
}

@end

@implementation CLInternalArray

-(void) dealloc
{
  CLUInteger i;
  CLArrayStorage *storage = arrayData;


#if 0
  {
    static int depth = 0, j;


    depth++;
    for (i = 0; i < storage->numElements; i++) {
      for (j = 1; j < depth; j++)
	fprintf(stderr, "  ");
      fprintf(stderr, "%i %u 0x%lx", 
	      (unsigned) i, (unsigned) storage->numElements, (unsigned long) self);
      fprintf(stderr, " <%s: 0x%lx>",
	      [[storage->dataPtr[i] class] name], (unsigned long) storage->dataPtr[i]);
      [storage->dataPtr[i] release];
      fprintf(stderr, "\n");
    }
    depth--;
  }
#else
  for (i = 0; i < storage->numElements; i++)
    [storage->dataPtr[i] release];
#endif
  if (storage->dataPtr)
    free(storage->dataPtr);
  free(storage);
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  CLArrayStorage *storage = arrayData;
  CLUInteger idx;

  
  [super read:stream];
  [stream readTypes:@"I", &storage->numElements];
  storage->maxElements = storage->numElements + 1;
  storage->maxElements = ((storage->maxElements + (CLARRAY_BLOCKSIZE - 1))
			  / CLARRAY_BLOCKSIZE) * CLARRAY_BLOCKSIZE;
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

-(void) getObjects:(id *) objects
{
  CLArrayStorage *storage = arrayData;


  if (storage->numElements)
    memcpy(objects, storage->dataPtr, sizeof(id) * storage->numElements);
  return;
}

-(CLArray *) subarrayWithRange:(CLRange) range
{
  CLArrayStorage *storage = arrayData;


  if (range.location >= storage->numElements || CLMaxRange(range) > storage->numElements) {
    /* FIXME - raise an exception */
    return nil;
  }

  return [[self class] arrayWithObjects:&storage->dataPtr[range.location] count:range.length];
}

@end
