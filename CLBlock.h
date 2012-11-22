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

#ifndef _CLBLOCK_H
#define _CLBLOCK_H

#import <ClearLake/CLElement.h>

@class CLMutableString, CLArray, CLMutableArray;

@interface CLBlock:CLElement <CLCopying>
{
  id value;
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage; /* This is the designated initializer */
-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage;
-(void) dealloc;

-(id) value;
-(void) setValue:(id) aValue;
-(void) setVisible:(BOOL) flag;
-(void) addObject:(id) anObject;
-(void) addObjectsFromArray:(CLArray *) otherArray;

-(void) writeValueTo:(CLStream *) stream;
-(void) writeHTML:(CLStream *) stream;
-(void) autonumber:(id) anObject position:(int) index
	  replaced:(CLMutableDictionary *) replaced;
-(void) autonumber:(id) anObject newIDs:(CLDictionary *) replaced;
-(void) autonumber:(CLArray *) anArray;
-(void) updateBindingFor:(id) anObject;
-(void) updateBinding;
-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore;

@end

#endif /* _CLBLOCK_H */
