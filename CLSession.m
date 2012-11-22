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

#import "CLSession.h"
#import "CLCalendarDate.h"
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

#include <stdlib.h>
#include <signal.h>
#include <unistd.h>

@implementation CLSession

+(void) deleteExpiredSessions
{
  CLArray *anArray;
  CLCalendarDate *aDate;
  CLString *query, *fullTable;
  int i, j;
  CLSession *aSession;
  CLRange aRange;
  CLDatabase *db;
  unsigned int sessionExpire = [[CLManager manager] sessionExpire];
  CLUInteger pid;
  CLDecimalNumber *hash;


  /* Yah this is kind of gross to reuse the hash field as a lock and
     pid tracker, but I don't want to have to add fields to all the
     existing ClearLake and MagicEdit sites. The hash is stored as a
     10 digit decimal number which means it can easily hold twice the
     value of CLUInteger32Max so any values above CLUInteger32Max are
     the pid of a process that should be running cleaning up
     sessions */
  
  fullTable = [CLGenericRecord tableForClassName:[self className]];
  aRange = [fullTable rangeOfString:@"."];
  db = [CLGenericRecord databaseNamed:[fullTable substringToIndex:aRange.location]];
  query = [CLString stringWithFormat:@"hash > %u", CLUInteger32Max];
  anArray = [CLGenericRecord loadTable:fullTable qualifier:query];

  for (i = 0, j = [anArray count]; i < j; i++) {
    aSession = [anArray objectAtIndex:i];
    /* FIXME - there is already a hash method part of CLObject */
    hash = [aSession objectValueForBinding:@"hash"];
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
    [[anArray objectAtIndex:i] deleteFromDatabase];

  /* Create a lock */
  aSession = [[CLSession alloc] init];
  hash = [CLDecimalNumber numberWithUnsignedInt:getpid()];
  hash = [hash decimalNumberByAdding:
		 [CLDecimalNumber numberWithUnsignedInt:CLUInteger32Max]];
  [aSession setHash:hash];
  [aSession setLastSeen:[CLCalendarDate calendarDate]];
  [aSession saveToDatabase];
  [aSession release];
  
  aDate = [[CLCalendarDate calendarDate]
	    dateByAddingYears:0 months:0 days:0 hours:0 minutes:0 seconds:-sessionExpire];
  query = [CLString stringWithFormat:@"last_seen < '%@' and hash <= %u",
		    [aDate descriptionWithCalendarFormat:[db dateFormat]
			   timeZone:[db timeZone]], CLUInteger32Max];
  anArray = [CLGenericRecord loadTable:fullTable qualifier:query];

  for (i = 0, j = [anArray count]; i < j; i++)
    [[anArray objectAtIndex:i] deleteFromDatabase];

  return;
}
  
-(void) saveToDatabase
{
  [[self account] setLastSeen:[CLCalendarDate calendarDate]];
  if (getenv("REMOTE_ADDR"))
    [[self account] setIpAddress:[CLString stringWithUTF8String:getenv("REMOTE_ADDR")]];
  [[self account] saveToDatabase];
  [self setLastSeen:[CLCalendarDate calendarDate]];
  [super saveToDatabase];
  return;
}

@end
