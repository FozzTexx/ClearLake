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

#import "CLControl.h"
#import "CLData.h"
#import "CLStream.h"
#import "CLPage.h"
#import "CLAutoreleasePool.h"
#import "CLMutableString.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLPageTarget.h"
#import "CLCalendarDate.h"
#import "CLManager.h"
#import "CLSession.h"
#import "CLNumber.h"
#import "CLCookie.h"
#import "CLImageElement.h"
#import "CLForm.h"
#import "CLRegularExpression.h"
#import "CLCharacterSet.h"
#import "CLValue.h"
#import "CLExpression.h"
#import "CLNull.h"
#import "CLObjCAPI.h"

#include <stdlib.h>

#define QUERY_SESSIONID	@"CLsid"

void CLWriteURLForGet(CLStream *stream, id object,
		      CLData *aData, CLDictionary *localQuery,
		      BOOL withoutQuery)
{
  int c;
  CLStream *stream2;
  CLString *aURL;
  BOOL dumbBrowser = NO;
  CLString *aString;
  CLAutoreleasePool *pool;
  CLMutableDictionary *mDict;

  
  pool = [[CLAutoreleasePool alloc] init];

  mDict = [localQuery mutableCopy];
  [mDict addEntriesFromDictionary:CLQuery];
  
  /* AvantGo can't parse HTML escape codes in A tags. */
  /* Neither can some crazy proxy server that the Arabians like to use */
  if ([CLUserAgent hasPrefix:@"Mozilla/3.0 (compatible; AvantGo 3.2"] ||
      [CLUserAgent isEqualToString:@"Mozilla/3.01 (compatible;)"])
    dumbBrowser = YES;

  if ([CLUserAgent hasPrefix:@"Mozilla/5.0 (compatible; Googlebot/2.1;"] ||
      [CLUserAgent hasPrefix:@"Mediapartners-Google"])
    CLCookiesEnabled = YES;
  
  stream2 = CLOpenMemory(NULL, 0, CL_WRITEONLY);

  aURL = nil;
  if ([object respondsTo:@selector(baseURL)] && [object baseURL])
    aURL = [object baseURL];
  if (aURL && ![CLServerURL isEqual:aURL])
    CLPrintf(stream2, aURL);
  
  if (CLDelegate && 
      [CLDelegate respondsTo:@selector(delegateEncodeSimpleURL:localQuery:)] &&
#if 0
      [object respondsTo:@selector(target)] &&
      [object respondsTo:@selector(action)] &&
#endif
      (aString = [CLDelegate delegateEncodeSimpleURL:object
			     localQuery:mDict])) {
    if (![aString isAbsolutePath])
      CLPrintf(stream2, @"%@/%@", CLWebName, aString);
    else
      CLPrintf(stream2, @"%@", aString);
    [mDict removeObjectForKey:CL_URLSEL];
    [mDict removeObjectForKey:CL_URLCLASS];
    [mDict removeObjectForKey:CL_URLDATA];
  }
  else {
    CLPrintf(stream2, @"%@/", CLWebName);

    if ((aString = [mDict objectForKey:CL_URLSEL])) {
      if ([aString length] && [aString characterAtIndex:[aString length]-1] == ':')
	aString = [aString substringToIndex:[aString length]-1];
      CLPrintf(stream2, @"%@", aString);
      [mDict removeObjectForKey:CL_URLSEL];
    }
    else
      CLPrintf(stream2, @"0");

    CLPrintf(stream2, @"/%@", [[object class] className]);
    CLPrintf(stream2, @"/%@", [aData encodeBase64]);
    [mDict removeObjectForKey:CL_URLCLASS];
    [mDict removeObjectForKey:CL_URLDATA];
  }

  /* FIXME - find a way to differentiate between a browser with no
     cookies set yet and a robot */  
  if (1 || CLCookiesEnabled) 
    [mDict removeObjectForKey:QUERY_SESSIONID];
  else {
    int sid;

    
    if ((sid = [[[CLManager manager] activeSession] objectID]))
      [mDict setObject:[CLNumber numberWithInt:sid] forKey:QUERY_SESSIONID];
  }

  if (!withoutQuery) {
    CLString *aKey;
    CLArray *keys;
    int i, j;
    id aValue;

    
    keys = [mDict allKeys];
    for (c = '?', i = 0, j = [keys count]; i < j; i++, c = '&') {
      aKey = [keys objectAtIndex:i];
      aValue = [mDict objectForKey:aKey];
      if (aValue && ![aValue isKindOfClass:[CLNull class]])
	CLPrintf(stream2, @"%c%@=%@", c, [[aKey description] stringByAddingPercentEscapes],
		 [[aValue description] stringByAddingPercentEscapes]);
      else
	CLPrintf(stream2, @"%c%@", c, [[aKey description] stringByAddingPercentEscapes]);
    }
  }

  aData = CLGetData(stream2);
  aString = [[CLString alloc] initWithData:aData encoding:CLUTF8StringEncoding];
  CLPrintf(stream, @"%@", dumbBrowser ? aString : [aString entityEncodedString]);
  CLCloseMemory(stream2, CL_FREEBUFFER);
  [aString release];

#if 0
  if (!withoutQuery) {
    CLString *aKey;
    CLArray *keys;
    int i, j;
    
    keys = [CLQuery allKeys];
    for (i = 0, j = [keys count]; i < j; i++) {
      aKey = [keys objectAtIndex:i];
      if ([aKey hasPrefix:@"url"])
	[CLQuery removeObjectForKey:aKey];
    }
  }
#endif

  [mDict release];
  [pool release];
    
  return;  
}

