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

#import "CLAttribute.h"
#import "CLRange.h"
#import "CLString.h"
#import "CLMutableArray.h"
#import "CLEditingContext.h"

#include <stdarg.h>

@implementation CLAttribute

+(void) load
{
  CLAttributeClass = [CLAttribute class];
  return;
}

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

  column = [[aString substringWithRange:aRange2] retain];
  key = nil;
  
  return self;
}

-(void) dealloc
{
  [column release];
  [key release];
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
  CLAttribute *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->column = [column copy];
  aCopy->key = [key copy];
  aCopy->externalType = externalType;
  aCopy->primaryKey = primaryKey;
  return aCopy;
}

-(CLString *) column
{
  return column;
}

-(CLString *) key
{
  return key;
}

-(CLAttributeType) externalType
{
  return externalType;
}

-(BOOL) isPrimaryKey
{
  return primaryKey;
}

-(void) setColumn:(CLString *) aColumn
{
  if (column != aColumn) {
    [column release];
    column = [aColumn copy];
  }
  return;
}

-(void) setKey:(CLString *) aKey
{
  if (key != aKey) {
    [key release];
    key = [aKey copy];
  }
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

  
#if DEBUG_RETAIN
    id self = nil;
#endif
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

  
#if DEBUG_RETAIN
    id self = nil;
#endif
  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++)
    [mArray addObject:[CLAttribute attributeFromString:[anArray objectAtIndex:i]]];
  
  return [mArray autorelease];
}
