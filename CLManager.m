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

/* This is way up here so I can get the special function to return the current directory */
#define _GNU_SOURCE
#include <unistd.h>

#import "CLManager.h"
#import "CLPage.h"
#import "CLMutableString.h"
#import "CLCharacterSet.h"
#import "CLCalendarDate.h"
#import "CLSession.h"
#import "CLMutableArray.h"
#import "CLAttribute.h"
#import "CLMutableDictionary.h"
#import "CLNumber.h"
#import "CLCookie.h"
#import "CLControl.h"
#import "CLForm.h"
#import "CLData.h"
#import "CLField.h"
#import "CLOpenFile.h"
#import "CLAccount.h"
#import "CLHashTable.h"
#import "CLValidation.h"
#import "CLAutoreleasePool.h"
#import "CLTimeZone.h"
#import "CLEmailMessage.h"
#import "CLRegularExpression.h"
#import "CLAccessControl.h"
#import "CLDatabase.h"
#import "CLNull.h"
#import "CLObjCAPI.h"

#include <stdlib.h>
#include <stdio.h>
#include <pwd.h>
#include <netinet/in.h>
#include <arpa/nameser.h>
#include <crypt.h>
#include <ctype.h>
#include <sys/time.h>

/* FIXME - sposed to be declared in stdio.h but it's not */
extern char *cuserid(char *string);

/* FIXME - make these part of ClearLake somehow */
#define RANDOMIZE	"/usr/local/bin/randomize"
#define WORDLIST	"/usr/local/lib/kjv.words"

#define URL_START	@"start_url"
#define URL_REFERRER	@"referrer_url"

#define COOKIE_SESSION	@"CL-session"

#define FIELD_ACCOUNT	@"cl_account"
#define FIELD_PASSWORD	@"cl_password"
#define FIELD_VERPASS	@"cl_verpass"
#define FIELD_EMAIL	@"cl_email"
#define FIELD_RETURN	@"cl_return"
#define FIELD_CREATE	@"cl_create"
#define FIELD_SKIP	@"cl_skip"

#define PAGE_LOGIN	@"cl_login"
#define PAGE_FORGOT	@"cl_recover"
#define PAGE_SIGNUP	@"cl_signup"

#define QUERY_RETURN	@"cl_return"
#define QUERY_USER	@"cl_user"
#define QUERY_ACCOUNT	@"CLuser"
#define QUERY_SESSIONID	@"CLsid"

#define MSG_FORGOT	@"cl_recover-msg"

static char *cryptset = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789./";
static id _manager = nil;
static CLString *CLConfigDir = nil;
static CLString *CLConfigFile = nil;
static CLMutableDictionary *CLConfig = nil;

@implementation CLManager

+(void) initialize
{
  CLInit();
  return;
}

+(CLManager *) manager
{
  if (!_manager) {
    _manager = [[self alloc] init];
    CLAddToCleanup(_manager);
  }
  return _manager;
}

+(CLSession *) activeSession
{
  return [[self manager] activeSession];
}

+(CLAccount *) activeAccount
{
  return [[[self manager] activeSession] account];
}

+(void) setConfigurationDirectory:(CLString *) aDir
{
  [CLConfigDir autorelease];
  CLConfigDir = [aDir copy];
  CLAddToCleanup(CLConfigDir);
  return;
}

+(void) setConfigurationFile:(CLString *) aFile
{
  char *buf;

  
  if (![aFile isAbsolutePath]) {
    buf = get_current_dir_name();
    aFile = [[CLString stringWithUTF8String:buf] stringByAppendingPathComponent:aFile];
    free(buf);
  }
  
  CLConfigFile = [aFile copy];
  CLAddToCleanup(CLConfigFile);
  if (!CLConfigDir) {
    CLConfigDir = [[aFile stringByDeletingLastPathComponent] retain];
    CLAddToCleanup(CLConfigDir);
  }
  return;
}
  
+(CLString *) configurationFile
{
  const char *username;
  struct passwd *pwent;
  CLString *aString = nil, *docRoot;
  CLMutableArray *mArray;
  int i, j;
  

  if (CLConfigFile)
    return CLConfigFile;
  
  if (!CLConfigDir) {
    mArray = [[CLMutableArray alloc] init];

    if (CLAppName)
      [mArray addObject:[CLAppName stringByAppendingPathExtension:@"conf"]];
    [mArray addObject:@"db.conf"];

    if ((docRoot = [CLEnvironment objectForKey:@"DOCUMENT_ROOT"])) {
      aString = [[[[[docRoot stringByDeletingLastPathComponent]
		     stringByAppendingPathComponent:CLAppName]
		    stringByAppendingPathExtension:@"conf"]
		   stringByAppendingPathComponent:CLAppName]
		  stringByAppendingPathExtension:@"conf"];
      [mArray addObject:aString];

      aString = [[[docRoot stringByDeletingLastPathComponent]
		   stringByAppendingPathComponent:CLAppName]
		  stringByAppendingPathExtension:@"conf"];
      [mArray addObject:aString];
      
      aString = [[docRoot stringByDeletingLastPathComponent]
		  stringByAppendingPathComponent:@"db.conf"];
      [mArray addObject:aString];

      aString = [[[[[docRoot stringByDeletingLastPathComponent]
		     stringByAppendingPathComponent:@"conf"]
		    stringByAppendingPathComponent:CLAppName]
		   stringByAppendingPathComponent:CLAppName]
		  stringByAppendingPathExtension:@"conf"];
      [mArray addObject:aString];

      aString = [[[[docRoot stringByDeletingLastPathComponent]
		    stringByAppendingPathComponent:@"conf"]
		   stringByAppendingPathComponent:CLAppName]
		  stringByAppendingPathExtension:@"conf"];
      [mArray addObject:aString];
    }

    if (CLAppName) {
      [mArray addObject:[CLString stringWithFormat:@"/etc/%@.conf", CLAppName]];
      [mArray addObject:[CLString stringWithFormat:@"/etc/%@/db.conf", CLAppName]];

      if (!(username = cuserid(NULL)))
	username = getlogin();
      if (username)
	pwent = getpwnam(username);
      else
	pwent = getpwuid(getuid());
      aString = [[[CLString stringWithUTF8String:pwent->pw_dir]
		   stringByAppendingPathComponent:CLAppName]
		  stringByAppendingPathExtension:@"conf"];
      [mArray addObject:aString];

      if ((docRoot = [CLEnvironment objectForKey:@"SCRIPT_FILENAME"])) {
	aString = [[[[[[docRoot stringByDeletingLastPathComponent]
			stringByDeletingLastPathComponent]
		       stringByAppendingPathComponent:@"conf"]
		      stringByAppendingPathComponent:CLAppName]
		     stringByAppendingPathComponent:CLAppName]
		    stringByAppendingPathExtension:@"conf"];
	[mArray addObject:aString];
      }
    }

    for (i = 0, j = [mArray count]; i < j; i++) {
      aString = [mArray objectAtIndex:i];
      if (!access([aString UTF8String], R_OK))
	break;
    }

    if (i == j)
      aString = nil;

    if (aString)
      [self setConfigurationFile:aString];
    [mArray release];
  }
  
  if (!CLConfigFile && CLConfigDir)
    [self setConfigurationFile:[[CLString alloc] initWithFormat:@"%@/db.conf", CLConfigDir]];

  return CLConfigFile;
}

