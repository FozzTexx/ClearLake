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

#import "CLPaymentGateway.h"
#import "CLString.h"
#import "CLDictionary.h"

CLString * const CLGatewayPassword = @"CLGatewayPassword";
CLString * const CLGatewayUser = @"CLGatewayUser";
CLString * const CLGatewayURL = @"CLGatewayURL";
CLString * const CLGatewayPartner = @"CLGatewayPartner";
CLString * const CLGatewaySignature = @"CLGatewaySignature";
CLString * const CLGatewayTransactionType = @"CLGatewayTransactionType";
CLString * const CLGatewayCreditCard = @"CLGatewayCreditCard";
CLString * const CLGatewayAmount = @"CLGatewayAmount";
CLString * const CLGatewayComment1 = @"CLGatewayComment1";
CLString * const CLGatewayComment2 = @"CLGatewayComment2";
CLString * const CLGatewayInvoiceNumber = @"CLGatewayInvoiceNumber";
CLString * const CLGatewayIPAddress = @"CLGatewayIPAddress";
CLString * const CLGatewayTransactionID = @"CLGatewayTransactionID";
CLString * const CLGatewayReturnURL = @"CLGatewayReturnURL";
CLString * const CLGatewayCancelURL = @"CLGatewayCancelURL";
CLString * const CLGatewayResultCode = @"CLGatewayResultCode";

@implementation CLPaymentGateway

-(id) initFromCredentials:(CLDictionary *) aDict
{
  [super init];
  credentials = [aDict copy];
  return self;
}

-(void) dealloc
{
  [credentials release];
  [super dealloc];
  return;
}

-(CLDictionary *) credentials
{
  return credentials;
}

@end
