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

#import "CLGenericRecord.h"
#import "CLEditingContext.h"
#import "CLRecordDefinition.h"
#import "CLRelationship.h"
#import "CLAttribute.h"
#import "CLDatabase.h"
#import "CLMutableDictionary.h"
#import "CLArray.h"
#import "CLNull.h"
#import "CLAutoreleasePool.h"
#import "CLStream.h"
#import "CLNumber.h"
#import "CLPage.h"
#import "CLBlock.h"
#import "CLInvocation.h"
#import "CLMethodSignature.h"
#import "CLPlaceholder.h"
#import "CLFault.h"
#import "CLDatetime.h"
#import "CLStackString.h"
#import "CLClassConstants.h"

#include <stdlib.h>
#include <wctype.h>
#include <string.h>
#include <ctype.h>

#define MAX_HASH	10
#define DONTCHANGE	-2

@interface CLGenericRecord (CLMagicNew)
-(void) edit:(id) sender;
@end

@implementation CLGenericRecord

-(id) init
{
  return [self initFromDictionary:nil table:[CLEditingContext tableForClass:[self class]]];
}

-(id) initFromDictionary:(CLDictionary *) aDict table:(CLString *) aTable
{
  id aValue;
  int i, j;
  CLDictionary *fields;
  CLAttribute *anAttr;
  CLArray *anArray;
  CLString *aString;


  [super init];

  _changed = DONTCHANGE;
  _record = CLHashTableAlloc(MAX_HASH);
  if (aTable) 
    _recordDef = [[CLEditingContext recordDefinitionForTable:aTable] retain];
  else
    _recordDef = [[CLEditingContext recordDefinitionForClass:[self class]] retain];
  _table = [[_recordDef table] retain];
  _autoretain = nil;
  _db = nil;
  _dbPrimaryKey = nil;

  fields = [_recordDef fields];
  anArray = [fields allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aString];
    if ((aValue = [aDict objectForKey:[anAttr column]]) && aValue != CLNullObject)
      [self setObjectValue:aValue forBinding:aString];
  }

  _changed = NO;
  
  return self;
}

-(id) initFromDictionary:(CLDictionary *) aDict
{
  [self error:@"%@ is no longer available", CLSelGetName(_cmd)];
  return nil;
}

