// -*- objc -*-

/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * $Id$
 */

#import <ClearLake/CLObject.h>

@class CLString, CLDictionary;

@interface CLNotification:CLObject
{
  CLString *name;
  id object;
  CLDictionary *userInfo;
}

+(id) notificationWithName:(CLString *) aName object:(id) anObject;
+(id) notificationWithName:(CLString *) aName object:(id) anObject
		  userInfo:(CLDictionary *) userInfo;

-(id) initFromName:(CLString *) aName object:(id) anObject
	  userInfo:(CLDictionary *) userInfo;
-(void) dealloc;

-(CLString *) name;
-(id) object;
-(CDictionary *) userInfo;

@end
