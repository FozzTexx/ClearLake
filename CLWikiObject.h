/* Copyright 2012 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * $Id$
 */

#import <ClearLake/CLObject.h>

@class CLDictionary, CLMutableDictionary, CLNumber, CLField, CLOriginalImage;

@interface CLWikiObject:CLObject <CLCopying, CLArchiving>
{
  CLMutableDictionary *attributes;
}

-(id) init;
-(id) initWithAttributes:(CLDictionary *) aDict;
-(void) dealloc;

-(CLDictionary *) attributes;
-(CLString *) description;
-(CLString *) html;
-(void) setObject:(id) anObject forAttribute:(CLString *) aString;
-(CLString *) wikiClassName;

@end
