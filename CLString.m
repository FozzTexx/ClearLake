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

#define _GNU_SOURCE
#include <printf.h>

#import "CLString.h"
#import "CLEntities.h"
#import "CLStringFunctions.h"
#import "CLData.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLAutoreleasePool.h"
#import "CLMutableDictionary.h"
#import "CLNumber.h"
#import "CLPlaceholder.h"
#import "CLNull.h"
#import "CLMutableCharacterSet.h"
#import "CLStream.h"
#import "CLDecimalNumber.h"
#import "CLMutableData.h"
#import "CLConstantUnicodeString.h"
#import "CLDatetime.h"
#import "CLStackString.h"
#import "CLCSVDecoder.h"
#import "CLClassConstants.h"

#include <stdlib.h>
#include <wctype.h>
#include <ctype.h>
#include <features.h>
#include <string.h>

#define PATHSEP_CHAR	'/'
#define PATHSEP_STRING	@"/"

#define hexval(c) ({int _c = c; toupper(_c) - '0' - (_c > '9' ? 7 : 0);})

static char *base64 = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_";

#if __GLIBC__ > 2 || (__GLIBC__ == 2 && __GLIBC_MINOR__ >= 11)
#define HAVE_REGISTERPRINTFSPECIFIER 1
#else
#define HAVE_REGISTERPRINTFSPECIFIER 0
#endif

static int CLPrintObject(FILE *stream, const struct printf_info *info,
			const void *const *args);
#if HAVE_REGISTERPRINTFSPECIFIER
static int CLPrintObjectArgInfo(const struct printf_info *info, size_t n,
				int *argtypes, int *size);
#else
static int CLPrintObjectArgInfo(const struct printf_info *info, size_t n,
				int *argtypes);
#endif

@implementation CLString

+(void) linkerIsBorked
{
  [CLConstantString linkerIsBorked];
  return;
}

+(void) load
{
#if HAVE_REGISTERPRINTFSPECIFIER
  register_printf_specifier('@', CLPrintObject, CLPrintObjectArgInfo);
#else
  register_printf_function('@', CLPrintObject, CLPrintObjectArgInfo);
#endif
  return;
}

-(id) initWithBytes:(const char *) bytes length:(CLUInteger) length
	   encoding:(CLStringEncoding) encoding
{
  char *buf = NULL;
  CLUInteger blen;


  if (bytes && length &&
      isa == CLStringClass && encoding == CLUTF8StringEncoding) {
    if (!(buf = malloc(length+1)))
      [self error:@"Unable to allocate memory"];
    memmove(buf, bytes, length);
    buf[length] = 0;
    isa = CLUTF8StringClass;
    [self initWithBytesNoCopy:buf length:length encoding:encoding];
  }
  else {
    [super init];
    if (!bytes)
      length = 0;

    if (length) {
      if (encoding != CLUnicodeStringEncoding) {
	CLStringConvertEncoding(bytes, length, encoding,
				&buf, &blen, CLUnicodeStringEncoding, NO);
	bytes = buf;
	len = blen / sizeof(unichar);
      }
      else
	len = (length + sizeof(unichar) - 1) / sizeof(unichar);
    }

    data = CLStringAllocateBuffer(NULL, len, NULL, self);
    if (len)
      wmemmove(data, (unichar *) bytes, len);
    if (buf)
      free(buf);
  }
  
  return self;
}

-(id) initWithBytesNoCopy:(char *) bytes length:(CLUInteger) length
		 encoding:(CLStringEncoding) encoding
{
  if (bytes && length) {
    if (isa == CLStringClass && encoding == CLUTF8StringEncoding) {
      isa = CLUTF8StringClass;
      [self initWithBytesNoCopy:bytes length:length encoding:encoding];
    }
#if 0
    else if (encoding == CLUnicodeStringEncoding) {
      CLStringStorage *stor;


      [super init];
      if (!(data = stor = calloc(1, sizeof(CLStringStorage))))
	[self error:@"Unable to allocate memory"];
      stor->str = (unichar *) bytes;
      stor->maxLen = len = (length + sizeof(unichar) - 1) / sizeof(unichar);
    }
#endif
    else {
      [self initWithBytes:bytes length:length encoding:encoding];
      free(bytes);
    }
  }
  else {
    [self initWithBytes:bytes length:length encoding:encoding];
    if (bytes)
      free(bytes);
  }
  
  return self;
}

