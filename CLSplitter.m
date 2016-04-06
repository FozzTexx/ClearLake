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

#import "CLSplitter.h"
#import "CLMutableDictionary.h"
#import "CLArray.h"

@implementation CLSplitter

+(void) load
{
  CLSplitterClass = [CLSplitter class];
  return;
}

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString;

  
  [super initFromElement:anElement onPage:aPage];

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_INTERVAL"])) {
    interval = [aString intValue];
    [attributes removeObjectForCaseInsensitiveString:@"CL_INTERVAL"];
  }
  else
    interval = 4;

  byColumn = !![attributes objectForCaseInsensitiveString:@"CL_BYCOLUMN"];
  
  return self;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLSplitter *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->interval = interval;
  return aCopy;
}

-(CLUInteger) interval
{
  return interval;
}

-(void) setInterval:(CLUInteger) aValue
{
  interval = aValue;
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  int i, j, k;

  
  if ([content isKindOfClass:CLArrayClass]) {
    if (!byColumn) {
      [stream writeString:@"<tr>" usingEncoding:CLUTF8StringEncoding];
      for (i = 0, j = [content count]; i < j; i++) {
	CLWriteHTMLObject(stream, [content objectAtIndex:i]);
	if (i % interval == interval - 1 && i < j - 1)
	  [stream writeString:@"</tr><tr>" usingEncoding:CLUTF8StringEncoding];
      }
      [stream writeString:@"</tr>" usingEncoding:CLUTF8StringEncoding];
    }
    else {
      j = [content count];
      k = (j + interval - 1) / interval;
      for (i = 0, j = [content count]; i < j; i++) {
	CLWriteHTMLObject(stream, [content objectAtIndex:i]);
	if (i % k == k - 1 && i < j - 1)
	  [stream writeString:@"</td><td valign=top>" usingEncoding:CLUTF8StringEncoding];
      }
    }
  }
  else
    CLWriteHTMLObject(stream, content);
  
  return;
}

@end
