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

/* Don't call these functions. These are nasty yucky things that I'm
   doing to try to speed up strings. They make assumptions about the 4
   classes that make up the CLString class cluster. Because I'm using
   these you probably can't subclass CLString, but why would you want
   to anyway? */

#ifndef _CLSTRINGFUNCTIONS_H
#define _CLSTRINGFUNCTIONS_H

#import <ClearLake/CLString.h>
#import <ClearLake/CLHashTable.h>

#include <stdlib.h>
#include <wctype.h>

/* The _reserved field is to match the isa field in CLString which
   will be ignored in all the unistr functions. Declaring it this way
   makes it possible to pass a CLString to the unistr functions. */
typedef struct {
  void *_reserved;
  unichar *str;
  CLUInteger len;
} unistr;

typedef struct {
  int maxLen;
  char *utf8;
  CLUInteger hash;
  BOOL hashSet:1;
} CLStringStorage;

extern CLStringStorage *CLStorageForString(CLString *aString);

extern BOOL CLCheckStringClass(id anObject);

/* Functions to hide CLStringStorage from objects */
extern void *CLStringAllocateBuffer(void *old, CLUInteger length, char *utf8, id self);
extern char *CLStringFreeBuffer(void *old);
extern const char *CLUTF8ForString(CLString *aString);
extern CLRange CLStringRangeOfString(CLString *inString, CLString *searchString,
				     CLStringCompareOptions mask, CLRange range);
extern void CLStringAppendCharacter(CLString *aString, unichar aChar, id self);

extern void CLCacheStringClasses();
extern CLComparisonResult CLStringCompare(CLString *string1, CLString *string2,
				   CLStringCompareOptions options, CLRange range);
extern BOOL CLStringFindCharacterFromSet(CLString *aString, CLCharacterSet *aSet,
				  CLStringCompareOptions options, CLRange searchRange,
				  CLRange *resultRange);
extern int CLStringConvertEncoding(const char *source, CLUInteger slen,
				   CLStringEncoding sEncoding,
				   char **dest, CLUInteger *dlen, CLStringEncoding dEncoding,
				   BOOL allowLossy);
extern BOOL CLStringReplaceCharacters(CLString *dest, CLRange aRange,
				      unichar *src, CLUInteger slen);
extern BOOL CLStringReplaceString(CLString *dest, CLRange aRange, CLString *source);
extern CLUInteger CLStringHash(CLString *aString);

extern CLComparisonResult CLUnistrCompare(unistr *string1, unistr *string2,
					  CLStringCompareOptions options, CLRange range);
extern void CLUnistrReplaceCharacters(unistr *dest, CLRange aRange,
				      unichar *src, CLUInteger slen);
extern void CLUnistrReplace(unistr *dest, CLRange aRange, unistr *src);
extern unistr *CLStringToUnistr(CLString *aString);

#endif /* _CLSTRINGFUNCTIONS_H */
