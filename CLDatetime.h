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

#import <ClearLake/CLObject.h>

#include <time.h>

typedef double CLTimeInterval;

@class CLString, CLTimeZone;

@interface CLDatetime:CLObject <CLCopying, CLPropertyList, CLArchiving>
{
  CLTimeInterval when;
  CLString *format;
  CLTimeZone *zone;
}

+(id) now;
+(id) dateWithString:(CLString *) description;
+(id) dateWithString:(CLString *) description format:(CLString *) format;
+(id) dateWithString:(CLString *) description format:(CLString *) format
	    timeZone:(CLTimeZone *) aZone;
+(id) dateWithYear:(CLInteger) year month:(CLUInteger) month day:(CLUInteger) day
	      hour:(CLUInteger) hour minute:(CLUInteger) minute second:(CLUInteger) second
	  timeZone:(CLTimeZone *) aTimeZone;
+(id) dateWithTimeIntervalSince1970:(CLTimeInterval) seconds;

-(id) init;
-(id) initWithString:(CLString *) description;
-(id) initWithString:(CLString *) description format:(CLString *) aFormat;
-(id) initWithString:(CLString *) description format:(CLString *) aFormat
	    timeZone:(CLTimeZone *) aZone;
-(id) initWithTimeIntervalSince1970:(CLTimeInterval) aTime;
-(id) initWithYear:(CLInteger) year month:(CLUInteger) month day:(CLUInteger) day
	      hour:(CLUInteger) hour minute:(CLUInteger) minute second:(CLUInteger) second
	  timeZone:(CLTimeZone *) aTimeZone;

-(void) dealloc;

-(CLTimeInterval) timeIntervalSince1970;
-(CLInteger) dayOfCommonEra;
-(CLInteger) dayOfMonth;
-(CLInteger) dayOfWeek;
-(CLInteger) dayOfYear;
-(CLInteger) hourOfDay;
-(CLInteger) minuteOfHour;
-(CLInteger) monthOfYear;
-(CLInteger) secondOfMinute;
-(CLInteger) yearOfCommonEra;
  
-(CLTimeZone *) timeZone;
-(void) setTimeZone:(CLTimeZone *) aZone;

-(CLDatetime *) dateByAddingYears:(int) year months:(int) month days:(int) day
			    hours:(int) hour minutes:(int) minute seconds:(int) second;
-(void) years:(CLInteger *) yearsPointer months:(CLInteger *) monthsPointer
	 days:(CLInteger *) daysPointer hours:(CLInteger *) hoursPointer
      minutes:(CLInteger *) minutesPointer seconds:(CLInteger *) secondsPointer
    sinceDate:(CLDatetime *) date;

-(CLString *) description;
-(CLString *) descriptionWithFormat:(CLString *) aFormat;
-(CLString *) descriptionWithTimeZone:(CLTimeZone *) aZone;
-(CLString *) descriptionWithFormat:(CLString *) aFormat
				   timeZone:(CLTimeZone *) aZone;
-(CLComparisonResult) compare:(CLDatetime *) aDate;

@end
