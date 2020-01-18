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

#define _GNU_SOURCE
#include <wchar.h>

#import "CLStringFunctions.h"
#import "CLConstantUnicodeString.h"
#import "CLUTF8String.h"
#import "CLMutableString.h"
#import "CLHashTable.h"
#import "CLCharacterSet.h"
#import "CLClassConstants.h"

#include <stdlib.h>
#include <iconv.h>
#include <errno.h>
#include <wctype.h>
#include <string.h>

BOOL CLCheckStringClass(id anObject)
{
  unistr *ustr = (unistr *) anObject;
  

  if (ustr->_reserved == CLUTF8StringClass ||
      ustr->_reserved == CLConstantStringClass)
    [anObject swizzle];

  if (ustr->_reserved == CLStringClass ||
      ustr->_reserved == CLMutableStringClass ||
      ustr->_reserved == CLConstantUnicodeStringClass)
    return YES;

  if (ustr->_reserved == CLImmutableStackStringClass ||
      ustr->_reserved == CLMutableStackStringClass)
    return YES;
  
  return NO;
}

CLStringStorage *CLStorageForString(CLString *aString)
{
  unistr *ustr;


  ustr = (unistr *) aString;
  if (!ustr->str || ustr->_reserved == CLImmutableStackStringClass ||
      !CLCheckStringClass(aString))
    return NULL;
  return ((void *) ustr->str) - sizeof(CLStringStorage);
}

void *CLStringAllocateBuffer(void *old, CLUInteger length, char *utf8, id self)
{
  void *buf;
  CLUInteger blen;
  CLStringStorage *stor;


  blen = length * sizeof(unichar) + sizeof(CLStringStorage);
  if (old)
    buf = realloc(old - sizeof(CLStringStorage), blen);
  else
    buf = calloc(blen, 1);
    
  stor = buf;
  stor->maxLen = length;
  if (utf8)
    stor->utf8 = utf8;
  return buf + sizeof(CLStringStorage);
}

char *CLStringFreeBuffer(void *old)
{
  CLStringStorage *stor;
  char *utf8 = NULL;
#if DEBUG_LEAK
  id self = nil;
#endif


  if (old) {
    stor = old - sizeof(CLStringStorage);
    utf8 = stor->utf8;
    free(stor);
  }
  return utf8;
}

const char *CLUTF8ForString(CLString *aString)
{
  CLStringStorage *stor;
  char *buf;
  CLUInteger blen;
  unistr *ustr;


  if (!(stor = CLStorageForString(aString)))
    return "";
  
  ustr = (unistr *) aString;
  if (!stor->utf8) {
    CLStringConvertEncoding((char *) ustr->str, ustr->len * sizeof(unichar),
			    CLUnicodeStringEncoding,
			    &buf, &blen, CLUTF8StringEncoding, NO);
    buf[blen] = 0;
    stor->utf8 = buf;
  }

  return stor->utf8;
}

CLRange CLStringRangeOfString(CLString *inString, CLString *searchString,
			      CLStringCompareOptions mask, CLRange range)
{
  CLUInteger ssLen;
  unichar *myBuf, *myPos, *myEnd, *ssBuf, *ssPos, *ssEnd;
  unistr *istr, *sstr;


  CLCheckStringClass(inString);
  istr = (unistr *) inString;
  if (CLMaxRange(range) > istr->len)
    [inString error:@"Range exceeds length"];
    
  CLCheckStringClass(searchString);
  sstr = (unistr *) searchString;
  ssLen = sstr->len;
  if (ssLen <= range.length) {
    CLStorageForString(inString);
    CLStorageForString(searchString);
    myBuf = istr->str + range.location;
    myEnd = myBuf + range.length - ssLen;
    ssBuf = sstr->str;
    ssEnd = ssBuf + ssLen;

    if (mask & CLBackwardsSearch) {
      myEnd += ssLen;
      myBuf += ssLen;
      if (mask & CLCaseInsensitiveSearch) {
	for (; myBuf <= myEnd; myEnd--) {
	  for (myPos = myEnd - ssLen, ssPos = ssBuf;
	       ssPos < ssEnd && towlower(*myPos) == towlower(*ssPos);
	       myPos++, ssPos++)
	    ;
	  if (!(ssEnd - ssPos))
	    return CLMakeRange(myEnd - istr->str - ssLen, ssLen);
	}
      }
      else {
	for (; myBuf <= myEnd; myEnd--) {
	  for (myPos = myEnd - ssLen, ssPos = ssBuf;
	       ssPos < ssEnd && *myPos == *ssPos;
	       myPos++, ssPos++)
	    ;
	  if (!(ssEnd - ssPos))
	    return CLMakeRange(myEnd - istr->str - ssLen, ssLen);
	}
      }
    }
    else {
      if (mask & CLCaseInsensitiveSearch) {
	for (; myBuf <= myEnd; myBuf++) {
	  for (myPos = myBuf, ssPos = ssBuf;
	       ssPos < ssEnd && towlower(*myPos) == towlower(*ssPos);
	       myPos++, ssPos++)
	    ;
	  if (!(ssEnd - ssPos))
	    return CLMakeRange(myBuf - istr->str, ssLen);
	}
      }
      else {
	for (; myBuf <= myEnd; myBuf++) {
	  for (myPos = myBuf, ssPos = ssBuf;
	       ssPos < ssEnd && *myPos == *ssPos;
	       myPos++, ssPos++)
	    ;
	  if (!(ssEnd - ssPos))
	    return CLMakeRange(myBuf - istr->str, ssLen);
	}
      }
    }
  }
  
  return CLMakeRange(CLNotFound, 0);
}

