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

#import "CLFault.h"
#import "CLArrayFault.h"
#import "CLRecordDefinition.h"
#import "CLDatabase.h"
#import "CLMutableString.h"
#import "CLMutableDictionary.h"
#import "CLArray.h"
#import "CLAutoreleasePool.h"
#import "CLNull.h"
#import "CLAttribute.h"
#import "CLGenericRecord.h"
#import "CLInvocation.h"
#import "CLMethodSignature.h"
#import "CLRelationship.h"
#import "CLMutableArray.h"
#import "CLEditingContext.h"
#import "CLRuntime.h"
#import "CLNull.h"
#import "CLClassConstants.h"

#include <stdlib.h>
#include <unistd.h>

/* FIXME - see NSManagedObject docs and make this just as awesome */

void CLFaultLoadRelationship(id anObject, CLString *aKey, CLFaultData *data,
			     CLDictionary *keyData);

@class Message;

@implementation CLFault

/* We have our own dealloc to prevent faulting and loading from the database */
-(void) dealloc
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;
  self->isa = data->original;
  [self dealloc];
  [data->info.faultData.primaryKey release];
  [data->info.faultData.recordDef release];
  free(data);

  /* Just here to make the compiler warning go away */
  if (0)
    [super dealloc];
  
  return;
}

-(Class) class
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;
  Class aClass;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;
  aClass = object_getClass(data->original);
  if (class_isMetaClass(aClass))
    aClass = data->original;
  return aClass;
}

-(BOOL) respondsTo:(SEL) aSel
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;

  return data && !!([self isInstance] ?
		    class_getInstanceMethod(data->original, aSel) :
		    class_getClassMethod(data->original, aSel));
}

-(struct objc_method_description *) descriptionForMethod:(SEL) aSel
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;

  return (struct objc_method_description *)
           ([self isInstance] ?
	    class_getInstanceMethod(data->original, aSel) :
	    class_getClassMethod(data->original, aSel));
}

-(BOOL) isMemberOfClass:(Class) aClassObject
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;
  return data->original == aClassObject;
}

-(BOOL) isKindOfClass:(Class) aClassObject
{
  Class class;
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;

  for (class = data->original; class; class = class_getSuperclass(class))
    if (class == aClassObject)
      return YES;
  return NO;
}

-(BOOL) isEqual:(id) anObject
{
  if (self == anObject)
    return YES;
  return NO;
}

-(CLEditingContext *) editingContext
{
  void *buf;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  return reserved->context;
}

-(void) setEditingContext:(CLEditingContext *) aContext
{
  void *buf;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  reserved->context = aContext;
  return;
}

-(void) fault
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;
  int i, j;
  CLArray *anArray;
  CLString *aField;
  id aValue;
  CLAutoreleasePool *pool;
  CLDictionary *fields;
  CLAttribute *anAttr;
  CLMutableDictionary *keyData;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;
  self->isa = data->original;

#if 0
  if ([self isFault])
    [self error:@"How can we still be a fault?"];
#endif

  /* FIXME - find a way to do this without causing an autorelease array */
  pool = [[CLAutoreleasePool alloc] init];

  if (![data->info.faultData.primaryKey isKindOfClass:CLDictionaryClass]) {
    fields = [[CLDictionary alloc] initWithObjectsAndKeys:
				     data->info.faultData.primaryKey,
				   [[[data->info.faultData.recordDef primaryKeys]
						       objectAtIndex:0] column], nil];
    [data->info.faultData.primaryKey release];
    data->info.faultData.primaryKey = fields;
  }

  {
    CLArray *have, *need;


    have = [data->info.faultData.primaryKey allKeys];
    need = [[data->info.faultData.recordDef fields] allValues];
    for (i = 0, j = [need count]; i < j; i++) {
      anAttr = [need objectAtIndex:i];
      if (![have containsObject:[anAttr column]])
	break;
    }

    if (i < j) {
      CLMutableString *mString;
      CLString *aString;
      id errors = nil;
      CLMutableArray *attr;
      CLArray *rows;
    

      [CLEditingContext createSelect:&mString andAttributes:&attr
		 forRecordDefinition:data->info.faultData.recordDef];
      aString = [CLEditingContext qualifierForObject:data->info.faultData.primaryKey
					      fromDatabase:YES
				    recordDefinition:data->info.faultData.recordDef];
      [mString appendFormat:@" where %@", aString];
      rows = [[data->info.faultData.recordDef database] read:attr qualifier:mString
						      errors:&errors];
      if (errors)
	[self error:@"Errors loading table: %s\n", [[errors description] UTF8String]];
      [mString release];
      [attr release];

      [data->info.faultData.primaryKey release];
      /* FIXME - what if there were no rows returned? */
      data->info.faultData.primaryKey = [[rows objectAtIndex:0] retain];
    }
  }

  fields = [data->info.faultData.recordDef fields];
  keyData = [[CLMutableDictionary alloc] init];
  anArray = [fields allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aField = [anArray objectAtIndex:i];
    anAttr = [fields objectForKey:aField];
    aValue = [data->info.faultData.primaryKey objectForKey:[anAttr column]];
    if (aValue == CLNullObject)
      aValue = nil;
    [((CLObject *) self) setPrimitiveValue:aValue forKey:aField];
    if (aValue)
      [keyData setObject:aValue forKey:aField];
  }

  fields = [data->info.faultData.recordDef relationships];
  anArray = [fields allKeys];
  for (i = 0, j = [anArray count]; i < j; i++)
    CLFaultLoadRelationship(self, [anArray objectAtIndex:i], data, keyData);

  [keyData release];
  [data->info.faultData.primaryKey release];
  [data->info.faultData.recordDef release];
  [pool release];
  free(data);

  if ([self respondsTo:@selector(didFault)])
    [((id) self) didFault]; /* Cast to id to stop warning about not responding to didFault */
  
  return;
}

