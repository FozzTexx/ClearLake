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

#import "CLConstantString.h"
#import "CLStringFunctions.h"

#include <string.h>

@implementation CLUTF8String

-(id) initWithBytes:(char *) bytes length:(CLUInteger) length
		 encoding:(CLStringEncoding) encoding
{
  if (encoding != CLUTF8StringEncoding)
    [self error:@"Don't know how to init with encoding\n"];

  [super init];
  len = length;
  if (!(data = malloc(len)))
    [self error:@"Unable to allocate memory"];
  memmove(data, bytes, len);  
  return self;
}

-(id) initWithBytesNoCopy:(char *) bytes length:(CLUInteger) length
		 encoding:(CLStringEncoding) encoding
{
  if (encoding != CLUTF8StringEncoding)
    [self error:@"Don't know how to init with encoding\n"];

  [super init];
  data = bytes;
  len = length;
  return self;
}

-(void) dealloc
{
  free(data);
  data = NULL;
  [super dealloc];
  return;
}

-(void) swizzle
{
  char *buf = NULL;
  CLUInteger blen = 0;


  if (len) {
    CLStringConvertEncoding(data, len, CLUTF8StringEncoding,
			    &buf, &blen, CLUnicodeStringEncoding, NO);
    blen /= sizeof(unichar);
  }

  data = CLStringAllocateBuffer(NULL, blen, data, self);
  len = blen;
  if (len)
    wmemmove(data, (unichar *) buf, len);
  if (buf)
    free(buf);

  isa = CLStringClass;
  return;
}

-(CLUInteger) length
{
  if (!len)
    return 0;
  
  if ([self respondsTo:@selector(swizzle)])
    [self swizzle];
  return [super length];
}

-(unichar) characterAtIndex:(CLUInteger) index
{
  if ([self respondsTo:@selector(swizzle)])
    [self swizzle];
  return [super characterAtIndex:index];
}

-(void) getCharacters:(unichar *) buffer range:(CLRange) aRange
{
  if ([self respondsTo:@selector(swizzle)])
    [self swizzle];
  [super getCharacters:buffer range:aRange];
}

-(const char *) UTF8String
{
  if ([self respondsTo:@selector(swizzle)])
    return data;
  return [super UTF8String];
}

@end
