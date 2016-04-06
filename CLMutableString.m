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

#import "CLMutableString.h"
#import "CLStringFunctions.h"
#import "CLStackString.h"
#import "CLEntities.h"
#import "CLStackString.h"

#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <string.h>
#include <errno.h>

#define PATHSEP_CHAR	'/'
#define PATHSEP_STRING	@"/"

#define hexval(c) ({int _c = c; toupper(_c) - '0' - (_c > '9' ? 7 : 0);})

static char *hex = "0123456789ABCDEF";
static char *goodurl = ".0123456789-ABCDEFGHIJKLMNOPQRSTUVWXYZ_abcdefghijklmnopqrstuvwxyz";

@implementation CLMutableString

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLMutableString *aString = [self mutableCopy];
  extern int CLLeakPrint;


  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx copy %s - 0x%lx %s:%i %i\n",
	    (unsigned long) self, className, (unsigned long) retainer,
	    file, line, [self retainCount] + 1);
    CLLeakPrint = pl;
  }

  aString->isa = CLStringClass;
  return aString;
}
#define copy		copy:__FILE__ :__LINE__ :self
#else
-(id) copy
{
  CLMutableString *aString = [self mutableCopy];


  aString->isa = CLStringClass;
  return aString;
}
#endif

-(void) replaceCharactersInRange:(CLRange) aRange withString:(CLString *) aString
{
  CLStringReplaceString(self, aRange, aString);
  return;
}

-(CLString *) reversePropertyListString
{
  CLUInteger i;
  unistr *ustr;

    
  CLCheckStringClass(self);
  ustr = (unistr *) self;
  for (i = 0; len && i < len - 1; i++)
    if (ustr->str[i] == '\\') {
      memmove(&ustr->str[i], &ustr->str[i+1], (len - (i+1)) * sizeof(unichar));
      len--;
      switch (ustr->str[i]) {
      case 'b':
	ustr->str[i] = '\b';
	break;

      case 'f':
	ustr->str[i] = '\f';
	break;

      case 'n':
	ustr->str[i] = '\n';
	break;

      case 'r':
	ustr->str[i] = '\r';
	break;

      case 't':
	ustr->str[i] = '\t';
	break;

      case 'u':
	{
	  unichar c = 0;
	  int n;


	  /* Not using wide tests here cuz it's too complicated */
	  for (n = 0; n < 4 && i+n+1 < len && isxdigit(ustr->str[i+n+1]); n++) {
	    c *= 16;
	    c += hexval(ustr->str[i+n+1]);
	  }
	  
	  ustr->str[i] = c;
	  memmove(&ustr->str[i+1], &ustr->str[i+n+1], (len - (i+n+1)) * sizeof(unichar));
	  len -= n;
	}
	break;
      }
    }

  return self;
}

@end

@implementation CLMutableString (CLMutableStringAdditions)

-(void) insertString:(CLString *) aString atIndex:(CLUInteger) anIndex
{
  [self replaceCharactersInRange:CLMakeRange(anIndex, 0) withString:aString];
  return;
}

-(void) setString:(CLString *) aString
{
  [self replaceCharactersInRange:CLMakeRange(0, len) withString:aString];
  return;
}

-(void) setCharacters:(unichar *) aBuffer length:(CLUInteger) length
{
  unistr stackStr;


  stackStr = CLMakeStackString(aBuffer, length);
  [self setString:(CLString *) &stackStr];
  return;
}

-(void) setFormat:(CLString *) format, ...
{
  va_list ap;


  len = 0;
  va_start(ap, format);
  [self appendFormat:format arguments:ap];
  va_end(ap);
  return;
}

-(void) deleteCharactersInRange:(CLRange) aRange
{
  [self replaceCharactersInRange:aRange withString:nil];
  return;
}

-(void) appendCharacter:(unichar) aChar
{
  CLStringAppendCharacter(self, aChar, self);
}

-(void) insertCharacter:(unichar) aChar atIndex:(CLUInteger) anIndex
{
  unistr ustr;


  ustr = CLNewStackString(1);
  ustr.str[0] = aChar;
  ustr.len = 1;
  [self insertString:(CLMutableStackString *) &ustr atIndex:anIndex];
  return;
}

