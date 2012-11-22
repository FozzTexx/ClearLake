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

/* Don't call these functions. These are nasty yucky things that I'm
   doing to try to speed up strings. They make assumptions about the 4
   classes that make up the CLString class cluster. Because I'm using
   these you probably can't subclass CLString, but why would you want
   to anyway? */

#ifndef _CLSTRINGFUNCTIONS_H
#define _CLSTRINGFUNCTIONS_H

#import <ClearLake/CLString.h>

typedef struct {
  unichar *str;
  int maxLen;
  char *utf8;
  CLUInteger hash;
  BOOL hashSet:1;
} CLStringStorage;

extern Class CLStringClass, CLUTF8StringClass, CLConstantStringClass,
  CLConstantUnicodeStringClass, CLMutableStringClass;

void CLCacheStringClasses();
CLUInteger CLStringHash(CLString *aString);
CLStringStorage *CLStorageForString(CLString *aString);
CLComparisonResult CLStringCompare(CLString *string1, CLString *string2,
				   CLStringCompareOptions options, CLRange range);
BOOL CLStringFindCharacterFromSet(CLString *aString, CLCharacterSet *aSet,
				  CLStringCompareOptions options, CLRange searchRange,
				  CLRange *resultRange);
int CLStringConvertEncoding(const char *source, CLUInteger slen, CLStringEncoding sEncoding,
			    char **dest, CLUInteger *dlen, CLStringEncoding dEncoding,
			    BOOL allowLossy);
BOOL CLStringReplaceCharacters(CLString *dest, CLRange aRange, CLString *source);

#endif /* _CLSTRINGFUNCTIONS_H */