void CLWriteURL(CLStream *stream, id object,
		CLData *aData, CLDictionary *localQuery)
{
  CLWriteURLForGet(stream, object, aData, localQuery, NO);
}

@implementation CLControl

+(CLString *) rewriteURL:(CLString *) aURL
{
  CLArray *anArray;
  int i, j;
  CLString *regString = nil;
  CLMutableString *newString = nil;
  CLRegularExpression *aRegex;
  CLRange aRange;
  CLString *aString;


  if ((aString = [CLManager configOption:@"RewriteRule"])) {
    anArray = [aString decodeCSVUsingCharacterSet:
			 [CLCharacterSet whitespaceAndNewlineCharacterSet]];
    /* decodeCSVUsingCharacterSet will treat runs of characters in the
       set as individual separators and insert empty strings between
       them. */
    for (i = 0, j = [anArray count]; i < j && (!regString || !newString); i++) {
      aString = [anArray objectAtIndex:i];
      if ([aString length]) {
	if (!regString)
	  regString = aString;
	else
	  newString = [[aString mutableCopy] autorelease];
      }
    }

    if (regString && newString) {
      aRegex = [CLRegularExpression regularExpressionFromString:regString];
      if ([aRegex matchesString:aURL substringRanges:&anArray]) {
	for (i = 1, j = [anArray count]; i < j; i++) {
	  aRange = [[anArray objectAtIndex:i] rangeValue];
	  /* FIXME - watch out for escaped $ */
	  [newString replaceOccurrencesOfString:[CLString stringWithFormat:@"$%i", i]
		     withString:[aURL substringWithRange:aRange]];
	}

	aRegex = [CLRegularExpression regularExpressionFromString:@"\\$[0-9]+"];
	while ([aRegex matchesString:newString substringRanges:&anArray])
	  [newString deleteCharactersInRange:[[anArray objectAtIndex:0] rangeValue]];
	
	aURL = newString;
      }
    }
  }

  return aURL;
}

