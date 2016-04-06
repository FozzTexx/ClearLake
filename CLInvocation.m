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

#import "CLInvocation.h"
#import "CLMethodSignature.h"
#import "CLNumber.h"
#import "CLString.h"
#import "CLRuntime.h"

#include <stdlib.h>
#include <ffi.h>
#include <stdio.h>
#include <string.h>

void *CLFFITypeForObjCType(const char *aType)
{
  switch (*aType) {
  case _C_ID:
  case _C_CLASS:
  case _C_SEL:
  case _C_PTR:
  case _C_CHARPTR:
    return &ffi_type_pointer;      

  case _C_CHR:
    return &ffi_type_schar;
    
  case _C_UCHR:
    return &ffi_type_uchar;
      
  case _C_SHT:
    return &ffi_type_sshort;
      
  case _C_USHT:
    return &ffi_type_ushort;
      
  case _C_INT:
    return &ffi_type_sint;
      
  case _C_UINT:
    return &ffi_type_uint;
      
  case _C_LNG:
    return &ffi_type_slong;
      
  case _C_ULNG:
    return &ffi_type_ulong;
      
  case _C_LNG_LNG:
    return &ffi_type_sint64;
    
  case _C_ULNG_LNG:
    return &ffi_type_uint64;
      
  case _C_FLT:
    return &ffi_type_float;
      
  case _C_DBL:
    return &ffi_type_double;

  case _C_VOID:
    return &ffi_type_void;
    
  default:
    fprintf(stderr, "Unknown Obj-C type: %s\n", aType);
    break;
  }

  return NULL;
}

@implementation CLInvocation

+(CLInvocation *) newInvocationWithMethodSignature:(CLMethodSignature *) signature
{
  return [[self alloc] initWithMethodSignature:signature];
}

-(id) initWithMethodSignature:(CLMethodSignature *) signature
{
  CLUInteger i;

  
  [super init];
  sig = [signature retain];
  target = nil;
  action = NULL;
  count = [sig numberOfArguments];
  if (count < 2)
    count = 2;
  if (!(values = malloc(sizeof(void *) * (count + 1))))
    [self error:@"Unable to allocate memory"];
  if (!(sizes = malloc(sizeof(CLUInteger) * (count + 1))))
    [self error:@"Unable to allocate memory"];
  sizes[0] = [sig sizeOfReturnValue];
  if (!(values[0] = malloc(sizes[0])))
    [self error:@"Unable to allocate memory"];
  for (i = 1; i <= count; i++) {
    sizes[i] = [sig sizeOfArgumentAtIndex:i-1];
    if (!(values[i] = malloc(sizes[i])))
      [self error:@"Unable to allocate memory"];
  }
  return self;
}

-(void) dealloc
{
  CLUInteger i;


  for (i = 0; i <= count; i++)
    free(values[i]);
  free(values);
  free(sizes);
  [sig release];
  [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef copy
#undef alloc
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLInvocation *aCopy;


#if DEBUG_RETAIN
  aCopy = [[[self class] alloc:file :line :retainer] initWithMethodSignature:sig];
#define alloc		alloc:__FILE__ :__LINE__ :self
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [[[self class] alloc] initWithMethodSignature:sig];
#endif
  aCopy->target = target;
  aCopy->action = action;
  return aCopy;
}
      
-(CLMethodSignature *) methodSignature
{
  return sig;
}

-(void) getArgument:(void *) buffer atIndex:(CLUInteger) index
{
  memcpy(buffer, values[index+1], sizes[index+1]);
  return;
}

-(void) getReturnValue:(void *) buffer
{
  memcpy(buffer, values[0], sizes[0]);
  return;
}

-(id) target
{
  return target;
}

-(SEL) selector
{
  return action;
}

-(id) objectValueForArgumentAtIndex:(CLUInteger) index
{
  id anObject = nil;
  int aType;
  const char *p;
  void *var;


  p = [sig getArgumentTypeAtIndex:index];
  aType = *p;
  var = values[index+1];
  switch (aType) {
  case _C_ID:
    anObject = *(id *) var;
    break;
  case _C_CHR:
    anObject = [CLNumber numberWithInt:*(char *) var];
    break;
  case _C_UCHR:
    anObject = [CLNumber numberWithUnsignedInt:*(unsigned char *) var];
    break;
  case _C_SHT:
    anObject = [CLNumber numberWithInt:*(short *) var];
    break;
  case _C_USHT:
    anObject = [CLNumber numberWithUnsignedInt:*(unsigned short *) var];
    break;
  case _C_INT:
    anObject = [CLNumber numberWithInt:*(int *) var];
    break;
  case _C_UINT:
    anObject = [CLNumber numberWithUnsignedInt:*(unsigned int *) var];
    break;
  case _C_LNG:
    anObject = [CLNumber numberWithLong:*(long *) var];
    break;
  case _C_ULNG:
    anObject = [CLNumber numberWithUnsignedLong:*(unsigned long *) var];
    break;
  case _C_LNG_LNG:
    anObject = [CLNumber numberWithLongLong:*(long long *) var];
    break;
  case _C_ULNG_LNG:
    anObject = [CLNumber numberWithUnsignedLongLong:*(unsigned long long *) var];
    break;
  case _C_FLT:
    anObject = [CLNumber numberWithFloat:*(float *) var];
    break;
  case _C_DBL:
    anObject = [CLNumber numberWithDouble:*(double *) var];
    break;
  case _C_CHARPTR:
    anObject = [CLString stringWithUTF8String:*(char **) var];
    break;
    
  case _C_CLASS:
  case _C_SEL:
  case _C_BFLD:
  case _C_VOID:
  case _C_UNDEF:
  case _C_PTR:
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

  return anObject;
}

-(void) setArgument:(void *) buffer atIndex:(CLUInteger) index
{
  memcpy(values[index+1], buffer, sizes[index+1]);
  return;
}

-(void) setReturnValue:(void *) buffer
{
  memcpy(values[0], buffer, sizes[0]);
  return;
}

-(void) setTarget:(id) anObject
{
  target = anObject;
  return;
}

-(void) setSelector:(SEL) aSelector
{
  action = aSelector;
  return;
}

-(void) invoke
{
  ffi_cif cif;
  ffi_type **arg_types;
  ffi_status status;
  ffi_arg result;
  int i, narg;
  IMP imp;


  if ((imp = [target methodFor:action])) {
    narg = [sig numberOfArguments];
    arg_types = calloc(narg, sizeof(ffi_type *));
    for (i = 0; i < narg; i++)
      arg_types[i] = CLFFITypeForObjCType([sig getArgumentTypeAtIndex:i]);
    
    status = ffi_prep_cif(&cif, FFI_DEFAULT_ABI, narg,
			  CLFFITypeForObjCType([sig methodReturnType]), arg_types);
    if (status != FFI_OK)
      [self error:@"Unable to invoke"];
    ffi_call(&cif, FFI_FN(imp), &result, &values[1]);
    [self setReturnValue:&result];
    free(arg_types);
  }
  else {
    /* No method which means we probably got here from swizzling out a
       fault on a CLGenericRecord which wanted to handle the
       forwardInvocation itself. In theory we shouldn't get into an
       infinite loop because no matter what class target is it isn't a
       CLFault anymore. */
    [target forwardInvocation:self];
  }

  return;
}

-(void) invokeWithTarget:(id) anObject
{
  [self setTarget:anObject];
  [self invoke];
  return;
}

@end
