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

#import "CLAccount.h"
#import "CLManager.h"
#import "CLAttribute.h"
#import "CLMutableString.h"
#import "CLDatabase.h"
#import "CLArray.h"
#import "CLMutableDictionary.h"
#import "CLSession.h"
#import "CLString.h"
#import "CLStream.h"
#import "CLEmailMessage.h"
#import "CLEditingContext.h"
#import "CLFault.h"
#import "CLNumber.h"
#import "CLDatetime.h"
#import "CLDecimalNumber.h"
#import "CLForm.h"
#import "CLInput.h"
#import "CLPage.h"
#import "CLRecordDefinition.h"

#include <stdlib.h>
#include <crypt.h>
#include <unistd.h>
#include <string.h>
#include <ctype.h>

/* Password reset */
#define FIELD_PASSWORD          @"cl_password"
#define FIELD_VERPASS           @"cl_verpass"

#define PAGE_RESET              @"resetPassword"
#define PAGE_RESETEXP           @"resetExpired"

#define PAGE_CONFIRMACCT	@"accountConfirmThanks"
#define PAGE_CONFIRMEXP		@"accountConfirmExpired"

#define TOKEN_LEN       32
static char tokenset[] = "0123456789abcdefghijklmnopqrstuv";

@implementation CLAccount

+(CLString *) makeNameValid:(CLString *) aString
{
  unichar *buf;
  CLUInteger len;
  int i;
  CLString *newString;
  

  len = [aString length];
  buf = calloc(len, sizeof(unichar));
  [aString getCharacters:buf];
  for (i = 0; i < len; i++) {
    if (buf[i] < ' ' || buf[i] > '~' || (!isalnum(buf[i]) && !strchr("-._", buf[i]))) {
      memmove(&buf[i], &buf[i+1], (len - i - 1) * sizeof(unichar));
      len--;
      i--;
    }
  }

  if (len == [aString length])
    newString = aString;
  else 
    newString = [CLString stringWithCharacters:buf length:len];
  free(buf);

  return newString;
}

-(void) dealloc
{
  [name release];
  [email release];
  [password release];
  [flags release];
  [ipAddress release];
  [created release];
  [lastSeen release];
  [super dealloc];
  return;
}

-(void) new:(id) sender
{
  [CLEditingContext generatePrimaryKey:nil forRecord:self];
  [self edit:sender];
  return;
}

-(id) read:(CLStream *) stream
{
  id anObject;

  
  [super read:stream];
  [stream readTypes:@"i", &objectID];
  if ((anObject = [CLDefaultContext registerInstance:self inTable:[CLEditingContext
								    tableForClass:[self class]]
				      withPrimaryKey:[CLNumber numberWithInt:objectID]]) &&
      anObject != self) {
    [anObject retain];
    [self release];
    self = anObject;
  }
  else
    CLBecomeFault(self, [CLDecimalNumber numberWithInt:objectID],
		  [CLEditingContext recordDefinitionForClass:[self class]], NO);
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeTypes:@"i", &objectID];
  return;
}

-(int) objectID
{
  return objectID;
}

-(CLString *) email
{
  return email;
}

-(CLString *) name
{
  return name;
}

-(CLString *) password
{
  return password;
}

-(CLString *) flags
{
  return flags;
}

-(CLDatetime *) created
{
  return created;
}

-(CLDatetime *) lastSeen
{
  return lastSeen;
}

-(CLString *) ipAddress
{
  return ipAddress;
}

-(void) setEmail:(CLString *) aString
{
  if (![email isEqualToString:aString]) {
    [self willChange];
    [email release];
    email = [aString copy];
  }
  return;
}

-(void) setName:(CLString *) aString
{
  if (![name isEqualToString:aString]) {
    [self willChange];
    [name release];
    name = [aString copy];
  }
  return;
}

-(void) setPassword:(CLString *) aString
{
  if (![password isEqualToString:aString]) {
    [self willChange];
    [password release];
    password = [aString copy];
  }
  return;
}

-(void) setFlags:(CLString *) aString
{
  if (![flags isEqualToString:aString]) {
    [self willChange];
    [flags release];
    flags = [aString copy];
  }
  return;
}

-(void) setCreated:(CLDatetime *) aDate
{
  if (![created isEqual:aDate]) {
    [self willChange];
    [created release];
    created = [aDate retain];
  }
  return;
}

-(void) setLastSeen:(CLDatetime *) aDate
{
  if (![lastSeen isEqual:aDate]) {
    [self willChange];
    [lastSeen release];
    lastSeen = [aDate retain];
  }
  return;
}

-(void) setIpAddress:(CLString *) aString
{
  if (![ipAddress isEqualToString:aString]) {
    [self willChange];
    [ipAddress release];
    ipAddress = [aString copy];
  }
  return;
}

-(BOOL) isAdmin
{
  return [self hasFlag:CLAccountFlagAdmin];
}
  
