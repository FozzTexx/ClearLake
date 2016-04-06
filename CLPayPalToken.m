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

#import "CLPayPalToken.h"
#import "CLPaymentGateway.h"
#import "CLEditingContext.h"
#import "CLDatetime.h"
#import "CLDatabase.h"
#import "CLAttribute.h"
#import "CLArray.h"
#import "CLStream.h"
#import "CLMutableData.h"
#import "CLEditingContext.h"
#import "CLRecordDefinition.h"
#import "CLDictionary.h"

@implementation CLPayPalToken

+(CLPayPalToken *) tokenForCredentials:(CLDictionary *) credentials
{
  CLDatetime *aDate;
  CLString *query;
  CLRecordDefinition *recordDef;
  CLDatabase *db;
  CLArray *rows;
  CLPayPalToken *aToken = nil;
  CLStream *pStream;
  CLMutableData *mData;
  CLData *aData;
  CLDictionary *aDict;
  CLString *aString;


  recordDef = [CLEditingContext recordDefinitionForClass:self];
  db = [recordDef database];
  
  aDate = [CLDatetime now];
  query = [CLString stringWithFormat:@"delete from %@ where expires < '%@'",
		    [recordDef databaseTable],
		    [aDate descriptionWithFormat:[db dateFormat] timeZone:[db timeZone]]];
  [db runQuery:query];

  query = [CLString stringWithFormat:@"select id from %@ limit 1", [recordDef databaseTable]];
  rows = [db read:CLAttributes(@"id:i", nil) qualifier:query errors:NULL];
  if ([rows count]) {
    aToken = [CLDefaultContext loadObjectWithClass:[CLPayPalToken class]
					primaryKey:[rows objectAtIndex:0]];
  }
  else {
    query = [CLString stringWithFormat:
		       @"curl -s %@"
			  " -H 'Accept: application/json'"
		 " -H 'Accept-Language: en_US'"
			      " -u '%@:%@'"
		      " -d 'grant_type=client_credentials'",
		      [[credentials objectForKey:CLGatewayURL]
			stringByAppendingPathComponent:@"v1/oauth2/token"],
		      [credentials objectForKey:CLGatewayUser],
		      [credentials objectForKey:CLGatewayPassword]];
    
    pStream = [CLStream openPipe:query mode:CLReadOnly];
    mData = [CLMutableData data];
    while ((aData = [pStream readDataOfLength:1024]) && [aData length])
      [mData appendData:aData];
    [pStream closeAndWait];
    aString = [CLString stringWithData:mData encoding:CLUTF8StringEncoding];

    if ((aDict = [aString decodeJSON])) {
      aToken = [[self alloc] init];
      [aToken setScope:[aDict objectForKey:@"scope"]];
      [aToken setAccessToken:[aDict objectForKey:@"access_token"]];
      [aToken setTokenType:[aDict objectForKey:@"token_type"]];
      [aToken setAppID:[aDict objectForKey:@"app_id"]];
      [aToken setExpires:[[CLDatetime now]
			   dateByAddingYears:0 months:0 days:0 hours:0 minutes:0
				     seconds:[[aDict objectForKey:@"expires_in"] intValue]]];

      [CLDefaultContext addObject:aToken];
      [CLDefaultContext saveChanges];
    }
  }

  return aToken;
}

@end
