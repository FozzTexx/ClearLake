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

#import "CLPageStack.h"

#include <string.h>
#include <stdlib.h>

@implementation CLPageStack

-(id) init
{
  return [self initFromString:nil path:nil];
}

-(id) initFromString:(CLString *) aString path:(CLString *) aPath
{
  [super init];
  buf = NULL;
  len = [aString length];
  pos = 0;
  path = [aPath copy];

  if (len) {
    if (!(buf = malloc(len * sizeof(unichar))))
      [self error:@"Unable to allocate memory"];
    [aString getCharacters:buf];
  }
  
  return self;
}

-(void) dealloc
{
  if (buf)
    free(buf);
  [path release];
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
  CLPageStack *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->len = len;
  aCopy->pos = pos;
  aCopy->path = [path copy];
  if (!(aCopy->buf = malloc(len * sizeof(unichar))))
    [self error:@"Unable to allocate memory"];
  memcpy(aCopy->buf, buf, len * sizeof(unichar));
  return aCopy;
}

-(unichar *) buffer
{
  return buf;
}

-(CLUInteger) length
{
  return len;
}

-(CLUInteger) position
{
  return pos;
}

-(CLString *) path
{
  return path;
}

-(unichar) nextCharacter
{
  if (pos < len)
    return buf[pos++];
  return 0;
}

-(void) setPosition:(CLUInteger) aValue
{
  pos = aValue;
  return;
}

@end
