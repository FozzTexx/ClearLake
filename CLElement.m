/* Copyright 1995-2007 by Chris Osborn <fozztexx@fozztexx.com>
 *
 * Copyright 2008-2016 by
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

#import "CLElement.h"
#import "CLString.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLPage.h"
#import "CLBlock.h"
#import "CLNull.h"
#import "CLNumber.h"
#import "CLExpression.h"
#import "CLManager.h"
#import "CLDecimalNumber.h"
#import "CLOption.h"
#import "CLScriptElement.h"
#import "CLRangeView.h"
#import "CLSplitter.h"
#import "CLPager.h"
#import "CLChainedSelect.h"
#import "CLStackString.h"

#include <wctype.h>
#include <stdlib.h>
#include <ctype.h>

#define MAX_HASH	10

@class CLField, CLImageElement, CLOption, CLScriptElement, CLRangeView, CLSplitter, CLPager,
  CLChainedSelect;
Class CLElementClass, CLBlockClass, CLOptionClass, CLScriptElementClass,
  CLRangeViewClass, CLSplitterClass, CLPagerClass, CLChainedSelectClass;

@implementation CLElement

+(void) load
{
  CLElementClass = [CLElement class];
  CLBlockClass = [CLBlock class];
  //  CLScriptElementClass = [CLScriptElement class];
  return;
}

+(id) expandBinding:(id) aBinding using:(id) anElement success:(BOOL *) success
{
  int i, nc, last;
  CLRange aRange;
  CLString *aValue;
  CLExpression *anExp;
  id anObject;
  BOOL flag;
  id expanded;
  unistr *bstr, *pstr;
  unistr ustr;
  id *components;


  if (![aBinding isKindOfClass:CLStringClass])
    return aBinding;
  
  *success = NO;

  bstr = CLStringToUnistr(aBinding);
  for (i = 0, nc = 1; i < bstr->len; i++)
    if (bstr->str[i] == ' ')
      nc++;

  components = alloca(sizeof(id) * nc);
  for (i = nc = 0, last = -1; i <= bstr->len; i++)
    if (i == bstr->len || bstr->str[i] == ' ') {
      if (i - last > 1) {
	pstr = alloca(sizeof(unistr));
	*pstr = CLMakeStackString(&bstr->str[last + 1], i - last - 1);
	aValue = components[nc] = (id) pstr;

	/* FIXME - let people escape the "=" */
	aRange = [aValue rangeOfString:@"="];
	if (aRange.length) {
	  ustr = *pstr;
	  ustr.str += CLMaxRange(aRange);
	  ustr.len -= CLMaxRange(aRange);
	  anExp = [[CLExpression alloc] initFromString:(CLString *) &ustr];
	  anObject = [anExp evaluate:anElement success:success];
	  [anExp release];

	  if (!aRange.location) {
	    aValue = anObject;
	    flag = YES;
	  }
	  else {
	    pstr->len = aRange.location;
	    aValue = (CLString *) pstr;
	    if ([anObject isKindOfClass:CLNumberClass])
	      flag = [anObject boolValue];
	    else
	      flag = !!anObject;
	  }

	  if (flag && aValue)
	    components[nc] = aValue;
	  else
	    nc--;
	}
	else
	  *success = YES;

	nc++;
      }      

      last = i;
    }

  if (!nc)
    expanded = nil;
  else if (nc == 1) {
    anObject = components[0];
    if ([anObject isKindOfClass:CLMutableStackStringClass] ||
	[anObject isKindOfClass:CLImmutableStackStringClass])
      anObject = [anObject copy];
    else
      [anObject retain];
    expanded = anObject;
  }
  else {
    CLMutableArray *mArray;


    mArray = [[CLMutableArray alloc] init];
    for (i = 0; i < nc; i++) {
      anObject = components[i];
      if ([anObject isKindOfClass:CLMutableStackStringClass] ||
	  [anObject isKindOfClass:CLImmutableStackStringClass])
	anObject = [anObject copy];
      else
	[anObject retain];
      [mArray addObject:anObject];
      [anObject release];
    }
    expanded = mArray;
  }
  return [expanded autorelease];
}

