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

#import "CLDecimalNumber.h"
#import "CLDecimalMPZ.h"
#import "CLMutableString.h"
#import "CLStream.h"
#import "CLHashTable.h"

#include <gmp.h>
#include <math.h>
#include <wctype.h>
#ifndef __USE_ISOC99
#define __USE_ISOC99	1
#endif
#include <stdlib.h>

#define MAX_DIGITS	38

CLDecimalNumber *CLDecimalZero = nil, *CLDecimalOne = nil;

@interface CLDecimalNumber (PrivateMethods)
-(id) initWithMPZ:(mpz_t) num exponent:(int) exp;
@end

@implementation CLDecimalNumber

+(CLDecimalNumber *) decimalNumberWithMantissa:(unsigned long long) mantissa
				      exponent:(short) exponent isNegative:(BOOL) flag
{
  return [[[self alloc] initWithMantissa:mantissa exponent:exponent isNegative:flag]
	   autorelease];
}

+(CLDecimalNumber *) decimalNumberWithString:(CLString *) numberValue
{
  return [[[self alloc] initWithString:numberValue] autorelease];
}

+(CLDecimalNumber *) decimalNumberWithNumber:(CLNumber *) aNumber
{
  return [[[self alloc] initWithNumber:aNumber] autorelease];
}

+(CLDecimalNumber *) decimalNumberWithMPZ:(CLDecimalMPZ *) num
{
  return [[[self alloc] initWithMPZ:num->mantissa exponent:num->exponent] autorelease];
}

+(CLDecimalNumber *) zero
{
  if (!CLDecimalZero)
    CLDecimalZero = [[self alloc] initWithInt:0];
  return CLDecimalZero;
}

+(CLDecimalNumber *) one
{
  if (!CLDecimalOne)
    CLDecimalOne = [[self alloc] initWithInt:1];
  return CLDecimalOne;
}

+(CLDecimalNumber *) minimumDecimalNumber
{
  /* FIXME */
  return nil;
}

+(CLDecimalNumber *) maximumDecimalNumber
{
  /* FIXME */
  return nil;
}

+(CLDecimalNumber *) notANumber
{
  /* FIXME */
  return nil;
}

-(id) initWithMantissa:(unsigned long long) mantissa exponent:(short) exponent
	    isNegative:(BOOL) flag
{
  unsigned long int uli;
  CLDecimalMPZ *val;

  
  [super init];

  if (!(val = malloc(sizeof(CLDecimalMPZ))))
    [self error:@"Unable to allocate memory"];
  dval = val;
  
  /* GMP only uses long and not long long, so I have to set it in stages */
  if (sizeof(mantissa) > sizeof(uli)) {
    uli = mantissa / ULONG_MAX;
    mpz_init_set_ui(val->mantissa, uli);
    mpz_mul_ui(val->mantissa, val->mantissa, ULONG_MAX);
    uli = mantissa % ULONG_MAX;
    mpz_add_ui(val->mantissa, val->mantissa, uli);
  }
  else
    mpz_init_set_ui(val->mantissa, mantissa);

  if (flag)
    mpz_neg(val->mantissa, val->mantissa);
  val->exponent = exponent;
  
  return self;
}

-(void) setValueFromString:(CLString *) numberValue
{
  CLMutableString *mString = [numberValue mutableCopy];
  unichar *buf;
  int i, len;
  int exp, dLoc;
  CLRange aRange;
  CLDecimalMPZ *val;


  val = dval;
  len = [mString length];
  if (!(buf = malloc(sizeof(unichar) * len)))
    [self error:@"Unable to allocate memory"];
  [mString getCharacters:buf];
  for (i = 0; i < len && iswspace(buf[i]); i++)
    ;
  aRange.location = i;
  if (i < len && (iswdigit(buf[i]) || buf[i] == '+' || buf[i] == '-' || buf[i] == '.')) {
    if (buf[i] != '.')
      i++;
    for (; i < len && iswdigit(buf[i]); i++)
      ;
    dLoc = -1;
    exp = 0;
    if (i < len && buf[i] == '.') {
      dLoc = i;
      i++;
      for (; i < len && iswdigit(buf[i]); i++)
	;
      for (; i && buf[i-1] == '0'; i--)
	;
      exp = i - dLoc - 1;
      exp = -exp;
    }
    aRange.length = i - aRange.location;
    if (i < len && (buf[i] == 'e' || buf[i] == 'E')) {
      i++;
      exp += [[mString substringFromIndex:i] intValue];
    }

    if (dLoc >= 0) {
      [mString deleteCharactersInRange:CLMakeRange(dLoc, 1)];
      aRange.length--;
    }
    gmp_sscanf([[mString substringWithRange:aRange] UTF8String], "%Zd", val->mantissa);
    val->exponent = exp;
  }
  [mString release];
  free(buf);

  return;
}

