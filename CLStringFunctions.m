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

#define _GNU_SOURCE
#include <wchar.h>

#import "CLStringFunctions.h"
#import "CLConstantUnicodeString.h"
#import "CLUTF8String.h"
#import "CLMutableString.h"
#import "CLHashTable.h"
#import "CLCharacterSet.h"

#include <stdlib.h>
#include <iconv.h>
#include <errno.h>
#include <wctype.h>
#include <string.h>

Class CLStringClass = nil, CLUTF8StringClass = nil, CLConstantStringClass = nil,
  CLConstantUnicodeStringClass = nil, CLMutableStringClass = nil;

typedef struct {
  @defs(CLString)
} *CLStr;

const char *CLStringEncodingForIconv(CLStringEncoding encoding)
{
  switch (encoding) {
  case CLASCIIStringEncoding:
    return "ASCII";
  case CLNEXTSTEPStringEncoding:
    return "NEXTSTEP";
  case CLJapaneseEUCStringEncoding:
    return "EUC-JISX0213";
  case CLUTF8StringEncoding:
    return "UTF-8";
  case CLISOLatin1StringEncoding:
    return "ISO-8859-1";
  case CLISOLatin2StringEncoding:
    return "ISO-8859-2";
  case CLISOLatin7StringEncoding:
    return "ISO-8859-7";
  case CLShiftJISStringEncoding:
    return "SHIFT_JIS";
  case CLUnicodeStringEncoding:
    return "WCHAR_T";
  case CLWindowsCP1250StringEncoding:
    return "CP1250";
  case CLWindowsCP1251StringEncoding:
    return "CP1251";
  case CLWindowsCP1252StringEncoding:
    return "CP1252";
  case CLWindowsCP1253StringEncoding:
    return "CP1253";
  case CLWindowsCP1254StringEncoding:
    return "CP1254";
  case CLISO2022JPStringEncoding:
    return "ISO-2022-JP";
  case CLMacOSRomanStringEncoding:
    return "MACINTOSH";
  case CLUTF16BigEndianStringEncoding:
    return "UTF-16BE";
  case CLUTF16LittleEndianStringEncoding:
    return "UTF-16LE";
  case CLUTF32StringEncoding:
    return "UTF-32";
  case CLUTF32BigEndianStringEncoding:
    return "UTF-32BE";
  case CLUTF32LittleEndianStringEncoding:
    return "UTF-32LE";
  case CLKOI8StringEncoding:
    return "KOI8";
  default:
    return NULL;
  }

  return NULL;
}

void CLCacheStringClasses()
{
  if (!CLStringClass) {
    CLStringClass = [CLString class];
    CLUTF8StringClass = [CLUTF8String class];
    CLConstantStringClass = [CLConstantString class];
    CLConstantUnicodeStringClass = [CLConstantUnicodeString class];
    CLMutableStringClass = [CLMutableString class];
  }
  
  return;
}
  
CL_INLINE BOOL CLCheckStringClass(id anObject)
{
  CLStr aString = (CLStr) anObject;
  

  if (!CLStringClass)
    CLCacheStringClasses();
  
  if (aString->isa == CLUTF8StringClass ||
      aString->isa == CLConstantStringClass)
    [anObject swizzle];

  if (aString->isa == CLStringClass ||
      aString->isa == CLMutableStringClass ||
      aString->isa == CLConstantUnicodeStringClass)
    return YES;

  return NO;
}

CLStringStorage *CLStorageForString(CLString *aString)
{
  CLStr str = (CLStr) aString;


  if (!CLCheckStringClass(aString))
    return NULL;
  return str->data;
}
  