+(BOOL) expandBoolean:(id) aBinding using:(id) anElement
{
  id anObject;
  BOOL val, success;

  
  anObject = [anElement expandBinding:aBinding success:&success];
  if (anObject == CLNullObject)
    val = NO;
  else if ([anObject isKindOfClass:CLNumberClass])
    val = [anObject boolValue];
#if 0 /* FIXME - do we want to treat it as a bool or just check that it exists? */
  else if ([anObject isKindOfClass:CLStringClass])
    val = [anObject boolValue];
#endif
  else
    val = !!anObject;
  
  return val;
}
  
+(CLString *) expandClass:(CLString *) aString using:(CLElement *) anElement
{
  id expanded;
  BOOL success;


  expanded = [self expandBinding:aString using:anElement success:&success];
  if ([expanded isKindOfClass:CLArrayClass])
    expanded = [expanded componentsJoinedByString:@" "];
  else
    expanded = [expanded description];
  return expanded;
}
  
+(void) writeAttributes:(CLDictionary *) aDict using:(id) anElement to:(CLStream *) stream
{
  int i, j;
  CLArray *keys;
  CLString *aKey;
  id aValue;
  BOOL found;


  keys = [aDict allKeys];
  for (i = 0, j = [keys count]; i < j; i++) {
    aKey = [keys objectAtIndex:i];

    /* Not using hasPrefix: because I need case insensitive */
    if ([aKey length] >= 3 && ![aKey compare:@"CL_" options:CLCaseInsensitiveSearch
				     range:CLMakeRange(0, 3)]) {
      if (![aKey caseInsensitiveCompare:@"CL_CLASS"])
	aValue = [self expandClass:[aDict objectForKey:aKey] using:anElement];
      else {
	aValue = [self expandBinding:[aDict objectForKey:aKey] using:anElement success:&found];
	if ([aValue isKindOfClass:CLArrayClass])
	  aValue = [aValue componentsJoinedByString:@" "];
	if (!aValue && found)
	  aValue = CLNullObject;
      }
      aKey = [aKey substringFromIndex:3];
    }
    else
      aValue = [aDict objectForKey:aKey];

    if (aValue) {
      [stream writeFormat:@" %@" usingEncoding:CLUTF8StringEncoding, aKey];
      if (aValue != CLNullObject)
	[stream writeFormat:@"=\"%@\"" usingEncoding:CLUTF8StringEncoding,
		[[aValue description] entityEncodedString]];
    }
  }

  return;
}

-(id) init
{
  return [self initFromString:nil onPage:nil];
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage
{
  unichar *buf, *p, *q, stringMarker;
  CLString *key, *val;
  
  
  [super init];
  page = aPage;
  title = [aString copy];
  attributes = [[CLMutableDictionary alloc] initWithSize:MAX_HASH];

  if (aString) {
    if (!(buf = calloc([aString length]+1, sizeof(unichar))))
      [self error:@"Unable to allocate memory"];
    [aString getCharacters:buf];

    p = buf;
    while (*p && (*p == '<' || iswspace(*p)))
      p++;
    q = p;
    while (*q && *q != '>' && !iswspace(*q))
      q++;
    title = [[CLString alloc] initWithCharacters:p length:q-p];

    p = q;
    while (*p && !iswalpha(*p))
      p++;

    while (*p) {
      q = p;
      while (*q && *q != '=' && *q != '>' && !iswspace(*q))
	q++;
      key = [[CLString alloc] initWithCharacters:p length:q-p];
      while (iswspace(*q))
	q++;
      p = q+1;
      if (*q != '=')
	val = nil;
      else {
	while (iswspace(*p))
	  p++;
	q = p;
	if (*q == '"' || *q == '\'') {
	  stringMarker = *q;
	  q++;
	  p++;
	  while (*q && *q != stringMarker)
	    q++;
	}
	else {
	  while (*q && *q != '>' && !iswspace(*q))
	    q++;
	}
	val = [[CLString alloc] initWithCharacters:p length:q-p];
      }
      if (val)
	[attributes setObject:[val entityDecodedString] forCaseInsensitiveString:key];
      else
	[attributes setObject:CLNullObject forCaseInsensitiveString:key];
      [key release];
      [val release];

      p = q;
      while (*p && !iswalpha(*p))
	p++;
    }

    free(buf);
  }

  return self;
}

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  [self initFromString:nil onPage:aPage];

  [title release];
  title = [[anElement title] copy];
  [attributes release];
  attributes = [[anElement attributes] mutableCopy];
  
  return self;
}