+(CLString *) configurationDirectory
{
  if (!CLConfigDir)
    [self configurationFile];
  return CLConfigDir;
}

+(CLString *) configOption:(CLString *) anOption
{
  FILE *file;
  CLRange aRange;
  CLString *aString;
  

  if (!CLConfig && (file = fopen([[self configurationFile] UTF8String], "r"))) {
    CLConfig = [[CLMutableDictionary alloc] init];
    CLAddToCleanup(CLConfig);
    while ((aString = CLGets(file, CLUTF8StringEncoding))) {
      aRange = [aString rangeOfString:@":"];
      if (aRange.length)
	[CLConfig setObject:[[aString substringFromIndex:CLMaxRange(aRange)]
			      stringByTrimmingWhitespaceAndNewlines]
		  forKey:[aString substringToIndex:aRange.location]];
    }
    fclose(file);
  }
    
  return [CLConfig objectForKey:anOption];
}

+(CLString *) domain
{
  CLString *option;


  if (!(option = [self configOption:@"Corp-Domain"]))
    option = [CLServerURL urlHost];
  return option;
}

+(CLString *) sslDomain
{
  return [self configOption:@"SSL-Domain"];
}

+(CLString *) browserType
{
  CLString *aString;
  CLDictionary *aDict;
  int i, j, k, l;
  CLArray *allKeys;
  CLRegularExpression *aRegex;
  id strings;
  BOOL match = NO;
  static int _didcheck = 0;
  
  
  if (!_didcheck) {
    /* FIXME - read site specific one and when there are no matches
       fall back to /usr/local/lib one. */
    if (!(aString = [CLString stringWithContentsOfFile:@"/usr/local/lib/browsers.plist"
			      encoding:CLUTF8StringEncoding])) {
      aString = [[self configurationDirectory]
		  stringByAppendingPathComponent:@"browsers.plist"];
      aString = [CLString stringWithContentsOfFile:aString
			  encoding:CLUTF8StringEncoding];
    }
    
    if (aString) {
      aDict = [aString decodePropertyList];
      allKeys = [aDict allKeys];
      for (i = 0, j = [allKeys count]; i < j; i++) {
	strings = [aDict objectForKey:[allKeys objectAtIndex:i]];
	if ([strings isKindOfClass:[CLArray class]]) {
	  for (k = 0, l = [strings count]; k < l; k++) {
	    aRegex = [[CLRegularExpression alloc] initFromString:[strings objectAtIndex:k]
						  options:0];
	    match = [aRegex matchesString:CLUserAgent];
	    [aRegex release];
	    if (match)
	      break;
	  }
	}
	else {
	  aRegex = [[CLRegularExpression alloc] initFromString:strings options:0];
	  match = [aRegex matchesString:CLUserAgent];
	  [aRegex release];
	}

	if (match)
	  break;
      }

      if (i < j) {
	CLBrowserType = [[allKeys objectAtIndex:i] retain];
	CLAddToCleanup(CLBrowserType);
      }
    }

    _didcheck = 1;
  }

  return CLBrowserType;
}
  
+(CLString *) randomPassword
{
  FILE *file;
  CLString *aString;
  CLMutableString *mString;


  /* Used to look for 4 letter words but it keeps giving me
     inappropriate things. Maybe I should make my own dictionary. */
  file = popen("egrep '^[a-z][a-z][a-z][a-z][a-z][a-z]$' "
	       WORDLIST " | " RANDOMIZE " | head -2", "r");
  mString = [[CLMutableString alloc] init];
  while ((aString = CLGets(file, CLUTF8StringEncoding))) {
    if ([mString length])
      [mString appendString:@"-"];
    [mString appendString:
	       [[aString stringByTrimmingCharactersInSet:
			  [CLCharacterSet whitespaceAndNewlineCharacterSet]]
		 lowercaseString]];
  }
  pclose(file);
  
  return [mString autorelease];
}

+(CLString *) randomSalt
{
  char buf[20];
  int i;
  CLString *aString;


  strcpy(buf, "$1$xxxxxxxx$");
  for (i = 0; i < 8; i++)
    buf[i+3] = cryptset[random() % strlen(cryptset)];
  aString = [CLString stringWithUTF8String:buf];
  
  return aString;
}

+(CLString *) returnFor:(id) anObject action:(SEL) anAction
	     localQuery:(CLDictionary *) aQuery
{
  CLStream *stream;
  CLTypedStream *tstream;
  CLData *aData;
  CLString *aString;

  
  stream = CLOpenMemory(NULL, 0, CL_WRITEONLY);
  tstream = CLOpenTypedStream(stream, CL_WRITEONLY);
  CLWriteTypes(tstream, "@:@", &anObject, &anAction, &aQuery);
  CLCloseTypedStream(tstream);
  aData = CLGetData(stream);
  aString = [aData encodeBase64];
  CLCloseMemory(stream, CL_FREEBUFFER);
  
  return aString;
}

-(void) becomeManager
{
  _manager = self;
  activeSession = nil;
  sessionExpire = 24 * 3600; /* seconds */
  acls = nil;
}

-(id) init
{
  [super init];
  
  if (!_manager)
    [self becomeManager];

  if (_manager != self) {
    [self release];
    [_manager retain];
  }

  return _manager;
}
    
-(void) dealloc
{
  [activeSession release];
  [acls release];
  if (_manager == self)
    _manager = nil;
  [super dealloc];
  return;
}

-(void) read:(CLTypedStream *) stream
{
  if (!_manager)
    [self becomeManager];
  [super read:stream];
  return;
}
  
