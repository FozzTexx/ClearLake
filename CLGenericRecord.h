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

#ifndef _CLGENERICRECORD_H
#define _CLGENERICRECORD_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLString.h>

@class CLDictionary, CLMutableDictionary, CLArray, CLHashTable, CLMutableArray,
  CLDatabase, CLCalendarDate, CLEditingContext, CLAttribute;

@interface CLGenericRecord:CLObject <CLArchiving, CLCopying>
{
  CLString *_table;
  CLHashTable *_record;
  CLDictionary *_recordDef;
  CLMutableArray *_loaded;
  CLDictionary *_primaryKey, *_dbPrimaryKey;
  CLMutableArray *_autoretain;
  CLDatabase *_db;
  int _changed;
}

+(id) model;
+(CLDatabase *) databaseNamed:(CLString *) aString;
+(CLDatabase *) database;
+(CLArray *) loadTable:(CLString *) table qualifier:(id) qual;
+(CLArray *) loadTable:(CLString *) table array:(CLArray *) anArray;
+(CLDictionary *) recordDefForTable:(CLString *) aTable;
+(id) classForTable:(CLString *) aString;
+(CLString *) tableForClass:(id) aClass;
+(CLString *) tableForClassName:(CLString *) aString;
+(CLString *) generateQualifier:(CLDictionary *) aDict;

-(id) init;
-(id) initFromDictionary:(CLDictionary *) aDict table:(CLString *) aTable;
-(id) initFromObjectID:(int) anID table:(CLString *) aTable;
-(id) initFromObjectID:(int) anID; /* Only for subclasses */
-(id) initFromDictionary:(CLDictionary *) aDict; /* Only for subclasses */
-(void) dealloc;
-(void) new:(id) sender;

-(CLDatabase *) database;
-(void) setLoaded:(CLString *) aString;
-(id) primaryKey;
-(BOOL) hasFieldNamed:(CLString *) aString;
-(CLAttribute *) attributeForField:(CLString *) aString;
-(int) objectID;
-(CLString *) table;
-(void) loadField:(CLString *) aField;
-(void) unloadRelationship:(CLString *) aKey;
-(CLString *) findFileForKey:(CLString *) aKey directory:(CLString *) aDir;
-(void) setObjectID:(int) oid;
-(void) loadFromDatabase;
-(int) generatePrimaryKey:(CLMutableDictionary *) mDict;
-(BOOL) exists;
-(id) saveToDatabase:(CLMutableArray *) ignore;
-(id) saveToDatabase;
-(id) saveSelfWithContext:(CLEditingContext *) aContext;
-(BOOL) deleteFromDatabase;
-(void) willChange;
-(void) willSaveToDatabase;
-(void) didInsertIntoDatabase;
-(void) didUpdateDatabase;
-(void) addObject:(id) anObject toRelationship:(CLString *) aString;
-(void) addObject:(id) anObject toBothSidesOfRelationship:(CLString *) aString;
-(id) addNewObjectToBothSidesOfRelationship:(CLString *) aString;
-(void) removeObject:(id) anObject fromRelationship:(CLString *) aString;
-(void) removeObject:(id) anObject fromBothSidesOfRelationship:(CLString *) aString;
-(CLDictionary *) dictionary;
-(CLString *) propertyList;
-(void) setFieldsFromDictionary:(CLDictionary *) aDict seen:(CLMutableDictionary *) seen
		  updateChanged:(BOOL) flag;
-(void) setFieldsFromDictionary:(CLDictionary *) aDict updateChanged:(BOOL) flag;
-(BOOL) hasChanges:(CLMutableArray *) ignoreList;
-(BOOL) allowZeroPrimaryKey;
-(CLDictionary *) recordDef;

@end

@interface CLGenericRecord (CLFlags)
-(BOOL) hasFlag:(unichar) aFlag;
-(void) addFlag:(unichar) aFlag;
-(void) removeFlag:(unichar) aFlag;
@end

@interface CLGenericRecord (CLFlagsMagic)
-(CLString *) flags;
-(void) setFlags:(CLString *) aString;
@end

@interface CLGenericRecord (CLModifiedMagic)
-(CLCalendarDate *) created;
-(CLCalendarDate *) modified;
-(void) setCreated:(CLCalendarDate *) aDate;
-(void) setModified:(CLCalendarDate *) aDate;
@end

#endif /* _CLGENERICRECORD_H */
