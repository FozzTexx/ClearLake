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

#import "CLSortDescriptor.h"
#import "CLString.h"
#import "CLMutableArray.h"
#import "CLNull.h"
#import "CLRuntime.h"

@implementation CLSortDescriptor

+(id) sortDescriptorFromKey:(CLString *) aString
{
  return [self sortDescriptorFromKey:aString ascending:YES selector:NULL];
}

+(id) sortDescriptorFromKey:(CLString *) aString ascending:(BOOL) flag
{
  return [self sortDescriptorFromKey:aString ascending:flag selector:NULL];
}

+(id) sortDescriptorFromKey:(CLString *) aString ascending:(BOOL) flag selector:(SEL) sel
{
  return [[[[self class] alloc] initWithKey:aString ascending:flag selector:sel]
	   autorelease];
}

+(CLArray *) sortDescriptorsFromString:(CLString *) aString
{
  CLArray *anArray;
  CLMutableArray *mArray;
  int i, j;


  anArray = [aString componentsSeparatedByString:@","];
  mArray = [[CLMutableArray alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++)
    [mArray addObject:[[self class] sortDescriptorFromKey:[anArray objectAtIndex:i]]];

  return [mArray autorelease];
}

-(id) initWithKey:(CLString *) aString ascending:(BOOL) flag
{
  return [self initWithKey:aString ascending:flag selector:NULL];
}

-(id) initWithKey:(CLString *) aString ascending:(BOOL) flag selector:(SEL) sel
{
  unichar c;

  
  [super init];
  key = [aString copy];
  ascending = flag;

  c = [key characterAtIndex:0];
  if (c == '+' || c == '-') {
    ascending = c == '+';
    aString = [[key substringFromIndex:1] retain];
    [key release];
    key = aString;
  }

  selector = sel;
  
  return self;
}

-(void) dealloc
{
  [key release];
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
  CLSortDescriptor *aCopy;


#if DEBUG_RETAIN
  aCopy = [super copy:file :line :retainer];
#define copy		copy:__FILE__ :__LINE__ :self
#else
  aCopy = [super copy];
#endif
  aCopy->key = [key copy];
  aCopy->ascending = ascending;
  aCopy->selector = selector;
  return aCopy;
}

-(CLString *) key
{
  return key;
}

-(BOOL) ascending
{
  return ascending;
}

-(SEL) selector
{
  return selector;
}

-(id) reversedSortDescriptor
{
  return [[self class] sortDescriptorFromKey:key ascending:ascending selector:selector];
}

-(CLComparisonResult) compareObject:(id) object1 toObject:(id) object2
{
  id val1, val2, vals;
  IMP imp;
  SEL sel = selector;


  val1 = [object1 objectValueForBinding:key];
  val2 = [object2 objectValueForBinding:key];
  if (val1 == CLNullObject)
    val1 = nil;
  if (val2 == CLNullObject)
    val2 = nil;

  if (!ascending) {
    vals = val1;
    val1 = val2;
    val2 = vals;
  }
    
  if (!val1 || !val2) {
    if (!val1 && val2)
      return CLOrderedAscending;
    else if (val1 && !val2)
      return CLOrderedDescending;
    else
      return CLOrderedSame;
  }

  if (!sel) {
    if ([val1 isKindOfClass:CLStringClass] && [val2 isKindOfClass:CLStringClass])
      sel = @selector(caseInsensitiveCompare:);
    else
      sel = @selector(compare:);
  }
  
  if (!(imp = [val1 methodFor:sel]))
    [self error:@"No method for selector %s", sel_getName(sel)];
  
  return ((int (*) (id,SEL,id)) imp)(val1, sel, val2);
}

@end
