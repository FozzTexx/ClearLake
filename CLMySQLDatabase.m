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

#import "CLMySQLDatabase.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"
#import "CLAutoreleasePool.h"
#import "CLNull.h"
#import "CLData.h"

#include <stdlib.h>
#include <string.h>

#define QUERY_TIME 0

int mysqlCount = 0;

@implementation CLMySQLDatabase

+(CLString *) defangString:(CLString *) aString escape:(int *) escape
{
  aString = [aString stringByReplacingOccurrencesOfString:@"\\" withString:@"\\\\"];
  return [super defangString:aString escape:escape];
}

-(id) init
{
  return [self initWithDatabase:nil user:nil password:nil host:nil];
}

-(id) initWithDatabase:(CLString *) aDatabase user:(CLString *) user
	      password:(CLString *) password host:(CLString *) aHost
{
  [super init];

  conn = NULL;

  if (aDatabase && user && password && aHost) {
    conn = mysql_init(NULL);
    if (!mysql_real_connect(conn, [aHost UTF8String], [user UTF8String],
			    [password UTF8String], [aDatabase UTF8String], 0, NULL, 0)) {
      mysql_close(conn);
      conn = NULL;
    }
  }

  if (!conn) {
    [self release];
    return nil;
  }

  return self;
}

-(void) dealloc
{
  if (conn)
    mysql_close(conn);
  [super dealloc];
  return;
}

-(id) runQuery:(CLString *) aQuery
{
  CLMutableArray *mArray = nil;
  CLMutableDictionary *mDict = nil;
  CLData *aData;
  MYSQL_RES *res;
  MYSQL_ROW values;
  MYSQL_FIELD *field;
  int nf, i, err;
  CLAutoreleasePool *pool;
#if QUERY_TIME
  struct timeval start, end;
  static int total_queries = 0;
#endif
  

#if QUERY_TIME
  gettimeofday(&start, NULL);
#endif
  
  pool = [[CLAutoreleasePool alloc] init];
  aData = [aQuery dataUsingEncoding:[self encoding]];
#if 0
  fprintf(stderr, "%s\n", buf);
#endif
  if (!(err = mysql_real_query(conn, [aData bytes], [aData length])) &&
      (res = mysql_store_result(conn))) {
    nf = mysql_num_fields(res);
    mArray = nil;

    while ((field = mysql_fetch_field(res))) {
      if (!mArray) {
	mArray = [[CLMutableArray alloc] init];
      }
      [mArray addObject:
		 [CLDictionary dictionaryWithObjectsAndKeys:
				 [CLString stringWithBytes:field->name
					   length:strlen(field->name)
					   encoding:[self encoding]], @"name",
			       nil]];
    }

    if (mArray) {
      if (!mDict) {
	mDict = [[CLMutableDictionary alloc] init];
      }
      [mDict setObject:mArray forKey:@"columns"];
      [mArray release];
      mArray = nil;
    }

    while ((values = mysql_fetch_row(res))) {
      CLMutableArray *aRow;
      

      mysqlCount++;
      aRow = [[CLMutableArray alloc] init];
      for (i = 0; i < nf; i++) {
	/* FIXME - use mysql_fetch_lengths, not strlen() */
	if (values[i]) {
	  [aRow addObject:[CLString stringWithBytes:values[i]
				    length:strlen(values[i]) encoding:[self encoding]]];
	}
	else
	  [aRow addObject:CLNullObject];
      }

      if (!mArray) {
	mArray = [[CLMutableArray alloc] init];
      }
      [mArray addObject:aRow];
      [aRow release];
    }

    if (mArray) {
      if (!mDict) {
	mDict = [[CLMutableDictionary alloc] init];
      }
      [mDict setObject:mArray forKey:@"rows"];
      [mArray release];
      mArray = nil;
    }
    
    mysql_free_result(res);
  }
  else if (err) {
    if (!mDict) {
      mDict = [[CLMutableDictionary alloc] init];
    }
    [mDict setObject:[CLString stringWithUTF8String:mysql_error(conn)]
	   forKey:@"errors"];
  }
  
  [pool release];

#if QUERY_TIME
  gettimeofday(&end, NULL);
  i = end.tv_sec - start.tv_sec;
  i *= 1000000;
  i += end.tv_usec - start.tv_usec;
  total_queries++;
  fprintf(stderr, "%i %.4f %i records %s\n", total_queries, i / 1000000.0,
	  [[mDict objectForKey:@"rows"] count], [aQuery UTF8String]);
#endif
  
  return [mDict autorelease];
}

-(void) beginTransaction
{
  id errors;

  
  errors = [self runQuery:@"set autocommit = 0"];
  if (errors)
    [self error:@"Failed to begin %@", errors];
  errors = [self runQuery:@"start transaction"];
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
  else
    [self runQuery:@"set autocommit = 1"];
  return;
}

-(void) rollbackTransaction
{
  [self runQuery:@"rollback"];
  [self runQuery:@"set autocommit = 1"];
  return;
}

@end
