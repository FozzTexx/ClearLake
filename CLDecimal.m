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

/* This is kind of lame-o because I'm going to have to import and
   export around every operation. I have to do this because the GMP
   library uses pointers that have to be freed, and the whole point of
   using CLDecimal instead of CLDecimalNumber is so that you don't
   have to deal with memory allocation. */

#import "CLDecimal.h"
#import "CLMutableString.h"
#import "CLDecimalMPZ.h"

void CLDecimalCompact(CLDecimal *number)
{
  CLDecimalMPZ num;


  CLCreateMPZ(&num, number);
  if (CLCompactMPZ(&num)) 
    CLReleaseMPZ(&num, number, CLRoundPlain);
  else
    mpz_clear(num.mantissa);
  
  return;
}

CLComparisonResult CLDecimalCompare(const CLDecimal *leftOperand,
				    const CLDecimal *rightOperand)
{
  int res;
  CLDecimalMPZ n1, n2;


  CLCreateMPZ(&n1, leftOperand);
  CLCreateMPZ(&n2, rightOperand);
  res = CLCompareMPZ(&n1, &n2);
  mpz_clear(n1.mantissa);
  mpz_clear(n2.mantissa);
  return res;
}

void CLDecimalRound(CLDecimal *result, const CLDecimal *number,
		    CLInteger scale, CLRoundingMode roundingMode)
{
  CLDecimalMPZ num;
  CLInteger s, t;


  s = -scale;
  if (number->_exponent >= s)
    return;

  t = s - number->_exponent;
  CLCreateMPZ(&num, number);
  CLRoundMPZ(&num, &num, t, roundingMode);
  CLReleaseMPZ(&num, result, roundingMode);
  return;
}

CLCalculationError CLDecimalNormalize(CLDecimal *number1,
				      CLDecimal *number2,
				      CLRoundingMode roundingMode)
{
  CLDecimalMPZ n1, n2;
  CLDecimalMPZ *which;
  CLCalculationError err = 0;


  CLCreateMPZ(&n1, number1);
  CLCreateMPZ(&n2, number2);
  which = CLNormalizeMPZ(&n1, &n2);
  if (which == &n2) {
    number1 = number2;
    n2 = n1;
  }
  err = CLReleaseMPZ(which, number1, roundingMode);
  mpz_clear(n2.mantissa);
  
  return err;
}

CLCalculationError CLDecimalAdd(CLDecimal *result,
				       const CLDecimal *leftOperand,
				       const CLDecimal *rightOperand,
				       CLRoundingMode roundingMode)
{
  CLDecimalMPZ n1, n2;
  CLCalculationError err;


  CLCreateMPZ(&n1, leftOperand);
  CLCreateMPZ(&n2, rightOperand);
  CLAddMPZ(&n1, &n1, &n2);
  err = CLReleaseMPZ(&n1, result, roundingMode);
  mpz_clear(n2.mantissa);
  return err;
}

CLCalculationError CLDecimalSubtract(CLDecimal *result,
					    const CLDecimal *leftOperand,
					    const CLDecimal *rightOperand,
					    CLRoundingMode roundingMode)
{
  CLDecimalMPZ n1, n2;
  CLCalculationError err;


  CLCreateMPZ(&n1, leftOperand);
  CLCreateMPZ(&n2, rightOperand);
  CLSubtractMPZ(&n1, &n1, &n2);
  err = CLReleaseMPZ(&n1, result, roundingMode);
  mpz_clear(n2.mantissa);
  return err;
}

CLCalculationError CLDecimalMultiply(CLDecimal *result,
					    const CLDecimal *leftOperand,
					    const CLDecimal *rightOperand,
					    CLRoundingMode roundingMode)
{
  CLDecimalMPZ n1, n2;
  CLCalculationError err;


  CLCreateMPZ(&n1, leftOperand);
  CLCreateMPZ(&n2, rightOperand);
  CLMultiplyMPZ(&n1, &n1, &n2);
  err = CLReleaseMPZ(&n1, result, roundingMode);
  mpz_clear(n2.mantissa);
  return err;
}

CLCalculationError CLDecimalDivide(CLDecimal *result,
					  const CLDecimal *leftOperand,
					  const CLDecimal *rightOperand,
					  CLRoundingMode roundingMode)
{
  CLDecimalMPZ n1, n2;
  CLCalculationError err;


  CLCreateMPZ(&n1, leftOperand);
  CLCreateMPZ(&n2, rightOperand);
  CLDivideMPZ(&n1, &n1, &n2, 38);
  err = CLReleaseMPZ(&n1, result, roundingMode);
  mpz_clear(n2.mantissa);
  return err;
}

CLCalculationError CLDecimalPower(CLDecimal *result,
					 const CLDecimal *number,
					 CLUInteger power,
					 CLRoundingMode roundingMode)
{
  CLDecimalMPZ num;


  CLCreateMPZ(&num, number);
  CLPowerMPZ(&num, &num, power);
  return CLReleaseMPZ(&num, result, roundingMode);
}

CLCalculationError CLDecimalMultiplyByPowerOf10(CLDecimal *result,
						       const CLDecimal *number,
						       short power,
						       CLRoundingMode roundingMode)
{
  CLDecimalMPZ num;


  CLCreateMPZ(&num, number);
  CLMultiplyByPowerOf10MPZ(&num, &num, power);
  return CLReleaseMPZ(&num, result, roundingMode);
}

CLString *CLDecimalString(const CLDecimal *number)
{
  CLDecimalMPZ num;
  CLString *aString;


  CLCreateMPZ(&num, number);
  aString = CLStringMPZ(&num);
  mpz_clear(num.mantissa);
  return aString;
}
