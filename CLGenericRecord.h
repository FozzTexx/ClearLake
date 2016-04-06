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

#ifndef _CLGENERICRECORD_H
#define _CLGENERICRECORD_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLString.h>
#import <ClearLake/CLHashTable.h>

@class CLDictionary, CLMutableDictionary, CLArray, CLMutableArray,
  CLDatabase, CLDatetime, CLEditingContext, CLAttribute, CLRelationship,
  CLRecordDefinition;

@interface CLGenericRecord:CLObject <CLArchiving, CLCopying>
{
  CLString *_table;
  CLHashTable *_record;
  CLRecordDefinition *_recordDef;
  CLDictionary *_primaryKey, *_dbPrimaryKey;
  CLMutableArray *_autoretain;
  CLDatabase *_db;
  int _changed;
}

-(id) init;
-(id) initFromDictionary:(CLDictionary *) aDict table:(CLString *) aTable;
-(void) dealloc;
-(void) new:(id) sender;

-(CLDatabase *) database;
-(id) primaryKey;
-(BOOL) hasFieldNamed:(CLString *) aString;
-(CLAttribute *) attributeForField:(CLString *) aString;
-(id) objectForCachedBinding:(CLCachedBinding *) cachedBinding;
-(CLUInteger) objectID;
-(CLString *) table;
-(void) setObjectID:(CLUInteger) oid;
-(BOOL) exists;
-(CLDictionary *) dictionary;
-(CLString *) propertyList;
-(CLString *) description;
-(void) setFieldsFromDictionary:(CLDictionary *) aDict seen:(CLMutableDictionary *) seen
		  updateChanged:(BOOL) flag;
-(void) setFieldsFromDictionary:(CLDictionary *) aDict updateChanged:(BOOL) flag;
-(BOOL) hasChanges:(CLMutableArray *) ignoreList;
-(BOOL) allowZeroPrimaryKey;
-(CLRecordDefinition *) recordDef;

@end

@interface CLObject (CLFlags)
-(BOOL) hasFlag:(unichar) aFlag;
-(void) addFlag:(unichar) aFlag;
-(void) removeFlag:(unichar) aFlag;
@end

@interface CLObject (CLFlagsMagic)
-(CLString *) flags;
-(void) setFlags:(CLString *) aString;
@end

@interface CLGenericRecord (CLModifiedMagic)
-(CLDatetime *) created;
-(CLDatetime *) modified;
-(void) setCreated:(CLDatetime *) aDate;
-(void) setModified:(CLDatetime *) aDate;
@end

@interface CLObject (CLGenericRecord)
-(CLEditingContext *) editingContext;
-(void) setEditingContext:(CLEditingContext *) aContext;
-(void) willChange;
-(void) willSaveToDatabase;
-(void) willDeleteFromDatabase;
-(void) didInsertIntoDatabase;
-(void) didUpdateDatabase;
-(void) didDeleteFromDatabase;
-(BOOL) hasChanges;
-(BOOL) exists;
-(BOOL) hasFieldNamed:(CLString *) aString;
-(CLRelationship *) theirRelationship:(CLRelationship *) ours named:(CLString **) aName;
-(void) addObject:(id) anObject toRelationship:(CLString *) aString;
-(void) addObject:(id) anObject toBothSidesOfRelationship:(CLString *) aString;
-(id) addNewObjectToBothSidesOfRelationship:(CLString *) aString;
-(void) removeObject:(id) anObject fromRelationship:(CLString *) aString;
-(void) removeObject:(id) anObject fromBothSidesOfRelationship:(CLString *) aString;
@end

#endif /* _CLGENERICRECORD_H */