-(void) dealloc
{
  char *utf8;

  
  if ((utf8 = CLStringFreeBuffer(data)))
    free(utf8);
  [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef copy
#undef retain
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  return [self retain:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#define retain		retain:__FILE__ :__LINE__ :self
}
#else
-(id) copy
{
  return [self retain];
}
#endif

-(id) mutableCopy
{
  return [[CLMutableString alloc] initWithString:self];
}

-(id) read:(CLStream *) stream
{
  char *p;


  [super read:stream];
  [stream readTypes:@"*", &p];
  return [self initWithBytesNoCopy:p length:strlen(p) encoding:CLUTF8StringEncoding];
}
  
-(void) write:(CLStream *) stream
{
  const char *p = [self UTF8String];


  [super write:stream];
  [stream writeTypes:@"*", &p];
  return;
}

-(CLUInteger) length
{
  CLCheckStringClass(self);
  return len;
}

-(unichar) characterAtIndex:(CLUInteger) index
{  
  if (index >= len)
    [self error:@"index exceeds length"];
  return ((unistr *) self)->str[index];
}

-(void) getCharacters:(unichar *) buffer range:(CLRange) aRange
{
  wmemmove(buffer, &((unistr *) self)->str[aRange.location], aRange.length);
  return;
}

-(const char *) UTF8String
{
  return CLUTF8ForString(self);
}

-(CLString *) description
{
  return self;
}

-(CLString *) propertyList
{
  return [self propertyListString];
}

-(CLString *) json
{
  CLMutableString *mString;
  CLString *aString;

  
  mString = [self mutableCopy];
  [mString replaceOccurrencesOfString:@"\\" withString:@"\\\\"];
  [mString replaceOccurrencesOfString:@"/" withString:@"\\/"];
  [mString replaceOccurrencesOfString:@"\"" withString:@"\\\""];
  [mString replaceOccurrencesOfString:@"\b" withString:@"\\b"];
  [mString replaceOccurrencesOfString:@"\f" withString:@"\\f"];
  [mString replaceOccurrencesOfString:@"\n" withString:@"\\n"];
  [mString replaceOccurrencesOfString:@"\r" withString:@"\\r"];
  [mString replaceOccurrencesOfString:@"\t" withString:@"\\t"];
  aString = [CLString stringWithFormat:@"\"%@\"", mString];
  [mString release];

  return aString;
}

-(CLUInteger) hash
{
  return CLStringHash(self);
}

@end

@implementation CLString (CLStringCreation)

+(id) string
{
  return [[[self alloc] init] autorelease];
}

+(id) stringWithCharacters:(const unichar *) chars length:(CLUInteger) length
{
  return [[[self alloc] initWithCharacters:chars length:length] autorelease];
}

+(id) stringWithUTF8String:(const char *) bytes
{
  return [[[self alloc] initWithUTF8String:bytes] autorelease];
}

+(id) stringWithString:(CLString *) aString
{
  return [[[self alloc] initWithString:aString] autorelease];
}

+(id) stringWithBytes:(const char *) bytes length:(CLUInteger) length
	     encoding:(CLStringEncoding) encoding
{
  return [[[self alloc] initWithBytes:bytes length:length encoding:encoding] autorelease];
}

+(id) stringWithBytesNoCopy:(const char *) bytes length:(CLUInteger) length
	     encoding:(CLStringEncoding) encoding
{
  return [[[self alloc] initWithBytesNoCopy:bytes length:length encoding:encoding]
	   autorelease];
}

+(id) stringWithData:(CLData *) aData encoding:(CLStringEncoding) encoding
{
  return [[[self alloc] initWithData:aData encoding:encoding] autorelease];
}
    
+(id) stringWithContentsOfFile:(CLString *) path encoding:(CLStringEncoding) enc
{
  return [[[self alloc] initWithContentsOfFile:path encoding:enc] autorelease];
}

-(id) initWithCString:(const char *) cString encoding:(CLStringEncoding) encoding
{
  return [self initWithBytes:cString length:strlen(cString) encoding:encoding];
}

-(id) initWithUTF8String:(const char *) bytes
{
  return [self initWithBytes:bytes length:strlen(bytes) encoding:CLUTF8StringEncoding];
}

-(id) initWithCharacters:(const unichar *) characters length:(CLUInteger) length
{
  return [self initWithBytes:(char *) characters length:length * sizeof(unichar)
	       encoding:CLUnicodeStringEncoding];
}

-(id) initWithString:(CLString *) aString
{
  if ([aString isKindOfClass:CLUTF8StringClass])
    [self initWithBytes:aString->data length:aString->len encoding:CLUTF8StringEncoding];
  else
    [self initWithBytes:aString->data length:aString->len*sizeof(unichar)
	       encoding:CLUnicodeStringEncoding];
  return self;
}

-(id) initWithData:(CLData *) aData encoding:(CLStringEncoding) encoding
{
  return [self initWithBytes:[aData bytes] length:[aData length] encoding:encoding];
}

-(id) initWithContentsOfFile:(CLString *) path encoding:(CLStringEncoding) enc
{
  FILE *file;
  long length;
  char *buf;


  if (!(file = fopen([path UTF8String], "r"))) {
    [super init];
    [self release];
    return nil;
  }

  fseek(file, 0L, SEEK_END);
  length = ftell(file);
  rewind(file);
  if (!(buf = malloc(length+1)))
    [self error:@"Unable to allocate memory"];
  fread(buf, length, 1, file);
  fclose(file);

  return [self initWithBytesNoCopy:buf length:length encoding:enc];
}

@end

@implementation CLString (CLStringComparison)

-(CLComparisonResult) compare:(CLString *) aString
{
  CLCheckStringClass(self);
  return [self compare:aString options:0 range:CLMakeRange(0, len)];
}

-(CLComparisonResult) compare:(CLString *) aString options:(CLStringCompareOptions) mask
{
  CLCheckStringClass(self);
  return [self compare:aString options:mask range:CLMakeRange(0, len)];
}

-(CLComparisonResult) compare:(CLString *) aString options:(CLStringCompareOptions) mask
			range:(CLRange) range
{
  return CLStringCompare(self, aString, mask, range);
}

-(CLComparisonResult) caseInsensitiveCompare:(CLString *) aString
{
  CLCheckStringClass(self);
  return CLStringCompare(self, aString, CLCaseInsensitiveSearch, CLMakeRange(0, len));
}

-(BOOL) hasPrefix:(CLString *) prefix
{
  CLCheckStringClass(self);
  CLCheckStringClass(prefix);
  if (prefix->len > len)
    return NO;
  return ![self compare:prefix options:0
		range:CLMakeRange(0, prefix->len)];
}

-(BOOL) hasSuffix:(CLString *) suffix
{
  if (!suffix)
    return NO;

  CLCheckStringClass(self);
  CLCheckStringClass(suffix);
  if (suffix->len > len)
    return NO;
  return ![self compare:suffix options:0
		range:CLMakeRange(len - suffix->len, suffix->len)];
}

-(CLRange) rangeOfString:(CLString *) aString
{
  CLCheckStringClass(self);
  return [self rangeOfString:aString options:0 range:CLMakeRange(0, len)];
}

-(CLRange) rangeOfString:(CLString *) aString options:(CLStringCompareOptions) mask
{
  CLCheckStringClass(self);
  return [self rangeOfString:aString options:mask range:CLMakeRange(0, len)];
}

-(CLRange) rangeOfString:(CLString *) aString options:(CLStringCompareOptions) mask
		   range:(CLRange) range
{
  return CLStringRangeOfString(self, aString, mask, range);
}

-(CLRange) rangeOfCharacter:(unichar) aChar options:(CLStringCompareOptions) mask
		   range:(CLRange) range
{
  unistr ustr;


  ustr = CLNewStackString(1);
  ustr.str[ustr.len] = aChar;
  ustr.len++;
  return CLStringRangeOfString(self, (CLString *) &ustr, mask, range);
}

-(CLRange) rangeOfCharacterFromSet:(CLCharacterSet *) aSet
{
  CLCheckStringClass(self);
  return [self rangeOfCharacterFromSet:aSet options:0 range:CLMakeRange(0, len)];
}

-(CLRange) rangeOfCharacterFromSet:(CLCharacterSet *) aSet
			   options:(CLStringCompareOptions) mask range:(CLRange) aRange
{
  CLRange res = CLMakeRange(CLNotFound, 0);
  

  CLStringFindCharacterFromSet(self, aSet, mask, aRange, &res);
  return res;
}

-(CLRange) rangeOfCharacterNotFromSet:(CLCharacterSet *) aSet
			   options:(CLStringCompareOptions) mask range:(CLRange) aRange
{
  CLRange res = CLMakeRange(CLNotFound, 0);
  

  CLStringFindCharacterFromSet(self, aSet, mask | CLInvertedSearch, aRange, &res);
  return res;
}

-(BOOL) isEqual:(id) anObject
{
  if (self == anObject)
    return YES;
  if (![anObject isKindOfClass:CLStringClass])
    return NO;

  return [self isEqualToString:anObject];
}

-(BOOL) isEqualToString:(CLString *) aString
{
  if (!aString)
    return NO;
  if (self == aString)
    return YES;
  CLCheckStringClass(self);
  return !CLStringCompare(self, aString, 0, CLMakeRange(0, len));
}

-(BOOL) isEqualToCaseInsensitiveString:(CLString *) aString
{
  if (!aString)
    return NO;
  CLCheckStringClass(self);
  return !CLStringCompare(self, aString, CLCaseInsensitiveSearch,
			  CLMakeRange(0, len));
}

-(CLRange) rangeOfTag:(CLString *) aTag inRange:(CLRange) aRange
{
  return [self rangeOfTag:aTag inRange:aRange allowCDATA:NO];
}

/* FIXME - make it have options and work backwards */
-(CLRange) rangeOfTag:(CLString *) aTag inRange:(CLRange) aRange allowCDATA:(BOOL) cdataFlag
{
  CLRange tagRange;
  CLUInteger i, j, k;
  BOOL inString, inCdata;
  CLUInteger tlen;
  CLString *cDataString = @"<![CDATA[";
  CLString *cDataEndString = @"]]>";
  unistr *ustr;


  CLCheckStringClass(aTag);
  CLCheckStringClass(self);
  CLCheckStringClass(cDataString);
  CLCheckStringClass(cDataEndString);
  
  tagRange.location = 0;
  tagRange.length = 0;
  tlen = aTag->len;

  ustr = (unistr *) self;
  for (i = aRange.location, j = aRange.location + aRange.length; i < j && i < len; i++) {
    if (ustr->str[i] == '<') {
      inString = inCdata = NO;
      k = i;
      for (; i < j; i++) {
	if (cdataFlag && i == k && j - i > cDataString->len &&
	    !wcsncmp(&ustr->str[i], cDataString->data, cDataString->len)) {
	  inCdata = YES;
	  i += cDataString->len - 1;
	}
	else if (inCdata && j - i >= cDataEndString->len &&
		 !wcsncmp(&ustr->str[i], cDataEndString->data, cDataEndString->len)) {
	  inCdata = NO;
	  i += cDataEndString->len - 2;
	}
	else if (!inCdata && ustr->str[i] == '"')
	  inString = !inString;
	else if (!inString && !inCdata && ustr->str[i] == '>')
	  break;
      }
      if (ustr->str[i] == '>') {
	tagRange.location = k;
	k++;
	while (iswspace(ustr->str[k]))
	  k++;
	if (k + tlen < j &&
	    (iswspace(ustr->str[k+tlen]) || ustr->str[k+tlen] == '>') &&
	    !CLStringCompare(self, aTag, CLCaseInsensitiveSearch,
			     CLMakeRange(k, tlen))) {
	  tagRange.length = i - tagRange.location + 1;
	  break;
	}
      }
    }
  }

  return tagRange;
}

-(BOOL) getRangeOfBlock:(CLString *) startTag end:(CLString *) endTag
	     outerRange:(CLRange *) outerRange innerRange:(CLRange *) innerRange
		inRange:(CLRange) aRange
{
  return [self getRangeOfBlock:startTag end:endTag outerRange:outerRange
	       innerRange:innerRange inRange:aRange allowCDATA:NO];
}

-(BOOL) getRangeOfBlock:(CLString *) startTag end:(CLString *) endTag
	     outerRange:(CLRange *) outerRange innerRange:(CLRange *) innerRange
		inRange:(CLRange) aRange allowCDATA:(BOOL) cdataFlag
{
  CLRange aRange2, aRange3, aRange4;
  int nest;
  BOOL found = NO;
  CLUInteger length;


  length = CLMaxRange(aRange);
  aRange = [self rangeOfTag:startTag inRange:aRange allowCDATA:cdataFlag];
  if (aRange.length) {
    aRange2.location = CLMaxRange(aRange);
    aRange2.length = length - aRange2.location;

    for (nest = 1; nest;) {
      aRange3 = aRange2;
      aRange2 = [self rangeOfTag:endTag inRange:aRange2 allowCDATA:cdataFlag];
      if (!aRange2.length)
	break;
      nest--;

      for (;;) {
	aRange4 = [self rangeOfTag:startTag inRange:aRange3 allowCDATA:cdataFlag];
	if (!aRange4.length || aRange4.location >= aRange2.location)
	  break;
	nest++;
	aRange3.location = CLMaxRange(aRange4);
	aRange3.length = aRange2.location - aRange3.location;
      }

      if (nest) {
	aRange2.location += aRange2.length;
	aRange2.length = length - aRange2.location;
      }
    }

    if (!nest) {
      outerRange->location = aRange.location;
      outerRange->length = CLMaxRange(aRange2) - aRange.location;
      innerRange->location = CLMaxRange(aRange);
      innerRange->length = aRange2.location - innerRange->location;
      found = YES;
    }
  }
  
  return found;
}

@end

@implementation CLString (CLStringPaths)

+(CLString *) pathWithComponents:(CLArray *) components
{
  CLMutableString *mString;
  CLString *aString;
  int i, j;


  mString = [[CLMutableString alloc] init];
  for (i = 0, j = [components count]; i < j; i++) {
    aString = [components objectAtIndex:i];
    if (!i && [aString isEqualToString:PATHSEP_STRING])
      continue;
    if (i)
      [mString appendString:PATHSEP_STRING];
    [mString appendString:aString];
  }
  
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(BOOL) isAbsolutePath
{
  CLCheckStringClass(self);
  return len > 0 && [self characterAtIndex:0] == PATHSEP_CHAR;
}

-(BOOL) hasPathPrefix:(CLString *) prefix
{
  CLCheckStringClass(self);
  CLCheckStringClass(prefix);
  if ([self hasPrefix:prefix] &&
      (len == prefix->len || (len > prefix->len &&
			      [self characterAtIndex:prefix->len] == PATHSEP_CHAR)))
    return YES;
  return NO;
}

-(CLString *) stringByAppendingPathComponent:(CLString *) aString
{
  CLMutableString *mString;


  CLCheckStringClass(self);
  if (!len)
    return [[aString copy] autorelease];

  mString = [self mutableCopy];
  [mString appendPathComponent:aString];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) stringByAppendingPathExtension:(CLString *) ext
{
  CLMutableString *mString;


  mString = [self mutableCopy];
  [mString appendPathExtension:ext];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) stringByDeletingLastPathComponent
{
  CLRange sRange;
  CLMutableString *mString;


  CLCheckStringClass(self);
  sRange = [self rangeOfString:PATHSEP_STRING options:CLBackwardsSearch
		 range:CLMakeRange(0, len)];
  if (!sRange.length)
    return @"";

  mString = [self mutableCopy];
  [mString deleteLastPathComponent];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) stringByDeletingPathExtension
{
  CLRange pRange, sRange;
  CLMutableString *mString;


  CLCheckStringClass(self);
  sRange = CLMakeRange(0, len);
  pRange = [self rangeOfString:@"." options:CLBackwardsSearch range:sRange];
  sRange = [self rangeOfString:PATHSEP_STRING options:CLBackwardsSearch range:sRange];
  if ((pRange.length && pRange.location &&
      (!sRange.length ||
       sRange.location < pRange.location || sRange.location == len - 1)) ||
      (sRange.length && sRange.location == len - 1)) {
    mString = [self mutableCopy];
    [mString deletePathExtension];
    ((CLString *) mString)->isa = CLStringClass;
    return [mString autorelease];
  }

  return self;  
}

-(CLString *) stringByDeletingPathPrefix:(CLString *) aPrefix
{
  CLMutableString *mString;

  
  if (![self hasPathPrefix:aPrefix])
    return self;

  mString = [self mutableCopy];
  [mString deletePathPrefix:aPrefix];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLArray *) pathComponents
{
  CLMutableArray *mArray;


  /* FIXME - yah yah, I'm typecasting it cuz I know what type I really return */
  mArray = (CLMutableArray *) [self componentsSeparatedByString:PATHSEP_STRING];
  if ([mArray count] && ![[mArray objectAtIndex:0] length]) {
    [mArray removeObjectAtIndex:0];
    [mArray insertObject:PATHSEP_STRING atIndex:0];
  }
  
  /* FIXME - return immutable array */
  return mArray;
}

-(CLString *) pathExtension
{
  CLRange pRange;


  CLCheckStringClass(self);
  pRange = [self rangeOfString:@"." options:CLBackwardsSearch
		 range:CLMakeRange(0, len)];
  if (pRange.length)
    return [self substringFromIndex:pRange.location + 1];

  return @"";
}

-(CLString *) lastPathComponent
{
  CLRange sRange, sRange2;


  CLCheckStringClass(self);
  sRange = [self rangeOfString:PATHSEP_STRING options:CLBackwardsSearch
		 range:CLMakeRange(0, len)];
  if (!sRange.length)
    return [[self copy] autorelease];

  sRange2 = [self rangeOfString:PATHSEP_STRING options:CLBackwardsSearch
		  range:CLMakeRange(0, sRange.location)];
  if (sRange.location == len - 1) {
    if (sRange.location == 0)
      return [[self copy] autorelease];
    if (!sRange2.length)
      return [self substringToIndex:sRange.location];
    return [self substringWithRange:
		   CLMakeRange(sRange2.location+1,
			       sRange.location - sRange2.location - 1)];
  }

  return [self substringFromIndex:sRange.location+1];
}

@end

@implementation CLString (CLStringEncodings)

-(CLData *) decodeBase64
{
  unichar *q;
  unsigned char *p;
  unichar c;
  char buf[4];
  int i, j, k, l;
  CLData *aData;


  CLCheckStringClass(self);
  if (!(p = malloc(l = len)))
    [self error:@"Unable to allocate memory"];
  
  for (i = j = 0, q = ((unistr *) self)->str; l; q++, l--) {
    c = *q;
    if (c != '=') {
      c = strchr(base64, c) - base64;
      if (c < 0)
	continue;
    }
    else {	/* padding */
      switch (i) {
      case 2:
	k = buf[0] & 0x3f;
	k <<= 6;
	k |= buf[1] & 0x3f;
	k <<= 6;
	p[j] = (k >> 10) & 0xff;
	j += 1;
	break;

      case 3:
	k = buf[0] & 0x3f;
	k <<= 6;
	k |= buf[1] & 0x3f;
	k <<= 6;
	k |= buf[2] & 0x3f;
	k <<= 6;
	p[j] = (k >> 16) & 0xff;
	p[j+1] = (k >> 8) & 0xff;
	j += 2;
	break;
      }
      break;
    }

    buf[i] = c;
    i++;
    if (i == 4) {
      k = buf[0] & 0x3f;
      k <<= 6;
      k |= buf[1] & 0x3f;
      k <<= 6;
      k |= buf[2] & 0x3f;
      k <<= 6;
      k |= buf[3] & 0x3f;
      p[j] = (k >> 16) & 0xff;
      p[j+1] = (k >> 8) & 0xff;
      p[j+2] = k & 0xff;
      j += 3;
      i = 0;
    }
  }

  aData = [CLData dataWithBytesNoCopy:p length:j];
  
  return aData;
}

-(CLString *) entityEncodedString
{
  CLMutableString *mString;
  unistr *ustr;
  unichar *p;
  unichar c;
  CLUInteger i;


  ustr = CLStringToUnistr(self);
  for (p = ustr->str; p < ustr->str + ustr->len; p++) {
    c = *p;
    for (i = 0; CLEntities[i].c; i++)
      if (c == CLEntities[i].c)
	break;

    if (CLEntities[i].c)
      break;
  }

  if (p == ustr->str + ustr->len)
    return self;

  mString = [self mutableCopy];
  [mString encodeEntities];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) xmlEntityEncodedString
{
  CLMutableString *mString;
  unistr *ustr;
  unichar *p;
  unichar c;
  CLUInteger i;


  ustr = CLStringToUnistr(self);
  for (p = ustr->str; p < ustr->str + ustr->len; p++) {
    c = *p;
    for (i = 0; CLEntities[i].c; i++)
      if (c == CLEntities[i].c)
	break;

    if (i < 5 && CLEntities[i].c)
      break;
  }

  if (p == ustr->str + ustr->len)
    return self;

  mString = [self mutableCopy];
  [mString encodeXMLEntities];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) entityDecodedString
{
  CLMutableString *mString;
  CLRange aRange;


  aRange = [self rangeOfString:@"&" options:0 range:CLMakeRange(0, len)];
  if (!aRange.length)
    return self;

  mString = [self mutableCopy];
  [mString decodeEntities];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) stringByAddingPercentEscapes
{
  return [self stringByAddingPercentEscapesWithPlus:YES];
}

-(CLString *) stringByAddingPercentEscapesWithPlus:(BOOL) flag
{
  CLMutableString *mString;

  
  mString = [self mutableCopy];
  [mString addPercentEscapesWithPlus:flag];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) stringByReplacingPercentEscapes
{
  CLMutableString *mString;

  
  mString = [self mutableCopy];
  [mString replacePercentEscapes];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(id) decodeObject:(unichar *) buf length:(CLUInteger) length pos:(CLUInteger *) pos
{
  CLUInteger i, start;
  id anObject = nil, anObject2, anObject3;
  BOOL inString, sawEscape;
  int inComment;
  

  start = *pos;
  inComment = 0;
  for (i = start; i < length; i++) {
    if (!inComment && i+1 < length && buf[i] == '/' && buf[i+1] == '*') {
      inComment = 1;
      i++;
    }
    else if (!inComment && i+1 < length && buf[i] == '/' && buf[i+1] == '/') {
      inComment = 2;
      i++;
    }

    if (!inComment && !iswspace(buf[i]))
      break;

    if (inComment == 1 && buf[i] == '/' && buf[i-1] == '*')
      inComment = 0;
    else if (inComment == 2 && buf[i] == '\n')
      inComment = 0;
  }

  if (i < length)
    switch (buf[i]) {
    case '{':
      anObject = [[[CLMutableDictionary alloc] init] autorelease];
      i++;
      while ((anObject2 = [self decodeObject:buf length:length pos:&i])) {
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (buf[i] != '=')
	  break;
	i++;
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if ((anObject3 = [self decodeObject:buf length:length pos:&i]))
	  [anObject setObject:anObject3 forKey:anObject2];
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == ';')
	  i++;
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == '}')
	  break;
      }
      if (buf[i] == '}')
	i++;
      break;

    case '(':
      anObject = [CLMutableArray array];
      i++;
      while ((anObject2 = [self decodeObject:buf length:length pos:&i])) {
	[anObject addObject:anObject2];
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == ',')
	  i++;
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == ')')
	  break;
      }
      if (buf[i] == ')')
	i++;
      break;

    case '<':
      inString = NO;
      start = i;
      for (; i < length && (inString || (!iswspace(buf[i]) &&
				      buf[i] != ';' && buf[i] != '=' && buf[i] != ',' &&
				      buf[i] != ')' && buf[i] != '}'));
	   i++)	
	if ((buf[i] == '<' && !inString) || (buf[i] == '>' && inString))
	  inString = !inString;
      if (buf[start+1] == '*') {
	switch (buf[start+2]) {
	case 'i':
	  anObject = [CLNumber numberWithLongLong:
				 [[CLString stringWithCharacters:&buf[start+3]
					    length:i-start-4] longLongValue]];
	  break;

	case 'u':
	  anObject = [CLNumber numberWithUnsignedLongLong:
				 [[CLString stringWithCharacters:&buf[start+3]
					    length:i-start-4] unsignedLongLongValue]];
	  break;

	case 'd':
	  anObject = [CLNumber numberWithDouble:
				 [[CLString stringWithCharacters:&buf[start+3]
					    length:i-start-4] doubleValue]];
	  break;

	case 'n':
	  anObject = [CLDecimalNumber decimalNumberWithString:
					[CLString stringWithCharacters:&buf[start+3]
						  length:i-start-4]];
	  break;

	case 'D':
	  anObject = [CLDatetime dateWithString:
				       [CLString stringWithCharacters:&buf[start+3]
						 length:i-start-4]];
	  break;
	}
      }
      else
	anObject = [CLPlaceholder placeholderFromString:
				    [CLString stringWithCharacters:&buf[start]
					      length:i-start]];
      break;
      
    default:
      inString = sawEscape = NO;
      start = i;
      for (; i < length && (inString || (!iswspace(buf[i]) &&
				      buf[i] != ';' && buf[i] != '=' &&
				      buf[i] != ',' && buf[i] != '}' &&
				      buf[i] != ')'));
	   i++)	{
	if (buf[i] == '"' && !sawEscape)
	  inString = !inString;
	if (!sawEscape && buf[i] == '\\')
	  sawEscape = YES;
	else
	  sawEscape = NO;
      }
      if (buf[start] == '"')
	anObject = [CLString stringWithCharacters:&buf[start+1] length:i-start-2];
      else if (i-start)
	anObject = [CLString stringWithCharacters:&buf[start] length:i-start];
      anObject = [anObject reversePropertyListString];
      break;
    }

  *pos = i;
  return anObject;
}

