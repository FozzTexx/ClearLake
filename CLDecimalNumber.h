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

#import <ClearLake/CLNumber.h>
#import <ClearLake/CLDecimal.h>

@interface CLDecimalNumber:CLNumber <CLCopying, CLPropertyList, CLArchiving>
{
  void *dval;
}

+(CLDecimalNumber *) decimalNumberWithMantissa:(unsigned long long) mantissa
				      exponent:(short) exponent isNegative:(BOOL) flag;
+(CLDecimalNumber *) decimalNumberWithString:(CLString *) numberValue;
+(CLDecimalNumber *) decimalNumberWithNumber:(CLNumber *) aNumber;
+(CLDecimalNumber *) zero;
+(CLDecimalNumber *) one;
+(CLDecimalNumber *) minimumDecimalNumber;
+(CLDecimalNumber *) maximumDecimalNumber;
+(CLDecimalNumber *) notANumber;

-(id) initWithMantissa:(unsigned long long) mantissa exponent:(short) exponent
	    isNegative:(BOOL) flag;
-(id) initWithString:(CLString *) numberValue;
-(id) initWithInt:(int) aValue;
-(id) initWithLong:(long) aValue;
-(id) initWithLongLong:(long long) aValue;
-(id) initWithUnsignedInt:(unsigned int) aValue;
-(id) initWithUnsignedLong:(unsigned long) aValue;
-(id) initWithUnsignedLongLong:(unsigned long long) aValue;
-(id) initWithFloat:(float) aValue;
-(id) initWithDouble:(double) aValue;
-(id) initWithNumber:(CLNumber *) aNumber;
-(void) dealloc;

-(CLDecimalNumber *) decimalNumberByAdding:(CLDecimalNumber *) decimalNumber;
-(CLDecimalNumber *) decimalNumberBySubtracting:(CLDecimalNumber *) decimalNumber;
-(CLDecimalNumber *) decimalNumberByMultiplyingBy:(CLDecimalNumber *) decimalNumber;
-(CLDecimalNumber *) decimalNumberByDividingBy:(CLDecimalNumber *) decimalNumber;
-(CLDecimalNumber *) decimalNumberByRaisingToPower:(CLUInteger) power;
-(CLDecimalNumber *) decimalNumberByMultiplyingByPowerOf10:(short) power;
-(CLDecimalNumber *) decimalNumberByRounding:(CLRoundingMode) mode scale:(short) scale;

-(CLComparisonResult) compare:(CLNumber *) decimalNumber;

-(int) intValue;
-(long) longValue;
-(long long) longLongValue;
-(unsigned int) unsignedIntValue;
-(unsigned long) unsignedLongValue;
-(long long) unsignedLongLongValue;
-(double) doubleValue;
-(CLDecimal) decimalValue;
-(CLString *) description;

@end
