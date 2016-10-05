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

#ifndef _CLPRIMITIVEOBJECT_H
#define _CLPRIMITIVEOBJECT_H

#import <ClearLake/CLRuntime.h>

#include <limits.h>

#define DEBUG_LEAK	0
#define DEBUG_RETAIN	0
#define DEBUG_RELEASE	0
#define DEBUG_ALLOC	0

typedef enum CLComparisonResult {
  CLOrderedAscending = -1,
  CLOrderedSame,
  CLOrderedDescending
} CLComparisonResult;

typedef int CLInteger;
typedef unsigned int CLUInteger;

#define CLIntegerMax    INT_MAX
#define CLIntegerMin    INT_MIN
#define CLUIntegerMax   UINT_MAX

enum {CLNotFound = CLUIntegerMax};

@class CLEditingContext;

typedef struct CLObjectReserved {
  CLUInteger retainCount;
  CLEditingContext *context;
  void *faultData;
} CLObjectReserved;

@class CLString, CLMethodSignature;

@protocol CLCopying
#if DEBUG_RETAIN
-(id) copy:(const char *) file :(int) line :(id) retainer;
#else
-(id) copy;
#endif
@end


@interface CLPrimitiveObject <CLCopying>
{
  Class isa;
}

+(id) alloc;
+(IMP) instanceMethodFor:(SEL) aSel;
+(void) poseAsClass:(Class) aClassObject;

-(id) init;
-(void) dealloc;

-(Class) class;
-(Class) superClass;
-(CLString *) className;
-(BOOL) isMemberOfClass:(Class) aClassObject;
-(BOOL) isKindOfClass:(Class) aClassObject;
-(BOOL) isFault;
-(BOOL) isClass;
-(BOOL) isInstance;

-(BOOL) respondsTo:(SEL) aSel;
-(struct objc_method_description *) descriptionForMethod:(SEL) aSel;
-(CLMethodSignature *) newMethodSignatureForSelector:(SEL) aSel;
-(void) doesNotRecognize:(SEL) aSel;
-(IMP) methodFor:(SEL) aSel;
-(id) perform:(SEL) aSel;
-(id) perform:(SEL) aSel with:(id) anObject;
-(id) perform:(SEL) aSel with:(id) anObject1 with:(id) anObject2;
-(void) error:(CLString *) aString, ...;
@end

@interface CLPrimitiveObject (CLRetaining)
-(id) retain;
-(void) release;
-(id) autorelease;
-(CLUInteger) retainCount;

#if DEBUG_RETAIN
+(id) alloc:(const char *) file :(int) line :(id) retainer;
-(id) retain:(const char *) file :(int) line :(id) retainer;
-(void) release:(const char *) file :(int) line :(id) retainer;
-(id) autorelease:(const char *) file :(int) line :(id) retainer;
#endif
@end

#if DEBUG_ALLOC
extern void CLPushAllocAllow(BOOL flag);
extern void CLPopAllocAllow();
#endif

#if DEBUG_LEAK && !defined(NO_OVERRIDE)
/* FIXME - just here trying to find memory leaks */

#include <stdio.h>
#ifndef __USE_ISOC99
#define __USE_ISOC99
#endif
#include <stdlib.h>
#include <string.h>

extern void *CLmalloc(size_t size, char *file, int line, id retainer);
extern void *CLcalloc(size_t nmemb, size_t size, char *file, int line, id retainer);
extern void *CLrealloc(void *ptr, size_t size, char *file, int line, id retainer);
extern void CLfree(void *ptr, char *file, int line, id retainer);
extern char *CLstrdup(const char *s, char *file, int line, id retainer);
extern char *CLstrndup(const char *s, size_t n, char *file, int line, id retainer);
extern int CLvasprintf(char **strp, const char *fmt, void *ap, char *file, int line, id retainer);

#define malloc(x)		CLmalloc(x, __FILE__, __LINE__, self)
#define calloc(x, y)		CLcalloc(x, y, __FILE__, __LINE__, self)
#define realloc(x, y)		CLrealloc(x, y, __FILE__, __LINE__, self)
#define free(x)			CLfree(x, __FILE__, __LINE__, self)
#define strdup(x)		CLstrdup(x, __FILE__, __LINE__, self)
#define strndup(x, y)		CLstrndup(x, y, __FILE__, __LINE__, self)
#define vasprintf(x, y, z)	CLvasprintf(x, y, z, __FILE__, __LINE__, self)

#endif /* DEBUG_LEAK && !defined(NO_OVERRIDE) */

#if DEBUG_RETAIN
#define alloc		alloc:__FILE__ :__LINE__ :self
#define copy		copy:__FILE__ :__LINE__ :self
#define retain		retain:__FILE__ :__LINE__ :self
#define release		release:__FILE__ :__LINE__ :self
#define autorelease	autorelease:__FILE__ :__LINE__ :self
#endif /* DEBUG_RETAIN */

extern void CLAddToCleanup(id anObject);
extern void CLCleanup();

#endif /* _CLPRIMITIVEOBJECT_H */
