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

#import "CLOriginalImage.h"
#import "CLCachedImage.h"
#import "CLDictionary.h"
#import "CLData.h"
#import "CLImageRep.h"
#import "CLArray.h"
#import "CLDatabase.h"
#import "CLRelationship.h"

#include <unistd.h>

@implementation CLOriginalImage

+(CLOriginalImage *) imageFromField:(CLField *) aField table:(CLString *) aTable
{
  return [self fileFromField:aField table:aTable];
}

+(CLOriginalImage *) imageFromFile:(CLString *) aFilename table:(CLString *) aTable
{
  return [self fileFromFile:aFilename table:aTable];
}

+(CLOriginalImage *) imageFromData:(CLData *) aData table:(CLString *) aTable
{
  return [self fileFromData:aData table:aTable];
}

-(void) dealloc
{
  [imageRep release];
  [super dealloc];
  return;
}

-(CLCachedImage *) cachedImageForEffects:(CLString *) aString
{
  CLArray *anArray;
  int i, j;
  CLCachedImage *anImage = nil;
  CLString *aPath, *query;
  CLRelationship *aRel;


  if (![_loaded containsObject:@"cachedImages"]) {
    query = [CLString stringWithFormat:@"parent_id = %i and effects = '%@'",
		      [self objectID], [[self database] defangString:aString escape:NULL]];
    aRel = [[_recordDef objectForKey:@"relationships"] objectForKey:@"cachedImages"];
    anArray = [CLGenericRecord loadTable:[aRel theirTable] qualifier:query];
    if ([anArray count])
      anImage = [anArray objectAtIndex:0];
  }
  else {
    anArray = [self cachedImages];
    for (i = 0, j = [anArray count]; i < j; i++)
      if ([[[anArray objectAtIndex:i] effects] isEqualToString:aString]) {
	anImage = [anArray objectAtIndex:i];
	break;
      }
  }

  if (anImage && (!(aPath = [anImage path]) || access([aPath UTF8String], R_OK))) {
    [anImage deleteFromDatabase];
    [self removeObject:anImage fromBothSidesOfRelationship:@"cachedImages"];
    anImage = nil;
  }
    
  return anImage;
}

-(id) imageRep
{
  CLString *aString;

  
  if (!imageRep && (aString = [self path]))
    imageRep = [[CLImageRep alloc] initFromFile:aString];
  return imageRep;
}

-(id) imageRepFromEffects:(CLString *) aString
{
  CLImageRep *aRep, *aRep2;
  int oid;
  CLCachedImage *cImage;
  CLData *aData;
  CLString *format;


  if (!(cImage = [self cachedImageForEffects:aString])) {
    aRep = [self imageRep];
    aRep2 = [aRep imageRepFromEffects:aString];
    format = [aRep bestFormat];
    aRep = aRep2;

    if ((aData = [aRep representationUsingFormat:format]) && (oid = CLStoreImage(aData))) {
      cImage = [[CLCachedImage alloc] init];
      [cImage setObjectID:oid];
      [cImage setEffects:aString];
      [cImage addObject:self toBothSidesOfRelationship:@"parent"];
      [cImage saveToDatabase];
      [cImage autorelease];
    }
  }

  return cImage;
}
  
-(CLData *) representationUsingFormat:(CLString *) format
{
  CLImageRep *aRep;
  CLData *aData;


  aRep = [self imageRep];
  aData = [aRep representationUsingFormat:format];
  return aData;
}

-(CLSize) size
{
  CLImageRep *aRep;
  CLSize aSize;


  aRep = [self imageRep];
  aSize = [aRep size];
  return aSize;
}

-(BOOL) isAudio
{
  return NO;
}

-(BOOL) isVideo
{
  return NO;
}

-(BOOL) isImage
{
  return YES;
}

/* Backwards compatibility with old CL API */
-(BOOL) deleteFromDatabase
{
  unlink([CLPathForImageID([self objectID]) UTF8String]);
  return [super deleteFromDatabase];
}

-(CLString *) path
{
  return CLPathForImageID([self objectID]);
}

-(CLString *) bestFormat
{
  return [[self imageRep] bestFormat];
}

@end
