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

#import "CLBlock.h"
#import "CLMutableString.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"
#import "CLPage.h"
#import "CLInput.h"
#import "CLNumber.h"
#import "CLManager.h"
#import "CLControl.h"
#import "CLData.h"
#import "CLNumberFormatter.h"
#import "CLDateFormatter.h"
#import "CLSortDescriptor.h"
#import "CLNull.h"
#import "CLCharacterSet.h"
#import "CLExpression.h"
#import "CLDatetime.h"

@implementation CLBlock

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage
{
  [super initFromString:nil onPage:aPage];
  content = [aString mutableCopy];
  datasource = nil;
  
  return self;
}

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  [super initFromElement:anElement onPage:aPage];

#if 0 /* FIXME - is this valid for anything except CLField? */
  if ((aString = [attributes objectForCaseInsensitiveString:@"VALUE"]))
    [self setContent:aString];
#endif

  return self;
}

-(void) dealloc
{
  [content release];
  if (datasource != page)
    [datasource release];
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
  CLBlock *aCopy;
  int i, j;
  id anObject;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  if ([content isKindOfClass:CLArrayClass]) {
    aCopy->content = [[CLMutableArray alloc] initWithArray:content copyItems:YES];
    for (i = 0, j = [aCopy->content count]; i < j; i++) {
      anObject = [aCopy->content objectAtIndex:i];
      if ([anObject respondsTo:@selector(setParentBlock:)])
	[anObject setParentBlock:aCopy];
    }
  }
  else
    aCopy->content = [content copy];

  aCopy->datasource = datasource;
  if (datasource != page)
    [aCopy->datasource retain];
  
  return aCopy;
}

-(id) content
{
  return content;
}

-(void) setPageFor:(id) anObject
{
  int i, j;

  
  if ([anObject isKindOfClass:CLArrayClass]) {
    for (i = 0, j = [anObject count]; i < j; i++)
      [self setPageFor:[anObject objectAtIndex:i]];
  }
  else if ([anObject respondsTo:@selector(setPage:)])
    [anObject setPage:page];
  return;
}
    
-(void) setPage:(CLPage *) aPage
{
  [super setPage:aPage];
  [self setPageFor:content];
  return;
}

