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

#import "CLNumber.h"
#import "CLDecimalNumber.h"
#import "CLMutableString.h"
#import "CLHashTable.h"
#import "CLStream.h"

#include <stdlib.h>

struct roman {
  unichar letter;
  unsigned int value;
} romanNumerals[] = {
  {'M', 1000}, {'D', 500}, {'C', 100}, {'L', 50}, {'X', 10}, {'V', 5}, {'I', 1}, {0, 0}
};
static CLString *humanSizes[] = { @"B", @"kB", @"MB", @"GB", nil };

@implementation CLNumber

+(id) numberWithInt:(int) aValue
{
  return [[[self alloc] initWithInt:aValue] autorelease];
}

+(id) numberWithLong:(long) aValue
{
  return [[[self alloc] initWithLong:aValue] autorelease];
}

+(id) numberWithLongLong:(long long) aValue
{
  return [[[self alloc] initWithLongLong:aValue] autorelease];
}

+(id) numberWithUnsignedInt:(unsigned int) aValue
{
  return [[[self alloc] initWithUnsignedInt:aValue] autorelease];
}

+(id) numberWithUnsignedLong:(unsigned long) aValue
{
  return [[[self alloc] initWithUnsignedLong:aValue] autorelease];
}

+(id) numberWithUnsignedLongLong:(unsigned long long) aValue
{
  return [[[self alloc] initWithUnsignedLongLong:aValue] autorelease];
}

+(id) numberWithFloat:(float) aValue
{
  return [[[self alloc] initWithFloat:aValue] autorelease];
}

+(id) numberWithDouble:(double) aValue
{
  return [[[self alloc] initWithFloat:aValue] autorelease];
}

+(id) numberWithRomanNumeral:(CLString *) aString
{
  return [[[self alloc] initWithRomanNumeral:aString] autorelease];
}

+(id) numberWithBool:(BOOL) aValue
{
  return [[[self alloc] initWithUnsignedInt:aValue] autorelease];
}

-(id) init
{
  return [super init];
}

-(id) initWithInt:(int) aValue
{
  [self init];
  value.l = aValue;
  type = 'i';
  return self;
}

-(id) initWithLong:(long) aValue
{
  [self init];
  value.l = aValue;
  type = 'i';
  return self;
}

-(id) initWithLongLong:(long long) aValue
{
  [self init];
  value.l = aValue;
  type = 'i';
  return self;
}

-(id) initWithUnsignedInt:(unsigned int) aValue
{
  [self init];
  value.ul = aValue;
  type = 'u';
  return self;
}

-(id) initWithUnsignedLong:(unsigned long) aValue
{
  [self init];
  value.ul = aValue;
  type = 'u';
  return self;
}

-(id) initWithUnsignedLongLong:(unsigned long long) aValue
{
  [self init];
  value.ul = aValue;
  type = 'u';
  return self;
}

-(id) initWithFloat:(float) aValue
{
  [self init];
  value.d = aValue;
  type = 'd';
  return self;
}

-(id) initWithDouble:(double) aValue
{
  [self init];
  value.d = aValue;
  type = 'd';
  return self;
}  

/* 1 DIM V(26): FOR I = 0 to 1: READ A$,B:A = A + 1:C$(A) = A$:P = ASC
   (A$) - 64:V(P) = B:A(A) = B:I = P = 0: NEXT : INPUT "R/A?";A$: ON
   A$ = "A" GOTO 2: INPUT "R:";A$: FOR I = 1 TO LEN (A$):C = V( ASC (
   MID$(A$ + "@",I+1)) - 64):B = V( ASC (MID$ (A$,I)) - 64):V = V + (
   - (B < C) * 2 + 1) * B: NEXT: PRINT V: END: DATA I,1,V,5,X */

-(unsigned int) romanValue:(unichar) letter
{
  int i;


  for (i = 0; romanNumerals[i].value; i++)
    if (romanNumerals[i].letter == letter)
      return romanNumerals[i].value;

  return 0;
}

-(id) initWithRomanNumeral:(CLString *) aString
{
  unichar *buf;
  int i, len;
  unsigned int b, c;

  
  [self init];

  aString = [aString uppercaseString];
  len = [aString length];
  if (!(buf = calloc(len, sizeof(unichar))))
    [self error:@"Unable to allocate memory"];
  [aString getCharacters:buf];

  value.ul = 0;
  for (i = 0; i < len; i++) {
    if (i < len)
      c = [self romanValue:buf[i+1]];
    else
      c = 0;
    b = [self romanValue:buf[i]];

    if (b < c)
      value.ul -= b;
    else
      value.ul += b;
  }
  free(buf);
  
  type = 'u';
  return self;  
}

-(void) read:(CLTypedStream *) stream
{
  [super read:stream];
  CLReadTypes(stream, "i", &type);
  if (type == 'i')
    CLReadTypes(stream, "l", &value.l);
  else if (type == 'u')
    CLReadTypes(stream, "L", &value.ul);
  else if (type == 'd')
    CLReadTypes(stream, "d", &value.d);
  return;
}

-(void) write:(CLTypedStream *) stream
{
  [super write:stream];
  CLWriteTypes(stream, "i", &type);
  if (type == 'i')
    CLWriteTypes(stream, "l", &value.l);
  else if (type == 'u')
    CLWriteTypes(stream, "L", &value.ul);
  else if (type == 'd')
    CLWriteTypes(stream, "d", &value.d);
  return;
}

