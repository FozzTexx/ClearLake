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

#import "CLPageTarget.h"
#import "CLPage.h"
#import "CLString.h"
#import "CLManager.h"
#import "CLSession.h"
#import "CLElement.h"

#include <stdlib.h>

@implementation CLPageTarget

-(id) init
{
  return [self initFromPath:nil];
}

-(id) initFromPath:(CLString *) aString
{
  [super init];
  path = [aString copy];
  return self;
}

-(void) dealloc
{
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
  CLPageTarget *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->path = [path copy];
  return aCopy;
}

-(id) read:(CLStream *) stream
{
  char *buf;

  
  [super read:stream];
  [stream readTypes:@"*", &buf];
  if (buf)
    path = [[CLString alloc] initWithUTF8String:buf];
  free(buf);
  return self;
}

-(void) write:(CLStream *) stream
{
  const char *buf;


  [super write:stream];
  buf = [path UTF8String];
  [stream writeTypes:@"*", &buf];
  return;
}

-(CLString *) path
{
  return path;
}

-(void) showPage:(id) sender
{
  /* FIXME - check if URL for this page is same as URL the browser
     requested, and if not do a redirect? */
  [sender setPage:[CLPage pageFromFile:path owner:nil]];
  return;
}

@end
