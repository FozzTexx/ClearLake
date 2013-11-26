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

#ifdef __GNU_LIBOBJC__
#error This will not work with newer GNU runtime
#endif

#define NO_OVERRIDE	1

#define _GNU_SOURCE
#include <string.h>

#import "CLObject.h"
#import "CLAutoreleasePool.h"
#import "CLString.h"
#import "CLNumber.h"
#import "CLHashTable.h"
#import "CLInvocation.h"
#import "CLMethodSignature.h"
#import "CLBlock.h"
#import "CLPage.h"
#import "CLControl.h"
#import "CLManager.h"
#import "CLCookie.h"
#import "CLArray.h"
#import "CLObjCAPI.h"

#if DEBUG_LEAK || DEBUG_RETAIN
#import "CLReleaseTracker.h"
Class CLReleaseTrackerClass;
#endif

#include <stdlib.h>
#include <wctype.h>

#define sel_getName	sel_get_name
struct objc_method_list *CLClassNextMethodList(Class aClass, void **iterator);

static IMP CLFindForwardFunction(SEL sel);

/* FIXME - just for finding memory leaks */
int numobj2 = 0;
int memused = 0;
int printleak = 0, trackleak = 0;
CLHashTable *leakTable = nil;

static CLMutableArray *CLCleanupArray = nil;

#if 1
CL_INLINE void CLIncrementExtraRefCount(id anObject)
{
  (*((CLUInteger *)((void *) anObject - sizeof(CLUInteger))))++;
}

CL_INLINE BOOL CLDecrementExtraRefCountWasZero(id anObject)
{
  if (!(*((CLUInteger *)((void *) anObject - sizeof(CLUInteger)))))
    return YES;
  (*((CLUInteger *)((void *) anObject - sizeof(CLUInteger))))--;
  return NO;
}

CL_INLINE CLUInteger CLExtraRefCount(id anObject)
{
  return (*((CLUInteger *)((void *) anObject - sizeof(CLUInteger))));
}
#else
static CLHashTable *CLRefCountTable = nil;

CL_INLINE void CLIncrementExtraRefCount(id anObject)
{
  CLUInteger data;
  CLBucket *aBucket;


  if (!CLRefCountTable)
    CLRefCountTable = [[CLHashTable alloc] initWithSize:1024 * 1024 / sizeof(void *)];

  if ((aBucket = [CLRefCountTable bucketForKeyIdenticalTo:anObject
				hash:(CLUInteger) anObject])) {
    data = (CLUInteger) aBucket->data;
    data++;
    aBucket->data = (void *) data;
  }
  else {
    data = 1;
    [CLRefCountTable setData:(void *) data forKey:anObject hash:(CLUInteger) anObject];
  }

  return;
}

CL_INLINE BOOL CLDecrementExtraRefCountWasZero(id anObject)
{
  CLUInteger data;
  CLBucket *aBucket;


  if ((aBucket = [CLRefCountTable bucketForKeyIdenticalTo:anObject
				hash:(CLUInteger) anObject])) {
    data = (CLUInteger) aBucket->data;
    data--;
    aBucket->data = (void *) data;
    if (!data)
      [CLRefCountTable removeDataForKeyIdenticalTo:anObject hash:(CLUInteger) anObject];
    return NO;
  }

  return YES;
}

CL_INLINE CLUInteger CLExtraRefCount(id anObject)
{
  return (CLUInteger) [CLRefCountTable dataForKeyIdenticalTo:anObject
				     hash:(CLUInteger) anObject];
}
#endif

id CLCreateInstance(Class class)
{
  void *buf;
  id anObject;


  buf = calloc(1, class->instance_size + sizeof(CLUInteger));
  anObject = buf + sizeof(CLUInteger);
  anObject->class_pointer = class;
  return anObject;
}

id CLDisposeInstance(id object)
{
  void *buf;

  
  buf = object;
  buf -= sizeof(CLUInteger);
  free(buf);
  return nil;
}

@implementation CLObject

+(void) load
{
  __objc_msg_forward = CLFindForwardFunction;
  _objc_object_alloc = CLCreateInstance;
  _objc_object_dispose = CLDisposeInstance;
  return;
}

+(void) initialize
{
#if DEBUG_LEAK || DEBUG_RETAIN
  CLReleaseTrackerClass = [CLReleaseTracker class];
#endif
  return;
}

+(id) alloc
{
  return CLCreateInstance(self);
}

+(void) poseAsClass:(Class) aClassObject
{
  class_pose_as(self, aClassObject);
}

-(id) init
{
#if DEBUG_LEAK || DEBUG_RETAIN
  numobj2++;
  if (printleak) {
    int pl = printleak;
    printleak = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx init %s\n", (unsigned long) self, className);
    printleak = pl;
  }
  if (trackleak && self != leakTable) {
    if (!leakTable) {
      leakTable = [CLHashTable alloc];
      [leakTable init];
    }
    [leakTable setData:isa forKey:self hash:(CLUInteger) self];
  }
#endif
  return self;
}

