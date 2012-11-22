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

#import "CLRelationship.h"
#import "CLMutableString.h"
#import "CLMutableArray.h"
#import "CLDatabase.h"
#import "CLCalendarDate.h"
#import "CLMutableDictionary.h"
#import "CLGenericRecord.h"
#import "CLAttribute.h"
#import "CLNull.h"

@implementation CLRelationship

-(id) init
{
  return [self initFromString:nil databaseName:nil];
}

-(id) initFromString:(CLString *) aString databaseName:(CLString *) aDatabase
{
  CLRange aRange, aRange2, aRange3;
  CLString *ourID, *theirID;
  CLArray *anArray;
  CLMutableArray *mArray;
  int i, j;


  [super init];
  ourKeys = theirKeys = nil;
  theirTable = nil;
  isOwner = toMany = isDependent = NO;

  if (aString) {
    aRange2 = CLMakeRange(0, [aString length]);
    aRange = [aString rangeOfString:@"=" options:0 range:aRange2];
    aRange2 = [aString rangeOfString:@"." options:0 range:aRange2];
    aRange3.location = CLMaxRange(aRange2);
    aRange3.length = [aString length] - aRange3.location;
    aRange3 = [aString rangeOfString:@"." options:0 range:aRange3];
    if (aRange3.length)
      aRange2 = aRange3;
    if ([aString characterAtIndex:aRange.location - 1] == '*') {
      toMany = YES;
      aRange.location--;
      aRange.length++;
    }

    if ([aString characterAtIndex:0] == '+') {
      isOwner = YES;
      ourID = [aString substringWithRange:CLMakeRange(1, aRange.location-1)];
    }
    else
      ourID = [aString substringToIndex:aRange.location];

    theirTable = [[aString substringWithRange:
			    CLMakeRange(CLMaxRange(aRange),
				     aRange2.location - CLMaxRange(aRange))] retain];
    theirID = [aString substringFromIndex:CLMaxRange(aRange2)];
    aRange = [theirTable rangeOfString:@"."];
    if (!aRange.length) {
      [theirTable autorelease];
      theirTable = [[CLString stringWithFormat:@"%@.%@", aDatabase, theirTable] retain];
    }

    mArray = [[CLMutableArray alloc] init];
    anArray = [ourID componentsSeparatedByString:@","];
    for (i = 0, j = [anArray count]; i < j; i++)
      [mArray addObject:[[anArray objectAtIndex:i] lowerCamelCaseString]];
    ourKeys = mArray;
    
    mArray = [[CLMutableArray alloc] init];
    anArray = [theirID componentsSeparatedByString:@","];
    for (i = 0, j = [anArray count]; i < j; i++)
      [mArray addObject:[[anArray objectAtIndex:i] lowerCamelCaseString]];
    theirKeys = mArray;
  }
  
  return self;
}

