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
#import "CLRuntime.h"
#import "CLGenericRecord.h"
#import "CLEditingContext.h"
#import "CLStringFunctions.h"
#import "CLStackString.h"
#import "CLRecordDefinition.h"
#import "CLRuntime.h"

#include <stdlib.h>
#include <wctype.h>
#include <string.h>
#include <ctype.h>
#include <dirent.h>

static CLHashTable *CLCachedClasses = NULL;

static IMP CLFindForwardFunction(SEL sel);

@implementation CLObject

+(void) load
{
  __objc_msg_forward = CLFindForwardFunction;
  return;
}

+(void) poseAsClass:(Class) aClassObject
{
#ifdef __GNU_LIBOBJC__
  [self error:@"Pose-as got borked!"];
#else
  class_pose_as(self, aClassObject);
#endif
}

-(void) dealloc
{
  void *buf;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);
  [reserved->context unregisterInstance:self];

  [super dealloc];
  return;
}

#if 0
-(int) returnType:(id) anObject forBinding:(CLString *) aBinding
{
  Method cMethod;
  const char *p, *enc;
  int aType = 0;
  Ivar iv;


  p = [aBinding UTF8String];
  cMethod = class_getInstanceMethod([self class], sel_getUid(p));
  if (cMethod) {
    enc = method_getTypeEncoding(cMethod);
    aType = *enc;
  }
  else {
    iv = class_getInstanceVariable([self class], p);
    if (iv) {
      enc = ivar_getTypeEncoding(iv);
      aType = *enc;
    }
  }
  
  return aType;
}
#endif

