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

#import "CLStandardContentImage.h"
#import "CLOriginalImage.h"
#import "CLEditingContext.h"
#import "CLStandardContent.h"

@implementation CLStandardContentImage

+(CLStandardContentImage *) imageFromField:(CLInput *) aField table:(CLString *) aTable
{
  CLStandardContentImage *pImage = nil;
  CLOriginalImage *anImage;


  if ((anImage = [CLOriginalImage imageFromField:aField table:aTable])) {
    [CLDefaultContext saveChanges];
    pImage = [[self alloc] initFromDictionary:nil table:aTable];
    [pImage setObjectID:[anImage objectID]];
    [pImage addObject:anImage toBothSidesOfRelationship:@"image"];
    //    [pImage saveToDatabase];
  }

  return pImage;
}

+(CLStandardContentImage *) imageFromFile:(CLString *) aFilename table:(CLString *) aTable
{
  CLStandardContentImage *pImage = nil;
  CLOriginalImage *anImage;


  if ((anImage = [CLOriginalImage imageFromFile:aFilename table:aTable])) {
    [CLDefaultContext saveChanges];
    pImage = [[self alloc] initFromDictionary:nil table:aTable];
    [pImage setObjectID:[anImage objectID]];
    //    [pImage saveToDatabase];
  }

  return pImage;
}

-(CLComparisonResult) comparePosition:(id) anImage
{
  int pos1, pos2;


  pos1 = [self position];
  pos2 = [anImage position];
  if (pos1 < pos2)
    return CLOrderedAscending;
  if (pos1 > pos2)
    return CLOrderedDescending;
  return CLOrderedSame;
}

-(BOOL) isAudio
{
  return [[self image] isAudio];
}

-(BOOL) isVideo
{
  return [[self image] isVideo];
}

-(BOOL) isImage
{
  return [[self image] isImage];
}

-(BOOL) isPDF
{
  return [[self image] isPDF];
}

-(void) download:(id) sender
{
  [[self image] download:sender];
  return;
}

-(void) view:(id) sender
{
  [[self image] view:sender];
  return;
}

-(CLString *) mimeType
{
  return [[self image] mimeType];
}

-(BOOL) willDelete
{
  return willDelete;
}

-(void) setWillDelete:(BOOL) flag
{
  willDelete = flag;
  return;
}

@end
