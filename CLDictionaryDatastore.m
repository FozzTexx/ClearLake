/* Copyright 2024 by
 *   Chris Osborn <fozztexx@fozztexx.com>
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

#import "CLDictionaryDatastore.h"
#import "CLHashTable.h"
#import "CLValue.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLStream.h"
#import "CLClassConstants.h"
#import "CLNull.h"

@interface CLDictionary (CLDictionaryDatastoreCommon)
-(id) _datastoreInitWithObjects:(id *) objects andKeys:(id *) keys
			  count:(CLUInteger) count size:(CLUInteger) size;
-(id) _datastoreRead:(CLStream *) stream;
-(void) _datastoreWrite:(CLStream *) stream;
-(CLUInteger) _datastoreCount;
-(id) _datastoreObjectForKey:(id) aKey caseInsensitive:(BOOL) caseFlag;
-(CLArray *) _datastoreAllKeys;
-(CLArray *) _datastoreAllKeysForObject:(id) anObject;
-(CLArray *) _datastoreAllValues;
@end

@implementation CLDictionary (CLDictionaryDatastoreCommon)

-(id) _datastoreInitWithObjects:(id *) objects andKeys:(id *) keys
			  count:(CLUInteger) count size:(CLUInteger) size
{
  CLDictionaryStorage *storage;
  CLUInteger i;


  [super init];
  storage = calloc(1, sizeof(*storage));
  storage->table = CLHashTableAlloc(CLMax(size, count));
  dictionaryData = storage;
  for (i = 0; i < count; i++)
    CLHashTableSetData(storage->table, [objects[i] retain], [keys[i] copy], [keys[i] hash]);

  return self;
}

-(void) _datastoreDealloc
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx;
  id *data;


  if (storage->table->count) {
    if (!(data = alloca(sizeof(id) * storage->table->count))) {
      fprintf(stderr, "error: Unable to allocate memory");
      abort();
    }
    CLHashTableGetData(storage->table, (void **) data);
    for (idx = 0; idx < storage->table->count; idx++)
      [data[idx] release];
    CLHashTableGetKeys(storage->table, data);
    for (idx = 0; idx < storage->table->count; idx++)
      [data[idx] release];
  }
  CLHashTableFree(storage->table);
  [storage->_keys release];
  [storage->_values release];

  free(storage);
  return;
}

-(id) _datastoreRead:(CLStream *) stream
{
  CLDictionaryStorage *storage;
  CLUInteger idx, count;
  id aKey, aValue;


  self = [super read:stream];
  [stream readType:@"I" data:&count];
  storage = calloc(1, sizeof(*storage));
  storage->table = CLHashTableAlloc(count);
  dictionaryData = storage;
  for (idx = 0; idx < count; idx++) {
    [stream readTypes:@"@@", &aKey, &aValue];
    if (!aKey || !aValue)
      [self error:@"Bogus key/value"];
    CLHashTableSetData(storage->table, aValue, aKey, [aKey hash]);
  }

  return self;
}

-(void) _datastoreWrite:(CLStream *) stream
{
  CLDictionaryStorage *storage = dictionaryData;
  id aKey, aValue;
  CLUInteger idx;
  id *data, *keys;


  [super write:stream];

  if (!(data = alloca(sizeof(id) * storage->table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetData(storage->table, (void **) data);
  if (!(keys = alloca(sizeof(id) * storage->table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(storage->table, keys);

  [stream writeTypes:@"I", &storage->table->count];
  for (idx = 0; idx < storage->table->count; idx++) {
    aKey = keys[idx];
    aValue = data[idx];
    if (!aKey || !aValue)
      [self error:@"Bogus key/value"];
    [stream writeTypes:@"@@", &aKey, &aValue];
  }

  return;
}

-(CLUInteger) _datastoreCount
{
  CLDictionaryStorage *storage = dictionaryData;


  return storage->table->count;
}

-(id) _datastoreObjectForKey:(id) aKey caseInsensitive:(BOOL) caseFlag
{
  CLDictionaryStorage *storage = dictionaryData;
  SEL aSel;


  aSel = caseFlag ? @selector(isEqualToCaseInsensitiveString:) : @selector(isEqual:);
  return CLHashTableDataForKey(storage->table, aKey, [aKey hash], aSel);
}

-(CLArray *) _datastoreAllKeys
{
  CLDictionaryStorage *storage = dictionaryData;
  id *data;


  if (!storage->_keys) {
    if (!(data = alloca(sizeof(id) * storage->table->count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetKeys(storage->table, data);
    storage->_keys = [[CLArray alloc] initWithObjects:data count:storage->table->count];
  }

  return storage->_keys;
}

-(CLArray *) _datastoreAllKeysForObject:(id) anObject
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx;
  id *data, *keys;
  CLMutableArray *anArray;


  if (!(data = alloca(sizeof(id) * storage->table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetData(storage->table, (void **) data);
  if (!(keys = alloca(sizeof(id) * storage->table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(storage->table, keys);
  anArray = [[CLMutableArray alloc] init];
  for (idx = 0; idx < storage->table->count; idx++)
    if ([anObject isEqual:data[idx]])
      [anArray addObject:keys[idx]];

  return [anArray autorelease];
}

-(CLArray *) _datastoreAllValues
{
  CLDictionaryStorage *storage = dictionaryData;
  id *data;


  if (!storage->_values) {
    if (!(data = alloca(sizeof(id) * storage->table->count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetData(storage->table, (void **) data);
    storage->_values = [[CLArray alloc] initWithObjects:data count:storage->table->count];
  }

  return storage->_values;
}

-(CLUInteger) _datastoreHash
{
  CLDictionaryStorage *storage = dictionaryData;
  CLArray *anArray;
  CLUInteger idx, count;
  CLUInteger h;
  id anObject;


  if (!storage->_hash) {
    anArray = [[self allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (idx = 0, count = [anArray count]; idx < count; idx++) {
      anObject = [anArray objectAtIndex:idx];
      h = [anObject hash];
      storage->_hash = CLHashBytes(&h, sizeof(h), storage->_hash);
      h = [[self objectForKey:anObject] hash];
      storage->_hash = CLHashBytes(&h, sizeof(h), storage->_hash);
    }
  }

  return storage->_hash;
}

@end

@implementation CLDictionaryDatastore

-(id) initAsCaseInsensitive:(BOOL) caseFlag
{
  return [self initWithObjects:NULL andKeys:NULL count:0 caseInsensitive:NO];
}

-(id) initWithObjects:(id *) objects andKeys:(id *) keys count:(CLUInteger) count
      caseInsensitive:(BOOL) caseFlag
{
  caseInsensitiveFlag = caseFlag;
  return [self _datastoreInitWithObjects:objects andKeys:keys count:count size:0];
}

-(void) dealloc
{
  [self _datastoreDealloc];
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  return [self _datastoreRead:stream];
}

-(void) write:(CLStream *) stream
{
  [self _datastoreWrite:stream];
  return;
}

-(CLUInteger) count
{
  return [self _datastoreCount];
}

-(id) objectForKey:(id) aKey
{
  return [self _datastoreObjectForKey:aKey caseInsensitive:caseInsensitiveFlag];
}

-(id) objectForCaseInsensitiveString:(CLString *) aKey
{
  return [self _datastoreObjectForKey:aKey caseInsensitive:YES];
}

-(CLArray *) allKeys
{
  return [self _datastoreAllKeys];
}

-(CLArray *) allKeysForObject:(id) anObject
{
  return [self _datastoreAllKeysForObject:anObject];
}

-(CLArray *) allValues
{
  return [self _datastoreAllValues];
}

-(CLUInteger) hash
{
  return [self _datastoreHash];
}

@end

@implementation CLMutableDictionaryDatastore

-(id) initAsCaseInsensitive:(BOOL) caseFlag
{
  return [self initWithObjects:NULL andKeys:NULL count:0 caseInsensitive:NO];
}

-(id) initWithObjects:(id *) objects andKeys:(id *) keys count:(CLUInteger) count
      caseInsensitive:(BOOL) caseFlag
{
  caseInsensitiveFlag = caseFlag;
  return [self _datastoreInitWithObjects:objects andKeys:keys count:count size:0];
}

-(id) initWithSize:(CLUInteger) size
{
  return [self initWithSize:size caseInsensitive:NO];
}

-(id) initWithSize:(CLUInteger) size caseInsensitive:(BOOL) caseFlag
{
  caseInsensitiveFlag = caseFlag;
  return [self _datastoreInitWithObjects:NULL andKeys:NULL count:0 size:size];
}

-(void) dealloc
{
  [self _datastoreDealloc];
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  return [self _datastoreRead:stream];
}

-(void) write:(CLStream *) stream
{
  [self _datastoreWrite:stream];
  return;
}

-(CLUInteger) count
{
  return [self _datastoreCount];
}

-(id) objectForKey:(id) aKey
{
  return [self _datastoreObjectForKey:aKey caseInsensitive:caseInsensitiveFlag];
}

-(id) objectForCaseInsensitiveString:(CLString *) aKey
{
  return [self _datastoreObjectForKey:aKey caseInsensitive:YES];
}

/* Doing an extra retain & autorelease on allKeys because we are
   mutable. If we get modified the array will be released unexpectedly
   and it should stick around until the caller is done with it. */
