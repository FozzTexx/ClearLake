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

#import "CLGenericRecord.h"
#import "CLEditingContext.h"
#import "CLManager.h"
#import "CLDatabase.h"
#import "CLAttribute.h"
#import "CLMutableString.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLPage.h"
#import "CLBlock.h"
#import "CLInvocation.h"
#import "CLMethodSignature.h"
#import "CLNumber.h"
#import "CLRelationship.h"
#import "CLHashTable.h"
#import "CLAccount.h"
#import "CLAutoreleasePool.h"
#import "CLNull.h"
#import "CLPlaceholder.h"
#import "CLMySQLDatabase.h"
#import "CLSybaseDatabase.h"
#import "CLTimeZone.h"
#import "CLCalendarDate.h"
#import "CLObjCAPI.h"

#include <stdlib.h>
#include <wctype.h>

#define MAX_HASH	10
#define DONTCHANGE	-2

static CLMutableDictionary *_instancesDict = nil;
static id _model = nil;

@interface CLGenericRecord (CLMagicNew)
-(void) edit:(id) sender;
@end

@implementation CLGenericRecord

+(void) decodeSchema:(CLMutableDictionary *) aSchema databaseName:(CLString *) aDatabase
{
  CLArray *keys;
  int i, j;
  CLString *aKey;
  CLMutableDictionary *mDict;

  
  keys = [aSchema allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    aKey = [keys objectAtIndex:i];
    mDict = [[aSchema objectForKey:aKey] mutableCopy];

    {
      id anObject;
      CLArray *anArray;
      CLMutableDictionary *fields;
      CLAttribute *anAttr;
      int k, l;


      fields = [[CLMutableDictionary alloc] init];
      anObject = [mDict objectForKey:@"fields"];
      if ([anObject isKindOfClass:[CLArray class]]) {
	anArray = CLAttributesFromArray([mDict objectForKey:@"fields"]);
	for (k = 0, l = [anArray count]; k < l; k++) {
	  anAttr = [anArray objectAtIndex:k];
	  [fields setObject:anAttr forKey:[[anAttr name] lowerCamelCaseString]];
	}
      }
      else {
	anArray = [anObject allKeys];
	for (k = 0, l = [anArray count]; k < l; k++) {
	  anAttr = [CLAttribute attributeFromString:
				  [anObject objectForKey:[anArray objectAtIndex:k]]];
	  [fields setObject:anAttr forKey:[anArray objectAtIndex:k]];
	}
      }
      [mDict setObject:fields forKey:@"fields"];
      [fields release];
    }

    {
      int k, l;
      CLMutableDictionary *relations;
      CLArray *anArray;
      id anObject;
      CLString *aString;


      relations = [[CLMutableDictionary alloc] init];
      anObject = [mDict objectForKey:@"relationships"];
      anArray = [anObject allKeys];
      for (k = 0, l = [anArray count]; k < l; k++) {
	aString = [anArray objectAtIndex:k];
	[relations setObject:[[[CLRelationship alloc]
				initFromString:[anObject objectForKey:aString]
				databaseName:aDatabase] autorelease]
		   forKey:[aString lowerCamelCaseString]];
      }
      [mDict setObject:relations forKey:@"relationships"];
      [relations release];
    }

    {
      id anObject;

      
      if (!(anObject = [mDict objectForKey:@"class"]))
	[mDict setObject:[aKey upperCamelCaseString] forKey:@"class"];
    }

    [aSchema setObject:mDict forKey:aKey];
    [mDict release];
  }

  return;
}

