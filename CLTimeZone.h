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

@class CLString, CLCalendarDate;

@interface CLTimeZone:CLObject <CLArchiving, CLCopying>
{
  CLString *zone;
  CLString *oldZone;
}

+(id) timeZoneWithName:(CLString *) aName;
+(CLTimeZone *) systemTimeZone;

-(id) init;
-(id) initWithName:(CLString *) aName;
-(void) dealloc;

-(void) set;
-(void) unset;
-(CLInteger) secondsFromGMT;
-(CLInteger) secondsFromGMTForDate:(CLCalendarDate *) aDate;
-(CLString *) zone;

@end