-(id) decodePropertyList
{
  CLUInteger i;
  id anObject;

  
  CLCheckStringClass(self);
  i = 0;
  anObject = [self decodeObject:((unistr *) self)->str length:len pos:&i];
  return anObject;
}

-(id) decodeJSON:(unichar *) buf length:(CLUInteger) length pos:(CLUInteger *) pos
{
  CLUInteger i, start;
  id anObject = nil, anObject2, anObject3;
  BOOL inString;
  

  start = *pos;
  for (i = start; i < length && iswspace(buf[i]); i++)
    ;

  if (i < length)
    switch (buf[i]) {
    case '{':
      anObject = [[[CLMutableDictionary alloc] init] autorelease];
      i++;
      while ((anObject2 = [self decodeJSON:buf length:length pos:&i])) {
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (buf[i] != ':')
	  break;
	i++;
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	anObject3 = [self decodeJSON:buf length:length pos:&i];
	[anObject setObject:anObject3 forKey:anObject2];
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == ',')
	  i++;
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == '}')
	  break;
      }
      if (buf[i] == '}')
	i++;
      break;

    case '[':
      anObject = [CLMutableArray array];
      i++;
      while ((anObject2 = [self decodeJSON:buf length:length pos:&i])) {
	[anObject addObject:anObject2];
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == ',')
	  i++;
	for (; i < length && iswspace(buf[i]); i++)
	  ;
	if (i < length && buf[i] == ']')
	  break;
      }
      if (buf[i] == ']')
	i++;
      break;

    default:
      inString = NO;
      start = i;
      for (; i < length && (inString || (!iswspace(buf[i]) &&
					 buf[i] != ':' &&
					 buf[i] != ',' && buf[i] != '}' &&
					 buf[i] != ']'));
	   i++)	{
	if (buf[i] == '\\') {
	  i++;
	  continue;
	}
	if (buf[i] == '"')
	  inString = !inString;
      }
      if (buf[start] == '"')
	anObject = [[CLString stringWithCharacters:&buf[start+1] length:i-start-2]
		     reversePropertyListString];
      else if (i-start) {
	anObject = [CLString stringWithCharacters:&buf[start] length:i-start];
	if ([anObject isEqualToString:@"true"])
	  anObject = CLTrueObject;
	else if ([anObject isEqualToString:@"false"])
	  anObject = CLFalseObject;
	else if ([anObject isEqualToString:@"null"])
	  anObject = CLNullObject;
	else if (i-start && (iswdigit(buf[start]) || buf[start] == '-'))
	  anObject = [CLDecimalNumber decimalNumberWithString:anObject];
	else
	  anObject = [anObject reversePropertyListString];
      }
      break;
    }

  *pos = i;
  return anObject;
}

