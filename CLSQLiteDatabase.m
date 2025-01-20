/* Copyright 2024 by
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

#import "CLSQLiteDatabase.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"
#import "CLNull.h"

static int CLSQLiteRowData(void *data, int argc, char **argv, char **azColName)
{
  int idx;
  CLMutableDictionary *mDict;
  CLMutableArray *rows, *mArray;
#if DEBUG_LEAK || DEBUG_RETAIN
  id self = nil;
#endif


  mDict = data;

  if (![mDict objectForKey:@"columns"]) {
    mArray = [[CLMutableArray alloc] init];
    for (idx = 0; idx < argc; idx++)
      [mArray addObject:[CLString stringWithUTF8String:azColName[idx]]];
    [mDict setObject:mArray forKey:@"columns"];
    [mArray release];
  }

  rows = [mDict objectForKey:@"rows"];
  if (!rows) {
    rows = [[CLMutableArray alloc] init];
    [mDict setObject:rows forKey:@"rows"];
    [rows release];
  }

  mArray = [[CLMutableArray alloc] init];
  for (idx = 0; idx < argc; idx++)
    [mArray addObject:argv[idx] ? [CLString stringWithUTF8String:argv[idx]] : CLNullObject];
  [rows addObject:mArray];
  [mArray release];

  return 0;
}

@implementation CLSQLiteDatabase

-(id) init
{
  return [self initWithDatabase:nil user:nil password:nil host:nil];
}

-(id) initWithDatabase:(CLString *) aFilename user:(CLString *) user
              password:(CLString *) password host:(CLString *) aHost
{
  int rc;


  [super init];

  conn = NULL;
  rc = sqlite3_open([aFilename UTF8String], &conn);
  if (rc != SQLITE_OK) {
    fprintf(stderr, "Failed to open database: %s\n", [aFilename UTF8String]);
    [self release];
    return nil;
  }

  sqlite3_exec(conn, "PRAGMA journal_mode=WAL;", 0, 0, 0);

  return self;
}

-(void) dealloc
{
  sqlite3_close(conn);
  [super dealloc];
  return;
}

-(id) runQuery:(CLString *) aQuery
{
  int rc;
  CLMutableDictionary *mDict;
  char *errmsg = NULL;


  mDict = [[CLMutableDictionary alloc] init];
  rc = sqlite3_exec(conn, [aQuery UTF8String], CLSQLiteRowData, (void *) mDict, &errmsg);
  if (rc != SQLITE_OK)
    [mDict setObject:[CLString stringWithUTF8String:errmsg] forKey:@"errors"];
  if (errmsg)
    sqlite3_free(errmsg);
  if (![mDict count]) {
    [mDict release];
    mDict = nil;
  }

  return [mDict autorelease];
}

-(void) beginTransaction
{
  id errors;


  errors = [self runQuery:@"begin transaction"];
  if (errors)
    [self error:@"Failed to begin %@", errors];
  return;
}

-(void) commitTransaction
{
  id errors;


  errors = [self runQuery:@"commit"];
  if (errors)
    [self error:@"Failed to commit %@", errors];
  return;
}

-(void) rollbackTransaction
{
  [self runQuery:@"rollback"];
  return;
}

@end
