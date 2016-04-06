/* Copyright 2015-2016 by
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

#import "CLPayPalRESTGateway.h"
#import "CLMutableDictionary.h"
#import "CLCreditCard.h"
#import "CLMailingAddress.h"
#import "CLMutableString.h"
#import "CLArray.h"
#import "CLStream.h"
#import "CLNumber.h"
#import "CLNumberFormatter.h"
#import "CLPayPalToken.h"
#import "CLMutableData.h"

@implementation CLPayPalRESTGateway

-(CLDictionary *) processTransaction:(CLDictionary *) parameters
{
  CLPayPalToken *aToken;
  CLMutableDictionary *mDict;
  CLString *cmd;
  CLStream *pStream;
  CLMutableData *mData;
  CLData *aData;
  CLNumberFormatter *format = [CLNumberFormatter numberFormatterFromFormat:@"0.00"];
  CLString *total;
  CLString *aString;
  CLDictionary *aDict, *details;
  id anObject;
  int transactionType;
  CLArray *anArray;
  
  
  aToken = [CLPayPalToken tokenForCredentials:credentials];
  if (!aToken)
    return nil;

  mDict = [[CLMutableDictionary alloc] init];

  transactionType = [[parameters objectForKey:CLGatewayTransactionType] intValue];
  switch (transactionType) {
  case CLTransactionCapture:
    [mDict setObject:CLTrueObject forKey:@"is_final_capture"];
    total = [format stringForObjectValue:[parameters objectForKey:CLGatewayAmount]];
    [mDict setObject:[CLDictionary dictionaryWithObjectsAndKeys:
					      total, @"total", @"USD", @"currency", nil]
	      forKey:@"amount"];
    break;

  case CLTransactionAuthorize:
  case CLTransactionSale:
    if ((anObject = [parameters objectForKey:CLGatewayTransactionID])) {
      [mDict setObject:anObject forKey:@"payer_id"];
    }
    else {
      if (transactionType == CLTransactionAuthorize)
	[mDict setObject:@"authorize" forKey:@"intent"];
      else
	[mDict setObject:@"sale" forKey:@"intent"];
      [mDict setObject:[CLDictionary
			 dictionaryWithObjectsAndKeys:
			     [parameters objectForKey:CLGatewayReturnURL], @"return_url",
			     [parameters objectForKey:CLGatewayCancelURL], @"cancel_url", nil]
		forKey:@"redirect_urls"];
      [mDict setObject:[CLDictionary dictionaryWithObjectsAndKeys:
				       @"paypal", @"payment_method", nil] forKey:@"payer"];

      total = [format stringForObjectValue:[parameters objectForKey:CLGatewayAmount]];
      details = [CLDictionary dictionaryWithObjectsAndKeys:@"0.00", @"shipping",
			      total, @"subtotal",
			      @"0.00", @"tax", nil];

      /* FIXME - list out all items of order */

      aDict = [CLDictionary dictionaryWithObjectsAndKeys:
			      [CLDictionary dictionaryWithObjectsAndKeys:
					      total, @"total",
					    details, @"details",
					    @"USD", @"currency",
					    nil], @"amount", nil];
      [mDict setObject:[CLArray arrayWithObjects:aDict, nil] forKey:@"transactions"];
    }
    break;

  case CLTransactionOrder:
    break;
  case CLTransactionCredit:
    break;
  case CLTransactionVoid:
    break;
  }
  
  cmd = [CLString stringWithFormat:
		    @"curl -s -d @-"
			  " -H 'Content-Type: application/json'"
		" -H 'Authorization: %@ %@'"
			 " %@",
		  [aToken tokenType], [aToken accessToken],
	  [parameters objectForKey:CLGatewayURL]];

  pStream = [CLStream openPipe:cmd mode:CLReadWrite];
  fprintf(stderr, "%s\n", [[mDict json] UTF8String]);
  [pStream writeString:[mDict json] usingEncoding:CLUTF8StringEncoding];
  [pStream closeWrite];
  [mDict release];

  mData = [CLMutableData data];
  while ((aData = [pStream readDataOfLength:1024]) && [aData length])
    [mData appendData:aData];
  [pStream closeAndWait];

  aString = [CLString stringWithData:mData encoding:CLUTF8StringEncoding];
  aDict = [aString decodeJSON];

  mDict = [[CLMutableDictionary alloc] initFromDictionary:aDict];

  /* FIXME - state varies depending on transaction type */
  anObject = [mDict objectForKey:@"state"];
  if ([anObject isEqualToString:@"completed"] ||
      [anObject isEqualToString:@"created"] ||
      [anObject isEqualToString:@"approved"]) {
    [mDict setObject:[CLNumber numberWithInt:CLTransactionApproved]
	   forKey:CLGatewayResultCode];
    anArray = [[[mDict objectForKey:@"transactions"] objectAtIndex:0]
		  objectForKey:@"related_resources"];
    if ([anArray count])
      [mDict setObject:
	       [[[anArray objectAtIndex:0] objectForKey:@"authorization"]
		 objectForKey:@"id"] forKey:CLGatewayTransactionID];
    else
      [mDict setObject:[mDict objectForKey:@"id"] forKey:CLGatewayTransactionID];
  }
  else
    [mDict setObject:[CLNumber numberWithInt:CLTransactionError]
	   forKey:CLGatewayResultCode];
  
  return [mDict autorelease];
}

@end
