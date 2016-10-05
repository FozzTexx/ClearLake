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

#import "CLMutableDictionary.h"
#import "CLString.h"
#import "CLArray.h"
#import "CLHashTable.h"
#import "CLClassConstants.h"

#include <stdlib.h>

@implementation CLMutableDictionary

-(void) setObject:(id) anObject forKey:(id) aKey
{
  id oldObject, oldObject2;
  

  if (!anObject || !aKey)
    [self error:@"Can't set nil objects!"];

  [anObject retain];
  if ((oldObject = CLHashTableKeyForKey(table, aKey, [aKey hash], @selector(isEqual:)))) {
    oldObject2 = CLHashTableRemoveDataForKey(table, aKey, [aKey hash], @selector(isEqual:));
    [oldObject release];
    [oldObject2 release];
  }
  aKey = [aKey copy];
  CLHashTableSetData(table, anObject, aKey, [aKey hash]);

  _hash = 0;
  [_keys release];
  _keys = nil;
  [_values release];
  _values = nil;
  return;
}
  
-(void) setObject:(id) anObject forCaseInsensitiveString:(CLString *) aString
{
  if (!anObject || !aString)
    [self error:@"Can't set nil objects!"];

  [anObject retain];
  [aString retain];
  [self removeObjectForCaseInsensitiveString:aString];
  [self setObject:anObject forKey:aString];
  [anObject release];
  [aString release];
  
  return;
}

-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField
{
  [self setObject:anObject forKey:aField];
  return;
}

-(void) removeObjectForCaseInsensitiveString:(CLString *) aKey
{
  id oldKey, oldObject;


  if ((oldKey = CLHashTableKeyForKey(table, aKey, [aKey hash],
				     @selector(isEqualToCaseInsensitiveString:)))) {
    oldObject = CLHashTableRemoveDataForKey(table, oldKey, [oldKey hash],
					    @selector(isEqualToCaseInsensitiveString:));
    [oldKey release];
    [oldObject release];

    _hash = 0;
    [_keys release];
    _keys = nil;
    [_values release];
    _values = nil;
  }

  return;
}

-(void) removeObjectForKey:(id) aKey
{
  id oldKey, oldObject;


  if ((oldKey = CLHashTableKeyForKey(table, aKey, [aKey hash], @selector(isEqual:)))) {
    oldObject = CLHashTableRemoveDataForKey(table, oldKey, [oldKey hash], @selector(isEqual:));
    [oldKey release];
    [oldObject release];

    _hash = 0;
    [_keys release];
    _keys = nil;
    [_values release];
    _values = nil;
  }

  return;
}

-(void) addEntriesFromDictionary:(CLDictionary *) otherDictionary
{
  CLArray *anArray;
  int i, j;
  id aKey;


  anArray = [otherDictionary allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aKey = [anArray objectAtIndex:i];
    [self setObject:[otherDictionary objectForKey:aKey] forKey:aKey];
  }

  return;
}

-(void) removeAllObjects
{
  CLUInteger i;
  id *keys;
  id oldObject;
  

  if (table->count) {
    if (!(keys = alloca(sizeof(id) * table->count)))
      [self error:@"Unable to allocate memory"];
    CLHashTableGetKeys(table, keys);
    for (i = 0; i < table->count; i++) {
      oldObject = CLHashTableRemoveDataForKey(table, keys[i], [keys[i] hash],
					      @selector(isEqual:));
      [keys[i] release];
      [oldObject release];
    }
  
    _hash = 0;
    [_keys release];
    _keys = nil;
    [_values release];
    _values = nil;
  }

  return;
}

/* Doing an extra retain & autorelease on allKeys because we are
   mutable. If we get modified the array will be released unexpectedly
   and it should stick around until the caller is done with it. */
-(CLArray *) allKeys
{
  return [[[super allKeys] retain] autorelease];
}

#if DEBUG_RETAIN
#undef copy
#undef retain
#include <stdio.h>
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLMutableDictionary *aDict = [self mutableCopy];
  extern int CLLeakPrint;


  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx copy %s - 0x%lx %s:%i %i\n",
	    (unsigned long) self, className, (unsigned long) retainer,
	    file, line, [self retainCount] + 1);
    CLLeakPrint = pl;
  }

  aDict->isa = CLDictionaryClass;
  return aDict;
}
#else
-(id) copy
{
  CLMutableDictionary *aDict = [self mutableCopy];


  aDict->isa = CLDictionaryClass;
  return aDict;
}
#endif

@end
