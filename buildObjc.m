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

#import <ClearLake/ClearLake.h>

#include <stdlib.h>
#include <sys/time.h>

void printInterface(CLRecordDefinition *recordDef, CLDictionary *model);
void printFields(CLRecordDefinition *recordDef, CLDictionary *model);
void printRelationships(CLRecordDefinition *recordDef, CLDictionary *model);

int main(int argc, char *argv[])
{
  struct timeval tv;
  CLAutoreleasePool *pool;
  CLDictionary *model, *schema;
  CLRecordDefinition *recordDef;
  CLArray *keys, *classes;
  int i, j, k, l;
  

#if DEBUG_LEAK || DEBUG_RETAIN
  {
    extern int CLLeakPrint;
    CLLeakPrint = 1;
  }
#endif
  pool = [[CLAutoreleasePool alloc] init];

  gettimeofday(&tv, NULL);
  srandom(tv.tv_sec + tv.tv_usec);

  [CLManager setConfigurationFile:[CLString stringWithUTF8String:argv[1]]];

  model = [CLEditingContext model];

  keys = [model allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    schema = [[model objectForKey:[keys objectAtIndex:i]] objectForKey:@"schema"];
    classes = [schema allKeys];
    for (k = 0, l = [classes count]; k < l; k++) {
      recordDef = [schema objectForKey:[classes objectAtIndex:k]];
      printInterface(recordDef, model);
    }
  }
  
  [pool release];

  exit(0);
}

void printInterface(CLRecordDefinition *recordDef, CLDictionary *model)
{
  printf("@interface %s (Magic)\n", [[[recordDef recordClass] className] UTF8String]);
  printFields(recordDef, model);
  printf("\n");
  printRelationships(recordDef, model);
  printf("@end\n");

  return;
}

void printFields(CLRecordDefinition *recordDef, CLDictionary *model)
{
  int i, j;
  CLArray *anArray;
  CLDictionary *aDict;
  CLAttribute *anAttribute;
  CLString *aName, *aType = nil;


  aDict = [recordDef fields];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aName = [anArray objectAtIndex:i];
    if ([aName isEqualToString:@"id"])
      continue;
    
    anAttribute = [aDict objectForKey:aName];
    switch ([anAttribute externalType]) {
    case CLVarcharAttributeType:
    case CLCharAttributeType:
      aType = @"CLString *";
      break;

      /* FIXME - allow int/CLNumber option somehow */
    case CLIntAttributeType:
      aType = @"int";
      break;

    case CLDatetimeAttributeType:
      aType = @"CLDatetime *";
      break;

    case CLMoneyAttributeType:
    case CLNumericAttributeType:
      aType = @"CLDecimalNumber *";
      break;
    }
    
    printf("-(%s) %s;\n", [aType UTF8String], [aName UTF8String]);
  }

  printf("\n");
  
  for (i = 0, j = [anArray count]; i < j; i++) {
    aName = [anArray objectAtIndex:i];
    if ([aName isEqualToString:@"id"])
      continue;
    
    anAttribute = [aDict objectForKey:aName];
    switch ([anAttribute externalType]) {
    case CLVarcharAttributeType:
    case CLCharAttributeType:
      aType = @"(CLString *) aString";
      break;

      /* FIXME - allow int option somehow */
    case CLIntAttributeType:
      aType = @"(int) aNumber";
      break;

    case CLDatetimeAttributeType:
      aType = @"(CLDatetime *) aDate";
      break;

    case CLMoneyAttributeType:
    case CLNumericAttributeType:
      aType = @"(CLDecimalNumber *) aNumber";
      break;
    }
    
    printf("-(void) set%s:%s;\n", [[aName upperCamelCaseString] UTF8String],
	   [aType UTF8String]);
  }
  
  return;
}

void printRelationships(CLRecordDefinition *recordDef, CLDictionary *model)
{
  int i, j;
  CLArray *anArray;
  CLDictionary *aDict;
  CLRelationship *aRelationship;
  CLString *aName;


  aDict = [recordDef relationships];
  anArray = [aDict allKeys];
  for (i = 0, j = [anArray count]; i < j; i++) {
    aName = [anArray objectAtIndex:i];
    aRelationship = [aDict objectForKey:aName];
    if ([aRelationship toMany])
      printf("-(CLArray *) %s;\n", [aName UTF8String]);
    else {
      printf("-(%s *) %s;\n",
	     [[[CLEditingContext classForTable:[aRelationship theirTable]] className]
	       UTF8String], [aName UTF8String]);
    }
  }
  
  return;
}
