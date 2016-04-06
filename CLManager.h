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

#import <ClearLake/CLObject.h>

@class CLString, CLDictionary, CLForm, CLControl, CLSession, CLPage,
  CLAccount, CLMutableDictionary, CLArray, CLMutableArray, CLEditingContext;

#define CLPasswordRequired	0x01
#define CLNameRequired		0x02
#define CLEmailRequired		0x04
#define CLNameNotUnique		0x08
#define CLEmailNotUnique	0x10

@interface CLManager:CLObject
{
  CLSession *activeSession;
  unsigned int sessionExpire;
  CLString *loginReturn;
  CLMutableArray *acls;
}

+(CLManager *) manager;
+(id) activeSession;
+(id) activeAccount;

+(void) setConfigurationDirectory:(CLString *) aDir;
+(void) setConfigurationFile:(CLString *) aFile;
+(CLString *) configurationFile;
+(CLString *) configurationDirectory;
+(CLMutableDictionary *) readConfigurationFile:(CLString *) aFile;
+(CLString *) configOption:(CLString *) aString;
+(CLString *) domain;
+(CLString *) sslDomain;
+(CLString *) browserType;
+(CLString *) randomPassword;
+(CLString *) randomSalt;
+(CLString *) returnFor:(id) anObject action:(SEL) anAction
	     localQuery:(CLDictionary *) aQuery;

-(id) init;
-(void) dealloc;

-(void) setupSession:(int) anID;
-(CLArray *) getUsers:(id) sender uniqueMask:(CLUInteger) mask ignoreInternal:(BOOL) ignore;
-(int) validateUser:(id) sender uniqueMask:(CLUInteger) mask;
-(BOOL) return:(id) sender;
-(void) preparePage:(CLPage *) aPage;
-(void) login:(id) sender;
-(void) runLoginFor:(id) anObject action:(SEL) anAction
	     sender:(id) sender localQuery:(CLDictionary *) aQuery;
-(void) runLoginFor:(id) anObject action:(SEL) anAction
	     sender:(id) sender localQuery:(CLDictionary *) aQuery
	    message:(CLString *) aMessage;
-(void) runLoginFor:(id) anObject action:(SEL) anAction
	     sender:(id) sender localQuery:(CLDictionary *) aQuery
	    message:(CLString *) aMessage ignore:(BOOL) ignore;
-(void) logout:(id) sender;
-(void) sendPassword:(id) sender;
-(id) activeSession;
-(CLAccount *) activeAccount;
-(void) setActiveSession:(id) aSession;
-(void) emailUser:(CLString *) aUser password:(CLString *) aPass to:(CLString *) anEmail
     instructions:(CLString *) instr bcc:(CLString *) bcc;
-(CLString *) activationLink:(int) accountID;
-(unsigned int) sessionExpire;
-(void) setSessionExpiresAfter:(unsigned int) seconds;
-(id) createAccount:(id) info requirements:(CLUInteger) mask errors:(CLDictionary **) errors;
-(BOOL) checkPermission:(id) anObject;
-(CLString *) loginReturn;
-(CLString *) currentURL;

@end

@protocol CLManagerDelegate
-(BOOL) willValidateAccountID:(int) anID sender:(id) sender;
-(void) accessDenied:(id) anObject;
-(void) willLogout:(CLAccount *) anAccount;
-(void) didLogout:(id) anObject;
-(void) didCreateSession:(CLSession *) aSession;
-(Class) sessionClass;
@end

extern CLString *CLAppName;	/* This is the name of the script
				   without any path info */
extern CLString *CLWebName;	/* This is the local URL of the
				   script. There is no
				   protocol://server.name */
extern CLString *CLAppPath;	/* This is the filesystem path to where the
				   program's files are stored. No trailing '/' */
extern CLString *CLWebPath;	/* This is the URL path to where the program's
				   files are stored. No trailing '/' */
extern CLString *CLServerURL;	/* This is the URL of the server. It
				   contains
				   protocol://server.name:portno. No
				   trailing '/' */

extern CLString *CLUserAgent, *CLBrowserType;

extern CLMutableDictionary *CLQuery, *CLEnvironment;
extern id CLDelegate, CLMainObject;
extern CLPage *CLMainPage;

extern void CLInit();
extern void CLRun(CLString *mainObjectName);
extern void CLInitializeQuery(CLString *aString);
