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

#import "CLRegularExpression.h"
#import "CLString.h"
#import "CLValue.h"
#import "CLMutableArray.h"

#include <pcre.h>
#include <string.h>

@implementation CLRegularExpression

+(CLRegularExpression *) regularExpressionFromString:(CLString *) aString
{
  return [[[self alloc] initFromString:aString options:0] autorelease];
}

-(id) init
{
  return [self initFromString:nil options:0];
}

-(id) initFromString:(CLString *) aString options:(CLUInteger) options
{
  const char *error;
  int erroffset;
  int pcreOptions;
  
  
  [super init];

  pcreOptions = PCRE_UTF8;
  if (options & CLAnchoredSearch)
    pcreOptions |= PCRE_ANCHORED;
  if (options & CLCaseInsensitiveSearch)
    pcreOptions |= PCRE_CASELESS;
  
  if (!(comp = pcre_compile([aString UTF8String], pcreOptions, &error, &erroffset, NULL)))
    [self error:@"Invalid regular expression: \"%@\" %s", aString, error];
  
  return self;
}

-(void) dealloc
{
  if (comp)
    pcre_free(comp);
  [super dealloc];
  return;
}

-(id) copy
{
  return [self retain];
}

-(BOOL) matchesString:(CLString *) aString
{
  return [self matchesString:aString range:CLMakeRange(0, [aString length])
	       substringRanges:NULL];
}

-(BOOL) matchesString:(CLString *) aString substringRanges:(CLArray **) ranges
{
  return [self matchesString:aString range:CLMakeRange(0, [aString length])
	       substringRanges:ranges];
}
  
-(BOOL) matchesString:(CLString *) aString range:(CLRange) aRange
      substringRanges:(CLArray **) ranges
{
  int res;
  const char *p;
  const unsigned char *up;
  int len, ns;
  int *ovector;
  int ovecsize;
  CLMutableArray *mArray;
  int i;
  int bpos, cpos;
  CLRange subRange;
  int err;


  aString = [aString substringWithRange:aRange];
  
  if (!aString)
    return NO;
  
  p = [aString UTF8String];
  len = strlen(p);
  if ((err = pcre_fullinfo(comp, NULL, PCRE_INFO_CAPTURECOUNT, &ns)))
    [self error:@"Some kind of error with pcre_fullinfo: %i", err];
  ovecsize = (ns + 1) * 3;
  if (!(ovector = calloc(ovecsize, sizeof(int))))
    [self error:@"Unable to allocate memory"];
  res = pcre_exec(comp, NULL, p, len, 0, 0, ovector, ovecsize);

  if (res > 0 && ranges) {
    mArray = [[CLMutableArray alloc] init];

    up = (unsigned char *) p;
    for (bpos = cpos = 0; bpos <= len; bpos++, cpos++) {
      for (i = 0; i < res; i++) {
	if (ovector[i*2] == bpos)
	  ovector[i*2] = cpos;
	if (ovector[i*2+1] == bpos)
	  ovector[i*2+1] = cpos;
      }
      
      if (up[bpos] == 192 || up[bpos] == 193 ||
	  (up[bpos] >= 194 && up[bpos] <= 223))
	bpos++;
      else if (up[bpos] >= 224 && up[bpos] <= 239)
	bpos += 2;
      else if ((up[bpos] >= 240 && up[bpos] <= 244) ||
	       (up[bpos] >= 245 && up[bpos] <= 247))
	bpos += 3;
      else if (up[bpos] >= 248 && up[bpos] <= 251)
	bpos += 4;
      else if (up[bpos] == 252 || up[bpos] == 253)
	bpos += 5;
    }
      
    for (i = 0; i < res; i++) {
      subRange = CLMakeRange(ovector[i*2], ovector[i*2+1] - ovector[i*2]);
      subRange.location += aRange.location;
      [mArray addObject:[CLValue valueWithRange:subRange]];
    }
    *ranges = [mArray autorelease];
  }
  
  free(ovector);

  if (res > 0)
    return YES;

  return NO;
}

@end
