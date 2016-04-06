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

#ifndef _CLORIGINALIMAGE_H
#define _CLORIGINALIMAGE_H

#import <ClearLake/CLOriginalFile.h>
#import <ClearLake/CLImageElement.h>

@class CLImageRep, CLInput, CLData, CLCachedImage;

@interface CLOriginalImage:CLOriginalFile <CLImagePresentation>
{
  CLImageRep *imageRep;
}

+(CLOriginalImage *) imageFromField:(CLInput *) aField table:(CLString *) aTable;
+(CLOriginalImage *) imageFromFile:(CLString *) aFilename table:(CLString *) aTable;
+(CLOriginalImage *) imageFromData:(CLData *) aData table:(CLString *) aTable;
+(CLOriginalImage *) imageFromPath:(CLString *) aPath table:(CLString *) aTable
			  hardlink:(BOOL) hardlink;
-(CLCachedImage *) cachedImageForEffects:(CLString *) aString;
-(void) didDeleteFromDatabase;
@end

@interface CLOriginalImage (CLMagic)
-(CLArray *) cachedImages;
@end

#endif /* _CLORIGINALIMAGE_H */
