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

#include <stdlib.h>
#include <stdarg.h>
#include <wctype.h>
#include <string.h>

@implementation CLArray

+(id) array
{
  return [[[self alloc] init] autorelease];
}

+(id) arrayWithObjects:(id) firstObj, ...
{
  int i;
  id *buf;
  va_list ap;
  id anObject;

  
  va_start(ap, firstObj);
  for (i = 1; va_arg(ap, id); i++)
    ;
  va_end(ap);
  if (!(buf = alloca(sizeof(id) * i)))
    [self error:@"Unable to allocate memory"];
  buf[0] = firstObj;
  va_start(ap, firstObj);
  for (i = 1; (anObject = va_arg(ap, id)); i++)
    buf[i] = anObject;
  va_end(ap);

  anObject = [[[self alloc] initWithObjects:buf count:i] autorelease];
  return anObject;
}

+(id) arrayWithObjects:(const id *) objects count:(CLUInteger) count
{
  return [[[self alloc] initWithObjects:objects count:count] autorelease];
}
  
-(id) init
{
  [super init];
  maxElements = 256;
  if (!(dataPtr = malloc(maxElements * sizeof(id))))
    [self error:@"Unable to alloc dataPtr"];
  numElements = 0;
  return self;
}

-(id) initWithObjects:(id) firstObj, ...
{
  va_list ap;
  int i;
  id anObject;

  
  [self init];
  va_start(ap, firstObj);
  for (i = 1; va_arg(ap, id); i++)
    ;
  va_end(ap);

  numElements = maxElements = i;
  maxElements = ((maxElements + 255) / 256) * 256;
  if (!(dataPtr = realloc(dataPtr, sizeof(id) * maxElements)))
    [self error:@"Unable to alloc dataPtr"];
  dataPtr[0] = [firstObj retain];
  va_start(ap, firstObj);
  for (i = 1; (anObject = va_arg(ap, id)); i++)
    dataPtr[i] = [anObject retain];
  va_end(ap);
  return self;
}

-(id) initWithObjects:(const id *) objects count:(unsigned) count
{
  [self init];
  numElements = count;
  if (numElements > maxElements) {
    maxElements = ((numElements + 255) / 256) * 256;
    if (!maxElements)
      maxElements = 256;
    if (!(dataPtr = realloc(dataPtr, sizeof(id) * maxElements)))
      [self error:@"Unable to alloc dataPtr"];
  }
  memcpy(dataPtr, objects, sizeof(id) * count);
  for (; count; objects++, count--)
    [*objects retain];
  return self;
}

-(id) initWithArray:(CLArray *) anArray
{
  return [self initWithArray:anArray copyItems:NO];
}

-(id) initWithArray:(CLArray *) anArray copyItems:(BOOL) flag
{
  int i;

  
  [self init];
  numElements = maxElements = anArray->numElements;
  maxElements = ((maxElements + 255) / 256) * 256;
  if (!maxElements)
    maxElements = 256;
  if (!(dataPtr = realloc(dataPtr, sizeof(id) * maxElements)))
    [self error:@"Unable to alloc dataPtr"];
  for (i = 0; i < numElements; i++) {
    if (flag)
      dataPtr[i] = [anArray->dataPtr[i] copy];
    else
      dataPtr[i] = [anArray->dataPtr[i] retain];
  }
      
  return self;
}

-(void) dealloc
{
  CLUInteger i;


#if 0
  {
    static int depth = 0, j;


    depth++;
    for (i = 0; i < numElements; i++) {
      for (j = 1; j < depth; j++)
	fprintf(stderr, "  ");
      fprintf(stderr, "%i %u 0x%lx", 
	      (unsigned) i, (unsigned) numElements, (unsigned long) self);
      fprintf(stderr, " <%s: 0x%lx>",
	      [[dataPtr[i] class] name], (unsigned long) dataPtr[i]);
      [dataPtr[i] release];
      fprintf(stderr, "\n");
    }
    depth--;
  }
#else
  for (i = 0; i < numElements; i++)
    [dataPtr[i] release];
#endif
  if (dataPtr)
    free(dataPtr);
  [super dealloc];
  return;
}

-(id) mutableCopy
{
  return [[CLMutableArray alloc] initWithArray:self];
}

-(id) read:(CLStream *) stream
{
  int i;

  
  [super read:stream];
  [stream readTypes:@"I", &numElements];
  maxElements = numElements + 1;
  maxElements = ((maxElements + 255) / 256) * 256;
  if (!(dataPtr = malloc(sizeof(id) * maxElements)))
    [self error:@"Unable to alloc dataPtr"];
  for (i = 0; i < numElements; i++)
    [stream readTypes:@"@", &dataPtr[i]];
  return self;
}

-(void) write:(CLStream *) stream
{
  int i;

  
  [super write:stream];
  [stream writeTypes:@"I", &numElements];
  for (i = 0; i < numElements; i++)
    [stream writeTypes:@"@", &dataPtr[i]];
  return;
}

