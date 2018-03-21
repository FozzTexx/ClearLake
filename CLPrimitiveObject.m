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

#define _GNU_SOURCE
#include <string.h>

#define NO_OVERRIDE	1

#import "CLPrimitiveObject.h"
#import "CLRuntime.h"
#import "CLHashTable.h"
#import "CLString.h"
#import "CLMethodSignature.h"
#import "CLAutoreleasePool.h"
#import "CLConstantUnicodeString.h"
#import "CLMutableDictionary.h"
#if DEBUG_ALLOC
#import "CLNumber.h" /* for allocAllow */
#endif

#if DEBUG_LEAK || DEBUG_RETAIN || DEBUG_RELEASE
#import "CLReleaseTracker.h"
Class CLReleaseTrackerClass;
#endif

#include <stdlib.h>

#if DEBUG_LEAK || DEBUG_RETAIN || DEBUG_ALLOC
/* FIXME - just for finding memory leaks */
typedef struct {
  id object;
  unsigned int sequence, size;
  char flag;
  char file[256];
  unsigned int line;
  id retainer[10];
  unsigned int retainerCount;
} CLLeak;
int CLLeakNumObjects = 0;
CLLeak *CLLeakArray = NULL;
int CLLeakArrayLength = 0, CLLeakArrayPos = 0;
unsigned int CLLeakSequence = 0;

CLLeak *CLLeakFindObject(id anObject);
CLLeak *CLLeakUpdateObject(id anObject, const char *file, int line, id retainer);
void CLLeakReleaseObject(id anObject, id retainer);
#endif

#if DEBUG_LEAK || DEBUG_RETAIN
int CLLeakMemUsed = 0;
int CLLeakPrint = 0;

int CLLeakNumBlocks = 0, CLLeakMaxBlocks = 0, CLLeakMarker = 0;
CLLeak *CLLeakBlocks = NULL;
#endif /* DEBUG_LEAK || DEBUG_RETAIN */

#if DEBUG_ALLOC
CLMutableArray *allocAllow = nil;
#endif

static CLMutableArray *CLCleanupArray = nil;
static CLMutableDictionary *CLPoseDict = nil;

CL_INLINE void CLIncrementExtraRefCount(id anObject)
{
  (*((CLUInteger *)((void *) anObject - sizeof(CLObjectReserved))))++;
}

CL_INLINE BOOL CLDecrementExtraRefCountWasZero(id anObject)
{
  if (!(*((CLUInteger *)((void *) anObject - sizeof(CLObjectReserved)))))
    return YES;
  (*((CLUInteger *)((void *) anObject - sizeof(CLObjectReserved))))--;
  return NO;
}

CL_INLINE CLUInteger CLExtraRefCount(id anObject)
{
  return (*((CLUInteger *)((void *) anObject - sizeof(CLObjectReserved))));
}

#ifndef __GNU_LIBOBJC__
id CLCreateInstance(Class class)
{
  void *buf;
  id anObject;


  buf = calloc(1, class->instance_size + sizeof(CLObjectReserved));
  anObject = buf + sizeof(CLObjectReserved);
  anObject->class_pointer = class;
  return anObject;
}

id CLDisposeInstance(id object)
{
  void *buf;

  
  buf = object;
  buf -= sizeof(CLObjectReserved);
  free(buf);
  return nil;
}
#endif

@implementation CLPrimitiveObject

#if DEBUG_LEAK || DEBUG_RETAIN || DEBUG_RELEASE
+(void) initialize
{
  CLReleaseTrackerClass = [CLReleaseTracker class];
  return;
}
#endif

#if DEBUG_RETAIN
#undef alloc
#endif

