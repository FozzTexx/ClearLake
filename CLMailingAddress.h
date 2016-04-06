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

#ifndef _CLMAILINGADDRESS_H
#define _CLMAILINGADDRESS_H

#import <ClearLake/CLObject.h>

@interface CLMailingAddress:CLObject <CLCopying>
{
  CLString *name;
  CLString *company;
  CLString *address1, *address2;
  CLString *city, *state, *zip;
  CLString *phone;
}

-(id) init;
-(void) dealloc;

-(CLString *) name;
-(CLString *) company;
-(CLString *) address1;
-(CLString *) address2;
-(CLString *) city;
-(CLString *) state;
-(CLString *) zip;
-(CLString *) phone;

-(void) setName:(CLString *) aString;
-(void) setCompany:(CLString *) aString;
-(void) setAddress1:(CLString *) aString;
-(void) setAddress2:(CLString *) aString;
-(void) setCity:(CLString *) aString;
-(void) setState:(CLString *) aString;
-(void) setZip:(CLString *) aString;
-(void) setPhone:(CLString *) aString;

@end

#endif /* _CLMAILINGADDRESS_H */
