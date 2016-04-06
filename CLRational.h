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

#define CLRationalMaxSize	8

typedef struct {
  unsigned int _isNegative:1;
  unsigned int _numeratorLength:4;
  unsigned int _denominatorLength:4;
  unsigned short _numerator[CLRationalMaxSize];
  unsigned short _denominator[CLRationalMaxSize];
} CLRational;

extern CLCalculationError CLRationalAdd(CLRational *result,
					const CLRational *leftOp, CLRational *rightOp,
					CLRoundingMode roundingMode);
extern CLCalculationError CLRationalSubtract(CLRational *result,
					     const CLRational *leftOp, CLRational *rightOp,
					     CLRoundingMode roundingMode);
extern CLCalculationError CLRationalMultiply(CLRational *result,
					     const CLRational *leftOp, CLRational *rightOp,
					     CLRoundingMode roundingMode);
extern CLCalculationError CLRationalDivide(CLRational *result,
					   const CLRational *leftOp, CLRational *rightOp,
					   CLRoundingMode roundingMode);