-(void) appendString:(CLString *) aString
{
  [self replaceCharactersInRange:CLMakeRange(len, 0) withString:aString];
  return;
}

-(void) appendFormat:(CLString *) format, ...
{
  va_list ap;


  va_start(ap, format);
  [self appendFormat:format arguments:ap];
  va_end(ap);
  return;
}

-(void) appendFormat:(CLString *) format arguments:(va_list) argList
{
  char *str;
  char *buf;
  CLUInteger blen;
  unistr output;


  vasprintf(&str, [format UTF8String], argList);

  CLStringConvertEncoding(str, strlen(str), CLUTF8StringEncoding,
			  &buf, &blen, CLUnicodeStringEncoding, NO);
  output._reserved = CLImmutableStackStringClass;
  output.len = blen / sizeof(unichar);
  output.str = (unichar *) buf;
  [self appendString:(CLString *) &output];
  free(buf);
  free(str);
  return;
}

-(CLUInteger) replaceOccurrencesOfString:(CLString *) target
			      withString:(CLString *) replacement
{
  return [self replaceOccurrencesOfString:target withString:replacement
	       options:0 range:CLMakeRange(0, len)];
}

-(CLUInteger) replaceOccurrencesOfString:(CLString *) target
			      withString:(CLString *) replacement
				 options:(CLStringCompareOptions) options
				   range:(CLRange) range
{
  CLRange aRange;
  int replaced = 0;


  aRange = [self rangeOfString:target options:options range:range];
  while (aRange.length) {
    replaced++;
    CLStringReplaceString(self, aRange, replacement);
    range.length += replacement->len - target->len;
    aRange.location = aRange.location + replacement->len;
    aRange.length = range.location + range.length - aRange.location;
    aRange = [self rangeOfString:target options:options range:aRange];
  }

  return replaced;
}

@end

@implementation CLMutableString (CLStringPaths)

-(void) appendPathComponent:(CLString *) aString
{
  CLUInteger i, j;
  unistr *ustr, pstr;


  CLCheckStringClass(aString);
  ustr = (unistr *) self;
  pstr = CLCloneStackString(aString);
  for (i = 0, j = pstr.len; i < j; i++)
    if (pstr.str[i] != PATHSEP_CHAR)
      break;

  for (j = ustr->len; j; j--)
    if (ustr->str[j-1] != PATHSEP_CHAR)
      break;

  ustr->len = j;
  pstr.str = &pstr.str[i];
  pstr.len -= i;
  [self appendFormat:@"/%@", &pstr];
  return;
}

-(void) appendPathExtension:(CLString *) ext
{
  unistr *ustr;

  
  ustr = (unistr *) self;
  if (len && ustr->str[len-1] == PATHSEP_CHAR)
    len--;

  [self appendFormat:@".%@", ext];
  return;
}

-(void) deleteLastPathComponent
{
  CLRange sRange, sRange2;


  sRange = [self rangeOfString:PATHSEP_STRING options:CLBackwardsSearch
		 range:CLMakeRange(0, len)];
  if (!sRange.length)
    len = 0;
  else {
    sRange2 = [self rangeOfString:PATHSEP_STRING options:CLBackwardsSearch
			    range:CLMakeRange(0, sRange.location)];
    if (sRange.location == len - 1) {
      if (sRange2.location == 0)
	len = 1;
      else
	len = sRange2.location;
    }
    else if (sRange.location == 0)
      len = 1;
    else
      len = sRange.location;
  }

  return;
}

-(void) deletePathExtension
{
  CLRange pRange, sRange;


  sRange = CLMakeRange(0, len);
  pRange = [self rangeOfString:@"." options:CLBackwardsSearch range:sRange];
  sRange = [self rangeOfString:PATHSEP_STRING options:CLBackwardsSearch range:sRange];
  if (pRange.length && pRange.location &&
      (!sRange.length ||
       sRange.location < pRange.location || sRange.location == len - 1))
    len = pRange.location;
  else if (sRange.length && sRange.location == len - 1)
    len = sRange.location;

  return;
}

-(void) deletePathPrefix:(CLString *) aPrefix
{
  int length;

  
  if (![self hasPathPrefix:aPrefix])
    return;

  CLCheckStringClass(aPrefix);
  length = aPrefix->len;
  if (![aPrefix hasSuffix:@"/"] && length < len)
    length++;
  [self deleteCharactersInRange:CLMakeRange(0, length)];
  return;
}

