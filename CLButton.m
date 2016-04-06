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

#import "CLButton.h"
#import "CLStream.h"
#import "CLNull.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLNumber.h"
#import "CLSortDescriptor.h"
#import "CLNumberFormatter.h"
#import "CLDateFormatter.h"
#import "CLDatetime.h"
#import "CLCharacterSet.h"
#import "CLMutableString.h"

Class CLButtonClass;

@implementation CLButton

+(void) load
{
  CLButtonClass = [CLButton class];
  return;
}

-(void) addObject:(id) anObject
{
  CLMutableArray *mArray;

  
  if (![content isKindOfClass:CLMutableArrayClass]) {
    mArray = [[CLMutableArray alloc] init];
    if (content)
      [mArray addObject:content];
    [content release];
    content = mArray;
  }
  
  [content addObject:anObject];
  if ([anObject respondsTo:@selector(setPage:)])
    [anObject setPage:page];
  if ([anObject respondsTo:@selector(setParentBlock:)])
    [anObject setParentBlock:self];
  
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  if (![self isVisible])
    return;

  [stream writeFormat:@"<%@" usingEncoding:CLUTF8StringEncoding, title];
  if (value)
    [stream writeFormat:@" VALUE=\"%@\"" usingEncoding:CLUTF8StringEncoding,
	    [[value description] entityEncodedString]];
  [self writeAttributes:stream ignore:nil];
  [stream writeString:@">" usingEncoding:CLUTF8StringEncoding];
  if (content)
    CLWriteHTMLObject(stream, content);
  [stream writeFormat:@"</%@>" usingEncoding:CLUTF8StringEncoding, title];

  return;
}

@end

@implementation CLButton (NotInherited)

-(void) setPageFor:(id) anObject
{
  int i, j;

  
  if ([anObject isKindOfClass:CLArrayClass]) {
    for (i = 0, j = [anObject count]; i < j; i++)
      [self setPageFor:[anObject objectAtIndex:i]];
  }
  else if ([anObject respondsTo:@selector(setPage:)])
    [anObject setPage:page];
  return;
}
    
-(void) setContent:(id) anObject
{
  [content autorelease];
  if ([anObject isKindOfClass:CLArrayClass] &&
      ![anObject isKindOfClass:CLMutableArrayClass]) {
    if ([content isKindOfClass:CLMutableArrayClass]) {
      [content retain];
      [content removeAllObjects];
      [content addObjectsFromArray:anObject];
    }
    else {
      content = [anObject mutableCopy];
    }
  }
  else if ([content isKindOfClass:CLMutableStringClass])
    content = [anObject copy];
  else
    content = [anObject retain];

  [self setPageFor:content];
  
  return;
}

