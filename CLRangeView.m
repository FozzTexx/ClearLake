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

#import "CLRangeView.h"
#import "CLArray.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLSortDescriptor.h"
#import "CLPage.h"

@implementation CLRangeView

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString;

  
  [super initFromElement:anElement onPage:aPage];

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_MAXITEMS"])) {
    maxItems = [aString intValue];
    [attributes removeObjectForCaseInsensitiveString:@"CL_MAXITEMS"];
  }
  else
    maxItems = 10;
  [self setRange:CLMakeRange([[attributes objectForCaseInsensitiveString:@"CL_START"]
			       intValue], maxItems)];
  
  return self;
}

-(id) copy
{
  CLRangeView *aCopy;


  aCopy = [super copy];
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


  aRange = [aBinding rangeOfString:@":"];
  if (aRange.length) {
    anObject = [page datasourceForBinding:[aBinding substringToIndex:aRange.location]];
    aBinding = [aBinding substringFromIndex:CLMaxRange(aRange)];
  }
  else if ([aBinding hasPrefix:@"#"]) {
    aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
    anObject = [page datasourceForBinding:[aBinding substringToIndex:aRange.location]];
    aBinding = [aBinding substringFromIndex:CLMaxRange(aRange)];
  }
  
  aRange = [aBinding rangeOfString:@"." options:0 range:CLMakeRange(0, [aBinding length])];
  if (aRange.length)
    aString = [aBinding substringToIndex:aRange.location];
  else
    aString = aBinding;

  aValue = [anObject objectValueForBinding:aString];
  if (![aValue isKindOfClass:[CLArray class]]) {
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
    aString = [self objectValueForSpecialBinding:aString allowConstant:YES
			 found:&found wasConstant:NULL];
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


  if ((aBinding = [attributes objectForCaseInsensitiveString:@"CL_VALUE"]) ||
      (aBinding = [attributes objectForCaseInsensitiveString:@"CL_BINDING"])) {
    anArray = [[self findArray:aBinding source:[self datasource]] retain];
    if (!(aBinding = [attributes objectForCaseInsensitiveString:@"CL_ARRAYVALUE"]))
      aBinding = [attributes objectForCaseInsensitiveString:@"CL_ARRAYBINDING"];
    [self setValue:[CLMutableArray array]];
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
    [self autonumber:value];

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