-(void) setupSession:(int) anID
{
  CLDatabase *db;
  CLArray *attr, *rows;
  CLString *aString;
  CLMutableDictionary *mDict;
  CLMutableArray *mArray;
  CLCookie *aCookie;
  CLUInteger32 h, h2;
  const char *p, *q;
  int err;
  CLArray *cookies;
  int i, j;
  id anObject;
  CLString *fullTable, *localTable;
  CLRange aRange;
  BOOL newSession = NO;


  if (_manager != self) {
    [_manager setupSession:anID];
    return;
  }

  if (anID && anID == [activeSession objectID])
    return;

  fullTable = [CLGenericRecord tableForClassName:@"CLSession"];
  aRange = [fullTable rangeOfString:@"."];
  db = [CLGenericRecord databaseNamed:[fullTable substringToIndex:aRange.location]];
  localTable = [fullTable substringFromIndex:CLMaxRange(aRange)];

  h = 0;
  if ((p = getenv("REMOTE_ADDR")) && (q = strchr(p, '.')))
    h = CLHashBytes(p, q-p, h);
  if ((p = getenv("HTTP_USER_AGENT")))
    h = CLHashBytes(p, strlen(p), h);

  cookies = CLCookiesWithKey(COOKIE_SESSION, NO);

  if ((anObject = [CLQuery objectForKey:QUERY_SESSIONID])) {
    aCookie = [[CLCookie alloc] init];
    [aCookie setKey:COOKIE_SESSION];
    [aCookie setValue:[CLNumber numberWithInt:[anObject intValue]]];
    if (cookies)
      cookies = [cookies arrayByAddingObject:aCookie];
    else
      cookies = [CLArray arrayWithObjects:aCookie, nil];
    [aCookie release];
  }
  
  j = [cookies count];
  i = 0;

  err = 0;
  attr = CLAttributes(@"id:i", @"hash:#", nil);
  /* FIXME - prefer the ID from a cookie over the one passed as the argument */
  do {
    if (anID) {
      aString = [CLString stringWithFormat:
			    @"select id, hash from %@ where id = %i", localTable, anID];
      rows = [db read:attr qualifier:aString errors:NULL];

      if ([rows count]) {
	h2 = [[[rows objectAtIndex:0] objectForKey:@"hash"] unsignedLongValue];
	if (h == h2) {
	  err = 0;
	  break;
	}
	
	err = 1;
	anID = 0;
      }
      else
	err = 1;      
    }

    if (i < j && [[cookies objectAtIndex:i] value]) {
      anID = [[[cookies objectAtIndex:i] value] intValue];
      while (!anID && (i + 1) < j) {
	i++;
	anID = [[[cookies objectAtIndex:i] value] intValue];
      }
    }
    i++;
  } while (anID && i <= j);
    
  if (err || !anID) {
    mDict = [[CLMutableDictionary alloc] init];
    [mDict setObject:[CLCalendarDate calendarDate] forKey:@"last_seen"];
    [mDict setObject:[CLNumber numberWithUnsignedLong:h] forKey:@"hash"];
    mArray = [[CLMutableArray alloc] initWithObjects:
				       @"last_seen:@", @"account_id:i", @"hash:#", nil];

    {
      CLDictionary *recordDef;
      CLString *aString;
      const char *p;


      recordDef = [CLGenericRecord recordDefForTable:
				     [CLGenericRecord tableForClass:[CLSession class]]];
      if ([[recordDef objectForKey:@"fields"]
	    objectForKey:[URL_START lowerCamelCaseString]] &&
	  (p = getenv("PATH_INFO")) && *p) {
	aString = [CLString stringWithUTF8String:p];
	if ((p = getenv("QUERY_STRING")) && *p)
	  aString = [aString stringByAppendingFormat:@"?%s", p];
	[mDict setObject:aString forKey:URL_START];
	[mArray addObject:URL_START @":*"];
      }
  
      if ([[recordDef objectForKey:@"fields"]
	    objectForKey:[URL_REFERRER lowerCamelCaseString]] &&
	  (p = getenv("HTTP_REFERER")) && *p) {
	[mDict setObject:[CLString stringWithUTF8String:p] forKey:URL_REFERRER];
	[mArray addObject:URL_REFERRER @":*"];
      }
    }

    attr = CLAttributesFromArray(mArray);
    [mArray release];
    if (anID)
      [db insertDictionary:mDict withAttributes:attr into:localTable withID:anID
	  errors:NULL];
    else
      anID = [db insertDictionary:mDict withAttributes:attr into:localTable errors:NULL];
    [mDict release];
    newSession = YES;
  }

  [self setActiveSession:[[[CLSession alloc] initFromObjectID:anID] autorelease]];
  if (newSession && [CLDelegate respondsTo:@selector(didCreateSession:)])
    [CLDelegate didCreateSession:[self activeSession]];

  aCookie = [[CLCookie alloc] init];
  [aCookie setKey:COOKIE_SESSION];
  [aCookie setValue:[CLNumber numberWithInt:anID]];
  [aCookie setExpires:
	     [CLCalendarDate dateWithTimeIntervalSince1970:time(NULL) + 30 * 24 * 60 * 60]];
#if 0
  if ((aString = [[self class] domain])) {
    if ([aString hasPrefix:@"www."])
      [aCookie setDomain:aString];
    else
      [aCookie setDomain:[CLString stringWithFormat:@".%@", aString]];
  }
  else
#endif
    if (getenv("SERVER_NAME"))
      [aCookie setDomain:[CLString stringWithUTF8String:getenv("SERVER_NAME")]];
  [aCookie setPath:@"/"];
  CLReplaceCookie(aCookie);
  [aCookie release];

  /* Make it update the last seen time */
  if ([CLGenericRecord model])
    [[self activeSession] saveToDatabase];
  
  return;
}

-(int) validateUser:(id) sender
{
  CLDatabase *db;
  CLArray *attr, *rows;
  int i, j;
  int uid = 0;
  CLString *aUser = nil, *aPass = nil, *cryptPass = nil;
  CLString *aString;
  CLDictionary *aDict;
  CLRange aRange;
  CLString *fullTable, *localTable;


  if ([sender isKindOfClass:[CLForm class]]) {
    aUser = [sender valueOfFieldNamed:FIELD_ACCOUNT];
    aPass = [sender valueOfFieldNamed:FIELD_PASSWORD];
  }
  else if ([sender isKindOfClass:[CLDictionary class]]) {
    aUser = [sender objectForKey:FIELD_ACCOUNT];
    aPass = [sender objectForKey:FIELD_PASSWORD];
  }
  
  if (!aUser)
    return 0;

  fullTable = [CLGenericRecord tableForClassName:@"CLAccount"];
  aRange = [fullTable rangeOfString:@"."];
  db = [CLGenericRecord databaseNamed:[fullTable substringToIndex:aRange.location]];
  localTable = [fullTable substringFromIndex:CLMaxRange(aRange)];
  
  attr = CLAttributes(@"id:i", @"password:*", @"flags:*", nil);
  aString = [CLString stringWithFormat:
			@"select id, password, flags from %@"
		      " where name = '%@' or email = '%@'",
		      localTable,
		      [CLDatabase defangString:aUser escape:NULL],
		      [CLDatabase defangString:aUser escape:NULL]];
  rows = [db read:attr qualifier:aString errors:NULL];

  for (i = 0, j = [rows count]; i < j; i++) {
    aDict = [rows objectAtIndex:i];
    
    /* Check if account is locked */
    aRange.length = 0;
    if ((aString = [aDict objectForKey:@"flags"]) && ![aString isKindOfClass:[CLNull class]])
      aRange = [aString rangeOfString:@"L" options:CLCaseInsensitiveSearch
			range:CLMakeRange(0, [aString length])];
    if (!aRange.length) {
      aString = [aDict objectForKey:@"password"];
      if ([aString isKindOfClass:[CLNull class]])
	aString = nil;

      if (aString && aPass)
	cryptPass = [CLString stringWithUTF8String:
				crypt([[aPass lowercaseString] UTF8String],
				      [aString UTF8String])];
      
      if ((!aString && !aPass) ||
	  (aString && aPass && [aString isEqualToString:cryptPass])) {
	uid = [[aDict objectForKey:@"id"] intValue];
	if ([CLDelegate respondsTo:@selector(willValidateAccountID:sender:)]
	    && ![CLDelegate willValidateAccountID:uid sender:sender])
	  uid = 0;
	break;
      }
    }
  }

  return uid;
}

