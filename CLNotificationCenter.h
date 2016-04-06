// -*- objc -*-
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
