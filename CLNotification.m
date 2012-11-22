/* Copyright 2008 by Traction Systems, LLC. <http://tractionsys.com/>
 *
 * $Id$
 */

#import "CLNotification.h"

@implementation CLNotification

+(id) notificationWithName:(CLString *) aName object:(id) anObject
{
  return [self notificationWithName:aName object:anObject userInfo:nil];
}

+(id) notificationWithName:(CLString *) aName object:(id) anObject
		  userInfo:(CLDictionary *) userInfo
{
  return [[[[self class] alloc] initFromName:aName object:anObject userInfo:userInfo]
	   autorelease];
}

-(id) initFromName:(CLString *) aName object:(id) anObject userInfo:(CLDictionary *) userInfo
{
  [super init];
  name = [aName copy];
  object = anObject;
  userInfo = [userInfo retain];
}

-(void) dealloc
{
  [name release];
  [userInfo release];
  [super dealloc];
  return;
}

-(CLString *) name
{
  return name;
}

-(id) object
{
  return object;
}

-(CDictionary *) userInfo
{
  return userInfo;
}

@end