-(int) intValue
{
  return (int) value.l;
}

-(long) longValue
{
  return (long) value.l;
}

-(long long) longLongValue
{
  return value.l;
}

-(unsigned int) unsignedIntValue
{
  return (unsigned int) value.ul;
}

-(unsigned long) unsignedLongValue
{
  return (unsigned long) value.ul;
}

-(unsigned long long) unsignedLongLongValue
{
  return value.ul;
}

-(double) doubleValue
{
  if (type == 'i')
    return (double) value.l;
  if (type == 'u')
    return (double) value.ul;
  return value.d;
}

/* 2 INPUT "A:";V: FOR I = A - 1 TO 1 STEP - 1:B = A(I): FOR J = 0 TO
   1:E = V > = B:E$ = E$ + C$(I * E):V = V - A(I * E):J = 1 - E: NEXT
   : FOR J = I - 1 TO 1 STEP - 1:C = A(J):J = J - (B - C = C):E = V >
   = B - A(J):E$ = E$ + C$(J * E) + C$(I * E):V = V - (A(I * E) - A(J
   * E)):J = J * (1 - E): NEXT J,I: PRINT E$: DATA
   10,L,50,C,100,D,500,M,1000,@,0 */

-(CLString *) romanNumeralValue
{
  CLMutableString *mString;
  int i, j;
  unsigned long long val;


  mString = [[CLMutableString alloc] init];

  val = value.ul;
  for (i = 0; romanNumerals[i].value; i++) {
    while (val >= romanNumerals[i].value) {
      [mString appendCharacter:romanNumerals[i].letter];
      val -= romanNumerals[i].value;
    }
    for (j = i+1; romanNumerals[j].value; j++) {
      if (romanNumerals[i].value - romanNumerals[j].value == romanNumerals[j].value)
	continue;
      if (val >= romanNumerals[i].value - romanNumerals[j].value) {
	[mString appendCharacter:romanNumerals[j].letter];
	[mString appendCharacter:romanNumerals[i].letter];
	val -= romanNumerals[i].letter - romanNumerals[j].letter;
	break;
      }
    }
  }
  
  return [mString autorelease];
}

-(BOOL) boolValue
{
  return !![self unsignedLongLongValue];
}

-(CLDecimal) decimalValue
{
  CLDecimalNumber *aNumber = nil;


  if (type == 'i')
    aNumber = [CLDecimalNumber numberWithLongLong:value.l];
  if (type == 'u')
    aNumber = [CLDecimalNumber numberWithUnsignedLongLong:value.l];
  if (type == 'd')
    aNumber = [CLDecimalNumber numberWithDouble:value.l];

  return [aNumber decimalValue];
}

-(CLString *) humanReadableBytes
{
  double size;
  int i;


  size = [self doubleValue];
  for (i = 0; humanSizes[i] && size > 1024; i++, size /= 1024)
    ;
  return [CLString stringWithFormat:@"%.2f %@", size, humanSizes[i]];
}

-(id) copy
{
  return [self retain];
}

-(CLString *) propertyList
{
  /* Write it out the GNUstep-ish way */
  return [CLString stringWithFormat:@"<*%c%@>", type, [self description]];
}

-(CLString *) json
{
  return [self description];
}

-(CLString *) description
{
  if (type == 'i')
    return [CLString stringWithFormat:@"%lli", value.l];
  if (type == 'u')
    return [CLString stringWithFormat:@"%llu", value.ul];
  if (type == 'd')
    return [CLString stringWithFormat:@"%f", value.d];

  return nil;
}

-(BOOL) isEqual:(id) anObject
{
  double d1, d2;


  if (self == anObject)
    return YES;
  
  if (![anObject isKindOfClass:[CLNumber class]])
    return NO;

  d1 = [self doubleValue];
  d2 = [anObject doubleValue];
  if (d1 == d2)
    return YES;

  return NO;
}
  
-(CLComparisonResult) compare:(CLNumber *) aNumber
{
  CLDecimalNumber *d1, *d2;


  if ([aNumber isKindOfClass:[CLDecimalNumber class]] ||
      type != aNumber->type) {
    d1 = [CLDecimalNumber decimalNumberWithNumber:self];
    d2 = (CLDecimalNumber *) aNumber;
    if (![d2 isKindOfClass:[CLDecimalNumber class]])
      d2 = [CLDecimalNumber decimalNumberWithNumber:d2];
    return [d1 compare:d2];
  }
  else {
    switch (type) {
    case 'i':
      if (value.l < aNumber->value.l)
	return CLOrderedAscending;
      if (value.l > aNumber->value.l)
	return CLOrderedDescending;
      return CLOrderedSame;
      
    case 'u':
      if (value.ul < aNumber->value.ul)
	return CLOrderedAscending;
      if (value.ul > aNumber->value.ul)
	return CLOrderedDescending;
      return CLOrderedSame;
      
    case 'd':
      if (value.d < aNumber->value.d)
	return CLOrderedAscending;
      if (value.d > aNumber->value.d)
	return CLOrderedDescending;
      return CLOrderedSame;

    default:
      [self error:@"Unknown number type"];
    }
  }

  
  return CLOrderedSame;
}

-(BOOL) isGreaterThanOne
{
  return [self intValue] > 1;
}

-(CLUInteger) hash
{
  return CLHashBytes(&value, sizeof(value), 0);
}

@end