#ifdef __GNU_LIBOBJC__
+(id) alloc
{
  void *buf;
  Class isa;
  id new;


#if DEBUG_ALLOC
  if ([allocAllow count] && ![[allocAllow lastObject] boolValue])
    [self error:@"No allocing!"];
#endif
  
  buf = class_createInstance(self, sizeof(CLObjectReserved));
  isa = ((id) buf)->class_pointer;
  new = buf + sizeof(CLObjectReserved);
  new->class_pointer = isa;
  *((CLUInteger *) buf) = 0;
  return new;
}
#else /* !__GNU_LIBOBJC__ */
+(void) load
{
  _objc_object_alloc = CLCreateInstance;
  _objc_object_dispose = CLDisposeInstance;
  return;
}

+(id) alloc
{
  Class aClass;

  
#if DEBUG_ALLOC
  if ([allocAllow count] && ![[allocAllow lastObject] boolValue])
    [self error:@"No allocing!"];
#endif
  if (!(aClass = [CLPoseDict objectForKey:self]))
    aClass = self;
  return class_create_instance(aClass);
}
#endif /* else __GNU_LIBOBJC__ */

+(IMP) instanceMethodFor:(SEL) aSel
{
  return method_getImplementation(class_getInstanceMethod(self, aSel));
}

+(void) poseAsClass:(Class) aClassObject
{
#ifdef __GNU_LIBOBJC__
  /* FIXME - what of some instance of aClassObject already exist? */
  if (!CLPoseDict)
    CLPoseDict = [[CLMutableDictionary alloc] init];
  [CLPoseDict setObject:self forKey:aClassObject];
#else
  class_pose_as(self, aClassObject);
#endif
}

+(CLUInteger) hash
{
  return (size_t) self;
}

-(id) init
{
#if DEBUG_LEAK || DEBUG_RETAIN || DEBUG_ALLOC
  CLLeak *aLeak;

  
  aLeak = CLLeakFindObject(self);
#endif
#if DEBUG_LEAK || DEBUG_RETAIN
  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx %u/%i init %s %i\n", (unsigned long) self,
	    aLeak->sequence, aLeak->flag, className, CLLeakSequence - 1);
    CLLeakPrint = pl;
  }
#endif
  return self;
}

-(void) dealloc
{
#if DEBUG_LEAK || DEBUG_RETAIN || DEBUG_ALLOC
  int pos;


  CLLeakNumObjects--;

  for (pos = CLLeakArrayPos - 1; pos >= 0; pos--)
    if (CLLeakArray[pos].object == self)
      break;
  if (pos < 0)
    [self error:@"How do we exist?"];
#if 1
  if (CLLeakArrayPos - pos)
    memmove(&CLLeakArray[pos], &CLLeakArray[pos+1], sizeof(CLLeak) * (CLLeakArrayPos - pos));
  CLLeakArrayPos--;
#endif
  
#endif
#if DEBUG_LEAK || DEBUG_RETAIN
  if (CLLeakNumObjects < 0)
    [self error:@"We released more than we allocated!"];
  
  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx dealloc %s %i\n", (unsigned long) self, className, pos);
    CLLeakPrint = pl;
  }
#endif

#if DEBUG_LEAK || DEBUG_RETAIN || DEBUG_RELEASE
  /* Not going to fully release, swizzling to another class that can't
     do anything and will abort if called */
  {
    void *buf;
    CLObjectReserved *reserved;


    buf = self;
    reserved = buf - sizeof(CLObjectReserved);
    reserved->faultData = isa;
    isa = CLReleaseTrackerClass;
  }
  
#else
  {
    void *buf;

  
    buf = self;
    buf -= sizeof(CLObjectReserved);
#ifdef __GNU_LIBOBJC__
    ((id) buf)->class_pointer = ((id) self)->class_pointer;
#endif
    object_dispose(buf);
  }
#endif

  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer;

#else
-(id) copy
#endif
{
  id newObject;
  

  newObject = [[self class] alloc];
#if DEBUG_LEAK || DEBUG_RETAIN || DEBUG_ALLOC
  CLLeak *aLeak;

  
  aLeak = CLLeakFindObject(self);
#endif
#if DEBUG_LEAK || DEBUG_RETAIN
  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[newObject class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx %u/%i copy %s %i\n", (unsigned long) newObject,
	    aLeak->sequence, aLeak->flag, className, CLLeakSequence - 1);
    CLLeakPrint = pl;
  }