-(BOOL) isLocked
{
  return [self hasFlag:CLAccountFlagLocked];
}

-(void) setAdmin:(BOOL) flag
{
  if (flag)
    [self addFlag:CLAccountFlagAdmin];
  else
    [self removeFlag:CLAccountFlagAdmin];
  return;
}

-(void) setLocked:(BOOL) flag
{
  if (flag)
    [self addFlag:CLAccountFlagLocked];
  else
    [self removeFlag:CLAccountFlagLocked];
  return;
}

-(BOOL) isActiveAccount
{
  return [[[[CLManager manager] activeSession] account] isEqual:self];
}

-(BOOL) validatePlainPass:(id *) ioValue error:(CLString **) outError
{
  CLString *aString = *ioValue;
  CLString *errString = nil;
  int err = 0;
  

  sawPlain = YES;
  if (sawVer &&
      ((!aString && _verPass) || (aString && !_verPass) ||
       (aString && _verPass && ![aString isEqual:_verPass]))) {
    errString = [CLString stringWithFormat:
			    @"Mismatch between password and verify"];
    err++;
  }

  *outError = errString;
  return !err;
}

-(BOOL) validateVerPass:(id *) ioValue error:(CLString **) outError
{
  CLString *aString = *ioValue;
  CLString *errString = nil;
  int err = 0;
  

  sawVer = YES;
  if (sawPlain &&
      ((!aString && _plainPass) || (aString && !_plainPass) ||
       (aString && _plainPass && ![aString isEqual:_plainPass]))) {
    errString = [CLString stringWithFormat:
			    @"Mismatch between password and verify"];
    err++;
  }

  *outError = errString;
  return !err;
}

-(void) setPlainPass:(CLString *) aString
{
  [_plainPass release];
  _plainPass = [aString copy];
  if (_plainPass && _verPass && [_plainPass isEqualToString:_verPass])
    [self setPassword:[CLString stringWithUTF8String:
				  crypt([[_plainPass lowercaseString] UTF8String],
					[[CLManager randomSalt] UTF8String])]];
  return;
}
    
-(void) setVerPass:(CLString *) aString
{
  [_verPass release];
  _verPass = [aString copy];
  if (_plainPass && _verPass && [_plainPass isEqualToString:_verPass])
    [self setPassword:[CLString stringWithUTF8String:
				  crypt([[_plainPass lowercaseString] UTF8String],
					[[CLManager randomSalt] UTF8String])]];
  return;
}
    
-(void) sendEmail:(CLDictionary *) aDict usingTemplate:(CLString *) aFilename
{
  CLMutableDictionary *mDict;


  mDict = [aDict mutableCopy];
  [mDict setObject:email forKey:@"--FROM_EMAIL--"];
  CLSendEmailUsingTemplate(mDict, aFilename, nil);
  [mDict release];
  return;
}

-(void) setObjectID:(int) aValue
{
  if (objectID)
    [self error:@"Changing primary key"];
  [self willChange];
  objectID = aValue;
  return;
}

-(CLString *) propertyList
{
  return [CLString stringWithFormat:@"{objectID = %i}", objectID];
}

@end

@implementation CLAccount (PasswordRecovery)

+(CLAccount *) accountWithEmail:(CLString *) anEmail
{
  CLString *query;
  CLRecordDefinition *recordDef;
  CLArray *rows;


  recordDef = [CLEditingContext recordDefinitionForClass:self];
  query = [CLString stringWithFormat:@"email = '%@'",
		    [[recordDef database] defangString:anEmail escape:NULL]];
  rows = [CLDefaultContext loadTableWithClass:self qualifier:query];
  if ([rows count])
    return [rows objectAtIndex:0];

  return nil;
}

+(CLAccount *) accountForTokenString:(CLString *) aString
{
  unichar *buf = NULL;
  int buflen;
  unsigned int seed;
  int tkn;
  int i;
  unsigned int setlen = strlen(tokenset);


  if ([aString length] < TOKEN_LEN)
    return nil;

  aString = [aString lowercaseString];

  buflen = [aString length];
  buf = malloc(buflen * sizeof(unichar));
  [aString getCharacters:buf];
  for (i = 0; i < buflen; i++)
    buf[i] = strchr(tokenset, buf[i]) - tokenset;
  seed = buf[0] + buf[1] * setlen;
  srandom(seed);
  for (i = 2; i < TOKEN_LEN; i++)
    buf[i] = (random() % setlen) ^ buf[i];
  for (i = TOKEN_LEN - 1, tkn = 0; i >= 2; i--) {
    tkn *= setlen;
    tkn += buf[i];
  }
  free(buf);

  return [CLDefaultContext loadExistingObjectWithClass:[self class] objectID:tkn];
}

