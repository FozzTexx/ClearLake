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

#ifndef _CLACCOUNT_H
#define _CLACCOUNT_H

#import <ClearLake/CLGenericRecord.h>

@class CLCalendarDate;

typedef enum {
  CLAccountFlagAdmin = 'A',
  CLAccountFlagLocked = 'L',
} CLAccountFlags;

@interface CLAccount:CLGenericRecord
{
  CLString *plainPass, *verPass;
  BOOL sawPlain, sawVer;
}

+(CLString *) makeNameValid:(CLString *) aString;

-(BOOL) isAdmin;
-(BOOL) isLocked;
-(void) setAdmin:(BOOL) flag;
-(void) setLocked:(BOOL) flag;
-(BOOL) isActiveAccount;
-(void) sendEmail:(CLDictionary *) aDict usingTemplate:(CLString *) aFilename;

@end

@interface CLAccount (CLMagic)
-(CLString *) email;
-(CLString *) name;
-(CLString *) password;
-(CLString *) flags;
-(CLCalendarDate *) created;
-(CLCalendarDate *) lastSeen;
-(CLString *) ipAddress;

-(void) setEmail:(CLString *) aString;
-(void) setName:(CLString *) aString;
-(void) setPassword:(CLString *) aString;
-(void) setFlags:(CLString *) aString;
-(void) setCreated:(CLCalendarDate *) aDate;
-(void) setLastSeen:(CLCalendarDate *) aDate;
-(void) setIpAddress:(CLString *) aString;
@end

#endif /* _CLACCOUNT_H */