-(id) decodeJSON
{
  CLUInteger i;
  id anObject;

  
  CLCheckStringClass(self);
  i = 0;
  anObject = [self decodeJSON:((unistr *) self)->str length:len pos:&i];
  return anObject;
}

-(id) decodeAttributes:(CLString *) aString
{
  unichar *p, *q, *strend;
  CLString *aKey;
  id aValue, anObject = nil;
  
  
  CLCheckStringClass(aString);
  p = ((unistr *) aString)->str;
  strend = p + aString->len;
  while (p < strend && !iswalpha(*p))
    p++;

  while (p < strend) {
    q = p;
    while (q < strend && *q != '=' && *q != '>'
	   && !iswspace(*q))
      q++;
    aKey = [[CLString alloc] initWithCharacters:p length:q-p];
    while (q < strend && iswspace(*q))
      q++;
    p = q+1;
    if (q >= strend || *q != '=')
      aValue = CLNullObject;
    else {
      while (p < strend && iswspace(*p))
	p++;
      q = p;
      if (*q == '"') {
	q++;
	p++;
	while (q < strend && *q != '"')
	  q++;
      }
      else {
	while (q < strend && *q != '>' && !iswspace(*q))
	  q++;
      }
      aValue = [[[[CLString alloc] initWithCharacters:p length:q-p]
		  entityDecodedString] retain];
    }
    if (!anObject)
      anObject = [[CLMutableDictionary alloc] init];
    [anObject setObject:aValue forCaseInsensitiveString:aKey];
    [aKey release];
    [aValue release];

    p = q;
    while (p < strend && !iswalpha(*p))
      p++;
  }

  return [anObject autorelease];
}

