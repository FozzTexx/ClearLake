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

#ifndef _CLRECORDDEFINITION_H
#define _CLRECORDDEFINITION_H

#include <ClearLake/CLObject.h>

@class CLDictionary, CLDatabase, CLArray;

@interface CLRecordDefinition:CLObject
{
  CLString *table, *databaseTable;
  CLDatabase *db;
  Class recordClass;
  CLDictionary *fields, *relationships;

  CLArray *_primaryKeys;
}

-(id) init;
-(id) initFromTable:(CLString *) aTable class:(Class) aClass
	     fields:(CLDictionary *) fieldsDict relationships:(CLDictionary *) relDict;
-(void) dealloc;

-(CLString *) table; /* Complete table name as dbname.tablename */
-(CLString *) databaseTable; /* Name of table in db, with no dbname. */
-(CLDatabase *) database;
-(Class) recordClass;
-(CLDictionary *) fields;
-(CLDictionary *) relationships;

-(CLString *) columnNameForKey:(CLString *) aKey;
-(CLArray *) primaryKeys;
-(BOOL) isPrimaryKey:(CLString *) fieldName;
-(CLRecordDefinition *) recordDefinitionForRelationship:(CLString *) relName;
@end

#endif /* _CLGENERICRECORD_H */
