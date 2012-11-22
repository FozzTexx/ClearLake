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

#import "CLEditingContext.h"
#import "CLMutableArray.h"
#import "CLGenericRecord.h"
#import "CLDatabase.h"

@implementation CLEditingContext

-(id) init
{
  [super init];
  dirty = [[CLMutableArray alloc] init];
  inserted = [[CLMutableArray alloc] init];
  updated = [[CLMutableArray alloc] init];
  return self;
}

-(void) dealloc
{
  [dirty release];
  [inserted release];
  [updated release];
  [super dealloc];
  return;
}

-(void) addObject:(id) anObject
{
  if (![dirty containsObjectIdenticalTo:anObject])
    [dirty addObject:anObject];
  return;
}

-(void) removeObject:(id) anObject
{
  CLUInteger index;


  if ((index = [dirty indexOfObjectIdenticalTo:anObject]) != CLNotFound)
    [dirty removeObjectAtIndex:index];
  return;
}

-(id) saveToDatabase
{
  int i, j;
  id result, anObject;
  CLMutableArray *errors = nil, *databases;
  

  databases = [[CLMutableArray alloc] init];
  
  for (i = 0, j = [dirty count]; i < j; i++) {
    anObject = [dirty objectAtIndex:i];
    [anObject willSaveToDatabase];
    if (![databases containsObject:[anObject database]])
      [databases addObject:[anObject database]];
  }

  for (i = 0, j = [databases count]; i < j; i++)
    [[databases objectAtIndex:i] beginTransaction];
  
  for (i = [dirty count] - 1; i >= 0; i--) {
    /* FIXME - check if object needs others to be saved first */
    result = [[dirty objectAtIndex:i] saveSelfWithContext:self];
    if (result) {
      if (!errors)
	errors = [CLMutableArray array];
      [errors addObject:result];
    }
  }

  /* FIXME - delete relationships that don't exist */
  
  if (!errors) {
    for (i = 0, j = [databases count]; i < j; i++)
      [[databases objectAtIndex:i] commitTransaction];
    for (i = 0, j = [inserted count]; i < j; i++)
      [[inserted objectAtIndex:i] didInsertIntoDatabase];
    for (i = 0, j = [updated count]; i < j; i++)
      [[updated objectAtIndex:i] didUpdateDatabase];
  }
  else {
    for (i = 0, j = [databases count]; i < j; i++)
      [[databases objectAtIndex:i] rollbackTransaction];
  }
  
  [dirty removeAllObjects];
  [inserted removeAllObjects];
  [updated removeAllObjects];
  [databases release];
  
  return errors;
}

-(void) didUpdate:(id) anObject
{
  [updated addObject:anObject];
  return;
}

-(void) didInsert:(id) anObject
{
  [inserted addObject:anObject];
  return;
}

@end