-(id) decodeXML
{
  CLUInteger i, j, k, l, start;
  id anObject = nil, curObject, oldObject;
  BOOL inString, inCdata, foundTag = NO;
  CLRange oRange, iRange;
  id aKey, aValue;
  CLAutoreleasePool *pool;
  CLString *cDataString = @"![CDATA[";
  CLString *cDataEndString = @"]]>";


  pool = [[CLAutoreleasePool alloc] init];
  CLCheckStringClass(self);
  CLCheckStringClass(cDataString);
  CLCheckStringClass(cDataEndString);

  i = 0;
  while (i < len) {
    for (; i < len && iswspace(((unistr *) self)->str[i]); i++)
      ;

    if (i < len && ((unistr *) self)->str[i] == '<') {
      foundTag = YES;
      inString = inCdata = NO;
      start = i;
      i++;
      for (k = i; k < len && iswspace(((unistr *) self)->str[k]); k++)
	;
      for (i = k; i < len; i++) {
	if (i == k && len - i > cDataString->len &&
	    !wcsncmp(&((unistr *) self)->str[i], cDataString->data, cDataString->len)) {
	  inCdata = YES;
	  i += cDataString->len - 1;
	}
	else if (inCdata && len - i >= cDataEndString->len &&
		 !wcsncmp(&((unistr *) self)->str[i], cDataEndString->data, cDataEndString->len)) {
	  inCdata = NO;
	  i += cDataEndString->len - 2;
	}
	else if (!inCdata && ((unistr *) self)->str[i] == '"')
	  inString = !inString;
	else if (!inString && !inCdata && ((unistr *) self)->str[i] == '>')
	  break;
      }

      if (i < len && ((unistr *) self)->str[i] == '>') {
	for (j = k; j < i && !iswspace(((unistr *) self)->str[j]) &&
	       ((unistr *) self)->str[j] != '>' && ((unistr *) self)->str[j] != '/'; j++)
	  ;
	aKey = [CLString stringWithCharacters:&((unistr *) self)->str[k] length:j-k];
	if ([aKey hasPrefix:cDataString]) {
	  iRange.location = k + cDataString->len;
	  iRange.length = (i - 2) - iRange.location;
	  curObject = [[[self substringWithRange:iRange] entityDecodedString] retain];
	  if (anObject) {
	    if ([anObject isKindOfClass:CLMutableStringClass]) 
	      [anObject appendString:curObject];
	    else if ([anObject isKindOfClass:CLStringClass]) {
	      aValue = [[anObject stringByAppendingString:curObject] retain];
	      [anObject release];
	      anObject = aValue;
	    }
	    else
	      [self error:@"Overwriting existing object!"];
	    
	    [curObject release];
	  }
	  else
	    anObject = curObject;
	}
	else {
	  curObject = aValue = nil;
	  l = i;
	  if (((unistr *) self)->str[i-1] == '/')
	    l--;
	  for (; j < l && iswspace(((unistr *) self)->str[j]); j++)
	    ;

	  if (l - j && (aValue = [self decodeAttributes:
					 [self substringWithRange:CLMakeRange(j, l - j)]])) {
	    curObject = aValue;
	    aValue = nil;
	  }

	  if (((unistr *) self)->str[i-1] == '/' || [aKey hasPrefix:@"?xml"]) {
	    aValue = CLNullObject;
	    i++;
	  }
	  else if ([self getRangeOfBlock:aKey end:[CLString stringWithFormat:@"/%@", aKey]
			 outerRange:&oRange innerRange:&iRange
			 inRange:CLMakeRange(start, len - start) allowCDATA:YES]) {
	    aValue = [[self substringWithRange:iRange] decodeXML];
	    i = CLMaxRange(oRange);
	  }

	  if (aValue) {
	    if (!anObject)
	      anObject = [[CLMutableDictionary alloc] init];
	  
	    if (curObject)
	      aValue = [CLArray arrayWithObjects:curObject, aValue, nil];
	  
	    if ((oldObject = [anObject objectForKey:aKey])) {
	      if (![oldObject isKindOfClass:CLMutableArrayClass]) {
		curObject = [[CLMutableArray alloc] init];
		[curObject addObject:oldObject];
		[anObject setObject:curObject forKey:aKey];
		oldObject = curObject;
		[curObject release];
	      }
	      [oldObject addObject:aValue];
	    }
	    else
	      [anObject setObject:aValue forKey:aKey];
	  }
	}
      }
      else if (i < len)
	[self error:@"Unknown XML encoding"];
    }
    else {
      if (!foundTag) {      
	anObject = [[self entityDecodedString] retain];
	i = len;
      }
      else
	i++;
    }
  }

  [pool release];

  return [anObject autorelease];
}

-(CLArray *) decodeCSV
{
  return [self decodeCSVUsingCharacterSet:
		 [CLCharacterSet characterSetWithCharactersInString:@","]];
}

-(CLArray *) decodeCSVUsingCharacterSet:(CLCharacterSet *) aSet
{
  CLMutableArray *mArray;
  CLArray *record, *rows, *dup;
  CLCSVDecoder *decoder;


  mArray = [[CLMutableArray alloc] init];
  decoder = [[CLCSVDecoder alloc] initWithString:self fieldSeparator:aSet];
  while ((record = [decoder decodeNextRow])) {
    /* Make a copy because the decoder re-uses the record array */
    dup = [record copy];
    [mArray addObject:dup];
    [dup release];
  }
  [decoder release];

  rows = mArray;
  if ([rows count] == 1) {
    record = [[rows objectAtIndex:0] retain];
    [rows release];
    rows = record;
  }
  
  return [rows autorelease];
}

-(CLData *) dataUsingEncoding:(CLStringEncoding) encoding
{
  return [self dataUsingEncoding:encoding allowLossyConversion:NO];
}

