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

#import "CLSybaseDatabase.h"
#import "CLMutableDictionary.h"
#import "CLMutableArray.h"
#import "CLMutableString.h"
#import "CLAutoreleasePool.h"
#import "CLData.h"
#import "CLNull.h"
#import "CLHashTable.h"

#include <stdlib.h>

CLString *CLSybaseErrorsFor(CS_CONTEXT *context);
CS_RETCODE CLSybaseClientError(CS_CONTEXT *context, CS_CONNECTION *connection,
			       CS_CLIENTMSG *errmsg);
CS_RETCODE CLSybaseServerError(CS_CONTEXT *context, CS_CONNECTION *connection,
			       CS_SERVERMSG *srvmsg);

@implementation CLSybaseDatabase

-(id) init
{
  return [self initWithDatabase:nil user:nil password:nil host:nil];
}

-(id) initWithDatabase:(CLString *) aDatabase user:(CLString *) user
	      password:(CLString *) password host:(CLString *) aHost
{
  CS_RETCODE retcode;
  CS_INT netio_type = CS_SYNC_IO;

  
  [super init];
  
  context = NULL;
  conn = NULL;

  if (aDatabase && user && password) {
    if (cs_ctx_alloc(CS_VERSION_100, &context) == CS_SUCCEED) {
      if (ct_init(context, CS_VERSION_100) != CS_SUCCEED) {
	cs_ctx_drop(context);
	context = NULL;
      }
      else {
	retcode = ct_callback(context, NULL, CS_SET, CS_CLIENTMSG_CB,
			      (CS_VOID *) CLSybaseClientError);

	if (retcode == CS_SUCCEED)
	  retcode = ct_callback(context, NULL, CS_SET, CS_SERVERMSG_CB,
				(CS_VOID *) CLSybaseServerError);

	if (retcode == CS_SUCCEED)
	  retcode = ct_config(context, CS_SET, CS_NETIO, &netio_type, 
			      CS_UNUSED, NULL);

	if (retcode != CS_SUCCEED) {
	  ct_exit(context, CS_FORCE_EXIT);
	  cs_ctx_drop(context);
	  context = NULL;
	}
	else {
	  retcode = ct_con_alloc(context, &conn);
	  if (retcode == CS_SUCCEED)
	    retcode = ct_con_props(conn, CS_SET, CS_USERNAME, 
				   (char *) [user UTF8String], CS_NULLTERM, NULL);
	  if (retcode == CS_SUCCEED)
	    retcode = ct_con_props(conn, CS_SET, CS_PASSWORD, 
				   (char *) [password UTF8String], CS_NULLTERM, NULL);
	  if (retcode == CS_SUCCEED)
	    retcode = ct_connect(conn, (char *) [aHost UTF8String], CS_NULLTERM);
	  if (retcode != CS_SUCCEED) {
	    ct_con_drop(conn);
	    conn = NULL;
	    ct_exit(context, CS_FORCE_EXIT);
	    cs_ctx_drop(context);
	    context = NULL;
	  }
	  else
	    [self runQuery:[CLString stringWithFormat:@"use %@", aDatabase]];
	}
      }
    }
  }

  if (!context)
    fprintf(stderr, "Error connecting to Sybase database\n");

  return self;
}

-(void) dealloc
{
  ct_close(conn, CS_UNUSED);
  ct_con_drop(conn);
  ct_exit(context, CS_UNUSED);
  cs_ctx_drop(context);
  [super dealloc];
  return;
}

-(int) nextIDForTable:(CLString *) table
{
  int rid = 0;
  CLDictionary *results;
  CLArray *anArray;


  results = [self runQuery:[CLString stringWithFormat:@"eo_pk_for_table %@", table]];
  anArray = [results objectForKey:@"rows"];
  if ([anArray count])
    rid = [[[anArray objectAtIndex:0] objectAtIndex:0] intValue];

  return rid;
}

