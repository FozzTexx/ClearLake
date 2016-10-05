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

#import "CLPlaceholder.h"
#import "CLString.h"
#import "CLHashTable.h"
#import "CLEditingContext.h"

@implementation CLPlaceholder

+(CLPlaceholder *) placeholderFromString:(CLString *) aString
{
  CLRange aRange;
  CLUInteger aTag = 0;

  
  if ([aString length] > 2 && [aString characterAtIndex:0] == '<' &&
      [aString characterAtIndex:[aString length] - 1] == '>') {
    aRange = [aString rangeOfString:@":" options:0 range:CLMakeRange(0, [aString length])];
    if (aRange.length) {
      aTag = [[aString substringFromIndex:CLMaxRange(aRange)] unsignedLongValue];
      aString = [aString substringWithRange:CLMakeRange(1, aRange.location-1)];
    }
  }

  if ([aString isEqualToString:@"CLNull"])
    return nil;
  return [self placeholderFromString:aString tag:aTag];
}

+(CLPlaceholder *) placeholderFromString:(CLString *) aString tag:(CLUInteger) aValue
{
  return [[[[self class] alloc] initFromString:aString tag:aValue] autorelease];
}

-(id) initFromString:(CLString *) aString tag:(CLUInteger) aValue
{
  [super init];
  string = [aString copy];
  tag = aValue;
  return self;
}

-(void) dealloc
{
  [string release];
  [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLPlaceholder *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->string = [string copy];
  aCopy->tag = tag;
  return aCopy;
}
  
-(CLString *) string
{
  return string;
}

-(CLUInteger) tag
{
  return tag;
}

-(void) setString:(CLString *) aString
{
  [string autorelease];
  string = [aString copy];
  return;
}

-(void) setTag:(CLUInteger) aValue
{
  tag = aValue;
  return;
}

-(CLString *) description
{
  return [CLString stringWithFormat:@"<%@: %u>", string, tag];
}

-(BOOL) isEqual:(id) anObject
{
  if (self == anObject)
    return YES;
  if ([anObject isKindOfClass:[self class]] &&
      [string isEqualToString:[anObject string]] &&
      tag == [anObject tag])
    return YES;

  return NO;
}

-(CLUInteger) hash
{
  CLUInteger hash = 0, h;

  
  h = [string hash];
  hash = CLHashBytes(&h, sizeof(h), hash);
  h = tag;
  hash = CLHashBytes(&h, sizeof(h), hash);

  return hash;
}

@end
