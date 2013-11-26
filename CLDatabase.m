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

#import "CLDatabase.h"
#import "CLMutableString.h"
#import "CLMutableArray.h"
#import "CLAttribute.h"
#import "CLMutableDictionary.h"
#import "CLNull.h"
#import "CLDecimalNumber.h"
#import "CLCalendarDate.h"
#import "CLTimeZone.h"
#import "CLMySQLDatabase.h"
#import "CLSybaseDatabase.h"
#import "CLCharacterSet.h"

#include <stdlib.h>
#include <string.h>

@implementation CLDatabase

+(int) findEscapeCharacter:(CLString *) aString
{
  unsigned char used[128];
  CLUInteger i, len;
  unichar *buf;


  memset(used, 0, sizeof(used));

  len = [aString length];
  if (!(buf = malloc(len * sizeof(unichar))))
    [self error:@"Unable to allocate memory"];
  [aString getCharacters:buf];

  for (i = 0; i < len; i++)
    if (buf[i] > ' ' && buf[i] < 127)
      used[buf[i]] = 1;
  free(buf);

  for (i = ' ' + 1; used[i] && i < 127; i++)
    ;

  if (i == 127)
    return -1;

  return i;
}

+(CLString *) defangString:(CLString *) aString escape:(int *) escape
{
  int esc = 0, len;
  unichar *buf, c;
  CLUInteger i;


  if (escape) {
    esc = *escape;
    esc &= 0x7f;
    if (esc <= ' ' || esc > '~')
      esc = [self findEscapeCharacter:aString];
    *escape = esc;
  }

  if ((len = [aString length])) {
    if (!(buf = malloc((len * 2) * sizeof(unichar))))
      [self error:@"Unable to allocate memory"];
    [aString getCharacters:buf];
  
    for (i = 0; i < len; i++) {
      c = buf[i];
      if (esc && (c == '[' || c == ']' || c == '%' || c == '_' || c == '^')) {
	wmemmove(&buf[i+1], &buf[i], len - i);
	buf[i] = esc;
	i++;
	len++;
      }

      if (c == '\'') {
	wmemmove(&buf[i+1], &buf[i], len - i);
	i++;
	len++;
      }
    }

    aString = [CLString stringWithCharacters:buf length:len];
    free(buf);
  }

  return aString;
}

+(CLDatabase *) databaseFromDictionary:(CLDictionary *) aDict
{
  CLString *user, *host, *database, *password, *interface;
  CLDatabase *aDatabase = nil;

  
  user = [aDict objectForKey:@"user"];
  password = [aDict objectForKey:@"password"];
  host = [aDict objectForKey:@"host"];
  database = [aDict objectForKey:@"database"];
  interface = [aDict objectForKey:@"interface"];

  if (![interface caseInsensitiveCompare:@"mysql"])
    aDatabase = [[CLMySQLDatabase alloc]
		  initWithDatabase:database user:user password:password host:host];
  else if (![interface caseInsensitiveCompare:@"sybase"])
    aDatabase = [[CLSybaseDatabase alloc]
		  initWithDatabase:database user:user password:password host:host];

  return [aDatabase autorelease];
}

-(CLString *) defangString:(CLString *) aString escape:(int *) escape
{
  return [[self class] defangString:aString escape:escape];
}

