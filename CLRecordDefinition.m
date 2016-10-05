/* Copyright 2012-2016 by
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

#import "CLRecordDefinition.h"
#import "CLRange.h"
#import "CLString.h"
#import "CLDictionary.h"
#import "CLAttribute.h"
#import "CLEditingContext.h"
#import "CLMutableArray.h"
#import "CLStackString.h"
#import "CLRelationship.h"
#import "CLClassConstants.h"

@implementation CLRecordDefinition

-(id) init
{
  return [self initFromTable:nil class:nil fields:nil relationships:nil];
}

-(id) initFromTable:(CLString *) aTable class:(Class) aClass
	     fields:(CLDictionary *) fieldsDict relationships:(CLDictionary *) relDict
{
  CLRange aRange;

  
  [super init];
  table = [aTable copy];
  aRange = [table rangeOfString:@"."];
  databaseTable = [[table substringFromIndex:CLMaxRange(aRange)] retain];
  db = nil;
  recordClass = aClass;
  fields = [fieldsDict copy];
  relationships = [relDict copy];
  _primaryKeys = nil;
  return self;
}

-(void) dealloc
{
  [table release];
  [databaseTable release];
  [fields release];
  [relationships release];
  [_primaryKeys release];
  [super dealloc];
  return;
}

-(CLString *) table
{
  return table;
}

-(CLString *) databaseTable
{
  return databaseTable;
}

-(CLDatabase *) database
{
  CLRange aRange;
  unistr ustr;

  
  if (!db) {
    aRange = [table rangeOfString:@"."];
    ustr = CLCloneStackString(table);
    ustr.len = aRange.location;
    db = [CLEditingContext databaseNamed:(CLString *) &ustr];
  }
  
  return db;
}

#if 0
-(Class) class
{
  [self error:@"I'll bet this isn't what you wanted"];
  return recordClass;
}
#endif

-(Class) recordClass
{
  return recordClass;
}

-(CLDictionary *) fields
{
  return fields;
}

-(CLDictionary *) relationships
{
  return relationships;
}

-(CLString *) columnNameForKey:(CLString *) aKey
{
  return [[fields objectForKey:aKey] column];
}

-(CLArray *) primaryKeys
{
  CLMutableArray *mArray;
  int i, j;
  CLArray *anArray;
  CLAttribute *anAttr;


  if (!_primaryKeys) {
    mArray = [[CLMutableArray alloc] init];
    anArray = [fields allValues];
    for (i = 0, j = [anArray count]; i < j; i++) {
      anAttr = [anArray objectAtIndex:i];
      if ([anAttr isPrimaryKey])
	[mArray addObject:anAttr];
    }
    _primaryKeys = mArray;
  }

  return _primaryKeys;
}

-(BOOL) isPrimaryKey:(CLString *) fieldName
{
  int i, j;
  CLArray *anArray;
  CLAttribute *anAttr;


  if (_primaryKeys)
    anArray = _primaryKeys;
  else
    anArray = [fields allValues];
  
  for (i = 0, j = [anArray count]; i < j; i++) {
    anAttr = [anArray objectAtIndex:i];
    if ([[anAttr key] isEqualToString:fieldName] ||
	([fieldName isEqualToString:@"objectID"] &&
	 [recordClass isKindOfClass:CLGenericRecordClass] &&
	 [[anAttr key] isEqualToString:@"id"]))
      return [anAttr isPrimaryKey];
  }

  return NO;
}

-(CLRecordDefinition *) recordDefinitionForRelationship:(CLString *) relName
{
  CLRelationship *aRel = [relationships objectForKey:relName];


  if (!aRel)
    return nil;
  return [CLEditingContext recordDefinitionForTable:[aRel theirTable]];
}

@end
