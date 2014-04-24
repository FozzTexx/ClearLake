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

#ifndef _CLDECIMAL_H
#define _CLDECIMAL_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLRuntime.h>

@class CLString;

typedef enum {
  CLRoundPlain,   // Round up on a tie
  CLRoundDown,    // Always down == truncate
  CLRoundUp,      // Always up
  CLRoundBankers  // on a tie round so last digit is even
} CLRoundingMode;

enum {
  CLCalculationNoError = 0,
  CLCalculationLossOfPrecision, // Result lost precision
  CLCalculationUnderflow,       // Result became 0
  CLCalculationOverflow,        // Result exceeds possible representation
  CLCalculationDivideByZero
};
typedef CLUInteger CLCalculationError;

#define CLDecimalMaxSize (8)
// Give a precision of at least 38 decimal digits, 128 binary positions.

#define CLDecimalNoScale SHRT_MAX
typedef struct {
  signed   int _exponent:8;
  unsigned int _length:4;     // length == 0 && isNegative -> NaN
  unsigned int _isNegative:1;
  unsigned short _mantissa[CLDecimalMaxSize];
} CLDecimal;

CL_INLINE BOOL CLDecimalIsNotANumber(const CLDecimal *dcm)
{ return ((dcm->_length == 0) && dcm->_isNegative); }
CL_INLINE void CLDecimalCopy(CLDecimal *destination, const CLDecimal *source)
{ *destination = *source; }

extern void CLDecimalCompact(CLDecimal *number);

extern CLComparisonResult CLDecimalCompare(const CLDecimal *leftOperand,
					   const CLDecimal *rightOperand);
// CLDecimalCompare:Compares leftOperand and rightOperand.

extern void CLDecimalRound(CLDecimal *result, const CLDecimal *number,
			   CLInteger scale, CLRoundingMode roundingMode);
// Rounds num to the given scale using the given mode.
// result may be a pointer to same space as num.
// scale indicates number of significant digits after the decimal point

extern CLCalculationError CLDecimalNormalize(CLDecimal *number1,
					     CLDecimal *number2,
					     CLRoundingMode roundingMode);
extern CLCalculationError CLDecimalAdd(CLDecimal *result,
				       const CLDecimal *leftOperand,
				       const CLDecimal *rightOperand,
				       CLRoundingMode roundingMode);
// Exact operations. result may be a pointer to same space as leftOperand or rightOperand

extern CLCalculationError CLDecimalSubtract(CLDecimal *result,
					    const CLDecimal *leftOperand,
					    const CLDecimal *rightOperand,
					    CLRoundingMode roundingMode);
// Exact operations. result may be a pointer to same space as leftOperand or rightOperand

extern CLCalculationError CLDecimalMultiply(CLDecimal *result,
					    const CLDecimal *leftOperand,
					    const CLDecimal *rightOperand,
					    CLRoundingMode roundingMode);
// Exact operations. result may be a pointer to same space as leftOperand or rightOperand
extern CLCalculationError CLDecimalDivide(CLDecimal *result,
					  const CLDecimal *leftOperand,
					  const CLDecimal *rightOperand,
					  CLRoundingMode roundingMode);
// Division could be silently inexact;
// Exact operations. result may be a pointer to same space as leftOperand or rightOperand

extern CLCalculationError CLDecimalPower(CLDecimal *result,
					 const CLDecimal *number,
					 CLUInteger power,
					 CLRoundingMode roundingMode);

extern CLCalculationError CLDecimalMultiplyByPowerOf10(CLDecimal *result,
						       const CLDecimal *number,
						       short power,
						       CLRoundingMode roundingMode);

extern CLString *CLDecimalString(const CLDecimal *number);

#endif /* _CLDECIMAL_H */