-(CLArray *) allKeys
{
  return [[[self _datastoreAllKeys] retain] autorelease];
}

-(CLArray *) allKeysForObject:(id) anObject
{
  return [self _datastoreAllKeysForObject:anObject];
}

/* Doing an extra retain & autorelease on allValues because we are
   mutable. If we get modified the array will be released unexpectedly
   and it should stick around until the caller is done with it. */
-(CLArray *) allValues
{
  return [[[self _datastoreAllValues] retain] autorelease];
}

-(CLUInteger) hash
{
  return [self _datastoreHash];
}

-(void) setObject:(id) anObject forKey:(id) aKey
{
  CLDictionaryStorage *storage = dictionaryData;
  id oldObject, oldObject2;


  if (!anObject || !aKey)
    [self error:@"Can't set nil objects!"];

  [anObject retain];
  if ((oldObject = CLHashTableKeyForKey(storage->table, aKey, [aKey hash],
                                        @selector(isEqual:)))) {
    oldObject2 = CLHashTableRemoveDataForKey(storage->table, aKey, [aKey hash],
                                             @selector(isEqual:));
    [oldObject release];
    [oldObject2 release];
  }
  aKey = [aKey copy];
  CLHashTableSetData(storage->table, anObject, aKey, [aKey hash]);

  storage->_hash = 0;
  [storage->_keys release];
  storage->_keys = nil;
  [storage->_values release];
  storage->_values = nil;
  return;
}