#endif
  return newObject;
}

-(Class) class
{
  Class aClass = object_getClass(self);
  Class poseClass;


  if (class_isMetaClass(aClass))
    aClass = (Class) self;
  if ((poseClass = [CLPoseDict objectForKey:aClass]))
    aClass = poseClass;
  
  return aClass;
}

-(Class) superClass
{
  return class_getSuperclass([self class]);
}

-(CLString *) className
{
  static CLHashTable *classNameTable = NULL;
  CLString *aString;
  Class aClass = [self class];
  

  if (!classNameTable ||
      !(aString = CLHashTableDataForIdenticalKey(classNameTable, aClass, (size_t) aClass))) {
    if (!classNameTable)
      classNameTable = CLHashTableAlloc(CLHashTableDefaultSize);
#if DEBUG_ALLOC
    CLPushAllocAllow(YES);
#endif
    aString = [[CLString alloc] initWithUTF8String:object_getClassName(aClass)];
#if DEBUG_ALLOC
    CLPopAllocAllow();
#endif
    CLHashTableSetData(classNameTable, aString, aClass, (size_t) aClass);
  }
  
  return aString;
}

-(BOOL) isMemberOfClass:(Class) aClassObject
{
  return self->isa == aClassObject;
}

-(BOOL) isKindOfClass:(Class) aClassObject
{
  Class aClass;
  

  aClass = object_getClass(self);
  if (class_isMetaClass(aClass))
    aClass = (Class) self;
  for (; aClass; aClass = class_getSuperclass(aClass))
    if (aClass == aClassObject)
      return YES;
  return NO;
}

-(BOOL) isFault
{
  return NO;
}

-(BOOL) isClass
{
#ifdef __GNU_LIBOBJC__
  return class_isMetaClass(object_getClass(self));
#else
  return object_is_class(self);
#endif
}

-(BOOL) isInstance
{
#ifdef __GNU_LIBOBJC__
  return ![self isClass];
#else
  return object_is_instance(self);
#endif
}

-(BOOL) respondsTo:(SEL) aSel
{
  return !![self methodFor:aSel];
}

/* This is just here to appease gdb */
-(BOOL) respondsToSelector:(SEL) aSel
{
  return [self respondsTo:aSel];
}

-(struct objc_method_description *) descriptionForMethod:(SEL) aSel
{
  return (struct objc_method_description *)
           ([self isInstance] ?
	    class_getInstanceMethod(self->isa, aSel) :
	    class_getClassMethod(self->isa, aSel));
}

-(CLMethodSignature *) newMethodSignatureForSelector:(SEL) aSel
{
  struct objc_method_description *md;
  CLMethodSignature *aSig;


  md = [self descriptionForMethod:aSel];
  if (md)
    aSig = [CLMethodSignature newMethodSignatureForDescription:md];
  else
    aSig = [CLMethodSignature newMethodSignatureForSelector:aSel];

  return aSig;
}

-(void) doesNotRecognize:(SEL) aSel
{
  [self error:@"%s does not recognize %s",
	object_getClassName(self), sel_getName(aSel)];
  return;
}

-(IMP) methodFor:(SEL) aSel
{
  return method_getImplementation([self isInstance] ?
			class_getInstanceMethod(self->isa, aSel) :
			class_getClassMethod(self->isa, aSel));
}

/* This is just here to appease gdb */
-(IMP) methodForSelector:(SEL) aSel
{
  return [self methodFor:aSel];
}

-(id) perform:(SEL) aSel
{
  IMP msg = objc_msg_lookup(self, aSel);

  
  if (!msg)
    [self error:@"invalid selector passed to %s", sel_getName(_cmd)];
  return (*msg)(self, aSel);
}

-(id) perform:(SEL) aSel with:(id) anObject
{
  IMP msg = objc_msg_lookup(self, aSel);

  
  if (!msg)
    [self error:@"invalid selector passed to %s", sel_getName(_cmd)];
  return (*msg)(self, aSel, anObject);
}

