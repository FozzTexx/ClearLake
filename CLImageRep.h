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

#ifndef _CLIMAGEREP_H
#define _CLIMAGEREP_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLGeometry.h>
#import <ClearLake/CLImageElement.h>

@class CLData;

@interface CLImageRep:CLObject <CLCopying, CLImagePresentation, CLArchiving>
{
  void *rep;
  CLString *path;
}

+(CLImageRep *) imageRepFromFile:(CLString *) filename;
+(CLImageRep *) imageRepFromData:(CLData *) aData;

-(id) init;
-(id) initFromFile:(CLString *) filename;
-(id) initFromData:(CLData *) aData;
-(void) dealloc;

-(CLSize) size;
-(CLString *) path;
-(void *) loadImage;
-(void) scaleImage:(CLSize) aSize blend:(BOOL) flag;
-(void) cropImage:(CLRect) aRect;
-(void) autocropImage:(int) margin;
-(void) zoomImage:(CLSize) mSize blend:(BOOL) blend slideTo:(CLString *) direction;
-(void) composite:(CLImageRep *) aRep from:(CLRect) aRect to:(CLPoint) aPoint;
-(void) rotate:(double) radians;
-(BOOL) writeToFile:(CLString *) filename format:(CLString *) format;

-(CLData *) representationUsingFormat:(CLString *) format;
-(CLImageRep *) imageRepFromEffects:(CLString *) effects;
-(CLString *) bestFormat;

/* Icky yucky stuff */
-(void *) piclibCopy;
-(id) initFromPiclib:(void *) aPic;

@end

extern CLString *CLPathForImageID(int image_id);
extern int CLStoreImage(CLData *aData);

#endif /* _CLIMAGEREP_H */
