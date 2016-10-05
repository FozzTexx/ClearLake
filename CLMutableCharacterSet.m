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

#import "CLMutableCharacterSet.h"
#import "CLMutableString.h"
#import "CLClassConstants.h"

@interface CLCharacterSet (CLPrivateMethods)
-(id) initFromString:(CLString *) aString;
@end

@implementation CLMutableCharacterSet

-(id) initFromString:(CLString *) aString
{
  [super initFromString:aString];
  [string release];
  string = [[CLMutableString alloc] init];
  if (aString)
    [string setString:aString];
  return self;
}
  
-(void) addCharactersInString:(CLString *) aString
{
  [string appendString:aString];
  return;
}

#if 0
-(void) removeCharactersInString:(CLString *) aString
{
  return;
}

-(void) formIntersectionWithCharacterSet:(CLCharacterSet *) otherSet
{
  return;
}
#endif

-(void) formUnionWithCharacterSet:(CLCharacterSet *) otherSet
{
  [self addCharactersInString:otherSet->string];
  return;
}

-(void) invert
{
  inverted = !inverted;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
#include <stdio.h>
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLMutableCharacterSet *aSet = [self mutableCopy];
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

  aSet->isa = CLCharacterSetClass;
  return aSet;
}
#else
-(id) copy
{
  CLMutableCharacterSet *aSet = [self mutableCopy];


  aSet->isa = CLCharacterSetClass;
  return aSet;
}
#endif

@end