-(void) dealloc
{
  [title release];
  [attributes release];
  [super dealloc];
  return;
}

/* These just exist to do the init */
-(id) read:(CLStream *) stream
{
  [super read:stream];
  attributes = [[CLMutableDictionary alloc] initWithSize:MAX_HASH];
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  return;
}

-(CLString *) title
{
  return title;
}

-(void) setTitle:(CLString *) aString
{
  [title autorelease];
  title = [aString copy];
  return;
}

-(CLMutableDictionary *) attributes
{
  return attributes;
}

-(CLPage *) page
{
  return page;
}

-(void) setPage:(CLPage *) aPage
{
  id oldDatasource = [[self datasource] retain];
  id newDatasource;

  
  page = aPage;
  newDatasource = [self datasource];
  if (newDatasource != oldDatasource)
    [self setDatasource:oldDatasource];
  [oldDatasource release];
  return;
}

-(CLBlock *) parentBlock
{
  return parentBlock;
}

-(void) setParentBlock:(id) aParent
{
  parentBlock = aParent;
  return;
}

-(id) datasource
{
  CLString *aString;
  BOOL success;
  id aDatasource;


  if (datasource)
    return datasource;

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_DATASOURCE"])) {
    if (parentBlock)
      aDatasource = [parentBlock expandBinding:aString success:&success];
    else
      aDatasource = [page datasourceForBinding:[aString substringFromIndex:1]];
    [self setDatasource:aDatasource];
    return datasource;
  }

  if (parentBlock)
    return [parentBlock datasource];

  return [page datasource];
}

-(void) setDatasource:(id) anObject
{
  if (anObject != datasource) {
#if 0
    fprintf(stdout, "<%s: 0x%lx> datasource: <%s: 0x%lx> anObject: <%s: 0x%lx> %s:%i\n",
	    [[self className] UTF8String], (unsigned long) self,
	    [[datasource className] UTF8String], (unsigned long) datasource,
	    [[anObject className] UTF8String], (unsigned long) anObject,
	    __FILE__, __LINE__);
#endif
    if (datasource != page)
      [datasource release];
    if (anObject != page)
      [anObject retain];
    datasource = anObject;
  }
  return;
}

-(id) objectValueForSpecialBinding:(CLString *) aBinding allowConstant:(BOOL) flag
			     found:(BOOL *) found wasConstant:(BOOL *) wasConst
{
  CLRange aRange;
  id anObject;
  CLUInteger index = 0;


  if (aBinding == CLNullObject)
    return nil;
  
  if (flag) {
    if ([aBinding isKindOfClass:CLStringClass] && [aBinding characterAtIndex:0] == '=') {
      index = 1;
      if ([aBinding characterAtIndex:index] == '!')
	index++;
      aBinding = [aBinding substringFromIndex:index];
      if (wasConst)
	*wasConst = NO;
    }
    else {
      *found = YES;
      return aBinding;
    }
  }

  if ([aBinding characterAtIndex:0] == '.') {
    anObject = self;
    aBinding = [aBinding substringFromIndex:1];
  }
  else {
    if ([aBinding hasPrefix:@"#"]) {
      aRange = [aBinding rangeOfString:@"." options:0
				 range:CLMakeRange(0, [aBinding length])];
      if (!aRange.length)
	aRange.location = [aBinding length];
      anObject = [[self page] objectWithID:[aBinding substringWithRange:
						       CLMakeRange(1, aRange.location-1)]];
      aBinding = [aBinding substringFromIndex:CLMaxRange(aRange)];      
    }
    else if ([aBinding hasPrefix:@"@"]) {
      aRange = [aBinding rangeOfString:@"." options:0
				 range:CLMakeRange(0, [aBinding length])];
      if (!aRange.length)
	aRange.location = [aBinding length];
      if (aRange.location == 1) {
	anObject = [self page];
	aBinding = [aBinding substringFromIndex:CLMaxRange(aRange)];
      }
    }
    else if ([CLDelegate respondsTo:@selector(datasourceForElement:binding:)])
      anObject = [CLDelegate datasourceForElement:self binding:&aBinding];
    else if (iswupper([aBinding characterAtIndex:0])) {
      aRange = [aBinding rangeOfString:@"." options:0
				 range:CLMakeRange(0, [aBinding length])];
      if (!aRange.length)
	aRange.location = [aBinding length];
      anObject = [[[objc_lookUpClass([[aBinding substringToIndex:aRange.location] UTF8String])
				    alloc] init] autorelease];
      aBinding = [aBinding substringFromIndex:CLMaxRange(aRange)];      
    }
    else
      anObject = [self datasource];
  }

  if ([aBinding length])
    anObject = [anObject objectValueForBinding:aBinding found:found];
  else
    *found = YES;
  
  if (anObject == CLNullObject)
    anObject = nil;

  if (index == 2) {
    if ([anObject isKindOfClass:CLNumberClass])
      anObject = [CLNumber numberWithBool:![anObject boolValue]];
    else
      anObject = [CLNumber numberWithBool:!anObject];
  }

  return anObject;
}

