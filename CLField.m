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

#import "CLField.h"
#import "CLString.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLNumber.h"
#import "CLCharacterSet.h"
#import "CLOption.h"
#import "CLPage.h"
#import "CLForm.h"
#import "CLExpression.h"
#import "CLNull.h"
#import "CLObjCAPI.h"

static CLString *CLFieldTypes[] = {
  @"UNDEFINED",
  @"TEXT",
  @"RADIO",
  @"SUBMIT",
  @"RESET",
  @"TEXTAREA",
  @"PASSWORD",
  @"SELECT",
  @"HIDDEN",
  @"CHECKBOX",
  @"IMAGE",
  @"FILE",
  @"BUTTON",
};

@implementation CLField

+(CLField *) hiddenFieldNamed:(CLString *) aString withValue:(id) aValue
{
  return [[[self alloc] initWithTitle:aString cols:0 rows:0 value:aValue
			type:CLHiddenFieldType onPage:nil] autorelease];
}

+(CLField *) checkboxNamed:(CLString *) aString withValue:(id) aValue
{
  return [[[self alloc] initWithTitle:aString cols:0 rows:0 value:aValue
			type:CLCheckboxFieldType onPage:nil] autorelease];
}

+(CLField *) textFieldNamed:(CLString *) aString withValue:(id) aValue
{
  return [[[self alloc] initWithTitle:aString cols:0 rows:0 value:aValue
			type:CLTextFieldType onPage:nil] autorelease];
}

