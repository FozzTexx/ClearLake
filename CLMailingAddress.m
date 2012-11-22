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

#import "CLMailingAddress.h"

@implementation CLMailingAddress

-(id) init
{
  [super init];
  name = company = address1 = address2 = city = state = zip = nil;
  return self;
}

-(void) dealloc
{
  [name release];
  [company release];
  [address1 release];
  [address2 release];
  [city release];
  [state release];
  [zip release];
  [super dealloc];
  return;
}

-(id) copy
{
  CLMailingAddress *aCopy;


  aCopy = [super copy];
  aCopy->name = [name copy];
  aCopy->company = [company copy];
  aCopy->address1 = [address1 copy];
  aCopy->address2 = [address2 copy];
  aCopy->city = [city copy];
  aCopy->state = [state copy];
  aCopy->zip = [zip copy];
  return aCopy;
}

-(CLString *) name
{
  return name;
}

-(CLString *) company
{
  return company;
}

-(CLString *) address1
{
  return address1;
}

-(CLString *) address2
{
  return address2;
}

-(CLString *) city
{
  return city;
}

-(CLString *) state
{
  return state;
}

-(CLString *) zip
{
  return zip;
}

-(CLString *) phone
{
  return phone;
}

-(void) setName:(CLString *) aString
{
  [name autorelease];
  name = [aString retain];
  return;
}

-(void) setCompany:(CLString *) aString
{
  [company autorelease];
  company = [aString retain];
  return;
}

-(void) setAddress1:(CLString *) aString
{
  [address1 autorelease];
  address1 = [aString retain];
  return;
}

-(void) setAddress2:(CLString *) aString
{
  [address2 release];
  address2 = [aString retain];
  return;
}

-(void) setCity:(CLString *) aString
{
  [city autorelease];
  city = [aString retain];
  return;
}

-(void) setState:(CLString *) aString
{
  [state autorelease];
  state = [aString retain];
  return;
}

-(void) setZip:(CLString *) aString
{
  [zip autorelease];
  zip = [aString retain];
  return;
}

-(void) setPhone:(CLString *) aString
{
  [phone autorelease];
  phone = [aString retain];
  return;
}

@end