-(id) expandBinding:(id) aBinding success:(BOOL *) success
{
  return [[self class] expandBinding:aBinding using:self success:success];
}

-(BOOL) expandBoolean:(id) aBinding
{
  return [[self class] expandBoolean:aBinding using:self];
}

-(void) writeAttributes:(CLDictionary *) aDict to:(CLStream *) stream
{
  return [[self class] writeAttributes:aDict using:self to:stream];
}

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  CLString *aKey;
  CLMutableDictionary *mDict;
  int i, j;


  mDict = [attributes mutableCopy];  
  if (!ignore)
    ignore = [CLMutableArray array];
  
  [ignore addObjects:@"CL_VISIBLE", @"CL_SORT", @"CL_FORMAT", @"CL_AUTONUMBER",
	  @"CL_DATASOURCE", @"CL_BINDING", @"CL_DBINDING", @"CL_VARNAME", nil];
  
  for (i = 0, j = [ignore count]; i < j; i++) {
    aKey = [ignore objectAtIndex:i];
    if ([mDict objectForCaseInsensitiveString:aKey])
      [mDict removeObjectForCaseInsensitiveString:aKey];
  }

  [[self class] writeAttributes:mDict using:self to:stream];
  [mDict release];
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  [stream writeFormat:@"<%@" usingEncoding:CLUTF8StringEncoding, title];
  [[self class] writeAttributes:attributes using:self to:stream];
  [stream writeString:@">" usingEncoding:CLUTF8StringEncoding];

  return;
}

-(id) valueForExpression:(CLString *) aString success:(BOOL *) success
{
  BOOL wasConst = NO;
  id anObject;


  anObject = [self objectValueForSpecialBinding:aString allowConstant:NO
		   found:success wasConstant:&wasConst];
  if (!*success) {
    /* FIXME - do better number/constant recognition */
    if ([aString length] && isdigit([aString characterAtIndex:0]))
      return [CLDecimalNumber decimalNumberWithString:aString];
    anObject = nil;
  }

  return anObject;
}

-(BOOL) isVisible
{
  BOOL val = YES;
  id aBinding;


  if ((aBinding = [attributes objectForCaseInsensitiveString:@"CL_VISIBLE"]))
    val = [[self class] expandBoolean:aBinding using:self];
  return val;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLElement *aCopy;


  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
  aCopy->title = [title copy];
  aCopy->page = page;
  aCopy->attributes = [attributes mutableCopy];
  return aCopy;
}
#else
-(id) copy
{
  CLElement *aCopy;


  aCopy = [super copy];
  aCopy->title = [title copy];
  aCopy->page = page;
  aCopy->attributes = [attributes mutableCopy];
  return aCopy;
}
#endif

@end
