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

#ifndef _CLOBJECT_H
#define _CLOBJECT_H

#import <ClearLake/CLPrimitiveObject.h>

@class CLInvocation, CLData, CLStream;

#define CL_URLDATA	@"CLurldata"
#define CL_URLSEL	@"CLurlsel"
#define CL_URLCLASS	@"CLurlclass"

typedef enum {
  CLNoBinding = 0,
  CLMethodBinding,
  CLIvarBinding,
  CLPageBinding,
  CLFieldBinding,
  CLRelationshipBinding
} CLBindingType;

typedef struct {
  void *getter;
  void *setter;
  CLBindingType getType, setType;
  SEL getSel, setSel;
  int returnType;
  int argumentType;
} CLCachedBinding;

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

@interface CLObject:CLPrimitiveObject <CLArchiving>
+(void) poseAsClass:(Class) aClassObject;

-(CLUInteger) hash;
-(BOOL) isEqual:(id) anObject;

-(void *) pointerForIvar:(const char *) anIvar type:(int *) aType;
-(id) objectForMethod:(CLString *) aMethod found:(BOOL *) found;
-(id) objectForIvar:(CLString *) anIvar found:(BOOL *) found;
-(CLString *) findFileForKey:(CLString *) aKey;
-(CLString *) findFileForKey:(CLString *) aKey directory:(CLString *) aDir;
-(void *) cacheBindings;
-(id) objectValueForBinding:(CLString *) aBinding;
-(id) objectValueForBinding:(CLString *) aBinding found:(BOOL *) found;
-(void) setObjectValue:(id) anObject forVariable:(CLString *) aField;
-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding;
-(void) setPrimitiveValue:(id) anObject forKey:(CLString *) aKey;
-(void) forwardInvocation:(CLInvocation *) anInvocation;
@end

@interface CLObject (CLWeb)
-(BOOL) replacePage:(id) sender filename:(CLString *) aFilename;
-(BOOL) replacePage:(id) sender key:(CLString *) aKey;
-(BOOL) replacePage:(id) sender selector:(SEL) aSel;
-(void) redirectTo:(id) anObject selector:(SEL) aSel;
-(CLString *) urlForMethod:(SEL) aSelector;
@end

extern CLString *CLPropertyListString(id anObject);
extern CLString *CLJSONString(id anObject);

#endif /* _CLOBJECT_H */