-(id) init
{
  return [self initFromString:nil onPage:nil];
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage
{
  [super initFromString:aString onPage:aPage];
  target = nil;
  action = NULL;
  if (title)
    [self addObject:title];
  [title release];
  title = nil;
  writeContents = NO;
  baseURL = nil;
  anchor = nil;
  localQuery = [[CLMutableDictionary alloc] init];
  return self;
}

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString;

  
  [super initFromElement:anElement onPage:aPage];

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_PAGE"])) {
    [self setTarget:[[[CLPageTarget alloc] initFromPath:aString] autorelease]];
    [self setAction:@selector(showPage:)];
  }

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_TARGET"])) {
    [self setTarget:[page datasourceForBinding:aString]];
  }

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_ACTION"])) {
    CLRange aRange;


    aRange = [aString rangeOfString:@":"];
    if (aRange.length && aRange.location < [aString length] - 1) {
      [self setTarget:[page datasourceForBinding:
			      [aString substringToIndex:aRange.location]]];
      aString = [aString substringFromIndex:CLMaxRange(aRange)];
    }
    if ([aString length] && [aString characterAtIndex:[aString length]-1] != ':')
      aString = [aString stringByAppendingString:@":"];
    [self setAction:sel_getUid([aString UTF8String])];
    if (!target && ![attributes objectForCaseInsensitiveString:@"CL_TARGET"])
      [self setTarget:[page owner]];      
  }

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_WRITECONTENTS"])) {
    [self setWriteContents:[aString boolValue]];
  }
  
  return self;
}

