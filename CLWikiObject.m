/* Copyright 2012 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * $Id$
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

-(id) copy
{
  CLWikiObject *aCopy;


  aCopy = [super copy];
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
    if (value && ![value isKindOfClass:[CLNull class]]) {
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
  [aBlock setValue:[aPage body]];
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