@end

@implementation CLMutableString (CLStringCase)

-(void) lowercase
{
  unistr *ustr;
  int i;
  CLStringStorage *stor;


  stor = CLStorageForString(self);
  if (stor->utf8) {
    free(stor->utf8);
    stor->utf8 = NULL;
  }
  
  ustr = (unistr *) self;
  for (i = 0; i < ustr->len; i++)
    ustr->str[i] = towlower(ustr->str[i]);

  return;
}

-(void) uppercase
{
  unistr *ustr;
  int i;
  CLStringStorage *stor;


  stor = CLStorageForString(self);
  if (stor->utf8) {
    free(stor->utf8);
    stor->utf8 = NULL;
  }
  
  ustr = (unistr *) self;
  for (i = 0; i < ustr->len; i++)
    ustr->str[i] = towupper(ustr->str[i]);
  return;
}

-(void) lowerCamelCase
{
  unistr *ustr;
  int i;
  CLStringStorage *stor;


  stor = CLStorageForString(self);
  if (stor->utf8) {
    free(stor->utf8);
    stor->utf8 = NULL;
  }
  
  ustr = (unistr *) self;
  for (i = 0; i < ustr->len; i++) {
    if (!i)
      ustr->str[i] = towlower(ustr->str[i]);
    else if (ustr->str[i] == '_' && i+1 < ustr->len && iswalpha(ustr->str[i+1])) {
      wmemmove(&ustr->str[i], &ustr->str[i+1], ustr->len - i - 1);
      ustr->len--;
      ustr->str[i] = towupper(ustr->str[i]);
      /* Special case _id to ID */
      if (i+2 == ustr->len && ustr->str[i] == 'I' && ustr->str[i+1] == 'd')
	ustr->str[i+1] = towupper(ustr->str[i+1]);
    }
  }

  return;
}

-(void) upperCamelCase
{
  unistr *ustr;


  [self lowerCamelCase];
  ustr = (unistr *) self;
  if (ustr->len)
    ustr->str[0] = towupper(ustr->str[0]);
  return;
}

-(void) underscore_case
{
  unistr *ustr;
  int i, cnt;
  CLStringStorage *stor;


  stor = CLStorageForString(self);
  if (stor->utf8) {
    free(stor->utf8);
    stor->utf8 = NULL;
  }
  
  ustr = (unistr *) self;
  for (i = cnt = 0; i < ustr->len; i++)
    if (i && iswupper(ustr->str[i]))
      cnt++;

  if (!cnt)
    return;

  data = CLStringAllocateBuffer(data, len+cnt, NULL, self);
  for (i = 0; i < ustr->len; i++) {
    if (i && iswupper(ustr->str[i])) {
      wmemmove(&ustr->str[i+1], &ustr->str[i], ustr->len - i);
      ustr->len++;
      ustr->str[i+1] = towlower(ustr->str[i+1]);
      ustr->str[i] = '_';
      i++;
      /* Special case "ID" to "_id" */
      if (i+2 == ustr->len && ustr->str[i] == 'i' && ustr->str[i+1] == 'D')
	ustr->str[i+1] = towlower(ustr->str[i+1]);
    }
    else
      ustr->str[i] = towlower(ustr->str[i]);
  }

  return;
}

@end

@implementation CLMutableString (CLStringEncodings)

-(void) encodeEntities:(int) max
{
  unichar c;
  int ent, pos;
  unistr *ustr, estr, fstr;


  ustr = (unistr *) self;
  fstr = CLNewStackString(30);
  for (pos = ustr->len - 1; pos >= 0; pos--) {
    c = ustr->str[pos];
    for (ent = 0; CLEntities[ent].c; ent++)
      if (c == CLEntities[ent].c)
	break;

    estr.len = 0;
    if (CLEntities[ent].c && (!max || ent < max))
      estr = CLCloneStackString(CLEntities[ent].entity);
    else if (c >= 0x80) {
      fstr.len = 0;
      [((CLMutableString *) &fstr) appendFormat:@"&#%d;", c];
      estr = fstr;
    }

    if (estr.len)
      [self replaceCharactersInRange:CLMakeRange(pos, 1) withString:(CLString *) &estr];
  }

  return;
}

