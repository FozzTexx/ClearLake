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

@class CLArray, CLMutableArray;

@interface CLEmailHeader:CLObject <CLCopying>
{
  CLMutableArray *headers, *values;
}

-(id) init;
-(id) initFromString:(CLString *) aString; /* This is the designated initializer */
-(void) dealloc;

-(void) setHeadersFromString:(CLString *) aString;
-(id) valueOfHeader:(CLString *) aHeader;
-(void) appendHeader:(CLString *) aHeader withValue:(id) aValue;
-(void) setValue:(id) aValue forHeader:(CLString *) aHeader;
-(void) removeHeader:(CLString *) aHeader;
-(CLString *) description;
-(void) updateBindings:(id) datasource;

-(CLArray *) headers;

@end
