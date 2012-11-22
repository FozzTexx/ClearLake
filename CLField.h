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

#import <ClearLake/CLBlock.h>

typedef enum CLFieldType {
  CLTextFieldType =	1,
  CLRadioFieldType,
  CLSubmitFieldType,
  CLResetFieldType,
  CLTextareaFieldType,
  CLPasswordFieldType,
  CLSelectFieldType,
  CLHiddenFieldType,
  CLCheckboxFieldType,
  CLImageFieldType,
  CLFileFieldType,
  CLButtonFieldType,
} CLFieldType;

@interface CLField:CLBlock <CLCopying>
{
  CLFieldType type;
  BOOL ignoreBinding;
  id originalValue;
}

+(CLField *) hiddenFieldNamed:(CLString *) aString withValue:(id) aValue;
+(CLField *) checkboxNamed:(CLString *) aString withValue:(id) aValue;
+(CLField *) textFieldNamed:(CLString *) aString withValue:(id) aValue;

-(id) init;
-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage; /* This is the designated initializer */
-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage;
-(id) initWithTitle:(CLString *) aTitle;
-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols;
-(id) initWithTitle:(CLString *) aTitle cols:(int) aCols rows:(int) aRows
	      value:(id) aValue type:(CLFieldType) aType onPage:(CLPage *) aPage;

-(void) setValue:(id) aValue;
-(BOOL) isChecked;
-(BOOL) isEnabled;
-(void) setChecked:(BOOL) isChecked;
-(void) setEnabled:(BOOL) enabled;
-(void) selectOptionWithValue:(id) aValue;
-(void) selectOptionWithName:(CLString *) aString;
-(int) numOptions;
-(void) addOption:(CLString *) aString withValue:(id) aValue;
-(void) removeAllOptions;
-(id) originalValue;
-(CLFieldType) type;
-(void) setType:(CLFieldType) aType;
-(void) setErrorString:(CLString *) aString;
-(void) setErrorString:(CLString *) errorString ignoreBinding:(BOOL) flag;
-(void) setInfoString:(CLString *) aString;
-(void) setIgnoreBinding:(BOOL) flag;

-(void) writeHTML:(CLStream *) stream;
-(void) writeHTML:(CLStream *) stream parentEnabled:(BOOL) parentEnabled;

@end

@protocol CLFieldDelegate
-(BOOL) willSetValue:(id) aValue for:(CLField *) aField;
@end
