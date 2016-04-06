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

#import "CLAuthorizeNetGateway.h"
#import "CLMutableString.h"
#import "CLCreditCard.h"
#import "CLMailingAddress.h"
#import "CLMutableDictionary.h"
#import "CLStream.h"
#import "CLArray.h"
#import "CLNumber.h"
#import "CLMutableData.h"

/* This supports the Authorize.net Advanced Integration Method (AIM)
 *
 * https://developer.authorize.net/guides/AIM/wwhelp/wwhimpl/js/html/wwhelp.htm
*/

@interface CLString (CLAuthorizeNetGateway)
-(CLString *) authorizeNetString;
@end

@implementation CLString (CLAuthorizeNetGateway)

-(CLString *) authorizeNetString
{
  return [[self stringByReplacingOccurrencesOfString:@"\"" withString:@""]
	   stringByAddingPercentEscapes];
}

@end

@implementation CLAuthorizeNetGateway

-(CLDictionary *) processTransaction:(CLDictionary *) aDict
{
  CLMutableString *mString;
  CLCreditCard *cc;
  CLMailingAddress *address;
  id anObject;
  CLString *aString;
  CLMutableDictionary *mDict;
  CLArray *anArray;
  CLStream *pStream;
  CLMutableData *mData;
  CLData *aData;

  
  mString = [[CLMutableString alloc] init];
  
  [mString appendFormat:@"x_tran_key=%@&x_login=%@",
	   [[[credentials objectForKey:CLGatewayPassword] description]
	     authorizeNetString],
	   [[[credentials objectForKey:CLGatewayUser] description]
	     authorizeNetString]];

  [mString appendString:@"&x_version=3.1&x_delim_data=TRUE&x_delim_char=,&x_encap_char=\""];
  
  [mString appendString:@"&x_type="];
  switch ([[aDict objectForKey:CLGatewayTransactionType] intValue]) {
  case CLTransactionCapture:
    if ((anObject = [aDict objectForKey:CLGatewayTransactionID]))
      [mString appendFormat:@"PRIOR_AUTH_CAPTURE&x_trans_id=%@",
	       [[anObject description] authorizeNetString]];
    else
      [mString appendString:@"AUTH_CAPTURE"];
    break;
  case CLTransactionAuthorize:
    [mString appendString:@"AUTH_ONLY"];
    break;
  case CLTransactionCredit:
    [mString appendFormat:@"CREDIT&x_trans_id=%@",
	     [[[aDict objectForKey:CLGatewayTransactionID] description]
	       authorizeNetString]];
    break;
  case CLTransactionVoid:
    [mString appendFormat:@"VOID&x_trans_id=%@",
	     [[[aDict objectForKey:CLGatewayTransactionID] description]
	       authorizeNetString]];
    break;
  }

  if ((cc = [aDict objectForKey:CLGatewayCreditCard])) {
    [mString appendFormat:@"&x_card_num=%@", [[[cc number] description]
					       authorizeNetString]];
    [mString appendFormat:@"&x_exp_date=%02i-%04i",
	     [[cc expirationMonth] intValue], [[[cc expirationYear] description] intValue]];
    if ((aString = [cc cvv]))
      [mString appendFormat:@"&x_card_code=%@", [[aString description]
						  authorizeNetString]];

    if ((address = [cc address])) {
      if ((aString = [address address1]))
	[mString appendFormat:@"&x_address=%@", [[aString description]
						  authorizeNetString]];
      if ((aString = [address zip]))
	[mString appendFormat:@"&x_zip=%@", [[[aString description] substringFromIndex:2]
					      authorizeNetString]];
      if ((aString = [address phone]))
	[mString appendFormat:@"&x_phone=%@", [[aString description]
						authorizeNetString]];
      if ((aString = [address name])) {
	CLString *first = nil, *last;
	CLRange aRange;

	
	last = aString;
	aRange = [last rangeOfString:@" " options:CLBackwardsSearch];
	if (aRange.length) {
	  first = [last substringToIndex:aRange.location];
	  last = [last substringFromIndex:CLMaxRange(aRange)];
	}

	if (first)
	  [mString appendFormat:@"&x_first_name=%@", [[first description]
						       authorizeNetString]];
	[mString appendFormat:@"&x_last_name=%@", [[last description]
						    authorizeNetString]];
      }
    }
  }

  [mString appendFormat:@"&x_amount=%@", [aDict objectForKey:CLGatewayAmount]];

  if ((anObject = [aDict objectForKey:CLGatewayComment1]))
    [mString appendFormat:@"&x_invoice_num=%@", [[anObject description]
						  authorizeNetString]];
  if ((anObject = [aDict objectForKey:CLGatewayComment2]))
    [mString appendFormat:@"&x_description=%@", [[anObject description]
						  authorizeNetString]];
  if ((anObject = [aDict objectForKey:CLGatewayTransactionID]))
    [mString appendFormat:@"&x_trans_id=%@", [[anObject description]
					       authorizeNetString]];

  if ((anObject = [aDict objectForKey:CLGatewayIPAddress]))
    [mString appendFormat:@"&x_customer_ip=%@", [[anObject description]
					       authorizeNetString]];
  
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

  mDict = [[CLMutableDictionary alloc] init];
  anArray = [[CLString stringWithData:mData encoding:CLUTF8StringEncoding] decodeCSV];
  if ([anArray count])
    [mDict setObject:[anArray objectAtIndex:0] forKey:CLGatewayResultCode];
  if ([anArray count] > 6)
    [mDict setObject:[anArray objectAtIndex:6] forKey:CLGatewayTransactionID];
  
  return [mDict autorelease];
}

@end
