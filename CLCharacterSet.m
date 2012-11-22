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

#import "CLCharacterSet.h"
#import "CLMutableString.h"
#import "CLMutableCharacterSet.h"

static CLCharacterSet *CLWhitespaceSet = nil;
static CLCharacterSet *CLControlSet = nil;
static CLCharacterSet *CLAlphaNumUnderscoreSet = nil;
static CLCharacterSet *CLAlphaNumSet = nil;

@interface CLCharacterSet (CLPrivateMethods)
-(id) initFromString:(CLString *) aString;
@end

@implementation CLCharacterSet

+(id) characterSetWithCharactersInString:(CLString *) aString
{
  return [[[self alloc] initFromString:aString] autorelease];
}

+(id) whitespaceAndNewlineCharacterSet
{
  if (!CLWhitespaceSet) {
    CLWhitespaceSet = [[self alloc] initFromString:@" \t\n\r"];
    CLAddToCleanup(CLWhitespaceSet);
  }
  return CLWhitespaceSet;
}

+(id) controlCharacterSet
{
  int i;
  CLMutableString *mString;

  
  if (!CLControlSet) {
    mString = [[CLMutableString alloc] init];
    for (i = 0x00; i <= 0x1f; i++)
      [mString appendCharacter:i];
    for (i = 0x7f; i <= 0x9f; i++)
      [mString appendCharacter:i];
    CLControlSet = [[self alloc] initFromString:mString];
    [mString release];
    CLAddToCleanup(CLControlSet);
  }
  return CLControlSet;
}

+(id) alphaNumericUnderscoreCharacterSet
{
  if (!CLAlphaNumUnderscoreSet) {
    CLAlphaNumUnderscoreSet =
      [[self alloc] initFromString:
		      @"0123456789"
		    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		    "abcdefghijklmnopqrstuvwxyz"
		    "_"];
    CLAddToCleanup(CLAlphaNumUnderscoreSet);
  }

  return CLAlphaNumUnderscoreSet;
}

+(id) alphaNumericCharacterSet
{
  if (!CLAlphaNumSet) {
    CLAlphaNumSet =
      [[self alloc] initFromString:
		      @"0123456789"
		    "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
		    "abcdefghijklmnopqrstuvwxyz"];
    CLAddToCleanup(CLAlphaNumSet);
  }

  return CLAlphaNumSet;
}

-(id) init
{
  return [self initFromString:nil];
}

-(id) initFromString:(CLString *) aString
{
  [super init];
  string = [aString copy];
  inverted = NO;
  return self;
}

-(void) dealloc
{
  [string release];
  [super dealloc];
  return;
}

-(id) copy
{
  return [self retain];
}

-(id) mutableCopy
{
  CLMutableCharacterSet *aCopy = [[CLMutableCharacterSet alloc] init];


  [aCopy addCharactersInString:string];
  if (inverted)
    [aCopy invert];
  return aCopy;
}

-(CLCharacterSet *) invertedSet
{
  CLMutableCharacterSet *copy = [self mutableCopy];


  if (!inverted)
    [copy invert];
  ((CLCharacterSet *) copy)->isa = [CLCharacterSet class];
  return [copy autorelease];
}

-(BOOL) characterIsMember:(unichar) aCharacter
{
  int i, j;


  for (i = 0, j = [string length]; i < j; i++)
    if ([string characterAtIndex:i] == aCharacter)
      return !inverted;

  return inverted;
}

@end
