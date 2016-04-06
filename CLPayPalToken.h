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

#ifndef _CLPAYPALTOKEN_H
#define _CLPAYPALTOKEN_H

#import <ClearLake/CLGenericRecord.h>

@interface CLPayPalToken:CLGenericRecord
{
}

+(CLPayPalToken *) tokenForCredentials:(CLDictionary *) credentials;

@end

@interface CLPayPalToken (CLMagic)
-(CLString *) scope;
-(CLString *) accessToken;
-(CLString *) tokenType;
-(CLString *) appID;
-(CLDatetime *) expires;

-(void) setScope:(CLString *) aString;
-(void) setAccessToken:(CLString *) aString;
-(void) setTokenType:(CLString *) aString;
-(void) setAppID:(CLString *) aString;
-(void) setExpires:(CLDatetime *) aDate;
@end

#endif /* _CLPAYPALTOKEN_H */