-(BOOL) return:(id) sender
{
  CLStream *stream;
  CLTypedStream *tstream;
  id anObject;
  SEL anAction;
  CLDictionary *aQuery;
  CLData *aData;
  CLString *retString = nil, *aString;


  if ([[[[self class] manager] activeSession] hasFieldNamed:@"returnTo"]) {
    anObject = [[[[self class] manager] activeSession] objectValueForBinding:@"returnTo"];
    retString = [[[anObject objectValueForBinding:@"returnTo"] retain] autorelease];
    [anObject deleteFromDatabase];
  }
  
  if ([sender isKindOfClass:[CLForm class]] &&
      (aString = [sender valueOfFieldNamed:FIELD_RETURN]))
    retString = aString;
  
  if (!retString) {
    if (![sender respondsTo:@selector(doVaction)] || ![sender doVaction])
      return NO;
  }
  else {
    aData = [retString decodeBase64];
    stream = CLOpenMemory([aData bytes], [aData length], CL_READONLY);
    tstream = CLOpenTypedStream(stream, CL_READONLY);
    CLReadTypes(tstream, "@:@", &anObject, &anAction, &aQuery);
    CLCloseTypedStream(tstream);
    CLCloseMemory(stream, CL_FREEBUFFER);
    [CLQuery addEntriesFromDictionary:aQuery];
    [aQuery release];
    [anObject perform:anAction with:sender];
  }
  
  return YES;
}

-(void) preparePage:(CLPage *) aPage
{
  return;
}

-(void) login:(id) sender message:(CLString *) aMessage
{
  int user_id = 0;


  if ([sender isKindOfClass:[CLForm class]]) {
    if ((loginReturn = [sender valueOfFieldNamed:FIELD_RETURN])) {
      [[[[sender page] objectWithID:@"cl_lostControl"] localQuery]
	setObject:loginReturn forKey:QUERY_RETURN];
      [[[[sender page] objectWithID:@"cl_signupControl"] localQuery]
	setObject:loginReturn forKey:QUERY_RETURN];
    }
  
    if ([sender valueOfFieldNamed:FIELD_SKIP]) {
      [self return:sender];
      return;
    }
    else {
      if ([sender target] == self)
	user_id = [self validateUser:sender];
    
      if (user_id > 0) {
	[[self activeSession] setAccount:[[[CLAccount alloc] initFromObjectID:user_id]
					   autorelease]];
	[[self activeSession] saveToDatabase];
	[self return:sender];
	return;
      }
      else {
	[self replacePage:sender filename:PAGE_LOGIN];
	if ((loginReturn = [sender valueOfFieldNamed:FIELD_RETURN])) {
	  [[[[sender page] objectWithID:@"cl_lostControl"] localQuery]
	    setObject:loginReturn forKey:QUERY_RETURN];
	  [[[[sender page] objectWithID:@"cl_signupControl"] localQuery]
	    setObject:loginReturn forKey:QUERY_RETURN];
	}
	
	[[sender pageForm] copyValuesFrom:sender];
	[[sender page] setStatus:401];
  
	if (user_id < 0) { /* Expired */
	  CLControl *c1, *c2;
	  CLStream *stream;
	  CLData *aData;


	  c1 = [[CLControl alloc] init];
	  c2 = [[CLControl alloc] init];
	  [c2 setTarget:self];
	  [c2 setAction:@selector(sendActivation:)];
	  [c2 addObject:@"Click here to resend the activation link."];
	  [[c2 localQuery] setObject:[CLNumber numberWithInt:-user_id] forKey:QUERY_USER];
	  [[c2 localQuery] setObject:[sender valueOfFieldNamed:FIELD_RETURN]
			   forKey:QUERY_RETURN];
	  
	  [c1 addObject:@"Your account has not been activated."
	      " Please click the activation link that was emailed to you. "];
	  [c1 addObject:c2];

	  stream = CLOpenMemory(NULL, 0, CL_WRITEONLY);
	  [c1 writeHTML:stream];
	  aData = CLGetData(stream);
	  CLCloseMemory(stream, CL_FREEBUFFER);
	  [[sender page] appendErrorString:[CLString stringWithData:aData
						     encoding:CLUTF8StringEncoding]];
	  [c1 release];
	  [c2 release];
	}
	else if ([sender target] == self)
	  [[sender page] appendErrorString:@"Invalid Username or Password\n"];

	[[sender pageForm] setValue:@"" forFieldNamed:FIELD_PASSWORD];
      }
    }
  }
  else {
    CLString *aString;


    [self replacePage:sender filename:PAGE_LOGIN];
    if ((aString = [CLQuery objectForKey:QUERY_ACCOUNT])) {
      [[[sender page] objectWithID:@"theForm"] setValue:aString forFieldNamed:FIELD_ACCOUNT];
      [CLQuery removeObjectForKey:QUERY_ACCOUNT];
    }
  }

  if (aMessage)
    [[sender page] appendInfoString:aMessage];
  
  return;
}

-(void) login:(id) sender
{
  [self login:sender message:nil];
}

-(void) runLoginFor:(id) anObject action:(SEL) anAction
	     sender:(id) sender localQuery:(CLDictionary *) aQuery
{
  [self runLoginFor:anObject action:anAction sender:sender localQuery:aQuery message:nil];
  return;
}

-(void) runLoginFor:(id) anObject action:(SEL) anAction
	     sender:(id) sender localQuery:(CLDictionary *) aQuery
	    message:(CLString *) aMessage
{
  [self runLoginFor:anObject action:anAction sender:sender localQuery:aQuery
	message:aMessage ignore:NO];
}

-(void) runLoginFor:(id) anObject action:(SEL) anAction
	     sender:(id) sender localQuery:(CLDictionary *) aQuery
	    message:(CLString *) aMessage ignore:(BOOL) ignore
{
  CLPage *aPage;
  

  loginReturn = [[self class] returnFor:anObject action:anAction localQuery:aQuery];

  if (!ignore && [[[[self class] manager] activeSession] hasFieldNamed:@"returnTo"]) {
    id anObject = [[[CLManager manager] activeSession] objectValueForBinding:@"returnTo"];


    if (!anObject)
      anObject = [[[CLManager manager] activeSession]
		   addNewObjectToBothSidesOfRelationship:@"returnTo"];

    [anObject setObjectValue:loginReturn forBinding:@"returnTo"];
    [anObject saveToDatabase];
  }
  
  if ([sender isKindOfClass:[CLForm class]]) {
    [(CLForm *) sender addObject:[[[CLField alloc]
			initWithTitle:FIELD_RETURN cols:0 rows:0 value:loginReturn
				   type:CLTextFieldType onPage:nil] autorelease]];
    [self login:sender message:aMessage];
  }
  else {
    aPage = [[CLPage alloc] initFromFile:PAGE_LOGIN owner:self];
    [[aPage objectWithID:@"cl_showLogin"] setVisible:NO];
    [self preparePage:aPage];

    [[[aPage objectWithID:@"cl_lostControl"] localQuery]
      setObject:loginReturn forKey:QUERY_RETURN];
    [[[aPage objectWithID:@"cl_signupControl"] localQuery]
      setObject:loginReturn forKey:QUERY_RETURN];

    if (aMessage)
      [aPage appendInfoString:aMessage];
    
    [sender setPage:aPage];
    [aPage autorelease];
  }
  
  return;
}

-(void) logout:(id) sender
{
  if ([CLDelegate respondsTo:@selector(willLogout:)])
    [CLDelegate willLogout:[[self activeSession] account]];

  [[self activeSession] setAccount:nil];
  [[self activeSession] saveToDatabase];
  if ([CLDelegate respondsTo:@selector(didLogout:)])
    [CLDelegate didLogout:sender];

  //  CLRedirectBrowserToPage([[sender page] filename], YES);
  return;
}

