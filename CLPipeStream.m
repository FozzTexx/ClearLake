/* Copyright 2015-2016 by
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

#import "CLPipeStream.h"
#import "CLArray.h"

#include <unistd.h>
#include <fcntl.h>
#include <sys/wait.h>
#include <string.h>

@implementation CLPipeStream

+(CLPipeStream *) streamWithCommand:(CLString *) aCommand mode:(int) aMode
{
  return [[[self alloc] initWithCommand:aCommand mode:aMode] autorelease];
}

+(CLPipeStream *) streamWithExecutable:(CLString *) aCommand arguments:(CLArray *) args
				 stdin:(int) sin stdout:(int) sout stderr:(int) serr
{
  return [[[self alloc] initWithExecutable:aCommand arguments:args
				     stdin:sin stdout:sout stderr:serr] autorelease];
}

-(id) init
{
  return [self initWithCommand:nil mode:CLReadWrite];
}

-(id) initWithCommand:(CLString *) aCommand mode:(int) aMode
{
  int wp[2], rp[2];
  int tty, fd, maxf;


  [super init];
  
  pipe(wp);
  pipe(rp);

  pid = fork();
  if (pid > 0) {
    close(wp[0]);
    close(rp[1]);
    rfd = rp[0];
    wfd = wp[1];
    
    if (aMode == CLReadOnly) {
      close(wfd);
      wfd = -1;
    }
    else if (aMode == CLWriteOnly) {
      close(rfd);
      rfd = -1;
    }
  }
  else if (pid == 0) { /* child */
    dup2(wp[0], 0);
    dup2(rp[1], 1);
    dup2(rp[1], 2);

    maxf = getdtablesize();
    for (fd = 3; fd < maxf; fd++)
      close(fd);

    if ((tty = open("/dev/tty", O_RDWR)) >= 0) {
      ioctl(tty, TIOCNOTTY, 0);
      close(tty);
    }
    
    execl("/bin/sh", "/bin/sh", "-c", [aCommand UTF8String], NULL);
  }

  return self;
}

-(id) initWithExecutable:(CLString *) aCommand arguments:(CLArray *) args
		   stdin:(int) sin stdout:(int) sout stderr:(int) serr
{
  int tty, fd, maxf;
  char **strargs;
  int i, j;


  [super init];
  
  pid = fork();
  if (pid > 0) {
    rfd = sout;
    wfd = sin;
  }
  else if (pid == 0) { /* child */
    dup2(sin, 0);
    dup2(sout, 1);
    dup2(serr, 2);

    maxf = getdtablesize();
    for (fd = 3; fd < maxf; fd++)
      close(fd);

    if ((tty = open("/dev/tty", O_RDWR)) >= 0) {
      ioctl(tty, TIOCNOTTY, 0);
      close(tty);
    }

    strargs = calloc([args count] + 1, sizeof(char *));
    for (i = 0, j = [args count]; i < j; i++)
      strargs[i] = strdup([[[args objectAtIndex:i] description] UTF8String]);
    execvp([aCommand UTF8String], strargs);
  }

  return self;
}

-(void) dealloc
{
  [self close];
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

-(int) read:(void *) buffer length:(int) len
{
  return read(rfd, buffer, len);
}

-(int) write:(const void *) buffer length:(int) len
{
  return write(wfd, buffer, len);
}

-(void) close
{
  [self closeRead];
  [self closeWrite];
  return;
}

-(void) closeRead
{
  if (rfd >= 0) {
    close(rfd);
    rfd = -1;
  }
  return;
}

-(void) closeWrite
{
  if (wfd >= 0) {
    close(wfd);
    wfd = -1;
  }
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

-(int) pid
{
  return pid;
}

@end