+(void) findDependencies:(CLMutableDictionary *) aSchema databaseName:(CLString *) aDatabase
{
  CLArray *keys;
  int i, j;
  CLString *aTable;
  CLMutableDictionary *mDict;

  
  keys = [aSchema allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    aTable = [keys objectAtIndex:i];
    mDict = [aSchema objectForKey:aTable];

    {
      int k, l;
      CLMutableDictionary *relations;
      CLArray *anArray;
      CLString *relName;
      CLRelationship *aRel;


      relations = [mDict objectForKey:@"relationships"];
      anArray = [relations allKeys];
      for (k = 0, l = [anArray count]; k < l; k++) {
	relName = [anArray objectAtIndex:k];
	aRel = [relations objectForKey:relName];
	if (![aRel toMany]) {
	  CLDictionary *aDict, *theirDef;
	  CLAttribute *anAttr;
	  CLString *fieldName;
	  CLArray *theirFields;
	  int m, n, nk;


	  theirDef = [[self class] recordDefForTable:[aRel theirTable]];
	  aDict = [theirDef objectForKey:@"fields"];
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
    }
  }

  /* FIXME - check for mutual dependencies */
  for (i = 0, j = [keys count]; i < j; i++) {
    aTable = [keys objectAtIndex:i];
    mDict = [aSchema objectForKey:aTable];
    aTable = [CLString stringWithFormat:@"%@.%@", aDatabase, aTable];

    {
      int k, l;
      CLMutableDictionary *relations;
      CLArray *anArray;
      CLString *relName;
      CLRelationship *aRel;


      relations = [mDict objectForKey:@"relationships"];
      anArray = [relations allKeys];
      for (k = 0, l = [anArray count]; k < l; k++) {
	relName = [anArray objectAtIndex:k];
	aRel = [relations objectForKey:relName];
	if ([aRel isDependent]) {
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

+(CLDictionary *) recordDefForTable:(CLString *) aTable
{
  CLDictionary *model;
  CLRange aRange;
  CLString *database, *table;

  
  model = [self model];
  aRange = [aTable rangeOfString:@"."];
  if (!aRange.length)
    aTable = [CLString stringWithFormat:@"%@.%@",
			[[model allKeys] objectAtIndex:0], aTable];

  aRange = [aTable rangeOfString:@"."];
  database = [aTable substringToIndex:aRange.location];
  table = [aTable substringFromIndex:CLMaxRange(aRange)];

  return [[[model objectForKey:database] objectForKey:@"schema"] objectForKey:table];
}

+(id) classForTable:(CLString *) aString
{
  id aClass = nil;
  CLString *aString2;
  CLRange aRange;
  CLString *localTable;


  if ((aString2 = [[self recordDefForTable:aString] objectForKey:@"class"]))
    aClass = objc_lookUpClass([aString2 UTF8String]);
  else {
    aRange = [aString rangeOfString:@"."];
    localTable = [aString substringFromIndex:CLMaxRange(aRange)];
    aClass = objc_lookUpClass([[localTable upperCamelCaseString] UTF8String]);
  }
    
  if (!aClass)
    aClass = [CLGenericRecord class];

  return aClass;
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

+(CLArray *) loadTable:(CLString *) table qualifier:(id) qual
{
  CLDatabase *db;
  CLArray *rows;
  CLDictionary *aDict;
  CLArray *anArray = nil;
  CLMutableArray *attr;
  CLMutableString *mString;
  CLString *aString;
  CLAttribute *anAttr;
  int i, j;
  CLRange aRange;
  CLString *localTable;
  id errors = nil;


  aRange = [table rangeOfString:@"."];
  if (aRange.length) {
    db = [self databaseNamed:[table substringToIndex:aRange.location]];
    localTable = [table substringFromIndex:CLMaxRange(aRange)];
  }
  else {
    CLDictionary *model = [self model];

    
    if ([model count] > 1)
      [self error:@"No database specified for table \"%@\"", table];
    db = [self databaseNamed:[[model allKeys] objectAtIndex:0]];
    localTable = table;
  }

  if ((aDict = [self recordDefForTable:table])) {
    attr = [[CLMutableArray alloc] init];
    mString = [[CLMutableString alloc] init];
    rows = [[aDict objectForKey:@"fields"] allValues];
    for (i = 0, j = [rows count]; i < j; i++) {
      anAttr = [rows objectAtIndex:i];
      if ([mString length])
	[mString appendString:@", "];
      [attr addObject:anAttr];
      [mString appendString:[anAttr name]];
    }

    if ([qual isKindOfClass:[CLDictionary class]])
      qual = [self generateQualifier:qual];
  
    if ([qual length])
      aString = [CLString stringWithFormat:@"select %@ from %@ where %@",
			  mString, localTable, qual];
    else
      aString = [CLString stringWithFormat:@"select %@ from %@", mString, localTable];
    rows = [db read:attr qualifier:aString errors:&errors];
    if (errors)
      fprintf(stderr, "Errors loading table: %s\n", [[errors description] UTF8String]);
    [mString release];
    [attr release];

    if ([rows count])
      anArray = [self loadTable:table array:rows];
  }

  return anArray;
}

+(CLDictionary *) constructPrimaryKey:(CLDictionary *) record table:(CLString *) aTable
{
  CLMutableDictionary *mDict;
  CLDictionary *recordDef, *fields;
  CLArray *anArray;
  CLAttribute *anAttr;
  CLString *aString;
  int i, j;


  mDict = [[CLMutableDictionary alloc] init];
  recordDef = [self recordDefForTable:aTable];
  fields = [recordDef objectForKey:@"fields"];
  anArray = [fields allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aString];
    if ([anAttr isPrimaryKey])
      [mDict setObject:[record objectForKey:[anAttr name]] forKey:aString];
  }  

  return [mDict autorelease];
}

+(CLArray *) loadTable:(CLString *) table array:(CLArray *) anArray
{
  int i, j;
  CLMutableArray *mArray;
  CLDictionary *aDict, *pk;
  id aClass, anObject;
  CLHashTable *hTable;


  aClass = [self classForTable:table];
  hTable = [_instancesDict objectForKey:table];

  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aDict = [anArray objectAtIndex:i];
    pk = [self constructPrimaryKey:aDict table:table];
    if (!(anObject = [hTable dataForKey:pk hash:[pk hash]]))
      anObject = [[[aClass alloc] initFromDictionary:aDict table:table] autorelease];
    [mArray addObject:anObject];
  }

  return [mArray autorelease];
}

+(CLGenericRecord *) registerInstance:(CLGenericRecord *) anObject
{
  CLGenericRecord *realObject;
  CLString *table;
  CLHashTable *hTable;
  id pk;


  if (!(pk = [anObject primaryKey]))
    return nil;

  if (!(table = [anObject table]))
    return nil;
  
  if (!(hTable = [_instancesDict objectForKey:table])) {
    if (!_instancesDict)
      _instancesDict = [[CLMutableDictionary alloc] init];
    hTable = [[CLHashTable alloc] init];
    [_instancesDict setObject:hTable forKey:table];
    [hTable release];
  }

  if (!(realObject = [hTable dataForKey:pk hash:[pk hash]])) {
    realObject = anObject;
    [hTable setData:realObject forKey:[pk retain] hash:[pk hash]];
  }

  return realObject;
}

+(void) unregisterInstance:(CLGenericRecord *) anObject
{
  CLString *table;
  CLHashTable *hTable;
  id pk;


  if (!(pk = [anObject primaryKey]))
    return;

  if ((table = [anObject table])) {
    hTable = [_instancesDict objectForKey:table];
    if ([hTable dataForKey:pk hash:[pk hash]] == anObject) {
      pk = [hTable keyForKey:pk hash:[pk hash]];
      [hTable removeDataForKey:pk hash:[pk hash]];
      [pk release];
      if (![hTable count])
	[_instancesDict removeObjectForKey:table];
      if (![_instancesDict count]) {
	[_instancesDict release];
	_instancesDict = nil;
      }
    }
  }

  return;
}

+(id) findInstance:(CLString *) aTable primaryKey:(id) aKey
{
  id anObject = nil;
  CLHashTable *hTable;


  hTable = [_instancesDict objectForKey:aTable];
  anObject = [hTable dataForKey:aKey hash:[aKey hash]];

  return anObject;
}

+(CLString *) tableForClass:(id) aClass
{
  return [self tableForClassName:[aClass className]];
}

+(CLString *) tableForClassName:(CLString *) aString
{
  CLDictionary *model = [self model];
  int i, j, k, l;
  CLArray *anArray, *keys;
  CLDictionary *schema;
  CLString *aString2;


  anArray = [model allKeys];
  for (k = 0, l = [anArray count]; k < l; k++) {
    schema = [[model objectForKey:[anArray objectAtIndex:k]] objectForKey:@"schema"];
    keys = [schema allKeys];
    for (i = 0, j = [keys count]; i < j; i++) {
      aString2 = [[schema objectForKey:[keys objectAtIndex:i]] objectForKey:@"class"];
      if ([aString2 isEqualToString:aString]) {
	aString = [CLString stringWithFormat:@"%@.%@",
			    [anArray objectAtIndex:k], [keys objectAtIndex:i]];
	return aString;
      }
    }
  }

  for (k = 0, l = [anArray count]; k < l; k++) {
    schema = [[model objectForKey:[anArray objectAtIndex:k]] objectForKey:@"schema"];
    keys = [schema allKeys];
    for (i = 0, j = [keys count]; i < j; i++) {
      aString2 = [keys objectAtIndex:i];
      if ([aString isEqualToString:aString2] ||
	  [[aString underscore_case_string] isEqualToString:aString2]) {
	aString = [CLString stringWithFormat:@"%@.%@",
			    [anArray objectAtIndex:k], aString2];
	return aString;
      }
    }
  }

  return nil;
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
    if (!(anObject = [aDict objectForKey:aKey]) ||
	[anObject isKindOfClass:[CLNull class]])
      [mString appendString:@" is null"];
    else if ([anObject isKindOfClass:[CLString class]])
      [mString appendFormat:@" = '%@'", [CLDatabase defangString:anObject escape:NULL]];
    else
      [mString appendFormat:@" = %@", anObject];
  }

  return [mString autorelease];
}

-(id) initFromDictionary:(CLDictionary *) aDict table:(CLString *) aString
{
  CLGenericRecord *anObject;
  id aValue;
  int i, j;
  CLDictionary *fields;
  CLAttribute *anAttr;
  CLArray *anArray;
  CLRange aRange;


  [super init];

#if 0
  if (!aString) {
    [self release];
    return nil;
  }
#endif
  
  _changed = DONTCHANGE;
  
  aRange = [aString rangeOfString:@"."];
  if (!aRange.length) {
    CLDictionary *model = [[self class] model];


    if ([model count] > 1)
      [self error:@"No database specified for table \"%@\"", aString];
    aString = [CLString stringWithFormat:@"%@.%@",
			[[model allKeys] objectAtIndex:0], aString];
  }
  
  _table = [aString copy];
  _record = [[CLHashTable alloc] initWithSize:MAX_HASH];
  _recordDef = [[[self class] recordDefForTable:aString] retain];
  _loaded = nil;
  _autoretain = nil;
  _db = nil;
  _dbPrimaryKey = nil;

  fields = [_recordDef objectForKey:@"fields"];
  anArray = [fields allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aString];
    if ((aValue = [aDict objectForKey:[anAttr name]]) &&
	![aValue isKindOfClass:[CLNull class]])
      [self setObjectValue:aValue forBinding:aString];
  }

  _changed = NO;
  
  if ((anObject = [[self class] registerInstance:self]) && anObject != self) {
    [anObject retain];
    [self release];
    self = anObject;
  }

  return self;
}

-(id) initFromObjectID:(int) anID table:(CLString *) aString
{
  CLMutableDictionary *mDict;
  id anObject;


  mDict = [[CLMutableDictionary alloc] init];
  [mDict setObject:[CLNumber numberWithInt:anID] forKey:@"id"];
  anObject = [self initFromDictionary:mDict table:aString];
  [mDict release];
  return anObject;
}

-(id) initFromObjectID:(int) anID
{
  CLString *aString = [[self class] className];


  if ([aString isEqualToString:@"CLGenericRecord"])
    [self doesNotRecognize:_cmd];
  return [self initFromObjectID:anID table:[[self class] tableForClassName:aString]];
}

-(id) initFromDictionary:(CLDictionary *) aDict
{
  CLString  *aString = [[self class] className];


  if ([aString isEqualToString:@"CLGenericRecord"])
    [self doesNotRecognize:_cmd];
  return [self initFromDictionary:aDict table:[[self class] tableForClassName:aString]];
}

-(id) init
{
  CLString *aString = [[self class] className];


  return [self initFromDictionary:nil table:[[self class] tableForClassName:aString]];
}

-(void) new:(id) sender
{
  [self generatePrimaryKey:nil];
  [self edit:sender];
  return;
}

-(CLRelationship *) theirRelationship:(CLRelationship *) ours named:(CLString **) aName
{
  CLDictionary *aDict;
  int i, j;
  CLArray *anArray;
  CLRelationship *theirs;


  *aName = nil;
  if ((aDict = [[[self class] recordDefForTable:[ours theirTable]]
		 objectForKey:@"relationships"])) {
    anArray = [aDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      theirs = [aDict objectForKey:[anArray objectAtIndex:i]];
      if ([theirs isReciprocal:ours forTable:_table]) {
	*aName = [anArray objectAtIndex:i];
	return theirs;
      }
    }
  }

  return nil;
}

-(BOOL) shouldRetain:(CLString *) aString
{
  int i, j;
  CLArray *anArray;
  CLDictionary *aDict;
  CLString *aKey;
  CLRelationship *aRel;
  CLString *aName;
  BOOL sr = NO;


  anArray = [[_recordDef objectForKey:@"fields"] allKeys];
  for (i = 0, j = [anArray count]; i < j; i++)
    if ([aString isEqualToString:[anArray objectAtIndex:i]]) {
      sr = YES;
      break;
    }

  if (!sr) {
    aDict = [_recordDef objectForKey:@"relationships"];
    anArray = [aDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aKey = [anArray objectAtIndex:i];
      aRel = [aDict objectForKey:aKey];
      if ([aString isEqualToString:aKey] &&
	  ([aRel isOwner] || [aRel toMany] ||
	   ![self theirRelationship:aRel named:&aName])) {
	sr = YES;
	break;
      }
    }
  }

  return sr;
}

-(void) dealloc
{
  CLAutoreleasePool *pool = [[CLAutoreleasePool alloc] init];
  int i, j;
  CLArray *anArray;
  CLString *aKey;
  void *var;
  int aType;
  id *data;


  anArray = [[_recordDef objectForKey:@"relationships"] allKeys];
  for (i = 0, j = [anArray count]; i < j; i++)
    [self unloadRelationship:[anArray objectAtIndex:i]];

  [[self class] unregisterInstance:self];

  j = [_record count];
  if (!(data = malloc(sizeof(id) * j)))
    [self error:@"Unable to allocate memory"];
  [_record getKeys:data];
  for (i = 0; i < j; i++) {
    aKey = data[i];
    if ([_autoretain containsObject:aKey])
      [((id) [_record dataForKey:aKey hash:[aKey hash]]) release];
  }
  for (i = 0; i < j; i++)
    [data[i] release];
  free(data);
  [_record release];

  for (i = 0, j = [_autoretain count]; i < j; i++) {
    aKey = [_autoretain objectAtIndex:i];
    if ((var = [self pointerForIvar:aKey type:&aType])) {
      switch (aType) {
      case _C_ID:
	[(*(id *) var) release];
	break;
      case _C_CHARPTR:
	free(*(char **) var);
	break;
      }
    }
  }

  [_table release];
  [_recordDef release];
  [_loaded release];
  [_primaryKey release];
  [_dbPrimaryKey release];
  [_autoretain release];

  _table = nil;
  _record = nil;
  _recordDef = nil;
  _loaded = nil;
  _primaryKey = nil;
  _dbPrimaryKey = nil;
  _autoretain = nil;
  
  [pool release];
  [super dealloc];
  return;
}

-(void) read:(CLTypedStream *) stream
{
  CLGenericRecord *anObject;
  CLDictionary *pk;
  CLArray *anArray;
  CLString *aKey;
  int i, j;


  [super read:stream];
  CLReadTypes(stream, "@@", &pk, &_table);
  _record = [[CLHashTable alloc] initWithSize:MAX_HASH];
  _recordDef = [[[self class] recordDefForTable:_table] retain];
  _loaded = nil;
  _autoretain = nil;
  _db = nil;
  _dbPrimaryKey = nil;
  _changed = DONTCHANGE;

  anArray = [pk allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    [self setObjectValue:[pk objectForKey:aKey] forBinding:aKey];
  }

  _changed = NO;
  [CLDefaultContext removeObject:self];

  if ((anObject = [[self class] registerInstance:self]) && anObject != self) {
    /* FIXME - replace ourselves or become a proxy. At the moment I
       hacked CLReadObject & CLReadType. */
#if 0
    [self error:@"Read second instance of %@:%@",  _table, [self primaryKey]];
#else
    fprintf(stderr, "Read second instance of %s:%s",  [_table UTF8String],
	    [[[self primaryKey] description] UTF8String]);
#endif
  }

  return;
}

-(void) write:(CLTypedStream *) stream
{
  id pk;


  [super write:stream];
  pk = [self primaryKey];
  CLWriteTypes(stream, "@@", &pk, &_table);
  return;
}

-(id) copy
{
  return [self retain];
}

-(CLDatabase *) database
{
  CLRange aRange;

  
  if (!_db) {
    aRange = [_table rangeOfString:@"."];
    _db = [[self class] databaseNamed:[_table substringToIndex:aRange.location]];
  }  

  return _db;
}

-(void) setLoaded:(CLString *) aString
{
  if (!_loaded)
    _loaded = [[CLMutableArray alloc] init];
  if (![_loaded containsObject:aString])
    [_loaded addObject:aString];
  return;
}

-(void) loadRelationship:(CLString *) aKey
{
  CLString *qual = nil, *relName;
  CLDictionary *keyDict;
  CLArray *anArray;
  CLMutableArray *mArray;
  CLRelationship *aRelationship;
  CLGenericRecord *aValue = nil;
  int i, j;
  BOOL oldChanged = _changed;
  BOOL otherChanged, wasLoaded;


  if ([_loaded containsObject:aKey])
    return;

  wasLoaded = [_loaded containsObject:aKey];
  [self setLoaded:aKey];

  aRelationship = [[_recordDef objectForKey:@"relationships"] objectForKey:aKey];
  [self theirRelationship:aRelationship named:&relName];

  if ((keyDict = [aRelationship constructKey:self]))
    qual = [aRelationship constructQualifierFromDictionary:keyDict];
  
  if (![aRelationship toMany]) {
    if (keyDict) {
      aValue = [[[self class] findInstance:[aRelationship theirTable] primaryKey:keyDict]
		 retain];
      if (!aValue) {
	anArray = [[self class] loadTable:[aRelationship theirTable] qualifier:qual];
	if ([anArray count])
	  aValue = [[anArray objectAtIndex:0] retain];
      }
    }

    _changed = DONTCHANGE;
    [self setObjectValue:aValue forBinding:aKey];
    _changed = oldChanged;
    if (relName && aValue) {
      otherChanged = aValue->_changed;
      aValue->_changed = DONTCHANGE;
      [aValue addObject:self toRelationship:relName];
      aValue->_changed = otherChanged;
    }
    else if (!aValue && !wasLoaded) /* FIXME - don't set loaded if object doesn't exist? */
      [_loaded removeObject:aKey];
    [aValue autorelease];
  }
  else {
    mArray = [[CLMutableArray alloc] init];
    _changed = DONTCHANGE;
    [self setObjectValue:mArray forBinding:aKey];
    _changed = oldChanged;
    if (keyDict) {
      anArray = [[self class] loadTable:[aRelationship theirTable] qualifier:qual];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aValue = [anArray objectAtIndex:i];
	[mArray addObject:aValue];
	if (relName && aValue) {
	  otherChanged = aValue->_changed;
	  aValue->_changed = DONTCHANGE;
	  [aValue addObject:self toRelationship:relName];
	  aValue->_changed = otherChanged;
	}
      }
    }
    [mArray release];
  }
  
  return;
}

/* This creates a string which will identify this object in the database */
-(CLString *) generateQualifier
{
  CLDictionary *fields;
  CLAttribute *anAttr;
  CLMutableDictionary *mDict;
  CLString *aKey;
  CLArray *anArray;
  id anObject;
  int i, j;


  fields = [_recordDef objectForKey:@"fields"];
  anArray = [fields allKeys];
  mDict = [CLMutableDictionary dictionary];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aKey];
    if ([anAttr isPrimaryKey]) {
      if (!(anObject = [super objectValueForBinding:aKey]))
	anObject = [CLNull null];
      [mDict setObject:anObject forKey:[anAttr name]];
    }
  }

  return [[self class] generateQualifier:mDict];
}

-(void) loadFields
{
  CLDatabase *db = [self database];
  CLArray *rows;
  CLMutableString *query;
  int i, j, k;
  CLDictionary *fields;
  CLMutableArray *attr;
  CLDictionary *aDict;
  CLString *aKey;
  CLMutableArray *mArray;
  CLAttribute *anAttr;
  BOOL oldChanged = _changed;
  id aValue;


  if (![self primaryKey])
    return;

  query = [[CLMutableString alloc] init];
  [query appendString:@"select "];
  fields = [_recordDef objectForKey:@"fields"];
  attr = [[CLMutableArray alloc] init];
  mArray = [[fields allKeys] mutableCopy];
  for (i = k = 0, j = [mArray count]; i < j; i++) {
    aKey = [mArray objectAtIndex:i];
    anAttr = [fields objectForKey:aKey];
    if ([_loaded containsObject:aKey]) {
      [mArray removeObjectAtIndex:i];
      i--;
      j--;
      continue;
    }

    if (k)
      [query appendString:@", "];
    k++;
    [query appendString:[anAttr name]];
    [attr addObject:[fields objectForKey:aKey]];
  }

  if (k) {
    CLRange aRange;
    CLString *localTable;
    id errors = nil;
    

    aRange = [_table rangeOfString:@"."];
    localTable = [_table substringFromIndex:CLMaxRange(aRange)];
    [query appendFormat:@" from %@ where %@", localTable, [self generateQualifier]];
    rows = [db read:attr qualifier:query errors:&errors];
    if (errors)
      fprintf(stderr, "Errors loading table: %s\n", [[errors description] UTF8String]);

    if ([rows count]) {
      aDict = [rows objectAtIndex:0];
      for (i = 0, j = [mArray count]; i < j; i++) {
	aKey = [mArray objectAtIndex:i];
	anAttr = [fields objectForKey:aKey];
	aValue = [aDict objectForKey:[anAttr name]];
	if ([aValue isKindOfClass:[CLNull class]])
	  aValue = nil;
	_changed = DONTCHANGE;
	[self setObjectValue:aValue forBinding:aKey];
	_changed = oldChanged;
      }
    }
  }

  [mArray release];
  [attr release];
  [query release];  

  return;
}

-(void) loadFromDatabase
{
  int i, j;
  CLArray *anArray;


  [self loadFields];
  anArray = [[_recordDef objectForKey:@"relationships"] allKeys];
  for (i = 0, j = [anArray count]; i < j; i++)
    [self loadRelationship:[anArray objectAtIndex:i]];
  return;
}

-(id) primaryKey
{
  CLMutableDictionary *mDict;
  CLDictionary *fields;
  CLArray *anArray;
  CLAttribute *anAttr;
  CLString *aString;
  id aValue;
  int i, j;


  if (!_primaryKey || _changed) {
    [_primaryKey release];
  
    mDict = [[CLMutableDictionary alloc] init];
    fields = [_recordDef objectForKey:@"fields"];
    anArray = [fields allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aString = [anArray objectAtIndex:i];
      anAttr = [fields objectForKey:aString];
      if ([anAttr isPrimaryKey]) {
	if (![_loaded containsObject:aString] ||
	    !(aValue = [self objectValueForBinding:aString]) ||
	    ([aValue isKindOfClass:[CLNumber class]] && ![aValue intValue] &&
	     ![self allowZeroPrimaryKey])) {
	  [mDict release];
	  mDict = nil;
	  break;
	}
	[mDict setObject:aValue forKey:aString];
      }
    }

    _primaryKey = mDict;
  }
  
  if (!_dbPrimaryKey)
    _dbPrimaryKey = [_primaryKey retain];
  
  return _primaryKey;
}

-(int) objectID
{
  return [[self objectValueForBinding:@"id"] intValue];
}

-(CLString *) table
{
  return _table;
}

-(void) setObjectID:(int) oid
{
  [self setObjectValue:[CLNumber numberWithInt:oid] forBinding:@"id"];
  return;
}

-(BOOL) hasFieldNamed:(CLString *) aString
{
  if ([[_recordDef objectForKey:@"fields"] objectForKey:aString])
    return YES;

  if ([[_recordDef objectForKey:@"relationships"] objectForKey:aString])
    return YES;

  return NO;
}

-(CLAttribute *) attributeForField:(CLString *) aString
{
  return [[_recordDef objectForKey:@"fields"] objectForKey:aString];
}

-(CLAttribute *) attributeForColumn:(CLString *) aString
{
  CLArray *anArray;
  CLAttribute *anAttr;
  int i, j;


  anArray = [[_recordDef objectForKey:@"fields"] allValues];
  for (i = 0, j = [anArray count]; i < j; i++) {
    anAttr = [anArray objectAtIndex:i];
    if ([[anAttr name] isEqualToString:aString])
      return anAttr;
  }

  return nil;
}

-(CLString *) relationshipForAttribute:(CLAttribute *) anAttr
{
  CLDictionary *aDict;
  CLArray *anArray;
  CLRelationship *aRelationship;
  CLString *aKey;
  int i, j;


  aDict = [_recordDef objectForKey:@"relationships"];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aRelationship = [aDict objectForKey:aKey];
    if ([[aRelationship ourKeys] containsObject:[anAttr name]])
      return aKey;
  }

  return nil;
}