-(CLUInteger) count
{
  return numElements;
}

-(id) lastObject
{
  if (!numElements)
    return nil;
  return dataPtr[numElements-1];
}

-(id) objectAtIndex:(CLUInteger) index
{
  if (index >= numElements)
    [self error:@"index beyond length"];
  return (id) dataPtr[index];
}

-(void) getObjects:(id *) objects
{
  if (numElements)
    memcpy(objects, dataPtr, sizeof(id) * numElements);
  return;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLMutableArray *mArray = nil;
  int i;
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
  for (i = 0; i < numElements; i++) {
    if (!mArray) {
      mArray = [[CLMutableArray alloc] init];
    }
    if ((anObject = [dataPtr[i] objectValueForBinding:aString]))
      [mArray addObject:anObject];
  }

  if (mArray)
    ((CLArray *) mArray)->isa = CLArrayClass;
  return [mArray autorelease];
}

-(CLUInteger) indexOfObject:(id) anObject
{
  CLUInteger i;


  i = [self indexOfObjectIdenticalTo:anObject];
  if (i != CLNotFound)
    return i;
  
  for (i = 0; i < numElements; i++)
    if ([dataPtr[i] isEqual:anObject])
      return i;

  return CLNotFound;
}

-(CLUInteger) indexOfObjectIdenticalTo:(id) anObject
{
  CLUInteger i;


  for (i = 0; i < numElements; i++)
    if (dataPtr[i] == anObject)
      return i;

  return CLNotFound;
}

-(CLArray *) sortedArrayUsingSelector:(SEL) comparator
{
  CLMutableArray *mArray;


  mArray = [self mutableCopy];
  [mArray sortUsingSelector:comparator];
  ((CLArray *) mArray)->isa = CLArrayClass;
  return [mArray autorelease];
}

-(CLArray *) sortedArrayUsingDescriptors:(CLArray *) sortDescriptors
{
  CLMutableArray *mArray;


  mArray = [self mutableCopy];
  [mArray sortUsingDescriptors:sortDescriptors];
  ((CLArray *) mArray)->isa = CLArrayClass;
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
  int i;


  mString = [[CLMutableString alloc] init];
  for (i = 0; i < numElements; i++) {
    if (i)
      [mString appendString:separator];
    [mString appendString:[dataPtr[i] description]];
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
  int i;
  CLCharacterSet *notAlnumSet = [[CLCharacterSet alphaNumericCharacterSet] invertedSet];
  CLString *aString;
  CLRange aRange;
  

  mString = [[CLMutableString alloc] init];
  for (i = 0; i < numElements; i++) {
    if (i)
      [mString appendString:separator];

    /* FIXME - should we really special case nulls? */
    if (dataPtr[i] != CLNullObject) {
      aString = [dataPtr[i] description];
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
  int len;


  len = numElements + [otherArray count];
  if (!(data = alloca(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [self getObjects:data];
  [otherArray getObjects:&data[numElements]];
  anArray = [[self class] arrayWithObjects:data count:len];
  return anArray;
}

-(CLArray *) arrayByAddingObject:(id) anObject
{
  CLArray *anArray;
  id *data;
  int len;


  len = numElements + 1;
  if (!(data = alloca(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [self getObjects:data];
  data[numElements] = anObject;
  anArray = [[self class] arrayWithObjects:data count:len];
  return anArray;
}

-(CLArray *) subarrayWithRange:(CLRange) range
{
  if (range.location >= numElements || CLMaxRange(range) > numElements) {
    /* FIXME - raise an exception */
    return nil;
  }

  return [[self class] arrayWithObjects:&dataPtr[range.location] count:range.length];
}

-(BOOL) containsMultipleObjects
{
  if (numElements < 2)
    return NO;
  return YES;
}

-(CLString *) propertyList
{
  int i;
  CLMutableString *mString;


  mString = [[CLMutableString alloc] initWithString:@"("];
  for (i = 0; i < numElements; i++) {
    if (i)
      [mString appendString:@", "];
    [mString appendString:CLPropertyListString(dataPtr[i])];
  }
  [mString appendString:@")"];

  return [mString autorelease];
}

-(CLString *) json
{
  int i;
  CLMutableString *mString;


  mString = [[CLMutableString alloc] initWithString:@"["];
  for (i = 0; i < numElements; i++) {
    if (i)
      [mString appendString:@", "];
    [mString appendString:CLJSONString(dataPtr[i])];
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
  int i;


  if (self == anObject)
    return YES;
  
  if (![anObject isKindOfClass:CLArrayClass])
    return NO;

  if (numElements != [anObject count])
    return NO;
  
  for (i = 0; i < numElements; i++)
    if (![dataPtr[i] isEqual:[anObject objectAtIndex:i]])
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
