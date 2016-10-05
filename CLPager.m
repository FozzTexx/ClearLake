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

#import "CLPager.h"
#import "CLRangeView.h"
#import "CLControl.h"
#import "CLNumber.h"
#import "CLMutableDictionary.h"
#import "CLManager.h"
#import "CLPage.h"
#import "CLMutableArray.h"
#import "CLClassConstants.h"

#define QUERY_START	@"start"
#define STRING_PREV	@"prev"
#define STRING_NEXT	@"next"

@implementation CLPager

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString;
  BOOL success;

  
  [super initFromElement:anElement onPage:aPage];
  maxPages = 9;

  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_MAXPAGES"])) {
    maxPages = [[self expandBinding:aString success:&success] intValue];
    [attributes removeObjectForCaseInsensitiveString:@"CL_MAXPAGES"];
  }
  
  return self;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
#else
-(id) copy
#endif
{
  CLPager *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->maxPages = maxPages;
  return aCopy;
}
      
-(id) read:(CLStream *) stream
{
  CLString *aString;
  CLUInteger start;

  
  [super read:stream];
  [stream readTypes:@"@ii", &aString, &maxPages, &start];
  if (![CLQuery objectForKey:QUERY_START])
    [CLQuery setObject:[CLNumber numberWithUnsignedInt:start] forKey:QUERY_START];
  [attributes setObject:aString forCaseInsensitiveString:@"CL_DATASOURCE"];
  return self;
}

-(void) write:(CLStream *) stream
{
  CLString *aString;
  CLRange aRange;

  
  [super write:stream];
  aRange = [[self datasource] range];
  aString = [attributes objectForCaseInsensitiveString:@"CL_DATASOURCE"];
  [stream writeTypes:@"@ii", &aString, &maxPages, &aRange.location];
  return;
}

-(CLRange) calculateRange
{
  CLUInteger i, start, end, count, maxItems;
  CLRange aRange;
  id aView;

  
  aView = [self datasource];
  aRange = [aView range];
  count = [aView count];
  maxItems = [aView maxItems];
  i = maxItems * (maxPages / 2);
  if (aRange.location < i)
    start = 0;
  else
    start = aRange.location - i;
  end = start + maxItems * maxPages;
  if (end > count)
    end = count;
  if (maxItems * maxPages > end)
    start = 0;
  if (maxItems * (maxPages - 1) <= end && start + maxItems * maxPages > end)
    start = ((end - maxItems * (maxPages - 1)) / maxItems) * maxItems;

  return CLMakeRange(start, end - start);
}

-(BOOL) hasPrevious
{
  CLRange aRange = [[self datasource] range];


  if (aRange.location)
    return YES;

  return NO;
}

-(BOOL) hasNext
{
  CLRange aRange = [[self datasource] range];
  CLUInteger maxItems = [[self datasource] count];


  if (CLMaxRange(aRange) < maxItems)
    return YES;

  return NO;
}

-(BOOL) hasMultiplePages
{
  CLRange aRange = [[self datasource] range];
  CLUInteger maxItems = [[self datasource] count];


  if (maxItems > aRange.length)
    return YES;

  return NO;
}

-(void) first:(id) sender
{
  [CLQuery setObject:[CLNumber numberWithInt:0] forKey:QUERY_START];
  [self goto:sender];
  return;
}

-(void) last:(id) sender
{
  CLRangeView *aView;
  CLString *aString;


  aString = [attributes objectForCaseInsensitiveString:@"CL_DATASOURCE"];
  /* FIXME - should probably do expandBinding but I'm not sure if the
     page is significant. */
  aView = [[sender page] datasourceForBinding:[aString substringFromIndex:1]];
  [CLQuery setObject:[CLNumber numberWithInt:[aView count] - 1] forKey:QUERY_START];
  [self goto:sender];
  return;
}

-(void) previous:(id) sender
{
  CLUInteger start;


  start = [[CLQuery objectForKey:QUERY_START] intValue];
  if (start)
    start--;
  [CLQuery setObject:[CLNumber numberWithInt:start] forKey:QUERY_START];
  [self goto:sender];
  return;
}

-(void) next:(id) sender
{
  CLRangeView *aView;
  CLUInteger start, maxItems;
  CLString *aString;


  aString = [attributes objectForCaseInsensitiveString:@"CL_DATASOURCE"];
  /* FIXME - should probably do expandBinding but I'm not sure if the
     page is significant. */
  aView = [[sender page] datasourceForBinding:[aString substringFromIndex:1]];
  start = [[CLQuery objectForKey:QUERY_START] intValue];
  maxItems = [aView maxItems];
  [CLQuery setObject:[CLNumber numberWithInt:start + maxItems] forKey:QUERY_START];
  [self goto:sender];
  return;
}

-(void) goto:(id) sender
{
  CLRangeView *aView;
  CLString *aString;
  CLRange aRange;
  CLUInteger maxItems;


  aString = [attributes objectForCaseInsensitiveString:@"CL_DATASOURCE"];
  /* FIXME - should probably do expandBinding but I'm not sure if the
     page is significant. */
  aView = [[sender page] datasourceForBinding:[aString substringFromIndex:1]];

  [aView updateBinding];
  maxItems = [aView maxItems];
  if (!maxItems)
    maxItems = 10;
  aRange.location = [[CLQuery objectForKey:QUERY_START] intValue];
  if (aRange.location > [aView count])
    aRange.location = [aView count] - 1;
  aRange.location /= maxItems;
  aRange.location *= maxItems;
  aRange.length = maxItems;
  if (CLMaxRange(aRange) > [aView count])
    aRange.length = [aView count] - aRange.location;
  [CLQuery removeObjectForKey:QUERY_START];
  [aView setRange:aRange];
  return;
}

