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

#import "CLAuthorizeNetGateway.h"
#import "CLMutableString.h"
#import "CLCreditCard.h"
#import "CLMailingAddress.h"
#import "CLMutableDictionary.h"
#import "CLStream.h"
#import "CLArray.h"

#include <unistd.h>
#include <sys/wait.h>
#include <stdlib.h>
#include <string.h>

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
  int i, j;
  FILE *file;
  int wp[2], rp[2];
  int cid;
  int err;
  CLArray *args;
  const char **argv;
  const char *p;

  
  mString = [[CLMutableString alloc] init];
  
  [mString appendFormat:@"x_tran_key=%@&x_login=%@",
	   [[[credentials objectForKey:CLGatewayPassword] description]
	     stringByAddingPercentEscapes],
	   [[[credentials objectForKey:CLGatewayUser] description]
	     stringByAddingPercentEscapes]];

  [mString appendString:@"&x_version=3.1&x_delim_data=TRUE&x_delim_char=,"];
  
  [mString appendString:@"&x_type="];
  switch ([[aDict objectForKey:CLGatewayTransactionType] intValue]) {
  case CLTransactionCapture:
    if ((anObject = [aDict objectForKey:CLGatewayTransactionID]))
      [mString appendFormat:@"PRIOR_AUTH_CAPTURE&x_trans_id=%@",
	       [[anObject description] stringByAddingPercentEscapes]];
    else
      [mString appendString:@"AUTH_CAPTURE"];
    break;
  case CLTransactionAuthorize:
    [mString appendString:@"AUTH_ONLY"];
    break;
  case CLTransactionCredit:
    [mString appendFormat:@"CREDIT&x_trans_id=%@",
	     [[[aDict objectForKey:CLGatewayTransactionID] description]
	       stringByAddingPercentEscapes]];
    break;
  case CLTransactionVoid:
    [mString appendFormat:@"VOID&x_trans_id=%@",
	     [[[aDict objectForKey:CLGatewayTransactionID] description]
	       stringByAddingPercentEscapes]];
    break;
  }

  if ((cc = [aDict objectForKey:CLGatewayCreditCard])) {
    [mString appendFormat:@"&x_card_num=%@", [[[cc number] description]
					       stringByAddingPercentEscapes]];
    [mString appendFormat:@"&x_exp_date=%02i-%04i",
	     [[cc expirationMonth] intValue], [[[cc expirationYear] description] intValue]];
    if ((aString = [cc cvv]))
      [mString appendFormat:@"&x_card_code=%@", [[aString description]
						  stringByAddingPercentEscapes]];

    if ((address = [cc address])) {
      if ((aString = [address address1]))
	[mString appendFormat:@"&x_address=%@", [[aString description]
						  stringByAddingPercentEscapes]];
      if ((aString = [address zip]))
	[mString appendFormat:@"&x_zip=%@", [[[aString description] substringFromIndex:2]
					      stringByAddingPercentEscapes]];
      if ((aString = [address phone]))
	[mString appendFormat:@"&x_phone=%@", [[aString description]
						stringByAddingPercentEscapes]];
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
						       stringByAddingPercentEscapes]];
	[mString appendFormat:@"&x_last_name=%@", [[last description]
						    stringByAddingPercentEscapes]];
      }
    }
  }

  [mString appendFormat:@"&x_amount=%@", [aDict objectForKey:CLGatewayAmount]];

  if ((anObject = [aDict objectForKey:CLGatewayComment1]))
    [mString appendFormat:@"&x_invoice_num=%@", [[anObject description]
						  stringByAddingPercentEscapes]];
  if ((anObject = [aDict objectForKey:CLGatewayComment2]))
    [mString appendFormat:@"&x_description=%@", [[anObject description]
						  stringByAddingPercentEscapes]];
  if ((anObject = [aDict objectForKey:CLGatewayTransactionID]))
    [mString appendFormat:@"&x_trans_id=%@", [[anObject description]
					       stringByAddingPercentEscapes]];

  if ((anObject = [aDict objectForKey:CLGatewayIPAddress]))
    [mString appendFormat:@"&x_customer_ip=%@", [[anObject description]
					       stringByAddingPercentEscapes]];
  
  [mString appendString:@"\n"];
  
  aString = [CLString stringWithFormat:@"/usr/bin/curl -s -d @- %@",
		      [credentials objectForKey:CLGatewayURL]];

  pipe(wp);
  pipe(rp);

  if ((cid = fork())) {
    close(wp[0]);
    close(rp[1]);
    p = [mString UTF8String];
    write(wp[1], p, strlen(p));
    [mString release];
    close(wp[1]);
    mString = [[CLMutableString alloc] init];
    file = fdopen(rp[0], "r");
    while ((aString = CLGets(file, CLUTF8StringEncoding)))
      [mString appendString:aString];
    fclose(file);
    aString = [mString autorelease];
    waitpid(cid, &err, 0);
  }
  else {
    close(wp[1]);
    close(rp[0]);
    dup2(wp[0], 0);
    dup2(rp[1], 1);
    close(wp[0]);
    close(rp[1]);
    args = [aString componentsSeparatedByString:@" "];
    j = [args count];
    if (!(argv = malloc(sizeof(char *) * (j + 1))))
      [self error:@"Unable to allocate memory"];
    for (i = 0; i < j; i++)
      argv[i] = [[args objectAtIndex:i] UTF8String];
    argv[i] = NULL;
    execv(argv[0], (char **) argv);
  }

  mDict = [[CLMutableDictionary alloc] init];
  anArray = [aString decodeCSV];
  if ([anArray count])
    [mDict setObject:[anArray objectAtIndex:0] forKey:CLGatewayResultCode];
  if ([anArray count] > 6)
    [mDict setObject:[anArray objectAtIndex:6] forKey:CLGatewayTransactionID];
  
  return [mDict autorelease];
}

@end
