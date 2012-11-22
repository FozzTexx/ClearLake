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

#define _ISOC9X_SOURCE
#define _XOPEN_SOURCE
#define _BSD_SOURCE

#import "CLCalendarDate.h"
#import "CLString.h"
#import "CLTimeZone.h"
#import "CLStream.h"
#import "CLRegularExpression.h"
#import "CLArray.h"
#import "CLValue.h"

#include <time.h>
#include <stdlib.h>

#define CLGregorianOffset	719163

 CLUInteger CLLastDayOfGregorianMonth(CLUInteger month, CLUInteger year)
{
  switch (month) {
  case 2:
    if ((((year % 4) == 0) && ((year % 100) != 0))
	|| ((year % 400) == 0))
      return 29;
    else
      return 28;
  case 4:
  case 6:
  case 9:
  case 11: return 30;
  default: return 31;
  }
}

 CLUInteger CLAbsoluteGregorianDay(CLUInteger day, CLUInteger month,
					    CLUInteger year)
{
  if (month > 1)
    while (--month)
      day += CLLastDayOfGregorianMonth(month, year);
  
  if (year)
    year--;

  return
    (day            // days this year
     + 365 * year   // days in previous years ignoring leap days
     + year/4       // Julian leap days before this year...
     - year/100     // ...minus prior century years...
     + year/400);   // ...plus prior years divisible by 400
}

 CLTimeInterval CLMakeTime(CLUInteger year, CLUInteger month, CLUInteger day,
			   CLUInteger hour, CLUInteger minute, CLUInteger second)
{
  CLTimeInterval a;
  

  a = CLAbsoluteGregorianDay(day, month, year);

  // Calculate date as GMT
  a -= CLGregorianOffset;
  a = a * 86400;
  a += hour * 3600;
  a += minute * 60;
  a += second;

  return a;
}

 void CLGregorianDateFromAbsolute(CLTimeInterval abs, int *day,
					   int *month, int *year)
{
  *year = abs / 366;
  while (abs >= CLAbsoluteGregorianDay(1, 1, (*year)+1))
    (*year)++;

  *month = 1;
  while (abs >
	 CLAbsoluteGregorianDay(CLLastDayOfGregorianMonth(*month, *year), *month, *year))
    (*month)++;
  *day = abs - CLAbsoluteGregorianDay(1, *month, *year) + 1;
}

@implementation CLCalendarDate

+(id) calendarDate
{
  return [[[self alloc] init] autorelease];
}

+(id) dateWithString:(CLString *) description
{
  return [[[self alloc] initWithString:description] autorelease];
}

+(id) dateWithString:(CLString *) description calendarFormat:(CLString *) format
{
  return [[[self alloc] initWithString:description calendarFormat:format
				  timeZone:nil]
	   autorelease];
}

+(id) dateWithString:(CLString *) description calendarFormat:(CLString *) format
	    timeZone:(CLTimeZone *) aZone
{
  return [[[self alloc] initWithString:description calendarFormat:format
				  timeZone:aZone]
	   autorelease];
}

+(id) dateWithYear:(CLInteger) year month:(CLUInteger) month day:(CLUInteger) day
	      hour:(CLUInteger) hour minute:(CLUInteger) minute second:(CLUInteger) second
	  timeZone:(CLTimeZone *) aTimeZone
{
  return [[[self alloc] initWithYear:year month:month day:day hour:hour minute:minute
			second:second timeZone:aTimeZone] autorelease];
}

+(id) dateWithTimeIntervalSince1970:(CLTimeInterval) seconds
{
  return [[[self alloc] initWithTimeIntervalSince1970:seconds] autorelease];
}

-(id) init
{
  [super init];
  when = time(NULL);
  format = @"%Y-%m-%d %H:%M:%S %z";
  zone = [[CLTimeZone systemTimeZone] retain];
  return self;
}

-(id) initWithString:(CLString *) description
{
  return [self initWithString:description calendarFormat:nil timeZone:nil];
}

