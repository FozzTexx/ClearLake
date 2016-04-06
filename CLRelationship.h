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

@class CLArray, CLString, CLDictionary, CLMutableDictionary;

@interface CLRelationship:CLObject <CLCopying>
{
  CLArray *ourKeys, *theirKeys;
  CLString *theirTable;
  int isOwner:1;
  int toMany:1;
  int isDependent:1;

  /* Needs some flags about cascade or nullify */
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
-(CLString *) constructQualifierFromKey:(id) aDict;
-(id) constructKey:(id) anObject;
-(void) setDictionary:(CLMutableDictionary *) aDict andRecord:(id) aRecord
	  usingObject:(id) anObject fieldDefinition:(CLDictionary *) fields;
-(void) setDictionary:(CLMutableDictionary *) aDict 
	  usingRecord:(id) anObject fieldDefinition:(CLDictionary *) fields;
-(BOOL) isReciprocal:(CLRelationship *) aRelationship forTable:(CLString *) aTable;

@end
