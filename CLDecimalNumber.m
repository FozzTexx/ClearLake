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

#define _ISOC99_SOURCE /* To get llabs */
#include <stdlib.h>

#import "CLDecimalNumber.h"
#import "CLDecimalMPZ.h"
#import "CLMutableString.h"
#import "CLStream.h"
#import "CLHashTable.h"
#import "CLClassConstants.h"

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
  value.dval = val;
  
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
  unichar *buf, *buf2;
  int i, j, len;
  int exp, dLoc;
  CLRange aRange;
  CLDecimalMPZ *val;


  val = value.dval;
  len = [mString length];
  if (!(buf = malloc(sizeof(unichar) * len)))
    [self error:@"Unable to allocate memory"];
  if (!(buf2 = malloc(sizeof(unichar) * len)))
    [self error:@"Unable to allocate memory"];
  [mString getCharacters:buf];
  for (i = j = 0; i < len; i++)
    if (iswdigit(buf[i]) || buf[i] == '+' || buf[i] == '-' || buf[i] == '.' ||
	buf[i] == 'e' || buf[i] == 'e')
      buf2[j++] = buf[i];
  free(buf);
  buf = buf2;
  len = j;
  [mString setCharacters:buf length:len];
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
  val = value.dval;
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

-(CLDecimalMPZ) mpzFromDouble:(double) aValue
{
  int64_t lVal;
  int exp;
  unsigned long long mantissa;
  unsigned long int uli;
  CLDecimalMPZ val, two;

  
  lVal = frexp(aValue, &exp) * INT64_MAX;
  mantissa = llabs(lVal);
  
  /* GMP only uses long and not long long, so I have to set it in stages */
  if (sizeof(mantissa) > sizeof(uli)) {
    uli = mantissa / ULONG_MAX;
    mpz_init_set_ui(val.mantissa, uli);
    mpz_mul_ui(val.mantissa, val.mantissa, ULONG_MAX);
    uli = mantissa % ULONG_MAX;
    mpz_add_ui(val.mantissa, val.mantissa, uli);
  }
  else
    mpz_init_set_ui(val.mantissa, mantissa);

  if (lVal < 0)
    mpz_neg(val.mantissa, val.mantissa);

  val.exponent = 0;

  mpz_init_set_ui(two.mantissa, 2);
  two.exponent = 0;
  CLPowerMPZ(&two, &two, abs(exp));
  if (exp >= 0)
    CLMultiplyMPZ(&val, &val, &two);
  else
    CLDivideMPZ(&val, &val, &two, MAX_DIGITS);

  mantissa = INT64_MAX;
  if (sizeof(mantissa) > sizeof(uli)) {
    uli = mantissa / ULONG_MAX;
    mpz_set_ui(two.mantissa, uli);
    mpz_mul_ui(two.mantissa, two.mantissa, ULONG_MAX);
    uli = mantissa % ULONG_MAX;
    mpz_add_ui(two.mantissa, two.mantissa, uli);
  }
  else
    mpz_set_ui(two.mantissa, mantissa);
  CLDivideMPZ(&val, &val, &two, MAX_DIGITS);

  mpz_clear(two.mantissa);
  return val;
}

-(id) initWithDouble:(double) aValue
{
  CLDecimalMPZ val;


  val = [self mpzFromDouble:aValue];
  [self initWithMPZ:val.mantissa exponent:val.exponent];
  mpz_clear(val.mantissa);
  return self;
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


  val = value.dval;
  mpz_clear(val->mantissa);
  free(val);
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  CLString *aString;
  CLDecimalMPZ *val;

  
  [super read:stream];
  [stream readTypes:@"@", &aString];
  if (!(val = calloc(1, sizeof(CLDecimalMPZ))))
    [self error:@"Unable to allocate memory"];
  value.dval = val;
  mpz_init_set_ui(val->mantissa, 0);
  [self setValueFromString:aString];
  [aString autorelease];
  return self;
}

-(void) write:(CLStream *) stream
{
  CLString *aString;


  [super write:stream];
  aString = [self description];
  [stream writeTypes:@"@", &aString];
  return;
}

-(void) normalize:(CLDecimalNumber *) decimalNumber
{
  CLNormalizeMPZ(value.dval, decimalNumber->value.dval);
  return;
}

-(void) compact
{
  CLCompactMPZ(value.dval);
  return;
}
  
