/* Copyright 2012 by Traction Systems, LLC. <http://tractionsys.com/>
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

  if (!buf && mode == CLAppend)
    mode = CLWriteOnly;
  
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

  case CLAppend:
    /* FIXME - fmemopen can open in append mode but will seek to the
       first null byte and can't grow the buffer. open_memstream needs
       to create its own buffer in order to add data. Could use
       open_memstream and copy the contents of the passed buffer, but
       if caller is expecting to write to same location, that isn't
       quite correct. Probably best to let caller open new buffer and
       add data themselves. */
    [self error:@"Appending to memory is not supported"];
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

/* FIXME - need to read up to a newline in the encoding, not in ascii/UTF8 */
-(CLString *) readStringUsingEncoding:(CLStringEncoding) enc
{
  char *buf, *err;
  size_t buflen = 0;
  int pos;
  CLString *aString;


  buf = malloc(buflen = 256);
  pos = 0;
  while ((err = fgets(buf + pos, buflen - pos, file))) {
    pos = strlen(buf);
    if (buf[pos-1] == '\n')
      break;
    if (buflen - pos < 2)
      buf = realloc(buf, buflen *= 2);
  }

  if (pos || err)  {
    aString = [CLString stringWithBytes:buf length:pos encoding:enc];
    free(buf);
  }
  else {
    aString = nil;
    free(buf);
  }
  
  return aString;
}

@end
