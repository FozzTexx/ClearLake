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

#import "CLFQTableName.h"
#import "CLString.h"

@implementation CLFQTableName

+(id) table:(CLString *) tName inDatabase:(CLString *) dbName
{
  return [[[self alloc] initFromTable:tName inDatabase:dbName] autorelease];
}

-(id) initFromTable:(CLString *) tName inDatabase:(CLString *) dbName
{
  [super init];
  databaseID = [dbName copy];
  tableName = [tName copy];
  fqTableName = [[CLString alloc] initWithFormat:@"%@.%@", databaseID, tableName];
  return self;
}

-(void) dealloc
{
  [databaseID release];
  [tableName release];
  [fqTableName release];
  [super dealloc];
  return;
}

-(CLString *) databaseID
{
  return databaseID;
}

-(CLString *) tableName
{
  return tableName;
}

-(CLUInteger) hash
{
  return [fqTableName hash];
}

-(BOOL) isEqual:(id) anObject
{
  return [fqTableName isEqual:anObject];
}

-(id) copy
{
  return [self retain];
}

@end