void CLStringAppendCharacter(CLString *aString, unichar aChar, id self)
{
  CLStringStorage *stor;
  unistr *ustr;


  stor = CLStorageForString(aString);
  ustr = (unistr *) aString;
  if (!stor || ustr->len+1 > stor->maxLen)
    ustr->str = CLStringAllocateBuffer(ustr->str, (stor ? stor->maxLen : 0) + 32, NULL, self);
  ustr->str[ustr->len] = aChar;
  ustr->len++;
  return;
}

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
  case CLEBCDICStringEncoding:
    return "EBCDIC-US";
  case CLPETSCIIUpperStringEncoding:
    return "PETSCII-U";
  case CLPETSCIILowerStringEncoding:
    return "PETSCII-L";
  case CPCP437StringEncoding:
    return "CP437";
  default:
    return NULL;
  }

  return NULL;
}

CLComparisonResult CLStringCompare(CLString *string1, CLString *string2,
				   CLStringCompareOptions options, CLRange range)
{
  if (string1 == string2)
    return CLOrderedSame;
  
  if (!string1 && string2)
    return CLOrderedAscending;
  if (string1 && !string2)
    return CLOrderedDescending;
  if ((!string1 && !string2) || (string1 == string2))
    return CLOrderedSame;
  
  if (CLMaxRange(range) > ((unistr *) string1)->len)
    [string1 error:@"%s range beyond length of string\n", [[string1 class] className]];
  
  if (!CLCheckStringClass(string1) || !CLCheckStringClass(string2))
    /* FIXME - deal with it */
    return 0;

  return CLUnistrCompare((unistr *) string1, (unistr *) string2, options, range);
}

