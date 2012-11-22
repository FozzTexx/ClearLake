// -*- objc -*-
/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * $Id$
 */

#import <ClearLake/CLObject.h>

@class CLNotification, CLString, CLDictionary, CLMutableDictionary;

@interface CLNotificationCenter:CLObject
{
  CLMutableDictionary *names, *objects;
}

+(id) defaultCenter;

-(void) addObserver:(id) notificationObserver selector:(SEL) notificationSelector
	       name:(CLString *) notificationName object:(id) notificationSender;
-(void) postNotification:(CLNotification *) notification;
-(void) postNotificationName:(CLString *) notificationName object:(id) notificationSender;
-(void) postNotificationName:(CLString *) notificationName object:(id) notificationSender
		    userInfo:(CLDictionary *) userInfo;
-(void) removeObserver:(id) notificationObserver;
-(void) removeObserver:(id) notificationObserver name:(CLString *) notificationName
		object:(id) notificationSender;

@end