-(void) encodeEntities
{
  [self encodeEntities:0];
  return;
}

-(void) encodeXMLEntities
{
  /* FIXME - don't hardcode max XML entity */
  [self encodeEntities:5];
  return;
}

-(void) decodeEntities
{
  CLRange aRange;
  int i, val;
  unistr estr, *ustr, hexStr, istr;


  aRange = [self rangeOfString:@"&" options:0 range:CLMakeRange(0, len)];
  if (!aRange.length)
    return;

  estr = CLNewStackString(2);
  estr.len = 1;

  hexStr = CLNewStackString(30);
  
  for (i = 0; CLEntities[i].c; i++) {
    estr.str[0] = CLEntities[i].c;
    [self replaceOccurrencesOfString:CLEntities[i].entity withString:(CLString *) &estr
	     options:0 range:CLMakeRange(0, len)];
  }

  ustr = (unistr *) self;
  aRange = [((CLString *) ustr) rangeOfString:@"&#" options:0
					range:CLMakeRange(0, ustr->len)];
  while (aRange.length) {
    if (ustr->str[CLMaxRange(aRange)] == 'x') {
      for (i = CLMaxRange(aRange); i < ustr->len; i++)
	if (!iswxdigit(ustr->str[i]))
	  break;
    }
    else {
      for (i = CLMaxRange(aRange); i < ustr->len; i++)
	if (!iswdigit(ustr->str[i]))
	  break;
    }
    if (i < ustr->len && ustr->str[i] == ';') {
      if (ustr->str[CLMaxRange(aRange)] == 'x') {
	hexStr.len = 0;
	istr = CLMakeStackString(&ustr->str[CLMaxRange(aRange)+1],
				 ustr->len - CLMaxRange(aRange)+1);
	[((CLMutableString *) &hexStr) appendFormat:@"0x%@", (CLString *) &istr];
	val = [((CLString *) &hexStr) intValue];
      }
      else {
	istr = CLMakeStackString(&ustr->str[CLMaxRange(aRange)],
				 ustr->len - CLMaxRange(aRange));
	val = [((CLString *) &istr) intValue];
      }
      estr.str[0] = val;
      [((CLMutableString *) ustr)
	replaceCharactersInRange:CLMakeRange(aRange.location, i - aRange.location + 1)
		      withString:(CLString *) &estr];
      aRange.location++;
    }
    else
      aRange.location = i;
    aRange.length = ustr->len - aRange.location;
    aRange = [((CLString *) ustr) rangeOfString:@"&#" options:0 range:aRange];
  }

  return;
}

-(void) addPercentEscapes
{
  [self addPercentEscapesWithPlus:YES];
  return;
}

-(void) addPercentEscapesWithPlus:(BOOL) flag
{
  const char *utf8 = [self UTF8String];
  unichar *p;
  unistr percentStr;


 /* It's gonna be less than or equal to that */
  percentStr = CLNewStackString(strlen(utf8) * 3);
  
  for (p = percentStr.str; *utf8; p++, utf8++) {
    *p = *utf8;
    if (flag && *utf8 == ' ')
      *p = '+';
    else if (!strchr(goodurl, *utf8)) {
      *p++ = '%';
      *p++ = hex[((*utf8) >> 4) & 0xf];
      *p = hex[(*utf8) & 0xf];
    }
  }
  percentStr.len = p - percentStr.str;

  [self setString:(CLString *) &percentStr];
  return;
}

-(void) replacePercentEscapes
{
  unistr *ustr, npStr;
  unichar *src, *dest;
  

  ustr = (unistr *) self;
  npStr = CLNewStackString(ustr->len);

  for (dest = npStr.str, src = ustr->str; src < ustr->str + ustr->len; src++, dest++) {
    *dest = *src;
    if (*src == '+')
      *dest = ' ';
    else if (*src == '%') {
      *dest = hexval(*(src+1)) << 4 | hexval(*(src+2));
      src += 2;
    }
  }

  npStr.len = dest - npStr.str;
  [self setString:(CLString *) &npStr];
  return;
}

@end
