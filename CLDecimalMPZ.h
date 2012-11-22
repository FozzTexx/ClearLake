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

/* DO NOT CALL THESE FUNCTIONS YOURSELF. Use CLDecimal or CLDecimalNumber.

   These functions exist so that CLDecimal and CLDecimalNumber can
   share the same routines. CLDecimalNumber does not use CLDecimal
   internally because the GNU MP Bignum Library supports arbitrary
   length integers and I wanted to avoid limiting the size of decimals
   as much as possible.

   CLDecimal exists purely so that decimal math can be done without
   having to create and release blocks of memory within your program
   (such as malloc/free or by creating objects).

   The only place in CLDecimalNumber where a fixed amount of precision
   is used is in decimalNumberByDividingBy:
*/

#import <ClearLake/CLDecimal.h>

#include <gmp.h>

typedef struct CLDecimalMPZ {
  int exponent;
  mpz_t mantissa;
} CLDecimalMPZ;

extern void CLCreateMPZ(CLDecimalMPZ *num, const CLDecimal *decimal);
extern CLCalculationError CLReleaseMPZ(CLDecimalMPZ *num, CLDecimal *decimal,
				       CLRoundingMode mode);
extern void CLRoundMPZ(CLDecimalMPZ *res, const CLDecimalMPZ *num,
		       CLInteger truncate, CLRoundingMode mode);
extern int CLCompactMPZ(CLDecimalMPZ *num);
extern CLComparisonResult CLCompareMPZ(CLDecimalMPZ *leftOperand,
				       CLDecimalMPZ *rightOperand);
extern CLDecimalMPZ *CLNormalizeMPZ(CLDecimalMPZ *number1, CLDecimalMPZ *number2);
extern void CLAddMPZ(CLDecimalMPZ *result,
		     CLDecimalMPZ *leftOperand,
		     CLDecimalMPZ *rightOperand);
extern void CLSubtractMPZ(CLDecimalMPZ *result,
			  CLDecimalMPZ *leftOperand,
			  CLDecimalMPZ *rightOperand);
extern void CLMultiplyMPZ(CLDecimalMPZ *result,
			  CLDecimalMPZ *leftOperand,
			  CLDecimalMPZ *rightOperand);
extern void CLDivideMPZ(CLDecimalMPZ *result,
			CLDecimalMPZ *leftOperand,
			CLDecimalMPZ *rightOperand,
			int precision);
extern void CLPowerMPZ(CLDecimalMPZ *result,
		       const CLDecimalMPZ *number,
		       CLUInteger power);
extern void CLMultiplyByPowerOf10MPZ(CLDecimalMPZ *result,
				     const CLDecimalMPZ *number,
				     short power);
extern CLString *CLStringMPZ(CLDecimalMPZ *num);
