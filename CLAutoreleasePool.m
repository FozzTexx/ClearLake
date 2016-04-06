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

#import "CLAutoreleasePool.h"
#import "CLMutableArray.h"
#import "CLString.h"

static CLMutableArray *activePools = nil;
static CLAutoreleasePool *lastPool = nil;

@implementation CLAutoreleasePool

+(void) addObject:(id) anObject
{
  [lastPool addObject:anObject];
  return;
}

+(BOOL) hasObject:(id) anObject
{
  int i;


  for (i = [activePools count]; i; i--)
    if ([[activePools objectAtIndex:i-1] indexOfObjectIdenticalTo:anObject] != CLNotFound)
      return YES;

  return NO;
}

-(id) init
{
  [super init];
  if (!activePools)
    activePools = [[CLMutableArray alloc] init];
  [activePools addObject:self];
  lastPool = self;
  return self;
}

#if DEBUG_RETAIN
#undef release
#endif
-(void) release
#if DEBUG_RETAIN
#define release		release:__FILE__ :__LINE__ :self
#endif
{
  [activePools removeObject:self];
  if (![activePools count]) {
    [activePools release];
    activePools = nil;
  }
  lastPool = [activePools lastObject];
#if DEBUG_RETAIN
#undef release
#endif
  [super release];
#if DEBUG_RETAIN
#define release		release:__FILE__ :__LINE__ :self
#endif
  return;
}
  
#if DEBUG_RETAIN
#undef autorelease
#endif
-(id) autorelease
#if DEBUG_RETAIN
#define autorelease	autorelease:__FILE__ :__LINE__ :self
#endif
{
  [self error:@"Can't autorelease CLAutoreleasePool"];
  return self;
}

@end
