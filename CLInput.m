/* Copyright 1995-2007 by Chris Osborn <fozztexx@fozztexx.com>
 *
 * Copyright 2008-2016 by
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

#import "CLInput.h"
#import "CLInfoMessage.h"
#import "CLPage.h"
#import "CLForm.h"
#import "CLString.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLNumber.h"
#import "CLCharacterSet.h"
#import "CLOption.h"
#import "CLExpression.h"
#import "CLNull.h"
#import "CLRuntime.h"
#import "CLDatetime.h"
#import "CLNumberFormatter.h"
#import "CLDateFormatter.h"

Class CLInputClass;

static CLString *CLInputTypes[] = {
  @"UNDEFINED",
  @"TEXT",
  @"RADIO",
  @"SUBMIT",
  @"RESET",
  @"PASSWORD",
  @"HIDDEN",
  @"CHECKBOX",
  @"IMAGE",
  @"FILE",
  @"BUTTON",
  @"TEXTAREA",
};

@implementation CLInput

+(void) load
{
  CLInputClass = [CLInput class];
  return;
}

+(CLInput *) hiddenFieldNamed:(CLString *) aString withValue:(id) aValue
{
  return [[[self alloc] initWithTitle:aString cols:0 rows:0 value:aValue
			type:CLHiddenInputType onPage:nil] autorelease];
}

+(CLInput *) checkboxNamed:(CLString *) aString withValue:(id) aValue
{
  return [[[self alloc] initWithTitle:aString cols:0 rows:0 value:aValue
			type:CLCheckboxInputType onPage:nil] autorelease];
}

+(CLInput *) textFieldNamed:(CLString *) aString withValue:(id) aValue
{
  return [[[self alloc] initWithTitle:aString cols:0 rows:0 value:aValue
			type:CLTextInputType onPage:nil] autorelease];
}

-(id) init
{
  return [self initWithTitle:nil cols:0 rows:0 value:nil type:CLTextInputType onPage:nil];
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage
{
  [super initFromString:aString onPage:aPage];
  type = CLTextInputType;
  value = nil;
  originalValue = nil;
  message = nil;
  return self;
}

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString;


  [super initFromElement:anElement onPage:aPage];

  if ((aString = [attributes objectForCaseInsensitiveString:@"TYPE"])) {
    if (![aString caseInsensitiveCompare:@"TEXT"])
      type = CLTextInputType;
    else if (![aString caseInsensitiveCompare:@"RADIO"])
      type = CLRadioInputType;
    else if (![aString caseInsensitiveCompare:@"SUBMIT"])
      type = CLSubmitInputType;
    else if (![aString caseInsensitiveCompare:@"RESET"])
      type = CLResetInputType;
    else if (![aString caseInsensitiveCompare:@"PASSWORD"])
      type = CLPasswordInputType;
    else if (![aString caseInsensitiveCompare:@"HIDDEN"])
      type = CLHiddenInputType;
    else if (![aString caseInsensitiveCompare:@"CHECKBOX"])
      type = CLCheckboxInputType;
    else if (![aString caseInsensitiveCompare:@"IMAGE"])
      type = CLImageInputType;
    else if (![aString caseInsensitiveCompare:@"FILE"])
      type = CLFileInputType;
    else if (![aString caseInsensitiveCompare:@"BUTTON"])
      type = CLButtonInputType;
    [attributes removeObjectForCaseInsensitiveString:@"TYPE"];
  }

  if (![title caseInsensitiveCompare:@"TEXTAREA"])
    type = CLTextareaInputType;

  if ((aString = [attributes objectForCaseInsensitiveString:@"VALUE"])) {
    [self setValue:aString];
    [attributes removeObjectForCaseInsensitiveString:@"VALUE"];
  }

  if ((aString = [attributes objectForCaseInsensitiveString:@"DISABLED"])) {
    [self setDisabled:YES];
    [attributes removeObjectForCaseInsensitiveString:@"DISABLED"];
  }

  return self;
}

-(id) initWithTitle:(CLString *) aTitle
{
  return [self initWithTitle:aTitle cols:0 rows:0 value:nil type:CLTextInputType onPage:nil];
}

-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols
{
  return [self initWithTitle:aTitle cols:aCols rows:0 value:nil type:CLTextInputType onPage:nil];
}

-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols rows:(int) aRows
	      value:(id) aValue type:(CLInputType) aType
	     onPage:(CLPage *) aPage
{
  [self initFromString:NULL onPage:aPage];
  type = aType;
  title = @"INPUT";
  switch (type) {
  case CLTextInputType:
  case CLPasswordInputType:
  case CLRadioInputType:
  case CLSubmitInputType:
  case CLResetInputType:
  case CLHiddenInputType:
  case CLCheckboxInputType:
  case CLImageInputType:
    if (aCols)
      [attributes setObject:[CLNumber numberWithInt:aCols] forCaseInsensitiveString:@"SIZE"];
    break;

  case CLTextareaInputType:
    if (aCols)
      [attributes setObject:[CLNumber numberWithInt:aCols] forCaseInsensitiveString:@"SIZE"];
    if (aRows)
      [attributes setObject:[CLNumber numberWithInt:aRows] forCaseInsensitiveString:@"ROWS"];
    break;

  case CLButtonInputType:
  case CLFileInputType:
    break;
  }

  [self setValue:aValue];

  if (aTitle)
    [attributes setObject:aTitle forCaseInsensitiveString:@"NAME"];
  
  return self;
}

-(void) dealloc
{
  [message release];
  [super dealloc];
  return;
}

-(id) value
{
  return value;
}

-(void) setValue:(id) aValue
{
  if (aValue == value)
    return;

  [originalValue release];
  originalValue = nil;
  
  if ([aValue isKindOfClass:CLStringClass]) {
    originalValue = [aValue copy];
    value = [[aValue stringByTrimmingCharactersInSet:
			      [CLCharacterSet whitespaceAndNewlineCharacterSet]] retain];
    if (![value length]) {
      [value release];
      value = nil;
    }
  }
  else
    value = [aValue copy];
  
  return;
}

-(BOOL) isChecked
{
  BOOL val = NO, success;
  id anObject, aValue;


  if ((anObject = [attributes objectForCaseInsensitiveString:@"CL_CHECKED"])) {
    aValue = [self expandBinding:anObject success:&success];
    if (!aValue && [attributes objectForCaseInsensitiveString:@"CHECKED"])
      val = YES;
    else {
      if (type == CLRadioInputType)
	val = [[aValue description] isEqual:[value description]];
      else if ([aValue isKindOfClass:CLNumberClass])
	val = [aValue boolValue];
      else
	val = !!aValue;
    }
  }
  else if ([attributes objectForCaseInsensitiveString:@"CHECKED"])
    val = YES;
  
  return val;
}

-(BOOL) isDisabled
{
  BOOL val = NO;
  id anObject;


  if ((anObject = [attributes objectForCaseInsensitiveString:@"CL_DISABLED"]))
    val = [self expandBoolean:anObject];
  return val;
}

-(void) setChecked:(BOOL) flag
{
  if (flag)
    [attributes setObject:CLTrueObject forCaseInsensitiveString:@"CHECKED"];
  else
    [attributes removeObjectForCaseInsensitiveString:@"CHECKED"];
  [attributes removeObjectForCaseInsensitiveString:@"CL_CHECKED"];
  return;
}

-(void) setDisabled:(BOOL) flag
{
  [attributes setObject:[CLNumber numberWithBool:flag]
	      forCaseInsensitiveString:@"CL_DISABLED"];
  return;
}

-(id) originalValue
{
  if (!originalValue)
    return value;
  return originalValue;
}

-(CLInputType) type
{
  return type;
}

-(void) setType:(CLInputType) aType
{
  type = aType;
  return;
}

-(id) labelFor:(CLString *) aString inArray:(CLArray *) anArray
{
  int i, j;
  id anObject;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLElementClass]) {
      if ([[[anObject attributes] objectForCaseInsensitiveString:@"FOR"]
	    isEqualToString:aString])
	return anObject;
      if ([anObject respondsTo:@selector(content)] &&
	  [[anObject content] isKindOfClass:CLArrayClass] &&
	  (anObject = [self labelFor:aString inArray:[anObject content]]))
	return anObject;
    }
  }

  return nil;
}

-(id) inputNamed:(CLString *) aString inArray:(CLArray *) anArray
{
  int i, j;
  id anObject;


  for (i = 0, j = [anArray count]; i < j; i++) {
    anObject = [anArray objectAtIndex:i];
    if ([anObject isKindOfClass:CLElementClass]) {
      if ([anObject isKindOfClass:CLInputClass] &&
	  [[[anObject attributes] objectForCaseInsensitiveString:@"NAME"]
	    isEqualToString:aString])
	return anObject;
      if ([anObject respondsTo:@selector(content)] &&
	  [[anObject content] isKindOfClass:CLArrayClass] &&
	  (anObject = [self inputNamed:aString inArray:[anObject content]]))
	return anObject;
    }
  }

  return nil;
}

-(void) setErrorString:(CLString *) aString
{
  [self setErrorString:aString ignoreBinding:NO];
  return;
}

-(void) setErrorString:(CLString *) errorString ignoreBinding:(BOOL) flag
{
  CLString *idString, *aString;
  id anObject;
  CLInput *pageInput;


  [page removeInfoMessage:message];
  [message release];
  message = [[CLInfoMessage alloc] initWithMessage:errorString isError:YES];
  [page addInfoMessage:message];

  pageInput = [[page objectWithID:[[[self form] attributes]
				    objectForCaseInsensitiveString:@"ID"]]
		      fieldNamed:[attributes objectForCaseInsensitiveString:@"NAME"]];
  idString = [[pageInput attributes] objectForCaseInsensitiveString:@"ID"];

  /* FIXME - let the label find the field */
  anObject = [self labelFor:idString inArray:[page body]];
  if (!(aString = [[anObject attributes] objectForCaseInsensitiveString:@"CLASS"]))
    aString = @"";
  else
    aString = [aString stringByAppendingString:@" "];
  aString = [aString stringByAppendingString:@"cl_error"];
  [[anObject attributes] setObject:aString forCaseInsensitiveString:@"CLASS"];
  
  anObject = [self inputNamed:idString inArray:[page body]];
  [anObject setMessage:message];
  [anObject setIgnoreBinding:flag];
  return;
}

