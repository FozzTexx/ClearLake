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

@interface CLDictionary:CLObject <CLCopying, CLMutableCopying, CLPropertyList>
{
  void *dictionaryData;
  BOOL caseInsensitiveFlag;
}

+(id) dictionary;
+(id) dictionaryWithObjectsAndKeys:(id) firstObject, ...;

-(id) initAsCaseInsensitive:(BOOL) caseFlag;
-(id) initFromDictionary:(CLDictionary *) aDict;
-(id) initWithObjectsAndKeys:(id) firstObject, ...;
-(id) initWithObject:(id) firstObject andVA:(va_list) ap_orig;
#if 0
-(id) initWithObjects:(id *) objects andKeys:(id *) keys count:(CLUInteger) count;
#endif

-(BOOL) isCaseInsensitive;
-(void) setCaseInsensitive:(BOOL) caseFlag;
-(CLString *) description;
-(CLString *) encodeXML;

@end

@protocol CLDictionarySubclass <CLArchiving>
-(id) initWithObjects:(id *) objects andKeys:(id *) keys count:(CLUInteger) count
      caseInsensitive:(BOOL) caseFlag;
-(CLUInteger) count;
-(id) objectForKey:(id) aKey;
-(CLArray *) allKeys;
-(CLArray *) allValues;
-(CLUInteger) hash;
@end

@interface CLDictionary (CLSubclassMethods) <CLDictionarySubclass>
-(id) objectForCaseInsensitiveString:(CLString *) aKey;
@end

#endif /* _CLDICTIONARY_H */
