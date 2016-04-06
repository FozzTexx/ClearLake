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

#import "CLCreditCard.h"
#import "CLMutableString.h"
#import "CLNumber.h"
#import "CLMailingAddress.h"
#import "CLDatetime.h"

#include <stdlib.h>
#include <ctype.h>
#include <string.h>

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
  name = nil;
  number = cvv = nil;
  expiration = nil;
  address = nil;
  return self;
}

-(void) dealloc
{
  [name release];
  [number release];
  [cvv release];
  [expiration release];
  [address release];
  [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLCreditCard *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->name = [name copy];
  aCopy->number = [number copy];
  aCopy->cvv = [cvv copy];
  aCopy->expiration = [expiration copy];
  aCopy->address = [address copy];
  return aCopy;
}

-(CLString *) name
{
  return name;
}

-(CLString *) number
{
  return number;
}

-(CLString *) cvv
{
  return cvv;
}

-(CLDatetime *) expiration
{
  return expiration;
}

-(CLMailingAddress *) address
{
  return address;
}

-(void) setName:(CLString *) aString
{
  if (name != aString) {
    [name release];
    name = [aString retain];
  }
  return;
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

  /* Not using wide iswdigit since I only want 0-9. Should I do a
     conversion to ASCII first to make sure unicode digits are
     forced to 0-9? */
  for (i = 0; i < len; i++)
    if (!isdigit(buf[i])) {
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
    if (!isdigit(buf[i])) {
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

-(void) setExpiration:(CLDatetime *) aDate
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

-(CLString *) formatNumber:(CLString *) aNumber, ...
{
  va_list ap;
  CLMutableString *mString;
  CLString *aString;
  CLRange aRange;
  int len;


  mString = [CLMutableString string];
  len = [aNumber length];
  aRange.location = 0;
  aRange.length = len;
  
  va_start(ap, aNumber);
  while ((aRange.length = va_arg(ap, int))) {
    if (CLMaxRange(aRange) > len)
      aRange.length = len - aRange.location;
    aString = [aNumber substringWithRange:aRange];
    if (![aString length])
      break;
    
    if ([mString length])
      [mString appendString:@" "];
    [mString appendString:aString];
    aRange.location += aRange.length;
    if (aRange.location >= len)
      break;
  }
  va_end(ap);

  if (aRange.location < len) {
    if ([mString length])
      [mString appendString:@" "];
    [mString appendString:[aNumber substringFromIndex:aRange.location]];
  }
    
  return mString;
}
  
-(CLString *) prettyNumber
{
  CLString *aString;

  
  switch ([self issuer]) {
  case CLAmericanExpressIssuer:
    aString = [self formatNumber:number, 4, 6, 5, 0];
    break;

  default:
    aString = [self formatNumber:number, 4, 4, 4, 4, 0];
    break;
  }

  return aString;
}

-(void) setPrettyNumber:(CLString *) aString
{
  [self setNumber:aString];
  return;
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
  CLDatetime *aDate;


  if (!(aDate = expiration))
    aDate = [CLDatetime now];
  [self setExpiration:[CLDatetime dateWithYear:[aDate yearOfCommonEra]
				      month:[aNumber intValue] + 1
				      day:0 hour:0 minute:0 second:0 timeZone:nil]];
  return;
}

-(void) setExpirationYear:(CLNumber *) aNumber
{
  CLDatetime *aDate;


  if (!(aDate = expiration))
    aDate = [CLDatetime now];
  [self setExpiration:[CLDatetime dateWithYear:[aNumber intValue]
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
