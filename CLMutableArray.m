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
