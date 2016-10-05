/* Copyright 1995-2007 by Chris Osborn <fozztexx@fozztexx.com>
 *
 * Copyright 2008-2016 by
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

#ifndef _CLELEMENT_H
#define _CLELEMENT_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLStream.h>

@class CLString, CLMutableDictionary, CLPage, CLDictionary, CLBlock, CLMutableArray;

@interface CLElement:CLObject <CLCopying, CLArchiving>
{
  CLString *title;
  CLMutableDictionary *attributes;
  CLPage *page;
  id datasource, parentBlock;
}

+(id) expandBinding:(id) aBinding using:(id) anElement success:(BOOL *) success;
+(BOOL) expandBoolean:(id) aBinding using:(id) anElement;
+(CLString *) expandClass:(CLString *) aString using:(CLElement *) anElement;
+(void) writeAttributes:(CLDictionary *) aDict using:(id) anElement to:(CLStream *) stream;

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
-(void) setParentBlock:(id) aParent;
-(id) objectValueForSpecialBinding:(CLString *) aBinding allowConstant:(BOOL) flag
			     found:(BOOL *) found wasConstant:(BOOL *) wasConst;
-(id) expandBinding:(id) aBinding success:(BOOL *) success;
-(BOOL) expandBoolean:(id) aBinding;
-(void) writeAttributes:(CLDictionary *) aDict to:(CLStream *) stream;
-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore;
-(void) writeHTML:(CLStream *) stream;
-(BOOL) isVisible;

@end

@protocol CLElementDelegate
-(id) datasourceForElement:(CLElement *) anElement binding:(CLString **) aBinding;
@end

#endif /* _CLELEMENT_H */
