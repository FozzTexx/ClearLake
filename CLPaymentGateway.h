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

#ifndef _CLPAYMENTGATEWAY_H
#define _CLPAYMENTGATEWAY_H

#import <ClearLake/CLObject.h>

@class CLDictionary;

typedef enum {
  CLTransactionCapture = 1,
  CLTransactionAuthorize,
  CLTransactionCredit,
  CLTransactionVoid
} CLTransactionType;

typedef enum {
  CLTransactionApproved = 1,
  CLTransactionDeclined,
  CLTransactionError,
  CLTransactionHeldForReview
} CLTransactionResult;

extern CLString * const CLGatewayPassword;
extern CLString * const CLGatewayUser;
extern CLString * const CLGatewayURL;
extern CLString * const CLGatewayPartner;
extern CLString * const CLGatewaySignature;
extern CLString * const CLGatewayTransactionType;
extern CLString * const CLGatewayCreditCard;
extern CLString * const CLGatewayAmount;
extern CLString * const CLGatewayComment1;
extern CLString * const CLGatewayComment2;
extern CLString * const CLGatewayInvoiceNumber;
extern CLString * const CLGatewayIPAddress;
extern CLString * const CLGatewayTransactionID;
extern CLString * const CLGatewayResultCode;

@protocol CLPaymentProcessing
-(CLDictionary *) processTransaction:(CLDictionary *) aDict;
@end

@interface CLPaymentGateway:CLObject
{
  CLDictionary *credentials;
}

-(id) initFromCredentials:(CLDictionary *) aDict;
-(void) dealloc;

@end

@interface CLPaymentGateway (CLStandardPaymentProcessing)
-(CLDictionary *) processTransaction:(CLDictionary *) aDict;
@end

#endif /* _CLPAYMENTGATEWAY_H */
