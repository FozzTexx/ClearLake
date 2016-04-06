/* Copyright 2013-2016 by
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

#import "CLSelect.h"
#import "CLMutableDictionary.h"
#import "CLCharacterSet.h"
#import "CLMutableArray.h"
#import "CLOption.h"

Class CLSelectClass;

@implementation CLSelect

+(void) load
{
  CLSelectClass = [CLSelect class];
  return;
}

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  [super initFromElement:anElement onPage:aPage];
  [value release];
  value = [[CLMutableArray alloc] init];
  return self;
}

-(void) addOption:(CLString *) aString withValue:(id) aValue
{
  aString = [aString stringByTrimmingCharactersInSet:
		       [CLCharacterSet whitespaceAndNewlineCharacterSet]];
  if (![aString length])
    aString = nil;
  if (!aString && !aValue)
    return;
  
  if (!aValue && [value count] && ![[value lastObject] string])
    [[value lastObject] setString:aString];
  else
    [value addObject:[[[CLOption alloc]
			initWithString:aString andValue:aValue] autorelease]];
  
  return;
}

-(void) removeAllOptions
{
  [value removeAllObjects];
  return;
}

-(void) addObject:(id) anObject
{
  if ([anObject isKindOfClass:CLElementClass]) {
    [self addOption:nil withValue:[[anObject attributes]
				    objectForCaseInsensitiveString:@"VALUE"]];
    if ([[anObject attributes] objectForCaseInsensitiveString:@"SELECTED"])
      [self selectOptionWithValue:[[anObject attributes]
				    objectForCaseInsensitiveString:@"VALUE"]];
  }
  else
    [self addOption:anObject withValue:nil];

  return;
}

-(void) selectOptionWithValue:(id) aValue
{
  int i, j;
  CLOption *anOption;
  id optionValue;

  
  if (!aValue)
    return;

  aValue = [aValue description];
  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    if (!(optionValue = [anOption value]))
      optionValue = [anOption string];
    optionValue = [optionValue description];
    [anOption setSelected:[optionValue isEqual:aValue]];
  }

  return;
}

-(void) selectOptionWithName:(CLString *) aString
{
  int i, j;
  CLOption *anOption;

  
  if (!aString)
    return;

  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    [anOption setSelected:[[anOption string] isEqualToString:aString]];
  }

  return;
}

-(void) selectOption:(int) index
{
  int i, j;
  CLOption *anOption;

  
  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    [anOption setSelected:i == index];
  }

  return;
}

-(CLOption *) selectedOption
{
  int i, j;
  CLOption *anOption;

  
  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    if ([anOption selected])
      return anOption;
  }

  return nil;
}

-(int) numOptions
{
  return [value count];
}

-(void) writeHTML:(CLStream *) stream
{
  int i, j;
  id aValue;
  BOOL found;


  if (![self isVisible])
    return;

  if ((aValue = [attributes objectForCaseInsensitiveString:@"CL_SELECTED"])) {
    aValue = [self objectValueForSpecialBinding:[aValue substringFromIndex:1] allowConstant:NO
					  found:&found wasConstant:NULL];
    [self selectOptionWithValue:aValue];
  }
  
  CLPrintf(stream, @"<SELECT");
  [self writeAttributes:stream ignore:nil];
  CLPrintf(stream, @">");
  for (i = 0, j = [value count]; i < j; i++)
    [[value objectAtIndex:i] writeHTML:stream];
  CLPrintf(stream, @"</SELECT>");

  return;
}

@end
