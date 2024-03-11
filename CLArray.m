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
#import "CLArrayDatastore.h"
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

+(id) alloc
{
  if (self == CLArrayClass)
    self = CLArrayDatastoreClass;
  return [super alloc];
}

+(id) array
{
  return [[[CLArrayDatastore alloc] init] autorelease];
}

+(id) arrayWithObjects:(id) firstObj, ...
{
  va_list ap;
  id anObject;


  va_start(ap, firstObj);
  anObject = [[[CLArrayDatastore alloc] initWithObject:firstObj andArguments:ap] autorelease];
  va_end(ap);
  return anObject;
}

+(id) arrayWithObjects:(const id *) objects count:(CLUInteger) count
{
  return [[[CLArrayDatastore alloc] initWithObjects:objects count:count] autorelease];
}

-(id) mutableCopy
{
  return [[CLMutableArray alloc] initWithArray:self];
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLUInteger idx1, idx2, count;
  CLRange aRange;
  CLString *aString;
  id anObject;
  unistr stackStr;
  id *buf;


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
  count = [self count];
  buf = alloca(count * sizeof(id));
  for (idx1 = idx2 = 0; idx1 < count; idx1++) {
    if ((anObject = [[self objectAtIndex:idx1] objectValueForBinding:aString])) {
      buf[idx2] = anObject;
      idx2++;
    }
  }

  return [[self class] arrayWithObjects:buf count:idx2];
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
  id sortedArray;
  CLArray *anArray;


  sortedArray = [self mutableCopy];
  [sortedArray sortUsingSelector:comparator];

  if (![self isKindOfClass:CLMutableArrayClass]) {
    /* FIXME - if self is not mutable then what is returned should not
               be either, find a way to downgrade mArray to immutable
               without forcing our class to implement
               initWithObjects:count: */
    anArray = [[[self class] alloc] initWithArray:sortedArray];
    [sortedArray release];
    sortedArray = anArray;
  }

  return [sortedArray autorelease];
}

-(CLArray *) sortedArrayUsingDescriptors:(CLArray *) sortDescriptors
{
  CLMutableArray *mArray;
  CLArray *anArray;


  mArray = [self mutableCopy];
  [mArray sortUsingDescriptors:sortDescriptors];
  anArray = [[[self class] alloc] initWithArray:mArray];
  [mArray release];
  return [anArray autorelease];
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

@implementation CLArray (CLSubclassMethods)

-(id) init
{
  if ([self class] == CLArrayClass)
    [self error:@"%s: %s must be implemented by subclass",
          object_getClassName(self), sel_getName(_cmd)];
  return [super init];
}

-(id) initWithObjects:(const id *) objects count:(unsigned) count
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

-(id) read:(CLStream *) stream
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

-(void) write:(CLStream *) stream
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return;
}

-(CLUInteger) count
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return 0;
}

-(id) objectAtIndex:(CLUInteger) index
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

@end

@implementation CLArray (CLArrayAccess)

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

