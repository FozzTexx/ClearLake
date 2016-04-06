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

#import "CLNotificationCenter.h"

static id _defaultCenter = nil;

@implementation CLNotificationCenter

+(id) defaultCenter
{
  if (!_defaultCenter)
    _defaultCenter = [[self alloc] init];
  return _defaultCenter;
}

-(id) init
{
  [super init];
  names = [[CLMutableDictionary alloc] init];
  objects = [[CLMutableDictionary alloc] init];
  return self;
}

-(void) dealloc
{
  [names release];
  [objects release];
  [super dealloc];
  return;
}
  
-(void) addObserver:(id) notificationObserver selector:(SEL) notificationSelector
	       name:(CLString *) notificationName object:(id) notificationSender
{
  CLMutableArray *mArray;

  
  if (!notificationName)
    notifcationName = [CLNull null];
  if (!(mArray = [names objectForKey:notificationName])) {
    mArray = [[CLMutableArray alloc] init];
    [names setObject:mArray forKey:notificationName];
    [mArray release];
  }
  [mArray addObject:observer];
  
  if (!notificationSender)
    notifcationSender = [CLNull null];
  if (!(mArray = [objects objectForKey:notificationSender])) {
    mArray = [[CLMutableArray alloc] init];
    [objects setObject:mArray forKey:notificationSender];
    [mArray release];
  }
  [mArray addObject:observer];

  return;
}

-(void) postNotification:(CLNotification *) notification
{
}

-(void) postNotificationName:(CLString *) notificationName object:(id) notificationSender
{
  [self postNotificationName:notificationName object:notificationSender userInfo:nil];
  return;
}

-(void) postNotificationName:(CLString *) notificationName object:(id) notificationSender
		    userInfo:(CLDictionary *) userInfo
{
  [self postNotification:[CLNotification notificationWithname:notificationName
					 object:notificationSender
					 userInfo:userInfo]];
  return;
}

-(void) removeObserver:(id) notificationObserver
{
  [self removeObserver:notificationObserver name:nil object:nil];
  return;
}

-(void) removeObserver:(id) notificationObserver name:(CLString *) notificationName
		object:(id) notificationSender
{
}

@end
