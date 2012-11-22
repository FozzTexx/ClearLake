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

#import "CLDecimalMPZ.h"
#import "CLMutableString.h"

#include <stdlib.h>
#include <math.h>

void CLCreateMPZ(CLDecimalMPZ *num, const CLDecimal *decimal)
{
  mpz_init(num->mantissa);
  mpz_import(num->mantissa, decimal->_length, -1, sizeof(decimal->_mantissa[0]),
	     0, 0, decimal->_mantissa);
  if (decimal->_isNegative)
    mpz_neg(num->mantissa, num->mantissa);
  num->exponent = decimal->_exponent;

  return;
}

CLCalculationError CLReleaseMPZ(CLDecimalMPZ *num, CLDecimal *decimal,
				CLRoundingMode mode)
{
  int numbytes, numbits, size, exp;
  size_t countp, countn;
  CLDecimalMPZ res;
  CLCalculationError err = CLCalculationNoError;


  numbytes = sizeof(decimal->_mantissa);
  size = sizeof(decimal->_mantissa[0]);
  countp = numbytes / size;
  numbits = 8 * size;
  mpz_init_set(res.mantissa, num->mantissa);
  res.exponent = num->exponent;
  exp = 0;
  countn = (mpz_sizeinbase(res.mantissa, 2) + numbits-1) / numbits;
  while (countn > countp) {
    mpz_tdiv_q_ui(res.mantissa, res.mantissa, 10);
    exp++;
    countn = (mpz_sizeinbase(res.mantissa, 2) + numbits-1) / numbits;
  }

  if (exp) {
    CLRoundMPZ(&res, num, exp, mode);
    err = CLCalculationLossOfPrecision;
  }
  
  mpz_export(decimal->_mantissa, &countp, -1, size, 0, 0, res.mantissa);
  decimal->_exponent = res.exponent;
  decimal->_length = countp;
  decimal->_isNegative = mpz_sgn(res.mantissa) < 0;
  mpz_clear(num->mantissa);
  mpz_clear(res.mantissa);

  return err;
}

void CLRoundMPZ(CLDecimalMPZ *res, const CLDecimalMPZ *num,
		       CLInteger truncate, CLRoundingMode mode)
{
  mpz_t rem, exp;
  unsigned long ul;
  int ord;


  mpz_init(rem);
  mpz_init(exp);
  mpz_ui_pow_ui(exp, 10, truncate);
  mpz_fdiv_qr(res->mantissa, rem, num->mantissa, exp);
  res->exponent = num->exponent + truncate;

  mpz_tdiv_q_ui(exp, exp, 2);
  
  switch (mode) {
  case CLRoundPlain:   // Round up on a tie
    if (mpz_sgn(res->mantissa) >= 0 && mpz_cmp(rem, exp) >= 0)
      mpz_add_ui(res->mantissa, res->mantissa, 1);
    break;
    
  case CLRoundDown:    // Always down == truncate
    break;

  case CLRoundUp:      // Always up
    if (mpz_cmp_ui(rem, 0) > 0)
      mpz_add_ui(res->mantissa, res->mantissa, 1);
    break;

  case CLRoundBankers:  // on a tie round so last digit is even
    ord = mpz_cmp(rem, exp);
    if (!ord) {
      ul = mpz_fdiv_ui(res->mantissa, 10);
      if (ul % 2)
	mpz_add_ui(res->mantissa, res->mantissa, 1);
    }
    else if (ord > 0)
      mpz_add_ui(res->mantissa, res->mantissa, 1);
    break;
  }

  mpz_clear(rem);
  mpz_clear(exp);
  
  return;
}

int CLCompactMPZ(CLDecimalMPZ *num)
{
  CLUInteger i;


  if (!mpz_sgn(num->mantissa))
    i = -num->exponent;
  else {
    i = 0;
    while (mpz_sgn(num->mantissa) && mpz_divisible_ui_p(num->mantissa, 10)) {
      i++;
      mpz_tdiv_q_ui(num->mantissa, num->mantissa, 10);
    }
  }

  num->exponent += i;
  
  return i;
}

CLComparisonResult CLCompareMPZ(CLDecimalMPZ *leftOperand,
				CLDecimalMPZ *rightOperand)
{
  int res;


  CLNormalizeMPZ(leftOperand, rightOperand);
  res = mpz_cmp(leftOperand->mantissa, rightOperand->mantissa);
    
  /* GMP docs just say negative/positive and the CLOrdered is exactly -1 and 1 */
  if (res < 0)
    return CLOrderedAscending;
  if (res > 0)
    return CLOrderedDescending;

  return CLOrderedSame;  
}