-(void) dealloc
{
  [baseURL release];
  [anchor release];
  [localQuery release];
  [target release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLControl *aCopy;


  aCopy = [super copy];
  aCopy->target = [target retain];
  aCopy->action = action;
  aCopy->writeContents = writeContents;
  aCopy->baseURL = [baseURL copy];
  aCopy->anchor = [anchor copy];
  aCopy->localQuery = [localQuery mutableCopy];
  return aCopy;
}

-(SEL) action
{
  return action;
}

-(id) target
{
  return target;
}

-(void) setAction:(SEL) anAction
{
  action = anAction;
  return;
}

-(void) setTarget:(id) aTarget
{
  [target autorelease];
  target = [aTarget retain];
  return;
}

-(void) setEnabled:(BOOL) flag
{
  [attributes setObject:[CLNumber numberWithBool:flag]
	      forCaseInsensitiveString:@"CL_ENABLED"];
  return;
}

-(void) setWriteContents:(BOOL) flag
{
  writeContents = flag;
  return;
}

-(void) setAnchor:(CLString *) aString
{
  [anchor autorelease];
  anchor = [aString retain];
  return;
}

-(void) performAction
{
  CLString *aString;
  CLData *aData;
  CLStream *stream;
  CLTypedStream *tstream;


  if ((aString = [CLQuery objectForCaseInsensitiveString:CL_URLDATA]) &&
      [aString length]) {
    aData = [aString decodeBase64];
    stream = CLOpenMemory([aData bytes], [aData length], CL_READONLY);
    tstream = CLOpenTypedStream(stream, CL_READONLY);
    [self readURL:tstream];
    CLReadTypes(tstream, "i", &writeContents);
    if (writeContents)
      CLReadTypes(tstream, "@", &value);
    CLCloseTypedStream(tstream);
    CLCloseMemory(stream, CL_FREEBUFFER);
  }

  {
    BOOL perform;
    id owner;


    if (!(perform = [[CLManager manager] checkPermission:self]) &&
	[CLDelegate respondsTo:@selector(accessDenied:)])
      [CLDelegate accessDenied:self];
    
    if (perform && [target respondsTo:@selector(controlShouldPerform:)])
      perform = [target controlShouldPerform:self];
    owner = [page owner];
    if (perform && owner && owner != target &&
	[owner respondsTo:@selector(controlShouldPerform:)])
      perform = [owner controlShouldPerform:self];
    if (perform && CLDelegate && CLDelegate != target && CLDelegate != owner &&
	[CLDelegate respondsTo:@selector(controlShouldPerform:)])
      perform = [CLDelegate controlShouldPerform:self];
    if (perform) {
      [target perform:action with:self];
      [page display];
    }
  }


  return;
}

-(BOOL) isEnabled
{
  BOOL val = YES, wasConst = NO;
  id anObject;
  CLExpression *anExp;


  if ((anObject = [attributes objectForCaseInsensitiveString:@"CL_ENABLED"])) {
    if ([anObject isKindOfClass:[CLString class]] && [anObject characterAtIndex:0] == '=') {
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

-(void) setBaseURL:(CLString *) aString
{
  [baseURL autorelease];
  baseURL = [aString retain];
  return;
}

-(CLString *) baseURL
{
  return baseURL;
}

-(CLMutableDictionary *) localQuery
{
  return localQuery;
}

-(BOOL) writeContents
{
  return writeContents;
}

-(CLString *) generateURL
{
  CLStream *stream;
  CLStream *stream2;
  CLTypedStream *tstream;
  CLString *aString, *aURL = nil;
  CLData *aData;
  BOOL found;


  if (!action) {
    if ((aString = [attributes objectForCaseInsensitiveString:@"CL_IMAGE"])) {
      CLImageElement *anImage;
      CLImageRep *aRep;


      anImage = [[CLImageElement alloc] init];
      [anImage setDatasource:[self datasource]];
      [anImage setParentBlock:self];
      [[anImage attributes] setObject:aString forCaseInsensitiveString:@"CL_VALUE"];
      if ((aString = [attributes objectForCaseInsensitiveString:@"CL_EFFECTS"]))
	[[anImage attributes] setObject:aString forCaseInsensitiveString:@"CL_EFFECTS"];
      [anImage updateBinding];
      aURL = [anImage generateURL];
      aRep = [anImage imageRep];
      if ((aString = [attributes objectForCaseInsensitiveString:@"CL_EFFECTS"]))
	aRep = [aRep imageRepFromEffects:aString];
      [attributes setObject:[CLNumber numberWithInt:[aRep size].width]
		  forCaseInsensitiveString:@"WIDTH"];
      [attributes setObject:[CLNumber numberWithInt:[aRep size].height]
		  forCaseInsensitiveString:@"HEIGHT"];
      [anImage release];
    }
    else if ((aString = [attributes objectForCaseInsensitiveString:@"CL_HREF"]))
      aURL = [self objectValueForSpecialBinding:aString allowConstant:NO
		      found:&found wasConstant:NULL];
  }
  else {
    stream = CLOpenMemory(NULL, 0, CL_WRITEONLY);
    stream2 = CLOpenMemory(NULL, 0, CL_WRITEONLY);
    tstream = CLOpenTypedStream(stream2, CL_WRITEONLY);
    [self writeURL:tstream];
    CLWriteTypes(tstream, "i", &writeContents);
    if (writeContents)
      CLWriteTypes(tstream, "@", &value);
    CLCloseTypedStream(tstream);
    aData = CLGetData(stream2);
    CLWriteURL(stream, self, aData, localQuery);
    [CLQuery removeObjectForKey:CL_URLSEL];
    CLCloseMemory(stream2, CL_FREEBUFFER);
    if (anchor)
      CLPrintf(stream, @"#%@", anchor);
    aData = CLGetData(stream);
    aURL = [CLString stringWithData:aData encoding:CLUTF8StringEncoding];
    CLCloseMemory(stream, CL_FREEBUFFER);
  }

  aURL = [[self class] rewriteURL:[[aURL description] entityDecodedString]];

  return aURL;
}

-(void) readURL:(CLTypedStream *) stream
{
  CLString *filename, *aString;
  CLPage *aPage;
  id anObject;

  
  if ([CLDelegate respondsTo:@selector(control:readPersistentData:)])
    [CLDelegate control:self readPersistentData:stream];
    
  target = CLReadObject(stream);
  CLReadTypes(stream, "@@@", &filename, &aString, &anObject);
  [filename autorelease];
  [aString autorelease];

  if ([filename isAbsolutePath] &&
      ![filename hasPathPrefix:[CLEnvironment objectForKey:@"DOCUMENT_ROOT"]])
    filename = [filename lastPathComponent];
  
  if (aString)
    [attributes setObject:aString forCaseInsensitiveString:@"ID"];
  aString = [CLQuery objectForKey:CL_URLSEL];
  if ([aString length] && [aString characterAtIndex:[aString length]-1] != ':')
    aString = [aString stringByAppendingString:@":"];
  action = sel_getUid([aString UTF8String]);
  [CLQuery removeObjectForKey:CL_URLSEL];
  if ([self isKindOfClass:[CLForm class]])
    [((CLForm *) self) restoreObject:anObject];

  aPage = [[CLPage alloc] initFromFile:filename owner:anObject];
  [self setPage:aPage];
  [aPage autorelease];

  if (aString) {
    if ((anObject = [aPage objectWithID:aString]) &&
	[anObject respondsTo:@selector(setTarget:)])
      [anObject setTarget:target];
  }  

  return;
}

-(void) writeURL:(CLTypedStream *) stream
{
  CLString *filename, *aString;
  id anObject;
  BOOL found;


  if ([CLDelegate respondsTo:@selector(control:writePersistentData:)])
    [CLDelegate control:self writePersistentData:stream];

  filename = [page filename];
  if ([filename hasPathPrefix:CLAppPath])
    filename = [filename stringByDeletingPathPrefix:CLAppPath];
  else
    filename = [filename stringByDeletingPathPrefix:
			   [CLEnvironment objectForKey:@"DOCUMENT_ROOT"]];
  
  anObject = [page owner];
  if (!(aString = [attributes objectForCaseInsensitiveString:@"ID"]) &&
      (aString = [attributes objectForCaseInsensitiveString:@"CL_ID"])) {
    aString = [self objectValueForSpecialBinding:aString allowConstant:NO found:&found
				     wasConstant:NULL];
  }
  CLWriteObject(stream, target);
  CLWriteTypes(stream, "@@@", &filename, &aString, &anObject);
  aString = [CLString stringWithUTF8String:sel_getName(action)];
  if ([aString length] && [aString characterAtIndex:[aString length]-1] == ':')
    aString = [aString substringToIndex:[aString length]-1];
  [CLQuery setObject:aString forKey:CL_URLSEL];
  return;
}

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  if (!ignore)
    ignore = [CLMutableArray array];
  [ignore addObjects:@"CL_ACTION", @"CL_TARGET", @"CL_PAGE", @"CL_QUERY",
	  @"CL_WRITECONTENTS", @"CL_HREF", @"CL_IMAGE", nil];
  
  [super writeAttributes:stream ignore:ignore];
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  CLAutoreleasePool *pool;
  BOOL writeATag = NO;


  if (![self isVisible])
    return;

  pool = [[CLAutoreleasePool alloc] init];

  if ([self isEnabled] &&
      (action ||
       [attributes objectForCaseInsensitiveString:@"CL_HREF"] ||
       ![title caseInsensitiveCompare:@"A"]))
    writeATag = YES;
  
  if (writeATag) {
    CLPrintf(stream, @"<A");
    if (action || [attributes objectForCaseInsensitiveString:@"CL_HREF"] ||
	[attributes objectForCaseInsensitiveString:@"CL_IMAGE"])
      CLPrintf(stream, @" HREF=\"%@\"", [self generateURL]);

#if 0
    /* Now I forget why I disabled this.
     *
     * The reason this is here is because when the user clicks a link
     * that begins with #, the browser cheerfully decides to pull the
     * page directly from the BASE folder instead of looking at the
     * page it is viewing.
     */
    {
      CLString *aString;
      

      /* FIXME - don't do this unless the page is actually writing us out */
      if ((aString = [attributes objectForCaseInsensitiveString:@"HREF"]) &&
	  [aString length] && [aString characterAtIndex:0] == '#' && CLWebName)
	[attributes setObject:[CLString stringWithFormat:@"%@%s%@",
					CLWebName, getenv("PATH_INFO"), aString]
		    forCaseInsensitiveString:@"HREF"];
    }
#endif
    
    [self writeAttributes:stream ignore:nil];

    CLPrintf(stream, @">");
  }

  CLWriteHTMLObject(stream, value);

  if (writeATag)
    CLPrintf(stream, @"</A>");

  [pool release];
  
  return;
}

@end