-(BOOL) isKeyField:(CLString *) aField
{
  CLAttribute *anAttr;


  anAttr = [self attributeForField:aField];
  if ([self relationshipForAttribute:anAttr])
    return YES;

  return NO;
}

-(void) loadField:(CLString *) aField
{
  BOOL oldChanged;

  
  if ([_loaded containsObject:aField])
    return;

  if ([[_recordDef objectForKey:@"relationships"] objectForKey:aField])
    [self loadRelationship:aField];
  else {
    [self loadFields];

    if (![_loaded containsObject:aField] && [self isKeyField:aField]) {
      CLString *aKey;
      CLAttribute *anAttr;
      CLRelationship *aRel;
      id anObject;
      int i, j;
      CLArray *anArray;


      anAttr = [self attributeForField:aField];
      if ((aKey = [self relationshipForAttribute:anAttr]) &&
	  [_loaded containsObject:aKey]) {
	aRel = [[_recordDef objectForKey:@"relationships"] objectForKey:aKey];
	anArray = [aRel ourKeys];
	for (i = 0, j = [anArray count]; i < j; i++)
	  if ([[anArray objectAtIndex:i] isEqualToString:aField])
	    break;
	if ((anObject = [self objectValueForBinding:
				[CLString stringWithFormat:@"%@.%@", aKey,
					  [[aRel theirKeys] objectAtIndex:i]]])) {
	  oldChanged = _changed;
	  _changed = DONTCHANGE;
	  [self setObjectValue:anObject forBinding:aField];
	  _changed = oldChanged;
	}
      }
    }
  }

  return;
}

