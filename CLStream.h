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

#ifndef _CLSTREAM_H
#define _CLSTREAM_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLString.h>
#import <ClearLake/CLHashTable.h>

#include <pty.h>
#include <stdio.h>

@class CLData, CLArray;

#define CLReadOnly	1
#define CLWriteOnly	2
#define CLReadWrite	4
#define CLEOF		-1

@protocol CLStream
-(int) readByte;
-(void) writeByte:(int) c;
-(int) read:(void *) buffer length:(int) len;
-(int) write:(const void *) buffer length:(int) len;
-(void) close;
@end

@interface CLStream:CLObject
{
  CLHashTable *streamObjects;
}
+(CLString *) mimeTypeForFile:(CLString *) aPath;
-(void) dealloc;
@end

@interface CLStream (CLBasicIO) <CLStream>
@end

@interface CLStream (CLStreamObjects)
-(CLData *) readDataOfLength:(int) len;
-(void) writeData:(CLData *) aData;
-(CLString *) readStringUsingEncoding:(CLStringEncoding) enc;
-(void) writeString:(CLString *) aString usingEncoding:(CLStringEncoding) enc;
-(void) writeFormat:(CLString *) aFormat usingEncoding:(CLStringEncoding) enc, ...;
-(void) writeFormat:(CLString *) format usingEncoding:(CLStringEncoding) enc
	  arguments:(va_list) argList;
@end

@interface CLStream (CLStreamOpening)
+(CLStream *) openFileAtPath:(CLString *) aPath mode:(int) mode;
+(CLStream *) openTemporaryFile:(CLString *) template;
+(CLStream *) openWithMemory:(void *) buf length:(int) len mode:(int) mode;
+(CLStream *) openWithData:(CLData *) aData mode:(int) mode;
+(CLStream *) openMemoryForWriting;
+(CLStream *) openPipe:(CLString *) aCommand mode:(int) mode;
+(CLStream *) openPty:(CLString *) aCommand termios:(struct termios *) termp
	   windowSize:(struct winsize *) winp;
+(CLStream *) openDescriptor:(int) fd mode:(int) mode;
@end

@interface CLStream (CLStreamArchiving)
-(void) readType:(CLString *) type data:(void *) data;
-(void) writeType:(CLString *) type data:(void *) data;
-(void) readTypes:(CLString *) type, ...;
-(void) writeTypes:(CLString *) type, ...;
@end

@interface CLStream (CLMemoryStreams)
-(const void *) bytes;
-(CLUInteger) length;
-(CLData *) data;
@end

@interface CLStream (CLFileStreams)
-(CLString *) path;
-(int) pid;
-(void) closeAndRemove;
-(int) closeAndWait;
-(void) remove;
@end

@interface CLStream (CLPipeStreams)
-(void) closeRead;
-(void) closeWrite;
-(int) closeAndWait;
-(int) pid;
@end

/* I/O */
extern void CLPrintf(CLStream *stream, CLString *format, ...);
/* Legacy I/O */
extern CLString *CLGets(FILE *file, CLStringEncoding enc);
extern CLString *CLGetsfd(int fd, CLStringEncoding enc);

extern CLString *CLPathForFileID(int image_id);
extern BOOL CLStoreFileAsID(CLData *aData, CLString *extension, CLString *extensionHint,
			    int seq);
extern int CLNextFileSequence();
extern int CLStoreFile(CLData *aData, CLString *extension, CLString *extensionHint);
extern void CLWriteHTMLObject(CLStream *stream, id anObject);
extern CLString *CLFullPathForFile(CLString *aFilename, CLArray *extensions,
				   CLArray *directories);
extern int CLDeflate(const void *data, int len, int level, CLData **aData);

#define CL_FROMSTART	SEEK_SET
#define CL_FROMCURRENT	SEEK_CUR
#define CL_FROMEND	SEEK_END

@protocol CLStreamDelegate
-(CLString *) delegateGetFileDirectory;
@end

#endif /* _CLSTREAM_H */
