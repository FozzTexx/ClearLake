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

/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * $Id$
 */

#import "CLCreditCard.h"
#import "CLString.h"
#import "CLCalendarDate.h"
#import "CLNumber.h"

#include <stdlib.h>
#include <wctype.h>

@implementation CLCreditCard

/* Based on info at http://www.merriampark.com/anatomycc.htm */
/* FIXME - update with info from http://en.wikipedia.org/wiki/Bank_Identification_Number */

+(CLCreditCardIssuer) issuer:(CLString *) number
{
  int identifier;


  if ([number length] >= 6) {
    identifier = [[number substringToIndex:6] intValue];

    if ((identifier >= 300000 && identifier <= 305999) ||
	(identifier >= 360000 && identifier <= 369999) ||
	(identifier >= 380000 && identifier <= 389999))
      return CLDinersClubIssuer; /* Diner's Club/Carte Blanche */
    else if ((identifier >= 340000 && identifier <= 349999) ||
	     (identifier >= 370000 && identifier <= 379999))
      return CLAmericanExpressIssuer;
    else if (identifier >= 400000 && identifier <= 499999)
      return CLVISAIssuer;
    else if (identifier >= 510000 && identifier <= 559999)
      return CLMasterCardIssuer;
    else if (identifier >= 601100 && identifier <= 601199)
      return CLDiscoverIssuer;
    else if (identifier == 700063)
      return CLShellOilIssuer;
  }

  return 0;
}

+(CLString *) type:(CLCreditCardIssuer) ct
{
  switch (ct) {
  case CLAmericanExpressIssuer:
    return @"American Express";

  case CLVISAIssuer:
    return @"Visa";

  case CLMasterCardIssuer:
    return @"MasterCard";

  case CLDiscoverIssuer:
    return @"Discover";

  case CLShellOilIssuer:
    return @"Shell Oil";

  case CLDinersClubIssuer:
    return @"Diners Club";
  }

  return nil;
}

-(id) init
{
  [super init];
  number = cvv = nil;
  expiration = nil;
  address = nil;
  return self;
}

-(void) dealloc
{
  [number release];
  [cvv release];
  [expiration release];
  [address release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLCreditCard *aCopy;


  aCopy = [super copy];
  aCopy->number = [number copy];
  aCopy->cvv = [cvv copy];
  aCopy->expiration = [expiration copy];
  aCopy->address = [address copy];
  return aCopy;
}

-(CLString *) number
{
  return number;
}

-(CLString *) cvv
{
  return cvv;
}

-(CLCalendarDate *) expiration
{
  return expiration;
}

-(CLMailingAddress *) address
{
  return address;
}

-(void) setNumber:(CLString *) aString
{
  unichar *buf;
  int len;
  int i;


  len = [aString length];
  if (!(buf = malloc(sizeof(unichar) * len)))
    [self error:@"Unable to allocate memory"];
  [aString getCharacters:buf];
  for (i = 0; i < len; i++)
    if (!iswdigit(buf[i])) {
      memmove(&buf[i], &buf[i+1], (len - i - 1) * sizeof(unichar));
      i--;
      len--;
    }

  aString = [CLString stringWithCharacters:buf length:len];
  free(buf);

  [number release];
  number = [aString retain];
  return;
}

-(void) setCVV:(CLString *) aString
{
  unichar *buf;
  int len;
  int i;


  len = [aString length];
  if (!(buf = malloc(sizeof(unichar) * len)))
    [self error:@"Unable to allocate memory"];
  [aString getCharacters:buf];
  for (i = 0; i < len; i++)
    if (!iswdigit(buf[i])) {
      memmove(&buf[i], &buf[i+1], (len - i - 1) * sizeof(unichar));
      i--;
      len--;
    }

  aString = [CLString stringWithCharacters:buf length:len];
  free(buf);

  [cvv release];
  cvv = [aString retain];
  
  return;
}

-(void) setExpiration:(CLCalendarDate *) aDate
{
  [expiration autorelease];
  expiration = [aDate retain];
  return;
}

-(void) setAddress:(CLMailingAddress *) anAddress
{
  [address autorelease];
  address = [anAddress retain];
  return;
}

-(CLString *) shortNumber
{
  return [number substringFromIndex:[number length] - 4];
}

-(CLString *) prettyNumber
{
  /* FIXME - format the number to insert blanks like it's stamped on the credit card */
  return number;
}

-(CLNumber *) expirationMonth
{
  return [CLNumber numberWithInt:[expiration monthOfYear]];
}

-(CLNumber *) expirationYear
{
  return [CLNumber numberWithInt:[expiration yearOfCommonEra]];
}

-(void) setExpirationMonth:(CLNumber *) aNumber
{
  CLCalendarDate *aDate;


  if (!(aDate = expiration))
    aDate = [CLCalendarDate calendarDate];
  [self setExpiration:[CLCalendarDate dateWithYear:[aDate yearOfCommonEra]
				      month:[aNumber intValue] + 1
				      day:0 hour:0 minute:0 second:0 timeZone:nil]];
  return;
}

-(void) setExpirationYear:(CLNumber *) aNumber
{
  CLCalendarDate *aDate;


  if (!(aDate = expiration))
    aDate = [CLCalendarDate calendarDate];
  [self setExpiration:[CLCalendarDate dateWithYear:[aNumber intValue]
				      month:[aDate monthOfYear] + 1
				      day:0 hour:0 minute:0 second:0 timeZone:nil]];
  return;
}

-(CLString *) type
{
  return [[self class] type:[self issuer]];
}

-(CLCreditCardIssuer) issuer
{
  return [[self class] issuer:number];
}

@end
