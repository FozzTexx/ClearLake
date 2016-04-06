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

#import "CLEditingContext.h"
#import "CLFault.h"
#import "CLArrayFault.h"
#import "CLRecordDefinition.h"
#import "CLGenericRecord.h"
#import "CLPlaceholder.h"
#import "CLDatabase.h"
#import "CLMutableArray.h"
#import "CLAutoreleasePool.h"
#import "CLMutableDictionary.h"
#import "CLRelationship.h"
#import "CLAttribute.h"
#import "CLHashTable.h"
#import "CLNumber.h"
#import "CLNull.h"
#import "CLMutableString.h"
#import "CLDecimalNumber.h"
#import "CLRuntime.h"
#import "CLManager.h"
#import "CLMySQLDatabase.h"
#import "CLSybaseDatabase.h"
#import "CLTimeZone.h"
#import "CLDatetime.h"
#import "CLSession.h"

#include <stdlib.h>

#define DONE		0
#define PREPARING	1
#define SAVING		2

static id _model = nil;
/* For CLRecordDefinition category */
static CLHashTable *_classDefs = NULL, *_tableDefs = NULL,
  *_classTable = NULL, *_tableClass = NULL;
static int _modelInitializing = 0;

Class CLEditingContextClass, CLGenericRecordClass, CLAttributeClass, CLRelationshipClass,
  CLRecordDefinitionClass, CLFaultClass, CLArrayFaultClass, CLPlaceholderClass;

@implementation CLEditingContext

+(void) load
{
  CLEditingContextClass = [CLEditingContext class];
  CLRecordDefinitionClass = [CLRecordDefinition class];
  CLFaultClass = [CLFault class];
  CLArrayFaultClass = [CLArrayFault class];
  return;
}
  
+(void) decodeSchema:(CLMutableDictionary *) aSchema databaseName:(CLString *) aDatabase
{
  CLArray *keys;
  int i, j;
  CLString *aTable, *aString;
  CLDictionary *aDict;
  CLRecordDefinition *recordDef;
  Class aClass;
  CLMutableDictionary *fields, *relations;

  
  keys = [aSchema allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    aTable = [keys objectAtIndex:i];
    aDict = [aSchema objectForKey:aTable];

    if (!(aString = [aDict objectForKey:@"class"]))
      aString = [aTable upperCamelCaseString];
    if (!(aClass = objc_lookUpClass([aString UTF8String]))) {
      if ([aDict objectForKey:@"class"])
	[self error:@"Unable to find class \"%@\"", aString];
      aClass = CLGenericRecordClass;
    }
    
    {
      id anObject;
      CLArray *anArray;
      CLAttribute *anAttr;
      CLString *aKey;
      int k, l;


      fields = [[CLMutableDictionary alloc] init];
      anObject = [aDict objectForKey:@"fields"];
      if ([anObject isKindOfClass:CLArrayClass]) {
	anArray = CLAttributesFromArray(anObject);
	for (k = 0, l = [anArray count]; k < l; k++) {
	  anAttr = [anArray objectAtIndex:k];
	  aKey = [[anAttr column] lowerCamelCaseString];
	  [anAttr setKey:aKey];
	  [fields setObject:anAttr forKey:aKey];
	}
      }
      else {
	anArray = [anObject allKeys];
	for (k = 0, l = [anArray count]; k < l; k++) {
	  aKey = [anArray objectAtIndex:k];
	  anAttr = [CLAttribute attributeFromString:[anObject objectForKey:aKey]];
	  [anAttr setKey:aKey];
	  [fields setObject:anAttr forKey:aKey];
	}
      }
    }

    {
      int k, l;
      CLArray *anArray;
      id anObject;
      CLString *aString;


      relations = [[CLMutableDictionary alloc] init];
      anObject = [aDict objectForKey:@"relationships"];
      anArray = [anObject allKeys];
      for (k = 0, l = [anArray count]; k < l; k++) {
	aString = [anArray objectAtIndex:k];
	[relations setObject:[[[CLRelationship alloc]
				initFromString:[anObject objectForKey:aString]
				databaseName:aDatabase] autorelease]
		   forKey:[aString lowerCamelCaseString]];
      }
    }

    recordDef = [[CLRecordDefinition alloc] initFromTable:[CLString stringWithFormat:@"%@.%@",
								    aDatabase, aTable]
						    class:aClass fields:fields
					    relationships:relations];
    [aSchema setObject:recordDef forKey:aTable];
    [fields release];
    [relations release];
    [recordDef release];
  }

  return;
}

