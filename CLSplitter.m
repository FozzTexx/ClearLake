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

#import "CLSplitter.h"
#import "CLMutableDictionary.h"
#import "CLArray.h"

@implementation CLSplitter

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

-(id) copy
{
  CLSplitter *aCopy;


  aCopy = [super copy];
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

  
  if ([value isKindOfClass:[CLArray class]]) {
    if (!byColumn) {
      CLPrintf(stream, @"<tr>");
      for (i = 0, j = [value count]; i < j; i++) {
	CLWriteHTMLObject(stream, [value objectAtIndex:i]);
	if (i % interval == interval - 1 && i < j - 1)
	  CLPrintf(stream, @"</tr><tr>");
      }
      CLPrintf(stream, @"</tr>");
    }
    else {
      j = [value count];
      k = (j + interval - 1) / interval;
      //      CLPrintf(stream, @"<td valign=top>");
      for (i = 0, j = [value count]; i < j; i++) {
	CLWriteHTMLObject(stream, [value objectAtIndex:i]);
	if (i % k == k - 1 && i < j - 1)
	  CLPrintf(stream, @"</td><td valign=top>");
      }
      //      CLPrintf(stream, @"</td>");
    }
  }
  else
    CLWriteHTMLObject(stream, value);
  
  return;
}

@end
