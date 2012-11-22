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

#ifndef _CLDATABASE_H
#define _CLDATABASE_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLString.h>

@class CLArray, CLDictionary, CLTimeZone;

@protocol CLDatabaseMethods
-(id) initWithDatabase:(CLString *) aDatabase user:(CLString *) user
	      password:(CLString *) password host:(CLString *) aHost;
-(id) runQuery:(CLString *) aQuery;

-(void) beginTransaction;
-(void) commitTransaction;
-(void) rollbackTransaction;
@end

@interface CLDatabase:CLObject
{
  CLStringEncoding encoding;
  CLTimeZone *zone;
  CLString *dateFormat;
}

+(CLString *) defangString:(CLString *) aString escape:(int *) escape;
+(CLDatabase *) databaseFromDictionary:(CLDictionary *) aDict;

-(CLString *) defangString:(CLString *) aString escape:(int *) escape;
-(CLArray *) read:(CLArray *) attributes qualifier:(CLString *) qualifier
	   errors:(id *) errors;
-(int) nextIDForTable:(CLString *) table;
-(int) insertDictionary:(CLDictionary *) aDict
	 withAttributes:(CLArray *) attributes into:(CLString *) table
		 errors:(id *) errors;
-(void) insertDictionary:(CLDictionary *) aDict
	  withAttributes:(CLArray *) attributes into:(CLString *) table withID:(int) rid
		  errors:(id *) errors;
-(BOOL) updateTable:(CLString *) table withDictionary:(CLDictionary *) aDict
      andAttributes:(CLArray *) attributes forRow:(CLString *) rowID
	     errors:(id *) errors;
-(BOOL) deleteRowsFromTable:(CLString *) aTable qualifier:(CLString *) qualifier
		     errors:(id *) errors;
-(CLStringEncoding) encoding;
-(void) setEncoding:(CLStringEncoding) aValue;
-(CLTimeZone *) timeZone;
-(void) setTimeZone:(CLTimeZone *) aZone;
-(CLString *) dateFormat;
-(void) setDateFormat:(CLString *) aString;
@end

/* Methods implemented by subclasses and not covered in CLDatabase directly */
@interface CLDatabase (CLDatabaseProtocol)
-(id) runQuery:(CLString *) aQuery;
-(void) beginTransaction;
-(void) commitTransaction;
-(void) rollbackTransaction;
@end

#endif /* _CLDATABASE_H */