+(void) findDependencies:(CLMutableDictionary *) aSchema databaseName:(CLString *) aDatabase
{
  CLArray *keys;
  int i, j;
  CLString *aTable;
  CLRecordDefinition *recordDef;
  CLAutoreleasePool *pool;


  keys = [aSchema allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    aTable = [keys objectAtIndex:i];
    recordDef = [aSchema objectForKey:aTable];

    {
      int k, l;
      CLDictionary *relations;
      CLArray *anArray;
      CLString *relName;
      CLRelationship *aRel;


      relations = [recordDef relationships];
      anArray = [relations allKeys];
      pool = [[CLAutoreleasePool alloc] init];
      for (k = 0, l = [anArray count]; k < l; k++) {
	relName = [anArray objectAtIndex:k];
	aRel = [relations objectForKey:relName];
	if (![aRel toMany]) {
	  CLDictionary *aDict;
	  CLRecordDefinition *theirDef;
	  CLAttribute *anAttr;
	  CLString *fieldName;
	  CLArray *theirFields, *theirKeys;
	  int m, n, nk;


	  theirDef = [CLEditingContext recordDefinitionForTable:[aRel theirTable]];
	  aDict = [theirDef fields];
	  theirFields = [aDict allKeys];
	  theirKeys = [aRel theirKeys];
	  for (m = 0, n = [theirKeys count]; m < n; m++)
	    if (![theirFields containsObject:[theirKeys objectAtIndex:m]])
	      [aRel error:[CLString stringWithFormat:
				      @"No matching keys found for relationship %@.%@",
				    aTable, relName]];

	  theirFields = [aRel theirKeys];
	  for (m = 0, n = [theirFields count]; m < n; m++) {
	    fieldName = [theirFields objectAtIndex:m];
	    anAttr = [aDict objectForKey:fieldName];
	    if ([anAttr isPrimaryKey])
	      break;
	  }

	  /* Can't be dependent on objects with mismatched number of
	     keys. Can't generate a key for it when we want to save
	     and there's no way it can be a to-one either. */
	  if (m < n) {
	    theirFields = [aDict allKeys];
	    for (m = nk = 0, n = [theirFields count]; m < n; m++) {
	      fieldName = [theirFields objectAtIndex:m];
	      anAttr = [aDict objectForKey:fieldName];
	      if ([anAttr isPrimaryKey])
		nk++;
	    }

	    if (nk != [[aRel ourKeys] count])
	      [aRel error:[CLString stringWithFormat:
				       @"To-one relationship from \"%@.%@\""
				    " to multi-key object \"%@\"",
				    aTable, relName, [aRel theirTable]]];

#if 0
	    /* FIXME - Just because we are the owner doesn't mean we
	       don't need its primary key as our foreign key */
	    if (![aRel isOwner])
#endif
	      [aRel setDependent:YES];
	  }
	}
      }
      [pool release];
    }
  }

  /* FIXME - check for mutual dependencies */
  for (i = 0, j = [keys count]; i < j; i++) {
    aTable = [keys objectAtIndex:i];
    recordDef = [aSchema objectForKey:aTable];
    aTable = [CLString stringWithFormat:@"%@.%@", aDatabase, aTable];

    {
      int k, l;
      CLDictionary *relations;
      CLArray *anArray;
      CLString *relName;
      CLRelationship *aRel;


      relations = [recordDef relationships];
      anArray = [relations allKeys];
      pool = [[CLAutoreleasePool alloc] init];
      for (k = 0, l = [anArray count]; k < l; k++) {
	relName = [anArray objectAtIndex:k];
	aRel = [relations objectForKey:relName];
	if ([aRel isDependent]) {
	  CLDictionary *aDict;
	  CLRecordDefinition *theirDef;
	  CLString *fieldName, *ourTable;
	  CLArray *theirFields;
	  CLRelationship *theirRel;
	  int m, n;


	  theirDef = [CLEditingContext recordDefinitionForTable:[aRel theirTable]];
	  aDict = [theirDef relationships];
	  theirFields = [aDict allKeys];
	  for (m = 0, n = [theirFields count]; m < n; m++) {
	    fieldName = [theirFields objectAtIndex:m];
	    theirRel = [aDict objectForKey:fieldName];
	    ourTable = [theirRel theirTable];
	    if ([ourTable isEqualToString:aTable] &&
		[[aRel ourKeys] isEqual:[theirRel theirKeys]] && [theirRel isDependent]) {
	      if ([aRel isOwner]) /* FIXME - we own them so we can't be dependent, right? */
		[aRel setDependent:NO];
	      else if ([theirRel isOwner])
		[theirRel setDependent:NO];
	      else
		[aRel error:[CLString stringWithFormat:
					@"Mutual dependency between \"%@.%@\" and \"%@\"",
				      aTable, relName, [aRel theirTable]]];
	    }
	  }
	}
#if 0 /* FIXME - is a to-one relationship that isn't linked with a primary key really ok? */
	else if (![aRel toMany]) {
	  CLDictionary *aDict, *theirDef;
	  CLString *fieldName, *ourTable;
	  CLArray *theirFields;
	  CLRelationship *theirRel;
	  int m, n;


	  theirDef = [[self class] recordDefForTable:[aRel theirTable]];
	  aDict = [theirDef objectForKey:@"relationships"];
	  theirFields = [aDict allKeys];
	  for (m = 0, n = [theirFields count]; m < n; m++) {
	    fieldName = [theirFields objectAtIndex:m];
	    theirRel = [aDict objectForKey:fieldName];
	    ourTable = [theirRel theirTable];
	    if ([ourTable isEqualToString:aTable] && [theirRel isDependent])
	      break;
	  }
	  if (m == n)
	    [aRel error:[CLString stringWithFormat:
				    @"No dependency between \"%@\" and \"%@\"",
				  aTable, [aRel theirTable]]];
	}
#endif
      }
      [pool release];
    }
  }

  return;
}

+(id) model
{
  CLMutableDictionary *mDict, *mDict2, *mDict3;
  CLArray *anArray;
  int i, j;
  CLString *aString;

  
  if (_model)
    return _model;

  if (_modelInitializing)
    [self error:@"Can't get model while getting model!"];
  _modelInitializing = 1;

  /* For CLRecordDefinition category */
  _classDefs = CLHashTableAlloc(CLHashTableDefaultSize);
  _tableDefs = CLHashTableAlloc(CLHashTableDefaultSize);
  _classTable = CLHashTableAlloc(CLHashTableDefaultSize);
  _tableClass = CLHashTableAlloc(CLHashTableDefaultSize);
  
  if ((aString = [CLManager configOption:@"Model"]) &&
      (aString = [CLString stringWithContentsOfFile:
			     [[CLManager configurationDirectory]
			       stringByAppendingPathComponent:aString]
			   encoding:CLASCIIStringEncoding]))
    _model = [[aString decodePropertyList] mutableCopy];
  else {
    if (![CLManager configOption:@"Database"])
      return nil;

    _model = [[CLMutableDictionary alloc] init];    
    mDict = [[CLMutableDictionary alloc] init];
    mDict2 = [[CLMutableDictionary alloc] init];
    if ((aString = [CLManager configOption:@"Database"]))
      [mDict2 setObject:aString forKey:@"database"];
    if ((aString = [CLManager configOption:@"User"]))
      [mDict2 setObject:aString forKey:@"user"];
    if ((aString = [CLManager configOption:@"Password"]))
      [mDict2 setObject:aString forKey:@"password"];
    if ((aString = [CLManager configOption:@"Host"]))
      [mDict2 setObject:aString forKey:@"host"];
    if ((aString = [CLManager configOption:@"Interface"]))
      [mDict2 setObject:aString forKey:@"interface"];
    [mDict setObject:mDict2 forKey:@"connection"];

    if ((aString = [CLManager configOption:@"Schema"]) &&
	(aString = [CLString stringWithContentsOfFile:
			       [[CLManager configurationDirectory]
				 stringByAppendingPathComponent:aString]
			     encoding:CLASCIIStringEncoding]))
      mDict3 = [[aString decodePropertyList] mutableCopy];
    else
      mDict3 = [[CLMutableDictionary alloc] init];

    if (![mDict3 objectForKey:@"account"])
      [mDict3 setObject:[@"{fields = (\"+id:i\", \"email:*\", \"name:*\", \"password:*\", \"flags:*\", \"created:@\", \"ip_address:*\", \"last_seen:@\"); class=CLAccount;}" decodePropertyList] forKey:@"account"];
    if (![mDict3 objectForKey:@"session"])
      [mDict3 setObject:[@"{fields = (\"+id:i\", \"last_seen:@\", \"account_id:i\", \"hash:#\"); relationships = { account = \"account_id=account.id\" } class=CLSession}" decodePropertyList] forKey:@"session"];

    [mDict setObject:mDict3 forKey:@"schema"];
    [_model setObject:mDict forKey:[mDict2 objectForKey:@"database"]];
    [mDict3 release];
    [mDict2 release];
    [mDict release];
  }

  anArray = [_model allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    [self decodeSchema:[[_model objectForKey:aString]
			 objectForKey:@"schema"] databaseName:aString];
  }

  /* Find relationship dependencies */
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    [self findDependencies:[[_model objectForKey:aString]
			     objectForKey:@"schema"] databaseName:aString];
  }

  return _model;
}

