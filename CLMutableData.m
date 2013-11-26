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

-(id) copy
{
  return [self mutableCopy];
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


  olen = len;
  [self increaseLengthBy:length];
  memmove(data+olen, bytes, length);
  return;
}

-(void) appendData:(CLData *) aData
{
  [self appendBytes:[aData bytes] length:[aData length]];
  return;
}

@end
