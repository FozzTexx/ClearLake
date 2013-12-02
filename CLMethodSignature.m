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

#define _GNU_SOURCE
#include <string.h>

#import "CLMethodSignature.h"
#import "CLMutableString.h"

#include <ctype.h>
#include <stdlib.h>

@implementation CLMethodSignature

+(CLMethodSignature *) methodSignatureForSelector:(SEL) aSel
{
  const char *types = ((struct objc_method_description *) aSel)->types;
  const char *p;
  CLUInteger i, j, offset;
  CLMutableString *mString;


  if (!types) {
    /* FIXME - this is just so totally wrong to have to do this */
    for (j = 0, p = sel_getName(aSel); p && *p; p++)
      if (*p == ':')
	j++;

    offset = sizeof(id);
    mString = [CLMutableString stringWithFormat:@"@0@0:%u", offset];

    for (i = 0, offset += sizeof(id); i < j; i++, offset += sizeof(id))
      [mString appendFormat:@"@%u", offset];

    types = [mString UTF8String];
  }    
    
  return [[self alloc] initFromTypes:types];
}

+(CLMethodSignature *) methodSignatureForDescription:(struct objc_method_description *) aDesc
{
  return [[[self alloc] initFromTypes:aDesc->types] autorelease];
}

-(id) initFromTypes:(const char *) types
{
  const char *p, *q;
  CLUInteger i, j;

  
  [super init];

  args = NULL;
  offsets = NULL;

  for (i = 0, p = types; p && *p; i++)
    p = [self getNextType:p offset:&j];

  count = i-1;
  if (!(args = malloc(sizeof(char *) * (count + 1))))
    [self error:@"Unable to allocate memory"];
  if (!(offsets = malloc(sizeof(int) * (count + 1))))
    [self error:@"Unable to allocate memory"];

  q = [self getNextType:types offset:&j];
  args[0] = strndup(types, q - types);
  offsets[0] = j;
    
  for (i = 1, p = q; p && *p; i++) {
    q = [self getNextType:p offset:&j];
    args[i] = strndup(p, q-p);
    offsets[i] = j;
    p = q;
  }
  
  return self;
}

-(void) dealloc
{
  int i;


  for (i = 0; i < count+1; i++)
    free(args[i]);
  free(args);
  free(offsets);
  [super dealloc];
  return;
}

-(id) copy
{
  CLMethodSignature *aCopy;
  int i;


  aCopy = [super copy];
  aCopy->count = count;
  if (!(aCopy->args = malloc(sizeof(char *) * (count + 1))))
    [self error:@"Unable to allocate memory"];
  if (!(aCopy->offsets = malloc(sizeof(int) * (count + 1))))
    [self error:@"Unable to allocate memory"];
  for (i = 0; i < count+1; i++) {
    aCopy->args[i] = strdup(args[i]);
    aCopy->offsets[i] = offsets[i];
  }

  return aCopy;
}
      
-(const char *) getNextType:(const char *) types offset:(CLUInteger *) offset
{
  char c;
  CLUInteger i;
  BOOL done = NO;


  while (!done) {
    c = *types;
    types++;
    
    switch (c) {
    case _C_ID:
    case _C_CLASS:
    case _C_SEL:
    case _C_CHR:
    case _C_UCHR:
    case _C_SHT:
    case _C_USHT:
    case _C_INT:
    case _C_UINT:
    case _C_LNG:
    case _C_ULNG:
    case _C_LNG_LNG:
    case _C_ULNG_LNG:
    case _C_FLT:
    case _C_DBL:
    case _C_BFLD:
    case _C_VOID:
    case _C_UNDEF:
      done = YES;
      break;
      
    case _C_PTR:
    case _C_CHARPTR:
    case _C_ATOM:
    case _C_ARY_B:
    case _C_ARY_E:
    case _C_UNION_B:
    case _C_UNION_E:
    case _C_STRUCT_B:
    case _C_STRUCT_E:
    case _C_VECTOR:
      break;
    }
  }

  for (i = 0; *types && isdigit(*types); types++) {
    i *= 10;
    i += *types - '0';
  }
  *offset = i;

  return types;
}

-(const char *) getArgumentTypeAtIndex:(CLUInteger) index
{
  return args[index+1];
}

-(CLUInteger) numberOfArguments
{
  return count;
}

-(const char *) methodReturnType
{
  return args[0];
}

-(CLUInteger) sizeOfType:(const char *) aType
{
  switch (*aType) {
  case _C_CHR:
    return sizeof(char);
  case _C_UCHR:
    return sizeof(unsigned char);
  case _C_SHT:
    return sizeof(short);
  case _C_USHT:
    return sizeof(unsigned short);
  case _C_INT:
    return sizeof(int);
  case _C_UINT:
    return sizeof(unsigned int);
  case _C_LNG:
    return sizeof(long);
  case _C_ULNG:
    return sizeof(unsigned long);
  case _C_LNG_LNG:
    return sizeof(long long);
  case _C_ULNG_LNG:
    return sizeof(unsigned long long);
  case _C_FLT:
    return sizeof(float);
  case _C_DBL:
    return sizeof(double);
  }

  return sizeof(void *);
}

-(CLUInteger) sizeOfArgumentAtIndex:(CLUInteger) index
{
  return [self sizeOfType:args[index+1]];
}

-(CLUInteger) sizeOfReturnValue
{
  return [self sizeOfType:args[0]];
}  

@end