-(void) autonumber:(id) anObject position:(int) index
	  replaced:(CLMutableDictionary *) replaced
{
  int i, j;
  CLMutableDictionary *mDict;
  CLString *aString, *newString;


  if ([anObject isKindOfClass:CLArrayClass]) {
    for (i = 0, j = [anObject count]; i < j; i++)
      [self autonumber:[anObject objectAtIndex:i] position:index replaced:replaced];
  }
  else if ([anObject isKindOfClass:CLElementClass]) {
    if ((mDict = [anObject attributes])) {
      if ((aString = [mDict objectForCaseInsensitiveString:@"NAME"]) &&
	  (![anObject isKindOfClass:CLInputClass] ||
	   [anObject type] != CLRadioInputType ||
	   [attributes objectForCaseInsensitiveString:@"CL_AUTORADIO"])) {
	aString = [aString stringByAppendingFormat:@"_%i", index];
	[mDict setObject:aString forCaseInsensitiveString:@"NAME"];
      }
      if ((aString = [mDict objectForCaseInsensitiveString:@"ID"])) {
	newString = [aString stringByAppendingFormat:@"_%i", index];
	[replaced setObject:newString forKey:aString];
	[mDict setObject:newString forCaseInsensitiveString:@"ID"];
      }
      if ((aString = [mDict objectForCaseInsensitiveString:@"FOR"])) {
	aString = [aString stringByAppendingFormat:@"_%i", index];
	[mDict setObject:aString forCaseInsensitiveString:@"FOR"];
      }
    }
	
    if ([anObject isKindOfClass:CLBlockClass] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [self autonumber:[anObject content] position:index replaced:replaced];
  }

  return;
}

-(CLString *) fixIDs:(CLString *) aString newIDs:(CLDictionary *) aDict
{
  CLRange aRange, aRange2, aRange3;
  int i, j;
  CLMutableString *mString;
  CLString *subString, *aKey;
  CLArray *anArray;
  CLCharacterSet *anuSet;


  anuSet = [CLCharacterSet alphaNumericUnderscoreCharacterSet];
  mString = [[aString mutableCopy] autorelease];
  aRange = [mString rangeOfString:@"@:"];
  while (aRange.length) {
    aRange2.location = CLMaxRange(aRange);
    aRange2.length = [mString length] - aRange2.location;
    aRange2 = [mString rangeOfCharacterNotFromSet:anuSet options:0 range:aRange2];
    if (!aRange2.length)
      aRange2.location = [mString length];

    aRange3.location = CLMaxRange(aRange);
    aRange3.length = aRange2.location - aRange3.location;
    subString = [mString substringWithRange:aRange3];

    anArray = [aDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aKey = [anArray objectAtIndex:i];
      if ([aKey isEqualToString:subString]) {
	subString = [aDict objectForKey:aKey];
	break;
      }
    }

    if (i < j)
      [mString replaceCharactersInRange:aRange3 withString:subString];

    aRange2.location = aRange3.location + [subString length];
    aRange2.length = [mString length] - aRange2.location;
    aRange = [mString rangeOfString:@"@:" options:0 range:aRange2];
  }

  return mString;
}

-(void) autonumber:(id) anObject newIDs:(CLDictionary *) replaced
{
  int i, j;
  CLMutableDictionary *mDict;
  CLString *aString, *aKey;
  CLArray *anArray;


  if ([anObject isKindOfClass:CLArrayClass]) {
    for (i = 0, j = [anObject count]; i < j; i++)
      [self autonumber:[anObject objectAtIndex:i] newIDs:replaced];
  }
  else if ([anObject isKindOfClass:CLElementClass]) {
    if ((mDict = [anObject attributes])) {
      anArray = [mDict allKeys];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aKey = [anArray objectAtIndex:i];
	if ([aKey hasPrefix:@"cl_"]) {
	  aString = [mDict objectForKey:aKey];
	  if ([aString isKindOfClass:CLStringClass]) {
	    aString = [self fixIDs:aString newIDs:replaced];
	    [mDict setObject:aString forKey:aKey];
	  }
	}
      }
    }
	
    if ([anObject isKindOfClass:CLBlockClass] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [self autonumber:[anObject content] newIDs:replaced];
  }

  return;
}

-(void) autonumber:(CLArray *) anArray
{
  int i, j;
  CLMutableDictionary *mDict;
  id anObject;


  mDict = [[CLMutableDictionary alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    [mDict removeAllObjects];
    anObject = [anArray objectAtIndex:i];
    [self autonumber:anObject position:i+1 replaced:mDict];
    if ([mDict count])
      [self autonumber:anObject newIDs:mDict];
  }
  
  [mDict release];
  
  return;
}

-(void) setContent:(id) anObject
{
  [content autorelease];
  if ([anObject isKindOfClass:CLArrayClass] &&
      ![anObject isKindOfClass:CLMutableArrayClass]) {
    if ([content isKindOfClass:CLMutableArrayClass]) {
      [content retain];
      [content removeAllObjects];
      [content addObjectsFromArray:anObject];
    }
    else {
      content = [anObject mutableCopy];
    }
  }
  else if ([content isKindOfClass:CLStringClass])
    content = [anObject copy];
  else
    content = [anObject retain];

  [self setPageFor:content];
  
  return;
}

-(void) setVisible:(BOOL) flag
{
  [attributes setObject:[CLNumber numberWithBool:flag]
	      forCaseInsensitiveString:@"CL_VISIBLE"];
  return;
}

-(void) addObject:(id) anObject
{
  CLMutableArray *mArray;

  
  if (![content isKindOfClass:CLMutableArrayClass]) {
    mArray = [[CLMutableArray alloc] init];
    if (content)
      [mArray addObject:content];
    [content release];
    content = mArray;
  }
  
  [content addObject:anObject];
  if ([anObject respondsTo:@selector(setPage:)])
    [anObject setPage:page];
  if ([anObject respondsTo:@selector(setParentBlock:)])
    [anObject setParentBlock:self];
  
  return;
}

-(void) addObjectsFromArray:(CLArray *) otherArray
{
  int i, j;
  
  
  for (i = 0, j = [otherArray count]; i < j; i++)
    [self addObject:[otherArray objectAtIndex:i]];
    
  return;
}

-(void) updateBindingFor:(id) anObject
{
  CLUInteger count;
  id *items;
  int i;


  if ([anObject isKindOfClass:CLArrayClass] && [anObject count]) {
    /* Nasty nasty nasty nasty. Array could grow/shrink when updating
       bindings. Copy the array and update everything in it. Things
       that insert new objects are responsible for making sure they
       get updated. */

    count = [anObject count];
    items = alloca(count * sizeof(id));
    [anObject getObjects:items];
    for (i = 0; i < count; i++)
      [self updateBindingFor:items[i]];
  }

  if ([anObject respondsTo:@selector(updateBinding)])
    [anObject updateBinding];

  return;
}

-(void) updateBinding
{
  CLString *aString, *sortString;
  id aFormatter;
  id anObject = nil;
  BOOL found, success;
  CLRange aRange;


  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_BINDING"])) {
    aRange.length = 0;
    if ([aString hasPrefix:@"="]) {
      aRange = [aString rangeOfString:@".objects." options:0
				range:CLMakeRange(0, [aString length])];
      if (aRange.length && ![attributes objectForCaseInsensitiveString:@"CL_AUTONUMBER"])
	[attributes setObject:CLTrueObject forCaseInsensitiveString:@"CL_AUTONUMBER"];
    }
    
    if (aRange.length &&
	(sortString = [attributes objectForCaseInsensitiveString:@"CL_SORT"])) {
      sortString = [self expandBinding:sortString success:&success];
      anObject = [self expandBinding:[aString substringToIndex:aRange.location]
			     success:&found];
      anObject = [anObject sortedArrayUsingDescriptors:
			     [CLSortDescriptor sortDescriptorsFromString:sortString]];
      anObject = [anObject objectValueForBinding:
			     [aString substringFromIndex:aRange.location+1]];
    }
    else {
      anObject = [self expandBinding:aString success:&found];
      if ([anObject isKindOfClass:CLArrayClass] &&
	  (sortString = [attributes objectForCaseInsensitiveString:@"CL_SORT"])) {
	sortString = [self expandBinding:sortString success:&success];
	anObject = [anObject sortedArrayUsingDescriptors:
			       [CLSortDescriptor sortDescriptorsFromString:sortString]];
      }
    }
      
    if ((aString = [attributes objectForCaseInsensitiveString:@"CL_FORMAT"])) {
      if ([anObject isKindOfClass:CLNumberClass]) {
	aFormatter = [CLNumberFormatter numberFormatterFromFormat:
					      [self expandBinding:aString success:&success]];
	anObject = [aFormatter stringForObjectValue:anObject];
      }
      else if ([anObject isKindOfClass:CLDatetimeClass]) {
	aFormatter = [CLDateFormatter dateFormatterFromFormat:aString];
	anObject = [aFormatter stringForObjectValue:anObject];
      }
    }

    if (anObject)
      [self setContent:anObject];
  }

  /* FIXME - Blah, we need to find another way to deal with this. If
     we update the bindings before the autonumber then cl_bindings
     that reference an ID won't get fixed. If we do the update after
     the autonumber, then the double autonumber doesn't happen. */
  
  [self updateBindingFor:content];

  if ([content isKindOfClass:CLArrayClass] &&
      (anObject = [attributes objectForCaseInsensitiveString:@"CL_AUTONUMBER"]) &&
      (anObject == CLNullObject || [self expandBoolean:anObject]))
    [self autonumber:content]; 

  return;
}

-(void) readURL:(CLStream *) stream
{
  CLString *aString;
  id anObject;


  [stream readType:@"@" data:&anObject];
  [self setDatasource:anObject];
  [stream readTypes:@"@", &aString];
  [attributes setObject:aString forCaseInsensitiveString:@"ID"];
  [attributes setObject:[CLQuery objectForKey:CL_URLSEL]
	      forCaseInsensitiveString:@"CL_DBINDING"];
  
  return;
}

-(void) writeURL:(CLStream *) stream
{
  CLString *aString;
  id anObject;

  
  aString = [attributes objectForCaseInsensitiveString:@"ID"];
  anObject = [self datasource];
  [stream writeType:@"@" data:&anObject];
  [stream writeTypes:@"@", &aString];
  [CLQuery setObject:[attributes objectForCaseInsensitiveString:@"CL_DBINDING"]
	   forKey:CL_URLSEL];
  return;
}

-(CLString *) generateAjaxURL
{
  CLStream *stream, *stream2;
  CLString *aString;
  CLData *aData;


  stream = [CLStream openMemoryForWriting];
  stream2 = [CLStream openMemoryForWriting];
  [self writeURL:stream2];
  aData = [stream2 data];
  CLWriteURLForGet(stream, self, aData, nil, YES);
  [stream2 close];
  /* FIXME - we should be using nocopy to move the stream buffer into the string */
  aData = [stream data];
  aString = [CLString stringWithData:aData encoding:CLUTF8StringEncoding];
  [stream close];

  return aString;
}

-(void) writeContentTo:(CLStream *) stream
{
  CLString *aString;

  
  if (content)
    CLWriteHTMLObject(stream, content);
  else if ([attributes objectForCaseInsensitiveString:@"CL_DBINDING"]) {
    aString = [self generateAjaxURL];
    [stream writeFormat:
	      @"<span id=\"%s\"></span><script>\n"
	    "//<![CDATA[\n"
	    "var test = document.getElementById('%s');\n"
	    "test.innerHTML = 'Scraping...';\n"
	    "function ajaxTest() {\n"
	    "  var oScript = document.createElement('script');\n"
	    "  oScript.type = 'text/javascript';\n"
	    "  oScript.src = '%s';\n"
	    "  document.body.appendChild(oScript);\n"
	    "}\n"
	    "window.onload = ajaxTest;\n"
	    "//]]>\n"
	    "</script>" usingEncoding:CLUTF8StringEncoding,
	    [[attributes objectForCaseInsensitiveString:@"ID"] UTF8String],
	    [[attributes objectForCaseInsensitiveString:@"ID"] UTF8String],
	    [aString UTF8String]];
  }

  return;
}

-(void) writeHTML:(CLStream *) stream
{
  if (![self isVisible])
    return;

  //  CLPrintf(stream, @"<!-- %s: %0x8lx -->", [[self class] name], (unsigned long) self);
  //  CLPrintf(stream, @"<!-- %s: %0x8lx -->", [[self datasource] name],
  //	   (unsigned long) [self datasource]);

  /* Not using hasPrefix: because I need case insensitive */
  if ([title length] &&
      ([title length] < 3 || [title compare:@"CL_" options:CLCaseInsensitiveSearch
				      range:CLMakeRange(0, 3)])) {
    [stream writeFormat:@"<%@" usingEncoding:CLUTF8StringEncoding, title];
    [self writeAttributes:stream ignore:nil];
    [stream writeString:@">" usingEncoding:CLUTF8StringEncoding];
    [self writeContentTo:stream];
    [stream writeFormat:@"</%@>" usingEncoding:CLUTF8StringEncoding, title];
  }
  else
    [self writeContentTo:stream];
  
  //  CLPrintf(stream, @"<!-- / %s: %0x8lx -->", [[self class] name], (unsigned long) self);
  //  CLPrintf(stream, @"<!-- / %s: %0x8lx -->", [[self datasource] name],
  //	   (unsigned long) [self datasource]);
  
  return;
}

-(void) performAction
{
  CLString *aString;
  CLData *aData;
  CLStream *stream;
  id aValue;
  BOOL found;


  if ((aString = [CLQuery objectForCaseInsensitiveString:CL_URLDATA]) &&
      [aString length]) {
    aData = [aString decodeBase64];
    stream = [CLStream openWithData:aData mode:CLReadOnly];
    [self readURL:stream];
    [stream close];
  }

  printf("Content-Type: text/javascript\n");
  printf("\n");
  printf("var test = document.getElementById('%s');\n",
	 [[attributes objectForCaseInsensitiveString:@"ID"] UTF8String]);
  aValue = [self expandBinding:[attributes objectForCaseInsensitiveString:@"CL_DBINDING"]
		       success:&found];
  printf("test.innerHTML = '%s';\n",
	 aValue ? [[aValue description] UTF8String] : "");

  return;
}

-(CLString *) description
{
  CLStream *stream;
  const void *data;
  int i;
  CLString *aString;


  stream = [CLStream openMemoryForWriting];
  [self writeHTML:stream];
  /* FIXME - we should be using nocopy to move the stream buffer into the string */
  data = [stream bytes];
  i = [stream length];
  aString = [CLString stringWithBytes:data length:i encoding:CLUTF8StringEncoding];
  [stream close];

  return aString;
}

@end
