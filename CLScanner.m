/* Copyright 2015-2016 by
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

#import "CLScanner.h"
#import "CLStringFunctions.h"

#include <wchar.h>
#include <errno.h>

@implementation CLScanner

+(CLScanner *) scannerWithString:(CLString *) aString
{
  return [[self alloc] initWithString:aString];
}

-(id) init
{
  return [self initWithString:nil];
}

-(id) initWithString:(CLString *) aString
{
  [super init];
  string = [aString retain];
  if (string)
    string = (CLString *) CLStringToUnistr(string);
  pos = 0;
  return self;
}

-(void) dealloc
{
  [string release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLScanner *aCopy;


  aCopy = [super copy];
  aCopy->string = [string retain];
  aCopy->pos = pos;
  return aCopy;
}

-(BOOL) scanDouble:(double *) aDouble
{
  unistr *ustr = (unistr *) string;
  unichar *end;
  double val;


  if (pos >= ustr->len)
    return NO;
  
  errno = 0;
  end = NULL;
  val = wcstod(ustr->str + pos, &end);
  if ((!end || end == ustr->str) && errno)
    return NO;
  *aDouble = val;
  pos = end - ustr->str;
  return YES;
}

@end
