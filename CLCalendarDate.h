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

#import <ClearLake/CLObject.h>

#include <time.h>

typedef double CLTimeInterval;

@class CLString, CLTimeZone;

@interface CLCalendarDate:CLObject <CLCopying, CLPropertyList, CLArchiving>
{
  CLTimeInterval when;
  CLString *format;
  CLTimeZone *zone;
}

+(id) calendarDate;
+(id) dateWithString:(CLString *) description;
+(id) dateWithString:(CLString *) description calendarFormat:(CLString *) format;
+(id) dateWithString:(CLString *) description calendarFormat:(CLString *) format
	    timeZone:(CLTimeZone *) aZone;
+(id) dateWithYear:(CLInteger) year month:(CLUInteger) month day:(CLUInteger) day
	      hour:(CLUInteger) hour minute:(CLUInteger) minute second:(CLUInteger) second
	  timeZone:(CLTimeZone *) aTimeZone;
+(id) dateWithTimeIntervalSince1970:(CLTimeInterval) seconds;

-(id) init;
-(id) initWithString:(CLString *) description;
-(id) initWithString:(CLString *) description calendarFormat:(CLString *) aFormat;
-(id) initWithString:(CLString *) description calendarFormat:(CLString *) aFormat
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

-(CLCalendarDate *) dateByAddingYears:(int) year months:(int) month days:(int) day
				hours:(int) hour minutes:(int) minute seconds:(int) second;
-(void) years:(CLInteger *) yearsPointer months:(CLInteger *) monthsPointer
	 days:(CLInteger *) daysPointer hours:(CLInteger *) hoursPointer
      minutes:(CLInteger *) minutesPointer seconds:(CLInteger *) secondsPointer
    sinceDate:(CLCalendarDate *) date;

-(CLString *) description;
-(CLString *) descriptionWithCalendarFormat:(CLString *) aFormat;
-(CLString *) descriptionWithTimeZone:(CLTimeZone *) aZone;
-(CLString *) descriptionWithCalendarFormat:(CLString *) aFormat
				   timeZone:(CLTimeZone *) aZone;
-(CLComparisonResult) compare:(CLCalendarDate *) aDate;

@end
