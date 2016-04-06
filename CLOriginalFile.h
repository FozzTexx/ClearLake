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

#ifndef _CLORIGINALFILE_H
#define _CLORIGINALFILE_H

#import <ClearLake/CLGenericRecord.h>

@class CLInput;

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
  CLString *_filename; /* Not called filename so that CLGenericRecord doesn't find it */
}

+(id) fileFromField:(CLInput *) aField table:(CLString *) aTable;
+(id) fileFromFile:(CLString *) aFilename table:(CLString *) aTable;
+(id) fileFromData:(CLData *) aData table:(CLString *) aTable;
+(id) fileFromPath:(CLString *) aPath table:(CLString *) aTable hardlink:(BOOL) hardlink;

-(id) init;
-(id) initFromData:(CLData *) aData table:(CLString *) aTable;
-(void) dealloc;

-(CLString *) path;
-(void) load;
-(BOOL) save;
-(unsigned long long) bytes;
-(CLData *) data;
-(CLString *) generateURL;
-(void) didDeleteFromDatabase;
-(CLString *) filename;
-(void) setFilename:(CLString *) aString;
@end

@interface CLOriginalFile (CLMagic)
-(CLString *) caption;
-(void) setCaption:(CLString *) aString;
@end

#endif /* _CLORIGINALFILE_H */