CLUInteger CLStringHash(CLString *aString)
{
  CLStringStorage *stor;
  CLStr str = (CLStr) aString;
  unichar *buf;
  int i;


  if (!CLCheckStringClass(aString))
    [aString error:@"Unable to create hash"];

  stor = str->data;
  if (!stor->hashSet) {
    /* I need a case insensitive hash to use with CLDictionary for
       case insensitive key lookups. I can't see any reason to store
       both a regular hash and a lowercase hash so I'm only generating
       the lowercase hash. The only thing that is important is that
       the hash is always the same for the same string, which it will
       be. The downside is the overhead of converting the whole string
       to lowercase to hash it. */
    if (!(buf = malloc(sizeof(unichar) * str->len)))
      [aString error:@"Unable to allocate memory"];
    wmemmove(buf, stor->str, str->len);
    for (i = 0; i < str->len; i++)
      buf[i] = towlower(buf[i]);
    stor->hash = CLHashBytes(buf, sizeof(unichar) * str->len, 0);
    free(buf);
    
    stor->hashSet = YES;
  }
  return stor->hash;
}

CLComparisonResult CLStringCompare(CLString *string1, CLString *string2,
				   CLStringCompareOptions options, CLRange range)
{
  CLUInteger max;
  CLStringStorage *stor1, *stor2;
  int cmp = 0;
  CLStr str1 = (CLStr) string1, str2 = (CLStr) string2;


  if (string1 == string2)
    return CLOrderedSame;
  
  if (!string1 && string2)
    return CLOrderedAscending;
  if (string1 && !string2)
    return CLOrderedDescending;
  if ((!string1 && !string2) || (string1 == string2))
    return CLOrderedSame;
  
  if (CLMaxRange(range) > str1->len)
    [string1 error:@"%s range beyond length of string\n", [[string1 class] className]];
  
  if (!CLCheckStringClass(string1) || !CLCheckStringClass(string2))
    /* FIXME - deal with it */
    return 0;

  stor1 = str1->data;
  stor2 = str2->data;

  max = range.length < str2->len ? range.length : str2->len;

  if (max) {
    if (options & CLCaseInsensitiveSearch)
      cmp = wcsncasecmp(&stor1->str[range.location], stor2->str, max);
    else
      cmp = wcsncmp(&stor1->str[range.location], stor2->str, max);
  }

  if (!cmp) {
    if (max < range.length)
      cmp = CLOrderedDescending;
    else if (max < str2->len)
      cmp = CLOrderedAscending;
    return cmp;
  }

  if (cmp < 0)
      return CLOrderedAscending;
  if (cmp > 0)
    return CLOrderedDescending;

  return CLOrderedSame;
}

BOOL CLStringFindCharacterFromSet(CLString *aString, CLCharacterSet *aSet,
				  CLStringCompareOptions options, CLRange searchRange,
				  CLRange *resultRange)
{
  CLUInteger i;
  CLStringStorage *stor;
  CLStr str = (CLStr) aString;


  if (CLMaxRange(searchRange) > str->len)
    [aString error:@"%@ range beyond length of string\n", [[aString class] className]];

  if (!CLCheckStringClass(aString))
    /* FIXME - deal with it */
    return 0;

  stor = str->data;
  
  if (options & CLBackwardsSearch) {
    for (i = searchRange.location + searchRange.length; i > searchRange.location; i--)
      if ([aSet characterIsMember:stor->str[i-1]] ^ (!!(options & CLInvertedSearch)))
	break;
    if (i > searchRange.location) {
      *resultRange = CLMakeRange(i-1, 1);
      return YES;
    }
  }
  else {
    for (i = searchRange.location; i < searchRange.location + searchRange.length; i++)
      if ([aSet characterIsMember:stor->str[i]] ^ (!!(options & CLInvertedSearch)))
	break;
    if (i < searchRange.location + searchRange.length) {
      *resultRange = CLMakeRange(i, 1);
      return YES;
    }
  }

  *resultRange = CLMakeRange(CLNotFound, 0);
  return NO;
}

/* Always allocates one extra unichar at the end so the buffer can be
   used as a null terminated string. Does *not* actually append the
   null though! */
