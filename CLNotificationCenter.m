/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * $Id$
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
