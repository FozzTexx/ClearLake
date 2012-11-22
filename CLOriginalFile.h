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

#ifndef _CLORIGINALFILE_H
#define _CLORIGINALFILE_H

#import <ClearLake/CLGenericRecord.h>

@class CLField;

@protocol CLFileTypeIdentification
-(BOOL) isAudio;
-(BOOL) isVideo;
-(BOOL) isImage;
-(BOOL) isPDF;
-(void) download:(id) sender;
-(void) view:(id) sender;
-(CLString *) mimeType;
@end

@interface CLOriginalFile:CLGenericRecord <CLArchiving, CLFileTypeIdentification>
{
  CLData *data;
  BOOL loaded;
  CLString *fname; /* Not called filename so that CLGenericRecord doesn't find it */
}

+(id) fileFromField:(CLField *) aField table:(CLString *) aTable;
+(id) fileFromFile:(CLString *) aFilename table:(CLString *) aTable;
+(id) fileFromData:(CLData *) aData table:(CLString *) aTable;

-(id) init;
-(id) initFromData:(CLData *) aData table:(CLString *) aTable;
-(void) dealloc;

-(CLString *) path;
-(void) load;
-(void) save;
-(unsigned long long) bytes;
-(CLData *) data;
-(CLString *) generateURL;
-(BOOL) deleteFromDatabase;
-(CLString *) filename;
-(void) setFilename:(CLString *) aString;
@end

@interface CLOriginalFile (CLMagic)
-(CLString *) caption;
-(void) setCaption:(CLString *) aString;
@end

#endif /* _CLORIGINALFILE_H */