-(void) dealloc
{
#if DEBUG_LEAK || DEBUG_RETAIN
  numobj2--;
  if (numobj2 < 0)
    [self error:@"We released more than we allocated!"];
  
  if (printleak) {
    int pl = printleak;
    printleak = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx dealloc %s\n", (unsigned long) self, className);
    printleak = pl;
  }
  if (trackleak) {
    Class val;


    val = [leakTable dataForKeyIdenticalTo:self hash:(CLUInteger) self];
    if (val != isa && (val != [CLUTF8String class] || isa != [CLString class]))
      [self error:@"My class changed!"];
    [leakTable removeDataForKeyIdenticalTo:self hash:(CLUInteger) self];
  }

  /* Not going to fully release, swizzling to another class that can't
     do anything and will abort if called */
  isa = CLReleaseTrackerClass;
#else
  CLDisposeInstance(self);
#endif

#if 0
  /* Just here to make the compiler warning go away */
  if (0)
    [(CLObject *) super dealloc];
#endif
  
  return;
}

-(id) copy
{
  id newObject;
  

  newObject = object_copy(self);
#if DEBUG_LEAK || DEBUG_RETAIN
  numobj2++;
  if (printleak){
    int pl = printleak;
    printleak = 0;
    const char *className = [[[newObject class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx copy %s\n", (unsigned long) newObject, className);
    printleak = pl;
  }
  if (trackleak) {
    if (!leakTable) {
      leakTable = [CLHashTable alloc];
      [leakTable init];
    }
    [leakTable setData:isa forKey:newObject hash:(CLUInteger) newObject];
  }
#endif
  return newObject;
}

-(CLMethodSignature *) methodSignatureForSelector:(SEL) aSel
{
  struct objc_method_description *md;
  CLMethodSignature *aSig;


  md = [self descriptionForMethod:aSel];
  if (md)
    aSig = [CLMethodSignature methodSignatureForDescription:md];
  else
    aSig = [CLMethodSignature methodSignatureForSelector:aSel];

  return aSig;
}

-(CLUInteger) retainCount
{
  return CLExtraRefCount(self) + 1;
}

-(int) returnType:(id) anObject forBinding:(CLString *) aBinding
{
  struct objc_class *aClass;
  void *iterator = NULL;
  struct objc_method_list* mlist;
  Method cMethod;
  int i;
  const char *p;
  int aType = 0;
  Ivar_t rtIvar;
  struct objc_ivar_list* ivarList;


  aClass = anObject->class_pointer;
  p = [aBinding UTF8String];

  while ((mlist = CLClassNextMethodList(aClass, &iterator))) {
    for (i = 0; i < mlist->method_count; i++) {
      cMethod = mlist->method_list[i];
      if (!strcmp(p, sel_get_name(cMethod.method_name))) {
	aType = *sel_get_type(cMethod.method_name);
	break;
      }
    }
    
    if (i < mlist->method_count)
      break;
  }

  if (!mlist) { /* No get method, see if there's an ivar with the same name */
    while (aClass) {
      ivarList = aClass->ivars;
      if (ivarList && ivarList->ivar_count > 0) {
	for (i = 0; i < ivarList->ivar_count; i++) {
	  rtIvar = ivarList->ivar_list + i;
	  if (!strcmp(p, rtIvar->ivar_name)) {
	    aType = *rtIvar->ivar_type;
	    break;
	  }
	}

	if (i < ivarList->ivar_count)
	  break;
      }

      aClass = aClass->super_class;
    }      
  }
  
  return aType;
}

-(id) objectForMethod:(CLString *) aMethod found:(BOOL *) found
{
  id anObject = nil;
  int aType = 0;
  SEL aSel;
  IMP imp;
  struct objc_method_description *md;


  *found = NO;
  
  aSel = sel_getUid([aMethod UTF8String]);
  if (![self respondsTo:aSel])
    return nil;
  
  md = [self descriptionForMethod:aSel];
  aType = *md->types;
  imp = [self methodFor:aSel];
  *found = YES;

  switch (aType) {
  case _C_ID:
    anObject = imp(self, aSel);
    break;
    
  case _C_CHR:
    anObject = [CLNumber numberWithInt:((char (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_UCHR:
    anObject = [CLNumber numberWithUnsignedInt:
			   ((unsigned char (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_SHT:
    anObject = [CLNumber numberWithInt:((short (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_USHT:
    anObject = [CLNumber numberWithUnsignedInt:
			   ((unsigned short (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_INT:
    anObject = [CLNumber numberWithInt:((int (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_UINT:
    anObject = [CLNumber numberWithUnsignedInt:
			   ((unsigned int (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_LNG:
    anObject = [CLNumber numberWithLong:((long (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_ULNG:
    anObject = [CLNumber numberWithUnsignedLong:
			   ((unsigned long (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_LNG_LNG:
    anObject = [CLNumber numberWithLongLong:
			   ((long long (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_ULNG_LNG:
    anObject = [CLNumber numberWithUnsignedLongLong:
			   ((unsigned long long (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_FLT:
    anObject = [CLNumber numberWithFloat:((float (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_DBL:
    anObject = [CLNumber numberWithDouble:((double (*) (id,SEL)) imp)(self, aSel)];
    break;
    
  case _C_CHARPTR:
    anObject = [CLString stringWithUTF8String:((char * (*) (id,SEL)) imp)(self, aSel)];
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

-(void *) pointerForIvar:(CLString *) anIvar type:(int *) aType
{
  Class aClass = [self class];
  void *var = NULL;
  struct objc_ivar_list* ivarList;
  int i;
  const char *p = [anIvar UTF8String];
  Ivar_t rtIvar;


  while (aClass) {
    ivarList = aClass->ivars;
    if (ivarList && ivarList->ivar_count > 0) {
      for (i = 0; i < ivarList->ivar_count; i++) {
	rtIvar = ivarList->ivar_list + i;
	if (!strcmp(p, rtIvar->ivar_name)) {
	  *aType = *rtIvar->ivar_type;
	  var = ((void *) self) + rtIvar->ivar_offset;
	  break;
	}
      }

      if (i < ivarList->ivar_count)
	break;
    }

    aClass = aClass->super_class;
  }

  return var;
}

-(id) objectForIvar:(CLString *) anIvar found:(BOOL *) found
{
  int aType;
  void *var;
  id anObject = nil;


  *found = NO;
  
  if (!(var = [self pointerForIvar:anIvar type:&aType]))
    return nil;

  *found = YES;
  
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

-(id) objectValueForBinding:(CLString *) aBinding
{
  BOOL found;


  return [self objectValueForBinding:aBinding found:&found];
}

-(CLString *) findFileForKey:(CLString *) aKey
{
  return [self findFileForKey:aKey directory:nil];
}

-(CLString *) findFileForKey:(CLString *) aKey directory:(CLString *) aDir
{
  CLString *aFilename = nil;
  id aClass = [self class];

  
  while (aClass && !(aFilename = [CLPage findFile:
					   [CLString stringWithFormat:@"%@_%@",
						     [aClass className], aKey]
					 directory:nil]))
    aClass = [aClass superClass];
  
  return aFilename;
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLRange aRange;
  CLString *aString;
  id anObject = nil;
  CLPage *aPage;


  *found = NO;
  
  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else
    aString = [aBinding substringToIndex:aRange.location];

  anObject = [self objectForMethod:aString found:found];
  if (!*found)
    anObject = [self objectForIvar:aString found:found];
  if (!*found) {
    aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
    if (!aRange.length && (aString = [self findFileForKey:aBinding]) &&
	(aPage = [[CLPage alloc] initFromFile:aString owner:self]  )) {
      *found = YES;
      anObject = [[CLBlock alloc] init];
      [anObject setValue:[aPage body]];
      [aPage release];
      [anObject autorelease];
    }
  }

  if (aRange.length)
    anObject = [anObject objectValueForBinding:
			   [aBinding substringFromIndex:CLMaxRange(aRange)]
			 found:found];
  
  return anObject;
}

-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField
{
  void *var;
  int aType;


  if ((var = [self pointerForIvar:aField type:&aType])) {
    switch (aType) {
    case _C_ID:
      /* FIXME - retain?? */
      *(id *) var = anObject;
      break;
    case _C_CHR:
    case _C_SHT:
    case _C_INT:
      *(int *) var = [anObject intValue];
      break;
    case _C_UCHR:
    case _C_USHT:
    case _C_UINT:
      *(unsigned int *) var = [anObject unsignedIntValue];
      break;
    case _C_LNG:
      *(long *) var = [anObject longValue];
      break;
    case _C_ULNG:
      *(unsigned long *) var = [anObject unsignedLongValue];
      break;

      /* For some reason a nil object can't set a long long or unsigned long long to 0 */
    case _C_LNG_LNG:
      if (anObject)
	*(long long *) var = [anObject longLongValue];
      else
	*(long long *) var = 0;
      break;
    case _C_ULNG_LNG:
      if (anObject)
	*(unsigned long long *) var = [anObject unsignedLongLongValue];
      else
	*(unsigned long long *) var = 0;
      break;
      
    case _C_FLT:
      *(float *) var = [anObject doubleValue];
      break;
    case _C_DBL:
      *(double *) var = [anObject doubleValue];
      break;
    }
  }

  return;
}

-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding
{
  CLRange aRange;
  CLString *aString;
  id anObject2;
  SEL sel;
  CLMethodSignature *aSig;


  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length) {
    aString = [aBinding substringToIndex:aRange.location];
    anObject2 = [self objectValueForBinding:aString];
    [anObject2 setObjectValue:anObject
	       forBinding:[aBinding substringFromIndex:CLMaxRange(aRange)]];
  }
  else {
    aString = [CLString stringWithFormat:@"set%@:", [aBinding upperCamelCaseString]];
    sel = sel_getUid([aString UTF8String]);
    if (![self respondsTo:sel])
      [self setObjectValue:anObject forVariable:aBinding];
    else {
      aSig = [self methodSignatureForSelector:sel];
      if ((*[aSig getArgumentTypeAtIndex:2]) == _C_ID)
	[self perform:sel with:anObject];
      else
	[self setObjectValue:anObject forVariable:aBinding];
    }
  }

  return;
}

-(BOOL) replacePage:(id) sender filename:(CLString *) aFilename
{
  CLPage *aPage;


  aPage = [CLPage pageFromFile:aFilename owner:self];

  if ([sender isKindOfClass:[CLElement class]] &&
      (![[aPage filename] isEqualToString:[[sender page] filename]] ||
       [[sender page] owner] != self)) {
    [sender setPage:aPage];
    return YES;
  }

  return NO;
}

-(BOOL) replacePage:(id) sender key:(CLString *) aKey
{
  CLString *aFilename;


  if ((aFilename = [self findFileForKey:aKey])) {
    [self replacePage:sender filename:aFilename];
    return YES;
  }
  
  return NO;
}

-(BOOL) replacePage:(id) sender selector:(SEL) aSel
{
  CLString *aString;
  BOOL didReplace;
  id oldTarget;
  SEL oldSel;
  CLControl *aControl;


  oldTarget = [sender target];
  oldSel = [sender action];
  
  aString = [CLString stringWithUTF8String:sel_getName(aSel)];
  aString = [aString substringToIndex:[aString length] - 1];
  didReplace = [self replacePage:sender key:aString];

  if (didReplace && oldTarget && oldSel && (oldTarget != self || oldSel != aSel)) {
    aControl = [[CLControl alloc] init];
    [aControl setTarget:self];
    [aControl setAction:aSel];

    if (CLDelegate && 
	[CLDelegate respondsTo:@selector(delegateEncodeSimpleURL:localQuery:)] &&
	(aString = [CLDelegate delegateEncodeSimpleURL:aControl localQuery:nil])) {
      aString = [CLWebName stringByAppendingFormat:@"/%@", aString];
      aString = [CLControl rewriteURL:aString];
      
      CLRedirectBrowser(aString, YES, 303);
      
      /* FIXME - should we really do an exit here? */
      exit(0);
    }

    [aControl release];
  }

  return didReplace;
}

-(void) redirectTo:(id) anObject selector:(SEL) aSel
{
  CLControl *aControl;
  CLString *aString;


  aControl = [[CLControl alloc] init];
  [aControl setTarget:anObject];
  [aControl setAction:aSel];
  aString = [aControl generateURL];
  [aControl release];
  CLRedirectBrowser(aString, YES, 303);
  return;
}

-(BOOL) isEqual:(id) anObject
{
  if (self == anObject)
    return YES;
  return NO;
}

-(CLUInteger) hash
{
  return (CLUInteger) self;
}

-(BOOL) setIvarFromInvocation:(CLInvocation *) anInvocation
{
  int aType, aType2;
  const char *p;
  void *var;
  CLString *fieldName;


  fieldName = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  fieldName = [[fieldName substringWithRange:CLMakeRange(3, [fieldName length]-4)]
		lowerCamelCaseString];
  
  if (!(var = [self pointerForIvar:fieldName type:&aType]))
    return NO;

  p = [[anInvocation methodSignature] getArgumentTypeAtIndex:2];
  aType2 = *p;
  if (aType == aType2) {
    switch (aType) {
    case _C_ID:
      {
	[anInvocation getArgument:var atIndex:2];
#if 0 /* FIXME - how do we know if it should be retained? */
	if ([self shouldRetain:fieldName]) {
	  [*(id *) var retain];
	  [anObject release];
	}
#endif
      }
      break;
    case _C_CHR:
    case _C_SHT:
    case _C_INT:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_UCHR:
    case _C_USHT:
    case _C_UINT:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_LNG:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_ULNG:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_LNG_LNG:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_ULNG_LNG:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_FLT:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_DBL:
      [anInvocation getArgument:var atIndex:2];
      break;
    case _C_CHARPTR:
      [anInvocation getArgument:var atIndex:2];
      break;
    }
  }
  else
    [self error:@"Type mismatch in %@ method %s", [[self class] className],
	  sel_getName([anInvocation selector])];

  return YES;
}

-(void) forwardInvocation:(CLInvocation *) anInvocation
{
  void *var;
  int aType;
  CLString *aBinding;
  CLRange aRange;
  id anObject;

  
  aBinding = [CLString stringWithUTF8String:sel_getName([anInvocation selector])];
  aRange = [aBinding rangeOfString:@":" options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length && [[anInvocation methodSignature] numberOfArguments] == 3) {
    if ([aBinding hasPrefix:@"set"]) {
      if ([self setIvarFromInvocation:anInvocation]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
    else if (*[[anInvocation methodSignature] getArgumentTypeAtIndex:2] == _C_ID) {
      aBinding = [aBinding substringToIndex:aRange.location];
      [anInvocation getArgument:&anObject atIndex:2];
      if ([self replacePage:anObject key:aBinding]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
  }
  else if ((var = [self pointerForIvar:[CLString stringWithUTF8String:
						   sel_getName([anInvocation selector])]
			type:&aType])) {
    [anInvocation setReturnValue:var];
    return;
  }
  
  [self doesNotRecognize:[anInvocation selector]];
  return;
}

-(CLString *) description
{
  return [CLString stringWithFormat:@"<%@: 0x%08lx>", [[self class] className],
		   (unsigned long) self];
}

#if DEBUG_RETAIN
#undef retain
#undef release
#undef autorelease
#endif

-(id) retain
{
  CLIncrementExtraRefCount(self);
  return self;
}

-(void) release
{
  if (CLDecrementExtraRefCountWasZero(self)) {
#if 0 || DEBUG_LEAK
    if ([CLAutoreleasePool hasObject:self])
      [self error:@"Double release!"];
#endif
    [self dealloc];
  }
  return;
}

-(id) autorelease
{
  [CLAutoreleasePool addObject:self];
  CLDecrementExtraRefCountWasZero(self);
  return self;
}

#if DEBUG_RETAIN
-(id) retain:(const char *) file :(int) line
{
  if (printleak) {
    int pl = printleak;
    printleak = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx retain %s - %s:%i %i\n",
	    (unsigned long) self, className, file, line, [self retainCount]);
    printleak = pl;
  }
  return [self retain];
}

-(void) release:(const char *) file :(int) line
{
  if (printleak) {
    int pl = printleak;
    printleak = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx release %s - %s:%i %i\n",
	    (unsigned long) self, className, file, line, [self retainCount]);
    printleak = pl;
  }
  [self release];
  return;
}

-(id) autorelease:(const char *) file :(int) line
{
  if (printleak) {
    int pl = printleak;
    printleak = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx autorelease %s - %s:%i\n",
	    (unsigned long) self, className, file, line);
    printleak = pl;
  }
  return [self autorelease];
}
#endif

/* Stuff we used to get from Object */

+(IMP) instanceMethodFor:(SEL) aSel
{
  return method_get_imp(class_get_instance_method(self, aSel));
}

-(void) error:(CLString *) aString, ...
{
  va_list ap;


  if (aString) {
    va_start(ap, aString);
    aString = [[[CLString alloc] initWithFormat:aString arguments:ap] autorelease];
    va_end(ap);
  }
  else
    aString = @"";

  aString = [CLString stringWithFormat:@"error: %s (%s)\n%@\n",
		      object_get_class_name(self),
		      object_is_instance(self) ? "instance" : "class",
		      aString];
  objc_error(self, OBJC_ERR_UNKNOWN, [aString UTF8String]);
  return;
}

-(void) doesNotRecognize:(SEL) aSel
{
  [self error:@"%s does not recognize %s",
	object_get_class_name(self), sel_get_name(aSel)];
  return;
}

-(id) perform:(SEL) aSel
{
  IMP msg = objc_msg_lookup(self, aSel);

  
  if (!msg)
    [self error:@"invalid selector passed to %s", sel_get_name(_cmd)];
  return (*msg)(self, aSel);
}

-(id) perform:(SEL) aSel with:(id) anObject
{
  IMP msg = objc_msg_lookup(self, aSel);

  
  if (!msg)
    [self error:@"invalid selector passed to %s", sel_get_name(_cmd)];
  return (*msg)(self, aSel, anObject);
}

-(id) perform:(SEL) aSel with:(id) anObject1 with:(id) anObject2
{
  IMP msg = objc_msg_lookup(self, aSel);

  
  if (!msg)
    [self error:@"invalid selector passed to %s", sel_get_name(_cmd)];
  return (*msg)(self, aSel, anObject1, anObject2);
}

-(struct objc_method_description *) descriptionForMethod:(SEL) aSel
{
  return (struct objc_method_description *)
           (object_is_instance(self) ?
	    class_get_instance_method(self->isa, aSel) :
	    class_get_class_method(self->isa, aSel));
}

-(IMP) methodFor:(SEL) aSel
{
  return method_get_imp(object_is_instance(self) ?
			class_get_instance_method(self->isa, aSel) :
			class_get_class_method(self->isa, aSel));
}

-(BOOL) respondsTo:(SEL) aSel
{
  return !!(object_is_instance(self) ?
	    class_get_instance_method(self->isa, aSel) :
	    class_get_class_method(self->isa, aSel));
}

-(BOOL) isMemberOfClass:(Class) aClassObject
{
  return self->isa == aClassObject;
}

-(BOOL) isKindOfClass:(Class) aClassObject
{
  Class class;
  

  for (class = self->isa; class; class = class_get_super_class(class))
    if (class == aClassObject)
      return YES;
  return NO;
}

-(Class) class
{
  return object_get_class(self);
}

-(Class) superClass
{
  return object_get_super_class(self);
}

-(CLString *) className
{
  static CLHashTable *classNameTable = nil;
  CLString *aString;
  

  if (!(aString = [classNameTable dataForKeyIdenticalTo:isa hash:(CLUInteger) isa])) {
    if (!classNameTable)
      classNameTable = [[CLHashTable alloc] init];
    aString = [[CLString alloc] initWithUTF8String:object_get_class_name(self)];
    [classNameTable setData:aString forKey:isa hash:(CLUInteger) isa];
  }
  
  return aString;
}

-(id) read:(CLStream *) stream
{
  return self;
}

-(void) write:(CLStream *) stream
{
  return;
}

@end

CLString *CLPropertyListString(id anObject)
{
  CLString *aString;
  unichar *buf;
  int i, len;


  if ([anObject isKindOfClass:[CLString class]]) {
    aString = anObject;
    if ((len = [aString length])) {
      buf = malloc(sizeof(unichar) * len);
      [aString getCharacters:buf];
      for (i = 0; i < len && iswalnum(buf[i]); i++)
	;
      if (!len || i < len)
	aString = [aString propertyListString];
      free(buf);
    }
  }
  else if ([anObject respondsTo:@selector(propertyList)])
    aString = [anObject propertyList];
  else
    aString = [anObject description];

  return aString;
}

CLString *CLJSONString(id anObject)
{
  CLString *aString;


  if ([anObject respondsTo:@selector(json)])
    aString = [anObject json];
  else
    aString = [anObject description];

  return aString;
}

CLInvocation *CLCreateInvocation(id receiver, SEL sel, va_list ap)
{
  CLInvocation *anInvocation;
  CLMethodSignature *sig;
  int i, j;
  const char *type;


  if (![receiver respondsTo:@selector(methodSignatureForSelector:)]) {
    fprintf(stderr, "Unknown object <%s> that does not inherit from CLObject\n",
	    [[[receiver class] className] UTF8String]);
    abort();
  }
    
  anInvocation = [CLInvocation invocationWithMethodSignature:
				 [receiver methodSignatureForSelector:sel]];
  [anInvocation setTarget:receiver];
  [anInvocation setSelector:sel];
  sig = [anInvocation methodSignature];
  j = [sig numberOfArguments];
  [anInvocation setArgument:&receiver atIndex:0];
  [anInvocation setArgument:&sel atIndex:1];
  
  for (i = 2; i < j; i++) {
    type = [sig getArgumentTypeAtIndex:i];
    switch (*type) {
    case _C_ID:
      {
	id anObject = va_arg(ap, id);
	[anInvocation setArgument:&anObject atIndex:i];
      }
      break;
      
    case _C_CLASS:
      break;
      
    case _C_SEL:
      {
	SEL aSel = va_arg(ap, SEL);
	[anInvocation setArgument:&aSel atIndex:i];
      }
      break;
      
    case _C_CHR:
      {
	int aChar = va_arg(ap, int);
	[anInvocation setArgument:&aChar atIndex:i];
      }
      break;
      
    case _C_UCHR:
      {
	int aChar = va_arg(ap, int);
	[anInvocation setArgument:&aChar atIndex:i];
      }
      break;
      
    case _C_SHT:
      {
	int aShort = va_arg(ap, int);
	[anInvocation setArgument:&aShort atIndex:i];
      }
      break;
      
    case _C_USHT:
      {
	int aShort = va_arg(ap, int);
	[anInvocation setArgument:&aShort atIndex:i];
      }
      break;
      
    case _C_INT:
      {
	int anInt = va_arg(ap, int);
	[anInvocation setArgument:&anInt atIndex:i];
      }
      break;
      
    case _C_UINT:
      {
	unsigned int anInt = va_arg(ap, unsigned int);
	[anInvocation setArgument:&anInt atIndex:i];
      }
      break;
      
    case _C_LNG:
      {
	long int anInt = va_arg(ap, long int);
	[anInvocation setArgument:&anInt atIndex:i];
      }
      break;
      
    case _C_ULNG:
      {
	unsigned long int anInt = va_arg(ap, unsigned long int);
	[anInvocation setArgument:&anInt atIndex:i];
      }
      break;
      
    case _C_LNG_LNG:
      {
	long long int anInt = va_arg(ap, long long int);
	[anInvocation setArgument:&anInt atIndex:i];
      }
      break;
      
    case _C_ULNG_LNG:
      {
	unsigned long long int anInt = va_arg(ap, unsigned long long int);
	[anInvocation setArgument:&anInt atIndex:i];
      }
      break;
      
    case _C_FLT:
      {
	double aFloat = va_arg(ap, double);
	[anInvocation setArgument:&aFloat atIndex:i];
      }
      break;
      
    case _C_DBL:
      {
	double aDouble = va_arg(ap, double);
	[anInvocation setArgument:&aDouble atIndex:i];
      }
      break;
      
    case _C_PTR:
    case _C_CHARPTR:
      {
	void *aPointer = va_arg(ap, void *);
	[anInvocation setArgument:&aPointer atIndex:i];
      }
      break;
    }
  }
  
  return anInvocation;
}

/* ARGH! NASTY NASTY BUG IN gcc and/or GNU ObjC runtime!!!!!!! On
   __x86_64__ there's a problem with the va_start (__builtin_va_start)
   after the call to objc_msg_lookup. I haven't yet figured out a
   workaround other than to compile 32bit using the -m32 option. */
#if __x86_64__
#error Due to a bug in gcc you MUST compile 32 bit with -m32
#endif

void *CLForwardPointerMethod(id receiver, SEL sel, ...)
{
  va_list ap;
  CLInvocation *invoc = nil;
  void *ret = NULL;


  va_start(ap, sel);
  invoc = CLCreateInvocation(receiver, sel, ap);
  va_end(ap);
  [receiver forwardInvocation:invoc];
  [invoc getReturnValue:&ret];
  return ret;
}

unsigned long long CLForwardLongLongPointerMethod(id receiver, SEL sel, ...)
{
  va_list ap;
  CLInvocation *invoc = nil;
  unsigned long long ret = 0;


  va_start(ap, sel);
  invoc = CLCreateInvocation(receiver, sel, ap);
  va_end(ap);
  [receiver forwardInvocation:invoc];
  [invoc getReturnValue:&ret];
  return ret;
}

static IMP CLFindForwardFunction(SEL sel)
{
  const char *t = sel->sel_types;


  if (t && (*t == _C_LNG_LNG || *t == _C_ULNG_LNG))
    return (IMP) CLForwardLongLongPointerMethod;
  
  return (IMP) CLForwardPointerMethod;
}

/* Objective-C API functions */

void CLObjectSetInstanceVariable(id anObject, const char *name, void *data)
{
  struct objc_ivar_list *ivars;
  int i;
  void *p;
  struct objc_class *aClass;


  aClass = anObject->class_pointer;

  while (aClass) {
    ivars = aClass->ivars;

    if (ivars) {
      for (i = 0; i < ivars->ivar_count; i++) {
	if (!strcmp(ivars->ivar_list[i].ivar_name, name)) {
	  p = ((void *) anObject) + ivars->ivar_list[i].ivar_offset;
	  *(id *) p = (id) data;
	  return;
	}
      }
    }
    aClass = aClass->super_class;
  }

  return;
}

struct objc_method_list *CLClassNextMethodList(Class aClass, void **iterator)
{
  if (!*iterator)
    *iterator = aClass->methods;
  else
    *iterator = (*(struct objc_method_list **) iterator)->method_next;

  return *iterator;
}

void CLShowIvars(Class klass)
{
  int i;
  Ivar_t rtIvar;
  struct objc_ivar_list* ivarList;


  while (klass) {
    ivarList = klass->ivars;
    if (ivarList!= NULL && (ivarList->ivar_count>0)) {
      printf ("  Instance Variabes:\n");
      for ( i = 0; i < ivarList->ivar_count; ++i ) {
	rtIvar = (ivarList->ivar_list + i);
	printf ("    name: '%s'  encodedType: '%s'  offset: %d\n",
		rtIvar->ivar_name, rtIvar->ivar_type, rtIvar->ivar_offset);
      }
    }

    klass = klass->super_class;
  }
}

void CLShowMethodGroups(Class klass)
{
  void *iterator = 0;     // Method list (category) iterator
  struct objc_method_list* mlist;
  Method currMethod;
  int  j;
  while ((mlist = CLClassNextMethodList(klass, &iterator))) {
    printf ("  Methods:\n");
    for ( j = 0; j < mlist->method_count; ++j ) {
      currMethod = mlist->method_list[j];
      printf ("    method: '%s'  encodedReturnTypeAndArguments: '%s'\n",
	      sel_get_name(currMethod.method_name), sel_get_type(currMethod.method_name));
    }
  }
}

/* FIXME - just for finding memory leaks */

int numblocks = 0, maxblocks = 0, marker = 0;
void **blocks = NULL;
int *sizes = NULL;
int *markers = NULL;

#include <malloc.h>

static void *(*CLoldMallocHook)(size_t, const void *);
static void *(*CLoldReallocHook)(void *ptr, size_t size, const void *caller);
static void (*CLoldFreeHook)(void *ptr, const void *caller);

void *CLoldMalloc(size_t size)
{
  void *ptr, *saveHook;
  

  saveHook = __malloc_hook;
  __malloc_hook = CLoldMallocHook;
  ptr = malloc(size);
  __malloc_hook = saveHook;
  return ptr;
}

void *CLoldRealloc(void *ptr, size_t size)
{
  void *saveHook;
  

  saveHook = __realloc_hook;
  __realloc_hook = CLoldReallocHook;
  ptr = realloc(ptr, size);
  __realloc_hook = saveHook;
  return ptr;
}
  
void CLsaveBlock(void *ptr, size_t size, char *file, int line)
{
  numblocks++;
  if (numblocks > maxblocks) {
    maxblocks++;
  
    if (!blocks) {
      blocks = CLoldMalloc(sizeof(void *));
      sizes = CLoldMalloc(sizeof(int));
      markers = CLoldMalloc(sizeof(int));
    }
    else {
      blocks = CLoldRealloc(blocks, sizeof(void *) * maxblocks);
      sizes = CLoldRealloc(sizes, sizeof(int) * maxblocks);
      markers = CLoldRealloc(markers, sizeof(int) * maxblocks);
    }
  }
  
  blocks[numblocks-1] = ptr;
  sizes[numblocks-1] = size;
  markers[numblocks-1] = marker;
  if (printleak && file && line)
    fprintf(stdout, "0x%lx %s %i malloc %i\n", (unsigned long) ptr, file, line, size);
  return;
}

int CLfreeBlock(void *ptr, char *file, int line)
{
  int i, size = -1;


  if (!ptr)
    return 0;
  
  for (i = 0; i < numblocks; i++)
    if (blocks[i] == ptr) {
      size = sizes[i];
      numblocks--;
      memmove(&blocks[i], &blocks[i+1], (numblocks - i) * sizeof(void *));
      memmove(&sizes[i], &sizes[i+1], (numblocks - i) * sizeof(int));
      memmove(&markers[i], &markers[i+1], (numblocks - i) * sizeof(int));
      break;
    }

  if (printleak && file && line) {
    if (size < 0) {
      fprintf(stdout, "0x%lx never allocated\n", (unsigned long) ptr);
      size = 0;
    }
    else
      fprintf(stdout, "0x%lx %s free %i\n", (unsigned long) ptr, file, line);
  }

  return size;
}

int CLfindMarker(int m, int start)
{
  int i;


  for (i = start; i < numblocks; i++)
    if (markers[i] == m)
      return i;
  return -1;
}

void *CLmalloc(size_t size, char *file, int line)
{
  void *ptr;


  if (!size)
    fprintf(stdout, "%s %i attempt to malloc zero bytes\n", file, line);
  
  ptr = CLoldMalloc(size);
  memused += size;
  CLsaveBlock(ptr, size, file, line);
  return ptr;
}

void *CLcalloc(size_t nmemb, size_t size, char *file, int line)
{
  void *ptr, *saveHook;
  

  if (!size || !nmemb)
    fprintf(stdout, "%s %i attempt to calloc zero bytes\n", file, line);

  saveHook = __malloc_hook;
  __malloc_hook = CLoldMallocHook;
  ptr = calloc(nmemb, size);
  __malloc_hook = saveHook;
  memused += nmemb * size;
  CLsaveBlock(ptr, nmemb * size, file, line);
  return ptr;
}

void *CLrealloc(void *ptr, size_t size, char *file, int line)
{
  memused -= CLfreeBlock(ptr, file, line);
  memused += size;
  ptr = CLoldRealloc(ptr, size);
  CLsaveBlock(ptr, size, file, line);
  return ptr;
}

void CLfree(void *ptr, char *file, int line)
{
  void *saveHook;
  

  memused -= CLfreeBlock(ptr, file, line);
  saveHook = __free_hook;
  __free_hook = CLoldFreeHook;
  free(ptr);
  __free_hook = saveHook;
  return;
}

#undef strdup
#undef strndup
#undef vasprintf

char *CLstrdup(const char *s, char *file, int line)
{
  char *ptr;
  int size;


  if (!s)
    fprintf(stdout, "%s %i attempt to duplicate null string\n", file, line);
  
  ptr = strdup(s);
  size = strlen(ptr) + 1;
  memused += size;
  CLsaveBlock(ptr, size, file, line);
  return ptr;
}

char *CLstrndup(const char *s, size_t n, char *file, int line)
{
  char *ptr;
  int size;


  if (!s)
    fprintf(stdout, "%s %i attempt to duplicate null string\n", file, line);
  
  ptr = strndup(s, n);
  size = strlen(ptr) + 1;
  memused += size;
  CLsaveBlock(ptr, size, file, line);
  return ptr;
}

int CLvasprintf(char **strp, const char *fmt, va_list ap, char *file, int line)
{
  int size;


  size = vasprintf(strp, fmt, ap) + 1;
  memused += size;
  CLsaveBlock(*strp, size, file, line);
  return size;
}

#if DEBUG_LEAK
static void *(*CLoldMemalignHook)(size_t alignment, size_t size, const void *caller);

static void *CLmallocHook(size_t size, const void *caller)
{
  return CLmalloc(size, NULL, 0);
}

static void *CLreallocHook(void *ptr, size_t size, const void *caller)
{
  return CLrealloc(ptr, size, NULL, 0);
}

static void *CLmemalignHook(size_t alignment, size_t size, const void *caller)
{
  void *ptr, *saveHook;
  

  saveHook = __memalign_hook;
  __memalign_hook = CLoldMemalignHook;
  ptr = memalign(alignment, size);
  __memalign_hook = saveHook;
  memused += size;
  CLsaveBlock(ptr, size, NULL, 0);
  return ptr;
}

static void CLfreeHook(void *ptr, const void *caller)
{
  CLfree(ptr, NULL, 0);
  return;
}

static void CLmallocInit(void)
{
  CLoldMallocHook = __malloc_hook;
  __malloc_hook = CLmallocHook;
  CLoldReallocHook = __realloc_hook;
  __realloc_hook = CLreallocHook;
  CLoldMemalignHook = __memalign_hook;
  __memalign_hook = CLmemalignHook;
  CLoldFreeHook = __free_hook;
  __free_hook = CLfreeHook;
  return;
}

void (*__malloc_initialize_hook) (void) = CLmallocInit;
#endif

void CLAddToCleanup(id anObject)
{
  if (!CLCleanupArray)
    CLCleanupArray = [[CLMutableArray alloc] init];
  [CLCleanupArray addObject:anObject];
  [anObject release];
  return;
}

void CLCleanup()
{
  [CLCleanupArray release];
  CLCleanupArray = nil;
#if 0
  [CLRefCountTable release];
  CLRefCountTable = nil;
#endif
  
  if ([leakTable count]) {
    id *data;
    int i, j;


    fprintf(stdout, "\n------------ Leaked Objects ------------\n");
    j = [leakTable count];
    data = malloc(sizeof(id) * j);
    [leakTable getKeys:data];
    for (i = 0; i < j; i++)
      fprintf(stdout, "0x%lx %s\n", (unsigned long) data[i],
	      [[[data[i] class] className] UTF8String]);
    free(data);
  }
  [leakTable release];

  if (numblocks) {
    int i;


    fprintf(stdout, "\n------------ Leaked Memory ------------\n");
    for (i = 0; i < numblocks; i++)
      fprintf(stdout, "0x%lx %i %i\n", (unsigned long) blocks[i], sizes[i], markers[i]);
  }
  
  return;
}

/* Things to make using gdb easier */

const char *_NSPrintForDebugger(id anObject)
{
  if ([anObject isKindOfClass:[CLString class]])
    return [[anObject propertyListString] UTF8String];
  else if ([anObject respondsTo:@selector(description)])
    return [[anObject description] UTF8String];

  return [[CLString stringWithFormat:@"<%s: 0x%08lx>", [[anObject class] className],
		    (unsigned long) anObject] UTF8String];
}

CLString *_NSNewStringFromCString(const char *cString)
{
  return [CLString stringWithUTF8String:cString];
}