-(CLString *) sybaseTypeString:(int) aType
{
  switch (aType) {
  case CS_CHAR_TYPE:
    return @"char";
  case CS_VARCHAR_TYPE:
    return @"varchar";
  case CS_TEXT_TYPE:
    return @"text";
  case CS_IMAGE_TYPE:
    return @"image";
  case CS_BINARY_TYPE:
    return @"binary";
  case CS_VARBINARY_TYPE:
    return @"varbinary";
  case CS_BIT_TYPE:
    return @"bit";
  case CS_TINYINT_TYPE:
    return @"tinyint";
  case CS_SMALLINT_TYPE:
    return @"smallint";
  case CS_INT_TYPE:
    return @"int";
  case CS_REAL_TYPE:
    return @"real";
  case CS_FLOAT_TYPE:
    return @"float";
  case CS_MONEY_TYPE:
    return @"money";
  case CS_MONEY4_TYPE:
    return @"money4";
  case CS_DATETIME_TYPE:
    return @"datetime";
  case CS_DATETIME4_TYPE:
    return @"datetime4";
  case CS_NUMERIC_TYPE:
    return @"numeric";
  case CS_DECIMAL_TYPE:
    return @"decimal";
  }

  return @"unknown";
}

-(CLString *) sybaseFormatString:(int) aType
{
  CLMutableString *mString;


  mString = [[CLMutableString alloc] init];
  
  if (aType & CS_FMT_UNUSED)
    [mString appendString:@"unused"];
  if (aType & CS_FMT_NULLTERM) {
    if ([mString length])
      [mString appendString:@","];
    [mString appendString:@"nullterm"];
  }
  if (aType & CS_FMT_PADNULL) {
    if ([mString length])
      [mString appendString:@","];
    [mString appendString:@"padnull"];
  }
  if (aType & CS_FMT_PADBLANK) {
    if ([mString length])
      [mString appendString:@","];
    [mString appendString:@"padblank"];
  }
  if (aType & CS_FMT_JUSTIFY_RT) {
    if ([mString length])
      [mString appendString:@","];
    [mString appendString:@"justifyright"];
  }
#ifdef CS_FMT_STRIPBLANKS
  if (aType & CS_FMT_STRIPBLANKS) {
    if ([mString length])
      [mString appendString:@","];
    [mString appendString:@"stripblanks"];
  }
#endif
#ifdef CS_FMT_SAFESTR
  if (aType & CS_FMT_SAFESTR) {
    if ([mString length])
      [mString appendString:@","];
    [mString appendString:@"safestr"];
  }
#endif

  return [mString autorelease];
}

