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

#import "CLDateFormatter.h"
#import "CLCalendarDate.h"
#import "CLString.h"

@implementation CLDateFormatter

+(CLDateFormatter *) dateFormatterFromFormat:(CLString *) aFormat
{
  CLDateFormatter *aFormatter;


  aFormatter = [[[self alloc] init] autorelease];
  [aFormatter setFormat:aFormat];
  return aFormatter;
}  

-(id) init
{
  [super init];
  format = nil;
  return self;
}

-(void) dealloc
{
  [format release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLDateFormatter *aCopy;


  aCopy = [super copy];
  aCopy->format = [format copy];
  return aCopy;
}

-(void) setFormat:(CLString *) aFormat
{
  [format autorelease];
  format = [aFormat retain];
  return;
}

-(CLString *) stringForObjectValue:(id) anObject
{
  if (![anObject isKindOfClass:[CLCalendarDate class]])
    return nil;
  
  return [anObject descriptionWithCalendarFormat:format];
}

@end