-(void) sendPassword:(id) sender
{
  CLString *aString, *email, *pass;
  CLMutableDictionary *mDict;
  CLAccount *anAccount;
  CLArray *anArray;
  int i, j;
  CLEmailMessage *aMessage;


  [self replacePage:sender filename:PAGE_FORGOT];
  [self preparePage:[sender page]];
  
  if ([sender isKindOfClass:[CLForm class]]) {
    if (!(email = [sender valueOfFieldNamed:FIELD_EMAIL]))
      [[sender fieldNamed:FIELD_EMAIL] setErrorString:@"Invalid email address"];
    else {
      anArray = [CLGenericRecord loadTable:[CLGenericRecord tableForClass:[CLAccount class]]
				 qualifier:
				   [CLString stringWithFormat:@"email = '%@'",
					     [CLDatabase defangString:email escape:NULL]]];
      if (![anArray count])
	[[sender fieldNamed:FIELD_EMAIL] setErrorString:@"Invalid email address"];
      else {
	for (i = 0, j = [anArray count]; i < j; i++) {
	  anAccount = [anArray objectAtIndex:i];
	  if (![anAccount isLocked]) {
	    pass = [[self class] randomPassword];

	    [anAccount setPassword:[CLString stringWithUTF8String:
					       crypt([[pass lowercaseString] UTF8String],
						     [[[self class] randomSalt]
						       UTF8String])]];
	    [anAccount saveToDatabase];

	    mDict = [[CLMutableDictionary alloc] init];
	    [mDict setObject:[anAccount email] forKey:@"cl_email"];
	    [mDict setObject:[anAccount objectValueForBinding:@"name"] forKey:@"cl_name"];
	    [mDict setObject:pass forKey:@"cl_plain"];
	    aMessage = [[CLEmailMessage alloc] initFromFile:MSG_FORGOT owner:mDict];
	    [aMessage send];
	    [aMessage release];
	    [mDict release];
	  }
	}

	if (![self return:sender]) {
	  CLPage *aPage;


	  aPage = [[CLPage alloc] initFromFile:PAGE_LOGIN owner:self];
	  [aPage appendInfoString:[CLString stringWithFormat:
					      @"A new password has been emailed to %@",
					    email]];
	  [aPage display];
	  [aPage release];
	  [sender setPage:nil];
	}
      }
    }
  }

  if ((aString = [CLQuery objectForKey:QUERY_RETURN])) {
    loginReturn = [aString retain];
    [CLQuery removeObjectForKey:QUERY_RETURN];
  }
  else if ([sender isKindOfClass:[CLForm class]] &&
	   (aString = [sender valueOfFieldNamed:FIELD_RETURN]))
    loginReturn = [aString retain];

  return;
}

-(CLSession *) activeSession
{
  if (_manager == self) {
    if (!activeSession)
      [self setupSession:0];
    return activeSession;
  }
  else
    return [_manager activeSession];
}

-(CLAccount *) activeAccount
{
  return [[self activeSession] account];
}

-(void) setActiveSession:(CLSession *) aSession
{
  if (_manager == self) {
    [activeSession autorelease];
    activeSession = [aSession retain];
  }
  else
    [_manager setActiveSession:aSession];

  return;
}

-(void) emailUser:(CLString *) aUser password:(CLString *) aPass to:(CLString *) anEmail
     instructions:(CLString *) instr bcc:(CLString *) bcc
{
  CLOpenFile *oFile;
  CLRange aRange, aRange2;
  CLMutableString *head = nil, *body = nil;
  FILE *msg;
  CLString *aString;


  oFile = CLTemporaryFile(@"manager.XXXXXX");

  if (instr) {
    aRange2 = CLMakeRange(0, [instr length]);
    aRange = [instr rangeOfString:@":" options:0 range:aRange2];
    aRange2 = [instr rangeOfString:@" " options:0 range:aRange2];
    if (aRange.length &&
	(!aRange2.length || aRange.location < aRange2.location)) {
      aRange = [instr rangeOfString:@"\n\n" options:0 range:CLMakeRange(0, [instr length])];
      head = [[instr substringToIndex:aRange.location+1] mutableCopy];
      body = [[instr substringFromIndex:CLMaxRange(aRange)] mutableCopy];

      [head replaceOccurrencesOfString:@"--FROM--" withString:
	      [CLString stringWithFormat:@"support@%@", [[self class] domain]]
	    options:0 range:CLMakeRange(0, [head length])];
      [head replaceOccurrencesOfString:@"--ERRORS--" withString:
	      [CLString stringWithFormat:@"support@%@", [[self class] domain]]
	    options:0 range:CLMakeRange(0, [head length])];
      [head replaceOccurrencesOfString:@"--SUBJET--" withString:
	      [CLString stringWithFormat:@"Your %@ password", [[self class] domain]]
	    options:0 range:CLMakeRange(0, [head length])];
      [head replaceOccurrencesOfString:@"--TO--" withString:anEmail
	    options:0 range:CLMakeRange(0, [head length])];
      if (bcc)
	[head replaceOccurrencesOfString:@"--BCC--" withString:bcc
	      options:0 range:CLMakeRange(0, [head length])];
    }
    else
      body = [instr mutableCopy];

    [head replaceOccurrencesOfString:@"--USER--" withString:aUser
	  options:0 range:CLMakeRange(0, [head length])];
    [head replaceOccurrencesOfString:@"--PASS--" withString:aPass
	  options:0 range:CLMakeRange(0, [head length])];
  }

  msg = [oFile file];
  if (head)
    fprintf(msg, "%s", [head UTF8String]);
  aRange2 = CLMakeRange(0, [head length]);
  aRange = [head rangeOfString:@"From:" options:0 range:aRange2];
  if (!head || !aRange.length || (aRange.location > 0 &&
				  [head characterAtIndex:aRange.location - 1] != '\n'))
    fprintf(msg, "From: support@%s\n", [[[self class] domain] UTF8String]);
  aRange = [head rangeOfString:@"Subject:" options:0 range:aRange2];
  if (!head || !aRange.length || (aRange.location > 0 &&
				  [head characterAtIndex:aRange.location - 1] != '\n'))
    fprintf(msg, "Subject: Your %s password\n", [[[self class] domain] UTF8String]);
  aRange = [head rangeOfString:@"To:" options:0 range:aRange2];
  if (!head || !aRange.length || (aRange.location > 0 &&
				  [head characterAtIndex:aRange.location - 1] != '\n'))
    fprintf(msg, "To: %s\n", [anEmail UTF8String]);
  aRange = [head rangeOfString:@"Bcc:" options:0 range:aRange2];
  if (bcc && (!head || !aRange.length ||
	      (aRange.location > 0 &&
	       [head characterAtIndex:aRange.location - 1] != '\n')))
    fprintf(msg, "Bcc: %s\n", [bcc UTF8String]);
  aRange = [head rangeOfString:@"Errors-To:" options:0 range:aRange2];
  if (!head || !aRange.length || (aRange.location > 0 &&
				  [head characterAtIndex:aRange.location - 1] != '\n'))
    fprintf(msg, "Errors-To: support@%s\n", [[[self class] domain] UTF8String]);
  fprintf(msg, "X-Remote-Addr: %s\n", getenv("REMOTE_ADDR"));
  fprintf(msg, "\n");

  if (body)
    fprintf(msg, "%s", [body UTF8String]);
  else {
    fprintf(msg, "Your username and password are:\n");
    fprintf(msg, "\n");
    fprintf(msg, "Username: %s\n", [aUser UTF8String]);
    fprintf(msg, "Password: %s\n", [aPass UTF8String]);
  }
  
  fclose(msg);
  aString = [CLString stringWithFormat:@"/usr/lib/sendmail -t < %@", [oFile path]];
  system([aString UTF8String]);
  unlink([[oFile path] UTF8String]);

  [head release];
  [body release];

  return;
}

