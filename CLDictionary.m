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

#import "CLDictionary.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"
#import "CLMutableString.h"
#import "CLHashTable.h"
#import "CLStream.h"
#import "CLNull.h"
#import "CLClassConstants.h"

#include <stdlib.h>
#include <wctype.h>
#include <stdarg.h>

@implementation CLDictionary

+(id) alloc
{
  if (self == CLDictionaryClass)
    self = CLInternalDictionaryClass;
  return [super alloc];
}

+(id) dictionary
{
  return [[[CLInternalDictionary alloc] init] autorelease];
}

+(id) dictionaryWithObjectsAndKeys:(id) firstObject , ...
{
  CLUInteger i;
  id *objects, *keys;
  va_list ap;
  id anObject;


  va_start(ap, firstObject);
  for (i = 1; va_arg(ap, id); i++)
    ;
  va_end(ap);
  i /= 2;
  if (!(objects = alloca(sizeof(id) * i)))
    [self error:@"Unable to allocate memory"];
  if (!(keys = alloca(sizeof(id) * i)))
    [self error:@"Unable to allocate memory"];

  va_start(ap, firstObject);
  objects[0] = firstObject;
  keys[0] = va_arg(ap, id);

  for (i = 1; (anObject = va_arg(ap, id)); i ++) {
    objects[i] = anObject;
    keys[i] = va_arg(ap, id);
  }
  va_end(ap);

  anObject = [[[CLInternalDictionary alloc] initWithObjects:objects forKeys:keys count:i]
               autorelease];
  return anObject;
}

-(id) initFromDictionary:(CLDictionary *) aDict
{
  CLUInteger count;
  id *objects, *keys;


  [self init];

  count = [aDict count];
  if (!(objects = alloca(sizeof(id) * count)))
    [self error:@"Unable to allocate memory"];
  if (!(keys = alloca(sizeof(id) * count)))
    [self error:@"Unable to allocate memory"];

  [[aDict allKeys] getObjects:keys];
  [[aDict allValues] getObjects:objects];

  [self initWithObjects:objects forKeys:keys count:count];

  return self;
}

-(id) initWithObjectsAndKeys:(id) firstObject, ...
{
  CLUInteger i;
  id *objects, *keys;
  va_list ap;
  id anObject;


  va_start(ap, firstObject);
  for (i = 1; va_arg(ap, id); i++)
    ;
  va_end(ap);
  i /= 2;
  if (!(objects = alloca(sizeof(id) * i)))
    [self error:@"Unable to allocate memory"];
  if (!(keys = alloca(sizeof(id) * i)))
    [self error:@"Unable to allocate memory"];

  va_start(ap, firstObject);
  objects[0] = firstObject;
  keys[0] = va_arg(ap, id);

  for (i = 1; (anObject = va_arg(ap, id)); i ++) {
    objects[i] = anObject;
    keys[i] = va_arg(ap, id);
  }
  va_end(ap);

  anObject = [self initWithObjects:objects forKeys:keys count:i];
  return anObject;
}

-(id) mutableCopy
{
  return [[CLMutableDictionary alloc] initFromDictionary:self];
}

-(void) write:(CLStream *) stream
{
  CLArray *anArray;
  id aKey, aValue;
  int i, j;


  [super write:stream];
  anArray = [self allKeys];
  j = [anArray count];
  [stream writeTypes:@"i", &j];
  for (i = 0; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aValue = [self objectForKey:aKey];
    [stream writeTypes:@"@@", &aKey, &aValue];
  }

  return;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLRange aRange;
  CLString *aString;
  id anObject = nil;


  *found = NO;

  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else
    aString = [aBinding substringToIndex:aRange.location];

  if (!(anObject = [self objectForKey:aString]))
    return [super objectValueForBinding:aBinding found:found];

  *found = YES;

  if (aRange.length)
    anObject = [anObject objectValueForBinding:
                           [aBinding substringFromIndex:CLMaxRange(aRange)] found:found];

  return anObject;
}

-(CLString *) description
{
  return [self propertyList];
}

#if DEBUG_RETAIN
#undef copy
#undef retain
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  return [self retain:file :line :retainer];
}
#else
-(id) copy
{
  return [self retain];
}
#endif

@end

@implementation CLDictionary (CLSubclassMethods)

-(id) init
{
  if ([self class] == CLDictionaryClass)
    [self error:@"%s: %s must be implemented by subclass",
          object_getClassName(self), sel_getName(_cmd)];
  return [super init];
}

