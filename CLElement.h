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

#ifndef _CLELEMENT_H
#define _CLELEMENT_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLStream.h>

@class CLString, CLMutableDictionary, CLPage, CLDictionary, CLBlock;

@interface CLElement:CLObject <CLCopying, CLArchiving>
{
  CLString *title;
  CLMutableDictionary *attributes;
  CLPage *page;
  id datasource, parentBlock;
}

-(id) init;
-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage; /* This is the designated initializer */
-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage;
-(void) dealloc;

-(CLString *) title;
-(void) setTitle:(CLString *) aString;
-(CLMutableDictionary *) attributes;
-(CLPage *) page;
-(void) setPage:(CLPage *) aPage;
-(id) datasource;
-(void) setDatasource:(id) anObject;
-(CLBlock *) parentBlock;
-(void) setParentBlock:(CLBlock *) aParent;
-(id) objectValueForSpecialBinding:(CLString *) aBinding allowConstant:(BOOL) flag
			     found:(BOOL *) found wasConstant:(BOOL *) wasConst;
-(void) writeAttributes:(CLDictionary *) aDict to:(CLStream *) stream;
-(void) writeHTML:(CLStream *) stream;
-(BOOL) isVisible;

@end

@protocol CLElementDelegate
-(id) datasourceForElement:(CLElement *) anElement binding:(CLString **) aBinding;
@end

#endif /* _CLELEMENT_H */
