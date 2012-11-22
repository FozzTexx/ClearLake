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

#import "CLAttribute.h"
#import "CLRange.h"
#import "CLString.h"
#import "CLMutableArray.h"

#include <stdarg.h>

@implementation CLAttribute

+(CLAttribute *) attributeFromString:(CLString *) aString
{
  return [[[CLAttribute alloc] initFromString:aString] autorelease];
}

-(id) init
{
  return [self initFromString:nil];
}

-(id) initFromString:(CLString *) aString
{
  CLRange aRange, aRange2;
  
  
  [super init];

  primaryKey = NO;
  aRange2.location = 0;
  aRange2.length = [aString length];
  if ([aString characterAtIndex:0] == '+') {
    primaryKey = YES;
    aRange2.location++;
    aRange2.length--;
  }
  
  aRange = [aString rangeOfString:@":" options:0 range:aRange2];
  if (!aRange.length)
    externalType = CLVarcharAttributeType;
  else {
    aRange2.length = aRange.location - aRange2.location;
    externalType = CLAttributeTypeFor([aString characterAtIndex:CLMaxRange(aRange)]);
  }

  name = [[aString substringWithRange:aRange2] retain];
  
  return self;
}

-(void) dealloc
{
  [name release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLAttribute *aCopy;


  aCopy = [super copy];
  aCopy->name = [name copy];
  aCopy->externalType = externalType;
  aCopy->primaryKey = primaryKey;
  return aCopy;
}

-(CLString *) name
{
  return name;
}

-(CLAttributeType) externalType
{
  return externalType;
}

-(BOOL) isPrimaryKey
{
  return primaryKey;
}

-(void) setName:(CLString *) aName
{
  [name autorelease];
  name = [aName copy];
  return;
}

-(void) setExternalType:(CLAttributeType) aType
{
  externalType = aType;
  return;
}

-(void) setPrimaryKey:(BOOL) aFlag
{
  primaryKey = aFlag;
  return;
}

@end

CLAttributeType CLAttributeTypeFor(int aType)
{
  switch (aType) {
  case '*':
    return CLVarcharAttributeType;
  case 'i':
    return CLIntAttributeType;
  case '$':
    return CLMoneyAttributeType;
  case '#':
    return CLNumericAttributeType;
  case '@':
    return CLDatetimeAttributeType;
  case 'c':
    return CLCharAttributeType;
  }

  return 0;
}

CLArray *CLAttributes(CLString *name, ...)
{
  va_list ap;
  CLMutableArray *mArray;

  
  mArray = [[CLMutableArray alloc] init];
  [mArray addObject:[CLAttribute attributeFromString:name]];

  va_start(ap, name);
  while ((name = va_arg(ap, CLString *)))
    [mArray addObject:[CLAttribute attributeFromString:name]];
  va_end(ap);
  
  return [mArray autorelease];
}

CLArray *CLAttributesFromArray(CLArray *anArray)
{
  CLMutableArray *mArray;
  int i, j;

  
  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++)
    [mArray addObject:[CLAttribute attributeFromString:[anArray objectAtIndex:i]]];
  
  return [mArray autorelease];
}
