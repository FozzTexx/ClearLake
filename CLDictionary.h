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

#ifndef _CLDICTIONARY_H
#define _CLDICTIONARY_H

#import <ClearLake/CLObject.h>

@class CLString, CLArray, CLHashTable;

@interface CLDictionary:CLObject <CLCopying, CLMutableCopying, CLPropertyList, CLArchiving>
{
  CLHashTable *table;
  CLUInteger _hash;
  CLArray *_keys;
}

+(id) dictionary;
+(id) dictionaryWithObjectsAndKeys:(id) firstObject, ...;

-(id) init;
-(id) initWithSize:(CLUInteger) size;
-(id) initFromDictionary:(CLDictionary *) aDict;
-(id) initWithObjects:(id *) objects forKeys:(id *) keys count:(CLUInteger) count;
-(id) initWithObjectsAndKeys:(id) firstObject, ...;
-(void) dealloc;

-(id) objectForKey:(id) aKey;
-(id) objectForCaseInsensitiveString:(CLString *) aString;
-(CLArray *) allKeys;
-(CLArray *) allKeysForObject:(id) anObject;
-(CLArray *) allValues;
-(CLUInteger) count;
-(CLString *) description;
-(CLString *) encodeXML;
			
@end

#endif /* _CLDICTIONARY_H */