-(void) dealloc
{
  [ourKeys release];
  [theirKeys release];
  [theirTable release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLRelationship *aCopy;


  aCopy = [super copy];
  aCopy->ourKeys = [ourKeys copy];
  aCopy->theirKeys = [theirKeys copy];
  aCopy->theirTable = [theirTable copy];
  aCopy->isOwner = isOwner;
  aCopy->toMany = toMany;
  aCopy->isDependent = isDependent;

  return aCopy;
}
      
-(CLString *) theirTable
{
  return theirTable;
}

-(CLArray *) ourKeys
{
  return ourKeys;
}

-(CLArray *) theirKeys
{
  return theirKeys;
}

-(BOOL) isOwner
{
  return isOwner;
}

-(BOOL) toMany
{
  return toMany;
}

-(BOOL) isDependent
{
  return isDependent;
}

-(void) setDependent:(BOOL) flag
{
  isDependent = flag;
  return;
}

-(CLString *) constructQualifier:(id) anObject
{
  return [self constructQualifierFromDictionary:[self constructKey:anObject]];
}

/* Creates a string that will find the object in the database */
-(CLString *) constructQualifierFromDictionary:(CLDictionary *) aDict
{
  int i, j;
  CLMutableString *mString = nil;
  id aValue;
  CLDictionary *fields;


  if (!aDict)
    return nil;

  fields = [[CLGenericRecord recordDefForTable:theirTable] objectForKey:@"fields"];

  for (i = 0, j = [theirKeys count]; i < j; i++) {
    aValue = [aDict objectForKey:[theirKeys objectAtIndex:i]];
    
    if (!mString)
      mString = [[CLMutableString alloc] init];
    if (i)
      [mString appendString:@" and "];

    if ([aValue isKindOfClass:[CLString class]])
      aValue = [CLString stringWithFormat:@"'%@'",
			 [CLDatabase defangString:aValue escape:NULL]];
    else if ([aValue isKindOfClass:[CLCalendarDate class]])
      aValue = [CLString stringWithFormat:@"'%@'", aValue];

    [mString appendFormat:@"%@ = %@",
	     [(CLAttribute *) [fields objectForKey:[theirKeys objectAtIndex:i]] name],
	     aValue];
  }
  
  return [mString autorelease];
}

-(CLDictionary *) constructKey:(id) anObject
{
  int i, j;
  CLMutableDictionary *mDict = nil;
  id aValue;


  for (i = 0, j = [ourKeys count]; i < j; i++) {
    if (!(aValue = [anObject objectValueForBinding:[ourKeys objectAtIndex:i]])) {
      [mDict release];
      mDict = nil;
      break;
    }
    
    if (!mDict)
      mDict = [[CLMutableDictionary alloc] init];
    [mDict setObject:aValue forKey:[theirKeys objectAtIndex:i]];
  }
  
  return [mDict autorelease];
}

/* Fills in the dictionary using column names in the database */
-(void) setDictionary:(CLMutableDictionary *) aDict andRecord:(id) aRecord
	  usingObject:(id) anObject fieldDefinition:(CLDictionary *) fields
{
  int i, j;
  CLString *aKey;
  id aValue;
  CLAttribute *anAttr;


  for (i = 0, j = [ourKeys count]; i < j; i++) {
    aValue = [anObject objectValueForBinding:[theirKeys objectAtIndex:i]];
    if (!aValue) {
      CLDictionary *theirFields;


      theirFields = [[((CLGenericRecord *) anObject) recordDef] objectForKey:@"fields"];
      if ([[theirFields objectForKey:[theirKeys objectAtIndex:i]] isPrimaryKey])
	[anObject generatePrimaryKey:nil];
      aValue = [anObject objectValueForBinding:[theirKeys objectAtIndex:i]];
    }
    
    aKey = [ourKeys objectAtIndex:i];
    if (!fields)
      anAttr = [aRecord attributeForField:aKey];
    else
      anAttr = [fields objectForKey:aKey];
    
    if (aValue) {
      [aDict setObject:aValue forKey:[anAttr name]];
      [aRecord setObjectValue:aValue forBinding:aKey];
    }
    else if (![anAttr isPrimaryKey]) { /* Don't clear out primary key */
      [aDict setObject:[CLNull null]
	     forKey:[anAttr name]];
      [aRecord setObjectValue:nil forBinding:aKey];
    }
  }

  return;
}

/* Fills in the dictionary using column names in the database */
-(void) setDictionary:(CLMutableDictionary *) aDict 
	  usingRecord:(id) aRecord fieldDefinition:(CLDictionary *) fields
{
  int i, j;
  CLString *aKey;
  id aValue;


  for (i = 0, j = [ourKeys count]; i < j; i++) {
    aKey = [ourKeys objectAtIndex:i];
    aValue = [aRecord objectValueForBinding:aKey];
    if (aValue)
      [aDict setObject:aValue forKey:[(CLAttribute *) [fields objectForKey:aKey] name]];
    else
      [aDict removeObjectForKey:[(CLAttribute *) [fields objectForKey:aKey] name]];
  }

  return;
}

-(BOOL) isReciprocal:(CLRelationship *) aRelationship forTable:(CLString *) aTable
{
  if (![aTable isEqualToString:theirTable])
    return NO;

  if (![ourKeys isEqual:aRelationship->theirKeys] ||
      ![aRelationship->ourKeys isEqual:theirKeys])
    return NO;

  return YES;
}

@end