-(CLString *) activationLink:(int) accountID
{
  int i;
  char abuf[25];
  unsigned int h;
  CLAccount *anAccount;
  CLString *aString;
  CLData *aData;

  
  anAccount = [[CLAccount alloc] initFromObjectID:accountID];
  for (i = 0; i < sizeof(abuf); i++)
    abuf[i] = random() % 128;
  h = htonl(accountID);
  memcpy(abuf, &h, sizeof(h));
  strncpy(abuf + sizeof(h), [[anAccount email] UTF8String], sizeof(abuf) - sizeof(h) - 1);
  aData = [[CLData alloc] initWithBytes:abuf length:strlen(abuf)];
  aString = [CLString stringWithFormat:@"%@%@/activate?emailid=%@",
		      CLServerURL, CLWebName, [aData encodeBase64]];
  [aData release];
  [anAccount release];

  return aString;
}

-(unsigned int) sessionExpire
{
  return sessionExpire;
}

-(void) setSessionExpiresAfter:(unsigned int) seconds
{
  sessionExpire = seconds;
  return;
}

-(BOOL) availableUser:(CLString *) aString
{
  CLDatabase *db;
  CLArray *rows;
  CLString *fullTable, *localTable;
  CLRange aRange;


  fullTable = [CLGenericRecord tableForClassName:@"CLAccount"];
  aRange = [fullTable rangeOfString:@"."];
  db = [CLGenericRecord databaseNamed:[fullTable substringToIndex:aRange.location]];
  localTable = [fullTable substringFromIndex:CLMaxRange(aRange)];

  rows = [db read:CLAttributes(@"id:i", nil) qualifier:
	       [CLString stringWithFormat:@"select id from %@ where name = '%@'",
			 localTable,
			 [CLDatabase defangString:aString escape:NULL]] errors:NULL];

  if ([rows count])
    return NO;

  return YES;
}

-(BOOL) unusedEmail:(CLString *) aString
{
  CLDatabase *db;
  CLArray *rows;
  CLString *fullTable, *localTable;
  CLRange aRange;


  fullTable = [CLGenericRecord tableForClassName:@"CLAccount"];
  aRange = [fullTable rangeOfString:@"."];
  db = [CLGenericRecord databaseNamed:[fullTable substringToIndex:aRange.location]];
  localTable = [fullTable substringFromIndex:CLMaxRange(aRange)];

  rows = [db read:CLAttributes(@"id:i", nil) qualifier:
	       [CLString stringWithFormat:@"select id from %@ where email = '%@'",
			 localTable,
			 [CLDatabase defangString:aString escape:NULL]] errors:NULL];

  if ([rows count])
    return NO;

  return YES;
}

-(CLAccount *) createAccount:(id) info requirements:(CLUInteger) mask
		      errors:(CLDictionary **) errors
{
  CLString *user, *pass, *vpass, *email, *vuser;
  int err = 0;
  CLAccount *anAccount = nil;
  CLRange aRange;
  CLMutableDictionary *mDict;


  if ([info isKindOfClass:[CLForm class]]) {
    user = [info valueOfFieldNamed:FIELD_ACCOUNT];
    pass = [info valueOfFieldNamed:FIELD_PASSWORD];
    vpass = [info valueOfFieldNamed:FIELD_VERPASS];
    email = [info valueOfFieldNamed:FIELD_EMAIL];
  }
  else { /* CLDictionary */
    user = [info objectForKey:FIELD_ACCOUNT];
    pass = [info objectForKey:FIELD_PASSWORD];
    vpass = [info objectForKey:FIELD_VERPASS];
    email = [info objectForKey:FIELD_EMAIL];
  }

  mDict = [CLMutableDictionary dictionary];
  
  if ((mask & CLPasswordRequired)) {
    if (!pass) {
      [mDict setObject:@"Please enter a password" forKey:FIELD_PASSWORD];
      err++;
    }
    if (!vpass) {
      [mDict setObject:@"Please verify password" forKey:FIELD_VERPASS];
      err++;
    }
    if (pass && vpass && ![pass isEqualToString:vpass]) {
      [mDict setObject:@"Password not identical to verify" forKey:FIELD_PASSWORD];
      [mDict setObject:[CLNull null] forKey:FIELD_VERPASS];
      err++;
    }
  }

  if ((mask & CLNameRequired) && !user) {
    [mDict setObject:@"Please enter a user name" forKey:FIELD_ACCOUNT];
    err++;
  }

  aRange = [user rangeOfString:@"@" options:0 range:CLMakeRange(0, [user length])];
  if (user && aRange.length) {
    [mDict setObject:@"You cannot use an email address as your user name"
	   forKey:FIELD_ACCOUNT];
    err++;
  }

  if ((mask & CLNameRequired)) {
    vuser = [CLAccount makeNameValid:user];
    if (![vuser isEqualToString:user]) { /* Pick out invalid characters */
      unichar *buf1, *buf2, *buf3;
      int i, j, len;


      i = [vuser length];
      buf1 = calloc(i+1, sizeof(unichar));
      [vuser getCharacters:buf1];
      j = [user length];
      buf2 = calloc(j+1, sizeof(unichar));
      buf3 = calloc(j+1, sizeof(unichar));
      [user getCharacters:buf2];
      for (i = len = 0; i < j; i++)
	if (!wcschr(buf1, buf2[i]) && !wcschr(buf3, buf2[i]))
	  buf3[len++] = buf2[i];
      [mDict setObject:[CLString stringWithFormat:
				   @"You cannot use these characters in your user name: %@",
				 [CLString stringWithCharacters:buf3 length:len]]
		forKey:FIELD_ACCOUNT];
      free(buf1);
      free(buf2);
      free(buf3);
      err++;
    }
  }

  if (!(mask & CLNameNotUnique) && user && ![self availableUser:user]) {
    [mDict setObject:[CLString stringWithFormat:@"Username <kbd>%@</kbd> is already taken",
			       user] forKey:FIELD_ACCOUNT];
    err++;
  }

  if ((mask & CLEmailRequired) && !email) {
    [mDict setObject:@"Please enter an email address" forKey:FIELD_EMAIL];
    err++;
  }

  if (email && !CLValidEmailAddress(email)) {
    [mDict setObject:@"Please enter a valid email address" forKey:FIELD_EMAIL];
    err++;
  }

  if (!(mask & CLEmailNotUnique) && email && ![self unusedEmail:email]) {
    [mDict setObject:@"That email address already has an account."
	   " Please use the Lost password function to retrieve your password."
	   forKey:FIELD_EMAIL];
    err++;
  }

  if (!err) {
    anAccount = [[[CLAccount alloc] init] autorelease];
    [anAccount setName:user];
    [anAccount setEmail:email];
    if (pass)
      [anAccount setPassword:[CLString stringWithUTF8String:
					 crypt([[pass lowercaseString] UTF8String],
					       [[[self class] randomSalt] UTF8String])]];
    [anAccount setCreated:[CLCalendarDate calendarDate]];
    [anAccount saveToDatabase];
  }
  else if ([info isKindOfClass:[CLForm class]]) {
    CLArray *anArray;
    int i, j;
    CLString *aField, *aString;


    anArray = [mDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aField = [anArray objectAtIndex:i];
      aString = [mDict objectForKey:aField];
      if ([aString isKindOfClass:[CLNull class]])
	aString = nil;
      [[info fieldNamed:aField] setErrorString:aString];
    }
  }

  if (errors) {
    *errors = nil;
    if (err)
      *errors = mDict;
  }
  
  return anAccount;
}

