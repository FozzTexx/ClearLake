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

#import <ClearLake/CLObject.h>

@class CLString, CLCalendarDate, CLArray, CLMutableArray;

@interface CLCookie:CLObject <CLCopying>
{
  CLString *key;
  id value;
  CLCalendarDate *expires;
  CLString *path;
  CLString *domain;
  BOOL secure, fromBrowser;
}

-(id) init;
-(void) dealloc;

-(CLString *) key;
-(id) value;
-(CLCalendarDate *) expires;
-(CLString *) path;
-(CLString *) domain;
-(BOOL) secure;
-(BOOL) isFromBrowser;
-(CLString *) cookieString;

-(void) setKey:(CLString *) aKey;
-(void) setValue:(id) aValue;
-(void) setExpires:(CLCalendarDate *) when;
-(void) setPath:(CLString *) aPath;
-(void) setDomain:(CLString *) aDomain;
-(void) setSecure:(BOOL) flag;
-(void) setFromBrowser:(BOOL) flag;

@end

extern CLMutableArray *CLCookies, *CLBrowserCookies;
extern BOOL CLCookiesEnabled;

extern void CLAddCookie(CLCookie *aCookie);
extern void CLReplaceCookie(CLCookie *aCookie);
extern CLCookie *CLCookieWithKey(CLString *aKey, BOOL onlyFromBrowser);
extern CLArray *CLCookiesWithKey(CLString *aKey, BOOL onlyFromBrowser);
extern void CLRemoveCookie(CLString *aKey);