int CLStringConvertEncoding(const char *source, CLUInteger slen, CLStringEncoding sEncoding,
			    char **dest, CLUInteger *dlen, CLStringEncoding dEncoding,
			    BOOL allowLossy)
{
  iconv_t cd;
  size_t ilen, olen;
  char *ibuf, *obuf, *bbuf;
  int err = 0;
  const char *senc, *denc;
  char *p = NULL;

  
  ilen = slen;
  olen = ilen * sizeof(unichar);
  ibuf = (char *) source;
  *dest = bbuf = obuf = malloc(olen + sizeof(unichar));
  senc = CLStringEncodingForIconv(sEncoding);
  denc = CLStringEncodingForIconv(dEncoding);
  if (allowLossy) {
    p = malloc(strlen(denc) + 19);
    strcpy(p, denc);
    strcat(p, "//TRANSLIT//IGNORE");
    denc = p;
  }

  if ((cd = iconv_open(denc, senc)) != (iconv_t) -1) {
    while ((iconv(cd, &ibuf, &ilen, &obuf, &olen)) == (size_t) -1) {
      if (errno == EILSEQ) {
	err++;
	ibuf++;
	ilen--;
      }
      else if (errno == E2BIG) {
	olen = obuf - bbuf;
	bbuf = realloc(bbuf, olen + 256 + sizeof(unichar));
	obuf = bbuf + olen;
	olen = 256;
      }
      else
	break;
    }
    *dlen = obuf - bbuf;
    *dest = bbuf;
    iconv_close(cd);
  }
  else
    err++;

  if (p)
    free(p);

#if 0
  if (dEncoding == CLUnicodeStringEncoding) {
    unichar *buf;
    int i, j;
    char *newbuf;


    buf = (unichar *) bbuf;
    for (i = 0, j = *dlen / 4; i < j; i++)
      if (buf[i] >= 0x80 && buf[i] < 0xa0)
	break;
    if (i < j) {
      //fprintf(stderr, "Likely double UTF8 encoded\n");

      newbuf = malloc(j);
      for (i = 0; i < j; i++) {
	if (buf[i] > 0xff)
	  break;
	newbuf[i] = buf[i];
      }
      if (i == j) {
	CLStringConvertEncoding(newbuf, j, CLUTF8StringEncoding,
				dest, dlen, CLUnicodeStringEncoding, allowLossy);
	free(bbuf);
      }
      free(newbuf);
    }
  }
#endif
  
  return err;
}

BOOL CLStringReplaceCharacters(CLString *dest, CLRange aRange, CLString *source)
{
  CLUInteger newlen, slen;
  CLStringStorage *stor1, *stor2 = NULL;
  CLStr str1 = (CLStr) dest, str2 = (CLStr) source;

  
  if (CLMaxRange(aRange) > str1->len)
    [dest error:@"%@ range beyond length of string", [[dest class] className]];
  
  if (!CLCheckStringClass(dest) || (source && !CLCheckStringClass(source)))
    /* FIXME - deal with it */
    return 0;

  if (str1->isa == CLConstantUnicodeStringClass)
    [dest error:@"Cannot replace characters in constant string"];
  
  stor1 = str1->data;
  if (source) {
    stor2 = str2->data;
    slen = str2->len;
  }
  else
    slen = 0;
  
  newlen = str1->len - aRange.length + slen;
  if (newlen > stor1->maxLen) {
    stor1->maxLen = newlen;
    if (stor1->str)
      stor1->str = realloc(stor1->str, stor1->maxLen * sizeof(unichar));
    else
      stor1->str = malloc(stor1->maxLen * sizeof(unichar));
  }
  if (str1->len - CLMaxRange(aRange))
    wmemmove(&stor1->str[aRange.location + slen],
	     &stor1->str[CLMaxRange(aRange)],
	     str1->len - CLMaxRange(aRange));
  if (slen)
    wmemmove(&stor1->str[aRange.location], stor2->str, slen);

  str1->len = newlen;
  
  if (stor1->utf8)
    free(stor1->utf8);
  stor1->utf8 = NULL;

  stor1->hashSet = NO;
  
  return YES;
}
