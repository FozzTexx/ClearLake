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
#include <stdio.h>

#import "CLReleaseTracker.h"
#import "CLConstantString.h"
#import "CLInvocation.h"

#include <stdlib.h>

@implementation CLReleaseTracker

-(Class) class
{
  Class aClass = object_getClass(self);


  if (class_isMetaClass(aClass))
    aClass = (Class) self;
  return aClass;
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

-(CLMethodSignature *) newMethodSignatureForSelector:(SEL) aSel
{
  void *buf;
  CLObjectReserved *reserved;


  buf = self;
  reserved = buf - sizeof(CLObjectReserved);

  isa = reserved->faultData;
  [self error:@"Trying to send \"%s\" to already released \"0x%lu\"\n",
	sel_getName(aSel), (unsigned long) self];
  return NULL;
}

@end
