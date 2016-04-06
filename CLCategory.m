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

#import "CLCategory.h"
#import "CLMutableArray.h"
#import "CLAttribute.h"
#import "CLManager.h"
#import "CLMutableString.h"
#import "CLDatabase.h"
#import "CLDictionary.h"
#import "CLCharacterSet.h"
#import "CLEditingContext.h"
#import "CLStandardContent.h"

#include <stdlib.h>

#define MAX_URLLENGTH		20

static CLMutableArray *categories = nil;

@implementation CLCategory

+(void) load
{
  CLCategoryClass = [CLCategory class];
  return;
}

+(CLCategory *) categoryWithID:(int) anID
{
  int i, j;
  CLCategory *aCat;

  
  if (!categories)
    categories = [[CLMutableArray alloc] init];

  for (i = 0, j = [categories count]; i < j; i++)
    if ([(aCat = [categories objectAtIndex:i]) objectID] == anID)
      return aCat;

  aCat = [CLDefaultContext loadObjectWithClass:CLCategoryClass objectID:anID];
  [categories addObject:aCat];
  [aCat release];
  return aCat;
}

+(CLCategory *) categoryWithTitle:(CLString *) aString andParentID:(int) anID
{
  CLArray *attr, *rows;
  CLString *qual;
  CLDatabase *db;
  CLString *fullTable, *localTable;
  CLRange aRange;


  fullTable = [CLEditingContext tableForClass:[self class]];
  aRange = [fullTable rangeOfString:@"."];
  db = [CLEditingContext databaseNamed:[fullTable substringToIndex:aRange.location]];
  localTable = [fullTable substringFromIndex:CLMaxRange(aRange)];

  attr = CLAttributes(@"id:i", nil);
  if (anID)
    qual = [CLString stringWithFormat:
		       @"select id from %@ where title = '%@' and parent_id = %i",
		     localTable, aString, anID];
  else
    qual = [CLString stringWithFormat:
		       @"select id from %@ where title = '%@' and parent_id is null",
		     localTable, aString];
  rows = [db read:attr qualifier:qual errors:NULL];

  if ([rows count])
    return [self categoryWithID:[[[rows objectAtIndex:0] objectForKey:@"id"] intValue]];

  return nil;
}

-(CLString *) path
{
  if ([self parent])
    return [CLString stringWithFormat:@"%@ > %@", [[self parent] path], [self title]];
  else
    return [self title];
}

-(CLString *) pathID
{
  CLArray *anArray;
  CLMutableArray *mArray;
  int i, j;
  CLString *aString;

  
  anArray = [self categoryPath];
  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++)
    [mArray addObject:[[anArray objectAtIndex:i] title]];
  aString = [CLString stringWithFormat:@"%i,%@", [self objectID], mArray];
  [mArray release];
  return aString;
}

-(CLArray *) categoryPath
{
  CLMutableArray *mArray;
  CLArray *anArray;
  int i, j;


  mArray = [[CLMutableArray alloc] init];
  [mArray addObject:self];
  
  if ([self parent]) {
    anArray = [[self parent] categoryPath];
    for (i = 0, j = [anArray count]; i < j; i++)
      [mArray insertObject:[anArray objectAtIndex:i] atIndex:i];
  }

  return [mArray autorelease];
}

-(BOOL) hasParent
{
  return !![self parent];
}

-(CLString *) description
{
  return [self path];
}

-(BOOL) isChildOfCategory:(CLCategory *) aCategory
{
  CLCategory *aParent;
  int oid = [aCategory objectID];


  aParent = self;
  while (aParent) {
    if ([aParent objectID] == oid)
      return YES;
    aParent = [aParent parent];
  }

  return NO;
}

-(void) createUrlTitleFromString:(CLString *) aString
{
  CLMutableString *mString;
  CLCharacterSet *aSet, *notSet;
  CLRange aRange, aRange2;
  int counter;
  CLArray *anArray;
  CLData *aData;


  if ([self hasFieldNamed:@"urlTitle"]) {
    aData = [aString dataUsingEncoding:CLASCIIStringEncoding allowLossyConversion:YES];
    mString = [CLMutableString stringWithData:aData encoding:CLASCIIStringEncoding];
    aSet = [CLCharacterSet characterSetWithCharactersInString:
			     @"0123456789"
			   "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
			   "abcdefghijklmnopqrstuvwxyz"];
    notSet = [aSet invertedSet];

    aRange = [mString rangeOfCharacterFromSet:notSet];
    while (aRange.length) {
      aRange2.location = CLMaxRange(aRange);
      aRange2.length = [mString length] - aRange2.location;
      aRange2 = [mString rangeOfCharacterFromSet:aSet options:0 range:aRange2];
      if (aRange2.length)
	aRange.length = aRange2.location - aRange.location;
      [mString replaceCharactersInRange:aRange withString:@""];
      if (aRange2.length) {
	aRange2.location = aRange.location;
	aRange2.length = [mString length] - aRange2.location;
	aRange = [mString rangeOfCharacterFromSet:notSet options:0 range:aRange2];
      }
      else
	aRange.length = 0;
    }

    if ([mString length] > MAX_URLLENGTH)
      [mString deleteCharactersInRange:
		 CLMakeRange(MAX_URLLENGTH, [mString length] - MAX_URLLENGTH)];
  
    anArray = [[self editingContext] loadTableWithClass:[self class] qualifier:
			[CLString stringWithFormat:@"url_title = '%@'", mString]];
    counter = 1;
    while ([anArray count] && ([anArray count] > 1 ||
			       ![[anArray objectAtIndex:0] isEqual:self])) {
      counter++;
      anArray = [[self editingContext] loadTableWithClass:[self class] qualifier:
			  [CLString stringWithFormat:@"url_title = '%@%i'", mString, counter]];
    }
    if (counter > 1)
      [mString appendFormat:@"%i", counter];

    [self setUrlTitle:mString];
  }

  return;
}

-(void) createUrlTitleFromTitle
{
  [self createUrlTitleFromString:[self title]];
  return;
}

-(CLCategory *) childWithTitle:(CLString *) aTitle
{
  CLArray *anArray;
  int i, j;
  CLCategory *aCat;


  anArray = [self children];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aCat = [anArray objectAtIndex:i];
    if ([[aCat title] isEqualToString:aTitle])
      return aCat;
  }

  return nil;
}

-(BOOL) validateTitle:(id *) ioValue error:(CLString **) outError
{
  CLString *aString = *ioValue;


  if (![aString length]) {
    *outError = @"Please enter a title";
    return NO;
  }

  [self createUrlTitleFromString:aString];
  
  return YES;
}

-(void) willSaveToDatabase
{
  if ([self hasFieldNamed:@"urlTitle"] && ![[self urlTitle] length])
    [self createUrlTitleFromTitle];
  [super willSaveToDatabase];
  return;
}

@end
