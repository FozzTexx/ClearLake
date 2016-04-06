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

#import <ClearLake/CLGenericRecord.h>

#define CLSCDashMode		1
#define CLSCCamelCaseMode	2

@class CLDatetime, CLCategory, CLWikiString;

extern Class CLStandardContentClass, CLCategoryClass, CLStandardContentCategoryClass,
  CLStandardContentFileClass, CLStandardContentImageClass, CLOriginalFileClass,
  CLOriginalImageClass, CLCachedImageClass, CLFileTypeClass;

@interface CLStandardContent:CLGenericRecord
{
  id body;

  CLArray *_positions;
  CLMutableArray *_removedCategories;
}

+(CLString *) urlTitleFromString:(CLString *) aString mode:(int) urlMode;

-(void) dealloc;
-(void) setBody:(CLString *) aString;
-(void) didDeleteFromDatabase;
-(CLArray *) sortedImages;
-(id) firstImage;
-(void) createUrlTitleFromString:(CLString *) aString;
-(void) createUrlTitleFromTitle;

-(id) joinCategory:(CLCategory *) aCat;
-(int) validateForm:(id) sender;
-(BOOL) validateTitle:(id *) ioValue error:(CLString **) outError;
-(void) uploadImage:(id) sender;
-(void) uploadFile:(id) sender;
-(void) edit:(id) sender;
-(BOOL) isChildOf:(id) anObject;
-(CLArray *) currentCategories;

-(CLString *) deleteFiles;
-(CLString *) deleteImages;

@end

@interface CLStandardContent (CLMagic)
-(CLString *) title;
-(CLString *) summary;
-(CLWikiString *) body;
-(CLDatetime *) created;
-(CLDatetime *) modified;
-(CLArray *) categories;
-(CLArray *) images;
-(CLArray *) files;
-(CLString *) urlTitle;
-(id) parent;
-(CLArray *) children;
-(void) setTitle:(CLString *) aString;
-(void) setSummary:(CLString *) aString;
-(void) setCreated:(CLDatetime *) aDate;
-(void) setModified:(CLDatetime *) aDate;
-(void) setUrlTitle:(CLString *) aString;
-(void) detail:(id) sender;
@end