+(CLDatabase *) databaseNamed:(CLString *) aString
{
  CLDictionary *model = [self model];
  CLMutableDictionary *mDict;
  CLDatabase *db;
  CLString *interface;
  CLDictionary *aDict;
  CLString *user, *database, *password, *host, *encoding, *zone, *format;


  mDict = [model objectForKey:aString];
  if (!(db = [mDict objectForKey:@"database"])) {
    aDict = [mDict objectForKey:@"connection"];
    interface = [aDict objectForKey:@"interface"];
    user = [aDict objectForKey:@"user"];
    database = [aDict objectForKey:@"database"];
    password = [aDict objectForKey:@"password"];
    host = [aDict objectForKey:@"host"];
    encoding = [aDict objectForKey:@"encoding"];
    zone = [aDict objectForKey:@"timezone"];
    format = [aDict objectForKey:@"dateformat"];
    if (![interface caseInsensitiveCompare:@"mysql"])
      db = [[CLMySQLDatabase alloc]
	     initWithDatabase:database user:user password:password host:host];
    else if (![interface caseInsensitiveCompare:@"sybase"])
      db = [[CLSybaseDatabase alloc]
	     initWithDatabase:database user:user password:password host:host];

    if (encoding) {
      if (![encoding caseInsensitiveCompare:@"UTF8"])
	[db setEncoding:CLUTF8StringEncoding];
      else if (![encoding caseInsensitiveCompare:@"ISO-8859-1"] ||
	       ![encoding caseInsensitiveCompare:@"ISO-1"] ||
	       ![encoding caseInsensitiveCompare:@"ISOLatin1"])
	[db setEncoding:CLISOLatin1StringEncoding];
      else if (![encoding caseInsensitiveCompare:@"NeXTSTEP"] ||
	       ![encoding caseInsensitiveCompare:@"OPENSTEP"])
	[db setEncoding:CLNEXTSTEPStringEncoding];
    }
    if (zone)
      [db setTimeZone:[CLTimeZone timeZoneWithName:zone]];
    if (format)
      [db setDateFormat:format];
    
    [mDict setObject:db forKey:@"database"];
  }

  return db;
}

+(CLDatabase *) database
{
  CLDictionary *model = [self model];


  if ([model count] > 1)
    [self error:@"No database specified"];
  return [self databaseNamed:[[model allKeys] objectAtIndex:0]];
}

+(CLDatabase *) databaseForClass:(Class) aClass
{
  return [[self recordDefinitionForClass:aClass] database];
}

+(Class) sessionClass
{
  static Class _sessionClass = nil;


  if (!_sessionClass) {
    if ([CLDelegate respondsTo:@selector(sessionClass)])
      _sessionClass = [CLDelegate sessionClass];
    else if (_model || !_modelInitializing) {
      CLArray *anArray;
      int i, j;
      CLRecordDefinition *recordDef;


      anArray = [[self model] allValues];
      for (i = 0, j = [anArray count]; i < j; i++)
	if ((recordDef = [[[anArray objectAtIndex:i] objectForKey:@"schema"]
			   objectForKey:@"session"])) {
	  _sessionClass = [recordDef recordClass];
	  break;
	}
    }
    else
      fprintf(stderr, "Warning: unable to parse model for session class"
	      " during initialization.\n");

    if (!_sessionClass)
      _sessionClass = CLSessionClass;
  }

  return _sessionClass;
}

+(Class) accountClass
{
  CLRecordDefinition *recordDef;
  CLRelationship *aRelationship;


  recordDef = [CLEditingContext recordDefinitionForClass:[self sessionClass]];
  aRelationship = [[recordDef relationships] objectForKey:@"account"];
  return [CLEditingContext classForTable:[aRelationship theirTable]];
}

