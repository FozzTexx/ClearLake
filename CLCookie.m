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

#import "CLCookie.h"
#import "CLMutableString.h"
#import "CLManager.h"
#import "CLCalendarDate.h"
#import "CLTimeZone.h"
#import "CLMutableArray.h"

CLMutableArray *CLCookies = nil, *CLBrowserCookies = nil;
BOOL CLCookiesEnabled = NO;

@implementation CLCookie

-(id) init
{
  [super init];
  key = value = nil;
  expires = 0;
  path = domain = nil;
  secure = fromBrowser = NO;
  return self;
}

-(void) dealloc
{
  [key release];
  [value release];
  [path release];
  [domain release];
  [expires release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLCookie *aCopy;


  aCopy = [super copy];
  aCopy->key = [key copy];
  aCopy->value = [value copy];
  aCopy->expires = [expires copy];
  aCopy->path = [path copy];
  aCopy->domain = [domain copy];
  aCopy->secure = secure;
  aCopy->fromBrowser = fromBrowser;
  return aCopy;
}

-(CLString *) key
{
  return key;
}

-(id) value
{
  return value;
}

-(CLCalendarDate *) expires
{
  return expires;
}

-(CLString *) path
{
  return path;
}

-(CLString *) domain
{
  return domain;
}

-(BOOL) secure
{
  return secure;
}

-(BOOL) isFromBrowser
{
  return fromBrowser;
}

-(CLString *) cookieString
{
  CLMutableString *mString;
  
  
  if (!key || !value)
    return nil;

  mString = [[CLMutableString alloc] init];
  [mString appendFormat:@"%@=%@", [[key description] stringByAddingPercentEscapes],
	   [[value description] stringByAddingPercentEscapes]];
  
  if (expires)
    [mString appendFormat:@"; expires=%@",
	     [expires descriptionWithCalendarFormat:@"%a, %d-%b-%Y %H:%M:%S GMT"
		      timeZone:[CLTimeZone timeZoneWithName:@"UTC+0000"]]];

  [mString appendFormat:@"; path=%@", path ? path : CLWebName];

  if (domain)
    [mString appendFormat:@"; domain=%@", domain];
  if (secure)
    [mString appendFormat:@"; secure"];

  return [mString autorelease];
}
  
-(void) setKey:(CLString *) aKey
{
  [key release];
  key = [aKey copy];
  return;
}

-(void) setValue:(id) aValue
{
  [value release];
  value = [aValue copy];
  return;
}

-(void) setExpires:(CLCalendarDate *) when
{
  [expires autorelease];
  expires = [when copy];
  return;
}

-(void) setPath:(CLString *) aPath
{
  [path release];
  path = [aPath copy];
  return;
}

-(void) setDomain:(CLString *) aDomain
{
  [domain release];
  domain = [aDomain copy];
  return;
}

-(void) setSecure:(BOOL) flag
{
  secure = flag;
  return;
}

-(void) setFromBrowser:(BOOL) flag
{
  fromBrowser = flag;
  return;
}

@end

void CLAddCookie(CLCookie *aCookie)
{
  if (!CLCookies) {
    CLCookies = [[CLMutableArray alloc] init];
    CLAddToCleanup(CLCookies);
  }

  if ([aCookie value]) {
    [CLCookies addObject:aCookie];
    if ([aCookie isFromBrowser]) {
      if (!CLBrowserCookies) {
	CLBrowserCookies = [[CLMutableArray alloc] init];
	CLAddToCleanup(CLBrowserCookies);
      }
      [CLBrowserCookies addObject:aCookie];
    }
  }
  
  return;
}

void CLReplaceCookie(CLCookie *aCookie)
{
  CLRemoveCookie([aCookie key]);
  CLAddCookie(aCookie);
  return;
}

CLCookie *CLCookieWithKey(CLString *aKey, BOOL onlyFromBrowser)
{
  CLArray *anArray;


  anArray = CLCookiesWithKey(aKey, onlyFromBrowser);
  if ([anArray count])
    return [anArray objectAtIndex:0];
  return nil;
}

/* Plural */
CLArray *CLCookiesWithKey(CLString *aKey, BOOL onlyFromBrowser)
{
  int i, j;
  CLCookie *aCookie = nil;
  CLMutableArray *mArray = nil;
  CLArray *cookies = CLCookies;


  if (onlyFromBrowser)
    cookies = CLBrowserCookies;
  
  for (i = 0, j = [cookies count]; i < j; i++) {
    aCookie = [cookies objectAtIndex:i];
    if ([[aCookie key] isEqualToString:aKey]) {
      if (!mArray)
	mArray = [[CLMutableArray alloc] init];
      [mArray addObject:aCookie];
    }
  }

  return [mArray autorelease];
}

void CLRemoveCookie(CLString *aKey)
{
  int i, j;
  id aCookie = nil;


  for (i = 0, j = [CLCookies count]; i < j; i++) {
    aCookie = [CLCookies objectAtIndex:i];
    if ([[aCookie key] isEqualToString:aKey]) {
      [CLCookies removeObjectAtIndex:i];
      i = 0;
      j = [CLCookies count];
    }
  }

  return;
}
