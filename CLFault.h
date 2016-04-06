/* Copyright 2012-2016 by
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

#ifndef _CLFAULT_H
#define _CLFAULT_H

#import <ClearLake/CLPrimitiveObject.h>

@class CLDictionary, CLRecordDefinition, CLMethodSignature, CLMutableArray;

typedef struct CLFaultData {
  Class original;
  union {
    struct {
      CLDictionary *primaryKey;
      CLRecordDefinition *recordDef;
    } faultData;
    struct {
      CLString *qualifier;
      CLString *table;
      CLMutableArray *objects;
    } arrayData;
  } info;
} CLFaultData;

/* Yes, this really does not inherit from CLObject. It is gross and
   icky but it was the only way I could think of to make sure it
   faults when it should. */
@interface CLFault:CLPrimitiveObject
-(BOOL) isFault;
-(void) fault;
@end

@protocol CLFaulting
-(void) didFault;
@end

extern id CLNewFault(id info, CLRecordDefinition *recordDef);
extern void CLBecomeFault(id anObject, id info, CLRecordDefinition *recordDef);

#endif /* _CLFAULT_H */
