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

/* This is a special class to be used for swizzling the
   CLConstantString. About all it does is override the dealloc stuff
   and swizzle back into a CLConstantString. Everything else is
   inherited from CLString.

   Not sure if I need to do anything special about retain/release
   stuff. It can't really ever be released although I can swizzle back
   into a CLConstantString and free the unicode buffer. */

#import "CLConstantUnicodeString.h"
#import "CLStringFunctions.h"

#include <stdlib.h>

@implementation CLConstantUnicodeString

-(id) init
{
  [self error:@"We are constant, who called init?"];
  return self;
}

-(void) swizzle
{
  CLStringStorage *stor;


  stor = data;
  len = stor->maxLen;
  data = stor->utf8;
  free(stor->str);
  free(stor);
  isa = CLConstantStringClass;
  
  return;
}

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