-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  [self fault];
  [anInvocation invoke];
  return;
}  

-(BOOL) isFault
{
  return YES;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data;
  CLString *fieldName;
  id aValue;


  *found = NO;
  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;

  if (![data->info.faultData.primaryKey isKindOfClass:CLDictionaryClass]) {
    fieldName = [[[data->info.faultData.recordDef primaryKeys] objectAtIndex:0] column];
    if ([aBinding isEqualToString:fieldName]) {
      *found = YES;
      return data->info.faultData.primaryKey;
    }
  }
  else if ((aValue = [data->info.faultData.primaryKey objectForKey:aBinding])) {
    if (aValue == CLNullObject)
      aValue = nil;
    *found = YES;
    return aValue;
  }

  [self fault];
  return [self objectValueForBinding:aBinding found:found];
}

-(id) objectValueForBinding:(CLString *) aBinding
{
  BOOL found;


  return [self objectValueForBinding:aBinding found:&found];
}

-(IMP) methodFor:(SEL) aSel
{
  void *buf;
  CLFaultData *data;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  data = reserved->faultData;

  return method_getImplementation(class_getInstanceMethod(data->original, aSel));
}

-(BOOL) shouldDeferRelease
{
#if 0
  [self fault];
  return [self shouldDeferRelease];
#endif
  return NO;
}

@end

void CLFaultLoadRelationship(id anObject, CLString *aKey, CLFaultData *data,
			     CLDictionary *keyData)
{
  CLString *qual = nil;
  id pk;
  CLArray *anArray;
  CLRelationship *aRelationship;
  id aValue;
  CLAutoreleasePool *pool;


#if DEBUG_RETAIN
    id self = nil;
#endif
  pool = [[CLAutoreleasePool alloc] init];
  aRelationship = [[data->info.faultData.recordDef relationships] objectForKey:aKey];

  if ((pk = [aRelationship constructKey:keyData]))
    qual = [aRelationship constructQualifierFromKey:pk];

#if 0
  fprintf(stderr, "Loading relationship: %s:%s %s\n", [[anObject className] UTF8String],
	  [aKey UTF8String], [qual UTF8String]);
#endif
  aValue = nil;
  if (![aRelationship toMany]) {
    if (pk) {
      aValue = [[[anObject editingContext] recordForPrimaryKey:pk
					      inTable:[aRelationship theirTable]] retain];
      if (!aValue) {
#if 0
	/* FIXME - I don't want to go hit the db but if it doesn't
	   exist I need it to be nil and not a fault */
	aValue = CLNewFault(pk, [CLDefaultContext
				  recordDefinitionForTable:[aRelationship theirTable]], YES);
#else
	anArray = [[anObject editingContext]
		    loadTableWithRecordDefinition:
		      [CLEditingContext recordDefinitionForTable:
					  [aRelationship theirTable]]
			     qualifier:qual];
	if ([anArray count])
	  aValue = [[anArray objectAtIndex:0] retain];
#endif
      }
    }
  }
  else
    aValue = CLNewArrayFault(qual, [aRelationship theirTable], [anObject editingContext]);

  if (aValue)
    [anObject setPrimitiveValue:aValue forKey:aKey];

  [pool release];

  /* FIXME - figure out if we own it and/or need to retain it. Currently
     setPrimitiveValue will do a retain if it's an object, which is
     probably wrong. */
  if ([aValue retainCount] == 1) {
#if 0
    if (isatty(2))
      fprintf(stderr, "Leaking! %s.%s\n", [[anObject className] UTF8String],
	      [aKey UTF8String]);
  //[anObject error:@"Why did we just load this then?"];
#endif
  }
  else
    [aValue release];
  
  return;
}

id CLNewFault(id info, CLRecordDefinition *recordDef)
{
  id anObject;


#if DEBUG_RETAIN
    id self = nil;
#endif
  anObject = [[[recordDef recordClass] alloc] init];
#if 0
  if ([anObject isKindOfClass:[Message class]])
    fprintf(stderr, "NewFault Message %lx %i\n", (unsigned long) anObject,
	    [[info objectForKey:@"id"] intValue]);
#endif
  CLBecomeFault(anObject, info, recordDef);
  return anObject;
}

void CLBecomeFault(id anObject, id info, CLRecordDefinition *recordDef)
{
  void *buf;
  CLObjectReserved *reserved;
  CLFaultData *data, *newFault;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  buf = newFault = (CLFaultData *) anObject;
  reserved = buf - sizeof(CLObjectReserved);
  data = calloc(1, sizeof(CLFaultData));
  reserved->faultData = data;
  data->original = newFault->original;
  data->info.faultData.primaryKey = [info retain];
  data->info.faultData.recordDef = [recordDef retain];
  newFault->original = CLFaultClass;

#if 0
  fprintf(stderr, "0x%08lx 0x%08lx 0x%08lx 0x%08lx\n", (long unsigned int) newFault,
	  (long unsigned int) data->original,
	  (long unsigned int) data->val1, (long unsigned int) data->val2);
#endif

  return;
}
