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

#import <ClearLake/CLControl.h>

@class CLInput;

@interface CLForm:CLControl
{
  BOOL wasError;
  CLMutableDictionary *errors;
}

-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage; /* This is the designated initializer */
-(void) dealloc;

-(id) valueOfFieldNamed:(CLString *) aField;
-(void) setValue:(id) aValue forFieldNamed:(CLString *) aField;
-(CLInput *) fieldNamed:(CLString *) field;
-(CLInput *) fieldNamed:(CLString *) field withValue:(id) aValue;
-(CLArray *) fieldsNamed:(CLString *) field;
-(CLArray *) fieldNames;
-(CLArray *) allFields;
-(BOOL) removeFieldNamed:(CLString *) field;
-(BOOL) doVaction;
-(void) copyValuesFrom:(id) aForm;
-(CLString *) query;
-(void) setQuery:(const char *) str;
-(void) selectRadioNamed:(CLString *) aName withValue:(id) aValue;
-(CLForm *) pageForm;
-(CLControl *) setBindings;
-(BOOL) wasError;
-(CLDictionary *) errors;
-(void) readData;
-(void) restoreObject:(id) anObject;
-(CLDictionary *) dictionary;

-(void) writeHTML:(CLStream *) stream;

@end

@protocol CLFormDelegate
-(BOOL) formShouldUseAutomaticPropertyList:(CLForm *) aForm;
-(void) formDidRestoreObject:(CLForm *) aForm fromDictionary:(CLDictionary *) aDict;
@end

@interface CLForm (LinkerIsBorked)
+(void) linkerIsBorked;
@end
