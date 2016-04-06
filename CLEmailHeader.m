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

#import "CLEmailHeader.h"
#import "CLRange.h"
#import "CLMutableString.h"
#import "CLAutoreleasePool.h"
#import "CLCharacterSet.h"
#import "CLMutableArray.h"
#import "CLPage.h"

@implementation CLEmailHeader

-(id) init
{
  return [self initFromString:nil];
}

-(id) initFromString:(CLString *) aString
{
  [super init];
  headers = [[CLMutableArray alloc] init];
  values = [[CLMutableArray alloc] init];
  if (aString)
    [self setHeadersFromString:aString];
  return self;
}

-(void) dealloc
{
  [headers release];
  [values release];
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
  CLEmailHeader *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->headers = [headers copy];
  aCopy->values = [values copy];
  
  return aCopy;
}

-(void) setHeadersFromString:(CLString *) aString
{
  CLRange aRange, aRange2, aRange3;
  CLMutableString *mString;
  CLUInteger pos, end;
  CLAutoreleasePool *pool;
  CLCharacterSet *notWset = [[CLCharacterSet whitespaceAndNewlineCharacterSet] invertedSet];


  pool = [[CLAutoreleasePool alloc] init];
  
  [headers removeAllObjects];
  [values removeAllObjects];
  
  mString = [aString mutableCopy];
  [mString replaceOccurrencesOfString:@"\r\n" withString:@"\n"];
  [mString replaceOccurrencesOfString:@"\r" withString:@"\n"];
  [mString replaceOccurrencesOfString:@"\n\t" withString:@" "];
  [mString replaceOccurrencesOfString:@"\n " withString:@" "];

  aRange = [mString rangeOfString:@"\n\n" options:0 range:CLMakeRange(0, [mString length])];
  if (aRange.length)
    end = aRange.location + 1;
  else
    end = [mString length];
  
  pos = 0;
  while (pos < end) {
    aRange = [mString rangeOfString:@"\n" options:0 range:CLMakeRange(pos, end - pos)];
    if (!aRange.length)
      aRange.location = end;

    if (!pos && [[mString substringWithRange:CLMakeRange(pos, aRange.location-pos)]
		  hasPrefix:@"From "]) {
      aRange2.location = 5;
      aRange2.length = 0;
    }
    else {
      aRange2 = [mString rangeOfString:@":" options:0
				 range:CLMakeRange(pos, aRange.location-pos)];
      if (!aRange2.length) {
	/* Bail-out, invalid header */
	break;
      }
    }

    aRange3.location = CLMaxRange(aRange2);
    aRange3.length = aRange.location - aRange3.location;
    aRange3 = [mString rangeOfCharacterFromSet:notWset options:0 range:aRange3];
    if (!aRange3.length)
      aRange3.location = CLMaxRange(aRange2);
    [self appendHeader:[mString substringWithRange:CLMakeRange(pos, aRange2.location - pos)]
	  withValue:[mString substringWithRange:
			       CLMakeRange(aRange3.location,
					   aRange.location - aRange3.location)]];
    pos = CLMaxRange(aRange);
  }
  
  [mString release];
  [pool release];
  
  return;
}

-(CLUInteger) indexOfHeader:(CLString *) aHeader startingIndex:(CLUInteger) index
{
  CLUInteger i, j;


  for (i = index, j = [headers count]; i < j; i++)
    if (![[headers objectAtIndex:i] caseInsensitiveCompare:aHeader])
      return i;

  return CLNotFound;
}

-(id) valueOfHeader:(CLString *) aHeader
{
  CLUInteger index;


  if ((index = [self indexOfHeader:aHeader startingIndex:0]) != CLNotFound)
    return [values objectAtIndex:index];

  return nil;
}

-(void) appendHeader:(CLString *) aHeader withValue:(id) aValue
{
  aHeader = [aHeader copy];
  [headers addObject:aHeader];
  [aHeader release];
  [values addObject:aValue];
  return;
}

-(void) setValue:(id) aValue forHeader:(CLString *) aHeader
{
  CLUInteger index, delIndex;


  if ((index = [self indexOfHeader:aHeader startingIndex:0]) != CLNotFound) {
    [headers removeObjectAtIndex:index];
    aHeader = [aHeader copy];
    [headers insertObject:aHeader atIndex:index];
    [aHeader release];
    [values removeObjectAtIndex:index];
    [values insertObject:aHeader atIndex:index];
    while ((delIndex = [self indexOfHeader:aHeader startingIndex:index+1]) != CLNotFound) {
      [headers removeObjectAtIndex:delIndex];
      [values removeObjectAtIndex:delIndex];
    }
  }
  else
    [self appendHeader:aHeader withValue:aValue];

  return;
}

-(void) removeHeader:(CLString *) aHeader
{
  CLUInteger delIndex;
  

  while ((delIndex = [self indexOfHeader:aHeader startingIndex:0]) != CLNotFound) {
    [headers removeObjectAtIndex:delIndex];
    [values removeObjectAtIndex:delIndex];
  }

  return;
}

-(CLString *) description
{
  int i, j;
  CLMutableString *mString;


  mString = [[CLMutableString alloc] init];
  for (i = 0, j = [headers count]; i < j; i++) {
    [mString appendString:[headers objectAtIndex:i]];
    [mString appendString:@": "];
    [mString appendString:[values objectAtIndex:i]];
    [mString appendString:@"\n"];
  }

  return [mString autorelease];
}

-(void) updateBindings:(id) datasource
{
  int i, j;
  CLPage *aPage;
  CLData *aData;
  CLString *aString;


  for (i = 0, j = [values count]; i < j; i++) {
    aPage = [[CLPage alloc] initFromString:[values objectAtIndex:i] owner:datasource];
    [aPage updateBindings];
    aData = [aPage htmlForBody];
    [values removeObjectAtIndex:i];
    aString = [CLString stringWithData:aData encoding:CLUTF8StringEncoding];
    aString = [aString stringByReplacingOccurrencesOfString:@"\r\n" withString:@"\n"];
    aString = [aString stringByReplacingOccurrencesOfString:@"\r" withString:@""];
    aString = [aString stringByReplacingOccurrencesOfString:@"\n" withString:@"\n\t"];
    [values insertObject:aString atIndex:i];
    [aPage release];
  }

  return;
}

-(CLArray *) headers
{
  return headers;
}

@end