-(id) initWithObjects:(id *) objects forKeys:(id *) keys count:(CLUInteger) count
{
  [self error:@"%s: %s must be implemented by subclass",
          object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

-(CLUInteger) count
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return 0;
}

-(id) objectForKey:(id) aKey
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

-(id) objectForCaseInsensitiveString:(CLString *) aKey
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

-(CLArray *) allKeys
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

-(CLArray *) allValues
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

@end

@implementation CLInternalDictionary

-(id) init
{
  return [self initWithSize:1024];
}

-(id) initWithSize:(CLUInteger) size
{
  [super init];
  dictionaryData = CLInternalDictionaryInitStorage(size);
  return self;
}

-(id) initWithObjects:(id *) objects forKeys:(id *) keys count:(CLUInteger) count
{
  CLDictionaryStorage *storage;
  CLUInteger i;


  [self init];
  storage = dictionaryData;
  for (i = 0; i < count; i++)
    CLHashTableSetData(storage->table, [objects[i] retain], [keys[i] copy], [keys[i] hash]);

  return self;
}

-(void) dealloc
{
  CLInternalDictionaryDeallocStorage((CLDictionaryStorage *) dictionaryData);
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx, count;
  id aKey, aValue;


  [super read:stream];
  storage->table = CLHashTableAlloc(1024);
  [stream readType:@"u" data:&count];
  for (idx = 0; idx < count; idx++) {
    [stream readTypes:@"@@", &aKey, &aValue];
    CLHashTableSetData(storage->table, aValue, aKey, [aKey hash]);
  }

  return self;
}

-(id) objectForKey:(id) aKey
{
  CLDictionaryStorage *storage = dictionaryData;


  return CLHashTableDataForKey(storage->table, aKey, [aKey hash], @selector(isEqual:));
}

-(id) objectForCaseInsensitiveString:(CLString *) aKey
{
  CLDictionaryStorage *storage = dictionaryData;


  return CLHashTableDataForKey(storage->table, aKey, [aKey hash],
                               @selector(isEqualToCaseInsensitiveString:));
}

-(CLArray *) allKeys
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

-(CLArray *) allKeysForObject:(id) anObject
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

-(CLArray *) allValues
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

-(CLUInteger) count
{
  CLDictionaryStorage *storage = dictionaryData;


  return storage->table->count;
}

-(CLString *) propertyList
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx, count;
  CLMutableString *mString;
  id *keys;
  CLMutableArray *mArray;
  id aKey;


  mString = [[CLMutableString alloc] initWithString:@"{"];

  if ((count = storage->table->count)) {
    if (!(keys = alloca(sizeof(id) * count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetKeys(storage->table, keys);
    mArray = [[CLMutableArray alloc] initWithObjects:keys count:storage->table->count];
    [mArray sortUsingSelector:@selector(compare:)];
    for (idx = 0; idx < count; idx++) {
      aKey = [mArray objectAtIndex:idx];
      if (idx)
        [mString appendString:@" "];
      [mString appendFormat:@"%@ = %@;",
               CLPropertyListString(aKey),
               CLPropertyListString(CLHashTableDataForKey(storage->table, aKey, [aKey hash],
                                                          @selector(isEqual:)))];
    }
    [mArray release];
  }

  [mString appendString:@"}"];

  return [mString autorelease];
}

-(CLString *) json
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx;
  CLMutableString *mString;
  id *keys;


  mString = [[CLMutableString alloc] initWithString:@"{"];

  if (!(keys = alloca(sizeof(id) * storage->table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(storage->table, keys);
  for (idx = 0; idx < storage->table->count; idx++) {
    if (idx)
      [mString appendString:@", "];
    [mString appendFormat:@"%@:%@",
             CLJSONString(keys[idx]),
             CLJSONString(CLHashTableDataForKey(storage->table, keys[idx], [keys[idx] hash],
                                                @selector(isEqual:)))];
  }

  [mString appendString:@"}"];

  return [mString autorelease];
}

-(CLString *) encodeXML
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx, jdx, count;
  CLMutableString *mString;
  id *keys;
  id aKey, aValue;
  CLDictionary *aDict;
  CLArray *anArray;


  mString = [[CLMutableString alloc] init];

  if (!(keys = alloca(sizeof(id) * storage->table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(storage->table, keys);
  for (idx = 0; idx < storage->table->count; idx++) {
    aValue = CLHashTableDataForKey(storage->table, keys[idx], [keys[idx] hash],
                                   @selector(isEqual:));
    if ([aValue isKindOfClass:CLArrayClass] && [aValue count] == 2 &&
        [[aValue objectAtIndex:0] isKindOfClass:CLDictionaryClass]) {
      [mString appendFormat:@"<%@", [keys[idx] description]];
      aDict = [aValue objectAtIndex:0];
      aValue = [aValue objectAtIndex:1];
      anArray = [aDict allKeys];
      for (jdx = 0, count = [anArray count]; jdx < count; jdx++) {
        aKey = [anArray objectAtIndex:jdx];
        [mString appendFormat:@" %@=\"%@\"", [aKey description],
                 [[[aDict objectForKey:aKey] description] xmlEntityEncodedString]];
      }
    }
    else
      [mString appendFormat:@"<%@", [keys[idx] description]];

    if (!aValue || aValue == CLNullObject)
      [mString appendFormat:@" />"];
    else
      [mString appendFormat:@">%@</%@>",
               [[aValue description] xmlEntityEncodedString], [keys[idx] description]];
  }

  return [mString autorelease];
}

-(BOOL) isEqual:(id) anObject
{
  CLDictionaryStorage *storage = dictionaryData;
  CLUInteger idx;
  id *data;
  BOOL res;


  if (self == anObject)
    return YES;

  if (![anObject isKindOfClass:CLDictionaryClass])
    return NO;

  if ([self count] != [anObject count])
    return NO;

  if ([self hash] != [anObject hash])
    return NO;

  if (!(data = alloca(sizeof(id) * storage->table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(storage->table, data);
  for (idx = 0, res = YES; idx < storage->table->count; idx++)
    if (![[self objectForKey:data[idx]] isEqual:[anObject objectForKey:data[idx]]]) {
      res = NO;
      break;
    }

  return res;
}

-(CLUInteger) hash
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

void *CLInternalDictionaryInitStorage(CLUInteger size)
{
  CLDictionaryStorage *storage;


  storage = calloc(1, sizeof(*storage));
  storage->table = CLHashTableAlloc(size);
  return storage;
}

void CLInternalDictionaryDeallocStorage(CLDictionaryStorage *storage)
{
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