-(void) setInfoString:(CLString *) aString
{
  id anObject;
  CLString *idString;

  
  [page removeInfoMessage:message];
  [message release];
  message = [[CLInfoMessage alloc] initWithMessage:aString isError:NO];
  [message setAssociatedObject:self];
  idString = [attributes objectForCaseInsensitiveString:@"NAME"];
  anObject = [self inputNamed:idString inArray:[page body]];
  [anObject setMessage:message];
  [page addInfoMessage:message];
  return;
}

-(void) setIgnoreBinding:(BOOL) flag
{
  ignoreBinding = flag;
  return;
}

-(CLInfoMessage *) message
{
  return message;
}

-(void) setMessage:(CLInfoMessage *) aMessage
{
  if (message != aMessage) {
    [message release];
    message = [aMessage retain];
    [message setAssociatedObject:self];
  }
  return;
}

-(CLForm *) form
{
  id anObject;


  anObject = self;
  while ((anObject = [anObject parentBlock]))
    if ([anObject isKindOfClass:CLFormClass])
      return anObject;

  return nil;
}

-(void) setObjectValue:(id) anObject forBinding:(CLString *) aBinding
{
  CLForm *aForm;
  BOOL setVal = YES;
  id obj1, obj2;


  aForm = [self form];
  if ((obj2 = [self datasource]) &&
      [obj2 respondsTo:@selector(willSetValue:for:)] &&
      ![obj2 willSetValue:anObject for:self])
    setVal = NO;
  if (setVal && (obj1 = [aForm target]) && obj2 != obj1 &&
      [obj1 respondsTo:@selector(willSetValue:for:)] &&
      ![obj1 willSetValue:anObject for:self])
    setVal = NO;
  if (setVal && (obj2 = [[self page] owner]) && obj2 != obj1 &&
      [obj2 respondsTo:@selector(willSetValue:for:)] &&
      ![obj2 willSetValue:anObject for:self])
    setVal = NO;

  if (setVal)
    [super setObjectValue:anObject forBinding:aBinding];
  
  return;
}

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  if (!ignore)
    ignore = [CLMutableArray array];
  [ignore addObjects:@"CL_CHECKED", @"CL_DISABLED", @"CL_SELECTED", nil];
  
  [super writeAttributes:stream ignore:ignore];
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  id aValue;


  if (![self isVisible])
    return;

  if ((type == CLCheckboxInputType || type == CLRadioInputType) && [self isChecked])
    [attributes setObject:CLNullObject forCaseInsensitiveString:@"CHECKED"];
  else
    [attributes removeObjectForCaseInsensitiveString:@"CHECKED"];

  if ([self isDisabled])
    [attributes setObject:CLNullObject forCaseInsensitiveString:@"DISABLED"];
  else
    [attributes removeObjectForCaseInsensitiveString:@"DISABLED"];
  
  aValue = [self originalValue];
  
  switch (type) {
  case CLTextInputType:
  case CLPasswordInputType:
  case CLRadioInputType:
  case CLSubmitInputType:
  case CLResetInputType:
  case CLHiddenInputType:
  case CLCheckboxInputType:
  case CLImageInputType:
  case CLButtonInputType:
    [stream writeFormat:@"<%@ TYPE=%@" usingEncoding:CLUTF8StringEncoding,
	    title, CLInputTypes[type]];
    if (aValue)
      [stream writeFormat:@" VALUE=\"%@\"" usingEncoding:CLUTF8StringEncoding,
	      [[aValue description] entityEncodedString]];
    [self writeAttributes:stream ignore:nil];
    [stream writeString:@" />" usingEncoding:CLUTF8StringEncoding];
    break;
    
  case CLTextareaInputType:
    CLPrintf(stream, @"<TEXTAREA");
    [self writeAttributes:stream ignore:nil];
    CLPrintf(stream, @">");
    if (aValue)
      CLPrintf(stream, @"%@", [[aValue description] entityEncodedString]);
    CLPrintf(stream, @"</TEXTAREA>");
    break;

  case CLFileInputType:
    CLPrintf(stream, @"<%@ TYPE=%@", title, CLInputTypes[type]);
    [self writeAttributes:stream ignore:nil];
    CLPrintf(stream, @" />");
    break;
  }

  return;
}

-(void) updateBinding
{
  CLString *aString;
  id aFormatter;
  id anObject = nil;
  BOOL found, success;


  if (ignoreBinding)
    return;
  
  if ((aString = [attributes objectForCaseInsensitiveString:@"CL_BINDING"])) {
    anObject = [self expandBinding:aString success:&found];
      
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
      [self setValue:anObject];
  }

  return;
}

#if DEBUG_RETAIN
#undef copy
-(id) copy:(const char *) file :(int) line :(id) retainer
{
  CLInput *aCopy;


  aCopy = [super copy:file :line: retainer];
#define copy		copy:__FILE__ :__LINE__ :self
  aCopy->type = type;
  aCopy->value = [value copy];
  
  return aCopy;
}
#else
-(id) copy
{
  CLInput *aCopy;


  aCopy = [super copy];
  aCopy->type = type;
  aCopy->value = [value copy];
  
  return aCopy;
}
#endif

@end