-(id) runQuery:(CLString *) aQuery
{
  CLAutoreleasePool *pool;
  CLMutableArray *mArray = nil;
  CLMutableDictionary *mDict = nil;
  CLData *aData;
  id results;
  CS_COMMAND *cmd;
  CS_DATAFMT *dataFmt, strFmt;
  CS_INT result_type, cols, outlen;
  CS_RETCODE ret;
  CS_INT *copied;
  CS_SMALLINT *indicator;
  void **values;
  char *buf;
  int i;
  unsigned int buflen;
  CLString *aString;


  pool = [[CLAutoreleasePool alloc] init];
  results = [[CLMutableArray alloc] init];
  aData = [aQuery dataUsingEncoding:[self encoding]];
  buflen = [aData length] + 1;
  if (buflen < 1024)
    buflen = 1024;
  if (!(buf = malloc(buflen)))
    [self error:@"Unable to allocate memory"];
  memcpy(buf, [aData bytes], [aData length]);
  buf[[aData length]] = 0;
  ct_cmd_alloc(conn, &cmd);
  ct_command(cmd, CS_LANG_CMD, buf, CS_NULLTERM, CS_UNUSED);
  ct_send(cmd);

  while (ct_results(cmd, &result_type) == CS_SUCCEED) {
    switch (result_type) {
    case CS_ROW_RESULT:
      ct_res_info(cmd, CS_NUMDATA, &cols, CS_UNUSED, NULL);
      if (!(values = malloc(sizeof(void *) * cols)))
	[self error:@"Unable to allocate memory"];	
      if (!(dataFmt = calloc(cols, sizeof(CS_DATAFMT))))
	[self error:@"Unable to allocate memory"];
      if (!(copied = malloc(sizeof(CS_INT) * cols)))
	[self error:@"Unable to allocate memory"];
      if (!(indicator = malloc(sizeof(CS_INT) * cols)))
	[self error:@"Unable to allocate memory"];
      for (i = 0; i < cols; i++) {
	ct_describe(cmd, i+1, &dataFmt[i]);
#if 0
	fprintf(stderr, "name:      %s\n", dataFmt[i].name);
	fprintf(stderr, "nameLen:   %i\n", dataFmt[i].namelen);
	fprintf(stderr, "datatype:  %s\n", [[self sybaseTypeString:dataFmt[i].datatype]
					     UTF8String]);
	fprintf(stderr, "maxlength: %i\n", dataFmt[i].maxlength);
	fprintf(stderr, "\n");
#endif
	if (!(values[i] = calloc(dataFmt[i].maxlength+1, 1)))
	  [self error:@"Unable to allocate memory"];
	ct_bind(cmd, i+1, &dataFmt[i], values[i], &copied[i], &indicator[i]);

	if (!mArray)
	  mArray = [[CLMutableArray alloc] init];
	[mArray addObject:
		  [CLDictionary dictionaryWithObjectsAndKeys:
				  [CLString stringWithBytes:dataFmt[i].name
					    length:strlen(dataFmt[i].name)
					    encoding:[self encoding]], @"name",
				nil]];
      }

      if (mArray) {
	if (!mDict)
	  mDict = [[CLMutableDictionary alloc] init];
	[mDict setObject:mArray forKey:@"columns"];
	[mArray release];
	mArray = nil;
      }
      
      while (ct_fetch(cmd, CS_UNUSED, CS_UNUSED, CS_UNUSED, NULL) == CS_SUCCEED) {
	CLMutableArray *aRow;


	aRow = [[CLMutableArray alloc] init];
	for (i = 0; i < cols; i++) {
	  if (indicator[i] < 0 || !copied[i])
	    [aRow addObject:[CLNull null]];
	  else if (dataFmt[i].datatype != CS_CHAR_TYPE &&
	      dataFmt[i].datatype != CS_VARCHAR_TYPE &&
		   dataFmt[i].datatype != CS_TEXT_TYPE) {
	    memcpy(&strFmt, &dataFmt[i], sizeof(CS_DATAFMT));
	    strFmt.datatype = CS_CHAR_TYPE;
	    strFmt.format = CS_FMT_NULLTERM;
	    strFmt.status = 0;
	    for (;;) {
	      strFmt.maxlength = buflen - 1;
	      outlen = 0;
	      memset(buf, 0, buflen);
	      ret = cs_convert(context, &dataFmt[i], values[i], &strFmt, buf, &outlen);
	      if (ret == CS_SUCCEED && outlen < strFmt.maxlength)
		break;
	    
	      buflen *= 2;
	      if (!(buf = realloc(buf, buflen)))
		[self error:@"Unable to allocate memory"];
	    }

	    [aRow addObject:[CLString stringWithBytes:buf
				      length:strlen(buf) encoding:[self encoding]]];
	  }
	  else
	    [aRow addObject:[CLString stringWithBytes:values[i] length:copied[i]
				      encoding:[self encoding]]];
	  memset(values[i], 0, dataFmt[i].maxlength);
	}
	if (!mArray)
	  mArray = [[CLMutableArray alloc] init];
	[mArray addObject:aRow];
	[aRow release];
      }
      
      if (mArray) {
	if (!mDict)
	  mDict = [[CLMutableDictionary alloc] init];
	[mDict setObject:mArray forKey:@"rows"];
	[mArray release];
	mArray = nil;
      }
      
      for (i = 0; i < cols; i++)
	free(values[i]);
      free(values);
      free(dataFmt);
      free(copied);
      free(indicator);
      break;
      
    case CS_STATUS_RESULT:
      ct_cancel(NULL, cmd, CS_CANCEL_CURRENT);
      break;

    case CS_CMD_DONE:
      if ((aString = CLSybaseErrorsFor(context))) {
	if (!mDict)
	  mDict = [[CLMutableDictionary alloc] init];
	[mDict setObject:aString forKey:@"errors"];
      }
      
      if (mDict) {
	[results addObject:mDict];
	[mDict release];
	mDict = nil;
      }
      break;
      
    default:
      break;
    }
  }

  free(buf);
  
  ct_cmd_drop(cmd);
  [pool release];

  if (![results count]) {
    [results release];
    results = mDict;
  }
  else if ([results count] == 1) {
    mDict = [[results objectAtIndex:0] retain];
    [results release];
    results = mDict;
  }
  
  return [results autorelease];
}