-(void) new:(id) sender
{
  [CLEditingContext generatePrimaryKey:nil forRecord:self];
  [self edit:sender];
  return;
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


  anArray = [[_recordDef fields] allKeys];
  for (i = 0, j = [anArray count]; i < j; i++)
    if ([aString isEqualToString:[anArray objectAtIndex:i]]) {
      sr = YES;
      break;
    }

  if (!sr) {
    aDict = [_recordDef relationships];
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
  int i, j;
  CLString *aKey;
  void *var;
  int aType;
  id *data;
#if 0
  CLAutoreleasePool *pool;


  pool = [[CLAutoreleasePool alloc] init];
#endif
  j = _record->count;
  if (!(data = alloca(sizeof(id) * j)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(_record, data);
  for (i = 0; i < j; i++) {
    aKey = data[i];
    if ([_autoretain containsObject:aKey])
      [((id) CLHashTableDataForKey(_record, aKey, [aKey hash], @selector(isEqual:))) release];
  }
  for (i = 0; i < j; i++)
    [data[i] release];
  CLHashTableFree(_record);

  for (i = 0, j = [_autoretain count]; i < j; i++) {
    aKey = [_autoretain objectAtIndex:i];
    if ((var = [self pointerForIvar:[aKey UTF8String] type:&aType])) {
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
  [_primaryKey release];
  [_dbPrimaryKey release];
  [_autoretain release];

  _table = nil;
  _record = NULL;
  _recordDef = nil;
  _primaryKey = nil;
  _dbPrimaryKey = nil;
  _autoretain = nil;

#if 0
  [pool release];
#endif
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  CLDictionary *pk;
  id anObject;


  [super read:stream];
  [stream readTypes:@"@@", &pk, &_table];
  _record = CLHashTableAlloc(MAX_HASH);
  if (_table)
    _recordDef = [[CLEditingContext recordDefinitionForTable:_table] retain];
  else {
    _recordDef = [[CLEditingContext recordDefinitionForClass:[self class]] retain];
    _table = [[_recordDef table] retain];
  }
  _autoretain = nil;
  _db = nil;
  _dbPrimaryKey = nil;

  if (pk) {
    anObject = [CLDefaultContext registerInstance:self inTable:[_recordDef table]
				   withPrimaryKey:pk];
    if (anObject != self) {
      [anObject retain];
      [self release];
      self = anObject;
    }
    else  
      CLBecomeFault(self, pk, _recordDef, NO);
  }
  
  return self;
}

-(void) write:(CLStream *) stream
{
  id pk;


  [super write:stream];
  pk = [self primaryKey];
  [stream writeTypes:@"@@", &pk, &_table];
  return;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  return [self retain:file :line :retainer];
}
#define copy		copy:__FILE__ :__LINE__ :self
#define retain		retain:__FILE__ :__LINE__ :self
#else
-(id) copy
{
  return [self retain];
}
#endif

-(CLDatabase *) database
{
  if (!_db)
    _db = [_recordDef database];

  return _db;
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


  fields = [_recordDef fields];
  anArray = [fields allKeys];
  mDict = [CLMutableDictionary dictionary];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aKey];
    if ([anAttr isPrimaryKey]) {
      if (!(anObject = [super objectValueForBinding:aKey]))
	anObject = CLNullObject;
      [mDict setObject:anObject forKey:[anAttr column]];
    }
  }

  return [CLEditingContext generateQualifier:mDict];
}

-(id) primaryKey
{
  if (!_primaryKey || _changed) {
    [_primaryKey release];
    _primaryKey = [[CLEditingContext constructPrimaryKey:self recordDef:_recordDef
					    fromDatabase:NO asDictionary:NO] retain];
  }
  
  if (!_dbPrimaryKey)
    _dbPrimaryKey = [_primaryKey retain];
  
  return _primaryKey;
}

-(CLUInteger) objectID
{
  return [[self objectValueForBinding:@"id"] unsignedIntValue];
}

-(CLString *) table
{
  return _table;
}

-(void) setObjectID:(CLUInteger) oid
{
  [self setObjectValue:[CLNumber numberWithUnsignedInt:oid] forBinding:@"id"];
  return;
}

-(BOOL) hasFieldNamed:(CLString *) aString
{
  if ([[_recordDef fields] objectForKey:aString])
    return YES;

  if ([[_recordDef relationships] objectForKey:aString])
    return YES;

  return NO;
}

-(CLAttribute *) attributeForField:(CLString *) aString
{
  return [[_recordDef fields] objectForKey:aString];
}

-(CLAttribute *) attributeForColumn:(CLString *) aString
{
  CLArray *anArray;
  CLAttribute *anAttr;
  int i, j;


  anArray = [[_recordDef fields] allValues];
  for (i = 0, j = [anArray count]; i < j; i++) {
    anAttr = [anArray objectAtIndex:i];
    if ([[anAttr column] isEqualToString:aString])
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


  aDict = [_recordDef relationships];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aRelationship = [aDict objectForKey:aKey];
    if ([[aRelationship ourKeys] containsObject:[anAttr column]])
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

-(CLHashTable *) cacheBindings
{
  CLHashTable *cache;
  CLCachedBinding *aBinding;
  CLDictionary *aDict;
  CLArray *anArray;
  int i, j;
  CLString *aKey;
  BOOL new;

  
  cache = [super cacheBindings];

  /* Insert all the field and relationship bindings. If there are any
     page bindings with the same name, replace them. Give method and
     ivar bindings priority. */

  aDict = [_recordDef fields];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    new = NO;
    if (!(aBinding = 
	  CLHashTableDataForKey(cache, aKey, [aKey hash], @selector(isEqual:)))) {
      aBinding = malloc(sizeof(CLCachedBinding));
      aBinding->getter = aBinding->setter = NULL;
      aBinding->getSel = aBinding->setSel = NULL;
      aBinding->getType = aBinding->setType = 0;
      aBinding->returnType = aBinding->argumentType = 0;
      new = YES;
    }

    if (!aBinding->getType || aBinding->getType == CLPageBinding) {
      [((CLString *) aBinding->getter) release]; // release CLPageBinding path
      aBinding->getter = [aKey retain];
      aBinding->returnType = _C_ID;
      aBinding->getType = CLFieldBinding;
    }

    if (!aBinding->setType) {
      aBinding->setter = [aKey retain];
      aBinding->argumentType = _C_ID;
      aBinding->setType = CLFieldBinding;
    }

    if (new) {
      [aKey retain];
      CLHashTableSetData(cache, aBinding, aKey, [aKey hash]);
    }
  }

  aDict = [_recordDef relationships];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    new = NO;
    if (!(aBinding = 
	  CLHashTableDataForKey(cache, aKey, [aKey hash], @selector(isEqual:)))) {
      aBinding = malloc(sizeof(CLCachedBinding));
      aBinding->getter = aBinding->setter = NULL;
      aBinding->getSel = aBinding->setSel = NULL;
      aBinding->getType = aBinding->setType = 0;
      aBinding->returnType = aBinding->argumentType = 0;
      new = YES;
    }

    if (!aBinding->getType || aBinding->getType == CLPageBinding) {
      [((CLString *) aBinding->getter) release]; // release CLPageBinding path
      aBinding->getter = [aKey retain];
      aBinding->returnType = _C_ID;
      aBinding->getType = CLRelationshipBinding;
    }

    if (!aBinding->setType) {
      aBinding->setter = [aKey retain];
      aBinding->argumentType = _C_ID;
      aBinding->setType = CLRelationshipBinding;
    }

    if (new) {
      [aKey retain];
      CLHashTableSetData(cache, aBinding, aKey, [aKey hash]);
    }
  }

  return cache;
}

-(id) objectForCachedBinding:(CLCachedBinding *) cachedBinding
{
  return CLHashTableDataForKey(_record, cachedBinding->getter,
			       [((CLString *) cachedBinding->getter) hash],
			       @selector(isEqual:));
}

-(id) retainField:(CLString *) aField object:(id) anObject oldObject:(id) oldObject
{
  if ([anObject isKindOfClass:CLMutableStackStringClass] ||
      [anObject isKindOfClass:CLImmutableStackStringClass])
    anObject = [anObject copy];
  else
    [anObject retain];
  if ([_autoretain containsObject:aField]) {
    [oldObject release];
    [_autoretain removeObject:aField];
  }
  if ([self shouldRetain:aField]) {
    id dup;

    
    if (!_autoretain)
      _autoretain = [[CLMutableArray alloc] init];
    dup = [aField copy];
    [_autoretain addObject:dup];
    [dup release];
  }
  else {
    [anObject release];
    anObject = nil;
  }
  return anObject;
}
  
-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField
{
  void *var;
  int aType;


  if (anObject == CLNullObject)
    anObject = nil;

  if (![self hasFieldNamed:aField]) {
    [super setObjectValue:anObject forVariable:aField];
    return;
  }

  if ((var = [self pointerForIvar:[aField UTF8String] type:&aType])) {
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


    oldKey = CLHashTableKeyForKey(_record, aField, [aField hash], @selector(isEqual:));
    oldObject = CLHashTableRemoveDataForKey(_record, aField, [aField hash],
					    @selector(isEqual:));
    if ([[self attributeForField:aField] isPrimaryKey]) {
      if (oldObject && ![oldObject isEqual:anObject])
	[self error:@"Changing primary key"];
      if ([anObject isKindOfClass:CLNumberClass] && ![anObject intValue] &&
	  ![self allowZeroPrimaryKey])
	[self error:@"Trying to set primary key to 0"];
    }
    [self retainField:aField object:anObject oldObject:oldObject];
    if (!oldKey)
      oldKey = [aField copy];
    CLHashTableSetData(_record, anObject, oldKey, [oldKey hash]);
    [self willChange];
  }

  return;
}

-(void) setPrimitiveValue:(id) anObject forKey:(CLString *) aKey
{
  void *var;
  int aType;


  if (anObject == CLNullObject)
    anObject = nil;

  if (![self hasFieldNamed:aKey]) {
    [super setObjectValue:anObject forVariable:aKey];
    return;
  }

  if ((var = [self pointerForIvar:[aKey UTF8String] type:&aType])) {
    switch (aType) {
    case _C_ID:
      {
	id oldObject = *(id *) var;
	if ((!oldObject && anObject) ||
	    (oldObject && ![oldObject isEqual:anObject])) {
	  *(id *) var = anObject;
	  [self retainField:aKey object:anObject oldObject:oldObject];
	}
      }
      break;
    case _C_CHR:
    case _C_SHT:
    case _C_INT:
      *(int *) var = [anObject intValue];
      break;
    case _C_UCHR:
    case _C_USHT:
    case _C_UINT:
      *(unsigned int *) var = [anObject unsignedIntValue];
      break;
    case _C_LNG:
      *(long *) var = [anObject longValue];
      break;
    case _C_ULNG:
      *(unsigned long *) var = [anObject unsignedLongValue];
      break;
    case _C_LNG_LNG:
      *(long long *) var = [anObject longLongValue];
      break;
    case _C_ULNG_LNG:
      *(unsigned long long *) var = [anObject unsignedLongLongValue];
      break;
    case _C_FLT:
    case _C_DBL:
      *(float *) var = [anObject doubleValue];
      break;
    }
  }
  else {
    id oldObject, oldKey;


    oldKey = CLHashTableKeyForKey(_record, aKey, [aKey hash], @selector(isEqual:));
    oldObject = CLHashTableRemoveDataForKey(_record, aKey, [aKey hash], @selector(isEqual:));
    if ([[self attributeForField:aKey] isPrimaryKey]) {
      if (oldObject && ![oldObject isEqual:anObject])
	[self error:@"Changing primary key"];
      if ([anObject isKindOfClass:CLNumberClass] && ![anObject intValue] &&
	  ![self allowZeroPrimaryKey])
	[self error:@"Trying to set primary key to 0"];
    }
    [self retainField:aKey object:anObject oldObject:oldObject];
    if (!oldKey)
      oldKey = [aKey copy];
    CLHashTableSetData(_record, anObject, oldKey, [oldKey hash]);
  }

  return;
}

-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding
{
  CLRange aRange;
  CLString *aString;
  CLRelationship *aRelationship;


  if (anObject) {
    aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
    if (aRange.length) {
      aString = [aBinding substringToIndex:aRange.location];
      if (![self objectValueForBinding:aString]) {
	aRelationship = [[_recordDef relationships] objectForKey:aString];
	if ([aRelationship isOwner])
	  [self addNewObjectToBothSidesOfRelationship:aString];
      }
    }
  }

  if (_changed == DONTCHANGE)
    [self setPrimitiveValue:anObject forKey:aBinding];
  else
    [super setObjectValue:anObject forBinding:aBinding];
  return;
}

-(BOOL) setIvarFromInvocation:(CLInvocation *) anInvocation
{
  int aType, aType2;
  const char *p;
  void *var;
  char *fieldName;


  p = sel_getName([anInvocation selector]);
  fieldName = strdup(p+3);
  fieldName[strlen(fieldName) - 1] = 0;
  fieldName[0] = tolower(fieldName[0]);
  var = [self pointerForIvar:fieldName type:&aType];
  
  if (!var) {
    free(fieldName);
    return NO;
  }

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
	[self retainField:[CLString stringWithUTF8String:fieldName]
		   object:*(id *) var oldObject:anObject];
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

  free(fieldName);
  return YES;
}

-(BOOL) setFieldFromInvocation:(CLInvocation *) anInvocation
{
  CLString *fieldName;
  CLAttribute *anAttr;
  CLRelationship *aRelationship = nil;
  id anObject, oldObject, oldKey;
  unistr ustr;


  anObject = [anInvocation objectValueForArgumentAtIndex:2];

  ustr = CLCloneStackString(CLSelGetName([anInvocation selector]));
  ustr.str += 3;
  ustr.len -= 4;
  ustr.str[0] = towlower(ustr.str[0]);
  fieldName = (CLString *) &ustr;
  
  if ((anAttr = [[_recordDef fields] objectForKey:fieldName])) {
    oldKey = CLHashTableKeyForKey(_record, fieldName, [fieldName hash], @selector(isEqual:));
    oldObject = CLHashTableRemoveDataForKey(_record, fieldName, [fieldName hash],
					    @selector(isEqual:));
    if ([[self attributeForField:fieldName] isPrimaryKey]) {
      if (oldObject && ![oldObject isEqual:anObject])
	[self error:@"Changing primary key"];
      if ([anObject isKindOfClass:CLNumberClass] && ![anObject intValue] &&
	  ![self allowZeroPrimaryKey])
	[self error:@"Trying to set primary key to 0"];
    }
    if (!oldKey)
      oldKey = [fieldName copy];
    anObject = [self retainField:oldKey object:anObject oldObject:oldObject];
    CLHashTableSetData(_record, anObject, oldKey, [oldKey hash]);
  }
  else if ((aRelationship = [[_recordDef relationships] objectForKey:fieldName])) {
    if ([aRelationship toMany])
      [self error:@"Can't replace relationship with %@ in %s", [[self class] className],
	    sel_getName([anInvocation selector])];
    
    oldKey = CLHashTableKeyForKey(_record, fieldName, [fieldName hash], @selector(isEqual:));
    oldObject = CLHashTableRemoveDataForKey(_record, fieldName, [fieldName hash],
					    @selector(isEqual:));
    [self retainField:fieldName object:anObject oldObject:oldObject];
    if (!oldKey)
      oldKey = [fieldName copy];
    CLHashTableSetData(_record, anObject, oldKey, [oldKey hash]);
    [aRelationship setDictionary:nil andRecord:self usingObject:anObject
		   fieldDefinition:[_recordDef fields]];
  }
  
  if (anAttr || aRelationship) {
    [self willChange];
    return YES;
  }

  return NO;
}

-(BOOL) addToFromInvocation:(CLInvocation *) anInvocation
{
  CLString *fieldName;
  id anObject;


  fieldName = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  fieldName = [[fieldName substringWithRange:CLMakeRange(5, [fieldName length]-6)]
		lowerCamelCaseString];
  if (![self hasFieldNamed:fieldName])
    return NO;

  anObject = [anInvocation objectValueForArgumentAtIndex:2];
  [self addObject:anObject toBothSidesOfRelationship:fieldName];

  return YES;
}

-(BOOL) removeFromFromInvocation:(CLInvocation *) anInvocation
{
  CLString *fieldName;
  id anObject;


  fieldName = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  fieldName = [[fieldName substringWithRange:CLMakeRange(10, [fieldName length]-11)]
		lowerCamelCaseString];
  if (![self hasFieldNamed:fieldName])
    return NO;

  anObject = [anInvocation objectValueForArgumentAtIndex:2];
  [self removeObject:anObject fromBothSidesOfRelationship:fieldName];

  return YES;
}

-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  id anObject;
  CLRange aRange;
  id sender;
  BOOL found;
  const char *aBinding, *pos;


  aBinding = sel_getName([anInvocation selector]);
  if ((pos = strchr(aBinding, ':'))) {
    aRange.location = pos - aBinding;
    aRange.length = 1;
  }
  else
    aRange.length = 0;
  
  if (aRange.length && [[anInvocation methodSignature] numberOfArguments] == 3) {
    if (!strncmp(aBinding, "set", 3) && isupper(aBinding[3])) {
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
    else if (!strncmp(aBinding, "addTo", 5)) {
      if ([self addToFromInvocation:anInvocation]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
    else if (!strncmp(aBinding, "removeFrom", 10)) {
      if ([self removeFromFromInvocation:anInvocation]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
    else if (*[[anInvocation methodSignature] getArgumentTypeAtIndex:2] == _C_ID) {
      [anInvocation getArgument:&sender atIndex:2];
      if (!strncmp(aBinding, "new", 3) && isupper(aBinding[3])) {
	CLString *aString;


	aString = [[CLString stringWithBytes:&aBinding[1] length:strlen(aBinding) - 4
				    encoding:CLUTF8StringEncoding] lowerCamelCaseString];
	anObject = [self addNewObjectToBothSidesOfRelationship:aString];
	[CLEditingContext generatePrimaryKey:nil forRecord:anObject];
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
    CLString *bString;

    
    bString = [[CLString alloc] initWithUTF8String:aBinding];
    anObject = [self objectValueForBinding:bString found:&found];
    [bString release];
    if (found) {
      pos = [[anInvocation methodSignature] methodReturnType];
      switch (*pos) {
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


  aDict = [_recordDef relationships];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++)
    if ([[aDict objectForKey:[anArray objectAtIndex:i]] isOwner])
      return YES;

  return NO;
}

-(BOOL) exists
{
  CLString *aString;
  CLDictionary *results;
  CLArray *anArray;
  CLDatabase *db = [self database];


  aString = [CLString stringWithFormat:@"select count(*) from %@ where %@",
		      [_recordDef databaseTable], [self generateQualifier]];
  results = [db runQuery:aString];
  anArray = [results objectForKey:@"rows"];
  if ([anArray count] && [[[anArray objectAtIndex:0] objectAtIndex:0] intValue])
    return YES;

  return NO;
}

-(BOOL) relationshipDependsOnUs:(CLRelationship *) ours record:(CLGenericRecord *) aRecord
{
  CLDictionary *aDict;
  CLRecordDefinition *theirDef;
  CLAttribute *anAttr;
  CLRelationship *aRelationship;
  CLString *ourTable, *aKey;
  CLArray *fields, *relationships;
  int i, j, k, l;


  theirDef = [CLEditingContext recordDefinitionForTable:[ours theirTable]];
  aDict = [theirDef relationships];
  relationships = [aDict allKeys];
  for (i = 0, j = [relationships count]; i < j; i++) {
    aKey = [relationships objectAtIndex:i];
    aRelationship = [aDict objectForKey:aKey];
    ourTable = [aRelationship theirTable];
    if ([ourTable isEqualToString:_table] && ![aRelationship toMany]) {
      if (![[aRecord objectValueForBinding:aKey] isEqual:self])
	continue;

      fields = [aRelationship theirKeys];
      for (k = 0, l = [fields count]; k < l; k++) {
	aKey = [fields objectAtIndex:k];
	anAttr = [self attributeForField:aKey];
	if ([anAttr isPrimaryKey])
	  return YES;
      }
    }
  }

  return NO;
}

-(id) plistFor:(id) anObject alreadyAdded:(CLMutableArray *) added allFields:(BOOL) allFields
{
  if ([added containsObjectIdenticalTo:anObject])
    return [CLPlaceholder placeholderFromString:[[anObject class] className]
			  tag:[added indexOfObjectIdenticalTo:anObject] + 1];

  if ([anObject isKindOfClass:CLArrayClass]) {
    CLMutableArray *mArray;
    CLArray *anArray;
    int i, j;


    mArray = [[CLMutableArray alloc] init];
    anArray = anObject;
    for (i = 0, j = [anArray count]; i < j; i++)
      if ((anObject = [self plistFor:[anArray objectAtIndex:i]
			alreadyAdded:added allFields:allFields]))
	[mArray addObject:anObject];
#if 0 /* Need to indicate that it's an empty array */
    if (![mArray count]) {
      [mArray release];
      mArray = nil;
    }
#endif
    anObject = [mArray autorelease];
  }

  if ([anObject isKindOfClass:CLGenericRecordClass]) {
    CLGenericRecord *record;
    CLDictionary *fields;
    CLMutableDictionary *mDict;
    CLArray *anArray;
    CLString *aKey;
    CLRelationship *aRelationship;
    int i, j;
    id pk;


    record = anObject;
    [added addObject:record];
    mDict = [[CLMutableDictionary alloc] init];

    if (record->_changed || ![record exists] || allFields) {
      fields = [record->_recordDef fields];
      anArray = [[record->_recordDef relationships] allKeys];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aKey = [anArray objectAtIndex:i];
	anObject = [record objectValueForBinding:aKey];
	aRelationship = [[record->_recordDef relationships] objectForKey:aKey];
	[aRelationship setDictionary:nil andRecord:record
			 usingObject:anObject fieldDefinition:fields];
      }
      
      anArray = [[[fields allKeys] arrayByAddingObjectsFromArray:
						  [[record->_recordDef relationships] allKeys]]
		  sortedArrayUsingSelector:@selector(compare:)];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aKey = [anArray objectAtIndex:i];
	anObject = [record objectValueForBinding:aKey];
	//aRelationship = [[record->_recordDef relationships] objectForKey:aKey];
	if (!anObject) {
	  anObject = CLNullObject;
	  [mDict setObject:anObject forKey:aKey];
	}
	else if ((anObject = [self plistFor:anObject alreadyAdded:added
				  allFields:allFields]) &&
		 (!allFields || ![anObject isKindOfClass:CLPlaceholderClass]))
	  [mDict setObject:anObject forKey:aKey];
      }
    }

    pk = [record primaryKey];
    if ([pk isKindOfClass:CLDictionaryClass])
      [mDict addEntriesFromDictionary:pk];
    else if (pk)
      [mDict setObject:pk forKey:[[[_recordDef primaryKeys] objectAtIndex:0] key]];

    anObject = [mDict autorelease];
  }

  return anObject;
}

-(CLDictionary *) dictionary
{
  id anObject;
  CLMutableArray *added;


  added = [[CLMutableArray alloc] init];
  anObject = [self plistFor:self alreadyAdded:added allFields:NO];
  [added release];
  return anObject;
}

-(CLString *) propertyList
{
  return [[self dictionary] propertyList];
}

-(CLString *) json
{
  id anObject;
  CLMutableArray *added;


  added = [[CLMutableArray alloc] init];
  anObject = [self plistFor:self alreadyAdded:added allFields:YES];
  [added release];
  return [anObject json];
}
  
-(CLString *) description
{
  return [self propertyList];
}

-(id) createObject:(id) anObject relationship:(CLRelationship *) aRelationship
	      seen:(CLMutableDictionary *) seen updateChanged:(BOOL) flag
{
  id newObject = nil, regObject;
  CLRecordDefinition *recordDef;
  id pk;


  if ([anObject isKindOfClass:CLPlaceholderClass]) {
    if (!(newObject = [seen objectForKey:anObject]))
      [self error:@"Did not find object!\n"];
  }
  else {
    recordDef = [CLEditingContext recordDefinitionForTable:[aRelationship theirTable]];
    if ((pk = [CLEditingContext constructPrimaryKey:anObject
					  recordDef:recordDef fromDatabase:NO
				       asDictionary:NO]))
      newObject = [[self editingContext]
		    loadObjectWithClass:[recordDef recordClass] primaryKey:pk];
    else {
      newObject = [[[recordDef recordClass] alloc]
		    initFromDictionary:anObject table:[recordDef table]];
      if ((regObject = [[self editingContext] registerInstance:newObject]) &&
	  regObject != newObject) {
	[regObject retain];
	[newObject release];
	newObject = regObject;
      }
#if 0
      else
	[CLDefaultContext addObject:newObject];
#endif
    }
    [seen setObject:newObject forKey:
	    [CLPlaceholder placeholderFromString:[newObject className] tag:[seen count] + 1]];
    if ([newObject respondsTo:@selector(setFieldsFromDictionary:seen:updateChanged:)])
      [newObject setFieldsFromDictionary:anObject seen:seen updateChanged:flag];
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
  fields = [[_recordDef fields] allKeys];
  relationships = [_recordDef relationships];
  relFields = [relationships allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    anObject = [aDict objectForKey:aKey];
    if ([fields containsObject:aKey] && anObject)
      [self setObjectValue:anObject forBinding:aKey];
    else if ([relFields containsObject:aKey] && anObject) {
      aRelationship = [relationships objectForKey:aKey];
      if ([aRelationship toMany]) {
	mArray = [[CLMutableArray alloc] init];
	[self setObjectValue:mArray forBinding:aKey];
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
	if (anObject != [self objectValueForBinding:aKey])
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
  
  aDict = [_recordDef relationships];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
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

-(CLRecordDefinition *) recordDef
{
  return _recordDef;
}

-(BOOL) hasChanges
{
  return _changed || [super hasChanges];
}

-(void) willChange
{
  [super willChange];
  _changed = YES;
  return;
}

-(BOOL) shouldDeferRelease
{
  int i, j;
  CLDictionary *aDict;
  CLArray *anArray;
  CLString *aKey;
  CLRelationship *aRelationship;
  id anObject;


  aDict = [_recordDef relationships];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aRelationship = [aDict objectForKey:aKey];
    if ([aRelationship toMany]) {
      int idx, len;
      CLArray *objects;


      objects = [self objectValueForBinding:aKey];
      for (idx = 0, len = [objects count]; idx < len; idx++) {
	anObject = [objects objectAtIndex:idx];
	if ([anObject retainCount] > 1)
	  return YES;
      }
    }
    else if ([aRelationship isOwner]) {
      anObject = [self objectValueForBinding:aKey];
      if ([anObject retainCount] > 1 &&
	  [self relationshipDependsOnUs:aRelationship record:anObject]) {
	return YES;
      }
    }
  }
  
  return NO;
}

@end

@implementation CLObject (CLFlags)

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
  unistr ustr;
  CLString *aString;


  if (![self hasFlag:aFlag]) {
    if ((aString = [self flags]))
      ustr = CLCopyStackString(aString, 1);
    else
      ustr = CLNewStackString(1);
    ustr.str[ustr.len] = aFlag;
    ustr.len++;
    aString = [((CLString *) &ustr) copy];
    [self setFlags:aString];
    [aString release];
  }
  
  return;
}

-(void) removeFlag:(unichar) aFlag
{
  CLString *aString;
  unistr ustr;
  int i;
  

  if (!(aString = [self flags]))
    return;

  ustr = CLCopyStackString(aString, 0);
  for (i = 0; i < ustr.len; i++)
    if (ustr.str[i] == aFlag)
      break;
  if (i < ustr.len) {
    [((CLMutableString *) &ustr) deleteCharactersInRange:CLMakeRange(i, 1)];
    [self setFlags:(CLString *) &ustr];
  }

  return;
}

@end

@implementation CLObject (CLGenericRecord)

-(CLEditingContext *) editingContext
{
  void *buf;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);

/* FIXME - should we do this? The editingContext will not be set when
   a new object is instantiated instead of loaded from the database. */
  if (!reserved->context) 
    reserved->context = CLDefaultContext;
  
  return reserved->context;
}

-(void) setEditingContext:(CLEditingContext *) aContext
{
  void *buf;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  reserved->context = aContext;
  return;
}

-(void) willChange
{
  [[self editingContext] addObject:self];
  return;
}

-(void) willSaveToDatabase
{
  CLDatetime *now;


  now = [CLDatetime now];
  if ([self hasFieldNamed:@"modified"] && [self hasChanges])
    [self setObjectValue:now forBinding:@"modified"];
  if ([self hasFieldNamed:@"created"] && ![self objectValueForBinding:@"created"])
    [self setObjectValue:now forBinding:@"created"];

  {
    int i, j, k, l;
    CLArray *anArray, *keys;
    CLDictionary *relationships;
    CLRecordDefinition *recordDef;
    CLRelationship *aRel;
    CLString *aKey;
    id anObject;


    if ([self isKindOfClass:CLGenericRecordClass])
      recordDef = [((CLGenericRecord *) self) recordDef];
    else
      recordDef = [CLEditingContext recordDefinitionForClass:[self class]];
    relationships = [recordDef relationships];
    keys = [relationships allKeys];
    for (i = 0, j = [keys count]; i < j; i++) {
      aKey = [keys objectAtIndex:i];
      aRel = [relationships objectForKey:aKey];
      if ([aRel toMany]) {
	anArray = [self objectValueForBinding:aKey];
	if (![anArray isFault]) {
	  for (k = 0, l = [anArray count]; k < l; k++) {
	    anObject = [anArray objectAtIndex:k];
	    if (![anObject isFault] && ![anObject exists])
	      [[self editingContext] addObject:anObject];
	  }
	}
      }
    }
  }
  
  return;
}

-(void) willDeleteFromDatabase
{
  return;
}

-(void) didInsertIntoDatabase
{
  return;
}

-(void) didUpdateDatabase
{
  return;
}

-(void) didDeleteFromDatabase
{
  return;
}

-(BOOL) hasChanges
{
  return [[self editingContext] recordHasChanges:self];
}

-(BOOL) exists
{
  return [[self editingContext] recordExists:self
		       recordDefinition:[CLEditingContext
					  recordDefinitionForClass:[self class]]];
}

-(BOOL) hasFieldNamed:(CLString *) aString
{
  CLRecordDefinition *recordDef = [CLEditingContext recordDefinitionForClass:[self class]];


  if ([[recordDef fields] objectForKey:aString])
    return YES;

  if ([[recordDef relationships] objectForKey:aString])
    return YES;

  return NO;
}

-(CLRelationship *) theirRelationship:(CLRelationship *) ours named:(CLString **) aName
{
  CLDictionary *aDict;
  int i, j;
  CLArray *anArray;
  CLRelationship *theirs;
  CLString *table;


  *aName = nil;
  table = [CLEditingContext tableForClass:[self class]];
  if ((aDict = [[CLEditingContext recordDefinitionForTable:[ours theirTable]]
		 relationships])) {
    anArray = [aDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      theirs = [aDict objectForKey:[anArray objectAtIndex:i]];
      if ([theirs isReciprocal:ours forTable:table]) {
	*aName = [anArray objectAtIndex:i];
	return theirs;
      }
    }
  }

  return nil;
}

-(void) addObject:(id) anObject toRelationship:(CLString *) aKey
{
  CLRelationship *aRelationship;
  CLMutableArray *mArray;
  CLRecordDefinition *recordDef = [CLEditingContext recordDefinitionForClass:[self class]];


  /* FIXME - set editing context on anObject if it doesn't have one? */
  
  if ([self objectValueForBinding:aKey] == anObject)
    return;
  
  aRelationship = [[recordDef relationships] objectForKey:aKey];
  if ([aRelationship toMany]) {
    mArray = [self objectValueForBinding:aKey];
    if (!mArray) {
      mArray = [[CLMutableArray alloc] init];
      [self setObjectValue:mArray forBinding:aKey];
      [mArray release];
    }
    if (![mArray containsObjectIdenticalTo:anObject]) {
      [self willChange];
      [mArray addObject:anObject];
    }
  }
  else
    [self setObjectValue:anObject forBinding:aKey];

  return;
}

-(void) addObject:(id) anObject toBothSidesOfRelationship:(CLString *) aKey
{
  CLRelationship *rel1, *rel2;
  CLString *relName;
  id otherObject;
  CLRecordDefinition *recordDef = [CLEditingContext recordDefinitionForClass:[self class]];


  if ([self objectValueForBinding:aKey] == anObject)
    return;
  
  rel1 = [[recordDef relationships] objectForKey:aKey];
  rel2 = [self theirRelationship:rel1 named:&relName];

  if (rel2 && ![rel1 toMany])
    [self removeObject:[self objectValueForBinding:aKey] fromBothSidesOfRelationship:aKey];
  [self addObject:anObject toRelationship:aKey];

  if (rel2 && [anObject respondsTo:@selector(addObject:toRelationship:)]) {
    if (![rel2 toMany] && self != [anObject objectValueForBinding:relName]) {
      otherObject = [anObject objectValueForBinding:relName];
      if ([otherObject respondsTo:@selector(removeObject:fromRelationship:)])
	[otherObject removeObject:anObject fromRelationship:aKey];
    }
    [anObject addObject:self toRelationship:relName];
  }

  return;
}

-(id) addNewObjectToBothSidesOfRelationship:(CLString *) aKey
{
  id anObject;
  CLRelationship *aRelationship;
  CLRecordDefinition *recordDef = [CLEditingContext recordDefinitionForClass:[self class]];


  aRelationship = [[recordDef relationships] objectForKey:aKey];
  anObject = [[[CLEditingContext classForTable:[aRelationship theirTable]]
		alloc] initFromDictionary:nil table:[aRelationship theirTable]];
  [self addObject:anObject toBothSidesOfRelationship:aKey];
  return anObject;
}

-(void) removeObject:(id) anObject fromRelationship:(CLString *) aKey
{
  CLRelationship *aRelationship;
  CLArray *anArray;
  CLRecordDefinition *recordDef = [CLEditingContext recordDefinitionForClass:[self class]];


  aRelationship = [[recordDef relationships] objectForKey:aKey];
  if ([aRelationship toMany]) {
    [[self objectValueForBinding:aKey] removeObject:anObject];
    if ([aRelationship isOwner]) {
      [[self editingContext] removeObject:anObject];
      [[self editingContext] deleteObject:anObject];
    }
  }
  else {
    [self setObjectValue:nil forBinding:aKey];
    anArray = [aRelationship ourKeys];
    if ([aRelationship isOwner]) {
      [[self editingContext] removeObject:anObject];
      [[self editingContext] deleteObject:anObject];
    }
    else if ([aRelationship isDependent])
      [self setObjectValue:nil forBinding:[anArray lastObject]];
  }

  return;
}

-(void) removeObject:(id) anObject fromBothSidesOfRelationship:(CLString *) aKey
{
  CLRelationship *rel1, *rel2;
  CLString *relName;
  CLRecordDefinition *recordDef = [CLEditingContext recordDefinitionForClass:[self class]];


  [anObject retain];
  rel1 = [[recordDef relationships] objectForKey:aKey];
  rel2 = [self theirRelationship:rel1 named:&relName];

  [self removeObject:anObject fromRelationship:aKey];

  if (rel2)
    [anObject removeObject:self fromRelationship:relName];
  [anObject release];

  return;
}

@end
