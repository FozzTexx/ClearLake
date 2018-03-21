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

#import "CLFileStream.h"
#import "CLString.h"

#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/wait.h>
#include <string.h>
#include <fcntl.h>

@implementation CLFileStream

+(CLFileStream *) openFileAtPath:(CLString *) aPath mode:(int) aMode
{
  int fd;
  int mode;


  if (aMode == CLReadOnly)
    mode = O_RDONLY;
  else if (aMode == CLWriteOnly)
    mode = O_WRONLY;
  else if (aMode == CLReadWrite)
    mode = O_RDWR;

  if ((fd = open([aPath UTF8String], mode)))
    return [[[self alloc] initWithDescriptor:fd path:aPath processID:0] autorelease];
  return nil;
}

+(CLFileStream *) streamWithDescriptor:(int) fd mode:(int) aMode
				atPath:(CLString *) aPath processID:(int) aPid
{
  return [[[self alloc] initWithDescriptor:fd path:aPath processID:aPid] autorelease];
}

-(id) init
{
  return [self initWithDescriptor:-1 path:nil processID:0];
}

-(id) initWithDescriptor:(int) aDesc path:(CLString *) aString processID:(int) aPid
{
  [super init];
  fd = aDesc;
  path = [aString copy];
  pid = aPid;
  return self;
}

-(id) initWithFile:(FILE *) aFile path:(CLString *) aString processID:(int) aPid
{
  return [self initWithDescriptor:fileno(aFile) path:aString processID:aPid];
}

-(void) dealloc
{
  [self close];
  [path release];
  [super dealloc];
  return;
}

-(CLString *) path
{
  return path;
}

-(int) pid
{
  return pid;
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

-(int) read:(void *) buffer length:(int) len
{
  return read(fd, buffer, len);
}

-(int) write:(const void *) buffer length:(int) len
{
  return write(fd, buffer, len);
}

-(void) close
{
  if (fd >= 0)
    close(fd);
  fd = -1;
  return;
}

-(void) closeAndRemove
{
  [self close];
  [self remove];
  return;
}

-(int) closeAndWait
{
  int status = 0;

  
  [self close];
  if (pid) {
    waitpid(pid, &status, 0);
    pid = 0;
  }

  return status;
}
  
-(void) remove
{
  unlink([path UTF8String]);
  return;
}

-(int) fileno
{
  return fd;
}

@end