-(id) initWithString:(CLString *) numberValue
{
  [self initWithMantissa:0 exponent:0 isNegative:NO];
  [self setValueFromString:numberValue];
  return self;
}

-(id) initWithMPZ:(mpz_t) num exponent:(int) exp
{
  CLDecimalMPZ *val;


  [self initWithMantissa:0 exponent:exp isNegative:NO];
  val = dval;
  mpz_set(val->mantissa, num);
  return self;
}
  
-(id) initWithInt:(int) aValue
{
  return [self initWithLongLong:aValue];
}

-(id) initWithLong:(long) aValue
{
  return [self initWithLongLong:aValue];
}

-(id) initWithLongLong:(long long) aValue
{
  return [self initWithMantissa:llabs(aValue) exponent:0 isNegative:aValue < 0 ? YES : NO];
}

-(id) initWithUnsignedInt:(unsigned int) aValue;
{
  return [self initWithUnsignedLongLong:aValue];
}

-(id) initWithUnsignedLong:(unsigned long) aValue
{
  return [self initWithUnsignedLongLong:aValue];
}
  
-(id) initWithUnsignedLongLong:(unsigned long long) aValue
{
  return [self initWithMantissa:aValue exponent:0 isNegative:NO];
}

-(id) initWithFloat:(float) aValue
{
  return [self initWithDouble:aValue];
}

-(id) initWithDouble:(double) aValue
{
  return [self initWithString:[CLString stringWithFormat:@"%.*f", MAX_DIGITS, aValue]];
}

-(id) initWithNumber:(CLNumber *) aNumber
{
  switch (aNumber->type) {
  case 'i':
    return [self initWithLongLong:aNumber->value.l];

  case 'u':
    return [self initWithUnsignedLongLong:aNumber->value.ul];

  case 'd':
    return [self initWithDouble:aNumber->value.d];

  default:
    [self error:@"Unknown number type"];
  }

  return self;
}

-(void) dealloc
{
  CLDecimalMPZ *val;


  val = dval;
  mpz_clear(val->mantissa);
  free(val);
  [super dealloc];
  return;
}

-(id) copy
{
  return [self retain];
}

-(void) read:(CLTypedStream *) stream
{
  CLString *aString;


  [super read:stream];
  CLReadTypes(stream, "@", &aString);
  [self setValueFromString:aString];
  [aString release];
  return;
}

-(void) write:(CLTypedStream *) stream
{
  CLString *aString;


  [super write:stream];
  aString = [self description];
  CLWriteTypes(stream, "@", &aString);
  return;
}

-(void) normalize:(CLDecimalNumber *) decimalNumber
{
  CLNormalizeMPZ(dval, decimalNumber->dval);
  return;
}

-(void) compact
{
  CLCompactMPZ(dval);
  return;
}
  
