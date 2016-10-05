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

#import "CLSession.h"
#import "CLAccount.h"
#import "CLMutableDictionary.h"
#import "CLString.h"
#import "CLDatabase.h"
#import "CLArray.h"
#import "CLNumber.h"
#import "CLManager.h"
#import "CLAttribute.h"
#import "CLHashTable.h"
#import "CLDecimalNumber.h"
#import "CLEditingContext.h"
#import "CLStream.h"
#import "CLRecordDefinition.h"
#import "CLFault.h"
#import "CLDatetime.h"

/* Only here to get the linker to include these classes (via linkerIsBorked) */
#import "CLCreditCard.h"
#import "CLPaymentGateway.h"

#include <stdlib.h>
#include <signal.h>
#include <unistd.h>

@implementation CLSession

+(void) linkerIsBorked
{
  [CLAccount linkerIsBorked];
  [CLCreditCard linkerIsBorked];
  [CLPaymentGateway linkerIsBorked];
  return;
}

+(void) deleteExpiredSessions
{
  CLArray *anArray;
  CLDatetime *aDate;
  CLString *query;
  int i, j;
  CLSession *aSession;
  unsigned int sessionExpire = [[CLManager manager] sessionExpire];
  CLUInteger pid;
  CLDecimalNumber *hash;
  CLRecordDefinition *recordDef;
  CLEditingContext *sessionContext;


  /* Yah this is kind of gross to reuse the hash field as a lock and
     pid tracker, but I don't want to have to add fields to all the
     existing ClearLake and MagicEdit sites. The hash is stored as a
     10 digit decimal number which means it can easily hold twice the
     value of CLUInteger32Max so any values above CLUInteger32Max are
     the pid of a process that should be running cleaning up
     sessions */

  sessionContext = [[CLEditingContext alloc] init];
  recordDef = [CLEditingContext recordDefinitionForClass:[self class]];
  query = [CLString stringWithFormat:@"%@ > %u",
		    [recordDef columnNameForKey:@"browserHash"], CLUInteger32Max];
  anArray = [sessionContext loadTableWithClass:[self class] qualifier:query];

  for (i = 0, j = [anArray count]; i < j; i++) {
    aSession = [anArray objectAtIndex:i];
    hash = [aSession browserHash];
    hash = [hash decimalNumberBySubtracting:
		   [CLDecimalNumber numberWithUnsignedInt:CLUInteger32Max]];
    pid = [hash unsignedIntValue];
    if (!kill(pid, 0))
      break;
  }

  if (i < j)
    return;

  /* Delete any sessions that are dead */
  for (i = 0, j = [anArray count]; i < j; i++)
    [sessionContext deleteObject:[anArray objectAtIndex:i]];

  /* Create a lock */
  aSession = [[[CLEditingContext sessionClass] alloc] init];
  hash = [CLDecimalNumber numberWithUnsignedInt:getpid()];
  hash = [hash decimalNumberByAdding:
		 [CLDecimalNumber numberWithUnsignedInt:CLUInteger32Max]];
  [aSession setBrowserHash:hash];
  [aSession setLastSeen:[CLDatetime now]];
  [sessionContext saveChanges];
  [aSession release];
  
  aDate = [[CLDatetime now]
	    dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:-sessionExpire];
  /* FIXME - get column names from record def */
  query = [CLString stringWithFormat:@"%@ < '%@' and %@ <= %u",
		    [recordDef columnNameForKey:@"lastSeen"],
		    [aDate descriptionWithFormat:@"%Y-%m-%d %H:%M:%S"
					timeZone:[[recordDef database] timeZone]],
		    [recordDef columnNameForKey:@"browserHash"], CLUInteger32Max];
  anArray = [sessionContext loadTableWithClass:[self class] qualifier:query];

  for (i = 0, j = [anArray count]; i < j; i++)
    [sessionContext deleteObject:[anArray objectAtIndex:i]];

  [sessionContext saveChanges];
  [sessionContext release];
  
  return;
}

-(void) dealloc
{
  [browserHash release];
  [lastSeen release];
  [super dealloc];
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
		  [CLEditingContext recordDefinitionForClass:[self class]]);
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeTypes:@"i", &objectID];
  return;
}

-(void) willSaveToDatabase
{
  [super willSaveToDatabase];
  [self setLastSeen:[CLDatetime now]];
  [account setLastSeen:lastSeen];
  if (getenv("REMOTE_ADDR"))
    [account setIpAddress:[CLString stringWithUTF8String:getenv("REMOTE_ADDR")]];
  return;
}

-(int) objectID
{
  return objectID;
}

-(id) account
{
  return account;
}

-(CLDecimalNumber *) browserHash
{
  return browserHash;
}

-(CLDatetime *) lastSeen
{
  return lastSeen;
}

-(id) returnTo
{
  return returnTo;
}

-(void) setAccount:(CLAccount *) anAccount
{
  if (anAccount != account) {
    [self willChange];
    [account release];
    account = [anAccount retain];
  }
  return;
}

-(void) setBrowserHash:(CLDecimalNumber *) aValue
{
  if (browserHash != aValue) {
    [self willChange];
    [browserHash release];
    browserHash = [aValue retain];
  }
  return;
}

-(void) setLastSeen:(CLDatetime *) aDate
{
  if (lastSeen != aDate) {
    [self willChange];
    [lastSeen release];
    lastSeen = [aDate retain];
  }
  return;
}

-(void) setReturnTo:(id) anObject
{
  if (anObject != returnTo) {
    [self willChange];
    [returnTo release];
    returnTo = [anObject retain];
  }
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
    
@end