#if 0
-(void) removeObjectForCaseInsensitiveString:(CLString *) aKey
{
  CLDictionaryStorage *storage = dictionaryData;
  id oldKey, oldObject;


  if ((oldKey = CLHashTableKeyForKey(storage->table, aKey, [aKey hash],
                                     @selector(isEqualToCaseInsensitiveString:)))) {
    oldObject = CLHashTableRemoveDataForKey(storage->table, oldKey, [oldKey hash],
                                            @selector(isEqualToCaseInsensitiveString:));
    [oldKey release];
    [oldObject release];

    storage->_hash = 0;
    [storage->_keys release];
    storage->_keys = nil;
    [storage->_values release];
    storage->_values = nil;
  }

  return;
}
#endif

-(void) removeObjectForKey:(id) aKey
{
  CLDictionaryStorage *storage = dictionaryData;
  id oldKey, oldObject;
  SEL aSel;


  aSel = caseInsensitiveFlag ?
    @selector(isEqualToCaseInsensitiveString:) : @selector(isEqual:);

  if ((oldKey = CLHashTableKeyForKey(storage->table, aKey, [aKey hash], aSel))) {
    oldObject = CLHashTableRemoveDataForIdenticalKey(storage->table, oldKey, [oldKey hash]);
    [oldKey release];
    [oldObject release];

    storage->_hash = 0;
    [storage->_keys release];
    storage->_keys = nil;
    [storage->_values release];
    storage->_values = nil;
  }

  return;
}

-(void) removeAllObjects
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx, count;
  id *keys;
  id oldObject;


  if (storage && storage->table && storage->table->count) {
    count = storage->table->count;
    if (!(keys = alloca(sizeof(id) * count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetKeys(storage->table, keys);
    for (idx = 0; idx < count; idx++) {
      oldObject = CLHashTableRemoveDataForKey(storage->table, keys[idx], [keys[idx] hash],
                                              @selector(isEqual:));
      [keys[idx] release];
      [oldObject release];
    }

    storage->_hash = 0;
    [storage->_keys release];
    storage->_keys = nil;
    [storage->_values release];
    storage->_values = nil;
  }

  return;
}

@end
