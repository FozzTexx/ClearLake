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

#import "CLScriptElement.h"
#import "CLMutableArray.h"
#import "CLExpression.h"
#import "CLMutableDictionary.h"
#import "CLControl.h"
#import "CLManager.h"
#import "CLData.h"
#import "CLPage.h"

@implementation CLScriptElement

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  if (!ignore)
    ignore = [CLMutableArray array];
  [ignore addObjects:@"CL_VARIABLES", @"CL_INCLUDE", @"CL_XSS", nil];
  
  [super writeAttributes:stream ignore:ignore];
  return;
}

-(CLDictionary *) expandVariables:(CLString *) aString
{
  CLArray *anArray;
  int i, j;
  CLRange aRange;
  CLString *aValue;
  CLExpression *anExp;
  id anObject;
  CLMutableDictionary *mDict;


  anArray = [aString componentsSeparatedByString:@" "];
  mDict = [CLMutableDictionary dictionary];
  
  for (i = 0, j = [anArray count]; i < j; i++) {
    aValue = [anArray objectAtIndex:i];
    aRange = [aValue rangeOfString:@"="];
    if (aRange.location) {
      anExp = [[CLExpression alloc]
		initFromString:[aValue substringFromIndex:CLMaxRange(aRange)]];
      anObject = [anExp evaluate:self];
      [anExp release];

      [mDict setObject:anObject forKey:[aValue substringToIndex:aRange.location]];
    }
  }

  return mDict;
}
  
-(void) readURL:(CLStream *) stream
{
  CLString *filename;
  id anObject;
  CLPage *aPage;

  
  [stream readTypes:@"@@@@", &attributes, &value, &filename, &anObject];
  aPage = [[CLPage alloc] initFromFile:filename owner:anObject];
  [self setPage:aPage];
  [aPage autorelease];
  return;
}

-(void) writeURL:(CLStream *) stream
{
  CLString *filename;
  id anObject;

  
  filename = [page filename];
  anObject = [page owner];
  [stream writeTypes:@"@@@@", &attributes, &value, &filename, &anObject];
  return;
}

-(CLString *) generateURL
{
  CLStream *stream, *stream2;
  CLString *aURL = nil;
  CLData *aData;


  stream = [CLStream openMemoryForWriting];
  stream2 = [CLStream openMemoryForWriting];
  [self writeURL:stream2];
  aData = [stream2 data];
  CLWriteURL(stream, self, aData, nil);
  [stream2 close];
  /* FIXME - we should be using nocopy to move the stream buffer into the string */
  aData = [stream data];
  aURL = [CLString stringWithData:aData encoding:CLUTF8StringEncoding];
  [stream close];

  aURL = [CLControl rewriteURL:[aURL entityDecodedString]];

  return aURL;
}

-(void) writeContents:(CLStream *) stream
{
  CLDictionary *aDict;
  CLArray *anArray;
  int i, j;
  id anObject;
  CLString *aValue, *aString;
  CLStream *stream2;
  CLData *aData;


  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_VARIABLES"])) {
    aDict = [self expandVariables:aString];
    anArray = [aDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aString = [anArray objectAtIndex:i];
      anObject = [aDict objectForKey:aString];
      if ([anObject respondsTo:@selector(json)])
	aValue = [anObject json];
      else if ([anObject isKindOfClass:[CLBlock class]]) {
	stream2 = [CLStream openMemoryForWriting];
	[anObject updateBinding];
	[anObject writeHTML:stream2];
	/* FIXME - we should be using nocopy to move the stream buffer into the string */
	aData = [stream2 data];
	aValue = [[CLString stringWithData:aData encoding:CLUTF8StringEncoding] json];
	[stream2 close];
      }
      else
	aValue = [[anObject description] json];

      [stream writeFormat:@"  var %@ = %@;\n" usingEncoding:CLUTF8StringEncoding,
	      aString, aValue];
    }
  }
  
  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_INCLUDE"])) {
  }

  if (value)
    CLWriteHTMLObject(stream, value);

  return;
}
  
-(void) writeHTML:(CLStream *) stream
{
  id xss;

  
  if (![self isVisible])
    return;

  CLPrintf(stream, @"<%@", title);
  [self writeAttributes:stream ignore:nil];
  if ((xss = [attributes objectForCaseInsensitiveString:@"CL_XSS"]))
    CLPrintf(stream, @" SRC=\"%@%@\"", CLServerURL,
	     [[self generateURL] entityEncodedString]);
  CLPrintf(stream, @">");

  if (!xss)
    [self writeContents:stream];
  
  CLPrintf(stream, @"</%@>", title);
  
  return;
}

-(void) performAction
{
  CLString *aString;
  CLData *aData;
  CLStream *stream;


  if ((aString = [CLQuery objectForCaseInsensitiveString:CL_URLDATA]) &&
      [aString length]) {
    aData = [aString decodeBase64];
    stream = [CLStream openWithData:aData mode:CLReadOnly];
    [self readURL:stream];
    [stream close];
  }

  stream = [CLStream openMemoryForWriting];
  [self writeContents:stream];
  aData = [stream data];
  [stream close];

  printf("Content-Type: text/javascript\r\n");
  printf("Content-Length: %i\r\n", [aData length]);
  printf("\r\n");
  fwrite([aData bytes], 1, [aData length], stdout);

  return;
}

@end
