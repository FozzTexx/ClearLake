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

#import "CLDateFormatter.h"
#import "CLDatetime.h"
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

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLDateFormatter *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
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
  if (![anObject isKindOfClass:CLDatetimeClass])
    return nil;
  
  return [anObject descriptionWithFormat:format];
}

@end
