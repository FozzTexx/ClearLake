/* Copyright 2012-2016 by
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

#define _GNU_SOURCE /* To get fmemopen */
#include <stdio.h>

#import "CLMemoryStream.h"
#import "CLData.h"

#include <stdlib.h>
#include <string.h>

@implementation CLMemoryStream

+(CLMemoryStream *) openWithMemory:(void *) buf length:(int) len mode:(int) mode
{
  return [[[self alloc] initWithMemory:buf length:len mode:mode] autorelease];
}

+(CLMemoryStream *) openWithData:(CLData *) aData mode:(int) mode
{
  return [[[self alloc] initWithData:aData mode:mode] autorelease];
}

+(CLStream *) openMemoryForWriting
{
  return [[[self alloc] initWithMemory:NULL length:0 mode:CLWriteOnly] autorelease];
}

-(id) init
{
  return [self initWithMemory:NULL length:0 mode:0];
}

-(id) initWithMemory:(void *) buf length:(int) len mode:(int) mode
{
  [super init];

  buffer = buf;
  length = len;
  
  switch (mode) {
  case CLReadOnly:
    file = fmemopen((void *) buf, length, "r");
    break;
      
  case CLWriteOnly:
  case CLReadWrite:
    if (!buf)
      freeBuffer = YES;
    file = open_memstream((char **) &buffer, &length);
    break;
  }

  return self;
}

-(id) initWithData:(CLData *) aData mode:(int) mode
{
  data = [aData retain];
  return [self initWithMemory:(void *) [aData bytes] length:[aData length] mode:mode];
}

-(void) dealloc
{
  if (file)
    fclose(file);
  if (buffer && freeBuffer)
    free(buffer);
  [data release];
  [super dealloc];
  return;
}

-(int) readByte
{
  unsigned char buf[4];
  int len;


  len = [self read:buf length:1];
  if (len <= 0)
    return CLEOF;
  return buf[0];
}

-(void) writeByte:(int) c
{
  unsigned char buf[4];


  buf[0] = c;
  [self write:buf length:1];
  return;
}

-(int) read:(void *) buf length:(int) len
{
  return fread(buf, 1, len, file);
}

-(int) write:(const void *) buf length:(int) len
{
  return fwrite(buf, 1, len, file);
}

-(void) close
{
  if (file)
    fclose(file);
  file = NULL;
  return;
}

-(void *) bytes
{
  if (file)
    fflush(file);
  return buffer;
}

-(CLUInteger) length
{
  if (file)
    fflush(file);
  return length;
}

-(CLData *) data
{
  if (data)
    return data;
  if (file)
    fflush(file);
  return [CLData dataWithBytes:buffer length:length];
}

-(int) fileno
{
  return -1;
}

@end