-(void) reset:(id) sender
{
  CLString *pass, *verPass;
  int err = 0;


  if ([sender isKindOfClass:[CLForm class]]) {
    pass = [sender valueOfFieldNamed:FIELD_PASSWORD];
    verPass = [sender valueOfFieldNamed:FIELD_VERPASS];
    if (!pass) {
      [[sender fieldNamed:FIELD_PASSWORD] setErrorString:@"You must enter a password"];
      err++;
    }
    else if (![pass isEqualToString:verPass]) {
      [[sender fieldNamed:FIELD_PASSWORD] setErrorString:@"Entered passwords don't match"];
      err++;
    }

    if (!err) {
      [self setPassword:[CLString stringWithUTF8String:
					 crypt([[pass lowercaseString] UTF8String],
					       [[CLManager randomSalt] UTF8String])]];
      [self setResetToken:0];
      [self setResetExpires:nil];
      [self removeFlag:CLAccountFlagUnconfirmed];
      [self removeFlag:CLAccountFlagInternalUseOnly];

      /* FIXME - should we automatically log them in? */
      [[CLManager activeSession] setAccount:self];
      [CLDefaultContext saveChanges];
      CLRedirectBrowserToPage(@"index", NO);
    }
  }
  
  return;
}

-(void) resetPassword:(id) sender
{
  [[CLManager manager] logout:nil];
  if ([resetExpires compare:[CLDatetime now]] <= 0)
    CLRedirectBrowserToPage(PAGE_RESETEXP, NO);
  else
    [self replacePage:sender filename:PAGE_RESET];

  return;
}

-(CLString *) resetPasswordURL
{
  return [self urlForMethod:@selector(resetPassword:)];
}

-(void) sendResetPasswordEmail
{
  int token = 0;
  CLEmailMessage *anEmail;


  while (!token)
    token = random() % CLIntegerMax;
  [self setResetToken:token];
  [self setResetExpires:[[CLDatetime now] dateByAddingYears:0 months:0 days:0
							   hours:8 minutes:0 seconds:0]];
  [CLDefaultContext saveChanges];

  anEmail = [[CLEmailMessage alloc] initFromFile:@"cl_reset-msg" owner:self];
  [anEmail send];
  [anEmail release];

  return;
}

-(CLString *) encodeToken
{
  unsigned char *tkn;
  unsigned int seed;
  int i;
  long int setlen = strlen(tokenset);
  unsigned char nv;
  int tid;


  tid = [self objectID];
  tkn = malloc(TOKEN_LEN + 1);
  memset(tkn, 0, TOKEN_LEN + 1);
  seed = random() % (setlen * setlen);
  tkn[0] = seed % setlen;
  tkn[1] = (seed / setlen) % setlen;
  srandom(seed);
  for (i = 2; i < TOKEN_LEN; i++)
    tkn[i] = random() % setlen;
  for (i = 2; tid; i++, tid /= setlen) {
    nv = tid % setlen;
    tkn[i] ^= nv;
  }
  for (i = 0; i < TOKEN_LEN; i++)
    tkn[i] = tokenset[(int) tkn[i]];
  
  return [CLString stringWithUTF8String:(char *) tkn];
}

-(int) resetToken
{
  return resetToken;
}

-(CLDatetime *) resetExpires
{
  return resetExpires;
}

-(void) setResetToken:(int) aValue
{
  if (aValue != resetToken) {
    [self willChange];
    resetToken = aValue;
  }
  return;
}

-(void) setResetExpires:(CLDatetime *) aDate
{
  if (![aDate isEqual:resetExpires]) {
    [self willChange];
    [resetExpires release];
    resetExpires = [aDate retain];
  }
  return;
}

-(void) confirmAccount:(id) sender
{
  [[CLManager manager] logout:nil];
  if ([resetExpires compare:[CLDatetime now]] <= 0)
    CLRedirectBrowserToPage(PAGE_CONFIRMEXP, NO);
  else {
    [self setResetToken:0];
    [self setResetExpires:nil];
    [self removeFlag:CLAccountFlagUnconfirmed];
    [self removeFlag:CLAccountFlagInternalUseOnly];
    [[CLManager activeSession] setAccount:self];
    [CLDefaultContext saveChanges];
    [self replacePage:sender filename:PAGE_CONFIRMACCT];
  }

  return;
}

-(CLString *) confirmAccountURL
{
  return [self urlForMethod:@selector(confirmAccount:)];
}

-(void) sendConfirmationEmail
{
  int token = 0;
  CLEmailMessage *anEmail;


  while (!token)
    token = random() % CLIntegerMax;
  [self setResetToken:token];
  [self setResetExpires:[[CLDatetime now] dateByAddingYears:0 months:0 days:0
							   hours:8 minutes:0 seconds:0]];
  [CLDefaultContext saveChanges];

  anEmail = [[CLEmailMessage alloc] initFromFile:@"cl_confirm-msg" owner:self];
  [anEmail send];
  [anEmail release];

  return;
}

@end