+(CLString *) generateQualifier:(CLDictionary *) aDict
{
  CLMutableString *mString;
  CLString *aKey;
  CLArray *anArray;
  id anObject;
  int i, j;


  anArray = [aDict allKeys];
  mString = [[CLMutableString alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    if ([mString length])
      [mString appendString:@" and "];
    [mString appendString:aKey];
    if (!(anObject = [aDict objectForKey:aKey]) || anObject == CLNullObject)
      [mString appendString:@" is null"];
    else if ([anObject isKindOfClass:CLStringClass])
      [mString appendFormat:@" = '%@'", [CLDatabase defangString:anObject escape:NULL]];
    else
      [mString appendFormat:@" = %@", anObject];
  }

  return [mString autorelease];
}

+(CLString *) qualifierForObject:(id) aRecord fromDatabase:(BOOL) fromDB
		recordDefinition:(CLRecordDefinition *) recordDef
{
  CLArray *pKeys;
  CLAttribute *anAttr;
  CLMutableDictionary *mDict;
  CLString *aKey;
  int i, j;
  id anObject;


  pKeys = [recordDef primaryKeys];
  mDict = [[CLMutableDictionary alloc] init];
  for (i = 0, j = [pKeys count]; i < j; i++) {
    anAttr = [pKeys objectAtIndex:i];
    if (fromDB)
      anObject = [aRecord objectForKey:[anAttr column]];
    else
      anObject = [aRecord objectValueForBinding:[anAttr key]];
    if (!anObject)
      anObject = CLNullObject;
    [mDict setObject:anObject forKey:[anAttr column]];
  }

  aKey = [[self class] generateQualifier:mDict];
  [mDict release];
  return aKey;
}

+(id) constructPrimaryKey:(id) record recordDef:(CLRecordDefinition *) recordDef
	     fromDatabase:(BOOL) fromDB asDictionary:(BOOL) asDict
{
  CLMutableDictionary *mDict;
  CLArray *primaryKeys;
  CLAttribute *anAttr;
  int i, j;
  id pk, value;


  primaryKeys = [recordDef primaryKeys];
  if ([primaryKeys count] == 1 && !asDict) {
    if ([record isKindOfClass:CLDictionaryClass] && fromDB)
      pk = [[record objectForKey:[[primaryKeys objectAtIndex:0] column]] retain];
    else
      pk = [[record objectValueForBinding:[[primaryKeys objectAtIndex:0] key]] retain];
    if ([pk isKindOfClass:[CLNumber class]] && ![pk unsignedIntValue])
      pk = nil;
  }
  else {
    mDict = [[CLMutableDictionary alloc] init];
    for (i = 0, j = [primaryKeys count]; i < j; i++) {
      anAttr = [primaryKeys objectAtIndex:i];
      if ([record isKindOfClass:CLDictionaryClass] && fromDB)
	value = [record objectForKey:[anAttr column]];
      else
	value = [record objectValueForBinding:[anAttr key]];
      if (!value)
	break;
      [mDict setObject:value forKey:[anAttr key]];
    }

    if (i < j) {
      [mDict release];
      mDict = nil;
    }
    
    pk = mDict;
  }

  return [pk autorelease];
}

+(void) createSelect:(CLMutableString **) select andAttributes:(CLArray **) attributes
 forRecordDefinition:(CLRecordDefinition *) recordDef
{
  CLMutableArray *attr;
  CLMutableString *mString;
  CLArray *rows;
  int i, j;
  CLAttribute *anAttr;


  attr = [[CLMutableArray alloc] init];
  mString = [[CLMutableString alloc] init];
  [mString appendString:@"select "];
  rows = [[recordDef fields] allValues];
  for (i = 0, j = [rows count]; i < j; i++) {
    anAttr = [rows objectAtIndex:i];
    if (i)
      [mString appendString:@", "];
    [attr addObject:anAttr];
    [mString appendString:[anAttr column]];
  }

  [mString appendFormat:@" from %@", [recordDef databaseTable]];

  *select = mString;
  *attributes = attr;
  return;
}

/* This generates a new key for a row in the database. The field names
   are all database column names, and not object field names */
/* FIXME - if there are errors saving to database then the transaction
   will be rolled back yet we will have an object with an ID out of
   sync with cl_sequence_table. */
+(int) generatePrimaryKey:(CLMutableDictionary *) mDict forRecord:(id) aRecord
{
  CLArray *pKeys;
  CLRecordDefinition *recordDef;
  int i, j, k, oid = 0, tid = 0;
  CLAttribute *anAttr;
  CLDatabase *db;
  id aValue;


  recordDef = [self recordDefinitionForClass:[aRecord class]];
  pKeys = [recordDef primaryKeys];
  for (i = k = 0, j = [pKeys count]; i < j; i++) {
    anAttr = [pKeys objectAtIndex:i];
    aValue = [mDict objectForKey:[anAttr column]];
    if (!aValue || aValue == CLNullObject ||
	([aValue isKindOfClass:CLNumberClass] && !(tid = [aValue intValue])))
      k++;
    else
      oid = tid;
  }

  if (k > 1)
    [self error:@"Don't know how to generate more than 1 primary key"];

  if (k) {
    db = [recordDef database];
    oid = [db nextIDForTable:[recordDef databaseTable]];
    for (i = 0, j = [pKeys count]; i < j; i++) {
      anAttr = [pKeys objectAtIndex:i];
      aValue = [mDict objectForKey:[anAttr column]];
      if (aValue == CLNullObject || ![aValue intValue]) {
	/* FIXME - should we be doing it this way and bypassing willChange? */
	[aRecord setPrimitiveValue:[CLNumber numberWithInt:oid] forKey:[anAttr key]];
	[mDict setObject:[CLNumber numberWithInt:oid] forKey:[anAttr column]];
	break;
      }
    }
  }

  return oid;
}

-(id) init
{
  [super init];
  dirty = [[CLMutableArray alloc] init];
  inserted = [[CLMutableArray alloc] init];
  updated = [[CLMutableArray alloc] init];
  delete = [[CLMutableArray alloc] init];
  instancesTable = CLHashTableAlloc(CLHashTableDefaultSize);
  primaryKeys = CLHashTableAlloc(CLHashTableDefaultSize);

  return self;
}

-(void) dealloc
{
  int i, j;
  id *data;
  CLHashTable **hTable;
  id anObject;


  [dirty release];
  [inserted release];
  [updated release];
  [delete release];

  hTable = alloca(sizeof(CLHashTable *) * instancesTable->count);
  CLHashTableGetData(instancesTable, (void **) hTable);
  for (i = 0; i < instancesTable->count; i++) {
    data = alloca(sizeof(id) * hTable[i]->count);
    CLHashTableGetKeys(hTable[i], data);
    for (j = 0; j < hTable[i]->count; j++) {
      anObject = CLHashTableDataForIdenticalKey(hTable[i], data[j], [data[j] hash]);
      [anObject setEditingContext:nil];
      [data[j] release];
    }
    CLHashTableFree(hTable[i]);
  }
  CLHashTableGetKeys(instancesTable, (id *) hTable);
  for (i = 0; i < instancesTable->count; i++)
    [((id) hTable[i]) release];
  CLHashTableFree(instancesTable);

  /* primaryKeys doesn't retain anything since it is just an alternate
     lookup for the data in instancesTable */  
  CLHashTableFree(primaryKeys);

  [super dealloc];
  return;
}

-(id) primaryKeyForRecord:(id) aRecord
{
  id pk;
  CLRecordDefinition *recordDef;


  if (!(pk = CLHashTableDataForIdenticalKey(primaryKeys, aRecord, (size_t) aRecord))) {
    recordDef = [CLEditingContext recordDefinitionForClass:[aRecord class]];
    pk = [[self class] constructPrimaryKey:aRecord recordDef:recordDef
			      fromDatabase:NO asDictionary:NO];
  }
  
  return pk;
}

-(id) registerInstance:(id) anObject
{
  CLDictionary *pk;

  
  if (!(pk = [self primaryKeyForRecord:anObject]))
    return nil;

  return [self registerInstance:anObject
			inTable:[CLEditingContext tableForClass:[anObject class]]
		 withPrimaryKey:pk];
}

-(id) registerInstance:(id) anObject inTable:(CLString *) table withPrimaryKey:(id) primaryKey
{
  id realObject;
  CLHashTable *insTable;


  if (!(insTable = CLHashTableDataForKey(instancesTable, table, [table hash],
					 @selector(isEqual:)))) {
    insTable = CLHashTableAlloc(CLHashTableDefaultSize);
    CLHashTableSetData(instancesTable, insTable, [table copy], [table hash]);
  }
  
  if (!(realObject = CLHashTableDataForKey(insTable, primaryKey, [primaryKey hash],
					   @selector(isEqual:)))) {
    realObject = anObject;
    /* Could be a mutable dictionary */
    primaryKey = [primaryKey copy];
    CLHashTableSetData(insTable, realObject, primaryKey, [primaryKey hash]);
    CLHashTableSetData(primaryKeys, primaryKey, realObject, (size_t) realObject);
    [realObject setEditingContext:self];
#if 0
    fprintf(stderr, "Registered 0x%08lx %s %s %u\n", (size_t) realObject, [table UTF8String],
	    [[primaryKey description] UTF8String], [primaryKey hash]);
#endif
  }

  return realObject;
}

-(void) unregisterInstance:(id) anObject
{
  CLDictionary *pk;
  CLString *table;
  CLHashTable *insTable;


  table = [CLEditingContext tableForClass:[anObject class]];

  if (!(pk = CLHashTableDataForIdenticalKey(primaryKeys, anObject, (size_t) anObject)))
    return;

  insTable = CLHashTableDataForKey(instancesTable, table, [table hash], @selector(isEqual:));
  CLHashTableRemoveDataForKey(insTable, pk, [pk hash], @selector(isEqual:));
  CLHashTableRemoveDataForIdenticalKey(primaryKeys, anObject, (size_t) anObject);
  [pk release];

  return;
}

-(id) recordForPrimaryKey:(id) primaryKey inTable:(CLString *) table
{
  CLHashTable *insTable;
  id anObject = nil;


#if 0
  fprintf(stderr, "Looking for %s %s...", [table UTF8String],
	  [[primaryKey description] UTF8String]);
#endif
  if ((insTable = CLHashTableDataForKey(instancesTable, table, [table hash],
					@selector(isEqual:))))
    anObject = CLHashTableDataForKey(insTable, primaryKey, [primaryKey hash],
				     @selector(isEqual:));
#if 0
  if (anObject)
    fprintf(stderr, "found\n");
  else
    fprintf(stderr, "not found\n");
#endif
  
  return anObject;
}

-(BOOL) recordHasChanges:(id) aRecord
{
  return [dirty containsObjectIdenticalTo:aRecord];
}

-(void) addObject:(id) anObject
{
  if (![dirty containsObjectIdenticalTo:anObject]) {
    if (_savingChanges == SAVING)
      [self error:@"Tried to add object during save"];
    [dirty addObject:anObject];
  }
  return;
}

-(void) removeObject:(id) anObject
{
  CLUInteger index;


  if ((index = [dirty indexOfObjectIdenticalTo:anObject]) != CLNotFound)
    [dirty removeObjectAtIndex:index];
  return;
}

-(void) deleteObject:(id) anObject
{
  if (!anObject)
    return;
  
  if (![delete containsObjectIdenticalTo:anObject]) {
    if (_savingChanges == SAVING)
      [self error:@"Tried to delete object during save"];
    [delete addObject:anObject];
  }
  return;
}

-(void) didUpdate:(id) anObject
{
  [updated addObject:anObject];
  return;
}

-(void) didInsert:(id) anObject
{
  [inserted addObject:anObject];
  return;
}

-(BOOL) recordExists:(id) aRecord recordDefinition:(CLRecordDefinition *) recordDef
{
  CLString *aString;
  CLDictionary *results;
  CLArray *anArray;


  aString = [CLString stringWithFormat:@"select count(*) from %@ where %@",
		      [recordDef databaseTable],
		      [[self class] qualifierForObject:aRecord fromDatabase:NO
				      recordDefinition:recordDef]];
  results = [[recordDef database] runQuery:aString];
  anArray = [results objectForKey:@"rows"];
  if ([anArray count] && [[[anArray objectAtIndex:0] objectAtIndex:0] intValue])
    return YES;

  return NO;
}

-(id) saveRecord:(id) aRecord
{
  CLDatabase *db;
  CLMutableDictionary *mDict;
  CLDictionary *fields, *relationships;
  CLRecordDefinition *recordDef;
  CLArray *anArray;
  CLString *aString, *aKey;
  CLAttribute *anAttr;
  int i, j;
  id anObject;
  id errors = nil;
  CLRelationship *aRelationship;
  CLMutableArray *saveFields, *skipped;


  if ([aRecord isFault])
    [self error:@"Why are we saving a fault?"];
  
  mDict = [[CLMutableDictionary alloc] init];
  saveFields = [[CLMutableArray alloc] init];
  skipped = [[CLMutableArray alloc] init];

  recordDef = [CLEditingContext recordDefinitionForClass:[aRecord class]];
  db = [recordDef database];
  
  fields = [recordDef fields];
  relationships = [recordDef relationships];

  anArray = [relationships allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aRelationship = [relationships objectForKey:aKey];
    if ([aRelationship isDependent]) {
      /* FIXME - don't fault in relationships */
      anObject = [aRecord objectValueForBinding:aKey];
      if (0 && [anObject isFault]) {
	[self error:@"Cannot fault object in while saving,"
	      " cannot save record without adding object to dictionary.\n"];
	/* FIXME - what if they are primary keys or cannot be null? */
	[skipped addObjectsFromArray:[aRelationship ourKeys]];
	fprintf(stderr, "Skipped %s.%s\n", [[aRecord className] UTF8String],
		[aKey UTF8String]);
      }
      else {
	if (anObject && ![self primaryKeyForRecord:anObject]) {
	  [CLEditingContext generatePrimaryKey:nil forRecord:anObject];
	  [self registerInstance:anObject];
	}
	[aRelationship setDictionary:mDict andRecord:aRecord
			 usingObject:anObject fieldDefinition:fields];
      }
    }
  }
  
  anArray = [fields allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aKey];
    
    if ((anObject = [aRecord objectValueForBinding:aKey]))
      [mDict setObject:anObject forKey:[anAttr column]];

    /* If a field is set to nil I need to write it. Why would I not?
       Ah of course, because it might be a relationship field and I
       skipped it above for some reason. */
    if ([mDict objectForKey:[anAttr column]] || [anAttr isPrimaryKey] ||
	![skipped containsObject:[anAttr key]])
      [saveFields addObject:anAttr];
  }

  if (![self primaryKeyForRecord:aRecord] || ![self recordExists:aRecord
						 recordDefinition:recordDef]) {
    [CLEditingContext generatePrimaryKey:mDict forRecord:aRecord];
    [db insertDictionary:mDict withAttributes:saveFields into:[recordDef databaseTable]
		  withID:0 errors:&errors];
    if (errors)
      [self error:@"Shouldn't be errors! %@", errors];
    if ((anObject = [self registerInstance:aRecord]) && anObject != aRecord) {
      CLString *errString = [CLString stringWithFormat:@"Saved second instance of %@:%@",
				      [recordDef table], [[self primaryKeyForRecord:aRecord]
					       description]];
#if 0
      [aRecord error:errString];
#else
      fprintf(stderr, "%s\n", [errString UTF8String]);
#endif
    }
    if (!errors)
      [self didInsert:aRecord];
  }
  else {
    aString = [[self class] qualifierForObject:aRecord fromDatabase:NO
			      recordDefinition:recordDef];
    [db updateTable:[recordDef databaseTable] withDictionary:mDict
      andAttributes:saveFields forRow:aString errors:&errors];
    if (!errors)
      [self didUpdate:aRecord];
  }
  
  [mDict release];
  [saveFields release];
  [skipped release];
  
  return errors;
}

