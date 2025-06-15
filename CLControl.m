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

#import "CLControl.h"
#import "CLData.h"
#import "CLStream.h"
#import "CLPage.h"
#import "CLAutoreleasePool.h"
#import "CLMutableString.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLPageTarget.h"
#import "CLManager.h"
#import "CLSession.h"
#import "CLNumber.h"
#import "CLCookie.h"
#import "CLImageElement.h"
#import "CLImageRep.h"
#import "CLForm.h"
#import "CLRegularExpression.h"
#import "CLCharacterSet.h"
#import "CLValue.h"
#import "CLExpression.h"
#import "CLNull.h"
#import "CLRuntime.h"
#import "CLStackString.h"
#import "CLJSONTarget.h"
#import "CLClassConstants.h"
#import "CLEditingContext.h"
#import "CLFQTableName.h"

#include <stdlib.h>

#define QUERY_SESSIONID @"CLsid"

CLString *CLURLOrder[] = {
  CL_URLCLASS, CL_URLDATA, CL_URLSEL, // New order
  CL_URLSEL, CL_URLCLASS, CL_URLDATA, // Old order
};

void CLWriteURLForGet(CLStream *stream, id object, CLData *stateData, SEL action,
		      CLDictionary *localQuery, BOOL withoutQuery)
{
  int c;
  CLStream *stream2;
  CLString *aURL, *simpleURL;
  BOOL dumbBrowser = NO;
  CLAutoreleasePool *pool;
  CLMutableDictionary *mDict;
  CLUInteger idx, count;


#if DEBUG_RETAIN
    id self = nil;
#endif
  pool = [[CLAutoreleasePool alloc] init];

  mDict = [localQuery mutableCopy];
  [mDict addEntriesFromDictionary:CLQuery];
  for (idx = 0, count = 3; idx < count; idx++)
    [mDict removeObjectForKey:CLURLOrder[idx]];

  /* AvantGo can't parse HTML escape codes in A tags. */
  /* Neither can some crazy proxy server that the Arabians like to use */
  if ([CLUserAgent hasPrefix:@"Mozilla/3.0 (compatible; AvantGo 3.2"] ||
      [CLUserAgent isEqualToString:@"Mozilla/3.01 (compatible;)"])
    dumbBrowser = YES;

  if ([CLUserAgent hasPrefix:@"Mozilla/5.0 (compatible; Googlebot/2.1;"] ||
      [CLUserAgent hasPrefix:@"Mediapartners-Google"])
    CLCookiesEnabled = YES;

  stream2 = [CLStream openMemoryForWriting];

  aURL = nil;
  if ([object respondsTo:@selector(baseURL)] && [object baseURL])
    aURL = [object baseURL];
  if (aURL && ![CLServerURL isEqual:aURL])
    [stream2 writeString:aURL usingEncoding:CLUTF8StringEncoding];

  {
    CLControl *aControl = object;


    if (![aControl isKindOfClass:CLControlClass]) {
      aControl = [[CLControl alloc] init];
      [aControl setTarget:object];
      [aControl setAction:action];
    }

    if (CLDelegate
	&& [CLDelegate respondsTo:@selector(delegateEncodeSimpleURL:localQuery:)]
#if 0
	&& [object respondsTo:@selector(target)]
	&& [object respondsTo:@selector(action)]
#endif
	&& (simpleURL = [CLDelegate delegateEncodeSimpleURL:aControl localQuery:mDict])) {
      if (![simpleURL isAbsolutePath])
	simpleURL = [CLString stringWithFormat:@"%@/%@", CLWebName, simpleURL];
      [stream2 writeString:simpleURL usingEncoding:CLUTF8StringEncoding];
    }
    else {
      CLMutableDictionary *urlComponents;


      urlComponents = [[CLMutableDictionary alloc] init];
      if (action) {
	CLString *actionName;


	actionName = CLStringFromSelector(action);
	if ([actionName characterAtIndex:[actionName length] - 1] == ':')
	  actionName = [actionName substringToIndex:[actionName length]-1];
	if (![actionName isEqualToString:@"detail"])
	  [urlComponents setObject:actionName forKey:CL_URLSEL];
      }

      if (object) {
	CLString *objectName;
	CLFQTableName *aTable;


	if ([object isKindOfClass:CLStringClass])
	  objectName = object;
	else if (!(aTable = [CLEditingContext tableForClass:[object class]]))
	  objectName = [object className];
	else if ([[CLEditingContext model] count] == 1)
	  objectName = [aTable tableName];
	[urlComponents setObject:objectName forKey:CL_URLCLASS];
      }

      if (stateData)
	[urlComponents setObject:[stateData encodeBase64] forKey:CL_URLDATA];

      {
	id anObject;


	[stream2 writeFormat:@"%@/" usingEncoding:CLUTF8StringEncoding, CLWebName];
	for (idx = 0, count = 3; idx < count; idx++) {
	  anObject = [urlComponents objectForKey:CLURLOrder[idx]];
	  if (!anObject)
	    break;
	  if (idx)
	    CLPrintf(stream2, @"/");
	  CLPrintf(stream2, @"%@", anObject);
	}
      }

      [urlComponents release];
    }
  }

  /* FIXME - find a way to differentiate between a browser with no
     cookies set yet and a robot */
  if (1 || CLCookiesEnabled)
    [mDict removeObjectForKey:QUERY_SESSIONID];
  else {
    CLUnsignedPK sid;


    sid = [[[[CLManager manager] activeSession] primaryKey] unsignedPK];
    if (sid)
      [mDict setObject:[CLNumber numberWithPK:sid] forKey:QUERY_SESSIONID];
  }

  if (!withoutQuery) {
    CLString *aKey;
    CLArray *keys;
    CLUInteger i, j;
    id aValue;


    keys = [mDict allKeys];
    for (c = '?', i = 0, j = [keys count]; i < j; i++, c = '&') {
      aKey = [keys objectAtIndex:i];
      aValue = [mDict objectForKey:aKey];
      if (aValue && aValue != CLNullObject)
        CLPrintf(stream2, @"%c%@=%@", c, [[aKey description] stringByAddingPercentEscapes],
                 [[aValue description] stringByAddingPercentEscapes]);
      else
        CLPrintf(stream2, @"%c%@", c, [[aKey description] stringByAddingPercentEscapes]);
    }
  }

  {
    CLString *urlString;


    urlString = [[CLString alloc] initWithBytes:[stream2 bytes] length:[stream2 length]
				       encoding:CLUTF8StringEncoding];
    [stream writeString:dumbBrowser ? urlString : [urlString entityEncodedString]
	  usingEncoding:CLUTF8StringEncoding];
    [stream2 close];
    [urlString release];
  }

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

void CLWriteURL(CLStream *stream, id object, CLData *stateData, SEL action,
		CLDictionary *localQuery)
{
  CLWriteURLForGet(stream, object, stateData, action, localQuery, NO);
}

Class CLClassFromURLString(CLString *objectName)
{
  Class targetClass = nil;
  CLFQTableName *table;


  if ([CLFQTableName isFullyQualifiedTableName:objectName])
    table = [CLFQTableName fullyQualifiedTableName:objectName];
  else
    table = [CLFQTableName tableName:objectName inDatabase:[[[CLEditingContext model] allKeys]
							     objectAtIndex:0]];
  targetClass = [CLEditingContext classForTable:table];
  if (!targetClass)
    targetClass = CLClassFromString(objectName);

  return targetClass;
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
  BOOL success;


  [super initFromElement:anElement onPage:aPage];

  if ((aString = [attributes objectForKey:@"CL_PAGE"])) {
    [self setTarget:[[[CLPageTarget alloc] initFromPath:
                                    [self expandBinding:aString success:&success]]
                      autorelease]];
    [self setAction:@selector(showPage:)];
  }

  if ((aString = [attributes objectForKey:@"CL_TARGET"]))
    [self setTarget:[self expandBinding:aString success:&success]];

  if ((aString = [attributes objectForKey:@"CL_ACTION"])) {
    CLRange aRange;


    aRange = [aString rangeOfString:@":"];
    if (aRange.length && aRange.location < [aString length] - 1) {
      [self setTarget:[self expandBinding:[aString substringToIndex:aRange.location]
                                  success:&success]];
      aString = [aString substringFromIndex:CLMaxRange(aRange)];
    }
    aString = [self expandBinding:aString success:&success];
    if ([aString length] && [aString characterAtIndex:[aString length]-1] != ':')
      aString = [aString stringByAppendingString:@":"];
    [self setAction:CLSelectorFromString(aString)];
    if (!target && ![attributes objectForKey:@"CL_TARGET"])
      [self setTarget:[page owner]];
  }

  if ((aString = [attributes objectForKey:@"CL_JSON"])) {
    [self setTarget:[[[CLJSONTarget alloc] initFromDatasource:[self datasource]
                                                      binding:aString] autorelease]];
    [self setAction:@selector(showPage:)];
  }

  if ((aString = [attributes objectForKey:@"CL_WRITECONTENTS"])) {
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
  [attributes setObject:[CLNumber numberWithBool:flag] forKey:@"CL_ENABLED"];
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
  Class targetClass;


  if ((aString = [CLQuery objectForKey:CL_URLDATA]) &&
      [aString length]) {
    aData = [aString decodeBase64];
    aString = [CLString stringWithData:aData encoding:CLUTF8StringEncoding];
    targetClass = CLClassFromURLString([CLQuery objectForKey:CL_URLCLASS]);

    if ([CLEditingContext recordDefinitionForClass:targetClass]) {
      target = [[CLDefaultContext loadExistingObjectWithClass:targetClass
                                                   primaryKey:[aString decodeJSON]] retain];
      if (!target)
        target = [[targetClass alloc] init];
      aString = [CLQuery objectForKey:CL_URLSEL];
      if (!aString)
        aString = @"detail";
      aString = [CLString stringWithFormat:@"%@:", aString];
      action = CLSelectorFromString(aString);
      [target replacePage:self selector:action];
    }
    else {
      CLStream *stream;


      stream = [CLStream openWithData:aData mode:CLReadOnly];
      [self readURL:stream];
      [stream readTypes:@"i", &writeContents];
      if (writeContents)
        [stream readTypes:@"@", &content];
      [stream close];
    }
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
      if (([target isKindOfClass:CLPageTargetClass] && action == @selector(showPage:))
	  || ([[CLQuery objectForKey:CL_URLCLASS] isEqualToString:@"CLControl"]
	      && [CLEditingContext recordDefinitionForClass:[target class]]
	      && [[target editingContext] primaryKeyForRecord:target]
	      && [target selectorIsPage:action])) {
	aString = [self generateURL];
	fprintf(stderr, "Redirecting: %s\n", [aString UTF8String]);
	CLRedirectBrowser(aString, YES, 301);
	return;
      }
      [target perform:action with:self];
      [page display];
    }
  }

  return;
}

-(BOOL) isEnabled
{
  BOOL val = YES;
  id anObject;


  if ((anObject = [attributes objectForKey:@"CL_ENABLED"]))
    val = [self expandBoolean:anObject];
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
  CLString *aString, *aURL = nil;
  BOOL success;


  if (!action) {
    if ((aString = [attributes objectForKey:@"CL_IMAGE"])) {
      CLImageElement *anImage;
      CLImageRep *aRep;


      anImage = [[CLImageElement alloc] init];
      [anImage setDatasource:[self datasource]];
      [anImage setParentBlock:self];
      [[anImage attributes] setObject:aString forKey:@"CL_BINDING"];
      if ((aString = [attributes objectForKey:@"CL_EFFECTS"]))
        [[anImage attributes] setObject:aString forKey:@"CL_EFFECTS"];
      [anImage updateBinding];
      aURL = [anImage generateURL];
      aRep = [anImage imageRep];
      if ((aString = [attributes objectForKey:@"CL_EFFECTS"]))
        aRep = [aRep imageRepFromEffects:aString];
      [attributes setObject:[CLNumber numberWithUnsignedInt:[aRep size].width]
		     forKey:@"WIDTH"];
      [attributes setObject:[CLNumber numberWithUnsignedInt:[aRep size].height]
		     forKey:@"HEIGHT"];
      [anImage release];
    }
    else if ((aString = [attributes objectForKey:@"CL_HREF"]))
      aURL = [self expandBinding:aString success:&success];
  }
  else {
    id urlObject;
    CLData *urlState;
    SEL urlAction;


    if ([target isKindOfClass:CLPageTargetClass]) {
      CLString *path;


      path = [target path];
      if ([path hasPathPrefix:CLAppPath])
	path = [path stringByDeletingPathPrefix:CLAppPath];
      path = [path stringByDeletingPathExtension];
      urlObject = path;
      urlState = nil;
      urlAction = NULL;
    }
    else if (target && [CLEditingContext recordDefinitionForClass:[target class]]
	     && [[target editingContext] primaryKeyForRecord:target]
	     && [target selectorIsPage:action]) {
      //id targetClass = nil;
      id pk;


      //targetClass = [target class];
      pk = [[target editingContext] primaryKeyForRecord:target];
      urlState = [[pk json] dataUsingEncoding:CLUTF8StringEncoding];
      urlObject = target;
      urlAction = action;
    }
    else {
      CLStream *stream2;


      // FIXME - give target an opportunity to create urlState
      stream2 = [CLStream openMemoryForWriting];
      [self writeURL:stream2];
      [stream2 writeTypes:@"i", &writeContents];
      if (writeContents)
	[stream2 writeTypes:@"@", &content];
      urlState = [stream2 data];
      urlObject = self;
      urlAction = action;
      [stream2 close];
    }

    stream = [CLStream openMemoryForWriting];
    CLWriteURL(stream, urlObject, urlState, urlAction, localQuery);
    if (anchor)
      [stream writeFormat:@"#%@" usingEncoding:CLUTF8StringEncoding, anchor];
    /* FIXME - we should be using nocopy to move the stream buffer into the string */
    aURL = [CLString stringWithData:[stream data] encoding:CLUTF8StringEncoding];
    [stream close];
  }

  aURL = [[self class] rewriteURL:[aURL entityDecodedString]];

  return aURL;
}

-(void) readURL:(CLStream *) stream
{
  CLString *filename, *aString;
  CLPage *aPage = nil;
  id anObject;
  Class targetClass;


  if ([CLDelegate respondsTo:@selector(control:readPersistentData:)])
    [CLDelegate control:self readPersistentData:stream];

  [stream readType:@"@" data:&target];
  [stream readTypes:@"@@@", &filename, &aString, &anObject];
  [filename autorelease];
  [aString autorelease];

  if ([target isKindOfClass:CLStringClass] &&
      (targetClass = CLClassFromURLString(target)))
    target = [[targetClass alloc] init];

  if ([target respondsTo:@selector(control:readPersistentData:)])
    [target control:self readPersistentData:stream];

  if ([filename isAbsolutePath] &&
      ![filename hasPathPrefix:[CLEnvironment objectForKey:@"DOCUMENT_ROOT"]])
    filename = [filename lastPathComponent];

  if (aString)
    [attributes setObject:aString forKey:@"ID"];
  aString = [CLQuery objectForKey:CL_URLSEL];
  if ([aString length] && [aString characterAtIndex:[aString length]-1] != ':')
    aString = [aString stringByAppendingString:@":"];
  action = CLSelectorFromString(aString);
  if ([self isKindOfClass:CLFormClass])
    [((CLForm *) self) restoreObject:anObject];

  if (filename) {
    aPage = [[CLPage alloc] initFromFile:filename owner:anObject];
    [self setPage:aPage];
    [aPage autorelease];
  }

  if (aString) {
    if ((anObject = [aPage objectWithID:aString]) &&
        [anObject respondsTo:@selector(setTarget:)])
      [anObject setTarget:target];
  }

  return;
}

-(void) writeURL:(CLStream *) stream
{
  unistr filename;
  id anObject;
  BOOL success;
  CLString *aString, *fString;


  if ([CLDelegate respondsTo:@selector(control:writePersistentData:)])
    [CLDelegate control:self writePersistentData:stream];

  if ((fString = [page filename])) {
    filename = CLCopyStackString(fString, 0);
    if ([((CLString *) &filename) hasPathPrefix:CLAppPath])
      [((CLMutableString *) &filename) deletePathPrefix:CLAppPath];
    else
      [((CLMutableString *) &filename) deletePathPrefix:
                            [CLEnvironment objectForKey:@"DOCUMENT_ROOT"]];
    fString = (CLString *) &filename;
  }

  anObject = [page owner];
  if (!(aString = [attributes objectForKey:@"ID"]) &&
      (aString = [attributes objectForKey:@"CL_ID"])) {
    aString = [self expandBinding:aString success:&success];
  }
  [stream writeType:@"@" data:&target];
  [stream writeTypes:@"@@@", &fString, &aString, &anObject];

  if ([target respondsTo:@selector(control:writePersistentData:)])
    [target control:self writePersistentData:stream];

  return;
}

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  if (!ignore)
    ignore = [CLMutableArray array];
  [ignore addObjects:@"CL_ACTION", @"CL_TARGET", @"CL_JSON", @"CL_PAGE", @"CL_QUERY",
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
      (action || [attributes objectForKey:@"CL_HREF"] ||
       ![title caseInsensitiveCompare:@"A"]))
    writeATag = YES;

  if (writeATag) {
    CLPrintf(stream, @"<A");
    if (action || [attributes objectForKey:@"CL_HREF"] ||
	[attributes objectForKey:@"CL_IMAGE"])
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
      if ((aString = [attributes objectForKey:@"HREF"]) &&
          [aString length] && [aString characterAtIndex:0] == '#' && CLWebName)
        [attributes setObject:[CLString stringWithFormat:@"%@%s%@",
                                        CLWebName, getenv("PATH_INFO"), aString]
                    forKey:@"HREF"];
    }
#endif

    [self writeAttributes:stream ignore:nil];

    CLPrintf(stream, @">");
  }

  CLWriteHTMLObject(stream, content);

  if (writeATag)
    CLPrintf(stream, @"</A>");

  [pool release];

  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLControl *aCopy;


  aCopy = [super copy:file :line :retainer];
#define copy            copy:__FILE__ :__LINE__ :self
  aCopy->target = [target retain];
  aCopy->action = action;
  aCopy->writeContents = writeContents;
  aCopy->baseURL = [baseURL copy];
  aCopy->anchor = [anchor copy];
  aCopy->localQuery = [localQuery mutableCopy];
  return aCopy;
}
#else
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
#endif

@end
