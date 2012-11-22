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

#ifndef _CLSTREAM_H
#define _CLSTREAM_H

#import <ClearLake/CLObject.h>
#import <ClearLake/CLString.h>

#include <pty.h>

@class CLString, CLOpenFile, CLData, CLArray;

#define CL_READONLY	OBJC_READONLY
#define CL_WRITEONLY	OBJC_WRITEONLY
#define CL_READWRITE	4

#define CL_FREEBUFFER	0

typedef struct CLStream {
  FILE *file;
  char *buf;
  size_t len;
} CLStream;

extern int CLGetc(CLStream *stream);
extern void CLPutc(CLStream *stream, int c);
extern int CLRead(CLStream *stream, char *buf, int len);
extern void CLWrite(CLStream *stream, const void *buf, int len);
extern void CLPrintf(CLStream *stream, CLString *format, ...);
extern CLStream *CLOpenMemory(const char *buf, int len, int mode);
extern void CLCloseMemory(CLStream *stream, int mode);
extern void CLGetMemoryBuffer(CLStream *stream, char **data, int *len, int *alloced);
extern CLData *CLGetData(CLStream *stream);
extern id CLReadObject(CLTypedStream *stream);
extern CLTypedStream *CLOpenTypedStream(CLStream *stream, int mode);
extern int CLReadType(CLTypedStream *stream, const char *type, void *data);
extern int CLWriteType(CLTypedStream *stream, const char *type, const void *data);
extern int CLReadTypes(CLTypedStream *stream, const char *type, ...);
extern int CLWriteTypes(CLTypedStream *stream, const char *type, ...);
extern long CLTell(CLStream *stream);
extern void CLSeek(CLStream *stream, long offset, int whence);
extern CLOpenFile *CLTemporaryFile(CLString *template);
extern CLString *CLGets(FILE *file, CLStringEncoding enc);
extern CLString *CLGetsfd(int fd, CLStringEncoding enc);
extern CLString *CLPathForFileID(int image_id);
extern BOOL CLStoreFileAsID(CLData *aData, CLString *extension, CLString *extensionHint,
			    int seq);
extern int CLStoreFile(CLData *aData, CLString *extension, CLString *extensionHint);
extern void CLWriteHTMLObject(CLStream *stream, id anObject);
extern CLString *CLFullPathForFile(CLString *aFilename, CLArray *extensions,
				   CLArray *directories);
extern CLOpenFile *CLPtyOpen(CLString *aCommand, struct termios *termp,
			     struct winsize *winp);
extern CLOpenFile *CLPipeOpen(CLString *aCommand, CLString *type);
extern int CLDeflate(const void *data, int len, int level, CLData **aData);

#define CL_FROMSTART	SEEK_SET
#define CL_FROMCURRENT	SEEK_CUR
#define CL_FROMEND	SEEK_END

#define CLCloseTypedStream	objc_close_typed_stream
#define CLWriteObject		objc_write_object
#define CLWriteObjectReference	objc_write_object_reference
#define CLReadArray		objc_read_array
#define CLWriteArray		objc_write_array

@protocol CLStreamDelegate
-(CLString *) delegateGetFileDirectory;
@end

#endif /* _CLSTREAM_H */