-(id) init
{
  return [self initWithTitle:nil cols:0 rows:0 value:nil type:CLTextFieldType onPage:nil];
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage
{
  [super initFromString:aString onPage:aPage];
  type = CLTextFieldType;
  value = nil;
  originalValue = nil;
  return self;
}

-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage
{
  CLString *aString;


  [super initFromElement:anElement onPage:aPage];

  if ((aString = [attributes objectForCaseInsensitiveString:@"TYPE"])) {
    if (![aString caseInsensitiveCompare:@"TEXT"])
      type = CLTextFieldType;
    else if (![aString caseInsensitiveCompare:@"RADIO"])
      type = CLRadioFieldType;
    else if (![aString caseInsensitiveCompare:@"SUBMIT"])
      type = CLSubmitFieldType;
    else if (![aString caseInsensitiveCompare:@"RESET"])
      type = CLResetFieldType;
    else if (![aString caseInsensitiveCompare:@"PASSWORD"])
      type = CLPasswordFieldType;
    else if (![aString caseInsensitiveCompare:@"HIDDEN"])
      type = CLHiddenFieldType;
    else if (![aString caseInsensitiveCompare:@"CHECKBOX"])
      type = CLCheckboxFieldType;
    else if (![aString caseInsensitiveCompare:@"IMAGE"])
      type = CLImageFieldType;
    else if (![aString caseInsensitiveCompare:@"FILE"])
      type = CLFileFieldType;
    else if (![aString caseInsensitiveCompare:@"BUTTON"])
      type = CLButtonFieldType;
    [attributes removeObjectForCaseInsensitiveString:@"TYPE"];
  }

  if (![title caseInsensitiveCompare:@"TEXTAREA"])
    type = CLTextareaFieldType;

  if (![title caseInsensitiveCompare:@"SELECT"]) {
    type = CLSelectFieldType;
    [super setValue:[CLMutableArray array]];
  }
  
  if ((aString = [attributes objectForCaseInsensitiveString:@"VALUE"])) {
    [self setValue:aString];
    [attributes removeObjectForCaseInsensitiveString:@"VALUE"];
  }
  if ((aString = [attributes objectForCaseInsensitiveString:@"ENABLED"])) {
    if (![aString caseInsensitiveCompare:@"NO"])
      [self setEnabled:NO];
    [attributes removeObjectForCaseInsensitiveString:@"ENABLED"];
  }

  return self;
}

-(id) initWithTitle:(CLString *) aTitle
{
  return [self initWithTitle:aTitle cols:0 rows:0 value:nil type:CLTextFieldType onPage:nil];
}

-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols
{
  return [self initWithTitle:aTitle cols:aCols rows:0 value:nil type:CLTextFieldType onPage:nil];
}

-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols rows:(int) aRows
	      value:(id) aValue type:(CLFieldType) aType
	     onPage:(CLPage *) aPage
{
  [self initFromString:NULL onPage:aPage];
  type = aType;
  title = @"INPUT";
  switch (type) {
  case CLTextFieldType:
  case CLPasswordFieldType:
  case CLRadioFieldType:
  case CLSubmitFieldType:
  case CLResetFieldType:
  case CLHiddenFieldType:
  case CLCheckboxFieldType:
  case CLImageFieldType:
  case CLButtonFieldType:
    if (aCols)
      [attributes setObject:[CLNumber numberWithInt:aCols] forCaseInsensitiveString:@"SIZE"];
    break;

  case CLTextareaFieldType:
    if (aCols)
      [attributes setObject:[CLNumber numberWithInt:aCols] forCaseInsensitiveString:@"SIZE"];
    if (aRows)
      [attributes setObject:[CLNumber numberWithInt:aRows] forCaseInsensitiveString:@"ROWS"];
    break;

  case CLSelectFieldType:
    [super setValue:[CLMutableArray array]];
    break;

  case CLFileFieldType:
    break;
  }

  /* FIXME - Some of the brain damaged WYSIWYG javascript editors are
     not decoding the HTML entities and are sending them encoded. Need
     a way to test for the brain damaged editor and use [aValue
     entityDecodedString] instead. */
  if (type != CLSelectFieldType)
    [self setValue:aValue];

  if (aTitle)
    [attributes setObject:aTitle forCaseInsensitiveString:@"NAME"];
  
  return self;
}

-(id) copy
{
  CLField *aCopy;


  aCopy = [super copy];
  aCopy->type = type;
  aCopy->value = [value copy];
  
  return aCopy;
}

-(void) setValue:(id) aValue
{
  if (aValue == value)
    return;

  [originalValue release];
  originalValue = nil;
  
  if (type == CLSelectFieldType) {
    [super setValue:[CLMutableArray array]];
    if ([aValue isKindOfClass:[CLArray class]]) {
      int i, j;
      id anObject;


      for (i = 0, j = [aValue count]; i < j; i++) {
	anObject = [aValue objectAtIndex:i];
	if ([anObject isKindOfClass:[CLOption class]])
	  [value addObject:anObject];
	else
	  [self addOption:anObject withValue:nil];
      }
    }
    else if ([aValue isKindOfClass:[CLOption class]])
      [value addObject:aValue];
    else
      [self addOption:aValue withValue:nil];
  }
  else {
    if ([aValue isKindOfClass:[CLString class]]) {
      originalValue = [aValue copy];
      [super setValue:[aValue stringByTrimmingCharactersInSet:
			       [CLCharacterSet whitespaceAndNewlineCharacterSet]]];
      if (![value length]) {
	[super setValue:nil];
      }
    }
    else
      [super setValue:[[aValue copy] autorelease]];
  }
  
  return;
}

-(void) addObject:(id) anObject
{
  if (type != CLSelectFieldType) {
    if (!value && [anObject isKindOfClass:[CLString class]])
      [self setValue:[[anObject copy] autorelease]];
#if 0
    else
      [self error:@"%@ objects should not be sent '%s' messages\n",
	    title, sel_getName(_cmd)];
#endif
  }
  else if ([anObject isKindOfClass:[CLElement class]]) {
    [self addOption:nil withValue:[[anObject attributes]
				    objectForCaseInsensitiveString:@"VALUE"]];
    if ([[anObject attributes] objectForCaseInsensitiveString:@"SELECTED"])
      [self selectOptionWithValue:[[anObject attributes]
				    objectForCaseInsensitiveString:@"VALUE"]];
  }
  else
    [self addOption:anObject withValue:nil];

  return;
}

-(BOOL) isChecked
{
  BOOL val = NO;
  id anObject, aValue;
  CLExpression *anExp;


  if ((anObject = [attributes objectForCaseInsensitiveString:@"CL_CHECKED"])) {
    anExp = [[CLExpression alloc] initFromString:anObject];
    aValue = [anExp evaluate:self];
    [anExp release];
    if (!aValue && [attributes objectForCaseInsensitiveString:@"CHECKED"])
      val = YES;
    else {
      if (type == CLRadioFieldType)
	val = [[aValue description] isEqual:[value description]];
      else if ([aValue isKindOfClass:[CLNumber class]])
	val = [aValue boolValue];
      else
	val = !!aValue;
    }
  }
  else if ([attributes objectForCaseInsensitiveString:@"CHECKED"])
    val = YES;
  
  return val;
}

/* This may seem redundant but CLField does not inherit from CLControl */
-(BOOL) isEnabled
{
  BOOL val = YES, wasConst = NO;
  id anObject;
  CLExpression *anExp;


  if ((anObject = [attributes objectForCaseInsensitiveString:@"CL_ENABLED"])) {
    if ([anObject isKindOfClass:[CLString class]] && [anObject characterAtIndex:0] == '=') {
      anExp = [[CLExpression alloc] initFromString:[anObject substringFromIndex:1]];
      anObject = [anExp evaluate:self];
      [anExp release];
    }
    else
      wasConst = YES;

    if (wasConst || [anObject isKindOfClass:[CLNumber class]])
      val = [anObject boolValue];
    else
      val = !!anObject;
  }
  
  return val;
}

-(void) setChecked:(BOOL) flag
{
  if (flag)
    [attributes setObject:[CLNumber numberWithBool:YES]
		forCaseInsensitiveString:@"CHECKED"];
  else
    [attributes removeObjectForCaseInsensitiveString:@"CHECKED"];
  [attributes removeObjectForCaseInsensitiveString:@"CL_CHECKED"];
  return;
}

-(void) setEnabled:(BOOL) flag
{
  [attributes setObject:[CLNumber numberWithBool:flag]
	      forCaseInsensitiveString:@"CL_ENABLED"];
  return;
}

-(void) selectOptionWithValue:(id) aValue
{
  int i, j;
  CLOption *anOption;
  id optionValue;

  
  if (!aValue)
    return;

  aValue = [aValue description];
  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    if (!(optionValue = [anOption value]))
      optionValue = [anOption string];
    optionValue = [optionValue description];
    [anOption setSelected:[optionValue isEqual:aValue]];
  }

  return;
}

