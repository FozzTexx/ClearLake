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
#import "CLRuntime.h"
#import "CLEditingContext.h"
#import "CLArray.h"
#import "CLRecordDefinition.h"
#import "CLClassConstants.h"

@implementation CLAccessControl

-(id) initFromString:(CLString *) aString
{
  CLCharacterSet *ws = [CLCharacterSet whitespaceAndNewlineCharacterSet];
  CLRange objRange, flagRange, trimRange;

  
  [super init];
  object = nil;
  accountFlags = nil;

  if (aString) {
    objRange = [aString rangeOfCharacterFromSet:ws];
    if (objRange.length) {
      flagRange = [aString rangeOfCharacterNotFromSet:ws options:0
			 range:CLMakeRange(CLMaxRange(objRange),
					   [aString length] - CLMaxRange(objRange))];
      if (flagRange.length) {
	trimRange = [aString rangeOfCharacterNotFromSet:ws options:0
						  range:CLMakeRange(0, [aString length])];
	object = [[aString substringWithRange:
			    CLMakeRange(trimRange.location,
					objRange.location - trimRange.location)] retain];
	trimRange = [aString rangeOfCharacterNotFromSet:ws options:CLBackwardsSearch
						  range:
			       CLMakeRange(flagRange.location,
					   [aString length] - flagRange.location)];
	accountFlags = [[aString substringWithRange:
				  CLMakeRange(flagRange.location,
					      CLMaxRange(trimRange) - flagRange.location)]
			 retain];
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

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLAccessControl *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
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
  CLRecordDefinition *recordDef;


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

  if ([anObject isKindOfClass:CLControlClass] && aClass && aMethod) {
    target = [anObject target];
    if ([target isKindOfClass:CLPageTargetClass])
      return YES; /* Deal with it when the page asks */

    action = [CLString stringWithUTF8String:sel_getName([anObject action])];

    if ([target isKindOfClass:CLGenericRecordClass]) {
      localTable = [target table];
      recordDef = [CLEditingContext recordDefinitionForTable:localTable];
      aRange = [localTable rangeOfString:@"."];
      localTable = [[localTable substringFromIndex:CLMaxRange(aRange)] upperCamelCaseString];
      localClass = [[recordDef class] className];
    }

    if (([target isKindOfClass:objc_lookUpClass([aClass UTF8String])] ||
	 ([target isKindOfClass:CLGenericRecordClass] &&
	  ([aClass isEqualToString:localClass] || [aClass isEqualToString:localTable]))) &&
	([aMethod isEqualToString:@"*:"] || [action isEqualToString:aMethod]))
      objMatch = YES;
  }
  else if ([anObject isKindOfClass:CLPageClass] && aFilename) {
    /* FIXME - may need some of the path */
    aString = [anObject filename];
    if ([aString hasPathPrefix:CLAppPath]) {
      aString = [aString substringFromIndex:[CLAppPath length] + 1];
      aString = [aString stringByDeletingPathExtension];

      if ([CLDelegate respondsTo:@selector(additionalPageDirectories)]) {
	CLArray *anArray;
	int i, j;
	CLString *aDir;


	anArray = [CLDelegate additionalPageDirectories];
	for (i = 0, j = [anArray count]; i < j; i++) {
	  aDir = [anArray objectAtIndex:i];
	  if ([aString hasPathPrefix:aDir]) {
	    aString = [aString substringFromIndex:[aDir length] + 1];
	    break;
	  }
	}
      }
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

@end