-(void) unloadField:(CLString *) aField containingObject:(id) anObject
{
  BOOL oldChanged;
  

  if (![_loaded containsObject:aField])
    return;

  if ([self objectValueForBinding:aField] == anObject) {
    oldChanged = _changed;
    _changed = DONTCHANGE;
    [self setObjectValue:nil forBinding:aField];
    _changed = oldChanged;
    [_loaded removeObject:aField];
  }

  return;
}

-(void) unloadRelationship:(CLString *) aKey
{
  CLString *aString;
  CLDictionary *keyDict;
  CLArray *anArray;
  CLRelationship *aRelationship;
  id aValue = nil;
  int i, j;


  if (![_loaded containsObject:aKey])
    return;

  aRelationship = [[_recordDef objectForKey:@"relationships"] objectForKey:aKey];
  [self theirRelationship:aRelationship named:&aString];

  if (![aRelationship toMany]) {
    if ((keyDict = [aRelationship constructKey:self])) {
      aValue = [[self class] findInstance:[aRelationship theirTable] primaryKey:keyDict];
      [aValue unloadField:aString containingObject:self];
      [self unloadField:aString containingObject:aValue];
    }
  }
  else {
    anArray = [self objectValueForBinding:aKey];
    for (i = 0, j = [anArray count]; i < j; i++)
      [[anArray objectAtIndex:i] unloadField:aString containingObject:self];
    [self unloadField:aKey containingObject:anArray];
  }

  return;
}

-(CLString *) findFileForKey:(CLString *) aKey directory:(CLString *) aDir
{
  CLString *aFilename;
  CLRange aRange;
  CLString *localTable;

  
  aFilename = [CLPage findFile:
			[CLString stringWithFormat:@"%@_%@", [self className], aKey]
		      directory:aDir];
  if (!aFilename) {
    aFilename = [CLPage findFile:
			  [CLString stringWithFormat:@"%@_%@",
				    [_recordDef objectForKey:@"class"], aKey]
		      directory:aDir];
    if (!aFilename) {
      aRange = [_table rangeOfString:@"."];
      localTable = [_table substringFromIndex:CLMaxRange(aRange)];
      aFilename = [CLPage findFile:
			    [CLString stringWithFormat:@"%@_%@",
				      [localTable upperCamelCaseString], aKey]
			  directory:aDir];
    }
  }
  
  return aFilename;
}
  
-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  id anObject = nil;
  CLString *aString;
  CLRange aRange;
  CLPage *aPage;


  *found = NO;

  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else
    aString = [aBinding substringToIndex:aRange.location];

  if ([self hasFieldNamed:aString]) {
    [self loadField:aString];
    if (!(anObject = [_record dataForKey:aString hash:[aString hash]])) {
      anObject = [self objectForMethod:aString found:found];
      if (!*found)
	anObject = [self objectForIvar:aString found:found];
    }
    *found = YES;
    if (aRange.length)
      anObject = [anObject objectValueForBinding:
			     [aBinding substringFromIndex:CLMaxRange(aRange)] found:found];
  }

  if (!*found) {
    anObject = [super objectValueForBinding:aBinding found:found];
    if (!*found) {
      aRange = [aBinding rangeOfString:@"." options:0
			 range:CLMakeRange(0, [aBinding length])];
      if (!aRange.length &&
	  (aString = [self findFileForKey:aBinding])) {
	aPage = [[CLPage alloc] initFromFile:aString owner:self];
	*found = YES;
	anObject = [[CLBlock alloc] init];
	[anObject setValue:[aPage body]];
	[aPage release];
	[anObject autorelease];
      }
    }
  }

  return anObject;
}

-(void) retainField:(CLString *) aField object:(id) anObject oldObject:(id) oldObject
{
  [anObject retain];
  if ([_autoretain containsObject:aField]) {
    [oldObject release];
    [_autoretain removeObject:aField];
  }
  if ([self shouldRetain:aField]) {
    if (!_autoretain)
      _autoretain = [[CLMutableArray alloc] init];
    [_autoretain addObject:aField];
  }
  else
    [anObject release];
  return;
}
  
-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField
{
  void *var;
  int aType;


  if ([anObject isKindOfClass:[CLNull class]])
    anObject = nil;

  if (![self hasFieldNamed:aField]) {
    [super setObjectValue:anObject forVariable:aField];
    return;
  }

  if ((var = [self pointerForIvar:aField type:&aType])) {
    switch (aType) {
    case _C_ID:
      {
	id oldObject = *(id *) var;
	if ((!oldObject && anObject) ||
	    (oldObject && ![oldObject isEqual:anObject])) {
	  [self willChange];
	  *(id *) var = anObject;
	  [self retainField:aField object:anObject oldObject:oldObject];
	}
      }
      break;
    case _C_CHR:
    case _C_SHT:
    case _C_INT:
      {
	int c = *(int *) var;
	*(int *) var = [anObject intValue];
	if (c != *(int *) var)
	  [self willChange];
      }
      break;
    case _C_UCHR:
    case _C_USHT:
    case _C_UINT:
      {
	unsigned int c = *(unsigned int *) var;
	*(unsigned int *) var = [anObject unsignedIntValue];
	if (c != *(unsigned int *) var)
	  [self willChange];
      }
      break;
    case _C_LNG:
      {
	long c = *(long *) var;
	*(long *) var = [anObject longValue];
	if (c != *(long *) var)
	  [self willChange];
      }
      break;
    case _C_ULNG:
      {
	unsigned long c = *(unsigned long *) var;
	*(unsigned long *) var = [anObject unsignedLongValue];
	if (c != *(unsigned long *) var)
	  [self willChange];
      }
      break;
    case _C_LNG_LNG:
      {
	long long c = *(long long *) var;
	*(long long *) var = [anObject longLongValue];
	if (c != *(long long *) var)
	  [self willChange];
      }
      break;
    case _C_ULNG_LNG:
      {
	unsigned long long c = *(unsigned long long *) var;
	*(unsigned long long *) var = [anObject unsignedLongLongValue];
	if (c != *(unsigned long long *) var)
	  [self willChange];
      }
      break;
    case _C_FLT:
    case _C_DBL:
      {
	float c = *(float *) var;
	*(float *) var = [anObject doubleValue];
	if (c != *(float *) var)
	  [self willChange];
      }
      break;
    }
  }
  else {
    id oldObject, oldKey;


    oldKey = [_record keyForKey:aField hash:[aField hash]];
    oldObject = [_record removeDataForKey:aField hash:[aField hash]];
    if ([[self attributeForField:aField] isPrimaryKey]) {
      if (oldObject && ![oldObject isEqual:anObject])
	[self error:@"Changing primary key"];
      if ([anObject isKindOfClass:[CLNumber class]] && ![anObject intValue] &&
	  ![self allowZeroPrimaryKey])
	[self error:@"Trying to set primary key to 0"];
    }
    [self retainField:aField object:anObject oldObject:oldObject];
    if (!oldKey)
      oldKey = [aField copy];
    [_record setData:anObject forKey:oldKey hash:[oldKey hash]];
    [self willChange];
  }

  [self setLoaded:aField];

  return;
}

-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding
{
  CLRange aRange;
  CLString *aString;
  CLRelationship *aRelationship;


  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length) {
    aString = [aBinding substringToIndex:aRange.location];
    if (![self objectValueForBinding:aString]) {
      aRelationship = [[_recordDef objectForKey:@"relationships"] objectForKey:aString];
      if ([aRelationship isOwner])
	[self addNewObjectToBothSidesOfRelationship:aString];
    }
  }

  [super setObjectValue:anObject forBinding:aBinding];
  return;
}