-(CLData *) dataUsingEncoding:(CLStringEncoding) encoding
	 allowLossyConversion:(BOOL) flag  
{
  char *buf;
  CLUInteger blen;


  CLCheckStringClass(self);
  CLStringConvertEncoding(data, len * sizeof(unichar), CLUnicodeStringEncoding,
			  &buf, &blen, encoding, flag);
  return [CLData dataWithBytesNoCopy:buf length:blen];
}

-(CLString *) htmlLineBreaks
{
  return [self stringByReplacingOccurrencesOfString:@"\n" withString:@"<br>"];
}

@end

@implementation CLString (CLStringCombining)

-(CLString *) stringByAppendingString:(CLString *) aString
{
  CLString *mString = [self mutableCopy];


  CLStringReplaceString(mString, CLMakeRange([mString length], 0), aString);
  mString->isa = CLStringClass;
  return [mString autorelease];
}

@end

@implementation CLString (CLStringDividing)

-(CLArray *) componentsSeparatedByCharactersInSet:(CLCharacterSet *) separator
{
  CLRange nRange, oRange;
  CLMutableArray *mArray;


  CLCheckStringClass(self);
  mArray = [[CLMutableArray alloc] init];
  oRange = CLMakeRange(0, len);
  for (;;) {
    nRange = [self rangeOfCharacterFromSet:separator options:0 range:oRange];
    if (nRange.length) {
      if (nRange.location == 0)
	[mArray addObject:[self substringToIndex:1]];
      else
	[mArray addObject:[self substringWithRange:
				   CLMakeRange(oRange.location,
					       nRange.location - oRange.location)]];
      oRange.location = nRange.location + 1;
      oRange.length = len - oRange.location;
    }
    else {
      if (oRange.length)
	[mArray addObject:[self substringFromIndex:oRange.location]];
      break;
    }
  }

  /* FIXME - return immutable array */
  return [mArray autorelease];
}

-(CLArray *) componentsSeparatedByString:(CLString *) separator
{
  CLRange nRange, oRange;
  CLMutableArray *mArray;


  CLCheckStringClass(self);
  mArray = [[CLMutableArray alloc] init];
  oRange = CLMakeRange(0, len);
  for (;;) {
    nRange = [self rangeOfString:separator options:0 range:oRange];
    if (nRange.length) {
      if (nRange.location == 0)
	[mArray addObject:@""];
      else
	[mArray addObject:[self substringWithRange:
				   CLMakeRange(oRange.location,
					       nRange.location - oRange.location)]];
      oRange.location = CLMaxRange(nRange);
      oRange.length = len - oRange.location;
    }
    else {
      if (oRange.length)
	[mArray addObject:[self substringFromIndex:oRange.location]];
      break;
    }
  }

  /* FIXME - return immutable array */
  return [mArray autorelease];
}

-(CLString *) stringByTrimmingCharactersInSet:(CLCharacterSet *) set
{
  CLRange aRange, aRange2;


  CLCheckStringClass(self);
  if (!len)
    return self;
  
  aRange = [self rangeOfCharacterNotFromSet:set options:0 range:CLMakeRange(0, len)];
  aRange2 = [self rangeOfCharacterNotFromSet:set options:CLBackwardsSearch
		  range:CLMakeRange(0, len)];
  if (aRange.length && aRange2.length) {
    if (!aRange.location && CLMaxRange(aRange2) == len) {
      /* Return a copy because we could be mutable. If we're not
	 mutable then copy will do a retain. */
      return [[self copy] autorelease];
    }
    return [self substringWithRange:CLMakeRange(aRange.location,
						(aRange2.location + aRange2.length)
						- aRange.location)];
  }
  return @"";
}

-(CLString *) stringByTrimmingWhitespaceAndNewlines
{
  return [self stringByTrimmingCharactersInSet:
		 [CLCharacterSet whitespaceAndNewlineCharacterSet]];
}

-(CLString *) substringFromIndex:(CLUInteger) anIndex
{
  CLCheckStringClass(self);
  return [self substringWithRange:CLMakeRange(anIndex, len - anIndex)];
}

-(CLString *) substringToIndex:(CLUInteger) anIndex
{
  return [self substringWithRange:CLMakeRange(0, anIndex)];
}

-(CLString *) substringWithRange:(CLRange) range
{
  CLUInteger max;


  CLCheckStringClass(self);
  max = range.location + range.length;
  if (max < range.length || max > len)
    [self error:@"Range exceeds length"];
  return [CLString stringWithCharacters:&((unistr *) self)->str[range.location]
		   length:range.length];
}

@end

@implementation CLString (CLStringReplacing)

-(CLString *) stringByReplacingOccurrencesOfString:(CLString *) target
					withString:(CLString *) replacement
{
  CLCheckStringClass(self);
  return [self stringByReplacingOccurrencesOfString:target withString:replacement
	       options:0 range:CLMakeRange(0, len)];
}

-(CLString *) stringByReplacingOccurrencesOfString:(CLString *) target
					withString:(CLString *) replacement
					   options:(CLStringCompareOptions) options
					     range:(CLRange) searchRange
{
  CLMutableString *mString = [self mutableCopy];


  [mString replaceOccurrencesOfString:target withString:replacement options:options
				range:searchRange];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) stringByReplacingCharactersInRange:(CLRange) range
				      withString:(CLString *) replacement
{
  CLMutableString *mString = [self mutableCopy];


  [mString replaceCharactersInRange:range withString:replacement];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) propertyListString
{
  CLMutableString *mString;


  mString = [self mutableCopy];
  [mString replaceOccurrencesOfString:@"\\" withString:@"\\\\"];
  [mString replaceOccurrencesOfString:@"\"" withString:@"\\\""];
  [mString replaceOccurrencesOfString:@"\b" withString:@"\\b"];
  [mString replaceOccurrencesOfString:@"\f" withString:@"\\f"];
  [mString replaceOccurrencesOfString:@"\n" withString:@"\\n"];
  [mString replaceOccurrencesOfString:@"\r" withString:@"\\r"];
  [mString replaceOccurrencesOfString:@"\t" withString:@"\\t"];
  [mString insertString:@"\"" atIndex:0];
  [mString appendString:@"\""];

  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) reversePropertyListString
{
  CLString *mString = [[self mutableCopy] reversePropertyListString];


  mString->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) shellEscaped
{
  CLMutableString *mString = (CLMutableString *) [self shellEscapedIgnoreSpace];


  [mString replaceOccurrencesOfString:@" " withString:@"\\ "];
  ((CLString *) mString)->isa = CLStringClass;
  return mString;
}