-(void) prepareToDeleteRecord:(id) aRecord
{
  CLDictionary *aDict;
  CLArray *anArray;
  CLString *aKey;
  CLRelationship *aRelationship;
  id aValue;
  int i, j, k, l;
  CLRecordDefinition *recordDef;


  recordDef = [CLEditingContext recordDefinitionForClass:[aRecord class]];
  aDict = [recordDef relationships];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aRelationship = [aDict objectForKey:aKey];
    if ([aRelationship isOwner]) {
      if ((aValue = [aRecord objectValueForBinding:aKey])) {
	if ([aRelationship toMany]) {
	  for (k = 0, l = [aValue count]; k < l; k++)
	    [self deleteObject:[aValue objectAtIndex:k]];
	}	
	else
	  [self deleteObject:aValue];
      }
    }
  }

  return;
}

-(id) deleteRecord:(id) aRecord
{
  CLRecordDefinition *recordDef;
  CLMutableString *mString = nil;
  id errors = nil;
  CLDatabase *db;
  id pk;


  if (!(pk = [self primaryKeyForRecord:aRecord]))
    return nil;

  recordDef = [CLEditingContext recordDefinitionForClass:[aRecord class]];
  db = [recordDef database];

  if (![pk isKindOfClass:CLDictionaryClass]) {
    /* Must be a single primary key */
    mString = [CLMutableString stringWithFormat:@"%@ = ",
			       [[[recordDef primaryKeys] objectAtIndex:0] column]];
    if ([pk isKindOfClass:CLStringClass])
      [mString appendFormat:@"'%@'", [db defangString:pk escape:NULL]];
    else if ([pk isKindOfClass:CLDatetimeClass])
      [mString appendFormat:@"'%@'",
	       [pk descriptionWithFormat:[db dateFormat] timeZone:[db timeZone]]];
    else
      [mString appendString:[pk description]];
    pk = mString;
  }
  else
    pk = [[self class] qualifierForObject:pk fromDatabase:NO recordDefinition:recordDef];
        
  [db deleteRowsFromTable:[recordDef databaseTable] qualifier:pk errors:&errors];
  return errors;
}

