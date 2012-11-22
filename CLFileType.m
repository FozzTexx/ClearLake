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

#import "CLFileType.h"
#import "CLMutableArray.h"
#import "CLOption.h"
#import "CLNumber.h"

static CLMutableArray *_allTypes;

@implementation CLFileType

/* This really should be a class method, but when processing bindings
   CLPage will create an instance of the class */
-(CLArray *) allTypes
{
  CLArray *anArray;
  int i, j;
  CLFileType *aType;

  
  if (!_allTypes) {
    _allTypes = [[CLMutableArray alloc] init];
    anArray = [CLGenericRecord loadTable:[self table] qualifier:nil];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aType = [anArray objectAtIndex:i];
      [_allTypes addObject:[CLOption optionWithString:[aType title]
				     andValue:[CLNumber numberWithInt:[aType objectID]]]];
    }    
  }

  return _allTypes;
}

@end
