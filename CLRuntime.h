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

#ifndef _CLRUNTIME_H
#define _CLRUNTIME_H

#import <objc/objc.h>

#ifdef __GNU_LIBOBJC__
#import <objc/runtime.h>
#import <objc/message.h>
#else
#import <objc/objc-api.h>
#import <objc/encoding.h>

#define class_createInstance		class_create_instance
#define class_getClassMethod		class_get_class_method
#define class_getInstanceMethod		class_get_instance_method
#define class_getSuperclass		class_get_super_class
#define class_isMetaClass		class_is_meta_class
#define method_getImplementation	method_get_imp
#define method_getTypeEncoding		method_get_type_encoding
#define objc_lookUpClass		objc_lookup_class
#define object_getClass			object_get_class
#define object_getClassName		object_get_class_name
#define sel_getName			sel_get_name
#define sel_getUid			sel_get_uid
#define method_getNumberOfArguments	method_get_number_of_arguments

#endif /* __GNU_LIBOBJC__ */

extern void CLObjectSetInstanceVariable(id anObject, const char *name, void *data);

#define CL_INLINE static __inline__ __attribute__((always_inline))

#endif /* _CLRUNTIME_H */

