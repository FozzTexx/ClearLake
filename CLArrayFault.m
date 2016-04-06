/* Copyright 2012-2016 by
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

#import "CLArrayFault.h"
#import "CLMutableArray.h"
#import "CLAutoreleasePool.h"
#import "CLInvocation.h"
#import "CLGenericRecord.h"
#import "CLEditingContext.h"

#include <stdlib.h>

/* FIXME - add a count method to avoid faulting things in */

@implementation CLArrayFault

/* We have our own dealloc to prevent faulting and loading from the database */
-(void) dealloc
{
  void *buf;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  reserved->context = nil;
  [super dealloc];
  
  return;
}

-(void) fault
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;
  CLAutoreleasePool *pool;
  CLArray *anArray;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;
  self->isa = data->original;

  pool = [[CLAutoreleasePool alloc] init];
  if (data->info.arrayData.qualifier) {
    anArray = [reserved->context loadTableWithRecordDefinition:
		    [CLEditingContext recordDefinitionForTable:data->info.arrayData.table]
						     qualifier:data->info.arrayData.qualifier];
    [((CLMutableArray *) self) addObjectsFromArray:anArray];
    [data->info.arrayData.objects removeObjectsInArray:anArray];
#if 0
    fprintf(stderr, "Loaded %s - %s : %i\n", [data->val2 UTF8String],
	    [data->val1 UTF8String], [((CLMutableArray *) self) count]);
#endif
  }

  [((CLMutableArray *) self) addObjectsFromArray:data->info.arrayData.objects];

  reserved->context = nil;
  [data->info.arrayData.qualifier release];
  [data->info.arrayData.table release];
  [data->info.arrayData.objects release];
  [pool release];
  free(data);

  return;
}

-(BOOL) isEqual:(id) anObject
{
  if (self == anObject)
    return YES;
  /* FIXME - is there a way to do this without loading from the database? */
  [self fault];
  return [self isEqual:anObject];
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  [self fault];
  return [self objectValueForBinding:aBinding found:found];
}

-(BOOL) containsObjectIdenticalTo:(id) anObject
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;
  id pk;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;

  if ([data->info.arrayData.objects containsObjectIdenticalTo:anObject])
    return YES;
  if (!(pk = [[anObject editingContext] primaryKeyForRecord:anObject]))
    return NO;

  /* FIXME - query the database and see if there's a record with that pk tied to us */
  
  [self fault];
  return [self containsObjectIdenticalTo:anObject];
}

-(void) addObject:(id) anObject
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;

  if (!data->info.arrayData.objects)
    data->info.arrayData.objects = [[CLMutableArray alloc] init];
  [data->info.arrayData.objects addObject:anObject];
  return;
}

@end

id CLNewArrayFault(CLString *aQualifier, CLString *aTable, CLEditingContext *aContext)
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data, *anObject;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  

  anObject = (CLFaultData *) [[CLMutableArray alloc] init];
  buf = anObject;
  reserved = buf - sizeof(CLObjectReserved);
  data = calloc(1, sizeof(CLFaultData));
  reserved->faultData = data;
  reserved->context = aContext;
  data->original = anObject->original;
  data->info.arrayData.qualifier = [aQualifier copy];
  data->info.arrayData.table = [aTable copy];
  data->info.arrayData.objects = nil;
  anObject->original = CLArrayFaultClass;

  return (id) anObject;
}
