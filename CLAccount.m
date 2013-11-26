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

#import "CLAccount.h"
#import "CLManager.h"
#import "CLAttribute.h"
#import "CLMutableString.h"
#import "CLDatabase.h"
#import "CLArray.h"
#import "CLMutableDictionary.h"
#import "CLCalendarDate.h"
#import "CLSession.h"
#import "CLString.h"
#import "CLStream.h"
#import "CLOpenFile.h"
#import "CLEmailMessage.h"

#include <stdlib.h>
#include <crypt.h>
#include <unistd.h>
#include <string.h>

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
    if (buf[i] < ' ' || buf[i] > '~' || strchr("@?&/+#", buf[i])) {
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

-(id) initFromObjectID:(int) anID
{
  return [super initFromObjectID:anID table:[CLGenericRecord tableForClass:self]];
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

-(void) saveToDatabase
{
  if (![self created])
    [self setCreated:[CLCalendarDate calendarDate]];
  [super saveToDatabase];
  return;
}

-(BOOL) validatePlainPass:(id *) ioValue error:(CLString **) outError
{
  CLString *aString = *ioValue;
  CLString *errString = nil;
  int err = 0;
  

  sawPlain = YES;
  if (sawVer &&
      ((!aString && verPass) || (aString && !verPass) ||
       (aString && verPass && ![aString isEqual:verPass]))) {
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
      ((!aString && plainPass) || (aString && !plainPass) ||
       (aString && plainPass && ![aString isEqual:plainPass]))) {
    errString = [CLString stringWithFormat:
			    @"Mismatch between password and verify"];
    err++;
  }

  *outError = errString;
  return !err;
}

-(void) setPlainPass:(CLString *) aString
{
  [plainPass release];
  plainPass = [aString copy];
  if (plainPass && verPass && [plainPass isEqualToString:verPass])
    [self setPassword:[CLString stringWithUTF8String:
				  crypt([[plainPass lowercaseString] UTF8String],
					[[CLManager randomSalt] UTF8String])]];
  return;
}
    
-(void) setVerPass:(CLString *) aString
{
  [verPass release];
  verPass = [aString copy];
  if (plainPass && verPass && [plainPass isEqualToString:verPass])
    [self setPassword:[CLString stringWithUTF8String:
				  crypt([[plainPass lowercaseString] UTF8String],
					[[CLManager randomSalt] UTF8String])]];
  return;
}
    
-(void) sendEmail:(CLDictionary *) aDict usingTemplate:(CLString *) aFilename
{
  CLMutableDictionary *mDict;


  mDict = [aDict mutableCopy];
  [mDict setObject:[self email] forKey:@"--FROM_EMAIL--"];
  CLSendEmailUsingTemplate(mDict, aFilename, nil);
  [mDict release];
  return;
}

@end
