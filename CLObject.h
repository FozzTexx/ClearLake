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

#ifndef _CLOBJECT_H
#define _CLOBJECT_H

#define DEBUG_LEAK	0
#define DEBUG_RETAIN	0

@class CLString, CLInvocation, CLData, CLStream;

#include <limits.h>
#include <objc/objc.h>

#define CL_URLDATA	@"CLurldata"
#define CL_URLSEL	@"CLurlsel"
#define CL_URLCLASS	@"CLurlclass"

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

typedef struct CLObjectReserved {
  CLUInteger retainCount;
} CLObjectReserved;

@protocol CLObject
-(id) retain;
-(void) release;
-(id) autorelease;
-(CLUInteger) retainCount;

#if DEBUG_RETAIN
-(id) retain:(const char *) file :(int) line;
-(void) release:(const char *) file :(int) line;
-(id) autorelease:(const char *) file :(int) line;
#endif
@end

@protocol CLCopying
-(id) copy;
@end

@protocol CLMutableCopying
-(id) mutableCopy;
@end

@protocol CLPropertyList
-(CLString *) propertyList;
-(CLString *) json;
#if 0
-(CLData *) bEncode;
-(CLString *) xml;
#endif
@end

@protocol CLArchiving
-(id) read:(CLStream *) stream;
-(void) write:(CLStream *) stream;
@end

@interface CLObject <CLObject, CLArchiving, CLCopying>
{
  Class isa;
}

+(void) initialize;
+(id) alloc;
+(void) poseAsClass:(Class) aClassObject;

-(id) init;
-(void) dealloc;

-(Class) class;
-(Class) superClass;
-(CLString *) className;
-(CLUInteger) hash;
-(BOOL) isEqual:(id) anObject;
-(BOOL) isKindOfClass:(Class) aClassObject;
-(BOOL) isMemberOfClass:(Class) aClassObject;
-(BOOL) isInstance;
-(BOOL) respondsTo:(SEL) aSel;
+(IMP) instanceMethodFor:(SEL) aSel;
-(IMP) methodFor:(SEL) aSel;
-(struct objc_method_description *) descriptionForMethod:(SEL) aSel;
-(id) perform:(SEL) aSel;
-(id) perform:(SEL) aSel with:(id) anObject;
-(id) perform:(SEL) aSel with:(id) anObject1 with:(id) anObject2;
-(void) doesNotRecognize:(SEL) aSel;
-(void) error:(CLString *) aString, ...;

-(void *) pointerForIvar:(const char *) anIvar type:(int *) aType;
-(id) objectForMethod:(CLString *) aMethod found:(BOOL *) found;
-(id) objectForIvar:(CLString *) anIvar found:(BOOL *) found;
-(CLString *) findFileForKey:(CLString *) aKey;
-(CLString *) findFileForKey:(CLString *) aKey directory:(CLString *) aDir;
-(id) objectValueForBinding:(CLString *) aBinding;
-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found;
-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField;
-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding;
-(BOOL) replacePage:(id) sender filename:(CLString *) aFilename;
-(BOOL) replacePage:(id) sender key:(CLString *) aKey;
-(BOOL) replacePage:(id) sender selector:(SEL) aSel;
-(void) redirectTo:(id) anObject selector:(SEL) aSel;
-(void) forwardInvocation:(CLInvocation *) anInvocation;

@end

extern CLString *CLPropertyListString(id anObject);
extern CLString *CLJSONString(id anObject);


#if DEBUG_LEAK && !defined(NO_OVERRIDE)
/* FIXME - just here trying to find memory leaks */

#include <stdio.h>
#ifndef __USE_ISOC99
#define __USE_ISOC99
#endif
#include <stdlib.h>

extern void *CLmalloc(size_t size, char *file, int line);
extern void *CLcalloc(size_t nmemb, size_t size, char *file, int line);
extern void *CLrealloc(void *ptr, size_t size, char *file, int line);
extern void CLfree(void *ptr, char *file, int line);
extern char *CLstrdup(const char *s, char *file, int line);
extern char *CLstrndup(const char *s, size_t n, char *file, int line);
extern int CLvasprintf(char **strp, const char *fmt, void *ap, char *file, int line);

#define malloc(x)		CLmalloc(x, __FILE__, __LINE__)
#define calloc(x, y)		CLcalloc(x, y, __FILE__, __LINE__)
#define realloc(x, y)		CLrealloc(x, y, __FILE__, __LINE__)
#define free(x)			CLfree(x, __FILE__, __LINE__)
#define strdup(x)		CLstrdup(x, __FILE__, __LINE__)
#define strndup(x, y)		CLstrndup(x, y, __FILE__, __LINE__)
#define vasprintf(x, y, z)	CLvasprintf(x, y, z, __FILE__, __LINE__)

#endif

#if DEBUG_RETAIN
#define retain		retain:__FILE__ :__LINE__
#define release		release:__FILE__ :__LINE__
#define autorelease	autorelease:__FILE__ :__LINE__
#endif

extern void CLAddToCleanup(id anObject);
extern void CLCleanup();

#endif /* _CLOBJECT_H */
