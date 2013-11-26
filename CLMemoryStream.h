/* Copyright 2012 by Traction Systems, LLC. <http://tractionsys.com/>
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

#import <ClearLake/CLStream.h>

@class CLString, CLData;

@interface CLMemoryStream:CLStream <CLStream>
{
  FILE *file;
  CLData *data;
  void *buffer;
  size_t length;
  BOOL freeBuffer;
}

+(CLMemoryStream *) openWithMemory:(void *) buf length:(int) len mode:(int) mode;
+(CLMemoryStream *) openWithData:(CLData *) aData mode:(int) mode;
+(CLStream *) openMemoryForWriting;

-(id) init;
-(id) initWithMemory:(void *) buf length:(int) len mode:(int) mode;
-(id) initWithData:(CLData *) aData mode:(int) mode;
-(void) dealloc;

-(void) close;
-(const void *) bytes;
-(CLUInteger) length;
-(CLData *) data;

@end