-(BOOL) checkPermission:(id) anObject
{
  int i, j;
  CLString *aString;
  FILE *file;
  CLAccessControl *anAcl;
  BOOL allow, foundMatch;

  
  if (_manager != self)
    return [_manager checkPermission:anObject];
  
  if (!acls) {
    acls = [[CLMutableArray alloc] init];
    aString = [[CLManager configurationDirectory]
		stringByAppendingPathComponent:
		  [CLManager configOption:@"ACL"]];
    if ((file = fopen([aString UTF8String], "r"))) {
      while ((aString = CLGets(file, CLUTF8StringEncoding))) {
	aString = [aString stringByTrimmingWhitespaceAndNewlines];
	if ([aString length] && [aString characterAtIndex:0] != '#') {
	  anAcl = [[CLAccessControl alloc] initFromString:aString];
	  [acls addObject:anAcl];
	  [anAcl release];
	}
      }
      fclose(file);
    }
  }

  if (![acls count])
    return YES;
  
  for (i = 0, j = [acls count]; i < j; i++)
    if ([[acls objectAtIndex:i] matchesObject:anObject]) {
      foundMatch = YES;
      if ((allow = [[acls objectAtIndex:i] checkPermission:anObject]))
	return YES;
    }


  if (foundMatch && !allow) {
    if ([anObject isKindOfClass:[CLControl class]]) {
      id target = [anObject target];
      CLString *action = [CLString stringWithUTF8String:
				     sel_getName([anObject action])];


      fprintf(stderr, "Access denied for object %s,%s\n",
	      [[target className] UTF8String], [action UTF8String]);
    }
    else if ([anObject isKindOfClass:[CLPage class]]) {
      fprintf(stderr, "Access denied for page %s\n", [[anObject filename] UTF8String]);
    }
  }
  
  return !foundMatch &&
    ![@"allow" caseInsensitiveCompare:[CLManager configOption:@"ACL-Default"]];
}

-(CLString *) loginReturn
{
  return loginReturn;
}

-(CLString *) currentURL
{
  CLString *current, *query;
  CLRange aRange;


  current = [CLEnvironment objectForKey:@"SCRIPT_URI"];
  query = [CLEnvironment objectForKey:@"REQUEST_URI"];
  aRange = [query rangeOfString:@"?"];
  if (aRange.length)
    current = [current stringByAppendingString:[query substringFromIndex:aRange.location]];
  
  return current;
}

@end

/* FIXME - move the below variables and CLRun to somewhere more appropriate */
CLString *CLAppName;
CLString *CLWebName;
CLString *CLAppPath;
CLString *CLWebPath;
CLString *CLServerURL;
CLString *CLUserAgent = nil;
CLString *CLBrowserType = nil;
CLMutableDictionary *CLQuery = nil, *CLEnvironment = nil;
CLEditingContext *CLDefaultContext = nil;
id CLDelegate = nil;
id CLMainObject = nil;
CLPage *CLMainPage = nil;

void CLInit()
{
  const char *p, *q;
  char *r, *s, *t, *w;
  int i, j;
  CLString *aString;
  CLArray *anArray;
  CLMutableArray *mArray;
  CLAutoreleasePool *pool;
  CLRange aRange;
  id anObject;
  static int didInit = 0;
  char **env;
  CLString *PATH_INFO = nil, *QUERY_STRING = nil;
  CLString *DOCUMENT_ROOT = nil, *SCRIPT_NAME = nil, *SCRIPT_FILENAME = nil;
  

  if (didInit)
    return;

  pool = [[CLAutoreleasePool alloc] init];

  CLDefaultContext = [[CLEditingContext alloc] init];
  CLAddToCleanup(CLDefaultContext);
  
  CLEnvironment = [[CLMutableDictionary alloc] init];
  CLAddToCleanup(CLEnvironment);

  env = environ;
  while (env && *env) {
    aString = [CLString stringWithUTF8String:*env];
    aRange = [aString rangeOfString:@"="];
    [CLEnvironment setObject:[aString substringFromIndex:CLMaxRange(aRange)]
		   forKey:[aString substringToIndex:aRange.location]];
    env++;
  }
  
  /* FIXME - use CLEnvironment */ 
  if ((p = getenv("PATH_INFO")))
    PATH_INFO = [CLString stringWithUTF8String:p];
  if ((p = getenv("QUERY_STRING")))
    QUERY_STRING = [CLString stringWithUTF8String:p];
  if ((p = getenv("DOCUMENT_ROOT")))
    DOCUMENT_ROOT = [CLString stringWithUTF8String:p];
  if ((p = getenv("SCRIPT_NAME")))
    SCRIPT_NAME = [CLString stringWithUTF8String:p];
  if ((p = getenv("SCRIPT_FILENAME")))
    SCRIPT_FILENAME = [CLString stringWithUTF8String:p];

  CLQuery = [[CLMutableDictionary alloc] init];
  CLAddToCleanup(CLQuery);

  CLWebName = nil;
  if (SCRIPT_FILENAME) {
    CLAppName = [SCRIPT_FILENAME lastPathComponent];
    mArray = [[SCRIPT_FILENAME pathComponents] mutableCopy];
    anArray = [DOCUMENT_ROOT pathComponents];
    j = [mArray count];
    if (j > [anArray count])
      j = [anArray count];
    for (i = 0; i < j; i++)
      if (![[mArray objectAtIndex:i] isEqualToString:[anArray objectAtIndex:i]])
	break;
    if (i < [mArray count]) {
      [mArray removeObjectsInRange:CLMakeRange(i, [mArray count] - i)];
      aString = [CLString pathWithComponents:mArray];
      CLWebName = [SCRIPT_FILENAME substringFromIndex:[aString length]];
    }
  }

  if ((!CLWebName || [CLWebName hasSuffix:SCRIPT_NAME]) && [SCRIPT_NAME length]) {
    if ([SCRIPT_NAME hasSuffix:PATH_INFO])
      CLWebName = [SCRIPT_NAME substringToIndex:[SCRIPT_NAME length] - [PATH_INFO length]];
    else
      CLWebName = SCRIPT_NAME;
    CLAppName = [CLWebName lastPathComponent];
  }

  if ([CLAppName hasSuffix:@".cgi"])
    CLAppName = [CLAppName stringByDeletingPathExtension];

  CLWebPath = [@"/" stringByAppendingString:CLAppName];

  /* Store DOCUMENT_ROOT/"program name" in CLAppPath */
  if (DOCUMENT_ROOT) {
    CLAppPath = [DOCUMENT_ROOT stringByAppendingPathComponent:CLAppName];
    if (access([CLAppPath UTF8String], X_OK)) {
      CLAppPath = [[[SCRIPT_FILENAME stringByDeletingLastPathComponent]
		     stringByDeletingLastPathComponent]
		    stringByAppendingPathComponent:CLAppName];
    }
  }
  else
    CLAppPath = @"";

  [CLAppName retain];
  [CLWebName retain];
  [CLAppPath retain];
  [CLWebPath retain];
  if (CLAppName)
    CLAddToCleanup(CLAppName);
  if (CLWebName)
    CLAddToCleanup(CLWebName);
  if (CLAppPath)
    CLAddToCleanup(CLAppPath);
  if (CLWebPath)
    CLAddToCleanup(CLWebPath);

  CLInitializeQuery(QUERY_STRING);

  if ((p = getenv("HTTP_COOKIE"))) {
    CLString *key, *val;

    
    w = strdup(p);

    for (r = w; r && *r; ) {
      if ((s = strchr(r, '=')))
	*s++ = 0;
      if (!s)
	break;
      if ((t = strchr(s, ';')))
	*t++ = 0;

      anObject = [[CLCookie alloc] init];
      key = [[CLString stringWithUTF8String:r] stringByReplacingPercentEscapes];
      val = [[CLString stringWithUTF8String:s] stringByReplacingPercentEscapes];
      [anObject setKey:key];
      [anObject setValue:val];
      [anObject setFromBrowser:YES];
      CLAddCookie(anObject);
      [anObject release];

      r = t;
      while (r && *r && isspace(*r))
	r++;
    }
    
    free(w);

    if (CLCookieWithKey(COOKIE_SESSION, YES))
      CLCookiesEnabled = YES;
  }

  if ((p = getenv("SERVER_URL")))
    CLServerURL = [[CLString alloc] initWithUTF8String:p];
  else {
    if (!(p = getenv("HTTP_HOST")))
      p = getenv("SERVER_NAME");
    if ((q = getenv("HTTPS")) && !strcmp(q, "on"))
      CLServerURL = [[CLString alloc] initWithFormat:@"https://%s", p];
    else
      CLServerURL = [[CLString alloc] initWithFormat:@"http://%s", p];
  }
  if ([CLServerURL hasSuffix:@"/"]) {
    [CLServerURL autorelease];
    CLServerURL = [[CLServerURL substringToIndex:[CLServerURL length] - 1] retain];
  }
  aRange = [CLServerURL rangeOfString:@":" options:0
			range:CLMakeRange(0, [CLServerURL length])];
  if (!aRange.length) {
    i = 80;
    if ([CLServerURL hasPrefix:@"https:"])
      i = 443;
    if ((p = getenv("SERVER_PORT")))
      j = atoi(p);
    else
      j = i;
    if (j != i) {
      [CLServerURL autorelease];
      CLServerURL = [CLServerURL stringByAppendingFormat:@":%d", j];
    }
  }
  CLAddToCleanup(CLServerURL);

  if ((p = getenv("HTTP_USER_AGENT"))) {
    CLUserAgent = [[CLString alloc] initWithUTF8String:p];
    CLAddToCleanup(CLUserAgent);
  }
  
  [pool release];
  
  didInit = 1;
  return;
}

