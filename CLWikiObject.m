/* Copyright 2012-2016 by
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

#import "CLWikiObject.h"
#import "CLMutableDictionary.h"
#import "CLArray.h"
#import "CLMutableString.h"
#import "CLNull.h"
#import "CLPage.h"
#import "CLBlock.h"
#import "CLStream.h"

@implementation CLWikiObject

-(id) init 
{
  return [self initWithAttributes:nil];
  return self;
}

-(id) initWithAttributes:(CLDictionary *) aDict
{
  [super init];
  attributes = [[CLMutableDictionary alloc] init];
  [attributes addEntriesFromDictionary:aDict];
  return self;
}

-(void) dealloc
{
  [attributes release];
  [super dealloc];
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLWikiObject *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->attributes = [attributes mutableCopy];
  return aCopy;
}

-(id) read:(CLStream *) stream
{
  [super read:stream];
  [stream readTypes:@"@", &attributes];
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeTypes:@"@", &attributes];
  return;
}

-(CLDictionary *) attributes
{
  return attributes;
}

-(CLString *) description 
{
  int i;
  CLArray *keys = [attributes allKeys];
  CLString *value;
  CLMutableString *result;


  result = [CLMutableString stringWithFormat:@"[[%@", [self wikiClassName]];
  for (i = 0; i < [keys count]; ++i) {
    value = [attributes objectForKey:[keys objectAtIndex:i]];
    [result appendString:@" "];
    [result appendString:[keys objectAtIndex:i]];
    if (value && value != CLNullObject) {
      [result appendString:@"=\""];
      [result appendString:[value description]];
      [result appendString:@"\""];
    }
  }
  [result appendString:@"]]"];
	
  return result;
}

-(CLString *) html
{
  CLPage *aPage;
  CLBlock *aBlock;
  CLStream *stream;
  CLData *aData;
  CLString *template;


  if (!(template = [attributes objectForCaseInsensitiveString:@"template"]))
    template = @"inline";
  aPage = [[CLPage alloc] initFromFile:[self findFileForKey:template] owner:self];
  if (!aPage && ![template isEqualToString:@"inline"])
    aPage = [[CLPage alloc] initFromFile:[self findFileForKey:@"inline"] owner:self];
  aBlock = [[CLBlock alloc] init];
  [aBlock setContent:[aPage body]];
  [aPage release];
  [aBlock updateBinding];
  stream = [CLStream openMemoryForWriting];
  CLWriteHTMLObject(stream, aBlock);
  [stream close];
  [aBlock release];
  /* FIXME - we should be using nocopy to move the stream buffer into the string */
  aData = [stream data];
  return [[CLString stringWithData:aData encoding:CLUTF8StringEncoding]
	   stringByTrimmingWhitespaceAndNewlines];
}  

-(void) setObject:(id) anObject forAttribute:(CLString *) aString
{
  if (!anObject)
    [attributes removeObjectForCaseInsensitiveString:aString];
  else
    [attributes setObject:anObject forCaseInsensitiveString:aString];
  return;
}

-(CLString *) wikiClassName
{
  return nil;
}

@end
