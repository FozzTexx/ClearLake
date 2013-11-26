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

#ifndef _CLCONTROL_H
#define _CLCONTROL_H

#import <ClearLake/CLBlock.h>

#include <time.h>

@class CLMutableArray, CLString, CLMutableDictionary, CLArray, CLData, CLDictionary,
  CLCalendarDate;

extern CLString *CLTargetFrame;

@interface CLControl:CLBlock <CLCopying>
{
  id target;
  SEL action;
  BOOL writeContents;
  CLString *baseURL, *anchor;
  CLMutableDictionary *localQuery;
}

+(CLString *) rewriteURL:(CLString *) aURL;

-(id) init;
-(id) initFromString:(CLString *) aString onPage:(CLPage *) aPage; /* This is the designated initializer */
-(id) initFromElement:(CLElement *) anElement onPage:(CLPage *) aPage;
-(void) dealloc;

-(SEL) action;
-(id) target;
-(void) setAction:(SEL) anAction;
-(void) setTarget:(id) aTarget;
-(void) setEnabled:(BOOL) flag;
-(void) setWriteContents:(BOOL) flag;
-(void) setAnchor:(CLString *) aString;
-(void) performAction;
-(BOOL) isEnabled;
-(void) setBaseURL:(CLString *) aString;
-(CLString *) baseURL;
-(CLMutableDictionary *) localQuery;
-(BOOL) writeContents;
-(CLString *) generateURL;

-(void) readURL:(CLStream *) stream;
-(void) writeURL:(CLStream *) stream;
-(void) writeHTML:(CLStream *) stream;

@end

@protocol CLControlDelegate
-(BOOL) controlShouldPerform:(CLControl *) aControl;
-(void) control:(CLControl *) aControl readPersistentData:(CLStream *) stream;
-(void) control:(CLControl *) aControl writePersistentData:(CLStream *) stream;

-(CLString *) delegateEncodeSimpleURL:(id) aControl
			    localQuery:(CLMutableDictionary *) localQuery;
-(BOOL) delegateDecodeSimpleURL:(CLString *) aString;
@end

extern CLMutableDictionary *CLControlState;

extern void CLWriteURLForGet(CLStream *stream, id object,
			     CLData *aData, CLDictionary *localQuery,
			     BOOL withoutQuery);
extern void CLWriteURL(CLStream *stream, id object,
		       CLData *aData, CLDictionary *localQuery);

#endif /* _CLCONTROL_H */
