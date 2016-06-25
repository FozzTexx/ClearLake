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

#import "CLWikiImage.h"
#import "CLArray.h"
#import "CLMutableString.h"
#import "CLPage.h"
#import "CLMutableDictionary.h"
#import "CLOriginalImage.h"
#import "CLBlock.h"
#import "CLImageRep.h"
#import "CLNumber.h"
#import "CLEditingContext.h"
#import "CLStandardContent.h"
#import "CLInput.h"
#import "CLWikiString.h"

#include <unistd.h>

@implementation CLWikiImage

+(void) load
{
  CLWikiImageClass = [CLWikiImage class];
  return;
}

-(CLNumber *) imageID
{
  return [attributes objectForCaseInsensitiveString:@"id"];
}

-(CLOriginalImage *) image
{
  CLOriginalImage *anImage = nil;
  int oid;

  
  if ((oid = [[self imageID] intValue]))
    anImage = [CLDefaultContext loadObjectWithClass:[CLOriginalImage imageClass] objectID:oid];
  return [anImage autorelease];
}

-(void) setImageID:(CLNumber *) aValue
{
  [attributes setObject:aValue forCaseInsensitiveString:@"id"];
  return;
}

-(BOOL) setImageFromField:(CLInput *) aField
{
  CLData *aData;
  int oid;


  if ((oid = [[self imageID] intValue]))
    unlink([CLPathForImageID(oid) UTF8String]);
    
  aData = [[aField value] data];
  if ((oid = CLStoreImage(aData))) {
    [[aField value] setObjectID:oid];
    [self setImageID:[CLNumber numberWithInt:oid]];
    return YES;
  }
  else {
    [[[aField value] editingContext] removeObject:[aField value]];
    [aField setValue:nil];
  }

  return NO;
}

-(CLString *) wikiClassName
{
  return @"image";
}

@end