-(BOOL) setIvarFromInvocation:(CLInvocation *) anInvocation
{
  int aType, aType2;
  const char *p;
  void *var;
  CLString *fieldName;


  fieldName = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  fieldName = [[fieldName substringWithRange:CLMakeRange(3, [fieldName length]-4)]
		lowerCamelCaseString];
  
  if (!(var = [self pointerForIvar:fieldName type:&aType]))
    return NO;

  p = [[anInvocation methodSignature] getArgumentTypeAtIndex:2];
  aType2 = *p;
  if (aType == aType2) {
    switch (aType) {
    case _C_ID:
      {
	id anObject = *(id *) var;
	[anInvocation getArgument:var atIndex:2];
	if ((!anObject && *(id *) var) ||
	    (anObject && ![anObject isEqual:*(id *)var]))
	  [self willChange];
	[self retainField:fieldName object:*(id *) var oldObject:anObject];
      }
      break;
    case _C_CHR:
    case _C_SHT:
    case _C_INT:
      {
	int c = *(int *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(int *) var)
	  [self willChange];
      }
      break;
    case _C_UCHR:
    case _C_USHT:
    case _C_UINT:
      {
	unsigned int c = *(unsigned int *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(unsigned int *) var)
	  [self willChange];
      }
      break;
    case _C_LNG:
      {
	long c = *(long *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(long *) var)
	  [self willChange];
      }
      break;
    case _C_ULNG:
      {
	unsigned long c = *(unsigned long *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(unsigned long *) var)
	  [self willChange];
      }
      break;
    case _C_LNG_LNG:
      {
	long long c = *(long long *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(long long *) var)
	  [self willChange];
      }
      break;
    case _C_ULNG_LNG:
      {
	unsigned long long c = *(unsigned long long *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(unsigned long long *) var)
	  [self willChange];
      }
      break;
    case _C_FLT:
      {
	float c = *(float *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(float *) var)
	  [self willChange];
      }
      break;
    case _C_DBL:
      {
	double c = *(double *) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(double *) var)
	  [self willChange];
      }
      break;
    case _C_CHARPTR:
      {
	char *c = *(char **) var;
	[anInvocation getArgument:var atIndex:2];
	if (c != *(char **) var)
	  [self willChange];
      }
      break;
    }
  }
  else
    [self error:@"Type mismatch in %@ method %s", [[self class] className],
	  sel_getName([anInvocation selector])];

  [self setLoaded:fieldName];

  return YES;
}

-(BOOL) setFieldFromInvocation:(CLInvocation *) anInvocation
{
  CLString *fieldName;
  CLAttribute *anAttr;
  CLRelationship *aRelationship = nil;
  id anObject, oldObject, oldKey;


  anObject = [anInvocation objectValueForArgumentAtIndex:2];
  fieldName = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  fieldName = [[fieldName substringWithRange:CLMakeRange(3, [fieldName length]-4)]
		lowerCamelCaseString];
  
  if ((anAttr = [[_recordDef objectForKey:@"fields"] objectForKey:fieldName])) {
    oldKey = [_record keyForKey:fieldName hash:[fieldName hash]];
    oldObject = [_record removeDataForKey:fieldName hash:[fieldName hash]];
    if ([[self attributeForField:fieldName] isPrimaryKey]) {
      if (oldObject && ![oldObject isEqual:anObject])
	[self error:@"Changing primary key"];
      if ([anObject isKindOfClass:[CLNumber class]] && ![anObject intValue] &&
	  ![self allowZeroPrimaryKey])
	[self error:@"Trying to set primary key to 0"];
    }
    [self retainField:fieldName object:anObject oldObject:oldObject];
    if (!oldKey)
      oldKey = [fieldName copy];
    [_record setData:anObject forKey:oldKey hash:[oldKey hash]];
  }
  else if ((aRelationship = [[_recordDef objectForKey:@"relationships"]
			      objectForKey:fieldName])) {
    if ([aRelationship toMany])
      [self error:@"Can't replace relationship with %@ in %s", [[self class] className],
	    sel_getName([anInvocation selector])];
    
    oldKey = [_record keyForKey:fieldName hash:[fieldName hash]];
    oldObject = [_record removeDataForKey:fieldName hash:[fieldName hash]];
    [self retainField:fieldName object:anObject oldObject:oldObject];
    if (!oldKey)
      oldKey = [fieldName copy];
    [_record setData:anObject forKey:oldKey hash:[oldKey hash]];
    [aRelationship setDictionary:nil andRecord:self usingObject:anObject
		   fieldDefinition:[_recordDef objectForKey:@"fields"]];
  }
  
  if (anAttr || aRelationship) {
    [self willChange];
    [self setLoaded:fieldName];
    return YES;
  }

  return NO;
}

-(BOOL) addToFromInvocation:(CLInvocation *) anInvocation
{
  CLString *fieldName;
  CLMutableArray *anArray;
  id anObject;


  fieldName = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  fieldName = [[fieldName substringWithRange:CLMakeRange(5, [fieldName length]-6)]
		lowerCamelCaseString];
  if (![self hasFieldNamed:fieldName])
    return NO;

  anObject = [anInvocation objectValueForArgumentAtIndex:2];
  anArray = [self objectValueForBinding:fieldName];
  [anArray addObject:anObject];

  return YES;
}

-(BOOL) removeFromFromInvocation:(CLInvocation *) anInvocation
{
  CLString *fieldName;
  CLMutableArray *anArray;
  id anObject;


  fieldName = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  fieldName = [[fieldName substringWithRange:CLMakeRange(10, [fieldName length]-11)]
		lowerCamelCaseString];
  if (![self hasFieldNamed:fieldName])
    return NO;

  anObject = [anInvocation objectValueForArgumentAtIndex:2];
  anArray = [self objectValueForBinding:fieldName];
  [anArray removeObject:anObject];
  _changed = YES;

  return YES;
}