CLDecimalMPZ *CLNormalizeMPZ(CLDecimalMPZ *number1, CLDecimalMPZ *number2)
{
  mpz_t exp;
  int i;


  /* There's no reason to normalize against zero */
  if (!mpz_sgn(number1->mantissa)) {
    number1->exponent = number2->exponent;
    return number1;
  }
  if (!mpz_sgn(number2->mantissa)) {
    number2->exponent = number1->exponent;
    return number2;
  }
  
  /* x*10^n + y*10^m = 10^n*(x + y*10^(m-n)) */
  i = number1->exponent - number2->exponent;
  if (i < 0) {
    i = -i;
    number1 = number2;
  }

  if (i) {
    mpz_init(exp);
    mpz_ui_pow_ui(exp, 10, i);
    mpz_mul(number1->mantissa, number1->mantissa, exp);
    number1->exponent -= i;
    mpz_clear(exp);
  }

  return number1;
}

void CLAddMPZ(CLDecimalMPZ *result,
	      CLDecimalMPZ *leftOperand,
	      CLDecimalMPZ *rightOperand)
{
  CLNormalizeMPZ(leftOperand, rightOperand);
  mpz_add(result->mantissa, leftOperand->mantissa, rightOperand->mantissa);
  result->exponent = leftOperand->exponent;
  return;
}

void CLSubtractMPZ(CLDecimalMPZ *result,
		   CLDecimalMPZ *leftOperand,
		   CLDecimalMPZ *rightOperand)
{
  CLNormalizeMPZ(leftOperand, rightOperand);
  mpz_sub(result->mantissa, leftOperand->mantissa, rightOperand->mantissa);
  result->exponent = leftOperand->exponent;
  return;
}

void CLMultiplyMPZ(CLDecimalMPZ *result,
		   CLDecimalMPZ *leftOperand,
		   CLDecimalMPZ *rightOperand)
{
  CLNormalizeMPZ(leftOperand, rightOperand);
  mpz_mul(result->mantissa, leftOperand->mantissa, rightOperand->mantissa);
  result->exponent = leftOperand->exponent * 2;
  return;
}

void CLDivideMPZ(CLDecimalMPZ *result,
		 CLDecimalMPZ *leftOperand,
		 CLDecimalMPZ *rightOperand,
		 int precision)
{
  mpz_t exp;
  

  CLNormalizeMPZ(leftOperand, rightOperand);
  mpz_init(exp);
  mpz_ui_pow_ui(exp, 10, precision);
  mpz_mul(result->mantissa, leftOperand->mantissa, exp);
  mpz_tdiv_q(result->mantissa, result->mantissa, rightOperand->mantissa);
  result->exponent = -precision;
  mpz_clear(exp);
  return;
}

void CLPowerMPZ(CLDecimalMPZ *result,
		const CLDecimalMPZ *number,
		CLUInteger power)
{
  mpz_pow_ui(result->mantissa, number->mantissa, power);
  result->exponent = number->exponent * power;
  return;
}

void CLMultiplyByPowerOf10MPZ(CLDecimalMPZ *result,
			      const CLDecimalMPZ *number,
			      short power)
{
  mpz_set(result->mantissa, number->mantissa);
  result->exponent = number->exponent + power;
  return;
}

CLString *CLStringMPZ(CLDecimalMPZ *num)
{
  char *buf = NULL;
  CLString *aString;
  mpz_t n1, exp;
  CLMutableString *mString;
  CLUInteger pos;


  CLCompactMPZ(num);
  if (num->exponent > 0) {
    mpz_init_set(n1, num->mantissa);
    mpz_init(exp);
    mpz_ui_pow_ui(exp, 10, num->exponent);
    mpz_mul(n1, n1, exp);
    gmp_asprintf(&buf, "%Zd", n1);
    aString = [CLString stringWithUTF8String:buf];
    free(buf);
    mpz_clear(n1);
    mpz_clear(exp);
  }
  else if (num->exponent < 0) {
    gmp_asprintf(&buf, "%Zd", num->mantissa);
    mString = [[CLString stringWithUTF8String:buf] mutableCopy];
    pos = abs(num->exponent);
    while (pos >= [mString length])
      [mString insertString:@"0" atIndex:0];
    [mString insertString:@"." atIndex:[mString length] - abs(num->exponent)];
    aString = [mString autorelease];
    free(buf);
  }
  else {    
    gmp_asprintf(&buf, "%Zd", num->mantissa);
    aString = [CLString stringWithUTF8String:buf];
    free(buf);
  }
  
  return aString;
}
