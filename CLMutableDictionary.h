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

#ifndef _CLMUTABLEDICTIONARY_H
#define _CLMUTABLEDICTIONARY_H

#import <ClearLake/CLDictionary.h>

@interface CLMutableDictionary:CLDictionary <CLCopying>
-(void) addEntriesFromDictionary:(CLDictionary *) otherDictionary;
@end

@protocol CLMutableDictionarySubclass
-(void) setObject:(id) anObject forKey:(id) aKey;
-(void) removeObjectForKey:(id) aKey;
-(void) removeAllObjects;
-(id) initWithSize:(CLUInteger) size caseInsensitive:(BOOL) caseFlag;
@end

@interface CLMutableDictionary (CLSubclassMethods) <CLMutableDictionarySubclass>
-(void) setObject:(id) anObject forCaseInsensitiveString:(CLString *) aString;
-(void) removeObjectForCaseInsensitiveString:(CLString *) aString;
@end

#endif /* _CLMUTABLEDICTIONARY_H */
