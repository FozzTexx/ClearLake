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
#import "CLStream.h"

#define FQ_SEPARATOR	@":"

@implementation CLFQTableName

+(BOOL) isFullyQualifiedTableName:(CLString *) aString
{
  CLRange aRange;


  aRange = [aString rangeOfString:FQ_SEPARATOR options:CLBackwardsSearch];
  return aRange.length;
}

+(id) tableName:(CLString *) tName inDatabase:(CLString *) dbName
{
  return [[[self alloc] initFromTableName:tName inDatabase:dbName] autorelease];
}

+(id) fullyQualifiedTableName:(CLString *) fqTable
{
  return [[[self alloc] initFromFullyQualifiedTableName:fqTable] autorelease];
}

-(id) initFromTableName:(CLString *) tName inDatabase:(CLString *) dbName
{
  [super init];
  databaseID = [dbName copy];
  tableName = [tName copy];
  fqTableName = [[CLString alloc] initWithFormat:@"%@%@%@",
				  databaseID, FQ_SEPARATOR, tableName];
  return self;
}

-(id) initFromFullyQualifiedTableName:(CLString *) fqTable
{
  CLRange aRange;


  aRange = [fqTable rangeOfString:FQ_SEPARATOR options:CLBackwardsSearch];
  if (!aRange.length) {
    // Legacy FQ table names used '.' instead of ':'
    aRange = [fqTable rangeOfString:@"." options:CLBackwardsSearch];
    if (!aRange.length)
      [self error:@"Invalid fully qualified table"];
  }

  return [self initFromTableName:[fqTable substringFromIndex:CLMaxRange(aRange)]
		      inDatabase:[fqTable substringToIndex:aRange.location]];
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

-(id) read:(CLStream *) stream
{
  CLString *fqEncoded;


  self = [super read:stream];
  [stream readTypes:@"@", &fqEncoded];
  return [self initFromFullyQualifiedTableName:fqEncoded];
}

-(void) write:(CLStream *) stream
{
  [super write:stream];
  [stream writeTypes:@"@", &fqTableName];
  return;
}

-(CLString *) description
{
  return fqTableName;
}

@end