-(CLArray *) read:(CLArray *) attributes qualifier:(CLString *) qualifier
	   errors:(id *) errors
{
  CLMutableArray *mArray = nil;
  CLDictionary *results;
  CLArray *rows, *aRow;
  CLAttribute *attr = nil;
  int i, j, k, l;
  id anObject;
  CLMutableDictionary *aDict;


  results = [self runQuery:qualifier];

  if (errors)
    *errors = [results objectForKey:@"errors"];
  
  rows = [results objectForKey:@"rows"];
  if ([rows count]) {
    mArray = [[CLMutableArray alloc] init];
    for (i = 0, j = [rows count]; i < j; i++) {
      aRow = [rows objectAtIndex:i];
      aDict = [[CLMutableDictionary alloc] init];
      for (k = 0, l = [aRow count]; k < l; k++) {
	attr = [attributes objectAtIndex:k];
	anObject = [aRow objectAtIndex:k];
	if ([anObject isKindOfClass:[CLNull class]])
	  [aDict setObject:anObject forKey:[attr name]];
	else {
	  switch ([attr externalType]) {
	  case CLVarcharAttributeType:
	    [aDict setObject:anObject forKey:[attr name]];
	    break;

	  case CLCharAttributeType:
	    {
	      CLRange aRange;
	      CLCharacterSet *iSet;


	      iSet = [[CLCharacterSet characterSetWithCharactersInString:@" "] invertedSet];
	      aRange = [anObject rangeOfCharacterFromSet:iSet options:CLBackwardsSearch
				 range:CLMakeRange(0, [anObject length])];
	      if (aRange.length)
		anObject = [anObject substringToIndex:CLMaxRange(aRange)];
	      else
		anObject = @"";
	    }
	      
	    [aDict setObject:anObject forKey:[attr name]];
	    break;

	  case CLIntAttributeType:
	    [aDict setObject:[CLNumber numberWithLongLong:[anObject longLongValue]]
		   forKey:[attr name]];
	    break;

	  case CLDatetimeAttributeType:
	    /* FIXME - not sure how to handle this. I'd rather display
	       dates in the local timezone and not in the DB's
	       timezone, but should the date's default timezone be the
	       DB's timezone anyway?? */
	    anObject = [CLCalendarDate
			 dateWithString:anObject
			 calendarFormat:[self dateFormat]
			 timeZone:[self timeZone]];
	    /* Reset timezone to system timezone */
	    [anObject setTimeZone:nil];
	    [aDict setObject:anObject forKey:[attr name]];
	    break;

	  case CLMoneyAttributeType:
	  case CLNumericAttributeType:
	    [aDict setObject:[CLDecimalNumber decimalNumberWithString:anObject]
		   forKey:[attr name]];
	    break;
	  }
	}
      }

      [mArray addObject:aDict];
      [aDict release];
    }
  }
  
  return [mArray autorelease];
}

-(int) nextIDForTable:(CLString *) table
{
  int rid = 0;
  CLDictionary *results;
  CLArray *anArray;
  CLString *aString;
  id aValue;


  [self runQuery:[CLString stringWithFormat:
			     @"UPDATE cl_sequence_table SET counter ="
			   " counter + 1 where table_name = '%@'", table]];
  results = [self runQuery:[CLString stringWithFormat:
				       @"SELECT counter FROM cl_sequence_table"
				     " WHERE table_name = '%@'", table]];
  anArray = [results objectForKey:@"rows"];
  if ([anArray count])
    rid = [[[anArray objectAtIndex:0] objectAtIndex:0] intValue];

  if (!rid) {
    [self runQuery:@"CREATE TABLE IF NOT EXISTS cl_sequence_table ("
	  "table_name varchar(32) not null, counter integer not null)"];

    aString = [CLString stringWithFormat:@"SELECT max(id)+1 FROM %@", table];
    results = [self runQuery:aString];
    anArray = [results objectForKey:@"rows"];
    if ([anArray count]) {
      aValue = [[anArray objectAtIndex:0] objectAtIndex:0];
      if (![aValue isKindOfClass:[CLNull class]])
	rid = [aValue intValue];
    }
    if (!rid)
      rid = 1;
    aString = [CLString stringWithFormat:
			  @"INSERT INTO cl_sequence_table (counter, table_name)"
			"VALUES (%i, '%@')", rid, table];
    [self runQuery:aString];
  }

  return rid;
}

-(int) insertDictionary:(CLDictionary *) aDictionary
	 withAttributes:(CLArray *) attributes into:(CLString *) table
		 errors:(id *) errors
{
  int rid;


  rid = [self nextIDForTable:table];
  [self insertDictionary:aDictionary withAttributes:attributes into:table withID:rid
	errors:errors];
  return rid;
}

