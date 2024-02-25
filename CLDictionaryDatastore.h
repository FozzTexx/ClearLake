/* Copyright 2024 by
 *   Chris Osborn <fozztexx@fozztexx.com>
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

#ifndef _CLDICTIONARYDATASTORE_H
#define _CLDICTIONARYDATASTORE_H

#import <ClearLake/CLDictionary.h>
#import <ClearLake/CLMutableDictionary.h>

typedef struct {
  CLHashTable *table;
  CLUInteger _hash;
  CLArray *_keys, *_values;
} CLDictionaryStorage;

@interface CLDictionaryDatastore:CLDictionary <CLDictionarySubclass>
@end

@interface CLMutableDictionaryDatastore:CLMutableDictionary <CLDictionarySubclass,
  CLMutableDictionarySubclass>
@end

#endif /* _CLDICTIONARYDATASTORE_H */
