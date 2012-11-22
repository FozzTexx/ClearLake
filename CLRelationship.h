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

@class CLArray, CLString, CLDictionary, CLMutableDictionary;

@interface CLRelationship:CLObject <CLCopying>
{
  CLArray *ourKeys, *theirKeys;
  CLString *theirTable;
  BOOL isOwner, toMany, isDependent;
}

-(id) init;
-(id) initFromString:(CLString *) aString databaseName:(CLString *) aDatabase;
-(void) dealloc;

-(CLString *) theirTable;
-(CLArray *) ourKeys;
-(CLArray *) theirKeys;
-(BOOL) isOwner;
-(BOOL) toMany;
-(BOOL) isDependent;
-(void) setDependent:(BOOL) flag;
-(CLString *) constructQualifier:(id) anObject;
-(CLString *) constructQualifierFromDictionary:(CLDictionary *) aDict;
-(CLDictionary *) constructKey:(id) anObject;
-(void) setDictionary:(CLMutableDictionary *) aDict andRecord:(id) aRecord
	  usingObject:(id) anObject fieldDefinition:(CLDictionary *) fields;
-(void) setDictionary:(CLMutableDictionary *) aDict 
	  usingRecord:(id) anObject fieldDefinition:(CLDictionary *) fields;
-(BOOL) isReciprocal:(CLRelationship *) aRelationship forTable:(CLString *) aTable;

@end