-(id) perform:(SEL) aSel with:(id) anObject1 with:(id) anObject2
{
  IMP msg = objc_msg_lookup(self, aSel);

  
  if (!msg)
    [self error:@"invalid selector passed to %s", sel_getName(_cmd)];
  return (*msg)(self, aSel, anObject1, anObject2);
}

-(void) error:(CLString *) aString, ...
{
  va_list ap;
  char *str = "";


  if (aString) {
    va_start(ap, aString);
    vasprintf(&str, [aString UTF8String], ap);
    va_end(ap);
  }

  fprintf(stderr, "error: %s (%s)\n%s\n",
	  object_getClassName(self),
	  [self isInstance] ? "instance" : "class",
	  str);
  abort();
  return;
}

@end

@implementation CLPrimitiveObject (CLRetaining)

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
    if (CLDeferPool && [self respondsTo:@selector(shouldDeferRelease)] &&
	[self shouldDeferRelease])
      [CLDeferPool addObject:self];
    else
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

-(CLUInteger) retainCount
{
  return CLExtraRefCount(self) + 1;
}

#if DEBUG_RETAIN
+(id) alloc:(const char *) file :(int) line :(id) retainer
{
  id anObject = [self alloc];
  CLLeak *aLeak;


  aLeak = CLLeakUpdateObject(anObject, file, line, retainer);
  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[self className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx %u/%i alloc %s - 0x%lx %s:%i %i\n",
	    (unsigned long) anObject, aLeak->sequence, aLeak->flag,
	    className, (unsigned long) retainer,
	    file, line, [self retainCount]);
    CLLeakPrint = pl;
  }
  return anObject;
}

-(id) retain:(const char *) file :(int) line :(id) retainer
{
  CLLeakUpdateObject(self, NULL, 0, retainer);
  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx retain %s - 0x%lx %s:%i %i\n",
	    (unsigned long) self, className, (unsigned long) retainer,
	    file, line, [self retainCount] + 1);
    CLLeakPrint = pl;
  }
  return [self retain];
}

-(void) release:(const char *) file :(int) line :(id) retainer
{
  CLLeakReleaseObject(self, retainer);
  
  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx release %s - 0x%lx %s:%i %i\n",
	    (unsigned long) self, className, (unsigned long) retainer,
	    file, line, [self retainCount] - 1);
    CLLeakPrint = pl;
  }
  [self release];
  return;
}

-(id) autorelease:(const char *) file :(int) line :(id) retainer
{
  if (CLLeakPrint) {
    int pl = CLLeakPrint;
    CLLeakPrint = 0;
    const char *className = [[[self class] className] UTF8String];
    if (!className)
      [self error:@"Unknown class!"];
    fprintf(stdout, "0x%lx autorelease %s - 0x%lx %s:%i\n",
	    (unsigned long) self, className, (unsigned long) retainer, file, line);
    CLLeakPrint = pl;
  }
  return [self autorelease];
}
#endif

@end

#if DEBUG_ALLOC
void CLPushAllocAllow(BOOL flag)
{
  if (!allocAllow)
    allocAllow = [[CLMutableArray alloc] init];

  //fprintf(stderr, "Push objects: %i\n", CLLeakNumObjects);
  [allocAllow addObject:flag ? CLTrueObject : CLFalseObject];
  return;
}

void CLPopAllocAllow()
{
  [allocAllow removeLastObject];
  //fprintf(stderr, "Pop objects: %i\n", CLLeakNumObjects);
  return;
}
#endif

#if DEBUG_LEAK
static void *(*CLoldMemalignHook)(size_t alignment, size_t size, const void *caller);

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
  