-(void) selectOptionWithName:(CLString *) aString
{
  int i, j;
  CLOption *anOption;

  
  if (!aString)
    return;

  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    [anOption setSelected:[[anOption string] isEqualToString:aString]];
  }

  return;
}

-(void) selectOption:(int) index
{
  int i, j;
  CLOption *anOption;

  
  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    [anOption setSelected:i == index];
  }

  return;
}

-(CLOption *) selectedOption
{
  int i, j;
  CLOption *anOption;

  
  for (i = 0, j = [value count]; i < j; i++) {
    anOption = [value objectAtIndex:i];
    if ([anOption selected])
      return anOption;
  }

  return nil;
}

-(int) numOptions
{
  return [value count];
}

-(void) addOption:(CLString *) aString withValue:(id) aValue
{
  aString = [aString stringByTrimmingCharactersInSet:
		       [CLCharacterSet whitespaceAndNewlineCharacterSet]];
  if (![aString length])
    aString = nil;
  if (!aString && !aValue)
    return;
  
  if (!aValue && [value count] && ![[value lastObject] string])
    [[value lastObject] setString:aString];
  else
    [value addObject:[[[CLOption alloc]
			initWithString:aString andValue:aValue] autorelease]];
  
  return;
}

-(void) removeAllOptions
{
  [value removeAllObjects];
  return;
}

-(id) originalValue
{
  if (!originalValue)
    return value;
  return originalValue;
}

-(CLFieldType) type
{
  return type;
}

