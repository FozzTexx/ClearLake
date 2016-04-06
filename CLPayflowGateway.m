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

#import "CLPayflowGateway.h"
#import "CLMutableString.h"
#import "CLCreditCard.h"
#import "CLMailingAddress.h"
#import "CLMutableDictionary.h"
#import "CLArray.h"
#import "CLStream.h"
#import "CLNumber.h"

@implementation CLPayflowGateway

-(CLDictionary *) processTransaction:(CLDictionary *) aDict
{
  CLMutableString *mString;
  CLCreditCard *cc;
  CLMailingAddress *address;
  id anObject;
  CLString *aString;
  CLMutableDictionary *mDict;
  CLArray *anArray;
  int i, j;
  CLRange aRange;
  FILE *file;


  mString = [[CLMutableString alloc] initWithString:
				       @"/usr/local/bin/pfpro payflow.verisign.com 443 '"];
  [mString appendFormat:@"PWD=%@&USER=%@&PARTNER=%@",
	   [credentials objectForKey:CLGatewayPassword],
	   [credentials objectForKey:CLGatewayUser],
	   [credentials objectForKey:CLGatewayPartner]];

  [mString appendString:@"&TRXTYPE="];
  switch ([[aDict objectForKey:CLGatewayTransactionType] intValue]) {
  case CLTransactionCapture:
    [mString appendString:@"S"];
    break;
  case CLTransactionAuthorize:
    [mString appendString:@"A"];
    break;
  case CLTransactionCredit:
    [mString appendString:@"C"];
    break;
  case CLTransactionVoid:
    [mString appendString:@"V"];
    break;
  }

  [mString appendString:@"&TENDER=C"];

  if ((cc = [aDict objectForKey:CLGatewayCreditCard])) {
    [mString appendFormat:@"&ACCT=%@", [cc number]];
    [mString appendFormat:@"&EXPDATE=%02i%02i",
	     [[cc expirationMonth] intValue], [[cc expirationYear] intValue] % 100];
    if ((address = [cc address]) && [address zip])
      [mString appendFormat:@"&ZIP=%@", [address zip]];
  }

  [mString appendFormat:@"&AMT=%@", [aDict objectForKey:CLGatewayAmount]];

  if ((anObject = [aDict objectForKey:CLGatewayComment1]))
    [mString appendFormat:@"&COMMENT1=%@", anObject];
  if ((anObject = [aDict objectForKey:CLGatewayComment2]))
    [mString appendFormat:@"&COMMENT2=%@", anObject];
  if ((anObject = [aDict objectForKey:CLGatewayTransactionID]))
    [mString appendFormat:@"&ORIGID=%@", anObject];

  [mString appendString:@"'"];
  
  file = popen([mString UTF8String], "r");
  aString = CLGets(file, CLUTF8StringEncoding);
  pclose(file);

  [mString release];

  mDict = [[CLMutableDictionary alloc] init];
  anArray = [aString componentsSeparatedByString:@"&"];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    aRange = [aString rangeOfString:@"="];
    [mDict setObject:[aString substringFromIndex:CLMaxRange(aRange)]
	   forKey:[aString substringToIndex:aRange.location]];
  }

  if ((aString = [mDict objectForKey:@"RESULT"])) {
    [mDict setObject:aString forKey:CLGatewayResultCode];
    [mDict removeObjectForKey:@"RESULT"];
  }
  if ((aString = [mDict objectForKey:@"PNREF"])) {
    [mDict setObject:aString forKey:CLGatewayTransactionID];
    [mDict removeObjectForKey:@"PNREF"];
  }
  
  return [mDict autorelease];
}

@end
