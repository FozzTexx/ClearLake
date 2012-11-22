/* Copyright 2009 by Traction Systems, LLC. <http://tractionsys.com/>
 *
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

#ifndef _CLVALUE_H
#define _CLVALUE_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLRange.h>

@interface CLValue:CLObject
{
  union {
    CLRange range;
  } value;
  int type;
}

+(CLValue *) valueWithRange:(CLRange) range;

-(CLRange) rangeValue;

@end

#endif /* _CLVALUE_H */
