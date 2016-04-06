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

#import "CLMutableData.h"
#import "CLString.h"

#include <stdlib.h>
#include <string.h>

@implementation CLMutableData

+(id) dataWithLength:(CLUInteger) length
{
  return [[[self alloc] initWithLength:length] autorelease];
}

-(id) initWithLength:(CLUInteger) length
{
  [self init];
  [self increaseLengthBy:length];
  return self;
}

-(void *) mutableBytes
{
  return data;
}

-(void) increaseLengthBy:(CLUInteger) extraLength
{
  len += extraLength;
  if (extraLength && !(data = realloc(data, len)))
    [self error:@"Unable to allocate memory"];
  return;
}

-(void) setLength:(CLUInteger) length
{
  if (length > len)
    [self increaseLengthBy:length - len];
  else
    len = length;
  return;
}

-(void) appendBytes:(const void *) bytes length:(CLUInteger) length
{
  CLUInteger olen;


  if (length) {
    olen = len;
    [self increaseLengthBy:length];
    memmove(data+olen, bytes, length);
  }
  
  return;
}

-(void) appendByte:(unsigned char) byte
{
  [self increaseLengthBy:1];
  data[len - 1] = byte;
  
  return;
}

-(void) appendData:(CLData *) aData
{
  [self appendBytes:[aData bytes] length:[aData length]];
  return;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
#include <stdio.h>
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLMutableData *aData = [self mutableCopy];
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

  aData->isa = CLDataClass;
  return aData;
}
#else
-(id) copy
{
  CLMutableData *aData = [self mutableCopy];


  aData->isa = CLDataClass;
  return aData;
}
#endif

@end
