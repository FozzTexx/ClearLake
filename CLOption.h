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

#import <ClearLake/CLElement.h>
#import <ClearLake/CLStream.h>

@class CLString, CLArray, CLMutableArray, CLMutableDictionary;

@interface CLOption:CLElement <CLCopying>
{
  id value;
  BOOL selected;
  CLMutableArray *subOptions; /* For CLChainedSelect */
}

+(CLOption *) optionWithString:(CLString *) aString andValue:(id) aValue;
+(CLOption *) optionWithString:(CLString *) aString andValue:(id) aValue
		      selected:(BOOL) flag;

-(id) initWithString:(CLString *) aString andValue:(id) aValue;
-(id) initWithString:(CLString *) aString andValue:(id) aValue selected:(BOOL) flag;
-(void) dealloc;

-(id) value;
-(CLString *) string;
-(BOOL) selected;
-(CLArray *) subOptions;
-(CLMutableDictionary *) attributes;

-(void) setValue:(id) anObject;
-(void) setString:(CLString *) aString;
-(void) setSelected:(BOOL) flag;
-(void) addSubOption:(CLOption *) anOption;
-(void) writeHTML:(CLStream *) stream;

@end
