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

#import <ClearLake/CLGenericRecord.h>

#define CLSCDashMode		1
#define CLSCCamelCaseMode	2

@class CLCalendarDate, CLCategory, CLWikiString;

@interface CLStandardContent:CLGenericRecord
{
  id body;

  CLArray *_positions;
}

-(void) dealloc;
-(void) setBody:(CLString *) aString;
-(BOOL) deleteFromDatabase;
-(CLArray *) sortedImages;
-(id) firstImage;
-(CLString *) urlTitleFromString:(CLString *) aString mode:(int) urlMode;
-(void) createUrlTitleFromString:(CLString *) aString;
-(void) createUrlTitleFromTitle;

-(id) joinCategory:(CLCategory *) aCat;
-(int) validateForm:(id) sender;
-(BOOL) validateTitle:(id *) ioValue error:(CLString **) outError;
-(void) uploadImage:(id) sender;
-(void) edit:(id) sender;
-(BOOL) isChildOf:(id) anObject;

@end

@interface CLStandardContent (CLMagic)
-(CLString *) title;
-(CLString *) summary;
-(CLWikiString *) body;
-(CLCalendarDate *) created;
-(CLCalendarDate *) modified;
-(CLArray *) categories;
-(CLArray *) images;
-(CLArray *) files;
-(CLString *) urlTitle;
-(id) parent;
-(CLArray *) children;
-(void) setTitle:(CLString *) aString;
-(void) setSummary:(CLString *) aString;
-(void) setCreated:(CLCalendarDate *) aDate;
-(void) setModified:(CLCalendarDate *) aDate;
-(void) setUrlTitle:(CLString *) aString;
-(void) detail:(id) sender;
@end
