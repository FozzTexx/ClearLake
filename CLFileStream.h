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

#import <ClearLake/CLStream.h>

@class CLString;

@interface CLFileStream:CLStream <CLStream>
{
  FILE *file;
  CLString *path;
  int pid;
}

+(CLFileStream *) openFileAtPath:(CLString *) aPath mode:(int) aMode;
+(CLFileStream *) streamWithDescriptor:(int) fd mode:(int) aMode
				atPath:(CLString *) aPath processID:(int) aPid;

-(id) initWithFile:(FILE *) aFile path:(CLString *) aString processID:(int) aPid;
-(id) init;
-(void) dealloc;

-(CLString *) path;
-(int) pid;
-(void) close;
-(void) closeAndRemove;
-(int) closeAndWait;
-(void) remove;

@end