void CLRun(CLString *mainObjectName)
{
  int isValidURL = YES;
  CLString *aString;
  const char *PATH_INFO, *PATH_TRANSLATED, *QUERY_STRING, *SCRIPT_NAME;
  SEL mainAction;


  CLInit();

  PATH_INFO = getenv("PATH_INFO");
  PATH_TRANSLATED = getenv("PATH_TRANSLATED");
  QUERY_STRING = getenv("QUERY_STRING");
  SCRIPT_NAME = getenv("SCRIPT_NAME");
  
  if (!PATH_INFO || !PATH_TRANSLATED || !*(PATH_INFO)) {
    printf("Status: 302 Moved Temporarily\r\n");
    if (QUERY_STRING && *QUERY_STRING) 
      printf("Location: %s/?%s\r\n", SCRIPT_NAME, QUERY_STRING);
    else
      printf("Location: %s/\r\n", SCRIPT_NAME);
    printf("Content-Type: text/html; charset=UTF-8\r\n");
    printf("\r\n");
    printf("This is somewhere else.\n");
    exit(0);
  }

#if 0
  if (validURLs) {
    if ((p = getenv("HTTP_REFERER"))) {
      isValidURL = NO;
      for (i = 0; validURLs[i]; i++) {
	re_comp(validURLs[i]);
	if (re_exec(p)) {
	  isValidURL = YES;
	  break;
	}
      }
    }
  }

  if (!isValidURL && redirectTo) {
    printf("Status: 302 Moved Temporarily\r\n");
    printf("Location: %s\r\n", redirectTo);
    printf("Content-Type: text/html; charset=UTF-8\r\n");
    printf("\r\n");
    printf("This is somewhere else.\r\n");
    exit(0);
  }
#endif

  if (CLDelegate && PATH_INFO && *PATH_INFO &&
      [CLDelegate respondsTo:@selector(delegateDecodeSimpleURL:)] &&
      [CLDelegate delegateDecodeSimpleURL:[CLString stringWithUTF8String:PATH_INFO+1]])
    goto done;
  
  if (PATH_INFO && *PATH_INFO && *(PATH_INFO+1)) {
    CLArray *anArray;


    aString = [CLString stringWithUTF8String:PATH_INFO+1];
    anArray = [aString pathComponents];
    [CLQuery setObject:[anArray objectAtIndex:0] forKey:CL_URLSEL];
    if ([anArray count] > 1)
      [CLQuery setObject:[anArray objectAtIndex:1] forKey:CL_URLCLASS];
    if ([anArray count] > 2)
      [CLQuery setObject:[anArray objectAtIndex:2] forKey:CL_URLDATA];
  }

  CLMainObject = nil;
  
  if (isValidURL && (aString = [CLQuery objectForKey:CL_URLCLASS]) &&
      (CLMainObject = [[objc_lookUpClass([aString UTF8String]) alloc] init]))
    mainAction = @selector(performAction);
  else {
    CLMainObject = [[objc_lookUpClass([mainObjectName UTF8String]) alloc] init];
    if ([CLMainObject respondsTo:@selector(showPage:)])
      mainAction = @selector(showPage:);
    else {
      CLMainObject = [[CLPage alloc] initFromFile:mainObjectName owner:CLMainObject];
      mainAction = @selector(display);
    }
  }
  
  [CLMainObject perform:mainAction with:nil];
  [CLMainObject release];

 done:
  [CLSession deleteExpiredSessions];
  exit(0);

  return;
}

void CLInitializeQuery(CLString *aString)
{
  char *r, *s, *t, *w;


  if (aString) {
    CLString *key;
    id val;


    [CLQuery removeAllObjects];
    w = strdup([aString UTF8String]);
    
    for (r = w; r && *r; ) {
      s = strchr(r, '=');
      t = strchr(r, '&');
      if (s && (!t || s < t)) {
	*s++ = 0;
	if ((t = strchr(s, '&')))
	  *t++ = 0;
      }
      else if (t)
	*t++ = 0;
      if (r && *r) {
	key = [[CLString stringWithUTF8String:r] stringByReplacingPercentEscapes];
	if (s)
	  val = [[CLString stringWithUTF8String:s] stringByReplacingPercentEscapes];
	else
	  val = [CLNull null];
	[CLQuery setObject:val forKey:key];
      }
      r = t;
    }
    
    free(w);
  }

  return;
}