-(void) autonumber:(id) anObject position:(int) index
	  replaced:(CLMutableDictionary *) replaced
{
  int i, j;
  CLMutableDictionary *mDict;
  CLString *aString, *newString;


  if ([anObject isKindOfClass:CLArrayClass]) {
    for (i = 0, j = [anObject count]; i < j; i++)
      [self autonumber:[anObject objectAtIndex:i] position:index replaced:replaced];
  }
  else if ([anObject isKindOfClass:CLElementClass]) {
    if ((mDict = [anObject attributes])) {
      if ((aString = [mDict objectForCaseInsensitiveString:@"NAME"]) &&
	  (![anObject isKindOfClass:CLInputClass] ||
	   [anObject type] != CLRadioInputType ||
	   [attributes objectForCaseInsensitiveString:@"CL_AUTORADIO"])) {
	aString = [aString stringByAppendingFormat:@"_%i", index];
	[mDict setObject:aString forCaseInsensitiveString:@"NAME"];
      }
      if ((aString = [mDict objectForCaseInsensitiveString:@"ID"])) {
	newString = [aString stringByAppendingFormat:@"_%i", index];
	[replaced setObject:newString forKey:aString];
	[mDict setObject:newString forCaseInsensitiveString:@"ID"];
      }
      if ((aString = [mDict objectForCaseInsensitiveString:@"FOR"])) {
	aString = [aString stringByAppendingFormat:@"_%i", index];
	[mDict setObject:aString forCaseInsensitiveString:@"FOR"];
      }
    }
	
    if ([anObject isKindOfClass:CLBlockClass] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [self autonumber:[anObject content] position:index replaced:replaced];
  }

  return;
}

-(CLString *) fixIDs:(CLString *) aString newIDs:(CLDictionary *) aDict
{
  CLRange aRange, aRange2, aRange3;
  int i, j;
  CLMutableString *mString;
  CLString *subString, *aKey;
  CLArray *anArray;
  CLCharacterSet *anuSet;


  anuSet = [CLCharacterSet alphaNumericUnderscoreCharacterSet];
  mString = [[aString mutableCopy] autorelease];
  aRange = [mString rangeOfString:@"@:"];
  while (aRange.length) {
    aRange2.location = CLMaxRange(aRange);
    aRange2.length = [mString length] - aRange2.location;
    aRange2 = [mString rangeOfCharacterNotFromSet:anuSet options:0 range:aRange2];
    if (!aRange2.length)
      aRange2.location = [mString length];

    aRange3.location = CLMaxRange(aRange);
    aRange3.length = aRange2.location - aRange3.location;
    subString = [mString substringWithRange:aRange3];

    anArray = [aDict allKeys];
    for (i = 0, j = [anArray count]; i < j; i++) {
      aKey = [anArray objectAtIndex:i];
      if ([aKey isEqualToString:subString]) {
	subString = [aDict objectForKey:aKey];
	break;
      }
    }

    if (i < j)
      [mString replaceCharactersInRange:aRange3 withString:subString];

    aRange2.location = aRange3.location + [subString length];
    aRange2.length = [mString length] - aRange2.location;
    aRange = [mString rangeOfString:@"@:" options:0 range:aRange2];
  }

  return mString;
}

-(void) autonumber:(id) anObject newIDs:(CLDictionary *) replaced
{
  int i, j;
  CLMutableDictionary *mDict;
  CLString *aString, *aKey;
  CLArray *anArray;


  if ([anObject isKindOfClass:CLArrayClass]) {
    for (i = 0, j = [anObject count]; i < j; i++)
      [self autonumber:[anObject objectAtIndex:i] newIDs:replaced];
  }
  else if ([anObject isKindOfClass:CLElementClass]) {
    if ((mDict = [anObject attributes])) {
      anArray = [mDict allKeys];
      for (i = 0, j = [anArray count]; i < j; i++) {
	aKey = [anArray objectAtIndex:i];
	if ([aKey hasPrefix:@"cl_"]) {
	  aString = [mDict objectForKey:aKey];
	  if ([aString isKindOfClass:CLStringClass]) {
	    aString = [self fixIDs:aString newIDs:replaced];
	    [mDict setObject:aString forKey:aKey];
	  }
	}
      }
    }
	
    if ([anObject isKindOfClass:CLBlockClass] &&
	[[anObject content] isKindOfClass:CLArrayClass])
      [self autonumber:[anObject content] newIDs:replaced];
  }

  return;
}

-(void) autonumber:(CLArray *) anArray
{
  int i, j;
  CLMutableDictionary *mDict;
  id anObject;


  mDict = [[CLMutableDictionary alloc] init];
  for (i = 0, j = [anArray count]; i < j; i++) {
    [mDict removeAllObjects];
    anObject = [anArray objectAtIndex:i];
    [self autonumber:anObject position:i+1 replaced:mDict];
    if ([mDict count])
      [self autonumber:anObject newIDs:mDict];
  }
  
  [mDict release];
  
  return;
}

-(void) updateBindingFor:(id) anObject
{
  CLUInteger count;
  id *items;
  int i;


  if ([anObject isKindOfClass:CLArrayClass] && [anObject count]) {
    /* Nasty nasty nasty nasty. Array could grow/shrink when updating
       bindings. Copy the array and update everything in it. Things
       that insert new objects are responsible for making sure they
       get updated. */

    count = [anObject count];
    items = alloca(count * sizeof(id));
    [anObject getObjects:items];
    for (i = 0; i < count; i++)
      [self updateBindingFor:items[i]];
  }

  if ([anObject respondsTo:@selector(updateBinding)])
    [anObject updateBinding];

  return;
}

-(void) updateBinding
{
  CLString *aString, *sortString;
  id aFormatter;
  id anObject = nil;
  BOOL found, success;
  CLRange aRange;


  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_BINDING"])) {
    aRange = [aString rangeOfString:@".objects." options:0
		      range:CLMakeRange(0, [aString length])];
    if (aRange.length && ![attributes objectForCaseInsensitiveString:@"CL_AUTONUMBER"])
      [attributes setObject:CLTrueObject forCaseInsensitiveString:@"CL_AUTONUMBER"];
    
    if (aRange.length &&
	(sortString = [attributes objectForCaseInsensitiveString:@"CL_SORT"])) {
      sortString = [self expandBinding:sortString success:&success];
      anObject = [self expandBinding:[aString substringToIndex:aRange.location]
			     success:&found];
      anObject = [anObject sortedArrayUsingDescriptors:
			     [CLSortDescriptor sortDescriptorsFromString:sortString]];
      anObject = [anObject objectValueForBinding:
			     [aString substringFromIndex:aRange.location+1]];
    }
    else {
      anObject = [self expandBinding:aString success:&found];
      if ([anObject isKindOfClass:CLArrayClass] &&
	  (sortString = [attributes objectForCaseInsensitiveString:@"CL_SORT"])) {
	sortString = [self expandBinding:sortString success:&success];
	anObject = [anObject sortedArrayUsingDescriptors:
			       [CLSortDescriptor sortDescriptorsFromString:sortString]];
      }
    }
      
    if ((aString = [attributes objectForCaseInsensitiveString:@"CL_FORMAT"])) {
      if ([anObject isKindOfClass:CLNumberClass]) {
	aFormatter = [CLNumberFormatter numberFormatterFromFormat:
					      [self expandBinding:aString success:&success]];
	anObject = [aFormatter stringForObjectValue:anObject];
      }
      else if ([anObject isKindOfClass:CLDatetimeClass]) {
	aFormatter = [CLDateFormatter dateFormatterFromFormat:aString];
	anObject = [aFormatter stringForObjectValue:anObject];
      }
    }

    if (found)
      [self setContent:anObject];
  }

  /* FIXME - Blah, we need to find another way to deal with this. If
     we update the bindings before the autonumber then cl_bindings
     that reference an ID won't get fixed. If we do the update after
     the autonumber, then the double autonumber doesn't happen. */
  
  [self updateBindingFor:content];

  if ([content isKindOfClass:CLArrayClass] &&
      (anObject = [attributes objectForCaseInsensitiveString:@"CL_AUTONUMBER"]) &&
      (anObject == CLNullObject || [self expandBoolean:anObject]))
    [self autonumber:content]; 

  return;
}

@end
