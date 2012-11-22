/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * This file is part of ClearLake.
 *
 * ClearLake is free software; you can redistribute it and/or modify it under
 * the terms of the GNU General Public License as published by the Free
 * Software Foundation; either version 3, or (at your option) any later
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

#import "CLNull.h"
#import "CLInvocation.h"

CLNull *CLNullObject = nil;

@implementation CLNull

+(CLNull *) null
{
  if (!CLNullObject)
    CLNullObject = [[[self class] alloc] init];
  return CLNullObject;
}

#if 0
/* I want CLNull to act like a nil object */
-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  id anObject = nil;

  
  [anInvocation setReturnValue:&anObject];
  return;
}
#endif

#if DEBUG_RETAIN
#undef retain
#undef release
#undef autorelease
#undef retainCount
#endif

/* There is one and always one CLNull instance */
-(id) retain
{
  return self;
}

-(void) release
{
  return;
}

-(id) autorelease
{
  return self;
}

-(CLUInteger) retainCount
{
  return 1;
}

@end
