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

#import "CLPayPalDirectGateway.h"
#import "CLMutableDictionary.h"
#import "CLCreditCard.h"
#import "CLMailingAddress.h"
#import "CLMutableString.h"
#import "CLArray.h"
#import "CLStream.h"
#import "CLNumber.h"
#import "CLNumberFormatter.h"
#import "CLMutableData.h"

#include <time.h>

@implementation CLPayPalDirectGateway

-(CLDictionary *) processTransaction:(CLDictionary *) aDict
{
  CLMutableDictionary *mDict;
  CLCreditCard *cc;
  CLString *aString;
  CLMailingAddress *address;
  CLMutableString *mString;
  CLArray *anArray;
  CLRange aRange;
  id anObject;
  int i, j;
  CLNumberFormatter *format = [CLNumberFormatter numberFormatterFromFormat:@"0.00"];
  CLStream *pStream;
  CLMutableData *mData;
  CLData *aData;


  mDict = [[CLMutableDictionary alloc] init];

  [mDict setObject:[credentials objectForKey:CLGatewayUser] forKey:@"USER"];
  [mDict setObject:[credentials objectForKey:CLGatewayPassword] forKey:@"PWD"];
  [mDict setObject:[credentials objectForKey:CLGatewaySignature] forKey:@"SIGNATURE"];
  [mDict setObject:@"56.0" forKey:@"VERSION"];
  
  switch ([[aDict objectForKey:CLGatewayTransactionType] intValue]) {
  case CLTransactionCapture:
    if ((anObject = [aDict objectForKey:CLGatewayTransactionID])) {
      [mDict setObject:@"DoCapture" forKey:@"METHOD"];
      [mDict setObject:anObject forKey:@"AUTHORIZATIONID"];
      /* Some new field that used to be optional */
      [mDict setObject:@"Complete" forKey:@"COMPLETETYPE"];
    }
    else {
      [mDict setObject:@"DoDirectPayment" forKey:@"METHOD"];
      [mDict setObject:@"Sale" forKey:@"PAYMENTACTION"];
    }
    break;
  case CLTransactionAuthorize:
    [mDict setObject:@"DoDirectPayment" forKey:@"METHOD"];
    [mDict setObject:@"Authorization" forKey:@"PAYMENTACTION"];
    break;
  case CLTransactionCredit:
    if ((anObject = [aDict objectForKey:CLGatewayTransactionID])) {
      [mDict setObject:@"RefundTransaction" forKey:@"METHOD"];
      [mDict setObject:anObject forKey:@"AUTHORIZATIONID"];
    }
    else
      [mDict setObject:@"DoNonReferencedCredit" forKey:@"METHOD"];
    break;
  case CLTransactionVoid:
    [mDict setObject:@"DoVoid" forKey:@"METHOD"];
    [mDict setObject:[aDict objectForKey:CLGatewayTransactionID]
	   forKey:@"AUTHORIZATIONID"];
    break;
  }

  [mDict setObject:[format stringForObjectValue:[aDict objectForKey:CLGatewayAmount]]
	    forKey:@"AMT"];
  [mDict setObject:[aDict objectForKey:CLGatewayIPAddress] forKey:@"IPADDRESS"];
  
  if ((cc = [aDict objectForKey:CLGatewayCreditCard])) {
    switch ([cc issuer]) {
    case CLVISAIssuer:
      [mDict setObject:@"Visa" forKey:@"CREDITCARDTYPE"];
      break;
    case CLMasterCardIssuer:
      [mDict setObject:@"MasterCard" forKey:@"CREDITCARDTYPE"];
      break;
    case CLAmericanExpressIssuer:
      [mDict setObject:@"Amex" forKey:@"CREDITCARDTYPE"];
      break;
    case CLDiscoverIssuer:
      [mDict setObject:@"Discover" forKey:@"CREDITCARDTYPE"];
      break;
    default:
      [mDict setObject:@"Unknown" forKey:@"CREDITCARDTYPE"];
      break;
    }
    [mDict setObject:[cc number] forKey:@"ACCT"];
    [mDict setObject:[CLString stringWithFormat:@"%02i%04i",
			       [[cc expirationMonth] intValue],
			       [[cc expirationYear] intValue]] forKey:@"EXPDATE"];
    [mDict setObject:[cc cvv] forKey:@"CVV2"];

    if ((address = [cc address])) {
      [mDict setObject:[address address1] forKey:@"STREET"];
      if ((anObject = [address address2]))
	[mDict setObject:anObject forKey:@"STREET2"];
      [mDict setObject:[address city] forKey:@"CITY"];
      [mDict setObject:[address state] forKey:@"STATE"];
      [mDict setObject:@"US" forKey:@"COUNTRYCODE"];
      [mDict setObject:[address zip] forKey:@"ZIP"];

      /* Apparently these things used to be optional but aren't now. WTF? */
      aString = [address name];
      anArray = [aString componentsSeparatedByString:@" "];
      if ([anArray count]) {
	[mDict setObject:[anArray objectAtIndex:0] forKey:@"FIRSTNAME"];
	[mDict setObject:[anArray lastObject] forKey:@"LASTNAME"];
      }
    }
  }

  if ((anObject = [aDict objectForKey:CLGatewayComment1]))
    [mDict setObject:anObject forKey:@"DESC"];
  if ((anObject = [aDict objectForKey:CLGatewayComment2]))
    [mDict setObject:anObject forKey:@"CUSTOM"];
  if ((anObject = [aDict objectForKey:CLGatewayInvoiceNumber]))
    [mDict setObject:[CLString stringWithFormat:@"%i-%@", time(NULL), anObject]
	   forKey:@"INVNUM"];

  mString = [[CLMutableString alloc] init];
  anArray = [mDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    if (i)
      [mString appendString:@"&"];
    [mString appendFormat:@"%@=%@",
	     [aString stringByAddingPercentEscapes],
	     [[[mDict objectForKey:aString] description] stringByAddingPercentEscapes]];
  }
  [mDict release];

  [mString appendString:@"\n"];
  
  aString = [CLString stringWithFormat:@"/usr/bin/curl -s -d @- %@",
		      [credentials objectForKey:CLGatewayURL]];

  pStream = [CLStream openPipe:aString mode:CLReadWrite];
  [pStream writeString:mString usingEncoding:CLUTF8StringEncoding];
  [pStream closeWrite];

  mData = [CLMutableData data];
  while ((aData = [pStream readDataOfLength:1024]) && [aData length])
    [mData appendData:aData];
  [pStream closeAndWait];

  aString = [CLString stringWithData:mData encoding:CLUTF8StringEncoding];
  mDict = [[CLMutableDictionary alloc] init];
  anArray = [aString componentsSeparatedByString:@"&"];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aString = [anArray objectAtIndex:i];
    aRange = [aString rangeOfString:@"="];
    [mDict setObject:[[aString substringFromIndex:CLMaxRange(aRange)]
		       stringByReplacingPercentEscapes]
	   forKey:[[aString substringToIndex:aRange.location]
		    stringByReplacingPercentEscapes]];
  }

  if ((anObject = [mDict objectForKey:@"TRANSACTIONID"]))
    [mDict setObject:anObject forKey:CLGatewayTransactionID];

  anObject = [mDict objectForKey:@"ACK"];
  if ([anObject hasPrefix:@"Success"])
    [mDict setObject:[CLNumber numberWithInt:CLTransactionApproved]
	   forKey:CLGatewayResultCode];
  else if ([anObject hasPrefix:@"Failure"])
    [mDict setObject:[CLNumber numberWithInt:CLTransactionDeclined]
	   forKey:CLGatewayResultCode];
  else
    [mDict setObject:[CLNumber numberWithInt:CLTransactionError]
	   forKey:CLGatewayResultCode];

  return [mDict autorelease];  
}

@end