void CLsaveBlock(const char *func, void *ptr, size_t size, char *file, int line, id retainer)
{
  CLLeak *aLeak = NULL;
  int i;


  if ([retainer isKindOfClass:CLConstantStringClass] ||
      [retainer isKindOfClass:CLConstantUnicodeStringClass]) {
    file = NULL;
    line = 0;
  }
  
  for (i = 0; i < CLLeakNumBlocks; i++) {
    if (CLLeakBlocks[i].object == ptr) {
      aLeak = &CLLeakBlocks[i];
      break;
    }
  }

  if (aLeak && aLeak->size != size)
    fprintf(stderr, "#### Size changed!\n");

  if (!aLeak) {
    if (CLLeakNumBlocks + 1 > CLLeakMaxBlocks) {
      CLLeakMaxBlocks += 32;
      CLLeakBlocks = CLoldRealloc(CLLeakBlocks, sizeof(CLLeak) * CLLeakMaxBlocks);
    }

    aLeak = &CLLeakBlocks[CLLeakNumBlocks++];
    aLeak->object = ptr;
    aLeak->sequence = CLLeakSequence++;
    aLeak->retainerCount = 0;
  }
  
  aLeak->size = size;
  aLeak->flag = CLLeakMarker;
  if (file)
    strncpy(aLeak->file, file, sizeof(aLeak->file) - 1);
  aLeak->line = line;
  aLeak->retainer[aLeak->retainerCount++] = retainer;

  if (CLLeakPrint /*&& file && line*/)
    fprintf(stdout, "0x%lx %u/%i %s %u 0x%lx %s:%i\n",
	    (unsigned long) ptr, aLeak->sequence, aLeak->flag,
	    func, aLeak->size, (unsigned long) retainer, file, line);
  return;
}

int CLfreeBlock(const char *func, void *ptr, char *file, int line, id retainer)
{
  int i, size;
  CLLeak *aLeak = NULL, leakCopy;


  if (!ptr)
    return 0;
  
  for (i = 0; i < CLLeakNumBlocks; i++) {
    if (CLLeakBlocks[i].object == ptr) {
      leakCopy = CLLeakBlocks[i];
      aLeak = &leakCopy;
      CLLeakNumBlocks--;
      memmove(&CLLeakBlocks[i], &CLLeakBlocks[i+1], (CLLeakNumBlocks - i) * sizeof(CLLeak));
      break;
    }
  }

  if (CLLeakPrint /*&& file && line*/) {
    if (!aLeak) {
      fprintf(stdout, "0x%lx %s never allocated\n", (unsigned long) ptr, func);
      size = 0;
    }
    else {
      size = aLeak->size;
      fprintf(stdout, "0x%lx %u/%i %s %u 0x%lx %s:%i\n", (unsigned long) ptr,
	      aLeak->sequence, aLeak->flag, func, aLeak->size,
	      (unsigned long) retainer, file, line);
    }
  }

  return size;
}

int CLfindMarker(int m, int start)
{
  int i;


  for (i = start; i < CLLeakNumBlocks; i++)
    if (CLLeakBlocks[i].flag == m)
      return i;

  return -1;
}

void *CLmalloc(size_t size, char *file, int line, id retainer)
{
  void *ptr;


  if (!size)
    fprintf(stdout, "%s %i attempt to malloc zero bytes\n", file, line);
  
  ptr = CLoldMalloc(size);
  CLLeakMemUsed += size;
  CLsaveBlock("malloc", ptr, size, file, line, retainer);
  return ptr;
}

void *CLcalloc(size_t nmemb, size_t size, char *file, int line, id retainer)
{
  void *ptr, *saveHook;
  

  if (!size || !nmemb)
    fprintf(stdout, "%s %i attempt to calloc zero bytes\n", file, line);

  saveHook = __malloc_hook;
  __malloc_hook = CLoldMallocHook;
  ptr = calloc(nmemb, size);
  __malloc_hook = saveHook;
  CLLeakMemUsed += nmemb * size;
  CLsaveBlock("calloc", ptr, nmemb * size, file, line, retainer);
  return ptr;
}

