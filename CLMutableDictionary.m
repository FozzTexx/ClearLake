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

#import "CLMutableDictionary.h"
#import "CLString.h"
#import "CLArray.h"
#import "CLHashTable.h"

#include <stdlib.h>

@implementation CLMutableDictionary

-(id) copy
{
  return [self mutableCopy];
}

-(void) setObject:(id) anObject forKey:(id) aKey
{
  id oldObject, oldObject2;
  

  if (!anObject)
    /* FIXME - raise an exception */
    return;

  [anObject retain];
  if ((oldObject = [table keyForKey:aKey hash:[aKey hash]])) {
    oldObject2 = [table removeDataForKey:aKey hash:[aKey hash]];
    [oldObject release];
    [oldObject2 release];
  }
  aKey = [aKey copy];
  [table setData:anObject forKey:aKey hash:[aKey hash]];

  _hash = 0;
  [_keys release];
  _keys = nil;
  return;
}
  
-(void) setObject:(id) anObject forCaseInsensitiveString:(CLString *) aString
{
  if (!anObject)
    /* FIXME - raise an exception */
    return;

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


  if ((oldKey = [table keyForKey:aKey hash:[aKey hash]
			   selector:@selector(isEqualToCaseInsensitiveString:)])) {
    oldObject = [table removeDataForKey:oldKey hash:[oldKey hash]];
    [oldKey release];
    [oldObject release];

    _hash = 0;
    [_keys release];
    _keys = nil;
  }

  return;
}

-(void) removeObjectForKey:(id) aKey
{
  id oldKey, oldObject;


  if ((oldKey = [table keyForKey:aKey hash:[aKey hash]])) {
    oldObject = [table removeDataForKey:oldKey hash:[oldKey hash]];
    [oldKey release];
    [oldObject release];

    _hash = 0;
    [_keys release];
    _keys = nil;
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
  CLUInteger i, len;
  id *keys;
  id oldObject;
  

  if ((len = [table count])) {
    if (!(keys = malloc(sizeof(id) * len)))
      [self error:@"Unable to allocate memory"];
    [table getKeys:keys];
    for (i = 0; i < len; i++) {
      oldObject = [table removeDataForKey:keys[i] hash:[keys[i] hash]];
      [keys[i] release];
      [oldObject release];
    }
    free(keys);
  }
  
  _hash = 0;
  [_keys release];
  _keys = nil;
  return;
}

/* Doing an extra retain & autorelease on allKeys because we are
   mutable. If we get modified the array will be released unexpectedly
   and it should stick around until the caller is done with it. */
-(CLArray *) allKeys
{
  return [[[super allKeys] retain] autorelease];
}

@end
