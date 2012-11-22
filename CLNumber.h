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

#ifndef _CLNUMBER_H
#define _CLNUMBER_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLDecimal.h>

@class CLString;

@interface CLNumber:CLObject <CLCopying, CLPropertyList, CLArchiving>
{
  union {
    long long l;
    unsigned long long ul;
    double d;
  } value;
  int type;
}

+(id) numberWithInt:(int) aValue;
+(id) numberWithLong:(long) aValue;
+(id) numberWithLongLong:(long long) aValue;
+(id) numberWithUnsignedInt:(unsigned int) aValue;
+(id) numberWithUnsignedLong:(unsigned long) aValue;
+(id) numberWithUnsignedLongLong:(unsigned long long) aValue;
+(id) numberWithFloat:(float) aValue;
+(id) numberWithDouble:(double) aValue;
+(id) numberWithRomanNumeral:(CLString *) aString;
+(id) numberWithBool:(BOOL) aValue;

-(id) initWithInt:(int) aValue;
-(id) initWithLong:(long) aValue;
-(id) initWithLongLong:(long long) aValue;
-(id) initWithUnsignedInt:(unsigned int) aValue;
-(id) initWithUnsignedLong:(unsigned long) aValue;
-(id) initWithUnsignedLongLong:(unsigned long long) aValue;
-(id) initWithFloat:(float) aValue;
-(id) initWithDouble:(double) aValue;
-(id) initWithRomanNumeral:(CLString *) aString;

-(int) intValue;
-(long) longValue;
-(long long) longLongValue;
-(unsigned int) unsignedIntValue;
-(unsigned long) unsignedLongValue;
-(unsigned long long) unsignedLongLongValue;
-(double) doubleValue;
-(CLString *) romanNumeralValue;
-(BOOL) boolValue;
-(CLDecimal) decimalValue;
-(CLString *) humanReadableBytes;
-(BOOL) isEqual:(id) anObject;
-(CLComparisonResult) compare:(CLNumber *) aNumber;
-(BOOL) isGreaterThanOne;

-(CLString *) description;

@end

#endif /* _CLNUMBER_H */