-(void) setType:(CLFieldType) aType
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
    if ([anObject isKindOfClass:[CLElement class]]) {
      if ([[[anObject attributes] objectForCaseInsensitiveString:@"FOR"]
	    isEqualToString:aString])
	return anObject;
      if ([anObject respondsTo:@selector(value)] &&
	  [[anObject value] isKindOfClass:[CLArray class]] &&
	  (anObject = [self labelFor:aString inArray:[anObject value]]))
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
    if ([anObject isKindOfClass:[CLElement class]]) {
      if ([anObject isKindOfClass:[CLField class]] &&
	  [[[anObject attributes] objectForCaseInsensitiveString:@"NAME"]
	    isEqualToString:aString])
	return anObject;
      if ([anObject respondsTo:@selector(value)] &&
	  [[anObject value] isKindOfClass:[CLArray class]] &&
	  (anObject = [self inputNamed:aString inArray:[anObject value]]))
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


  if (errorString)
    [page appendErrorString:errorString];
  idString = [attributes objectForCaseInsensitiveString:@"NAME"];
  anObject = [self labelFor:idString inArray:[page body]];
  if (!(aString = [[anObject attributes] objectForCaseInsensitiveString:@"CLASS"]))
    aString = @"";
  else
    aString = [aString stringByAppendingString:@" "];
  aString = [aString stringByAppendingString:@"error"];
  [[anObject attributes] setObject:aString forCaseInsensitiveString:@"CLASS"];
  anObject = [self inputNamed:idString inArray:[page body]];
  [anObject setIgnoreBinding:flag];
  return;
}

-(void) setInfoString:(CLString *) aString
{
  if (aString)
    [[self page] appendInfoString:aString];
  return;
}

-(void) setIgnoreBinding:(BOOL) flag
{
  ignoreBinding = flag;
  return;
}

-(CLForm *) form
{
  id anObject;


  while ((anObject = [self parentBlock]))
    if ([anObject isKindOfClass:[CLForm class]])
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

-(void) updateBinding
{
  if (!ignoreBinding)
    [super updateBinding];
  return;
}

-(void) writeHTML:(CLStream *) stream
{
  BOOL parentEnabled = YES;
  id form = self;


  while (form) {
    form = [form parentBlock];
    if ([form isKindOfClass:[CLForm class]]) {
      parentEnabled = [form isEnabled];
      break;
    }
  }
  
  [self writeHTML:stream parentEnabled:parentEnabled];
  return;
}

-(void) writeAttributes:(CLStream *) stream ignore:(CLMutableArray *) ignore
{
  if (!ignore)
    ignore = [CLMutableArray array];
  [ignore addObjects:@"CL_CHECKED", @"CL_ENABLED", @"CL_SELECTED", nil];
  
  [super writeAttributes:stream ignore:ignore];
  return;
}

-(void) writeHTML:(CLStream *) stream parentEnabled:(BOOL) parentEnabled
{
  int i, j;
  id aValue;
  BOOL found;


  if (![self isVisible])
    return;

  if ((type == CLCheckboxFieldType || type == CLRadioFieldType) && [self isChecked])
    [attributes setObject:[CLNull null] forCaseInsensitiveString:@"CHECKED"];
  else
    [attributes removeObjectForCaseInsensitiveString:@"CHECKED"];

  if ((!parentEnabled || ![self isEnabled]) && type != CLHiddenFieldType) {
    id str, val;

    
    str = val = value;
    if (type == CLSelectFieldType) {
      aValue = [self selectedOption];
      str = [aValue string];
      val = [aValue value];
      if (!val)
	val = str;
    }
    
    if (val && ((type != CLSubmitFieldType && type != CLResetFieldType &&
		 type != CLButtonFieldType) ||
		(!parentEnabled && type != CLHiddenFieldType))) {
      if (parentEnabled) {
	CLPrintf(stream, @"<INPUT TYPE=\"HIDDEN\" VALUE=\"%@\"",
		 [[val description] entityEncodedString]);
	[self writeAttributes:stream ignore:nil];
	CLPrintf(stream, @" />");
      }
      CLPrintf(stream, @"%@", [str description]);
    }
    return;
  }

  aValue = [self originalValue];
  
  switch (type) {
  case CLTextFieldType:
  case CLPasswordFieldType:
  case CLRadioFieldType:
  case CLSubmitFieldType:
  case CLResetFieldType:
  case CLHiddenFieldType:
  case CLCheckboxFieldType:
  case CLImageFieldType:
  case CLButtonFieldType:
    if ([title caseInsensitiveCompare:@"BUTTON"]) {
      CLPrintf(stream, @"<%@ TYPE=%@", title, CLFieldTypes[type]);
      if (aValue)
	CLPrintf(stream, @" VALUE=\"%@\"", [[aValue description] entityEncodedString]);
      [self writeAttributes:stream ignore:nil];
      CLPrintf(stream, @" />");
    }
    else {
      CLPrintf(stream, @"<%@", title);
      [self writeAttributes:stream ignore:nil];
      CLPrintf(stream, @">");
      if (aValue)
	CLWriteHTMLObject(stream, aValue);
      CLPrintf(stream, @" </%@>", title);
    }
    break;
    
  case CLTextareaFieldType:
    CLPrintf(stream, @"<TEXTAREA");
    [self writeAttributes:stream ignore:nil];
    CLPrintf(stream, @">");
    if (aValue)
      CLPrintf(stream, @"%@", [[aValue description] entityEncodedString]);
    CLPrintf(stream, @"</TEXTAREA>");
    break;

  case CLSelectFieldType:
    if ((aValue = [attributes objectForCaseInsensitiveString:@"CL_SELECTED"])) {
      aValue = [self objectValueForSpecialBinding:aValue allowConstant:NO
		     found:&found wasConstant:NULL];
      [self selectOptionWithValue:aValue];
    }
  
    CLPrintf(stream, @"<SELECT");
    [self writeAttributes:stream ignore:nil];
    CLPrintf(stream, @">");
    for (i = 0, j = [value count]; i < j; i++)
      [[value objectAtIndex:i] writeHTML:stream];
    CLPrintf(stream, @"</SELECT>");
    break;

  case CLFileFieldType:
    CLPrintf(stream, @"<%@ TYPE=%@", title, CLFieldTypes[type]);
    [self writeAttributes:stream ignore:nil];
    CLPrintf(stream, @" />");
    break;
  }

  return;
}

@end
