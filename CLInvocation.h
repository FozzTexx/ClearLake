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

#import <ClearLake/CLObject.h>

@class CLMethodSignature;

@interface CLInvocation:CLObject <CLCopying>
{
  CLMethodSignature *sig;
  id target;
  SEL action;
  CLUInteger count;
  void **values;
  CLUInteger *sizes;
}

+(CLInvocation *) invocationWithMethodSignature:(CLMethodSignature *) signature;

-(id) initWithMethodSignature:(CLMethodSignature *) signature;
-(void) dealloc;

-(CLMethodSignature *) methodSignature;
-(void) getArgument:(void *) buffer atIndex:(CLUInteger) index;
-(void) getReturnValue:(void *) buffer;
-(id) target;
-(SEL) selector;
-(id) objectValueForArgumentAtIndex:(CLUInteger) index;

-(void) setArgument:(void *) buffer atIndex:(CLUInteger) index;
-(void) setReturnValue:(void *) buffer;
-(void) setTarget:(id) anObject;
-(void) setSelector:(SEL) aSelector;

-(void) invoke;

@end