-(id) saveChanges
{
  return [self saveChangesWithoutTransaction:NO];
}

-(id) saveChangesWithoutTransaction:(BOOL) noTransaction
{
  int i, j;
  int spos, dpos;
  id result;
  CLMutableArray *errors = nil, *databases, *mArray;
  CLMutableArray *saving, *deleting;
  CLDictionary *model;
  CLArray *anArray;
  CLDatabase *db;
  id anObject;


  if (_savingChanges == PREPARING)
    return nil;
  
  if (_savingChanges)
    [self error:@"Already saving changes!"];

  if (![dirty count] && ![delete count])
    return nil;

  _savingChanges = PREPARING;

  [dirty removeObjectsInArray:delete];
  saving = [dirty mutableCopy];
  deleting = [delete mutableCopy];
  spos = dpos = 0;

  do {
    
    for (; spos < [saving count]; spos++) {
      anObject = [saving objectAtIndex:spos];
      [anObject willSaveToDatabase];
    }

    for (; dpos < [deleting count]; dpos++) {
      anObject = [deleting objectAtIndex:dpos];
      [anObject willDeleteFromDatabase];
      [self prepareToDeleteRecord:anObject];
    }

    [dirty removeObjectsInArray:delete];
    [saving removeObjectsInArray:delete];
    mArray = [dirty mutableCopy];
    [mArray removeObjectsInArray:saving];
    [saving addObjectsFromArray:mArray];
    [mArray release];

    mArray = [delete mutableCopy];
    [mArray removeObjectsInArray:deleting];
    [deleting addObjectsFromArray:mArray];
    [mArray release];
  } while (spos < [saving count] || dpos < [deleting count]);

  _savingChanges = SAVING;
  
  model = [CLEditingContext model];
  databases = [[CLMutableArray alloc] init];
  anArray = [model allValues];
  for (i = 0, j = [anArray count]; i < j; i++) {
    if ((db = [[anArray objectAtIndex:i] objectForKey:@"database"]))
      [databases addObject:db];
  }

  if (!noTransaction)
    for (i = 0, j = [databases count]; i < j; i++)
      [[databases objectAtIndex:i] beginTransaction];
  
  for (i = ((int) [saving count]) - 1; i >= 0; i--) {
    /* FIXME - check if object needs others to be saved first */
    anObject = [saving objectAtIndex:i];
    if ([anObject isFault])
      [self error:@"Trying to save an object that hasn't been faulted in.\n"];
    result = [self saveRecord:anObject];
    if (result) {
      if (!errors)
	errors = [CLMutableArray array];
      [errors addObject:result];
    }
  }

  for (i = ((int) [deleting count]) - 1; i >= 0; i--) {
    anObject = [deleting objectAtIndex:i];
    result = [self deleteRecord:anObject];
    if (result) {
      if (!errors)
	errors = [CLMutableArray array];
      [errors addObject:result];
    }
  }
  
  if (!errors) {
    if (!noTransaction)
      for (i = 0, j = [databases count]; i < j; i++)
	[[databases objectAtIndex:i] commitTransaction];
    for (i = 0, j = [inserted count]; i < j; i++)
      [[inserted objectAtIndex:i] didInsertIntoDatabase];
    for (i = 0, j = [updated count]; i < j; i++)
      [[updated objectAtIndex:i] didUpdateDatabase];
    for (i = 0, j = [deleting count]; i < j; i++)
      [[deleting objectAtIndex:i] didDeleteFromDatabase];

    [dirty removeObjectsInArray:saving];
    [inserted removeAllObjects];
    [updated removeAllObjects];
    [delete removeObjectsInArray:deleting];
  }
  else {
    fprintf(stderr, "Errors during transaction: %s\n", [[errors description] UTF8String]);
    for (i = 0, j = [databases count]; i < j; i++)
      [[databases objectAtIndex:i] rollbackTransaction];
  }
  
  [databases release];
  [saving release];
  [deleting release];
  
  _savingChanges = DONE;
  
  return errors;
}

