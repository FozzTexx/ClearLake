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

#import "CLValidation.h"
#import "CLString.h"
#import "CLStream.h"
#import "CLCharacterSet.h"

#include <stdlib.h>
#include <ctype.h>
#include <time.h>

/* FIXME - can non ascii characters be valid in an email address? */
static CLString *validEmailChars =
  @"0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz!#$%&'*+-/=?^_`{|}~.";

BOOL CLHasDNSRecord(CLString *type, CLString *host)
{
  FILE *file;
  CLString *aString;


  aString = [CLString stringWithFormat:
			@"/usr/bin/dig -t %@ '%@' | egrep -v '^;' | grep '\t%@\t'",
		      type, host, type];
  file = popen([aString UTF8String], "r");
  while ((aString = CLGets(file, CLUTF8StringEncoding)))
    if ([aString length])
      break;
  pclose(file);

  return !![aString length];
}  
  
BOOL CLValidEmailAddress(CLString *anAddress)
{
  CLRange aRange, aRange2;
  CLCharacterSet *notGoodSet;
  CLString *local, *host;
  CLUInteger len;


  if (![anAddress length])
    return NO;
  
  aRange = [anAddress rangeOfString:@"@" options:0 range:CLMakeRange(0, [anAddress length])];
  if (!aRange.length)
    return NO;

  local = [anAddress substringToIndex:aRange.location];
  host = [anAddress substringFromIndex:CLMaxRange(aRange)];
  if (![local length] || ![host length])
    return NO;
  
  notGoodSet = [[CLCharacterSet characterSetWithCharactersInString:validEmailChars]
		 invertedSet];
  aRange = [local rangeOfCharacterFromSet:notGoodSet];
  if (aRange.length)
    return NO;
  
  if (CLHasDNSRecord(@"MX", host) || CLHasDNSRecord(@"A", host))      
    return YES;

  len = [host length];
  aRange.location = 0;
  aRange.length = len;
  for (;;) {
    aRange2.location = CLMaxRange(aRange);
    aRange2.length = len - aRange2.location;
    aRange2 = [host rangeOfString:@"." options:0 range:aRange2];
    if (!aRange2.length)
      return NO;

    if (CLHasDNSRecord(@"MX", [CLString stringWithFormat:@"*%@",
					[host substringFromIndex:aRange2.location]]))
      return YES;

    aRange = aRange2;
  }
  
  return NO;
}

BOOL CLValidCreditCard(CLString *aCCNumber, CLUInteger month, CLUInteger year)
{
  char ccNum[20];
  unichar *buf;
  CLUInteger len, maxlen;
  int ccPos;
  struct tm *tp;
  time_t t;
  int i, j, k;
  BOOL valid = YES;
  const char *p;


  ccPos = 0;
  if ((len = [aCCNumber length])) {
    buf = malloc(sizeof(unichar) * len);
    [aCCNumber getCharacters:buf];
    maxlen = sizeof(ccNum) - 1;

    /* Using isdigit and not iswdigit cuz I'm only interested in ASCII digits */
    for (i = 0; i < len && i < maxlen; i++)
      if (isdigit(buf[i]))
	ccNum[ccPos++] = buf[i];
    free(buf);
  }
  ccNum[ccPos] = 0;

  if (ccNum[0] != '3' && ccNum[0] != '4' && ccNum[0] != '5')
    valid = NO;
  
  if (valid &&
      ((ccNum[0] == '3' && ccPos != 15) ||
       (ccNum[0] == '4' && ccPos != 13 && ccPos != 16) ||
       (ccNum[0] == '5' && ccPos != 16)))
    valid = NO;

  if (valid) {
    for (p = ccNum, j = strlen(ccNum) % 2, k = 0; p && *p; p++, j++) {
      i = (*p) - '0';
      if (!(j % 2)) {
	i *= 2;
	if (i > 9)
	  i -= 9;
	k += i;
      }
      else
	k += i;
    }
    if (k % 10)
      valid = NO;
  }

  if (valid) {
    t = time(NULL);
    tp = localtime(&t);
    if (year < tp->tm_year + 1900 ||
	(tp->tm_year + 1900 == year && month < tp->tm_mon + 1) ||
	year > tp->tm_year + 1910)
      valid = NO;
  }

  return valid;
}
