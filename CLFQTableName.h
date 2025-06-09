/* Copyright 2025 by
 *   Chris Osborn <fozztexx@fozztexx.com>
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

#ifndef _CLFQTABLENAME_H
#define _CLFQTABLENAME_H

#import <ClearLake/CLObject.h>

@interface CLFQTableName:CLObject <CLArchiving, CLCopying>
{
  CLString *databaseID;
  CLString *tableName;
  CLString *fqTableName;
}

+(BOOL) isFullyQualifiedTableName:(CLString *) aString;
+(id) table:(CLString *) tName inDatabase:(CLString *) dbName;
-(id) initFromTable:(CLString *) tName inDatabase:(CLString *) dbName;
-(id) initFromFullyQualifiedTableName:(CLString *) fqTable;
-(void) dealloc;

-(CLString *) databaseID;
-(CLString *) tableName;

-(CLUInteger) hash;
-(BOOL) isEqual:(id) anObject;

@end

#endif /* _CLFQTABLENAME_H */