-(id) loadObjectWithClass:(Class) aClass objectID:(CLUInteger) anID
{
  return [self loadObjectWithClass:aClass primaryKey:[CLNumber numberWithUnsignedInt:anID]];
}

-(id) loadExistingObjectWithClass:(Class) aClass objectID:(CLUInteger) anID
{
  return [self loadExistingObjectWithClass:aClass
				primaryKey:[CLNumber numberWithUnsignedInt:anID]];
}

-(id) loadObjectWithClass:(Class) aClass primaryKey:(id) pk
{
  CLString *table;
  CLAutoreleasePool *pool;
  id anObject;


  pool = [[CLAutoreleasePool alloc] init];
  if (!(anObject = [self loadExistingObjectWithClass:aClass primaryKey:pk])) {
    table = [CLEditingContext tableForClass:aClass];
    anObject = CLNewFault(pk, [CLEditingContext recordDefinitionForClass:aClass]);
    [self registerInstance:anObject inTable:table withPrimaryKey:pk];
  }
  [anObject retain];
  [pool release];
  return [anObject autorelease];
}

-(id) loadExistingObjectWithClass:(Class) aClass primaryKey:(id) pk
{
  CLString *table;
  CLArray *anArray;
  CLAutoreleasePool *pool;
  id anObject = nil;
  CLRecordDefinition *recordDef;
  CLMutableString *mString;
  CLDatabase *db;


  pool = [[CLAutoreleasePool alloc] init];
  recordDef = [CLEditingContext recordDefinitionForClass:aClass];
  table = [recordDef table];

  if (!(anObject = [self recordForPrimaryKey:pk inTable:table])) {
    if (![pk isKindOfClass:CLDictionaryClass]) {
      /* Must be a single primary key */
      mString = [CLMutableString stringWithFormat:@"%@ = ",
				 [[[recordDef primaryKeys] objectAtIndex:0] column]];
      db = [recordDef database];
      if ([pk isKindOfClass:CLStringClass])
	[mString appendFormat:@"'%@'", [db defangString:pk escape:NULL]];
      else if ([pk isKindOfClass:CLDatetimeClass])
	[mString appendFormat:@"'%@'",
		 [pk descriptionWithFormat:[db dateFormat] timeZone:[db timeZone]]];
      else
	[mString appendString:[pk description]];
      pk = mString;
    }
    else
      pk = [[self class] qualifierForObject:pk fromDatabase:NO recordDefinition:recordDef];
        
    anArray = [self loadTableWithRecordDefinition:recordDef qualifier:pk];
    if ([anArray count])
      anObject = [anArray objectAtIndex:0];
  }
  [anObject retain];
  [pool release];
  return [anObject autorelease];
}

-(CLArray *) loadTableWithRecordDefinition:(CLRecordDefinition *) recordDef
				     array:(CLArray *) anArray
{
  int i, j;
  CLMutableArray *mArray;
  CLDictionary *aDict, *pk;
  id anObject;
  CLAutoreleasePool *pool;


  pool = [[CLAutoreleasePool alloc] init];

  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aDict = [anArray objectAtIndex:i];
    pk = [CLEditingContext constructPrimaryKey:aDict recordDef:recordDef
				  fromDatabase:YES asDictionary:NO];
    if (!(anObject = [self recordForPrimaryKey:pk inTable:[recordDef table]])) {
      anObject = CLNewFault(aDict, recordDef);
      [self registerInstance:anObject inTable:[recordDef table] withPrimaryKey:pk];
    }
    else
      [anObject retain];
    [mArray addObject:anObject];
    [anObject release];
  }
  [pool release];

  return [mArray autorelease];
}

-(CLArray *) loadTableWithRecordDefinition:(CLRecordDefinition *) recordDef
				 qualifier:(id) qual
{
  return [self loadTableWithRecordDefinition:recordDef qualifier:qual orderBy:nil];
}

-(CLArray *) loadTableWithRecordDefinition:(CLRecordDefinition *) recordDef
				 qualifier:(id) qual orderBy:(CLString *) order
{
  CLArray *rows;
  CLArray *anArray = nil;
  CLMutableArray *attr;
  CLMutableString *mString;
  id errors = nil;
  CLAutoreleasePool *pool;
  Class class1, class2;


  class1 = [recordDef recordClass];
  class2 = [CLEditingContext classForTable:[recordDef table]];
  if (class1 != class2)
    [self error:@"Bogus class finder! %@ %@", [class1 className], [class2 className]];

  pool = [[CLAutoreleasePool alloc] init];
  [CLEditingContext createSelect:&mString andAttributes:&attr forRecordDefinition:recordDef];

  if ([qual isKindOfClass:CLDictionaryClass])
    qual = [CLEditingContext generateQualifier:qual];

  if ([qual length])
    [mString appendFormat:@" where %@", qual];
  if (order)
    [mString appendFormat:@" order by %@", order];
      
  rows = [[recordDef database] read:attr qualifier:mString errors:&errors];
  if (errors)
    fprintf(stderr, "Errors loading table: \"%s\"\n%s\n", [mString UTF8String],
	    [[errors description] UTF8String]);
  [mString release];
  [attr release];

  if ([rows count])
    anArray = [[self loadTableWithRecordDefinition:recordDef array:rows] retain];
  [pool release];

  return [anArray autorelease];
}

