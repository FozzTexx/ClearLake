/* Copyright 2013-2016 by
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

#import "CLJSONTarget.h"
#import "CLString.h"
#import "CLStream.h"
#import "CLPage.h"
#import "CLData.h"
#import "CLElement.h"

#include <stdlib.h>

@implementation CLJSONTarget

-(id) init
{
  return [self initFromDatasource:nil binding:nil];
}

-(id) initFromDatasource:(id) aDatasource binding:(CLString *) aString
{
  [super init];
  datasource = [aDatasource retain];
  if ([aString hasSuffix:@".json"])
    aString = [aString substringToIndex:[aString length] - 5];
  binding = [aString copy];
  return self;
}

-(void) dealloc
{
  [datasource release];
  [binding release];
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
  CLJSONTarget *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->datasource = [datasource retain];
  aCopy->binding = [binding copy];
  return aCopy;
}

-(id) read:(CLStream *) stream
{
  [super read:stream];
  [stream readTypes:@"@@", &datasource, &binding];
  return self;
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeTypes:@"@@", &datasource, &binding];
  return;
}

-(id) datasource
{
  return datasource;
}

-(CLString *) binding
{
  return binding;
}

-(void) showPage:(id) sender
{
  CLString *json;
  CLData *aData, *gzData;
  BOOL success;
  CLElement *anElement;
  id anObject;


  anElement = [[CLElement alloc] init];
  [anElement setDatasource:datasource];
  anObject = [anElement expandBinding:binding success:&success];
  [anElement release];
  if (!success) {
    printf("Status: 500\r\n");
    printf("\r\n");
    printf("Unable to expand binding\r\n");
    exit(0);
  }

  if (![anObject respondsTo:@selector(json)]) {
    printf("Status: 500\r\n");
    printf("\r\n");
    printf("Object has no JSON representation\r\n");
    exit(0);
  }
  
  json = [anObject json];
  aData = [json dataUsingEncoding:CLUTF8StringEncoding allowLossyConversion:NO];
  printf("Status: 200 OK\r\n");
  printf("Content-Type: text/plain; charset=UTF-8\r\n");
  if (CLBrowserAcceptsGzip() && !CLDeflate([aData bytes], [aData length], 9, &gzData)) {
    printf("Content-Encoding: gzip\r\n");
    aData = gzData;
  }

  printf("Content-Length: %i\r\n", [aData length]);
  printf("\r\n");
  fwrite([aData bytes], [aData length], 1, stdout);
  exit(0);
}

@end
