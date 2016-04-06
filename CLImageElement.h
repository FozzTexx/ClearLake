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

#ifndef _CLIMAGEELEMENT_H
#define _CLIMAGEELEMENT_H

#import <ClearLake/CLBlock.h>
#import <ClearLake/CLGeometry.h>

@class CLImageRep;

extern Class CLImageElementClass;

@interface CLImageElement:CLElement <CLCopying, CLArchiving>
{
  id imageRep;

  /* Used to cache path of image during generateURL to allow delegate to make short URLs */
  CLString *path;
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage;
-(id) initWithImageRep:(id) aRep alt:(CLString *) anAlt onPage:(CLPage *) aPage;
-(void) dealloc;

-(id) imageRep;
-(CLString *) path;
-(void) setImageRep:(id) aRep;

-(void) updateBinding;
-(CLString *) generateURL;
-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore;
-(void) writeHTML:(CLStream *) stream;

@end

@protocol CLImagePresentation
-(CLSize) size;
-(CLString *) path;
-(id) imageRep;
-(id) imageRepFromEffects:(CLString *) effects;
-(CLData *) representationUsingFormat:(CLString *) format;
-(CLString *) bestFormat;
@end

#endif /* _CLIMAGEELEMENT_H */
