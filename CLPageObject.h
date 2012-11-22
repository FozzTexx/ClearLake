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

typedef enum {
  CL_NOOBJECT = 0,
  CL_APPEND,
  CL_PUSH,
  CL_PUSHDIFF,
  CL_POP,
  CL_DISCARD,
} CLResult;

@interface CLPageObject:CLObject
{
  CLString *name;
  CLResult result;
  Class objectClass;
}

+(CLPageObject *) objectForName:(CLString *) aName result:(CLResult) aResult
			  objectClass:(Class) aClass;

-(id) initFromName:(CLString *) aName result:(CLResult) aResult
	     objectClass:(Class) aClass;
-(void) dealloc;

-(CLString *) name;
-(CLResult) result;
-(Class) objectClass;

@end
