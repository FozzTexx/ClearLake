/* Copyright 1995-2007 by Chris Osborn <fozztexx@fozztexx.com>
 *
 * Copyright 2008-2016 by
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

#import <ClearLake/CLObject.h>
#import <ClearLake/CLStream.h>

@interface Header:CLObject <CLCopying>
{
  char *headers;
  char *mbuf;
}

- init;
- initFromString:(const char *) str;
- initFromString:(const char *) str length:(unsigned int) len;
-(void) dealloc;
- writeSelf:(CLStream *) stream;

- setHeaders:(const char *) str;
- setHeaders:(const char *) str length:(unsigned int) len;

-(const char *) valueOf:(const char *) str;
- addHeader:(const char *) hstr withValue:(const char *) str;
- deleteHeader:(const char *) hstr;
-(CLUInteger) count;
-(const char *) headerAt:(int) index;

@end
