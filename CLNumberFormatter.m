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

#import "CLNumberFormatter.h"
#import "CLCharacterSet.h"
#import "CLMutableString.h"
#import "CLDecimalNumber.h"
#import "CLClassConstants.h"

@implementation CLNumberFormatter

+(CLNumberFormatter *) numberFormatterFromFormat:(CLString *) aFormat
{
  CLNumberFormatter *aFormatter;


  if (![aFormat length])
    return nil;
  
  aFormatter = [[[self alloc] init] autorelease];
  [aFormatter setFormat:aFormat];
  return aFormatter;
}

-(id) init
{
  [super init];
  prefix = suffix = @"";
  grouping = 0;
  multiplier = 1;
  leftMinDigits = 1;
  rightMinDigits = 2;
  rightMaxDigits = 2;
  return self;
}

-(void) dealloc
{
  [prefix release];
  [suffix release];
  [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLNumberFormatter *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->prefix = [prefix copy];
  aCopy->suffix = [suffix copy];
  aCopy->grouping = grouping;
  aCopy->rightMinDigits = rightMinDigits;
  aCopy->rightMaxDigits = rightMaxDigits;
  aCopy->leftMinDigits = leftMinDigits;
  aCopy->multiplier = multiplier;
  return aCopy;
}

-(void) setFormat:(CLString *) aFormat
{
  [format autorelease];
  format = [aFormat copy];
  return;
}

-(CLDecimalNumber *) parseFormat:(CLDecimalNumber *) aNumber
{
  CLCharacterSet *numSet, *notNumSet;
  CLRange aRange;
  CLString *numString, *leftString;
  unsigned int end;
  CLString *aFormat;
  int posneg;


  aRange = [format rangeOfString:@";"];
  posneg = [aNumber compare:[CLDecimalNumber zero]];
  if (aRange.length) {
    if (posneg > 0)
      aFormat = [format substringToIndex:aRange.location];
    else if (posneg < 0) {
      aFormat = [format substringFromIndex:CLMaxRange(aRange)];
      aRange = [aFormat rangeOfString:@";"];
      if (aRange.length)
	aFormat = [aFormat substringFromIndex:CLMaxRange(aRange)];
    }
    else {
      CLRange aRange2;
      
      
      aFormat = [format substringToIndex:aRange.location];
      aRange2.location = CLMaxRange(aRange);
      aRange2.length = [format length] - aRange2.location;
      aRange2 = [format rangeOfString:@";" options:0 range:aRange2];
      if (aRange2.length) {
	aRange.location = CLMaxRange(aRange);
	aRange.length = aRange2.location - aRange.location;
	aFormat = [format substringWithRange:aRange];
      }
    }
  }
  else
    aFormat = format;
  
  numSet = [CLCharacterSet characterSetWithCharactersInString:@"0123456789@#.,Ee"];
  notNumSet = [numSet invertedSet];

  aRange = [aFormat rangeOfCharacterFromSet:numSet];
  prefix = [[aFormat substringToIndex:aRange.location] retain];
  numString = [aFormat substringFromIndex:aRange.location];
  aRange = [numString rangeOfCharacterFromSet:notNumSet];
  if (aRange.length) {
    suffix = [[numString substringFromIndex:aRange.location] retain];
    numString = [numString substringToIndex:aRange.location];
  }

  if (posneg < 0) {
    if (!aRange.length)
      prefix = [prefix stringByAppendingString:@"-"];
    aNumber = [aNumber decimalNumberByMultiplyingBy:[CLDecimalNumber numberWithInt:-1]];
  }

  aRange = [numString rangeOfString:@"." options:0 range:CLMakeRange(0, [numString length])];
  if (aRange.length) {
    leftString = [numString substringToIndex:aRange.location];
    rightMaxDigits = rightMinDigits = [numString length] - CLMaxRange(aRange);
    end = aRange.location;
    aRange = [numString rangeOfString:@"#" options:0
			range:CLMakeRange(CLMaxRange(aRange),
					  [numString length] - CLMaxRange(aRange))];
    if (aRange.length)
      rightMinDigits = rightMaxDigits - ([numString length] - aRange.location);
  }
  else {
    rightMaxDigits = rightMinDigits = 0;
    end = [numString length];
    leftString = numString;
  }

  {
    int i, j;


    for (i = leftMinDigits = 0, j = [leftString length]; i < j; i++)
      if ([leftString characterAtIndex:i] == '0')
	leftMinDigits++;
  }
  
  aRange = [numString rangeOfString:@"," options:CLBackwardsSearch
		      range:CLMakeRange(0, [numString length])];
  if (aRange.length)
    grouping = end - CLMaxRange(aRange);

  aRange = [prefix rangeOfString:@"%" options:0 range:CLMakeRange(0, [prefix length])];
  if (!aRange.length)
    aRange = [suffix rangeOfString:@"%" options:0 range:CLMakeRange(0, [suffix length])];
  if (aRange.length)
    multiplier = 100;

  /* Per mille - UTF8 encoding of \u2030 */
  aRange = [prefix rangeOfString:@"\xE2\x80\xB0" options:0
		   range:CLMakeRange(0, [prefix length])];
  if (!aRange.length)
    aRange = [suffix rangeOfString:@"\xE2\x80\xB0" options:0
		     range:CLMakeRange(0, [suffix length])];
  if (aRange.length)
    multiplier = 1000;
  
  return aNumber;
}

-(CLString *) stringForObjectValue:(id) anObject
{
  CLString *aString = nil, *numString;
  CLString *iString, *dString;
  CLRange aRange;
  CLMutableString *mString;
  unsigned int i, j;

  
  if (![anObject isKindOfClass:CLDecimalNumberClass])
    anObject = [CLDecimalNumber numberWithDouble:[anObject doubleValue]];

  anObject = [self parseFormat:anObject];
  
  if (multiplier > 1)
    anObject = [anObject decimalNumberByMultiplyingBy:
			   [CLDecimalNumber numberWithInt:multiplier]];
  anObject = [anObject decimalNumberByRounding:CLRoundPlain scale:rightMaxDigits];
  numString = [anObject description];
  aRange = [numString rangeOfString:@"." options:0 range:CLMakeRange(0, [numString length])];
  if (aRange.length) {
    dString = [numString substringFromIndex:CLMaxRange(aRange)];
    iString = [numString substringToIndex:aRange.location];
  }
  else {
    dString = @"";
    iString = numString;
  }

  if ([dString length] < rightMinDigits) {
    mString = [dString mutableCopy];
    while ([mString length] < rightMinDigits)
      [mString appendString:@"0"];
    dString = [mString autorelease];
  }

  if ([iString length] < leftMinDigits) {
    mString = [iString mutableCopy];
    while ([mString length] < leftMinDigits)
      [mString insertString:@"0" atIndex:0];
    iString = [mString autorelease];
  }

  if (grouping) {
    mString = [iString mutableCopy];
    for (i = 0, j = ([mString length] - 1) / grouping; i < j; i++)
      [mString insertString:@"," atIndex:[mString length] - ((i+1) * grouping + i)];
    iString = [mString autorelease];
  }

  if ([dString length])
    aString = [CLString stringWithFormat:@"%@%@.%@%@", prefix, iString, dString, suffix];
  else
    aString = [CLString stringWithFormat:@"%@%@%@", prefix, iString, suffix];

  return aString;
}

@end