void *CLrealloc(void *ptr, size_t size, char *file, int line, id retainer)
{
  CLLeakMemUsed -= CLfreeBlock("realloc", ptr, file, line, retainer);
  CLLeakMemUsed += size;
  ptr = CLoldRealloc(ptr, size);
  CLsaveBlock("realloc", ptr, size, file, line, retainer);
  return ptr;
}

void CLfree(void *ptr, char *file, int line, id retainer)
{
  void *saveHook;
  

  CLLeakMemUsed -= CLfreeBlock("free", ptr, file, line, retainer);
  saveHook = __free_hook;
  __free_hook = CLoldFreeHook;
  free(ptr);
  __free_hook = saveHook;
  return;
}

#undef strdup
#undef strndup
#undef vasprintf

char *CLstrdup(const char *s, char *file, int line, id retainer)
{
  char *ptr;
  int size;


  if (!s)
    fprintf(stdout, "%s %i attempt to duplicate null string\n", file, line);
  
  ptr = strdup(s);
  size = strlen(ptr) + 1;
  CLLeakMemUsed += size;
  CLsaveBlock("strdup", ptr, size, file, line, retainer);
  return ptr;
}

char *CLstrndup(const char *s, size_t n, char *file, int line, id retainer)
{
  char *ptr;
  int size;


  if (!s)
    fprintf(stdout, "%s %i attempt to duplicate null string\n", file, line);
  
  ptr = strndup(s, n);
  size = strlen(ptr) + 1;
  CLLeakMemUsed += size;
  CLsaveBlock("strndup", ptr, size, file, line, retainer);
  return ptr;
}

int CLvasprintf(char **strp, const char *fmt, va_list ap, char *file, int line, id retainer)
{
  int size;


  size = vasprintf(strp, fmt, ap) + 1;
  CLLeakMemUsed += size;
  CLsaveBlock("vasprintf", *strp, size, file, line, retainer);
  return size;
}

static void *CLmallocHook(size_t size, const void *caller)
{
  return CLmalloc(size, NULL, 0, nil);
}

static void *CLreallocHook(void *ptr, size_t size, const void *caller)
{
  return CLrealloc(ptr, size, NULL, 0, nil);
}

static void *CLmemalignHook(size_t alignment, size_t size, const void *caller)
{
  void *ptr, *saveHook;
  

  saveHook = __memalign_hook;
  __memalign_hook = CLoldMemalignHook;
  ptr = memalign(alignment, size);
  __memalign_hook = saveHook;
  CLLeakMemUsed += size;
  CLsaveBlock("memalign", ptr, size, NULL, 0, nil);
  return ptr;
}

static void CLfreeHook(void *ptr, const void *caller)
{
  CLfree(ptr, NULL, 0, nil);
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

/* Mostly for tracking memory leaks. No real reason to use this since
   exit() will clean up everything */

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
  
#if DEBUG_LEAK || DEBUG_RETAIN
  if (CLLeakArrayPos) {
    int i;


    fprintf(stdout, "\n------------ Leaked Objects ------------\n");
    for (i = 0; i < CLLeakArrayPos; i++)
      fprintf(stdout, "0x%lx %s\n", (unsigned long) CLLeakArray[i].object,
	      [[CLLeakArray[i].object className] UTF8String]);
  }

  if (CLLeakNumBlocks) {
    int i;


    fprintf(stdout, "\n------------ Leaked Memory ------------\n");
    for (i = 0; i < CLLeakNumBlocks; i++)
      fprintf(stdout, "0x%lx %i %i\n", (unsigned long) CLLeakBlocks[i].object,
	      CLLeakBlocks[i].size, CLLeakBlocks[i].flag);
  }
#endif
  
  return;
}

