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

#include <stdlib.h>
#include <wctype.h>
#include <stdarg.h>

Class CLDictionaryClass, CLMutableDictionaryClass;

@implementation CLDictionary

+(void) load
{
  CLDictionaryClass = [CLDictionary class];
  return;
}

+(id) dictionary
{
  return [[[self alloc] init] autorelease];
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

  anObject = [[[self alloc] initWithObjects:objects forKeys:keys count:i] autorelease];
  return anObject;
}

-(id) init
{
  return [self initWithSize:1024];
}

-(id) initWithSize:(CLUInteger) size
{
  [super init];
  table = CLHashTableAlloc(size);
  return self;
}

-(id) initFromDictionary:(CLDictionary *) aDict
{
  CLArray *allKeys;
  int i, j;
  id aKey;

  
  [self init];
  allKeys = [aDict allKeys];
  for (i = 0, j = [allKeys count]; i < j; i++) {
    aKey = [allKeys objectAtIndex:i];
    CLHashTableSetData(table, [[aDict objectForKey:aKey] retain], [aKey copy], [aKey hash]);
  }

  return self;
}

-(id) initWithObjects:(id *) objects forKeys:(id *) keys count:(CLUInteger) count
{
  CLUInteger i;
  
  
  [self init];
  for (i = 0; i < count; i++)
    CLHashTableSetData(table, [objects[i] retain], [keys[i] copy], [keys[i] hash]);
  
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

-(void) dealloc
{
  int i;
  id *data;


  if (table->count) {
    if (!(data = alloca(sizeof(id) * table->count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetData(table, (void **) data);
    for (i = 0; i < table->count; i++)
      [data[i] release];
    CLHashTableGetKeys(table, data);
    for (i = 0; i < table->count; i++)
      [data[i] release];
  }
  CLHashTableFree(table);
  [_keys release];
  [_values release];

  [super dealloc];
  return;
}

-(id) mutableCopy
{
  return [[CLMutableDictionary alloc] initFromDictionary:self];
}

-(id) read:(CLStream *) stream
{
  int i, j;
  id aKey, aValue;

  
  [super read:stream];
  table = CLHashTableAlloc(1024);
  [stream readType:@"i" data:&j];
  for (i = 0; i < j; i++) {
    [stream readTypes:@"@@", &aKey, &aValue];
    CLHashTableSetData(table, aValue, aKey, [aKey hash]);
  }

  return self;
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

-(id) objectForKey:(id) aKey
{
  return CLHashTableDataForKey(table, aKey, [aKey hash], @selector(isEqual:));
}

-(id) objectForCaseInsensitiveString:(CLString *) aKey
{
  return CLHashTableDataForKey(table, aKey, [aKey hash],
			       @selector(isEqualToCaseInsensitiveString:));
}

-(CLArray *) allKeys
{
  id *data;

  
  if (!_keys) {
    if (!(data = alloca(sizeof(id) * table->count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetKeys(table, data);
    _keys = [[CLArray alloc] initWithObjects:data count:table->count];
  }

  return _keys;
}

-(CLArray *) allKeysForObject:(id) anObject
{
  CLUInteger i;
  id *data, *keys;
  CLMutableArray *anArray;


  if (!(data = alloca(sizeof(id) * table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetData(table, (void **) data);
  if (!(keys = alloca(sizeof(id) * table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(table, keys);
  anArray = [[CLMutableArray alloc] init];
  for (i = 0; i < table->count; i++)
    if ([anObject isEqual:data[i]])
      [anArray addObject:keys[i]];
  
  return [anArray autorelease];
}

-(CLArray *) allValues
{
  id *data;


  if (!_values) {
    if (!(data = alloca(sizeof(id) * table->count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetData(table, (void **) data);
    _values = [[CLArray alloc] initWithObjects:data count:table->count];
  }
  
  return _values;
}

-(CLUInteger) count
{
  return table->count;
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

-(CLString *) propertyList
{
  CLUInteger i, len;
  CLMutableString *mString;
  id *keys;
  CLMutableArray *mArray;
  id aKey;


  mString = [[CLMutableString alloc] initWithString:@"{"];

  if ((len = table->count)) {
    if (!(keys = alloca(sizeof(id) * len)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetKeys(table, keys);
    mArray = [[CLMutableArray alloc] initWithObjects:keys count:table->count];
    [mArray sortUsingSelector:@selector(compare:)];
    for (i = 0; i < len; i++) {
      aKey = [mArray objectAtIndex:i];
      if (i)
	[mString appendString:@" "];
      [mString appendFormat:@"%@ = %@;",
	       CLPropertyListString(aKey),
	       CLPropertyListString(CLHashTableDataForKey(table, aKey, [aKey hash],
							  @selector(isEqual:)))];
    }
    [mArray release];
  }

  [mString appendString:@"}"];

  return [mString autorelease];
}

-(CLString *) json
{
  CLUInteger i;
  CLMutableString *mString;
  id *keys;


  mString = [[CLMutableString alloc] initWithString:@"{"];

  if (!(keys = alloca(sizeof(id) * table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(table, keys);
  for (i = 0; i < table->count; i++) {
    if (i)
      [mString appendString:@", "];
    [mString appendFormat:@"%@:%@",
	     CLJSONString(keys[i]),
	     CLJSONString(CLHashTableDataForKey(table, keys[i], [keys[i] hash],
						@selector(isEqual:)))];
  }

  [mString appendString:@"}"];

  return [mString autorelease];
}

-(CLString *) description
{
  return [self propertyList];
}

-(CLString *) encodeXML
{
  CLUInteger i, j, k;
  CLMutableString *mString;
  id *keys;
  id aKey, aValue;
  CLDictionary *aDict;
  CLArray *anArray;


  mString = [[CLMutableString alloc] init];

  if (!(keys = alloca(sizeof(id) * table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(table, keys);
  for (i = 0; i < table->count; i++) {
    aValue = CLHashTableDataForKey(table, keys[i], [keys[i] hash], @selector(isEqual:));
    if ([aValue isKindOfClass:CLArrayClass] && [aValue count] == 2 &&
	[[aValue objectAtIndex:0] isKindOfClass:CLDictionaryClass]) {
      [mString appendFormat:@"<%@", [keys[i] description]];
      aDict = [aValue objectAtIndex:0];
      aValue = [aValue objectAtIndex:1];
      anArray = [aDict allKeys];
      for (k = 0, j = [anArray count]; k < j; k++) {
	aKey = [anArray objectAtIndex:k];
	[mString appendFormat:@" %@=\"%@\"", [aKey description],
		 [[[aDict objectForKey:aKey] description] xmlEntityEncodedString]];
      }
    }
    else
      [mString appendFormat:@"<%@", [keys[i] description]];
    
    if (!aValue || aValue == CLNullObject)
      [mString appendFormat:@" />"];
    else
      [mString appendFormat:@">%@</%@>",
	       [[aValue description] xmlEntityEncodedString], [keys[i] description]];
  }

  return [mString autorelease];
}
 
-(BOOL) isEqual:(id) anObject
{
  int i;
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
  
  if (!(data = alloca(sizeof(id) * table->count)))
    [self error:@"Unable to allocate memory"];
  CLHashTableGetKeys(table, data);
  for (i = 0, res = YES; i < table->count; i++)
    if (![[self objectForKey:data[i]] isEqual:[anObject objectForKey:data[i]]]) {
      res = NO;
      break;
    }
  
  return res;
}

-(CLUInteger) hash
{
  CLArray *anArray;
  int i, j;
  CLUInteger h;
  id anObject;


  if (!_hash) {
    anArray = [[self allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (i = 0, j = [anArray count]; i < j; i++) {
      anObject = [anArray objectAtIndex:i];
      h = [anObject hash];
      _hash = CLHashBytes(&h, sizeof(h), _hash);
      h = [[self objectForKey:anObject] hash];
      _hash = CLHashBytes(&h, sizeof(h), _hash);
    }
  }

  return _hash;
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