-(id) initWithString:(CLString *) description calendarFormat:(CLString *) aFormat
{
  return [self initWithString:description calendarFormat:aFormat timeZone:nil];
}

-(id) initWithString:(CLString *) description calendarFormat:(CLString *) aFormat
	    timeZone:(CLTimeZone *) aZone
{
  struct tm tm;
  int offset = 0;


  if (!aFormat)
    aFormat = @"%Y-%m-%d %H:%M:%S %z";
  memset(&tm, 0, sizeof(tm));
  tm.tm_isdst = -1;
  strptime([description UTF8String], [aFormat UTF8String], &tm);

  {
    CLRange aRange;
    CLString *aString;
    CLRegularExpression *aRegex;
    const char *p;
    char *tbuf;
    size_t tsize;
    CLArray *anArray;
    CLTimeZone *dZone;


    aRange = [aFormat rangeOfString:@"%z"];
    if (!aRange.length)
      aRange = [aFormat rangeOfString:@"%Z"];
    if (aRange.length) {
      aString = [aFormat stringByReplacingCharactersInRange:aRange withString:@"(.*)"];
      p = [aString UTF8String];
      tsize = 40;
      if (!(tbuf = malloc(tsize)))
	[self error:@"Unable to allocate memory"];
      while (!strftime(tbuf, tsize, p, &tm)) {
	tsize *= 2;
	if (!(tbuf = realloc(tbuf, tsize)))
	  [self error:@"Unable to allocate memory"];
      }
      aString = [CLString stringWithUTF8String:tbuf];
      free(tbuf);

      aRegex = [CLRegularExpression regularExpressionFromString:aString];
      if ([aRegex matchesString:description substringRanges:&anArray]) {
	aRange = [[anArray objectAtIndex:1] rangeValue];
	aString = [description substringWithRange:aRange];
	dZone = [[CLTimeZone alloc] initWithName:aString];
	/* If aZone is already set, should we calculate some kind of offset? */
	if (!aZone)
	  aZone = dZone;
      }
    }
  }

  [self initWithYear:tm.tm_year + 1900 month:tm.tm_mon + 1 day:tm.tm_mday
	hour:tm.tm_hour minute:tm.tm_min second:tm.tm_sec + offset timeZone:aZone];
  [format release];
  format = [aFormat copy];

  return self;
}

-(id) initWithTimeIntervalSince1970:(CLTimeInterval) aTime
{
  [self init];
  when = aTime;
  return self;
}

-(id) initWithYear:(CLInteger) year month:(CLUInteger) month day:(CLUInteger) day
	      hour:(CLUInteger) hour minute:(CLUInteger) minute second:(CLUInteger) second
	  timeZone:(CLTimeZone *) aTimeZone
{
  CLInteger off1, off2;

  
  [self init];
  if (!aTimeZone)
    aTimeZone = [CLTimeZone systemTimeZone];
  when = CLMakeTime(year, month, day, hour, minute, second);
  off1 = [aTimeZone secondsFromGMTForDate:self];
  when -= off1;
  off2 = [aTimeZone secondsFromGMTForDate:self];
  if (off1 != off2) {
    when -= off2 - off1;
    off1 = [aTimeZone secondsFromGMTForDate:self];
    if (off1 != off2)
      [self error:@"Can't figure out what date you're talking about:"
	    " %u %u %u %u %u %u %s", year, month, day, hour, minute, second,
	    [[aTimeZone zone] UTF8String]];
  }
  [self setTimeZone:aTimeZone];
  return self;
}

