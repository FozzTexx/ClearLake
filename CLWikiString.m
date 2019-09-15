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

#import "CLWikiString.h"
#import "CLWikiImage.h"
#import "CLWikiMedia.h"
#import "CLWikiLink.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLMutableDictionary.h"
#import "CLImageRep.h"
#import "CLNull.h"
#import "CLNumber.h"
#import "CLClassConstants.h"

#include <unistd.h>
#include <stdlib.h>
#include <wctype.h>

@interface CLWikiString (CLPrivateMethods)
-(CLMutableArray *) parseString:(CLString *) source;
@end

@implementation CLWikiString

-(id) init
{
  [super init];
  return self;
}	

-(id) initFromString:(CLString *) aString
{
  [super init];
  contents = [[self parseString:aString] retain];
  return self;
}

-(void) dealloc
{
  [contents release];
  [super dealloc];
  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLWikiString *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->contents = [contents copy];
  return aCopy;
}

-(CLString *) propertyList
{
  return [[self description] propertyListString];
}

-(CLString *) description
{
  int i, j;
  CLMutableString *result = [[CLMutableString alloc] init];
  id obj;

	
  for (i = 0, j = [contents count]; i < j; ++i) {
    obj = [contents objectAtIndex:i];
    [result appendString:[obj description]];
  }

  return [result autorelease];
}

-(CLString *) html
{
  int i, j;
  CLMutableString *result = [[CLMutableString alloc] init];
  id obj;

	
  for (i = 0, j = [contents count]; i < j; ++i) {
    obj = [contents objectAtIndex:i];
    if ([obj respondsTo:@selector(html)])
      [result appendString:[obj html]];
    else
      [result appendString:[obj description]];
  }

  return [result autorelease];
}

-(id) buildObjectFromName:(CLString *) objName andArgs:(CLMutableDictionary *) args
{
  id anObject = nil;


  if (![objName caseInsensitiveCompare:@"image"])
    anObject = [[CLWikiImage alloc] initWithAttributes:args];
  else if (![objName caseInsensitiveCompare:@"link"])
    anObject = [[CLWikiLink alloc] initWithAttributes:args];
  else if (![objName caseInsensitiveCompare:@"media"])
    anObject = [[CLWikiMedia alloc] initWithAttributes:args];
    
  return [anObject autorelease];
}

-(void) addParamsFromString:(CLString *) aString
	     intoDictionary:(CLMutableDictionary *) mDict
{
  unichar ch, inString, *buf;
  CLString *key, *value;
  int indx, len, begin;


  buf = calloc([aString length], sizeof(unichar));
  [aString getCharacters:buf];
  
  indx = 0;
  len = [aString length];
  while (indx < len) {
    for (begin = indx; indx < len; indx++) {
      ch = buf[indx];
      if (ch == '=' || iswspace(ch))
	break;
    }
    key = [[CLString alloc] initWithCharacters:&buf[begin] length:indx -begin];

    if (indx < len && ch == '=') {
      indx++;
      while (indx < len && iswspace(buf[indx]))
	indx++;

      if (indx < len && buf[indx] == '"') {
	inString = buf[indx];
	indx++;
	begin = indx;
	while (indx < len && buf[indx] != inString)
	  indx++;
      }
      else {
	begin = indx;
	while (indx < len && !iswspace(buf[indx]))
	  indx++;
      }

      value = [[CLString alloc] initWithCharacters:&buf[begin] length:indx -begin];
      [mDict setObject:value forKey:key];
      [value release];
      if (indx < len && buf[indx] == '"')
	indx++;
    }
    else
      [mDict setObject:CLNullObject forKey:key];
    [key release];

    while (indx < len && iswspace(buf[indx]))
      indx++;
  }
  free(buf);

  return;
}

-(id) createObjectFromString:(CLString *) objectString
{
  CLString *objName, *rest;
  CLMutableDictionary *params = nil;
  id anObject = objectString;
  CLRange rngEquals, rngSpace;


  rngEquals = [objectString rangeOfString:@" "];
  if (rngEquals.length) {
    rngSpace = [objectString rangeOfString:@" "];
    objName = [objectString substringToIndex:rngSpace.location];
    rest = [[objectString substringFromIndex:rngSpace.location + 1]
	     stringByReplacingOccurrencesOfString:@"&quot;" withString:@"\""];
    params = [[CLMutableDictionary alloc] init];
    [self addParamsFromString:rest intoDictionary:params];
  }
  else
    objName = objectString;

  anObject = [self buildObjectFromName:objName andArgs:params];
  [params release];

  return anObject;
}

/*
 TODO:
 1- handle invalid input ([[ count and ]] count don't match, nested [[ or ]], etc.
 */
-(CLMutableArray *) parseString:(CLString *) source
{
  CLMutableArray *results = [[CLMutableArray alloc] init];
  CLRange aRange, beginRange, endRange;
  CLUInteger len;
  CLString *str;
  id object;


  len = [source length];
  aRange.location = 0;
  aRange.length = len;
  while (aRange.length) {
    beginRange = [source rangeOfString:@"[[" options:0 range:aRange];
    if (!beginRange.length)
      break;
    
    endRange.location = CLMaxRange(beginRange);
    endRange.length = len - endRange.location;
    endRange = [source rangeOfString:@"]]" options:0 range:endRange];
    if (!endRange.length)
      break;

    if (beginRange.location) {
      aRange.length = beginRange.location - aRange.location;
      [results addObject:[source substringWithRange:aRange]];
    }
    
    aRange.location = CLMaxRange(beginRange);
    aRange.length = endRange.location - aRange.location;
    str = [source substringWithRange:aRange];
    object = [self createObjectFromString:str];
    if (!object) {
      aRange.location = beginRange.location;
      aRange.length = CLMaxRange(endRange) - aRange.location;
      object = [source substringWithRange:aRange];
    }
    [results addObject:object];

    aRange.location = CLMaxRange(endRange);
    aRange.length = len - aRange.location;
  }

  if (aRange.length)
    [results addObject:[source substringWithRange:aRange]];
    
  return [results autorelease];
}

-(CLMutableArray *) contents
{
  return contents;
}

-(CLArray *) filterByClass:(Class) klass
{
  CLMutableArray *filteredList = [[CLMutableArray alloc] init];
  int i, j;


  for (i = 0, j = [contents count]; i < j; ++i) {
    if ([[contents objectAtIndex:i] isKindOfClass:klass])
      [filteredList addObject:[contents objectAtIndex:i]];
  }

  return [filteredList autorelease];
}

-(CLArray *) images
{
  return [self filterByClass:CLWikiImageClass];
}
  
-(CLArray *) links
{
  return [self filterByClass:CLWikiLinkClass];
}

-(CLArray *) media
{
  return [self filterByClass:CLWikiMediaClass];
}

-(void) unlinkImages
{
  CLArray *anArray;
  int i, j;


  anArray = [self images];
  for (i = 0, j = [anArray count]; i < j; i++)
    unlink([CLPathForImageID([[[anArray objectAtIndex:i] imageID] intValue]) UTF8String]);

  return;
}

-(void) unlinkMedia
{
  CLArray *anArray;
  int i, j;


  anArray = [self media];
  for (i = 0, j = [anArray count]; i < j; i++)
    unlink([CLPathForFileID([[[anArray objectAtIndex:i] fileID] intValue]) UTF8String]);

  return;
}

@end