BOOL CLStringFindCharacterFromSet(CLString *aString, CLCharacterSet *aSet,
				  CLStringCompareOptions options, CLRange searchRange,
				  CLRange *resultRange)
{
  CLUInteger i;
  unistr *ustr;


  ustr = (unistr *) aString;
  if (CLMaxRange(searchRange) > ustr->len)
    [aString error:@"%@ range beyond length of string\n", [[aString class] className]];

  if (!CLCheckStringClass(aString))
    /* FIXME - deal with it */
    return 0;

  CLStorageForString(aString);
  
  if (options & CLBackwardsSearch) {
    for (i = searchRange.location + searchRange.length; i > searchRange.location; i--)
      if ([aSet characterIsMember:ustr->str[i-1]] ^ (!!(options & CLInvertedSearch)))
	break;
    if (i > searchRange.location) {
      *resultRange = CLMakeRange(i-1, 1);
      return YES;
    }
  }
  else {
    for (i = searchRange.location; i < searchRange.location + searchRange.length; i++)
      if ([aSet characterIsMember:ustr->str[i]] ^ (!!(options & CLInvertedSearch)))
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
#if DEBUG_LEAK
  id self = nil;
#endif

  
  ilen = slen;
  olen = ilen * sizeof(unichar);
  ibuf = (char *) source;
  *dest = bbuf = obuf = malloc(olen + sizeof(unichar));
  senc = CLStringEncodingForIconv(sEncoding);
  denc = CLStringEncodingForIconv(dEncoding);
  if (allowLossy) {
    p = alloca(strlen(denc) + 19);
    strcpy(p, denc);
    strcat(p, "//TRANSLIT//IGNORE");
    denc = p;
  }

  if ((cd = iconv_open(denc, senc)) != (iconv_t) -1) {
    while ((iconv(cd, &ibuf, &ilen, &obuf, &olen)) == (size_t) -1) {
      if (errno == EILSEQ) {
	err++;
	if (sEncoding == CLUnicodeStringEncoding) {
	  ibuf += 4;
	  ilen -= 4;
	}
	else {
	  ibuf++;
	  ilen--;
	}
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

BOOL CLStringReplaceCharacters(CLString *dest, CLRange aRange, unichar *src, CLUInteger slen)
{
  CLUInteger newlen;
  CLStringStorage *destStor;
  unistr *udest;
#if DEBUG_LEAK
  id self = nil;
#endif


  if (CLMaxRange(aRange) > ((unistr *) dest)->len)
    [dest error:@"%@ range beyond length of string", [[dest class] className]];
  
  if (!CLCheckStringClass(dest))
    /* FIXME - deal with it */
    return 0;

  udest = (unistr *) dest;
  if (udest->_reserved == CLConstantUnicodeStringClass)
    [dest error:@"Cannot replace characters in constant string"];

  destStor = CLStorageForString(dest);
  
  newlen = udest->len - aRange.length + slen;
  if (!destStor || newlen > destStor->maxLen) {
    if (destStor)
      destStor = realloc(destStor, newlen * sizeof(unichar) + sizeof(CLStringStorage));
    else
      destStor = calloc(newlen * sizeof(unichar) + sizeof(CLStringStorage), 1);
    destStor->maxLen = newlen;
    udest->str = ((void *) destStor) + sizeof(CLStringStorage);
  }

  CLUnistrReplaceCharacters((unistr *) dest, aRange, src, slen);
  
  if (destStor->utf8)
    free(destStor->utf8);
  destStor->utf8 = NULL;

  destStor->hashSet = NO;
  
  return YES;
}

BOOL CLStringReplaceString(CLString *dest, CLRange aRange, CLString *source)
{
  unistr *usrc;

  
  if (source && !CLCheckStringClass(source))
    /* FIXME - deal with it */
    return 0;

  usrc = (unistr *) source;
  return CLStringReplaceCharacters(dest, aRange,
				   source ? usrc->str : NULL, source ? usrc->len : 0);
}

CLUInteger CLStringHash(CLString *aString)
{
  CLStringStorage *stor;
  unichar *buf;
  int i;
  unistr *ustr;
  CLUInteger hash;


  if (!CLCheckStringClass(aString))
    [aString error:@"Unable to create hash"];

  ustr = (unistr *) aString;
  stor = CLStorageForString(aString);
  if (stor && stor->hashSet)
    hash = stor->hash;
  else {
    /* I need a case insensitive hash to use with CLDictionary for
       case insensitive key lookups. I can't see any reason to store
       both a regular hash and a lowercase hash so I'm only generating
       the lowercase hash. The only thing that is important is that
       the hash is always the same for the same string, which it will
       be. The downside is the overhead of converting the whole string
       to lowercase to hash it. */
    if (!(buf = alloca(sizeof(unichar) * ustr->len)))
      [aString error:@"Unable to allocate memory"];
    wmemmove(buf, ustr->str, ustr->len);
    for (i = 0; i < ustr->len; i++)
      buf[i] = towlower(buf[i]);
    hash = CLHashBytes(buf, sizeof(unichar) * ustr->len, 0);
    
    if (stor) {
      stor->hash = hash;
      stor->hashSet = YES;
    }
  }

  return hash;
}

extern CLComparisonResult CLUnistrCompare(unistr *string1, unistr *string2,
					  CLStringCompareOptions options, CLRange range)
{
  CLUInteger max;
  int cmp = 0;

  
  max = range.length < string2->len ? range.length : string2->len;

  if (max) {
    if (options & CLCaseInsensitiveSearch)
      cmp = wcsncasecmp(&string1->str[range.location], string2->str, max);
    else
      cmp = wcsncmp(&string1->str[range.location], string2->str, max);
  }

  if (!cmp) {
    if (max < range.length)
      cmp = CLOrderedDescending;
    else if (max < string2->len)
      cmp = CLOrderedAscending;
    return cmp;
  }

  if (cmp < 0)
      return CLOrderedAscending;
  if (cmp > 0)
    return CLOrderedDescending;

  return CLOrderedSame;
}

void CLUnistrReplaceCharacters(unistr *dest, CLRange aRange, unichar *src, CLUInteger slen)
{
  CLUInteger newlen;


  if (CLMaxRange(aRange) > dest->len) {
    fprintf(stderr, "CLUnistrReplaceCharacters: range beyond length");
    abort();
  }
  
  newlen = dest->len - aRange.length + slen;

#if 0
  /* FIXME - find a way to realloc */
  if (newlen > destStor->maxLen) {
    destStor->maxLen = newlen;
    if (destStor->str)
      destStor->str = realloc(destStor->str, destStor->maxLen * sizeof(unichar));
    else
      destStor->str = malloc(destStor->maxLen * sizeof(unichar));
  }
#endif

  if (dest->len - CLMaxRange(aRange))
    wmemmove(&dest->str[aRange.location + slen],
	     &dest->str[CLMaxRange(aRange)],
	     dest->len - CLMaxRange(aRange));
  if (slen)
    wmemmove(&dest->str[aRange.location], src, slen);
  dest->len = newlen;
  return;
}

void CLUnistrReplace(unistr *dest, CLRange aRange, unistr *src)
{
  CLUnistrReplaceCharacters(dest, aRange, src ? src->str : NULL, src ? src->len : 0);
  return;
}

/* This doesn't do much more than the typecast. It just makes sure to
   swizzle a string that isn't currently in unicode format. */
unistr *CLStringToUnistr(CLString *aString)
{
  CLCheckStringClass(aString);
  return (unistr *) aString;
}
