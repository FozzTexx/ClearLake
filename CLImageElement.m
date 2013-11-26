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

#import "CLImageElement.h"
#import "CLMutableString.h"
#import "CLNumber.h"
#import "CLMutableDictionary.h"
#import "CLManager.h"
#import "CLOpenFile.h"
#import "CLControl.h"
#import "CLData.h"
#import "CLMutableArray.h"
#import "CLImageRep.h"
#import "CLPage.h"

#include <stdlib.h>

@implementation CLImageElement

-(id) init
{
  return [self initFromString:nil onPage:nil];
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage
{
  [super initFromString:aString onPage:aPage];
  imageRep = nil;
  [attributes setObject:[CLNumber numberWithInt:0] forCaseInsensitiveString:@"BORDER"];
  return self;
}

-(id) initWithImageRep:(id) aRep alt:(CLString *) anAlt onPage:(CLPage *) aPage
{
  [self initFromString:nil onPage:aPage];
  imageRep = [aRep retain];
  if (anAlt)
    [attributes setObject:anAlt forCaseInsensitiveString:@"ALT"];
  return self;
}

#if 0 /* This is cool and all but doesn't really need to be done to static images */
-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString, *prefix;
  CLImageRep *aRep;


  [super initFromElement:anElement onPage:aPage];
  if ([attributes objectForCaseInsensitiveString:@"CL_EFFECTS"] &&
      (aString = [attributes objectForCaseInsensitiveString:@"SRC"]) &&
      !([aString isURL])) {
    if ([aString isAbsolutePath])
      prefix = [CLString stringWithUTF8String:getenv("DOCUMENT_ROOT")];
    else
      prefix = [[page filename] stringByDeletingLastPathComponent];
    aString = [prefix stringByAppendingPathComponent:aString];
    if ((aRep = [CLImageRep imageRepFromFile:aString])) {
      [self setImageRep:aRep];
      [attributes removeObjectForCaseInsensitiveString:@"SRC"];
    }
  }

  return self;
}
#endif

-(void) dealloc
{
  [imageRep release];
  [super dealloc];
  return;
}

-(id) read:(CLStream *) stream
{
  [super read:stream];
  [stream readTypes:@"@", &imageRep];
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeTypes:@"@", &imageRep];
  return;
}

-(id) copy
{
  CLImageElement *aCopy;


  aCopy = [super copy];
  aCopy->imageRep = [imageRep retain];
  return aCopy;
}

-(void) readURL:(CLStream *) stream
{
  id anObject;
  CLString *effects;

  
  [stream readTypes:@"@", &anObject];
  if ([anObject isKindOfClass:[CLString class]])
    imageRep = [[CLImageRep alloc] initFromFile:anObject];
  else {
    imageRep = anObject;
    [stream readTypes:@"@", &effects];
    if (effects)
      [attributes setObject:effects forCaseInsensitiveString:@"CL_EFFECTS"];
  }
  
  return;
}

-(void) writeURL:(CLStream *) stream image:(CLImageRep *) aRep
{
  CLString *aString;


  if ((aString = [aRep path]))
    [stream writeTypes:@"@", &aString];
  else {
    aString = [attributes objectForCaseInsensitiveString:@"CL_EFFECTS"];
    [stream writeTypes:@"@@", &imageRep, &aString];
  }
  
  return;
}

-(void) performAction
{
  CLStream *stream;
  CLString *aString;
  CLData *aData;
  CLImageRep *newRep;
  CLString *format;
  
  
  if ((aString = [CLQuery objectForKey:CL_URLDATA])) {
    aData = [aString decodeBase64];
    stream = [CLStream openWithData:aData mode:CLReadOnly];
    [self readURL:stream];
    [stream close];

    if (!imageRep) {
      printf("Status: 404 File Not Found\n");
      printf("Content-Type: text/html; charset=UTF-8\n");
      printf("\n");
      printf("<HEAD><TITLE>404 File Not Found</TITLE></HEAD><BODY>\n");
      printf("<H1>Not Found</H1>\n");
      printf("<P>The document you have requested does not exist.</P>\n");
      printf("</BODY>\n");
      return;
    }
    else {
      if ((aString = [attributes objectForCaseInsensitiveString:@"CL_EFFECTS"]))
	newRep = [imageRep imageRepFromEffects:aString];
      else
	newRep = imageRep;
      format = [newRep bestFormat];
      aData = [newRep representationUsingFormat:format];

      printf("Content-Type: image/%s\n", [format UTF8String]);
      printf("Content-Length: %u\n", [aData length]);
      printf("\n");
      fwrite([aData bytes], 1, [aData length], stdout);
    }
  }

  return;
}

