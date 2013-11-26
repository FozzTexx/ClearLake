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
#import <objc/objc-api.h>

#include <wctype.h>
#include <stdlib.h>
#include <ctype.h>

#define MAX_HASH	10

@implementation CLElement

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
      while(iswspace(*q))
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
	[attributes setObject:[CLNull null] forCaseInsensitiveString:key];
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

-(id) copy
{
  CLElement *aCopy;


  aCopy = [super copy];
  aCopy->title = [title copy];
  aCopy->page = page;
  aCopy->attributes = [attributes mutableCopy];
  return aCopy;
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

-(void) setParentBlock:(CLBlock *) aParent
{
  parentBlock = aParent;
  return;
}

-(id) datasource
{
  CLString *aString;


  if (datasource)
    return datasource;

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_DATASOURCE"])) {
    [self setDatasource:[page datasourceForBinding:aString]];
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
	    [[self class] name], (unsigned long) self,
	    [[datasource class] name], (unsigned long) datasource,
	    [[anObject class] name], (unsigned long) anObject,
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


  if ([aBinding isKindOfClass:[CLNull class]])
    return nil;
  
  if (flag) {
    if ([aBinding isKindOfClass:[CLString class]] && [aBinding characterAtIndex:0] == '=') {
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

  aRange = [aBinding rangeOfString:@":" options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length) {
    if (!aRange.location)
      anObject = self;
    else
      anObject = [page datasourceForBinding:[aBinding substringToIndex:aRange.location]];
    aBinding = [aBinding substringFromIndex:CLMaxRange(aRange)];
  }
  else {
    if ([aBinding hasPrefix:@"#"]) {
      aRange = [aBinding rangeOfString:@"." options:0
				 range:CLMakeRange(0, [aBinding length])];
      if (!aRange.length)
	aRange.location = [aBinding length];
      anObject = [page datasourceForBinding:[aBinding substringToIndex:aRange.location]];
      aBinding = [aBinding substringFromIndex:CLMaxRange(aRange)];      
    }
    else if ([CLDelegate respondsTo:@selector(datasourceForElement:binding:)])
      anObject = [CLDelegate datasourceForElement:self binding:&aBinding];
    else
      anObject = [self datasource];
  }

  if (aBinding)
    anObject = [anObject objectValueForBinding:aBinding found:found];
  else
    *found = YES;
  
  if ([anObject isKindOfClass:[CLNull class]])
    anObject = nil;

  if (index == 2) {
    if ([anObject isKindOfClass:[CLNumber class]])
      anObject = [CLNumber numberWithBool:![anObject boolValue]];
    else
      anObject = [CLNumber numberWithBool:!anObject];
  }

  return anObject;
}

-(CLString *) expandClass:(CLString *) aString
{
  CLMutableArray *mArray;
  int i;
  CLRange aRange;
  CLString *aValue;
  CLExpression *anExp;
  id anObject;
  BOOL flag;


  mArray = [[aString componentsSeparatedByString:@" "] mutableCopy];
  for (i = [mArray count] - 1; i >= 0; i--) {
    aValue = [mArray objectAtIndex:i];
    aRange = [aValue rangeOfString:@"="];
    if (aRange.length) {
      anExp = [[CLExpression alloc]
		initFromString:[aValue substringFromIndex:CLMaxRange(aRange)]];
      anObject = [anExp evaluate:self];
      [anExp release];

      [mArray removeObjectAtIndex:i];
      if (!aRange.location) {
	aValue = anObject;
	flag = YES;
      }
      else {
	aValue = [aValue substringToIndex:aRange.location];
	if ([anObject isKindOfClass:[CLNumber class]])
	  flag = [anObject boolValue];
	else
	  flag = !!anObject;
      }
      if (flag && aValue)
	[mArray insertObject:aValue atIndex:i];
    }
  }

  aString = [mArray componentsJoinedByString:@" "];
  [mArray release];
  return aString;
}
  
-(void) writeAttributes:(CLDictionary *) aDict to:(CLStream *) stream
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
	aValue = [self expandClass:[aDict objectForKey:aKey]];
      else {
	aValue = [self objectValueForSpecialBinding:
			 [attributes objectForCaseInsensitiveString:aKey]
				      allowConstant:NO found:&found wasConstant:NULL];
	if (!aValue && found)
	  aValue = [CLNull null];
      }
      aKey = [aKey substringFromIndex:3];
    }
    else
      aValue = [aDict objectForKey:aKey];

    if (aValue) {
      CLPrintf(stream, @" %@", aKey);
      if (![aValue isKindOfClass:[CLNull class]])
	CLPrintf(stream, @"=\"%@\"", [[aValue description] entityEncodedString]);
    }
  }

  return;
}

-(void) writeHTML:(CLStream *) stream
{
  CLPrintf(stream, @"<%@", title);
  [self writeAttributes:attributes to:stream];
  CLPrintf(stream, @">");

  return;
}

-(id) valueForExpression:(CLString *) aString
{
  BOOL found = NO, wasConst = NO;
  id anObject;


  anObject = [self objectValueForSpecialBinding:aString allowConstant:NO
		   found:&found wasConstant:&wasConst];
  if (!found) {
    /* FIXME - do better number/constant recognition */
    if ([aString length] && isdigit([aString characterAtIndex:0]))
      return [CLDecimalNumber decimalNumberWithString:aString];
    anObject = nil;
  }

  return anObject;
}

-(BOOL) isVisible
{
  BOOL val = YES, wasConst = NO;
  id anObject;
  CLExpression *anExp;


  if ((anObject = [attributes objectForCaseInsensitiveString:@"CL_VISIBLE"])) {
    if ([anObject isKindOfClass:[CLString class]] && [anObject length] &&
	[anObject characterAtIndex:0] == '=') {
      anExp = [[CLExpression alloc] initFromString:[anObject substringFromIndex:1]];
      anObject = [anExp evaluate:self];
      [anExp release];
    }
    else
      wasConst = YES;

    if (wasConst || [anObject isKindOfClass:[CLNumber class]])
      val = [anObject boolValue];
    else
      val = !!anObject;
  }
  
  return val;
}

@end
