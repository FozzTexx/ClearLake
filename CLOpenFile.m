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

#import "CLOpenFile.h"
#import "CLString.h"

#include <unistd.h>
#include <sys/wait.h>

@implementation CLOpenFile

+(CLOpenFile *) openFileAtPath:(CLString *) aString mode:(CLString *) aMode
{
  FILE *file;


  if ((file = fopen([aString UTF8String], [aMode UTF8String])))
    return [[[self alloc] initWithFile:file path:aString pid:0] autorelease];
  return nil;
}

-(id) initWithFile:(FILE *) aFile path:(CLString *) aString pid:(int) aPid
{
  [super init];
  file = aFile;
  path = [aString copy];
  pid = aPid;
  return self;
}

-(void) dealloc
{
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
