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

#import "CLWikiLink.h"
#import "CLMutableDictionary.h"
#import "CLString.h"
#import "CLManager.h"
#import "CLMutableString.h"
#import "CLArray.h"
#import "CLBlock.h"
#import "CLPage.h"

@implementation CLWikiLink

-(CLString *) href
{
  CLString *aString = nil;

  
  if ([CLDelegate respondsTo:@selector(hrefForWikiLink:)])
    aString = [CLDelegate hrefForWikiLink:self];
  return aString;
}

-(CLString *) content
{
  CLString *aString;
  
  
  aString = [attributes objectForCaseInsensitiveString:@"text"];
  if (!aString)
    aString = [attributes objectForCaseInsensitiveString:@"href"];
  return aString;
}

-(CLString *) wikiClassName
{
  return @"link";
}

@end
