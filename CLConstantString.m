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

#import "CLConstantString.h"
#import "CLStringFunctions.h"

@implementation CLConstantString

-(id) init
{
  [self error:@"We are constant, who called init?"];
  return self;
}

-(void) swizzle
{
  [super swizzle];
  isa = CLConstantUnicodeStringClass;  
  return;
}

/* CLConstantString was never allocated, don't allow it to be
   deallocated */
-(void) dealloc
{
  [self error:@"We are constant, who tried to dealloc?"];
  /* Just here to make the compiler warning go away. */
  if (0)
    [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef retain
#undef release
#undef autorelease
#undef retainCount
#endif

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