-(CLDecimalNumber *) decimalNumberByAdding:(CLDecimalNumber *) decimalNumber
{
  CLDecimalMPZ res;
  id anObject;


  if (!decimalNumber)
    return self;

  mpz_init(res.mantissa);
  CLAddMPZ(&res, dval, decimalNumber->dval);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberBySubtracting:(CLDecimalNumber *) decimalNumber
{
  CLDecimalMPZ res;
  id anObject;


  if (!decimalNumber)
    return self;

  mpz_init(res.mantissa);
  CLSubtractMPZ(&res, dval, decimalNumber->dval);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberByMultiplyingBy:(CLDecimalNumber *) decimalNumber
{
  CLDecimalMPZ res;
  id anObject;


  if (!decimalNumber)
    return self;

  mpz_init(res.mantissa);
  CLMultiplyMPZ(&res, dval, decimalNumber->dval);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberByDividingBy:(CLDecimalNumber *) decimalNumber
{
  CLDecimalMPZ res;
  id anObject;


  if (!decimalNumber)
    return self;

  mpz_init(res.mantissa);
  CLDivideMPZ(&res, dval, decimalNumber->dval, MAX_DIGITS);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberByRaisingToPower:(CLUInteger) power
{
  CLDecimalMPZ res;
  id anObject;


  mpz_init(res.mantissa);
  CLPowerMPZ(&res, dval, power);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberByMultiplyingByPowerOf10:(short) power
{
  CLDecimalMPZ res;
  id anObject;


  mpz_init(res.mantissa);
  CLMultiplyByPowerOf10MPZ(&res, dval, power);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberByRounding:(CLRoundingMode) mode scale:(short) scale
{
  CLDecimalMPZ res;
  id anObject;
  int s, t;


  s = -scale;
  if (((CLDecimalMPZ *) dval)->exponent >= s)
    return self;

  t = s - ((CLDecimalMPZ *) dval)->exponent;
  mpz_init(res.mantissa);
  CLRoundMPZ(&res, dval, t, mode);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLComparisonResult) compare:(CLNumber *) decimalNumber
{
  if (!decimalNumber)
    decimalNumber = [CLDecimalNumber zero];

  if (![decimalNumber isKindOfClass:[CLDecimalNumber class]])
    decimalNumber = [CLDecimalNumber decimalNumberWithNumber:decimalNumber];

  return CLCompareMPZ(dval, ((CLDecimalNumber *) decimalNumber)->dval);
}

-(int) intValue
{
  return (int) [self longLongValue];
}
  
-(long) longValue
{
  return (long) [self longLongValue];
}

-(long long) longLongValue
{
  CLDecimalMPZ *num1;
  long long mantissa;

  
  num1 = dval;

  mantissa = [self unsignedLongLongValue];
  mantissa *= mpz_sgn(num1->mantissa);
  
  return mantissa;
}

-(unsigned int) unsignedIntValue
{
  return (unsigned int) [self unsignedLongLongValue];
}

-(unsigned long) unsignedLongValue
{
  return (unsigned long) [self unsignedLongLongValue];
}

-(long long) unsignedLongLongValue
{
  CLDecimalMPZ *num1;
  mpz_t exp, n1;
  unsigned long uli = 0;
  unsigned long long mantissa;

  
  num1 = dval;

  if (num1->exponent > 0) {
    mpz_init_set(n1, num1->mantissa);
    mpz_init(exp);
    mpz_ui_pow_ui(exp, 10, num1->exponent);
    mpz_mul(n1, n1, exp);
    mpz_clear(exp);
  }
  else if (num1->exponent < 0) {
    mpz_init_set(n1, num1->mantissa);
    mpz_init(exp);
    mpz_ui_pow_ui(exp, 10, abs(num1->exponent));
    mpz_div(n1, n1, exp);
    mpz_clear(exp);
  }
  else
    mpz_init_set(n1, num1->mantissa);
  
  if (sizeof(mantissa) > sizeof(uli)) {
    mpz_init(exp);
    uli = mpz_fdiv_q_ui(exp, n1, ULONG_MAX);
    mantissa = mpz_get_ui(exp);
    mantissa *= ULONG_MAX;
    mantissa += uli;
    mpz_clear(exp);
  }
  else
    mantissa = mpz_get_ui(n1);
  
  mpz_clear(n1);
  
  return mantissa;
}
  
-(double) doubleValue
{
  CLDecimalMPZ *num1;
  double d, exp;


  num1 = dval;
  d = mpz_get_d(num1->mantissa);
  exp = pow(10.0, num1->exponent);
  d *= exp;
  
  return d;
}

-(CLDecimal) decimalValue
{
  CLDecimalMPZ num;
  CLDecimal val;


  mpz_init_set(num.mantissa, ((CLDecimalMPZ *) dval)->mantissa);
  num.exponent = ((CLDecimalMPZ *) dval)->exponent;
  CLReleaseMPZ(&num, &val, CLRoundPlain);
  return val;
}

-(CLString *) description
{
  return CLStringMPZ(dval);
}

-(CLString *) propertyList
{
  return [CLString stringWithFormat:@"<*n%@>", [self description]];
}

-(CLString *) json
{
  return [self description];
}

-(CLUInteger) hash
{
  long long int val = [self intValue];


  return CLHashBytes(&val, sizeof(val), 0);
}

@end
