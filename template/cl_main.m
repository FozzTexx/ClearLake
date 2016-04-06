/* Copyright 2006-2008 by Chris Osborn <fozztexx@fozztexx.com>
 *
 * $Id$
 */

#import <ClearLake/ClearLake.h>

#include <stdlib.h>
#include <sys/time.h>

int main(int argc, char *argv[])
{
  struct timeval tv;
  CLAutoreleasePool *pool;
  

  pool = [[CLAutoreleasePool alloc] init];
  
  gettimeofday(&tv, NULL);
  srandom(tv.tv_sec + tv.tv_usec);

  CLRun(@"index");
  [pool release];

  exit(0);
}
