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

#import "CLTimeZone.h"
#import "CLString.h"
#import "CLStream.h"
#import "CLCalendarDate.h"

#include <stdlib.h>
#include <time.h>
#include <string.h>

@implementation CLTimeZone

+(id) timeZoneWithName:(CLString *) aName
{
  return [[[self alloc] initWithName:aName] autorelease];
}

+(CLTimeZone *) systemTimeZone
{
  return [self timeZoneWithName:nil];
}

-(id) init
{
  return [self initWithName:nil];
}

-(id) initWithName:(CLString *) aName
{
  [super init];

  if ([aName characterAtIndex:0] == '+' ||
      [aName characterAtIndex:0] == '-')
    aName = [@"UTC" stringByAppendingString:aName];
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

-(id) copy
{
  CLTimeZone *aCopy;


  aCopy = [super copy];
  aCopy->zone = [zone copy];
  aCopy->oldZone = [oldZone copy];
  return aCopy;
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
-(CLInteger) secondsFromGMTForDate:(CLCalendarDate *) aDate
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

@end