-(CLDecimalNumber *) decimalNumberByAdding:(CLDecimalNumber *) decimalNumber
{
  CLDecimalMPZ res;
  id anObject;


  if (!decimalNumber)
    return self;

  mpz_init(res.mantissa);
  CLAddMPZ(&res, value.dval, decimalNumber->value.dval);
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
  CLSubtractMPZ(&res, value.dval, decimalNumber->value.dval);
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
  CLMultiplyMPZ(&res, value.dval, decimalNumber->value.dval);
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
  CLDivideMPZ(&res, value.dval, decimalNumber->value.dval, MAX_DIGITS);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberModulo:(CLDecimalNumber *) decimalNumber
{
  CLDecimalMPZ res;
  id anObject;


  if (!decimalNumber)
    return self;

  mpz_init(res.mantissa);
  CLModuloMPZ(&res, value.dval, decimalNumber->value.dval, MAX_DIGITS);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberByRaisingToPower:(CLUInteger) power
{
  CLDecimalMPZ res;
  id anObject;


  mpz_init(res.mantissa);
  CLPowerMPZ(&res, value.dval, power);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLDecimalNumber *) decimalNumberByMultiplyingByPowerOf10:(short) power
{
  CLDecimalMPZ res;
  id anObject;


  mpz_init(res.mantissa);
  CLMultiplyByPowerOf10MPZ(&res, value.dval, power);
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
  if (((CLDecimalMPZ *) value.dval)->exponent >= s)
    return self;

  t = s - ((CLDecimalMPZ *) value.dval)->exponent;
  mpz_init(res.mantissa);
  CLRoundMPZ(&res, value.dval, t, mode);
  anObject = [CLDecimalNumber decimalNumberWithMPZ:&res];
  mpz_clear(res.mantissa);
  return anObject;
}

-(CLComparisonResult) compareLong:(long) aValue
{
  CLDecimalMPZ *num1;
  mpz_t exp, n1;
  int res;

  
  num1 = value.dval;

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

  res = mpz_cmp_si(n1, aValue);
  /* GMP docs just say negative/positive and the CLOrdered is exactly -1 and 1 */
  if (res < 0)
    res = CLOrderedAscending;
  if (res > 0)
    res = CLOrderedDescending;

  mpz_clear(n1);
  
  return res;
}

-(CLComparisonResult) compareUnsignedLong:(unsigned long) aValue
{
  CLDecimalMPZ *num1;
  mpz_t exp, n1;
  int res;

  
  num1 = value.dval;

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

  res = mpz_cmp_ui(n1, aValue);
  /* GMP docs just say negative/positive and the CLOrdered is exactly -1 and 1 */
  if (res < 0)
    res = CLOrderedAscending;
  if (res > 0)
    res = CLOrderedDescending;

  mpz_clear(n1);
  
  return res;
}

-(CLComparisonResult) compareDouble:(double) aValue
{
  CLDecimalMPZ val;
  int res;


  val = [self mpzFromDouble:aValue];
  res = CLCompareMPZ(value.dval, &val);
  mpz_clear(val.mantissa);
  return res;
}

-(CLComparisonResult) compare:(CLNumber *) decimalNumber
{
  if (!decimalNumber)
    decimalNumber = [CLDecimalNumber zero];

  if (![decimalNumber isKindOfClass:CLDecimalNumberClass]) {
    switch (decimalNumber->type) {
    case 'i':
      return [self compareLong:decimalNumber->value.l];
    case 'u':
      return [self compareUnsignedLong:decimalNumber->value.ul];
    case 'd':
      return [self compareDouble:decimalNumber->value.d];

    default:
      [self error:@"Unknown number type"];
    }
  }

  return CLCompareMPZ(value.dval, ((CLDecimalNumber *) decimalNumber)->value.dval);
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
  mpz_t exp, n1;
  unsigned long uli = 0;
  long long mantissa;

  
  num1 = value.dval;

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
    mantissa = mpz_get_si(exp);
    mantissa *= ULONG_MAX;
    mantissa += uli;
    mpz_clear(exp);
  }
  else
    mantissa = mpz_get_ui(n1);
  
  mpz_clear(n1);
  
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

-(unsigned long long) unsignedLongLongValue
{
  return (unsigned long long) [self longLongValue];
}
  
-(double) doubleValue
{
  CLDecimalMPZ *num1;
  double d, exp;


  num1 = value.dval;
  d = mpz_get_d(num1->mantissa);
  exp = pow(10.0, num1->exponent);
  d *= exp;
  
  return d;
}

-(CLDecimal) decimalValue
{
  CLDecimalMPZ num;
  CLDecimal val;


  mpz_init_set(num.mantissa, ((CLDecimalMPZ *) value.dval)->mantissa);
  num.exponent = ((CLDecimalMPZ *) value.dval)->exponent;
  CLReleaseMPZ(&num, &val, CLRoundPlain);
  return val;
}

-(CLDecimalNumber *) absoluteValue
{
  CLDecimalMPZ pos, *val;
  CLDecimalNumber *aNumber;


  if (![self isNegative])
    return self;

  val = value.dval;
  mpz_init(pos.mantissa);
  mpz_abs(pos.mantissa, val->mantissa);
  aNumber = [[CLDecimalNumber alloc] initWithMPZ:pos.mantissa exponent:val->exponent];
  mpz_clear(pos.mantissa);
  return [aNumber autorelease];
}

-(BOOL) isNegative
{
  CLDecimalMPZ *num;


  num = value.dval;
  return mpz_cmp_si(num->mantissa, 0) < 0;
}

-(CLString *) description
{
  return CLStringMPZ(value.dval);
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
  return [self intValue];
}

#if DEBUG_RETAIN
#undef copy
#undef retain
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  return [self retain:file :line :retainer];
}
#else
-(id) copy
{
  return [self retain];
}
#endif

@end
