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

#ifndef _CLDICTIONARY_H
#define _CLDICTIONARY_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLHashTable.h>

@class CLString, CLArray;

typedef struct {
  CLHashTable *table;
  CLUInteger _hash;
  CLArray *_keys, *_values;
} CLDictionaryStorage;

@interface CLDictionary:CLObject <CLCopying, CLMutableCopying, CLPropertyList, CLArchiving>
{
  void *dictionaryData;
}

+(id) dictionary;
+(id) dictionaryWithObjectsAndKeys:(id) firstObject, ...;

-(id) initWithSize:(CLUInteger) size;
-(id) initFromDictionary:(CLDictionary *) aDict;
-(id) initWithObjectsAndKeys:(id) firstObject, ...;

-(id) objectForCaseInsensitiveString:(CLString *) aString;
-(CLArray *) allKeys;
-(CLArray *) allKeysForObject:(id) anObject;
-(CLArray *) allValues;
-(CLUInteger) count;
-(CLString *) description;
-(CLString *) encodeXML;

@end

@protocol CLDictionarySubclass
-(id) initWithObjects:(id *) objects forKeys:(id *) keys count:(CLUInteger) count;
-(id) read:(CLStream *) stream;
-(void) write:(CLStream *) stream;
-(CLUInteger) count;
-(id) objectForKey:(id) aKey;
-(CLArray *) allKeys;
-(CLArray *) allValues;
-(id) objectForCaseInsensitiveString:(CLString *) aKey;
@end

@interface CLDictionary (CLSubclassMethods) <CLDictionarySubclass>
@end

@interface CLInternalDictionary:CLDictionary
@end

extern void *CLInternalDictionaryInitStorage(CLUInteger size);
extern void CLInternalDictionaryDeallocStorage(CLDictionaryStorage *storage);

#endif /* _CLDICTIONARY_H */