-(CLArray *) loadTableWithClass:(Class) aClass qualifier:(id) qual
{
  return [self loadTableWithRecordDefinition:[CLEditingContext recordDefinitionForClass:aClass]
				   qualifier:qual orderBy:nil];
}

-(CLArray *) loadTableWithClass:(Class) aClass qualifier:(id) qual orderBy:(CLString *) order
{
  return [self loadTableWithRecordDefinition:[CLEditingContext recordDefinitionForClass:aClass]
				   qualifier:qual orderBy:order];
}

-(CLArray *) loadTableWithClass:(Class) aClass array:(CLArray *) anArray
{
  CLRecordDefinition *recordDef;
  CLAutoreleasePool *pool;


  pool = [[CLAutoreleasePool alloc] init];
  recordDef = [CLEditingContext recordDefinitionForClass:aClass];
  anArray = [[self loadTableWithRecordDefinition:recordDef array:anArray] retain];
  [pool release];

  return [anArray autorelease];
}

@end

@implementation CLEditingContext (CLRecordDefinition)

+(id) classForTable:(CLString *) aTable
{
  id aClass;
  CLString *aString;
  CLAutoreleasePool *pool;


  if (!_classTable)
    [self model];
  
  if (!(aClass = CLHashTableDataForKey(_classTable, aTable, [aTable hash],
				       @selector(isEqual:)))) {
    pool = [[CLAutoreleasePool alloc] init];
    aClass = [[self recordDefinitionForTable:aTable] recordClass];

    /* Make a copy because aTable could be mutable */
    aString = [aTable copy];
    CLHashTableSetData(_classTable, aClass, aString, [aString hash]);
    CLHashTableSetData(_tableClass, aString, aClass, (size_t) aClass);
    [pool release];
  }

  return aClass;
}

+(CLString *) tableForClass:(id) aClass
{
  CLString *aTable;
  CLDictionary *model;
  int i, j, k, l;
  CLArray *anArray, *keys;
  CLDictionary *schema;
  CLString *aString;
  CLAutoreleasePool *pool;
  

  if (!aClass)
    [self error:@"Cannot lookup table for nonexistant class"];
  if (![aClass isClass])
    [self error:@"Can only lookup classes!"];

  if (!_tableClass)
    [self model];
  
  if (!(aTable = CLHashTableDataForIdenticalKey(_tableClass, aClass, (size_t) aClass))) {
    pool = [[CLAutoreleasePool alloc] init];
    model = [CLEditingContext model];
    
    anArray = [model allKeys];
    for (k = 0, l = [anArray count]; k < l; k++) {
      schema = [[model objectForKey:[anArray objectAtIndex:k]] objectForKey:@"schema"];
      keys = [schema allKeys];
      for (i = 0, j = [keys count]; i < j; i++) {
	if ([[schema objectForKey:[keys objectAtIndex:i]] recordClass] == aClass) {
	  aTable = [CLString stringWithFormat:@"%@.%@",
			[anArray objectAtIndex:k], [keys objectAtIndex:i]];
	  break;
	}
      }

      if (i < j)
	break;
    }

    if (k == l) {
      CLString *className = [aClass className];

      
      for (k = 0, l = [anArray count]; k < l; k++) {
	schema = [[model objectForKey:[anArray objectAtIndex:k]] objectForKey:@"schema"];
	keys = [schema allKeys];
	for (i = 0, j = [keys count]; i < j; i++) {
	  aString = [keys objectAtIndex:i];
	  if ([className isEqualToString:aString] ||
	      [[className underscore_case_string] isEqualToString:aString]) {
	    aTable = [CLString stringWithFormat:@"%@.%@",
			 [anArray objectAtIndex:k], aString];
	    break;
	  }
	}

	if (i < j)
	  break;
      }
    }

    if (aTable) {
      CLHashTableSetData(_classTable, aClass, [aTable retain], [aTable hash]);
      CLHashTableSetData(_tableClass, aTable, aClass, (size_t) aClass);
    }
    
    [pool release];
  }

  return aTable;
}

+(CLRecordDefinition *) recordDefinitionForClass:(Class) aClass
{
  CLRecordDefinition *recordDef;


  if (!_classDefs)
    [self model];
  
  if (!(recordDef = CLHashTableDataForIdenticalKey(_classDefs, aClass, (size_t) aClass)) &&
      (recordDef = [self recordDefinitionForTable:[self tableForClass:aClass]]))
    CLHashTableSetData(_classDefs, recordDef, aClass, (size_t) aClass);

#if 0
  if (![recordDef isKindOfClass:CLRecordDefinitionClass])
    [self error:@"WTF"];
#endif
  
  return recordDef;
}

+(CLRecordDefinition *) recordDefinitionForTable:(CLString *) aTable
{
  CLRecordDefinition *recordDef;
  CLDictionary *model;
  CLRange aRange;
  CLString *database, *table;
  CLAutoreleasePool *pool;


  if (!_tableDefs)
    [self model];
  
  if (!(recordDef = CLHashTableDataForKey(_tableDefs, aTable, [aTable hash],
					  @selector(isEqual:)))) {
    pool = [[CLAutoreleasePool alloc] init];
    model = [CLEditingContext model];

    aRange = [aTable rangeOfString:@"."];
    database = [aTable substringToIndex:aRange.location];
    table = [aTable substringFromIndex:CLMaxRange(aRange)];

    recordDef = [[[model objectForKey:database] objectForKey:@"schema"] objectForKey:table];
    CLHashTableSetData(_tableDefs, recordDef, [aTable copy], [aTable hash]);
    [pool release];
  }

#if 0
  if (![recordDef isKindOfClass:CLRecordDefinitionClass])
    [self error:@"WTF"];
#endif
  
  return recordDef;
}

@end
