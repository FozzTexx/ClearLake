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

@implementation CLDictionary

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
  if (!(objects = malloc(sizeof(id) * i)))
    [self error:@"Unable to allocate memory"];
  if (!(keys = malloc(sizeof(id) * i)))
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
  free(objects);
  free(keys);
  return anObject;
}

-(id) init
{
  return [self initWithSize:1024];
}

-(id) initWithSize:(CLUInteger) size
{
  [super init];
  table = [[CLHashTable alloc] initWithSize:size];
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
    [table setData:[[aDict objectForKey:aKey] retain] forKey:[aKey copy]
	      hash:[aKey hash]];
  }

  return self;
}

-(id) initWithObjects:(id *) objects forKeys:(id *) keys count:(CLUInteger) count
{
  CLUInteger i;
  
  
  [self init];
  for (i = 0; i < count; i++)
    [table setData:[objects[i] retain] forKey:[keys[i] copy] hash:[keys[i] hash]];
  
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
  if (!(objects = malloc(sizeof(id) * i)))
    [self error:@"Unable to allocate memory"];
  if (!(keys = malloc(sizeof(id) * i)))
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
  free(objects);
  free(keys);
  return anObject;
}

-(void) dealloc
{
  int i, len;
  id *data;


  if ((len = [table count])) {
    if (!(data = malloc(sizeof(id) * len)))
      [self error:@"Unable to allocate memory"];
    [table getData:(void **) data];
    for (i = 0; i < len; i++)
      [data[i] release];
    [table getKeys:data];
    for (i = 0; i < len; i++)
      [data[i] release];
    free(data);
  }
  [table release];
  [_keys release];

  [super dealloc];
  return;
}

-(id) copy
{
  return [self retain];
}

-(id) mutableCopy
{
  return [[CLMutableDictionary alloc] initFromDictionary:self];
}

-(void) read:(CLTypedStream *) stream
{
  int i, j;
  id aKey, aValue;

  
  [super read:stream];
  table = [[CLHashTable alloc] init];
  CLReadTypes(stream, "i", &j);
  for (i = 0; i < j; i++) {
    CLReadTypes(stream, "@@", &aKey, &aValue);
    [table setData:aValue forKey:aKey hash:[aKey hash]];
  }

  return;
}

-(void) write:(CLTypedStream *) stream
{
  CLArray *anArray;
  id aKey, aValue;
  int i, j;

  
  [super write:stream];
  anArray = [self allKeys];
  j = [anArray count];
  CLWriteTypes(stream, "i", &j);
  for (i = 0; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    aValue = [self objectForKey:aKey];
    CLWriteTypes(stream, "@@", &aKey, &aValue);
  }

  return;
}

-(id) objectForKey:(id) aKey
{
  return [table dataForKey:aKey hash:[aKey hash]];
}

-(id) objectForCaseInsensitiveString:(CLString *) aKey
{
  return [table dataForKey:aKey hash:[aKey hash]
		  selector:@selector(isEqualToCaseInsensitiveString:)];
}

-(CLArray *) allKeys
{
  if (!_keys)
    _keys = [[table allKeys] retain];
  return _keys;
}

-(CLArray *) allKeysForObject:(id) anObject
{
  CLUInteger i, len;
  id *data, *keys;
  CLMutableArray *anArray;


  len = [table count];
  if (!(data = malloc(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [table getData:(void **) data];
  if (!(keys = malloc(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [table getKeys:keys];
  anArray = [[CLMutableArray alloc] init];
  for (i = 0; i < len; i++)
    if ([anObject isEqual:data[i]])
      [anArray addObject:keys[i]];

  free(keys);
  free(data);
  
  return [anArray autorelease];
}

-(CLArray *) allValues
{
  CLUInteger len;
  id *data;
  CLArray *anArray;


  len = [table count];
  if (!(data = malloc(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [table getData:(void **) data];
  anArray = [[CLArray alloc] initWithObjects:data count:len];
  free(data);
  return [anArray autorelease];
}

-(CLUInteger) count
{
  return [table count];
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


  mString = [[CLMutableString alloc] initWithString:@"{\n"];

  if ((len = [table count])) {
    if (!(keys = malloc(sizeof(id) * len)))
      [self error:@"Unable to allocate memory"];
    [table getKeys:keys];
    mArray = [[CLMutableArray alloc] initWithObjects:keys count:len];
    free(keys);
    [mArray sortUsingSelector:@selector(compare:)];
    for (i = 0; i < len; i++) {
      aKey = [mArray objectAtIndex:i];
      [mString appendFormat:@"  %@ = %@;\n",
	       CLPropertyListString(aKey),
	       CLPropertyListString([table dataForKey:aKey hash:[aKey hash]])];
    }
    [mArray release];
  }

  [mString appendString:@"}\n"];

  return [mString autorelease];
}

-(CLString *) json
{
  CLUInteger i, len;
  CLMutableString *mString;
  id *keys;


  mString = [[CLMutableString alloc] initWithString:@"{\n"];

  len = [table count];
  if (!(keys = malloc(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [table getKeys:keys];
  for (i = 0; i < len; i++) {
    if (i)
      [mString appendString:@", "];
    [mString appendFormat:@"  %@ : %@",
	     CLJSONString(keys[i]),
	     CLJSONString([table dataForKey:keys[i] hash:[keys[i] hash]])];
  }
  free(keys);

  [mString appendString:@"}\n"];

  return [mString autorelease];
}

-(CLString *) description
{
  return [self propertyList];
}

-(CLString *) encodeXML
{
  CLUInteger i, j, k, len;
  CLMutableString *mString;
  id *keys;
  id aKey, aValue;
  CLDictionary *aDict;
  CLArray *anArray;


  mString = [[CLMutableString alloc] init];

  len = [table count];
  if (!(keys = malloc(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [table getKeys:keys];
  for (i = 0; i < len; i++) {
    aValue = [table dataForKey:keys[i] hash:[keys[i] hash]];
    if ([aValue isKindOfClass:[CLArray class]] && [aValue count] == 2 &&
	[[aValue objectAtIndex:0] isKindOfClass:[CLDictionary class]]) {
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
    
    if (!aValue || [aValue isKindOfClass:[CLNull class]])
      [mString appendFormat:@" />"];
    else
      [mString appendFormat:@">%@</%@>",
	       [[aValue description] xmlEntityEncodedString], [keys[i] description]];
  }
  free(keys);

  return [mString autorelease];
}
 
-(BOOL) isEqual:(id) anObject
{
  int i, len;
  id *data;
  BOOL res;


  if (anObject == self)
    return YES;
  
  if (![anObject isKindOfClass:[CLDictionary class]])
    return NO;

  if ([self count] != [anObject count])
    return NO;

  if ([self hash] != [anObject hash])
    return NO;
  
  len = [table count];
  if (!(data = malloc(sizeof(id) * len)))
    [self error:@"Unable to allocate memory"];
  [table getKeys:data];
  for (i = 0, res = YES; i < len; i++)
    if (![[self objectForKey:data[i]] isEqual:[anObject objectForKey:data[i]]]) {
      res = NO;
      break;
    }
  free(data);
  
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

@end
