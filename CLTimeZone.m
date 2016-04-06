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

#import "CLTimeZone.h"
#import "CLDatetime.h"
#import "CLString.h"
#import "CLStream.h"

#include <stdlib.h>
#include <time.h>
#include <string.h>

static CLTimeZone *CLSystemTimeZone = nil, *CLUTCTimeZone = nil;

@implementation CLTimeZone

+(id) timeZoneWithName:(CLString *) aName
{
  return [[[self alloc] initWithName:aName] autorelease];
}

+(id) timeZoneWithSecondsFromGMT:(CLInteger) seconds
{
  CLString *aName;

  
  seconds /= 60;
  if (seconds >= 0)
    aName = [CLString stringWithFormat:@"UTC-%02i:%02i", seconds / 60, seconds % 60];
  else
    aName = [CLString stringWithFormat:@"UTC+%02i:%02i", abs(seconds / 60), abs(seconds % 60)];
  return [self timeZoneWithName:aName];
}

+(id) timeZoneWithOffset:(CLString *) offset
{
  int hours, minutes;


  hours = [offset intValue];
  minutes = hours % 100;
  hours /= 100;
  minutes += hours * 60;
  return [self timeZoneWithSecondsFromGMT:minutes * 60];
}

+(CLTimeZone *) systemTimeZone
{
  if (!CLSystemTimeZone)
    CLSystemTimeZone = [[self timeZoneWithName:nil] retain];
  return CLSystemTimeZone;
}

+(CLTimeZone *) UTCTimeZone
{
  if (!CLUTCTimeZone)
    CLUTCTimeZone = [[self timeZoneWithName:@"UTC+00:00"] retain];
  return CLUTCTimeZone;
}

-(id) init
{
  return [self initWithName:nil];
}

-(id) initWithName:(CLString *) aName
{
  int offset;

  
  [super init];

  if ([aName characterAtIndex:0] == '+' ||
      [aName characterAtIndex:0] == '-') {
    /* FIXME - this seems finicky and changed somewhere between
       versions of Linux I was using */
    offset = [aName intValue];
    offset = -offset;
    aName = [@"UTC" stringByAppendingFormat:@"%02i:%02i", offset / 100, offset % 100];
  }
  else if ([aName isEqualToString:@"PST"] || [aName isEqualToString:@"PDT"])
    aName = @":US/Pacific";
  else if ([aName isEqualToString:@"EST"] || [aName isEqualToString:@"EDT"])
    aName = @":US/Eastern";

  zone = [aName copy];
  oldZone = nil;
  return self;
}

-(void) dealloc
{
  [zone release];
  [oldZone release];
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  [super read:stream];
  [stream readTypes:@"@", &zone];
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeTypes:@"@", &zone];
}

-(void) set
{
  const char *p;


  [oldZone release];
  oldZone = nil;
  if ((p = getenv("TZ")))
    oldZone = [[CLString stringWithUTF8String:p] retain];

  if (zone)
    setenv("TZ", [zone UTF8String], 1);
  else
    unsetenv("TZ");
  tzset();

  return;
}

-(void) unset
{
  if (oldZone)
    setenv("TZ", [oldZone UTF8String], 1);
  else
    unsetenv("TZ");
  tzset();
  return;
}

-(CLInteger) secondsFromGMT
{
  time_t tl, tg;
  struct tm tm, *tp;


  if (_isUTC)
    return 0;
  
  [self set];
  tl = time(NULL);
  tp = gmtime(&tl);
  tm = *tp;
  tm.tm_isdst = -1;
  tg = mktime(&tm);
  [self unset];

  if (!strcmp(tm.tm_zone, "UTC"))
    _isUTC = YES;
  
  return tl - tg;
}

/* FIXME - won't work for dates before 1970 */
-(CLInteger) secondsFromGMTForDate:(CLDatetime *) aDate
{
  time_t tl, tg;
  struct tm tm, *tp;


  if (_isUTC)
    return 0;

  [self set];
  tl = [aDate timeIntervalSince1970];
  tp = gmtime(&tl);
  tm = *tp;
  tm.tm_isdst = -1;
  tg = mktime(&tm);
  [self unset];
  
  if (!strcmp(tm.tm_zone, "UTC"))
    _isUTC = YES;

  return tl - tg;
}

-(CLString *) zone
{
  return zone;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  return [self retain:file :line :retainer];
}
#else
-(id) copy
{
  return [self retain];
}
#endif

@end