-(void) dealloc
{
  [format release];
  [zone release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLCalendarDate *aCopy;


  aCopy = [super copy];
  aCopy->when = when;
  aCopy->format = [format copy];
  aCopy->zone = [zone retain];
  return aCopy;
}

-(void) read:(CLTypedStream *) stream
{
  [super read:stream];
  CLReadTypes(stream, "l@@", &when, &format, &zone);
  return;
}

-(void) write:(CLTypedStream *) stream
{
  [super write:stream];
  CLWriteTypes(stream, "l@@", &when, &format, &zone);
  return;
}

-(CLTimeInterval) timeIntervalSince1970
{
  return when;
}

-(struct tm) breakTime:(CLTimeZone *) aZone
{
  static struct tm tm;
  CLTimeInterval t;
  int y, m, d;
  long long days;
  long long H, M, S, T;
  int i;


  t = when + [aZone secondsFromGMTForDate:self];
  days = t / 86400 + CLGregorianOffset;
  CLGregorianDateFromAbsolute(days, &d, &m, &y);

  memset(&tm, 0, sizeof(tm));
  tm.tm_isdst = -1;
  tm.tm_year = y - 1900;
  tm.tm_mon = m - 1;
  tm.tm_mday = d;
  tm.tm_wday = days % 7;
  if (tm.tm_wday < 0)
    tm.tm_wday += 7;
  tm.tm_yday = d;
  for (i = m - 1; i > 0; i--)
    tm.tm_yday += CLLastDayOfGregorianMonth(i, y);

  days -= CLGregorianOffset;
  T = days * 86400;
  H = llabs(T - t);
  S = H % 60;
  M = (H % 3600) / 60;
  H /= 3600;
  if (H == 24)
    H = 0;

  tm.tm_hour = H;
  tm.tm_min = M;
  tm.tm_sec = S;

  return tm;
}

-(CLInteger) dayOfCommonEra
{
  int days;


  days = (when + [zone secondsFromGMTForDate:self]) / 86400;
  days += CLGregorianOffset;
  return days;
}

-(CLInteger) dayOfMonth
{
  struct tm tm;


  tm = [self breakTime:zone];
  return tm.tm_mday;
}

-(CLInteger) dayOfWeek
{
  int d;


  d = [self dayOfCommonEra] % 7;
  if (d < 0)
    d += 7;
  return d;
}

-(CLInteger) dayOfYear
{
  int d, m, y, i;


  CLGregorianDateFromAbsolute([self dayOfCommonEra], &d, &m, &y);
  for (i = m - 1; i > 0; i--)
    d += CLLastDayOfGregorianMonth(i, y);
  return d;
}

-(CLInteger) hourOfDay
{
  struct tm tm;


  tm = [self breakTime:zone];
  return tm.tm_hour;
}

-(CLInteger) minuteOfHour
{
  struct tm tm;


  tm = [self breakTime:zone];
  return tm.tm_min;
}

-(CLInteger) monthOfYear
{
  struct tm tm;


  tm = [self breakTime:zone];
  return tm.tm_mon + 1;
}

-(CLInteger) secondOfMinute
{
  struct tm tm;


  tm = [self breakTime:zone];
  return tm.tm_sec;
}

-(CLInteger) yearOfCommonEra
{
  struct tm tm;


  tm = [self breakTime:zone];
  return tm.tm_year + 1900;
}

-(CLTimeZone *) timeZone
{
  return zone;
}

-(void) setTimeZone:(CLTimeZone *) aZone
{
  [zone autorelease];
  if (!aZone)
    aZone = [CLTimeZone systemTimeZone];
  zone = [aZone retain];
  return;
}

-(CLCalendarDate *) dateByAddingYears:(int) year months:(int) month days:(int) day
				hours:(int) hour minutes:(int) minute seconds:(int) second
{
  struct tm tm;
  CLInteger off1, off2;
  CLCalendarDate *newDate;
  int i;


  tm = [self breakTime:zone];

  while (year || month || day || hour || minute || second) {
    tm.tm_year += year;
    year = 0;

    tm.tm_mon += month;
    month = 0;
    while (tm.tm_mon > 11) {
      tm.tm_year++;
      tm.tm_mon -= 12;
    }
    while (tm.tm_mon < 0) {
      tm.tm_year--;
      tm.tm_mon += 12;
    }

    tm.tm_mday += day;
    day = 0;
    if (tm.tm_mday > 28) {
      i = CLLastDayOfGregorianMonth(tm.tm_mon + 1, tm.tm_year + 1900);
      while (tm.tm_mday > i) {
	tm.tm_mday -= i;
	if (tm.tm_mon < 11)
	  tm.tm_mon++;
	else {
	  tm.tm_mon = 0;
	  tm.tm_year++;
	}
	i = CLLastDayOfGregorianMonth(tm.tm_mon + 1, tm.tm_year + 1900);
      }
    }
    else {
      while (tm.tm_mday < 1) {
	if (tm.tm_mon == 0) {
	  tm.tm_year--;
	  tm.tm_mon = 11;
	}
	else
	  tm.tm_mon--;
	tm.tm_mday += CLLastDayOfGregorianMonth(tm.tm_mon + 1, tm.tm_year + 1900);
      }
    }

    tm.tm_hour += hour;
    hour = 0;
    day += tm.tm_hour / 24;
    tm.tm_hour %= 24;
    if (tm.tm_hour < 0) {
      day--;
      tm.tm_hour += 24;
    }

    tm.tm_min += minute;
    minute = 0;
    hour += tm.tm_min / 60;
    tm.tm_min %= 60;
    if (tm.tm_min < 0) {
      hour--;
      tm.tm_min += 60;
    }

    tm.tm_sec += second;
    second = 0;
    minute += tm.tm_sec / 60;
    tm.tm_sec %= 60;
    if (tm.tm_sec < 0) {
      minute--;
      tm.tm_sec += 60;
    }
  }

  newDate = [CLCalendarDate alloc];
  newDate->format = [format copy];
  newDate->zone = [zone retain];
  off1 = [zone secondsFromGMTForDate:self];
  newDate->when = CLMakeTime(tm.tm_year + 1900, tm.tm_mon + 1, tm.tm_mday,
			     tm.tm_hour, tm.tm_min, tm.tm_sec) - off1;
  off2 = [zone secondsFromGMTForDate:newDate];
  if (off1 != off2) {
    newDate->when -= off2 - off1;
    off1 = [zone secondsFromGMTForDate:newDate];
    if (off1 != off2)
      [self error:@"Can't figure out what date you're talking about"];
  }

  return [newDate autorelease];
}

-(void) years:(CLInteger *) yearsPointer months:(CLInteger *) monthsPointer
	 days:(CLInteger *) daysPointer hours:(CLInteger *) hoursPointer
      minutes:(CLInteger *) minutesPointer seconds:(CLInteger *) secondsPointer
    sinceDate:(CLCalendarDate *) date
{
  CLCalendarDate *start, *end;
  int diff, extra, sign;
  struct tm stm, etm;


  if ([self compare:date] > 0) {
    end = self;
    start = date;
    sign = 1;
  }
  else {
    end = date;
    start = self;
    sign = -1;
  }

  stm = [start breakTime:[start timeZone]];
  etm = [end breakTime:[end timeZone]];

  if (etm.tm_sec < stm.tm_sec) {
    etm.tm_min -= 1;
    etm.tm_sec += 60;
  }
  if (etm.tm_min < stm.tm_min) {
    etm.tm_hour -= 1;
    etm.tm_min += 60;
  }
  if (etm.tm_hour < stm.tm_hour) {
    etm.tm_mday -= 1;
    etm.tm_hour += 24;
  }
  if (etm.tm_mday < stm.tm_mday) {
    etm.tm_mon -= 1;
    if (etm.tm_mon >= 0)
      etm.tm_mday += CLLastDayOfGregorianMonth(etm.tm_mon + 1, etm.tm_year + 1900);
    else
      etm.tm_mday += 31;
  }
  if (etm.tm_mon < stm.tm_mon || (etm.tm_mon == stm.tm_mon && etm.tm_mday < stm.tm_mday)) {
    etm.tm_year -= 1;
    etm.tm_mon += 12;
  }

  /* Calculate year difference and leave any remaining months in 'extra' */
  diff = etm.tm_year - stm.tm_year;
  extra = 0;
  if (yearsPointer)
    *yearsPointer = sign*diff;
  else
    extra += diff*12;

  /* Calculate month difference and leave any remaining days in 'extra' */
  diff = etm.tm_mon - stm.tm_mon + extra;
  extra = 0;
  if (monthsPointer)
    *monthsPointer = sign*diff;
  else {
    while (diff-- > 0) {
      int tmpmonth = etm.tm_mon - diff - 1;
      int tmpyear = etm.tm_year;

      while (tmpmonth < 0) {
	tmpmonth += 12;
	tmpyear--;
      }
      extra += CLLastDayOfGregorianMonth(tmpmonth + 1, tmpyear + 1900);
    }
  }

  /* Calculate day difference and leave any remaining hours in 'extra' */
  diff = etm.tm_mday - stm.tm_mday + extra;
  extra = 0;
  if (daysPointer)
    *daysPointer = sign*diff;
  else
    extra += diff*24;

  /* Calculate hour difference and leave any remaining minutes in 'extra' */
  diff = etm.tm_hour - stm.tm_hour + extra;
  extra = 0;
  if (hoursPointer)
    *hoursPointer = sign*diff;
  else
    extra += diff*60;

  /* Calculate minute difference and leave any remaining seconds in 'extra' */
  diff = etm.tm_min - stm.tm_min + extra;
  extra = 0;
  if (minutesPointer)
    *minutesPointer = sign*diff;
  else
    extra += diff*60;

  diff = etm.tm_sec - stm.tm_sec + extra;
  if (secondsPointer)
    *secondsPointer = sign*diff;
}

-(CLString *) propertyList
{
  /* Write it out the GNUstep way */
  return [CLString stringWithFormat:@"<*D%@>",
		   [self descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S +0000"
			 timeZone:[CLTimeZone timeZoneWithName:@"UTC+0000"]]];
}

-(CLString *) json
{
  return [[self descriptionWithCalendarFormat:@"%Y-%m-%d %H:%M:%S +0000"
		timeZone:[CLTimeZone timeZoneWithName:@"UTC+0000"]] json];
}

-(CLString *) description
{
  return [self descriptionWithTimeZone:nil];
}

-(CLString *) descriptionWithCalendarFormat:(CLString *) aFormat
{
  return [self descriptionWithCalendarFormat:aFormat timeZone:nil];
}

-(CLString *) descriptionWithTimeZone:(CLTimeZone *) aZone
{
  return [self descriptionWithCalendarFormat:format timeZone:aZone];
}

-(CLString *) descriptionWithCalendarFormat:(CLString *) aFormat
				   timeZone:(CLTimeZone *) aZone
{
  struct tm tm;
  char *tbuf;
  size_t tsize;
  CLString *aString;
  const char *p;
  CLInteger offset;


  if (!aZone)
    aZone = zone;
  
  tm = [self breakTime:aZone];

  offset = [aZone secondsFromGMTForDate:self] / 60;
  if (!offset)
    aString = @"Z";
  else
    aString = [CLString stringWithFormat:@"%c%02i%02i",
			offset < 0 ? '-' : '+',
			abs(offset) / 60, abs(offset) % 60];
  /* FIXME - parse the string correctly, %%z will end up getting mangled */
  aFormat = [aFormat stringByReplacingOccurrencesOfString:@"%z" withString:aString];
  
  p = [aFormat UTF8String];
  tsize = 40;
  if (!(tbuf = malloc(tsize)))
    [self error:@"Unable to allocate memory"];
  while (!strftime(tbuf, tsize, p, &tm)) {
    tsize *= 2;
    if (!(tbuf = realloc(tbuf, tsize)))
      [self error:@"Unable to allocate memory"];
  }

  aString = [CLString stringWithUTF8String:tbuf];
  free(tbuf);
  return aString;
}

-(CLComparisonResult) compare:(CLCalendarDate *) aDate
{
  if (!aDate)
    return CLOrderedDescending;
  
  if (when < aDate->when)
    return CLOrderedAscending;
  if (when > aDate->when)
    return CLOrderedDescending;
  return CLOrderedSame;
}

@end
