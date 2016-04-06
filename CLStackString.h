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

#ifndef _CLSTACKSTRING_H
#define _CLSTACKSTRING_H

#import <ClearLake/CLMutableString.h>
#import <ClearLake/CLRuntime.h>
#import <ClearLake/CLStringFunctions.h>

@interface CLMutableStackString:CLMutableString
@end

@interface CLImmutableStackString:CLString
@end

CL_INLINE unistr CLNewStackString(CLUInteger len)
{
  unistr ustr;
  CLStringStorage *stor;


  ustr._reserved = CLMutableStackStringClass;
  ustr.len = 0;
  stor = alloca(len * sizeof(unichar) + sizeof(CLStringStorage));
  stor->maxLen = len;
  stor->utf8 = NULL;
  stor->hash = 0;
  stor->hashSet = 0;
  ustr.str = ((void *) stor) + sizeof(CLStringStorage);  
  return ustr;
}

CL_INLINE unistr CLCopyStackString(CLString *aString, CLUInteger extra)
{
  unistr ustr;
  unistr *pstr;


  pstr = CLStringToUnistr(aString);
  ustr = CLNewStackString(pstr->len + extra);
  ustr.len = pstr->len;
  wmemmove(ustr.str, pstr->str, ustr.len);
  return ustr;
}

CL_INLINE unistr CLMakeStackString(unichar *str, CLUInteger len)
{
  unistr ustr;


  ustr._reserved = CLImmutableStackStringClass;
  ustr.len = len;
  ustr.str = str;
  return ustr;
}

CL_INLINE unistr CLCloneStackString(CLString *aString)
{
  unistr ustr;
  unistr *pstr;


  pstr = CLStringToUnistr(aString);
  ustr._reserved = CLImmutableStackStringClass;
  ustr.len = pstr->len;
  ustr.str = pstr->str;
  return ustr;
}

#endif /* _CLSTACKSTRING_H */