-(CLString *) generateURL
{
  CLImageRep *newRep;
  const char *p;
  CLString *aString = nil;
  CLStream *stream, *stream2;
  CLData *aData;

  
  if (imageRep) {
    if ((aString = [attributes objectForCaseInsensitiveString:@"CL_EFFECTS"]))
      newRep = [imageRep imageRepFromEffects:aString];
    else
      newRep = imageRep;
    path = [newRep path];

    if ((p = getenv("DOCUMENT_ROOT")))
      aString = [CLString stringWithUTF8String:p];
    else
      aString = [CLString stringWithString:CLAppPath];
    
    if (![path hasPathPrefix:aString]) {
      stream = [CLStream openMemoryForWriting];
      stream2 = [CLStream openMemoryForWriting];
      [self writeURL:stream2 image:newRep];
      aData = [stream2 data];
      CLWriteURL(stream, self, aData, nil);
      [stream2 close];
      /* FIXME - we should be using nocopy to move the stream buffer into the string */
      aData = [stream data];
      aString = [CLString stringWithData:aData encoding:CLUTF8StringEncoding];
      [stream close];
    }
    else {
      CLString *prefix, *filename;
      

      prefix = [path substringFromIndex:[aString length]];
      filename = [prefix lastPathComponent];
      prefix = [prefix stringByDeletingLastPathComponent];
      aString = [prefix stringByAppendingPathComponent:
			  [filename stringByAddingPercentEscapes]];
    }
  }

  return aString;
}

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  CLString *aKey;
  CLMutableDictionary *mDict = [attributes copy];
  int i, j;


  if (!ignore)
    ignore = [CLMutableArray array];
  [ignore addObjects:@"CL_VISIBLE", @"CL_SORT", @"CL_FORMAT", @"CL_AUTONUMBER",
	  @"CL_DATASOURCE", @"CL_BINDING", @"CL_VALUE", @"CL_DBINDING", @"CL_VARNAME",
	  @"CL_EFFECTS", @"CL_SRC", @"CL_NOSIZE", nil];
  
  for (i = 0, j = [ignore count]; i < j; i++) {
    aKey = [ignore objectAtIndex:i];
    if ([mDict objectForCaseInsensitiveString:aKey])
      [mDict removeObjectForCaseInsensitiveString:aKey];
  }

  [super writeAttributes:mDict to:stream];
  [mDict release];
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  CLString *aString;
  CLSize aSize;
  id newRep;


  if (![self isVisible])
    return;
  
  CLPrintf(stream, @"<IMG");

  if (imageRep) {
    if ((aString = [attributes objectForCaseInsensitiveString:@"CL_EFFECTS"]))
      newRep = [imageRep imageRepFromEffects:aString];
    else
      newRep = imageRep;

    if ([attributes objectForCaseInsensitiveString:@"CL_NOSIZE"]) {
      [attributes removeObjectForCaseInsensitiveString:@"WIDTH"];
      [attributes removeObjectForCaseInsensitiveString:@"HEIGHT"];
    }
    else {
      aSize = [newRep size];
      [attributes setObject:[CLNumber numberWithInt:aSize.width]
		  forCaseInsensitiveString:@"WIDTH"];
      [attributes setObject:[CLNumber numberWithInt:aSize.height]
		  forCaseInsensitiveString:@"HEIGHT"];
    }

    CLPrintf(stream, @" SRC=\"%@\"", [self generateURL]);
  }
  
  [self writeAttributes:stream ignore:nil];
  CLPrintf(stream, @">");
  
  return;
}

-(id) imageRep
{
  return imageRep;
}

-(CLString *) path
{
  return path;
}

-(void) setImageRep:(id) aRep
{
  [imageRep autorelease];
  imageRep = [aRep retain];
  return;
}

-(void) updateBinding
{
  CLString *binding;
  id anObject;
  BOOL found;

  
  if ((binding = [attributes objectForCaseInsensitiveString:@"CL_VALUE"]) ||
      (binding = [attributes objectForCaseInsensitiveString:@"CL_BINDING"])) {
    anObject = [self objectValueForSpecialBinding:binding allowConstant:NO
		     found:&found wasConstant:NULL];
    if (found) {
      if ([anObject isKindOfClass:[CLString class]])
	anObject = [[[CLImageRep alloc] initFromFile:anObject] autorelease];
      [self setImageRep:anObject];
    }
  }

  if (!imageRep && (binding = [attributes objectForCaseInsensitiveString:@"CL_SRC"])) {
    anObject = [self objectValueForSpecialBinding:binding allowConstant:NO
		     found:&found wasConstant:NULL];
    if (found)
      [attributes setObject:anObject forKey:@"SRC"];
  }

  return;
}

@end
