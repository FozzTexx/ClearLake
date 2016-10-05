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

#ifndef _CLINPUT_H
#define _CLINPUT_H

#import <ClearLake/CLBlock.h>

@class CLInfoMessage, CLForm;

typedef enum CLInputType {
  CLTextInputType =	1,
  CLRadioInputType,
  CLSubmitInputType,
  CLResetInputType,
  CLPasswordInputType,
  CLHiddenInputType,
  CLCheckboxInputType,
  CLImageInputType,
  CLFileInputType,
  CLButtonInputType,
  CLTextareaInputType,
} CLInputType;

@interface CLInput:CLElement <CLCopying>
{
  id value;
  CLInputType type;
  BOOL ignoreBinding;
  id originalValue;
  CLInfoMessage *message;
}

+(CLInput *) hiddenFieldNamed:(CLString *) aString withValue:(id) aValue;
+(CLInput *) checkboxNamed:(CLString *) aString withValue:(id) aValue;
+(CLInput *) textFieldNamed:(CLString *) aString withValue:(id) aValue;

-(id) init;
-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage; /* This is the designated initializer */
-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage;
-(id) initWithTitle:(CLString *) aTitle;
-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols;
-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols rows:(int) aRows
	      value:(id) aValue type:(CLInputType) aType onPage:(CLPage *) aPage;
-(void) dealloc;

-(id) value;
-(void) setValue:(id) aValue;
-(BOOL) isChecked;
-(BOOL) isDisabled;
-(void) setChecked:(BOOL) isChecked;
-(void) setDisabled:(BOOL) disabled;
-(id) originalValue;
-(CLInputType) type;
-(void) setType:(CLInputType) aType;
-(void) setErrorString:(CLString *) aString;
-(void) setErrorString:(CLString *) errorString ignoreBinding:(BOOL) flag;
-(void) setInfoString:(CLString *) aString;
-(void) setIgnoreBinding:(BOOL) flag;
-(CLInfoMessage *) message;
-(void) setMessage:(CLInfoMessage *) aMessage;
-(CLForm *) form;

-(void) writeHTML:(CLStream *) stream;

@end

@protocol CLInputDelegate
-(BOOL) willSetValue:(id) aValue for:(CLInput *) aField;
@end

#endif /* _CLINPUT_H */