-(CLString *) shellEscapedIgnoreSpace
{
  CLMutableString *mString = [self mutableCopy];


  [mString replaceOccurrencesOfString:@"\\" withString:@"\\\\"];
  [mString replaceOccurrencesOfString:@"(" withString:@"\\("];
  [mString replaceOccurrencesOfString:@")" withString:@"\\)"];
  [mString replaceOccurrencesOfString:@"$" withString:@"\\$"];
  [mString replaceOccurrencesOfString:@"\"" withString:@"\\\""];
  [mString replaceOccurrencesOfString:@"'" withString:@"\\'"];

  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

@end

@implementation CLString (CLStringNumeric)

-(BOOL) boolValue
{
  int i, j;
  unichar c = 0;


  CLCheckStringClass(self);
  for (i = 0, j = len; i < j; i++) {
    c = [self characterAtIndex:i];
    if (!iswspace(c) && c != '0' &&
	!(!i && (c == '+' || c == '-')))
      break;
  }

  if ((iswdigit(c) && (c - '0')) || towupper(c) == 'Y' || towupper(c) == 'T')
    return YES;

  if (![self caseInsensitiveCompare:@"on"])
    return YES;
  
  return NO;
}

-(int) intValue
{
  return [self longLongValue];
}

-(long) longValue
{
  return [self longLongValue];
}

-(long long) longLongValue
{
  return strtoll([self UTF8String], NULL, 0);  
}

-(unsigned int) unsignedIntValue
{
  return [self unsignedLongLongValue];
}

-(unsigned long) unsignedLongValue
{
  return [self unsignedLongLongValue];
}

-(unsigned long long) unsignedLongLongValue
{
  return strtoull([self UTF8String], NULL, 0);
}

-(double) doubleValue
{
  return atof([self UTF8String]);
}

@end

@implementation CLString (CLStringCase)

-(CLString *) lowercaseString
{
  CLMutableString *mString;


  /* FIXME - do some checks to see if there is anything to convert
     before creating a copy? */
  mString = [self mutableCopy];
  [mString lowercase];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) uppercaseString
{
  CLMutableString *mString;


  /* FIXME - do some checks to see if there is anything to convert
     before creating a copy? */
  mString = [self mutableCopy];
  [mString uppercase];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) lowerCamelCaseString
{
  CLMutableString *mString;


  /* FIXME - do some checks to see if there is anything to convert
     before creating a copy? */
  mString = [self mutableCopy];
  [mString lowerCamelCase];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) upperCamelCaseString
{
  CLMutableString *mString;


  /* FIXME - do some checks to see if there is anything to convert
     before creating a copy? */
  mString = [self mutableCopy];
  [mString upperCamelCase];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

-(CLString *) underscore_case_string
{
  CLMutableString *mString;


  /* FIXME - do some checks to see if there is anything to convert
     before creating a copy? */
  mString = [self mutableCopy];
  [mString underscore_case];
  ((CLString *) mString)->isa = CLStringClass;
  return [mString autorelease];
}

@end

@implementation CLString (CLStringFormatting)

+(id) stringWithFormat:(CLString *) format, ...
{
  va_list ap;
  CLString *aString;


  va_start(ap, format);
  aString = [[self alloc] initWithFormat:format arguments:ap];
  va_end(ap);
  return [aString autorelease];
}

-(id) initWithFormat:(CLString *) format, ...
{
  va_list ap;
  CLString *aString;


  va_start(ap, format);
  aString = [self initWithFormat:format arguments:ap];
  va_end(ap);
  return aString;
}

-(id) initWithFormat:(CLString *) format arguments:(va_list) argList
{
  char *str;


  vasprintf(&str, [format UTF8String], argList);
  return [self initWithBytesNoCopy:str length:strlen(str) encoding:CLUTF8StringEncoding];
}

-(CLString *) stringByAppendingFormat:(CLString *) format, ...
{
  va_list ap;
  CLString *aString;


  va_start(ap, format);
  aString = [[CLString alloc] initWithFormat:format arguments:ap];
  va_end(ap);
  CLStringReplaceString(aString, CLMakeRange(0, 0), self);
  return [aString autorelease];
}

@end

@implementation CLString (CLStringMisc)

-(void) getCharacters:(unichar *) buffer
{
  CLCheckStringClass(self);
  [self getCharacters:buffer range:CLMakeRange(0, len)];
  return;
}

@end

@implementation CLString (CLStringURL)

-(CLString *) urlProtocol
{
  CLRange aRange;


  aRange = [self rangeOfString:@":"];
  if (!aRange.length)
    return nil;
  return [self substringToIndex:aRange.location];
}

-(CLString *) urlServer
{
  CLRange aRange, aRange2;


  CLCheckStringClass(self);
  aRange = [self rangeOfString:@"://"];
  if (!aRange.length)
    return nil;
  aRange2.location = CLMaxRange(aRange);
  aRange2.length = len - aRange2.location;
  aRange2 = [self rangeOfString:PATHSEP_STRING options:0 range:aRange2];
  if (!aRange2.length)
    return [self substringFromIndex:CLMaxRange(aRange)];

  aRange.location = CLMaxRange(aRange);
  aRange.length = aRange2.location - aRange.location;
  return [self substringWithRange:aRange];
}

-(CLString *) urlHost
{
  CLString *aString = [self urlServer];
  CLRange aRange;


  if (!aString)
    return nil;

  aRange = [aString rangeOfString:@"@"];
  if (aRange.length)
    aString = [aString substringFromIndex:CLMaxRange(aRange)];

  aRange = [aString rangeOfString:@":"];
  if (aRange.length)
    aString = [aString substringToIndex:aRange.location];

  return aString;
}

-(CLString *) urlPort
{
  CLString *aString = [self urlServer];
  CLRange aRange;


  if (!aString)
    return nil;

  aRange = [aString rangeOfString:@"@"];
  if (aRange.length)
    aString = [aString substringFromIndex:CLMaxRange(aRange)];

  aRange = [aString rangeOfString:@":"];
  if (aRange.length)
    return [aString substringFromIndex:CLMaxRange(aRange)];

  return nil;
}

-(CLString *) urlUser
{
  CLString *aString = [self urlServer];
  CLRange aRange;


  if (!aString)
    return nil;

  aRange = [aString rangeOfString:@"@"];
  if (!aRange.length)
    return nil;

  aString = [aString substringToIndex:aRange.location];

  aRange = [aString rangeOfString:@":"];
  if (aRange.length)
    return [aString substringToIndex:aRange.location];

  return aString;
}

-(CLString *) urlPassword
{
  CLString *aString = [self urlServer];
  CLRange aRange;


  if (!aString)
    return nil;

  aRange = [aString rangeOfString:@"@"];
  if (!aRange.length)
    return nil;

  aString = [aString substringToIndex:aRange.location];

  aRange = [aString rangeOfString:@":"];
  if (aRange.length)
    return [aString substringFromIndex:CLMaxRange(aRange)];

  return nil;
}

-(CLString *) urlPath
{
  CLRange aRange, aRange2;


  aRange = [self rangeOfString:@"://"];
  if (!aRange.length)
    return self;
  
  CLCheckStringClass(self);
  aRange2.location = CLMaxRange(aRange);
  aRange2.length = len - aRange2.location;
  aRange2 = [self rangeOfString:PATHSEP_STRING options:0 range:aRange2];
  if (!aRange2.length)
    return nil;

  return [self substringFromIndex:aRange2.location];
}

-(CLString *) urlBase
{
  CLRange aRange, aRange2;


  aRange = [self rangeOfString:@"://"];
  if (!aRange.length)
    return self;
  
  CLCheckStringClass(self);
  aRange2.location = CLMaxRange(aRange);
  aRange2.length = len - aRange2.location;
  aRange2 = [self rangeOfString:PATHSEP_STRING options:0 range:aRange2];
  if (!aRange2.length)
    return self;

  return [self substringToIndex:aRange2.location];
}

-(BOOL) isURL
{
  CLRange aRange, aRange2;
  CLCharacterSet *alphaSet;


  CLCheckStringClass(self);
  aRange = [self rangeOfString:@"://" options:0 range:CLMakeRange(0, len)];
  if (aRange.length) {
    alphaSet = [CLCharacterSet characterSetWithCharactersInString:
				 @"abcdefghijklmnopqrstuvwxyz"];
    aRange2 = [self rangeOfCharacterNotFromSet:alphaSet options:0
		    range:CLMakeRange(0, len)];
    if (aRange2.location == aRange.location)
      return YES;
  }

  return NO;
}

@end

@implementation CLString (CLStringLanguage)

static const char *CLMPVowels = "AEIOU";
static const char *CLMPFrontV = "EIY";
static const char *CLMPVarSon = "CSPTG";
static const char *CLMPDouble = ".";

static const char *CLMPExcPair = "AGKPW";
static const char *CLMPNextLtr = "ENNNR";

-(CLString *) englishMetaphoneString
{
  int ii, jj, silent, hard, Lng, lastChr;
  char curLtr, prevLtr, nextLtr, nextLtr2, nextLtr3;
  int vowelAfter, vowelBefore, frontvAfter;
  char *ename;
  const char *name;
  CLData *aData;
  CLMutableData *mData;
  const char *chrptr, *chrptr1;
  CLMutableString *metaph;


  /* Convert to ASCII then to uppercase in case of any bizarre accented characters */
  aData = [self dataUsingEncoding:CLASCIIStringEncoding allowLossyConversion:YES];
  name = [aData bytes];
  mData = [CLMutableData dataWithLength:[aData length] + 1];
  ename = [mData mutableBytes];
  
  for (ii = jj = 0, Lng = [aData length]; ii < Lng; ii++) {
    if (isalpha(name[ii])) {
      ename[jj] = toupper(name[ii]);
      jj++;
    }
  }
  ename[jj] = 0;

  if (!jj)
    return nil;

  metaph = [[CLMutableString alloc] init];
  
  /* if AE, GN, KN, PN, WR then drop the first letter */
  if ((chrptr = strchr(CLMPExcPair, ename[0]))) {
    chrptr1 = CLMPNextLtr + (chrptr - CLMPExcPair);
    if (*chrptr1 == ename[1])
      strcpy(ename, &ename[1]);
  }
  /* change X to S */
  if (ename[0] == 'X')
    ename[0] = 'S';
  /* get rid of the "H" in "WH" */
  if (strncmp(ename, "WH", 2) == 0)
    strcpy(&ename[1], &ename[2]);

  Lng = strlen(ename);
  lastChr = Lng -1;   /* index to last character in string makes code easier */

  /* Remove an S from the end of the string */
  if (ename[lastChr] == 'S') {
    ename[lastChr] = '\0';
    Lng--;
    lastChr = Lng - 1;
  }

  for (ii = 0; ii < Lng; ii++) {
    curLtr = ename[ii];
    vowelBefore = NO;
    prevLtr = ' ';
      
    if (ii > 0) {
      prevLtr = ename[ii-1];
      if (strchr(CLMPVowels, prevLtr))
	vowelBefore = YES;
    }
    /* if first letter is a vowel KEEP it */
    if (ii == 0 && strchr(CLMPVowels, curLtr)) {
      [metaph appendCharacter:curLtr];
      continue;
    }

    vowelAfter = NO;
    frontvAfter = NO;
    nextLtr = ' ';
    if (ii < lastChr) {
      nextLtr = ename[ii+1];
      if (strchr(CLMPVowels, nextLtr))
	vowelAfter = YES;
      if (strchr(CLMPFrontV, nextLtr))
	frontvAfter = YES;
    }
    /* skip double letters except ones in list */
    if (curLtr == nextLtr && !strchr(CLMPDouble, nextLtr))
      continue;

    nextLtr2 = ' ';
    if (ii < lastChr-1)
      nextLtr2 = ename[ii+2];

    nextLtr3 = ' ';
    if (ii < lastChr-2)
      nextLtr3 = ename[ii+3];

    switch (curLtr) {
    case 'B':
      silent = NO;
      if (ii == lastChr && prevLtr == 'M')
	silent = YES;
      if (!silent)
	[metaph appendCharacter:curLtr];
      break;

      /*silent -sci-,-sce-,-scy-;  sci-, etc OK*/
    case 'C':
      if (!(ii > 1 && prevLtr == 'S' && frontvAfter)) {
	if (ii > 0 && nextLtr == 'I' && nextLtr2 == 'A')
	  [metaph appendCharacter:'X'];
	else {
	  if (frontvAfter)
	    [metaph appendCharacter:'S'];
	  else {
	    if (ii > 1 && prevLtr == 'S' && nextLtr == 'H')
	      [metaph appendCharacter:'K'];
	    else {
	      if (nextLtr == 'H') {
		if (ii == 0 && !strchr(CLMPVowels, nextLtr2))
		  [metaph appendCharacter:'K'];
		else
		  [metaph appendCharacter:'X'];
	      }
	      else {
		if (prevLtr == 'C')
		  [metaph appendCharacter:'C'];
		else
		  [metaph appendCharacter:'K'];
	      }
	    }
	  }
	}
      }
      break;

    case 'D':
      if (nextLtr == 'G' && strchr(CLMPFrontV, nextLtr2))
	[metaph appendCharacter:'J'];
      else
	[metaph appendCharacter:'T'];
      break;

    case 'G':
      silent = NO;
      /* SILENT -gh- except for -gh and no vowel after h */
      if (ii < (lastChr-1) && nextLtr == 'H' && !strchr(CLMPVowels, nextLtr2))
	silent = YES;

      if (ii == lastChr-3 && nextLtr == 'N' && nextLtr2 == 'E' && nextLtr3 == 'D')
	silent = YES;
      else
	if (ii == lastChr-1 && nextLtr == 'N')
	  silent = YES;

      if (prevLtr == 'D' && frontvAfter)
	silent = YES;

      if (prevLtr == 'G')
	hard = YES;
      else
	hard = NO;

      if (!silent) {
	if (frontvAfter && !hard)
	  [metaph appendCharacter:'J'];
	else
	  [metaph appendCharacter:'K'];
      }
      break;

    case 'H':
      silent = NO;
      if (strchr(CLMPVarSon, prevLtr))
	silent = YES;

      if (vowelBefore && !vowelAfter)
	silent = YES;

      if (!silent)
	[metaph appendCharacter:curLtr];
      break;

    case 'F':
    case 'J':
    case 'L':
    case 'M':
    case 'N':
    case 'R':
      [metaph appendCharacter:curLtr];
      break;

    case 'K':
      if (prevLtr != 'C')
	[metaph appendCharacter:curLtr];
      break;

    case 'P':
      if (nextLtr == 'H')
	[metaph appendCharacter:'F'];
      else
	[metaph appendCharacter:'P'];
      break;

    case 'Q':
      [metaph appendCharacter:'K'];
      break;

    case 'S':
      if (ii > 1 && nextLtr == 'I' && (nextLtr2 == 'O' || nextLtr2 == 'A'))
	[metaph appendCharacter:'X'];
      else {
	if (nextLtr == 'H')
	  [metaph appendCharacter:'X'];
	else
	  [metaph appendCharacter:'S'];
      }
      break;

    case 'T':
      if (ii > 1 && nextLtr == 'I' && (nextLtr2 == 'O' || nextLtr2 == 'A'))
	[metaph appendCharacter:'X'];
      else {
	if (nextLtr == 'H') {       /* The=0, Tho=T, Withrow=0 */
	  if (ii > 0 || strchr(CLMPVowels, nextLtr2))
	    [metaph appendCharacter:'0'];
	  else
	    [metaph appendCharacter:'T'];
	}
	else if (!(ii < lastChr-2 && nextLtr == 'C' && nextLtr2 == 'H'))
	  [metaph appendCharacter:'T'];
      }
      break;

    case 'V':
      [metaph appendCharacter:'F'];
      break;

    case 'W':
    case 'Y':
      if (ii < lastChr && vowelAfter)
	[metaph appendCharacter:curLtr];
      break;

    case 'X':
      [metaph appendString:@"KS"];
      break;

    case 'Z':
      [metaph appendCharacter:'S'];
      break;
    }
  }

  ((CLString *) metaph)->isa = CLStringClass;
  return [metaph autorelease];
}

-(CLString *) englishMetaphoneWords
{
  CLAutoreleasePool *pool;
  CLMutableArray *mArray;
  CLString *aString;
  CLArray *anArray;
  int i, j;


  pool = [[CLAutoreleasePool alloc] init];
  mArray = [[CLMutableArray alloc] init];
  anArray = [self componentsSeparatedByCharactersInSet:
		    [CLCharacterSet whitespaceAndNewlineCharacterSet]];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    if ([aString length]) {
      aString = [aString englishMetaphoneString];
      if ([aString length])
	[mArray addObject:aString];
    }
  }
  aString = [[mArray componentsJoinedByString:@" "] retain];
  [mArray release];
  [pool release];

  return [aString autorelease];
}

@end

static int CLPrintObject(FILE *stream, const struct printf_info *info,
			const void *const *args)
{
  id anObject;
  int len;
  const char *p;
  

  anObject = *((id *) (args[0]));

  /* FIXME - look at info and type of object and format correctly */
  if (!(p = [[anObject description] UTF8String]))
    p = "(nil)";

  if (info->width) {
    len = info->width;
    if (info->left)
      len = -len;
    len = fprintf(stream, "%*s", len, p);
  }
  else
    len = fprintf(stream, "%s", p);
  
  return len;
}

#define PA_OBJECT	PA_LAST

#if HAVE_REGISTERPRINTFSPECIFIER
static int CLPrintObjectArgInfo(const struct printf_info *info, size_t n,
				int *argtypes, int *size)
#else
static int CLPrintObjectArgInfo(const struct printf_info *info, size_t n,
				int *argtypes)
#endif
{
  if (n > 0) {
    argtypes[0] = PA_OBJECT|PA_FLAG_PTR;
#if HAVE_REGISTERPRINTFSPECIFIER
    size[0] = sizeof(id);
#endif
  }
  return 1;
}