-(id) objectForIMP:(IMP) imp selector:(SEL) aSel returnType:(int) aType
{
  id anObject = nil;


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

-(id) objectForMethod:(CLString *) aMethod found:(BOOL *) found
{
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

  return [self objectForIMP:imp selector:aSel returnType:aType];
}

#ifdef __GNU_LIBOBJC__
-(void *) pointerForIvar:(const char *) anIvar type:(int *) aType
{
  void *var = NULL;
  const char *enc;
  Ivar iv;


  iv = class_getInstanceVariable([self class], anIvar);
  if (iv) {
    enc = ivar_getTypeEncoding(iv);
    *aType = *enc;
    var = ((void *) self) + ivar_getOffset(iv);
  }

  return var;
}
#else
-(void *) pointerForIvar:(const char *) anIvar type:(int *) aType
{
  Class aClass = [self class];
  void *var = NULL;
  struct objc_ivar_list* ivarList;
  int i;
  Ivar_t rtIvar;


  while (aClass) {
    ivarList = aClass->ivars;
    if (ivarList && ivarList->ivar_count > 0) {
      for (i = 0; i < ivarList->ivar_count; i++) {
	rtIvar = ivarList->ivar_list + i;
	if (!strcmp(anIvar, rtIvar->ivar_name)) {
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
#endif

-(id) objectForIvarPointer:(void *) var type:(int) aType
{
  id anObject = nil;


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

-(id) objectForIvar:(CLString *) anIvar found:(BOOL *) found
{
  int aType;
  void *var;


  *found = NO;
  
  if (!(var = [self pointerForIvar:[anIvar UTF8String] type:&aType]))
    return nil;

  *found = YES;

  return [self objectForIvarPointer:var type:aType];
}

-(CLString *) findFileForKey:(CLString *) aKey
{
  return [self findFileForKey:aKey directory:nil];
}

-(CLString *) findFileForKey:(CLString *) aKey directory:(CLString *) aDir
{
  CLString *aFilename = nil;
  CLRecordDefinition *recordDef;
  Class aClass;


  if (([self isKindOfClass:CLGenericRecordClass] &&
       (recordDef = [((CLGenericRecord *) self) recordDef])) ||
      (recordDef = [CLEditingContext recordDefinitionForClass:[self class]])) {
    CLString *cname, *rname, *tname;
    CLUInteger len;
    unistr evil;
    unistr *pstr;
    CLMutableStackString *evilStack;


    cname = [self className];
    len = [cname length];
    rname = [[recordDef recordClass] className];
    if (len < [rname length])
      len = [rname length];

    if ((tname = [recordDef databaseTable])) {
      pstr = alloca(sizeof(unistr));
      *pstr = CLCopyStackString(tname, 0);
      [((CLMutableString *) pstr) upperCamelCase];
      tname = (CLString *) pstr;
      if (len < [tname length])
	len = [tname length];
    }

    len += 1 + [aKey length];
    evil = CLNewStackString(len);
    evilStack = (CLMutableStackString *) &evil;
    [evilStack setString:cname];
    [evilStack appendString:@"_"];
    [evilStack appendString:aKey];

    aFilename = [CLPage findFile:evilStack directory:aDir];
    if (!aFilename) {
      [evilStack setString:rname];
      [evilStack appendString:@"_"];
      [evilStack appendString:aKey];
      aFilename = [CLPage findFile:evilStack directory:aDir];
      if (!aFilename) {
	[evilStack setString:tname];
	[evilStack appendString:@"_"];
	[evilStack appendString:aKey];
	aFilename = [CLPage findFile:evilStack directory:aDir];
      }
    }
  }

  if (!aFilename) {
    aClass = [self class];
    while (aClass && !(aFilename = [CLPage findFile:
					     [CLString stringWithFormat:@"%@_%@",
						       [aClass className], aKey]
					  directory:nil]))
      aClass = [aClass superClass];
  }
  
  return aFilename;
}

-(CLArray *) pagesForPrefix:(CLString *) aPrefix
{
  struct dirent *dp;
  DIR *dir;
  CLMutableArray *mArray, *pages;
  CLArray *extensions, *anArray;
  int i, j, k, l;
  CLString *aDir;
  const char *cname;
  unistr ustr;
  int clen;
  CLString *aString;


  ustr = CLCopyStackString(aPrefix, 1);
  [((CLMutableString *) &ustr) appendCharacter:'_'];
  cname = [((CLMutableString *) &ustr) UTF8String];
  clen = strlen(cname);
  pages = [[CLMutableArray alloc] init];
  
  extensions = [CLPage pageExtensions];
  mArray = [[CLMutableArray alloc] init];
  if ([CLDelegate respondsTo:@selector(additionalPageDirectories)]) {
    anArray = [CLDelegate additionalPageDirectories];
    for (i = 0, j = [anArray count]; i < j; i++)
      [mArray addObject:[CLAppPath stringByAppendingPathComponent:[anArray objectAtIndex:i]]];
  }
  [mArray addObject:CLAppPath];

  for (i = 0, j = [mArray count]; i < j; i++) {
    aDir = [mArray objectAtIndex:i];
    if (!(dir = opendir([aDir UTF8String])))
      continue;

    for (dp = readdir(dir); dp; dp = readdir(dir)) {
      if (!strncmp(dp->d_name, cname, clen)) {
	/* FIXME - don't convert every string just to check extensions */
	aString = [CLString stringWithUTF8String:dp->d_name];
	for (k = 0, l = [extensions count]; k < l; k++) {
	  if ([[aString pathExtension] isEqualToString:[extensions objectAtIndex:k]]) {
	    [pages addObject:[aDir stringByAppendingPathComponent:aString]];
	    break;
	  }
	}
      }
    }

    closedir(dir);
  }
  [mArray release];
  
  return [pages autorelease];
}
  
-(void *) cacheBindings
{
  CLMethodInfo *methods, *aMethod;
  CLIvarInfo *ivars, *anIvar;
  unsigned int i, count;
  CLCachedBinding *aBinding;
  CLHashTable *cache;
  unistr *ustr;
  CLString *aString;
  Class aClass;
  BOOL new;


  aClass = [self class];
#if 0
  fprintf(stderr, "Caching bindings for %s 0x%08x\n",
	  [[aClass className] UTF8String], (size_t) aClass);
#endif
  cache = CLHashTableAlloc(64);
  
  methods = CLGetMethods(aClass, &count);
  for (i = 0; i < count; i++) {
    aMethod = &methods[i];
    new = NO;
    if (aMethod->returnType == _C_VOID && aMethod->numArguments == 1 &&
	!strncmp(aMethod->name, "set", 3)) {
      /* This is probably a setter */
      aString = [[CLMutableString alloc] initWithUTF8String:aMethod->name+3];
      ustr = (unistr *) aString;
      ustr->str[0] = towlower(ustr->str[0]);

      if (!(aBinding =
	    CLHashTableDataForKey(cache, aString, [aString hash], @selector(isEqual:)))) {
	aBinding = malloc(sizeof(CLCachedBinding));
	aBinding->getter = NULL;
	aBinding->returnType = 0;
	aBinding->getType = aBinding->setType = 0;
	new = YES;
      }
      
      if (!aBinding->setType) {
	aBinding->setter = aMethod->imp;
	aBinding->setSel = aMethod->selector;
	aBinding->argumentType = aMethod->returnType;
	aBinding->setType = CLMethodBinding;
      }

      if (new)
	CLHashTableSetData(cache, aBinding, aString, [aString hash]);
      else
	[aString release];
    }
    else if (aMethod->returnType != _C_VOID && aMethod->numArguments == 0) {
      /* This is probably a getter */
      aString = [[CLString alloc] initWithUTF8String:aMethod->name];

      if (!(aBinding =
	    CLHashTableDataForKey(cache, aString, [aString hash], @selector(isEqual:)))) {
	aBinding = malloc(sizeof(CLCachedBinding));
	aBinding->setter = NULL;
	aBinding->argumentType = 0;
	aBinding->getType = aBinding->setType = 0;
	new = YES;
      }
      
      if (!aBinding->getType) {
	aBinding->getter = aMethod->imp;
	aBinding->getSel = aMethod->selector;
	aBinding->returnType = aMethod->returnType;
	aBinding->getType = CLMethodBinding;
      }

      if (new)
	CLHashTableSetData(cache, aBinding, aString, [aString hash]);
      else
	[aString release];
    }
  }
  free(methods);

  ivars = CLGetIvars(aClass, &count);
  for (i = 0; i < count; i++) {
    anIvar = &ivars[i];
    new = NO;
    aString = [[CLString alloc] initWithUTF8String:anIvar->name];
    if (!(aBinding = 
	  CLHashTableDataForKey(cache, aString, [aString hash], @selector(isEqual:)))) {
      aBinding = malloc(sizeof(CLCachedBinding));
      aBinding->getter = aBinding->setter = NULL;
      aBinding->getSel = aBinding->setSel = NULL;
      aBinding->getType = aBinding->setType = 0;
      aBinding->returnType = aBinding->argumentType = 0;
      new = YES;
    }

    if (!aBinding->getType) {
      aBinding->getter = (void *) anIvar->offset;
      aBinding->returnType = anIvar->type;
      aBinding->getType = CLIvarBinding;
    }

    if (!aBinding->setType) {
      aBinding->setter = (void *) anIvar->offset;
      aBinding->argumentType = anIvar->type;
      aBinding->setType = CLIvarBinding;
    }

    if (new)
      CLHashTableSetData(cache, aBinding, aString, [aString hash]);
    else
      [aString release];
  }
  free(ivars);
  
  {
    CLMutableArray *mArray;
    CLRecordDefinition *recordDef;
    CLArray *anArray;
    int i, j;
    CLString *aString;
    unistr binding;
    CLRange aRange;
    Class pClass;


    mArray = [[CLMutableArray alloc] init];
    pClass = aClass;
    while (pClass) {
      [mArray addObjectsFromArray:[self pagesForPrefix:[pClass className]]];
      pClass = [pClass superClass];
    }

    if (([self isKindOfClass:CLGenericRecordClass] &&
	 (recordDef = [((CLGenericRecord *) self) recordDef])) ||
	(recordDef = [CLEditingContext recordDefinitionForClass:[self class]])) {
      anArray = [self pagesForPrefix:[[recordDef databaseTable] upperCamelCaseString]];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aString = [anArray objectAtIndex:i];
	if (![mArray containsObject:aString])
	  [mArray addObject:aString];
      }
    }

    count = [mArray count];
    for (i = 0; i < count; i++) {
      aString = [mArray objectAtIndex:i];
      aRange = [aString rangeOfString:@"_" options:CLBackwardsSearch];
      binding = CLCloneStackString(aString);
      binding.str += CLMaxRange(aRange);
      binding.len -= CLMaxRange(aRange);
      aRange = [((CLString *) &binding) rangeOfString:@"."];
      binding.len = aRange.location;

      new = NO;
      if (!(aBinding = 
	    CLHashTableDataForKey(cache, (CLString *) &binding,
				  [((CLString *) &binding) hash], @selector(isEqual:)))) {
	aBinding = malloc(sizeof(CLCachedBinding));
	aBinding->getter = aBinding->setter = NULL;
	aBinding->getSel = aBinding->setSel = NULL;
	aBinding->getType = aBinding->setType = 0;
	aBinding->returnType = aBinding->argumentType = 0;
	new = YES;
      }

      if (!aBinding->getType) {
	aBinding->getter = [aString retain];
	aBinding->returnType = _C_ID;
	aBinding->getType = CLPageBinding;
      }

      if (new) {
	aString = [((CLString *) &binding) copy];
	CLHashTableSetData(cache, aBinding, aString, [aString hash]);
      }
    }

    [mArray release];
  }

  if (!CLCachedClasses)
    CLCachedClasses = CLHashTableAlloc(100);
  CLHashTableSetData(CLCachedClasses, cache, aClass, (size_t) aClass);
  
  return cache;
}
  
-(id) objectValueForBinding:(CLString *) aBinding
{
  BOOL found;


  return [self objectValueForBinding:aBinding found:&found];
}

-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found
{
  CLRange aRange;
  CLString *aString;
  id anObject = nil;
  CLPage *aPage;
  unistr stackStr;
  CLHashTable *cache;
  Class aClass;
  CLCachedBinding *cachedBinding;


  *found = NO;
  
  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (!aRange.length)
    aString = aBinding;
  else {
    stackStr = CLCloneStackString(aBinding);
    stackStr.len = aRange.location;
    aString = (CLString *) &stackStr;
  }

  aClass = [self class];
  if (!CLCachedClasses ||
      !(cache = CLHashTableDataForIdenticalKey(CLCachedClasses, aClass, (size_t) aClass)))
    cache = [self cacheBindings];

  if ((cachedBinding = CLHashTableDataForKey(cache, aString, [aString hash],
					     @selector(isEqual:)))) {
    switch (cachedBinding->getType) {
    case CLNoBinding:
      break;
      
    case CLMethodBinding:
      anObject = [self objectForIMP:cachedBinding->getter selector:cachedBinding->getSel
			 returnType:cachedBinding->returnType];
      *found = YES;
      break;

    case CLIvarBinding:
      anObject = [self objectForIvarPointer:((void *) self) + ((size_t) cachedBinding->getter)
				       type:cachedBinding->returnType];
      *found = YES;
      break;
      
    case CLPageBinding:
      aPage = [[CLPage alloc] initFromFile:cachedBinding->getter owner:self];
      anObject = [[CLBlock alloc] init];
      [anObject setContent:[aPage body]];
      [aPage release];
      [anObject autorelease];
      *found = YES;
      break;
      
    case CLFieldBinding:
    case CLRelationshipBinding:
      anObject = [((CLGenericRecord *) self) objectForCachedBinding:cachedBinding];
      *found = YES;
      break;
      
    default:
      [self error:@"Unknown binding type\n"];
      break;
    }
  }

  if (aRange.length) {
    stackStr = CLCloneStackString(aBinding);
    stackStr.str += CLMaxRange(aRange);
    stackStr.len -= CLMaxRange(aRange);
    anObject = [anObject objectValueForBinding:(CLString *) &stackStr found:found];
  }
  
  return anObject;
}

-(void) setObjectValue:(id) anObject atLocation:(void *) var type:(int) aType
{
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

  return;
}

-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField
{
  void *var;
  int aType;


  if ((var = [self pointerForIvar:[aField UTF8String] type:&aType]))
    [self setObjectValue:anObject atLocation:var type:aType];
  return;
}
  
-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding
{
  CLRange aRange;
  id anObject2;
  SEL sel;
  CLMethodSignature *aSig;
  IMP imp;
  unistr ustr;


  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length) {
    ustr = CLCloneStackString(aBinding);
    ustr.len = aRange.location;
    anObject2 = [self objectValueForBinding:(CLString *) &ustr];
    ustr = CLCloneStackString(aBinding);
    ustr.str += CLMaxRange(aRange);
    ustr.len -= CLMaxRange(aRange);
    [anObject2 setObjectValue:anObject forBinding:(CLString *) &ustr];
  }
  else {
    ustr = CLCopyStackString(aBinding, 4);
    [((CLMutableString *) &ustr) upperCamelCase];
    [((CLMutableString *) &ustr) appendString:@":"];
    [((CLMutableString *) &ustr) insertString:@"set" atIndex:0];
    sel = sel_getUid([((CLString *) &ustr) UTF8String]);
    if (![self respondsTo:sel])
      [self setObjectValue:anObject forVariable:aBinding];
    else {
      aSig = [self newMethodSignatureForSelector:sel];
      imp = [self methodFor:sel];
      switch (*[aSig getArgumentTypeAtIndex:2]) {
      case _C_ID:
	imp(self, sel, anObject);
	break;

      case _C_CHR:
      case _C_SHT:
      case _C_INT:
	imp(self, sel, [anObject intValue]);
	break;
      case _C_UCHR:
      case _C_USHT:
      case _C_UINT:
	imp(self, sel, [anObject unsignedIntValue]);
	break;
      case _C_LNG:
	imp(self, sel, [anObject longValue]);
	break;
      case _C_ULNG:
	imp(self, sel, [anObject unsignedLongValue]);
	break;
      case _C_LNG_LNG:
	imp(self, sel, [anObject longLongValue]);
	break;
      case _C_ULNG_LNG:
	imp(self, sel, [anObject unsignedLongLongValue]);
	break;
      
      case _C_FLT:
	imp(self, sel, [anObject doubleValue]);
	break;
      case _C_DBL:
	imp(self, sel, [anObject doubleValue]);
	break;
      }
      [aSig release];
    }
  }

  return;
}

-(void) setPrimitiveValue:(id) anObject forKey:(CLString *) aKey
{
  CLString *aString;
  SEL sel;
  CLMethodSignature *aSig;
  int aType;
  void *buf;
  id oldObject;
  

  if ((buf = [self pointerForIvar:[aKey UTF8String] type:&aType])) {
    oldObject = *(id *) buf;
    [self setObjectValue:anObject atLocation:buf type:aType];
    if (aType == _C_ID) {
      [oldObject release];
      [anObject retain];
    }
  }
  else {
    aString = [CLString stringWithFormat:@"set%@:", [aKey upperCamelCaseString]];
    sel = sel_getUid([aString UTF8String]);
    if ([self respondsTo:sel]) {
      aSig = [self newMethodSignatureForSelector:sel];
      if ((*[aSig getArgumentTypeAtIndex:2]) == _C_ID)
	[self perform:sel with:anObject];
      [aSig release];
    }
  }

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
  return (size_t) self;
}

-(BOOL) setIvarFromInvocation:(CLInvocation *) anInvocation
{
  int aType, aType2;
  const char *p;
  void *var;
  char *fieldName;


  p = sel_getName([anInvocation selector]);
  fieldName = strdup(p+3);
  fieldName[strlen(fieldName) - 2] = 0;
  fieldName[0] = tolower(fieldName[0]);
  var = [self pointerForIvar:fieldName type:&aType];
  free(fieldName);
  
  if (!var)
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


  /* Sometimes when the runtime is stacking up method calls on a
     CLFault that hasn't fired yet it thinks that the object doesn't
     respond to a selector that it will respond to after the fault has
     fired. */
  if ([self respondsTo:[anInvocation selector]]) {
    [anInvocation invoke];
    return;
  }
  
  aBinding = CLSelGetName([anInvocation selector]);
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
      [anInvocation getArgument:&anObject atIndex:2];
      if ([anObject isKindOfClass:CLControlClass] &&
	  [self replacePage:anObject selector:[anInvocation selector]]) {
	anObject = nil;
	[anInvocation setReturnValue:&anObject];
	return;
      }
    }
  }
  else if ((var = [self pointerForIvar:sel_getName([anInvocation selector]) type:&aType])) {
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

-(CLString *) json
{
  return [CLString stringWithFormat:@"\"<%@: 0x%08lx>\"", [[self class] className],
		   (unsigned long) self];
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

@implementation CLObject (CLWeb)

-(BOOL) replacePage:(id) sender filename:(CLString *) aFilename
{
  CLPage *aPage;


  aPage = [CLPage pageFromFile:aFilename owner:self];

  if ([sender isKindOfClass:CLElementClass] &&
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
  unistr ustr;



  oldTarget = [sender target];
  oldSel = [sender action];
  
  aString = CLSelGetName(aSel);
  ustr = CLCloneStackString(aString);
  ustr.len--;
  didReplace = [self replacePage:sender key:(CLString *) &ustr];

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

-(CLString *) urlForMethod:(SEL) aSelector
{
  CLControl *aControl;
  CLString *aURL;
  CLRange aRange;
  

  aControl = [[CLControl alloc] init];
  [aControl setTarget:self];
  [aControl setAction:aSelector];
  aURL = [aControl generateURL];
  [aControl release];

  aRange = [aURL rangeOfString:@"?"];
  if (aRange.length)
    aURL = [aURL substringToIndex:aRange.location];

  return [CLServerURL stringByAppendingPathComponent:aURL];
}

@end

CLString *CLPropertyListString(id anObject)
{
  CLString *aString;
  unichar *buf;
  int i, len;
#if DEBUG_LEAK
  id self = nil;
#endif


  if ([anObject isKindOfClass:CLStringClass]) {
    aString = anObject;
    len = [aString length];
    buf = malloc(sizeof(unichar) * len);
    [aString getCharacters:buf];
    for (i = 0; i < len && iswalnum(buf[i]); i++)
      ;
    if (!len || i < len)
      aString = [aString propertyListString];
    free(buf);
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


#if 0
  if (![receiver respondsTo:@selector(methodSignatureForSelector:)]) {
    fprintf(stderr, "Unknown object <%s> that does not inherit from CLObject\n",
	    [[[receiver class] className] UTF8String]);
    abort();
  }
#endif

  sig = [receiver newMethodSignatureForSelector:sel];
  anInvocation = [CLInvocation newInvocationWithMethodSignature:sig];
#if DEBUG_RETAIN
    id self = nil;
#endif
  [sig release];
  
  [anInvocation setTarget:receiver];
  [anInvocation setSelector:sel];
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

#ifndef __GNU_LIBOBJC__
/* ARGH! NASTY NASTY BUG IN gcc and/or GNU ObjC runtime!!!!!!! On
   __x86_64__ there's a problem with the va_start (__builtin_va_start)
   after the call to objc_msg_lookup. I haven't yet figured out a
   workaround other than to compile 32bit using the -m32 option.

   2012-12-03: gcc 4.6 doesn't have this problem which uses the
               __GNU_LIBOBJC__ define.
*/
#if __x86_64__
#error Due to a bug in gcc you MUST compile 32 bit with -m32
#endif
#endif /* __GNU_LIBOBJC__ */

void *CLForwardPointerMethod(id receiver, SEL sel, ...)
{
  va_list ap;
  CLInvocation *invoc = nil;
  void *ret = NULL;


  va_start(ap, sel);
  invoc = CLCreateInvocation(receiver, sel, ap);
  va_end(ap);
  if (![receiver respondsTo:@selector(forwardInvocation:)])
    [receiver error:@"Unable to forward message %s", sel_getName(sel)];
  [receiver forwardInvocation:invoc];
  [invoc getReturnValue:&ret];
#if DEBUG_RETAIN
    id self = nil;
#endif
  [invoc release];
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
#if DEBUG_RETAIN
    id self = nil;
#endif
  [invoc release];
  return ret;
}

static IMP CLFindForwardFunction(SEL sel)
{
  const char *t = ((struct objc_method_description *) sel)->types;


  if (t && (*t == _C_LNG_LNG || *t == _C_ULNG_LNG))
    return (IMP) CLForwardLongLongPointerMethod;
  
  return (IMP) CLForwardPointerMethod;
}

#if 0
/* Objective-C API functions */

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
#endif

/* Things to make using gdb easier */

const char *_NSPrintForDebugger(id anObject)
{
  const char *str;


  if ([anObject isKindOfClass:CLStringClass])
    str= [[anObject propertyListString] UTF8String];
  else if ([anObject respondsTo:@selector(description)])
    str = [[anObject description] UTF8String];
  else
    str = [[CLString stringWithFormat:@"<%s: 0x%08lx>", [[anObject class] className],
		     (unsigned long) anObject] UTF8String];
  return str;
}

CLString *_NSNewStringFromCString(const char *cString)
{
  CLString *aString;

  
  aString = [CLString stringWithUTF8String:cString];
  return aString;
}

#import "CLStandardContentImage.h"
#import "CLStandardContentCategory.h"
#import "CLFileType.h"

static void CLLinkerIsBorked()
{
  void CLShutupAboutUnused();


  [CLStandardContentImage linkerIsBorked];
  [CLStandardContentCategory linkerIsBorked];
  [CLFileType linkerIsBorked];
  CLShutupAboutUnused();
  return;
}

void CLShutupAboutUnused()
{
  CLLinkerIsBorked();
  return;
}
