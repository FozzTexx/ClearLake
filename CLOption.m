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

#import "CLOption.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"

@implementation CLOption

+(CLOption *) optionWithString:(CLString *) aString andValue:(id) aValue
{
  return [self optionWithString:aString andValue:aValue selected:NO];
}

+(CLOption *) optionWithString:(CLString *) aString andValue:(id) aValue
		      selected:(BOOL) flag
{
  return [[[self alloc] initWithString:aString andValue:aValue selected:flag] autorelease];
}

-(id) initWithString:(CLString *) aString andValue:(id) aValue
{
  return [self initWithString:aString andValue:aValue selected:NO];
}

-(id) initWithString:(CLString *) aString andValue:(id) aValue selected:(BOOL) flag
{
  [super init];
  [title release];
  title = [aString copy];
  value = [aValue retain];
  selected = flag;
  attributes = [[CLMutableDictionary alloc] init];
  return self;
}

-(void) dealloc
{
  [value release];
  [subOptions release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLOption *aCopy;


  aCopy = [super copy];
  aCopy->value = [value retain];
  aCopy->subOptions = [subOptions copy];
  return aCopy;
}

-(id) value
{
  return value;
}

-(CLString *) string
{
  return title;
}

-(BOOL) selected
{
  return selected;
}

-(CLArray *) subOptions
{
  return subOptions;
}

-(CLMutableDictionary *) attributes
{
  return attributes;
}

-(void) setValue:(id) anObject
{
  [value autorelease];
  value = [anObject retain];
  return;
}

-(void) setString:(CLString *) aString
{
  [self setTitle:aString];
  return;
}

-(void) setSelected:(BOOL) flag
{
  selected = flag;
  return;
}

-(void) addSubOption:(CLOption *) anOption
{
  if (!subOptions)
    subOptions = [[CLMutableArray alloc] init];
  [subOptions addObject:anOption];
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  CLPrintf(stream, @"<OPTION");
  if (selected)
    CLPrintf(stream, @" SELECTED");
  if (value)
    CLPrintf(stream, @" VALUE=\"%@\"", [[value description] entityEncodedString]);
  [self writeAttributes:attributes to:stream];
  CLPrintf(stream, @">");
  CLPrintf(stream, @"%@", [title entityEncodedString]);
  CLPrintf(stream, @"</OPTION>");
  return;
}
  
@end
