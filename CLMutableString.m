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

#import "CLMutableString.h"
#import "CLStringFunctions.h"

#include <stdlib.h>
#include <stdarg.h>
#include <ctype.h>
#include <string.h>

#define PATHSEP_CHAR	'/'
#define PATHSEP_STRING	@"/"

#define hexval(c) ({int _c = c; toupper(_c) - '0' - (_c > '9' ? 7 : 0);})

@implementation CLMutableString

-(id) copy
{
  return [self mutableCopy];
}

-(void) replaceCharactersInRange:(CLRange) aRange withString:(CLString *) aString
{
  CLStringReplaceCharacters(self, aRange, aString);
  return;
}

-(CLString *) reversePropertyListString
{
  CLStringStorage *stor;
  CLUInteger i;

    
  stor = CLStorageForString(self);
  for (i = 0; len && i < len - 1; i++)
    if (stor->str[i] == '\\') {
      memmove(&stor->str[i], &stor->str[i+1], (len - (i+1)) * sizeof(unichar));
      len--;
      switch (stor->str[i]) {
      case 'b':
	stor->str[i] = '\b';
	break;

      case 'f':
	stor->str[i] = '\f';
	break;

      case 'n':
	stor->str[i] = '\n';
	break;

      case 'r':
	stor->str[i] = '\r';
	break;

      case 't':
	stor->str[i] = '\t';
	break;

      case 'u':
	{
	  unichar c = 0;
	  int n;


	  /* Not using wide tests here cuz it's too complicated */
	  for (n = 0; n < 4 && i+n+1 < len && isxdigit(stor->str[i+n+1]); n++) {
	    c *= 16;
	    c += hexval(stor->str[i+n+1]);
	  }
	  
	  stor->str[i] = c;
	  memmove(&stor->str[i+1], &stor->str[i+n+1], (len - (i+n+1)) * sizeof(unichar));
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
  CLStringReplaceCharacters(self, CLMakeRange(anIndex, 0), aString);
  return;
}

-(void) setString:(CLString *) aString
{
  CLStringReplaceCharacters(self, CLMakeRange(0, len), aString);
  return;
}

-(void) setCharacters:(unichar *) aBuffer length:(CLUInteger) length
{
  CLStringStorage *stor;


  stor = data;
  if (len < length && !(stor->str = realloc(stor->str, length * sizeof(unichar))))
    [self error:@"Unable to allocate memory"];
  len = length;
  wmemmove(stor->str, aBuffer, len);
  return;
}

-(void) deleteCharactersInRange:(CLRange) aRange
{
  CLStringReplaceCharacters(self, aRange, nil);
  return;
}

-(void) appendCharacter:(unichar) aChar
{
  CLStringStorage *stor;


  stor = data;
  if (len+1 >= stor->maxLen) {
    stor->maxLen += 32;
    if (!(stor->str = realloc(stor->str, stor->maxLen * sizeof(unichar))))
      [self error:@"Unable to allocate memory"];
  }
  stor->str[len] = aChar;
  len++;
  return;
}

-(void) appendString:(CLString *) aString
{
  CLStringReplaceCharacters(self, CLMakeRange(len, 0), aString);
  return;
}

-(void) appendFormat:(CLString *) format, ...
{
  CLString *aString;
  va_list ap;


  va_start(ap, format);
  aString = [[CLString alloc] initWithFormat:format arguments:ap];
  va_end(ap);
  [self appendString:aString];
  [aString release];
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
    CLStringReplaceCharacters(self, aRange, replacement);
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


  if (![self length]) {
    [self setString:aString];
    return;
  }
  
  for (i = 0, j = [aString length]; i < j; i++)
    if ([aString characterAtIndex:i] != PATHSEP_CHAR)
      break;

  for (j = [self length]; j; j--)
    if ([self characterAtIndex:j-1] != PATHSEP_CHAR)
      break;

  [self setString:[CLString stringWithFormat:@"%@/%@", [self substringToIndex:j],
			    [aString substringFromIndex:i]]];
}

-(void) appendPathExtension:(CLString *) ext
{
  if ([self length] && [self characterAtIndex:[self length] - 1] == PATHSEP_CHAR)
    [self setString: [[self substringToIndex:[self length] - 1]
		       stringByAppendingFormat:@".%@", ext]];
  else
    [self appendFormat:@".%@", ext];
  return;
}

@end
