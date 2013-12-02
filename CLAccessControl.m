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

#import "CLAccessControl.h"
#import "CLCharacterSet.h"
#import "CLString.h"
#import "CLAccount.h"
#import "CLManager.h"
#import "CLControl.h"
#import "CLPageTarget.h"
#import "CLPage.h"
#import "CLSession.h"
#import "CLDictionary.h"

@implementation CLAccessControl

-(id) initFromString:(CLString *) aString
{
  CLCharacterSet *ws = [CLCharacterSet whitespaceAndNewlineCharacterSet];
  CLCharacterSet *nws;
  CLRange aRange, aRange2;

  
  [super init];
  object = nil;
  accountFlags = nil;

  if (aString) {
    aRange = [aString rangeOfCharacterFromSet:ws];
    if (aRange.length) {
      nws = [ws invertedSet];
      aRange2 = [aString rangeOfCharacterFromSet:nws options:0
			 range:CLMakeRange(CLMaxRange(aRange),
					   [aString length] - CLMaxRange(aRange))];
      if (aRange2.length) {
	object = [[[aString substringToIndex:aRange.location]
		   stringByTrimmingCharactersInSet:ws] retain];
	accountFlags = [[[aString substringFromIndex:aRange2.location]
			 stringByTrimmingCharactersInSet:ws] retain];
      }
    }
  }
  
  return self;
}

-(void) dealloc
{
  [object release];
  [accountFlags release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLAccessControl *aCopy;


  aCopy = [super copy];
  aCopy->object = [object copy];
  aCopy->accountFlags = [accountFlags copy];
  return aCopy;
}

-(BOOL) matchesObject:(id) anObject
{
  CLRange aRange;
  CLString *aClass = nil, *aMethod = nil, *aFilename = nil;
  BOOL objMatch = NO;
  CLString *aString;
  id target;
  CLString *action;
  CLString *localTable = nil, *localClass = nil;
  CLDictionary *aDict;


  aRange = [object rangeOfString:@","];
  if (aRange.length) {
    aClass = [object substringToIndex:aRange.location];
    aMethod = [object substringFromIndex:CLMaxRange(aRange)];
    if ([aMethod characterAtIndex:[aMethod length] - 1] == ':')
      aMethod = [aMethod substringToIndex:[aMethod length] - 1];
    aFilename = [CLString stringWithFormat:@"%@_%@", aClass, aMethod];
    aMethod = [CLString stringWithFormat:@"%@:", aMethod];
  }
  else
    aFilename = object;

  if ([anObject isKindOfClass:[CLControl class]] && aClass && aMethod) {
    target = [anObject target];
    if ([target isKindOfClass:[CLPageTarget class]])
      return YES; /* Deal with it when the page asks */

    action = [CLString stringWithUTF8String:sel_getName([anObject action])];

    if ([target isKindOfClass:[CLGenericRecord class]]) {
      localTable = [target table];
      aDict = [CLGenericRecord recordDefForTable:localTable];
      aRange = [localTable rangeOfString:@"."];
      localTable = [[localTable substringFromIndex:CLMaxRange(aRange)] upperCamelCaseString];
      localClass = [aDict objectForKey:@"class"];
    }

    if (([target isKindOfClass:objc_lookUpClass([aClass UTF8String])] ||
	 ([target isKindOfClass:[CLGenericRecord class]] &&
	  ([aClass isEqualToString:localClass] || [aClass isEqualToString:localTable]))) &&
	([aMethod isEqualToString:@"*:"] || [action isEqualToString:aMethod]))
      objMatch = YES;
  }
  else if ([anObject isKindOfClass:[CLPage class]] && aFilename) {
    /* FIXME - may need some of the path */
    aString = [anObject filename];
    if ([aString hasPrefix:CLAppPath] && [aString length] > [CLAppPath length] + 1 &&
	[aString characterAtIndex:[CLAppPath length]] == '/') {
      aString = [aString substringFromIndex:[CLAppPath length] + 1];
      aString = [aString stringByDeletingPathExtension];
    }

    if ([aString hasPrefix:[CLString stringWithFormat:@"%@/", [CLManager browserType]]])
      aString = [aString substringFromIndex:[[CLManager browserType] length] + 1];
    
    if ([aString isEqualToString:aFilename])
      objMatch = YES;
    if ([aMethod isEqualToString:@"*:"] && [aString hasPrefix:aClass] &&
	[aString characterAtIndex:[aClass length]] == '_')
      objMatch = YES;
  }

  return objMatch;
}

-(BOOL) checkPermission:(id) anObject
{
  CLAccount *account = [[[CLManager manager] activeSession] account];
  int i, j;


  if ([self matchesObject:anObject]) {
    if ([accountFlags isEqualToString:@"-"])
      return YES;
    if ([accountFlags isEqualToString:@"+"] && account)
      return YES;
    for (i = 0, j = [accountFlags length]; i < j; i++)
      if (![account hasFlag:[accountFlags characterAtIndex:i]])
	break;
    if (i == j)
      return YES;
  }
  
  return NO;
}

-(BOOL) isWildcard
{
  return [object hasSuffix:@",*"];
}

@end
