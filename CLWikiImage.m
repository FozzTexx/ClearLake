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

#import "CLWikiImage.h"
#import "CLArray.h"
#import "CLMutableString.h"
#import "CLPage.h"
#import "CLMutableDictionary.h"
#import "CLOriginalImage.h"
#import "CLBlock.h"
#import "CLImageRep.h"
#import "CLNumber.h"
#import "CLField.h"

#include <unistd.h>

@implementation CLWikiImage

-(CLNumber *) imageID
{
  return [attributes objectForCaseInsensitiveString:@"id"];
}

-(CLOriginalImage *) image
{
  CLOriginalImage *anImage = nil;
  int oid;

  
  if ((oid = [[self imageID] intValue]))
    anImage = [[CLOriginalImage alloc] initFromObjectID:oid];
  return [anImage autorelease];
}

-(void) setImageID:(CLNumber *) aValue
{
  [attributes setObject:aValue forCaseInsensitiveString:@"id"];
  return;
}

-(BOOL) setImageFromField:(CLField *) aField
{
  CLData *aData;
  int oid;


  if ((oid = [[self imageID] intValue]))
    unlink([CLPathForImageID(oid) UTF8String]);
    
  aData = [[aField value] data];
  if ((oid = CLStoreImage(aData))) {
    [self setImageID:[CLNumber numberWithInt:oid]];
    return YES;
  }

  return NO;
}

-(CLString *) wikiClassName
{
  return @"image";
}

@end
