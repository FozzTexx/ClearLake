/* Copyright 2013-2016 by
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

#import "CLHeader.h"

/* This is sort of like a CLDictionary except that it keeps track of
   what order things are in and you can have multiple headers with the
   same name. Automatically adds/removes ':' from header names. Deals
   with "From " header which has no ':'. */

@implementation CLHeader

-(id) init
{
  return [self initFromString:nil];
}

-(id) initFromString:(CLString *) aString
{
  CLStringStorage *stor;

  
  [super init];
  headers = [[CLMutableArray alloc] init];
  values = [[CLMutableArray alloc] init];

  if ([aString length]) {
    stor = CLStringStorage(aString);
    
  }
  
  return self;
}

-(void) dealloc
{
  [headers release];
  [values release];
  [super dealloc];
  return;
}

/* Will return an array if there is more than one of the same header */
-(id) valueOfHeader:(CLString *) aHeader
{
  id found, aValue;
  int i, j;


  found = [[CLMutableArray alloc] init];
  for (i = 0, j = [headers count]; i < j; i++)
    if ([[header objectAtIndex:i] isEqualToString:aHeader])
      [found addObject:[values objectAtIndex:i]];

  if (![found count]) {
    [found release];
    found = nil;
  }
  else if ([found count] == 1) {
    aValue = [found objectAtIndex:0];
    [found release];
    found = aValue;
  }
  else
    [found autorelease];

  return found;
}
  
-(void) insertHeader:(CLString *) aHeader withValue:(CLString *) aValue atIndex:(int) anIndex
{
}

-(void) addHeader:(CLString *) aHeader withValue:(CLString *) aValue
{
}

-(void) deleteHeader:(CLString *) aHeader
{
}
			
@end