-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  id anObject;
  CLRange aRange;
  id sender;
  BOOL found;
  const char *p;
  CLString *aBinding;


  aBinding = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  aRange = [aBinding rangeOfString:@":" options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length && [[anInvocation methodSignature] numberOfArguments] == 3) {
    if ([aBinding hasPrefix:@"set"] && iswupper([aBinding characterAtIndex:3])) {
      if ([self setIvarFromInvocation:anInvocation]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
      else if ([self setFieldFromInvocation:anInvocation]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
    else if ([aBinding hasPrefix:@"addTo"]) {
      if ([self addToFromInvocation:anInvocation]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
    else if ([aBinding hasPrefix:@"removeFrom"]) {
      if ([self removeFromFromInvocation:anInvocation]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
    else if (*[[anInvocation methodSignature] getArgumentTypeAtIndex:2] == _C_ID) {
      aBinding = [aBinding substringToIndex:aRange.location];
      [anInvocation getArgument:&sender atIndex:2];
      if ([aBinding hasPrefix:@"new"] && iswupper([aBinding characterAtIndex:3])) {
	CLString *aString;


	aString = [[aBinding substringFromIndex:3] lowerCamelCaseString];
	anObject = [self addNewObjectToBothSidesOfRelationship:aString];
	[anObject generatePrimaryKey:nil];
	[anObject edit:sender];
	[anObject release];
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
      else if ([self replacePage:sender selector:[anInvocation selector]]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
  }
  else {
    anObject = [self objectValueForBinding:aBinding found:&found];
    if (found) {
      p = [[anInvocation methodSignature] methodReturnType];
      switch (*p) {
      case _C_ID:
	[anInvocation setReturnValue:&anObject];
	break;
      case _C_CHR:
      case _C_SHT:
      case _C_INT:
	{
	  int c = [anObject intValue];
	  [anInvocation setReturnValue:&c];
	}
	break;
      case _C_UCHR:
      case _C_USHT:
      case _C_UINT:
	{
	  unsigned int c = [anObject unsignedIntValue];
	  [anInvocation setReturnValue:&c];
	}
	break;
      case _C_LNG:
	{
	  long c = [anObject longValue];
	  [anInvocation setReturnValue:&c];
	}
	break;
      case _C_ULNG:
	{
	  unsigned long c = [anObject unsignedLongValue];
	  [anInvocation setReturnValue:&c];
	}
	break;

	/* For some reason a nil object can't set a long long or unsigned long long to 0 */
      case _C_LNG_LNG:
	{
	  long long c;


	  if (anObject)
	    c = [anObject longLongValue];
	  else
	    c = 0;
	  [anInvocation setReturnValue:&c];
	}
	break;
      case _C_ULNG_LNG:
	{
	  unsigned long long c;


	  if (anObject)
	    c = [anObject unsignedLongLongValue];
	  else
	    c = 0;
	  [anInvocation setReturnValue:&c];
	}
	break;
	
      case _C_FLT:
      case _C_DBL:
	{
	  double c = [anObject doubleValue];
	  [anInvocation setReturnValue:&c];
	}
      }
      return;
    }
  }

  [super forwardInvocation:anInvocation];
  return;
}

-(BOOL) ownsAnyRelationships
{
  CLArray *anArray;
  CLDictionary *aDict;
  int i, j;


  aDict = [_recordDef objectForKey:@"relationships"];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++)
    if ([[aDict objectForKey:[anArray objectAtIndex:i]] isOwner])
      return YES;

  return NO;
}

-(void) deleteChildren:(CLArray *) anArray forRelationship:(CLRelationship *) aRelationship
{
  int i, j;


  if (![anArray count])
    return;

#if 0
  /* FIXME - this was a fast delete but it doesn't work on all objects */
  if (![[anArray objectAtIndex:0] ownsAnyRelationships]) {
    CLMutableString *mString;
    CLDatabase *db = [self database];


    mString = [[CLMutableString alloc] init];
    [mString appendString:@"id in ("];
    for (i = 0, j = [anArray count]; i < j; i++) {
      if (i)
	[mString appendString:@", "];
      [mString appendString:[CLString stringWithFormat:@"%i",
				      [[anArray objectAtIndex:i] objectID]]];
    }
    [mString appendString:@")"];
    [db deleteRowsFromTable:[aRelationship theirTable] qualifier:mString];
    [mString release];
  }
  else
#endif
    for (i = 0, j = [anArray count]; i < j; i++)
      [[anArray objectAtIndex:i] deleteFromDatabase];

  return;
}

/* This generates a new key for a row in the database. The field names
   are all database column names, and not object field names */
-(int) generatePrimaryKey:(CLMutableDictionary *) mDict
{
  CLArray *fields = [[_recordDef objectForKey:@"fields"] allValues];
  int i, j, k, oid = 0, tid = 0;
  CLAttribute *anAttr;
  CLDatabase *db = [self database];
  id aValue;


  for (i = k = 0, j = [fields count]; i < j; i++) {
    anAttr = [fields objectAtIndex:i];
    if ([anAttr isPrimaryKey]) {
      aValue = [mDict objectForKey:[anAttr name]];
      if (!aValue || [aValue isKindOfClass:[CLNull class]] ||
	  ([aValue isKindOfClass:[CLNumber class]] && !(tid = [aValue intValue])))
	k++;
      else
	oid = tid;
    }
  }

  if (k > 1)
    [self error:@"Don't know how to generate more than 1 primary key"];

  if (k) {
    CLRange aRange;
    CLString *localTable;

    
    aRange = [_table rangeOfString:@"."];
    localTable = [_table substringFromIndex:CLMaxRange(aRange)];
    oid = [db nextIDForTable:localTable];
    for (i = 0, j = [fields count]; i < j; i++) {
      anAttr = [fields objectAtIndex:i];
      aValue = [mDict objectForKey:[anAttr name]];
      if ([anAttr isPrimaryKey] &&
	  ([aValue isKindOfClass:[CLNull class]] || ![aValue intValue])) {
	[self setObjectValue:[CLNumber numberWithInt:oid] forBinding:[anAttr name]];
	[mDict setObject:[CLNumber numberWithInt:oid] forKey:[anAttr name]];
      }
    }
  }

  return oid;
}

-(BOOL) exists
{
  CLString *aString;
  CLDictionary *results;
  CLArray *anArray;
  CLDatabase *db = [self database];
  CLRange aRange;
  CLString *localTable;


  aRange = [_table rangeOfString:@"."];
  localTable = [_table substringFromIndex:CLMaxRange(aRange)];

  aString = [CLString stringWithFormat:@"select count(*) from %@ where %@",
		      localTable, [self generateQualifier]];
  results = [db runQuery:aString];
  anArray = [results objectForKey:@"rows"];
  if ([anArray count] && [[[anArray objectAtIndex:0] objectAtIndex:0] intValue])
    return YES;

  return NO;
}

-(BOOL) relationshipDependsOnUs:(CLRelationship *) ours record:(CLGenericRecord *) aRecord
{
  CLDictionary *aDict, *theirDef;
  CLAttribute *anAttr;
  CLRelationship *aRelationship;
  CLString *ourTable, *aKey;
  CLArray *fields, *relationships;
  int i, j, k, l;


  theirDef = [[self class] recordDefForTable:[ours theirTable]];
  aDict = [theirDef objectForKey:@"relationships"];
  relationships = [aDict allKeys];
  for (i = 0, j = [relationships count]; i < j; i++) {
    aKey = [relationships objectAtIndex:i];
    aRelationship = [aDict objectForKey:aKey];
    ourTable = [aRelationship theirTable];
    if ([ourTable isEqualToString:_table] && ![aRelationship toMany]) {
      if (![aRecord->_loaded containsObject:aKey] ||
	  ![[aRecord objectValueForBinding:aKey] isEqual:self])
	continue;

      fields = [aRelationship theirKeys];
      for (k = 0, l = [fields count]; k < l; k++) {
	aKey = [fields objectAtIndex:k];
	anAttr = [self attributeForField:aKey];
	if ([anAttr isPrimaryKey] && ![_loaded containsObject:aKey])
	  return YES;
      }
    }
  }

  return NO;
}

-(id) saveSelfToDatabase:(CLArray *) parents
{
#if 0
  CLDatabase *db = [self database];
  CLMutableDictionary *mDict;
  CLDictionary *aDict, *fields;
  CLArray *anArray;
  CLMutableArray *ignoreFields;
  CLString *aKey, *aString;
  CLAttribute *anAttr;
  CLRelationship *aRelationship;
  int i, j;
  id anObject;
  CLRange aRange;
  CLString *localTable;
  id errors;
#endif
  CLMutableArray *results = nil;


  if (![self primaryKey] || _changed) {
#if 1
    results = [self saveSelfWithContext:nil];
#else
    mDict = [[CLMutableDictionary alloc] init];
    ignoreFields = [[CLMutableArray alloc] init];

    fields = [_recordDef objectForKey:@"fields"];
    aDict = [_recordDef objectForKey:@"relationships"];
    anArray = [aDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aKey = [anArray objectAtIndex:i];
      aRelationship = [aDict objectForKey:aKey];
      if (![aRelationship toMany]) {
	/* FIXME - don't load a relationship from the database just to save it back */
	if ((anObject = [self objectValueForBinding:aKey])) {
	  if (![anObject primaryKey]) {
	    if (![self relationshipDependsOnUs:aRelationship record:anObject] &&
		![parents containsObject:anObject]) {
	      CLMutableArray *np;


	      np = [[CLMutableArray alloc] init];
	      [np addObjectsFromArray:parents];
	      [np addObject:self];
	      [anObject willSaveToDatabase];
	      if ((errors = [anObject saveSelfToDatabase:np])) {
		if (!results)
		  results = [CLMutableArray array];
		[results addObject:errors];
	      }
	      [np release];
	    }
	  }
	  [aRelationship setDictionary:mDict andRecord:self
			   usingObject:anObject fieldDefinition:fields];
	}
	else
	  [aRelationship setDictionary:mDict usingRecord:self fieldDefinition:fields];
	[ignoreFields addObjectsFromArray:[aRelationship ourKeys]];
      }
    }

    anArray = [fields allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aString = [anArray objectAtIndex:i];
      anAttr = [fields objectForKey:aString];
      if (![ignoreFields containsObject:aString] &&
	  (anObject = [self objectValueForBinding:aString]))
	[mDict setObject:anObject forKey:[anAttr name]];
    }

    [ignoreFields release];

    aRange = [_table rangeOfString:@"."];
    localTable = [_table substringFromIndex:CLMaxRange(aRange)];

    if (![self primaryKey] || ![self exists]) {
      [self generatePrimaryKey:mDict];
      [db insertDictionary:mDict
	    withAttributes:[[_recordDef objectForKey:@"fields"] allValues]
		      into:localTable withID:0 errors:&errors];
      if ((anObject = [[self class] registerInstance:self]) && anObject != self) {
	CLString *errString = [CLString stringWithFormat:@"Saved second instance of %@:%@",
					_table, [[self primaryKey] description]];
#if 0
	[self error:errString];
#else
	fprintf(stderr, "%s\n", [errString UTF8String]);
#endif
      }
      if (!errors)
	[self didInsertIntoDatabase];
      else {
	if (!results)
	  results = [CLMutableArray array];
	[results addObject:errors];
      }
    }
    else {
      aString = [self generateQualifier];
      [mDict addEntriesFromDictionary:[self primaryKey]];
      [db updateTable:localTable withDictionary:mDict
	andAttributes:[[_recordDef objectForKey:@"fields"] allValues]
	       forRow:aString errors:&errors];
      if (!errors)
	[self didUpdateDatabase];
      else {
	if (!results)
	  results = [CLMutableArray array];
	[results addObject:errors];
      }
    }

    [mDict release];
#endif
    
    if (!results)
      _changed = NO;
    [CLDefaultContext removeObject:self];
    [_dbPrimaryKey release];
    _dbPrimaryKey = nil;
  }

  return results;
}

-(id) saveRelationshipsToDatabase:(CLMutableArray *) ignore
{
  CLDictionary *aDict;
  CLArray *anArray;
  CLString *aKey, *aString;
  CLRelationship *aRelationship;
  int i, j;
  id anObject, errors;
  CLMutableArray *results = nil;


  aDict = [_recordDef objectForKey:@"relationships"];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    if (![_loaded containsObject:aKey])
      continue;
    
    aRelationship = [aDict objectForKey:aKey];
    if (![aRelationship toMany]) {
      if ((anObject = [self objectValueForBinding:aKey])) {
	/* FIXME - check if we own the relationship and clean out the old one! */
	if ([anObject hasChanges:[[ignore copy] autorelease]]) {
	  if ((errors = [anObject saveToDatabase:ignore])) {
	    if (!results)
	      results = [CLMutableArray array];
	    [results addObject:errors];
	  }
	}
	[ignore addObject:anObject];
      }
    }
    else {
      CLArray *anArray2;
      CLMutableArray *anArray3;
      int k, l;


      anArray2 = [self objectValueForBinding:aKey];
      for (k = 0, l = [anArray2 count]; k < l; k++) {
	anObject = [anArray2 objectAtIndex:k];
	if ([anObject hasChanges:[[ignore copy] autorelease]]) {
	  if ((errors = [anObject saveToDatabase:ignore])) {
	    if (!results)
	      results = [CLMutableArray array];
	    [results addObject:errors];
	  }
	}
	[ignore addObject:anObject];
      }

      if ([aRelationship isOwner]) {
	aString = [aRelationship constructQualifier:self];
	anArray3 = [[[self class] loadTable:[aRelationship theirTable] qualifier:aString]
		     mutableCopy];
	[anArray3 removeObjectsInArray:anArray2];
	[self deleteChildren:anArray3 forRelationship:aRelationship];
	[anArray3 release];
      }
    }
  }

  return results;
}

-(id) saveToDatabase:(CLMutableArray *) ignore
{
  CLAutoreleasePool *pool;
  CLMutableArray *mArray = nil;
  id errors;
  CLMutableArray *results = nil;
  

  pool = [[CLAutoreleasePool alloc] init];

  if (!ignore)
    ignore = mArray = [[CLMutableArray alloc] init];
  
  if ([self hasChanges:[[ignore copy] autorelease]]) {
    [self willSaveToDatabase];
    [ignore addObject:self];
    if ((errors = [self saveSelfToDatabase:nil])) {
      if (!results)
	results = [[CLMutableArray alloc] init];
      [results addObject:errors];
    }
    if ((errors = [self saveRelationshipsToDatabase:ignore])) {
      if (!results)
	results = [[CLMutableArray alloc] init];
      [results addObject:errors];
    }
  }

  [mArray release];
  [pool release];

  return [results autorelease];
}

-(id) saveToDatabase
{
  return [self saveToDatabase:nil];
}

-(id) saveSelfWithContext:(CLEditingContext *) aContext
{
  CLDatabase *db = [self database];
  CLMutableDictionary *mDict;
  CLDictionary *fields, *relationships;
  CLArray *anArray;
  CLString *aString;
  CLAttribute *anAttr;
  int i, j;
  id anObject;
  CLRange aRange;
  CLString *localTable;
  id errors = nil;
  CLRelationship *aRelationship;
  CLMutableArray *saveFields;


  mDict = [[CLMutableDictionary alloc] init];
  saveFields = [[CLMutableArray alloc] init];

  fields = [_recordDef objectForKey:@"fields"];
  relationships = [_recordDef objectForKey:@"relationships"];

  anArray = [relationships allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    if ([_loaded containsObject:aString]) {
      anObject = [self objectValueForBinding:aString];
      aRelationship = [relationships objectForKey:aString];
      if (![aRelationship isDependent])
	continue;

      if (![anObject primaryKey])
	[anObject generatePrimaryKey:nil];
      [aRelationship setDictionary:mDict andRecord:self
		       usingObject:anObject fieldDefinition:fields];
    }
  }
  
  anArray = [fields allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aString];
    
    if ([_loaded containsObject:aString] &&
	(anObject = [self objectValueForBinding:aString]))
      [mDict setObject:anObject forKey:[anAttr name]];

    if ([_loaded containsObject:aString] || [mDict objectForKey:[anAttr name]] ||
	[anAttr isPrimaryKey])
      [saveFields addObject:anAttr];
  }

  aRange = [_table rangeOfString:@"."];
  localTable = [_table substringFromIndex:CLMaxRange(aRange)];

  if (![self primaryKey] || ![self exists]) {
    [self generatePrimaryKey:mDict];
    [db insertDictionary:mDict withAttributes:saveFields into:localTable withID:0
		  errors:&errors];
    if ((anObject = [[self class] registerInstance:self]) && anObject != self) {
      CLString *errString = [CLString stringWithFormat:@"Saved second instance of %@:%@",
				      _table, [[self primaryKey] description]];
#if 0
      [self error:errString];
#else
      fprintf(stderr, "%s\n", [errString UTF8String]);
#endif
    }
    if (!errors) {
      if (aContext)
	[aContext didInsert:self];
      else
	[self didInsertIntoDatabase];
    }	
  }
  else {
    aString = [self generateQualifier];
    [mDict addEntriesFromDictionary:[self primaryKey]];
    [db updateTable:localTable withDictionary:mDict andAttributes:saveFields forRow:aString
	     errors:&errors];
    if (!errors) {
      if (aContext)
	[aContext didUpdate:self];
      else
	[self didUpdateDatabase];
    }	
  }
  
  [mDict release];
  [saveFields release];
  [_dbPrimaryKey release];
  _dbPrimaryKey = nil;
  
  return errors;
}

-(BOOL) deleteFromDatabase
{
  CLDatabase *db = [self database];
  CLDictionary *aDict, *fields;
  CLArray *anArray;
  CLString *aKey;
  CLRelationship *aRelationship;
  CLMutableString *mString;
  CLAttribute *anAttr;
  id aValue;
  int i, j;
  CLRange aRange;
  CLString *localTable;
  id errors = nil;


  aDict = [_recordDef objectForKey:@"relationships"];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aRelationship = [aDict objectForKey:aKey];
    if ([aRelationship isOwner]) {
      aValue = [self objectValueForBinding:aKey];
      if ([aRelationship toMany])
	[self deleteChildren:aValue forRelationship:aRelationship];
      else
	[aValue deleteFromDatabase];
    }
  }

  [self primaryKey];
  aDict = _dbPrimaryKey;
  anArray = [aDict allKeys];
  if (![anArray count])
    return NO;
  
  mString = [[CLMutableString alloc] init];
  fields = [_recordDef objectForKey:@"fields"];

  for (i = 0, j = [anArray count]; i < j; i++) {
    if (i)
      [mString appendString:@" and "];
    aKey = [anArray objectAtIndex:i];
    aValue = [aDict objectForKey:aKey];
    anAttr = [fields objectForKey:aKey];
    if ([aValue isKindOfClass:[CLString class]])
      [mString appendFormat:@"%@ = '%@'", [anAttr name],
	       [CLDatabase defangString:aValue escape:NULL]];
    else if ([aValue isKindOfClass:[CLCalendarDate class]])
      [mString appendFormat:@"%@ = '%@'", [anAttr name], [aValue description]];
    else
      [mString appendFormat:@"%@ = %@", [anAttr name], aValue];
  }

  aRange = [_table rangeOfString:@"."];
  localTable = [_table substringFromIndex:CLMaxRange(aRange)];

  [db deleteRowsFromTable:localTable qualifier:mString errors:&errors];
  [mString release];
  return !!errors;
}

-(void) willChange
{
  if (!_changed) {
    _changed = YES;
    [CLDefaultContext addObject:self];
  }
  return;
}

-(void) willSaveToDatabase
{
  if ([self hasFieldNamed:@"modified"] && _changed)
    [self setModified:[CLCalendarDate calendarDate]];
  if ([self hasFieldNamed:@"created"] && ![self created])
    [self setCreated:[CLCalendarDate calendarDate]];

  return;
}

-(void) didInsertIntoDatabase
{
  _changed = NO;
  return;
}

-(void) didUpdateDatabase
{
  _changed = NO;
  return;
}

-(void) addObject:(id) anObject toRelationship:(CLString *) aString
{
  CLRelationship *aRelationship;
  CLMutableArray *mArray;


  aRelationship = [[_recordDef objectForKey:@"relationships"] objectForKey:aString];
  if ([aRelationship toMany]) {
    mArray = [self objectValueForBinding:aString];
    if (![mArray containsObjectIdenticalTo:anObject]) {
      [self willChange];
      [mArray addObject:anObject];
    }
  }
  else
    [self setObjectValue:anObject forBinding:aString];

  return;
}

-(void) addObject:(id) anObject toBothSidesOfRelationship:(CLString *) aString
{
  CLRelationship *rel1, *rel2;
  CLString *relName;
  id otherObject;


  rel1 = [[_recordDef objectForKey:@"relationships"] objectForKey:aString];
  rel2 = [self theirRelationship:rel1 named:&relName];

  if (rel2 && ![rel1 toMany] && [_loaded containsObject:aString])
    [[self objectValueForBinding:aString] removeObject:self fromRelationship:relName];
  [self addObject:anObject toRelationship:aString];

  if (rel2 && [anObject respondsTo:@selector(addObject:toRelationship:)]) {
    if (![rel2 toMany] && self != [anObject objectValueForBinding:relName]) {
      otherObject = [anObject objectValueForBinding:relName];
      if ([otherObject respondsTo:@selector(removeObject:fromRelationship:)])
	[otherObject removeObject:anObject fromRelationship:aString];
    }
    [anObject addObject:self toRelationship:relName];
  }

  return;
}

-(id) addNewObjectToBothSidesOfRelationship:(CLString *) aString
{
  id anObject;
  CLRelationship *aRelationship;


  aRelationship = [[_recordDef objectForKey:@"relationships"] objectForKey:aString];
  anObject = [[[[self class] classForTable:[aRelationship theirTable]]
		alloc] initFromDictionary:nil table:[aRelationship theirTable]];
  [self addObject:anObject toBothSidesOfRelationship:aString];
  return anObject;
}

-(void) removeObject:(id) anObject fromRelationship:(CLString *) aString
{
  CLRelationship *aRelationship;
  CLArray *anArray;


  [self willChange];
  aRelationship = [[_recordDef objectForKey:@"relationships"] objectForKey:aString];
  if ([aRelationship toMany])
    [[self objectValueForBinding:aString] removeObject:anObject];
  else {
    [self setObjectValue:nil forBinding:aString];
    anArray = [aRelationship ourKeys];
    if ([aRelationship isDependent])
      [self setObjectValue:nil forBinding:[anArray lastObject]];
  }

  return;
}

-(void) removeObject:(id) anObject fromBothSidesOfRelationship:(CLString *) aString
{
  CLRelationship *rel1, *rel2;
  CLString *relName;


  [anObject retain];
  rel1 = [[_recordDef objectForKey:@"relationships"] objectForKey:aString];
  rel2 = [self theirRelationship:rel1 named:&relName];

  [self removeObject:anObject fromRelationship:aString];

  if (rel2)
    [anObject removeObject:self fromRelationship:relName];
  [anObject release];

  return;
}

#if 0
-(BOOL) isEqual:(id) anObject
{
  id myPK, theirPK;


  if (self == anObject)
    return YES;

  if (![anObject isKindOfClass:[self class]])
    return NO;

  if (![_table isEqualToString:[anObject table]])
    return NO;

  myPK = [self primaryKey];
  theirPK = [anObject primaryKey];

  if (myPK && theirPK && [myPK isEqual:theirPK])
    return YES;

  /* FIXME - PK may not be generated yet, compare the fields */

  return NO;
}
#endif

-(CLUInteger) hash
{
  return [[self primaryKey] hash];
}

-(id) plistFor:(id) anObject alreadyAdded:(CLMutableArray *) added
{
  if ([added containsObjectIdenticalTo:anObject])
    return [CLPlaceholder placeholderFromString:[[anObject class] className]
			  tag:[added indexOfObjectIdenticalTo:anObject] + 1];

  if ([anObject isKindOfClass:[CLArray class]]) {
    CLMutableArray *mArray;
    CLArray *anArray;
    int i, j;


    mArray = [[CLMutableArray alloc] init];
    anArray = anObject;
    for (i = 0, j = [anArray count]; i < j; i++)
      if ((anObject = [self plistFor:[anArray objectAtIndex:i] alreadyAdded:added]))
	[mArray addObject:anObject];
#if 0 /* Need to indicate that it's an empty array */
    if (![mArray count]) {
      [mArray release];
      mArray = nil;
    }
#endif
    anObject = [mArray autorelease];
  }

  if ([anObject isKindOfClass:[CLGenericRecord class]]) {
    CLGenericRecord *record;
    CLMutableDictionary *mDict;
    CLArray *anArray;
    CLString *aKey;
    CLRelationship *aRelationship;
    int i, j;


    record = anObject;
    [added addObject:record];
    mDict = [[CLMutableDictionary alloc] init];

    if (record->_changed || ![self exists]) {
      anArray = [record->_loaded sortedArrayUsingSelector:@selector(compare:)];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aKey = [anArray objectAtIndex:i];
	anObject = [record objectValueForBinding:aKey];
	aRelationship = [[record->_recordDef objectForKey:@"relationships"]
			  objectForKey:aKey];
	if (!aRelationship)
	  [mDict setObject:anObject forKey:aKey];
	else if ((anObject = [self plistFor:anObject alreadyAdded:added]))
	  [mDict setObject:anObject forKey:aKey];
      }
    }

    [mDict addEntriesFromDictionary:[record primaryKey]];

    anObject = [mDict autorelease];
  }

  return anObject;
}

-(CLDictionary *) dictionary
{
  id anObject;
  CLMutableArray *added;


  added = [[CLMutableArray alloc] init];
  anObject = [self plistFor:self alreadyAdded:added];
  [added release];
  return anObject;
}

-(CLString *) propertyList
{
  return [[self dictionary] propertyList];
}

-(CLString *) description
{
  return [self propertyList];
}

-(id) createObject:(id) anObject relationship:(CLRelationship *) aRelationship
	      seen:(CLMutableDictionary *) seen updateChanged:(BOOL) flag
{
  id newObject = nil;


  if ([anObject isKindOfClass:[CLPlaceholder class]]) {
    if (!(newObject = [seen objectForKey:anObject]))
      [self error:@"Did not find object!\n"];
  }
  else {
    newObject = [[[[self class] classForTable:[aRelationship theirTable]]
		   alloc] initFromDictionary:anObject table:[aRelationship theirTable]];
    [seen setObject:newObject forKey:
	    [CLPlaceholder placeholderFromString:[[newObject class] className]
			   tag:[seen count] + 1]];
    [newObject setFieldsFromDictionary:anObject seen:seen updateChanged:flag];
    if ((anObject = [[self class] registerInstance:newObject]) &&
	anObject != newObject) {
      [anObject retain];
      [newObject release];
      newObject = anObject;
    }
  }

  return newObject;
}

-(void) setFieldsFromDictionary:(CLDictionary *) aDict seen:(CLMutableDictionary *) seen
		  updateChanged:(BOOL) flag
{
  CLArray *anArray, *fields, *relFields;
  int i, j, k, l;
  id anObject, aRecord;
  CLString *aKey;
  CLRelationship *aRelationship;
  CLDictionary *relationships;
  CLMutableArray *mArray;
  BOOL oldChanged = _changed;


  if (!flag)
    _changed = DONTCHANGE;

  anArray = [[aDict allKeys] sortedArrayUsingSelector:@selector(compare:)];
  fields = [[_recordDef objectForKey:@"fields"] allKeys];
  relationships = [_recordDef objectForKey:@"relationships"];
  relFields = [relationships allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    anObject = [aDict objectForKey:aKey];
    if ([fields containsObject:aKey] && anObject)
      [self setObjectValue:anObject forBinding:aKey];
    else if ([relFields containsObject:aKey] && anObject) {
      aRelationship = [relationships objectForKey:aKey];
      if ([aRelationship toMany]) {
	if ([_loaded containsObject:aKey])
	  [self unloadRelationship:aKey];

	mArray = [[CLMutableArray alloc] init];
	[self setObjectValue:mArray forBinding:aKey];
	[self setLoaded:aKey];
	[mArray release];
      
	for (k = 0, l = [anObject count]; k < l; k++) {
	  aRecord = [anObject objectAtIndex:k];
	  aRecord = [self createObject:aRecord relationship:aRelationship
				  seen:seen updateChanged:flag];
	  if (![mArray containsObject:aRecord])
	    [self addObject:aRecord toBothSidesOfRelationship:aKey];
	}
      }
      else if (anObject) {
	/* FIXME - should we nullify if the key was empty? Probably need
	   to check if the related key is set.  */
	anObject = [self createObject:anObject relationship:aRelationship
				 seen:seen updateChanged:flag];
	[self addObject:anObject toBothSidesOfRelationship:aKey];
      }
    }
  }

  if (!flag)
    _changed = oldChanged;
  
  return;
}

-(void) setFieldsFromDictionary:(CLDictionary *) aDict updateChanged:(BOOL) flag
{
  CLMutableDictionary *mDict;


  mDict = [[CLMutableDictionary alloc] init];
  [mDict setObject:self forKey:
	   [CLPlaceholder placeholderFromString:[[self class] className]
			  tag:1]];
  [self setFieldsFromDictionary:aDict seen:mDict updateChanged:flag];
  [mDict release];
  return;
}

-(BOOL) hasChanges:(CLMutableArray *) ignoreList
{
  int i, j;
  CLDictionary *aDict;
  CLArray *anArray;
  CLString *aKey;
  CLRelationship *aRelationship;
  CLMutableArray *mArray = nil;
  BOOL hasChanges = NO;
  id anObject;


  if ([ignoreList containsObjectIdenticalTo:self])
    return NO;
  
  if (_changed)
    return YES;

  if (!ignoreList)
    ignoreList = mArray = [[CLMutableArray alloc] init];
  [ignoreList addObject:self];
  
  aDict = [_recordDef objectForKey:@"relationships"];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    if (![_loaded containsObject:aKey])
      continue;
    
    aRelationship = [aDict objectForKey:aKey];
    if (![aRelationship toMany]) {
      anObject = [self objectValueForBinding:aKey];
      if (![ignoreList containsObjectIdenticalTo:anObject] &&
	  [anObject hasChanges:ignoreList]) {
	hasChanges = YES;
	break;
      }
    }
    else {
      CLArray *anArray2;
      int k, l;


      anArray2 = [self objectValueForBinding:aKey];
      for (k = 0, l = [anArray2 count]; k < l; k++) {
	anObject = [anArray2 objectAtIndex:k];
	if (![ignoreList containsObjectIdenticalTo:anObject] &&
	    [anObject hasChanges:ignoreList]) {
	  hasChanges = YES;
	  break;
	}
	if (hasChanges)
	  break;
	
	[ignoreList addObject:anObject];
      }
    }
  }

  [mArray release];
  return hasChanges;
}

-(BOOL) allowZeroPrimaryKey
{
  return NO;
}

-(CLDictionary *) recordDef
{
  return _recordDef;
}

@end

@implementation CLGenericRecord (CLFlags)

-(BOOL) hasFlag:(unichar) aFlag
{
  CLRange aRange;
  unichar buf[2];
  CLString *aString;


  if (![[self flags] length])
    return NO;
  
  buf[0] = aFlag;
  aString = [[CLString alloc] initWithCharacters:buf length:1];
  aRange = [[self flags] rangeOfString:aString options:CLCaseInsensitiveSearch];
  [aString release];
  if (aRange.length)
    return YES;

  return NO;
}

-(void) addFlag:(unichar) aFlag
{
  CLString *aString;
  unichar buf[2];


  if (![self hasFlag:aFlag]) {
    buf[0] = aFlag;
    aString = [CLString stringWithCharacters:buf length:1];
    [self setFlags:[aString stringByAppendingString:[self flags]]];
  }
  
  return;
}

-(void) removeFlag:(unichar) aFlag
{
  CLRange aRange;
  CLString *aString;
  unichar buf[2];
  
  
  buf[0] = aFlag;
  aString = [CLString stringWithCharacters:buf length:1];
  aRange = [[self flags] rangeOfString:aString options:CLCaseInsensitiveSearch];
  if (aRange.length)
    [self setFlags:[[self flags] stringByReplacingCharactersInRange:aRange withString:@""]];

  return;
}

@end
