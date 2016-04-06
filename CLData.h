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

#ifndef _CLDATA_H
#define _CLDATA_H

#import <ClearLake/CLObject.h>

@class CLString;

extern Class CLDataClass, CLMutableDataClass;

@interface CLData:CLObject <CLCopying, CLMutableCopying, CLArchiving>
{
  unsigned char *data;
  CLUInteger len;
}

+(id) data;
+(id) dataWithBytes:(const void *) bytes length:(CLUInteger) length;
+(id) dataWithBytesNoCopy:(const void *) bytes length:(CLUInteger) length;
+(id) dataWithContentsOfFile:(CLString *) path;

-(id) init;
-(id) initWithBytes:(const void *) bytes length:(CLUInteger) length;
-(id) initWithBytesNoCopy:(const void *) bytes length:(CLUInteger) length;
-(id) initWithContentsOfFile:(CLString *) path;
-(void) dealloc;

-(const void *) bytes;
-(CLUInteger) length;
-(CLString *) encodeBase64;
-(CLString *) encodeBase64WithCharacters:(const char *) baseChars;
-(id) bDecode;
-(CLString *) hexEncode;
-(CLUInteger) crc32;
-(CLData *) md5;
-(CLData *) hmacSHA1WithKey:(CLData *) aKey;
-(BOOL) writeToFile:(CLString *) path atomically:(BOOL) atomic
    preserveBackups:(CLUInteger) numBackups;

@end

#endif /* _CLDATA_H */