-(void) insertDictionary:(CLDictionary *) aDictionary
	  withAttributes:(CLArray *) attributes into:(CLString *) table withID:(int) rid
		  errors:(id *) errors
{
  CLMutableString *mString;
  CLAttribute *attr;
  id anObject;
  int i, j;
  CLDictionary *results;


  mString = [[CLMutableString alloc] init];
  [mString appendFormat:@"insert into %@ (", table];
  if (rid)
    [mString appendString:@"id"];
  for (i = 0, j = [attributes count]; i < j; i++) {
    attr = [attributes objectAtIndex:i];
    if (i || rid)
      [mString appendString:@", "];
    [mString appendString:[attr name]];
  }
  [mString appendString:@") values ("];
  if (rid)
    [mString appendFormat:@"%i", rid];
  for (i = 0, j = [attributes count]; i < j; i++) {
    attr = [attributes objectAtIndex:i];
    if (i || rid)
      [mString appendString:@", "];

    anObject = [aDictionary objectForKey:[attr name]];
    if (!anObject || [anObject isKindOfClass:[CLNull class]])
      [mString appendString:@"NULL"];
    else {
      switch ([attr externalType]) {
      case CLVarcharAttributeType:
      case CLCharAttributeType:
	[mString appendFormat:@"'%@'", [self defangString:[anObject description]
					     escape:NULL]];
	break;

      case CLDatetimeAttributeType:
	if ([anObject isKindOfClass:[CLCalendarDate class]])
	  [mString appendFormat:@"'%@'",
		   [anObject descriptionWithCalendarFormat:[self dateFormat]
			     timeZone:[self timeZone]]];
	else
	  [mString appendFormat:@"'%@'", [self defangString:[anObject description]
					       escape:NULL]];
	break;
	  
      case CLIntAttributeType:
      case CLMoneyAttributeType:
      case CLNumericAttributeType:
	if (![anObject isKindOfClass:[CLNumber class]])
	  anObject = [CLDecimalNumber decimalNumberWithString:[anObject description]];
	[mString appendFormat:@"%@", anObject];
	break;
      }
    }
  }
  [mString appendString:@")"];

  results = [self runQuery:mString];
  [mString release];
  
  if (errors)
    *errors = [results objectForKey:@"errors"];
  
  return;
}

-(BOOL) updateTable:(CLString *) table withDictionary:(CLDictionary *) aDictionary
      andAttributes:(CLArray *) attributes forRow:(CLString *) rowID
	     errors:(id *) errors
{
  CLMutableString *mString;
  CLAttribute *attr;
  id anObject;
  int i, j;
  CLDictionary *results;


  mString = [[CLMutableString alloc] init];
  [mString appendFormat:@"update %@ set ", table];
  for (i = 0, j = [attributes count]; i < j; i++) {
    attr = [attributes objectAtIndex:i];
    if (i)
      [mString appendString:@", "];
    [mString appendFormat:@"%@ = ", [attr name]];

    anObject = [aDictionary objectForKey:[attr name]];
    if (!anObject || [anObject isKindOfClass:[CLNull class]])
      [mString appendString:@"NULL"];
    else {
      switch ([attr externalType]) {
      case CLVarcharAttributeType:
      case CLCharAttributeType:
	[mString appendFormat:@"'%@'", [self defangString:[anObject description]
						   escape:NULL]];
	break;

      case CLDatetimeAttributeType:
	if ([anObject isKindOfClass:[CLCalendarDate class]])
	  [mString appendFormat:@"'%@'",
		   [anObject descriptionWithCalendarFormat:[self dateFormat]
			     timeZone:[self timeZone]]];
	else
	  [mString appendFormat:@"'%@'", [self defangString:[anObject description]
					       escape:NULL]];
	break;
	  
      case CLIntAttributeType:
      case CLMoneyAttributeType:
      case CLNumericAttributeType:
	[mString appendFormat:@"%@", anObject];
	break;
      }
    }
  }
  [mString appendFormat:@" where %@", rowID];

  results = [self runQuery:mString];
  [mString release];

  if (errors)
    *errors = [results objectForKey:@"errors"];
  
  return YES;
}

-(BOOL) deleteRowsFromTable:(CLString *) aTable qualifier:(CLString *) qualifier
		     errors:(id *) errors
{
  CLString *aString;
  CLDictionary *results;


  aString = [[CLString alloc] initWithFormat:@"delete from %@ where %@", aTable, qualifier];
  results = [self runQuery:aString];
  [aString release];
  if (errors)
    *errors = [results objectForKey:@"errors"];
  
  return YES;
}

-(CLStringEncoding) encoding
{
  if (!encoding)
    return CLUTF8StringEncoding;
  return encoding;
}

-(void) setEncoding:(CLStringEncoding) aValue
{
  encoding = aValue;
  return;
}

-(CLTimeZone *) timeZone
{
  if (!zone)
    zone = [[CLTimeZone timeZoneWithName:@"UTC+0000"] retain];
  return zone;
}

-(void) setTimeZone:(CLTimeZone *) aZone
{
  [zone autorelease];
  zone = [aZone retain];
  return;
}

-(CLString *) dateFormat
{
  if (!dateFormat)
    return @"%Y-%m-%d %H:%M:%S";
  return dateFormat;
}

-(void) setDateFormat:(CLString *) aString
{
  [dateFormat autorelease];
  dateFormat = [aString copy];
  return;
}

@end
