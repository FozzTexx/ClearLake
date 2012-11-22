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

@class CLString, CLArray;

typedef enum {
  CLVarcharAttributeType = 1,
  CLIntAttributeType,
  CLDatetimeAttributeType,
  CLMoneyAttributeType,
  CLNumericAttributeType,
  CLCharAttributeType,
} CLAttributeType;

@interface CLAttribute:CLObject <CLCopying>
{
  CLString *name;
  CLAttributeType externalType;
  BOOL primaryKey;
}

+(CLAttribute *) attributeFromString:(CLString *) aString;

-(id) init;
-(id) initFromString:(CLString *) aString;
-(void) dealloc;

-(CLString *) name;
-(CLAttributeType) externalType;
-(BOOL) isPrimaryKey;

-(void) setName:(CLString *) aName;
-(void) setExternalType:(CLAttributeType) aType;
-(void) setPrimaryKey:(BOOL) aFlag;

@end

extern CLArray *CLAttributes(CLString *name, ...);
extern CLArray *CLAttributesFromArray(CLArray *anArray);
extern CLAttributeType CLAttributeTypeFor(int aType);
