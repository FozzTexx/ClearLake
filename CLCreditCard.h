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

#ifndef _CLCREDITCARD_H
#define _CLCREDITCARD_H

#import <ClearLake/CLGenericRecord.h>

@class CLCalendarDate, CLMailingAddress, CLNumber;

typedef enum {
  CLVISAIssuer = 1,
  CLMasterCardIssuer,
  CLAmericanExpressIssuer,
  CLDiscoverIssuer,
  CLShellOilIssuer,
  CLDinersClubIssuer,
} CLCreditCardIssuer;

@interface CLCreditCard:CLObject <CLCopying>
{
  CLString *number, *cvv;
  CLCalendarDate *expiration;
  CLMailingAddress *address;
}

+(CLCreditCardIssuer) issuer:(CLString *) number;
+(CLString *) type:(CLCreditCardIssuer) ct;

-(id) init;
-(void) dealloc;

-(CLString *) number;
-(CLString *) cvv;
-(CLCalendarDate *) expiration;
-(CLMailingAddress *) address;
-(void) setNumber:(CLString *) aString;
-(void) setCVV:(CLString *) aString;
-(void) setExpiration:(CLCalendarDate *) aDate;
-(void) setAddress:(CLMailingAddress *) anAddress;

-(CLString *) shortNumber;
-(CLString *) prettyNumber;
-(CLNumber *) expirationMonth;
-(CLNumber *) expirationYear;
-(void) setExpirationMonth:(CLNumber *) aNumber;
-(void) setExpirationYear:(CLNumber *) aNumber;
-(CLString *) type;
-(CLCreditCardIssuer) issuer;

@end

#endif /* _CLCREDITCARD_H */
