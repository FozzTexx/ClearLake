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

#import "CLRangeView.h"
#import "CLArray.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLSortDescriptor.h"
#import "CLPage.h"

@implementation CLRangeView

#if 0
+(void) load
{
  CLRangeViewClass = [CLRangeView class];
  return;
}
#endif

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString;
  BOOL success;

  
  [super initFromElement:anElement onPage:aPage];

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_MAXITEMS"])) {
    maxItems = [[self expandBinding:aString success:&success] intValue];
    [attributes removeObjectForCaseInsensitiveString:@"CL_MAXITEMS"];
  }
  else
    maxItems = 10;
  [self setRange:CLMakeRange([[self expandBinding:
				      [attributes objectForCaseInsensitiveString:@"CL_START"]
					  success:&success]
			       intValue], maxItems)];
  
  return self;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLRangeView *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->range = range;
  aCopy->count = count;
  aCopy->maxItems = maxItems;
  return aCopy;
}
      
-(CLRange) range
{
  return range;
}

-(CLUInteger) count
{
  return count;
}

-(CLUInteger) firstIndex
{
  return range.location + 1;
}

-(CLUInteger) lastIndex
{
  [self updateBinding];
  if (CLMaxRange(range) > count)
    range.length = count - range.location;
  return CLMaxRange(range);
}

-(CLUInteger) maxItems
{
  return maxItems;
}

-(void) setRange:(CLRange) aRange
{
  range = aRange;
  return;
}

-(id) findArray:(CLString *) aBinding source:(id) anObject
{
  CLRange aRange;
  CLString *aString;
  id aValue;
  BOOL found = NO;


  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length)
    aString = [aBinding substringToIndex:aRange.location];
  else
    aString = aBinding;

  if (!anObject)
    aValue = [self objectValueForSpecialBinding:aString allowConstant:NO
					  found:&found wasConstant:NULL];
  else
    aValue = [anObject objectValueForBinding:aString];
  
  if (![aValue isKindOfClass:CLArrayClass]) {
    if (aRange.length)
      aValue = [self findArray:[aBinding substringFromIndex:CLMaxRange(aRange)]
					 source:aValue];
  }
  else {
    aRange = [aBinding rangeOfString:@"." options:0
		       range:CLMakeRange(CLMaxRange(aRange),
					 [aBinding length] - CLMaxRange(aRange))];
    [attributes setObject:[aBinding substringFromIndex:CLMaxRange(aRange)]
		forCaseInsensitiveString:@"CL_ARRAYVALUE"];
  }

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_SORT"])) {
    aString = [self expandBinding:aString success:&found];
    if (found)
      aValue = [aValue sortedArrayUsingDescriptors:
			 [CLSortDescriptor sortDescriptorsFromString:aString]];
  }
  
  return aValue;
}

-(void) updateBinding
{
  CLString *aBinding;
  CLArray *anArray;
  id aValue;
  CLUInteger i;


  if ((aBinding = [attributes objectForCaseInsensitiveString:@"CL_BINDING"])) {
    anArray = [[self findArray:[aBinding substringFromIndex:1] source:nil] retain];
    if (!(aBinding = [attributes objectForCaseInsensitiveString:@"CL_ARRAYVALUE"]))
      aBinding = [attributes objectForCaseInsensitiveString:@"CL_ARRAYBINDING"];
    [self setContent:[CLMutableArray array]];
    count = [anArray count];

    if (range.location >= count)
      range.location = ((count + maxItems - 2) / maxItems) * maxItems - maxItems;
    
    for (i = range.location; i < count && i < CLMaxRange(range); i++) {
      aValue = [anArray objectAtIndex:i];
      if (aBinding)
	aValue = [aValue objectValueForBinding:aBinding];
      [self updateBindingFor:aValue];
      if (aValue)
	[self addObject:aValue];
    }
  }

  if ([attributes objectForCaseInsensitiveString:@"CL_AUTONUMBER"])
    [self autonumber:content];

  return;
}

-(CLDictionary *) extraQuery
{
  id ds = [self datasource];


  if ([ds respondsTo:@selector(extraQueryForRangeView:)])
    return [ds extraQueryForRangeView:self];

  return nil;
}

@end
