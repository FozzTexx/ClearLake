/* Copyright 2026 by
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

#import "CLPostgresDatabase.h"
#import "CLMutableArray.h"
#import "CLMutableDictionary.h"
#import "CLAutoreleasePool.h"
#import "CLNull.h"
#import "CLData.h"

#include <stdlib.h>
#include <string.h>

#define QUERY_TIME 0

#if QUERY_TIME
#include <sys/time.h>
#endif

int postgresCount = 0;

@implementation CLPostgresDatabase

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
    /* Build a libpq connection string from the individual parameters */
    const char *keys[]   = { "host", "dbname", "user", "password", NULL };
    const char *values[] = {
      [aHost UTF8String],
      [aDatabase UTF8String],
      [user UTF8String],
      [password UTF8String],
      NULL
    };

    conn = PQconnectdbParams(keys, values, 0);

    if (PQstatus(conn) != CONNECTION_OK) {
      PQfinish(conn);
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
    PQfinish(conn);
  [super dealloc];
  return;
}

-(id) runQuery:(CLString *) aQuery
{
  CLMutableArray *mArray = nil;
  CLMutableDictionary *mDict = nil;
  PGresult *res;
  ExecStatusType status;
  int nf, nr, i, j;
  CLAutoreleasePool *pool;
#if QUERY_TIME
  struct timeval start, end;
  static int total_queries = 0;
  static double elapsed, total_time = 0.0;
#endif

#if QUERY_TIME
  gettimeofday(&start, NULL);
#endif

  pool = [[CLAutoreleasePool alloc] init];

  res = PQexec(conn, [aQuery UTF8String]);
  status = PQresultStatus(res);

  if (status == PGRES_TUPLES_OK) {
    /* --- Build column metadata --- */
    nf = PQnfields(res);
    mArray = [[CLMutableArray alloc] init];
    for (i = 0; i < nf; i++) {
      [mArray addObject:
                 [CLDictionary dictionaryWithObjectsAndKeys:
                                 [CLString stringWithBytes:PQfname(res, i)
                                           length:strlen(PQfname(res, i))
                                           encoding:[self encoding]], @"name",
                               nil]];
    }
    mDict = [[CLMutableDictionary alloc] init];
    [mDict setObject:mArray forKey:@"columns"];
    [mArray release];
    mArray = nil;

    /* --- Build row data --- */
    nr = PQntuples(res);
    if (nr > 0) {
      mArray = [[CLMutableArray alloc] init];
      for (j = 0; j < nr; j++) {
        CLMutableArray *aRow = [[CLMutableArray alloc] init];
        postgresCount++;
        for (i = 0; i < nf; i++) {
          if (PQgetisnull(res, j, i)) {
            [aRow addObject:CLNullObject];
          }
          else {
            const char *val = PQgetvalue(res, j, i);
            int len = PQgetlength(res, j, i);
            [aRow addObject:[CLString stringWithBytes:val
                                      length:len
                                      encoding:[self encoding]]];
          }
        }
        [mArray addObject:aRow];
        [aRow release];
      }
      [mDict setObject:mArray forKey:@"rows"];
      [mArray release];
      mArray = nil;
    }
  }
  else if (status == PGRES_COMMAND_OK) {
    /* Non-SELECT query (INSERT, UPDATE, DELETE, etc.) succeeded — return nil */
  }
  else {
    /* Query failed — capture the error message */
    if (!mDict)
      mDict = [[CLMutableDictionary alloc] init];
    [mDict setObject:[CLString stringWithUTF8String:PQresultErrorMessage(res)]
           forKey:@"errors"];
  }

  PQclear(res);
  [pool release];

#if QUERY_TIME
  gettimeofday(&end, NULL);
  i = end.tv_sec - start.tv_sec;
  i *= 1000000;
  i += end.tv_usec - start.tv_usec;
  total_queries++;
  elapsed = i / 1000000.0;
  total_time += elapsed;
  fprintf(stderr, "%i %.4f + %.4f %i records %s\n", total_queries, total_time, elapsed,
          [[mDict objectForKey:@"rows"] count], [aQuery UTF8String]);
#endif

  return [mDict autorelease];
}

-(void) beginTransaction
{
  id result;

  result = [self runQuery:@"BEGIN"];
  if (result && [result objectForKey:@"errors"])
    [self error:@"Failed to begin %@", result];
  return;
}

-(void) commitTransaction
{
  id result;

  result = [self runQuery:@"COMMIT"];
  if (result && [result objectForKey:@"errors"])
    [self error:@"Failed to commit %@", result];
  return;
}

-(void) rollbackTransaction
{
  [self runQuery:@"ROLLBACK"];
  return;
}

-(void) setEncoding:(CLStringEncoding) aValue
{
  const char *enc = NULL;

  [super setEncoding:aValue];

  switch (encoding) {
  case CLISOLatin1StringEncoding:
    enc = "LATIN1";
    break;
  case CLUTF8StringEncoding:
  default:
    enc = "UTF8";
    break;
  }

  if (enc) {
    /* PQsetClientEncoding returns 0 on success, -1 on failure */
    PQsetClientEncoding(conn, enc);
  }

  return;
}

@end