-(CLBlock *) templateNamed:(CLString *) aString in:(id) aValue
{
  int i, j;
  id anObject;


  if ([aValue isKindOfClass:CLArrayClass]) {
    for (i = 0, j = [aValue count]; i < j; i++)
      if ((anObject = [self templateNamed:aString in:[aValue objectAtIndex:i]]))
	return anObject;
  }

  if ([aValue isKindOfClass:CLBlockClass] &&
      [[[aValue attributes] objectForCaseInsensitiveString:@"name"]
	isEqualToString:aString])
    return aValue;

  if ([aValue respondsTo:@selector(content)] &&
      [(anObject = [aValue content]) isKindOfClass:CLArrayClass] &&
      (anObject = [self templateNamed:aString in:anObject]))
    return anObject;

  return nil;
}

-(void) setDatasource:(id) aDatasource for:(id) anObject
{
  int i, j;


  if ([anObject isKindOfClass:CLArrayClass])
    for (i = 0, j = [anObject count]; i < j; i++)
      [self setDatasource:aDatasource for:[anObject objectAtIndex:i]];

  if ([anObject isKindOfClass:CLBlockClass])
    [anObject setDatasource:aDatasource];

  if ([anObject respondsTo:@selector(content)] &&
      [(anObject = [anObject content]) isKindOfClass:CLArrayClass])
    [self setDatasource:aDatasource for:anObject];

  return;
}

-(void) setTargetFor:(id) anObject
{
  int i, j;


  if ([anObject isKindOfClass:CLArrayClass])
      for (i = 0, j = [anObject count]; i < j; i++)
	[self setTargetFor:[anObject objectAtIndex:i]];

  if ([anObject isKindOfClass:CLControlClass])
    [anObject setTarget:self];

  if ([anObject respondsTo:@selector(content)] &&
      [(anObject = [anObject content]) isKindOfClass:CLArrayClass])
    [self setTargetFor:anObject];

  return;
}

-(BOOL) replaceTemplates:(id) aValue with:(id) anObject
{
  int i, j, k, nf;
  id aBlock;
  CLString *aString;

  
  if ([aValue isKindOfClass:CLArrayClass]) {
    for (i = k = nf = 0, j = [aValue count]; i < j && nf < 2; i++) {
      aBlock = [aValue objectAtIndex:i];
      if ([aBlock isKindOfClass:CLBlockClass]) {
	aString = [[aBlock attributes] objectForCaseInsensitiveString:@"name"];
	if ([aString isEqualToString:@"cl_active"] ||
	    [aString isEqualToString:@"cl_inactive"]) {
	  if (!nf)
	    k = i;
	  nf++;
	}
      }
    }

    [aValue removeObjectsInRange:CLMakeRange(k, i-k)];
    [aValue insertObject:anObject atIndex:k];
    return YES;
  }
  else if ([aValue respondsTo:@selector(content)] &&
      [(aValue = [aValue content]) isKindOfClass:CLArrayClass] &&
      [self replaceTemplates:aValue with:anObject])
    return YES;

  return NO;
}

-(void) updateBindingFor:(id) anObject
{
  if ([anObject isKindOfClass:CLControlClass])
    [[anObject localQuery] addEntriesFromDictionary:[[self datasource] extraQuery]];
  [super updateBindingFor:anObject];
  
  return;
}

-(void) updateBinding
{
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  CLUInteger i, start, end, maxItems;
  CLRange aRange;
  CLControl *aControl;
  CLString *aString;
  CLMutableArray *mArray;
  CLBlock *aBlock;
  id aValue;
  CLDictionary *extraQuery = nil;


  if (![self isVisible])
    return;

  mArray = [[CLMutableArray alloc] init];
  if ([[self datasource] respondsTo:@selector(extraQuery)])
    extraQuery = [[self datasource] extraQuery];
  
  aRange = [self calculateRange];
  start = aRange.location;
  end = CLMaxRange(aRange);
  aRange = [[self datasource] range];
  maxItems = [[self datasource] maxItems];
  
  for (i = start; i < end; i += maxItems) {
    aString = [CLString stringWithFormat:@"%i", (i + maxItems - 1) / maxItems + 1];
    aControl = [[[CLControl alloc] init] autorelease];
    [aControl setTarget:self];
    [aControl setAction:@selector(goto:)];
    [[aControl localQuery] setObject:[CLNumber numberWithInt:i] forKey:QUERY_START];
    [[aControl localQuery] addEntriesFromDictionary:extraQuery];
    [aControl addObject:aString];
    [aControl setPage:page];
    
    if (i < aRange.location || i >= CLMaxRange(aRange)) {
      if ((aBlock = [self templateNamed:@"cl_active" in:content])) {
	aBlock = [aBlock copy];
	[mArray addObject:aBlock];
	[self setDatasource:aControl for:aBlock];
      }
      else
	[mArray addObject:aControl];
    }
    else {
      if ((aBlock = [self templateNamed:@"cl_inactive" in:content])) {
	aBlock = [aBlock copy];
	[mArray addObject:aBlock];
	[self setDatasource:aControl for:aBlock];
      }
      else
	[mArray addObject:aString];
    }
  }

  if (content) {
    if ([content isKindOfClass:CLArrayClass])
      aValue = [[CLMutableArray alloc] initWithArray:content copyItems:YES];
    else
      aValue = [content copy];
  }
  else
    aValue = [[CLBlock alloc] init];

  [self setDatasource:self for:aValue];
  [self setTargetFor:aValue];
  
  if (![self replaceTemplates:aValue with:mArray])
    [aValue addObject:mArray];

  [self updateBindingFor:aValue];
  CLWriteHTMLObject(stream, aValue);
  [mArray release];
  [aValue release];
  
  return;
}

@end