#if DEBUG_LEAK || DEBUG_RETAIN
CLLeak *CLLeakFindObject(id anObject)
{
  int i;
  CLLeak *aLeak;
  

  /* FIXME - use a hash table */
  for (i = 0; i < CLLeakArrayPos; i++)
    if (CLLeakArray[i].object == anObject)
      return &CLLeakArray[i];

  CLLeakNumObjects++;
  if (CLLeakArrayPos + 1 > CLLeakArrayLength) {
    CLLeakArrayLength += 256;
    CLLeakArray = realloc(CLLeakArray, sizeof(CLLeak) * CLLeakArrayLength);
  }
  aLeak = &CLLeakArray[CLLeakArrayPos++];
  aLeak->object = anObject;
  aLeak->sequence = CLLeakSequence++;
  aLeak->flag = 0;
  aLeak->retainerCount = 0;
  memset(aLeak->file, 0, sizeof(aLeak->file));
  aLeak->file[0] = 0;
  aLeak->line = 0;

  return aLeak;
}

CLLeak *CLLeakUpdateObject(id anObject, const char *file, int line, id retainer)
{
  CLLeak *aLeak;


  aLeak = CLLeakFindObject(anObject);
  if (aLeak->retainerCount < sizeof(aLeak->retainer) / sizeof(id))
    aLeak->retainer[aLeak->retainerCount++] = retainer;
  if (file) {
    strncpy(aLeak->file, file, sizeof(aLeak->file) - 1);
    aLeak->line = line;
  }
  
  return aLeak;
}

void CLLeakReleaseObject(id anObject, id retainer)
{
  CLLeak *aLeak;
  int i;


  aLeak = CLLeakFindObject(anObject);
  for (i = 0; i < aLeak->retainerCount; i++) {
    if (aLeak->retainer[i] == anObject) {
      memmove(&aLeak->retainer[i], &aLeak->retainer[i+1],
	      sizeof(id) * (aLeak->retainerCount - i));
      aLeak->retainerCount--;
      break;
    }
  }

  return;
}

int CLLeakDump(int all)
{
  int i, j, k;
  CLLeak *aLeak;


  for (i = j = 0; i < CLLeakArrayPos; i++) {
    aLeak = &CLLeakArray[i];
    if (all || aLeak->line) {
      fprintf(stdout, "0x%lx %s - %u/%i",
	      (unsigned long) aLeak->object, [[aLeak->object className] UTF8String],
	      aLeak->sequence, aLeak->flag);
      for (k = 0; k < aLeak->retainerCount; k++)
	fprintf(stdout, " 0x%lx", (unsigned long) aLeak->retainer[k]);
      fprintf(stdout, " %i %s:%i\n",
	      [aLeak->object retainCount],	      
	      aLeak->file, aLeak->line);
      j++;
    }
  }
  fprintf(stdout, "Total objects: %i\n", j);

  return j;
}

int CLLeakCount()
{
  int i, j;
  CLLeak *aLeak;


  for (i = j = 0; i < CLLeakArrayPos; i++) {
    aLeak = &CLLeakArray[i];
    if (aLeak->line)
      j++;
  }

  return j;
}

int CLBlockDump(int all)
{
  int i, j;
  unsigned int size;
  CLLeak *aLeak;


  for (size = i = j = 0; i < CLLeakNumBlocks; i++) {
    aLeak = &CLLeakBlocks[i];
    if (all || aLeak->line) {
      fprintf(stdout, "0x%lx %u - %u/%i 0x%lx %s",
	      (unsigned long) aLeak->object, aLeak->size,
	      aLeak->sequence, aLeak->flag,
	      (unsigned long) aLeak->retainer[0], [[aLeak->retainer[0] className] UTF8String]);
      fprintf(stdout, "  %s:%i\n", aLeak->file, aLeak->line);
      j++;
      size += aLeak->size;
    }
  }
  fprintf(stdout, "Total blocks: %i\n", j);
  fprintf(stdout, "Total size: %i\n", size);

  return j;
}

unsigned int CLBlockSize(int all)
{
  int i;
  unsigned int size;
  CLLeak *aLeak;


  for (size = i = 0; i < CLLeakNumBlocks; i++) {
    aLeak = &CLLeakBlocks[i];
    if (all || aLeak->line)
      size += aLeak->size;
  }
  fprintf(stdout, "Total size: %i\n", size);

  return size;
}

#endif