-(void) beginTransaction
{
  [self runQuery:@"begin transaction"];
  return;
}

-(void) commitTransaction
{
  [self runQuery:@"commit transaction"];
  return;
}

-(void) rollbackTransaction
{
  [self runQuery:@"rollback transaction"];
  return;
}

@end

static CLHashTable *CLSybaseErrors = nil;

void CLSybaseAddErrorFor(CS_CONTEXT *context, CLString *error)
{
  CLString *newString, *oldString;

  
  if (!CLSybaseErrors) {
    CLSybaseErrors = [[CLHashTable alloc] init];
    CLAddToCleanup(CLSybaseErrors);
  }

  if ((oldString = [CLSybaseErrors dataForKeyIdenticalTo:(id) context
				   hash:(CLUInteger) context]))
    newString = [oldString stringByAppendingString:error];
  else
    newString = error;

  [CLSybaseErrors removeDataForKeyIdenticalTo:(id) context hash:(CLUInteger) context];
  [newString retain];
  [oldString release];
  [CLSybaseErrors setData:newString forKey:(id) context hash:(CLUInteger) context];
  return;
}

CLString *CLSybaseErrorsFor(CS_CONTEXT *context)
{
  CLString *aString;


  if ((aString = [CLSybaseErrors dataForKeyIdenticalTo:(id) context
				 hash:(CLUInteger) context]))
    [CLSybaseErrors removeDataForKeyIdenticalTo:(id) context hash:(CLUInteger) context];

  return [aString autorelease];
}

CS_RETCODE CLSybaseClientError(CS_CONTEXT *context, CS_CONNECTION *connection,
			       CS_CLIENTMSG *errmsg)
{
  CLSybaseAddErrorFor(context,
		      [CLString stringWithFormat:
				  @"Open Client Message:\n"
				"Message number: LAYER = (%d) ORIGIN = (%d) "
				"SEVERITY = (%d) NUMBER = (%d)\n"
				"Message String: %s\n",
				CS_LAYER(errmsg->msgnumber), CS_ORIGIN(errmsg->msgnumber),
				CS_SEVERITY(errmsg->msgnumber), CS_NUMBER(errmsg->msgnumber),
				errmsg->msgstring]);
  return CS_SUCCEED;
}

CS_RETCODE CLSybaseServerError(CS_CONTEXT *context, CS_CONNECTION *connection,
			       CS_SERVERMSG *srvmsg)
{
  if (srvmsg->severity && srvmsg->severity != 10)
    CLSybaseAddErrorFor(context,
			[CLString stringWithFormat:
				    @"Server message:\n"
				  "Message number: %d, Severity %d, "
				  "State %d, Line %d\n"
				  "Message String: %s\n",
				  srvmsg->msgnumber, srvmsg->severity,
				  srvmsg->state, srvmsg->line, srvmsg->text]);
  return CS_SUCCEED;
}
