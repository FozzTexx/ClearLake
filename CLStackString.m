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

#import "CLStackString.h"

@implementation CLMutableStackString

/* FIXME - probably should block appendFormat: since it sort of
   defeats the purpose of a stack allocated string because it will
   need malloc/free to do the printf. */

-(void) replaceCharactersInRange:(CLRange) aRange withString:(CLString *) aString
{
  CLStringStorage *stor;
  CLUInteger newlen;

  
  stor = CLStorageForString(self);
  newlen = len - aRange.length;
  if (aString) {
    CLCheckStringClass(aString);
    newlen += aString->len;
  }
  if (newlen > stor->maxLen)
    [self error:@"Buffer overrun"];
  CLUnistrReplace((unistr *) self, aRange, (unistr *) aString);
  return;
}

#if DEBUG_RETAIN
#undef retain
#undef release
#undef autorelease
#undef retainCount
#endif

-(id) retain
{
  [self error:@"You can't retain this!"];
  return self;
}

-(void) release
{
  return;
}

-(id) autorelease
{
  return self;
}

-(CLUInteger) retainCount
{
  return 1;
}

-(const char *) UTF8String
{
  char *buf;
  CLUInteger blen;
  unistr *ustr;


  ustr = (unistr *) self;
  CLStringConvertEncoding((char *) ustr->str, ustr->len * sizeof(unichar),
			  CLUnicodeStringEncoding,
			  &buf, &blen, CLUTF8StringEncoding, NO);
  buf[blen] = 0;
  return buf;
}

@end

@implementation CLImmutableStackString

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLString *aString = [self mutableCopy];


  aString->isa = CLStringClass;
  return aString;
}

-(id) retain
{
  [self error:@"You can't retain this!"];
  return self;
}

-(void) release
{
  return;
}

-(id) autorelease
{
  return self;
}

-(CLUInteger) retainCount
{
  return 1;
}

-(const char *) UTF8String
{
  char *buf;
  CLUInteger blen;
  unistr *ustr;


  ustr = (unistr *) self;
  CLStringConvertEncoding((char *) ustr->str, ustr->len * sizeof(unichar),
			  CLUnicodeStringEncoding,
			  &buf, &blen, CLUTF8StringEncoding, NO);
  buf[blen] = 0;
  return buf;
}

@end

