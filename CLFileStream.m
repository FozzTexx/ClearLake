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

@implementation CLFileStream

+(CLFileStream *) openFileAtPath:(CLString *) aPath mode:(int) aMode
{
  FILE *file;
  char *mode;


  if (aMode == CLReadOnly)
    mode = "r";
  else if (aMode == CLWriteOnly)
    mode = "w";
  else if (aMode == CLReadWrite)
    mode = "w+";

 /* FIXME - should there be a way to do "r+", "a", or "a+" ? */
  
  if ((file = fopen([aPath UTF8String], mode)))
    return [[[self alloc] initWithFile:file path:aPath processID:0] autorelease];
  return nil;
}

+(CLFileStream *) streamWithDescriptor:(int) fd mode:(int) aMode
				atPath:(CLString *) aPath processID:(int) aPid
{
  FILE *file;
  char *mode;


  if (aMode == CLReadOnly)
    mode = "r";
  else if (aMode == CLWriteOnly)
    mode = "w";
  else if (aMode == CLReadWrite)
    mode = "w+";

 /* FIXME - should there be a way to do "r+", "a", or "a+" ? */
  
  if ((file = fdopen(fd, mode)))
    return [[[self alloc] initWithFile:file path:aPath processID:aPid] autorelease];
  return nil;
}

-(id) init
{
  return [self initWithFile:NULL path:nil processID:0];
}

-(id) initWithFile:(FILE *) aFile path:(CLString *) aString processID:(int) aPid
{
  [super init];
  file = aFile;
  path = [aString copy];
  pid = aPid;
  return self;
}

-(void) dealloc
{
  if (file)
    fclose(file);
  [path release];
  [super dealloc];
  return;
}

-(FILE *) file
{
  return file;
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
  return fread(buffer, 1, len, file);
}

-(int) write:(const void *) buffer length:(int) len
{
  return fwrite(buffer, 1, len, file);
}

-(void) close
{
  if (file)
    fclose(file);
  file = NULL;
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

@end
