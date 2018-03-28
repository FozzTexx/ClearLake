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

#ifndef _CLEDITINGCONTEXT_H
#define _CLEDITINGCONTEXT_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLHashTable.h>

@class CLMutableArray, CLDictionary, CLMutableDictionary, CLDatabase, CLRecordDefinition,
  CLMutableString, CLArray;

@interface CLEditingContext:CLObject
{
  CLMutableArray *dirty, *inserted, *updated, *delete;
  CLHashTable *instancesTable, *primaryKeys;

  int _savingChanges;
}

+(id) model;
+(CLDatabase *) databaseNamed:(CLString *) aString;
+(CLDatabase *) database;
+(CLDatabase *) databaseForClass:(Class) aClass;
+(Class) sessionClass;
+(Class) accountClass;
+(CLString *) generateQualifier:(CLDictionary *) aDict;
+(CLString *) qualifierForObject:(id) aRecord fromDatabase:(BOOL) fromDB
		recordDefinition:(CLRecordDefinition *) recordDef;
+(id) constructPrimaryKey:(id) record recordDef:(CLRecordDefinition *) recordDef
	     fromDatabase:(BOOL) fromDB asDictionary:(BOOL) asDict;
+(void) createSelect:(CLMutableString **) select andAttributes:(CLArray **) attributes
 forRecordDefinition:(CLRecordDefinition *) recordDef;
+(int) generatePrimaryKey:(CLMutableDictionary *) mDict forRecord:(id) aRecord;

-(id) init;
-(void) dealloc;

-(id) primaryKeyForRecord:(id) aRecord;
-(id) registerInstance:(id) anObject;
-(id) registerInstance:(id) anObject inTable:(CLString *) table withPrimaryKey:(id) primaryKey;
-(void) unregisterInstance:(id) anObject;
-(BOOL) instanceIsRegistered:(id) anObject;
-(id) recordForPrimaryKey:(id) primaryKey inTable:(CLString *) table;
-(BOOL) recordHasChanges:(id) aRecord;

-(void) addObject:(id) anObject;
-(void) removeObject:(id) anObject;
-(void) deleteObject:(id) anObject;
-(void) didUpdate:(id) anObject;
-(void) didInsert:(id) anObject;
-(BOOL) recordExists:(id) anObject recordDefinition:(CLRecordDefinition *) recordDef;
-(id) saveChanges;
-(id) saveChangesWithoutTransaction:(BOOL) noTransaction;

-(id) loadObjectWithClass:(Class) aClass objectID:(CLUInteger) anID;
-(id) loadExistingObjectWithClass:(Class) aClass objectID:(CLUInteger) anID;
-(id) loadObjectWithClass:(Class) aClass primaryKey:(id) pk;
-(id) loadExistingObjectWithClass:(Class) aClass primaryKey:(id) pk;
-(CLArray *) loadTableWithRecordDefinition:(CLRecordDefinition *) recordDef
				     array:(CLArray *) anArray;
-(CLArray *) loadTableWithRecordDefinition:(CLRecordDefinition *) recordDef
				 qualifier:(id) qual;
-(CLArray *) loadTableWithRecordDefinition:(CLRecordDefinition *) recordDef
				 qualifier:(id) qual orderBy:(CLString *) order;
-(CLArray *) loadTableWithClass:(Class) aClass qualifier:(id) qual;
-(CLArray *) loadTableWithClass:(Class) aClass qualifier:(id) qual orderBy:(CLString *) order;
-(CLArray *) loadTableWithClass:(Class) aClass array:(CLArray *) anArray;

@end

@interface CLEditingContext (CLRecordDefinition)
+(id) classForTable:(CLString *) aString;
+(CLString *) tableForClass:(id) aClass;
+(CLRecordDefinition *) recordDefinitionForClass:(Class) aClass;
+(CLRecordDefinition *) recordDefinitionForTable:(CLString *) aTable;
@end

extern CLEditingContext *CLDefaultContext;

#endif /* _CLEDITINGCONTEXT_H */
