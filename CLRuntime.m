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

#import "CLRuntime.h"
#import "CLHashTable.h"
#import "CLString.h"

#include <string.h>

#if __GNU_LIBOBJC__ > 20100911
/* FIXME - there's a bug in class_copyIvarList that if a class has no
   ivars of its own, it tries to dereference a NULL pointer. Helpfully
   instead of fixing the problem, they removed the class declaration
   so that I can't test to see if there are any ivars declared */

struct objc_class {
  void *class_pointer;
  struct objc_class *super_class;
  const char *name;
  long version;
  unsigned long info;
  long instance_size;
  #ifdef _WIN64
  long pad;
  #endif
  struct objc_ivar_list *ivars;
  struct objc_method_list *methods;
  struct sarray *dtable;
  struct objc_class *subclass_list;
  struct objc_class *sibling_class;
  struct objc_protocol_list *protocols;
  void *gc_object_type;
};
#endif

CLHashTable *CLSelNameTable = NULL;

CLString *CLSelGetName(SEL selector)
{
  CLString *aString;
  const char *selName;

  
  if (!CLSelNameTable ||
      !(aString =
	CLHashTableDataForIdenticalKey(CLSelNameTable, (id) selector, (size_t) selector))) {
    selName = sel_getName(selector);
#if DEBUG_RETAIN
    id self = nil;
#endif
    aString = [[CLString alloc] initWithBytes:selName length:strlen(selName)
				     encoding:CLUTF8StringEncoding];
    if (!CLSelNameTable)
      CLSelNameTable = CLHashTableAlloc(CLHashTableDefaultSize);
    CLHashTableSetData(CLSelNameTable, aString, (id) selector, (size_t) selector);
  }

  return aString;
}

#ifdef __GNU_LIBOBJC__

CLMethodInfo *CLGetMethods(Class aClass, unsigned int *count)
{
  unsigned int numMethods, totalMethods;
  Method *methods, aMethod;
  unsigned int i;
  CLMethodInfo *info, *mInfo;
  

  totalMethods = 0;
  info = NULL;
  while (aClass) {
    methods = class_copyMethodList(aClass, &numMethods);
    totalMethods += numMethods;
    info = realloc(info, totalMethods * sizeof(CLMethodInfo));
    for (i = 0; i < numMethods; i++) {
      aMethod = methods[i];
      mInfo = &info[i + totalMethods - numMethods];
      mInfo->selector = method_getName(aMethod);
      mInfo->name = sel_getName(mInfo->selector);
      mInfo->imp = method_getImplementation(aMethod);
      mInfo->methodTypes = method_getTypeEncoding(aMethod);
      mInfo->returnType = *(mInfo->methodTypes);
      mInfo->numArguments = method_getNumberOfArguments(aMethod) - 2;
    }
    aClass = [aClass superClass];
  }
  
  *count = totalMethods;
  return info;
}

void *CLGetIvars(Class aClass, unsigned int *count)
{
  unsigned int numIvars, totalIvars;
  CLIvarInfo *info, *ivInfo;
  Ivar *ivars, anIvar;
  const char *enc;
  unsigned int i;


  totalIvars = 0;
  info = NULL;
  while (aClass) {
    if (((struct objc_class *) aClass)->ivars) {
      ivars = class_copyIvarList(aClass, &numIvars);
      totalIvars += numIvars;
      info = realloc(info, totalIvars * sizeof(CLIvarInfo));
      for (i = 0; i < numIvars; i++) {
	anIvar = ivars[i];
	ivInfo = &info[i + totalIvars - numIvars];
	ivInfo->name = ivar_getName(anIvar);
	ivInfo->offset = ivar_getOffset(anIvar);
	enc = ivar_getTypeEncoding(anIvar);
	ivInfo->type = *enc;
      }
    }
    aClass = [aClass superClass];
  }

  *count = totalIvars;
  return info;
}

#else /* not __GNU_LIBOBJC__ */

struct objc_method_list *CLClassNextMethodList(Class aClass, void **iterator)
{
  if (!*iterator)
    *iterator = aClass->methods;
  else
    *iterator = (*(struct objc_method_list **) iterator)->method_next;

  return *iterator;
}

CLMethodInfo *CLGetMethods(Class aClass, unsigned int *count)
{
  unsigned int totalMethods;
  Method aMethod;
  unsigned int i;
  CLMethodInfo *info, *mInfo;
  void *iterator = NULL;
  struct objc_method_list* mlist;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif
  

  totalMethods = 0;
  info = NULL;
  while (aClass) {
    if (mlist = CLClassNextMethodList(aClass, &iterator)) {
      totalMethods += mlist->method_count;
      info = realloc(info, totalMethods * sizeof(CLMethodInfo));
      for (i = 0; i < mlist->method_count; i++) {
	aMethod = mlist->method_list[i];
	mInfo = &info[i + totalMethods - mlist->method_count];
	mInfo->selector = aMethod.method_name;
	mInfo->name = sel_getName(mInfo->selector);
	mInfo->imp = aMethod.method_imp;
	mInfo->methodTypes = aMethod.method_types;
	mInfo->returnType = *(mInfo->methodTypes);
	mInfo->numArguments = method_getNumberOfArguments(&aMethod) - 2;
      }
    }
    else
      aClass = [aClass superClass];
  }
  
  *count = totalMethods;
  return info;
}

void *CLGetIvars(Class aClass, unsigned int *count)
{
  unsigned int totalIvars;
  CLIvarInfo *info, *ivInfo;
  const char *enc;
  unsigned int i;
  struct objc_ivar_list* ivarList;
  Ivar_t anIvar;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  totalIvars = 0;
  info = NULL;
  while (aClass) {
    ivarList = aClass->ivars;
    if (ivarList && ivarList->ivar_count > 0) {
      totalIvars += ivarList->ivar_count;
      info = realloc(info, totalIvars * sizeof(CLIvarInfo));
      for (i = 0; i < ivarList->ivar_count; i++) {
	anIvar = ivarList->ivar_list + i;
	ivInfo = &info[i + totalIvars - ivarList->ivar_count];
	ivInfo->name = anIvar->ivar_name;
	ivInfo->offset = anIvar->ivar_offset;
	enc = anIvar->ivar_type;
	ivInfo->type = *enc;
      }
    }
    aClass = [aClass superClass];
  }

  *count = totalIvars;
  return info;
}

#endif /* __GNU_LIBOBJC__ */
