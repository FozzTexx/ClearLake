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
#import "CLMutableDictionary.h"
#import "CLDictionaryDatastore.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLHashTable.h"
#import "CLStream.h"
#import "CLNull.h"
#import "CLClassConstants.h"
#import "CLAutoreleasePool.h"

#include <stdlib.h>
#include <wctype.h>
#include <stdarg.h>

@implementation CLDictionary

#if DEBUG_RETAIN
#undef alloc
#endif

+(id) alloc
{
  if (self == CLDictionaryClass)
    self = CLDictionaryDatastoreClass;
  return [super alloc];
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

  anObject = [[[self alloc] initWithObjects:objects forKeys:keys count:i]
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

-(id) read:(CLStream *) stream
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return nil;
}

-(void) write:(CLStream *) stream
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return;
}

-(id) mutableCopy
{
  return [[CLMutableDictionary alloc] initFromDictionary:self];
}

-(id) objectValueForKey:(CLString *) aKey found:(BOOL *) found
{
  id anObject = nil;


  *found = NO;

  if (!(anObject = [self objectForKey:aKey]))
    return [super objectValueForKey:aKey found:found];

  *found = YES;
  return anObject;
}

-(BOOL) isEqual:(id) anObject
{
  CLUInteger idx, count;
  CLArray *keys;
  id aKey;
  BOOL res;


  if (self == anObject)
    return YES;

  if (![anObject isKindOfClass:CLDictionaryClass])
    return NO;

  if ([self count] != [anObject count])
    return NO;

  if ([self hash] != [anObject hash])
    return NO;

  keys = [self allKeys];
  for (idx = 0, res = YES, count = [keys count]; idx < count; idx++) {
    aKey = [keys objectAtIndex:idx];
    if (![[self objectForKey:aKey] isEqual:[anObject objectForKey:aKey]]) {
      res = NO;
      break;
    }
  }

  return res;
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

-(CLString *) encodeXML
{
  CLUInteger idx, jdx, count;
  CLMutableString *mString;
  CLArray *keys;
  id aKey, aValue;
  CLDictionary *aDict;
  CLArray *anArray;


  mString = [[CLMutableString alloc] init];

  keys = [self allKeys];
  for (idx = 0, count = [keys count]; idx < count; idx++) {
    aKey = [keys objectAtIndex:idx];
    aValue = [self objectForKey:[keys objectAtIndex:idx]];
    if ([aValue isKindOfClass:CLArrayClass] && [aValue count] == 2 &&
        [[aValue objectAtIndex:0] isKindOfClass:CLDictionaryClass]) {
      [mString appendFormat:@"<%@", [aKey description]];
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
      [mString appendFormat:@"<%@", [aKey description]];

    if (!aValue || aValue == CLNullObject)
      [mString appendFormat:@" />"];
    else
      [mString appendFormat:@">%@</%@>",
               [[aValue description] xmlEntityEncodedString], [aKey description]];
  }

  return [mString autorelease];
}

-(CLString *) json
{
  CLUInteger idx, count;
  CLMutableString *mString;
  CLArray *keys;
  id aKey;


  mString = [[CLMutableString alloc] initWithString:@"{"];

  keys = [self allKeys];
  for (idx = 0, count = [keys count]; idx < count; idx++) {
    if (idx)
      [mString appendString:@", "];
    aKey = [keys objectAtIndex:idx];
    [mString appendFormat:@"%@:%@", CLJSONString(aKey),
	     CLJSONString([self objectForKey:aKey])];
  }

  [mString appendString:@"}"];

  return [mString autorelease];
}

-(CLString *) propertyList
{
  CLUInteger idx, count;
  CLMutableString *mString;
  CLArray *keys;
  id aKey;
  CLAutoreleasePool *pool;


  pool = [[CLAutoreleasePool alloc] init];
  mString = [[CLMutableString alloc] initWithString:@"{"];

  if ([self count]) {
    keys = [[self allKeys] sortedArrayUsingSelector:@selector(compare:)];
    for (idx = 0, count = [keys count]; idx < count; idx++) {
      if (idx)
        [mString appendString:@" "];
      aKey = [keys objectAtIndex:idx];
      [mString appendFormat:@"%@ = %@;", CLPropertyListString(aKey),
	       CLPropertyListString([self objectForKey:aKey])];
    }
  }

  [mString appendString:@"}"];
  [pool release];

  return [mString autorelease];
}

@end

@implementation CLDictionary (CLSubclassMethods)

-(id) init
{
  if ([self class] == CLDictionaryClass || [self class] == CLMutableDictionaryClass)
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

-(id) read:(CLStream *) stream
{
  if ([self class] == CLDictionaryClass || [self class] == CLMutableDictionaryClass)
    [self error:@"%s: %s must be implemented by subclass",
	  object_getClassName(self), sel_getName(_cmd)];
  return [super read:stream];
}

-(void) write:(CLStream *) stream
{
  if ([self class] == CLDictionaryClass || [self class] == CLMutableDictionaryClass)
    [self error:@"%s: %s must be implemented by subclass",
	  object_getClassName(self), sel_getName(_cmd)];
  [super write:stream];
  return;
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

-(CLUInteger) hash
{
  [self error:@"%s: %s must be implemented by subclass",
        object_getClassName(self), sel_getName(_cmd)];
  return 0;
}

@end
