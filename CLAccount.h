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

#ifndef _CLACCOUNT_H
#define _CLACCOUNT_H

#import <ClearLake/CLGenericRecord.h>

@class CLDatetime;

typedef enum {
  CLAccountFlagAdmin = 'A',
  CLAccountFlagLocked = 'L',
  CLAccountFlagUnconfirmed = 'U',
  CLAccountFlagInternalUseOnly = 'X',
} CLAccountFlags;

@interface CLAccount:CLObject <CLArchiving>
{
  int objectID;
  CLString *name, *email, *password, *flags, *ipAddress;
  CLDatetime *created, *lastSeen;

  CLString *_plainPass, *_verPass;
  BOOL sawPlain, sawVer;
}

+(CLString *) makeNameValid:(CLString *) aString;

-(int) objectID;
-(CLString *) email;
-(CLString *) name;
-(CLString *) password;
-(CLString *) flags;
-(CLDatetime *) created;
-(CLDatetime *) lastSeen;
-(CLString *) ipAddress;

-(void) setEmail:(CLString *) aString;
-(void) setName:(CLString *) aString;
-(void) setPassword:(CLString *) aString;
-(void) setFlags:(CLString *) aString;
-(void) setCreated:(CLDatetime *) aDate;
-(void) setLastSeen:(CLDatetime *) aDate;
-(void) setIpAddress:(CLString *) aString;

-(BOOL) isAdmin;
-(BOOL) isLocked;
-(void) setAdmin:(BOOL) flag;
-(void) setLocked:(BOOL) flag;
-(BOOL) isActiveAccount;

/* Must call both to set password */
-(void) setPlainPass:(CLString *) aString;
-(void) setVerPass:(CLString *) aString;

-(void) sendEmail:(CLDictionary *) aDict usingTemplate:(CLString *) aFilename;

@end

@interface CLAccount (CLMagic)
-(void) edit:(id) sender;
@end

@interface CLAccount (LinkerIsBorked)
+(void) linkerIsBorked;
@end

#endif /* _CLACCOUNT_H */
