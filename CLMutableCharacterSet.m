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

#import "CLMutableCharacterSet.h"
#import "CLMutableString.h"

@interface CLCharacterSet (CLPrivateMethods)
-(id) initFromString:(CLString *) aString;
@end

@implementation CLMutableCharacterSet

-(id) initFromString:(CLString *) aString
{
  [super initFromString:aString];
  [string release];
  string = [[CLMutableString alloc] init];
  if (aString)
    [string setString:aString];
  return self;
}
  
-(id) copy
{
  return [self mutableCopy];
}

-(void) addCharactersInString:(CLString *) aString
{
  [string appendString:aString];
  return;
}

#if 0
-(void) removeCharactersInString:(CLString *) aString
{
  return;
}

-(void) formIntersectionWithCharacterSet:(CLCharacterSet *) otherSet
{
  return;
}
#endif

-(void) formUnionWithCharacterSet:(CLCharacterSet *) otherSet
{
  [self addCharactersInString:otherSet->string];
  return;
}

-(void) invert
{
  inverted = !inverted;
}

@end
